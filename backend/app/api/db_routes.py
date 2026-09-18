from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, UploadFile, File, Form, Request
from sqlalchemy.orm import Session
from typing import List
import uuid

import os
import shutil
from app.db.database import get_db
from app.db import models
from app.api import schemas
from app.services.youtube import download_audio_background
from sqlalchemy import text, func

router = APIRouter(prefix="/db", tags=["database"])

def get_user_id(request: Request) -> str:
    device_id = request.headers.get("X-Device-Id")
    if not device_id:
        return "default"
    return device_id

def create_track_if_not_exists(db: Session, track: schemas.TrackCreate):
    db_track = db.query(models.Track).filter(models.Track.video_id == track.video_id).first()
    if not db_track:
        db_track = models.Track(**track.dict())
        db.add(db_track)
        db.commit()
        db.refresh(db_track)
    return db_track

@router.get("/favorites", response_model=List[schemas.Track])
def get_favorites(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    favorites = db.query(models.Favorite).filter(models.Favorite.user_id == user_id).order_by(models.Favorite.position).all()
    return [fav.track for fav in favorites]

@router.post("/favorites", response_model=schemas.Track)
def add_favorite(request: Request, track: schemas.TrackCreate, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    create_track_if_not_exists(db, track)
    fav = db.query(models.Favorite).filter(models.Favorite.user_id == user_id, models.Favorite.track_id == track.video_id).first()
    if not fav:
        # Get min position to insert at the beginning
        min_pos = db.query(func.min(models.Favorite.position)).filter(models.Favorite.user_id == user_id).scalar() or 0
        new_fav = models.Favorite(user_id=user_id, track_id=track.video_id, position=min_pos - 1)
        db.add(new_fav)
        db.commit()
    background_tasks.add_task(download_audio_background, track.video_id)
    return track

@router.delete("/favorites/{video_id}")
def remove_favorite(request: Request, video_id: str, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    fav = db.query(models.Favorite).filter(models.Favorite.user_id == user_id, models.Favorite.track_id == video_id).first()
    if fav:
        db.delete(fav)
        db.commit()
    return {"status": "success"}

@router.delete("/favorites")
def clear_favorites(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    db.query(models.Favorite).filter(models.Favorite.user_id == user_id).delete()
    db.commit()
    return {"status": "success"}

@router.put("/favorites/reorder")
def reorder_favorites(request: Request, track_ids: List[str], db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    favorites = db.query(models.Favorite).filter(models.Favorite.user_id == user_id).all()
    fav_map = {f.track_id: f for f in favorites}
    for i, tid in enumerate(track_ids):
        if tid in fav_map:
            fav_map[tid].position = i
    db.commit()
    return {"status": "success"}

@router.get("/playlists", response_model=List[schemas.Playlist])
def get_playlists(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    return db.query(models.Playlist).filter(models.Playlist.user_id == user_id).all()

@router.post("/playlists", response_model=schemas.Playlist)
def create_playlist(request: Request, playlist: schemas.PlaylistCreate, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    db_playlist = models.Playlist(id=str(uuid.uuid4()), user_id=user_id, name=playlist.name)
    db.add(db_playlist)
    db.commit()
    db.refresh(db_playlist)
    return db_playlist

@router.put("/playlists/{playlist_id}", response_model=schemas.Playlist)
def update_playlist(request: Request, playlist_id: str, playlist: schemas.PlaylistBase, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    db_playlist = db.query(models.Playlist).filter(models.Playlist.id == playlist_id, models.Playlist.user_id == user_id).first()
    if not db_playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    db_playlist.name = playlist.name
    if playlist.cover_image is not None:
        db_playlist.cover_image = playlist.cover_image
    db.commit()
    db.refresh(db_playlist)
    return db_playlist

@router.delete("/playlists/{playlist_id}")
def delete_playlist(request: Request, playlist_id: str, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    db_playlist = db.query(models.Playlist).filter(models.Playlist.id == playlist_id, models.Playlist.user_id == user_id).first()
    if db_playlist:
        db.delete(db_playlist)
        db.commit()
    return {"status": "success"}

@router.post("/playlists/{playlist_id}/tracks")
def add_track_to_playlist(request: Request, playlist_id: str, track: schemas.TrackCreate, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    db_playlist = db.query(models.Playlist).filter(models.Playlist.id == playlist_id, models.Playlist.user_id == user_id).first()
    if not db_playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    
    db_track = create_track_if_not_exists(db, track)
    if db_track not in db_playlist.tracks:
        current_min = db.execute(
            text("SELECT MIN(position) FROM playlist_track WHERE playlist_id = :pid"),
            {"pid": playlist_id}
        ).scalar()
        next_pos = 0 if current_min is None else current_min - 1

        db_playlist.tracks.append(db_track)
        db.commit()
        
        db.execute(
            text("UPDATE playlist_track SET position = :pos WHERE playlist_id = :pid AND track_id = :tid"),
            {"pos": next_pos, "pid": playlist_id, "tid": track.video_id}
        )
        db.commit()
        
    background_tasks.add_task(download_audio_background, track.video_id)
    return {"status": "success"}

@router.delete("/playlists/{playlist_id}/tracks/{video_id}")
def remove_track_from_playlist(request: Request, playlist_id: str, video_id: str, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    db_playlist = db.query(models.Playlist).filter(models.Playlist.id == playlist_id, models.Playlist.user_id == user_id).first()
    if not db_playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    
    db_track = db.query(models.Track).filter(models.Track.video_id == video_id).first()
    if db_track in db_playlist.tracks:
        db_playlist.tracks.remove(db_track)
        db.commit()
    return {"status": "success"}

@router.put("/playlists/{playlist_id}/reorder")
def reorder_playlist(request: Request, playlist_id: str, track_ids: List[str], db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    db_playlist = db.query(models.Playlist).filter(models.Playlist.id == playlist_id, models.Playlist.user_id == user_id).first()
    if not db_playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
        
    for idx, tid in enumerate(track_ids):
        db.execute(
            text("UPDATE playlist_track SET position = :pos WHERE playlist_id = :pid AND track_id = :tid"),
            {"pos": idx, "pid": playlist_id, "tid": tid}
        )
    db.commit()
    return {"status": "success"}

@router.post("/tracks/{video_id}/thumbnail")
async def update_thumbnail(
    request: Request,
    video_id: str,
    db: Session = Depends(get_db),
    image_url: str = Form(None),
    file: UploadFile = File(None)
):
    db_track = db.query(models.Track).filter(models.Track.video_id == video_id).first()
    if not db_track:
        raise HTTPException(status_code=404, detail="Track not found")
        
    if image_url:
        db_track.thumbnail = image_url
    elif file:
        downloads_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "downloads", "thumbnails")
        os.makedirs(downloads_dir, exist_ok=True)
        ext = file.filename.split('.')[-1] if '.' in file.filename else 'jpg'
        filename = f"{video_id}_{uuid.uuid4().hex[:8]}.{ext}"
        filepath = os.path.join(downloads_dir, filename)
        
        content = await file.read()
        with open(filepath, "wb") as f:
            f.write(content)
            
        base_url = str(request.base_url).rstrip("/")
        db_track.thumbnail = f"{base_url}/api/downloads/thumbnails/{filename}"
    else:
        raise HTTPException(status_code=400, detail="Must provide image_url or file")
        
    db.commit()
    db.refresh(db_track)
    return {"status": "ok", "message": f"Updated thumbnail for {video_id}"}

@router.post("/upload_image")
async def upload_image(request: Request, file: UploadFile = File(...)):
    ext = os.path.splitext(file.filename)[1].lower() if file.filename else ""
    if ext not in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
        raise HTTPException(status_code=400, detail="File must be an image")
    
    filename = f"{uuid.uuid4().hex}{ext}"
    
    downloads_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "downloads")
    covers_dir = os.path.join(downloads_dir, "covers")
    os.makedirs(covers_dir, exist_ok=True)
    
    file_path = os.path.join(covers_dir, filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    base_url = str(request.base_url).rstrip("/")
    url = f"{base_url}/api/downloads/covers/{filename}"
    return {"status": "success", "url": url}

@router.get("/history", response_model=List[schemas.Track])
def get_history(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    history_entries = db.query(models.History).filter(models.History.user_id == user_id).order_by(models.History.played_at.desc()).limit(20).all()
    return [entry.track for entry in history_entries]

@router.post("/history", response_model=schemas.Track)
def add_to_history(request: Request, track: schemas.TrackCreate, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    create_track_if_not_exists(db, track)
    existing = db.query(models.History).filter(models.History.user_id == user_id, models.History.track_id == track.video_id).first()
    if existing:
        db.delete(existing)
    
    new_entry = models.History(user_id=user_id, track_id=track.video_id)
    db.add(new_entry)
    db.commit()
    
    history = db.query(models.History).filter(models.History.user_id == user_id).order_by(models.History.played_at.desc()).all()
    if len(history) > 20:
        for entry in history[20:]:
            db.delete(entry)
        db.commit()
        
    return track

@router.delete("/history/{video_id}")
def remove_from_history(request: Request, video_id: str, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    entry = db.query(models.History).filter(models.History.user_id == user_id, models.History.track_id == video_id).first()
    if entry:
        db.delete(entry)
        db.commit()
    return {"status": "success"}

@router.get("/settings")
def get_settings(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    settings = db.query(models.Setting).filter(models.Setting.user_id == user_id).all()
    return {s.key: s.value for s in settings}

@router.post("/settings")
def update_settings(request: Request, settings: dict, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    for key, value in settings.items():
        db_setting = db.query(models.Setting).filter(models.Setting.user_id == user_id, models.Setting.key == key).first()
        if db_setting:
            db_setting.value = str(value)
        else:
            db_setting = models.Setting(user_id=user_id, key=key, value=str(value))
            db.add(db_setting)
    db.commit()
    return {"status": "success"}

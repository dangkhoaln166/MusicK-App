from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import uuid

from app.db.database import get_db
from app.db import models
from app.api import schemas

router = APIRouter(prefix="/db", tags=["database"])

def create_track_if_not_exists(db: Session, track: schemas.TrackCreate):
    db_track = db.query(models.Track).filter(models.Track.video_id == track.video_id).first()
    if not db_track:
        db_track = models.Track(**track.dict())
        db.add(db_track)
        db.commit()
        db.refresh(db_track)
    return db_track

@router.get("/favorites", response_model=List[schemas.Track])
def get_favorites(db: Session = Depends(get_db)):
    favorites = db.query(models.Favorite).all()
    return [fav.track for fav in favorites]

@router.post("/favorites", response_model=schemas.Track)
def add_favorite(track: schemas.TrackCreate, db: Session = Depends(get_db)):
    create_track_if_not_exists(db, track)
    fav = db.query(models.Favorite).filter(models.Favorite.track_id == track.video_id).first()
    if not fav:
        new_fav = models.Favorite(track_id=track.video_id)
        db.add(new_fav)
        db.commit()
    return track

@router.delete("/favorites/{video_id}")
def remove_favorite(video_id: str, db: Session = Depends(get_db)):
    fav = db.query(models.Favorite).filter(models.Favorite.track_id == video_id).first()
    if fav:
        db.delete(fav)
        db.commit()
    return {"status": "success"}

@router.get("/playlists", response_model=List[schemas.Playlist])
def get_playlists(db: Session = Depends(get_db)):
    return db.query(models.Playlist).all()

@router.post("/playlists", response_model=schemas.Playlist)
def create_playlist(playlist: schemas.PlaylistCreate, db: Session = Depends(get_db)):
    db_playlist = models.Playlist(id=str(uuid.uuid4()), name=playlist.name)
    db.add(db_playlist)
    db.commit()
    db.refresh(db_playlist)
    return db_playlist

@router.put("/playlists/{playlist_id}", response_model=schemas.Playlist)
def rename_playlist(playlist_id: str, playlist: schemas.PlaylistBase, db: Session = Depends(get_db)):
    db_playlist = db.query(models.Playlist).filter(models.Playlist.id == playlist_id).first()
    if not db_playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    db_playlist.name = playlist.name
    db.commit()
    db.refresh(db_playlist)
    return db_playlist

@router.delete("/playlists/{playlist_id}")
def delete_playlist(playlist_id: str, db: Session = Depends(get_db)):
    db_playlist = db.query(models.Playlist).filter(models.Playlist.id == playlist_id).first()
    if db_playlist:
        db.delete(db_playlist)
        db.commit()
    return {"status": "success"}

@router.post("/playlists/{playlist_id}/tracks")
def add_track_to_playlist(playlist_id: str, track: schemas.TrackCreate, db: Session = Depends(get_db)):
    db_playlist = db.query(models.Playlist).filter(models.Playlist.id == playlist_id).first()
    if not db_playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    
    db_track = create_track_if_not_exists(db, track)
    if db_track not in db_playlist.tracks:
        db_playlist.tracks.append(db_track)
        db.commit()
    return {"status": "success"}

@router.delete("/playlists/{playlist_id}/tracks/{video_id}")
def remove_track_from_playlist(playlist_id: str, video_id: str, db: Session = Depends(get_db)):
    db_playlist = db.query(models.Playlist).filter(models.Playlist.id == playlist_id).first()
    if not db_playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    
    db_track = db.query(models.Track).filter(models.Track.video_id == video_id).first()
    if db_track in db_playlist.tracks:
        db_playlist.tracks.remove(db_track)
        db.commit()
    return {"status": "success"}

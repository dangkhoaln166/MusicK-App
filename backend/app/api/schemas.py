from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class TrackBase(BaseModel):
    video_id: str
    title: str
    thumbnail: Optional[str] = None
    duration: Optional[int] = None
    channel: Optional[str] = None

class TrackCreate(TrackBase):
    pass

class Track(TrackBase):
    class Config:
        from_attributes = True

class PlaylistBase(BaseModel):
    name: str
    cover_image: Optional[str] = None

class PlaylistCreate(PlaylistBase):
    pass

class Playlist(PlaylistBase):
    id: str
    created_at: datetime
    tracks: List[Track] = []

    class Config:
        from_attributes = True

class Setting(BaseModel):
    key: str
    value: str

    class Config:
        from_attributes = True

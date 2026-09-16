from sqlalchemy import Column, String, Integer, ForeignKey, DateTime, Table
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.database import Base

playlist_track_association = Table(
    'playlist_track', Base.metadata,
    Column('playlist_id', String, ForeignKey('playlists.id', ondelete="CASCADE"), primary_key=True),
    Column('track_id', String, ForeignKey('tracks.video_id', ondelete="CASCADE"), primary_key=True)
)

class Track(Base):
    __tablename__ = "tracks"

    video_id = Column(String, primary_key=True, index=True)
    title = Column(String, nullable=False)
    thumbnail = Column(String, nullable=True)
    duration = Column(Integer, nullable=True)
    channel = Column(String, nullable=True)

    playlists = relationship("Playlist", secondary=playlist_track_association, back_populates="tracks")

class Playlist(Base):
    __tablename__ = "playlists"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    cover_image = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    tracks = relationship("Track", secondary=playlist_track_association, back_populates="playlists")

class Favorite(Base):
    __tablename__ = "favorites"

    track_id = Column(String, ForeignKey("tracks.video_id", ondelete="CASCADE"), primary_key=True)
    track = relationship("Track")

class History(Base):
    __tablename__ = "history"

    track_id = Column(String, ForeignKey("tracks.video_id", ondelete="CASCADE"), primary_key=True)
    played_at = Column(DateTime, default=datetime.utcnow)
    track = relationship("Track")

class Setting(Base):
    __tablename__ = "settings"

    key = Column(String, primary_key=True, index=True)
    value = Column(String, nullable=False)

class LyricCache(Base):
    __tablename__ = "lyric_cache"

    query = Column(String, primary_key=True, index=True)
    plain_lyrics = Column(String, nullable=True)
    synced_lyrics = Column(String, nullable=True)
    lang = Column(String, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

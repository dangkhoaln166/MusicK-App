from sqlalchemy import Column, String, Integer, ForeignKey, DateTime, Table
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.database import Base

playlist_track_association = Table(
    'playlist_track', Base.metadata,
    Column('playlist_id', String, ForeignKey('playlists.id', ondelete="CASCADE"), primary_key=True),
    Column('track_id', String, ForeignKey('tracks.video_id', ondelete="CASCADE"), primary_key=True),
    Column('position', Integer, default=0)
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
    user_id = Column(String, index=True, default='default')
    name = Column(String, nullable=False)
    cover_image = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    tracks = relationship("Track", secondary=playlist_track_association, back_populates="playlists", order_by=playlist_track_association.c.position)

class Favorite(Base):
    __tablename__ = "favorites"

    user_id = Column(String, primary_key=True, index=True, default='default')
    track_id = Column(String, ForeignKey("tracks.video_id", ondelete="CASCADE"), primary_key=True)
    position = Column(Integer, default=0)
    track = relationship("Track")

class History(Base):
    __tablename__ = "history"

    user_id = Column(String, primary_key=True, index=True, default='default')
    track_id = Column(String, ForeignKey("tracks.video_id", ondelete="CASCADE"), primary_key=True)
    played_at = Column(DateTime, default=datetime.utcnow)
    track = relationship("Track")

class Setting(Base):
    __tablename__ = "settings"

    user_id = Column(String, primary_key=True, index=True, default='default')
    key = Column(String, primary_key=True, index=True)
    value = Column(String, nullable=False)

class LyricCache(Base):
    __tablename__ = "lyric_cache"

    query = Column(String, primary_key=True, index=True)
    plain_lyrics = Column(String, nullable=True)
    synced_lyrics = Column(String, nullable=True)
    lang = Column(String, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class TranslationCache(Base):
    __tablename__ = "translation_cache"

    id = Column(String, primary_key=True, index=True) # md5 hash of lyrics + target_lang
    translated_text = Column(String, nullable=True)
    romaji_text = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

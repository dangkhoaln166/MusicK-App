import os
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import router
from app.api.db_routes import router as db_router
from app.core.config import settings
from app.db.database import engine, Base

Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.PROJECT_NAME)

# Create and mount downloads directory
DOWNLOADS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "downloads")
THUMBNAILS_DIR = os.path.join(DOWNLOADS_DIR, "thumbnails")
COVERS_DIR = os.path.join(DOWNLOADS_DIR, "covers")
os.makedirs(DOWNLOADS_DIR, exist_ok=True)
os.makedirs(THUMBNAILS_DIR, exist_ok=True)
os.makedirs(COVERS_DIR, exist_ok=True)
app.mount("/api/downloads", StaticFiles(directory=DOWNLOADS_DIR), name="downloads")

# Allow CORS for the Flutter frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api")
app.include_router(db_router, prefix="/api")

@app.get("/")
def read_root():
    return {"status": "ok", "message": "MusicK API is running"}

from fastapi import APIRouter, HTTPException, Query
from app.services import youtube
import asyncio
from concurrent.futures import ThreadPoolExecutor

router = APIRouter()
executor = ThreadPoolExecutor(max_workers=5)

@router.get("/search")
async def search(q: str = Query(..., min_length=1), page: int = Query(1, ge=1), limit: int = Query(15, ge=1, le=50)):
    """Searches YouTube and returns a paginated list of matching videos."""
    try:
        loop = asyncio.get_event_loop()
        max_results = page * limit
        results = await loop.run_in_executor(executor, youtube.extract_search_results, q, max_results)
        
        # Calculate slice
        start_idx = (page - 1) * limit
        end_idx = start_idx + limit
        
        paginated_results = results[start_idx:end_idx] if start_idx < len(results) else []
        
        return {"results": paginated_results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

@router.get("/stream/{video_id}")
async def get_stream(video_id: str):
    """Extracts direct audio and video stream URLs for a given YouTube Video ID."""
    try:
        loop = asyncio.get_event_loop()
        stream_info = await loop.run_in_executor(executor, youtube.extract_stream_urls, video_id)
        return stream_info
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stream extraction failed: {str(e)}")

@router.get("/suggest")
async def suggest(q: str = Query(..., min_length=1)):
    """Fetches autocomplete suggestions from YouTube."""
    try:
        loop = asyncio.get_event_loop()
        suggestions = await loop.run_in_executor(executor, youtube.get_suggestions, q)
        return {"suggestions": suggestions}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Suggest failed: {str(e)}")

@router.get("/lyrics")
async def get_lyrics(q: str = Query(..., min_length=1)):
    """Fetches lyrics for a given query."""
    try:
        loop = asyncio.get_event_loop()
        lyrics = await loop.run_in_executor(executor, youtube.extract_lyrics, q)
        if not lyrics:
            raise HTTPException(status_code=404, detail="Lyrics not found")
        return {"lyrics": lyrics}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lyrics failed: {str(e)}")

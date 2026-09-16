from fastapi import APIRouter, HTTPException, Query, Request, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db import models
import httpx
from app.services import youtube
import os
import asyncio
from concurrent.futures import ThreadPoolExecutor

router = APIRouter()
executor = ThreadPoolExecutor(max_workers=10)

@router.get("/search")
async def search(q: str = Query(...), page: int = Query(1), limit: int = Query(20)):
    try:
        loop = asyncio.get_event_loop()
        results = await loop.run_in_executor(executor, youtube.extract_search_results, q, 20)
        
        # Results now contain "channels" and "tracks"
        tracks = results.get("tracks", [])
        channels = results.get("channels", []) if page == 1 else []
        
        # Calculate slice for tracks
        start_idx = (page - 1) * limit
        end_idx = start_idx + limit
        
        # Paginate tracks
        paginated_tracks = tracks[start_idx:end_idx]
        
        return {
            "results": paginated_tracks, 
            "channels": channels,
            "total": len(tracks), 
            "page": page, 
            "limit": limit
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/explore")
async def get_explore():
    try:
        loop = asyncio.get_event_loop()
        explore_data = await loop.run_in_executor(executor, youtube.get_explore)
        return explore_data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/charts")
async def get_charts():
    try:
        loop = asyncio.get_event_loop()
        charts_data = await loop.run_in_executor(executor, youtube.get_global_charts)
        return charts_data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/channels/{channel_id}/videos")
async def get_channel_videos(channel_id: str, sort_by: str = Query('p'), page: int = Query(1), limit: int = Query(30)):
    try:
        loop = asyncio.get_event_loop()
        videos = await loop.run_in_executor(executor, youtube.get_channel_videos, channel_id, sort_by, page, limit)
        return {"results": videos}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/stream/{video_id}")
async def get_stream(video_id: str, request: Request):
    """Extracts direct audio and video stream URLs for a given YouTube Video ID."""
    try:
        downloads_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "downloads")
        file_path = os.path.join(downloads_dir, f"{video_id}.m4a")
        loop = asyncio.get_event_loop()
        
        if os.path.exists(file_path):
            base_url = str(request.base_url).rstrip("/")
            local_url = f"{base_url}/api/downloads/{video_id}.m4a"
            try:
                stream_info = await loop.run_in_executor(executor, youtube.extract_stream_urls, video_id)
                stream_info["audio_url"] = local_url
            except Exception:
                stream_info = {
                    "video_id": video_id,
                    "audio_url": local_url,
                    "video_url": None,
                    "title": "Offline Track",
                    "duration": 0,
                    "thumbnail": None
                }
            return stream_info
        else:
            stream_info = await loop.run_in_executor(executor, youtube.extract_stream_urls, video_id)
            # Use proxy to avoid CORS and 403 on the web
            base_url = str(request.base_url).rstrip("/")
            proxy_url = f"{base_url}/api/proxy_audio/{video_id}"
            if stream_info and stream_info.get("audio_url"):
                stream_info["audio_url"] = proxy_url
            return stream_info
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stream extraction failed: {str(e)}")

@router.get("/proxy_audio/{video_id}")
async def proxy_audio(video_id: str, request: Request):
    """Proxies the audio stream to bypass CORS and User-Agent blocks."""
    loop = asyncio.get_event_loop()
    try:
        stream_info = await loop.run_in_executor(executor, youtube.extract_stream_urls, video_id)
        audio_url = stream_info.get("audio_url")
        if not audio_url:
            raise HTTPException(status_code=404, detail="Audio URL not found")

        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
        range_header = request.headers.get("range")
        if range_header:
            headers["Range"] = range_header

        client = httpx.AsyncClient(follow_redirects=True)
        req = client.build_request("GET", audio_url, headers=headers)
        resp = await client.send(req, stream=True)

        async def stream_generator():
            try:
                async for chunk in resp.aiter_bytes(chunk_size=8192):
                    yield chunk
            finally:
                await resp.aclose()
                await client.aclose()
                
        response_headers = {
            "Accept-Ranges": "bytes",
        }
        for key in ["Content-Length", "Content-Range", "Content-Type"]:
            if key in resp.headers:
                response_headers[key] = resp.headers[key]
            elif key.lower() in resp.headers:
                response_headers[key] = resp.headers[key.lower()]

        return StreamingResponse(
            stream_generator(),
            status_code=resp.status_code,
            headers=response_headers,
            media_type=response_headers.get("Content-Type", "audio/webm")
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

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
async def get_lyrics(q: str = Query(..., min_length=1), db: Session = Depends(get_db)):
    """Fetches lyrics for a given query, utilizing local database cache."""
    try:
        # 1. Check local cache
        cache_entry = db.query(models.LyricCache).filter(models.LyricCache.query == q).first()
        if cache_entry:
            return {
                "lyrics": {
                    "plainLyrics": cache_entry.plain_lyrics,
                    "syncedLyrics": cache_entry.synced_lyrics,
                    "lang": cache_entry.lang
                }
            }

        # 2. If not in cache, fetch from internet
        loop = asyncio.get_event_loop()
        lyrics = await loop.run_in_executor(executor, youtube.extract_lyrics, q)
        if not lyrics:
            raise HTTPException(status_code=404, detail="Lyrics not found")
        
        # Detect language of the plain lyrics
        lang = 'unknown'
        plain_lyrics = lyrics.get('plainLyrics')
        if plain_lyrics:
            try:
                from langdetect import detect
                lang = detect(plain_lyrics)
            except:
                pass
                
        lyrics['lang'] = lang

        # 3. Save to cache
        new_cache = models.LyricCache(
            query=q,
            plain_lyrics=lyrics.get('plainLyrics'),
            synced_lyrics=lyrics.get('syncedLyrics'),
            lang=lang
        )
        db.add(new_cache)
        db.commit()

        return {"lyrics": lyrics}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lyrics failed: {str(e)}")
        
from pydantic import BaseModel
import re
import pykakasi
from pypinyin import pinyin, Style
from korean_romanizer.romanizer import Romanizer
from langdetect import detect
import urllib.request as _urllib_request
import urllib.parse as _urllib_parse

# Initialize pykakasi globally
kks = pykakasi.kakasi()

def _google_translate(text: str, target_lang: str) -> str:
    """Translates text using the public Google Translate GTX endpoint (no API key needed)."""
    try:
        url = (
            'https://translate.googleapis.com/translate_a/single'
            '?client=gtx&sl=auto&tl=' + _urllib_parse.quote(target_lang)
            + '&dt=t&q=' + _urllib_parse.quote(text)
        )
        req = _urllib_request.Request(url, headers={
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
        with _urllib_request.urlopen(req, timeout=20) as resp:
            import json as _json
            result = _json.loads(resp.read().decode('utf-8'))
            translated = ''.join([item[0] for item in result[0] if item[0]])
            return translated
    except Exception as e:
        print("_google_translate error:", e)
        return ""

class LyricsTranslateRequest(BaseModel):
    lyrics: str
    target_lang: str = "vi" # We keep it for compatibility but won't use it for romaji

@router.post("/translate_lyrics")
async def translate_lyrics(req: LyricsTranslateRequest):
    """Generates Romaji using offline packages."""
    try:
        lines = req.lyrics.split('\n')
        text_lines = []
        tags = []
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            match = re.match(r'^(\[[0-9:\.]+\])(.*)', line)
            if match:
                tags.append(match.group(1))
                text_lines.append(match.group(2).strip())
            else:
                tags.append("")
                text_lines.append(line)
                
        # Handle empty case
        if not text_lines:
            return {"translated": "", "romaji": ""}
            
        full_text = "\n".join(text_lines)
        try:
            lang = detect(full_text)
        except:
            lang = 'unknown'

        out_romaji = []
        out_translated = []
        
        # Translate line by line using the GTX endpoint
        trans_lines = []
        translation_failed = False
        try:
            # Translate all lines at once joined by newlines
            combined = '\n'.join(text_lines)
            trans_combined = _google_translate(combined, req.target_lang)
            if trans_combined:
                trans_lines = trans_combined.split('\n')
                # If line count mismatch, translate each line individually
                if len(trans_lines) != len(text_lines):
                    trans_lines = []
                    for l in text_lines:
                        if l.strip():
                            t = _google_translate(l, req.target_lang)
                            trans_lines.append(t if t else l)
                        else:
                            trans_lines.append(l)
            else:
                translation_failed = True
        except Exception as e:
            print("Translate error:", e)
            translation_failed = True
            trans_lines = []
            
        for i in range(len(tags)):
            line = text_lines[i]
            r_line = line
            t_line = ""
            
            if line:
                if lang == 'ja':
                    res = kks.convert(line)
                    r_line = ' '.join([item['hepburn'] for item in res])
                elif lang.startswith('zh'):
                    r_line = ' '.join([item[0] for item in pinyin(line, style=Style.NORMAL)])
                elif lang == 'ko':
                    try:
                        r_line = Romanizer(line).romanize()
                    except:
                        pass
                
                # Assign translated line if available
                if i < len(trans_lines):
                    t_line = trans_lines[i].strip()
                        
            out_romaji.append(f"{tags[i]}{r_line}")
            if trans_lines: # Only append to translated if translation succeeded
                if t_line:
                    out_translated.append(f"{tags[i]}{t_line}")
                else:
                    out_translated.append(f"{tags[i]}{line}") # fallback to original if missing
            
        return {
            "translated": "\n".join(out_translated) if trans_lines else "",
            "romaji": "\n".join(out_romaji)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

import yt_dlp
import urllib.request
import json
from urllib.parse import quote
from typing import List, Dict, Any, Optional
import os
import threading

from ytmusicapi import YTMusic
ytmusic = YTMusic()

# --- Timeout helper ---
class TimeoutError(Exception):
    pass

def _run_with_timeout(func, args=(), kwargs={}, timeout_secs=30):
    """Runs func(*args, **kwargs) in a thread; raises TimeoutError if it takes too long."""
    result = [None]
    exc = [None]

    def target():
        try:
            result[0] = func(*args, **kwargs)
        except Exception as e:
            exc[0] = e

    t = threading.Thread(target=target, daemon=True)
    t.start()
    t.join(timeout_secs)
    if t.is_alive():
        raise TimeoutError(f"{func.__name__} timed out after {timeout_secs}s")
    if exc[0]:
        raise exc[0]
    return result[0]

def extract_search_results(query: str, max_results: int = 15) -> List[Dict[str, Any]]:
    # Search specifically for 'songs' to get Official Audio instead of Music Videos with cinematic intros.
    # This guarantees perfect synchronization with LrcLib lyrics.
    results = ytmusic.search(query, filter="songs", limit=max_results)
    
    formatted_results = []
    for entry in results:
        if entry.get("videoId"):
            # Get the best thumbnail
            thumbnails = entry.get("thumbnails", [])
            best_thumb = thumbnails[-1].get("url") if thumbnails else None
            
            # Get artists
            artists = entry.get("artists", [])
            channel = artists[0].get("name") if artists else "Unknown Artist"
            
            import re
            
            # format duration
            duration_str = entry.get("duration", "")
            if not duration_str and entry.get("duration_seconds"):
                ds = entry.get("duration_seconds")
                duration_str = f"{ds//60}:{ds%60:02d}"
            
            formatted_results.append({
                "video_id": entry.get("videoId"),
                "title": f"{entry.get('title')} - {channel}",
                "duration": duration_str,
                "thumbnail": best_thumb,
                "channel": channel
            })
            
    return formatted_results

def _do_extract_stream_urls(video_id: str) -> Dict[str, Optional[str]]:
    video_url = f"https://www.youtube.com/watch?v={video_id}"
    
    def _try_extract(extra_opts: dict = {}):
        ydl_opts = {
            'format': 'bestaudio/best',
            'quiet': True,
            'noplaylist': True,
            'socket_timeout': 15,
            'http_headers': {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
            },
        }
        ydl_opts.update(extra_opts)
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            return ydl.extract_info(video_url, download=False)
    
    # Try with Chrome cookies first (bypasses bot detection)
    info = None
    for browser in ['chrome', 'edge', 'firefox']:
        try:
            info = _try_extract({'cookiesfrombrowser': (browser, None, None, None)})
            if info:
                break
        except Exception:
            continue
    
    # Last resort: no cookies
    if not info:
        info = _try_extract()
    
    # Extract audio and video format URLs from the info dict
    audio_url = None
    video_url_stream = None
    
    formats = info.get('formats', [])
    
    # 1. Best pure audio stream
    audio_formats = [f for f in formats if f.get('acodec') != 'none' and f.get('vcodec') == 'none']
    if audio_formats:
        # Prioritize m4a (AAC) format for better compatibility with just_audio on web
        m4a_formats = [f for f in audio_formats if f.get('ext') == 'm4a']
        if m4a_formats:
            best_audio = sorted(m4a_formats, key=lambda x: x.get('abr') or 0, reverse=True)[0]
        else:
            best_audio = sorted(audio_formats, key=lambda x: x.get('abr') or 0, reverse=True)[0]
        audio_url = best_audio.get('url')
        
    # 2. Best video stream (without or with audio)
    video_formats = [f for f in formats if f.get('vcodec') != 'none']
    if video_formats:
        mp4_videos = [f for f in video_formats if f.get('ext') == 'mp4']
        video_list = mp4_videos if mp4_videos else video_formats
        good_videos = [f for f in video_list if f.get('height') in (1080, 720)]
        if good_videos:
            best_video = good_videos[0]
        else:
            best_video = sorted(video_list, key=lambda x: x.get('height') or 0, reverse=True)[0]
        video_url_stream = best_video.get('url')
        
    # Fallbacks
    if not audio_url:
        audio_url = info.get('url')
    if not video_url_stream:
        video_url_stream = info.get('url')

    return {
        "video_id": video_id,
        "title": info.get("title"),
        "duration": info.get("duration"),
        "thumbnail": info.get("thumbnail"),
        "audio_url": audio_url,
        "video_url": video_url_stream,
    }

def extract_stream_urls(video_id: str) -> Dict[str, Optional[str]]:
    """Extracts stream URLs with a 45-second hard timeout to prevent hanging."""
    return _run_with_timeout(_do_extract_stream_urls, args=(video_id,), timeout_secs=45)

def get_suggestions(query: str) -> List[str]:
    url = f"http://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q={quote(query)}"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=5) as response:
            data = json.loads(response.read().decode('utf-8'))
            if len(data) > 1 and isinstance(data[1], list):
                return data[1]
    except Exception as e:
        print(f"Error fetching suggestions: {e}")
    return []

import re

def _fetch_lrclib(query: str) -> Optional[Dict[str, Optional[str]]]:
    url = f"https://lrclib.net/api/search?q={quote(query)}"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'MusicK/1.0'})
        with urllib.request.urlopen(req, timeout=8) as response:
            data = json.loads(response.read().decode('utf-8'))
            if isinstance(data, list) and len(data) > 0:
                for track in data:
                    if track.get('plainLyrics') or track.get('syncedLyrics'):
                        return {
                            "plainLyrics": track.get('plainLyrics'),
                            "syncedLyrics": track.get('syncedLyrics')
                        }
    except Exception as e:
        pass
    return None

def extract_lyrics(query: str) -> Optional[Dict[str, Optional[str]]]:
    # Try the original query
    res = _fetch_lrclib(query)
    if res: return res

    # 1. Clean the title from parentheses, brackets, "official"
    clean_query = re.sub(r'\(.*?\)', '', query)
    clean_query = re.sub(r'\[.*?\]', '', clean_query)
    clean_query = re.sub(r'(?i)official.*', '', clean_query)
    clean_query = clean_query.replace('|', ' ').replace('-', ' ')
    clean_query = re.sub(r'\s+', ' ', clean_query).strip()

    if clean_query != query and clean_query:
        res = _fetch_lrclib(clean_query)
        if res: return res

    # 2. Try the first part before a pipe or dash, in case it's "Song Name - Artist" or "Song Name | Artist"
    if '|' in query:
        first_part = query.split('|')[0].strip()
        res = _fetch_lrclib(first_part)
        if res: return res
        
    if '-' in query:
        first_part = query.split('-')[0].strip()
        res = _fetch_lrclib(first_part)
        if res: return res

    return None

def download_audio_background(video_id: str):
    """
    Downloads the audio of a YouTube video in the background to the downloads folder.
    """
    downloads_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "downloads")
    os.makedirs(downloads_dir, exist_ok=True)
    
    file_path = os.path.join(downloads_dir, f"{video_id}.m4a")
    if os.path.exists(file_path):
        return # Already downloaded
    
    video_url = f"https://www.youtube.com/watch?v={video_id}"
    ydl_opts = {
        'format': 'bestaudio[ext=m4a]/bestaudio/best',
        'outtmpl': os.path.join(downloads_dir, f"{video_id}.%(ext)s"),
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'm4a',
            'preferredquality': '192',
        }],
        'quiet': True,
        'noplaylist': True,
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([video_url])
            print(f"Downloaded audio for {video_id}")
    except Exception as e:
        print(f"Failed to download audio for {video_id}: {e}")


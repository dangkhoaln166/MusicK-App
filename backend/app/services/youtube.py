import yt_dlp
import urllib.request
import json
from urllib.parse import quote
from typing import List, Dict, Any, Optional

def extract_search_results(query: str, max_results: int = 10) -> List[Dict[str, Any]]:
    ydl_opts = {
        'format': 'best',
        'noplaylist': True,
        'extract_flat': True,
        'quiet': True,
    }
    
    # ytsearch{n}:query syntax
    search_query = f"ytsearch{max_results}:{query}"
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        result = ydl.extract_info(search_query, download=False)
        if 'entries' in result:
            return [
                {
                    "video_id": entry.get("id"),
                    "title": entry.get("title"),
                    "duration": entry.get("duration"),
                    "thumbnail": entry.get("thumbnails", [{}])[-1].get("url") if entry.get("thumbnails") else None,
                    "channel": entry.get("uploader")
                }
                for entry in result['entries'] if entry
            ]
        return []

def extract_stream_urls(video_id: str) -> Dict[str, Optional[str]]:
    video_url = f"https://www.youtube.com/watch?v={video_id}"
    ydl_opts = {
        'format': 'bestaudio/best', # Focus on best audio
        'quiet': True,
        'noplaylist': True,
    }
    
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(video_url, download=False)
        
        audio_url = None
        video_url_stream = None
        
        formats = info.get('formats', [])
        
        # 1. Best pure audio stream
        audio_formats = [f for f in formats if f.get('acodec') != 'none' and f.get('vcodec') == 'none']
        if audio_formats:
            best_audio = sorted(audio_formats, key=lambda x: x.get('abr') or 0, reverse=True)[0]
            audio_url = best_audio.get('url')
            
        # 2. Best video stream (without or with audio)
        video_formats = [f for f in formats if f.get('vcodec') != 'none']
        if video_formats:
            # We prefer MP4 for broader compatibility
            mp4_videos = [f for f in video_formats if f.get('ext') == 'mp4']
            video_list = mp4_videos if mp4_videos else video_formats
            
            # Prioritize 720p/1080p for good balance
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

def extract_lyrics(query: str) -> Optional[Dict[str, Optional[str]]]:
    # LrcLib is a great free open API for lyrics
    url = f"https://lrclib.net/api/search?q={quote(query)}"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'MusicK/1.0'})
        with urllib.request.urlopen(req, timeout=5) as response:
            data = json.loads(response.read().decode('utf-8'))
            if isinstance(data, list) and len(data) > 0:
                for track in data:
                    if track.get('plainLyrics') or track.get('syncedLyrics'):
                        return {
                            "plainLyrics": track.get('plainLyrics'),
                            "syncedLyrics": track.get('syncedLyrics')
                        }
    except Exception as e:
        print(f"Error fetching lyrics: {e}")
    return None

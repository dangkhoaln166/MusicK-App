import yt_dlp
import urllib.request
import json
from urllib.parse import quote
from typing import List, Dict, Any, Optional
import os
import re
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

def extract_channels(query: str, max_results: int = 3) -> List[Dict[str, Any]]:
    url = f"https://www.youtube.com/results?search_query={quote(query)}&sp=EgIQAg%253D%253D"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    try:
        html = urllib.request.urlopen(req).read().decode('utf-8')
        match = re.search(r'ytInitialData\s*=\s*({.*?});', html)
        if match:
            data = json.loads(match.group(1))
            channels = []
            contents = data.get('contents', {}).get('twoColumnSearchResultsRenderer', {}).get('primaryContents', {}).get('sectionListRenderer', {}).get('contents', [])
            for content in contents:
                items = content.get('itemSectionRenderer', {}).get('contents', [])
                for item in items:
                    channel = item.get('channelRenderer')
                    if channel:
                        title = channel.get('title', {}).get('simpleText')
                        channel_id = channel.get('channelId')
                        subscribers = channel.get('subscriberCountText', {}).get('simpleText')
                        thumbnails = channel.get('thumbnail', {}).get('thumbnails', [])
                        avatar = thumbnails[-1].get('url') if thumbnails else None
                        if avatar and avatar.startswith('//'):
                            avatar = 'https:' + avatar
                        
                        channels.append({
                            "channel_id": channel_id,
                            "title": title,
                            "subscribers": subscribers,
                            "avatar": avatar
                        })
                        if len(channels) >= max_results:
                            return channels
            return channels
    except Exception as e:
        print(f"Error scraping channels: {e}")
    return []

def extract_search_results(query: str, max_results: int = 15) -> Dict[str, Any]:
    channels = extract_channels(query, max_results=2)
    
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
            
    return {"channels": channels, "tracks": formatted_results}

def get_channel_videos(channel_id: str, sort_by: str = 'p', page: int = 1, limit: int = 30) -> List[Dict[str, Any]]:
    path = "popular" if sort_by == 'p' else "videos"
    url = f"https://www.youtube.com/channel/{channel_id}/{path}"
    start_idx = (page - 1) * limit + 1
    end_idx = page * limit
    ydl_opts = {
        'extract_flat': True,
        'quiet': True,
        'playlist_items': f'{start_idx}-{end_idx}'
    }
    
    entries = []
    channel_name = "Channel"
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            entries = info.get('entries', [])
            channel_name = info.get('uploader') or info.get('channel') or "Channel"
    except Exception as e:
        if sort_by == 'p' and "does not have a popular tab" in str(e):
            # Fallback to manual sorting of the latest videos
            url = f"https://www.youtube.com/channel/{channel_id}/videos"
            ydl_opts['playlist_items'] = '1-200' # Fetch a large pool to sort
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                raw_entries = info.get('entries', [])
                channel_name = info.get('uploader') or info.get('channel') or "Channel"
                
                # Sort manually by view count
                sorted_entries = sorted(
                    raw_entries,
                    key=lambda x: x.get('view_count') or 0,
                    reverse=True
                )
                
                # Paginate locally
                start_i = (page - 1) * limit
                end_i = page * limit
                entries = sorted_entries[start_i:end_i]
        else:
            raise e
            
    formatted_results = []
    for entry in entries:
        title = entry.get('title')
        video_id = entry.get('id')
        if not video_id:
            continue
            
        thumbnails = entry.get('thumbnails', [])
        best_thumb = thumbnails[-1].get('url') if thumbnails else None
        
        duration_secs = entry.get('duration')
        duration_str = ""
        if duration_secs:
            duration_str = f"{int(duration_secs)//60}:{int(duration_secs)%60:02d}"
            
        formatted_results.append({
            "video_id": video_id,
            "title": f"{title} - {channel_name}",
            "duration": duration_str,
            "thumbnail": best_thumb,
            "channel": channel_name
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
                            "syncedLyrics": None  # Disabled to avoid sync issues with non-official audio
                        }
    except Exception as e:
        pass
    return None

def _fetch_youtube_subtitles(video_id: str) -> Optional[Dict[str, Optional[str]]]:
    ydl_opts = {
        'quiet': True,
        'skip_download': True,
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_id, download=False)
            subs = info.get('subtitles', {})
            auto_subs = info.get('automatic_captions', {})
            
            # Prefer manual subtitles, then auto-captions. Prefer 'vi', then 'en'
            target_subs = subs.get('vi') or subs.get('en') or auto_subs.get('vi') or auto_subs.get('en')
            if not target_subs:
                return None
            
            json3_sub = next((s for s in target_subs if s.get('ext') == 'json3'), None)
            if not json3_sub:
                return None
                
            req = urllib.request.Request(json3_sub['url'], headers={'User-Agent': 'Mozilla/5.0'})
            resp = urllib.request.urlopen(req)
            data = json.loads(resp.read())
            
            lrc_lines = []
            plain_lines = []
            for event in data.get('events', []):
                start_ms = event.get('tStartMs', 0)
                segs = event.get('segs', [])
                text = "".join(seg.get('utf8', '') for seg in segs).strip()
                if not text:
                    continue
                
                lines = text.split('\n')
                duration_per_line = event.get('dDurationMs', 0) / max(1, len(lines))
                for i, line in enumerate(lines):
                    if not line.strip(): continue
                    line_start = start_ms + int(i * duration_per_line)
                    minutes = line_start // 60000
                    seconds = (line_start % 60000) / 1000
                    lrc_lines.append(f"[{minutes:02d}:{seconds:05.2f}]{line}")
                    plain_lines.append(line)
                    
            if not lrc_lines:
                return None
                
            return {
                "plainLyrics": "\n".join(plain_lines),
                "syncedLyrics": "\n".join(lrc_lines)
            }
    except Exception as e:
        print("YT Subtitle fetch error:", e)
        return None

def extract_lyrics(query: str, video_id: str = None) -> Optional[Dict[str, Optional[str]]]:
    if video_id:
        yt_lyrics = _fetch_youtube_subtitles(video_id)
        if yt_lyrics:
            return yt_lyrics

    # Try the original query
    res = _fetch_lrclib(query)
    if res: return res

    # 1. Clean the title from parentheses, brackets
    clean_query = re.sub(r'\(.*?\)', '', query)
    clean_query = re.sub(r'\[.*?\]', '', clean_query)
    
    # Remove common noise words (case insensitive)
    noise_words = [
        'official video', 'official music video', 'official audio', 'official',
        'lyric video', 'lyrics', 'lyric', 'top tik tok', 'tik tok', 'tiktok',
        'remix', 'cover', 'nightcore', 'sped up', 'slowed', 'reverb', 'audio',
        'mv', 'hd', 'hq', 'live', 'performance'
    ]
    for word in noise_words:
        clean_query = re.sub(r'(?i)\b' + word + r'\b', '', clean_query)
    
    # Remove extra spaces or trailing hyphens
    clean_query = re.sub(r'\s+', ' ', clean_query).replace(' - - ', ' - ').strip(' -|')

    if clean_query != query and clean_query:
        res = _fetch_lrclib(clean_query)
        if res: return res

    # 2. Try swapping or cleaning around dash
    if '-' in clean_query:
        parts = clean_query.split('-')
        if len(parts) >= 2:
            # Maybe the dash was separating artist and title, but one side has garbage.
            # Try just combining them without the dash
            combined = (parts[0].strip() + ' ' + parts[1].strip()).strip()
            res = _fetch_lrclib(combined)
            if res: return res
            
            # If still nothing, try the first part (risky, might get popular covers like Rihanna's Umbrella)
            # Only do this if it's very long and likely to fail otherwise
            if len(combined) > 30:
                res = _fetch_lrclib(parts[0].strip())
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

def get_explore() -> Dict[str, List[Dict[str, Any]]]:
    try:
        explore_data = ytmusic.get_explore()
    except Exception as e:
        print(f"Error fetching explore data: {e}")
        return {"trending": [], "new_releases": []}
    
    def parse_items(key: str) -> List[Dict[str, Any]]:
        results = []
        if key in explore_data and 'items' in explore_data[key]:
            for item in explore_data[key]['items']:
                video_id = item.get('videoId')
                if not video_id:
                    continue
                
                artists = item.get('artists', [])
                channel = artists[0].get('name') if artists else "Unknown Artist"
                
                thumbnails = item.get('thumbnails', [])
                best_thumb = thumbnails[-1].get('url') if thumbnails else None
                
                title = item.get('title', '')
                
                results.append({
                    "video_id": video_id,
                    "title": f"{title} - {channel}" if channel else title,
                    "duration": None,
                    "thumbnail": best_thumb,
                    "channel": channel
                })
        return results

    return {
        "trending": parse_items('trending'),
        "new_releases": parse_items('new_videos')
    }

def get_global_charts() -> Dict[str, List[Dict[str, Any]]]:
    from concurrent.futures import ThreadPoolExecutor, as_completed
    
    playlists = {
        "Global": "PL4fGSI1pDJn5kI81J1fYWK5eZRl1zJ5kM",
        "VN": "PL4fGSI1pDJn4FPCRZtojwqQro5GPY6cuV",
        "US": "PL4fGSI1pDJn69On1f-8NAvX_CYlx7QyZc",
        "KR": "PL4fGSI1pDJn5S09aId3dUGp40ygUqmPGc",
        "UK": "PL4fGSI1pDJn688ebB8czINn0_nov50e3A"
    }
    
    def fetch_playlist(country, playlist_id):
        try:
            pl = ytmusic.get_playlist(playlist_id, limit=20)
            tracks = []
            for track in pl.get('tracks', [])[:20]:
                video_id = track.get('videoId')
                if not video_id:
                    continue
                
                artists = track.get('artists', [])
                channel = artists[0].get('name') if artists else "Unknown Artist"
                title = track.get('title', '')
                
                thumbnails = track.get('thumbnails', [])
                best_thumb = thumbnails[-1].get('url') if thumbnails else None
                
                duration_parts = track.get('duration', '0:00').split(':')
                duration_sec = 0
                if len(duration_parts) == 2:
                    duration_sec = int(duration_parts[0]) * 60 + int(duration_parts[1])
                elif len(duration_parts) == 3:
                    duration_sec = int(duration_parts[0]) * 3600 + int(duration_parts[1]) * 60 + int(duration_parts[2])
                    
                tracks.append({
                    "video_id": video_id,
                    "title": title,
                    "duration": duration_sec,
                    "thumbnail": best_thumb,
                    "channel": channel
                })
            return country, tracks
        except Exception as e:
            print(f"Failed to fetch chart {country}: {e}")
            return country, []

    results = {}
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = {executor.submit(fetch_playlist, c, pid): c for c, pid in playlists.items()}
        for future in as_completed(futures):
            country, tracks = future.result()
            results[country] = tracks
            
    return results

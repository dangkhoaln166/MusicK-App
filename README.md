# MusicK 

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)
![Python](https://img.shields.io/badge/Python-14354C?style=for-the-badge&logo=python&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)

MusicK is a modern, high-performance music streaming application built with a **Flutter** frontend and a **FastAPI (Python)** backend. It provides a seamless listening experience with real-time audio playback, playlist management, and a stunning Glassmorphism UI.

##  Features

- **Modern UI/UX**: Cyberpunk-inspired dark theme, glassmorphic elements, and ultra-smooth tactile animations.
- **Audio Streaming**: Seamless background playback with full audio controls (Loop, Shuffle, Next/Previous) using `just_audio`.
- **Dynamic MiniPlayer**: Persistent player across all screens that expands into a beautiful full-screen player.
- **Playlist Management**: Create, edit, and organize your favorite tracks into custom playlists.
- **Real-time Search**: Fast and intelligent search capabilities to discover new music.
- **Responsive Layout**: Optimized for both mobile devices and desktop web browsers.

##  Technology Stack

### Frontend
- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Audio Engine**: just_audio, audio_session
- **UI Design**: Custom animations (`AnimatedScale`, `AnimatedSwitcher`), Glassmorphism (`BackdropFilter`).

### Backend
- **Framework**: FastAPI (Python)
- **Server**: Uvicorn
- **Integration**: yt-dlp (for audio extraction)
- **Architecture**: RESTful APIs with asynchronous processing.

##  Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Python 3.9+
- FFmpeg (for audio processing)

### Backend Setup
```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python -m uvicorn app.main:app --reload
```

### Frontend Setup
```bash
cd frontend
flutter pub get
flutter run
```

##  Screenshots



##  Contributing

Contributions, issues, and feature requests are welcome!

##  License

This project is open-source and available under the MIT License.

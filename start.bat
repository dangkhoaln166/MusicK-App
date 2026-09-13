@echo off
echo ====================================================
echo    MusicK - Starting with Persistent Browser Data
echo ====================================================
echo.
echo Backend and Frontend will start automatically.
echo Your playlists and favorites will be SAVED permanently.
echo.
echo Instructions:
echo   - Press Ctrl+C in this window to stop
echo   - Press F5 in the browser to reload (data stays!)
echo.
echo Starting backend...
start "MusicK Backend" cmd /k "cd /d d:\MusicK\backend && .\venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"

timeout /t 3 >nul

echo Starting frontend with persistent Chrome profile...
cd /d d:\MusicK\frontend
flutter run -d chrome --web-browser-flag="--user-data-dir=C:\Users\dangk\AppData\Local\MusicKProfile" --web-browser-flag="--no-first-run" --web-browser-flag="--no-default-browser-check"

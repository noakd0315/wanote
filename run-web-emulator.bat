@echo off
cd /d "%~dp0"
"C:\flutter\bin\flutter.bat" run -d web-server --web-port 5000 --web-hostname 0.0.0.0 --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=AI_BACKEND_BASE_URL=http://localhost:8787

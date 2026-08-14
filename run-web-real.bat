@echo off
rem Runs the web build against the REAL Firebase project (wanote-7dca0).
rem No USE_FIREBASE_EMULATOR, so main.dart picks DefaultFirebaseOptions.
rem Port 5001 so it can run alongside the emulator build on 5000.
cd /d "%~dp0"
"C:\flutter\bin\flutter.bat" run -d web-server --web-port 5001 --web-hostname localhost

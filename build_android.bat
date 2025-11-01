@echo off
echo ============================================
echo Building Android App Bundle with Supabase credentials
echo ============================================

flutter build appbundle --release ^
  --dart-define="SUPABASE_URL=https://pyfughpblzbgrfuhymka.supabase.co" ^
  --dart-define="SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5ZnVnaHBibHpiZ3JmdWh5bWthIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2NDEyOTEsImV4cCI6MjA3MzIxNzI5MX0.Tbqs9wWyS3FGpQHKVcy1fsGI_Mi5cDShJJ13Ta-QVbg"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================
    echo BUILD SUCCESSFUL!
    echo ============================================
    echo.
    echo Upload this file to Play Console:
    echo build\app\outputs\bundle\release\app-release.aab
    echo.
) else (
    echo.
    echo ============================================
    echo BUILD FAILED!
    echo ============================================
    echo.
)

pause

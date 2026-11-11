@echo off
chcp 65001 >nul
cd /d "%~dp0"
title El-Alfy ERP - Auto Release (Version + Build + GitHub Push)

if exist "D:\flutter\bin" set "PATH=D:\flutter\bin;%PATH%"
if exist "C:\flutter\bin" set "PATH=C:\flutter\bin;%PATH%"
if exist "C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot" set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot"
if exist "%JAVA_HOME%\bin" set "PATH=%JAVA_HOME%\bin;%PATH%"
if exist "D:\Android\Sdk" set "ANDROID_HOME=D:\Android\Sdk"

where flutter >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Flutter not found!
    pause
    exit /b 1
)

where python >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Python not found!
    pause
    exit /b 1
)

:: Get current version from pubspec.yaml
for /f "tokens=2 delims=: " %%a in ('findstr /b "version:" pubspec.yaml') do set "FULL_VER=%%a"
for /f "tokens=1 delims=+" %%v in ("%FULL_VER%") do set "CUR_VER=%%v"

echo ====================================================================
echo             El-Alfy ERP - Automatic Release Manager
echo             Current Version: v%CUR_VER%
echo ====================================================================
echo.
echo Choose version update type (auto-selects [1] Patch in 10s):
echo   [1] Patch  (e.g. 1.0.0 -^> 1.0.1)  [Default]
echo   [2] Minor  (e.g. 1.0.0 -^> 1.1.0)
echo   [3] Major  (e.g. 1.0.0 -^> 2.0.0)
echo   [4] Custom (Enter version manually)
echo.
choice /c 1234 /n /t 10 /d 1 /m "Select [1-4]: "
set "SEL=%errorlevel%"

if "%SEL%"=="4" (
    set /p CUSTOM_VER="Enter new version (e.g. 1.2.0): "
    for /f %%i in ('python scripts\bump_version.py custom %CUSTOM_VER%') do set "NEW_VER=%%i"
) else if "%SEL%"=="3" (
    for /f %%i in ('python scripts\bump_version.py major') do set "NEW_VER=%%i"
) else if "%SEL%"=="2" (
    for /f %%i in ('python scripts\bump_version.py minor') do set "NEW_VER=%%i"
) else (
    for /f %%i in ('python scripts\bump_version.py patch') do set "NEW_VER=%%i"
)

if "%NEW_VER%"=="" (
    echo [ERROR] Failed to update version!
    pause
    exit /b 1
)

echo.
echo [1/4] Updated version: v%CUR_VER% -^> v%NEW_VER%
echo.

echo [2/4] Fetching dependencies and building APK (v%NEW_VER%)...
call flutter pub get
if errorlevel 1 (
    echo [ERROR] flutter pub get failed!
    pause
    exit /b 1
)

call flutter build apk --release
if errorlevel 1 (
    echo [ERROR] flutter build apk failed!
    pause
    exit /b 1
)

if not exist "releases" mkdir "releases"
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "releases\el-Alfy-v%NEW_VER%.apk" >nul
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "releases\el-Alfy-latest.apk" >nul
echo Saved local APK to: %cd%\releases\el-Alfy-v%NEW_VER%.apk
echo.

echo [3/4] Committing changes to Git...
git add .
git commit -m "Release v%NEW_VER%"
echo.

echo [4/4] Pushing to GitHub (triggers cloud APK build & Release link)...
git push origin main
if errorlevel 1 (
    echo.
    echo [WARNING] Git push failed or requires authentication.
    echo Please sign in to GitHub when prompted or run 'git push origin main' manually.
    pause
    exit /b 1
)

echo.
echo ====================================================================
echo [SUCCESS] Release v%NEW_VER% Completed!
echo.
echo 1. Local APK inside project:
echo    %cd%\releases\el-Alfy-v%NEW_VER%.apk
echo.
echo 2. GitHub Cloud Build & Download Link (ready in ~2-3 mins):
echo    https://github.com/emontal90/el-alfy-90/releases/latest
echo    Direct APK Download Link:
echo    https://github.com/emontal90/el-alfy-90/releases/latest/download/el-Alfy-App.apk
echo ====================================================================
echo.
explorer "releases"
pause


@echo off
chcp 65001 >nul
cd /d "%~dp0"
title El-Alfy ERP - Auto Build APK

if exist "D:\flutter\bin" set "PATH=D:\flutter\bin;%PATH%"
if exist "C:\flutter\bin" set "PATH=C:\flutter\bin;%PATH%"
if exist "C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot" set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot"
if exist "%JAVA_HOME%\bin" set "PATH=%JAVA_HOME%\bin;%PATH%"
if exist "D:\Android\Sdk" set "ANDROID_HOME=D:\Android\Sdk"

where flutter >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Flutter not found at D:\flutter\bin or in PATH.
    pause
    exit /b 1
)

:: Extract current version from pubspec.yaml
for /f "tokens=2 delims=: " %%a in ('findstr /b "version:" pubspec.yaml') do set "FULL_VER=%%a"
for /f "tokens=1 delims=+" %%v in ("%FULL_VER%") do set "APP_VER=%%v"
if "%APP_VER%"=="" set "APP_VER=1.0.0"

echo ====================================================================
echo            El-Alfy ERP - Automatic APK Builder (v%APP_VER%)
echo ====================================================================
echo.
echo [1/3] Fetching packages...
call flutter pub get
if errorlevel 1 (
    echo [ERROR] flutter pub get failed.
    pause
    exit /b 1
)

echo.
echo [2/3] Building Release APK...
call flutter build apk --release
if errorlevel 1 (
    echo [ERROR] APK build failed!
    pause
    exit /b 1
)

echo.
echo [3/3] Saving APK inside project folder (releases\)...
if not exist "releases" mkdir "releases"
if exist "releases\*.apk" del /Q "releases\*.apk" >nul 2>nul
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "releases\el-Alfy-v%APP_VER%.apk" >nul
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "releases\el-Alfy-latest.apk" >nul

echo.
echo ====================================================================
echo [SUCCESS] APK Built Successfully!
echo Saved inside project folder:
echo   %cd%\releases\el-Alfy-v%APP_VER%.apk
echo   %cd%\releases\el-Alfy-latest.apk
echo ====================================================================
echo.
start "" explorer "releases"
pause
exit /b 0

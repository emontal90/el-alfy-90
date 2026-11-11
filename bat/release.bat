@echo off
setlocal enableextensions
cd /d "%~dp0.."
title El-Alfy ERP - Auto Release

if exist "D:\flutter\bin" set "PATH=D:\flutter\bin;%PATH%"
if exist "C:\flutter\bin" set "PATH=C:\flutter\bin;%PATH%"
if exist "C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot" set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot"
if defined JAVA_HOME (
    if exist "%JAVA_HOME%\bin" set "PATH=%JAVA_HOME%\bin;%PATH%"
)
if exist "D:\Android\Sdk" set "ANDROID_HOME=D:\Android\Sdk"

where flutter >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Flutter not found!
    goto :FAIL
)

where python >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Python not found!
    goto :FAIL
)

where git >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Git not found!
    goto :FAIL
)

:: Get current version from pubspec.yaml
set "FULL_VER="
set "CUR_VER="
for /f "tokens=2 delims=: " %%a in ('findstr /b "version:" pubspec.yaml') do set "FULL_VER=%%a"
for /f "tokens=1 delims=+" %%v in ("%FULL_VER%") do set "CUR_VER=%%v"
if "%CUR_VER%"=="" set "CUR_VER=unknown"

echo ====================================================================
echo             El-Alfy ERP - Automatic Release Manager
echo             Current Version: v%CUR_VER%
echo ====================================================================
echo.

set "BUMP_MODE=patch"
if not "%~1"=="" set "BUMP_MODE=%~1"

set "NEW_VER="
if /i "%BUMP_MODE%"=="custom" (
    if "%~2"=="" (
        echo [ERROR] Custom version requires second argument ^(e.g. release.bat custom 1.2.0^)
        goto :FAIL
    )
    for /f "usebackq delims=" %%i in (`python scripts\bump_version.py custom %~2`) do set "NEW_VER=%%i"
) else (
    for /f "usebackq delims=" %%i in (`python scripts\bump_version.py %BUMP_MODE%`) do set "NEW_VER=%%i"
)

:CHECK_VER
if "%NEW_VER%"=="" (
    echo [ERROR] Failed to update version!
    goto :FAIL
)

echo.
echo [1/4] Version updated: v%CUR_VER% -^> v%NEW_VER%
echo.

echo [2/4] Fetching packages and building Release APK (v%NEW_VER%)...
call flutter pub get
if errorlevel 1 (
    echo [ERROR] flutter pub get failed!
    goto :FAIL
)

call flutter build apk --release
if errorlevel 1 (
    echo [ERROR] flutter build apk failed!
    goto :FAIL
)

if not exist "releases" mkdir "releases"
if exist "releases\*.apk" del /Q "releases\*.apk" >nul 2>nul
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "releases\el-Alfy-v%NEW_VER%.apk" >nul
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "releases\el-Alfy-latest.apk" >nul
echo Saved APK to: %cd%\releases\el-Alfy-v%NEW_VER%.apk
echo.

echo [3/4] Committing changes to Git...
git add -A
git commit -m "Release v%NEW_VER%"
if errorlevel 1 (
    echo [ERROR] git commit failed!
    goto :FAIL
)
echo.

echo [4/4] Pushing changes to GitHub...
git push origin main
if errorlevel 1 (
    echo.
    echo [ERROR] Git push failed! Please check your internet or GitHub login.
    goto :FAIL
)

echo.
echo ====================================================================
echo [SUCCESS] Release v%NEW_VER% completed cleanly!
echo.
echo 1. Local APK path:
echo    %cd%\releases\el-Alfy-v%NEW_VER%.apk
echo.
echo 2. GitHub Releases link:
echo    https://github.com/emontal90/el-alfy-90/releases/latest
echo    Direct Download Link:
echo    https://github.com/emontal90/el-alfy-90/releases/latest/download/el-Alfy-App.apk
echo ====================================================================
echo.
start "" explorer "releases"
goto :DONE

:CANCEL
echo.
echo Release cancelled by user.
goto :DONE

:FAIL
echo.
echo Release process aborted due to error.
pause
endlocal
exit /b 1

:DONE
echo.
echo Press any key to close...
pause >nul
endlocal
exit /b 0

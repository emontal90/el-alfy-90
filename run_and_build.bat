@echo off
title Furniture ERP - Run and Build

if exist "D:\flutter\bin" set "PATH=D:\flutter\bin;%PATH%"
if exist "C:\flutter\bin" set "PATH=C:\flutter\bin;%PATH%"
if exist "%USERPROFILE%\Desktop\flutter\bin" set "PATH=%USERPROFILE%\Desktop\flutter\bin;%PATH%"
if exist "C:\Users\Ayman\Desktop\flutter\bin" set "PATH=C:\Users\Ayman\Desktop\flutter\bin;%PATH%"
if exist "%USERPROFILE%\flutter\bin" set "PATH=%USERPROFILE%\flutter\bin;%PATH%"
if exist "%LOCALAPPDATA%\flutter\bin" set "PATH=%LOCALAPPDATA%\flutter\bin;%PATH%"

where flutter >nul 2>nul
if errorlevel 1 (
    echo ====================================================================
    echo [ERROR] Flutter engine not found at D:\flutter\bin or in system PATH.
    echo Please ensure Flutter is installed at D:\flutter
    echo or add its bin directory to your Windows PATH environment variable.
    echo ====================================================================
    echo.
    pause
    exit /b 1
)

echo ====================================================================
echo                   Furniture ERP System
echo                    Run and Build Tool
echo ====================================================================
echo.
echo Flutter location:
where flutter
echo.
echo Fetching and updating project packages...
call flutter pub get
echo.
echo ====================================================================
echo Select an option:
echo.
echo [1] Run application locally (Default device / emulator)
echo [2] Build release APK for Android
echo ====================================================================
echo.
choice /c 12 /n /m "Select an option [1 or 2]: "
if errorlevel 2 goto :BUILD_APK
if errorlevel 1 goto :RUN_LOCAL

:RUN_LOCAL
echo.
echo Starting application locally...
call flutter run
goto :END

:BUILD_APK
echo.
echo ====================================================================
echo Building release APK for Android...
echo Note: This requires Android SDK / Android Studio to be installed.
echo ====================================================================
call flutter build apk --release
goto :END

:END
echo.
pause

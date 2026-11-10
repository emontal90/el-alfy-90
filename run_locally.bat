@echo off
title Furniture ERP - Local Runner

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
echo                    Local Test Runner
echo ====================================================================
echo.
echo Flutter location:
where flutter
echo.
echo [1/3] Getting project packages (flutter pub get)...
call flutter pub get
echo.
echo [2/3] Available target devices:
call flutter devices
echo.
echo [3/3] Choose target platform:
echo.
echo [1] Auto-detect / Connected Mobile Device or Emulator
echo [2] Google Chrome Browser (Fast Web Preview)
echo [3] Windows Desktop Application
echo [4] Check Environment Health (flutter doctor)
echo [5] Clean and rebuild cache (flutter clean)
echo [0] Exit
echo.
choice /c 123450 /n /m "Enter your choice [0-5]: "
if errorlevel 6 exit /b 0
if errorlevel 5 goto :CLEAN
if errorlevel 4 goto :DOCTOR
if errorlevel 3 goto :WIN
if errorlevel 2 goto :CHROME
if errorlevel 1 goto :DEFAULT

:DEFAULT
echo.
echo Starting on default connected device...
call flutter run
goto :END

:CHROME
echo.
echo Starting on Google Chrome...
call flutter run -d chrome
goto :END

:WIN
echo.
echo ====================================================================
echo Starting on Windows Desktop...
echo Note: If Windows Desktop fails with symlink errors, please enable
echo Windows Developer Mode in Windows Settings or run this as Administrator.
echo ====================================================================
call flutter run -d windows
goto :END

:DOCTOR
echo.
echo Checking Flutter environment health:
call flutter doctor
goto :END

:CLEAN
echo.
echo Cleaning build cache...
call flutter clean
call flutter pub get
echo Cache cleaned successfully.
goto :END

:END
echo.
pause

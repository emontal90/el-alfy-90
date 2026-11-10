@echo off
title Push El-Alfy to GitHub
echo ===============================================================
echo          Pushing El-Alfy project to GitHub Repository
echo       Repository: https://github.com/emontal90/el-alfy-90.git
echo ===============================================================
echo.
cd /d "%~dp0"
git push -u origin main
echo.
echo ===============================================================
pause

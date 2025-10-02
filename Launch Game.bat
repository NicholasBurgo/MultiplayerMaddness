@echo off
title Multiplayer Madness Launcher
echo.
echo ========================================
echo    Multiplayer Madness Game Launcher
echo ========================================
echo.
echo Starting game...
echo.

REM Try to find love.exe in common locations
set LOVE_PATH=""

REM Check current directory first
if exist "love.exe" (
    set LOVE_PATH="love.exe"
    goto :launch
)

REM Check if LOVE is in PATH
where love.exe >nul 2>&1
if %ERRORLEVEL% == 0 (
    set LOVE_PATH="love.exe"
    goto :launch
)

REM Check common installation directories
if exist "C:\Program Files\LOVE\love.exe" (
    set LOVE_PATH="C:\Program Files\LOVE\love.exe"
    goto :launch
)

if exist "C:\Program Files (x86)\LOVE\love.exe" (
    set LOVE_PATH="C:\Program Files (x86)\LOVE\love.exe"
    goto :launch
)

if exist "%USERPROFILE%\AppData\Local\LOVE\love.exe" (
    set LOVE_PATH="%USERPROFILE%\AppData\Local\LOVE\love.exe"
    goto :launch
)

REM If LOVE.exe not found, show error and try to open LOVE website
echo ERROR: LOVE2D engine not found!
echo.
echo Please install LOVE2D from: https://love2d.org/
echo.
echo Or place love.exe in the same folder as this launcher.
echo.
echo Press any key to open the LOVE2D download page...
pause >nul
start https://love2d.org/
exit /b 1

:launch
echo Found LOVE2D at: %LOVE_PATH%
echo.
echo Launching Multiplayer Madness...
echo.

REM Launch the game
%LOVE_PATH% "multiplayergame"

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Failed to launch game!
    echo Please make sure LOVE2D is properly installed.
    echo.
    pause
)

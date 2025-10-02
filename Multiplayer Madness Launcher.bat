@echo off
title Multiplayer Madness - Advanced Launcher
color 0A
echo.
echo  ███╗   ███╗██╗   ██╗██╗  ████████╗██╗     ███████╗██╗      █████╗ ██╗   ██╗██████╗ 
echo  ████╗ ████║██║   ██║██║  ╚══██╔══╝██║     ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗
echo  ██╔████╔██║██║   ██║██║     ██║   ██║     █████╗  ██║     ███████║██║   ██║██████╔╝
echo  ██║╚██╔╝██║██║   ██║██║     ██║   ██║     ██╔══╝  ██║     ██╔══██║██║   ██║██╔═══╝ 
echo  ██║ ╚═╝ ██║╚██████╔╝███████╗██║   ███████╗███████╗███████╗██║  ██║╚██████╔╝██║     
echo  ╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝   ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝     
echo.
echo                    ██████╗  █████╗ ███╗   ███╗███████╗
echo                   ██╔════╝ ██╔══██╗████╗ ████║██╔════╝
echo                   ██║  ███╗███████║██╔████╔██║█████╗  
echo                   ██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  
echo                   ╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗
echo                    ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝
echo.
echo ================================================================================
echo                           MULTIPLAYER MADNESS LAUNCHER
echo ================================================================================
echo.

REM Set variables
set GAME_DIR=multiplayergame
set LOVE_FOUND=0

echo [INFO] Searching for LOVE2D engine...
echo.

REM Check current directory first
if exist "love.exe" (
    echo [✓] Found love.exe in current directory
    set LOVE_PATH=love.exe
    set LOVE_FOUND=1
    goto :check_game
)

REM Check if LOVE is in PATH
echo [INFO] Checking system PATH...
where love.exe >nul 2>&1
if %ERRORLEVEL% == 0 (
    echo [✓] Found love.exe in system PATH
    set LOVE_PATH=love.exe
    set LOVE_FOUND=1
    goto :check_game
)

REM Check common installation directories
echo [INFO] Checking common installation directories...

if exist "C:\Program Files\LOVE\love.exe" (
    echo [✓] Found LOVE2D in Program Files
    set LOVE_PATH="C:\Program Files\LOVE\love.exe"
    set LOVE_FOUND=1
    goto :check_game
)

if exist "C:\Program Files (x86)\LOVE\love.exe" (
    echo [✓] Found LOVE2D in Program Files (x86)
    set LOVE_PATH="C:\Program Files (x86)\LOVE\love.exe"
    set LOVE_FOUND=1
    goto :check_game
)

if exist "%USERPROFILE%\AppData\Local\LOVE\love.exe" (
    echo [✓] Found LOVE2D in user AppData
    set LOVE_PATH="%USERPROFILE%\AppData\Local\LOVE\love.exe"
    set LOVE_FOUND=1
    goto :check_game
)

REM LOVE not found
echo [✗] LOVE2D engine not found!
echo.
echo Please install LOVE2D from the official website:
echo https://love2d.org/
echo.
echo Installation options:
echo 1. Download from https://love2d.org/ and install
echo 2. Or place love.exe in the same folder as this launcher
echo.
echo Press 'D' to open download page, or any other key to exit...
choice /C D /N /M "Your choice: "
if errorlevel 2 goto :exit
if errorlevel 1 start https://love2d.org/
goto :exit

:check_game
echo.
echo [INFO] Checking game files...

if not exist "%GAME_DIR%" (
    echo [✗] Game directory '%GAME_DIR%' not found!
    echo Please make sure the game files are in the correct location.
    goto :exit_error
)

if not exist "%GAME_DIR%\main.lua" (
    echo [✗] Main game file not found in '%GAME_DIR%'!
    echo Please make sure the game files are complete.
    goto :exit_error
)

echo [✓] Game files found
echo.
echo [INFO] Launch configuration:
echo   LOVE2D Path: %LOVE_PATH%
echo   Game Directory: %GAME_DIR%
echo.
echo Press any key to launch the game...
pause >nul

echo.
echo [INFO] Launching Multiplayer Madness...
echo ================================================================================

REM Launch the game
%LOVE_PATH% "%GAME_DIR%"

REM Check if launch was successful
if %ERRORLEVEL% neq 0 (
    echo.
    echo [✗] ERROR: Failed to launch game!
    echo.
    echo Possible solutions:
    echo 1. Make sure LOVE2D is properly installed
    echo 2. Check that all game files are present
    echo 3. Try running as administrator
    echo.
    goto :exit_error
)

REM If we get here, the game launched successfully
echo.
echo [✓] Game launched successfully!
goto :exit

:exit_error
echo.
echo Press any key to exit...
pause >nul
exit /b 1

:exit
echo.
echo Thank you for playing Multiplayer Madness!
timeout /t 2 >nul
exit /b 0


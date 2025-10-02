# Multiplayer Madness PowerShell Launcher
# This script launches the game using LOVE2D

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   Multiplayer Madness Game Launcher" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$gameDir = "multiplayergame"
$lovePaths = @(
    "love.exe",  # Current directory
    "C:\Program Files\LOVE\love.exe",
    "C:\Program Files (x86)\LOVE\love.exe",
    "$env:USERPROFILE\AppData\Local\LOVE\love.exe"
)

Write-Host "[INFO] Searching for LOVE2D engine..." -ForegroundColor Yellow

$lovePath = $null
foreach ($path in $lovePaths) {
    if (Test-Path $path) {
        Write-Host "[✓] Found LOVE2D at: $path" -ForegroundColor Green
        $lovePath = $path
        break
    }
}

if (-not $lovePath) {
    # Try to find love.exe in PATH
    try {
        $loveInPath = Get-Command love.exe -ErrorAction SilentlyContinue
        if ($loveInPath) {
            Write-Host "[✓] Found LOVE2D in system PATH" -ForegroundColor Green
            $lovePath = "love.exe"
        }
    }
    catch {
        # love.exe not in PATH
    }
}

if (-not $lovePath) {
    Write-Host "[✗] LOVE2D engine not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install LOVE2D from: https://love2d.org/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or place love.exe in the same folder as this script." -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Press Enter to open the LOVE2D download page"
    Start-Process "https://love2d.org/"
    exit 1
}

Write-Host ""
Write-Host "[INFO] Checking game files..." -ForegroundColor Yellow

if (-not (Test-Path $gameDir)) {
    Write-Host "[✗] Game directory '$gameDir' not found!" -ForegroundColor Red
    Write-Host "Please make sure the game files are in the correct location." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not (Test-Path "$gameDir\main.lua")) {
    Write-Host "[✗] Main game file not found in '$gameDir'!" -ForegroundColor Red
    Write-Host "Please make sure the game files are complete." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[✓] Game files found" -ForegroundColor Green
Write-Host ""
Write-Host "[INFO] Launch configuration:" -ForegroundColor Cyan
Write-Host "  LOVE2D Path: $lovePath" -ForegroundColor White
Write-Host "  Game Directory: $gameDir" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to launch the game"

Write-Host ""
Write-Host "[INFO] Launching Multiplayer Madness..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green

try {
    if ($lovePath -eq "love.exe") {
        & $lovePath $gameDir
    } else {
        & $lovePath $gameDir
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[✓] Game launched successfully!" -ForegroundColor Green
    } else {
        throw "Game exited with error code $LASTEXITCODE"
    }
}
catch {
    Write-Host ""
    Write-Host "[✗] ERROR: Failed to launch game!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible solutions:" -ForegroundColor Yellow
    Write-Host "1. Make sure LOVE2D is properly installed" -ForegroundColor White
    Write-Host "2. Check that all game files are present" -ForegroundColor White
    Write-Host "3. Try running as administrator" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Thank you for playing Multiplayer Madness!" -ForegroundColor Green
Start-Sleep -Seconds 2


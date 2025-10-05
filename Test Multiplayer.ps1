# Quick Multiplayer Test Launcher
# Launches two instances of the game for testing

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Multiplayer Test Launcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$gameDir = "multiplayergame"
$lovePaths = @(
    "love.exe",
    "C:\Program Files\LOVE\love.exe",
    "C:\Program Files (x86)\LOVE\love.exe",
    "$env:USERPROFILE\AppData\Local\LOVE\love.exe"
)

# Find LOVE2D
$lovePath = $null
foreach ($path in $lovePaths) {
    if (Test-Path $path) {
        $lovePath = $path
        break
    }
}

if (-not $lovePath) {
    try {
        $loveInPath = Get-Command love.exe -ErrorAction SilentlyContinue
        if ($loveInPath) {
            $lovePath = "love.exe"
        }
    }
    catch { }
}

if (-not $lovePath) {
    Write-Host "[✗] LOVE2D not found!" -ForegroundColor Red
    Write-Host "Please run 'Launch Game.ps1' first to set up LOVE2D" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[✓] Found LOVE2D at: $lovePath" -ForegroundColor Green
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "  1. Window 1 will open - Click 'Play' → 'Host Game'" -ForegroundColor White
Write-Host "  2. Window 2 will open - Click 'Play' → 'Join Game' → 'Connect'" -ForegroundColor White
Write-Host "  3. Both players should now be in the same lobby!" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to launch both game windows"

Write-Host ""
Write-Host "[INFO] Launching Window 1 (Host)..." -ForegroundColor Cyan

try {
    # Launch first instance
    Start-Process -FilePath $lovePath -ArgumentList $gameDir
    Start-Sleep -Seconds 2
    
    Write-Host "[INFO] Launching Window 2 (Client)..." -ForegroundColor Cyan
    # Launch second instance
    Start-Process -FilePath $lovePath -ArgumentList $gameDir
    
    Write-Host ""
    Write-Host "[✓] Both windows launched!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Now follow the instructions above to test multiplayer." -ForegroundColor Yellow
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "[✗] Failed to launch game!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ""
Write-Host "Press Enter to close this window..."
Read-Host



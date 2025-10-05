# Join Button Fix - Connecting Screen Implementation

## Date
October 5, 2025

## Issue
The "Join Game" button wasn't working properly. The original game had a connecting screen where players could enter the server IP address, but the refactored version was missing this feature.

## Root Cause
The refactored menu was trying to directly connect to `127.0.0.1:12345` without giving players a chance to enter a different server address. The legacy code had a "connecting" state with an input field for entering the server address.

## Solution Implemented

### 1. Created New Connecting Scene
**File**: `src/game/scenes/connecting.lua`

Features:
- Input field for entering server address (defaults to "localhost")
- "Connect" button to initiate connection
- "Back" button to return to menu
- Text input support for typing server addresses
- Enter key shortcut to connect
- Visual feedback with cursor blinking

### 2. Updated Menu Scene
**File**: `src/game/scenes/menu.lua`

Changes:
- "Join Game" button now emits `intent:show_connecting` instead of directly connecting
- This shows the connecting screen where players can enter the server address

### 3. Updated App Core
**File**: `src/core/app.lua`

Changes:
- Added `intent:show_connecting` event handler to show connecting scene
- Added `intent:back_to_menu` event handler to return to menu
- Updated `intent:join` to accept host parameter from connecting screen
- Registered the new connecting scene in the scenes list

## How It Works Now

### Join Flow:
1. Player clicks "Play" → "Join Game" in main menu
2. Connecting screen appears with input field
3. Player can enter server address (or use default "localhost")
4. Player clicks "Connect" or presses Enter
5. Game attempts to connect to the specified server
6. If successful, player joins the lobby
7. If failed, returns to connecting screen to try again

### Testing Multiplayer:
1. **Window 1** (Host):
   - Launch game
   - Click "Play" → "Host Game"
   - Wait in lobby

2. **Window 2** (Client):
   - Launch game
   - Click "Play" → "Join Game"
   - Enter "localhost" (or leave default)
   - Click "Connect"
   - Join the host's lobby

## Related Fixes
This update works together with the previously implemented fixes:
- ✅ Unique player IDs (host = 0, clients = 1, 2, 3...)
- ✅ Proper player control separation
- ✅ Player naming system
- ✅ Character customization textinput

## Files Modified
- `src/game/scenes/connecting.lua` (NEW)
- `src/game/scenes/menu.lua`
- `src/core/app.lua`

## Testing Notes
- Default server address is "localhost" for local testing
- Players can enter IP addresses like "192.168.1.100" for LAN play
- Port is fixed at 12345 (can be changed in connecting.lua if needed)
- Server tries multiple ports (12345-12348) if first port is busy

## Future Enhancements
- Add port input field (currently fixed at 12345)
- Add connection status indicator
- Add recent servers list
- Add server browser
- Steam integration will replace this with Steam lobby system



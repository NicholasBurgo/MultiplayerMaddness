# Character Customization & Connection Fixes

## Date
October 5, 2025

## Issues Fixed

### 1. Character Customization Not Working in Main Menu
**Problem**: 
- Clicking "Customize" button worked but drawing on face didn't work
- Mouse events weren't being passed through properly
- Button return value mismatch ("confirm" vs "done")

**Solution**:
- Added `mousereleased` and `mousemoved` callbacks to app.lua
- Added these callbacks to main.lua love callbacks
- Added mouse event forwarding in customization scene
- Fixed button result checking to accept both "confirm" and "done"
- Updated to use characterCustomization getter functions for proper data retrieval

### 2. Connect Button Visual Feedback
**Problem**:
- Connect button might not be giving clear feedback when clicked
- Need better debugging to see connection flow

**Solution**:
- Added extensive debug logging to connecting scene
- Added debug logging to join intent handler
- Added console output to track connection attempts
- This will help identify any connection issues

## Files Modified

### New Files:
- `Test Multiplayer.ps1` - Quick launcher for testing multiplayer with two windows

### Modified Files:
- `src/game/scenes/customization.lua`
  - Fixed button result checking
  - Added mouse event handlers
  - Fixed data retrieval using getter functions

- `src/core/app.lua`
  - Added `mousereleased` callback
  - Added `mousemoved` callback
  - Added debug logging to join handler

- `main.lua`
  - Added `love.mousereleased` callback
  - Added `love.mousemoved` callback

- `src/game/scenes/connecting.lua`
  - Added debug logging for mouse clicks
  - Added logging for button detection

## How Character Customization Works Now

1. Click "Customize" from main menu
2. **Name Input**: Click the text field and type your name
3. **Color Selection**: Use < and > buttons to cycle through colors
4. **Face Drawing**: Click and drag on the colored square to draw your face
5. **Clear Face**: Click "Clear Face" to start over
6. **Done**: Click "Done" to save and return to menu
7. **Cancel**: Click "Cancel" to return without saving

## Mouse Events Flow

```
love.mousepressed → app.mousepressed → scene.mousepressed
love.mousereleased → app.mousereleased → scene.mousereleased
love.mousemoved → app.mousemoved → scene.mousemoved
```

All mouse coordinates are automatically converted from screen space to game space using the scaling system.

## Testing Multiplayer

### Method 1: Manual (Two Terminal Windows)
```powershell
# Terminal 1
.\Launch Game.ps1

# Terminal 2 (after first window opens)
.\Launch Game.ps1
```

### Method 2: Automatic Test Script
```powershell
.\Test Multiplayer.ps1
```

This will:
1. Launch Window 1 (for hosting)
2. Wait 2 seconds
3. Launch Window 2 (for joining)

### Connection Flow:
1. **Window 1**: Play → Host Game → Wait in lobby
2. **Window 2**: Play → Join Game → Enter "localhost" → Click Connect
3. **Window 2** should join **Window 1's** lobby
4. Both players can now move around with WASD

## Debug Output

When testing, watch the console for these messages:

**Connecting Scene:**
```
[Connecting] Mouse clicked at: X, Y
[Connecting] Connect button clicked! Attempting to join: localhost
```

**App Layer:**
```
[App] Join intent received!
[App] Host: localhost
[App] Port: 12345
[App] Transport start result: true/false
[App] Client started, waiting for connection...
```

**Network Layer:**
```
[net.lan] Starting client...
[net.lan] Connecting to localhost:12345
[net.lan] Connection attempt sent
[net.lan] Connected to server
```

## Known Issues & Notes

1. **Port Conflicts**: If port 12345 is busy, the server will try 12346, 12347, 12348
2. **Connection Timeout**: If connection fails, you'll return to the connecting screen
3. **Localhost Only**: Currently defaults to localhost - change in connecting screen for LAN play
4. **ENet Required**: Make sure ENet library is available (should be included with LOVE2D)

## Future Enhancements

- Add connection status indicator (connecting... connected... failed)
- Add timeout message if connection takes too long
- Add recent servers dropdown
- Add LAN server discovery
- Add connection retry logic
- Steam integration will replace manual IP entry with lobby system



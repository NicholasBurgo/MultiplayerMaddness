# Character Customization Button Fix & Face Removal

## Date
October 5, 2025

## Issues Fixed

### 1. Buttons Not Working
**Problem**: 
- None of the buttons in character customization were responding to clicks
- The < > color buttons, Done, and Cancel buttons were all non-functional

**Root Cause**:
The `isMouseOver` function was using `love.mouse.getPosition()` which returns screen coordinates (actual window pixels), but the buttons were positioned using game coordinates (base 800x600 resolution). The scaling system converts between these coordinate spaces, but the button detection wasn't using the converted coordinates.

**Solution**:
- Updated `isMouseOver` to accept mouse coordinates as parameters
- When coordinates aren't provided, it now uses the scaling system to convert screen coordinates to game coordinates
- Updated all button hover detection in the draw function to pass converted coordinates
- Updated mousepressed to pass the already-converted coordinates from the app layer

### 2. Smiley Face Removal
**Problem**:
- Character preview showed eyes and a smile that the user wanted removed

**Solution**:
- Removed the eyes drawing code (white circles with black pupils)
- Removed the smile drawing code (black arc)
- Character now shows just a colored body square and head circle

## Technical Details

### Coordinate System
The game uses two coordinate systems:
1. **Screen Coordinates**: Actual window pixels (e.g., 1920x1080)
2. **Game Coordinates**: Virtual base resolution (800x600)

The scaling system (`src/core/scaling.lua`) handles conversion:
```lua
local gx, gy = scaling.screenToGame(screenX, screenY)
```

### Mouse Event Flow
```
User clicks → Screen coordinates (1920x1080)
    ↓
main.lua: love.mousepressed → Converts to game coordinates
    ↓
app.lua: app.mousepressed → Passes game coordinates
    ↓
scene.mousepressed → Receives game coordinates (800x600)
```

### isMouseOver Function
**Before:**
```lua
function isMouseOver(item)
    local mx, my = love.mouse.getPosition()  -- Screen coordinates!
    return mx > item.x and mx < item.x + item.width ...
end
```

**After:**
```lua
function isMouseOver(item, mx, my)
    if not mx or not my then
        local scaling = require("src.core.scaling")
        local screenX, screenY = love.mouse.getPosition()
        mx, my = scaling.screenToGame(screenX, screenY)  -- Convert!
    end
    return mx > item.x and mx < item.x + item.width ...
end
```

## Files Modified

### `src/game/systems/charactercustom.lua`

**Changes:**
1. Updated `isMouseOver` function to accept and convert coordinates
2. Added coordinate conversion in draw function for hover effects
3. Updated all `isMouseOver` calls to pass coordinates
4. Added debug logging to mousepressed for troubleshooting
5. Removed eyes and smile from character drawing

**Buttons Fixed:**
- Previous color button (<)
- Next color button (>)
- Done button
- Cancel button
- Name input field

**Visual Changes:**
- Character preview now shows only body and head (no face)

## Testing

### Button Functionality:
1. **Name Input**: Click the text field → Should activate and show cursor
2. **Color Buttons**: Click < or > → Should cycle through colors
3. **Done Button**: Click → Should save and return to menu
4. **Cancel Button**: Click → Should return to menu without saving
5. **Hover Effects**: Buttons should highlight when mouse hovers over them

### Character Preview:
- Should show a colored square body
- Should show a colored circle head (slightly darker than body)
- Should NOT show eyes or smile

## Debug Output

When clicking buttons, console will show:
```
[CharacterCustom] Mouse pressed at: X, Y
[CharacterCustom] Previous color clicked
[CharacterCustom] Next color clicked
[CharacterCustom] Confirm button clicked
[CharacterCustom] Cancel button clicked
```

This helps verify that:
1. Mouse coordinates are being received
2. Button detection is working
3. Click handlers are being called

## Related Systems
- **Scaling System**: `src/core/scaling.lua` - Coordinate conversion
- **Customization Scene**: `src/game/scenes/customization.lua` - Scene wrapper
- **App Layer**: `src/core/app.lua` - Event routing
- **Main**: `main.lua` - LÖVE callbacks

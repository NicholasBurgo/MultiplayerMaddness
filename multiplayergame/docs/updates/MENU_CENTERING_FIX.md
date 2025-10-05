# Menu Centering Fix

## Date
October 5, 2025

## Issue
All menus and UI elements were positioned off-center, appearing too far to the right. This was because the UI code was using hardcoded pixel positions (x=300) or actual window dimensions instead of the base resolution.

## Root Cause
The game uses a scaling system with a BASE resolution of 800x600, which is then scaled to fit the actual window size. However, UI positioning code was either:
1. Using hardcoded positions (x=300) that assumed a specific screen size
2. Using `love.graphics.getWidth()` which returns the actual window size, not the base resolution

## Solution
Updated all UI positioning to use the BASE_WIDTH and BASE_HEIGHT constants (800x600) and calculate centered positions dynamically.

## Files Modified

### 1. `src/game/scenes/menu.lua`
**Changed:**
- Replaced hardcoded `x = 300` with `centerX = (BASE_WIDTH - 200) / 2`
- All menu buttons now properly centered at x=300 (center of 800px width)

**Buttons Fixed:**
- Play, Customize, Settings, Quit (main menu)
- Host Game, Join Game, Back (play submenu)
- Back buttons (settings and customize submenus)

### 2. `src/game/scenes/connecting.lua`
**Changed:**
- Replaced hardcoded `x = 300` with `centerX = (BASE_WIDTH - 200) / 2`
- Input field and buttons now properly centered

**Elements Fixed:**
- Server address input field
- Connect button
- Back button

### 3. `src/game/systems/charactercustom.lua`
**Changed:**
- Replaced `love.graphics.getWidth()` and `love.graphics.getHeight()` with BASE_WIDTH and BASE_HEIGHT
- All positioning now uses base resolution (800x600)
- Text centering uses BASE_WIDTH instead of screenWidth

**Elements Fixed:**
- Title text
- Name input field
- Character preview
- Color selection buttons (< and >)
- Color name display
- Done and Cancel buttons

## Technical Details

### Base Resolution System
The game uses a virtual resolution system:
```lua
BASE_WIDTH = 800
BASE_HEIGHT = 600
```

All UI elements should be positioned relative to this base resolution. The scaling system (`src/core/scaling.lua`) then handles:
1. Scaling the base resolution to fit the window
2. Converting mouse coordinates from screen space to game space
3. Maintaining aspect ratio

### Centering Formula
For elements with width W:
```lua
centerX = (BASE_WIDTH - W) / 2
```

For 200px wide buttons on 800px screen:
```lua
centerX = (800 - 200) / 2 = 300
```

## Testing
All menus should now be properly centered regardless of window size:
- Main menu buttons
- Play submenu buttons
- Connecting screen
- Character customization screen

The scaling system ensures everything stays centered when:
- Window is resized
- Fullscreen is toggled (F11)
- Window is maximized

## Related Systems
- **Scaling System**: `src/core/scaling.lua` - Handles resolution scaling
- **Mouse Input**: Coordinates are automatically converted from screen to game space
- **Music Handler**: Visual effects (wave, pulse) work correctly with centered elements

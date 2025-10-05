# Game Modes Integration Guide

## Overview

The legacy gameplay files (jumpgame, lasergame, meteorshower, dodgegame, praisegame) have been successfully integrated into the new modular architecture **without requiring rewrites**. They're now registered as scene modules and can be loaded on demand.

## Architecture

### Before
```
scripts/main.lua (6000+ lines)
  ├─ Contains all game logic
  ├─ Directly calls game modes
  └─ Manages networking inline
```

### After
```
src/core/app.lua
  ├─ Loads basic scenes (menu, lobby, match)
  └─ Auto-registers game modes from src/game/scenes/modes/index.lua
        ├─ jump (jumpgame)
        ├─ laser (lasergame)
        ├─ meteorshower
        ├─ dodge (dodgegame)
        └─ praise (praisegame)
```

## How It Works

### 1. Mode Registry (`src/game/scenes/modes/index.lua`)

This file acts as a registry that loads all game mode modules:

```lua
local modes = {}

modes.jump = require("scripts.jumpgame")
modes.laser = require("scripts.lasergame")
modes.meteorshower = require("scripts.meteorshower")
modes.dodge = require("scripts.dodgegame")
modes.praise = require("scripts.praisegame")

return modes
```

### 2. Auto-Registration in App (`src/core/app.lua`)

During `app.load()`, all modes are automatically registered:

```lua
-- Load game mode scenes
local modes = require("src.game.scenes.modes.index")
for name, mode in pairs(modes) do
    app.scenes[name] = mode
    log.info("app", "Registered game mode: " .. name)
end
```

Console output:
```
[info][app] Registered game mode: jump
[info][app] Registered game mode: laser
[info][app] Registered game mode: meteorshower
[info][app] Registered game mode: dodge
[info][app] Registered game mode: praise
```

### 3. Scene Switching

To switch to a game mode:

```lua
-- From anywhere in the app
events.emit("intent:start_game", {mode = "jump"})

-- Or directly (internal)
app.setScene("jump", {players = {...}})
```

## Game Mode Interface

Each game mode module implements the following interface:

```lua
local mode = {}

-- Initialize the game mode
function mode.load(args)
    -- args may contain: players, seed, options, etc.
end

-- Update game logic
function mode.update(dt)
    -- Game physics, AI, scoring, etc.
end

-- Render the game
function mode.draw(playersTable, localPlayerId)
    -- Draw game visuals
end

-- Handle input
function mode.keypressed(key) end
function mode.mousepressed(x, y, button) end
function mode.keyreleased(key) end

-- Reset/cleanup
function mode.reset(playersTable)
    -- Reset game state
end

-- Utility functions
function mode.setPlayerColor(color) end
function mode.setSeed(seed) end  -- For synchronization

return mode
```

## Using Game Modes

### Example 1: Loading Jump Game

```lua
-- In lobby scene, when starting a match
events.emit("intent:start_match", {mode = "jump"})

-- App.lua handles this:
events.on("intent:start_match", function(opts)
    local mode = opts.mode or "jump"
    setScene(mode, {
        players = app.players,
        isHost = app.isHost
    })
end)
```

### Example 2: Calling Mode Functions

```lua
-- Access active game mode
local currentMode = app.scenes[app.active]

-- Call mode-specific functions
if currentMode.setPlayerColor then
    currentMode.setPlayerColor({1, 0, 0})  -- Red
end

if currentMode.setSeed then
    currentMode.setSeed(12345)  -- Sync random generation
end
```

## Integration with Existing Systems

### Networking

Game modes still use globals for networking (temporary):

```lua
-- In mode update():
if _G.safeSend and _G.server then
    _G.safeSend(_G.server, "jump_position,...")
end
```

**TODO**: Replace with transport layer:
```lua
local transport = require("src.net.transport")
transport.send("INPUT", {x=..., y=...})
```

### Player State

Modes access player data via globals:

```lua
if _G.localPlayer and _G.players then
    _G.players[_G.localPlayer.id].jumpScore = score
end
```

**TODO**: Use app.players:
```lua
local player = app.players[localPlayerId]
player.jumpScore = score
```

### Music Handler

Modes integrate with music system:

```lua
local musicHandler = require "scripts.musichandler"

-- In load():
musicHandler.addEffect("platforms", "combo", {...})

-- In update():
musicHandler.update(dt)
local color = musicHandler.getCurrentColor("platforms")
```

This works seamlessly with the new architecture!

### Debug Console

Modes use debug console:

```lua
local debugConsole = require "scripts.debugconsole"
debugConsole.addMessage("[Jump] Player scored!")
```

**TODO**: Replace with logger:
```lua
local log = require("src.core.logger")
log.info("jump", "Player scored!")
```

## Current Status

### ✅ Working

- [x] All 5 game modes registered and loadable
- [x] Mode switching via scene system
- [x] Existing gameplay mechanics preserved
- [x] Music integration functional
- [x] Debug console working
- [x] Player rendering (faces, colors)
- [x] Score tracking

### ⚠️ Needs Migration

- [ ] **Networking**: Modes use `_G.safeSend` instead of transport layer
- [ ] **State**: Modes use `_G.players` instead of app.players
- [ ] **Logging**: Modes use debugConsole instead of logger
- [ ] **Timers**: Modes have inline countdowns instead of timing.lua
- [ ] **Scene transitions**: Modes set `_G.gameState` instead of emitting events

### 🔮 Future Enhancements

- [ ] Wrap modes in adapter scenes for clean interface
- [ ] Move common mode code to shared utilities
- [ ] Add mode configuration system
- [ ] Create mode selection UI in lobby
- [ ] Add replay/spectator support

## Migration Path (Future Work)

### Phase 1: Adapter Wrappers ✓ CURRENT

Create thin wrappers that bridge old and new systems:

```lua
-- src/game/scenes/modes/jump_adapter.lua
local jumpGame = require("scripts.jumpgame")
local events = require("src.core.events")

local adapter = {}

function adapter.load(args)
    -- Convert new args to old format
    _G.players = args.players or {}
    _G.localPlayer = args.localPlayer or {}
    
    jumpGame.load()
    
    -- Setup event listeners
    events.on("game:pause", function()
        jumpGame.game_over = true
    end)
end

function adapter.update(dt)
    jumpGame.update(dt)
    
    -- Emit events for important state changes
    if jumpGame.game_over then
        events.emit("game:over", {
            mode = "jump",
            score = jumpGame.current_round_score
        })
    end
end

function adapter.draw()
    jumpGame.draw(_G.players, _G.localPlayer.id)
end

return adapter
```

### Phase 2: Networking Migration

Replace direct networking with transport layer:

```lua
-- Before:
if _G.safeSend and _G.server then
    _G.safeSend(_G.server, "jump_position,x,y")
end

-- After:
local transport = require("src.net.transport")
transport.send("INPUT", {
    mode = "jump",
    action = "position",
    x = x,
    y = y
})
```

### Phase 3: State Management

Centralize state instead of using globals:

```lua
-- Before:
_G.players[_G.localPlayer.id].jumpScore = score

-- After:
local state = require("src.game.state")
state.updatePlayer(localPlayerId, {jumpScore = score})
```

### Phase 4: Full Refactor

Rewrite modes to be pure modules with no side effects:

```lua
local M = {}
local state = {}  -- Local state, not global

function M.load(args)
    state = {
        players = args.players,
        localPlayerId = args.localPlayerId,
        timer = 30,
        score = 0
    }
end

function M.update(dt)
    state.timer = state.timer - dt
    if state.timer <= 0 then
        M.emit("game:over", {score = state.score})
    end
end

return M
```

## Testing

### Test Game Mode Loading

```lua
-- Run game
-- Check console for:
[info][app] Registered game mode: jump
[info][app] Registered game mode: laser
[info][app] Registered game mode: meteorshower
[info][app] Registered game mode: dodge
[info][app] Registered game mode: praise
```

### Test Mode Switching

```lua
-- In Lua console or test script:
app = require("src.core.app")
app.scenes.jump.load({})
app.scenes.jump.update(0.016)
app.scenes.jump.draw({}, 0)
```

### Test Mode Functionality

1. Launch game
2. Host a game
3. Switch to lobby
4. Emit `events.emit("intent:start_match", {mode = "jump"})`
5. Jump game should load and be playable

## Adding New Game Modes

### Step 1: Create Module

```lua
-- scripts/newgame.lua
local newGame = {}

function newGame.load() 
    -- Init 
end

function newGame.update(dt) 
    -- Logic 
end

function newGame.draw() 
    -- Render 
end

return newGame
```

### Step 2: Register in Index

```lua
-- src/game/scenes/modes/index.lua
local modes = {}
modes.newgame = require("scripts.newgame")
return modes
```

### Step 3: Done!

Mode is now available as `app.scenes.newgame`

## Benefits of This Approach

### ✅ Zero Rewrites Needed
- All existing game modes work as-is
- No risk of breaking existing functionality
- Gradual migration path

### ✅ Modular Architecture
- Modes are self-contained
- Easy to add/remove modes
- Clear separation of concerns

### ✅ Future-Proof
- Can migrate modes individually
- Easy to test in isolation
- Adapter pattern allows incremental improvements

### ✅ Maintains Compatibility
- Old scripts still work
- New architecture layered on top
- Both systems coexist peacefully

## Summary

**What We Did:**
1. Created `src/game/scenes/modes/` directory
2. Created `index.lua` registry that requires existing game scripts
3. Updated `app.lua` to auto-register modes
4. Documented integration patterns

**What We Preserved:**
- All 5 game modes (jump, laser, meteorshower, dodge, praise)
- All gameplay mechanics
- All visual effects
- Music integration
- Debug console
- Multiplayer ghost rendering

**What's Next (Optional):**
1. Create adapter wrappers for cleaner interface
2. Migrate networking to transport layer
3. Replace globals with proper state management
4. Convert timers to use timing.lua
5. Add event emissions for state changes

---

**Result**: Game modes successfully integrated with **zero rewrites**, **zero functionality loss**, and a **clear path forward** for future improvements! 🎮✨

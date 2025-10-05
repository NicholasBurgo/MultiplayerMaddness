# Multiplayer Sync - Remaining Steps

## ✅ COMPLETED SO FAR:

1. **Protocol Updated** - Added all necessary message types (JUMP_POSITION, LASER_POSITION, etc.)
2. **App.lua Transport Handlers** - Added handlers to receive and process all position messages
3. **App.lua Event Handlers** - Added event handlers to broadcast Jump position/score
4. **Jump Game Position Sync** - Jump game now emits position events every frame

## 🚧 REMAINING TASKS:

### 1. Update Other Games to Emit Position Events

Each game needs similar updates to what was done in jump.lua:

**Laser Game** (`src/game/scenes/modes/games/lasergame.lua`):
- In `laserGame.update()`, emit `player:laser_position` event with `{id, x, y, color}`
- Event: `events.emit("player:laser_position", {id=..., x=laserGame.player.x, y=laserGame.player.y, color=...})`

**Meteor Shower** (`src/game/scenes/modes/games/meteorshower.lua`):
- In `meteorShower.update()`, emit `player:battle_position` event with `{id, x, y, color}`
- If host, also emit `meteor:sync` event with `{center_x, center_y, radius, direction}`

**Dodge Game** (`src/game/scenes/modes/games/dodgegame.lua`):
- In `dodgeGame.update()`, emit `player:dodge_position` event with `{id, x, y, color}`

**Praise Game** (`src/game/scenes/modes/games/praisegame.lua`):
- In `praiseGame.update()`, emit `player:praise_position` event with `{id, x, y, color}`

### 2. Add Event Handlers in app.lua for Other Games

Add similar handlers to what was added for jump, but for:
- `events.on("player:laser_position", ...)` → broadcasts via `LASER_POSITION`
- `events.on("player:battle_position", ...)` → broadcasts via `BATTLE_POSITION`  
- `events.on("player:dodge_position", ...)` → broadcasts via `DODGE_POSITION`
- `events.on("player:praise_position", ...)` → broadcasts via `PRAISE_POSITION`
- `events.on("meteor:sync", ...)` → broadcasts via `METEOR_SYNC` (host only)

### 3. Fix Tab Score Display

**Update `src/game/systems/gameui.lua`**:
- Change drawTabScores to match old style:
  - Use proper medal colors (#1 gold, #2 silver, #3 bronze, rest white)
  - Show "Player List" title centered
  - Each player entry: "#X Player Name Score: Y"
  - Use totalScore for overall, or game-specific scores
  - Semi-transparent dark background
  - Proper font sizing (xlarge for title, medium for entries)

**Medal Colors** (from old code):
```lua
local function getMedalColor(rank)
    if rank == 1 then return {1, 0.84, 0, 0.9} -- Gold
    elseif rank == 2 then return {0.75, 0.75, 0.75, 0.9} -- Silver
    elseif rank == 3 then return {0.8, 0.5, 0.2, 0.9} -- Bronze
    else return {1, 1, 1, 0.9} -- White
    end
end
```

### 4. Fix Tab Key Handling

Currently using toggle (keypressed/keyreleased). Old system used "hold to view":
- Change to: `showTabScores = love.keyboard.isDown("tab")` in each game's update function
- Remove keypressed/keyreleased handlers for tab

### 5. Test Multiplayer Scenarios

- Host + 1 client: verify remote player visibility in all games
- Check tab scores show correctly with proper rankings
- Verify meteor shower circle movement is synced
- Verify deaths are tracked properly across network

## 📋 QUICK REFERENCE - Code Patterns

**Position Emit Pattern** (add to each game's update function):
```lua
if _G.localPlayer and _G.localPlayer.id then
    local events = require("src.core.events")
    events.emit("player:GAME_position", {
        id = _G.localPlayer.id,
        x = gameModule.player.x,
        y = gameModule.player.y,
        color = _G.localPlayer.color or gameModule.playerColor
    })
end
```

**Event Handler Pattern** (add to app.lua):
```lua
events.on("player:GAME_position", function(data)
    if data.id and data.x and data.y then
        if app.players[data.id] then
            app.players[data.id].GAMEX = data.x
            app.players[data.id].GAMEY = data.y
            if data.color then app.players[data.id].color = data.color end
        end
        if app.connected then
            app.transport.send("GAME_POSITION", data)
        end
    end
end)
```

## 🎯 PRIORITY ORDER:

1. **HIGH**: Add position emits to laser, meteor, dodge, praise games
2. **HIGH**: Add corresponding event handlers in app.lua  
3. **MEDIUM**: Fix tab score display styling
4. **MEDIUM**: Add meteor shower circle sync
5. **LOW**: Fix tab key to be hold-based instead of toggle

Once these are complete, multiplayer sync should be fully functional!

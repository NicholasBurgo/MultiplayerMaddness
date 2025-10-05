# Remaining Fixes Needed

## ✅ Fixes Completed So Far

### 1. Game Mode Selection Menu - FIXED ✅
- **Issue**: Party Mode selection didn't close menu
- **Fix**: Moved `gameModeSelection.active = false` to start of Party Mode handler
- **Status**: ✅ COMPLETE

### 2. Play/Play Now Host-Only - FIXED ✅
- **Issue**: Play and Play Now should only show for host
- **Fix**: Modified drawGameModeSelection to skip these options for non-hosts
- **Status**: ✅ COMPLETE

### 3. Main Menu Animation - FIXED ✅
- **Issue**: Menu buttons not "dancing" like before, music not playing
- **Fix**: 
  - Added `musicHandler.loadMenuMusic()` in menu.load
  - Changed button effects from `beatPulse` to `combo` (scale + rotate)
  - Matches original effect setup
- **Status**: ✅ COMPLETE

## ⏳ Fixes Still Needed

### 4. Character Customization Not Showing in Games
**Issue**: Custom faces don't appear in game modes

**Root Cause**: Player data with facePoints not being passed to game scenes

**Fix Needed**:
```lua
-- In src/core/app.lua, when starting game:
events.on("intent:start_game", function(opts)
    local mode = opts and opts.mode or "jump"
    
    -- Pass full player data including facePoints
    if app.scenes[mode] then
        setScene(mode, {
            players = app.players,  -- ← Must include facePoints
            localPlayerId = 0,
            isHost = app.isHost
        })
    end
end)
```

**Test**: Check that `localPlayer.facePoints` is set and passed through

---

### 5. Party Mode Implementation
**Issue**: Party mode needs complete implementation

**Required Features**:
1. **Game Rotation**: Jump → Laser → Meteor → Dodge → Praise → repeat
2. **15-second rounds** for each game
3. **Round timer** at top middle of screen
4. **Party music** playing during all games
5. **Auto-transition** between games when time expires
6. **Score tracking** across all games

**Implementation Plan**:

#### A. Create Party Mode Manager
```lua
-- src/game/systems/partymode.lua
local party = {}

party.active = false
party.currentGameIndex = 1
party.gameLineup = {"jump", "laser", "meteorshower", "dodge", "praise"}
party.roundTime = 15
party.timeRemaining = 15

function party.start()
    party.active = true
    party.currentGameIndex = 1
    party.timeRemaining = 15
    
    -- Load party music
    local musicHandler = require("src.game.systems.musichandler")
    musicHandler.loadPartyMusic()
    
    return party.gameLineup[1]
end

function party.update(dt)
    if not party.active then return end
    
    party.timeRemaining = party.timeRemaining - dt
    
    if party.timeRemaining <= 0 then
        party.nextGame()
    end
end

function party.nextGame()
    party.currentGameIndex = party.currentGameIndex + 1
    if party.currentGameIndex > #party.gameLineup then
        party.currentGameIndex = 1
    end
    party.timeRemaining = party.roundTime
    
    local events = require("src.core.events")
    events.emit("party:next_game", {
        mode = party.gameLineup[party.currentGameIndex]
    })
end

function party.drawTimer()
    if not party.active then return end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf(
        string.format("TIME: %.1f", party.timeRemaining),
        0, 10, 800, "center"
    )
end

return party
```

#### B. Integrate Party Mode into App
```lua
-- In src/core/app.lua

local party = require("src.game.systems.partymode")

-- In app.update(dt):
party.update(dt)

-- Handle party mode transitions:
events.on("party:next_game", function(opts)
    if app.scenes[opts.mode] then
        setScene(opts.mode, {
            players = app.players,
            localPlayerId = 0,
            isHost = app.isHost,
            partyMode = true
        })
    end
end)
```

#### C. Add Timer Overlay to Games
```lua
-- Each game mode should check for party mode and draw timer

-- In each game's draw function:
function game.draw()
    -- ... game drawing ...
    
    -- Draw party mode timer if active
    local party = _G.partyMode or require("src.game.systems.partymode")
    if party.active then
        party.drawTimer()
    end
end
```

#### D. Handle Game End in Party Mode
```lua
-- In each game's update, check for party mode time expiration

function game.update(dt)
    -- ... game logic ...
    
    -- If party mode, don't end game normally
    if _G.partyMode then
        -- Just update party mode, it will handle transitions
        return
    end
    
    -- Normal game end logic...
end
```

---

### 6. Fix Jump Game Freeze
**Issue**: Jump game freezes when it ends in party mode

**Root Cause**: Game doesn't know how to handle party mode end state

**Fix**: Party mode manager should handle all transitions, games should never end themselves in party mode

---

## Implementation Priority

1. **HIGH**: Fix character customization (quick fix)
2. **HIGH**: Implement basic party mode manager
3. **MEDIUM**: Add 15-second timers
4. **MEDIUM**: Add timer overlay to games
5. **MEDIUM**: Fix party music
6. **LOW**: Polish transitions

## Testing Checklist

After fixes:
- [ ] Custom faces appear in all games
- [ ] Party mode starts correctly
- [ ] Timer shows at top middle
- [ ] Games rotate: Jump → Laser → Meteor → Dodge → Praise → repeat
- [ ] Each game lasts 15 seconds
- [ ] Party music plays throughout
- [ ] No freezes between games
- [ ] Scores tracked across all games

## Estimated Work

- **Character customization**: 15 minutes
- **Party mode system**: 1-2 hours
- **Timer integration**: 30 minutes
- **Testing & polish**: 30 minutes

**Total**: ~3 hours of focused work

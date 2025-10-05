# Play Button & Protocol Fix

## Issues Fixed

### 1. Protocol Error - Missing START_GAME Message Type

**Error:**
```
src/net/protocol.lua:6: Unknown kind: START_GAME
```

**Fix:**
Added missing message types to `src/net/protocol.lua`:
```lua
P.K = { 
    HELLO=true, 
    JOIN=true, 
    STATE=true, 
    INPUT=true, 
    PING=true, 
    PONG=true, 
    CHAT=true, 
    START_MATCH=true,
    START_GAME=true,      -- ← Added
    VOTE=true,            -- ← Added (for future)
    VOTE_UPDATE=true,     -- ← Added (for future)
    PLAYER_MOVE=true      -- ← Added (for future)
}
```

### 2. Play Button Not Working

**Issue:**
The "Play" option in the Game Mode Selection menu had a TODO and didn't actually launch games.

**Fix:**
Implemented proper random selection from votes in `src/game/scenes/lobby.lua`:

```lua
elseif gameModeSelection.selectedMode == 3 then
    -- Play - random from votes (host only)
    if isHost then
        gameModeSelection.active = false
        
        -- Count total votes
        local totalVotes = 0
        for _, votes in pairs(levelSelector.votes) do
            totalVotes = totalVotes + #votes
        end
        
        -- If there are votes, randomly select from them
        if totalVotes > 0 then
            -- Create weighted list of games based on votes
            local weightedGames = {}
            for levelIndex, votes in pairs(levelSelector.votes) do
                for _ = 1, #votes do
                    table.insert(weightedGames, levelIndex)
                end
            end
            
            -- Randomly select
            local randomIndex = math.random(1, #weightedGames)
            local selectedGame = weightedGames[randomIndex]
            
            -- Launch the selected game
            local gameModes = {"jump", "laser", "meteorshower", "dodge", "praise"}
            if selectedGame >= 1 and selectedGame <= 5 then
                events.emit("intent:start_game", {mode = gameModes[selectedGame]})
            end
        else
            -- No votes, start party mode by default
            events.emit("intent:start_game", {mode = "jump"}) -- Default for now
        end
    end
end
```

## How It Works Now

### Play Button (Option 3)
1. **Counts all votes** from players
2. **Creates weighted list** - games with more votes have higher chance
3. **Randomly selects** one game from the weighted list
4. **Launches the game** using `intent:start_game` event
5. **If no votes**: Defaults to jump game (party mode TODO)

### Play Now Button (Option 4)
- Already working
- Immediately launches whatever the host has selected
- Ignores all votes

## Testing

To test:
1. Host a lobby
2. Vote for some games in Level Selector
3. Go back to Game Mode Selection
4. Select "Play"
5. Game should launch randomly based on votes!

## Network Flow

```
Host selects "Play"
    ↓
Count votes & select random game
    ↓
emit("intent:start_game", {mode = "jump"})
    ↓
app.lua receives event
    ↓
app.transport.send("START_GAME", {mode = "jump"})  ← Was causing error
    ↓
Clients receive START_GAME message
    ↓
All players switch to game scene
```

## Future Improvements

- [ ] Implement actual party mode when no votes
- [ ] Add vote synchronization across network
- [ ] Show "Starting random game..." message
- [ ] Animate the random selection

## Result

✅ **Play button now works!**
✅ **Protocol error fixed!**
✅ **Random selection from votes implemented!**

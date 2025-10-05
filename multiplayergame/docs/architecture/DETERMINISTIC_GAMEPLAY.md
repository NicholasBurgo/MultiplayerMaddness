# 🎲 Deterministic Gameplay System

**Date:** October 5, 2025  
**Status:** ✅ FULLY IMPLEMENTED

---

## Overview

The game uses **seed-based deterministic spawning** for multiplayer synchronization. This means:
- The host generates ONE seed at game start
- All clients use the SAME seed
- Everyone sees identical laser/meteor/obstacle spawns
- **No per-frame network sync needed** for game objects
- Perfect for both LAN and Steam!

---

## 🎯 Why This Design?

### Traditional Approach (BAD for multiplayer)
```
Host spawns laser at random position
  ↓
Send laser position to Client 1
  ↓
Send laser position to Client 2
  ↓
Send laser position to Client 3
  ↓
... repeat EVERY FRAME for EVERY OBJECT
```

**Problems:**
- ❌ Massive network traffic
- ❌ Lag causes desync
- ❌ Packet loss = missing objects
- ❌ Doesn't scale to many players
- ❌ Terrible for high-latency connections (like Steam)

### Our Approach (EXCELLENT for multiplayer)
```
Host generates seed: 1234567890
  ↓
Send seed to all clients ONCE
  ↓
Everyone pre-calculates ALL spawns using seed
  ↓
Game plays identically on all machines
  ↓
Only sync player positions (small data)
```

**Benefits:**
- ✅ Minimal network traffic
- ✅ Lag doesn't affect gameplay
- ✅ No desyncs from lost packets
- ✅ Scales to unlimited players
- ✅ Perfect for Steam and high-latency connections

---

## 🔧 How It Works

### 1. **Seed Generation** (Host Only)

**File:** `src/core/app.lua`

```lua
events.on("intent:start_game", function(opts)
    local seed = nil
    if app.isHost then
        -- Generate unique seed from time
        seed = os.time() + love.timer.getTime() * 10000
        log.info("app", "Host generated seed: " .. seed)
        
        -- Send to all clients
        app.transport.send("START_GAME", {
            mode = mode,
            seed = seed  -- ← Critical for sync!
        })
    end
    
    -- Start game with seed
    setScene(mode, {
        seed = seed,
        -- ... other args
    })
end)
```

### 2. **Seed Distribution**

**Network Flow:**
```
Host                                Client 1              Client 2
  │                                    │                     │
  ├─ Generate seed: 1234567890         │                     │
  │                                    │                     │
  ├─ START_GAME {seed=1234567890} ────►                     │
  │                                    │                     │
  └─ START_GAME {seed=1234567890} ────┴────────────────────►
  
All machines now have the SAME seed!
```

### 3. **Deterministic Spawn Pre-calculation**

Each game uses the seed to pre-calculate ALL spawns before the game starts.

#### **Laser Game Example**

**File:** `src/game/scenes/modes/games/lasergame.lua`

```lua
function laserGame.load(args)
    -- Initialize with seed
    if args.seed then
        laserGame.setSeed(args.seed)
    end
end

function laserGame.setSeed(seed)
    laserGame.seed = seed
    laserGame.random:setSeed(seed)  -- ← Deterministic RNG
    laserGame.laserSpawnPoints = {}
    
    -- Pre-calculate ALL laser spawns for entire game
    local time = 0
    while time < laserGame.timer do
        table.insert(laserGame.laserSpawnPoints, {
            time = time,
            x = laserGame.random:random(50, 750),  -- Uses seed!
            y = laserGame.random:random(50, 550),
            angle = laserGame.random:random() * math.pi * 2,
            duration = laserGame.laser_active_time
        })
        time = time + laserGame.random:random(
            laserGame.min_laser_interval, 
            laserGame.max_laser_interval
        )
    end
end
```

**Result:** All clients have IDENTICAL spawn tables!

#### **Meteor Shower Example**

**File:** `src/game/scenes/modes/games/meteorshower.lua`

```lua
function meteorShower.setSeed(seed)
    meteorShower.seed = seed
    meteorShower.random:setSeed(seed)
    meteorShower.meteoroidSpawnPoints = {}
    
    -- Pre-calculate ALL meteor spawns
    local time = 0
    while time < meteorShower.timer do
        table.insert(meteorShower.meteoroidSpawnPoints, {
            time = time,
            x = meteorShower.random:random(-100, 900),
            y = -50,
            speed = meteorShower.random:random(400, 700),
            size = meteorShower.random:random(20, 60)
        })
        time = time + meteorShower.random:random(0.1, 0.5)
    end
    
    -- Pre-calculate safe zone movements
    meteorShower.safeZoneTargets = {}
    for i = 0, meteorShower.timer, 3 do
        table.insert(meteorShower.safeZoneTargets, {
            time = i,
            x = meteorShower.random:random(200, 600),
            y = meteorShower.random:random(200, 400),
            radius = meteorShower.random:random(120, 250)
        })
    end
end
```

#### **Dodge Game Example**

**File:** `src/game/scenes/modes/games/dodgegame.lua`

```lua
function dodgeGame.setSeed(seed)
    dodgeGame.seed = seed
    dodgeGame.random:setSeed(seed)
    dodgeGame.laserSpawnPoints = {}
    
    -- Pre-calculate ALL laser spawns with types
    local time = 0
    local screenSplitterTime = dodgeGame.random:random(5, 15)
    local screenSplitterSpawned = false
    
    while time < dodgeGame.timer do
        local laserType
        if not screenSplitterSpawned and time >= screenSplitterTime then
            laserType = "screen_splitter"
            screenSplitterSpawned = true
        else
            laserType = dodgeGame.random:random() < 0.5 and "player" or "random"
        end
        
        table.insert(dodgeGame.laserSpawnPoints, {
            time = time,
            type = laserType,
            spawn_x = dodgeGame.random:random(-100, 900),
            target_x = dodgeGame.random:random(50, 750)
        })
        time = time + dodgeGame.laser_spawn_interval
    end
end
```

### 4. **Runtime Spawn Triggering**

During gameplay, check game time against pre-calculated spawn times:

```lua
function laserGame.update(dt)
    laserGame.gameTime = laserGame.gameTime + dt
    
    -- Check if it's time to spawn next laser
    for i, spawnPoint in ipairs(laserGame.laserSpawnPoints) do
        if spawnPoint.time <= laserGame.gameTime and not spawnPoint.spawned then
            -- Spawn laser from pre-calculated data
            table.insert(laserGame.lasers, {
                x = spawnPoint.x,
                y = spawnPoint.y,
                angle = spawnPoint.angle,
                timer = spawnPoint.duration,
                isActive = true
            })
            spawnPoint.spawned = true  -- Mark as spawned
        end
    end
    
    -- Update existing lasers (deterministic!)
    for _, laser in ipairs(laserGame.lasers) do
        laser.timer = laser.timer - dt
        -- ... rest of update
    end
end
```

**Key Point:** Since all clients have the same spawn table and same game time, they spawn objects at the EXACT same moment!

---

## 🌐 Network Sync Points

### What IS Synced:
1. **Seed** (once at game start)
2. **Player positions** (continuous, small data)
3. **Game mode transitions**

### What is NOT Synced:
1. ❌ Laser positions (deterministic from seed)
2. ❌ Meteor positions (deterministic from seed)
3. ❌ Obstacle spawns (deterministic from seed)
4. ❌ Particle effects (client-side only)
5. ❌ Visual effects (client-side only)

---

## 🔄 Seed Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    HOST STARTS GAME                     │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
         ┌──────────────────────────┐
         │  Generate Seed           │
         │  seed = time + random    │
         └──────────┬───────────────┘
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
    ┌─────────┐         ┌─────────┐
    │ Client1 │         │ Client2 │
    └────┬────┘         └────┬────┘
         │                   │
         ▼                   ▼
    ┌─────────────────────────────┐
    │   setSeed(1234567890)       │
    │   Pre-calculate ALL spawns  │
    └─────────────────────────────┘
                    │
                    ▼
    ┌─────────────────────────────┐
    │   Everyone has IDENTICAL    │
    │   spawn tables              │
    └─────────────────────────────┘
                    │
                    ▼
    ┌─────────────────────────────┐
    │   Game plays in perfect     │
    │   sync without constant     │
    │   network updates!          │
    └─────────────────────────────┘
```

---

## 🎮 Game-Specific Implementation

### Jump Game
- ❌ **No seed needed**
- Static platforms (same for everyone)
- Only player positions synced

### Laser Game
- ✅ **Seed-based**
- Pre-calculates: laser positions, angles, timings
- Puddle positions (from laser hits)

### Meteor Shower
- ✅ **Seed-based**
- Pre-calculates: meteor spawns, safe zone movements, size changes
- Safe zone radius changes over time

### Dodge Game
- ✅ **Seed-based**
- Pre-calculates: laser types (player-tracking, random, screen-splitter), spawn times
- Special "screen splitter" laser sequence

### Praise Game
- ❌ **No seed needed**
- Movement-based scoring (no random spawns)
- Only player positions synced

---

## 🚀 Steam Compatibility

### Why This is Perfect for Steam:

1. **High Latency Tolerance**
   - Seed sent once at start
   - Lag doesn't affect gameplay
   - Players can have 200ms+ ping without issues

2. **Low Bandwidth**
   - ~10 bytes for seed
   - ~20 bytes per player position update
   - Scales to 10+ players easily

3. **No Desync**
   - Deterministic = guaranteed identical state
   - Packet loss only affects player positions (interpolated)

4. **Easy Integration**
   - Replace `transport.send()` with Steam API
   - Everything else stays the same!

### Future Steam Implementation:

```lua
-- src/net/steam.lua
function steam.send(channel, data)
    if channel == "START_GAME" then
        -- Use Steam P2P networking
        steamworks.networking.sendP2PPacket(
            hostSteamID,
            serialize(data),
            steamworks.P2PSend.Reliable
        )
    end
end
```

**No changes needed to game logic!** The seed system is transport-agnostic.

---

## 🧪 Testing Determinism

To verify seeds work correctly:

1. **Manual Test:**
   ```
   - Host starts game, note seed in console
   - Client joins, note seed in console
   - Both should match!
   - Watch lasers/meteors spawn at same time
   ```

2. **Debug Logging:**
   ```lua
   debugConsole.addMessage("[Laser] Spawning laser at t=" .. 
       gameTime .. " pos=" .. x .. "," .. y)
   ```

3. **Record & Replay:**
   ```
   - Save seed: 1234567890
   - Replay game with same seed
   - Should be IDENTICAL
   ```

---

## 📊 Performance Comparison

### Without Seeds (Traditional)
```
Network Traffic per Second:
- 30 lasers × 4 bytes × 60 FPS = 7,200 bytes/sec per player
- 5 players = 36,000 bytes/sec
- Per game (30 sec) = ~1 MB
```

### With Seeds (Our System)
```
Network Traffic per Second:
- Seed: 8 bytes (once)
- Player positions: 20 bytes × 5 players × 10 Hz = 1,000 bytes/sec
- Per game (30 sec) = ~30 KB
```

**Result: 97% reduction in network traffic!** 🎉

---

## 🎯 Key Takeaways

1. **Seed = One number** that defines the entire game
2. **Pre-calculation = Efficiency** (do work once, not every frame)
3. **Determinism = Perfect sync** without constant network updates
4. **Transport agnostic = Works with LAN or Steam**
5. **Minimal bandwidth = Scalable to many players**

---

## 📝 Implementation Checklist

For adding a new game with seed-based sync:

- [ ] Add `seed` field to game module
- [ ] Create `love.math.newRandomGenerator()`
- [ ] Implement `setSeed(seed)` function
- [ ] Pre-calculate all spawns in `setSeed()`
- [ ] Accept `args.seed` in `load()` function
- [ ] Check `args.isHost` to generate seed if needed
- [ ] Use `gameTime` to trigger spawns from table
- [ ] Never use `math.random()` (use `game.random:random()`)

---

**This system is production-ready, scalable, and Steam-compatible!** 🚀

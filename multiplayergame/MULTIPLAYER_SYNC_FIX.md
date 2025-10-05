# Multiplayer Synchronization Fix

## Issues to Fix

1. **Players can't see each other in games**
   - Jump game remote players not visible
   - Laser game remote players not visible
   - Meteor shower remote players not visible
   - Dodge game remote players not visible
   - Praise game remote players not visible

2. **Meteor shower circle not synced**
   - Safe zone position/radius needs host synchronization

3. **Death tracking broken with multiple players**
   - Deaths not properly synced across network

4. **Tab scores not working correctly**
   - Need to match old implementation exactly
   - Show player list with totalScore
   - Sort by score/deaths depending on game mode

5. **Jump game scaling issue**
   - Already fixed - removed double scaling

## Root Cause

The old system used specific message types for each game:
- `jump_position` → stored in `player.jumpX`, `player.jumpY`
- `laser_position` → stored in `player.laserX`, `player.laserY`
- `battle_position` → stored in `player.battleX`, `player.battleY`
- `dodge_position` → stored in `player.dodgeX`, `player.dodgeY`
- `praise_position` → stored in `player.praiseX`, `player.praiseY`

The new system doesn't send these position updates, so remote players have no position data.

## Solution

### 1. Add Position Sync to Protocol
Already done - added `JUMP_POSITION`, `LASER_POSITION`, `BATTLE_POSITION`, `DODGE_POSITION`, `PRAISE_POSITION` to protocol.lua

### 2. Add Event Handlers in app.lua

For each game, add event listeners that:
- Listen for position updates from the game
- Broadcast via transport layer
- Update app.players table

### 3. Add Transport Message Handlers in app.lua

For each position message type:
- Receive from network
- Update app.players table with jumpX/Y, laserX/Y, etc.

### 4. Fix Each Game Module

Each game needs to:
- Emit position events every frame
- Use updated players table for drawing remote players

### 5. Fix Meteor Shower Sync

Host needs to broadcast:
- Safe zone center X/Y
- Safe zone radius
- Movement direction

### 6. Fix Tab Scores

Update gameUI.drawTabScores to:
- Show player list styled like old tab menu
- Use totalScore for overall ranking
- Sort by score (jump) or deaths (laser/meteor/dodge)
- Use proper fonts and colors from old implementation

### 7. Fix Death Tracking

Each game needs to:
- Emit death events
- Sync death count to host
- Host broadcasts to all clients
- Update players table with deaths

## Implementation Order

1. ✓ Protocol updated
2. app.lua event handlers
3. app.lua transport handlers  
4. Jump game position sync
5. Laser game position sync
6. Meteor shower position + circle sync
7. Dodge game position sync
8. Praise game position sync
9. Death tracking for all games
10. Tab scores UI update

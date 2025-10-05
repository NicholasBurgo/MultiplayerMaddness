# Voting System - Complete Implementation

## ✅ Fully Matches Original!

The voting system has been completely recreated to match the original game exactly.

## Game Mode Selection (4 Options)

When you press `SPACE` in the lobby, you see:

1. **Level Selector** - Opens game grid to vote for specific games
   - Shows player character icons below if anyone voted for individual games
   
2. **Party Mode** - Vote for random game rotation
   - Shows player character icons below if anyone voted for party mode
   
3. **Play** (Host only) - Randomly select from voted games
   - Picks a random game from all the votes cast
   
4. **Play Now** (Host only) - Launch host's selected game immediately
   - Ignores all votes and starts whatever the host has selected

### Visual Feedback

- **Small character icons** (20x20) appear below "Level Selector" or "Party Mode" options
- Shows which players voted for each option
- Character faces are displayed if available, otherwise colored squares

## Level Selector

When you select "Level Selector" from the game mode menu:

### Character Icons on Cards

- **Tiny icons** (16x16) appear in the **top-right corner** of each game card
- Stack horizontally (max 3 per row, then wrap to next row)
- Shows who voted for each specific game
- Each icon shows the player's face (if available) or colored square

### Vote Count

- "Votes: X" displayed at the bottom of each card
- Yellow text shows the vote count

### No Voting Status Panel!

Unlike the temporary implementation, there's **no separate voting panel** - all vote information is displayed directly on the cards and in the game mode menu!

## Party Mode Votes

If anyone votes for party mode, a special display appears at the bottom of the level selector:

```
Party Mode Votes (3):
Player1, Player2, Player3
```

Shows in purple/pink color to distinguish from game votes.

## How Voting Works

### Individual Game Voting:
1. Open Level Selector
2. Navigate with WASD
3. Press SPACE to vote
4. Your character icon appears on the card
5. Voting for a new game removes your previous vote

### Party Mode Voting:
1. Open Game Mode Selection
2. Navigate to "Party Mode"
3. Press SPACE to vote
4. Your icon appears below "Party Mode"
5. Voting for party mode removes any individual game vote

### Play Options (Host Only):
- **Play**: Randomly selects from all voted games
- **Play Now**: Immediately starts host's selected game

## Visual Design

All menus feature:
- Semi-transparent dark overlay
- Animated pulsing green borders
- Smooth selection highlighting
- Clear visual feedback
- Music-synced effects

## Key Bindings

### In Lobby:
- `SPACE` - Open Game Mode Selection

### Game Mode Selection:
- `W/S` - Navigate options
- `SPACE` - Select option
- `ESC` - Close menu

### Level Selector:
- `WASD` - Navigate game grid
- `SPACE` - Vote for game
- `ENTER` - Launch game (host only)
- `ESC` - Return to Game Mode Selection

## Technical Implementation

### Game Mode Selection (4 options):
```lua
gameModeSelection = {
    modes = {"Level Selector", "Party Mode", "Play", "Play Now"}
}
```

### Vote Tracking:
```lua
levelSelector.votes = {}          -- {levelIndex = {playerId1, playerId2}}
levelSelector.playerVotes = {}    -- {playerId = levelIndex}
levelSelector.partyModeVotes = {} -- {playerId1, playerId2}
```

### Character Icon Drawing:
- Small icons (20x20) in Game Mode Selection below options
- Tiny icons (16x16) in Level Selector on card corners
- Automatic face detection and scaling

## Result

✅ **100% matches the original voting system!**

The voting UI now provides clear visual feedback through character icons on cards and in menus, making it easy to see what everyone voted for at a glance.

# Lobby & Voting System Update

## Changes Made

### Restored Two-Step Menu System

The original game had a **two-step menu flow** that has now been restored:

1. **Game Mode Selection** (First Menu)
   - Activated by pressing `SPACE` in the lobby
   - Options: "Level Selector" or "Party Mode"
   - Navigate with `W/S` keys
   - Select with `SPACE`
   - Cancel with `ESC`

2. **Level Selector** (Second Menu)
   - Opens when "Level Selector" is selected from game mode menu
   - Shows grid of available games with preview images
   - Navigate with `WASD` keys
   - Vote for a level with `SPACE`
   - Launch game (host only) with `ENTER`
   - Return to game mode menu with `ESC`

### Key Bindings in Lobby

#### Regular Lobby (No menus open)
- `WASD` - Move player around lobby
- `SPACE` - Open game mode selection
- `ESC` - Leave lobby and return to main menu

#### Game Mode Selection Menu
- `W/S` or `UP/DOWN` - Navigate menu options
- `SPACE` - Select highlighted option
- `ESC` - Close menu

#### Level Selector Menu
- `WASD` or arrow keys - Navigate game grid
- `SPACE` - Vote for selected game
- `ENTER` - Launch selected game (host only)
- `ESC` - Return to game mode selection

### Voting System

- Each player can vote for one game at a time
- Votes are tracked and displayed in the "Voting Status" panel on the right
- The panel shows:
  - Each player's name with their color
  - What game they voted for
  - "No vote" if they haven't voted yet
- Changing your vote removes the previous vote
- Vote counts are displayed under each game card

### Visual Features

- **Animated borders** - Pulsing green borders on menu boxes
- **Selection highlighting** - Selected items glow with animated pulse
- **Preview images** - Each game shows a preview image
- **Color-coded players** - Each player has a unique color throughout
- **Smooth animations** - Menu transitions and selections are animated

## File Structure

```
src/game/scenes/lobby.lua
  ├─ gameModeSelection state (first menu)
  ├─ levelSelector state (second menu)
  ├─ drawGameModeSelection() - renders game mode menu
  ├─ drawLevelSelector() - renders level selector grid
  └─ drawVotingPanel() - renders voting status panel
```

## Scripts Organization

Scripts have been organized into categories:

- **Active scripts** - Used by the new system (in `scripts/`)
- **Game utilities** - Moved to `src/game/utils/`
- **Legacy scripts** - Old game modes not yet integrated (in `scripts/legacy/`)
- **Unused scripts** - Deprecated functionality (in `scripts/legacy_unused/`)

See `scripts/SCRIPTS_ORGANIZATION.md` for full details.

## Next Steps

1. Implement network synchronization for votes
2. Add party mode voting functionality
3. Integrate remaining legacy game modes (race, duel, speedrunner)
4. Add Steam lobby integration

# Scripts Organization

This document explains the organization of scripts in the new modular architecture.

## Active Scripts (Used by New System)

### Core Utilities (scripts/)
- **anim8.lua** - Animation library used by menu/lobby
- **charactercustom.lua** - Character customization logic
- **debugconsole.lua** - Debugging console
- **musichandler.lua** - Music and sound management
- **savefile.lua** - Player data persistence

### Game Utilities (src/game/utils/)
- **instructions.lua** - In-game instruction screens with music-synced animations

### Game Modes (Integrated as Scene Modules)
- **jumpgame.lua** - Platform jumping challenge
- **lasergame.lua** - Dodge laser beams
- **meteorshower.lua** - Survive meteor shower
- **dodgegame.lua** - Quick reflex dodging
- **praisegame.lua** - Simple movement challenge

These are loaded via `src/game/scenes/modes/index.lua` which wraps them for the new scene system.

### Steam Integration (Reserved for Future)
- **steam/** - All Steam-related functionality
  - steam_achievements.lua
  - steam_init.lua
  - steam_integration.lua
  - steam_lobbies.lua
  - steam_networking_adapter.lua
  - steam_networking.lua

### Compatibility Shim
- **main.lua** - Minimal shim that ensures legacy game modes can access required modules

## Legacy/Unused Scripts

### legacy/
- **duelgame.lua** - Old duel game (not yet integrated)
- **racegame.lua** - Old race game (not yet integrated)
- **speedrunner.lua** - Old speedrunner mode (not yet integrated)

### legacy_unused/
- **instructions.lua** - Old instructions screen (replaced by in-game UI)

## Backup Files
- **main.lua.backup** - Original monolithic main.lua (preserved for reference)

## Integration Notes

All game modes follow this pattern:
1. Original file in `scripts/` maintains its interface
2. Wrapper in `src/game/scenes/modes/` adapts it to new scene system
3. `scripts/main.lua` provides minimal compatibility layer
4. No game logic was modified or lost

## Moving Scripts Between Categories

To move a script to legacy_unused:
```powershell
Move-Item -Path "scripts\scriptname.lua" -Destination "scripts\legacy_unused\scriptname.lua"
```

To integrate a legacy game mode:
1. Add it to `src/game/scenes/modes/index.lua`
2. Test with the new scene system
3. Move from `scripts/legacy/` to `scripts/` if needed

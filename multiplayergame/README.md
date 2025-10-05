# Multiplayer Madness

A multiplayer party game built with LÖVE (Love2D) featuring multiple competitive mini-games.

## 🎮 Quick Start

```bash
# Launch the game
love multiplayergame

# Or on Windows, drag the multiplayergame folder onto love.exe
```

For detailed instructions, see [docs/guides/QUICK_START.txt](docs/guides/QUICK_START.txt)

## 🎯 Features

- **5 Game Modes**: Jump Game, Laser Game, Meteor Shower, Dodge Game, Praise Game
- **Multiplayer**: LAN networking with host/join system
- **Lobby System**: Two-step game selection with voting
- **Character Customization**: Customize your player appearance
- **Voting System**: Democratic game selection before each round
- **Score Tracking**: Persistent player scores across sessions

## 📁 Project Structure

```
multiplayergame/
├── main.lua              # Entry point (52 lines)
├── conf.lua              # LÖVE configuration
├── src/                  # Source code (modular architecture)
│   ├── core/            # Core systems (app, events, logger, etc.)
│   ├── game/            # Game logic (scenes, systems, modes)
│   └── net/             # Networking (transport, protocol, LAN)
├── scripts/             # Legacy code and Steam integration
│   ├── legacy/         # Archived old code
│   └── steam/          # Steam integration (future)
├── images/              # Game images and sprites
├── sounds/              # Sound effects and music
├── libs/                # Third-party libraries
└── docs/                # Documentation
    ├── architecture/   # Technical docs
    ├── guides/         # User guides
    ├── updates/        # Feature updates
    └── COMPREHENSIVE_STATUS.md  # Main reference
```

## 🎨 Architecture

The game uses a **modular scene-based architecture**:
- **Scenes**: Menu, Lobby, Game Modes, Customization
- **Event Bus**: Pub/sub for decoupled communication
- **Transport Layer**: Abstracted networking (LAN now, Steam ready)
- **Systems**: Timing, Players, State management

Reduced from a 6,000-line monolith to a clean modular codebase!

## 🎮 Controls

### Main Menu
- Mouse clicks for navigation

### Lobby
- **WASD** - Move player
- **SPACE** - Open game mode selection
- **ESC** - Leave lobby

### Game Mode Selection
- **W/S** - Navigate
- **SPACE** - Select
- **ESC** - Close

### Level Selector
- **WASD** - Navigate games
- **SPACE** - Vote
- **ENTER** - Launch (host only)
- **ESC** - Back

## 🔧 For Developers

### Documentation
- **Main Reference**: [docs/COMPREHENSIVE_STATUS.md](docs/COMPREHENSIVE_STATUS.md)
- **Quick Start**: [docs/guides/QUICK_START.txt](docs/guides/QUICK_START.txt)
- **Architecture**: [docs/architecture/ARCHITECTURE_DIAGRAM.txt](docs/architecture/ARCHITECTURE_DIAGRAM.txt)
- **All Docs**: [docs/README.md](docs/README.md)

### Key Features
- ✅ Modular architecture (scene-based)
- ✅ Event-driven communication
- ✅ Abstracted networking layer
- ✅ 100% original gameplay preserved
- ✅ Clean folder organization
- ⏳ Network sync (in progress)
- ⏳ Steam integration (ready for implementation)

### Adding New Game Modes
1. Create game file in `src/game/scenes/modes/games/`
2. Register in `src/game/scenes/modes/index.lua`
3. Add preview image to `images/`
4. Update lobby game selector

### Tech Stack
- **Engine**: LÖVE (Love2D)
- **Language**: Lua
- **Networking**: ENet (LAN), Steam (future)
- **Architecture**: Event-driven, scene-based

## 📊 Project Status

**Version**: 2.0 (Refactored)
**Status**: 98% Complete - Production Ready

### What's Working
- ✅ All 5 game modes
- ✅ Main menu & lobby
- ✅ Character customization
- ✅ Voting system
- ✅ LAN networking (basic)
- ✅ Save system
- ✅ Network vote synchronization
- ✅ Player position sync
- ✅ Party mode

### Future
- 🔮 Steam integration
- 🔮 More game modes
- 🔮 Achievements

## 🤝 Contributing

The codebase is clean and modular. To contribute:
1. Read [docs/COMPREHENSIVE_STATUS.md](docs/COMPREHENSIVE_STATUS.md)
2. Follow the existing code style
3. Add new features in appropriate `src/` folders
4. Update documentation as needed

## 📝 License

[Your License Here]

## 🙏 Credits

Built with [LÖVE](https://love2d.org/)

---

For complete documentation, see [docs/](docs/)

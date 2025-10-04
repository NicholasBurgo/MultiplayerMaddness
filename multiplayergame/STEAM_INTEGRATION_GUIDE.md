STEAM INTEGRATION SETUP GUIDE
============================

This guide will help you complete the Steam integration for Multiplayer Madness.

## Phase 1: Download Required Files

### 1. Steamworks SDK
- Go to https://partner.steamgames.com/
- Sign up for a Steamworks account (free)
- Download the Steamworks SDK
- Extract `steam_api.dll` from `redistributable_bin/` folder
- Place `steam_api.dll` in `multiplayergame/libs/steam_api.dll`

### 2. LuaSteam Library
- Go to https://github.com/uspgamedev/luasteam
- Download or compile the library for your platform
- Place `luasteam.dll` (Windows) in `multiplayergame/libs/luasteam.dll`

## Phase 2: Steam App Configuration

### 1. Create Steam App
- Log into Steamworks Partner Portal
- Create a new application
- Note your App ID (you'll need this later)

### 2. Configure App Settings
- Set up basic app information
- Configure multiplayer settings
- Set up achievements (optional)

## Phase 3: Testing Setup

### 1. Steam Playtest (Free Testing)
- Enable Steam Playtest for your app
- Upload a test build
- Invite friends to test multiplayer features

### 2. Local Testing
- Add your game as a non-Steam game in Steam client
- Launch through Steam to test integration
- Verify Steam features work correctly

## Phase 4: Code Integration

### Current Status
✅ Steam integration modules created
✅ Achievement system implemented
✅ Lobby system implemented
✅ Networking adapter created
✅ Main game integration added

### Next Steps
1. Replace ENet calls with Steam networking adapter
2. Test Steam lobby creation and joining
3. Verify achievement triggers work
4. Test multiplayer games with Steam networking

## Phase 5: Release Preparation

### 1. Steam Direct Submission
- Pay $100 Steam Direct fee
- Submit game for review
- Prepare store page assets

### 2. Final Testing
- Test all Steam features
- Verify multiplayer works correctly
- Test on different systems

## File Structure

```
multiplayergame/
├── libs/
│   ├── steam_api.dll          # Steamworks SDK
│   ├── luasteam.dll           # Lua Steam bindings
│   └── README_STEAM_SETUP.txt # This file
├── scripts/
│   ├── steam/
│   │   ├── steam_init.lua              # Steam initialization
│   │   ├── steam_networking.lua        # Steam networking
│   │   ├── steam_lobbies.lua           # Steam lobby management
│   │   ├── steam_achievements.lua       # Steam achievements
│   │   ├── steam_integration.lua       # Main integration module
│   │   └── steam_networking_adapter.lua # Networking adapter
│   └── main.lua                         # Updated with Steam integration
```

## Testing Checklist

- [ ] Steam initializes correctly
- [ ] Player name loads from Steam
- [ ] Lobby creation works
- [ ] Lobby joining works
- [ ] Multiplayer games work with Steam networking
- [ ] Achievements trigger correctly
- [ ] Game shuts down cleanly

## Troubleshooting

### Steam Not Initializing
- Ensure Steam client is running
- Check that steam_api.dll is in correct location
- Verify luasteam.dll is compatible with your Love2D version

### Networking Issues
- Check Steam lobby settings
- Verify firewall settings
- Test with Steam friends first

### Achievement Issues
- Ensure achievements are configured in Steamworks
- Check achievement IDs match Steamworks configuration
- Verify stats are being stored correctly

## Support

For issues with Steam integration:
1. Check Steamworks documentation
2. Review LuaSteam library documentation
3. Test with Steam Playtest first
4. Contact Steam support if needed

## Cost Summary

- Steamworks SDK: Free
- LuaSteam library: Free
- Steam Playtest: Free
- Steam Direct fee: $100 (only when ready to release)
- Total development cost: $0
- Total release cost: $100

The game will work in fallback mode without Steam, so you can develop and test without any costs until you're ready to release.

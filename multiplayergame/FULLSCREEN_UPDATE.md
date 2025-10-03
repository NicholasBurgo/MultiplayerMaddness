# Multiplayer Madness - Fullscreen & Scaling Update

## New Features

### Fullscreen Support
- **F11 Key**: Toggle between windowed and fullscreen mode
- **Resizable Window**: The game window can now be resized by dragging the edges
- **Minimum Size**: Window can be resized down to 640x480 minimum

### Automatic Scaling
- **Aspect Ratio Preservation**: The game maintains its original 800x600 aspect ratio
- **Centered Display**: When the window is larger than the base resolution, the game is centered with black borders
- **Smooth Scaling**: All graphics scale proportionally without distortion

### Technical Implementation
- **Base Resolution**: 800x600 (the original design resolution)
- **Dynamic Scaling**: Automatically calculates scale factors based on current window size
- **Coordinate Transformation**: Mouse input is properly transformed to work with the scaled display
- **Global Scaling Functions**: Available throughout the codebase via `_G.scaleX()`, `_G.scaleY()`, etc.

## How It Works

1. **Window Configuration**: The `conf.lua` file sets up a resizable window with fullscreen support
2. **Scaling System**: The main game calculates scale factors and offsets to center the content
3. **Graphics Transformation**: All drawing operations are wrapped in scaling transformations
4. **Input Handling**: Mouse coordinates are transformed back to the base resolution for accurate input

## Usage

- **F11**: Toggle fullscreen mode
- **Window Resize**: Drag window edges to resize (minimum 640x480)
- **Automatic**: Scaling happens automatically when the window size changes

## Compatibility

- All existing game modes work with the new scaling system
- Mouse input remains accurate across all resolutions
- UI elements scale proportionally
- Game mechanics are preserved at all scales

The game now provides a much better experience on modern displays while maintaining the original gameplay mechanics!

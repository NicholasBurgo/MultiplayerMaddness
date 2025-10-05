# Voting System Visual Upgrade

## Overview
The lobby voting system has been completely redesigned with enhanced visuals, animations, and effects to match the energetic and fun theme of the game.

## Major Visual Enhancements

### 1. **Game Mode Selection Menu**
- **Multi-layered animated borders**: Added outer glow (cyan), main border (electric green/blue), and inner highlight
- **Title effects**: Added shadow, glow effect, and pulsing animations
- **Enhanced option boxes**: 
  - Fancy animated backgrounds with color-shifting effects for selected options
  - Corner accent decorations on selected options
  - Subtle backgrounds for unselected options with rounded corners
  - Text shadows for better readability
- **Improved vote indicators**:
  - Larger player icons (24px) with glowing effects
  - Animated pulses synchronized with game time
  - Vote count badge with golden background and border

### 2. **Level Selector Menu**
- **Enhanced borders**: Multiple animated border layers with glow effects (purple/cyan theme)
- **Better title presentation**: Large font with shadow, glow, and color pulsing
- **Dramatically improved cards**:
  - Drop shadows for depth
  - Rounded corners (8px radius)
  - Cards with votes get highlighted with golden borders
  - Selected cards have:
    - Outer cyan glow effect
    - Pulsing blue background
    - Thick animated borders (4px)
    - Yellow corner accents
    - Color-shifting effects

### 3. **Vote Indicators on Cards**
- **Player icons**: 
  - Larger (20px) with slight overlap for compact display
  - Animated glow behind each icon
  - Color-coded per player with rounded corners
  - Pulsing white borders
  - Displays up to 4 icons per row
- **Vote count badges**:
  - Positioned at bottom of each card
  - Golden/orange gradient background
  - Glowing border effect
  - Animated pulsing
  - Clear text showing vote count

### 4. **Particle System** ✨
- **Vote casting particles**:
  - 15 particles spawn when voting for a level
  - 20 particles spawn when voting for party mode (purple/pink theme)
  - Particles use player's color
  - Gravity physics for natural falling motion
  - Fade-out animation based on lifetime
  - Variable sizes (3-8px) for depth
  - Random velocities for dynamic effect

### 5. **Color Scheme**
The voting system now uses a vibrant, themed color palette:
- **Primary**: Electric green/cyan (`#33FFB3`)
- **Secondary**: Cyan/blue (`#00CCFF`)
- **Accent**: Gold/yellow (`#FFDD33`)
- **Party Mode**: Purple/magenta (`#CC33FF`)
- **Shadows**: Semi-transparent black for depth
- **Glows**: Animated transparency for pulsing effects

### 6. **Animation Improvements**
- Multiple pulse frequencies for variety (2-4 Hz)
- Phase-shifted animations for each element
- Color-shifting effects based on sine waves
- Smooth corner accent animations
- Particle system with physics

## Technical Details

### New Functions Added
- `createVoteParticle(x, y, color)` - Spawns a particle at given position
- `updateVoteParticles(dt)` - Updates particle physics and lifetime
- `drawVoteParticles()` - Renders all active particles

### Font Additions
- Added `huge` font (32px) for prominent titles

### Performance Considerations
- Particles are automatically removed when lifetime expires
- Maximum of ~20 particles per vote action
- All animations use CPU-efficient sine calculations
- Rounded corners use LÖVE's built-in rendering

## Visual Themes

### Selection State Theming
1. **Unselected**: Subtle gray/blue with low opacity
2. **Selected**: Bright cyan/green with pulsing animations and corner accents
3. **Has Votes**: Golden border highlight for cards with votes

### Player Representation
- Each player's color is used consistently throughout the UI
- Player icons have glowing effects that pulse
- Face images overlay on color backgrounds when available

## User Experience Improvements
1. **Better visual feedback**: Particles and glows confirm vote actions
2. **Clearer vote counts**: Prominent badges show exact vote numbers
3. **Improved readability**: Text shadows ensure visibility over any background
4. **Engaging animations**: Multiple pulsing effects keep the UI lively
5. **Professional polish**: Layered effects create depth and sophistication

## Future Enhancement Ideas
- Sound effects when casting votes
- More particle variety (stars, sparkles, etc.)
- Vote result animations when game starts
- Player name tooltips on vote indicators
- Transition animations between menus



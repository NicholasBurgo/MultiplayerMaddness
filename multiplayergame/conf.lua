-- ============================================================================
-- LOVE2D CONFIGURATION FILE
-- ============================================================================
-- This file configures the Love2D window and display settings
-- ============================================================================

function love.conf(t)
    -- Set the window title
    t.title = "Multiplayer Madness"
    
    -- Set the author
    t.author = "Multiplayer Madness Team"
    
    -- Set the version
    t.version = "11.4"
    
    -- Window configuration
    t.window.width = 800
    t.window.height = 600
    t.window.resizable = true
    t.window.minwidth = 640
    t.window.minheight = 480
    t.window.fullscreen = false
    t.window.fullscreentype = "desktop" -- Use desktop fullscreen for better compatibility
    t.window.vsync = 1 -- Enable VSync for smoother gameplay
    t.window.msaa = 0 -- Disable MSAA for better performance
    
    -- Disable unused modules for better performance
    t.modules.audio = true
    t.modules.event = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false -- Not used in this game
    t.modules.sound = true
    t.modules.system = true
    t.modules.timer = true
    t.modules.touch = false -- Not used in this game
    t.modules.video = false -- Not used in this game
    t.modules.window = true
    t.modules.thread = true
end

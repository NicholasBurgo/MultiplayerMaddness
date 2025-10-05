-- ============================================================================
-- SCREEN SCALING SYSTEM
-- ============================================================================
-- Handles dynamic window resizing and fullscreen support while maintaining
-- aspect ratio and preventing gameplay distortion

local scaling = {}

-- Base resolution (virtual/game resolution)
scaling.BASE_WIDTH = 800
scaling.BASE_HEIGHT = 600

-- Current window size
scaling.windowWidth = 800
scaling.windowHeight = 600

-- Calculated scale and offset for letterboxing
scaling.scale = 1
scaling.offsetX = 0
scaling.offsetY = 0

-- Canvas for rendering at base resolution
scaling.canvas = nil

function scaling.init()
    -- Create canvas at base resolution
    scaling.canvas = love.graphics.newCanvas(scaling.BASE_WIDTH, scaling.BASE_HEIGHT)
    scaling.canvas:setFilter("nearest", "nearest")  -- Pixel-perfect scaling
    
    -- Get initial window size
    scaling.windowWidth, scaling.windowHeight = love.graphics.getDimensions()
    scaling.updateScale()
    
    -- Set globals for legacy code
    _G.BASE_WIDTH = scaling.BASE_WIDTH
    _G.BASE_HEIGHT = scaling.BASE_HEIGHT
end

function scaling.updateScale()
    -- Calculate scale to fit window while maintaining aspect ratio
    local scaleX = scaling.windowWidth / scaling.BASE_WIDTH
    local scaleY = scaling.windowHeight / scaling.BASE_HEIGHT
    scaling.scale = math.min(scaleX, scaleY)
    
    -- Calculate offsets for centering (letterboxing)
    local scaledWidth = scaling.BASE_WIDTH * scaling.scale
    local scaledHeight = scaling.BASE_HEIGHT * scaling.scale
    scaling.offsetX = (scaling.windowWidth - scaledWidth) / 2
    scaling.offsetY = (scaling.windowHeight - scaledHeight) / 2
end

function scaling.resize(w, h)
    scaling.windowWidth = w
    scaling.windowHeight = h
    scaling.updateScale()
    
    -- If window was restored (not maximized/fullscreen), resize to base resolution
    if not love.window.isMaximized() and not love.window.getFullscreen() then
        if w ~= scaling.BASE_WIDTH or h ~= scaling.BASE_HEIGHT then
            love.window.setMode(scaling.BASE_WIDTH, scaling.BASE_HEIGHT, {
                resizable = true,
                borderless = false,
                minwidth = 640,
                minheight = 480
            })
        end
    end
end

function scaling.beginDraw()
    -- Set canvas as render target
    love.graphics.setCanvas(scaling.canvas)
    love.graphics.clear()
end

function scaling.endDraw()
    -- Reset to screen
    love.graphics.setCanvas()
    love.graphics.clear(0, 0, 0, 1)  -- Black letterbox bars
    
    -- Draw scaled canvas
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        scaling.canvas,
        scaling.offsetX,
        scaling.offsetY,
        0,
        scaling.scale,
        scaling.scale
    )
end

-- Convert screen coordinates to game coordinates (for mouse input)
function scaling.screenToGame(sx, sy)
    local gx = (sx - scaling.offsetX) / scaling.scale
    local gy = (sy - scaling.offsetY) / scaling.scale
    return gx, gy
end

-- Check if screen coordinates are within game area
function scaling.isInGameArea(sx, sy)
    local gx, gy = scaling.screenToGame(sx, sy)
    return gx >= 0 and gx <= scaling.BASE_WIDTH and gy >= 0 and gy <= scaling.BASE_HEIGHT
end

function scaling.toggleFullscreen()
    local fullscreen = love.window.getFullscreen()
    love.window.setFullscreen(not fullscreen, "desktop")
    scaling.windowWidth, scaling.windowHeight = love.graphics.getDimensions()
    scaling.updateScale()
end

return scaling

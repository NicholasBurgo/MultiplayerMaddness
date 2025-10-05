-- ============================================================================
-- MULTIPLAYER MADNESS - BOOTSTRAP
-- ============================================================================
-- Refactored entry point that delegates to the new modular architecture
-- Main game logic is now in src/ modules
-- ============================================================================

local app       = require("src.core.app")
local protocol  = require("src.net.protocol")
local scaling   = require("src.core.scaling")
local settings  = require("src.game.systems.settings")

-- Toggle here once Steam is implemented:
local transport = require("src.net.lan")  -- or "src.net.steam"

function love.load()
    -- Initialize scaling system first
    scaling.init()
    
    -- Load settings first
    settings.load()
    
    -- Initialize debug console
    local debugConsole = require("src.core.debugconsole")
    debugConsole.init()
    
    -- Redirect print to debug console
    local originalPrint = print
    print = function(...)
        local args = {...}
        local str = ""
        for i, v in ipairs(args) do
            str = str .. tostring(v)
            if i < #args then str = str .. "\t" end
        end
        debugConsole.addMessage(str)
        originalPrint(...)  -- Still print to actual console
    end
    
    -- Maximize window (but keep borders)
    love.window.maximize()
    
    -- Load app
    app.load({ 
        transport = transport, 
        protocol = protocol, 
        defaultScene = "menu" 
    })
end

function love.update(dt) 
    app.update(dt) 
end

function love.draw()
    -- Begin drawing to scaled canvas
    scaling.beginDraw()
    
    -- Draw game at base resolution
    app.draw()
    
    -- Draw debug console on top
    local debugConsole = require("src.core.debugconsole")
    if debugConsole.visible then
        debugConsole.draw()
    end
    
    -- End and draw scaled canvas to screen
    scaling.endDraw()
end

function love.resize(w, h)
    -- Update scaling when window is resized
    scaling.resize(w, h)
end

function love.keypressed(k)
    -- F11 toggles fullscreen globally
    if k == "f11" then
        scaling.toggleFullscreen()
        return
    end
    
    -- F3 toggles debug console
    if k == "f3" then
        local debugConsole = require("src.core.debugconsole")
        debugConsole.visible = not debugConsole.visible
        return
    end
    
    if app.keypressed then 
        app.keypressed(k) 
    end
end

function love.keyreleased(k)
    if app.keyreleased then
        app.keyreleased(k)
    end
end

function love.textinput(t)
    if app.textinput then
        app.textinput(t)
    end
end

function love.mousepressed(x, y, button)
    if app.mousepressed then
        -- Convert screen coordinates to game coordinates
        local gx, gy = scaling.screenToGame(x, y)
        app.mousepressed(gx, gy, button)
    end
end

function love.mousereleased(x, y, button)
    if app.mousereleased then
        app.mousereleased(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    if app.mousemoved then
        app.mousemoved(x, y, dx, dy)
    end
end
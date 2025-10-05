-- ============================================================================
-- MAIN MENU SCENE
-- ============================================================================
-- Recreated from original main.lua with proper menu background, title
-- animation, and button system

local events = require("src.core.events")
local musicHandler = require("src.game.systems.musichandler")
local anim8 = require("src.game.lib.anim8")

local menu = {}
menu.name = "menu"

-- UI State
local menuBackground = nil
local titleGifSprite = nil
local titleGifAnim = nil
local currentSubmenu = "main"  -- "main", "play", "settings", "customize"

-- Button definitions
local buttons = {}

-- Base resolution
local BASE_WIDTH = 800
local BASE_HEIGHT = 600

-- Starfield system
local stars = {}
local numStars = 100

-- Meteor system
local meteors = {}
local lastMeteorTime = 0
local meteorSpawnInterval = 5.0  -- seconds between meteors

-- Mouse tracking for hover effects
local mouseX, mouseY = 0, 0

-- Theme colors
local themeColors = {
    primary = {0.2, 0.4, 0.8, 1},      -- Blue
    secondary = {0.8, 0.2, 0.4, 1},    -- Red
    accent = {0.4, 0.8, 0.2, 1},       -- Green
    dark = {0.1, 0.1, 0.2, 1},         -- Dark blue
    light = {0.9, 0.9, 0.95, 1},       -- Light
    glow = {0.6, 0.8, 1, 0.8}          -- Glow effect
}

function menu.load(args) 
    -- Load menu music
    musicHandler.loadMenuMusic()
    
    -- Load background
    if not menuBackground then
        menuBackground = love.graphics.newImage("images/menu-background.jpg")
    end
    
    -- Initialize starfield
    initStarfield()
    
    -- Initialize meteors
    lastMeteorTime = love.timer.getTime()
    
    -- Load title gif animation (synced with BPM)
    if not titleGifSprite then
        titleGifSprite = love.graphics.newImage("images/title.png")
        titleGifSprite:setFilter("nearest", "nearest")
        local g = anim8.newGrid(71, 32, titleGifSprite:getWidth(), titleGifSprite:getHeight())
        titleGifAnim = anim8.newAnimation(g('1-5','1-4'), (60/musicHandler.bpm) / 8)
    end
    
    -- Create buttons (centered on BASE_WIDTH)
    local centerX = (BASE_WIDTH - 200) / 2  -- Center for 200px wide buttons
    
    -- Main menu buttons
    buttons.play = {x = centerX, y = 230, width = 200, height = 50, text = "Play", submenu = "main"}
    buttons.customize = {x = centerX, y = 300, width = 200, height = 50, text = "Customize", submenu = "main"}
    buttons.settings = {x = centerX, y = 370, width = 200, height = 50, text = "Settings", submenu = "main"}
    buttons.quit = {x = centerX, y = 440, width = 200, height = 50, text = "Quit", submenu = "main"}
    
    -- Play submenu buttons
    buttons.host = {x = centerX, y = 230, width = 200, height = 50, text = "Host Game", submenu = "play"}
    buttons.join = {x = centerX, y = 300, width = 200, height = 50, text = "Join Game", submenu = "play"}
    buttons.back_play = {x = centerX, y = 370, width = 200, height = 50, text = "Back", submenu = "play"}
    
    -- Settings submenu buttons
    buttons.back_settings = {x = centerX, y = 400, width = 200, height = 50, text = "Back", submenu = "settings"}
    
    -- Customize submenu buttons
    buttons.back_customize = {x = centerX, y = 400, width = 200, height = 50, text = "Back", submenu = "customize"}
    
    -- Setup music effects (matching original)
    musicHandler.removeEffect("menu_bg")
    musicHandler.removeEffect("title")
    musicHandler.removeEffect("play_button")
    musicHandler.removeEffect("customize_button")
    musicHandler.removeEffect("settings_button")
    musicHandler.removeEffect("quit_button")
    musicHandler.removeEffect("host_button")
    musicHandler.removeEffect("join_button")
    musicHandler.removeEffect("back_play_button")
    musicHandler.removeEffect("back_settings_button")
    musicHandler.removeEffect("back_customize_button")
    
    musicHandler.addEffect("menu_bg", "wave", {amplitude = 5, frequency = 0.5})
    musicHandler.addEffect("title", "beatPulse", {scaleAmount = 0.1, duration = 0.2})
    
    -- Button effects with combo (scale + rotate)
    musicHandler.addEffect("play_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        duration = 0.2
    })
    musicHandler.addEffect("customize_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        duration = 0.2
    })
    musicHandler.addEffect("settings_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        duration = 0.2
    })
    musicHandler.addEffect("quit_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        duration = 0.2
    })
    musicHandler.addEffect("host_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        duration = 0.2
    })
    musicHandler.addEffect("join_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        duration = 0.2
    })
    musicHandler.addEffect("back_play_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        duration = 0.2
    })
    musicHandler.addEffect("back_settings_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        duration = 0.2
    })
    musicHandler.addEffect("back_customize_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        duration = 0.2
    })
    
    currentSubmenu = "main"
end

-- Initialize starfield
function initStarfield()
    stars = {}
    for i = 1, numStars do
        stars[i] = {
            x = math.random(0, BASE_WIDTH),
            y = math.random(0, BASE_HEIGHT),
            speed = math.random(10, 50),
            size = math.random(1, 3),
            brightness = math.random(0.3, 1.0),
            twinkle = math.random(0, math.pi * 2)
        }
    end
end

-- Create a new meteor
function createMeteor()
    local meteor = {
        x = -50,  -- Start off screen left
        y = math.random(50, BASE_HEIGHT - 100),
        speed = math.random(80, 150),
        size = math.random(3, 8),
        trail = {},
        life = 1.0
    }
    
    -- Create trail points
    for i = 1, 8 do
        meteor.trail[i] = {x = meteor.x, y = meteor.y}
    end
    
    table.insert(meteors, meteor)
end

function menu.update(dt) 
    -- Update title animation
    if titleGifAnim then
        titleGifAnim:update(dt)
    end
    
    -- Update music handler
    musicHandler.update(dt)
    
    -- Update starfield
    for i, star in ipairs(stars) do
        star.x = star.x - star.speed * dt
        star.twinkle = star.twinkle + dt * 2
        
        -- Reset star when it goes off screen
        if star.x < -10 then
            star.x = BASE_WIDTH + 10
            star.y = math.random(0, BASE_HEIGHT)
        end
    end
    
    -- Update meteors
    local currentTime = love.timer.getTime()
    if currentTime - lastMeteorTime > meteorSpawnInterval then
        createMeteor()
        lastMeteorTime = currentTime
        meteorSpawnInterval = math.random(3, 8)  -- Random interval
    end
    
    -- Update existing meteors
    for i = #meteors, 1, -1 do
        local meteor = meteors[i]
        meteor.x = meteor.x + meteor.speed * dt
        meteor.life = meteor.life - dt * 0.3
        
        -- Update trail
        for j = #meteor.trail, 2, -1 do
            meteor.trail[j] = meteor.trail[j-1]
        end
        meteor.trail[1] = {x = meteor.x, y = meteor.y}
        
        -- Remove meteor when it goes off screen or fades out
        if meteor.x > BASE_WIDTH + 50 or meteor.life <= 0 then
            table.remove(meteors, i)
        end
    end
end

local function drawButton(button, effectId)
    if not button or button.visible == false then return end
    
    local x, y, r = button.x, button.y, 0
    local sx, sy = 1, 1
    
    if effectId then
        x, y, r, sx, sy = musicHandler.applyToDrawable(effectId, x, y)
    end
    
    -- Check if mouse is hovering over button
    local isHovered = isMouseOver(button, mouseX, mouseY)
    
    love.graphics.push()
    love.graphics.translate(x + button.width/2, y + button.height/2)
    if r then love.graphics.rotate(r) end
    love.graphics.scale(sx, sy)
    love.graphics.translate(-button.width/2, -button.height/2)
    
    local radius = 25  -- Rounded corners
    
    -- Subtle glow effect when hovered
    if isHovered then
        love.graphics.setColor(themeColors.accent[1], themeColors.accent[2], themeColors.accent[3], 0.4)
        love.graphics.rectangle("fill", -3, -3, button.width + 6, button.height + 6, radius + 3)
    end
    
    -- Main button background with smooth gradient effect
    if isHovered then
        -- Hovered: brighter blue with slight red tint
        love.graphics.setColor(0.4, 0.6, 1, 0.95)
    else
        -- Normal: deep space blue
        love.graphics.setColor(0.15, 0.25, 0.6, 0.9)
    end
    love.graphics.rectangle("fill", 0, 0, button.width, button.height, radius)
    
    -- Subtle inner highlight
    if isHovered then
        love.graphics.setColor(0.8, 0.9, 1, 0.6)
    else
        love.graphics.setColor(0.6, 0.7, 0.9, 0.4)
    end
    love.graphics.rectangle("fill", 2, 2, button.width - 4, button.height/2, radius - 2, radius - 2, 0, 0)
    
    -- Clean border without pixelation
    if isHovered then
        love.graphics.setColor(0.9, 0.9, 1, 0.8)
        love.graphics.setLineWidth(2)
    else
        love.graphics.setColor(0.5, 0.7, 1, 0.6)
        love.graphics.setLineWidth(1.5)
    end
    love.graphics.rectangle("line", 1, 1, button.width - 2, button.height - 2, radius - 1)
    
    -- Button text with clean styling
    if isHovered then
        -- Hovered text: bright white with subtle shadow
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.printf(button.text, 2, 17, button.width, "center")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(button.text, 0, 15, button.width, "center")
    else
        -- Normal text: clean white with minimal shadow
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.printf(button.text, 1, 16, button.width, "center")
        love.graphics.setColor(0.95, 0.95, 1, 0.9)
        love.graphics.printf(button.text, 0, 15, button.width, "center")
    end
    
    love.graphics.pop()
end

function menu.draw()
    -- Draw background with music effect
    local bgx, bgy = musicHandler.applyToDrawable("menu_bg", 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    if menuBackground then
        love.graphics.draw(menuBackground, bgx, bgy)
    end
    
    -- Draw starfield
    for _, star in ipairs(stars) do
        local twinkle = 0.5 + 0.5 * math.sin(star.twinkle)
        local alpha = star.brightness * twinkle
        love.graphics.setColor(themeColors.light[1], themeColors.light[2], themeColors.light[3], alpha)
        love.graphics.circle("fill", star.x, star.y, star.size)
        
        -- Add a subtle glow for larger stars
        if star.size > 2 then
            love.graphics.setColor(themeColors.accent[1], themeColors.accent[2], themeColors.accent[3], alpha * 0.3)
            love.graphics.circle("fill", star.x, star.y, star.size * 2)
        end
    end
    
    -- Draw meteors
    for _, meteor in ipairs(meteors) do
        -- Draw meteor trail
        for i = 1, #meteor.trail - 1 do
            local alpha = (meteor.life * i) / #meteor.trail
            love.graphics.setColor(themeColors.secondary[1], themeColors.secondary[2], themeColors.secondary[3], alpha)
            local size = meteor.size * alpha
            love.graphics.circle("fill", meteor.trail[i].x, meteor.trail[i].y, size)
        end
        
        -- Draw meteor head
        love.graphics.setColor(themeColors.accent[1], themeColors.accent[2], themeColors.accent[3], meteor.life)
        love.graphics.circle("fill", meteor.x, meteor.y, meteor.size)
        
        -- Meteor glow
        love.graphics.setColor(themeColors.light[1], themeColors.light[2], themeColors.light[3], meteor.life * 0.5)
        love.graphics.circle("fill", meteor.x, meteor.y, meteor.size * 1.5)
    end
    
    -- Draw title with music effect and enhanced visibility
    if titleGifSprite and titleGifAnim then
        local titleScale = 3
        local ex, ey, er, esx, esy = musicHandler.applyToDrawable("title", BASE_WIDTH/2, 100)
        
        -- Draw title with enhanced brightness and contrast
        love.graphics.setColor(1, 1, 1, 1)  -- Full opacity
        titleGifAnim:draw(titleGifSprite, ex, ey, er or 0, 
            titleScale * (esx or 1), titleScale * (esy or 1), 71/2, 32/2)
        
        -- Add a subtle glow behind the title
        love.graphics.setColor(themeColors.accent[1], themeColors.accent[2], themeColors.accent[3], 0.3)
        titleGifAnim:draw(titleGifSprite, ex + 2, ey + 2, er or 0, 
            titleScale * (esx or 1), titleScale * (esy or 1), 71/2, 32/2)
    end
    
    -- Draw buttons based on current submenu
    if currentSubmenu == "main" then
        drawButton(buttons.play, "play_button")
        drawButton(buttons.customize, "customize_button")
        drawButton(buttons.settings, "settings_button")
        drawButton(buttons.quit, "quit_button")
        
    elseif currentSubmenu == "play" then
        drawButton(buttons.host, "host_button")
        drawButton(buttons.join, "join_button")
        drawButton(buttons.back_play, "back_play_button")
        
    elseif currentSubmenu == "settings" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Settings", 0, 200, BASE_WIDTH, "center")
        love.graphics.printf("Settings options coming soon!", 0, 250, BASE_WIDTH, "center")
        drawButton(buttons.back_settings, "back_settings_button")
        
    elseif currentSubmenu == "customize" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Customize", 0, 200, BASE_WIDTH, "center")
        love.graphics.printf("Character customization coming soon!", 0, 250, BASE_WIDTH, "center")
        drawButton(buttons.back_customize, "back_customize_button")
    end
end

local function isMouseOver(button, x, y)
    if not button then return false end
    return x >= button.x and x <= button.x + button.width and
           y >= button.y and y <= button.y + button.height
end

function menu.mousemoved(x, y)
    mouseX, mouseY = x, y
end

function menu.mousepressed(x, y, button)
    if button ~= 1 then return end  -- Only left click
    
    -- Transform mouse coordinates if needed (handled by app layer)
    if currentSubmenu == "main" then
        if isMouseOver(buttons.play, x, y) then
            currentSubmenu = "play"
        elseif isMouseOver(buttons.customize, x, y) then
            events.emit("intent:customize")
        elseif isMouseOver(buttons.settings, x, y) then
            currentSubmenu = "settings"
        elseif isMouseOver(buttons.quit, x, y) then
            love.event.quit()
        end
        
    elseif currentSubmenu == "play" then
        if isMouseOver(buttons.host, x, y) then
            events.emit("intent:host", {port=12345})
        elseif isMouseOver(buttons.join, x, y) then
            events.emit("intent:show_connecting")
        elseif isMouseOver(buttons.back_play, x, y) then
            currentSubmenu = "main"
        end
        
    elseif currentSubmenu == "settings" then
        if isMouseOver(buttons.back_settings, x, y) then
            currentSubmenu = "main"
        end
        
    elseif currentSubmenu == "customize" then
        if isMouseOver(buttons.back_customize, x, y) then
            currentSubmenu = "main"
        end
    end
end

function menu.keypressed(k)
    -- Quick navigation
    if k == "escape" then
        if currentSubmenu ~= "main" then
            currentSubmenu = "main"
        else
            love.event.quit()
        end
    end
    
    -- Quick shortcuts (for testing)
    if currentSubmenu == "play" then
        if k == "h" then 
            events.emit("intent:host", {port=12345})
        elseif k == "j" then 
            events.emit("intent:join", {host="127.0.0.1", port=12345})
        end
    end
end

return menu
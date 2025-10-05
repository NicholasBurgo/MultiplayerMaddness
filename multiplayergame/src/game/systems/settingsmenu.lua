-- ============================================================================
-- SETTINGS MENU SYSTEM
-- ============================================================================
-- Settings menu that can be accessed from the pause menu
-- ============================================================================

local settings = require("src.game.systems.settings")

local settingsMenu = {}

-- Settings menu state
settingsMenu.visible = false
settingsMenu.selectedOption = 1
settingsMenu.animationTime = 0

-- Settings options
settingsMenu.options = {
    {key = "masterVolume", name = "Master Volume", type = "slider", min = 0, max = 1, step = 0.1},
    {key = "musicVolume", name = "Music Volume", type = "slider", min = 0, max = 1, step = 0.1},
    {key = "sfxVolume", name = "SFX Volume", type = "slider", min = 0, max = 1, step = 0.1},
    {key = "fullscreen", name = "Fullscreen", type = "toggle"},
    {key = "vsync", name = "VSync", type = "toggle"},
    {key = "graphics", name = "Graphics", type = "choice", choices = {"low", "medium", "high"}}
}

-- Font system
local fonts = {
    small = nil,
    medium = nil,
    large = nil,
    xlarge = nil,
    huge = nil
}

-- Initialize fonts
local function initFonts()
    fonts.small = love.graphics.newFont(12)
    fonts.medium = love.graphics.newFont(16)
    fonts.large = love.graphics.newFont(20)
    fonts.xlarge = love.graphics.newFont(24)
    fonts.huge = love.graphics.newFont(32)
end

-- Show settings menu
function settingsMenu.show()
    settingsMenu.visible = true
    settingsMenu.animationTime = 0
    settingsMenu.selectedOption = 1
end

-- Hide settings menu
function settingsMenu.hide()
    settingsMenu.visible = false
end

-- Check if settings menu is visible
function settingsMenu.isVisible()
    return settingsMenu.visible
end

-- Update settings menu
function settingsMenu.update(dt)
    if not settingsMenu.visible then return end
    settingsMenu.animationTime = settingsMenu.animationTime + dt
end

-- Check if mouse is over a button
local function isMouseOverButton(x, y, buttonX, buttonY, buttonWidth, buttonHeight)
    return x >= buttonX and x <= buttonX + buttonWidth and
           y >= buttonY and y <= buttonY + buttonHeight
end

-- Handle mouse input
function settingsMenu.mousepressed(x, y, button)
    if not settingsMenu.visible or button ~= 1 then return false end
    
    local BASE_WIDTH = 800
    local startY = 180
    local optionSpacing = 50
    
    for i, option in ipairs(settingsMenu.options) do
        local buttonY = startY + (i - 1) * optionSpacing
        if isMouseOverButton(x, y, 150, buttonY - 5, BASE_WIDTH - 300, 40) then
            settingsMenu.selectedOption = i
            
            -- Handle different option types
            if option.type == "slider" then
                -- Calculate slider position
                local sliderX = 400
                local sliderWidth = 200
                local sliderY = buttonY + 16
                local sliderHeight = 8
                
                if x >= sliderX and x <= sliderX + sliderWidth and 
                   y >= sliderY - 10 and y <= sliderY + sliderHeight + 10 then
                    local percentage = (x - sliderX) / sliderWidth
                    local newValue = option.min + (option.max - option.min) * percentage
                    newValue = math.max(option.min, math.min(option.max, newValue))
                    -- Round to step
                    newValue = math.floor(newValue / option.step + 0.5) * option.step
                    settings.set(option.key, newValue)
                end
            elseif option.type == "toggle" then
                local current = settings.get(option.key)
                settings.set(option.key, not current)
            elseif option.type == "choice" then
                local current = settings.get(option.key)
                local currentIndex = 1
                for j, choice in ipairs(option.choices) do
                    if choice == current then
                        currentIndex = j
                        break
                    end
                end
                currentIndex = currentIndex + 1
                if currentIndex > #option.choices then
                    currentIndex = 1
                end
                settings.set(option.key, option.choices[currentIndex])
            end
            return true
        end
    end
    
    return true -- Handled
end

-- Handle mouse movement for hover effects
function settingsMenu.mousemoved(x, y, dx, dy)
    if not settingsMenu.visible then return false end
    
    local BASE_WIDTH = 800
    local startY = 180
    local optionSpacing = 50
    
    for i, option in ipairs(settingsMenu.options) do
        local buttonY = startY + (i - 1) * optionSpacing
        if isMouseOverButton(x, y, 150, buttonY - 5, BASE_WIDTH - 300, 40) then
            settingsMenu.selectedOption = i
            return true
        end
    end
    
    return true -- Handled
end

-- Handle key input
function settingsMenu.keypressed(key)
    if not settingsMenu.visible then return false end
    
    local option = settingsMenu.options[settingsMenu.selectedOption]
    if not option then return true end
    
    if key == "w" or key == "up" then
        settingsMenu.selectedOption = settingsMenu.selectedOption - 1
        if settingsMenu.selectedOption < 1 then
            settingsMenu.selectedOption = #settingsMenu.options
        end
    elseif key == "s" or key == "down" then
        settingsMenu.selectedOption = settingsMenu.selectedOption + 1
        if settingsMenu.selectedOption > #settingsMenu.options then
            settingsMenu.selectedOption = 1
        end
    elseif key == "a" or key == "left" then
        -- Decrease value
        if option.type == "slider" then
            local current = settings.get(option.key)
            local newValue = math.max(option.min, current - option.step)
            settings.set(option.key, newValue)
        elseif option.type == "toggle" then
            local current = settings.get(option.key)
            settings.set(option.key, not current)
        elseif option.type == "choice" then
            local current = settings.get(option.key)
            local currentIndex = 1
            for i, choice in ipairs(option.choices) do
                if choice == current then
                    currentIndex = i
                    break
                end
            end
            currentIndex = currentIndex - 1
            if currentIndex < 1 then
                currentIndex = #option.choices
            end
            settings.set(option.key, option.choices[currentIndex])
        end
    elseif key == "d" or key == "right" then
        -- Increase value
        if option.type == "slider" then
            local current = settings.get(option.key)
            local newValue = math.min(option.max, current + option.step)
            settings.set(option.key, newValue)
        elseif option.type == "toggle" then
            local current = settings.get(option.key)
            settings.set(option.key, not current)
        elseif option.type == "choice" then
            local current = settings.get(option.key)
            local currentIndex = 1
            for i, choice in ipairs(option.choices) do
                if choice == current then
                    currentIndex = i
                    break
                end
            end
            currentIndex = currentIndex + 1
            if currentIndex > #option.choices then
                currentIndex = 1
            end
            settings.set(option.key, option.choices[currentIndex])
        end
    elseif key == "escape" then
        settingsMenu.hide()
    end
    
    return true -- Handled
end

-- Draw settings menu
function settingsMenu.draw()
    if not settingsMenu.visible then return end
    
    -- Initialize fonts if needed
    if not fonts.huge then
        initFonts()
    end
    
    local BASE_WIDTH = 800
    local BASE_HEIGHT = 600
    
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, BASE_WIDTH, BASE_HEIGHT)
    
    -- Animated border
    local pulse = math.sin(settingsMenu.animationTime * 3) * 0.2 + 0.8
    local pulse2 = math.sin(settingsMenu.animationTime * 4 + 1) * 0.15 + 0.7
    
    -- Outer glow
    love.graphics.setColor(0.8, 0, 1, pulse2 * 0.3)
    love.graphics.setLineWidth(8)
    love.graphics.rectangle("line", 50, 50, BASE_WIDTH - 100, BASE_HEIGHT - 100)
    
    -- Main border
    love.graphics.setColor(0.2, 1, 0.6, pulse)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 60, 60, BASE_WIDTH - 120, BASE_HEIGHT - 120)
    
    -- Menu background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", 80, 80, BASE_WIDTH - 160, BASE_HEIGHT - 160)
    
    -- Title
    love.graphics.setFont(fonts.huge)
    local titlePulse = math.sin(settingsMenu.animationTime * 2) * 0.3 + 0.7
    love.graphics.setColor(0.2, 1, 0.4, titlePulse)
    love.graphics.printf("SETTINGS", 0, 100, BASE_WIDTH, "center")
    
    -- Settings options
    local startY = 180
    local optionSpacing = 50
    
    for i, option in ipairs(settingsMenu.options) do
        local y = startY + (i - 1) * optionSpacing
        local isSelected = i == settingsMenu.selectedOption
        
        -- Option background
        if isSelected then
            local bgPulse = math.sin(settingsMenu.animationTime * 4 + i) * 0.15 + 0.85
            love.graphics.setColor(0.2, 0.4, 0.6, 0.6 * bgPulse)
            love.graphics.rectangle("fill", 150, y - 5, BASE_WIDTH - 300, 40)
            
            -- Selection indicator
            love.graphics.setColor(1, 1, 0.2, bgPulse)
            love.graphics.rectangle("fill", 130, y - 5, 15, 40)
        end
        
        -- Option name
        love.graphics.setFont(fonts.large)
        if isSelected then
            love.graphics.setColor(1, 1, 0.2, pulse)
        else
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
        end
        love.graphics.printf(option.name, 160, y, 200, "left")
        
        -- Option value
        love.graphics.setFont(fonts.medium)
        local currentValue = settings.get(option.key)
        local valueText = ""
        
        if option.type == "slider" then
            local percentage = math.floor((currentValue - option.min) / (option.max - option.min) * 100)
            valueText = percentage .. "%"
            
            -- Draw slider bar
            local barWidth = 200
            local barHeight = 8
            local barX = 400
            local barY = y + 16
            
            -- Background bar
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 4, 4)
            
            -- Value bar
            local valueWidth = (currentValue - option.min) / (option.max - option.min) * barWidth
            love.graphics.setColor(0.2, 1, 0.6, 1)
            love.graphics.rectangle("fill", barX, barY, valueWidth, barHeight, 4, 4)
            
            -- Slider handle
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.circle("fill", barX + valueWidth, barY + barHeight/2, 8)
            
        elseif option.type == "toggle" then
            valueText = currentValue and "ON" or "OFF"
            love.graphics.setColor(currentValue and {0.2, 1, 0.2} or {1, 0.2, 0.2}, 1)
            
        elseif option.type == "choice" then
            valueText = string.upper(currentValue)
        end
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.printf(valueText, 650, y, 100, "right")
    end
    
    -- Instructions
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.printf("W/S or mouse to navigate, A/D or click to change values, ESC to back", 0, BASE_HEIGHT - 80, BASE_WIDTH, "center")
end

return settingsMenu

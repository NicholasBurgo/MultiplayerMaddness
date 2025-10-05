-- charactercustom.lua
local debugConsole = require "src.core.debugconsole"
local musicHandler = require "src.game.systems.musichandler"

local characterCustomization = {}

-- Helper function for mouse detection
function isMouseOver(item, mx, my)
    -- If coordinates not provided, get them from mouse (already converted by app layer)
    if not mx or not my then
        local scaling = require("src.core.scaling")
        local screenX, screenY = love.mouse.getPosition()
        mx, my = scaling.screenToGame(screenX, screenY)
    end
    return mx > item.x and mx < item.x + item.width and my > item.y and my < item.y + item.height
end

-- Predefined color schemes with names
characterCustomization.colors = {
    {color = {1, 0, 0}, name = "Red"},
    {color = {0, 1, 0}, name = "Green"},
    {color = {0, 0, 1}, name = "Blue"},
    {color = {1, 1, 0}, name = "Yellow"},
    {color = {1, 0, 1}, name = "Magenta"},
    {color = {0, 1, 1}, name = "Cyan"},
    {color = {1, 0.5, 0}, name = "Orange"},
    {color = {0.5, 0, 1}, name = "Purple"},
    {color = {1, 0.75, 0.8}, name = "Pink"},
    {color = {0.5, 1, 0.5}, name = "Lime"}
}

-- State management
characterCustomization.currentColorIndex = 1

-- Name input
characterCustomization.playerName = "Player"
characterCustomization.nameInputActive = false
characterCustomization.cursorBlink = 0

-- Menu theming variables
characterCustomization.menuBackground = nil

-- Initialize with current player data
function characterCustomization.initialize(playerData)
    print("[CharacterCustom] Initializing with player data")
    if playerData then
        print("[CharacterCustom] Player data exists, name: " .. (playerData.name or "nil"))
        characterCustomization.playerName = playerData.name or "Player"
        characterCustomization.currentColorIndex = 1
        -- Find matching color index
        for i, colorData in ipairs(characterCustomization.colors) do
            local color = colorData.color
            if color[1] == playerData.color[1] and color[2] == playerData.color[2] and color[3] == playerData.color[3] then
                characterCustomization.currentColorIndex = i
                break
            end
        end
    else
        print("[CharacterCustom] No player data provided")
    end
end

-- UI elements (calculated dynamically based on screen size)
characterCustomization.nameInput = {
    x = 0, y = 0, width = 300, height = 40
}

characterCustomization.buttons = {
    prev = {x = 0, y = 0, width = 60, height = 60, text = "<"},
    next = {x = 0, y = 0, width = 60, height = 60, text = ">"},
    confirm = {x = 0, y = 0, width = 200, height = 60, text = "Done"},
    cancel = {x = 0, y = 0, width = 200, height = 60, text = "Cancel"}
}

-- Initialize theming
function characterCustomization.init()
    print("[CharacterCustom] Init called")
    characterCustomization.menuBackground = love.graphics.newImage("images/menu-background.jpg")
    
    -- Calculate button positions based on BASE resolution (800x600)
    local BASE_WIDTH = 800
    local BASE_HEIGHT = 600
    local centerX = BASE_WIDTH / 2
    
    -- Name input at top
    characterCustomization.nameInput.x = centerX - characterCustomization.nameInput.width / 2
    characterCustomization.nameInput.y = 120
    
    -- Color buttons
    characterCustomization.buttons.prev.x = centerX - 200
    characterCustomization.buttons.prev.y = 300
    characterCustomization.buttons.next.x = centerX + 140
    characterCustomization.buttons.next.y = 300
    
    -- Bottom buttons
    characterCustomization.buttons.cancel.x = centerX - 220
    characterCustomization.buttons.cancel.y = BASE_HEIGHT - 100
    characterCustomization.buttons.confirm.x = centerX + 20
    characterCustomization.buttons.confirm.y = BASE_HEIGHT - 100
end

function characterCustomization.getCurrentColor()
    return characterCustomization.colors[characterCustomization.currentColorIndex].color
end

function characterCustomization.getPlayerName()
    return characterCustomization.playerName
end

function characterCustomization.nextColor()
    characterCustomization.currentColorIndex = characterCustomization.currentColorIndex % #characterCustomization.colors + 1
end

function characterCustomization.prevColor()
    characterCustomization.currentColorIndex = characterCustomization.currentColorIndex - 1
    if characterCustomization.currentColorIndex < 1 then
        characterCustomization.currentColorIndex = #characterCustomization.colors
    end
end

function characterCustomization.update(dt)
    characterCustomization.cursorBlink = characterCustomization.cursorBlink + dt
end

function characterCustomization.mousepressed(x, y, button)
    if button == 1 then  -- Left mouse button
        print(string.format("[CharacterCustom] Mouse pressed at: %d, %d", x, y))
        
        -- Handle name input field
        if isMouseOver(characterCustomization.nameInput, x, y) then
            print("[CharacterCustom] Name input clicked")
            characterCustomization.nameInputActive = true
            return true
        else
            characterCustomization.nameInputActive = false
        end
        
        -- Handle color selection buttons
        if isMouseOver(characterCustomization.buttons.prev, x, y) then
            print("[CharacterCustom] Previous color clicked")
            characterCustomization.prevColor()
            return true
        elseif isMouseOver(characterCustomization.buttons.next, x, y) then
            print("[CharacterCustom] Next color clicked")
            characterCustomization.nextColor()
            return true
        end
        
        -- Handle confirm button
        if isMouseOver(characterCustomization.buttons.confirm, x, y) then
            print("[CharacterCustom] Confirm button clicked")
            characterCustomization.nameInputActive = false
            return "confirm"
        end
        
        -- Handle cancel button
        if isMouseOver(characterCustomization.buttons.cancel, x, y) then
            print("[CharacterCustom] Cancel button clicked")
            characterCustomization.nameInputActive = false
            return "cancel"
        end
    end
    return false
end

function characterCustomization.textinput(t)
    if characterCustomization.nameInputActive then
        if characterCustomization.playerName:len() < 20 then
            characterCustomization.playerName = characterCustomization.playerName .. t
        end
        return true
    end
    return false
end

function characterCustomization.keyreleased(key)
    if characterCustomization.nameInputActive then
        if key == "backspace" then
            if characterCustomization.playerName:len() > 0 then
                characterCustomization.playerName = characterCustomization.playerName:sub(1, -2)
            end
        elseif key == "return" or key == "escape" then
            characterCustomization.nameInputActive = false
        end
        return true
    end
    return false
end

-- Draw a player character
local function drawPlayer(x, y, color, size)
    size = size or 1
    local bodySize = 50 * size
    local headSize = 30 * size
    
    -- Body
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x - bodySize/2, y - bodySize/2, bodySize, bodySize)
    
    -- Head (slightly lighter)
    love.graphics.setColor(color[1] * 0.8, color[2] * 0.8, color[3] * 0.8)
    love.graphics.circle("fill", x, y - bodySize/2 - headSize/2 - 5 * size, headSize/2)
end

function characterCustomization.draw()
    -- Use BASE resolution for consistent layout
    local BASE_WIDTH = 800
    local BASE_HEIGHT = 600
    local centerX = BASE_WIDTH / 2
    local centerY = BASE_HEIGHT / 2
    
    -- Draw background
    local bgx, bgy = musicHandler.applyToDrawable("menu_bg", 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(characterCustomization.menuBackground, bgx, bgy)
    
    -- Draw semi-transparent overlay for readability
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", 0, 0, BASE_WIDTH, BASE_HEIGHT)
    
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.printf("Character Customization", 0, 40, BASE_WIDTH, "center")
    love.graphics.setFont(love.graphics.newFont(14))
    
    -- Name Section
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.printf("Your Name:", 0, 90, BASE_WIDTH, "center")
    love.graphics.setFont(love.graphics.newFont(14))
    
    -- Name input field with glow effect
    if characterCustomization.nameInputActive then
        love.graphics.setColor(0.3, 0.7, 1, 0.5)
        love.graphics.rectangle("fill", 
            characterCustomization.nameInput.x - 3, 
            characterCustomization.nameInput.y - 3, 
            characterCustomization.nameInput.width + 6, 
            characterCustomization.nameInput.height + 6, 
            5, 5)
    end
    
    love.graphics.setColor(0.2, 0.2, 0.3)
    love.graphics.rectangle("fill", 
        characterCustomization.nameInput.x, 
        characterCustomization.nameInput.y, 
        characterCustomization.nameInput.width, 
        characterCustomization.nameInput.height, 
        5, 5)
    
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 
        characterCustomization.nameInput.x, 
        characterCustomization.nameInput.y, 
        characterCustomization.nameInput.width, 
        characterCustomization.nameInput.height, 
        5, 5)
    
    -- Name text
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.setColor(1, 1, 1)
    local displayName = characterCustomization.playerName
    if displayName == "" then
        love.graphics.setColor(0.5, 0.5, 0.5)
        displayName = "Click to type..."
    end
    love.graphics.printf(displayName, 
        characterCustomization.nameInput.x + 10, 
        characterCustomization.nameInput.y + 10, 
        characterCustomization.nameInput.width - 20, 
        "center")
    
    -- Blinking cursor
    if characterCustomization.nameInputActive and characterCustomization.playerName ~= "" then
        if math.floor(characterCustomization.cursorBlink * 2) % 2 == 0 then
            local textWidth = love.graphics.getFont():getWidth(characterCustomization.playerName)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("fill",
                characterCustomization.nameInput.x + characterCustomization.nameInput.width / 2 + textWidth / 2 + 2,
                characterCustomization.nameInput.y + 8,
                2,
                characterCustomization.nameInput.height - 16
            )
        end
    end
    love.graphics.setFont(love.graphics.newFont(14))
    
    -- Character Preview Section
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.printf("Character Preview:", 0, 190, BASE_WIDTH, "center")
    love.graphics.setFont(love.graphics.newFont(14))
    
    -- Preview background panel
    love.graphics.setColor(0.15, 0.15, 0.2, 0.8)
    love.graphics.rectangle("fill", centerX - 150, 230, 300, 180, 10, 10)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", centerX - 150, 230, 300, 180, 10, 10)
    
    -- Draw player character in the center
    local color = characterCustomization.getCurrentColor()
    drawPlayer(centerX, 320, color, 1.5)
    
    -- Color Selection Section
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.printf("Color:", 0, 430, BASE_WIDTH, "center")
    
    -- Current color name
    local colorName = characterCustomization.colors[characterCustomization.currentColorIndex].name
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.setColor(color)
    love.graphics.printf(colorName, 0, 460, BASE_WIDTH, "center")
    love.graphics.setFont(love.graphics.newFont(14))
    
    -- Previous button
    local scaling = require("src.core.scaling")
    local screenX, screenY = love.mouse.getPosition()
    local mx, my = scaling.screenToGame(screenX, screenY)
    local prevHover = isMouseOver(characterCustomization.buttons.prev, mx, my)
    love.graphics.setColor(prevHover and 0.5 or 0.3, prevHover and 0.5 or 0.3, prevHover and 0.6 or 0.4)
    love.graphics.rectangle("fill", 
        characterCustomization.buttons.prev.x, 
        characterCustomization.buttons.prev.y, 
        characterCustomization.buttons.prev.width, 
        characterCustomization.buttons.prev.height, 
        5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.printf(characterCustomization.buttons.prev.text, 
        characterCustomization.buttons.prev.x, 
        characterCustomization.buttons.prev.y + 10, 
        characterCustomization.buttons.prev.width, 
        "center")
    love.graphics.setFont(love.graphics.newFont(14))
    
    -- Next button
    local nextHover = isMouseOver(characterCustomization.buttons.next, mx, my)
    love.graphics.setColor(nextHover and 0.5 or 0.3, nextHover and 0.5 or 0.3, nextHover and 0.6 or 0.4)
    love.graphics.rectangle("fill", 
        characterCustomization.buttons.next.x, 
        characterCustomization.buttons.next.y, 
        characterCustomization.buttons.next.width, 
        characterCustomization.buttons.next.height, 
        5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.printf(characterCustomization.buttons.next.text, 
        characterCustomization.buttons.next.x, 
        characterCustomization.buttons.next.y + 10, 
        characterCustomization.buttons.next.width, 
        "center")
    love.graphics.setFont(love.graphics.newFont(14))
    
    -- Cancel button
    local cancelHover = isMouseOver(characterCustomization.buttons.cancel, mx, my)
    love.graphics.setColor(cancelHover and 0.9 or 0.7, cancelHover and 0.3 or 0.2, cancelHover and 0.3 or 0.2, 0.9)
    love.graphics.rectangle("fill", 
        characterCustomization.buttons.cancel.x, 
        characterCustomization.buttons.cancel.y, 
        characterCustomization.buttons.cancel.width, 
        characterCustomization.buttons.cancel.height, 
        8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.printf(characterCustomization.buttons.cancel.text, 
        characterCustomization.buttons.cancel.x, 
        characterCustomization.buttons.cancel.y + 18, 
        characterCustomization.buttons.cancel.width, 
        "center")
    
    -- Done button
    local confirmHover = isMouseOver(characterCustomization.buttons.confirm, mx, my)
    love.graphics.setColor(cancelHover and 0.3 or 0.2, confirmHover and 0.9 or 0.7, cancelHover and 0.3 or 0.2, 0.9)
    love.graphics.rectangle("fill", 
        characterCustomization.buttons.confirm.x, 
        characterCustomization.buttons.confirm.y, 
        characterCustomization.buttons.confirm.width, 
        characterCustomization.buttons.confirm.height, 
        8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(characterCustomization.buttons.confirm.text, 
        characterCustomization.buttons.confirm.x, 
        characterCustomization.buttons.confirm.y + 18, 
        characterCustomization.buttons.confirm.width, 
        "center")
    love.graphics.setFont(love.graphics.newFont(14))
    
    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

function characterCustomization.getFacePoints()
    -- No longer using face points/drawing
    return nil
end

return characterCustomization
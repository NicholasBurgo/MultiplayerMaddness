-- charactercustom.lua
local debugConsole = require "scripts.debugconsole"
local musicHandler = require "scripts.musichandler"
local anim8 = require "scripts.anim8"

local characterCustomization = {}

-- Helper function for mouse detection
function isMouseOver(item)
    local mx, my = love.mouse.getPosition()
    local result = mx > item.x and mx < item.x + item.width and my > item.y and my < item.y + item.height
    if item.text == "Done" or item.text == "Confirm" then
        debugConsole.addMessage(string.format("isMouseOver check: mouse(%d,%d) vs item(%d,%d,%d,%d) = %s", 
            mx, my, item.x, item.y, item.width, item.height, tostring(result)))
    end
    return result
end

-- Predefined color schemes
characterCustomization.colors = {
    {1, 0, 0},    -- Red
    {0, 1, 0},    -- Green
    {0, 0, 1},    -- Blue
    {1, 1, 0},    -- Yellow
    {1, 0, 1},    -- Magenta
    {0, 1, 1},    -- Cyan 
    {1, 0.5, 0},  -- Orange
    {0.5, 0, 1},  -- Purple
    {1, 0.75, 0.8}, -- Pink
    {0.5, 1, 0.5}   -- Lime
}

-- State management
characterCustomization.currentColorIndex = 1
characterCustomization.isDrawing = false
characterCustomization.currentStroke = {}

-- Name input
characterCustomization.playerName = "Player"
characterCustomization.nameInputActive = false

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
        for i, color in ipairs(characterCustomization.colors) do
            if color[1] == playerData.color[1] and color[2] == playerData.color[2] and color[3] == playerData.color[3] then
                characterCustomization.currentColorIndex = i
                break
            end
        end
        if playerData.facePoints then
            print("[CharacterCustom] Loading saved face canvas, type: " .. type(playerData.facePoints))
            characterCustomization.faceCanvas = playerData.facePoints
            print("[CharacterCustom] Face canvas loaded successfully")
        else
            print("[CharacterCustom] No saved face canvas found")
        end
    else
        print("[CharacterCustom] No player data provided")
    end
end

-- Canvas for face drawing
characterCustomization.faceCanvas = nil
characterCustomization.canvasSize = 100
characterCustomization.canvasHeight = 100

-- UI elements
characterCustomization.previewRect = {
    x = (love.graphics.getWidth() - 100) / 2,  -- Center horizontally
    y = 250,          -- less is higher up                        
    width = 100,
    height = 100
}

characterCustomization.previewRectExtraBoundaries = {
    x = (love.graphics.getWidth() - 100) / 2,  -- Center horizontally
    y = 250,                                  
    width = 100,
    height = 150
}

-- Name input field
characterCustomization.nameInput = {
    x = (love.graphics.getWidth() - 200) / 2,
    y = 150,
    width = 200,
    height = 30
}


characterCustomization.buttons = {
    prev = {x = 250, y = 320, width = 50, height = 50, text = "<"},
    next = {x = 500, y = 320, width = 50, height = 50, text = ">"},
    confirm = {x = 325, y = 500, width = 150, height = 50, text = "Done"},
    clear = {x = 325, y = 460, width = 150, height = 50, text = "Clear Face"},
    cancel = {x = 150, y = 500, width = 150, height = 50, text = "Cancel"}
}

-- Initialize canvas and theming
function characterCustomization.init()
    print("[CharacterCustom] Init called, faceCanvas exists: " .. tostring(characterCustomization.faceCanvas ~= nil))
    -- Only create new canvas if one doesn't exist
    if not characterCustomization.faceCanvas then
        print("[CharacterCustom] Creating new face canvas")
        characterCustomization.faceCanvas = love.graphics.newCanvas(
            characterCustomization.canvasSize,
            characterCustomization.canvasHeight
        )
        -- Clear canvas with transparency only if it's new
        love.graphics.setCanvas(characterCustomization.faceCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setCanvas()
        print("[CharacterCustom] New canvas created and cleared")
    else
        print("[CharacterCustom] Using existing face canvas")
    end
    
    -- Initialize theming assets
    characterCustomization.menuBackground = love.graphics.newImage("images/menu-background.jpg")
end

function characterCustomization.getCurrentColor()
    return characterCustomization.colors[characterCustomization.currentColorIndex]
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

function characterCustomization.mousepressed(x, y, button)
    if button == 1 then  -- Left mouse button
        debugConsole.addMessage(string.format("Mouse clicked at: %d, %d", x, y))
        
        -- Handle name input field
        if isMouseOver(characterCustomization.nameInput) then
            debugConsole.addMessage("Name input field clicked")
            characterCustomization.nameInputActive = true
            return true
        end
        
        -- Handle color selection buttons
        if isMouseOver(characterCustomization.buttons.prev) then
            debugConsole.addMessage("Previous color button clicked")
            characterCustomization.prevColor()
            return true
        elseif isMouseOver(characterCustomization.buttons.next) then
            debugConsole.addMessage("Next color button clicked")
            characterCustomization.nextColor()
            return true
        end
        
        -- Handle face drawing area
        if isMouseOver(characterCustomization.previewRect) then
            debugConsole.addMessage("Started drawing on preview rect")
            print(string.format("[MousePress] Drawing started at (%d,%d), preview rect: (%d,%d,%d,%d)", 
                x, y, characterCustomization.previewRect.x, characterCustomization.previewRect.y, 
                characterCustomization.previewRect.width, characterCustomization.previewRect.height))
            characterCustomization.isDrawing = true
            characterCustomization.currentStroke = {
                x = x - characterCustomization.previewRect.x,
                y = y - characterCustomization.previewRect.y
            }
            print(string.format("[MousePress] Stroke start: (%d,%d)", characterCustomization.currentStroke.x, characterCustomization.currentStroke.y))
            return true
        end
        
        -- Handle clear canvas button
        if isMouseOver(characterCustomization.buttons.clear) then
            characterCustomization.clearFace()
            debugConsole.addMessage("Face cleared")
            return true
        end
        
        
        -- Handle confirm button
        if isMouseOver(characterCustomization.buttons.confirm) then
            debugConsole.addMessage("Character customization confirmed")
            characterCustomization.nameInputActive = false
            return "confirm"
        end
        
        -- Handle cancel button
        if isMouseOver(characterCustomization.buttons.cancel) then
            debugConsole.addMessage("Character customization cancelled")
            characterCustomization.nameInputActive = false
            return "cancel"
        end
    end
    return false
end

function characterCustomization.mousereleased(x, y, button)
    characterCustomization.isDrawing = false
    characterCustomization.currentStroke = {}
end

function characterCustomization.mousemoved(x, y)
    if characterCustomization.isDrawing and characterCustomization.faceCanvas then--and isMouseOver(characterCustomization.previewRectExtraBoundaries) then
        local newX = x - characterCustomization.previewRect.x
        local newY = y - characterCustomization.previewRect.y
        
        print(string.format("[Draw] Drawing line from (%d,%d) to (%d,%d)", 
            characterCustomization.currentStroke.x, characterCustomization.currentStroke.y, newX, newY))
        
        -- Draw line to canvas with safety check
        local success = pcall(function()
            love.graphics.setCanvas(characterCustomization.faceCanvas)
            love.graphics.setColor(0, 0, 0, 1)
            -- Set line width thicker for better visibility
            love.graphics.setLineWidth(2)
            love.graphics.line(
                characterCustomization.currentStroke.x,
                characterCustomization.currentStroke.y,
                newX,
                newY
            )
            love.graphics.setCanvas()
        end)
        
        if not success then
            print("[Draw] Canvas is invalid during drawing, stopping")
            characterCustomization.isDrawing = false
            characterCustomization.faceCanvas = nil
            return
        end
        
        -- Update current position
        characterCustomization.currentStroke.x = newX
        characterCustomization.currentStroke.y = newY
    end
end

function characterCustomization.keypressed(key)
    if characterCustomization.nameInputActive then
        if key == "backspace" then
            characterCustomization.playerName = characterCustomization.playerName:sub(1, -2)
        elseif key == "return" or key == "enter" then
            characterCustomization.nameInputActive = false
        elseif key:len() == 1 and characterCustomization.playerName:len() < 20 then
            characterCustomization.playerName = characterCustomization.playerName .. key
        end
        return true
    end
    return false
end

function characterCustomization.draw()
    -- Draw themed customization UI with background
    
    -- Draw background (same as main menu)
    local bgx, bgy = musicHandler.applyToDrawable("menu_bg", 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(characterCustomization.menuBackground, bgx, bgy)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Character Customization", 0, 100, love.graphics.getWidth(), "center")
    
    -- Name input section
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Name:", 0, 160, love.graphics.getWidth(), "center")
    
    -- Draw name input field
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.rectangle("fill", 
        characterCustomization.nameInput.x, 
        characterCustomization.nameInput.y, 
        characterCustomization.nameInput.width, 
        characterCustomization.nameInput.height)
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", 
        characterCustomization.nameInput.x, 
        characterCustomization.nameInput.y, 
        characterCustomization.nameInput.width, 
        characterCustomization.nameInput.height)
    
    -- Draw name text
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(characterCustomization.playerName, 
        characterCustomization.nameInput.x + 5, 
        characterCustomization.nameInput.y + 5, 
        characterCustomization.nameInput.width - 10, 
        "left")
    
    -- Draw cursor if active
    if characterCustomization.nameInputActive then
        local textWidth = love.graphics.getFont():getWidth(characterCustomization.playerName)
        love.graphics.setColor(0, 0, 0)
        love.graphics.line(
            characterCustomization.nameInput.x + 5 + textWidth,
            characterCustomization.nameInput.y + 5,
            characterCustomization.nameInput.x + 5 + textWidth,
            characterCustomization.nameInput.y + characterCustomization.nameInput.height - 5
        )
    end
    
    -- Color selection section
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Color:", 0, 220, love.graphics.getWidth(), "center")
    
    -- Draw color preview
    local color = characterCustomization.getCurrentColor()
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", 
        characterCustomization.previewRect.x,
        characterCustomization.previewRect.y,
        characterCustomization.previewRect.width,
        characterCustomization.previewRect.height
    )
    
    -- Draw color navigation buttons
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.rectangle("fill", 
        characterCustomization.buttons.prev.x, 
        characterCustomization.buttons.prev.y, 
        characterCustomization.buttons.prev.width, 
        characterCustomization.buttons.prev.height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(characterCustomization.buttons.prev.text, 
        characterCustomization.buttons.prev.x, 
        characterCustomization.buttons.prev.y + 15, 
        characterCustomization.buttons.prev.width, 
        "center")
    
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.rectangle("fill", 
        characterCustomization.buttons.next.x, 
        characterCustomization.buttons.next.y, 
        characterCustomization.buttons.next.width, 
        characterCustomization.buttons.next.height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(characterCustomization.buttons.next.text, 
        characterCustomization.buttons.next.x, 
        characterCustomization.buttons.next.y + 15, 
        characterCustomization.buttons.next.width, 
        "center")
    
    -- Color index display
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Color %d/%d", 
        characterCustomization.currentColorIndex, 
        #characterCustomization.colors
    ), 0, 380, love.graphics.getWidth(), "center")
    
    -- Face drawing section
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Face:", 0, 420, love.graphics.getWidth(), "center")
    love.graphics.printf("Click and drag to draw", 0, 440, love.graphics.getWidth(), "center")
    
    -- Draw the face canvas
    if characterCustomization.faceCanvas then
        -- Check if canvas is still valid
        local success = pcall(function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(characterCustomization.faceCanvas,
                characterCustomization.previewRect.x,
                characterCustomization.previewRect.y
            )
        end)
        if not success then
            print("[Draw] Canvas is invalid, clearing reference")
            characterCustomization.faceCanvas = nil
        end
    end
    
    -- Draw clear button
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.rectangle("fill", 
        characterCustomization.buttons.clear.x, 
        characterCustomization.buttons.clear.y, 
        characterCustomization.buttons.clear.width, 
        characterCustomization.buttons.clear.height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(characterCustomization.buttons.clear.text, 
        characterCustomization.buttons.clear.x, 
        characterCustomization.buttons.clear.y + 15, 
        characterCustomization.buttons.clear.width, 
        "center")
    
    -- Draw confirm button
    love.graphics.setColor(0.2, 0.8, 0.2)
    love.graphics.rectangle("fill", 
        characterCustomization.buttons.confirm.x, 
        characterCustomization.buttons.confirm.y, 
        characterCustomization.buttons.confirm.width, 
        characterCustomization.buttons.confirm.height)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(characterCustomization.buttons.confirm.text, 
        characterCustomization.buttons.confirm.x, 
        characterCustomization.buttons.confirm.y + 15, 
        characterCustomization.buttons.confirm.width, 
        "center")
    
    -- Draw cancel button
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", 
        characterCustomization.buttons.cancel.x, 
        characterCustomization.buttons.cancel.y, 
        characterCustomization.buttons.cancel.width, 
        characterCustomization.buttons.cancel.height)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(characterCustomization.buttons.cancel.text, 
        characterCustomization.buttons.cancel.x, 
        characterCustomization.buttons.cancel.y + 15, 
        characterCustomization.buttons.cancel.width, 
        "center")
    
end

function characterCustomization.clearFace()
    if characterCustomization.faceCanvas then
        love.graphics.setCanvas(characterCustomization.faceCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setCanvas()
    end
end

function characterCustomization.getFacePoints()
    if characterCustomization.faceCanvas then
        local success, width, height = pcall(function()
            return characterCustomization.faceCanvas:getWidth(), characterCustomization.faceCanvas:getHeight()
        end)
        if success then
            print(string.format("[GetFacePoints] Canvas dimensions: %dx%d", width, height))
        else
            print("[GetFacePoints] Canvas is not valid")
        end
    else
        print("[GetFacePoints] Canvas is nil")
    end
    return characterCustomization.faceCanvas
end


return characterCustomization
-- charactercustom.lua
local debugConsole = require "scripts.debugconsole"

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
characterCustomization.state = "color" -- can be "color" or "face"
characterCustomization.isDrawing = false
characterCustomization.currentStroke = {}

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


characterCustomization.buttons = {
    prev = {x = 250, y = 275, width = 50, height = 50, text = "<"},
    next = {x = 500, y = 275, width = 50, height = 50, text = ">"},
    confirm = {x = 325, y = 375, width = 150, height = 50, text = "Confirm"},
    clear = {x = 325, y = 425, width = 150, height = 50, text = "Clear Face", visible = false}
}

-- Initialize canvas
function characterCustomization.init()
    characterCustomization.faceCanvas = love.graphics.newCanvas(
        characterCustomization.canvasSize,
        characterCustomization.canvasHeight
    )
    -- Clear canvas with transparency
    love.graphics.setCanvas(characterCustomization.faceCanvas)
    love.graphics.clear(0, 0, 0, 0)
    -- sets extra space at the top for drawing hats
    love.graphics.translate(0, characterCustomization.canvasHeight - characterCustomization.canvasSize) 
    -- Set initial line width
    love.graphics.setLineWidth(2)
    love.graphics.setCanvas()
end

function characterCustomization.getCurrentColor()
    return characterCustomization.colors[characterCustomization.currentColorIndex]
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
        debugConsole.addMessage(string.format("Mouse clicked at: %d, %d, state: %s", x, y, characterCustomization.state))
        if characterCustomization.state == "color" then
            if isMouseOver(characterCustomization.buttons.prev) then
                debugConsole.addMessage("Previous color button clicked")
                characterCustomization.prevColor()
                return true
            elseif isMouseOver(characterCustomization.buttons.next) then
                debugConsole.addMessage("Next color button clicked")
                characterCustomization.nextColor()
                return true
            elseif isMouseOver(characterCustomization.buttons.confirm) then
                debugConsole.addMessage("Confirm button clicked - switching to face drawing")
                characterCustomization.state = "face"
                -- Clear canvas when starting face drawing
                love.graphics.setCanvas(characterCustomization.faceCanvas)
                love.graphics.clear(0, 0, 0, 0)
                love.graphics.setCanvas()
                return true
            end
        elseif characterCustomization.state == "face" then
            debugConsole.addMessage(string.format("Face state - checking buttons. Confirm at: %d,%d size: %dx%d", 
                characterCustomization.buttons.confirm.x, 
                characterCustomization.buttons.confirm.y,
                characterCustomization.buttons.confirm.width,
                characterCustomization.buttons.confirm.height))
            if isMouseOver(characterCustomization.previewRect) then
                debugConsole.addMessage("Started drawing on preview rect")
                characterCustomization.isDrawing = true
                characterCustomization.currentStroke = {
                    x = x - characterCustomization.previewRect.x,
                    y = y - characterCustomization.previewRect.y
                }
                return true
            elseif isMouseOver(characterCustomization.buttons.confirm) then
                debugConsole.addMessage("Done button clicked in face state")
                -- Improved drawing check
                local imageData = characterCustomization.faceCanvas:newImageData()
                local hasDrawing = false
                
                -- Sample every few pixels to check for any non-transparent pixels
                for y = 0, imageData:getHeight() - 1, 2 do
                    for x = 0, imageData:getWidth() - 1, 2 do
                        local r, g, b, a = imageData:getPixel(x, y)
                        if a > 0 then
                            hasDrawing = true
                            break
                        end
                    end
                    if hasDrawing then break end
                end

                if hasDrawing then
                    debugConsole.addMessage("Face completed - returning confirm")
                    return "confirm"
                else
                    debugConsole.addMessage("No face drawn, but allowing completion anyway for testing")
                    return "confirm"
                end
            elseif isMouseOver(characterCustomization.buttons.clear) then
                characterCustomization.clearFace()
                debugConsole.addMessage("Face cleared")
                return true
            end
        end
    end
    return false
end

function characterCustomization.mousereleased(x, y, button)
    characterCustomization.isDrawing = false
    characterCustomization.currentStroke = {}
end

function characterCustomization.mousemoved(x, y)
    if characterCustomization.isDrawing  then--and isMouseOver(characterCustomization.previewRectExtraBoundaries) then
        local newX = x - characterCustomization.previewRect.x
        local newY = y - characterCustomization.previewRect.y
        
        -- Draw line to canvas
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
        -- Reset line width
        love.graphics.setLineWidth(1)
        love.graphics.setCanvas()
        
        -- Update current position
        characterCustomization.currentStroke.x = newX
        characterCustomization.currentStroke.y = newY
    end
end

function characterCustomization.draw()
    if characterCustomization.state == "color" then
        -- Draw color selection UI
        local color = characterCustomization.getCurrentColor()
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", 
            characterCustomization.previewRect.x,
            characterCustomization.previewRect.y,
            characterCustomization.previewRect.width,
            characterCustomization.previewRect.height
        )

        -- Draw navigation buttons
        love.graphics.setColor(0.7, 0.7, 0.7)
        for _, button in pairs(characterCustomization.buttons) do
            if button.text ~= "Clear Face" then
                love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
                love.graphics.setColor(0, 0, 0)
                love.graphics.printf(button.text, button.x, button.y + 15, button.width, "center")
                love.graphics.setColor(0.7, 0.7, 0.7)
            end
        end

        -- Draw title and color index
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Choose Your Color", 0, 150, love.graphics.getWidth(), "center")
        love.graphics.printf(string.format("Color %d/%d", 
            characterCustomization.currentColorIndex, 
            #characterCustomization.colors
        ), 0, 200, love.graphics.getWidth(), "center")

    elseif characterCustomization.state == "face" then
        -- Draw face customization UI
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Draw Your Face", 0, 150, love.graphics.getWidth(), "center")
        love.graphics.printf("Click and drag to draw", 0, 200, love.graphics.getWidth(), "center")

        -- Draw the preview square with current color
        love.graphics.setColor(characterCustomization.getCurrentColor())
        love.graphics.rectangle("fill", 
            characterCustomization.previewRect.x,
            characterCustomization.previewRect.y,
            characterCustomization.previewRect.width,
            characterCustomization.previewRect.height
        )

        -- Draw the face canvas
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(characterCustomization.faceCanvas,
            characterCustomization.previewRect.x,
            characterCustomization.previewRect.y
        )

        -- Draw buttons
        love.graphics.setColor(0.7, 0.7, 0.7)
        characterCustomization.buttons.confirm.text = "Done"
        characterCustomization.buttons.clear.visible = true
        for _, button in pairs(characterCustomization.buttons) do
            if button.visible ~= false then
                love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
                love.graphics.setColor(0, 0, 0)
                love.graphics.printf(button.text, button.x, button.y + 15, button.width, "center")
                love.graphics.setColor(0.7, 0.7, 0.7)
            end
        end
        love.graphics.setColor(1, 1, 1)
        local imageData = characterCustomization.faceCanvas:newImageData()
        local pixelCount = 0
        for y = 0, imageData:getHeight() - 1, 2 do
            for x = 0, imageData:getWidth() - 1, 2 do
                local r, g, b, a = imageData:getPixel(x, y)
                if a > 0 then pixelCount = pixelCount + 1 end
            end
        end
        love.graphics.print(string.format("Drawn pixels: %d", pixelCount), 
            characterCustomization.previewRect.x, 
            characterCustomization.previewRect.y - 20)
    end
end

function characterCustomization.clearFace()
    love.graphics.setCanvas(characterCustomization.faceCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setCanvas()
end

function characterCustomization.getFacePoints()
    return characterCustomization.faceCanvas
end

return characterCustomization
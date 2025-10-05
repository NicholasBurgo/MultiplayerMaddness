-- ============================================================================
-- CONNECTING SCENE
-- ============================================================================
-- Screen for entering server IP/hostname before joining

local events = require("src.core.events")
local musicHandler = require("src.game.systems.musichandler")

local connecting = {}
connecting.name = "connecting"

-- Base resolution
local BASE_WIDTH = 800
local BASE_HEIGHT = 600

-- UI State
local menuBackground = nil
local centerX = (BASE_WIDTH - 200) / 2  -- Center for 200px wide elements

local inputField = {
    x = centerX,
    y = 250,
    width = 200,
    height = 30,
    text = "localhost",
    active = true
}

local buttons = {
    connect = {x = centerX, y = 300, width = 200, height = 50, text = "Connect"},
    back = {x = centerX, y = 370, width = 200, height = 50, text = "Back"}
}

function connecting.load(args)
    -- Load background
    if not menuBackground then
        menuBackground = love.graphics.newImage("images/menu-background.jpg")
    end
    
    -- Reset input field
    inputField.active = true
    inputField.text = inputField.text or "localhost"
end

function connecting.update(dt)
    musicHandler.update(dt)
end

function connecting.draw()
    -- Draw background
    local bgx, bgy = musicHandler.applyToDrawable("menu_bg", 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(menuBackground, bgx, bgy)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf("Join Game", 0, 150, BASE_WIDTH, "center")
    
    -- Draw instructions
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("Enter server address:", 0, 210, BASE_WIDTH, "center")
    
    -- Draw input field
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.rectangle("fill", inputField.x, inputField.y, inputField.width, inputField.height)
    
    if inputField.active then
        love.graphics.setColor(0.3, 0.6, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", inputField.x, inputField.y, inputField.width, inputField.height)
    else
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", inputField.x, inputField.y, inputField.width, inputField.height)
    end
    
    -- Draw input text
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(inputField.text, inputField.x + 5, inputField.y + 7, inputField.width - 10, "left")
    
    -- Draw cursor if active
    if inputField.active then
        local textWidth = love.graphics.getFont():getWidth(inputField.text)
        local cursorX = inputField.x + 5 + textWidth
        local time = love.timer.getTime()
        if math.floor(time * 2) % 2 == 0 then  -- Blink cursor
            love.graphics.line(cursorX, inputField.y + 5, cursorX, inputField.y + inputField.height - 5)
        end
    end
    
    -- Draw buttons
    -- Connect button
    love.graphics.setColor(0.2, 0.8, 0.2)
    love.graphics.rectangle("fill", buttons.connect.x, buttons.connect.y, buttons.connect.width, buttons.connect.height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(buttons.connect.text, buttons.connect.x, buttons.connect.y + 15, buttons.connect.width, "center")
    
    -- Back button
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.rectangle("fill", buttons.back.x, buttons.back.y, buttons.back.width, buttons.back.height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(buttons.back.text, buttons.back.x, buttons.back.y + 15, buttons.back.width, "center")
end

function connecting.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    print(string.format("[Connecting] Mouse clicked at: %d, %d", x, y))
    
    -- Check input field
    if x >= inputField.x and x <= inputField.x + inputField.width and
       y >= inputField.y and y <= inputField.y + inputField.height then
        print("[Connecting] Input field clicked")
        inputField.active = true
        return
    else
        inputField.active = false
    end
    
    -- Check connect button
    if x >= buttons.connect.x and x <= buttons.connect.x + buttons.connect.width and
       y >= buttons.connect.y and y <= buttons.connect.y + buttons.connect.height then
        print("[Connecting] Connect button clicked! Attempting to join: " .. inputField.text)
        -- Emit join intent with the entered address
        events.emit("intent:join", {host=inputField.text, port=12345})
        return
    end
    
    -- Check back button
    if x >= buttons.back.x and x <= buttons.back.x + buttons.back.width and
       y >= buttons.back.y and y <= buttons.back.y + buttons.back.height then
        print("[Connecting] Back button clicked")
        events.emit("intent:back_to_menu")
        return
    end
    
    print("[Connecting] No button clicked")
end

function connecting.keypressed(k)
    if k == "escape" then
        events.emit("intent:back_to_menu")
    elseif k == "return" or k == "enter" then
        -- Connect on Enter key
        events.emit("intent:join", {host=inputField.text, port=12345})
    elseif k == "backspace" and inputField.active then
        inputField.text = inputField.text:sub(1, -2)
    end
end

function connecting.textinput(t)
    if inputField.active then
        inputField.text = inputField.text .. t
    end
end

return connecting

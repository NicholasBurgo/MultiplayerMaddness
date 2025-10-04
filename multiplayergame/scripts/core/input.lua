-- input.lua
-- Centralized input handling for all game modules

local constants = require "scripts.core.constants"

local input = {}

-- Check if any of the specified keys are currently pressed
function input.isKeyDown(keys)
    if type(keys) == "string" then
        return love.keyboard.isDown(keys)
    elseif type(keys) == "table" then
        for _, key in ipairs(keys) do
            if love.keyboard.isDown(key) then
                return true
            end
        end
    end
    return false
end

-- Get movement input as normalized vector
function input.getMovementInput()
    local dx, dy = 0, 0
    
    if input.isKeyDown(constants.INPUT_KEYS.MOVE_LEFT) then
        dx = dx - 1
    end
    if input.isKeyDown(constants.INPUT_KEYS.MOVE_RIGHT) then
        dx = dx + 1
    end
    if input.isKeyDown(constants.INPUT_KEYS.MOVE_UP) then
        dy = dy - 1
    end
    if input.isKeyDown(constants.INPUT_KEYS.MOVE_DOWN) then
        dy = dy + 1
    end
    
    -- Normalize diagonal movement
    if dx ~= 0 and dy ~= 0 then
        dx = dx * 0.707
        dy = dy * 0.707
    end
    
    return dx, dy
end

-- Check if jump key is pressed
function input.isJumpPressed()
    return input.isKeyDown(constants.INPUT_KEYS.JUMP)
end

-- Check if action key is pressed
function input.isActionPressed()
    return input.isKeyDown(constants.INPUT_KEYS.ACTION)
end

-- Get mouse position
function input.getMousePosition()
    return love.mouse.getPosition()
end

-- Check if mouse button is pressed
function input.isMousePressed(button)
    return love.mouse.isDown(button or 1)
end

return input

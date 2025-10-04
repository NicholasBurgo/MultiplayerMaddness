-- ui.lua
-- Centralized UI rendering utilities for all game modules

local constants = require "scripts.core.constants"
local timer = require "scripts.core.timer"

local ui = {}

-- Set color with RGB values
function ui.setColor(r, g, b, a)
    if type(r) == "table" then
        -- Color table passed
        love.graphics.setColor(r[1], r[2], r[3], r[4] or 1)
    else
        -- Individual RGB values passed
        love.graphics.setColor(r, g, b, a or 1)
    end
end

-- Draw rectangle with color
function ui.drawRect(mode, x, y, width, height, color)
    if color then
        ui.setColor(color)
    end
    love.graphics.rectangle(mode, x, y, width, height)
end

-- Draw filled rectangle
function ui.drawFilledRect(x, y, width, height, color)
    ui.drawRect("fill", x, y, width, height, color)
end

-- Draw rectangle outline
function ui.drawRectOutline(x, y, width, height, color)
    ui.drawRect("line", x, y, width, height, color)
end

-- Draw centered text
function ui.drawCenteredText(text, x, y, width, color)
    if color then
        ui.setColor(color)
    end
    love.graphics.printf(text, x, y, width, "center")
end

-- Draw timer display
function ui.drawTimer(gameTimer, x, y, width, color)
    local timeText = "Time: " .. timer.formatTime(gameTimer)
    ui.drawCenteredText(timeText, x, y, width, color)
end

-- Draw score display
function ui.drawScore(score, x, y, color)
    local scoreText = "Score: " .. math.floor(score)
    if color then
        ui.setColor(color)
    end
    love.graphics.print(scoreText, x, y)
end

-- Draw total score display
function ui.drawTotalScore(totalScore, x, y, color)
    local totalScoreText = "Total Score: " .. math.floor(totalScore or 0)
    if color then
        ui.setColor(color)
    end
    love.graphics.print(totalScoreText, x, y)
end

-- Draw player with face
function ui.drawPlayer(x, y, width, height, color, facePoints)
    -- Draw player body
    ui.drawFilledRect(x, y, width, height, color)
    
    -- Draw player face if available
    if facePoints then
        ui.setColor(constants.UI_COLORS.WHITE)
        love.graphics.draw(facePoints, x, y, 0, width/100, height/100)
    end
end

-- Draw ghost player (for multiplayer)
function ui.drawGhostPlayer(x, y, width, height, color, facePoints)
    -- Draw ghost player body with transparency
    local ghostColor = {color[1], color[2], color[3], 0.5}
    ui.drawFilledRect(x, y, width, height, ghostColor)
    
    -- Draw ghost player face if available
    if facePoints then
        ui.setColor(1, 1, 1, 0.5)
        love.graphics.draw(facePoints, x, y, 0, width/100, height/100)
    end
end

-- Draw game over screen
function ui.drawGameOver(message, x, y, width, color)
    ui.drawCenteredText(message, x, y, width, color)
end

return ui

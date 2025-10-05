-- ============================================================================
-- GAME UI SYSTEM
-- ============================================================================
-- Unified UI for all games with consistent styling matching party timer

local gameUI = {}

-- Font sizes
local fonts = {
    large = love.graphics.newFont(36),
    medium = love.graphics.newFont(24),
    small = love.graphics.newFont(18)
}

-- Colors
local colors = {
    primary = {1, 1, 1, 1},
    hits = {1, 0.3, 0.3, 1},
    score = {0.3, 1, 0.3, 1},
    shadow = {0, 0, 0, 0.5}
}

-- Draw text with shadow for better visibility
local function drawTextWithShadow(text, x, y, font, color)
    love.graphics.setFont(font)
    
    -- Shadow
    love.graphics.setColor(colors.shadow)
    love.graphics.print(text, x + 2, y + 2)
    
    -- Main text
    love.graphics.setColor(color)
    love.graphics.print(text, x, y)
    
    -- Reset
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw hit counter (for laser, meteor, dodge games)
function gameUI.drawHitCounter(hits, x, y)
    x = x or 10
    y = y or 10
    
    local text = "Hits: " .. hits
    drawTextWithShadow(text, x, y, fonts.medium, colors.hits)
end

-- Keep old function for backward compatibility
function gameUI.drawDeathCounter(deaths, x, y)
    gameUI.drawHitCounter(deaths, x, y)
end

-- Draw score (for jump game)
function gameUI.drawScore(score, x, y)
    x = x or 10
    y = y or 10
    
    local text = "Score: " .. math.floor(score)
    drawTextWithShadow(text, x, y, fonts.medium, colors.score)
end

-- Draw tab score overlay (shows all players' scores)
function gameUI.drawTabScores(players, localPlayerId, gameMode)
    if not players then return end
    
    local BASE_WIDTH = 800
    local BASE_HEIGHT = 600
    
    -- Semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', BASE_WIDTH/2 - 200, 100, 400, (#players * 40) + 60)
    
    -- Title
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("SCORES", BASE_WIDTH/2 - 200, 110, 400, "center")
    
    -- Player scores
    love.graphics.setFont(fonts.medium)
    local y = 160
    local index = 1
    
    for id, player in pairs(players) do
        -- Highlight local player
        if id == localPlayerId then
            love.graphics.setColor(1, 1, 0, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        
        local name = player.name or ("Player " .. id)
        local score = 0
        
        -- Get score based on game mode
        if gameMode == "jump" then
            score = player.jumpScore or player.totalScore or 0
        elseif gameMode == "laser" then
            score = player.laserDeaths or 0
        elseif gameMode == "meteorshower" then
            score = player.meteorDeaths or 0
        elseif gameMode == "dodge" then
            score = player.dodgeDeaths or 0
        else
            score = player.totalScore or 0
        end
        
        -- Draw player entry
        local scoreText = gameMode == "jump" and string.format("%d pts", score) or string.format("%d hits", score)
        love.graphics.print(string.format("%d. %s", index, name), BASE_WIDTH/2 - 180, y)
        love.graphics.print(scoreText, BASE_WIDTH/2 + 100, y)
        
        y = y + 35
        index = index + 1
    end
    
    -- Instructions
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf("Hold TAB to view", BASE_WIDTH/2 - 200, y + 10, 400, "center")
    
    -- Reset
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw respawn message
function gameUI.drawRespawnMessage(respawnTime)
    local BASE_WIDTH = 800
    local BASE_HEIGHT = 600
    
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.printf("RESPAWNING IN " .. math.ceil(respawnTime), 
        0, BASE_HEIGHT/2 - 50, BASE_WIDTH, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw invincibility indicator
function gameUI.drawInvincibility(time)
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print("INVINCIBLE: " .. string.format("%.1f", time), 10, 50)
    love.graphics.setColor(1, 1, 1, 1)
end

return gameUI

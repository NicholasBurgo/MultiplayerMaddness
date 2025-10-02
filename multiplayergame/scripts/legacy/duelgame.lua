local duelGame = {}
local debugConsole = require "scripts.debugconsole"
local musicHandler = require "scripts.musichandler"
local anim8 = require "scripts.anim8"

-- Game state
duelGame.state = "start"  -- states: start, result
duelGame.current_round_score = 0
duelGame.game_over = false
duelGame.winning_points = 300

-- Animation states
duelGame.currentAnim = nil
duelGame.startAnim = nil
duelGame.winAnim = nil
duelGame.loseAnim = nil
duelGame.startSprite = nil
duelGame.winSprite = nil
duelGame.loseSprite = nil
duelGame.frameCount = 0
duelGame.shootWindow = {39, 41}  -- Valid frames for shooting
duelGame.hasShot = false
duelGame.shotResult = nil  -- "win" or "lose"

-- Pause timers
duelGame.firstPauseTimer = 0.5
duelGame.endingPauseTimer = 1.0  
duelGame.currentPauseTimer = 0

-- sounds
duelGame.sounds = {
    gunshot = love.audio.newSource("sounds/gunshot.mp3", "static"),
}

duelGame.sounds.gunshot:setVolume(0.4)

function duelGame.load()
    font = love.graphics.newFont(17) -- sets size of font

    -- Load spritesheets
    duelGame.startSprite = love.graphics.newImage("images/duelstart.png")
    duelGame.winSprite = love.graphics.newImage("images/duelwin.png")
    duelGame.loseSprite = love.graphics.newImage("images/duellose.png")
    
    -- Set nearest neighbor filtering for pixel art
    duelGame.startSprite:setFilter("nearest", "nearest")
    duelGame.winSprite:setFilter("nearest", "nearest")
    duelGame.loseSprite:setFilter("nearest", "nearest")
    
    -- Create animation grids
    local startGrid = anim8.newGrid(400, 300, 400 * 5, 300 * 12)  -- 5 columns, 12 rows
    local winGrid = anim8.newGrid(400, 300, 400 * 5, 300 * 4)     -- 5 columns, 4 rows
    local loseGrid = anim8.newGrid(400, 300, 400 * 5, 300 * 4)    -- 5 columns, 4 rows
    
    -- Duration per frame (assuming 30fps for smooth animation)
    local frameDuration = 1/30
    
    -- Create animations
    duelGame.startAnim = anim8.newAnimation(startGrid('1-5', '1-12'), frameDuration)
    duelGame.winAnim = anim8.newAnimation(winGrid('1-5', '1-4'), frameDuration)
    duelGame.loseAnim = anim8.newAnimation(loseGrid('1-5', '1-4'), frameDuration)
    
    duelGame.reset()
end

function duelGame.reset()
    duelGame.state = "start"
    -- Reset animations to their first frame
    duelGame.startAnim:gotoFrame(1)  -- Make sure start animation begins from frame 1
    duelGame.winAnim:gotoFrame(1)    -- Reset win animation
    duelGame.loseAnim:gotoFrame(1)   -- Reset lose animation
    duelGame.currentAnim = duelGame.startAnim
    duelGame.frameCount = 0
    duelGame.hasShot = false
    duelGame.shotResult = nil
    duelGame.game_over = false
    duelGame.current_round_score = 0
    duelGame.currentPauseTimer = 0
    love.graphics.setFont(love.graphics.newFont(12))
end

function duelGame.update(dt)
    if duelGame.game_over then return end

    if duelGame.state == "start" then
        if duelGame.currentPauseTimer > 0 then
            -- During first pause, stay on last frame of start animation
            duelGame.currentPauseTimer = duelGame.currentPauseTimer - dt
            if duelGame.currentPauseTimer <= 0 then
                -- After pause, switch to result animation
                duelGame.state = "result"
                duelGame.currentAnim = duelGame.shotResult == "win" and duelGame.winAnim or duelGame.loseAnim
                duelGame.currentPauseTimer = 0
            end
        else
            duelGame.currentAnim:update(dt)
            duelGame.frameCount = duelGame.currentAnim.position
            if duelGame.frameCount >= 40 then
                duelGame.sounds.gunshot:play()
            end
            if duelGame.frameCount >= 56 then
                duelGame.currentPauseTimer = duelGame.firstPauseTimer
                if not duelGame.hasShot then
                    duelGame.shotResult = "lose"
                end
            end
        end
    elseif duelGame.state == "result" then  
        if duelGame.currentPauseTimer > 0 then
            -- During ending pause, stay on last frame
            duelGame.currentPauseTimer = duelGame.currentPauseTimer - dt
            if duelGame.currentPauseTimer <= 0 then
                duelGame.game_over = true
            end
        else
            duelGame.currentAnim:update(dt)
            -- Check for end of result animation
            if duelGame.currentAnim.position >= (duelGame.shotResult == "win" and 18 or 18) then
                duelGame.currentPauseTimer = duelGame.endingPauseTimer
            end
        end
    end
end

function duelGame.keypressed(key)
    if key == "space" and not duelGame.hasShot and duelGame.frameCount > 0 then
        duelGame.hasShot = true
        
        -- Check if shot was within valid window
        if duelGame.frameCount >= duelGame.shootWindow[1] and 
            duelGame.frameCount <= duelGame.shootWindow[2] then
            duelGame.shotResult = "win"
            duelGame.current_round_score = duelGame.winning_points
        else
            duelGame.shotResult = "lose"
        end
    end
end

function duelGame.draw()
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    if duelGame.currentAnim then
        love.graphics.setColor(1, 1, 1, 1)
        
        local scale = 2
        local spriteWidth = 400
        local spriteHeight = 300
        
        local x = (love.graphics.getWidth() - (spriteWidth * scale)) / 2
        local y = (love.graphics.getHeight() - (spriteHeight * scale)) / 2
        
        local sprite = duelGame.startSprite
        if duelGame.state == "result" then
            sprite = (duelGame.shotResult == "win") and duelGame.winSprite or duelGame.loseSprite
        end
        
        duelGame.currentAnim:draw(sprite, x, y, 0, scale, scale)
    end
    
    if duelGame.winAnim.position >= 10 and duelGame.shotResult == "win" then
        debugConsole.addMessage("[Duel Game] WIN")
        love.graphics.setColor(1, 0, 0)
        love.graphics.setFont(font)
        if duelGame.shotResult == "win" then
            love.graphics.printf(string.format("YOU WIN! +300 POINTS!"),
                0, love.graphics.getHeight()/2 - 30,
                love.graphics.getWidth(), "center")
        end
    elseif duelGame.loseAnim.position >= 10 and duelGame.shotResult == "lose" then
        debugConsole.addMessage("[Duel Game] LOSE")
        love.graphics.setColor(1, 0, 0)
        love.graphics.setFont(font)
        if duelGame.shotResult == "lose" then
            love.graphics.printf(string.format("YOU LOST! SKILL ISSUE!"),
                0, love.graphics.getHeight()/2 - 30,
                love.graphics.getWidth(), "center")
        end
    end
    
    love.graphics.setFont(love.graphics.newFont(12))

end

return duelGame
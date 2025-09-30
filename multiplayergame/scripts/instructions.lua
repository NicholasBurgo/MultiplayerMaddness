local instructions = {}
local debugConsole = require "scripts.debugconsole"
local musicHandler = require "scripts.musichandler"

-- Sprite setup
instructions.jumpSprite = nil
instructions.laserSprite = nil
instructions.spriteWidth = 400  -- Adjust based on your sprite size
instructions.spriteHeight = 300 -- Adjust based on your sprite size
instructions.currentAnim = nil
instructions.anim8 = require "scripts.anim8"

-- Animation states
instructions.showing = false
instructions.isTransitioning = false
instructions.slidePos = -love.graphics.getWidth()
instructions.targetPos = 0
instructions.slideSpeed = love.graphics.getWidth() / (musicHandler.beatInterval / 2)  -- Complete slide in 1/4 beat
instructions.displayTimer = 0
instructions.displayDuration = musicHandler.beatInterval / 2  -- Show for exactly 1/4 beat
instructions.currentCallback = nil

function instructions.load()
    -- Load sprite sheets
    instructions.jumpSprite = love.graphics.newImage("images/jumpintro.png")
    instructions.jumpSprite:setFilter("nearest", "nearest")
    instructions.laserSprite = love.graphics.newImage("images/lasersintro.png")
    instructions.laserSprite:setFilter("nearest", "nearest")
    -- instructions.battleroyaleSprite = love.graphics.newImage("battleroyaleintro.png")
    -- instructions.battleroyaleSprite:setFilter("nearest", "nearest")
    instructions.raceSprite = love.graphics.newImage("images/raceintro.png")
    instructions.raceSprite:setFilter("nearest", "nearest")
    -- Create animations for both instruction types
    local jumpGrid = instructions.anim8.newGrid(400, 300, 400, 600)
    local laserGrid = instructions.anim8.newGrid(400, 300, 400, 600)
    -- local battleroyaleGrid = instructions.anim8.newGrid(400, 300, 400, 600)
    local raceGrid = instructions.anim8.newGrid(400, 300, 400, 600)
    instructions.jumpAnim = instructions.anim8.newAnimation(jumpGrid('1-1', '1-2'), 0.5)
    instructions.laserAnim = instructions.anim8.newAnimation(laserGrid('1-1', '1-2'), 0.5)
    -- instructions.battleroyaleAnim = instructions.anim8.newAnimation(battleroyaleGrid('1-1', '1-2'), 0.5)
    instructions.raceAnim = instructions.anim8.newAnimation(raceGrid('1-1', '1-2'), 0.5)
end

function instructions.show(gameType, callback)
    -- If already transitioning, ignore new requests
    if instructions.isTransitioning then
        debugConsole.addMessage("[Instructions] Blocked duplicate instruction request during transition")
        return
    end

    instructions.isTransitioning = true
    instructions.showing = true
    instructions.slidePos = -love.graphics.getWidth()
    instructions.targetPos = 0
    instructions.displayTimer = instructions.displayDuration
    instructions.currentCallback = callback

    -- Set current animation based on game type
    if gameType == "jumpgame" then
        instructions.currentAnim = instructions.jumpAnim
        instructions.currentSprite = instructions.jumpSprite
    elseif gameType == "lasergame" then
        instructions.currentAnim = instructions.laserAnim
        instructions.currentSprite = instructions.laserSprite
    elseif gameType == "battleroyale" then
        -- Skip instruction screen for battle royale
        instructions.showing = false
        instructions.isTransitioning = false
        if callback then
            callback()
        end
        return
    elseif gameType == "racegame" then
        instructions.currentAnim = instructions.raceAnim
        instructions.currentSprite = instructions.raceSprite
    end
end

function instructions.update(dt)
    if not instructions.showing then
        instructions.isTransitioning = false
        instructions.currentCallback = nil
        return
    end
    
    -- Update animation
    if instructions.currentAnim then
        instructions.currentAnim:update(dt)
    end
    
    -- Precise slide timing
    local totalTime = musicHandler.beatInterval/4  -- Slide duration
    if instructions.slidePos < instructions.targetPos then
        instructions.slidePos = instructions.slidePos + instructions.slideSpeed * dt
        if instructions.slidePos > instructions.targetPos then
            instructions.slidePos = instructions.targetPos
        end
    else
        -- Once in position, start countdown with precise timing
        instructions.displayTimer = instructions.displayTimer - dt
        if instructions.displayTimer <= 0 then
            instructions.showing = false
            instructions.isTransitioning = false
            local callback = instructions.currentCallback
            instructions.currentCallback = nil
            
            if callback then
                callback()
            end
        end
    end
end

function instructions.draw()
    if not instructions.showing then return end
    
    -- Draw semi-transparent dark overlay
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    if instructions.currentAnim and instructions.currentSprite then
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Scale exactly 2x since we want 400->800 and 300->600
        local scale = 2
        
        -- Calculate centered positions
        local x = instructions.slidePos + (love.graphics.getWidth() - (instructions.spriteWidth * scale)) / 2
        local y = (love.graphics.getHeight() - (instructions.spriteHeight * scale)) / 2
        
        -- Draw the scaled animation
        instructions.currentAnim:draw(
            instructions.currentSprite,
            x,
            y,
            0,  -- rotation
            scale,  -- scale X
            scale   -- scale Y
        )
    end
end

-- Add cleanup function
function instructions.clear()
    instructions.showing = false
    instructions.isTransitioning = false
    instructions.currentCallback = nil
    instructions.slidePos = -love.graphics.getWidth()
end

return instructions

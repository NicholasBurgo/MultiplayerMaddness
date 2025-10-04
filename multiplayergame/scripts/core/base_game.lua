-- base_game.lua
-- Base game class that provides common functionality for all game modules

local constants = require "scripts.core.constants"
local logger = require "scripts.core.logger"
local timer = require "scripts.core.timer"
local ui = require "scripts.core.ui"

local BaseGame = {}

function BaseGame:new(gameName)
    local instance = {
        gameName = gameName or "Unknown",
        game_over = false,
        current_round_score = 0,
        playerColor = constants.DEFAULT_PLAYER_COLOR,
        gameTimer = timer.create(constants.DEFAULT_GAME_DURATION),
        startTimer = timer.create(3), -- 3 second countdown
        isStarted = false
    }
    
    setmetatable(instance, self)
    self.__index = self
    
    return instance
end

-- Initialize the base game state
function BaseGame:initialize()
    self.game_over = false
    self.current_round_score = 0
    self.isStarted = false
    timer.reset(self.gameTimer)
    timer.reset(self.startTimer)
    logger.gameReset(self.gameName)
end

-- Update base game logic
function BaseGame:update(dt)
    -- Update start timer
    if not self.isStarted then
        timer.update(self.startTimer, dt)
        if timer.isExpired(self.startTimer) then
            self.isStarted = true
            timer.start(self.gameTimer)
            logger.gameStart(self.gameName)
        end
        return
    end
    
    -- Update game timer
    if self.isStarted and not self.game_over then
        timer.update(self.gameTimer, dt)
        if timer.isExpired(self.gameTimer) then
            self.game_over = true
            logger.gameEnd(self.gameName)
        end
    end
end

-- Draw base UI elements
function BaseGame:drawUI(playersTable, localPlayerId)
    -- Draw timer
    ui.drawTimer(self.gameTimer, 0, 10, constants.BASE_WIDTH, constants.UI_COLORS.WHITE)
    
    -- Draw round score
    ui.drawScore(self.current_round_score, 10, 10)
    
    -- Draw total score if available
    if playersTable and playersTable[localPlayerId] then
        ui.drawTotalScore(playersTable[localPlayerId].totalScore, 10, 30)
    end
    
    -- Countdown removed - games start immediately
    
    -- Draw game over if applicable
    if self.game_over then
        ui.drawGameOver("Game Over", 0, constants.BASE_HEIGHT / 2 - 50, constants.BASE_WIDTH, constants.UI_COLORS.WHITE)
    end
end

-- Set player color
function BaseGame:setPlayerColor(color)
    self.playerColor = color or constants.DEFAULT_PLAYER_COLOR
end

-- Add to round score
function BaseGame:addScore(points)
    self.current_round_score = self.current_round_score + points
    logger.scoreUpdate(self.gameName, self.current_round_score)
end

-- Set round score
function BaseGame:setScore(score)
    self.current_round_score = score
    logger.scoreUpdate(self.gameName, self.current_round_score)
end

-- Check if game is over
function BaseGame:isGameOver()
    return self.game_over
end

-- Check if game has started
function BaseGame:hasStarted()
    return self.isStarted
end

-- Get remaining time
function BaseGame:getRemainingTime()
    return timer.getRemaining(self.gameTimer)
end

-- Get game progress (0 to 1)
function BaseGame:getProgress()
    return timer.getProgress(self.gameTimer)
end

return BaseGame

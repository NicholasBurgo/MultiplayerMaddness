-- logger.lua
-- Centralized logging system for all game modules

local debugConsole = require "scripts.debugconsole"

local logger = {}

-- Log levels
logger.LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

logger.currentLevel = logger.LEVELS.DEBUG

function logger.setLevel(level)
    logger.currentLevel = level
end

function logger.log(level, gameName, message)
    if level >= logger.currentLevel then
        local prefix = string.format("[%s]", gameName or "Unknown")
        debugConsole.addMessage(prefix .. " " .. message)
    end
end

function logger.debug(gameName, message)
    logger.log(logger.LEVELS.DEBUG, gameName, message)
end

function logger.info(gameName, message)
    logger.log(logger.LEVELS.INFO, gameName, message)
end

function logger.warn(gameName, message)
    logger.log(logger.LEVELS.WARN, gameName, message)
end

function logger.error(gameName, message)
    logger.log(logger.LEVELS.ERROR, gameName, message)
end

-- Convenience methods for common game events
function logger.gameStart(gameName)
    logger.info(gameName, "Game started")
end

function logger.gameEnd(gameName)
    logger.info(gameName, "Game ended")
end

function logger.gameReset(gameName)
    logger.info(gameName, "Game reset")
end

function logger.playerAction(gameName, action)
    logger.debug(gameName, "Player action: " .. action)
end

function logger.scoreUpdate(gameName, score)
    logger.debug(gameName, "Score updated: " .. score)
end

return logger

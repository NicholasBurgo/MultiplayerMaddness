-- party_mode.lua
-- Centralized party mode management system
-- Handles different party mode types and game transitions

local logger = require "scripts.core.logger"
local constants = require "scripts.core.constants"

local PartyMode = {}

-- Party mode types
PartyMode.TYPES = {
    SEQUENTIAL = "sequential",    -- Games in fixed order: jump -> laser -> meteor -> dodge -> repeat
    RANDOM = "random",           -- Random game selection each round
    TOURNAMENT = "tournament",   -- Elimination-style tournament
    SURVIVAL = "survival",       -- Players eliminated, last one standing wins
    CUSTOM = "custom"           -- User-defined game sequence
}

-- Default game lineup for sequential mode
PartyMode.DEFAULT_LINEUP = {
    "jumpgame",
    "lasergame", 
    "meteorshower",
    "dodgegame",
    "praisegame"
}

-- Party mode configuration
local partyConfig = {
    type = PartyMode.TYPES.SEQUENTIAL,
    lineup = PartyMode.DEFAULT_LINEUP,
    currentIndex = 1,
    isActive = false,
    transitionFlag = false,
    transitioned = false,
    roundsPlayed = 0,
    maxRounds = 4, -- Show score lobby every 4 rounds
    players = {},
    localPlayer = nil
}

-- Initialize party mode
function PartyMode.initialize()
    partyConfig.type = PartyMode.TYPES.SEQUENTIAL
    partyConfig.lineup = PartyMode.DEFAULT_LINEUP
    partyConfig.currentIndex = 1
    partyConfig.isActive = false
    partyConfig.transitionFlag = false
    partyConfig.transitioned = false
    partyConfig.roundsPlayed = 0
    partyConfig.players = {}
    partyConfig.localPlayer = nil
    
    logger.info("PartyMode", "Initialized with default sequential mode")
end

-- Start party mode
function PartyMode.start(type, customLineup)
    partyConfig.type = type or PartyMode.TYPES.SEQUENTIAL
    partyConfig.lineup = customLineup or PartyMode.DEFAULT_LINEUP
    partyConfig.currentIndex = 1
    partyConfig.isActive = true
    partyConfig.transitionFlag = false
    partyConfig.transitioned = false
    partyConfig.roundsPlayed = 0
    
    -- Set global party mode flag
    _G.partyMode = true
    
    -- Sync with main.lua lineup if it exists
    if _G.miniGameLineup then
        partyConfig.lineup = _G.miniGameLineup
        logger.info("PartyMode", "Synced with main.lua lineup: " .. table.concat(partyConfig.lineup, ", "))
    end
    
    logger.info("PartyMode", "Started " .. partyConfig.type .. " mode with lineup: " .. table.concat(partyConfig.lineup, ", "))
end

-- Stop party mode
function PartyMode.stop()
    partyConfig.isActive = false
    partyConfig.transitionFlag = false
    partyConfig.transitioned = false
    
    -- Clear global party mode flag
    _G.partyMode = false
    
    logger.info("PartyMode", "Stopped party mode")
end

-- Check if party mode is active
function PartyMode.isActive()
    return partyConfig.isActive
end

-- Get current game
function PartyMode.getCurrentGame()
    if not partyConfig.isActive then
        return nil
    end
    
    return partyConfig.lineup[partyConfig.currentIndex]
end

-- Get next game in sequence
function PartyMode.getNextGame()
    if not partyConfig.isActive then
        return nil
    end
    
    local nextIndex = partyConfig.currentIndex + 1
    if nextIndex > #partyConfig.lineup then
        nextIndex = 1 -- Loop back to start
    end
    
    return partyConfig.lineup[nextIndex], nextIndex
end

-- Advance to next game
function PartyMode.advanceToNext()
    if not partyConfig.isActive then
        return nil
    end
    
    local nextGame, nextIndex = PartyMode.getNextGame()
    partyConfig.currentIndex = nextIndex
    partyConfig.roundsPlayed = partyConfig.roundsPlayed + 1
    
    logger.info("PartyMode", "Advanced to game " .. partyConfig.currentIndex .. ": " .. nextGame)
    
    return nextGame
end

-- Handle game end transition
function PartyMode.handleGameEnd(gameName)
    if not partyConfig.isActive then
        return false
    end
    
    -- Check if we should show score lobby
    if partyConfig.roundsPlayed % partyConfig.maxRounds == 0 then
        logger.info("PartyMode", "Showing score lobby after " .. partyConfig.roundsPlayed .. " rounds")
        return "score_lobby"
    end
    
    -- Advance to next game first
    local nextGame = PartyMode.advanceToNext()
    logger.info("PartyMode", "Advanced from " .. gameName .. " to " .. nextGame)
    
    -- Set transition flag for main.lua to handle
    partyConfig.transitionFlag = true
    partyConfig.transitioned = true
    _G.partyModeTransition = true  -- Set the global flag that main.lua checks
    
    logger.info("PartyMode", "Game " .. gameName .. " ended, transitioning to next game")
    
    return "transition"
end

-- Check if transition is needed
function PartyMode.needsTransition()
    return partyConfig.transitionFlag
end

-- Clear transition flag
function PartyMode.clearTransition()
    partyConfig.transitionFlag = false
    _G.partyModeTransition = false  -- Clear the global flag too
end

-- Get transition info
function PartyMode.getTransitionInfo()
    if not partyConfig.transitionFlag then
        return nil
    end
    
    local nextGame = PartyMode.getNextGame()
    return {
        nextGame = nextGame,
        currentIndex = partyConfig.currentIndex,
        roundsPlayed = partyConfig.roundsPlayed,
        lineup = partyConfig.lineup
    }
end

-- Set custom lineup
function PartyMode.setCustomLineup(lineup)
    if type(lineup) == "table" and #lineup > 0 then
        partyConfig.lineup = lineup
        partyConfig.currentIndex = 1
        logger.info("PartyMode", "Set custom lineup: " .. table.concat(lineup, ", "))
    else
        logger.warn("PartyMode", "Invalid lineup provided")
    end
end

-- Get current configuration
function PartyMode.getConfig()
    return {
        type = partyConfig.type,
        lineup = partyConfig.lineup,
        currentIndex = partyConfig.currentIndex,
        isActive = partyConfig.isActive,
        roundsPlayed = partyConfig.roundsPlayed,
        maxRounds = partyConfig.maxRounds
    }
end

-- Set players for party mode
function PartyMode.setPlayers(players, localPlayer)
    partyConfig.players = players or {}
    partyConfig.localPlayer = localPlayer
end

-- Get party mode status for UI
function PartyMode.getStatus()
    if not partyConfig.isActive then
        return "Inactive"
    end
    
    local currentGame = PartyMode.getCurrentGame()
    return string.format("%s Mode - Round %d - %s", 
        partyConfig.type:gsub("^%l", string.upper), 
        partyConfig.roundsPlayed + 1,
        currentGame or "Unknown"
    )
end

-- Reset party mode (for new game sessions)
function PartyMode.reset()
    partyConfig.currentIndex = 1
    partyConfig.transitionFlag = false
    partyConfig.transitioned = false
    partyConfig.roundsPlayed = 0
    
    logger.info("PartyMode", "Reset party mode state")
end

-- Start a specific game (helper function for main.lua)
function PartyMode.startGame(gameName, players, localPlayer, serverClients)
    if not gameName then
        logger.warn("PartyMode", "No game name provided to startGame")
        return false
    end
    
    logger.info("PartyMode", "Starting game: " .. gameName)
    
    -- This function will be called by main.lua to start the actual game
    -- The actual game starting logic remains in main.lua for now
    -- This is just a placeholder for the interface
    
    return true
end

return PartyMode

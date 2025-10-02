-- Main Steam Integration Module
-- Coordinates all Steam features and provides unified interface

local steam_integration = {}

-- Import Steam modules
local steam_init = require("scripts.steam.steam_init")
local steam_networking = require("scripts.steam.steam_networking")
local steam_lobbies = require("scripts.steam.steam_lobbies")
local steam_achievements = require("scripts.steam.steam_achievements")

-- Integration state
local initialized = false
local integrationMode = "disabled" -- "disabled", "steam", "fallback"

-- Initialize Steam integration
function steam_integration.init()
    print("[Steam Integration] Initializing Steam integration...")
    
    -- Try to initialize Steam
    if steam_init.init() then
        integrationMode = "steam"
        
        -- Initialize Steam subsystems
        steam_networking.init()
        steam_lobbies.init()
        steam_achievements.init()
        
        initialized = true
        print("[Steam Integration] Steam integration enabled")
        return true
    else
        -- Fallback to non-Steam mode
        integrationMode = "fallback"
        initialized = true
        print("[Steam Integration] Steam not available, using fallback mode")
        return false
    end
end

-- Check if Steam is available
function steam_integration.isSteamAvailable()
    return integrationMode == "steam"
end

-- Get integration mode
function steam_integration.getMode()
    return integrationMode
end

-- Update Steam integration (call in love.update)
function steam_integration.update()
    if not initialized then
        return
    end
    
    if integrationMode == "steam" then
        steam_init.update()
        steam_networking.update()
        steam_lobbies.update()
        steam_achievements.update()
    end
end

-- Shutdown Steam integration
function steam_integration.shutdown()
    if initialized then
        if integrationMode == "steam" then
            steam_networking.shutdown()
            steam_lobbies.shutdown()
            steam_achievements.shutdown()
            steam_init.shutdown()
        end
        
        initialized = false
        print("[Steam Integration] Shutdown complete")
    end
end

-- Networking interface
function steam_integration.createLobby(maxPlayers, isPrivate)
    if integrationMode == "steam" then
        return steam_lobbies.createLobby(maxPlayers, isPrivate)
    else
        -- Fallback to original ENet system
        return false
    end
end

function steam_integration.joinLobby(lobbyID)
    if integrationMode == "steam" then
        return steam_lobbies.joinLobby(lobbyID)
    else
        -- Fallback to original ENet system
        return false
    end
end

function steam_integration.leaveLobby()
    if integrationMode == "steam" then
        steam_lobbies.leaveLobby()
    else
        -- Fallback to original ENet system
        return false
    end
end

function steam_integration.sendMessage(message)
    if integrationMode == "steam" then
        return steam_lobbies.sendMessage(message)
    else
        -- Fallback to original ENet system
        return false
    end
end

function steam_integration.getLobbyMembers()
    if integrationMode == "steam" then
        return steam_lobbies.getMembers()
    else
        return {}
    end
end

function steam_integration.isLobbyOwner()
    if integrationMode == "steam" then
        return steam_lobbies.isLobbyOwner()
    else
        return false
    end
end

-- Achievements interface
function steam_integration.unlockAchievement(achievementId)
    if integrationMode == "steam" then
        return steam_achievements.unlock(achievementId)
    else
        print("[Steam Integration] Achievement unlocked (Steam not available): " .. achievementId)
        return true
    end
end

function steam_integration.setStat(statName, value)
    if integrationMode == "steam" then
        return steam_achievements.setStat(statName, value)
    else
        print("[Steam Integration] Stat set (Steam not available): " .. statName .. " = " .. value)
        return true
    end
end

function steam_integration.incrementStat(statName, amount)
    if integrationMode == "steam" then
        return steam_achievements.incrementStat(statName, amount)
    else
        print("[Steam Integration] Stat incremented (Steam not available): " .. statName)
        return true
    end
end

-- User info interface
function steam_integration.getUserName()
    if integrationMode == "steam" then
        return steam_init.getUserName()
    else
        return "Player"
    end
end

function steam_integration.getUserID()
    if integrationMode == "steam" then
        return steam_init.getUserID()
    else
        return "local_player"
    end
end

-- Game event handlers
function steam_integration.onGameWin(gameType, score)
    if integrationMode == "steam" then
        steam_achievements.onGameWin(gameType, score)
    end
end

function steam_integration.onLaserGameSurvive(time)
    if integrationMode == "steam" then
        steam_achievements.onLaserGameSurvive(time)
    end
end

function steam_integration.onDodgeGameScore(score)
    if integrationMode == "steam" then
        steam_achievements.onDodgeGameScore(score)
    end
end

function steam_integration.onHostGame()
    if integrationMode == "steam" then
        steam_achievements.onHostGame()
    end
end

function steam_integration.onMeetPlayer()
    if integrationMode == "steam" then
        steam_achievements.onMeetPlayer()
    end
end

-- Debug information
function steam_integration.getDebugInfo()
    return {
        initialized = initialized,
        mode = integrationMode,
        steamAvailable = steam_integration.isSteamAvailable(),
        userName = steam_integration.getUserName(),
        userID = steam_integration.getUserID(),
        lobbyMembers = steam_integration.getLobbyMembers(),
        isLobbyOwner = steam_integration.isLobbyOwner()
    }
end

return steam_integration

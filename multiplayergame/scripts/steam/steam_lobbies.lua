-- Steam Lobby Management Module
-- Handles lobby creation, joining, and management

local steam_lobbies = {}

-- Lobby state
local currentLobby = nil
local lobbyMembers = {}
local lobbySettings = {
    maxPlayers = 4,
    gameMode = "party",
    isPrivate = false
}

-- Initialize lobby system
function steam_lobbies.init()
    print("[Steam Lobbies] Initializing lobby system")
    return true
end

-- Create a new lobby
function steam_lobbies.createLobby(maxPlayers, isPrivate)
    local success, luasteam = pcall(require, "luasteam")
    if not success then
        print("[Steam Lobbies] luasteam not available")
        return false
    end
    
    if not luasteam.matchmaking then
        print("[Steam Lobbies] Matchmaking not available")
        return false
    end
    
    lobbySettings.maxPlayers = maxPlayers or 4
    lobbySettings.isPrivate = isPrivate or false
    
    local lobbyType = isPrivate and luasteam.matchmaking.LobbyType.Private or luasteam.matchmaking.LobbyType.Public
    
    luasteam.matchmaking.createLobby(lobbyType, lobbySettings.maxPlayers)
    print("[Steam Lobbies] Creating lobby (Max players: " .. lobbySettings.maxPlayers .. ", Private: " .. tostring(isPrivate) .. ")")
    
    return true
end

-- Join a lobby by Steam ID
function steam_lobbies.joinLobby(lobbySteamID)
    local success, luasteam = pcall(require, "luasteam")
    if not success then
        print("[Steam Lobbies] luasteam not available")
        return false
    end
    
    if not luasteam.matchmaking then
        print("[Steam Lobbies] Matchmaking not available")
        return false
    end
    
    luasteam.matchmaking.joinLobby(lobbySteamID)
    print("[Steam Lobbies] Joining lobby: " .. lobbySteamID)
    
    return true
end

-- Leave current lobby
function steam_lobbies.leaveLobby()
    if currentLobby then
        local success, luasteam = pcall(require, "luasteam")
        if success and luasteam.matchmaking then
            luasteam.matchmaking.leaveLobby(currentLobby)
        end
        
        currentLobby = nil
        lobbyMembers = {}
        print("[Steam Lobbies] Left lobby")
    end
end

-- Get current lobby ID
function steam_lobbies.getCurrentLobby()
    return currentLobby
end

-- Get lobby members
function steam_lobbies.getMembers()
    return lobbyMembers
end

-- Get lobby member count
function steam_lobbies.getMemberCount()
    return #lobbyMembers
end

-- Check if lobby is full
function steam_lobbies.isLobbyFull()
    return #lobbyMembers >= lobbySettings.maxPlayers
end

-- Check if user is lobby owner
function steam_lobbies.isLobbyOwner()
    if not currentLobby then
        return false
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.matchmaking then
        local ownerID = luasteam.matchmaking.getLobbyOwner(currentLobby)
        local myID = luasteam.user.getSteamID()
        return ownerID == myID
    end
    
    return false
end

-- Set lobby data
function steam_lobbies.setLobbyData(key, value)
    if not currentLobby then
        return false
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.matchmaking then
        luasteam.matchmaking.setLobbyData(currentLobby, key, value)
        return true
    end
    
    return false
end

-- Get lobby data
function steam_lobbies.getLobbyData(key)
    if not currentLobby then
        return nil
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.matchmaking then
        return luasteam.matchmaking.getLobbyData(currentLobby, key)
    end
    
    return nil
end

-- Send lobby message
function steam_lobbies.sendMessage(message)
    if not currentLobby then
        return false
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.matchmaking then
        luasteam.matchmaking.sendLobbyChatMsg(currentLobby, message)
        return true
    end
    
    return false
end

-- Handle lobby events
function steam_lobbies.handleEvent(event)
    if event.type == "LobbyCreated" then
        currentLobby = event.lobby
        print("[Steam Lobbies] Lobby created: " .. currentLobby)
        
        -- Set initial lobby data
        steam_lobbies.setLobbyData("game_mode", lobbySettings.gameMode)
        steam_lobbies.setLobbyData("max_players", tostring(lobbySettings.maxPlayers))
        
    elseif event.type == "LobbyEntered" then
        currentLobby = event.lobby
        print("[Steam Lobbies] Entered lobby: " .. currentLobby)
        
        -- Update lobby members
        steam_lobbies.updateMembers()
        
    elseif event.type == "LobbyChatUpdate" then
        print("[Steam Lobbies] Lobby member update")
        steam_lobbies.updateMembers()
        
    elseif event.type == "LobbyChatMsg" then
        print("[Steam Lobbies] Received message from " .. event.sender .. ": " .. event.message)
        -- Handle lobby chat messages here
        
    elseif event.type == "LobbyDataUpdate" then
        print("[Steam Lobbies] Lobby data updated")
        
    elseif event.type == "LobbyGameCreated" then
        print("[Steam Lobbies] Lobby game created")
        
    elseif event.type == "LobbyKicked" then
        print("[Steam Lobbies] Kicked from lobby")
        currentLobby = nil
        lobbyMembers = {}
        
    elseif event.type == "LobbyInvite" then
        print("[Steam Lobbies] Received lobby invite from " .. event.sender)
        -- Handle lobby invite here
    end
end

-- Update lobby members list
function steam_lobbies.updateMembers()
    if not currentLobby then
        return
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.matchmaking then
        local members = luasteam.matchmaking.getLobbyMembers(currentLobby)
        lobbyMembers = {}
        
        for _, memberID in ipairs(members) do
            local memberName = luasteam.friends.getPersonaName(memberID)
            table.insert(lobbyMembers, {
                id = memberID,
                name = memberName
            })
        end
        
        print("[Steam Lobbies] Updated members list (" .. #lobbyMembers .. " members)")
    end
end

-- Find lobbies
function steam_lobbies.findLobbies()
    local success, luasteam = pcall(require, "luasteam")
    if not success then
        return false
    end
    
    if not luasteam.matchmaking then
        return false
    end
    
    -- Add search criteria
    luasteam.matchmaking.addRequestLobbyListStringFilter("game_mode", lobbySettings.gameMode, luasteam.matchmaking.LobbyComparison.Equal)
    luasteam.matchmaking.addRequestLobbyListNumericalFilter("max_players", lobbySettings.maxPlayers, luasteam.matchmaking.LobbyComparison.Equal)
    
    -- Request lobby list
    luasteam.matchmaking.requestLobbyList()
    print("[Steam Lobbies] Searching for lobbies...")
    
    return true
end

-- Get lobby search results
function steam_lobbies.getSearchResults()
    local success, luasteam = pcall(require, "luasteam")
    if not success then
        return {}
    end
    
    if not luasteam.matchmaking then
        return {}
    end
    
    local results = {}
    local count = luasteam.matchmaking.getLobbyListCount()
    
    for i = 0, count - 1 do
        local lobbyID = luasteam.matchmaking.getLobbyByIndex(i)
        if lobbyID then
            local memberCount = luasteam.matchmaking.getLobbyMemberCount(lobbyID)
            local maxMembers = tonumber(luasteam.matchmaking.getLobbyData(lobbyID, "max_players")) or 4
            local gameMode = luasteam.matchmaking.getLobbyData(lobbyID, "game_mode") or "party"
            
            table.insert(results, {
                id = lobbyID,
                memberCount = memberCount,
                maxMembers = maxMembers,
                gameMode = gameMode,
                isFull = memberCount >= maxMembers
            })
        end
    end
    
    return results
end

-- Update lobby system (call in love.update)
function steam_lobbies.update()
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.matchmaking then
        local event = luasteam.matchmaking.getLobbyEvent()
        if event then
            steam_lobbies.handleEvent(event)
        end
    end
end

-- Shutdown lobby system
function steam_lobbies.shutdown()
    steam_lobbies.leaveLobby()
    print("[Steam Lobbies] Shutdown complete")
end

return steam_lobbies

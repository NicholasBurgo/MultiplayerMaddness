-- Steam Networking Module
-- Replaces ENet with Steam's networking system

local steam_networking = {}

-- Networking state
local networkingInitialized = false
local lobbyID = nil
local lobbyMembers = {}
local peerConnections = {}
local messageHandlers = {}

-- Initialize Steam networking
function steam_networking.init()
    local success, luasteam = pcall(require, "luasteam")
    if not success then
        print("[Steam Networking] luasteam not available")
        return false
    end
    
    -- Initialize Steam networking
    if luasteam.networkingSockets then
        networkingInitialized = true
        print("[Steam Networking] Successfully initialized")
        return true
    else
        print("[Steam Networking] Failed to initialize")
        return false
    end
end

-- Create a lobby
function steam_networking.createLobby(maxPlayers)
    if not networkingInitialized then
        print("[Steam Networking] Not initialized")
        return false
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.matchmaking then
        -- Create lobby with Steam matchmaking
        luasteam.matchmaking.createLobby(luasteam.matchmaking.LobbyType.Public, maxPlayers or 4)
        print("[Steam Networking] Creating lobby...")
        return true
    end
    
    return false
end

-- Join a lobby by ID
function steam_networking.joinLobby(lobbyID)
    if not networkingInitialized then
        print("[Steam Networking] Not initialized")
        return false
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.matchmaking then
        luasteam.matchmaking.joinLobby(lobbyID)
        print("[Steam Networking] Joining lobby: " .. lobbyID)
        return true
    end
    
    return false
end

-- Send message to all lobby members
function steam_networking.sendToLobby(message)
    if not networkingInitialized or not lobbyID then
        return false
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.matchmaking then
        luasteam.matchmaking.sendLobbyChatMsg(lobbyID, message)
        return true
    end
    
    return false
end

-- Send message to specific peer
function steam_networking.sendToPeer(peerID, message)
    if not networkingInitialized then
        return false
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.networkingSockets then
        -- Use Steam networking sockets for peer-to-peer communication
        luasteam.networkingSockets.sendMessageToConnection(peerID, message)
        return true
    end
    
    return false
end

-- Register message handler
function steam_networking.registerHandler(messageType, handler)
    messageHandlers[messageType] = handler
end

-- Handle incoming messages
function steam_networking.handleMessage(message, senderID)
    print("[Steam Networking] Received message: " .. message .. " from " .. (senderID or "unknown"))
    
    -- Parse message type
    local messageType = message:match("^([^,]+)")
    if messageType and messageHandlers[messageType] then
        messageHandlers[messageType](message, senderID)
    end
end

-- Update networking (call in love.update)
function steam_networking.update()
    if not networkingInitialized then
        return
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if success then
        -- Handle lobby events
        if luasteam.matchmaking then
            local lobbyEvent = luasteam.matchmaking.getLobbyEvent()
            if lobbyEvent then
                steam_networking.handleLobbyEvent(lobbyEvent)
            end
        end
        
        -- Handle networking socket events
        if luasteam.networkingSockets then
            local socketEvent = luasteam.networkingSockets.getNextEvent()
            if socketEvent then
                steam_networking.handleSocketEvent(socketEvent)
            end
        end
    end
end

-- Handle lobby events
function steam_networking.handleLobbyEvent(event)
    if event.type == "LobbyCreated" then
        lobbyID = event.lobby
        print("[Steam Networking] Lobby created: " .. lobbyID)
    elseif event.type == "LobbyEntered" then
        lobbyID = event.lobby
        print("[Steam Networking] Entered lobby: " .. lobbyID)
    elseif event.type == "LobbyChatUpdate" then
        -- Handle lobby member changes
        print("[Steam Networking] Lobby member update")
    elseif event.type == "LobbyChatMsg" then
        -- Handle lobby chat messages
        steam_networking.handleMessage(event.message, event.sender)
    end
end

-- Handle socket events
function steam_networking.handleSocketEvent(event)
    if event.type == "Connected" then
        print("[Steam Networking] Peer connected: " .. event.peer)
        peerConnections[event.peer] = true
    elseif event.type == "Disconnected" then
        print("[Steam Networking] Peer disconnected: " .. event.peer)
        peerConnections[event.peer] = nil
    elseif event.type == "Message" then
        steam_networking.handleMessage(event.data, event.peer)
    end
end

-- Get lobby members
function steam_networking.getLobbyMembers()
    if not networkingInitialized or not lobbyID then
        return {}
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.matchmaking then
        return luasteam.matchmaking.getLobbyMembers(lobbyID)
    end
    
    return {}
end

-- Get lobby ID
function steam_networking.getLobbyID()
    return lobbyID
end

-- Check if in lobby
function steam_networking.isInLobby()
    return lobbyID ~= nil
end

-- Leave lobby
function steam_networking.leaveLobby()
    if lobbyID then
        local success, luasteam = pcall(require, "luasteam")
        if success and luasteam.matchmaking then
            luasteam.matchmaking.leaveLobby(lobbyID)
        end
        lobbyID = nil
        lobbyMembers = {}
        print("[Steam Networking] Left lobby")
    end
end

-- Shutdown networking
function steam_networking.shutdown()
    steam_networking.leaveLobby()
    networkingInitialized = false
    print("[Steam Networking] Shutdown complete")
end

return steam_networking

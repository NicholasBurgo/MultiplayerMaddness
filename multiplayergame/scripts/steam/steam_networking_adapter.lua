-- Steam Networking Adapter
-- Provides a unified interface between ENet and Steam networking

local steam_networking_adapter = {}

-- Networking mode: "enet" or "steam"
local networkingMode = "enet"
local steamNetworking = nil
local enetHost = nil
local enetServer = nil
local enetClients = {}
local messageHandlers = {}

-- Initialize networking adapter
function steam_networking_adapter.init()
    print("[Networking Adapter] Initializing networking adapter...")
    
    -- Try to initialize Steam networking first
    local success, steam_integration = pcall(require, "scripts.steam.steam_integration")
    if success and steam_integration.isSteamAvailable() then
        networkingMode = "steam"
        steamNetworking = steam_integration
        print("[Networking Adapter] Using Steam networking")
        return true
    else
        -- Fallback to ENet
        networkingMode = "enet"
        local success, enet = pcall(require, "enet")
        if success then
            print("[Networking Adapter] Using ENet networking")
            return true
        else
            print("[Networking Adapter] No networking available")
            return false
        end
    end
end

-- Register message handler
function steam_networking_adapter.registerHandler(messageType, handler)
    messageHandlers[messageType] = handler
end

-- Send message to all clients (host only)
function steam_networking_adapter.sendToAll(message)
    if networkingMode == "steam" then
        return steamNetworking.sendMessage(message)
    else
        -- ENet implementation
        for _, client in ipairs(enetClients) do
            safeSend(client, message)
        end
        return true
    end
end

-- Send message to specific peer
function steam_networking_adapter.sendToPeer(peerId, message)
    if networkingMode == "steam" then
        return steamNetworking.sendToPeer(peerId, message)
    else
        -- ENet implementation
        if enetClients[peerId] then
            return safeSend(enetClients[peerId], message)
        end
        return false
    end
end

-- Create server
function steam_networking_adapter.createServer(maxPlayers)
    if networkingMode == "steam" then
        return steamNetworking.createLobby(maxPlayers, false)
    else
        -- ENet server creation
        return startServer()
    end
end

-- Join server
function steam_networking_adapter.joinServer(address, port)
    if networkingMode == "steam" then
        -- Steam uses lobby IDs, not IP addresses
        return steamNetworking.joinLobby(address)
    else
        -- ENet client connection
        return startNetworking()
    end
end

-- Leave server/lobby
function steam_networking_adapter.leaveServer()
    if networkingMode == "steam" then
        steamNetworking.leaveLobby()
    else
        -- ENet cleanup
        if enetHost then
            enetHost:destroy()
            enetHost = nil
        end
        if enetServer then
            enetServer:disconnect()
            enetServer = nil
        end
    end
end

-- Get connected players
function steam_networking_adapter.getPlayers()
    if networkingMode == "steam" then
        return steamNetworking.getLobbyMembers()
    else
        -- ENet players
        return players or {}
    end
end

-- Check if hosting
function steam_networking_adapter.isHosting()
    if networkingMode == "steam" then
        return steamNetworking.isLobbyOwner()
    else
        return gameState == "hosting"
    end
end

-- Check if connected
function steam_networking_adapter.isConnected()
    if networkingMode == "steam" then
        return steamNetworking.getLobbyMembers() and #steamNetworking.getLobbyMembers() > 0
    else
        return connected
    end
end

-- Update networking (call in love.update)
function steam_networking_adapter.update()
    if networkingMode == "steam" then
        steamNetworking.update()
    else
        -- ENet update
        if gameState == "hosting" then
            updateServer()
        elseif gameState == "playing" or gameState == "connecting" then
            updateClient()
        end
    end
end

-- Handle incoming messages
function steam_networking_adapter.handleMessage(message, senderId)
    print("[Networking Adapter] Received message: " .. message .. " from " .. (senderId or "unknown"))
    
    -- Parse message type
    local messageType = message:match("^([^,]+)")
    if messageType and messageHandlers[messageType] then
        messageHandlers[messageType](message, senderId)
    end
end

-- Get networking mode
function steam_networking_adapter.getMode()
    return networkingMode
end

-- Check if Steam networking is available
function steam_networking_adapter.isSteamAvailable()
    return networkingMode == "steam"
end

-- Shutdown networking
function steam_networking_adapter.shutdown()
    steam_networking_adapter.leaveServer()
    print("[Networking Adapter] Shutdown complete")
end

return steam_networking_adapter

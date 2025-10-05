local log = require("src.core.logger")
local protocol = require("src.net.protocol")
local enet = require("enet")

local M = {}
local role, host, serverPeer, peers = nil, nil, nil, {}
local peerToId = {}
local nextClientId = 1

function M.start(r, opts)
    role = r
    opts = opts or {}
    
    if role == "server" then
        log.info("net.lan", "Starting server...")
        
        -- Try different ports if the first one fails
        local ports = {opts.port or 12345, 12346, 12347, 12348}
        local success = false
        
        for i, port in ipairs(ports) do
            log.info("net.lan", string.format("Trying port %d", port))
            host = enet.host_create("0.0.0.0:" .. tostring(port))
            if host then
                log.info("net.lan", string.format("Successfully started on port %d", port))
                success = true
                break
            else
                log.warn("net.lan", string.format("Port %d failed", port))
            end
        end
        
        if not success then
            log.error("net.lan", "Failed to create server on any port")
            return false
        end
        
        peers = {}
        peerToId = {}
        nextClientId = 1
        log.info("net.lan", "Server started successfully")
        return true
        
    elseif role == "client" then
        log.info("net.lan", "Starting client...")
        host = enet.host_create()
        if not host then
            log.error("net.lan", "Failed to create client host")
            return false
        end
        
        local address = (opts.host or "127.0.0.1") .. ":" .. tostring(opts.port or 12345)
        log.info("net.lan", "Connecting to " .. address)
        serverPeer = host:connect(address)
        if not serverPeer then
            log.error("net.lan", "Failed to connect to server at " .. address)
            return false
        end
        
        log.info("net.lan", "Connection attempt sent")
        return true
    end
    
    return false
end

function M.stop()
    if host then
        if role == "server" and peers then
            for _, peer in pairs(peers) do
                if peer then peer:disconnect() end
            end
        elseif role == "client" and serverPeer then
            serverPeer:disconnect()
        end
        host = nil
    end
    peers = {}
    peerToId = {}
    serverPeer = nil
    role = nil
    log.info("net.lan", "Stopped")
end

function M.send(channel, msg, to)
    if not host then 
        log.warn("net.lan", "Cannot send: not connected")
        return 
    end
    
    local payload = protocol.encode(channel, msg)
    
    if role == "server" then
        if to then
            -- Send to specific client
            -- Convert to number if it's a string
            local clientId = tonumber(to) or to
            local peer = peers[clientId]
            if peer then
                local success, err = pcall(function()
                    peer:send(payload)
                end)
                if not success then
                    log.error("net.lan", "Failed to send to client: " .. tostring(err))
                end
            else
                log.warn("net.lan", "No peer found for client ID: " .. tostring(to) .. " (converted to " .. tostring(clientId) .. ")")
            end
        else
            -- Broadcast to all clients
            for _, peer in pairs(peers) do
                local success, err = pcall(function()
                    peer:send(payload)
                end)
                if not success then
                    log.error("net.lan", "Failed to send to client: " .. tostring(err))
                end
            end
        end
    elseif role == "client" then
        if serverPeer then
            local success, err = pcall(function()
                serverPeer:send(payload)
            end)
            if not success then
                log.error("net.lan", "Failed to send to server: " .. tostring(err))
            end
        end
    end
end

function M.poll(handler)
    if not host then return end
    
    local success, err = pcall(function()
        local event = host:service(0)
        while event do
            if event.type == "connect" then
                if role == "server" then
                    local clientId = nextClientId
                    nextClientId = nextClientId + 1
                    peers[clientId] = event.peer
                    peerToId[event.peer] = clientId
                    log.info("net.lan", "Client connected: " .. tostring(clientId))
                    handler({ type="connect", from=tostring(clientId) })
                elseif role == "client" then
                    log.info("net.lan", "Connected to server")
                    handler({ type="connect" })
                end
                
            elseif event.type == "receive" then
                local kind, data, ver = protocol.decode(event.data)
                if kind then
                    local fromId = role == "server" and tostring(peerToId[event.peer]) or "server"
                    handler({ type="message", from=fromId, channel=kind, msg=data })
                end
                
            elseif event.type == "disconnect" then
                if role == "server" then
                    local clientId = peerToId[event.peer]
                    if clientId then
                        log.info("net.lan", "Client disconnected: " .. tostring(clientId))
                        handler({ type="disconnect", from=tostring(clientId) })
                        peers[clientId] = nil
                        peerToId[event.peer] = nil
                    end
                elseif role == "client" then
                    log.info("net.lan", "Disconnected from server")
                    handler({ type="disconnect" })
                end
            end
            
            event = host:service(0)
        end
    end)
    
    if not success then
        log.error("net.lan", "Error polling: " .. tostring(err))
        if role == "client" then
            handler({ type="disconnect" })
        end
    end
end

return M

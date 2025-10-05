local events = require("src.core.events")
local log    = require("src.core.logger")
local party  = require("src.game.systems.partymode")
local tabMenu = require("src.game.systems.tabmenu")
local pauseMenu = require("src.game.systems.pausemenu")

local app = { 
    scenes = {}, 
    active = nil, 
    transport = nil,
    protocol = nil,
    isHost = false,
    players = {},
    connected = false,
    localPlayerId = 0,  -- Track our own player ID
    nextPlayerId = 1,   -- For host to assign new player IDs
    joinRequestSent = false  -- Prevent multiple JOIN messages
}

local function setScene(name, args)
    log.info("app", "Switching to scene: " .. name)
    app.active = assert(app.scenes[name], "Unknown scene: "..tostring(name))
    if app.active.load then app.active.load(args) end
end

function app.load(cfg)
    app.transport = assert(cfg.transport, "transport required")
    app.protocol  = assert(cfg.protocol, "protocol required")
    
    log.info("app", "Initializing application")
    
    -- Intent routing to transport
    events.on("intent:host", function(o) 
        log.info("app", "Host intent received")
        local success = app.transport.start("server", o or {})
        if success then
            app.isHost = true
            app.connected = true
            
        -- Load player data for host
        local savefile = require("src.game.systems.savefile")
        local savedData = savefile.loadPlayerData()
        
        -- Host always has ID 0
        app.localPlayerId = 0
        app.nextPlayerId = 1
            
        app.players = {
            [0] = {
                id=0,
                name=savedData.name or "Host",
                color=savedData.color or {1, 0, 0},
                facePoints=savedData.facePoints,
                x=100,
                y=100,
                totalScore=0
            }
        }
        setScene("lobby", {players=app.players, isHost=true, localPlayerId=0})
        else
            log.error("app", "Failed to start server")
        end
    end)
    
    events.on("intent:show_connecting", function()
        log.info("app", "Show connecting screen")
        setScene("connecting")
    end)
    
    events.on("intent:back_to_menu", function()
        log.info("app", "Back to menu")
        setScene("menu")
    end)
    
    events.on("intent:join", function(o) 
        log.info("app", "Join intent received with host: " .. tostring(o and o.host or "nil"))
        print("[App] Join intent received!")
        print("[App] Host: " .. tostring(o and o.host or "nil"))
        print("[App] Port: " .. tostring(o and o.port or "nil"))
        
        -- Reset join request flag for new connection attempt
        app.joinRequestSent = false
        
        local success = app.transport.start("client", o or {})
        print("[App] Transport start result: " .. tostring(success))
        
        if success then
            app.isHost = false
            -- Load player data for client
            local savefile = require("src.game.systems.savefile")
            local savedData = savefile.loadPlayerData()
            
            -- Client will get assigned ID from host
            app.localPlayerId = nil  -- Will be set when we receive JOIN_ACCEPTED
            app.players = {}  -- Will be populated by host
            
            log.info("app", "Client started, waiting for connection...")
            print("[App] Client started, waiting for connection...")
            -- Will switch to lobby once connected and ID is assigned
        else
            log.error("app", "Failed to connect")
            print("[App] Failed to start client transport")
            -- Go back to connecting screen to try again
            setScene("connecting")
        end
    end)
    
    events.on("intent:start_match", function(opts) 
        log.info("app", "Start match intent")
        if app.isHost then
            -- Broadcast match start to all clients
            app.transport.send("START_MATCH", opts or {})
            setScene("match")
        end
    end)
    
    events.on("intent:start_game", function(opts)
        local mode = opts and opts.mode or "jump"
        local isPartyMode = opts and opts.partyMode or false
        
        log.info("app", "Start game mode: " .. mode .. (isPartyMode and " (Party Mode)" or ""))
        
        -- Start party mode if requested
        if isPartyMode then
            mode = party.start()
            log.info("app", "Party mode activated, starting with: " .. mode)
        end
        
        -- Generate seed for deterministic gameplay
        local seed = nil
        if app.isHost then
            seed = os.time() + love.timer.getTime() * 10000
            log.info("app", "Host generated seed: " .. seed)
            -- Broadcast game start to all clients with seed
            app.transport.send("START_GAME", {
                mode = mode, 
                partyMode = isPartyMode,
                seed = seed
            })
        end
        
        -- Switch to game mode scene with full player data including facePoints and seed
        if app.scenes[mode] then
            setScene(mode, {
                players = app.players,
                localPlayerId = app.localPlayerId,
                isHost = app.isHost,
                partyMode = isPartyMode or party.isActive(),
                seed = seed
            })
        else
            log.error("app", "Unknown game mode: " .. mode)
        end
    end)
    
    events.on("intent:leave_lobby", function()
        log.info("app", "Leave lobby intent")
        party.stop()  -- Stop party mode if active
        app.transport.stop()
        app.isHost = false
        app.connected = false
        app.players = {}
        app.joinRequestSent = false  -- Reset for future connection attempts
        setScene("menu")
    end)
    
    -- Handle party mode game transitions
    events.on("party:next_game", function(opts)
        local mode = opts and opts.mode or "jump"
        log.info("app", "Party mode transitioning to: " .. mode)
        
        -- Generate seed for deterministic gameplay
        local seed = nil
        if app.isHost then
            seed = os.time() + love.timer.getTime() * 10000
            log.info("app", "Host generated seed for next game: " .. seed)
            -- Broadcast next game to clients with seed
            app.transport.send("START_GAME", {
                mode = mode, 
                partyMode = true,
                seed = seed
            })
        end
        
        -- Switch to next game
        if app.scenes[mode] then
            setScene(mode, {
                players = app.players,
                localPlayerId = app.localPlayerId,
                isHost = app.isHost,
                partyMode = true,
                seed = seed
            })
        end
    end)
    
    events.on("player:move", function(data)
        -- Broadcast player movement to all clients
        if app.transport and app.connected then
            app.transport.send("PLAYER_MOVE", {
                id = data.id,
                x = data.x,
                y = data.y
            })
        end
    end)
    
    -- Game-specific position sync events
    events.on("player:jump_position", function(data)
        if data.id and data.x and data.y then
            if app.players[data.id] then
                app.players[data.id].jumpX = data.x
                app.players[data.id].jumpY = data.y
                if data.color then app.players[data.id].color = data.color end
            end
            if app.connected then
                app.transport.send("JUMP_POSITION", data)
            end
        end
    end)
    
    events.on("player:jump_score", function(data)
        if data.id and data.score then
            if app.players[data.id] then
                app.players[data.id].jumpScore = data.score
            end
            if app.connected then
                app.transport.send("JUMP_SCORE", data)
            end
        end
    end)
    
    events.on("player:laser_position", function(data)
        if data.id and data.x and data.y then
            if app.players[data.id] then
                app.players[data.id].laserX = data.x
                app.players[data.id].laserY = data.y
                if data.color then app.players[data.id].color = data.color end
            end
            if app.connected then
                app.transport.send("LASER_POSITION", data)
            end
        end
    end)
    
    events.on("player:battle_position", function(data)
        if data.id and data.x and data.y then
            if app.players[data.id] then
                app.players[data.id].battleX = data.x
                app.players[data.id].battleY = data.y
                if data.color then app.players[data.id].color = data.color end
            end
            if app.connected then
                app.transport.send("BATTLE_POSITION", data)
            end
        end
    end)
    
    events.on("player:dodge_position", function(data)
        if data.id and data.x and data.y then
            if app.players[data.id] then
                app.players[data.id].dodgeX = data.x
                app.players[data.id].dodgeY = data.y
                if data.color then app.players[data.id].color = data.color end
            end
            if app.connected then
                app.transport.send("DODGE_POSITION", data)
            end
        end
    end)
    
    events.on("player:praise_position", function(data)
        if data.id and data.x and data.y then
            if app.players[data.id] then
                app.players[data.id].praiseX = data.x
                app.players[data.id].praiseY = data.y
                if data.color then app.players[data.id].color = data.color end
            end
            if app.connected then
                app.transport.send("PRAISE_POSITION", data)
            end
        end
    end)
    
    events.on("player:score_update", function(data)
        if data.id and data.totalScore ~= nil then
            if app.players[data.id] then
                app.players[data.id].totalScore = data.totalScore
            end
            if app.connected then
                app.transport.send("PLAYER_SCORE", data)
            end
        end
    end)
    
    events.on("lobby:level_vote", function(data)
        if app.connected then
            app.transport.send("LEVEL_VOTE", data)
        end
    end)
    
    events.on("lobby:party_vote", function(data)
        if app.connected then
            app.transport.send("PARTY_MODE_VOTE", data)
        end
    end)
    
    events.on("intent:customize", function()
        log.info("app", "Character customization intent")
        setScene("customization", {returnTo = "menu"})
    end)
    
    events.on("intent:return_from_customization", function(opts)
        log.info("app", "Returning from customization")
        setScene(opts.returnTo or "menu")
    end)
    
    events.on("intent:quit_to_lobby", function()
        log.info("app", "Quit to lobby intent")
        party.stop()  -- Stop party mode if active
        setScene("lobby", {players=app.players, isHost=app.isHost, localPlayerId=app.localPlayerId})
    end)
    
    events.on("match:countdown_complete", function()
        log.info("app", "Match countdown complete")
        -- This is where you'd transition to actual gameplay
    end)
    
    -- Load basic scenes
    app.scenes = {
        menu  = require("src.game.scenes.menu"),
        lobby = require("src.game.scenes.lobby"),
        match = require("src.game.scenes.match"),
        customization = require("src.game.scenes.customization"),
        connecting = require("src.game.scenes.connecting"),
    }
    
    -- Load game mode scenes
    local modes = require("src.game.scenes.modes.index")
    for name, mode in pairs(modes) do
        app.scenes[name] = mode
        log.info("app", "Registered game mode: " .. name)
    end
    
    setScene(cfg.defaultScene or "menu")
end

function app.update(dt)
    -- Update pause menu
    pauseMenu.update(dt)
    
    -- Poll transport for network events
    if app.transport then 
        app.transport.poll(function(ev)
            if ev.type == "connect" then
                if app.isHost then
                    log.info("app", "Client connected: " .. tostring(ev.from))
                    print("[App] Host: Client connected: " .. tostring(ev.from))
                    
                    -- Check if this client already has a player (prevent duplicate connections)
                    local existingPlayerId = nil
                    for playerId, player in pairs(app.players) do
                        if player.connectionId == ev.from then
                            existingPlayerId = playerId
                            break
                        end
                    end
                    
                    if existingPlayerId then
                        print("[App] Client " .. tostring(ev.from) .. " already has player ID " .. tostring(existingPlayerId) .. ", resending player data")
                        -- Resend player data to existing player
                        app.transport.send("YOUR_ID", {playerId = existingPlayerId}, ev.from)
                        app.transport.send("STATE", {players = app.players}, ev.from)
                        return
                    end
                    
                    -- Assign unique player ID immediately (legacy approach)
                    local newPlayerId = app.nextPlayerId
                    app.nextPlayerId = app.nextPlayerId + 1
                    
                    -- Load saved player data for the new client
                    local savefile = require("src.game.systems.savefile")
                    local savedData = savefile.loadPlayerData()
                    
                    -- Handle duplicate names by adding suffix
                    local playerName = savedData.name or "Player"
                    local finalName = playerName
                    local suffix = 2
                    
                    -- Check for duplicate names and add suffix if needed
                    while true do
                        local nameExists = false
                        for _, existingPlayer in pairs(app.players) do
                            if existingPlayer.name == finalName then
                                nameExists = true
                                break
                            end
                        end
                        if not nameExists then
                            break
                        end
                        finalName = playerName .. "-" .. suffix
                        suffix = suffix + 1
                    end
                    
                    if finalName ~= playerName then
                        print("[App] Duplicate name detected, using: " .. finalName)
                    end
                    
                    -- Create player immediately (legacy approach)
                    app.players[newPlayerId] = {
                        id = newPlayerId,
                        name = finalName,
                        color = savedData.color or {math.random(), math.random(), math.random()},
                        facePoints = savedData.facePoints,
                        x = 200 + newPlayerId * 50,
                        y = 200 + newPlayerId * 30,
                        totalScore = 0,
                        connectionId = ev.from
                    }
                    
                    print("[App] Created player " .. finalName .. " with ID: " .. tostring(newPlayerId))
                    print("[App] Sending YOUR_ID to client " .. tostring(ev.from) .. " with player ID: " .. tostring(newPlayerId))
                    
                    -- Send player ID immediately (legacy approach)
                    app.transport.send("YOUR_ID", {playerId = newPlayerId}, ev.from)
                    
                    print("[App] Sending STATE to client " .. tostring(ev.from))
                    -- Send current state to the new client
                    app.transport.send("STATE", {players = app.players}, ev.from)
                    print("[App] Messages sent to client")
                    
                    -- Broadcast updated player list to all other clients
                    for _, player in pairs(app.players) do
                        if player.connectionId and player.connectionId ~= ev.from then
                            app.transport.send("NEW_PLAYER", {
                                id = newPlayerId,
                                name = finalName,
                                color = savedData.color or {math.random(), math.random(), math.random()},
                                facePoints = savedData.facePoints,
                                x = 200 + newPlayerId * 50,
                                y = 200 + newPlayerId * 30,
                                totalScore = 0
                            }, player.connectionId)
                        end
                    end
                    
                else
                    log.info("app", "Connected to server")
                    print("[App] Client: Connected to server! Transitioning to lobby...")
                    print("[App] Current scene when connected: " .. tostring(app.active and app.active.name or "nil"))
                    app.connected = true
                    
                    -- Transition to lobby immediately upon connection (like legacy code does)
                    -- Player ID and state will be populated by incoming messages
                    setScene("lobby", {players=app.players, isHost=false, localPlayerId=app.localPlayerId})
                end
                
            elseif ev.type == "disconnect" then
                if app.isHost then
                    log.info("app", "Client disconnected: " .. tostring(ev.from))
                    print("[App] Client " .. tostring(ev.from) .. " disconnected")
                    -- Find and remove player by connection ID
                    local removedPlayer = nil
                    for playerId, player in pairs(app.players) do
                        if player.connectionId == ev.from or tostring(playerId) == ev.from or tostring(player.id) == ev.from then
                            removedPlayer = player
                            app.players[playerId] = nil
                            log.info("app", "Removed player with ID: " .. tostring(playerId) .. " (" .. tostring(player.name) .. ")")
                            print("[App] Removed player: " .. tostring(player.name) .. " (ID: " .. tostring(playerId) .. ")")
                            break
                        end
                    end
                    -- Broadcast updated player list
                    app.transport.send("STATE", {players=app.players})
                else
                    log.info("app", "Disconnected from server")
                    app.connected = false
                    app.localPlayerId = nil
                    setScene("menu")
                end
                
            elseif ev.type == "message" then
                local channel = ev.channel
                local msg = ev.msg
                local from = ev.from
                
                print("[App] Received message - Channel: " .. tostring(channel) .. ", From: " .. tostring(from))
                
                if channel == "PING" then
                    log.info("app", "Received PING from " .. tostring(from))
                    -- Respond with PONG
                    if app.isHost then
                        app.transport.send("PONG", {timestamp=msg.timestamp}, from)
                    end
                    
                elseif channel == "PONG" then
                    log.info("app", "Received PONG from " .. tostring(from))
                    
                elseif channel == "STATE" then
                    log.info("app", "Received STATE update")
                    if msg.players then
                        app.players = msg.players
                        local playerCount = 0
                        for _ in pairs(msg.players) do playerCount = playerCount + 1 end
                        print("[App] STATE received with " .. playerCount .. " players")
                        print("[App] Current scene: " .. tostring(app.active and app.active.name or "nil"))
                        print("[App] Local player ID: " .. tostring(app.localPlayerId))
                        print("[App] Is host: " .. tostring(app.isHost))
                        
                        -- If we're a client and we have a player ID but haven't switched to lobby yet, do it now
                        if not app.isHost and app.localPlayerId then
                            local currentScene = app.active and app.active.name or "unknown"
                            print("[App] Checking if should transition to lobby (current scene: " .. currentScene .. ")")
                            -- Switch to lobby if we're not already there
                            if currentScene ~= "lobby" then
                                print("[App] Client received STATE and has player ID, switching to lobby...")
                                setScene("lobby", {players=app.players, isHost=false, localPlayerId=app.localPlayerId})
                            else
                                print("[App] Already in lobby, just updating players")
                            end
                        else
                            if app.isHost then
                                print("[App] Not transitioning - we are the host")
                            elseif not app.localPlayerId then
                                print("[App] Not transitioning yet - waiting for YOUR_ID message")
                            end
                        end
                        
                        -- Update lobby if active
                        if app.active and app.active.setPlayers then
                            app.active.setPlayers(app.players)
                        end
                    end
                    
                elseif channel == "START_MATCH" then
                    log.info("app", "Received START_MATCH command")
                    setScene("match")
                    
                elseif channel == "START_GAME" then
                    local mode = msg.mode or "jump"
                    local seed = msg.seed
                    local partyMode = msg.partyMode or false
                    log.info("app", "Received START_GAME command for mode: " .. mode .. " with seed: " .. tostring(seed))
                    
                    -- Start party mode on client if needed
                    if partyMode and not party.isActive() then
                        party.start()
                        log.info("app", "Client: Party mode activated")
                    end
                    
                    if app.scenes[mode] then
                        setScene(mode, {
                            players = app.players, 
                            localPlayerId = app.localPlayerId,  -- Fixed: use actual local player ID
                            seed = seed,
                            partyMode = partyMode
                        })
                    end
                    
                elseif channel == "PLAYER_MOVE" then
                    -- Update player position
                    if msg.id and msg.x and msg.y and app.players[msg.id] then
                        app.players[msg.id].x = msg.x
                        app.players[msg.id].y = msg.y
                        
                        -- Update lobby if active
                        if app.active and app.active.setPlayers then
                            app.active.setPlayers(app.players)
                        end
                    end
                    
                elseif channel == "JUMP_POSITION" then
                    if msg.id and msg.x and msg.y and app.players[msg.id] then
                        app.players[msg.id].jumpX = msg.x
                        app.players[msg.id].jumpY = msg.y
                        if msg.color then app.players[msg.id].color = msg.color end
                    end
                    
                elseif channel == "JUMP_SCORE" then
                    if msg.id and msg.score and app.players[msg.id] then
                        app.players[msg.id].jumpScore = msg.score
                    end
                    
                elseif channel == "PLAYER_SCORE" then
                    if msg.id and msg.totalScore ~= nil and app.players[msg.id] then
                        app.players[msg.id].totalScore = msg.totalScore
                        print("[App] Updated player " .. msg.id .. " total score to: " .. msg.totalScore)
                    end
                    
                elseif channel == "LEVEL_VOTE" then
                    -- Forward to lobby if active
                    if app.active and app.active.handleLevelVote then
                        app.active.handleLevelVote(msg)
                    end
                    
                elseif channel == "PARTY_MODE_VOTE" then
                    -- Forward to lobby if active
                    if app.active and app.active.handlePartyVote then
                        app.active.handlePartyVote(msg)
                    end
                    
                elseif channel == "LASER_POSITION" then
                    if msg.id and msg.x and msg.y and app.players[msg.id] then
                        app.players[msg.id].laserX = msg.x
                        app.players[msg.id].laserY = msg.y
                        if msg.color then app.players[msg.id].color = msg.color end
                    end
                    
                elseif channel == "BATTLE_POSITION" then
                    if msg.id and msg.x and msg.y and app.players[msg.id] then
                        app.players[msg.id].battleX = msg.x
                        app.players[msg.id].battleY = msg.y
                        if msg.color then app.players[msg.id].color = msg.color end
                    end
                    
                elseif channel == "DODGE_POSITION" then
                    if msg.id and msg.x and msg.y and app.players[msg.id] then
                        app.players[msg.id].dodgeX = msg.x
                        app.players[msg.id].dodgeY = msg.y
                        if msg.color then app.players[msg.id].color = msg.color end
                    end
                    
                elseif channel == "PRAISE_POSITION" then
                    if msg.id and msg.x and msg.y and app.players[msg.id] then
                        app.players[msg.id].praiseX = msg.x
                        app.players[msg.id].praiseY = msg.y
                        if msg.color then app.players[msg.id].color = msg.color end
                    end
                    
                elseif channel == "QUIT_VOTE_START" then
                    log.info("app", "Received quit vote start")
                    -- Update pause menu with vote info
                    if pauseMenu.isVisible() then
                        pauseMenu.quitVoteActive = true
                        pauseMenu.quitVoteTimer = msg.time or 30
                        pauseMenu.quitVotes = msg.votes or {}
                        pauseMenu.hasVotedToQuit = false
                    end
                    
                elseif channel == "QUIT_VOTE" then
                    log.info("app", "Received quit vote from " .. tostring(from))
                    -- Update vote in pause menu
                    if pauseMenu.isVisible() and msg.playerId and msg.vote ~= nil then
                        pauseMenu.quitVotes[msg.playerId] = msg.vote
                    end
                    
                elseif channel == "QUIT_VOTE_RESULT" then
                    log.info("app", "Received quit vote result: " .. tostring(msg.result))
                    if msg.result == true then
                        -- Vote passed, quit to lobby
                        pauseMenu.hide() -- Close pause menu first
                        events.emit("intent:quit_to_lobby")
                    end
                    pauseMenu.quitVoteActive = false
                    
                elseif channel == "KICK_PLAYER" then
                    log.info("app", "Received kick player command for ID: " .. tostring(msg.playerId))
                    if app.isHost and msg.playerId and msg.playerId ~= 0 then
                        -- Remove player from game
                        app.players[msg.playerId] = nil
                        -- Broadcast updated player list
                        app.transport.send("STATE", {players=app.players})
                        -- Send kick message to the player
                        app.transport.send("PLAYER_KICKED", {reason="You were kicked by the host"}, msg.playerId)
                    end
                    
                elseif channel == "PLAYER_KICKED" then
                    log.info("app", "You were kicked from the game")
                    -- Return to menu
                    app.transport.stop()
                    app.isHost = false
                    app.connected = false
                    app.players = {}
                    setScene("menu")
                    
                elseif channel == "PLAYER_DEATH" then
                    if msg.id and msg.gameMode and app.players[msg.id] then
                        if msg.gameMode == "laser" then
                            app.players[msg.id].laserDeaths = (app.players[msg.id].laserDeaths or 0) + 1
                        elseif msg.gameMode == "meteor" then
                            app.players[msg.id].meteorDeaths = (app.players[msg.id].meteorDeaths or 0) + 1
                        elseif msg.gameMode == "dodge" then
                            app.players[msg.id].dodgeDeaths = (app.players[msg.id].dodgeDeaths or 0) + 1
                        end
                    end
                    
                elseif channel == "YOUR_ID" then
                    log.info("app", "Received YOUR_ID with player ID: " .. tostring(msg.playerId))
                    print("[App] YOUR_ID received! Player ID: " .. tostring(msg.playerId))
                    app.localPlayerId = msg.playerId
                    print("[App] Client assigned player ID: " .. tostring(app.localPlayerId))
                    print("[App] Current scene: " .. tostring(app.active and app.active.name or "nil"))
                    print("[App] Is host: " .. tostring(app.isHost))
                    print("[App] Players table has data: " .. tostring(app.players and next(app.players) ~= nil))
                    
                    -- Update lobby with local player ID if we're already in lobby
                    if app.active and app.active.setLocalPlayerId then
                        print("[App] Updating lobby with local player ID")
                        app.active.setLocalPlayerId(msg.playerId)
                    end
                    
                    -- If we already have player data and we're not in lobby, transition now
                    if not app.isHost and app.players and next(app.players) then
                        local currentScene = app.active and app.active.name or "unknown"
                        print("[App] Checking if should transition to lobby (current scene: " .. currentScene .. ")")
                        if currentScene ~= "lobby" then
                            print("[App] Client has player ID and STATE, switching to lobby...")
                            setScene("lobby", {players=app.players, isHost=false, localPlayerId=app.localPlayerId})
                        else
                            print("[App] Already in lobby, just updated player ID")
                        end
                    else
                        print("[App] Not transitioning yet - waiting for STATE message")
                    end
                    
                elseif channel == "NEW_PLAYER" then
                    log.info("app", "Received NEW_PLAYER: " .. tostring(msg.name))
                    print("[App] NEW_PLAYER received: " .. tostring(msg.name) .. " (ID: " .. tostring(msg.id) .. ")")
                    if msg.id then
                        app.players[msg.id] = {
                            id = msg.id,
                            name = msg.name,
                            color = msg.color or {1, 1, 1},
                            facePoints = msg.facePoints,
                            x = msg.x or 200,
                            y = msg.y or 200,
                            totalScore = msg.totalScore or 0
                        }
                        print("[App] Added new player to local players list")
                    end
                    
                    
                else
                    log.warn("app", "Unknown message channel: " .. tostring(channel))
                end
            end
        end)
    end
    
    -- Update party mode
    party.update(dt)
    
    -- Update active scene
    if app.active and app.active.update then 
        app.active.update(dt) 
    end
end

function app.draw() 
    if app.active and app.active.draw then 
        -- Pass players table and localPlayerId to draw function
        app.active.draw(app.players, app.localPlayerId) 
    end
    
    -- Draw tab menu on top of everything if visible
    if tabMenu.isVisible() then
        tabMenu.draw(app.players)
    end
    
    -- Draw party mode timer overlay on top of everything
    if party.isActive() then
        party.drawTimer()
    end
    
    -- Draw pause menu on top of everything if visible
    if pauseMenu.isVisible() then
        pauseMenu.draw()
    end
end

function app.keypressed(k) 
    -- Handle pause menu globally (but not in menu/customization scenes or during voting)
    if k == "escape" then
        local sceneName = app.active and app.active.name or "unknown"
        if sceneName ~= "menu" and sceneName ~= "customization" then
            -- Check if lobby has active voting menus - give them priority
            if sceneName == "lobby" and app.active.hasActiveMenus and app.active.hasActiveMenus() then
                -- Let lobby handle ESC for its voting menus
                if app.active.keypressed then 
                    app.active.keypressed(k) 
                end
                return
            end
            
            -- Check if we're in voting mode - if so, disable pause menu completely
            if pauseMenu.isVisible() and pauseMenu.quitVoteActive then
                -- Only handle voting-specific keys, ignore ESC for pause menu
                if pauseMenu.keypressed(k) then
                    return -- Voting menu handled the key
                end
                -- Don't do anything else with ESC during voting
                return
            elseif pauseMenu.isVisible() then
                if pauseMenu.keypressed(k) then
                    return -- Pause menu handled the key
                end
            else
                -- Show pause menu
                pauseMenu.setContext(sceneName, app.isHost, app.players, app.localPlayerId)
                pauseMenu.setTransport(app.transport)
                pauseMenu.show()
                return
            end
        end
    end
    
    -- Handle pause menu input when visible
    if pauseMenu.isVisible() then
        if pauseMenu.keypressed(k) then
            return -- Pause menu handled the key
        end
    end
    
    -- Handle tab menu globally (but not in menu/customization scenes)
    if k == "tab" then
        local sceneName = app.active and app.active.name or "unknown"
        if sceneName ~= "menu" and sceneName ~= "customization" then
            if tabMenu.keypressed(k) then
                return -- Tab menu handled the key
            end
        end
    end
    
    if app.active and app.active.keypressed then 
        app.active.keypressed(k) 
    end
end

function app.keyreleased(k)
    -- Handle tab menu globally
    if k == "tab" then
        if tabMenu.keyreleased(k) then
            return -- Tab menu handled the key
        end
    end
    
    if app.active and app.active.keyreleased then
        app.active.keyreleased(k)
    end
end

function app.textinput(t)
    if app.active and app.active.textinput then
        app.active.textinput(t)
    end
end

function app.mousepressed(x, y, button)
    -- Handle pause menu mouse input first
    if pauseMenu.isVisible() then
        -- Convert screen coordinates to game coordinates
        local gx, gy = require("src.core.scaling").screenToGame(x, y)
        if pauseMenu.mousepressed and pauseMenu.mousepressed(gx, gy, button) then
            return -- Pause menu handled the mouse input
        end
    end
    
    if app.active and app.active.mousepressed then
        app.active.mousepressed(x, y, button)
    end
end

function app.mousereleased(x, y, button)
    if app.active and app.active.mousereleased then
        -- Convert screen coordinates to game coordinates
        local gx, gy = require("src.core.scaling").screenToGame(x, y)
        app.active.mousereleased(gx, gy, button)
    end
end

function app.mousemoved(x, y, dx, dy)
    -- Handle pause menu mouse movement first
    if pauseMenu.isVisible() then
        -- Convert screen coordinates to game coordinates
        local scaling = require("src.core.scaling")
        local gx, gy = scaling.screenToGame(x, y)
        if pauseMenu.mousemoved and pauseMenu.mousemoved(gx, gy, dx, dy) then
            return -- Pause menu handled the mouse movement
        end
    end
    
    if app.active and app.active.mousemoved then
        -- Convert screen coordinates to game coordinates
        local scaling = require("src.core.scaling")
        local gx, gy = scaling.screenToGame(x, y)
        app.active.mousemoved(gx, gy, dx, dy)
    end
end

return app

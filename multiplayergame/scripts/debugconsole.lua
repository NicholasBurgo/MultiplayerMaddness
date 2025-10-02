local debugConsole = {}

debugConsole.log = {}
debugConsole.MAX_MESSAGES = 20
debugConsole.visible = false
debugConsole.width = 400
debugConsole.height = 300
debugConsole.x = 10  -- Position from left
debugConsole.y = love.graphics.getHeight() - 310  -- Position from bottom

-- Debug commands
debugConsole.commands = {}
debugConsole.inputText = ""
debugConsole.inputActive = false

function debugConsole.init()
    debugConsole.log = {}
    debugConsole.addMessage("[Status] Debug console initialized")
    
    -- Initialize debug commands
    debugConsole.initCommands()
end

function debugConsole.initCommands()
    -- Add debug commands
    debugConsole.commands["setscore"] = function(playerId, score)
        playerId = tonumber(playerId)
        score = tonumber(score)
        if playerId and score and _G.players and _G.players[playerId] then
            _G.players[playerId].totalScore = score
            debugConsole.addMessage(string.format("[Debug] Set player %d score to %d", playerId, score))
        else
            debugConsole.addMessage("[Debug] Invalid player ID or score")
        end
    end
    
    debugConsole.commands["addscore"] = function(playerId, amount)
        playerId = tonumber(playerId)
        amount = tonumber(amount)
        if playerId and amount and _G.players and _G.players[playerId] then
            _G.players[playerId].totalScore = (_G.players[playerId].totalScore or 0) + amount
            debugConsole.addMessage(string.format("[Debug] Added %d to player %d score (now %d)", amount, playerId, _G.players[playerId].totalScore))
        else
            debugConsole.addMessage("[Debug] Invalid player ID or amount")
        end
    end
    
    debugConsole.commands["testscorelobby"] = function()
        if _G.scoreLobby and _G.players then
            -- Create test round wins
            local roundWins = {}
            for id, player in pairs(_G.players) do
                roundWins[id] = math.random(0, 3) -- Random wins for testing
            end
            
            -- Show score lobby for all players (like level selection)
            _G.scoreLobby.show(4, roundWins, _G.players)
            debugConsole.addMessage("[Debug] Testing score lobby for all players")
            
            -- If we're the host, notify all clients about the score lobby
            if _G.gameState == "hosting" and _G.serverClients then
                for _, client in ipairs(_G.serverClients) do
                    local message = "show_score_lobby,4"
                    for id, wins in pairs(roundWins) do
                        message = message .. "," .. id .. "," .. wins
                    end
                    _G.safeSend(client, message)
                end
                debugConsole.addMessage("[Debug] Notified all clients about score lobby")
            end
        else
            debugConsole.addMessage("[Debug] Score lobby not available")
        end
    end
    
    debugConsole.commands["help"] = function()
        debugConsole.addMessage("[Debug] Available commands:")
        debugConsole.addMessage("  setscore <playerId> <score> - Set player score")
        debugConsole.addMessage("  addscore <playerId> <amount> - Add to player score")
        debugConsole.addMessage("  testscorelobby - Test score lobby")
        debugConsole.addMessage("  help - Show this help")
    end
end

function debugConsole.executeCommand(input)
    local parts = {}
    for word in input:gmatch("%S+") do
        table.insert(parts, word)
    end
    
    if #parts == 0 then return end
    
    local command = parts[1]
    local args = {}
    for i = 2, #parts do
        table.insert(args, parts[i])
    end
    
    if debugConsole.commands[command] then
        debugConsole.commands[command](unpack(args))
    else
        debugConsole.addMessage("[Debug] Unknown command: " .. command)
        debugConsole.addMessage("[Debug] Type 'help' for available commands")
    end
end

function debugConsole.addMessage(msg)
    local timestamp = os.date("%H:%M:%S")
    table.insert(debugConsole.log, 1, timestamp .. ": " .. tostring(msg))
    if #debugConsole.log > debugConsole.MAX_MESSAGES then
        table.remove(debugConsole.log)
    end
end

function debugConsole.draw()
    if not debugConsole.visible then return end
    
    -- Store current color
    local r, g, b, a = love.graphics.getColor()
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", 
        debugConsole.x, 
        debugConsole.y, 
        debugConsole.width, 
        math.min(debugConsole.height, #debugConsole.log * 20 + 40)
    )
    
    -- Draw server status at top
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        string.format("Debug Console (F3) | Server: %s | Players: %d", 
            _G.serverStatus or "Unknown",
            #table_keys(_G.players or {})
        ),
        debugConsole.x + 10, 
        debugConsole.y + 10
    )
    
    -- Draw messages
    for i, msg in ipairs(debugConsole.log) do
        love.graphics.print(msg, 
            debugConsole.x + 10, 
            debugConsole.y + 30 + (i-1) * 20
        )
    end
    
    -- Draw input field
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", 
        debugConsole.x + 10, 
        debugConsole.y + 30 + #debugConsole.log * 20 + 10, 
        debugConsole.width - 20, 
        20
    )
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("> " .. debugConsole.inputText .. (debugConsole.inputActive and "_" or ""), 
        debugConsole.x + 15, 
        debugConsole.y + 35 + #debugConsole.log * 20 + 10
    )
    
    -- Restore original color
    love.graphics.setColor(r, g, b, a)
end

function debugConsole.toggle()
    debugConsole.visible = not debugConsole.visible
    if debugConsole.visible then
        debugConsole.inputActive = true
    else
        debugConsole.inputActive = false
    end
end

function debugConsole.textinput(text)
    if debugConsole.visible and debugConsole.inputActive then
        debugConsole.inputText = debugConsole.inputText .. text
    end
end

function debugConsole.keypressed(key)
    if not debugConsole.visible or not debugConsole.inputActive then
        return false
    end
    
    if key == "return" or key == "kpenter" then
        -- Execute command
        if debugConsole.inputText ~= "" then
            debugConsole.addMessage("> " .. debugConsole.inputText)
            debugConsole.executeCommand(debugConsole.inputText)
            debugConsole.inputText = ""
        end
        return true
    elseif key == "backspace" then
        debugConsole.inputText = debugConsole.inputText:sub(1, -2)
        return true
    end
    
    return false
end

-- Helper function to safely count table keys
function table_keys(t)
    if type(t) ~= "table" then return {} end
    local keys = {}
    for k in pairs(t) do 
        table.insert(keys, k)
    end
    return keys
end

return debugConsole
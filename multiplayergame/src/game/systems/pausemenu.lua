-- ============================================================================
-- PAUSE MENU SYSTEM
-- ============================================================================
-- Global pause menu that can be activated from any game scene
-- Features: Resume, Player List, Settings, Quit (context-sensitive)
-- ============================================================================

local events = require("src.core.events")
local logger = require("src.core.logger")
local settingsMenu = require("src.game.systems.settingsmenu")

local pausemenu = {}

-- Pause menu state
pausemenu.visible = false
pausemenu.currentScene = nil
pausemenu.isHost = false
pausemenu.players = {}
pausemenu.localPlayerId = 0
pausemenu.selectedOption = 1
pausemenu.animationTime = 0

-- Menu options - will be set based on context
pausemenu.options = {}

-- Player list submenu state
pausemenu.playerListVisible = false
pausemenu.selectedPlayer = 1
pausemenu.playerListAnimationTime = 0

-- Voting system for quit to lobby
pausemenu.quitVoteActive = false
pausemenu.quitVotes = {} -- {playerId = true/false}
pausemenu.quitVoteTime = 30 -- 30 seconds to vote
pausemenu.quitVoteTimer = 0
pausemenu.hasVotedToQuit = false

-- Font system
local fonts = {
    small = nil,
    medium = nil,
    large = nil,
    xlarge = nil,
    huge = nil
}

-- Initialize fonts
local function initFonts()
    fonts.small = love.graphics.newFont(12)
    fonts.medium = love.graphics.newFont(16)
    fonts.large = love.graphics.newFont(20)
    fonts.xlarge = love.graphics.newFont(24)
    fonts.huge = love.graphics.newFont(32)
end

-- Set context for the pause menu
function pausemenu.setContext(sceneName, isHost, players, localPlayerId)
    pausemenu.currentScene = sceneName
    pausemenu.isHost = isHost
    pausemenu.players = players or {}
    pausemenu.localPlayerId = localPlayerId or 0
    
    -- Set menu options based on context
    pausemenu.options = {}
    table.insert(pausemenu.options, {text = "Resume", action = "resume"})
    table.insert(pausemenu.options, {text = "Players", action = "players"})
    table.insert(pausemenu.options, {text = "Settings", action = "settings"})
    
    -- Add quit option based on context
    if sceneName == "lobby" then
        table.insert(pausemenu.options, {text = "Quit to Menu", action = "quit_to_menu"})
    elseif sceneName == "menu" then
        -- Don't show quit option in main menu
    else
        -- In game modes or party mode
        if isHost then
            table.insert(pausemenu.options, {text = "Quit to Lobby", action = "quit_to_lobby"})
        else
            table.insert(pausemenu.options, {text = "Vote to Quit", action = "vote_to_quit"})
        end
    end
    
    pausemenu.selectedOption = 1
end

-- Set transport reference for network communication
function pausemenu.setTransport(transport)
    pausemenu.transport = transport
end

-- Show pause menu
function pausemenu.show()
    pausemenu.visible = true
    pausemenu.animationTime = 0
    pausemenu.playerListVisible = false
    pausemenu.quitVoteActive = false
    pausemenu.hasVotedToQuit = false
    logger.info("pausemenu", "Pause menu shown")
end

-- Hide pause menu
function pausemenu.hide()
    pausemenu.visible = false
    pausemenu.playerListVisible = false
    pausemenu.quitVoteActive = false
    logger.info("pausemenu", "Pause menu hidden")
end

-- Check if pause menu is visible
function pausemenu.isVisible()
    return pausemenu.visible
end

-- Update pause menu
function pausemenu.update(dt)
    if not pausemenu.visible then return end
    
    -- Update settings menu if visible
    if settingsMenu.isVisible() then
        settingsMenu.update(dt)
        return
    end
    
    pausemenu.animationTime = pausemenu.animationTime + dt
    
    if pausemenu.playerListVisible then
        pausemenu.playerListAnimationTime = pausemenu.playerListAnimationTime + dt
    end
    
    -- Update quit vote timer
    if pausemenu.quitVoteActive then
        pausemenu.quitVoteTimer = pausemenu.quitVoteTimer - dt
        if pausemenu.quitVoteTimer <= 0 then
            pausemenu.checkQuitVoteResult()
        end
    end
end

-- Check quit vote result
function pausemenu.checkQuitVoteResult()
    local totalVoters = 0
    local yesVotes = 0
    
    -- Count votes (excluding host)
    for playerId, voted in pairs(pausemenu.quitVotes) do
        if playerId ~= 0 and pausemenu.players[playerId] then -- Exclude host
            totalVoters = totalVoters + 1
            if voted then
                yesVotes = yesVotes + 1
            end
        end
    end
    
    local requiredVotes = math.ceil(totalVoters * 2 / 3) -- 2/3 majority
    
    if yesVotes >= requiredVotes then
        logger.info("pausemenu", "Quit vote passed: " .. yesVotes .. "/" .. totalVoters)
        -- Send result to all players
        if pausemenu.transport then
            pausemenu.transport.send("QUIT_VOTE_RESULT", {result = true})
        end
        pausemenu.hide() -- Close pause menu first
        events.emit("intent:quit_to_lobby")
        pausemenu.quitVoteActive = false
    else
        logger.info("pausemenu", "Quit vote failed: " .. yesVotes .. "/" .. totalVoters .. " (needed " .. requiredVotes .. ")")
        -- Send result to all players
        if pausemenu.transport then
            pausemenu.transport.send("QUIT_VOTE_RESULT", {result = false})
        end
        pausemenu.quitVoteActive = false
        pausemenu.quitVotes = {}
        pausemenu.hasVotedToQuit = false
    end
end

-- Handle menu selection
function pausemenu.selectOption()
    if pausemenu.playerListVisible then
        -- Handle player list selection
        local playerIds = {}
        for id, _ in pairs(pausemenu.players) do
            table.insert(playerIds, id)
        end
        table.sort(playerIds)
        
        if pausemenu.selectedPlayer >= 1 and pausemenu.selectedPlayer <= #playerIds then
            local targetPlayerId = playerIds[pausemenu.selectedPlayer]
            if targetPlayerId ~= pausemenu.localPlayerId and pausemenu.isHost then
                -- Kick player (host only)
                logger.info("pausemenu", "Kicking player: " .. targetPlayerId)
                if pausemenu.transport then
                    pausemenu.transport.send("KICK_PLAYER", {playerId = targetPlayerId})
                end
            end
        end
    else
        -- Handle main menu selection
        local option = pausemenu.options[pausemenu.selectedOption]
        if option then
            if option.action == "resume" then
                pausemenu.hide()
            elseif option.action == "players" then
                pausemenu.playerListVisible = true
                pausemenu.playerListAnimationTime = 0
                pausemenu.selectedPlayer = 1
            elseif option.action == "settings" then
                -- Open settings menu
                settingsMenu.show()
            elseif option.action == "quit_to_menu" then
                pausemenu.hide() -- Close pause menu first
                events.emit("intent:leave_lobby")
            elseif option.action == "quit_to_lobby" then
                pausemenu.hide() -- Close pause menu first
                events.emit("intent:quit_to_lobby")
            elseif option.action == "vote_to_quit" then
                pausemenu.startQuitVote()
            end
        end
    end
end

-- Start quit vote
function pausemenu.startQuitVote()
    if pausemenu.hasVotedToQuit then return end
    
    pausemenu.quitVoteActive = true
    pausemenu.quitVoteTimer = pausemenu.quitVoteTime
    pausemenu.quitVotes = {}
    pausemenu.hasVotedToQuit = true
    
    -- Vote yes by default
    pausemenu.quitVotes[pausemenu.localPlayerId] = true
    
    logger.info("pausemenu", "Started quit vote")
    
    -- Send vote start to all players
    if pausemenu.transport then
        pausemenu.transport.send("QUIT_VOTE_START", {
            time = pausemenu.quitVoteTime,
            votes = pausemenu.quitVotes
        })
    end
end

-- Check if mouse is over a button
local function isMouseOverButton(x, y, buttonX, buttonY, buttonWidth, buttonHeight)
    return x >= buttonX and x <= buttonX + buttonWidth and
           y >= buttonY and y <= buttonY + buttonHeight
end

-- Handle mouse input
function pausemenu.mousepressed(x, y, button)
    if not pausemenu.visible or button ~= 1 then return false end
    
    -- Handle settings menu mouse input first
    if settingsMenu.isVisible() then
        if settingsMenu.mousepressed and settingsMenu.mousepressed(x, y, button) then
            return true
        end
        return true
    end
    
    if pausemenu.quitVoteActive then
        -- Handle quit vote mouse input
        local BASE_WIDTH = 800
        local BASE_HEIGHT = 600
        
        -- Yes button
        if isMouseOverButton(x, y, BASE_WIDTH/2 - 120, BASE_HEIGHT/2 + 100, 100, 40) then
            pausemenu.quitVotes[pausemenu.localPlayerId] = true
            pausemenu.hasVotedToQuit = true
            if pausemenu.transport then
                pausemenu.transport.send("QUIT_VOTE", {
                    playerId = pausemenu.localPlayerId,
                    vote = true
                })
            end
        -- No button
        elseif isMouseOverButton(x, y, BASE_WIDTH/2 + 20, BASE_HEIGHT/2 + 100, 100, 40) then
            pausemenu.quitVotes[pausemenu.localPlayerId] = false
            pausemenu.hasVotedToQuit = true
            if pausemenu.transport then
                pausemenu.transport.send("QUIT_VOTE", {
                    playerId = pausemenu.localPlayerId,
                    vote = false
                })
            end
        else
            -- Clicked outside buttons - close voting menu
            pausemenu.quitVoteActive = false
            pausemenu.quitVotes = {}
            pausemenu.hasVotedToQuit = false
        end
        return true
    end
    
    if pausemenu.playerListVisible then
        -- Handle player list mouse input
        local BASE_WIDTH = 800
        local startY = 200
        local playerSpacing = 45
        
        local playerIds = {}
        for id, _ in pairs(pausemenu.players) do
            table.insert(playerIds, id)
        end
        table.sort(playerIds)
        
        for i, playerId in ipairs(playerIds) do
            local buttonY = startY + (i - 1) * playerSpacing
            if isMouseOverButton(x, y, 150, buttonY, BASE_WIDTH - 300, 35) then
                pausemenu.selectedPlayer = i
                if pausemenu.isHost and playerId ~= pausemenu.localPlayerId then
                    -- Kick player on click (host only)
                    if pausemenu.transport then
                        pausemenu.transport.send("KICK_PLAYER", {playerId = playerId})
                    end
                end
                return true
            end
        end
        return true
    end
    
    -- Handle main menu mouse input
    local BASE_WIDTH = 800
    local startY = 220
    local optionSpacing = 50
    
    for i, option in ipairs(pausemenu.options) do
        local buttonY = startY + (i - 1) * optionSpacing
        if isMouseOverButton(x, y, 150, buttonY - 5, BASE_WIDTH - 300, 40) then
            pausemenu.selectedOption = i
            pausemenu.selectOption()
            return true
        end
    end
    
    return true -- Handled
end

-- Handle mouse movement for hover effects
function pausemenu.mousemoved(x, y, dx, dy)
    if not pausemenu.visible then return false end
    
    -- Handle settings menu mouse movement first
    if settingsMenu.isVisible() then
        if settingsMenu.mousemoved and settingsMenu.mousemoved(x, y, dx, dy) then
            return true
        end
        return true
    end
    
    if pausemenu.quitVoteActive then
        return true
    end
    
    if pausemenu.playerListVisible then
        -- Handle player list hover
        local BASE_WIDTH = 800
        local startY = 200
        local playerSpacing = 45
        
        local playerIds = {}
        for id, _ in pairs(pausemenu.players) do
            table.insert(playerIds, id)
        end
        table.sort(playerIds)
        
        for i, playerId in ipairs(playerIds) do
            local buttonY = startY + (i - 1) * playerSpacing
            if isMouseOverButton(x, y, 150, buttonY, BASE_WIDTH - 300, 35) then
                pausemenu.selectedPlayer = i
                return true
            end
        end
        return true
    end
    
    -- Handle main menu hover
    local BASE_WIDTH = 800
    local startY = 220
    local optionSpacing = 50
    
    for i, option in ipairs(pausemenu.options) do
        local buttonY = startY + (i - 1) * optionSpacing
        if isMouseOverButton(x, y, 150, buttonY - 5, BASE_WIDTH - 300, 40) then
            pausemenu.selectedOption = i
            return true
        end
    end
    
    return true -- Handled
end

-- Handle key input
function pausemenu.keypressed(key)
    if not pausemenu.visible then return false end
    
    -- Handle settings menu input first
    if settingsMenu.isVisible() then
        if settingsMenu.keypressed(key) then
            return true
        end
        -- If settings menu handled escape, hide it and return to pause menu
        if key == "escape" then
            return true
        end
    end
    
    if pausemenu.quitVoteActive then
        -- Handle only voting-specific keys during voting
        if key == "y" or key == "space" then
            pausemenu.quitVotes[pausemenu.localPlayerId] = true
            pausemenu.hasVotedToQuit = true
            -- Send vote to other players
            if pausemenu.transport then
                pausemenu.transport.send("QUIT_VOTE", {
                    playerId = pausemenu.localPlayerId,
                    vote = true
                })
            end
            return true
        elseif key == "n" then
            pausemenu.quitVotes[pausemenu.localPlayerId] = false
            pausemenu.hasVotedToQuit = true
            -- Send vote to other players
            if pausemenu.transport then
                pausemenu.transport.send("QUIT_VOTE", {
                    playerId = pausemenu.localPlayerId,
                    vote = false
                })
            end
            return true
        end
        -- For any other key (including ESC), do nothing during voting
        return true
    end
    
    if pausemenu.playerListVisible then
        -- Handle player list navigation
        if key == "w" or key == "up" then
            pausemenu.selectedPlayer = pausemenu.selectedPlayer - 1
            if pausemenu.selectedPlayer < 1 then
                local playerCount = 0
                for _ in pairs(pausemenu.players) do playerCount = playerCount + 1 end
                pausemenu.selectedPlayer = playerCount
            end
        elseif key == "s" or key == "down" then
            local playerCount = 0
            for _ in pairs(pausemenu.players) do playerCount = playerCount + 1 end
            pausemenu.selectedPlayer = pausemenu.selectedPlayer + 1
            if pausemenu.selectedPlayer > playerCount then
                pausemenu.selectedPlayer = 1
            end
        elseif key == "space" or key == "return" then
            pausemenu.selectOption()
        elseif key == "escape" or key == "backspace" then
            pausemenu.playerListVisible = false
        end
    else
        -- Handle main menu navigation
        if key == "w" or key == "up" then
            pausemenu.selectedOption = pausemenu.selectedOption - 1
            if pausemenu.selectedOption < 1 then
                pausemenu.selectedOption = #pausemenu.options
            end
        elseif key == "s" or key == "down" then
            pausemenu.selectedOption = pausemenu.selectedOption + 1
            if pausemenu.selectedOption > #pausemenu.options then
                pausemenu.selectedOption = 1
            end
        elseif key == "space" or key == "return" then
            pausemenu.selectOption()
        elseif key == "escape" then
            if pausemenu.playerListVisible then
                pausemenu.playerListVisible = false
            else
                pausemenu.hide()
            end
        end
    end
    
    return true -- Handled
end

-- Draw pause menu
function pausemenu.draw()
    if not pausemenu.visible then return end
    
    -- Draw settings menu if visible
    if settingsMenu.isVisible() then
        settingsMenu.draw()
        return
    end
    
    -- Initialize fonts if needed
    if not fonts.huge then
        initFonts()
    end
    
    local BASE_WIDTH = 800
    local BASE_HEIGHT = 600
    
    if pausemenu.quitVoteActive then
        pausemenu.drawQuitVote()
    elseif pausemenu.playerListVisible then
        pausemenu.drawPlayerList()
    else
        pausemenu.drawMainMenu()
    end
end

-- Draw main pause menu
function pausemenu.drawMainMenu()
    local BASE_WIDTH = 800
    local BASE_HEIGHT = 600
    
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, BASE_WIDTH, BASE_HEIGHT)
    
    -- Animated border
    local pulse = math.sin(pausemenu.animationTime * 3) * 0.2 + 0.8
    local pulse2 = math.sin(pausemenu.animationTime * 4 + 1) * 0.15 + 0.7
    
    -- Outer glow
    love.graphics.setColor(0, 0.8, 1, pulse2 * 0.3)
    love.graphics.setLineWidth(8)
    love.graphics.rectangle("line", 50, 50, BASE_WIDTH - 100, BASE_HEIGHT - 100)
    
    -- Main border
    love.graphics.setColor(0.2, 1, 0.6, pulse)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 60, 60, BASE_WIDTH - 120, BASE_HEIGHT - 120)
    
    -- Menu background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", 80, 80, BASE_WIDTH - 160, BASE_HEIGHT - 160)
    
    -- Title
    love.graphics.setFont(fonts.huge)
    local titlePulse = math.sin(pausemenu.animationTime * 2) * 0.3 + 0.7
    love.graphics.setColor(0.2, 1, 0.4, titlePulse)
    love.graphics.printf("PAUSED", 0, 120, BASE_WIDTH, "center")
    
    -- Scene info
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    local sceneText = "Scene: " .. (pausemenu.currentScene or "Unknown")
    if pausemenu.isHost then
        sceneText = sceneText .. " (Host)"
    end
    love.graphics.printf(sceneText, 0, 170, BASE_WIDTH, "center")
    
    -- Menu options
    local startY = 220
    local optionSpacing = 50
    
    for i, option in ipairs(pausemenu.options) do
        local y = startY + (i - 1) * optionSpacing
        local isSelected = i == pausemenu.selectedOption
        
        -- Option background
        if isSelected then
            local bgPulse = math.sin(pausemenu.animationTime * 4 + i) * 0.15 + 0.85
            love.graphics.setColor(0.2, 0.4, 0.6, 0.6 * bgPulse)
            love.graphics.rectangle("fill", 150, y - 5, BASE_WIDTH - 300, 40)
            
            -- Selection indicator
            love.graphics.setColor(1, 1, 0.2, bgPulse)
            love.graphics.rectangle("fill", 130, y - 5, 15, 40)
        end
        
        -- Option text
        love.graphics.setFont(fonts.large)
        if isSelected then
            love.graphics.setColor(1, 1, 0.2, pulse)
        else
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
        end
        love.graphics.printf(option.text, 0, y, BASE_WIDTH, "center")
    end
    
    -- Instructions
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.printf("Use W/S or mouse to navigate, SPACE/ENTER or click to select, ESC to resume", 0, BASE_HEIGHT - 80, BASE_WIDTH, "center")
end

-- Draw player list submenu
function pausemenu.drawPlayerList()
    local BASE_WIDTH = 800
    local BASE_HEIGHT = 600
    
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, BASE_WIDTH, BASE_HEIGHT)
    
    -- Animated border
    local pulse = math.sin(pausemenu.playerListAnimationTime * 3) * 0.2 + 0.8
    
    love.graphics.setColor(0.8, 0, 1, pulse)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 60, 60, BASE_WIDTH - 120, BASE_HEIGHT - 120)
    
    -- Menu background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", 80, 80, BASE_WIDTH - 160, BASE_HEIGHT - 160)
    
    -- Title
    love.graphics.setFont(fonts.huge)
    local titlePulse = math.sin(pausemenu.playerListAnimationTime * 2) * 0.3 + 0.7
    love.graphics.setColor(0.8, 0, 1, titlePulse)
    love.graphics.printf("PLAYERS", 0, 100, BASE_WIDTH, "center")
    
    -- Player count
    local playerCount = 0
    for _ in pairs(pausemenu.players) do playerCount = playerCount + 1 end
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf("Players: " .. playerCount, 0, 150, BASE_WIDTH, "center")
    
    -- Draw players
    local playerIds = {}
    for id, _ in pairs(pausemenu.players) do
        table.insert(playerIds, id)
    end
    table.sort(playerIds)
    
    local startY = 200
    local playerSpacing = 45
    
    for i, playerId in ipairs(playerIds) do
        local player = pausemenu.players[playerId]
        local y = startY + (i - 1) * playerSpacing
        local isSelected = i == pausemenu.selectedPlayer
        
        -- Player background
        if isSelected then
            local bgPulse = math.sin(pausemenu.playerListAnimationTime * 4 + i) * 0.15 + 0.85
            love.graphics.setColor(0.2, 0.4, 0.6, 0.6 * bgPulse)
            love.graphics.rectangle("fill", 150, y - 5, BASE_WIDTH - 300, 35)
            
            -- Selection indicator
            love.graphics.setColor(1, 1, 0.2, bgPulse)
            love.graphics.rectangle("fill", 130, y - 5, 15, 35)
        end
        
        -- Player color indicator
        if player.color then
            love.graphics.setColor(player.color[1], player.color[2], player.color[3], 1)
            love.graphics.rectangle("fill", 170, y, 30, 30, 5, 5)
        end
        
        -- Player name
        love.graphics.setFont(fonts.large)
        if isSelected then
            love.graphics.setColor(1, 1, 0.2, pulse)
        else
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
        end
        love.graphics.printf(player.name or "Player " .. playerId, 220, y + 5, 200, "left")
        
        -- Player info
        love.graphics.setFont(fonts.medium)
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        local infoText = "ID: " .. playerId
        if playerId == 0 then
            infoText = infoText .. " (Host)"
        end
        if playerId == pausemenu.localPlayerId then
            infoText = infoText .. " (You)"
        end
        love.graphics.printf(infoText, 450, y + 5, 150, "left")
        
        -- Score
        love.graphics.printf("Score: " .. (player.totalScore or 0), 620, y + 5, 100, "right")
    end
    
    -- Instructions
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    if pausemenu.isHost then
        love.graphics.printf("W/S or mouse to navigate, SPACE or click to kick player, ESC to back", 0, BASE_HEIGHT - 80, BASE_WIDTH, "center")
    else
        love.graphics.printf("W/S or mouse to navigate, ESC to back", 0, BASE_HEIGHT - 80, BASE_WIDTH, "center")
    end
end

-- Draw quit vote screen
function pausemenu.drawQuitVote()
    local BASE_WIDTH = 800
    local BASE_HEIGHT = 600
    
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, BASE_WIDTH, BASE_HEIGHT)
    
    -- Animated border
    local pulse = math.sin(pausemenu.animationTime * 5) * 0.2 + 0.8
    
    love.graphics.setColor(1, 0.3, 0.3, pulse)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle("line", 50, 50, BASE_WIDTH - 100, BASE_HEIGHT - 100)
    
    -- Menu background
    love.graphics.setColor(0.15, 0.05, 0.05, 0.95)
    love.graphics.rectangle("fill", 80, 80, BASE_WIDTH - 160, BASE_HEIGHT - 160)
    
    -- Title
    love.graphics.setFont(fonts.huge)
    local titlePulse = math.sin(pausemenu.animationTime * 3) * 0.3 + 0.7
    love.graphics.setColor(1, 0.2, 0.2, titlePulse)
    love.graphics.printf("VOTE TO QUIT", 0, 150, BASE_WIDTH, "center")
    
    -- Timer
    love.graphics.setFont(fonts.xlarge)
    love.graphics.setColor(1, 1, 1, 1)
    local timeText = string.format("Time: %.1f", math.max(0, pausemenu.quitVoteTimer))
    love.graphics.printf(timeText, 0, 220, BASE_WIDTH, "center")
    
    -- Vote instructions
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.printf("Vote to return to lobby?", 0, 280, BASE_WIDTH, "center")
    
    -- Vote count
    local yesVotes = 0
    local totalVoters = 0
    for playerId, voted in pairs(pausemenu.quitVotes) do
        if playerId ~= 0 then -- Exclude host
            totalVoters = totalVoters + 1
            if voted then
                yesVotes = yesVotes + 1
            end
        end
    end
    
    local requiredVotes = math.ceil(totalVoters * 2 / 3)
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf("Votes: " .. yesVotes .. "/" .. totalVoters .. " (Need " .. requiredVotes .. ")", 0, 320, BASE_WIDTH, "center")
    
    -- Vote options
    love.graphics.setFont(fonts.large)
    if pausemenu.quitVotes[pausemenu.localPlayerId] then
        love.graphics.setColor(0.2, 1, 0.2, 1)
        love.graphics.printf("Your vote: YES", 0, 380, BASE_WIDTH, "center")
    else
        love.graphics.setColor(1, 0.2, 0.2, 1)
        love.graphics.printf("Your vote: NO", 0, 380, BASE_WIDTH, "center")
    end
    
    -- Vote buttons
    local buttonY = BASE_HEIGHT/2 + 100
    local buttonWidth = 100
    local buttonHeight = 40
    
    -- Yes button
    local yesX = BASE_WIDTH/2 - 120
    local yesSelected = pausemenu.quitVotes[pausemenu.localPlayerId] == true
    love.graphics.setColor(yesSelected and {0.2, 1, 0.2} or {0.3, 0.6, 0.3}, yesSelected and 1 or 0.7)
    love.graphics.rectangle("fill", yesX, buttonY, buttonWidth, buttonHeight, 8, 8)
    love.graphics.setColor(yesSelected and {0, 0.8, 0} or {0.2, 0.4, 0.2}, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", yesX, buttonY, buttonWidth, buttonHeight, 8, 8)
    love.graphics.setLineWidth(1)
    
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("YES", yesX, buttonY + 8, buttonWidth, "center")
    
    -- No button
    local noX = BASE_WIDTH/2 + 20
    local noSelected = pausemenu.quitVotes[pausemenu.localPlayerId] == false
    love.graphics.setColor(noSelected and {1, 0.2, 0.2} or {0.6, 0.3, 0.3}, noSelected and 1 or 0.7)
    love.graphics.rectangle("fill", noX, buttonY, buttonWidth, buttonHeight, 8, 8)
    love.graphics.setColor(noSelected and {0.8, 0, 0} or {0.4, 0.2, 0.2}, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", noX, buttonY, buttonWidth, buttonHeight, 8, 8)
    love.graphics.setLineWidth(1)
    
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("NO", noX, buttonY + 8, buttonWidth, "center")
    
    -- Instructions
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.printf("Click buttons or use Y/N keys to vote, click outside to cancel", 0, BASE_HEIGHT - 120, BASE_WIDTH, "center")
end

return pausemenu

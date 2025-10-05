-- ============================================================================
-- LOBBY SCENE
-- ============================================================================
-- Recreated from original main.lua with:
-- - Player rendering with custom faces
-- - WASD movement in lobby
-- - Game Mode Selection menu (4 options: Level Selector, Party Mode, Play, Play Now)
-- - Level selector with character icons on voted cards
-- - No voting status panel - icons appear on cards and in game mode menu

local events = require("src.core.events")
local musicHandler = require("src.game.systems.musichandler")
local characterCustomization = require("src.game.systems.charactercustom")

local lobby = {}
lobby.name = "lobby"

-- UI State
local lobbyBackground = nil
local isHost = false
local players = {}
local localPlayer = {x = 100, y = 100, id = 0, color = {1, 1, 1}, name = "Player", facePoints = nil, totalScore = 0}

-- Base resolution
local BASE_WIDTH = 800
local BASE_HEIGHT = 600

-- Game Mode Selection (first menu when pressing SPACE)
local gameModeSelection = {
    active = false,
    selectedMode = 1, -- 1 = Level Selector, 2 = Party Mode, 3 = Play, 4 = Play Now (host only)
    modes = {"Level Selector", "Party Mode", "Play", "Play Now"},
    animationTime = 0
}

-- Level Selector System (second menu, opens from game mode selection)
local levelSelector = {
    active = false,
    selectedLevel = 1,
    currentPage = 1,
    pages = {
        -- Page 1: Current games
        {
            {name = "Jump Game", description = "Platform jumping challenge", image = "images/jumpintro.png"},
            {name = "Laser Game", description = "Dodge laser beams", image = "images/lasersintro.png"},
            {name = "Meteor Shower", description = "Survive the meteor shower", image = "images/menu-background.jpg"},
            {name = "Dodge Laser", description = "Quick reflex dodging", image = "images/menu-background.jpg"},
            {name = "Praise Game", description = "Simple movement challenge", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "New game mode in development", image = "images/menu-background.jpg"}
        }
    },
    animationTime = 0,
    votes = {}, -- Track votes: {levelIndex = {playerId1, playerId2, ...}}
    playerVotes = {}, -- Track which level each player voted for: {playerId = levelIndex}
    partyModeVotes = {}, -- Track party mode votes
    gridCols = 3,
    gridRows = 2,
    cardWidth = 200,
    cardHeight = 140,
    cardSpacing = 20,
    loadedImages = {},
    lastSelectedGame = 1
}

-- Fonts
local fonts = {
    small = love.graphics.newFont(14),
    medium = love.graphics.newFont(16),
    large = love.graphics.newFont(18),
    xlarge = love.graphics.newFont(24),
    huge = love.graphics.newFont(32)
}

-- Particle system for votes
local voteParticles = {}
local function createVoteParticle(x, y, color)
    table.insert(voteParticles, {
        x = x,
        y = y,
        vx = (math.random() - 0.5) * 100,
        vy = (math.random() - 0.5) * 100 - 50,
        life = 1.0,
        maxLife = 1.0,
        color = color or {1, 1, 0},
        size = math.random(3, 8)
    })
end

local function updateVoteParticles(dt)
    for i = #voteParticles, 1, -1 do
        local p = voteParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 200 * dt -- gravity
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(voteParticles, i)
        end
    end
end

local function drawVoteParticles()
    for _, p in ipairs(voteParticles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.circle("fill", p.x, p.y, p.size * alpha)
    end
end

-- Load level selector images
local function loadLevelSelectorImages()
    local currentLevels = levelSelector.pages[levelSelector.currentPage]
    for i, level in ipairs(currentLevels) do
        if not levelSelector.loadedImages[i] then
            local success, image = pcall(love.graphics.newImage, level.image)
            if success then
                levelSelector.loadedImages[i] = image
            else
                -- Fallback
                local fallbackSuccess, fallbackImage = pcall(love.graphics.newImage, "images/menu-background.jpg")
                if fallbackSuccess then
                    levelSelector.loadedImages[i] = fallbackImage
                end
            end
        end
    end
end

function lobby.load(args)
    isHost = args and args.isHost or false
    players = args and args.players or {}
    
    print("[Lobby] Loading lobby with isHost: " .. tostring(isHost))
    print("[Lobby] args.isHost: " .. tostring(args and args.isHost))
    print("[Lobby] args.localPlayerId: " .. tostring(args and args.localPlayerId))
    
    -- Load saved player data
    local savefile = require("src.game.systems.savefile")
    local savedData = savefile.loadPlayerData()
    
    -- Initialize localPlayer with saved data or defaults
    localPlayer.x = localPlayer.x or 100
    localPlayer.y = localPlayer.y or 100
    localPlayer.color = savedData.color or {1, 0, 0}
    localPlayer.name = savedData.name or "Player"
    localPlayer.id = args and args.localPlayerId  -- Use assigned ID (may be nil for clients initially)
    localPlayer.totalScore = localPlayer.totalScore or 0
    localPlayer.facePoints = savedData.facePoints
    
    print("[Lobby] Local player ID: " .. tostring(localPlayer.id))
    print("[Lobby] Is host: " .. tostring(isHost))
    
    -- Only add localPlayer to players table if we have a valid ID
    -- For clients, this will be set when we receive YOUR_ID message
    -- For host, this should already be set (ID 0)
    if localPlayer.id ~= nil then
        print("[Lobby] Adding local player to players table with ID: " .. tostring(localPlayer.id))
        players[localPlayer.id] = {
            x = localPlayer.x,
            y = localPlayer.y,
            color = localPlayer.color,
            id = localPlayer.id,
            facePoints = localPlayer.facePoints,
            name = localPlayer.name,
            totalScore = localPlayer.totalScore
        }
    else
        print("[Lobby] Waiting for player ID assignment from host...")
    end
    
    -- Ensure all existing players have color field
    for id, player in pairs(players) do
        if not player.color then
            -- Default color palette
            local colors = {{1,0,0}, {0,1,0}, {0,0,1}, {1,1,0}, {1,0,1}, {0,1,1}}
            player.color = colors[(id % #colors) + 1]
        end
    end
    
    -- Load background
    if not lobbyBackground then
        lobbyBackground = love.graphics.newImage("images/menu-background.jpg")
    end
    
    -- Setup music effects
    musicHandler.update(0)
    
    -- Make globally accessible for old code compatibility
    _G.levelSelector = levelSelector
    _G.gameModeSelection = gameModeSelection
    _G.players = players
    _G.localPlayer = localPlayer
end

function lobby.update(dt) 
    musicHandler.update(dt)
    
    -- Update animations
    if gameModeSelection.active then
        gameModeSelection.animationTime = gameModeSelection.animationTime + dt
    end
    
    if levelSelector.active then
        levelSelector.animationTime = levelSelector.animationTime + dt
    end
    
    -- Update vote particles
    updateVoteParticles(dt)
    
    -- Update player movement (WASD) - only when menus are NOT active
    if not gameModeSelection.active and not levelSelector.active then
        local moved = false
        if love.keyboard.isDown('w') then
            localPlayer.y = localPlayer.y - 200 * dt
            moved = true
        elseif love.keyboard.isDown('s') then
            localPlayer.y = localPlayer.y + 200 * dt
            moved = true
        end
        if love.keyboard.isDown('a') then
            localPlayer.x = localPlayer.x - 200 * dt
            moved = true
        elseif love.keyboard.isDown('d') then
            localPlayer.x = localPlayer.x + 200 * dt
            moved = true
        end
        
        -- Keep player in bounds
        localPlayer.x = math.max(0, math.min(BASE_WIDTH - 30, localPlayer.x))
        localPlayer.y = math.max(0, math.min(BASE_HEIGHT - 30, localPlayer.y))
        
        -- Update player position in players table
        if moved and localPlayer.id ~= nil then
            players[localPlayer.id] = {
                x = localPlayer.x,
                y = localPlayer.y,
                color = localPlayer.color,
                id = localPlayer.id,
                totalScore = localPlayer.totalScore,
                facePoints = localPlayer.facePoints or players[localPlayer.id].facePoints,
                name = localPlayer.name
            }
            
            -- Send position update to other players
            events.emit("player:move", {
                id = localPlayer.id,
                x = localPlayer.x,
                y = localPlayer.y
            })
        end
    end
end

local function drawGameModeSelection()
    if not gameModeSelection.active then return end
    
    -- Fancy gradient overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle('fill', 0, 0, BASE_WIDTH, BASE_HEIGHT)
    
    -- Multiple animated borders with different colors
    local pulse = math.sin(gameModeSelection.animationTime * 3) * 0.2 + 0.8
    local pulse2 = math.sin(gameModeSelection.animationTime * 4 + 1) * 0.15 + 0.7
    
    -- Outer glow border (cyan)
    love.graphics.setColor(0, 0.8, 1, pulse2 * 0.3)
    love.graphics.setLineWidth(12)
    love.graphics.rectangle('line', 95, 45, BASE_WIDTH - 190, BASE_HEIGHT - 90)
    
    -- Main border (electric green/blue gradient effect)
    love.graphics.setColor(0.2, 1, 0.6, pulse)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle('line', 100, 50, BASE_WIDTH - 200, BASE_HEIGHT - 100)
    
    -- Inner highlight
    love.graphics.setColor(0.5, 1, 0.9, pulse * 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', 105, 55, BASE_WIDTH - 210, BASE_HEIGHT - 110)
    love.graphics.setLineWidth(1)
    
    -- Title with shadow and glow
    local titlePulse = math.sin(gameModeSelection.animationTime * 2) * 0.3 + 0.7
    love.graphics.setFont(fonts.huge)
    
    -- Title shadow
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.printf("SELECT GAME MODE", 0, 103, BASE_WIDTH, "center")
    
    -- Title glow
    love.graphics.setColor(0, 1, 1, titlePulse * 0.5)
    love.graphics.printf("SELECT GAME MODE", 0, 99, BASE_WIDTH, "center")
    love.graphics.printf("SELECT GAME MODE", 0, 101, BASE_WIDTH, "center")
    
    -- Title main
    love.graphics.setColor(0.2, 1, 0.4, titlePulse)
    love.graphics.printf("SELECT GAME MODE", 0, 100, BASE_WIDTH, "center")
    
    -- Subtitle
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.setFont(fonts.medium)
    love.graphics.printf("Use W/S or mouse to navigate, SPACE/CLICK to select", 0, 140, BASE_WIDTH, "center")
    
    -- Game mode options
    local centerY = BASE_HEIGHT / 2 - 50
    local optionSpacing = 70
    
    -- Build list of visible modes (skip Play/Play Now for non-hosts)
    local visibleModes = {}
    for i, mode in ipairs(gameModeSelection.modes) do
        if not ((i == 3 or i == 4) and not isHost) then
            table.insert(visibleModes, {index = i, name = mode})
        end
    end
    
    for i, modeInfo in ipairs(visibleModes) do
        local actualIndex = modeInfo.index
        local mode = modeInfo.name
        
        local y = centerY - 40 + (i - 1) * optionSpacing
        local isSelected = i == gameModeSelection.selectedMode
        
        -- Background box for all options
        local boxWidth = 450
        local boxHeight = 55
        local boxX = (BASE_WIDTH - boxWidth) / 2
        local boxY = y - 18
        
        if isSelected then
            -- Selected option - fancy animated background
            local bgPulse = math.sin(gameModeSelection.animationTime * 4 + i) * 0.15 + 0.85
            local colorShift = math.sin(gameModeSelection.animationTime * 2 + i) * 0.2
            
            -- Outer glow
            love.graphics.setColor(0, 0.8, 1, 0.3 * bgPulse)
            love.graphics.rectangle('fill', boxX - 5, boxY - 5, boxWidth + 10, boxHeight + 10, 8, 8)
            
            -- Main background with gradient effect
            love.graphics.setColor(0.1 + colorShift, 0.5, 0.8, 0.5 * bgPulse)
            love.graphics.rectangle('fill', boxX, boxY, boxWidth, boxHeight, 6, 6)
            
            -- Animated border
            love.graphics.setColor(0.2, 1, 0.6, bgPulse)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle('line', boxX, boxY, boxWidth, boxHeight, 6, 6)
            love.graphics.setLineWidth(1)
            
            -- Corner accents
            local cornerSize = 12
            love.graphics.setColor(1, 1, 0, bgPulse)
            love.graphics.setLineWidth(3)
            -- Top-left corner
            love.graphics.line(boxX, boxY + cornerSize, boxX, boxY, boxX + cornerSize, boxY)
            -- Top-right corner
            love.graphics.line(boxX + boxWidth - cornerSize, boxY, boxX + boxWidth, boxY, boxX + boxWidth, boxY + cornerSize)
            -- Bottom-left corner
            love.graphics.line(boxX, boxY + boxHeight - cornerSize, boxX, boxY + boxHeight, boxX + cornerSize, boxY + boxHeight)
            -- Bottom-right corner
            love.graphics.line(boxX + boxWidth - cornerSize, boxY + boxHeight, boxX + boxWidth, boxY + boxHeight, boxX + boxWidth, boxY + boxHeight - cornerSize)
            love.graphics.setLineWidth(1)
        else
            -- Unselected option - subtle background
            love.graphics.setColor(0.15, 0.15, 0.2, 0.4)
            love.graphics.rectangle('fill', boxX, boxY, boxWidth, boxHeight, 6, 6)
            
            love.graphics.setColor(0.3, 0.3, 0.4, 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle('line', boxX, boxY, boxWidth, boxHeight, 6, 6)
        end
        
        -- Option text with shadow
        love.graphics.setFont(fonts.large)
        if isSelected then
            -- Shadow
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.printf(">>> " .. mode .. " <<<", 2, y + 2, BASE_WIDTH, "center")
            
            -- Main text with color pulse
            love.graphics.setColor(1, 1, 0.2, pulse)
            love.graphics.printf(">>> " .. mode .. " <<<", 0, y, BASE_WIDTH, "center")
        else
            -- Shadow
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.printf(mode, 2, y + 2, BASE_WIDTH, "center")
            
            -- Main text
            love.graphics.setColor(0.8, 0.8, 0.9, 1)
            love.graphics.printf(mode, 0, y, BASE_WIDTH, "center")
        end
        
        -- Draw player pictures for who voted for this option
        local votedPlayers = {}
        
        if i == 1 then
            -- Level Selector - show players who voted for individual games
            for playerId, votedLevel in pairs(levelSelector.playerVotes) do
                if players[playerId] then
                    table.insert(votedPlayers, playerId)
                end
            end
        elseif i == 2 then
            -- Party Mode - show players who voted for party mode
            votedPlayers = levelSelector.partyModeVotes
        end
        
        -- Draw player pictures under the option with enhanced styling
        if #votedPlayers > 0 then
            local picSize = 24
            local picSpacing = 6
            local startX = (BASE_WIDTH - (#votedPlayers * (picSize + picSpacing))) / 2
            local picY = y + 28
            
            for j, playerId in ipairs(votedPlayers) do
                if players[playerId] then
                    local picX = startX + (j-1) * (picSize + picSpacing)
                    
                    -- Glow effect behind player icon
                    local glowPulse = math.sin(gameModeSelection.animationTime * 3 + j) * 0.3 + 0.7
                    love.graphics.setColor(players[playerId].color[1], players[playerId].color[2], players[playerId].color[3], 0.4 * glowPulse)
                    love.graphics.rectangle("fill", picX - 3, picY - 3, picSize + 6, picSize + 6, 4, 4)
                    
                    -- Draw player color square with rounded corners
                    love.graphics.setColor(players[playerId].color[1], players[playerId].color[2], players[playerId].color[3], 1)
                    love.graphics.rectangle("fill", picX, picY, picSize, picSize, 3, 3)
                    
                    -- Draw player face if available
                    if players[playerId].facePoints and type(players[playerId].facePoints) == "userdata" then
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(
                            players[playerId].facePoints,
                            picX, picY,
                            0,
                            picSize/100, picSize/100
                        )
                    end
                    
                    -- Draw fancy border with glow
                    love.graphics.setColor(1, 1, 1, glowPulse)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", picX, picY, picSize, picSize, 3, 3)
                    love.graphics.setLineWidth(1)
                end
            end
            
            -- Vote count badge
            local badgeX = BASE_WIDTH / 2 - 30
            local badgeY = picY + picSize + 5
            love.graphics.setColor(1, 0.8, 0, 0.9)
            love.graphics.rectangle("fill", badgeX, badgeY, 60, 20, 10, 10)
            love.graphics.setColor(0.4, 0.3, 0, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", badgeX, badgeY, 60, 20, 10, 10)
            love.graphics.setLineWidth(1)
            
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.1, 0.1, 0.1, 1)
            love.graphics.printf(#votedPlayers .. " VOTE" .. (#votedPlayers > 1 and "S" or ""), badgeX, badgeY + 3, 60, "center")
        end
        
        ::continue::
    end
    
    -- Mode descriptions
    love.graphics.setColor(0.6, 0.6, 1, 1)
    love.graphics.setFont(fonts.medium)
    if gameModeSelection.selectedMode == 1 then
        love.graphics.printf("Choose specific levels to play", 0, BASE_HEIGHT - 120, BASE_WIDTH, "center")
    elseif gameModeSelection.selectedMode == 2 then
        love.graphics.printf("Random games in party mode", 0, BASE_HEIGHT - 120, BASE_WIDTH, "center")
    elseif gameModeSelection.selectedMode == 3 then
        love.graphics.printf("Start game with random selection from votes", 0, BASE_HEIGHT - 120, BASE_WIDTH, "center")
    elseif gameModeSelection.selectedMode == 4 then
        love.graphics.printf("Start game with host's selected level", 0, BASE_HEIGHT - 120, BASE_WIDTH, "center")
    end
    
    -- Instructions
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.printf("CLICK or press SPACE to select, ESC to cancel", 0, BASE_HEIGHT - 80, BASE_WIDTH, "center")
end

local function drawLevelSelector()
    if not levelSelector.active then return end
    
    loadLevelSelectorImages()
    
    -- Fancy gradient overlay
    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle('fill', 0, 0, BASE_WIDTH, BASE_HEIGHT)
    
    -- Multiple animated borders
    local pulse = math.sin(levelSelector.animationTime * 3) * 0.2 + 0.8
    local pulse2 = math.sin(levelSelector.animationTime * 4 + 0.5) * 0.15 + 0.7
    
    -- Outer glow
    love.graphics.setColor(0.6, 0, 1, pulse2 * 0.3)
    love.graphics.setLineWidth(12)
    love.graphics.rectangle('line', 45, 45, BASE_WIDTH - 90, BASE_HEIGHT - 90)
    
    -- Main border
    love.graphics.setColor(0.2, 1, 0.6, pulse)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle('line', 50, 50, BASE_WIDTH - 100, BASE_HEIGHT - 100)
    
    -- Inner highlight
    love.graphics.setColor(0.5, 1, 0.9, pulse * 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', 55, 55, BASE_WIDTH - 110, BASE_HEIGHT - 110)
    love.graphics.setLineWidth(1)
    
    -- Title with effects
    local titlePulse = math.sin(levelSelector.animationTime * 2) * 0.3 + 0.7
    love.graphics.setFont(fonts.huge)
    
    -- Title shadow
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.printf("SELECT LEVEL", 0, 83, BASE_WIDTH, "center")
    
    -- Title glow
    love.graphics.setColor(0.8, 0, 1, titlePulse * 0.5)
    love.graphics.printf("SELECT LEVEL", 0, 79, BASE_WIDTH, "center")
    love.graphics.printf("SELECT LEVEL", 0, 81, BASE_WIDTH, "center")
    
    -- Title main
    love.graphics.setColor(0.4, 1, 0.8, titlePulse)
    love.graphics.printf("SELECT LEVEL", 0, 80, BASE_WIDTH, "center")
    
    -- Instructions
    love.graphics.setColor(0.8, 1, 0.8, 1)
    love.graphics.setFont(fonts.medium)
    if isHost then
        love.graphics.printf("Use WASD or mouse to navigate, SPACE/CLICK to vote/launch, ESC to close", 
            0, 120, BASE_WIDTH, "center")
    else
        love.graphics.printf("Use WASD or mouse to navigate, SPACE/CLICK to vote, ESC to close", 
            0, 120, BASE_WIDTH, "center")
    end
    
    -- Calculate grid positioning
    local totalGridWidth = levelSelector.gridCols * levelSelector.cardWidth + 
                          (levelSelector.gridCols - 1) * levelSelector.cardSpacing
    local startX = (BASE_WIDTH - totalGridWidth) / 2
    local startY = 150
    
    -- Draw level cards
    local currentLevels = levelSelector.pages[levelSelector.currentPage]
    for i, level in ipairs(currentLevels) do
        local row = math.floor((i - 1) / levelSelector.gridCols)
        local col = (i - 1) % levelSelector.gridCols
        local x = startX + col * (levelSelector.cardWidth + levelSelector.cardSpacing)
        local y = startY + row * (levelSelector.cardHeight + levelSelector.cardSpacing)
        local isSelected = i == levelSelector.selectedLevel
        
        local hasVotes = levelSelector.votes[i] and #levelSelector.votes[i] > 0
        
        -- Card shadow
        if not (level.name == "Coming Soon") then
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle('fill', x + 4, y + 4, levelSelector.cardWidth, levelSelector.cardHeight, 8, 8)
        end
        
        -- Card background with gradient effect
        if level.name == "Coming Soon" then
            love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
            love.graphics.rectangle('fill', x, y, levelSelector.cardWidth, levelSelector.cardHeight, 8, 8)
        elseif isSelected then
            local bgPulse = math.sin(levelSelector.animationTime * 4 + i) * 0.15 + 0.85
            local colorShift = math.sin(levelSelector.animationTime * 2 + i * 0.5) * 0.15
            
            -- Outer glow for selected card
            love.graphics.setColor(0, 0.8, 1, 0.4 * bgPulse)
            love.graphics.rectangle('fill', x - 4, y - 4, levelSelector.cardWidth + 8, levelSelector.cardHeight + 8, 10, 10)
            
            -- Main background
            love.graphics.setColor(0.15 + colorShift, 0.3, 0.5, 0.7 * bgPulse)
            love.graphics.rectangle('fill', x, y, levelSelector.cardWidth, levelSelector.cardHeight, 8, 8)
        else
            -- Unselected card with vote highlight
            if hasVotes then
                love.graphics.setColor(0.25, 0.2, 0.15, 0.6)
            else
                love.graphics.setColor(0.15, 0.15, 0.18, 0.5)
            end
            love.graphics.rectangle('fill', x, y, levelSelector.cardWidth, levelSelector.cardHeight, 8, 8)
        end
        
        -- Card border
        if level.name == "Coming Soon" then
            love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', x, y, levelSelector.cardWidth, levelSelector.cardHeight, 8, 8)
        elseif isSelected then
            local bgPulse = math.sin(levelSelector.animationTime * 4 + i) * 0.15 + 0.85
            love.graphics.setColor(0.2, 1, 0.6, bgPulse)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle('line', x, y, levelSelector.cardWidth, levelSelector.cardHeight, 8, 8)
            
            -- Corner accents
            local cornerSize = 10
            love.graphics.setColor(1, 1, 0.2, bgPulse)
            love.graphics.setLineWidth(3)
            love.graphics.line(x + 8, y + cornerSize, x + 8, y + 8, x + cornerSize, y + 8)
            love.graphics.line(x + levelSelector.cardWidth - cornerSize - 8, y + 8, x + levelSelector.cardWidth - 8, y + 8, x + levelSelector.cardWidth - 8, y + cornerSize)
            love.graphics.line(x + 8, y + levelSelector.cardHeight - cornerSize, x + 8, y + levelSelector.cardHeight - 8, x + cornerSize, y + levelSelector.cardHeight - 8)
            love.graphics.line(x + levelSelector.cardWidth - cornerSize - 8, y + levelSelector.cardHeight - 8, x + levelSelector.cardWidth - 8, y + levelSelector.cardHeight - 8, x + levelSelector.cardWidth - 8, y + levelSelector.cardHeight - cornerSize)
        else
            if hasVotes then
                love.graphics.setColor(1, 0.8, 0.2, 0.8)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.4, 0.4, 0.45, 0.7)
                love.graphics.setLineWidth(1)
            end
            love.graphics.rectangle('line', x, y, levelSelector.cardWidth, levelSelector.cardHeight, 8, 8)
        end
        love.graphics.setLineWidth(1)
        
        -- Draw image
        local imageX = x + 8
        local imageY = y + 8
        local imageWidth = levelSelector.cardWidth - 16
        local imageHeight = 60
        
        if levelSelector.loadedImages[i] then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(levelSelector.loadedImages[i], imageX, imageY, 0,
                imageWidth / levelSelector.loadedImages[i]:getWidth(),
                imageHeight / levelSelector.loadedImages[i]:getHeight())
        end
        
        -- Level name
        love.graphics.setFont(fonts.medium)
        if level.name == "Coming Soon" then
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
        elseif isSelected then
            love.graphics.setColor(0, 1, 0, 1)
        else
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
        end
        love.graphics.printf(level.name, x + 8, y + 78, levelSelector.cardWidth - 16, "center")
        
        -- Level description
        love.graphics.setFont(fonts.small)
        if level.name == "Coming Soon" then
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
        else
            love.graphics.setColor(0.7, 0.8, 0.7, 1)
        end
        love.graphics.printf(level.description, x + 8, y + 95, levelSelector.cardWidth - 16, "center")
        
        -- Show character icons with enhanced styling in top-right corner
        if levelSelector.votes[i] and #levelSelector.votes[i] > 0 then
            local iconSize = 20
            local iconStartX = x + levelSelector.cardWidth - 25
            local iconStartY = y + 8
            
            for j, playerId in ipairs(levelSelector.votes[i]) do
                if players[playerId] then
                    -- Calculate position for this icon (stack with slight overlap)
                    local iconX = iconStartX - (math.min(j, 4) - 1) * (iconSize - 5)
                    local iconY = iconStartY + math.floor((j - 1) / 4) * (iconSize + 3)
                    
                    -- Animated glow behind icon
                    local iconPulse = math.sin(levelSelector.animationTime * 4 + j * 0.5) * 0.3 + 0.7
                    love.graphics.setColor(players[playerId].color[1], players[playerId].color[2], players[playerId].color[3], 0.5 * iconPulse)
                    love.graphics.rectangle("fill", iconX - 2, iconY - 2, iconSize + 4, iconSize + 4, 4, 4)
                    
                    -- Draw player color background with rounded corners
                    love.graphics.setColor(players[playerId].color[1], players[playerId].color[2], players[playerId].color[3])
                    love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize, 3, 3)
                    
                    -- Draw player face if available
                    if players[playerId].facePoints and type(players[playerId].facePoints) == "userdata" then
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(
                            players[playerId].facePoints,
                            iconX, iconY,
                            0,
                            iconSize/100, iconSize/100
                        )
                    end
                    
                    -- Glowing border
                    love.graphics.setColor(1, 1, 1, iconPulse)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", iconX, iconY, iconSize, iconSize, 3, 3)
                    love.graphics.setLineWidth(1)
                end
            end
            
            -- Enhanced vote count badge at bottom
            local voteCount = #levelSelector.votes[i]
            local badgeWidth = 70
            local badgeHeight = 22
            local badgeX = x + (levelSelector.cardWidth - badgeWidth) / 2
            local badgeY = y + levelSelector.cardHeight - badgeHeight - 4
            
            -- Badge glow
            local badgePulse = math.sin(levelSelector.animationTime * 3 + i) * 0.2 + 0.8
            love.graphics.setColor(1, 0.8, 0, 0.4 * badgePulse)
            love.graphics.rectangle("fill", badgeX - 2, badgeY - 2, badgeWidth + 4, badgeHeight + 4, 12, 12)
            
            -- Badge background
            love.graphics.setColor(1, 0.7, 0, 0.95)
            love.graphics.rectangle("fill", badgeX, badgeY, badgeWidth, badgeHeight, 10, 10)
            
            -- Badge border
            love.graphics.setColor(1, 1, 0.3, badgePulse)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", badgeX, badgeY, badgeWidth, badgeHeight, 10, 10)
            love.graphics.setLineWidth(1)
            
            -- Vote count text
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.1, 0.05, 0, 1)
            love.graphics.printf(voteCount .. " VOTE" .. (voteCount > 1 and "S" or ""), badgeX, badgeY + 4, badgeWidth, "center")
        end
    end
    
    -- Draw party mode votes display if any
    if #levelSelector.partyModeVotes > 0 then
        local partyVotesY = startY + levelSelector.gridRows * (levelSelector.cardHeight + levelSelector.cardSpacing) + 20
        love.graphics.setColor(0.8, 0.4, 1, 1)
        love.graphics.setFont(fonts.medium)
        love.graphics.printf("Party Mode Votes (" .. #levelSelector.partyModeVotes .. "):",
            0, partyVotesY, BASE_WIDTH, "center")
        
        -- Show player names who voted for party mode
        local playerNames = {}
        for _, playerId in ipairs(levelSelector.partyModeVotes) do
            if players[playerId] then
                table.insert(playerNames, players[playerId].name)
            end
        end
        
        if #playerNames > 0 then
            love.graphics.setColor(0.6, 0.3, 0.8, 1)
            love.graphics.setFont(fonts.small)
            love.graphics.printf(table.concat(playerNames, ", "),
                0, partyVotesY + 20, BASE_WIDTH, "center")
        end
    end
end

function lobby.draw()
    -- Draw background
    love.graphics.setColor(1, 1, 1, 1)
    if lobbyBackground then
        love.graphics.draw(lobbyBackground, 0, 0)
    end
    
    -- Don't draw players if menus are active
    if not gameModeSelection.active and not levelSelector.active then
        -- Draw title
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.xlarge)
        love.graphics.printf("=== LOBBY ===", 0, 20, BASE_WIDTH, "center")
        
        -- Draw player count
        local playerCount = 0
        for _ in pairs(players) do playerCount = playerCount + 1 end
        love.graphics.setFont(fonts.medium)
        love.graphics.printf("Players: " .. playerCount, 0, 60, BASE_WIDTH, "center")
        
        -- Debug: Show local player ID
        love.graphics.setFont(fonts.small)
        love.graphics.printf("Local ID: " .. tostring(localPlayer.id), 0, 80, BASE_WIDTH, "center")
        
        -- Draw all players with movement
        for id, player in pairs(players) do
            if player and player.color then
                -- Draw player square (30x30)
                love.graphics.setColor(player.color[1], player.color[2], player.color[3])
                love.graphics.rectangle("fill", player.x, player.y, 30, 30)
                
                -- Draw face image if it exists
                if player.facePoints and type(player.facePoints) == "userdata" then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        player.facePoints,
                        player.x,
                        player.y,
                        0,
                        30/100,
                        30/100
                    )
                end
                
                -- Draw player name above
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(fonts.small)
                love.graphics.printf(
                    player.name or "Player " .. id,
                    player.x - 30,
                    player.y - 20,
                    100,
                    "center"
                )
                
                -- Draw player score below
                love.graphics.setColor(1, 1, 0)
                love.graphics.printf(
                    "Score: " .. math.floor(player.totalScore or 0),
                    player.x - 30,
                    player.y + 35,
                    100,
                    "center"
                )
            end
        end
        
        -- Draw instructions at bottom
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.medium)
        love.graphics.printf("Use WASD to move | SPACE to select game", 0, 500, BASE_WIDTH, "center")
        love.graphics.printf("ESC to leave lobby", 0, 525, BASE_WIDTH, "center")
        
        -- Connection status
        love.graphics.setColor(0.5, 1, 0.5)
        love.graphics.setFont(fonts.small)
        love.graphics.print("Connected", 10, 10)
        if isHost then
            love.graphics.print("Role: Host", 10, 25)
        else
            love.graphics.print("Role: Client", 10, 25)
        end
    end
    
    -- Draw overlays
    drawGameModeSelection()
    drawLevelSelector()
    
    -- Draw vote particles on top of everything
    drawVoteParticles()
end

function lobby.keypressed(k) 
    if levelSelector.active then
        -- Level selector navigation
        if k == "w" or k == "up" then
            local currentRow = math.floor((levelSelector.selectedLevel - 1) / levelSelector.gridCols)
            if currentRow > 0 then
                levelSelector.selectedLevel = levelSelector.selectedLevel - levelSelector.gridCols
            end
        elseif k == "s" or k == "down" then
            local currentLevels = levelSelector.pages[levelSelector.currentPage]
            local currentRow = math.floor((levelSelector.selectedLevel - 1) / levelSelector.gridCols)
            if currentRow < levelSelector.gridRows - 1 and 
               levelSelector.selectedLevel + levelSelector.gridCols <= #currentLevels then
                levelSelector.selectedLevel = levelSelector.selectedLevel + levelSelector.gridCols
            end
        elseif k == "a" or k == "left" then
            if levelSelector.selectedLevel > 1 then
                levelSelector.selectedLevel = levelSelector.selectedLevel - 1
            end
        elseif k == "d" or k == "right" then
            local currentLevels = levelSelector.pages[levelSelector.currentPage]
            if levelSelector.selectedLevel < #currentLevels then
                levelSelector.selectedLevel = levelSelector.selectedLevel + 1
            end
        elseif k == "space" then
            -- SPACE to vote for selected level
            local selectedLevel = levelSelector.pages[levelSelector.currentPage][levelSelector.selectedLevel]
            if selectedLevel and selectedLevel.name ~= "Coming Soon" then
                -- Remove previous vote
                if levelSelector.playerVotes[localPlayer.id] then
                    local oldVote = levelSelector.playerVotes[localPlayer.id]
                    if levelSelector.votes[oldVote] then
                        for i, pid in ipairs(levelSelector.votes[oldVote]) do
                            if pid == localPlayer.id then
                                table.remove(levelSelector.votes[oldVote], i)
                                break
                            end
                        end
                    end
                end
                
                -- Remove party mode vote if exists
                for i, pid in ipairs(levelSelector.partyModeVotes) do
                    if pid == localPlayer.id then
                        table.remove(levelSelector.partyModeVotes, i)
                        break
                    end
                end
                
                -- Add new vote
                levelSelector.playerVotes[localPlayer.id] = levelSelector.selectedLevel
                if not levelSelector.votes[levelSelector.selectedLevel] then
                    levelSelector.votes[levelSelector.selectedLevel] = {}
                end
                table.insert(levelSelector.votes[levelSelector.selectedLevel], localPlayer.id)
                
                -- Emit vote event for multiplayer sync
                events.emit("lobby:level_vote", {
                    playerId = localPlayer.id,
                    levelIndex = levelSelector.selectedLevel,
                    pageIndex = levelSelector.currentPage
                })
                
                -- Create vote particles at card position
                local currentLevels = levelSelector.pages[levelSelector.currentPage]
                local row = math.floor((levelSelector.selectedLevel - 1) / levelSelector.gridCols)
                local col = (levelSelector.selectedLevel - 1) % levelSelector.gridCols
                local totalGridWidth = levelSelector.gridCols * levelSelector.cardWidth + 
                                      (levelSelector.gridCols - 1) * levelSelector.cardSpacing
                local startX = (BASE_WIDTH - totalGridWidth) / 2
                local startY = 150
                local cardX = startX + col * (levelSelector.cardWidth + levelSelector.cardSpacing)
                local cardY = startY + row * (levelSelector.cardHeight + levelSelector.cardSpacing)
                
                -- Spawn multiple particles
                for i = 1, 15 do
                    createVoteParticle(
                        cardX + levelSelector.cardWidth / 2, 
                        cardY + levelSelector.cardHeight / 2,
                        localPlayer.color or {1, 1, 0}
                    )
                end
                
                -- TODO: Send vote to server
                -- events.emit("vote:cast", {level = levelSelector.selectedLevel})
            end
        elseif k == "return" and isHost then
            -- Launch selected game
            local selectedLevel = levelSelector.pages[levelSelector.currentPage][levelSelector.selectedLevel]
            if selectedLevel and selectedLevel.name ~= "Coming Soon" then
                local gameModes = {"jump", "laser", "meteorshower", "dodge", "praise"}
                local modeIndex = levelSelector.selectedLevel
                if modeIndex >= 1 and modeIndex <= 5 then
                    levelSelector.active = false
                    gameModeSelection.active = false
                    events.emit("intent:start_game", {mode = gameModes[modeIndex]})
                end
            end
        elseif k == "escape" then
            levelSelector.active = false
            gameModeSelection.active = true
        end
        
    elseif gameModeSelection.active then
        -- Game mode selection navigation
        if k == "w" or k == "up" then
            gameModeSelection.selectedMode = gameModeSelection.selectedMode - 1
            if gameModeSelection.selectedMode < 1 then
                gameModeSelection.selectedMode = isHost and 4 or 2
            end
            -- Skip Play/Play Now for clients
            if not isHost and (gameModeSelection.selectedMode == 3 or gameModeSelection.selectedMode == 4) then
                gameModeSelection.selectedMode = 2
            end
        elseif k == "s" or k == "down" then
            gameModeSelection.selectedMode = gameModeSelection.selectedMode + 1
            local maxMode = isHost and 4 or 2
            if gameModeSelection.selectedMode > maxMode then
                gameModeSelection.selectedMode = 1
            end
            -- Skip Play/Play Now for clients
            if not isHost and (gameModeSelection.selectedMode == 3 or gameModeSelection.selectedMode == 4) then
                gameModeSelection.selectedMode = 1
            end
        elseif k == "space" then
            -- Select current mode
            if gameModeSelection.selectedMode == 1 then
                -- Open Level Selector
                gameModeSelection.active = false
                levelSelector.active = true
                levelSelector.animationTime = 0
            elseif gameModeSelection.selectedMode == 2 then
                -- Party Mode vote
                gameModeSelection.active = false
                
                -- Remove previous individual game vote
                if levelSelector.playerVotes[localPlayer.id] then
                    local oldVote = levelSelector.playerVotes[localPlayer.id]
                    if levelSelector.votes[oldVote] then
                        for i, pid in ipairs(levelSelector.votes[oldVote]) do
                            if pid == localPlayer.id then
                                table.remove(levelSelector.votes[oldVote], i)
                                break
                            end
                        end
                    end
                    levelSelector.playerVotes[localPlayer.id] = nil
                end
                
                -- Toggle party mode vote
                local alreadyVoted = false
                for i, pid in ipairs(levelSelector.partyModeVotes) do
                    if pid == localPlayer.id then
                        table.remove(levelSelector.partyModeVotes, i)
                        alreadyVoted = true
                        break
                    end
                end
                
                if not alreadyVoted then
                    table.insert(levelSelector.partyModeVotes, localPlayer.id)
                    
                    -- Create party mode vote particles (purple/pink theme)
                    for i = 1, 20 do
                        createVoteParticle(
                            BASE_WIDTH / 2, 
                            BASE_HEIGHT / 2,
                            {0.8 + math.random() * 0.2, 0.2, 1}
                        )
                    end
                end
                
                -- Emit party mode vote event for multiplayer sync
                events.emit("lobby:party_vote", {
                    playerId = localPlayer.id,
                    voted = not alreadyVoted  -- true if voting, false if unvoting
                })
            elseif gameModeSelection.selectedMode == 3 then
                -- Play - random from votes (host only)
                if isHost then
                    gameModeSelection.active = false
                    
                    -- Count total votes
                    local totalVotes = 0
                    for _, votes in pairs(levelSelector.votes) do
                        totalVotes = totalVotes + #votes
                    end
                    
                    -- If there are votes, randomly select from them
                    if totalVotes > 0 then
                        -- Create weighted list of games based on votes
                        local weightedGames = {}
                        for levelIndex, votes in pairs(levelSelector.votes) do
                            for _ = 1, #votes do
                                table.insert(weightedGames, levelIndex)
                            end
                        end
                        
                        -- Randomly select
                        local randomIndex = math.random(1, #weightedGames)
                        local selectedGame = weightedGames[randomIndex]
                        
                        -- Launch the selected game
                        local gameModes = {"jump", "laser", "meteorshower", "dodge", "praise"}
                        if selectedGame >= 1 and selectedGame <= 5 then
                            events.emit("intent:start_game", {mode = gameModes[selectedGame]})
                        end
                    else
                        -- No votes, start party mode by default
                        events.emit("intent:start_game", {mode = "jump", partyMode = true})
                    end
                end
            elseif gameModeSelection.selectedMode == 4 then
                -- Play Now - host's selected level (host only)
                if isHost then
                    local selectedLevel = levelSelector.pages[levelSelector.currentPage][levelSelector.selectedLevel]
                    if selectedLevel and selectedLevel.name ~= "Coming Soon" then
                        local gameModes = {"jump", "laser", "meteorshower", "dodge", "praise"}
                        local modeIndex = levelSelector.selectedLevel
                        if modeIndex >= 1 and modeIndex <= 5 then
                            gameModeSelection.active = false
                            events.emit("intent:start_game", {mode = gameModes[modeIndex]})
                        end
                    end
                end
            end
        elseif k == "escape" then
            gameModeSelection.active = false
        end
        
    else
        -- Regular lobby controls
        if k == "space" then
            -- SPACE opens game mode selection
            gameModeSelection.active = true
            gameModeSelection.animationTime = 0
        elseif k == "escape" then
            events.emit("intent:leave_lobby")
        end
    end
end

-- Check if any voting menus are active
function lobby.hasActiveMenus()
    return gameModeSelection.active or levelSelector.active
end

-- Helper function to check if mouse is over a button
local function isMouseOverButton(x, y, buttonX, buttonY, buttonWidth, buttonHeight)
    return x >= buttonX and x <= buttonX + buttonWidth and
           y >= buttonY and y <= buttonY + buttonHeight
end

function lobby.mousepressed(x, y, button)
    if button ~= 1 then return false end
    
    -- Handle level selector clicks
    if levelSelector.active then
        -- Check for level card clicks
        local currentLevels = levelSelector.pages[levelSelector.currentPage]
        local totalGridWidth = levelSelector.gridCols * levelSelector.cardWidth + 
                              (levelSelector.gridCols - 1) * levelSelector.cardSpacing
        local startX = (BASE_WIDTH - totalGridWidth) / 2
        local startY = 150
        
        for i, level in ipairs(currentLevels) do
            local row = math.floor((i - 1) / levelSelector.gridCols)
            local col = (i - 1) % levelSelector.gridCols
            local cardX = startX + col * (levelSelector.cardWidth + levelSelector.cardSpacing)
            local cardY = startY + row * (levelSelector.cardHeight + levelSelector.cardSpacing)
            
            if isMouseOverButton(x, y, cardX, cardY, levelSelector.cardWidth, levelSelector.cardHeight) then
                levelSelector.selectedLevel = i
                
                -- Vote for this level if it's not "Coming Soon"
                if level.name ~= "Coming Soon" then
                    -- Remove previous vote
                    if levelSelector.playerVotes[localPlayer.id] then
                        local oldVote = levelSelector.playerVotes[localPlayer.id]
                        if levelSelector.votes[oldVote] then
                            for j, pid in ipairs(levelSelector.votes[oldVote]) do
                                if pid == localPlayer.id then
                                    table.remove(levelSelector.votes[oldVote], j)
                                    break
                                end
                            end
                        end
                    end
                    
                    -- Remove party mode vote if exists
                    for j, pid in ipairs(levelSelector.partyModeVotes) do
                        if pid == localPlayer.id then
                            table.remove(levelSelector.partyModeVotes, j)
                            break
                        end
                    end
                    
                    -- Add new vote
                    levelSelector.playerVotes[localPlayer.id] = i
                    if not levelSelector.votes[i] then
                        levelSelector.votes[i] = {}
                    end
                    table.insert(levelSelector.votes[i], localPlayer.id)
                    
                    -- Create vote particles
                    for j = 1, 15 do
                        createVoteParticle(
                            cardX + levelSelector.cardWidth / 2, 
                            cardY + levelSelector.cardHeight / 2,
                            localPlayer.color or {1, 1, 0}
                        )
                    end
                    
                    -- If host double-clicks (or Enter key), launch the game
                    if isHost then
                        local gameModes = {"jump", "laser", "meteorshower", "dodge", "praise"}
                        local modeIndex = i
                        if modeIndex >= 1 and modeIndex <= 5 then
                            levelSelector.active = false
                            gameModeSelection.active = false
                            events.emit("intent:start_game", {mode = gameModes[modeIndex]})
                        end
                    end
                end
                return true
            end
        end
        
        return true -- Consumed the click
    end
    
    -- Handle game mode selection clicks
    if gameModeSelection.active then
        local centerY = BASE_HEIGHT / 2 - 50
        local optionSpacing = 70
        
        -- Build list of visible modes
        local visibleModes = {}
        for i, mode in ipairs(gameModeSelection.modes) do
            if not ((i == 3 or i == 4) and not isHost) then
                table.insert(visibleModes, {index = i, name = mode})
            end
        end
        
        for i, modeInfo in ipairs(visibleModes) do
            local y = centerY - 40 + (i - 1) * optionSpacing
            local boxWidth = 450
            local boxHeight = 55
            local boxX = (BASE_WIDTH - boxWidth) / 2
            local boxY = y - 18
            
            if isMouseOverButton(x, y, boxX, boxY, boxWidth, boxHeight) then
                gameModeSelection.selectedMode = i
                
                -- Select this mode
                if i == 1 then
                    -- Open Level Selector
                    gameModeSelection.active = false
                    levelSelector.active = true
                    levelSelector.animationTime = 0
                elseif i == 2 then
                    -- Party Mode vote
                    gameModeSelection.active = false
                    
                    -- Remove previous individual game vote
                    if levelSelector.playerVotes[localPlayer.id] then
                        local oldVote = levelSelector.playerVotes[localPlayer.id]
                        if levelSelector.votes[oldVote] then
                            for j, pid in ipairs(levelSelector.votes[oldVote]) do
                                if pid == localPlayer.id then
                                    table.remove(levelSelector.votes[oldVote], j)
                                    break
                                end
                            end
                        end
                        levelSelector.playerVotes[localPlayer.id] = nil
                    end
                    
                    -- Toggle party mode vote
                    local alreadyVoted = false
                    for j, pid in ipairs(levelSelector.partyModeVotes) do
                        if pid == localPlayer.id then
                            table.remove(levelSelector.partyModeVotes, j)
                            alreadyVoted = true
                            break
                        end
                    end
                    
                    if not alreadyVoted then
                        table.insert(levelSelector.partyModeVotes, localPlayer.id)
                        
                        -- Create party mode vote particles
                        for j = 1, 20 do
                            createVoteParticle(
                                BASE_WIDTH / 2, 
                                BASE_HEIGHT / 2,
                                {0.8 + math.random() * 0.2, 0.2, 1}
                            )
                        end
                    end
                elseif i == 3 and isHost then
                    -- Play - random from votes
                    gameModeSelection.active = false
                    
                    -- Count total votes
                    local totalVotes = 0
                    for _, votes in pairs(levelSelector.votes) do
                        totalVotes = totalVotes + #votes
                    end
                    
                    if totalVotes > 0 then
                        -- Create weighted list
                        local weightedGames = {}
                        for levelIndex, votes in pairs(levelSelector.votes) do
                            for _ = 1, #votes do
                                table.insert(weightedGames, levelIndex)
                            end
                        end
                        
                        local randomIndex = math.random(1, #weightedGames)
                        local selectedGame = weightedGames[randomIndex]
                        local gameModes = {"jump", "laser", "meteorshower", "dodge", "praise"}
                        if selectedGame >= 1 and selectedGame <= 5 then
                            events.emit("intent:start_game", {mode = gameModes[selectedGame]})
                        end
                    else
                        events.emit("intent:start_game", {mode = "jump", partyMode = true})
                    end
                elseif i == 4 and isHost then
                    -- Play Now - host's selected level
                    local selectedLevel = levelSelector.pages[levelSelector.currentPage][levelSelector.selectedLevel]
                    if selectedLevel and selectedLevel.name ~= "Coming Soon" then
                        local gameModes = {"jump", "laser", "meteorshower", "dodge", "praise"}
                        local modeIndex = levelSelector.selectedLevel
                        if modeIndex >= 1 and modeIndex <= 5 then
                            gameModeSelection.active = false
                            events.emit("intent:start_game", {mode = gameModes[modeIndex]})
                        end
                    end
                end
                
                return true
            end
        end
        
        return true -- Consumed the click
    end
    
    return false
end

-- Handle mouse movement for hover effects
function lobby.mousemoved(x, y, dx, dy)
    -- Handle level selector hover
    if levelSelector.active then
        local currentLevels = levelSelector.pages[levelSelector.currentPage]
        local totalGridWidth = levelSelector.gridCols * levelSelector.cardWidth + 
                              (levelSelector.gridCols - 1) * levelSelector.cardSpacing
        local startX = (BASE_WIDTH - totalGridWidth) / 2
        local startY = 150
        
        for i, level in ipairs(currentLevels) do
            local row = math.floor((i - 1) / levelSelector.gridCols)
            local col = (i - 1) % levelSelector.gridCols
            local cardX = startX + col * (levelSelector.cardWidth + levelSelector.cardSpacing)
            local cardY = startY + row * (levelSelector.cardHeight + levelSelector.cardSpacing)
            
            if isMouseOverButton(x, y, cardX, cardY, levelSelector.cardWidth, levelSelector.cardHeight) then
                levelSelector.selectedLevel = i
                return true
            end
        end
        
        return true
    end
    
    -- Handle game mode selection hover
    if gameModeSelection.active then
        local centerY = BASE_HEIGHT / 2 - 50
        local optionSpacing = 70
        
        -- Build list of visible modes
        local visibleModes = {}
        for i, mode in ipairs(gameModeSelection.modes) do
            if not ((i == 3 or i == 4) and not isHost) then
                table.insert(visibleModes, {index = i, name = mode})
            end
        end
        
        for i, modeInfo in ipairs(visibleModes) do
            local y = centerY - 40 + (i - 1) * optionSpacing
            local boxWidth = 450
            local boxHeight = 55
            local boxX = (BASE_WIDTH - boxWidth) / 2
            local boxY = y - 18
            
            if isMouseOverButton(x, y, boxX, boxY, boxWidth, boxHeight) then
                gameModeSelection.selectedMode = i
                return true
            end
        end
        
        return true
    end
    
    return false
end

-- Update players from network
function lobby.setPlayers(newPlayers)
    print("[Lobby] setPlayers called")
    local count = 0
    for id in pairs(newPlayers) do 
        count = count + 1
        print("[Lobby] Received player ID: " .. tostring(id) .. ", name: " .. tostring(newPlayers[id].name))
    end
    print("[Lobby] Total players received: " .. count)
    print("[Lobby] Local player ID: " .. tostring(localPlayer.id))
    
    -- Merge new players with existing, preserving movement
    for id, newPlayer in pairs(newPlayers) do
        if players[id] then
            -- Keep local position for local player
            if id ~= localPlayer.id then
                -- Preserve position data if it exists
                local existingX = players[id].x
                local existingY = players[id].y
                players[id] = newPlayer
                players[id].x = newPlayer.x or existingX or (200 + id * 50)
                players[id].y = newPlayer.y or existingY or (200 + id * 30)
                print("[Lobby] Updated existing player: " .. tostring(id))
            else
                -- Update local player data from host (especially name) but keep position
                local existingX = players[id].x
                local existingY = players[id].y
                players[id] = newPlayer
                players[id].x = existingX
                players[id].y = existingY
                -- Sync local player name with host's version
                localPlayer.name = newPlayer.name or localPlayer.name
                localPlayer.color = newPlayer.color or localPlayer.color
                print("[Lobby] Updated local player from host, name: " .. tostring(localPlayer.name))
            end
        else
            -- New player - initialize with position if missing
            players[id] = newPlayer
            players[id].x = newPlayer.x or (200 + id * 50)
            players[id].y = newPlayer.y or (200 + id * 30)
            print("[Lobby] Added new player: " .. tostring(id))
            
            -- If this is our player ID, update local player data
            if id == localPlayer.id then
                localPlayer.name = newPlayer.name or localPlayer.name
                localPlayer.color = newPlayer.color or localPlayer.color
                print("[Lobby] This is local player, updated name to: " .. tostring(localPlayer.name))
            end
        end
        
        -- Ensure color exists
        if not players[id].color then
            players[id].color = {math.random(), math.random(), math.random()}
        end
    end
    
    local finalCount = 0
    for _ in pairs(players) do finalCount = finalCount + 1 end
    print("[Lobby] Final player count in lobby: " .. finalCount)
    
    _G.players = players
end

function lobby.setLocalPlayerId(playerId)
    print("[Lobby] Setting local player ID to: " .. tostring(playerId))
    localPlayer.id = playerId
    
    -- Update the player entry if it already exists (from host's STATE message)
    if playerId and players[playerId] then
        print("[Lobby] Player entry already exists, syncing with host data")
        -- Use the host's data as the source of truth (especially for name)
        -- Only preserve local position since we control our own movement
        players[playerId].x = localPlayer.x
        players[playerId].y = localPlayer.y
        
        -- Update local player with host's data (especially the name which may have been modified)
        localPlayer.name = players[playerId].name or localPlayer.name
        localPlayer.color = players[playerId].color or localPlayer.color
        localPlayer.facePoints = players[playerId].facePoints or localPlayer.facePoints
        localPlayer.totalScore = players[playerId].totalScore or localPlayer.totalScore
        
        print("[Lobby] Local player name updated to: " .. tostring(localPlayer.name))
    elseif playerId then
        -- Add new player entry if it doesn't exist yet
        print("[Lobby] Adding local player to players table")
        players[playerId] = {
            x = localPlayer.x,
            y = localPlayer.y,
            color = localPlayer.color,
            id = localPlayer.id,
            facePoints = localPlayer.facePoints,
            name = localPlayer.name,
            totalScore = localPlayer.totalScore
        }
    end
    
    print("[Lobby] After setLocalPlayerId, player count: " .. tostring(#players))
    for id in pairs(players) do
        print("[Lobby] Player in table: " .. tostring(id))
    end
end

-- Handle incoming level vote from network
function lobby.handleLevelVote(msg)
    if not msg.playerId or not msg.levelIndex then return end
    
    print("[Lobby] Received level vote from player " .. msg.playerId .. " for level " .. msg.levelIndex)
    
    -- Remove previous vote
    if levelSelector.playerVotes[msg.playerId] then
        local oldVote = levelSelector.playerVotes[msg.playerId]
        if levelSelector.votes[oldVote] then
            for i, pid in ipairs(levelSelector.votes[oldVote]) do
                if pid == msg.playerId then
                    table.remove(levelSelector.votes[oldVote], i)
                    break
                end
            end
        end
    end
    
    -- Remove party mode vote if exists
    for i, pid in ipairs(levelSelector.partyModeVotes) do
        if pid == msg.playerId then
            table.remove(levelSelector.partyModeVotes, i)
            break
        end
    end
    
    -- Add new vote
    levelSelector.playerVotes[msg.playerId] = msg.levelIndex
    if not levelSelector.votes[msg.levelIndex] then
        levelSelector.votes[msg.levelIndex] = {}
    end
    table.insert(levelSelector.votes[msg.levelIndex], msg.playerId)
end

-- Handle incoming party mode vote from network
function lobby.handlePartyVote(msg)
    if not msg.playerId then return end
    
    print("[Lobby] Received party mode vote from player " .. msg.playerId .. " (voted: " .. tostring(msg.voted) .. ")")
    
    -- Remove previous individual game vote
    if levelSelector.playerVotes[msg.playerId] then
        local oldVote = levelSelector.playerVotes[msg.playerId]
        if levelSelector.votes[oldVote] then
            for i, pid in ipairs(levelSelector.votes[oldVote]) do
                if pid == msg.playerId then
                    table.remove(levelSelector.votes[oldVote], i)
                    break
                end
            end
        end
        levelSelector.playerVotes[msg.playerId] = nil
    end
    
    -- Remove existing party mode vote
    for i, pid in ipairs(levelSelector.partyModeVotes) do
        if pid == msg.playerId then
            table.remove(levelSelector.partyModeVotes, i)
            break
        end
    end
    
    -- Add party mode vote if voted is true
    if msg.voted then
        table.insert(levelSelector.partyModeVotes, msg.playerId)
    end
end

return lobby
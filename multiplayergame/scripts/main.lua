-- CHANGE LOG:
-- problem with host playing game causing guest disconnect. 
-- problem with only host being able to change colors.


local enet = require "enet"
local anim8 = require "scripts.anim8"
local jumpGame = require "scripts.jumpgame"
local laserGame = require "scripts.lasergame"
local battleRoyale = require "scripts.battleroyale"
local dodgeGame = require "scripts.dodgegame"
local characterCustomization = require "scripts.charactercustom"
local scoreLobby = require "scripts.scorelobby"
local debugConsole = require "scripts.debugconsole"
local musicHandler = require "scripts.musichandler"
local instructions = require "scripts.instructions"
local savefile = require "scripts.savefile"
local returnState = "playing"
local afterCustomization = nil
local connectionAttempted = false
local statusMessages = {}
local postGameSceneDuration = 3
local host
local server
local peerToId = {}
local connected = false
local players = {}
local localPlayer = {x = 100, y = 100, color = {1, 0, 0}, id = 0, totalScore = 0, name = "Player"}

-- Load saved player data
function loadPlayerData()
    local savedData = savefile.loadPlayerData()
    localPlayer.name = savedData.name
    localPlayer.color = savedData.color
    localPlayer.facePoints = savedData.facePoints
    debugConsole.addMessage("[Load] Loaded player data: " .. localPlayer.name)
end
local serverStatus = "Unknown"
local nextClientId = 1
local menuBackground = nil
local lobbyBackground = nil
local partyMode = false
_G.partyMode = partyMode -- Make it globally accessible
local currentPartyGame = nil
local isFirstPartyInstruction = true
local partyModeTransitioned = false -- Prevent multiple transitions

-- Round tracking system
local currentRound = 1
local maxRounds = 3
local roundWins = {} -- Track wins per player: {playerId = wins}
local showScoreDisplay = false
local scoreDisplayTimer = 0
local scoreDisplayDuration = 3 -- Show for 3 seconds

-- Tab menu system
local tabMenu = {
    visible = false,
    maxPlayers = 8,
    tabHeld = false
}

-- Function to sort players by score then name
local function sortPlayersForTab()
    local sortedPlayers = {}
    
    -- Convert players table to array for sorting
    for id, player in pairs(players) do
        table.insert(sortedPlayers, {
            id = id,
            name = player.name or "Player",
            totalScore = player.totalScore or 0
        })
    end
    
    -- Sort by score (descending) then by name (ascending)
    table.sort(sortedPlayers, function(a, b)
        if a.totalScore ~= b.totalScore then
            return a.totalScore > b.totalScore
        end
        return a.name < b.name
    end)
    
    return sortedPlayers
end

-- Function to get medal color for position
local function getMedalColor(position)
    if position == 1 then
        return {1, 0.84, 0} -- Gold
    elseif position == 2 then
        return {0.75, 0.75, 0.75} -- Silver
    elseif position == 3 then
        return {0.8, 0.5, 0.2} -- Bronze
    else
        return {1, 1, 1} -- White
    end
end

-- Function to get unique player name (adds suffix for duplicates)
local function getUniquePlayerName(baseName, currentPlayerId)
    -- Check if the base name is already taken by another player
    local nameExists = false
    for id, player in pairs(players) do
        if id ~= currentPlayerId and player.name == baseName then
            nameExists = true
            break
        end
    end
    
    if not nameExists then
        return baseName
    end
    
    -- Find the next available suffix
    local suffix = 2
    local testName = baseName .. " - " .. suffix
    
    while true do
        local nameTaken = false
        for id, player in pairs(players) do
            if id ~= currentPlayerId and player.name == testName then
                nameTaken = true
                break
            end
        end
        
        if not nameTaken then
            return testName
        end
        
        suffix = suffix + 1
        testName = baseName .. " - " .. suffix
    end
end

-- Function to draw voting panel showing all players and their votes
local function drawVotingPanel()
    -- Safety check - only draw if levelSelector is available
    if not levelSelector then
        debugConsole.addMessage("[VotingPanel] levelSelector not available")
        return
    end
    
    debugConsole.addMessage("[VotingPanel] Drawing voting panel - Player votes: " .. (levelSelector.playerVotes and #levelSelector.playerVotes or 0))
    debugConsole.addMessage("[VotingPanel] Total players: " .. #table_keys(players))
    for id, player in pairs(players) do
        local votedLevel = levelSelector.playerVotes and levelSelector.playerVotes[id]
        debugConsole.addMessage("[VotingPanel] Player " .. id .. " voted for: " .. tostring(votedLevel))
    end
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local panelWidth = 400  -- Increased width for bigger icons
    local panelHeight = 300  -- Increased height for bigger icons
    local panelX = screenWidth - panelWidth - 20
    local panelY = 80
    
    -- Panel background (more visible)
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight)
    love.graphics.setLineWidth(1)
    
    -- Panel title
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("VOTING STATUS", panelX, panelY + 10, panelWidth, "center")
    
    -- Draw players and their votes
    local yOffset = 40
    local lineHeight = 70  -- Much bigger for 60x60 icons
    
    for id, player in pairs(players) do
        if player.name then
            -- Player color indicator (MUCH bigger: 60x60)
            love.graphics.setColor(player.color[1], player.color[2], player.color[3], 1)
            love.graphics.rectangle("fill", panelX + 10, panelY + yOffset, 60, 60)
            
            -- Draw player face if available
            if player.facePoints and type(player.facePoints) == "userdata" then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    player.facePoints,
                    panelX + 10, panelY + yOffset,
                    0,
                    60/100, 60/100  -- Scale from 100x100 to 60x60
                )
            end
            
            -- Add a thick border to make the icon very visible
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle("line", panelX + 10, panelY + yOffset, 60, 60)
            love.graphics.setLineWidth(1)
            
            -- Player name
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(love.graphics.newFont(16))
            love.graphics.printf(player.name, panelX + 80, panelY + yOffset + 10, 150, "left")
            
            -- Show what they voted for
            local votedLevel = levelSelector.playerVotes[id]
            if votedLevel and levelSelector.pages[levelSelector.currentPage] and levelSelector.pages[levelSelector.currentPage][votedLevel] then
                love.graphics.setColor(0.7, 0.7, 0.7, 1)
                love.graphics.setFont(love.graphics.newFont(14))
                love.graphics.printf("→ " .. levelSelector.pages[levelSelector.currentPage][votedLevel].name, panelX + 80, panelY + yOffset + 30, 200, "left")
            else
                love.graphics.setColor(0.5, 0.5, 0.5, 1)
                love.graphics.setFont(love.graphics.newFont(14))
                love.graphics.printf("→ No vote", panelX + 80, panelY + yOffset + 30, 200, "left")
            end
            
            yOffset = yOffset + lineHeight
            
            -- Stop if we're running out of space
            if yOffset > panelHeight - 20 then
                break
            end
        end
    end
end

-- Function to draw tab menu
local function drawTabMenu()
    if not tabMenu.visible then return end
    
    local sortedPlayers = sortPlayersForTab()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Draw semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Tab menu background
    local menuWidth = 400
    local menuHeight = math.min(#sortedPlayers * 50 + 60, tabMenu.maxPlayers * 50 + 60)
    local menuX = (screenWidth - menuWidth) / 2
    local menuY = (screenHeight - menuHeight) / 2
    
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
    
    -- Title
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf("Player List", menuX, menuY + 10, menuWidth, "center")
    
    -- Draw players (up to maxPlayers)
    local startY = menuY + 50
    local maxToShow = math.min(#sortedPlayers, tabMenu.maxPlayers)
    
    for i = 1, maxToShow do
        local player = sortedPlayers[i]
        local y = startY + (i - 1) * 45
        local medalColor = getMedalColor(i)
        
        -- Player background
        love.graphics.setColor(0.2, 0.2, 0.2, 0.3)
        love.graphics.rectangle("fill", menuX + 10, y, menuWidth - 20, 40)
        
        -- Position number
        love.graphics.setColor(medalColor[1], medalColor[2], medalColor[3], 0.9)
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.printf("#" .. i, menuX + 15, y + 12, 50, "left")
        
        -- Player name
        love.graphics.setColor(medalColor[1], medalColor[2], medalColor[3], 0.9)
        love.graphics.setFont(love.graphics.newFont(18))
        love.graphics.printf(player.name, menuX + 70, y + 10, 200, "left")
        
        -- Score
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.printf("Score: " .. player.totalScore, menuX + 280, y + 12, 100, "right")
    end
end

-- Mini game lineup system
local miniGameLineup = {
    "jumpgame",
    "lasergame", 
    "battleroyale",
    "dodgegame"
}
local currentGameIndex = 1

-- Function to shuffle the game lineup
local function shuffleGameLineup()
    local shuffled = {}
    local original = {}
    
    -- Copy the original lineup
    for i = 1, #miniGameLineup do
        original[i] = miniGameLineup[i]
    end
    
    -- Fisher-Yates shuffle algorithm
    for i = #original, 1, -1 do
        local j = math.random(i)
        shuffled[#shuffled + 1] = original[j]
        original[j] = original[i]
    end
    
    return shuffled
end

-- Game mode selection system
local gameModeSelection = {
    active = false,
    selectedMode = 1, -- 1 = Level Selector, 2 = Party Mode
    modes = {"Level Selector", "Party Mode"},
    animationTime = 0
}

-- Level selector system
local levelSelector = {
    active = false,
    selectedLevel = 1,
    currentPage = 1,
    pages = {
        -- Page 1: Current games + Coming Soon
        {
            {name = "Jump Game", description = "Platform jumping challenge", image = "images/jumpintro.png"},
            {name = "Laser Game", description = "Dodge laser beams", image = "images/lasersintro.png"},
            {name = "Battle Royale", description = "Survive the meteor shower", image = "images/menu-background.jpg"},
            {name = "Dodge Laser", description = "Quick reflex dodging", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "New game mode in development", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Exciting content coming soon", image = "images/menu-background.jpg"}
        },
        -- Page 2: Racing Games
        {
            {name = "Coming Soon", description = "High-speed racing action", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Formula 1 style racing", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Off-road adventure racing", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Time trial challenges", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Multiplayer racing tournaments", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Custom track builder", image = "images/menu-background.jpg"}
        },
        -- Page 3: Puzzle Games
        {
            {name = "Coming Soon", description = "Mind-bending puzzle challenges", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Cooperative puzzle solving", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Speed puzzle competitions", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "3D puzzle adventures", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Logic puzzle master", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Creative puzzle designer", image = "images/menu-background.jpg"}
        },
        -- Page 4: Action Games
        {
            {name = "Coming Soon", description = "Epic action adventures", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Combat arena battles", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Stealth mission challenges", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Boss fight showdowns", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Power-up collection races", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Survival mode challenges", image = "images/menu-background.jpg"}
        },
        -- Page 5: Strategy Games
        {
            {name = "Coming Soon", description = "Strategic planning games", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Resource management challenges", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Tower defense battles", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Turn-based strategy", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Real-time strategy combat", image = "images/menu-background.jpg"},
            {name = "Coming Soon", description = "Diplomatic negotiations", image = "images/menu-background.jpg"}
        }
    },
    animationTime = 0,
    votes = {}, -- Track votes: {levelIndex = {playerId1, playerId2, ...}}
    playerVotes = {}, -- Track which level each player voted for: {playerId = levelIndex}
    gridCols = 3, -- Number of columns in the grid
    gridRows = 2, -- Number of rows in the grid (3x2 for 6 games)
    cardWidth = 200,
    cardHeight = 140,
    cardSpacing = 20,
    loadedImages = {}, -- Cache for loaded images
    lastSelectedGame = 1 -- Track the last selected actual game (not Run Game)
}

-- Function to load and cache level selector images
local function loadLevelSelectorImages()
    local currentLevels = levelSelector.pages[levelSelector.currentPage]
    for i, level in ipairs(currentLevels) do
        if not levelSelector.loadedImages[i] then
            local success, image = pcall(love.graphics.newImage, level.image)
            if success then
                levelSelector.loadedImages[i] = image
                debugConsole.addMessage("[LevelSelector] Loaded image for " .. level.name)
            else
                -- Fallback to menu-background.jpg if image fails to load
                local fallbackSuccess, fallbackImage = pcall(love.graphics.newImage, "images/menu-background.jpg")
                if fallbackSuccess then
                    levelSelector.loadedImages[i] = fallbackImage
                    debugConsole.addMessage("[LevelSelector] Using fallback image for " .. level.name)
                else
                    debugConsole.addMessage("[LevelSelector] Failed to load image for " .. level.name)
                end
            end
        end
    end
end

local gameState = "menu"  -- Can be "menu", "play_menu", "settings_menu", "customize_menu", "connecting", "customization", "playing", or "hosting"
local highScore = 0 -- this is high score for jumpgame
local inputIP = "localhost"
local inputPort = "12345"


-- How to add effects to objects:
-- musicHandler.addEffect("player", "bounce") -- Makes player bounce up and down
-- musicHandler.addEffect("enemy", "pulse") -- Makes enemy pulse in size
-- musicHandler.addEffect("background", "colorPulse", {
--     baseColor = {0.5, 0, 1}, -- Purple
--     frequency = 2 -- Twice per beat
-- })


-- UI elements
local buttons = {}
local inputField = {x = 300, y = 250, width = 200, height = 30, text = "localhost", active = false}

-- Server variables
local serverHost
local serverClients = {}

-- Networking variables
local updateRate = 1/20  -- 20 updates per second
local updateTimer = 0

-- Game state synchronization
local gameStateSync = {
    meteoroids = {},
    safeZone = {center_x = 400, center_y = 300, radius = 450},
    gameTime = 0,
    lastSyncTime = 0
}

-- Simple test timer
local testSyncTimer = 0
local debugTestTimer = 0

-- Physics variables
local fixedTimestep = 1/60  -- 60 physics updates per second
local accumulatedTime = 0

-- Debug log system
local debugLog = {}
local MAX_DEBUG_MESSAGES = 10

function addDebugMessage(msg)
    table.insert(debugLog, 1, os.date("%H:%M:%S") .. ": " .. msg)
    if #debugLog > MAX_DEBUG_MESSAGES then
        table.remove(debugLog)
    end
end

-- Round tracking functions
function initializeRoundWins()
    roundWins = {}
    for id, player in pairs(players) do
        roundWins[id] = 0
        -- Initialize game-specific tracking
        players[id].jumpScore = 0
        players[id].laserHits = 0
        players[id].battleScore = 0
        players[id].dodgeScore = 0
    end
    if localPlayer.id then
        roundWins[localPlayer.id] = 0
        if players[localPlayer.id] then
            players[localPlayer.id].jumpScore = 0
            players[localPlayer.id].laserHits = 0
            players[localPlayer.id].battleScore = 0
            players[localPlayer.id].dodgeScore = 0
        end
    end
end

function awardRoundWin(playerId)
    if not roundWins[playerId] then
        roundWins[playerId] = 0
    end
    roundWins[playerId] = roundWins[playerId] + 1
    debugConsole.addMessage(string.format("[Round] Player %d wins round %d! Total wins: %d", playerId, currentRound, roundWins[playerId]))
end

function checkForScoreDisplay()
    if currentRound % maxRounds == 0 then
        showScoreDisplay = true
        scoreDisplayTimer = scoreDisplayDuration
        debugConsole.addMessage("[Score] Showing score display after round " .. currentRound)
    end
end

function updateScoreDisplay(dt)
    if showScoreDisplay then
        scoreDisplayTimer = scoreDisplayTimer - dt
        if scoreDisplayTimer <= 0 then
            showScoreDisplay = false
            currentRound = currentRound + 1
            debugConsole.addMessage("[Round] Starting round " .. currentRound)
        end
    end
end

function showPostGame(gameType)
    showPostGameScene = true
    postGameSceneTimer = postGameSceneDuration
    lastGameType = gameType
    debugConsole.addMessage("[PostGame] Showing " .. gameType .. " completion scene")
end

function updatePostGameScene(dt)
    if showPostGameScene then
        postGameSceneTimer = postGameSceneTimer - dt
        if postGameSceneTimer <= 0 then
            showPostGameScene = false
            debugConsole.addMessage("[PostGame] Scene ended, returning to lobby")
        end
    end
end

function drawPostGameScene()
    if not showPostGameScene then return end
    
    -- Animated background with pulsing effect
    local pulse = math.sin(love.timer.getTime() * 3) * 0.1 + 0.9
    love.graphics.setColor(0.1, 0.1, 0.3, 0.9)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Animated border
    love.graphics.setColor(0.2, 0.6, 1.0, pulse)
    love.graphics.setLineWidth(5)
    love.graphics.rectangle('line', 10, 10, love.graphics.getWidth() - 20, love.graphics.getHeight() - 20)
    love.graphics.setLineWidth(1)
    
    -- Title with glow effect
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.printf("ROUND " .. currentRound .. " COMPLETE!", 
        0, 100, love.graphics.getWidth(), "center")
    
    -- Subtitle
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.printf("Final Results", 
        0, 150, love.graphics.getWidth(), "center")
    
    -- Player leaderboard with better styling
    local y = 250
    local sortedPlayers = {}
    for id, wins in pairs(roundWins) do
        table.insert(sortedPlayers, {id = id, wins = wins})
    end
    
    -- Sort by wins (descending)
    table.sort(sortedPlayers, function(a, b) return a.wins > b.wins end)
    
    for i, playerData in ipairs(sortedPlayers) do
        local player = players[playerData.id]
        if player then
            -- Position background
            local bgAlpha = 0.3 + (i == 1 and 0.3 or 0) -- Highlight first place
            love.graphics.setColor(0.2, 0.2, 0.4, bgAlpha)
            love.graphics.rectangle('fill', 200, y - 10, 400, 60)
            
            -- Position number
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.printf("#" .. i, 220, y + 10, 50, "center")
            
            -- Player color square (larger)
            love.graphics.setColor(player.color[1], player.color[2], player.color[3])
            love.graphics.rectangle('fill', 280, y, 40, 40)
            
            -- Player face if available
            if player.facePoints then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    player.facePoints,
                    280, y,
                    0,
                    40/100,
                    40/100
                )
            end
            
            -- Player wins with larger text
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(string.format("Player %d", playerData.id), 
                340, y + 5, 120, "left")
            
            love.graphics.setColor(0.8, 0.8, 1, 1)
            love.graphics.printf(string.format("%d wins", playerData.wins), 
                340, y + 25, 120, "left")
            
            y = y + 70
        end
    end
    
    -- Timer with pulsing effect
    local timerPulse = math.sin(love.timer.getTime() * 4) * 0.2 + 0.8
    love.graphics.setColor(1, 1, 0, timerPulse)
    love.graphics.printf(string.format("Next round in %.1f seconds...", postGameSceneTimer), 
        0, love.graphics.getHeight() - 100, love.graphics.getWidth(), "center")
    
    -- Press any key message
    love.graphics.setColor(0.6, 0.6, 1, 1)
    love.graphics.printf("Press any key to continue", 
        0, love.graphics.getHeight() - 60, love.graphics.getWidth(), "center")
end

function drawScoreDisplay()
    if not showScoreDisplay then return end
    
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("ROUND " .. (currentRound - 1) .. " COMPLETE!", 
        0, 100, love.graphics.getWidth(), "center")
    
    -- Player scores
    local y = 200
    local sortedPlayers = {}
    for id, wins in pairs(roundWins) do
        table.insert(sortedPlayers, {id = id, wins = wins})
    end
    
    -- Sort by wins (descending)
    table.sort(sortedPlayers, function(a, b) return a.wins > b.wins end)
    
    for i, playerData in ipairs(sortedPlayers) do
        local player = players[playerData.id]
        if player then
            -- Player color
            love.graphics.setColor(player.color[1], player.color[2], player.color[3])
            love.graphics.rectangle('fill', 300, y, 30, 30)
            
            -- Player wins
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(string.format("Player %d: %d wins", playerData.id, playerData.wins), 
                350, y + 5, 200, "left")
            
            y = y + 50
        end
    end
    
    -- Continue message
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("Press any key to continue...", 
        0, love.graphics.getHeight() - 100, love.graphics.getWidth(), "center")
end

function drawGameModeSelection()
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Animated border with pulsing effect
    local pulse = math.sin(gameModeSelection.animationTime * 3) * 0.2 + 0.8
    love.graphics.setColor(0.2, 0.6, 1.0, pulse)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle('line', 50, 50, love.graphics.getWidth() - 100, love.graphics.getHeight() - 100)
    love.graphics.setLineWidth(1)
    
    -- Title with pulsing effect
    local titlePulse = math.sin(gameModeSelection.animationTime * 2) * 0.3 + 0.7
    love.graphics.setColor(1, 1, 0, titlePulse)
    love.graphics.printf("SELECT GAME MODE", 
        0, 100, love.graphics.getWidth(), "center")
    
    -- Subtitle
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.printf("Use W/S to navigate, SPACE to select", 
        0, 140, love.graphics.getWidth(), "center")
    
    -- Game mode options
    local centerY = love.graphics.getHeight() / 2
    local optionSpacing = 80
    
    for i, mode in ipairs(gameModeSelection.modes) do
        local y = centerY - 40 + (i - 1) * optionSpacing
        local isSelected = i == gameModeSelection.selectedMode
        
        -- Background for selected option
        if isSelected then
            local bgPulse = math.sin(gameModeSelection.animationTime * 4 + i) * 0.1 + 0.9
            love.graphics.setColor(0.1, 0.3, 0.6, 0.3 * bgPulse)
            love.graphics.rectangle('fill', 200, y - 20, 400, 60)
        end
        
        -- Option text
        if isSelected then
            love.graphics.setColor(1, 1, 0, 1) -- Yellow for selected
        else
            love.graphics.setColor(0.7, 0.7, 0.7, 1) -- Gray for unselected
        end
        
        love.graphics.printf(mode, 0, y, love.graphics.getWidth(), "center")
        
        -- Selection indicator
        if isSelected then
            love.graphics.setColor(1, 1, 0, pulse)
            love.graphics.printf(">>> " .. mode .. " <<<", 0, y, love.graphics.getWidth(), "center")
        end
    end
    
    -- Mode descriptions
    love.graphics.setColor(0.6, 0.6, 1, 1)
    if gameModeSelection.selectedMode == 1 then
        love.graphics.printf("Choose specific levels to play", 
            0, centerY + 120, love.graphics.getWidth(), "center")
    elseif gameModeSelection.selectedMode == 2 then
        love.graphics.printf("Random games in party mode", 
            0, centerY + 120, love.graphics.getWidth(), "center")
    end
    
    -- Instructions
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.printf("Press ESC to cancel", 
        0, love.graphics.getHeight() - 80, love.graphics.getWidth(), "center")
    
    -- Draw voting panel in top right
    drawVotingPanel()
end

function drawLevelSelector()
    -- Load images if not already loaded
    loadLevelSelectorImages()
    
    -- Debug vote data
    debugConsole.addMessage("[LevelSelector] Drawing level selector - vote data:")
    debugConsole.addMessage("[LevelSelector] levelSelector.votes exists: " .. tostring(levelSelector.votes ~= nil))
    debugConsole.addMessage("[LevelSelector] levelSelector.playerVotes exists: " .. tostring(levelSelector.playerVotes ~= nil))
    for levelIdx, voteList in pairs(levelSelector.votes) do
        debugConsole.addMessage("[LevelSelector] Level " .. levelIdx .. " has " .. #voteList .. " votes")
        for j, playerId in ipairs(voteList) do
            debugConsole.addMessage("[LevelSelector] Level " .. levelIdx .. " vote " .. j .. ": player " .. playerId)
        end
    end
    
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Animated border with pulsing effect
    local pulse = math.sin(levelSelector.animationTime * 3) * 0.2 + 0.8
    love.graphics.setColor(0.2, 0.8, 0.2, pulse)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle('line', 50, 50, love.graphics.getWidth() - 100, love.graphics.getHeight() - 100)
    love.graphics.setLineWidth(1)
    
    -- Title with pulsing effect
    local titlePulse = math.sin(levelSelector.animationTime * 2) * 0.3 + 0.7
    love.graphics.setColor(0, 1, 0, titlePulse)
    
    -- Page-specific titles
    local pageTitles = {
        "SELECT LEVEL - Current Games",
        "SELECT LEVEL - Racing Games", 
        "SELECT LEVEL - Puzzle Games",
        "SELECT LEVEL - Action Games",
        "SELECT LEVEL - Strategy Games"
    }
    
    love.graphics.printf(pageTitles[levelSelector.currentPage] or "SELECT LEVEL", 
        0, 80, love.graphics.getWidth(), "center")
    
    -- Subtitle with different instructions for host vs client
    love.graphics.setColor(0.8, 1, 0.8, 1)
    if gameState == "hosting" then
        love.graphics.printf("Use WASD to navigate, SPACE to vote, ENTER to launch", 
            0, 120, love.graphics.getWidth(), "center")
    else
        love.graphics.printf("Use WASD to navigate, SPACE to vote", 
            0, 120, love.graphics.getWidth(), "center")
    end
    
    -- Calculate grid positioning
    local totalGridWidth = levelSelector.gridCols * levelSelector.cardWidth + (levelSelector.gridCols - 1) * levelSelector.cardSpacing
    local totalGridHeight = levelSelector.gridRows * levelSelector.cardHeight + (levelSelector.gridRows - 1) * levelSelector.cardSpacing
    local startX = (love.graphics.getWidth() - totalGridWidth) / 2
    local startY = 150
    
    -- Draw level cards in grid
    local currentLevels = levelSelector.pages[levelSelector.currentPage]
    for i, level in ipairs(currentLevels) do
        local row = math.floor((i - 1) / levelSelector.gridCols)
        local col = (i - 1) % levelSelector.gridCols
        local x = startX + col * (levelSelector.cardWidth + levelSelector.cardSpacing)
        local y = startY + row * (levelSelector.cardHeight + levelSelector.cardSpacing)
        local isSelected = i == levelSelector.selectedLevel
        
        -- Card background
        if level.name == "Coming Soon" then
            -- Special styling for Coming Soon levels
            love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
        elseif isSelected then
            local bgPulse = math.sin(levelSelector.animationTime * 4 + i) * 0.1 + 0.9
            love.graphics.setColor(0.1, 0.4, 0.1, 0.4 * bgPulse)
        else
            love.graphics.setColor(0.1, 0.1, 0.1, 0.3)
        end
        love.graphics.rectangle('fill', x, y, levelSelector.cardWidth, levelSelector.cardHeight)
        
        -- Card border
        if level.name == "Coming Soon" then
            -- Special border for Coming Soon levels
            love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
            love.graphics.setLineWidth(2)
        elseif isSelected then
            love.graphics.setColor(0, 1, 0, pulse)
            love.graphics.setLineWidth(3)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle('line', x, y, levelSelector.cardWidth, levelSelector.cardHeight)
        love.graphics.setLineWidth(1)
        
        -- Highlight most voted level (for host)
        if gameState == "hosting" then
            local maxVotes = 0
            local mostVotedLevel = 1
            for levelIdx, voteList in pairs(levelSelector.votes) do
                if #voteList > maxVotes then
                    maxVotes = #voteList
                    mostVotedLevel = levelIdx
                end
            end
            
            if i == mostVotedLevel and maxVotes > 0 then
                local highlightPulse = math.sin(levelSelector.animationTime * 6) * 0.1 + 0.9
                love.graphics.setColor(0.2, 0.2, 0.6, 0.3 * highlightPulse)
                love.graphics.rectangle('fill', x + 2, y + 2, levelSelector.cardWidth - 4, levelSelector.cardHeight - 4)
            end
        end
        
        -- Draw level image
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
        if level.name == "Coming Soon" then
            love.graphics.setColor(0.5, 0.5, 0.5, 1) -- Dimmed gray for Coming Soon
        elseif isSelected then
            love.graphics.setColor(0, 1, 0, 1) -- Green for selected
        else
            love.graphics.setColor(0.9, 0.9, 0.9, 1) -- Light gray for unselected
        end
        love.graphics.printf(level.name, x + 8, y + 78, levelSelector.cardWidth - 16, "center")
        
        -- Level description
        if level.name == "Coming Soon" then
            love.graphics.setColor(0.4, 0.4, 0.4, 1) -- Dimmed gray for Coming Soon descriptions
        else
            love.graphics.setColor(0.7, 0.8, 0.7, 1)
        end
        love.graphics.printf(level.description, x + 8, y + 95, levelSelector.cardWidth - 16, "center")
        
        -- Show votes for this level
        debugConsole.addMessage("[VoteDraw] Checking level " .. i .. " - votes[i] exists: " .. tostring(levelSelector.votes[i] ~= nil) .. ", count: " .. tostring(#(levelSelector.votes[i] or {})))
        if levelSelector.votes[i] and #levelSelector.votes[i] > 0 then
            debugConsole.addMessage("[VoteDraw] Drawing votes for level " .. i .. " - count: " .. #levelSelector.votes[i])
            love.graphics.setColor(1, 1, 0, 1) -- Yellow for votes
            debugConsole.addMessage("[VoteDraw] Set color to yellow, drawing text at x=" .. (x + 8) .. ", y=" .. (y + 115))
            love.graphics.printf("Votes: " .. #levelSelector.votes[i], x + 8, y + 115, levelSelector.cardWidth - 16, "center")
            debugConsole.addMessage("[VoteDraw] Level " .. i .. " has " .. #levelSelector.votes[i] .. " votes")
            
            -- Show player icons who voted (bigger version for grid - 4x size)
            local iconSize = 20  -- 4x bigger than the original 5x5
            local iconStartX = x + (levelSelector.cardWidth - (#levelSelector.votes[i] * iconSize)) / 2
            for j, playerId in ipairs(levelSelector.votes[i]) do
                debugConsole.addMessage("[VoteIconDraw] Drawing icon for player " .. playerId .. " on level " .. i .. " (j=" .. j .. ")")
                if players[playerId] then
                    debugConsole.addMessage("[VoteIconDraw] Player " .. playerId .. " exists, color: " .. tostring(players[playerId].color[1]) .. "," .. tostring(players[playerId].color[2]) .. "," .. tostring(players[playerId].color[3]))
                    love.graphics.setColor(players[playerId].color[1], players[playerId].color[2], players[playerId].color[3])
                    love.graphics.rectangle("fill", iconStartX + (j-1) * iconSize, y + 125, iconSize, iconSize)
                    debugConsole.addMessage("[VoteIconDraw] Drew rectangle at x=" .. (iconStartX + (j-1) * iconSize) .. ", y=" .. (y + 125) .. ", size=" .. iconSize)
                    
                    -- Draw player face if available
                    if players[playerId].facePoints and type(players[playerId].facePoints) == "userdata" then
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(
                            players[playerId].facePoints,
                            iconStartX + (j-1) * iconSize, y + 125,
                            0,
                            iconSize/100, iconSize/100  -- Scale from 100x100 to iconSize x iconSize
                        )
                    end
                end
            end
        end
    end
    
    -- Draw voting panel in top right
    drawVotingPanel()
    
    -- Draw page navigation
    local totalPages = #levelSelector.pages
    local pageY = love.graphics.getHeight() - 60
    
    -- Page indicator
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf("Page " .. levelSelector.currentPage .. " of " .. totalPages, 
        0, pageY, love.graphics.getWidth(), "center")
    
    -- Navigation instructions
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.printf("Q/E: Previous/Next Page | WASD: Navigate | SPACE: Vote", 
        0, pageY + 20, love.graphics.getWidth(), "center")
    
    -- Navigation instructions removed for cleaner look
end


function safeSend(peer, message)
    if peer and peer.send then
        local success, err = pcall(function()
            peer:send(message)
        end)
        if not success then
            debugConsole.addMessage("Failed to send message: " .. tostring(err))
        end
    else
        debugConsole.addMessage("Warning: Attempted to send to invalid peer")
    end
end

-- Make safeSend available globally for battle royale
_G.safeSend = safeSend
_G.serverClients = serverClients

-- Game state synchronization functions
function syncGameState()
    debugConsole.addMessage("[Sync] syncGameState called - gameState: " .. gameState .. ", returnState: " .. tostring(returnState) .. ", clients: " .. #serverClients)
    
    if gameState == "battleroyale" and returnState == "hosting" then
        -- Host sends complete game state to all clients
        local meteoroidData = serializeMeteoroids(battleRoyale.asteroids)
        local safeZoneData = string.format("%.2f,%.2f,%.2f", 
            battleRoyale.center_x, battleRoyale.center_y, battleRoyale.safe_zone_radius)
        
        -- Simplified message for testing
        local message = string.format("game_state_sync,test_meteoroids,%.2f,%.2f,%.2f,%.2f", 
            battleRoyale.center_x, battleRoyale.center_y, battleRoyale.safe_zone_radius, battleRoyale.timer)
        
        debugConsole.addMessage("[Sync] Message length: " .. #message)
        debugConsole.addMessage("[Sync] Asteroids: " .. #battleRoyale.asteroids)
        
        for _, client in ipairs(serverClients) do
            safeSend(client, message)
            debugConsole.addMessage("[Host] Sent sync to client")
        end
        
        -- Update local sync state
        gameStateSync.meteoroids = battleRoyale.asteroids
        gameStateSync.safeZone = {
            center_x = battleRoyale.center_x,
            center_y = battleRoyale.center_y,
            radius = battleRoyale.safe_zone_radius
        }
        gameStateSync.gameTime = battleRoyale.timer
        gameStateSync.lastSyncTime = love.timer.getTime()
        
        debugConsole.addMessage("[Sync] Sent game state to " .. #serverClients .. " clients")
    else
        debugConsole.addMessage("[Sync] Not syncing - conditions not met")
    end
end


function serializeMeteoroids(meteoroids)
    local meteoroidStrings = {}
    for i, meteoroid in ipairs(meteoroids) do
        table.insert(meteoroidStrings, string.format("%.2f,%.2f,%.2f,%.2f,%.2f",
            meteoroid.x, meteoroid.y, meteoroid.vx, meteoroid.vy, meteoroid.size))
    end
    return table.concat(meteoroidStrings, "|")
end


function deserializeMeteoroids(data)
    local meteoroids = {}
    if data and data ~= "" then
        for meteoroidStr in data:gmatch("([^|]+)") do
            local x, y, vx, vy, size = meteoroidStr:match("([-%d.]+),([-%d.]+),([-%d.]+),([-%d.]+),([%d.]+)")
            if x and y and vx and vy and size then
                local meteoroid = {
                    x = tonumber(x),
                    y = tonumber(y),
                    vx = tonumber(vx),
                    vy = tonumber(vy),
                    size = tonumber(size),
                    color = {0.5, 0.5, 0.5},
                    points = {}
                }
                -- Generate shape for the meteoroid
                battleRoyale.generateAsteroidShape(meteoroid)
                table.insert(meteoroids, meteoroid)
            end
        end
    end
    return meteoroids
end

function love.load() -- music effect
    print("[Main] Game loaded successfully!")
    players = {}
    debugConsole.init()
    love.keyboard.setKeyRepeat(true)
    
    -- Load saved player data
    loadPlayerData()
    musicHandler.loadMenuMusic()
    instructions.load()
    battleRoyale.load()


    -- load background
    menuBackground = love.graphics.newImage("images/menu-background.jpg")
    lobbyBackground = love.graphics.newImage("images/menu-background.jpg")

    -- gif frames synced with BPM
    titleGifSprite = love.graphics.newImage("images/title.png") 
    titleGifSprite:setFilter("nearest", "nearest") -- keeps image sharp no matter the scale
    local g = anim8.newGrid(71, 32, titleGifSprite:getWidth(), titleGifSprite:getHeight()) 
    titleGifAnim = anim8.newAnimation(g('1-5','1-4'), (60/musicHandler.bpm) / 8) 

    -- Create buttons
    -- Main menu buttons
    buttons.play = {x = 300, y = 230, width = 200, height = 50, text = "Play"}
    buttons.customize = {x = 300, y = 300, width = 200, height = 50, text = "Customize"}
    buttons.settings = {x = 300, y = 370, width = 200, height = 50, text = "Settings"}
    buttons.quit = {x = 300, y = 440, width = 200, height = 50, text = "Quit"}
    
    -- Play submenu buttons
    buttons.host = {x = 300, y = 230, width = 200, height = 50, text = "Host Game"}
    buttons.join = {x = 300, y = 300, width = 200, height = 50, text = "Join Game"}
    buttons.back_play = {x = 300, y = 370, width = 200, height = 50, text = "Back"}
    
    -- Settings submenu buttons
    buttons.back_settings = {x = 300, y = 400, width = 200, height = 50, text = "Back"}
    
    -- Customize submenu buttons
    buttons.back_customize = {x = 300, y = 400, width = 200, height = 50, text = "Back"}
    
    -- Other buttons
    buttons.start = {x = 300, y = 300, width = 200, height = 50, text = "Start", visible = false}

    -- Clear any existing effects first
    musicHandler.removeEffect("host_button")
    musicHandler.removeEffect("join_button")
    musicHandler.removeEffect("play_button")
    musicHandler.removeEffect("customize_button")
    musicHandler.removeEffect("settings_button")
    musicHandler.removeEffect("quit_button")
    musicHandler.removeEffect("menu_bg")
    musicHandler.removeEffect("title")

    musicHandler.addEffect("play_button", "combo", {
        scaleAmount = 0.1,      -- Pulse up to 20% bigger
        rotateAmount = math.pi/64,  -- Small rotation
        frequency = 1,          -- Once per beat
        phase = 0,              -- Start of beat
        snapDuration = 1.0    -- Quick snap
    })

    musicHandler.addEffect("customize_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        phase = 0.25,   -- Different timing
        snapDuration = 1.0
    })

    musicHandler.addEffect("settings_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        phase = 0.5,   -- Different timing
        snapDuration = 1.0
    })

    musicHandler.addEffect("quit_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        phase = 0.75,   -- Different timing
        snapDuration = 1.0
    })

    musicHandler.addEffect("host_button", "combo", {
        scaleAmount = 0.1,      -- Pulse up to 20% bigger
        rotateAmount = math.pi/64,  -- Small rotation
        frequency = 1,          -- Once per beat
        phase = 0,              -- Start of beat
        snapDuration = 1.0    -- Quick snap
    })

    musicHandler.addEffect("join_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        phase = 0.5,   -- Opposite timing
        snapDuration = 1.0
    })

    musicHandler.addEffect("back_play_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        phase = 0.125,   -- Different timing
        snapDuration = 1.0
    })

    musicHandler.addEffect("back_settings_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        phase = 0.375,   -- Different timing
        snapDuration = 1.0
    })

    musicHandler.addEffect("back_customize_button", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/64,
        frequency = 1,
        phase = 0.625,   -- Different timing
        snapDuration = 1.0
    })

    musicHandler.addEffect("menu_bg", "bounce", {
        amplitude = 5,
        frequency = 0.5,
        phase = 0
    })

    musicHandler.addEffect("title", "combo", {
        scaleAmount = 0.1,      
        rotateAmount = 0,  
        frequency = 1.5,          
        phase = 1,             
        snapDuration = 0.1    
    })

    checkServerStatus()
    jumpGame.load()
    scoreLobby.init()
end

function love.update(dt)
    -- print("[Main] Update running, gameState: " .. gameState) -- Uncomment this if needed
    musicHandler.update(dt)
    instructions.update(dt)
    updateScoreDisplay(dt)
    scoreLobby.update(dt)
    
    -- Update game mode selection animation
    if gameModeSelection.active then
        gameModeSelection.animationTime = gameModeSelection.animationTime + dt
    end
    
    -- Update level selector animation
    if levelSelector.active then
        levelSelector.animationTime = levelSelector.animationTime + dt
    end


    -- Track actual game transitions
    if gameState == "jumpgame" then
        currentPartyGame = "jumpgame"
    elseif gameState == "lasergame" then
        currentPartyGame = "lasergame"
    elseif gameState == "battleroyale" then
        currentPartyGame = "battleroyale"
    elseif gameState == "dodgegame" then
        currentPartyGame = "dodgegame"
    end

    -- Check for party mode transition flag (host only)
    if _G.partyModeTransition and returnState == "hosting" then
        _G.partyModeTransition = false
        partyModeTransitioned = false -- Reset the flag for next game
        debugConsole.addMessage("[PartyMode] Host transitioning to next game")
        
        -- Reset battle royale state
        battleRoyale.game_over = false
        battleRoyale.death_animation_done = false
        
        -- No elimination system in battle royale - players respawn instead
        
        -- Get next game from lineup
        currentGameIndex = currentGameIndex + 1
        if currentGameIndex > #miniGameLineup then
            currentGameIndex = 1 -- Loop back to start
        end
        
        local nextGame = miniGameLineup[currentGameIndex]
        currentPartyGame = nextGame
        debugConsole.addMessage("[Party Mode] Next game: " .. nextGame)
        debugConsole.addMessage("[Party Mode] Current index: " .. currentGameIndex .. " of " .. #miniGameLineup)
        debugConsole.addMessage("[Party Mode] Full lineup: " .. table.concat(miniGameLineup, ", "))
        
        -- Start the next game directly (no instructions in party mode transitions)
        if nextGame == "jumpgame" then
            gameState = "jumpgame"
            jumpGame.reset(players)
            jumpGame.setPlayerColor(localPlayer.color)
            
            -- Host notifies clients
            for _, client in ipairs(serverClients) do
                safeSend(client, "start_jump_game")
            end
        elseif nextGame == "lasergame" then
            gameState = "lasergame"
            local seed = os.time() + love.timer.getTime() * 10000
            laserGame.reset()
            laserGame.setSeed(seed)
            laserGame.setPlayerColor(localPlayer.color)
            
            -- Host notifies clients
            for _, client in ipairs(serverClients) do
                safeSend(client, "start_laser_game," .. seed)
            end
        elseif nextGame == "battleroyale" then
            gameState = "battleroyale"
            _G.returnState = returnState
            _G.gameState = "battleroyale"
            _G.players = players
            _G.localPlayer = localPlayer
            initializeRoundWins()
            local seed = os.time() + love.timer.getTime() * 10000
            battleRoyale.reset()
            battleRoyale.setSeed(seed)
            battleRoyale.setPlayerColor(localPlayer.color)
            
            -- Host notifies clients
            for _, client in ipairs(serverClients) do
                safeSend(client, "start_battleroyale_game," .. seed)
            end
        elseif nextGame == "dodgegame" then
            gameState = "dodgegame"
            _G.returnState = returnState
            _G.gameState = "dodgegame"
            _G.players = players
            _G.localPlayer = localPlayer
            initializeRoundWins()
            local seed = os.time() + love.timer.getTime() * 10000
            dodgeGame.reset()
            dodgeGame.setSeed(seed)
            dodgeGame.setPlayerColor(localPlayer.color)
            
            -- Host notifies clients
            for _, client in ipairs(serverClients) do
                safeSend(client, "start_dodge_game," .. seed)
            end
        end
        
        -- Send specific game transition to clients
        for _, client in ipairs(serverClients) do
            safeSend(client, "party_transition_to," .. nextGame)
        end
    end

    -- Removed duplicate party mode transition logic - now handled above

    if partyMode then
        if gameState == "jumpgame" then
            currentPartyGame = "jumpgame"
        elseif gameState == "lasergame" then
            currentPartyGame = "lasergame"
        elseif gameState == "battleroyale" then
            currentPartyGame = "battleroyale"
        elseif gameState == "dodgegame" then
            currentPartyGame = "dodgegame"
        end
    end

    if gameState == "menu" or gameState == "play_menu" or gameState == "settings_menu" or gameState == "customize_menu" then
        titleGifAnim:update(dt)
    end

    if gameState == "menu" then
        if not musicHandler.isPlaying then
            musicHandler.loadMenuMusic()
        end
        musicHandler.clearEffects()
    elseif gameState == "customization" then
        if not musicHandler.isPlaying then
            musicHandler.loadMenuMusic()
        end
        musicHandler.applyCustomizationEffect()
    else
        -- Only stop music if we're not in party mode
        if not partyMode then
            musicHandler.stopMusic()
        end
        musicHandler.clearEffects()
    end

    if gameState == "jumpgame" then
        if returnState == "hosting" then
            updateServer()
        else
            updateClient()
        end

        jumpGame.update(dt)

        if jumpGame.game_over then
            debugConsole.addMessage("Jump game over, returning to state: " .. returnState)
            
            -- Award round win to highest scoring player
            local winnerId = localPlayer.id
            local highestScore = jumpGame.current_round_score
            
            -- Check all players for highest score
            for id, player in pairs(players) do
                if player.jumpScore and player.jumpScore > highestScore then
                    highestScore = player.jumpScore
                    winnerId = id
                end
            end
            
            -- Only handle round wins in multiplayer mode
            if returnState == "hosting" and serverClients and #serverClients > 0 then
                awardRoundWin(winnerId)
                checkForScoreDisplay()
                
                -- Broadcast round win
                for _, client in ipairs(serverClients) do
                    safeSend(client, string.format("round_win,%d", winnerId))
                end
            elseif returnState == "playing" and server and connected then
                if server and connected then
                    safeSend(server, string.format("round_win,%d", winnerId))
                end
            end
            
            -- Only show score lobby after every 3 games
            if currentRound % maxRounds == 0 then
                debugConsole.addMessage("[Main] Showing score lobby after round " .. currentRound)
                scoreLobby.show(currentRound, roundWins, players)
            end
            
            -- Check if we should transition in party mode (only once)
            if partyMode and not partyModeTransitioned then
                partyModeTransitioned = true
                -- In jump game, transition when the timer runs out (game ends naturally)
                debugConsole.addMessage("Jump game finished, transitioning to next game")
                _G.partyModeTransition = true
                debugConsole.addMessage("[PartyMode] Set party mode transition flag")
                
                -- Host will handle the transition in the main loop
            end
            
            -- Only return to lobby if not in party mode transition
            if not _G.partyModeTransition then
                gameState = returnState
                debugConsole.addMessage("Returned to state: " .. gameState)
                jumpGame.reset()
            else
                debugConsole.addMessage("Party mode transition active, staying in jump game state")
                -- Don't reset jumpGame here - let the transition logic handle it
            end
            -- Don't reset partyModeTransitioned here - let the transition logic handle it
        end
    elseif gameState == "lasergame" then
        if returnState == "hosting" then
            updateServer()
        else
            updateClient()
        end

        laserGame.update(dt)

        if connected then
            local message = string.format("laser_position,%d,%.2f,%.2f,%.2f,%.2f,%.2f",
                localPlayer.id or 0,
                laserGame.player.x,
                laserGame.player.y,
                localPlayer.color[1],
                localPlayer.color[2],
                localPlayer.color[3]
            )
            if returnState == "hosting" then
                for _, client in ipairs(serverClients) do
                    safeSend(client, message)
                end
            else
                safeSend(server, message)
            end
        end

        if laserGame.game_over then
            debugConsole.addMessage("Laser game transitioning to: " .. returnState)
            
            -- Award round win to player hit least (or all tied players)
            local minHits = laserGame.hitCount or 0
            local winners = {}
            
            -- Include local player's hit count
            if localPlayer.id and players[localPlayer.id] then
                local localHits = players[localPlayer.id].laserHits or 0
                if localHits < minHits then
                    minHits = localHits
                    winners = {localPlayer.id}
                elseif localHits == minHits then
                    table.insert(winners, localPlayer.id)
                end
            end
            
            -- Find minimum hit count among all players
            for id, player in pairs(players) do
                local playerHits = player.laserHits or 0
                if playerHits < minHits then
                    minHits = playerHits
                    winners = {id}
                elseif playerHits == minHits and id ~= localPlayer.id then
                    table.insert(winners, id)
                end
            end
            
            -- Award wins to all tied players (only in multiplayer mode)
            if returnState == "hosting" and serverClients and #serverClients > 0 then
                for _, winnerId in ipairs(winners) do
                    awardRoundWin(winnerId)
                end
                checkForScoreDisplay()
                
                -- Broadcast round wins
                for _, client in ipairs(serverClients) do
                    for _, winnerId in ipairs(winners) do
                        safeSend(client, string.format("round_win,%d", winnerId))
                    end
                end
            elseif returnState == "playing" and server and connected then
                for _, winnerId in ipairs(winners) do
                    safeSend(server, string.format("round_win,%d", winnerId))
                end
            end
            
            -- Only show score lobby after every 3 games
            if currentRound % maxRounds == 0 then
                debugConsole.addMessage("[Main] Showing score lobby after round " .. currentRound)
                scoreLobby.show(currentRound, roundWins, players)
            end
            
            -- Check if we should transition in party mode (only once)
            if partyMode and not partyModeTransitioned then
                partyModeTransitioned = true
                -- In laser game, transition when the game ends naturally
                debugConsole.addMessage("Laser game finished, transitioning to next game")
                _G.partyModeTransition = true
                debugConsole.addMessage("[PartyMode] Set party mode transition flag")
                
                -- Host will handle the transition in the main loop
            end
            
            -- Only return to lobby if not in party mode transition
            if not _G.partyModeTransition then
                gameState = returnState
                debugConsole.addMessage("Returned to state: " .. gameState)
            else
                debugConsole.addMessage("Party mode transition active, staying in laser game state")
            end
        end
    elseif gameState == "battleroyale" then
        -- Debug test - show message every 3 seconds
        debugTestTimer = debugTestTimer + dt
        if debugTestTimer >= 3.0 then
            debugTestTimer = 0
            debugConsole.addMessage("[TEST] Battle royale running - returnState: " .. tostring(returnState))
        end
        
        -- Simple sync test - send test message every second
        if returnState == "hosting" then
            testSyncTimer = testSyncTimer + dt
            if testSyncTimer >= 1.0 then
                testSyncTimer = 0
                debugConsole.addMessage("[Host] Meteoroids: " .. #battleRoyale.asteroids .. ", Clients: " .. #serverClients)
            end
            updateServer()
        else
            updateClient()
        end

        battleRoyale.update(dt)

        if battleRoyale.game_over then
            debugConsole.addMessage("Battle Royale game over, returning to state: " .. returnState)
            
            -- Award round win to player with highest survival score
            local winnerId = localPlayer.id
            local highestScore = battleRoyale.current_round_score
            
            -- Check all players for highest score
            for id, player in pairs(players) do
                if player.battleScore and player.battleScore > highestScore then
                    highestScore = player.battleScore
                    winnerId = id
                end
            end
            
            if winnerId and returnState == "hosting" and serverClients and #serverClients > 0 then
                awardRoundWin(winnerId)
                checkForScoreDisplay()
                
                -- Broadcast round win
                for _, client in ipairs(serverClients) do
                    safeSend(client, string.format("round_win,%d", winnerId))
                end
            elseif winnerId and returnState == "playing" and server and connected then
                safeSend(server, string.format("round_win,%d", winnerId))
            end
            
            -- Check if we should transition in party mode (only once)
            if partyMode and not partyModeTransitioned then
                partyModeTransitioned = true
                -- In battle royale, transition when the timer runs out
                debugConsole.addMessage("Battle royale finished, transitioning to next game")
                _G.partyModeTransition = true
                debugConsole.addMessage("[PartyMode] Set party mode transition flag")
                
                -- Host will handle the transition in the main loop
            end
            
            -- Only show score lobby after every 3 games
            if currentRound % maxRounds == 0 then
                debugConsole.addMessage("[Main] Showing score lobby after round " .. currentRound)
                scoreLobby.show(currentRound, roundWins, players)
            end
            
            -- Only return to lobby if not in party mode
            if not partyMode then
                gameState = returnState
                debugConsole.addMessage("Returned to state: " .. gameState)
                battleRoyale.reset()
            else
                debugConsole.addMessage("Party mode active, staying in battle royale state for next game")
                -- Don't reset battleRoyale here - let the transition logic handle it
            end
            -- Don't reset partyModeTransitioned here - let the transition logic handle it
        end
    elseif gameState == "dodgegame" then
        if returnState == "hosting" then
            updateServer()
        else
            updateClient()
        end

        dodgeGame.update(dt)

        if connected then
            local message = string.format("dodge_position,%d,%.2f,%.2f,%.2f,%.2f,%.2f",
                localPlayer.id or 0,
                dodgeGame.player.x,
                dodgeGame.player.y,
                localPlayer.color[1],
                localPlayer.color[2],
                localPlayer.color[3]
            )
            if returnState == "hosting" then
                for _, client in ipairs(serverClients) do
                    safeSend(client, message)
                end
            else
                safeSend(server, message)
            end
        end

        if dodgeGame.game_over then
            debugConsole.addMessage("Dodge game over, returning to state: " .. returnState)
            
            -- Award round win to player with highest survival score
            local winnerId = localPlayer.id
            local highestScore = dodgeGame.current_round_score
            
            -- Check all players for highest score
            for id, player in pairs(players) do
                if player.dodgeScore and player.dodgeScore > highestScore then
                    highestScore = player.dodgeScore
                    winnerId = id
                end
            end
            
            if winnerId and returnState == "hosting" and serverClients and #serverClients > 0 then
                awardRoundWin(winnerId)
                checkForScoreDisplay()
                
                -- Broadcast round win
                for _, client in ipairs(serverClients) do
                    safeSend(client, string.format("round_win,%d", winnerId))
                end
            elseif winnerId and returnState == "playing" and server and connected then
                safeSend(server, string.format("round_win,%d", winnerId))
            end
            
            -- Check if we should transition in party mode (only once)
            if partyMode and not partyModeTransitioned then
                partyModeTransitioned = true
                -- In dodge game, transition when the timer runs out
                debugConsole.addMessage("Dodge game finished, transitioning to next game")
                _G.partyModeTransition = true
                debugConsole.addMessage("[PartyMode] Set party mode transition flag")
                
                -- Host will handle the transition in the main loop
            end
            
            -- Only show score lobby after every 3 games
            if currentRound % maxRounds == 0 then
                debugConsole.addMessage("[Main] Showing score lobby after round " .. currentRound)
                scoreLobby.show(currentRound, roundWins, players)
            end
            
            -- Only return to lobby if not in party mode
            if not partyMode then
                gameState = returnState
                debugConsole.addMessage("Returned to state: " .. gameState)
                dodgeGame.reset()
            else
                debugConsole.addMessage("Party mode active, staying in dodge game state for next game")
                -- Don't reset dodgeGame here - let the transition logic handle it
            end
            -- Don't reset partyModeTransitioned here - let the transition logic handle it
        end
    elseif gameState == "hosting" then
        updateServer()
    elseif gameState == "playing" or gameState == "connecting" then
        updateClient()
    end
    accumulatedTime = accumulatedTime + dt
    while accumulatedTime >= fixedTimestep do
        updatePhysics(fixedTimestep)
        accumulatedTime = accumulatedTime - fixedTimestep
    end
end

function updatePhysics(dt)
    if gameState == "hosting" or gameState == "playing" then
        -- Don't allow player movement when any menu is active
        if gameModeSelection.active or levelSelector.active then
            return
        end
        
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
        
        if moved and localPlayer.id ~= nil then
            -- Update local player's position in the players table while preserving all data
            local existingFacePoints = players[localPlayer.id] and players[localPlayer.id].facePoints
            local existingScore = players[localPlayer.id] and players[localPlayer.id].totalScore or 0
            local existingName = players[localPlayer.id] and players[localPlayer.id].name or localPlayer.name
            players[localPlayer.id] = {
                x = localPlayer.x,
                y = localPlayer.y,
                color = localPlayer.color,
                id = localPlayer.id,
                totalScore = existingScore,
                facePoints = existingFacePoints or localPlayer.facePoints,
                name = existingName
            }
        end
    end
end

function updateServer()
    if not serverHost then 
        debugConsole.addMessage("[Server] updateServer called but no serverHost!")
        return 
    end
    
    -- sends positions and colors in lobby
    for _, client in ipairs(serverClients) do
        local message = string.format("%d,%d,%d,%.2f,%.2f,%.2f", 
            localPlayer.id,
            math.floor(localPlayer.x), 
            math.floor(localPlayer.y),
            localPlayer.color[1],
            localPlayer.color[2],
            localPlayer.color[3]
        )
        safeSend(client, message)
    end

    -- send jump game positions
    if gameState == "jumpgame" then
        local jumpX = jumpGame.player.rect.x
        local jumpY = jumpGame.player.rect.y 
        
        for _, client in ipairs(serverClients) do
            safeSend(client, string.format("jump_position,0,%.2f,%.2f,%.2f,%.2f,%.2f",
                jumpX, jumpY,
                localPlayer.color[1], localPlayer.color[2], localPlayer.color[3]))
        end
    end

    -- send battle royale positions
    if gameState == "battleroyale" then
        local battleX = battleRoyale.player.x
        local battleY = battleRoyale.player.y 
        
        -- Include laser data
        local laserData = ""
        if battleRoyale.lasers and #battleRoyale.lasers > 0 then
            local laserStrings = {}
            for i, laser in ipairs(battleRoyale.lasers) do
                table.insert(laserStrings, string.format("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f",
                    laser.x, laser.y, laser.vx, laser.vy, laser.time, laser.duration, laser.size))
            end
            laserData = "|" .. table.concat(laserStrings, "|")
        end
        
        -- Send position and laser data like laser game (no elimination status)
        for _, client in ipairs(serverClients) do
            safeSend(client, string.format("battle_position,0,%.2f,%.2f,%.2f,%.2f,%.2f,%s",
                battleX, battleY,
                localPlayer.color[1], localPlayer.color[2], localPlayer.color[3], 
                laserData or ""))
        end
        
        -- Game state is now deterministic - no need to sync meteoroids/powerups
    end
    
    -- send dodge game positions
    if gameState == "dodgegame" then
        local dodgeX = dodgeGame.player.x
        local dodgeY = dodgeGame.player.y 
        
        -- Send position data
        for _, client in ipairs(serverClients) do
            safeSend(client, string.format("dodge_position,0,%.2f,%.2f,%.2f,%.2f,%.2f",
                dodgeX, dodgeY,
                localPlayer.color[1], localPlayer.color[2], localPlayer.color[3]))
        end
    end
    
    

    -- Handle network events
    if not serverHost then
        debugConsole.addMessage("[Server] serverHost became nil during updateServer!")
        return
    end
    
    local event = serverHost:service(0)
    while event do
        if event.type == "connect" then
            if event.peer then
                local clientId = nextClientId
                nextClientId = nextClientId + 1
                peerToId[event.peer] = clientId
                
                table.insert(serverClients, event.peer)
                players[clientId] = {
                    x = 100, 
                    y = 100, 
                    id = clientId,
                    color = {0, 0, 1},  -- Default blue color until client sends their color
                    name = "Player" .. clientId  -- Default name until client sends their name
                }
                
                safeSend(event.peer, "your_id," .. clientId)
                
                -- Send existing players to new client
                for id, player in pairs(players) do
                    -- Send position and color
                    safeSend(event.peer, string.format("new_player,%d,%d,%d,%.2f,%.2f,%.2f,%s",
                        id, math.floor(player.x), math.floor(player.y),
                        player.color[1], player.color[2], player.color[3],
                        player.name or "Player"))
                    
                    -- Send face data if it exists
                    if player.facePoints then
                        local faceData = serializeFacePoints(player.facePoints)
                        if faceData then
                            safeSend(event.peer, "face_data," .. id .. "," .. faceData)
                            debugConsole.addMessage("[Server] Sent player " .. id .. "'s face to new client")
                        end
                    end
                end
            end
        elseif event.type == "receive" then
            if event.peer then
                local clientId = peerToId[event.peer]
                if clientId then
                    debugConsole.addMessage("[Server] Received message from client " .. clientId .. ": " .. event.data)
                    handleServerMessage(clientId, event.data)
                else
                    debugConsole.addMessage("[Server] Received message from unknown client: " .. event.data)
                end
            end
        elseif event.type == "disconnect" then
            if event.peer then
                local clientId = peerToId[event.peer]
                if clientId and players[clientId] then
                    players[clientId] = nil
                    -- Notify other clients
                    for _, client in ipairs(serverClients) do
                        if client ~= event.peer then
                            safeSend(client, "player_disconnect," .. clientId)
                        end
                    end
                    -- Remove from clients list
                    for i, client in ipairs(serverClients) do
                        if client == event.peer then
                            table.remove(serverClients, i)
                            break
                        end
                    end
                    peerToId[event.peer] = nil
                end
            end
        end
        
        event = serverHost:service(0)
    end
end

function updateClient()
    if not host then 
        debugConsole.addMessage("[Client] updateClient called but no host!")
        return 
    end

    -- Handle network events
    local success, err = pcall(function()
        local event = host:service(0)
        while event do
            if event.type == "connect" then
                connected = true
        gameState = "playing"
            elseif event.type == "receive" then
                handleClientMessage(event.data)
            elseif event.type == "disconnect" then
                handleDisconnection()
            end
            event = host:service(0)
        end
    end)

    if not success then
        handleDisconnection()
        return
    end

    -- sends regular position updates
    if connected and localPlayer.id then
        if gameState == "playing" then
            local message = string.format("%d,%d,%d,%.2f,%.2f,%.2f",
                localPlayer.id,
                math.floor(localPlayer.x),
                math.floor(localPlayer.y),
                localPlayer.color[1],
                localPlayer.color[2],
                localPlayer.color[3]
            )
            safeSend(server, message)
        end

        -- jump game positions
        if gameState == "jumpgame" then
            local jumpX = jumpGame.player.rect.x
            local jumpY = jumpGame.player.rect.y
            safeSend(server, string.format("jump_position,%d,%.2f,%.2f,%.2f,%.2f,%.2f",
                localPlayer.id, jumpX, jumpY,
                localPlayer.color[1], localPlayer.color[2], localPlayer.color[3]))
        end

        -- battle royale positions - send like laser game
        if gameState == "battleroyale" then
            local battleX = battleRoyale.player.x
            local battleY = battleRoyale.player.y
            
            -- Include laser data
            local laserData = ""
            if battleRoyale.lasers and #battleRoyale.lasers > 0 then
                local laserStrings = {}
                for i, laser in ipairs(battleRoyale.lasers) do
                    table.insert(laserStrings, string.format("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f",
                        laser.x, laser.y, laser.vx, laser.vy, laser.time, laser.duration, laser.size))
                end
                laserData = "|" .. table.concat(laserStrings, "|")
            end
            
            -- Send position and laser data like laser game (no elimination status)
            safeSend(server, string.format("battle_position,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%s",
                localPlayer.id, battleX, battleY,
                localPlayer.color[1], localPlayer.color[2], localPlayer.color[3], 
                laserData or ""))
        end
        
        -- dodge game positions
        if gameState == "dodgegame" then
            local dodgeX = dodgeGame.player.x
            local dodgeY = dodgeGame.player.y
            
        -- Send position data
        safeSend(server, string.format("dodge_position,%d,%.2f,%.2f,%.2f,%.2f,%.2f",
            localPlayer.id, dodgeX, dodgeY,
            localPlayer.color[1], localPlayer.color[2], localPlayer.color[3]))
        end
        
        
    end
end

function love.draw()
    if gameState == "jumpgame" then
        jumpGame.draw(players, localPlayer.id)
    elseif gameState == "lasergame" then
        love.graphics.setColor(1, 1, 1, 1)
        laserGame.draw(players, localPlayer.id)
    elseif gameState == "battleroyale" then
        debugConsole.addMessage("[Draw] Drawing battle royale game")
        battleRoyale.draw(players, localPlayer.id)
    elseif gameState == "dodgegame" then
        debugConsole.addMessage("[Draw] Drawing dodge game")
        dodgeGame.draw(players, localPlayer.id)
    elseif gameState == "menu" then
        local bgx, bgy = musicHandler.applyToDrawable("menu_bg", 0, 0) --changes for music effect
        local scale = 3
        local frameWidth = 71 * scale
        local ex, ey, er, esx, esy = musicHandler.applyToDrawable("title", love.graphics.getWidth()/2, 100) -- for music effect
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(menuBackground, bgx, bgy) --changes for music effect
        titleGifAnim:draw(titleGifSprite, ex, ey, er or 0, scale * (esx or 1), scale * (esx or 1), 71/2, 32/2)

        drawButton(buttons.play, "play_button")
        drawButton(buttons.customize, "customize_button")
        drawButton(buttons.settings, "settings_button")
        drawButton(buttons.quit, "quit_button")

    elseif gameState == "play_menu" then
        local bgx, bgy = musicHandler.applyToDrawable("menu_bg", 0, 0) --changes for music effect
        local scale = 3
        local frameWidth = 71 * scale
        local ex, ey, er, esx, esy = musicHandler.applyToDrawable("title", love.graphics.getWidth()/2, 100) -- for music effect
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(menuBackground, bgx, bgy) --changes for music effect
        titleGifAnim:draw(titleGifSprite, ex, ey, er or 0, scale * (esx or 1), scale * (esx or 1), 71/2, 32/2)

        drawButton(buttons.host, "host_button")
        drawButton(buttons.join, "join_button")
        drawButton(buttons.back_play, "back_play_button")

    elseif gameState == "settings_menu" then
        local bgx, bgy = musicHandler.applyToDrawable("menu_bg", 0, 0) --changes for music effect
        local scale = 3
        local frameWidth = 71 * scale
        local ex, ey, er, esx, esy = musicHandler.applyToDrawable("title", love.graphics.getWidth()/2, 100) -- for music effect
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(menuBackground, bgx, bgy) --changes for music effect
        titleGifAnim:draw(titleGifSprite, ex, ey, er or 0, scale * (esx or 1), scale * (esx or 1), 71/2, 32/2)

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Settings", 0, 200, love.graphics.getWidth(), "center")
        love.graphics.printf("Settings options coming soon!", 0, 250, love.graphics.getWidth(), "center")
        
        drawButton(buttons.back_settings, "back_settings_button")
    elseif gameState == "customize_menu" then
        local bgx, bgy = musicHandler.applyToDrawable("menu_bg", 0, 0) --changes for music effect
        local scale = 3
        local frameWidth = 71 * scale
        local ex, ey, er, esx, esy = musicHandler.applyToDrawable("title", love.graphics.getWidth()/2, 100) -- for music effect
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(menuBackground, bgx, bgy) --changes for music effect
        titleGifAnim:draw(titleGifSprite, ex, ey, er or 0, scale * (esx or 1), scale * (esx or 1), 71/2, 32/2)

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Customize", 0, 200, love.graphics.getWidth(), "center")
        love.graphics.printf("Character customization coming soon!", 0, 250, love.graphics.getWidth(), "center")
        
        drawButton(buttons.back_customize, "back_customize_button")
    elseif gameState == "customization" then
        characterCustomization.draw()
    elseif gameState == "connecting" then
        love.graphics.printf("Connecting to " .. inputField.text .. ":" .. inputPort, 
            0, 100, love.graphics.getWidth(), "center")
        drawInputField()
        drawButton(buttons.start)
    elseif gameState == "playing" or gameState == "hosting" then
        -- Draw background
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(lobbyBackground, 0, 0)

        
        
        -- Draw all players
        for id, player in pairs(players) do
            if player and player.color then
                -- Draw player square
                love.graphics.setColor(player.color[1], player.color[2], player.color[3])
                love.graphics.rectangle("fill", player.x, player.y, 50, 50)
                
                -- Draw face image if it exists
                if player.facePoints and type(player.facePoints) == "userdata" then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        player.facePoints,
                        player.x,
                        player.y,
                        0,
                        50/100,
                        50/100
                    )
                end
                
                -- Draw player name above the player
                love.graphics.setColor(1, 1, 1)  -- White color for name
                love.graphics.printf(
                    player.name or "Player",
                    player.x - 30,
                    player.y - 45,
                    120,
                    "center"
                )
                
                -- Draw player score below the name
                love.graphics.setColor(1, 1, 0)  -- Yellow color for score
                love.graphics.printf(
                    "Score: " .. math.floor(player.totalScore or 0),
                    player.x - 30,
                    player.y - 25,
                    120,
                    "center"
                )
                
            end
        end
        
        -- Draw voting panel in main lobby (always visible when there are 2+ players)
        if levelSelector and levelSelector.playerVotes and #table_keys(players) >= 2 then
            drawVotingPanel()
        end
        
        -- Draw game mode selection UI
        if gameModeSelection.active then
            drawGameModeSelection()
        elseif levelSelector.active then
            drawLevelSelector()
        else
            -- Show spacebar hint when not in game mode selection
            love.graphics.setColor(0.8, 0.8, 1, 0.8)
            love.graphics.printf("Press SPACE to select game mode", 
                0, love.graphics.getHeight() - 60, love.graphics.getWidth(), "center")
        end
    end

    -- Draw instructions overlay last (if showing)
    if instructions.showing then
        instructions.draw()
    end

    -- Draw FPS counter (always visible)
    love.graphics.setColor(1, 1, 1)
    local fps = love.timer.getFPS()
    love.graphics.print(string.format("FPS: %d", fps), 
        love.graphics.getWidth() - 80, 30)

    -- Draw connection info (always visible)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Game State: " .. gameState, 10, 30)
    love.graphics.print("Players: " .. #table_keys(players), 10, 50)

    -- Draw score lobby if showing
    scoreLobby.draw()
    
    -- Draw score display if showing
    drawScoreDisplay()
    
    -- Draw debug console last so it's always on top
    debugConsole.draw()
    
    -- Draw tab menu (always on top)
    drawTabMenu()
end

function drawButton(button, effectId)
    if button.visible == false then return end
    
    local x, y, r = button.x, button.y, 0
    local sx, sy = 1, 1  -- Default scale values
    
    if effectId then
        -- Get ALL transform values including scale
        x, y, r, sx, sy = musicHandler.applyToDrawable(effectId, x, y)
        -- Debug print
        print(effectId, "scale:", sx, sy)
    end
    
    love.graphics.push()
    
    -- Move to button center for rotation AND scaling
    love.graphics.translate(x + button.width/2, y + button.height/2)
    if r then 
        love.graphics.rotate(r)
    end
    -- Apply scale BEFORE moving back
    love.graphics.scale(sx, sy)
    love.graphics.translate(-button.width/2, -button.height/2)
    
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.rectangle("fill", 0, 0, button.width, button.height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(button.text, 0, 15, button.width, "center")
    
    love.graphics.pop()
end

function drawInputField()
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", 
        inputField.x, inputField.y, inputField.width, inputField.height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(inputField.text, 
        inputField.x + 5, inputField.y + 5, inputField.width - 10, "left")
    if inputField.active then
        love.graphics.rectangle("line", 
            inputField.x, inputField.y, inputField.width, inputField.height)
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then  -- Left mouse button
        if gameState == "menu" then
            if isMouseOver(buttons.play) then
                gameState = "play_menu"
            elseif isMouseOver(buttons.customize) then
                gameState = "customization"
                afterCustomization = "customize_only"
                characterCustomization.initialize(localPlayer)
                characterCustomization.init()
            elseif isMouseOver(buttons.settings) then
                gameState = "settings_menu"
            elseif isMouseOver(buttons.quit) then
                love.event.quit()
            end
        elseif gameState == "play_menu" then
            if isMouseOver(buttons.host) then
                debugConsole.addMessage("[Play Menu] Starting host game")
                startServer()
                debugConsole.addMessage(string.format("[Play Menu] After startServer(), gameState = %s", gameState))
                
                -- If server creation failed, try a fallback approach
                if not serverHost then
                    debugConsole.addMessage("[Play Menu] Server creation failed, trying fallback")
                    gameState = "hosting"
                    connected = true
                    localPlayer.id = 0
                    players = {}
                    local uniqueName = getUniquePlayerName(localPlayer.name, localPlayer.id)
                    players[localPlayer.id] = {
                        x = localPlayer.x,
                        y = localPlayer.y,
                        color = localPlayer.color,
                        id = localPlayer.id,
                        facePoints = localPlayer.facePoints,
                        name = uniqueName
                    }
                    if uniqueName ~= localPlayer.name then
                        localPlayer.name = uniqueName
                        debugConsole.addMessage("[Server] Host name changed to: " .. uniqueName)
                    end
                    debugConsole.addMessage("[Play Menu] Fallback hosting mode activated")
                end
            elseif isMouseOver(buttons.join) then
                debugConsole.addMessage("[Play Menu] Switching to connecting state")
                gameState = "connecting"
                buttons.start.visible = true
            elseif isMouseOver(buttons.back_play) then
                gameState = "menu"
            end
        elseif gameState == "settings_menu" then
            if isMouseOver(buttons.back_settings) then
                gameState = "menu"
            end
        elseif gameState == "customize_menu" then
            if isMouseOver(buttons.back_customize) then
                gameState = "menu"
            end
        elseif gameState == "customization" then
            local result = characterCustomization.mousepressed(x, y, button)
            debugConsole.addMessage(string.format("Customization result: %s", tostring(result)))
            if result == "confirm" then
                -- Apply the selected color, face, and name to localPlayer
                localPlayer.color = characterCustomization.getCurrentColor()
                localPlayer.name = characterCustomization.getPlayerName()
                
                -- Get the face canvas and create a copy to avoid reference issues
                local faceCanvas = characterCustomization.getFacePoints()
                if faceCanvas then
                    -- Create a new canvas and copy the content
                    local newCanvas = love.graphics.newCanvas(100, 100)
                    love.graphics.setCanvas(newCanvas)
                    love.graphics.clear(0, 0, 0, 0)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(faceCanvas, 0, 0)
                    love.graphics.setCanvas()
                    localPlayer.facePoints = newCanvas
                    print("[Customization] Created new canvas copy for localPlayer")
                else
                    localPlayer.facePoints = nil
                    print("[Customization] No face canvas to copy")
                end
                
                debugConsole.addMessage("[Customization] Character saved successfully")
                debugConsole.addMessage(string.format("[Customization] Name: %s", localPlayer.name))
                debugConsole.addMessage(string.format("[Customization] Face points type: %s", type(localPlayer.facePoints)))
                debugConsole.addMessage(string.format("[Customization] afterCustomization = %s", tostring(afterCustomization)))
                
                -- Save player data to file
                savefile.savePlayerData(localPlayer)
                
                -- Proceed with the stored action
                if afterCustomization == "host" then
                    debugConsole.addMessage("[Customization] Calling startServer()")
                    startServer()
                    debugConsole.addMessage(string.format("[Customization] After startServer(), gameState = %s", gameState))
                    
                    -- If server creation failed, try a fallback approach
                    if not serverHost then
                        debugConsole.addMessage("[Customization] Server creation failed, trying fallback")
                        gameState = "hosting"
                        connected = true
                        localPlayer.id = 0
                        players = {}
                        local uniqueName = getUniquePlayerName(localPlayer.name, localPlayer.id)
                        players[localPlayer.id] = {
                            x = localPlayer.x,
                            y = localPlayer.y,
                            color = localPlayer.color,
                            id = localPlayer.id,
                            facePoints = localPlayer.facePoints,
                            name = uniqueName
                        }
                        if uniqueName ~= localPlayer.name then
                            localPlayer.name = uniqueName
                            debugConsole.addMessage("[Server] Host name changed to: " .. uniqueName)
                        end
                        debugConsole.addMessage("[Customization] Fallback hosting mode activated")
                    end
                elseif afterCustomization == "join" then
                    debugConsole.addMessage("[Customization] Switching to connecting state")
                    gameState = "connecting"
                    buttons.start.visible = true
                elseif afterCustomization == "customize_only" then
                    debugConsole.addMessage("[Customization] Returning to main menu")
                    gameState = "menu"
                end
            elseif result == "cancel" then
                debugConsole.addMessage("[Customization] Cancelled, returning to main menu")
                gameState = "menu"
            end
        elseif gameState == "connecting" and isMouseOver(buttons.start) then
            startNetworking()
        elseif isMouseOver(inputField) then
            inputField.active = true
        else
            inputField.active = false
        end
    end
    
    -- Handle game-specific mouse input
    -- Battle royale uses spacebar for power-ups, not mouse
end

function love.keypressed(key)
    print("[Main] Key pressed: " .. key .. " in gameState: " .. gameState)
    debugConsole.addMessage("[Main] Key pressed: " .. key .. " in gameState: " .. gameState)
    
    -- Handle customization keyboard input
    if gameState == "customization" then
        local handled = characterCustomization.keypressed(key)
        if handled then
            return
        end
    end
    
    if key == "f3" then  
        debugConsole.toggle()
        debugConsole.addMessage("[DEBUG] F3 pressed - console toggled!")
    end

    -- Handle TAB key for tab menu (works anywhere in the game except menus)
    if key == "tab" then
        -- Don't show tab menu in menu states
        if gameState == "menu" or gameState == "play_menu" or gameState == "settings_menu" or gameState == "customization" then
            return
        end
        
        if not tabMenu.tabHeld then
            tabMenu.tabHeld = true
            tabMenu.visible = true
            debugConsole.addMessage("[TabMenu] Tab held - menu opened")
        end
        return
    end

    if gameState == "connecting" and inputField.active then
        if key == "backspace" then
            inputField.text = inputField.text:sub(1, -2)
        end
    end


    -- Handle spacebar specifically for battle royale
    if gameState == "battleroyale" and (key == " " or key == "space") then
        print("[Main] Spacebar detected in battle royale, calling battleRoyale.keypressed")
        debugConsole.addMessage("[Main] Spacebar detected in battle royale, calling battleRoyale.keypressed")
        battleRoyale.keypressed(key)
        return
    end

    -- Handle spacebar for game mode selection in lobby
    if (gameState == "playing" or gameState == "hosting") and (key == " " or key == "space") and not levelSelector.active then
        debugConsole.addMessage("[GameMode] SPACEBAR in lobby - levelSelector.active=" .. tostring(levelSelector.active) .. ", gameModeSelection.active=" .. tostring(gameModeSelection.active))
        if not gameModeSelection.active then
            gameModeSelection.active = true
            gameModeSelection.animationTime = 0
            debugConsole.addMessage("[GameMode] Game mode selection activated")
        else
            -- Select the current mode
            if gameModeSelection.selectedMode == 1 then
                -- Level Selector mode
                debugConsole.addMessage("[GameMode] Level Selector selected")
                gameModeSelection.active = false
                levelSelector.active = true
                levelSelector.animationTime = 0
                debugConsole.addMessage("[LevelSelector] Level selector activated - active=" .. tostring(levelSelector.active))
                
                -- Only reset votes if we're the host
                if gameState == "hosting" then
                    levelSelector.votes = {}
                    levelSelector.playerVotes = {}
                    debugConsole.addMessage("[LevelSelector] Host reset votes")
                else
                    -- Client: request current votes from server
                    if server then
                        safeSend(server, "request_votes," .. localPlayer.id)
                        debugConsole.addMessage("[LevelSelector] Client requested current votes")
                    end
                end
                
                -- Initialize lastSelectedGame to first game
                levelSelector.lastSelectedGame = 1
            elseif gameModeSelection.selectedMode == 2 then
                -- Party Mode
                debugConsole.addMessage("[GameMode] Party Mode selected")
                partyMode = true
                _G.partyMode = partyMode
                gameModeSelection.active = false
                debugConsole.addMessage("[Party Mode] Enabled via game mode selection")
                
                -- Shuffle the game lineup for random order
                miniGameLineup = shuffleGameLineup()
                debugConsole.addMessage("[Party Mode] Game lineup shuffled: " .. table.concat(miniGameLineup, ", "))
                
                -- Start the first game in party mode (same as P key)
                if gameState == "hosting" then
                    currentGameIndex = 1  -- Reset game index to start from beginning
                    local firstGame = miniGameLineup[1]
                    currentPartyGame = firstGame
                    partyModeTransitioned = false  -- Reset transition flag
                    
                    debugConsole.addMessage("[Party Mode] Starting first game: " .. firstGame)
                    
                    -- Start party music immediately
                    musicHandler.loadPartyMusic()
                    debugConsole.addMessage("[Party Mode] Starting party music")
                    
                    -- Notify clients that party mode has started
                    for _, client in ipairs(serverClients) do
                        safeSend(client, "start_party_mode")
                    end
                    
                    -- Start the first game directly from the shuffled lineup
                    if firstGame == "jumpgame" then
                        -- Notify clients BEFORE showing host instructions
                        for _, client in ipairs(serverClients) do
                            safeSend(client, "show_jump_instructions")
                        end
                        
                        instructions.show("jumpgame", function()
                            -- Start party music only after the first instruction if in party mode
                            if partyMode and isFirstPartyInstruction then
                                musicHandler.loadPartyMusic()
                                isFirstPartyInstruction = false  -- Clear the flag
                                debugConsole.addMessage("[Party Mode] Starting music after first instruction")
                            end

                            gameState = "jumpgame"
                            returnState = "hosting"
                            _G.returnState = "hosting"
                            initializeRoundWins()
                            jumpGame.reset(players)
                            jumpGame.setPlayerColor(localPlayer.color)

                            -- Only send game start after instructions
                            for _, client in ipairs(serverClients) do
                                safeSend(client, "start_jump_game")
                            end
                        end)
                    elseif firstGame == "lasergame" then
                        -- Notify clients BEFORE showing host instructions
                        for _, client in ipairs(serverClients) do
                            safeSend(client, "show_laser_instructions")
                        end
                        
                        instructions.show("lasergame", function()
                            gameState = "lasergame"
                            returnState = "hosting"
                            _G.returnState = "hosting"
                            initializeRoundWins()
                            laserGame.load()
                            laserGame.reset()
                            laserGame.setPlayerColor(localPlayer.color)

                            -- Only send game start after instructions
                            for _, client in ipairs(serverClients) do
                                safeSend(client, "start_laser_game")
                            end
                        end)
                    elseif firstGame == "battleroyale" then
                        -- Notify clients BEFORE showing host instructions
                        for _, client in ipairs(serverClients) do
                            safeSend(client, "show_battle_royale_instructions")
                        end
                        
                        instructions.show("battleroyale", function()
                            gameState = "battleroyale"
                            returnState = "hosting"
                            _G.returnState = "hosting"
                            initializeRoundWins()
                            battleRoyale.load()
                            battleRoyale.reset()
                            battleRoyale.setPlayerColor(localPlayer.color)

                            -- Only send game start after instructions
                            for _, client in ipairs(serverClients) do
                                safeSend(client, "start_battle_royale")
                            end
                        end)
                    elseif firstGame == "dodgegame" then
                        -- Notify clients BEFORE showing host instructions
                        for _, client in ipairs(serverClients) do
                            safeSend(client, "show_dodge_instructions")
                        end
                        
                        instructions.show("dodgegame", function()
                            gameState = "dodgegame"
                            returnState = "hosting"
                            _G.returnState = "hosting"
                            initializeRoundWins()
                            dodgeGame.load()
                            dodgeGame.setPlayerColor(localPlayer.color)
                            local seed = math.random(1000000)
                            dodgeGame.setSeed(seed)

                            -- Only send game start after instructions
                            for _, client in ipairs(serverClients) do
                                safeSend(client, "start_dodge_game," .. seed)
                            end
                        end)
                    end
                end
            end
        end
        return
    end

    -- Handle WASD keys for game mode selection
    if gameModeSelection.active and (key == "w" or key == "s") then
        if key == "w" then
            gameModeSelection.selectedMode = gameModeSelection.selectedMode - 1
            if gameModeSelection.selectedMode < 1 then
                gameModeSelection.selectedMode = #gameModeSelection.modes
            end
        elseif key == "s" then
            gameModeSelection.selectedMode = gameModeSelection.selectedMode + 1
            if gameModeSelection.selectedMode > #gameModeSelection.modes then
                gameModeSelection.selectedMode = 1
            end
        end
        debugConsole.addMessage("[GameMode] Selected mode: " .. gameModeSelection.modes[gameModeSelection.selectedMode])
        return
    end

    -- Handle ESC to cancel game mode selection
    if gameModeSelection.active and key == "escape" then
        gameModeSelection.active = false
        debugConsole.addMessage("[GameMode] Game mode selection cancelled")
        return
    end

    -- Handle page navigation with Q/E keys
    if levelSelector.active and (key == "q" or key == "e") then
        if key == "q" then
            -- Previous page
            levelSelector.currentPage = levelSelector.currentPage - 1
            if levelSelector.currentPage < 1 then
                levelSelector.currentPage = #levelSelector.pages
            end
        elseif key == "e" then
            -- Next page
            levelSelector.currentPage = levelSelector.currentPage + 1
            if levelSelector.currentPage > #levelSelector.pages then
                levelSelector.currentPage = 1
            end
        end
        
        -- Reset selected level when changing pages
        levelSelector.selectedLevel = 1
        levelSelector.loadedImages = {} -- Clear cached images for new page
        
        debugConsole.addMessage("[LevelSelector] Switched to page " .. levelSelector.currentPage .. " of " .. #levelSelector.pages)
        return
    end

    -- Handle level selector navigation with WASD (grid navigation)
    if levelSelector.active and (key == "w" or key == "s" or key == "a" or key == "d") then
        local currentRow = math.floor((levelSelector.selectedLevel - 1) / levelSelector.gridCols)
        local currentCol = (levelSelector.selectedLevel - 1) % levelSelector.gridCols
        
        if key == "w" then
            -- Move up
            currentRow = currentRow - 1
            if currentRow < 0 then
                currentRow = levelSelector.gridRows - 1
            end
        elseif key == "s" then
            -- Move down
            currentRow = currentRow + 1
            if currentRow >= levelSelector.gridRows then
                currentRow = 0
            end
        elseif key == "a" then
            -- Move left
            currentCol = currentCol - 1
            if currentCol < 0 then
                currentCol = levelSelector.gridCols - 1
            end
        elseif key == "d" then
            -- Move right
            currentCol = currentCol + 1
            if currentCol >= levelSelector.gridCols then
                currentCol = 0
            end
        end
        
        -- Calculate new level index
        levelSelector.selectedLevel = currentRow * levelSelector.gridCols + currentCol + 1
        
        -- Make sure we don't go out of bounds
        if levelSelector.selectedLevel > #levelSelector.pages[levelSelector.currentPage] then
            levelSelector.selectedLevel = #levelSelector.pages[levelSelector.currentPage]
        end
        
        -- Update lastSelectedGame if we're selecting an actual game (not Race Game)
        if levelSelector.selectedLevel <= 4 then
            levelSelector.lastSelectedGame = levelSelector.selectedLevel
            debugConsole.addMessage("[LevelSelector] Updated lastSelectedGame to: " .. levelSelector.selectedLevel .. " (" .. levelSelector.pages[levelSelector.currentPage][levelSelector.selectedLevel].name .. ")")
        end
        
        debugConsole.addMessage("[LevelSelector] Selected level: " .. levelSelector.pages[levelSelector.currentPage][levelSelector.selectedLevel].name)
        return
    end

    -- Handle level selection
    if levelSelector.active and (key == " " or key == "space") then
        local selectedLevel = levelSelector.pages[levelSelector.currentPage][levelSelector.selectedLevel]
        debugConsole.addMessage("[LevelSelector] SPACEBAR pressed - levelSelector.active=" .. tostring(levelSelector.active) .. ", gameState=" .. gameState)
        
        -- Prevent voting for "Coming Soon" levels
        if selectedLevel.name == "Coming Soon" then
            debugConsole.addMessage("[LevelSelector] Cannot vote for Coming Soon level")
            return
        end
        
        if gameState == "hosting" then
            -- Host votes directly (no need to send to server)
            debugConsole.addMessage("[LevelSelector] Host voting for level: " .. selectedLevel.name)
            
            -- Host processes vote directly
            local playerId = localPlayer.id
            local levelIndex = levelSelector.selectedLevel
            
            -- Remove previous vote if exists
            if levelSelector.playerVotes[playerId] then
                local oldVote = levelSelector.playerVotes[playerId]
                if levelSelector.votes[oldVote] then
                    for i, pid in ipairs(levelSelector.votes[oldVote]) do
                        if pid == playerId then
                            table.remove(levelSelector.votes[oldVote], i)
                            break
                        end
                    end
                end
            end
            
            -- Add new vote
            levelSelector.playerVotes[playerId] = levelIndex
            if not levelSelector.votes[levelIndex] then
                levelSelector.votes[levelIndex] = {}
            end
            table.insert(levelSelector.votes[levelIndex], playerId)
            
            debugConsole.addMessage("[LevelSelector] Host voted for level " .. levelIndex .. " (" .. selectedLevel.name .. ")")
            
            -- Debug: Check vote data after host vote
            debugConsole.addMessage("[HostVote] playerVotes[" .. playerId .. "] = " .. tostring(levelSelector.playerVotes[playerId]))
            debugConsole.addMessage("[HostVote] votes[" .. levelIndex .. "] has " .. #levelSelector.votes[levelIndex] .. " votes")
            for i, pid in ipairs(levelSelector.votes[levelIndex]) do
                debugConsole.addMessage("[HostVote] votes[" .. levelIndex .. "][" .. i .. "] = " .. pid)
            end
            
            -- Broadcast vote update to all clients
            for _, client in ipairs(serverClients) do
                safeSend(client, "vote_update," .. levelIndex .. "," .. playerId)
            end
            
        elseif gameState == "playing" then
            -- Client votes for the level
            debugConsole.addMessage("[LevelSelector] Client voting for level: " .. selectedLevel.name)
            
            -- Send vote to server
            if server then
                local voteMessage = "level_vote," .. levelSelector.selectedLevel .. "," .. localPlayer.id
                debugConsole.addMessage("[Client] Sending vote message: " .. voteMessage)
                safeSend(server, voteMessage)
                debugConsole.addMessage("[Client] Vote message sent successfully")
            else
                debugConsole.addMessage("[Client] ERROR: No server connection!")
            end
        end
        return
    end
    
    -- TEST: Add a test vote with 't' key
    if levelSelector.active and key == "t" then
        debugConsole.addMessage("[TEST] Adding test vote for level " .. levelSelector.selectedLevel)
        local playerId = localPlayer.id or 1
        local levelIndex = levelSelector.selectedLevel
        
        -- Add test vote
        if not levelSelector.votes[levelIndex] then
            levelSelector.votes[levelIndex] = {}
        end
        table.insert(levelSelector.votes[levelIndex], playerId)
        levelSelector.playerVotes[playerId] = levelIndex
        
        debugConsole.addMessage("[TEST] Added test vote - level " .. levelIndex .. " now has " .. #levelSelector.votes[levelIndex] .. " votes")
        return
    end
    
    -- Handle ENTER key for host to launch selected game
    if levelSelector.active and key == "return" and gameState == "hosting" then
        local selectedLevel = levelSelector.pages[levelSelector.currentPage][levelSelector.selectedLevel]
        debugConsole.addMessage("[LevelSelector] Host launching level: " .. selectedLevel.name)
        levelSelector.active = false
        
        if levelSelector.selectedLevel == 1 then
            gameState = "jumpgame"
            jumpGame.load()
            jumpGame.reset(players)
            jumpGame.setPlayerColor(localPlayer.color)
            debugConsole.addMessage("[Game] Started Jump Game")
            
            -- Notify clients to start jump game
            for _, client in ipairs(serverClients) do
                safeSend(client, "start_jump_game")
            end
        elseif levelSelector.selectedLevel == 2 then
            gameState = "lasergame"
            local seed = os.time() + love.timer.getTime() * 10000
            laserGame.load()
            laserGame.reset()
            laserGame.setSeed(seed)
            laserGame.setPlayerColor(localPlayer.color)
            debugConsole.addMessage("[Game] Started Laser Game")
            
            -- Notify clients to start laser game
            for _, client in ipairs(serverClients) do
                safeSend(client, "start_laser_game," .. seed)
            end
        elseif levelSelector.selectedLevel == 3 then
            gameState = "battleroyale"
            local seed = os.time() + love.timer.getTime() * 10000
            battleRoyale.load()
            battleRoyale.reset()
            battleRoyale.setSeed(seed)
            battleRoyale.setPlayerColor(localPlayer.color)
            debugConsole.addMessage("[Game] Started Battle Royale")
            
            -- Notify clients to start battle royale
            for _, client in ipairs(serverClients) do
                safeSend(client, "start_battleroyale_game," .. seed)
            end
        elseif levelSelector.selectedLevel == 4 then
            gameState = "dodgegame"
            local seed = os.time() + love.timer.getTime() * 10000
            dodgeGame.load()
            dodgeGame.reset()
            dodgeGame.setSeed(seed)
            dodgeGame.setPlayerColor(localPlayer.color)
            debugConsole.addMessage("[Game] Started Dodge Game")
            
            -- Notify clients to start dodge game
            for _, client in ipairs(serverClients) do
                safeSend(client, "start_dodge_game," .. seed)
            end
        end
        return
    end

    -- Handle ESC to cancel level selector
    if levelSelector.active and key == "escape" then
        levelSelector.active = false
        debugConsole.addMessage("[LevelSelector] Level selector cancelled")
        return
    end

    -- Handle '1' key for party mode (restored from P key functionality)
    if key == "1" then
        if gameState ~= "hosting" then
            debugConsole.addMessage("[Game] Only the host can start games")
            return
        end
        
        -- If in party mode, start the first game from the shuffled lineup
        if partyMode then
            currentGameIndex = 1  -- Reset game index to start from beginning
            local firstGame = miniGameLineup[1]
            debugConsole.addMessage("[Party Mode] Starting first game via '1' key: " .. firstGame)
            
            -- Start the first game in the party mode lineup
            if firstGame == "jumpgame" then
                -- Notify clients BEFORE showing host instructions
                for _, client in ipairs(serverClients) do
                    safeSend(client, "show_jump_instructions")
                end
                
                instructions.show("jumpgame", function()
                    -- Start party music only after the first instruction if in party mode
                    if partyMode and isFirstPartyInstruction then
                        musicHandler.loadPartyMusic()
                        isFirstPartyInstruction = false  -- Clear the flag
                        debugConsole.addMessage("[Party Mode] Starting music after first instruction")
                    end

                    gameState = "jumpgame"
                    returnState = "hosting"
                    _G.returnState = "hosting"
                    initializeRoundWins()
                    jumpGame.reset(players)
                    jumpGame.setPlayerColor(localPlayer.color)

                    -- Only send game start after instructions
                    for _, client in ipairs(serverClients) do
                        safeSend(client, "start_jump_game")
                        if partyMode and isFirstPartyInstruction then
                            safeSend(client, "start_party_music")
                        end
                    end
                end)
            else
                -- Handle other games in party mode lineup
                debugConsole.addMessage("[Party Mode] Starting " .. firstGame .. " via '1' key")
                -- The game transition logic will handle starting the appropriate game
                gameState = firstGame
                returnState = "hosting"
                _G.returnState = "hosting"
                initializeRoundWins()
                
                -- Start the appropriate game
                if firstGame == "lasergame" then
                    laserGame.load()
                    laserGame.setPlayerColor(localPlayer.color)
                    local seed = math.random(1000000)
                    laserGame.setSeed(seed)
                    for _, client in ipairs(serverClients) do
                        safeSend(client, "start_laser_game," .. seed)
                    end
                elseif firstGame == "battleroyale" then
                    battleRoyale.load()
                    battleRoyale.setPlayerColor(localPlayer.color)
                    for _, client in ipairs(serverClients) do
                        safeSend(client, "start_battle_royale")
                    end
                elseif firstGame == "dodgegame" then
                    dodgeGame.load()
                    dodgeGame.setPlayerColor(localPlayer.color)
                    local seed = math.random(1000000)
                    dodgeGame.setSeed(seed)
                    for _, client in ipairs(serverClients) do
                        safeSend(client, "start_dodge_game," .. seed)
                    end
                end
            end
        else
            -- Not in party mode - start jump game normally
            -- Notify clients BEFORE showing host instructions
            for _, client in ipairs(serverClients) do
                safeSend(client, "show_jump_instructions")
            end
            
            instructions.show("jumpgame", function()
                gameState = "jumpgame"
                returnState = "hosting"
                _G.returnState = "hosting"
                initializeRoundWins()
                jumpGame.reset(players)
                jumpGame.setPlayerColor(localPlayer.color)

                -- Only send game start after instructions
                for _, client in ipairs(serverClients) do
                    safeSend(client, "start_jump_game")
                end
            end)
        end
    end

    -- Handle score lobby skip
    if scoreLobby.keypressed(key) then
        return
    end

    -- Handle score display skip
    if showScoreDisplay then
        showScoreDisplay = false
        currentRound = currentRound + 1
        debugConsole.addMessage("[Round] Starting round " .. currentRound)
        return
    end

    -- Battle royale spacebar handled above, other keys handled here
    if gameState == "battleroyale" and key ~= " " and key ~= "space" then
        battleRoyale.keypressed(key)
    end
end

function love.keyreleased(key)
    -- Handle TAB key release for tab menu
    if key == "tab" then
        tabMenu.tabHeld = false
        tabMenu.visible = false
        debugConsole.addMessage("[TabMenu] Tab released - menu closed")
    end
end

function love.textinput(t)
    if inputField.active then
        inputField.text = inputField.text .. t
    end
end

function drawInputField()
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", inputField.x, inputField.y, inputField.width, inputField.height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(inputField.text, inputField.x + 5, inputField.y + 5, inputField.width - 10, "left")
    if inputField.active then
        love.graphics.rectangle("line", inputField.x, inputField.y, inputField.width, inputField.height)
    end
end

function isMouseOver(item)
    local mx, my = love.mouse.getPosition()
    return mx > item.x and mx < item.x + item.width and my > item.y and my < item.y + item.height
end

function addStatusMessage(msg)
    debugConsole.addMessage("[Status] " .. msg)
end

function startServer()
    debugConsole.addMessage("[Server] startServer() called")
    
    -- Test if enet is available
    if not enet then
        debugConsole.addMessage("[Server] ERROR: enet library not available")
        return
    end
    
    debugConsole.addMessage("[Server] enet library is available")
    
    -- Try different ports if the first one fails
    local ports = {"12345", "12346", "12347", "12348"}
    local success = false
    
    for i, port in ipairs(ports) do
        debugConsole.addMessage(string.format("[Server] Trying port %s", port))
        serverHost = enet.host_create("0.0.0.0:" .. port)
        if serverHost then
            debugConsole.addMessage(string.format("[Server] Successfully started on port %s", port))
            success = true
            break
        else
            debugConsole.addMessage(string.format("[Server] Port %s failed", port))
        end
    end
    
    if not success then
        debugConsole.addMessage("[Server] Failed to create server on any port")
        return
    end
    
    players = {}
    peerToId = {}
        localPlayer.id = 0  -- Ensure host ID is set
        
        -- Create initial player entry with correct data
        local uniqueName = getUniquePlayerName(localPlayer.name, localPlayer.id)
        players[localPlayer.id] = {
            x = localPlayer.x,
            y = localPlayer.y,
            color = localPlayer.color,
            id = localPlayer.id,
            facePoints = characterCustomization.getFacePoints(),  -- Store the canvas directly for the host
            name = uniqueName
        }
        
        -- Update localPlayer name if it was changed
        if uniqueName ~= localPlayer.name then
            localPlayer.name = uniqueName
            debugConsole.addMessage("[Server] Host name changed to: " .. uniqueName)
        end
        
    nextClientId = 1
        gameState = "hosting"
    connected = true
    serverStatus = "Running"
        debugConsole.addMessage("[Server] Server started with face data")
    debugConsole.addMessage(string.format("[Server] Final gameState = %s, connected = %s", gameState, tostring(connected)))
end

function startNetworking()
    debugConsole.addMessage("[Client] Creating host...")
    host = enet.host_create()
    if not host then
        debugConsole.addMessage("[Client] Failed to create host")
        return
    end
    
    local address = inputField.text .. ":" .. inputPort
    debugConsole.addMessage("[Client] Connecting to " .. address .. "...")
    server = host:connect(address)
    if not server then
        debugConsole.addMessage("[Client] Failed to connect to server at " .. address)
        return
    end
    
    debugConsole.addMessage("[Client] Connection attempt sent...")
        gameState = "connecting"
        
        -- Initialize local player with correct data
        local savedColor = localPlayer.color
        local savedFace = localPlayer.facePoints
        local savedName = localPlayer.name
        local savedScore = localPlayer.totalScore
        localPlayer = {
            x = 100,
            y = 100,
            color = savedColor,
            facePoints = savedFace,  -- Preserve face data
            name = savedName,  -- Preserve name
            totalScore = savedScore,  -- Preserve score
            id = nil
        }
        players = {}
end

function handleDisconnection()
    if gameState == "jumpgame" then
        jumpGame.game_over = true
    end
    gameState = "menu"
    connected = false
    players = {}
    debugConsole.addMessage("[Connection] Disconnected from server. Returning to main menu.")
end

function handleServerMessage(id, data)
    -- Handle scores from both games
    if data:match("^jump_score,(%d+)") or data:match("^laser_score,(%d+)") then
        local score = math.floor(tonumber(data:match(",(%d+)")))
        debugConsole.addMessage("[Score] Server received score: " .. score)
        if score then
            if not players[id] then
                players[id] = {totalScore = 0}
            end
            players[id].totalScore = math.floor((players[id].totalScore or 0) + score)
            
            -- Broadcast updated score to all clients
            for _, client in ipairs(serverClients) do
                safeSend(client, string.format("total_score,%d,%d", id, math.floor(players[id].totalScore)))
            end
            debugConsole.addMessage(string.format("[Score] Server: Player %d scored %d points, total now %d", 
                id, score, players[id].totalScore))
        end
        return
    end

    -- Handle face data
    if data:match("^face_data,") then
        local face_id, face_points = data:match("^face_data,(%d+),(.+)")
        face_id = tonumber(face_id)
        if face_id and players[face_id] then
            local faceImage = deserializeFacePoints(face_points)
            if faceImage then
                players[face_id].facePoints = faceImage
                debugConsole.addMessage("[Server] Received face data for player " .. face_id)
                
                -- Forward face data to other clients
                for _, client in ipairs(serverClients) do
                    safeSend(client, data)
                end
            end
        end
        return
    end

    if data:match("^battleroyale_score,(%d+)") then
        local score = tonumber(data:match(",(%d+)"))
        if score then
            if not players[id] then players[id] = {totalScore = 0} end
            players[id].totalScore = (players[id].totalScore or 0) + score
            
            -- Broadcast updated score
            for _, client in ipairs(serverClients) do
                safeSend(client, string.format("total_score,%d,%d", id, players[id].totalScore))
            end
        end
        return
    end

    -- Handle jump game positions
    if data:match("jump_position,(%d+),([-%d.]+),([-%d.]+),([%d.]+),([%d.]+),([%d.]+)") then
        local playerId, x, y, r, g, b = data:match("jump_position,(%d+),([-%d.]+),([-%d.]+),([%d.]+),([%d.]+),([%d.]+)")
        playerId = tonumber(playerId)
        if not players[playerId] then
            players[playerId] = {}
        end
        players[playerId].jumpX = tonumber(x)
        players[playerId].jumpY = tonumber(y)
        players[playerId].color = {tonumber(r), tonumber(g), tonumber(b)}
        
        for _, client in ipairs(serverClients) do
            safeSend(client, string.format("jump_position,%d,%.2f,%.2f,%.2f,%.2f,%.2f",
                playerId, x, y, r, g, b))
        end
        return
    end
    
    
    -- Handle dodge game positions
    if data:match("dodge_position,(%d+),") then
        local parts = {}
        for part in data:gmatch("([^,]+)") do
            table.insert(parts, part)
        end
        
        if #parts >= 7 then
            local playerId = tonumber(parts[2])
            local x = tonumber(parts[3])
            local y = tonumber(parts[4])
            local r = tonumber(parts[5])
            local g = tonumber(parts[6])
            local b = tonumber(parts[7])
            
            if not players[playerId] then
                players[playerId] = {}
            end
            players[playerId].dodgeX = x
            players[playerId].dodgeY = y
            players[playerId].color = {r, g, b}
            
            -- Forward to all other clients
            for _, client in ipairs(serverClients) do
                safeSend(client, data)
            end
        end
        return
    end

    -- Handle battle royale positions
    if data:match("battle_position,(%d+),") then
        -- Parse the message step by step to avoid regex issues
        local parts = {}
        for part in data:gmatch("([^,]+)") do
            table.insert(parts, part)
        end
        
        if #parts >= 7 then
            local playerId = tonumber(parts[2])
            local x = tonumber(parts[3])
            local y = tonumber(parts[4])
            local r = tonumber(parts[5])
            local g = tonumber(parts[6])
            local b = tonumber(parts[7])
            local laserData = ""
            if #parts > 7 then
                laserData = parts[8]
            end
            
        if not players[playerId] then
            players[playerId] = {}
        end
        players[playerId].battleX = x
        players[playerId].battleY = y
        players[playerId].color = {r, g, b}
        players[playerId].battleLasers = laserData
            
            -- Debug: Show what we received and are sending
            debugConsole.addMessage("[Server] Received player " .. playerId .. " position update")
            debugConsole.addMessage("[Server] Sending player " .. playerId .. " position update")
            
            for _, client in ipairs(serverClients) do
                safeSend(client, string.format("battle_position,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%s",
                    playerId, x, y, r, g, b, laserData))
            end
        end
        return
    end

    -- Handle laser game requests
    if data:match("^request_laser_game") then
        local seed = os.time() + love.timer.getTime() * 10000
        instructions.show("lasergame", function()
            for _, client in ipairs(serverClients) do
                safeSend(client, "start_laser_game," .. seed)
            end
            gameState = "lasergame"
            returnState = "hosting"
            laserGame.load()
            laserGame.setSeed(seed)
            laserGame.setPlayerColor(localPlayer.color)
        end)
        return
    end

    -- Handle laser positions
    if data:match("^laser_position,") then
        local id, x, y, r, g, b = data:match("laser_position,(%d+),([-%d.]+),([-%d.]+),([%d.]+),([%d.]+),([%d.]+)")
        id = tonumber(id)
        if id and id ~= localPlayer.id then
            if not players[id] then
                players[id] = {}
            end
            players[id].laserX = tonumber(x)
            players[id].laserY = tonumber(y)
            players[id].color = {tonumber(r), tonumber(g), tonumber(b)}
            
            for _, client in ipairs(serverClients) do
                safeSend(client, data)
            end
        end
        return
    end
    
    

    -- Handle regular position and color updates
    local id_from_msg, x, y, r, g, b = data:match("(%d+),(%d+),(%d+),([%d.]+),([%d.]+),([%d.]+)")
    if id_from_msg and x and y and r and g and b then
        id_from_msg = tonumber(id_from_msg)
        x = tonumber(x)
        y = tonumber(y)
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        
        local existingFacePoints = players[id_from_msg] and players[id_from_msg].facePoints
        local existingScore = players[id_from_msg] and players[id_from_msg].totalScore or 0
        local existingName = players[id_from_msg] and players[id_from_msg].name or "Player"
        
        if not players[id_from_msg] then
            players[id_from_msg] = {
                x = x, 
                y = y, 
                color = {r, g, b}, 
                id = id_from_msg,
                totalScore = existingScore,
                name = existingName,
                facePoints = nil
            }
        else
            players[id_from_msg].x = x
            players[id_from_msg].y = y
            players[id_from_msg].color = {r, g, b}
            players[id_from_msg].facePoints = existingFacePoints
            players[id_from_msg].totalScore = existingScore
            players[id_from_msg].name = existingName  -- Preserve the existing name
        end

        for _, client in ipairs(serverClients) do
            safeSend(client, string.format("%d,%d,%d,%.2f,%.2f,%.2f",
                id_from_msg, x, y, r, g, b))
        end
        return
    end

    if data == "disconnect" then
        if players[id] then
            debugConsole.addMessage("Player " .. id .. " disconnected")
            players[id] = nil
            
            for _, client in ipairs(serverClients) do
                safeSend(client, "player_disconnect," .. id)
            end
        end
        return
    end

    if data == "request_party_mode" then
        partyMode = true
        _G.partyMode = partyMode -- Update global reference
        gameState = "jumpgame"
        currentPartyGame = "jumpgame"
        returnState = "hosting"
        jumpGame.reset(players)
        jumpGame.setPlayerColor(localPlayer.color)
        
        -- Broadcast to all clients
        for _, client in ipairs(serverClients) do
            safeSend(client, "start_party_mode")
        end
        return
    end

    -- Handle laser shots from clients
    if data:match("^battle_laser_shot,") then
        local playerId, laserData = data:match("^battle_laser_shot,(%d+),(.+)")
        if playerId and laserData then
            playerId = tonumber(playerId)
            -- Forward laser shot to all other clients
            for _, client in ipairs(serverClients) do
                if client ~= event.peer then -- Don't send back to sender
                    safeSend(client, data)
                end
            end
            debugConsole.addMessage("[Server] Forwarded laser shot from player " .. playerId)
        end
        return
    end

    -- Handle teleports from clients
    if data:match("^battle_teleport,") then
        local playerId, x, y = data:match("^battle_teleport,(%d+),([-%d.]+),([-%d.]+)")
        if playerId and x and y then
            playerId = tonumber(playerId)
            x, y = tonumber(x), tonumber(y)
            -- Forward teleport to all other clients
            for _, client in ipairs(serverClients) do
                if client ~= event.peer then -- Don't send back to sender
                    safeSend(client, data)
                end
            end
            debugConsole.addMessage("[Server] Forwarded teleport from player " .. playerId)
        end
        return
    end

    -- Handle power-up collection from clients
    if data:match("^battle_powerup_collected,") then
        local playerId, x, y, type, spawnTime, spawnSide = data:match("^battle_powerup_collected,(%d+),([-%d.]+),([-%d.]+),([^,]+),([-%d.]+),(%d+)")
        if playerId and x and y and type and spawnTime and spawnSide then
            playerId = tonumber(playerId)
            x, y = tonumber(x), tonumber(y)
            spawnTime, spawnSide = tonumber(spawnTime), tonumber(spawnSide)
            
            -- Power-ups removed from game - no forwarding needed
            debugConsole.addMessage("[Server] Forwarded power-up collection from player " .. playerId)
        end
        return
    end

    -- Handle round win messages
    if data:match("^round_win,(%d+)") then
        local winnerId = tonumber(data:match("^round_win,(%d+)"))
        if winnerId then
            awardRoundWin(winnerId)
            checkForScoreDisplay()
            
            -- Broadcast to all clients
            for _, client in ipairs(serverClients) do
                safeSend(client, data)
            end
        end
        return
    end

    -- Handle player name messages
    if data:match("^player_name,") then
        local playerId, playerName = data:match("player_name,(%d+),(.+)")
        if playerId and playerName then
            playerId = tonumber(playerId)
            if players[playerId] then
                -- Check for duplicate names and add suffix if needed
                local finalName = getUniquePlayerName(playerName, playerId)
                players[playerId].name = finalName
                debugConsole.addMessage("[Server] Updated player " .. playerId .. " name to: " .. finalName)
                
                -- Broadcast name update to all clients
                for _, client in ipairs(serverClients) do
                    safeSend(client, "player_name_update," .. playerId .. "," .. finalName)
                end
            end
        end
        return
    end

    -- Handle vote requests from clients
    if data:match("^request_votes,") then
        local playerId = tonumber(data:match("request_votes,(%d+)"))
        if playerId then
            -- Send current votes to the requesting client
            for levelIdx, voteList in pairs(levelSelector.votes) do
                for _, voterId in ipairs(voteList) do
                    safeSend(event.peer, "vote_update," .. levelIdx .. "," .. voterId)
                end
            end
            debugConsole.addMessage("[Server] Sent current votes to player " .. playerId)
        end
        return
    end

    -- Handle level votes
    if data:match("^level_vote,") then
        debugConsole.addMessage("[Server] Received level_vote message: " .. data)
        local levelIndex, playerId = data:match("level_vote,(%d+),(%d+)")
        levelIndex = tonumber(levelIndex)
        playerId = tonumber(playerId)
        debugConsole.addMessage("[Server] Parsed level_vote - levelIndex: " .. tostring(levelIndex) .. ", playerId: " .. tostring(playerId))
        
        if levelIndex and playerId and levelIndex >= 1 and levelIndex <= #levelSelector.levels then
            -- Remove previous vote if exists
            if levelSelector.playerVotes[playerId] then
                local oldVote = levelSelector.playerVotes[playerId]
                if levelSelector.votes[oldVote] then
                    for i, pid in ipairs(levelSelector.votes[oldVote]) do
                        if pid == playerId then
                            table.remove(levelSelector.votes[oldVote], i)
                            break
                        end
                    end
                end
            end
            
            -- Add new vote
            levelSelector.playerVotes[playerId] = levelIndex
            if not levelSelector.votes[levelIndex] then
                levelSelector.votes[levelIndex] = {}
            end
            table.insert(levelSelector.votes[levelIndex], playerId)
            
            debugConsole.addMessage("[Server] Player " .. playerId .. " voted for level " .. levelIndex .. " (" .. levelSelector.levels[levelIndex].name .. ")")
            
            -- Broadcast vote update to all clients
            for _, client in ipairs(serverClients) do
                safeSend(client, "vote_update," .. levelIndex .. "," .. playerId)
            end
            
        end
        return
    end

    debugConsole.addMessage("[Server] Unhandled message from player " .. id .. ": " .. data)
end

function handleClientMessage(data)
    debugConsole.addMessage("[Client] Received: " .. data)
    
    -- Handle simple sync test
    if data:match("^sync_test,") then
        debugConsole.addMessage("[Client] RECEIVED SYNC TEST MESSAGE!")
        return
    end
    
    -- Check if it's a game state sync message
    if data:match("^game_state_sync,") then
        debugConsole.addMessage("[Client] DETECTED game_state_sync message!")
    end
    if data:match("^start_battleroyale_game,") then
        local seed = tonumber(data:match("^start_battleroyale_game,(%d+)"))
        debugConsole.addMessage("[Client] RECEIVED BATTLE ROYALE START MESSAGE with seed: " .. seed)
        if seed then
            gameState = "battleroyale"
            returnState = "playing"
            _G.returnState = "playing"
            _G.gameState = "battleroyale"
            _G.players = players
            _G.localPlayer = localPlayer
            battleRoyale.reset()
            battleRoyale.setSeed(seed)
            battleRoyale.setPlayerColor(localPlayer.color)
            debugConsole.addMessage("[Client] Battle royale game state set to: " .. gameState)
            debugConsole.addMessage("[Client] Battle royale loaded successfully with seed: " .. seed)
        end
        return
    end
    
    if data:match("^start_dodge_game,") then
        local seed = tonumber(data:match("^start_dodge_game,(%d+)"))
        debugConsole.addMessage("[Client] RECEIVED DODGE GAME START MESSAGE with seed: " .. seed)
        if seed then
            gameState = "dodgegame"
            returnState = "playing"
            _G.returnState = "playing"
            _G.gameState = "dodgegame"
            _G.players = players
            _G.localPlayer = localPlayer
            dodgeGame.reset()
            dodgeGame.setSeed(seed)
            dodgeGame.setPlayerColor(localPlayer.color)
            debugConsole.addMessage("[Client] Dodge game state set to: " .. gameState)
            debugConsole.addMessage("[Client] Dodge game loaded successfully with seed: " .. seed)
        end
        return
    end
    -- instructions
    if data == "show_jump_instructions" then
        instructions.show("jumpgame", function() end)
        return
    end
    
    if data == "show_laser_instructions" then
        instructions.show("lasergame", function() end)
        return
    end

    if data == "start_party_music" then
        musicHandler.loadPartyMusic()
        return
    end

    if data:match("^party_transition_to,") then
        local nextGame = data:match("^party_transition_to,(.+)")
        debugConsole.addMessage("[Client] Received party mode transition to: " .. nextGame)
        
        -- Start the specific game directly
        if nextGame == "jumpgame" then
            gameState = "jumpgame"
            jumpGame.reset(players)
            jumpGame.setPlayerColor(localPlayer.color)
        elseif nextGame == "lasergame" then
            gameState = "lasergame"
            -- Client will receive seed in start_laser_game message
        elseif nextGame == "battleroyale" then
            gameState = "battleroyale"
            -- Client will receive seed in start_battleroyale_game message
        elseif nextGame == "dodgegame" then
            gameState = "dodgegame"
            -- Client will receive seed in start_dodge_game message
        end
        return
    end
    
    
    if data == "show_battleroyale_instructions" then
        instructions.show("battleroyale", function() end)
        return
    end
    
    if data == "show_dodge_instructions" then
        instructions.show("dodgegame", function() end)
        return
    end
    


    -- Handle total score updates from server
    if data:match("^total_score,(%d+),(%d+)") then
        local id, score = data:match("^total_score,(%d+),(%d+)")
        id = tonumber(id)
        score = math.floor(tonumber(score))
        if id then
            if not players[id] then
                players[id] = {totalScore = score}
            else
                players[id].totalScore = score
            end
            
            if id == localPlayer.id then
                localPlayer.totalScore = score
                debugConsole.addMessage(string.format("[Score] Client: Total score updated to: %d", score))
            end
        end
        return
    end

    if data:match("^battleroyale_score,(%d+)") then
        local score = tonumber(data:match(",(%d+)"))
        if score then
            local previousScore = localPlayer.totalScore or 0
            localPlayer.totalScore = previousScore + score
            if players[localPlayer.id] then
                players[localPlayer.id].totalScore = localPlayer.totalScore
            end
            if server then
                safeSend(server, string.format("total_score,%d,%d", localPlayer.id, localPlayer.totalScore))
            end
        end
        return
    end

    -- Handle direct game score updates
    if data:match("^jump_score,(%d+)") or data:match("^laser_score,(%d+)") then
        local score = math.floor(tonumber(data:match(",(%d+)")))
        debugConsole.addMessage("[Score] Client received game score: " .. score)
        if score then
            -- Preserve existing score
            local previousScore = localPlayer.totalScore or 0
            -- Add new score
            localPlayer.totalScore = previousScore + score
            
            -- Update player table to match
            if players[localPlayer.id] then
                players[localPlayer.id].totalScore = localPlayer.totalScore
            end
            
            -- Confirm back to server
            if server then
                safeSend(server, string.format("total_score,%d,%d", localPlayer.id, localPlayer.totalScore))
            end
            
            debugConsole.addMessage(string.format("[Score] Client: Added %d to previous %d, new total: %d", 
                score, previousScore, localPlayer.totalScore))
        end
        return
    end
    
    if data:match("^face_data,") then
        local face_id, face_points = data:match("^face_data,(%d+),(.+)")
        face_id = tonumber(face_id)
        if face_id then
            local faceImage = deserializeFacePoints(face_points)
            if faceImage then
                if not players[face_id] then
                    players[face_id] = {
                        x = 100,
                        y = 100,
                        color = {1, 1, 1},
                        id = face_id,
                        totalScore = 0
                    }
                end
                players[face_id].facePoints = faceImage
                debugConsole.addMessage("[Client] Updated face for player " .. face_id)
            end
        end
        return
    end

    if data == "start_jump_game" then
        gameState = "jumpgame"
        returnState = "playing"
        jumpGame.reset(players)
        jumpGame.setPlayerColor(localPlayer.color)
        return
    end


    -- Handle synchronized game state from host
    if data:match("^game_state_sync,") then
        debugConsole.addMessage("[Client] Received game_state_sync message!")
        local parts = {}
        for part in data:gmatch("([^,]+)") do
            table.insert(parts, part)
        end
        
        debugConsole.addMessage("[Client] Message parts: " .. #parts)
        for i, part in ipairs(parts) do
            debugConsole.addMessage("[Client] Part " .. i .. ": " .. part)
        end
        
        if #parts >= 7 then
            local powerUpData = parts[2]
            local meteoroidData = parts[3]
            local center_x = tonumber(parts[4])
            local center_y = tonumber(parts[5])
            local radius = tonumber(parts[6])
            local gameTime = tonumber(parts[7])
            
            -- Update safe zone
            battleRoyale.center_x = center_x
            battleRoyale.center_y = center_y
            battleRoyale.safe_zone_radius = radius
            
            -- Update game timer
            battleRoyale.timer = gameTime
            
            debugConsole.addMessage("[Client] Updated safe zone: " .. center_x .. "," .. center_y .. "," .. radius)
            debugConsole.addMessage("[Client] Updated timer: " .. gameTime)
        else
            debugConsole.addMessage("[Client] Invalid game_state_sync message format - expected 7 parts, got " .. #parts)
        end
        return
    end


    if data:match("high_score,(%d+)") then
        highScore = tonumber(data:match("high_score,(%d+)")) -- wtf
        debugConsole.addMessage("New high score: " .. highScore)
        return
    end

    if data:match("jump_position,(%d+),([-%d.]+),([-%d.]+),([%d.]+),([%d.]+),([%d.]+)") then
        local playerId, x, y, r, g, b = data:match("jump_position,(%d+),([-%d.]+),([-%d.]+),([%d.]+),([%d.]+),([%d.]+)")
        playerId = tonumber(playerId)
        if playerId ~= localPlayer.id then
            if not players[playerId] then
                players[playerId] = {}
            end
            players[playerId].jumpX = tonumber(x)
            players[playerId].jumpY = tonumber(y)
            players[playerId].color = {tonumber(r), tonumber(g), tonumber(b)}
        end
        return
    end

    if data:match("^start_laser_game,(%d+)") then
        local seed = tonumber(data:match("^start_laser_game,(%d+)"))
        gameState = "lasergame"
        returnState = "playing"
        laserGame.load()
        laserGame.setSeed(seed)
        laserGame.setPlayerColor(localPlayer.color)
        return
    end
    
    
    
    if data:match("^laser_position,") then
        local id, x, y, r, g, b = data:match("laser_position,(%d+),([-%d.]+),([-%d.]+),([%d.]+),([%d.]+),([%d.]+)")
        id = tonumber(id)
        if id and id ~= localPlayer.id then
            if not players[id] then
                players[id] = {}
            end
            players[id].laserX = tonumber(x)
            players[id].laserY = tonumber(y)
            players[id].color = {tonumber(r), tonumber(g), tonumber(b)}
        end
        return
    end
    

    if data:match("^dodge_position,") then
        -- Parse the message using comma delimiter like laser game
        local parts = {}
        for part in data:gmatch("([^,]+)") do
            table.insert(parts, part)
        end
        
        if #parts >= 7 then
            local id = tonumber(parts[2])
            local x = tonumber(parts[3])
            local y = tonumber(parts[4])
            local r = tonumber(parts[5])
            local g = tonumber(parts[6])
            local b = tonumber(parts[7])
            
            if id and id ~= localPlayer.id then
                if not players[id] then
                    players[id] = {}
                end
                players[id].dodgeX = x
                players[id].dodgeY = y
                players[id].color = {r, g, b}
            end
        end
        return
    end

    if data:match("^race_position,") then
        -- Parse the message using comma delimiter like laser game
        local parts = {}
        for part in data:gmatch("([^,]+)") do
            table.insert(parts, part)
        end
        
        if #parts >= 7 then
            local id = tonumber(parts[2])
            local x = tonumber(parts[3])
            local y = tonumber(parts[4])
            local r = tonumber(parts[5])
            local g = tonumber(parts[6])
            local b = tonumber(parts[7])
            
            if id and id ~= localPlayer.id then
                if not players[id] then
                    players[id] = {}
                end
                players[id].raceX = x
                players[id].raceY = y
                players[id].color = {r, g, b}
            end
        end
        return
    end

    if data:match("^battle_position,") then
        -- Parse the message using comma delimiter like laser game
        local parts = {}
        for part in data:gmatch("([^,]+)") do
            table.insert(parts, part)
        end
        
        if #parts >= 7 then
            local id = tonumber(parts[2])
            local x = tonumber(parts[3])
            local y = tonumber(parts[4])
            local r = tonumber(parts[5])
            local g = tonumber(parts[6])
            local b = tonumber(parts[7])
            local laserData = parts[8] or ""
            
            if id and id ~= localPlayer.id then
                if not players[id] then
                    players[id] = {}
                end
                players[id].battleX = x
                players[id].battleY = y
                players[id].color = {r, g, b}
                players[id].battleLasers = laserData
            end
        end
        return
    end


    -- Handle your_id assignment
    if data:match("your_id,(%d+)") then
        localPlayer.id = tonumber(data:match("your_id,(%d+)"))
        debugConsole.addMessage("[Client] Assigned player ID: " .. localPlayer.id)
        
        players[localPlayer.id] = {
            x = localPlayer.x,
            y = localPlayer.y,
            color = localPlayer.color,
            id = localPlayer.id,
            totalScore = localPlayer.totalScore,
            facePoints = localPlayer.facePoints,
            name = localPlayer.name
        }
        
        if server then
            safeSend(server, string.format("%d,%d,%d,%.2f,%.2f,%.2f",
                localPlayer.id,
                math.floor(localPlayer.x),
                math.floor(localPlayer.y),
                localPlayer.color[1],
                localPlayer.color[2],
                localPlayer.color[3]))
            
            -- Send player name
            safeSend(server, "player_name," .. localPlayer.id .. "," .. localPlayer.name)
            debugConsole.addMessage("[Client] Sent player name: " .. localPlayer.name)
            
            if localPlayer.facePoints then
                local serializedFace = serializeFacePoints(localPlayer.facePoints)
                if serializedFace then
                    safeSend(server, "face_data," .. localPlayer.id .. "," .. serializedFace)
                    debugConsole.addMessage("[Client] Sent face data")
                end
            end
        end
        return
    end
    
    -- Handle new_player messages
    if data:match("^new_player,") then
        local id, x, y, r, g, b, name = data:match("new_player,(%d+),(%d+),(%d+),([%d.]+),([%d.]+),([%d.]+),(.+)")
        if id and x and y and r and g and b and name then
            id = tonumber(id)
            if id ~= localPlayer.id then
                players[id] = {
                    x = tonumber(x),
                    y = tonumber(y),
                    color = {tonumber(r), tonumber(g), tonumber(b)},
                    id = id,
                    name = name
                }
                debugConsole.addMessage("[Client] Added new player " .. id .. " with name: " .. name)
            end
        end
        return
    end

    -- Handle regular position updates
    local id, x, y, r, g, b = data:match("(%d+),(%d+),(%d+),([%d.]+),([%d.]+),([%d.]+)")
    if id and x and y and r and g and b then
        id = tonumber(id)
        if id ~= localPlayer.id then
            local existingFacePoints = players[id] and players[id].facePoints
            local existingScore = players[id] and players[id].totalScore or 0
            local existingName = players[id] and players[id].name or "Player"
            
            if not players[id] then
                players[id] = {
                    x = tonumber(x),
                    y = tonumber(y),
                    color = {tonumber(r), tonumber(g), tonumber(b)},
                    id = id,
                    totalScore = existingScore,
                    facePoints = nil,
                    name = existingName
                }
            else
                players[id].x = tonumber(x)
                players[id].y = tonumber(y)
                players[id].color = {tonumber(r), tonumber(g), tonumber(b)}
                players[id].facePoints = existingFacePoints
                players[id].totalScore = existingScore
                players[id].name = existingName  -- Preserve the existing name
            end
        end
        return
    end

    if data:match("player_disconnect,(%d+)") then
        local disconnected_id = tonumber(data:match("player_disconnect,(%d+)"))
        if players[disconnected_id] then
            debugConsole.addMessage("Player " .. disconnected_id .. " disconnected")
            players[disconnected_id] = nil
        end
        return
    end

    if data == "start_party_mode" then
        partyMode = true
        _G.partyMode = partyMode -- Update global reference
        -- Shuffle the game lineup for random order (clients should match host)
        miniGameLineup = shuffleGameLineup()
        debugConsole.addMessage("[Client] Game lineup shuffled: " .. table.concat(miniGameLineup, ", "))
        -- Start party music for client
        musicHandler.loadPartyMusic()
        debugConsole.addMessage("[Client] Starting party music")
        gameState = "jumpgame"
        currentPartyGame = "jumpgame"
        currentGameIndex = 1 -- Reset game index to match host
        returnState = "playing"
        jumpGame.reset(players)
        jumpGame.setPlayerColor(localPlayer.color)
        return
    end
    
    if data == "end_party_mode" then
        partyMode = false
        _G.partyMode = partyMode -- Update global reference
        currentPartyGame = nil
        gameState = "playing"
        return
    end

    -- Handle laser shots from other players
    if data:match("^battle_laser_shot,") then
        local playerId, laserData = data:match("^battle_laser_shot,(%d+),(.+)")
        if playerId and laserData and playerId ~= localPlayer.id then
            playerId = tonumber(playerId)
            local x, y, vx, vy, time, duration, size = laserData:match("([-%d.]+),([-%d.]+),([-%d.]+),([-%d.]+),([%d.]+),([%d.]+),([%d.]+)")
            if x and y and vx and vy and time and duration and size then
                x, y, vx, vy, time, duration, size = tonumber(x), tonumber(y), tonumber(vx), tonumber(vy), tonumber(time), tonumber(duration), tonumber(size)
                
                -- Store laser data for this player
                if players[playerId] then
                    players[playerId].battleLasers = laserData
                end
                debugConsole.addMessage("[Client] Received laser shot from player " .. playerId)
            end
        end
        return
    end

    -- Handle teleports from other players
    if data:match("^battle_teleport,") then
        local playerId, x, y = data:match("^battle_teleport,(%d+),([-%d.]+),([-%d.]+)")
        if playerId and x and y and playerId ~= localPlayer.id then
            playerId = tonumber(playerId)
            x, y = tonumber(x), tonumber(y)
            
            -- Update player position
            if players[playerId] then
                players[playerId].battleX = x
                players[playerId].battleY = y
            end
            debugConsole.addMessage("[Client] Received teleport from player " .. playerId)
        end
        return
    end

    -- Power-ups removed from game - no handling needed

    -- Handle battle royale game state synchronization
    if data:match("^bsync,") then
        local gameTime, centerX, centerY, radius, colorIndex, directionIndex, beatCount, changeRate, changeDuration, musicColorIndex = data:match("^bsync,([-%d.]+),([-%d.]+),([-%d.]+),([-%d.]+),([-%d]+),([-%d]+),([-%d]+),([-%d.]+),([-%d.]+),([-%d]+)")
        if gameTime and centerX and centerY and radius and colorIndex and directionIndex and beatCount and changeRate and changeDuration and musicColorIndex then
            gameTime = tonumber(gameTime)
            centerX = tonumber(centerX)
            centerY = tonumber(centerY)
            radius = tonumber(radius)
            colorIndex = tonumber(colorIndex)
            directionIndex = tonumber(directionIndex)
            beatCount = tonumber(beatCount)
            changeRate = tonumber(changeRate)
            changeDuration = tonumber(changeDuration)
            musicColorIndex = tonumber(musicColorIndex)
            
            -- Sync game state with host
            battleRoyale.gameTime = gameTime
            battleRoyale.current_color_index = colorIndex
            battleRoyale.current_direction_index = directionIndex
            battleRoyale.beat_count = beatCount
            battleRoyale.current_change_rate = changeRate
            battleRoyale.change_duration = changeDuration
            battleRoyale.music_asteroid_color_index = musicColorIndex
            
            -- Set target positions for smooth interpolation
            battleRoyale.target_center_x = centerX
            battleRoyale.target_center_y = centerY
            
            -- Smooth radius changes - only update if change is significant
            local radius_diff = math.abs(radius - (battleRoyale.target_radius or battleRoyale.safe_zone_radius))
            if radius_diff > 1.0 then -- Only update if radius changed by more than 1 pixel
                battleRoyale.target_radius = radius
            end
            
            -- Update safe zone direction based on synced direction index
            battleRoyale.safe_zone_direction = battleRoyale.safety_ring_directions[directionIndex]
            
            -- Only log sync every 60 updates (once per second) to avoid spam
            if not battleRoyale.sync_log_timer then battleRoyale.sync_log_timer = 0 end
            battleRoyale.sync_log_timer = battleRoyale.sync_log_timer + 1
            if battleRoyale.sync_log_timer >= 60 then
                debugConsole.addMessage("[Client] Synced game state: time=" .. gameTime .. ", center=(" .. centerX .. "," .. centerY .. "), radius=" .. radius .. ", color=" .. colorIndex .. ", direction=" .. directionIndex .. ", beats=" .. beatCount .. ", changeRate=" .. changeRate .. ", changeDuration=" .. changeDuration)
                battleRoyale.sync_log_timer = 0
            end
        end
        return
    end

    -- Handle round win messages
    if data:match("^round_win,(%d+)") then
        local winnerId = tonumber(data:match("^round_win,(%d+)"))
        if winnerId then
            awardRoundWin(winnerId)
            checkForScoreDisplay()
        end
        return
    end

    -- Handle player name update messages
    if data:match("^player_name_update,") then
        local playerId, playerName = data:match("player_name_update,(%d+),(.+)")
        if playerId and playerName then
            playerId = tonumber(playerId)
            if players[playerId] then
                players[playerId].name = playerName
                debugConsole.addMessage("[Client] Updated player " .. playerId .. " name to: " .. playerName)
            end
        end
        return
    end

    -- Handle vote updates
    if data:match("^vote_update,") then
        local levelIndex, playerId = data:match("vote_update,(%d+),(%d+)")
        levelIndex = tonumber(levelIndex)
        playerId = tonumber(playerId)
        
        if levelIndex and playerId and levelIndex >= 1 and levelIndex <= #levelSelector.levels then
            -- Remove previous vote if exists
            if levelSelector.playerVotes[playerId] then
                local oldVote = levelSelector.playerVotes[playerId]
                if levelSelector.votes[oldVote] then
                    for i, pid in ipairs(levelSelector.votes[oldVote]) do
                        if pid == playerId then
                            table.remove(levelSelector.votes[oldVote], i)
                            break
                        end
                    end
                end
            end
            
            -- Add new vote
            levelSelector.playerVotes[playerId] = levelIndex
            if not levelSelector.votes[levelIndex] then
                levelSelector.votes[levelIndex] = {}
            end
            table.insert(levelSelector.votes[levelIndex], playerId)
            
            debugConsole.addMessage("[Client] Player " .. playerId .. " voted for level " .. levelIndex .. " (" .. levelSelector.levels[levelIndex].name .. ")")
        end
        return
    end

    debugConsole.addMessage("Unhandled message format: " .. data)
end

--////////// OLD CHECK SERVER ///////// KEEP THIS AS BACKUP

--[[
function checkServerStatus()
    if gameState == "jumpgame" or gameState == "hosting" then   -- Don't check status during jump game or if we're hosting
        serverStatus = "Running"
        return
    end

    local testHost = enet.host_create()
    if not testHost then return end
    
    local testServer = testHost:connect("localhost:12345")
    if not testServer then 
        testHost:destroy()
        return 
    end
    
    local startTime = love.timer.getTime()
    while love.timer.getTime() - startTime < 0.1 do
        local event = testHost:service(0)
        if event and event.type == "connect" then
            testServer:disconnect()
            testHost:flush()
            serverStatus = "Running"
            return
        end
    end
    
    serverStatus = "Not Running"
    testServer:disconnect()
    testHost:flush()
end
--]]

function checkServerStatus()
    local oldStatus = serverStatus
    -- NEVER check if we're the host
    if gameState == "hosting" then
        serverStatus = "Running"
    -- Don't create test connections if server exists
    elseif serverHost then
        serverStatus = "Running"
    else
        serverStatus = "Not Running"
    end
    
    -- Log status changes to debug console
    if oldStatus ~= serverStatus then
        debugConsole.addMessage("[Server] Status changed to: " .. serverStatus)
    end
end

function table_keys(t)
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    return keys
end

function table_dump(o)
    if type(o) == 'table' then
        local s = '{'
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. table_dump(v) .. ','
        end
        return s .. '}'
    else
        return tostring(o)
    end
end

function love.mousemoved(x, y)
    if gameState == "customization" then
        characterCustomization.mousemoved(x, y)
    end
end

function love.mousereleased(x, y, button)
    if gameState == "customization" then
        characterCustomization.mousereleased(x, y, button)
    end
end

function serializeFacePoints(canvas)
    if not canvas then return nil end
    
    local success, result = pcall(function()
        local imageData = canvas:newImageData()
        return love.data.encode("string", "base64", imageData:encode("png"))
    end)
    
    if success then
        return result
    else
        debugConsole.addMessage("[Error] Failed to serialize face: " .. tostring(result))
        return nil
    end
end

function deserializeFacePoints(str)
    if not str or str == "" then return nil end
    
    local success, result = pcall(function()
        local pngData = love.data.decode("string", "base64", str)
        local fileData = love.filesystem.newFileData(pngData, "face.png")
        local imageData = love.image.newImageData(fileData)
        return love.graphics.newImage(imageData)
    end)
    
    if success then
        return result
    else
        debugConsole.addMessage("[Error] Failed to deserialize face: " .. tostring(result))
        return nil
    end
end

function love.quit()
    -- Save player data before quitting
    savefile.savePlayerData(localPlayer)
    
    if characterCustomization.faceCanvas then
        characterCustomization.faceCanvas:release()
    end
end

function hasFaceData(player)
    return player and player.facePoints and 
            (type(player.facePoints) == "userdata" or type(player.facePoints) == "table")
end
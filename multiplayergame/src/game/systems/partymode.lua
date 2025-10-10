-- ============================================================================
-- PARTY MODE MANAGER
-- ============================================================================
-- Manages party mode game rotation, timers, and transitions
-- Game sequence: Jump → Laser → Meteor → Dodge → Praise → repeat

local events = require("src.core.events")
local logger = require("src.core.logger")

local party = {}

-- Party mode state
party.active = false
party.currentGameIndex = 1
party.gameLineup = {"jump", "laser", "meteorshower", "dodge", "colorstorm", "particlecollector", "praise"}
party.roundTime = 15  -- 15 seconds per game
party.timeRemaining = 15
party.totalGamesPlayed = 0

-- Fonts for timer display
local timerFont = nil

function party.init()
    timerFont = love.graphics.newFont(24)
    logger.info("party", "Party mode initialized")
end

function party.start()
    party.active = true
    party.currentGameIndex = 1
    party.timeRemaining = party.roundTime
    party.totalGamesPlayed = 0
    
    logger.info("party", "Party mode started")
    
    -- Load party music
    local musicHandler = require("src.game.systems.musichandler")
    if musicHandler.loadPartyMusic then
        musicHandler.loadPartyMusic()
        logger.info("party", "Party music loaded")
    end
    
    -- Return first game to start
    return party.gameLineup[1]
end

function party.stop()
    party.active = false
    party.currentGameIndex = 1
    party.timeRemaining = party.roundTime
    logger.info("party", "Party mode stopped")
    
    -- Return to menu music
    local musicHandler = require("src.game.systems.musichandler")
    if musicHandler.loadMenuMusic then
        musicHandler.loadMenuMusic()
    end
end

function party.update(dt)
    if not party.active then return end
    
    party.timeRemaining = party.timeRemaining - dt
    
    -- Check if time is up
    if party.timeRemaining <= 0 then
        logger.info("party", "Time expired, moving to next game")
        party.nextGame()
    end
end

function party.calculateRoundWinner()
    -- Only host calculates winners
    local app = require("src.core.app")
    if not app.isHost then
        logger.info("party", "Client skipping winner calculation (host will handle)")
        return
    end
    
    -- Calculate winner for the current game that just ended
    local currentGame = party.gameLineup[party.currentGameIndex]
    local players = _G.players or {}
    
    if not players or not next(players) then
        logger.warn("party", "No players to calculate winner")
        return
    end
    
    local winnerId = nil
    local winnerScore = nil
    
    if currentGame == "jump" then
        -- Jump game: highest score (height) wins
        for id, player in pairs(players) do
            local score = player.jumpScore or 0
            if not winnerScore or score > winnerScore then
                winnerScore = score
                winnerId = id
            end
        end
        logger.info("party", "Jump game winner: Player " .. tostring(winnerId) .. " with height " .. tostring(winnerScore))
        
    elseif currentGame == "colorstorm" then
        -- Color Storm: highest score wins
        for id, player in pairs(players) do
            local score = player.colorStormScore or 0
            if not winnerScore or score > winnerScore then
                winnerScore = score
                winnerId = id
            end
        end
        logger.info("party", "Color Storm winner: Player " .. tostring(winnerId) .. " with score " .. tostring(winnerScore))
        
    elseif currentGame == "particlecollector" then
        -- Particle Collector: highest score wins
        for id, player in pairs(players) do
            local score = player.particleCollectorScore or 0
            if not winnerScore or score > winnerScore then
                winnerScore = score
                winnerId = id
            end
        end
        logger.info("party", "Particle Collector winner: Player " .. tostring(winnerId) .. " with score " .. tostring(winnerScore))
        
    elseif currentGame == "praise" then
        -- Praise game: no winner (user specified "nothing")
        logger.info("party", "Praise game has no winner")
        return
        
    else
        -- Meteor/Dodge/Laser: lowest hits/deaths wins
        for id, player in pairs(players) do
            local hits = player.battleDeaths or player.dodgeHits or player.laserHits or 0
            if not winnerScore or hits < winnerScore then
                winnerScore = hits
                winnerId = id
            end
        end
        logger.info("party", currentGame .. " game winner: Player " .. tostring(winnerId) .. " with " .. tostring(winnerScore) .. " hits")
    end
    
    -- Award point to winner (host only)
    if winnerId and players[winnerId] then
        players[winnerId].totalScore = (players[winnerId].totalScore or 0) + 1
        logger.info("party", "Player " .. winnerId .. " awarded 1 point. Total: " .. players[winnerId].totalScore)
        
        -- Update local player's totalScore if they're the winner
        if _G.localPlayer and _G.localPlayer.id == winnerId then
            _G.localPlayer.totalScore = players[winnerId].totalScore
        end
        
        -- Broadcast the winner's score to all clients
        events.emit("player:score_update", {
            id = winnerId,
            totalScore = players[winnerId].totalScore
        })
        logger.info("party", "Host broadcasting winner score for player " .. winnerId)
    end
end

function party.nextGame()
    if not party.active then return end
    
    -- Calculate winner of the game that just ended (before incrementing)
    party.calculateRoundWinner()
    
    party.totalGamesPlayed = party.totalGamesPlayed + 1
    party.currentGameIndex = party.currentGameIndex + 1
    
    -- Loop back to start
    if party.currentGameIndex > #party.gameLineup then
        party.currentGameIndex = 1
        logger.info("party", "Completed full rotation, starting over")
    end
    
    -- Sync all player scores before transitioning
    if _G.localPlayer and _G.localPlayer.id and _G.localPlayer.totalScore then
        events.emit("player:score_update", {
            id = _G.localPlayer.id,
            totalScore = _G.localPlayer.totalScore
        })
        logger.info("party", "Synced local player score: " .. _G.localPlayer.totalScore)
    end
    
    -- Reset timer
    party.timeRemaining = party.roundTime
    
    -- Emit event to transition to next game
    local nextMode = party.gameLineup[party.currentGameIndex]
    logger.info("party", "Transitioning to: " .. nextMode)
    
    events.emit("party:next_game", {
        mode = nextMode,
        gameIndex = party.currentGameIndex
    })
end

function party.drawTimer()
    if not party.active then return end
    if not timerFont then party.init() end
    
    -- Draw timer at top middle of screen
    love.graphics.push()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(timerFont)
    
    -- Format time with 1 decimal place
    local timeText = string.format("TIME: %.1f", math.max(0, party.timeRemaining))
    
    -- Get text width for centering
    local textWidth = timerFont:getWidth(timeText)
    
    -- Draw at top center with background
    local x = (800 - textWidth) / 2
    local y = 10
    
    -- Semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x - 10, y - 5, textWidth + 20, 35)
    
    -- Timer text
    if party.timeRemaining <= 3 then
        -- Flash red when time is low
        local flash = math.sin(party.timeRemaining * 10) * 0.5 + 0.5
        love.graphics.setColor(1, flash, flash, 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.printf(timeText, 0, y, 800, "center")
    
    -- Draw game counter
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.printf(
        "Game " .. party.currentGameIndex .. " of " .. #party.gameLineup .. " | Round " .. (party.totalGamesPlayed + 1),
        0, y + 30, 800, "center"
    )
    
    love.graphics.pop()
end

function party.getCurrentGame()
    if not party.active then return nil end
    return party.gameLineup[party.currentGameIndex]
end

function party.isActive()
    return party.active
end

function party.getTimeRemaining()
    return party.timeRemaining
end

-- Make party mode globally accessible for compatibility
_G.partyMode = party

return party

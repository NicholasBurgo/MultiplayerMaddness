local scoreLobby = {}

-- Score lobby state
scoreLobby.showing = false
scoreLobby.timer = 0
scoreLobby.duration = 25 -- Show for 25 seconds
scoreLobby.currentRound = 1
scoreLobby.roundWins = {}
scoreLobby.players = {}
scoreLobby.animationTime = 0
scoreLobby.particleSystem = {}
scoreLobby.backgroundStars = {}

-- Text animation system (letter-by-letter, 4 phases)
scoreLobby.textAnimation = {
    currentPhase = 1, -- 1: praising first, 2: mocking last, 3: praising first again, 4: mocking last again
    letterIndex = 0,
    letterTimer = 0,
    letterDelay = 0.05, -- Much faster letter delay
    fadeTimer = 0,
    fadeDelay = 0.2, -- Shorter fade delay
    currentText = "",
    letters = {},
    phaseStartTime = 0,
    firstPlacePlayer = nil,
    lastPlacePlayer = nil
}

-- Exit voting system
scoreLobby.voting = {
    votes = {}, -- Track who has voted to quit
    spaceHeld = false,
    holdTimer = 0,
    holdDuration = 1.5, -- Hold space for 1.5 seconds to vote
    hasVoted = false,
    totalPlayers = 0,
    votesNeeded = 0
}

-- Initialize score lobby
function scoreLobby.init()
    scoreLobby.particleSystem = {}
    scoreLobby.backgroundStars = {}
    
    -- Create background stars
    for i = 1, 100 do
        table.insert(scoreLobby.backgroundStars, {
            x = math.random(0, 800),
            y = math.random(0, 600),
            size = math.random(1, 3),
            speed = math.random(20, 60),
            alpha = math.random(0.3, 0.8)
        })
    end
end

-- Generate praising message for first place
function scoreLobby.generatePraisingMessage(firstPlacePlayer)
    local playerName = firstPlacePlayer.name or ("Player " .. (firstPlacePlayer.id or "Unknown"))
    local messages = {
        "Wow! " .. playerName .. " is absolutely DOMINATING this game!",
        "Incredible! " .. playerName .. " is on fire today!",
        "Amazing! " .. playerName .. " is crushing everyone else!",
        "Outstanding! " .. playerName .. " is the clear champion!",
        "Fantastic! " .. playerName .. " is playing like a pro!",
        "Unbelievable! " .. playerName .. " is unstoppable right now!",
        "Phenomenal! " .. playerName .. " is in the zone!"
    }
    return messages[math.random(1, #messages)]
end

-- Generate mocking message for last place
function scoreLobby.generateMockingMessage(lastPlacePlayer)
    local playerName = lastPlacePlayer.name or ("Player " .. (lastPlacePlayer.id or "Unknown"))
    local messages = {
        "Oh dear... " .. playerName .. " needs some serious practice!",
        "Yikes! " .. playerName .. " might want to try a different game!",
        "Ouch! " .. playerName .. " is really struggling out there!",
        "Well... " .. playerName .. " gave it their best shot... I think?",
        "Hmm... " .. playerName .. " might need a tutorial or two!",
        "Eek! " .. playerName .. " is having a rough time!",
        "Yowch! " .. playerName .. " could use some help!"
    }
    return messages[math.random(1, #messages)]
end

-- Initialize text animation
function scoreLobby.initTextAnimation()
    local sortedPlayers = {}
    for id, wins in pairs(scoreLobby.roundWins) do
        table.insert(sortedPlayers, {id = id, wins = wins})
    end
    
    -- Sort by wins (descending)
    table.sort(sortedPlayers, function(a, b) return a.wins > b.wins end)
    
    if #sortedPlayers > 0 then
        local firstPlace = scoreLobby.players[sortedPlayers[1].id]
        local lastPlace = scoreLobby.players[sortedPlayers[#sortedPlayers].id]
        
        if firstPlace and lastPlace then
            -- Set up first praising phase
            scoreLobby.textAnimation.currentPhase = 1
            scoreLobby.textAnimation.currentText = scoreLobby.generatePraisingMessage(firstPlace)
            scoreLobby.textAnimation.letters = {}
            for letter in scoreLobby.textAnimation.currentText:gmatch(".") do
                table.insert(scoreLobby.textAnimation.letters, letter)
            end
            scoreLobby.textAnimation.letterIndex = 0
            scoreLobby.textAnimation.letterTimer = 0
            scoreLobby.textAnimation.fadeTimer = 0
            scoreLobby.textAnimation.phaseStartTime = scoreLobby.animationTime
            
            -- Store players for all phases
            scoreLobby.textAnimation.firstPlacePlayer = firstPlace
            scoreLobby.textAnimation.lastPlacePlayer = lastPlace
        end
    end
end

-- Initialize voting system
function scoreLobby.initVoting()
    scoreLobby.voting.votes = {}
    scoreLobby.voting.spaceHeld = false
    scoreLobby.voting.holdTimer = 0
    scoreLobby.voting.hasVoted = false
    
    -- Count total players and calculate votes needed (2/3 majority)
    scoreLobby.voting.totalPlayers = 0
    for id, player in pairs(scoreLobby.players) do
        scoreLobby.voting.totalPlayers = scoreLobby.voting.totalPlayers + 1
    end
    
    -- Calculate votes needed (2/3 majority, rounded up)
    scoreLobby.voting.votesNeeded = math.ceil(scoreLobby.voting.totalPlayers * 2 / 3)
    
    if _G.debugConsole and _G.debugConsole.addMessage then
        _G.debugConsole.addMessage(string.format("[Voting] Total players: %d, Votes needed: %d", 
            scoreLobby.voting.totalPlayers, scoreLobby.voting.votesNeeded))
    end
end

-- Show the score lobby
function scoreLobby.show(roundNumber, wins, playersTable)
    scoreLobby.showing = true
    scoreLobby.timer = scoreLobby.duration
    scoreLobby.currentRound = roundNumber
    scoreLobby.roundWins = wins
    scoreLobby.players = playersTable
    scoreLobby.animationTime = 0
    
    -- Initialize text animation
    scoreLobby.initTextAnimation()
    
    -- Initialize voting system
    scoreLobby.initVoting()
    
    -- Store return state
    _G.returnState = _G.gameState or "playing"
    
    -- Create celebration particles
    for i = 1, 50 do
        table.insert(scoreLobby.particleSystem, {
            x = math.random(0, 800),
            y = math.random(0, 600),
            vx = math.random(-100, 100),
            vy = math.random(-100, 100),
            life = 2.0,
            maxLife = 2.0,
            size = math.random(2, 6),
            color = {math.random(), math.random(), math.random()}
        })
    end
end

-- Update score lobby (non-blocking)
function scoreLobby.update(dt)
    if not scoreLobby.showing then return end
    
    scoreLobby.timer = scoreLobby.timer - dt
    scoreLobby.animationTime = scoreLobby.animationTime + dt
    
    -- Update text animation
    scoreLobby.updateTextAnimation(dt)
    
    -- Update voting system
    scoreLobby.updateVoting(dt)
    
    -- Update background stars
    for _, star in ipairs(scoreLobby.backgroundStars) do
        star.y = star.y + star.speed * dt
        if star.y > 600 then
            star.y = -10
            star.x = math.random(0, 800)
        end
    end
    
    -- Update particles
    for i = #scoreLobby.particleSystem, 1, -1 do
        local particle = scoreLobby.particleSystem[i]
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.life = particle.life - dt
        particle.vy = particle.vy + 200 * dt -- gravity
        
        if particle.life <= 0 then
            table.remove(scoreLobby.particleSystem, i)
        end
    end
    
    -- Auto-hide after duration
    if scoreLobby.timer <= 0 then
        scoreLobby.hide()
    end
end

-- Check if score lobby is blocking network updates
function scoreLobby.isBlockingNetwork()
    return true -- Score lobby blocks game state changes but allows voting
end

-- Update text animation (4 phases, letter-by-letter)
function scoreLobby.updateTextAnimation(dt)
    local anim = scoreLobby.textAnimation
    local phaseDuration = 6.25 -- 25 seconds / 4 phases = 6.25 seconds each
    
    -- Check for phase transitions
    local timeInPhase = scoreLobby.animationTime - anim.phaseStartTime
    if timeInPhase >= phaseDuration and anim.currentPhase < 4 then
        anim.currentPhase = anim.currentPhase + 1
        anim.phaseStartTime = scoreLobby.animationTime
        
        -- Generate new message for current phase
        if anim.currentPhase == 2 and anim.lastPlacePlayer then
            -- Second phase: mocking last place
            anim.currentText = scoreLobby.generateMockingMessage(anim.lastPlacePlayer)
        elseif anim.currentPhase == 3 and anim.firstPlacePlayer then
            -- Third phase: praising first place again
            anim.currentText = scoreLobby.generatePraisingMessage(anim.firstPlacePlayer)
        elseif anim.currentPhase == 4 and anim.lastPlacePlayer then
            -- Fourth phase: mocking last place again
            anim.currentText = scoreLobby.generateMockingMessage(anim.lastPlacePlayer)
        end
        
        -- Reset letter animation for new phase
        anim.letters = {}
        for letter in anim.currentText:gmatch(".") do
            table.insert(anim.letters, letter)
        end
        anim.letterIndex = 0
        anim.letterTimer = 0
        anim.fadeTimer = 0
    end
    
    -- Update letter display timing
    if anim.letterIndex < #anim.letters then
        anim.letterTimer = anim.letterTimer + dt
        
        -- Show next letter
        if anim.letterTimer >= anim.letterDelay then
            anim.letterIndex = anim.letterIndex + 1
            anim.letterTimer = 0
            anim.fadeTimer = 0
        end
    end
end

-- Hide score lobby
function scoreLobby.hide()
    scoreLobby.showing = false
    scoreLobby.timer = 0
    
    -- Increment round for next game
    if _G.currentRound then
        _G.currentRound = _G.currentRound + 1
        -- Also update the local currentRound variable in main.lua if it exists
        if _G.currentRound then
            -- This will be handled by the main.lua update loop
        end
        if _G.debugConsole and _G.debugConsole.addMessage then
            _G.debugConsole.addMessage("[Round] Score lobby dismissed, starting round " .. _G.currentRound)
        end
    end
end

-- Force hide score lobby (for game transitions)
function scoreLobby.forceHide()
    scoreLobby.showing = false
    scoreLobby.timer = 0
    if _G.debugConsole and _G.debugConsole.addMessage then
        _G.debugConsole.addMessage("[ScoreLobby] Force hidden due to game transition")
    end
end

-- Draw score lobby (like pre-game lobby with bold text)
function scoreLobby.draw()
    if not scoreLobby.showing then return end
    
    -- Draw lobby background (same as pre-game lobby)
    love.graphics.setColor(1, 1, 1, 1)
    if _G.lobbyBackground then
        love.graphics.draw(_G.lobbyBackground, 0, 0)
    else
        -- Fallback background if lobbyBackground not available
        love.graphics.setColor(0.2, 0.3, 0.5, 1)
        love.graphics.rectangle('fill', 0, 0, 800, 600)
    end
    
    -- Draw all players (same style as pre-game lobby)
    for id, player in pairs(scoreLobby.players) do
        if player and player.color then
            -- Draw player square (same as pre-game lobby)
            love.graphics.setColor(player.color[1], player.color[2], player.color[3])
            love.graphics.rectangle("fill", player.x or 100, player.y or 100, 50, 50)
            
            -- Draw face image if it exists (same as pre-game lobby)
            if player.facePoints and type(player.facePoints) == "userdata" then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    player.facePoints,
                    player.x or 100,
                    player.y or 100,
                    0,
                    50/100,
                    50/100
                )
            end
            
            -- Draw player name above the player (same as pre-game lobby)
            love.graphics.setColor(1, 1, 1)  -- White color for name
            love.graphics.printf(
                player.name or "Player",
                (player.x or 100) - 30,
                (player.y or 100) - 45,
                120,
                "center"
            )
            
            -- Draw player score below the name (same as pre-game lobby)
            love.graphics.setColor(1, 1, 0)  -- Yellow color for score
            love.graphics.printf(
                "Score: " .. math.floor(player.totalScore or 0),
                (player.x or 100) - 30,
                (player.y or 100) - 25,
                120,
                "center"
            )
            
            -- Draw voting status for this player
            if scoreLobby.voting.votes[id] then
                love.graphics.setColor(0, 1, 0, 1) -- Green for voted
                love.graphics.printf(
                    "VOTED TO QUIT",
                    (player.x or 100) - 40,
                    (player.y or 100) + 60,
                    120,
                    "center"
                )
            end
        end
    end
    
    -- Draw animated text in center (bold)
    scoreLobby.drawAnimatedText()
    
    -- Draw voting instructions
    scoreLobby.drawVotingInstructions()
    
    -- Draw timer
    local timerPulse = math.sin(scoreLobby.animationTime * 5) * 0.3 + 0.7
    love.graphics.setColor(1, 1, 0, timerPulse)
    love.graphics.printf(string.format("Exit sequence: %.1f seconds remaining", scoreLobby.timer), 
        0, 550, 800, "center")
end

-- Draw animated text (bold and centered)
function scoreLobby.drawAnimatedText()
    local anim = scoreLobby.textAnimation
    
    if #anim.letters == 0 then return end
    
    -- Set large font for the animated text (Love2D doesn't have setBold)
    local largeFont = love.graphics.newFont(36)
    love.graphics.setFont(largeFont)
    
    -- Calculate text position (top of screen)
    local textY = 80  -- Top area of screen
    local currentText = ""
    
    -- Build the current text based on letter index
    for i = 1, math.min(anim.letterIndex, #anim.letters) do
        currentText = currentText .. anim.letters[i]
    end
    
    -- Set color based on phase with more vibrant colors
    if anim.currentPhase == 1 or anim.currentPhase == 3 then
        -- Praising phases - bright golden color
        love.graphics.setColor(1, 0.9, 0, 1)
    else
        -- Mocking phases - bright red color
        love.graphics.setColor(1, 0.2, 0.2, 1)
    end
    
    -- Draw the text with a thick shadow effect for better visibility (bold effect)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.printf(currentText, 4, textY + 4, 800, "center")
    love.graphics.printf(currentText, 3, textY + 3, 800, "center")
    love.graphics.printf(currentText, 2, textY + 2, 800, "center")
    
    -- Reset color and draw main text
    if anim.currentPhase == 1 or anim.currentPhase == 3 then
        love.graphics.setColor(1, 0.9, 0, 1)
    else
        love.graphics.setColor(1, 0.2, 0.2, 1)
    end
    love.graphics.printf(currentText, 0, textY, 800, "center")
    
    -- Phase indicator removed for cleaner display
end

-- Draw voting instructions
function scoreLobby.drawVotingInstructions()
    local voting = scoreLobby.voting
    local currentVotes = 0
    for _ in pairs(voting.votes) do
        currentVotes = currentVotes + 1
    end
    
    -- Draw voting status
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(string.format("Votes to quit: %d/%d (Need %d for 2/3 majority)", 
        currentVotes, voting.totalPlayers, voting.votesNeeded), 
        0, 450, 800, "center")
    
    -- Draw instructions
    love.graphics.setFont(love.graphics.newFont(16))
    
    -- Check if voting is disabled in last 5 seconds
    if scoreLobby.timer <= 5 then
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.printf("Voting disabled - Final countdown!", 
            0, 480, 800, "center")
    elseif not voting.hasVoted then
        love.graphics.setColor(0.8, 0.8, 1, 1)
        love.graphics.printf("Hold SPACE for 1.5 seconds to vote to quit", 
            0, 480, 800, "center")
        
        -- Draw progress bar for space holding
        if voting.spaceHeld then
            local progress = math.min(voting.holdTimer / voting.holdDuration, 1.0)
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.printf(string.format("Voting... %.1f%%", progress * 100), 
                0, 500, 800, "center")
        end
    else
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.printf("✓ You voted to quit!", 
            0, 480, 800, "center")
    end
    
    -- Host instructions removed
end

-- Handle key press (voting system)
function scoreLobby.keypressed(key)
    if not scoreLobby.showing then return false end
    
    -- Disable voting in the last 5 seconds
    if scoreLobby.timer <= 5 then
        return false
    end
    
    local voting = scoreLobby.voting
    
    -- ESC functionality removed
    
    -- Space key for voting
    if key == "space" and not voting.hasVoted then
        voting.spaceHeld = true
        voting.holdTimer = 0
        return true
    end
    
    return false
end

-- Handle key release (voting system)
function scoreLobby.keyreleased(key)
    if not scoreLobby.showing then return false end
    
    local voting = scoreLobby.voting
    
    if key == "space" and voting.spaceHeld then
        voting.spaceHeld = false
        voting.holdTimer = 0
        return true
    end
    
    return false
end

-- Update voting system
function scoreLobby.updateVoting(dt)
    if not scoreLobby.showing then return end
    
    local voting = scoreLobby.voting
    
    -- Disable voting in the last 5 seconds
    if scoreLobby.timer <= 5 then
        return
    end
    
    -- Handle space holding for voting
    if voting.spaceHeld and not voting.hasVoted then
        voting.holdTimer = voting.holdTimer + dt
        
        -- Check if held long enough to vote
        if voting.holdTimer >= voting.holdDuration then
            voting.hasVoted = true
            voting.spaceHeld = false
            
            -- Add vote (this would need to be networked in a real implementation)
            if _G.localPlayer and _G.localPlayer.id then
                voting.votes[_G.localPlayer.id] = true
                
                if _G.debugConsole and _G.debugConsole.addMessage then
                    _G.debugConsole.addMessage(string.format("[Voting] Player %d voted to quit", _G.localPlayer.id))
                end
                
                -- Check if we have enough votes
                local currentVotes = 0
                for _ in pairs(voting.votes) do
                    currentVotes = currentVotes + 1
                end
                
                if currentVotes >= voting.votesNeeded then
                    scoreLobby.quitToLobby()
                end
            end
        end
    end
end

-- Quit to lobby
function scoreLobby.quitToLobby()
    if _G.debugConsole and _G.debugConsole.addMessage then
        _G.debugConsole.addMessage("[Voting] Quitting to lobby")
    end
    
    scoreLobby.hide()
    
    -- Set game state back to playing/hosting
    if _G.gameState then
        _G.gameState = _G.returnState or "playing"
    end
    
    -- If we're the host, notify all clients to quit to lobby
    if _G.gameState == "hosting" and _G.serverClients then
        for _, client in ipairs(_G.serverClients) do
            _G.safeSend(client, "quit_to_lobby")
        end
        if _G.debugConsole and _G.debugConsole.addMessage then
            _G.debugConsole.addMessage("[Voting] Notified all clients to quit to lobby")
        end
    end
end

return scoreLobby

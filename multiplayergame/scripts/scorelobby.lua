local scoreLobby = {}

-- Score lobby state
scoreLobby.showing = false
scoreLobby.timer = 0
scoreLobby.duration = 10 -- Show for 10 seconds
scoreLobby.currentRound = 1
scoreLobby.roundWins = {}
scoreLobby.players = {}
scoreLobby.animationTime = 0
scoreLobby.particleSystem = {}
scoreLobby.backgroundStars = {}

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

-- Show the score lobby
function scoreLobby.show(roundNumber, wins, playersTable)
    scoreLobby.showing = true
    scoreLobby.timer = scoreLobby.duration
    scoreLobby.currentRound = roundNumber
    scoreLobby.roundWins = wins
    scoreLobby.players = playersTable
    scoreLobby.animationTime = 0
    
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

-- Update score lobby
function scoreLobby.update(dt)
    if not scoreLobby.showing then return end
    
    scoreLobby.timer = scoreLobby.timer - dt
    scoreLobby.animationTime = scoreLobby.animationTime + dt
    
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

-- Hide score lobby
function scoreLobby.hide()
    scoreLobby.showing = false
    scoreLobby.timer = 0
end

-- Draw score lobby
function scoreLobby.draw()
    if not scoreLobby.showing then return end
    
    -- Animated background
    local pulse = math.sin(scoreLobby.animationTime * 2) * 0.1 + 0.9
    love.graphics.setColor(0.05, 0.05, 0.2, 0.95)
    love.graphics.rectangle('fill', 0, 0, 800, 600)
    
    -- Draw background stars
    for _, star in ipairs(scoreLobby.backgroundStars) do
        love.graphics.setColor(1, 1, 1, star.alpha)
        love.graphics.circle('fill', star.x, star.y, star.size)
    end
    
    -- Draw particles
    for _, particle in ipairs(scoreLobby.particleSystem) do
        local alpha = particle.life / particle.maxLife
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        love.graphics.circle('fill', particle.x, particle.y, particle.size)
    end
    
    -- Animated border with gradient effect
    love.graphics.setColor(0.2, 0.6, 1.0, pulse)
    love.graphics.setLineWidth(8)
    love.graphics.rectangle('line', 5, 5, 790, 590)
    love.graphics.setLineWidth(1)
    
    -- Title with pulsing effect
    local titlePulse = math.sin(scoreLobby.animationTime * 3) * 0.2 + 0.8
    love.graphics.setColor(1, 1, 0, titlePulse)
    love.graphics.printf("ROUND " .. scoreLobby.currentRound .. " COMPLETE!", 
        0, 80, 800, "center")
    
    -- Subtitle with glow
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.printf("FINAL RESULTS", 
        0, 130, 800, "center")
    
    -- Player leaderboard
    local y = 200
    local sortedPlayers = {}
    for id, wins in pairs(scoreLobby.roundWins) do
        table.insert(sortedPlayers, {id = id, wins = wins})
    end
    
    -- Sort by wins (descending)
    table.sort(sortedPlayers, function(a, b) return a.wins > b.wins end)
    
    for i, playerData in ipairs(sortedPlayers) do
        local player = scoreLobby.players[playerData.id]
        if player then
            -- Animated position background
            local bgPulse = math.sin(scoreLobby.animationTime * 4 + i) * 0.1 + 0.9
            local bgAlpha = 0.2 + (i == 1 and 0.4 or 0) -- Highlight first place
            love.graphics.setColor(0.1, 0.1, 0.3, bgAlpha * bgPulse)
            love.graphics.rectangle('fill', 150, y - 15, 500, 80)
            
            -- Position number with special styling for top 3
            if i <= 3 then
                local medalColors = {{1, 0.8, 0}, {0.7, 0.7, 0.7}, {0.8, 0.4, 0.2}}
                love.graphics.setColor(medalColors[i][1], medalColors[i][2], medalColors[i][3], 1)
                love.graphics.printf("#" .. i, 170, y + 10, 60, "center")
            else
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf("#" .. i, 170, y + 10, 60, "center")
            end
            
            -- Player color square (larger with glow)
            love.graphics.setColor(player.color[1], player.color[2], player.color[3], 1)
            love.graphics.rectangle('fill', 250, y, 50, 50)
            
            -- Player face if available
            if player.facePoints then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    player.facePoints,
                    250, y,
                    0,
                    50/100,
                    50/100
                )
            end
            
            -- Player info
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(string.format("Player %d", playerData.id), 
                320, y + 10, 150, "left")
            
            love.graphics.setColor(0.8, 0.8, 1, 1)
            love.graphics.printf(string.format("%d wins", playerData.wins), 
                320, y + 30, 150, "left")
            
            -- Special effects for first place
            if i == 1 then
                love.graphics.setColor(1, 1, 0, 0.5)
                love.graphics.printf("WINNER!", 480, y + 20, 100, "center")
            end
            
            y = y + 90
        end
    end
    
    -- Timer with pulsing effect
    local timerPulse = math.sin(scoreLobby.animationTime * 5) * 0.3 + 0.7
    love.graphics.setColor(1, 1, 0, timerPulse)
    love.graphics.printf(string.format("Next round in %.1f seconds...", scoreLobby.timer), 
        0, 520, 800, "center")
    
    -- Press any key message
    love.graphics.setColor(0.6, 0.6, 1, 1)
    love.graphics.printf("Press any key to continue", 
        0, 550, 800, "center")
end

-- Handle key press
function scoreLobby.keypressed(key)
    if scoreLobby.showing then
        scoreLobby.hide()
        return true
    end
    return false
end

return scoreLobby

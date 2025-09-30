local laserGame = {}
local debugConsole = require "scripts.debugconsole"
local musicHandler = require "scripts.musichandler"

-- Game state
laserGame.player = {}
laserGame.lasers = {}
laserGame.particles = {}
laserGame.timer = (musicHandler.beatInterval * 8)-- - (musicHandler.beatInterval / 2)
laserGame.game_over = false
laserGame.is_dead = false
laserGame.camera_y = 0
laserGame.playerColor = {1, 1, 1}
laserGame.player_size = 30
laserGame.arena_size = 600
laserGame.arena_offset_x = 0
laserGame.arena_offset_y = 0
laserGame.points_per_second = 15
laserGame.current_round_score = 0
laserGame.is_penalized = false
laserGame.penalty_timer = 0
laserGame.PENALTY_DURATION = 1.0
laserGame.hitCount = 0

-- seed stuff
laserGame.seed = 0
laserGame.random = love.math.newRandomGenerator()
laserGame.gameTime = 0
laserGame.nextLaserTime = 0
laserGame.laserSpawnPoints = {}

-- Laser properties
laserGame.laser_warn_color = {1, 0, 0, 0.3}
laserGame.laser_color = {1, 0, 0, 0.8}
laserGame.laser_warning_time = musicHandler.beatInterval / 4
laserGame.laser_active_time = 1
laserGame.laser_warning_thickness = 4  -- Thinner warning line
laserGame.laser_active_thickness = 30  -- Thicker active laser
laserGame.min_laser_interval = musicHandler.beatInterval / 4
laserGame.max_laser_interval = musicHandler.beatInterval / 4
laserGame.next_laser_time = musicHandler.beatInterval / 4
laserGame.puddles = {}
laserGame.puddle_radius = 20
laserGame.puddle_color = {1, 0, 0, 0.4}
laserGame.puddle_border_color = {1, 0.3, 0, 0.6}
laserGame.puddle_pulse_speed = 2
laserGame.puddle_pulse_amount = 0.2


-- Particle properties
laserGame.particle_lifetime = 0.5
laserGame.particles_per_end = 8
laserGame.particle_speed = 100
laserGame.particle_size = 3
laserGame.particle_colors = {
    {1, 0, 0, 1},    -- Red
    {1, 0.5, 0, 1},  -- Orange
    {1, 1, 0, 1}     -- Yellow
}

-- Sound effects
laserGame.sounds = {
    laser = love.audio.newSource("sounds/laser.mp3", "static"),
    death = love.audio.newSource("sounds/death.mp3", "static")
}

-- sound editing
laserGame.sounds.laser:setVolume(0.2)

function laserGame.createParticles(x, y, angle)
    local particles = {}
    for i = 1, laserGame.particles_per_end do
        -- Spread particles in a 90-degree arc centered on the main angle
        local spread = math.pi / 4  -- 45 degrees
        local particleAngle = angle + (love.math.random() - 0.5) * spread
        local speed = love.math.random(50, laserGame.particle_speed)
        local color = laserGame.particle_colors[love.math.random(#laserGame.particle_colors)]
        
        table.insert(particles, {
            x = x,
            y = y,
            dx = math.cos(particleAngle) * speed,
            dy = math.sin(particleAngle) * speed,
            size = love.math.random(1, laserGame.particle_size),
            lifetime = laserGame.particle_lifetime * love.math.random(0.8, 1.2),
            color = color
        })
    end
    table.insert(laserGame.particles, particles)
end

function laserGame.updateParticles(dt)
    for i = #laserGame.particles, 1, -1 do
        local particleGroup = laserGame.particles[i]
        local allDead = true
        
        for j = #particleGroup, 1, -1 do
            local particle = particleGroup[j]
            particle.lifetime = particle.lifetime - dt
            
            if particle.lifetime <= 0 then
                table.remove(particleGroup, j)
            else
                allDead = false
                particle.x = particle.x + particle.dx * dt
                particle.y = particle.y + particle.dy * dt
                particle.dy = particle.dy + 200 * dt  -- Add gravity
                -- Fade out color
                particle.color[4] = particle.lifetime / laserGame.particle_lifetime
            end
        end
        
        if allDead then
            table.remove(laserGame.particles, i)
        end
    end
end

function laserGame.load()
    laserGame.arena_offset_x = (love.graphics.getWidth() - laserGame.arena_size) / 2
    laserGame.arena_offset_y = (love.graphics.getHeight() - laserGame.arena_size) / 2

    laserGame.player = {
        x = laserGame.arena_size / 2,
        y = laserGame.arena_size / 2,
        radius = laserGame.player_size / 2,
        speed = 300
    }
    
    laserGame.lasers = {}
    laserGame.particles = {}
    laserGame.puddles = {}
    laserGame.timer = (musicHandler.beatInterval * 8)-- - (musicHandler.beatInterval / 2)
    laserGame.game_over = false
    laserGame.is_dead = false
    laserGame.next_laser_time = laserGame.min_laser_interval
    laserGame.current_round_score = 0
    laserGame.gameTime = 0
    
    -- Make sure globals exist and are valid with proper score preservation
    if not _G.players then _G.players = {} end
    if not _G.localPlayer then 
        _G.localPlayer = {
            x = 100, 
            y = 100, 
            color = {1, 1, 1}, 
            id = 0,
            totalScore = 0
        }
    end
    
    -- Preserve existing score when loading
    local existingScore = 0
    if _G.localPlayer.id and _G.players[_G.localPlayer.id] then
        existingScore = _G.players[_G.localPlayer.id].totalScore or 0
        _G.localPlayer.totalScore = existingScore
    end
    
    debugConsole.addMessage(string.format("[Laser] Game loaded with player ID: %s, existing score: %d", 
        _G.localPlayer.id or "none", existingScore))
    
    if _G.gameState == "hosting" then
        local seed = os.time() + love.timer.getTime() * 10000
        laserGame.setSeed(seed)
    end
end

function laserGame.setSeed(seed)
    laserGame.seed = seed
    laserGame.random:setSeed(seed)
    laserGame.gameTime = 0
    laserGame.nextLaserTime = 0
    laserGame.laserSpawnPoints = {}
    
    local time = 0
    while time < laserGame.timer do
        local spawnInfo = {
            time = time,
            isVertical = laserGame.random:random() < 0.5,
            position = laserGame.random:random(0, laserGame.arena_size),
            isDouble = laserGame.random:random() < 0.3
        }
        
        if spawnInfo.isDouble then
            spawnInfo.secondPosition = laserGame.random:random(0, laserGame.arena_size)
        end
        
        table.insert(laserGame.laserSpawnPoints, spawnInfo)
        time = time + laserGame.random:random(
            laserGame.min_laser_interval,
            laserGame.max_laser_interval
        )
    end
    
    debugConsole.addMessage(string.format(
        "[LaserGame] Generated %d laser spawn points with seed %d",
        #laserGame.laserSpawnPoints,
        seed
    ))
end

function laserGame.spawnLaser(spawnInfo)
    -- Spawn first laser
    local laser = {
        warning = true,
        warning_timer = laserGame.laser_warning_time,
        active_timer = laserGame.laser_active_time,
        vertical = spawnInfo.isVertical,
        sound_delay = 0.1,
        sound_played = false
    }
    
    if spawnInfo.isVertical then
        local centerX = spawnInfo.position
        laser.x = centerX - laserGame.laser_warning_thickness/2
        laser.y = 0
        laser.height = laserGame.arena_size
        laser.width = laserGame.laser_warning_thickness
        laser.centerX = centerX
    else
        local centerY = spawnInfo.position
        laser.x = 0
        laser.y = centerY - laserGame.laser_warning_thickness/2
        laser.width = laserGame.arena_size
        laser.height = laserGame.laser_warning_thickness
        laser.centerY = centerY
    end
    
    table.insert(laserGame.lasers, laser)
    
    -- If it's a double laser, spawn the second one
    if spawnInfo.isDouble then
        local laser2 = {
            warning = true,
            warning_timer = laserGame.laser_warning_time,
            active_timer = laserGame.laser_active_time,
            vertical = spawnInfo.isVertical,
            sound_delay = 0.1,
            sound_played = false
        }
        
        if spawnInfo.isVertical then
            local centerX = spawnInfo.secondPosition
            laser2.x = centerX - laserGame.laser_warning_thickness/2
            laser2.y = 0
            laser2.height = laserGame.arena_size
            laser2.width = laserGame.laser_warning_thickness
            laser2.centerX = centerX
        else
            local centerY = spawnInfo.secondPosition
            laser2.x = 0
            laser2.y = centerY - laserGame.laser_warning_thickness/2
            laser2.width = laserGame.arena_size
            laser2.height = laserGame.laser_warning_thickness
            laser2.centerY = centerY
        end
        
        table.insert(laserGame.lasers, laser2)
    end
end

function laserGame.findIntersections()
    -- Check all pairs of active (non-warning) lasers for intersections
    for i = 1, #laserGame.lasers do
        for j = i + 1, #laserGame.lasers do
            local laser1 = laserGame.lasers[i]
            local laser2 = laserGame.lasers[j]
            
            -- Only check intersection if both lasers are active and one is vertical and one is horizontal
            if not laser1.warning and not laser2.warning and laser1.vertical ~= laser2.vertical then
                
                local vertical = laser1.vertical and laser1 or laser2
                local horizontal = laser1.vertical and laser2 or laser1
                
                -- Calculate center points of lasers
                local verticalCenterX = vertical.x + vertical.width/2
                local horizontalCenterY = horizontal.y + horizontal.height/2
                
                -- Calculate intersection point (using center points)
                local intersectX = verticalCenterX
                local intersectY = horizontalCenterY
                
                -- Check if we already have a puddle at this location
                local duplicatePuddle = false
                for _, puddle in ipairs(laserGame.puddles) do
                    local dx = puddle.x - intersectX
                    local dy = puddle.y - intersectY
                    if dx * dx + dy * dy < 4 then -- Small threshold to prevent overlapping puddles
                        duplicatePuddle = true
                        break
                    end
                end
                
                -- If no duplicate, create new puddle
                if not duplicatePuddle then
                    -- Debug visualization of intersection point
                    if _G.debugConsole then
                        _G.debugConsole.addMessage(string.format(
                            "New puddle at %.1f, %.1f (V: %.1f, H: %.1f)", 
                            intersectX, intersectY,
                            verticalCenterX, horizontalCenterY
                        ))
                    end
                    
                    table.insert(laserGame.puddles, {
                        x = intersectX,
                        y = intersectY,
                        time = love.math.random() * math.pi * 2 -- Randomize pulse phase
                    })
                    
                    -- Create particle effect at intersection
                    for i = 1, 16 do
                        local angle = (i / 16) * math.pi * 2
                        laserGame.createParticles(intersectX, intersectY, angle)
                    end
                end
            end
        end
    end
end

function laserGame.spawnEndpointParticles(laser)
    if laser.vertical then
        -- Create particles at top and bottom of vertical laser
        laserGame.createParticles(laser.x, 0, math.pi / 2)  -- Bottom, shooting up
        laserGame.createParticles(laser.x, laserGame.arena_size, -math.pi / 2)  -- Top, shooting down
    else
        -- Create particles at left and right of horizontal laser
        laserGame.createParticles(0, laser.y, 0)  -- Left, shooting right
        laserGame.createParticles(laserGame.arena_size, laser.y, math.pi)  -- Right, shooting left
    end
end

function laserGame.update(dt)
    if laserGame.game_over then 
        laserGame.puddles = {}
        return 
    end
    
    -- Update penalty state
    if laserGame.is_penalized then
        laserGame.penalty_timer = laserGame.penalty_timer - dt
        if laserGame.penalty_timer <= 0 then
            laserGame.is_penalized = false
            debugConsole.addMessage("[Laser] Penalty ended, can score again")
        end
    end
    
    laserGame.timer = laserGame.timer - dt
    if laserGame.timer <= 0 then
        laserGame.timer = 0
        laserGame.game_over = true
        laserGame.puddles = {}
        
        -- Store hit count in players table for round win determination
        if _G.localPlayer and _G.localPlayer.id and _G.players and _G.players[_G.localPlayer.id] then
            _G.players[_G.localPlayer.id].laserHits = laserGame.hitCount
        end
        
        if _G.returnState then
            _G.gameState = _G.returnState
        end
        return
    end
    
    -- Update game time and check for laser spawns
    laserGame.gameTime = laserGame.gameTime + dt
    
    -- Check if we need to spawn any lasers based on pre-calculated spawn points
    while #laserGame.laserSpawnPoints > 0 and laserGame.laserSpawnPoints[1].time <= laserGame.gameTime do
        laserGame.spawnLaser(table.remove(laserGame.laserSpawnPoints, 1))
    end
    
    -- Update score if not penalized
    if not laserGame.is_penalized then
        laserGame.current_round_score = laserGame.current_round_score + (laserGame.points_per_second * dt)
    end
    
    -- Update particles
    laserGame.updateParticles(dt)
    
    -- Update puddle animations
    for _, puddle in ipairs(laserGame.puddles) do
        puddle.time = puddle.time + dt * laserGame.puddle_pulse_speed
    end

    -- Update player movement (always allowed)
    local dx, dy = 0, 0
    if love.keyboard.isDown('a') then dx = dx - 1 end
    if love.keyboard.isDown('d') then dx = dx + 1 end
    if love.keyboard.isDown('w') then dy = dy - 1 end
    if love.keyboard.isDown('s') then dy = dy + 1 end
    
    if dx ~= 0 and dy ~= 0 then
        dx = dx * 0.707
        dy = dy * 0.707
    end
    
    laserGame.player.x = laserGame.player.x + dx * laserGame.player.speed * dt
    laserGame.player.y = laserGame.player.y + dy * laserGame.player.speed * dt
    
    laserGame.player.x = math.max(laserGame.player.radius, 
        math.min(laserGame.arena_size - laserGame.player.radius, laserGame.player.x))
    laserGame.player.y = math.max(laserGame.player.radius, 
        math.min(laserGame.arena_size - laserGame.player.radius, laserGame.player.y))
    
    -- Update lasers
    for i = #laserGame.lasers, 1, -1 do
        local laser = laserGame.lasers[i]
        if laser.warning then
            laser.warning_timer = laser.warning_timer - dt
            if laser.warning_timer <= 0 then
                laser.warning = false
                if laser.vertical then
                    laser.width = laserGame.laser_active_thickness
                    laser.x = laser.centerX - laser.width/2
                else
                    laser.height = laserGame.laser_active_thickness
                    laser.y = laser.centerY - laser.height/2
                end
                laserGame.sounds.laser:clone():play()
                laserGame.spawnEndpointParticles(laser)
                if not laserGame.is_penalized and laserGame.checkLaserCollision(laser) then
                    laserGame.penalizePlayer()
                end
            end
        else
            laserGame.findIntersections()
            
            laser.active_timer = laser.active_timer - dt
            if laser.active_timer <= 0 then
                laserGame.spawnEndpointParticles(laser)
                table.remove(laserGame.lasers, i)
            elseif not laserGame.is_penalized and laserGame.checkLaserCollision(laser) then
                laserGame.penalizePlayer()
            end
        end
    end
    
    -- Check puddle collisions
    if not laserGame.is_penalized then
        for _, puddle in ipairs(laserGame.puddles) do
            if laserGame.checkPuddleCollision(puddle) then
                laserGame.penalizePlayer()
                break
            end
        end
    end
end

function laserGame.draw(playersTable, localPlayerId)
    -- Set background color
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Push graphics state for arena drawing
    love.graphics.push()
    love.graphics.translate(laserGame.arena_offset_x, laserGame.arena_offset_y)
    
    -- Draw arena boundary
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", 0, 0, laserGame.arena_size, laserGame.arena_size)
    
    -- Draw grid lines for visual reference
    love.graphics.setColor(0.2, 0.2, 0.2)
    for i = 0, laserGame.arena_size, 50 do
        love.graphics.line(i, 0, i, laserGame.arena_size)
        love.graphics.line(0, i, laserGame.arena_size, i)
    end
    
    -- Draw puddles
    for _, puddle in ipairs(laserGame.puddles) do
        local pulse = 1 + math.sin(puddle.time) * laserGame.puddle_pulse_amount
        local radius = laserGame.puddle_radius * pulse
        
        love.graphics.setColor(laserGame.puddle_color)
        love.graphics.circle("fill", puddle.x, puddle.y, radius)
        
        love.graphics.setColor(laserGame.puddle_border_color)
        love.graphics.circle("line", puddle.x, puddle.y, radius)
    end
    
    -- Draw lasers
    for _, laser in ipairs(laserGame.lasers) do
        if laser.warning then
            love.graphics.setColor(laserGame.laser_warn_color)
        else
            local alpha = math.min(1, laser.active_timer / (laserGame.laser_active_time * 0.5))
            love.graphics.setColor(laserGame.laser_color[1], 
                                    laserGame.laser_color[2], 
                                    laserGame.laser_color[3], 
                                    laserGame.laser_color[4] * alpha)
        end
        love.graphics.rectangle("fill", laser.x, laser.y, laser.width, laser.height)
    end
    
    -- Draw particles
    for _, particleGroup in ipairs(laserGame.particles) do
        for _, particle in ipairs(particleGroup) do
            love.graphics.setColor(particle.color)
            love.graphics.circle("fill", particle.x, particle.y, particle.size)
        end
    end
    
    -- Draw ghost players
    if playersTable then
        for id, player in pairs(playersTable) do
            if id ~= localPlayerId and player.laserX and player.laserY then
                -- Draw ghost player body
                love.graphics.setColor(player.color[1], player.color[2], player.color[3], 0.5)
                love.graphics.rectangle("fill",
                    player.laserX - laserGame.player_size/2,
                    player.laserY - laserGame.player_size/2,
                    laserGame.player_size,
                    laserGame.player_size
                )
                
                -- Draw their face if available
                if player.facePoints then
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.draw(
                        player.facePoints,
                        player.laserX - laserGame.player_size/2,
                        player.laserY - laserGame.player_size/2,
                        0,
                        laserGame.player_size/100,
                        laserGame.player_size/100
                    )
                end
                
                -- Score display removed
            end
        end
    end
    
    -- Draw local player
    -- If penalized, flash the player red
    if laserGame.is_penalized then
        -- Flash between red and normal color
        if math.floor(laserGame.penalty_timer * 10) % 2 == 0 then
            love.graphics.setColor(1, 0, 0, 0.8)  -- Red flash
        else
            love.graphics.setColor(laserGame.playerColor)
        end
    else
        love.graphics.setColor(laserGame.playerColor)
    end
    
    love.graphics.rectangle("fill",
        laserGame.player.x - laserGame.player_size/2,
        laserGame.player.y - laserGame.player_size/2,
        laserGame.player_size,
        laserGame.player_size
    )
    
    if playersTable and playersTable[localPlayerId] and playersTable[localPlayerId].facePoints then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            playersTable[localPlayerId].facePoints,
            laserGame.player.x - laserGame.player_size/2,
            laserGame.player.y - laserGame.player_size/2,
            0,
            laserGame.player_size/100,
            laserGame.player_size/100
        )
    end
    
    -- Score display removed
    
    -- Pop graphics state
    love.graphics.pop()
    
    -- Draw UI elements with integer scores
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Time: %.1f", laserGame.timer), 
        0, 10, love.graphics.getWidth(), "center")
    
    -- Draw current round score (as integer)
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf(string.format("Round Score: %d", math.floor(laserGame.current_round_score)), 
        0, 40, love.graphics.getWidth(), "center")
    
    -- If penalized, show penalty message
    if laserGame.is_penalized then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf(string.format("HIT! Score Reset (%.1f)", laserGame.penalty_timer),
            0, love.graphics.getHeight()/2 - 30,
            love.graphics.getWidth(), "center")
    end
    
    if laserGame.game_over then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.format("Game Over!\nRound Score: %d", 
            math.floor(laserGame.current_round_score)), 
            0, love.graphics.getHeight()/2 + 30, 
            love.graphics.getWidth(), "center")
    end
end

function laserGame.checkLaserCollision(laser)
    local half_size = laserGame.player_size/2
    local playerLeft = laserGame.player.x - half_size
    local playerRight = laserGame.player.x + half_size
    local playerTop = laserGame.player.y - half_size
    local playerBottom = laserGame.player.y + half_size
    
    if laser.vertical then
        local laserLeft = laser.x
        local laserRight = laser.x + laser.width
        return not (playerRight < laserLeft or playerLeft > laserRight)
    else
        local laserTop = laser.y
        local laserBottom = laser.y + laser.height
        return not (playerBottom < laserTop or playerTop > laserBottom)
    end
end

function laserGame.checkPuddleCollision(puddle)
    local half_size = laserGame.player_size/2
    local dx = math.abs(laserGame.player.x - puddle.x)
    local dy = math.abs(laserGame.player.y - puddle.y)
    return dx < half_size + laserGame.puddle_radius and dy < half_size + laserGame.puddle_radius
end

function laserGame.penalizePlayer()
    if not laserGame.is_penalized then
        laserGame.is_penalized = true
        laserGame.penalty_timer = laserGame.PENALTY_DURATION
        laserGame.current_round_score = 0
        laserGame.hitCount = laserGame.hitCount + 1
        
        -- Play penalty sound
        if laserGame.sounds.death:isPlaying() then
            laserGame.sounds.death:stop()
        end
        laserGame.sounds.death:play()
        
        -- Create particle effect
        for i = 1, 20 do
            local angle = (i / 20) * math.pi * 2
            laserGame.createParticles(
                laserGame.player.x,
                laserGame.player.y,
                angle
            )
        end
        
        debugConsole.addMessage("[Laser] Player hit! Score reset to 0, hits: " .. laserGame.hitCount)
    end
end

function laserGame.reset()
    laserGame.load()  
end

function laserGame.setPlayerColor(color)
    laserGame.playerColor = color
end

function laserGame.keypressed(key)
    -- Add any key press handling here if needed
end

function laserGame.mousepressed(x, y, button)
    -- Add any mouse press handling here if needed
end

return laserGame
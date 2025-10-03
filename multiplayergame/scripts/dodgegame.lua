local dodgeGame = {}
local debugConsole = require "scripts.debugconsole"
local musicHandler = require "scripts.musichandler"

-- Sound effects
dodgeGame.sounds = {
    laser = love.audio.newSource("sounds/laser.mp3", "static")
}

-- Set laser sound volume
dodgeGame.sounds.laser:setVolume(0.2)

-- Game state
dodgeGame.game_over = false
dodgeGame.current_round_score = 0
dodgeGame.playerColor = {1, 1, 1}
dodgeGame.screen_width = _G.BASE_WIDTH
dodgeGame.screen_height = _G.BASE_HEIGHT
dodgeGame.camera_x = 0
dodgeGame.camera_y = 0
dodgeGame.death_count = 0

-- Seed-based synchronization (like laser game)
dodgeGame.seed = 0
dodgeGame.random = love.math.newRandomGenerator()
dodgeGame.gameTime = 0
dodgeGame.laserSpawnPoints = {}

-- Game settings 
dodgeGame.game_started = true
dodgeGame.start_timer = 0 -- No start timer
dodgeGame.timer = 30 -- 30 seconds
dodgeGame.laser_tracking_time = 3.0 -- 2-4 seconds tracking time (randomized)
dodgeGame.laser_duration = 0.25 -- 0.25 second active time (quarter of original)
dodgeGame.laser_width = 24 -- Width of the laser beam (3x indicator width)
dodgeGame.indicator_width = 8 -- Width of the tracking indicator
dodgeGame.indicator_drag_speed = 0.3 -- How fast indicator follows player (0.1 = slow, 1.0 = instant)
dodgeGame.laser_spawn_interval = 3.0 -- Spawn laser every 3 seconds
dodgeGame.next_laser_time = 0

-- Player settings
dodgeGame.player = {
    x = 400,
    y = 300,
    width = 40,
    height = 40,
    speed = 300,
    points = 0,
    is_invincible = false,
    invincibility_timer = 0
}

-- Game objects
dodgeGame.keysPressed = {}
dodgeGame.lasers = {}
dodgeGame.stars = {} -- Moving starfield background
dodgeGame.star_direction = 0 -- Global direction for all stars
dodgeGame.player_dropped = false

-- Laser structure: {x, y, target_player_id, tracking_time, active_time, is_active, is_tracking, target_x, stop_tracking_time}

function dodgeGame.load()
    debugConsole.addMessage("[DodgeGame] Loading dodge laser game")
    debugConsole.addMessage("[DodgeGame] Party mode status: " .. tostring(_G and _G.partyMode or "nil"))
    
    -- Reset game state
    dodgeGame.game_over = false
    dodgeGame.current_round_score = 0
    dodgeGame.death_count = 0
    dodgeGame.game_started = true
    dodgeGame.start_timer = 0
    dodgeGame.timer = 30 -- Reset timer to 30 seconds
    dodgeGame.gameTime = 0
    dodgeGame.next_laser_time = 0
    dodgeGame.lasers = {}
    dodgeGame.player_dropped = false
    
    debugConsole.addMessage("[DodgeGame] Dodge laser game loaded successfully")

    dodgeGame.keysPressed = {}
    
    -- Laser colors now match laser game (static red colors)

    -- Reset player
    dodgeGame.player = {
        x = 400,
        y = 300,
        width = 40,
        height = 40,
        speed = 300,
        points = 0,
        is_invincible = false,
        invincibility_timer = 0
    }
    
    -- Set star direction for this round (top to bottom for space movement effect)
    dodgeGame.star_direction = math.pi / 2  -- 90 degrees (downward)
    
    -- Create game elements
    dodgeGame.createStars()
    dodgeGame.lasers = {}

    debugConsole.addMessage("[DodgeGame] Game loaded")
end

function dodgeGame.setSeed(seed)
    dodgeGame.seed = seed
    dodgeGame.random:setSeed(seed)
    dodgeGame.gameTime = 0
    dodgeGame.laserSpawnPoints = {}
    
    -- Determine when screen-splitter will appear (more frequent)
    local screenSplitterTime = dodgeGame.random:random(5, 15) -- Between 5-15 seconds
    local screenSplitterSpawned = false
    
    -- Pre-calculate laser spawn points with both types
    local time = 0
    while time < dodgeGame.timer do
        local laserType
        
        -- Check if it's time for the screen-splitter (only once per game)
        if not screenSplitterSpawned and time >= screenSplitterTime then
            laserType = "screen_splitter"
            screenSplitterSpawned = true
        else
            -- 50/50 chance between player and random
            local rand = dodgeGame.random:random()
            if rand < 0.5 then
                laserType = "player"
            else
                laserType = "random"
            end
        end
        
        local spawnInfo = {
            time = time,
            type = laserType,
            spawn_x = dodgeGame.random:random(-100, dodgeGame.screen_width + 100), -- Can spawn off-screen
            target_x = dodgeGame.random:random(50, dodgeGame.screen_width - 50) -- Where indicator moves to
        }
        
        if laserType == "screen_splitter" then
            -- Screen-splitter creates multiple lasers in sequence
            spawnInfo.isPaired = false
            spawnInfo.splitter_side = dodgeGame.random:random() < 0.5 and "left" or "right" -- Which side of screen
            spawnInfo.warning_time = 4.0 -- Longer warning time
            
            -- Create multiple spawn points for the screen splitter sequence
            local splitterWidth = dodgeGame.screen_width / 3
            local numLasers = 8 -- Number of lasers in the sequence
            local laserSpacing = splitterWidth / numLasers
            
            for i = 1, numLasers do
                local splitterSpawn = {
                    time = time + (i - 1) * 0.2, -- Stagger each laser by 0.2 seconds
                    type = "screen_splitter",
                    isPaired = false,
                    splitter_side = spawnInfo.splitter_side,
                    warning_time = 4.0,
                    spawn_x = spawnInfo.splitter_side == "left" and (i - 1) * laserSpacing or 
                             (dodgeGame.screen_width * 2/3) + (i - 1) * laserSpacing,
                    target_x = spawnInfo.splitter_side == "left" and 
                             (dodgeGame.screen_width / 2) - (numLasers - i) * laserSpacing or
                             (dodgeGame.screen_width / 2) + (numLasers - i) * laserSpacing,
                    splitter_index = i,
                    splitter_total = numLasers
                }
                table.insert(dodgeGame.laserSpawnPoints, splitterSpawn)
            end
            
            -- Skip the main spawn since we created multiple individual ones
            -- (No need to add spawnInfo to the table)
        elseif laserType == "random" then
            -- Only random lasers get pairs (80% chance)
            local isPaired = dodgeGame.random:random() < 0.8 -- 80% chance of being paired
            spawnInfo.isPaired = isPaired
            
            if isPaired then
                -- Add mirrored spawn info
                spawnInfo.mirror_spawn_x = dodgeGame.screen_width - spawnInfo.spawn_x -- Mirror position
                spawnInfo.mirror_target_x = dodgeGame.screen_width - spawnInfo.target_x -- Mirror target
            end
        else
            spawnInfo.isPaired = false -- Following lasers never get pairs
        end
        
        -- Only add to spawn points if not screen_splitter (already handled above)
        if laserType ~= "screen_splitter" then
            table.insert(dodgeGame.laserSpawnPoints, spawnInfo)
        end
        
        -- Spawn lasers with beat timing, minimum 1.5 seconds between pairs
        if laserType == "screen_splitter" then
            time = time + 2.0 -- Only 2 seconds for screen-splitter (allows other lasers during prep)
        elseif laserType == "random" and spawnInfo.isPaired then
            time = time + math.max(1.5, musicHandler.beatInterval) -- Minimum 1.5 seconds for pairs
        else
            time = time + musicHandler.beatInterval -- Normal beat timing for singles
        end
    end
    
    debugConsole.addMessage(string.format(
        "[DodgeGame] Generated %d laser spawn points with seed %d",
        #dodgeGame.laserSpawnPoints,
        seed
    ))
end

function dodgeGame.update(dt)
    -- Update music effects
    musicHandler.update(dt)
    
    -- Game starts immediately - no start timer needed

    -- Don't return early if game_over - allow respawning
    if dodgeGame.timer <= 0 then
        dodgeGame.timer = 0
        dodgeGame.game_over = true
        return
    end

    dodgeGame.timer = dodgeGame.timer - dt
    dodgeGame.gameTime = dodgeGame.gameTime + dt
    
    -- Handle player movement
    local moveSpeed = dodgeGame.player.speed
    if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
        dodgeGame.player.y = dodgeGame.player.y - moveSpeed * dt
    end
    if love.keyboard.isDown('s') or love.keyboard.isDown('down') then
        dodgeGame.player.y = dodgeGame.player.y + moveSpeed * dt
    end
    if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
        dodgeGame.player.x = dodgeGame.player.x - moveSpeed * dt
    end
    if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
        dodgeGame.player.x = dodgeGame.player.x + moveSpeed * dt
    end

    -- Keep player within screen bounds
    dodgeGame.player.x = math.max(0, math.min(dodgeGame.screen_width - dodgeGame.player.width, dodgeGame.player.x))
    dodgeGame.player.y = math.max(0, math.min(dodgeGame.screen_height - dodgeGame.player.height, dodgeGame.player.y))
    
    -- Handle respawning if player was hit
    if dodgeGame.player_dropped and not dodgeGame.game_over then
        -- Respawn player after a short delay
        if not dodgeGame.respawn_timer then
            dodgeGame.respawn_timer = 1.0 -- 1 second respawn delay
        end
        
        dodgeGame.respawn_timer = dodgeGame.respawn_timer - dt
        if dodgeGame.respawn_timer <= 0 then
            -- Respawn player at random position
            dodgeGame.player.x = dodgeGame.random:random(50, dodgeGame.screen_width - 50)
            dodgeGame.player.y = dodgeGame.random:random(50, dodgeGame.screen_height - 50)
            dodgeGame.player_dropped = false
            dodgeGame.respawn_timer = nil
            debugConsole.addMessage("[DodgeGame] Player respawned!")
        end
    end

    -- Update lasers using deterministic spawning
    dodgeGame.updateLasers(dt)
    
    -- Check laser collisions with player
    dodgeGame.checkLaserCollisions()
    
    -- Update starfield
    dodgeGame.updateStars(dt)
    
    -- Update scoring based on survival time
    dodgeGame.current_round_score = dodgeGame.current_round_score + math.floor(dt * 10)
    
        -- Store death count in players table for round win determination (least deaths wins)
        if _G.localPlayer and _G.localPlayer.id and _G.players and _G.players[_G.localPlayer.id] then
            _G.players[_G.localPlayer.id].dodgeDeaths = dodgeGame.death_count
            _G.players[_G.localPlayer.id].dodgeScore = dodgeGame.current_round_score
        end
        
        -- Send death count to server for winner determination
        if _G.safeSend and _G.server then
            _G.safeSend(_G.server, string.format("dodge_deaths_sync,%d,%d", _G.localPlayer.id, dodgeGame.death_count))
            debugConsole.addMessage("[Dodge] Sent death count to server: " .. dodgeGame.death_count)
        end
end

function dodgeGame.draw(playersTable, localPlayerId)
    -- Clear background
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, dodgeGame.screen_width, dodgeGame.screen_height)
    
    -- Draw starfield background
    dodgeGame.drawStars()
    
    -- Draw lasers
    dodgeGame.drawLasers()
    
    -- Draw other players
    if playersTable then
        for id, player in pairs(playersTable) do
            if id ~= localPlayerId and player.dodgeX and player.dodgeY then
                -- Draw ghost player body
                love.graphics.setColor(player.color[1], player.color[2], player.color[3], 0.5)
                love.graphics.rectangle('fill',
                    player.dodgeX,
                    player.dodgeY,
                    dodgeGame.player.width,
                    dodgeGame.player.height
                )
                
                -- Draw their face if available
                if player.facePoints then
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.draw(
                        player.facePoints,
                        player.dodgeX,
                        player.dodgeY,
                        0,
                        dodgeGame.player.width/100,
                        dodgeGame.player.height/100
                    )
                end
                
                love.graphics.setColor(1, 1, 0, 0.8)
                love.graphics.printf(
                    "Score: " .. math.floor(player.totalScore or 0),
                    player.dodgeX - 50,
                    player.dodgeY - 40,
                    100,
                    "center"
                )
            end
        end
    end
    
    -- Draw local player (only if not eliminated or if respawning)
    if not dodgeGame.player_dropped or (dodgeGame.player_dropped and dodgeGame.respawn_timer) then
        if playersTable and playersTable[localPlayerId] then
            -- Draw invincibility effect if active
            if dodgeGame.player.is_invincible then
                local invincibility_radius = 35
                
                -- Draw outer glow effect
                love.graphics.setColor(1, 1, 0, 0.3)
                love.graphics.circle('fill',
                    dodgeGame.player.x + dodgeGame.player.width/2,
                    dodgeGame.player.y + dodgeGame.player.height/2,
                    invincibility_radius + 5
                )
                
                -- Draw main invincibility bubble
                love.graphics.setColor(1, 1, 0, 0.2)
                love.graphics.circle('fill',
                    dodgeGame.player.x + dodgeGame.player.width/2,
                    dodgeGame.player.y + dodgeGame.player.height/2,
                    invincibility_radius
                )
                
                -- Draw border with pulsing effect
                local pulse = math.sin(love.timer.getTime() * 8) * 0.2 + 0.8
                love.graphics.setColor(1, 1, 0, pulse)
                love.graphics.setLineWidth(2)
                love.graphics.circle('line',
                    dodgeGame.player.x + dodgeGame.player.width/2,
                    dodgeGame.player.y + dodgeGame.player.height/2,
                    invincibility_radius
                )
                love.graphics.setLineWidth(1)
            end
            
            -- Draw player
            love.graphics.setColor(dodgeGame.playerColor)
            love.graphics.rectangle('fill',
                dodgeGame.player.x,
                dodgeGame.player.y,
                dodgeGame.player.width,
                dodgeGame.player.height
            )
            
            -- Draw face
            if playersTable[localPlayerId].facePoints then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    playersTable[localPlayerId].facePoints,
                    dodgeGame.player.x,
                    dodgeGame.player.y,
                    0,
                    dodgeGame.player.width/100,
                    dodgeGame.player.height/100
                )
            end
        end
    end
    
    -- Draw UI elements
    dodgeGame.drawUI(playersTable, localPlayerId)
end

function dodgeGame.drawUI(playersTable, localPlayerId)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Score: ' .. math.floor(dodgeGame.current_round_score), 10, 10)

    love.graphics.printf(string.format("Time: %.1f", dodgeGame.timer), 
        0, 10, love.graphics.getWidth(), "center")
    
    if playersTable and playersTable[localPlayerId] then
        love.graphics.print('Total Score: ' .. 
            math.floor(playersTable[localPlayerId].totalScore or 0), 10, 30)
    end
    
    -- Display invincibility status
    if dodgeGame.player.is_invincible then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print('INVINCIBLE: ' .. string.format("%.1f", dodgeGame.player.invincibility_timer), 10, 50)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- No start timer display needed
    
    if dodgeGame.game_over then
        love.graphics.printf('Game Over - Round Complete!', 
            0, dodgeGame.screen_height / 2 - 50, dodgeGame.screen_width, 'center')
    elseif dodgeGame.player_dropped and dodgeGame.respawn_timer then
        love.graphics.printf('Respawning in ' .. math.ceil(dodgeGame.respawn_timer) .. '...', 
            0, dodgeGame.screen_height / 2 - 50, dodgeGame.screen_width, 'center')
    end
end

function dodgeGame.createStars()
    dodgeGame.stars = {}
    -- Create a moving starfield moving from top to bottom (space movement effect)
    for i = 1, 150 do
        table.insert(dodgeGame.stars, {
            x = math.random(0, dodgeGame.screen_width),
            y = math.random(-dodgeGame.screen_height, dodgeGame.screen_height), -- Start above screen for smooth entry
            size = math.random(1, 3),
            speed = math.random(120, 360) -- 6x faster movement speed (120-360 pixels per second)
        })
    end
end

function dodgeGame.updateStars(dt)
    for i = #dodgeGame.stars, 1, -1 do
        local star = dodgeGame.stars[i]
        
        -- Move star in the global direction
        star.x = star.x + math.cos(dodgeGame.star_direction) * star.speed * dt
        star.y = star.y + math.sin(dodgeGame.star_direction) * star.speed * dt
        
        -- Wrap around screen edges
        if star.x < 0 then
            star.x = dodgeGame.screen_width
        elseif star.x > dodgeGame.screen_width then
            star.x = 0
        end
        
        -- For top-to-bottom movement, wrap stars from bottom to top
        if star.y > dodgeGame.screen_height then
            star.y = -20 -- Start slightly above screen for smooth entry
        elseif star.y < -20 then
            star.y = dodgeGame.screen_height + 20 -- Keep moving if above screen
        end
    end
end

function dodgeGame.drawStars()
    for _, star in ipairs(dodgeGame.stars) do
        love.graphics.setColor(1, 1, 1, 0.8) -- Uniform white color with slight transparency
        love.graphics.circle('fill', star.x, star.y, star.size)
    end
end

function dodgeGame.updateLasers(dt)
    -- Check if we need to spawn any lasers based on pre-calculated spawn points
    while #dodgeGame.laserSpawnPoints > 0 and dodgeGame.laserSpawnPoints[1].time <= dodgeGame.gameTime do
        dodgeGame.spawnLaserFromSpawnPoint(table.remove(dodgeGame.laserSpawnPoints, 1))
    end
    
    -- Update existing lasers
    for i = #dodgeGame.lasers, 1, -1 do
        local laser = dodgeGame.lasers[i]
        
        if laser.is_tracking then
            laser.tracking_time = laser.tracking_time - dt
            
            if laser.is_player_tracking then
                -- Player-following laser behavior - move directly to player (no back and forth)
                local targetX = 0
                
                -- Get target position
                if laser.target_player_id == (_G.localPlayer and _G.localPlayer.id or 0) then
                    targetX = dodgeGame.player.x + dodgeGame.player.width / 2
                else
                    if _G.players and _G.players[laser.target_player_id] and _G.players[laser.target_player_id].dodgeX then
                        targetX = _G.players[laser.target_player_id].dodgeX + dodgeGame.player.width / 2
                    end
                end
                
                -- Move directly towards player position
                local distance = targetX - laser.x
                laser.x = laser.x + distance * dodgeGame.indicator_drag_speed * dt * 10
            else
                -- Random position laser behavior - move to target position
                if laser.tracking_time > laser.stop_tracking_time and laser.target_x then
                    -- Move indicator towards target position
                    local distance = laser.target_x - laser.x
                    laser.x = laser.x + distance * dodgeGame.indicator_drag_speed * dt * 10
                end
            end
            
            -- Transition from tracking to active
            if laser.tracking_time <= 0 then
                laser.is_tracking = false
                laser.is_active = true
                -- Play laser sound effect
                dodgeGame.sounds.laser:clone():play()
            end
        elseif laser.is_active then
            laser.active_time = laser.active_time - dt
            
            -- Remove laser after it's been active
            if laser.active_time <= 0 then
                table.remove(dodgeGame.lasers, i)
            end
        end
    end
end

function dodgeGame.spawnLaserFromSpawnPoint(spawnInfo)
    -- Spawn first laser
    local laser = {}
    
    if spawnInfo.type == "player" then
        -- Player-following laser - spawn from off-screen
        laser.x = spawnInfo.spawn_x -- Start at spawn position (can be off-screen)
        laser.y = dodgeGame.screen_height -- Start at bottom of screen
        laser.target_player_id = 0 -- Default to local player
        laser.tracking_time = dodgeGame.random:random(2, 4) -- 2-4 seconds tracking
        laser.stop_tracking_time = 0 -- No stop tracking - move directly to player
        laser.is_player_tracking = true
        laser.is_screen_splitter = false
    elseif spawnInfo.type == "screen_splitter" then
        -- Screen-splitter laser - spawns multiple lasers in sequence moving to center
        laser.x = spawnInfo.spawn_x -- Start at spawn position
        laser.y = dodgeGame.screen_height -- Start at bottom of screen
        laser.target_x = spawnInfo.target_x -- Target center of screen
        laser.tracking_time = spawnInfo.warning_time -- 4 seconds warning
        laser.stop_tracking_time = 1.0 -- Stop moving 1 second before firing
        laser.is_player_tracking = false
        laser.is_screen_splitter = true
        laser.splitter_side = spawnInfo.splitter_side
        laser.splitter_index = spawnInfo.splitter_index -- Which laser in the sequence
        laser.splitter_total = spawnInfo.splitter_total -- Total lasers in sequence
    else
        -- Random position laser with moving indicator
        laser.x = spawnInfo.spawn_x -- Start at spawn position
        laser.y = dodgeGame.screen_height -- Start at bottom of screen
        laser.target_x = spawnInfo.target_x -- Target position to move to
        laser.tracking_time = dodgeGame.random:random(2, 4) -- 2-4 seconds to move and fire
        laser.stop_tracking_time = 1.0 -- Stop moving 1 second before firing
        laser.is_player_tracking = false
        laser.is_screen_splitter = false
    end
    
    laser.active_time = dodgeGame.laser_duration -- 0.25 second active
    laser.is_active = false
    laser.is_tracking = true
    
    table.insert(dodgeGame.lasers, laser)
    
    -- Spawn mirrored laser if paired (only for random lasers)
    if spawnInfo.isPaired and spawnInfo.type == "random" then
        local mirrorLaser = {}
        
        -- Random position mirror laser
        mirrorLaser.x = spawnInfo.mirror_spawn_x -- Start at mirror spawn position
        mirrorLaser.y = dodgeGame.screen_height -- Start at bottom of screen
        mirrorLaser.target_x = spawnInfo.mirror_target_x -- Mirror target position
        mirrorLaser.tracking_time = laser.tracking_time -- Same timing as first laser
        mirrorLaser.stop_tracking_time = 1.0 -- Stop moving 1 second before firing
        mirrorLaser.is_player_tracking = false
        mirrorLaser.is_screen_splitter = false
        
        mirrorLaser.active_time = dodgeGame.laser_duration -- 0.25 second active
        mirrorLaser.is_active = false
        mirrorLaser.is_tracking = true
        
        table.insert(dodgeGame.lasers, mirrorLaser)
    end
end

function dodgeGame.drawLasers()
    for _, laser in ipairs(dodgeGame.lasers) do
        if laser.is_tracking then
            -- Draw tracking indicator (matches laser game warning color)
            love.graphics.setColor(1, 0, 0, 0.3) -- Same as laser game warning
            love.graphics.setLineWidth(dodgeGame.indicator_width)
            love.graphics.line(laser.x, dodgeGame.screen_height, laser.x, 0)
            love.graphics.setLineWidth(1)
        elseif laser.is_active then
            -- Draw active laser (matches laser game active color)
            love.graphics.setColor(1, 0, 0, 0.8) -- Same as laser game active
            love.graphics.setLineWidth(dodgeGame.laser_width)
            love.graphics.line(laser.x, dodgeGame.screen_height, laser.x, 0)
            love.graphics.setLineWidth(1)
        end
    end
end

function dodgeGame.checkLaserCollisions()
    for _, laser in ipairs(dodgeGame.lasers) do
        if laser.is_active then -- Only active lasers can hit
            -- Check collision with laser (vertical laser only)
            if dodgeGame.player.x < laser.x + dodgeGame.laser_width/2 and
               dodgeGame.player.x + dodgeGame.player.width > laser.x - dodgeGame.laser_width/2 then
                if not dodgeGame.player.is_invincible then
                    dodgeGame.player_dropped = true
                    dodgeGame.death_count = dodgeGame.death_count + 1 -- Increment death count
                    if laser.is_screen_splitter then
                        debugConsole.addMessage("[DodgeGame] Player hit by screen-splitter! Death count: " .. dodgeGame.death_count)
                    else
                        debugConsole.addMessage("[DodgeGame] Player hit by laser! Death count: " .. dodgeGame.death_count)
                    end
                end
            end
        end
    end
end

function dodgeGame.keypressed(key)
    print("[DodgeGame] Key pressed: " .. key)
    debugConsole.addMessage("[DodgeGame] Key pressed: " .. key)
end

function dodgeGame.mousepressed(x, y, button)
    -- No mouse input needed
end

function dodgeGame.keyreleased(key)
    dodgeGame.keysPressed[key] = false
end

function dodgeGame.reset()
    dodgeGame.load()
end

function dodgeGame.setPlayerColor(color)
    dodgeGame.playerColor = color
end

return dodgeGame

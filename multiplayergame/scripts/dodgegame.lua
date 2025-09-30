local dodgeGame = {}
local debugConsole = require "scripts.debugconsole"
local musicHandler = require "scripts.musichandler"

-- Game state
dodgeGame.game_over = false
dodgeGame.current_round_score = 0
dodgeGame.playerColor = {1, 1, 1}
dodgeGame.screen_width = 800
dodgeGame.screen_height = 600
dodgeGame.camera_x = 0
dodgeGame.camera_y = 0

-- Seed-based synchronization (like laser game)
dodgeGame.seed = 0
dodgeGame.random = love.math.newRandomGenerator()
dodgeGame.gameTime = 0
dodgeGame.laserSpawnPoints = {}

-- Game settings 
dodgeGame.game_started = false
dodgeGame.start_timer = 1 -- Reduced from 3 to 1 second
dodgeGame.timer = 30 -- 30 seconds
dodgeGame.laser_tracking_time = 3.0 -- 2-4 seconds tracking time (randomized)
dodgeGame.laser_duration = 1.0 -- 1 second active time
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
    dodgeGame.game_started = false
    dodgeGame.start_timer = 3
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
    
    -- Pre-calculate laser spawn points
    local time = 0
    while time < dodgeGame.timer do
        local spawnInfo = {
            time = time,
            target_player_id = 0, -- Will be set to random player when spawning
            x = 0 -- Will be set to target player's x position when spawning
        }
        table.insert(dodgeGame.laserSpawnPoints, spawnInfo)
        
        -- Spawn lasers every 3-5 seconds
        time = time + dodgeGame.random:random(3, 5)
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
    
    if not dodgeGame.game_started then
        dodgeGame.start_timer = math.max(0, dodgeGame.start_timer - dt)
        dodgeGame.game_started = dodgeGame.start_timer == 0
        return
    end

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
    
    -- Store score in players table for round win determination
    if _G.localPlayer and _G.localPlayer.id and _G.players and _G.players[_G.localPlayer.id] then
        _G.players[_G.localPlayer.id].dodgeScore = dodgeGame.current_round_score
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
    
    if not dodgeGame.game_started then
        love.graphics.printf('Get Ready: ' .. math.ceil(dodgeGame.start_timer), 
            0, dodgeGame.screen_height / 2 - 50, dodgeGame.screen_width, 'center')
    end
    
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
            speed = math.random(60, 180) -- 3x faster movement speed (60-180 pixels per second)
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
            
            -- Only follow player if we haven't reached the stop tracking time
            if laser.tracking_time > laser.stop_tracking_time then
                local targetX = 0
                
                -- Get target position
                if laser.target_player_id == (_G.localPlayer and _G.localPlayer.id or 0) then
                    targetX = dodgeGame.player.x + dodgeGame.player.width / 2
                else
                    if _G.players and _G.players[laser.target_player_id] and _G.players[laser.target_player_id].dodgeX then
                        targetX = _G.players[laser.target_player_id].dodgeX + dodgeGame.player.width / 2
                    end
                end
                
                -- Apply drag effect - indicator follows with delay
                local distance = targetX - laser.x
                laser.x = laser.x + distance * dodgeGame.indicator_drag_speed * dt * 10
            end
            
            -- Transition from tracking to active
            if laser.tracking_time <= 0 then
                laser.is_tracking = false
                laser.is_active = true
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
    local laser = {}
    
    -- Select random target player (including local player)
    local targetPlayerId = 0 -- Default to local player
    if _G.players and _G.localPlayer then
        local playerIds = {}
        -- Add local player
        table.insert(playerIds, _G.localPlayer.id or 0)
        -- Add other players
        for id, _ in pairs(_G.players) do
            if id ~= (_G.localPlayer.id or 0) then
                table.insert(playerIds, id)
            end
        end
        
        if #playerIds > 0 then
            targetPlayerId = playerIds[dodgeGame.random:random(1, #playerIds)]
        end
    end
    
    -- Set initial position based on target
    if targetPlayerId == (_G.localPlayer and _G.localPlayer.id or 0) then
        laser.x = dodgeGame.player.x + dodgeGame.player.width / 2
    else
        -- Start at center, will be updated during tracking
        laser.x = dodgeGame.screen_width / 2
    end
    laser.y = 0 -- Start at top of screen
    laser.target_player_id = targetPlayerId
    laser.tracking_time = dodgeGame.random:random(2, 4) -- 2-4 seconds tracking
    laser.stop_tracking_time = 1.0 -- Stop tracking 1 second before firing
    laser.active_time = dodgeGame.laser_duration -- 1 second active
    laser.is_active = false
    laser.is_tracking = true
    
    table.insert(dodgeGame.lasers, laser)
end

function dodgeGame.drawLasers()
    for _, laser in ipairs(dodgeGame.lasers) do
        if laser.is_tracking then
            -- Draw tracking indicator (red line that follows player - matches laser game)
            love.graphics.setColor(1, 0, 0, 0.3)
            love.graphics.setLineWidth(dodgeGame.indicator_width)
            love.graphics.line(laser.x, 0, laser.x, dodgeGame.screen_height)
            love.graphics.setLineWidth(1)
            
            -- Draw target indicator at the bottom
            love.graphics.setColor(1, 0, 0, 0.8)
            love.graphics.circle('fill', laser.x, dodgeGame.screen_height - 20, 8)
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.circle('line', laser.x, dodgeGame.screen_height - 20, 8)
        elseif laser.is_active then
            -- Draw active laser (red vertical line - matches laser game)
            love.graphics.setColor(1, 0, 0, 0.8)
            love.graphics.setLineWidth(dodgeGame.laser_width)
            love.graphics.line(laser.x, 0, laser.x, dodgeGame.screen_height)
            love.graphics.setLineWidth(1)
        end
    end
end

function dodgeGame.checkLaserCollisions()
    for _, laser in ipairs(dodgeGame.lasers) do
        if laser.is_active then -- Only active lasers can hit
            -- Check collision with player (vertical laser only)
            if dodgeGame.player.x < laser.x + dodgeGame.laser_width/2 and
               dodgeGame.player.x + dodgeGame.player.width > laser.x - dodgeGame.laser_width/2 then
                if not dodgeGame.player.is_invincible then
                    dodgeGame.player_dropped = true
                    debugConsole.addMessage("[DodgeGame] Player hit by laser!")
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

local battleRoyale = {}
local debugConsole = require "scripts.debugconsole"
local musicHandler = require "scripts.musichandler"

-- Game state
battleRoyale.game_over = false
battleRoyale.current_round_score = 0
battleRoyale.playerColor = {1, 1, 1}
battleRoyale.screen_width = 800
battleRoyale.screen_height = 600
battleRoyale.camera_x = 0
battleRoyale.camera_y = 0

-- Seed-based synchronization (like laser game)
battleRoyale.seed = 0
battleRoyale.random = love.math.newRandomGenerator()
battleRoyale.gameTime = 0
battleRoyale.nextMeteoroidTime = 0
battleRoyale.meteoroidSpawnPoints = {}
battleRoyale.safeZoneTargets = {}

-- Game settings 
battleRoyale.gravity = 1000
battleRoyale.game_started = false
battleRoyale.start_timer = 3
battleRoyale.shrink_timer = 15
battleRoyale.shrink_interval = 2
battleRoyale.shrink_padding_x = 0
battleRoyale.shrink_padding_y = 0
battleRoyale.max_shrink_padding_x = 300
battleRoyale.max_shrink_padding_y = 200
-- Use safe timer calculation with fallback for party mode
local beatInterval = musicHandler.beatInterval or 2.0 -- Fallback to 2 seconds if not set
battleRoyale.timer = beatInterval * 20 -- 40 seconds
battleRoyale.safe_zone_radius = 450
battleRoyale.center_x = 400
battleRoyale.center_y = 300
battleRoyale.death_timer = 0
battleRoyale.death_shake = 0
battleRoyale.player_dropped = false
battleRoyale.death_animation_done = false
battleRoyale.shrink_duration = 20 -- 20 seconds of shrinking (faster)
battleRoyale.shrink_start_time = 0 -- When shrinking actually starts
battleRoyale.safe_zone_move_speed = 60 -- pixels per second (faster movement)
battleRoyale.safe_zone_move_timer = 0
battleRoyale.safe_zone_target_x = 400
battleRoyale.safe_zone_target_y = 300
battleRoyale.sync_timer = 0
battleRoyale.sync_interval = 1.0 -- Send sync every 1 second
battleRoyale.respawn_timer = 0 -- Timer for respawn mechanism
battleRoyale.respawn_delay = 3 -- 3 seconds before respawn
battleRoyale.grow_timer = 0 -- Timer for random growth periods
battleRoyale.grow_duration = 0 -- Current growth duration (0 = not growing)
battleRoyale.is_growing = false -- Whether currently in growth phase

-- Player settings
battleRoyale.player = {
    x = 400,
    y = 300,
    width = 40,
    height = 40,
    speed = 250,
    normal_speed = 250,
    points = 0,
    is_invincible = false,
    invincibility_timer = 0
}

-- Sounds removed - no power-ups in this version

-- Game objects
battleRoyale.keysPressed = {}
battleRoyale.safe_zone_alpha = 0.3
battleRoyale.asteroids = {}
battleRoyale.asteroid_spawn_timer = 0
battleRoyale.asteroid_spawn_interval = 1.0 -- More frequent asteroid spawning
battleRoyale.asteroid_speed = 600 -- Pixels per second (much faster)
battleRoyale.stars = {} -- Moving starfield background
battleRoyale.star_direction = 0 -- Global direction for all stars

function battleRoyale.load()
    debugConsole.addMessage("[BattleRoyale] Loading battle royale game")
    debugConsole.addMessage("[BattleRoyale] Party mode status: " .. tostring(_G and _G.partyMode or "nil"))
    -- Reset game state
    battleRoyale.game_over = false
    battleRoyale.current_round_score = 0
    battleRoyale.death_timer = 0
    battleRoyale.death_shake = 0
    battleRoyale.player_dropped = false
    battleRoyale.death_animation_done = false
    battleRoyale.game_started = false
    battleRoyale.start_timer = 3
    battleRoyale.shrink_start_time = 0
    battleRoyale.shrink_padding_x = 0
    battleRoyale.shrink_padding_y = 0
    battleRoyale.safe_zone_radius = 450
    battleRoyale.player.drop_cooldown = 0
    battleRoyale.player.dropping = false
    battleRoyale.player.jump_count = 0
    battleRoyale.player.has_double_jumped = false
    battleRoyale.player.on_ground = false
    -- Use safe timer calculation with fallback for party mode
    local beatInterval = musicHandler.beatInterval or 2.0 -- Fallback to 2 seconds if not set
    battleRoyale.timer = beatInterval * 20 -- 40 seconds
    battleRoyale.gameTime = 0
    debugConsole.addMessage("[BattleRoyale] Battle royale loaded successfully")

    battleRoyale.keysPressed = {}
    
    -- Add rhythmic effects for meteoroids and safety circle
    musicHandler.addEffect("meteoroid_spawn", "beatPulse", {
        baseColor = {1, 1, 1},
        intensity = 0.5,
        duration = 0.1
    })
    
    musicHandler.addEffect("safety_circle_rotate", "combo", {
        scaleAmount = 0,
        rotateAmount = math.pi/4,  -- Rotate 45 degrees per beat (faster)
        frequency = 2,             -- Twice per beat for more speed
        phase = 0,
        snapDuration = 0.1
    })

    -- Reset player
    battleRoyale.player = {
        x = 400,
        y = 300,
        width = 40,
        height = 40,
        speed = 250,
        normal_speed = 250,
        points = 0,
        is_invincible = false,
        invincibility_timer = 0
    }
    
    -- Reset respawn timer and growth timers
    battleRoyale.respawn_timer = 0
    battleRoyale.grow_timer = 0
    battleRoyale.grow_duration = 0
    battleRoyale.is_growing = false
    
    -- In party mode, ensure player starts in center of safe zone
    debugConsole.addMessage("[BattleRoyale] Checking party mode: " .. tostring(_G and _G.partyMode or "nil") .. " (type: " .. type(_G and _G.partyMode) .. ")")
    if _G and _G.partyMode == true then
        battleRoyale.player.x = 400
        battleRoyale.player.y = 300
        battleRoyale.center_x = 400
        battleRoyale.center_y = 300
        battleRoyale.safe_zone_radius = 450
        
        -- Debug music handler state
        debugConsole.addMessage("[PartyMode] Player positioned in center of safe zone")
    else
        debugConsole.addMessage("[BattleRoyale] Party mode not detected, using normal initialization")
    end
    
    -- No spacebar functionality needed without power-ups

    -- Reset safe zone to center
    battleRoyale.center_x = 400
    battleRoyale.center_y = 300
    battleRoyale.safe_zone_radius = 450
    
    -- Set star direction for this round
    battleRoyale.star_direction = math.random(0, 2 * math.pi)
    
    -- Create game elements
    battleRoyale.createStars()
    battleRoyale.asteroids = {}
    battleRoyale.asteroid_spawn_timer = 0

    debugConsole.addMessage("[BattleRoyale] Game loaded")
end

function battleRoyale.setSeed(seed)
    battleRoyale.seed = seed
    battleRoyale.random:setSeed(seed)
    battleRoyale.gameTime = 0
    battleRoyale.nextMeteoroidTime = 0
    battleRoyale.meteoroidSpawnPoints = {}
    battleRoyale.safeZoneTargets = {}
    
    -- Pre-calculate meteoroid spawn points (like laser game)
    local time = 0
    while time < battleRoyale.timer do
        local spawnInfo = {
            time = time,
            side = battleRoyale.random:random(1, 4), -- 1=top, 2=right, 3=bottom, 4=left
            speed = battleRoyale.random:random(400, 800),
            size = battleRoyale.random:random(25, 45)
        }
        table.insert(battleRoyale.meteoroidSpawnPoints, spawnInfo)
        
        -- Spawn meteoroids more frequently (every 0.5-1.5 seconds)
        time = time + battleRoyale.random:random(0.5, 1.5)
    end
    
    -- No power-ups in this version
    
    -- Pre-calculate safe zone target positions
    time = 0
    while time < battleRoyale.timer do
        local margin = math.max(50, battleRoyale.safe_zone_radius + 50)
        local targetInfo = {
            time = time,
            x = battleRoyale.random:random(margin, battleRoyale.screen_width - margin),
            y = battleRoyale.random:random(margin, battleRoyale.screen_height - margin)
        }
        table.insert(battleRoyale.safeZoneTargets, targetInfo)
        
        -- Change target every 2 seconds
        time = time + 2.0
    end
    
    debugConsole.addMessage(string.format(
        "[BattleRoyale] Generated %d meteoroid and %d safe zone targets with seed %d",
        #battleRoyale.meteoroidSpawnPoints,
        #battleRoyale.safeZoneTargets,
        seed
    ))
end

-- Power-ups removed from this version

function battleRoyale.update(dt)
    -- Update music effects
    musicHandler.update(dt)
    
    if not battleRoyale.game_started then
        battleRoyale.start_timer = math.max(0, battleRoyale.start_timer - dt)
        battleRoyale.game_started = battleRoyale.start_timer == 0
        
        -- In party mode, give extra time for players to get into safe zone
        if _G and _G.partyMode == true and battleRoyale.game_started then
            -- Reset safe zone to full size when game starts in party mode
            battleRoyale.safe_zone_radius = 450
            battleRoyale.center_x = 400
            battleRoyale.center_y = 300
            debugConsole.addMessage("[PartyMode] Game started - reset safe zone to full size")
            
            -- No elimination system - players respawn instead of being eliminated
        end
        
        return
    end

    if battleRoyale.game_over then return end

    battleRoyale.timer = battleRoyale.timer - dt
    battleRoyale.gameTime = battleRoyale.gameTime + dt
    
    if battleRoyale.timer <= 0 then
        battleRoyale.timer = 0
        battleRoyale.game_over = true
        
        -- No elimination system - players just continue until timer runs out
        
        -- Party mode transition is handled by main.lua
        return
    end
    
    -- No elimination system - game only ends when timer runs out

    -- Update safe zone movement using pre-calculated targets
    if #battleRoyale.safeZoneTargets > 0 and battleRoyale.safeZoneTargets[1].time <= battleRoyale.gameTime then
        local target = table.remove(battleRoyale.safeZoneTargets, 1)
        battleRoyale.safe_zone_target_x = target.x
        battleRoyale.safe_zone_target_y = target.y
        debugConsole.addMessage("[SafeZone] New target: " .. battleRoyale.safe_zone_target_x .. "," .. battleRoyale.safe_zone_target_y)
    end
    
    -- Party mode uses same safe zone logic as standalone (no music handler dependency)
    
    -- Move safe zone towards target
    local dx = battleRoyale.safe_zone_target_x - battleRoyale.center_x
    local dy = battleRoyale.safe_zone_target_y - battleRoyale.center_y
    local distance = math.sqrt(dx*dx + dy*dy)
    if distance > 5 then
        local move_x = (dx / distance) * battleRoyale.safe_zone_move_speed * dt
        local move_y = (dy / distance) * battleRoyale.safe_zone_move_speed * dt
        battleRoyale.center_x = battleRoyale.center_x + move_x
        battleRoyale.center_y = battleRoyale.center_y + move_y
    end

    -- Update shrinking safe zone with random growth periods (deterministic)
    if true then -- Shrinking always happens now
        -- Start shrinking immediately when game starts
        if battleRoyale.shrink_start_time == 0 and battleRoyale.game_started then
            battleRoyale.shrink_start_time = battleRoyale.gameTime
            debugConsole.addMessage("[BattleRoyale] Safe zone shrinking started!")
        end
        
        -- Start shrinking immediately after game starts
        if battleRoyale.shrink_start_time > 0 then
            local elapsed_shrink_time = battleRoyale.gameTime - battleRoyale.shrink_start_time
            
            -- Check for random growth periods (increases over time) - deterministic
            if not battleRoyale.is_growing and battleRoyale.grow_timer <= 0 and elapsed_shrink_time > 2 then
                -- Growth chance increases over time: 25% early game, 40% mid game, 60% late game (higher for testing)
                local growth_chance = 0.25
                if elapsed_shrink_time > 8 then
                    growth_chance = 0.40 -- Mid game
                end
                if elapsed_shrink_time > 12 then
                    growth_chance = 0.60 -- Late game
                end
                
                -- Use deterministic random based on game time for synchronization
                local time_seed = math.floor(battleRoyale.gameTime * 10) -- Check every 0.1 seconds
                battleRoyale.random:setSeed(battleRoyale.seed + time_seed)
                local random_value = battleRoyale.random:random(0, 100)
                local threshold = growth_chance * 100
                
                
                if random_value < threshold then
                    battleRoyale.is_growing = true
                    -- Growth duration increases over time: 2-3 early, 3-5 mid, 4-6 late
                    local min_growth = 2
                    local max_growth = 3
                    if elapsed_shrink_time > 8 then
                        min_growth = 3
                        max_growth = 5
                    end
                    if elapsed_shrink_time > 12 then
                        min_growth = 4
                        max_growth = 6
                    end
                    
                    battleRoyale.grow_duration = battleRoyale.random:random(min_growth, max_growth)
                    battleRoyale.grow_timer = battleRoyale.grow_duration
                end
                -- Restore original seed
                battleRoyale.random:setSeed(battleRoyale.seed)
            end
            
            -- Handle growth period
            if battleRoyale.is_growing then
                battleRoyale.grow_timer = battleRoyale.grow_timer - dt
                if battleRoyale.grow_timer <= 0 then
                    battleRoyale.is_growing = false
                    battleRoyale.grow_duration = 0
                end
            else
                -- Reset growth timer for next chance (faster checking in late game)
                battleRoyale.grow_timer = battleRoyale.grow_timer - dt
                if battleRoyale.grow_timer <= 0 then
                    -- Check more frequently as game progresses
                    if elapsed_shrink_time > 15 then
                        battleRoyale.grow_timer = 1 -- Check every 1 second in late game
                    else
                        battleRoyale.grow_timer = 1.5 -- Check every 1.5 seconds in mid game
                    end
                end
            end
            
            -- Only shrink if we haven't exceeded the shrink duration and not currently growing
            if elapsed_shrink_time <= battleRoyale.shrink_duration and not battleRoyale.is_growing then
                -- Calculate shrink rate: 350 pixels over 20 seconds = 17.5 pixels per second (from 450 to 100)
                local shrink_rate = 350 / battleRoyale.shrink_duration
                battleRoyale.safe_zone_radius = battleRoyale.safe_zone_radius - (dt * shrink_rate)
            elseif battleRoyale.is_growing then
                -- Grow during growth periods (larger growth in late game)
                local grow_rate = 40 -- Base 40 pixels per second growth
                if elapsed_shrink_time > 10 then
                    grow_rate = 50 -- 50 pixels per second in mid game
                end
                if elapsed_shrink_time > 15 then
                    grow_rate = 60 -- 60 pixels per second in late game
                end
                battleRoyale.safe_zone_radius = battleRoyale.safe_zone_radius + (dt * grow_rate)
            end
        end
    end
    battleRoyale.safe_zone_radius = math.max(100, battleRoyale.safe_zone_radius) -- Minimum radius of 100 (stops at 100)

    -- Handle top-down movement (only if not eliminated)
    if not battleRoyale.player_dropped then
        local moveSpeed = battleRoyale.player.speed
        if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
            battleRoyale.player.y = battleRoyale.player.y - moveSpeed * dt
        end
        if love.keyboard.isDown('s') or love.keyboard.isDown('down') then
            battleRoyale.player.y = battleRoyale.player.y + moveSpeed * dt
        end
        if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
            battleRoyale.player.x = battleRoyale.player.x - moveSpeed * dt
        end
        if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
            battleRoyale.player.x = battleRoyale.player.x + moveSpeed * dt
        end
    end

    -- Keep player within screen bounds
    battleRoyale.player.x = math.max(0, math.min(battleRoyale.screen_width - battleRoyale.player.width, battleRoyale.player.x))
    battleRoyale.player.y = math.max(0, math.min(battleRoyale.screen_height - battleRoyale.player.height, battleRoyale.player.y))

    -- Update laser angle based on mouse position
    local mx, my = love.mouse.getPosition()
    battleRoyale.player.laser_angle = math.atan2(my - battleRoyale.player.y - battleRoyale.player.height/2, 
                                                mx - battleRoyale.player.x - battleRoyale.player.width/2)

    -- Check if player is outside safe zone (only after game has started)
    if battleRoyale.game_started then
        -- Use deterministic safe zone data (same on all clients)
        local center_x, center_y, radius = battleRoyale.center_x, battleRoyale.center_y, battleRoyale.safe_zone_radius
        
        local distance_from_center = math.sqrt(
            (battleRoyale.player.x + battleRoyale.player.width/2 - center_x)^2 +
            (battleRoyale.player.y + battleRoyale.player.height/2 - center_y)^2
        )
        
        -- Debug output for party mode
        if _G.partyMode == true then
            debugConsole.addMessage(string.format("[PartyMode] Player at (%.1f,%.1f), center at (%.1f,%.1f), radius=%.1f, distance=%.1f", 
                battleRoyale.player.x, battleRoyale.player.y, center_x, center_y, radius, distance_from_center))
        end
        
        if distance_from_center > radius and not battleRoyale.player.is_invincible and not battleRoyale.player_dropped then
            battleRoyale.player_dropped = true
            battleRoyale.death_timer = 2 -- 2 second death animation
            battleRoyale.death_shake = 15 -- Shake intensity
            battleRoyale.respawn_timer = battleRoyale.respawn_delay -- Start respawn timer
            debugConsole.addMessage("[BattleRoyale] Player died outside safe zone! Respawning in " .. battleRoyale.respawn_delay .. " seconds...")
        end
    end

    -- Handle respawn mechanism
    if battleRoyale.player_dropped and battleRoyale.respawn_timer > 0 then
        battleRoyale.respawn_timer = battleRoyale.respawn_timer - dt
        if battleRoyale.respawn_timer <= 0 then
            -- Respawn player in center of safe zone
            battleRoyale.player.x = battleRoyale.center_x - battleRoyale.player.width/2
            battleRoyale.player.y = battleRoyale.center_y - battleRoyale.player.height/2
            battleRoyale.player_dropped = false
            battleRoyale.death_timer = 0
            battleRoyale.death_shake = 0
            battleRoyale.player.is_invincible = true
            battleRoyale.player.invincibility_timer = 2 -- 2 seconds of invincibility after respawn
            debugConsole.addMessage("[BattleRoyale] Player respawned in center of safe zone!")
        end
    end

    -- Update invincibility timer
    if battleRoyale.player.is_invincible then
        battleRoyale.player.invincibility_timer = battleRoyale.player.invincibility_timer - dt
        if battleRoyale.player.invincibility_timer <= 0 then
            battleRoyale.player.is_invincible = false
        end
    end

    -- Update asteroids using deterministic spawning (like laser game)
    battleRoyale.updateAsteroids(dt)
    
    -- Check asteroid collisions with player
    battleRoyale.checkAsteroidCollisions()
    
    
    -- Update starfield
    battleRoyale.updateStars(dt)
    
    -- Send periodic synchronization to keep clients in sync
    battleRoyale.sync_timer = battleRoyale.sync_timer + dt
    if battleRoyale.sync_timer >= battleRoyale.sync_interval then
        battleRoyale.sync_timer = 0
        battleRoyale.sendGameStateSync()
    end

    -- Update death timer and shake
    if battleRoyale.death_timer > 0 then
        battleRoyale.death_timer = battleRoyale.death_timer - dt
        battleRoyale.death_shake = battleRoyale.death_shake * 0.85 -- Decay shake
        if battleRoyale.death_timer <= 0 then
            battleRoyale.death_timer = 0
            battleRoyale.death_shake = 0
            battleRoyale.death_animation_done = true
            -- Don't end game immediately - wait for all players to be eliminated or timer to run out
        end
    end

    -- Update scoring based on survival time
    battleRoyale.current_round_score = battleRoyale.current_round_score + math.floor(dt * 10)
    
    -- Store score in players table for round win determination
    if _G.localPlayer and _G.localPlayer.id and _G.players and _G.players[_G.localPlayer.id] then
        _G.players[_G.localPlayer.id].battleScore = battleRoyale.current_round_score
    end
    
    -- Handle spacebar input using isDown (like jump game)
    battleRoyale.handleSpacebar()
end

function battleRoyale.draw(playersTable, localPlayerId)
    -- Apply death shake effect
    if battleRoyale.death_shake > 0 then
        local shake_x = math.random(-battleRoyale.death_shake, battleRoyale.death_shake)
        local shake_y = math.random(-battleRoyale.death_shake, battleRoyale.death_shake)
        love.graphics.translate(shake_x, shake_y)
    end
    
    -- Clear background
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, battleRoyale.screen_width, battleRoyale.screen_height)
    
    -- Draw starfield background
    battleRoyale.drawStars()
    
    -- Draw safe zone (use synchronized data if available)
    battleRoyale.drawSafeZone(playersTable)
    
    -- Draw game elements
    battleRoyale.drawAsteroids()
    
    -- Draw other players
    if playersTable then
        for id, player in pairs(playersTable) do
            if id ~= localPlayerId and player.battleX and player.battleY then
                -- Draw ghost player body
                love.graphics.setColor(player.color[1], player.color[2], player.color[3], 0.5)
                love.graphics.rectangle('fill',
                    player.battleX,
                    player.battleY,
                    battleRoyale.player.width,
                    battleRoyale.player.height
                )
                
                -- Draw their face if available
                if player.facePoints then
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.draw(
                        player.facePoints,
                        player.battleX,
                        player.battleY,
                        0,
                        battleRoyale.player.width/100,
                        battleRoyale.player.height/100
                    )
                end
                
                love.graphics.setColor(1, 1, 0, 0.8)
                love.graphics.printf(
                    "Score: " .. math.floor(player.totalScore or 0),
                    player.battleX - 50,
                    player.battleY - 40,
                    100,
                    "center"
                )
            end
        end
    end
    
    -- No spectator mode text needed with respawn mechanism
    
    -- Draw local player (only if not dropped)
    if not battleRoyale.player_dropped then
        if playersTable and playersTable[localPlayerId] then
            -- Draw invincibility effect if active
            if battleRoyale.player.is_invincible then
                local invincibility_radius = 35
                
                -- Draw outer glow effect
                love.graphics.setColor(1, 1, 0, 0.3)
                love.graphics.circle('fill',
                    battleRoyale.player.x + battleRoyale.player.width/2,
                    battleRoyale.player.y + battleRoyale.player.height/2,
                    invincibility_radius + 5
                )
                
                -- Draw main invincibility bubble
                love.graphics.setColor(1, 1, 0, 0.2)
                love.graphics.circle('fill',
                    battleRoyale.player.x + battleRoyale.player.width/2,
                    battleRoyale.player.y + battleRoyale.player.height/2,
                    invincibility_radius
                )
                
                -- Draw border with pulsing effect
                local pulse = math.sin(love.timer.getTime() * 8) * 0.2 + 0.8
                love.graphics.setColor(1, 1, 0, pulse)
                love.graphics.setLineWidth(2)
                love.graphics.circle('line',
                    battleRoyale.player.x + battleRoyale.player.width/2,
                    battleRoyale.player.y + battleRoyale.player.height/2,
                    invincibility_radius
                )
                love.graphics.setLineWidth(1)
            end
            
            -- Draw player
            love.graphics.setColor(battleRoyale.playerColor)
            love.graphics.rectangle('fill',
                battleRoyale.player.x,
                battleRoyale.player.y,
                battleRoyale.player.width,
                battleRoyale.player.height
            )
            
            -- Draw face
            if playersTable[localPlayerId].facePoints then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    playersTable[localPlayerId].facePoints,
                    battleRoyale.player.x,
                    battleRoyale.player.y,
                    0,
                    battleRoyale.player.width/100,
                    battleRoyale.player.height/100
                )
            end
        end
    else
        -- Draw death indicator with respawn countdown
        love.graphics.setColor(1, 0, 0, 0.7)
        love.graphics.rectangle('fill', battleRoyale.player.x, battleRoyale.player.y, battleRoyale.player.width, battleRoyale.player.height)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf('RESPAWNING', battleRoyale.player.x - 30, battleRoyale.player.y - 30, battleRoyale.player.width + 60, 'center')
        if battleRoyale.respawn_timer > 0 then
            love.graphics.printf(string.format('%.1f', battleRoyale.respawn_timer), 
                battleRoyale.player.x - 20, battleRoyale.player.y - 10, battleRoyale.player.width + 40, 'center')
        end
    end
    
    -- Draw UI elements
    battleRoyale.drawUI(playersTable, localPlayerId)
end



function battleRoyale.drawSafeZone(playersTable)
    -- Use deterministic safe zone data (same on all clients)
    local center_x, center_y, radius = battleRoyale.center_x, battleRoyale.center_y, battleRoyale.safe_zone_radius
    
    -- Only draw if radius is greater than 0
    if radius > 0 then
        -- Get rhythmic rotation for safety circle (only when music is playing)
        local rotation = 0
        if musicHandler.music and musicHandler.isPlaying then
            local _, _, rhythmicRotation = musicHandler.applyToDrawable("safety_circle_rotate", 1, 1)
            rotation = rhythmicRotation or 0
            
            -- Add continuous rotation for more dynamic movement
            local time = love.timer.getTime()
            rotation = rotation + time * 0.5 -- Continuous slow rotation
        end
        
        -- Draw safe zone circle - always blue
        local alpha = 0.2
        local r, g, b = 0.3, 0.6, 1.0 -- Always blue
        
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.circle('fill', center_x, center_y, radius)
        
        -- Draw safe zone border with status-based color and rhythmic rotation
        love.graphics.push()
        love.graphics.translate(center_x, center_y)
        love.graphics.rotate(rotation)
        
        -- Always use blue border
        love.graphics.setColor(0.4, 0.7, 1.0, 0.6) -- Always blue
            love.graphics.circle('line', 0, 0, radius)
        
        love.graphics.pop()
    end
    
    -- No warning text for minimum safe zone size
end

function battleRoyale.drawUI(playersTable, localPlayerId)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Score: ' .. math.floor(battleRoyale.current_round_score), 10, 10)

    love.graphics.printf(string.format("Time: %.1f", battleRoyale.timer), 
    0, 10, love.graphics.getWidth(), "center")
    
    if playersTable and playersTable[localPlayerId] then
        love.graphics.print('Total Score: ' .. 
            math.floor(playersTable[localPlayerId].totalScore or 0), 10, 30)
    end
    
    -- Display invincibility status
    if battleRoyale.player.is_invincible then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print('INVINCIBLE: ' .. string.format("%.1f", battleRoyale.player.invincibility_timer), 10, 50)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Display respawn countdown if dead
    if battleRoyale.player_dropped and battleRoyale.respawn_timer > 0 then
        love.graphics.setColor(1, 0, 0)
        love.graphics.print('RESPAWNING IN: ' .. string.format("%.1f", battleRoyale.respawn_timer), 10, 70)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Show safe zone info
    love.graphics.print('Safe Zone Radius: ' .. math.floor(battleRoyale.safe_zone_radius), 10, battleRoyale.screen_height - 80)
    
    -- Show shrink status
    local phase_text = "READY"
    local phase_color = {0.5, 1, 0.5}
    local timer_value = 0
    
    if battleRoyale.shrink_start_time == 0 or not battleRoyale.game_started then
        phase_text = "READY"
        phase_color = {0.5, 1, 0.5}
        timer_value = battleRoyale.shrink_duration
    else
        local elapsed_shrink_time = love.timer.getTime() - battleRoyale.shrink_start_time
        if battleRoyale.is_growing then
            phase_text = "GROWING"
            phase_color = {0.5, 1, 0.5}
            timer_value = battleRoyale.grow_timer
        elseif elapsed_shrink_time <= battleRoyale.shrink_duration then
            phase_text = "SHRINKING"
            phase_color = {1, 0.5, 0.5}
            timer_value = battleRoyale.shrink_duration - elapsed_shrink_time
        else
            phase_text = "STABLE"
            phase_color = {0.5, 1, 0.5}
            timer_value = 0
        end
    end
    
    love.graphics.setColor(phase_color[1], phase_color[2], phase_color[3])
    love.graphics.print('Status: ' .. phase_text, 10, battleRoyale.screen_height - 60)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Time Left: ' .. string.format("%.1f", math.max(0, timer_value)), 10, battleRoyale.screen_height - 40)
    
    -- Show respawn status more prominently
    if battleRoyale.player_dropped and battleRoyale.respawn_timer > 0 then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf('YOU DIED! RESPAWNING IN ' .. string.format("%.1f", battleRoyale.respawn_timer) .. ' SECONDS...', 
            0, battleRoyale.screen_height - 100, battleRoyale.screen_width, 'center')
        love.graphics.setColor(1, 1, 1)
    elseif battleRoyale.player.is_invincible then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf('INVINCIBLE - PROTECTED FROM ASTEROIDS', 
            0, battleRoyale.screen_height - 100, battleRoyale.screen_width, 'center')
        love.graphics.setColor(1, 1, 1)
    end
    
    if not battleRoyale.game_started then
        love.graphics.printf('Get Ready: ' .. math.ceil(battleRoyale.start_timer), 
            0, battleRoyale.screen_height / 2 - 50, battleRoyale.screen_width, 'center')
    end
    
    if battleRoyale.game_over then
        love.graphics.printf('Game Over - You were caught outside the safe zone!', 
            0, battleRoyale.screen_height / 2 - 50, battleRoyale.screen_width, 'center')
    end
end


function battleRoyale.checkCollision(obj1, obj2)
    return obj1.x < obj2.x + obj2.width and
            obj1.x + obj1.width > obj2.x and
            obj1.y < obj2.y + obj2.height and
            obj1.y + obj1.height > obj2.y
end


function battleRoyale.createStars()
    battleRoyale.stars = {}
    -- Create a moving starfield with uniform direction and color
    for i = 1, 150 do
        table.insert(battleRoyale.stars, {
            x = math.random(0, battleRoyale.screen_width),
            y = math.random(0, battleRoyale.screen_height),
            size = math.random(1, 3),
            speed = math.random(20, 60) -- Movement speed in pixels per second
            -- All stars use the global star_direction
        })
    end
end

function battleRoyale.updateStars(dt)
    for i = #battleRoyale.stars, 1, -1 do
        local star = battleRoyale.stars[i]
        
        -- Move star in the global direction
        star.x = star.x + math.cos(battleRoyale.star_direction) * star.speed * dt
        star.y = star.y + math.sin(battleRoyale.star_direction) * star.speed * dt
        
        -- Wrap around screen edges
        if star.x < 0 then
            star.x = battleRoyale.screen_width
        elseif star.x > battleRoyale.screen_width then
            star.x = 0
        end
        
        if star.y < 0 then
            star.y = battleRoyale.screen_height
        elseif star.y > battleRoyale.screen_height then
            star.y = 0
        end
    end
end

-- Power-up functions removed

function battleRoyale.drawStars()
    for _, star in ipairs(battleRoyale.stars) do
        love.graphics.setColor(1, 1, 1, 0.8) -- Uniform white color with slight transparency
        love.graphics.circle('fill', star.x, star.y, star.size)
    end
end

-- Power-up and laser drawing functions removed


function battleRoyale.keypressed(key)
    print("[BattleRoyale] Key pressed: " .. key)
    debugConsole.addMessage("[BattleRoyale] Key pressed: " .. key)
    -- No special key handling needed without power-ups
end

function battleRoyale.handleSpacebar()
    -- No spacebar functionality needed without power-ups
end

function battleRoyale.mousepressed(x, y, button)
    -- No mouse input needed without power-ups
end

function battleRoyale.keyreleased(key)
    battleRoyale.keysPressed[key] = false
end

-- All power-up related functions removed

function battleRoyale.updateAsteroids(dt)
    -- Check if we need to spawn any asteroids based on pre-calculated spawn points
    while #battleRoyale.meteoroidSpawnPoints > 0 and battleRoyale.meteoroidSpawnPoints[1].time <= battleRoyale.gameTime do
        battleRoyale.spawnAsteroidFromSpawnPoint(table.remove(battleRoyale.meteoroidSpawnPoints, 1))
    end
    
    -- Update existing asteroids
    for i = #battleRoyale.asteroids, 1, -1 do
        local asteroid = battleRoyale.asteroids[i]
        
        -- Apply deterministic speed multiplier based on game time
        local speedMultiplier = 1
        -- Speed up after 10 seconds of gameplay
        if battleRoyale.gameTime > 10 then
            speedMultiplier = 1.5 -- 50% faster after 10 seconds
        end
        
        asteroid.x = asteroid.x + asteroid.vx * dt * speedMultiplier
        asteroid.y = asteroid.y + asteroid.vy * dt * speedMultiplier
        
        -- Remove asteroids that are off screen
        if asteroid.x < -50 or asteroid.x > battleRoyale.screen_width + 50 or
           asteroid.y < -50 or asteroid.y > battleRoyale.screen_height + 50 then
            table.remove(battleRoyale.asteroids, i)
        end
    end
end

function battleRoyale.spawnAsteroidFromSpawnPoint(spawnInfo)
    local asteroid = {}
    local side = spawnInfo.side
    local speed = spawnInfo.speed
    local size = spawnInfo.size
    
    if side == 1 then -- Top
        asteroid.x = battleRoyale.random:random(0, battleRoyale.screen_width)
        asteroid.y = -50
        asteroid.vx = battleRoyale.random:random(-speed/4, speed/4)
        asteroid.vy = battleRoyale.random:random(speed/4, speed)
    elseif side == 2 then -- Right
        asteroid.x = battleRoyale.screen_width + 50
        asteroid.y = battleRoyale.random:random(0, battleRoyale.screen_height)
        asteroid.vx = battleRoyale.random:random(-speed, -speed/4)
        asteroid.vy = battleRoyale.random:random(-speed/4, speed/4)
    elseif side == 3 then -- Bottom
        asteroid.x = battleRoyale.random:random(0, battleRoyale.screen_width)
        asteroid.y = battleRoyale.screen_height + 50
        asteroid.vx = battleRoyale.random:random(-speed/4, speed/4)
        asteroid.vy = battleRoyale.random:random(-speed, -speed/4)
    else -- Left
        asteroid.x = -50
        asteroid.y = battleRoyale.random:random(0, battleRoyale.screen_height)
        asteroid.vx = battleRoyale.random:random(speed/4, speed)
        asteroid.vy = battleRoyale.random:random(-speed/4, speed/4)
    end
    
    asteroid.size = size
    asteroid.color = {0.5, 0.5, 0.5} -- Consistent gray color
    asteroid.points = {} -- Store irregular shape points
    battleRoyale.generateAsteroidShape(asteroid) -- Generate the irregular shape
    
    table.insert(battleRoyale.asteroids, asteroid)
end

function battleRoyale.spawnAsteroid()
    local asteroid = {}
    local side = math.random(1, 4) -- 1=top, 2=right, 3=bottom, 4=left
    
    if side == 1 then -- Top
        asteroid.x = math.random(0, battleRoyale.screen_width)
        asteroid.y = -50
        asteroid.vx = math.random(-battleRoyale.asteroid_speed/4, battleRoyale.asteroid_speed/4)
        asteroid.vy = math.random(battleRoyale.asteroid_speed/4, battleRoyale.asteroid_speed)
    elseif side == 2 then -- Right
        asteroid.x = battleRoyale.screen_width + 50
        asteroid.y = math.random(0, battleRoyale.screen_height)
        asteroid.vx = math.random(-battleRoyale.asteroid_speed, -battleRoyale.asteroid_speed/4)
        asteroid.vy = math.random(-battleRoyale.asteroid_speed/4, battleRoyale.asteroid_speed/4)
    elseif side == 3 then -- Bottom
        asteroid.x = math.random(0, battleRoyale.screen_width)
        asteroid.y = battleRoyale.screen_height + 50
        asteroid.vx = math.random(-battleRoyale.asteroid_speed/4, battleRoyale.asteroid_speed/4)
        asteroid.vy = math.random(-battleRoyale.asteroid_speed, -battleRoyale.asteroid_speed/4)
    else -- Left
        asteroid.x = -50
        asteroid.y = math.random(0, battleRoyale.screen_height)
        asteroid.vx = math.random(battleRoyale.asteroid_speed/4, battleRoyale.asteroid_speed)
        asteroid.vy = math.random(-battleRoyale.asteroid_speed/4, battleRoyale.asteroid_speed/4)
    end
    
    asteroid.size = math.random(25, 45)
    asteroid.color = {0.5, 0.5, 0.5} -- Consistent gray color
    asteroid.points = {} -- Store irregular shape points
    battleRoyale.generateAsteroidShape(asteroid) -- Generate the irregular shape
    
    table.insert(battleRoyale.asteroids, asteroid)
end

function battleRoyale.generateAsteroidShape(asteroid)
    -- Generate irregular asteroid shape with 6-8 points using deterministic random
    local num_points = battleRoyale.random:random(6, 8)
    asteroid.points = {}
    
    for i = 1, num_points do
        local angle = (i - 1) * (2 * math.pi / num_points)
        local radius_variation = battleRoyale.random:random(0.7, 1.1) -- Make it irregular but not too extreme
        local base_radius = asteroid.size / 2
        local x = math.cos(angle) * base_radius * radius_variation
        local y = math.sin(angle) * base_radius * radius_variation
        
        -- Add some deterministic jitter to make it more chaotic
        local jitter = asteroid.size / 10
        x = x + battleRoyale.random:random(-jitter, jitter)
        y = y + battleRoyale.random:random(-jitter, jitter)
        
        table.insert(asteroid.points, x)
        table.insert(asteroid.points, y)
    end
end

function battleRoyale.drawAsteroids()
    for _, asteroid in ipairs(battleRoyale.asteroids) do
        love.graphics.push()
        love.graphics.translate(asteroid.x, asteroid.y)
        
        -- Draw asteroid with irregular shape - no animations
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.polygon('fill', asteroid.points)
        
        -- Draw outline
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.polygon('line', asteroid.points)
        
        love.graphics.pop()
    end
end

function battleRoyale.checkAsteroidCollisions()
    for _, asteroid in ipairs(battleRoyale.asteroids) do
        -- Check collision with player
        if battleRoyale.checkCollision(battleRoyale.player, {
            x = asteroid.x - asteroid.size/2,
            y = asteroid.y - asteroid.size/2,
            width = asteroid.size,
            height = asteroid.size
        }) then
            if not battleRoyale.player.is_invincible and not battleRoyale.player_dropped then
                battleRoyale.player_dropped = true
                battleRoyale.death_timer = 2 -- 2 second death animation
                battleRoyale.death_shake = 15 -- Shake intensity
                battleRoyale.respawn_timer = battleRoyale.respawn_delay -- Start respawn timer
                debugConsole.addMessage("[BattleRoyale] Player hit by asteroid! Respawning in " .. battleRoyale.respawn_delay .. " seconds...")
            end
        end
    end
end

-- Laser collisions removed - no power-ups in this version

function battleRoyale.reset()
    battleRoyale.load()
end

function battleRoyale.setPlayerColor(color)
    battleRoyale.playerColor = color
end

function battleRoyale.sendGameStateSync()
    -- Only send sync from host
    if _G and _G.returnState == "hosting" and _G.serverClients then
        local message = string.format("battle_sync,%.2f,%.2f,%.2f,%.2f", 
            battleRoyale.gameTime, 
            battleRoyale.center_x, 
            battleRoyale.center_y, 
            battleRoyale.safe_zone_radius)
        
        for _, client in ipairs(_G.serverClients) do
            -- Use the global safeSend function
            if _G.safeSend then
                _G.safeSend(client, message)
            end
        end
    end
end

return battleRoyale

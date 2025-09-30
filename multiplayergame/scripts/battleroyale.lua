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
battleRoyale.musicAsteroidSpawnPoints = {} -- Pre-calculated music asteroid spawns
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
battleRoyale.safe_zone_radius = 250 -- Start at max radius
battleRoyale.center_x = 400
battleRoyale.center_y = 300
battleRoyale.death_timer = 0
battleRoyale.death_shake = 0
battleRoyale.player_dropped = false
battleRoyale.death_animation_done = false

-- Random grow/shrink system
battleRoyale.min_radius = 120
battleRoyale.max_radius = 250
battleRoyale.shrink_chance = 1.0 -- Always shrink, never grow
battleRoyale.size_change_timer = 0
battleRoyale.size_change_interval = 1.5 -- Change every 1.5 seconds
battleRoyale.current_change_rate = 0 -- Current radius change rate
battleRoyale.change_duration = 0 -- How long current change lasts

battleRoyale.safe_zone_move_speed = 40 -- pixels per second (slower than player)
battleRoyale.safe_zone_move_timer = 0
battleRoyale.safe_zone_target_x = 400
battleRoyale.safe_zone_target_y = 300
battleRoyale.sync_timer = 0
battleRoyale.sync_interval = 1/60 -- Send sync every 1/60 seconds (60 times per second)
battleRoyale.respawn_timer = 0 -- Timer for respawn mechanism
battleRoyale.respawn_delay = 3 -- 3 seconds before respawn

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
battleRoyale.music_asteroids = {} -- New music-synced asteroids
battleRoyale.asteroid_spawn_timer = 0
battleRoyale.asteroid_spawn_interval = 1.0 -- More frequent asteroid spawning
battleRoyale.asteroid_speed = 600 -- Pixels per second (much faster)
battleRoyale.music_asteroid_spawn_timer = 0
battleRoyale.music_asteroid_spawn_interval = 2.0 -- Less frequent music asteroids
battleRoyale.stars = {} -- Moving starfield background
battleRoyale.star_direction = 0 -- Global direction for all stars

-- Music-synced safety ring system
battleRoyale.safety_ring_colors = {
    {0.3, 0.6, 1.0}, -- Blue (default)
    {1.0, 0.3, 0.3}, -- Red
    {0.3, 1.0, 0.3}, -- Green
    {1.0, 1.0, 0.3}, -- Yellow
    {1.0, 0.3, 1.0}, -- Magenta
    {0.3, 1.0, 1.0}, -- Cyan
    {1.0, 0.6, 0.3}, -- Orange
    {0.6, 0.3, 1.0}  -- Purple
}
battleRoyale.current_color_index = 1
battleRoyale.safety_ring_directions = {
    {1, 0},   -- Right
    {1, 1},   -- Down-Right
    {0, 1},   -- Down
    {-1, 1},  -- Down-Left
    {-1, 0},  -- Left
    {-1, -1}, -- Up-Left
    {0, -1},  -- Up
    {1, -1}   -- Up-Right
}
battleRoyale.current_direction_index = 1
battleRoyale.safe_zone_direction = {1, 0} -- Current movement direction
battleRoyale.beat_count = 0 -- Track beats for synchronization

-- Music asteroid color system
battleRoyale.music_asteroid_colors = {
    {0.8, 0.3, 0.8}, -- Purple
    {1.0, 0.5, 0.0}, -- Orange
    {0.0, 0.8, 1.0}, -- Cyan
    {1.0, 0.0, 0.5}, -- Pink
    {0.5, 1.0, 0.0}, -- Lime
    {1.0, 1.0, 0.0}, -- Yellow
    {0.0, 1.0, 0.5}, -- Teal
    {1.0, 0.3, 0.0}  -- Red-Orange
}
battleRoyale.music_asteroid_color_index = 1

-- Interpolation variables for smooth sync
battleRoyale.last_sync_time = 0
battleRoyale.target_center_x = 400
battleRoyale.target_center_y = 300
battleRoyale.target_radius = 250
battleRoyale.sync_interpolation_speed = 60.0 -- How fast to interpolate to target (matches 60Hz sync)
battleRoyale.radius_interpolation_speed = 120.0 -- Faster interpolation for radius changes
battleRoyale.last_radius = 250 -- Track last radius for smooth transitions

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
    battleRoyale.safe_zone_radius = 250 -- Start at max radius
    battleRoyale.size_change_timer = 0
    battleRoyale.current_change_rate = 0
    battleRoyale.change_duration = 0
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
    
    -- Add dancing effects for music-synced asteroids (like platforms in jump game)
    musicHandler.addEffect("music_asteroids", "combo", {
        scaleAmount = 0.15,        -- Scale up to 15% bigger on beat
        rotateAmount = math.pi/8,  -- Rotate 22.5 degrees on beat
        frequency = 1,             -- Once per beat
        phase = 0,
        snapDuration = 0.15        -- Quick snap effect
    })
    
    musicHandler.addEffect("asteroid_pulse", "beatPulse", {
        baseColor = {0.5, 0.5, 0.5}, -- Gray base color
        intensity = 0.4,
        duration = 0.15
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
    
    -- Reset respawn timer
    battleRoyale.respawn_timer = 0
    
    -- Reset music-synced variables
    battleRoyale.current_color_index = 1
    battleRoyale.current_direction_index = 1
    battleRoyale.safe_zone_direction = {1, 0}
    battleRoyale.beat_count = 0
    battleRoyale.music_asteroid_color_index = 1
    battleRoyale.last_sync_time = 0
    battleRoyale.target_center_x = battleRoyale.screen_width / 2
    battleRoyale.target_center_y = battleRoyale.screen_height / 2
    battleRoyale.target_radius = 250
    battleRoyale.last_radius = 250
    
    -- In party mode, ensure player starts in center of safe zone
    debugConsole.addMessage("[BattleRoyale] Checking party mode: " .. tostring(_G and _G.partyMode or "nil") .. " (type: " .. type(_G and _G.partyMode) .. ")")
    if _G and _G.partyMode == true then
        battleRoyale.player.x = battleRoyale.screen_width / 2
        battleRoyale.player.y = battleRoyale.screen_height / 2
        battleRoyale.center_x = battleRoyale.screen_width / 2
        battleRoyale.center_y = battleRoyale.screen_height / 2
        battleRoyale.safe_zone_radius = 250 -- Start at max radius
        
        -- Debug music handler state
        debugConsole.addMessage("[PartyMode] Player positioned in center of safe zone")
    else
        debugConsole.addMessage("[BattleRoyale] Party mode not detected, using normal initialization")
    end
    
    -- No spacebar functionality needed without power-ups

    -- Reset safe zone to center of screen
    battleRoyale.center_x = battleRoyale.screen_width / 2  -- 400
    battleRoyale.center_y = battleRoyale.screen_height / 2 -- 300
    battleRoyale.safe_zone_radius = 250 -- Start at max radius
    
    -- Set star direction for this round
    battleRoyale.star_direction = math.random(0, 2 * math.pi)
    
    -- Create game elements
    battleRoyale.createStars()
    battleRoyale.asteroids = {}
    battleRoyale.music_asteroids = {}
    battleRoyale.asteroid_spawn_timer = 0
    battleRoyale.music_asteroid_spawn_timer = 0

    -- Override music handler onBeat function for Battle Royale
    musicHandler.onBeat = battleRoyale.handleBeat

    debugConsole.addMessage("[BattleRoyale] Game loaded")
end

-- Handle beat events for music synchronization
function battleRoyale.handleBeat()
    if not battleRoyale.game_started then return end
    
    battleRoyale.beat_count = battleRoyale.beat_count + 1
    
    -- Change safety ring border color every beat
    battleRoyale.current_color_index = battleRoyale.current_color_index + 1
    if battleRoyale.current_color_index > #battleRoyale.safety_ring_colors then
        battleRoyale.current_color_index = 1
    end
    
    -- Change direction every beat for faster movement
    battleRoyale.current_direction_index = battleRoyale.current_direction_index + 1
    if battleRoyale.current_direction_index > #battleRoyale.safety_ring_directions then
        battleRoyale.current_direction_index = 1
    end
    
    -- Update safe zone movement direction
    battleRoyale.safe_zone_direction = battleRoyale.safety_ring_directions[battleRoyale.current_direction_index]
    
    -- Change music asteroid colors every beat
    battleRoyale.music_asteroid_color_index = battleRoyale.music_asteroid_color_index + 1
    if battleRoyale.music_asteroid_color_index > #battleRoyale.music_asteroid_colors then
        battleRoyale.music_asteroid_color_index = 1
    end
    
    -- Calculate current speed multiplier for debug
    local base_speed = battleRoyale.safe_zone_move_speed
    local raw_multiplier = 1.0 + (battleRoyale.beat_count * 0.05)
    local max_multiplier = battleRoyale.player.speed / base_speed
    local actual_multiplier = math.min(raw_multiplier, max_multiplier)
    
    debugConsole.addMessage(string.format("[BattleRoyale] Beat %d - Border Color: %d, Direction: %d, Speed: %.1fx (capped at %.1fx)", 
        battleRoyale.beat_count, battleRoyale.current_color_index, battleRoyale.current_direction_index, actual_multiplier, max_multiplier))
end

function battleRoyale.setSeed(seed)
    battleRoyale.seed = seed
    battleRoyale.random:setSeed(seed)
    battleRoyale.gameTime = 0
    battleRoyale.nextMeteoroidTime = 0
    battleRoyale.meteoroidSpawnPoints = {}
    battleRoyale.musicAsteroidSpawnPoints = {}
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
    
    -- Pre-calculate music asteroid spawn points
    time = 0
    while time < battleRoyale.timer do
        local musicSpawnInfo = {
            time = time,
            side = battleRoyale.random:random(1, 4), -- 1=top, 2=right, 3=bottom, 4=left
            speed = battleRoyale.random:random(300, 500), -- Slower than regular asteroids
            size = battleRoyale.random:random(30, 50) -- Larger than regular asteroids
        }
        table.insert(battleRoyale.musicAsteroidSpawnPoints, musicSpawnInfo)
        
        -- Spawn music asteroids less frequently (every 2-4 seconds)
        time = time + battleRoyale.random:random(2.0, 4.0)
    end
    
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
        "[BattleRoyale] Generated %d meteoroid, %d music asteroids, and %d safe zone targets with seed %d",
        #battleRoyale.meteoroidSpawnPoints,
        #battleRoyale.musicAsteroidSpawnPoints,
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
            -- Reset safe zone to max size when game starts in party mode
            battleRoyale.safe_zone_radius = 250
            battleRoyale.center_x = battleRoyale.screen_width / 2
            battleRoyale.center_y = battleRoyale.screen_height / 2
            debugConsole.addMessage("[PartyMode] Game started - reset safe zone to max size")
            
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
    
    -- Move safe zone - use interpolation for clients, direct movement for host
    if _G and _G.returnState == "hosting" then
        -- Host: direct movement using music-synced direction
        local base_speed = battleRoyale.safe_zone_move_speed
        local beat_speed_multiplier = 1.0 + (battleRoyale.beat_count * 0.05) -- Slower speed increase
        -- Cap speed multiplier to ensure safe zone never moves faster than player (250 pixels/sec)
        local max_multiplier = battleRoyale.player.speed / base_speed -- 250/40 = 6.25
        beat_speed_multiplier = math.min(beat_speed_multiplier, max_multiplier)
        local move_speed = base_speed * beat_speed_multiplier * dt
        local move_x = battleRoyale.safe_zone_direction[1] * move_speed
        local move_y = battleRoyale.safe_zone_direction[2] * move_speed
        
        battleRoyale.center_x = battleRoyale.center_x + move_x
        battleRoyale.center_y = battleRoyale.center_y + move_y
        
        -- Keep safe zone center within screen bounds with padding
        local padding = battleRoyale.safe_zone_radius + 50
        battleRoyale.center_x = math.max(padding, math.min(battleRoyale.screen_width - padding, battleRoyale.center_x))
        battleRoyale.center_y = math.max(padding, math.min(battleRoyale.screen_height - padding, battleRoyale.center_y))
        
        -- Update target positions for interpolation
        battleRoyale.target_center_x = battleRoyale.center_x
        battleRoyale.target_center_y = battleRoyale.center_y
        battleRoyale.target_radius = battleRoyale.safe_zone_radius
        
        -- Track radius changes for smooth transitions
        battleRoyale.last_radius = battleRoyale.safe_zone_radius
    else
        -- Client: interpolate towards target positions
        local lerp_factor = battleRoyale.sync_interpolation_speed * dt
        
        -- Interpolate center position
        battleRoyale.center_x = battleRoyale.center_x + (battleRoyale.target_center_x - battleRoyale.center_x) * lerp_factor
        battleRoyale.center_y = battleRoyale.center_y + (battleRoyale.target_center_y - battleRoyale.center_y) * lerp_factor
        
        -- Interpolate radius with faster speed for smoother growth/shrinking
        local radius_lerp_factor = battleRoyale.radius_interpolation_speed * dt
        battleRoyale.safe_zone_radius = battleRoyale.safe_zone_radius + (battleRoyale.target_radius - battleRoyale.safe_zone_radius) * radius_lerp_factor
        
        -- Update last radius for smooth transitions
        battleRoyale.last_radius = battleRoyale.safe_zone_radius
    end

    -- Update random grow/shrink system
    if battleRoyale.game_started then
        battleRoyale.size_change_timer = battleRoyale.size_change_timer + dt
        
        -- Check if it's time to change size direction
        if battleRoyale.size_change_timer >= battleRoyale.size_change_interval then
            battleRoyale.size_change_timer = 0
            
            -- Use deterministic random for synchronization
            local time_seed = math.floor(battleRoyale.gameTime * 10)
            battleRoyale.random:setSeed(battleRoyale.seed + time_seed)
            local random_value = battleRoyale.random:random(0, 100)
            
            -- Always shrink - slower rate for more gradual shrinking
            battleRoyale.current_change_rate = -15 -- pixels per second (slower shrinking)
            battleRoyale.change_duration = battleRoyale.random:random(2.0, 4.0) -- 2-4 seconds (longer duration)
            debugConsole.addMessage("[SafeZone] Starting to shrink for " .. battleRoyale.change_duration .. " seconds")
            
            -- Restore original seed
            battleRoyale.random:setSeed(battleRoyale.seed)
        end
        
        -- Apply current size change if we have one
        if battleRoyale.change_duration > 0 then
            battleRoyale.change_duration = battleRoyale.change_duration - dt
            
            -- Apply radius change
            local new_radius = battleRoyale.safe_zone_radius + (battleRoyale.current_change_rate * dt)
            
            -- Clamp to min/max bounds
            battleRoyale.safe_zone_radius = math.max(battleRoyale.min_radius, 
                                                   math.min(battleRoyale.max_radius, new_radius))
            
            if battleRoyale.change_duration <= 0 then
                battleRoyale.current_change_rate = 0
                debugConsole.addMessage("[SafeZone] Size change completed. Current radius: " .. math.floor(battleRoyale.safe_zone_radius))
            end
        end
    end

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
        
        -- Draw safe zone circle - keep fill color consistent (blue)
        local alpha = 0.2
        love.graphics.setColor(0.3, 0.6, 1.0, alpha) -- Always blue fill
        love.graphics.circle('fill', center_x, center_y, radius)
        
        -- Draw safe zone border with music-synced color and rhythmic rotation
        love.graphics.push()
        love.graphics.translate(center_x, center_y)
        love.graphics.rotate(rotation)
        
        -- Use music-synced color for border only
        local current_color = battleRoyale.safety_ring_colors[battleRoyale.current_color_index]
        local r, g, b = current_color[1], current_color[2], current_color[3]
        love.graphics.setColor(r, g, b, 0.8) -- Bright border with current beat color
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
    love.graphics.print('Safe Zone Radius: ' .. math.floor(battleRoyale.safe_zone_radius) .. ' (Range: ' .. battleRoyale.min_radius .. '-' .. battleRoyale.max_radius .. ')', 10, battleRoyale.screen_height - 80)
    
    -- Show current size change status
    local phase_text = "READY"
    local phase_color = {0.5, 1, 0.5}
    local timer_value = 0
    
    if not battleRoyale.game_started then
        phase_text = "READY"
        phase_color = {0.5, 1, 0.5}
    elseif battleRoyale.change_duration > 0 then
        phase_text = "SHRINKING"
        phase_color = {1, 0.5, 0.5}
        timer_value = battleRoyale.change_duration
    else
        phase_text = "STABLE"
        phase_color = {0.7, 0.7, 0.7}
        timer_value = battleRoyale.size_change_interval - battleRoyale.size_change_timer
    end
    
    love.graphics.setColor(phase_color[1], phase_color[2], phase_color[3])
    love.graphics.print('Status: ' .. phase_text, 10, battleRoyale.screen_height - 60)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Next Change: ' .. string.format("%.1f", math.max(0, timer_value)), 10, battleRoyale.screen_height - 40)
    
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
    -- Check if we need to spawn any regular asteroids based on pre-calculated spawn points
    while #battleRoyale.meteoroidSpawnPoints > 0 and battleRoyale.meteoroidSpawnPoints[1].time <= battleRoyale.gameTime do
        battleRoyale.spawnAsteroidFromSpawnPoint(table.remove(battleRoyale.meteoroidSpawnPoints, 1))
    end
    
    -- Check if we need to spawn any music asteroids based on pre-calculated spawn points
    while #battleRoyale.musicAsteroidSpawnPoints > 0 and battleRoyale.musicAsteroidSpawnPoints[1].time <= battleRoyale.gameTime do
        battleRoyale.spawnMusicAsteroidFromSpawnPoint(table.remove(battleRoyale.musicAsteroidSpawnPoints, 1))
    end
    
    -- Update existing regular asteroids
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
    
    -- Update music-synced asteroids
    for i = #battleRoyale.music_asteroids, 1, -1 do
        local asteroid = battleRoyale.music_asteroids[i]
        
        -- Music asteroids move at consistent speed (no speed multiplier)
        asteroid.x = asteroid.x + asteroid.vx * dt
        asteroid.y = asteroid.y + asteroid.vy * dt
        
        -- Remove asteroids that are off screen
        if asteroid.x < -50 or asteroid.x > battleRoyale.screen_width + 50 or
           asteroid.y < -50 or asteroid.y > battleRoyale.screen_height + 50 then
            table.remove(battleRoyale.music_asteroids, i)
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

function battleRoyale.spawnMusicAsteroidFromSpawnPoint(spawnInfo)
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
    asteroid.color = battleRoyale.music_asteroid_colors[battleRoyale.music_asteroid_color_index] -- Use current beat color
    asteroid.points = {} -- Store irregular shape points
    asteroid.is_music_asteroid = true -- Mark as music asteroid
    battleRoyale.generateAsteroidShape(asteroid) -- Generate the irregular shape
    
    table.insert(battleRoyale.music_asteroids, asteroid)
    debugConsole.addMessage("[MusicAsteroid] Spawned music-synced asteroid at time " .. spawnInfo.time)
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
    -- Draw regular asteroids (unchanged)
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
    
    -- Draw music-synced asteroids with beat effects
    for i, asteroid in ipairs(battleRoyale.music_asteroids) do
        love.graphics.push()
        love.graphics.translate(asteroid.x, asteroid.y)
        
        -- Get music effects for asteroids
        local pulseColor = musicHandler.getCurrentColor("asteroid_pulse")
        local x, y, rotation, scaleX, scaleY = musicHandler.applyToDrawable("music_asteroids", 0, 0)
        
        -- Apply rotation and scale from music effects
        love.graphics.rotate(rotation or 0)
        love.graphics.scale(scaleX or 1, scaleY or 1)
        
        -- Use the asteroid's stored color (set when spawned) with pulse effect
        local baseColor = asteroid.color or {0.8, 0.3, 0.8}
        local finalColor = {
            baseColor[1] * pulseColor[1],
            baseColor[2] * pulseColor[2], 
            baseColor[3] * pulseColor[3]
        }
        
        -- Draw asteroid with dynamic color
        love.graphics.setColor(finalColor[1], finalColor[2], finalColor[3])
        love.graphics.polygon('fill', asteroid.points)
        
        -- Draw outline with darker color
        love.graphics.setColor(finalColor[1] * 0.6, finalColor[2] * 0.6, finalColor[3] * 0.6)
        love.graphics.polygon('line', asteroid.points)
        
        love.graphics.pop()
    end
end

function battleRoyale.checkAsteroidCollisions()
    -- Check collisions with regular asteroids
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
                debugConsole.addMessage("[BattleRoyale] Player hit by regular asteroid! Respawning in " .. battleRoyale.respawn_delay .. " seconds...")
            end
        end
    end
    
    -- Check collisions with music-synced asteroids
    for _, asteroid in ipairs(battleRoyale.music_asteroids) do
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
                debugConsole.addMessage("[BattleRoyale] Player hit by music asteroid! Respawning in " .. battleRoyale.respawn_delay .. " seconds...")
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
        -- Compact message format for high-frequency updates
        local message = string.format("bsync,%.1f,%.1f,%.1f,%.1f,%d,%d,%d,%.1f,%.1f,%d", 
            battleRoyale.gameTime, 
            battleRoyale.center_x, 
            battleRoyale.center_y, 
            battleRoyale.safe_zone_radius,
            battleRoyale.current_color_index,
            battleRoyale.current_direction_index,
            battleRoyale.beat_count,
            battleRoyale.current_change_rate,
            battleRoyale.change_duration,
            battleRoyale.music_asteroid_color_index)
        
        for _, client in ipairs(_G.serverClients) do
            -- Use the global safeSend function
            if _G.safeSend then
                _G.safeSend(client, message)
            end
        end
    end
end

return battleRoyale

local meteorShower = {}
meteorShower.name = "meteorshower"
local debugConsole = require "src.core.debugconsole"
local musicHandler = require "src.game.systems.musichandler"
local gameUI = require "src.game.systems.gameui"

-- Sound effects
meteorShower.sounds = {
    death = love.audio.newSource("sounds/death.mp3", "static")
}

-- Set death sound volume
meteorShower.sounds.death:setVolume(0.3)

-- Game state
meteorShower.game_over = false
meteorShower.current_round_score = 0
meteorShower.playerColor = {1, 1, 1}
meteorShower.screen_width = 800  -- Fixed base resolution
meteorShower.screen_height = 600  -- Fixed base resolution
meteorShower.camera_x = 0
meteorShower.camera_y = 0
meteorShower.death_count = 0
meteorShower.partyMode = false  -- Party mode flag
meteorShower.isHost = false  -- Host flag for safe zone movement
meteorShower.hits = 0  -- Track hits
meteorShower.showTabScores = false  -- Tab key pressed

-- Seed-based synchronization (like laser game)
meteorShower.seed = 0
meteorShower.random = love.math.newRandomGenerator()
meteorShower.gameTime = 0
meteorShower.nextMeteoroidTime = 0
meteorShower.meteoroidSpawnPoints = {}
meteorShower.musicAsteroidSpawnPoints = {} -- Pre-calculated music asteroid spawns
meteorShower.safeZoneTargets = {}

-- Game settings 
meteorShower.gravity = 1000
meteorShower.game_started = false
meteorShower.start_timer = 0
meteorShower.shrink_timer = 15
meteorShower.shrink_interval = 2
meteorShower.shrink_padding_x = 0
meteorShower.shrink_padding_y = 0
meteorShower.max_shrink_padding_x = 300
meteorShower.max_shrink_padding_y = 200
-- Use safe timer calculation with fallback for party mode
local beatInterval = musicHandler.beatInterval or 2.0 -- Fallback to 2 seconds if not set
meteorShower.timer = beatInterval * 12.5 -- 25 seconds (reduced by 15 seconds)
meteorShower.safe_zone_radius = 450 -- Start at max radius (increased to compensate for smaller scale)
meteorShower.center_x = 400
meteorShower.center_y = 300
meteorShower.death_timer = 0
meteorShower.death_shake = 0
meteorShower.player_dropped = false
meteorShower.death_animation_done = false

-- Random grow/shrink system (compensated for smaller scale)
meteorShower.min_radius = 120  -- Increased to compensate for smaller scale
meteorShower.max_radius = 450  -- Increased to compensate for smaller scale
meteorShower.shrink_chance = 1.0 -- Always shrink, never grow
meteorShower.size_change_timer = 0
meteorShower.size_change_interval = 1.5 -- Change every 1.5 seconds
meteorShower.current_change_rate = 0 -- Current radius change rate
meteorShower.change_duration = 0 -- How long current change lasts

meteorShower.safe_zone_move_speed = 50 -- pixels per second
meteorShower.safe_zone_move_timer = 0
meteorShower.safe_zone_target_x = 400
meteorShower.safe_zone_target_y = 300
meteorShower.sync_timer = 0
meteorShower.sync_interval = 1/60 -- Send sync every 1/60 seconds (60 times per second)
meteorShower.respawn_timer = 0 -- Timer for respawn mechanism
meteorShower.respawn_delay = 1 -- 1 second before respawn

-- Player settings (30x30 to match laser game)
meteorShower.player = {
    x = 400,
    y = 300,
    width = 30,
    height = 30,
    speed = 250,
    normal_speed = 250,
    points = 0,
    is_invincible = false,
    invincibility_timer = 0
}

-- Sounds removed - no power-ups in this version

-- Game objects
meteorShower.keysPressed = {}
meteorShower.safe_zone_alpha = 0.3
meteorShower.asteroids = {}
meteorShower.music_asteroids = {} -- New music-synced asteroids
meteorShower.asteroid_spawn_timer = 0
meteorShower.asteroid_spawn_interval = 1.0 -- More frequent asteroid spawning
meteorShower.asteroid_speed = 600 -- Pixels per second (much faster)
meteorShower.music_asteroid_spawn_timer = 0
meteorShower.music_asteroid_spawn_interval = 2.0 -- Less frequent music asteroids
meteorShower.stars = {} -- Moving starfield background
meteorShower.star_direction = 0 -- Global direction for all stars

-- Music-synced safety ring system
meteorShower.safety_ring_colors = {
    {0.3, 0.6, 1.0}, -- Blue (default)
    {1.0, 0.3, 0.3}, -- Red
    {0.3, 1.0, 0.3}, -- Green
    {1.0, 1.0, 0.3}, -- Yellow
    {1.0, 0.3, 1.0}, -- Magenta
    {0.3, 1.0, 1.0}, -- Cyan
    {1.0, 0.6, 0.3}, -- Orange
    {0.6, 0.3, 1.0}  -- Purple
}
meteorShower.current_color_index = 1
meteorShower.safe_zone_direction = {1, 0} -- Current movement direction
meteorShower.direction_angle = 0 -- Current direction angle in radians
meteorShower.target_x = 400 -- Target position to move towards
meteorShower.target_y = 300 -- Target position to move towards
meteorShower.target_reached_threshold = 50 -- Distance threshold to consider target reached
meteorShower.beat_count = 0 -- Track beats for synchronization

-- Music asteroid color system
meteorShower.music_asteroid_colors = {
    {0.8, 0.3, 0.8}, -- Purple
    {1.0, 0.5, 0.0}, -- Orange
    {0.0, 0.8, 1.0}, -- Cyan
    {1.0, 0.0, 0.5}, -- Pink
    {0.5, 1.0, 0.0}, -- Lime
    {1.0, 1.0, 0.0}, -- Yellow
    {0.0, 1.0, 0.5}, -- Teal
    {1.0, 0.3, 0.0}  -- Red-Orange
}
meteorShower.music_asteroid_color_index = 1

-- Interpolation variables for smooth sync
meteorShower.last_sync_time = 0
meteorShower.target_center_x = 400
meteorShower.target_center_y = 300
meteorShower.target_radius = 250
meteorShower.sync_interpolation_speed = 60.0 -- How fast to interpolate to target (matches 60Hz sync)
meteorShower.radius_interpolation_speed = 120.0 -- Faster interpolation for radius changes
meteorShower.last_radius = 250 -- Track last radius for smooth transitions

function meteorShower.load(args)
    args = args or {}
    meteorShower.partyMode = args.partyMode or false
    meteorShower.isHost = args.isHost or false
    
    debugConsole.addMessage("[MeteorShower] Loading meteor shower game")
    debugConsole.addMessage("[MeteorShower] Party mode status: " .. tostring(meteorShower.partyMode))
    debugConsole.addMessage("[MeteorShower] Is host: " .. tostring(meteorShower.isHost))
    -- Reset game state
    meteorShower.game_over = false
    meteorShower.current_round_score = 0
    meteorShower.death_count = 0
    meteorShower.hits = 0  -- Reset hits counter for party mode
    meteorShower.death_timer = 0
    meteorShower.death_shake = 0
    meteorShower.player_dropped = false
    meteorShower.death_animation_done = false
    meteorShower.game_started = false
    meteorShower.start_timer = 0
    meteorShower.safe_zone_radius = 250 -- Start at max radius
    meteorShower.size_change_timer = 0
    meteorShower.current_change_rate = 0
    meteorShower.change_duration = 0
    meteorShower.player.drop_cooldown = 0
    meteorShower.player.dropping = false
    meteorShower.player.jump_count = 0
    meteorShower.player.has_double_jumped = false
    meteorShower.player.on_ground = false
    -- Use safe timer calculation with fallback for party mode
    local beatInterval = musicHandler.beatInterval or 2.0 -- Fallback to 2 seconds if not set
    meteorShower.timer = beatInterval * 12.5 -- 25 seconds (reduced by 15 seconds)
    meteorShower.gameTime = 0
    debugConsole.addMessage("[MeteorShower] Meteor shower loaded successfully")

    meteorShower.keysPressed = {}
    
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
    meteorShower.player = {
        x = 400,
        y = 300,
        width = 30,
        height = 30,
        speed = 250,
        normal_speed = 250,
        points = 0,
        is_invincible = false,
        invincibility_timer = 0
    }
    
    -- Set player color if available from args
    if args.players and args.localPlayerId ~= nil then
        local localPlayer = args.players[args.localPlayerId]
        if localPlayer and localPlayer.color then
            meteorShower.playerColor = localPlayer.color
        end
    end
    
    -- Reset respawn timer
    meteorShower.respawn_timer = 0
    
    -- Reset music-synced variables
    meteorShower.current_color_index = 1
    meteorShower.safe_zone_direction = {1, 0}
    meteorShower.direction_angle = 0
    -- Initialize first target using seeded random
    local margin = 100
    meteorShower.target_x = meteorShower.random:random(margin, meteorShower.screen_width - margin)
    meteorShower.target_y = meteorShower.random:random(margin, meteorShower.screen_height - margin)
    meteorShower.beat_count = 0
    meteorShower.lastTargetIndex = -1  -- Initialize for deterministic target selection
    meteorShower.music_asteroid_color_index = 1
    meteorShower.last_sync_time = 0
    meteorShower.target_center_x = meteorShower.screen_width / 2
    meteorShower.target_center_y = meteorShower.screen_height / 2
    meteorShower.target_radius = 250
    meteorShower.last_radius = 250
    
    -- In party mode, ensure player starts in center of safe zone
    debugConsole.addMessage("[BattleRoyale] Checking party mode: " .. tostring(_G and _G.partyMode or "nil") .. " (type: " .. type(_G and _G.partyMode) .. ")")
    if _G and _G.partyMode == true then
        meteorShower.player.x = meteorShower.screen_width / 2
        meteorShower.player.y = meteorShower.screen_height / 2
        meteorShower.center_x = meteorShower.screen_width / 2
        meteorShower.center_y = meteorShower.screen_height / 2
        meteorShower.safe_zone_radius = 250 -- Start at max radius
        
        -- Debug music handler state
        debugConsole.addMessage("[PartyMode] Player positioned in center of safe zone")
    else
        debugConsole.addMessage("[BattleRoyale] Party mode not detected, using normal initialization")
    end
    
    -- No spacebar functionality needed without power-ups

    -- Reset safe zone to center of screen
    meteorShower.center_x = meteorShower.screen_width / 2  -- 400
    meteorShower.center_y = meteorShower.screen_height / 2 -- 300
    meteorShower.safe_zone_radius = 250 -- Start at max radius
    
    -- Set star direction for this round using seeded random
    meteorShower.star_direction = meteorShower.random:random() * 2 * math.pi
    
    -- Create game elements
    meteorShower.createStars()
    meteorShower.asteroids = {}
    meteorShower.music_asteroids = {}
    meteorShower.asteroid_spawn_timer = 0
    meteorShower.music_asteroid_spawn_timer = 0

    -- Override music handler onBeat function for Meteor Shower
    musicHandler.onBeat = meteorShower.handleBeat

    -- Initialize with seed if provided, otherwise generate one for host
    if args.seed then
        meteorShower.setSeed(args.seed)
        debugConsole.addMessage("[MeteorShower] Using provided seed: " .. args.seed)
    elseif args.isHost then
        local seed = os.time() + love.timer.getTime() * 10000
        meteorShower.setSeed(seed)
        debugConsole.addMessage("[MeteorShower] Host generated seed: " .. seed)
    end

    debugConsole.addMessage("[MeteorShower] Game loaded")
end

-- Function to select a new target point at random spots around the screen
function meteorShower.selectNewTarget()
    -- Move to completely random spots around the screen
    local margin = 100 -- Keep some margin from screen edges
    local target_x = meteorShower.random:random(margin, meteorShower.screen_width - margin)
    local target_y = meteorShower.random:random(margin, meteorShower.screen_height - margin)
    
    meteorShower.target_x = target_x
    meteorShower.target_y = target_y
    
    -- Calculate direction towards target
    local dx = target_x - meteorShower.center_x
    local dy = target_y - meteorShower.center_y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        meteorShower.safe_zone_direction = {dx / distance, dy / distance}
        meteorShower.direction_angle = math.atan2(dy, dx)
    end
    
    debugConsole.addMessage(string.format("[SafeZone] New target: (%.1f, %.1f), Direction: %.1f°", 
        target_x, target_y, math.deg(meteorShower.direction_angle)))
end

-- Handle beat events for music synchronization
function meteorShower.handleBeat()
    if not meteorShower.game_started then return end
    
    meteorShower.beat_count = meteorShower.beat_count + 1
    
    -- Change safety ring border color every beat
    meteorShower.current_color_index = meteorShower.current_color_index + 1
    if meteorShower.current_color_index > #meteorShower.safety_ring_colors then
        meteorShower.current_color_index = 1
    end
    
    -- Select new target point every 4 beats (instead of every beat) to allow flying across screen
    if meteorShower.beat_count % 4 == 0 then
        meteorShower.selectNewTarget()
    end
    
    -- Change music asteroid colors every beat
    meteorShower.music_asteroid_color_index = meteorShower.music_asteroid_color_index + 1
    if meteorShower.music_asteroid_color_index > #meteorShower.music_asteroid_colors then
        meteorShower.music_asteroid_color_index = 1
    end
    
    -- Calculate current speed multiplier for debug
    local base_speed = meteorShower.safe_zone_move_speed
    local raw_multiplier = 1.0 + (meteorShower.beat_count * 0.075) -- Moderate acceleration rate
    local max_multiplier = meteorShower.player.speed / base_speed
    local actual_multiplier = math.min(raw_multiplier, max_multiplier)
    
    debugConsole.addMessage(string.format("[MeteorShower] Beat %d - Border Color: %d, Target: (%.1f, %.1f), Speed: %.1fx (capped at %.1fx)", 
        meteorShower.beat_count, meteorShower.current_color_index, meteorShower.target_x, meteorShower.target_y, actual_multiplier, max_multiplier))
end

function meteorShower.setSeed(seed)
    meteorShower.seed = seed
    meteorShower.random:setSeed(seed)
    meteorShower.gameTime = 0
    meteorShower.nextMeteoroidTime = 0
    meteorShower.meteoroidSpawnPoints = {}
    meteorShower.musicAsteroidSpawnPoints = {}
    meteorShower.safeZoneTargets = {}
    
    -- Pre-calculate meteoroid spawn points (like laser game)
    local time = 0
    while time < meteorShower.timer do
        local spawnInfo = {
            time = time,
            side = meteorShower.random:random(1, 4), -- 1=top, 2=right, 3=bottom, 4=left
            speed = meteorShower.random:random(200, 250), -- Almost as fast as player (250 pixels/sec)
            size = meteorShower.random:random(25, 45)
        }
        table.insert(meteorShower.meteoroidSpawnPoints, spawnInfo)
        
        -- Spawn meteoroids more frequently (every 0.8-1.5 seconds)
        time = time + meteorShower.random:random(0.8, 1.5)
    end
    
    -- No power-ups in this version
    
    -- Pre-calculate music asteroid spawn points
    time = 0
    while time < meteorShower.timer do
        local musicSpawnInfo = {
            time = time,
            side = meteorShower.random:random(1, 4), -- 1=top, 2=right, 3=bottom, 4=left
            speed = meteorShower.random:random(200, 250), -- Same speed as regular asteroids
            size = meteorShower.random:random(30, 50) -- Larger than regular asteroids
        }
        table.insert(meteorShower.musicAsteroidSpawnPoints, musicSpawnInfo)
        
        -- Spawn music asteroids less frequently (every 2-4 seconds)
        time = time + meteorShower.random:random(2.0, 4.0)
    end
    
    -- Pre-calculate safe zone target positions
    time = 0
    while time < meteorShower.timer do
        local margin = math.max(50, meteorShower.safe_zone_radius + 50)
        local targetInfo = {
            time = time,
            x = meteorShower.random:random(margin, meteorShower.screen_width - margin),
            y = meteorShower.random:random(margin, meteorShower.screen_height - margin)
        }
        table.insert(meteorShower.safeZoneTargets, targetInfo)
        
        -- Change target every 2 seconds
        time = time + 2.0
    end
    
    debugConsole.addMessage(string.format(
        "[MeteorShower] Generated %d meteoroid, %d music asteroids, and %d safe zone targets with seed %d",
        #meteorShower.meteoroidSpawnPoints,
        #meteorShower.musicAsteroidSpawnPoints,
        #meteorShower.safeZoneTargets,
        seed
    ))
end

-- Power-ups removed from this version

function meteorShower.update(dt)
    -- Update music effects
    musicHandler.update(dt)
    
    if not meteorShower.game_started then
        meteorShower.start_timer = math.max(0, meteorShower.start_timer - dt)
        meteorShower.game_started = meteorShower.start_timer == 0
        
        -- In party mode, give extra time for players to get into safe zone
        if _G and _G.partyMode == true and meteorShower.game_started then
            -- Reset safe zone to max size when game starts in party mode
            meteorShower.safe_zone_radius = 250
            meteorShower.center_x = meteorShower.screen_width / 2
            meteorShower.center_y = meteorShower.screen_height / 2
            debugConsole.addMessage("[PartyMode] Game started - reset safe zone to max size")
            
            -- No elimination system - players respawn instead of being eliminated
        end
        
        return
    end

    if meteorShower.game_over then return end

    -- Only handle internal timer if not in party mode
    if not meteorShower.partyMode then
        meteorShower.timer = meteorShower.timer - dt
        
        if meteorShower.timer <= 0 then
            meteorShower.timer = 0
            meteorShower.game_over = true
        end
    end
    
    meteorShower.gameTime = meteorShower.gameTime + dt
    
    -- No elimination system - game only ends when timer runs out

    -- Update safe zone movement using pre-calculated targets (deterministic)
    if #meteorShower.safeZoneTargets > 0 and meteorShower.safeZoneTargets[1].time <= meteorShower.gameTime then
        local target = table.remove(meteorShower.safeZoneTargets, 1)
        meteorShower.target_x = target.x
        meteorShower.target_y = target.y
        debugConsole.addMessage("[SafeZone] New target: " .. meteorShower.target_x .. "," .. meteorShower.target_y)
    end
    
    -- Deterministic movement towards target (same calculation for all players)
    local base_speed = meteorShower.safe_zone_move_speed
    local beat_speed_multiplier = 1.0 + (meteorShower.beat_count * 0.075) -- Moderate acceleration rate
    -- Cap speed multiplier to ensure safe zone never moves faster than player (250 pixels/sec)
    local max_multiplier = meteorShower.player.speed / base_speed -- 250/50 = 5.0
    beat_speed_multiplier = math.min(beat_speed_multiplier, max_multiplier)
    local move_speed = base_speed * beat_speed_multiplier * dt
    local move_x = meteorShower.safe_zone_direction[1] * move_speed
    local move_y = meteorShower.safe_zone_direction[2] * move_speed
    
    meteorShower.center_x = meteorShower.center_x + move_x
    meteorShower.center_y = meteorShower.center_y + move_y
    
    -- Keep safe zone center within screen bounds with padding
    local padding = meteorShower.safe_zone_radius + 50
    meteorShower.center_x = math.max(padding, math.min(meteorShower.screen_width - padding, meteorShower.center_x))
    meteorShower.center_y = math.max(padding, math.min(meteorShower.screen_height - padding, meteorShower.center_y))
    
    -- Track radius changes for smooth transitions
    meteorShower.last_radius = meteorShower.safe_zone_radius

    -- Update random grow/shrink system
    if meteorShower.game_started then
        meteorShower.size_change_timer = meteorShower.size_change_timer + dt
        
        -- Check if it's time to change size direction
        if meteorShower.size_change_timer >= meteorShower.size_change_interval then
            meteorShower.size_change_timer = 0
            
            -- Use deterministic random for synchronization
            local time_seed = math.floor(meteorShower.gameTime * 10)
            meteorShower.random:setSeed(meteorShower.seed + time_seed)
            local random_value = meteorShower.random:random(0, 100)
            
            -- Always shrink - slower rate for more gradual shrinking
            meteorShower.current_change_rate = -15 -- pixels per second (slower shrinking)
            meteorShower.change_duration = meteorShower.random:random(2.0, 4.0) -- 2-4 seconds (longer duration)
            debugConsole.addMessage("[SafeZone] Starting to shrink for " .. meteorShower.change_duration .. " seconds")
            
            -- Restore original seed
            meteorShower.random:setSeed(meteorShower.seed)
        end
        
        -- Apply current size change if we have one
        if meteorShower.change_duration > 0 then
            meteorShower.change_duration = meteorShower.change_duration - dt
            
            -- Apply radius change
            local new_radius = meteorShower.safe_zone_radius + (meteorShower.current_change_rate * dt)
            
            -- Clamp to min/max bounds
            meteorShower.safe_zone_radius = math.max(meteorShower.min_radius, 
                                                   math.min(meteorShower.max_radius, new_radius))
            
            if meteorShower.change_duration <= 0 then
                meteorShower.current_change_rate = 0
                debugConsole.addMessage("[SafeZone] Size change completed. Current radius: " .. math.floor(meteorShower.safe_zone_radius))
            end
        end
    end

    -- Handle top-down movement (only if not eliminated)
    if not meteorShower.player_dropped then
        local moveSpeed = meteorShower.player.speed
        if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
            meteorShower.player.y = meteorShower.player.y - moveSpeed * dt
        end
        if love.keyboard.isDown('s') or love.keyboard.isDown('down') then
            meteorShower.player.y = meteorShower.player.y + moveSpeed * dt
        end
        if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
            meteorShower.player.x = meteorShower.player.x - moveSpeed * dt
        end
        if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
            meteorShower.player.x = meteorShower.player.x + moveSpeed * dt
        end
    end

    -- Keep player within screen bounds
    meteorShower.player.x = math.max(0, math.min(meteorShower.screen_width - meteorShower.player.width, meteorShower.player.x))
    meteorShower.player.y = math.max(0, math.min(meteorShower.screen_height - meteorShower.player.height, meteorShower.player.y))

    -- Send player position for multiplayer sync
    if _G.localPlayer and _G.localPlayer.id then
        local events = require("src.core.events")
        events.emit("player:battle_position", {
            id = _G.localPlayer.id,
            x = meteorShower.player.x,
            y = meteorShower.player.y,
            color = _G.localPlayer.color or meteorShower.playerColor
        })
    end

    -- Update laser angle based on mouse position
    local mx, my = love.mouse.getPosition()
    meteorShower.player.laser_angle = math.atan2(my - meteorShower.player.y - meteorShower.player.height/2, 
                                                mx - meteorShower.player.x - meteorShower.player.width/2)

    -- Check if player is outside safe zone (only after game has started)
    if meteorShower.game_started then
        -- Use deterministic safe zone data (same on all clients)
        local center_x, center_y, radius = meteorShower.center_x, meteorShower.center_y, meteorShower.safe_zone_radius
        
        local distance_from_center = math.sqrt(
            (meteorShower.player.x + meteorShower.player.width/2 - center_x)^2 +
            (meteorShower.player.y + meteorShower.player.height/2 - center_y)^2
        )
        
        -- Debug output for party mode
        if _G.partyMode == true then
            debugConsole.addMessage(string.format("[PartyMode] Player at (%.1f,%.1f), center at (%.1f,%.1f), radius=%.1f, distance=%.1f", 
                meteorShower.player.x, meteorShower.player.y, center_x, center_y, radius, distance_from_center))
        end
        
        if distance_from_center > radius and not meteorShower.player.is_invincible and not meteorShower.player_dropped then
            meteorShower.player_dropped = true
            meteorShower.death_count = meteorShower.death_count + 1 -- Increment death count
            meteorShower.hits = meteorShower.hits + 1  -- Track hits
            meteorShower.death_timer = 2 -- 2 second death animation
            meteorShower.death_shake = 15 -- Shake intensity
            meteorShower.respawn_timer = meteorShower.respawn_delay -- Start respawn timer
            meteorShower.sounds.death:clone():play() -- Play death sound
            debugConsole.addMessage("[MeteorShower] Player died outside safe zone! Death count: " .. meteorShower.death_count .. ". Respawning in " .. meteorShower.respawn_delay .. " seconds...")
        end
    end

    -- Handle respawn mechanism
    if meteorShower.player_dropped and meteorShower.respawn_timer > 0 then
        meteorShower.respawn_timer = meteorShower.respawn_timer - dt
        if meteorShower.respawn_timer <= 0 then
            -- Respawn player in center of safe zone
            meteorShower.player.x = meteorShower.center_x - meteorShower.player.width/2
            meteorShower.player.y = meteorShower.center_y - meteorShower.player.height/2
            meteorShower.player_dropped = false
            meteorShower.death_timer = 0
            meteorShower.death_shake = 0
            meteorShower.player.is_invincible = true
            meteorShower.player.invincibility_timer = 2 -- 2 seconds of invincibility after respawn
            debugConsole.addMessage("[MeteorShower] Player respawned in center of safe zone!")
        end
    end

    -- Update invincibility timer
    if meteorShower.player.is_invincible then
        meteorShower.player.invincibility_timer = meteorShower.player.invincibility_timer - dt
        if meteorShower.player.invincibility_timer <= 0 then
            meteorShower.player.is_invincible = false
        end
    end

    -- Update asteroids using deterministic spawning (like laser game)
    meteorShower.updateAsteroids(dt)
    
    -- Check asteroid collisions with player
    meteorShower.checkAsteroidCollisions()
    
    
    -- Update starfield
    meteorShower.updateStars(dt)
    
    -- Send periodic synchronization to keep clients in sync
    meteorShower.sync_timer = meteorShower.sync_timer + dt
    if meteorShower.sync_timer >= meteorShower.sync_interval then
        meteorShower.sync_timer = 0
        meteorShower.sendGameStateSync()
    end

    -- Update death timer and shake
    if meteorShower.death_timer > 0 then
        meteorShower.death_timer = meteorShower.death_timer - dt
        meteorShower.death_shake = meteorShower.death_shake * 0.85 -- Decay shake
        if meteorShower.death_timer <= 0 then
            meteorShower.death_timer = 0
            meteorShower.death_shake = 0
            meteorShower.death_animation_done = true
            -- Don't end game immediately - wait for all players to be eliminated or timer to run out
        end
    end

    -- Update scoring based on survival time
    meteorShower.current_round_score = meteorShower.current_round_score + math.floor(dt * 10)
    
        -- Store death count in players table for round win determination (least deaths wins)
        if _G.localPlayer and _G.localPlayer.id and _G.players and _G.players[_G.localPlayer.id] then
            _G.players[_G.localPlayer.id].battleDeaths = meteorShower.hits  -- Use hits for consistency
            _G.players[_G.localPlayer.id].battleScore = meteorShower.current_round_score
        end
        
        -- Send death count to server for winner determination
        if _G.safeSend and _G.server then
            _G.safeSend(_G.server, string.format("battle_deaths_sync,%d,%d", _G.localPlayer.id, meteorShower.death_count))
            debugConsole.addMessage("[MeteorShower] Sent death count to server: " .. meteorShower.death_count)
        end
    
    -- Handle spacebar input using isDown (like jump game)
    meteorShower.handleSpacebar()
end

function meteorShower.draw(playersTable, localPlayerId)
    -- Apply death shake effect
    if meteorShower.death_shake > 0 then
        local shake_x = meteorShower.random:random(-meteorShower.death_shake, meteorShower.death_shake)
        local shake_y = meteorShower.random:random(-meteorShower.death_shake, meteorShower.death_shake)
        love.graphics.translate(shake_x, shake_y)
    end
    
    -- Clear background
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, meteorShower.screen_width, meteorShower.screen_height)
    
    -- Draw starfield background
    meteorShower.drawStars()
    
    -- Draw safe zone (use synchronized data if available)
    meteorShower.drawSafeZone(playersTable)
    
    -- Draw game elements
    meteorShower.drawAsteroids()
    
    -- Draw other players
    if playersTable then
        for id, player in pairs(playersTable) do
            if id ~= localPlayerId and player.battleX and player.battleY then
                -- Draw ghost player body
                love.graphics.setColor(player.color[1], player.color[2], player.color[3], 0.5)
                love.graphics.rectangle('fill',
                    player.battleX,
                    player.battleY,
                    meteorShower.player.width,
                    meteorShower.player.height
                )
                
                -- Draw their face if available
                if player.facePoints then
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.draw(
                        player.facePoints,
                        player.battleX,
                        player.battleY,
                        0,
                        meteorShower.player.width/100,
                        meteorShower.player.height/100
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
    if not meteorShower.player_dropped then
        -- Draw invincibility effect if active
        if meteorShower.player.is_invincible then
                local invincibility_radius = 35
                
                -- Draw outer glow effect
                love.graphics.setColor(1, 1, 0, 0.3)
                love.graphics.circle('fill',
                    meteorShower.player.x + meteorShower.player.width/2,
                    meteorShower.player.y + meteorShower.player.height/2,
                    invincibility_radius + 5
                )
                
                -- Draw main invincibility bubble
                love.graphics.setColor(1, 1, 0, 0.2)
                love.graphics.circle('fill',
                    meteorShower.player.x + meteorShower.player.width/2,
                    meteorShower.player.y + meteorShower.player.height/2,
                    invincibility_radius
                )
                
                -- Draw border with pulsing effect
                local pulse = math.sin(love.timer.getTime() * 8) * 0.2 + 0.8
                love.graphics.setColor(1, 1, 0, pulse)
                love.graphics.setLineWidth(2)
                love.graphics.circle('line',
                    meteorShower.player.x + meteorShower.player.width/2,
                    meteorShower.player.y + meteorShower.player.height/2,
                    invincibility_radius
                )
                love.graphics.setLineWidth(1)
            end
            
        -- Draw player
        love.graphics.setColor(meteorShower.playerColor)
        love.graphics.rectangle('fill',
            meteorShower.player.x,
            meteorShower.player.y,
            meteorShower.player.width,
            meteorShower.player.height
        )
        
        -- Draw face
        if playersTable and playersTable[localPlayerId] and playersTable[localPlayerId].facePoints then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                playersTable[localPlayerId].facePoints,
                meteorShower.player.x,
                meteorShower.player.y,
                0,
                meteorShower.player.width/100,
                meteorShower.player.height/100
            )
        end
    else
        -- Draw death indicator with respawn countdown (visual only, no text)
        love.graphics.setColor(1, 0, 0, 0.7)
        love.graphics.rectangle('fill', meteorShower.player.x, meteorShower.player.y, meteorShower.player.width, meteorShower.player.height)
    end
    
    -- Draw UI elements
    meteorShower.drawUI(playersTable, localPlayerId)
end



function meteorShower.drawSafeZone(playersTable)
    -- Use deterministic safe zone data (same on all clients)
    local center_x, center_y, radius = meteorShower.center_x, meteorShower.center_y, meteorShower.safe_zone_radius
    
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
        local current_color = meteorShower.safety_ring_colors[meteorShower.current_color_index]
        local r, g, b = current_color[1], current_color[2], current_color[3]
        love.graphics.setColor(r, g, b, 0.8) -- Bright border with current beat color
        love.graphics.circle('line', 0, 0, radius)
        
        love.graphics.pop()
    end
    
    -- No warning text for minimum safe zone size
end

function meteorShower.drawUI(playersTable, localPlayerId)
    -- Draw hits counter
    gameUI.drawHitCounter(meteorShower.hits, 10, 10)
    
    -- Invincibility indicator
    if meteorShower.player.is_invincible then
        gameUI.drawInvincibility(meteorShower.player.invincibility_timer)
    end
    
    -- Tab score overlay
    if meteorShower.showTabScores and playersTable then
        gameUI.drawTabScores(playersTable, localPlayerId, "meteorshower")
    end
    
    if not meteorShower.game_started then
        love.graphics.printf('Get Ready: ' .. math.ceil(meteorShower.start_timer), 
            0, meteorShower.screen_height / 2 - 50, meteorShower.screen_width, 'center')
    end
    
    if meteorShower.game_over then
        love.graphics.printf('Game Over - You were caught outside the safe zone!', 
            0, meteorShower.screen_height / 2 - 50, meteorShower.screen_width, 'center')
    end
end


function meteorShower.checkCollision(obj1, obj2)
    return obj1.x < obj2.x + obj2.width and
            obj1.x + obj1.width > obj2.x and
            obj1.y < obj2.y + obj2.height and
            obj1.y + obj1.height > obj2.y
end


function meteorShower.createStars()
    meteorShower.stars = {}
    -- Create a moving starfield with uniform direction and color using seeded random
    for i = 1, 150 do
        table.insert(meteorShower.stars, {
            x = meteorShower.random:random(0, meteorShower.screen_width),
            y = meteorShower.random:random(0, meteorShower.screen_height),
            size = meteorShower.random:random(1, 3),
            speed = meteorShower.random:random(20, 60) -- Movement speed in pixels per second
            -- All stars use the global star_direction
        })
    end
end

function meteorShower.updateStars(dt)
    for i = #meteorShower.stars, 1, -1 do
        local star = meteorShower.stars[i]
        
        -- Move star in the global direction
        star.x = star.x + math.cos(meteorShower.star_direction) * star.speed * dt
        star.y = star.y + math.sin(meteorShower.star_direction) * star.speed * dt
        
        -- Wrap around screen edges
        if star.x < 0 then
            star.x = meteorShower.screen_width
        elseif star.x > meteorShower.screen_width then
            star.x = 0
        end
        
        if star.y < 0 then
            star.y = meteorShower.screen_height
        elseif star.y > meteorShower.screen_height then
            star.y = 0
        end
    end
end

-- Power-up functions removed

function meteorShower.drawStars()
    for _, star in ipairs(meteorShower.stars) do
        love.graphics.setColor(1, 1, 1, 0.8) -- Uniform white color with slight transparency
        love.graphics.circle('fill', star.x, star.y, star.size)
    end
end

-- Power-up and laser drawing functions removed


function meteorShower.keypressed(key)
    print("[MeteorShower] Key pressed: " .. key)
    debugConsole.addMessage("[MeteorShower] Key pressed: " .. key)
    -- No special key handling needed without power-ups
end

function meteorShower.handleSpacebar()
    -- No spacebar functionality needed without power-ups
end

function meteorShower.mousepressed(x, y, button)
    -- No mouse input needed without power-ups
end

function meteorShower.keyreleased(key)
    meteorShower.keysPressed[key] = false
end

-- All power-up related functions removed

function meteorShower.updateAsteroids(dt)
    -- Check if we need to spawn any regular asteroids based on pre-calculated spawn points
    while #meteorShower.meteoroidSpawnPoints > 0 and meteorShower.meteoroidSpawnPoints[1].time <= meteorShower.gameTime do
        meteorShower.spawnAsteroidFromSpawnPoint(table.remove(meteorShower.meteoroidSpawnPoints, 1))
    end
    
    -- Check if we need to spawn any music asteroids based on pre-calculated spawn points
    while #meteorShower.musicAsteroidSpawnPoints > 0 and meteorShower.musicAsteroidSpawnPoints[1].time <= meteorShower.gameTime do
        meteorShower.spawnMusicAsteroidFromSpawnPoint(table.remove(meteorShower.musicAsteroidSpawnPoints, 1))
    end
    
    -- Update existing regular asteroids
    for i = #meteorShower.asteroids, 1, -1 do
        local asteroid = meteorShower.asteroids[i]
        
        -- Apply deterministic speed multiplier based on game time
        local speedMultiplier = 1
        -- Speed up after 10 seconds of gameplay
        if meteorShower.gameTime > 10 then
            speedMultiplier = 1.5 -- 50% faster after 10 seconds
        end
        
        asteroid.x = asteroid.x + asteroid.vx * dt * speedMultiplier
        asteroid.y = asteroid.y + asteroid.vy * dt * speedMultiplier
        
        -- Bounce asteroids off screen edges instead of removing them
        if asteroid.x < -50 then
            asteroid.x = -50
            asteroid.vx = math.abs(asteroid.vx) -- Bounce right
        elseif asteroid.x > meteorShower.screen_width + 50 then
            asteroid.x = meteorShower.screen_width + 50
            asteroid.vx = -math.abs(asteroid.vx) -- Bounce left
        end
        
        if asteroid.y < -50 then
            asteroid.y = -50
            asteroid.vy = math.abs(asteroid.vy) -- Bounce down
        elseif asteroid.y > meteorShower.screen_height + 50 then
            asteroid.y = meteorShower.screen_height + 50
            asteroid.vy = -math.abs(asteroid.vy) -- Bounce up
        end
    end
    
    -- Update music-synced asteroids
    for i = #meteorShower.music_asteroids, 1, -1 do
        local asteroid = meteorShower.music_asteroids[i]
        
        -- Music asteroids move at consistent speed (no speed multiplier)
        asteroid.x = asteroid.x + asteroid.vx * dt
        asteroid.y = asteroid.y + asteroid.vy * dt
        
        -- Bounce music asteroids off screen edges instead of removing them
        if asteroid.x < -50 then
            asteroid.x = -50
            asteroid.vx = math.abs(asteroid.vx) -- Bounce right
        elseif asteroid.x > meteorShower.screen_width + 50 then
            asteroid.x = meteorShower.screen_width + 50
            asteroid.vx = -math.abs(asteroid.vx) -- Bounce left
        end
        
        if asteroid.y < -50 then
            asteroid.y = -50
            asteroid.vy = math.abs(asteroid.vy) -- Bounce down
        elseif asteroid.y > meteorShower.screen_height + 50 then
            asteroid.y = meteorShower.screen_height + 50
            asteroid.vy = -math.abs(asteroid.vy) -- Bounce up
        end
    end
end

function meteorShower.spawnAsteroidFromSpawnPoint(spawnInfo)
    local asteroid = {}
    local side = spawnInfo.side
    local speed = spawnInfo.speed
    local size = spawnInfo.size
    
    -- Create a local random generator for this specific asteroid to ensure determinism
    local asteroidRng = love.math.newRandomGenerator(meteorShower.seed + math.floor(spawnInfo.time * 1000))
    
    if side == 1 then -- Top
        asteroid.x = asteroidRng:random(0, meteorShower.screen_width)
        asteroid.y = -50
        asteroid.vx = asteroidRng:random(-speed/4, speed/4)
        asteroid.vy = asteroidRng:random(speed/4, speed)
    elseif side == 2 then -- Right
        asteroid.x = meteorShower.screen_width + 50
        asteroid.y = asteroidRng:random(0, meteorShower.screen_height)
        asteroid.vx = asteroidRng:random(-speed, -speed/4)
        asteroid.vy = asteroidRng:random(-speed/4, speed/4)
    elseif side == 3 then -- Bottom
        asteroid.x = asteroidRng:random(0, meteorShower.screen_width)
        asteroid.y = meteorShower.screen_height + 50
        asteroid.vx = asteroidRng:random(-speed/4, speed/4)
        asteroid.vy = asteroidRng:random(-speed, -speed/4)
    else -- Left
        asteroid.x = -50
        asteroid.y = asteroidRng:random(0, meteorShower.screen_height)
        asteroid.vx = asteroidRng:random(speed/4, speed)
        asteroid.vy = asteroidRng:random(-speed/4, speed/4)
    end
    
    asteroid.size = size
    asteroid.color = {0.5, 0.5, 0.5} -- Consistent gray color
    asteroid.points = {} -- Store irregular shape points
    asteroid.rotation = asteroidRng:random() * 2 * math.pi
    asteroid.rotation_speed = asteroidRng:random(-2, 2)
    meteorShower.generateAsteroidShapeWithRng(asteroid, asteroidRng) -- Generate the irregular shape with local RNG
    
    table.insert(meteorShower.asteroids, asteroid)
end

function meteorShower.spawnAsteroid()
    local asteroid = {}
    local side = meteorShower.random:random(1, 4) -- 1=top, 2=right, 3=bottom, 4=left
    
    if side == 1 then -- Top
        asteroid.x = meteorShower.random:random(0, meteorShower.screen_width)
        asteroid.y = -50
        asteroid.vx = meteorShower.random:random() * (meteorShower.asteroid_speed/2) - meteorShower.asteroid_speed/4
        asteroid.vy = meteorShower.random:random() * (meteorShower.asteroid_speed*3/4) + meteorShower.asteroid_speed/4
    elseif side == 2 then -- Right
        asteroid.x = meteorShower.screen_width + 50
        asteroid.y = meteorShower.random:random(0, meteorShower.screen_height)
        asteroid.vx = -(meteorShower.random:random() * (meteorShower.asteroid_speed*3/4) + meteorShower.asteroid_speed/4)
        asteroid.vy = meteorShower.random:random() * (meteorShower.asteroid_speed/2) - meteorShower.asteroid_speed/4
    elseif side == 3 then -- Bottom
        asteroid.x = meteorShower.random:random(0, meteorShower.screen_width)
        asteroid.y = meteorShower.screen_height + 50
        asteroid.vx = meteorShower.random:random() * (meteorShower.asteroid_speed/2) - meteorShower.asteroid_speed/4
        asteroid.vy = -(meteorShower.random:random() * (meteorShower.asteroid_speed*3/4) + meteorShower.asteroid_speed/4)
    else -- Left
        asteroid.x = -50
        asteroid.y = meteorShower.random:random(0, meteorShower.screen_height)
        asteroid.vx = meteorShower.random:random() * (meteorShower.asteroid_speed*3/4) + meteorShower.asteroid_speed/4
        asteroid.vy = meteorShower.random:random() * (meteorShower.asteroid_speed/2) - meteorShower.asteroid_speed/4
    end
    
    asteroid.size = meteorShower.random:random(25, 45)
    asteroid.color = {0.5, 0.5, 0.5} -- Consistent gray color
    asteroid.points = {} -- Store irregular shape points
    meteorShower.generateAsteroidShape(asteroid) -- Generate the irregular shape
    
    table.insert(meteorShower.asteroids, asteroid)
end

function meteorShower.spawnMusicAsteroidFromSpawnPoint(spawnInfo)
    local asteroid = {}
    local side = spawnInfo.side
    local speed = spawnInfo.speed
    local size = spawnInfo.size
    
    -- Create a local random generator for this specific asteroid to ensure determinism
    local asteroidRng = love.math.newRandomGenerator(meteorShower.seed + math.floor(spawnInfo.time * 1000) + 999999)
    
    if side == 1 then -- Top
        asteroid.x = asteroidRng:random(0, meteorShower.screen_width)
        asteroid.y = -50
        asteroid.vx = asteroidRng:random(-speed/4, speed/4)
        asteroid.vy = asteroidRng:random(speed/4, speed)
    elseif side == 2 then -- Right
        asteroid.x = meteorShower.screen_width + 50
        asteroid.y = asteroidRng:random(0, meteorShower.screen_height)
        asteroid.vx = asteroidRng:random(-speed, -speed/4)
        asteroid.vy = asteroidRng:random(-speed/4, speed/4)
    elseif side == 3 then -- Bottom
        asteroid.x = asteroidRng:random(0, meteorShower.screen_width)
        asteroid.y = meteorShower.screen_height + 50
        asteroid.vx = asteroidRng:random(-speed/4, speed/4)
        asteroid.vy = asteroidRng:random(-speed, -speed/4)
    else -- Left
        asteroid.x = -50
        asteroid.y = asteroidRng:random(0, meteorShower.screen_height)
        asteroid.vx = asteroidRng:random(speed/4, speed)
        asteroid.vy = asteroidRng:random(-speed/4, speed/4)
    end
    
    asteroid.size = size
    -- Use deterministic color based on spawn time instead of music beat
    local colorIndex = (math.floor(spawnInfo.time * 2) % #meteorShower.music_asteroid_colors) + 1
    asteroid.color = meteorShower.music_asteroid_colors[colorIndex]
    asteroid.points = {} -- Store irregular shape points
    asteroid.is_music_asteroid = true -- Mark as music asteroid
    asteroid.rotation = asteroidRng:random() * 2 * math.pi
    asteroid.rotation_speed = asteroidRng:random(-2, 2)
    meteorShower.generateAsteroidShapeWithRng(asteroid, asteroidRng) -- Generate the irregular shape with local RNG
    
    table.insert(meteorShower.music_asteroids, asteroid)
    debugConsole.addMessage("[MusicAsteroid] Spawned music-synced asteroid at time " .. spawnInfo.time)
end

function meteorShower.generateAsteroidShape(asteroid)
    -- Generate irregular asteroid shape with 6-8 points using deterministic random
    local num_points = meteorShower.random:random(6, 8)
    asteroid.points = {}
    
    for i = 1, num_points do
        local angle = (i - 1) * (2 * math.pi / num_points)
        local radius_variation = meteorShower.random:random(0.7, 1.1) -- Make it irregular but not too extreme
        local base_radius = asteroid.size / 2
        local x = math.cos(angle) * base_radius * radius_variation
        local y = math.sin(angle) * base_radius * radius_variation
        
        -- Add some deterministic jitter to make it more chaotic
        local jitter = asteroid.size / 10
        x = x + meteorShower.random:random(-jitter, jitter)
        y = y + meteorShower.random:random(-jitter, jitter)
        
        table.insert(asteroid.points, x)
        table.insert(asteroid.points, y)
    end
end

function meteorShower.generateAsteroidShapeWithRng(asteroid, rng)
    -- Generate irregular asteroid shape with 6-8 points using provided RNG
    local num_points = rng:random(6, 8)
    asteroid.points = {}
    
    for i = 1, num_points do
        local angle = (i - 1) * (2 * math.pi / num_points)
        local radius_variation = rng:random(0.7, 1.1) -- Make it irregular but not too extreme
        local base_radius = asteroid.size / 2
        local x = math.cos(angle) * base_radius * radius_variation
        local y = math.sin(angle) * base_radius * radius_variation
        
        -- Add some deterministic jitter to make it more chaotic
        local jitter = asteroid.size / 10
        x = x + rng:random(-jitter, jitter)
        y = y + rng:random(-jitter, jitter)
        
        table.insert(asteroid.points, x)
        table.insert(asteroid.points, y)
    end
end

function meteorShower.drawAsteroids()
    -- Draw regular asteroids (unchanged)
    for _, asteroid in ipairs(meteorShower.asteroids) do
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
    for i, asteroid in ipairs(meteorShower.music_asteroids) do
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

function meteorShower.checkAsteroidCollisions()
    -- Check collisions with regular asteroids
    for _, asteroid in ipairs(meteorShower.asteroids) do
        -- Check collision with player
        if meteorShower.checkCollision(meteorShower.player, {
            x = asteroid.x - asteroid.size/2,
            y = asteroid.y - asteroid.size/2,
            width = asteroid.size,
            height = asteroid.size
        }) then
            if not meteorShower.player.is_invincible and not meteorShower.player_dropped then
                meteorShower.player_dropped = true
                meteorShower.death_count = meteorShower.death_count + 1 -- Increment death count
                meteorShower.hits = meteorShower.hits + 1  -- Track hits
                meteorShower.death_timer = 2 -- 2 second death animation
                meteorShower.death_shake = 15 -- Shake intensity
                meteorShower.respawn_timer = meteorShower.respawn_delay -- Start respawn timer
                meteorShower.sounds.death:clone():play() -- Play death sound
                debugConsole.addMessage("[MeteorShower] Player hit by regular asteroid! Death count: " .. meteorShower.death_count .. ". Respawning in " .. meteorShower.respawn_delay .. " seconds...")
            end
        end
    end
    
    -- Check collisions with music-synced asteroids
    for _, asteroid in ipairs(meteorShower.music_asteroids) do
        -- Check collision with player
        if meteorShower.checkCollision(meteorShower.player, {
            x = asteroid.x - asteroid.size/2,
            y = asteroid.y - asteroid.size/2,
            width = asteroid.size,
            height = asteroid.size
        }) then
            if not meteorShower.player.is_invincible and not meteorShower.player_dropped then
                meteorShower.player_dropped = true
                meteorShower.death_count = meteorShower.death_count + 1 -- Increment death count
                meteorShower.hits = meteorShower.hits + 1  -- Track hits
                meteorShower.death_timer = 2 -- 2 second death animation
                meteorShower.death_shake = 15 -- Shake intensity
                meteorShower.respawn_timer = meteorShower.respawn_delay -- Start respawn timer
                meteorShower.sounds.death:clone():play() -- Play death sound
                debugConsole.addMessage("[MeteorShower] Player hit by music asteroid! Death count: " .. meteorShower.death_count .. ". Respawning in " .. meteorShower.respawn_delay .. " seconds...")
            end
        end
    end
end

-- Laser collisions removed - no power-ups in this version

function meteorShower.reset()
    meteorShower.load()
end

function meteorShower.setPlayerColor(color)
    meteorShower.playerColor = color
end

function meteorShower.sendGameStateSync()
    -- Only send sync from host
    if _G and _G.returnState == "hosting" and _G.serverClients then
        -- Compact message format for high-frequency updates
        local message = string.format("bsync,%.1f,%.1f,%.1f,%.1f,%d,%.3f,%d,%.1f,%.1f,%d,%.1f,%.1f", 
            meteorShower.gameTime, 
            meteorShower.center_x, 
            meteorShower.center_y, 
            meteorShower.safe_zone_radius,
            meteorShower.current_color_index,
            meteorShower.direction_angle,
            meteorShower.beat_count,
            meteorShower.current_change_rate,
            meteorShower.change_duration,
            meteorShower.music_asteroid_color_index,
            meteorShower.target_x,
            meteorShower.target_y)
        
        for _, client in ipairs(_G.serverClients) do
            -- Use the global safeSend function
            if _G.safeSend then
                _G.safeSend(client, message)
            end
        end
    end
end

function meteorShower.keypressed(key)
    if key == "tab" then
        meteorShower.showTabScores = true
    end
end

function meteorShower.keyreleased(key)
    if key == "tab" then
        meteorShower.showTabScores = false
    end
end

return meteorShower

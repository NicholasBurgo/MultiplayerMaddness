local particleCollector = {}
particleCollector.name = "particlecollector"
local debugConsole = require "src.core.debugconsole"
local musicHandler = require "src.game.systems.musichandler"
local gameUI = require "src.game.systems.gameui"

-- Sound effects
particleCollector.sounds = {
    collect_good = love.audio.newSource("sounds/jumpgame-jump.mp3", "static"),
    collect_bad = love.audio.newSource("sounds/death.mp3", "static"),
    spawn_particle = love.audio.newSource("sounds/laser.mp3", "static")
}

-- Set sound volumes
particleCollector.sounds.collect_good:setVolume(0.4)
particleCollector.sounds.collect_bad:setVolume(0.3)
particleCollector.sounds.spawn_particle:setVolume(0.2)

-- Game state
particleCollector.game_over = false
particleCollector.current_round_score = 0
particleCollector.playerColor = {1, 1, 1}
particleCollector.screen_width = 800  -- Fixed base resolution
particleCollector.screen_height = 600  -- Fixed base resolution
particleCollector.partyMode = false  -- Party mode flag
particleCollector.showTabScores = false  -- Tab key pressed

-- Seed-based synchronization
particleCollector.seed = 0
particleCollector.random = love.math.newRandomGenerator()
particleCollector.gameTime = 0

-- Game settings
particleCollector.timer = 15 -- 15 seconds for now
particleCollector.player_size = 30
particleCollector.arena_size = 750
particleCollector.arena_offset_x = 0
particleCollector.arena_offset_y = 0

-- Player settings
particleCollector.player = {
    x = 400,
    y = 300,
    width = 30,
    height = 30,
    speed = 250,
    score = 0,
    is_invincible = false,
    invincibility_timer = 0
}

-- Particle system
particleCollector.particles = {}
particleCollector.good_particles = {}
particleCollector.bad_particles = {}
particleCollector.collection_particles = {}

-- Particle properties
particleCollector.particle_lifetime = 1.0
particleCollector.particle_speed = 100
particleCollector.particle_size = 4

-- Game phases for breathing room
particleCollector.phase = "calm"  -- "calm" or "chaos"
particleCollector.phase_timer = 0
particleCollector.calm_duration = 3.0  -- 3 seconds of calm collection
particleCollector.chaos_duration = 4.0  -- 4 seconds of chaos with chasing bad particles

-- Particle spawn settings
particleCollector.spawn_timer = 0
particleCollector.spawn_interval = 0.3  -- Spawn particles every 0.3 seconds (much faster)
particleCollector.good_particle_chance = 0.6  -- 60% chance for good particles (more bad particles)
particleCollector.spawn_count = 3  -- Spawn 3 particles at a time

-- Bad particle chase behavior
particleCollector.bad_particle_speed = 80
particleCollector.bad_particle_acceleration = 120

-- Star field background
particleCollector.stars = {}
particleCollector.star_direction = 0

function particleCollector.createParticles(x, y, color, count)
    count = count or 8
    for i = 1, count do
        local angle = (i / count) * math.pi * 2
        local speed = particleCollector.random:random(50, particleCollector.particle_speed)
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = particleCollector.particle_lifetime,
            maxLife = particleCollector.particle_lifetime,
            size = particleCollector.random:random(2, particleCollector.particle_size),
            color = {color[1], color[2], color[3]}
        }
        table.insert(particleCollector.collection_particles, particle)
    end
end

function particleCollector.updateParticles(dt)
    -- Update collection particles
    for i = #particleCollector.collection_particles, 1, -1 do
        local particle = particleCollector.collection_particles[i]
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.life = particle.life - dt
        
        if particle.life <= 0 then
            table.remove(particleCollector.collection_particles, i)
        end
    end
end

function particleCollector.createStars()
    particleCollector.stars = {}
    -- Create a moving starfield with uniform direction using seeded random
    for i = 1, 100 do
        table.insert(particleCollector.stars, {
            x = particleCollector.random:random(0, particleCollector.screen_width),
            y = particleCollector.random:random(0, particleCollector.screen_height),
            size = particleCollector.random:random(1, 2),
            speed = particleCollector.random:random(15, 40)
        })
    end
end

function particleCollector.updateStars(dt)
    for i = #particleCollector.stars, 1, -1 do
        local star = particleCollector.stars[i]
        
        -- Move star in the global direction
        star.x = star.x + math.cos(particleCollector.star_direction) * star.speed * dt
        star.y = star.y + math.sin(particleCollector.star_direction) * star.speed * dt
        
        -- Wrap around screen edges
        if star.x < 0 then
            star.x = particleCollector.screen_width
        elseif star.x > particleCollector.screen_width then
            star.x = 0
        end
        
        if star.y < 0 then
            star.y = particleCollector.screen_height
        elseif star.y > particleCollector.screen_height then
            star.y = 0
        end
    end
end

function particleCollector.drawStars()
    for _, star in ipairs(particleCollector.stars) do
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.circle('fill', star.x, star.y, star.size)
    end
end

function particleCollector.spawnParticle()
    -- Spawn multiple particles at once
    for i = 1, particleCollector.spawn_count do
        local is_good = particleCollector.random:random() < particleCollector.good_particle_chance
        local particle = {
            x = particleCollector.random:random(50, particleCollector.arena_size - 50),
            y = particleCollector.random:random(50, particleCollector.arena_size - 50),
            size = particleCollector.random:random(6, 14),
            life = 12.0,  -- Particles last 12 seconds
            maxLife = 12.0,
            is_good = is_good,
            vx = 0,
            vy = 0,
            target_x = 0,
            target_y = 0,
            chase_speed = particleCollector.bad_particle_speed
        }
        
        if is_good then
            -- Good particles: green, move erratically
            particle.color = {0.2, 1, 0.2}
            particle.vx = particleCollector.random:random(-80, 80)
            particle.vy = particleCollector.random:random(-80, 80)
            table.insert(particleCollector.good_particles, particle)
        else
            -- Bad particles: red, will chase player
            particle.color = {1, 0.2, 0.2}
            particle.vx = particleCollector.random:random(-40, 40)
            particle.vy = particleCollector.random:random(-40, 40)
            table.insert(particleCollector.bad_particles, particle)
        end
    end
    
    -- Play spawn sound occasionally
    if particleCollector.random:random() < 0.2 then
        particleCollector.sounds.spawn_particle:clone():play()
    end
end

function particleCollector.updateParticleMovement(dt)
    -- Update good particles (erratic movement)
    for i = #particleCollector.good_particles, 1, -1 do
        local particle = particleCollector.good_particles[i]
        
        -- Erratic movement - change direction randomly
        if particleCollector.random:random() < 0.1 then
            particle.vx = particleCollector.random:random(-80, 80)
            particle.vy = particleCollector.random:random(-80, 80)
        end
        
        -- Apply movement
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        
        -- Bounce off arena walls
        if particle.x <= particle.size then
            particle.x = particle.size
            particle.vx = math.abs(particle.vx)
        elseif particle.x >= particleCollector.arena_size - particle.size then
            particle.x = particleCollector.arena_size - particle.size
            particle.vx = -math.abs(particle.vx)
        end
        
        if particle.y <= particle.size then
            particle.y = particle.size
            particle.vy = math.abs(particle.vy)
        elseif particle.y >= particleCollector.arena_size - particle.size then
            particle.y = particleCollector.arena_size - particle.size
            particle.vy = -math.abs(particle.vy)
        end
        
        -- Remove expired particles
        particle.life = particle.life - dt
        if particle.life <= 0 then
            table.remove(particleCollector.good_particles, i)
        end
    end
    
    -- Update bad particles (chase behavior during chaos phase)
    for i = #particleCollector.bad_particles, 1, -1 do
        local particle = particleCollector.bad_particles[i]
        
        if particleCollector.phase == "chaos" then
            -- Chase player during chaos phase
            local dx = particleCollector.player.x - particleCollector.arena_offset_x - particle.x
            local dy = particleCollector.player.y - particleCollector.arena_offset_y - particle.y
            local distance = math.sqrt(dx^2 + dy^2)
            
            if distance > 0 then
                -- Normalize direction and apply chase speed
                local chase_force_x = (dx / distance) * particle.chase_speed
                local chase_force_y = (dy / distance) * particle.chase_speed
                
                -- Apply acceleration towards player
                particle.vx = particle.vx + chase_force_x * particleCollector.bad_particle_acceleration * dt
                particle.vy = particle.vy + chase_force_y * particleCollector.bad_particle_acceleration * dt
                
                -- Limit speed
                local speed = math.sqrt(particle.vx^2 + particle.vy^2)
                if speed > particle.chase_speed * 1.5 then
                    particle.vx = particle.vx * (particle.chase_speed * 1.5 / speed)
                    particle.vy = particle.vy * (particle.chase_speed * 1.5 / speed)
                end
            end
        else
            -- Calm phase - move erratically
            if particleCollector.random:random() < 0.1 then
                particle.vx = particleCollector.random:random(-40, 40)
                particle.vy = particleCollector.random:random(-40, 40)
            end
        end
        
        -- Apply movement
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        
        -- Bounce off arena walls
        if particle.x <= particle.size then
            particle.x = particle.size
            particle.vx = math.abs(particle.vx)
        elseif particle.x >= particleCollector.arena_size - particle.size then
            particle.x = particleCollector.arena_size - particle.size
            particle.vx = -math.abs(particle.vx)
        end
        
        if particle.y <= particle.size then
            particle.y = particle.size
            particle.vy = math.abs(particle.vy)
        elseif particle.y >= particleCollector.arena_size - particle.size then
            particle.y = particleCollector.arena_size - particle.size
            particle.vy = -math.abs(particle.vy)
        end
        
        -- Remove expired particles
        particle.life = particle.life - dt
        if particle.life <= 0 then
            table.remove(particleCollector.bad_particles, i)
        end
    end
end

function particleCollector.checkCollisions()
    -- Check collision with good particles
    for i = #particleCollector.good_particles, 1, -1 do
        local particle = particleCollector.good_particles[i]
        local dx = particleCollector.player.x - particleCollector.arena_offset_x - particle.x
        local dy = particleCollector.player.y - particleCollector.arena_offset_y - particle.y
        local distance = math.sqrt(dx^2 + dy^2)
        
        if distance < (particleCollector.player_size/2 + particle.size) then
            -- Collected good particle - add to particle count
            particleCollector.player.score = particleCollector.player.score + 1
            particleCollector.current_round_score = particleCollector.current_round_score + 1
            
            -- Create collection effect
            particleCollector.createParticles(
                particle.x + particleCollector.arena_offset_x, 
                particle.y + particleCollector.arena_offset_y, 
                {0.2, 1, 0.2}, 
                6
            )
            
            -- Play sound
            particleCollector.sounds.collect_good:clone():play()
            
            -- Remove particle
            table.remove(particleCollector.good_particles, i)
            
            debugConsole.addMessage("[ParticleCollector] Collected good particle! Particle count: " .. particleCollector.player.score)
        end
    end
    
    -- Check collision with bad particles
    for i = #particleCollector.bad_particles, 1, -1 do
        local particle = particleCollector.bad_particles[i]
        local dx = particleCollector.player.x - particleCollector.arena_offset_x - particle.x
        local dy = particleCollector.player.y - particleCollector.arena_offset_y - particle.y
        local distance = math.sqrt(dx^2 + dy^2)
        
        if distance < (particleCollector.player_size/2 + particle.size) and not particleCollector.player.is_invincible then
            -- Hit bad particle - remove from particle count
            particleCollector.player.score = math.max(0, particleCollector.player.score - 1)
            particleCollector.current_round_score = math.max(0, particleCollector.current_round_score - 1)
            
            -- Create hit effect
            particleCollector.createParticles(
                particle.x + particleCollector.arena_offset_x, 
                particle.y + particleCollector.arena_offset_y, 
                {1, 0.2, 0.2}, 
                8
            )
            
            -- Play sound
            particleCollector.sounds.collect_bad:clone():play()
            
            -- Remove particle
            table.remove(particleCollector.bad_particles, i)
            
            -- Brief invincibility
            particleCollector.player.is_invincible = true
            particleCollector.player.invincibility_timer = 0.5
            
            debugConsole.addMessage("[ParticleCollector] Hit bad particle! Particle count: " .. particleCollector.player.score)
        end
    end
end

function particleCollector.load(args)
    args = args or {}
    particleCollector.partyMode = args.partyMode or false
    
    debugConsole.addMessage("[ParticleCollector] Loading particle collector game")
    debugConsole.addMessage("[ParticleCollector] Party mode status: " .. tostring(particleCollector.partyMode))
    
    -- Calculate arena positioning
    local base_width = _G.BASE_WIDTH or 800
    local base_height = _G.BASE_HEIGHT or 600
    particleCollector.arena_offset_x = (base_width - particleCollector.arena_size) / 2
    particleCollector.arena_offset_y = (base_height - particleCollector.arena_size) / 2
    
    -- Reset game state
    particleCollector.game_over = false
    particleCollector.current_round_score = 0
    particleCollector.timer = 15
    particleCollector.gameTime = 0
    particleCollector.collection_particles = {}
    particleCollector.good_particles = {}
    particleCollector.bad_particles = {}
    
    -- Reset player
    particleCollector.player = {
        x = particleCollector.arena_offset_x + particleCollector.arena_size / 2,
        y = particleCollector.arena_offset_y + particleCollector.arena_size / 2,
        width = 30,
        height = 30,
        speed = 250,
        score = 0,
        is_invincible = false,
        invincibility_timer = 0
    }
    
    -- Set player color if available from args
    if args.players and args.localPlayerId ~= nil then
        local localPlayer = args.players[args.localPlayerId]
        if localPlayer and localPlayer.color then
            particleCollector.playerColor = localPlayer.color
        end
    end
    
    -- Initialize phase system
    particleCollector.phase = "calm"
    particleCollector.phase_timer = 0
    particleCollector.spawn_timer = 0
    
    -- Set star direction for this round using seeded random
    particleCollector.star_direction = particleCollector.random:random() * 2 * math.pi
    
    -- Create star field
    particleCollector.createStars()
    
    -- Add music effects
    musicHandler.addEffect("particle_pulse", "beatPulse", {
        baseColor = {1, 1, 1},
        intensity = 0.4,
        duration = 0.15
    })
    
    -- Initialize with seed if provided, otherwise generate one for host
    if args.seed then
        particleCollector.setSeed(args.seed)
        debugConsole.addMessage("[ParticleCollector] Using provided seed: " .. args.seed)
    elseif args.isHost then
        local seed = os.time() + love.timer.getTime() * 10000
        particleCollector.setSeed(seed)
        debugConsole.addMessage("[ParticleCollector] Host generated seed: " .. seed)
    end
    
    debugConsole.addMessage("[ParticleCollector] Game loaded")
end

function particleCollector.setSeed(seed)
    particleCollector.seed = seed
    particleCollector.random:setSeed(seed)
    particleCollector.gameTime = 0
    debugConsole.addMessage(string.format("[ParticleCollector] Seed set to %d", seed))
end

function particleCollector.update(dt)
    if particleCollector.game_over then return end
    
    -- Only handle internal timer if not in party mode
    if not particleCollector.partyMode then
        particleCollector.timer = particleCollector.timer - dt
        if particleCollector.timer <= 0 then
            particleCollector.timer = 0
            particleCollector.game_over = true
            
            -- Store score in players table for round win determination
            if _G.localPlayer and _G.localPlayer.id and _G.players and _G.players[_G.localPlayer.id] then
                _G.players[_G.localPlayer.id].particleCollectorScore = particleCollector.current_round_score
            end
            
            -- Send score to server for winner determination
            if _G.safeSend and _G.server then
                _G.safeSend(_G.server, string.format("particlecollector_score_sync,%d,%d", _G.localPlayer.id, particleCollector.current_round_score))
                debugConsole.addMessage("[ParticleCollector] Sent score to server: " .. particleCollector.current_round_score)
            end
            
            if _G.returnState then
                _G.gameState = _G.returnState
            end
            return
        end
    end
    
    particleCollector.gameTime = particleCollector.gameTime + dt
    
    -- Update phase system
    particleCollector.phase_timer = particleCollector.phase_timer + dt
    
    if particleCollector.phase == "calm" then
        if particleCollector.phase_timer >= particleCollector.calm_duration then
            particleCollector.phase = "chaos"
            particleCollector.phase_timer = 0
            debugConsole.addMessage("[ParticleCollector] Entering chaos phase - bad particles are chasing!")
        end
    elseif particleCollector.phase == "chaos" then
        if particleCollector.phase_timer >= particleCollector.chaos_duration then
            particleCollector.phase = "calm"
            particleCollector.phase_timer = 0
            debugConsole.addMessage("[ParticleCollector] Entering calm phase - breathing room!")
        end
    end
    
    -- Spawn particles
    particleCollector.spawn_timer = particleCollector.spawn_timer + dt
    if particleCollector.spawn_timer >= particleCollector.spawn_interval then
        particleCollector.spawnParticle()
        particleCollector.spawn_timer = 0
    end
    
    -- Update player movement
    local dx, dy = 0, 0
    if love.keyboard.isDown('a') then dx = dx - 1 end
    if love.keyboard.isDown('d') then dx = dx + 1 end
    if love.keyboard.isDown('w') then dy = dy - 1 end
    if love.keyboard.isDown('s') then dy = dy + 1 end
    
    if dx ~= 0 and dy ~= 0 then
        dx = dx * 0.707
        dy = dy * 0.707
    end
    
    particleCollector.player.x = particleCollector.player.x + dx * particleCollector.player.speed * dt
    particleCollector.player.y = particleCollector.player.y + dy * particleCollector.player.speed * dt
    
    -- Keep player within arena bounds
    particleCollector.player.x = math.max(
        particleCollector.arena_offset_x + particleCollector.player_size/2,
        math.min(particleCollector.arena_offset_x + particleCollector.arena_size - particleCollector.player_size/2, particleCollector.player.x))
    particleCollector.player.y = math.max(
        particleCollector.arena_offset_y + particleCollector.player_size/2,
        math.min(particleCollector.arena_offset_y + particleCollector.arena_size - particleCollector.player_size/2, particleCollector.player.y))
    
    -- Send player position for multiplayer sync
    if _G.localPlayer and _G.localPlayer.id then
        local events = require("src.core.events")
        events.emit("player:particlecollector_position", {
            id = _G.localPlayer.id,
            x = particleCollector.player.x,
            y = particleCollector.player.y,
            color = _G.localPlayer.color or particleCollector.playerColor
        })
    end
    
    -- Update particle movement
    particleCollector.updateParticleMovement(dt)
    
    -- Check collisions
    particleCollector.checkCollisions()
    
    -- Update invincibility timer
    if particleCollector.player.is_invincible then
        particleCollector.player.invincibility_timer = particleCollector.player.invincibility_timer - dt
        if particleCollector.player.invincibility_timer <= 0 then
            particleCollector.player.is_invincible = false
        end
    end
    
    -- Update particles
    particleCollector.updateParticles(dt)
    
    -- Update starfield
    particleCollector.updateStars(dt)
end

function particleCollector.draw(playersTable, localPlayerId)
    local base_width = _G.BASE_WIDTH or 800
    local base_height = _G.BASE_HEIGHT or 600
    
    -- Set background color
    love.graphics.setColor(0.05, 0.05, 0.15)
    love.graphics.rectangle("fill", 0, 0, base_width, base_height)
    
    -- Draw starfield background
    particleCollector.drawStars()
    
    -- Push graphics state for arena drawing
    love.graphics.push()
    love.graphics.translate(particleCollector.arena_offset_x, particleCollector.arena_offset_y)
    
    -- Draw arena boundary
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", 0, 0, particleCollector.arena_size, particleCollector.arena_size)
    
    -- Draw good particles (green, glowing)
    for _, particle in ipairs(particleCollector.good_particles) do
        local alpha = particle.life / particle.maxLife
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha * 0.8)
        love.graphics.circle("fill", particle.x, particle.y, particle.size)
        
        -- Glow effect
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha * 0.3)
        love.graphics.circle("fill", particle.x, particle.y, particle.size * 1.5)
    end
    
    -- Draw bad particles (red, pulsing)
    for _, particle in ipairs(particleCollector.bad_particles) do
        local alpha = particle.life / particle.maxLife
        local pulse = 1.0 + math.sin(particleCollector.gameTime * 8) * 0.2
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha * 0.9)
        love.graphics.circle("fill", particle.x, particle.y, particle.size * pulse)
        
        -- Danger glow
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha * 0.4)
        love.graphics.circle("fill", particle.x, particle.y, particle.size * 2)
    end
    
    -- Draw collection particles
    for _, particle in ipairs(particleCollector.collection_particles) do
        local alpha = particle.life / particle.maxLife
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        love.graphics.circle("fill", particle.x - particleCollector.arena_offset_x, particle.y - particleCollector.arena_offset_y, particle.size)
    end
    
    -- Draw other players (ghost-like)
    if playersTable then
        for id, player in pairs(playersTable) do
            if id ~= localPlayerId and player.particleCollectorX and player.particleCollectorY then
                -- Convert absolute position to arena-relative position
                local other_player_x = player.particleCollectorX - particleCollector.arena_offset_x
                local other_player_y = player.particleCollectorY - particleCollector.arena_offset_y
                
                -- Draw ghost player body
                love.graphics.setColor(player.color[1], player.color[2], player.color[3], 0.5)
                love.graphics.rectangle("fill",
                    other_player_x - particleCollector.player_size/2,
                    other_player_y - particleCollector.player_size/2,
                    particleCollector.player_size,
                    particleCollector.player_size
                )
                
                -- Draw their face if available
                if player.facePoints then
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.draw(
                        player.facePoints,
                        other_player_x - particleCollector.player_size/2,
                        other_player_y - particleCollector.player_size/2,
                        0,
                        particleCollector.player_size/100,
                        particleCollector.player_size/100
                    )
                end
            end
        end
    end
    
    -- Draw local player
    local player_x = particleCollector.player.x - particleCollector.arena_offset_x
    local player_y = particleCollector.player.y - particleCollector.arena_offset_y
    
    -- Flash player if invincible
    if particleCollector.player.is_invincible then
        local flash = math.floor(love.timer.getTime() * 10) % 2
        if flash == 0 then
            love.graphics.setColor(1, 1, 1)  -- White flash
        else
            love.graphics.setColor(particleCollector.playerColor[1], particleCollector.playerColor[2], particleCollector.playerColor[3])
        end
    else
        love.graphics.setColor(particleCollector.playerColor[1], particleCollector.playerColor[2], particleCollector.playerColor[3])
    end
    
    love.graphics.rectangle("fill",
        player_x - particleCollector.player_size/2,
        player_y - particleCollector.player_size/2,
        particleCollector.player_size,
        particleCollector.player_size
    )
    
    -- Draw player face if available
    if playersTable and playersTable[localPlayerId] and playersTable[localPlayerId].facePoints then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            playersTable[localPlayerId].facePoints,
            player_x - particleCollector.player_size/2,
            player_y - particleCollector.player_size/2,
            0,
            particleCollector.player_size/100,
            particleCollector.player_size/100
        )
    end
    
    love.graphics.pop()
    
    -- Draw UI
    particleCollector.drawUI(playersTable, localPlayerId)
end

function particleCollector.drawUI(playersTable, localPlayerId)
    local base_width = _G.BASE_WIDTH or 800
    local base_height = _G.BASE_HEIGHT or 600
    
    -- Draw current phase indicator
    local phase_text = ""
    local phase_color = {1, 1, 1}
    
    if particleCollector.phase == "calm" then
        phase_text = "CALM PHASE - Collect Green Particles!"
        phase_color = {0.2, 1, 0.2}  -- Green
    else
        phase_text = "CHAOS PHASE - Avoid Red Particles!"
        phase_color = {1, 0.2, 0.2}  -- Red
    end
    
    love.graphics.setColor(phase_color[1], phase_color[2], phase_color[3])
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf(phase_text, 0, 10, base_width, "center")
    
    -- Draw particle count
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(20))
    local count_text = "Particles: " .. particleCollector.current_round_score
    love.graphics.print(count_text, 10, 40)
    
    -- Draw particle counts on screen
    local good_count = #particleCollector.good_particles
    local bad_count = #particleCollector.bad_particles
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.print("Green: " .. good_count, 10, 65)
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.print("Red: " .. bad_count, 10, 80)
    
    -- Tab score overlay
    if particleCollector.showTabScores and playersTable then
        gameUI.drawTabScores(playersTable, localPlayerId, "particlecollector")
    end
end

function particleCollector.reset(playersTable)
    debugConsole.addMessage("[ParticleCollector] Resetting particle collector game")
    particleCollector.load()
end

function particleCollector.setPlayerColor(color)
    particleCollector.playerColor = color
end

function particleCollector.keypressed(key)
    if key == "tab" then
        particleCollector.showTabScores = true
    end
end

function particleCollector.keyreleased(key)
    if key == "tab" then
        particleCollector.showTabScores = false
    end
end

function particleCollector.mousepressed(x, y, button)
    -- No mouse handling needed
end

return particleCollector

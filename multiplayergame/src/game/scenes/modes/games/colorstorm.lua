local colorStorm = {}
colorStorm.name = "colorstorm"
local debugConsole = require "src.core.debugconsole"
local musicHandler = require "src.game.systems.musichandler"
local gameUI = require "src.game.systems.gameui"

-- Sound effects
colorStorm.sounds = {
    color_change = love.audio.newSource("sounds/laser.mp3", "static"),
    hit = love.audio.newSource("sounds/death.mp3", "static")
}

-- Set sound volumes
colorStorm.sounds.color_change:setVolume(0.3)
colorStorm.sounds.hit:setVolume(0.4)

-- Game state
colorStorm.game_over = false
colorStorm.current_round_score = 0
colorStorm.playerColor = {1, 1, 1}
colorStorm.screen_width = 800  -- Fixed base resolution
colorStorm.screen_height = 600  -- Fixed base resolution
colorStorm.partyMode = false  -- Party mode flag
colorStorm.hits = 0  -- Track hits
colorStorm.showTabScores = false  -- Tab key pressed

-- Seed-based synchronization
colorStorm.seed = 0
colorStorm.random = love.math.newRandomGenerator()
colorStorm.gameTime = 0
colorStorm.colorSequence = {}  -- Pre-calculated color changes

-- Game settings
colorStorm.timer = 30 -- 30 seconds
colorStorm.player_size = 30
colorStorm.arena_size = 750
colorStorm.arena_offset_x = 0
colorStorm.arena_offset_y = 0

-- Color system
colorStorm.available_colors = {
    {1, 0, 0},    -- Red
    {0, 1, 0},    -- Green
    {0, 0, 1},    -- Blue
    {1, 1, 0},    -- Yellow
    {1, 0, 1},    -- Magenta
    {0, 1, 1},    -- Cyan
    {1, 0.5, 0},  -- Orange
    {0.5, 0, 1}   -- Purple
}

colorStorm.current_color = {1, 0, 0}  -- Start with red
colorStorm.current_color_index = 1
colorStorm.safe_zones = {}  -- Colored zones on screen
colorStorm.phase = "preview"  -- "preview", "chaos", "stay", "transition"
colorStorm.phase_timer = 0
colorStorm.preview_duration = 1.5  -- 1.5 seconds color popup indicator
colorStorm.chaos_duration = 3.0    -- 3 seconds timer to get in zones
colorStorm.stay_duration = 2.0      -- 2 seconds stay in zone
colorStorm.transition_duration = 0.5  -- 0.5 seconds between phases

-- Player settings
colorStorm.player = {
    x = 400,
    y = 300,
    width = 30,
    height = 30,
    speed = 300,
    points = 0,
    is_invincible = false,
    invincibility_timer = 0
}

-- Particle system for visual effects
colorStorm.particles = {}
colorStorm.particle_lifetime = 1.0
colorStorm.particle_speed = 150
colorStorm.particle_size = 4

-- Star field background (like meteoroid shower)
colorStorm.stars = {}
colorStorm.star_direction = 0 -- Global direction for all stars

-- Color popup indicator system
colorStorm.color_popup = {
    visible = false,
    timer = 0,
    duration = 2.0,
    scale = 1.0,
    alpha = 1.0
}

function colorStorm.createParticles(x, y, color)
    for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2
        local speed = colorStorm.random:random(50, colorStorm.particle_speed)
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = colorStorm.particle_lifetime,
            maxLife = colorStorm.particle_lifetime,
            size = colorStorm.random:random(2, colorStorm.particle_size),
            color = {color[1], color[2], color[3]}
        }
        table.insert(colorStorm.particles, particle)
    end
end

function colorStorm.updateParticles(dt)
    for i = #colorStorm.particles, 1, -1 do
        local particle = colorStorm.particles[i]
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.life = particle.life - dt
        
        if particle.life <= 0 then
            table.remove(colorStorm.particles, i)
        end
    end
end

function colorStorm.createStars()
    colorStorm.stars = {}
    -- Create a moving starfield with uniform direction and color using seeded random
    for i = 1, 150 do
        table.insert(colorStorm.stars, {
            x = colorStorm.random:random(0, colorStorm.screen_width),
            y = colorStorm.random:random(0, colorStorm.screen_height),
            size = colorStorm.random:random(1, 3),
            speed = colorStorm.random:random(20, 60) -- Movement speed in pixels per second
            -- All stars use the global star_direction
        })
    end
end

function colorStorm.updateStars(dt)
    for i = #colorStorm.stars, 1, -1 do
        local star = colorStorm.stars[i]
        
        -- Move star in the global direction
        star.x = star.x + math.cos(colorStorm.star_direction) * star.speed * dt
        star.y = star.y + math.sin(colorStorm.star_direction) * star.speed * dt
        
        -- Wrap around screen edges
        if star.x < 0 then
            star.x = colorStorm.screen_width
        elseif star.x > colorStorm.screen_width then
            star.x = 0
        end
        
        if star.y < 0 then
            star.y = colorStorm.screen_height
        elseif star.y > colorStorm.screen_height then
            star.y = 0
        end
    end
end

function colorStorm.drawStars()
    for _, star in ipairs(colorStorm.stars) do
        love.graphics.setColor(1, 1, 1, 0.8) -- Uniform white color with slight transparency
        love.graphics.circle('fill', star.x, star.y, star.size)
    end
end

function colorStorm.load(args)
    args = args or {}
    colorStorm.partyMode = args.partyMode or false
    
    debugConsole.addMessage("[ColorStorm] Loading color storm game")
    debugConsole.addMessage("[ColorStorm] Party mode status: " .. tostring(colorStorm.partyMode))
    
    -- Calculate arena positioning
    local base_width = _G.BASE_WIDTH or 800
    local base_height = _G.BASE_HEIGHT or 600
    colorStorm.arena_offset_x = (base_width - colorStorm.arena_size) / 2
    colorStorm.arena_offset_y = (base_height - colorStorm.arena_size) / 2
    
    -- Reset game state
    colorStorm.game_over = false
    colorStorm.current_round_score = 0
    colorStorm.hits = 0
    colorStorm.timer = 30
    colorStorm.gameTime = 0
    colorStorm.particles = {}
    
    -- Reset player
    colorStorm.player = {
        x = colorStorm.arena_offset_x + colorStorm.arena_size / 2,
        y = colorStorm.arena_offset_y + colorStorm.arena_size / 2,
        width = 30,
        height = 30,
        speed = 300,
        points = 0,
        is_invincible = false,
        invincibility_timer = 0
    }
    
    -- Set player color if available from args
    if args.players and args.localPlayerId ~= nil then
        local localPlayer = args.players[args.localPlayerId]
        if localPlayer and localPlayer.color then
            colorStorm.playerColor = localPlayer.color
        end
    end
    
    -- Initialize color system
    colorStorm.current_color_index = 1
    colorStorm.current_color = colorStorm.available_colors[1]
    colorStorm.phase = "preview"
    colorStorm.phase_timer = 0
    colorStorm.safe_zones = {}
    
    -- Create initial safe zones
    colorStorm.createSafeZones()
    
    -- Set star direction for this round using seeded random
    colorStorm.star_direction = colorStorm.random:random() * 2 * math.pi
    
    -- Create star field
    colorStorm.createStars()
    
    -- Add music effects
    musicHandler.addEffect("color_pulse", "beatPulse", {
        baseColor = {1, 1, 1},
        intensity = 0.6,
        duration = 0.2
    })
    
    musicHandler.addEffect("zone_scale", "combo", {
        scaleAmount = 0.1,
        rotateAmount = 0,
        frequency = 1,
        phase = 0,
        snapDuration = 0.1
    })
    
    -- Initialize with seed if provided, otherwise generate one for host
    if args.seed then
        colorStorm.setSeed(args.seed)
        debugConsole.addMessage("[ColorStorm] Using provided seed: " .. args.seed)
    elseif args.isHost then
        local seed = os.time() + love.timer.getTime() * 10000
        colorStorm.setSeed(seed)
        debugConsole.addMessage("[ColorStorm] Host generated seed: " .. seed)
    end
    
    debugConsole.addMessage("[ColorStorm] Game loaded")
end

function colorStorm.setSeed(seed)
    colorStorm.seed = seed
    colorStorm.random:setSeed(seed)
    colorStorm.gameTime = 0
    colorStorm.colorSequence = {}
    
    -- Pre-calculate color changes for the entire game
    local time = 0
    while time < colorStorm.timer do
        local colorChange = {
            time = time,
            color_index = colorStorm.random:random(1, #colorStorm.available_colors),
            phase_duration = colorStorm.random:random(1.5, 2.5)  -- Variable phase duration
        }
        table.insert(colorStorm.colorSequence, colorChange)
        
        -- Next color change in 3-5 seconds
        time = time + colorStorm.random:random(3.0, 5.0)
    end
    
    debugConsole.addMessage(string.format(
        "[ColorStorm] Generated %d color changes with seed %d",
        #colorStorm.colorSequence,
        seed
    ))
end

function colorStorm.createSafeZones()
    colorStorm.safe_zones = {}
    
    -- Create 4-6 random colored circular zones with different colors
    local num_zones = colorStorm.random:random(4, 6)
    
    -- First zone is guaranteed to be the correct color
    local zone = {
        x = colorStorm.random:random(100, colorStorm.arena_size - 100),
        y = colorStorm.random:random(100, colorStorm.arena_size - 100),
        radius = colorStorm.random:random(40, 80),
        color = colorStorm.current_color, -- Guaranteed correct color
        alpha = 0.3
    }
    table.insert(colorStorm.safe_zones, zone)
    
    -- Create remaining zones with random colors
    for i = 2, num_zones do
        local random_color_index = colorStorm.random:random(1, #colorStorm.available_colors)
        local zone_color = colorStorm.available_colors[random_color_index]
        
        local zone = {
            x = colorStorm.random:random(100, colorStorm.arena_size - 100),
            y = colorStorm.random:random(100, colorStorm.arena_size - 100),
            radius = colorStorm.random:random(40, 80),
            color = zone_color, -- Random color
            alpha = 0.3
        }
        table.insert(colorStorm.safe_zones, zone)
    end
    
    debugConsole.addMessage(string.format("[ColorStorm] Created %d zones. First zone guaranteed correct color (index %d)", 
        num_zones, colorStorm.current_color_index))
end

function colorStorm.update(dt)
    if colorStorm.game_over then return end
    
    -- Only handle internal timer if not in party mode
    if not colorStorm.partyMode then
        colorStorm.timer = colorStorm.timer - dt
        if colorStorm.timer <= 0 then
            colorStorm.timer = 0
            colorStorm.game_over = true
            
            -- Store score in players table for round win determination
            if _G.localPlayer and _G.localPlayer.id and _G.players and _G.players[_G.localPlayer.id] then
                _G.players[_G.localPlayer.id].colorStormScore = colorStorm.current_round_score
            end
            
            -- Send score to server for winner determination
            if _G.safeSend and _G.server then
                _G.safeSend(_G.server, string.format("colorstorm_score_sync,%d,%d", _G.localPlayer.id, colorStorm.current_round_score))
                debugConsole.addMessage("[ColorStorm] Sent score to server: " .. colorStorm.current_round_score)
            end
            
            if _G.returnState then
                _G.gameState = _G.returnState
            end
            return
        end
    end
    
    colorStorm.gameTime = colorStorm.gameTime + dt
    
    -- Check for color changes based on pre-calculated sequence (only during transition phase)
    if colorStorm.phase == "transition" and #colorStorm.colorSequence > 0 and colorStorm.colorSequence[1].time <= colorStorm.gameTime then
        local colorChange = table.remove(colorStorm.colorSequence, 1)
        colorStorm.current_color_index = colorChange.color_index
        colorStorm.current_color = colorStorm.available_colors[colorChange.color_index]
        
        -- Recreate safe zones with new color
        colorStorm.createSafeZones()
        
        -- Play color change sound
        colorStorm.sounds.color_change:clone():play()
        
        debugConsole.addMessage("[ColorStorm] Color changed to index " .. colorChange.color_index)
    end
    
    -- Update phase system
    colorStorm.phase_timer = colorStorm.phase_timer + dt
    
    if colorStorm.phase == "preview" then
        -- Show color popup indicator
        colorStorm.color_popup.visible = true
        colorStorm.color_popup.timer = colorStorm.color_popup.timer + dt
        
        -- Animate popup scale and alpha
        local progress = colorStorm.color_popup.timer / colorStorm.color_popup.duration
        colorStorm.color_popup.scale = 1.0 + math.sin(progress * math.pi * 4) * 0.2 -- Pulsing effect
        colorStorm.color_popup.alpha = 1.0 - (progress * 0.3) -- Fade slightly over time
        
        if colorStorm.phase_timer >= colorStorm.preview_duration then
            colorStorm.phase = "chaos"
            colorStorm.phase_timer = 0
            colorStorm.color_popup.visible = false
            colorStorm.color_popup.timer = 0
            debugConsole.addMessage("[ColorStorm] Entering chaos phase - Find the correct colored zones!")
        end
    elseif colorStorm.phase == "chaos" then
        -- Hide popup during chaos phase
        colorStorm.color_popup.visible = false
        
        if colorStorm.phase_timer >= colorStorm.chaos_duration then
            colorStorm.phase = "stay"
            colorStorm.phase_timer = 0
            debugConsole.addMessage("[ColorStorm] Entering stay phase - Stay in the correct zone!")
        end
    elseif colorStorm.phase == "stay" then
        if colorStorm.phase_timer >= colorStorm.stay_duration then
            colorStorm.phase = "transition"
            colorStorm.phase_timer = 0
            debugConsole.addMessage("[ColorStorm] Entering transition phase")
        end
    elseif colorStorm.phase == "transition" then
        if colorStorm.phase_timer >= colorStorm.transition_duration then
            colorStorm.phase = "preview"
            colorStorm.phase_timer = 0
            colorStorm.color_popup.timer = 0
            debugConsole.addMessage("[ColorStorm] Entering preview phase")
        end
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
    
    colorStorm.player.x = colorStorm.player.x + dx * colorStorm.player.speed * dt
    colorStorm.player.y = colorStorm.player.y + dy * colorStorm.player.speed * dt
    
    -- Keep player within arena bounds
    colorStorm.player.x = math.max(
        colorStorm.arena_offset_x + colorStorm.player_size/2,
        math.min(colorStorm.arena_offset_x + colorStorm.arena_size - colorStorm.player_size/2, colorStorm.player.x))
    colorStorm.player.y = math.max(
        colorStorm.arena_offset_y + colorStorm.player_size/2,
        math.min(colorStorm.arena_offset_y + colorStorm.arena_size - colorStorm.player_size/2, colorStorm.player.y))
    
    -- Send player position for multiplayer sync
    if _G.localPlayer and _G.localPlayer.id then
        local events = require("src.core.events")
        events.emit("player:colorstorm_position", {
            id = _G.localPlayer.id,
            x = colorStorm.player.x,
            y = colorStorm.player.y,
            color = _G.localPlayer.color or colorStorm.playerColor
        })
    end
    
    -- Check if player is in a safe zone (only during chaos phase)
    if colorStorm.phase == "chaos" then
        local in_safe_zone = false
        for _, zone in ipairs(colorStorm.safe_zones) do
            -- Only zones matching the current target color are safe
            if zone.color[1] == colorStorm.current_color[1] and 
               zone.color[2] == colorStorm.current_color[2] and 
               zone.color[3] == colorStorm.current_color[3] then
                
                -- Convert player position to arena-relative coordinates for comparison
                local player_arena_x = colorStorm.player.x - colorStorm.arena_offset_x
                local player_arena_y = colorStorm.player.y - colorStorm.arena_offset_y
                local player_center_x = player_arena_x + colorStorm.player_size/2
                local player_center_y = player_arena_y + colorStorm.player_size/2
                
                -- Calculate distance from player center to zone center
                local distance = math.sqrt((player_center_x - zone.x)^2 + (player_center_y - zone.y)^2)
                
                if distance <= zone.radius then
                    in_safe_zone = true
                    debugConsole.addMessage(string.format("[ColorStorm] Player in correct color zone! Distance: %.1f, Radius: %.1f", distance, zone.radius))
                    break
                end
            end
        end
        
        -- Check for damage continuously during chaos phase
        if not in_safe_zone and not colorStorm.player.is_invincible then
            -- Player is not in correct color zone during chaos - take damage
            colorStorm.player.is_invincible = true
            colorStorm.player.invincibility_timer = 1.0
            colorStorm.hits = colorStorm.hits + 1
            
            -- Play hit sound
            colorStorm.sounds.hit:clone():play()
            
            -- Create particle effect
            colorStorm.createParticles(colorStorm.player.x, colorStorm.player.y, colorStorm.current_color)
            
            debugConsole.addMessage("[ColorStorm] Player hit! Not in correct color zone. Hits: " .. colorStorm.hits)
        end
    end
    
    -- Update invincibility timer
    if colorStorm.player.is_invincible then
        colorStorm.player.invincibility_timer = colorStorm.player.invincibility_timer - dt
        if colorStorm.player.invincibility_timer <= 0 then
            colorStorm.player.is_invincible = false
        end
    end
    
    -- Update score based on survival time
    if colorStorm.phase == "chaos" then
        colorStorm.current_round_score = colorStorm.current_round_score + math.floor(dt * 20)
    end
    
    -- Update particles
    colorStorm.updateParticles(dt)
    
    -- Update starfield
    colorStorm.updateStars(dt)
end

function colorStorm.draw(playersTable, localPlayerId)
    local base_width = _G.BASE_WIDTH or 800
    local base_height = _G.BASE_HEIGHT or 600
    
    -- Set background color
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 0, 0, base_width, base_height)
    
    -- Draw starfield background
    colorStorm.drawStars()
    
    -- Push graphics state for arena drawing
    love.graphics.push()
    love.graphics.translate(colorStorm.arena_offset_x, colorStorm.arena_offset_y)
    
    -- Draw arena boundary
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", 0, 0, colorStorm.arena_size, colorStorm.arena_size)
    
    -- Draw safe zones as circles
    for _, zone in ipairs(colorStorm.safe_zones) do
        local alpha = zone.alpha
        if colorStorm.phase == "preview" then
            alpha = alpha * 0.5  -- Dimmer during preview
        elseif colorStorm.phase == "chaos" then
            alpha = alpha * 1.5  -- Brighter during chaos
        end
        
        love.graphics.setColor(zone.color[1], zone.color[2], zone.color[3], alpha)
        love.graphics.circle("fill", zone.x, zone.y, zone.radius)
        
        -- Draw zone border
        love.graphics.setColor(zone.color[1], zone.color[2], zone.color[3], alpha * 2)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", zone.x, zone.y, zone.radius)
        love.graphics.setLineWidth(1)
    end
    
    -- Draw particles
    for _, particle in ipairs(colorStorm.particles) do
        local alpha = particle.life / particle.maxLife
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        love.graphics.circle("fill", particle.x, particle.y, particle.size)
    end
    
    -- Draw other players (ghost-like)
    if playersTable then
        for id, player in pairs(playersTable) do
            if id ~= localPlayerId and player.colorStormX and player.colorStormY then
                -- Convert absolute position to arena-relative position
                local other_player_x = player.colorStormX - colorStorm.arena_offset_x
                local other_player_y = player.colorStormY - colorStorm.arena_offset_y
                
                -- Draw ghost player body
                love.graphics.setColor(player.color[1], player.color[2], player.color[3], 0.5)
                love.graphics.rectangle("fill",
                    other_player_x - colorStorm.player_size/2,
                    other_player_y - colorStorm.player_size/2,
                    colorStorm.player_size,
                    colorStorm.player_size
                )
                
                -- Draw their face if available
                if player.facePoints then
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.draw(
                        player.facePoints,
                        other_player_x - colorStorm.player_size/2,
                        other_player_y - colorStorm.player_size/2,
                        0,
                        colorStorm.player_size/100,
                        colorStorm.player_size/100
                    )
                end
            end
        end
    end
    
    -- Draw local player
    local player_x = colorStorm.player.x - colorStorm.arena_offset_x
    local player_y = colorStorm.player.y - colorStorm.arena_offset_y
    
    -- Flash player if invincible
    if colorStorm.player.is_invincible then
        local flash = math.floor(love.timer.getTime() * 10) % 2
        if flash == 0 then
            love.graphics.setColor(1, 1, 1)  -- White flash
        else
            love.graphics.setColor(colorStorm.playerColor[1], colorStorm.playerColor[2], colorStorm.playerColor[3])
        end
    else
        love.graphics.setColor(colorStorm.playerColor[1], colorStorm.playerColor[2], colorStorm.playerColor[3])
    end
    
    love.graphics.rectangle("fill",
        player_x - colorStorm.player_size/2,
        player_y - colorStorm.player_size/2,
        colorStorm.player_size,
        colorStorm.player_size
    )
    
    -- Draw player face if available
    if playersTable and playersTable[localPlayerId] and playersTable[localPlayerId].facePoints then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            playersTable[localPlayerId].facePoints,
            player_x - colorStorm.player_size/2,
            player_y - colorStorm.player_size/2,
            0,
            colorStorm.player_size/100,
            colorStorm.player_size/100
        )
    end
    
    love.graphics.pop()
    
    -- Draw color popup indicator
    if colorStorm.color_popup.visible then
        local center_x = base_width / 2
        local center_y = base_height / 2
        
        love.graphics.push()
        love.graphics.translate(center_x, center_y)
        love.graphics.scale(colorStorm.color_popup.scale, colorStorm.color_popup.scale)
        
        -- Draw large colored circle as popup
        love.graphics.setColor(colorStorm.current_color[1], colorStorm.current_color[2], colorStorm.current_color[3], colorStorm.color_popup.alpha)
        love.graphics.circle("fill", 0, 0, 100)
        
        -- Draw border
        love.graphics.setColor(colorStorm.current_color[1], colorStorm.current_color[2], colorStorm.current_color[3], colorStorm.color_popup.alpha * 1.5)
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", 0, 0, 100)
        love.graphics.setLineWidth(1)
        
        -- Draw text
        love.graphics.setColor(1, 1, 1, colorStorm.color_popup.alpha)
        love.graphics.setFont(love.graphics.newFont(32))
        love.graphics.printf("GET READY!", -150, -20, 300, "center")
        
        love.graphics.pop()
    end
    
    -- Draw UI
    colorStorm.drawUI(playersTable, localPlayerId)
end

function colorStorm.drawUI(playersTable, localPlayerId)
    local base_width = _G.BASE_WIDTH or 800
    local base_height = _G.BASE_HEIGHT or 600
    
    -- Draw hits counter
    gameUI.drawHitCounter(colorStorm.hits, 10, 10)
    
    -- Draw current phase indicator (simplified)
    local phase_text = ""
    local phase_color = {1, 1, 1}
    
    if colorStorm.phase == "preview" then
        phase_text = "PREVIEW - Get Ready!"
        phase_color = {0, 1, 0}  -- Green
    elseif colorStorm.phase == "chaos" then
        phase_text = "FIND THE CORRECT COLOR!"
        phase_color = {1, 0, 0}  -- Red
    elseif colorStorm.phase == "stay" then
        phase_text = "STAY IN THE ZONE!"
        phase_color = {0, 0, 1}  -- Blue
    elseif colorStorm.phase == "transition" then
        phase_text = "TRANSITION"
        phase_color = {1, 1, 0}  -- Yellow
    end
    
    love.graphics.setColor(phase_color[1], phase_color[2], phase_color[3])
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf(phase_text, 0, 50, base_width, "center")
    
    -- Draw current color indicator
    love.graphics.setColor(colorStorm.current_color[1], colorStorm.current_color[2], colorStorm.current_color[3])
    love.graphics.rectangle("fill", base_width - 60, 10, 50, 30)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", base_width - 60, 10, 50, 30)
    
    -- Draw score
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(16))
    local score_text = "Score: " .. colorStorm.current_round_score
    love.graphics.print(score_text, 10, 30)
    
    -- Tab score overlay
    if colorStorm.showTabScores and playersTable then
        gameUI.drawTabScores(playersTable, localPlayerId, "colorstorm")
    end
end

function colorStorm.reset(playersTable)
    debugConsole.addMessage("[ColorStorm] Resetting color storm game")
    colorStorm.load()
end

function colorStorm.setPlayerColor(color)
    colorStorm.playerColor = color
end

function colorStorm.keypressed(key)
    if key == "tab" then
        colorStorm.showTabScores = true
    end
end

function colorStorm.keyreleased(key)
    if key == "tab" then
        colorStorm.showTabScores = false
    end
end

function colorStorm.mousepressed(x, y, button)
    -- No mouse handling needed
end

return colorStorm

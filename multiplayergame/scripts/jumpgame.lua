local jumpGame = {}
local musicHandler = require "scripts.musichandler"

jumpGame.player = {}
jumpGame.platforms = {}
jumpGame.gravity = 0.25
jumpGame.jump_strength = 8
jumpGame.move_speed = 2
jumpGame.camera_y = 0
jumpGame.has_first_jump = false
jumpGame.has_second_jump = false
jumpGame.game_speed = 1
jumpGame.score = 0
jumpGame.hit_platforms = {}
jumpGame.background_image = nil
jumpGame.timer = (musicHandler.beatInterval * 8)-- - (musicHandler.beatInterval / 2)
jumpGame.game_over = false
jumpGame.camera_smoothness = 0.1
jumpGame.playerColor = {1, 1, 1}  
jumpGame.current_round_score = 0

jumpGame.particles = {}
jumpGame.particleLifetime = 0.5
jumpGame.particleCount = 10

jumpGame.sounds = {
    jump = love.audio.newSource("sounds/jumpgame-jump.mp3", "static"),
    doublejump = love.audio.newSource("sounds/jumpgame-double.mp3", "static"),
    perfectlanding = love.audio.newSource("sounds/jumpgame-skill.mp3", "static")
}

-- sound editing
jumpGame.sounds.jump:setPitch(1.5)
jumpGame.sounds.doublejump:setVolume(0.3)
jumpGame.sounds.perfectlanding:setVolume(0.5)

jumpGame.platformEffects = {
    combo = {
        scaleAmount = 0.1,
        rotateAmount = math.pi/32,
        frequency = 1,
        phase = 0,
        snapDuration = 0.15
    },
    pulse = {
        baseColor = {0.8, 0.2, 0.2}, 
        intensity = 0.5,
        duration = 0.2
    }
}

function jumpGame.createParticles(x, y, velocity)
    local particles = {}
    for i = 1, jumpGame.particleCount do
        local angle = math.random() * math.pi * 2
        local speed = math.random(50, 100)
        table.insert(particles, {
            x = x,
            y = y,
            dx = math.cos(angle) * speed,
            dy = math.sin(angle) * speed - math.abs(velocity), -- Use landing velocity for upward burst
            lifetime = jumpGame.particleLifetime,
            color = {0, 0.5, 1}  
        })
    end
    table.insert(jumpGame.particles, particles)
end

function jumpGame.updateParticles(dt)
    for i = #jumpGame.particles, 1, -1 do
        local particleGroup = jumpGame.particles[i]
        local allDead = true
        
        for j = #particleGroup, 1, -1 do
            local particle = particleGroup[j]
            particle.lifetime = particle.lifetime - dt
            
            if particle.lifetime <= 0 then
                table.remove(particleGroup, j)
            else
                allDead = false
                -- Update particle position
                particle.x = particle.x + particle.dx * dt
                particle.y = particle.y + particle.dy * dt
                -- Add gravity effect
                particle.dy = particle.dy + jumpGame.gravity * 60 * dt
            end
        end
        
        if allDead then
            table.remove(jumpGame.particles, i)
        end
    end
end

function jumpGame.load()
    love.window.setTitle("Jump Game")
    love.window.setMode(800, 600)

    jumpGame.background_image = love.graphics.newImage("images/JKGame.png")

    jumpGame.player.rect = { x = 100, y = 500, width = 50, height = 50 }
    jumpGame.player.dy = 0
    jumpGame.player.is_jumping = false

    jumpGame.createPlatforms()
    
    -- Clear any existing effects first
    musicHandler.removeEffect("platforms")
    musicHandler.removeEffect("platform_pulse")

    -- Add the combo effect first
    musicHandler.addEffect("platforms", "combo", {
        scaleAmount = 0.1,      -- How much bigger it gets
        rotateAmount = math.pi/32,  -- How much it rotates
        frequency = 1,
        phase = 0,
        snapDuration = 0.15
    })

    -- Then add the pulse effect
    musicHandler.addEffect("platform_pulse", "beatPulse", {
        baseColor = {0.8, 0.2, 0.2}, 
        intensity = 0.5,
        duration = 0.2
    })
end

function jumpGame.slowClock(dt)
    return dt * jumpGame.game_speed
end

function jumpGame.setPlayerColor(color)
    jumpGame.playerColor = color
end

function jumpGame.writeScoreToFile()
    local new_score = "Score: " .. jumpGame.score .. "\n"
    local existing_scores = ""
    if love.filesystem.getInfo("score.txt") then
        existing_scores = love.filesystem.read("score.txt")
    end
    local updated_scores = existing_scores .. new_score
    love.filesystem.write("score.txt", updated_scores)
end

function jumpGame.update(dt) -- added music reaction
    local color = musicHandler.getCurrentColor("platforms")
    musicHandler.update(dt)

    if not jumpGame.game_over then
        dt = jumpGame.slowClock(dt)
        jumpGame.updateParticles(dt)
        

        local keys = love.keyboard.isDown
        if keys("a") then
            jumpGame.player.rect.x = jumpGame.player.rect.x - jumpGame.move_speed * dt * 150
        end
        if keys("d") then
            jumpGame.player.rect.x = jumpGame.player.rect.x + jumpGame.move_speed * dt * 150
        end

        if keys("w") and not jumpGame.has_first_jump and not jumpGame.player.is_jumping then
            jumpGame.player.dy = -jumpGame.jump_strength
            jumpGame.has_first_jump = true
            jumpGame.player.is_jumping = true
            jumpGame.sounds.jump:clone():play()
        end

        if keys("space") and jumpGame.has_first_jump and not jumpGame.has_second_jump then
            jumpGame.player.dy = -jumpGame.jump_strength
            jumpGame.has_second_jump = true
            jumpGame.sounds.doublejump:clone():play()
        end

        local previousDy = jumpGame.player.dy

        -- Apply gravity and update position
        jumpGame.player.dy = jumpGame.player.dy + jumpGame.gravity * dt * 90
        jumpGame.player.rect.y = jumpGame.player.rect.y + jumpGame.player.dy * dt * 90

        -- Ground collision
        if jumpGame.player.rect.y + jumpGame.player.rect.height >= love.graphics.getHeight() then
            jumpGame.player.rect.y = love.graphics.getHeight() - jumpGame.player.rect.height
            jumpGame.player.dy = 0
            jumpGame.has_first_jump = false
            jumpGame.has_second_jump = false
            jumpGame.player.is_jumping = false
        end

        -- Platform collision
        local on_platform = false
        for _, platform in ipairs(jumpGame.platforms) do
            if jumpGame.player.rect.x < platform.rect.x + platform.rect.width and
                jumpGame.player.rect.x + jumpGame.player.rect.width > platform.rect.x and
                jumpGame.player.rect.y + jumpGame.player.rect.height >= platform.rect.y and
                jumpGame.player.rect.y + jumpGame.player.rect.height <= platform.rect.y + platform.rect.height then
                
                -- Check if this was a "snap" (significant downward velocity suddenly stopped)
                if previousDy < -2 and not love.keyboard.isDown('w') then -- Threshold for considering it a "snap"
                    jumpGame.sounds.perfectlanding:clone():play()
                    jumpGame.createParticles(
                        jumpGame.player.rect.x + jumpGame.player.rect.width / 2,
                        jumpGame.player.rect.y + jumpGame.player.rect.height,
                        previousDy
                    )
                end
                
                jumpGame.player.rect.y = platform.rect.y - jumpGame.player.rect.height
                jumpGame.player.dy = 0
                on_platform = true
                
                local platform_id = platform.rect.x .. "_" .. platform.rect.y
                if not jumpGame.hit_platforms[platform_id] then
                    jumpGame.hit_platforms[platform_id] = true
                end
            end
        end

        -- Update score based on upward movement
        if jumpGame.player.dy < 0 then  -- Only count upward movement
            jumpGame.current_round_score = jumpGame.current_round_score + math.floor(-jumpGame.player.dy * dt * 20)
        end

        if on_platform then
            jumpGame.has_first_jump = false
            jumpGame.has_second_jump = false
            jumpGame.player.is_jumping = false
        end

        -- Camera follow
        local target_camera_y = jumpGame.player.rect.y - love.graphics.getHeight() / 2
        jumpGame.camera_y = jumpGame.camera_y + (target_camera_y - jumpGame.camera_y) * jumpGame.camera_smoothness

        jumpGame.timer = jumpGame.timer - dt
        if jumpGame.timer <= 0 then
            jumpGame.timer = 0
            jumpGame.game_over = true

            -- Store score in players table for round win determination
            if _G.localPlayer and _G.localPlayer.id and _G.players and _G.players[_G.localPlayer.id] then
                _G.players[_G.localPlayer.id].jumpScore = jumpGame.current_round_score
            end
            
            _G.gameState = returnState

        end
    end
end

function jumpGame.draw(playersTable, localPlayerId)
    local window_width, window_height = love.graphics.getWidth(), love.graphics.getHeight()
    local bg_width, bg_height = jumpGame.background_image:getWidth(), jumpGame.background_image:getHeight()

    local scale = 1.25
    
    local background_x = (window_width - (bg_width * scale)) / 2
    
    local background_parallax = 0.5
    local background_y = window_height - (jumpGame.camera_y * background_parallax % (bg_height * scale))

    -- Draw background tiles
    local num_tiles = math.ceil(window_height / (bg_height * scale)) + 2
    for i = 0, num_tiles do
        love.graphics.draw(
            jumpGame.background_image,
            background_x,
            background_y - (i * bg_height * scale),
            0,
            scale,
            scale
        )
    end

    love.graphics.push()
    love.graphics.translate(0, -math.floor(jumpGame.camera_y))

    for _, platform in ipairs(jumpGame.platforms) do
        -- Get color from beat pulse effect
        local pulseColor = musicHandler.getCurrentColor("platform_pulse")
        
        -- Get transform values from combo effect
        local x, y, rotation, scaleX, scaleY = musicHandler.applyToDrawable(
            "platforms",
            platform.rect.x,
            platform.rect.y
        )
        
        -- Apply the combined effects
        love.graphics.push()
        love.graphics.translate(x + platform.rect.width/2, y + platform.rect.height/2)
        love.graphics.rotate(rotation or 0)
        love.graphics.scale(scaleX or 1, scaleY or 1)
        
        love.graphics.setColor(pulseColor[1], pulseColor[2], pulseColor[3])
        love.graphics.rectangle(
            "fill",
            -platform.rect.width/2,
            -platform.rect.height/2,
            platform.rect.width,
            platform.rect.height
        )
        love.graphics.pop()
    end

    -- Draw particles
    for _, particleGroup in ipairs(jumpGame.particles) do
        for _, particle in ipairs(particleGroup) do
            love.graphics.setColor(
                particle.color[1],
                particle.color[2],
                particle.color[3],
                particle.lifetime / jumpGame.particleLifetime
            )
            love.graphics.circle("fill", particle.x, particle.y, 4)
        end
    end

    -- Draw main player with score
    love.graphics.setColor(jumpGame.playerColor[1], jumpGame.playerColor[2], jumpGame.playerColor[3])
    love.graphics.rectangle("fill", 
        jumpGame.player.rect.x, 
        jumpGame.player.rect.y, 
        jumpGame.player.rect.width, 
        jumpGame.player.rect.height) 

    -- Draw main player with score
    love.graphics.setColor(jumpGame.playerColor[1], jumpGame.playerColor[2], jumpGame.playerColor[3])
    love.graphics.rectangle("fill", 
        jumpGame.player.rect.x, 
        jumpGame.player.rect.y, 
        jumpGame.player.rect.width, 
        jumpGame.player.rect.height
    )

    -- Draw local player's face and score
    if playersTable and playersTable[localPlayerId] then
        -- Draw face
        if playersTable[localPlayerId].facePoints then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                playersTable[localPlayerId].facePoints,
                jumpGame.player.rect.x,
                jumpGame.player.rect.y,
                0,
                jumpGame.player.rect.width/100,
                jumpGame.player.rect.height/100
            )
        end
        
        -- Score display removed
    end

    -- draw ghost players and scores
    if playersTable then
        for id, player in pairs(playersTable) do
            if id ~= localPlayerId and player.jumpX and player.jumpY then
                -- Draw ghost player body
                love.graphics.setColor(player.color[1], player.color[2], player.color[3], 0.5)
                love.graphics.rectangle("fill", 
                    player.jumpX, 
                    player.jumpY,
                    jumpGame.player.rect.width, 
                    jumpGame.player.rect.height
                )
                
                -- Draw ghost player face if available
                if player.facePoints then
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.draw(
                        player.facePoints,
                        player.jumpX,
                        player.jumpY,
                        0,
                        jumpGame.player.rect.width/100,
                        jumpGame.player.rect.height/100
                    )
                end
                
                -- Score display removed
            end
        end
    end

    love.graphics.pop() -- this works somehow

    -- UI elements
    love.graphics.setColor(1, 1, 1)
    local round_score_text = "Round Score: " .. jumpGame.current_round_score
    love.graphics.print(round_score_text, 10, 10)

    -- Show total score from players table if available
    if playersTable and playersTable[localPlayerId] then
        local total_score_text = "Total Score: " .. (playersTable[localPlayerId].totalScore or 0)
        love.graphics.print(total_score_text, 10, 30)
    end
end

function jumpGame.reset(playersTable) 
    jumpGame.createPlatforms()
    jumpGame.hit_platforms = {}
    jumpGame.score = 0
    jumpGame.timer = (musicHandler.beatInterval * 8)-- - (musicHandler.beatInterval / 2)
    jumpGame.game_over = false
    jumpGame.player.rect.x = 100
    jumpGame.player.rect.y = 500
    jumpGame.player.dy = 0
    jumpGame.camera_y = 0
    jumpGame.has_first_jump = false
    jumpGame.has_second_jump = false
    jumpGame.current_round_score = 0

    -- clear ghost positions if we have a players table
    if playersTable then
        for id, player in pairs(playersTable) do
            player.jumpX = nil
            player.jumpY = nil
        end
    end
end

function jumpGame.createPlatforms()
    -- base platforms
    jumpGame.platforms = {
        { rect = { x = 50, y = 500, width = 700, height = 20 } },
        { rect = { x = 100, y = 400, width = 100, height = 10 } },
        { rect = { x = 300, y = 325, width = 100, height = 10 } },
        { rect = { x = 500, y = 250, width = 100, height = 10 } },
        { rect = { x = 200, y = 175, width = 100, height = 10 } },
        { rect = { x = 400, y = 100, width = 100, height = 10 } }
    }

    -- generate additional random platforms
    local current_y = 100
    local num_extra_platforms = 100
    for i = 1, num_extra_platforms do
        local platform_x = math.random(50, 700)
        current_y = current_y - 75
        table.insert(jumpGame.platforms, { rect = { x = platform_x, y = current_y, width = 100, height = 10 } })
    end
end

function jumpGame.keypressed(key) -- going to need this for later
    if key == "1" then
        jumpGame.game_speed = 0.5
    elseif key == "2" then
        jumpGame.game_speed = 1
    elseif key == "3" then
        jumpGame.game_speed = 2
    end
end

return jumpGame
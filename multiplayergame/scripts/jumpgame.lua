local jumpGame = {}
local musicHandler = require "scripts.musichandler"
local BaseGame = require "scripts.core.base_game"
local constants = require "scripts.core.constants"
local logger = require "scripts.core.logger"
local input = require "scripts.core.input"
local ui = require "scripts.core.ui"
local PartyMode = require "scripts.core.party_mode"

-- Initialize base game functionality
jumpGame.baseGame = BaseGame:new("JumpGame")

-- Game-specific properties
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
jumpGame.camera_smoothness = 0.1

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
    -- Window size is now handled by the main scaling system

    jumpGame.background_image = love.graphics.newImage("images/JKGame.png")

    local BASE_HEIGHT = constants.BASE_HEIGHT
    jumpGame.player.rect = { x = 100, y = BASE_HEIGHT - 130, width = 30, height = 30 }  -- Spawn on ground platform
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
    
    -- Initialize base game timer
    jumpGame.baseGame.gameTimer.duration = musicHandler.beatInterval * 8
    jumpGame.baseGame.gameTimer.remaining = musicHandler.beatInterval * 8
    
    logger.info("JumpGame", "Game loaded")
end

function jumpGame.slowClock(dt)
    return dt * jumpGame.game_speed
end

function jumpGame.setPlayerColor(color)
    jumpGame.baseGame:setPlayerColor(color)
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

    if not jumpGame.baseGame.game_over then
        dt = jumpGame.slowClock(dt)
        jumpGame.updateParticles(dt)
        
        local dx, dy = input.getMovementInput()
        if dx ~= 0 then
            jumpGame.player.rect.x = jumpGame.player.rect.x + dx * jumpGame.move_speed * dt * 150
        end
        
        -- Keep player within base resolution bounds
        local BASE_WIDTH = constants.BASE_WIDTH
        jumpGame.player.rect.x = math.max(0, math.min(BASE_WIDTH - jumpGame.player.rect.width, jumpGame.player.rect.x))

        if input.isJumpPressed() and not jumpGame.has_first_jump and not jumpGame.player.is_jumping then
            jumpGame.player.dy = -jumpGame.jump_strength
            jumpGame.has_first_jump = true
            jumpGame.player.is_jumping = true
            jumpGame.sounds.jump:clone():play()
        end

        if input.isActionPressed() and jumpGame.has_first_jump and not jumpGame.has_second_jump then
            jumpGame.player.dy = -jumpGame.jump_strength
            jumpGame.has_second_jump = true
            jumpGame.sounds.doublejump:clone():play()
        end

        local previousDy = jumpGame.player.dy

        -- Apply gravity and update position
        jumpGame.player.dy = jumpGame.player.dy + jumpGame.gravity * dt * 90
        jumpGame.player.rect.y = jumpGame.player.rect.y + jumpGame.player.dy * dt * 90

        -- Ground collision (use BASE_HEIGHT to prevent resize issues)
        local GROUND_Y = constants.BASE_HEIGHT
        if jumpGame.player.rect.y + jumpGame.player.rect.height >= GROUND_Y then
            jumpGame.player.rect.y = GROUND_Y - jumpGame.player.rect.height
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
                if previousDy < -2 and not input.isJumpPressed() then -- Threshold for considering it a "snap"
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
            jumpGame.baseGame:addScore(math.floor(-jumpGame.player.dy * dt * 20))
        end

        if on_platform then
            jumpGame.has_first_jump = false
            jumpGame.has_second_jump = false
            jumpGame.player.is_jumping = false
        end

        -- Camera follow (use BASE_HEIGHT to prevent resize issues)
        local target_camera_y = jumpGame.player.rect.y - constants.BASE_HEIGHT / 2
        jumpGame.camera_y = jumpGame.camera_y + (target_camera_y - jumpGame.camera_y) * jumpGame.camera_smoothness

        -- Timer countdown
        jumpGame.baseGame.gameTimer.remaining = jumpGame.baseGame.gameTimer.remaining - dt
        if jumpGame.baseGame.gameTimer.remaining <= 0 then
            jumpGame.baseGame.gameTimer.remaining = 0
            jumpGame.baseGame.game_over = true

            -- Store score in players table for round win determination
            if _G.localPlayer and _G.localPlayer.id and _G.players and _G.players[_G.localPlayer.id] then
                _G.players[_G.localPlayer.id].jumpScore = jumpGame.baseGame.current_round_score
            end
            
            -- Send score to server for winner determination
            if _G.safeSend and _G.server then
                _G.safeSend(_G.server, string.format("jump_score_sync,%d,%d", _G.localPlayer.id, jumpGame.baseGame.current_round_score))
                logger.debug("JumpGame", "Sent score to server: " .. jumpGame.baseGame.current_round_score)
            end
            
            -- Handle party mode transition or return to lobby
            if PartyMode.isActive() then
                -- Let party mode system handle the transition
                PartyMode.handleGameEnd("jumpgame")
                logger.info("JumpGame", "Party mode transition initiated")
            else
                -- Return to lobby for single game mode
                _G.gameState = _G.returnState
                logger.info("JumpGame", "Returning to lobby")
            end
        end
    end
end

function jumpGame.draw(playersTable, localPlayerId)
    -- Get current screen dimensions
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()
    local base_width = constants.BASE_WIDTH
    local base_height = constants.BASE_HEIGHT
    
    -- Calculate scaling to fit base resolution on screen
    local scale_x = screen_width / base_width
    local scale_y = screen_height / base_height
    local scale = math.min(scale_x, scale_y)
    
    -- Calculate offsets to center the game
    local offset_x = (screen_width - base_width * scale) / 2
    local offset_y = (screen_height - base_height * scale) / 2
    
    -- Apply scaling and centering
    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)
    love.graphics.scale(scale, scale)
    
    local bg_width, bg_height = jumpGame.background_image:getWidth(), jumpGame.background_image:getHeight()
    local background_scale = 1.25
    local background_x = (base_width - (bg_width * background_scale)) / 2
    local background_parallax = 0.5
    local background_y = base_height - (jumpGame.camera_y * background_parallax % (bg_height * background_scale))

    -- Draw background tiles
    local num_tiles = math.ceil(base_height / (bg_height * background_scale)) + 2
    for i = 0, num_tiles do
        love.graphics.draw(
            jumpGame.background_image,
            background_x,
            background_y - (i * bg_height * background_scale),
            0,
            background_scale,
            background_scale
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
        
        ui.setColor(pulseColor[1], pulseColor[2], pulseColor[3])
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
            ui.setColor(
                particle.color[1],
                particle.color[2],
                particle.color[3],
                particle.lifetime / jumpGame.particleLifetime
            )
            love.graphics.circle("fill", particle.x, particle.y, 4)
        end
    end

    -- Draw main player
    ui.drawPlayer(
        jumpGame.player.rect.x, 
        jumpGame.player.rect.y, 
        jumpGame.player.rect.width, 
        jumpGame.player.rect.height,
        jumpGame.baseGame.playerColor,
        playersTable and playersTable[localPlayerId] and playersTable[localPlayerId].facePoints
    )

    -- draw ghost players
    if playersTable then
        for id, player in pairs(playersTable) do
            if id ~= localPlayerId and player.jumpX and player.jumpY then
                ui.drawGhostPlayer(
                    player.jumpX, 
                    player.jumpY,
                    jumpGame.player.rect.width, 
                    jumpGame.player.rect.height,
                    player.color,
                    player.facePoints
                )
            end
        end
    end

    love.graphics.pop() -- this works somehow

    -- Draw UI elements
    love.graphics.setColor(1, 1, 1)
    local round_score_text = "Round Score: " .. jumpGame.baseGame.current_round_score
    love.graphics.print(round_score_text, 10, 10)

    -- Show total score from players table if available
    if playersTable and playersTable[localPlayerId] then
        local total_score_text = "Total Score: " .. (playersTable[localPlayerId].totalScore or 0)
        love.graphics.print(total_score_text, 10, 30)
    end
    
    -- Pop the scaling transform
    love.graphics.pop()
end

function jumpGame.reset(playersTable) 
    jumpGame.createPlatforms()
    jumpGame.hit_platforms = {}
    jumpGame.score = 0
    jumpGame.baseGame:initialize()
    jumpGame.baseGame.gameTimer.duration = musicHandler.beatInterval * 8
    jumpGame.baseGame.gameTimer.remaining = musicHandler.beatInterval * 8
    local BASE_HEIGHT = constants.BASE_HEIGHT
    jumpGame.player.rect.x = 100
    jumpGame.player.rect.y = BASE_HEIGHT - 130  -- Spawn on ground platform
    jumpGame.player.dy = 0
    jumpGame.camera_y = 0
    jumpGame.has_first_jump = false
    jumpGame.has_second_jump = false

    -- clear ghost positions if we have a players table
    if playersTable then
        for id, player in pairs(playersTable) do
            player.jumpX = nil
            player.jumpY = nil
        end
    end
end

function jumpGame.createPlatforms()
    local BASE_WIDTH = constants.BASE_WIDTH
    local BASE_HEIGHT = constants.BASE_HEIGHT
    
    -- base platforms
    jumpGame.platforms = {
        { rect = { x = 50, y = BASE_HEIGHT - 100, width = BASE_WIDTH - 100, height = 20 } },
        { rect = { x = 100, y = BASE_HEIGHT - 200, width = 100, height = 10 } },
        { rect = { x = 300, y = BASE_HEIGHT - 275, width = 100, height = 10 } },
        { rect = { x = 500, y = BASE_HEIGHT - 350, width = 100, height = 10 } },
        { rect = { x = 200, y = BASE_HEIGHT - 425, width = 100, height = 10 } },
        { rect = { x = 400, y = BASE_HEIGHT - 500, width = 100, height = 10 } }
    }

    -- generate additional random platforms
    local current_y = BASE_HEIGHT - 500
    local num_extra_platforms = 100
    for i = 1, num_extra_platforms do
        local platform_x = math.random(50, BASE_WIDTH - 150)
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
-- ============================================================================
-- JUMP GAME MODE
-- ============================================================================
-- Converted from scripts/jumpgame.lua to fit new modular architecture
-- Original mechanics and gameplay preserved

local M = {}
local musicHandler = require "src.game.systems.musichandler"
local debugConsole = _G.debugConsole or require "src.core.debugconsole"
local gameUI = require "src.game.systems.gameui"

-- State variables
M.player = {}
M.platforms = {}
M.gravity = 0.25
M.jump_strength = 8
M.move_speed = 2
M.camera_y = 0
M.has_first_jump = false
M.has_second_jump = false
M.game_speed = 1
M.score = 0
M.hit_platforms = {}
M.background_image = nil
M.timer = (musicHandler.beatInterval * 8)
M.game_over = false
M.camera_smoothness = 0.1
M.playerColor = {1, 1, 1}  
M.current_round_score = 0

M.particles = {}
M.particleLifetime = 0.5
M.particleCount = 10

-- Seed for deterministic platform generation
M.seed = 0
M.random = love.math.newRandomGenerator()
M.partyMode = false
M.isHost = false
M.showTabScores = false  -- Tab key pressed

M.sounds = {
    jump = love.audio.newSource("sounds/jumpgame-jump.mp3", "static"),
    doublejump = love.audio.newSource("sounds/jumpgame-double.mp3", "static"),
    perfectlanding = love.audio.newSource("sounds/jumpgame-skill.mp3", "static")
}

-- Sound editing
M.sounds.jump:setPitch(1.5)
M.sounds.doublejump:setVolume(0.3)
M.sounds.perfectlanding:setVolume(0.5)

M.platformEffects = {
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

function M.createParticles(x, y, velocity)
    local particles = {}
    for i = 1, M.particleCount do
        local angle = math.random() * math.pi * 2
        local speed = math.random(50, 100)
        table.insert(particles, {
            x = x,
            y = y,
            dx = math.cos(angle) * speed,
            dy = math.sin(angle) * speed - math.abs(velocity),
            lifetime = M.particleLifetime,
            color = {0, 0.5, 1}  
        })
    end
    table.insert(M.particles, particles)
end

function M.updateParticles(dt)
    for i = #M.particles, 1, -1 do
        local particleGroup = M.particles[i]
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
                particle.dy = particle.dy + M.gravity * 60 * dt
            end
        end
        
        if allDead then
            table.remove(M.particles, i)
        end
    end
end

function M.load(args)
    args = args or {}
    M.partyMode = args.partyMode or false
    M.isHost = args.isHost or false
    
    love.window.setTitle("Jump Game")
    
    M.background_image = love.graphics.newImage("images/JKGame.png")
    
    local BASE_HEIGHT = _G.BASE_HEIGHT or 600
    M.player.rect = { x = 100, y = BASE_HEIGHT - 130, width = 30, height = 30 }
    M.player.dy = 0
    M.player.is_jumping = false
    
    -- Initialize with seed if provided, otherwise generate one for host
    if args.seed then
        M.setSeed(args.seed)
        debugConsole.addMessage("[Jump] Using provided seed: " .. args.seed)
    elseif args.isHost then
        local seed = os.time() + love.timer.getTime() * 10000
        M.setSeed(seed)
        debugConsole.addMessage("[Jump] Host generated seed: " .. seed)
    else
        -- Fallback: create platforms without seed
        M.createPlatforms()
    end
    
    -- Clear any existing effects first
    musicHandler.removeEffect("platforms")
    musicHandler.removeEffect("platform_pulse")
    
    -- Add the combo effect first
    musicHandler.addEffect("platforms", "combo", {
        scaleAmount = 0.1,
        rotateAmount = math.pi/32,
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

function M.slowClock(dt)
    return dt * M.game_speed
end

function M.setPlayerColor(color)
    M.playerColor = color
end

function M.writeScoreToFile()
    local new_score = "Score: " .. M.score .. "\n"
    local existing_scores = ""
    if love.filesystem.getInfo("score.txt") then
        existing_scores = love.filesystem.read("score.txt")
    end
    local updated_scores = existing_scores .. new_score
    love.filesystem.write("score.txt", updated_scores)
end

function M.update(dt)
    local color = musicHandler.getCurrentColor("platforms")
    musicHandler.update(dt)
    
    if not M.game_over then
        dt = M.slowClock(dt)
        M.updateParticles(dt)
        
        local keys = love.keyboard.isDown
        if keys("a") then
            M.player.rect.x = M.player.rect.x - M.move_speed * dt * 150
        end
        if keys("d") then
            M.player.rect.x = M.player.rect.x + M.move_speed * dt * 150
        end
        
        -- Keep player within base resolution bounds
        local BASE_WIDTH = _G.BASE_WIDTH or 800
        M.player.rect.x = math.max(0, math.min(BASE_WIDTH - M.player.rect.width, M.player.rect.x))
        
        if keys("w") and not M.has_first_jump and not M.player.is_jumping then
            M.player.dy = -M.jump_strength
            M.has_first_jump = true
            M.player.is_jumping = true
            M.sounds.jump:clone():play()
        end
        
        if keys("space") and M.has_first_jump and not M.has_second_jump then
            M.player.dy = -M.jump_strength
            M.has_second_jump = true
            M.sounds.doublejump:clone():play()
        end
        
        local previousDy = M.player.dy
        
        -- Apply gravity and update position
        M.player.dy = M.player.dy + M.gravity * dt * 90
        M.player.rect.y = M.player.rect.y + M.player.dy * dt * 90
        
        -- Ground collision
        local GROUND_Y = _G.BASE_HEIGHT or 600
        if M.player.rect.y + M.player.rect.height >= GROUND_Y then
            M.player.rect.y = GROUND_Y - M.player.rect.height
            M.player.dy = 0
            M.has_first_jump = false
            M.has_second_jump = false
            M.player.is_jumping = false
        end
        
        -- Platform collision
        local on_platform = false
        for _, platform in ipairs(M.platforms) do
            if M.player.rect.x < platform.rect.x + platform.rect.width and
                M.player.rect.x + M.player.rect.width > platform.rect.x and
                M.player.rect.y + M.player.rect.height >= platform.rect.y and
                M.player.rect.y + M.player.rect.height <= platform.rect.y + platform.rect.height then
                
                -- Check if this was a "snap" (significant downward velocity suddenly stopped)
                if previousDy < -2 and not love.keyboard.isDown('w') then
                    M.sounds.perfectlanding:clone():play()
                    M.createParticles(
                        M.player.rect.x + M.player.rect.width / 2,
                        M.player.rect.y + M.player.rect.height,
                        previousDy
                    )
                end
                
                M.player.rect.y = platform.rect.y - M.player.rect.height
                M.player.dy = 0
                on_platform = true
                
                local platform_id = platform.rect.x .. "_" .. platform.rect.y
                if not M.hit_platforms[platform_id] then
                    M.hit_platforms[platform_id] = true
                end
            end
        end
        
        -- Update score based on upward movement
        if M.player.dy < 0 then
            M.current_round_score = M.current_round_score + math.floor(-M.player.dy * dt * 20)
        end
        
        if on_platform then
            M.has_first_jump = false
            M.has_second_jump = false
            M.player.is_jumping = false
        end
        
        -- Camera follow
        local target_camera_y = M.player.rect.y - (_G.BASE_HEIGHT or 600) / 2
        M.camera_y = M.camera_y + (target_camera_y - M.camera_y) * M.camera_smoothness
        
        -- Send player position every frame for multiplayer sync
        if _G.localPlayer and _G.localPlayer.id then
            local events = require("src.core.events")
            events.emit("player:jump_position", {
                id = _G.localPlayer.id,
                x = M.player.rect.x,
                y = M.player.rect.y,
                color = _G.localPlayer.color or M.playerColor
            })
        end
        
        -- Timer countdown (TODO: refactor to use timing.lua)
        M.timer = M.timer - dt
        if M.timer <= 0 then
            M.timer = 0
            M.game_over = true
            
            -- Store score in players table for round win determination
            if _G.localPlayer and _G.localPlayer.id and _G.players and _G.players[_G.localPlayer.id] then
                _G.players[_G.localPlayer.id].jumpScore = M.current_round_score
            end
            
            -- Send score via event system
            local events = require("src.core.events")
            events.emit("player:jump_score", {
                id = _G.localPlayer.id,
                score = M.current_round_score
            })
        end
    end
end

function M.draw(playersTable, localPlayerId)
    local base_width = _G.BASE_WIDTH or 800
    local base_height = _G.BASE_HEIGHT or 600
    
    -- Draw background (no transform needed, handled by global scaling)
    local bg_width, bg_height = M.background_image:getWidth(), M.background_image:getHeight()
    local background_scale = (base_width / bg_width) -- Scale to fit screen width
    local background_x = 0 -- Center aligned
    local background_parallax = 0.5
    local background_y = base_height - ((M.camera_y * background_parallax) % (bg_height * background_scale))
    
    -- Draw background tiles
    local num_tiles = math.ceil(base_height / (bg_height * background_scale)) + 2
    for i = 0, num_tiles do
        love.graphics.draw(
            M.background_image,
            background_x,
            background_y - (i * bg_height * background_scale),
            0,
            background_scale,
            background_scale
        )
    end
    
    love.graphics.push()
    love.graphics.translate(0, -math.floor(M.camera_y))
    
    for _, platform in ipairs(M.platforms) do
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
    for _, particleGroup in ipairs(M.particles) do
        for _, particle in ipairs(particleGroup) do
            love.graphics.setColor(
                particle.color[1],
                particle.color[2],
                particle.color[3],
                particle.lifetime / M.particleLifetime
            )
            love.graphics.circle("fill", particle.x, particle.y, 4)
        end
    end
    
    -- Draw main player
    love.graphics.setColor(M.playerColor[1], M.playerColor[2], M.playerColor[3])
    love.graphics.rectangle("fill", 
        M.player.rect.x, 
        M.player.rect.y, 
        M.player.rect.width, 
        M.player.rect.height
    )
    
    -- Draw local player's face and score
    if playersTable and playersTable[localPlayerId] then
        if playersTable[localPlayerId].facePoints then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                playersTable[localPlayerId].facePoints,
                M.player.rect.x,
                M.player.rect.y,
                0,
                M.player.rect.width/100,
                M.player.rect.height/100
            )
        end
    end
    
    -- Draw ghost players
    if playersTable then
        for id, player in pairs(playersTable) do
            if id ~= localPlayerId and player.jumpX and player.jumpY then
                -- Draw ghost player body
                love.graphics.setColor(player.color[1], player.color[2], player.color[3], 0.5)
                love.graphics.rectangle("fill", 
                    player.jumpX, 
                    player.jumpY,
                    M.player.rect.width, 
                    M.player.rect.height
                )
                
                -- Draw ghost player face if available
                if player.facePoints then
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.draw(
                        player.facePoints,
                        player.jumpX,
                        player.jumpY,
                        0,
                        M.player.rect.width/100,
                        M.player.rect.height/100
                    )
                end
            end
        end
    end
    
    love.graphics.pop()
    
    -- UI with new system
    gameUI.drawScore(M.current_round_score, 10, 10)
    
    -- Tab score overlay
    if M.showTabScores and playersTable then
        gameUI.drawTabScores(playersTable, localPlayerId, "jump")
    end
end

function M.reset(playersTable) 
    M.createPlatforms()
    M.hit_platforms = {}
    M.score = 0
    M.timer = (musicHandler.beatInterval * 8)
    M.game_over = false
    local BASE_HEIGHT = _G.BASE_HEIGHT or 600
    M.player.rect.x = 100
    M.player.rect.y = BASE_HEIGHT - 130
    M.player.dy = 0
    M.camera_y = 0
    M.has_first_jump = false
    M.has_second_jump = false
    M.current_round_score = 0
    
    -- Clear ghost positions if we have a players table
    if playersTable then
        for id, player in pairs(playersTable) do
            player.jumpX = nil
            player.jumpY = nil
        end
    end
end

function M.setSeed(seed)
    M.seed = seed
    M.random:setSeed(seed)
    M.createPlatforms()
end

function M.createPlatforms()
    local BASE_WIDTH = _G.BASE_WIDTH or 800
    local BASE_HEIGHT = _G.BASE_HEIGHT or 600
    
    -- Base platforms (same for everyone)
    M.platforms = {
        { rect = { x = 50, y = BASE_HEIGHT - 100, width = BASE_WIDTH - 100, height = 20 } },
        { rect = { x = 100, y = BASE_HEIGHT - 200, width = 100, height = 10 } },
        { rect = { x = 300, y = BASE_HEIGHT - 275, width = 100, height = 10 } },
        { rect = { x = 500, y = BASE_HEIGHT - 350, width = 100, height = 10 } },
        { rect = { x = 200, y = BASE_HEIGHT - 425, width = 100, height = 10 } },
        { rect = { x = 400, y = BASE_HEIGHT - 500, width = 100, height = 10 } }
    }
    
    -- Generate additional platforms using seed-based randomness
    local current_y = BASE_HEIGHT - 500
    local num_extra_platforms = 100
    for i = 1, num_extra_platforms do
        local platform_x = M.random:random(50, BASE_WIDTH - 150)
        current_y = current_y - 75
        table.insert(M.platforms, { rect = { x = platform_x, y = current_y, width = 100, height = 10 } })
    end
    
    debugConsole.addMessage("[Jump] Generated " .. #M.platforms .. " platforms with seed: " .. M.seed)
end

function M.keypressed(key)
    if key == "tab" then
        M.showTabScores = true
    elseif key == "1" then
        M.game_speed = 0.5
    elseif key == "2" then
        M.game_speed = 1
    elseif key == "3" then
        M.game_speed = 2
    end
end

function M.keyreleased(key)
    if key == "tab" then
        M.showTabScores = false
    end
end

return M

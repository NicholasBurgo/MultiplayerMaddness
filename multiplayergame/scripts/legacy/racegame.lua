local raceGame = {}
local debugConsole = require "scripts.debugconsole"
local musicHandler = require "scripts.musichandler"

-- Game state
raceGame.game_over = false
raceGame.current_round_score = 0
raceGame.playerColor = {1, 1, 1}
raceGame.screen_width = 800
raceGame.screen_height = 600
raceGame.camera_x = 0

-- Game settings 
raceGame.gravity = 1000
raceGame.gameLength = 200000
raceGame.scroll_speed = 400
raceGame.max_scroll_speed = 500
raceGame.scroll_speed_increment = 15
raceGame.game_started = false
raceGame.start_timer = 3
raceGame.difficulty_timer = 0
raceGame.difficulty_interval = 20
raceGame.shrink_timer = 15
raceGame.spiral_overlay_progress = 0
raceGame.spiral_overlay_speed = 0.01
raceGame.background_speed_multiplier = 1
raceGame.max_background_speed_multiplier = 3
raceGame.trail_duration = 5
raceGame.trail_active = false
raceGame.trail_timer = 0
raceGame.timer = (musicHandler.beatInterval * 8)

-- Player settings
raceGame.player = {
    x = 200,
    y = 400,
    width = 50,
    height = 50,
    speed = 600,
    normal_speed = 600,
    slowed_speed = 300,
    dy = 0,
    jump_strength = -600,
    on_ground = false,
    jump_count = 0,    
    max_jumps = 2,     
    points = 0,
    powerUpsCollected = {},
    max_powerUps = 1,
    active_effects = {},
    dropping = false, 
    drop_cooldown = 0  
}

local sounds = {
    powerup = love.audio.newSource("sounds/laser.mp3", "static") -- reusing laser sound for now
}

-- Game objects
raceGame.platforms = {}
raceGame.obstacles = {}
raceGame.powerUps = {}
raceGame.trail_segments = {}
raceGame.lasers = {}
raceGame.stars = {}
raceGame.keysPressed = {}


function raceGame.load()
    -- Reset game state
    raceGame.game_over = false
    raceGame.current_round_score = 0
    raceGame.camera_x = 0
    raceGame.game_started = false
    raceGame.start_timer = 0
    raceGame.scroll_speed = 400
    raceGame.spiral_overlay_progress = 0
    raceGame.shrink_timer = 15
    raceGame.player.drop_cooldown = 0
    raceGame.player.dropping = false
    raceGame.player.jump_count = 0
    raceGame.player.has_double_jumped = false
    raceGame.player.on_ground = false
    raceGame.timer = (musicHandler.beatInterval * 8)

    raceGame.keysPressed = {}

    -- Reset player
    raceGame.player = {
        x = 200,
        y = 400,
        width = 50,
        height = 50,
        speed = 600,
        normal_speed = 600,
        slowed_speed = 300,
        dy = 0,
        jump_strength = -600,
        on_ground = false,
        jump_count = 0,
        max_jumps = 2,    
        points = 0,
        powerUpsCollected = {},
        max_powerUps = 1,
        is_invincible = false,
        invincibility_timer = 0,
        is_slowed = false,
        slowdown_timer = 0,
        is_stunned = false,
        stun_timer = 0,
        speed_up_active = false,
        speed_up_timer = 0
    }

    -- Create game elements
    raceGame.createStarField()
    raceGame.createPlatforms()
    raceGame.createObstacles()
    raceGame.createPowerUps()

    debugConsole.addMessage("[RaceGame] Game loaded")
end

function raceGame.update(dt)
    if not raceGame.game_started then
        raceGame.start_timer = math.max(0, raceGame.start_timer - dt)
        raceGame.game_started = raceGame.start_timer == 0
        return
    end

    if raceGame.game_over then return end

    raceGame.timer = raceGame.timer - dt
    if raceGame.timer <= 0 then
        raceGame.timer = 0
        raceGame.game_over = true
        
        -- Send final score
        if _G.gameState == "hosting" then
            if _G.players[_G.localPlayer.id] then
                _G.players[_G.localPlayer.id].totalScore = 
                    (_G.players[_G.localPlayer.id].totalScore or 0) + raceGame.current_round_score
                _G.localPlayer.totalScore = _G.players[_G.localPlayer.id].totalScore
            end
            
            -- Broadcast to clients
            for _, client in ipairs(_G.serverClients or {}) do
                safeSend(client, string.format("total_score,%d,%d", 
                    _G.localPlayer.id, 
                    _G.players[_G.localPlayer.id].totalScore))
            end
        else
            if _G.server then
                safeSend(_G.server, "race_score," .. math.floor(raceGame.current_round_score))
            end
        end
        
        if _G.returnState then
            _G.gameState = _G.returnState
        end
        return
    end

    -- Initialize drop_cooldown if it doesn't exist
    if raceGame.player.drop_cooldown == nil then
        raceGame.player.drop_cooldown = 0
    end

    -- Update drop cooldown
    if raceGame.player.drop_cooldown > 0 then
        raceGame.player.drop_cooldown = raceGame.player.drop_cooldown - dt
    end

    -- Update difficulty
    raceGame.difficulty_timer = raceGame.difficulty_timer + dt
    if raceGame.difficulty_timer >= raceGame.difficulty_interval then
        raceGame.difficulty_timer = 0
        raceGame.scroll_speed = math.min(raceGame.max_scroll_speed, 
            raceGame.scroll_speed + raceGame.scroll_speed_increment)
    end

    -- Handle horizontal movement
    local moveSpeed = raceGame.player.speed
    if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
        raceGame.player.x = raceGame.player.x - moveSpeed * dt
    end
    if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
        raceGame.player.x = raceGame.player.x + moveSpeed * dt
    end

    -- Handle dropping through platforms
    if love.keyboard.isDown('s') and raceGame.player.on_ground and 
        (raceGame.player.drop_cooldown == nil or raceGame.player.drop_cooldown <= 0) then
        raceGame.player.dropping = true
        raceGame.player.drop_cooldown = 0.1
        raceGame.player.on_ground = false
        raceGame.player.dy = 50
    else
        raceGame.player.dropping = false
    end

    -- Apply gravity
    raceGame.player.dy = (raceGame.player.dy + raceGame.gravity * dt) + 3
    
    -- Handle first jump with 'W'
    if (love.keyboard.isDown('w') or love.keyboard.isDown('up')) and raceGame.player.on_ground then
        raceGame.player.dy = raceGame.player.jump_strength
        raceGame.player.jump_count = 1
        raceGame.player.on_ground = false
    end
    
    -- Handle double jump with Space (only in midair after first jump)
    if love.keyboard.isDown('space') and not raceGame.player.on_ground 
        and not raceGame.player.has_double_jumped then
        raceGame.player.dy = raceGame.player.jump_strength
        raceGame.player.has_double_jumped = true
    end

    -- Update vertical position
    raceGame.player.y = raceGame.player.y + raceGame.player.dy * dt

    -- Update camera
    raceGame.camera_x = raceGame.camera_x + raceGame.scroll_speed * dt

    -- Keep player within camera bounds
    if raceGame.player.x < raceGame.camera_x then
        raceGame.player.x = raceGame.camera_x
    end

    -- Platform collisions with drop-through mechanic
    raceGame.player.on_ground = false
    for _, platform in ipairs(raceGame.platforms) do
        if raceGame.checkCollision(raceGame.player, platform) then
            if raceGame.player.dy > 0 and not raceGame.player.dropping and 
               raceGame.player.y + raceGame.player.height - raceGame.player.dy * dt <= platform.y then
                raceGame.player.y = platform.y - raceGame.player.height
                raceGame.player.dy = 0
                raceGame.player.on_ground = true
                raceGame.player.jump_count = 0
                raceGame.player.has_double_jumped = false  -- Reset double jump when landing
            end
        end
    end

    -- Handle obstacle collisions
    for i = #raceGame.obstacles, 1, -1 do
        local obstacle = raceGame.obstacles[i]
        if raceGame.checkCollision(raceGame.player, obstacle) then
            if obstacle.type == 'slow' and not raceGame.player.is_invincible then
                raceGame.player.is_slowed = true
                raceGame.player.slowdown_timer = 1  -- 1 second slowdown
                raceGame.player.speed = raceGame.player.slowed_speed
                debugConsole.addMessage("[RaceGame] Player slowed for 1 second")
            elseif obstacle.type == 'stun' and not raceGame.player.is_invincible then
                raceGame.player.is_stunned = true
                raceGame.player.stun_timer = 0.5  -- 0.5 second stun
                debugConsole.addMessage("[RaceGame] Player stunned for 0.5 seconds")
            end
            table.remove(raceGame.obstacles, i)
        end
    end

    -- Update stun effect
    if raceGame.player.is_stunned then
        raceGame.player.stun_timer = raceGame.player.stun_timer - dt
        if raceGame.player.stun_timer <= 0 then
            raceGame.player.is_stunned = false
            debugConsole.addMessage("[RaceGame] Stun effect ended")
        end
    end

    -- Update slow effect
    if raceGame.player.is_slowed then
        raceGame.player.slowdown_timer = raceGame.player.slowdown_timer - dt
        if raceGame.player.slowdown_timer <= 0 then
            raceGame.player.is_slowed = false
            raceGame.player.speed = raceGame.player.normal_speed
            debugConsole.addMessage("[RaceGame] Slow effect ended, speed restored")
        end
    end

    -- Handle powerup collisions
    for i = #raceGame.powerUps, 1, -1 do
        local powerUp = raceGame.powerUps[i]
        if raceGame.checkCollision(raceGame.player, powerUp) then
            if raceGame.collectPowerUp(powerUp) then
                table.remove(raceGame.powerUps, i)
            end
        end
    end

    -- Update power-up timers
    if raceGame.player.speed_up_active then
        raceGame.player.speed_up_timer = raceGame.player.speed_up_timer - dt
        if raceGame.player.speed_up_timer <= 0 then
            raceGame.player.speed_up_active = false
            raceGame.player.speed = raceGame.player.normal_speed
            debugConsole.addMessage("[RaceGame] Speed boost expired")
        end
    end
    
    if raceGame.player.is_invincible then
        raceGame.player.invincibility_timer = raceGame.player.invincibility_timer - dt
        if raceGame.player.invincibility_timer <= 0 then
            raceGame.player.is_invincible = false
            debugConsole.addMessage("[RaceGame] Shield expired")
        end
    end
    
    if raceGame.trail_active then
        raceGame.trail_timer = raceGame.trail_timer - dt
        if raceGame.trail_timer <= 0 then
            raceGame.trail_active = false
            debugConsole.addMessage("[RaceGame] Trail expired")
        else
            -- add trail segments
            if raceGame.player.on_ground then
                table.insert(raceGame.trail_segments, {
                    x = raceGame.player.x + raceGame.player.width/2,
                    y = raceGame.player.y + raceGame.player.height,
                    size = 10 + math.random(-3, 3),
                    angle = math.rad(math.random(0, 360)),
                    life = 1,
                    max_life = 1
                })
            end
        end
            -- Update existing trail segments
        for i = #raceGame.trail_segments, 1, -1 do
            local seg = raceGame.trail_segments[i]
            seg.life = seg.life - dt * 1.5
            seg.y = seg.y - dt * 30  -- Float upward
            seg.x = seg.x + math.random(-2, 2)  -- Random horizontal movement
            seg.angle = seg.angle + dt * math.rad(30)  -- Rotate
            
            -- Remove old segments
            if seg.life <= 0 or seg.x < raceGame.camera_x then
                table.remove(raceGame.trail_segments, i)
            end
        end
        -- Check for obstacle collisions with trail
        for i = #raceGame.obstacles, 1, -1 do
            local obstacle = raceGame.obstacles[i]
            if raceGame.checkTrailCollision(obstacle) then
                table.remove(raceGame.obstacles, i)
                debugConsole.addMessage("[RaceGame] Obstacle destroyed by trail!")
            end
        end
    end

    for i = #raceGame.lasers, 1, -1 do
        local laser = raceGame.lasers[i]
        laser.time = laser.time + dt
        if laser.time >= laser.duration then
            table.remove(raceGame.lasers, i)
        end
    end

    -- Update scoring
    raceGame.current_round_score = math.floor(raceGame.camera_x / 20)

    -- Update effects
    raceGame.updateStars(dt)
    
    -- Check game over conditions
    if raceGame.playerOutOfBounds() then
        raceGame.game_over = true
    end

    -- Update shrink timer
    if raceGame.shrink_timer > 0 then
        raceGame.shrink_timer = raceGame.shrink_timer - dt
    else
        raceGame.spiral_overlay_progress = raceGame.spiral_overlay_progress + 
            raceGame.spiral_overlay_speed * dt
        if raceGame.spiral_overlay_progress >= 1 then
            raceGame.spiral_overlay_progress = 1
            raceGame.game_over = true
        end
    end
end

function raceGame.draw(playersTable, localPlayerId)
    -- Clear background
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, raceGame.screen_width, raceGame.screen_height)
    
    -- Draw stars with parallax effect
    raceGame.drawStars()
    
    -- Set up camera
    love.graphics.push()
    love.graphics.translate(-raceGame.camera_x, 0)
    
    -- Draw game elements
    raceGame.drawPlatforms()
    raceGame.drawObstacles()
    raceGame.drawPowerUps()
    raceGame.drawLasers()
    raceGame.drawTrail()
    
    -- Draw other players
    if playersTable then
        for id, player in pairs(playersTable) do
            if id ~= localPlayerId and player.raceX and player.raceY then
                -- Draw ghost player body
                love.graphics.setColor(player.color[1], player.color[2], player.color[3], 0.5)
                love.graphics.rectangle('fill',
                    player.raceX,
                    player.raceY,
                    raceGame.player.width,
                    raceGame.player.height
                )
                
                -- Draw their face if available
                if player.facePoints then
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.draw(
                        player.facePoints,
                        player.raceX,
                        player.raceY,
                        0,
                        raceGame.player.width/100,
                        raceGame.player.height/100
                    )
                end
                
                love.graphics.setColor(1, 1, 0, 0.8)
                love.graphics.printf(
                    "Score: " .. math.floor(player.totalScore or 0),
                    player.raceX - 50,
                    player.raceY - 40,
                    100,
                    "center"
                )
            end
        end
    end
    
    -- Draw local player
    if playersTable and playersTable[localPlayerId] then
        love.graphics.setColor(raceGame.playerColor)
        love.graphics.rectangle('fill',
            raceGame.player.x,
            raceGame.player.y,
            raceGame.player.width,
            raceGame.player.height
        )
        
        -- Draw face
        if playersTable[localPlayerId].facePoints then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                playersTable[localPlayerId].facePoints,
                raceGame.player.x,
                raceGame.player.y,
                0,
                raceGame.player.width/100,
                raceGame.player.height/100
            )
        end
    end
    
    love.graphics.pop()

    -- Draw UI elements
    raceGame.drawUI(playersTable, localPlayerId)
    
    -- Draw spiral overlay
    raceGame.drawSpiralOverlay(raceGame.spiral_overlay_progress)
end

function raceGame.updateStars(dt)
    for layer, star_layer in ipairs(raceGame.stars) do
        for _, star in ipairs(star_layer) do
            star.x = star.x - (star.speed * raceGame.background_speed_multiplier) * dt
            if star.x < 0 then
                star.x = raceGame.screen_width
                star.y = math.random(0, raceGame.screen_height)
            end
        end
    end
end

function raceGame.drawStars()
    for layer, star_layer in ipairs(raceGame.stars) do
        local brightness = 0.5 + (layer / #raceGame.stars) * 0.5
        love.graphics.setColor(brightness, brightness, brightness)
        for _, star in ipairs(star_layer) do
            love.graphics.rectangle('fill', star.x, star.y, star.size, star.size)
        end
    end
end

function raceGame.createStarField()
    raceGame.stars = {}
    local star_layers = 3
    for layer = 1, star_layers do
        raceGame.stars[layer] = {}
        local num_stars = 100 + (layer - 1) * 50
        for i = 1, num_stars do
            raceGame.stars[layer][i] = {
                x = math.random(0, raceGame.screen_width),
                y = math.random(0, raceGame.screen_height),
                size = math.random(1, 3),
                speed = (layer / star_layers) * 50
            }
        end
    end
end

function raceGame.drawPlatforms()
    for _, platform in ipairs(raceGame.platforms) do
        love.graphics.setColor(0.2, 0.2, 0.5)
        love.graphics.rectangle('fill', platform.x, platform.y, platform.width, platform.height)
        love.graphics.setColor(0.4, 0.4, 0.7)
        love.graphics.rectangle('fill', platform.x, platform.y, platform.width, platform.height / 2)
        love.graphics.setColor(1, 1, 1)
        for _, star in ipairs(platform.stars) do
            love.graphics.points(star.x, star.y)
        end
    end
end

function raceGame.createPlatforms()
    raceGame.platforms = {}
    local platform_height = 20
    local platform_y_positions = {200, 350, 500}
    local bottom_platform_y = 500
    
    for _, y in ipairs(platform_y_positions) do
        local x = 0
        while x < raceGame.gameLength do
            local gap = math.random(200, 400)
            local length = math.random(500, 800)
            if x < 500 then
                length = 500 - x
                gap = 0
            end
            local platform = {
                x = x,
                y = y,
                width = length,
                height = platform_height,
                stars = {}
            }
            
            -- Add decorative stars to platform
            for i = 1, 5 do
                table.insert(platform.stars, {
                    x = platform.x + math.random(0, platform.width),
                    y = platform.y + math.random(0, platform.height)
                })
            end
            
            table.insert(raceGame.platforms, platform)
            x = x + length + gap
        end
    end
end

function raceGame.drawUI(playersTable, localPlayerId)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Score: ' .. math.floor(raceGame.current_round_score), 10, 10)

    love.graphics.printf(string.format("Time: %.1f", raceGame.timer), 
    0, 10, love.graphics.getWidth(), "center")
    
    if playersTable and playersTable[localPlayerId] then
        love.graphics.print('Total Score: ' .. 
            math.floor(playersTable[localPlayerId].totalScore or 0), 10, 30)
    end
    
    -- Display collected powerups
    love.graphics.print('Collected Powerups:', 10, 50)
    for i, powerUp in ipairs(raceGame.player.powerUpsCollected) do
        love.graphics.print(i .. ': ' .. powerUp.type, 10, 70 + (i-1) * 20)
    end
    
    -- Display active effects
    local activeY = 130
    if raceGame.player.speed_up_active then
        love.graphics.print('Speed Boost: ' .. string.format("%.1f", raceGame.player.speed_up_timer), 10, activeY)
        activeY = activeY + 20
    end
    if raceGame.player.is_invincible then
        love.graphics.print('Shield: ' .. string.format("%.1f", raceGame.player.invincibility_timer), 10, activeY)
        activeY = activeY + 20
    end
    
    if not raceGame.game_started then
        love.graphics.printf('Get Ready: ' .. math.ceil(raceGame.start_timer), 
            0, raceGame.screen_height / 2 - 50, raceGame.screen_width, 'center')
    end
    
    if raceGame.game_over then
        love.graphics.printf('Game Over', 
            0, raceGame.screen_height / 2 - 50, raceGame.screen_width, 'center')
    end
end

function raceGame.drawSpiralOverlay(progress)
    -- Create shrinking circle mask effect
    local radius = (1 - progress) * 
        math.sqrt((raceGame.screen_width/2)^2 + (raceGame.screen_height/2)^2)
    love.graphics.stencil(function()
        love.graphics.circle('fill', raceGame.screen_width/2, raceGame.screen_height/2, radius)
    end, 'replace', 1)
    love.graphics.setStencilTest('less', 1)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, raceGame.screen_width, raceGame.screen_height)
    love.graphics.setStencilTest()
end

function raceGame.drawObstacles()
    for _, obstacle in ipairs(raceGame.obstacles) do
        if obstacle.type == 'slow' then
            raceGame.drawNimbusCloud(obstacle)
        elseif obstacle.type == 'stun' then
            raceGame.drawStunOrb(obstacle)
        end
    end
end

function raceGame.drawNimbusCloud(obstacle)
    local time = love.timer.getTime()
    local num_circles = 5
    love.graphics.setColor(1, 0.9, 0.1, 0.7)
    for i = 1, num_circles do
        local angle = (i / num_circles) * math.pi * 2 + time * 0.5
        local radius = obstacle.width * 0.3
        local offsetX = math.cos(angle) * radius
        local offsetY = math.sin(angle) * radius * 0.5
        love.graphics.circle('fill', 
            obstacle.x + obstacle.width/2 + offsetX, 
            obstacle.y + obstacle.height/2 + offsetY, 
            obstacle.width * 0.2)
    end
end

function raceGame.drawStunOrb(obstacle)
    local time = love.timer.getTime()
    local pulse = math.sin(time * 5) * 0.2 + 0.8
    love.graphics.setColor(0.5, 0, 1, 0.7)
    love.graphics.circle('fill', 
        obstacle.x + obstacle.width/2, 
        obstacle.y + obstacle.height/2, 
        obstacle.width * 0.5 * pulse)
end

function raceGame.createFirePolygon(size)
    local num_points = math.random(3, 5)
    local vertices = {}
    for i = 1, num_points do
        local angle = (i / num_points) * math.pi * 2
        local radius = size + math.random(-size * 0.3, size * 0.3)
        table.insert(vertices, radius * math.cos(angle))
        table.insert(vertices, radius * math.sin(angle))
    end
    return vertices
end

function raceGame.checkCollision(obj1, obj2)
    return obj1.x < obj2.x + obj2.width and
            obj1.x + obj1.width > obj2.x and
            obj1.y < obj2.y + obj2.height and
            obj1.y + obj1.height > obj2.y
end

function raceGame.checkTrailCollision(obstacle)
    for _, segment in ipairs(raceGame.trail_segments) do
        local segmentRect = {
            x = segment.x - segment.size/2,
            y = segment.y - segment.size/2,
            width = segment.size,
            height = segment.size
        }
        if raceGame.checkCollision(obstacle, segmentRect) then
            return true
        end
    end
    return false
end

function raceGame.playerOutOfBounds()
    return raceGame.player.x + raceGame.player.width < raceGame.camera_x or 
            raceGame.player.y > raceGame.screen_height
end

function raceGame.createObstacles()
    raceGame.obstacles = {}
    for _, platform in ipairs(raceGame.platforms) do
        local startX = platform.x + 100
        local endX = platform.x + platform.width - 100
        if endX > startX and endX > 500 then
            if startX < 500 then
                startX = 500
            end
            local x = startX
            while x < endX do
                local obstacleType
                local rand = math.random()
                if rand < 0.2 then
                    obstacleType = 'slow'
                elseif rand < 0.3 then
                    obstacleType = 'stun'
                else
                    x = x + 150
                    goto continue
                end
                
                local obstacleHeight = 50
                table.insert(raceGame.obstacles, {
                    x = x,
                    y = platform.y - obstacleHeight,
                    width = 50,
                    height = obstacleHeight,
                    type = obstacleType
                })
                x = x + 150
                ::continue::
            end
        end
    end
end

function raceGame.createPowerUps()
    raceGame.powerUps = {}
    local powerUpTypes = {'speed', 'shield', 'trail', 'laser'}
    for i = 1, 200 do
        local platform = raceGame.platforms[math.random(1, #raceGame.platforms)]
        local minX = math.max(platform.x + 100, 500)
        local maxX = platform.x + platform.width - 100
        if maxX > minX then
            local x = math.random(minX, maxX)
            local pType = powerUpTypes[math.random(1, #powerUpTypes)]
            table.insert(raceGame.powerUps, {
                x = x,
                y = platform.y - 30,
                width = 30,
                height = 30,
                type = pType
            })
        end
    end
end

function raceGame.collectPowerUp(powerUp)
    if #raceGame.player.powerUpsCollected < raceGame.player.max_powerUps then
        table.insert(raceGame.player.powerUpsCollected, powerUp)
        debugConsole.addMessage("[RaceGame] Collected powerup: " .. powerUp.type)
        -- Play collection sound here 
        return true
    end
    return false
end

function raceGame.drawPowerUps()
    love.graphics.setColor(1, 1, 1)
    for _, powerUp in ipairs(raceGame.powerUps) do
        -- Draw power up circle
        love.graphics.setColor(1, 1, 0)  -- Yellow color
        love.graphics.circle('fill',
            powerUp.x + powerUp.width/2,
            powerUp.y + powerUp.height/2,
            powerUp.width/2)
            
        -- Draw power up type indicator
        love.graphics.setColor(0, 0, 0)
        local letter = powerUp.type:sub(1, 1):upper()
        love.graphics.printf(letter,
            powerUp.x,
            powerUp.y + powerUp.height/4,
            powerUp.width,
            'center')
    end
end

function raceGame.drawLasers()
    love.graphics.setColor(1, 0, 0)
    for _, laser in ipairs(raceGame.lasers) do
        love.graphics.rectangle('fill',
            laser.x,
            laser.y,
            laser.width,
            laser.height)
    end
end

function raceGame.drawTrail()
    for _, segment in ipairs(raceGame.trail_segments) do
        local life_ratio = segment.life / segment.max_life
        local r, g, b, alpha
        
        -- Fire-like color gradient
        if life_ratio > 0.6 then
            r, g, b = 1, 0.5 + math.random() * 0.3, 0  -- Bright orange/yellow
        elseif life_ratio > 0.3 then
            r, g, b = 1, 0.1, 0  -- Deep orange
        else
            r, g, b = 0.2, 0.2, 0.2  -- Smoke gray
        end
        alpha = life_ratio * (0.8 + math.random() * 0.2)
        
        love.graphics.setColor(r, g, b, alpha)
        
        -- Draw fire polygon
        love.graphics.push()
        love.graphics.translate(segment.x, segment.y)
        love.graphics.rotate(segment.angle or math.random() * math.pi * 2)
        local vertices = raceGame.createFirePolygon(segment.size or 10)
        love.graphics.polygon('fill', vertices)
        love.graphics.pop()
    end
end

function raceGame.keypressed(key)
    debugConsole.addMessage("[RaceGame] Key pressed: " .. key)
    
    if key == 'e' then
        debugConsole.addMessage("[RaceGame] E key pressed, powerups collected: " .. 
            #raceGame.player.powerUpsCollected)
        
        if #raceGame.player.powerUpsCollected > 0 then
            local powerUp = table.remove(raceGame.player.powerUpsCollected, 1)
            if powerUp then
                -- Play sound effect
                sounds.powerup:stop()
                sounds.powerup:play()
                
                debugConsole.addMessage("[RaceGame] Activating powerup: " .. powerUp.type)
                raceGame.activateSpecificPowerUp(powerUp.type)
            end
        end
    end
end

function raceGame.keyreleased(key)
    raceGame.keysPressed[key] = false
end

function raceGame.activateSpecificPowerUp(type)
    if type == 'speed' then
        raceGame.player.speed_up_active = true
        raceGame.player.speed_up_timer = 2
        raceGame.player.is_slowed = false
        raceGame.player.speed = raceGame.player.normal_speed * 2
        debugConsole.addMessage("[RaceGame] Speed boost activated! New speed: " .. raceGame.player.speed)
        
    elseif type == 'shield' then
        raceGame.player.is_invincible = true
        raceGame.player.invincibility_timer = 4
        debugConsole.addMessage("[RaceGame] Shield activated for " .. 
            raceGame.player.invincibility_timer .. " seconds")
        
    elseif type == 'trail' then
        raceGame.trail_active = true
        raceGame.trail_timer = 5
        raceGame.trail_segments = {}
        debugConsole.addMessage("[RaceGame] Trail activated for " .. raceGame.trail_timer .. " seconds")
        
    elseif type == 'laser' then
        local laser = {
            x = raceGame.player.x + raceGame.player.width,
            y = raceGame.player.y + raceGame.player.height / 2 - 2,
            width = raceGame.screen_width / 3,
            height = 4,
            duration = 0.5,
            time = 0
        }
        table.insert(raceGame.lasers, laser)
        debugConsole.addMessage("[RaceGame] Laser fired!")
    end
end

function raceGame.reset()
    raceGame.load()
end

function raceGame.setPlayerColor(color)
    raceGame.playerColor = color
end

return raceGame
local speedRunner = {}

function speedRunner.load()
    speedRunner.players = {}
    speedRunner.obstacles = {}
    speedRunner.powerUps = {}
    speedRunner.platforms = {}
    speedRunner.game_over = false
    speedRunner.lastPlayerStanding = nil
    speedRunner.game_started = false
    speedRunner.start_timer = 3

    -- Game variables
    speedRunner.gravity = 1000
    speedRunner.scroll_speed = 400
    speedRunner.camera_x = 0
    speedRunner.shrink_timer = 0
    speedRunner.shrink_interval = 5
    speedRunner.screen_width = love.graphics.getWidth()
    speedRunner.screen_height = love.graphics.getHeight()
    speedRunner.shrink_padding_x = 0
    speedRunner.shrink_padding_y = 0
    speedRunner.max_shrink_padding_x = 200
    speedRunner.max_shrink_padding_y = 150

    -- Create platforms, obstacles, and power-ups
    speedRunner.createPlatforms()
    speedRunner.createObstacles()
    speedRunner.createPowerUps()

    -- Initialize input tracking
    love.keyboard.keysPressed = {}
end

function speedRunner.update(dt)
    if not speedRunner.game_started then
        speedRunner.start_timer = speedRunner.start_timer - dt
        if speedRunner.start_timer <= 0 then
            speedRunner.game_started = true
            speedRunner.start_timer = 0
        end
    else
        -- Update game logic for each player
        for id, player in pairs(speedRunner.players) do
            if not player.game_over then
                speedRunner.updatePlayer(dt, player)
            end
        end

        -- Scroll the camera (this may need to be adjusted for multiplayer)
        speedRunner.camera_x = speedRunner.camera_x + speedRunner.scroll_speed * dt

        -- Check for last player standing
        speedRunner.checkLastPlayerStanding()
    end

    -- Reset input tracking
    love.keyboard.keysPressed = {}
end

function speedRunner.updatePlayer(dt, player)
    -- Apply gravity
    player.dy = player.dy + speedRunner.gravity * dt
    player.y = player.y + player.dy * dt

    -- Handle player input (only for the local player)
    if player.isLocalPlayer and not player.is_stunned then
        speedRunner.handlePlayerInput(dt, player)
    end

    -- Collision with platforms
    speedRunner.handlePlatformCollisions(dt, player)

    -- Collision with obstacles
    speedRunner.handleObstacleCollisions(dt, player)

    -- Collision with power-ups
    speedRunner.handlePowerUpCollisions(dt, player)

    -- Update trail blaze
    speedRunner.updateTrail(dt, player)

    -- Update laser beam
    speedRunner.updateLaser(dt, player)

    -- Check if player falls off the screen
    if player.x + player.width < speedRunner.camera_x or player.y > speedRunner.screen_height then
        player.game_over = true
    end
end

function speedRunner.handlePlayerInput(dt, player)
    if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
        player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
        player.x = player.x + player.speed * dt
    end

    -- Jumping
    if (love.keyboard.wasPressed('space') or love.keyboard.wasPressed('w') or love.keyboard.wasPressed('up')) and player.jump_count < player.max_jumps then
        player.dy = -player.jump_strength
        player.on_ground = false
        player.jump_count = player.jump_count + 1
    end

    -- Dropping through platforms
    if (love.keyboard.wasPressed('s') or love.keyboard.wasPressed('down')) and player.on_ground and not player.droppingThroughPlatform then
        if not speedRunner.isOnBottomPlatform(player) then
            player.droppingThroughPlatform = speedRunner.getPlatformBelowPlayer(player)
            player.on_ground = false
            player.dy = 5
        end
    end

    -- Activate power-up
    if love.keyboard.wasPressed('e') then
        speedRunner.activatePowerUp(player)
    end
end

function speedRunner.handlePlatformCollisions(dt, player)
    player.on_ground = false
    local platformCollided = false
    for _, platform in ipairs(speedRunner.platforms) do
        if platform == player.droppingThroughPlatform then
            if player.y > platform.y + platform.height then
                player.droppingThroughPlatform = nil
            end
            goto continue
        end

        if speedRunner.checkCollision(player.x, player.y, player.width, player.height,
                                      platform.x, platform.y, platform.width, platform.height) then
            if player.dy > 0 then
                player.y = platform.y - player.height
                player.dy = 0
                player.on_ground = true
                player.jump_count = 0
                platformCollided = true
            end
        end
        ::continue::
    end
    if not platformCollided then
        player.on_ground = false
    end
end

function speedRunner.handleObstacleCollisions(dt, player)
    for i = #speedRunner.obstacles, 1, -1 do
        local obstacle = speedRunner.obstacles[i]
        if speedRunner.checkCollision(player.x, player.y, player.width, player.height,
                                      obstacle.x, obstacle.y, obstacle.width, obstacle.height) then
            if obstacle.type == 'slow' then
                if not player.is_invincible and not player.speed_up_active then
                    if not player.is_slowed then
                        player.is_slowed = true
                        player.slowdown_timer = 1
                        player.speed = player.slowed_speed
                    end
                end
            elseif obstacle.type == 'stun' then
                if not player.is_invincible then
                    if not player.is_stunned then
                        player.is_stunned = true
                        player.stun_timer = 0.1
                    end
                end
                table.remove(speedRunner.obstacles, i)
            elseif obstacle.type == 'speed' then
                player.speed_up_active = true
                player.speed_up_timer = 2
                player.speed = player.normal_speed * 2
                table.remove(speedRunner.obstacles, i)
            end

            -- Remove obstacle if trail is active and obstacle is behind player
            if player.trail_active then
                for j = #player.trail_segments, 1, -1 do
                    local segment = player.trail_segments[j]
                    if speedRunner.checkCollision(obstacle.x, obstacle.y, obstacle.width, obstacle.height,
                                                  segment.x, segment.y, segment.width, segment.height) then
                        table.remove(speedRunner.obstacles, i)
                        break
                    end
                end
            end

            -- Remove obstacle if laser is active and obstacle is in front of player
            if player.laser_active and obstacle.x > player.x + player.width then
                table.remove(speedRunner.obstacles, i)
            end
        end
    end
end

function speedRunner.handlePowerUpCollisions(dt, player)
    for i = #speedRunner.powerUps, 1, -1 do
        local powerUp = speedRunner.powerUps[i]
        if speedRunner.checkCollision(player.x, player.y, player.width, player.height,
                                      powerUp.x, powerUp.y, powerUp.radius * 2, powerUp.radius * 2) then
            if not player.powerUp then
                player.powerUp = powerUp
            end
            table.remove(speedRunner.powerUps, i)
        end
    end
end

function speedRunner.activatePowerUp(player)
    if player.powerUp then
        local powerUp = player.powerUp
        if powerUp.type == 'speed' then
            player.speed_up_active = true
            player.speed_up_timer = 2
            player.is_slowed = false
            player.speed = player.normal_speed * 2
        elseif powerUp.type == 'shield' then
            player.is_invincible = true
            player.invincibility_timer = 4
        elseif powerUp.type == 'trail' then
            player.trail_active = true
            player.trail_timer = 5
            player.trail_segments = {}
        elseif powerUp.type == 'laser' then
            player.laser_active = true
            player.laser_timer = 0.5
        end
        player.powerUp = nil
    end
end

function speedRunner.updateTrail(dt, player)
    if player.trail_active then
        player.trail_timer = player.trail_timer - dt
        local segment = {
            x = player.x,
            y = player.y + player.height / 2 - player.height / 4,
            width = 10,
            height = player.height / 2
        }
        table.insert(player.trail_segments, segment)
        for i = #player.trail_segments, 1, -1 do
            if player.trail_segments[i].x < speedRunner.camera_x then
                table.remove(player.trail_segments, i)
            end
        end
        if player.trail_timer <= 0 then
            player.trail_active = false
            player.trail_segments = {}
        end
    end
end

function speedRunner.updateLaser(dt, player)
    if player.laser_active then
        player.laser_timer = player.laser_timer - dt
        if player.laser_timer <= 0 then
            player.laser_active = false
        end
    end
end

function speedRunner.checkLastPlayerStanding()
    local activePlayers = 0
    local lastPlayerId = nil
    for id, player in pairs(speedRunner.players) do
        if not player.game_over then
            activePlayers = activePlayers + 1
            lastPlayerId = id
        end
    end

    if activePlayers == 1 and not speedRunner.game_over then
        speedRunner.lastPlayerStanding = lastPlayerId
        speedRunner.game_over = true

        -- Award points to the last player standing
        if speedRunner.players[lastPlayerId].isLocalPlayer then
            if connected then
                server:send("speedrunner_winner," .. lastPlayerId)
            end
        end
    end
end

function speedRunner.draw()
    love.graphics.push()
    love.graphics.translate(-speedRunner.camera_x, 0)

    -- Draw platforms
    love.graphics.setColor(0.5, 0.5, 0.5)
    for _, platform in ipairs(speedRunner.platforms) do
        love.graphics.rectangle('fill', platform.x, platform.y, platform.width, platform.height)
    end

    -- Draw obstacles
    for _, obstacle in ipairs(speedRunner.obstacles) do
        if obstacle.type == 'slow' then
            love.graphics.setColor(0, 1, 1)
        elseif obstacle.type == 'stun' then
            love.graphics.setColor(1, 0, 0)
        elseif obstacle.type == 'speed' then
            love.graphics.setColor(0, 1, 0)
        end
        love.graphics.rectangle('fill', obstacle.x, obstacle.y, obstacle.width, obstacle.height)
    end

    -- Draw power-ups
    for _, powerUp in ipairs(speedRunner.powerUps) do
        if powerUp.type == 'speed' then
            love.graphics.setColor(1, 1, 0)
        elseif powerUp.type == 'shield' then
            love.graphics.setColor(0, 1, 1)
        elseif powerUp.type == 'trail' then
            love.graphics.setColor(1, 0.5, 0)
        elseif powerUp.type == 'laser' then
            love.graphics.setColor(1, 0, 1)
        end
        love.graphics.circle('fill', powerUp.x + powerUp.radius, powerUp.y + powerUp.radius, powerUp.radius)
    end

    -- Draw players
    for id, player in pairs(speedRunner.players) do
        -- Draw laser beam
        if player.laser_active then
            love.graphics.setColor(1, 0, 1, 0.5)
            local laser_x = player.x + player.width
            local laser_y = player.y + player.height / 2 - player.height
            local laser_width = speedRunner.camera_x + speedRunner.screen_width - (player.x + player.width)
            local laser_height = player.height * 2
            love.graphics.rectangle('fill', laser_x, laser_y, laser_width, laser_height)
        end

        -- Draw trail blaze
        if player.trail_active then
            love.graphics.setColor(1, 0.5, 0)
            for _, segment in ipairs(player.trail_segments) do
                love.graphics.rectangle('fill', segment.x, segment.y, segment.width, segment.height)
            end
        end

        -- Draw player
        if player.is_invincible then
            love.graphics.setColor(0, 1, 1)
        elseif player.speed_up_active then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(player.color)
        end
        love.graphics.rectangle('fill', player.x, player.y, player.width, player.height)
    end

    love.graphics.pop()

    -- UI elements
    if not speedRunner.game_started then
        love.graphics.printf('Get Ready: ' .. math.ceil(speedRunner.start_timer), 0, speedRunner.screen_height / 2 - 50, speedRunner.screen_width, 'center')
    elseif speedRunner.game_over then
        love.graphics.printf('Game Over', 0, speedRunner.screen_height / 2 - 50, speedRunner.screen_width, 'center')
    end

    function speedRunner.reset()
        speedRunner.load()
    end
    function createPlatforms()
        platforms = {}
        local platform_height = 20
        platform_y_positions = {200, 350, 500}
        bottom_platform_y = 500

        for _, y in ipairs(platform_y_positions) do
            local x = 0
            while x < 200000 do
                local gap = math.random(200, 400)
                local length = math.random(500, 800)

                if x < 500 then
                    length = 500 - x
                    gap = 0
                end

                table.insert(platforms, { x = x, y = y, width = length, height = platform_height })
                x = x + length + gap
            end
        end
    end
    function createObstacles()
        obstacles = {}
        for _, platform in ipairs(platforms) do
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
                    elseif rand < 0.25 then
                        obstacleType = 'stun'
                    elseif rand < 0.3 then
                        obstacleType = 'speed'
                    else
                        x = x + 150
                        goto continue
                    end
                    table.insert(obstacles, { x = x, y = platform.y - 30, width = 30, height = 30, type = obstacleType })
                    x = x + 150
                    ::continue::
                end
            end
        end
    end
    function createPowerUps()
        powerUps = {}
        local powerUpTypes = { 'speed', 'shield', 'trail', 'laser' }
        for i = 1, 20 do
            local platform = platforms[math.random(1, #platforms)]
            local minX = math.max(platform.x + 100, 500)
            local maxX = platform.x + platform.width - 100
            if maxX > minX then
                local x = math.random(minX, maxX)
                local y = platform.y - 30
                local pType = powerUpTypes[math.random(1, #powerUpTypes)]
                table.insert(powerUps, { x = x, y = y, radius = 15, type = pType })
            end
        end
    end

    -- Check if the player is on the bottom platform
    function isOnBottomPlatform()
        local currentPlatform = getPlatformBelowPlayer()
        if currentPlatform and currentPlatform.y == bottom_platform_y then
            return true
        else
            return false
        end
    end

    -- Get the platform directly below the player
    function getPlatformBelowPlayer()
        for _, platform in ipairs(platforms) do
            if player.x + player.width > platform.x and player.x < platform.x + platform.width then
                if math.abs(player.y + player.height - platform.y) < 1 then
                    return platform
                end
            end
        end
        return nil
    end

    -- Check for collision between two rectangles
    function checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
        return x1 < x2 + w2 and
            x1 + w1 > x2 and
            y1 < y2 + h2 and
            y1 + h1 > y2
    end

    -- Capture key presses
    function love.keypressed(key)
        love.keyboard.keysPressed[key] = true
    end

    -- Define the wasPressed function
    function love.keyboard.wasPressed(key)
        return love.keyboard.keysPressed[key]
    end

    return speedrunner
end
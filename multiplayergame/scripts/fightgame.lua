local fightGame = {}
local debugConsole = require "scripts.debugconsole"
local musicHandler = require "scripts.musichandler"

-- Game state
fightGame.game_over = false
fightGame.current_round_score = 0
fightGame.playerColor = {1, 1, 1}
fightGame.screen_width = 800
fightGame.screen_height = 600
fightGame.game_started = false
fightGame.start_timer = 3
fightGame.timer = 60 -- 60 seconds match
fightGame.gameTime = 0

-- Player settings
fightGame.player = {
    x = 400,
    y = 300,
    width = 40,
    height = 40,
    speed = 250,
    health = 100,
    max_health = 100,
    weapon = nil, -- Current weapon: "laser_gun", "fire_sword", "shield"
    weapon_timer = 0,
    weapon_duration = 10, -- 10 seconds per weapon
    is_invincible = false,
    invincibility_timer = 0,
    last_damage_time = 0
}

-- Power-ups system
fightGame.powerups = {}
fightGame.powerup_spawn_timer = 0
fightGame.powerup_spawn_interval = 8 -- Spawn power-up every 8 seconds
fightGame.powerup_types = {"laser_gun", "fire_sword", "shield"}

-- Laser gun settings
fightGame.laser_bullets = {}
fightGame.laser_cooldown = 0
fightGame.laser_cooldown_time = 0.3 -- 3 shots per second

-- Fire sword settings
fightGame.sword_slash_timer = 0
fightGame.sword_cooldown = 0
fightGame.sword_cooldown_time = 0.5
fightGame.sword_range = 80

-- Shield settings
fightGame.shield_active = false
fightGame.shield_health = 50
fightGame.max_shield_health = 50

-- Other players (for multiplayer)
fightGame.other_players = {}

-- Seed-based synchronization
fightGame.seed = 0
fightGame.random = love.math.newRandomGenerator()

-- Sounds
fightGame.sounds = {
    laser = love.audio.newSource("sounds/laser.mp3", "static"),
    gunshot = love.audio.newSource("sounds/gunshot.mp3", "static"),
    death = love.audio.newSource("sounds/death.mp3", "static")
}

-- Set sound volumes
fightGame.sounds.laser:setVolume(0.3)
fightGame.sounds.gunshot:setVolume(0.4)
fightGame.sounds.death:setVolume(0.5)

function fightGame.load()
    debugConsole.addMessage("[FightGame] Loading fight game")
    
    -- Reset game state
    fightGame.game_over = false
    fightGame.current_round_score = 0
    fightGame.game_started = false
    fightGame.start_timer = 3
    fightGame.timer = 60
    fightGame.gameTime = 0
    
    -- Reset player
    fightGame.player = {
        x = 400,
        y = 300,
        width = 40,
        height = 40,
        speed = 250,
        health = 100,
        max_health = 100,
        weapon = nil,
        weapon_timer = 0,
        weapon_duration = 10,
        is_invincible = false,
        invincibility_timer = 0,
        last_damage_time = 0
    }
    
    -- Reset power-ups
    fightGame.powerups = {}
    fightGame.powerup_spawn_timer = 0
    
    -- Reset weapons
    fightGame.laser_bullets = {}
    fightGame.laser_cooldown = 0
    fightGame.sword_slash_timer = 0
    fightGame.sword_cooldown = 0
    fightGame.shield_active = false
    fightGame.shield_health = 50
    
    -- Reset other players
    fightGame.other_players = {}
    
    debugConsole.addMessage("[FightGame] Fight game loaded successfully")
end

function fightGame.setSeed(seed)
    fightGame.seed = seed
    fightGame.random:setSeed(seed)
    fightGame.gameTime = 0
    
    debugConsole.addMessage("[FightGame] Set seed: " .. seed)
end

function fightGame.update(dt)
    -- Update music effects
    musicHandler.update(dt)
    
    if not fightGame.game_started then
        fightGame.start_timer = math.max(0, fightGame.start_timer - dt)
        fightGame.game_started = fightGame.start_timer == 0
        return
    end

    if fightGame.game_over then return end

    fightGame.timer = fightGame.timer - dt
    fightGame.gameTime = fightGame.gameTime + dt
    
    if fightGame.timer <= 0 then
        fightGame.timer = 0
        fightGame.game_over = true
        return
    end

    -- Handle movement
    fightGame.handleMovement(dt)
    
    -- Update weapon timer
    if fightGame.player.weapon then
        fightGame.player.weapon_timer = fightGame.player.weapon_timer - dt
        if fightGame.player.weapon_timer <= 0 then
            fightGame.player.weapon = nil
            fightGame.player.weapon_timer = 0
            fightGame.shield_active = false
            debugConsole.addMessage("[FightGame] Weapon expired")
        end
    end
    
    -- Update weapon cooldowns
    if fightGame.laser_cooldown > 0 then
        fightGame.laser_cooldown = fightGame.laser_cooldown - dt
    end
    if fightGame.sword_cooldown > 0 then
        fightGame.sword_cooldown = fightGame.sword_cooldown - dt
    end
    
    -- Update invincibility timer
    if fightGame.player.is_invincible then
        fightGame.player.invincibility_timer = fightGame.player.invincibility_timer - dt
        if fightGame.player.invincibility_timer <= 0 then
            fightGame.player.is_invincible = false
        end
    end
    
    -- Spawn power-ups
    fightGame.updatePowerups(dt)
    
    -- Update laser bullets
    fightGame.updateLaserBullets(dt)
    
    -- Update sword slash effect
    if fightGame.sword_slash_timer > 0 then
        fightGame.sword_slash_timer = fightGame.sword_slash_timer - dt
    end
    
    -- Update scoring
    fightGame.current_round_score = fightGame.current_round_score + math.floor(dt * 5)
    
    -- Store score in players table for round win determination
    if _G.localPlayer and _G.localPlayer.id and _G.players and _G.players[_G.localPlayer.id] then
        _G.players[_G.localPlayer.id].fightScore = fightGame.current_round_score
    end
end

function fightGame.handleMovement(dt)
    local moveSpeed = fightGame.player.speed
    
    if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
        fightGame.player.y = fightGame.player.y - moveSpeed * dt
    end
    if love.keyboard.isDown('s') or love.keyboard.isDown('down') then
        fightGame.player.y = fightGame.player.y + moveSpeed * dt
    end
    if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
        fightGame.player.x = fightGame.player.x - moveSpeed * dt
    end
    if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
        fightGame.player.x = fightGame.player.x + moveSpeed * dt
    end
    
    -- Keep player within screen bounds
    fightGame.player.x = math.max(0, math.min(fightGame.screen_width - fightGame.player.width, fightGame.player.x))
    fightGame.player.y = math.max(0, math.min(fightGame.screen_height - fightGame.player.height, fightGame.player.y))
end

function fightGame.updatePowerups(dt)
    fightGame.powerup_spawn_timer = fightGame.powerup_spawn_timer + dt
    
    if fightGame.powerup_spawn_timer >= fightGame.powerup_spawn_interval then
        fightGame.spawnPowerup()
        fightGame.powerup_spawn_timer = 0
    end
    
    -- Check power-up collisions
    for i = #fightGame.powerups, 1, -1 do
        local powerup = fightGame.powerups[i]
        
        -- Check collision with player
        if fightGame.checkCollision(fightGame.player, powerup) then
            fightGame.collectPowerup(powerup)
            table.remove(fightGame.powerups, i)
        end
    end
end

function fightGame.spawnPowerup()
    -- Random position away from edges
    local margin = 50
    local x = fightGame.random:random(margin, fightGame.screen_width - margin)
    local y = fightGame.random:random(margin, fightGame.screen_height - margin)
    
    -- Random power-up type
    local powerup_type = fightGame.powerup_types[fightGame.random:random(1, #fightGame.powerup_types)]
    
    local powerup = {
        x = x,
        y = y,
        width = 30,
        height = 30,
        type = powerup_type,
        spawn_time = fightGame.gameTime,
        lifetime = 15 -- Power-ups disappear after 15 seconds
    }
    
    table.insert(fightGame.powerups, powerup)
    debugConsole.addMessage("[FightGame] Spawned " .. powerup_type .. " at (" .. x .. ", " .. y .. ")")
end

function fightGame.collectPowerup(powerup)
    fightGame.player.weapon = powerup.type
    fightGame.player.weapon_timer = fightGame.player.weapon_duration
    
    if powerup.type == "shield" then
        fightGame.shield_active = true
        fightGame.shield_health = fightGame.max_shield_health
    end
    
    debugConsole.addMessage("[FightGame] Collected " .. powerup.type)
end

function fightGame.updateLaserBullets(dt)
    for i = #fightGame.laser_bullets, 1, -1 do
        local bullet = fightGame.laser_bullets[i]
        
        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt
        
        -- Remove bullets that are off screen
        if bullet.x < -10 or bullet.x > fightGame.screen_width + 10 or
           bullet.y < -10 or bullet.y > fightGame.screen_height + 10 then
            table.remove(fightGame.laser_bullets, i)
        end
    end
end

function fightGame.shootLaser()
    if fightGame.laser_cooldown > 0 then return end
    
    local mx, my = love.mouse.getPosition()
    local angle = math.atan2(my - fightGame.player.y - fightGame.player.height/2, 
                            mx - fightGame.player.x - fightGame.player.width/2)
    
    local bullet_speed = 400
    local bullet = {
        x = fightGame.player.x + fightGame.player.width/2,
        y = fightGame.player.y + fightGame.player.height/2,
        vx = math.cos(angle) * bullet_speed,
        vy = math.sin(angle) * bullet_speed,
        width = 5,
        height = 5,
        damage = 20
    }
    
    table.insert(fightGame.laser_bullets, bullet)
    fightGame.laser_cooldown = fightGame.laser_cooldown_time
    fightGame.sounds.laser:play()
end

function fightGame.swingSword()
    if fightGame.sword_cooldown > 0 then return end
    
    fightGame.sword_slash_timer = 0.3 -- Show slash effect for 0.3 seconds
    fightGame.sword_cooldown = fightGame.sword_cooldown_time
    fightGame.sounds.gunshot:play() -- Reuse gunshot sound for sword
    
    -- Check for hits on other players
    local mx, my = love.mouse.getPosition()
    local sword_angle = math.atan2(my - fightGame.player.y - fightGame.player.height/2, 
                                  mx - fightGame.player.x - fightGame.player.width/2)
    
    -- TODO: Implement multiplayer sword hits
    debugConsole.addMessage("[FightGame] Sword swing!")
end

function fightGame.checkCollision(obj1, obj2)
    return obj1.x < obj2.x + obj2.width and
           obj1.x + obj1.width > obj2.x and
           obj1.y < obj2.y + obj2.height and
           obj1.y + obj1.height > obj2.y
end

function fightGame.takeDamage(damage)
    if fightGame.player.is_invincible then return end
    
    -- Shield absorbs damage first
    if fightGame.shield_active and fightGame.shield_health > 0 then
        fightGame.shield_health = math.max(0, fightGame.shield_health - damage)
        if fightGame.shield_health <= 0 then
            fightGame.shield_active = false
            fightGame.player.weapon = nil
            fightGame.player.weapon_timer = 0
        end
        return
    end
    
    fightGame.player.health = math.max(0, fightGame.player.health - damage)
    fightGame.player.is_invincible = true
    fightGame.player.invincibility_timer = 1.0 -- 1 second invincibility after taking damage
    
    if fightGame.player.health <= 0 then
        fightGame.player.health = 0
        fightGame.game_over = true
        fightGame.sounds.death:play()
        debugConsole.addMessage("[FightGame] Player died!")
    end
end

function fightGame.draw(playersTable, localPlayerId)
    -- Clear background
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle('fill', 0, 0, fightGame.screen_width, fightGame.screen_height)
    
    -- Draw power-ups
    fightGame.drawPowerups()
    
    -- Draw laser bullets
    fightGame.drawLaserBullets()
    
    -- Draw sword slash effect
    fightGame.drawSwordSlash()
    
    -- Draw other players
    if playersTable then
        for id, player in pairs(playersTable) do
            if id ~= localPlayerId and player.fightX and player.fightY then
                -- Draw ghost player body
                love.graphics.setColor(player.color[1], player.color[2], player.color[3], 0.7)
                love.graphics.rectangle('fill',
                    player.fightX,
                    player.fightY,
                    fightGame.player.width,
                    fightGame.player.height
                )
                
                -- Draw their face if available
                if player.facePoints then
                    love.graphics.setColor(1, 1, 1, 0.7)
                    love.graphics.draw(
                        player.facePoints,
                        player.fightX,
                        player.fightY,
                        0,
                        fightGame.player.width/100,
                        fightGame.player.height/100
                    )
                end
                
                -- Draw health bar
                love.graphics.setColor(1, 0, 0)
                love.graphics.rectangle('fill', player.fightX, player.fightY - 10, 
                                      fightGame.player.width, 4)
                love.graphics.setColor(0, 1, 0)
                local health_width = (player.fightHealth or 100) / 100 * fightGame.player.width
                love.graphics.rectangle('fill', player.fightX, player.fightY - 10, 
                                      health_width, 4)
                
                love.graphics.setColor(1, 1, 0, 0.8)
                love.graphics.printf(
                    "Score: " .. math.floor(player.totalScore or 0),
                    player.fightX - 50,
                    player.fightY - 40,
                    100,
                    "center"
                )
            end
        end
    end
    
    -- Draw local player
    if playersTable and playersTable[localPlayerId] then
        -- Draw invincibility effect if active
        if fightGame.player.is_invincible then
            local invincibility_radius = 35
            love.graphics.setColor(1, 1, 0, 0.3)
            love.graphics.circle('fill',
                fightGame.player.x + fightGame.player.width/2,
                fightGame.player.y + fightGame.player.height/2,
                invincibility_radius
            )
        end
        
        -- Draw shield effect if active
        if fightGame.shield_active then
            local shield_radius = 45
            local shield_alpha = 0.3 + 0.2 * math.sin(love.timer.getTime() * 8)
            love.graphics.setColor(0, 0.5, 1, shield_alpha)
            love.graphics.circle('line',
                fightGame.player.x + fightGame.player.width/2,
                fightGame.player.y + fightGame.player.height/2,
                shield_radius
            )
        end
        
        -- Draw player
        love.graphics.setColor(fightGame.playerColor)
        love.graphics.rectangle('fill',
            fightGame.player.x,
            fightGame.player.y,
            fightGame.player.width,
            fightGame.player.height
        )
        
        -- Draw face
        if playersTable[localPlayerId].facePoints then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                playersTable[localPlayerId].facePoints,
                fightGame.player.x,
                fightGame.player.y,
                0,
                fightGame.player.width/100,
                fightGame.player.height/100
            )
        end
        
        -- Draw health bar
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle('fill', fightGame.player.x, fightGame.player.y - 10, 
                              fightGame.player.width, 4)
        love.graphics.setColor(0, 1, 0)
        local health_width = fightGame.player.health / fightGame.player.max_health * fightGame.player.width
        love.graphics.rectangle('fill', fightGame.player.x, fightGame.player.y - 10, 
                              health_width, 4)
        
        -- Draw shield health bar if shield is active
        if fightGame.shield_active then
            love.graphics.setColor(0, 0.5, 1)
            love.graphics.rectangle('fill', fightGame.player.x, fightGame.player.y - 15, 
                                  fightGame.player.width, 3)
            love.graphics.setColor(0, 0, 0.8)
            local shield_width = fightGame.shield_health / fightGame.max_shield_health * fightGame.player.width
            love.graphics.rectangle('fill', fightGame.player.x, fightGame.player.y - 15, 
                                  shield_width, 3)
        end
    end
    
    -- Draw UI
    fightGame.drawUI(playersTable, localPlayerId)
end

function fightGame.drawPowerups()
    for _, powerup in ipairs(fightGame.powerups) do
        local color = {1, 1, 1}
        if powerup.type == "laser_gun" then
            color = {1, 0, 0} -- Red for laser gun
        elseif powerup.type == "fire_sword" then
            color = {1, 0.5, 0} -- Orange for fire sword
        elseif powerup.type == "shield" then
            color = {0, 0.5, 1} -- Blue for shield
        end
        
        love.graphics.setColor(color[1], color[2], color[3], 0.8)
        love.graphics.rectangle('fill', powerup.x, powerup.y, powerup.width, powerup.height)
        
        -- Draw outline
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle('line', powerup.x, powerup.y, powerup.width, powerup.height)
        
        -- Draw type indicator
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.upper(string.sub(powerup.type, 1, 1)), 
                            powerup.x, powerup.y + 5, powerup.width, "center")
    end
end

function fightGame.drawLaserBullets()
    for _, bullet in ipairs(fightGame.laser_bullets) do
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.rectangle('fill', bullet.x - bullet.width/2, bullet.y - bullet.height/2, 
                              bullet.width, bullet.height)
    end
end

function fightGame.drawSwordSlash()
    if fightGame.sword_slash_timer > 0 then
        local mx, my = love.mouse.getPosition()
        local slash_angle = math.atan2(my - fightGame.player.y - fightGame.player.height/2, 
                                      mx - fightGame.player.x - fightGame.player.width/2)
        
        love.graphics.push()
        love.graphics.translate(fightGame.player.x + fightGame.player.width/2, 
                               fightGame.player.y + fightGame.player.height/2)
        love.graphics.rotate(slash_angle)
        
        love.graphics.setColor(1, 0.5, 0, 0.7)
        love.graphics.rectangle('fill', 20, -5, fightGame.sword_range, 10)
        
        love.graphics.pop()
    end
end

function fightGame.drawUI(playersTable, localPlayerId)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Score: ' .. math.floor(fightGame.current_round_score), 10, 10)
    love.graphics.printf(string.format("Time: %.1f", fightGame.timer), 
                        0, 10, love.graphics.getWidth(), "center")
    
    if playersTable and playersTable[localPlayerId] then
        love.graphics.print('Total Score: ' .. 
            math.floor(playersTable[localPlayerId].totalScore or 0), 10, 30)
    end
    
    -- Display health
    love.graphics.print('Health: ' .. math.floor(fightGame.player.health) .. '/' .. fightGame.player.max_health, 10, 50)
    
    -- Display current weapon
    if fightGame.player.weapon then
        local weapon_text = "Weapon: " .. string.upper(fightGame.player.weapon) .. 
                           " (" .. string.format("%.1f", fightGame.player.weapon_timer) .. "s)"
        love.graphics.print(weapon_text, 10, 70)
    else
        love.graphics.print('Weapon: NONE', 10, 70)
    end
    
    -- Display shield status
    if fightGame.shield_active then
        love.graphics.print('Shield: ' .. math.floor(fightGame.shield_health) .. '/' .. fightGame.max_shield_health, 10, 90)
    end
    
    if not fightGame.game_started then
        love.graphics.printf('Get Ready: ' .. math.ceil(fightGame.start_timer), 
                            0, fightGame.screen_height / 2 - 50, fightGame.screen_height, 'center')
    end
    
    if fightGame.game_over then
        love.graphics.printf('Game Over - You Died!', 
                            0, fightGame.screen_height / 2 - 50, fightGame.screen_height, 'center')
    end
end

function fightGame.keypressed(key)
    debugConsole.addMessage("[FightGame] Key pressed: " .. key)
    
    if key == " " then -- Spacebar for weapon actions
        if fightGame.player.weapon == "laser_gun" then
            fightGame.shootLaser()
        elseif fightGame.player.weapon == "fire_sword" then
            fightGame.swingSword()
        elseif fightGame.player.weapon == "shield" then
            -- Shield is passive, no action needed
            debugConsole.addMessage("[FightGame] Shield is passive protection")
        end
    end
end

function fightGame.mousepressed(x, y, button)
    if button == 1 then -- Left mouse button
        if fightGame.player.weapon == "laser_gun" then
            fightGame.shootLaser()
        elseif fightGame.player.weapon == "fire_sword" then
            fightGame.swingSword()
        end
    end
end

function fightGame.keyreleased(key)
    -- No special key release handling needed
end

function fightGame.reset()
    fightGame.load()
end

function fightGame.setPlayerColor(color)
    fightGame.playerColor = color
end

return fightGame


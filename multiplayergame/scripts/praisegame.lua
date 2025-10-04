local praiseGame = {}
local debugConsole = require "scripts.debugconsole"
local musicHandler = require "scripts.musichandler"

-- Game state
praiseGame.player = {}
praiseGame.particles = {}
praiseGame.timer = 25 -- 25 seconds
praiseGame.game_over = false
praiseGame.is_dead = false
praiseGame.camera_y = 0
praiseGame.playerColor = {1, 1, 1}
praiseGame.player_size = 30
praiseGame.arena_size = 750  -- Same arena size as laser game
praiseGame.arena_offset_x = 0
praiseGame.arena_offset_y = 0
praiseGame.current_round_score = 0
praiseGame.is_penalized = false
praiseGame.penalty_timer = 0
praiseGame.PENALTY_DURATION = 1.0

-- seed stuff
praiseGame.seed = 0
praiseGame.random = love.math.newRandomGenerator()
praiseGame.gameTime = 0

-- Alternating praise/mock messages system
praiseGame.praise_messages = {
    "[TROPHY] Player is earning MASSIVE POINTS! This is legendary!",
    "[GOLD] Player's score is EXPLODING! Pure domination!",
    "[STAR] Player is racking up points like a machine!",
    "[TARGET] Player's performance = MAXIMUM POINTS! Incredible!",
    "[FIRE] Player is on a point-scoring rampage! Unstoppable!",
    "[DIAMOND] Player is collecting points like treasure! Amazing!",
    "[ROCKET] Player's score is skyrocketing! Phenomenal work!",
    "[LIGHTNING] Player is generating points at lightning speed!",
    "[100] Player is hitting perfect scores! Outstanding!",
    "[PARTY] Player is celebrating with MASSIVE point gains!"
}

praiseGame.mock_messages = {
    "[SKULL] Player's points are NEGATIVE! How is that even possible?!",
    "[CLOWN] Player is literally LOSING points! This is pathetic!",
    "[TRASH] Player's score is GARBAGE! Absolute trash performance!",
    "[BURN] Player is BURNING points faster than money! Disgraceful!",
    "[DOWN] Player's score is going DOWN! You're playing backwards!",
    "[POOP] Player's points smell worse than actual poop! Terrible!",
    "[STOP] Player is actively HURTING their score! Stop moving!",
    "[BROKEN] Player's points are BROKEN! Like your gaming skills!",
    "[FAKE] Player is pretending to play! Your score is FAKE NEWS!",
    "[FAIL] Player's performance is so bad it's INVENTING new ways to fail!",
    "[DEAD] Player is DEAD LAST in points! Even ghosts score higher!",
    "[SICK] Player's score makes me physically ill! Stop embarrassing yourself!",
    "[BOOM] Player is EXPLODING their own points! Self-destruction mode!",
    "[CLOWN] Player is a CIRCUS CLOWN! Points are the joke!",
    "[KNIFE] Player is STABBING their score to death! Murderous gameplay!",
    "[CURSED] Player's points are CURSED! Even voodoo dolls score better!",
    "[VIRUS] Player's score is CONTAGIOUSLY bad! Quarantine this gameplay!",
    "[NEGATIVE] Player is so bad at points they're INVENTING negative numbers!",
    "[ACTING] Player is ACTING like they have points! Performance art of failure!",
    "[HELL] Player's points died and went to hell! Even Satan scored higher!"
}

praiseGame.current_message_index = 1
praiseGame.message_timer = 0
praiseGame.message_duration = 5.0 -- Each message shows for 5 seconds
praiseGame.message_display_time = 0
praiseGame.show_message = false
praiseGame.is_praise = true -- Start with praise
praiseGame.current_text = ""
praiseGame.target_text = ""
praiseGame.typewriter_timer = 0
praiseGame.typewriter_speed = 0.05 -- Seconds per character
praiseGame.is_typing = false
praiseGame.is_deleting = false

-- Movement tracking for player position
praiseGame.last_position = {x = 0, y = 0}

-- Victory/Defeat scene
praiseGame.victory_scene = false
praiseGame.scene_timer = 0
praiseGame.scene_duration = 3.0
praiseGame.is_winner = false

-- Particle properties
praiseGame.particle_life = 1.0
praiseGame.particle_speed = 100
praiseGame.particle_size = 3
praiseGame.particle_color = {1, 1, 0}

-- Movement properties
praiseGame.move_speed = 200
praiseGame.move_acceleration = 800
praiseGame.move_deceleration = 600
praiseGame.max_speed = 300

-- Initialize player movement
praiseGame.player.vx = 0
praiseGame.player.vy = 0

-- Create particles for visual effects
function praiseGame.createParticles(x, y, angle)
    for i = 1, 8 do
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle + (i - 1) * math.pi / 4) * praiseGame.particle_speed,
            vy = math.sin(angle + (i - 1) * math.pi / 4) * praiseGame.particle_speed,
            life = praiseGame.particle_life,
            maxLife = praiseGame.particle_life,
            size = praiseGame.particle_size,
            color = {praiseGame.particle_color[1], praiseGame.particle_color[2], praiseGame.particle_color[3]}
        }
        table.insert(praiseGame.particles, particle)
    end
end

-- Update particles
function praiseGame.updateParticles(dt)
    for i = #praiseGame.particles, 1, -1 do
        local particle = praiseGame.particles[i]
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.life = particle.life - dt
        
        if particle.life <= 0 then
            table.remove(praiseGame.particles, i)
        end
    end
end

-- Load the game
function praiseGame.load()
    debugConsole.addMessage("[Praise] Loading praise/belittler game")
    
    -- Initialize player position (center of arena)
    local base_width = _G.BASE_WIDTH or 800
    local base_height = _G.BASE_HEIGHT or 600
    
    praiseGame.player.x = praiseGame.arena_offset_x + praiseGame.arena_size / 2
    praiseGame.player.y = praiseGame.arena_offset_y + praiseGame.arena_size / 2
    praiseGame.player.vx = 0
    praiseGame.player.vy = 0
    
    -- Reset game state
    praiseGame.game_over = false
    praiseGame.is_dead = false
    praiseGame.timer = 25 -- 25 seconds
    praiseGame.current_round_score = 0
    praiseGame.is_penalized = false
    praiseGame.penalty_timer = 0
    praiseGame.particles = {}
    
    -- Reset message system
    praiseGame.current_message_index = 1
    praiseGame.message_timer = 0
    praiseGame.message_display_time = 0
    praiseGame.show_message = false
    praiseGame.is_praise = true
    praiseGame.current_text = ""
    praiseGame.target_text = ""
    praiseGame.typewriter_timer = 0
    praiseGame.is_typing = false
    praiseGame.is_deleting = false
    
    -- Start first message immediately
    local playerName = _G.localPlayer and _G.localPlayer.name or "Player"
    praiseGame.target_text = praiseGame.praise_messages[1]:gsub("Player", playerName)
    praiseGame.is_typing = true
    praiseGame.is_deleting = false
    praiseGame.typewriter_timer = 0
    
    -- Reset victory scene
    praiseGame.victory_scene = false
    praiseGame.scene_timer = 0
    praiseGame.is_winner = false
    
    -- Reset movement tracking
    praiseGame.last_position = {x = praiseGame.player.x, y = praiseGame.player.y}
    
    -- Calculate arena positioning
    praiseGame.arena_offset_x = (base_width - praiseGame.arena_size) / 2
    praiseGame.arena_offset_y = (base_height - praiseGame.arena_size) / 2
    
    -- Initialize random generator
    praiseGame.random:setSeed(praiseGame.seed)
    
    debugConsole.addMessage("[Praise] Game loaded - simple movement game")
end

-- Set seed for synchronized gameplay
function praiseGame.setSeed(seed)
    praiseGame.seed = seed
    debugConsole.addMessage("[Praise] Seed set to: " .. seed)
end

-- Simple movement game - no message spawning needed

-- Simple movement game - no collision detection needed

-- Update the game
function praiseGame.update(dt)
    -- Update victory scene timer
    if praiseGame.victory_scene then
        praiseGame.scene_timer = praiseGame.scene_timer - dt
        if praiseGame.scene_timer <= 0 then
            praiseGame.victory_scene = false
            -- Let main loop handle state transition
            debugConsole.addMessage("[Praise] Victory scene ended - letting main loop handle state transition")
        end
        return
    end
    
    if praiseGame.game_over then 
        return 
    end
    
    praiseGame.timer = praiseGame.timer - dt
    if praiseGame.timer <= 0 then
        praiseGame.timer = 0
        praiseGame.game_over = true
        
        -- Start victory scene (no scoring)
        praiseGame.victory_scene = true
        praiseGame.scene_timer = praiseGame.scene_duration
        
        -- Determine if player is winner (for now, just random for demo)
        praiseGame.is_winner = praiseGame.random:random() > 0.5
        
        debugConsole.addMessage("[Praise] Game over - starting victory scene")
        return
    end
    
    -- Update game time
    praiseGame.gameTime = praiseGame.gameTime + dt
    
    -- Update message system
    praiseGame.message_timer = praiseGame.message_timer + dt
    
    -- Cycle through messages every 5 seconds
    if praiseGame.message_timer >= praiseGame.message_duration then
        praiseGame.message_timer = 0
        praiseGame.current_message_index = praiseGame.current_message_index + 1
        if praiseGame.current_message_index > #praiseGame.praise_messages then
            praiseGame.current_message_index = 1
        end
        
        -- Alternate between praise and insults every 5 seconds
        praiseGame.is_praise = not praiseGame.is_praise
        
        -- Set target text based on alternating state with actual player name
        local playerName = _G.localPlayer and _G.localPlayer.name or "Player"
        if praiseGame.is_praise then
            praiseGame.target_text = praiseGame.praise_messages[praiseGame.current_message_index]:gsub("Player", playerName)
        else
            praiseGame.target_text = praiseGame.mock_messages[praiseGame.current_message_index]:gsub("Player", playerName)
        end
        
        -- Start typewriter effect
        praiseGame.is_typing = true
        praiseGame.is_deleting = false
        praiseGame.typewriter_timer = 0
        praiseGame.current_text = ""
    end
    
    -- Handle typewriter effect
    if praiseGame.is_typing then
        praiseGame.typewriter_timer = praiseGame.typewriter_timer + dt
        
        if praiseGame.typewriter_timer >= praiseGame.typewriter_speed then
            praiseGame.typewriter_timer = 0
            
            if not praiseGame.is_deleting then
                -- Typing out the message
                if #praiseGame.current_text < #praiseGame.target_text then
                    praiseGame.current_text = praiseGame.current_text .. praiseGame.target_text:sub(#praiseGame.current_text + 1, #praiseGame.current_text + 1)
                else
                    -- Finished typing, wait a bit then start deleting
                    praiseGame.message_display_time = praiseGame.message_display_time + dt
                    if praiseGame.message_display_time >= 2.0 then
                        praiseGame.is_deleting = true
                        praiseGame.message_display_time = 0
                    end
                end
            else
                -- Deleting the message
                if #praiseGame.current_text > 0 then
                    praiseGame.current_text = praiseGame.current_text:sub(1, #praiseGame.current_text - 1)
                else
                    -- Finished deleting
                    praiseGame.is_typing = false
                    praiseGame.is_deleting = false
                end
            end
        end
    end
    
    -- Handle player movement
    local moveX, moveY = 0, 0
    
    if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
        moveY = moveY - 1
    end
    if love.keyboard.isDown('s') or love.keyboard.isDown('down') then
        moveY = moveY + 1
    end
    if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
        moveX = moveX - 1
    end
    if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
        moveX = moveX + 1
    end
    
    -- Apply movement with acceleration/deceleration
    if moveX ~= 0 or moveY ~= 0 then
        praiseGame.player.vx = praiseGame.player.vx + moveX * praiseGame.move_acceleration * dt
        praiseGame.player.vy = praiseGame.player.vy + moveY * praiseGame.move_acceleration * dt
    else
        praiseGame.player.vx = praiseGame.player.vx * (1 - praiseGame.move_deceleration * dt)
        praiseGame.player.vy = praiseGame.player.vy * (1 - praiseGame.move_deceleration * dt)
    end
    
    -- Limit speed
    local speed = math.sqrt(praiseGame.player.vx^2 + praiseGame.player.vy^2)
    if speed > praiseGame.max_speed then
        praiseGame.player.vx = praiseGame.player.vx * (praiseGame.max_speed / speed)
        praiseGame.player.vy = praiseGame.player.vy * (praiseGame.max_speed / speed)
    end
    
    -- Update player position
    praiseGame.player.x = praiseGame.player.x + praiseGame.player.vx * dt
    praiseGame.player.y = praiseGame.player.y + praiseGame.player.vy * dt
    
    -- Update last position for movement tracking
    praiseGame.last_position = {x = praiseGame.player.x, y = praiseGame.player.y}
    
    -- Keep player within arena bounds
    praiseGame.player.x = math.max(
        praiseGame.arena_offset_x + praiseGame.player_size / 2, 
        math.min(praiseGame.arena_offset_x + praiseGame.arena_size - praiseGame.player_size / 2, praiseGame.player.x))
    praiseGame.player.y = math.max(
        praiseGame.arena_offset_y + praiseGame.player_size / 2, 
        math.min(praiseGame.arena_offset_y + praiseGame.arena_size - praiseGame.player_size / 2, praiseGame.player.y))
    
    -- Simple movement game - no message updates needed
    
    -- Update particles
    praiseGame.updateParticles(dt)
end

-- Draw the game
function praiseGame.draw(playersTable, localPlayerId)
    local base_width = _G.BASE_WIDTH or 800
    local base_height = _G.BASE_HEIGHT or 600
    
    -- Set background color
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 0, 0, base_width, base_height)
    
    -- Push graphics state for arena drawing
    love.graphics.push()
    love.graphics.translate(praiseGame.arena_offset_x, praiseGame.arena_offset_y)
    
    -- Draw arena boundary (centered)
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", 0, 0, praiseGame.arena_size, praiseGame.arena_size)
    
    -- Draw grid lines for visual reference (centered)
    love.graphics.setColor(0.2, 0.2, 0.2)
    for i = 0, praiseGame.arena_size, 50 do
        love.graphics.line(i, 0, i, praiseGame.arena_size)
    end
    for i = 0, praiseGame.arena_size, 50 do
        love.graphics.line(0, i, praiseGame.arena_size, i)
    end
    
    -- Draw alternating praise/mock messages (Stick Fighter style)
    if praiseGame.is_typing and not praiseGame.victory_scene then
        -- Get much larger font for bigger text
        local originalFont = love.graphics.getFont()
        local bigFont = love.graphics.newFont(48) -- Much bigger font size
        love.graphics.setFont(bigFont)
        
        -- Calculate text width for proper centering
        local textWidth = bigFont:getWidth(praiseGame.current_text)
        local textHeight = bigFont:getHeight()
        
        -- Draw text shadow (offset by 4 pixels for bigger text)
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.printf(praiseGame.current_text, 
            4, 
            124, 
            base_width, 
            "center")
        
        -- Draw main text (white, extra bold effect by drawing multiple times)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(praiseGame.current_text, 
            0, 
            120, 
            base_width, 
            "center")
        love.graphics.printf(praiseGame.current_text, 
            1, 
            121, 
            base_width, 
            "center")
        love.graphics.printf(praiseGame.current_text, 
            2, 
            122, 
            base_width, 
            "center")
        
        -- Restore original font
        love.graphics.setFont(originalFont)
    end
    
    -- Draw player (relative to arena)
    local player_x = praiseGame.player.x - praiseGame.arena_offset_x
    local player_y = praiseGame.player.y - praiseGame.arena_offset_y
    
    love.graphics.setColor(praiseGame.playerColor)
    love.graphics.rectangle("fill", 
        player_x - praiseGame.player_size / 2, 
        player_y - praiseGame.player_size / 2, 
        praiseGame.player_size, 
        praiseGame.player_size)
    
    -- Draw player outline
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 
        player_x - praiseGame.player_size / 2, 
        player_y - praiseGame.player_size / 2, 
        praiseGame.player_size, 
        praiseGame.player_size)
    
    -- Draw player name above player
    if _G.localPlayer and _G.localPlayer.name then
        love.graphics.setColor(1, 1, 1)
        local nameWidth = love.graphics.getFont():getWidth(_G.localPlayer.name)
        love.graphics.printf(_G.localPlayer.name, 
            player_x - nameWidth / 2, 
            player_y - praiseGame.player_size / 2 - 25, 
            nameWidth, "center")
    end
    
    -- Draw particles
    for _, particle in ipairs(praiseGame.particles) do
        local alpha = particle.life / particle.maxLife
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        love.graphics.circle("fill", particle.x, particle.y, particle.size)
    end
    
    love.graphics.pop()
    
    -- Draw UI elements
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Time: %.1f", praiseGame.timer), 
        0, 10, base_width, "center")
    
    -- Draw victory/defeat scene
    if praiseGame.victory_scene then
        -- Dark overlay
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, base_width, base_height)
        
        if praiseGame.is_winner then
            -- Victory scene
            love.graphics.setColor(0.2, 1, 0.2) -- Green for victory
            love.graphics.printf("🏆 VICTORY! 🏆", 0, base_height/2 - 50, base_width, "center")
            love.graphics.setColor(1, 1, 0.2) -- Yellow for celebration
            love.graphics.printf("You are the champion!", 0, base_height/2 - 20, base_width, "center")
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf("(No points awarded - this is just for fun)", 0, base_height/2 + 10, base_width, "center")
        else
            -- Defeat scene
            love.graphics.setColor(1, 0.2, 0.2) -- Red for defeat
            love.graphics.printf("💀 DEFEAT! 💀", 0, base_height/2 - 50, base_width, "center")
            love.graphics.setColor(1, 0.5, 0.2) -- Orange for mocking
            love.graphics.printf("Better luck next time...", 0, base_height/2 - 20, base_width, "center")
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf("(No points lost - this is just for fun)", 0, base_height/2 + 10, base_width, "center")
        end
        
        -- Countdown
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.format("Returning to lobby in %.1f", praiseGame.scene_timer), 
            0, base_height/2 + 40, base_width, "center")
    end
end

-- Reset the game
function praiseGame.reset(playersTable)
    debugConsole.addMessage("[Praise] Resetting praise/belittler game")
    praiseGame.load()
end

-- Set player color
function praiseGame.setPlayerColor(color)
    praiseGame.playerColor = color
end

-- Handle key presses
function praiseGame.keypressed(key)
    -- No special key handling needed
end

-- Handle mouse presses
function praiseGame.mousepressed(x, y, button)
    -- No mouse handling needed
end

return praiseGame

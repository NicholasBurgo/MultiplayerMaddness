local timing = require("src.game.systems.timing")
local events = require("src.core.events")
local match = {}
match.name = "match"

local countdown

function match.load(args) 
    countdown = timing.new(3.0, function()
        events.emit("match:countdown_complete")
    end)
end

function match.update(dt) 
    if countdown then
        timing.update(countdown, dt)
    end
end

function match.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("=== MATCH STARTING ===", 250, 100)
    
    if countdown and not countdown.done then
        love.graphics.print("Starting in: " .. string.format("%.1f", math.max(0, countdown.t)), 250, 200)
    else
        love.graphics.print("GO!", 250, 200)
    end
end

function match.keypressed(k) 
    -- Match input handling
end

return match

local debugConsole = {}

debugConsole.log = {}
debugConsole.MAX_MESSAGES = 20
debugConsole.visible = false
debugConsole.width = 400
debugConsole.height = 300
debugConsole.x = 10  -- Position from left
debugConsole.y = love.graphics.getHeight() - 310  -- Position from bottom

function debugConsole.init()
    debugConsole.log = {}
    debugConsole.addMessage("[Status] Debug console initialized")
end

function debugConsole.addMessage(msg)
    local timestamp = os.date("%H:%M:%S")
    table.insert(debugConsole.log, 1, timestamp .. ": " .. tostring(msg))
    if #debugConsole.log > debugConsole.MAX_MESSAGES then
        table.remove(debugConsole.log)
    end
end

function debugConsole.draw()
    if not debugConsole.visible then return end
    
    -- Store current color
    local r, g, b, a = love.graphics.getColor()
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", 
        debugConsole.x, 
        debugConsole.y, 
        debugConsole.width, 
        math.min(debugConsole.height, #debugConsole.log * 20 + 40)
    )
    
    -- Draw server status at top
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        string.format("Debug Console (F3) | Server: %s | Players: %d", 
            _G.serverStatus or "Unknown",
            #table_keys(_G.players or {})
        ),
        debugConsole.x + 10, 
        debugConsole.y + 10
    )
    
    -- Draw messages
    for i, msg in ipairs(debugConsole.log) do
        love.graphics.print(msg, 
            debugConsole.x + 10, 
            debugConsole.y + 30 + (i-1) * 20
        )
    end
    
    -- Restore original color
    love.graphics.setColor(r, g, b, a)
end

function debugConsole.toggle()
    debugConsole.visible = not debugConsole.visible
end

-- Helper function to safely count table keys
function table_keys(t)
    if type(t) ~= "table" then return {} end
    local keys = {}
    for k in pairs(t) do 
        table.insert(keys, k)
    end
    return keys
end

return debugConsole
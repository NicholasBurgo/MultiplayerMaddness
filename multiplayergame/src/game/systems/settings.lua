-- ============================================================================
-- SETTINGS SYSTEM
-- ============================================================================
-- Manages game settings like volume, graphics, etc.
-- ============================================================================

local settings = {}

-- Default settings
local defaultSettings = {
    masterVolume = 1.0,
    musicVolume = 0.8,
    sfxVolume = 0.9,
    fullscreen = false,
    vsync = true,
    graphics = "medium" -- low, medium, high
}

-- Current settings (loaded from save or defaults)
settings.current = {}

-- Load settings from file or use defaults
function settings.load()
    -- Try to load from file first
    local success, data = pcall(love.filesystem.read, "settings.dat")
    if success and data then
        -- Simple deserialization for settings
        local fn = load("return " .. data)
        if fn then
            settings.current = fn()
            -- Ensure all required settings exist
            for key, value in pairs(defaultSettings) do
                if settings.current[key] == nil then
                    settings.current[key] = value
                end
            end
        else
            settings.current = defaultSettings
        end
    else
        settings.current = defaultSettings
    end
    
    -- Apply settings
    settings.apply()
end

-- Save settings to file
function settings.save()
    local data = {}
    for key, value in pairs(settings.current) do
        if type(value) == "string" then
            data[key] = '"' .. value .. '"'
        else
            data[key] = tostring(value)
        end
    end
    
    local serialized = "{" .. table.concat(data, ",") .. "}"
    love.filesystem.write("settings.dat", serialized)
end

-- Apply current settings
function settings.apply()
    -- Apply fullscreen
    if settings.current.fullscreen then
        love.window.setFullscreen(true)
    else
        love.window.setFullscreen(false)
    end
    
    -- Apply VSync
    love.window.setVSync(settings.current.vsync and 1 or 0)
    
    -- Apply volume settings
    local musicHandler = require("src.game.systems.musichandler")
    if musicHandler and musicHandler.setVolume then
        musicHandler.setVolume(settings.current.masterVolume * settings.current.musicVolume)
    end
end

-- Get a setting value
function settings.get(key)
    return settings.current[key]
end

-- Set a setting value
function settings.set(key, value)
    settings.current[key] = value
    settings.apply()
    settings.save()
end

-- Get all settings
function settings.getAll()
    return settings.current
end

-- Reset to defaults
function settings.reset()
    settings.current = defaultSettings
    settings.apply()
    settings.save()
end

return settings

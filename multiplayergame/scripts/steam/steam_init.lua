-- Steam Integration Module
-- Handles Steam initialization and basic functionality

local steam = {}

-- Steam state variables
local steamInitialized = false
local steamUserID = nil
local steamUserName = nil
local steamAppID = nil

-- Initialize Steam
function steam.init()
    -- Check if Steam is available
    if not love.filesystem.exists("libs/steam_api.dll") then
        print("[Steam] Warning: steam_api.dll not found. Steam features will be disabled.")
        return false
    end
    
    -- Try to load luasteam library
    local success, luasteam = pcall(require, "luasteam")
    if not success then
        print("[Steam] Warning: luasteam library not found. Steam features will be disabled.")
        print("[Steam] Error: " .. tostring(luasteam))
        return false
    end
    
    -- Initialize Steam
    if luasteam.init() then
        steamInitialized = true
        steamUserID = luasteam.user.getSteamID()
        steamUserName = luasteam.user.getName()
        steamAppID = luasteam.user.getAppID()
        
        print("[Steam] Successfully initialized!")
        print("[Steam] User: " .. (steamUserName or "Unknown"))
        print("[Steam] SteamID: " .. (steamUserID or "Unknown"))
        print("[Steam] AppID: " .. (steamAppID or "Unknown"))
        
        return true
    else
        print("[Steam] Failed to initialize Steam")
        return false
    end
end

-- Update Steam callbacks
function steam.update()
    if steamInitialized then
        local success, luasteam = pcall(require, "luasteam")
        if success then
            luasteam.run_callbacks()
        end
    end
end

-- Shutdown Steam
function steam.shutdown()
    if steamInitialized then
        local success, luasteam = pcall(require, "luasteam")
        if success then
            luasteam.shutdown()
        end
        steamInitialized = false
        print("[Steam] Shutdown complete")
    end
end

-- Check if Steam is initialized
function steam.isInitialized()
    return steamInitialized
end

-- Get Steam user ID
function steam.getUserID()
    return steamUserID
end

-- Get Steam user name
function steam.getUserName()
    return steamUserName
end

-- Get Steam App ID
function steam.getAppID()
    return steamAppID
end

-- Check if running through Steam
function steam.isRunningOnSteam()
    return steamInitialized
end

return steam

-- ============================================================================
-- CHARACTER CUSTOMIZATION SCENE
-- ============================================================================
-- Integration with existing character customization system

local events = require("src.core.events")
local characterCustomization = require("src.game.systems.charactercustom")
local savefile = require("src.game.systems.savefile")

local customization = {}
customization.name = "customization"
local returnTo = "menu"
local localPlayer = {
    x = 100,
    y = 100,
    color = {1, 0, 0},
    id = 0,
    name = "Player",
    totalScore = 0
}

function customization.load(args)
    returnTo = args and args.returnTo or "menu"
    
    -- Load saved player data
    local savedData = savefile.loadPlayerData()
    localPlayer.name = savedData.name
    localPlayer.color = savedData.color
    
    -- Initialize character customization
    characterCustomization.initialize(localPlayer)
    characterCustomization.init()
    
    -- Make globally accessible for compatibility
    _G.localPlayer = localPlayer
end

function customization.update(dt)
    characterCustomization.update(dt)
end

function customization.draw()
    characterCustomization.draw()
end

function customization.mousepressed(x, y, button)
    local result = characterCustomization.mousepressed(x, y, button)
    
    if result == "confirm" or result == "done" then
        -- Save and return
        savedData = savefile.loadPlayerData()
        savedData.name = characterCustomization.getPlayerName()
        savedData.color = characterCustomization.getCurrentColor()
        localPlayer.name = savedData.name
        localPlayer.color = savedData.color
        savefile.savePlayerData(savedData)
        
        events.emit("intent:return_from_customization", {returnTo = returnTo})
    elseif result == "cancel" then
        events.emit("intent:return_from_customization", {returnTo = returnTo})
    end
end

function customization.keypressed(k)
    -- Handle any keyboard input if needed
end

function customization.textinput(t)
    characterCustomization.textinput(t)
end

function customization.keyreleased(k)
    if characterCustomization.keyreleased then
        characterCustomization.keyreleased(k)
    end
end

return customization

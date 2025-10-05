-- ============================================================================
-- TAB MENU SYSTEM
-- ============================================================================
-- Global tab menu that shows player list with scores
-- Can be used across all game scenes
-- ============================================================================

local tabMenu = {}

-- Tab menu state
tabMenu.visible = false
tabMenu.tabHeld = false
tabMenu.maxPlayers = 8

-- Font system for tab menu
local fonts = {
    small = nil,
    medium = nil,
    large = nil,
    xlarge = nil
}

-- Initialize fonts
local function initFonts()
    fonts.small = love.graphics.newFont(14)
    fonts.medium = love.graphics.newFont(16)
    fonts.large = love.graphics.newFont(18)
    fonts.xlarge = love.graphics.newFont(24)
end

-- Function to sort players by score then name
local function sortPlayersForTab(players)
    local sortedPlayers = {}
    
    -- Convert players table to array for sorting
    for id, player in pairs(players) do
        table.insert(sortedPlayers, {
            id = id,
            name = player.name or "Player",
            totalScore = player.totalScore or 0
        })
    end
    
    -- Sort by score (descending) then by name (ascending)
    table.sort(sortedPlayers, function(a, b)
        if a.totalScore ~= b.totalScore then
            return a.totalScore > b.totalScore
        end
        return a.name < b.name
    end)
    
    return sortedPlayers
end

-- Function to get medal color for ranking
local function getMedalColor(position)
    if position == 1 then
        return {1, 0.84, 0, 1} -- Gold
    elseif position == 2 then
        return {0.75, 0.75, 0.75, 1} -- Silver
    elseif position == 3 then
        return {0.8, 0.5, 0.2, 1} -- Bronze
    else
        return {0.7, 0.7, 0.7, 1} -- Gray
    end
end

-- Show tab menu
function tabMenu.show()
    if not tabMenu.tabHeld then
        tabMenu.tabHeld = true
        tabMenu.visible = true
    end
end

-- Hide tab menu
function tabMenu.hide()
    tabMenu.tabHeld = false
    tabMenu.visible = false
end

-- Check if tab menu is visible
function tabMenu.isVisible()
    return tabMenu.visible
end

-- Draw the tab menu
function tabMenu.draw(players)
    if not tabMenu.visible or not players then return end
    
    -- Initialize fonts if needed
    if not fonts.xlarge then
        initFonts()
    end
    
    local sortedPlayers = sortPlayersForTab(players)
    -- Use base resolution for positioning since we're drawing on the canvas
    local BASE_WIDTH = 800
    local BASE_HEIGHT = 600
    
    -- Draw semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, BASE_WIDTH, BASE_HEIGHT)
    
    -- Tab menu background
    local menuWidth = 400
    local menuHeight = math.min(#sortedPlayers * 50 + 60, tabMenu.maxPlayers * 50 + 60)
    local menuX = (BASE_WIDTH - menuWidth) / 2
    local menuY = 100  -- Position near the top of the screen
    
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
    
    -- Menu border
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
    
    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.xlarge)
    love.graphics.printf("Player List", menuX, menuY + 10, menuWidth, "center")
    
    -- Draw players (up to maxPlayers)
    local startY = menuY + 50
    local maxToShow = math.min(#sortedPlayers, tabMenu.maxPlayers)
    
    for i = 1, maxToShow do
        local player = sortedPlayers[i]
        local y = startY + (i - 1) * 45
        local medalColor = getMedalColor(i)
        
        -- Player background
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", menuX + 10, y, menuWidth - 20, 40)
        
        -- Medal/rank indicator
        love.graphics.setColor(medalColor)
        love.graphics.setFont(fonts.large)
        love.graphics.printf("#" .. i, menuX + 15, y + 10, 30, "center")
        
        -- Player name
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(fonts.medium)
        love.graphics.printf(player.name, menuX + 50, y + 10, menuWidth - 120, "left")
        
        -- Player score
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(fonts.medium)
        love.graphics.printf(tostring(player.totalScore), menuX + menuWidth - 80, y + 10, 60, "right")
    end
    
    -- Instructions
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.setFont(fonts.small)
    love.graphics.printf("Hold TAB to show player list", menuX, menuY + menuHeight - 25, menuWidth, "center")
end

-- Handle key press
function tabMenu.keypressed(key)
    if key == "tab" then
        tabMenu.show()
        return true -- Handled
    end
    return false -- Not handled
end

-- Handle key release
function tabMenu.keyreleased(key)
    if key == "tab" then
        tabMenu.hide()
        return true -- Handled
    end
    return false -- Not handled
end

return tabMenu

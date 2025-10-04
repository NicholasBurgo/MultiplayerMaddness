-- Steam Achievements Module
-- Handles Steam achievements and stats

local steam_achievements = {}

-- Achievement definitions
local achievements = {
    first_win = {
        id = "ACH_FIRST_WIN",
        name = "First Victory",
        description = "Win your first game",
        icon = "first_win",
        unlocked = false
    },
    jump_master = {
        id = "ACH_JUMP_MASTER",
        name = "Jump Master",
        description = "Score 1000+ points in Jump Game",
        icon = "jump_master",
        unlocked = false
    },
    laser_dodger = {
        id = "ACH_LASER_DODGER",
        name = "Laser Dodger",
        description = "Survive 30+ seconds in Laser Game",
        icon = "laser_dodger",
        unlocked = false
    },
    battle_survivor = {
        id = "ACH_BATTLE_SURVIVOR",
        name = "Battle Survivor",
        description = "Win a Meteor Shower game",
        icon = "battle_survivor",
        unlocked = false
    },
    dodge_expert = {
        id = "ACH_DODGE_EXPERT",
        name = "Dodge Expert",
        description = "Dodge 50+ obstacles in Dodge Game",
        icon = "dodge_expert",
        unlocked = false
    },
    multiplayer_champion = {
        id = "ACH_MULTIPLAYER_CHAMPION",
        name = "Multiplayer Champion",
        description = "Win 10 multiplayer games",
        icon = "multiplayer_champion",
        unlocked = false
    },
    party_host = {
        id = "ACH_PARTY_HOST",
        name = "Party Host",
        description = "Host 5 multiplayer sessions",
        icon = "party_host",
        unlocked = false
    },
    social_player = {
        id = "ACH_SOCIAL_PLAYER",
        name = "Social Player",
        description = "Play with 10 different players",
        icon = "social_player",
        unlocked = false
    }
}

-- Stats definitions
local stats = {
    total_wins = 0,
    total_games_played = 0,
    jump_game_high_score = 0,
    laser_game_best_time = 0,
    meteor_shower_wins = 0,
    dodge_game_best_score = 0,
    multiplayer_games_hosted = 0,
    unique_players_met = 0
}

-- Initialize achievements system
function steam_achievements.init()
    print("[Steam Achievements] Initializing achievements system")
    
    local success, luasteam = pcall(require, "luasteam")
    if not success then
        print("[Steam Achievements] luasteam not available")
        return false
    end
    
    if not luasteam.userStats then
        print("[Steam Achievements] UserStats not available")
        return false
    end
    
    -- Request current stats and achievements
    luasteam.userStats.requestCurrentStats()
    print("[Steam Achievements] Requested current stats")
    
    return true
end

-- Unlock an achievement
function steam_achievements.unlock(achievementId)
    local achievement = achievements[achievementId]
    if not achievement then
        print("[Steam Achievements] Unknown achievement: " .. achievementId)
        return false
    end
    
    if achievement.unlocked then
        print("[Steam Achievements] Achievement already unlocked: " .. achievement.name)
        return true
    end
    
    local success, luasteam = pcall(require, "luasteam")
    if not success then
        print("[Steam Achievements] luasteam not available")
        return false
    end
    
    if luasteam.userStats then
        local result = luasteam.userStats.setAchievement(achievement.id)
        if result then
            achievement.unlocked = true
            print("[Steam Achievements] Unlocked: " .. achievement.name)
            
            -- Store achievement
            luasteam.userStats.storeStats()
            
            -- Show achievement notification
            steam_achievements.showNotification(achievement)
            
            return true
        else
            print("[Steam Achievements] Failed to unlock: " .. achievement.name)
            return false
        end
    end
    
    return false
end

-- Check if achievement is unlocked
function steam_achievements.isUnlocked(achievementId)
    local achievement = achievements[achievementId]
    return achievement and achievement.unlocked
end

-- Get achievement info
function steam_achievements.getAchievement(achievementId)
    return achievements[achievementId]
end

-- Get all achievements
function steam_achievements.getAllAchievements()
    return achievements
end

-- Set a stat value
function steam_achievements.setStat(statName, value)
    local stat = stats[statName]
    if not stat then
        print("[Steam Achievements] Unknown stat: " .. statName)
        return false
    end
    
    stats[statName] = value
    
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.userStats then
        luasteam.userStats.setStat(statName, value)
        luasteam.userStats.storeStats()
        print("[Steam Achievements] Set stat " .. statName .. " to " .. value)
        return true
    end
    
    return false
end

-- Get a stat value
function steam_achievements.getStat(statName)
    return stats[statName] or 0
end

-- Increment a stat
function steam_achievements.incrementStat(statName, amount)
    amount = amount or 1
    local currentValue = steam_achievements.getStat(statName)
    return steam_achievements.setStat(statName, currentValue + amount)
end

-- Show achievement notification
function steam_achievements.showNotification(achievement)
    -- This would integrate with your game's UI system
    print("[Steam Achievements] NOTIFICATION: " .. achievement.name .. " - " .. achievement.description)
    
    -- You could add visual notification here
    -- For example, show a popup or play a sound
end

-- Handle Steam events
function steam_achievements.handleEvent(event)
    if event.type == "UserStatsReceived" then
        print("[Steam Achievements] User stats received")
        steam_achievements.loadAchievements()
        steam_achievements.loadStats()
        
    elseif event.type == "UserStatsStored" then
        print("[Steam Achievements] User stats stored")
        
    elseif event.type == "UserAchievementStored" then
        print("[Steam Achievements] Achievement stored: " .. event.achievementName)
    end
end

-- Load achievements from Steam
function steam_achievements.loadAchievements()
    local success, luasteam = pcall(require, "luasteam")
    if not success then
        return
    end
    
    if not luasteam.userStats then
        return
    end
    
    for achievementId, achievement in pairs(achievements) do
        local unlocked = luasteam.userStats.getAchievement(achievement.id)
        achievement.unlocked = unlocked
        if unlocked then
            print("[Steam Achievements] Loaded unlocked achievement: " .. achievement.name)
        end
    end
end

-- Load stats from Steam
function steam_achievements.loadStats()
    local success, luasteam = pcall(require, "luasteam")
    if not success then
        return
    end
    
    if not luasteam.userStats then
        return
    end
    
    for statName, _ in pairs(stats) do
        local value = luasteam.userStats.getStat(statName)
        stats[statName] = value
        print("[Steam Achievements] Loaded stat " .. statName .. ": " .. value)
    end
end

-- Game-specific achievement triggers
function steam_achievements.onGameWin(gameType, score)
    steam_achievements.incrementStat("total_wins")
    steam_achievements.incrementStat("total_games_played")
    
    -- Check for first win
    if steam_achievements.getStat("total_wins") == 1 then
        steam_achievements.unlock("first_win")
    end
    
    -- Check for multiplayer champion
    if steam_achievements.getStat("total_wins") >= 10 then
        steam_achievements.unlock("multiplayer_champion")
    end
    
    -- Game-specific achievements
    if gameType == "jump" and score >= 1000 then
        steam_achievements.unlock("jump_master")
        if score > steam_achievements.getStat("jump_game_high_score") then
            steam_achievements.setStat("jump_game_high_score", score)
        end
    elseif gameType == "meteor_shower" then
        steam_achievements.unlock("battle_survivor")
        steam_achievements.incrementStat("meteor_shower_wins")
    end
end

function steam_achievements.onLaserGameSurvive(time)
    if time >= 30 then
        steam_achievements.unlock("laser_dodger")
    end
    
    if time > steam_achievements.getStat("laser_game_best_time") then
        steam_achievements.setStat("laser_game_best_time", time)
    end
end

function steam_achievements.onDodgeGameScore(score)
    if score >= 50 then
        steam_achievements.unlock("dodge_expert")
    end
    
    if score > steam_achievements.getStat("dodge_game_best_score") then
        steam_achievements.setStat("dodge_game_best_score", score)
    end
end

function steam_achievements.onHostGame()
    steam_achievements.incrementStat("multiplayer_games_hosted")
    
    if steam_achievements.getStat("multiplayer_games_hosted") >= 5 then
        steam_achievements.unlock("party_host")
    end
end

function steam_achievements.onMeetPlayer()
    steam_achievements.incrementStat("unique_players_met")
    
    if steam_achievements.getStat("unique_players_met") >= 10 then
        steam_achievements.unlock("social_player")
    end
end

-- Update achievements system (call in love.update)
function steam_achievements.update()
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.userStats then
        local event = luasteam.userStats.getEvent()
        if event then
            steam_achievements.handleEvent(event)
        end
    end
end

-- Shutdown achievements system
function steam_achievements.shutdown()
    local success, luasteam = pcall(require, "luasteam")
    if success and luasteam.userStats then
        luasteam.userStats.storeStats()
    end
    print("[Steam Achievements] Shutdown complete")
end

return steam_achievements

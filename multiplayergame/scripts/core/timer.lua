-- timer.lua
-- Centralized timer management for all game modules

local timer = {}

function timer.create(duration)
    return {
        duration = duration or 0,
        remaining = duration or 0,
        isActive = false,
        isExpired = false
    }
end

function timer.start(timerObj)
    timerObj.isActive = true
    timerObj.isExpired = false
    timerObj.remaining = timerObj.duration
end

function timer.stop(timerObj)
    timerObj.isActive = false
end

function timer.reset(timerObj)
    timerObj.remaining = timerObj.duration
    timerObj.isExpired = false
    timerObj.isActive = false
end

function timer.update(timerObj, dt)
    if timerObj.isActive and not timerObj.isExpired then
        timerObj.remaining = timerObj.remaining - dt
        if timerObj.remaining <= 0 then
            timerObj.remaining = 0
            timerObj.isExpired = true
            timerObj.isActive = false
        end
    end
end

function timer.isExpired(timerObj)
    return timerObj.isExpired
end

function timer.getRemaining(timerObj)
    return timerObj.remaining
end

function timer.getProgress(timerObj)
    if timerObj.duration <= 0 then return 0 end
    return 1 - (timerObj.remaining / timerObj.duration)
end

function timer.formatTime(timerObj)
    return string.format("%.1f", timerObj.remaining)
end

return timer

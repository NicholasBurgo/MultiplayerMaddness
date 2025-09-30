local musicHandler = {}
local debugConsole = require "scripts.debugconsole"

-- BPM-related calculations
musicHandler.bpm = 30.625
musicHandler.beatInterval = 60 / musicHandler.bpm
musicHandler.halfBeatInterval = musicHandler.beatInterval / 2
musicHandler.quarterBeatInterval = musicHandler.beatInterval / 4

-- Separate timers for effects and music
musicHandler.effectTimer = 0
musicHandler.effectBeat = 0
musicHandler.musicTimer = 0
musicHandler.musicBeat = 0

-- Other state
musicHandler.effects = {}
musicHandler.music = nil
musicHandler.totalBeats = 64
musicHandler.isPlaying = false
musicHandler.isEffectActive = false

-- Effect presets
musicHandler.presets = {
    bounce = {
        type = "position",
        amplitude = 10,
        frequency = 1, -- In beats
        phase = 0,
        axis = "y",
        snapDuration = 0.15  -- Quick movement duration
    },
    pulse = {
        type = "scale",
        amplitude = 0.2,
        frequency = 1,
        phase = 0,
        snapDuration = 0.15
    },
    rotate = {
        type = "rotation",
        amplitude = math.pi/8,
        frequency = 2,
        phase = 0,
        snapDuration = 0.15
    },
    colorPulse = {
        type = "color",
        amplitude = 0.3,
        frequency = 1,
        phase = 0,
        baseColor = {1, 1, 1}
    },
    beatPulse = {
        type = "beatColor",
        intensity = 0.5,    -- How much brighter it gets (0.5 = 50% brighter)
        duration = 0.1,     -- How long the pulse lasts (in beats)
        baseColor = {1, 1, 1}
    },
    shake = {
        type = "position",
        amplitude = 5,
        frequency = 4,
        phase = 0,
        axis = "both",
        snapDuration = 0.15
    },
    combo = {
        type = "combo",
        scaleAmount = 0.2,      -- How much bigger it gets
        rotateAmount = math.pi/16,  -- How much it rotates
        frequency = 1,
        phase = 0,
        snapDuration = 0.15
    }
}

function musicHandler.stopMusic()
    if musicHandler.music then
        musicHandler.music:stop()
        musicHandler.isPlaying = false
        musicHandler.timer = 0
        musicHandler.currentBeat = 0
    end
end

function musicHandler.applyCustomizationEffect()
    if musicHandler.music and not musicHandler.isEffectActive then
        print("[Music] Attempting to apply muffled room reverb effect")
        
        -- First, remove any existing effect
        love.audio.setEffect('customization', nil)
        
        -- Lower the music volume first
        musicHandler.music:setVolume(0.4)
        
        -- Set up the reverb effect for "other room" sound
        local success = love.audio.setEffect('customization', {
            type = 'reverb',
            gain = 0.2,       -- Much lower gain to prevent volume increase
            highgain = 0.1,   -- Keep high frequencies low for muffled effect
            density = 1.0,    -- Full density for wall simulation
            diffusion = 0.85, -- High diffusion for scattered sound
            decaytime = 2.5   -- Moderate decay for room simulation
        })
        
        if success then
            -- Enable the effect on our music source
            musicHandler.music:setEffect('customization', true)
            musicHandler.isEffectActive = true
            print("[Music] Successfully applied muffled room reverb effect")
        else
            print("[Music] Failed to set up reverb effect")
        end
    end
end

function musicHandler.clearEffects()
    if musicHandler.isEffectActive and musicHandler.music then
        print("[Music] Clearing effects")
        musicHandler.music:setEffect('customization', false)
        love.audio.setEffect('customization', nil)
        musicHandler.isEffectActive = false
        -- Restore original volume
        musicHandler.music:setVolume(1.0)
    end
end

function musicHandler.loadMenuMusic()
    if not musicHandler.music then
        musicHandler.music = love.audio.newSource("sounds/menutheme.mp3", "stream")
        musicHandler.music:setLooping(false)
        musicHandler.music:setVolume(1.0)  -- Ensure full volume when starting
        musicHandler.music:play()
    end

    if not musicHandler.isPlaying then
        musicHandler.music:play()
        musicHandler.isPlaying = true
        musicHandler.timer = 0
        musicHandler.currentBeat = 0
    end
end

function musicHandler.loadPartyMusic()
    if musicHandler.music then
        musicHandler.music:stop()
        musicHandler.music:release()
        musicHandler.music = nil
    end
    
    local success, result = pcall(function()
        local music = love.audio.newSource("sounds/partymodetheme.mp3", "stream")
        if not music then
            debugConsole.addMessage("[Music] Failed to create party music source")
            return nil
        end
        return music
    end)
    
    if success and result then
        musicHandler.music = result
        musicHandler.music:setVolume(0.4)
        musicHandler.isPlaying = true
        musicHandler.musicTimer = 0
        musicHandler.musicBeat = 0
        
        -- Actually play the music
        local playSuccess, playError = pcall(function()
            musicHandler.music:play()
        end)
        
        if playSuccess then
            debugConsole.addMessage("[Music] Party music started successfully")
        else
            debugConsole.addMessage("[Music] Failed to play party music: " .. tostring(playError))
        end
    else
        debugConsole.addMessage("[Music] Failed to load party music: " .. tostring(result))
    end
end

function musicHandler.addEffect(objectId, presetName, customParams)
    local preset = musicHandler.presets[presetName]
    if not preset then return end
    
    local effect = {}
    for k, v in pairs(preset) do
        effect[k] = v
    end
    
    -- Override with custom parameters if provided
    if customParams then
        for k, v in pairs(customParams) do
            effect[k] = v
        end
    end
    
    -- Add additional tracking data
    effect.objectId = objectId
    effect.originalValues = {}
    effect.lastBeat = -1  -- For beat-based effects
    effect.beatProgress = 0  -- For beat-based effects
    
    musicHandler.effects[objectId] = effect
    return effect
end

function musicHandler.removeEffect(objectId)
    musicHandler.effects[objectId] = nil
end

local function calculateBeatPulse(effect)
    if effect.beatProgress <= effect.duration then
        -- Quick rise and fall during the duration
        local pulseIntensity = math.sin((effect.beatProgress / effect.duration) * math.pi)
        
        -- Calculate how much brighter to make the color (0.0 to intensity)
        local brightnessIncrease = pulseIntensity * effect.intensity
        
        -- Apply the brightness increase while ensuring we don't exceed 1.0
        return {
            math.min(effect.baseColor[1] * (1 + brightnessIncrease), 1),
            math.min(effect.baseColor[2] * (1 + brightnessIncrease), 1),
            math.min(effect.baseColor[3] * (1 + brightnessIncrease), 1)
        }
    end
    
    -- Return base color when not pulsing
    return {
        effect.baseColor[1],
        effect.baseColor[2],
        effect.baseColor[3]
    }
end

function musicHandler.update(dt)
    -- Update effect timing
    musicHandler.effectTimer = musicHandler.effectTimer + dt
    local previousEffectBeat = musicHandler.effectBeat
    musicHandler.effectBeat = musicHandler.effectTimer / musicHandler.beatInterval
    
    -- Process visual effects
    for objectId, effect in pairs(musicHandler.effects) do
        if effect.type == "beatColor" then
            local currentBeat = math.floor(musicHandler.effectBeat)
            local beatProgress = musicHandler.effectBeat - currentBeat
            
            if currentBeat > effect.lastBeat then
                effect.lastBeat = currentBeat
                effect.beatProgress = 0
            else
                effect.beatProgress = beatProgress
            end
            
            effect.currentColor = calculateBeatPulse(effect)
        elseif effect.type == "combo" then
            local currentBeat = math.floor(musicHandler.effectBeat + effect.phase)
            local beatProgress = (musicHandler.effectBeat + effect.phase) % 1
                
            if beatProgress < effect.snapDuration then
                local progress = beatProgress / effect.snapDuration
                local sharpValue = math.sin(progress * math.pi)
                    
                effect.currentScale = 1 + (effect.scaleAmount * sharpValue)
                effect.originX = effect.currentOriginX or 0
                effect.originY = effect.currentOriginY or 0
                    
                if currentBeat % 2 == 0 then
                    effect.currentRotation = effect.rotateAmount * sharpValue
                else
                    effect.currentRotation = -effect.rotateAmount * sharpValue
                end
            else
                effect.currentScale = 1
                effect.currentRotation = 0
            end
        elseif effect.type == "position" then
            local beatPhase = (musicHandler.effectBeat * effect.frequency + effect.phase) * math.pi * 2
            local value = math.sin(beatPhase) * effect.amplitude
            
            if effect.axis == "x" or effect.axis == "both" then
                effect.currentX = value
            end
            if effect.axis == "y" or effect.axis == "both" then
                effect.currentY = value
            end
        end
    end

    -- Update music timing separately
    if musicHandler.music and musicHandler.isPlaying then
        musicHandler.musicTimer = musicHandler.musicTimer + dt
        musicHandler.musicBeat = musicHandler.musicTimer / musicHandler.beatInterval

        if not musicHandler.music:isPlaying() then
            musicHandler.music:play()
        end

        if musicHandler.musicBeat >= musicHandler.totalBeats then
            musicHandler.musicTimer = 0
            musicHandler.musicBeat = 0
            musicHandler.music:seek(0)
            musicHandler.music:play()
        end
    end

    -- Fire beat events
    if math.floor(musicHandler.effectBeat) > math.floor(previousEffectBeat) then
        musicHandler.onBeat()
    end
end

function musicHandler.onBeat()
    -- Can be overridden by the game to add beat reactions
end

function musicHandler.getEffectValues(objectId)
    local effect = musicHandler.effects[objectId]
    if not effect then return nil end
    
    return {
        x = effect.currentX or 0,
        y = effect.currentY or 0,
        scale = effect.currentScale or 1,
        rotation = effect.currentRotation or 0,
        color = effect.currentColor
    }
end

function musicHandler.applyToDrawable(drawable, x, y, r, sx, sy, ox, oy)
    -- Get all effects for this drawable
    local effect = musicHandler.effects[drawable]
    if not effect then return x, y, r, sx, sy, ox, oy end
    
    local finalX = x + (effect.currentX or 0)
    local finalY = y + (effect.currentY or 0)
    
    local finalR = r or 0
    if effect.currentRotation then
        finalR = finalR + effect.currentRotation
    end
    
    local finalSX = sx or 1
    local finalSY = sy or sx or 1
    if effect.currentScale then
        finalSX = finalSX * effect.currentScale
        finalSY = finalSY * effect.currentScale
    end
    
    return finalX, finalY, finalR, finalSX, finalSY, ox, oy
end

function musicHandler.getCurrentColor(objectId)
    local effect = musicHandler.effects[objectId]
    if effect and effect.currentColor then
        return effect.currentColor
    end
    return {1, 1, 1}
end

function musicHandler.setEffectOrigin(objectId, x, y)
    local effect = musicHandler.effects[objectId]
    if effect then
        effect.currentOriginX = x
        effect.currentOriginY = y
    end
end

return musicHandler
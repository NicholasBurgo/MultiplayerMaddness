-- savefile.lua
-- Simple save/load system for player customization

local savefile = {}

-- Helper function to serialize face canvas data
function savefile.serializeFaceCanvas(faceCanvas)
    if not faceCanvas then 
        print("[Serialize] Face canvas is nil")
        return nil 
    end
    
    print("[Serialize] Attempting to serialize face canvas")
    
    local success, imageData = pcall(function()
        return faceCanvas:newImageData()
    end)
    
    if not success then 
        print("[Serialize] Failed to get image data from canvas")
        return nil 
    end
    
    local width = imageData:getWidth()
    local height = imageData:getHeight()
    print("[Serialize] Canvas size: " .. width .. "x" .. height)
    
    local data = {}
    local pixelCount = 0
    
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local r, g, b, a = imageData:getPixel(x, y)
            if a > 0 then -- Only save non-transparent pixels
                table.insert(data, string.format("%d,%d,%.6f,%.6f,%.6f,%.6f", x, y, r, g, b, a))
                pixelCount = pixelCount + 1
            end
        end
    end
    
    print("[Serialize] Found " .. pixelCount .. " non-transparent pixels")
    if pixelCount == 0 then
        print("[Serialize] WARNING: Canvas appears to be empty!")
    end
    return table.concat(data, ";")
end

-- Helper function to deserialize face canvas data
function savefile.deserializeFaceCanvas(faceData, width, height)
    if not faceData or faceData == "" then 
        print("[Deserialize] No face data to deserialize")
        return nil 
    end
    
    print("[Deserialize] Deserializing face data, creating " .. width .. "x" .. height .. " canvas")
    
    local canvas = love.graphics.newCanvas(width, height)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    
    local pixels = {}
    for pixel in faceData:gmatch("[^;]+") do
        local x, y, r, g, b, a = pixel:match("([%d.]+),([%d.]+),([%d.]+),([%d.]+),([%d.]+),([%d.]+)")
        if x and y and r and g and b and a then
            table.insert(pixels, {
                x = tonumber(x),
                y = tonumber(y),
                r = tonumber(r),
                g = tonumber(g),
                b = tonumber(b),
                a = tonumber(a)
            })
        end
    end
    
    print("[Deserialize] Parsed " .. #pixels .. " pixels")
    
    -- Draw pixels back to canvas using rectangles for better reliability
    for _, pixel in ipairs(pixels) do
        love.graphics.setColor(pixel.r, pixel.g, pixel.b, pixel.a)
        love.graphics.rectangle("fill", pixel.x, pixel.y, 1, 1)
    end
    
    love.graphics.setCanvas()
    print("[Deserialize] Face canvas recreated successfully")
    return canvas
end

-- Save player data to a file
function savefile.savePlayerData(playerData)
    print("[Save] ===== SAVE FUNCTION CALLED =====")
    print("[Save] Player data type: " .. type(playerData))
    if playerData then
        print("[Save] Player name: " .. tostring(playerData.name))
        print("[Save] Player color: " .. tostring(playerData.color))
        print("[Save] Face points type: " .. type(playerData.facePoints))
        print("[Save] Face points exists: " .. tostring(playerData.facePoints ~= nil))
    end
    
    local data = {
        name = playerData.name or "Player",
        color = playerData.color or {1, 0, 0},
        faceCanvas = playerData.facePoints or playerData.faceCanvas
    }
    
    print("[Save] Face canvas exists: " .. tostring(data.faceCanvas ~= nil))
    if data.faceCanvas then
        print("[Save] Face canvas type: " .. type(data.faceCanvas))
        -- Check if it's a valid Love2D canvas
        local success, width, height = pcall(function()
            return data.faceCanvas:getWidth(), data.faceCanvas:getHeight()
        end)
        if success then
            print("[Save] Canvas dimensions: " .. width .. "x" .. height)
        else
            print("[Save] Canvas is not valid Love2D canvas")
        end
    end
    
    local faceData = ""
    if data.faceCanvas then
        local serializedData = savefile.serializeFaceCanvas(data.faceCanvas)
        print("[Save] Serialized face data length: " .. (serializedData and #serializedData or 0))
        if serializedData then
            faceData = "face=" .. serializedData .. "\n"
        end
    end
    
    -- Test basic file writing first
    local testContent = "name=" .. data.name .. "\n" ..
                       "color=" .. data.color[1] .. "," .. data.color[2] .. "," .. data.color[3] .. "\n" ..
                       "test=basic_save_works\n" ..
                       faceData
    
    print("[Save] Attempting to write file with content length: " .. #testContent)
    
    local success, err = pcall(function()
        local file = love.filesystem.write("player_data.txt", testContent)
    end)
    
    if success then
        print("[Save] Player data saved successfully")
        print("[Save] File content preview: name=" .. data.name .. ", color=" .. 
              data.color[1] .. "," .. data.color[2] .. "," .. data.color[3] .. 
              ", face data length=" .. (faceData and #faceData or 0))
        
        -- Verify file was created
        local fileInfo = love.filesystem.getInfo("player_data.txt")
        if fileInfo then
            print("[Save] File exists, size: " .. fileInfo.size .. " bytes")
        else
            print("[Save] ERROR: File was not created!")
        end
        
        return true
    else
        print("[Save] Failed to save player data: " .. tostring(err))
        return false
    end
end

-- Load player data from file
function savefile.loadPlayerData()
    print("[Load] ===== LOAD FUNCTION CALLED =====")
    local playerData = {
        name = "Player",
        color = {1, 0, 0},
        facePoints = nil
    }
    
    local fileInfo = love.filesystem.getInfo("player_data.txt")
    if fileInfo then
        print("[Load] Save file exists, size: " .. fileInfo.size .. " bytes")
        local content = love.filesystem.read("player_data.txt")
        if content then
            print("[Load] File content length: " .. #content)
            print("[Load] File content preview: " .. content:sub(1, math.min(200, #content)))
            
            for line in content:gmatch("[^\r\n]+") do
                print("[Load] Processing line: " .. line)
                if line:match("^name=") then
                    playerData.name = line:match("^name=(.+)")
                    print("[Load] Loaded name: " .. playerData.name)
                elseif line:match("^color=") then
                    local r, g, b = line:match("^color=([%d.]+),([%d.]+),([%d.]+)")
                    if r and g and b then
                        playerData.color = {tonumber(r), tonumber(g), tonumber(b)}
                        print("[Load] Loaded color: " .. r .. "," .. g .. "," .. b)
                    end
                elseif line:match("^test=") then
                    local testValue = line:match("^test=(.+)")
                    print("[Load] Found test value: " .. testValue)
                elseif line:match("^face=") then
                    local faceData = line:match("^face=(.+)")
                    print("[Load] Found face data line, length: " .. (faceData and #faceData or 0))
                    if faceData and faceData ~= "" then
                        -- Recreate face canvas (using standard canvas size)
                        playerData.facePoints = savefile.deserializeFaceCanvas(faceData, 100, 100)
                        if playerData.facePoints then
                            print("[Load] Face data loaded successfully, canvas type: " .. type(playerData.facePoints))
                        else
                            print("[Load] Failed to load face data")
                        end
                    else
                        print("[Load] No face data found in line")
                    end
                end
            end
            print("[Load] Player data loaded successfully")
        else
            print("[Load] Failed to read file content")
        end
    else
        print("[Load] No save file found, using defaults")
    end
    
    print("[Load] Final loaded data - name: " .. playerData.name .. ", color: " .. 
          tostring(playerData.color) .. ", facePoints: " .. tostring(playerData.facePoints ~= nil))
    return playerData
end

return savefile

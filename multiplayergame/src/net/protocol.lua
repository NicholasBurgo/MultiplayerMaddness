-- Note: This project doesn't appear to have dkjson or json, so we'll use a simple serialization
local P = {}
P.VERSION = "0.1.0"
P.K = { 
    HELLO=true, 
    JOIN=true, 
    JOIN_ACCEPTED=true,
    YOUR_ID=true,
    NEW_PLAYER=true,
    STATE=true, 
    INPUT=true, 
    PING=true, 
    PONG=true, 
    CHAT=true, 
    START_MATCH=true,
    START_GAME=true,
    VOTE=true,
    VOTE_UPDATE=true,
    LEVEL_VOTE=true,
    PARTY_MODE_VOTE=true,
    PLAYER_MOVE=true,
    JUMP_POSITION=true,
    LASER_POSITION=true,
    BATTLE_POSITION=true,
    DODGE_POSITION=true,
    PRAISE_POSITION=true,
    METEOR_SYNC=true,
    PLAYER_DEATH=true,
    JUMP_SCORE=true,
    PLAYER_SCORE=true,
    QUIT_VOTE_START=true,
    QUIT_VOTE=true,
    QUIT_VOTE_RESULT=true,
    KICK_PLAYER=true,
    PLAYER_KICKED=true
}

local function assertKind(k) assert(P.K[k], "Unknown kind: "..tostring(k)) end

-- Simple table serialization for Lua tables
local function serialize(t)
    if type(t) ~= "table" then return tostring(t) end
    local parts = {}
    for k, v in pairs(t) do
        local key = type(k) == "number" and "["..k.."]" or '["'..tostring(k)..'"]'
        local val = type(v) == "table" and serialize(v) or (type(v) == "string" and '"'..v..'"' or tostring(v))
        table.insert(parts, key.."="..val)
    end
    return "{"..table.concat(parts, ",").."}"
end

local function deserialize(s)
    local fn = load("return " .. s)
    if fn then return fn() end
    return nil
end

function P.encode(kind, tbl) 
    assertKind(kind) 
    local msg = {k=kind, d=tbl, v=P.VERSION}
    return serialize(msg)
end

function P.decode(s) 
    local t = deserialize(s)
    if not t then return nil, nil, nil end
    assertKind(t.k)
    return t.k, t.d, t.v
end

function P.validate(kind, data)
    -- Add field checks for your payloads
    return true
end

return P

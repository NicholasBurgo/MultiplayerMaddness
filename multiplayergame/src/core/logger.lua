local LOG_LEVEL = (os and os.getenv and os.getenv("LOG_LEVEL")) or "info"
local levels = { debug=1, info=2, warn=3, error=4 }
local cur = levels[LOG_LEVEL] or 2
local function out(l, tag, msg) if levels[l] >= cur then print(("[%s][%s] %s"):format(l, tag or "-", msg or "")) end end
return { debug=function(t,m) out("debug",t,m) end, info=function(t,m) out("info",t,m) end,
         warn=function(t,m) out("warn",t,m) end,  error=function(t,m) out("error",t,m) end }

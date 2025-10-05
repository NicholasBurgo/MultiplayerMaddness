local U = require("src.core.util")
local S = {}
function S.new()
  return { players = {}, tick = 0, round = 1, over=false, meta={} }
end
function S.clone(st) return U.deepcopy(st) end
return S

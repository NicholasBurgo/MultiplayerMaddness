local M = {}
function M.deepcopy(t) if type(t)~="table" then return t end local r={} for k,v in pairs(t) do r[M.deepcopy(k)] = M.deepcopy(v) end return r end
function M.clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end
return M

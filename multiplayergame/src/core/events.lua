local M = {}
local subs = {}
function M.on(evt, fn)
  subs[evt] = subs[evt] or {}
  table.insert(subs[evt], fn); return function()
    for i,f in ipairs(subs[evt]) do if f==fn then table.remove(subs[evt], i) break end end
  end
end
function M.emit(evt, data)
  local ls = subs[evt]; if not ls then return end
  for _,f in ipairs(ls) do f(data) end
end
return M

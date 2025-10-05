local P = {}
local palette = { {1,0,0},{0,1,0},{0,0,1},{1,1,0},{1,0,1},{0,1,1},{1,1,1},{.5,.5,.5} }
function P.getColorFor(id) return palette[(id % #palette) + 1] end
function P.add(state, playerId) state.players[playerId] = state.players[playerId] or { id=playerId, color=P.getColorFor(playerId), score=0 } end
function P.remove(state, playerId) state.players[playerId] = nil end
return P

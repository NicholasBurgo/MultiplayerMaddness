local T = {}
function T.new(seconds, on_done) return {t=seconds or 0, done=false, cb=on_done} end
function T.reset(timer, seconds) timer.t=seconds or timer.t; timer.done=false end
function T.update(timer, dt) if timer.done then return end timer.t = timer.t - dt; if timer.t <= 0 then timer.done=true; if timer.cb then timer.cb() end end end
function T.running(timer) return not timer.done end
return T

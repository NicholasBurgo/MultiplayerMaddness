-- ============================================================================
-- GAME MODES REGISTRY
-- ============================================================================
-- Loads all available game mode modules and registers them with the app
-- Each mode module implements: load(args), update(dt), draw(), reset(), etc.

local modes = {}

-- Load all game modes from the games directory
-- These are already in module format, so we can require them directly
modes.jump = require("src.game.scenes.modes.games.jumpgame")
modes.laser = require("src.game.scenes.modes.games.lasergame")
modes.meteorshower = require("src.game.scenes.modes.games.meteorshower")
modes.dodge = require("src.game.scenes.modes.games.dodgegame")
modes.colorstorm = require("src.game.scenes.modes.games.colorstorm")
modes.particlecollector = require("src.game.scenes.modes.games.particlecollector")
modes.praise = require("src.game.scenes.modes.games.praisegame")

-- Legacy modes (may need additional integration work)
-- Uncomment when ready to integrate:
-- modes.duel = require("scripts.legacy.duelgame")
-- modes.race = require("scripts.legacy.racegame")

return modes

-- constants.lua
-- Shared constants across all game modules

local constants = {}

-- Screen dimensions
constants.BASE_WIDTH = 800
constants.BASE_HEIGHT = 600

-- Default player properties
constants.DEFAULT_PLAYER_COLOR = {1, 1, 1}
constants.DEFAULT_PLAYER_SIZE = 30

-- Game state constants
constants.GAME_STATES = {
    MENU = "menu",
    PLAYING = "playing",
    HOSTING = "hosting",
    CUSTOMIZATION = "customization"
}

-- Timer constants
constants.DEFAULT_GAME_DURATION = 25 -- seconds

-- UI constants
constants.UI_COLORS = {
    WHITE = {1, 1, 1},
    BLACK = {0, 0, 0},
    RED = {1, 0, 0},
    GREEN = {0, 1, 0},
    BLUE = {0, 0, 1},
    YELLOW = {1, 1, 0},
    GRAY = {0.5, 0.5, 0.5},
    LIGHT_GRAY = {0.8, 0.8, 0.8}
}

-- Input constants
constants.INPUT_KEYS = {
    MOVE_LEFT = {"a", "left"},
    MOVE_RIGHT = {"d", "right"},
    MOVE_UP = {"w", "up"},
    MOVE_DOWN = {"s", "down"},
    JUMP = {"w", "up"},
    ACTION = {"space"}
}

return constants

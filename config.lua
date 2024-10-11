local M = {}

--- @enum Mode
local Mode = { -- table indexes starts from 1
    minimal = 1,
    default = 2,
    advanced = 3,
}

local speed_mode = Mode.advanced

M = {

    --
    -- Math constants
    --

    PHI = 1.618,
    PHI_INV = 0.618,
    PI = math.pi,
    PI_INV = 1 / math.pi,

    --
    -- FLAGS
    --

    IS_CREATURE_FOLLOW_PLAYER = true,
    IS_CREATURE_FUSION_ENABLED = false, --- FIXME: Assertion fails in `simulate.lua`
    IS_CREATURE_SWARM_ENABLED = true,
    IS_GAME_SLOW = false,
    IS_GRUG_BRAIN = false, --- Whether to complicate life and the codebase.
    IS_PLAYER_INVULNERABLE = false,
    IS_PLAYER_PROJECTILE_WRAP_AROUND_ARENA = false, --- Flags if fired projectile should wrap around arena.

    --
    -- Configurations
    --

    AIR_RESISTANCE = 0.98, --- Resistance factor between 0 and 1.

    FIXED_FPS = 60,
    LASER_FIRE_TIMER_LIMIT = ({ 0.16, 0.12, 0.10 })[speed_mode], --- Reduce this to increase fire rate.
    LASER_PROJECTILE_SPEED = ({ 2 ^ 8, 2 ^ 9, 2 ^ 9 + 256 })[speed_mode], --- 256|512|768

    MAX_GAME_LEVELS = 2 ^ 6, --> 64
    MAX_LASER_CAPACITY = 2 ^ 5, -- Choices: 2^4(balanced [nerfs fast fire rate]) | 2^5 (long range)
    MAX_PLAYER_HEALTH = 3,

    PLAYER_ACCELERATION = ({ 150, 200, 300 })[speed_mode],
    PLAYER_FIRE_COOLDOWN_TIMER_LIMIT = ({ 4, 6, 12 })[speed_mode], --- TODO: Implement this (6 is rough guess, but intend for alpha lifecycle from 0.0 to 1.0.) -- see if this is in love.load()

    --
    -- Variables
    --

    debug = { --- Debugging Flags.
        is_assert = true,
        is_development = false,
        is_test = true,
        is_trace_entities = false,
        is_trace_hud = true,
    },
}
--
-- Configurations
--

M.DEFAULT_PLAYER_TURN_SPEED = ({
    (10 * M.PHI_INV),
    10,
    -3 + (30 / 2) / 4 + (M.PLAYER_ACCELERATION / M.FIXED_FPS),
})[speed_mode]
M.PLAYER_CIRCLE_IRIS_TO_EYE_RATIO = M.PHI_INV

--
-- Derived Configurations
--

M.FIXED_DT = 1 / M.FIXED_FPS --- Consistent update frame rate fluctuations.
M.FIXED_DT_INV = 1 / (1 / M.FIXED_FPS) --- avoid dividing each frame

assert(M.PLAYER_ACCELERATION / M.DEFAULT_PLAYER_TURN_SPEED <= 60)

return M

local M = {}

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
    IS_CREATURE_FUSION_ENABLED = false,
    IS_CREATURE_SWARM_ENABLED = true,
    IS_GAME_SLOW = false,
    IS_GRUG_BRAIN = false,                          --- Whether to complicate life and the codebase.
    IS_PLAYER_INVULNERABLE = false,
    IS_PLAYER_PROJECTILE_WRAP_AROUND_ARENA = false, --- Flags if fired projectile should wrap around arena.

    --
    -- Configurations
    --

    AIR_RESISTANCE = 0.98, -- Resistance factor between 0 and 1.
    FIXED_FPS = 60,
    LASER_FIRE_TIMER_LIMIT = 0.5 * 0.2 * 1,
    LASER_PROJECTILE_SPEED = 2 ^ 9,       -- 512
    MAX_GAME_LEVELS = 16,
    MAX_LASER_CAPACITY = 2 ^ 4,           -- Choices: 2^4(balanced [nerfs fast fire rate]) | 2^5 (long range)
    PLAYER_ACCELERATION = 100 * 2,
    PLAYER_FIRE_COOLDOWN_TIMER_LIMIT = 6, --- TODO: Implement this (6 is rough guess, but intend for alpha lifecycle from 0.0 to 1.0.) -- see if this is in love.load()

    --
    -- Variables
    --

    debug = { --- Debugging Flags.
        is_development = false,
        is_test = false,
        is_trace_entities = false,
    },
}
--
-- Configurations
--
M.DEFAULT_PLAYER_TURN_SPEED = 10 * M.PHI_INV
M.PLAYER_CIRCLE_IRIS_TO_EYE_RATIO = M.PHI_INV
--
-- Derived Configurations
--

M.FIXED_DT = 1 / M.FIXED_FPS           --- Consistent update frame rate fluctuations.
M.FIXED_DT_INV = 1 / (1 / M.FIXED_FPS) --- avoid dividing each frame



return M

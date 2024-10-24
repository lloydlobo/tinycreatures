local M = {}

--- @enum Mode
local Mode = { -- table indexes starts from 1
        minimal = 1,
        default = 2,
        advanced = 3,
}

--- @enum Theme
local Theme = {
        low_light = 1,
        medium_light = 2,
        high_light = 3,
}

local speed_mode = Mode.advanced

local _fixed_fps = 60
local _phi = 1.618
local _phi_inv = 0.618
local _player_acceleration = ({ 150, 200, 300 })[speed_mode]
local _player_radius = (32 * 0.61) - 4

M = {
        -- CONFIGURATIONS

        AIR_RESISTANCE = 0.95, --- Resistance factor between 0 and 1.
        CURRENT_THEME = Theme.low_light,
        FIXED_DT = 1 / _fixed_fps, --- Consistent update frame rate fluctuations.
        FIXED_DT_INV = 1 / (1 / _fixed_fps), --- Helper constant to avoid dividing on each frame.
        FIXED_FPS = _fixed_fps,
        LASER_FIRE_TIMER_LIMIT = _phi_inv * ({ 0.21, 0.16, 0.14 })[speed_mode], --- Reduce this to increase fire rate.
        LASER_PROJECTILE_SPEED = ({ 2 ^ 7, 2 ^ 8, 2 ^ 8 + 256 })[speed_mode], --- 256|512|768
        LASER_RADIUS = math.floor(_player_radius * _phi_inv),
        MAX_GAME_LEVELS = 2 ^ 6, -- > 64
        MAX_CREATURE_RADIUS = 80,
        MAX_LASER_CAPACITY = 2 ^ 5, -- Choices: 2^4(balanced [nerfs fast fire rate]) | 2^5 (long range)
        MAX_PLAYER_HEALTH = 3,
        MAX_PLAYER_TRAIL_COUNT = -4 + math.floor(math.pi * math.sqrt(_player_radius * _phi_inv)), -- player_radius(32)*PHI==20(approx)
        PLAYER_ACCELERATION = 3 * ({ 150, 200, 300 })[speed_mode],
        PLAYER_CIRCLE_IRIS_TO_EYE_RATIO = _phi_inv,
        PLAYER_DEFAULT_TURN_SPEED = ({ (10 * _phi_inv), 10, -2 + (30 / 2) / 4 + (_player_acceleration / _fixed_fps) })[speed_mode],
        PLAYER_FIRE_COOLDOWN_TIMER_LIMIT = ({ 4, 6, 12 })[speed_mode], --- FIXME: Implement this (6 is rough guess, but intend for alpha lifecycle from 0.0 to 1.0.) -- see if this is in love.load()
        PLAYER_FIRING_EDGE_MAX_RADIUS = 0.9 * math.ceil(_player_radius * (true and 0.328 or (_phi_inv * _phi_inv))), --- Trigger distance from center of player.
        PLAYER_FIRING_EDGE_RADIUS = 1.1 * math.ceil(_player_radius * (true and 0.328 or (_phi_inv * _phi_inv))), --- Trigger distance from center of player.
        PLAYER_RADIUS = _player_radius,
        PLAYER_TRAIL_THICKNESS = 1.2 * math.ceil(_player_radius * _phi_inv), -- HACK: 32 is player_radius global var in love.load (same size as dark of eye looks good)

        -- FLAGS

        IS_CREATURE_FOLLOW_PLAYER = true,
        IS_CREATURE_FUSION_ENABLED = not true, --- FIXME: Assertion fails in `simulate.lua`
        IS_CREATURE_SWARM_ENABLED = not true,
        IS_GAME_SLOW = not true,
        IS_GRUG_BRAIN = not true, --- Whether to complicate life and the codebase.
        IS_PLAYER_INVULNERABLE = not true,
        IS_PLAYER_PROJECTILE_WRAP_AROUND_ARENA = not true, --- Flags if fired projectile should wrap around arena.

        -- Math constants (to fiddle with for random discoveries)

        PHI = _phi,
        PHI_INV = _phi_inv,
        PI = math.pi,
        PI_INV = 1 / math.pi,

        -- DEBUGGING FLAGS

        debug = {
                is_assert = not true,
                is_development = not true,
                is_test = true,
                is_trace_entities = not true,
                is_trace_hud = not true,
        },

        Theme = Theme, -- FIXME: Shouldn't this be in common.lua?
}

local is_skip_assert = true
if not is_skip_assert then assert(M.PLAYER_ACCELERATION / M.PLAYER_DEFAULT_TURN_SPEED <= 60, 'Expected <= 60. Actual: ' .. M.PLAYER_ACCELERATION) end

return M

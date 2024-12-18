-- file: config.lua

--- @enum Mode
local Mode = { -- table indexes starts from 1
    MINIMAL = 1,
    DEFAULT = 2,
    ADVANCED = 3,
}

--- @enum Theme
local Theme = {
    LOW_LIGHT = 1,
    MEDIUM_LIGHT = 2,
    HIGH_LIGHT = 3,
}

local _speed_mode = Mode.ADVANCED

local _fixed_fps = 60
local _inv_phi = 0.618
local _phi = 1.618

local _inv_phi_sq = 1 / (_phi ^ 2)

--- @class (exact) CreatureStage
--- @field radius integer
--- @field speed number

local _creature_initial_large_count = (2 ^ 1) --[[NOTE: Increase this for more challenging levels that are not trivial]]
local _creatures_initial_constant_large_count = (2 ^ 4)
local _cret_max_radius = 92
local _cret_max_speed = 100 -- 32..120
local _cret_min_radius = 8
local _cret_min_speed = 32
local _f_cret_scale = 1. -- factor
local _f_cret_speed = 1. -- factor

--- @type CreatureStage[] Size decreases as stage progresses.
local _CREATURE_STAGES = {
    {
        radius = math.max(_cret_min_radius, math.ceil(_cret_max_radius * (_inv_phi ^ 5) * _f_cret_scale)),
        speed = (math.min(_cret_max_speed, math.floor(_cret_min_speed * (_phi ^ 3.8) * _f_cret_speed))),
    },
    {
        radius = math.ceil(_cret_max_radius * (_inv_phi ^ 3) * _f_cret_scale),
        speed = math.floor(_cret_min_speed * (_phi ^ 2) * _f_cret_speed),
    },
    {
        radius = math.ceil(_cret_max_radius * (_inv_phi ^ 2) * _f_cret_scale),
        speed = math.floor(_cret_min_speed * (_phi ^ 1) * _f_cret_speed),
    },
    {
        radius = math.ceil(_cret_max_radius * (_inv_phi ^ 0) * _f_cret_scale),
        speed = math.floor(_cret_min_speed * (_phi ^ 0) * _f_cret_speed),
    },
}

local _player_accel = ({ 150, 200, 300 })[_speed_mode]
local _player_radius = math.min(_CREATURE_STAGES[1].radius * _phi, (32 * 0.61) - 4)
local _companion_size = (_player_radius / (_phi ^ 1))

--- @class (exact) MoonshineShaderSettings
--- @field bloom_intensity { enable: boolean, amount: number }
--- @field chromatic_abberation {enable:boolean, mode: 'minimal'|'default'|'advanced'}
--- @field curved_monitor {enable:boolean, amount:number}
--- @field filmgrain {enable:boolean, amount:number}
--- @field lens_dirt {enable:boolean}
--- @field scanlines {enable:boolean, mode:'grid'|'horizontal'}
local _MoonshineShaderSettings = {
    bloom_intensity = {
        enable = true,
        amount = 0.05,
    }, --- For `fx.glow`.
    chromatic_abberation = {
        enable = not true,
        mode = 'minimal',
    },
    curved_monitor = {
        enable = not true,
        amount = _phi,
    },
    filmgrain = {
        enable = not true,
        amount = _inv_phi,
    },
    lens_dirt = {
        enable = not true,
    }, --- unimplemented
    scanlines = {
        enable = not true,
        mode = 'horizontal',
    }, -- NOTE: ENABLED FOR BG SHADER---PERHAPS HAVE MORE OPTIONS TO PICK FOR post_processing and background_shader????
}

-- do --TESTING
--     do
--         local is_skip_assert = true
--         if not is_skip_assert then --
--             assert((M.PLAYER_ACCELERATION / M.PLAYER_DEFAULT_TURN_SPEED <= 60), 'Expected <= 60. Actual: ' .. M.PLAYER_ACCELERATION)
--         end
--     end
--
--     do -- Test `creature_evolution_stages`.
--         local max_creature_mutation_count = 0
--         for i = 1, #M.CREATURE_STAGES do
--             max_creature_mutation_count = max_creature_mutation_count + i
--             local stage = M.CREATURE_STAGES[i]
--             local speed = stage.speed
--             local radius = stage.radius
--             assert(speed > M.MIN_CREATURE_SPEED and speed <= M.MAX_CREATURE_SPEED)
--             assert(radius >= M.MIN_CREATURE_RADIUS and radius <= M.MAX_CREATURE_RADIUS)
--         end
--         assert(max_creature_mutation_count == 10, 'Assert 1 creature (ancestor) »»mutates»» into ten creatures including itself.')
--     end
-- end

--- @class (exact) Config
return {
    --- @class (exact) debug
    --- @field IS_ASSERT boolean = true,
    --- @field IS_DEVELOPMENT boolean = false,
    --- @field IS_TEST boolean = true,
    --- @field IS_TRACE_ENTITIES boolean = false,
    --- @field IS_TRACE_HUD boolean = false,
    Debug = {
        IS_ASSERT = true,
        IS_DEVELOPMENT = not true,
        IS_TEST = true,
        IS_TRACE_ENTITIES = not true,
        IS_TRACE_HUD = not true, -- Heads Up Displaye
    },
    Mode = Mode,
    MoonshineShaderSettings = _MoonshineShaderSettings,
    Theme = Theme, -- FIXME: Shouldn't this be in common.lua?

    --
    -- flags
    --

    IS_CREATURE_FOLLOW_PLAYER = true,
    IS_CREATURE_FUSION_ENABLED = not true, --- FIXME: Assertion fails in `simulate.lua`
    IS_CREATURE_SWARM_ENABLED = not true,
    IS_GAME_SLOW = not true,
    IS_GRUG_BRAIN = not true, --- Whether to complicate life and the codebase.
    IS_PLAYER_INVULNERABLE = not true,
    IS_PLAYER_PROJECTILE_WRAP_AROUND_ARENA = not true, --- Flags if fired projectile should wrap around arena.

    --
    -- math constants
    --

    INV_PHI = _inv_phi,
    INV_PHI_SQ = _inv_phi_sq,
    INV_PI = 1 / math.pi,
    PHI = _phi,
    PHI_SQ = (_phi ^ 2),
    PI = math.pi,
    TWO_PI = 2 * math.pi,

    --
    -- game constants
    --

    AIR_RESISTANCE = 0.95, --- Resistance factor between 0 and 1.
    COMPANION_DIST_FROM_PLAYER = (_phi ^ 4) * _companion_size, -- FIXME: THIS SHOULD INCLUDE LASER RADIUS TOO (FOR PRECISE CENTERING)
    COMPANION_SIZE = _companion_size,
    CREATURE_EXPECTED_FINAL_HEALED_COUNT = ((_creature_initial_large_count ^ 2) - _creature_initial_large_count), --- @type integer # Double buffer size possible creatures count `initial count ^ 2`
    CREATURE_INITIAL_CONSTANT_LARGE_STAGE_COUNT = _creatures_initial_constant_large_count, -- WARN: Any more than this, and levels above 50 lag
    CREATURE_INTIAL_LARGE_STAGE_COUNT = _creature_initial_large_count, --- @type integer # This count excludes the initial ancestor count.k
    CREATURE_MAX_RADIUS = _CREATURE_STAGES[#_CREATURE_STAGES].radius,
    CREATURE_MAX_SPEED = _CREATURE_STAGES[1].speed,
    CREATURE_MIN_RADIUS = _CREATURE_STAGES[1].radius,
    CREATURE_MIN_SPEED = _CREATURE_STAGES[#_CREATURE_STAGES].speed,
    CREATURE_STAGES = _CREATURE_STAGES,
    CREATURE_STAGES_COUNT = #_CREATURE_STAGES,
    CREATURE_TOTAL_CAPACITY = (2 * (_creature_initial_large_count ^ 2)),
    CURRENT_THEME = Theme.LOW_LIGHT,
    FIXED_DT = 1 / _fixed_fps, --- Consistent update frame rate fluctuations.
    FIXED_DT_INV = 1 / (1 / _fixed_fps), --- Helper constant to avoid dividing on each frame. (same as FIXED_FPS)
    FIXED_FPS = _fixed_fps,
    GAME_MAX_LEVEL = 2 ^ 6, -- > 64
    LASER_FIRE_TIMER_LIMIT = (_inv_phi ^ 2.0) * ({ 0.21, 0.16, 0.14 })[_speed_mode], --- Reduce this to increase fire rate.
    LASER_MAX_CAPACITY = 2 ^ 8, -- Choices: 2^4(balanced [nerfs fast fire rate]) | 2^5 (long range)
    LASER_PROJECTILE_SPEED = ({ 2 ^ 7, 2 ^ 8, 2 ^ 8 + 256 })[_speed_mode], --- 256|512|768
    LASER_RADIUS = (_inv_phi ^ 1) * math.max(_inv_phi * _player_radius, math.floor(_player_radius * (_inv_phi ^ (1 * _phi)))),
    PARALLAX_ENTITY_IMG_RADIUS = 48,
    PARALLAX_ENTITY_MAX_COUNT = (2 ^ 6),
    PARALLAX_ENTITY_MAX_DEPTH = 3, --- @type integer
    PARALLAX_ENTITY_MIN_DEPTH = 1, --- @type integer
    PARALLAX_ENTITY_RADIUS_FACTOR = _inv_phi_sq, --- QUESTION: Are we scaling up by this factor? (should ensure resulting radius is similar to `PARALLAX_ENTITY_IMG_RADIUS`)
    PARALLAX_OFFSET_FACTOR_X = 0.00, -- NOTE: Should be lower to avoid puking
    PARALLAX_OFFSET_FACTOR_Y = 0.00,
    PLAYER_ACCELERATION = math.floor(3 * (true and 1 or 1.25) * ({ 150, 200, 300 })[_speed_mode]),
    PLAYER_CIRCLE_IRIS_TO_EYE_RATIO = _inv_phi,
    PLAYER_ROT_TURN_SPEED = ({ (10 * _inv_phi), 10, -2 + (30 / 2) / 4 + (_player_accel / _fixed_fps) })[_speed_mode],
    PLAYER_TURN_SPEED_BESERK_MULTIPLIER = _phi * _phi,
    PLAYER_FIRE_COOLDOWN_TIMER_LIMIT = ({ 4, 6, 12 })[_speed_mode], --- FIXME: Implement this (6 is rough guess, but intend for alpha lifecycle from 0.0 to 1.0.) -- see if this is in love.load()
    PLAYER_FIRING_EDGE_MAX_RADIUS = (0.6 * math.ceil(_player_radius * (true and 0.328 or (_inv_phi * _inv_phi)))), --- Trigger distance from center of player.
    PLAYER_FIRING_EDGE_RADIUS = (0.9 * math.ceil(_player_radius * (true and 0.328 or (_inv_phi * _inv_phi)))), --- Trigger distance from center of player.
    PLAYER_MAX_HEALTH = 4,
    PLAYER_MAX_TRAIL_COUNT = 8, -- (-2 + math.floor(math.pi * math.sqrt(_player_radius * _inv_phi))), -- player_radius(32)*PHI==20(approx)
    PLAYER_RADIUS = _player_radius,
    PLAYER_TRAIL_THICKNESS = (1.2 * math.ceil(_player_radius * _inv_phi)), -- HACK: 32 is player_radius global var in love.load (same size as dark of eye looks good)
}

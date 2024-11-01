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

local __creature_scale_factor = 1
local __creature_speed_factor = 1.35
local _constant_initial_large_creatures = (2 ^ 3)
local _fixed_fps = 60
local _initial_lg_creatures = (2 ^ 1) --[[NOTE: Increase this for more challenging levels that are not trivial]]
local _inv_phi = 0.618
local _max_creature_radius = 100
local _max_creature_speed = 120
local _min_creature_radius = 8
local _min_creature_speed = 32
local _phi = 1.618
local _player_acceleration = ({ 150, 200, 300 })[speed_mode]
local _player_radius = (32 * 0.61) - 4

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
    INV_PHI = _inv_phi,
    INV_PI = 1 / math.pi,
    PHI = _phi,
    PI = math.pi,
    TWO_PI = 2 * math.pi,

    Theme = Theme, -- FIXME: Shouldn't this be in common.lua?

    --- @class (exact) debug
    --- @field is_assert boolean = true,
    --- @field is_development boolean = false,
    --- @field is_test boolean = true,
    --- @field is_trace_entities boolean = false,
    --- @field is_trace_hud boolean = false,
    debug = {
        is_assert = true,
        is_development = not true,
        is_test = true,
        is_trace_entities = not true,
        is_trace_hud = not true,
    },

    IS_CREATURE_FOLLOW_PLAYER = true,
    IS_CREATURE_FUSION_ENABLED = not true, --- FIXME: Assertion fails in `simulate.lua`
    IS_CREATURE_SWARM_ENABLED = not true,
    IS_GAME_SLOW = not true,
    IS_GRUG_BRAIN = not true, --- Whether to complicate life and the codebase.
    IS_PLAYER_INVULNERABLE = not true,
    IS_PLAYER_PROJECTILE_WRAP_AROUND_ARENA = not true, --- Flags if fired projectile should wrap around arena.

    AIR_RESISTANCE = 0.95, --- Resistance factor between 0 and 1.
    CONSTANT_INITIAL_LARGE_CREATURES = _constant_initial_large_creatures, -- WARN: Any more than this, and levels above 50 lag
    CURRENT_THEME = Theme.low_light,
    EXPECTED_FINAL_HEALED_CREATURE_COUNT = ((_initial_lg_creatures ^ 2) - _initial_lg_creatures), --- @type integer # Double buffer size possible creatures count `initial count ^ 2`
    FIXED_DT = 1 / _fixed_fps, --- Consistent update frame rate fluctuations.
    FIXED_DT_INV = 1 / (1 / _fixed_fps), --- Helper constant to avoid dividing on each frame. (same as FIXED_FPS)
    FIXED_FPS = _fixed_fps,
    INITIAL_LARGE_CREATURES = _initial_lg_creatures, --- @type integer # This count excludes the initial ancestor count.
    LASER_FIRE_TIMER_LIMIT = _inv_phi * ({ 0.21, 0.16, 0.14 })[speed_mode], --- Reduce this to increase fire rate.
    LASER_PROJECTILE_SPEED = ({ 2 ^ 7, 2 ^ 8, 2 ^ 8 + 256 })[speed_mode], --- 256|512|768
    LASER_RADIUS = math.floor(_player_radius * (_inv_phi ^ (1 * _phi))),
    MAX_CREATURE_RADIUS = 100,
    MAX_CREATURE_SPEED = _max_creature_speed,
    MAX_GAME_LEVELS = 2 ^ 6, -- > 64
    MAX_LASER_CAPACITY = 2 ^ 6, -- Choices: 2^4(balanced [nerfs fast fire rate]) | 2^5 (long range)
    MAX_PARALLAX_ENTITIES = (2 ^ 4),
    MAX_PLAYER_HEALTH = 3,
    MAX_PLAYER_TRAIL_COUNT = -2 + math.floor(math.pi * math.sqrt(_player_radius * _inv_phi)), -- player_radius(32)*PHI==20(approx)
    MIN_CREATURE_RADIUS = 8,
    MIN_CREATURE_SPEED = _min_creature_speed, -- 20|30
    PARALLAX_ENTITY_MAX_DEPTH = 4, --- @type integer
    PARALLAX_ENTITY_MIN_DEPTH = 1, --- @type integer
    PARALLAX_OFFSET_FACTOR_X = 0.0275 * _inv_phi, -- NOTE: Should be lower to avoid puking
    PARALLAX_OFFSET_FACTOR_Y = 0.0275 * _inv_phi,
    PLAYER_ACCELERATION = math.floor(3 * (true and 1 or 1.25) * ({ 150, 200, 300 })[speed_mode]),
    PLAYER_CIRCLE_IRIS_TO_EYE_RATIO = _inv_phi,
    PLAYER_DEFAULT_TURN_SPEED = ({ (10 * _inv_phi), 10, -2 + (30 / 2) / 4 + (_player_acceleration / _fixed_fps) })[speed_mode],
    PLAYER_FIRE_COOLDOWN_TIMER_LIMIT = ({ 4, 6, 12 })[speed_mode], --- FIXME: Implement this (6 is rough guess, but intend for alpha lifecycle from 0.0 to 1.0.) -- see if this is in love.load()
    PLAYER_FIRING_EDGE_MAX_RADIUS = 0.9 * math.ceil(_player_radius * (true and 0.328 or (_inv_phi * _inv_phi))), --- Trigger distance from center of player.
    PLAYER_FIRING_EDGE_RADIUS = 1.0 * math.ceil(_player_radius * (true and 0.328 or (_inv_phi * _inv_phi))), --- Trigger distance from center of player.
    PLAYER_RADIUS = _player_radius,
    PLAYER_TRAIL_THICKNESS = 1.2 * math.ceil(_player_radius * _inv_phi), -- HACK: 32 is player_radius global var in love.load (same size as dark of eye looks good)
    TOTAL_CREATURES_CAPACITY = (2 * (_initial_lg_creatures ^ 2)),

    --- @type CreatureStage[] Size decreases as stage progresses.
    CREATURE_STAGES = {
        {
            speed = (math.min(_max_creature_speed, math.floor(_min_creature_speed * (_phi ^ 3.8) * __creature_speed_factor))),
            radius = (math.max(_min_creature_radius, math.ceil(_max_creature_radius * (_inv_phi ^ 5) * __creature_scale_factor))),
        },
        {
            speed = math.floor(_min_creature_speed * (_phi ^ 2) * __creature_speed_factor),
            radius = math.ceil(_max_creature_radius * (_inv_phi ^ 3) * __creature_scale_factor),
        },
        {
            speed = math.floor(_min_creature_speed * (_phi ^ 1) * __creature_speed_factor),
            radius = math.ceil(_max_creature_radius * (_inv_phi ^ 2) * __creature_scale_factor),
        },
        {
            speed = math.floor(_min_creature_speed * (_phi ^ 0) * __creature_speed_factor),
            radius = math.ceil(_max_creature_radius * (_inv_phi ^ 0) * __creature_scale_factor),
        },
    },

    --- Public API shader graphics config.
    --- @class (exact) MOONSHINE_SHADERS
    --- @field bloom_intensity { enable: boolean, amount: number }
    --- @field chromatic_abberation {enable:boolean, mode: 'minimal'|'default'|'advanced'}
    --- @field curved_monitor {enable:boolean, amount:number}
    --- @field filmgrain {enable:boolean, amount:number}
    --- @field lens_dirt {enable:boolean}
    --- @field scanlines {enable:boolean, mode:'grid'|'horizontal'}
    MOONSHINE_SHADERS = {
        bloom_intensity = { enable = true, amount = 0.05 }, --- For `fx.glow`.
        chromatic_abberation = { enable = true, mode = 'minimal' },
        curved_monitor = { enable = not true, amount = _phi },
        filmgrain = { enable = not true, amount = _inv_phi },
        lens_dirt = { enable = not true }, --- unimplemented
        scanlines = { enable = not true, mode = 'horizontal' }, -- NOTE: ENABLED FOR BG SHADER---PERHAPS HAVE MORE OPTIONS TO PICK FOR post_processing and background_shader????
    },
}

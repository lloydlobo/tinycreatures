--- @class (exact) Config
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
local _inv_phi = 0.618
local _player_acceleration = ({ 150, 200, 300 })[speed_mode]
local _player_radius = (32 * 0.61) - 4

M = {

    debug = {
        is_assert = true,
        is_development = true,
        is_test = true,
        is_trace_entities = not true,
        is_trace_hud = not true,
    },

    Theme = Theme, -- FIXME: Shouldn't this be in common.lua?

    AIR_RESISTANCE = 0.95, --- Resistance factor between 0 and 1.
    CURRENT_THEME = Theme.low_light,
    FIXED_DT = 1 / _fixed_fps, --- Consistent update frame rate fluctuations.
    FIXED_DT_INV = 1 / (1 / _fixed_fps), --- Helper constant to avoid dividing on each frame. (same as FIXED_FPS)
    FIXED_FPS = _fixed_fps,
    LASER_FIRE_TIMER_LIMIT = _inv_phi * ({ 0.21, 0.16, 0.14 })[speed_mode], --- Reduce this to increase fire rate.
    LASER_PROJECTILE_SPEED = ({ 2 ^ 7, 2 ^ 8, 2 ^ 8 + 256 })[speed_mode], --- 256|512|768
    LASER_RADIUS = math.floor(_player_radius * (_inv_phi ^ (1 * _phi))),
    MAX_CREATURE_RADIUS = 100,
    MAX_CREATURE_SPEED = 120,
    MAX_GAME_LEVELS = 2 ^ 6, -- > 64
    MAX_LASER_CAPACITY = 2 ^ 6, -- Choices: 2^4(balanced [nerfs fast fire rate]) | 2^5 (long range)
    MAX_PLAYER_HEALTH = 3,
    MAX_PLAYER_TRAIL_COUNT = -4 + math.floor(math.pi * math.sqrt(_player_radius * _inv_phi)), -- player_radius(32)*PHI==20(approx)
    MIN_CREATURE_RADIUS = 8,
    MIN_CREATURE_SPEED = 32, -- 20|30
    PLAYER_ACCELERATION = math.floor(3 * (true and 1 or 1.25) * ({ 150, 200, 300 })[speed_mode]),
    PLAYER_CIRCLE_IRIS_TO_EYE_RATIO = _inv_phi,
    PLAYER_DEFAULT_TURN_SPEED = ({ (10 * _inv_phi), 10, -2 + (30 / 2) / 4 + (_player_acceleration / _fixed_fps) })[speed_mode],
    PLAYER_FIRE_COOLDOWN_TIMER_LIMIT = ({ 4, 6, 12 })[speed_mode], --- FIXME: Implement this (6 is rough guess, but intend for alpha lifecycle from 0.0 to 1.0.) -- see if this is in love.load()
    PLAYER_FIRING_EDGE_MAX_RADIUS = 0.9 * math.ceil(_player_radius * (true and 0.328 or (_inv_phi * _inv_phi))), --- Trigger distance from center of player.
    PLAYER_FIRING_EDGE_RADIUS = 1.1 * math.ceil(_player_radius * (true and 0.328 or (_inv_phi * _inv_phi))), --- Trigger distance from center of player.
    PLAYER_RADIUS = _player_radius,
    PLAYER_TRAIL_THICKNESS = 1.2 * math.ceil(_player_radius * _inv_phi), -- HACK: 32 is player_radius global var in love.load (same size as dark of eye looks good)

    IS_CREATURE_FOLLOW_PLAYER = true,
    IS_CREATURE_FUSION_ENABLED = not true, --- FIXME: Assertion fails in `simulate.lua`
    IS_CREATURE_SWARM_ENABLED = not true,
    IS_GAME_SLOW = not true,
    IS_GRUG_BRAIN = not true, --- Whether to complicate life and the codebase.
    IS_PLAYER_INVULNERABLE = not true,
    IS_PLAYER_PROJECTILE_WRAP_AROUND_ARENA = not true, --- Flags if fired projectile should wrap around arena.

    PHI = _phi,
    INV_PHI = _inv_phi,
    PI = math.pi,
    TWO_PI = 2 * math.pi,
    INV_PI = 1 / math.pi,

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

    MAX_PARALLAX_ENTITIES = (2 ^ 4),
    PARALLAX_ENTITY_MAX_DEPTH = 4, --- @type integer
    PARALLAX_ENTITY_MIN_DEPTH = 1, --- @type integer
    PARALLAX_OFFSET_FACTOR_X = 0.0275 * _inv_phi, -- NOTE: Should be lower to avoid puking
    PARALLAX_OFFSET_FACTOR_Y = 0.0275 * _inv_phi,
}

do
    --- NOTE: Incresed this to make levels more challenging and not trivial
    M.CONSTANT_INITIAL_LARGE_CREATURES = (2 ^ 3) -- WARN: Any more than this, and levels above 50 lag
    do
        M.INITIAL_LARGE_CREATURES = (2 ^ 0) --- @type integer # This count excludes the initial ancestor count.
        M.EXPECTED_FINAL_HEALED_CREATURE_COUNT = ((M.INITIAL_LARGE_CREATURES ^ 2) - M.INITIAL_LARGE_CREATURES) --- @type integer # Double buffer size of possible creatures count i.e. `initial count ^ 2`
        M.TOTAL_CREATURES_CAPACITY = (2 * (M.INITIAL_LARGE_CREATURES ^ 2))
    end

    local is_skip_assert = true
    if not is_skip_assert then --
        assert((M.PLAYER_ACCELERATION / M.PLAYER_DEFAULT_TURN_SPEED <= 60), 'Expected <= 60. Actual: ' .. M.PLAYER_ACCELERATION)
    end
end

do
    local _creature_scale = 1
    local _speed_multiplier = 1.35

    --- @type Stage[] # Size decreases as stage progresses.
    M.CREATURE_STAGES = {
        {
            speed = (math.min(M.MAX_CREATURE_SPEED, math.floor(M.MIN_CREATURE_SPEED * (_phi ^ 3.8) * _speed_multiplier))),
            radius = (math.max(M.MIN_CREATURE_RADIUS, math.ceil(M.MAX_CREATURE_RADIUS * (_inv_phi ^ 5) * _creature_scale))),
        },
        {
            speed = math.floor(M.MIN_CREATURE_SPEED * (_phi ^ 2) * _speed_multiplier),
            radius = math.ceil(M.MAX_CREATURE_RADIUS * (_inv_phi ^ 3) * _creature_scale),
        },
        {
            speed = math.floor(M.MIN_CREATURE_SPEED * (_phi ^ 1) * _speed_multiplier),
            radius = math.ceil(M.MAX_CREATURE_RADIUS * (_inv_phi ^ 2) * _creature_scale),
        },
        {
            speed = math.floor(M.MIN_CREATURE_SPEED * (_phi ^ 0) * _speed_multiplier),
            radius = math.ceil(M.MAX_CREATURE_RADIUS * (_inv_phi ^ 0) * _creature_scale),
        },
    }
    do -- Test `creature_evolution_stages`.
        local max_creature_mutation_count = 0
        for i = 1, #M.CREATURE_STAGES do
            max_creature_mutation_count = max_creature_mutation_count + i
            local stage = M.CREATURE_STAGES[i]
            local speed = stage.speed
            local radius = stage.radius
            assert(speed > M.MIN_CREATURE_SPEED and speed <= M.MAX_CREATURE_SPEED)
            assert(radius >= M.MIN_CREATURE_RADIUS and radius <= M.MAX_CREATURE_RADIUS)
        end
        assert(max_creature_mutation_count == 10, 'Assert 1 creature (ancestor) »»mutates»» into ten creatures including itself.')
    end
end

return M

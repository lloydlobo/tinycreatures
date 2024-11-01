local M = {}

local Config = require 'config'

--- @enum STATUS
M.STATUS = {
    NOT_ACTIVE = 0,
    ACTIVE = 1,
}

-- curr_state.creatures_is_spawn[] ???

--- @enum HEALTH_TRANSITIONS
M.HEALTH_TRANSITIONS = {
    NONE = -1,
    HEALING = 0, --- Creature did spawn, and saved and now inactive but healing.
    HEALTHY = 1,
}

--- @enum CONTROL_KEY
M.CONTROL_KEY = {
    ESCAPE_KEY = 'escape',
    FIRE = 'space',
    FORCE_QUIT_GAME = 'q',
    NEXT_LEVEL = 'n',
    PREV_LEVEL = 'p',
    RESET_LEVEL = 'r',
    TOGGLE_HUD = 'h',
}

--- @enum PLAYER_ACTION
M.PLAYER_ACTION = {
    BESERK = 'BESERK',
    BOOST = 'BOOST',
    COMBO_BESERK_BOOST = 'COMBO_BESERK_BOOST',
    FIRE = 'FIRE',
    IDLE = 'IDLE',
}

--- @enum PLAYER_DAMAGE_STATUS
M.PLAYER_DAMAGE_STATUS = {
    DAMAGED = 'DAMAGED',
    DEAD = 'DEAD',
    INVULNERABLE = 'INVULNERABLE',
}

--- @enum SCREEN_FLASH_ALPHA_LEVEL
M.SCREEN_FLASH_ALPHA_LEVEL = {
    HIGH = 0.25, --- note: high level needs a fade out timer
    MEDIUM = 0.1,
    LOW = 0.045,
}

--- @enum CREATURE_STAGE_COLORS
--- Based on creature_evolution_stages `Stage[]` where the size decreases as stage progresses.
M.CREATURE_STAGE_COLORS = {
    { 0.75, 0.1, 0.3 },
    { 0.70, 0.2, 0.3 },
    { 0.70, 0.3, 0.4 },
    { 0.52, 0.45, 0.45 },
}

-- local ordia_blue = { 0.06, 0.16, 0.38 }

--- @enum COLOR
M.COLOR = {
    --{
    -- background = ({ { 0.005, 0.005, 0.005 }, { 0.4, 0.4, 0.4 }, { 0.75, 0.75, 0.75 } })[config.CURRENT_THEME], -- dark waters low_light ─ exposure: 0.0625, decay: 0.60
    -- creature_infected = ({ { 0.7, 0.5, 0.2 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[config.CURRENT_THEME], -- green low_light
    -- creature_healed = { 0.75, 0.75, 0.75 },
    --}

    --{
    -- GREENNNNN
    BACKGROUND = ({ { 0.06, 0.36, 0.30 }, { 0.4, 0.4, 0.4 }, { 0.75, 0.75, 0.75 } })[Config.CURRENT_THEME], -- exposure: 0.0625, decay: 0.60
    -- creature_healed = { 0.45, 0.52, 0.45 }, -- before impl gradient bg shader
    creature_healed = { 0.08, 0.08, 0.08, 0.2 }, -- after impl gradient bg shader
    -- creature_healed = { 0.8, 0.8, 0.8 },  -- after impl gradient bg shader
    creature_infected = ({ { 0.05, 0.02, 0.15 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[Config.CURRENT_THEME], -- green low_light

    -- BLUUEUUEUE
    -- background = ({ { 0.06, 0.36, 0.30 }, { 0.4, 0.4, 0.4 }, { 0.75, 0.75, 0.75 } })[config.CURRENT_THEME], -- exposure: 0.0625, decay: 0.60
    -- creature_healed = { 0.45, 0.45, 0.75 },
    -- creature_infected = ({ { 0.05, 0.02, 0.15 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[config.CURRENT_THEME], -- green low_light

    creature_healing = { 0.85, 0.3, 0.5 }, --- (pink)
    creature_infected_rgba = { 0.65, 0.1, 0.2, 0.5 },

    player_beserker_dash_modifier = { 0.9, 0.9, 0.4 }, --- ??? Chaos when shift + x are down. (yellow)
    player_beserker_modifier = { 135 / 255, 280 / 255, 138 / 255 }, --- buttercup Enhanced abilities, when either of shift key is pressed. (green)
    -- player_dash_neonblue_modifier = { 0.8, 0.8, 1.0 }, --- bubbles (luminiscent blue)
    player_dash_neonblue_modifier = { 0.85, 0.85, 0.95 }, --- bubbles (luminiscent blue)
    player_dash_pink_modifier = { 0.95, 0.4, 0.6 }, --- blossom The idle tail and projectile color. (purple)
    player_dash_yellow_modifier = { 0.9, 0.9, 0.4 }, --- You see, you're not dealing with the average player. (yellow)
    player_entity = ({ { 0.05 * 1, 0.05 * 1, 0.05 * 1 }, { 0.05 * 2, 0.05 * 2, 0.05 * 2 }, { 0.05 * 4, 0.05 * 4, 0.05 * 4 } })[Config.CURRENT_THEME],
    player_entity_firing_edge_dark = { 0.8, 0.8, 0.8 }, --- The "scanner|trigger|glint" of the eye ^_^. (offwhite)
    player_entity_firing_edge_darker = { 0.8, 0.8, 0.8 }, --- The lighter outer edge of the eye. (offwhite)
    player_entity_firing_projectile = { 125 / 255, 148 / 255, 290 / 255 }, --- The idle tail and projectile color. (purple)

    TEXT_DARKER = { 0.4, 0.4, 0.4 },
    TEXT_DARKEST = { 0.3, 0.3, 0.3 },
    TEXT_DEBUG_HUD = { 0.8, 0.7, 0.0 },
}

--- @type table<PLAYER_ACTION, [number, number, number]>
M.PLAYER_ACTION_COLOR_MAP = {
    [M.PLAYER_ACTION.COMBO_BESERK_BOOST] = M.COLOR.player_beserker_dash_modifier,
    [M.PLAYER_ACTION.BESERK] = M.COLOR.player_beserker_modifier,
    [M.PLAYER_ACTION.BOOST] = M.COLOR.player_dash_neonblue_modifier,
    [M.PLAYER_ACTION.FIRE] = M.COLOR.player_entity_firing_projectile,
    [M.PLAYER_ACTION.IDLE] = M.COLOR.player_entity,
}

--- Desaturate an RGB color by averaging it with grayscale.
--- @param color [number, number, number]  The original RGB color.
--- @return [number, number, number] The desaturated RGB color.
function M.desaturate(color)
    local gray = (color[1] + color[2] + color[3]) / 3
    return {
        (color[1] + gray) / 2,
        (color[2] + gray) / 2,
        (color[3] + gray) / 2,
    }
end

--- @type table<PLAYER_ACTION, [number, number, number]>
M.PLAYER_ACTION_DESATURATED_COLOR_MAP = {
    [M.PLAYER_ACTION.COMBO_BESERK_BOOST] = M.desaturate(M.COLOR.player_beserker_dash_modifier),
    [M.PLAYER_ACTION.BESERK] = M.desaturate(M.COLOR.player_beserker_modifier),
    [M.PLAYER_ACTION.BOOST] = M.desaturate(M.COLOR.player_dash_neonblue_modifier),
    [M.PLAYER_ACTION.FIRE] = M.desaturate(M.COLOR.player_entity_firing_projectile),
    [M.PLAYER_ACTION.IDLE] = M.desaturate(M.COLOR.player_entity),
}

-- --- @type table<PLAYER_ACTION, [number, number, number]>
-- M.PLAYER_ACTION_COLOR_MAP_DESATURATED = {
--     [M.PLAYER_ACTION.COMBO_BESERK_BOOST] = M.COLOR.player_beserker_dash_modifier,
--     [M.PLAYER_ACTION.BESERK] = M.COLOR.player_beserker_modifier,
--     [M.PLAYER_ACTION.BOOST] = M.COLOR.player_dash_neonblue_modifier,
--     [M.PLAYER_ACTION.FIRE] = M.COLOR.player_entity_firing_projectile,
--     [M.PLAYER_ACTION.IDLE] = M.COLOR.player_entity,
-- }

-- --- @type fun(a: number, b: number, t: number): number
-- function M.lerp(a, b, t)
--     if not (a ~= nil and b ~= nil and t ~= nil) then
--         error(string.format('Invalid lerp arguments { a = "%s", b = "%s", c = "%s" }.', a, b, t), 3)
--     end

--     return ((1 - t) * a) + (t * b)
-- end

--- @alias LoveRGB { [1]: number, [2]: number, [3]: number }

--- Interpolate two color sources into destination color.
--- @param dst LoveRGB
--- @param src1 LoveRGB
--- @param src2 LoveRGB
--- @param t number # 0.0..1.0
function M.lerp_rbg(dst, src1, src2, t)
    dst[1] = M.lerp(src1[1], src2[1], t)
    dst[2] = M.lerp(src1[2], src2[2], t)
    dst[3] = M.lerp(src1[3], src2[3], t)
end

--- @type fun(t: { x1: number, y1: number, x2: number, y2: number }): number
function M.manhattan_distance(t) return math.abs(t.x1 - t.x2) + math.abs(t.y1 - t.y2) end

function M.sign(x) return (x >= 0 and 1) or -1 end

--- See http://lua-users.org/wiki/SimpleRound
-- function M.round(x) return math.floor((math.floor(x * 2) + 1) * .5) end
function M.round(x, bracket)
    bracket = bracket or 1
    return math.floor(x / bracket + M.sign(x) * 0.5) * bracket
end

--- WARN: This is not accurate!!!
function M.approx(a, b, tolerance)
    local diff = math.abs(a - b)
    if tolerance ~= nil then
        diff = tonumber(tostring(diff))
        return diff >= tolerance
    else
        return math.floor(diff) == 0 or math.ceil(diff) == 0
    end
end

do
    assert(M.approx(1.234, 1.230, 0.004))
    assert(not M.approx(1.234, 1.230, 0.005))
end

--- See http://lua-users.org/wiki/SimpleRound
do
    local actual = M.round(119.68, 6.4) -- 121.6 (= 19 * 6.4)
    local expected = 121.6
    assert(tostring(actual) == tostring(expected), 'actual: ' .. tostring(actual) .. ': expected: ' .. tostring(expected)) -- FIXME: Fails without string cmp
end

--- @alias LerpFn fun(a: number, b: number, t: number):number

--- Linear interpolation between `a` and `b` using parameter `t`.
--- @type LerpFn
function M.lerp(a, b, t)
    if Config.debug.is_assert then
        if not (a ~= nil and b ~= nil and t ~= nil) then error(string.format('Invalid lerp arguments { a = "%s", b = "%s", c = "%s" }.', a, b, t), 3) end
    end

    return (1 - t) * a + t * b
end

-- Types of common interpolation:
--   lerp()
--   normalize(lerp()) -- good for shaders, if angle is small, else learn `slerp`
--   slerp() -- interpolates across unit vector in sphere
--- spherical linear interpolation
function M.slerp() end

---
--- Different types of interpolation that extends `lerp`.
---
---
--- @alias LerpMode
---
--- Linear interpolation (t).
---
--- | "linear"
---
--- Squared interpolation (t²).
---
--- | "square"
---
--- Square Root interpolation (√t).
---
--- | "sqrt"
---
--- Cubic interpolation (t³).
---
--- | "cube"
---
--- Logarithmic interpolation (exp(lerp(log(a), log(b), t))).
---
--- | "log"
---
--- Smoothstep interpolation (3t² - 2t³).
---
--- | "smoothstep" # Shapes the curve such that eases in and eases out, avoiding abrupt changes at the boundaries. A smooth transition that starts and ends slowly, unlike the constant rate of lerp. Use for smoother animations or transitions─where we want to avoid sudden starts or stops.

--- See also https://easings.net/
--- @type table<LerpMode, LerpFn>
M.lerper = {
    cube = function(a, b, t) return (1 - (t * t * t)) * a + (t * t * t) * b end,
    linear = function(a, b, t) return (1 - t) * a + t * b end,
    log = function(a, b, t) return math.exp((1 - t) * math.log(a) + t * math.log(b)) end,
    smoothstep = function(a, b, t)
        local smooth_t = 3 * (t * t) - 2 * (t * t * t)
        return (1 - smooth_t) * a + smooth_t * b
    end,
    sqrt = function(a, b, t)
        local t_ = math.sqrt(t)
        return (1 - t_) * a + t_ * b
    end,
    square = function(a, b, t) return (1 - (t * t)) * a + (t * t) * b end,
}
do
    assert(M.lerper['linear'](0, 10, 0.5) == 5)
    assert(M.lerper['square'](0, 10, 0.5) == 2.5)
    assert(M.approx(M.lerper['sqrt'](0, 10, 0.25), 5))
    assert(M.approx(M.lerper['sqrt'](0, 10, 0.5), 7.37))
    assert(M.approx(M.lerper['sqrt'](0, 10, 0.75), 8.66))
    assert(M.lerper['cube'](0, 10, 0.5) == 1.25)
    assert(M.approx(M.lerper['cube'](0, 10, 0.75), 4.21))
    assert(M.round(M.lerper['log'](1, 10, 0.5), 0.2) == 3.2)
    assert(M.approx(M.lerper['log'](1, 10, 0.75), 5.62))
    assert(M.lerper['smoothstep'](1, 10, 0.5) == 5.5)
    assert(M.lerper['smoothstep'](1, 10, 0.25) == 2.40625)
    assert(M.lerper['smoothstep'](1, 10, 0.75) == 8.59375)
end

return M

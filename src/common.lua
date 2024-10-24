local M = {}

local config = require 'config'

--- @enum Status
M.Status = {
        not_active = 0,
        active = 1,
}

-- curr_state.creatures_is_spawn[] ???

--- @enum HealthTransitions
M.HealthTransitions = {
        none = -1,
        healing = 0, --- Creature did spawn, and saved and now inactive but healing.
        healthy = 1,
}

--- @enum ControlKey
M.ControlKey = {
        escape_key = 'escape',
        fire = 'space',
        force_quit_game = 'q',
        next_level = 'n',
        prev_level = 'p',
        reset_level = 'r',
        toggle_hud = 'h',
}

--- @enum CreatureStageColor
--- Based on creature_evolution_stages `Stage[]` where the size decreases as
--- stage progresses.
M.CreatureStageColor = { { 0.75, 0.1, 0.3 }, { 0.70, 0.2, 0.3 }, { 0.70, 0.3, 0.4 }, { 0.52, 0.45, 0.45 } }

local ordia_blue = { 0.06, 0.16, 0.38 }
--- @enum Color
M.Color = {
        --{
        -- background = ({ { 0.005, 0.005, 0.005 }, { 0.4, 0.4, 0.4 }, { 0.75, 0.75, 0.75 } })[config.CURRENT_THEME], -- dark waters low_light ─ exposure: 0.0625, decay: 0.60
        -- creature_infected = ({ { 0.7, 0.5, 0.2 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[config.CURRENT_THEME], -- green low_light
        -- creature_healed = { 0.75, 0.75, 0.75 },
        --}

        --{
        background = ({ { 0.06, 0.16, 0.30 }, { 0.4, 0.4, 0.4 }, { 0.75, 0.75, 0.75 } })[config.CURRENT_THEME], -- exposure: 0.0625, decay: 0.60
        -- background = ({ { 0.06, 0.16, 0.38 }, { 0.4, 0.4, 0.4 }, { 0.75, 0.75, 0.75 } })[config.CURRENT_THEME], -- exposure: 0.0625, decay: 0.60
        -- creature_infected = ({ { 0.05, 0.09, 0.23 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[config.CURRENT_THEME], -- green low_light
        creature_infected = ({ { 0.05, 0.02, 0.15 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[config.CURRENT_THEME], -- green low_light
        creature_healed = { 0.45, 0.45, 0.75 },
        --}

        -- creature_infected = ({ { 0.25, 0.9, 0.6 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[config.CURRENT_THEME], -- green low_light
        -- creature_infected = (({ { 0.76, 0.05, 0.25 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[config.CURRENT_THEME]), -- red low_light

        -- creature_infected = (({ { 0.25, 0.9, 0.6 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[config.CURRENT_THEME]), -- green low_light
        -- creature_infected = (({ { 0.46, 0.16, 0.19 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[config.CURRENT_THEME]), -- magenta low_light
        -- creature_infected = (({ { 0.65, 1.00, 0.60 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[config.CURRENT_THEME]), -- beserk low_light
        -- creature_infected = (({ { 0.86, 0.40, 0.55 }, { 0.25 + 0.1, 0.9 + 0.1, 0.6 + 0.2 }, { 0.05, 0.05, 0.05 } })[config.CURRENT_THEME]), -- red low_light
        -- creature_infected = { 0.2, 0.9, 0.6 }, -- green (works with all themes)
        -- creature_infected = { 0.75, 0.1, 0.3 },

        -- background = { 0.4, 0.4, 0.4 },-- exposure: 0.0625, decay: 0.60
        -- background = { 0.75, 0.75, 0.75 }, -- exposure: 0.325, decay: 0.75
        -- background = { 0.9, 0.9, 0.9 }, -- exposure: 0.325, decay: 0.75
        -- creature_healed = { 0.85, 0.85, 0.85 },
        -- creature_healing = { 0.95, 0.4, 0.6 }, --- (pink)
        -- creature_infected_rgba = { 0.75, 0.1, 0.3, 0.5 },
        -- player_beserker_modifier = { 0.9, 0.9, 0.4 },                          --- Enhanced abilities, when either of shift key is pressed.
        -- player_entity = { 0.3, 0.3, 0.3 }, --- The dark backdrop (galaxy like) of the eye. (charcoal)
        -- player_entity_firing_projectile = { 155 / 255, 190 / 255, 128 / 255 }, -- green mint
        -- player_entity_firing_projectile = { 230 / 255, 230 / 255, 250 / 255 }, -- lavender
        creature_healing = { 0.85, 0.3, 0.5 }, --- (pink)
        creature_infected_rgba = { 0.65, 0.1, 0.2, 0.5 },
        player_beserker_dash_modifier = { 0.9, 0.9, 0.4 }, --- ??? Chaos when shift + x are down. (yellow)
        player_beserker_modifier = { 155 / 255, 190 / 255, 128 / 255 }, --- buttercup Enhanced abilities, when either of shift key is pressed. (green)
        player_dash_neonblue_modifier = { 0.7, 0.7, 1.0 }, --- bubbles (luminiscent blue)
        player_dash_pink_modifier = { 0.95, 0.4, 0.6 }, --- blossom The idle tail and projectile color. (purple)
        player_dash_yellow_modifier = { 0.9, 0.9, 0.4 }, --- You see, you're not dealing with the average player. (yellow)
        player_entity = ({
                { 0.05 * 1, 0.05 * 1, 0.05 * 1 },
                { 0.05 * 2, 0.05 * 2, 0.05 * 2 },
                { 0.05 * 4, 0.05 * 4, 0.05 * 4 },
        })[config.CURRENT_THEME],
        player_entity_firing_edge_dark = { 0.8, 0.8, 0.8 }, --- The "scanner|trigger|glint" of the eye ^_^. (offwhite)
        player_entity_firing_edge_darker = { 0.8, 0.8, 0.8 }, --- The lighter outer edge of the eye. (offwhite)
        player_entity_firing_projectile = { 155 / 255, 128 / 255, 190 / 255 }, --- The idle tail and projectile color. (purple)
        text_darker = { 0.4, 0.4, 0.4 },
        text_darkest = { 0.3, 0.3, 0.3 },
        text_debug_hud = { 0.8, 0.7, 0.0 },
}

--- @enum ScreenFlashAlphaLevel
M.ScreenFlashAlphaLevel = {
        high = 0.25, --- note: high level needs a fade out timer
        medium = 0.1,
        low = 0.045,
}

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

--- @alias M.LerpFn fun(a: number, b: number, t: number):number

--- Linear interpolation between `a` and `b` using parameter `t`.
--- @type M.LerpFn
function M.lerp(a, b, t)
        if config.debug.is_assert then
                if not (a ~= nil and b ~= nil and t ~= nil) then
                        error(string.format('Invalid lerp arguments { a = "%s", b = "%s", c = "%s" }.', a, b, t), 3)
                end
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
--- @alias M.LerpMode
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
--- @type table<M.LerpMode, M.LerpFn>
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

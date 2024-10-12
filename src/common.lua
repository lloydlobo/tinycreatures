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
M.CreatureStageColor = {
    { 0.75, 0.1, 0.3 },
    { 0.70, 0.2, 0.3 },
    { 0.70, 0.3, 0.4 },
    { 0.52, 0.45, 0.45 },
}

--- @enum Color
M.Color = {
    --player_beserker_modifier = { 0.9, 0.9, 0.4 },                          --- Enhanced abilities, when either of shift key is pressed.
    --player_entity_firing_projectile = { 155 / 255, 190 / 255, 128 / 255 }, -- green mint
    --player_entity_firing_projectile = { 230 / 255, 230 / 255, 250 / 255 }, -- lavender
    background = ({ { 0.05, 0.05, 0.05 }, { 0.4, 0.4, 0.4 }, { 0.75, 0.75, 0.75 }})[config.CURRENT_THEME], -- exposure: 0.0625, decay: 0.60
    -- background = { 0.4, 0.4, 0.4 },-- exposure: 0.0625, decay: 0.60
    -- background = { 0.75, 0.75, 0.75 }, -- exposure: 0.325, decay: 0.75
    -- background = { 0.9, 0.9, 0.9 }, -- exposure: 0.325, decay: 0.75

    -- creature_healed = { 0.85, 0.85, 0.85 },
    -- creature_healing = { 0.95, 0.4, 0.6 }, --- (pink)
    -- creature_infected = { 0.75, 0.1, 0.3 },
    -- creature_infected_rgba = { 0.75, 0.1, 0.3, 0.5 },
    creature_healed = { 0.75, 0.75, 0.75 },
    creature_healing = { 0.85, 0.3, 0.5 }, --- (pink)
    creature_infected = { 0.2, 0.9, 0.6 },
    creature_infected_rgba = { 0.65, 0.1, 0.2, 0.5 },

    player_beserker_dash_modifier = { 0.9, 0.9, 0.4 }, --- ??? Chaos when shift + x are down. (yellow)
    player_beserker_modifier = { 155 / 255, 190 / 255, 128 / 255 }, --- buttercup Enhanced abilities, when either of shift key is pressed. (green)
    player_dash_pink_modifier = { 0.95, 0.4, 0.6 }, --- blossom The idle tail and projectile color. (purple)
    player_dash_yellow_modifier = { 0.9, 0.9, 0.4 }, --- You see, you're not dealing with the average player. (yellow)
    player_dash_neonblue_modifier = { 0.7, 0.7, 1.0 }, --- bubbles (luminiscent blue)
    player_entity = { 0.3, 0.3, 0.3 }, --- The dark backdrop (galaxy like) of the eye. (charcoal)
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

--- @type fun(a: number, b: number, t: number): number
function M.lerp(a, b, t)
    if not (a ~= nil and b ~= nil and t ~= nil) then
        error(string.format('Invalid lerp arguments { a = "%s", b = "%s", c = "%s" }.', a, b, t), 3)
    end

    return ((1 - t) * a) + (t * b)
end

--- @alias LoveRGB { [1]: number, [2]: number, [3]: number }

---Interpolate two color sources into destination color.
---@param dst LoveRGB
---@param src1 LoveRGB
---@param src2 LoveRGB
---@param t number # 0.0..1.0
function M.lerp_rbg(dst, src1, src2, t)
    dst[1] = M.lerp(src1[1], src2[1], t)
    dst[2] = M.lerp(src1[2], src2[2], t)
    dst[3] = M.lerp(src1[3], src2[3], t)
end

--- @type fun(t: { x1: number, y1: number, x2: number, y2: number }): number
function M.manhattan_distance(t)
    return math.abs(t.x1 - t.x2) + math.abs(t.y1 - t.y2)
end

return M

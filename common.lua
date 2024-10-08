local M = {}

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
    { 0.75, 0.1,  0.3 },
    { 0.70, 0.2,  0.3 },
    { 0.70, 0.3,  0.4 },
    { 0.52, 0.45, 0.45 },
}
--- @enum Color
M.Color = {
    --background = { 0.8, 0.8, 0.8 },
    background = { 0.9, 0.9, 0.9 },
    creature_healed = { 0.85, 0.85, 0.85 },
    creature_healing = { 0.95, 0.4, 0.6 },
    creature_infected = { 0.75, 0.1, 0.3 },
    creature_infected_rgba = { 0.75, 0.1, 0.3, 0.5 },
    player_entity = { 0.3, 0.3, 0.3 },
    player_entity_firing_edge_dark = { 0.8, 0.8, 0.8 },
    player_entity_firing_edge_darker = { 0.7, 0.7, 0.7 },
    --player_entity_firing_projectile = { 230 / 255, 230 / 255, 250 / 255 }, -- lavender
    --player_entity_firing_projectile = { 155 / 255, 128 / 255, 190 / 255 }, -- purple
    player_entity_firing_projectile = { 155 / 255, 190 / 255, 128 / 255 }, -- purple
    text_darker = { 0.4, 0.4, 0.4 },
    text_darkest = { 0.3, 0.3, 0.3 },
    text_debug_hud = { 0.8, 0.7, 0.0 },
}

--- @enum ScreenFlashAlphaLevel
M.ScreenFlashAlphaLevel = {
    high = .25, --- note: high level needs a fade out timer
    medium = .1,
    low = .045,
}


--- @type fun(a: number, b: number, t: number): number
function M.lerp(a, b, t)
    if not (a ~= nil and b ~= nil and t ~= nil) then
        error(string.format('Invalid lerp arguments { a = "%s", b = "%s", c = "%s" }.', a, b, t), 3)
    end

    return ((1 - t) * a) + (t * b)
end

--- @type fun(t: { x1: number, y1: number, x2: number, y2: number }): number
function M.manhattan_distance(t)
    return math.abs(t.x1 - t.x2) + math.abs(t.y1 - t.y2)
end

return M

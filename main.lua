---@diagnostic disable: lowercase-global, undefined-global, duplicate-set-field

--- Ported initially from https://berbasoft.com/simplegametutorials/love/asteroids/

local moonshine = require 'lib.moonshine'

local LG = love.graphics

--- @class GameState
--- @field creatures_vel_x number[]
--- @field creatures_vel_y number[]
--- @field creatures_angle number[]
--- @field creatures_evolution_stage integer[]
--- @field creatures_is_active Status[]
--- @field creatures_health integer[]
--- @field creatures_x number[]
--- @field creatures_y number[]
--- @field player_rot_angle number # 0
--- @field player_vel_x number # 0
--- @field player_vel_y number # 0
--- @field player_x number # 0|400
--- @field player_y number # 0|300
--- @field lasers_angle number[]
--- @field lasers_is_active Status[]
--- @field lasers_time_left number[]
--- @field lasers_x number[]
--- @field lasers_y number[]

--- @class Shader
--- @field post_processing table

--- @class Stage
--- @field speed number
--- @field radius integer

--- @class Circle
--- @field x number
--- @field y number
--- @field radius number

--- @class ScreenShake
--- @field amount number # 0
--- @field duration number # 0
--- @field offset_x number # 0
--- @field offset_y number # 0
--- @field wait number # 0
--- See also: https://sheepolution.com/learn/book/22

--- @enum Status
local Status = {
    not_active = 0,
    active = 1,
}

-- curr_state.creatures_is_spawn[] ???

local Health = {
    none = -1,
    healing = 0, --- Creature did spawn, and saved and now inactive but healing.
    healthy = 1,
}

--- @enum ControlKey
local ControlKey = {
    escape_key = 'escape_key',
    force_quit_game = 'q',
    toggle_hud = 'h',
}

--- @enum Color
local Color = {
    background = { 0.8, 0.8, 0.8 },
    creature_healed = { 0.85, 0.85, 0.85 },
    creature_healing = { 0.95, 0.4, 0.6 },
    creature_infected = { 0.75, 0.1, 0.3 },
    creature_infected_rgba = { 0.75, 0.1, 0.3, 0.5 },
    player_entity = { 0.3, 0.3, 0.3 },
    player_entity_firing_edge_dark = { 0.7, 0.7, 0.7 },
    player_entity_firing_edge_darker = { 0.6, 0.6, 0.6 },
    player_entity_firing_projectile = { 0.5, 0.5, 0.5 },
    text_darker = { 0.4, 0.4, 0.4 },
    text_darkest = { 0.3, 0.3, 0.3 },
    text_debug_hud = { 0.8, 0.7, 0.0 },
}

local AIR_RESISTANCE = 0.98 -- Resistance factor between 0 and 1.
local FIXED_FPS = 60

local IS_GRUG_BRAIN = false --- Whether to complicate life and the codebase.
local IS_PLAYER_PROJECTILE_WRAP_AROUND_ARENA = false --- Flags if fired projectile should wrap around arena.

local LASER_FIRE_TIMER_LIMIT = 0.5 * 0.2
local LASER_PROJECTILE_SPEED = 500
local MAX_LASER_CAPACITY = 256

local PHI = 1.618
local PHI_INV = 0.618
local PI = math.pi
local PI_INV = 1 / math.pi

local PLAYER_ACCELERATION = 100
PLAYER_ACCELERATION = PLAYER_ACCELERATION * 2

local PLAYER_CIRCLE_IRIS_TO_EYE_RATIO = 0.618
local PLAYER_FIRE_COOLDOWN_TIMER_LIMIT = 6 --- Note: 6 is rough guess, but intend for alpha lifecycle from 0.0 to 1.0.
local DEFAULT_PLAYER_TURN_SPEED = 10 * 0.5 - 1

local INITIAL_LARGE_CREATURES = 3
--- HACK: Settling for a lower value, to avoid dealing with individual counters
--- to animate healing. Due to increase of inactive healed creatures in arena.
local MAX_CREATURES_IN_ARENA = 64 --- Allocated size is always less than capacity by ((power/multiple) of 2 or some constant).
local TOTAL_CREATURES_CAPACITY = 128 --- Allocated capacity.
local MAX_HEALED_BUT_INACTIVE_CREATURES = 5

local FIXED_DT = 1 / FIXED_FPS --- Ensures consistent game logic updates regardless of frame rate fluctuations.
local FIXED_DT_INV = 1 / (1 / FIXED_FPS) --- avoid dividing each frame

--
-- Variables
--

local dt_accum = 0.0 --- Accumulator keeps track of time passed between frames.

local debug = { --- Debugging Flags.
    is_development = true,
    is_test = true,
    is_trace_entities = true,
}

--- @type fun(a: number, b: number, t: number): number
function lerp(a, b, t)
    if not (a ~= nil and b ~= nil and t ~= nil) then
        error(string.format('Invalid lerp arguments { a = "%s", b = "%s", c = "%s" }.', a, b, t), 3)
    end

    return ((1 - t) * a) + (t * b)
end

function assert_consistent_state()
    local cs = curr_state
    local ps = prev_state

    assert(#ps.creatures_angle == #cs.creatures_angle)
    assert(#ps.creatures_is_active == #cs.creatures_is_active)
    assert(#ps.creatures_health == #cs.creatures_health)
    assert(#ps.creatures_evolution_stage == #cs.creatures_evolution_stage)
    assert(#ps.creatures_x == #cs.creatures_x)
    assert(#ps.creatures_y == #cs.creatures_y)
    assert(#ps.lasers_angle == #cs.lasers_angle)
    assert(#ps.lasers_is_active == #cs.lasers_is_active)
    assert(#ps.lasers_time_left == #cs.lasers_time_left)
    assert(#ps.lasers_x == #cs.lasers_x)
    assert(#ps.lasers_y == #cs.lasers_y)

    assert(#cs.lasers_x == MAX_LASER_CAPACITY)
end

function sync_prev_state()
    local cs = curr_state
    local ps = prev_state

    ps.player_rot_angle = cs.player_rot_angle
    ps.player_vel_x = cs.player_vel_x
    ps.player_vel_y = cs.player_vel_y
    ps.player_x = cs.player_x
    ps.player_y = cs.player_y

    for i = 1, #cs.lasers_x do
        ps.lasers_angle[i] = cs.lasers_angle[i]
        ps.lasers_is_active[i] = cs.lasers_is_active[i]
        ps.lasers_time_left[i] = cs.lasers_time_left[i]
        ps.lasers_x[i] = cs.lasers_x[i]
        ps.lasers_y[i] = cs.lasers_y[i]
    end

    for i = 1, #cs.creatures_x do
        ps.creatures_angle[i] = cs.creatures_angle[i]
        ps.creatures_evolution_stage[i] = cs.creatures_evolution_stage[i]
        ps.creatures_health[i] = cs.creatures_health[i]
        ps.creatures_is_active[i] = cs.creatures_is_active[i]
        ps.creatures_vel_x[i] = cs.creatures_vel_x[i]
        ps.creatures_vel_y[i] = cs.creatures_vel_y[i]
        ps.creatures_x[i] = cs.creatures_x[i]
        ps.creatures_y[i] = cs.creatures_y[i]
    end
end

--- @type fun(dst: GameState, src: GameState)
function copy_game_state(dst, src)
    for key, value in pairs(src) do
        if type(value) == 'table' then
            dst[key] = {}
            for i = 1, #value do
                dst[key][i] = value[i]
            end
        else
            dst[key] = value
        end
    end
end

function love.load()
    LG.setDefaultFilter('linear', 'linear') -- smooth edges

    arena_w = gw
    arena_h = gh

    -- TODO
    do
        local pointing_laser_scope_length = math.min(arena_w / 2, arena_h / 2)
        -- print(pointing_laser_scope_length)
    end

    player_radius = 32

    --
    -- FIXME: swarm range --- should be evolution_stage.radius specific
    --
    creature_swarm_range = player_radius * 4

    laser_radius = 5

    -- active_creatures = 0
    player_firing_edge_max_radius = math.ceil(player_radius * 0.328) --- Trigger distance from center of player.

    local fx = moonshine.effects

    shaders = { --- @type Shader
        post_processing = moonshine(arena_w, arena_h, fx.colorgradesimple)
            .chain(fx.chromasep)
            -- .chain(fx.crt)
            .chain(fx.scanlines)
            .chain(fx.vignette)
            .chain(fx.godsray),
    }
    if true then
        local is_default = false
        shaders.post_processing.godsray.exposure = is_default and 0.25 or 0.05
        shaders.post_processing.godsray.decay = is_default and 0.95 or 0.95
        shaders.post_processing.godsray.density = is_default and 0.15 or 0.15
        shaders.post_processing.godsray.weight = is_default and 0.50 or 0.90
        shaders.post_processing.godsray.light_position = is_default and { 0.5, 0.5 } or { 0.125, 0.125 }
        shaders.post_processing.godsray.samples = is_default and 70 or 8
    end
    if true then
        shaders.post_processing.vignette.radius = 0.8 + 0.4
        shaders.post_processing.vignette.softness = 0.5 + 0.2
        shaders.post_processing.vignette.opacity = 0.5 + 0.1
        shaders.post_processing.vignette.color = Color.background
    end

    if true then
        shaders.post_processing.scanlines.opacity = 1 * 0.618
        shaders.post_processing.scanlines.thickness = 1 * 0.5 * 0.0618
        shaders.post_processing.scanlines.width = 2
    end

    -- can put a fadeout timer for infected -> healed creatures as achievement with color change
    prev_state = { --- @type GameState
        creatures_angle = {},
        creatures_evolution_stage = {},
        creatures_health = {},
        creatures_is_active = {},
        creatures_vel_x = {},
        creatures_vel_y = {},
        creatures_x = {},
        creatures_y = {},
        lasers_angle = {},
        lasers_is_active = {},
        lasers_time_left = {},
        lasers_x = {},
        lasers_y = {},
        player_rot_angle = 0,
        player_vel_x = 0,
        player_vel_y = 0,
        player_x = 0,
        player_y = 0,
    }

    curr_state = { --- @type GameState
        creatures_angle = {},
        creatures_evolution_stage = {},
        creatures_health = {},
        creatures_is_active = {},
        creatures_vel_x = {},
        creatures_vel_y = {},
        creatures_x = {},
        creatures_y = {},
        lasers_angle = {},
        lasers_is_active = {},
        lasers_time_left = {},
        lasers_x = {},
        lasers_y = {},
        player_rot_angle = 0,
        player_vel_x = 0,
        player_vel_y = 0,
        player_x = 0,
        player_y = 0,
    }

    screenshake = { --- @type ScreenShake
        amount = 5 * 0.5 * 0.618,
        duration = 0.0,
        offset_x = 0.0,
        offset_y = 0.0,
        wait = 0.0,
    }

    do
        local creature_scale = 1
        local speed_multiplier = 1
        creature_evolution_stages = { ---@type Stage[] # Size decreases as stage progresses.
            { speed = 100 * speed_multiplier, radius = math.ceil(15 * creature_scale) },
            { speed = 70 * speed_multiplier, radius = math.ceil(30 * creature_scale) },
            { speed = 50 * speed_multiplier, radius = math.ceil(50 * creature_scale) },
            { speed = 20 * speed_multiplier, radius = math.ceil(80 * creature_scale) },
        }
        do -- @unimplemented
            creature_stages_index = #creature_evolution_stages -- start from the last item
        end
        max_creature_mutation_count = 0
        for i = 1, #creature_evolution_stages do
            max_creature_mutation_count = max_creature_mutation_count + i
        end
        assert(max_creature_mutation_count == 10)
    end

    function reset_game()
        game_timer_t = 0.0
        game_timer_dt = 0.0
        player_fire_cooldown_timer = 0
        laser_fire_timer = 0
        laser_index = 1 -- circular buffer index
        is_debug_hud_enabled = false --- Toggled by keys event.
        player_turn_speed = DEFAULT_PLAYER_TURN_SPEED

        curr_state.player_rot_angle = 0
        curr_state.player_vel_x = 0
        curr_state.player_vel_y = 0
        curr_state.player_x = arena_w * 0.5
        curr_state.player_y = arena_h * 0.5
        prev_state.player_rot_angle = 0
        prev_state.player_vel_x = 0
        prev_state.player_vel_y = 0
        prev_state.player_x = arena_w * 0.5
        prev_state.player_y = arena_h * 0.5

        for i = 1, MAX_LASER_CAPACITY do
            curr_state.lasers_angle[i] = 0
            curr_state.lasers_is_active[i] = Status.not_active
            curr_state.lasers_time_left[i] = LASER_FIRE_TIMER_LIMIT
            curr_state.lasers_x[i] = 0
            curr_state.lasers_y[i] = 0
        end
        -- laser_fire_timer = 0
        laser_index = 1 -- reset circular buffer index

        -- Test me:
        -- curr_state.creatures_x = { 100, arena_w - 100, arena_w / 2 }
        -- curr_state.creatures_y = { 100, 100, arena_h - 10 }

        local largest_creature_stage = #creature_evolution_stages
        for i = 1, TOTAL_CREATURES_CAPACITY do -- Pre-allocate all creature's including stage combinations
            curr_state.creatures_angle[i] = 0
            curr_state.creatures_evolution_stage[i] = largest_creature_stage
            curr_state.creatures_health[i] = 0 -- default 0 value
            curr_state.creatures_is_active[i] = Status.not_active
            curr_state.creatures_x[i] = 0
            curr_state.creatures_y[i] = 0
            curr_state.creatures_vel_x[i] = 0
            curr_state.creatures_vel_y[i] = 0
        end

        for i = 1, INITIAL_LARGE_CREATURES do -- Activate initial creatures.
            curr_state.creatures_angle[i] = love.math.random() * (2 * math.pi)
            curr_state.creatures_evolution_stage[i] = largest_creature_stage -- Start at smallest stage
            curr_state.creatures_health[i] = -1 -- -1 to 0 to 1.... like dash timer, or fade timer ( -1 to 0 to 1 )
            curr_state.creatures_is_active[i] = Status.active
            curr_state.creatures_vel_x[i] = 0
            curr_state.creatures_vel_y[i] = 0
            curr_state.creatures_x[i] = 0
            curr_state.creatures_y[i] = 0
        end

        copy_game_state(prev_state, curr_state)
        sync_prev_state()
        if debug.is_test then
            assert_consistent_state()
        end
    end

    reset_game()
    LG.setBackgroundColor(Color.background)
end

function love.keypressed(key, _, _)
    if key == ControlKey.escape_key or key == ControlKey.force_quit_game then
        love.event.push 'quit'
    elseif key == ControlKey.toggle_hud then
        is_debug_hud_enabled = not is_debug_hud_enabled
    end
end

function love.update(dt)
    game_timer_t = game_timer_t + dt
    game_timer_dt = dt -- note: for easy global reference

    --#region Frame Rate Independence.
    dt_accum = dt_accum + dt
    while dt_accum >= FIXED_DT do
        sync_prev_state()
        update_game(FIXED_DT)
        dt_accum = dt_accum - FIXED_DT
    end
    --#endregion

    update_screenshake(dt)
end

--- @param dt number # Actual delta time. Not same as `fixed_dt`.
function update_screenshake(dt)
    local ss = screenshake
    if ss.duration > 0 then
        ss.duration = ss.duration - dt
        if ss.wait <= 0 then
            ss.offset_x = love.math.random(-ss.amount, ss.amount)
            ss.offset_y = love.math.random(-ss.amount, ss.amount)
            ss.wait = 0.05 -- load up default timer countdown
        else -- prevent fast screenshakes
            ss.wait = ss.wait - dt
        end
    end
end

--- @type fun(pair: { a: Circle, b: Circle }): boolean
local function is_intersect_circles(ab)
    local dx = (ab.a.x - ab.b.x)
    local dy = (ab.a.y - ab.b.y)
    local ab_dist = ab.a.radius + ab.b.radius

    return (dx * dx + dy * dy <= ab_dist * ab_dist)
end

function fire_player_projectile() --- Fire projectile from players's position.
    if laser_fire_timer <= 0 then
        local cs = curr_state
        cs.lasers_angle[laser_index] = cs.player_rot_angle
        cs.lasers_is_active[laser_index] = Status.active
        cs.lasers_time_left[laser_index] = 4
        cs.lasers_x[laser_index] = cs.player_x + math.cos(cs.player_rot_angle) * player_radius
        cs.lasers_y[laser_index] = cs.player_y + math.sin(cs.player_rot_angle) * player_radius
        laser_index = (laser_index % MAX_LASER_CAPACITY) + 1 -- Laser_index tracks circular reusable buffer.
        laser_fire_timer = LASER_FIRE_TIMER_LIMIT -- Reset timer to default.
    end
end

function dash_player_entity(dt)
    local dash_multiplier = PHI

    local cs = curr_state
    local prev_vel_x = cs.player_vel_x
    local prev_vel_y = cs.player_vel_y
    cs.player_vel_x = cs.player_vel_x * dash_multiplier
    cs.player_vel_y = cs.player_vel_y * dash_multiplier

    update_player_entity(dt) -- remember to update once

    cs.player_vel_x = prev_vel_x
    cs.player_vel_y = prev_vel_y
end

function handle_player_input(dt)
    local cs = curr_state

    if love.keyboard.isDown('right', 'd') then
        cs.player_rot_angle = cs.player_rot_angle + player_turn_speed * dt
    end
    if love.keyboard.isDown('left', 'a') then
        cs.player_rot_angle = cs.player_rot_angle - player_turn_speed * dt
    end
    cs.player_rot_angle = cs.player_rot_angle % (2 * math.pi) -- wrap player angle each 360°

    if love.keyboard.isDown('up', 'w') then
        cs.player_vel_x = cs.player_vel_x + math.cos(cs.player_rot_angle) * PLAYER_ACCELERATION * dt
        cs.player_vel_y = cs.player_vel_y + math.sin(cs.player_rot_angle) * PLAYER_ACCELERATION * dt
    end
    local is_reverse_enabled = true
    if is_reverse_enabled then
        if love.keyboard.isDown('down', 's') then
            cs.player_vel_x = cs.player_vel_x - math.cos(cs.player_rot_angle) * PLAYER_ACCELERATION * dt
            cs.player_vel_y = cs.player_vel_y - math.sin(cs.player_rot_angle) * PLAYER_ACCELERATION * dt
        end
    end

    if love.keyboard.isDown 'x' then
        dash_player_entity(dt)
    end

    if love.keyboard.isDown 'space' then
        fire_player_projectile()
    end

    if love.keyboard.isDown('lshift', 'rshift') then --- enhance attributes while spinning like a top
        player_turn_speed = DEFAULT_PLAYER_TURN_SPEED * PHI
        if love.math.random() < 0.05 then
            laser_fire_timer = 0
        else
            laser_fire_timer = game_timer_dt
        end
    else
        player_turn_speed = DEFAULT_PLAYER_TURN_SPEED
    end
end

-- Use dt for position updates, because movement is time-dependent
function update_player_entity(dt)
    local cs = curr_state
    cs.player_vel_x = cs.player_vel_x * AIR_RESISTANCE
    cs.player_vel_y = cs.player_vel_y * AIR_RESISTANCE
    cs.player_x = (cs.player_x + cs.player_vel_x * dt) % arena_w
    cs.player_y = (cs.player_y + cs.player_vel_y * dt) % arena_h
end

function update_player_entity_projectiles(dt)
    local cs = curr_state
    -- #region Update laser positions.
    for laser_index = 1, #cs.lasers_x do
        if cs.lasers_is_active[laser_index] == Status.active then
            cs.lasers_time_left[laser_index] = cs.lasers_time_left[laser_index] - dt
            if cs.lasers_time_left[laser_index] <= 0 then -- Deactivate if animation ends
                cs.lasers_is_active[laser_index] = Status.not_active
            else
                local angle = cs.lasers_angle[laser_index]
                cs.lasers_x[laser_index] = cs.lasers_x[laser_index] + math.cos(angle) * LASER_PROJECTILE_SPEED * dt
                cs.lasers_y[laser_index] = cs.lasers_y[laser_index] + math.sin(angle) * LASER_PROJECTILE_SPEED * dt
                if IS_PLAYER_PROJECTILE_WRAP_AROUND_ARENA then
                    cs.lasers_x[laser_index] = cs.lasers_x[laser_index] % arena_w
                    cs.lasers_y[laser_index] = cs.lasers_y[laser_index] % arena_h
                elseif --[[Deactivate if it goes off screen]]
                    cs.lasers_x[laser_index] < 0
                    or cs.lasers_x[laser_index] >= arena_w
                    or cs.lasers_y[laser_index] < 0
                    or cs.lasers_y[laser_index] >= arena_h
                then
                    cs.lasers_is_active[laser_index] = Status.not_active
                end
            end
        end
    end
    -- Update fire cooldown timer.
    laser_fire_timer = laser_fire_timer - dt
    -- #endregion

    -- #region Handle laser collisions.
    local laser_circle = { x = 0, y = 0, radius = 0 } ---@type Circle
    local creature_circle = { x = 0, y = 0, radius = 0 } ---@type Circle
    for laser_index = 1, #cs.lasers_x do
        if not (cs.lasers_is_active[laser_index] == Status.active) then
            goto continue_not_is_active_laser
        end
        laser_circle = {
            x = cs.lasers_x[laser_index],
            y = cs.lasers_y[laser_index],
            radius = laser_radius,
        }
        for creature_index = 1, TOTAL_CREATURES_CAPACITY do
            if not (cs.creatures_is_active[creature_index] == Status.active) then
                goto continue_not_is_active_creature
            end
            local curr_stage = cs.creatures_evolution_stage[creature_index]
            assert(curr_stage >= 1 and curr_stage <= #creature_evolution_stages, curr_stage)
            creature_circle = {
                x = cs.creatures_x[creature_index],
                y = cs.creatures_y[creature_index],
                radius = creature_evolution_stages[curr_stage].radius,
            }
            if is_intersect_circles { a = creature_circle, b = laser_circle } then -- TODO: I think this stage value should be updated.....
                do
                    cs.lasers_is_active[laser_index] = Status.not_active -- deactivate projectile if hits creature
                    screenshake.duration = 0.15 -- got'em!

                    cs.creatures_is_active[creature_index] = Status.not_active -- deactivate current creature stage if hits creature
                    cs.creatures_health[creature_index] = Health.healing
                end

                -- Split the creature into two smaller ones.
                if curr_stage > 1 then
                    local new_stage = curr_stage - 1 -- note: initial stage is `#creature_evolution_stages`
                    cs.creatures_evolution_stage[creature_index] = new_stage
                    for i = 1, 2 do
                        local new_creature_index = find_inactive_creature_index()
                        if new_creature_index then
                            spawn_new_creature(new_creature_index, creature_index, new_stage)
                        else
                            if debug.is_trace_entities then
                                print('Failed to spawn more creatures.\n', 'curr_stage:', curr_stage, 'i:', i)
                            end
                            break -- skip if we can't spawn anymore
                        end
                    end
                end
                break -- this projectile has served it's purpose
            end
            ::continue_not_is_active_creature::
        end
        ::continue_not_is_active_laser::
    end
    -- #endregion
end

function find_inactive_creature_index()
    for i = 1, TOTAL_CREATURES_CAPACITY do
        if curr_state.creatures_is_active[i] == Status.not_active then
            return i
        end
    end

    return nil
end

function count_active_creatures()
    local counter = 0
    for i = 1, TOTAL_CREATURES_CAPACITY do
        if curr_state.creatures_is_active[i] == Status.active then
            counter = counter + 1
        end
    end

    return counter
end

function spawn_new_fused_creature_pair(new_index, parent_index1, parent_index2, new_stage)
    -- assert(new_stage <= #creature_evolution_stages) --
    --
    do
        -- spawn_new_creature(new_index, parent_index, new_stage)
    end
end

--- @type fun(t: { x1: number, y1: number, x2: number, y2: number }): number
function manhattan_distance(t)
    return math.abs(t.x1 - t.x2) + math.abs(t.y1 - t.y2)
end

--- NOTE: Does not mutate position.
function simulate_creatures_swarm_behavior(dt)
    local cs = curr_state

    for creature_index = 1, TOTAL_CREATURES_CAPACITY do
        if cs.creatures_is_active[creature_index] == Status.active then
            local group_center_x = 0
            local group_center_y = 0
            local count = 0
            local creature_stage_id = cs.creatures_evolution_stage[creature_index] --- @type integer
            local creature_stage = creature_evolution_stages[creature_stage_id] --- @type Stage
            -- local creature_swarm_range = creature_stage.radius --- @type integer # TEMPORARY solution
            local creature_x = cs.creatures_x[creature_index]
            local creature_y = cs.creatures_y[creature_index]

            -- use dt here?
            local creature_group_factor = 0.4 --- @type number|integer # TEMPORARY solution

            for other_creature_index = 1, TOTAL_CREATURES_CAPACITY do
                if cs.creatures_is_active[other_creature_index] == Status.active then
                    local other_creature_x = cs.creatures_x[other_creature_index]
                    local other_creature_y = cs.creatures_y[other_creature_index]

                    local dist = nil
                    if
                        creature_x ~= nil
                        and creature_y ~= nil
                        and other_creature_x ~= nil
                        and other_creature_y ~= nil
                    then
                        dist = manhattan_distance {
                            x1 = creature_x,
                            y1 = creature_y,
                            x2 = other_creature_x,
                            y2 = other_creature_y,
                        }
                    end
                    do
                        local __is_log_enabled = false
                        if __is_log_enabled and debug.is_trace_entities and love.math.random() < 0.05 then
                            print(dist, creature_swarm_range, creature_index, other_creature_index, count)
                        end
                    end

                    if creature_index ~= other_creature_index and dist ~= nil and (dist <= creature_swarm_range) then
                        group_center_x = group_center_x + cs.creatures_x[other_creature_index]
                        group_center_y = group_center_y + cs.creatures_y[other_creature_index]
                        count = count + 1
                    end
                    local __is_swarm_damped = dist <= creature_swarm_range -- temporary
                    if count > 0 and __is_swarm_damped then
                        group_center_x = group_center_x / count
                        group_center_y = group_center_y / count
                        local curr_vel_x = cs.creatures_vel_x[creature_index]
                        local curr_vel_y = cs.creatures_vel_y[creature_index]
                        local factor = love.math.random() < 0.5 and dt or creature_group_factor

                        local next_vel_x = curr_vel_x + (group_center_x - creature_y) * factor
                        local next_vel_y = curr_vel_y + (group_center_y - creature_y) * factor
                        do
                            local __is_log_enabled = false
                            if __is_log_enabled and debug.is_trace_entities and love.math.random() < 0.05 then
                                print('range', creature_swarm_range, 'dist', dist)
                                print(curr_vel_x, ' -> ', next_vel_x, curr_vel_y, ' -> ', next_vel_y)
                            end
                        end
                        -- HACK: Update and clamp new speed to base speed for each respective stage.
                        cs.creatures_vel_x[creature_index] = lerp(creature_stage.speed, next_vel_x, 0.8)
                        cs.creatures_vel_y[creature_index] = lerp(creature_stage.speed, next_vel_y, 0.8)
                    end
                end
            end
        end
    end
end

function spawn_new_creature(new_index, parent_index, new_stage)
    if count_active_creatures() >= MAX_CREATURES_IN_ARENA then
        print 'Count of creatures in arena exceeded limit'
        return
    end

    local cs = curr_state
    local angle1 = love.math.random() * (2 * math.pi)
    local angle2 = (angle1 - math.pi) % (2 * math.pi)
    local alpha = dt_accum * FIXED_DT_INV
    local angle_offset = lerp(angle1, angle2, alpha)
    cs.creatures_angle[new_index] = cs.creatures_angle[parent_index] + angle_offset
    cs.creatures_evolution_stage[new_index] = new_stage
    cs.creatures_is_active[new_index] = Status.active
    cs.creatures_x[new_index] = cs.creatures_x[parent_index]
    cs.creatures_y[new_index] = cs.creatures_y[parent_index]

    -- Avoid overlap among new creatures.
    local offset = creature_evolution_stages[new_stage].radius * 0.5
    cs.creatures_x[new_index] = cs.creatures_x[new_index] + love.math.random(-offset, offset)
    cs.creatures_y[new_index] = cs.creatures_y[new_index] + love.math.random(-offset, offset)
end

function update_creatures(dt)
    local cs = curr_state
    local player_circle = { x = cs.player_x, y = cs.player_y, radius = player_radius } ---@type Circle
    local creature_circle = { x = 0, y = 0, radius = 0 } ---@type Circle # hope for cache-locality
    local alpha = dt_accum * FIXED_DT

    for i = 1, TOTAL_CREATURES_CAPACITY do
        if debug.is_test then
            -- if cs.creatures_health[i] > Health.healing then
            --     assert(cs.creatures_status[i] == Status.none)
            -- end
        end
        if not (cs.creatures_is_active[i] == Status.active) then
            local health = cs.creatures_health[i]
            if health >= Health.healing and health < Health.healthy then
                cs.creatures_health[i] = health + (alpha + game_timer_dt) -- note: using dt will make it feel too linear
            end
            if health >= Health.healthy then -- Creature rescued. The End.
                cs.creatures_health[i] = Health.none -- note: using dt will make it feel too linear
            end
            goto continue
        end
        local angle = cs.creatures_angle[i] --- @type number
        local creature_stage_id = cs.creatures_evolution_stage[i] --- @type integer

        if debug.is_test then
            assert(creature_stage_id >= 1 and creature_stage_id <= creature_stages_index)
        end

        local stage = creature_evolution_stages[creature_stage_id] --- @type Stage
        local speed_x = lerp(stage.speed, cs.creatures_vel_x[i], alpha)
        local speed_y = lerp(stage.speed, cs.creatures_vel_y[i], alpha)
        local x = (cs.creatures_x[i] + math.cos(angle) * speed_x * dt) % arena_w --- @type number
        local y = (cs.creatures_y[i] + math.sin(angle) * speed_y * dt) % arena_h --- @type number

        -- Update new location.
        cs.creatures_x[i] = x
        cs.creatures_y[i] = y

        creature_circle = { x = x, y = y, radius = stage.radius }

        if is_intersect_circles { a = player_circle, b = creature_circle } then -- defeat
            screenshake.duration = 0.15
            reset_game()
            return
        end

        ::continue::
    end

    -- local active_creature_count = 0
    -- for i = 1, TOTAL_CREATURES_CAPACITY do
    --     if cs.creatures_status[i] == Status.active then -- increment
    --         active_creature_count = active_creature_count + 1
    --     end
    -- end
    if count_active_creatures() == 0 then -- victory
        reset_game()
        return
    end
end

function update_game(dt) ---@param dt number # Fixed delta time.
    handle_player_input(dt)
    update_player_entity(dt)
    update_player_entity_projectiles(dt)
    simulate_creatures_swarm_behavior(dt)
    update_creatures(dt)
end

function draw_hud()
    local pad_x = 8 -- horizontal
    local pad_y = 8 -- vertical
    local hud_w = 128
    local hud_h = 128
    local pos_x = arena_w - hud_w
    local pos_y = 0

    local cs = curr_state

    local active_counter = 0
    for _, value in ipairs(cs.creatures_is_active) do
        if value == Status.active then
            active_counter = active_counter + 1
        end
    end
    LG.setColor(Color.text_darkest)
    LG.print(
        table.concat({
            active_counter .. ' remaining',
            string.format('%.4s', game_timer_t),
        }, '\n'),
        1 * pos_x,
        1 * pos_y
    )

    -- HACK: To avoid leaking debug hud text color into post-processing shader.
    LG.setColor(1, 1, 1)
end
function draw_debug_hud()
    local cs = curr_state

    local pad_x = 8
    local pad_y = 8
    local pos_x = 0
    local pos_y = 0

    LG.setColor(0, 0, 0, 0.7)
    LG.rectangle('fill', pos_x, pos_y, 222, arena_h)

    local stats = LG.getStats()
    local fps = love.timer.getFPS()
    local dt = love.timer.getDelta()

    local active_counter = 0
    for _, value in ipairs(cs.creatures_is_active) do
        if value == Status.active then
            active_counter = active_counter + 1
        end
    end

    LG.setColor(Color.text_debug_hud)
    LG.print(
        table.concat({
            'creatures.active: ' .. active_counter,
            'creatures.count: ' .. #cs.creatures_x,
            'player.angle: ' .. cs.player_rot_angle,
            'player.speed_x: ' .. cs.player_vel_x,
            'player.speed_y: ' .. cs.player_vel_y,
            'player.x: ' .. cs.player_x,
            'player.y: ' .. cs.player_y,
            'stats.canvases: ' .. stats.canvases,
            'stats.canvasswitches: ' .. stats.canvasswitches,
            'stats.drawcalls: ' .. stats.drawcalls,
            'stats.drawcallsbatch: ' .. stats.drawcallsbatched,
            'stats.fonts: ' .. stats.fonts,
            'stats.images: ' .. stats.images,
            'stats.shaderswitches: ' .. stats.shaderswitches,
            'stats.texturememory: ' .. stats.texturememory,
            'timer.dt: ' .. dt,
            'timer.fps: ' .. fps,
            'lasers.count: ' .. #cs.lasers_x,
        }, '\n'),
        pos_x + pad_x,
        pos_y + pad_y
    )

    -- HACK: To avoid leaking debug hud text color into post-processing shader.
    LG.setColor(1, 1, 1)
end

function love.draw()
    if debug.is_test then
        assert_consistent_state()
    end

    shaders.post_processing(function()
        -- So that objects that are partially off the edge of the screen can be seen on the other side,
        -- the coordinate system is translated to different positions and everything is drawn at each
        -- position around the screen and in the center.
        for y = -1, 1 do -- Draw off-screen object partially wrap around without glitch
            for x = -1, 1 do
                local alpha = dt_accum * FIXED_DT_INV

                --
                --#region ORIGIN
                --
                -- Resets the current coordinate transformation. Reverse any
                -- previous calls to LG.rotate, LG.scale, LG.shear or LG.translate.
                LG.origin()

                LG.translate(x * arena_w, y * arena_h)

                -- Add Visual Effects. (TODO: Make it optional, and sensory warning perhaps?)
                if screenshake.duration > 0 then
                    LG.translate(screenshake.offset_x, screenshake.offset_y)

                    do
                        LG.setColor { 1, 1, 1, 0.045 }
                        LG.rectangle('fill', 0, 0, arena_w, arena_h)
                    end
                end

                local juice_frequency = 1 + math.sin(FIXED_FPS * game_timer_dt)
                local juice_frequency_damper = lerp(0.0625, 0.125, alpha)

                -- Draw player player
                local player_angle = lerp(prev_state.player_rot_angle, curr_state.player_rot_angle, alpha)
                local player_x = lerp(prev_state.player_x, curr_state.player_x, alpha)
                local player_y = lerp(prev_state.player_y, curr_state.player_y, alpha)

                local is_interpolate_player = true
                if is_interpolate_player then
                    local player_speed_x =
                        lerp(prev_state.player_vel_x, curr_state.player_vel_x * AIR_RESISTANCE, alpha)
                    local player_speed_y =
                        lerp(prev_state.player_vel_y, curr_state.player_vel_y * AIR_RESISTANCE, alpha)
                    player_x = (player_x + player_speed_x * game_timer_dt) % arena_w
                    player_y = (player_y + player_speed_y * game_timer_dt) % arena_h
                    LG.setColor(Color.player_entity_firing_edge_darker)
                    LG.circle('fill', player_x, player_y, player_radius)
                end

                -- Draw player inner iris * (iris)
                local player_iris_radius = (player_radius * PLAYER_CIRCLE_IRIS_TO_EYE_RATIO)
                    * (1 + juice_frequency * juice_frequency_damper)
                LG.setColor(Color.player_entity)
                LG.circle('fill', player_x, player_y, player_iris_radius)

                -- Draw player player firing trigger • (circle)
                local player_trigger_radius =
                    lerp(player_firing_edge_max_radius - 4, player_firing_edge_max_radius - 3, alpha)
                local player_edge_x = player_x + math.cos(player_angle) * player_firing_edge_max_radius
                local player_edge_y = player_y + math.sin(player_angle) * player_firing_edge_max_radius
                do -- @juice ─ simulate the twinkle in eye to go opposite to player's direction
                    local inertia_x = 0
                    local inertia_y = 0
                    if love.keyboard.isDown('up', 'w') then
                        inertia_x = curr_state.player_vel_x
                            + math.cos(curr_state.player_rot_angle) * PLAYER_ACCELERATION * game_timer_dt
                        inertia_y = curr_state.player_vel_y
                            + math.sin(curr_state.player_rot_angle) * PLAYER_ACCELERATION * game_timer_dt
                    end
                    if love.keyboard.isDown('down', 's') then
                        inertia_x = curr_state.player_vel_x
                            - math.cos(curr_state.player_rot_angle) * PLAYER_ACCELERATION * game_timer_dt
                        inertia_y = curr_state.player_vel_y
                            - math.sin(curr_state.player_rot_angle) * PLAYER_ACCELERATION * game_timer_dt
                    end
                    inertia_x = curr_state.player_vel_x * AIR_RESISTANCE
                    inertia_y = curr_state.player_vel_y * AIR_RESISTANCE
                    player_edge_x = player_edge_x
                        - (0.328 * player_firing_edge_max_radius) * (inertia_x * game_timer_dt)
                    player_edge_y = player_edge_y
                        - (0.328 * player_firing_edge_max_radius) * (inertia_y * game_timer_dt)
                end

                local is_plus_sprite = false
                LG.setColor(Color.player_entity_firing_edge_dark)
                -- if is_plus_sprite then
                --     draw_plus_icon(player_edge_x, player_edge_y, player_trigger_radius)
                -- else
                LG.circle('fill', player_edge_x, player_edge_y, player_trigger_radius)
                -- end

                local is_trail_enabled = false
                if is_trail_enabled then
                    local trail_length = 5 -- No. of past positions to draw as a trail
                    for i = 1, #curr_state.lasers_x do
                        local pos_x = curr_state.lasers_x[i]
                        local pos_y = curr_state.lasers_y[i]

                        if prev_state.lasers_is_active[i] == Status.active then
                            pos_x = lerp(prev_state.lasers_x[i], pos_x, alpha)
                            pos_y = lerp(prev_state.lasers_y[i], pos_y, alpha)
                        end

                        -- THIS MAY ERR, if prev trail is nil
                        for t = trail_length, 1, -1 do
                            local trail_factor = t / trail_length
                            local trail_x = lerp(prev_state.lasers_x[i], pos_x, trail_factor)
                            local trail_y = lerp(prev_state.lasers_y[i], pos_y, trail_factor)
                            LG.setColor(
                                Color.player_entity_firing_projectile[1],
                                Color.player_entity_firing_projectile[2],
                                Color.player_entity_firing_projectile[3],
                                trail_factor
                            ) -- Fading effect
                            draw_plus_icon(trail_x, trail_y, laser_radius * trail_factor, 3)
                        end

                        if is_plus_sprite then
                            draw_plus_icon(pos_x, pos_y, laser_radius * PHI, 3)
                        else
                            LG.circle('fill', pos_x, pos_y, laser_radius)
                        end
                    end
                else
                    -- Draw player player fired projectiles
                    LG.setColor(Color.player_entity_firing_projectile)
                    for i = 1, #curr_state.lasers_x do
                        if curr_state.lasers_is_active[i] == Status.active then
                            local pos_x = curr_state.lasers_x[i]
                            local pos_y = curr_state.lasers_y[i]
                            if prev_state.lasers_is_active[i] == Status.active then
                                pos_x = lerp(prev_state.lasers_x[i], pos_x, alpha)
                                pos_y = lerp(prev_state.lasers_y[i], pos_y, alpha)
                            end

                            if is_plus_sprite then
                                draw_plus_icon(pos_x, pos_y, laser_radius * PHI, 3)
                            else
                                LG.circle('fill', pos_x, pos_y, laser_radius)
                            end
                        end
                    end
                end

                -- Draw creatures
                local should_interpolate = false -- FIXME: Changing states, causes glitches
                for i = 1, #curr_state.creatures_x do
                    local evolution_stage = creature_evolution_stages[curr_state.creatures_evolution_stage[i]] --- @type Stage

                    if curr_state.creatures_is_active[i] == Status.active then
                        LG.setColor(Color.creature_infected)
                        local curr_x = curr_state.creatures_x[i]
                        local curr_y = curr_state.creatures_y[i]
                        local creature_radius = evolution_stage.radius --- @type integer
                        if should_interpolate then
                            local prev_x = prev_state.creatures_x[i]
                            local prev_y = prev_state.creatures_y[i]
                            local can_interpolate = ( --[[@type boolean]]
                                math.abs(curr_x - prev_x) <= (arena_w - 2 * creature_radius)
                                and math.abs(curr_y - prev_y) <= (arena_h - 2 * creature_radius)
                            )
                            if can_interpolate then
                                curr_x = lerp(prev_x, curr_x, alpha)
                                curr_y = lerp(prev_y, curr_y, alpha)
                            end
                        end

                        -- Draw swarm behavior glitch circumference effect (blur-haze) on this creature.
                        local tolerance = evolution_stage.speed
                        if math.abs(curr_state.creatures_vel_x[i] - prev_state.creatures_vel_x[i]) >= tolerance then
                            LG.setColor(Color.creature_infected_rgba)
                            local segments = lerp(18, 6, alpha) -- for an eeerie hexagonal sharp edges effect
                            local segment_distortion_amplitude = 2
                            local segment_distortion = (segments * math.sin(segments) * 0.03)
                                * segment_distortion_amplitude
                            -- FIXME: swarm range ─ should be evolution_stage.radius specific
                            local distorting_radius =
                                lerp(creature_radius - 1, creature_radius + 1 + segment_distortion, alpha)
                            LG.circle('line', curr_x, curr_y, distorting_radius, segments)
                            LG.setColor(Color.creature_infected) --- HACK: RESET leaking color to post-processing shader
                        end

                        -- Draw this creature.
                        LG.circle('fill', curr_x, curr_y, evolution_stage.radius)
                    else
                        local is_not_moving = prev_state.creatures_x[i] ~= prev_state.creatures_x[i]
                            and prev_state.creatures_x[i] ~= curr_state.creatures_y[i]
                        local curr_x = curr_state.creatures_x[i]
                        local curr_y = curr_state.creatures_y[i]
                        -- PLACEHOLDER for "If we can attach a countdown timer for state change active -> inactive,
                        -- and then show the success healing while the timer is running till 0..."
                        -- BUT why bother for now? dormant inactive cells lie still at corners,
                        -- and so, lets just not draw cells near corner that are inactive
                        local corner_offset = player_radius + evolution_stage.radius
                        local is_away_from_corner = (
                            curr_x >= 0 + corner_offset
                            and curr_x <= arena_w - corner_offset
                            and curr_y >= 0 + corner_offset
                            and curr_y <= arena_h - corner_offset
                        )
                        if is_away_from_corner or is_not_moving then
                            -- automatically disappear when the `find_inactive_creature_index` looks them up
                            -- and then `spawn_new_creature` mutates them.
                            local health = curr_state.creatures_health[i]
                            if
                                curr_state.creatures_is_active[i] == Status.not_active
                                and health > Health.healing
                                and health <= Health.healthy
                            then
                                LG.setColor(Color.creature_healed)
                                LG.circle('fill', curr_x, curr_y, evolution_stage.radius)
                                if alpha < PHI_INV then
                                    local radius_ = evolution_stage.radius
                                        * (1 + alpha * juice_frequency * lerp(1, juice_frequency_damper, alpha))
                                    LG.setColor(Color.creature_healing)
                                    LG.circle('fill', curr_x, curr_y, radius_)
                                    LG.setColor(1, 1, 1)
                                    for dy = -1, 1 do
                                        for dx = -1, 1 do
                                            draw_plus_icon(curr_x + dx, curr_y + dy, radius_)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        -- Reverse any previous calls to LG.rotate, LG.scale, LG.shear or LG.translate.
        -- It returns the current transformation state to its defaults.
        LG.origin()
        draw_hud()
        --
        --#endregion ORIGIN
        --
    end)

    if is_debug_hud_enabled then
        draw_debug_hud()
    end
end

function draw_plus_icon(x_, y_, size_, linewidth)
    local half_size = size_ * 0.5
    -- horizontal
    LG.setLineWidth(linewidth or 2)
    LG.line(x_ - half_size, y_, x_ + half_size, y_)
    -- vertical
    LG.line(x_, y_ - half_size, x_, y_ + half_size)
end

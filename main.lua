---@diagnostic disable: lowercase-global, undefined-global, duplicate-set-field

--- Ported initially from https://berbasoft.com/simplegametutorials/love/asteroids/

local moonshine = require 'lib.moonshine'

local LG = love.graphics

--- @class GameState
--- @field creatures_angle number[]
--- @field creatures_evolution_stage integer[]
--- @field creatures_is_active Status[]
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
    active = 1,
    inactive = 0,
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
    creature = { 0.8, 0.1, 0.3 },
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
local INITIAL_LARGE_CREATURES = 3
local IS_GRUG_BRAIN = false --- Whether to complicate life and the codebase.
local IS_PLAYER_PROJECTILE_WRAP_AROUND_ARENA = true --- Flags if fired projectile should wrap around arena.
local LASER_FIRE_TIMER_LIMIT = 0.5
local LASER_PROJECTILE_SPEED = 500
local MAX_CREATURES = 32 --- adjust as you please
local PLAYER_ACCELERATION = 100
local PLAYER_CIRCLE_IRIS_TO_EYE_RATIO = 0.618
local PLAYER_FIRE_COOLDOWN_TIMER_LIMIT = 6 --- Note: 6 is rough guess, but intend for alpha lifecycle from 0.0 to 1.0.
local PLAYER_TURN_SPEED = 10 * 0.5

local FIXED_DT = 1 / FIXED_FPS --- Ensures consistent game logic updates regardless of frame rate fluctuations.
local FIXED_DT_INV = 1 / (1 / FIXED_FPS) --- avoid dividing each frame

--
-- Variables
--

local dt_accum = 0.0 --- Accumulator keeps track of time passed between frames.
local debug = { --- Debugging Flags.
    is_development = true,
    is_test = true,
    is_trace_entities = false,
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
    assert(#ps.creatures_evolution_stage == #cs.creatures_evolution_stage)
    assert(#ps.creatures_x == #cs.creatures_x)
    assert(#ps.creatures_y == #cs.creatures_y)
    assert(#ps.lasers_angle == #cs.lasers_angle)
    assert(#ps.lasers_is_active == #cs.lasers_is_active)
    assert(#ps.lasers_time_left == #cs.lasers_time_left)
    assert(#ps.lasers_x == #cs.lasers_x)
    assert(#ps.lasers_y == #cs.lasers_y)

    assert(#cs.lasers_x == laser_capacity)
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
        ps.creatures_is_active[i] = cs.creatures_is_active[i]
        ps.creatures_evolution_stage[i] = cs.creatures_evolution_stage[i]
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

    game_timer_t = 0.0
    game_timer_dt = 0.0

    is_debug_hud_enabled = false --- Toggled by keys event.
    player_fire_cooldown_timer = 0

    player_radius = 30
    laser_capacity = 30
    laser_fire_timer = 0
    laser_index = 1 -- circular buffer index
    laser_radius = 5

    -- active_creatures = 0
    player_firing_edge_max_radius = math.ceil(player_radius * 0.328) --- Trigger distance from center of player.

    local fx = moonshine.effects

    shaders = { --- @type Shader
        post_processing = moonshine(arena_w, arena_h, fx.colorgradesimple)
            .chain(fx.chromasep)
            -- .chain(fx.crt)
            .chain(fx.scanlines)
            .chain(fx.vignette),
    }
    shaders.post_processing.scanlines.opacity = 1 * 0.618
    shaders.post_processing.scanlines.thickness = 1 * 0.5 * 0.0618
    shaders.post_processing.scanlines.width = 2

    prev_state = { --- @type GameState
        creatures_angle = {},
        creatures_evolution_stage = {},
        creatures_is_active = {},
        creatures_x = {},
        creatures_y = {},
        player_rot_angle = 0,
        player_vel_x = 0,
        player_vel_y = 0,
        player_x = 0,
        player_y = 0,
        lasers_angle = {},
        lasers_is_active = {},
        lasers_time_left = {},
        lasers_x = {},
        lasers_y = {},
    }

    curr_state = { --- @type GameState
        creatures_angle = {},
        creatures_evolution_stage = {},
        creatures_is_active = {},
        creatures_x = {},
        creatures_y = {},
        player_rot_angle = 0,
        player_vel_x = 0,
        player_vel_y = 0,
        player_x = 0,
        player_y = 0,
        lasers_angle = {},
        lasers_is_active = {},
        lasers_time_left = {},
        lasers_x = {},
        lasers_y = {},
    }

    screenshake = { --- @type ScreenShake
        amount = 5 * 0.5 * 0.618,
        duration = 0.0,
        offset_x = 0.0,
        offset_y = 0.0,
        wait = 0.0,
    }

    do
        local creature_scale = 0.618
        creature_evolution_stages = { ---@type Stage[] # Size decreases as stage progresses.
            { speed = 100, radius = math.ceil(15 * creature_scale) },
            { speed = 70, radius = math.ceil(30 * creature_scale) },
            { speed = 50, radius = math.ceil(50 * creature_scale) },
            { speed = 20, radius = math.ceil(80 * creature_scale) },
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

        for i = 1, laser_capacity do
            curr_state.lasers_angle[i] = 0
            curr_state.lasers_is_active[i] = Status.inactive
            curr_state.lasers_time_left[i] = LASER_FIRE_TIMER_LIMIT
            curr_state.lasers_x[i] = 0
            curr_state.lasers_y[i] = 0
        end
        laser_fire_timer = 0
        laser_index = 1 -- reset circular buffer index

        -- Test me:
        -- curr_state.creatures_x = { 100, arena_w - 100, arena_w / 2 }
        -- curr_state.creatures_y = { 100, 100, arena_h - 10 }

        local largest_creature_stage = #creature_evolution_stages
        for i = 1, MAX_CREATURES do -- Pre-allocate all creature's including stage combinations
            curr_state.creatures_angle[i] = 0
            curr_state.creatures_is_active[i] = Status.inactive
            curr_state.creatures_evolution_stage[i] = largest_creature_stage
            curr_state.creatures_x[i] = 0
            curr_state.creatures_y[i] = 0
        end

        for i = 1, INITIAL_LARGE_CREATURES do -- Activate initial creatures.
            curr_state.creatures_angle[i] = love.math.random() * (2 * math.pi)
            curr_state.creatures_is_active[i] = Status.active
            curr_state.creatures_evolution_stage[i] = largest_creature_stage -- Start at smallest stage
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
        laser_index = (laser_index % laser_capacity) + 1 -- Laser_index tracks circular reusable buffer.
        laser_fire_timer = LASER_FIRE_TIMER_LIMIT -- Reset timer to default.
    end
end

function handle_player_input(dt)
    local cs = curr_state

    if love.keyboard.isDown('right', 'd') then
        cs.player_rot_angle = cs.player_rot_angle + PLAYER_TURN_SPEED * dt
    end
    if love.keyboard.isDown('left', 'a') then
        cs.player_rot_angle = cs.player_rot_angle - PLAYER_TURN_SPEED * dt
    end
    cs.player_rot_angle = cs.player_rot_angle % (2 * math.pi) -- wrap player angle each 360°

    if love.keyboard.isDown('up', 'w') then
        cs.player_vel_x = cs.player_vel_x + math.cos(cs.player_rot_angle) * PLAYER_ACCELERATION * dt
        cs.player_vel_y = cs.player_vel_y + math.sin(cs.player_rot_angle) * PLAYER_ACCELERATION * dt
    end
    if love.keyboard.isDown('down', 's') then
        cs.player_vel_x = cs.player_vel_x - math.cos(cs.player_rot_angle) * PLAYER_ACCELERATION * dt
        cs.player_vel_y = cs.player_vel_y - math.sin(cs.player_rot_angle) * PLAYER_ACCELERATION * dt
    end

    if love.keyboard.isDown 'space' then
        fire_player_projectile()
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
                cs.lasers_is_active[laser_index] = Status.inactive
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
                    cs.lasers_is_active[laser_index] = Status.inactive
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
        for creature_index = 1, MAX_CREATURES do
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
                cs.lasers_is_active[laser_index] = Status.inactive -- deactivate projectile if hits creature
                screenshake.duration = 0.15 -- got'em!
                cs.creatures_is_active[creature_index] = Status.inactive -- deactivate current creature stage if hits creature

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
    for i = 1, MAX_CREATURES do
        if curr_state.creatures_is_active[i] == Status.inactive then
            return i
        end
    end
    return nil
end

function spawn_new_creature(new_index, parent_index, new_stage)
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
    for i = 1, MAX_CREATURES do
        if not (cs.creatures_is_active[i] == Status.active) then
            goto continue
        end
        local angle = cs.creatures_angle[i] --- @type number
        local creature_stage_id = cs.creatures_evolution_stage[i] --- @type integer
        if debug.is_test then
            assert(creature_stage_id >= 1 and creature_stage_id <= creature_stages_index)
        end
        local stage = creature_evolution_stages[creature_stage_id] --- @type Stage
        local x = (cs.creatures_x[i] + math.cos(angle) * stage.speed * dt) % arena_w --- @type number
        local y = (cs.creatures_y[i] + math.sin(angle) * stage.speed * dt) % arena_h --- @type number
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

    local active_creature_count = 0
    for i = 1, MAX_CREATURES do
        if cs.creatures_is_active[i] == Status.active then -- increment
            active_creature_count = active_creature_count + 1
        end
    end
    if active_creature_count == 0 then -- victory
        reset_game()
        return
    end
end

function update_game(dt) ---@param dt number # Fixed delta time.
    if debug.is_trace_entities then
        print('before', #prev_state.creatures_is_active, #curr_state.creatures_is_active)
    end

    handle_player_input(dt)
    update_player_entity(dt)
    update_player_entity_projectiles(dt)
    update_creatures(dt)

    if debug.is_trace_entities then
        print('after', #prev_state.creatures_is_active, #curr_state.creatures_is_active)
    end
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
                if screenshake.duration > 0 then --
                    LG.translate(screenshake.offset_x, screenshake.offset_y)
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
                    lerp(player_firing_edge_max_radius - 4, player_firing_edge_max_radius - 2, alpha)
                LG.setColor(Color.player_entity_firing_edge_dark)
                local player_edge_x = player_x + math.cos(player_angle) * player_firing_edge_max_radius
                local player_edge_y = player_y + math.sin(player_angle) * player_firing_edge_max_radius
                LG.circle('fill', player_edge_x, player_edge_y, player_trigger_radius)

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
                        LG.circle('fill', pos_x, pos_y, laser_radius)
                    end
                end

                -- Draw creatures
                local should_interpolate = false -- FIXME: Changing states, causes glitches
                LG.setColor(Color.creature)
                for i = 1, #curr_state.creatures_x do
                    if curr_state.creatures_is_active[i] == Status.active then
                        local curr_x = curr_state.creatures_x[i]
                        local curr_y = curr_state.creatures_y[i]
                        local prev_x = prev_state.creatures_x[i]
                        local prev_y = prev_state.creatures_y[i]
                        local evolution_stage = creature_evolution_stages[curr_state.creatures_evolution_stage[i]] --- @type Stage
                        local creature_radius = evolution_stage.radius --- @type integer
                        local can_interpolate = ( --[[@type boolean]]
                            math.abs(curr_x - prev_x) <= (arena_w - 2 * creature_radius)
                            and math.abs(curr_y - prev_y) <= (arena_h - 2 * creature_radius)
                        )
                        if should_interpolate and can_interpolate then
                            curr_x = lerp(prev_x, curr_x, alpha)
                            curr_y = lerp(prev_y, curr_y, alpha)
                        end
                        LG.circle('fill', curr_x, curr_y, evolution_stage.radius)
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

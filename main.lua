---@diagnostic disable: lowercase-global, undefined-global, duplicate-set-field

--[[

Ludum Dare 56: Tiny Creatures
    See https://ldjam.com/events/ludum-dare/56/$403597

Starter setup ported initially from https://berbasoft.com/simplegametutorials/love/asteroids/

Development
    $ find -name '*.lua' | entr -crs 'date; love .; echo exit status $?'

--]]

local moonshine = require 'lib.moonshine'

local config    = require 'config'
local common    = require 'common'
local simulate  = require 'simulate'

local LG        = love.graphics

local PHI       = config.PHI
local lerp      = common.lerp

--
--
-- Types & Definitions
--
--

--- @class GameState
--- @field creatures_angle number[]
--- @field creatures_evolution_stage integer[]
--- @field creatures_health HealthTransitions[] # Transitions from `-1 to 0` and `0..1`.
--- @field creatures_is_active Status[]
--- @field creatures_vel_x number[]
--- @field creatures_vel_y number[]
--- @field creatures_x number[]
--- @field creatures_y number[]
--- @field lasers_angle number[]
--- @field lasers_is_active Status[]
--- @field lasers_time_left number[]
--- @field lasers_x number[]
--- @field lasers_y number[]
--- @field player_rot_angle number # 0
--- @field player_vel_x number # 0
--- @field player_vel_y number # 0
--- @field player_x number # 0|400
--- @field player_y number # 0|300

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

--
--
-- State Synchronizers
--
--

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

    assert(#cs.lasers_x == config.MAX_LASER_CAPACITY)
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

--
--
-- Update Helpers
--
--

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
        cs.lasers_is_active[laser_index] = common.Status.active
        cs.lasers_time_left[laser_index] = 4
        cs.lasers_x[laser_index] = cs.player_x + math.cos(cs.player_rot_angle) * player_radius
        cs.lasers_y[laser_index] = cs.player_y + math.sin(cs.player_rot_angle) * player_radius
        laser_index = (laser_index % config.MAX_LASER_CAPACITY) + 1 -- Laser_index tracks circular reusable buffer.
        laser_fire_timer = config.LASER_FIRE_TIMER_LIMIT            -- Reset timer to default.
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

function find_inactive_creature_index()
    for i = 1, config.TOTAL_CREATURES_CAPACITY do
        if curr_state.creatures_is_active[i] == common.Status.not_active then
            return i
        end
    end

    return nil
end

function find_inactive_creature_index_except(index)
    for i = 1, config.TOTAL_CREATURES_CAPACITY do
        if curr_state.creatures_is_active[i] == common.Status.not_active and i ~= index then
            return i
        end
    end

    return nil
end

--- Check if two creatures are close enough to start fusion.
function check_creature_is_close_enough(index1, index2, fuse_distance)
    local cs = curr_state
    local distance = common.manhattan_distance {
        x1 = cs.creatures_x[index1],
        y1 = cs.creatures_y[index1],
        x2 = cs.creatures_x[index2],
        y2 = cs.creatures_y[index2],
    }

    local stage_id_1 = cs.creatures_evolution_stage[index1]
    local stage_id_2 = cs.creatures_evolution_stage[index2]
    local stage_1 = creature_evolution_stages[stage_id_1]
    local stage_2 = creature_evolution_stages[stage_id_2]

    return distance < (stage_1.radius + stage_2.radius + fuse_distance)
end

function count_active_creatures()
    local counter = 0
    for i = 1, config.TOTAL_CREATURES_CAPACITY do
        if curr_state.creatures_is_active[i] == common.Status.active then
            counter = counter + 1
        end
    end

    return counter
end

function spawn_new_creature(new_index, parent_index, new_stage, offset)
    local cs = curr_state
    local angle1 = love.math.random() * (2 * math.pi)
    local angle2 = (angle1 - math.pi) % (2 * math.pi)
    local alpha = dt_accum * config.FIXED_DT_INV
    local angle_offset = lerp(angle1, angle2, alpha)
    local parent_angle = cs.creatures_angle[parent_index]

    if cs.creatures_is_active[new_index] == common.Status.active then
        error('expected to not be active')
    end

    cs.creatures_angle[new_index] = parent_angle + angle_offset
    cs.creatures_evolution_stage[new_index] = new_stage
    cs.creatures_is_active[new_index] = common.Status.active
    cs.creatures_x[new_index] = cs.creatures_x[parent_index]
    cs.creatures_y[new_index] = cs.creatures_y[parent_index]

    -- Avoid overlap among new creatures.
    offset = offset or creature_evolution_stages[new_stage].radius * 0.5
    cs.creatures_x[new_index] = cs.creatures_x[new_index] + love.math.random(-offset, offset)
    cs.creatures_y[new_index] = cs.creatures_y[new_index] + love.math.random(-offset, offset)
end

--
--
-- Update Handlers
--
--

--- @param dt number # Actual delta time. Not same as `fixed_dt`.
function update_screenshake(dt)
    local ss = screenshake
    if ss.duration > 0 then
        ss.duration = ss.duration - dt
        if ss.wait <= 0 then
            ss.offset_x = love.math.random(-ss.amount, ss.amount)
            ss.offset_y = love.math.random(-ss.amount, ss.amount)
            ss.wait = 0.05 -- load up default timer countdown
        else               -- prevent fast screenshakes
            ss.wait = ss.wait - dt
        end
    end
end

-- Use dt for position updates, because movement is time-dependent
function update_player_entity(dt)
    local cs = curr_state
    cs.player_vel_x = cs.player_vel_x * config.AIR_RESISTANCE
    cs.player_vel_y = cs.player_vel_y * config.AIR_RESISTANCE
    cs.player_x = (cs.player_x + cs.player_vel_x * dt) % arena_w
    cs.player_y = (cs.player_y + cs.player_vel_y * dt) % arena_h
end

function update_player_entity_projectiles(dt)
    local cs = curr_state
    -- #region Update laser positions.
    for laser_index = 1, #cs.lasers_x do
        if cs.lasers_is_active[laser_index] == common.Status.active then
            cs.lasers_time_left[laser_index] = cs.lasers_time_left[laser_index] - dt
            if cs.lasers_time_left[laser_index] <= 0 then -- Deactivate if animation ends
                cs.lasers_is_active[laser_index] = common.Status.not_active
            else
                local angle = cs.lasers_angle[laser_index]
                cs.lasers_x[laser_index] = cs.lasers_x[laser_index] +
                    math.cos(angle) * config.LASER_PROJECTILE_SPEED * dt
                cs.lasers_y[laser_index] = cs.lasers_y[laser_index] +
                    math.sin(angle) * config.LASER_PROJECTILE_SPEED * dt
                if config.IS_PLAYER_PROJECTILE_WRAP_AROUND_ARENA then
                    cs.lasers_x[laser_index] = cs.lasers_x[laser_index] % arena_w
                    cs.lasers_y[laser_index] = cs.lasers_y[laser_index] % arena_h
                elseif --[[Deactivate if it goes off screen]]
                    cs.lasers_x[laser_index] < 0
                    or cs.lasers_x[laser_index] >= arena_w
                    or cs.lasers_y[laser_index] < 0
                    or cs.lasers_y[laser_index] >= arena_h
                then
                    cs.lasers_is_active[laser_index] = common.Status.not_active
                end
            end
        end
    end
    laser_fire_timer = laser_fire_timer - dt -- Update fire cooldown timer.
    -- #endregion

    -- #region Handle laser collisions.
    local laser_circle = { x = 0, y = 0, radius = 0 } ---@type Circle
    local creature_circle = { x = 0, y = 0, radius = 0 } ---@type Circle
    for laser_index = 1, #cs.lasers_x do
        if not (cs.lasers_is_active[laser_index] == common.Status.active) then
            goto continue_not_is_active_laser
        end
        laser_circle = {
            x = cs.lasers_x[laser_index],
            y = cs.lasers_y[laser_index],
            radius = laser_radius,
        }
        for creature_index = 1, config.TOTAL_CREATURES_CAPACITY do
            if not (cs.creatures_is_active[creature_index] == common.Status.active) then
                goto continue_not_is_active_creature
            end
            local curr_stage_id = cs.creatures_evolution_stage[creature_index]
            assert(curr_stage_id >= 1 and curr_stage_id <= #creature_evolution_stages, curr_stage_id)
            creature_circle = {
                x = cs.creatures_x[creature_index],
                y = cs.creatures_y[creature_index],
                radius = creature_evolution_stages[curr_stage_id].radius,
            }
            if is_intersect_circles { a = creature_circle, b = laser_circle } then
                screenshake.duration = 0.15 -- got'em!
                -- Deactivate projectile if touch creature.
                cs.lasers_is_active[laser_index] = common.Status.not_active
                laser_intersect_creature_counter = laser_intersect_creature_counter + 1
                -- Deactivate current creature stage if touch creature.
                cs.creatures_is_active[creature_index] = common.Status.not_active
                cs.creatures_health[creature_index] = common.HealthTransitions.healing
                -- Split the creature into two smaller ones.
                if curr_stage_id > 1 then
                    local new_stage_id = curr_stage_id - 1 -- note: initial stage is `#creature_evolution_stages`
                    cs.creatures_evolution_stage[creature_index] = new_stage_id
                    for i = 1, 2 do
                        local new_creature_index = find_inactive_creature_index()
                        if new_creature_index then
                            spawn_new_creature(new_creature_index, creature_index, new_stage_id)
                        else
                            if config.debug.is_trace_entities then
                                -- print('Failed to spawn more creatures.\n', 'curr_stage_id:', curr_stage_id, 'i:', i)
                            end
                            break -- Yeet outta this loop if we can't spawn anymore.
                        end
                    end
                end
                break -- This projectile has served it's purpose.
            end
            ::continue_not_is_active_creature::
        end
        ::continue_not_is_active_laser::
    end
    -- #endregion
end

function update_creatures(dt)
    -- FIXME: HOW TO FIX THIS ANOMALY?
    local weird_alpha = dt_accum * config.FIXED_DT -- SHOULD BE FIXED_DT_INV

    local cs = curr_state

    local player_circle = { x = cs.player_x, y = cs.player_y, radius = player_radius } ---@type Circle
    local creature_circle = { x = 0, y = 0, radius = 0 } ---@type Circle # hope for cache-locality
    for i = 1, config.TOTAL_CREATURES_CAPACITY do
        if config.debug.is_test then
            if cs.creatures_health[i] == common.HealthTransitions.healthy then
                assert(cs.creatures_is_active[i] == common.Status.not_active)
            end
        end
        if not (cs.creatures_is_active[i] == common.Status.active) then
            local health = cs.creatures_health[i]
            if health >= common.HealthTransitions.healing and health < common.HealthTransitions.healthy then
                cs.creatures_health[i] = health + dt           -- increament counter
            end
            if health >= common.HealthTransitions.healthy then -- Creature rescued. The End.
                cs.creatures_health[i] = common.HealthTransitions
                    .none                                      -- note: using dt will make it feel too linear
            end
            goto continue
        end

        -- Update active creature
        if config.IS_CREATURE_FOLLOW_PLAYER then
            simulate.simulate_creature_follows_player(dt, i)
        end
        local creature_stage_id = cs.creatures_evolution_stage[i] --- @type integer
        if config.debug.is_test then
            assert(creature_stage_id >= 1 and creature_stage_id <= #creature_evolution_stages)
        end
        local stage = creature_evolution_stages[creature_stage_id] --- @type Stage
        local angle = cs.creatures_angle[i]                        --- @type number
        local speed_x = lerp(stage.speed, cs.creatures_vel_x[i], weird_alpha)
        local speed_y = lerp(stage.speed, cs.creatures_vel_y[i], weird_alpha)
        local x = (cs.creatures_x[i] + math.cos(angle) * speed_x * dt) % arena_w --- @type number
        local y = (cs.creatures_y[i] + math.sin(angle) * speed_y * dt) % arena_h --- @type number
        cs.creatures_x[i] = x
        cs.creatures_y[i] = y

        -- Check for game over (player lost).
        creature_circle = { x = x, y = y, radius = stage.radius }
        if is_intersect_circles { a = player_circle, b = creature_circle } then -- defeat
            sound_interference:play()

            screenshake.duration = 0.15
            if not config.IS_PLAYER_INVULNERABLE then -- HACK while prototyping... can slow player down though???
                reset_game()
                return
            end
        end
        ::continue::
    end

    -- PLAYER WON
    if count_active_creatures() == 0 then -- victory
        pcall(assert,
            config.EXPECTED_FINAL_HEALED_CREATURE_COUNT == laser_intersect_creature_counter,
            config.EXPECTED_FINAL_HEALED_CREATURE_COUNT .. ' , ' .. laser_intersect_creature_counter
        )

        sound_upgrade:play()
        reset_game()
        return
    end
end

--
--
-- Drawing Renderer
--
--

function draw_player(alpha)
    local juice_frequency = 1 + math.sin(config.FIXED_FPS * game_timer_dt)
    local juice_frequency_damper = lerp(0.0625, 0.125, alpha)

    -- Draw player player
    local player_angle = lerp(prev_state.player_rot_angle, curr_state.player_rot_angle, alpha)
    local player_x = lerp(prev_state.player_x, curr_state.player_x, alpha)
    local player_y = lerp(prev_state.player_y, curr_state.player_y, alpha)

    local is_interpolate_player = true
    if is_interpolate_player then
        local player_speed_x =
            lerp(prev_state.player_vel_x, curr_state.player_vel_x * config.AIR_RESISTANCE, alpha)
        local player_speed_y =
            lerp(prev_state.player_vel_y, curr_state.player_vel_y * config.AIR_RESISTANCE, alpha)
        player_x = (player_x + player_speed_x * game_timer_dt) % arena_w
        player_y = (player_y + player_speed_y * game_timer_dt) % arena_h
        LG.setColor(common.Color.player_entity_firing_edge_darker)
        LG.circle('fill', player_x, player_y, player_radius)
    end

    -- Draw player inner iris * (iris)
    local player_iris_radius = (player_radius * config.PLAYER_CIRCLE_IRIS_TO_EYE_RATIO)
        * (1 + juice_frequency * juice_frequency_damper)
    LG.setColor(common.Color.player_entity)
    LG.circle('fill', player_x, player_y, player_iris_radius)

    -- Draw player player firing trigger • (circle)
    local player_trigger_radius = lerp(player_firing_edge_max_radius - 4, player_firing_edge_max_radius - 3,
        alpha)
    local player_edge_x = player_x + math.cos(player_angle) * player_firing_edge_max_radius
    local player_edge_y = player_y + math.sin(player_angle) * player_firing_edge_max_radius
    do -- @juice ─ simulate the twinkle in eye to go opposite to player's direction
        local inertia_x = 0
        local inertia_y = 0
        if love.keyboard.isDown('up', 'w') then
            inertia_x = curr_state.player_vel_x
                + math.cos(curr_state.player_rot_angle) * config.PLAYER_ACCELERATION * game_timer_dt
            inertia_y = curr_state.player_vel_y
                + math.sin(curr_state.player_rot_angle) * config.PLAYER_ACCELERATION * game_timer_dt
        end
        if love.keyboard.isDown('down', 's') then
            inertia_x = curr_state.player_vel_x
                - math.cos(curr_state.player_rot_angle) * config.PLAYER_ACCELERATION * game_timer_dt
            inertia_y = curr_state.player_vel_y
                - math.sin(curr_state.player_rot_angle) * config.PLAYER_ACCELERATION * game_timer_dt
        end
        inertia_x = curr_state.player_vel_x * config.AIR_RESISTANCE
        inertia_y = curr_state.player_vel_y * config.AIR_RESISTANCE
        player_edge_x = player_edge_x
            - (0.328 * player_firing_edge_max_radius) * (inertia_x * game_timer_dt)
        player_edge_y = player_edge_y
            - (0.328 * player_firing_edge_max_radius) * (inertia_y * game_timer_dt)
    end

    LG.setColor(common.Color.player_entity_firing_edge_dark)
    LG.circle('fill', player_edge_x, player_edge_y, player_trigger_radius)
end

function draw_projectiles(alpha)
    -- Draw player player fired projectiles
    LG.setColor(common.Color.player_entity_firing_projectile)
    for i = 1, #curr_state.lasers_x do
        if curr_state.lasers_is_active[i] == common.Status.active then
            local pos_x = curr_state.lasers_x[i]
            local pos_y = curr_state.lasers_y[i]
            if prev_state.lasers_is_active[i] == common.Status.active then
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

function draw_creatures(alpha)
    for i = 1, #curr_state.creatures_x do
        local evolution_stage = creature_evolution_stages[curr_state.creatures_evolution_stage[i]] --- @type Stage

        if curr_state.creatures_is_active[i] == common.Status.active then
            local curr_x = curr_state.creatures_x[i]
            local curr_y = curr_state.creatures_y[i]
            local creature_radius = evolution_stage.radius --- @type integer

            -- Draw swarm behavior glitch circumference effect (blur-haze) on this creature.
            if config.IS_CREATURE_SWARM_ENABLED then -- note: better to use a wave shader for ripples
                local tolerance = evolution_stage.speed
                if math.abs(curr_state.creatures_vel_x[i] - prev_state.creatures_vel_x[i]) >= tolerance then
                    LG.setColor(common.Color.creature_infected_rgba)
                    local segments = lerp(18, 6, alpha) -- for an eeerie hexagonal sharp edges effect
                    local segment_distortion_amplitude = 2
                    local segment_distortion = (segments * math.sin(segments) * 0.03) * segment_distortion_amplitude
                    -- FIXME: swarm range ─ should be evolution_stage.radius specific
                    local distorting_radius =
                        lerp(creature_radius - 1, creature_radius + 1 + segment_distortion, alpha)
                    LG.circle('line', curr_x, curr_y, distorting_radius, segments)
                    LG.setColor(common.Color.creature_infected) --- HACK: RESET leaking color to post-processing shader
                end
            end

            -- Draw this creature.
            LG.setColor(common.Color.creature_infected)
            LG.circle('fill', curr_x, curr_y, evolution_stage.radius)
        else
            local curr_x = curr_state.creatures_x[i]
            local curr_y = curr_state.creatures_y[i]
            local is_not_moving = prev_state.creatures_x[i] ~= curr_x and prev_state.creatures_y[i] ~= curr_y
            local corner_offset = player_radius + evolution_stage.radius
            local is_away_from_corner = (
                curr_x >= 0 + corner_offset
                and curr_x <= arena_w - corner_offset
                and curr_y >= 0 + corner_offset
                and curr_y <= arena_h - corner_offset
            )
            -- Automatically disappear when the `find_inactive_creature_index`
            -- looks them up and then `spawn_new_creature` mutates them.
            if is_away_from_corner or is_not_moving then
                local health = curr_state.creatures_health[i]
                local is_healing = curr_state.creatures_is_active[i] == common.Status.not_active and
                    health > common.HealthTransitions.healing and
                    health <= common.HealthTransitions.healthy
                if is_healing then
                    LG.setColor(common.Color.creature_healed)
                    LG.circle('fill', curr_x, curr_y, evolution_stage.radius)

                    -- Draw final creature evolution on successful healing.
                    if alpha < config.PHI_INV then
                        local juice_frequency = 1 + math.sin(config.FIXED_FPS * game_timer_dt)
                        local juice_frequency_damper = lerp(0.0625, 0.125, alpha)
                        local radius_factor = (1 + alpha * juice_frequency * lerp(1, juice_frequency_damper, alpha))
                        local radius = evolution_stage.radius * radius_factor
                        LG.setColor(common.Color.creature_healing)
                        LG.circle('fill', curr_x, curr_y, radius)

                        -- Draw `+` icon indicating score increment.
                        LG.setColor(1, 1, 1)
                        for dy = -1, 1 do
                            for dx = -1, 1 do
                                draw_plus_icon(curr_x + dx, curr_y + dy, radius)
                            end
                        end
                    end
                end
            end
        end
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

function draw_hud()
    local hud_h = 128
    local hud_w = 128
    local pad_x = 8 -- horizontal
    local pad_y = 8 -- vertical
    local pos_x = arena_w - hud_w
    local pos_y = 0

    local cs = curr_state

    local active_counter = 0
    for _, value in ipairs(cs.creatures_is_active) do
        if value == common.Status.active then
            active_counter = active_counter + 1
        end
    end
    local fps = love.timer.getFPS()
    LG.setColor(common.Color.text_darkest)
    LG.print(
        table.concat({
            laser_intersect_creature_counter .. ' Score',
            active_counter .. ' Left',
            '',
            fps .. ' fps',
            string.format('%.4s', game_timer_t) .. ' elapsed',
        }, '\n'),
        1 * pos_x,
        1 * pos_y
    )
    -- HACK: To avoid leaking debug hud text color into post-processing shader.
    LG.setColor(1, 1, 1)
end

function draw_debug_hud()
    local pad_x = 8
    local pad_y = 8
    local pos_x = 0
    local pos_y = 0
    LG.setColor(0, 0, 0, 0.7)
    LG.rectangle('fill', pos_x, pos_y, 222, arena_h)

    local stats = LG.getStats()
    local fps = love.timer.getFPS()
    local dt = love.timer.getDelta()

    local cs = curr_state

    local active_counter = 0
    for _, value in ipairs(cs.creatures_is_active) do
        if value == common.Status.active then
            active_counter = active_counter + 1
        end
    end

    LG.setColor(common.Color.text_debug_hud)
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
        cs.player_vel_x = cs.player_vel_x + math.cos(cs.player_rot_angle) * config.PLAYER_ACCELERATION * dt
        cs.player_vel_y = cs.player_vel_y + math.sin(cs.player_rot_angle) * config.PLAYER_ACCELERATION * dt
    end
    local is_reverse_enabled = true
    if is_reverse_enabled then
        local reverse_acceleration_factor = 0.9
        local reverese_acceleration = config.PLAYER_ACCELERATION * reverse_acceleration_factor
        if love.keyboard.isDown('down', 's') then
            cs.player_vel_x = cs.player_vel_x - math.cos(cs.player_rot_angle) * reverese_acceleration * dt
            cs.player_vel_y = cs.player_vel_y - math.sin(cs.player_rot_angle) * reverese_acceleration * dt
        end
    end

    if love.keyboard.isDown 'space' then
        fire_player_projectile()
    end

    if love.keyboard.isDown 'x' then
        dash_player_entity(dt)
    end

    if love.keyboard.isDown('lshift', 'rshift') then --- enhance attributes while spinning like a top
        player_turn_speed = config.DEFAULT_PLAYER_TURN_SPEED * PHI
        if love.math.random() < 0.05 then
            laser_fire_timer = 0
        else
            laser_fire_timer = game_timer_dt
        end
    else
        player_turn_speed = config.DEFAULT_PLAYER_TURN_SPEED
    end
end

function update_game(dt) ---@param dt number # Fixed delta time.
    handle_player_input(dt)
    update_player_entity(dt)
    update_player_entity_projectiles(dt)
    simulate.simulate_creatures_swarm_behavior(dt)
    update_creatures(dt)
end

function draw_game(alpha)
    draw_player(alpha)
    draw_projectiles(alpha)
    draw_creatures(alpha)
end

--
--
-- LOVE - [Open in Browser](https://love2d.org/wiki/love)
--
--

function love.load()
    LG.setDefaultFilter('linear', 'linear')                                                                    -- smooth edges

    do                                                                                                         -- Music time
        sound_guns_turn_off = love.audio.newSource('resources/audio/sfx/machines_guns_turn_off.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io
        sound_upgrade = love.audio.newSource('resources/audio/sfx/statistics_upgrade.wav', 'static')           -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
        sound_interference = love.audio.newSource('resources/audio/sfx/machines_interference.wav', 'static')   -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds

        sound_pickup = love.audio.newSource('resources/audio/sfx/pickup_holy.wav', 'static')                   --stream and loop background music
        sound_pickup:setVolume(0.9)                                                                            -- 90% of ordinary volume
        sound_pickup:setPitch(0.5)                                                                             -- one octave lower
        sound_pickup:setVolume(0.7)
        sound_pickup:play()                                                                                    -- PLAY AT GAME START once

        -- Credits:
        --   Lupus Nocte: http://link.epidemicsound.com/LUPUS
        --   YouTube link: https://youtu.be/NwyDMDlZrMg?si=oaFxm0LHqGCiUGEC
        music_bgm = love.audio.newSource('resources/audio/music/lupus_nocte_arcadewave.mp3', 'stream') --stream and loop background music
        music_bgm:setVolume(0.9)
        music_bgm:setPitch(1.11)                                                                       -- one octave lower
        music_bgm:setVolume(0.5)
        --music_bgm:play()

        -- Master volume
        love.audio.setVolume(0.9) --volume # number # 1.0 is max and 0.0 is off.
    end

    dt_accum = 0.0 --- Accumulator keeps track of time passed between frames.
    arena_h = gh
    arena_w = gw
    laser_radius = 5
    player_radius = 32

    player_firing_edge_max_radius = math.ceil(player_radius * 0.328) --- Trigger distance from center of player.
    creature_swarm_range = player_radius * 4                         -- FIXME: should be evolution_stage.radius specific

    local fx = moonshine.effects
    shaders = { --- @type Shader
        post_processing = moonshine(arena_w, arena_h, fx.colorgradesimple)
            .chain(fx.chromasep)
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
        shaders.post_processing.vignette.color = common.Color.background
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
        amount = 5 * 0.5 * config.PHI_INV,
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
            { speed = 70 * speed_multiplier,  radius = math.ceil(30 * creature_scale) },
            { speed = 50 * speed_multiplier,  radius = math.ceil(50 * creature_scale) },
            { speed = 20 * speed_multiplier,  radius = math.ceil(80 * creature_scale) },
        }
        do -- Test `creature_evolution_stages`.
            local max_creature_mutation_count = 0
            for i = 1, #creature_evolution_stages do
                max_creature_mutation_count = max_creature_mutation_count + i
            end
            assert(
                max_creature_mutation_count == 10,
                'Assert 1 creature (ancestor) »»mutates»» into ten creatures including itself.'
            )
        end
    end

    function reset_game()
        laser_intersect_creature_counter = 0 -- count creatures collision with laser... coin like
        game_timer_dt = 0.0
        game_timer_t = 0.0
        is_debug_hud_enabled = false --- Toggled by keys event.
        laser_fire_timer = 0
        laser_index = 1              -- circular buffer index
        player_fire_cooldown_timer = 0
        player_turn_speed = config.DEFAULT_PLAYER_TURN_SPEED

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

        for i = 1, config.MAX_LASER_CAPACITY do
            curr_state.lasers_angle[i] = 0
            curr_state.lasers_is_active[i] = common.Status.not_active
            curr_state.lasers_time_left[i] = config.LASER_FIRE_TIMER_LIMIT
            curr_state.lasers_x[i] = 0
            curr_state.lasers_y[i] = 0
        end
        laser_index = 1 -- reset circular buffer index

        -- Test me:
        -- curr_state.creatures_x = { 100, arena_w - 100, arena_w / 2 }
        -- curr_state.creatures_y = { 100, 100, arena_h - 10 }

        local largest_creature_stage = #creature_evolution_stages
        for i = 1, config.TOTAL_CREATURES_CAPACITY do -- Pre-allocate all creature's including stage combinations
            curr_state.creatures_angle[i] = 0
            curr_state.creatures_evolution_stage[i] = largest_creature_stage
            curr_state.creatures_health[i] = 0 -- default 0 value
            curr_state.creatures_is_active[i] = common.Status.not_active
            curr_state.creatures_x[i] = 0
            curr_state.creatures_y[i] = 0
            curr_state.creatures_vel_x[i] = 0
            curr_state.creatures_vel_y[i] = 0
        end

        for i = 1, config.INITIAL_LARGE_CREATURES do                         -- Activate initial creatures.
            curr_state.creatures_angle[i] = love.math.random() * (2 * math.pi)
            curr_state.creatures_evolution_stage[i] = largest_creature_stage -- Start at smallest stage
            curr_state.creatures_health[i] = -1                              -- -1 to 0 to 1.... like dash timer, or fade timer ( -1 to 0 to 1 )
            curr_state.creatures_is_active[i] = common.Status.active
            curr_state.creatures_vel_x[i] = 0
            curr_state.creatures_vel_y[i] = 0
            curr_state.creatures_x[i] = 0
            curr_state.creatures_y[i] = 0
        end

        copy_game_state(prev_state, curr_state)
        sync_prev_state()
        if config.debug.is_test then
            assert_consistent_state()
        end
    end

    reset_game()
    LG.setBackgroundColor(common.Color.background)
end

function love.update(dt)
    if not music_bgm:isPlaying() then
        love.audio.play(music_bgm)
    end
    -- NOTE: love.audio is to be overriden by audio.lua, else this panics.
    -- love.audio.update()
    -----fade_start_time = fade_start_time + dt
    -----if fade_start_time > total_fade_duration then fade_start_time = total_fade_duration end

    game_timer_t = game_timer_t + dt
    game_timer_dt = dt -- note: for easy global reference

    --#region Frame Rate Independence.
    dt_accum = dt_accum + dt
    while dt_accum >= config.FIXED_DT do
        sync_prev_state()
        update_game(config.FIXED_DT)
        dt_accum = dt_accum - config.FIXED_DT
    end
    --#endregion

    update_screenshake(dt)
end

function love.draw()
    local alpha = dt_accum * config.FIXED_DT_INV --- @type number

    if config.debug.is_test then
        assert_consistent_state()
    end

    shaders.post_processing(function()
        -- #region ORIGIN
        --
        -- Objects that are partially off the edge of the screen can be seen on the other side.
        -- Coordinate system is translated to different positions and everything is drawn at each position around the screen and in the center.
        for y = -1, 1 do -- Draw off-screen object partially wrap around without glitch
            for x = -1, 1 do
                LG.origin()
                LG.translate(x * arena_w, y * arena_h)

                if screenshake.duration > 0 then                             -- vfx
                    LG.setColor { 1, 1, 1, common.ScreenFlashAlphaLevel.low }
                    LG.rectangle('fill', 0, 0, arena_w, arena_h)             -- Simulate screenflash (TODO: Make it optional, and sensory warning perhaps?)
                    LG.translate(screenshake.offset_x, screenshake.offset_y) -- Simulate screenshake
                end

                draw_game(alpha)
            end
        end

        -- Reverse any previous calls to love.graphics.
        LG.origin()
        --
        -- #endregion ORIGIN
    end)

    draw_hud()
    if is_debug_hud_enabled then
        draw_debug_hud()
    end
end

function love.keypressed(key, _, _)
    if key == common.ControlKey.escape_key or key == common.ControlKey.force_quit_game then
        love.event.push 'quit'
    elseif key == common.ControlKey.toggle_hud then
        is_debug_hud_enabled = not is_debug_hud_enabled
    end
end

function love.keyreleased(key)
    if key == 'space' then
        sound_guns_turn_off:play()
    end
end

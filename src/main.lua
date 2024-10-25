---@diagnostic disable: lowercase-global, undefined-global, duplicate-set-field
--[[

Ludum Dare 56: Tiny Creatures
    See https://ldjam.com/events/ludum-dare/56/$403597

Starter setup ported initially from https://berbasoft.com/simplegametutorials/love/asteroids/

Development
    $ find -name '*.lua' | entr -crs 'date; love .; echo exit status $?'

--]]
local moonshine = require 'lib.moonshine'

local Timer = require 'timer' --- @type Timer
local common = require 'common'
local config = require 'config'
local lume = require 'lume'
local simulate = require 'simulate'

local LG = love.graphics

local PHI, PHI_INV = config.PHI, config.PHI_INV

-- local lerp = common.lerp
-- local smoothstep = common.lerper['smoothstep']
local lerp = lume.lerp
local smoothstep = lume.smooth

--- MOVE THIS TO CONFIG.LUA
--- NOTE: This is used by `game_level` to mutate `initial_large_creatures` these are mutated after
---       each level::: i can't bother changing case as of now... will do when time permits??

--- Public API shader graphics config.
--- @class GraphicsConfig
--- @field bloom_intensity { enable: boolean, amount: number }
--- @field chromatic_abberation {enable:boolean, mode: 'minimal'|'default'|'advanced'}
--- @field curved_monitor {enable:boolean, amount:number}
--- @field filmgrain {enable:boolean, amount:number}
--- @field lens_dirt {enable:boolean}
--- @field scanlines {enable:boolean, mode:'grid'|'horizontal'}
local graphics_config = {
        bloom_intensity = { enable = true, amount = 0.05 }, --- For `fx.glow`.
        chromatic_abberation = { enable = true, mode = 'minimal' },
        curved_monitor = { enable = not true, amount = PHI },
        filmgrain = { enable = not true, amount = PHI_INV },
        lens_dirt = { enable = not true }, --- unimplemented
        scanlines = { enable = not true, mode = 'horizontal' }, -- NOTE: ENABLED FOR BG SHADER---PERHAPS HAVE MORE OPTIONS TO PICK FOR post_processing and background_shader????
}

-- Copied from [SkyVaultGames ─ Love2D | Shader Tutorial 1 | Introduction](https://www.youtube.com/watch?v=DOyJemh_7HE&t=1s)

-- `vec2 uvs` is for LOVE quads
local glsl_gradient_shader_code = [[
extern vec2 screen;

vec4 effect(vec4 color, Image image, vec2 uvs, vec2 screen_coords) {
        vec4 pixel = Texel(image, uvs);
        vec2 sc = vec2(screen_coords.x / screen.x, screen_coords.y / screen.y);
        //return vec4(sc, 1.0, 1.0) * pixel; // default
        return vec4(1.0, sc[0], sc[1], 1.0) * pixel; // redpinkyello
        //return vec4(sc[0],sc[1], 1.0, 1.0) * pixel; // blueishpink
        //return vec4(sc[0], 1.0, sc[1], 1.0) * pixel; // greenishyellow
        //return vec4(sc[0]+0.3, 0.4, sc[1]+0.2, 1.0) * pixel; // purple yellowish
}
]]


function test_timer_basic_usage()
        local isInvincible = true -- grant the player 5 seconds of invulnerability
        Timer.after(5, function()
                print('isInvincible', isInvincible)
                isInvincible = not true
                print('isInvincible', isInvincible)
        end)

        Timer.after(1, function(func) -- print "foo" every second
                print 'foo'
                Timer.after(1, func) -- reschedule the timer to run after a second
        end)
end

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
--- @field player_health number # 0|3
--- @field player_invulnerability_timer number # 0.0|1.0
--- @field player_rot_angle number # 0
--- @field player_vel_x number # 0
--- @field player_vel_y number # 0
--- @field player_x number # 0|400
--- @field player_y number # 0|300

--- @class Shader
--- @field background_shader table
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

        assert(ps.player_health >= 0)
        assert(cs.player_health >= 0)
end

function sync_prev_state()
        local cs = curr_state
        local ps = prev_state

        ps.player_rot_angle = cs.player_rot_angle
        ps.player_vel_x = cs.player_vel_x
        ps.player_vel_y = cs.player_vel_y
        ps.player_x = cs.player_x
        ps.player_y = cs.player_y
        ps.player_health = cs.player_health

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

--- @enum COLLISION_TOLERANCE
local COLLISION_TOLERANCE = {
        OUTER_50 = 1.5,
        OUTER_40 = 1.4,
        OUTER_30 = 1.3,
        OUTER_20 = 1.2,
        OUTER_10 = 1.1,
        EXACT = 1.0,
        INNER_10 = 0.9,
        INNER_20 = 0.8,
        INNER_30 = 0.7,
        INNER_40 = 0.6,
        INNER_50 = 0.5,
        INNER_60 = 0.4,
        INNER_70 = 0.3,
}

--- tolerance = 1.0: exact check (original behavior)
--- tolerance > 1.0: more forgiving (e.g., 1.1 gives 10% more leeway)
--- tolerance < 1.0: stricter check (e.g., 0.9 requires 10% more overlap)
--- @type fun(opts: { a: Circle, b: Circle, tolerance_factor: number|COLLISION_TOLERANCE } ): boolean
local function is_intersect_circles_tolerant(opts)
        if config.debug.is_assert then assert(opts.tolerance_factor >= 0.0 and opts.tolerance_factor <= 2.0) end
        local dx = (opts.a.x - opts.b.x)
        local dy = (opts.a.y - opts.b.y)
        local ab_dist = opts.a.radius + opts.b.radius

        local lhs = dx * dx + dy * dy
        local rhs = ab_dist * ab_dist
        return (lhs <= rhs * opts.tolerance_factor)
end

--- @return integer|nil
--- @nodiscard
function find_inactive_creature_index()
        for i = 1, config.TOTAL_CREATURES_CAPACITY do
                if curr_state.creatures_is_active[i] == common.Status.not_active then return i end
        end

        return nil
end

function find_inactive_creature_index_except(index)
        for i = 1, config.TOTAL_CREATURES_CAPACITY do
                if curr_state.creatures_is_active[i] == common.Status.not_active and i ~= index then return i end
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
                if curr_state.creatures_is_active[i] == common.Status.active then counter = counter + 1 end
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

        if cs.creatures_is_active[new_index] == common.Status.active then error 'expected to not be active' end

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

function fire_player_projectile() --- Fire projectile from players's position.
        if laser_fire_timer <= 0 then
                local cs = curr_state
                cs.lasers_angle[laser_index] = cs.player_rot_angle
                cs.lasers_is_active[laser_index] = common.Status.active
                cs.lasers_time_left[laser_index] = 4
                cs.lasers_x[laser_index] = cs.player_x + math.cos(cs.player_rot_angle) * config.PLAYER_RADIUS
                cs.lasers_y[laser_index] = cs.player_y + math.sin(cs.player_rot_angle) * config.PLAYER_RADIUS
                laser_index = (laser_index % config.MAX_LASER_CAPACITY) + 1 -- Laser_index tracks circular reusable buffer.
                laser_fire_timer = config.LASER_FIRE_TIMER_LIMIT -- Reset timer to default.
                sound_fire_projectile:play() -- Unconventional but works without distraction.
        end
end

local MAX_SPEED_BOOST_MULTIPLIER = 1.05 -- PHI
local IS_SMOOTH_BOOST = true
--- TODO: Use dash timer for Renderer to react to it, else use key event to detect dash (hack).
function boost_player_entity_speed(dt)
        local cs = curr_state
        local prev_vel_x = cs.player_vel_x
        local prev_vel_y = cs.player_vel_y
        --
        -- local alpha = dt_accum * config.FIXED_DT_INV --- @type number
        -- local juice_frequency = 1 + math.sin(config.FIXED_FPS * game_timer_dt)
        -- local juice_frequency_damper = lerp(0.0625, 0.125, alpha)
        -- local ease = 1 - juice_frequency * juice_frequency_damper
        local ease = PHI_INV
        -- can use lerp here for smooth speed easing
        if IS_SMOOTH_BOOST then
                cs.player_vel_x = smoothstep(prev_vel_x, prev_vel_x * MAX_SPEED_BOOST_MULTIPLIER, ease)
                -- cs.player_vel_x = math.min(cs.player_vel_x * config.AIR_RESISTANCE ^ 2, prev_vel_x * config.AIR_RESISTANCE ^ 2)

                cs.player_vel_y = smoothstep(prev_vel_y, prev_vel_y * MAX_SPEED_BOOST_MULTIPLIER, ease)
                -- cs.player_vel_y = math.min(cs.player_vel_y * config.AIR_RESISTANCE ^ 2, prev_vel_y * config.AIR_RESISTANCE ^ 2)
        else
                cs.player_vel_x = cs.player_vel_x * MAX_SPEED_BOOST_MULTIPLIER
                cs.player_vel_y = cs.player_vel_y * MAX_SPEED_BOOST_MULTIPLIER
        end
        update_player_position_this_frame(dt) -- remember to update once
        -- By default the value is set to 0 which means that air absorption effects
        -- are disabled. A value of 1 will apply high frequency attenuation to the
        -- Source at a rate of 0.05 dB per meter.
        if IS_SMOOTH_BOOST then
                cs.player_vel_x = smoothstep(cs.player_vel_x, cs.player_vel_x * config.AIR_RESISTANCE, ease)
                cs.player_vel_y = smoothstep(cs.player_vel_y, cs.player_vel_y * config.AIR_RESISTANCE, ease)
        else
                cs.player_vel_x = prev_vel_x
                cs.player_vel_y = prev_vel_y
        end
end

--- @enum PlayerDamageStatus
local PlayerDamageStatus = {
        DEAD = 'dead',
        DAMAGED = 'damaged',
        INVULNERABLE = 'invulnerable',
}

--- Mutates `player_invulnerability_timer`. Returns player damage state.
--- @param damage integer? # Defaults to `1`.
--- @return PlayerDamageStatus
--- @nodiscard
local function damage_player_fetch_status(damage)
        local cs = curr_state
        if config.IS_PLAYER_INVULNERABLE or cs.player_invulnerability_timer > 0 then return PlayerDamageStatus.INVULNERABLE end
        cs.player_health = cs.player_health - (damage or 1)
        if cs.player_health <= 0 then return PlayerDamageStatus.DEAD end
        cs.player_invulnerability_timer = 1
        return PlayerDamageStatus.DAMAGED
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
                else -- prevent fast screenshakes
                        ss.wait = ss.wait - dt
                end
        end
end

function update_player_vulnerability_timer_this_frame(dt)
        local cs = curr_state
        if cs.player_invulnerability_timer > 0 then
                cs.player_invulnerability_timer = cs.player_invulnerability_timer - dt
                if cs.player_invulnerability_timer <= 0 then cs.player_invulnerability_timer = 0 end
        end
end

-- TODO: update trails, in update_player_position_this_frame
-- TODO: Add a `laser_fire_timer` and `LASER_FIRE_TIMER_LIMIT` like constraints for this trail

-- Use dt for position updates, because movement is time-dependent
function update_player_position_this_frame(dt)
        local cs = curr_state
        cs.player_vel_x = cs.player_vel_x * config.AIR_RESISTANCE
        cs.player_vel_y = cs.player_vel_y * config.AIR_RESISTANCE
        cs.player_x = (cs.player_x + cs.player_vel_x * dt) % arena_w
        cs.player_y = (cs.player_y + cs.player_vel_y * dt) % arena_h
end

---@diagnostic disable-next-line: unused-local
function update_player_trails_this_frame(dt)
        local cs = curr_state
        player_trails_x[player_trails_index] = cs.player_x
        player_trails_y[player_trails_index] = cs.player_y
        player_trails_vel_x[player_trails_index] = cs.player_vel_x
        player_trails_vel_y[player_trails_index] = cs.player_vel_y
        player_trails_rot_angle[player_trails_index] = cs.player_rot_angle
        player_trails_index = (player_trails_index % config.MAX_PLAYER_TRAIL_COUNT) + 1
end

function update_player_fired_projectiles_this_frame(dt)
        local cs = curr_state

        -- #region Update laser positions.
        for laser_index = 1, #cs.lasers_x do
                if cs.lasers_is_active[laser_index] == common.Status.active then
                        cs.lasers_time_left[laser_index] = cs.lasers_time_left[laser_index] - dt
                        if cs.lasers_time_left[laser_index] <= 0 then -- Deactivate if animation ends
                                cs.lasers_is_active[laser_index] = common.Status.not_active
                        else
                                local angle = cs.lasers_angle[laser_index]
                                cs.lasers_x[laser_index] = cs.lasers_x[laser_index] + math.cos(angle) * config.LASER_PROJECTILE_SPEED * dt
                                cs.lasers_y[laser_index] = cs.lasers_y[laser_index] + math.sin(angle) * config.LASER_PROJECTILE_SPEED * dt
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

        -- Update fire cooldown timer.
        laser_fire_timer = laser_fire_timer - dt
        -- #endregion

        -- #region Handle laser collisions.
        local laser_circle = { x = 0, y = 0, radius = 0 } --- @type Circle

        local creature_circle = { x = 0, y = 0, radius = 0 } --- @type Circle
        local stages = creature_evolution_stages --- @type Stage[]
        local temp_hit_counter_this_frame = 0 --- @type integer Count hits for double hit sfx.
        for laser_index = 1, #cs.lasers_x do
                if not (cs.lasers_is_active[laser_index] == common.Status.active) then --[[]]
                        goto continue_not_is_active_laser
                end
                laser_circle = { x = cs.lasers_x[laser_index], y = cs.lasers_y[laser_index], radius = config.LASER_RADIUS }
                for creature_index = 1, config.TOTAL_CREATURES_CAPACITY do
                        if not (cs.creatures_is_active[creature_index] == common.Status.active) then --[[]]
                                goto continue_not_is_active_creature
                        end
                        local curr_stage_id = cs.creatures_evolution_stage[creature_index] --- @type integer
                        if config.debug.is_assert then assert(curr_stage_id >= 1 and curr_stage_id <= #stages, curr_stage_id) end
                        creature_circle = {
                                x = cs.creatures_x[creature_index],
                                y = cs.creatures_y[creature_index],
                                radius = stages[curr_stage_id].radius,
                        }
                        if is_intersect_circles { a = creature_circle, b = laser_circle } then
                                temp_hit_counter_this_frame = temp_hit_counter_this_frame + 1
                                screenshake.duration = 0.15 -- got'em!

                                -- Deactivate projectile if touch creature.
                                cs.lasers_is_active[laser_index] = common.Status.not_active
                                laser_intersect_creature_counter = laser_intersect_creature_counter + 1

                                if curr_stage_id == 1 then
                                        laser_intersect_final_creature_counter = laser_intersect_final_creature_counter + 1
                                        local choices = { sound_creature_healed_1, sound_creature_healed_2 }
                                        local choice_index = love.math.random(1, #choices)
                                        choices[choice_index]:play()
                                end

                                -- Deactivate current creature stage if touch creature.
                                cs.creatures_is_active[creature_index] = common.Status.not_active
                                cs.creatures_health[creature_index] = common.HealthTransitions.healing

                                -- Split the creature into two smaller ones.
                                if curr_stage_id > 1 then
                                        -- Note: initial stage is `#creature_evolution_stages`.
                                        local new_stage_id = curr_stage_id - 1
                                        cs.creatures_evolution_stage[creature_index] = new_stage_id
                                        for i = 1, 2 do
                                                local new_creature_index = find_inactive_creature_index()
                                                if new_creature_index ~= nil then
                                                        spawn_new_creature(new_creature_index, creature_index, new_stage_id)
                                                else
                                                        if config.debug.is_trace_entities then
                                                                print('Failed to spawn more creatures.\n', 'stage:', curr_stage_id, 'i:', i)
                                                        end
                                                        break -- Yeet outta this loop if we can't spawn anymore.
                                                end
                                        end
                                end
                                break -- This projectile has now served it's purpose.
                        end
                        ::continue_not_is_active_creature::
                end
                ::continue_not_is_active_laser::
        end

        -- Double hit achievement (seems hacky)
        if temp_hit_counter_this_frame > 1 then
                if temp_hit_counter_this_frame == 2 then
                        -- Placeholder for variation in sound
                        if love.math.random() < 0.5 then
                                sound_fire_combo_hit:play()
                        else
                                sound_fire_combo_hit:play()
                        end
                else
                        sound_fire_combo_hit:play()
                        sound_fire_combo_hit:play()
                end
        end
        -- #endregion
end

function respawn_next_shield()
        if player_shield_collectible_pos_x == nil and player_shield_collectible_pos_y == nil then
                player_shield_collectible_pos_x = love.math.random() * arena_w
                player_shield_collectible_pos_y = love.math.random() * arena_h
        end
end

function update_player_shield_collectible_this_frame(dt)
        local cs = curr_state
        local COLLECTIBLE_SHIELD_RADIUS = config.PLAYER_RADIUS * (1 - PHI_INV) * 3
        if cs.player_health < config.MAX_PLAYER_HEALTH then --
                respawn_next_shield()
        end
        local pos_x = player_shield_collectible_pos_x
        local pos_y = player_shield_collectible_pos_y
        local is_shield_spawned = (pos_x ~= nil and pos_y ~= nil)
        local is_player_increment_shield = is_intersect_circles_tolerant {
                a = { x = cs.player_x, y = cs.player_y, radius = config.PLAYER_RADIUS },
                b = { x = pos_x or 0, y = pos_y or 0, radius = COLLECTIBLE_SHIELD_RADIUS },
                tolerance_factor = COLLISION_TOLERANCE.OUTER_50, -- avoid player to not "miss it by an inch"
        }
        if is_shield_spawned and is_player_increment_shield then
                if cs.player_health < config.MAX_PLAYER_HEALTH then
                        cs.player_health = cs.player_health + 1
                        sound_pickup_shield:play() -- SFX
                end
                if config.debug.is_assert then assert(cs.player_health <= config.MAX_PLAYER_HEALTH) end
                -- Make shield `not is_active`.
                player_shield_collectible_pos_x = nil --- @type number|nil
                player_shield_collectible_pos_y = nil --- @type number|nil
        end
end

function update_creatures_this_frame(dt)
        -- note: better to use a wave shader for ripples
        if config.IS_CREATURE_SWARM_ENABLED then simulate.simulate_creatures_swarm_behavior(dt, config.TOTAL_CREATURES_CAPACITY) end

        local cs = curr_state

        -- FIXME: HOW TO FIX THIS ANOMALY? (SHOULD BE `FIXED_DT_INV`)
        local weird_alpha = dt_accum * config.FIXED_DT

        local player_circle = { x = cs.player_x, y = cs.player_y, radius = config.PLAYER_RADIUS } ---@type Circle
        local creature_circle = { x = 0, y = 0, radius = 0 } ---@type Circle # hope for cache-locality

        local stages = creature_evolution_stages
        for i = 1, config.TOTAL_CREATURES_CAPACITY do
                if config.debug.is_assert and (cs.creatures_health[i] == common.HealthTransitions.healthy) then
                        assert(cs.creatures_is_active[i] == common.Status.not_active)
                end
                if not (cs.creatures_is_active[i] == common.Status.active) then
                        local health = cs.creatures_health[i]
                        local is_slow_heal = true
                        local healing_factor = is_slow_heal and 0.5 or 1
                        if health >= common.HealthTransitions.healing and health < common.HealthTransitions.healthy then
                                health = health + dt * healing_factor -- increament counter
                                cs.creatures_health[i] = health
                        end
                        if health >= common.HealthTransitions.healthy then -- Creature rescued. The End.
                                cs.creatures_health[i] = common.HealthTransitions.none -- note: using dt will make it feel too linear
                        end
                        goto continue
                end

                -- Update active creature
                if config.IS_CREATURE_FOLLOW_PLAYER then --
                        simulate.simulate_creature_follows_player(dt, i)
                end
                local creature_stage_id = cs.creatures_evolution_stage[i] --- @type integer
                if config.debug.is_assert then assert(creature_stage_id >= 1 and creature_stage_id <= #stages) end
                local stage = stages[creature_stage_id] --- @type Stage
                local angle = cs.creatures_angle[i] --- @type number
                local speed_x = lerp(stage.speed, cs.creatures_vel_x[i], weird_alpha)
                local speed_y = lerp(stage.speed, cs.creatures_vel_y[i], weird_alpha)
                local x = (cs.creatures_x[i] + math.cos(angle) * speed_x * dt) % arena_w --- @type number
                local y = (cs.creatures_y[i] + math.sin(angle) * speed_y * dt) % arena_h --- @type number
                cs.creatures_x[i] = x
                cs.creatures_y[i] = y

                -- Player collision with creature.
                creature_circle = { x = x, y = y, radius = stage.radius }
                if is_intersect_circles_tolerant { a = player_circle, b = creature_circle, tolerance_factor = COLLISION_TOLERANCE.INNER_70 } then
                        player_damage_status_actions(damage_player_fetch_status())
                end

                ::continue::
        end

        -- Player won!
        if count_active_creatures() == 0 then
                if config.debug.is_assert then
                        local cond = (config.EXPECTED_FINAL_HEALED_CREATURE_COUNT == laser_intersect_creature_counter)
                        pcall(assert, cond, config.EXPECTED_FINAL_HEALED_CREATURE_COUNT .. ' , ' .. laser_intersect_creature_counter)
                end
                sound_upgrade:play()
                game_level = (game_level % config.MAX_GAME_LEVELS) + 1
                reset_game()
                return
        end
end

--
--
-- Drawing Renderer
--
--

local dst_trail_color = { 0, 0, 0 } --- Initialize zero value
function draw_player_trail(alpha)
        local clr_green = common.Color.player_beserker_modifier
        -- local clr_pink = common.Color.player_dash_pink_modifier
        local clr_yellow = common.Color.player_dash_yellow_modifier
        local invulnerability_timer = curr_state.player_invulnerability_timer
        local is_beserker = love.keyboard.isDown('lshift', 'rshift')
        local is_dash = love.keyboard.isDown 'x'

        -- local damage_freq = 2 * (1 + invulnerability_timer) -- Hz

        if is_beserker and is_dash then
                common.lerp_rbg(dst_trail_color, clr_green, clr_yellow, alpha)
                LG.setColor(dst_trail_color)
        elseif is_beserker then
                LG.setColor(clr_green)
        elseif is_dash then
                LG.setColor(common.Color.player_dash_neonblue_modifier)
        else
                LG.setColor(common.Color.player_entity_firing_projectile)
        end

        local thickness = config.PLAYER_TRAIL_THICKNESS
        local frequency = 440 -- Hz
        local amplitude = 1
        local is_enlarge_tail = true
        for i = config.MAX_PLAYER_TRAIL_COUNT, 1, -1 do -- iter in reverse
                local radius = lerp(thickness, thickness + (amplitude * math.sin(frequency * i)), alpha)
                if config.debug.is_assert then assert(invulnerability_timer <= 1) end
                if invulnerability_timer > 0 then -- tween -> swell or shrink up
                        local radius_tween = ((radius + (is_enlarge_tail and 8 or -8)) - radius) * invulnerability_timer
                        radius = lerp(radius + radius_tween, radius, alpha)
                end
                LG.circle('fill', player_trails_x[i], player_trails_y[i], radius)
        end
end

local RAY_RADIUS = config.PLAYER_RADIUS * (1 - PHI_INV) * 0.5
local RAY_COLOR = { 0.6, 0.6, 0.6, 0.15 }

--- Excellent for predicting visually where player might end up.. like a lookahead (great for dodge!)
function draw_player_direction_ray(alpha)
        local cs = curr_state
        -- LG.setColor(1, 0, 1, 0.18)
        LG.setColor(RAY_COLOR)

        local ray_x = lerp(prev_state.player_x, cs.player_x, alpha)
        local ray_y = lerp(prev_state.player_y, cs.player_y, alpha)

        local ray_vel_x = 0
        local ray_vel_y = 0
        local hack_len_short_factor = 0.5
        ray_vel_x = lerp(prev_state.player_vel_x, cs.player_vel_x * config.AIR_RESISTANCE, alpha)
        ray_vel_y = lerp(prev_state.player_vel_y, cs.player_vel_y * config.AIR_RESISTANCE, alpha)
        ray_vel_x = ray_vel_x * hack_len_short_factor + math.cos(cs.player_rot_angle) * config.PLAYER_ACCELERATION * game_timer_dt
        ray_vel_y = ray_vel_y * hack_len_short_factor + math.sin(cs.player_rot_angle) * config.PLAYER_ACCELERATION * game_timer_dt
        -- #region why are we using this?
        ray_x = (ray_x + ray_vel_x * game_timer_dt) % arena_w
        ray_y = (ray_y + ray_vel_y * game_timer_dt) % arena_h
        -- #endregion

        local is_ray_cast = true
        if is_ray_cast then
                local ease = 1
                ray_x = (ray_x + ray_vel_x * config.AIR_RESISTANCE) % arena_w
                ray_y = (ray_y + ray_vel_y * config.AIR_RESISTANCE) % arena_h
                LG.line(cs.player_x - 1, cs.player_y - 1, ray_x - 1, ray_y - 1)
                LG.line(cs.player_x, cs.player_y, ray_x, ray_y)
                LG.line(cs.player_x + 1, cs.player_y + 1, ray_x + 1, ray_y + 1)
        else -- jump to dot
                local last_ray_radius_if_multiple_rays = 2
                for i = -1, 1, 1 do
                        local ease = (0.125 - (i * 0.0125 * PHI_INV)) -- like the flash of a torch on zz ground
                        ray_x = (ray_x + ray_vel_x * ease) % arena_w
                        ray_y = (ray_y + ray_vel_y * ease) % arena_h
                        local curr_radius = RAY_RADIUS + (ease * math.log(i) * last_ray_radius_if_multiple_rays)
                        LG.circle('fill', ray_x, ray_y, curr_radius)
                end
        end
end

function draw_player(alpha)
        local juice_frequency = 1 + math.sin(config.FIXED_FPS * game_timer_dt)
        local juice_frequency_damper = lerp(0.0625, 0.125, alpha)

        -- Draw player entity.
        local player_angle = lerp(prev_state.player_rot_angle, curr_state.player_rot_angle, alpha)
        local player_x = lerp(prev_state.player_x, curr_state.player_x, alpha)
        local player_y = lerp(prev_state.player_y, curr_state.player_y, alpha)

        local is_interpolate_player = true
        if is_interpolate_player then
                local player_speed_x = lerp(prev_state.player_vel_x, curr_state.player_vel_x * config.AIR_RESISTANCE, alpha)
                local player_speed_y = lerp(prev_state.player_vel_y, curr_state.player_vel_y * config.AIR_RESISTANCE, alpha)
                player_x = (player_x + player_speed_x * game_timer_dt) % arena_w
                player_y = (player_y + player_speed_y * game_timer_dt) % arena_h
                LG.setColor(common.Color.player_entity_firing_edge_darker)
                LG.circle('fill', player_x, player_y, config.PLAYER_RADIUS)
                -- Draw if Last shield
                if (curr_state.player_health == 1) and (love.math.random() < 0.1 * alpha) then
                        local clr = common.Color.creature_healing
                        LG.setColor(clr[1], clr[2], clr[3], lerp(0.2, 0.4, alpha))
                        LG.circle('fill', player_x, player_y, config.PLAYER_RADIUS)
                end
        end

        -- Draw player inner iris * (iris)
        local player_iris_radius = (config.PLAYER_RADIUS * config.PLAYER_CIRCLE_IRIS_TO_EYE_RATIO) * (1 + juice_frequency * juice_frequency_damper)
        if curr_state.player_invulnerability_timer > 0 then -- eye winces and widens
                player_iris_radius = lerp(player_iris_radius, (player_iris_radius * 1.328), curr_state.player_invulnerability_timer * alpha)
        end
        LG.setColor(common.Color.player_entity)
        LG.circle('fill', player_x, player_y, player_iris_radius)

        -- Draw player player firing trigger • (circle)
        local player_edge_x = player_x + math.cos(player_angle) * config.PLAYER_FIRING_EDGE_MAX_RADIUS
        local player_edge_y = player_y + math.sin(player_angle) * config.PLAYER_FIRING_EDGE_MAX_RADIUS
        do -- @juice ─ simulate the twinkle in eye to go opposite to player's direction
                local inertia_x = 0
                local inertia_y = 0
                if love.keyboard.isDown('up', 'w') then
                        inertia_x = curr_state.player_vel_x + math.cos(curr_state.player_rot_angle) * config.PLAYER_ACCELERATION * game_timer_dt
                        inertia_y = curr_state.player_vel_y + math.sin(curr_state.player_rot_angle) * config.PLAYER_ACCELERATION * game_timer_dt
                end
                local is_reversing = not true
                if love.keyboard.isDown('down', 's') then
                        is_reversing = true
                        reverse_damp_dist = 0.5
                        inertia_x = curr_state.player_vel_x - math.cos(curr_state.player_rot_angle) * config.PLAYER_ACCELERATION * game_timer_dt
                        inertia_y = curr_state.player_vel_y - math.sin(curr_state.player_rot_angle) * config.PLAYER_ACCELERATION * game_timer_dt
                else
                        is_reversing = not true
                end
                inertia_x = curr_state.player_vel_x * config.AIR_RESISTANCE
                inertia_y = curr_state.player_vel_y * config.AIR_RESISTANCE
                local dfactor = true and 0.5 or (PHI_INV * 0.8) -- ideal: .328 (distance factor)
                local amplitude_factor = is_reversing and 0.125 or 0.35
                player_edge_x = player_edge_x - (dfactor * amplitude_factor * config.PLAYER_FIRING_EDGE_MAX_RADIUS) * (inertia_x * game_timer_dt)
                player_edge_y = player_edge_y - (dfactor * amplitude_factor * config.PLAYER_FIRING_EDGE_MAX_RADIUS) * (inertia_y * game_timer_dt)
        end
        local invultimer = curr_state.player_invulnerability_timer
        local player_trigger_radius = lerp(config.PLAYER_FIRING_EDGE_RADIUS - 5, config.PLAYER_FIRING_EDGE_RADIUS - 3, alpha + (invultimer * 0.5))
        local _radius = (invultimer > 0) and lerp(player_trigger_radius - (3 * invultimer), player_trigger_radius + (3 * invultimer), invultimer)
                or player_trigger_radius
        LG.setColor(common.Color.player_entity_firing_edge_dark)
        LG.circle('fill', player_edge_x, player_edge_y, _radius)
end

local temp_last_ouch_x = nil
local temp_last_ouch_y = nil
local temp_ouch_messages = { 'OUCH!', 'OWW!', 'HEYY!' }
local temp_last_ouch_message_index = love.math.random(1, MAX_TEMP_OUCH_MESSAGES)
local MAX_TEMP_OUCH_MESSAGES = #temp_ouch_messages
function draw_player_health_bar(alpha)
        local cs = curr_state
        local sw = 1 -- scale width
        local sh = 1 -- scale height

        local player_invulnerability_timer = cs.player_invulnerability_timer
        local curr_health_percentage = (cs.player_health / config.MAX_PLAYER_HEALTH)
        if config.debug.is_assert then assert(curr_health_percentage >= 0.0 and curr_health_percentage <= 1.0) end
        local bar_width = 2 ^ 8 -- Example width
        local bar_height = 2 ^ 3 -- Example height
        local bar_x = (arena_w * 0.5) - (bar_width * 0.5) -- X position on screen
        local bar_y = bar_height * 2 * PHI -- Y position on screen

        local prev_health_percentage = (prev_state.player_health / config.MAX_PLAYER_HEALTH)
        local interpolated_health = lerp(prev_health_percentage, curr_health_percentage, alpha)
        LG.setColor(common.Color.creature_healing) -- red
        if config.IS_GRUG_BRAIN and player_invulnerability_timer > 0 then -- @juice: inflate/deflate health bar
                -- sw = sw * 1.1 -- horizontal translation is tricky and trippy ^_^
                sh = lerp(sh * 0.95, sh * 1.25, player_invulnerability_timer * alpha)
        end

        LG.setColor(common.Color.creature_healing) -- red
        LG.rectangle('fill', bar_x, bar_y, bar_width * sw, bar_height * sh) -- missing health

        LG.setColor(0.95, 0.95, 0.95) -- white
        LG.rectangle('fill', bar_x, bar_y, (bar_width * interpolated_health) * sw, bar_height * sh) -- current health
        if player_invulnerability_timer > 0 then
                if temp_last_ouch_x == nil and temp_last_ouch_y == nil then
                        temp_last_ouch_x = cs.player_x + config.PLAYER_RADIUS - 4
                        temp_last_ouch_y = cs.player_y - config.PLAYER_RADIUS - 4
                        temp_last_ouch_message_index = math.floor(love.math.random(1, MAX_TEMP_OUCH_MESSAGES)) --- WARN: Is the random output inclusive?
                        assert(temp_last_ouch_message_index >= 1 and temp_last_ouch_message_index <= MAX_TEMP_OUCH_MESSAGES)
                else
                        LG.setColor(common.Color.player_dash_pink_modifier) -- white
                        LG.print(temp_ouch_messages[temp_last_ouch_message_index], temp_last_ouch_x, temp_last_ouch_y)
                end

                -- Draw invulnerability timer
                local invulnerability_bar_height = bar_height * PHI_INV * 0.5
                LG.setColor(0.95, 0.95, 0.95, 0.1) -- white
                LG.rectangle('fill', bar_x, bar_y + bar_height * sh, bar_width * sw, invulnerability_bar_height * sh) -- missing health

                local invulnerable_tween = player_invulnerability_timer
                if config.IS_GRUG_BRAIN then invulnerable_tween = lerp(player_invulnerability_timer - game_timer_dt, player_invulnerability_timer, alpha) end
                LG.setColor(0, 1, 1) -- cyan?????
                LG.rectangle('fill', bar_x, bar_y + bar_height * sh, (bar_width * invulnerable_tween) * sw, invulnerability_bar_height * sh) -- current invulnerability
        else
                temp_last_ouch_x = nil
                temp_last_ouch_y = nil
        end
        LG.setColor(1, 1, 1) -- reset color to default
end

function draw_player_shield_collectible(alpha)
        local COLLECTIBLE_SHIELD_RADIUS = config.PLAYER_RADIUS * (1 - PHI_INV) * 3
        local is_spawned_shield = (player_shield_collectible_pos_x ~= nil and player_shield_collectible_pos_y ~= nil)
        if not is_spawned_shield then -- exists
                return
        end

        local glowclr = common.Color.player_dash_pink_modifier
        local freq = 127 -- Hz
        local tween_fx = lerp(0.05, PHI_INV * math.sin(alpha * freq), alpha / math.min(0.4, game_timer_dt * math.sin(alpha)))
        local tween = lerp(PHI, 2 * PHI * math.sin(alpha * freq), alpha)
        local radius = (COLLECTIBLE_SHIELD_RADIUS * (1.2 + math.sin(0.03 * alpha)) + tween)
        LG.setColor(glowclr[1], glowclr[2], glowclr[3], 1.0 - math.sin(0.03 * alpha)) -- LG.setColor { 0.9, 0.9, 0.4 }
        LG.circle('fill', player_shield_collectible_pos_x, player_shield_collectible_pos_y, radius)

        local fxclr = common.Color.player_entity
        LG.setColor(fxclr[1], fxclr[2], fxclr[3], 0.2)
        LG.circle('fill', player_shield_collectible_pos_x, player_shield_collectible_pos_y, COLLECTIBLE_SHIELD_RADIUS + tween_fx)

        LG.setColor(1, 1, 1, 0.2)
        draw_plus_icon(player_shield_collectible_pos_x, player_shield_collectible_pos_y, COLLECTIBLE_SHIELD_RADIUS + tween_fx)
        LG.setColor(fxclr)
        LG.circle('fill', player_shield_collectible_pos_x, player_shield_collectible_pos_y, COLLECTIBLE_SHIELD_RADIUS + tween)

        LG.setColor(1, 1, 1)
        draw_plus_icon(player_shield_collectible_pos_x, player_shield_collectible_pos_y, COLLECTIBLE_SHIELD_RADIUS + tween)

        LG.setColor(1, 1, 1) -- reset
end

--- @enum PLAYER_ACTION
local PLAYER_ACTION = {
        BESERK_BOOST_COMBO = 'BESERK_BOOST_COMBO',
        BESERK = 'BESERK',
        DASH = 'DASH',
        FIRE = 'FIRE',
        IDLE = 'IDLE',
}

--- @type table<PLAYER_ACTION, [number, number, number]>
local PROJECTILE_TO_PLAYER_ACTION_MAP = {
        [PLAYER_ACTION.BESERK_BOOST_COMBO] = common.Color.player_beserker_dash_modifier,
        [PLAYER_ACTION.BESERK] = common.Color.player_beserker_modifier,
        [PLAYER_ACTION.DASH] = common.Color.player_dash_neonblue_modifier,
        [PLAYER_ACTION.FIRE] = common.Color.player_entity_firing_projectile,
        [PLAYER_ACTION.IDLE] = common.Color.player_entity,
}

function _draw_active_projectile(i, alpha)
        local pos_x = curr_state.lasers_x[i]
        local pos_y = curr_state.lasers_y[i]
        if prev_state.lasers_is_active[i] == common.Status.active then
                pos_x = lerp(prev_state.lasers_x[i], pos_x, alpha)
                pos_y = lerp(prev_state.lasers_y[i], pos_y, alpha)
        end

        local is_beserk = love.keyboard.isDown('lshift', 'rshift')
        local is_boost = love.keyboard.isDown 'x'
        local is_beserk_boost_combo = is_beserk and is_boost

        -- maybe this should be in its update method?
        --[[@type PLAYER_ACTION]]
        local player_action = (
                is_beserk_boost_combo and PLAYER_ACTION.BESERK_BOOST_COMBO
                or (is_beserk and PLAYER_ACTION.BESERK
                        or (is_boost and PLAYER_ACTION.DASH or PLAYER_ACTION.FIRE)
                        or PLAYER_ACTION.IDLE)
        )

        -- Add sprite to batch with position, rotation, scale and color
        local scale = 1 --- Scale based on original `LASER_RADIUS`.
        local origin_x = config.LASER_RADIUS
        local origin_y = config.LASER_RADIUS
        laser_sprite_batch:setColor(PROJECTILE_TO_PLAYER_ACTION_MAP[player_action])
        laser_sprite_batch:add(pos_x, pos_y, 0, scale, scale, origin_x, origin_y)
end

function draw_player_fired_projectiles(alpha)
        laser_sprite_batch:clear()
        for i = 1, #curr_state.lasers_x do
                if curr_state.lasers_is_active[i] == common.Status.active then --
                        _draw_active_projectile(i, alpha)
                end
        end
        LG.setColor(1, 1, 1, 1) -- Reset color before drawing
        LG.draw(laser_sprite_batch) -- Draw all sprites in one batch
end

local MAX_CREATURE_RADIUS_INV = 1 / config.MAX_CREATURE_RADIUS
function _draw_active_creature(i, alpha)
        local cs = curr_state
        local curr_x = cs.creatures_x[i]
        local curr_y = cs.creatures_y[i]
        local evolution_stage = creature_evolution_stages[cs.creatures_evolution_stage[i]] --- @type Stage
        local radius = evolution_stage.radius --- @type integer
        -- Add sprite to batch with position, rotation, scale and color
        local scale = radius * MAX_CREATURE_RADIUS_INV
        local origin_x = radius
        local origin_y = radius
        creatures_sprite_batch:setColor(common.Color.creature_infected) -- !!!! can this paint them individually with set color
        creatures_sprite_batch:add(curr_x, curr_y, 0, scale, scale, origin_x, origin_y) -- x, y, ?, sx, sy, ox, oy (origin x, y 'center of the circle')
end

function _draw_non_active_creature(i, alpha)
        local curr_x = curr_state.creatures_x[i]
        local curr_y = curr_state.creatures_y[i]

        local evolution_stage = creature_evolution_stages[curr_state.creatures_evolution_stage[i]] --- @type Stage
        local radius = evolution_stage.radius
        local scale = radius * MAX_CREATURE_RADIUS_INV --- since sprite batch item has radius of largest creature

        -- Automatically disappear when the `find_inactive_creature_index` looks them up and then
        -- `spawn_new_creature` mutates them.
        local is_not_moving = prev_state.creatures_x[i] ~= curr_x and prev_state.creatures_y[i] ~= curr_y
        local corner_offset = config.PLAYER_RADIUS + evolution_stage.radius

        local health = curr_state.creatures_health[i]
        local is_away_from_corner = curr_x >= 0 + corner_offset
                and curr_x <= arena_w - corner_offset
                and curr_y >= 0 + corner_offset
                and curr_y <= arena_h - corner_offset
        local is_healing = (curr_state.creatures_is_active[i] == common.Status.not_active)
                and health > common.HealthTransitions.healing
                and health <= common.HealthTransitions.healthy
        if (is_away_from_corner or is_not_moving) and is_healing then
                -- Add sprite to batch with position, rotation, scale and color
                local origin_x = radius
                local origin_y = radius
                creatures_sprite_batch:setColor(common.Color.creature_healed) -- !!!! can this paint them individually with set color
                creatures_sprite_batch:add(curr_x, curr_y, 0, scale, scale, origin_x, origin_y) -- x, y, ?, sx, sy, ox, oy (origin x, y 'center of the circle')

                -- PERF: Use a different sprite batch for healed departing creature
                -- THIS LEADS TO +1000 batch calls
                -- Draw final creature evolution on successful healing with '+' symbol.
                if config.IS_GAME_SLOW then
                        local smooth_alpha = lerp((1 - PHI_INV), alpha, PHI_INV)
                        if smooth_alpha < config.PHI_INV then --- avoid janky alpha fluctuations per game basis
                                local juice_frequency = 1 + math.sin(config.FIXED_FPS * game_timer_dt)
                                local juice_frequency_damper = lerp(0.25, 0.125, alpha)
                                local radius_factor = (1 + smooth_alpha * juice_frequency * lerp(1, juice_frequency_damper, smooth_alpha))
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

--- FIXME: Creature still on screen after laser collision, after introducing batch draw
---             USE separate batches to draw active and non_active creatures
function draw_creatures(alpha)
        creatures_sprite_batch:clear() -- clear previous frame's creatures_sprite_batch from canvas
        for i = 1, #curr_state.creatures_x do
                if curr_state.creatures_is_active[i] == common.Status.active then
                        _draw_active_creature(i, alpha)
                else
                        _draw_non_active_creature(i, alpha)
                end
        end
        LG.setColor(1, 1, 1, 1) -- Reset color before drawing
        LG.draw(creatures_sprite_batch) -- Draw all sprites in one batch
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
        local cs = curr_state
        local hud_h = 128
        local hud_w = 150
        local pad_x = 16 -- horizontal
        local pad_y = 16 -- vertical
        local pos_x = arena_w - hud_w
        local pos_y = 0
        LG.setColor(common.Color.text_darkest)
        LG.print(
                table.concat({
                        'Level ' .. game_level,
                        'Total hit count ' .. laser_intersect_creature_counter,
                        'Healed count ' .. laser_intersect_final_creature_counter,
                        string.format('%.4s', game_timer_t),
                }, '\n'),
                1 * pos_x + pad_x,
                1 * pos_y + pad_y
        )
        if config.debug.is_development and config.debug.is_trace_hud then
                LG.print(
                        table.concat({
                                'love.timer.getFPS() ' .. love.timer.getFPS(),
                                'dt_accum ' .. string.format('%.6f', dt_accum),
                                'alpha ' .. string.format('%f', dt_accum * config.FIXED_DT_INV),
                                '---',
                                'active_creatures ' .. count_active_creatures(),
                                'invulnerability_timer ' .. cs.player_invulnerability_timer,
                        }, '\n'),
                        1 * pos_x - (hud_w * 0.25) + pad_x,
                        (arena_h * 0.5) - 1 * pos_y + hud_h + pad_y
                )
        end
        LG.setColor(1, 1, 1) -- reset color
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
        local active_counter = 0 --- @type integer
        for _, value in ipairs(cs.creatures_is_active) do
                if value == common.Status.active then --
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
        LG.setColor(1, 1, 1) -- reset color to avoid leaking debug hud text color into post-processing shader.
end

--
--
-- Uncategorized
--
--

--- @enum EngineMoveKind
local EngineMoveKind = {
        idle = 0,
        forward = 1,
        backward = 2,
}

--- @param dt number # Delta time.
--- @param movekind EngineMoveKind
function play_player_engine_sound(dt, movekind)
        local cs = curr_state
        sound_player_engine:play()
        sound_player_engine:setVelocity(cs.player_vel_x, cs.player_vel_y, 1)
        if config.IS_GRUG_BRAIN then
                -- Stop overlapping sound waves by making the consecutive one softer
                local curr_pos = sound_player_engine:tell 'samples'
                local last_pos = sound_player_engine:getDuration 'samples'
                if movekind == EngineMoveKind.forward then
                        sound_player_engine:setVolume(1.3)
                        sound_player_engine:setAirAbsorption(dt) --- LOL (: warble effect due to using variable dt
                elseif movekind == EngineMoveKind.backward then
                        sound_player_engine:setVolume(0.8)
                        sound_player_engine:setAirAbsorption(0) --- LOL (: warble effect due to using variable dt
                elseif curr_pos >= PHI_INV * last_pos and curr_pos <= 0.99 * last_pos then
                        sound_player_engine:setVolume(movekind == EngineMoveKind.forward and 0.6 or 0.7)
                        sound_player_engine:setAirAbsorption(10) --- LOL (: warble effect due to using variable dt
                elseif curr_pos > 0.99 * last_pos then
                        sound_player_engine:setVolume(1)
                        sound_player_engine:setAirAbsorption(20) --- LOL (: warble effect due to using variable dt
                end
        end
end

--- TODO: Add screen transition using a Timer.
--- TODO: Fade to black and then back to player if reset_game
--- @param status PlayerDamageStatus
function player_damage_status_actions(status)
        if status == PlayerDamageStatus.DEAD then
                screenshake.duration = 0.15 * PHI * PHI
                sound_interference:play()
                reset_game()
        elseif status == PlayerDamageStatus.DAMAGED then
                screenshake.duration = 0.15 * PHI
                sound_interference:play()
        elseif status == PlayerDamageStatus.INVULNERABLE then
                screenshake.duration = 0.45
                sound_player_engine:play() -- indicate player to move while they still can ^_^
        end -- no-op
end

function handle_player_input_this_frame(dt)
        local cs = curr_state
        if love.keyboard.isDown('right', 'd') then --
                cs.player_rot_angle = cs.player_rot_angle + player_turn_speed * dt
        end
        if love.keyboard.isDown('left', 'a') then --
                cs.player_rot_angle = cs.player_rot_angle - player_turn_speed * dt
        end
        cs.player_rot_angle = cs.player_rot_angle % (2 * math.pi) -- wrap player angle each 360°
        if love.keyboard.isDown('up', 'w') then
                cs.player_vel_x = cs.player_vel_x + math.cos(cs.player_rot_angle) * config.PLAYER_ACCELERATION * dt
                cs.player_vel_y = cs.player_vel_y + math.sin(cs.player_rot_angle) * config.PLAYER_ACCELERATION * dt
                play_player_engine_sound(dt, EngineMoveKind.forward)
        end
        local is_reverse_enabled = true
        if is_reverse_enabled then
                local reverse_acceleration_factor = 0.9
                local reverese_acceleration = config.PLAYER_ACCELERATION * reverse_acceleration_factor
                if love.keyboard.isDown('down', 's') then
                        cs.player_vel_x = cs.player_vel_x - math.cos(cs.player_rot_angle) * reverese_acceleration * dt
                        cs.player_vel_y = cs.player_vel_y - math.sin(cs.player_rot_angle) * reverese_acceleration * dt
                end
                play_player_engine_sound(dt, EngineMoveKind.backward)
        end
        if love.keyboard.isDown 'space' then fire_player_projectile() end
        if love.keyboard.isDown 'x' then boost_player_entity_speed(dt) end
        if love.keyboard.isDown('lshift', 'rshift') then --- enhance attributes while spinning like a top
                player_turn_speed = config.PLAYER_DEFAULT_TURN_SPEED * PHI
                laser_fire_timer = (love.math.random() < 0.05) and 0 or game_timer_dt
        else
                player_turn_speed = config.PLAYER_DEFAULT_TURN_SPEED
        end
end

---
---
--- The Game Update & Draw Loops
---
---

function update_game(dt) ---@param dt number # Fixed delta time.
        handle_player_input_this_frame(dt)
        update_background_shader(dt)
        update_player_vulnerability_timer_this_frame(dt)
        update_player_position_this_frame(dt)
        update_player_trails_this_frame(dt)
        update_player_fired_projectiles_this_frame(dt)
        update_player_shield_collectible_this_frame(dt)
        update_creatures_this_frame(dt)
end

-- bigger parallax entities go slow?
-- or closer to the screen goes slow?
local MAX_PARALLAX_ENTITIES = (2 ^ 5)
local PARALLAX_ENTITY_MAX_DEPTH = 4 --- @type integer
local PARALLAX_ENTITY_MIN_DEPTH = 1 --- @type integer
local PARALLAX_OFFSET_FACTOR_X = 0.075 * PHI_INV -- NOTE: Should be lower to avoid puking
local PARALLAX_OFFSET_FACTOR_Y = 0.075 * PHI_INV
local _PARALLAX_ENTITY_RADIUS_FACTOR = 2 * PHI * (config.IS_GAME_SLOW and 2 or 1) -- some constant

local parallax_entity_depth = {} --- @type number[]
local parallax_entity_pos_x = {} --- @type number[] without arena_w world coordinate scaling
local parallax_entity_pos_y = {} --- @type number[] without arena_h world coordinate scaling
local parallax_entity_radius = {} --- @type number[]
-- Initialize parallax entities
do
        for i = 1, MAX_PARALLAX_ENTITIES do
                parallax_entity_pos_x[i] = love.math.random() --- 0.0..1.0
                parallax_entity_pos_y[i] = love.math.random() --- 0.0..1.0
                local depth = love.math.random(PARALLAX_ENTITY_MIN_DEPTH, PARALLAX_ENTITY_MAX_DEPTH)
                parallax_entity_depth[i] = depth
                parallax_entity_radius[i] = _PARALLAX_ENTITY_RADIUS_FACTOR * math.ceil(math.sqrt(depth) * (PARALLAX_ENTITY_MAX_DEPTH / depth))
        end
        if not true then
                local condition = #parallax_entity_pos_x == math.sqrt(#parallax_entity_pos_x) * math.sqrt(#parallax_entity_pos_x)
                assert(condition, 'Assert count of parallax entity is a perfect square')
        end
end

local offset_x = 0
local offset_y = 0
local parallax_entity_alpha_color = ({ (PHI_INV ^ (config.IS_GAME_SLOW and -1 or -1)) * 0.56, 0.7, 1.0 })[config.CURRENT_THEME]
local sign1 = ({ -1, 1 })[love.math.random(1, 2)]
local sign2 = ({ -3, 3 })[love.math.random(1, 2)]

function update_background_shader(dt)
        local alpha = dt_accum * config.FIXED_DT_INV
        local a, b, t = (sign1 * 0.003 * alpha), (sign2 * 0.03 * alpha), math.sin(0.003 * alpha)
        local smoothValue = smoothstep(a, b, t)
        local freq = (smoothstep(common.sign(smoothValue) * (dt + 0.001), common.sign(smoothValue) * (smoothValue + 0.001), 0.5))
        local vel_x = 0.001 * 5 * freq * dt
        local vel_y = 4 * math.abs(0.4 * 8 * freq) * dt
        for i = 1, MAX_PARALLAX_ENTITIES, 4 do
                if config.IS_GRUG_BRAIN and screenshake.duration > 0 then
                        vel_x = vel_x - smoothstep(vel_x * (-love.math.random(-4, 4)), vel_x * love.math.random(-4, 4), smoothValue)
                        vel_y = vel_y - smoothstep(vel_y * (-love.math.random(-0.5, 2.5)), vel_y * love.math.random(0, 8), smoothValue)
                end
                parallax_entity_pos_x[i] = parallax_entity_pos_x[i] - math.sin(parallax_entity_depth[i] * vel_x)
                parallax_entity_pos_x[i + 1] = parallax_entity_pos_x[i + 1] - math.sin(parallax_entity_depth[i + 1] * vel_x)
                parallax_entity_pos_x[i + 2] = parallax_entity_pos_x[i + 2] - math.sin(parallax_entity_depth[i + 2] * vel_x)
                parallax_entity_pos_x[i + 3] = parallax_entity_pos_x[i + 3] - math.sin(parallax_entity_depth[i + 3] * vel_x)
                parallax_entity_pos_y[i] = parallax_entity_pos_y[i] - (vel_y / parallax_entity_depth[i])
                parallax_entity_pos_y[i + 1] = parallax_entity_pos_y[i + 1] - (vel_y / parallax_entity_depth[i + 1])
                parallax_entity_pos_y[i + 2] = parallax_entity_pos_y[i + 2] - (vel_y / parallax_entity_depth[i + 2])
                parallax_entity_pos_y[i + 3] = parallax_entity_pos_y[i + 3] - (vel_y / parallax_entity_depth[i + 3])
                if parallax_entity_pos_y[i] < 0 then parallax_entity_pos_y[i] = 1 end
                if parallax_entity_pos_y[i + 1] < 0 then parallax_entity_pos_y[i + 1] = 1 end
                if parallax_entity_pos_y[i + 2] < 0 then parallax_entity_pos_y[i + 2] = 1 end
                if parallax_entity_pos_y[i + 3] < 0 then parallax_entity_pos_y[i + 4] = 1 end
        end
end

--- without sprite batch:        draw calls 2474 for (2^8 entities)
--- with sprite batch:           draw calls 162 for (2^8 entities)
--- TODO: simulate fireworks like animation of entities
local thirty_two_inv = 1 / 32
function _draw_background_shader(alpha)
        local cs = curr_state
        local dx = 0
        local dy = 0
        local is_follow_player_parallax = true
        if is_follow_player_parallax then
                offset_x = cs.player_x / arena_w -- FIXME: should lerp on wrap
                offset_y = cs.player_y / arena_h
                dx = offset_x * PARALLAX_OFFSET_FACTOR_X
                dy = offset_y * PARALLAX_OFFSET_FACTOR_Y
        end
        background_parallax_sprite_batch:clear() -- Clear and update sprite batch
        for i = 1, MAX_PARALLAX_ENTITIES do
                local depth_inv = parallax_entity_depth[i]
                local radius = parallax_entity_radius[i]
                local x = (parallax_entity_pos_x[i] - (dx * depth_inv)) * arena_w
                local y = (parallax_entity_pos_y[i] - (dy * depth_inv)) * arena_h
                local point_alpha = parallax_entity_alpha_color * depth_inv

                -- Add sprite to batch with position, rotation, scale and color
                local scale = radius * thirty_two_inv -- Scale based on original circle radius as 32 was parallax entity image size
                local origin_x = radius
                local origin_y = radius
                -- background_parallax_sprite_batch:setColor(0.9, 0.9, 0.9, point_alpha)
                background_parallax_sprite_batch:setColor(0.025, 0.015, 0.10, point_alpha)
                background_parallax_sprite_batch:add(x, y, 0, scale, scale, origin_x, origin_y) -- origin x, y (center of the circle)
        end
        LG.setColor(1, 1, 1, 1) -- Reset color before drawing
        LG.draw(background_parallax_sprite_batch) -- Draw all sprites in one batch
end

function draw_background_shader(alpha)
        if config.IS_GAME_SLOW then
                shaders.background_shader(function() _draw_background_shader(alpha) end)
        else
                _draw_background_shader(alpha)
        end
end

---@diagnostic disable-next-line: unused-local
function draw_screenshake_fx(alpha)
        if not (screenshake.duration > 0) then return end
        if screenshake.duration >= 0.125 and screenshake.duration <= 0.96 then -- snappy screenflash
                local flash_alpha = common.ScreenFlashAlphaLevel.low
                LG.setColor(({ { 0.15, 0.15, 0.15, flash_alpha }, { 0.5, 0.5, 0.5, flash_alpha }, { 1, 1, 1, flash_alpha } })[config.CURRENT_THEME])
                LG.rectangle('fill', 0, 0, arena_w, arena_h) -- Simulate screenflash (TODO: Make it optional, and sensory warning perhaps?)
        end
        LG.translate(screenshake.offset_x, screenshake.offset_y) -- Simulate screenshake
end

--- FIXME: When I set a refresh rate of 75.00 Hz on a 800 x 600 (4:3)
--- monitor, alpha seems to be faster -> which causes the juice frequency to
--- fluctute super fast
function draw_game(alpha)
        draw_screenshake_fx(alpha)

        draw_creatures(alpha)
        draw_player_health_bar(alpha)
        draw_player_fired_projectiles(alpha)
        draw_player_shield_collectible(alpha)
        draw_player_trail(alpha)
        draw_player_direction_ray(alpha)
        draw_player(alpha)
end

--
--
-- LOVE - [Open in Browser](https://love2d.org/wiki/love)
--
--

function love.load()
        LG.setDefaultFilter('linear', 'linear') -- smooth edges
        arena_h = gh
        arena_w = gw
        do -- Music time
                local on_hit_play_coin = not true
                if on_hit_play_coin then
                        sound_creature_healed_1 = love.audio.newSource('resources/audio/sfx/statistics_pickup_coin3.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
                        sound_creature_healed_1:setPitch(1.50) -- tuned close to `music_bgm`'s key
                        sound_creature_healed_1:setVolume(0.625)
                        sound_creature_healed_2 = love.audio.newSource('resources/audio/sfx/statistics_pickup_coin3_1.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
                        sound_creature_healed_2:setPitch(1.50) -- tuned close to `music_bgm`'s key
                        sound_creature_healed_2:setVolume(0.625)
                        sound_fire_combo_hit = love.audio.newSource('resources/audio/sfx/animal_happy_bird.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
                        sound_fire_combo_hit:setPitch(0.85)
                        sound_fire_combo_hit:setVolume(PHI_INV)
                else
                        sound_creature_healed_1 = love.audio.newSource('resources/audio/sfx/wip/laser_jsfxr.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
                        sound_creature_healed_1:setVolume(1)
                        sound_creature_healed_2 = love.audio.newSource('resources/audio/sfx/wip/laser_final_jsfxr.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
                        sound_creature_healed_2:setVolume(1)
                        sound_fire_combo_hit = love.audio.newSource('resources/audio/sfx/wip/laser_explosion_jsfxr.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
                        sound_fire_combo_hit:setVolume(PHI_INV)
                end

                sound_pickup_shield = love.audio.newSource('resources/audio/sfx/wip/powerup_jsfxr.wav', 'static') -- stream and loop background music
                sound_pickup_shield:setVolume(1)

                sound_pickup_holy = love.audio.newSource('resources/audio/sfx/pickup_holy.wav', 'static') -- stream and loop background music
                sound_pickup_holy:setVolume(0.9) -- 90% of ordinary volume
                sound_pickup_holy:setPitch(0.5) -- one octave lower
                sound_pickup_holy:setVolume(0.6)
                sound_pickup_holy:play() -- PLAY AT GAME START once

                sound_guns_turn_off = love.audio.newSource('resources/audio/sfx/machines_guns_turn_off.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io
                sound_guns_turn_off:setEffect 'bandpass'
                sound_guns_turn_off:setVolume(PHI_INV)

                sound_interference = love.audio.newSource('resources/audio/sfx/machines_interference.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
                sound_interference:setVolume(PHI_INV)

                sound_fire_projectile = love.audio.newSource('resources/audio/sfx/select_sound.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
                sound_fire_projectile:setPitch(1.15)
                sound_fire_projectile:setVolume(PHI_INV)

                sound_player_engine = love.audio.newSource('resources/audio/sfx/atmosphere_dive.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io
                sound_player_engine:setPitch(0.6)
                sound_player_engine:setVolume(0.5)
                sound_player_engine:setFilter { type = 'lowpass', volume = 1, highgain = (3 * 0.5) }
                sound_player_engine:setVolume(PHI_INV ^ 8)

                sound_upgrade = love.audio.newSource('resources/audio/sfx/statistics_upgrade.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
                sound_upgrade:setVolume(PHI_INV)

                sound_ui_menu_select = love.audio.newSource('resources/audio/sfx/menu_select.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
                sound_ui_menu_select:setVolume(PHI_INV)

                --- Audio Drone
                sound_atmosphere_tense = love.audio.newSource('resources/audio/sfx/atmosphere_tense_atmosphere_1.wav', 'static') -- Credit to DASK: Retro
                sound_atmosphere_tense:setVolume(PHI_INV ^ 4)

                --- Background Music Credit:
                ---     • [Lupus Nocte](http://link.epidemicsound.com/LUPUS)
                ---     • [YouTube Link](https://youtu.be/NwyDMDlZrMg?si=oaFxm0LHqGCiUGEC)
                --- Note: `stream` option ─ stream and loop background music
                music_bgm = love.audio.newSource('resources/audio/music/lupus_nocte_arcadewave.mp3', 'stream')
                music_bgm:setFilter { type = 'lowpass', volume = 1, highgain = 1 }
                if config.debug.is_development then music_bgm:setFilter { type = 'bandpass', lowgain = 1 } end
                music_bgm:setVolume(0.9)
                music_bgm:setPitch(1.00) -- one octave lower
                if config.debug.is_development then
                        music_bgm:setVolume(music_bgm:getVolume() * 0.025)
                else
                        music_bgm:setVolume(1 - (2 * (3 / 16)))
                end

                -- Master volume
                love.audio.setVolume(not config.debug.is_development and 1.0 or 0.35) -- volume # number # 1.0 is max and 0.0 is off.
        end

        game_level = 1
        dt_accum = 0.0 --- Accumulator keeps track of time passed between frames.
        creature_swarm_range = config.PLAYER_RADIUS * 4 -- FIXME: should be evolution_stage.radius specific

        local fx = moonshine.effects
        shaders = { --- @type Shader
                background_shader = moonshine(arena_w, arena_h, fx.chromasep)
                        -- .chain(fx.pixelate)
                        -- .chain(fx.godsray)
                        .chain(fx.fastgaussianblur)
                        -- .chain(fx.desaturate)
                        .chain(fx.colorgradesimple)
                        .chain(fx.vignette),
                post_processing = moonshine(arena_w, arena_h, fx.godsray)
                        .chain(fx.chromasep)
                        -- .chain(fx.glow)
                        -- .chain(fx.crt)

                        .chain(fx.colorgradesimple)
                        .chain(fx.vignette),
        }
        glsl_gradient_shader = LG.newShader(glsl_gradient_shader_code)

        if true then
                if not true then
                        shaders.background_shader.pixelate.size = { 4, 4 } -- Default: {5, 5}
                        shaders.background_shader.pixelate.feedback = PHI_INV -- Default: 0
                end

                if not true then
                        shaders.background_shader.godsray.decay = ({ 0.80, 0.69, 0.70 })[config.CURRENT_THEME] -- Choices: dark .60|light .75
                        shaders.background_shader.godsray.density = 0.15 -- WARN: Performance Hog!
                        shaders.background_shader.godsray.exposure = ({ 0.32, 0.125, 0.25 })[config.CURRENT_THEME]
                        shaders.background_shader.godsray.light_position = { 0.50, -0.99 } -- twice the height above ((rays from top))
                        shaders.background_shader.godsray.samples = 48 -- lower sample helps to spread out rays
                        shaders.background_shader.godsray.weight = ({ 0.65, 0.45, 0.65 })[config.CURRENT_THEME]
                end

                shaders.background_shader.chromasep.angle = 180 -- 180 light from above reflects rays downwards
                shaders.background_shader.chromasep.radius = 3

                if graphics_config.scanlines.enable then
                        shaders.background_shader.scanlines.opacity = 1 * (1 - PHI_INV)
                        shaders.background_shader.scanlines.thickness = 2 * PHI_INV
                        shaders.background_shader.scanlines.width = 3 -- * 0.25 (HIGHER VALUES GIVE TRIPPY WATERY HORIZONTAL LINE VIBES FOR BG SHADER on low_light background)
                end
        end

        -- if graphics_config.bloom_intensity.enable then
        --         local amount = graphics_config.bloom_intensity.amount
        --         local defaults = { min_luma = 0.7, strength = 5 }
        --         shaders.post_processing.glow.min_luma = defaults.min_luma * amount
        --         shaders.post_processing.glow.strength = defaults.strength * amount
        -- end

        if graphics_config.chromatic_abberation.enable then
                local mode_settings = {
                        default = { angle = 0, radius = 0.0 },
                        minimal = { angle = 0, radius = 0.5 },
                        advanced = { angle = 180, radius = 1.2 },
                }
                local mode = graphics_config.chromatic_abberation.mode
                local settings = mode_settings[mode] or error('Invalid mode: ' .. mode, 3)
                shaders.post_processing.chromasep.angle = settings.angle
                shaders.post_processing.chromasep.radius = settings.radius
        end

        if graphics_config.curved_monitor.enable then
                local mode_settings = {
                        default = { distortion_factor = { 1.06, 1.065 }, feather = 0.02, scale_factor = 1 },
                        minimal = { distortion_factor = { 1.0, 1.0 }, feather = 0.0, scale_factor = 1 },
                        advanced = { distortion_factor = { 0.92, 1.08 }, feather = 0.02, scale_factor = 0.99 },
                }
                local minimal = mode_settings.minimal
                local advanced = mode_settings.advanced
                local amount = graphics_config.curved_monitor.amount
                shaders.post_processing.crt.distortionFactor = {
                        lerp(minimal.distortion_factor[1], advanced.distortion_factor[1], amount),
                        lerp(minimal.distortion_factor[2], advanced.distortion_factor[2], amount),
                }
                shaders.post_processing.crt.feather = lerp(minimal.feather, advanced.feather, amount)
                shaders.post_processing.crt.scaleFactor = lerp(minimal.scale_factor, advanced.scale_factor, amount)
        end

        if graphics_config.filmgrain.enable then
                local amount = graphics_config.filmgrain.amount
                local defaults = { opacity = lerp(0.3, 1.0, amount), size = lerp(1, 4, amount) }
                shaders.post_processing.filmgrain.opacity = defaults.opacity
                shaders.post_processing.filmgrain.size = defaults.size
        end

        if true then
                shaders.post_processing.godsray.decay = ({ 0.75, 0.69, 0.70 })[config.CURRENT_THEME]
                shaders.post_processing.godsray.density = 0.15
                shaders.post_processing.godsray.exposure =  ({ 0.20, 0.12, 0.25 })[config.CURRENT_THEME]
                shaders.post_processing.godsray.light_position = { 0.5, 0.5 }
                shaders.post_processing.godsray.samples = (config.IS_GAME_SLOW and 8 ^ 2 or math.floor(8 ^ 1.68)) --- 64 | 32 `(default: 70)`
                shaders.post_processing.godsray.weight = ({ 0.50, 0.45, 0.65 })[config.CURRENT_THEME]
        end
        if true then -- NOTE: default vignette filters ray scattering by godsray neately so we disable settings below
                shaders.post_processing.vignette.radius = 0.8+0.1 -- avoid health bar at the top
                shaders.post_processing.vignette.softness = (0.5 + 0.2)
                shaders.post_processing.vignette.opacity = 0.5 + 0.1-- + 0.3
                -- shaders.post_processing.vignette.color = common.Color.background
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
                player_health = 0,
                player_invulnerability_timer = 0,
                player_damaged_last_timestamp = 0.0,
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
                player_health = 0,
                player_invulnerability_timer = 0,
                player_damaged_last_timestamp = 0.0,
                player_rot_angle = 0,
                player_vel_x = 0,
                player_vel_y = 0,
                player_x = 0,
                player_y = 0,
        }

        player_trails_x = {} --- @type number[]
        player_trails_y = {} --- @type number[]
        player_trails_vel_x = {} --- @type number[]
        player_trails_vel_y = {} --- @type number[]
        player_trails_rot_angle = {} --- @type number[]
        player_trails_is_active = {} --- @type Status[]
        player_trails_time_left = {} --- @type number[]
        player_trails_index = 1 --- @type integer # 1..`MAX_PLAYER_TRAIL_COUNT`

        screenshake = { --- @type ScreenShake
                amount = 5 * 0.5 * config.PHI_INV,
                duration = 0.0,
                offset_x = 0.0,
                offset_y = 0.0,
                wait = 0.0,
        }

        local _creature_scale = 1
        local _speed_multiplier = 1.25
        creature_evolution_stages = { ---@type Stage[] # Size decreases as stage progresses.
                { speed = 90 * _speed_multiplier, radius = math.ceil(15 * _creature_scale) },
                { speed = 70 * _speed_multiplier, radius = math.ceil(30 * _creature_scale) },
                { speed = 50 * _speed_multiplier, radius = math.ceil(50 * _creature_scale) },
                { speed = 20 * _speed_multiplier, radius = math.ceil(80 * _creature_scale) },
        }
        do -- Test `creature_evolution_stages`.
                local max_creature_mutation_count = 0
                for i = 1, #creature_evolution_stages do
                        max_creature_mutation_count = max_creature_mutation_count + i
                end
                assert(max_creature_mutation_count == 10, 'Assert 1 creature (ancestor) »»mutates»» into ten creatures including itself.')
        end

        is_debug_hud_enabled = not true --- Toggled by keys event.

        -- Create a small circle image to use in our sprite batch.
        local function create_circle_image(radius, r, g, b, a)
                local diameter = radius * 2
                local canvas = LG.newCanvas(diameter, diameter)
                LG.setCanvas(canvas)
                LG.clear()
                LG.setColor(r or 1, g or 1, b or 1, a or 1)
                LG.circle('fill', radius, radius, radius)
                LG.setCanvas()
                return LG.newImage(canvas:newImageData())
        end

        local function make_background_parallax_entities_sprite_batch()
                local circle_image = create_circle_image(32, 0.025, 0.15, 0.10, 0.2)  -- if 4 -> Base size of 8 pixels diameter
                return love.graphics.newSpriteBatch(circle_image, MAX_PARALLAX_ENTITIES, 'static')
        end

        local function make_creatures_sprite_batch()
                local creature_circle_image = create_circle_image(creature_evolution_stages[#creature_evolution_stages].radius)
                return love.graphics.newSpriteBatch(creature_circle_image, config.TOTAL_CREATURES_CAPACITY, 'static') -- maybe static?
        end

        local function make_laser_sprite_batch()
                local laser_circle_image = create_circle_image(config.LASER_RADIUS) --- FIXME: how to make this dynamic sized? use differnet sprite images and batches?
                return love.graphics.newSpriteBatch(laser_circle_image, config.MAX_LASER_CAPACITY, 'static')
        end

        function reset_game()
                -- MUTATE GLOBAL VARS0
                config.INITIAL_LARGE_CREATURES = config.CONSTANT_INITIAL_LARGE_CREATURES * game_level
                do -- FIXME: ^^^ Avoiding exponential-like (not really) overpopulation
                        config.INITIAL_LARGE_CREATURES = math.floor(config.CONSTANT_INITIAL_LARGE_CREATURES * (game_level ^ (1 / 4)))
                end
                do -- AUTO-UPDATE
                        ---@type integer # This count excludes the initial ancestor count.
                        config.EXPECTED_FINAL_HEALED_CREATURE_COUNT = (config.INITIAL_LARGE_CREATURES ^ 2) - config.INITIAL_LARGE_CREATURES
                        ---@type integer # Double buffer size of possible creatures count i.e. `initial count ^ 2`
                        config.TOTAL_CREATURES_CAPACITY = 2 * (config.INITIAL_LARGE_CREATURES ^ 2)
                end

                game_timer_dt = 0.0
                game_timer_t = 0.0

                laser_fire_timer = 0
                laser_index = 1 -- circular buffer index (duplicated below!)
                laser_intersect_creature_counter = 0 -- count creatures collision with laser... coin like
                laser_intersect_final_creature_counter = 0 -- count tiniest creature to save─collision with laser
                player_fire_cooldown_timer = 0
                player_turn_speed = config.PLAYER_DEFAULT_TURN_SPEED

                player_shield_collectible_pos_x = nil --- @type number|nil
                player_shield_collectible_pos_y = nil --- @type number|nil

                curr_state.player_invulnerability_timer = 0
                curr_state.player_health = config.MAX_PLAYER_HEALTH
                curr_state.player_rot_angle = 0
                curr_state.player_vel_x = 0
                curr_state.player_vel_y = 0
                curr_state.player_x = arena_w * 0.5
                curr_state.player_y = arena_h * 0.5

                prev_state.player_invulnerability_timer = 0
                prev_state.player_health = nil --- NOTE: What should this be?
                prev_state.player_rot_angle = 0
                prev_state.player_vel_x = 0
                prev_state.player_vel_y = 0
                prev_state.player_x = arena_w * 0.5
                prev_state.player_y = arena_h * 0.5

                do
                        background_parallax_sprite_batch = make_background_parallax_entities_sprite_batch() --- @type love.SpriteBatch
                        creatures_sprite_batch = make_creatures_sprite_batch() --- @type love.SpriteBatch
                        laser_sprite_batch = make_laser_sprite_batch() --- @type love.SpriteBatch
                end

                for i = 1, config.MAX_PLAYER_TRAIL_COUNT do
                        player_trails_x[i] = 0
                        player_trails_y[i] = 0
                        player_trails_vel_x[i] = 0
                        player_trails_vel_y[i] = 0
                        player_trails_rot_angle[i] = 0
                        player_trails_is_active[i] = common.Status.not_active
                        player_trails_time_left[i] = 0
                end

                for i = 1, config.MAX_LASER_CAPACITY do
                        curr_state.lasers_angle[i] = 0
                        curr_state.lasers_is_active[i] = common.Status.not_active
                        curr_state.lasers_time_left[i] = config.LASER_FIRE_TIMER_LIMIT
                        curr_state.lasers_x[i] = 0
                        curr_state.lasers_y[i] = 0
                end
                laser_index = 1 -- reset circular buffer index (duplicated! Look above)

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

                for i = 1, config.INITIAL_LARGE_CREATURES do -- Activate initial creatures.
                        curr_state.creatures_angle[i] = love.math.random() * (2 * math.pi)
                        curr_state.creatures_evolution_stage[i] = largest_creature_stage -- Start at smallest stage
                        curr_state.creatures_health[i] = -1 -- -1 to 0 to 1.... like dash timer, or fade timer ( -1 to 0 to 1 )
                        curr_state.creatures_is_active[i] = common.Status.active
                        curr_state.creatures_vel_x[i] = 0
                        curr_state.creatures_vel_y[i] = 0
                        -- Avoid creature spawning at window corners. (when value is 0)
                        -- FIXME: Ensure creature doesn't intersect with player at new level load
                        do
                                curr_state.creatures_x[i] = love.math.random(32, arena_w - 32)
                                curr_state.creatures_y[i] = love.math.random(32, arena_h - 32)
                        end
                end

                copy_game_state(prev_state, curr_state)
                sync_prev_state()
                if config.debug.is_assert then assert_consistent_state() end
        end

        reset_game()

        -- if config.debug.is_test then
        --     test_timer_basic_usage()
        -- end

        -- LG.setBackgroundColor(common.Color.background)
end

function love.update(dt)
        if config.debug.is_development then -- FIXME: Maybe make stuff global that are not hot-reloading?
                require('lurker').update()
        end

        -- #1 Handle music and sound logic.
        if not music_bgm:isPlaying() then love.audio.play(music_bgm) end
        local is_every_10_second = (math.floor(game_timer_t) % 10) == 0
        if is_every_10_second then -- each 10+ score
                if not sound_atmosphere_tense:isPlaying() then sound_atmosphere_tense:play() end
        end

        -- #2 Update game timer.
        game_timer_t = game_timer_t + dt
        game_timer_dt = dt -- note: for easy global reference

        -- #3 Update all timers based on real dt.
        Timer.update(dt) -- call this every frame to update timers

        -- #4 Frame Rate Independence: Fixed timestep loop.
        local fixed_dt = config.FIXED_DT
        dt_accum = dt_accum + dt
        while dt_accum >= fixed_dt do
                sync_prev_state()
                update_game(fixed_dt)
                dt_accum = dt_accum - fixed_dt
        end

        -- #5 Update any other frame-based effects (e.g., screen shake).
        update_screenshake(dt)
end

function love.draw()
        LG.clear(1, 1, 1, 1)                         -- this clears crt and background color each frame start
        if config.debug.is_assert then assert_consistent_state() end
        local alpha = dt_accum * config.FIXED_DT_INV --- @type number
        shaders.post_processing(function()
                do
                        LG.setShader(glsl_gradient_shader)
                        LG.rectangle("fill", 0, 0, arena_w, arena_h)                                 --- draw background fill, else background color shows up (maybe use LG.clearBackground())
                        glsl_gradient_shader:send('screen', { LG.getWidth(), LG.getHeight() }) -- or use getDimension()???  -- shouldn't this be in update???
                        do
                                draw_background_shader(alpha)
                        end
                        LG.setShader() -- LG.setShader(background_gradient_shader)
                end

                -- • Objects that are partially off the edge of the screen can be seen on the other side.
                -- • Coordinate system is translated to different positions and everything is drawn at each position around the screen and in the center.
                -- • Draw off-screen object partially wrap around without glitch
                for y = -1, 1 do
                        for x = -1, 1 do
                                LG.origin()
                                LG.translate(x * arena_w, y * arena_h)
                                draw_game(alpha)
                        end
                end
                LG.origin() -- Reverse any previous calls to love.graphics.
        end)
        if is_debug_hud_enabled then draw_hud() end
        if is_debug_hud_enabled then draw_debug_hud() end
end

function love.keypressed(key, _, _)
        -- if key == common.ControlKey.force_quit_game then love.event.push 'quit' end
        if key == common.ControlKey.escape_key then
                love.event.push 'quit'
        elseif key == common.ControlKey.toggle_hud then
                is_debug_hud_enabled = not is_debug_hud_enabled
        elseif key == common.ControlKey.reset_level then -- high priority
                reset_game()
        elseif key == common.ControlKey.next_level then
                game_level = (game_level % config.MAX_GAME_LEVELS) + 1
                reset_game()
        elseif key == common.ControlKey.prev_level then
                game_level = game_level - 1
                if game_level <= 0 then game_level = config.MAX_GAME_LEVELS end
                reset_game()
        end
end

function love.keyreleased(key)
        if key == 'space' then sound_guns_turn_off:play() end
end

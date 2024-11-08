---@diagnostic disable: lowercase-global, undefined-global, duplicate-set-field
--[[

Ludum Dare 56: Tiny Creatures
    See https://ldjam.com/events/ludum-dare/56/$403597

Starter setup ported initially from https://berbasoft.com/simplegametutorials/love/asteroids/

Development
    $ find -name '*.lua' | entr -crs 'date; love .; echo exit status $?'

--]]

local lume = require 'lume'

local Collision = require 'collision'
local Common = require 'common'
local Config = require 'config'
local Simulate = require 'simulate'
local Timer = require 'timer'

local LG = love.graphics
local lerp, smoothstep = lume.lerp, lume.smooth
local PHI, PHI_SQ, INV_PHI, INV_PHI_SQ = Config.PHI, Config.PHI_SQ, Config.INV_PHI, Config.INV_PHI_SQ
local PI, INV_PI = Config.PI, Config.INV_PI

--
--
--
--
-- Types & Definitions
--
--
--
--

--- @class (exact) GameState
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

--- @class (exact) Circle
--- @field x number
--- @field y number
--- @field radius number

--- @class (exact) ScreenShake
--- @field amount number # 0
--- @field duration number # 0
--- @field offset_x number # 0
--- @field offset_y number # 0
--- @field wait number # 0
--- See also: https://sheepolution.com/learn/book/22

--- MOVE THIS TO CONFIG.LUA
--- NOTE: This is used by `game_level` to mutate `initial_large_creatures` these are mutated after
---       each level::: i can't bother changing case as of now... will do when time permits??

-- #region  Declare global data structures.
-- vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

--- @class GameState
curr_state = {
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
    player_damaged_last_timestamp = 0.0,
    player_health = 0,
    player_invulnerability_timer = 0,
    player_rot_angle = 0,
    player_vel_x = 0,
    player_vel_y = 0,
    player_x = 0,
    player_y = 0,
}

--- @class GameState
prev_state = {
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
    player_damaged_last_timestamp = 0.0,
    player_health = 0,
    player_invulnerability_timer = 0,
    player_rot_angle = 0,
    player_vel_x = 0,
    player_vel_y = 0,
    player_x = 0,
    player_y = 0,
}

--- @class (exact) ParallaxEntities
--- @field depth number[]
--- @field radius number[]
--- @field x number[] Without arena_w world coordinate scaling
--- @field y number[] Without arena_h world coordinate scaling
parallax_entities = {
    depth = {},
    radius = {},
    x = {},
    y = {},
    -- FEAT: Add active timer to disappear it
}

--- @class (exact) PlayerTrails
--- @field index integer # 1..`MAX_PLAYER_TRAIL_COUNT`
--- @field is_active Status[]
--- @field rot_angle number[]
--- @field time_left number[]
--- @field vel_x number[]
--- @field vel_y number[]
--- @field x number[]
--- @field y number[]
player_trails = {
    index = 1,
    is_active = {},
    rot_angle = {},
    time_left = {},
    vel_x = {},
    vel_y = {},
    x = {},
    y = {},
}

-- TODO: after prototype add this to curr_state & prev_state datastructures
drone = {
    x = 0.0,
    y = 0.0,
    rot_angle = 0.0,
    vel_x = 0.0,
    vel_y = 0.0,
    radius = Config.PLAYER_RADIUS,
}
prev_drone = {
    x = 0.0,
    y = 0.0,
    rot_angle = 0.0,
    vel_x = 0.0,
    vel_y = 0.0,
    radius = Config.PLAYER_RADIUS,
}

-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
-- #endregion

--
--
--
--
-- State Synchronizers
--
--
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

    assert(#cs.lasers_x == Config.LASER_MAX_CAPACITY)

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
--
--
-- Update Helpers
--
--
--
--

--- @return integer|nil
--- @nodiscard
function find_inactive_creature_index()
    for i = 1, Config.CREATURE_TOTAL_CAPACITY do
        if curr_state.creatures_is_active[i] == Common.STATUS.NOT_ACTIVE then return i end
    end

    return nil
end

function find_inactive_creature_index_except(index)
    for i = 1, Config.CREATURE_TOTAL_CAPACITY do
        if curr_state.creatures_is_active[i] == Common.STATUS.NOT_ACTIVE and i ~= index then return i end
    end

    return nil
end

--- Check if two creatures are close enough to start fusion.
function check_creature_is_close_enough(index1, index2, fuse_distance)
    local cs = curr_state
    local distance = Common.manhattan_distance {
        x1 = cs.creatures_x[index1],
        y1 = cs.creatures_y[index1],
        x2 = cs.creatures_x[index2],
        y2 = cs.creatures_y[index2],
    }

    local stage_id_1 = cs.creatures_evolution_stage[index1]
    local stage_id_2 = cs.creatures_evolution_stage[index2]
    local stage_1 = Config.CREATURE_STAGES[stage_id_1]
    local stage_2 = Config.CREATURE_STAGES[stage_id_2]

    return distance < (stage_1.radius + stage_2.radius + fuse_distance)
end

function count_active_creatures()
    local counter = 0
    for i = 1, Config.CREATURE_TOTAL_CAPACITY do
        if curr_state.creatures_is_active[i] == Common.STATUS.ACTIVE then counter = counter + 1 end
    end

    return counter
end

function spawn_new_creature(new_index, parent_index, new_stage, offset)
    local cs = curr_state
    local angle1 = love.math.random() * (2 * PI)
    local angle2 = (angle1 - PI) % (2 * PI)
    local alpha = dt_accum * Config.FIXED_DT_INV
    local angle_offset = lerp(angle1, angle2, alpha)
    local parent_angle = cs.creatures_angle[parent_index]

    if cs.creatures_is_active[new_index] == Common.STATUS.ACTIVE then error 'expected to not be active' end

    cs.creatures_angle[new_index] = parent_angle + angle_offset
    cs.creatures_evolution_stage[new_index] = new_stage
    cs.creatures_is_active[new_index] = Common.STATUS.ACTIVE
    cs.creatures_x[new_index] = cs.creatures_x[parent_index]
    cs.creatures_y[new_index] = cs.creatures_y[parent_index]

    -- Avoid overlap among new creatures.
    offset = offset or Config.CREATURE_STAGES[new_stage].radius * 0.5
    cs.creatures_x[new_index] = cs.creatures_x[new_index] + love.math.random(-offset, offset)
    cs.creatures_y[new_index] = cs.creatures_y[new_index] + love.math.random(-offset, offset)
end

function emit_projectile(x, y)
    local cs = curr_state

    cs.lasers_angle[laser_index] = cs.player_rot_angle
    cs.lasers_is_active[laser_index] = Common.STATUS.ACTIVE
    cs.lasers_time_left[laser_index] = 4

    cs.lasers_x[laser_index] = x
    cs.lasers_y[laser_index] = y

    -- Laser_index tracks circular reusable buffer.
    laser_index = 1 + (laser_index % Config.LASER_MAX_CAPACITY)

    -- Reset timer to default.
    laser_fire_timer = Config.LASER_FIRE_TIMER_LIMIT
end

function fire_player_projectile() --- Fire projectile from players's position.
    if laser_fire_timer <= 0 then
        local cs = curr_state

        local player_x = cs.player_x
        local player_y = cs.player_y
        local player_rot_angle = cs.player_rot_angle

        local x_origin = player_x + math.cos(cs.player_rot_angle) * Config.PLAYER_RADIUS
        local y_origin = player_y + math.sin(cs.player_rot_angle) * Config.PLAYER_RADIUS
        emit_projectile(x_origin, y_origin)

        if player_action == Common.PLAYER_ACTION.COMPANION then
            local poly_size = Config.COMPANION_SIZE
            local dist_from_player = Config.COMPANION_DIST_FROM_PLAYER
            local x1 = player_x + math.cos(player_rot_angle) * poly_size
            local y1 = player_y + math.sin(player_rot_angle) * poly_size
            local x2 = player_x + math.cos(player_rot_angle + math.pi * 0.75) * poly_size
            local y2 = player_y + math.sin(player_rot_angle + math.pi * 0.75) * poly_size
            local x3 = player_x + math.cos(player_rot_angle - math.pi * 0.75) * poly_size
            local y3 = player_y + math.sin(player_rot_angle - math.pi * 0.75) * poly_size
            emit_projectile(x1 + dist_from_player * 0, y1 + dist_from_player * -1)
            emit_projectile(x1 + dist_from_player * 0, y1 + dist_from_player * 1)
            emit_projectile(x2 + dist_from_player * -1, y2 + dist_from_player * 0)
            emit_projectile(x3 + dist_from_player * 1, y3 + dist_from_player * 0)
        end

        sound_fire_projectile:play() -- Unconventional but works without distraction.
    end
end

local MAX_SPEED_BOOST_MULTIPLIER = 1.25
local IS_SMOOTH_BOOST = true
--- TODO: Use dash timer for Renderer to react to it, else use key event to detect dash (hack).
function boost_player_entity_speed(dt)
    local cs = curr_state
    local prev_vel_x = cs.player_vel_x
    local prev_vel_y = cs.player_vel_y
    local game_freq = lume.clamp(math.sin(4 * game_timer_t) / 2, 0., 1.)
    local ease = smoothstep(game_freq ^ 0.8, game_freq ^ 1.2, game_freq) --* PHI

    -- can use lerp here for smooth speed easing
    if IS_SMOOTH_BOOST then
        cs.player_vel_x = smoothstep(prev_vel_x, prev_vel_x * MAX_SPEED_BOOST_MULTIPLIER, ease)
        cs.player_vel_y = smoothstep(prev_vel_y, prev_vel_y * MAX_SPEED_BOOST_MULTIPLIER, ease)
    else
        cs.player_vel_x = cs.player_vel_x * MAX_SPEED_BOOST_MULTIPLIER
        cs.player_vel_y = cs.player_vel_y * MAX_SPEED_BOOST_MULTIPLIER
    end
    update_player_position_this_frame(dt) -- remember to update once
    if IS_SMOOTH_BOOST then
        cs.player_vel_x = smoothstep(cs.player_vel_x, cs.player_vel_x * Config.AIR_RESISTANCE, ease)
        cs.player_vel_y = smoothstep(cs.player_vel_y, cs.player_vel_y * Config.AIR_RESISTANCE, ease)
    else
        cs.player_vel_x = prev_vel_x
        cs.player_vel_y = prev_vel_y
    end
end

--- Mutates `player_invulnerability_timer`. Returns player damage state.
--- @param damage integer? Defaults to `1`.
--- @return PlayerDamageStatus
--- @nodiscard
local function damage_player_fetch_status(damage)
    local cs = curr_state

    local is_invulnerable = Config.IS_PLAYER_INVULNERABLE or cs.player_invulnerability_timer > 0
    if is_invulnerable then return Common.PLAYER_DAMAGE_STATUS.INVULNERABLE end

    cs.player_health = (cs.player_health - (damage or 1))

    local is_vulnerable = cs.player_health <= 0
    if is_vulnerable then return Common.PLAYER_DAMAGE_STATUS.DEAD end

    -- Reset to upper limit in range(0..1)
    cs.player_invulnerability_timer = 1
    return Common.PLAYER_DAMAGE_STATUS.DAMAGED
end

--
--
--
--
-- Uncategorized
--
--
--
--

--- @enum EngineMoveKind
local EngineMoveKind = {
    IDLE = 0,
    FORWARD = 1,
    BACKWARD = 2,
}

--- @param dt number # Delta time.
--- @param movekind EngineMoveKind
function play_player_engine_sound(dt, movekind)
    local cs = curr_state
    sound_player_engine:play()
    sound_player_engine:setVelocity(cs.player_vel_x, cs.player_vel_y, 1)
    if Config.IS_GRUG_BRAIN then
        -- Stop overlapping sound waves by making the consecutive one softer
        local curr_pos = sound_player_engine:tell 'samples'
        local last_pos = sound_player_engine:getDuration 'samples'
        if movekind == EngineMoveKind.FORWARD then
            sound_player_engine:setVolume(1.3)
            sound_player_engine:setAirAbsorption(dt) --- LOL (: warble effect due to using variable dt
        elseif movekind == EngineMoveKind.BACKWARD then
            sound_player_engine:setVolume(0.8)
            sound_player_engine:setAirAbsorption(0) --- LOL (: warble effect due to using variable dt
        elseif curr_pos >= INV_PHI * last_pos and curr_pos <= 0.99 * last_pos then
            sound_player_engine:setVolume(movekind == EngineMoveKind.FORWARD and 0.6 or 0.7)
            sound_player_engine:setAirAbsorption(10) --- LOL (: warble effect due to using variable dt
        elseif curr_pos > 0.99 * last_pos then
            sound_player_engine:setVolume(1)
            sound_player_engine:setAirAbsorption(20) --- LOL (: warble effect due to using variable dt
        end
    end
end

--- @param duration number (in seconds)
function start_fadeout_music_sci_fi_engine(duration)
    if Config.Debug.IS_ASSERT and music_sci_fi_engine:isPlaying() and (MUSIC_SCI_FI_ENGINE_VOLUME == music_sci_fi_engine:getVolume()) then
        assert(not music_sci_fi_engine_is_fading_out) -- HACK: Avoid assertion failure if key that triggers the music is not debounced.
    end
    music_sci_fi_engine_is_fading_out = true

    local fade_steps = 8 --- @type integer number of steps for fading out, adjust for smoother fades.
    local fade_steps_inv = 1 / fade_steps
    local fade_step_duration = duration * fade_steps_inv
    local step_volume = music_sci_fi_engine:getVolume() * fade_steps_inv

    local function fade_out()
        if not music_sci_fi_engine_is_fading_out then return end

        local next_step_volume = (music_sci_fi_engine:getVolume() - step_volume)
        if next_step_volume > 0 then
            music_sci_fi_engine:setVolume(next_step_volume)
        else
            -- Finalize fadeout and restore initial volume.
            next_step_volume = 0
            music_sci_fi_engine_is_fading_out = not true
            music_sci_fi_engine:stop()
            music_sci_fi_engine:setVolume(MUSIC_SCI_FI_ENGINE_VOLUME)
        end
    end

    for i = 1, fade_steps do
        Timer.after(fade_step_duration * i, fade_out)
    end
end

--- TODO: Add screen transition using a Timer.
--- TODO: Fade to black and then back to player if reset_game
--- @param status PlayerDamageStatus
function player_damage_status_actions(status)
    if status == Common.PLAYER_DAMAGE_STATUS.DEAD then
        screenshake.duration = SCREENSHAKE_DURATION.ON_DEATH
        sound_player_took_damage_interference:play()
        sound_player_took_damage:play()
        reset_game()
    elseif status == Common.PLAYER_DAMAGE_STATUS.DAMAGED then
        screenshake.duration = SCREENSHAKE_DURATION.ON_DAMAGE
        sound_player_took_damage_interference:play()
        sound_player_took_damage:play()
    elseif status == Common.PLAYER_DAMAGE_STATUS.INVULNERABLE then
        screenshake.duration = SCREENSHAKE_DURATION.ON_INVULNERABLE
        --- just use a fade in Timer here
        sound_player_engine:play() -- indicate player to move while they still can ^_^
    end -- no-op
end

--
--
--
--
-- Update Handlers
--
--
--
--

local parallax_sign1_ = ({ -1, 1 })[love.math.random(1, 2)]
local parallax_sign2_ = ({ -3, 3 })[love.math.random(1, 2)]
function update_background_shader(dt)
    local alpha = dt_accum * Config.FIXED_DT_INV
    -- local a, b, t = (parallax_sign1_ * 0.003 * alpha), (parallax_sign2_ * 0.03 * alpha), math.sin(0.003 * alpha)
    -- local smoothValue = smoothstep(a, b, t)
    -- local freq = (smoothstep(Common.sign(smoothValue) * (dt + 0.001), Common.sign(smoothValue) * (smoothValue + 0.001), 0.5))

    local speed_y = (arena_h / 32) * 0.001

    local game_freq_x = math.sin(2 * game_timer_t) / 2
    local game_freq_y = math.sin((4 + love.math.random()) * game_timer_t * 0.0625) / 4

    local vel_x = 0.25 * 0.001 * lume.clamp(game_freq_x, -1, 1)
    local vel_y = speed_y * (INV_PHI_SQ * math.abs(game_freq_y))
    vel_y = math.max(smoothstep(vel_y, 0.001 * 5, 0.4), vel_y)

    if Config.Debug.IS_ASSERT and vel_y < 0.000005 then assert(false, vel_y) end

    for i = 1, Config.PARALLAX_ENTITY_MAX_COUNT, 1 do
        local depth = parallax_entities.depth[i]
        parallax_entities.x[i] = parallax_entities.x[i] - math.sin(4 * depth * vel_x) / depth
        parallax_entities.y[i] = parallax_entities.y[i] - (vel_y / depth)
        if parallax_entities.y[i] < 0 then parallax_entities.y[i] = 1 end
    end
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

function update_player_vulnerability_timer_this_frame(dt)
    local cs = curr_state
    if cs.player_invulnerability_timer > 0 then
        cs.player_invulnerability_timer = cs.player_invulnerability_timer - dt
        if cs.player_invulnerability_timer <= 0 then cs.player_invulnerability_timer = 0 end
    end
end

-- Use dt for position updates, because movement is time-dependent
function update_player_position_this_frame(dt)
    local cs = curr_state
    cs.player_vel_x = cs.player_vel_x * Config.AIR_RESISTANCE
    cs.player_vel_y = cs.player_vel_y * Config.AIR_RESISTANCE
    cs.player_x = (cs.player_x + cs.player_vel_x * dt) % arena_w
    cs.player_y = (cs.player_y + cs.player_vel_y * dt) % arena_h
end

function update_player_trails_this_frame(dt)
    local cs = curr_state
    local ps = prev_state

    local alpha = dt_accum * Config.FIXED_DT_INV --- @type number

    -- Interpolate Player Position and Rotation (COPIED FROM `draw_player()`)
    local player_rot_angle = lerp(ps.player_rot_angle, cs.player_rot_angle, alpha)
    local player_x = lerp(ps.player_x, cs.player_x, alpha)
    local player_y = lerp(ps.player_y, cs.player_y, alpha)
    local player_vel_x = lerp(ps.player_vel_x, cs.player_vel_x, alpha)
    local player_vel_y = lerp(ps.player_vel_y, cs.player_vel_y, alpha)

    player_trails.index = (player_trails.index % Config.PLAYER_MAX_TRAIL_COUNT) + 1

    local index = player_trails.index
    player_trails.rot_angle[index] = player_rot_angle
    player_trails.vel_x[index] = player_vel_x
    player_trails.vel_y[index] = player_vel_y
    player_trails.x[index] = player_x
    player_trails.y[index] = player_y
end

function update_player_fired_projectiles_this_frame(dt)
    local cs = curr_state

    -- #region Update laser positions.

    for laser_index = 1, #cs.lasers_x do
        if cs.lasers_is_active[laser_index] == Common.STATUS.ACTIVE then
            cs.lasers_time_left[laser_index] = cs.lasers_time_left[laser_index] - dt
            if cs.lasers_time_left[laser_index] <= 0 then -- Deactivate if animation ends
                cs.lasers_is_active[laser_index] = Common.STATUS.NOT_ACTIVE
            else
                local angle = cs.lasers_angle[laser_index]
                cs.lasers_x[laser_index] = cs.lasers_x[laser_index] + math.cos(angle) * Config.LASER_PROJECTILE_SPEED * dt
                cs.lasers_y[laser_index] = cs.lasers_y[laser_index] + math.sin(angle) * Config.LASER_PROJECTILE_SPEED * dt
                if Config.IS_PLAYER_PROJECTILE_WRAP_AROUND_ARENA then
                    cs.lasers_x[laser_index] = cs.lasers_x[laser_index] % arena_w
                    cs.lasers_y[laser_index] = cs.lasers_y[laser_index] % arena_h
                elseif --[[Deactivate if it goes off screen]]
                    cs.lasers_x[laser_index] < 0
                    or cs.lasers_x[laser_index] >= arena_w
                    or cs.lasers_y[laser_index] < 0
                    or cs.lasers_y[laser_index] >= arena_h
                then
                    cs.lasers_is_active[laser_index] = Common.STATUS.NOT_ACTIVE
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

    local stages = Config.CREATURE_STAGES --- @type CreatureStage[]
    local temp_hit_counter_this_frame = 0 --- @type integer Count hits for double hit sfx.
    for laser_index = 1, #cs.lasers_x do
        if not (cs.lasers_is_active[laser_index] == Common.STATUS.ACTIVE) then --[[]]
            goto continue_not_is_active_laser
        end

        laser_circle = {
            x = cs.lasers_x[laser_index],
            y = cs.lasers_y[laser_index],
            radius = Config.LASER_RADIUS,
        }

        for creature_index = 1, Config.CREATURE_TOTAL_CAPACITY do
            if not (cs.creatures_is_active[creature_index] == Common.STATUS.ACTIVE) then --[[]]
                goto continue_not_is_active_creature
            end

            local curr_stage_id = cs.creatures_evolution_stage[creature_index] --- @type integer
            if Config.Debug.IS_ASSERT then assert(curr_stage_id >= 1 and curr_stage_id <= #stages, curr_stage_id) end

            creature_circle = {
                x = cs.creatures_x[creature_index],
                y = cs.creatures_y[creature_index],
                radius = stages[curr_stage_id].radius,
            }

            if Collision.is_intersect_circles { a = creature_circle, b = laser_circle } then
                temp_hit_counter_this_frame = temp_hit_counter_this_frame + 1

                screenshake.duration = SCREENSHAKE_DURATION.ON_LASER_HIT_CREATURE

                -- Deactivate projectile if touch creature.
                cs.lasers_is_active[laser_index] = Common.STATUS.NOT_ACTIVE
                laser_intersect_creature_counter = laser_intersect_creature_counter + 1

                if curr_stage_id == 1 then
                    laser_intersect_final_creature_counter = (laser_intersect_final_creature_counter + 1)
                    local choices = { sound_creature_healed_1, sound_creature_healed_2 }
                    local choice_index = love.math.random(1, #choices)
                    choices[choice_index]:play()
                end

                -- Deactivate current creature stage if touch creature.
                cs.creatures_is_active[creature_index] = Common.STATUS.NOT_ACTIVE
                cs.creatures_health[creature_index] = Common.HEALTH_TRANSITIONS.HEALING

                -- Split the creature into two smaller ones.
                if curr_stage_id > 1 then
                    -- Update state: initial stage is `#creature_evolution_stages`.
                    local new_stage_id = curr_stage_id - 1

                    cs.creatures_evolution_stage[creature_index] = new_stage_id
                    for i = 1, 2 do
                        local new_creature_index = find_inactive_creature_index()
                        if new_creature_index ~= nil then
                            spawn_new_creature(new_creature_index, creature_index, new_stage_id)
                        else
                            if Config.Debug.IS_TRACE_ENTITIES then --[[]]
                                print('Failed to spawn more creatures.\n', 'stage:', curr_stage_id, 'i:', i)
                            end

                            -- _Yeet_ outta this loop if we can't spawn anymore.
                            break
                        end
                    end
                end

                -- This projectile has now served it's purpose.
                break
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
    local COLLECTIBLE_SHIELD_RADIUS = Config.PLAYER_RADIUS * (1 - INV_PHI) * 3

    if cs.player_health < Config.PLAYER_MAX_HEALTH then respawn_next_shield() end

    local pos_x = player_shield_collectible_pos_x
    local pos_y = player_shield_collectible_pos_y
    local is_shield_spawned = (pos_x ~= nil and pos_y ~= nil)

    -- Avoid player to not "miss it by an inch"
    local intersect_opts = { --- @type { a:Circle, b:Circle, tolerance_factor:COLLISION_TOLERANCE}
        a = { x = cs.player_x, y = cs.player_y, radius = Config.PLAYER_RADIUS },
        b = { x = pos_x or 0, y = pos_y or 0, radius = COLLECTIBLE_SHIELD_RADIUS },
        tolerance_factor = Collision.COLLISION_TOLERANCE.OUTER_50,
    }

    local is_player_touch_shield = Collision.is_intersect_circles_tolerant(intersect_opts)
    if is_shield_spawned and is_player_touch_shield then
        if cs.player_health < Config.PLAYER_MAX_HEALTH then
            cs.player_health = cs.player_health + 1
            sound_pickup_shield:play() -- SFX
        end
        if Config.Debug.IS_ASSERT then assert(cs.player_health <= Config.PLAYER_MAX_HEALTH) end

        -- Make shield inactive.
        player_shield_collectible_pos_x = nil
        player_shield_collectible_pos_y = nil
    end
end

function update_creatures_this_frame(dt)
    -- note: better to use a wave shader for ripples
    if Config.IS_CREATURE_SWARM_ENABLED then Simulate.simulate_creatures_swarm_behavior(dt, Config.CREATURE_TOTAL_CAPACITY) end

    local cs = curr_state

    local weird_alpha = dt_accum * Config.FIXED_DT -- FIXME: how to fix this anomaly? (should be `fixed_dt_inv`)

    local player_circle = { x = cs.player_x, y = cs.player_y, radius = Config.PLAYER_RADIUS } --- @type Circle
    local creature_circle = { x = 0, y = 0, radius = 0 } --- @type Circle # hope for cache-locality

    local stages = Config.CREATURE_STAGES

    for i = 1, Config.CREATURE_TOTAL_CAPACITY do
        if Config.Debug.IS_ASSERT and (cs.creatures_health[i] == Common.HEALTH_TRANSITIONS.HEALTHY) then
            assert(cs.creatures_is_active[i] == Common.STATUS.NOT_ACTIVE)
        end

        if not (cs.creatures_is_active[i] == Common.STATUS.ACTIVE) then
            local health = cs.creatures_health[i]
            local is_slow_heal = true
            local healing_factor = is_slow_heal and 0.5 or 1
            if health >= Common.HEALTH_TRANSITIONS.HEALING and health < Common.HEALTH_TRANSITIONS.HEALTHY then
                health = health + dt * healing_factor -- increament counter
                cs.creatures_health[i] = health
            end
            if health >= Common.HEALTH_TRANSITIONS.HEALTHY then -- Creature rescued. The End.
                cs.creatures_health[i] = Common.HEALTH_TRANSITIONS.NONE -- note: using dt will make it feel too linear
            end
            goto continue
        end

        -- Update active creature
        if Config.IS_CREATURE_FOLLOW_PLAYER then --
            Simulate.simulate_creature_follows_player(dt, i)
        end
        local creature_stage_id = cs.creatures_evolution_stage[i] --- @type integer
        if Config.Debug.IS_ASSERT then assert(creature_stage_id >= 1 and creature_stage_id <= #stages) end
        local stage = stages[creature_stage_id] --- @type CreatureStage
        local angle = cs.creatures_angle[i] --- @type number
        local speed_x = lerp(stage.speed, cs.creatures_vel_x[i], weird_alpha)
        local speed_y = lerp(stage.speed, cs.creatures_vel_y[i], weird_alpha)
        local x = (cs.creatures_x[i] + math.cos(angle) * speed_x * dt) % arena_w --- @type number
        local y = (cs.creatures_y[i] + math.sin(angle) * speed_y * dt) % arena_h --- @type number
        cs.creatures_x[i] = x
        cs.creatures_y[i] = y

        -- Player collision with creature.
        creature_circle.x = x
        creature_circle.y = y
        creature_circle.radius = stage.radius
        if Collision.is_intersect_circles_tolerant { a = player_circle, b = creature_circle, tolerance_factor = Collision.COLLISION_TOLERANCE.INNER_50 } then
            player_damage_status_actions(damage_player_fetch_status())
        end

        ::continue::
    end

    -- Player won!
    if count_active_creatures() == 0 then
        if Config.Debug.IS_ASSERT then
            local cond = (Config.CREATURE_EXPECTED_FINAL_HEALED_COUNT == laser_intersect_creature_counter)
            pcall(assert, cond, (Config.CREATURE_EXPECTED_FINAL_HEALED_COUNT .. ' , ' .. laser_intersect_creature_counter))
        end
        sound_upgrade_level:play()
        game_level = (game_level % Config.GAME_MAX_LEVEL) + 1
        reset_game()
        return
    end
end

function update_on_love_keypressed(key)
    if key == Common.CONTROL_KEY.ESCAPE_KEY then
        love.event.push 'quit'
    elseif key == Common.CONTROL_KEY.TOGGLE_HUD then
        is_debug_hud_enable = not is_debug_hud_enable
    elseif key == Common.CONTROL_KEY.RESET_LEVEL then -- high priority
        reset_game()
    elseif key == Common.CONTROL_KEY.NEXT_LEVEL then
        game_level = (game_level % Config.GAME_MAX_LEVEL) + 1
        reset_game()
    elseif key == Common.CONTROL_KEY.PREV_LEVEL then
        game_level = game_level - 1
        if game_level <= 0 then game_level = Config.GAME_MAX_LEVEL end
        reset_game()
    end
end

function update_on_love_keyreleased(key)
    if key == 'space' then sound_guns_turn_off:play() end
    if key == 'x' then start_fadeout_music_sci_fi_engine(MUSIC_SCI_FI_ENGINE_FADEOUT_MAX_DURATION) end
end

local _F_REVERSE_ACCELERATION = 0.9
local _CONTROL_KEY = Common.CONTROL_KEY
local love_keyboard_isDown = love.keyboard.isDown

--- @enum ScreenshakeDuration
SCREENSHAKE_DURATION = {
    ON_BOOST = 0.05,
    ON_FIRE_LASER = 0.05,
    ON_INVULNERABLE = 0.45,
    ON_LASER_HIT_CREATURE = 0.15,
    ON_DAMAGE = 0.15 * PHI,
    ON_DEATH = 0.15 * PHI * PHI,
}

function handle_player_input_this_frame(dt)
    local cs = curr_state

    local is_stop_and_beserk_in_place = love_keyboard_isDown(_CONTROL_KEY.BESERK, _CONTROL_KEY.BESERK)
    local is_boosting = love_keyboard_isDown(_CONTROL_KEY.BOOST)
    local has_companions = love_keyboard_isDown(_CONTROL_KEY.COMPANIONS)
    local is_firing = love_keyboard_isDown(_CONTROL_KEY.FIRING)

    if love.keyboard.isDown('right', 'd') then --
        cs.player_rot_angle = cs.player_rot_angle + player_turn_speed * dt
    end
    if love.keyboard.isDown('left', 'a') then --
        cs.player_rot_angle = cs.player_rot_angle - player_turn_speed * dt
    end
    cs.player_rot_angle = cs.player_rot_angle % (2 * PI) -- wrap player angle each 360°

    -- Move player entity.
    local is_movement_enable = not is_stop_and_beserk_in_place -- or not is_boosting
    if is_movement_enable then
        if love.keyboard.isDown('up', 'w') then
            cs.player_vel_x = cs.player_vel_x + math.cos(cs.player_rot_angle) * Config.PLAYER_ACCELERATION * dt
            cs.player_vel_y = cs.player_vel_y + math.sin(cs.player_rot_angle) * Config.PLAYER_ACCELERATION * dt
            play_player_engine_sound(dt, EngineMoveKind.FORWARD)
        end

        local reverese_acceleration = Config.PLAYER_ACCELERATION * _F_REVERSE_ACCELERATION
        if love.keyboard.isDown('down', 's') then
            cs.player_vel_x = cs.player_vel_x - math.cos(cs.player_rot_angle) * reverese_acceleration * dt
            cs.player_vel_y = cs.player_vel_y - math.sin(cs.player_rot_angle) * reverese_acceleration * dt
        end
        play_player_engine_sound(dt, EngineMoveKind.BACKWARD)
    end

    if is_firing and not is_boosting then
        screenshake.duration = SCREENSHAKE_DURATION.ON_FIRE_LASER
        fire_player_projectile()
    end

    --[[Tradeoffs to aid microdecisions]]
    if is_boosting then -- Can't shoot while boosting.
        --[[TODO: Make player invulnerable while boost timer─which is unimplemented, does not runs out]]
        cs.player_invulnerability_timer = 1.0
        screenshake.duration = SCREENSHAKE_DURATION.ON_BOOST
        boost_player_entity_speed(dt)
        do
            local should_play_once = (not music_sci_fi_engine:isPlaying()) or music_sci_fi_engine_is_fading_out
            if should_play_once then sound_boost_impulse:play() end
            music_sci_fi_engine:play()
        end
    elseif is_stop_and_beserk_in_place and not has_companions then
        -- Enhance attributes while spinning like a top.
        --[[TODO: On init, emit a burst of lasers automatically. Give player some respite]]
        player_turn_speed = Config.PLAYER_TURN_SPEED * Config.PLAYER_TURN_SPEED_BESERK_MULTIPLIER
        laser_fire_timer = (love.math.random() < 0.05) and 0 or game_timer_dt
    elseif has_companions then
        player_turn_speed = Config.PLAYER_TURN_SPEED * INV_PHI_SQ
    else
        player_turn_speed = Config.PLAYER_TURN_SPEED
    end

    -- Update and assign new player action
    -- NOTE: What if the actions are actual keyboard like one-shot modes─like CAPSLOCK, so it needs to be switched that way....
    do
        if is_boosting then
            player_action = Common.PLAYER_ACTION.BOOST
        elseif has_companions then
            player_action = Common.PLAYER_ACTION.COMPANION
        elseif is_stop_and_beserk_in_place then
            player_action = Common.PLAYER_ACTION.BESERK
        elseif is_firing then
            player_action = Common.PLAYER_ACTION.FIRING -- since we are firing
        else
            player_action = Common.PLAYER_ACTION.IDLE
        end
    end
end

--
--
--
--
-- Drawing Renderer
--
--
--
--

local dest_trail_color = { 0, 0, 0 } --- WARN: Initialize zero value (this is then mutated)
function draw_player_trail(alpha)
    local IS_ENLARGE_PLAYER_TRAIL_ON_DAMAGE = true

    local f = 0. --- @type number Any factor
    local invulnerability_timer = curr_state.player_invulnerability_timer

    if player_action == Common.PLAYER_ACTION.COMPANION then
        LG.setColor(Common.COLOR.player_companion_modifier)
    elseif player_action == Common.PLAYER_ACTION.BESERK then
        LG.setColor(Common.COLOR.player_beserker_modifier)
    elseif player_action == Common.PLAYER_ACTION.BOOST then
        LG.setColor(Common.COLOR.player_boost_dash_modifier)
    else
        LG.setColor(Common.COLOR.player_entity_firing_projectile)
    end

    local thickness = Config.PLAYER_TRAIL_THICKNESS
    local frequency = 440 -- Hz
    local amplitude = 1
    local wiggle_rate = 1.0
    local wiggle_freq = alpha
    -- local game_freq = math.sin(game_timer_t * 8) / 8
    local game_freq = lume.clamp(math.sin(8 * game_timer_t) / 8, 0., 1.)
    wiggle_freq = smoothstep(wiggle_freq, game_freq, game_freq)

    local last_f = 0.
    local NI = Config.PLAYER_MAX_TRAIL_COUNT
    for i = NI, 1, -1 do -- iter in reverse
        -- local radius = lerp(thickness, thickness + (amplitude * math.sin(frequency * i)), alpha) -- original
        local radius = lerp(thickness, thickness + (amplitude * math.sin(wiggle_rate * frequency * i)), wiggle_freq)

        if Config.Debug.IS_ASSERT then assert(invulnerability_timer <= 1) end

        if invulnerability_timer > 0 then -- tween -> swell or shrink up
            local radius_tween = ((radius + (IS_ENLARGE_PLAYER_TRAIL_ON_DAMAGE and 8 or -8)) - radius) * invulnerability_timer
            -- radius = lerp(radius + radius_tween, radius, alpha)
            radius = lerp(radius + radius_tween, radius, game_freq)
        end

        if player_action == Common.PLAYER_ACTION.COMPANION then
            f = i ^ 1.2
            f = smoothstep(i, PHI * i, game_freq)
            f = -f ^ 0.1
            last_f = f
            LG.circle('line', player_trails.x[i], player_trails.y[i], radius * f)
        elseif player_action == Common.PLAYER_ACTION.BESERK then
            f = smoothstep(last_f < 0.4 and lume.clamp(last_f, 0.4, 2) or last_f, radius, game_freq) * i
            f = 1.5 * smoothstep(-f ^ 0.8, -f ^ 0.3, game_freq)
            last_f = f
            LG.circle('line', player_trails.x[i], player_trails.y[i], radius * f)
        elseif player_action == Common.PLAYER_ACTION.BOOST then
            f = smoothstep(last_f < 0.4 and lume.clamp(last_f, 0.4, 2) or last_f, radius, game_freq) * i
            f = lume.clamp((f / (i ^ 1.2)), 0, 1)
            last_f = f
            LG.circle('line', player_trails.x[NI + 1 - i], player_trails.y[NI + 1 - i], radius * f ^ 1.2)
            LG.circle('line', player_trails.x[NI + 1 - i], player_trails.y[NI + 1 - i], radius * f ^ 1.2)
        else
            f, last_f = 1, 1
            LG.circle('fill', player_trails.x[i], player_trails.y[i], radius)
        end
    end
end

--- Excellent for predicting visually where player might end up.. like a lookahead (great for dodge!)
function draw_player_direction_ray(alpha)
    local IS_PLAYER_RAY_CASTED = true
    local PLAYER_RAY_RADIUS = Config.PLAYER_RADIUS * (1 - INV_PHI) * 0.5
    local PLAYER_RAY_COLOR = { 1, 1, 1 } -- { 0.6, 0.6, 0.6, 0.15 }
    local AIR_RESISTANCE = Config.AIR_RESISTANCE

    local cs = curr_state

    local ray_x = lerp(prev_state.player_x, cs.player_x, alpha)
    local ray_y = lerp(prev_state.player_y, cs.player_y, alpha)

    local ray_vel_x = 0
    local ray_vel_y = 0
    local hack_len_short_factor = 0.5
    ray_vel_x = lerp(prev_state.player_vel_x, cs.player_vel_x * AIR_RESISTANCE, alpha)
    ray_vel_y = lerp(prev_state.player_vel_y, cs.player_vel_y * AIR_RESISTANCE, alpha)
    ray_vel_x = ray_vel_x * hack_len_short_factor + math.cos(cs.player_rot_angle) * Config.PLAYER_ACCELERATION * game_timer_dt
    ray_vel_y = ray_vel_y * hack_len_short_factor + math.sin(cs.player_rot_angle) * Config.PLAYER_ACCELERATION * game_timer_dt

    -- #region why are we using this?
    do
        ray_x = (ray_x + ray_vel_x * game_timer_dt) % arena_w
        ray_y = (ray_y + ray_vel_y * game_timer_dt) % arena_h
    end
    -- #endregion

    if IS_PLAYER_RAY_CASTED then
        ray_x = (ray_x + ray_vel_x * AIR_RESISTANCE) % arena_w
        ray_y = (ray_y + ray_vel_y * AIR_RESISTANCE) % arena_h

        LG.setColor(PLAYER_RAY_COLOR)
        LG.line(cs.player_x, cs.player_y, ray_x, ray_y)
    else -- jump to dot
        local last_ray_radius_if_multiple_rays = 2
        for i = -1, 1, 1 do
            -- Like the flash of a torch on zz ground...
            local ease = (0.125 - (i * 0.0125 * INV_PHI))
            ray_x = (ray_x + ray_vel_x * ease) % arena_w
            ray_y = (ray_y + ray_vel_y * ease) % arena_h
            local curr_radius = PLAYER_RAY_RADIUS + (ease * math.log(i) * last_ray_radius_if_multiple_rays)

            LG.setColor(PLAYER_RAY_COLOR)
            LG.circle('fill', ray_x, ray_y, curr_radius)
        end
    end
end

function draw_player(alpha)
    local cs = curr_state
    local IS_EYE_TWINKLE_ENABLE = true

    -- Frequency-based visual effect
    -- local juice_frequency = 1 + math.sin(Config.FIXED_FPS * game_timer_dt)
    local game_freq = lume.clamp(math.sin(4 * game_timer_t) / 4, 0., 1.)
    local juice_frequency = 1 + game_freq
    local juice_frequency_damper = lerp(0.0625, 0.125, alpha)

    -- #1: Interpolate Player Position and Rotation
    local player_rot_angle = lerp(prev_state.player_rot_angle, cs.player_rot_angle, alpha)
    local player_x = lerp(prev_state.player_x, cs.player_x, alpha)
    local player_y = lerp(prev_state.player_y, cs.player_y, alpha)
    local player_vel_x = lerp(prev_state.player_vel_x, cs.player_vel_x, alpha)
    local player_vel_y = lerp(prev_state.player_vel_y, cs.player_vel_y, alpha)
    local player_radius = Config.PLAYER_RADIUS

    -- #2: Firing Position and Trigger Radius
    local fire_pos_x = player_x + math.cos(player_rot_angle) * Config.PLAYER_FIRING_EDGE_MAX_RADIUS
    local fire_pos_y = player_y + math.sin(player_rot_angle) * Config.PLAYER_FIRING_EDGE_MAX_RADIUS
    local firing_trigger_radius = Config.PLAYER_FIRING_EDGE_RADIUS
    local invulnerability_timer = cs.player_invulnerability_timer
    local trigger_radius = smoothstep(firing_trigger_radius - 1, firing_trigger_radius, game_freq)

    if invulnerability_timer > 0 then
        trigger_radius = smoothstep(trigger_radius + (2 * invulnerability_timer), trigger_radius + invulnerability_timer, game_freq * invulnerability_timer)
    end

    -- #3: Eye Twinkle Effect
    if IS_EYE_TWINKLE_ENABLE then
        local inertia_x, inertia_y = 0, 0
        if love.keyboard.isDown('up', 'w') then
            inertia_x = player_vel_x + math.cos(player_rot_angle) * Config.PLAYER_ACCELERATION * game_timer_dt
            inertia_y = player_vel_y + math.sin(player_rot_angle) * Config.PLAYER_ACCELERATION * game_timer_dt
        end

        local is_player_going_backwards = love.keyboard.isDown('down', 's')
        if is_player_going_backwards then
            inertia_x = player_vel_x - math.cos(player_rot_angle) * Config.PLAYER_ACCELERATION * game_timer_dt
            inertia_y = player_vel_y - math.sin(player_rot_angle) * Config.PLAYER_ACCELERATION * game_timer_dt
        end

        inertia_x = player_vel_x * Config.AIR_RESISTANCE
        inertia_y = player_vel_y * Config.AIR_RESISTANCE

        -- Apply inertia adjustments to firing position
        local dfactor = (is_player_going_backwards and 0.125 or 0.35)
        local amplitude_factor = 0.328
        fire_pos_x = fire_pos_x - (dfactor * amplitude_factor * Config.PLAYER_FIRING_EDGE_MAX_RADIUS) * (inertia_x * game_timer_dt)
        fire_pos_y = fire_pos_y - (dfactor * amplitude_factor * Config.PLAYER_FIRING_EDGE_MAX_RADIUS) * (inertia_y * game_timer_dt)
    end

    -- #4: Draw Player Shape and Companion Effects
    if player_action == Common.PLAYER_ACTION.COMPANION then
        local prev_line_width = LG.getLineWidth()
        LG.setLineWidth(2.5 * (1 + math.abs(invulnerability_timer)))

        local pos_x_, pos_y_ = player_x, player_y
        local poly_size = Config.COMPANION_SIZE -- dest size
        local dist_from_player = Config.COMPANION_DIST_FROM_PLAYER

        -- Draw player triangle
        local x1 = pos_x_ + math.cos(player_rot_angle) * poly_size
        local y1 = pos_y_ + math.sin(player_rot_angle) * poly_size
        local x2 = pos_x_ + math.cos(player_rot_angle + math.pi * 0.75) * poly_size
        local y2 = pos_y_ + math.sin(player_rot_angle + math.pi * 0.75) * poly_size
        local x3 = pos_x_ + math.cos(player_rot_angle - math.pi * 0.75) * poly_size
        local y3 = pos_y_ + math.sin(player_rot_angle - math.pi * 0.75) * poly_size

        -- Triangle color same as companion mode??
        -- PERF: Batch draw companions.
        do
            -- LG.setColor(Common.PLAYER_ACTION_TO_DESATURATED_COLOR[player_action])
            LG.setColor(0.8, 0.9, 1.0)
        end

        -- Draw companion pulse effect
        local has_companion = true
        if has_companion then
            local game_pulse_freq = lume.clamp(lume.pingpong(math.abs(invulnerability_timer)) + game_freq, 0, 1)
            local f_size = 1 * smoothstep(PHI, PHI_SQ, game_pulse_freq)
            if not Config.IS_GRUG_BRAIN then
                f_size = 1. -- f_size = player_radius / 4
            end

            --[[PERF: Use lookup table of hard-coded coordinates. See `fire_player_projectile`]]
            for y = -1, 1 do
                for x = -1, 1 do
                    if x == 0 and y == 0 then goto continue_skip_origin end
                    if x == 0 or y == 0 then --[[]]
                        local nx = f_size * dist_from_player * x
                        local ny = f_size * dist_from_player * y
                        LG.polygon('line', x1 + nx, y1 + ny, x2 + nx, y2 + ny, x3 + nx, y3 + ny)
                        if Config.Debug.IS_TRACE_HUD or is_debug_hud_enable then LG.print('' .. x .. ' ' .. y, arena_w - 100 + x * 32, 100 + y * 32) end
                    end
                    ::continue_skip_origin::
                end
            end
        else
            LG.polygon('line', x1, y1, x2, y2, x3, y3)
        end

        LG.setLineWidth(prev_line_width)
    end

    -- #5: Interpolation and Shield Effects
    if cs.player_health == 1 and love.math.random() < 0.1 * alpha then
        LG.setColor(Common.COLOR.creature_healing)
        LG.circle('fill', player_x, player_y, player_radius)
    end

    -- #6: Draw Inner Eye (Iris) and Firing Edge
    local player_iris_radius = Config.PLAYER_RADIUS * Config.PLAYER_CIRCLE_IRIS_TO_EYE_RATIO * (1 + juice_frequency * juice_frequency_damper)
    if cs.player_invulnerability_timer > 0 then
        player_iris_radius = lerp(player_iris_radius, player_iris_radius * 1.382, cs.player_invulnerability_timer * alpha)
    end

    LG.setColor(Common.COLOR.player_entity)
    LG.circle('fill', player_x, player_y, player_iris_radius)

    LG.setColor(Common.COLOR.player_entity_firing_edge_dark)
    LG.circle('fill', fire_pos_x, fire_pos_y, trigger_radius)
end

function draw_plus_icon(x_, y_, size_, linewidth)
    local half_size = size_ * 0.5
    -- Draw horizontal line.
    LG.setLineWidth(linewidth or 2)
    LG.line(x_ - half_size, y_, x_ + half_size, y_)
    -- Draw vertical line.
    LG.line(x_, y_ - half_size, x_, y_ + half_size)
end

local COLLECTIBLE_SHIELD_RADIUS = Config.PLAYER_RADIUS * (1 - INV_PHI) * 3

function draw_player_shield_collectible(alpha)
    local pos_x = player_shield_collectible_pos_x
    local pos_y = player_shield_collectible_pos_y

    local is_spawned_shield = (pos_x ~= nil and pos_y ~= nil)
    if not is_spawned_shield then -- exists
        return
    end

    --- @cast pos_x number
    --- @cast pos_y number

    local glowclr = Common.COLOR.player_dash_pink_modifier
    local freq = 127 -- Hz
    local tween_fx = lerp(0.05, INV_PHI * math.sin(alpha * freq), alpha / math.min(0.4, game_timer_dt * math.sin(alpha)))
    local tween = lerp(PHI, 2 * PHI * math.sin(alpha * freq), alpha)
    do
        local radius = (COLLECTIBLE_SHIELD_RADIUS * (1.2 + math.sin(0.03 * alpha)) + tween)
        LG.setColor(glowclr[1], glowclr[2], glowclr[3], 1.0 - math.sin(0.03 * alpha)) -- LG.setColor { 0.9, 0.9, 0.4 }
        LG.circle('fill', pos_x, pos_y, radius)
    end

    local fxclr = Common.COLOR.player_entity
    LG.setColor(fxclr[1], fxclr[2], fxclr[3], 0.2)
    LG.circle('fill', pos_x, pos_y, COLLECTIBLE_SHIELD_RADIUS + tween_fx)

    LG.setColor(1, 1, 1, 0.2)
    draw_plus_icon(pos_x, pos_y, COLLECTIBLE_SHIELD_RADIUS + tween_fx)

    LG.setColor(fxclr)
    LG.circle('fill', pos_x, pos_y, COLLECTIBLE_SHIELD_RADIUS + tween)

    LG.setColor(1, 1, 1)
    draw_plus_icon(pos_x, pos_y, COLLECTIBLE_SHIELD_RADIUS + tween)

    LG.setColor(1, 1, 1) -- reset
end

function _draw_active_projectile(i, alpha)
    local prev_player_action = player_action --- @type PlayerAction

    local pos_x = curr_state.lasers_x[i]
    local pos_y = curr_state.lasers_y[i]

    if prev_state.lasers_is_active[i] == Common.STATUS.ACTIVE then
        pos_x = lerp(prev_state.lasers_x[i], pos_x, alpha)
        pos_y = lerp(prev_state.lasers_y[i], pos_y, alpha)
    end

    -- Add sprite to batch with position, rotation, scale and color
    local scale = 1 --- Scale based on original `LASER_RADIUS`.
    local origin_x = Config.LASER_RADIUS
    local origin_y = Config.LASER_RADIUS
    local rgb = Common.PLAYER_ACTION_TO_COLOR[player_action] or { 0.4, 0.4, 0.4 }
    laser_sprite_batch:setColor(rgb) --- @diagnostic disable-line: param-type-mismatch
    laser_sprite_batch:add(pos_x, pos_y, 0, scale, scale, origin_x, origin_y)

    -- Since we are firing‥‥
    do
        player_action = prev_player_action
    end
end

function draw_player_fired_projectiles(alpha)
    laser_sprite_batch:clear()
    for i = 1, #curr_state.lasers_x do
        if curr_state.lasers_is_active[i] == Common.STATUS.ACTIVE then _draw_active_projectile(i, alpha) end
    end
    LG.setColor(1, 1, 1, 1) -- reset color before drawing
    LG.draw(laser_sprite_batch) -- draw all sprites in one batch
end

local MAX_CREATURE_RADIUS_INV = 1 / Config.CREATURE_MAX_RADIUS
function _draw_active_creature(i, alpha)
    local cs = curr_state

    local curr_x = cs.creatures_x[i]
    local curr_y = cs.creatures_y[i]
    local evolution_stage = Config.CREATURE_STAGES[cs.creatures_evolution_stage[i]] --- @type CreatureStage
    local radius = evolution_stage.radius --- @type integer

    -- Add sprite to batch with position, rotation, scale and color
    local scale = radius * MAX_CREATURE_RADIUS_INV
    local origin_x = radius
    local origin_y = radius
    local rgb = Common.COLOR.creature_infected -- !!!! can this paint them individually with set color

    -- creatures_sprite_batch:setColor(rgb[1], rgb[2], rgb[3], 1.) ---@diagnostic disable-line: param-type-mismatch
    creatures_sprite_batch:setColor(0.03, 0.03, 0.03) ---@diagnostic disable-line: param-type-mismatch
    creatures_sprite_batch:add(curr_x, curr_y, 0, scale, scale, origin_x, origin_y) -- x, y, ?, sx, sy, ox, oy (origin x, y 'center of the circle')
end

function _draw_not_active_creature(i, alpha)
    local cs = curr_state

    local game_freq = math.sin(game_timer_t * 8) / 8

    local curr_x = cs.creatures_x[i]
    local curr_y = cs.creatures_y[i]
    local evolution_stage_id = cs.creatures_evolution_stage[i]
    local evolution_stage = Config.CREATURE_STAGES[evolution_stage_id] --- @type CreatureStage
    local radius = evolution_stage.radius
    local scale = radius * MAX_CREATURE_RADIUS_INV --- since sprite batch item has radius of largest creature

    -- Automatically disappear when the `find_inactive_creature_index` looks them up and then `spawn_new_creature` mutates them.
    local is_not_moving = prev_state.creatures_x[i] ~= curr_x and prev_state.creatures_y[i] ~= curr_y
    local corner_offset = Config.PLAYER_RADIUS + evolution_stage.radius

    local health = cs.creatures_health[i]
    local is_away_from_corner = (
        curr_x >= 0 + corner_offset
        and curr_x <= arena_w - corner_offset
        and curr_y >= 0 + corner_offset
        and curr_y <= arena_h - corner_offset
    )
    local is_healing = (
        (cs.creatures_is_active[i] == Common.STATUS.NOT_ACTIVE)
        and health > Common.HEALTH_TRANSITIONS.HEALING
        and health <= Common.HEALTH_TRANSITIONS.HEALTHY
    )
    if (is_away_from_corner or is_not_moving) and is_healing then
        local juice_frequency = 1 + math.sin(Config.FIXED_FPS * game_timer_dt)

        -- Add sprite to batch with position, rotation, scale and color
        local origin_x = radius
        local origin_y = radius
        local _sx = scale
        local _sy = scale
        do
            local __is_overide = true
            if __is_overide or Config.IS_GRUG_BRAIN then
                local shrinkage = lume.clamp(cs.creatures_health[i], -radius, 0.200)
                local shrink_factor = lume.clamp(shrinkage, 0, 1)
                local s_lo = scale - INV_PHI * shrink_factor
                local s_hi = scale - PHI * shrink_factor
                _sx = smoothstep(s_lo, s_hi, game_freq)
                _sy = smoothstep(s_lo, s_hi, game_freq)
            end
        end

        -- !!!! can this paint them individually with set color
        -- FIXME: If color passed has an alpha channel, this will panic
        local rgb = Common.COLOR.creature_healed
        rgb = Common.CREATURE_STAGE_EYE_COLORS[1]
        -- creatures_sprite_batch:setColor(rgb[1], rgb[2], rgb[3])
        -- creatures_sprite_batch:add(curr_x, curr_y, 0, _sx, _sy, origin_x, origin_y) -- x, y, ?, sx, sy, ox, oy (origin x, y 'center of the circle')

        -- creatures_sprite_batch:setColor(0.9, 0.2, 0.3)
        creatures_sprite_batch:setColor(rgb[1], rgb[2] * INV_PHI, rgb[3] * INV_PHI, 0.8)
        creatures_sprite_batch:add(curr_x, curr_y, 0, _sx, _sy, origin_x, origin_y) -- x, y, ?, sx, sy, ox, oy (origin x, y 'center of the circle')

        -- PERF: Use a different sprite batch for healed departing creature
        -- THIS LEADS TO +1000 batch calls
        -- Draw final creature evolution on successful healing with '+' symbol.
        if Config.IS_GAME_SLOW then
            local smooth_alpha = lerp((1 - INV_PHI), alpha, INV_PHI)
            if smooth_alpha < Config.INV_PHI then --- avoid janky alpha fluctuations per game basis
                local juice_frequency_damper = lerp(0.25, 0.125, alpha)
                local radius_factor = (1 + smooth_alpha * juice_frequency * lerp(1, juice_frequency_damper, smooth_alpha))
                local radius = evolution_stage.radius * radius_factor

                LG.setColor(Common.COLOR.creature_healing)
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

local _IS_CREATURES_BLINK_ENABLE = not true
--- PERF: Use sprite batch for eyes
function draw_creatures_eye(alpha)
    local cs = curr_state

    local game_freq = math.sin(2 * game_timer_t)
    game_freq = lume.clamp(game_freq, 0., 1.)

    for i = 1, #cs.creatures_x do
        if cs.creatures_is_active[i] == Common.STATUS.ACTIVE then
            local evolution_stage_id = cs.creatures_evolution_stage[i] --- @type integer
            local evolution_stage = Config.CREATURE_STAGES[evolution_stage_id] --- @type CreatureStage

            local radius = evolution_stage.radius --- @type integer
            local angle = cs.creatures_angle[i] --- @type number

            -- Draw creatures eye.
            LG.setColor(1, 1, 1)
            local stage_offset = Config.CREATURE_STAGES_COUNT - evolution_stage_id
            local size = (stage_offset * radius / 4)

            local is_initial_stage = stage_offset == 0
            if not is_initial_stage then
                if Config.Debug.IS_ASSERT then assert(evolution_stage_id ~= Config.CREATURE_STAGES_COUNT) end
                size = size + (radius / evolution_stage_id) / stage_offset
            end

            local x = cs.creatures_x[i] + size
            local y = cs.creatures_y[i] + size

            -- Random blinking
            do
                local DX = 0.05
                local DY = 0.05
                x = smoothstep(x + -DX * size, x + DX * size, game_freq)
                y = smoothstep(y + -DY * size, y + DY * size, game_freq)

                if love.math.random() < 0.005 then
                    x = smoothstep(x - game_freq, x + game_freq, game_freq)
                    y = smoothstep(y - game_freq, y + game_freq, game_freq)
                end
            end

            if evolution_stage_id == Config.CREATURE_STAGES_COUNT then
                local poly_size = PHI * radius / evolution_stage_id

                game_freq = game_freq * 0.9 / i

                local x1 = x + math.cos(angle + game_freq) * poly_size -- pointy x
                local y1 = y + math.sin(angle + game_freq) * poly_size -- pointy y
                local x2 = x + math.cos(angle + math.pi * 0.75 + game_freq) * poly_size
                local y2 = y + math.sin(angle + math.pi * 0.75 + game_freq) * poly_size
                local x3 = x + math.cos(angle - math.pi * 0.75 + game_freq) * poly_size
                local y3 = y + math.sin(angle - math.pi * 0.75 + game_freq) * poly_size

                LG.setColor(0.2, 0.3, 0.4)
                LG.polygon('line', x1, y1, x2, y2, x3, y3) -- star like glitter edge

                LG.setColor(Common.CREATURE_STAGE_EYE_COLORS[evolution_stage_id])
                LG.circle('fill', x, y, PHI * radius * INV_PHI_SQ * INV_PHI)
            else
                local radius_ = radius * INV_PHI_SQ * INV_PHI
                LG.setColor(Common.CREATURE_STAGE_EYE_COLORS[evolution_stage_id])

                if _IS_CREATURES_BLINK_ENABLE then
                    local radius_blink = 0
                    local f_blink_speed_damper = 2 -- 1..infinity
                    local f_blink_ease = 4
                    local f_blink_rate = lume.clamp(f_blink_speed_damper * math.sin(((i % 11) % 9 + f_blink_ease * game_freq)), 0, 1)
                    radius_blink = smoothstep(radius_, -0.4, f_blink_rate)
                    -- if radius_blink < 0.7 then radius_blink = 0 end
                    local is_eye_shut = radius_blink < 0.2
                    if is_eye_shut then radius_blink = 0 end
                    if not is_eye_shut then
                        radius_blink = lume.clamp(radius_blink, 0.00, radius_ * (1 + INV_PHI_SQ))
                        LG.ellipse('fill', x, y, radius_, radius_blink)
                    end
                    -- Draw actual eyes no blinking
                    if Config.Debug.IS_DEVELOPMENT then LG.circle('line', x, y, radius * INV_PHI_SQ * INV_PHI) end
                else
                    -- Draw actual eyes no blinking
                    LG.circle('fill', x, y, radius * INV_PHI_SQ * INV_PHI)
                end
            end
        end
    end
end

--- FIXME: Creature still on screen after laser collision, after introducing batch draw
---             USE separate batches to draw active and non_active creatures
function draw_creatures(alpha)
    local cs = curr_state

    creatures_sprite_batch:clear() -- clear previous frame's creatures_sprite_batch from canvas

    for i = 1, #cs.creatures_x do
        if cs.creatures_is_active[i] == Common.STATUS.ACTIVE then
            _draw_active_creature(i, alpha)
        else
            _draw_not_active_creature(i, alpha)
        end
    end
    LG.setColor(1, 1, 1, 1) -- Reset color before drawing
    LG.draw(creatures_sprite_batch) -- Draw all sprites in one batch

    draw_creatures_eye(alpha)
end

local _parallax_draw_offset_x = 0
local _parallax_draw_offset_y = 0
local _parallax_entity_alpha_color = ({ (INV_PHI ^ (Config.IS_GAME_SLOW and -1 or -1)) * 0.56, 0.7, 1.0 })[Config.CURRENT_THEME]
local _is_follow_player_parallax = not true

--- Stats:
---     Without sprite batch:        draw calls 2474 for (2^8 entities)
---     With sprite batch:           draw calls  162 for (2^8 entities)
function draw_background_shader(alpha)
    local cs = curr_state
    local dx = 0
    local dy = 0
    if _is_follow_player_parallax then
        _parallax_draw_offset_x = cs.player_x / arena_w -- FIXME: should lerp on wrap
        _parallax_draw_offset_y = cs.player_y / arena_h
        dx = _parallax_draw_offset_x * Config.PARALLAX_OFFSET_FACTOR_X
        dy = _parallax_draw_offset_y * Config.PARALLAX_OFFSET_FACTOR_Y
    end

    bg_parallax_sprite_batch:clear() -- Clear and update sprite batch

    for i = 1, Config.PARALLAX_ENTITY_MAX_COUNT do
        local depth_inv = parallax_entities.depth[i]
        local radius = parallax_entities.radius[i]
        local x = (parallax_entities.x[i] - (dx * depth_inv)) * arena_w
        local y = (parallax_entities.y[i] - (dy * depth_inv)) * arena_h
        local point_alpha = _parallax_entity_alpha_color * depth_inv

        -- Add sprite to batch with position, rotation, scale and color
        local scale = radius * 0.03125 -- Scale based on original circle radius as 32 was parallax entity image size
        bg_parallax_sprite_batch:setColor(1.0, 1.0, 1.0, point_alpha)
        bg_parallax_sprite_batch:add(x, y, 0, scale, scale, radius, radius) -- origin x, y (center of the circle)
    end

    LG.setColor(1, 1, 1, 1) -- Reset color before drawing
    LG.draw(bg_parallax_sprite_batch) -- Draw all sprites in one batch
end

local _IS_SCREENFLASH_ENABLE = true -- (TODO: Make it optional, and sensory warning perhaps?)
local _SCREENFLASH_FROM_SCREENSHAKE_MIN_DURATION = 0.125
local _SCREENFLASH_FROM_SCREENSHAKE_MAX_DURATION = 0.96
local _SCREENFLASH_ALPHA = Common.SCREEN_FLASH_ALPHA_LEVEL.LOW
local _SCREENFLASH_COLOR = { 0.1, 0.1, 0.1, _SCREENFLASH_ALPHA }

function draw_screenshake_fx(alpha)
    local screenshake_duration = screenshake.duration
    if screenshake_duration <= 0 then return end

    -- Simulate screenflash.
    local is_snappy_interval = (screenshake_duration >= _SCREENFLASH_FROM_SCREENSHAKE_MIN_DURATION)
        and (screenshake_duration <= _SCREENFLASH_FROM_SCREENSHAKE_MAX_DURATION)
    if _IS_SCREENFLASH_ENABLE and is_snappy_interval then
        LG.setColor(_SCREENFLASH_COLOR)
        LG.rectangle('fill', 0, 0, arena_w, arena_h)
    end

    -- Simulate screenshake.
    LG.translate(screenshake.offset_x, screenshake.offset_y)
end

local temp_last_ouch_x = nil
local temp_last_ouch_y = nil
local temp_ouch_messages = { 'OUCH!', 'OWW!', 'HEYY!' }
local temp_last_ouch_message_index = love.math.random(1, MAX_TEMP_OUCH_MESSAGES)
local MAX_TEMP_OUCH_MESSAGES = #temp_ouch_messages

--- Draws horizontal status bar for player statistics that includes health, invulnerability timer.
--- @param alpha number
function draw_player_status_bar(alpha)
    local cs = curr_state

    local bar_width = 2 ^ 8 -- Example width
    local bar_height = 2 ^ 3 -- Example height
    local bar_x = (arena_w * 0.5) - (bar_width * 0.5) -- X position on screen
    local bar_y = bar_height * 2 * PHI -- Y position on screen

    local sw = 1 -- scale width
    local sh = 1 -- scale height

    local invulnerability_timer = cs.player_invulnerability_timer
    local curr_health_percentage = (cs.player_health / Config.PLAYER_MAX_HEALTH)
    if Config.Debug.IS_ASSERT then assert(curr_health_percentage >= 0.0 and curr_health_percentage <= 1.0) end

    -- Draw health bar.
    do
        local prev_health_percentage = (prev_state.player_health / Config.PLAYER_MAX_HEALTH)
        local interpolated_health = lerp(prev_health_percentage, curr_health_percentage, alpha)
        if Config.IS_GRUG_BRAIN and invulnerability_timer > 0 then -- @juice: inflate/deflate health bar
            sh = lerp(sh * 0.95, sh * 1.25, invulnerability_timer * alpha)
        end
        -- Draw missing health part.
        LG.setColor(Common.COLOR.creature_healing) -- red
        LG.rectangle('fill', bar_x, bar_y, bar_width * sw, bar_height * sh)
        -- Draw current health part.
        LG.setColor(0.95, 0.95, 0.95) -- white
        LG.rectangle('fill', bar_x, bar_y, (bar_width * interpolated_health) * sw, bar_height * sh)
    end

    -- Draw invulnerability timer.
    do
        if invulnerability_timer > 0 then
            if temp_last_ouch_x == nil and temp_last_ouch_y == nil then
                temp_last_ouch_x = cs.player_x + Config.PLAYER_RADIUS - 4
                temp_last_ouch_y = cs.player_y - Config.PLAYER_RADIUS - 4
                temp_last_ouch_message_index = math.floor(love.math.random(1, MAX_TEMP_OUCH_MESSAGES)) --- WARN: Is the random output inclusive?
                assert(temp_last_ouch_message_index >= 1 and temp_last_ouch_message_index <= MAX_TEMP_OUCH_MESSAGES)
            else
                LG.setColor(Common.COLOR.player_dash_pink_modifier) -- white
                LG.print(temp_ouch_messages[temp_last_ouch_message_index], temp_last_ouch_x, temp_last_ouch_y)
            end
            local invulnerability_bar_height = bar_height * INV_PHI * 0.5
            LG.setColor(0.95, 0.95, 0.95, 0.1) -- white
            LG.rectangle('fill', bar_x, bar_y + bar_height * sh, bar_width * sw, invulnerability_bar_height * sh) -- missing health
            local invulnerable_tween = invulnerability_timer
            if Config.IS_GRUG_BRAIN then invulnerable_tween = lerp(invulnerability_timer - game_timer_dt, invulnerability_timer, alpha) end
            LG.setColor(Common.COLOR.player_boost_dash_modifier) -- recharging ...
            LG.rectangle('fill', bar_x, bar_y + bar_height * sh, (bar_width * invulnerable_tween) * sw, 1 + invulnerability_bar_height * sh) -- current invulnerability
        else
            temp_last_ouch_x = nil
            temp_last_ouch_y = nil
        end
    end

    LG.setColor(1, 1, 1) -- reset color to default
end

function draw_timer_text()
    local text = string.format('%.2f', game_timer_t)
    local tw, th = font:getWidth(text), font:getHeight()

    local x = (arena_w * 0.5)
    local y = 14

    if Config.IS_GRUG_BRAIN then
        -- Draw rounded rectangle button like backdrop.
        local game_freq = math.sin(game_timer_t * 4) / 4
        local f = lume.clamp((1 + game_freq), INV_PHI, PHI)
        f = smoothstep(f, 1 + f * INV_PHI_SQ, f ^ 1.2)
        -- Save state.
        local blend_mode = LG.getBlendMode()
        LG.setBlendMode('lighten', 'premultiplied')
        LG.setColor(0.2, 0.2, 0.2, 0.5)
        local rect_w = tw * (INV_PHI + 0.15)
        LG.rectangle('fill', x - rect_w * 0.5, y - th * f, rect_w, th * f * 2)
        LG.circle('fill', x - rect_w * 0.5, y, th * f)
        LG.circle('fill', x + rect_w * 0.5, y, th * f)
        -- Restore state.
        LG.setBlendMode(blend_mode)
    end

    -- Draw timer text.
    LG.setColor(1, 1, 1)
    LG.print(text, x, y, 0., 1., 1., tw * 0.5, th * 0.5)
end

function draw_keybindings_text()
    local x = 16
    local y = arena_h - 32

    local cs = curr_state
    local player_x = cs.player_x
    local player_y = cs.player_y
    local target_distance = 300

    -- Calculate wrapped distance along the x and y axis.
    local dx = math.min(math.abs(player_x - x), arena_w - math.abs(player_x - x))
    local dy = math.min(math.abs(player_y - y), arena_h - math.abs(player_y - y))

    -- Calculate the Manhattan distance using wrapped coordinates
    local distance = dx + dy
    if distance <= target_distance then
        local f = lume.clamp(math.min(1.0, (target_distance - distance) / target_distance), 0.0, 1.)
        LG.setColor(1., 1., 1., 1. * f)
        LG.print([[Z-beserk  X-boost  C-companions SPC-fire]], x, y, 0., 0.9, 0.9)
    end
end

function draw_debug_general_hud()
    local cs = curr_state

    local hud_h = 128
    local hud_w = 150
    local pad_x = 16 -- horizontal
    local pad_y = 16 -- vertical
    local pos_x = arena_w - hud_w
    local pos_y = 0
    LG.setColor(Common.COLOR.TEXT_DARKEST)
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

    if Config.Debug.IS_DEVELOPMENT and Config.Debug.IS_TRACE_HUD then
        LG.print(
            table.concat({
                'love.timer.getFPS() ' .. love.timer.getFPS(),
                'dt_accum ' .. string.format('%.6f', dt_accum),
                'alpha ' .. string.format('%f', dt_accum * Config.FIXED_DT_INV),
                'active_creatures ' .. count_active_creatures(),
                'invulnerability_timer ' .. cs.player_invulnerability_timer,
            }, '\n'),
            1 * pos_x - (hud_w * 0.25) + pad_x,
            (arena_h * 0.5) - 1 * pos_y + hud_h + pad_y
        )
    end

    LG.setColor(1, 1, 1) -- reset color
end

function draw_debug_stats_hud()
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
        if value == Common.STATUS.ACTIVE then --
            active_counter = active_counter + 1
        end
    end

    LG.setColor(Common.COLOR.TEXT_DEBUG_HUD)
    LG.print(
        table.concat({
            'curr_state.creatures.active: ' .. active_counter,
            -- FIXME: This does not decrease as we allocate and increase the buffer size at each level increment.
            'curr_state.creatures.count: ' .. #cs.creatures_x,
            'initial_large_creatures_this_game_level: ' .. initial_large_creatures_this_game_level,
            'buffer creatures.count: ' .. #cs.creatures_x,
            'drone.vel_x: ' .. drone.vel_x,
            'drone.vel_y: ' .. drone.vel_y,
            'drone.x: ' .. drone.x,
            'drone.y: ' .. drone.y,
            'player.angle: ' .. cs.player_rot_angle,
            'player.vel_x: ' .. cs.player_vel_x,
            'player.vel_y: ' .. cs.player_vel_y,
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
--
--
-- The Game Update & Draw Loops
--
--
--
--

function update_game(dt) ---@param dt number # Fixed delta time.
    handle_player_input_this_frame(dt)
    update_background_shader(dt)
    update_player_vulnerability_timer_this_frame(dt)
    update_player_position_this_frame(dt)
    update_player_trails_this_frame(dt)
    update_player_fired_projectiles_this_frame(dt)
    update_player_shield_collectible_this_frame(dt)
    update_creatures_this_frame(dt)

    if curr_state.player_invulnerability_timer > 0 then
        music_bgm:setEffect('on_damage_lowpass', true)
        music_bgm:setEffect('on_damage_reverb', true)
    else
        music_bgm:setEffect('on_damage_lowpass', not true)
        music_bgm:setEffect('on_damage_reverb', not true)
    end

    -- #1 Update drone
    do
        local DRONE_ACCELERATION = Config.PLAYER_ACCELERATION
        local accel = DRONE_ACCELERATION
        local air_resist = Config.AIR_RESISTANCE

        -- Pathfind to player.
        do
            dist_btw_player_and_drone = Common.manhattan_distance { x1 = curr_state.player_x, y1 = curr_state.player_y, x2 = drone.x, y2 = drone.y }

            do -- NAIVE closing sddistance [[follow the player without touching]]
                drone.x = smoothstep(drone.x, curr_state.player_x, 0.1)
                drone.y = smoothstep(drone.y, curr_state.player_y, 0.1)
            end
        end

        -- Update drone AI input.
        drone.rot_angle = PI + curr_state.player_rot_angle
        drone.vel_x = drone.vel_x + math.cos(drone.rot_angle) * accel * dt
        drone.vel_y = drone.vel_y + math.sin(drone.rot_angle) * accel * dt

        -- Update position.
        drone.vel_x = drone.vel_x * air_resist
        drone.vel_y = drone.vel_y * air_resist
        drone.x = (drone.x + drone.vel_x * dt) % arena_w
        drone.y = (drone.y + drone.vel_y * dt) % arena_h

        do -- Synchronize
            prev_drone.rot_angle = drone.rot_angle
            prev_drone.vel_x = drone.vel_x
            prev_drone.vel_y = drone.vel_y
            prev_drone.x = drone.x
            prev_drone.y = drone.y
        end
    end
end

--- FIXME: When I set a refresh rate of 75.00 Hz on a 800 x 600 (4:3)
--- monitor, alpha seems to be faster -> which causes the juice frequency to
--- fluctute super fast
function draw_game(alpha)
    draw_screenshake_fx(alpha)
    draw_creatures(alpha)
    draw_keybindings_text()
    draw_player_fired_projectiles(alpha)
    draw_player_trail(alpha)
    if Config.Debug.IS_TRACE_HUD or is_debug_hud_enable then --[[]]
        draw_player_direction_ray(alpha)
    end
    draw_player_shield_collectible(alpha)
    draw_player(alpha)
    curr_state:draw_player_collectible_indicators(alpha)

    -- WIP: DRONE
    do
        -- #2 Draw drone
        do
            do --interpolate
                drone.vel_x = lerp(prev_drone.vel_x, drone.vel_x, alpha)
                drone.vel_y = lerp(prev_drone.vel_y, drone.vel_y, alpha)
                drone.x = lerp(prev_drone.x, drone.x, alpha) % arena_w
                drone.y = lerp(prev_drone.y, drone.y, alpha) % arena_h
            end
            LG.setColor(1.0, 0.3, 0.4)
            LG.circle('fill', drone.x, drone.y, drone.radius)
        end
        if dist_btw_player_and_drone ~= nil then
            --
            LG.print(string.format('[%.2f] dist_btw_player_and_drone', dist_btw_player_and_drone), 100, 100)
        end
    end
end

local COLLECTIBLE_INDICATOR_FONT_SCALE_FACTOR = 1.75
local COLLECTIBLE_INDICATOR_OFFSET_FROM_PLAYER = 16

local _t_points_player_and_collectible = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
local __TEMP_OVERRIDE_DEBUG_POLAR_COORDS__ = not true
function curr_state:draw_player_collectible_indicators(alpha)
    --[[  UPDATE  ]]

    local src_x = self.player_x
    local src_y = self.player_y
    local dest_x = player_shield_collectible_pos_x
    local dest_y = player_shield_collectible_pos_y

    local is_spawn = dest_x ~= nil and dest_y ~= nil
    if is_spawn then
        --- @cast dest_x number
        --- @cast dest_y number

        -- Get distance, angle between player and collectible.
        local _t = _t_points_player_and_collectible
        do
            -- Does this help with caching?
            _t.x1 = src_x
            _t.y1 = src_y
            _t.x2 = dest_x
            _t.y2 = dest_y
        end

        local dist = Common.manhattan_distance(_t_points_player_and_collectible)
        local dx = _t.x2 - _t.x1
        local dy = _t.y2 - _t.y1
        --[[@diagnostic disable-next-line: deprecated # WARN: math.atan leads to weird behavior]]
        local angle = math.atan2(dy, dx)

        --[[  DRAW  ]]

        -- Draw indicator.
        local game_freq = lume.clamp(math.sin(8 * game_timer_t) / 8, 0., 1.)
        local f_scale = COLLECTIBLE_INDICATOR_FONT_SCALE_FACTOR
        local scale0 = smoothstep(f_scale - game_freq, f_scale + game_freq, game_freq)

        -- Just enough to avoid overlapping with player trail
        local ox = -COLLECTIBLE_INDICATOR_OFFSET_FROM_PLAYER
        local oy = COLLECTIBLE_INDICATOR_OFFSET_FROM_PLAYER

        LG.setColor(0.1, 1., 0.4, 1)
        LG.print('»', src_x, src_y, angle, scale0, scale0, ox, oy)

        -- Debug coordinates.
        if __TEMP_OVERRIDE_DEBUG_POLAR_COORDS__ or (Config.Debug.IS_TRACE_ENTITIES and Config.Debug.IS_DEVELOPMENT) then
            LG.setColor(1, 1, 0, 0.8)
            LG.line(src_x, src_y, _t.x2, _t.y2)
            LG.setColor(0, 1, 1, 1.0)
            LG.print(('%.2f dist'):format(dist), _t.x2, _t.y2, (PI * 0.5) + angle, PHI, PHI, -8, -8)
            LG.setColor(0.2, 1.0, 0.8)
            LG.print(('%.2f rad'):format(angle), _t.x2, _t.y2, angle, 2, 2, -4, 4)
            LG.setColor(0.5, 0.5, 0.8, 1.0)
            LG.print(('%.2f deg'):format(math.deg(angle)), _t.x2, _t.y2, (0.25 * PI) + angle, 2.5, 2.5)
        end
    end
end

--
--
--
--
-- FILE IO
--
--
--
--

function load_audio()
    local on_hit_play_coin = not true
    if on_hit_play_coin then
        sound_creature_healed_1 = (love.audio.newSource('resources/audio/sfx/statistics_pickup_coin3.wav', 'static')) -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
        sound_creature_healed_1:setPitch(1.50) -- tuned close to `music_bgm`'s key
        sound_creature_healed_1:setVolume(0.625)
        sound_creature_healed_2 = (love.audio.newSource('resources/audio/sfx/statistics_pickup_coin3_1.wav', 'static')) -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
        sound_creature_healed_2:setPitch(1.50) -- tuned close to `music_bgm`'s key
        sound_creature_healed_2:setVolume(0.625)
        sound_fire_combo_hit = love.audio.newSource('resources/audio/sfx/animal_happy_bird.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
        sound_fire_combo_hit:setPitch(0.85)
        sound_fire_combo_hit:setVolume(INV_PHI ^ 4)
    else
        sound_creature_healed_1 = (love.audio.newSource('resources/audio/sfx/wip/laser_jsfxr.wav', 'static'))
        sound_creature_healed_1:setPitch(INV_PHI ^ 2)
        sound_creature_healed_1:setVolume(INV_PHI)
        sound_creature_healed_2 = (love.audio.newSource('resources/audio/sfx/wip/laser_final_jsfxr.wav', 'static'))
        sound_creature_healed_2:setPitch(INV_PHI ^ 2)
        sound_creature_healed_2:setVolume(INV_PHI)
        -- sound_fire_combo_hit = love.audio.newSource('resources/audio/sfx/animal_happy_bird.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
        sound_fire_combo_hit = (love.audio.newSource('resources/audio/sfx/wip/laser_explosion_jsfxr.wav', 'static'))
        sound_fire_combo_hit:setPitch(INV_PHI ^ 0)
        sound_fire_combo_hit:setVolume(INV_PHI ^ 5)
    end

    sound_pickup_shield = love.audio.newSource('resources/audio/sfx/wip/powerup_jsfxr.wav', 'static') -- stream and loop background music
    sound_pickup_shield:setVolume(1)

    sound_pickup_holy = love.audio.newSource('resources/audio/sfx/pickup_holy.wav', 'static') -- stream and loop background music
    sound_pickup_holy:setVolume(0.9) -- 90% of ordinary volume
    sound_pickup_holy:setPitch(0.5) -- one octave lower
    sound_pickup_holy:setVolume(0.6)
    -- sound_pickup_holy:play()                                                                               -- PLAY AT GAME START once

    sound_guns_turn_off = love.audio.newSource('resources/audio/sfx/machines_guns_turn_off.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io
    sound_guns_turn_off:setEffect 'bandpass'
    sound_guns_turn_off:setVolume(INV_PHI ^ 4)

    sound_player_took_damage_interference = love.audio.newSource('resources/audio/sfx/machines_interference.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
    sound_player_took_damage_interference:setPitch(INV_PHI ^ -3)
    sound_player_took_damage_interference:setVolume(0.5)
    sound_player_took_damage = love.audio.newSource('resources/audio/sfx/wip/laser_final_jsfxr.wav', 'static')
    sound_player_took_damage:setPitch(INV_PHI ^ 2.5)
    sound_player_took_damage:setVolume(1)

    sound_player_beserk = (love.audio.newSource('resources/audio/sfx/statistics_upgrade.wav', 'static')) -- Dash Sound Effect by ArTiX.0 -- https://freesound.org/s/742717/ -- License: Creative Commons 0
    sound_player_beserk:setPitch(INV_PHI ^ 1)
    sound_player_beserk:setVolume(INV_PHI ^ 2)

    -- sound_fire_projectile = love.audio.newSource('resources/audio/sfx/select_sound.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
    -- sound_fire_projectile:setPitch(1.15)
    -- sound_fire_projectile:setVolume(PHI_INV)
    sound_fire_projectile = love.audio.newSource('resources/audio/sfx/wip/laser_jsfxr.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
    sound_fire_projectile:setPitch(INV_PHI ^ 1)
    sound_fire_projectile:setVolume(INV_PHI ^ 3)

    sound_player_engine = love.audio.newSource('resources/audio/sfx/atmosphere_dive.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io
    sound_player_engine:setPitch(0.6)
    sound_player_engine:setVolume(0.5)
    sound_player_engine:setFilter { type = 'lowpass', volume = 1, highgain = (3 * 0.5) }
    sound_player_engine:setVolume(INV_PHI ^ 8)

    sound_ui_menu_select = love.audio.newSource('resources/audio/sfx/menu_select.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
    sound_ui_menu_select:setVolume(INV_PHI)

    -- sound_upgrade_level = love.audio.newSource('resources/audio/sfx/statistics_upgrade.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
    sound_upgrade_level = love.audio.newSource('resources/audio/sfx/select_sound.wav', 'static') -- Credit to DASK: Retro sounds https://dagurasusk.itch.io/retrosounds
    sound_upgrade_level:setVolume(3)

    sound_boost_impulse = (love.audio.newSource('resources/audio/sfx/585256__lesaucisson__swoosh-2.mp3', 'static')) -- swoosh-2.mp3 by lesaucisson -- https://freesound.org/s/585256/ -- License: Creative Commons 0
    sound_boost_impulse:setPitch(INV_PHI ^ 0)
    sound_boost_impulse:setVolume(INV_PHI ^ 0)

    --- Audio Drone

    sound_atmosphere_tense = (love.audio.newSource('resources/audio/sfx/atmosphere_tense_atmosphere_1.wav', 'static')) -- Credit to DASK: Retro
    sound_atmosphere_tense:setVolume(INV_PHI ^ 4)

    --- Note: `stream` option ─ stream and loop background music
    music_bgms = {
        love.audio.newSource('resources/audio/music/ross_bugden_chime_chase.wav', 'stream'),
        love.audio.newSource('resources/audio/music/ross_bugden_silver_seven_step.mp3', 'stream'),
    }
    local _is_skip_load_bgm = true
    if not _is_skip_load_bgm then --[[OLDER MUSIC]]
        --- Background Music Credit:
        ---     • [Lupus Nocte](http://link.epidemicsound.com/LUPUS)
        ---     • [YouTube Link](https://youtu.be/NwyDMDlZrMg?si=oaFxm0LHqGCiUGEC)
        table.insert(music_bgms, love.audio.newSource('resources/audio/music/lupus_nocte_arcadewave.mp3', 'stream'))
    end

    -- Effects
    do
        local on_damage_lowpass_effect_opts =
            { type = 'equalizer', highcut = 4000, highgain = 0.126, highmidgain = 0.126, lowgain = 2, lowmidfrequency = 500, lowmidgain = 0.126, volume = 2.0 }
        love.audio.setEffect('on_damage_lowpass', on_damage_lowpass_effect_opts) -- Create a low-pass filter effect -- see https://love2d.org/wiki/EffectType

        -- frequency: `default: 800` ─ I want a hollow eerie effect (100 is great for ross_bugden_chime_chase)
        -- highcut: ... use a freq which is consistently playing (1000Hz)
        --- @alias Waveform 'sine' | 'square' | 'sawtooth'
        local waveform = 'sine'--[[@type Waveform]]
        local on_damage_effect_opts =
            { type = 'ringmodulator', frequency = 100, highcut = lume.clamp(450, 0, 24000), waveform = waveform, volume = INV_PHI ^ 4 }
        love.audio.setEffect('on_damage_reverb', on_damage_effect_opts)

        local master_effect_opts = { type = 'reverb' } --[[decaytime = lume.clamp(1.49 * (PHI * 1), 0.1, 20), roomrolloff = lume.clamp(PHI, 0, 10), gain = 0.32 * PHI_INV, volume = PHI_INV, ]]
        love.audio.setEffect('master_reverb', master_effect_opts)
    end

    do
        music_bgm = music_bgms[love.math.random(1, #music_bgms)]
        do
            music_bgm:setEffect('master_reverb', true)
            music_bgm:setFilter { type = 'highpass', volume = 6, lowgain = 6 }
            music_bgm:setPitch(1.0) -- one octave lower
            music_bgm:setVolume(1.0 * (Config.Debug.IS_DEVELOPMENT and (1 * INV_PHI) or 1))
            music_bgm:setLooping(true)
        end
    end

    music_ambience_underwater = (love.audio.newSource('resources/audio/sfx/255597__akemov__underwater-ambience.wav', 'stream')) -- underwater ambience by akemov -- https://freesound.org/s/255597/ -- License: Attribution 4.0
    music_ambience_underwater:setVolume(1.0)
    music_ambience_underwater:setPitch(2.0)
    music_ambience_underwater:setLooping(true)

    music_sci_fi_engine = (love.audio.newSource('resources/audio/sfx/136672__fedexico__sci-fi-engine-light-cycle.wav', 'stream')) -- underwater ambience by akemov -- https://freesound.org/s/255597/ -- License: Attribution 4.0
    music_sci_fi_engine:setVolume(INV_PHI ^ 1)
    MUSIC_SCI_FI_ENGINE_VOLUME = music_sci_fi_engine:getVolume()
    music_sci_fi_engine_volume_current = MUSIC_SCI_FI_ENGINE_VOLUME

    -- Sci-Fi Engine - Light Cycle.wav by fedexico -- https://freesound.org/s/136672/ -- License: Attribution 3.0
    music_sci_fi_engine_is_fading_out = not true
    music_sci_fi_engine_fade_timer = 0

    MUSIC_SCI_FI_ENGINE_FADEOUT_MAX_DURATION = 0.750
    music_sci_fi_engine_fadeout_duration = MUSIC_SCI_FI_ENGINE_FADEOUT_MAX_DURATION
end

function load_shaders()
    Shaders = require 'shaders'

    --- @class (exact) GlslShaders
    --- @field gradient_basic love.Shader
    --- @field gradient_timemod love.Shader
    --- @field lighting_phong love.Shader
    --- @field warp love.Shader
    glsl_shaders = {
        gradient_basic = LG.newShader(Shaders.bg_gradient.glsl_frag),
        gradient_timemod = LG.newShader 'shaders/bg_gradient_time_modulate.frag',
        lighting_phong = LG.newShader 'shaders/phong_lighting.frag',
        warp = LG.newShader 'shaders/warp.frag',
    }

    -- Load moonshine shaders
    local moonshine = require 'lib.moonshine'
    local fx = moonshine.effects

    --- @class (exact) MoonshineShaders
    --- @field fog table
    moonshine_shaders = {
        fog = moonshine(arena_w, arena_h, fx.fog).chain(fx.desaturate) --[[ desaturate removes ocataves(frequency) lines ]],
    }

    -- Setup moonshine shaders
    if true then
        moonshine_shaders.fog.fog.fog_color = { 0.0, 0.1, 0.0 }
        moonshine_shaders.fog.fog.speed = { 0.2, 0.9 }
        moonshine_shaders.fog.fog.octaves = 1
    end
end

--- Function: Global game state reset function (handle with care).
function reset_game()
    -- Reset game states.
    do
        curr_state.player_invulnerability_timer = 0
        curr_state.player_health = Config.PLAYER_MAX_HEALTH
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
    end

    -- Reset decorative data structures.
    do
        for i = 1, Config.PLAYER_MAX_TRAIL_COUNT do
            player_trails.x[i] = 0
            player_trails.y[i] = 0
            player_trails.vel_x[i] = 0
            player_trails.vel_y[i] = 0
            player_trails.rot_angle[i] = 0
            player_trails.is_active[i] = Common.STATUS.NOT_ACTIVE
            player_trails.time_left[i] = 0
        end

        for i = 1, Config.LASER_MAX_CAPACITY do
            curr_state.lasers_angle[i] = 0
            curr_state.lasers_is_active[i] = Common.STATUS.NOT_ACTIVE
            curr_state.lasers_time_left[i] = Config.LASER_FIRE_TIMER_LIMIT
            curr_state.lasers_x[i] = 0
            curr_state.lasers_y[i] = 0
        end
    end

    -- Initialize and setup creatures.
    do
        -- HACK: Avoid exponential overpopulation initial creatures.
        do
            -- FIXME: THIS IS NOT IN CONFIGURATION (did not notice it while renaming ^_^) -- FIXME: vvv Avoiding exponential-like (not really) overpopulation
            initial_large_creatures_this_game_level = Config.CREATURE_INITIAL_CONSTANT_LARGE_STAGE_COUNT * game_level
            initial_large_creatures_this_game_level = (math.floor(Config.CREATURE_INITIAL_CONSTANT_LARGE_STAGE_COUNT * (game_level ^ (1 / 4))))

            -- FIXME: Should not modify Configuration!!!!  --[[AUTO-UPDATE]]
            EXPECTED_FINAL_HEALED_CREATURE_COUNT = ((initial_large_creatures_this_game_level ^ 2) - initial_large_creatures_this_game_level) --[[@type integer # This count excludes the initial ancestor count.]]
            Config.CREATURE_TOTAL_CAPACITY = 2 * (initial_large_creatures_this_game_level ^ 2) --[[@type integer # Double buffer size of possible creatures count i.e. `initial count ^ 2`]]
        end

        local _largest_creature_stage = #Config.CREATURE_STAGES
        local _not_active_status = Common.STATUS.NOT_ACTIVE

        -- Pre-allocate all creature's including stage combinations.
        for i = 1, Config.CREATURE_TOTAL_CAPACITY do
            curr_state.creatures_angle[i] = 0
            curr_state.creatures_evolution_stage[i] = _largest_creature_stage
            curr_state.creatures_health[i] = 0
            curr_state.creatures_is_active[i] = _not_active_status
            curr_state.creatures_x[i] = 0
            curr_state.creatures_y[i] = 0
            curr_state.creatures_vel_x[i] = 0
            curr_state.creatures_vel_y[i] = 0
        end

        local _active_status = Common.STATUS.ACTIVE
        -- Activate initial creatures.
        for i = 1, initial_large_creatures_this_game_level do
            curr_state.creatures_angle[i] = love.math.random() * Config.TWO_PI
            curr_state.creatures_evolution_stage[i] = _largest_creature_stage -- Start at smallest stage
            curr_state.creatures_health[i] = -1 --[[-1 to 0 to 1.... like dash timer, or fade timer ( -1 to 0 to 1 )]]
            curr_state.creatures_is_active[i] = _active_status
            curr_state.creatures_vel_x[i] = 0
            curr_state.creatures_vel_y[i] = 0
            -- Avoid creature spawning at window corners. (when value is 0)
            do -- FIXME: Ensure creature doesn't intersect with player at new level load
                curr_state.creatures_x[i] = love.math.random(32, arena_w - 32)
                curr_state.creatures_y[i] = love.math.random(32, arena_h - 32)
            end
        end
    end

    -- Reset declared global variables.
    do
        game_timer_dt = 0.0
        game_timer_t = 0.0

        laser_fire_timer = 0
        laser_index = 1 -- circular buffer index (duplicated below!)
        laser_intersect_creature_counter = 0 -- count creatures collision with laser... coin like
        laser_intersect_final_creature_counter = 0 -- count tiniest creature to save─collision with laser

        player_fire_cooldown_timer = 0
        player_turn_speed = Config.PLAYER_TURN_SPEED

        player_shield_collectible_pos_x = nil --- @type number|nil
        player_shield_collectible_pos_y = nil --- @type number|nil
    end

    -- Copy once and Synchronize state.
    do
        copy_game_state(prev_state, curr_state)
        sync_prev_state()
        if Config.Debug.IS_ASSERT then --[[Sane assumptions]]
            assert(laser_index == 1)
        end
        if Config.Debug.IS_ASSERT then--[[Match prev_state with curr_state]]
            assert_consistent_state()
        end
    end
end --< reset_game()

--
--
--
--
-- LOVE - [Open in Browser](https://love2d.org/wiki/love)
--
--
--
--

function love.load()
    -- #1 Set LOVE defaults.
    do
        -- Smoother edges.
        love.graphics.setDefaultFilter('linear', 'linear')

        -- Disabled by default.
        love.keyboard.setKeyRepeat(true)
    end

    -- #2 Copy once from global variables declared in `conf.lua`.
    do
        arena_h = gh
        arena_w = gw
    end

    -- #3 Initialize font/audio/shader/spritebatch assets
    do
        font = LG.getFont()

        load_audio()

        load_shaders()

        -- Load sprite batches.
        local graphics_util = require 'drawutil'
        bg_parallax_sprite_batch = graphics_util.SpriteBatchFn.make_bg_parallax_entities() --- @type love.SpriteBatch
        creatures_sprite_batch = graphics_util.SpriteBatchFn.make_creatures() --- @type love.SpriteBatch
        laser_sprite_batch = graphics_util.SpriteBatchFn.make_lasers() --- @type love.SpriteBatch
    end

    -- #4 Initialize global variables.
    do
        creature_swarm_range = Config.PLAYER_RADIUS * 4 -- FIXME: should be evolution_stage.radius specific
        dt_accum = 0.0 --- @type number Accumulator keeps track of time passed between frames.
        game_level = 1 --- @type integer
        is_debug_hud_enable = not true --- Toggled on key `h` `keyDown` event.
        player_action = Common.PLAYER_ACTION.IDLE --- @type PlayerAction
        screenshake = { amount = 5 * 0.5 * Config.INV_PHI, duration = 0.0, offset_x = 0.0, offset_y = 0.0, wait = 0.0 } --[[@type ScreenShake]]

        -- Global variables that **must** be reset at each level.
        do
            game_timer_dt = 0.0
            game_timer_t = 0.0
            laser_fire_timer = 0
            laser_index = 1 -- circular buffer index (duplicated below!)
            laser_intersect_creature_counter = 0 -- count creatures collision with laser... coin like
            laser_intersect_final_creature_counter = 0 -- count tiniest creature to save─collision with laser
            player_fire_cooldown_timer = 0
            player_shield_collectible_pos_x = nil --- @type number|nil
            player_shield_collectible_pos_y = nil --- @type number|nil
            player_turn_speed = Config.PLAYER_TURN_SPEED
        end
    end

    -- #5 Initialize parallax entities.
    do
        for i = 1, Config.PARALLAX_ENTITY_MAX_COUNT do
            parallax_entities.x[i] = love.math.random() --- 0.0..1.0
            parallax_entities.y[i] = love.math.random() --- 0.0..1.0
            local depth = love.math.random(Config.PARALLAX_ENTITY_MIN_DEPTH, Config.PARALLAX_ENTITY_MAX_DEPTH)
            parallax_entities.depth[i] = depth
            parallax_entities.radius[i] = Config.PARALLAX_ENTITY_RADIUS_FACTOR * math.ceil(math.sqrt(depth) * (Config.PARALLAX_ENTITY_MAX_DEPTH / depth))
        end
        if not true then
            local condition = #parallax_entities.x == math.sqrt(#parallax_entities.x) * math.sqrt(#parallax_entities.x)
            assert(condition, 'Assert count of parallax entity is a perfect square')
        end
    end

    -- #6 Reset the game (once!) on load.
    reset_game()

    -- #7 Apply final touches before takeoff.
    do
        -- WARN: Background shaders over-write this... but this may be useful for menus...
        LG.setBackgroundColor(0.1, 0.1, 0.1) -- or (Common.COLOR.BACKGROUND)

        -- Set master volume.
        love.audio.setVolume(not Config.Debug.IS_DEVELOPMENT and 1.0 or 0.5) -- volume # number # 1.0 is max and 0.0 is off.

        -- Play music and effects once/looped once on load.
        sound_upgrade_level:play()
        music_ambience_underwater:play()
    end
end --< love.load()

function love.update(dt)
    if Config.Debug.IS_DEVELOPMENT then -- FIXME: Maybe make stuff global that are not hot-reloading?
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
    do
        local screen_w, screen_h = LG.getDimensions()
        -- glsl_shaders.gradient_timemod:send('screen', { screen_w, screen_h })
        -- glsl_shaders.gradient_timemod:send('time', love.timer.getTime())
        glsl_shaders.warp:send('screen', { screen_w, screen_h })
        glsl_shaders.warp:send('time', love.timer.getTime())
        moonshine_shaders.fog.fog.time = love.timer.getTime()
    end

    -- #4 Frame Rate Independence: Fixed timestep loop.
    local fixed_dt = Config.FIXED_DT
    dt_accum = dt_accum + dt
    while dt_accum >= fixed_dt do
        sync_prev_state()
        update_game(fixed_dt)
        dt_accum = dt_accum - fixed_dt
    end

    -- #5 Update any other frame-based effects (e.g., screen shake).
    update_screenshake(dt)
end --< love.update()

function love.draw()
    --- Interpolation factor between previous and current state.
    --- @type number
    local alpha = dt_accum * Config.FIXED_DT_INV

    if Config.Debug.IS_ASSERT then
        assert_consistent_state() --> sanity check
    end

    -- #1 Draw Background shader effects.
    --
    -- • Warp shader pixels to work with.
    -- • Draw interactive parallax.
    --   • Layer 0 : Draw fog shader
    --   • Layer 1 : Draw rectangle mask dropback glow around player
    --   • Layer 2 : Shine on star diamonds when around player
    local blend_mode = LG.getBlendMode()
    LG.setBlendMode('screen', 'premultiplied') --> set `screen` blend mode
    LG.setShader(glsl_shaders.warp) --> set `warp` shader
    do
        LG.rectangle('fill', 0, 0, arena_w, arena_h)
        LG.setBlendMode('add', 'premultiplied') --> set `add` blend mode
        do
            moonshine_shaders.fog(function() end)
            Shaders.phong_lighting.shade_any_to_player_pov(function()
                LG.rectangle('fill', 0, 0, arena_w, arena_h)
                draw_background_shader(alpha)
            end)
        end
        LG.setBlendMode('screen', 'premultiplied') --< reset `add` blend  mode
    end
    LG.setShader() --< end of `warp` shader
    LG.setBlendMode(blend_mode) --< end of 'screen' blend mode

    -- #2 Draw game.
    --
    -- • Objects that are partially off the edge of the screen can be seen on the other side.
    -- • Translate coordinate system to different positions and draw everything at each position around the screen and in the center.
    -- • Draw off-screen object partially wrap around without glitch
    for y = -1, 1 do
        for x = -1, 1 do
            LG.origin()
            LG.translate(x * arena_w, y * arena_h)
            draw_game(alpha)
            LG.origin()
        end
    end

    -- #3 Draw textual and HUD elements.
    draw_timer_text()
    draw_player_status_bar(alpha)

    -- #4 Draw debugging tools.
    --
    -- • Toggled on `h` `keyDown` event.
    if is_debug_hud_enable then
        draw_debug_general_hud()
        draw_debug_stats_hud()
    end
end --< love.draw()

function love.keypressed(key) update_on_love_keypressed(key) end

function love.keyreleased(key) update_on_love_keyreleased(key) end

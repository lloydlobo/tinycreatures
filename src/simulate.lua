local M = {}

local common = require 'common'
local config = require 'config'

local lerp = common.lerp

--- Calculate the vector from the creature to the player.
--- Normalize the vector and multiply it by a speed factor.
--- Optionally, limit the turn rate to avoid making them too aggressive.
function M.simulate_creature_follows_player(dt, creature_index)
    local cs = curr_state

    local dir_x = cs.player_x - cs.creatures_x[creature_index]
    local dir_y = cs.player_y - cs.creatures_y[creature_index]
    local dist_btw = math.sqrt(dir_x * dir_x + dir_y * dir_y)
    if dist_btw > 0 then
        dir_x = dir_x / dist_btw
        dir_y = dir_y / dist_btw
    end

    local stage_id = cs.creatures_evolution_stage[creature_index]
    local max_turn_speed = 1000
    local creature_speed = config.CREATURE_STAGES[stage_id].speed
    local turn_factor = math.min(creature_speed * dt, max_turn_speed * dt)

    --100000 * lerp(player_turn_speed * .5, creature_speed * .5, PHI_INV) --- FIXME: TEMPORARY
    -- local creature_turn_speed = player_turn_speed * 1000000
    local angle = cs.creatures_angle[creature_index]
    local sx = math.cos(angle) * cs.creatures_vel_x[creature_index] * dt
    local sy = math.sin(angle) * cs.creatures_vel_y[creature_index] * dt
    if config.IS_GRUG_BRAIN then
        dir_x = lerp(dir_x, math.abs(dir_x + sx), turn_factor * dt)
        dir_y = lerp(dir_y, math.abs(dir_y + sy), turn_factor * dt)
    end

    cs.creatures_vel_x[creature_index] = lerp(cs.creatures_vel_x[creature_index], dir_x * creature_speed, turn_factor)
    cs.creatures_vel_y[creature_index] = lerp(cs.creatures_vel_y[creature_index], dir_y * creature_speed, turn_factor)
end

--- NOTE: Does not mutate position.
function M.simulate_creatures_swarm_behavior(dt, total)
    local alpha = dt_accum * config.FIXED_DT_INV

    local cs = curr_state
    for creature_index = 1, total do
        if cs.creatures_is_active[creature_index] == common.Status.active then
            local group_center_x = 0
            local group_center_y = 0
            local count = 0
            local creature_stage_id = cs.creatures_evolution_stage[creature_index] --- @type integer
            local creature_stage = config.CREATURE_STAGES[creature_stage_id] --- @type CreatureStage
            -- local creature_swarm_range = creature_stage.radius --- @type integer # TEMPORARY solution
            local creature_x = cs.creatures_x[creature_index]
            local creature_y = cs.creatures_y[creature_index]

            -- use dt here?
            local creature_group_factor = 0.4 --- @type number|integer # TEMPORARY solution

            for other_creature_index = 1, total do
                if cs.creatures_is_active[other_creature_index] == common.Status.active then
                    local other_creature_x = cs.creatures_x[other_creature_index]
                    local other_creature_y = cs.creatures_y[other_creature_index]
                    local other_creature_stage_id = cs.creatures_evolution_stage[other_creature_index] --- @type integer
                    local other_creature_stage = config.CREATURE_STAGES[other_creature_stage_id] --- @type CreatureStage

                    local dist = nil
                    if creature_x ~= nil and creature_y ~= nil and other_creature_x ~= nil and other_creature_y ~= nil then
                        dist = common.manhattan_distance {
                            x1 = creature_x,
                            y1 = creature_y,
                            x2 = other_creature_x,
                            y2 = other_creature_y,
                        }
                    end

                    if creature_index ~= other_creature_index and dist ~= nil and (dist <= creature_swarm_range) then
                        group_center_x = group_center_x + cs.creatures_x[other_creature_index]
                        group_center_y = group_center_y + cs.creatures_y[other_creature_index]
                        count = count + 1
                        do
                            local __is_log_enabled = false
                            if __is_log_enabled and config.Debug.IS_TRACE_ENTITIES and love.math.random() < 0.05 then
                                print(dist, creature_swarm_range, creature_index, other_creature_index, count)
                            end
                        end
                    end

                    local __is_swarm_damped = dist >= (2 * creature_swarm_range) -- temporary
                    if count > 0 and __is_swarm_damped then
                        group_center_x = group_center_x / count
                        group_center_y = group_center_y / count
                        local curr_vel_x = cs.creatures_vel_x[creature_index]
                        local curr_vel_y = cs.creatures_vel_y[creature_index]
                        local factor = love.math.random() < 0.5 and dt or creature_group_factor
                        do -- TEMPORARY OVERIDE
                            factor = lerp(other_creature_stage.radius, creature_stage.radius, config.INV_PHI) -- somewhat like gravitational pull
                            local is_level_difficulty_hard = false
                            if is_level_difficulty_hard then
                                factor = lerp(100, factor, alpha) -- somewhat like gravitational pull
                            end
                        end

                        local next_vel_x = curr_vel_x + (group_center_x - creature_y) * factor
                        local next_vel_y = curr_vel_y + (group_center_y - creature_y) * factor
                        do
                            local __is_log_enabled = false
                            if __is_log_enabled and config.Debug.IS_TRACE_ENTITIES and love.math.random() < 0.05 then
                                print('range', creature_swarm_range, 'dist', dist)
                                print(curr_vel_x, ' -> ', next_vel_x, curr_vel_y, ' -> ', next_vel_y)
                            end
                        end
                        -- HACK: Update and clamp new speed to base speed for each respective stage.
                        cs.creatures_vel_x[creature_index] = lerp(creature_stage.speed, next_vel_x, 0.8)
                        cs.creatures_vel_y[creature_index] = lerp(creature_stage.speed, next_vel_y, 0.8)
                    end

                    if config.IS_CREATURE_FUSION_ENABLED then
                        if creature_stage_id == other_creature_stage_id and creature_stage_id > 2 and creature_stage_id < #config.CREATURE_STAGES then
                            if check_creature_is_close_enough(creature_index, other_creature_index, creature_swarm_range) then
                                -- function spawn_new_fused_creature_pair(new_index:
                                -- any, parent_index1: any, parent_index2: any,
                                -- new_stage: any)

                                local inactive_index = find_inactive_creature_index()
                                if config.Debug.IS_TRACE_ENTITIES then
                                    -- print('inactive_index: ', inactive_index)
                                end
                                local is_able_to_fuse = inactive_index ~= nil
                                if is_able_to_fuse then
                                    if love.math.random() < 0.5 then -- HACK: TO MAKE IT WORK SOMEHOW
                                        do -- Safely turn the smaller pair off, before spawning the bigger one.
                                            cs.creatures_is_active[creature_index] = common.Status.not_active
                                            cs.creatures_is_active[other_creature_index] = common.Status.not_active
                                        end
                                    end
                                    M.spawn_new_fused_creature_pair(inactive_index, creature_index, other_creature_index, creature_stage_id - 1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function M.spawn_new_fused_creature_pair(new_index, parent_index1, parent_index2, new_stage)
    if config.Debug.IS_ASSERT then
        assert(new_stage >= 1)
        assert(new_stage < #config.CREATURE_STAGES)
        assert(new_stage ~= curr_state.creatures_evolution_stage[parent_index1] and new_stage ~= curr_state.creatures_evolution_stage[parent_index2])
    end

    spawn_new_creature( --
        new_index,
        ((love.math.random() < 0.5) and parent_index1 or parent_index2),
        new_stage,
        100 -- TEMPORARY: offset
    )
end

return M

local LG = love.graphics
local common = require 'common'

local LIGHT_DEFAULT_ANY_TO_PLAYER_POV_DIFFUSE_COLOR = { 0.8, 0.8, 0.7 } -- error.. shouldn't be triggered, as player action must always be defined
local LIGHT_DEFAULT_PLAYER_TRAIL_DIFFUSE_COLOR = { 0.5, 0.5, 0.5 } -- error.. shouldn't be triggered, as player action must always be defined
local LIGHT_DIFFUSE_COLORS = common.PLAYER_ACTION_TO_COLOR

local light_active_creatures_screen_coords = { gw, gh }
local light_player_trail_screen_coords = { gw, gh }

--- @class (exact) Light
local light_player_trail = {
    position = { 0, 0 },
    diffuse = LIGHT_DEFAULT_PLAYER_TRAIL_DIFFUSE_COLOR,
    power = 32,
}

--- @class (exact) Light
local light_any_to_player_pov = {
    position = { 0, 0 },
    diffuse = LIGHT_DEFAULT_ANY_TO_PLAYER_POV_DIFFUSE_COLOR,
    power = 64,
}

local function shade_any_to_player_pov(fun)
    local shader = glsl_shaders.lighting_phong
    LG.setShader(shader)

    local cs = curr_state
    light_active_creatures_screen_coords[1], light_active_creatures_screen_coords[2] = LG.getDimensions()

    -- TODO: use func args
    light_any_to_player_pov.position[1], light_any_to_player_pov.position[2] = cs.player_x, cs.player_y

    -- Avoid branching
    -- TODO: send color in func args
    -- light_any_to_player_pov.diffuse = LIGHT_DIFFUSE_COLORS[player_action] or LIGHT_DEFAULT_ANY_TO_PLAYER_POV_DIFFUSE_COLOR
    light_any_to_player_pov.diffuse = LIGHT_DEFAULT_ANY_TO_PLAYER_POV_DIFFUSE_COLOR

    shader:send('screen', light_active_creatures_screen_coords)
    shader:send('num_lights', 1)

    -- NOTE: First array offset is 0 in glsl. Lua uses 1 as index.
    local name = 'lights[' .. 0 .. ']'
    shader:send(name .. '.position', light_any_to_player_pov.position)
    shader:send(name .. '.diffuse', light_any_to_player_pov.diffuse)
    shader:send(name .. '.power', light_any_to_player_pov.power)

    -- Draw here with callback function.
    fun()

    LG.setShader() -- glsl_phong_shader
end

--- @type Light[]
local parallax_multiple_lights = {
    { position = { 100, 200 * 0.5 }, diffuse = { 0.7, 0.5, 0.3 }, power = 16 },
    { position = { 300, 400 * 0.5 }, diffuse = { 0.7, 0.5, 1 }, power = 16 },
    { position = { 500, 600 * 0.5 }, diffuse = { 0.7, 0.5, 0.5 }, power = 32 },
    { position = { 700, 800 * 0.5 }, diffuse = { 0.7, 0.5, 0.5 }, power = 64 },
    { position = { 500, 600 * 0.5 * 0.5 }, diffuse = { 0.7, 0.5, 0.5 }, power = 32 },
    { position = { 300, 400 * 0.5 * 0.5 }, diffuse = { 0.8, 0.5, 1 }, power = 16 },
    { position = { 800, 800 * 0.5 * 0.5 }, diffuse = { 0.8, 0.5, 1 }, power = 16 },
}

local function shade_parallax_multiple_lights(fun, lights)
    local shader = glsl_shaders.lighting_phong
    LG.setShader(shader)

    lights = lights or parallax_multiple_lights

    local screen_width, screen_height = LG.getDimensions()
    shader:send('screen', { screen_width, screen_height })
    shader:send('num_lights', #lights)

    -- Send each light's data to the shader
    for i, light in ipairs(lights) do
        local name = 'lights[' .. (i - 1) .. ']' -- Array index for GLSL
        shader:send(name .. '.position', light.position)
        shader:send(name .. '.diffuse', light.diffuse)
        shader:send(name .. '.power', light.power - i % 4)
    end

    -- Draw with the shader
    fun()
    LG.setShader()
end

--- @type Light[]
local multiple_lights = {
    { position = { 100, 200 }, diffuse = { 0.2, 0.5, 0.3 }, power = 64 },
    { position = { 300, 400 }, diffuse = { 0.3, 0.5, 1 }, power = 64 },
}

local function shade_active_creatures_multiple_lights(fun, lights)
    local shader = glsl_shaders.lighting_phong
    LG.setShader(shader)

    lights = lights or multiple_lights

    local screen_width, screen_height = LG.getDimensions()
    shader:send('screen', { screen_width, screen_height })
    shader:send('num_lights', #lights)

    -- Send each light's data to the shader
    for i, light in ipairs(lights) do
        local name = 'lights[' .. (i - 1) .. ']' -- Array index for GLSL
        shader:send(name .. '.position', light.position)
        shader:send(name .. '.diffuse', light.diffuse)
        shader:send(name .. '.power', light.power)
    end

    -- Draw with the shader
    fun()
    LG.setShader()
end

local function shade_player_trail(fun)
    local shader = glsl_shaders.lighting_phong
    LG.setShader(shader)

    local cs = curr_state
    light_player_trail_screen_coords[1], light_player_trail_screen_coords[2] = LG.getDimensions() -- shader:send('screen', { LG.getWidth(), LG.getHeight() })
    light_player_trail.position[1], light_player_trail.position[2] = cs.player_x, cs.player_y -- TODO: use func args
    light_player_trail.diffuse = LIGHT_DIFFUSE_COLORS[player_action] or LIGHT_DEFAULT_PLAYER_TRAIL_DIFFUSE_COLOR -- TODO: send color in func args

    shader:send('screen', light_player_trail_screen_coords)
    shader:send('num_lights', 1)
    -- NOTE: First array offset is 0 in glsl. Lua uses 1 as index.
    local name = 'lights[' .. 0 .. ']'
    shader:send(name .. '.position', light_player_trail.position)
    shader:send(name .. '.diffuse', light_player_trail.diffuse)
    shader:send(name .. '.power', light_player_trail.power)
    -- Draw here with callback function.
    fun()
    LG.setShader() -- glsl_phong_shader
end

return {
    shade_any_to_player_pov = shade_any_to_player_pov,
    shade_active_creatures_multiple_lights = shade_active_creatures_multiple_lights,
    shade_parallax_multiple_lights = shade_parallax_multiple_lights,
    shade_player_trail = shade_player_trail,
}

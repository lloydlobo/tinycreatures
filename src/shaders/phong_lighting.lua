local LG = love.graphics
local common = require 'common'

local glsl_frag = [[
#define NUM_LIGHTS 32

struct Light{
        vec2 position;
        vec3 diffuse;
        float power;
};

extern Light lights[NUM_LIGHTS];
extern int num_lights;

extern vec2 screen;

const float constant=1.;
const float linear=.09;
const float quadratic=.032;

vec4 effect(vec4 color,Image image,vec2 uvs,vec2 screen_coords){
        vec4 pixel=Texel(image,uvs);

        vec2 norm_screen=screen_coords/screen;
        vec3 diffuse=vec3(0);

        for(int i=0;i<num_lights;i++){
                Light light=lights[i];
                vec2 norm_position=light.position/screen;

                float distance=length(norm_position-norm_screen)*light.power;
                float attenuation=1./(constant+linear*distance+quadratic*(distance*distance));
                diffuse+=light.diffuse*attenuation;
        }

        diffuse=clamp(diffuse,0.,1.);

        return pixel*vec4(diffuse,1.);
}
]]

local LIGHT_DEFAULT_ACTIVE_CREATURES_DIFFUSE_COLOR = { 0.5, 0.5, 0.5 } -- error.. shouldn't be triggered, as player action must always be defined
local LIGHT_DEFAULT_PLAYER_TRAIL_DIFFUSE_COLOR = { 0.5, 0.5, 0.5 } -- error.. shouldn't be triggered, as player action must always be defined
local LIGHT_DIFFUSE_COLORS = common.PLAYER_ACTION_TO_DESATURATED_COLOR

local light_active_creatures_screen_coords = { gw, gh }
local light_player_trail_screen_coords = { gw, gh }

--- @class (exact) Light
local light_active_creatures = {
    position = { 0, 0 },
    diffuse = LIGHT_DEFAULT_ACTIVE_CREATURES_DIFFUSE_COLOR,
    power = 128,
}

--- @class (exact) Light
local light_player_trail = {
    position = { 0, 0 },
    diffuse = LIGHT_DEFAULT_ACTIVE_CREATURES_DIFFUSE_COLOR,
    power = 32,
}

local function shade_active_creatures_to_player_pov(fun)
    local shader = glsl_love_shaders.lighting_phong
    LG.setShader(shader)

    local cs = curr_state
    light_active_creatures_screen_coords[1], light_active_creatures_screen_coords[2] = LG.getDimensions() -- shader:send('screen', { LG.getWidth(), LG.getHeight() })
    light_active_creatures.position[1], light_active_creatures.position[2] = cs.player_x, cs.player_y -- TODO: use func args
    light_active_creatures.diffuse = LIGHT_DIFFUSE_COLORS[player_action] or LIGHT_DEFAULT_ACTIVE_CREATURES_DIFFUSE_COLOR -- TODO: send color in func args

    shader:send('screen', light_active_creatures_screen_coords)
    shader:send('num_lights', 1)

    -- NOTE: First array offset is 0 in glsl. Lua uses 1 as index.
    local name = 'lights[' .. 0 .. ']'
    shader:send(name .. '.position', light_active_creatures.position)
    shader:send(name .. '.diffuse', light_active_creatures.diffuse)
    shader:send(name .. '.power', light_active_creatures.power)
    -- Draw here with callback function.
    fun()

    LG.setShader() -- glsl_phong_shader
end

--- @type Light[]
local multiple_lights = {
    { position = { 100, 200 }, diffuse = { 0.2, 0.5, 0.3 }, power = 64 },
    { position = { 300, 400 }, diffuse = { 0.3, 0.5, 1 }, power = 200 },
}
local function shade_active_creatures_multiple_lights(fun, lights)
    local shader = glsl_love_shaders.lighting_phong
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
    local shader = glsl_love_shaders.lighting_phong
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
    glsl_frag = glsl_frag,

    shade_active_creatures_to_player_pov = shade_active_creatures_to_player_pov,
    shade_active_creatures_multiple_lights = shade_active_creatures_multiple_lights,
    shade_player_trail = shade_player_trail,
}

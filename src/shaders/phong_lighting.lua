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
const float linear=.09;// Increase this to reduce light spread (e.g., try 0.2 or 0.3)
const float quadratic=.032;// Increase this for a sharper falloff (e.g., 0.05 or 0.1)
const float f_diffuse=1.;// Scale factor down final diffuse effect (orginally 1.)

vec4 effect(vec4 color,Image image,vec2 uvs,vec2 screen_coords){
     vec4 pixel=Texel(image,uvs);

     // Normalize screen coordinates
     float aspect_ratio=screen.x/screen.y;
     vec2 norm_screen=vec2(screen_coords.x/screen.x,screen_coords.y/screen.y);// Using `vec2` for dividing can be faster
     vec2 orig_screen=norm_screen;// if we mutate norm_screen for effects

     vec3 col=vec3(0.);

     for(int i=0;i<num_lights;i++){
          Light light=lights[i];
          vec2 norm_pos=light.position/screen;
          vec2 diff=vec2(
               (norm_pos.x-norm_screen.x)*aspect_ratio,
               norm_pos.y-norm_screen.y
          );
          float distance=length(diff)*light.power;
          float attenuation=1./(constant+linear*distance+quadratic*(distance*distance));
          col+=light.diffuse*attenuation*f_diffuse;
     }

     col=clamp(col,0.,1.);
     return pixel*vec4(col,1.);
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
    power = 64,
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
    { position = { 300, 400 }, diffuse = { 0.3, 0.5, 1 }, power = 64 },
    { position = { 600, 600 }, diffuse = { 0.5, 0.3, 1 }, power = 64 },
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

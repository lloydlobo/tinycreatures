local LG = love.graphics

local common = require 'common'

local M = {}
--- @class Light
--- @field position [number, number]
--- @field diffuse [number, number, number]
--- @field power number

M.glsl_phong_shader_code = [[
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

function M.draw_phong_shader_player_trail_callback(fun)
    LG.setShader(glsl_love_shaders.lighting_phong)
    glsl_love_shaders.lighting_phong:send('screen', { LG.getWidth(), LG.getHeight() })
    glsl_love_shaders.lighting_phong:send('num_lights', 1)
    do
        local name = 'lights[' .. 0 .. ']' -- first array offset is 0 in glsl. lua uses 1 as index
        -- glsl_phong_shader:send(name .. '.position', { LG.getWidth() * .5, LG.getHeight() * .5 })
        glsl_love_shaders.lighting_phong:send(name .. '.position', { curr_state.player_x, curr_state.player_y })
        glsl_love_shaders.lighting_phong:send(name .. '.diffuse', (common.PLAYER_ACTION_COLOR_MAP[player_action] or { 1, 1, 1 }))
        -- glsl_phong_shader:send(name .. '.power', 64 - 64 * curr_state.player_invulnerability_timer)
        -- glsl_phong_shader:send(name .. '.power', 48 )
        glsl_love_shaders.lighting_phong:send(name .. '.power', 8)
    end
    do -- draw here
        fun()
    end
    LG.setShader() -- glsl_phong_shader
end

function M.draw_phong_shader_active_creatures_callback(fun)
    LG.setShader(glsl_love_shaders.lighting_phong)
    glsl_love_shaders.lighting_phong:send('screen', { LG.getWidth(), LG.getHeight() })
    glsl_love_shaders.lighting_phong:send('num_lights', 1)
    do -- NOTE: First array offset is 0 in glsl. lua uses 1 as index
        local name = 'lights[' .. 0 .. ']'
        glsl_love_shaders.lighting_phong:send(name .. '.position', { curr_state.player_x, curr_state.player_y })
        glsl_love_shaders.lighting_phong:send(name .. '.diffuse', (common.PLAYER_ACTION_DESATURATED_COLOR_MAP[player_action] or { 0.5, 0.5, 0.5 }))
        glsl_love_shaders.lighting_phong:send(name .. '.power', 192)
    end
    do -- draw here
        fun()
    end
    LG.setShader() -- glsl_phong_shader
end

return M

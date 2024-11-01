local M = {}

-- local LG = love.graphics
-- local common = require 'common'

-- Copied from [SkyVaultGames ─ Love2D | Shader Tutorial 1 | Introduction](https://www.youtube.com/watch?v=DOyJemh_7HE&t=1s)
M.glsl_gradient_time_modulate_shader_code = [[

extern vec2 screen;
extern float time;                                                      //> love.timer.getTime()


vec4 effect(vec4 color, Image image, vec2 uvs, vec2 screen_coords) {
     vec4 pixel = Texel(image, uvs);

     // Normalize screen coordinates
     vec2 sc = vec2(screen_coords.x/screen.x,screen_coords.y/screen.y);

     for(float i=1.;i<5.;++i){
         vec3 col = vec3(1.0)/i;

         // Radial distance from canvas center
         float d = -exp(length(sc));
         d=abs(d);

         // Modulate color channels over time
         float f=.5-.5*sin((sc[0]*3.14159+time/5.));

         col[1]=sc[0]-f;
         col[2]=sc[1]-f;
         col.gb/=1.+sin(uvs/d);

         d=pow(d,1.2);d=abs(d);
         col.yz*=col.yz/d;

         return pixel * vec4(col,1.);// red-pink-yellow
     }
}
]]

return M

local M = {}

-- local LG = love.graphics
-- local common = require 'common'

-- Copied from [SkyVaultGames ─ Love2D | Shader Tutorial 1 | Introduction](https://www.youtube.com/watch?v=DOyJemh_7HE&t=1s)
M.glsl_frag = [[
extern vec2 screen;
extern float time;//> love.timer.getTime()

vec4 effect(vec4 color,Image image,vec2 uvs,vec2 screen_coords){
     vec4 pixel=Texel(image,uvs);

     float aspect_ratio=screen.x/screen.y;

     // Normalize screen coordinates
     vec2 sc=vec2(screen_coords.x/screen.x,screen_coords.y/screen.y);

     // glsl idiom for uv (screen)─not uvs (texture)
     vec2 uv=vec2(sc.x/aspect_ratio,sc.y);

     vec2 uv0=uv;// original normalized screen

     // Radial distance from canvas center
     float d=-exp(length(uv));d=abs(d);

     // Modulate color channels over time
     float f=1.;

     vec3 col=vec3(0.);
     vec3 final_col=vec3(0.);

     for(float i=1.;i<5.;++i){
          f=.5-.5*sin((uv[0]*3.14159+time*.0625))*i;/*f/=i;*/

          // Color this iteration
          col=vec3(d,uv[0]-f,uv[1]-f);col/=i;

          // Accentuate darker contrast
          d=pow(d,1.2);d=abs(d);

          // Feather radient edges
          col.gb*=clamp(1.-sin(uvs/d)/i,.1,.8);col.gb*=col.gb/d;

          final_col+=col;
     }

     return pixel*vec4(final_col,1.);// red-pink-yellow
}
]]

M.glsl_frag_v2 = [[
extern vec2 screen;
extern float time;//> love.timer.getTime()

vec4 effect(vec4 color,Image image,vec2 uvs,vec2 screen_coords){
     vec4 pixel=Texel(image,uvs);

     // Normalize screen coordinates
     float aspect_ratio=screen.x/screen.y;
     vec2 sc=vec2(screen_coords.x/screen.x,screen_coords.y/screen.y);

     //vec2 norm_pos = vec2(uvs.x/aspect_ratio,uvs.y);
     vec2 norm_pos=vec2(sc.x/aspect_ratio,sc.y);
     vec2 orig_sc=norm_pos;

     vec3 final_col=vec3(1.);
     for(float i=1.;i<5.;++i){
          vec3 col=vec3(1.);

          // Radial distance from canvas center
          float d=-exp(length(orig_sc));d=abs(d);

          // Modulate color channels over time
          float f=.5-.5*sin((sc[0]*3.14159+time/5.));

          col[1]*=sc[0]-f;
          col[2]*=sc[1]-f;
          col.gb/=1.+sin(uvs/d);

          d=pow(d,1.2);d=abs(d);
          col.yz*=col.yz*d;
          //col*=i;//DEBUG:sine wave
          col=1.-col;
          col/=i;
          col=1.-col;
          col=clamp(col,0.,1.);
          final_col*=col;
     }
     return pixel*vec4(final_col,1.);// red-pink-yellow
}
]]

return M

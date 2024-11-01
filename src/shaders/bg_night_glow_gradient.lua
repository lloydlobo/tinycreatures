local M = {}

-- `vec2 uvs` is for LOVE quads
M.glsl_bg_night_mode_firefly_code = [[
extern vec2 screen;

vec4 effect(vec4 color, Image image, vec2 uvs, vec2 screen_coords) {
        vec4 pixel = Texel(image, uvs);
        vec2 uv0 = uvs;

        float f = 1.; // 0..1
        float d = length(uvs); // distance from center
        d*=exp(-length(uv0)); // blend to canvas center with inverse smooth function curve
        d=abs(d);

        vec2 sc = vec2(screen_coords.x / screen.x, screen_coords.y / screen.y);
        sc=1.-sc; // invert

        vec3 col = vec3(1.0, sc[0], sc[1]);

        // f=.01618; // glow factor
        // d=f/d;

        d/=sin(d)*0.01; // night mode (invert gradient mask)
        //d/=sin(d)*0.00001; // extreme night mode
        d=pow(d,1.2); // increase contrast of overall image (i.e. darker color closer to zero)

        col+=col*d;
        return pixel * vec4(col, 1.); // redpinkyello
}
]]


return M

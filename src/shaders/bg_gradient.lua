local M = {}

local LG = love.graphics

local common = require 'common'

-- Copied from [SkyVaultGames ─ Love2D | Shader Tutorial 1 | Introduction](https://www.youtube.com/watch?v=DOyJemh_7HE&t=1s)
M.glsl_gradient_shader_code = [[
extern vec2 screen;

vec4 effect(vec4 color, Image image, vec2 uvs, vec2 screen_coords) {
        vec4 pixel = Texel(image, uvs);
        vec2 sc = vec2(screen_coords.x/screen.x,screen_coords.y/screen.y);
        return pixel * vec4(1.,sc[0],sc[1],1.);// red-pink-yellow
}
]]

--[[

# Options

```glsl
//return vec4(sc, 1.0, 1.0) * pixel; // default
//return vec4(sc[0],sc[1], 1.0, 1.0) * pixel; // blueishpink
//return vec4(sc[0], 1.0, sc[1], 1.0) * pixel; // greenishyellow
//return vec4(sc[0]+0.3, 0.4, sc[1]+0.2, 1.0) * pixel; // purple yellowish
```

]]

return M

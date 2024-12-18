--- @class Light
--- @field position [number, number]
--- @field diffuse [number, number, number]
--- @field power number

--- @class (exact) Shaders
return {
    bg_gradient = require 'shaders.bg_gradient',
    bg_gradient_time_modulate = require 'shaders.bg_gradient_time_modulate',
    bg_night_glow_gradient = require 'shaders.bg_night_glow_gradient',
    phong_lighting = require 'shaders.phong_lighting',
}

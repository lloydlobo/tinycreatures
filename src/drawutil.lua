--[[
    Module avoids busted testing for now, due to love dependency
--]]
local LG = love.graphics

local Common = require 'common'
local Config = require 'config'

--- Create a small circle image to use in our sprite batch.
--- @param opts { radius: number, color: [number, number, number, number]|[number, number, number] } A table containing radius and color options.
--- @return love.Image image A new Image object which can be drawn on screen.
--- @nodiscard
local function create_circle_image(opts)
    local radius = opts.radius
    local col = opts.color or { 1, 1, 1, 1 }

    local diameter = radius * 2
    local canvas = LG.newCanvas(diameter, diameter)

    LG.setCanvas(canvas)
    LG.clear()
    LG.setColor(col[1] or 1, col[2] or 1, col[3] or 1, col[4] or 1)
    LG.circle('fill', radius, radius, radius)
    LG.setCanvas()

    return LG.newImage(canvas:newImageData())
end

--- @class (exact) SpriteBatchFn
--- @field make_bg_parallax_entities fun():love.SpriteBatch
--- @field make_creatures fun():love.SpriteBatch
--- @field make_lasers fun():love.SpriteBatch
local SpriteBatchFn = {
    make_bg_parallax_entities = function()
        -- local img = M.create_circle_image { radius = 32, color = { 0.025, 0.15, 0.10, 0.2 } } -- if 4 -> Base size of 8 pixels diameter
        -- if 4 -> Base size of 8 pixels diameter
        local img = create_circle_image { radius = Config.PARALLAX_ENTITY_IMG_RADIUS, color = { 1.0, 1.0, 1.0, 1.0 } }
        return LG.newSpriteBatch(img, Config.PARALLAX_ENTITY_MAX_COUNT, 'static')
    end,

    make_creatures = function()
        local color = Common.COLOR.creature_infected
        local radius = Config.CREATURE_STAGES[#Config.CREATURE_STAGES].radius --[[local creature_circle_image = create_circle_image(radius, color[1], color[2], color[3], 1.0)]]
        local img = create_circle_image { radius = radius, color = { 0.3, 0.3, 0.3 } }
        return LG.newSpriteBatch(img, Config.CREATURE_TOTAL_CAPACITY, 'static') -- maybe static?
    end,

    make_lasers = function()
        --- FIXME: how to make this dynamic sized? use differnet sprite images and batches?
        local img = create_circle_image { radius = Config.LASER_RADIUS }
        return LG.newSpriteBatch(img, Config.LASER_MAX_CAPACITY, 'static')
    end,
}

--- @class (exact) drawutil
return {
    create_circle_image = create_circle_image,
    SpriteBatchFn = SpriteBatchFn,
}

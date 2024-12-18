local M = {}

local config = require 'config'

--- @enum COLLISION_TOLERANCE
M.COLLISION_TOLERANCE = {
    OUTER_50 = 1.5,
    OUTER_40 = 1.4,
    OUTER_30 = 1.3,
    OUTER_20 = 1.2,
    OUTER_10 = 1.1,
    EXACT = 1.0,
    INNER_10 = 0.9,
    INNER_20 = 0.8,
    INNER_30 = 0.7,
    INNER_40 = 0.6,
    INNER_50 = 0.5,
    INNER_60 = 0.4,
    INNER_70 = 0.3,
}

--- @type fun(pair: { a: Circle, b: Circle }): boolean
function M.is_intersect_circles(ab)
    local dx = (ab.a.x - ab.b.x)
    local dy = (ab.a.y - ab.b.y)
    local dist_ab = ab.a.radius + ab.b.radius
    return (dx * dx + dy * dy <= dist_ab * dist_ab)
end

--- tolerance = 1.0: exact check (original behavior)
--- tolerance > 1.0: more forgiving (e.g., 1.1 gives 10% more leeway)
--- tolerance < 1.0: stricter check (e.g., 0.9 requires 10% more overlap)
---
--- @type fun(opts: { a: Circle, b: Circle, tolerance_factor: number|COLLISION_TOLERANCE } ): boolean
function M.is_intersect_circles_tolerant(opts)
    if config.Debug.IS_ASSERT then
        assert((opts.tolerance_factor >= 0.0) and (opts.tolerance_factor <= 2.0), string.format("Invalid tolerance value '%.2f'", opts.tolerance_factor))
    end
    local dx = (opts.a.x - opts.b.x)
    local dy = (opts.a.y - opts.b.y)
    local dist_ab = opts.a.radius + opts.b.radius
    return (((dx * dx) + (dy * dy)) <= ((dist_ab * dist_ab) * opts.tolerance_factor))
end

return M

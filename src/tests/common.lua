if arg[1] == '' then --
    error 'Please run `busted tests/*.lua`'
end

assert = require 'luassert'
local common = require '../common'

describe('get sign', function()
    it('should get positive sign for positive numbers', function()
        assert.are.equal(1, common.sign(1))
    end)
    it('should get negative sign for negative numbers', function()
        assert.are.equal(-1, common.sign(-1))
    end)
end)

describe('get interpolated value', function()
    it('should lerp midpoint', function()
        assert.are.equal(5, common.lerp(0, 10, 0.5))
    end)
    it('should lerp midpoint', function()
        assert.are.equal(5.5, common.lerp(1, 10, 0.5))
    end)
end)

describe('get manhattan_distance', function()
    it('should get approx distance between two points', function()
        assert.are.equal(2, common.manhattan_distance { x1 = 0, y1 = 0, x2 = 1, y2 = 1 })
        assert.are.equal(2, common.manhattan_distance { x1 = 0, y1 = 0, x2 = -1, y2 = -1 })
        assert.are.equal(2, common.manhattan_distance { x1 = 1, y1 = 1, x2 = 0, y2 = 0 })
        assert.are.equal(2, common.manhattan_distance { x1 = -1, y1 = -1, x2 = 0, y2 = 0 })
    end)
end)

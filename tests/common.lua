local common = require '../common'

assert = require 'luassert'
require 'busted'

if arg[1] == '' then error 'Please run `busted tests/*.lua`.' end

describe('common - datastructures', function()
    describe('enumerations', function()
        it('should have correct status values', function()
            assert.are.equal(common.Status.active, 1)
            assert.are.equal(common.Status.not_active, 0)
            assert.are.equal(common.Status.active == 1, true)
            assert.are.equal(common.Status.not_active == 0, true)
        end)
        it('should have correct health transition values', function()
            assert.are.equal(common.HealthTransitions.none, -1)
            assert.are.equal(common.HealthTransitions.healing, 0)
            assert.are.equal(common.HealthTransitions.healthy, 1)
        end)
    end)
end)

describe('common - functions', function()
    describe('get sign', function()
        it('should get positive sign for positive numbers', function() assert.are.equal(1, common.sign(1)) end)
        it('should get negative sign for negative numbers', function() assert.are.equal(-1, common.sign(-1)) end)
        it('should not return zero for zero input', function() -- edge case
            assert.are.equal(1, common.sign(0))
        end)
    end)

    describe('get interpolated value', function()
        it('should lerp midpoint', function()
            assert.are.equal(5, common.lerp(0, 10, 0.5))
            assert.are.equal(5.5, common.lerp(1, 10, 0.5))
        end)
        it('should correctly interpolate with lerp', function()
            assert.are.equal(common.lerp(0, 10, 0.5), 5)
            assert.are.equal(common.lerp(10, 20, 0.25), 12.5)
        end)
        it('should return start when t is 0', function() -- edge case
            assert.are.equal(0, common.lerp(0, 10, 0))
        end)
        it('should return end when t is 1', function() -- edge case
            assert.are.equal(10, common.lerp(0, 10, 1))
        end)
    end)

    describe('mutate destination table with interpolated rgb value', function()
        it('should interpolate colors with lerp_rbg', function()
            local dst = { 0, 0, 0 }
            local src1 = { 1, 0, 0 }
            local src2 = { 0, 1, 0 }
            common.lerp_rbg(dst, src1, src2, 0.5)
            assert.are.same(dst, { 0.5, 0.5, 0 })
        end)
        it('should return src1 when t is 0', function()
            local dst = { 0, 0, 0 }
            local src1 = { 1, 0, 0 }
            local src2 = { 0, 1, 0 }
            common.lerp_rbg(dst, src1, src2, 0)
            assert.are.same(dst, src1)
        end)
        it('should return src2 when t is 1', function()
            local dst = { 0, 0, 0 }
            local src1 = { 1, 0, 0 }
            local src2 = { 0, 1, 0 }
            common.lerp_rbg(dst, src1, src2, 1)
            assert.are.same(dst, src2)
        end)
    end)

    describe('get manhattan_distance', function()
        it('should get approx distance between two points', function()
            assert.are.equal(0, common.manhattan_distance { x1 = 0, y1 = 0, x2 = 0, y2 = 0 })
            assert.are.equal(2, common.manhattan_distance { x1 = -1, y1 = -1, x2 = 0, y2 = 0 })
            assert.are.equal(2, common.manhattan_distance { x1 = 0, y1 = 0, x2 = -1, y2 = -1 })
            assert.are.equal(2, common.manhattan_distance { x1 = 0, y1 = 0, x2 = 1, y2 = 1 })
            assert.are.equal(2, common.manhattan_distance { x1 = 1, y1 = 1, x2 = 0, y2 = 0 })
        end)
    end)
end)

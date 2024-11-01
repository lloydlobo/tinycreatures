local Timer = require 'src.timer'

assert = require 'luassert'
require 'busted'
if arg[1] == '' then error 'Please run `busted tests/*.lua`.' end

local is_skip_test = true

describe('timer - functions', function()
    describe('toggles playing boolean state', function()
        it('should toggle `is_playing` to be falsy', function() -- TODO: test time elapsed
            local is_playing = true
            Timer.after(2, function() is_playing = false end)
            Timer.after(2 + 1, function() assert.is.truthy(not is_playing) end)
        end)
    end)

    describe('grant the player 5 seconds of invulnerability', function()
        it('should toggle `is_invincible` to be falsy', function() -- TODO: test time elapsed
            local is_invincible = true
            Timer.after(5, function() is_invincible = not true end)
            Timer.after(5 + 1, function() assert.is.truthy(not is_invincible) end)
        end)
    end)

    if not is_skip_test then
        Timer.after(1, function(func) -- print "foo" every second
            print 'foo'
            Timer.after(1, func) -- reschedule the timer to run after a second
        end)
    end
end)

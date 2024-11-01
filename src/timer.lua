--- @class Timer
---
--- A simple timer utility, inspired by `hump.timer`, for managing delayed
--- function execution. Supports non-blocking timers and periodic scheduling.
---
--- ## Example
--- ```lua
--- local Timer = require("timer")
---
--- function love.update(dt)
---     Timer.update(dt) -- call this every frame to update timers
--- end
---
--- player.isInvincible = true -- grant the player 5 seconds of invulnerability
--- Timer.after(5, function() player.isInvincible = false end)
---
--- Timer.after(1, function(func) -- print "foo" every second
---     print("foo")
---     Timer.after(1, func) -- reschedule the timer to run after a second
--- end)
--- ```
local M = {}

--- @class (exact) ScheduledTimer
--- @field callback function # The function to execute when the timer ends.
--- @field time_left number # Time remaining for the timer.

--- Holds all scheduled timers
--- @type ScheduledTimer[]
local timers = {}

--- Schedules a new timer.
--- Insert a new timer to `local timers` of type `ScheduledTimer[]`.
--- @param delay number # Time in seconds until the callback is executed.
--- @param callback function # The function to call after the delay.
function M.after(delay, callback)
    timers[#timers + 1] = {
        time_left = delay,
        callback = callback,
    }
end

--- Updates all timers. Call this in `love.update(dt)`.
--- @param dt number # The delta time passed since the last frame.
function M.update(dt)
    local timer --- @type ScheduledTimer
    for i = #timers, 1, -1 do
        timer = timers[i]
        timer.time_left = timer.time_left - dt
        if timer.time_left <= 0 then
            timer.callback(timer.callback) -- execute callback function, passing itself as its parameter
            table.remove(timers, i) -- remove the timer after execution
        end
    end
end

do -- TODO: TWEENING
    -- Timer = {}
    -- local timers = {}
    -- -- Schedules a function to run after a delay (same as before)
    -- function Timer.after(delay, func)
    --     table.insert(timers, {timeLeft = delay, callback = func, isTween = false})
    -- end
    -- -- Adds a tween to change a value over a given duration
    -- function Timer.tween(duration, subject, target, easing)
    --     local startValues = {}
    --     -- Store initial values for each target field
    --     for key, targetValue in pairs(target) do
    --         startValues[key] = subject[key]
    --     end
    --     local timer = {
    --         timeLeft = duration,
    --         duration = duration,
    --         subject = subject,
    --         target = target,
    --         startValues = startValues,
    --         easing = easing or function(t) return t end, -- Default to linear easing
    --         isTween = true
    --     }
    --     table.insert(timers, timer)
    -- end
    --
    -- -- Call this in your update loop to update timers and tweens
    -- function Timer.update(dt)
    --     for i = #timers, 1, -1 do
    --         local timer = timers[i]
    --         timer.timeLeft = timer.timeLeft - dt
    --         if timer.isTween then
    --             local progress = math.min(1, (timer.duration - timer.timeLeft) / timer.duration)
    --             local easedProgress = timer.easing(progress)
    --             -- Update each property in the subject towards the target value
    --             for key, targetValue in pairs(timer.target) do
    --                 local startValue = timer.startValues[key]
    --                 timer.subject[key] = startValue + (targetValue - startValue) * easedProgress
    --             end
    --         end
    --         if timer.timeLeft <= 0 then
    --             if not timer.isTween then
    --                 timer.callback(timer.callback) -- Call the function if it's not a tween
    --             end
    --             table.remove(timers, i)
    --         end
    --     end
    -- end
    -- -- Linear interpolation function (default easing)
    -- function Timer.linear(t)
    --     return t
    -- end
    -- -- Example easing function (ease out)
    -- function Timer.easeOutQuad(t)
    --     return 1 - (1 - t) * (1 - t)
    -- end
    -- return Timer
    do -- TODO: Example of tweening
        -- local Timer = require("timer")
        -- local player = { x = 100, y = 100, alpha = 1 }
        -- function love.update(dt)
        --     Timer.update(dt)
        -- end
        -- function love.load()
        --     -- Move player smoothly from x = 100 to x = 300 in 2 seconds
        --     Timer.tween(2, player, { x = 300 }, Timer.easeOutQuad)
        --     -- Fade out player (alpha = 1 to alpha = 0) in 3 seconds
        --     Timer.tween(3, player, { alpha = 0 }, Timer.linear)
        --     -- Example of a simple delay action
        --     Timer.after(5, function() print("5 seconds passed!") end)
        -- end
        -- function love.draw()
        --     -- Draw the player as a rectangle with a fading effect
        --     love.graphics.setColor(1, 1, 1, player.alpha)
        --     love.graphics.rectangle("fill", player.x, player.y, 50, 50)
        -- end
    end
end

return M

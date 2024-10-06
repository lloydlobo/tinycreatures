-- Grug not found
-- function love.conf(t)
--     t.window.width = 800
--     t.window.height = 600
-- end

-- conf.lua
--
-- See https://love2d.org/wiki/Config_Files
--
-- List of options and their default values for LÖVE 11.3 and 11.4:~
--
-- - Setting unused modules to false is encouraged when you release
--   your game. It reduces startup time slightly (especially if the
--   joystick module is disabled) and reduces memory usage (slightly).

--standard resolution 1024x768
--
--  2^10 --> 1024
--  2^ 9 -->  512
--  2^ 8 -->  256

local sx, sy = 1.28, 1.28
gw = 800 * sx
gh = 450 * sy
-- local aspect_ratio = 4 / 3
-- gh = math.floor(gw * (1 / aspect_ratio))
-- print(pcall(function() assert((gw / gh) == aspect_ratio, 'Expected ' .. aspect_ratio .. ' aspect ration') end))

function love.conf(t)
    t.console = false -- Attach a console (boolean, Windows only)
    t.externalstorage = false -- True to save files (and read from the save directory) in external storage on Android (boolean)
    t.gammacorrect = true -- Enable gamma-correct rendering, when supported by the system (boolean)

    t.window.title = 'sokoban' -- The window title (string)
    t.window.width = gw --width -- The window width (number)
    t.window.height = gh --height -- The window height (number)
    t.window.borderless = true -- Remove all border visuals from the window (boolean)
    t.window.resizable = false -- Let the window be user-resizable (boolean)
    t.window.fullscreen = false -- Enable fullscreen (boolean)
    t.window.fullscreentype = 'exclusive' -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
    t.window.vsync = 1 -- Vertical sync mode (number)
    t.window.msaa = 0 -- The number of samples to use with multi-sampled antialiasing (number)
    t.window.highdpi = true -- Enable high-dpi mode for the window on a Retina display (boolean)
    t.window.usedpiscale = true -- Enable automatic DPI scaling when highdpi is set to true as well (boolean)
    t.window.x = nil -- The x-coordinate of the window's position in the specified display (number)
    t.window.y = nil -- The y-coordinate of the window's position in the specified display (number)

    t.modules.audio = true -- Enable the audio module (boolean)
    t.modules.data = true -- Enable the data module (boolean)
    t.modules.event = true -- Enable the event module (boolean)
    t.modules.font = true -- Enable the font module (boolean)
    t.modules.graphics = true -- Enable the graphics module (boolean)
    t.modules.image = true -- Enable the image module (boolean)
    t.modules.joystick = false -- Enable the joystick module (boolean)
    t.modules.keyboard = true -- Enable the keyboard module (boolean)
    t.modules.math = true -- Enable the math module (boolean)
    t.modules.mouse = true -- Enable the mouse module (boolean)
    t.modules.physics = false -- Enable the physics module (boolean)
    t.modules.sound = true -- Enable the sound module (boolean)
    t.modules.system = true -- Enable the system module (boolean)
    t.modules.thread = true -- Enable the thread module (boolean)
    t.modules.timer = true -- Enable the timer module (boolean), Disabling it will result 0 delta time in love.update
    t.modules.touch = false -- Enable the touch module (boolean)
    t.modules.video = true -- Enable the video module (boolean)
    t.modules.window = true -- Enable the window module (boolean)
end

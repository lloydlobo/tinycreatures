--
--
--
--
--
-- TODO: later... move to config.lua if necessary
--
--
--
--
local AUDIO_DIR = 'resources/audio/'
local SFX_DIR = AUDIO_DIR .. 'sfx/'
local LOOPS_DIR = AUDIO_DIR .. 'minimalistic_loops/'
LOOPS_DIR = AUDIO_DIR .. 'music/'

---@enum Audio_Path
local Audio_Path = { ---Enumerations for sound file paths.
    --[[stream]]

    Bgm = LOOPS_DIR .. 'buildup.wav',

    --[[static]]

    Collect = SFX_DIR .. 'pickup_holy.wav',

    -- Jump = SFX_DIR .. 'jump.wav',
    -- Win = SFX_DIR .. 'win.wav',
    -- Lose = SFX_DIR .. 'lose.wav',
}
---@enum Audio_Play_How
local Audio_Play_How = { Static = 'static', Stream = 'stream', Queue = 'queue' }

---@class Audio
local Audio = {
    bgm = nil,
}

-- SEE IMPLEMENTATION :::: https://github.com/lloydlobo/sokoban-love/blob/aa48a970e3ae40244b230c30a77a64ac689e7544/main.lua#L727C1-L787C1

--A minimalist sound manager to make playing sounds easier without adding a whole library.
--
--see also: https://www.love2d.org/wiki/Minimalist_Sound_Manager
do
    local sound_sources = {}

    --check for sources that finished playing and remove them and add to `love.update`
    function love.audio.update()
        local remove = {}
        for _, s in pairs(sound_sources) do
            if s.isStopped ~= nil and s:isStopped() then
                remove[#remove + 1] = s
            end
        end

        for i, s in pairs(remove) do
            sound_sources[s] = nil
        end
    end

    local la_play = LA.play
    ---Overwrite love.audio.play to create and register source if needed.
    ---
    ---@param what love.Source|string # The filename.
    ---@param how love.Source|string # The source type: `'static'|'stream'|'queue'`
    ---@param loop boolean # Whether the audio is to be looped infinitely.
    ---@return love.Source
    ---@diagnostic disable-next-line: duplicate-set-field
    function love.audio.play(what, how, loop)
        local src = what
        if type(what) ~= 'userdata' or not (what:typeOf 'Source') then ---@diagnostic disable-line: undefined-field
            src = LA.newSource(what, how) ---@diagnostic disable-line: param-type-mismatch
            src:setLooping(loop or false)
        end

        la_play(src)
        sound_sources[src] = src
        return src
    end

    local la_stop = LA.stop
    --Stops a sound source.
    --
    ---@param src love.Source
    ---@diagnostic disable-next-line: duplicate-set-field
    function love.audio.stop(src)
        if not src then
            return
        end
        la_stop(src)
        sound_sources[src] = nil
    end
end

local fade_color_opts = readonly { ---@type FadeColorOpts
    prologue = 0.050, --seconds opaque white.
    attack = 1.750, --seconds to make it transparent.
    sustain = 0.450, --seconds transparent.
    decay = 1.900, --seconds to go to opaque black.
    epilogue = 0, --seconds opaque black.
}
local fade_start_time
local total_fade_duration

function Audio_load()
    local function load_audio() --
        Audio.bgm = love.audio.play(Audio_Path.Bgm, Audio_Play_How.Stream, true) --stream and loop background music
    end

    local ok, err = pcall(load_audio)
    io.write(string.format('%.8f  %s %s\n', os.clock(), '[Audio]', ok and 'Loaded succesfully' or 'Failed to load'))
    if not ok then
        io.write('\tError: ', err)
    end

    love.audio.setVolume(0.4) --volume # number # 1.0 is max and 0.0 is off.
end

--[[
    local function game_keypressed(key, _, _)
        if key == 'escape' or key == Control_Key.Force_Quit_Game then
            love.event.push 'quit'
        elseif key == 's' then
            if Audio.bgm then LA.stop(Audio.bgm) end
        elseif key == 'p' then
            if Audio.bgm then LA.play(Audio.bgm) end --still streaming and looping
        elseif key == Control_Key.Toggle_Hud then
            Game.flag.is_hud_enabled = not Game.flag.is_hud_enabled
        elseif key == Control_Key.Undo then
            undo_game_state()
        elseif key == Control_Key.Reset_Level then
            reset_loaded_game_state()
        elseif key == Control_Key.Next_Level then
            Game.current_level = 1 + (((Game.current_level + 1) > Constants.LEVELS_COUNT) and 0 or Game.current_level)
            reset_loaded_game_state()
        elseif key == Control_Key.Previous_Level then
            Game.current_level = -1 + (((Game.current_level - 1) < 1 and (Constants.LEVELS_COUNT + 1)) or Game.current_level)
            reset_loaded_game_state()
        elseif Controller.movement_keys_matcher[key] then
            --note: set `or` to '0' to disallow diagonal teleportation vvv like movement vvv
            Game.movement.dx = ({ left = -1, right = 1 })[key] or Game.movement.dx
            Game.movement.dy = ({ up = -1, down = 1 })[key] or Game.movement.dy

            --NOTE: move_player(): for fixed on input gameplay without time steps, call this once here:
            --NOTE: moved move_player() here as it messes with continous saves of undo_stack state saves (bug)
            --    move_player()
        end
    end
--]]

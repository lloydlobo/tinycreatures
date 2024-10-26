-- Different methods for out-of-band boolean storage

-- Method 1: Using bit fields in a single number
local BitFlags = {}
BitFlags.__index = BitFlags

function BitFlags.new()
    return setmetatable({
        value = 0  -- Single number storing up to 32 booleans
    }, BitFlags)
end

function BitFlags:set(position, value)
    if value then
        self.value = self.value | (1 << position)
    else
        self.value = self.value & ~(1 << position)
    end
end

function BitFlags:get(position)
    return (self.value & (1 << position)) ~= 0
end

-- Method 2: Using string as bit array (can store thousands of booleans)
local StringFlags = {}
StringFlags.__index = StringFlags

function StringFlags.new(size)
    local bytes = math.ceil(size / 8)
    return setmetatable({
        data = string.rep('\0', bytes),
        size = size
    }, StringFlags)
end

function StringFlags:set(position, value)
    assert(position < self.size, "Position out of bounds")
    local byte_pos = math.floor(position / 8) + 1
    local bit_pos = position % 8
    local byte = string.byte(self.data, byte_pos) or 0

    if value then
        byte = byte | (1 << bit_pos)
    else
        byte = byte & ~(1 << bit_pos)
    end

    self.data = string.sub(self.data, 1, byte_pos - 1) ..
                string.char(byte) ..
                string.sub(self.data, byte_pos + 1)
end

function StringFlags:get(position)
    assert(position < self.size, "Position out of bounds")
    local byte_pos = math.floor(position / 8) + 1
    local bit_pos = position % 8
    local byte = string.byte(self.data, byte_pos) or 0
    return (byte & (1 << bit_pos)) ~= 0
end

-- Method 3: Using array of numbers (good balance between memory and speed)
local ArrayFlags = {}
ArrayFlags.__index = ArrayFlags

function ArrayFlags.new(size)
    local nums = math.ceil(size / 32)
    return setmetatable({
        data = table.create(nums, 0),
        size = size
    }, ArrayFlags)
end

function ArrayFlags:set(position, value)
    assert(position < self.size, "Position out of bounds")
    local array_pos = math.floor(position / 32) + 1
    local bit_pos = position % 32

    if value then
        self.data[array_pos] = self.data[array_pos] | (1 << bit_pos)
    else
        self.data[array_pos] = self.data[array_pos] & ~(1 << bit_pos)
    end
end

function ArrayFlags:get(position)
    assert(position < self.size, "Position out of bounds")
    local array_pos = math.floor(position / 32) + 1
    local bit_pos = position % 32
    return (self.data[array_pos] & (1 << bit_pos)) ~= 0
end

-- Example usage and benchmarking
local function example()
    -- Basic usage example
    local flags = BitFlags.new()
    flags:set(0, true)   -- Set first flag
    flags:set(5, true)   -- Set sixth flag
    print("Flag 0:", flags:get(0))  -- true
    print("Flag 1:", flags:get(1))  -- false
    print("Flag 5:", flags:get(5))  -- true

    -- String-based storage for many flags
    local string_flags = StringFlags.new(1000)  -- Store 1000 booleans
    string_flags:set(999, true)
    print("Flag 999:", string_flags:get(999))

    -- Array-based storage
    local array_flags = ArrayFlags.new(100)
    array_flags:set(50, true)
    print("Flag 50:", array_flags:get(50))

    -- Memory usage comparison
    print("\nMemory Usage Comparison:")
    print("Regular boolean table (100 entries):", collectgarbage("count"))
    local regular = {}
    for i = 1, 100 do regular[i] = false end
    local mem1 = collectgarbage("count")

    local bit_flags = BitFlags.new()
    local mem2 = collectgarbage("count")

    local string_flags = StringFlags.new(100)
    local mem3 = collectgarbage("count")

    print("BitFlags overhead:", mem2 - mem1, "KB")
    print("StringFlags overhead:", mem3 - mem2, "KB")
end

-- Performance test
local function benchmark(iterations)
    local start = os.clock()
    local flags = BitFlags.new()
    for i = 0, 31 do
        for _ = 1, iterations do
            flags:set(i, true)
            flags:get(i)
            flags:set(i, false)
        end
    end
    print("BitFlags time:", os.clock() - start)

    start = os.clock()
    local string_flags = StringFlags.new(32)
    for i = 0, 31 do
        for _ = 1, iterations do
            string_flags:set(i, true)
            string_flags:get(i)
            string_flags:set(i, false)
        end
    end
    print("StringFlags time:", os.clock() - start)
end

return {
    BitFlags = BitFlags,
    StringFlags = StringFlags,
    ArrayFlags = ArrayFlags,
    example = example,
    benchmark = benchmark
}

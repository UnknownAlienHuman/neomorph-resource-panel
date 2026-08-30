local ADDON_NAME, NS = ...
NS.Debug = NS.Debug or {}
local Debug = NS.Debug
local Safe = NS.Safe
local unpack = table.unpack or unpack

Debug.maxEntries = 200
Debug.buffer = Debug.buffer or {}
Debug.cursor = Debug.cursor or 1
Debug.count = Debug.count or 0

local function Push(line)
    Debug.buffer[Debug.cursor] = line
    Debug.cursor = Debug.cursor + 1
    if Debug.cursor > Debug.maxEntries then Debug.cursor = 1 end
    Debug.count = math.min(Debug.maxEntries, Debug.count + 1)
end

local function Format(fmt, ...)
    fmt = Safe.String(fmt)
    if not fmt then return "<inaccessible debug message>" end

    local count = select("#", ...)
    if count == 0 then return fmt end

    local args = { ... }
    for index = 1, count do
        local value = args[index]
        if not Safe.CanAccess(value) then return fmt .. " <inaccessible payload>" end
        local valueType = type(value)
        if valueType ~= "string" and valueType ~= "number" and valueType ~= "boolean" and value ~= nil then
            return fmt .. " <unsupported payload>"
        end
    end

    local ok, message = pcall(string.format, fmt, unpack(args, 1, count))
    return ok and message or fmt
end

function Debug.IsEnabled()
    local db = NS.GetDB()
    return db.debug == true
end

function Debug.Log(fmt, ...)
    if not Debug.IsEnabled() then return end
    local message = Format(fmt, ...)
    local stamp = "--:--:--"
    if type(date) == "function" then
        local ok, value = pcall(date, "%H:%M:%S")
        if ok and Safe.String(value) then stamp = value end
    end
    local line = string.format("[%s] NRP %s", stamp, message)
    Push(line)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(line) end
end

function Debug.Dump(requested)
    local amount = math.floor(Safe.Clamp(requested, 30, 1, Debug.maxEntries) + 0.5)
    local available = math.min(amount, Debug.count)
    local index = Debug.cursor - 1
    if index < 1 then index = Debug.maxEntries end
    for _ = 1, available do
        local line = Debug.buffer[index]
        if line and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(line)
        end
        index = index - 1
        if index < 1 then index = Debug.maxEntries end
    end
end

function Debug.Clear()
    Debug.buffer = {}
    Debug.cursor = 1
    Debug.count = 0
end

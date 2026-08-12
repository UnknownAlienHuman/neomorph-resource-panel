-- NeomorphResourcePanel
-- Minimal debug logger (ring buffer) for in-game diagnostics.

local ADDON_NAME, NS = ...

NS.Debug = NS.Debug or {}

local Debug = NS.Debug
Debug.enabled = true
Debug.maxEntries = 200
Debug.buffer = Debug.buffer or {}
Debug.cursor = Debug.cursor or 1

local function Push(line)
    local buf = Debug.buffer
    buf[Debug.cursor] = line
    Debug.cursor = Debug.cursor + 1
    if Debug.cursor > Debug.maxEntries then
        Debug.cursor = 1
    end
end

function Debug.Log(fmt, ...)
    if not Debug.enabled then return end

    local msg
    if select('#', ...) > 0 then
        msg = string.format(fmt, ...)
    else
        msg = tostring(fmt)
    end

    local stamp = date("%H:%M:%S")
    local line = string.format("[%s] NRP %s", stamp, msg)
    Push(line)

    -- Chat output (kept minimal; comment this line if you want silent logging)
    DEFAULT_CHAT_FRAME:AddMessage(line)
end

function Debug.Dump(n)
    n = tonumber(n) or 30
    if n < 1 then n = 1 end

    local buf = Debug.buffer
    local max = Debug.maxEntries

    -- Print newest -> older
    local idx = Debug.cursor - 1
    if idx < 1 then idx = max end

    for _ = 1, math.min(n, max) do
        local line = buf[idx]
        if line then
            DEFAULT_CHAT_FRAME:AddMessage(line)
        end
        idx = idx - 1
        if idx < 1 then idx = max end
    end
end

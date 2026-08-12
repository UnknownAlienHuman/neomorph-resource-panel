-- NeomorphResourcePanel
-- SavedVariables + defaults

local ADDON_NAME, NS = ...

NeomorphResourcePanelDB = NeomorphResourcePanelDB or {}

local defaults = {
    locked = false,
    threshold = 0.80, -- 80%
    width = 260,
    height = 18,
    showText = true,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = -180,
}

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function NS.GetDB()
    NeomorphResourcePanelDB = NeomorphResourcePanelDB or {}
    CopyDefaults(NeomorphResourcePanelDB, defaults)
    return NeomorphResourcePanelDB
end

function NS.ResetDB()
    NeomorphResourcePanelDB = {}
    return NS.GetDB()
end

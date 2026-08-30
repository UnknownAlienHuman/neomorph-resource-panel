local ADDON_NAME, NS = ...
NS = NS or {}

NS.VERSION = "0.2.0"
NS.DB_VERSION = 2
NS.Safe = NS.Safe or {}
local Safe = NS.Safe

function Safe.CanAccess(value)
    if type(canaccessvalue) == "function" then
        local ok, accessible = pcall(canaccessvalue, value)
        return ok and accessible == true
    end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        return ok and secret ~= true
    end
    return true
end

function Safe.Boolean(value)
    if not Safe.CanAccess(value) or type(value) ~= "boolean" then return nil end
    return value
end

function Safe.Number(value)
    if not Safe.CanAccess(value) or type(value) ~= "number" or value ~= value then return nil end
    return value
end

function Safe.String(value)
    if not Safe.CanAccess(value) or type(value) ~= "string" then return nil end
    return value
end

function Safe.Table(value)
    if not Safe.CanAccess(value) or type(value) ~= "table" then return nil end
    if type(issecrettable) == "function" then
        local ok, secret = pcall(issecrettable, value)
        if not ok or secret == true then return nil end
    end
    return value
end

function Safe.Text(value, fallback)
    if not Safe.CanAccess(value) then return fallback or "<inaccessible>" end
    local valueType = type(value)
    if valueType == "string" then return value end
    if valueType == "number" or valueType == "boolean" then return tostring(value) end
    return fallback or "<unavailable>"
end

function Safe.Clamp(value, fallback, minimum, maximum)
    value = Safe.Number(value)
    if value == nil then return fallback end
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function Safe.InCombat()
    if type(InCombatLockdown) ~= "function" then return false end
    local ok, value = pcall(InCombatLockdown)
    return ok and Safe.Boolean(value) == true
end

local DEFAULTS = {
    version = NS.DB_VERSION,
    enabled = true,
    locked = false,
    threshold = 0.80,
    width = 260,
    height = 18,
    showText = true,
    debug = false,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = -180,
}

local VALID_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function Sanitize(db)
    db.version = NS.DB_VERSION
    db.enabled = Safe.Boolean(db.enabled) ~= false
    db.locked = Safe.Boolean(db.locked) == true
    db.threshold = Safe.Clamp(db.threshold, DEFAULTS.threshold, 0, 1)
    db.width = math.floor(Safe.Clamp(db.width, DEFAULTS.width, 80, 1200) + 0.5)
    db.height = math.floor(Safe.Clamp(db.height, DEFAULTS.height, 6, 100) + 0.5)
    db.showText = Safe.Boolean(db.showText) ~= false
    db.debug = Safe.Boolean(db.debug) == true

    local point = Safe.String(db.point)
    local relativePoint = Safe.String(db.relativePoint)
    db.point = point and VALID_POINTS[point] and point or DEFAULTS.point
    db.relativePoint = relativePoint and VALID_POINTS[relativePoint] and relativePoint or DEFAULTS.relativePoint
    db.x = math.floor(Safe.Clamp(db.x, DEFAULTS.x, -4000, 4000) + 0.5)
    db.y = math.floor(Safe.Clamp(db.y, DEFAULTS.y, -4000, 4000) + 0.5)

    db.percentScale = nil
    db.combatColorCurve = nil
    db.pendingApply = nil
    return db
end

function NS.GetDefaults()
    local copy = {}
    for key, value in pairs(DEFAULTS) do copy[key] = value end
    return copy
end

function NS.GetDB()
    local db = Safe.Table(_G.NeomorphResourcePanelDB) or {}
    _G.NeomorphResourcePanelDB = Sanitize(db)
    return _G.NeomorphResourcePanelDB
end

function NS.ResetDB()
    _G.NeomorphResourcePanelDB = Sanitize(NS.GetDefaults())
    return _G.NeomorphResourcePanelDB
end

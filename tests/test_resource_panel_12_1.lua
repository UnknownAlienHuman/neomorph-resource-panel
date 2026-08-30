local unpack = table.unpack or unpack
local combat = false
local powerMode = "ordinary"
local currentPower = 85
local maxPower = 100
local currentToken = "RUNIC_POWER"
local currentType = 6
local chat = {}
local frames = {}

local SECRET = setmetatable({}, {
    __tostring = function() error("secret value stringified") end,
    __eq = function() error("secret value compared") end,
    __lt = function() error("secret value compared") end,
    __le = function() error("secret value compared") end,
    __div = function() error("secret value divided") end,
    __index = function() error("secret value indexed") end,
})

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertNear(actual, expected, message)
    if type(actual) ~= "number" or math.abs(actual - expected) > 0.002 then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

function canaccessvalue(value) return not rawequal(value, SECRET) end
function issecretvalue(value) return rawequal(value, SECRET) end
function issecrettable(value) return rawequal(value, SECRET) end
function InCombatLockdown() return combat end
function date() return "12:34:56" end

DEFAULT_CHAT_FRAME = {}
function DEFAULT_CHAT_FRAME:AddMessage(message) chat[#chat + 1] = message end
SlashCmdList = {}
GameFontHighlightSmall = {}
RAID_CLASS_COLORS = { DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 } }
PowerBarColor = { RUNIC_POWER = { r = 0.0, g = 0.82, b = 1.0 } }

function UnitClass() return "Death Knight", "DEATHKNIGHT" end
function UnitPowerType()
    if powerMode == "secret-type" then return SECRET, SECRET, SECRET, SECRET, SECRET end
    return currentType, currentToken, 0.0, 0.82, 1.0
end
function UnitPower()
    if powerMode == "secret" or powerMode == "secret-curve" then return SECRET end
    return currentPower
end
function UnitPowerMax()
    if powerMode == "secret" or powerMode == "secret-curve" then return SECRET end
    return maxPower
end

local function NewColor(r, g, b, a)
    local color = { r = r, g = g, b = b, a = a or 1 }
    function color:GetRGB() return self.r, self.g, self.b end
    return color
end
function CreateColor(r, g, b, a) return NewColor(r, g, b, a) end

local function EvaluateCurve(curve, value)
    if curve.kind == "scale100" then return value * 100 end
    local selected = curve.points[1][2]
    for _, point in ipairs(curve.points) do
        if value >= point[1] then selected = point[2] end
    end
    return selected
end

C_CurveUtil = {}
function C_CurveUtil.CreateColorCurve()
    local curve = { points = {}, kind = "color" }
    function curve:SetType(value) self.curveType = value end
    function curve:AddPoint(x, value) self.points[#self.points + 1] = { x, value } end
    return curve
end
Enum = { LuaCurveType = { Linear = 1 } }
CurveConstants = { ScaleTo100 = { kind = "scale100" } }
function UnitPowerPercent(_, _, _, curve)
    local fraction = currentPower / maxPower
    if powerMode == "secret-curve" then return SECRET end
    if curve then return EvaluateCurve(curve, fraction) end
    if powerMode == "secret" then return SECRET end
    return fraction
end

local function NewObject(objectType, name, parent)
    local object = {
        objectType = objectType or "Frame",
        name = name,
        parent = parent,
        shown = true,
        width = 1,
        height = 1,
        point = { "CENTER", parent, "CENTER", 0, 0 },
        scripts = {},
        events = {},
        statusColor = { 1, 1, 1 },
    }
    function object:SetSize(w, h) self.width, self.height = w, h end
    function object:GetSize() return self.width, self.height end
    function object:SetPoint(...) self.point = { ... } end
    function object:GetPoint() return unpack(self.point) end
    function object:ClearAllPoints() self.point = {} end
    function object:SetClampedToScreen(value) self.clamped = value end
    function object:SetMovable(value) self.movable = value end
    function object:SetBackdrop(value) self.backdrop = value end
    function object:SetBackdropColor(...) self.backdropColor = { ... } end
    function object:SetBackdropBorderColor(...) self.backdropBorderColor = { ... } end
    function object:SetAllPoints(value) self.allPoints = value end
    function object:SetStatusBarTexture(value) self.statusTexture = value end
    function object:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function object:SetValue(value) self.value = value end
    function object:SetStatusBarColor(...) self.statusColor = { ... } end
    function object:CreateFontString()
        local font = NewObject("FontString", nil, self)
        self.font = font
        return font
    end
    function object:SetJustifyH(value) self.justify = value end
    function object:SetText(value) self.text = value end
    function object:SetTextColor(...) self.textColor = { ... } end
    function object:SetShown(value) self.shown = value == true end
    function object:IsShown() return self.shown end
    function object:Show() self.shown = true end
    function object:Hide() self.shown = false end
    function object:EnableMouse(value) self.mouse = value end
    function object:RegisterForDrag(...) self.drag = { ... } end
    function object:SetScript(name, callback) self.scripts[name] = callback end
    function object:GetScript(name) return self.scripts[name] end
    function object:StartMoving() self.moving = true end
    function object:StopMovingOrSizing() self.moving = false end
    function object:RegisterEvent(event) self.events[event] = true end
    function object:RegisterUnitEvent(event, unit) self.events[event] = unit end
    frames[#frames + 1] = object
    if name then _G[name] = object end
    return object
end

function CreateFrame(objectType, name, parent) return NewObject(objectType, name, parent) end
UIParent = NewObject("Frame", "UIParent")

NeomorphResourcePanelDB = {
    version = 1,
    enabled = true,
    locked = false,
    threshold = 2,
    width = 99999,
    height = -2,
    showText = true,
    debug = SECRET,
    point = "INVALID",
    relativePoint = "INVALID",
    x = 9000,
    y = -9000,
    percentScale = 100,
}

local namespace = {}
assert(loadfile("core/DB.lua"))("NeomorphResourcePanel", namespace)
assert(loadfile("core/Debug.lua"))("NeomorphResourcePanel", namespace)
assert(loadfile("modules/ResourceBar.lua"))("NeomorphResourcePanel", namespace)
assert(loadfile("core/Init.lua"))("NeomorphResourcePanel", namespace)

local db = namespace.GetDB()
assertEqual(db.version, 2, "schema version")
assertNear(db.threshold, 1, "threshold clamp")
assertEqual(db.width, 1200, "width clamp")
assertEqual(db.height, 6, "height clamp")
assertEqual(db.debug, false, "secret debug flag must default off")
assertEqual(db.point, "CENTER", "invalid point")
assertEqual(db.relativePoint, "CENTER", "invalid relative point")
assertEqual(db.x, 4000, "x clamp")
assertEqual(db.y, -4000, "y clamp")
assertEqual(db.percentScale, nil, "obsolete percentScale")

namespace.EventFrame.scripts.OnEvent(namespace.EventFrame, "PLAYER_LOGIN")
local barModule = namespace.ResourceBar
local frame = assert(barModule.frame)
assertEqual(#chat, 0, "debug default emitted chat")
assertEqual(frame.width, 1200, "DB width not applied")
assertEqual(frame.height, 6, "DB height not applied")
assertEqual(frame.mouse, true, "unlocked frame should accept drag")

db.width, db.height, db.threshold = 260, 18, 0.80
barModule:ApplyDB(true)
currentPower, maxPower = 85, 100
powerMode = "ordinary"
combat = true
barModule:UpdateAll()
assertNear(frame.bar.statusColor[1], 1.0, "above-threshold combat color")
assertNear(frame.bar.statusColor[2], 0.1, "above-threshold combat color green")
assertEqual(frame.text.text, "85 / 100 (85%)", "ordinary text")

currentPower = 25
barModule:OnPowerUpdate("RUNIC_POWER")
assertNear(frame.bar.statusColor[1], 0.0, "below-threshold resource color")
assertNear(frame.bar.statusColor[2], 0.82, "below-threshold resource color green")

currentPower = 90
powerMode = "secret"
local secretOK, secretError = pcall(function() barModule:UpdateAll() end)
assertEqual(secretOK, true, "secret power escaped boundary: " .. tostring(secretError))
assertEqual(rawequal(frame.bar.maximum, SECRET), true, "secret max not forwarded to StatusBar")
assertEqual(rawequal(frame.bar.value, SECRET), true, "secret current not forwarded to StatusBar")
assertNear(frame.bar.statusColor[1], 1.0, "curve did not produce warning color")
assertEqual(frame.text.text, "90%", "curve percent text")

powerMode = "secret-curve"
local curveOK, curveError = pcall(function() barModule:ApplyColor() end)
assertEqual(curveOK, true, "secret curve escaped boundary: " .. tostring(curveError))
assertNear(frame.bar.statusColor[1], 0.0, "secret curve did not fall back to base")
assertNear(frame.bar.statusColor[2], 0.82, "secret curve base green")

powerMode = "ordinary"
currentPower = 50
local tokenOK, tokenError = pcall(function() barModule:OnPowerUpdate(SECRET) end)
assertEqual(tokenOK, true, "secret event token escaped boundary: " .. tostring(tokenError))
assertEqual(frame.bar.value, 50, "secret token did not refresh")

namespace.SlashCommand("lock")
assertEqual(db.locked, true, "lock toggle")
assertEqual(frame.mouse, false, "locked frame still intercepts mouse")
local oldDB = NeomorphResourcePanelDB
namespace.SlashCommand("reset")
assertEqual(NeomorphResourcePanelDB, oldDB, "combat reset replaced DB")
combat = false
namespace.SlashCommand("reset")
db = namespace.GetDB()
assertEqual(db.threshold, 0.80, "reset threshold")
assertEqual(db.debug, false, "reset debug")
assertEqual(frame.width, 260, "reset width")
assertEqual(frame.height, 18, "reset height")

namespace.SlashCommand("debug")
local debugOK, debugError = pcall(function() namespace.Debug.Log("payload=%s", SECRET) end)
assertEqual(debugOK, true, "debug secret escaped boundary: " .. tostring(debugError))
assert(chat[#chat]:find("inaccessible payload", 1, true) ~= nil, "debug payload was not sanitized")

local function Read(path)
    local handle = assert(io.open(path, "rb"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local toc = Read("NeomorphResourcePanel.toc")
assert(toc:find("## Interface: 120100", 1, true), "wrong interface")
assert(toc:find("## Version: 0.2.0", 1, true), "wrong version")
local runtime = Read("core/DB.lua") .. Read("core/Debug.lua") .. Read("modules/ResourceBar.lua") .. Read("core/Init.lua")
for _, forbidden in ipairs({ "COMBAT_LOG_EVENT_UNFILTERED", 'SetScript("OnUpdate"', "C_Timer.NewTicker", "UNIT_AURA" }) do
    assert(not runtime:find(forbidden, 1, true), "forbidden runtime token: " .. forbidden)
end
assert(runtime:find("UnitPowerPercent", 1, true), "secret-safe percent path missing")
assert(runtime:find("SetMinMaxValues", 1, true), "native StatusBar sink missing")
assert(runtime:find("SetValue", 1, true), "native StatusBar value sink missing")

print("PASS: schema, access-first power handling, curve threshold, native sinks, event tokens, locking, reset and debug sanitization")

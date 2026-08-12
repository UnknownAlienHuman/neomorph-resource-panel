-- NeomorphResourcePanel
-- Resource bar module: displays current player power (runic power / energy / mana / etc.)
-- Base color = resource color (PowerBarColor / UnitPowerType altColor). In combat: turns red if power% >= threshold.

local ADDON_NAME, NS = ...

NS.ResourceBar = NS.ResourceBar or {}
local M = NS.ResourceBar

local RED_R, RED_G, RED_B = 1.0, 0.1, 0.1

local function IsSecret(v)
    -- Midnight: some APIs return "secret" values in combat; math/compare on them is forbidden.
    return type(issecretvalue) == "function" and issecretvalue(v) or false
end

local function GetClassColor()
    local _, classTag = UnitClass("player")
    local c = classTag and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag]
    if c then
        return c.r, c.g, c.b
    end
    return 0.5, 0.5, 0.5
end

local function GetPowerColor(powerToken, altR, altG, altB)
    -- Prefer alt color from UnitPowerType (used for some special display modes)
    if type(altR) == "number" and type(altG) == "number" and type(altB) == "number" and not IsSecret(altR) and not IsSecret(altG) and not IsSecret(altB) then
        return altR, altG, altB
    end

    local pbc = _G.PowerBarColor
    local c = (pbc and powerToken and pbc[powerToken]) or nil
    if c and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
        return c.r, c.g, c.b
    end

    return GetClassColor()
end

local function SetBarColor(bar, r, g, b)
    -- Avoid redundant GPU state changes (only safe for non-secret scalars).
    if not IsSecret(r) and not IsSecret(g) and not IsSecret(b) then
        if bar.__r == r and bar.__g == g and bar.__b == b then return end
        bar.__r, bar.__g, bar.__b = r, g, b
    else
        -- Don't cache secret components; later comparisons would throw.
        bar.__r, bar.__g, bar.__b = nil, nil, nil
    end
    bar:SetStatusBarColor(r, g, b)
end

local function SetTextColor(fs, r, g, b)
    if not fs then return end
    if not IsSecret(r) and not IsSecret(g) and not IsSecret(b) then
        if fs.__r == r and fs.__g == g and fs.__b == b then return end
        fs.__r, fs.__g, fs.__b = r, g, b
    else
        fs.__r, fs.__g, fs.__b = nil, nil, nil
    end
    fs:SetTextColor(r, g, b)
end

local function MakeColorKey(r, g, b)
    return string.format("%.3f|%.3f|%.3f", r or 0, g or 0, b or 0)
end

function M:Create(parent)
    local db = NS.GetDB()

    local f = CreateFrame("Frame", "NeomorphResourcePanelFrame", parent or UIParent, "BackdropTemplate")
    f:SetSize(db.width, db.height)
    f:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    f:SetClampedToScreen(true)

    -- Simple backdrop
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.45)
    f:SetBackdropBorderColor(0, 0, 0, 0.9)

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetAllPoints(true)
    bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local text
    if db.showText then
        text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")
    end

    f.bar = bar
    f.text = text

    -- Movable when unlocked
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(self)
        if NS.GetDB().locked then return end
        if InCombatLockdown() then
            if NS.Debug then NS.Debug.Log("Move blocked in combat") end
            return
        end
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        local db2 = NS.GetDB()
        db2.point, db2.relativePoint, db2.x, db2.y = p, rp, x, y
        if NS.Debug then NS.Debug.Log("Saved position: %s/%s %.0f %.0f", p or "?", rp or "?", x or 0, y or 0) end
    end)

    self.frame = f

    -- Cached state
    self.baseR, self.baseG, self.baseB = GetClassColor()
    self.powerType = nil
    self.powerToken = nil

    -- Percent scale for UnitPowerPercent (some builds return 0..1, others 0..100). Detect out of combat.
    self.percentScale = 1

    -- Curve-driven recolor (used when percent becomes a secret value in combat)
    self.combatColorCurve = nil
    self._curveThreshold = nil
    self._curveBaseKey = nil
    self._curveScale = nil

    self.lastMax = nil
    self.lastToken = nil

    self:UpdateAll()

    return f
end

function M:UpdatePercentScale(unit, powerType)
    if type(UnitPowerPercent) ~= "function" then
        self.percentScale = 1
        return
    end

    -- Only probe when return is not secret (i.e., safe out of combat / safe path)
    local ok, pct = pcall(UnitPowerPercent, unit, powerType)
    if ok and type(pct) == "number" and not IsSecret(pct) then
        -- If it ever returns > 1.5, treat it as 0..100 scale.
        self.percentScale = (pct > 1.5) and 100 or 1
    end
end

function M:EnsureCombatCurve(threshold)
    threshold = threshold or 0.80
    if threshold < 0 then threshold = 0 end
    if threshold > 1 then threshold = 1 end

    local scale = self.percentScale or 1
    local baseKey = MakeColorKey(self.baseR, self.baseG, self.baseB)

    if self.combatColorCurve and self._curveThreshold == threshold and self._curveBaseKey == baseKey and self._curveScale == scale then
        return
    end

    local curve = C_CurveUtil and C_CurveUtil.CreateColorCurve and C_CurveUtil.CreateColorCurve() or nil
    if not curve then
        self.combatColorCurve = nil
        return
    end

    -- Use a tiny linear transition band to avoid relying on Step semantics.
    curve:SetType(Enum.LuaCurveType.Linear)

    local maxX = (scale == 100) and 100 or 1
    local t = threshold * scale
    local delta = (scale == 100) and 0.1 or 0.001
    local t2 = t + delta
    if t2 > maxX then t2 = maxX end

    curve:AddPoint(0, CreateColor(self.baseR, self.baseG, self.baseB, 1))
    curve:AddPoint(t, CreateColor(self.baseR, self.baseG, self.baseB, 1))
    curve:AddPoint(t2, CreateColor(RED_R, RED_G, RED_B, 1))
    curve:AddPoint(maxX, CreateColor(RED_R, RED_G, RED_B, 1))

    self.combatColorCurve = curve
    self._curveThreshold = threshold
    self._curveBaseKey = baseKey
    self._curveScale = scale
end

function M:ApplyColor(unit)
    if not self.frame then return end

    local db = NS.GetDB()
    local threshold = db.threshold or 0.80

    -- Out of combat: always base (resource) color
    if not InCombatLockdown() then
        SetBarColor(self.frame.bar, self.baseR, self.baseG, self.baseB)
        SetTextColor(self.frame.text, 1, 1, 1)
        return
    end

    local powerType = self.powerType
    if powerType == nil then
        SetBarColor(self.frame.bar, self.baseR, self.baseG, self.baseB)
        SetTextColor(self.frame.text, 1, 1, 1)
        return
    end

    -- Combat: try non-secret fast path
    local max = UnitPowerMax(unit, powerType)
    local cur = UnitPower(unit, powerType)
    if type(max) == "number" and type(cur) == "number" and not IsSecret(max) and not IsSecret(cur) and max > 0 then
        local pct = cur / max
        if pct >= threshold then
            SetBarColor(self.frame.bar, RED_R, RED_G, RED_B)
        else
            SetBarColor(self.frame.bar, self.baseR, self.baseG, self.baseB)
        end
        SetTextColor(self.frame.text, 1, 1, 1)
        return
    end

    -- Combat + secret percent: use curve evaluation (no math/compare in addon code)
    self:EnsureCombatCurve(threshold)
    if self.combatColorCurve and type(UnitPowerPercent) == "function" then
        local ok, color = pcall(UnitPowerPercent, unit, powerType, false, self.combatColorCurve)
        if ok and color and color.GetRGB then
            local r, g, b = color:GetRGB()
            SetBarColor(self.frame.bar, r, g, b)
            SetTextColor(self.frame.text, 1, 1, 1)
            return
        end
    end

    -- Fallback
    SetBarColor(self.frame.bar, self.baseR, self.baseG, self.baseB)
    SetTextColor(self.frame.text, 1, 1, 1)
end

function M:UpdateAll()
    if not self.frame then return end

    local unit = "player"

    local powerType, powerToken, altR, altG, altB = UnitPowerType(unit)
    self.powerType = powerType
    self.powerToken = powerToken

    -- Refresh base color for current resource
    self.baseR, self.baseG, self.baseB = GetPowerColor(powerToken, altR, altG, altB)

    -- Probe UnitPowerPercent output scaling when safe (out of combat typically)
    if not InCombatLockdown() then
        self:UpdatePercentScale(unit, powerType)
    end

    local max = UnitPowerMax(unit, powerType)
    local cur = UnitPower(unit, powerType)

    -- Update bar range/value without doing any math (works with secret values).
    if not max then
        self.frame.bar:SetMinMaxValues(0, 1)
        self.frame.bar:SetValue(0)
    else
        if IsSecret(max) or type(max) ~= "number" then
            self.frame.bar:SetMinMaxValues(0, max)
        else
            if max <= 0 then
                self.frame.bar:SetMinMaxValues(0, 1)
                self.frame.bar:SetValue(0)
                if self.frame.text then self.frame.text:SetText(powerToken or "") end
                self.lastToken = powerToken
                self:ApplyColor(unit)
                return
            end
            if self.lastMax ~= max then
                self.frame.bar:SetMinMaxValues(0, max)
                self.lastMax = max
            end
        end
        self.frame.bar:SetValue(cur or 0)
    end

    -- Text only when values are non-secret numbers.
    if self.frame.text then
        if type(cur) == "number" and type(max) == "number" and not IsSecret(cur) and not IsSecret(max) and max > 0 then
            local pct = (cur / max) * 100
            self.frame.text:SetText(string.format("%d / %d (%.0f%%)", cur, max, pct))
        else
            self.frame.text:SetText(powerToken or "")
        end
    end

    self.lastToken = powerToken

    self:ApplyColor(unit)
end

function M:OnPowerUpdate(unit, powerTypeToken)
    if unit ~= "player" then return end

    -- If token is provided, update only when it matches current token.
    if powerTypeToken and self.lastToken and powerTypeToken ~= self.lastToken then
        return
    end

    self:UpdateAll()
end

function M:OnDisplayPower()
    -- Power type switched (forms/vehicles/etc.)
    self.lastMax = nil
    self.lastToken = nil
    self.combatColorCurve = nil
    self._curveBaseKey = nil
    self:UpdateAll()
end

function M:OnCombatChange()
    -- Force recolor even if power didn't change
    self:UpdateAll()
end

function M:ApplyDB()
    if not self.frame then return end
    local db = NS.GetDB()
    self.frame:SetSize(db.width, db.height)
end

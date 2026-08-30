local ADDON_NAME, NS = ...
NS.ResourceBar = NS.ResourceBar or {}
local M = NS.ResourceBar
local Safe = NS.Safe

local RED_R, RED_G, RED_B = 1.0, 0.1, 0.1
local FALLBACK_R, FALLBACK_G, FALLBACK_B = 0.5, 0.5, 0.5

local function OrdinaryRGB(r, g, b)
    r, g, b = Safe.Number(r), Safe.Number(g), Safe.Number(b)
    if r and g and b then return r, g, b end
    return nil
end

local function GetClassColor()
    if type(UnitClass) ~= "function" then return FALLBACK_R, FALLBACK_G, FALLBACK_B end
    local ok, _, classTag = pcall(UnitClass, "player")
    classTag = ok and Safe.String(classTag) or nil
    local colors = Safe.Table(_G.RAID_CLASS_COLORS)
    local color = colors and classTag and Safe.Table(colors[classTag]) or nil
    if color then
        local r, g, b = OrdinaryRGB(color.r, color.g, color.b)
        if r then return r, g, b end
    end
    return FALLBACK_R, FALLBACK_G, FALLBACK_B
end

local function GetPowerColor(powerToken, altR, altG, altB)
    local r, g, b = OrdinaryRGB(altR, altG, altB)
    if r then return r, g, b end

    powerToken = Safe.String(powerToken)
    local colors = Safe.Table(_G.PowerBarColor)
    local color = colors and powerToken and Safe.Table(colors[powerToken]) or nil
    if color then
        r, g, b = OrdinaryRGB(color.r, color.g, color.b)
        if r then return r, g, b end
    end
    return GetClassColor()
end

local function SetBarColor(self, r, g, b)
    r, g, b = OrdinaryRGB(r, g, b)
    if not r then r, g, b = self.baseR, self.baseG, self.baseB end
    if self.colorR == r and self.colorG == g and self.colorB == b then return end
    self.colorR, self.colorG, self.colorB = r, g, b
    pcall(self.frame.bar.SetStatusBarColor, self.frame.bar, r, g, b)
end

local function SetText(self, value)
    if self.frame and self.frame.text then
        pcall(self.frame.text.SetText, self.frame.text, Safe.String(value) or "")
    end
end

local function CreateThresholdCurve(self, threshold)
    threshold = Safe.Clamp(threshold, 0.80, 0, 1)
    if self.thresholdCurve and self.curveThreshold == threshold
        and self.curveR == self.baseR and self.curveG == self.baseG and self.curveB == self.baseB then
        return self.thresholdCurve
    end

    if not (C_CurveUtil and type(C_CurveUtil.CreateColorCurve) == "function"
        and Enum and Enum.LuaCurveType and type(CreateColor) == "function") then
        self.thresholdCurve = nil
        return nil
    end

    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return nil end
    local epsilon = 0.001
    local transition = math.min(1, threshold + epsilon)
    local curveType = Enum.LuaCurveType.Linear
    local points = {
        { 0, CreateColor(self.baseR, self.baseG, self.baseB, 1) },
        { threshold, CreateColor(self.baseR, self.baseG, self.baseB, 1) },
        { transition, CreateColor(RED_R, RED_G, RED_B, 1) },
        { 1, CreateColor(RED_R, RED_G, RED_B, 1) },
    }
    local configured = pcall(function()
        curve:SetType(curveType)
        for _, point in ipairs(points) do curve:AddPoint(point[1], point[2]) end
    end)
    if not configured then return nil end

    self.thresholdCurve = curve
    self.curveThreshold = threshold
    self.curveR, self.curveG, self.curveB = self.baseR, self.baseG, self.baseB
    return curve
end

local function EvaluateThresholdColor(self)
    if type(UnitPowerPercent) ~= "function" or self.powerType == nil then return nil end
    local curve = CreateThresholdCurve(self, NS.GetDB().threshold)
    if not curve then return nil end

    local ok, color = pcall(UnitPowerPercent, "player", self.powerType, false, curve)
    if not ok or not Safe.CanAccess(color) then return nil end
    local getRGB = color and color.GetRGB
    if type(getRGB) ~= "function" then return nil end
    local rgbOK, r, g, b = pcall(getRGB, color)
    if not rgbOK then return nil end
    return OrdinaryRGB(r, g, b)
end

local function GetPercentText(powerType)
    if type(UnitPowerPercent) ~= "function" or not CurveConstants or not CurveConstants.ScaleTo100 then return nil end
    local ok, percent = pcall(UnitPowerPercent, "player", powerType, false, CurveConstants.ScaleTo100)
    percent = ok and Safe.Number(percent) or nil
    if not percent then return nil end
    local formatOK, text = pcall(string.format, "%.0f%%", percent)
    return formatOK and text or nil
end

local function ApplyPosition(self)
    local db = NS.GetDB()
    self.frame:ClearAllPoints()
    self.frame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
end

function M:Create(parent)
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "NeomorphResourcePanelFrame", parent or UIParent, "BackdropTemplate")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0, 0, 0, 0.45)
    frame:SetBackdropBorderColor(0, 0, 0, 0.9)

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetAllPoints(frame)
    bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")

    frame.bar = bar
    frame.text = text
    self.frame = frame
    self.baseR, self.baseG, self.baseB = GetClassColor()

    frame:SetScript("OnDragStart", function(owner)
        local current = NS.GetDB()
        if current.locked or Safe.InCombat() then
            if NS.Debug then NS.Debug.Log("Move blocked: locked=%s combat=%s", current.locked, Safe.InCombat()) end
            return
        end
        owner:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(owner)
        owner:StopMovingOrSizing()
        local point, _, relativePoint, x, y = owner:GetPoint(1)
        point, relativePoint = Safe.String(point), Safe.String(relativePoint)
        x, y = Safe.Number(x), Safe.Number(y)
        if point and relativePoint and x and y then
            local current = NS.GetDB()
            current.point, current.relativePoint = point, relativePoint
            current.x, current.y = math.floor(x + 0.5), math.floor(y + 0.5)
            if NS.Debug then NS.Debug.Log("Saved position: %s/%s %d %d", point, relativePoint, current.x, current.y) end
        end
    end)

    self:ApplyDB(true)
    self:UpdateAll()
    return frame
end

function M:ApplyDB(applyPosition)
    if not self.frame then return end
    local db = NS.GetDB()
    self.frame:SetSize(db.width, db.height)
    self.frame:SetShown(db.enabled)
    self.frame.text:SetShown(db.showText)
    self.frame:EnableMouse(not db.locked)
    if db.locked then self.frame:RegisterForDrag() else self.frame:RegisterForDrag("LeftButton") end
    if applyPosition then ApplyPosition(self) end
end

function M:UpdatePowerType()
    local ok, powerType, powerToken, altR, altG, altB = pcall(UnitPowerType, "player")
    if not ok then
        self.powerType, self.powerToken = nil, nil
        self.baseR, self.baseG, self.baseB = GetClassColor()
        return
    end

    self.powerType = Safe.Number(powerType)
    self.powerToken = Safe.String(powerToken)
    self.baseR, self.baseG, self.baseB = GetPowerColor(self.powerToken, altR, altG, altB)
    self.thresholdCurve = nil
    self.colorR, self.colorG, self.colorB = nil, nil, nil
end

function M:UpdateValue()
    if not self.frame or self.powerType == nil then return end
    local maxOK, maximum = pcall(UnitPowerMax, "player", self.powerType)
    local valueOK, current = pcall(UnitPower, "player", self.powerType)
    if not maxOK or not valueOK then
        self.frame.bar:SetMinMaxValues(0, 1)
        self.frame.bar:SetValue(0)
        SetText(self, self.powerToken or "")
        return
    end

    local ordinaryMax = Safe.Number(maximum)
    local ordinaryCurrent = Safe.Number(current)
    if ordinaryMax ~= nil then
        if ordinaryMax <= 0 then
            self.frame.bar:SetMinMaxValues(0, 1)
            self.frame.bar:SetValue(0)
            SetText(self, self.powerToken or "")
            return
        end
        self.frame.bar:SetMinMaxValues(0, ordinaryMax)
    else
        local ok = pcall(self.frame.bar.SetMinMaxValues, self.frame.bar, 0, maximum)
        if not ok then self.frame.bar:SetMinMaxValues(0, 1) end
    end

    if ordinaryCurrent ~= nil then
        self.frame.bar:SetValue(ordinaryCurrent)
    else
        local ok = pcall(self.frame.bar.SetValue, self.frame.bar, current)
        if not ok then self.frame.bar:SetValue(0) end
    end

    if NS.GetDB().showText then
        local percentText = GetPercentText(self.powerType)
        if ordinaryCurrent ~= nil and ordinaryMax ~= nil then
            local text
            if percentText then
                text = string.format("%d / %d (%s)", ordinaryCurrent, ordinaryMax, percentText)
            else
                text = string.format("%d / %d", ordinaryCurrent, ordinaryMax)
            end
            SetText(self, text)
        else
            SetText(self, percentText or self.powerToken or "")
        end
    end
end

function M:ApplyColor()
    if not self.frame then return end
    if self.powerType == nil then
        SetBarColor(self, self.baseR, self.baseG, self.baseB)
        return
    end
    if not Safe.InCombat() then
        SetBarColor(self, self.baseR, self.baseG, self.baseB)
        return
    end

    local r, g, b = EvaluateThresholdColor(self)
    if r then
        SetBarColor(self, r, g, b)
        return
    end

    local maxOK, maximum = pcall(UnitPowerMax, "player", self.powerType)
    local valueOK, current = pcall(UnitPower, "player", self.powerType)
    maximum = maxOK and Safe.Number(maximum) or nil
    current = valueOK and Safe.Number(current) or nil
    if maximum and current and maximum > 0 then
        if (current / maximum) >= NS.GetDB().threshold then
            SetBarColor(self, RED_R, RED_G, RED_B)
        else
            SetBarColor(self, self.baseR, self.baseG, self.baseB)
        end
        return
    end

    SetBarColor(self, self.baseR, self.baseG, self.baseB)
end

function M:UpdateAll()
    if not self.frame then return end
    self:UpdatePowerType()
    self:UpdateValue()
    self:ApplyColor()
end

function M:OnPowerUpdate(powerTypeToken)
    local token = Safe.String(powerTypeToken)
    if token and self.powerToken and token ~= self.powerToken then return end
    self:UpdateValue()
    self:ApplyColor()
end

function M:OnDisplayPower()
    self:UpdateAll()
end

function M:OnCombatChange()
    self:UpdateValue()
    self:ApplyColor()
end

function M:ResetPosition()
    if not self.frame or Safe.InCombat() then return false end
    ApplyPosition(self)
    return true
end

M.Runtime = {
    EvaluateThresholdColor = function() return EvaluateThresholdColor(M) end,
    GetPercentText = GetPercentText,
}

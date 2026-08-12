-- NeomorphResourcePanel
-- Core bootstrap: creates modules, registers events, slash commands.

local ADDON_NAME, NS = ...

local Debug = NS.Debug

local function EnsureModules()
    NS.GetDB() -- ensure defaults

    if not NS.ResourceBar or not NS.ResourceBar.Create then
        error("NeomorphResourcePanel: ResourceBar module missing")
    end
end

local function CreateUI()
    NS.ResourceBar:Create(UIParent)
    NS.ResourceBar:ApplyDB()
end

-- Event dispatcher frame
local E = CreateFrame("Frame")

E:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        EnsureModules()
        CreateUI()
        if Debug then Debug.Log("Loaded") end
        return
    end

    if not NS.ResourceBar or not NS.ResourceBar.frame then
        return
    end

    if event == "UNIT_POWER_UPDATE" then
        local unit, powerTypeToken = ...
        NS.ResourceBar:OnPowerUpdate(unit, powerTypeToken)
    elseif event == "UNIT_MAXPOWER" then
        local unit = ...
        if unit == "player" then NS.ResourceBar:UpdateAll() end
    elseif event == "UNIT_DISPLAYPOWER" then
        local unit = ...
        if unit == "player" then NS.ResourceBar:OnDisplayPower() end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        NS.ResourceBar:OnCombatChange()
    elseif event == "PLAYER_ENTERING_WORLD" then
        NS.ResourceBar:UpdateAll()
    end
end)

E:RegisterEvent("PLAYER_LOGIN")
E:RegisterEvent("PLAYER_ENTERING_WORLD")
E:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
E:RegisterUnitEvent("UNIT_MAXPOWER", "player")
E:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
E:RegisterEvent("PLAYER_REGEN_DISABLED")
E:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Slash commands
SLASH_NEOMORPHRESOURCEPANEL1 = "/nrp"
SlashCmdList["NEOMORPHRESOURCEPANEL"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local db = NS.GetDB()

    if msg == "" or msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("NRP commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /nrp lock        - toggle move lock")
        DEFAULT_CHAT_FRAME:AddMessage("  /nrp reset       - reset position/settings")
        DEFAULT_CHAT_FRAME:AddMessage("  /nrp threshold x - set threshold (0..1), e.g. /nrp threshold 0.8")
        DEFAULT_CHAT_FRAME:AddMessage("  /nrp log [n]     - print last n debug lines")
        return
    end

    if msg == "lock" then
        db.locked = not db.locked
        DEFAULT_CHAT_FRAME:AddMessage("NRP locked: " .. tostring(db.locked))
        return
    end

    if msg == "reset" then
        if InCombatLockdown() then
            DEFAULT_CHAT_FRAME:AddMessage("NRP: reset blocked in combat")
            return
        end
        db = NS.ResetDB()
        if NS.ResourceBar and NS.ResourceBar.frame then
            NS.ResourceBar.frame:ClearAllPoints()
            NS.ResourceBar.frame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
            NS.ResourceBar:ApplyDB()
            NS.ResourceBar:UpdateAll()
        end
        DEFAULT_CHAT_FRAME:AddMessage("NRP: reset")
        return
    end

    if msg:match("^threshold") then
        local v = tonumber(msg:match("threshold%s+([%d%.]+)"))
        if not v or v < 0 or v > 1 then
            DEFAULT_CHAT_FRAME:AddMessage("NRP: invalid threshold. Use 0..1")
            return
        end
        db.threshold = v
        DEFAULT_CHAT_FRAME:AddMessage(string.format("NRP threshold: %.2f", v))
        if NS.ResourceBar then NS.ResourceBar:UpdateAll() end
        return
    end

    if msg:match("^log") then
        local n = tonumber(msg:match("log%s+(%d+)") or "30")
        if NS.Debug then NS.Debug.Dump(n) end
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("NRP: unknown command. /nrp help")
end

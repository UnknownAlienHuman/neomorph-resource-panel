local ADDON_NAME, NS = ...
local Safe = NS.Safe
local Debug = NS.Debug

local function Chat(message)
    message = Safe.String(message) or "<unavailable>"
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(message) end
end

local function EnsureUI()
    NS.GetDB()
    if not NS.ResourceBar or not NS.ResourceBar.Create then
        Chat("NRP: ResourceBar module missing")
        return false
    end
    NS.ResourceBar:Create(UIParent)
    NS.ResourceBar:ApplyDB(true)
    return true
end

local Events = CreateFrame("Frame")
Events:RegisterEvent("PLAYER_LOGIN")
Events:RegisterEvent("PLAYER_ENTERING_WORLD")
Events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
Events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
Events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
Events:RegisterEvent("PLAYER_REGEN_DISABLED")
Events:RegisterEvent("PLAYER_REGEN_ENABLED")

Events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if EnsureUI() and Debug then Debug.Log("Loaded %s", NS.VERSION) end
        return
    end

    local resource = NS.ResourceBar
    if not resource or not resource.frame then return end

    if event == "UNIT_POWER_UPDATE" then
        local _, powerTypeToken = ...
        resource:OnPowerUpdate(powerTypeToken)
    elseif event == "UNIT_MAXPOWER" then
        resource:UpdateAll()
    elseif event == "UNIT_DISPLAYPOWER" then
        resource:OnDisplayPower()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        resource:OnCombatChange()
    elseif event == "PLAYER_ENTERING_WORLD" then
        resource:UpdateAll()
    end
end)

local function Help()
    Chat("NRP commands:")
    Chat("  /nrp lock             - toggle move lock")
    Chat("  /nrp toggle           - show/hide the resource panel")
    Chat("  /nrp text             - toggle numeric text")
    Chat("  /nrp threshold <0..1> - set the combat warning threshold")
    Chat("  /nrp reset            - reset position and settings")
    Chat("  /nrp debug            - toggle debug logging")
    Chat("  /nrp log [n]          - print recent debug lines")
    Chat("  /nrp status           - print current configuration")
end

local function Slash(message)
    message = Safe.String(message) or ""
    message = message:lower():gsub("^%s+", ""):gsub("%s+$", "")
    local db = NS.GetDB()
    local resource = NS.ResourceBar

    if message == "" or message == "help" then
        Help()
    elseif message == "lock" then
        db.locked = not db.locked
        if resource then resource:ApplyDB(false) end
        Chat("NRP locked: " .. tostring(db.locked))
    elseif message == "toggle" then
        db.enabled = not db.enabled
        if resource then resource:ApplyDB(false) end
        Chat("NRP enabled: " .. tostring(db.enabled))
    elseif message == "text" then
        db.showText = not db.showText
        if resource then resource:ApplyDB(false); resource:UpdateValue() end
        Chat("NRP text: " .. tostring(db.showText))
    elseif message == "reset" then
        if Safe.InCombat() then
            Chat("NRP: reset blocked in combat")
            return
        end
        db = NS.ResetDB()
        if resource and resource.frame then
            resource:ApplyDB(true)
            resource:UpdateAll()
        end
        Chat("NRP: settings reset")
    elseif message:match("^threshold") then
        local value = tonumber(message:match("^threshold%s+([%d%.]+)$"))
        if not value or value < 0 or value > 1 then
            Chat("NRP: invalid threshold; use 0..1")
            return
        end
        db.threshold = value
        if resource then resource.thresholdCurve = nil; resource:ApplyColor() end
        Chat(string.format("NRP threshold: %.2f", value))
    elseif message == "debug" then
        db.debug = not db.debug
        Chat("NRP debug: " .. tostring(db.debug))
        if db.debug and Debug then Debug.Log("Debug enabled") end
    elseif message:match("^log") then
        local amount = tonumber(message:match("^log%s+(%d+)$")) or 30
        if Debug then Debug.Dump(amount) end
    elseif message == "status" then
        Chat(string.format(
            "NRP v%s enabled=%s locked=%s threshold=%.2f size=%dx%d text=%s debug=%s",
            NS.VERSION, tostring(db.enabled), tostring(db.locked), db.threshold,
            db.width, db.height, tostring(db.showText), tostring(db.debug)
        ))
    else
        Chat("NRP: unknown command; use /nrp help")
    end
end

SLASH_NEOMORPHRESOURCEPANEL1 = "/nrp"
SlashCmdList.NEOMORPHRESOURCEPANEL = Slash

NS.EventFrame = Events
NS.SlashCommand = Slash
NS.EnsureUI = EnsureUI

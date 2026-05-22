-- === CONFIGURATION ===
setDefaultTab("Main")
UI.Separator()

-- Creature outfit ID mappings
local a = {
    ["dog"] = 32,
    ["dragon"] = 34,
    ["rat"] = 21,
    ["troll"] = 15,
    ["spider"] = 30,
    ["bug"] = 45,
    ["ghost"] = 48,
    ["ghoul"] = 18,
}

-- === STATE VARIABLES ===
local g                    -- Verification position
local orbInProgress = false
local verificationInProgress = false

-- === UTILITY FUNCTIONS ===
function getChildByText(text, parent)
    parent = parent or g_ui.getRootWidget()
    for _, child in ipairs(parent:getChildren()) do
        if child:getText():lower() == text:lower() then
            return child
        else
            local result = getChildByText(text, child)
            if result then return result end
        end
    end
end

function postostring(pos)
    return pos.x .. " " .. pos.y .. " " .. pos.z
end

-- === VERIFICATION HANDLER ===
local function handleVerification()
    verificationInProgress = true
    local window = getChildByText("Bot Verification")
    if not window then 
        verificationInProgress = false
        return 
    end

    local creatureWidget = window:getChildById("creature")
    local outfitId = creatureWidget:getOutfit().type
    local response = table.find(a, outfitId)

    if not response then
        playAlarm()
        modules.game_textmessage.displayPrivateMessage("Creature not found in list, ID: " .. tostring(outfitId))

        schedule(150, function()
            local timestamp = modules.corelib.os.date("%Y-%m-%d %H-%M-%S")
            modules.corelib.g_app.doScreenshot("botVerification " .. timestamp .. " ID-" .. tostring(outfitId) .. ".png")
        end)

        schedule(1000, function()
            window:getChildById("cancelButton"):onClick()
            schedule(800, function() handleVerification() end)
        end)

        verificationInProgress = false
        return true
    end

    window:getChildById("textEdit"):setText(response)
    window:getChildById("sendButton"):onClick()
    CaveBot.setOn(true)
    TargetBot.setOn(true)
    g = nil
    verificationInProgress = false
    return true
end

-- === VERIFICATION MOVEMENT MACRO ===
local verificationWalker = macro(150, function(macro)
    if not g then return end
    if postostring(player:getPosition()) == postostring(g) then
        schedule(1500, function()
            if not handleVerification() then
                CaveBot.setOn(true)
                TargetBot.setOn(true)
            end
        end)
        macro.retries = 0
        macro.setOn(false)
        return
    end

    TargetBot.setOn(not autoWalk(g, 20, { ignoreNonPathable = true, precision = 0 }))
    macro.retries = macro.retries + 1

    if macro.retries > 100 then
        macro.retries = 0
        CaveBot.setOn(true)
        TargetBot.setOn(true)
        macro.setOn(false)
        g = nil
    end
end)
verificationWalker.setOn(false)
verificationWalker.retries = 0

-- === TRIGGER FOR EFFECTS / ORBS ===
local mainToggle = macro(10000, "Auto-Orbs CaveBot", function() end)

onAddThing(function(pos, thing)
    if mainToggle:isOff() or pos:getPosition().z ~= player:getPosition().z then return end

    -- 🟡 Orb Detected
    if thing:isItem() and thing:getId() == 10840 then
        orbInProgress = true
        CaveBot.setOff()
        TargetBot.setOff()

        for i = 0, 4 do
            schedule(i * 300, function()
                autoWalk(pos:getPosition(), 20, { ignoreNonPathable = true, precision = 1 })
            end)
        end

        schedule(3000, function()
            orbInProgress = false
            if not verificationInProgress then
                CaveBot.setOn(true)
                TargetBot.setOn(true)
            else
                -- Failsafe recovery
                schedule(5000, function()
                    if not CaveBot.isOn() then CaveBot.setOn(true) end
                    if not TargetBot.isOn() then TargetBot.setOn(true) end
                end)
            end
        end)
    end

    -- 🧪 Verification Trigger Detected
    if thing:isEffect() and thing:getId() == 210 then
        g = pos:getPosition()
        CaveBot.setOff()
        TargetBot.setOff()
        verificationWalker.setOn(true)
    end
end)

-- === WATCHDOG MACRO ===
macro(3000, "CaveBot Watchdog", function()
    if not orbInProgress and not verificationInProgress then
        if not CaveBot.isOn() then
            CaveBot.setOn(true)
            print("[Watchdog] CaveBot re-enabled.")
        end
        if not TargetBot.isOn() then
            TargetBot.setOn(true)
            print("[Watchdog] TargetBot re-enabled.")
        end
    end
end)
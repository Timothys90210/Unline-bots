-- === CONFIGURATION ===
setDefaultTab("Main")
UI.Separator()

-- Portal item ID mappings
local PORTALS = {
    [11553] = "Halloween Battlegrounds",
    [47087] = "Treasure Room"
}

-- === STATE VARIABLES ===
local portalInProgress = false
local currentPortalPos = nil

-- === UTILITY FUNCTIONS ===
function getChildByText(text, parent)
    parent = parent or g_ui.getRootWidget()
    for _, child in ipairs(parent:getChildren()) do
        if child:getText():lower():find(text:lower()) then
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

-- === PORTAL PROMPT HANDLER ===
local function handlePortalPrompt()
    -- Look for the confirmation window with "Yes" button
    local yesButton = getChildByText("Yes")

    if yesButton then
        yesButton:onClick()
        print("[Portal] Entered portal successfully!")
        schedule(2000, function()
            portalInProgress = false
            currentPortalPos = nil
        end)
        return true
    end

    return false
end

-- === PORTAL PROMPT WATCHER ===
macro(200, "Portal Prompt Watcher", function()
    if portalInProgress then
        handlePortalPrompt()
    end
end)

-- === MAIN PORTAL DETECTION ===
local mainToggle = macro(10000, function() end)

onAddThing(function(pos, thing)
    if mainToggle:isOff() then return end
    if pos:getPosition().z ~= player:getPosition().z then return end
    if portalInProgress then return end

    -- Check if it's a portal we care about
    if thing:isItem() and PORTALS[thing:getId()] then
        local portalName = PORTALS[thing:getId()]
        local portalPos = pos:getPosition()

        print("[Portal] Detected " .. portalName .. " at " .. postostring(portalPos))

        portalInProgress = true
        currentPortalPos = portalPos

        -- Stop bots to avoid interference
        CaveBot.setOff()
        TargetBot.setOff()

        -- Walk to portal multiple times to ensure we reach it
        for i = 0, 5 do
            schedule(i * 300, function()
                if portalInProgress then
                    autoWalk(portalPos, 20, { ignoreNonPathable = true, precision = 0 })
                end
            end)
        end

        -- After reaching portal, wait for prompt and handle it
        schedule(2000, function()
            if portalInProgress then
                -- Try to click Yes if prompt appeared
                if not handlePortalPrompt() then
                    -- If no prompt found, retry walking
                    schedule(500, function()
                        if portalInProgress then
                            autoWalk(portalPos, 20, { ignoreNonPathable = true, precision = 0 })
                        end
                    end)
                end
            end
        end)

        -- Failsafe: Resume bots after timeout if we're still on the same floor
        schedule(8000, function()
            if portalInProgress then
                print("[Portal] Timeout - resuming bots")
                portalInProgress = false
                currentPortalPos = nil
            end

            -- Only resume if we're not in a portal (same Z level means we didn't enter)
            if not portalInProgress then
                CaveBot.setOn(true)
                TargetBot.setOn(true)
            end
        end)
    end
end)

-- === VISUAL INDICATOR ===
macro(500, function()
    if mainToggle:isOn() then
        mainToggle:setText("🎃 Halloween Events: ON")
    else
        mainToggle:setText("🎃 Halloween Events: OFF")
    end
end)

-- === WATCHDOG MACRO ===
macro(3000, "Portal Bot Watchdog", function()
    if not portalInProgress then
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

print("=== Portal Auto-Enter Script Loaded ===")
print("Portals configured:")
for id, name in pairs(PORTALS) do
    print("  - " .. name .. " (ID: " .. id .. ")")
end

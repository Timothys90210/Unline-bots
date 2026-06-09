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

-- Enhanced function to find modal dialogs
function findModalDialog()
    local root = g_ui.getRootWidget()
    for _, child in ipairs(root:getChildren()) do
        local className = child:getClassName()
        -- Look for common modal dialog class names
        if className and (className:lower():find("modal") or
                          className:lower():find("dialog") or
                          className:lower():find("messagebox") or
                          className:lower():find("window")) then
            return child
        end
    end
    return nil
end

-- Alternative button finder using class names
function findButton(text, parent)
    parent = parent or g_ui.getRootWidget()
    for _, child in ipairs(parent:getChildren()) do
        local className = child:getClassName()
        if className and className:lower():find("button") then
            if child:getText():lower():find(text:lower()) then
                return child
            end
        end
        local result = findButton(text, child)
        if result then return result end
    end
end

function postostring(pos)
    return pos.x .. " " .. pos.y .. " " .. pos.z
end

-- Debug function to list all visible UI widgets (for troubleshooting)
function debugUIWidgets(parent, depth)
    parent = parent or g_ui.getRootWidget()
    depth = depth or 0
    local indent = string.rep("  ", depth)

    for _, child in ipairs(parent:getChildren()) do
        if child:isVisible() then
            local text = child:getText() or ""
            local className = child:getClassName() or "unknown"
            print(indent .. "- " .. className .. (text ~= "" and (" [" .. text .. "]") or ""))

            if depth < 3 then  -- Limit recursion depth
                debugUIWidgets(child, depth + 1)
            end
        end
    end
end

-- === PORTAL PROMPT HANDLER ===
local promptCheckCount = 0
local hasDebuggedUI = false
local function handlePortalPrompt()
    -- Try multiple methods to find the Yes button
    local yesButton = nil

    -- Method 1: Search within modal dialog first
    local dialog = findModalDialog()
    if dialog then
        yesButton = getChildByText("Yes", dialog)
        if not yesButton then
            yesButton = findButton("Yes", dialog)
        end
        if promptCheckCount % 5 == 0 then  -- Only print every 5 checks to avoid spam
            print("[Portal] Found dialog window, searching for button...")
        end

        -- Debug UI structure once if button not found after several attempts
        if not yesButton and promptCheckCount == 15 and not hasDebuggedUI then
            print("[Portal] === DEBUG: UI Structure ===")
            debugUIWidgets(dialog, 0)
            print("[Portal] === END DEBUG ===")
            hasDebuggedUI = true
        end
    end

    -- Method 2: Global search as fallback
    if not yesButton then
        yesButton = getChildByText("Yes")
    end

    -- Method 3: Try finding by button class
    if not yesButton then
        yesButton = findButton("Yes")
    end

    if yesButton then
        print("[Portal] Found 'Yes' button! Attempting to click...")
        promptCheckCount = 0

        -- Try multiple click methods for maximum compatibility
        local success = false

        -- Method 1: Standard onClick
        if yesButton.onClick then
            pcall(function() yesButton:onClick() end)
            print("[Portal] Clicked using onClick()")
            success = true
        end

        -- Method 2: Direct click
        if yesButton.click then
            pcall(function() yesButton:click() end)
            print("[Portal] Clicked using click()")
            success = true
        end

        -- Method 3: Focus and simulate enter
        if yesButton.focus then
            pcall(function() yesButton:focus() end)
            print("[Portal] Focused button")
        end

        -- Method 4: Keyboard fallback - press Enter
        schedule(100, function()
            pcall(function()
                g_keyboard.pressKey("Return")
                schedule(50, function()
                    g_keyboard.releaseKey("Return")
                end)
            end)
            print("[Portal] Sent Enter key")
        end)

        -- Method 5: Try 'Y' key as well
        schedule(200, function()
            pcall(function()
                g_keyboard.pressKey("Y")
                schedule(50, function()
                    g_keyboard.releaseKey("Y")
                end)
            end)
            print("[Portal] Sent 'Y' key")
        end)

        if success then
            print("[Portal] Dialog accepted! Waiting for teleport...")
        end

        schedule(2000, function()
            portalInProgress = false
            currentPortalPos = nil
        end)

        return true
    else
        -- Debug: No button found (limit spam)
        if portalInProgress then
            promptCheckCount = promptCheckCount + 1
            if promptCheckCount % 10 == 1 then  -- Print every 10 checks (every 2 seconds)
                print("[Portal] Waiting for 'Yes' button to appear... (check #" .. promptCheckCount .. ")")
            end
        end
    end

    return false
end

-- === MAIN PORTAL SYSTEM TOGGLE ===
local mainToggle = macro(10000, "Auto-Portals", function() end)

-- === PORTAL PROMPT WATCHER ===
macro(200, function()
    if mainToggle:isOff() then return end
    if portalInProgress then
        handlePortalPrompt()
    end
end)

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
        promptCheckCount = 0
        hasDebuggedUI = false

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

        -- After reaching portal, wait 3000ms before handling prompt
        -- This ensures character stays on the portal tile
        schedule(2000, function()
            if portalInProgress then
                print("[Portal] Reached portal, waiting 3000ms to ensure stable position...")
                -- Wait 3 seconds to ensure character is stable on portal tile
                schedule(3000, function()
                    if portalInProgress then
                        print("[Portal] Position stable, looking for dialog prompt...")
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
            end
        end)

        -- Failsafe: Resume bots after timeout if we're still on the same floor
        -- Increased to 12000ms to account for 3000ms stability wait
        schedule(12000, function()
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

-- === WATCHDOG MACRO ===
macro(3000, function()
    if mainToggle:isOff() then return end
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

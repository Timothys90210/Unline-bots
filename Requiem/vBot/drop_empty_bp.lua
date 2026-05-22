setDefaultTab("Tools")

local pendingDrop = nil
local queue = {}
local lastScan = 0
local SCAN_INTERVAL = 15 * 60 * 1000 -- 15 minutes

onTextMessage(function(mode, text)
    if not pendingDrop then return end
    if not text:find("You see a backpack") then return end

    if text:find("It weighs 18.00 oz") then
        dropItem(pendingDrop)
    end
    pendingDrop = nil
end)

macro(1000, "Drop empty BP", function()
    if pendingDrop then return end

    -- queue empty: wait for cooldown then rescan
    if #queue == 0 then
        if now - lastScan < SCAN_INTERVAL then return end
        lastScan = now
        for _, container in pairs(getContainers()) do
            for __, item in ipairs(container:getItems()) do
                if item:getId() == 2854 then
                    table.insert(queue, item)
                end
            end
        end
        if #queue == 0 then return end
    end

    -- process next backpack in queue
    pendingDrop = table.remove(queue, 1)
    g_game.look(pendingDrop)
end)

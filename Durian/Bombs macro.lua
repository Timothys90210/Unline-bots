setDefaultTab("main")

local BACKPACK_SLOT = 3

UI.Separator()
UI.Label("Auto Bombs Config")

storage.msc = storage.msc or {
    enabled = false,
    targetCount = 5,
    minManaPct = 10,
    cooldown = 2,
    nextActionTime = 0,
    itemId1 = 7366,
    itemId2 = 7368,
    itemId3 = 3287,
    spell1 = "exevo pox morir",
    spell2 = "exevo mas morir",
    spell3 = "exevo morir",
    finishSpell = "adevo eversio",
    showUI = false,
    showCounts = true
}

local mscConfigWidgets = {}
local mscCountsWidgets = {}
local toggleLabel = UI.Label("Status: Disabled")
toggleLabel:setColor("#ff0000")

local showConfigButton, hideConfigButton
local showCountsButton, hideCountsButton

local function setMSCConfigUIVisible(visible)
    for _, w in ipairs(mscConfigWidgets) do
        w:setVisible(visible)
    end
end

local function setMSCCountsUIVisible(visible)
    for _, w in ipairs(mscCountsWidgets) do
        w:setVisible(visible)
    end
end

local function updateUIVisibility()
    local isEnabled = storage.msc.enabled
    if isEnabled then
        toggleLabel:setText("Status: Enabled")
        toggleLabel:setColor("#00ff00")
    else
        toggleLabel:setText("Status: Disabled")
        toggleLabel:setColor("#ff0000")
    end
    toggleLabel:setVisible(isEnabled)

    if isEnabled then
        local isConfigUIVisible = storage.msc.showUI
        setMSCConfigUIVisible(isConfigUIVisible)
        showConfigButton:setVisible(not isConfigUIVisible)
        hideConfigButton:setVisible(isConfigUIVisible)

        local isCountsUIVisible = storage.msc.showCounts
        setMSCCountsUIVisible(isCountsUIVisible)
        showCountsButton:setVisible(not isCountsUIVisible)
        hideCountsButton:setVisible(isCountsUIVisible)
    else
        setMSCConfigUIVisible(false)
        showConfigButton:setVisible(false)
        hideConfigButton:setVisible(false)

        setMSCCountsUIVisible(false)
        showCountsButton:setVisible(false)
        hideCountsButton:setVisible(false)
    end
end

local mscButton = UI.Button("Enable/Disable Auto Bombs", function()
    storage.msc.enabled = not storage.msc.enabled
    storage.msc.nextActionTime = 0 
    updateUIVisibility()
end)

showConfigButton = UI.Button("Show Config", function() 
    storage.msc.showUI = true
    updateUIVisibility()
end)

hideConfigButton = UI.Button("Hide Config", function() 
    storage.msc.showUI = false
    updateUIVisibility()
end)

showCountsButton = UI.Button("Show Live Counts", function()
    storage.msc.showCounts = true
    updateUIVisibility()
end)

hideCountsButton = UI.Button("Hide Live Counts", function()
    storage.msc.showCounts = false
    updateUIVisibility()
end)

local lbl1 = UI.Label("Target Count:"); table.insert(mscConfigWidgets, lbl1)
local edit1 = UI.TextEdit(storage.msc.targetCount or "5", function(widget, text) storage.msc.targetCount = tonumber(text) or 5 end); table.insert(mscConfigWidgets, edit1)
local lbl2 = UI.Label("Min. Mana %:"); table.insert(mscConfigWidgets, lbl2)
local edit2 = UI.TextEdit(storage.msc.minManaPct or "10", function(widget, text) storage.msc.minManaPct = tonumber(text) or 10 end); table.insert(mscConfigWidgets, edit2)
local lblCooldown = UI.Label("Action Cooldown (s):"); table.insert(mscConfigWidgets, lblCooldown)
local editCooldown = UI.TextEdit(storage.msc.cooldown or "2", function(widget, text) storage.msc.cooldown = tonumber(text) or 2 end); table.insert(mscConfigWidgets, editCooldown)
local lbl3 = UI.Label("Spell 1 / ItemID:"); table.insert(mscConfigWidgets, lbl3)
local edit3a = UI.TextEdit(storage.msc.spell1, function(widget, text) storage.msc.spell1 = text end); table.insert(mscConfigWidgets, edit3a)
local edit3b = UI.TextEdit(storage.msc.itemId1, function(widget, text) storage.msc.itemId1 = tonumber(text) or 7366 end); table.insert(mscConfigWidgets, edit3b)
local lbl4 = UI.Label("Spell 2 / ItemID:"); table.insert(mscConfigWidgets, lbl4)
local edit4a = UI.TextEdit(storage.msc.spell2, function(widget, text) storage.msc.spell2 = text end); table.insert(mscConfigWidgets, edit4a)
local edit4b = UI.TextEdit(storage.msc.itemId2, function(widget, text) storage.msc.itemId2 = tonumber(text) or 7368 end); table.insert(mscConfigWidgets, edit4b)
local lbl5 = UI.Label("Spell 3 / ItemID:"); table.insert(mscConfigWidgets, lbl5)
local edit5a = UI.TextEdit(storage.msc.spell3, function(widget, text) storage.msc.spell3 = text end); table.insert(mscConfigWidgets, edit5a)
local edit5b = UI.TextEdit(storage.msc.itemId3, function(widget, text) storage.msc.itemId3 = tonumber(text) or 3287 end); table.insert(mscConfigWidgets, edit5b)
local lbl6 = UI.Label("Finisher Spell:"); table.insert(mscConfigWidgets, lbl6)
local edit6 = UI.TextEdit(storage.msc.finishSpell, function(widget, text) storage.msc.finishSpell = text end); table.insert(mscConfigWidgets, edit6)
local configSeparator = UI.Separator(); table.insert(mscConfigWidgets, configSeparator)

local lbl7 = UI.Label("--- Live Counts ---"); lbl7:setColor("#90ee90"); table.insert(mscCountsWidgets, lbl7)
local countLabel1 = UI.Label("Item1: 0 / " .. storage.msc.targetCount); table.insert(mscCountsWidgets, countLabel1)
local countLabel2 = UI.Label("Item2: 0 / " .. storage.msc.targetCount); table.insert(mscCountsWidgets, countLabel2)
local countLabel3 = UI.Label("Item3: 0 / " .. storage.msc.targetCount); table.insert(mscCountsWidgets, countLabel3)
local actionLabel = UI.Label("Action: Idle"); table.insert(mscCountsWidgets, actionLabel)
local countsSeparator = UI.Separator(); table.insert(mscCountsWidgets, countsSeparator)

local function countItem(targetId)
    local total = 0
    local targetIdNum = tonumber(targetId)
    if not targetIdNum then return 0 end
    local backpackItem = getSlot(BACKPACK_SLOT)
    if not (backpackItem and backpackItem.getId) then return 0 end
    local backpackId = backpackItem:getId()
    if not backpackId then return 0 end
    local backpackContainer = getContainerByItem(backpackId)
    if not (backpackContainer and backpackContainer.getItems) then return 0 end
    for _, item in ipairs(backpackContainer:getItems()) do
        if item and item.getId then
            local itemIdNum = tonumber(item:getId())
            if itemIdNum and itemIdNum == targetIdNum then
                local itemCount = (item.getCount and tonumber(item:getCount())) or item.count or 1
                total = total + itemCount
            end
        end
    end
    return total
end

macro(1000, function()
    if not storage.msc.enabled then
        actionLabel:setText("Action: Disabled")
        return
    end
    if os.time() < (storage.msc.nextActionTime or 0) then
        actionLabel:setText("Action: Cooldown")
        return
    end
    if manapercent() < (storage.msc.minManaPct or 10) then
        actionLabel:setText("Action: Low Mana")
        return
    end
    local c1 = countItem(storage.msc.itemId1)
    local c2 = countItem(storage.msc.itemId2)
    local c3 = countItem(storage.msc.itemId3)
    local target = storage.msc.targetCount or 5
    countLabel1:setText(string.format("Item1: %d / %d", c1, target))
    countLabel2:setText(string.format("Item2: %d / %d", c2, target))
    countLabel3:setText(string.format("Item3: %d / %d", c3, target))
    local function performAction(spell, actionText, currentCount)
        say(spell)
        actionLabel:setText(string.format("Action: %s (Count: %d)", actionText, currentCount))
        storage.msc.nextActionTime = os.time() + (storage.msc.cooldown or 2)
    end
    if c1 >= target and c2 >= target and c3 >= target then
        performAction(storage.msc.finishSpell, "Casting Finisher", (c1+c2+c3))
        return
    end
    if c1 < target then
        performAction(storage.msc.spell1, "Building Item1", c1)
        return
    end
    if c2 < target then
        performAction(storage.msc.spell2, "Building Item2", c2)
        return
    end
    if c3 < target then
        performAction(storage.msc.spell3, "Building Item3", c3)
        return
    end
    actionLabel:setText("Action: Idle")
end)

updateUIVisibility()


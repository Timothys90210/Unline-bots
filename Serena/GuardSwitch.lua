if GuardSwitchLoaded then return end
GuardSwitchLoaded = true

setDefaultTab("Tools")
-- Guard Switch
-- Equips shield + training weapon at trainers, restores main weapon when they leave

local TRAINER_RANGE = 10

local trainerDetected = false
local lastSpellCast   = 0
local SPELL_INTERVAL  = 4  -- seconds

-- Persist item IDs across sessions
storage.guardSwitchMainWeapon  = storage.guardSwitchMainWeapon  or 0
storage.guardSwitchTrainWeapon = storage.guardSwitchTrainWeapon or 0
storage.guardSwitchShield      = storage.guardSwitchShield      or 0
storage.guardSwitchEnabled     = storage.guardSwitchEnabled     or false

-- Item slot UI
local ui = setupUI([[
Panel
  height: 136

  BotItem
    id: mainWeapon
    size: 32 32
    anchors.top: parent.top
    anchors.right: parent.right
    margin-top: 1

  Label
    anchors.verticalCenter: mainWeapon.verticalCenter
    anchors.left: parent.left
    anchors.right: mainWeapon.left
    margin-right: 5
    text: Main weapon:
    font: verdana-11px-rounded

  BotItem
    id: trainWeapon
    size: 32 32
    anchors.top: mainWeapon.bottom
    anchors.right: parent.right
    margin-top: 6

  Label
    anchors.verticalCenter: trainWeapon.verticalCenter
    anchors.left: parent.left
    anchors.right: trainWeapon.left
    margin-right: 5
    text: Training weapon:
    font: verdana-11px-rounded

  BotItem
    id: shield
    size: 32 32
    anchors.top: trainWeapon.bottom
    anchors.right: parent.right
    margin-top: 6

  Label
    anchors.verticalCenter: shield.verticalCenter
    anchors.left: parent.left
    anchors.right: shield.left
    margin-right: 5
    text: Shield:
    font: verdana-11px-rounded

  CheckBox
    id: enableCheck
    text: Enable Guard Switch
    anchors.top: shield.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 20
    margin-top: 8
]])

ui.mainWeapon:setItemId(storage.guardSwitchMainWeapon)
ui.trainWeapon:setItemId(storage.guardSwitchTrainWeapon)
ui.shield:setItemId(storage.guardSwitchShield)
ui.enableCheck:setChecked(storage.guardSwitchEnabled)

ui.mainWeapon.onItemChange  = function(w) storage.guardSwitchMainWeapon  = w:getItemId() end
ui.trainWeapon.onItemChange = function(w) storage.guardSwitchTrainWeapon = w:getItemId() end
ui.shield.onItemChange      = function(w) storage.guardSwitchShield      = w:getItemId() end
ui.enableCheck.onCheckChange = function(w, checked) storage.guardSwitchEnabled = checked end

local function hasTrainerNearby(range)
    for _, spec in pairs(getSpectators()) do
        if spec:isMonster() and (g_game.getClientVersion() < 960 or spec:getType() < 3) then
            local name = spec:getName()
            if name and name:lower():find("trainer", 1, true)
               and distanceFromPlayer(spec:getPosition()) <= range then
                return true
            end
        end
    end
    return false
end

local function moveToContainer(item)
    if not item then return end
    for _, container in pairs(g_game.getContainers()) do
        if not containerIsFull(container) then
            g_game.move(item, container:getSlotPosition(container:getItemsCount()), item:getCount())
            return
        end
    end
end

local guardSwitch = macro(2000, function()
    if not player then return end
    if not ui.enableCheck:isChecked() then return end

    local hasTrainer = hasTrainerNearby(TRAINER_RANGE)

    if not hasTrainer then
        if trainerDetected then
            trainerDetected = false
            local right = getSlot(5)
            local left  = getSlot(6)
            if right then moveToContainer(right) end
            if left  then moveToContainer(left)  end
            local mainId = ui.mainWeapon:getItemId()
            if mainId and mainId > 0 then
                local function tryEquipMain()
                    local r = getSlot(5)
                    local l = getSlot(6)
                    if r then moveToContainer(r) end
                    if l then moveToContainer(l) end
                    if r or l then
                        schedule(1000, tryEquipMain)
                    else
                        g_game.equipItemId(mainId)
                    end
                end
                schedule(1000, tryEquipMain)
            end
            modules.game_textmessage.displayGameMessage("[GuardSwitch] No trainer nearby — weapons restored")
        end
        return
    end

    if not trainerDetected then
        trainerDetected = true
        modules.game_textmessage.displayGameMessage("[GuardSwitch] Trainer detected — equipping shield")

        local right    = getSlot(5)
        local left     = getSlot(6)
        if right then moveToContainer(right) end
        if left  then moveToContainer(left)  end

        local trainId  = ui.trainWeapon:getItemId()
        local shieldId = ui.shield:getItemId()
        schedule(1000, function()
            if trainId and trainId > 0 then g_game.equipItemId(trainId) end
            if shieldId and shieldId > 0 then g_game.equipItemId(shieldId) end
        end)
    end

    local now = os.time()
    if now - lastSpellCast >= SPELL_INTERVAL then
        lastSpellCast = now
        g_game.talk("exeta res")
    end
end)

addIcon("GuardSwitch", { item = { id = 52735, count = 1 }, text = "Guard Switch" }, guardSwitch)

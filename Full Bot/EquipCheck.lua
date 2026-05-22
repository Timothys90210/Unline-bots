if EquipCheckLoaded then return end
EquipCheckLoaded = true

setDefaultTab("Tools")
-- Equip Check
-- Ensures configured gear is equipped whenever stamina is above 41h 50m

local STAMINA_MIN = 41 * 60 + 50  -- 2510 minutes

storage.equipCheckHelmet  = storage.equipCheckHelmet  or 0
storage.equipCheckArmor   = storage.equipCheckArmor   or 0
storage.equipCheckWeapon  = storage.equipCheckWeapon  or 0
storage.equipCheckShield  = storage.equipCheckShield  or 0
storage.equipCheckDoll    = storage.equipCheckDoll    or 0
local ui = setupUI([[
Panel
  height: 185

  BotItem
    id: helmet
    size: 32 32
    anchors.top: parent.top
    anchors.right: parent.right
    margin-top: 1

  Label
    anchors.verticalCenter: helmet.verticalCenter
    anchors.left: parent.left
    anchors.right: helmet.left
    margin-right: 5
    text: Helmet:
    font: verdana-11px-rounded

  BotItem
    id: armor
    size: 32 32
    anchors.top: helmet.bottom
    anchors.right: parent.right
    margin-top: 6

  Label
    anchors.verticalCenter: armor.verticalCenter
    anchors.left: parent.left
    anchors.right: armor.left
    margin-right: 5
    text: Armor:
    font: verdana-11px-rounded

  BotItem
    id: weapon
    size: 32 32
    anchors.top: armor.bottom
    anchors.right: parent.right
    margin-top: 6

  Label
    anchors.verticalCenter: weapon.verticalCenter
    anchors.left: parent.left
    anchors.right: weapon.left
    margin-right: 5
    text: Weapon:
    font: verdana-11px-rounded

  BotItem
    id: shield
    size: 32 32
    anchors.top: weapon.bottom
    anchors.right: parent.right
    margin-top: 6

  Label
    anchors.verticalCenter: shield.verticalCenter
    anchors.left: parent.left
    anchors.right: shield.left
    margin-right: 5
    text: Shield:
    font: verdana-11px-rounded

  BotItem
    id: doll
    size: 32 32
    anchors.top: shield.bottom
    anchors.right: parent.right
    margin-top: 6

  Label
    anchors.verticalCenter: doll.verticalCenter
    anchors.left: parent.left
    anchors.right: doll.left
    margin-right: 5
    text: Doll:
    font: verdana-11px-rounded

]])

ui.helmet:setItemId(storage.equipCheckHelmet)
ui.armor:setItemId(storage.equipCheckArmor)
ui.weapon:setItemId(storage.equipCheckWeapon)
ui.shield:setItemId(storage.equipCheckShield)
ui.doll:setItemId(storage.equipCheckDoll)

ui.helmet.onItemChange = function(w) storage.equipCheckHelmet = w:getItemId() end
ui.armor.onItemChange  = function(w) storage.equipCheckArmor  = w:getItemId() end
ui.weapon.onItemChange = function(w) storage.equipCheckWeapon = w:getItemId() end
ui.shield.onItemChange = function(w) storage.equipCheckShield = w:getItemId() end
ui.doll.onItemChange   = function(w) storage.equipCheckDoll   = w:getItemId() end

local slotConfig = {
    { storageKey = "equipCheckHelmet", slot = 1,  label = "Helmet" },
    { storageKey = "equipCheckArmor",  slot = 4,  label = "Armor"  },
    { storageKey = "equipCheckWeapon", slot = 6,  label = "Weapon" },
    { storageKey = "equipCheckShield", slot = 5,  label = "Shield" },
    { storageKey = "equipCheckDoll",   slot = 10, label = "Doll"   },
}

local function log(msg)
    modules.game_textmessage.displayGameMessage("[EquipCheck] " .. msg)
end

local function runEquipCheck()
    for _, entry in ipairs(slotConfig) do
        local configId = storage[entry.storageKey]
        if configId and configId > 0 then
            local equipped = getSlot(entry.slot)
            local equippedId = equipped and equipped:getId() or 0
            if equippedId == configId then
                log(entry.label .. ": found equipped")
            else
                log(entry.label .. ": equipping")
                g_game.equipItemId(configId)
            end
        end
    end
end

local staminaActive = false

macro(2000, "Equip Check", function()
    if not player then return end

    local stamina = player:getStamina()
    if stamina <= STAMINA_MIN then
        staminaActive = false
        return
    end

    if not staminaActive then
        staminaActive = true
        log("Stamina above 41h 50m — checks active")
        runEquipCheck()
        return
    end

    for _, entry in ipairs(slotConfig) do
        local configId = storage[entry.storageKey]
        if configId and configId > 0 then
            local equipped = getSlot(entry.slot)
            local equippedId = equipped and equipped:getId() or 0
            if equippedId ~= configId then
                log(entry.label .. ": equipping")
                g_game.equipItemId(configId)
            end
        end
    end
end)

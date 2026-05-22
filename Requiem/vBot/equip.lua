-- config
setDefaultTab("HP")
local scripts = 3 -- if you want more auto equip panels you can change 2 to higher value

-- Weapon item pickers (used to detect bow vs crossbow for conditional ammo equip)
if type(storage.weaponConfig) ~= "table" then
  storage.weaponConfig = {bow=0, crossbow=0}
end

local bowUi = setupUI([[
Panel
  height: 34

  UIWidget
    id: lbl
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    font: verdana-11px-rounded
    text: Bow
    width: 60
    text-align: left

  BotItem
    id: item
    anchors.left: lbl.right
    anchors.verticalCenter: parent.verticalCenter
]])
bowUi.item:setItemId(storage.weaponConfig.bow)
bowUi.item.onItemChange = function(widget)
  storage.weaponConfig.bow = widget:getItemId()
end

local crossbowUi = setupUI([[
Panel
  height: 34

  UIWidget
    id: lbl
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    font: verdana-11px-rounded
    text: Crossbow
    width: 60
    text-align: left

  BotItem
    id: item
    anchors.left: lbl.right
    anchors.verticalCenter: parent.verticalCenter
]])
crossbowUi.item:setItemId(storage.weaponConfig.crossbow)
crossbowUi.item.onItemChange = function(widget)
  storage.weaponConfig.crossbow = widget:getItemId()
end

-- script by kondrah, don't edit below unless you know what you are doing
UI.Label("Auto equip")
if type(storage.autoEquip) ~= "table" then
  storage.autoEquip = {}
end
for i=1,scripts do
  if not storage.autoEquip[i] then
    storage.autoEquip[i] = {on=false, title="Auto Equip", item1=i == 1 and 3052 or 0, item2=i == 1 and 3089 or 0, slot=i == 1 and 9 or 0}
  end
  -- panels 2 and 3 are weapon-controlled, always start as off
  if i == 2 or i == 3 then
    storage.autoEquip[i].on = false
  end
  UI.TwoItemsAndSlotPanel(storage.autoEquip[i], function(widget, newParams)
    storage.autoEquip[i] = newParams
  end)
end

-- Indicator panels for weapon-controlled ammo slots (read-only, controlled by macro)
local spectralUi = setupUI([[
Panel
  height: 19

  BotSwitch
    id: switch
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    !text: tr('Spectral Bolts')
]])
spectralUi.switch.onClick = function() end

local diamondUi = setupUI([[
Panel
  height: 19

  BotSwitch
    id: switch
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    !text: tr('Diamond Arrows')
]])
diamondUi.switch.onClick = function() end

local lastWeaponId = -1

macro(250, function()
  local weaponItem = getLeft()
  local bowId = storage.weaponConfig.bow
  local crossbowId = storage.weaponConfig.crossbow
  local weaponCheckActive = (bowId or 0) > 0 and (crossbowId or 0) > 0
  local weaponId = weaponItem and weaponItem:getId() or 0

  if weaponCheckActive and weaponId ~= lastWeaponId then
    lastWeaponId = weaponId
    spectralUi.switch:setOn(weaponId == crossbowId)
    diamondUi.switch:setOn(weaponId == bowId)
  end

  local containers = g_game.getContainers()
  for index, autoEquip in ipairs(storage.autoEquip) do
    local shouldRun = autoEquip.on

    -- When both weapon IDs are configured, override panels 2 and 3 based on equipped weapon:
    --   Panel 2 (spectral bolts)  -> active only when crossbow is in weapon slot
    --   Panel 3 (diamond arrows)  -> active only when bow is in weapon slot
    if weaponCheckActive then
      if index == 2 then
        shouldRun = weaponId == crossbowId
      elseif index == 3 then
        shouldRun = weaponId == bowId
      end
    end

    if shouldRun then
      local slotItem = getSlot(autoEquip.slot)
      if not slotItem or (slotItem:getId() ~= autoEquip.item1 and slotItem:getId() ~= autoEquip.item2) then
        for _, container in pairs(containers) do
          for __, item in ipairs(container:getItems()) do
            if item:getId() == autoEquip.item1 or item:getId() == autoEquip.item2 then
              g_game.move(item, {x=65535, y=autoEquip.slot, z=0}, item:getCount())
              delay(1000) -- don't call it too often
              return
            end
          end
        end
      end
    end
  end
end)

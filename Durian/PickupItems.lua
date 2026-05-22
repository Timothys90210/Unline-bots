--[[
  PickupItems.lua
  Picks up all moveable items from the tile the character is standing on
  and moves them into the first open backpack.
]]

local panelName = "pickupItems"

local ui = setupUI([[
Panel
  height: 19

  Label
    id: label
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: Pickup Items
    width: 80

  Button
    id: pickupBtn
    anchors.top: parent.top
    anchors.left: prev.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 5
    width: 20
    height: 17
    text: P
    tooltip: Pickup now
]])

-- Check if container has space
local function hasSpace(container)
  return container:getCapacity() > #container:getItems()
end

-- Find a backpack with available space
local function getBackpackWithSpace()
  local containers = g_game.getContainers()
  for _, container in pairs(containers) do
    if hasSpace(container) then
      return container
    end
  end
  return nil
end

-- Pick up all items from the player's current tile
local function pickupItemsFromTile()
  local playerPos = player:getPosition()
  local tile = g_map.getTile(playerPos)

  if not tile then
    warn("[PickupItems] No tile found at player position")
    return
  end

  local items = tile:getItems()
  if not items or #items == 0 then
    return
  end

  local backpack = getBackpackWithSpace()
  if not backpack then
    warn("[PickupItems] No open backpack with space found")
    return
  end

  -- Collect moveable items first
  local toPickup = {}
  for _, item in ipairs(items) do
    if item:isItem() and not item:isNotMoveable() then
      table.insert(toPickup, item)
    end
  end

  -- Schedule rapid pickups (20ms apart)
  for i, item in ipairs(toPickup) do
    schedule((i - 1) * 20, function()
      local bp = getBackpackWithSpace()
      if not bp then return end
      local destSlot = bp:getSlotPosition(bp:getItemsCount())
      g_game.move(item, destSlot, item:getCount())
    end)
  end
end

-- Manual pickup button click
ui.pickupBtn.onClick = function()
  pickupItemsFromTile()
end

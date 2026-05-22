setDefaultTab("Cave")

--[EquipItems]
-- Tibia 10+
--> equipItems() <--

UI.Label("Items To Equip:"):setColor("green")

if type(storage.itemsToEquip) ~= "table" then
  storage.itemsToEquip = {3081, 3006}
end

local itemsContainer = UI.Container(function(widget, items)
  storage.itemsToEquip = items
end, true)
itemsContainer:setHeight(35)
itemsContainer:setItems(storage.itemsToEquip)

local getItemsToEquipIds = function()
  local ids = {}
  for i, item in ipairs(storage.itemsToEquip) do
    table.insert(ids, item.id)
  end
  return ids
end

local function equipedItemsIds()
  local equipedIds = { }
  local items = {getNeck(), getHead(), getLeft(), getRight(), getBody(), getLeg(), getFeet(), getFinger(), getAmmo() }
  for i, item in pairs(items) do
    if item then
      table.insert(equipedIds, item:getId())
    end
  end
  return equipedIds
end

function equipItems()
  --Made By VivoDibra#1182
  local delay = 0
  for _, id in ipairs(getItemsToEquipIds()) do
    schedule(delay, function()
      if not table.find(equipedItemsIds(), id) then
        g_game.equipItemId(id)
      end
    end)
    delay = delay + 500
  end
end

UI.Separator()
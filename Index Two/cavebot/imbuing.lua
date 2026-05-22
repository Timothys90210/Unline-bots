-- imbuing window should be handled separately
-- reequiping should be handled separately (ie. equipment manager)

-- ── CaveBot Extension ────────────────────────────────────────────────────────
CaveBot.Extensions.Imbuing = {}

local SHRINES = {25060, 25061, 25182, 25183}

-- Inventory slot numbers mapped to each equipment piece
-- Head=1, Armor=4, Right(weapon)=5, Left(shield)=6, Ring(doll)=9
local EQUIP_SLOTS = {
  helmet = 1,
  armor  = 4,
  weapon = 6,  -- left hand
  shield = 5,  -- right hand
  doll   = 10, -- ammo slot
}

local currentIndex    = 1
local shrine          = nil
local item            = nil
local currentId       = 0
local currentImbuIds  = {0, 0, 0}
local currentSlot     = nil  -- slot the current item was equipped in
local triedToTakeOff  = false
local destination     = nil
local imbuementState  = "init"
local imbuedItems     = {}   -- {id, slot} per imbued item, for re-equip
local itemsToImbue    = {}   -- {id, slot, imbuIds} built at start of run
local reequipIndex    = 0    -- position in imbuedItems during reequipping state

local function reset()
  EquipManager.setOn()
  ImbuingActive  = false
  shrine         = nil
  currentIndex   = 1
  item           = nil
  currentId      = 0
  currentImbuIds = {0, 0, 0}
  currentSlot    = nil
  triedToTakeOff = false
  destination    = nil
  imbuementState = "init"
  imbuedItems    = {}
  itemsToImbue   = {}
  reequipIndex   = 0
  -- EquipCheck runs after a short delay as a backup for any slots imbuing
  -- failed to re-equip correctly
  if EquipCheck then
    schedule(1500, function() EquipCheck.run() end)
  end
end

local function getImbuementWindow()
  local rootWidget = g_ui.getRootWidget()
  if not rootWidget then return nil end
  local possibleIds = {
    'ImbuementWindow', 'imbuementWindow', 'imbuingWindow',
    'shrineWindow', 'ShrineWindow', 'itemImbuementWindow'
  }
  for _, id in ipairs(possibleIds) do
    local window = rootWidget:recursiveGetChildById(id)
    if window then return window end
  end
  return nil
end

local function findCloseButton(imbuementWindow)
  if not imbuementWindow then return nil end
  local knownButtonIds = {
    'widget1550', 'closeButton', 'buttonClose', 'cancelButton',
    'buttonCancel', 'exitButton', 'buttonExit'
  }
  for _, buttonId in ipairs(knownButtonIds) do
    local button = imbuementWindow:recursiveGetChildById(buttonId)
    if button and button.onClick then return button end
  end
  local function findButtonByText(widget, depth)
    depth = depth or 0
    if depth > 6 then return nil end
    local children = widget:getChildren()
    if not children then return nil end
    for _, child in ipairs(children) do
      local className = ""
      pcall(function() className = child:getClassName() or "" end)
      if className:lower():find("button") or child.onClick then
        local buttonText = ""
        pcall(function() buttonText = child:getText() or "" end)
        if buttonText:lower():find("close") or buttonText:lower():find("cancel") or
           buttonText:lower():find("exit") or buttonText == "X" then
          return child
        end
      end
      local result = findButtonByText(child, depth + 1)
      if result then return result end
    end
    return nil
  end
  return findButtonByText(imbuementWindow, 0)
end

local function closeInfoDialogs()
  local rootWidget = g_ui.getRootWidget()
  if not rootWidget then return end

  local function closeMessageBoxes(widget)
    pcall(function()
      if widget:getClassName() == "UIMessageBox" and widget:isVisible() then
        pcall(function() widget:hide() end)
        pcall(function() widget:destroy() end)
        delay(50)
      end
      for _, child in ipairs(widget:getChildren()) do
        closeMessageBoxes(child)
      end
    end)
  end

  closeMessageBoxes(rootWidget)
  delay(300)
end

-- Searches all configured equipment slots for an item with the given ID.
-- Used in non-'name' mode where slot info isn't pre-built.
local function findItemSlot(itemId)
  local lp = player or g_game.getLocalPlayer()
  if not lp then return nil end
  for _, slotNum in pairs(EQUIP_SLOTS) do
    local slotItem = lp:getInventoryItem(slotNum)
    if slotItem and slotItem:getId() == itemId then
      return slotNum
    end
  end
  return nil
end

CaveBot.Extensions.Imbuing.setup = function()
  CaveBot.registerAction("imbuing", "red", function(value, retries)
    local ids = {}
    local config = storage.imbuingConfig or {}

    EquipManager.setOff()
    ImbuingActive = true

    if value == 'name' then
      if #itemsToImbue == 0 and currentIndex == 1 then
        local lp = (player and player) or g_game.getLocalPlayer()
        for key, slotNum in pairs(EQUIP_SLOTS) do
          local imbuIds = config[key] or {0, 0, 0}
          local hasAny = (imbuIds[1] or 0) > 0 or (imbuIds[2] or 0) > 0 or (imbuIds[3] or 0) > 0
          if hasAny and lp then
            local equipped = lp:getInventoryItem(slotNum)
            if equipped then
              table.insert(itemsToImbue, {
                id     = equipped:getId(),
                slot   = slotNum,
                imbuIds = {imbuIds[1] or 0, imbuIds[2] or 0, imbuIds[3] or 0}
              })
            end
          end
        end
        if #itemsToImbue == 0 then
          warn("CaveBot[Imbuing] No items configured to imbue, check Tools tab config")
          reset()
          return false
        end
      end
      for _, entry in ipairs(itemsToImbue) do
        table.insert(ids, entry.id)
      end
    else
      local data = string.split(value, ",")
      if #data == 0 then
        warn("CaveBot[Imbuing] no items added, proceeding")
        reset()
        return false
      end
      for _, id in ipairs(data) do
        id = tonumber(id)
        if id and not table.find(ids, id) then
          table.insert(ids, id)
        end
      end
    end

    -- ── State: reequipping ── (checked before currentIndex guard so the guard
    -- cannot re-trigger it on every tick once we've entered this state)
    if imbuementState == "reequipping" then
      if reequipIndex == 0 then
        closeInfoDialogs()
        local win = getImbuementWindow()
        if win then
          local btn = findCloseButton(win)
          if btn then pcall(function() btn:onClick() end) end
        end
        reequipIndex = 1
        delay(600)
        return "retry"
      end

      if reequipIndex > #imbuedItems then
        warn("CaveBot[Imbuing] re-equip done — EquipCheck will verify slots")
        reset()
        return true
      end

      local entry = imbuedItems[reequipIndex]
      local found = findItem(entry.id)
      if found then
        warn("CaveBot[Imbuing] re-equipping " .. entry.id .. " to slot " .. entry.slot)
        g_game.move(found, {x=65535, y=entry.slot, z=0}, 1)
      else
        warn("CaveBot[Imbuing] item " .. entry.id .. " not in backpack, EquipCheck will handle")
      end
      reequipIndex = reequipIndex + 1
      delay(600)
      return "retry"
    end

    if currentIndex > #ids then
      warn("CaveBot[Imbuing] used shrine on all items, starting re-equip")
      imbuementState = "reequipping"
      reequipIndex   = 0
      return "retry"
    end

    -- ── State: init ──────────────────────────────────────────────────────────
    if imbuementState == "init" then
      shrine = nil
      for _, tile in ipairs(g_map.getTiles(posz())) do
        for _, tileItem in ipairs(tile:getItems()) do
          if table.find(SHRINES, tileItem:getId()) then
            shrine = tileItem
            break
          end
        end
        if shrine then break end
      end

      if not shrine then
        warn("CaveBot[Imbuing] shrine not found! proceeding")
        reset()
        return false
      end

      destination = shrine:getPosition()
      currentId   = ids[currentIndex]

      -- determine which slot this item occupies
      if value == 'name' then
        local entry = itemsToImbue[currentIndex]
        currentSlot    = entry and entry.slot or nil
        currentImbuIds = entry and entry.imbuIds or {0, 0, 0}
      else
        currentSlot    = findItemSlot(currentId)
        currentImbuIds = {0, 0, 0}
      end

      item = findItem(currentId)

      -- stale backpack detection: if the item is in BOTH the backpack and its
      -- configured slot, the backpack copy is leftover from a prior imbue cycle;
      -- nil it out so we take the unequip-from-slot path below
      if item and currentSlot then
        local lp = player or g_game.getLocalPlayer()
        local slotItem = lp and lp:getInventoryItem(currentSlot)
        if slotItem and slotItem:getId() == currentId then
          item = nil
        end
      end

      if not item then
        if triedToTakeOff then
          warn("CaveBot[Imbuing] item not found! skipping: " .. currentId)
          triedToTakeOff = false
          currentIndex   = currentIndex + 1
          imbuementState = "init"
          return "retry"
        end
        triedToTakeOff = true
        -- unequip from the known slot using move, not equipItemId
        -- (equipItemId routes by natural slot type and will miss non-natural placements)
        local lp = player or g_game.getLocalPlayer()
        if currentSlot and lp then
          local slotItem = lp:getInventoryItem(currentSlot)
          if slotItem and slotItem:getId() == currentId then
            local containers = g_game.getContainers()
            for _, c in pairs(containers) do
              if not c.lootContainer and c:getItemsCount() < c:getCapacity() then
                g_game.move(slotItem, c:getSlotPosition(c:getItemsCount()), 1)
                delay(1000)
                return "retry"
              end
            end
          end
        end
        -- fallback: no slot info or no open container
        g_game.equipItemId(currentId)
        delay(1000)
        return "retry"
      end

      triedToTakeOff = false
      imbuementState = "walking"
      return "retry"
    end

    -- ── State: walking ───────────────────────────────────────────────────────
    if imbuementState == "walking" then
      if not CaveBot.MatchPosition(destination, 1) then
        CaveBot.GoTo(destination, 1)
        delay(200)
        return "retry"
      end

      -- refresh item reference — backpack slots can shift if a spell created
      -- an item between init and now, leaving the stored reference stale
      item = findItem(currentId)
      if not item then
        warn("CaveBot[Imbuing] item " .. currentId .. " lost during walk, retrying init")
        imbuementState = "init"
        return "retry"
      end

      useWith(shrine, item)
      warn("CaveBot[Imbuing] Opening shrine for item: " .. currentId)
      delay(2000)
      imbuementState = "imbuing"
      return "retry"
    end

    -- ── State: imbuing ───────────────────────────────────────────────────────
    if imbuementState == "imbuing" then
      for slot = 1, 3 do
        g_game.clearImbuement(slot)
        delay(300)
      end

      for slot = 1, 3 do
        local imbuId = currentImbuIds[slot] or 0
        if imbuId > 0 then
          g_game.applyImbuement(slot, imbuId)
          delay(300)
          warn("CaveBot[Imbuing] Applied imbuement " .. imbuId .. " to slot " .. slot .. " on item " .. currentId)
        end
      end

      -- track by slot so dual-wield same-ID weapons are handled correctly
      if currentSlot then
        local tracked = false
        for _, e in ipairs(imbuedItems) do
          if e.slot == currentSlot then tracked = true; break end
        end
        if not tracked then
          table.insert(imbuedItems, {id=currentId, slot=currentSlot})
        end
      end

      currentIndex   = currentIndex + 1
      imbuementState = "init"
      delay(1000)
      return "retry"
    end

    return "retry"
  end)

  CaveBot.Editor.registerAction("imbuing", "imbuing", {
    value="name",
    title="Auto Imbuing",
    description="Use 'name' to load from Tools tab config\nor enter item ids separated by comma",
  })
end

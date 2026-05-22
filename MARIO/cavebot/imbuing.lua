-- imbuing window should be handled separatly
-- reequiping should be handled separatly (ie. equipment manager)

CaveBot.Extensions.Imbuing = {}

local SHRINES = {25060, 25061, 25182, 25183}

-- Timing constants (in milliseconds)
local DELAYS = {
  DIALOG_HIDE = 50,
  DIALOG_CLOSE = 300,
  DIALOG_CLOSE_LONG = 500,
  WALKING = 200,
  WINDOW_WAIT = 500,
  EQUIP_ITEM = 500,
  UI_UPDATE = 1000,
  UNEQUIP_ITEM = 1000,
  ITEM_COMPLETE = 1000,
  BUTTON_CLICK = 1200,
  CLEAR_COMPLETE = 1500,
  SLOT_SELECT = 2000,
  SHRINE_OPEN = 2000,
  BETWEEN_IMBUEMENTS = 3000,
}

local currentIndex = 1
local shrine = nil
local item = nil
local currentId = 0
local triedToTakeOff = false
local destination = nil
local imbuementState = "init" -- States: init, walking, clearing, imbuing, next
local currentImbuementIndex = 1
local windowWaitRetries = 0
local MAX_WINDOW_WAIT = 10
local imbuedItemIds = {} -- Track all items that were imbued for reequipping

local function reequipAllItems()
  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: reequipAllItems() function called", 18)
  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: imbuedItemIds count = " .. #imbuedItemIds, 18)

  if #imbuedItemIds == 0 then
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: No items to reequip, returning early", 18)
    return
  end

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Reequipping all imbued items...", 18)

  for _, itemId in ipairs(imbuedItemIds) do
    local item = findItem(itemId)
    if item then
      g_game.equipItemId(itemId)
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Reequipped item: " .. itemId, 18)
      delay(DELAYS.EQUIP_ITEM)
    else
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Could not find item to reequip: " .. itemId, 18)
    end
  end

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Finished reequipping all items", 18)
  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: About to call closeInfoDialog()", 18)
  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: Returned from closeInfoDialog()", 18)
end

local function reset()
  EquipManager.setOn()
  shrine = nil
  currentIndex = 1
  item = nil
  currentId = 0
  triedToTakeOff = false
  destination = nil
  imbuementState = "init"
  currentImbuementIndex = 1
  windowWaitRetries = 0
  imbuedItemIds = {}
end

local function getImbuementWindow()
  local rootWidget = g_ui.getRootWidget()
  if not rootWidget then
    return nil
  end

  -- Try multiple possible window IDs
  local possibleIds = {
    'ImbuementWindow',
    'imbuementWindow',
    'imbuingWindow',
    'shrineWindow',
    'ShrineWindow',
    'itemImbuementWindow'
  }

  for _, id in ipairs(possibleIds) do
    local window = rootWidget:recursiveGetChildById(id)
    if window then
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Found window: " .. id, 18)
      return window
    end
  end

  -- Debug: List all open windows
  local function listWindows(widget, depth)
    depth = depth or 0
    if depth > 3 then return end

    for _, child in ipairs(widget:getChildren()) do
      local id = child:getId()
      if id and id ~= "" and id:lower():find("window") then
        modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: Found window: " .. id, 18)
      end
      listWindows(child, depth + 1)
    end
  end

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: Listing all windows...", 18)
  listWindows(rootWidget)

  return nil
end

-- Dynamically find the imbuement slots panel by looking for a container with item slot children
local function findImbuementSlotsPanel(imbuementWindow)
  if not imbuementWindow then return nil end

  -- Known panel IDs to try first (for backwards compatibility)
  local knownPanelIds = {'widget1510', 'imbuementSlotsPanel', 'slotsPanel', 'itemSlotsPanel'}

  for _, panelId in ipairs(knownPanelIds) do
    local panel = imbuementWindow:recursiveGetChildById(panelId)
    if panel then
      local children = panel:getChildren()
      if children and #children >= 1 then
        modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Found slots panel by ID: " .. panelId, 18)
        return panel
      end
    end
  end

  -- Dynamic discovery: search for a panel containing item slots
  local function findPanelWithSlots(widget, depth)
    depth = depth or 0
    if depth > 5 then return nil end

    local children = widget:getChildren()
    if not children then return nil end

    -- Check if this widget has children that look like imbuement slots
    local slotCount = 0
    for _, child in ipairs(children) do
      local childId = child:getId() or ""
      local className = ""
      pcall(function() className = child:getClassName() or "" end)

      -- Look for item slots or imbuement-related widgets
      if childId:lower():find("slot") or
         childId:lower():find("item") or
         childId:lower():find("imbuement") or
         className:lower():find("item") then
        slotCount = slotCount + 1
      end
    end

    -- If we found 1-3 slot-like children, this is likely our panel
    if slotCount >= 1 and slotCount <= 4 then
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Found slots panel dynamically with " .. slotCount .. " slots", 18)
      return widget
    end

    -- Recurse into children
    for _, child in ipairs(children) do
      local result = findPanelWithSlots(child, depth + 1)
      if result then return result end
    end

    return nil
  end

  local panel = findPanelWithSlots(imbuementWindow, 0)
  if panel then
    return panel
  end

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] WARNING: Could not find imbuement slots panel", 18)
  return nil
end

-- Dynamically find the close button
local function findCloseButton(imbuementWindow)
  if not imbuementWindow then return nil end

  -- Known close button IDs to try first
  local knownButtonIds = {
    'widget1550', 'closeButton', 'buttonClose', 'cancelButton',
    'buttonCancel', 'exitButton', 'buttonExit'
  }

  for _, buttonId in ipairs(knownButtonIds) do
    local button = imbuementWindow:recursiveGetChildById(buttonId)
    if button and button.onClick then
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Found close button by ID: " .. buttonId, 18)
      return button
    end
  end

  -- Dynamic discovery: search for a button with close-like text or at bottom of window
  local function findButtonByText(widget, depth)
    depth = depth or 0
    if depth > 6 then return nil end

    local children = widget:getChildren()
    if not children then return nil end

    for _, child in ipairs(children) do
      local className = ""
      pcall(function() className = child:getClassName() or "" end)

      -- Check if this is a button-like widget
      if className:lower():find("button") or child.onClick then
        -- Try to get the button text
        local buttonText = ""
        pcall(function() buttonText = child:getText() or "" end)

        -- Check for close-related text
        if buttonText:lower():find("close") or
           buttonText:lower():find("cancel") or
           buttonText:lower():find("exit") or
           buttonText == "X" then
          modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Found close button by text: " .. buttonText, 18)
          return child
        end
      end

      -- Recurse
      local result = findButtonByText(child, depth + 1)
      if result then return result end
    end

    return nil
  end

  local button = findButtonByText(imbuementWindow, 0)
  if button then
    return button
  end

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] WARNING: Could not find close button", 18)
  return nil
end

local function selectImbuementSlot(slotIndex)
  local imbuementWindow = getImbuementWindow()
  if not imbuementWindow then
    return false
  end

  -- The slots are shown at the top of the window as visual item slots
  -- Use dynamic panel finder to locate the slots container
  local panel = findImbuementSlotsPanel(imbuementWindow)
  if not panel then
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: Could not find imbuement slots panel", 18)
    return false
  end

  -- Get all children and look for clickable slot items
  local children = panel:getChildren()

  -- Map logical slot index (0, 1, 2) to actual child index
  -- Widget structure: Child 1=imbuementBaseItem, Child 2=imbuementSlot3, Child 3=imbuementSlot2
  local slotToChildMap = {
    [0] = 1,  -- First slot -> Child 1 (imbuementBaseItem)
    [1] = 3,  -- Second slot -> Child 3 (imbuementSlot2)
    [2] = 2   -- Third slot -> Child 2 (imbuementSlot3)
  }

  local childIndex = slotToChildMap[slotIndex]
  if children and childIndex and children[childIndex] then
    local slot = children[childIndex]
    if slot.onClick then
      pcall(function() slot:onClick() end)
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Selected slot " .. slotIndex .. " (child index " .. childIndex .. ")", 18)
      return true
    else
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Slot " .. slotIndex .. " has no onClick method", 18)
    end
  end

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: Could not find slot " .. slotIndex .. " in widget1510", 18)
  return false
end

local function closeInfoDialog()
  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: Closing message box dialogs", 18)

  local rootWidget = g_ui.getRootWidget()
  if not rootWidget then
    return
  end

  -- Find all UIMessageBox widgets and hide them directly
  local function findAndCloseMessageBoxes(widget)
    pcall(function()
      local className = widget:getClassName() or ""

      -- If this is a UIMessageBox, hide it directly
      if className == "UIMessageBox" and widget:isVisible() then
        local widgetId = widget:getId() or "unknown"
        modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: Found UIMessageBox: " .. widgetId, 18)

        -- Try to hide/destroy the message box
        pcall(function()
          widget:hide()
          modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: Hidden " .. widgetId, 18)
        end)

        pcall(function()
          widget:destroy()
          modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: Destroyed " .. widgetId, 18)
        end)

        delay(DELAYS.DIALOG_HIDE)
      end

      -- Recursively check children
      for _, child in ipairs(widget:getChildren()) do
        findAndCloseMessageBoxes(child)
      end
    end)
  end

  -- Find and close all message boxes
  findAndCloseMessageBoxes(rootWidget)
  delay(DELAYS.DIALOG_CLOSE)
end

local function clearImbuements(itemId)
  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Clearing imbuements on item: " .. itemId, 18)

  local imbuementWindow = getImbuementWindow()
  if not imbuementWindow then
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Warning: Imbuement window not found", 18)
    return false
  end

  -- Clear all slots (up to 3) by selecting each slot and clicking clear
  -- Slots are indexed 0, 1, 2
  local clearedCount = 0
  for slotIndex = 0, 2 do
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Clearing slot " .. slotIndex, 18)

    -- Select the slot first
    selectImbuementSlot(slotIndex)
    delay(DELAYS.SLOT_SELECT)

    -- Find and click clear button for this slot
    if not imbuementWindow then
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: imbuementWindow became nil during loop", 18)
      break
    end

    local clearButton = imbuementWindow:recursiveGetChildById('clearButton') or
                       imbuementWindow:recursiveGetChildById('buttonClear') or
                       imbuementWindow:recursiveGetChildById('removeButton') or
                       imbuementWindow:recursiveGetChildById('buttonRemove')

    if clearButton and clearButton.onClick then
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: clearButton found, calling onClick", 18)
      clearButton:onClick()
      clearedCount = clearedCount + 1
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Clicked clear for slot " .. slotIndex, 18)
      delay(DELAYS.BUTTON_CLICK)

      -- Close the "successfully cleared" dialog after each clear
      closeInfoDialog()
      delay(DELAYS.DIALOG_CLOSE_LONG)
    else
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] No clear button for slot " .. slotIndex, 18)
    end
  end

  if clearedCount > 0 then
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Cleared " .. clearedCount .. " slots", 18)
    return true
  end

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Warning: No slots cleared", 18)
  return false
end

local function selectImbuementType(imbueName)
  local imbuementWindow = getImbuementWindow()
  if not imbuementWindow then
    return false
  end

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Selecting imbuement: " .. imbueName, 18)

  -- Find the name combobox (this is the dropdown that shows the imbuement name)
  local nameComboBox = imbuementWindow:recursiveGetChildById('nameComboBox')
  if not nameComboBox then
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Warning: nameComboBox not found", 18)
    return false
  end

  -- Try to set the option using setCurrentOption
  if nameComboBox.setCurrentOption then
    nameComboBox:setCurrentOption(imbueName)
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Set nameComboBox to: " .. imbueName, 18)
    return true
  end

  -- Alternative: Try to find the option index
  if nameComboBox.setCurrentIndex and nameComboBox.getOptionsCount then
    local optionsCount = nameComboBox:getOptionsCount()
    for i = 0, optionsCount - 1 do
      local option = nameComboBox:getOption(i)
      if option and option.text and option.text:lower():find(imbueName:lower()) then
        nameComboBox:setCurrentIndex(i)
        modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Set nameComboBox index to: " .. i .. " (" .. imbueName .. ")", 18)
        return true
      end
    end
  end

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Warning: Could not set imbuement type", 18)
  return false
end

local function selectImbuementTier(tier)
  local imbuementWindow = getImbuementWindow()
  if not imbuementWindow then
    return false
  end

  tier = tier or "Intricate" -- Default to Intricate (capital I)

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Selecting tier: " .. tier, 18)

  -- Find the category combobox (this is the tier dropdown)
  local categoryComboBox = imbuementWindow:recursiveGetChildById('categoryComboBox')
  if not categoryComboBox then
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Warning: categoryComboBox not found", 18)
    return false
  end

  -- Try to set the option using setCurrentOption
  if categoryComboBox.setCurrentOption then
    categoryComboBox:setCurrentOption(tier)
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Set categoryComboBox to: " .. tier, 18)
    return true
  end

  -- Alternative: Try to find the option index
  if categoryComboBox.setCurrentIndex and categoryComboBox.getOptionsCount then
    local optionsCount = categoryComboBox:getOptionsCount()
    for i = 0, optionsCount - 1 do
      local option = categoryComboBox:getOption(i)
      if option and option.text and option.text:lower():find(tier:lower()) then
        categoryComboBox:setCurrentIndex(i)
        modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Set categoryComboBox index to: " .. i .. " (" .. tier .. ")", 18)
        return true
      end
    end
  end

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Warning: Could not set tier", 18)
  return false
end

local function applyImbuement(itemId, imbueName, slotIndex)
  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Applying imbuement: " .. imbueName .. " to item: " .. itemId, 18)

  local imbuementWindow = getImbuementWindow()
  if not imbuementWindow then
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Warning: Imbuement window not found", 18)
    return false
  end

  -- Step 1: Select the slot (if slotIndex provided)
  if slotIndex then
    if not selectImbuementSlot(slotIndex) then
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Warning: Could not select slot " .. slotIndex, 18)
    end
    delay(DELAYS.SLOT_SELECT)
  end

  -- Step 2: Select the imbuement type
  if not selectImbuementType(imbueName) then
    return false
  end

  -- Wait for UI to update
  delay(DELAYS.UI_UPDATE)

  -- Step 3: Select tier (Intricate)
  selectImbuementTier("Intricate")

  -- Wait for UI to update
  delay(DELAYS.UI_UPDATE)

  -- Step 4: Click apply button (in the "Success Rate" panel on the right)
  local possibleButtonIds = {
    'applyButton',
    'buttonApply',
    'imbuementApplyButton',
    'okButton',
    'buttonOk',
    'confirmButton'
  }

  local applyButton = nil
  for _, buttonId in ipairs(possibleButtonIds) do
    applyButton = imbuementWindow:recursiveGetChildById(buttonId)
    if applyButton then
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Found apply button: " .. buttonId, 18)
      break
    end
  end

  if applyButton and applyButton.onClick then
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: Clicking apply button", 18)
    applyButton:onClick()
    modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Clicked apply button for: " .. imbueName, 18)
    delay(DELAYS.BUTTON_CLICK)

    -- Close the "successfully imbued" dialog after applying
    closeInfoDialog()
    delay(DELAYS.DIALOG_CLOSE_LONG)

    return true
  end

  modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Warning: Apply button not found", 18)
  return false
end

CaveBot.Extensions.Imbuing.setup = function()
  CaveBot.registerAction("imbuing", "red", function(value, retries)
    local data = string.split(value, ",")
    local ids = {}

    if #data == 0 and value ~= 'name' then
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] no items added, proceeding", 18)
      reset()
      return false
    end

    -- setting of equipment manager so it wont disturb imbuing process
    EquipManager.setOff()

    if value == 'name' then
      if not AutoImbueTable then
        modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] ERROR: AutoImbueTable is not defined! Make sure autoImbue.lua is loaded.", 18)
        reset()
        return false
      end

      -- Get player name safely, fallback to defaultEquipment if player not available
      local playerName = player and player:getName() or nil
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: playerName = " .. (playerName or "nil"), 18)
      local imbuData = playerName and AutoImbueTable[playerName] or AutoImbueTable.defaultEquipment
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: imbuData = " .. (imbuData and "found" or "nil"), 18)
      if not imbuData then
        local charName = playerName or "Unknown"
        modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] ERROR: No imbuement data found for character: " .. charName, 18)
        reset()
        return false
      end

      for id, imbues in pairs(imbuData) do
        table.insert(ids, id)
      end
      -- Sort IDs to ensure consistent processing order (lowest ID first)
      table.sort(ids)
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG: Sorted item IDs: " .. table.concat(ids, ", "), 18)
    else
      -- convert to number
      for i, id in ipairs(data) do
        id = tonumber(id)
        if not table.find(ids, id) then
          table.insert(ids, id)
        end
      end
    end

    -- all items imbued, can proceed
    if currentIndex > #ids then
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] used shrine on all items, proceeding", 18)

      -- Step 1: Close any remaining dialogs first (this enables the Close button)
      closeInfoDialog()
      delay(DELAYS.UI_UPDATE)  -- Wait for dialogs to close completely

      -- Step 2: Now close the imbuement window by clicking the Close button
      local imbuementWindow = getImbuementWindow()
      if imbuementWindow then
        modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Closing imbuement window", 18)

        -- Use dynamic close button finder
        local closeButton = findCloseButton(imbuementWindow)

        if closeButton then
          pcall(function() closeButton:onClick() end)
          modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Clicked close button", 18)
          delay(DELAYS.DIALOG_CLOSE_LONG)
        else
          -- Fallback: try pressing Escape to close it
          modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Close button not found, using Escape", 18)
          pcall(function()
            g_window.setPressed(KeyEscape, true)
            delay(DELAYS.DIALOG_HIDE)
            g_window.setPressed(KeyEscape, false)
          end)
          delay(DELAYS.DIALOG_CLOSE_LONG)
        end
      end

      -- Step 3: Reequip all imbued items before finishing
      reequipAllItems()

      reset()
      return true
    end

    -- State: init - find shrine and item
    if imbuementState == "init" then
      for _, tile in ipairs(g_map.getTiles(posz())) do
        for _, item in ipairs(tile:getItems()) do
            local id = item:getId()
            if table.find(SHRINES, id) then
              shrine = item
              break
            end
        end
      end

      -- if not shrine
      if not shrine then
        modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] shrine not found! proceeding", 18)
        reset()
        return false
      end

      destination = shrine:getPosition()
      currentId = ids[currentIndex]
      item = findItem(currentId)

      -- maybe equipped? try to take off
      if not item then
        -- did try before, still not found so item is unavailable
        if triedToTakeOff then
          modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] item not found! skipping: "..currentId, 18)
          triedToTakeOff = false
          currentIndex = currentIndex + 1
          imbuementState = "init"
          return "retry"
        end
        triedToTakeOff = true
        g_game.equipItemId(currentId)
        delay(DELAYS.UNEQUIP_ITEM)
        return "retry"
      end

      -- we are past unequiping so just in case we were forced before, reset var
      triedToTakeOff = false
      imbuementState = "walking"
      return "retry"
    end

    -- State: walking - move to shrine
    if imbuementState == "walking" then
      if not CaveBot.MatchPosition(destination, 1) then
        CaveBot.GoTo(destination, 1)
        delay(DELAYS.WALKING)
        return "retry"
      end

      -- Arrived at shrine, open it
      useWith(shrine, item)
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Opening shrine for item: "..currentId, 18)
      delay(DELAYS.SHRINE_OPEN)
      imbuementState = "clearing"
      return "retry"
    end

    -- State: clearing - clear all existing imbuements
    if imbuementState == "clearing" then
      local imbuementWindow = getImbuementWindow()

      if not imbuementWindow then
        windowWaitRetries = windowWaitRetries + 1
        if windowWaitRetries >= MAX_WINDOW_WAIT then
          modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] ERROR: Window did not open after " .. MAX_WINDOW_WAIT .. " retries, skipping item", 18)
          currentIndex = currentIndex + 1
          imbuementState = "init"
          windowWaitRetries = 0
          return "retry"
        end
        modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Waiting for window to open... (" .. windowWaitRetries .. "/" .. MAX_WINDOW_WAIT .. ")", 18)
        delay(DELAYS.WINDOW_WAIT)
        return "retry"
      end

      -- Window found, reset retry counter
      windowWaitRetries = 0
      clearImbuements(currentId)
      delay(DELAYS.CLEAR_COMPLETE)
      imbuementState = "imbuing"
      currentImbuementIndex = 1
      return "retry"
    end

    -- State: imbuing - apply imbuements one by one
    if imbuementState == "imbuing" then
      local playerName = player and player:getName() or nil
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG (state imbuing): playerName = " .. (playerName or "nil"), 18)
      local imbuData = playerName and AutoImbueTable[playerName] or AutoImbueTable.defaultEquipment
      modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] DEBUG (state imbuing): imbuData = " .. (imbuData and "found" or "nil"), 18)
      local imbuements = imbuData and imbuData[currentId] or nil

      if not imbuements or currentImbuementIndex > #imbuements then
        -- Done with this item, move to next
        modules.game_textmessage.displayGameMessage("CaveBot[Imbuing] Finished imbuing item: "..currentId, 18)

        -- Track this item for reequipping later
        if not table.find(imbuedItemIds, currentId) then
          table.insert(imbuedItemIds, currentId)
        end

        currentIndex = currentIndex + 1
        imbuementState = "init"
        currentImbuementIndex = 1
        delay(DELAYS.ITEM_COMPLETE)
        return "retry"
      end

      local imbueName = imbuements[currentImbuementIndex]
      -- Pass the slot index (0, 1, 2) for the current imbuement
      -- currentImbuementIndex is 1-based, so subtract 1 to get 0-based slot index
      local slotIndex = currentImbuementIndex - 1
      applyImbuement(currentId, imbueName, slotIndex)
      currentImbuementIndex = currentImbuementIndex + 1
      delay(DELAYS.BETWEEN_IMBUEMENTS)
      return "retry"
    end

    return "retry"
  end)

 CaveBot.Editor.registerAction("imbuing", "imbuing", {
  value="name",
  title="Auto Imbuing",
  description="insert below item ids to be imbued, separated by comma\nor 'name' to load from file",
 })
end

setDefaultTab("Stash")
-------------------------------------------------------
-- 0. Defaults + safety / compatibility fallbacks
-------------------------------------------------------
storage.stashNumFields = tonumber(storage.stashNumFields) or 30
autoStashEnabled = storage.autoStashEnabled or false
storage.stashDepositsDelay = tonumber(storage.stashDepositsDelay) or 500
storage.stashDepositsTolerance = tonumber(storage.stashDepositsTolerance) or 1
storage.stashWithdrawsDelay = tonumber(storage.stashWithdrawsDelay) or 500
storage.stashWithdrawsTolerance = tonumber(storage.stashWithdrawsTolerance) or 1
storage.stashActionMaxRetries = tonumber(storage.stashActionMaxRetries) or 2
storage.stashActionRetryWait = tonumber(storage.stashActionRetryWait) or 200

T = T or {}
U = U or nil
local _ = true
local a0, a1 = false, false

if not table.findbyfield then
  function table.findbyfield(tbl, field, value)
    if not tbl then return nil end
    for k, v in pairs(tbl) do
      if type(v) == "table" and v[field] == value then return v, k end
    end
    return nil
  end
end
if not table.empty then
  function table.empty(t) return next(t) == nil end
end
modules.corelib = modules.corelib or {}
if not modules.corelib.next then
  modules.corelib.next = function(tbl, last)
    if not tbl then return nil end
    if last == nil then
      for k, v in pairs(tbl) do return k, v end
      return nil
    end
    local found = false
    for k, v in pairs(tbl) do
      if found then return k, v end
      if k == last then found = true end
    end
    return nil
  end
end
if not modules.corelib.periodicalEvent then
  modules.corelib.periodicalEvent = function(statusFn, cbFn, interval, delay)
    local interval = tonumber(interval) or 500
    local active = true
    local function loop()
      if not active then return end
      pcall(function() if statusFn then statusFn() end end)
      local ok, res = pcall(cbFn)
      if ok and res == false then active = false; return end
      if active then schedule(interval, loop) end
    end
    schedule(delay or interval, loop)
    return { stop = function() active = false end }
  end
end

-------------------------------------------------------
-- 1. UI windows
-------------------------------------------------------
g_ui.loadUIFromString([[
AnenSpinBox < SpinBox
  id: value
  focusable: true
  text-align: center
StashDepositsWindow < MainWindow
  id: stashDeposits
  text: Config Deposits
  size: 350 205
  @onEscape: self:hide()
  UIWidget
    id: text
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    !text: tr("Quantity is how many you want to have left in backpack")
    text-wrap: true
    height: 35
    background-color: gray
  BotContainer
    id: items
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: text.bottom
    margin-top: 5
    margin-bottom: 55
    height: 250
StashWithdrawsWindow < MainWindow
  id: stashWithdraws
  text: Config Withdraws
  size: 350 205
  @onEscape: self:hide()
  UIWidget
    id: text
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    !text: tr("Quantity is how many you want to have left in backpack")
    text-wrap: true
    height: 35
    background-color: gray
  BotContainer
    id: items
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: text.bottom
    margin-top: 5
    margin-bottom: 55
    height: 250
]])
local depositsWindow = UI.createWindow("StashDepositsWindow")
local withdrawsWindow = UI.createWindow("StashWithdrawsWindow")
depositsWindow:hide()
withdrawsWindow:hide()
local function hideButtonPanel(win)
  if not win then return end
  if win.buttonPanel and win.buttonPanel.setVisible then pcall(function() win.buttonPanel:setVisible(false) end) end
end
hideButtonPanel(depositsWindow)
hideButtonPanel(withdrawsWindow)

-------------------------------------------------------
-- 2. Storage init
-------------------------------------------------------
if not storage["stashDeposits"] then storage["stashDeposits"] = { items = {} } end
if not storage["stashWithdraws"] then storage["stashWithdraws"] = { items = {} } end
local storageDeposits = storage["stashDeposits"]
local storageWithdraws = storage["stashWithdraws"]

-------------------------------------------------------
-- 3. ContainerAnen
-------------------------------------------------------
UI.ContainerAnen = function(callback, uniqueItems, unused_e, parentItemsWidget, onItemWidgetCreate, hideCount, tooltip, opts)
  local f = parentItemsWidget
  opts = opts or {}
  local currentList = {}
  local onItemsChanged = function()
    local m = f:getItems()
    local changed = #m ~= #currentList
    for i, p in ipairs(m) do
      if type(currentList[i]) ~= "table" then changed = true; break end
      if currentList[i].id ~= p.id or currentList[i].count ~= p.count then changed = true; break end
    end
    if changed then
      currentList = m
      callback(f, m)
    end
    f:setItems(m)
  end
  f.setItems = function(self, m)
    if type(self) == 'table' then m = self end
    local NUM = math.max(tonumber(storage.stashNumFields) or 30, #m + 2)
    if NUM % 5 ~= 0 then NUM = NUM + 5 - NUM % 5 end
    f.items:destroyChildren()
    for i = 1, NUM do
      local wi = g_ui.createWidget("BotItem", f.items)
      if type(m[i]) == 'number' then m[i] = { id = m[i], count = 1 } end
      if type(m[i]) == 'table' then pcall(function() wi:setItem(Item.create(m[i].id, m[i].count)) end) end
      if hideCount then wi:setShowCount(false) end
      if wi:getItemId() ~= 0 and tooltip then wi:setTooltip(tooltip) end
    end
    currentList = m
    for _, child in ipairs(f.items:getChildren()) do
      child.onItemChange = onItemsChanged
      if type(onItemWidgetCreate) == "function" then onItemWidgetCreate(child) end
      if opts.maxItem then
        child.onMousePress = function(widget, mousePos, button)
          if button ~= 1 then return end
          schedule(120, function()
            local sel = g_ui.getRootWidget():getChildById("itemSelector")
            if sel and sel.getChildById then
              local ic = sel:getChildById("itemCount")
              if ic and ic.setMaximum then ic:setMaximum(opts.maxItem) end
              if ic and ic.setValue then ic:setValue(child:getItemCountOrSubType()) end
            end
          end)
        end
      end
    end
  end
  f.getItems = function()
    local out, seen = {}, {}
    for _, w in ipairs(f.items:getChildren()) do
      local id = w.getItemId and w:getItemId() or 0
      if id >= 100 then
        if not seen[id] or not uniqueItems then
          table.insert(out, { id = id, count = w:getItemCountOrSubType() })
          seen[id] = true
        end
      end
    end
    return out
  end
  f:setItems({})
  return f
end

-------------------------------------------------------
-- 4. UI helpers
-------------------------------------------------------
modules.gamelib = modules.gamelib or {}
modules.gamelib.Player = modules.gamelib.Player or {}
modules.gamelib.Player.getItems = function(self, itemId, itemSubType, countContainers, containerList)
  itemSubType = itemSubType or -1
  if containerList then containerList = type(containerList) ~= "table" and { containerList } or containerList end
  local foundItems = {}
  if not countContainers then
    for i = 1, 10 do
      local item = self:getInventoryItem(i)
      if item and item:getId() == itemId and (itemSubType == -1 or item:getSubType() == itemSubType) then
        table.insert(foundItems, item)
      end
    end
  end
  for _, container in pairs(containerList or g_game.getContainers()) do
    for slot, item in pairs(container:getItems()) do
      if item:getId() == itemId and (itemSubType == -1 or item:getSubType() == itemSubType) then
        item.container = container
        table.insert(foundItems, item)
      end
    end
  end
  return foundItems
end
displayNumberInputBox = function(...)
  local B = ...
  local C = modules.corelib.UIInputBox.create(B.title, B.callback, B.cancelCallback)
  local D = nil
  if B.description then
    D = C:addLabel(B.description)
    D:setTextAutoResize(true)
    D:setWidth(235)
    D:setTextWrap(true)
  end
  local E = g_ui.createWidget('AnenSpinBox', C)
  E:setMinimum(B.min and type(B.min) == "table" and B.min[1][B.min[2]] or B.min or 0)
  E:setMaximum(B.max and type(B.max) == "table" and B.max[1][B.max[2]] or B.max or 100)
  E:setValue(B.value and type(B.value) == "table" and B.value[1][B.value[2]] or B.value or 1)
  E:setStep(B.step or 1)
  E.onValueChange = function(_, val) if B.onValueChange then B.onValueChange(val) end end
  table.insert(C.inputs, function() return E:getValue() end)
  C:display()
  schedule(50, function() C:show() C:raise() C:focus() C:raise() end)
  return C, D
end
modules.gamelib.Player.getItemsCount = function(self, v, x, y)
  local m, total = self:getItems(v, -1, x, y), 0
  for i = 1, #m do total = total + m[i]:getCount() end
  return total
end
function table.findbyfieldL(H, I, J, K)
  if not H then return end
  for idx, item in pairs(H) do
    if type(item) == "table" then
      if K then
        if tostring(item[I]):lower() == tostring(J):lower() then return item, idx end
      else
        if item[I] == J then return item, idx end
      end
    end
  end
end

-------------------------------------------------------
-- 5. Containers
-------------------------------------------------------
local depositsContainer = UI.ContainerAnen(function(widget, list)
  storageDeposits.items = table.collect(list, function(_, it)
    local existing = table.findbyfield(storageDeposits.items, "id", it.id)
    return { id = it.id, count = it.count, tolerance = existing and existing.tolerance or 0 }
  end)
end, true, nil, depositsWindow.items, function(r)
  if r:getItemId() == 0 then return end
  r.onMouseRelease = function(_, _, button)
    if button ~= 2 then return end
    local obj, idx = table.findbyfieldL(storageDeposits.items, "id", r:getItemId())
    if not obj then return end
    local P = math.ceil(obj.count * obj.tolerance / 100)
    local box, desc = displayNumberInputBox({
      title = "Tolerance",
      description = ("Tolerance: %d%% (Min: %d, Max: %d)"):format(obj.tolerance, obj.count - P, obj.count + P),
      value = obj.tolerance,
      onValueChange = function(val)
        local P2 = math.ceil(obj.count * val / 100)
        if desc and desc.setText then desc:setText(("Tolerance: %d%% (Min: %d, Max: %d)"):format(val, obj.count - P2, obj.count + P2)) end
        storageDeposits.items[idx].tolerance = val
      end,
      callback = function(val) storageDeposits.items[idx].tolerance = val end
    })
  end
end, false, nil, { maxItem = 999999 })
local withdrawsContainer = UI.ContainerAnen(function(widget, list)
  storageWithdraws.items = table.collect(list, function(_, it)
    local existing = table.findbyfield(storageWithdraws.items, "id", it.id)
    return { id = it.id, count = it.count, tolerance = existing and existing.tolerance or 0 }
  end)
end, true, nil, withdrawsWindow.items, function(r)
  if r:getItemId() == 0 then return end
  r.onMouseRelease = function(_, _, button)
    if button ~= 2 then return end
    local obj, idx = table.findbyfieldL(storageWithdraws.items, "id", r:getItemId())
    if not obj then return end
    local P = math.ceil(obj.count * obj.tolerance / 100)
    local box, desc = displayNumberInputBox({
      title = "Tolerance",
      description = ("Tolerance: %d%% (Min: %d, Max: %d)"):format(obj.tolerance, obj.count - P, obj.count + P),
      value = obj.tolerance,
      onValueChange = function(val)
        local P2 = math.ceil(obj.count * val / 100)
        if desc and desc.setText then desc:setText(("Tolerance: %d%% (Min: %d, Max: %d)"):format(val, obj.count - P2, obj.count + P2)) end
        storageWithdraws.items[idx].tolerance = val
      end,
      callback = function(val) storageWithdraws.items[idx].tolerance = val end
    })
  end
end, false, nil, { maxItem = 999999 })
depositsContainer:setItems(storageDeposits.items)
withdrawsContainer:setItems(storageWithdraws.items)

-------------------------------------------------------
-- 6. Buttons & Sidepanel
-------------------------------------------------------
local depositBtn = UI.Button("Config Deposits", function()
  depositsWindow:setText("Config Deposits")
  depositsContainer:setItems(storageDeposits.items)
  depositsWindow:show()
  depositsWindow:raise()
  depositsWindow:focus()
end)
local withdrawBtn = UI.Button("Config Withdraws", function()
  withdrawsWindow:setText("Config Withdraws")
  withdrawsContainer:setItems(storageWithdraws.items)
  withdrawsWindow:show()
  withdrawsWindow:raise()
  withdrawsWindow:focus()
end)
local stashState = { showDepositsConfig = false, showWithdrawsConfig = false }
local function createConfigTextEdit(labelText, storageKey, defaultValue)
  local lbl = UI.Label(labelText)
  local edit = UI.TextEdit(tostring(storage[storageKey] or defaultValue), function(widget, text)
    local trimmed = (text or ""):trim()
    local n = tonumber(trimmed)
    if n ~= nil then storage[storageKey] = n else storage[storageKey] = trimmed end
  end)
  return lbl, edit
end
local depositsWidgets = {}
local showDepositsConfigBtn = UI.Button("Deposits Config (Delay/Tol)", function() stashState.showDepositsConfig = not stashState.showDepositsConfig end)
local d_delay_label, d_delay_edit = createConfigTextEdit("Delay (ms):", "stashDepositsDelay", 500)
local d_tol_label, d_tol_edit = createConfigTextEdit("Tolerance (%):", "stashDepositsTolerance", 1)
table.insert(depositsWidgets, d_delay_label); table.insert(depositsWidgets, d_delay_edit)
table.insert(depositsWidgets, d_tol_label); table.insert(depositsWidgets, d_tol_edit)
local withdrawsWidgets = {}
local showWithdrawsConfigBtn = UI.Button("Withdraws Config (Delay/Tol)", function() stashState.showWithdrawsConfig = not stashState.showWithdrawsConfig end)
local w_delay_label, w_delay_edit = createConfigTextEdit("Delay (ms):", "stashWithdrawsDelay", 500)
local w_tol_label, w_tol_edit = createConfigTextEdit("Tolerance (%):", "stashWithdrawsTolerance", 1)
table.insert(withdrawsWidgets, w_delay_label); table.insert(withdrawsWidgets, w_delay_edit)
table.insert(withdrawsWidgets, w_tol_label); table.insert(withdrawsWidgets, w_tol_edit)

-------------------------------------------------------
-- 7. Stash Interaction Helpers (V, W, Z)
-------------------------------------------------------

-- Polling helper för att vänta på fönster
local function pollForWindow(id, timeout, callback)
  local startTime = os.clock()
  local timeoutInSeconds = timeout / 1000
  local function check()
    local window = g_ui.getRootWidget():getChildById(id)
    if window then callback(window); return end
    if os.clock() - startTime > timeoutInSeconds then callback(nil); return end
    schedule(100, check)
  end
  check()
end

-- V():
local function V(callback)
  local ok, children = pcall(function()
    return g_ui.getRootWidget():getChildById("gameRootPanel")
      :getChildById("gameRightPanels")
      :recursiveGetChildById("miniwindowsButtons")
      :recursiveGetChildById("contentsPanel")
      :getChildren()
  end)
  if not ok or not children then
    if callback then callback(nil) end
    return
  end
  for _, btn in ipairs(children) do
    if btn:getId() == "stashButton" then
      btn:onClick()
      pollForWindow("widget1483", 2000, callback)
      return
    end
  end
  if callback then callback(nil) end
end

-- W():
local function W(callback, show)
  local stashWindow = g_ui.getRootWidget():getChildById("widget1483")
  if stashWindow then
    if show and stashWindow:isHidden() then stashWindow:show() end
    if type(callback) == "function" then callback(stashWindow) end
    return
  end
  V(function(newlyOpenedWindow)
    if newlyOpenedWindow then
      if type(callback) == "function" then callback(newlyOpenedWindow) end
    else
      if type(callback) == "function" then callback(nil) end
    end
  end)
end

-- parseCount(): hanterar k-notation
local function parseCount(str)
  if not str then return 0 end
  str = str:lower():gsub(",", ".")
  local multiplier = 1
  if str:find("k") then
    multiplier = 1000
    str = str:gsub("k", "")
  end
  local n = tonumber(str)
  if n then return math.floor(n * multiplier) end
  return 0
end

-- Z(): Tar snapshot av stash
local function Z()
  W(function(stashWindow)
    if not stashWindow then
      return
    end

    U = stashWindow
    T = {}

    local panel = stashWindow.rootItemsPanel and stashWindow.rootItemsPanel.itemsPanel
    if not panel then
      return
    end

    for _, itemWidget in ipairs(panel:getChildren()) do
      local itemObject = itemWidget.item
      if itemObject and type(itemObject.getItemId) == "function" then
        local itemId = itemObject:getItemId()
        local countTextWidget = itemWidget.count
        if itemId > 0 and countTextWidget and countTextWidget.getText then
          local itemCount = parseCount(countTextWidget:getText())
          if itemCount > 0 then
            table.insert(T, { item = itemId, count = itemCount })
          end
        end
      end
    end


    -- Stänger stash window efter liten delay (om det behövs)
    schedule(300, function()
      if stashWindow and stashWindow.closeButton and stashWindow.closeButton.onClick then
        stashWindow.closeButton:onClick()
      end
    end)
  end, true)
end

-- Kör snapshot direkt vid scriptstart
Z()

-- Hook för att köra Z() varje gång stash öppnas manuellt
schedule(500, function()
  local root = g_ui.getRootWidget()
  if root then
    local oldOnAddChild = root.onChildAdd
    root.onChildAdd = function(widget)
      if oldOnAddChild then oldOnAddChild(widget) end
      if widget:getId() == "stashWindow" then
        Z() -- snapshot direkt när stash öppnas
      end
    end
  end
end)

-------------------------------------------------------
-- 8. Interaction helpers (rewritten)
-------------------------------------------------------

-- Parses text like "12.7k" or "48.76k" into a proper number
local function parseCount(str)
  if not str then return 0 end
  str = str:lower():gsub(",", ".")
  local multiplier = 1
  if str:find("k") then
    multiplier = 1000
    str = str:gsub("k", "")
  end
  local n = tonumber(str)
  if n then return math.floor(n * multiplier) end
  return 0
end

-- Get total count of an item in the player's inventory
local function getPlayerTotalCount(itemId)
  local player = g_game.getLocalPlayer()
  if not player then return 0 end
  local ok, n = pcall(function() return player:getItemsCount(itemId, true) end)
  if ok and type(n) == "number" then return n end
  return 0
end

-- Recursive search for a widget by styleName
local function getChildByStyleName(styleName, root)
  root = root or g_ui.getRootWidget()
  if not root or not root.getChildren then return nil end
  for _, child in ipairs(root:getChildren()) do
    if child.getStyleName and type(child.getStyleName) == "function" then
      if child:getStyleName() == styleName then
        return child
      end
    end
    local found = getChildByStyleName(styleName, child)
    if found then return found end
  end
  return nil
end

-- Poll for a widget by ID
local function pollForWidgetById(id, timeout, callback)
  local startTime = os.clock()
  local timeoutInSeconds = timeout / 1000
  local function check()
    local widget = g_ui.getRootWidget():getChildById(id)
    if widget then callback(widget); return end
    if os.clock() - startTime > timeoutInSeconds then callback(nil); return end
    schedule(100, check)
  end
  check()
end

-- Poll for a widget by style
local function pollForWidgetByStyle(styleName, timeout, callback)
  local startTime = os.clock()
  local timeoutInSeconds = timeout / 1000
  local function check()
    local widget = getChildByStyleName(styleName)
    if widget then callback(widget); return end
    if os.clock() - startTime > timeoutInSeconds then callback(nil); return end
    schedule(100, check)
  end
  check()
end

-- Generic helper to split large stack into chunks based on countWindow max
local function sendCountWindowAction(countWin, total, callback)
  local maxValue = countWin.countScrollBar and countWin.countScrollBar:getMaximum() or total
  local toSend = math.min(total, maxValue)
  if toSend <= 0 then callback(0); return end
  if countWin.countScrollBar then countWin.countScrollBar:setValue(toSend) end
  if countWin.buttonOk then countWin.buttonOk:onClick() end
  local remaining = total - toSend
  if remaining > 0 then
    schedule(200, function()
      sendCountWindowAction(countWin, remaining, callback)
    end)
  else
    callback(total)
  end
end

-- Deposit (Stow) items
local function a2_with_confirm(itemId, wantCount, callback)
  local player = g_game.getLocalPlayer()
  local thing = player:getItems(itemId, nil, true)[1]
  modules.game_interface.createThingMenu({ x = 0, y = 0 }, nil, thing)
  pollForWidgetByStyle("PopupMenu", 1000, function(popup)
    for _, option in ipairs(popup:getChildren()) do
      if option:getText() == "Stow" then
        option:onClick()
        pollForWidgetById("countWindow", 1000, function(countWin)
          local totalToSend = math.min(thing:getCount(), wantCount)
          sendCountWindowAction(countWin, totalToSend, function(sent)
            callback(sent)
          end)
        end)
        return
      end
    end
    callback(0)
  end)
end

-- Withdraw items from stash
local function ac_with_confirm(itemId, wantCount, callback)
  W(function(stashWindow)
    local panel = stashWindow.rootItemsPanel and stashWindow.rootItemsPanel.itemsPanel
    for _, itemWidget in ipairs(panel:getChildren()) do
      if itemId == (itemWidget.item and itemWidget.item:getItemId()) then
        itemWidget.item:onClick()
        pollForWidgetById("countWindow", 1000, function(countWin)
          local availableCount = parseCount(itemWidget.count:getText())
          local totalToWithdraw = math.min(wantCount, availableCount)
          sendCountWindowAction(countWin, totalToWithdraw, function(sent)
            callback(sent)
          end)
        end)
        return
      end
    end
    callback(0)
  end, true)
end

-------------------------------------------------------
-- PLACEHOLDER FÖR AUTO STASH
-------------------------------------------------------
local autoStashMacro = nil  -- deklarera först så wrappers kan referera den

-------------------------------------------------------
-- Wrappers for periodical flows (a8/ad)
-------------------------------------------------------
-- Deposit Wrapper
local function a8_wrapper(m, doneCb)
  local aa, remaining = nil, {}
  for k, v in pairs(m) do remaining[k] = v end

  a0 = true
  modules.corelib.periodicalEvent(function() end, function()
    if not autoStashMacro or not autoStashMacro:isOn() then
      a0 = false
      return false
    end

    local v, need = modules.corelib.next(remaining, aa)
    if not v then
      a0 = false
      doneCb()
      return false
    end

    aa = v  -- current item key
    _ = false

    a2_with_confirm(tonumber(v), need, function(moved)
      remaining[v] = remaining[v] - (moved or 0)
      if remaining[v] <= 0 then
        remaining[v] = nil  -- klart med detta item
      end
      _ = true  -- tillåt nästa iteration
    end)

    return true
  end, storage.stashDepositsDelay, storage.stashDepositsDelay)
end

-- Withdraw Wrapper
local function ad_wrapper(m, doneCb)
  local aa, remaining = nil, {}
  for k, v in pairs(m) do remaining[k] = v end

  a1 = true
  modules.corelib.periodicalEvent(function() end, function()
    if not autoStashMacro or not autoStashMacro:isOn() then
      a1 = false
      return false
    end

    local v, need = modules.corelib.next(remaining, aa)
    if not v then
      a1 = false
      doneCb()
      return false
    end

    aa = v  -- current item key
    _ = false

    ac_with_confirm(tonumber(v), need, function(moved)
      remaining[v] = remaining[v] - (moved or 0)
      if remaining[v] <= 0 then
        remaining[v] = nil  -- klart med detta item
      end
      _ = true
    end)

    return true
  end, storage.stashWithdrawsDelay, storage.stashWithdrawsDelay)
end

-------------------------------------------------------
-- 10. MASTER MACRO (Färdig version)
-------------------------------------------------------


local masterMacroTick = 0


autoStashMacro = macro(500, "Auto Stash", function()
    if masterMacroTick == nil then masterMacroTick = 0 end

        -- Part 1: Sidepanel UI Update
    pcall(function()
        if showDepositsConfigBtn and showWithdrawsConfigBtn then
            showDepositsConfigBtn:setVisible(true)
            showWithdrawsConfigBtn:setVisible(true)
        end
        for _, w in ipairs(depositsWidgets) do w:setVisible(stashState.showDepositsConfig) end
        for _, w in ipairs(withdrawsWidgets) do w:setVisible(stashState.showWithdrawsConfig) end
    end)

    -- Part 3: Main Logic (runs every 2nd tick)
    if masterMacroTick % 2 == 0 then
        if not autoStashMacro:isOn() then return end
        if a0 or a1 then return end

       
        local withdrawTasks, saveTasks = {}, {}

        -- Withdraw Rules
        for _, rule in ipairs(storageWithdraws.items) do
            local current_count = getPlayerTotalCount(rule.id)
            local target_count = rule.count or 0
            local tolerance = tonumber(rule.tolerance) or storage.stashWithdrawsTolerance or 1
            local threshold = math.ceil(target_count * tolerance / 100)
            if current_count < target_count - threshold then
                local itemInStash = table.findbyfield(T, "item", rule.id)
                if itemInStash then
                    withdrawTasks[tostring(rule.id)] = math.min(target_count - current_count, itemInStash.count)
                end
            end
        end

        -- Deposit Rules
        for _, rule in ipairs(storageDeposits.items) do
            local current_count = getPlayerTotalCount(rule.id)
            local target_count = rule.count or 0
            local tolerance = tonumber(rule.tolerance) or storage.stashDepositsTolerance or 1
            local threshold = math.ceil(target_count * tolerance / 100)
            if current_count > target_count + threshold then
                saveTasks[tostring(rule.id)] = current_count - target_count
            end
        end

        -- Execute Tasks
        if not table.empty(withdrawTasks) then
            ad_wrapper(withdrawTasks, function()
                Z()
            end)
            return
        end

        if not table.empty(saveTasks) then
            a8_wrapper(saveTasks, function()
                Z()
            end)
        end
    end

    masterMacroTick = masterMacroTick + 1
end)

autoStashMacro.onToggle = function(widget)
    storage.autoStashEnabled = widget:isOn()
end

if storage.autoStashEnabled then
    autoStashMacro:setOn(true)
end
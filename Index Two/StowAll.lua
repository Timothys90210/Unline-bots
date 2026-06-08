-- StowAll.lua
-- Sibling of Stash.lua, but instead of the "Stow" context option (which opens
-- a count window and lets you keep a quantity), this uses the
-- "Stow all items of this type" option — every configured item is fully dumped
-- into the Supply Stash, nothing is kept back.
--
-- Loaded as a root-level script via dofile in _Loader.lua, so the window style
-- must be defined inline with g_ui.loadUIFromString (see Stash.lua / lessons.md).

-- Load guard — _Loader re-runs in the same persistent Lua state on soft reload.
if StowAllLoaded then return end
StowAllLoaded = true

setDefaultTab("Stash")

-------------------------------------------------------
-- 0. Storage / defaults
-------------------------------------------------------
if type(storage.stowAllItems) ~= "table" then storage.stowAllItems = {} end
storage.stowAllEnabled = storage.stowAllEnabled or false
storage.stowAllDelay = tonumber(storage.stowAllDelay) or 1000

-------------------------------------------------------
-- 1. Config window
-------------------------------------------------------
g_ui.loadUIFromString([[
StowAllWindow < MainWindow
  id: stowAll
  text: StowAll Items
  size: 350 205
  @onEscape: self:hide()
  UIWidget
    id: text
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    !text: tr("Items added here get fully stowed (Stow all items of this type)")
    text-wrap: true
    height: 35
    background-color: gray
  BotContainer
    id: items
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: text.bottom
    margin-top: 5
    margin-bottom: 10
    height: 250
]])
local stowWindow = UI.createWindow("StowAllWindow")
stowWindow:hide()
if stowWindow.buttonPanel and stowWindow.buttonPanel.setVisible then
  pcall(function() stowWindow.buttonPanel:setVisible(false) end)
end

-- Wire the item grid so edits persist to storage. The BotContainer itself
-- exposes :setItems / :getItems; UI.Container attaches the change callback.
UI.Container(function(widget, items)
  storage.stowAllItems = items
end, true, nil, stowWindow.items)
stowWindow.items:setItems(storage.stowAllItems)

-------------------------------------------------------
-- 2. Tab UI — red on/off toggle + config button
-------------------------------------------------------
local ui = setupUI([[
Panel
  height: 19
  BotSwitch
    id: switch
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    !text: tr('Stow All')
]])
ui:setId("StowAll")

-- Force the toggle red regardless of on/off state (mirrors cavebot ON/OFF button).
local function paintSwitch()
  pcall(function() ui.switch:setBackgroundColor("#8B0000") end)
end
ui.switch:setOn(storage.stowAllEnabled)
paintSwitch()
ui.switch.onClick = function(widget)
  storage.stowAllEnabled = not storage.stowAllEnabled
  widget:setOn(storage.stowAllEnabled)
  paintSwitch()
end

UI.Button("Config Items", function()
  stowWindow.items:setItems(storage.stowAllItems)
  stowWindow:show()
  stowWindow:raise()
  stowWindow:focus()
end)

-------------------------------------------------------
-- 3. Stash interaction helpers
-------------------------------------------------------
-- Recursive search for a widget by styleName (PopupMenu has no fixed id).
local function getChildByStyleName(styleName, root)
  root = root or g_ui.getRootWidget()
  if not root or not root.getChildren then return nil end
  for _, child in ipairs(root:getChildren()) do
    if child.getStyleName and child:getStyleName() == styleName then
      return child
    end
    local found = getChildByStyleName(styleName, child)
    if found then return found end
  end
  return nil
end

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

-- Right-click an item of `itemId` and pick "Stow all items of this type".
-- Unlike "Stow", this option stows every stack of that type immediately with
-- no count window — so a single click clears the item from the backpack.
local function stowAllOf(itemId, done)
  local thing = findItem(itemId)
  if not thing then done(false); return end
  modules.game_interface.createThingMenu({ x = 0, y = 0 }, nil, thing)
  pollForWidgetByStyle("PopupMenu", 1000, function(popup)
    if not popup then done(false); return end
    local target
    for _, option in ipairs(popup:getChildren()) do
      if option.getText and option:getText() == "Stow all items of this type" then
        target = option
        break
      end
    end
    if not target then
      -- Fallback: any "stow all" option that isn't the looted-items one.
      for _, option in ipairs(popup:getChildren()) do
        local t = option.getText and option:getText():lower() or ""
        if t:find("stow all") and not t:find("loot") then target = option; break end
      end
    end
    if target then
      target:onClick()
      done(true)
    else
      pcall(function() popup:destroy() end)
      done(false)
    end
  end)
end

-------------------------------------------------------
-- 4. Worker macro (anonymous — driven by the red switch)
-------------------------------------------------------
local busy = false

macro(storage.stowAllDelay, function()
  if not storage.stowAllEnabled then return end
  if busy then return end

  local player = g_game.getLocalPlayer()
  if not player then return end

  -- One stow-all action per cycle: find the first configured item still in the
  -- backpack and dump it. Next cycle moves to the next item.
  for _, entry in ipairs(storage.stowAllItems) do
    local id = type(entry) == "table" and entry.id or entry
    if id and id >= 100 and player:getItemsCount(id) > 0 then
      busy = true
      stowAllOf(id, function()
        schedule(300, function() busy = false end)
      end)
      return
    end
  end
end)

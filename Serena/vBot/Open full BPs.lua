setDefaultTab("Tools")

local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('Open Full BPs')

  Button
    id: edit
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Edit
]])

local edit = setupUI([[
Panel
  height: 70

  Label
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 5
    text-align: center
    text: Loot Containers:

  BotContainer
    id: containers
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 45
]])
edit:hide()

if not storage.openFullBPs then
  storage.openFullBPs = {
    enabled = false,
    containers = {}
  }
end

local config = storage.openFullBPs

local showEdit = false
ui.edit.onClick = function()
  showEdit = not showEdit
  if showEdit then
    edit:show()
  else
    edit:hide()
  end
end

ui.title:setOn(config.enabled)
ui.title.onClick = function()
  config.enabled = not config.enabled
  ui.title:setOn(config.enabled)
end

UI.Container(function()
  config.containers = edit.containers:getItems()
end, true, nil, edit.containers)
edit.containers:setItems(config.containers)

local function openNextLootContainer()
  if not config.enabled then return end

  local lootContainerIds = {}
  for _, entry in pairs(config.containers or {}) do
    if type(entry) == "table" and entry.id then
      table.insert(lootContainerIds, tonumber(entry.id))
    end
  end

  if #lootContainerIds == 0 then return end

  for _, container in pairs(getContainers()) do
    local cId = container:getContainerItem():getId()
    if containerIsFull(container) and table.find(lootContainerIds, cId) then
      for _, item in ipairs(container:getItems()) do
        if item:getId() == cId then
          return g_game.open(item, container)
        end
      end
    end
  end
end

macro(120 * 1000, function()
  openNextLootContainer()
end)

onContainerOpen(function(container, previousContainer)
  schedule(100, function()
    openNextLootContainer()
  end)
end)

onAddItem(function(container, slot, item, oldItem)
  schedule(100, function()
    openNextLootContainer()
  end)
end)

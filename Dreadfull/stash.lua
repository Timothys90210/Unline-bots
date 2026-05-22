setDefaultTab("Tools")

local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 100
    !text: tr('Stasher')

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
  height: 180

  Label
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 5
    text-align: center
    text: Stash:

  BotContainer
    id: StashItems
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 32

  Button
    id: ok
    anchors.top: prev.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    margin-top: 10
    width: 40
    height: 17
    text: OK
]])
edit:hide()

-- Config simple
if not storage.stasher then
  storage.stasher = {
    enabled = false,
    stashItems = {}
  }
end
local config = storage.stasher

-- Mostrar/ocultar editor
ui.edit.onClick = function()
  if edit:isVisible() then edit:hide() else edit:show() end
end
-- Botón OK cierra editor
edit.ok.onClick = function() edit:hide() end

-- Switch ON/OFF
ui.title:setOn(config.enabled)
ui.title.onClick = function()
  config.enabled = not config.enabled
  ui.title:setOn(config.enabled)
end

-- Bind del BotContainer
UI.Container(function()
  config.stashItems = edit.StashItems:getItems()
end, true, nil, edit.StashItems)
edit.StashItems:setItems(config.stashItems)

-- Helper igual al dropper
local function properTable(t)
  local r = {}
  for _, entry in pairs(t) do
    table.insert(r, entry.id)
  end
  return r
end

-- Click automático robusto al botón OK de la ventana "Retrieve items"
local function tryPressOK()
  local root = g_ui.getRootWidget()
  if not root then return false end

  for _, w in ipairs(root:recursiveGetChildren()) do
    if w.getText and type(w.getText) == "function" then
      local txt = (w:getText() or ""):lower()
      -- Frases típicas; añade variantes si tu cliente está traducido
      if txt:find("number of items you want to move")
         or txt:find("retrieve items")
         or txt:find("cantidad de objetos")
         or txt:find("mover articulos")
      then
        local p = w:getParent()
        if p and p.getChildren then
          for _, c in ipairs(p:getChildren()) do
            if c.getText and type(c.getText) == "function" then
              local ct = (c:getText() or ""):lower()
              if (ct == "ok" or ct == "aceptar" or ct == "accept") and c.onClick then
                c:onClick()
                return true
              end
            end
          end
        end
      end
    end
  end
  return false
end

-- Tamaño fijo de grupo (100)
local GROUP_COUNT = 100

-- Macro único
macro(1000, function()
  if not config.enabled then return end

  local stash = modules.game_stash
  if not (stash and stash.preStowItem) then return end

  local ids = properTable(config.stashItems)
  if #ids == 0 then
    -- Aun así, si la ventana quedó abierta por otra razón, intentamos cerrarla
    tryPressOK()
    return
  end

  -- Recorre contenedores abiertos (como el dropper)
  local containers = getContainers()
  for _, container in pairs(containers) do
    for __, item in ipairs(container:getItems()) do
      local itemId = item:getId()
      local count = (item.getCount and item:getCount()) or 0
      for ___, wantId in ipairs(ids) do
        if itemId == wantId and count == GROUP_COUNT then
          -- Stashea el stack de 100
          stash.preStowItem(item)
          -- En algunos clientes, la ventana tarda unos ms; intentamos varias veces
          if tryPressOK() then return end
          delay(50)
          if tryPressOK() then return end
          delay(50)
          if tryPressOK() then return end
          return
        end
      end
    end
  end

  -- Si no stasheamos nada esta pasada, igual revisamos si quedó la ventana abierta
  tryPressOK()
end)

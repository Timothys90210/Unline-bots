--Join Discord server for free scripts
--https://discord.gg/RkQ9nyPMBH
--Made By VivoDibra
--Tested on vBot 4.8 / OTCV8 3.2 rev 4

if not storage.NewComboLeader then
  storage.NewComboLeader = {}
end

local settings = storage.NewComboLeader

if settings.enabled == nil then
  settings.enabled = true
end

if not settings.sdMissle then
  settings.sdMissle = 32
end

if not settings.AttackEnemiesHK then
  settings.AttackEnemiesHK = "f5"
end

g_ui.loadUIFromString([[
NewComboLeaderTextEdit < Panel
  height: 40

  UIWidget
    id: text
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    text-align: center
    
  TextEdit
    id: textEdit
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 5
    minimum: 0
    maximum: 10
    step: 1
    text-align: center

NewComboLeaderItem < Panel
  height: 34
  margin-top: 7
  margin-left: 25
  margin-right: 25

  UIWidget
    id: text
    anchors.left: parent.left
    anchors.verticalCenter: next.verticalCenter

  BotItem
    id: item
    anchors.top: parent.top
    anchors.right: parent.right


NewComboLeaderWindow < MainWindow
  !text: tr('NewComboLeader')
  size: 440 360
  padding: 25

  Label
    anchors.left: parent.left
    anchors.right: parent.horizontalCenter
    anchors.top: parent.top
    text-align: center

  Label
    anchors.left: parent.horizontalCenter
    anchors.right: parent.right
    anchors.top: parent.top
    text-align: center

  VerticalScrollBar
    id: contentScroll
    anchors.top: prev.bottom
    margin-top: 3
    anchors.right: parent.right
    anchors.bottom: separator.top
    step: 28
    pixels-scroll: true
    margin-right: -10
    margin-top: 5
    margin-bottom: 5

  ScrollablePanel
    id: content
    anchors.top: prev.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: separator.top
    vertical-scrollbar: contentScroll
    margin-bottom: 10
      
    Panel
      id: left
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.horizontalCenter
      margin-top: 5
      margin-left: 10
      margin-right: 10
      layout:
        type: verticalBox
        fit-children: true

    Panel
      id: right
      anchors.top: parent.top
      anchors.left: parent.horizontalCenter
      anchors.right: parent.right
      margin-top: 5
      margin-left: 10
      margin-right: 10
      layout:
        type: verticalBox
        fit-children: true

    VerticalSeparator
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: parent.horizontalCenter

  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 8

  ResizeBorder
    id: bottomResizeBorder
    anchors.fill: separator
    height: 3
    minimum: 260
    maximum: 600
    margin-left: 3
    margin-right: 3
    background: #ffffff88    

  Button
    id: closeButton
    !text: tr('Close')
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 45 21
    margin-right: 5
]])

-- basic elements
NewComboLeaderWindow = UI.createWindow('NewComboLeaderWindow', rootWidget)
NewComboLeaderWindow:hide()
NewComboLeaderWindow.closeButton.onClick = function(widget)
  NewComboLeaderWindow:hide()
end

NewComboLeaderWindow:setHeight(350)
NewComboLeaderWindow:setWidth(450)
NewComboLeaderWindow:setText("New Combo Leader")

local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('New Combo Leader')

  Button
    id: push
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup

]])

ui.title:setOn(settings.enabled)
ui.title.onClick = function(widget)
  settings.enabled = not settings.enabled
  widget:setOn(settings.enabled)
end

ui.push.onClick = function(widget)
  NewComboLeaderWindow:show()
  NewComboLeaderWindow:raise()
  NewComboLeaderWindow:focus()
end

-- available options for dest param
local rightPanel = NewComboLeaderWindow.content.right
local leftPanel = NewComboLeaderWindow.content.left

-- objects made by Kondrah - taken from creature editor, minor changes to adapt
local addItem = function(id, title, defaultItem, dest, tooltip)
  local widget = UI.createWidget('NewComboLeaderItem', dest)
  widget.text:setText(title)
  widget.text:setTooltip(tooltip)
  widget.item:setTooltip(tooltip)
  widget.item:setItemId(settings[id] or defaultItem)
  widget.item.onItemChange = function(widget)
    settings[id] = widget:getItemId()
  end
  settings[id] = settings[id] or defaultItem
end

local addTextEdit = function(id, title, defaultValue, dest, tooltip)
  local widget = UI.createWidget('NewComboLeaderTextEdit', dest)
  widget.text:setText(title)
  widget.textEdit:setText(settings[id] or defaultValue or "")
  widget.text:setTooltip(tooltip)
  widget.textEdit.onTextChange = function(widget,text)
    settings[id] = text
  end
  settings[id] = settings[id] or defaultValue or ""
end

local m_leaderTarget = macro(10000, "Leader Target", function() end, leftPanel)
local m_comboSD = macro(10000, "Combo Rune", function() end, leftPanel)
local m_comboSpell = macro(10000, "Combo UE", function() end, leftPanel)

hotkey(settings.AttackEnemiesHK, "Attack Enemy Listed",function()
  if g_game.isAttacking() then return end
  
  local enemies = {}
  for _, enemyName in ipairs(storage.playerList.enemyList) do
    local enemy = getCreatureByName(enemyName)
    if enemy then
      local enemyT = g_map.getTile(enemy:getPosition())
      if enemyT:canShoot() then
        table.insert(enemies, enemy)
      end
    end
  end
  
  table.sort(enemies, function(a, b)
    local distA = getDistanceBetween(a:getPosition(), pos())
    local distB = getDistanceBetween(b:getPosition(), pos())
    return distA < distB
  end)
  
  local t = enemies[1]
  if t then
    g_game.attack(t)
  end
end, leftPanel)

addTextEdit("LeaderName", "Leader Name",settings.LeaderName or "name", rightPanel)

addTextEdit("LeaderSpell", "Leader UE",settings.LeaderSpell or "exevo gran mas frigo", rightPanel)

addTextEdit("UE", "Your UE",settings.UE or "exevo gran mas frigo", rightPanel)

addTextEdit("AttackEnemiesHK", "Attack Enemies HK", "f5", rightPanel)

addItem("SD", "Rune", 3155, leftPanel, "")

local m_configRune = macro(10000, "Config Rune", function() end, leftPanel)

addLabel("","to configure the rune combo, enable the 'Config Rune' macro, and ask the leader to use the rune in any target, DO NOT ATTACK, only rune :)", leftPanel)

addButton("", "+ Free Scripts", function()
  g_platform.openUrl("https://discord.gg/RkQ9nyPMBH")
end, leftPanel)

--inspired by vbot 4.8 combo
onMissle(function(missle)
  if not settings.enabled then return end
  local src = missle:getSource()
  if src.z ~= posz() then return end
  
  local from = g_map.getTile(src)
  local to = g_map.getTile(missle:getDestination())
  if not from or not to then return end
  
  local fromCreatures = from:getCreatures()
  local toCreatures = to:getCreatures()
  if #fromCreatures ~= 1 or #toCreatures ~= 1 then return end
  
  local c1 = fromCreatures[1]
  local t1 = toCreatures[1]
  
  if t1:getName():lower() == settings.LeaderName:lower() then return end
  if table.find(storage.playerList.friendList, t1:getName(), true) then return end
  
  if c1:getName():lower() == settings.LeaderName:lower() then
    if m_configRune.isOn() then
      settings.sdMissle = missle:getId()      
      modules.game_textmessage.displayGameMessage("Rune Combo Configured.")
      m_configRune:setOff()
    else
      if m_leaderTarget:isOn() then
        local target = g_game.getAttackingCreature()
        if not target or target ~= t1 then
          g_game.attack(t1)
          schedule(1000, function()
            g_game.cancelAttackAndFollow()
          end)
        end
      end
      if m_comboSD.isOn() and missle:getId() == settings.sdMissle then
        useWith(settings.SD, t1)
      end
    end
  end
end)

onTalk(function(name, level, mode, text, channelId, pos) 
  if not settings.enabled then return end
  if m_comboSpell.isOn() and name:lower() == settings.LeaderName:lower() and text:lower() == settings.LeaderSpell:lower() then
    say(settings.UE)
  end
end)

--Join Discord server for free scripts
--https://discord.gg/RkQ9nyPMBH
--Made By VivoDibra
--Tested on vBot 4.8 / OTCV8 3.2 rev 4
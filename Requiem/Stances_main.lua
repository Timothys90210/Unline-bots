if StancesLoaded then return end
StancesLoaded = true

setDefaultTab("Main")

--[[
  Stances.lua
  -----------
  Global stance manager (vocation-agnostic).

  * "Attack stance"   : when toggled on, keeps the character in the selected
                        attack stance. Detection is driven by the Default chat:
                          "You enter the XYZ stance."  -> we are in that stance
                          "You leave the XYZ stance."  -> we left that stance
  * "Defensive stance": same idea, but only triggers when HP drops below the
                        HP% set on the scroll bar. While active it takes
                        precedence over the attack stance.

  The spell behind each button is chosen from a pop-up spell box. The same box
  is reused for both buttons; whichever button opened it receives the choice.
]]

-- ###########################################################################
-- ## Spell database
-- ###########################################################################
local stanceSpells = {
  { voc = "Paladin",  name = "Master Archer",        spell = "utori con" },
  { voc = "Paladin",  name = "Divine Defiance",      spell = "utori san def", defensive = true },
  { voc = "Knight",   name = "Berserker Stance",     spell = "utito stancia" },
  { voc = "Knight",   name = "Guardian Stance",      spell = "utamo stancia", defensive = true },
  { voc = "Druid",    name = "Elemental Synthesis",  spell = "utori tera frigo" },
  { voc = "Druid",    name = "Shared Conservation",  spell = "utori sio", defensive = true },
  { voc = "Sorcerer", name = "Lord of Thunder",      spell = "utori vis" },
  { voc = "Sorcerer", name = "Lord of Flames",       spell = "utori flam" },
  { voc = "Sorcerer", name = "Lord of Death",        spell = "utori mort" },
}

-- ###########################################################################
-- ## Storage
-- ###########################################################################
storage.stances = storage.stances or {}
local cfg = storage.stances
cfg.attackSpell    = cfg.attackSpell    or nil   -- { name = , spell = }
cfg.defensiveSpell = cfg.defensiveSpell or nil   -- { name = , spell = }
cfg.defensiveHp    = tonumber(cfg.defensiveHp) or 30
cfg.attackEnabled    = cfg.attackEnabled    or false
cfg.defensiveEnabled = cfg.defensiveEnabled or false

-- ###########################################################################
-- ## Stance state tracking (read from the Default chat)
-- ###########################################################################
-- Only one stance can be active at a time. We remember the name reported by
-- the last "You enter the <name> stance." message (lower-cased, trimmed).
local currentStanceName = nil

-- Reduce a stance name to a matchable keyword: drop "stance" / "(defensive)".
local function normalize(name)
  return (name or ""):lower()
    :gsub("%(defensive%)", "")
    :gsub("stance", "")
    :gsub("%s+", " ")
    :trim()
end

-- Is the character currently in the stance identified by `name`?
local function isInStance(name)
  if not currentStanceName then return false end
  local kw = normalize(name)
  if kw == "" then return false end
  return currentStanceName:find(kw, 1, true) ~= nil
end

onTextMessage(function(mode, text)
  local t = text:lower()
  if not t:find("stance") then return end
  local body = t:match("the%s+(.-)%s+stance")
  if t:find("you enter the") then
    currentStanceName = body or t
  elseif t:find("you leave the") then
    if not body or not currentStanceName then
      currentStanceName = nil
    elseif currentStanceName:find(body, 1, true) or body:find(currentStanceName, 1, true) then
      currentStanceName = nil
    end
  end
end)

-- ###########################################################################
-- ## Spell selection pop-up (shared by both buttons)
-- ###########################################################################
g_ui.loadUIFromString([[
StanceVocHeader < Label
  height: 16
  text-align: center
  color: #ffcc00
  background-color: #00000055
  margin-top: 4

StanceSpellChoice < Button
  height: 18
  text-align: center
  margin-top: 1

StanceSelectWindow < MainWindow
  id: stanceSelect
  text: Select Stance Spell
  size: 250 360
  @onEscape: self:hide()

  ScrollablePanel
    id: listPanel
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: closeButton.top
    margin-top: 2
    margin-bottom: 6
    margin-right: 14
    vertical-scrollbar: listScroll
    layout:
      type: verticalBox
      spacing: 1

  VerticalScrollBar
    id: listScroll
    anchors.top: listPanel.top
    anchors.bottom: listPanel.bottom
    anchors.right: parent.right
    step: 18
    pixels-scroll: true

  Button
    id: closeButton
    !text: tr('Close')
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 50 22
]])

local selectWindow = UI.createWindow("StanceSelectWindow")
selectWindow:hide()

-- which button is being configured: "attack" or "defensive"
local selectTarget = nil
-- forward declaration so spell clicks can refresh the button captions
local refreshButtons

local function applySelection(entry)
  if selectTarget == "attack" then
    cfg.attackSpell = { name = entry.name, spell = entry.spell }
  elseif selectTarget == "defensive" then
    cfg.defensiveSpell = { name = entry.name, spell = entry.spell }
  end
  selectWindow:hide()
  if refreshButtons then refreshButtons() end
end

-- Build the list once (the spells never change)
local lastVoc = nil
for _, entry in ipairs(stanceSpells) do
  if entry.voc ~= lastVoc then
    local header = g_ui.createWidget("StanceVocHeader", selectWindow.listPanel)
    header:setText(entry.voc)
    lastVoc = entry.voc
  end
  local btn = g_ui.createWidget("StanceSpellChoice", selectWindow.listPanel)
  btn:setText(entry.name .. (entry.defensive and "  (DEFENSIVE)" or ""))
  btn.onClick = function() applySelection(entry) end
end

selectWindow.closeButton.onClick = function() selectWindow:hide() end

local function openSelect(target)
  selectTarget = target
  selectWindow:setText(target == "attack" and "Select Attack Stance" or "Select Defensive Stance")
  selectWindow:show()
  selectWindow:raise()
  selectWindow:focus()
end

-- ###########################################################################
-- ## Hunt tab UI
-- ###########################################################################
UI.Separator()

-- 1. Attack stance toggle (red/green macro button)
-- Toggle state is persisted in storage and restored here. The live button
-- state is polled into storage by the worker below (onToggle is unreliable in
-- this client build), mirroring the proven Autospell pattern.
local attackMacro = macro(1000, "Attack stance", function() end)
attackMacro.setOn(cfg.attackEnabled)

-- 2. Attack stance spell selector
local attackSelectBtn = UI.Button("Attack spell: (none)", function() openSelect("attack") end)

-- 3. Defensive stance toggle (red/green macro button)
local defenseMacro = macro(1000, "Defensive stance", function() end)
defenseMacro.setOn(cfg.defensiveEnabled)

-- 4. Defensive stance spell selector
local defenseSelectBtn = UI.Button("Defensive spell: (none)", function() openSelect("defensive") end)

-- 5. Defensive HP threshold scroll bar
local hpPanel = setupUI([[
Panel
  height: 34
  Label
    id: text
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    text: HP 0% < 100%
  HorizontalScrollBar
    id: scroll
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 3
    minimum: 0
    maximum: 100
    step: 1
]])

hpPanel.scroll.onValueChange = function(scroll, value)
  cfg.defensiveHp = value
  hpPanel.text:setText("Defensive stance below HP " .. value .. "%")
end
hpPanel.scroll:setValue(cfg.defensiveHp)
hpPanel.scroll.onValueChange(hpPanel.scroll, hpPanel.scroll:getValue())

UI.Separator()

-- keep the selector button captions in sync with the stored selection
refreshButtons = function()
  attackSelectBtn:setText("Attack spell: " .. (cfg.attackSpell and cfg.attackSpell.name or "(none)"))
  defenseSelectBtn:setText("Defensive spell: " .. (cfg.defensiveSpell and cfg.defensiveSpell.name or "(none)"))
end
refreshButtons()

-- ###########################################################################
-- ## Maintenance worker
-- ###########################################################################
local lastCast = 0
local CAST_GUARD = 1500   -- ms between recast attempts (lets the chat update)

macro(500, function()
  local attackOn  = attackMacro.isOn()
  local defenseOn = defenseMacro.isOn()

  -- Keep the persisted toggle state in sync with the live buttons so it is
  -- correctly restored after the bot is turned off and on again.
  cfg.attackEnabled    = attackOn
  cfg.defensiveEnabled = defenseOn

  if not attackOn and not defenseOn then return end

  -- Defensive stance takes precedence while HP is below the set threshold.
  if defenseOn and cfg.defensiveSpell and cfg.defensiveSpell.spell
     and hppercent() < (cfg.defensiveHp or 0) then
    if not isInStance(cfg.defensiveSpell.name) and (now - lastCast) > CAST_GUARD then
      say(cfg.defensiveSpell.spell)
      lastCast = now
    end
    return
  end

  -- Otherwise hold the attack stance.
  if attackOn and cfg.attackSpell and cfg.attackSpell.spell then
    if not isInStance(cfg.attackSpell.name) and (now - lastCast) > CAST_GUARD then
      say(cfg.attackSpell.spell)
      lastCast = now
    end
  end
end)

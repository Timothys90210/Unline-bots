if WavesLoaded then return end
WavesLoaded = true

setDefaultTab("Hunt")

--[[
  Waves.lua
  ---------
  Global wave-spell caster (vocation-agnostic).

  * "Waves" toggle (red button): when on, the script watches for monster
    clusters inside the selected wave spell's area. If at least "Monsters"
    creatures (the number in the input box = "that many OR MORE") fall inside
    the wave area for some facing, the character turns to face that direction
    and casts the wave.

  * Spell is chosen from a pop-up box (same style as Stances.lua).

  Wave areas (caster = G, forward = up), confirmed from the reference image:

    All normal waves            Paladin "Divine Barrage"
        X X X X X                   X X X X
          X X X                     X X X X
          X X X                     X X X X   6 forward
            X                       X X X X
            G                       X X X X
                                    X X X X
                                    X G X X   caster row (1 left, 2 right)
                                    X X X X   2 behind
                                    X X X X
]]

-- ###########################################################################
-- ## Spell database
-- ###########################################################################
-- pattern: "wave" = standard cone, "barrage" = Divine Barrage box
local waveSpells = {
  { voc = "Paladin",  name = "Divine Barrage",  spell = "exori gran mas con",  mana = 600, cooldown = 6, pattern = "barrage" },
  { voc = "Knight",   name = "Shield Bash",     spell = "exori scutum hur",    mana = 300, cooldown = 3, pattern = "wave" },
  { voc = "Druid",    name = "Ice Wave",        spell = "exevo frigo hur",     mana = 25,  cooldown = 4, pattern = "wave" },
  { voc = "Druid",    name = "Tera Wave",       spell = "exevo tera hur",      mana = 210, cooldown = 4, pattern = "wave" },
  { voc = "Sorcerer", name = "Fire Wave",       spell = "exevo flam hur",      mana = 25,  cooldown = 4, pattern = "wave" },
  { voc = "Sorcerer", name = "Great Fire Wave", spell = "exevo gran flam hur", mana = 150, cooldown = 4, pattern = "wave" },
  { voc = "Sorcerer", name = "Energy Wave",     spell = "exevo vis hur",       mana = 170, cooldown = 4, pattern = "wave" },
}

-- ###########################################################################
-- ## Area patterns
-- ###########################################################################
-- Each cell is {forward, right} relative to the character, where forward is
-- toward the facing direction and right is to the character's right hand.
local patterns = {}

-- Standard wave cone: 1 / 3 / 3 / 5 tiles deep
patterns.wave = {
  {1, 0},
  {2, -1}, {2, 0}, {2, 1},
  {3, -1}, {3, 0}, {3, 1},
  {4, -2}, {4, -1}, {4, 0}, {4, 1}, {4, 2},
}

-- Divine Barrage box: forward -2..6 (2 behind, caster row, 6 forward),
-- right -1..2 (1 left, caster column, 2 right)
patterns.barrage = {}
for f = -2, 6 do
  for r = -1, 2 do
    patterns.barrage[#patterns.barrage + 1] = { f, r }
  end
end

-- Rotate a {forward, right} offset into a {dx, dy} map offset for a facing.
-- dir: 0 = North, 1 = East, 2 = South, 3 = West (matches g_game / turn()).
local function rotate(f, r, dir)
  if dir == 0 then      -- North: forward = -y, right = +x
    return r, -f
  elseif dir == 1 then  -- East:  forward = +x, right = +y
    return f, r
  elseif dir == 2 then  -- South: forward = +y, right = -x
    return -r, f
  else                  -- West:  forward = -x, right = -y
    return -f, -r
  end
end

-- ###########################################################################
-- ## Storage
-- ###########################################################################
storage.waves = storage.waves or {}
local cfg = storage.waves
cfg.enabled  = cfg.enabled or false
cfg.selected = cfg.selected or nil               -- selected spell name
cfg.monsters = tonumber(cfg.monsters) or 2       -- "this many or more"

local function getSelectedSpell()
  if not cfg.selected then return nil end
  for _, s in ipairs(waveSpells) do
    if s.name == cfg.selected then return s end
  end
  return nil
end

-- ###########################################################################
-- ## Spell selection pop-up
-- ###########################################################################
g_ui.loadUIFromString([[
WaveVocHeader < Label
  height: 16
  text-align: center
  color: #ffcc00
  background-color: #00000055
  margin-top: 4

WaveSpellChoice < Button
  height: 18
  text-align: center
  margin-top: 1

WaveSelectWindow < MainWindow
  id: waveSelect
  text: Select Wave Spell
  size: 260 320
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

local selectWindow = UI.createWindow("WaveSelectWindow")
selectWindow:hide()

local refreshButton  -- forward declaration

local function applySelection(entry)
  cfg.selected = entry.name
  selectWindow:hide()
  if refreshButton then refreshButton() end
end

local lastVoc = nil
for _, entry in ipairs(waveSpells) do
  if entry.voc ~= lastVoc then
    local header = g_ui.createWidget("WaveVocHeader", selectWindow.listPanel)
    header:setText(entry.voc)
    lastVoc = entry.voc
  end
  local btn = g_ui.createWidget("WaveSpellChoice", selectWindow.listPanel)
  btn:setText(entry.name .. "  (" .. entry.mana .. " mana, " .. entry.cooldown .. "s)")
  btn.onClick = function() applySelection(entry) end
end

selectWindow.closeButton.onClick = function() selectWindow:hide() end

-- ###########################################################################
-- ## Hunt tab UI
-- ###########################################################################
UI.Separator()

-- 1. Waves toggle (red/green macro button). Its state is persisted in storage
-- and restored here; the worker below polls the live button into storage
-- (onToggle is unreliable in this client build).
local wavesMacro = macro(1000, "Waves", function() end)
wavesMacro.setOn(cfg.enabled)

-- 2. Wave spell selector
local selectBtn = UI.Button("Wave spell: (none)", function()
  selectWindow:show()
  selectWindow:raise()
  selectWindow:focus()
end)

-- 3. "Monsters" numeric input (this many OR MORE inside the wave area)
local condPanel = setupUI([[
Panel
  height: 22

  UIWidget
    id: lbl
    text: Monsters:
    width: 62
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    font: verdana-11px-rounded
    text-align: left

  BotTextEdit
    id: input
    width: 40
    height: 16
    anchors.left: lbl.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 4
    text-align: center
]])
condPanel.input:setText(tostring(cfg.monsters))
condPanel.input.onTextChange = function(widget, text)
  local clean = text:gsub("%D", "")          -- digits only
  if clean ~= text then
    widget:setText(clean)
    return                                    -- setText re-fires this handler
  end
  cfg.monsters = tonumber(clean) or 0
end

UI.Separator()

refreshButton = function()
  selectBtn:setText("Wave spell: " .. (cfg.selected or "(none)"))
end
refreshButton()

-- ###########################################################################
-- ## Worker
-- ###########################################################################
local lastCast = 0

macro(200, function()
  -- Persist toggle state so it survives the bot being turned off/on.
  local on = wavesMacro.isOn()
  cfg.enabled = on
  if not on then return end

  if not player then return end

  -- Cheap early rejects before scanning creatures.
  if not target() then return end          -- only cast with an active target
  local spell = getSelectedSpell()
  if not spell then return end
  if isInPz() then return end
  if (now - lastCast) < (spell.cooldown * 1000) then return end
  if player:getMana() < spell.mana then return end

  local threshold = tonumber(cfg.monsters) or 0
  if threshold < 1 then return end

  -- Build a lookup of monster tiles on the current floor.
  local pPos = player:getPosition()
  local monsters = {}
  local any = false
  for _, spec in pairs(getSpectators(false)) do
    if spec ~= player and spec:isMonster()
       and (g_game.getClientVersion() < 960 or spec:getType() < 3) then
      local mp = spec:getPosition()
      if mp.z == pPos.z then
        monsters[mp.x .. ":" .. mp.y] = true
        any = true
      end
    end
  end
  if not any then return end

  -- Count how many monsters the wave would hit for each of the 4 facings.
  local pat = patterns[spell.pattern]
  local counts = {}
  local maxCount = -1
  for dir = 0, 3 do
    local c = 0
    for _, cell in ipairs(pat) do
      local dx, dy = rotate(cell[1], cell[2], dir)
      if monsters[(pPos.x + dx) .. ":" .. (pPos.y + dy)] then
        c = c + 1
      end
    end
    counts[dir] = c
    if c > maxCount then maxCount = c end
  end

  if maxCount < threshold then return end

  -- Pick the best facing, preferring the current one on a tie (less turning).
  local curDir = player:getDirection()
  local bestDir
  if curDir and curDir <= 3 and counts[curDir] == maxCount then
    bestDir = curDir
  else
    for dir = 0, 3 do
      if counts[dir] == maxCount then bestDir = dir break end
    end
  end

  -- Face the monsters first, then cast on the next tick.
  if player:getDirection() ~= bestDir then
    turn(bestDir)
    return
  end

  say(spell.spell)
  lastCast = now
end)

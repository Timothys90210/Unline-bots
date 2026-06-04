setDefaultTab("Main")
UI.Label("[[ Massacre Bomb ]]"):setFont("verdana-11px-rounded")

local runeId    = 52287
local exhausted = 1000
local minHP     = 50  -- self HP% to stop using item

local panelName = "massacreBomb"

local defaults = {
  info       = {on=false, title="HP%", item=runeId, min=1, max=100},
  minTargets = 5,
  radius     = 3,
}

if not storage[panelName] then storage[panelName] = defaults end
-- upgrade older saves missing new keys
if storage[panelName].minTargets == nil then storage[panelName].minTargets = defaults.minTargets end
if storage[panelName].radius     == nil then storage[panelName].radius     = defaults.radius     end

local config = storage[panelName]

-- HP range panel
UI.DualScrollItemPanel(config.info, function(widget, newParams)
  config.info = newParams
end)

-- Target count + radius inputs
local condPanel = setupUI([[
Panel
  height: 22

  UIWidget
    id: lbl1
    text: Min targets:
    width: 68
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    font: verdana-11px-rounded
    text-align: left

  BotTextEdit
    id: targetsInput
    width: 30
    height: 16
    anchors.left: lbl1.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 2
    text-align: center

  UIWidget
    id: lbl2
    text: Radius:
    width: 40
    anchors.left: targetsInput.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 6
    font: verdana-11px-rounded
    text-align: left

  BotTextEdit
    id: radiusInput
    width: 30
    height: 16
    anchors.left: lbl2.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 2
    text-align: center
]])

condPanel.targetsInput:setText(tostring(config.minTargets))
condPanel.radiusInput:setText(tostring(config.radius))

condPanel.targetsInput.onTextChange = function(widget, text)
  config.minTargets = tonumber(text) or defaults.minTargets
end
condPanel.radiusInput.onTextChange = function(widget, text)
  config.radius = tonumber(text) or defaults.radius
end

-- Count monsters within square radius of the player
local function countNearbyMonsters(radius)
  local count = 0
  local px, py, pz = posx(), posy(), posz()
  for _, spec in pairs(getSpectators(false)) do
    if spec:isMonster() and (g_game.getClientVersion() < 960 or spec:getType() < 3) then
      local pos = spec:getPosition()
      if pos.z == pz
         and math.abs(pos.x - px) <= radius
         and math.abs(pos.y - py) <= radius then
        count = count + 1
      end
    end
  end
  return count
end

local massacreMacro = macro(100, function()
  if not config.info.on then return end
  if player:getHealthPercent() < minHP then return end

  local data      = config.info
  local minT      = config.minTargets or defaults.minTargets
  local radius    = config.radius     or defaults.radius

  -- Check monster count condition first (fastest reject)
  local nearby = countNearbyMonsters(radius)
  if nearby < minT then return end

  -- Find or validate attack target within HP range
  local target = g_game.getAttackingCreature()
  if target then
    if target:getHealthPercent() < data.min or target:getHealthPercent() > data.max then
      g_game.cancelAttack()
      delay(exhausted / 3)
      return
    end
  else
    for _, spec in pairs(getSpectators(false)) do
      if spec:isMonster() and (g_game.getClientVersion() < 960 or spec:getType() < 3) then
        if spec:getHealthPercent() >= data.min and spec:getHealthPercent() <= data.max then
          local pos = spec:getPosition()
          if pos.z == posz()
             and math.abs(pos.x - posx()) <= radius
             and math.abs(pos.y - posy()) <= radius then
            g_game.attack(spec)
            delay(exhausted / 3)
            break
          end
        end
      end
    end
  end

  target = g_game.getAttackingCreature()
  if not target then return end

  useWith(data.item, target)
  delay(exhausted)
end)

local runeIcon = addIcon("massacreIcon", {switchable=true, item={id=runeId, count=1}, movable=true, text="Bombs"}, function() end)
runeIcon.onClick = function() config.info.on = not config.info.on end
runeIcon.text:setFont("verdana-11px-rounded")

macro(100, function()
  runeIcon.text:setColor(config.info.on and "green" or "red")
end)

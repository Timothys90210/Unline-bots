-- CONFIGURACIÓN DE COLORES Y TIPOS DE DAÑO
local colorDamageTable = {
  { name = "Physical", r = 255, g = 0,   b = 0,   color = '#ff0000' },
  { name = "Holy",     r = 255, g = 255, b = 0,   color = '#ffff00' },
  { name = "Energy",   r = 204, g = 51,  b = 255, color = '#cc33ff' },
  { name = "Fire",     r = 255, g = 153, b = 0,   color = '#ff9900' },
  { name = "Ice",      r = 153, g = 255, b = 255, color = '#99ffff' },
  { name = "Earth",    r = 0,   g = 255, b = 0,   color = '#00ff00' },
  { name = "Death",    r = 153, g = 0,   b = 0,   color = '#990000' },
}

-- INICIAR CONTADORES DE DAÑO Y TIEMPO
storage.colorDamageLog = storage.colorDamageLog or {}
for _, entry in ipairs(colorDamageTable) do
  storage.colorDamageLog[entry.name] = storage.colorDamageLog[entry.name] or 0
end

storage.dmgStartTime = storage.dmgStartTime or os.time()

-- FUNCIÓN PARA FORMATO CORTO DE NÚMEROS
function shortNumber(n)
  if n >= 1000000 then
    return string.format("%.1fm", n / 1000000)
  elseif n >= 1000 then
    return string.format("%.1fk", n / 1000)
  else
    return tostring(n)
  end
end

-- CREAR PANEL VISUAL
local damagePanel = setupUI([[
OutlineLabel < Label
  height: 12
  background-color: #00000088
  opacity: 0.95
  text-auto-resize: true
  font: verdana-11px-rounded
  anchors.left: parent.left
  $first:
    anchors.top: parent.top
  $!first:
    anchors.top: prev.bottom

Panel
  id: damageTypePanel
  height: 50
  width: 190
  anchors.right: parent.right
  anchors.bottom: parent.bottom
  margin-bottom: 5
  margin-left: 5
]], modules.game_interface.getMapPanel())

-- FUNCIÓN PARA ACTUALIZAR PANEL VISUAL
local function updateDamagePanel()
  local elapsed = math.max(1, os.time() - storage.dmgStartTime)

  for _, entry in ipairs(colorDamageTable) do
    local totalDmg = storage.colorDamageLog[entry.name] or 0
    local dmgPerHour = math.floor(totalDmg / elapsed * 3600)

    local label = damagePanel[entry.name] or UI.createWidget("OutlineLabel", damagePanel)
    label:setId(entry.name)
    label:setColoredText({
      '~ ' .. entry.name .. ': ', entry.color or 'white',
      shortNumber(totalDmg), 'white',
      ' | ', 'white',
      shortNumber(dmgPerHour) .. ' dmg/h', 'gray'
    })
  end

  damagePanel:setHeight(damagePanel:getChildCount() * 13)
end

-- MACRO PARA ACTUALIZACIÓN AUTOMÁTICA
macro(500, function()
  updateDamagePanel()
end)

-- DETECTOR DE TEXTO DE DAÑO SOBRE EL JUGADOR
g_map.onAnimatedText = function(thing, text)
  local pos = thing:getPosition()
  if getDistanceBetween(pos, player:getPosition()) ~= 0 then return end

  local n = tonumber(text)
  if not n then return end

  local color = thing:getColor()
  local r, g, b = color.r or 0, color.g or 0, color.b or 0

  for _, entry in ipairs(colorDamageTable) do
    if r == entry.r and g == entry.g and b == entry.b then
      storage.colorDamageLog[entry.name] = (storage.colorDamageLog[entry.name] or 0) + n
      break
    end
  end
end

-- BOTÓN PARA RESETEAR DATOS
UI.Button("Reset Dmg Stats", function()
  for _, entry in ipairs(colorDamageTable) do
    storage.colorDamageLog[entry.name] = 0
  end
  storage.dmgStartTime = os.time()
end)

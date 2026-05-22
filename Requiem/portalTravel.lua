local function normalizeNavText(text)
  text = tostring(text or ""):lower()
  text = text:gsub("'", "")
  text = text:gsub("\226\128\153", "") -- UTF-8 right single quote
  text = text:gsub("\146", "") -- CP1252 right single quote
  text = text:gsub("%s+", " ")
  text = text:match("^%s*(.-)%s*$") or ""
  return text
end

function PortalTravel(city, waypoint)
  local navPanel = g_ui.getRootWidget():recursiveGetChildById("navPanel")
  if not navPanel then
    return false
  end

  local wantedCity = normalizeNavText(city)
  local wantedWaypoint = normalizeNavText(waypoint)

  for _, widget in ipairs(navPanel:getChildren()) do
    local cityName = normalizeNavText(widget:getChildren()[1]:getText())
    if cityName == wantedCity then
      local waypointsWidgets = widget:getChildren()[2]:getChildren()
      for _, waypointWidget in ipairs(waypointsWidgets) do
        local waypointName = normalizeNavText(waypointWidget:getText())
        if waypointName == wantedWaypoint then
          waypointWidget:onClick()
          return true
        end
      end
      return false
    end
  end

  return false
end

local cavebotActionNextRun = cavebotActionNextRun or {}

local function currentTimeMs()
  if type(now) == "function" then
    return now()
  end

  if type(now) == "number" then
    return now
  end

  if g_clock and g_clock.millis then
    return g_clock.millis()
  end

  return os.time() * 1000
end

local function tileIdVisible(id, floor, maxDistance)
  local z = floor or posz()
  local tiles = g_map.getTiles(z) or {}
  local p = pos()

  local function matchesDistance(tilePos)
    if not maxDistance then
      return true
    end
    return math.max(math.abs(tilePos.x - p.x), math.abs(tilePos.y - p.y)) <= maxDistance
  end

  for _, tile in ipairs(tiles) do
    local tilePos = tile:getPosition()
    local ground = tile:getGround()
    if ground and ground:getId() == id and matchesDistance(tilePos) then
      return true
    end

    for _, thing in ipairs(tile:getThings() or {}) do
      if thing:getId() == id and matchesDistance(tilePos) then
        return true
      end
    end
  end

  return false
end

local function runCavebotAction(actionText)
  if type(actionText) ~= "string" then return false end
  local action, value = actionText:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
  if not action then
    return false
  end

  action = action:lower()
  local registered = CaveBot and CaveBot.Actions and CaveBot.Actions[action]
  if not registered or type(registered.callback) ~= "function" then
    return false
  end

  return registered.callback(value or "", 0, true)
end

function DoCavebotActionUntilTileIdVisible(id, actionText, intervalMs, floor, actionKey, range)
  local key = actionKey or actionText or tostring(id)

  if tileIdVisible(id, floor, range) then
    cavebotActionNextRun[key] = nil
    return true
  end

  local nowMs = currentTimeMs()
  local nextRun = cavebotActionNextRun[key] or 0

  if nowMs >= nextRun then
    runCavebotAction(actionText)
    cavebotActionNextRun[key] = nowMs + (intervalMs or 1000)
  end

  return "retry"
end

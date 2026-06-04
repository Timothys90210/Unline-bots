-- Definición de los pilares con su posición y ID objetivo
local targetChecks = {
  {pos = {x = 2750, y = 821, z = 5}, targetID = 33172},
  {pos = {x = 2754, y = 821, z = 5}, targetID = 33171},
  {pos = {x = 2750, y = 817, z = 5}, targetID = 33169},
  {pos = {x = 2754, y = 817, z = 5}, targetID = 33170}
}

-- Tile de la armadura que debe estar en su lugar
local armorTile = {pos = {x = 2753, y = 817, z = 5}, id = 33168}

-- Índice actual del pilar que se está revisando
storage.useGroundIndex = storage.useGroundIndex or 1

-- Función para verificar si la armor está en su lugar
local function isArmorInPlace()
  local tile = g_map.getTile(armorTile.pos)
  if not tile then return false end
  local topThing = tile:getTopUseThing()
  return topThing and topThing:getId() == armorTile.id
end

-- Macro principal
Pilar = macro(200, "Girar pilares (con armor)", function()
  if not isArmorInPlace() then return end -- No girar si falta la armor

  local check = targetChecks[storage.useGroundIndex]
  local tile = g_map.getTile(check.pos)

  if tile then
    local topThing = tile:getTopUseThing()
    if topThing then
      if topThing:getId() ~= check.targetID then
        g_game.use(topThing)
        return -- Sigue girando este hasta que sea correcto
      end
    end
  end

  -- Si el pilar ya está correcto, avanzar al siguiente
  storage.useGroundIndex = storage.useGroundIndex + 1
  if storage.useGroundIndex > #targetChecks then
    storage.useGroundIndex = 1
  end
end)

-- Botón para encender/apagar el macro
addIcon("Pilar", {item = armorTile.id, text = "Pilar"}, function(icon, isOn)
  Pilar.setOn(isOn)
end)



local requiredTiles = {
  {pos = {x = 2750, y = 821, z = 5}, id = 33172},
  {pos = {x = 2754, y = 821, z = 5}, id = 33171},
  {pos = {x = 2750, y = 817, z = 5}, id = 33169},
  {pos = {x = 2754, y = 817, z = 5}, id = 33170}
}

local triggerTile = {pos = {x = 2753, y = 817, z = 5}, id = 33168}

local function allTilesMatch()
  for _, tileData in ipairs(requiredTiles) do
    local tile = g_map.getTile(tileData.pos)
    if not tile then return false end

    local topThing = tile:getTopUseThing()
    if not topThing or topThing:getId() ~= tileData.id then
      return false
    end
  end
  return true
end

local function triggerTileIsValid()
  local tile = g_map.getTile(triggerTile.pos)
  if not tile then return false end

  local topThing = tile:getTopUseThing()
  return topThing and topThing:getId() == triggerTile.id
end

local checkPillars = macro(200, "Revisar pilares y activar", function()
  if allTilesMatch() and triggerTileIsValid() then
    local tile = g_map.getTile(triggerTile.pos)
    if tile then
      local topThing = tile:getTopUseThing()
      if topThing then
        g_game.use(topThing)
      end
    end
  end
end)

-- Icono opcional para controlar el macro
addIcon("CheckPillars", {item = triggerTile.id, text = "Armor"}, function(icon, isOn)
  checkPillars.setOn(isOn)
end)




-- Lista de IDs de efectos a esquivar (avisan que caerá un efecto peligroso)
local effectIdsToDodge = {78, 79, 80, 188}

-- Lista de IDs que indican que el peligro ya pasó (tiles seguras de nuevo)
local effectIdsSafe = {575, 277, 404}

local avoidItemId = 1949 -- ID de ítem a evitar
local maxSearchDistance = 7 -- Rango máximo de búsqueda progresiva
local reentryDelay = 5 -- Seguridad extra para no volver a pisar instantáneo
local recentlyDangerousTiles = {} -- key = "x,y,z", value = timestamp
local flags = {
    ignoreNonPathable = true
}

local wasChaseDisabledByMacro = false
local lastDangerTime = 0

-- Verifica si un tile tiene alguno de los efectos peligrosos
function hasDangerousEffect(tile)
    for _, fx in ipairs(tile:getEffects()) do
        for _, dangerId in ipairs(effectIdsToDodge) do
            if fx:getId() == dangerId then
                return true
            end
        end
    end
    return false
end

-- Verifica si un tile tiene un efecto que lo hace seguro otra vez
function hasSafeEffect(tile)
    for _, fx in ipairs(tile:getEffects()) do
        for _, safeId in ipairs(effectIdsSafe) do
            if fx:getId() == safeId then
                return true
            end
        end
    end
    return false
end

-- Verifica si el tile tiene un ítem específico
function hasAvoidItem(tile)
    for i = 0, tile:getThingCount() - 1 do
        local thing = tile:getThing(i)
        if thing and thing:getId() == avoidItemId then
            return true
        end
    end
    return false
end

-- Verifica si el tile tiene una criatura
function tileHasCreature(tile)
    return tile and tile:getTopCreature() ~= nil
end

function posToKey(pos)
    return pos.x .. "," .. pos.y .. "," .. pos.z
end

function isTileRecentlyDangerous(pos)
    local key = posToKey(pos)
    local timestamp = recentlyDangerousTiles[key]
    return timestamp and (os.clock() - timestamp < reentryDelay)
end

function cleanupOldDangerousTiles()
    local now = os.clock()
    for key, timestamp in pairs(recentlyDangerousTiles) do
        if now - timestamp >= reentryDelay then
            recentlyDangerousTiles[key] = nil
        end
    end
end

-- Limpia tiles si aparece un efecto "seguro"
function cleanupBySafeEffect()
    for _, tile in ipairs(g_map.getTiles(player:getPosition().z)) do
        if hasSafeEffect(tile) then
            local key = posToKey(tile:getPosition())
            recentlyDangerousTiles[key] = nil
        end
    end
end

dodge = macro(200, "Dodge Effects", function()
    local playerTile = player:getTile()
    cleanupOldDangerousTiles()
    cleanupBySafeEffect()

    if hasDangerousEffect(playerTile) or hasAvoidItem(playerTile) then
        local playerPos = player:getPosition()
        local key = posToKey(playerPos)
        recentlyDangerousTiles[key] = os.clock()
        lastDangerTime = os.clock()

        -- Cambiar a no follow
        if not wasChaseDisabledByMacro then
            g_game.setChaseMode(0)
            wasChaseDisabledByMacro = true
        end

        local safeTileFound = false

        for distance = 1, maxSearchDistance do
            local nearbyTiles = {}
            for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
                local tilePos = tile:getPosition()
                if tilePos and getDistanceBetween(playerPos, tilePos) == distance then
                    table.insert(nearbyTiles, tile)
                end
            end

            table.sort(nearbyTiles, function(a, b)
                local ap, bp = a:getPosition(), b:getPosition()
                return getDistanceBetween(playerPos, ap) < getDistanceBetween(playerPos, bp)
            end)

            for _, tile in ipairs(nearbyTiles) do
                local tilePos = tile:getPosition()
                if not hasDangerousEffect(tile)
                   and not hasAvoidItem(tile)
                   and not isTileRecentlyDangerous(tilePos)
                   and not tileHasCreature(tile)
                   and findPath(playerPos, tilePos, 15, flags)
                then
                    autoWalk(tilePos, 15, flags)
                    CaveBot.delay(500)
                    delay(500)
                    safeTileFound = true
                    break
                end
            end

            if safeTileFound then break end
        end

    elseif wasChaseDisabledByMacro and (os.clock() - lastDangerTime >= reentryDelay) then
        -- Cambiar a follow de nuevo
        g_game.setChaseMode(1)
        wasChaseDisabledByMacro = false
    end
end)

addIcon("Dodge", {item={id=22538, count=100}, text="Dodge"}, function(icon, isOn)
dodge.setOn(isOn)
end)

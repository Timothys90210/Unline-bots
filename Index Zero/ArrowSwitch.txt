-- Arrow Switch
-- Toggles between normal arrows (3447) and diamond arrows (25757) based on nearby monsters
-- If any monster around has "Trainer" in its name -> enable normal arrows
-- Otherwise -> enable diamond arrows

local normalArrows = 3447      -- Normal arrows (for Trainers)
local diamondArrows = 25757    -- Diamond arrows (for everything else)
local ammoSlot = 5             -- Slot 5 = Right hand (ammo)

local panelName = "ArrowSwitch"

-- Main toggle panel
local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: switch
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    !text: tr('Arrow Switch')
]])
ui:setId(panelName)

-- Normal arrows indicator panel
local normalUi = setupUI([[
Panel
  height: 19

  BotSwitch
    id: normalSwitch
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    !text: tr('Normal Arrows')
]])
normalUi:setId(panelName .. "_normal")

-- Diamond arrows indicator panel
local diamondUi = setupUI([[
Panel
  height: 19

  BotSwitch
    id: diamondSwitch
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    !text: tr('Diamond Arrows')
]])
diamondUi:setId(panelName .. "_diamond")

if not storage[panelName] then
    storage[panelName] = {
        enabled = false
    }
end

local config = storage[panelName]

ui.switch:setOn(config.enabled)
ui.switch.onClick = function(widget)
    config.enabled = not config.enabled
    widget:setOn(config.enabled)
end

-- Disable manual clicking on arrow switches (they are indicators only)
normalUi.normalSwitch.onClick = function(widget)
    -- Do nothing, controlled by script
end
diamondUi.diamondSwitch.onClick = function(widget)
    -- Do nothing, controlled by script
end

-- Function to check if any nearby monster has "Trainer" in its name
local function hasTrainerNearby(range)
    if not range then range = 10 end
    for _, spec in pairs(getSpectators()) do
        if spec:isMonster() and (g_game.getClientVersion() < 960 or spec:getType() < 3) then
            local name = spec:getName():lower()
            if name:find("trainer") and distanceFromPlayer(spec:getPosition()) <= range then
                return true
            end
        end
    end
    return false
end

-- Function to get current ammo ID
local function getCurrentAmmoId()
    local item = getSlot(ammoSlot)
    if item then
        return item:getId()
    end
    return nil
end

-- Track last state
local lastState = nil

-- Main macro to handle arrow switching
macro(50, function()
    if not config.enabled then
        normalUi.normalSwitch:setOn(false)
        diamondUi.diamondSwitch:setOn(false)
        return
    end

    local trainerNearby = hasTrainerNearby(10)
    local currentAmmo = getCurrentAmmoId()

    if trainerNearby then
        -- Trainer nearby - use normal arrows
        normalUi.normalSwitch:setOn(true)
        diamondUi.diamondSwitch:setOn(false)

        if currentAmmo ~= normalArrows then
            if findItem(normalArrows) then
                g_game.move(findItem(normalArrows), {x=65535, y=ammoSlot, z=0}, findItem(normalArrows):getCount())
                delay(500)
            end
        end

        if lastState ~= "normal" then
            modules.game_textmessage.displayGameMessage("[ArrowSwitch] Trainer! NORMAL arrows")
            lastState = "normal"
        end
    else
        -- No trainer - use diamond arrows
        normalUi.normalSwitch:setOn(false)
        diamondUi.diamondSwitch:setOn(true)

        if currentAmmo ~= diamondArrows then
            if findItem(diamondArrows) then
                g_game.move(findItem(diamondArrows), {x=65535, y=ammoSlot, z=0}, findItem(diamondArrows):getCount())
                delay(500)
            end
        end

        if lastState ~= "diamond" then
            modules.game_textmessage.displayGameMessage("[ArrowSwitch] No trainer. DIAMOND arrows")
            lastState = "diamond"
        end
    end
end)

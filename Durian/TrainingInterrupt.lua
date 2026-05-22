--------------------------------- Training Interrupt Handler --------------------------------------------

-- Track the last time we attempted to use the training dummy
local lastUseTime = 0
local COOLDOWN = 3000 -- 3 second cooldown between uses

-- Track whether training is currently active
local isTrainingActive = false

-- Tracks when the last 5-minute check ran
local lastCheckTime = 0
local CHECK_INTERVAL = 30000 -- 30 seconds in milliseconds

-- Item IDs to scan nearby tiles for before starting training
local TRAINER_IDS = {29243, 31608}

-- Coordinates for the training dummy
local DUMMY_POS = {x = 5645, y = 5599, z = 6}

-- Returns true if any tile within range contains an item matching TRAINER_IDS
local function isTrainerNearby(range)
  range = range or 10
  local playerPos = player:getPosition()
  for dx = -range, range do
    for dy = -range, range do
      local tile = g_map.getTile({x = playerPos.x + dx, y = playerPos.y + dy, z = playerPos.z})
      if tile then
        for _, item in ipairs(tile:getItems()) do
          for _, id in ipairs(TRAINER_IDS) do
            if item:getId() == id then
              return true
            end
          end
        end
      end
    end
  end
  return false
end

-- Shared restart function used by all triggers
local function restartTraining(reason)
  local currentTime = now
  if currentTime - lastUseTime < COOLDOWN then return end
  lastUseTime = currentTime

  modules.game_textmessage.displayGameMessage(reason)

  schedule(1000, function()
    local item = g_game.findPlayerItem(34761, -1)
    if not item then
      modules.game_textmessage.displayGameMessage("Item 34761 not found in inventory")
      return
    end

    local tile = g_map.getTile(DUMMY_POS)
    if not tile then
      modules.game_textmessage.displayGameMessage("Training position not visible on map")
      return
    end

    local targetThing = tile:getTopUseThing()
    if not targetThing then
      modules.game_textmessage.displayGameMessage("No target at training position")
      return
    end

    g_game.useWith(item, targetThing)
    isTrainingActive = true
    modules.game_textmessage.displayGameMessage("Training restarted with item " .. item:getId())
  end)
end

-- Single macro linked to the icon.
-- Ticks every second but only runs the training check every 5 minutes.
local autoRetrain = macro(1000, function()
  local currentTime = now
  if currentTime - lastCheckTime < CHECK_INTERVAL then return end
  lastCheckTime = currentTime

  if not isTrainerNearby() then return end

  if isTrainingActive then return end

  restartTraining("Trainer nearby and training stopped - restarting...")
end)

-- Visual icon to activate/deactivate auto-retrain
addIcon("AutoRetrain", { item = { id = 34761, count = 1 }, text = "AutoRetrain" }, autoRetrain)

-- Run once shortly after script loads in case trainer is already nearby.
-- Bypasses the autoRetrain toggle so it always checks on load.
schedule(3000, function()
  if isTrainingActive then return end
  if not isTrainerNearby() then return end
  restartTraining("On-load: Trainer nearby - starting training...")
end)

-- Listen for server messages about training interruption
onTextMessage(function(mode, text)
  if autoRetrain:isOff() then return end

  -- Only process mode 18 messages
  if mode ~= 18 then return end

  local lowerText = text:lower()

  -- Training interrupted message
  if lowerText:find("training") and lowerText:find("interupted") then
    isTrainingActive = false
    if isTrainerNearby() then
      restartTraining("Training interrupted, restarting...")
    end
  end
end)

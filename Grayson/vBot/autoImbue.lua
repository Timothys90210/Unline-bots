-- === AUTO IMBUEMENT CONFIG ===
-- Global table for cavebot integration
if not AutoImbueTable then
  AutoImbueTable = {}
end

local autoImbue = {
  equipment = {
    [27735] = {"Void", "Vampirism", "Precision"}, -- Weapon
    --[52736] = {"Vampirism"}, -- Grand Falcon Grail
    [33164] = {"Void", "Precision"}, -- Helmet
    [22532] = {"Vampirism", "Dragon Hide"} -- Armor
  }
}

-- Populate global table for current character
if player then
  local playerName = player:getName()
  modules.game_textmessage.displayGameMessage("AutoImbue DEBUG: player exists, name = " .. playerName, 18)
  AutoImbueTable[playerName] = autoImbue.equipment
else
  modules.game_textmessage.displayGameMessage("AutoImbue DEBUG: player is nil, using defaultEquipment", 18)
  -- If player not available yet, store with a default key and populate later
  AutoImbueTable.defaultEquipment = autoImbue.equipment
end

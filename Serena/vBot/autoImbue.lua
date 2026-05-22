-- === AUTO IMBUEMENT CONFIG ===
-- Global table for cavebot integration
if not AutoImbueTable then
  AutoImbueTable = {}
end

local autoImbue = {
  equipment = {
    [27736] = {"Void", "Vampirism", "Strike"}, -- Emerald herald axe
    [29198] = {"Vampirism"}, -- Bone Fiddle
    [27373] = {"Void", "Chop"}, -- Falcon Coif
    [26703] = {"Vampirism", "Dragon Hide"} -- Earthheart Platemail
    --[26763] = {"Cloud Fabric"} -- Shield
  }
}

-- Populate global table for current character
AutoImbueTable[player:getName()] = autoImbue.equipment
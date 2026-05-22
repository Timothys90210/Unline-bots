-- === AUTO IMBUEMENT CONFIG ===
-- Global table for cavebot integration
if not AutoImbueTable then
  AutoImbueTable = {}
end

local autoImbue = {
  equipment = {
    [52477] = {"Void", "Vampirism", "Precision"}, -- Kraken Bow
    [52736] = {"Vampirism"}, -- Grand Falcon Grail
    [26701] = {"Void", "Precision"}, -- Falcon Coif
    [43157] = {"Vampirism", "Demon Presence", "Quara Scale"} -- Hellforged Plate
  }
}

-- Populate global table for current character
AutoImbueTable[player:getName()] = autoImbue.equipment

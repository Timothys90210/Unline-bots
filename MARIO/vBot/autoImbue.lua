-- === AUTO IMBUEMENT CONFIG ===
-- Global table for cavebot integration
if not AutoImbueTable then
  AutoImbueTable = {}
end

local autoImbue = {
  equipment = {
    [60038] = {"Void", "Vampirism", "Epiphany"}, -- Weapon
    [52826] = {"Void"}, -- Arrow slot
    [52700] = {"Void", "Epiphany"}, -- Helmet
    [27390] = {"Vampirism", "Lich Shroud"} -- Armor
    --[33161] = {"Quara Scale"} -- Shield
  }
}

-- Populate global table for current character
AutoImbueTable[player:getName()] = autoImbue.equipment

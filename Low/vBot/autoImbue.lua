-- === AUTO IMBUEMENT CONFIG ===
-- Global table for cavebot integration
if not AutoImbueTable then
  AutoImbueTable = {}
end

local autoImbue = {
  equipment = {
    [26736] = {"Void", "Vampirism", "Precision"}, -- Weapon
    [52835] = {"Void"}, -- Arrow slot
    [52766] = {"Void", "Precision"}, -- Helmet
    [52697] = {"Vampirism", "Quara Scale"}, -- Armor
    [33161] = {"Quara Scale"} -- Shield
  }
}

-- Populate global table for current character
AutoImbueTable[player:getName()] = autoImbue.equipment

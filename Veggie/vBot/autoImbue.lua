-- === AUTO IMBUEMENT CONFIG ===
-- Global table for cavebot integration
if not AutoImbueTable then
  AutoImbueTable = {}
end

local autoImbue = {
  equipment = {
    [27682] = {"Void", "Vampirism", "Epiphany"}, -- Weapon
    [10227] = {"Void"}, -- Arrow slot
    [52766] = {"Void", "Epiphany"}, -- Helmet
    [52818] = {"Vampirism", "Dragon Hide"}, -- Armor
    [33161] = {"Quara Scale"} -- Shield
  }
}

-- Populate global table for current character
AutoImbueTable[player:getName()] = autoImbue.equipment

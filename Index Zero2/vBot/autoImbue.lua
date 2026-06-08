-- === AUTO IMBUEMENT CONFIG ===
-- Global table for cavebot integration
if not AutoImbueTable then
  AutoImbueTable = {}
end

local autoImbue = {
  equipment = {
    [27480] = {"Void", "Vampirism", "Strike"}, -- Weapon
    -- [33164] = {"Vampirism"}, -- Doll
    [33164] = {"Void", "Precision"}, -- Helmet
    [8060] = {"Vampirism", "Snake Skin"} -- Armor
  }
}

-- Populate global table for current character
AutoImbueTable[player:getName()] = autoImbue.equipment

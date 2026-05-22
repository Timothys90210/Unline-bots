setDefaultTab("Tools")
local mkPanelname = "monsterKill"
if not storage[mkPanelname] then storage[mkPanelname] = { min = false } end

UI.Label("Prey Slots")
preySlotOne = "slotOne"
if not storage[preySlotOne] then storage[preySlotOne] = { player = 'name'} end
preySlotTwo = "slotTwo"
if not storage[preySlotTwo] then storage[preySlotTwo] = { player = 'name'} end
preySlotThree = "slotThree"
if not storage[preySlotThree] then storage[preySlotThree] = { player = 'name'} end

slotOne = UI.TextEdit(storage[preySlotOne].player or "name", function(widget, newText)
    storage[preySlotOne].player = newText
end)
slotTwo = UI.TextEdit(storage[preySlotTwo].player or "name", function(widget, newText2)
    storage[preySlotTwo].player = newText2
end)
slotThree = UI.TextEdit(storage[preySlotThree].player or "name", function(widget, newText3)
    storage[preySlotThree].player = newText3
end)

-- XP Bonus | Damage Boost | Damage Reduction | Improved Loot | any
local desiredState = {
    "any", -- first slot
    "any", -- second slot
    "any"  -- third slot
}
local monsters = {
    storage[preySlotOne].player,        -- first slot
    storage[preySlotTwo].player,        -- second slot
    storage[preySlotThree].player  		-- third slot
}

local minTime = 5       -- reset at % - out of 2h! 
local rollsLimit = 500  -- just in case, rolls limit

local rollBonus = true   -- roll prey bonus
local rollMonster = true  -- roll prey creature

local function isempty(s)
  return s == nil or s == ''
end

-- do not edit below
local currentRolls = 1
local bonusRegex = "Type: (XP Bonus|Damage Boost|Damage Reduction|Improved Loot)"
macro(200, "Lock Preys", function()
	
    local tracker = modules.game_prey.preyTracker
    local window = modules.game_prey.preyWindow

    for i, slot in ipairs({"slot1", "slot2", "slot3"}) do
        local trackerSlot = tracker.contentsPanel[slot]
        local windowSlot = window[slot]
        local time = trackerSlot.time:getPercent() -- time left
        local data = trackerSlot.creature:getTooltip() -- bonus type & creature will be exctracted from this one
        local bonusType = regexMatch(data, bonusRegex)
        local creature = windowSlot.title:getText():lower()
        local canChoosePrey = creature:lower() == "select monster"
        bonusType = bonusType and bonusType[1] and bonusType[1][2] -- bonus type
    
        -- creature reroll conditions
        if rollMonster and currentRolls < rollsLimit then
            -- prey is active but wrong monster is selected
			
			if not table.find(monsters, creature, true) and not canChoosePrey then
			
				if creature == "locked" then
					print(creature)
					return true
				else				
					print("Rerolling monster: "..creature..". Not found in monsters table.")
					return g_game.preyAction(i-1, 0, 0)
				end
            -- prey is inactive
            elseif not table.find(monsters, creature, true) and canChoosePrey then
                -- search current list for monster
                for j, child in ipairs(windowSlot.inactive.list:getChildren()) do
                    local name = child:getTooltip():lower()
					
                    if table.find(monsters, name, true) then
                        -- success
                        print("Found creature: "..name.." in "..slot.."!")
                        currentRolls = 1
                        return g_game.preyAction(i-1, 2, j - 1)
                    end																
                end
                print("Unfortunately not found. Rerolling "..slot.. " tries: ".. currentRolls.."/"..rollsLimit)
                currentRolls = currentRolls + 1
                return g_game.preyAction(i-1, 0, 0)
            end
        end

        -- bonus reroll conditions
        if rollBonus then
            if time > 0 and ((desiredState[i] == "any" and time < minTime) or ((desiredState[i] ~= "any" and bonusType ~= desiredState[i]) or time < minTime)) then
                print("Prey Reroller: rolled slot: "..i..", previously type: "..bonusType.." and time: ".. time.."%")
                return g_game.preyAction(i-1, 0, 0)
            end
        end
    end
end)

UI.Separator()

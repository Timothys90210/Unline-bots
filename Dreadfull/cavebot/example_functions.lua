CaveBot.Editor.ExampleFunctions = {}

local function addExampleFunction(title, text)
  return table.insert(CaveBot.Editor.ExampleFunctions, {title, text:trim()})
end

addExampleFunction("Click to browse example functions", [[

return true
]])

addExampleFunction("Check for PZ and wait until dropped", [[
if not hasSwords() then
  return true
else
  if isPoisioned() then
      say("exana pox")
  end
  if hasSwords() then
      delay(8000)
  end
  return "retry"
end
]])

addExampleFunction("Check for stamina less then 2340", [[
if stamina() < 2340 then 
	CaveBot.gotoLabel("staminaRefill")  
	return false 
else 
	return true 
end
]])

addExampleFunction("Remove Left Weapon", [[
g_game.move(getLeft(), {x=65535, y=SlotBack, z=0},1)
return true
]])

addExampleFunction("Remove Both Weapons (Ninja)", [[
g_game.move(getRight(), {x=65535, y=SlotBack, z=0},1)
g_game.move(getLeft(), {x=65535, y=SlotBack, z=0},1)
return true
]])

addExampleFunction("Imbui Close Window", [[
modules.game_imbuing.hide()
return true
]])

addExampleFunction("Disable TargetBot", [[
TargetBot.setOff()
return true
]])

addExampleFunction("Enable TargetBot", [[
TargetBot.setOn()
return true
]])

addExampleFunction("Disable CaveBot", [[
CaveBot.setOff()
return true
]])

addExampleFunction("Enable CaveBot", [[
CaveBot.setOn()
return true
]])

addExampleFunction("Logout", [[
g_game.safeLogout()
delay(1000)
return "retry"
]])

addExampleFunction("Close Loot Containers", [[
CaveBot.CloseAllLootContainers()
delay(3000)
return true
]])
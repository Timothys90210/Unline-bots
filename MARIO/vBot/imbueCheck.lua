UI.Separator()
function checkWep()
  local weapon = getLeft()
  if weapon then
    check = true
     g_game.look(weapon)
  end
end
checkWep()

function getImbuementTime(imbuData, imbuName)
  local timePattern = imbuName .. " (%d+:%d+h)"
  local time = imbuData:match(timePattern)
  return time
end

ImbueCheck = macro(1000, "Check Imbue", function()
    checkWep()
end)

onTextMessage(function(mode, text)
  if ImbueCheck:isOff() then return end
  if not check then return end
  if not text:find("Imbuements: %(([^)]*)%)%.") then return end
  local imbuData = text:match("Imbuements: %(([^)]*)%)")
  local imbuEmpty = text:match("Empty Slot")
  if imbuEmpty == "Empty Slot" then
		CaveBot.gotoLabel("supplyRefill")
		ImbueCheck:setOff()
  else
	  if imbuData then
		local imbuNames = { "Powerful Vampirism", "Powerful Void", "Powerful Strike" }
		for _, imbuName in ipairs(imbuNames) do
		  local time = getImbuementTime(imbuData, imbuName)
		  if time then
			local hours, minutes = time:match("(%d+):(%d+)h")
			if hours and minutes then
			  hours = tonumber(hours)
			  minutes = tonumber(minutes)
			  if hours < 1 and minutes <= 59 then -- Modificamos la condición para que solo active la alarma cuando las horas sean 0 y los minutos sean menores a 59
				CaveBot.gotoLabel("supplyRefill")
				ImbueCheck:setOff()
			  else
				ImbueCheck:setOff()
			  end
			end
		  end
		end
	  end  
  end
  check = false
end)

UI.Separator()


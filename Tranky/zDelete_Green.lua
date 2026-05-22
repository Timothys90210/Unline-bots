setDefaultTab("Main")
UI.Separator()

local clearMacro = macro(1000, "Delete Message", function() end)

onTextMessage(function(mode, text)
  if clearMacro.isOff() then 
    return 
  end

  -- Si contiene "Loot of" o "Using one of", 
  if text:find("Loot of") or text:find("Using one of") then
    modules.game_textmessage.clearMessages()
  end
end)
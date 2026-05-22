setDefaultTab("Main")
UI.Separator()

macro(1500, "Manatrain",  function()
  if (hppercent() > 50) then
  say(storage.ManatrainText)
end
end)
addTextEdit("ManatrainText", storage.ManatrainText or "Exevo Utamo", function(widget, text) 
storage.ManatrainText = text
end)
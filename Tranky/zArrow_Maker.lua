setDefaultTab("Main")
UI.Separator()

UI.Label("-- Arrow creation -------")

UI.Label("Arrow id:")
UI.TextEdit(storage.ArrowId or 3447, function(widget, newText)
  storage.ArrowId = newText
end)
UI.Label("Arrow spell:")
UI.TextEdit(storage.ArrowSpell or "exevo con", function(widget, newText)
  storage.ArrowSpell = newText
end)
UI.Label("Arrow min Qty:")
UI.TextEdit(storage.ArrowQty or 100, function(widget, newText)
  storage.ArrowQty = newText
end)
macro(500, "Create Arrows", function()
     if player:getItemsCount(tonumber(storage.ArrowId)) < tonumber(storage.ArrowQty) then
       say(storage.ArrowSpell)
   return
   end
end)
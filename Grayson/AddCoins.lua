setDefaultTab("Tools")
UI.Button("Add Coins (item 22118)", function()
  local lp = g_game.getLocalPlayer()
  if not lp then return end
  local item = lp:getInventoryItem(0)
  -- server-side action triggers when item 22118 is used in-game
  g_game.useInventoryItem(22118)
end)

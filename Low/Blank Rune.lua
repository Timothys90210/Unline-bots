local config = {
  item = {
    id = 3147,
    minQty = 5
  },

  pos = {x=0000, y=0000, z=0}
}

macro(200, "Blank rune", function()
  local qty = player:getItemsCount(config.item.id)
  if manapercent() > 60 and qty < config.item.minQty then
	say("adori blank")
  end
end)
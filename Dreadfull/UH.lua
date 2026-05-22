local config = {
  item = {
    id = 52813,
    minQty = 500
  },

  pos = {x=0000, y=0000, z=0}
}

macro(200, "UHS", function()
  local qty = player:getItemsCount(config.item.id)
  if manapercent() > 60 and qty < config.item.minQty then
	say("adura vita")
  end
end)
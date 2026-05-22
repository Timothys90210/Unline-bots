local config = {
  item = {
    id = 52813,
    minQty = 300
  },

  pos = {x=0000, y=0000, z=0}
}

macro(200, "UHs", function()
  local qty = player:getItemsCount(config.item.id)
  if manapercent() > 90 and qty < config.item.minQty then
	say("adura vita")
  end
end)
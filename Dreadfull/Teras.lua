local config = {
  item = {
    id = 52820,
    minQty = 10
  },

  pos = {x=0000, y=0000, z=0}
}

macro(200, "Teras", function()
  local qty = player:getItemsCount(config.item.id)
  if manapercent() > 60 and qty < config.item.minQty then
	say("adori mas tera")
  end
end)
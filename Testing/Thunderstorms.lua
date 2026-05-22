local config = {
  item = {
    id = 52811,
    minQty = 300
  },

  pos = {x=0000, y=0000, z=0}
}

macro(200, "Thunderstorm runes", function()
  local qty = player:getItemsCount(config.item.id)
  if manapercent() > 60 and qty < config.item.minQty then
	say("adori mas vis")
  end
end)
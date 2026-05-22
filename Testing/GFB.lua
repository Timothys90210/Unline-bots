local config = {
  item = {
    id = 52763,
    minQty = 300
  },

  pos = {x=0000, y=0000, z=0}
}

macro(200, "GFB runes", function()
  local qty = player:getItemsCount(config.item.id)
  if manapercent() > 95 and qty < config.item.minQty then
	say("adori mas flam")
  end
end)
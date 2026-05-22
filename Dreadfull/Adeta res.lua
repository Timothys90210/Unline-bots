local config = {
  spell = "adeta res",
  onlyAttacking = true
}

addIcon("buffIcon", {item={id=3288, count=1}, text=config.spell}, macro(100, function(m)
  if (not config.onlyAttacking or g_game.isAttacking()) then
    say(config.spell)
    delay(10000)
  end
end))
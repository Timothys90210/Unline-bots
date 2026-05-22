local resetCursorIcon = nil

resetCursorIcon = addIcon("resetCursorIcon", {item={id=5031, count=1}, text="Reset Cursor", hotkey = "Shift+C"}, macro(500, function(m)
  g_mouse.popCursor('target')
  m.setOff()
  schedule(50, function()
    resetCursorIcon.text:setColor("yellow")
  end)
  modules.game_textmessage.displayGameMessage("Cursor reseted :)")
end))

resetCursorIcon.text:setColor("yellow")


--Join Discord server for free scripts
--https://discord.gg/RkQ9nyPMBH
--Made By VivoDibra
--Tested on vBot 4.8 / OTCV8 3.2 rev 4
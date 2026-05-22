macro(250, "Sio Friends", function()
  local healPercent = 80
  local minMyHp = 80
  local minMyMana = 30
  local friends = storage.playerList and storage.playerList.friendList or {}

  if hppercent() > minMyHp and manapercent() > minMyMana then
    for _, spec in pairs(getSpectators()) do
      if table.find(friends, spec:getName()) and spec:getHealthPercent() < healPercent then
        say('exura sio "' .. spec:getName())
        break
      end
    end
  end
end)
local friendList = {"Urgot", "Arrowzerinho", "Kawasick", "Lord Voldemort"}
local healPercent = 80
local minMyHp = 80
local minMyMana = 30

macro(250, "Auto Exura Sio Friends", function()
  if hppercent() > minMyHp and manapercent() > minMyMana then
    for _, spec in pairs(getSpectators()) do
      if table.find(friendList, spec:getName()) and spec:getHealthPercent() < healPercent then
        say("exura sio \"" .. spec:getName())
        break
      end
    end
  end
end)
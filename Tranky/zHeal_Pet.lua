setDefaultTab("Hp")
UI.Separator()

macro(100, "Uh Pet", nil, function()
  local healFriend = getCreatureByName(storage.uhFriend)
  if healFriend then
    local heal_player = healFriend:getName();
    if (heal_player == storage.uhFriend) then
      if (healFriend:getHealthPercent() < tonumber(storage.uhFriendPercent)) then
        useWith(3160, healFriend);
      end
    end
  end
end)


addLabel("uhname", "Name Pet:", warTab)
addTextEdit("uhfriend", storage.uhFriend or "", function(widget, text)
  storage.uhFriend = text
end)
addLabel("uhpercent", "Heal Below %:", warTab)
addTextEdit("uhfriendpercent", storage.uhFriendPercent or "", function(widget, text)
  storage.uhFriendPercent = text
end)
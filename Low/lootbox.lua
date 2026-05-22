--[[
  +---------------------------------------------------------------+
  ¦   Script by Lee (Discord: l33_)                               ¦
  ¦   URL: https://www.trainorcreations.com/coding/otclient/114   ¦
  ¦---------------------------------------------------------------¦
  ¦   Website: https://trainorcreations.com/                       ¦
  ¦   Donate: https://trainorcreations.com/donate                 ¦
  ¦   Discord: https://trainorcreations.com/discord               ¦
  ¦---------------------------------------------------------------¦
  ¦   PS: Stop ripping off my work and selling it.                ¦
  +---------------------------------------------------------------+
]]--
local useLoot = macro(100000, "Loot Channel", function() end)
local tabName = "Loot"
local console = modules.game_console

onTextMessage(function(mode, text)
  if mode ~= 29 then return end
  if useLoot.isOff() then return end
  if not text:find("Loot of") then return end

  local tab = console.getTab(tabName) or console.addTab(tabName, true)
  console.addText(text, { color = '#00EB00' }, tabName, "")
end)
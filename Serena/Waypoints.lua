setDefaultTab("Main")

 teleportWindow = setupUI([[
Panel
  id: teleportWin
  title: "Teleport Control"
  width: 150
  height: 70
  color: #00000055
  
  Label
    text: "City ID:"
    anchors.top: parent.top
    anchors.left: parent.left
    margin-top: 5
  
  BotTextEdit
    id: cityId
    anchors.top: parent.top
    anchors.right: parent.right
    width: 20
    height: 20
    margin-top: 5
    margin-right: 5

  Label
    text: "Waypoint ID:"
    anchors.top: cityId.bottom
    anchors.left: parent.left
    margin-top: 5
  
  BotTextEdit
    id: waypointId
    anchors.top: cityId.bottom
    anchors.right: parent.right
    width: 20
    height: 20
    margin-top: 5
    margin-right: 5

  Button
    id: teleportBtn
    text: "Activate Waypoint"
    anchors.top: waypointId.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: 120
    height: 15
    margin-top: 10
]])

-- Initialize fields from storage
teleportWindow.cityId:setText(storage.teleportCity or "1")
teleportWindow.waypointId:setText(storage.teleportWaypoint or "1")

-- Add real-time storage updates
teleportWindow.cityId.onTextChange = function(widget, text)
  storage.teleportCity = text
end

teleportWindow.waypointId.onTextChange = function(widget, text)
  storage.teleportWaypoint = text
end

-- Store original position for verification
 originalPos = nil

teleportWindow.teleportBtn.onClick = function()
   city = tonumber(teleportWindow.cityId:getText()) or 1
   waypoint = tonumber(teleportWindow.waypointId:getText()) or 1
  originalPos = pos()

   protocol = g_game.getProtocolGame()
  if protocol then
     data = string.format(
      '{"mapIndex":%d,"nodeIndex":%d,"topic":"travel"}', 
      city, 
      waypoint
    )
    protocol:sendExtendedOpcode(215, data)
    print("[Teleport] Sent request to City:", city, "Waypoint:", waypoint)
  end
end

function teleportAction()
  if not originalPos then
    teleportWindow.teleportBtn.onClick()
    return "retry"
  end

  if pos() ~= originalPos then
    originalPos = nil
    return true
  end

  if cavebot.getRetryCount() > 5 then
    warn("Teleport timeout - position unchanged")
    originalPos = nil
    return false
  end

  return "retry"
end
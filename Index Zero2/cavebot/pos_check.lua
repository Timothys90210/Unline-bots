CaveBot.Extensions.PosCheck = {}

local posCheckRetries = 0
CaveBot.Extensions.PosCheck.setup = function()
  CaveBot.registerAction("PosCheck", "#00FFFF", function(value, retries)
    local tilePos
    local data = string.split(value, ",")
    if #data ~= 5 then
     warn("wrong travel format, should be: label, distance, x, y, z")
     return false
    end

    local tilePos = player:getPosition()

    tilePos.x = tonumber(data[3])
    tilePos.y = tonumber(data[4])
    tilePos.z = tonumber(data[5])

    if posCheckRetries > 10 then
        posCheckRetries = 0
        print("CaveBot[CheckPos]: waypoints locked, too many tries, unclogging cavebot and proceeding")
        return false
    elseif (tilePos.z == player:getPosition().z) and (getDistanceBetween(player:getPosition(), tilePos) <= tonumber(data[2])) then
        posCheckRetries = 0
        print("CaveBot[CheckPos]: position reached, proceeding")
        return true
    else
        posCheckRetries = posCheckRetries + 1
        if data[1] == "last" then
          CaveBot.gotoFirstPreviousReachableWaypoint()
          print("CaveBot[CheckPos]: position not-reached, going back to first reachable waypoint.")
          return false
        else
          CaveBot.gotoLabel(data[1])
          print("CaveBot[CheckPos]: position not-reached, going back to label: " .. data[1])
          return false
        end
    end
  end)

  -- Mount / Dismount action. Registered here, immediately before the "pos check"
  -- editor button, so the "Mount" button renders directly to the LEFT of "pos check"
  -- (editor buttons appear in registration order; extensions otherwise load in a
  -- non-deterministic pairs() order, so hosting it here is the reliable way to pin it).
  CaveBot.registerAction("mount", "#FFA500", function(value, retries)
    local wantDismount = tostring(value):lower():find("dismount") ~= nil
    local mounted = player:isMounted()
    if wantDismount and not mounted then return true end   -- already dismounted
    if not wantDismount and mounted then return true end    -- already mounted
    if retries >= 20 then return true end                   -- ~2s elapsed; proceed, never clog the route
    if retries % 5 == 0 then                                -- (re)issue the command every ~500ms
      if wantDismount then player:dismount() else player:mount() end
    end
    delay(100)
    return "retry"
  end)

  CaveBot.Editor.registerAction("mount", "Mount", {
    value="mount",
    title="Mount / Dismount",
    description="Type 'mount' to mount, or 'dismount' to dismount",
    multiline=false,
  })

  CaveBot.Editor.registerAction("poscheck", "pos check", {
    value=function() return "last" .. "," .. "10" .. "," .. posx() .. "," .. posy() .. "," .. posz() end,
    title="Location Check",
    description="label name, accepted dist from coordinates, x, y, z",
    multiline=false,
})
end
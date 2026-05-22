setDefaultTab("Hunt")

addLabel("Label", "Leader Name")
addTextEdit("TxtEdit", storage.backupLeaderName or "Name", function(widget, text)
    storage.backupLeaderName = text
end)

macro(100, "Back up ladder", function()
    local leaderName = storage.backupLeaderName or ""
    if leaderName == "" or leaderName == "Name" then return end

    local leader = getCreatureByName(leaderName)
    if not leader then
        if not CaveBot.isOn() then
            CaveBot.setOn()
        end
    else
        if CaveBot.isOn() then
            CaveBot.setOff()
        end
    end
end)

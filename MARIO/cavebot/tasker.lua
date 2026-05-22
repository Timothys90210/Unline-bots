CaveBot.Extensions.Tasker = {}

local dataValidationFailed = function()
    print("CaveBot[Tasker]: data validation failed! incorrect data, check cavebot/tasker for more info")
    return false
end

-- miniconfig
local talkDelay = storage.extras.talkDelay
if not storage.caveBotTasker then
    storage.caveBotTasker = {
        inProgress = false,
        monster = "",
        taskName = "",
        count = 0,
        max = 0
    }
end

local resetTaskData = function()
    storage.caveBotTasker.inProgress = false
    storage.caveBotTasker.monster = ""
    storage.caveBotTasker.monster2 = ""
    storage.caveBotTasker.monster3 = ""
    storage.caveBotTasker.monster4 = ""
    storage.caveBotTasker.monster5 = ""
    storage.caveBotTasker.taskName = ""
    storage.caveBotTasker.count = 0
    storage.caveBotTasker.max = 0
end

local resetTaskData2 = function()
    storage.caveBotTasker.inProgress2 = false
    storage.caveBotTasker.monster6 = ""
    storage.caveBotTasker.monster7 = ""
    storage.caveBotTasker.monster8 = ""
    storage.caveBotTasker.monster9 = ""
    storage.caveBotTasker.monster10 = ""
    storage.caveBotTasker.taskName2 = ""
    storage.caveBotTasker.count2 = 0
    storage.caveBotTasker.max2 = 0
	
	
end

local resetTaskData3 = function()
    storage.caveBotTasker.inProgress3 = false
    storage.caveBotTasker.monster11 = ""
    storage.caveBotTasker.monster12 = ""
    storage.caveBotTasker.monster13 = ""
    storage.caveBotTasker.monster14 = ""
    storage.caveBotTasker.monster15 = ""
    storage.caveBotTasker.taskName3 = ""
    storage.caveBotTasker.count3 = 0
    storage.caveBotTasker.max3 = 0
	
	
end

local resetTaskData4 = function()
    storage.caveBotTasker.inProgress4 = false
    storage.caveBotTasker.monster16 = ""
    storage.caveBotTasker.monster17 = ""
    storage.caveBotTasker.monster18 = ""
    storage.caveBotTasker.monster19 = ""
    storage.caveBotTasker.monster20 = ""
    storage.caveBotTasker.taskName4 = ""
    storage.caveBotTasker.count4 = 0
    storage.caveBotTasker.max4 = 0
	
	
end

CaveBot.Extensions.Tasker.setup = function()
  CaveBot.registerAction("Tasker", "#FF0090", function(value, retries)
    local taskName = ""
    local monster = ""
    local monster2 = ""
	local monster3 = ""
    local monster4 = ""
    local monster5 = ""
    local count = 0
    local label1 = ""
    local label2 = ""
    local task
	
	local taskName2 = ""
    local monster6 = ""
    local monster7 = ""    
	local monster8 = ""
    local monster9 = ""
    local monster10 = ""
    local count2 = 0
    local label3 = ""
    local label4 = ""
    local task1
	
	local taskName3 = ""
    local monster11 = ""
    local monster12 = ""    
	local monster13 = ""
    local monster14 = ""
    local monster15 = ""
    local count3 = 0
    local label5 = ""
    local label6 = ""
    local task2	
	
	local taskName4 = ""
    local monster16 = ""
    local monster17 = ""    
	local monster18 = ""
    local monster19 = ""
    local monster20 = ""
    local count4 = 0
    local label7 = ""
    local label8 = ""
    local task3

    local data = string.split(value, ",")
    if not data or #data < 1 then
        dataValidationFailed()
    end
    local marker = tonumber(data[1])

    if not marker then
        dataValidationFailed()
        resetTaskData()
    elseif marker == 1 then
        if getNpcs(3) == 0 then
            print("CaveBot[Tasker]: no NPC found in range! skipping")
            return false
        end
		
        if #data ~= 4 and #data ~= 5 and #data ~= 6 and #data ~= 7 and #data ~= 8 then
            dataValidationFailed()
            resetTaskData()
        else
            taskName = data[2]:lower():trim()
            count = tonumber(data[3]:trim())
            monster = data[4]:lower():trim()
            if #data == 5 then
                monster2 = data[5]:lower():trim()
            elseif #data == 6 then
                monster3 = data[6]:lower():trim()
            elseif #data == 7 then
                monster4 = data[7]:lower():trim()
            elseif #data == 8 then
                monster5 = data[8]:lower():trim()
            end
        end
    elseif marker == 2 then
        if #data ~= 3 then
            dataValidationFailed()
        else
            label1 = data[2]:lower():trim()
            label2 = data[3]:lower():trim()
        end
    elseif marker == 3 then
        if getNpcs(3) == 0 then
            print("CaveBot[Tasker]: no NPC found in range! skipping")
            return false
        end
        if #data ~= 1 then
            dataValidationFailed()
        end
    elseif marker == 4 then
        if getNpcs(3) == 0 then
            print("CaveBot[Tasker]: no NPC found in range! skipping")
            return false
        end
        if #data ~= 4 and #data ~= 5 and #data ~= 6 and #data ~= 7 and #data ~= 8 then
            dataValidationFailed()
            resetTaskData2()
        else
            taskName2 = data[2]:lower():trim()
            count2 = tonumber(data[3]:trim())
            monster6 = data[4]:lower():trim()
            if #data == 5 then
                monster7 = data[5]:lower():trim()
            elseif #data == 6 then
                monster8 = data[6]:lower():trim()
            elseif #data == 7 then
                monster9 = data[7]:lower():trim()
            elseif #data == 8 then
                monster10 = data[8]:lower():trim()
            end
        end
    elseif marker == 5 then
        if #data ~= 3 then
            dataValidationFailed()
        else
            label3 = data[2]:lower():trim()
            label4 = data[3]:lower():trim()
        end
    elseif marker == 6 then
        if getNpcs(3) == 0 then
            print("CaveBot[Tasker]: no NPC found in range! skipping")
            return false
        end
        if #data ~= 1 then
            dataValidationFailed()
        end
		
	elseif marker == 7 then
         if getNpcs(3) == 0 then
                print("CaveBot[Tasker]: no NPC found in range! skipping")
                return false
            end

            if #data ~= 4 and #data ~= 5 and #data ~= 6 and #data ~= 7 and #data ~= 8 then
                dataValidationFailed()
                resetTaskData3()
            else
                taskName3 = data[2]:lower():trim()
                count3 = tonumber(data[3]:trim())
                monster11 = data[4]:lower():trim()
                if #data == 5 then
                    monster12 = data[5]:lower():trim()
                elseif #data == 6 then
                    monster13 = data[6]:lower():trim()
                elseif #data == 7 then
                    monster14 = data[7]:lower():trim()
                elseif #data == 8 then
                    monster15 = data[8]:lower():trim()
                end
            end
    elseif marker == 8 then
        if #data ~= 3 then
            dataValidationFailed()
        else
            label5 = data[2]:lower():trim()
            label6 = data[3]:lower():trim()
        end
    elseif marker == 9 then
        if getNpcs(3) == 0 then
            print("CaveBot[Tasker]: no NPC found in range! skipping")
            return false
        end
        if #data ~= 1 then
            dataValidationFailed()
        end
	elseif marker == 10 then
         if #data ~= 4 and #data ~= 5 and #data ~= 6 and #data ~= 7 and #data ~= 8 then
            dataValidationFailed()
            resetTaskData()
        else
            taskName = data[2]:lower():trim()
            count = tonumber(data[3]:trim())
            monster = data[4]:lower():trim()
            if #data == 5 then
                monster2 = data[5]:lower():trim()
            elseif #data == 6 then
                monster3 = data[6]:lower():trim()
            elseif #data == 7 then
                monster4 = data[7]:lower():trim()
            elseif #data == 8 then
                monster5 = data[8]:lower():trim()
            end
        end
    elseif marker == 11 then
			if #data ~= 4 and #data ~= 5 and #data ~= 6 and #data ~= 7 and #data ~= 8 then
				dataValidationFailed()
				resetTaskData2()
			else
				taskName2 = data[2]:lower():trim()
				count2 = tonumber(data[3]:trim())
				monster6 = data[4]:lower():trim()
				if #data == 5 then
					monster7 = data[5]:lower():trim()
				elseif #data == 6 then
					monster8 = data[6]:lower():trim()
				elseif #data == 7 then
					monster9 = data[7]:lower():trim()
				elseif #data == 8 then
					monster10 = data[8]:lower():trim()
				end
			end
    elseif marker == 12 then
            if #data ~= 4 and #data ~= 5 and #data ~= 6 and #data ~= 7 and #data ~= 8 then
                dataValidationFailed()
                resetTaskData3()
            else
                taskName3 = data[2]:lower():trim()
                count3 = tonumber(data[3]:trim())
                monster11 = data[4]:lower():trim()
                if #data == 5 then
                    monster12 = data[5]:lower():trim()
                elseif #data == 6 then
                    monster13 = data[6]:lower():trim()
                elseif #data == 7 then
                    monster14 = data[7]:lower():trim()
                elseif #data == 8 then
                    monster15 = data[8]:lower():trim()
                end
            end
    end
    
    -- let's cover markers now
    if marker == 1 then -- starting task
        CaveBot.Conversation("hi", "task", taskName, "yes")
        delay(talkDelay*4)

        storage.caveBotTasker.monster = monster
        if monster2 then storage.caveBotTasker.monster2 = monster2 end
        if monster3 then storage.caveBotTasker.monster3 = monster3 end
        if monster4 then storage.caveBotTasker.monster4 = monster4 end
        if monster5 then storage.caveBotTasker.monster5 = monster5 end
        storage.caveBotTasker.taskName = taskName
        storage.caveBotTasker.inProgress = true
        storage.caveBotTasker.max = count
        storage.caveBotTasker.count = 0

        print("CaveBot[Tasker]: taken task for: " .. taskName .. " x" .. count)
        return true
    elseif marker == 2 then -- only checking
        if not storage.caveBotTasker.inProgress then
            CaveBot.gotoLabel(label2)
            print("CaveBot[Tasker]: there is no task in progress so going to take one.")
            return true
        end

        local max = storage.caveBotTasker.max
        local count = storage.caveBotTasker.count

        if count >= max then
            CaveBot.gotoLabel(label2)
            print("CaveBot[Tasker]: task completed: " .. storage.caveBotTasker.taskName)
            return true
        else
            CaveBot.gotoLabel(label1)
            print("Task in progress '" .. storage.caveBotTasker.taskName .. "': " .. count .. "/" .. max)

            return true
        end


    elseif marker == 3 then -- reporting task
        CaveBot.Conversation("hi", "report", "task")
        delay(talkDelay*3)

        print("CaveBot[Tasker]: Task " .. storage.caveBotTasker.taskName .. " reported, done")
		resetTaskData()
        return true
    elseif marker == 4 then -- starting task
        CaveBot.Conversation("hi", "task", taskName2, "yes")
        delay(talkDelay*4)

        storage.caveBotTasker.monster6 = monster6
        if monster7 then storage.caveBotTasker.monster7 = monster7 end
        if monster8 then storage.caveBotTasker.monster8 = monster8 end
        if monster9 then storage.caveBotTasker.monster9 = monster9 end
        if monster10 then storage.caveBotTasker.monster10 = monster10 end
        storage.caveBotTasker.taskName2 = taskName2
        storage.caveBotTasker.inProgress2 = true
        storage.caveBotTasker.max2 = count2
        storage.caveBotTasker.count2 = 0

        print("CaveBot[Tasker]: taken task for: " .. taskName2 .. " x" .. count2)
        return true
    elseif marker == 5 then -- only checking
        if not storage.caveBotTasker.inProgress2 then
            CaveBot.gotoLabel(label4)
            print("CaveBot[Tasker]: there is no task in progress so going to take one.")
            return true
        end

        local max2 = storage.caveBotTasker.max2
        local count2 = storage.caveBotTasker.count2

        if count2 >= max2 then
            CaveBot.gotoLabel(label4)
            print("CaveBot[Tasker]: task completed: " .. storage.caveBotTasker.taskName2)
            return true
        else
            CaveBot.gotoLabel(label3)
            print("Task in progress '" .. storage.caveBotTasker.taskName2 .. "': " .. count2 .. "/" .. max2)
            return true
        end


    elseif marker == 6 then -- reporting task
        CaveBot.Conversation("hi", "report", "task")
        delay(talkDelay*3)
        
        print("CaveBot[Tasker]: Task " .. storage.caveBotTasker.taskName2 .. " reported, done")
		resetTaskData2()
        return true
		
	elseif marker == 7 then -- starting task
        CaveBot.Conversation("hi", "task", taskName3, "yes")
        delay(talkDelay*4)

        storage.caveBotTasker.monster11 = monster11
        if monster12 then storage.caveBotTasker.monster12 = monster12 end
        if monster13 then storage.caveBotTasker.monster13 = monster13 end
        if monster14 then storage.caveBotTasker.monster14 = monster14 end
        if monster15 then storage.caveBotTasker.monster15 = monster15 end
        storage.caveBotTasker.taskName3 = taskName3
        storage.caveBotTasker.inProgress3 = true
        storage.caveBotTasker.max3 = count3
        storage.caveBotTasker.count3 = 0

        print("CaveBot[Tasker]: taken task for: " .. taskName3 .. " x" .. count3)
        return true
    elseif marker == 8 then -- only checking
        if not storage.caveBotTasker.inProgress3 then
            CaveBot.gotoLabel(label6)
            print("CaveBot[Tasker]: there is no task in progress so going to take one.")
            return true
        end

        local max3 = storage.caveBotTasker.max3
        local count3 = storage.caveBotTasker.count3

        if count3 >= max3 then
            CaveBot.gotoLabel(label6)
            print("CaveBot[Tasker]: task completed: " .. storage.caveBotTasker.taskName3)
            return true
        else
            CaveBot.gotoLabel(label5)
            print("Task in progress '" .. storage.caveBotTasker.taskName3 .. "': " .. count3 .. "/" .. max3)
            return true
        end


    elseif marker == 9 then -- reporting task
        CaveBot.Conversation("hi", "report", "task")
        delay(talkDelay*3)

        print("CaveBot[Tasker]: Task " .. storage.caveBotTasker.taskName3 .. " reported, done")
		resetTaskData3()
        return true
	elseif marker == 10 then
        storage.caveBotTasker.monster = monster
        if monster2 then storage.caveBotTasker.monster2 = monster2 end
        if monster3 then storage.caveBotTasker.monster3 = monster3 end
        if monster4 then storage.caveBotTasker.monster4 = monster4 end
        if monster5 then storage.caveBotTasker.monster5 = monster5 end
        storage.caveBotTasker.taskName = taskName
        storage.caveBotTasker.inProgress = true
        storage.caveBotTasker.max = count
        storage.caveBotTasker.count = 0

        print("CaveBot[Tasker]: taken task for: " .. taskName .. " x" .. count)
        return true
	elseif marker == 11 then
        storage.caveBotTasker.monster6 = monster6
        if monster7 then storage.caveBotTasker.monster7 = monster7 end
        if monster8 then storage.caveBotTasker.monster8 = monster8 end
        if monster9 then storage.caveBotTasker.monster9 = monster9 end
        if monster10 then storage.caveBotTasker.monster10 = monster10 end
        storage.caveBotTasker.taskName2 = taskName2
        storage.caveBotTasker.inProgress2 = true
        storage.caveBotTasker.max2 = count2
        storage.caveBotTasker.count2 = 0

        print("CaveBot[Tasker]: taken task for: " .. taskName2 .. " x" .. count2)
        return true
	elseif marker == 12 then
	    storage.caveBotTasker.monster11 = monster11
        if monster12 then storage.caveBotTasker.monster12 = monster12 end
        if monster13 then storage.caveBotTasker.monster13 = monster13 end
        if monster14 then storage.caveBotTasker.monster14 = monster14 end
        if monster15 then storage.caveBotTasker.monster15 = monster15 end
        storage.caveBotTasker.taskName3 = taskName3
        storage.caveBotTasker.inProgress3 = true
        storage.caveBotTasker.max3 = count3
        storage.caveBotTasker.count3 = 0

        print("CaveBot[Tasker]: taken task for: " .. taskName3 .. " x" .. count3)
        return true
    end

  end)

 CaveBot.Editor.registerAction("tasker", "tasker", {
  value=[[ -------------Valores para pedir Tasker--------------


Task 1
  1,NameTask1,Cantidad1,Name1,Name2,Name3,Name4,Name5  
  2,LabelHunt1,LabelSalir2  
  3,----Solo Reportar
  
Task 2
  4,NameTask2,Cantidad2,Name6,Name7,Name8,Name9,Name10  
  5,LabelHunt3,LabelSalir4  
  6,----Solo Reportar
  
Task 3
  7,NameTask3,Cantidad3,Name11,Name12,Name13,Name14,Name15  
  8,LabelHunt5,LabelSalir6  
  9,----Solo Reportar]],
  title="Tasker",
  multiline = true
 })
end

local regex = "Loot of ([a-z])* ([a-z A-Z]*):"
local regex2 = "Loot of ([a-z A-Z]*):"
onTalk(function(name, level, mode, text, channelId, pos)
   -- if CaveBot.isOff() then return end
    if not text:lower():find("loot of") then return end
    if #regexMatch(text, regex) == 1 and #regexMatch(text, regex)[1] == 3 then
        monster = regexMatch(text, regex)[1][3]
    elseif #regexMatch(text, regex2) == 1 and #regexMatch(text, regex2)[1] == 2 then
        monster = regexMatch(text, regex2)[1][2]
    end

    local m1 = storage.caveBotTasker.monster
    local m2 = storage.caveBotTasker.monster2
	local m3 = storage.caveBotTasker.monster3
    local m4 = storage.caveBotTasker.monster4    
	local m5 = storage.caveBotTasker.monster5
    local m6 = storage.caveBotTasker.monster6
	local m7 = storage.caveBotTasker.monster7
    local m8 = storage.caveBotTasker.monster8	
	local m9 = storage.caveBotTasker.monster9
    local m10 = storage.caveBotTasker.monster10
	local m11 = storage.caveBotTasker.monster11
	local m12 = storage.caveBotTasker.monster12
	local m13 = storage.caveBotTasker.monster13
	local m14 = storage.caveBotTasker.monster14
	local m15 = storage.caveBotTasker.monster15	
	

    if monster == m1 or monster == m2 or monster == m3 or monster == m4 or monster == m5 and storage.caveBotTasker.count then
        storage.caveBotTasker.count = storage.caveBotTasker.count + 1
    elseif monster == m6 or monster == m7 or monster == m8 or monster == m9 or monster == m10 and storage.caveBotTasker.count2 then
        storage.caveBotTasker.count2 = storage.caveBotTasker.count2 + 1
	elseif monster == m11 or monster == m12 or monster == m13 or monster == m14 or monster == m15 and storage.caveBotTasker.count3 then
        storage.caveBotTasker.count3 = storage.caveBotTasker.count3 + 1
    end
end)
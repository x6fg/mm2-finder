print("naa")
local PlaceID = game.PlaceId
local AllIDs = {}
local UsedIDs = {}
local lastHour = os.date("!*t").hour
local serverFileName = "ServerIDs_" .. PlaceID .. ".json"  -- File name based on PlaceID

-- Load the previously stored IDs and timestamps
local function loadData()
    print("Loading data from file: " .. serverFileName)
    local success, data = pcall(function()
        return game:GetService('HttpService'):JSONDecode(readfile(serverFileName))
    end)
    
    if success and data then
        AllIDs = data.AllIDs or {}
        UsedIDs = data.UsedIDs or {}
        print("Data loaded successfully. AllIDs count: " .. #AllIDs .. ", UsedIDs count: " .. #UsedIDs)
    else
        print("No data found, creating new file: " .. serverFileName)
        writefile(serverFileName, game:GetService('HttpService'):JSONEncode({AllIDs = {}, UsedIDs = {}}))
    end
end

-- Save the updated IDs and timestamps
local function saveData()
    print("Saving data to file: " .. serverFileName)
    writefile(serverFileName, game:GetService('HttpService'):JSONEncode({AllIDs = AllIDs, UsedIDs = UsedIDs}))
    print("Data saved. AllIDs count: " .. #AllIDs .. ", UsedIDs count: " .. #UsedIDs)
end

-- Reset UsedIDs if the hour has changed
local function resetUsedIDsIfHourChanged()
    local currentHour = os.date("!*t").hour
    if currentHour ~= lastHour then
        print("Hour changed from " .. lastHour .. " to " .. currentHour .. ". Resetting UsedIDs.")
        UsedIDs = {}
        lastHour = currentHour
        saveData()
    end
end

-- Function to record a server visit
local function recordVisit(ID)
    UsedIDs[ID] = true
    print("Recorded visit for server ID: " .. ID)
end

-- Attempt to teleport to a suitable server
local function TPReturner()
    if #AllIDs == 0 then
        print("AllIDs is empty. No servers to teleport to.")
        return
    end

    local ID = table.remove(AllIDs, 1) -- Get the first ID from the list
    print("Attempting to teleport to server ID: " .. ID)

    -- Save the updated AllIDs to the file before attempting to teleport
    saveData()

    local success, err = pcall(function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
    end)

    if success then
        print("Successfully teleported to server ID: " .. ID)
        recordVisit(ID) -- Record the visit after a successful teleport
    else
        print("Failed to teleport to server ID: " .. ID .. ". Error: " .. err)
        -- If teleportation fails, you might want to keep the ID in the list or handle it differently
    end
end

-- Start the teleport process
local function Teleport()
    while wait(1) do -- Reduced wait time to 1 second for more frequent checks
        resetUsedIDsIfHourChanged()
        TPReturner() -- Directly call TPReturner
    end
end

-- Load data and initiate teleport process
loadData()
Teleport()

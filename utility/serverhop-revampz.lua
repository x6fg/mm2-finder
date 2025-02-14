local PlaceID = game.PlaceId
local AllIDs = {}
local UsedIDs = {}
local lastHour = os.date("!*t").hour
local foundAnything = ""
local serverFileName = "Sbaba" .. PlaceID .. ".json"  -- File name based on PlaceID

-- Load the previously stored IDs, timestamps, and lastHour
local function loadData()
    local success, data = pcall(function()
        return game:GetService('HttpService'):JSONDecode(readfile(serverFileName))
    end)
    
    if success then
        AllIDs = data.AllIDs or {}
        UsedIDs = data.UsedIDs or {}
        lastHour = data.lastHour or lastHour  -- Load lastHour from saved data
        print("Data loaded successfully.")
    else
        writefile(serverFileName, game:GetService('HttpService'):JSONEncode({AllIDs = {}, UsedIDs = {}, lastHour = lastHour}))
        print("No data found, created new file.")
    end
end

-- Save the updated IDs, timestamps, and lastHour
local function saveData()
    writefile(serverFileName, game:GetService('HttpService'):JSONEncode({AllIDs = AllIDs, UsedIDs = UsedIDs, lastHour = lastHour}))
    print("Data saved.")
end

-- Reset UsedIDs if the hour has changed
local function resetUsedIDsIfHourChanged()
    local currentHour = os.date("!*t").hour
    if currentHour ~= lastHour then
        UsedIDs = {}
        lastHour = currentHour
        saveData()  -- Save the new lastHour
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, game.Players.LocalPlayer)
    end
end

-- Function to determine if a server has been visited within the current hour
local function isRecentVisit(ID)
    return UsedIDs[ID] == true
end

-- Function to record a server visit
local function recordVisit(ID)
    UsedIDs[ID] = true
    print("Recorded visit for server ID: " .. ID)
end

-- Function to fetch new servers and update the AllIDs list
local function fetchNewServers()
    local url = 'https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100'
    
    if foundAnything ~= "" then
        url = url .. '&cursor=' .. foundAnything
    end

    print("Fetching servers from URL: " .. url) -- Print the URL for debugging

    local success, response = pcall(function()
        return game.HttpService:JSONDecode(game:HttpGet(url))
    end)

    if not success then
        print("HTTP request failed: " .. response) -- Print the error message
        return -- Exit if the request fails
    end

    if not response.data then
        print("No data returned from the server.")
        return
    end

    if response.nextPageCursor and response.nextPageCursor ~= "null" then
        foundAnything = response.nextPageCursor
    end

    local newIDs = {} -- Temporary table to hold new server IDs

    for _, v in pairs(response.data) do
        local ID = tostring(v.id)
        if tonumber(v.maxPlayers) > tonumber(v.playing) and not isRecentVisit(ID) and not AllIDs[ID] then
            table.insert(newIDs, ID) -- Add to temporary table
            print("Found new server ID: " .. ID)
        end
    end

    -- Add all new IDs to AllIDs at once
    for _, id in ipairs(newIDs) do
        table.insert(AllIDs, id)
    end

    -- Save the updated AllIDs to the file
    saveData()
end

-- Attempt to teleport to a suitable server
local function TPReturner()
    if #AllIDs == 0 then
        print("AllIDs is empty, fetching new servers...")
        fetchNewServers()
        return
    end

    local ID = table.remove(AllIDs, 1) -- Get the first ID from the list
    print("Attempting to teleport to server ID: " .. ID)

    local success, err = pcall(function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
    end)

    if success then
        recordVisit(ID) -- Record the visit after a successful teleport
        print("Successfully teleported to server ID: " .. ID)
    else
        print("Failed to teleport to server ID: " .. ID .. ". Error: " .. err)
        -- If teleportation fails, you might want to keep the ID in the list or handle it differently
    end

    -- Save the updated UsedIDs to the file after attempting to teleport
    saveData()
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

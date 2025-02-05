local PlaceID = game.PlaceId
local AllIDs = {}
local UsedIDs = {}
local lastHour = os.date("!*t").hour
local foundAnything = ""
local serverFileName = "ServerIDs_" .. PlaceID .. ".json"  -- Updated to include PlaceID

-- Load the previously stored IDs and timestamps
local function loadData()
    print("Loading data from file: " .. serverFileName)
    local success, data = pcall(function()
        return game:GetService('HttpService'):JSONDecode(readfile(serverFileName))
    end)
    
    if success then
        AllIDs = data.AllIDs or {}
        UsedIDs = data.UsedIDs or {}
        print("Data loaded successfully. AllIDs count: " .. #AllIDs .. ", UsedIDs count: " .. #UsedIDs)
    else
        writefile(serverFileName, game:GetService('HttpService'):JSONEncode({AllIDs = {}, UsedIDs = {}}))
        print("No data found, created new file: " .. serverFileName)
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
        print("Next page cursor found: " .. foundAnything)
    end

    local newIDs = {} -- Temporary table to hold new server IDs

    for _, v in pairs(response.data) do
        local ID = tostring(v.id)
        if tonumber(v.maxPlayers) > tonumber(v.playing) and not isRecentVisit(ID) and not AllIDs[ID] then
            table.insert(newIDs, ID) -- Add to temporary table
            recordVisit(ID) -- Record the visit
            print("Found new server ID: " .. ID)
        end
    end

    -- Add all new IDs to AllIDs at once
    for _, id in ipairs(newIDs) do
        table.insert(AllIDs, id)
    end

    -- Save the updated AllIDs to the file
    if #newIDs > 0 then
        print("Total new server IDs found: " .. #newIDs)
        saveData()
    else
        print("No new server IDs found.")
    end
end

-- Attempt to teleport to a suitable server
local function TPReturner()
    if #AllIDs == 0 then
        print("AllIDs is empty, fetching new servers...")
        fetchNewServers()
    end

    if #AllIDs > 0 then
        local ID = table.remove(AllIDs, 1) -- Get the first ID from the list
        print("Teleporting to server ID: " .. ID)
        game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
        wait(3) -- Wait for a short period before the next teleport
    else
        print("No suitable servers found.")
    end
end

-- Start the teleport process
local function Teleport()
    while wait(1) do -- Reduced wait time to 1 second for more frequent checks
        resetUsedIDsIfHourChanged()
        pcall(function()
            TPReturner()
        end)
    end
end

-- Load data and initiate teleport process
loadData()
Teleport()

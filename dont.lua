local PlaceID = game.PlaceId
local AllIDs = {}
local UsedIDs = {}
local lastHour = os.date("!*t").hour
local foundAnything = ""
local serverFileName = "ServerIDs.json" .. PlaceID

-- Load the previously stored IDs and timestamps
local function loadData()
    local success, data = pcall(function()
        return game:GetService('HttpService'):JSONDecode(readfile(serverFileName))
    end)
    
    if success then
        AllIDs = data.AllIDs or {}
        UsedIDs = data.UsedIDs or {}
        print("Data loaded successfully.")
    else
        writefile(serverFileName, game:GetService('HttpService'):JSONEncode({AllIDs = {}, UsedIDs = {}}))
        print("No data found, created new file.")
    end
end

-- Save the updated IDs and timestamps
local function saveData()
    writefile(serverFileName, game:GetService('HttpService'):JSONEncode({AllIDs = AllIDs, UsedIDs = UsedIDs}))
    print("Data saved.")
end

-- Reset UsedIDs if the hour has changed
local function resetUsedIDsIfHourChanged()
    local currentHour = os.date("!*t").hour
    if currentHour ~= lastHour then
        UsedIDs = {}
        lastHour = currentHour
        saveData()
        print("Used IDs reset for the new hour.")
    end
end

-- Function to determine if a server has been visited within the current hour
local function isRecentVisit(ID)
    return UsedIDs[ID] == true
end

-- Function to record a server visit
local function recordVisit(ID)
    UsedIDs[ID] = true
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
            recordVisit(ID) -- Record the visit
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
    else

        for i, v in pairs(AllIDs) do
            local ID = table.remove(AllIDs, v) -- Get the first ID from the list
            print("Teleporting to server ID: " .. ID)
            game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
            break
        end
        print("kakann")
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

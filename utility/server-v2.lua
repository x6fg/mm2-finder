local PlaceID = game.PlaceId
local AllIDs = {}
local UsedIDs = {}
local lastHour = os.date("!*t").hour
local foundAnything = ""
local serverFileName = "ServerIDs.json"

-- Load the previously stored IDs and timestamps
local function loadData()
    local success, data = pcall(function()
        return game:GetService('HttpService'):JSONDecode(readfile(serverFileName))
    end)
    
    if success then
        AllIDs = data.AllIDs or {}
        UsedIDs = data.UsedIDs or {}
    else
        writefile(serverFileName, game:GetService('HttpService'):JSONEncode({AllIDs = {}, UsedIDs = {}}))
    end
end

-- Save the updated IDs and timestamps
local function saveData()
    writefile(serverFileName, game:GetService('HttpService'):JSONEncode({AllIDs = AllIDs, UsedIDs = UsedIDs}))
end

-- Reset UsedIDs if the hour has changed
local function resetUsedIDsIfHourChanged()
    local currentHour = os.date("!*t").hour
    if currentHour ~= lastHour then
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
end

-- Function to fetch new servers and update the AllIDs list
local function fetchNewServers()
    local Site
    local url = 'https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100'
    
    if foundAnything ~= "" then
        url = url .. '&cursor=' .. foundAnything
    end

    local success, response = pcall(function()
        return game.HttpService:JSONDecode(game.HttpService:HttpGet(url))
    end)

    if not success or not response.data then
        return -- Exit if the request fails
    end

    if response.nextPageCursor and response.nextPageCursor ~= "null" then
        foundAnything = response.nextPageCursor
    end

    for _, v in pairs(response.data) do
        local ID = tostring(v.id)
        if tonumber(v.maxPlayers) > tonumber(v.playing) and not isRecentVisit(ID) then
            table.insert(AllIDs, ID)
            recordVisit(ID)
        end
    end

    -- Save the updated AllIDs to the file
    saveData()
end

-- Attempt to teleport to a suitable server
local function TPReturner()
    if #AllIDs == 0 then
        fetchNewServers()
    end

    if #AllIDs > 0 then
        local ID = table.remove(AllIDs, 1) -- Get the first ID from the list
        game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
        wait(3) -- Wait for a short period before the next teleport
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

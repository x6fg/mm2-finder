local PlaceID = game.PlaceId
local AllIDs = {}
local UsedIDs = {}
local lastHour = os.date("!*t").hour
local foundAnything = ""

-- Load the previously stored IDs and timestamps
local function loadData()
    local success, data = pcall(function()
        return game:GetService('HttpService'):JSONDecode(readfile("TestingExperimental.json"))
    end)
    
    if success then
        AllIDs = data.AllIDs or {}
        UsedIDs = data.UsedIDs or {}
    else
        writefile("TestingExperimental.json", game:GetService('HttpService'):JSONEncode({AllIDs = {}, UsedIDs = {}}))
    end
end

-- Save the updated IDs and timestamps
local function saveData()
    writefile("TestingExperimental.json", game:GetService('HttpService'):JSONEncode({AllIDs = AllIDs, UsedIDs = UsedIDs}))
end

-- Reset UsedIDs if the hour has changed
local function resetUsedIDsIfHourChanged()
    local currentHour = os.date("!*t").hour
    if currentHour ~= lastHour then
        UsedIDs = {}
		AllIDs = {}
        lastHour = currentHour
        saveData()
    end
end

-- Function to determine if a server has been visited within the current hour
local function isRecentVisit(ID)
    return UsedIDs[ID] ~= nil
end

-- Function to record a server visit
local function recordVisit(ID)
    UsedIDs[ID] = true
    saveData()
end

-- Attempt to find and teleport to a suitable server
local function TPReturner()
    local Site
    if foundAnything == "" then
        Site = game.HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100'))
    else
        Site = game.HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100&cursor=' .. foundAnything))
    end

    if Site.nextPageCursor and Site.nextPageCursor ~= "null" then
        foundAnything = Site.nextPageCursor
    end

    for _, v in pairs(Site.data) do
        local ID = tostring(v.id)
        if tonumber(v.maxPlayers) > tonumber(v.playing) and not isRecentVisit(ID) then
            table.insert(AllIDs, ID)
            recordVisit(ID)
            game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
            wait(3)
            return
        end
    end

    -- If no suitable server is found, attempt the next batch
    if foundAnything ~= "" then
        TPReturner()
    end
end

-- Start the teleport process
local function Teleport()
    while wait() do
        resetUsedIDsIfHourChanged()
        pcall(function()
            TPReturner()
        end)
    end
end

-- Load data and initiate teleport process
loadData()
Teleport()

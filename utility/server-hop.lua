local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local PlaceID = getgenv().placeId
local jsonFileName = "SavedServerIDs.json"
local unusedFileName = "UnusedServerIDs.json"
local actualHour = os.date("%H")

local AllIDs = {}
local UnusedIDs = {}
local foundAnything = nil
local isTeleporting = false -- Track teleportation state

-- Load IDs from files
local function loadIDs()
    print("Loading IDs from files...")
    local success, result = pcall(function()
        return HttpService:JSONDecode(readfile(jsonFileName))
    end)

    if success and type(result) == "table" then
        AllIDs = result
        print("Loaded IDs successfully:", AllIDs)
    else
        AllIDs = {actualHour}
        print("No existing ID file found or failed to load, creating new file with current hour:", actualHour)
        writefile(jsonFileName, HttpService:JSONEncode(AllIDs))
    end

    local successUnused, resultUnused = pcall(function()
        return HttpService:JSONDecode(readfile(unusedFileName))
    end)

    if successUnused and type(resultUnused) == "table" then
        UnusedIDs = resultUnused
        print("Loaded unused IDs successfully:", UnusedIDs)
    else
        UnusedIDs = {}
        print("No existing unused server file found or failed to load, creating new file.")
        writefile(unusedFileName, HttpService:JSONEncode(UnusedIDs))
    end
end

-- Save IDs to files
local function saveIDs()
    writefile(jsonFileName, HttpService:JSONEncode(AllIDs))
    writefile(unusedFileName, HttpService:JSONEncode(UnusedIDs))
end

-- Clear the files if the hour has changed
local function clearFileIfHourChanged()
    if tonumber(actualHour) ~= tonumber(AllIDs[1]) then
        pcall(function()
            delfile(jsonFileName)
            delfile(unusedFileName)
        end)
        AllIDs = {actualHour}
        UnusedIDs = {}
        saveIDs()
    end
end

-- Fetch servers with pagination
local function fetchServers(cursor)
    local url = 'https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100'

    if cursor then
        url = url .. '&cursor=' .. cursor
    end

    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)

    if not success then
        return nil
    end

    return result
end

-- Attempt to teleport to a server
local function tryTeleport(ID)
    if isTeleporting then
        print("Already teleporting. Waiting...")
        repeat
            task.wait(0.2)  -- Shorter delay while waiting for teleportation to finish
        until not isTeleporting
    end

    print("Attempting to teleport to server ID:", ID)
    table.insert(AllIDs, ID)
    saveIDs()
    isTeleporting = true -- Mark teleportation as in progress

    local success, errorMsg = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceID, ID, Players.LocalPlayer)
    end)

    if not success then
        print("Teleport failed:", errorMsg)
        isTeleporting = false -- Reset teleportation state if it fails
    end
end

-- Teleporting Completed Event
TeleportService.TeleportInitFailed:Connect(function()
    print("Teleport failed. Resetting state.")
    isTeleporting = false
end)

Players.LocalPlayer.OnTeleport:Connect(function()
    print("Teleport completed.")
    isTeleporting = false
end)

-- Attempt to use an unused server
local function tryUnusedServers()
    while #UnusedIDs > 0 do
        local ID = table.remove(UnusedIDs, 1)
        task.wait(2) -- Shorter delay between attempts for unused servers
        print("Trying unused server ID:", ID)
        tryTeleport(ID)
        saveIDs()
    end
end

-- Main function to find and teleport to a suitable server
local function TPReturner()
    local Site = fetchServers(foundAnything) -- Fetch servers outside the repeat loop

    repeat
        if not Site then
            print("Failed to fetch servers. Retrying...")
            break
        end

        if Site.nextPageCursor then
            foundAnything = Site.nextPageCursor
            print("Next page cursor set to:", foundAnything)
        else
            foundAnything = nil
        end

        clearFileIfHourChanged()

        for _, server in ipairs(Site.data) do
            local ID = tostring(server.id)
            print("Checking server ID:", ID, "Players:", server.playing, "/", server.maxPlayers)

            task.wait(1) -- Reduced delay before processing each server

            if tonumber(server.maxPlayers) > tonumber(server.playing) then
                if not table.find(AllIDs, ID) then
                    print("Suitable server found:", ID)
                    tryTeleport(ID)
                    saveIDs()
                else
                    print("Server ID already used, adding to unused servers:", ID)
                    -- Add ID to UnusedIDs only if it's not in AllIDs
                    if not table.find(UnusedIDs, ID) and not table.find(AllIDs, ID) then
                        table.insert(UnusedIDs, ID)
                    end
                end
            end
        end

        -- Remove processed servers from the current list
        saveIDs()
    until not foundAnything

    print("Finished fetching servers for this session.")
end

-- Main teleport loop
local function Teleport()
    while wait(0.5) do  -- Faster main loop to avoid unnecessary delays
        -- Attempt to use unused servers first
        if #UnusedIDs > 0 then
            print("Trying unused servers...")
            tryUnusedServers()
        else
            print("No unused servers left, fetching new servers...")
            pcall(TPReturner)
        end
    end
end

-- Load and start teleporting
loadIDs()
Teleport()

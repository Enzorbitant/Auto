-- Load config
local CONFIG_URL = "https://raw.githubusercontent.com/Enzorbitant/Auto/main/config.lua"
loadstring(game:HttpGet(CONFIG_URL))()

-- Ensure config loaded
if not getgenv().bgsInfConfig then
    error("Failed to load config! Check the CONFIG_URL or config file.")
end
print("Config loaded successfully!")

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RemoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

-- Rift data with names and paths
local RIFT_DATA = {
    ["Royal Chest"] = {path = "royal-chest", type = "chest"},
    ["Golden Chest"] = {path = "golden-chest", type = "chest"},
    ["Dice Chest"] = {path = "dice-rift", type = "chest"},
    ["Rainbow Egg"] = {path = "rainbow-egg", type = "egg"},
    ["Void Egg"] = {path = "void-egg", type = "egg"},
    ["Nightmare Egg"] = {path = "nightmare-egg", type = "egg"},
    ["Cyber Egg"] = {path = "cyber-egg", type = "egg"},
    ["Underworld Egg"] = {path = "underworld-egg", type = "egg"}
}

-- Utility functions
local function getRiftTimer(riftPath)
    local success, timerGui = pcall(function()
        return Workspace.Rendered.Rifts[riftPath].Display.SurfaceGui.Timer
    end)
    if success and timerGui then
        local timerText = timerGui.Text
        local minutes = tonumber(timerText:match("(%d+) minutes")) or 0
        return minutes
    end
    return 0
end

local function getRiftLuck(riftPath)
    local success, timerGui = pcall(function()
        return Workspace.Rendered.Rifts[riftPath].Display.SurfaceGui.Timer
    end)
    if success and timerGui then
        local luckText = timerGui.Text:match("X(%d+)") or "X0" -- Extract "X5", "X10", "X25" or default to "X0"
        return "X" .. luckText
    end
    return "X0"
end

local function flyToRift(riftPath)
    local success, targetPart = pcall(function()
        return Workspace.Rendered.Rifts[riftPath].Decoration.Model.islandbottom_collision.MeshPart
    end)
    if success and targetPart and LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart then
        local targetPos = targetPart.Position + Vector3.new(0, 5, 0) -- Slightly above platform
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(targetPos)
        print("Flew to rift: " .. riftPath)
        return true
    else
        print("Failed to fly to rift: " .. riftPath .. " (Target part or character not found)")
        return false
    end
end

local function openChest(chestType)
    RemoteEvent:FireServer("UnlockRiftChest", chestType, false)
    print("Attempted to open chest: " .. chestType)
end

local function hatchEgg(eggType, amount)
    RemoteEvent:FireServer("HatchEgg", eggType, amount)
    print("Attempted to hatch " .. amount .. " " .. eggType)
end

local function blowBubble()
    RemoteEvent:FireServer("BlowBubble")
    print("Blew bubble")
end

local function serverHop()
    if getgenv().bgsInfConfig.SERVER_HOP then
        TeleportService:Teleport(game.PlaceId)
        print("Server hop initiated")
    end
end

local function scanRifts()
    local activeRifts = {}
    for name, data in pairs(RIFT_DATA) do
        local success, exists = pcall(function()
            return Workspace.Rendered.Rifts:FindFirstChild(data.path) ~= nil
        end)
        if success and exists then
            table.insert(activeRifts, {name = name, path = data.path, type = data.type})
            print("Found active rift: " .. name .. " (" .. data.path .. ")")
        end
    end
    if #activeRifts == 0 then
        print("No active rifts found!")
    end
    return activeRifts
end

local function findTargetRift(activeRifts)
    local luckOptions = getgenv().bgsInfConfig.LUCK_RIFT
    -- Prioritize eggs first based on EGG_HATCH config order
    for _, egg in ipairs(getgenv().bgsInfConfig.EGG_HATCH) do
        for _, rift in ipairs(activeRifts) do
            if rift.name == egg and rift.type == "egg" then
                local luck = getRiftLuck(rift.path)
                for _, luckLevel in ipairs(luckOptions) do
                    if luck == luckLevel then
                        print("Target rift selected: " .. rift.name .. " with luck " .. luck)
                        return rift
                    end
                end
            end
        end
    end
    -- Then check chests based on CHESTS_OPEN config order
    for _, chest in ipairs(getgenv().bgsInfConfig.CHESTS_OPEN) do
        for _, rift in ipairs(activeRifts) do
            if rift.name == chest and rift.type == "chest" then
                local luck = getRiftLuck(rift.path)
                for _, luckLevel in ipairs(luckOptions) do
                    if luck == luckLevel then
                        print("Target rift selected: " .. rift.name .. " with luck " .. luck)
                        return rift
                    end
                end
            end
        end
    end
    print("No suitable target rift found with matching luck!")
    return nil
end

-- Main logic
local function mainLoop()
    print("Main loop started!")
    while true do
        -- Auto-bubble
        if getgenv().bgsInfConfig.AUTO_BUBBLE then
            blowBubble()
        end

        -- Scan for active rifts
        local activeRifts = scanRifts()
        if #activeRifts > 0 then
            -- Find target rift based on priority and luck
            local targetRift = findTargetRift(activeRifts)
            if targetRift then
                -- Fly to rift
                local flewSuccessfully = flyToRift(targetRift.path)
                if flewSuccessfully then
                    -- Auto-open or hatch
                    if targetRift.type == "chest" and getgenv().bgsInfConfig.OPEN_CHEST then
                        local riftExists = true
                        while riftExists do
                            local success = pcall(function()
                                if Workspace.Rendered.Rifts:FindFirstChild(targetRift.path) then
                                    openChest(targetRift.path)
                                else
                                    riftExists = false
                                end
                            end)
                            if not success then
                                riftExists = false
                            end
                            wait(0.5)
                        end
                    elseif targetRift.type == "egg" and getgenv().bgsInfConfig.OPEN_EGG then
                        local riftExists = true
                        while riftExists do
                            local success = pcall(function()
                                if Workspace.Rendered.Rifts:FindFirstChild(targetRift.path) then
                                    hatchEgg(targetRift.name, getgenv().bgsInfConfig.EGG_HATCH_AMOUNT)
                                else
                                    riftExists = false
                                end
                            end)
                            if not success then
                                riftExists = false
                            end
                            wait(0.5)
                        end
                    end

                    -- Check timer and rejoin
                    if getgenv().bgsInfConfig.AUTO_REJOIN then
                        local riftExists, timer = pcall(function()
                            if Workspace.Rendered.Rifts:FindFirstChild(targetRift.path) then
                                return true, getRiftTimer(targetRift.path)
                            end
                            return false, 0
                        end)
                        if riftExists and timer <= 0 or not riftExists then
                            local newActiveRifts = scanRifts()
                            local nextRift = findTargetRift(newActiveRifts)
                            if nextRift then
                                flyToRift(nextRift.path)
                            else
                                serverHop()
                            end
                        end
                    end
                end
            end
        else
            -- No rifts found, hop if enabled
            if getgenv().bgsInfConfig.AUTO_REJOIN and getgenv().bgsInfConfig.SERVER_HOP then
                serverHop()
            end
        end
        wait(1)
    end
end

-- Start the script
mainLoop()

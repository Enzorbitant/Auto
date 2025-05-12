-- Config directly in script
getgenv().bgsInfConfig = {
    AUTO_REJOIN = true, -- Rejoin servers when rifts despawn
    SERVER_HOP = true, -- Enable server hopping
    OPEN_CHEST = true, -- Auto-open chests
    OPEN_EGG = true, -- Auto-hatch eggs
    AUTO_BUBBLE = true, -- Auto-blow bubbles
    CHESTS_OPEN = {"Royal Chest", "Dice Chest", "Golden Chest"}, -- Chests to open
    EGG_HATCH = {"Cyber Egg", "Underworld Egg", "Rainbow Egg"}, -- Eggs to hatch (first in list prioritized)
    EGG_HATCH_AMOUNT = 6, -- Number of eggs to hatch per action
    LUCK_RIFT = {"X5", "X10", "X25"} -- Luck levels to target (e.g., only "X25" for highest luck)
}

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
        return true
    end
    return false
end

local function openChest(chestType)
    RemoteEvent:FireServer("UnlockRiftChest", chestType, false)
end

local function hatchEgg(eggType, amount)
    RemoteEvent:FireServer("HatchEgg", eggType, amount)
end

local function blowBubble()
    RemoteEvent:FireServer("BlowBubble")
end

local function serverHop()
    if getgenv().bgsInfConfig.SERVER_HOP then
        TeleportService:Teleport(game.PlaceId)
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
        end
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
                        return rift
                    end
                end
            end
        end
    end
    return nil
end

-- Main logic
local function mainLoop()
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

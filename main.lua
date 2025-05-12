-- Load config
local CONFIG_URL = "https://raw.githubusercontent.com/YourUsername/YourRepo/main/config.lua"
loadstring(game:HttpGet(CONFIG_URL))()

-- Ensure config loaded
if not getgenv().bgsInfConfig then
    error("Failed to load config!")
end

local CONFIG = getgenv().bgsInfConfig

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
    local timerGui = Workspace.Rendered.Rifts[riftPath].Display.SurfaceGui.Timer
    local timerText = timerGui.Text
    local minutes = tonumber(timerText:match("(%d+) minutes")) or 0
    return minutes
end

local function flyToRift(riftPath)
    local targetPart = Workspace.Rendered.Rifts[riftPath].Decoration.Model.islandbottom_collision.MeshPart
    local targetPos = targetPart.Position + Vector3.new(0, 5, 0) -- Slightly above platform
    if LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(targetPos)
    end
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
    if CONFIG.SERVER_HOP then
        TeleportService:Teleport(game.PlaceId)
    end
end

local function findTargetRift()
    -- Prioritize eggs first based on EGG_HATCH config order
    for _, egg in ipairs(CONFIG.EGG_HATCH) do
        local riftInfo = RIFT_DATA[egg]
        if riftInfo and Workspace.Rendered.Rifts:FindFirstChild(riftInfo.path) then
            return riftInfo
        end
    end
    -- Then check chests based on CHESTS_OPEN config order
    for _, chest in ipairs(CONFIG.CHESTS_OPEN) do
        local riftInfo = RIFT_DATA[chest]
        if riftInfo and Workspace.Rendered.Rifts:FindFirstChild(riftInfo.path) then
            return riftInfo
        end
    end
    return nil
end

-- Main logic
local function mainLoop()
    while true do
        -- Auto-bubble
        if CONFIG.AUTO_BUBBLE then
            blowBubble()
        end

        -- Find target rift
        local targetRift = findTargetRift()
        if targetRift then
            -- Fly to rift
            flyToRift(targetRift.path)

            -- Auto-open or hatch
            if targetRift.type == "chest" and CONFIG.OPEN_CHEST then
                while Workspace.Rendered.Rifts:FindFirstChild(targetRift.path) do
                    openChest(targetRift.path)
                    wait(0.5)
                end
            elseif targetRift.type == "egg" and CONFIG.OPEN_EGG then
                while Workspace.Rendered.Rifts:FindFirstChild(targetRift.path) do
                    hatchEgg(targetRift.name, CONFIG.EGG_HATCH_AMOUNT)
                    wait(0.5)
                end
            end

            -- Check timer and rejoin
            if CONFIG.AUTO_REJOIN then
                if Workspace.Rendered.Rifts:FindFirstChild(targetRift.path) then
                    local timer = getRiftTimer(targetRift.path)
                    if timer <= 0 then
                        local nextRift = findTargetRift()
                        if nextRift then
                            flyToRift(nextRift.path)
                        else
                            serverHop()
                        end
                    end
                else
                    local nextRift = findTargetRift()
                    if nextRift then
                        flyToRift(nextRift.path)
                    else
                        serverHop()
                    end
                end
            end
        else
            -- No rifts found, hop if enabled
            if CONFIG.AUTO_REJOIN and CONFIG.SERVER_HOP then
                serverHop()
            end
        end
        wait(1)
    end
end

-- Start the script
mainLoop()

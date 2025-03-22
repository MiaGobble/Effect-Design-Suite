-- Constants
local TICK_RATE = 1 / 2
local AFK_TIMEOUT = 60

-- Services
local RunService = game:GetService("RunService")
local SelectionService = game:GetService("Selection") :: Selection
local StudioService = game:GetService("StudioService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

-- Imports
local Components = script.Parent:FindFirstChild("Components")
local IconicDesign = Components:FindFirstChild("IconicDesign")
local PluginComponents = IconicDesign:FindFirstChild("PluginComponents")
local Objects = script.Parent:FindFirstChild("Objects")
local Interface = require(script.Parent:FindFirstChild("Interface"))
local Toolbar = require(PluginComponents:FindFirstChild("Toolbar"))
local ToolbarButton = require(PluginComponents:FindFirstChild("ToolbarButton"))
local States = require(Objects:FindFirstChild("States"))
local StateOutput = require(script.Parent:FindFirstChild("StateOutput"))
local Fusion = require(script.Parent:FindFirstChild("Packages"):FindFirstChild("Fusion"))
local Peek = Fusion.peek

-- Variables
local ThisToolbar = Toolbar {
    Name = "Effect Designer Suite",
}

local MainButton = ToolbarButton {
    ToolTip = "",
    Name = "Open",
    Image = "rbxassetid://14364353606",
    Toolbar = ThisToolbar,
} :: PluginToolbarButton

local function Init()
    if RunService:IsRunning() or RunService:IsRunMode() then -- Don't init if running in studio
        return
    end

    StateOutput:Init()

    local Widget : DockWidgetPluginGui = Interface:Init()

    MainButton.Click:Connect(function()
        Widget.Enabled = not Widget.Enabled
    end)

    SelectionService.SelectionChanged:Connect(function()
        States.CurrentlySelected:set(SelectionService:Get())
    end)
end

Init()
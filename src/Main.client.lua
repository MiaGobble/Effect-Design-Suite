-- Constants
local ACCEPTABLE_INSTANCE_TYPES = {
    "ParticleEmitter",
    "Sound",
    "ModuleScript",
    "StringValue",
    "Trail",
}

-- Services
local SelectionService = game:GetService("Selection") :: Selection
local RunService = game:GetService("RunService")


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
        local SelectedInstances = SelectionService:Get()
        local ValidInstances = {}

        for _, This : Instance in SelectedInstances do
            if table.find(ACCEPTABLE_INSTANCE_TYPES, This.ClassName) then
                table.insert(ValidInstances, This)
                continue
            end

            for _, SubInstance : Instance in This:GetDescendants() do
                if table.find(ACCEPTABLE_INSTANCE_TYPES, SubInstance.ClassName) then
                    table.insert(ValidInstances, SubInstance)
                end
            end
        end

        States.CurrentlySelected:set(ValidInstances)
        States.IsEditable:set(#ValidInstances == 1)
        States.IsEmittable:set(#ValidInstances >= 1)
        States.PrimarySelected:set(if #ValidInstances == 1 then ValidInstances[1] else nil)

        if Peek(States.PrimarySelected) then
            States.IsEffectModule:set(Peek(States.PrimarySelected):IsA("ModuleScript"))
        end
    end)
end

Init()
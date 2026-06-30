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
local Objects = script.Parent:FindFirstChild("Objects")
local Interface = require(script.Parent:FindFirstChild("Interface"))
local States = require(Objects:FindFirstChild("States"))
local StateOutput = require(script.Parent:FindFirstChild("StateOutput"))
local Packages = script.Parent:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))

local Scope = Seam.Scope(Seam)

-- Variables
local ThisToolbar = Scope:New(Jian.Toolbar, {
    Name = "Effect Designer Suite",
})

local MainButton = Scope:New(Jian.ToolbarButton, {
    ToolTip = "",
    Name = "Open",
    Image = "rbxassetid://140043496156959",
    Toolbar = ThisToolbar,
}) :: PluginToolbarButton

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
        task.wait()
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

        States.CurrentlySelected.Value = ValidInstances
        States.IsEditable.Value = #ValidInstances == 1
        States.IsEmittable.Value = #ValidInstances >= 1
        States.PrimarySelected.Value = if #ValidInstances == 1 then ValidInstances[1] else nil
        States.RawSelection.Value = SelectedInstances or {}

        if States.PrimarySelected.Value then
            States.IsEffectModule.Value = States.PrimarySelected.Value:IsA("ModuleScript")
        else
            States.IsEffectModule.Value = false
        end
    end)
end

Init()
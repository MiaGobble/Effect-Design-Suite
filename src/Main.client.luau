-- Constants
local ACCEPTABLE_INSTANCE_TYPES = {
    "ParticleEmitter",
    "Beam",
    "Sound",
    "ModuleScript",
    "StringValue",
    "Trail",
}
local TOOLBAR_NAME = "Effect Designer Suite"
local TOOLBAR_BUTTONS = {
    {
        Key = "Core",
        Name = "Core",
        ToolTip = "Effect Designer Suite — Core",
        Image = "rbxassetid://140043496156959",
    },
    {
        Key = "Editing",
        Name = "Editing",
        ToolTip = "Effect Designer Suite — Editing",
        Image = "rbxassetid://90017125667882",
    },
    {
        Key = "Advanced",
        Name = "Advanced",
        ToolTip = "Effect Designer Suite — Advanced",
        Image = "rbxassetid://136044962311445",
    },
    {
        Key = "Presets",
        Name = "Presets",
        ToolTip = "Effect Designer Suite — Presets",
        Image = "rbxassetid://102514759395148",
    },
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

-- Variables
local Scope = Seam.Scope(Seam)
local ThisToolbar = Scope:New(Jian.Toolbar, {
    Name = TOOLBAR_NAME,
})

local function Init()
    if RunService:IsRunning() or RunService:IsRunMode() then -- Don't init if running in studio
        return
    end

    StateOutput:Init()

    local Widgets = Interface:Init()

    for _, buttonConfig in TOOLBAR_BUTTONS do
        local Button = Scope:New(Jian.ToolbarButton, {
            ToolTip = buttonConfig.ToolTip,
            Name = buttonConfig.Name,
            Image = buttonConfig.Image,
            Toolbar = ThisToolbar,
        }) :: PluginToolbarButton

        Button.Click:Connect(function()
            local Widget = Widgets[buttonConfig.Key]
            if Widget then
                Widget.Enabled = not Widget.Enabled
            end
        end)
    end

    SelectionService.SelectionChanged:Connect(function()
        task.wait()
        if States.IsPickingInstance.Value then
            return
        end

        local SelectedInstances = SelectionService:Get()
        local ValidInstances = {}

        for _, selected : Instance in SelectedInstances do
            if table.find(ACCEPTABLE_INSTANCE_TYPES, selected.ClassName) then
                table.insert(ValidInstances, selected)
                continue
            end

            if selected:IsA("BasePart") then
                table.insert(ValidInstances, selected)
            end

            for _, subInstance : Instance in selected:GetDescendants() do
                if table.find(ACCEPTABLE_INSTANCE_TYPES, subInstance.ClassName) then
                    table.insert(ValidInstances, subInstance)
                end
            end
        end

        States.IsEmittable.Value = #ValidInstances >= 1
        States.IsEditable.Value = #ValidInstances == 1
        States.CurrentlySelected.Value = ValidInstances
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

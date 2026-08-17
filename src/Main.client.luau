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
local TOOLBAR_BUTTON_NAME = "Open"
local TOOLBAR_BUTTON_IMAGE = "rbxassetid://140043496156959"

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
local MainButton = Scope:New(Jian.ToolbarButton, {
    ToolTip = "",
    Name = TOOLBAR_BUTTON_NAME,
    Image = TOOLBAR_BUTTON_IMAGE,
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
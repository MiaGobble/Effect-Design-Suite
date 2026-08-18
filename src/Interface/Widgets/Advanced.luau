local Advanced = {}

-- Constants
local WIDGET_ID = "EffectDesignerSuiteAdvanced"
local WIDGET_TITLE = "Effect Designer Suite — Advanced"
local WIDGET_WIDTH = 320
local WIDGET_HEIGHT = 480
local ANIMATION_ACTIONS = {
    {
        Order = 2,
        Text = "Create Bezier Animation",
        Kind = "Bezier",
    },
    {
        Order = 3,
        Text = "Create Tween Animation",
        Kind = "Tween",
    },
}

-- Services
local SelectionService = game:GetService("Selection")

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Objects = Bin:FindFirstChild("Objects")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))
local States = require(Objects:FindFirstChild("States"))
local EmitUtils = require(Interface:FindFirstChild("EmitUtils"))
local Modules = Interface:FindFirstChild("Modules")
local UiKit = require(Modules:FindFirstChild("UiKit"))
local VfxApiInjection = require(Modules:FindFirstChild("VfxApiInjection"))
local WorldSpaceAcceleration = require(Modules:FindFirstChild("WorldSpaceAcceleration"))
local ChangeHistory = require(Modules:FindFirstChild("ChangeHistory"))

function Advanced.Create(scope, _session, selection)
    local Widget, Container = UiKit.CreateListWidget(
        scope,
        WIDGET_ID,
        WIDGET_TITLE,
        false,
        WIDGET_WIDTH,
        WIDGET_HEIGHT,
        Enum.InitialDockState.Float
    )

    local InjectVfxApiEnabled = scope:Value(false)
    local WorldSpaceAccelEnabled = scope:Value(false)
    local IsSyncingWorldSpaceAccel = false

    local AnimationButtons = {}
    for _, spec in ANIMATION_ACTIONS do
        table.insert(AnimationButtons, UiKit.CreateActionButton(scope, spec.Order, spec.Text, selection.HasRawSelection, function()
            local SelectedInstances = States.RawSelection.Value
            if #SelectedInstances == 0 then
                return
            end

            ChangeHistory.Record("Create " .. spec.Kind .. " Animation", function()
                local Indicator = EmitUtils:CreateNewAnimationIndicator(SelectedInstances[1], spec.Kind)
                SelectionService:Set({Indicator})
            end)
        end))
    end

    local InsertPlayEffectModuleButton = UiKit.CreateActionButton(scope, 2, "Insert PlayEffect Module", selection.HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value
        if #SelectedInstances == 0 then
            return
        end

        ChangeHistory.Record("Insert PlayEffect Module", function()
            VfxApiInjection.EnsureSharedModules(Bin)

            local Parent = SelectedInstances[1]
            local Existing = Parent:FindFirstChild("PlayEffect")
            if Existing then
                Existing:Destroy()
            end

            local PlayEffectModule = Bin.PlaybackModules.PlayEffect:Clone()
            PlayEffectModule.Name = "PlayEffect"
            PlayEffectModule.Parent = Parent
            SelectionService:Set({PlayEffectModule})
        end)
    end)

    local InsertEffectModuleTemplateButton = UiKit.CreateActionButton(scope, 3, "Insert Effect Module Template", selection.HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value
        if #SelectedInstances == 0 then
            return
        end

        ChangeHistory.Record("Insert Effect Module Template", function()
            local EffectModuleTemplate = Bin.PlaybackModules.EffectModuleTemplate:Clone()
            EffectModuleTemplate.Parent = SelectedInstances[1]
            SelectionService:Set({EffectModuleTemplate})
        end)
    end)

    local InjectApiCheckboxRow = UiKit.CreateRow(scope, 5)
    scope:New(Jian.Checkbox, {
        Parent = InjectApiCheckboxRow,
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 0, 20),
        Title = "Inject VFX API",
        Active = true,
        Value = InjectVfxApiEnabled,
    })

    local WorldSpaceAccelCheckboxRow = UiKit.CreateRow(scope, 6)
    scope:New(Jian.Checkbox, {
        Parent = WorldSpaceAccelCheckboxRow,
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 0, 20),
        Title = "World space acceleration for LockedToPart",
        Active = selection.HasParticleEmitterSelection,
        Value = WorldSpaceAccelEnabled,
    })

    scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 1,
        Text = "Animation",
        Active = true,

        [Seam.Children] = {
            AnimationButtons[1],
            AnimationButtons[2],
        },
    })
    scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 2,
        Text = "Programming",
        Active = true,

        [Seam.Children] = {
            InsertPlayEffectModuleButton,
            InsertEffectModuleTemplateButton,
            InjectApiCheckboxRow,
        },
    })
    scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 3,
        Text = "Behavior",
        Active = true,

        [Seam.Children] = {
            WorldSpaceAccelCheckboxRow,
        },
    })

    local function RefreshWorldSpaceAccelCheckbox()
        IsSyncingWorldSpaceAccel = true

        local HasEnabled = false
        local HasDisabled = false

        for _, instance in States.CurrentlySelected.Value do
            if instance:IsA("ParticleEmitter") then
                if WorldSpaceAcceleration.IsEnabled(instance) then
                    HasEnabled = true
                else
                    HasDisabled = true
                end
            end
        end

        WorldSpaceAccelEnabled.Value = HasEnabled and not HasDisabled
        IsSyncingWorldSpaceAccel = false
    end

    RefreshWorldSpaceAccelCheckbox()
    scope:OnChanged(States.CurrentlySelected, RefreshWorldSpaceAccelCheckbox)
    scope:OnChanged(InjectVfxApiEnabled, function()
        ChangeHistory.Record(if InjectVfxApiEnabled.Value then "Enable VFX API" else "Disable VFX API", function()
            if InjectVfxApiEnabled.Value then
                VfxApiInjection.Enable(Bin)
            else
                VfxApiInjection.Disable()
            end
        end)
    end)
    scope:OnChanged(WorldSpaceAccelEnabled, function()
        if IsSyncingWorldSpaceAccel then
            return
        end

        ChangeHistory.Record("Set World Space Acceleration", function()
            for _, instance in States.CurrentlySelected.Value do
                if instance:IsA("ParticleEmitter") then
                    WorldSpaceAcceleration.SetEnabled(instance, WorldSpaceAccelEnabled.Value)
                end
            end
        end)
    end)

    if InjectVfxApiEnabled.Value then
        VfxApiInjection.Enable(Bin)
    else
        VfxApiInjection.Disable()
    end

    return Widget
end

return Advanced

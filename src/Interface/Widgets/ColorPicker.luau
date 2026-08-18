local ColorPickerWidget = {}

-- Constants
local WIDGET_ID = "EffectDesignerSuiteColorPicker"

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))
local Components = Interface:FindFirstChild("Components")
local Modules = Interface:FindFirstChild("Modules")
local ColorPicker = require(Components:FindFirstChild("ColorPicker"))
local EffectOps = require(Modules:FindFirstChild("EffectOps"))

function ColorPickerWidget.Create(scope, session)
    local Widget = scope:New(Jian.Widget, {
        WidgetId = WIDGET_ID,
        Title = "Color Picker",
        InitialDockState = Enum.InitialDockState.Float,
        InitialEnabled = false,
        OverridePreviousState = false,
        DefaultWidth = 260,
        DefaultHeight = 260,
        MinimumWidth = 220,
        MinimumHeight = 245,
    }) :: DockWidgetPluginGui
    Widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    session.ColorPickerWidget = Widget

    scope:New(Jian.Background, {
        Parent = Widget,
    })

    local ColorPickerRoot = scope:New("Frame", {
        Parent = Widget,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    })

    scope:New(Jian.Text, {
        Parent = ColorPickerRoot,
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -24, 0, 20),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = scope:Computed(function(use)
            local Index = use(session.ActiveColorPointIndex)
            local Points = use(session.ColorSequencePoints)
            local Point = Index and Points[Index] or nil
            return if Point then string.format("Point at %.3f", Point.Time) else "Select a color point"
        end),
        Active = false,
    })

    scope:New(ColorPicker, {
        Parent = ColorPickerRoot,
        Position = UDim2.fromOffset(12, 34),
        Size = UDim2.new(1, -24, 0, 198),
        Value = session.ColorPickerValue,
        Active = scope:Computed(function(use)
            return use(session.ActiveColorPointIndex) ~= nil
        end),
    })

    scope:OnChanged(session.ColorPickerValue, function()
        if session.IsSyncingColorPicker then
            return
        end

        local Index = session.ActiveColorPointIndex.Value
        local ExistingPoint = Index and session.ColorSequencePoints.Value[Index] or nil
        if not ExistingPoint then
            return
        end

        local UpdatedPoints = table.clone(session.ColorSequencePoints.Value)
        UpdatedPoints[Index] = EffectOps.Color3ToOklabPoint(session.ColorPickerValue.Value, ExistingPoint.Time)
        session.ColorSequencePoints.Value = UpdatedPoints
    end)

    return Widget
end

return ColorPickerWidget

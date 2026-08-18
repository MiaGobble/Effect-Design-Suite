local CurveEditorWidget = {}

-- Constants
local WIDGET_ID = "EffectDesignerSuiteCurveEditor"
local WIDGET_TITLE = "Effect Designer Suite — Curve Editor"
local WIDGET_WIDTH = 360
local WIDGET_HEIGHT = 420

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Objects = Bin:FindFirstChild("Objects")
local Jian = require(Packages:FindFirstChild("Jian"))
local States = require(Objects:FindFirstChild("States"))
local Components = Interface:FindFirstChild("Components")
local Modules = Interface:FindFirstChild("Modules")
local CurveEditor = require(Components:FindFirstChild("CurveEditor"))
local UiKit = require(Modules:FindFirstChild("UiKit"))

function CurveEditorWidget.Create(scope, session)
    local Widget, Container = UiKit.CreateListWidget(
        scope,
        WIDGET_ID,
        WIDGET_TITLE,
        false,
        WIDGET_WIDTH,
        WIDGET_HEIGHT,
        Enum.InitialDockState.Float
    )

    session.CurveEditorWidget = Widget

    scope:New(Jian.Text, {
        Parent = Container,
        LayoutOrder = 1,
        Text = scope:Computed(function(use)
            local Property = use(session.CurvePropertyText)
            if Property == "" then
                return "Select a curve property from Core"
            end

            return "Editing " .. Property
        end),
        Size = UDim2.new(1, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    scope:New(CurveEditor, {
        Parent = Container,
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 180),
        Points = session.CurvePoints,
        Active = States.IsEmittable,
    })

    local CurveMinRangeRow = UiKit.CreateRow(scope, 3)
    CurveMinRangeRow.Parent = Container
    UiKit.CreateLabel(scope, CurveMinRangeRow, "Range Min")
    UiKit.CreateBoundTextBox(
        scope,
        CurveMinRangeRow,
        session.CurveMinRangeText,
        States.IsEmittable,
        "0",
        UDim2.fromScale(0.35, 0),
        UDim2.fromScale(0.65, 1)
    )

    local CurveMaxRangeRow = UiKit.CreateRow(scope, 4)
    CurveMaxRangeRow.Parent = Container
    UiKit.CreateLabel(scope, CurveMaxRangeRow, "Range Max")
    UiKit.CreateBoundTextBox(
        scope,
        CurveMaxRangeRow,
        session.CurveMaxRangeText,
        States.IsEmittable,
        "10",
        UDim2.fromScale(0.35, 0),
        UDim2.fromScale(0.65, 1)
    )

    local CurveApplyButton = UiKit.CreateActionButton(scope, 5, "Apply Curve", States.IsEmittable, function()
        session.ApplyCurve()
    end)
    CurveApplyButton.Parent = Container

    return Widget
end

return CurveEditorWidget

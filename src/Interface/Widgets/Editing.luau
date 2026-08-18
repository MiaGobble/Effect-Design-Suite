local Editing = {}

-- Constants
local WIDGET_ID = "EffectDesignerSuiteEditing"
local WIDGET_TITLE = "Effect Designer Suite — Editing"
local WIDGET_WIDTH = 320
local WIDGET_HEIGHT = 480
local MATH_OPERATIONS = {
    { Order = 4, Text = "Add", Operation = "add" },
    { Order = 5, Text = "Subtract", Operation = "subtract" },
    { Order = 6, Text = "Multiply", Operation = "multiply" },
    { Order = 7, Text = "Divide", Operation = "divide" },
}

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Objects = Bin:FindFirstChild("Objects")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))
local States = require(Objects:FindFirstChild("States"))
local EmitUtils = require(Interface:FindFirstChild("EmitUtils"))
local Components = Interface:FindFirstChild("Components")
local Modules = Interface:FindFirstChild("Modules")
local SliderInput = require(Components:FindFirstChild("SliderInput"))
local UiKit = require(Modules:FindFirstChild("UiKit"))
local PropertyMaps = require(Modules:FindFirstChild("PropertyMaps"))
local EffectOps = require(Modules:FindFirstChild("EffectOps"))

function Editing.Create(scope, _session, _selection)
    local Widget, Container = UiKit.CreateListWidget(
        scope,
        WIDGET_ID,
        WIDGET_TITLE,
        false,
        WIDGET_WIDTH,
        WIDGET_HEIGHT,
        Enum.InitialDockState.Float
    )

    local ResizeMultiplierValue = scope:Value(1)
    local MathPropertyText = scope:Value("Size")
    local MathAmountValue = scope:Value(3)
    local PreviewPathsEnabled = scope:Value(false)

    local ResizeMultiplierSlider = scope:New(SliderInput, {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 58),
        Title = "Multiplier",
        Min = 0.5,
        Max = 2,
        Step = 0.1,
        Value = ResizeMultiplierValue,
        AllowOutOfRangeText = true,
        Active = States.IsEmittable,
    })

    local ResizeApplyButton = UiKit.CreateActionButton(scope, 3, "Apply Resize", States.IsEmittable, function()
        EffectOps.ApplyResizeMultiplier(ResizeMultiplierValue.Value, States.CurrentlySelected.Value)
    end)

    local MathAmountSlider = scope:New(SliderInput, {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 58),
        Title = "Amount",
        Min = -10,
        Max = 10,
        Step = 0.1,
        Value = MathAmountValue,
        AllowOutOfRangeText = true,
        Active = States.IsEmittable,
    })

    local MathPropertyRow = UiKit.CreateRow(scope, 3)
    UiKit.CreateLabel(scope, MathPropertyRow, "Property")
    UiKit.CreateBoundTextBox(
        scope,
        MathPropertyRow,
        MathPropertyText,
        States.IsEmittable,
        "Size",
        UDim2.fromScale(0.35, 0),
        UDim2.fromScale(0.65, 1),
        {
            FocusLost = function()
                MathPropertyText.Value = PropertyMaps.NormalizeParticleProperty(MathPropertyText.Value)
            end,
        }
    )

    local function RunMathOperation(operation : string)
        local Value = MathAmountValue.Value
        local Property = PropertyMaps.NormalizeParticleProperty(MathPropertyText.Value)

        EffectOps.ApplyMathOperation(Value, Property, operation, States.CurrentlySelected.Value)
        MathPropertyText.Value = Property
    end

    local MathButtons = {}
    for _, spec in MATH_OPERATIONS do
        table.insert(MathButtons, UiKit.CreateActionButton(scope, spec.Order, spec.Text, States.IsEmittable, function()
            RunMathOperation(spec.Operation)
        end))
    end

    local PreviewPathsCheckboxRow = UiKit.CreateRow(scope, 4)
    scope:New(Jian.Checkbox, {
        Parent = PreviewPathsCheckboxRow,
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 0, 20),
        Title = "Preview Paths",
        Active = true,
        Value = PreviewPathsEnabled,
    })

    scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 1,
        Text = "Resize",
        Active = true,

        [Seam.Children] = {
            ResizeMultiplierSlider,
            ResizeApplyButton,
        },
    })
    scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 2,
        Text = "Math Operations",
        Active = true,

        [Seam.Children] = {
            MathAmountSlider,
            MathPropertyRow,
            MathButtons[1],
            MathButtons[2],
            MathButtons[3],
            MathButtons[4],
        },
    })
    scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 3,
        Text = "Preview paths",
        Active = true,

        [Seam.Children] = {
            PreviewPathsCheckboxRow,
        },
    })

    scope:OnChanged(PreviewPathsEnabled, function()
        EmitUtils:SetPathPreviewEnabled(PreviewPathsEnabled.Value)
    end)
    EmitUtils:SetPathPreviewEnabled(PreviewPathsEnabled.Value)

    return Widget
end

return Editing

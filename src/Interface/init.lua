local Interface = {}

local PARTICLE_PROPERTIES = {
    "Size",
    "Color",
    "Transparency",
    "Speed",
    "Acceleration",
    "Lifetime",
    "Rate",
    "SpreadAngle",
    "LightEmission",
    "LightInfluence",
    "Texture",
}

local Selection = game:GetService("Selection")

local Bin = script.Parent
local Objects = Bin:FindFirstChild("Objects")
local Packages = Bin:FindFirstChild("Packages")
local EmitUtils = require(script.EmitUtils)
local States = require(Objects:FindFirstChild("States"))
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))

local InterfaceScope = nil

local function NormalizeParticleProperty(PropertyName : string)
    local LowerName = PropertyName:lower()

    for _, Property in PARTICLE_PROPERTIES do
        if Property:lower():sub(1, #LowerName) == LowerName then
            return Property
        end
    end

    return PropertyName
end

local function ApplyMathOperation(Value: number, Property: string, Operation: string, Instances: {Instance})
    if not Value or Property == "" then
        return
    end

    for _, Instance in Instances do
        if not (Instance:IsA("ParticleEmitter") and Instance[Property]) then
            continue
        end

        local PropertyType = typeof(Instance[Property])

        if PropertyType == "NumberSequence" then
            local OldSequence = Instance[Property]
            local NewKeypoints = {}

            for _, Keypoint in OldSequence.Keypoints do
                local NewValue, NewEnvelope

                if Operation == "add" then
                    NewValue = Keypoint.Value + Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope + Value)
                elseif Operation == "subtract" then
                    NewValue = Keypoint.Value - Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope - Value)
                elseif Operation == "multiply" then
                    NewValue = Keypoint.Value * Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope * Value)
                elseif Operation == "divide" then
                    if Value == 0 then
                        continue
                    end

                    NewValue = Keypoint.Value / Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope / Value)
                end

                table.insert(NewKeypoints, NumberSequenceKeypoint.new(
                    Keypoint.Time,
                    NewValue,
                    NewEnvelope
                ))
            end

            Instance[Property] = NumberSequence.new(NewKeypoints)
        elseif PropertyType == "NumberRange" then
            local OldMin = Instance[Property].Min
            local OldMax = Instance[Property].Max
            local NewMin, NewMax

            if Operation == "add" then
                NewMin = OldMin + Value
                NewMax = OldMax + Value
            elseif Operation == "subtract" then
                NewMin = OldMin - Value
                NewMax = OldMax - Value
            elseif Operation == "multiply" then
                NewMin = OldMin * Value
                NewMax = OldMax * Value
            elseif Operation == "divide" then
                if Value == 0 then
                    continue
                end

                NewMin = OldMin / Value
                NewMax = OldMax / Value
            end

            Instance[Property] = NumberRange.new(NewMin, NewMax)
        elseif PropertyType == "number" then
            if Operation == "add" then
                Instance[Property] = Instance[Property] + Value
            elseif Operation == "subtract" then
                Instance[Property] = Instance[Property] - Value
            elseif Operation == "multiply" then
                Instance[Property] = Instance[Property] * Value
            elseif Operation == "divide" then
                if Value == 0 then
                    continue
                end

                Instance[Property] = Instance[Property] / Value
            end
        end
    end
end

local function CreateRow(Scope, LayoutOrder : number, Children : {any}?)
    return Scope:New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        LayoutOrder = LayoutOrder,

        [Seam.Children] = Children,
    })
end

local function CreateLabel(Scope, Parent : Instance, Text : any)
    return Scope:New(Jian.Text, {
        Parent = Parent,
        Text = Text,
        Size = UDim2.new(0.33, -8, 1, 0),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function BindTextBox(Scope, TextBox : TextBox, State)
    Scope:AddObject(TextBox:GetPropertyChangedSignal("Text"):Connect(function()
        State.Value = TextBox.Text
    end))
end

local function CreateBoundTextBox(Scope, Parent : Instance, State, Active, PlaceholderText : string, Position : UDim2, Size : UDim2)
    local TextBox = Scope:New(Jian.TextBox, {
        Parent = Parent,
        Text = State,
        Active = Active,
        PlaceholderText = PlaceholderText,
        Position = Position,
        Size = Size,
    })

    BindTextBox(Scope, TextBox, State)

    return TextBox
end

local function CreateActionButton(Scope, LayoutOrder : number, Text : string, Active, Callback)
    return Scope:New(Jian.TextButton, {
        LayoutOrder = LayoutOrder,
        Text = Text,
        Active = Active,
        Size = UDim2.new(1, 0, 0, 35),
        [Seam.OnEvent("Activated")] = Callback,
    })
end

local function SyncSelectionAttribute(State, AttributeName : string)
    local CurrentInstance = States.PrimarySelected.Value

    if not CurrentInstance then
        State.Value = ""
        return
    end

    State.Value = tostring(CurrentInstance:GetAttribute(AttributeName) or "")
end

function Interface:Init() : DockWidgetPluginGui
    if InterfaceScope then
        InterfaceScope:Destroy()
        InterfaceScope = nil
    end

    local Scope = Seam.Scope(Seam)
    InterfaceScope = Scope

    local MainWidget = Scope:New(Jian.Widget, {
        WidgetId = "EffectDesignerSuite",
        Title = "Effect Designer Suite",
        InitialDockState = Enum.InitialDockState.Left,
        InitialEnabled = false,
        OverridePreviousState = false,
        DefaultWidth = 320,
        DefaultHeight = 480,
        MinimumWidth = 320,
        MinimumHeight = 320,
    }) :: DockWidgetPluginGui

    local HasEditableSelection = Scope:Computed(function(Use)
        return #Use(States.CurrentlySelected) > 0
    end)

    local HasSingleSelection = Scope:Computed(function(Use)
        return Use(States.IsEmittable) and #Use(States.CurrentlySelected) == 1
    end)

    local HasRawSelection = Scope:Computed(function(Use)
        return #Use(States.RawSelection) > 0
    end)

    local SelectionSummary = Scope:Computed(function(Use)
        local Selected = Use(States.CurrentlySelected)

        if #Selected == 0 then
            return "No valid emitters selected"
        end

        if #Selected == 1 then
            return "Editing 1 valid object"
        end

        return string.format("Editing %d valid objects", #Selected)
    end)

    local EmitCountText = Scope:Value("")
    local EmitDelayText = Scope:Value("")
    local EmitDurationText = Scope:Value("")
    local RepeatEmitDelayText = Scope:Value(tostring(States.RepeatEmitDelay.Value))
    local CopyPropertyText = Scope:Value("Size")
    local MathPropertyText = Scope:Value("Size")
    local MathValueText = Scope:Value("3")
    local CopiedValue = Scope:Value(nil)

    MainWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    Scope:New(Jian.Background, {
        Parent = MainWidget,
    })

    local Container = Scope:New(Jian.ScrollingList, {
        Parent = MainWidget,
        Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 8,

        [Seam.Children] = {
            Scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 16),
                PaddingBottom = UDim.new(0, 16),
                PaddingLeft = UDim.new(0, 16),
                PaddingRight = UDim.new(0, 16),
            }),
        },
    })

    Scope:New(Jian.Text, {
        Parent = Container,
        Text = SelectionSummary,
        Size = UDim2.new(1, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 0,
        Active = HasEditableSelection,
    })

    local function CreateCorePropertyRow(LayoutOrder : number, LabelText : string, AttributeName : string, TextState)
        local Row = CreateRow(Scope, LayoutOrder)

        CreateLabel(Scope, Row, LabelText)

        local TextBox = CreateBoundTextBox(
            Scope,
            Row,
            TextState,
            HasEditableSelection,
            "0",
            UDim2.fromScale(0.35, 0),
            UDim2.fromScale(0.65, 1)
        )

        Scope:AddObject(TextBox.FocusLost:Connect(function()
            local CurrentlySelected = States.CurrentlySelected.Value

            if #CurrentlySelected == 0 then
                return
            end

            local Number = tonumber(TextState.Value)

            if not Number or Number == 0 then
                return
            end

            for _, Instance in CurrentlySelected do
                Instance:SetAttribute(AttributeName, Number)
            end
        end))

        return Row
    end

    local CoreEmitCountRow = CreateCorePropertyRow(2, "Emit Count", "EmitCount", EmitCountText)
    local CoreEmitDelayRow = CreateCorePropertyRow(3, "Emit Delay", "EmitDelay", EmitDelayText)
    local CoreEmitDurationRow = CreateCorePropertyRow(4, "Emit Duration", "EmitDuration", EmitDurationText)

    local EmitButton = CreateActionButton(Scope, 2, "Emit", States.IsEmittable, function()
        EmitUtils:EmitCurrent()
    end)

    local RepeatRow = CreateRow(Scope, 3)
    local RepeatDelayBox = CreateBoundTextBox(
        Scope,
        RepeatRow,
        RepeatEmitDelayText,
        States.RepeatEmit,
        "Repeat delay",
        UDim2.new(0, 0, 0, 0),
        UDim2.fromScale(0.48, 1)
    )

    Scope:AddObject(RepeatDelayBox.FocusLost:Connect(function()
        local Delay = tonumber(RepeatEmitDelayText.Value)

        if not Delay then
            RepeatEmitDelayText.Value = tostring(States.RepeatEmitDelay.Value)
            return
        end

        States.RepeatEmitDelay.Value = Delay
    end))

    Scope:New(Jian.Checkbox, {
        Parent = RepeatRow,
        Position = UDim2.new(0.52, 0, 0, 8),
        Size = UDim2.new(0.48, 0, 0, 20),
        Title = "Repeat Emit",
        Active = true,
        Value = States.RepeatEmit,
    })

    local CopyPropertyBox = Scope:New(Jian.TextBox, {
        LayoutOrder = 2,
        Text = CopyPropertyText,
        Active = States.IsEmittable,
        PlaceholderText = "Property name",
        Size = UDim2.new(1, 0, 0, 35),
    })
    BindTextBox(Scope, CopyPropertyBox, CopyPropertyText)
    Scope:AddObject(CopyPropertyBox.FocusLost:Connect(function()
        CopyPropertyText.Value = NormalizeParticleProperty(CopyPropertyText.Value)
    end))

    local CopyPasteButtons = CreateRow(Scope, 3)
    Scope:New(Jian.TextButton, {
        Parent = CopyPasteButtons,
        Text = "Copy",
        Active = HasSingleSelection,
        Size = UDim2.fromScale(0.48, 1),
        [Seam.OnEvent("Activated")] = function()
            local SelectedInstances = States.CurrentlySelected.Value

            if #SelectedInstances == 0 then
                return
            end

            local FirstInstance = SelectedInstances[1]

            if not FirstInstance:IsA("ParticleEmitter") then
                return
            end

            local SelectedProperty = NormalizeParticleProperty(CopyPropertyText.Value)
            local Success, Value = pcall(function()
                return FirstInstance[SelectedProperty]
            end)

            if Success then
                CopiedValue.Value = Value
                CopyPropertyText.Value = SelectedProperty
            end
        end,
    })

    Scope:New(Jian.TextButton, {
        Parent = CopyPasteButtons,
        Text = "Paste",
        Active = States.IsEmittable,
        Position = UDim2.fromScale(0.52, 0),
        Size = UDim2.fromScale(0.48, 1),
        [Seam.OnEvent("Activated")] = function()
            local SelectedInstances = States.CurrentlySelected.Value
            local SelectedProperty = NormalizeParticleProperty(CopyPropertyText.Value)
            local Value = CopiedValue.Value

            if Value == nil then
                return
            end

            for _, Instance in SelectedInstances do
                if Instance:IsA("ParticleEmitter") then
                    Instance[SelectedProperty] = Value
                end
            end
        end,
    })

    local MathAmountRow = CreateRow(Scope, 2)
    CreateLabel(Scope, MathAmountRow, "Amount")
    CreateBoundTextBox(
        Scope,
        MathAmountRow,
        MathValueText,
        States.IsEmittable,
        "3",
        UDim2.fromScale(0.35, 0),
        UDim2.fromScale(0.65, 1)
    )

    local MathPropertyRow = CreateRow(Scope, 3)
    CreateLabel(Scope, MathPropertyRow, "Property")
    local MathPropertyBox = CreateBoundTextBox(
        Scope,
        MathPropertyRow,
        MathPropertyText,
        States.IsEmittable,
        "Size",
        UDim2.fromScale(0.35, 0),
        UDim2.fromScale(0.65, 1)
    )

    Scope:AddObject(MathPropertyBox.FocusLost:Connect(function()
        MathPropertyText.Value = NormalizeParticleProperty(MathPropertyText.Value)
    end))

    local function RunMathOperation(Operation : string)
        local Value = tonumber(MathValueText.Value)
        local Property = NormalizeParticleProperty(MathPropertyText.Value)

        ApplyMathOperation(Value, Property, Operation, States.CurrentlySelected.Value)
        MathPropertyText.Value = Property
    end

    local MathAddButton = CreateActionButton(Scope, 4, "Add", States.IsEmittable, function()
        RunMathOperation("add")
    end)
    local MathSubtractButton = CreateActionButton(Scope, 5, "Subtract", States.IsEmittable, function()
        RunMathOperation("subtract")
    end)
    local MathMultiplyButton = CreateActionButton(Scope, 6, "Multiply", States.IsEmittable, function()
        RunMathOperation("multiply")
    end)
    local MathDivideButton = CreateActionButton(Scope, 7, "Divide", States.IsEmittable, function()
        RunMathOperation("divide")
    end)

    local CreateBezierAnimationButton = CreateActionButton(Scope, 2, "Create Bezier Animation", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        local Indicator = EmitUtils:CreateNewAnimationIndicator(SelectedInstances[1], "Bezier")
        Selection:Set({Indicator})
    end)

    local CreateTweenAnimationButton = CreateActionButton(Scope, 3, "Create Tween Animation", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        local Indicator = EmitUtils:CreateNewAnimationIndicator(SelectedInstances[1], "Tween")
        Selection:Set({Indicator})
    end)

    local InsertPlayEffectModuleButton = CreateActionButton(Scope, 2, "Insert PlayEffect Module", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        local PlayEffectModule = Bin.PlaybackModules.PlayEffect:Clone()
        PlayEffectModule.Parent = SelectedInstances[1]
        Selection:Set({PlayEffectModule})
    end)

    local InsertEffectModuleTemplateButton = CreateActionButton(Scope, 3, "Insert Effect Module Template", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        local EffectModuleTemplate = Bin.PlaybackModules.EffectModuleTemplate:Clone()
        EffectModuleTemplate.Parent = SelectedInstances[1]
        Selection:Set({EffectModuleTemplate})
    end)

    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 1,
        Text = "Core Properties",
        Active = true,
        DefaultOpen = true,

        [Seam.Children] = {
            CoreEmitCountRow,
            CoreEmitDelayRow,
            CoreEmitDurationRow,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 2,
        Text = "Emit Actions",
        Active = true,
        DefaultOpen = true,

        [Seam.Children] = {
            EmitButton,
            RepeatRow,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 3,
        Text = "Copy/Paste Properties",
        Active = true,

        [Seam.Children] = {
            CopyPropertyBox,
            CopyPasteButtons,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 4,
        Text = "Math Operations",
        Active = true,

        [Seam.Children] = {
            MathAmountRow,
            MathPropertyRow,
            MathAddButton,
            MathSubtractButton,
            MathMultiplyButton,
            MathDivideButton,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 5,
        Text = "Animation Indicators",
        Active = true,

        [Seam.Children] = {
            CreateBezierAnimationButton,
            CreateTweenAnimationButton,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 6,
        Text = "Programmer Resources",
        Active = true,

        [Seam.Children] = {
            InsertPlayEffectModuleButton,
            InsertEffectModuleTemplateButton,
        },
    })

    local function RefreshCoreFields()
        SyncSelectionAttribute(EmitCountText, "EmitCount")
        SyncSelectionAttribute(EmitDelayText, "EmitDelay")
        SyncSelectionAttribute(EmitDurationText, "EmitDuration")
    end

    RefreshCoreFields()
    Scope:AddObject(Seam.OnChanged(States.PrimarySelected, RefreshCoreFields))
    Scope:AddObject(Seam.OnChanged(States.RepeatEmitDelay, function()
        RepeatEmitDelayText.Value = tostring(States.RepeatEmitDelay.Value)
    end))
    Scope:AddObject(Seam.OnChanged(States.RepeatEmit, function()
        if States.RepeatEmit.Value then
            EmitUtils:EnableRepeatEmit()
        else
            EmitUtils:DisableRepeatEmit()
        end
    end))

    EmitUtils:SetWidget(MainWidget)

    return MainWidget
end

return Interface

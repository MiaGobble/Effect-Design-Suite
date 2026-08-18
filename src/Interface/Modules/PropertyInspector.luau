local PropertyInspector = {}

-- Constants
local CURVE_PREVIEW_LINE_SAMPLES = 48
local CURVE_PREVIEW_GRADIENT_SAMPLES = 19

-- Services
local HttpService = game:GetService("HttpService")

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Objects = Bin:FindFirstChild("Objects")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))
local States = require(Objects:FindFirstChild("States"))
local Components = Interface:FindFirstChild("Components")
local Dropdown = require(Components:FindFirstChild("Dropdown"))
local PropertyMaps = require(script.Parent:FindFirstChild("PropertyMaps"))
local PropertyValues = require(script.Parent:FindFirstChild("PropertyValues"))
local UiKit = require(script.Parent:FindFirstChild("UiKit"))
local EffectOps = require(script.Parent:FindFirstChild("EffectOps"))
local EditorSession = require(script.Parent:FindFirstChild("EditorSession"))
local SelectionQueries = require(script.Parent:FindFirstChild("SelectionQueries"))

local function GetPreviewNumberSequence(instance, property)
    local ReadSuccess, Value = pcall(function()
        return instance[property]
    end)
    if ReadSuccess and typeof(Value) == "NumberSequence" then
        return Value
    end

    local EncodedPoints = instance:GetAttribute(EditorSession.CurveAttributeName(property))
    local EncodedMinRange = instance:GetAttribute(EditorSession.CurveRangeAttributeName(property, "MinRange"))
    local EncodedMaxRange = instance:GetAttribute(EditorSession.CurveRangeAttributeName(property, "MaxRange"))
    if typeof(EncodedPoints) == "string" then
        local DecodeSuccess, Decoded = pcall(function()
            return HttpService:JSONDecode(EncodedPoints)
        end)
        if DecodeSuccess and typeof(Decoded) == "table" and #Decoded >= 2 then
            local MinRange = tonumber(EncodedMinRange) or 0
            local MaxRange = tonumber(EncodedMaxRange) or 1
            return EffectOps.BuildNumberSequenceFromCurve(Decoded, MinRange, MaxRange)
        end
    end

    return NumberSequence.new(0.5)
end

local function GetPreviewColorSequence(instance)
    if SelectionQueries.HasColorSequence(instance) then
        return instance.Color
    end

    local EncodedPoints = instance:GetAttribute(EditorSession.COLOR_SEQUENCE_ATTRIBUTE)
    if typeof(EncodedPoints) == "string" then
        local DecodeSuccess, Decoded = pcall(function()
            return HttpService:JSONDecode(EncodedPoints)
        end)
        if DecodeSuccess and typeof(Decoded) == "table" then
            return EffectOps.BuildColorSequenceFromOklabPoints(Decoded)
        end
    end

    local ColorSuccess, Color = pcall(function()
        return instance.Color
    end)
    if ColorSuccess and typeof(Color) == "Color3" then
        return ColorSequence.new(Color)
    end

    return ColorSequence.new(Color3.new(1, 1, 1))
end

local function UpdateCurvePreview(previewRoot, sequence)
    local Path = previewRoot:FindFirstChild("CurvePath")
    local Gradient = previewRoot:FindFirstChildWhichIsA("UIGradient")
    if typeof(sequence) ~= "NumberSequence" then
        return
    end

    local MinValue, MaxValue = PropertyValues.GetNumberSequenceRange(sequence)
    local ValueRange = MaxValue - MinValue
    local ControlPoints = {}
    local ColorKeys = {}

    for index = 0, CURVE_PREVIEW_LINE_SAMPLES do
        local Time = index / CURVE_PREVIEW_LINE_SAMPLES
        local Value = PropertyValues.SampleNumberSequence(sequence, Time)
        local Alpha = math.clamp((Value - MinValue) / ValueRange, 0, 1)
        table.insert(ControlPoints, { Time = Time, Alpha = Alpha })
    end

    for index = 0, CURVE_PREVIEW_GRADIENT_SAMPLES do
        local Time = index / CURVE_PREVIEW_GRADIENT_SAMPLES
        local Value = PropertyValues.SampleNumberSequence(sequence, Time)
        local Alpha = math.clamp((Value - MinValue) / ValueRange, 0, 1)
        table.insert(ColorKeys, ColorSequenceKeypoint.new(Time, Color3.fromRGB(Alpha * 220 + 35, Alpha * 220 + 35, Alpha * 230 + 25)))
    end

    if Path then
        local PathPoints = {}
        local PathSuccess = pcall(function()
            for _, sample in ControlPoints do
                table.insert(PathPoints, Path2DControlPoint.new(UDim2.fromScale(sample.Time, 1 - sample.Alpha)))
            end
            Path.Closed = false
            Path:SetControlPoints(PathPoints)
        end)
        Path.Visible = PathSuccess
    end

    if Gradient then
        pcall(function()
            Gradient.Color = ColorSequence.new(ColorKeys)
        end)
    end
end

local function ApplyCFrameComponentVector(property, kind, vector)
    for _, target in SelectionQueries.GetPropertyEditTargets() do
        pcall(function()
            local Current = PropertyValues.ReadInstanceCFrame(target, property)
            if kind == "Orientation" then
                target[property] = PropertyValues.CFrameFromPositionAndOrientation(Current.Position, vector)
            else
                target[property] = PropertyValues.CFrameFromPositionAndOrientation(vector, PropertyValues.GetCFrameOrientationDegrees(Current))
            end
        end)
    end
end

local function AssignProperty(property, value)
    for _, target in SelectionQueries.GetPropertyEditTargets() do
        pcall(function()
            target[property] = value
        end)
    end
end

local function CreateSplitNumericInputs(scope, parent, position, size, placeholders, getNumbers, applyNumbers, instance, property)
    local Count = #placeholders
    local GapDeduction = math.ceil(4 * (Count - 1) / Count)
    local Host = scope:New("Frame", {
        Parent = parent,
        Position = position,
        Size = size,
        BackgroundTransparency = 1,

        [Seam.Children] = {
            scope:New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
                VerticalAlignment = Enum.VerticalAlignment.Center,
            }),
        },
    })

    local Numbers = getNumbers()
    local FieldStates = {}
    local FocusedCount = 0

    for index, placeholder in placeholders do
        local FieldState = scope:Value(tostring(Numbers[index] or 0))
        FieldStates[index] = FieldState

        local Box = UiKit.CreateBoundTextBox(
            scope,
            Host,
            FieldState,
            true,
            placeholder,
            UDim2.fromOffset(0, 0),
            UDim2.new(1 / Count, -GapDeduction, 1, -4),
            {
                Focused = function()
                    FocusedCount += 1
                end,
                FocusLost = function()
                    FocusedCount = math.max(FocusedCount - 1, 0)

                    local Parsed = {}
                    for fieldIndex, fieldState in FieldStates do
                        local Number = tonumber(fieldState.Value)
                        if not Number then
                            local Latest = getNumbers()
                            for resetIndex, resetState in FieldStates do
                                resetState.Value = tostring(Latest[resetIndex] or 0)
                            end
                            return
                        end

                        Parsed[fieldIndex] = Number
                    end

                    applyNumbers(Parsed)
                end,
            }
        )
        Box.LayoutOrder = index
    end

    scope:OnChanged(instance, function(changedProperty)
        if changedProperty ~= property or FocusedCount > 0 then
            return
        end

        local Latest = getNumbers()
        for index, fieldState in FieldStates do
            fieldState.Value = tostring(Latest[index] or 0)
        end
    end)
end

local function CreateSequencePreviewButton(scope, parent, size, isColorSequence, instance, property, callback)
    local Button = scope:New("TextButton", {
        Parent = parent,
        Position = UDim2.new(0.28, 0, 0, 4),
        Size = UDim2.new(size.X.Scale, size.X.Offset, 1, -8),
        BackgroundColor3 = if isColorSequence then Color3.new(1, 1, 1) else Color3.fromRGB(28, 28, 32),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        [Seam.OnEvent("Activated")] = callback,
    })

    scope:New("UICorner", {
        Parent = Button,
        CornerRadius = UDim.new(0, 6),
    })
    scope:New("UIStroke", {
        Parent = Button,
        Color = Color3.fromRGB(56, 56, 56),
        Thickness = 1,
    })

    local Gradient = scope:New("UIGradient", {
        Parent = Button,
    })

    if not isColorSequence then
        pcall(function()
            local Path = Instance.new("Path2D")
            Path.Name = "CurvePath"
            Path.Thickness = 1.5
            Path.Color3 = Color3.fromRGB(186, 214, 255)
            Path.ZIndex = 2
            Path.Closed = false
            Path.Parent = Button
        end)
    end

    local function RefreshPreview()
        if isColorSequence then
            Gradient.Color = GetPreviewColorSequence(instance)
        else
            UpdateCurvePreview(Button, GetPreviewNumberSequence(instance, property))
        end
    end

    RefreshPreview()
    scope:OnChanged(instance, function(changedProperty)
        if changedProperty == property then
            RefreshPreview()
        end
    end)
    scope:AddObject(instance.AttributeChanged:Connect(RefreshPreview))

    return Button
end

local function CreateBooleanEditor(context)
    local BoolState = context.Scope:Value(context.CurrentValue == true)
    local IsSyncing = false

    context.Scope:New(Jian.Checkbox, {
        Parent = context.Row,
        Position = UDim2.new(0.28, 0, 0, 8),
        Size = UDim2.new(context.ValueSize.X.Scale, context.ValueSize.X.Offset, 0, 20),
        Title = "",
        Active = true,
        Value = BoolState,
    })

    context.Scope:OnChanged(BoolState, function()
        if IsSyncing then
            return
        end

        AssignProperty(context.Property, BoolState.Value)
    end)

    context.Scope:OnChanged(context.Instance, function(changedProperty)
        if changedProperty ~= context.Property then
            return
        end

        local ValueSuccess, Value = pcall(function()
            return context.Instance[context.Property]
        end)
        if not ValueSuccess or Value == BoolState.Value then
            return
        end

        IsSyncing = true
        BoolState.Value = Value == true
        IsSyncing = false
    end)
end

local function CreateVector3Editor(context)
    CreateSplitNumericInputs(
        context.Scope,
        context.Row,
        UDim2.new(0.28, 0, 0, 0),
        context.ValueSize,
        { "X", "Y", "Z" },
        function()
            if context.CFrameKind then
                local Vector = PropertyValues.GetCFrameComponentVector(context.Instance, context.Property, context.CFrameKind)
                return { Vector.X, Vector.Y, Vector.Z }
            end

            local LatestSuccess, LatestValue = pcall(function()
                return context.Instance[context.Property]
            end)
            if LatestSuccess and typeof(LatestValue) == "Vector3" then
                return { LatestValue.X, LatestValue.Y, LatestValue.Z }
            end

            return { 0, 0, 0 }
        end,
        function(numbers)
            local Value = Vector3.new(numbers[1], numbers[2], numbers[3])
            if context.CFrameKind then
                ApplyCFrameComponentVector(context.Property, context.CFrameKind, Value)
                return
            end

            AssignProperty(context.Property, Value)
        end,
        context.Instance,
        context.Property
    )
end

local function CreateNumberRangeEditor(context)
    CreateSplitNumericInputs(
        context.Scope,
        context.Row,
        UDim2.new(0.28, 0, 0, 0),
        context.ValueSize,
        { "Min", "Max" },
        function()
            local LatestSuccess, LatestValue = pcall(function()
                return context.Instance[context.Property]
            end)
            if LatestSuccess and typeof(LatestValue) == "NumberRange" then
                return { LatestValue.Min, LatestValue.Max }
            end

            return { 0, 0 }
        end,
        function(numbers)
            local MinValue = numbers[1]
            local MaxValue = numbers[2]
            if MinValue > MaxValue then
                MinValue, MaxValue = MaxValue, MinValue
            end

            AssignProperty(context.Property, NumberRange.new(MinValue, MaxValue))
        end,
        context.Instance,
        context.Property
    )
end

local function CreateEnumEditor(context)
    local EnumState = context.Scope:Value(context.CurrentValue.Name)
    local EnumOptions = PropertyValues.GetEnumItemNames(context.CurrentValue)
    local IsSyncing = false
    local DropdownHost = context.Scope:New("Frame", {
        Parent = context.Row,
        Position = UDim2.new(0.28, 0, 0, 0),
        Size = context.ValueSize,
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        ZIndex = 40,
    })

    context.Scope:New(Dropdown, {
        Parent = DropdownHost,
        Value = EnumState,
        Options = EnumOptions,
        Active = true,
    })

    context.Scope:OnChanged(EnumState, function()
        if IsSyncing then
            return
        end

        local ItemSuccess, Item = pcall(function()
            return context.CurrentValue.EnumType[EnumState.Value]
        end)
        if not ItemSuccess or typeof(Item) ~= "EnumItem" then
            return
        end

        AssignProperty(context.Property, Item)
    end)

    context.Scope:OnChanged(context.Instance, function(changedProperty)
        if changedProperty ~= context.Property then
            return
        end

        local ValueSuccess, Value = pcall(function()
            return context.Instance[context.Property]
        end)
        if not ValueSuccess or typeof(Value) ~= "EnumItem" or Value.Name == EnumState.Value then
            return
        end

        IsSyncing = true
        EnumState.Value = Value.Name
        IsSyncing = false
    end)
end

local function CreateTextEditor(context)
    local TextState = context.Scope:Value(if context.Success then PropertyValues.Format(context.CurrentValue) else "")
    local IsFocused = false

    UiKit.CreateBoundTextBox(
        context.Scope,
        context.Row,
        TextState,
        true,
        context.Property,
        UDim2.new(0.28, 0, 0, 0),
        context.ValueSize,
        {
            Focused = function()
                IsFocused = true
            end,
            FocusLost = function()
                IsFocused = false

                local LatestSuccess, LatestValue = pcall(function()
                    return context.Instance[context.Property]
                end)
                if not LatestSuccess then
                    return
                end

                local Parsed = PropertyValues.Parse(LatestValue, TextState.Value)
                if Parsed == nil then
                    TextState.Value = PropertyValues.Format(LatestValue)
                    return
                end

                AssignProperty(context.Property, Parsed)
            end,
        }
    )

    context.Scope:OnChanged(context.Instance, function(changedProperty)
        if changedProperty ~= context.Property or IsFocused then
            return
        end

        local ValueSuccess, Value = pcall(function()
            return context.Instance[context.Property]
        end)
        if ValueSuccess then
            TextState.Value = PropertyValues.Format(Value)
        end
    end)
end

local function CreateSequenceEditor(context)
    CreateSequencePreviewButton(
        context.Scope,
        context.Row,
        context.ValueSize,
        context.IsColorSequence,
        context.Instance,
        context.Property,
        function()
            if context.IsColorSequence then
                context.Session.OpenColorSequenceEditor()
            else
                context.Session.OpenCurveEditor(context.Property)
            end
        end
    )
end

local ROW_EDITORS = {
    Sequence = CreateSequenceEditor,
    boolean = CreateBooleanEditor,
    Vector3 = CreateVector3Editor,
    NumberRange = CreateNumberRangeEditor,
    EnumItem = CreateEnumEditor,
    Default = CreateTextEditor,
}

local function CreateInspectorPropertyRow(scope, session, instance, property : string, layoutOrder : number, displayName : string?, cframeKind : string?)
    local Row = UiKit.CreateRow(scope, layoutOrder)
    local IconClusterWidth = UiKit.GetPropertyIconClusterWidth()
    local ValueSize = UDim2.new(0.72, -IconClusterWidth - 4, 1, 0)

    scope:New(Jian.Text, {
        Parent = Row,
        Text = displayName or property,
        Size = UDim2.new(0.28, -4, 1, 0),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClipsDescendants = true,
    })

    local Success, CurrentValue = pcall(function()
        return instance[property]
    end)
    local ValueType = if Success then typeof(CurrentValue) else nil
    local IsColorSequence = PropertyMaps.IsColorSequenceProperty(instance, property) or ValueType == "ColorSequence"
    local IsCurve = (not IsColorSequence) and (PropertyMaps.IsCurveProperty(instance, property) or ValueType == "NumberSequence")

    local Context = {
        Scope = scope,
        Session = session,
        Row = Row,
        Instance = instance,
        Property = property,
        ValueSize = ValueSize,
        Success = Success,
        CurrentValue = CurrentValue,
        CFrameKind = cframeKind,
        IsColorSequence = IsColorSequence,
    }

    local EditorKey = if IsCurve or IsColorSequence then "Sequence" elseif cframeKind then "Vector3" else ValueType
    local Editor = ROW_EDITORS[EditorKey] or ROW_EDITORS.Default
    Editor(Context)

    UiKit.CreatePropertyIconButton(scope, Row, UiKit.COPY_BUTTON_IMAGE_ID, -IconClusterWidth, function()
        local CopySuccess, Value = pcall(function()
            if cframeKind then
                return PropertyValues.GetCFrameComponentVector(instance, property, cframeKind)
            end

            return instance[property]
        end)
        if CopySuccess then
            session.CopiedValue.Value = Value
        end
    end)

    UiKit.CreatePropertyIconButton(scope, Row, UiKit.PASTE_BUTTON_IMAGE_ID, -UiKit.PROPERTY_ICON_BUTTON_SIZE, function()
        local Value = session.CopiedValue.Value
        if Value == nil then
            return
        end

        if cframeKind then
            if typeof(Value) == "CFrame" then
                Value = if cframeKind == "Orientation" then PropertyValues.GetCFrameOrientationDegrees(Value) else Value.Position
            end

            if typeof(Value) == "Vector3" then
                ApplyCFrameComponentVector(property, cframeKind, Value)
            end

            return
        end

        AssignProperty(property, Value)
    end)

    return Row
end

function PropertyInspector.Mount(scope, parent, session)
    local Host = scope:New("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 3,

        [Seam.Children] = {
            scope:New("UIListLayout", {
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        },
    })

    local InspectorScope = nil

    local function RefreshPropertyInspector()
        if InspectorScope then
            if scope.Trove then
                scope.Trove:Pop(InspectorScope)
            end
            InspectorScope:Destroy()
        end

        InspectorScope = scope:InnerScope()

        local Inspected = SelectionQueries.GetInspectedInstance()
        if not Inspected then
            return
        end

        local LayoutOrder = 0
        for _, property in PropertyMaps.GetInspectorProperties(Inspected) do
            local ReadSuccess, Value = pcall(function()
                return Inspected[property]
            end)

            if ReadSuccess and typeof(Value) == "CFrame" then
                LayoutOrder += 1
                CreateInspectorPropertyRow(
                    InspectorScope,
                    session,
                    Inspected,
                    property,
                    LayoutOrder,
                    PropertyValues.GetCFrameComponentLabel(property, "Position"),
                    "Position"
                ).Parent = Host
                LayoutOrder += 1
                CreateInspectorPropertyRow(
                    InspectorScope,
                    session,
                    Inspected,
                    property,
                    LayoutOrder,
                    PropertyValues.GetCFrameComponentLabel(property, "Orientation"),
                    "Orientation"
                ).Parent = Host
            else
                LayoutOrder += 1
                CreateInspectorPropertyRow(InspectorScope, session, Inspected, property, LayoutOrder).Parent = Host
            end
        end
    end

    scope:OnChanged(States.RawSelection, RefreshPropertyInspector)
    RefreshPropertyInspector()

    return Host
end

return PropertyInspector

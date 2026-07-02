local SliderInput = {}

local UserInputService = game:GetService("UserInputService")

local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))

local function Clamp01(Value)
    return math.clamp(Value, 0, 1)
end

local function ToNumber(Value)
    local Number = tonumber(Value)
    if Number == nil then
        return nil
    end

    return Number
end

local function ResolveInputObject(FirstArg, SecondArg)
    if typeof(FirstArg) == "InputObject" then
        return FirstArg
    end

    if typeof(SecondArg) == "InputObject" then
        return SecondArg
    end

    return nil
end

function SliderInput:Init(Scope, Properties)
    self.Dragging = Scope:Value(false)

    if Properties.Value and typeof(Properties.Value.Value) ~= "number" then
        Properties.Value.Value = ToNumber(Properties.Value.Value) or (Properties.Min or 0)
    end
end

function SliderInput:Construct(Scope, Properties)
    local Min = Properties.Min or 0
    local Max = Properties.Max or 1
    local AllowOutOfRangeText = Properties.AllowOutOfRangeText == true
    local TrackRightInset = 96

    local function ReadActiveValue()
        if typeof(Properties.Active) == "boolean" then
            return Properties.Active
        end

        if typeof(Properties.Active) == "table" and Properties.Active.Value ~= nil then
            return Properties.Active.Value == true
        end

        return Properties.Active ~= false
    end

    local function FormatNumber(Value)
        local Rounded = math.floor(Value * 100 + 0.5) / 100
        if math.abs(Rounded - math.floor(Rounded)) < 0.001 then
            return tostring(math.floor(Rounded))
        end

        return string.format("%.2f", Rounded)
    end

    local Frame = Scope:New("Frame", {
        Parent = Properties.Parent,
        LayoutOrder = Properties.LayoutOrder,
        Position = Properties.Position,
        AnchorPoint = Properties.AnchorPoint,
        Size = Properties.Size or UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1,
    })

    Scope:New(Jian.Text, {
        Parent = Frame,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = Properties.Title or "",
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    local SliderTrack = Scope:New("Frame", {
        Parent = Frame,
        Position = UDim2.fromOffset(0, 20),
        Size = UDim2.new(1, -TrackRightInset, 0, 16),
        BackgroundColor3 = Color3.fromRGB(36, 36, 36),
        BorderSizePixel = 0,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            Scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
        },
    })

    Scope:New(Jian.Text, {
        Parent = Frame,
        Position = UDim2.fromOffset(0, 40),
        Size = UDim2.fromOffset(56, 14),
        Text = FormatNumber(Min),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    Scope:New(Jian.Text, {
        Parent = Frame,
        Position = UDim2.new(1, -TrackRightInset - 56, 0, 40),
        Size = UDim2.fromOffset(56, 14),
        Text = FormatNumber(Max),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        Active = false,
    })

    Scope:New("Frame", {
        Parent = SliderTrack,
        Size = Scope:Computed(function(Use)
            local Current = Properties.Value and Use(Properties.Value) or Min
            local Alpha = Clamp01((Current - Min) / (Max - Min))
            return UDim2.fromScale(Alpha, 1)
        end),
        BackgroundColor3 = Color3.fromRGB(86, 140, 255),
        BorderSizePixel = 0,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
        },
    })

    local function UpdateFromPosition(PositionX)
        if not Properties.Value then
            return
        end

        local AbsolutePosition = SliderTrack.AbsolutePosition.X
        local AbsoluteSize = SliderTrack.AbsoluteSize.X

        if AbsoluteSize <= 0 then
            return
        end

        local Alpha = Clamp01((PositionX - AbsolutePosition) / AbsoluteSize)
        local Value = Min + (Max - Min) * Alpha
        Properties.Value.Value = Value
    end

    Scope:New("TextButton", {
        Parent = SliderTrack,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Active = Properties.Active,
        [Seam.OnEvent("InputBegan")] = function(FirstArg, SecondArg)
            if not ReadActiveValue() then
                return
            end

            local Input = ResolveInputObject(FirstArg, SecondArg)
            if not Input then
                return
            end

            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end

            self.Dragging.Value = true
            UpdateFromPosition(Input.Position.X)
        end,
    })

    Scope:AddObject(UserInputService.InputChanged:Connect(function(Input)
        if not self.Dragging.Value then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        UpdateFromPosition(Input.Position.X)
    end))

    Scope:AddObject(UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.Dragging.Value = false
        end
    end))

    local InputState = Scope:Value("0")

    Scope:AddObject(Seam.OnChanged(Properties.Value, function()
        if Properties.Value then
            InputState.Value = tostring(Properties.Value.Value)
        end
    end))

    local NumberBox = Scope:New(Jian.TextBox, {
        Parent = Frame,
        Position = UDim2.new(1, -88, 0, 13),
        Size = UDim2.fromOffset(88, 30),
        Text = InputState,
        Active = Properties.Active,
        PlaceholderText = tostring(Min),
    })

    Scope:AddObject(NumberBox.FocusLost:Connect(function()
        local NumberValue = ToNumber(InputState.Value)

        if NumberValue == nil then
            InputState.Value = tostring(Properties.Value and Properties.Value.Value or Min)
            return
        end

        if not AllowOutOfRangeText then
            NumberValue = math.clamp(NumberValue, Min, Max)
        end

        if Properties.Value then
            Properties.Value.Value = NumberValue
        end

        InputState.Value = tostring(NumberValue)
    end))

    if Properties.Value then
        InputState.Value = FormatNumber(Properties.Value.Value)
    end

    return Frame
end

return Seam.Component(SliderInput)

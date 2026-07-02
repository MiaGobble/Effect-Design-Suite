local SliderInput = {}

local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))
local LocalInput = require(Interface.Modules:FindFirstChild("LocalInput"))

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
    local Step = Properties.Step
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

    local function GetStepDecimals()
        if not Step or Step <= 0 then
            return 6
        end

        local StepText = tostring(Step)
        local DecimalPart = StepText:match("%.(%d+)")
        if not DecimalPart then
            return 0
        end

        return math.min(6, #DecimalPart)
    end

    local function RoundToDecimals(Value, Decimals)
        local Multiplier = 10 ^ Decimals
        return math.floor((Value * Multiplier) + 0.5) / Multiplier
    end

    local function ApplyStep(Value)
        if not Step or Step <= 0 then
            return RoundToDecimals(Value, 6)
        end

        local Steps = math.floor((Value / Step) + 0.5)
        local Snapped = Steps * Step
        return RoundToDecimals(Snapped, GetStepDecimals())
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

    local function ProcessLocalInput(LocalPositionX)
        local AbsoluteSize = math.max(1, SliderTrack.AbsoluteSize.X)
        local Alpha = Clamp01(LocalPositionX / AbsoluteSize)
        local Value = Min + (Max - Min) * Alpha

        if Properties.Value then
            Properties.Value.Value = ApplyStep(Value)
        end
    end

    local DragSession = LocalInput.BindPrimaryDrag(Scope, SliderTrack, function(LocalMouse)
        ProcessLocalInput(LocalMouse.X)
    end, function()
        self.Dragging.Value = false
    end)

    local function StartDrag(StartLocalPosition)
        self.Dragging.Value = true
        DragSession.Start(StartLocalPosition)
    end

    local Hitbox = Scope:New("TextButton", {
        Parent = SliderTrack,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Active = Properties.Active,
    })

    Scope:AddObject(Hitbox.InputBegan:Connect(function(Input)
        if not ReadActiveValue() then
            return
        end

        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ScreenPosition = Vector2.new(Input.Position.X, Input.Position.Y)
            local LocalMouse = LocalInput.GetLocalFromScreenPosition(SliderTrack, ScreenPosition)
            ProcessLocalInput(LocalMouse.X)
            StartDrag(LocalMouse)
        end
    end))

    local InputState = Scope:Value("0")

    Scope:AddObject(Seam.OnChanged(Properties.Value, function()
        if Properties.Value then
            InputState.Value = FormatNumber(Properties.Value.Value)
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

        NumberValue = ApplyStep(NumberValue)

        if Properties.Value then
            Properties.Value.Value = NumberValue
        end

        InputState.Value = FormatNumber(NumberValue)
    end))

    if Properties.Value then
        InputState.Value = FormatNumber(Properties.Value.Value)
    end

    return Frame
end

return Seam.Component(SliderInput)

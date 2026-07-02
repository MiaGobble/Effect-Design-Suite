local SliderInput = {}

local RunService = game:GetService("RunService")
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

    local function ApplyStep(Value)
        if not Step or Step <= 0 then
            return Value
        end

        local Steps = math.floor((Value / Step) + 0.5)
        return Steps * Step
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

    local LastTrackLocalX = 0
    local DragConnection = nil

    Scope:AddObject(SliderTrack.MouseMoved:Connect(function(X)
        LastTrackLocalX = X
    end))

    local function IsMouse1Down()
        for _, InputType in UserInputService:GetMouseButtonsPressed() do
            if InputType == Enum.UserInputType.MouseButton1 then
                return true
            end
        end

        return false
    end

    local function GetCurrentMousePosition()
        local Widget = SliderTrack:FindFirstAncestorWhichIsA("DockWidgetPluginGui")

        if Widget then
            return Widget:GetRelativeMousePosition().X
        end

        return UserInputService:GetMouseLocation().X
    end

    local function ProcessInput(PositionX)
        local AbsolutePosition = SliderTrack.AbsolutePosition.X
        local AbsoluteSize = math.max(1, SliderTrack.AbsoluteSize.X)
        local Alpha = Clamp01((PositionX - AbsolutePosition) / AbsoluteSize)
        local Value = Min + (Max - Min) * Alpha

        if Properties.Value then
            Properties.Value.Value = ApplyStep(Value)
        end
    end

    local function StopDrag()
        self.Dragging.Value = false

        if DragConnection then
            DragConnection:Disconnect()
            DragConnection = nil
        end
    end

    local function StartDrag()
        self.Dragging.Value = true

        if DragConnection then
            DragConnection:Disconnect()
            DragConnection = nil
        end

        DragConnection = RunService.Heartbeat:Connect(function()
            if not IsMouse1Down() then
                StopDrag()
                return
            end

            ProcessInput(GetCurrentMousePosition())
        end)
    end

    Scope:New("TextButton", {
        Parent = SliderTrack,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Active = Properties.Active,
        [Seam.OnEvent("MouseButton1Down")] = function()
            if not ReadActiveValue() then
                return
            end

            if Properties.Value then
                local Width = math.max(1, SliderTrack.AbsoluteSize.X)
                local Alpha = Clamp01(LastTrackLocalX / Width)
                Properties.Value.Value = ApplyStep(Min + (Max - Min) * Alpha)
            end

            StartDrag()
        end,
    })

    Scope:AddObject(UserInputService.InputChanged:Connect(function(Input)
        if not self.Dragging.Value then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        ProcessInput(Input.Position.X)
    end))

    Scope:AddObject(UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            StopDrag()
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

        NumberValue = ApplyStep(NumberValue)

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

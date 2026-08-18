local SliderInput = {}

-- Constants
local TRACK_RIGHT_INSET = 96
local TRACK_HEIGHT = 16
local TEXT_BOX_OFFSET = 56

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))
local LocalInput = require(Interface.Modules:FindFirstChild("LocalInput"))

local function Clamp01(value)
    return math.clamp(value, 0, 1)
end

local function ToNumber(value)
    local Number = tonumber(value)
    if Number == nil then
        return nil
    end

    return Number
end

function SliderInput:Init(scope, properties)
    self.Dragging = scope:Value(false)

    if properties.Value and typeof(properties.Value.Value) ~= "number" then
        properties.Value.Value = ToNumber(properties.Value.Value) or (properties.Min or 0)
    end
end

function SliderInput:Construct(scope, properties)
    local Min = properties.Min or 0
    local Max = properties.Max or 1
    local AllowOutOfRangeText = properties.AllowOutOfRangeText == true
    local Step = properties.Step

    local function ReadActiveValue()
        if typeof(properties.Active) == "boolean" then
            return properties.Active
        end

        if typeof(properties.Active) == "table" and properties.Active.Value ~= nil then
            return properties.Active.Value == true
        end

        return properties.Active ~= false
    end

    local function FormatNumber(value)
        local Rounded = math.floor(value * 100 + 0.5) / 100
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

    local function RoundToDecimals(value, decimals)
        local Multiplier = 10 ^ decimals
        return math.floor((value * Multiplier) + 0.5) / Multiplier
    end

    local function ApplyStep(value)
        if not Step or Step <= 0 then
            return RoundToDecimals(value, 6)
        end

        local Steps = math.floor((value / Step) + 0.5)
        local Snapped = Steps * Step
        return RoundToDecimals(Snapped, GetStepDecimals())
    end

    local Frame = scope:New("Frame", {
        Parent = properties.Parent,
        LayoutOrder = properties.LayoutOrder,
        Position = properties.Position,
        AnchorPoint = properties.AnchorPoint,
        Size = properties.Size or UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1,
    })

    scope:New(Jian.Text, {
        Parent = Frame,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = properties.Title or "",
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    local SliderTrack = scope:New("Frame", {
        Parent = Frame,
        Position = UDim2.fromOffset(0, 20),
        Size = UDim2.new(1, -TRACK_RIGHT_INSET, 0, TRACK_HEIGHT),
        BackgroundColor3 = Color3.fromRGB(36, 36, 36),
        BorderSizePixel = 0,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
        },
    })

    scope:New(Jian.Text, {
        Parent = Frame,
        Position = UDim2.fromOffset(0, 40),
        Size = UDim2.fromOffset(56, 14),
        Text = FormatNumber(Min),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    scope:New(Jian.Text, {
        Parent = Frame,
        Position = UDim2.new(1, -TRACK_RIGHT_INSET - TEXT_BOX_OFFSET, 0, 40),
        Size = UDim2.fromOffset(56, 14),
        Text = FormatNumber(Max),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        Active = false,
    })

    scope:New("Frame", {
        Parent = SliderTrack,
        Size = scope:Computed(function(use)
            local Current = properties.Value and use(properties.Value) or Min
            local Alpha = Clamp01((Current - Min) / (Max - Min))
            return UDim2.fromScale(Alpha, 1)
        end),
        BackgroundColor3 = Color3.fromRGB(86, 140, 255),
        BorderSizePixel = 0,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
        },
    })

    local function ProcessLocalInput(localPositionX)
        local AbsoluteSize = math.max(1, SliderTrack.AbsoluteSize.X)
        local Alpha = Clamp01(localPositionX / AbsoluteSize)
        local Value = Min + (Max - Min) * Alpha

        if properties.Value then
            properties.Value.Value = ApplyStep(Value)
        end
    end

    local DragSession = LocalInput.BindPrimaryDrag(scope, SliderTrack, function(localMouse)
        ProcessLocalInput(localMouse.X)
    end, function()
        self.Dragging.Value = false
    end)

    local function StartDrag(startLocalPosition, input)
        self.Dragging.Value = true
        DragSession.Start(startLocalPosition, input)
    end

    scope:New("TextButton", {
        Parent = SliderTrack,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Active = properties.Active,
        [Seam.OnEvent("InputBegan")] = function(input)
            if not ReadActiveValue() then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local ScreenPosition = Vector2.new(input.Position.X, input.Position.Y)
                local LocalMouse = LocalInput.GetLocalFromScreenPosition(SliderTrack, ScreenPosition)
                ProcessLocalInput(LocalMouse.X)
                StartDrag(LocalMouse, input)
            end
        end,
    })

    local InputState = scope:Value("0")

    scope:OnChanged(properties.Value, function()
        if properties.Value then
            InputState.Value = FormatNumber(properties.Value.Value)
        end
    end)

    local NumberBox = scope:New(Jian.TextBox, {
        Parent = Frame,
        Position = UDim2.new(1, -88, 0, 13),
        Size = UDim2.fromOffset(88, 30),
        Text = InputState,
        Active = properties.Active,
        PlaceholderText = tostring(Min),
    })

    local InnerNumberBox = if NumberBox:IsA("TextBox") then NumberBox else NumberBox:FindFirstChildWhichIsA("TextBox", true)
    if InnerNumberBox then
        Seam.New(InnerNumberBox, {
            [Seam.OnEvent("FocusLost")] = function()
                local NumberValue = ToNumber(InputState.Value)

                if NumberValue == nil then
                    InputState.Value = tostring(properties.Value and properties.Value.Value or Min)
                    return
                end

                if not AllowOutOfRangeText then
                    NumberValue = math.clamp(NumberValue, Min, Max)
                end

                NumberValue = ApplyStep(NumberValue)

                if properties.Value then
                    properties.Value.Value = NumberValue
                end

                InputState.Value = FormatNumber(NumberValue)
            end,
        })
    end

    if properties.Value then
        InputState.Value = FormatNumber(properties.Value.Value)
    end

    return Frame
end

return Seam.Component(SliderInput)

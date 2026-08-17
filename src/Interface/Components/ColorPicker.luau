local ColorPicker = {}

-- Constants
local PICKER_SIZE = 170
local VALUE_SLIDER_WIDTH = 18
local PICKER_GAP = 8
local VALUE_SLIDER_OFFSET = 6

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local LocalInput = require(Interface.Modules:FindFirstChild("LocalInput"))

local function Clamp01(value)
    return math.clamp(value, 0, 1)
end

local function ReadActiveValue(activeProperty)
    if typeof(activeProperty) == "boolean" then
        return activeProperty
    end

    if typeof(activeProperty) == "table" and activeProperty.Value ~= nil then
        return activeProperty.Value == true
    end

    return activeProperty ~= false
end

function ColorPicker:Init(scope, properties)
    self.H = scope:Value(0)
    self.S = scope:Value(0)
    self.V = scope:Value(1)
    self.IsDraggingPicker = scope:Value(false)
    self.IsDraggingValue = scope:Value(false)

    local Initial = properties.Value and properties.Value.Value or Color3.new(1, 1, 1)
    self.H.Value, self.S.Value, self.V.Value = Initial:ToHSV()
end

function ColorPicker:Construct(scope, properties)
    local Frame = scope:New("Frame", {
        Parent = properties.Parent,
        LayoutOrder = properties.LayoutOrder,
        Position = properties.Position,
        AnchorPoint = properties.AnchorPoint,
        Size = properties.Size or UDim2.new(1, 0, 0, 198),
        BackgroundTransparency = 1,
    })

    local PickerFrame = scope:New("Frame", {
        Parent = Frame,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -VALUE_SLIDER_WIDTH - PICKER_GAP, 0, PICKER_SIZE),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ClipsDescendants = true,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
            scope:New("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
                }),
                Rotation = 0,
            }),
            scope:New("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,

                [Seam.Children] = {
                    scope:New("UIGradient", {
                        Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0),
                            NumberSequenceKeypoint.new(1, 1),
                        }),
                        Rotation = 90,
                    }),
                },
            }),
        },
    })

    local PickerHitbox = scope:New("TextButton", {
        Parent = PickerFrame,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Active = true,
        ZIndex = 5,
    })

    scope:New("Frame", {
        Parent = PickerFrame,
        Size = UDim2.fromOffset(10, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = scope:Computed(function(use)
            return UDim2.fromScale(use(self.H), use(self.S))
        end),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 6,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(1, 0),
            }),
            scope:New("UIStroke", {
                Color = Color3.fromRGB(0, 0, 0),
                Thickness = 1,
            }),
        },
    })

    local ValueSlider = scope:New("Frame", {
        Parent = Frame,
        Position = UDim2.new(1, -VALUE_SLIDER_WIDTH, 0, 0),
        Size = UDim2.fromOffset(VALUE_SLIDER_WIDTH, PICKER_SIZE),
        BorderSizePixel = 0,
        ClipsDescendants = true,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
            scope:New("UIGradient", {
                Color = scope:Computed(function(use)
                    local Hue = use(self.H)
                    local Saturation = use(self.S)
                    local Bright = Color3.fromHSV(Hue, Saturation, 1)
                    return ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Bright),
                        ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
                    })
                end),
                Rotation = 90,
            }),
        },
    })

    local ValueHitbox = scope:New("TextButton", {
        Parent = ValueSlider,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Active = true,
        ZIndex = 5,
    })

    scope:New("Frame", {
        Parent = ValueSlider,
        Size = UDim2.new(1, 0, 0, 2),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = scope:Computed(function(use)
            return UDim2.fromScale(0, 1 - use(self.V))
        end),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 6,
    })

    scope:New("TextLabel", {
        Parent = Frame,
        Position = UDim2.fromOffset(0, PICKER_SIZE + VALUE_SLIDER_OFFSET),
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        FontFace = Font.fromName("SourceSans"),
        TextSize = 12,
        TextColor3 = Color3.fromRGB(230, 230, 230),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = scope:Computed(function(use)
            local H = math.floor(use(self.H) * 360 + 0.5)
            local S = math.floor(use(self.S) * 100 + 0.5)
            local V = math.floor(use(self.V) * 100 + 0.5)
            return string.format("HSV(%d, %d%%, %d%%)", H, S, V)
        end),
    })

    local function UpdateFromPickerMouse(localMouse)
        local Width = math.max(1, PickerFrame.AbsoluteSize.X)
        local Height = math.max(1, PickerFrame.AbsoluteSize.Y)

        self.H.Value = Clamp01(localMouse.X / Width)
        self.S.Value = Clamp01(localMouse.Y / Height)
    end

    local function UpdateFromValueMouse(localMouse)
        local Height = math.max(1, ValueSlider.AbsoluteSize.Y)
        self.V.Value = Clamp01(1 - (localMouse.Y / Height))
    end

    local function StopDragging()
        self.IsDraggingPicker.Value = false
        self.IsDraggingValue.Value = false
    end

    local PickerDrag = LocalInput.BindPrimaryDrag(scope, PickerHitbox, function(localMouse)
        UpdateFromPickerMouse(localMouse)
    end, StopDragging)

    local ValueDrag = LocalInput.BindPrimaryDrag(scope, ValueHitbox, function(localMouse)
        UpdateFromValueMouse(localMouse)
    end, StopDragging)

    scope:AddObject(PickerHitbox.InputBegan:Connect(function(input)
        if not ReadActiveValue(properties.Active) then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        ValueDrag.Stop()
        self.IsDraggingPicker.Value = true
        self.IsDraggingValue.Value = false

        local ScreenPosition = Vector2.new(input.Position.X, input.Position.Y)
        local LocalMouse = LocalInput.GetLocalFromScreenPosition(PickerHitbox, ScreenPosition)
        PickerDrag.Start(LocalMouse, input)
    end))

    scope:AddObject(ValueHitbox.InputBegan:Connect(function(input)
        if not ReadActiveValue(properties.Active) then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        PickerDrag.Stop()
        self.IsDraggingPicker.Value = false
        self.IsDraggingValue.Value = true

        local ScreenPosition = Vector2.new(input.Position.X, input.Position.Y)
        local LocalMouse = LocalInput.GetLocalFromScreenPosition(ValueHitbox, ScreenPosition)
        ValueDrag.Start(LocalMouse, input)
    end))

    local function UpdateExternal()
        if not properties.Value then
            return
        end

        properties.Value.Value = Color3.fromHSV(self.H.Value, self.S.Value, self.V.Value)
    end

    scope:AddObject(Seam.OnChanged(self.H, UpdateExternal))
    scope:AddObject(Seam.OnChanged(self.S, UpdateExternal))
    scope:AddObject(Seam.OnChanged(self.V, UpdateExternal))

    if properties.Value then
        scope:AddObject(Seam.OnChanged(properties.Value, function()
            local H, S, V = properties.Value.Value:ToHSV()
            self.H.Value = H
            self.S.Value = S
            self.V.Value = V
        end))
    end

    return Frame
end

return Seam.Component(ColorPicker)

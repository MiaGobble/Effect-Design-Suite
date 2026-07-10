local ColorPicker = {}

local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local LocalInput = require(Interface.Modules:FindFirstChild("LocalInput"))

local function Clamp01(Value)
    return math.clamp(Value, 0, 1)
end

local function ReadActiveValue(ActiveProperty)
    if typeof(ActiveProperty) == "boolean" then
        return ActiveProperty
    end

    if typeof(ActiveProperty) == "table" and ActiveProperty.Value ~= nil then
        return ActiveProperty.Value == true
    end

    return ActiveProperty ~= false
end

function ColorPicker:Init(Scope, Properties)
    self.H = Scope:Value(0)
    self.S = Scope:Value(0)
    self.V = Scope:Value(1)
    self.IsDraggingPicker = Scope:Value(false)
    self.IsDraggingValue = Scope:Value(false)

    local Initial = Properties.Value and Properties.Value.Value or Color3.new(1, 1, 1)
    self.H.Value, self.S.Value, self.V.Value = Initial:ToHSV()
end

function ColorPicker:Construct(Scope, Properties)
    local PickerSize = 170
    local ValueSliderWidth = 18

    local Frame = Scope:New("Frame", {
        Parent = Properties.Parent,
        LayoutOrder = Properties.LayoutOrder,
        Position = Properties.Position,
        AnchorPoint = Properties.AnchorPoint,
        Size = Properties.Size or UDim2.new(1, 0, 0, 198),
        BackgroundTransparency = 1,
    })

    local PickerFrame = Scope:New("Frame", {
        Parent = Frame,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -ValueSliderWidth - 8, 0, PickerSize),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ClipsDescendants = true,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            Scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
            Scope:New("UIGradient", {
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
            Scope:New("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,

                [Seam.Children] = {
                    Scope:New("UIGradient", {
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

    local PickerHitbox = Scope:New("TextButton", {
        Parent = PickerFrame,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Active = true,
        ZIndex = 5,
    })

    Scope:New("Frame", {
        Parent = PickerFrame,
        Size = UDim2.fromOffset(10, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = Scope:Computed(function(Use)
            return UDim2.fromScale(Use(self.H), Use(self.S))
        end),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 6,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(1, 0),
            }),
            Scope:New("UIStroke", {
                Color = Color3.fromRGB(0, 0, 0),
                Thickness = 1,
            }),
        },
    })

    local ValueSlider = Scope:New("Frame", {
        Parent = Frame,
        Position = UDim2.new(1, -ValueSliderWidth, 0, 0),
        Size = UDim2.fromOffset(ValueSliderWidth, PickerSize),
        BorderSizePixel = 0,
        ClipsDescendants = true,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            Scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
            Scope:New("UIGradient", {
                Color = Scope:Computed(function(Use)
                    local Hue = Use(self.H)
                    local Saturation = Use(self.S)
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

    local ValueHitbox = Scope:New("TextButton", {
        Parent = ValueSlider,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Active = true,
        ZIndex = 5,
    })

    Scope:New("Frame", {
        Parent = ValueSlider,
        Size = UDim2.new(1, 0, 0, 2),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = Scope:Computed(function(Use)
            return UDim2.fromScale(0, 1 - Use(self.V))
        end),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 6,
    })

    Scope:New("TextLabel", {
        Parent = Frame,
        Position = UDim2.fromOffset(0, PickerSize + 6),
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        FontFace = Font.fromName("SourceSans"),
        TextSize = 12,
        TextColor3 = Color3.fromRGB(230, 230, 230),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = Scope:Computed(function(Use)
            local H = math.floor(Use(self.H) * 360 + 0.5)
            local S = math.floor(Use(self.S) * 100 + 0.5)
            local V = math.floor(Use(self.V) * 100 + 0.5)
            return string.format("HSV(%d, %d%%, %d%%)", H, S, V)
        end),
    })

    local function UpdateFromPickerMouse(LocalMouse)
        local Width = math.max(1, PickerFrame.AbsoluteSize.X)
        local Height = math.max(1, PickerFrame.AbsoluteSize.Y)

        self.H.Value = Clamp01(LocalMouse.X / Width)
        self.S.Value = Clamp01(LocalMouse.Y / Height)
    end

    local function UpdateFromValueMouse(LocalMouse)
        local Height = math.max(1, ValueSlider.AbsoluteSize.Y)
        self.V.Value = Clamp01(1 - (LocalMouse.Y / Height))
    end

    local function StopDragging()
        self.IsDraggingPicker.Value = false
        self.IsDraggingValue.Value = false
    end

    local PickerDrag = LocalInput.BindPrimaryDrag(Scope, PickerHitbox, function(LocalMouse)
        UpdateFromPickerMouse(LocalMouse)
    end, StopDragging)

    local ValueDrag = LocalInput.BindPrimaryDrag(Scope, ValueHitbox, function(LocalMouse)
        UpdateFromValueMouse(LocalMouse)
    end, StopDragging)

    Scope:AddObject(PickerHitbox.InputBegan:Connect(function(Input)
        if not ReadActiveValue(Properties.Active) then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        ValueDrag.Stop()
        self.IsDraggingPicker.Value = true
        self.IsDraggingValue.Value = false

        local ScreenPosition = Vector2.new(Input.Position.X, Input.Position.Y)
        local LocalMouse = LocalInput.GetLocalFromScreenPosition(PickerHitbox, ScreenPosition)
        PickerDrag.Start(LocalMouse, Input)
    end))

    Scope:AddObject(ValueHitbox.InputBegan:Connect(function(Input)
        if not ReadActiveValue(Properties.Active) then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        PickerDrag.Stop()
        self.IsDraggingPicker.Value = false
        self.IsDraggingValue.Value = true

        local ScreenPosition = Vector2.new(Input.Position.X, Input.Position.Y)
        local LocalMouse = LocalInput.GetLocalFromScreenPosition(ValueHitbox, ScreenPosition)
        ValueDrag.Start(LocalMouse, Input)
    end))

    local function UpdateExternal()
        if not Properties.Value then
            return
        end

        Properties.Value.Value = Color3.fromHSV(self.H.Value, self.S.Value, self.V.Value)
    end

    Scope:AddObject(Seam.OnChanged(self.H, UpdateExternal))
    Scope:AddObject(Seam.OnChanged(self.S, UpdateExternal))
    Scope:AddObject(Seam.OnChanged(self.V, UpdateExternal))

    if Properties.Value then
        Scope:AddObject(Seam.OnChanged(Properties.Value, function()
            local H, S, V = Properties.Value.Value:ToHSV()
            self.H.Value = H
            self.S.Value = S
            self.V.Value = V
        end))
    end

    return Frame
end

return Seam.Component(ColorPicker)

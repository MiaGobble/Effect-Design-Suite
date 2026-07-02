local ColorPicker = {}

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))

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
    local DragConnection = nil

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
                            NumberSequenceKeypoint.new(0, 1),
                            NumberSequenceKeypoint.new(1, 0),
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
            return UDim2.fromScale(1 - Use(self.H), 1 - Use(self.S))
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

    local function UpdateFromPickerMouse(MouseLocation)
        local Relative = MouseLocation - PickerFrame.AbsolutePosition
        local Width = math.max(1, PickerFrame.AbsoluteSize.X)
        local Height = math.max(1, PickerFrame.AbsoluteSize.Y)

        self.H.Value = Clamp01(1 - (Relative.X / Width))
        self.S.Value = Clamp01(1 - (Relative.Y / Height))
    end

    local function UpdateFromValueMouse(MouseLocation)
        local RelativeY = MouseLocation.Y - ValueSlider.AbsolutePosition.Y
        local Height = math.max(1, ValueSlider.AbsoluteSize.Y)
        self.V.Value = Clamp01(1 - (RelativeY / Height))
    end

    local function IsMouse1Down()
        for _, InputType in UserInputService:GetMouseButtonsPressed() do
            if InputType == Enum.UserInputType.MouseButton1 then
                return true
            end
        end

        return false
    end

    local function StopDragging()
        self.IsDraggingPicker.Value = false
        self.IsDraggingValue.Value = false

        if DragConnection then
            DragConnection:Disconnect()
            DragConnection = nil
        end
    end

    local function BeginDrag(Mode)
        if DragConnection then
            DragConnection:Disconnect()
            DragConnection = nil
        end

        self.IsDraggingPicker.Value = Mode == "Picker"
        self.IsDraggingValue.Value = Mode == "Value"

        DragConnection = RunService.Heartbeat:Connect(function()
            if not IsMouse1Down() then
                StopDragging()
                return
            end

            local MouseLocation = UserInputService:GetMouseLocation()
            if self.IsDraggingPicker.Value then
                UpdateFromPickerMouse(MouseLocation)
            elseif self.IsDraggingValue.Value then
                UpdateFromValueMouse(MouseLocation)
            end
        end)
    end

    Scope:AddObject(PickerHitbox.MouseButton1Down:Connect(function()
        if not ReadActiveValue(Properties.Active) then
            return
        end

        UpdateFromPickerMouse(UserInputService:GetMouseLocation())
        BeginDrag("Picker")
    end))

    Scope:AddObject(ValueHitbox.MouseButton1Down:Connect(function()
        if not ReadActiveValue(Properties.Active) then
            return
        end

        UpdateFromValueMouse(UserInputService:GetMouseLocation())
        BeginDrag("Value")
    end))

    Scope:AddObject(UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            StopDragging()
        end
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

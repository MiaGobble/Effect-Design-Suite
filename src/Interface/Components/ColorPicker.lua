local ColorPicker = {}

local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local SliderInput = require(script.Parent.SliderInput)

function ColorPicker:Init(Scope, Properties)
    self.R = Scope:Value(255)
    self.G = Scope:Value(255)
    self.B = Scope:Value(255)

    local Initial = Properties.Value and Properties.Value.Value or Color3.new(1, 1, 1)
    self.R.Value = math.floor(Initial.R * 255 + 0.5)
    self.G.Value = math.floor(Initial.G * 255 + 0.5)
    self.B.Value = math.floor(Initial.B * 255 + 0.5)
end

function ColorPicker:Construct(Scope, Properties)
    local Frame = Scope:New("Frame", {
        Parent = Properties.Parent,
        LayoutOrder = Properties.LayoutOrder,
        Position = Properties.Position,
        AnchorPoint = Properties.AnchorPoint,
        Size = Properties.Size or UDim2.new(1, 0, 0, 198),
        BackgroundTransparency = 1,

        [Seam.Children] = {
            Scope:New("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
            }),
            Scope:New(SliderInput, {
                LayoutOrder = 1,
                Size = UDim2.new(1, 0, 0, 58),
                Title = "R",
                Min = 0,
                Max = 255,
                Value = self.R,
                Active = Properties.Active,
            }),
            Scope:New(SliderInput, {
                LayoutOrder = 2,
                Size = UDim2.new(1, 0, 0, 58),
                Title = "G",
                Min = 0,
                Max = 255,
                Value = self.G,
                Active = Properties.Active,
            }),
            Scope:New(SliderInput, {
                LayoutOrder = 3,
                Size = UDim2.new(1, 0, 0, 58),
                Title = "B",
                Min = 0,
                Max = 255,
                Value = self.B,
                Active = Properties.Active,
            }),
            Scope:New("Frame", {
                LayoutOrder = 4,
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,

                [Seam.Children] = {
                    Scope:New("Frame", {
                        Position = UDim2.fromOffset(0, 0),
                        Size = UDim2.fromOffset(24, 24),
                        BackgroundColor3 = Scope:Computed(function(Use)
                            return Color3.fromRGB(Use(self.R), Use(self.G), Use(self.B))
                        end),
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
                    }),
                    Scope:New("TextLabel", {
                        Position = UDim2.fromOffset(32, 0),
                        Size = UDim2.new(1, -32, 1, 0),
                        BackgroundTransparency = 1,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        FontFace = Font.fromName("SourceSans"),
                        TextSize = 12,
                        TextColor3 = Color3.fromRGB(235, 235, 235),
                        Text = Scope:Computed(function(Use)
                            local R = math.clamp(Use(self.R), 0, 255)
                            local G = math.clamp(Use(self.G), 0, 255)
                            local B = math.clamp(Use(self.B), 0, 255)
                            return string.format("RGB(%d, %d, %d)", R, G, B)
                        end),
                    }),
                },
            }),
            Scope:New("Frame", {
                LayoutOrder = 5,
                Size = UDim2.new(1, 0, 0, 2),
                BackgroundColor3 = Scope:Computed(function(Use)
                    return Color3.fromRGB(Use(self.R), Use(self.G), Use(self.B))
                end),
                BorderSizePixel = 0,
            }),
        },
    })

    local function UpdateExternal()
        if not Properties.Value then
            return
        end

        Properties.Value.Value = Color3.fromRGB(self.R.Value, self.G.Value, self.B.Value)
    end

    Scope:AddObject(Seam.OnChanged(self.R, UpdateExternal))
    Scope:AddObject(Seam.OnChanged(self.G, UpdateExternal))
    Scope:AddObject(Seam.OnChanged(self.B, UpdateExternal))

    return Frame
end

return Seam.Component(ColorPicker)

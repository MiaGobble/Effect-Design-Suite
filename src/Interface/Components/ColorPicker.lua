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
        Size = Properties.Size or UDim2.new(1, 0, 0, 198),
        BackgroundTransparency = 1,

        [Seam.Children] = {
            Scope:New(SliderInput, {
                LayoutOrder = 1,
                Position = UDim2.fromOffset(0, 0),
                Size = UDim2.new(1, 0, 0, 58),
                Title = "R",
                Min = 0,
                Max = 255,
                Value = self.R,
                Active = Properties.Active,
            }),
            Scope:New(SliderInput, {
                LayoutOrder = 2,
                Position = UDim2.fromOffset(0, 62),
                Size = UDim2.new(1, 0, 0, 58),
                Title = "G",
                Min = 0,
                Max = 255,
                Value = self.G,
                Active = Properties.Active,
            }),
            Scope:New(SliderInput, {
                LayoutOrder = 3,
                Position = UDim2.fromOffset(0, 124),
                Size = UDim2.new(1, 0, 0, 58),
                Title = "B",
                Min = 0,
                Max = 255,
                Value = self.B,
                Active = Properties.Active,
            }),
            Scope:New("Frame", {
                Position = UDim2.new(1, -42, 0, 0),
                Size = UDim2.fromOffset(42, 42),
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

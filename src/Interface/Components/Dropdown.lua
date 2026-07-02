local Dropdown = {}

local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))

function Dropdown:Init(Scope, Properties)
    self.IsOpen = Scope:Value(false)

    local Default = Properties.Default or ""
    local Value = Properties.Value

    if Value and Value.Value == nil then
        Value.Value = Default
    end
end

function Dropdown:Construct(Scope, Properties)
    local OptionsSource = Properties.Options or {}

    local OptionsFrame

    local function ClearOptionButtons()
        if not OptionsFrame then
            return
        end

        for _, Child in OptionsFrame:GetChildren() do
            if Child:IsA("GuiObject") and Child.Name == "DropdownOption" then
                Child:Destroy()
            end
        end
    end

    local function ReadOptions()
        if typeof(OptionsSource) == "table" and OptionsSource.Value ~= nil and typeof(OptionsSource.Value) == "table" then
            return OptionsSource.Value
        end

        if typeof(OptionsSource) == "table" then
            return OptionsSource
        end

        return {}
    end

    local function RenderOptions()
        if not OptionsFrame then
            return
        end

        ClearOptionButtons()

        local CurrentOptions = ReadOptions()

        for Index, Option in ipairs(CurrentOptions) do
            local OptionText = tostring(Option)

            Scope:New(Jian.TextButton, {
                Parent = OptionsFrame,
                Name = "DropdownOption",
                LayoutOrder = Index,
                Size = UDim2.new(1, 0, 0, 26),
                Text = OptionText,
                Active = Properties.Active,
                [Seam.OnEvent("Activated")] = function()
                    if Properties.Value then
                        Properties.Value.Value = OptionText
                    end

                    self.IsOpen.Value = false
                end,
            })
        end
    end

    local Frame = Scope:New("Frame", {
        Parent = Properties.Parent,
        LayoutOrder = Properties.LayoutOrder,
        Position = Properties.Position,
        AnchorPoint = Properties.AnchorPoint,
        Size = Properties.Size or UDim2.new(1, 0, 0, 70),
        BackgroundTransparency = 1,

        [Seam.Children] = {
            Scope:New(Jian.TextButton, {
                Size = UDim2.new(1, 0, 0, 32),
                Text = Scope:Computed(function(Use)
                    local Current = Properties.Value and Use(Properties.Value) or ""
                    if Current == nil or Current == "" then
                        return Properties.PlaceholderText or "Select"
                    end

                    return tostring(Current)
                end),
                Active = Properties.Active,
                [Seam.OnEvent("Activated")] = function()
                    self.IsOpen.Value = not self.IsOpen.Value
                end,
            }),
        },
    })

    OptionsFrame = Scope:New("Frame", {
        Parent = Frame,
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.None,
        BackgroundColor3 = Color3.fromRGB(27, 27, 27),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = self.IsOpen,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            Scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
            Scope:New("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        },
    })

    if typeof(OptionsSource) == "table" and OptionsSource.Value ~= nil then
        Scope:AddObject(Seam.OnChanged(OptionsSource, function()
            local CurrentOptions = ReadOptions()
            OptionsFrame.Size = if self.IsOpen.Value then UDim2.new(1, 0, 0, math.max(1, #CurrentOptions) * 26) else UDim2.fromScale(1, 0)
            RenderOptions()
        end))
    end

    Scope:AddObject(Seam.OnChanged(self.IsOpen, function()
        local CurrentOptions = ReadOptions()
        OptionsFrame.Size = if self.IsOpen.Value then UDim2.new(1, 0, 0, math.max(1, #CurrentOptions) * 26) else UDim2.fromScale(1, 0)
    end))

    RenderOptions()

    return Frame
end

return Seam.Component(Dropdown)

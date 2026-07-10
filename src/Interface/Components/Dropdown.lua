local Dropdown = {}

local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))

local CLOSED_HEIGHT = 36
local ROW_HEIGHT = 30
local MAX_LIST_HEIGHT = 220
local BASE_Z = 120

local COLOR_BUTTON = Color3.fromRGB(60, 60, 60)
local COLOR_BUTTON_HOVER = Color3.fromRGB(70, 70, 70)
local COLOR_BUTTON_DISABLED = Color3.fromRGB(40, 40, 40)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_TEXT_DISABLED = Color3.fromRGB(163, 163, 163)
local COLOR_STROKE = Color3.fromRGB(40, 40, 40)
local COLOR_STROKE_HOVER = Color3.fromRGB(60, 60, 60)

local function ReadOptions(Source, Use)
    if Use and typeof(Source) == "table" and Source.Value ~= nil then
        local Value = Use(Source)
        if typeof(Value) == "table" then
            return Value
        end
    end

    if typeof(Source) == "table" and Source.Value ~= nil and typeof(Source.Value) == "table" then
        return Source.Value
    end

    if typeof(Source) == "table" then
        return Source
    end

    return {}
end

local function ReadActiveValue(ActiveProperty, Use)
    if Use and typeof(ActiveProperty) == "table" and ActiveProperty.Value ~= nil then
        return Use(ActiveProperty) == true
    end

    if typeof(ActiveProperty) == "boolean" then
        return ActiveProperty
    end

    if typeof(ActiveProperty) == "table" and ActiveProperty.Value ~= nil then
        return ActiveProperty.Value == true
    end

    return ActiveProperty ~= false
end

function Dropdown:Init(Scope, Properties)
    self.IsOpen = Scope:Value(false)
    self.IsHovering = Scope:Value(false)

    local Default = Properties.Default or ""
    if Properties.Value and Properties.Value.Value == nil then
        Properties.Value.Value = Default
    end
end

function Dropdown:Construct(Scope, Properties)
    local OptionsSource = Properties.Options or {}

        local function IsEnabled(Use)
        return ReadActiveValue(Properties.Active, Use) and #ReadOptions(OptionsSource, Use) > 0
    end

    local Root = Scope:New("Frame", {
        Parent = Properties.Parent,
        LayoutOrder = Properties.LayoutOrder,
        Position = Properties.Position,
        AnchorPoint = Properties.AnchorPoint,
        Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = BASE_Z,
    })

    local OverlayRoot = Scope:New("Frame", {
        Parent = Root,
        Name = "DropdownOverlay",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromScale(1, 1),
        ClipsDescendants = false,
        ZIndex = BASE_Z + 8,
        Visible = self.IsOpen,
    })

    local Container = Scope:New("Frame", {
        Parent = Root,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT),
                BackgroundColor3 = Scope:Computed(function(Use)
            if not IsEnabled(Use) then
                return COLOR_BUTTON_DISABLED
            end

            if Use(self.IsHovering) or Use(self.IsOpen) then
                return COLOR_BUTTON_HOVER
            end

            return COLOR_BUTTON
        end),
        BorderSizePixel = 0,
        ZIndex = BASE_Z + 1,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            Scope:New("UIStroke", {
                Color = Scope:Computed(function(Use)
                    if Use(self.IsHovering) or Use(self.IsOpen) then
                        return COLOR_STROKE_HOVER
                    end

                    return COLOR_STROKE
                end),
                Thickness = 1,
            }),
        },
    })

    Scope:New("TextLabel", {
        Parent = Container,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        FontFace = Font.fromEnum(Enum.Font.BuilderSans),
        TextSize = 14,
                TextColor3 = Scope:Computed(function(Use)
            if IsEnabled(Use) then
                return COLOR_TEXT
            end

            return COLOR_TEXT_DISABLED
        end),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = Scope:Computed(function(Use)
            local Current = Properties.Value and Use(Properties.Value) or ""
            if Current == nil or Current == "" then
                return Properties.PlaceholderText or "Select"
            end

            return tostring(Current)
        end),
        ZIndex = BASE_Z + 2,
    })

    Scope:New("TextLabel", {
        Parent = Container,
        Position = UDim2.new(1, -26, 0, 0),
        Size = UDim2.fromOffset(20, CLOSED_HEIGHT),
        BackgroundTransparency = 1,
        FontFace = Font.fromEnum(Enum.Font.BuilderSans),
        TextSize = 15,
                TextColor3 = Scope:Computed(function(Use)
            if IsEnabled(Use) then
                return COLOR_TEXT
            end

            return COLOR_TEXT_DISABLED
        end),
        TextXAlignment = Enum.TextXAlignment.Center,
        Text = Scope:Computed(function(Use)
            return Use(self.IsOpen) and "▴" or "▾"
        end),
        ZIndex = BASE_Z + 2,
    })

    Scope:New("TextButton", {
        Parent = Container,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Active = true,
        ZIndex = BASE_Z + 3,
        [Seam.OnEvent("MouseEnter")] = function()
            self.IsHovering.Value = true
        end,
        [Seam.OnEvent("MouseLeave")] = function()
            self.IsHovering.Value = false
        end,
        [Seam.OnEvent("Activated")] = function()
            if not IsEnabled() then
                return
            end

            self.IsOpen.Value = not self.IsOpen.Value
        end,
    })

    local ListFrame = Scope:New("ScrollingFrame", {
        Parent = OverlayRoot,
        Position = UDim2.fromOffset(0, CLOSED_HEIGHT + 5),
        Size = UDim2.fromScale(1, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        CanvasSize = UDim2.fromScale(0, 0),
        ScrollBarThickness = 8,
        ScrollBarImageColor3 = Color3.fromRGB(140, 140, 150),
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        BackgroundColor3 = Color3.fromRGB(50, 50, 50),
        BorderSizePixel = 0,
        Visible = self.IsOpen,
        ClipsDescendants = true,
        ZIndex = BASE_Z + 10,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            Scope:New("UIStroke", {
                Color = COLOR_STROKE_HOVER,
                Thickness = 1,
            }),
            Scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 4),
                PaddingBottom = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
            }),
            Scope:New("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
            }),
        },
    })

    local function ClearRows()
        for _, Child in ListFrame:GetChildren() do
            if Child:IsA("GuiButton") and Child.Name == "OptionRow" then
                Child:Destroy()
            end
        end
    end

    local function RefreshLayout()
        local Options = ReadOptions(OptionsSource)
        local FullHeight = math.max(1, #Options) * (ROW_HEIGHT + 4) + 8
        local VisibleHeight = math.min(MAX_LIST_HEIGHT, FullHeight)

        local Widget = Root:FindFirstAncestorWhichIsA("DockWidgetPluginGui")
        local RootPosition = Vector2.new(0, 0)

        if Widget then
            if OverlayRoot.Parent ~= Widget then
                OverlayRoot.Parent = Widget
            end

            RootPosition = Root.AbsolutePosition - Widget.AbsolutePosition
        else
            if OverlayRoot.Parent ~= Root then
                OverlayRoot.Parent = Root
            end

            RootPosition = Vector2.new(0, 0)
        end

        local RootWidth = Root.AbsoluteSize.X
        ListFrame.Position = UDim2.fromOffset(RootPosition.X, RootPosition.Y + CLOSED_HEIGHT + 5)

        ListFrame.CanvasSize = UDim2.fromOffset(0, FullHeight)
        ListFrame.Size = if self.IsOpen.Value then UDim2.fromOffset(RootWidth, VisibleHeight) else UDim2.fromOffset(RootWidth, 0)
        Root.Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT)
    end

    local function RenderRows()
        ClearRows()

        local Options = ReadOptions(OptionsSource)
        for Index, Option in ipairs(Options) do
            local OptionText = tostring(Option)
            local IsHover = Scope:Value(false)

            Scope:New("TextButton", {
                Parent = ListFrame,
                Name = "OptionRow",
                LayoutOrder = Index,
                Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
                BorderSizePixel = 0,
                BackgroundColor3 = Scope:Computed(function(Use)
                    if Use(IsHover) then
                        return COLOR_BUTTON_HOVER
                    end

                    return COLOR_BUTTON
                end),
                FontFace = Font.fromEnum(Enum.Font.BuilderSans),
                TextSize = 13,
                TextColor3 = COLOR_TEXT,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "  " .. OptionText,
                Active = true,
                AutoButtonColor = false,
                ZIndex = BASE_Z + 11,

                [Seam.Children] = {
                    Scope:New("UICorner", {
                        CornerRadius = UDim.new(0, 4),
                    }),
                    Scope:New("UIStroke", {
                        Color = COLOR_STROKE,
                        Thickness = 1,
                    }),
                },

                [Seam.OnEvent("MouseEnter")] = function()
                    IsHover.Value = true
                end,
                [Seam.OnEvent("MouseLeave")] = function()
                    IsHover.Value = false
                end,
                [Seam.OnEvent("Activated")] = function()
                    if not IsEnabled() then
                        return
                    end

                    if Properties.Value then
                        Properties.Value.Value = OptionText
                    end

                    self.IsOpen.Value = false
                end,
            })
        end

        RefreshLayout()
    end

    Scope:AddObject(Seam.OnChanged(self.IsOpen, function()
        OverlayRoot.Visible = self.IsOpen.Value
        ListFrame.Visible = self.IsOpen.Value
        RefreshLayout()
    end))

    Scope:AddObject(Root:GetPropertyChangedSignal("AbsolutePosition"):Connect(RefreshLayout))
    Scope:AddObject(Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(RefreshLayout))

    if typeof(OptionsSource) == "table" and OptionsSource.Value ~= nil then
        Scope:AddObject(Seam.OnChanged(OptionsSource, function()
            RenderRows()
        end))
    end

    RenderRows()

    return Root
end

return Seam.Component(Dropdown)

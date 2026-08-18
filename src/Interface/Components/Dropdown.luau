local Dropdown = {}

-- Constants
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

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))

local function ReadOptions(source, use)
    if use and typeof(source) == "table" and source.Value ~= nil then
        local Value = use(source)
        if typeof(Value) == "table" then
            return Value
        end
    end

    if typeof(source) == "table" and source.Value ~= nil and typeof(source.Value) == "table" then
        return source.Value
    end

    if typeof(source) == "table" then
        return source
    end

    return {}
end

local function ReadActiveValue(activeProperty, use)
    if use and typeof(activeProperty) == "table" and activeProperty.Value ~= nil then
        return use(activeProperty) == true
    end

    if typeof(activeProperty) == "boolean" then
        return activeProperty
    end

    if typeof(activeProperty) == "table" and activeProperty.Value ~= nil then
        return activeProperty.Value == true
    end

    return activeProperty ~= false
end

function Dropdown:Init(scope, properties)
    self.IsOpen = scope:Value(false)
    self.IsHovering = scope:Value(false)

    local Default = properties.Default or ""
    if properties.Value and properties.Value.Value == nil then
        properties.Value.Value = Default
    end
end

function Dropdown:Construct(scope, properties)
    local OptionsSource = properties.Options or {}

        local function IsEnabled(use)
        return ReadActiveValue(properties.Active, use) and #ReadOptions(OptionsSource, use) > 0
    end

    local Root = scope:New("Frame", {
        Parent = properties.Parent,
        LayoutOrder = properties.LayoutOrder,
        Position = properties.Position,
        AnchorPoint = properties.AnchorPoint,
        Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = BASE_Z,
    })

    local OverlayRoot = scope:New("Frame", {
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

    local Container = scope:New("Frame", {
        Parent = Root,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT),
                BackgroundColor3 = scope:Computed(function(use)
            if not IsEnabled(use) then
                return COLOR_BUTTON_DISABLED
            end

            if use(self.IsHovering) or use(self.IsOpen) then
                return COLOR_BUTTON_HOVER
            end

            return COLOR_BUTTON
        end),
        BorderSizePixel = 0,
        ZIndex = BASE_Z + 1,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            scope:New("UIStroke", {
                Color = scope:Computed(function(use)
                    if use(self.IsHovering) or use(self.IsOpen) then
                        return COLOR_STROKE_HOVER
                    end

                    return COLOR_STROKE
                end),
                Thickness = 1,
            }),
        },
    })

    scope:New("TextLabel", {
        Parent = Container,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        FontFace = Font.fromEnum(Enum.Font.BuilderSans),
        TextSize = 14,
                TextColor3 = scope:Computed(function(use)
            if IsEnabled(use) then
                return COLOR_TEXT
            end

            return COLOR_TEXT_DISABLED
        end),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = scope:Computed(function(use)
            local Current = properties.Value and use(properties.Value) or ""
            if Current == nil or Current == "" then
                return properties.PlaceholderText or "Select"
            end

            return tostring(Current)
        end),
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextWrapped = false,
        ZIndex = BASE_Z + 2,
    })

    scope:New("TextLabel", {
        Parent = Container,
        Position = UDim2.new(1, -26, 0, 0),
        Size = UDim2.fromOffset(20, CLOSED_HEIGHT),
        BackgroundTransparency = 1,
        FontFace = Font.fromEnum(Enum.Font.BuilderSans),
        TextSize = 15,
                TextColor3 = scope:Computed(function(use)
            if IsEnabled(use) then
                return COLOR_TEXT
            end

            return COLOR_TEXT_DISABLED
        end),
        TextXAlignment = Enum.TextXAlignment.Center,
        Text = scope:Computed(function(use)
            return use(self.IsOpen) and "▴" or "▾"
        end),
        ZIndex = BASE_Z + 2,
    })

    scope:New("TextButton", {
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

    local ListFrame = scope:New("ScrollingFrame", {
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
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            scope:New("UIStroke", {
                Color = COLOR_STROKE_HOVER,
                Thickness = 1,
            }),
            scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 4),
                PaddingBottom = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
            }),
            scope:New("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
            }),
        },
    })

    local function ClearRows()
        for _, child in ListFrame:GetChildren() do
            if child:IsA("GuiButton") and child.Name == "OptionRow" then
                child:Destroy()
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
        for index, option in ipairs(Options) do
            local OptionText = tostring(option)
            local IsHover = scope:Value(false)

            scope:New("TextButton", {
                Parent = ListFrame,
                Name = "OptionRow",
                LayoutOrder = index,
                Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
                BorderSizePixel = 0,
                BackgroundColor3 = scope:Computed(function(use)
                    if use(IsHover) then
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
                    scope:New("UICorner", {
                        CornerRadius = UDim.new(0, 4),
                    }),
                    scope:New("UIStroke", {
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

                    if properties.Value then
                        properties.Value.Value = OptionText
                    end

                    self.IsOpen.Value = false
                end,
            })
        end

        RefreshLayout()
    end

    scope:OnChanged(self.IsOpen, function()
        OverlayRoot.Visible = self.IsOpen.Value
        ListFrame.Visible = self.IsOpen.Value
        RefreshLayout()
    end)

    local LAYOUT_PROPERTIES = {
        AbsolutePosition = true,
        AbsoluteSize = true,
    }
    scope:OnChanged(Root, function(property)
        if LAYOUT_PROPERTIES[property] then
            RefreshLayout()
        end
    end)

    if typeof(OptionsSource) == "table" and OptionsSource.Value ~= nil then
        scope:OnChanged(OptionsSource, function()
            RenderRows()
        end)
    end

    RenderRows()

    return Root
end

return Seam.Component(Dropdown)

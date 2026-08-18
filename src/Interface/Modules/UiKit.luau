local UiKit = {}

-- Constants
local TEXTURE_ID_PREFIX = "rbxassetid://"
local PROPERTY_ICON_BUTTON_SIZE = 24
local PROPERTY_ICON_BUTTON_GAP = 4
local ICON_ANIMATION_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ICON_HOVER_SCALE = 1.12
local ICON_PRESS_SCALE = 0.88
local ICON_DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local ICON_HOVER_COLOR = Color3.fromRGB(220, 230, 255)
local ICON_PRESS_COLOR = Color3.fromRGB(170, 190, 230)
local MAIN_WIDGET_MIN_SIZE = 320

UiKit.MAIN_WIDGET_MIN_SIZE = MAIN_WIDGET_MIN_SIZE
UiKit.PROPERTY_ICON_BUTTON_SIZE = PROPERTY_ICON_BUTTON_SIZE
UiKit.COPY_BUTTON_IMAGE_ID = "103287906385313"
UiKit.PASTE_BUTTON_IMAGE_ID = "89773130507890"

-- Services
local TweenService = game:GetService("TweenService")

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))

function UiKit.FormatTextureId(textureId : number | string)
    return TEXTURE_ID_PREFIX .. tostring(textureId)
end

function UiKit.GetPropertyIconClusterWidth()
    return PROPERTY_ICON_BUTTON_SIZE * 2 + PROPERTY_ICON_BUTTON_GAP
end

function UiKit.CreateRow(scope, layoutOrder : number, children : {any}?)
    return scope:New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        LayoutOrder = layoutOrder,

        [Seam.Children] = children,
    })
end

function UiKit.CreateLabel(scope, parent : Instance, text : any)
    return scope:New(Jian.Text, {
        Parent = parent,
        Text = text,
        Size = UDim2.new(0.33, -8, 1, 0),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

function UiKit.CreateBoundTextBox(scope, parent : Instance, state, active, placeholderText : string, position : UDim2, size : UDim2, extraEvents)
    local Properties = {
        Parent = parent,
        Text = state,
        Active = active,
        PlaceholderText = placeholderText,
        Position = position,
        Size = size,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClipsDescendants = true,
    }

    local TextBox = scope:New(Jian.TextBox, Properties)
    local InnerTextBox = if TextBox:IsA("TextBox") then TextBox else TextBox:FindFirstChildWhichIsA("TextBox", true)
    if not InnerTextBox then
        return TextBox
    end

    local HydrateProperties = {
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClipsDescendants = true,
        [Seam.OnChanged] = function(property, newValue)
            if property == "Text" then
                state.Value = newValue
            end
        end,
    }

    if extraEvents then
        for eventName, callback in extraEvents do
            HydrateProperties[Seam.OnEvent(eventName)] = callback
        end
    end

    Seam.New(InnerTextBox, HydrateProperties)

    return TextBox
end

function UiKit.CreateActionButton(scope, layoutOrder : number, text : string, active, callback)
    return scope:New(Jian.TextButton, {
        LayoutOrder = layoutOrder,
        Text = text,
        Active = active,
        Size = UDim2.new(1, 0, 0, 35),
        [Seam.OnEvent("Activated")] = callback,
    })
end

function UiKit.CreatePropertyIconButton(scope, parent, imageId : string, xOffset : number, callback)
    local IsHovering = false
    local IsPressed = false
    local Scale
    local Button

    local function PlayIconState()
        local TargetScale = 1
        local TargetColor = ICON_DEFAULT_COLOR

        if IsPressed then
            TargetScale = ICON_PRESS_SCALE
            TargetColor = ICON_PRESS_COLOR
        elseif IsHovering then
            TargetScale = ICON_HOVER_SCALE
            TargetColor = ICON_HOVER_COLOR
        end

        TweenService:Create(Scale, ICON_ANIMATION_INFO, { Scale = TargetScale }):Play()
        TweenService:Create(Button, ICON_ANIMATION_INFO, { ImageColor3 = TargetColor }):Play()
    end

    Button = scope:New("ImageButton", {
        Parent = parent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Image = UiKit.FormatTextureId(imageId),
        ImageColor3 = ICON_DEFAULT_COLOR,
        ScaleType = Enum.ScaleType.Fit,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, xOffset + PROPERTY_ICON_BUTTON_SIZE / 2, 0.5, 0),
        Size = UDim2.fromOffset(PROPERTY_ICON_BUTTON_SIZE, PROPERTY_ICON_BUTTON_SIZE),
        [Seam.OnEvent("Activated")] = callback,
        [Seam.OnEvent("MouseEnter")] = function()
            IsHovering = true
            PlayIconState()
        end,
        [Seam.OnEvent("MouseLeave")] = function()
            IsHovering = false
            IsPressed = false
            PlayIconState()
        end,
        [Seam.OnEvent("MouseButton1Down")] = function()
            IsPressed = true
            PlayIconState()
        end,
        [Seam.OnEvent("MouseButton1Up")] = function()
            IsPressed = false
            PlayIconState()
        end,
    })

    Scale = scope:New("UIScale", {
        Parent = Button,
        Scale = 1,
    })

    return Button
end

function UiKit.CreateListWidget(scope, widgetId : string, title : string, initialEnabled : boolean, width : number, height : number, dockState)
    local Widget = scope:New(Jian.Widget, {
        WidgetId = widgetId,
        Title = title,
        InitialDockState = dockState or Enum.InitialDockState.Float,
        InitialEnabled = initialEnabled,
        OverridePreviousState = false,
        DefaultWidth = width,
        DefaultHeight = height,
        MinimumWidth = MAIN_WIDGET_MIN_SIZE,
        MinimumHeight = MAIN_WIDGET_MIN_SIZE,
    }) :: DockWidgetPluginGui

    Widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    scope:New(Jian.Background, {
        Parent = Widget,
    })

    local Container = scope:New(Jian.ScrollingList, {
        Parent = Widget,
        Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 8,

        [Seam.Children] = {
            scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 16),
                PaddingBottom = UDim.new(0, 16),
                PaddingLeft = UDim.new(0, 16),
                PaddingRight = UDim.new(0, 16),
            }),
        },
    })

    return Widget, Container
end

return UiKit

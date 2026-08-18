local Interface = {}

-- Constants
local VERSION_FILE_NAME = "VERSION.txt"
local VERSION_OBJECT_NAME = "VERSION"
local GITHUB_VERSION_URLS = {
    "https://raw.githubusercontent.com/MiaGobble/Effect-Design-Suite/main/src/VERSION.txt",
    "https://raw.githubusercontent.com/MiaGobble/Effect-Design-Suite/refs/heads/main/src/VERSION.txt",
    "https://raw.githubusercontent.com/MiaGobble/Effect-Design-Suite/main/VERSION.txt",
}
local HTTP_PERMISSION_NEEDLES = {
    "http requests are not enabled",
    "permission",
    "not allowed",
    "trust check",
    "aborted",
}
local HTTP_PERMISSION_WARNING = "This plugin does not have HTTP permissions and cannot check for updates."
local COLOR_SEQUENCE_ATTRIBUTE = "EffectDesignerOklabColorSequence"
local CURVE_ATTRIBUTE_PREFIX = "EffectDesignerCurve_"
local TEXTURE_ID_PREFIX = "rbxassetid://"
local MAIN_WIDGET_ID = "EffectDesignerSuite"
local MAIN_WIDGET_TITLE = "Effect Designer Suite — Core"
local EDITING_WIDGET_ID = "EffectDesignerSuiteEditing"
local EDITING_WIDGET_TITLE = "Effect Designer Suite — Editing"
local ADVANCED_WIDGET_ID = "EffectDesignerSuiteAdvanced"
local ADVANCED_WIDGET_TITLE = "Effect Designer Suite — Advanced"
local COLOR_PICKER_WIDGET_ID = "EffectDesignerSuiteColorPicker"
local ASSETS_WIDGET_ID = "EffectDesignerSuiteAssets"
local ASSETS_WIDGET_TITLE = "Effect Designer Suite — Presets"
local CURVE_EDITOR_WIDGET_ID = "EffectDesignerSuiteCurveEditor"
local CURVE_EDITOR_WIDGET_TITLE = "Effect Designer Suite — Curve Editor"
local COLOR_SEQUENCE_WIDGET_ID = "EffectDesignerSuiteColorSequence"
local COLOR_SEQUENCE_WIDGET_TITLE = "Effect Designer Suite — Color Sequence"
local MAIN_WIDGET_WIDTH = 320
local MAIN_WIDGET_HEIGHT = 480
local MAIN_WIDGET_MIN_SIZE = 320
local EDITOR_WIDGET_WIDTH = 360
local EDITOR_WIDGET_HEIGHT = 420
local NOT_CONFIGURABLE_TEXT = "this instance is not configurable with Effect Designer Suite"
local OTHER_TOOLS_HINT = "Looking for other tools? They're now separate widgets!"
local COPY_BUTTON_IMAGE_ID = "103287906385313"
local PASTE_BUTTON_IMAGE_ID = "89773130507890"
local PROPERTY_ICON_BUTTON_SIZE = 24
local PROPERTY_ICON_BUTTON_GAP = 4
local ICON_ANIMATION_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ICON_HOVER_SCALE = 1.12
local ICON_PRESS_SCALE = 0.88
local ICON_DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local ICON_HOVER_COLOR = Color3.fromRGB(220, 230, 255)
local ICON_PRESS_COLOR = Color3.fromRGB(170, 190, 230)
local EMIT_FIELD_LABEL_HEIGHT = 16
local EMIT_FIELD_BOX_HEIGHT = 36
local EMIT_ATTRIBUTE_ROW_HEIGHT = 54
local CURVE_PREVIEW_LINE_SAMPLES = 48
local CURVE_PREVIEW_GRADIENT_SAMPLES = 19

-- Services
local SelectionService = game:GetService("Selection")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

-- Imports
local Bin = script.Parent
local Objects = Bin:FindFirstChild("Objects")
local Packages = Bin:FindFirstChild("Packages")
local EmitUtils = require(script.EmitUtils)
local AssetUtils = require(script.AssetUtils)
local States = require(Objects:FindFirstChild("States"))
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))
local Components = script:FindFirstChild("Components")
local Modules = script:FindFirstChild("Modules")
local PropertyMaps = require(Modules:FindFirstChild("PropertyMaps"))
local EffectOps = require(Modules:FindFirstChild("EffectOps"))
local VfxApiInjection = require(Modules:FindFirstChild("VfxApiInjection"))
local WorldSpaceAcceleration = require(Modules:FindFirstChild("WorldSpaceAcceleration"))
local PartAnimation = require(Modules:FindFirstChild("PartAnimation"))
local Dropdown = require(Components:FindFirstChild("Dropdown"))
local SliderInput = require(Components:FindFirstChild("SliderInput"))
local CurveEditor = require(Components:FindFirstChild("CurveEditor"))
local ColorPicker = require(Components:FindFirstChild("ColorPicker"))
local ColorSequenceEditor = require(Components:FindFirstChild("ColorSequenceEditor"))

-- Variables
local InterfaceScope = nil
local PendingPreviewLoads = {}

local function TrimVersionText(text : string) : string
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function ParseVersionParts(text : string) : {number}?
    local Clean = string.match(text, "^v?(%d+[%.%d]*)$")
    if not Clean then
        return nil
    end

    local Parts = {}
    for number in string.gmatch(Clean, "%d+") do
        table.insert(Parts, tonumber(number) or 0)
    end

    if #Parts == 0 then
        return nil
    end

    return Parts
end

local function IsRemoteVersionNewer(remoteText : string, localText : string) : boolean
    local RemoteParts = ParseVersionParts(remoteText)
    local LocalParts = ParseVersionParts(localText)
    if not RemoteParts or not LocalParts then
        return false
    end

    local Count = math.max(#RemoteParts, #LocalParts)
    for index = 1, Count do
        local RemotePart = RemoteParts[index] or 0
        local LocalPart = LocalParts[index] or 0
        if RemotePart > LocalPart then
            return true
        elseif RemotePart < LocalPart then
            return false
        end
    end

    return false
end

local function ReadLocalVersion() : string?
    local VersionObject = Bin:FindFirstChild(VERSION_FILE_NAME) or Bin:FindFirstChild(VERSION_OBJECT_NAME)
    if not VersionObject then
        return nil
    end

    local Text = nil
    if VersionObject:IsA("StringValue") then
        Text = VersionObject.Value
    elseif VersionObject:IsA("LuaSourceContainer") then
        Text = VersionObject.Source
    end

    if typeof(Text) ~= "string" then
        return nil
    end

    Text = TrimVersionText(Text)
    if Text == "" then
        return nil
    end

    return Text
end

local function IsHttpPermissionError(thisError) : boolean
    local Text = string.lower(tostring(thisError))
    for _, needle in HTTP_PERMISSION_NEEDLES do
        if string.find(Text, needle, 1, true) ~= nil then
            return true
        end
    end

    return false
end

local function FetchGitHubVersion() : (string?, boolean)
    for _, url in GITHUB_VERSION_URLS do
        local Success, Result = pcall(function()
            return HttpService:GetAsync(url)
        end)

        if Success and typeof(Result) == "string" then
            local Text = TrimVersionText(Result)
            if Text ~= "" and ParseVersionParts(Text) then
                return Text, false
            end
        elseif not Success and IsHttpPermissionError(Result) then
            return nil, true
        end
    end

    return nil, false
end

local function FormatTextureId(textureId : number | string)
    return TEXTURE_ID_PREFIX .. tostring(textureId)
end

local function GetFlipbookGridSize(flipbookType : number?)
    if flipbookType == 8 then
        return 8
    elseif flipbookType == 4 then
        return 4
    elseif flipbookType == 2 then
        return 2
    end

    return 1
end

local function GetParticleFlipbookLayout(flipbookType : number?)
    if flipbookType == 8 then
        return Enum.ParticleFlipbookLayout.Grid8x8
    elseif flipbookType == 4 then
        return Enum.ParticleFlipbookLayout.Grid4x4
    elseif flipbookType == 2 then
        return Enum.ParticleFlipbookLayout.Grid2x2
    end

    return Enum.ParticleFlipbookLayout.None
end

local function GetFlipbookTypeLabel(flipbookType : number?)
    local GridSize = GetFlipbookGridSize(flipbookType)

    if GridSize <= 1 then
        return "Static"
    end

    return string.format("%dx%d flipbook", GridSize, GridSize)
end

local function ApplyAssetToTextureObject(asset, object : Instance)
    local Texture = FormatTextureId(asset.TextureId)

    if object:IsA("ParticleEmitter") then
        object.Texture = Texture
        object.FlipbookLayout = GetParticleFlipbookLayout(asset.FlipbookType)
        object.FlipbookMode = Enum.ParticleFlipbookMode.Loop

        if GetFlipbookGridSize(asset.FlipbookType) > 1 then
            object.FlipbookFramerate = NumberRange.new(24)
        else
            object.FlipbookFramerate = NumberRange.new(1)
        end
    elseif object:IsA("Beam") or object:IsA("Trail") then
        object.Texture = Texture
    end
end

local function ResolveParticleInsertParent(selectionTarget : Instance?)
    if not selectionTarget then
        return nil
    end

    if selectionTarget:IsA("ParticleEmitter") or selectionTarget:IsA("Trail") or selectionTarget:IsA("Beam") then
        return selectionTarget.Parent
    end

    return selectionTarget
end

local function CreatePreviewFrame(scope, previewEntries, asset, layoutOrder : number, animate : boolean?, size : UDim2?)
    local PreviewWindow = scope:New("Frame", {
        LayoutOrder = layoutOrder,
        Size = size or UDim2.fromOffset(88, 88),
        BackgroundColor3 = Color3.fromRGB(28, 28, 28),
        BorderSizePixel = 0,
        ClipsDescendants = true,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            scope:New("UIStroke", {
                Color = Color3.fromRGB(52, 52, 52),
                Thickness = 1,
            }),
        },
    })

    local GridSize = GetFlipbookGridSize(asset.FlipbookType)
    local ImageParent = PreviewWindow

    if GridSize > 1 then
        ImageParent = scope:New("Frame", {
            Parent = PreviewWindow,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ClipsDescendants = true,

            [Seam.Children] = {
                scope:New("UIAspectRatioConstraint", {
                    AspectRatio = 1,
                    AspectType = Enum.AspectType.FitWithinMaxSize,
                }),
            },
        })
    end

    local ImageScaleType = Enum.ScaleType.Fit

    if GridSize > 1 then
        ImageScaleType = Enum.ScaleType.Stretch
    end

    local ContentId = FormatTextureId(asset.TextureId)
    local PreviewImage = scope:New("ImageLabel", {
        Parent = ImageParent,
        BackgroundTransparency = 1,
        Image = ContentId,
        ImageTransparency = 1,
        ScaleType = ImageScaleType,
        Size = UDim2.fromScale(GridSize, GridSize),
    })

    local LoadingIndicator = scope:New("TextLabel", {
        Parent = PreviewWindow,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Text = "Loading",
        TextColor3 = Color3.fromRGB(168, 168, 168),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 3,
    })

    local PreviewEntry = nil

    if animate == true and GridSize > 1 then
        PreviewEntry = {
            Image = PreviewImage,
            GridSize = GridSize,
            TotalFrames = GridSize * GridSize,
            StartedAt = os.clock(),
            FramesPerSecond = GridSize == 8 and 20 or 12,
        }
        table.insert(previewEntries, PreviewEntry)
    end

    table.insert(PendingPreviewLoads, {
        Image = PreviewImage,
        Indicator = LoadingIndicator,
        PreviewEntry = PreviewEntry,
        ContentId = ContentId,
        Preloaded = false,
    })

    local PendingEntry = PendingPreviewLoads[#PendingPreviewLoads]

    task.defer(function()
        pcall(function()
            ContentProvider:PreloadAsync({PendingEntry.ContentId})
        end)
        PendingEntry.Preloaded = true
    end)

    return PreviewWindow
end

local function CreateAssetCard(scope, previewEntries, asset, layoutOrder : number, isSelected, selectCallback)
    local Card = scope:New("Frame", {
        LayoutOrder = layoutOrder,
        Size = UDim2.fromOffset(188, 76),
        BackgroundColor3 = scope:Computed(function(use)
            if use(isSelected) then
                return Color3.fromRGB(53, 53, 53)
            end

            return Color3.fromRGB(40, 40, 40)
        end),
        BorderSizePixel = 0,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 8),
            }),
            scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
            scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 8),
                PaddingBottom = UDim.new(0, 8),
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8),
            }),
        },
    })

    CreatePreviewFrame(scope, previewEntries, asset, 1, false, UDim2.fromOffset(56, 56)).Parent = Card

    scope:New(Jian.Text, {
        Parent = Card,
        LayoutOrder = 2,
        Position = UDim2.fromOffset(68, 8),
        Size = UDim2.new(1, -76, 0, 18),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = string.format("%s %03d", asset.Type, asset.CategoryIndex),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 14,
    })

    scope:New(Jian.Text, {
        Parent = Card,
        LayoutOrder = 3,
        Position = UDim2.fromOffset(68, 30),
        Size = UDim2.new(1, -76, 0, 16),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = GetFlipbookTypeLabel(asset.FlipbookType),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 11,
        Active = false,
    })

    scope:New("TextButton", {
        Parent = Card,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        [Seam.OnEvent("Activated")] = function()
            selectCallback(asset)
        end,
    })

    return Card
end

local function CreateRow(scope, layoutOrder : number, children : {any}?)
    return scope:New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        LayoutOrder = layoutOrder,

        [Seam.Children] = children,
    })
end

local function CreateLabel(scope, parent : Instance, text : any)
    return scope:New(Jian.Text, {
        Parent = parent,
        Text = text,
        Size = UDim2.new(0.33, -8, 1, 0),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function BindTextBox(scope, textBox : TextBox, state)
    scope:AddObject(textBox:GetPropertyChangedSignal("Text"):Connect(function()
        state.Value = textBox.Text
    end))
end

local function CreateBoundTextBox(scope, parent : Instance, state, active, placeholderText : string, position : UDim2, size : UDim2)
    local TextBox = scope:New(Jian.TextBox, {
        Parent = parent,
        Text = state,
        Active = active,
        PlaceholderText = placeholderText,
        Position = position,
        Size = size,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClipsDescendants = true,
    })

    local InnerTextBox = if TextBox:IsA("TextBox") then TextBox else TextBox:FindFirstChildWhichIsA("TextBox", true)
    if InnerTextBox then
        InnerTextBox.TextWrapped = false
        InnerTextBox.TextTruncate = Enum.TextTruncate.AtEnd
        InnerTextBox.ClipsDescendants = true
    end

    BindTextBox(scope, TextBox, state)

    return TextBox
end

local function CreateActionButton(scope, layoutOrder : number, text : string, active, callback)
    return scope:New(Jian.TextButton, {
        LayoutOrder = layoutOrder,
        Text = text,
        Active = active,
        Size = UDim2.new(1, 0, 0, 35),
        [Seam.OnEvent("Activated")] = callback,
    })
end

local function GetPropertyIconClusterWidth()
    return PROPERTY_ICON_BUTTON_SIZE * 2 + PROPERTY_ICON_BUTTON_GAP
end

local function CreatePropertyIconButton(scope, parent, imageId : string, xOffset : number, callback)
    local Button = scope:New("ImageButton", {
        Parent = parent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Image = FormatTextureId(imageId),
        ImageColor3 = ICON_DEFAULT_COLOR,
        ScaleType = Enum.ScaleType.Fit,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, xOffset + PROPERTY_ICON_BUTTON_SIZE / 2, 0.5, 0),
        Size = UDim2.fromOffset(PROPERTY_ICON_BUTTON_SIZE, PROPERTY_ICON_BUTTON_SIZE),
        [Seam.OnEvent("Activated")] = callback,
    })

    local Scale = scope:New("UIScale", {
        Parent = Button,
        Scale = 1,
    })

    local IsHovering = false
    local IsPressed = false

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

    Button.MouseEnter:Connect(function()
        IsHovering = true
        PlayIconState()
    end)
    Button.MouseLeave:Connect(function()
        IsHovering = false
        IsPressed = false
        PlayIconState()
    end)
    Button.MouseButton1Down:Connect(function()
        IsPressed = true
        PlayIconState()
    end)
    Button.MouseButton1Up:Connect(function()
        IsPressed = false
        PlayIconState()
    end)

    return Button
end

local function CreateListWidget(scope, widgetId : string, title : string, initialEnabled : boolean, width : number, height : number, dockState)
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

local function SplitNumbers(text : string) : {number}
    local Numbers = {}

    for token in string.gmatch(text, "[^,;%s]+") do
        local Number = tonumber(token)
        if Number then
            table.insert(Numbers, Number)
        end
    end

    return Numbers
end

local function FormatPropertyValue(value) : string
    local ValueType = typeof(value)

    if ValueType == "number" then
        return tostring(value)
    elseif ValueType == "boolean" then
        return if value then "true" else "false"
    elseif ValueType == "string" then
        return value
    elseif ValueType == "Vector3" then
        return string.format("%s, %s, %s", tostring(value.X), tostring(value.Y), tostring(value.Z))
    elseif ValueType == "Vector2" then
        return string.format("%s, %s", tostring(value.X), tostring(value.Y))
    elseif ValueType == "NumberRange" then
        return string.format("%s, %s", tostring(value.Min), tostring(value.Max))
    elseif ValueType == "Color3" then
        return string.format("%d, %d, %d", math.round(value.R * 255), math.round(value.G * 255), math.round(value.B * 255))
    elseif ValueType == "EnumItem" then
        return value.Name
    elseif ValueType == "CFrame" then
        return table.concat({value:GetComponents()}, ", ")
    elseif ValueType == "UDim" then
        return string.format("%s, %s", tostring(value.Scale), tostring(value.Offset))
    elseif ValueType == "UDim2" then
        return string.format(
            "%s, %s, %s, %s",
            tostring(value.X.Scale),
            tostring(value.X.Offset),
            tostring(value.Y.Scale),
            tostring(value.Y.Offset)
        )
    elseif ValueType == "Rect" then
        return string.format("%s, %s, %s, %s", tostring(value.Min.X), tostring(value.Min.Y), tostring(value.Max.X), tostring(value.Max.Y))
    elseif ValueType == "BrickColor" then
        return value.Name
    elseif ValueType == "Instance" then
        return value:GetFullName()
    elseif ValueType == "NumberSequence" then
        return "NumberSequence"
    elseif ValueType == "ColorSequence" then
        return "ColorSequence"
    end

    return tostring(value)
end

local function SampleNumberSequence(sequence : NumberSequence, time : number)
    local Keys = sequence.Keypoints
    if #Keys == 0 then
        return 0
    end

    if time <= Keys[1].Time then
        return Keys[1].Value
    end

    for index = 1, #Keys - 1 do
        local Start = Keys[index]
        local Finish = Keys[index + 1]
        if time <= Finish.Time then
            local Duration = Finish.Time - Start.Time
            local Alpha = if Duration <= 0 then 0 else (time - Start.Time) / Duration
            return Start.Value + (Finish.Value - Start.Value) * Alpha
        end
    end

    return Keys[#Keys].Value
end

local function GetNumberSequenceRange(sequence : NumberSequence)
    local MinValue = math.huge
    local MaxValue = -math.huge

    for _, keypoint in sequence.Keypoints do
        MinValue = math.min(MinValue, keypoint.Value)
        MaxValue = math.max(MaxValue, keypoint.Value)
    end

    if MinValue == math.huge then
        return 0, 1
    end

    if MaxValue <= MinValue then
        MaxValue = MinValue + 1
    end

    return MinValue, MaxValue
end

local function GetCFrameOrientationDegrees(cframe : CFrame)
    local Rx, Ry, Rz = cframe:ToOrientation()
    return Vector3.new(math.deg(Rx), math.deg(Ry), math.deg(Rz))
end

local function CFrameFromPositionAndOrientation(position : Vector3, orientation : Vector3)
    return CFrame.new(position) * CFrame.fromOrientation(math.rad(orientation.X), math.rad(orientation.Y), math.rad(orientation.Z))
end

local function GetCFrameComponentLabel(property : string, kind : string)
    if property == "CFrame" then
        return kind
    end

    return property .. " " .. kind
end

local function GetEnumItemNames(enumItem)
    local Names = {}
    for _, item in enumItem.EnumType:GetEnumItems() do
        table.insert(Names, item.Name)
    end
    return Names
end

local function ParsePropertyValue(currentValue, text : string)
    local ValueType = typeof(currentValue)

    if ValueType == "number" then
        return tonumber(text)
    elseif ValueType == "boolean" then
        local Lower = string.lower(text)
        if Lower == "true" or Lower == "1" then
            return true
        elseif Lower == "false" or Lower == "0" then
            return false
        end

        return nil
    elseif ValueType == "string" then
        return text
    elseif ValueType == "Vector3" then
        local Numbers = SplitNumbers(text)
        if #Numbers >= 3 then
            return Vector3.new(Numbers[1], Numbers[2], Numbers[3])
        elseif #Numbers == 1 then
            return Vector3.new(Numbers[1], Numbers[1], Numbers[1])
        end

        return nil
    elseif ValueType == "Vector2" then
        local Numbers = SplitNumbers(text)
        if #Numbers >= 2 then
            return Vector2.new(Numbers[1], Numbers[2])
        end

        return nil
    elseif ValueType == "NumberRange" then
        local Numbers = SplitNumbers(text)
        if #Numbers >= 2 then
            return NumberRange.new(Numbers[1], Numbers[2])
        elseif #Numbers == 1 then
            return NumberRange.new(Numbers[1], Numbers[1])
        end

        return nil
    elseif ValueType == "Color3" then
        local Numbers = SplitNumbers(text)
        if #Numbers >= 3 then
            local Red, Green, Blue = Numbers[1], Numbers[2], Numbers[3]
            if Red > 1 or Green > 1 or Blue > 1 then
                return Color3.fromRGB(Red, Green, Blue)
            end

            return Color3.new(Red, Green, Blue)
        end

        return nil
    elseif ValueType == "EnumItem" then
        local Success, Item = pcall(function()
            return currentValue.EnumType[text]
        end)
        if Success then
            return Item
        end

        return nil
    elseif ValueType == "CFrame" then
        local Numbers = SplitNumbers(text)
        if #Numbers >= 12 then
            return CFrame.new(table.unpack(Numbers, 1, 12))
        elseif #Numbers >= 3 then
            return CFrame.new(Numbers[1], Numbers[2], Numbers[3])
        end

        return nil
    elseif ValueType == "UDim" then
        local Numbers = SplitNumbers(text)
        if #Numbers >= 2 then
            return UDim.new(Numbers[1], Numbers[2])
        end

        return nil
    elseif ValueType == "UDim2" then
        local Numbers = SplitNumbers(text)
        if #Numbers >= 4 then
            return UDim2.new(Numbers[1], Numbers[2], Numbers[3], Numbers[4])
        end

        return nil
    elseif ValueType == "Rect" then
        local Numbers = SplitNumbers(text)
        if #Numbers >= 4 then
            return Rect.new(Numbers[1], Numbers[2], Numbers[3], Numbers[4])
        end

        return nil
    elseif ValueType == "BrickColor" then
        local Number = tonumber(text)
        if Number then
            return BrickColor.new(Number)
        end

        local Success, Color = pcall(function()
            return BrickColor.new(text)
        end)
        if Success then
            return Color
        end

        return nil
    end

    return nil
end

local function SyncSelectionAttribute(state, attributeName : string)
    local CurrentInstance = States.PrimarySelected.Value

    if not CurrentInstance then
        state.Value = ""
        return
    end

    state.Value = tostring(CurrentInstance:GetAttribute(attributeName) or "")
end

function Interface:Init()
    if InterfaceScope then
        InterfaceScope:Destroy()
        InterfaceScope = nil
    end

    local Scope = Seam.Scope(Seam)
    InterfaceScope = Scope

    local MainWidget, Container = CreateListWidget(
        Scope,
        MAIN_WIDGET_ID,
        MAIN_WIDGET_TITLE,
        true,
        MAIN_WIDGET_WIDTH,
        MAIN_WIDGET_HEIGHT,
        Enum.InitialDockState.Left
    )
    local EditingWidget, EditingContainer = CreateListWidget(
        Scope,
        EDITING_WIDGET_ID,
        EDITING_WIDGET_TITLE,
        false,
        MAIN_WIDGET_WIDTH,
        MAIN_WIDGET_HEIGHT,
        Enum.InitialDockState.Float
    )
    local AdvancedWidget, AdvancedContainer = CreateListWidget(
        Scope,
        ADVANCED_WIDGET_ID,
        ADVANCED_WIDGET_TITLE,
        false,
        MAIN_WIDGET_WIDTH,
        MAIN_WIDGET_HEIGHT,
        Enum.InitialDockState.Float
    )
    local CurveEditorDock, CurveEditorContainer = CreateListWidget(
        Scope,
        CURVE_EDITOR_WIDGET_ID,
        CURVE_EDITOR_WIDGET_TITLE,
        false,
        EDITOR_WIDGET_WIDTH,
        EDITOR_WIDGET_HEIGHT,
        Enum.InitialDockState.Float
    )
    local ColorSequenceDock, ColorSequenceContainer = CreateListWidget(
        Scope,
        COLOR_SEQUENCE_WIDGET_ID,
        COLOR_SEQUENCE_WIDGET_TITLE,
        false,
        EDITOR_WIDGET_WIDTH,
        280,
        Enum.InitialDockState.Float
    )

    local function GetInspectedInstance()
        local RawSelection = States.RawSelection.Value
        if #RawSelection == 0 then
            return nil
        end

        local First = RawSelection[1]
        if PropertyMaps.IsConfigurableInstance(First) then
            return First
        end

        return nil
    end

    local HasEditableSelection = Scope:Computed(function(use)
        return #use(States.CurrentlySelected) > 0
    end)

    local HasConfigurableSelection = Scope:Computed(function(use)
        local RawSelection = use(States.RawSelection)
        return #RawSelection >= 1 and PropertyMaps.IsConfigurableInstance(RawSelection[1])
    end)

    local HasRawSelection = Scope:Computed(function(use)
        return #use(States.RawSelection) > 0
    end)

    local function HasColorSequence(instance)
        local Success, Value = pcall(function()
            return instance.Color
        end)
        return Success and typeof(Value) == "ColorSequence"
    end

    local function CanEditColorSequence(instance)
        return HasColorSequence(instance) or instance:IsA("BasePart")
    end

    local HasColorSequenceSelection = Scope:Computed(function(use)
        local RawSelection = use(States.RawSelection)
        return #RawSelection >= 1 and PropertyMaps.IsColorSequenceProperty(RawSelection[1], "Color")
    end)

    local HasParticleEmitterSelection = Scope:Computed(function(use)
        for _, instance in use(States.CurrentlySelected) do
            if instance:IsA("ParticleEmitter") then
                return true
            end
        end

        return false
    end)

    local HasReplaceTargets = Scope:Computed(function(use)
        local RawSelection = use(States.RawSelection)
        local CurrentSelection = use(States.CurrentlySelected)

        for _, instance in RawSelection do
            if instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
                return true
            end
        end

        for _, instance in CurrentSelection do
            if instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
                return true
            end
        end

        return false
    end)

    local SelectionSummary = Scope:Computed(function(use)
        local RawSelection = use(States.RawSelection)

        if #RawSelection == 0 or not PropertyMaps.IsConfigurableInstance(RawSelection[1]) then
            return NOT_CONFIGURABLE_TEXT
        end

        local Inspected = RawSelection[1]
        if #RawSelection == 1 then
            return string.format("%s — %s", Inspected.ClassName, Inspected.Name)
        end

        return string.format("%s — %s (+%d)", Inspected.ClassName, Inspected.Name, #RawSelection - 1)
    end)

    local EmitCountText = Scope:Value("")
    local EmitDelayText = Scope:Value("")
    local EmitDurationText = Scope:Value("")
    local RepeatEmitDelayText = Scope:Value(tostring(States.RepeatEmitDelay.Value))
    local ResizeMultiplierValue = Scope:Value(1)
    local MathPropertyText = Scope:Value("Size")
    local MathAmountValue = Scope:Value(3)
    local CurvePropertyText = Scope:Value("")
    local CurveMinRangeText = Scope:Value("0")
    local CurveMaxRangeText = Scope:Value("10")
    local CurvePoints = Scope:Value({
        {
                        Time = 0,
            Value = 0.5,
            InHandleX = 0,
            InHandleY = 0,
            OutHandleX = 0,
            OutHandleY = 0,
        },
        {
            Time = 1,
            Value = 0.5,
            InHandleX = 0,
            InHandleY = 0,
            OutHandleX = 0,
            OutHandleY = 0,
        },
    })
    local function CurveAttributeName(property)
        return CURVE_ATTRIBUTE_PREFIX .. property
    end

    local function CurveRangeAttributeName(property, suffix)
        return CurveAttributeName(property) .. "_" .. suffix
    end

    local function GetDefaultCurveRange(property : string)
        if property == "Transparency" or property == "Scale" then
            return 0, 1
        end

        return 0, 10
    end

    local function ResetCurveState()
        local MinRange, MaxRange = GetDefaultCurveRange(CurvePropertyText.Value)
        local DefaultValue = if CurvePropertyText.Value == "Scale" then 1 else 0.5
        CurvePoints.Value = {
            {
                Time = 0,
                Value = DefaultValue,
                InHandleX = 0,
                InHandleY = 0,
                OutHandleX = 0,
                OutHandleY = 0,
            },
            {
                Time = 1,
                Value = DefaultValue,
                InHandleX = 0,
                InHandleY = 0,
                OutHandleX = 0,
                OutHandleY = 0,
            },
        }
        CurveMinRangeText.Value = tostring(MinRange)
        CurveMaxRangeText.Value = tostring(MaxRange)
    end

    local function ReadCurveState()
        local Property = CurvePropertyText.Value
        local Instance = GetInspectedInstance()
        if not Property or Property == "" or not Instance then
            ResetCurveState()
            return
        end

        local Points
                local MinRange
        local MaxRange
        local EncodedPoints = Instance:GetAttribute(CurveAttributeName(Property))
        local EncodedMinRange = Instance:GetAttribute(CurveRangeAttributeName(Property, "MinRange"))
        local EncodedMaxRange = Instance:GetAttribute(CurveRangeAttributeName(Property, "MaxRange"))

        if typeof(EncodedPoints) == "string" then
            local Success, Decoded = pcall(function()
                return HttpService:JSONDecode(EncodedPoints)
            end)
            if Success and typeof(Decoded) == "table" and #Decoded >= 2 then
                Points = Decoded
                MinRange = tonumber(EncodedMinRange)
                MaxRange = tonumber(EncodedMaxRange)
            end
        end

        if not Points then
            local Success, Value = pcall(function()
                return Instance[Property]
            end)
            if Success and typeof(Value) == "NumberSequence" then
                Points, MinRange, MaxRange = EffectOps.ReadCurvePointsFromNumberSequence(Value)
            end
        end

                if Points and #Points >= 2 then
            CurvePoints.Value = Points
            CurveMinRangeText.Value = tostring(MinRange or 0)
            CurveMaxRangeText.Value = tostring(MaxRange or 1)
        else
            ResetCurveState()
        end
    end

    local function DefaultColorSequencePoints()
        return {
            EffectOps.Color3ToOklabPoint(Color3.new(1, 1, 1), 0),
            EffectOps.Color3ToOklabPoint(Color3.new(1, 1, 1), 1),
        }
    end

    local ColorSequencePoints = Scope:Value(DefaultColorSequencePoints())
    local ActiveColorPointIndex = Scope:Value(nil)
    local ColorPickerValue = Scope:Value(Color3.new(1, 1, 1))
    local IsSyncingColorPicker = false
    local ColorPickerWidget = nil

    local function ReadColorSequenceState()
        local SourceInstance = GetInspectedInstance()
        if SourceInstance and not CanEditColorSequence(SourceInstance) then
            SourceInstance = nil
        end

        ActiveColorPointIndex.Value = nil
        if ColorPickerWidget then
            ColorPickerWidget.Enabled = false
        end
        if not SourceInstance then
            ColorSequencePoints.Value = DefaultColorSequencePoints()
            return
        end

        local Points = nil
        local EncodedPoints = SourceInstance:GetAttribute(COLOR_SEQUENCE_ATTRIBUTE)
        if typeof(EncodedPoints) == "string" then
            local Success, Decoded = pcall(function()
                return HttpService:JSONDecode(EncodedPoints)
            end)

            if Success and typeof(Decoded) == "table" and #Decoded >= 2 and #Decoded <= 20 then
                local Valid = true
                for _, point in Decoded do
                    if typeof(point) ~= "table"
                        or typeof(point.Time) ~= "number"
                        or typeof(point.L) ~= "number"
                        or typeof(point.A) ~= "number"
                        or typeof(point.B) ~= "number" then
                        Valid = false
                        break
                    end
                end

                if Valid then
                    table.sort(Decoded, function(left, right)
                        return left.Time < right.Time
                    end)
                    if Decoded[1].Time == 0 and Decoded[#Decoded].Time == 1 then
                        Points = Decoded
                    end
                end
            end
        end

        if not Points then
            if HasColorSequence(SourceInstance) then
                Points = EffectOps.ReadOklabPointsFromColorSequence(SourceInstance.Color)
            elseif SourceInstance:IsA("BasePart") then
                Points = {
                    EffectOps.Color3ToOklabPoint(SourceInstance.Color, 0),
                    EffectOps.Color3ToOklabPoint(SourceInstance.Color, 1),
                }
            else
                Points = DefaultColorSequencePoints()
            end
        end

        ColorSequencePoints.Value = Points
    end

    local PreviewPathsEnabled = Scope:Value(false)
    local InjectVfxApiEnabled = Scope:Value(false)
    local WorldSpaceAccelEnabled = Scope:Value(false)
    local IsSyncingWorldSpaceAccel = false
    local CopiedValue = Scope:Value(nil)
    local SelectedAsset = Scope:Value(nil)
    local SelectedAssetCategory = Scope:Value(nil)
    local DefaultSelectedAsset = nil
    local AssetCatalog = nil

    local PreviewEntries = {}
    local IsAssetBrowserInitialized = false

    ColorPickerWidget = Scope:New(Jian.Widget, {
        WidgetId = COLOR_PICKER_WIDGET_ID,
        Title = "Color Picker",
        InitialDockState = Enum.InitialDockState.Float,
        InitialEnabled = false,
        OverridePreviousState = false,
        DefaultWidth = 260,
        DefaultHeight = 260,
        MinimumWidth = 220,
        MinimumHeight = 245,
    }) :: DockWidgetPluginGui
    ColorPickerWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    Scope:New(Jian.Background, {
        Parent = ColorPickerWidget,
    })

    local ColorPickerRoot = Scope:New("Frame", {
        Parent = ColorPickerWidget,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    })

    Scope:New(Jian.Text, {
        Parent = ColorPickerRoot,
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -24, 0, 20),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = Scope:Computed(function(use)
            local Index = use(ActiveColorPointIndex)
            local Points = use(ColorSequencePoints)
            local Point = Index and Points[Index] or nil
            return if Point then string.format("Point at %.3f", Point.Time) else "Select a color point"
        end),
        Active = false,
    })

    Scope:New(ColorPicker, {
        Parent = ColorPickerRoot,
        Position = UDim2.fromOffset(12, 34),
        Size = UDim2.new(1, -24, 0, 198),
        Value = ColorPickerValue,
        Active = Scope:Computed(function(use)
            return use(ActiveColorPointIndex) ~= nil
        end),
    })

    local function SyncPickerFromPoint(index)
        local Point = index and ColorSequencePoints.Value[index] or nil
        if not Point then
            return
        end

        IsSyncingColorPicker = true
        ColorPickerValue.Value = EffectOps.OklabPointToColor3(Point)
        IsSyncingColorPicker = false
    end

    Scope:AddObject(Seam.OnChanged(ColorPickerValue, function()
        if IsSyncingColorPicker then
            return
        end

        local Index = ActiveColorPointIndex.Value
        local ExistingPoint = Index and ColorSequencePoints.Value[Index] or nil
        if not ExistingPoint then
            return
        end

        local UpdatedPoints = table.clone(ColorSequencePoints.Value)
        UpdatedPoints[Index] = EffectOps.Color3ToOklabPoint(ColorPickerValue.Value, ExistingPoint.Time)
        ColorSequencePoints.Value = UpdatedPoints
    end))

    local UpdateWarningText = Scope:Value("")
    Scope:New("TextLabel", {
        Parent = Container,
        LayoutOrder = -1,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = UpdateWarningText,
        TextWrapped = true,
        TextColor3 = Color3.fromRGB(255, 196, 72),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        Visible = Scope:Computed(function(use)
            return use(UpdateWarningText) ~= ""
        end),
    })

    task.spawn(function()
        local RemoteVersion, PermissionDenied = FetchGitHubVersion()
        if PermissionDenied then
            UpdateWarningText.Value = HTTP_PERMISSION_WARNING
            return
        end

        local LocalVersion = ReadLocalVersion()
        if not LocalVersion or not RemoteVersion then
            return
        end

        if IsRemoteVersionNewer(RemoteVersion, LocalVersion) then
            UpdateWarningText.Value = string.format(
                "Update available: %s (you have %s). Please update Effect Designer Suite.",
                RemoteVersion,
                LocalVersion
            )
        end
    end)

    Scope:New("TextLabel", {
        Parent = Container,
        LayoutOrder = 0,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = SelectionSummary,
        TextWrapped = true,
        TextColor3 = Color3.fromRGB(220, 220, 220),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Font = Enum.Font.Gotham,
        TextSize = 13,
    })

    local AssetWidget = Scope:New(Jian.Widget, {
        WidgetId = ASSETS_WIDGET_ID,
        Title = ASSETS_WIDGET_TITLE,
        InitialDockState = Enum.InitialDockState.Float,
        InitialEnabled = false,
        OverridePreviousState = false,
        DefaultWidth = 760,
        DefaultHeight = 560,
        MinimumWidth = 480,
        MinimumHeight = 320,
    }) :: DockWidgetPluginGui

    AssetWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    Scope:New(Jian.Background, {
        Parent = AssetWidget,
    })

    local AssetRoot = Scope:New("Frame", {
        Parent = AssetWidget,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        [Seam.Children] = {
            Scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 16),
                PaddingBottom = UDim.new(0, 16),
                PaddingLeft = UDim.new(0, 16),
                PaddingRight = UDim.new(0, 16),
            }),
        },
    })

    Scope:New(Jian.Text, {
        Parent = AssetRoot,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = "Insert creates a ParticleEmitter. Replace applies to selected ParticleEmitters, Beams, and Trails.",
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    local AssetNavigation = Scope:New("ScrollingFrame", {
        Parent = AssetRoot,
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(0, 152, 1, -36),
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromScale(0, 0),
        ScrollBarThickness = 6,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 8),
            }),
            Scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
            Scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 10),
                PaddingBottom = UDim.new(0, 10),
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
            }),
            Scope:New("UIListLayout", {
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        },
    })

    local AssetGridFrame = Scope:New("ScrollingFrame", {
        Parent = AssetRoot,
        Position = UDim2.fromOffset(168, 36),
        Size = UDim2.new(1, -504, 1, -36),
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromScale(0, 0),
        ScrollBarThickness = 6,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 8),
            }),
            Scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
            Scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 12),
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
            }),
            Scope:New("UIGridLayout", {
                CellSize = UDim2.fromOffset(188, 76),
                CellPadding = UDim2.fromOffset(10, 10),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        },
    })

    local AssetGridEmptyText = Scope:New(Jian.Text, {
        Parent = AssetGridFrame,
        Text = Scope:Computed(function(use)
            if use(SelectedAssetCategory) then
                return ""
            end

            return "Select a category"
        end),
        Size = UDim2.new(1, -24, 0, 24),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    local InsertAssetPreset
    local ReplaceAssetPreset

    local AssetPreviewPane = Scope:New("Frame", {
        Parent = AssetRoot,
        Position = UDim2.new(1, -320, 0, 36),
        Size = UDim2.new(0, 320, 1, -36),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(36, 36, 36),
        BorderSizePixel = 0,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 8),
            }),
            Scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
            Scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 12),
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
            }),
        },
    })

    Scope:New(Jian.Text, {
        Parent = AssetPreviewPane,
        LayoutOrder = 1,
        Text = Scope:Computed(function(use)
            local Asset = use(SelectedAsset)

            if not Asset then
                return "Select an asset preset"
            end

            return string.format("%s %03d", Asset.Type, Asset.CategoryIndex)
        end),
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 16,
    })

    local PreviewFrameHost = Scope:New("Frame", {
        Parent = AssetPreviewPane,
        LayoutOrder = 2,
        Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 0, 184),
        BackgroundTransparency = 1,
    })

    local AssetGridInstances = {}
    local RefreshSelectedAssetPreview

    local function ClearAssetGrid()
        for _, instance in AssetGridInstances do
            instance:Destroy()
        end

        table.clear(AssetGridInstances)
    end

    local function RefreshAssetGrid()
        ClearAssetGrid()
        AssetGridFrame.CanvasPosition = Vector2.zero

        local Category = SelectedAssetCategory.Value

        if not Category or not AssetCatalog then
            AssetGridEmptyText.Visible = true
            return
        end

        AssetGridEmptyText.Visible = false

        for assetOrder, asset in ipairs(AssetCatalog.AssetsByCategory[Category] or {}) do
            local Card = CreateAssetCard(
                Scope,
                PreviewEntries,
                asset,
                assetOrder,
                Scope:Computed(function(use)
                    return use(SelectedAsset) == asset
                end),
                function(newAsset)
                    SelectedAsset.Value = newAsset
                    RefreshSelectedAssetPreview()
                end
            )

            Card.Parent = AssetGridFrame
            table.insert(AssetGridInstances, Card)
        end
    end

    function RefreshSelectedAssetPreview()
        for _, child in PreviewFrameHost:GetChildren() do
            child:Destroy()
        end

        table.clear(PreviewEntries)

        local Asset = SelectedAsset.Value

        if not Asset then
            return
        end

        CreatePreviewFrame(Scope, PreviewEntries, Asset, 1, true, UDim2.new(1, 0, 0, 184)).Parent = PreviewFrameHost
    end

    Scope:New(Jian.Text, {
        Parent = AssetPreviewPane,
        LayoutOrder = 3,
        Position = UDim2.fromOffset(0, 226),
        Size = UDim2.new(1, 0, 0, 18),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = Scope:Computed(function(use)
            local Asset = use(SelectedAsset)

            if not Asset then
                return "Texture: -"
            end

            return string.format("Texture: %s", tostring(Asset.TextureId))
        end),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12,
        Active = false,
    })

    Scope:New(Jian.Text, {
        Parent = AssetPreviewPane,
        LayoutOrder = 4,
        Position = UDim2.fromOffset(0, 248),
        Size = UDim2.new(1, 0, 0, 18),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = Scope:Computed(function(use)
            local Asset = use(SelectedAsset)

            if not Asset then
                return "Type: -"
            end

            return "Type: " .. GetFlipbookTypeLabel(Asset.FlipbookType)
        end),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12,
        Active = false,
    })

    Scope:New(Jian.TextButton, {
        Parent = AssetPreviewPane,
        Position = UDim2.fromOffset(0, 280),
        Size = UDim2.new(1, 0, 0, 32),
        Text = "Insert",
        Active = Scope:Computed(function(use)
            return use(SelectedAsset) ~= nil and use(HasRawSelection)
        end),
        [Seam.OnEvent("Activated")] = function()
            local Asset = SelectedAsset.Value

            if not Asset then
                return
            end

            InsertAssetPreset(Asset)
        end,
    })

    Scope:New(Jian.TextButton, {
        Parent = AssetPreviewPane,
        Position = UDim2.fromOffset(0, 320),
        Size = UDim2.new(1, 0, 0, 32),
        Text = "Replace",
        Active = Scope:Computed(function(use)
            return use(SelectedAsset) ~= nil and use(HasReplaceTargets)
        end),
        [Seam.OnEvent("Activated")] = function()
            local Asset = SelectedAsset.Value

            if not Asset then
                return
            end

            ReplaceAssetPreset(Asset)
        end,
    })

    function InsertAssetPreset(asset)
        local Target = ResolveParticleInsertParent(States.RawSelection.Value[1])

        if not Target then
            return
        end

        local NewEmitter = Instance.new("ParticleEmitter")
        NewEmitter.Name = string.format("%sPreset", asset.Type)
        NewEmitter.Size = NumberSequence.new(1)
        NewEmitter.Rate = 1
        NewEmitter.Lifetime = NumberRange.new(2, 2)
        NewEmitter.Enabled = true
        ApplyAssetToTextureObject(asset, NewEmitter)

        local Success = pcall(function()
            NewEmitter.Parent = Target
        end)

        if not Success then
            NewEmitter:Destroy()
            return
        end

        SelectionService:Set({NewEmitter})
    end

    function ReplaceAssetPreset(asset)
        local Targets = {}
        local Seen = {}

        for _, instance in States.CurrentlySelected.Value do
            if (instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail")) and not Seen[instance] then
                Seen[instance] = true
                table.insert(Targets, instance)
            end
        end

        for _, instance in States.RawSelection.Value do
            if (instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail")) and not Seen[instance] then
                Seen[instance] = true
                table.insert(Targets, instance)
            end
        end

        for _, instance in Targets do
            ApplyAssetToTextureObject(asset, instance)
        end
    end

    local function EnsureAssetBrowserInitialized()
        if IsAssetBrowserInitialized then
            return
        end

        AssetCatalog = AssetUtils:GetAssetCatalog()

        if AssetCatalog.Categories[1] and AssetCatalog.AssetsByCategory[AssetCatalog.Categories[1]] then
            SelectedAssetCategory.Value = AssetCatalog.Categories[1]
            DefaultSelectedAsset = AssetCatalog.AssetsByCategory[AssetCatalog.Categories[1]][1]
        end

        for categoryOrder, category in ipairs(AssetCatalog.Categories) do
            local CategoryButton = Scope:New(Jian.TextButton, {
                Parent = AssetNavigation,
                LayoutOrder = categoryOrder,
                Size = UDim2.new(1, 0, 0, 30),
                Text = string.format("%s (%d)", category, #(AssetCatalog.AssetsByCategory[category] or {})),
                Active = true,
                [Seam.OnEvent("Activated")] = function()
                    SelectedAssetCategory.Value = category

                    if not SelectedAsset.Value or SelectedAsset.Value.Type ~= category then
                        SelectedAsset.Value = (AssetCatalog.AssetsByCategory[category] or {})[1]
                        RefreshSelectedAssetPreview()
                    end

                    RefreshAssetGrid()
                end,
            })

            CategoryButton.Parent = AssetNavigation
        end

        RefreshAssetGrid()

        IsAssetBrowserInitialized = true
    end

    local function IsPreviewContentReady(entry)
        if entry.Preloaded or entry.Image.IsLoaded then
            return true
        end

        local Success, Status = pcall(function()
            return ContentProvider:GetAssetFetchStatus(entry.ContentId)
        end)

        return Success and (Status == Enum.AssetFetchStatus.Success or Status == Enum.AssetFetchStatus.Failure)
    end

    Scope:AddObject(RunService.RenderStepped:Connect(function()
        if not AssetWidget.Enabled then
            return
        end

        for index = #PendingPreviewLoads, 1, -1 do
            local Entry = PendingPreviewLoads[index]

            if Entry.Image.Parent == nil then
                table.remove(PendingPreviewLoads, index)
            elseif IsPreviewContentReady(Entry) then
                Entry.Indicator.Visible = false
                Entry.Image.ImageTransparency = 0

                if Entry.PreviewEntry then
                    Entry.PreviewEntry.StartedAt = os.clock()
                end

                table.remove(PendingPreviewLoads, index)
            end
        end

        local Now = os.clock()

        for _, preview in PreviewEntries do
            if preview.Image.ImageTransparency ~= 0 then
                continue
            end

            local FrameIndex = math.floor((Now - preview.StartedAt) * preview.FramesPerSecond) % preview.TotalFrames
            local Column = FrameIndex % preview.GridSize
            local Row = math.floor(FrameIndex / preview.GridSize)

            preview.Image.Position = UDim2.fromScale(-Column, -Row)
        end
    end))

    local function BindEmitAttributeBox(textBox, textState, attributeName : string)
        local IsFocused = false
        local FocusStartText = textState.Value
        local IsDirty = false

        Scope:AddObject(textBox.Focused:Connect(function()
            IsFocused = true
            FocusStartText = textBox.Text
            IsDirty = false
        end))

        Scope:AddObject(textBox:GetPropertyChangedSignal("Text"):Connect(function()
            if not IsFocused then
                return
            end

            IsDirty = textBox.Text ~= FocusStartText
        end))

        Scope:AddObject(textBox.FocusLost:Connect(function()
            IsFocused = false

            if not IsDirty then
                return
            end

            local CurrentlySelected = States.CurrentlySelected.Value
            if #CurrentlySelected == 0 then
                IsDirty = false
                return
            end

            local Number = tonumber(textState.Value)
            if not Number or Number == 0 then
                IsDirty = false
                return
            end

            for _, instance in CurrentlySelected do
                instance:SetAttribute(attributeName, Number)
            end

            IsDirty = false
            FocusStartText = textBox.Text
        end))
    end

    local function CreateEmitAttributeField(parent, position : UDim2, size : UDim2, labelText : string, attributeName : string, textState)
        local Column = Scope:New("Frame", {
            Parent = parent,
            Position = position,
            Size = size,
            BackgroundTransparency = 1,
        })

        Scope:New(Jian.Text, {
            Parent = Column,
            Text = labelText,
            Size = UDim2.new(1, 0, 0, EMIT_FIELD_LABEL_HEIGHT),
            AutomaticSize = Enum.AutomaticSize.None,
            TextXAlignment = Enum.TextXAlignment.Left,
            Active = false,
        })

        local TextBox = CreateBoundTextBox(
            Scope,
            Column,
            textState,
            HasEditableSelection,
            "0",
            UDim2.fromOffset(0, EMIT_FIELD_LABEL_HEIGHT),
            UDim2.new(1, 0, 0, EMIT_FIELD_BOX_HEIGHT)
        )
        BindEmitAttributeBox(TextBox, textState, attributeName)

        return Column
    end

    local EmitAttributesRow = Scope:New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, EMIT_ATTRIBUTE_ROW_HEIGHT),
        LayoutOrder = 1,
    })
    CreateEmitAttributeField(EmitAttributesRow, UDim2.fromScale(0, 0), UDim2.new(0.32, 0, 1, 0), "Count", "EmitCount", EmitCountText)
    CreateEmitAttributeField(EmitAttributesRow, UDim2.fromScale(0.34, 0), UDim2.new(0.32, 0, 1, 0), "Delay", "EmitDelay", EmitDelayText)
    CreateEmitAttributeField(EmitAttributesRow, UDim2.fromScale(0.68, 0), UDim2.new(0.32, 0, 1, 0), "Duration", "EmitDuration", EmitDurationText)

    local EmitButton = CreateActionButton(Scope, 3, "Emit", States.IsEmittable, function()
        EmitUtils:EmitCurrent()
    end)

    local RepeatRow = Scope:New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, EMIT_ATTRIBUTE_ROW_HEIGHT),
        LayoutOrder = 2,
    })

    local RepeatDelayColumn = Scope:New("Frame", {
        Parent = RepeatRow,
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.new(0.48, 0, 1, 0),
        BackgroundTransparency = 1,
    })

    Scope:New(Jian.Text, {
        Parent = RepeatDelayColumn,
        Text = "repeat delay",
        Size = UDim2.new(1, 0, 0, EMIT_FIELD_LABEL_HEIGHT),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    local RepeatDelayBox = CreateBoundTextBox(
        Scope,
        RepeatDelayColumn,
        RepeatEmitDelayText,
        States.RepeatEmit,
        "0",
        UDim2.fromOffset(0, EMIT_FIELD_LABEL_HEIGHT),
        UDim2.new(1, 0, 0, EMIT_FIELD_BOX_HEIGHT)
    )

    Scope:AddObject(RepeatDelayBox.FocusLost:Connect(function()
        local Delay = tonumber(RepeatEmitDelayText.Value)

        if not Delay then
            RepeatEmitDelayText.Value = tostring(States.RepeatEmitDelay.Value)
            return
        end

        States.RepeatEmitDelay.Value = Delay
    end))

    Scope:New(Jian.Checkbox, {
        Parent = RepeatRow,
        Position = UDim2.new(0.52, 0, 0.5, -10),
        Size = UDim2.new(0.48, 0, 0, 20),
        Title = "Repeat Emit",
        Active = true,
        Value = States.RepeatEmit,
    })

    local function GetPropertyEditTargets()
        local Inspected = GetInspectedInstance()
        if not Inspected then
            return {}
        end

        local Targets = {}
        for _, instance in States.RawSelection.Value do
            if instance == Inspected then
                table.insert(Targets, instance)
            elseif Inspected:IsA("BasePart") and instance:IsA("BasePart") then
                table.insert(Targets, instance)
            elseif instance.ClassName == Inspected.ClassName then
                table.insert(Targets, instance)
            end
        end

        return Targets
    end

    local function OpenCurveEditor(property : string)
        CurvePropertyText.Value = property
        ReadCurveState()
        CurveEditorDock.Enabled = true
    end

    local function OpenColorSequenceEditor()
        ReadColorSequenceState()
        ColorSequenceDock.Enabled = true
    end

    Scope:AddObject(Seam.OnChanged(States.CurrentlySelected, function()
        ReadCurveState()
        ReadColorSequenceState()
    end))
    Scope:AddObject(Seam.OnChanged(CurvePropertyText, ReadCurveState))
    ReadColorSequenceState()

    local PropertyRowsHost = Scope:New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,

        [Seam.Children] = {
            Scope:New("UIListLayout", {
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        },
    })

    local PropertyRowInstances = {}
    local PropertyRowConnections = {}

    local function ClearPropertyRows()
        for _, connection in PropertyRowConnections do
            connection:Disconnect()
        end
        table.clear(PropertyRowConnections)

        for _, row in PropertyRowInstances do
            row:Destroy()
        end
        table.clear(PropertyRowInstances)
    end

    local function CreateSplitNumericInputs(parent, position, size, placeholders, getNumbers, applyNumbers, instance, property)
        local Count = #placeholders
        local GapDeduction = math.ceil(4 * (Count - 1) / Count)
        local Host = Scope:New("Frame", {
            Parent = parent,
            Position = position,
            Size = size,
            BackgroundTransparency = 1,

            [Seam.Children] = {
                Scope:New("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    Padding = UDim.new(0, 4),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                }),
            },
        })

        local Numbers = getNumbers()
        local FieldStates = {}
        local FocusedCount = 0

        for index, placeholder in placeholders do
            local FieldState = Scope:Value(tostring(Numbers[index] or 0))
            FieldStates[index] = FieldState

            local Box = CreateBoundTextBox(
                Scope,
                Host,
                FieldState,
                true,
                placeholder,
                UDim2.fromOffset(0, 0),
                UDim2.new(1 / Count, -GapDeduction, 1, -4)
            )
            Box.LayoutOrder = index

            Scope:AddObject(Box.Focused:Connect(function()
                FocusedCount += 1
            end))

            Scope:AddObject(Box.FocusLost:Connect(function()
                FocusedCount = math.max(FocusedCount - 1, 0)

                local Parsed = {}
                for fieldIndex, fieldState in FieldStates do
                    local Number = tonumber(fieldState.Value)
                    if not Number then
                        local Latest = getNumbers()
                        for resetIndex, resetState in FieldStates do
                            resetState.Value = tostring(Latest[resetIndex] or 0)
                        end
                        return
                    end

                    Parsed[fieldIndex] = Number
                end

                applyNumbers(Parsed)
            end))
        end

        local SignalSuccess, ChangedSignal = pcall(function()
            return instance:GetPropertyChangedSignal(property)
        end)
        if SignalSuccess then
            table.insert(PropertyRowConnections, ChangedSignal:Connect(function()
                if FocusedCount > 0 then
                    return
                end

                local Latest = getNumbers()
                for index, fieldState in FieldStates do
                    fieldState.Value = tostring(Latest[index] or 0)
                end
            end))
        end
    end

    local function GetPreviewNumberSequence(instance, property)
        local ReadSuccess, Value = pcall(function()
            return instance[property]
        end)
        if ReadSuccess and typeof(Value) == "NumberSequence" then
            return Value
        end

        local EncodedPoints = instance:GetAttribute(CurveAttributeName(property))
        local EncodedMinRange = instance:GetAttribute(CurveRangeAttributeName(property, "MinRange"))
        local EncodedMaxRange = instance:GetAttribute(CurveRangeAttributeName(property, "MaxRange"))
        if typeof(EncodedPoints) == "string" then
            local DecodeSuccess, Decoded = pcall(function()
                return HttpService:JSONDecode(EncodedPoints)
            end)
            if DecodeSuccess and typeof(Decoded) == "table" and #Decoded >= 2 then
                local MinRange = tonumber(EncodedMinRange) or 0
                local MaxRange = tonumber(EncodedMaxRange) or 1
                return EffectOps.BuildNumberSequenceFromCurve(Decoded, MinRange, MaxRange)
            end
        end

        return NumberSequence.new(0.5)
    end

    local function GetPreviewColorSequence(instance)
        if HasColorSequence(instance) then
            return instance.Color
        end

        local EncodedPoints = instance:GetAttribute(COLOR_SEQUENCE_ATTRIBUTE)
        if typeof(EncodedPoints) == "string" then
            local DecodeSuccess, Decoded = pcall(function()
                return HttpService:JSONDecode(EncodedPoints)
            end)
            if DecodeSuccess and typeof(Decoded) == "table" then
                return EffectOps.BuildColorSequenceFromOklabPoints(Decoded)
            end
        end

        local ColorSuccess, Color = pcall(function()
            return instance.Color
        end)
        if ColorSuccess and typeof(Color) == "Color3" then
            return ColorSequence.new(Color)
        end

        return ColorSequence.new(Color3.new(1, 1, 1))
    end

    local function UpdateCurvePreview(previewRoot, sequence)
        local Path = previewRoot:FindFirstChild("CurvePath")
        local Gradient = previewRoot:FindFirstChildWhichIsA("UIGradient")
        if typeof(sequence) ~= "NumberSequence" then
            return
        end

        local MinValue, MaxValue = GetNumberSequenceRange(sequence)
        local ValueRange = MaxValue - MinValue
        local ControlPoints = {}
        local ColorKeys = {}

        for index = 0, CURVE_PREVIEW_LINE_SAMPLES do
            local Time = index / CURVE_PREVIEW_LINE_SAMPLES
            local Value = SampleNumberSequence(sequence, Time)
            local Alpha = math.clamp((Value - MinValue) / ValueRange, 0, 1)
            table.insert(ControlPoints, { Time = Time, Alpha = Alpha })
        end

        for index = 0, CURVE_PREVIEW_GRADIENT_SAMPLES do
            local Time = index / CURVE_PREVIEW_GRADIENT_SAMPLES
            local Value = SampleNumberSequence(sequence, Time)
            local Alpha = math.clamp((Value - MinValue) / ValueRange, 0, 1)
            table.insert(ColorKeys, ColorSequenceKeypoint.new(Time, Color3.fromRGB(Alpha * 220 + 35, Alpha * 220 + 35, Alpha * 230 + 25)))
        end

        if Path then
            local PathPoints = {}
            local PathSuccess = pcall(function()
                for _, sample in ControlPoints do
                    table.insert(PathPoints, Path2DControlPoint.new(UDim2.fromScale(sample.Time, 1 - sample.Alpha)))
                end
                Path.Closed = false
                Path:SetControlPoints(PathPoints)
            end)
            Path.Visible = PathSuccess
        end

        if Gradient then
            pcall(function()
                Gradient.Color = ColorSequence.new(ColorKeys)
            end)
        end
    end

    local function CreateSequencePreviewButton(parent, size, isColorSequence, instance, property, callback)
        local Button = Scope:New("TextButton", {
            Parent = parent,
            Position = UDim2.new(0.28, 0, 0, 4),
            Size = UDim2.new(size.X.Scale, size.X.Offset, 1, -8),
            BackgroundColor3 = if isColorSequence then Color3.new(1, 1, 1) else Color3.fromRGB(28, 28, 32),
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            [Seam.OnEvent("Activated")] = callback,
        })

        Scope:New("UICorner", {
            Parent = Button,
            CornerRadius = UDim.new(0, 6),
        })
        Scope:New("UIStroke", {
            Parent = Button,
            Color = Color3.fromRGB(56, 56, 56),
            Thickness = 1,
        })

        local Gradient = Scope:New("UIGradient", {
            Parent = Button,
        })

        if not isColorSequence then
            pcall(function()
                local Path = Instance.new("Path2D")
                Path.Name = "CurvePath"
                Path.Thickness = 1.5
                Path.Color3 = Color3.fromRGB(186, 214, 255)
                Path.ZIndex = 2
                Path.Closed = false
                Path.Parent = Button
            end)
        end

        local function RefreshPreview()
            if isColorSequence then
                Gradient.Color = GetPreviewColorSequence(instance)
            else
                UpdateCurvePreview(Button, GetPreviewNumberSequence(instance, property))
            end
        end

        RefreshPreview()

        local SignalSuccess, ChangedSignal = pcall(function()
            return instance:GetPropertyChangedSignal(property)
        end)
        if SignalSuccess then
            table.insert(PropertyRowConnections, ChangedSignal:Connect(RefreshPreview))
        end

        table.insert(PropertyRowConnections, instance.AttributeChanged:Connect(function()
            RefreshPreview()
        end))

        return Button
    end

    local function ReadInstanceCFrame(instance, property)
        local ReadSuccess, Value = pcall(function()
            return instance[property]
        end)
        if ReadSuccess and typeof(Value) == "CFrame" then
            return Value
        end

        return CFrame.new()
    end

    local function GetCFrameComponentVector(instance, property, kind)
        local Current = ReadInstanceCFrame(instance, property)
        if kind == "Orientation" then
            return GetCFrameOrientationDegrees(Current)
        end

        return Current.Position
    end

    local function ApplyCFrameComponentVector(property, kind, vector)
        for _, target in GetPropertyEditTargets() do
            pcall(function()
                local Current = ReadInstanceCFrame(target, property)
                if kind == "Orientation" then
                    target[property] = CFrameFromPositionAndOrientation(Current.Position, vector)
                else
                    target[property] = CFrameFromPositionAndOrientation(vector, GetCFrameOrientationDegrees(Current))
                end
            end)
        end
    end

    local function CreateInspectorPropertyRow(instance, property : string, layoutOrder : number, displayName : string?, cframeKind : string?)
        local Row = CreateRow(Scope, layoutOrder)
        Row.Parent = PropertyRowsHost

        local IconClusterWidth = GetPropertyIconClusterWidth()
        local ValueSize = UDim2.new(0.72, -IconClusterWidth - 4, 1, 0)

        Scope:New(Jian.Text, {
            Parent = Row,
            Text = displayName or property,
            Size = UDim2.new(0.28, -4, 1, 0),
            AutomaticSize = Enum.AutomaticSize.None,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ClipsDescendants = true,
        })

        local Success, CurrentValue = pcall(function()
            return instance[property]
        end)
        local ValueType = if Success then typeof(CurrentValue) else nil
        local IsColorSequence = PropertyMaps.IsColorSequenceProperty(instance, property) or ValueType == "ColorSequence"
        local IsCurve = (not IsColorSequence) and (PropertyMaps.IsCurveProperty(instance, property) or ValueType == "NumberSequence")

        if IsCurve or IsColorSequence then
            CreateSequencePreviewButton(Row, ValueSize, IsColorSequence, instance, property, function()
                if IsColorSequence then
                    OpenColorSequenceEditor()
                else
                    OpenCurveEditor(property)
                end
            end)
        elseif ValueType == "boolean" then
            local BoolState = Scope:Value(CurrentValue == true)
            local IsSyncing = false

            Scope:New(Jian.Checkbox, {
                Parent = Row,
                Position = UDim2.new(0.28, 0, 0, 8),
                Size = UDim2.new(ValueSize.X.Scale, ValueSize.X.Offset, 0, 20),
                Title = "",
                Active = true,
                Value = BoolState,
            })

            Scope:AddObject(Seam.OnChanged(BoolState, function()
                if IsSyncing then
                    return
                end

                for _, target in GetPropertyEditTargets() do
                    pcall(function()
                        target[property] = BoolState.Value
                    end)
                end
            end))

            local SignalSuccess, ChangedSignal = pcall(function()
                return instance:GetPropertyChangedSignal(property)
            end)
            if SignalSuccess then
                table.insert(PropertyRowConnections, ChangedSignal:Connect(function()
                    local ValueSuccess, Value = pcall(function()
                        return instance[property]
                    end)
                    if not ValueSuccess or Value == BoolState.Value then
                        return
                    end

                    IsSyncing = true
                    BoolState.Value = Value == true
                    IsSyncing = false
                end))
            end
        elseif ValueType == "Vector3" or cframeKind ~= nil then
            CreateSplitNumericInputs(
                Row,
                UDim2.new(0.28, 0, 0, 0),
                ValueSize,
                { "X", "Y", "Z" },
                function()
                    if cframeKind then
                        local Vector = GetCFrameComponentVector(instance, property, cframeKind)
                        return { Vector.X, Vector.Y, Vector.Z }
                    end

                    local LatestSuccess, LatestValue = pcall(function()
                        return instance[property]
                    end)
                    if LatestSuccess and typeof(LatestValue) == "Vector3" then
                        return { LatestValue.X, LatestValue.Y, LatestValue.Z }
                    end

                    return { 0, 0, 0 }
                end,
                function(numbers)
                    local Value = Vector3.new(numbers[1], numbers[2], numbers[3])
                    if cframeKind then
                        ApplyCFrameComponentVector(property, cframeKind, Value)
                        return
                    end

                    for _, target in GetPropertyEditTargets() do
                        pcall(function()
                            target[property] = Value
                        end)
                    end
                end,
                instance,
                property
            )
        elseif ValueType == "NumberRange" then
            CreateSplitNumericInputs(
                Row,
                UDim2.new(0.28, 0, 0, 0),
                ValueSize,
                { "Min", "Max" },
                function()
                    local LatestSuccess, LatestValue = pcall(function()
                        return instance[property]
                    end)
                    if LatestSuccess and typeof(LatestValue) == "NumberRange" then
                        return { LatestValue.Min, LatestValue.Max }
                    end

                    return { 0, 0 }
                end,
                function(numbers)
                    local MinValue = numbers[1]
                    local MaxValue = numbers[2]
                    if MinValue > MaxValue then
                        MinValue, MaxValue = MaxValue, MinValue
                    end

                    local Value = NumberRange.new(MinValue, MaxValue)
                    for _, target in GetPropertyEditTargets() do
                        pcall(function()
                            target[property] = Value
                        end)
                    end
                end,
                instance,
                property
            )
        elseif ValueType == "EnumItem" then
            local EnumState = Scope:Value(CurrentValue.Name)
            local EnumOptions = GetEnumItemNames(CurrentValue)
            local IsSyncing = false
            local DropdownHost = Scope:New("Frame", {
                Parent = Row,
                Position = UDim2.new(0.28, 0, 0, 0),
                Size = ValueSize,
                BackgroundTransparency = 1,
                ClipsDescendants = false,
                ZIndex = 40,
            })

            Scope:New(Dropdown, {
                Parent = DropdownHost,
                Value = EnumState,
                Options = EnumOptions,
                Active = true,
            })

            Scope:AddObject(Seam.OnChanged(EnumState, function()
                if IsSyncing then
                    return
                end

                local ItemSuccess, Item = pcall(function()
                    return CurrentValue.EnumType[EnumState.Value]
                end)
                if not ItemSuccess or typeof(Item) ~= "EnumItem" then
                    return
                end

                for _, target in GetPropertyEditTargets() do
                    pcall(function()
                        target[property] = Item
                    end)
                end
            end))

            local SignalSuccess, ChangedSignal = pcall(function()
                return instance:GetPropertyChangedSignal(property)
            end)
            if SignalSuccess then
                table.insert(PropertyRowConnections, ChangedSignal:Connect(function()
                    local ValueSuccess, Value = pcall(function()
                        return instance[property]
                    end)
                    if not ValueSuccess or typeof(Value) ~= "EnumItem" or Value.Name == EnumState.Value then
                        return
                    end

                    IsSyncing = true
                    EnumState.Value = Value.Name
                    IsSyncing = false
                end))
            end
        else
            local TextState = Scope:Value(if Success then FormatPropertyValue(CurrentValue) else "")
            local IsFocused = false

            local TextBox = CreateBoundTextBox(
                Scope,
                Row,
                TextState,
                true,
                property,
                UDim2.new(0.28, 0, 0, 0),
                ValueSize
            )

            Scope:AddObject(TextBox.Focused:Connect(function()
                IsFocused = true
            end))

            Scope:AddObject(TextBox.FocusLost:Connect(function()
                IsFocused = false

                local LatestSuccess, LatestValue = pcall(function()
                    return instance[property]
                end)
                if not LatestSuccess then
                    return
                end

                local Parsed = ParsePropertyValue(LatestValue, TextState.Value)
                if Parsed == nil then
                    TextState.Value = FormatPropertyValue(LatestValue)
                    return
                end

                for _, target in GetPropertyEditTargets() do
                    pcall(function()
                        target[property] = Parsed
                    end)
                end
            end))

            local SignalSuccess, ChangedSignal = pcall(function()
                return instance:GetPropertyChangedSignal(property)
            end)
            if SignalSuccess then
                table.insert(PropertyRowConnections, ChangedSignal:Connect(function()
                    if IsFocused then
                        return
                    end

                    local ValueSuccess, Value = pcall(function()
                        return instance[property]
                    end)
                    if ValueSuccess then
                        TextState.Value = FormatPropertyValue(Value)
                    end
                end))
            end
        end

        CreatePropertyIconButton(Scope, Row, COPY_BUTTON_IMAGE_ID, -IconClusterWidth, function()
            local CopySuccess, Value = pcall(function()
                if cframeKind then
                    return GetCFrameComponentVector(instance, property, cframeKind)
                end

                return instance[property]
            end)
            if CopySuccess then
                CopiedValue.Value = Value
            end
        end)

        CreatePropertyIconButton(Scope, Row, PASTE_BUTTON_IMAGE_ID, -PROPERTY_ICON_BUTTON_SIZE, function()
            local Value = CopiedValue.Value
            if Value == nil then
                return
            end

            if cframeKind then
                if typeof(Value) == "CFrame" then
                    Value = if cframeKind == "Orientation" then GetCFrameOrientationDegrees(Value) else Value.Position
                end

                if typeof(Value) == "Vector3" then
                    ApplyCFrameComponentVector(property, cframeKind, Value)
                end

                return
            end

            for _, target in GetPropertyEditTargets() do
                pcall(function()
                    target[property] = Value
                end)
            end
        end)

        return Row
    end

    local function RefreshPropertyInspector()
        ClearPropertyRows()

        local Inspected = GetInspectedInstance()
        if not Inspected then
            return
        end

        local LayoutOrder = 0
        for _, property in PropertyMaps.GetInspectorProperties(Inspected) do
            local ReadSuccess, Value = pcall(function()
                return Inspected[property]
            end)

            if ReadSuccess and typeof(Value) == "CFrame" then
                LayoutOrder += 1
                table.insert(PropertyRowInstances, CreateInspectorPropertyRow(
                    Inspected,
                    property,
                    LayoutOrder,
                    GetCFrameComponentLabel(property, "Position"),
                    "Position"
                ))
                LayoutOrder += 1
                table.insert(PropertyRowInstances, CreateInspectorPropertyRow(
                    Inspected,
                    property,
                    LayoutOrder,
                    GetCFrameComponentLabel(property, "Orientation"),
                    "Orientation"
                ))
            else
                LayoutOrder += 1
                table.insert(PropertyRowInstances, CreateInspectorPropertyRow(Inspected, property, LayoutOrder))
            end
        end
    end

    Scope:AddObject(Seam.OnChanged(States.RawSelection, RefreshPropertyInspector))
    RefreshPropertyInspector()

    local ResizeMultiplierSlider = Scope:New(SliderInput, {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 58),
        Title = "Multiplier",
        Min = 0.5,
        Max = 2,
        Step = 0.1,
        Value = ResizeMultiplierValue,
        AllowOutOfRangeText = true,
        Active = States.IsEmittable,
    })

    local ResizeApplyButton = CreateActionButton(Scope, 3, "Apply Resize", States.IsEmittable, function()
        EffectOps.ApplyResizeMultiplier(ResizeMultiplierValue.Value, States.CurrentlySelected.Value)
    end)

    local MathAmountSlider = Scope:New(SliderInput, {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 58),
        Title = "Amount",
        Min = -10,
        Max = 10,
        Step = 0.1,
        Value = MathAmountValue,
        AllowOutOfRangeText = true,
        Active = States.IsEmittable,
    })

    local MathPropertyRow = CreateRow(Scope, 3)
    CreateLabel(Scope, MathPropertyRow, "Property")
    local MathPropertyBox = CreateBoundTextBox(
        Scope,
        MathPropertyRow,
        MathPropertyText,
        States.IsEmittable,
        "Size",
        UDim2.fromScale(0.35, 0),
        UDim2.fromScale(0.65, 1)
    )

    Scope:AddObject(MathPropertyBox.FocusLost:Connect(function()
        MathPropertyText.Value = PropertyMaps.NormalizeParticleProperty(MathPropertyText.Value)
    end))

    local function RunMathOperation(operation : string)
        local Value = MathAmountValue.Value
        local Property = PropertyMaps.NormalizeParticleProperty(MathPropertyText.Value)

        EffectOps.ApplyMathOperation(Value, Property, operation, States.CurrentlySelected.Value)
        MathPropertyText.Value = Property
    end

    local MathAddButton = CreateActionButton(Scope, 4, "Add", States.IsEmittable, function()
        RunMathOperation("add")
    end)
    local MathSubtractButton = CreateActionButton(Scope, 5, "Subtract", States.IsEmittable, function()
        RunMathOperation("subtract")
    end)
    local MathMultiplyButton = CreateActionButton(Scope, 6, "Multiply", States.IsEmittable, function()
        RunMathOperation("multiply")
    end)
    local MathDivideButton = CreateActionButton(Scope, 7, "Divide", States.IsEmittable, function()
        RunMathOperation("divide")
    end)

    Scope:New(Jian.Text, {
        Parent = CurveEditorContainer,
        LayoutOrder = 1,
        Text = Scope:Computed(function(use)
            local Property = use(CurvePropertyText)
            if Property == "" then
                return "Select a curve property from Core"
            end

            return "Editing " .. Property
        end),
        Size = UDim2.new(1, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    local CurveEditorView = Scope:New(CurveEditor, {
        Parent = CurveEditorContainer,
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 180),
        Points = CurvePoints,
        Active = States.IsEmittable,
    })

    local CurveMinRangeRow = CreateRow(Scope, 3)
    CurveMinRangeRow.Parent = CurveEditorContainer
    CreateLabel(Scope, CurveMinRangeRow, "Range Min")
    CreateBoundTextBox(
        Scope,
        CurveMinRangeRow,
        CurveMinRangeText,
        States.IsEmittable,
        "0",
        UDim2.fromScale(0.35, 0),
        UDim2.fromScale(0.65, 1)
    )

    local CurveMaxRangeRow = CreateRow(Scope, 4)
    CurveMaxRangeRow.Parent = CurveEditorContainer
    CreateLabel(Scope, CurveMaxRangeRow, "Range Max")
    CreateBoundTextBox(
        Scope,
        CurveMaxRangeRow,
        CurveMaxRangeText,
        States.IsEmittable,
        "10",
        UDim2.fromScale(0.35, 0),
        UDim2.fromScale(0.65, 1)
    )

    local CurveApplyButton = CreateActionButton(Scope, 5, "Apply Curve", States.IsEmittable, function()
        local SelectedProperty = CurvePropertyText.Value
        local MinRange = tonumber(CurveMinRangeText.Value)
        local MaxRange = tonumber(CurveMaxRangeText.Value)

        if not SelectedProperty or SelectedProperty == "" then
            return
        end

        if not MinRange or not MaxRange or MinRange > MaxRange then
            return
        end

        local NewSequence = EffectOps.BuildNumberSequenceFromCurve(CurvePoints.Value, MinRange, MaxRange)
        local EncodedPoints = HttpService:JSONEncode(CurvePoints.Value)

        for _, instance in GetPropertyEditTargets() do
            if instance:IsA("BasePart") then
                PartAnimation.Ensure(instance, Bin)
                instance:SetAttribute(CurveAttributeName(SelectedProperty), EncodedPoints)
                instance:SetAttribute(CurveRangeAttributeName(SelectedProperty, "MinRange"), MinRange)
                instance:SetAttribute(CurveRangeAttributeName(SelectedProperty, "MaxRange"), MaxRange)
            else
                pcall(function()
                    instance[SelectedProperty] = NewSequence
                    instance:SetAttribute(CurveAttributeName(SelectedProperty), EncodedPoints)
                    instance:SetAttribute(CurveRangeAttributeName(SelectedProperty, "MinRange"), MinRange)
                    instance:SetAttribute(CurveRangeAttributeName(SelectedProperty, "MaxRange"), MaxRange)
                end)
            end
        end
    end)
    CurveApplyButton.Parent = CurveEditorContainer

    Scope:New(Jian.Text, {
        Parent = ColorSequenceContainer,
        LayoutOrder = 1,
        Text = "Editing Color",
        Size = UDim2.new(1, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    local ColorSequenceEditorView = Scope:New(ColorSequenceEditor, {
        Parent = ColorSequenceContainer,
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 76),
        Points = ColorSequencePoints,
        ActivePointIndex = ActiveColorPointIndex,
        Active = HasColorSequenceSelection,
        OnEditPoint = function(index)
            if not index then
                ColorPickerWidget.Enabled = false
                return
            end
            SyncPickerFromPoint(index)
            ColorPickerWidget.Enabled = true
        end,
    })

    local ColorSequenceApplyButton = CreateActionButton(Scope, 3, "Apply Color Sequence", HasColorSequenceSelection, function()
        local NewSequence = EffectOps.BuildColorSequenceFromOklabPoints(ColorSequencePoints.Value)
        local EncodedPoints = HttpService:JSONEncode(ColorSequencePoints.Value)

        for _, instance in GetPropertyEditTargets() do
            if HasColorSequence(instance) then
                pcall(function()
                    instance.Color = NewSequence
                    instance:SetAttribute(COLOR_SEQUENCE_ATTRIBUTE, EncodedPoints)
                end)
            elseif instance:IsA("BasePart") then
                PartAnimation.Ensure(instance, Bin)
                instance:SetAttribute(COLOR_SEQUENCE_ATTRIBUTE, EncodedPoints)
            end
        end
    end)
    ColorSequenceApplyButton.Parent = ColorSequenceContainer

    local CreateBezierAnimationButton = CreateActionButton(Scope, 2, "Create Bezier Animation", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        local Indicator = EmitUtils:CreateNewAnimationIndicator(SelectedInstances[1], "Bezier")
        SelectionService:Set({Indicator})
    end)

    local CreateTweenAnimationButton = CreateActionButton(Scope, 3, "Create Tween Animation", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        local Indicator = EmitUtils:CreateNewAnimationIndicator(SelectedInstances[1], "Tween")
        SelectionService:Set({Indicator})
    end)

    local InsertPlayEffectModuleButton = CreateActionButton(Scope, 2, "Insert PlayEffect Module", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        VfxApiInjection.EnsureSharedModules(Bin)

        local Parent = SelectedInstances[1]
        local Existing = Parent:FindFirstChild("PlayEffect")
        if Existing then
            Existing:Destroy()
        end

        local PlayEffectModule = Bin.PlaybackModules.PlayEffect:Clone()
        PlayEffectModule.Name = "PlayEffect"
        PlayEffectModule.Parent = Parent
        SelectionService:Set({PlayEffectModule})
    end)

    local InsertEffectModuleTemplateButton = CreateActionButton(Scope, 3, "Insert Effect Module Template", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        local EffectModuleTemplate = Bin.PlaybackModules.EffectModuleTemplate:Clone()
        EffectModuleTemplate.Parent = SelectedInstances[1]
        SelectionService:Set({EffectModuleTemplate})
    end)

    local PreviewPathsCheckboxRow = CreateRow(Scope, 4)
    Scope:New(Jian.Checkbox, {
        Parent = PreviewPathsCheckboxRow,
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 0, 20),
        Title = "Preview Paths",
        Active = true,
        Value = PreviewPathsEnabled,
    })

    local InjectApiCheckboxRow = CreateRow(Scope, 5)
    Scope:New(Jian.Checkbox, {
        Parent = InjectApiCheckboxRow,
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 0, 20),
        Title = "Inject VFX API",
        Active = true,
        Value = InjectVfxApiEnabled,
    })

    local WorldSpaceAccelCheckboxRow = CreateRow(Scope, 6)
    Scope:New(Jian.Checkbox, {
        Parent = WorldSpaceAccelCheckboxRow,
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 0, 20),
        Title = "World space acceleration for LockedToPart",
        Active = HasParticleEmitterSelection,
        Value = WorldSpaceAccelEnabled,
    })

    local ConfigurablePanel = Scope:New("Frame", {
        Parent = Container,
        LayoutOrder = 1,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = HasConfigurableSelection,

        [Seam.Children] = {
            Scope:New("UIListLayout", {
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        },
    })

    Scope:New(Jian.ListSection, {
        Parent = ConfigurablePanel,
        LayoutOrder = 1,
        Text = "Emit",
        Active = true,

        [Seam.Children] = {
            EmitAttributesRow,
            RepeatRow,
            EmitButton,
        },
    })
    Scope:New(Jian.Text, {
        Parent = ConfigurablePanel,
        LayoutOrder = 2,
        Text = "Properties",
        Size = UDim2.new(1, 0, 0, 18),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })
    PropertyRowsHost.Parent = ConfigurablePanel
    PropertyRowsHost.LayoutOrder = 3
    Scope:New(Jian.Text, {
        Parent = ConfigurablePanel,
        LayoutOrder = 4,
        Text = OTHER_TOOLS_HINT,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    Scope:New(Jian.ListSection, {
        Parent = EditingContainer,
        LayoutOrder = 1,
        Text = "Resize",
        Active = true,

        [Seam.Children] = {
            ResizeMultiplierSlider,
            ResizeApplyButton,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = EditingContainer,
        LayoutOrder = 2,
        Text = "Math Operations",
        Active = true,

        [Seam.Children] = {
            MathAmountSlider,
            MathPropertyRow,
            MathAddButton,
            MathSubtractButton,
            MathMultiplyButton,
            MathDivideButton,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = EditingContainer,
        LayoutOrder = 3,
        Text = "Preview paths",
        Active = true,

        [Seam.Children] = {
            PreviewPathsCheckboxRow,
        },
    })

    Scope:New(Jian.ListSection, {
        Parent = AdvancedContainer,
        LayoutOrder = 1,
        Text = "Animation",
        Active = true,

        [Seam.Children] = {
            CreateBezierAnimationButton,
            CreateTweenAnimationButton,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = AdvancedContainer,
        LayoutOrder = 2,
        Text = "Programming",
        Active = true,

        [Seam.Children] = {
            InsertPlayEffectModuleButton,
            InsertEffectModuleTemplateButton,
            InjectApiCheckboxRow,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = AdvancedContainer,
        LayoutOrder = 3,
        Text = "Behavior",
        Active = true,

        [Seam.Children] = {
            WorldSpaceAccelCheckboxRow,
        },
    })

    Scope:AddObject(AssetWidget:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not AssetWidget.Enabled then
            return
        end

        EnsureAssetBrowserInitialized()

        if not SelectedAsset.Value and DefaultSelectedAsset then
            SelectedAsset.Value = DefaultSelectedAsset
            RefreshSelectedAssetPreview()
        end
    end))

    local function RefreshWorldSpaceAccelCheckbox()
        IsSyncingWorldSpaceAccel = true

        local HasEnabled = false
        local HasDisabled = false

        for _, instance in States.CurrentlySelected.Value do
            if instance:IsA("ParticleEmitter") then
                if WorldSpaceAcceleration.IsEnabled(instance) then
                    HasEnabled = true
                else
                    HasDisabled = true
                end
            end
        end

        WorldSpaceAccelEnabled.Value = HasEnabled and not HasDisabled
        IsSyncingWorldSpaceAccel = false
    end

    local function RefreshCoreFields()
        SyncSelectionAttribute(EmitCountText, "EmitCount")
        SyncSelectionAttribute(EmitDelayText, "EmitDelay")
        SyncSelectionAttribute(EmitDurationText, "EmitDuration")
        RefreshWorldSpaceAccelCheckbox()
    end

    RefreshCoreFields()
    Scope:AddObject(Seam.OnChanged(States.PrimarySelected, RefreshCoreFields))
    Scope:AddObject(Seam.OnChanged(States.CurrentlySelected, RefreshWorldSpaceAccelCheckbox))
    Scope:AddObject(Seam.OnChanged(States.RepeatEmitDelay, function()
        RepeatEmitDelayText.Value = tostring(States.RepeatEmitDelay.Value)
    end))
    Scope:AddObject(Seam.OnChanged(States.RepeatEmit, function()
        if States.RepeatEmit.Value then
            EmitUtils:EnableRepeatEmit()
        else
            EmitUtils:DisableRepeatEmit()
        end
    end))
    Scope:AddObject(Seam.OnChanged(PreviewPathsEnabled, function()
        EmitUtils:SetPathPreviewEnabled(PreviewPathsEnabled.Value)
    end))
    Scope:AddObject(Seam.OnChanged(InjectVfxApiEnabled, function()
        if InjectVfxApiEnabled.Value then
            VfxApiInjection.Enable(Bin)
        else
            VfxApiInjection.Disable()
        end
    end))
    Scope:AddObject(Seam.OnChanged(WorldSpaceAccelEnabled, function()
        if IsSyncingWorldSpaceAccel then
            return
        end

        for _, instance in States.CurrentlySelected.Value do
            if instance:IsA("ParticleEmitter") then
                WorldSpaceAcceleration.SetEnabled(instance, WorldSpaceAccelEnabled.Value)
            end
        end
    end))

    EmitUtils:SetPathPreviewEnabled(PreviewPathsEnabled.Value)
    if InjectVfxApiEnabled.Value then
        VfxApiInjection.Enable(Bin)
    else
        VfxApiInjection.Disable()
    end

    EmitUtils:SetWidget(MainWidget)

    return {
        Core = MainWidget,
        Editing = EditingWidget,
        Advanced = AdvancedWidget,
        Presets = AssetWidget,
    }
end

return Interface

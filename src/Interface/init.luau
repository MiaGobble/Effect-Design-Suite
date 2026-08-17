local Interface = {}

local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")

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
local Dropdown = require(Components:FindFirstChild("Dropdown"))
local SliderInput = require(Components:FindFirstChild("SliderInput"))
local CurveEditor = require(Components:FindFirstChild("CurveEditor"))
local ColorPicker = require(Components:FindFirstChild("ColorPicker"))
local ColorSequenceEditor = require(Components:FindFirstChild("ColorSequenceEditor"))

local function TrimVersionText(Text : string) : string
    Text = string.gsub(Text, "^%s+", "")
    Text = string.gsub(Text, "%s+$", "")
    return Text
end

local function ParseVersionParts(Text : string) : {number}?
    local Clean = string.match(Text, "^v?(%d+[%.%d]*)$")
    if not Clean then
        return nil
    end

    local Parts = {}
    for Number in string.gmatch(Clean, "%d+") do
        table.insert(Parts, tonumber(Number) or 0)
    end

    if #Parts == 0 then
        return nil
    end

    return Parts
end

local function IsRemoteVersionNewer(RemoteText : string, LocalText : string) : boolean
    local RemoteParts = ParseVersionParts(RemoteText)
    local LocalParts = ParseVersionParts(LocalText)
    if not RemoteParts or not LocalParts then
        return false
    end

    local Count = math.max(#RemoteParts, #LocalParts)
    for Index = 1, Count do
        local RemotePart = RemoteParts[Index] or 0
        local LocalPart = LocalParts[Index] or 0
        if RemotePart > LocalPart then
            return true
        elseif RemotePart < LocalPart then
            return false
        end
    end

    return false
end

local function ReadLocalVersion() : string?
    local VersionObject = Bin:FindFirstChild("VERSION.txt") or Bin:FindFirstChild("VERSION")
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

local function IsHttpPermissionError(Error) : boolean
    local Text = string.lower(tostring(Error))
    return string.find(Text, "http requests are not enabled", 1, true) ~= nil
        or string.find(Text, "permission", 1, true) ~= nil
        or string.find(Text, "not allowed", 1, true) ~= nil
        or string.find(Text, "trust check", 1, true) ~= nil
        or string.find(Text, "aborted", 1, true) ~= nil
end

local function FetchGitHubVersion() : (string?, boolean)
    local Urls = {
        "https://raw.githubusercontent.com/MiaGobble/Effect-Design-Suite/main/src/VERSION.txt",
        "https://raw.githubusercontent.com/MiaGobble/Effect-Design-Suite/refs/heads/main/src/VERSION.txt",
        "https://raw.githubusercontent.com/MiaGobble/Effect-Design-Suite/main/VERSION.txt",
    }

    for _, Url in Urls do
        local Success, Result = pcall(function()
            return HttpService:GetAsync(Url)
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

local InterfaceScope = nil
local PendingPreviewLoads = {}

local function FormatTextureId(TextureId : number | string)
    return "rbxassetid://" .. tostring(TextureId)
end

local function GetFlipbookGridSize(FlipbookType : number?)
    if FlipbookType == 8 then
        return 8
    elseif FlipbookType == 4 then
        return 4
    elseif FlipbookType == 2 then
        return 2
    end

    return 1
end

local function GetParticleFlipbookLayout(FlipbookType : number?)
    if FlipbookType == 8 then
        return Enum.ParticleFlipbookLayout.Grid8x8
    elseif FlipbookType == 4 then
        return Enum.ParticleFlipbookLayout.Grid4x4
    elseif FlipbookType == 2 then
        return Enum.ParticleFlipbookLayout.Grid2x2
    end

    return Enum.ParticleFlipbookLayout.None
end

local function GetFlipbookTypeLabel(FlipbookType : number?)
    local GridSize = GetFlipbookGridSize(FlipbookType)

    if GridSize <= 1 then
        return "Static"
    end

    return string.format("%dx%d flipbook", GridSize, GridSize)
end

local function ApplyAssetToTextureObject(Asset, Object : Instance)
    local Texture = FormatTextureId(Asset.TextureId)

    if Object:IsA("ParticleEmitter") then
        Object.Texture = Texture
        Object.FlipbookLayout = GetParticleFlipbookLayout(Asset.FlipbookType)
        Object.FlipbookMode = Enum.ParticleFlipbookMode.Loop

        if GetFlipbookGridSize(Asset.FlipbookType) > 1 then
            Object.FlipbookFramerate = NumberRange.new(24)
        else
            Object.FlipbookFramerate = NumberRange.new(1)
        end
    elseif Object:IsA("Beam") or Object:IsA("Trail") then
        Object.Texture = Texture
    end
end

local function ResolveParticleInsertParent(SelectionTarget : Instance?)
    if not SelectionTarget then
        return nil
    end

    if SelectionTarget:IsA("ParticleEmitter") or SelectionTarget:IsA("Trail") or SelectionTarget:IsA("Beam") then
        return SelectionTarget.Parent
    end

    return SelectionTarget
end

local function CreatePreviewFrame(Scope, PreviewEntries, Asset, LayoutOrder : number, Animate : boolean?, Size : UDim2?)
    local PreviewWindow = Scope:New("Frame", {
        LayoutOrder = LayoutOrder,
        Size = Size or UDim2.fromOffset(88, 88),
        BackgroundColor3 = Color3.fromRGB(28, 28, 28),
        BorderSizePixel = 0,
        ClipsDescendants = true,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            Scope:New("UIStroke", {
                Color = Color3.fromRGB(52, 52, 52),
                Thickness = 1,
            }),
        },
    })

    local GridSize = GetFlipbookGridSize(Asset.FlipbookType)
    local ImageParent = PreviewWindow

    if GridSize > 1 then
        ImageParent = Scope:New("Frame", {
            Parent = PreviewWindow,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ClipsDescendants = true,

            [Seam.Children] = {
                Scope:New("UIAspectRatioConstraint", {
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

    local ContentId = FormatTextureId(Asset.TextureId)
    local PreviewImage = Scope:New("ImageLabel", {
        Parent = ImageParent,
        BackgroundTransparency = 1,
        Image = ContentId,
        ImageTransparency = 1,
        ScaleType = ImageScaleType,
        Size = UDim2.fromScale(GridSize, GridSize),
    })

    local LoadingIndicator = Scope:New("TextLabel", {
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

    if Animate == true and GridSize > 1 then
        PreviewEntry = {
            Image = PreviewImage,
            GridSize = GridSize,
            TotalFrames = GridSize * GridSize,
            StartedAt = os.clock(),
            FramesPerSecond = GridSize == 8 and 20 or 12,
        }
        table.insert(PreviewEntries, PreviewEntry)
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

local function CreateAssetCard(Scope, PreviewEntries, Asset, LayoutOrder : number, IsSelected, SelectCallback)
    local Card = Scope:New("Frame", {
        LayoutOrder = LayoutOrder,
        Size = UDim2.fromOffset(188, 76),
        BackgroundColor3 = Scope:Computed(function(Use)
            if Use(IsSelected) then
                return Color3.fromRGB(53, 53, 53)
            end

            return Color3.fromRGB(40, 40, 40)
        end),
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
                PaddingTop = UDim.new(0, 8),
                PaddingBottom = UDim.new(0, 8),
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8),
            }),
        },
    })

    CreatePreviewFrame(Scope, PreviewEntries, Asset, 1, false, UDim2.fromOffset(56, 56)).Parent = Card

    Scope:New(Jian.Text, {
        Parent = Card,
        LayoutOrder = 2,
        Position = UDim2.fromOffset(68, 8),
        Size = UDim2.new(1, -76, 0, 18),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = string.format("%s %03d", Asset.Type, Asset.CategoryIndex),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 14,
    })

    Scope:New(Jian.Text, {
        Parent = Card,
        LayoutOrder = 3,
        Position = UDim2.fromOffset(68, 30),
        Size = UDim2.new(1, -76, 0, 16),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = GetFlipbookTypeLabel(Asset.FlipbookType),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 11,
        Active = false,
    })

    Scope:New("TextButton", {
        Parent = Card,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        [Seam.OnEvent("Activated")] = function()
            SelectCallback(Asset)
        end,
    })

    return Card
end

local function CreateRow(Scope, LayoutOrder : number, Children : {any}?)
    return Scope:New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        LayoutOrder = LayoutOrder,

        [Seam.Children] = Children,
    })
end

local function CreateLabel(Scope, Parent : Instance, Text : any)
    return Scope:New(Jian.Text, {
        Parent = Parent,
        Text = Text,
        Size = UDim2.new(0.33, -8, 1, 0),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function BindTextBox(Scope, TextBox : TextBox, State)
    Scope:AddObject(TextBox:GetPropertyChangedSignal("Text"):Connect(function()
        State.Value = TextBox.Text
    end))
end

local function CreateBoundTextBox(Scope, Parent : Instance, State, Active, PlaceholderText : string, Position : UDim2, Size : UDim2)
    local TextBox = Scope:New(Jian.TextBox, {
        Parent = Parent,
        Text = State,
        Active = Active,
        PlaceholderText = PlaceholderText,
        Position = Position,
        Size = Size,
    })

    BindTextBox(Scope, TextBox, State)

    return TextBox
end

local function CreateActionButton(Scope, LayoutOrder : number, Text : string, Active, Callback)
    return Scope:New(Jian.TextButton, {
        LayoutOrder = LayoutOrder,
        Text = Text,
        Active = Active,
        Size = UDim2.new(1, 0, 0, 35),
        [Seam.OnEvent("Activated")] = Callback,
    })
end

local function SyncSelectionAttribute(State, AttributeName : string)
    local CurrentInstance = States.PrimarySelected.Value

    if not CurrentInstance then
        State.Value = ""
        return
    end

    State.Value = tostring(CurrentInstance:GetAttribute(AttributeName) or "")
end

function Interface:Init() : DockWidgetPluginGui
    if InterfaceScope then
        InterfaceScope:Destroy()
        InterfaceScope = nil
    end

    local Scope = Seam.Scope(Seam)
    InterfaceScope = Scope

    local MainWidget = Scope:New(Jian.Widget, {
        WidgetId = "EffectDesignerSuite",
        Title = "Effect Designer Suite",
        InitialDockState = Enum.InitialDockState.Left,
        InitialEnabled = true,
        OverridePreviousState = false,
        DefaultWidth = 320,
        DefaultHeight = 480,
        MinimumWidth = 320,
        MinimumHeight = 320,
    }) :: DockWidgetPluginGui

    local HasEditableSelection = Scope:Computed(function(Use)
        return #Use(States.CurrentlySelected) > 0
    end)

    local HasSingleSelection = Scope:Computed(function(Use)
        return Use(States.IsEmittable) and #Use(States.CurrentlySelected) == 1
    end)

    local HasRawSelection = Scope:Computed(function(Use)
        return #Use(States.RawSelection) > 0
    end)

    local function HasColorSequence(Instance)
        local Success, Value = pcall(function()
            return Instance.Color
        end)
        return Success and typeof(Value) == "ColorSequence"
    end

    local HasColorSequenceSelection = Scope:Computed(function(Use)
        for _, Instance in Use(States.CurrentlySelected) do
            if HasColorSequence(Instance) then
                return true
            end
        end
        return false
    end)

    local HasParticleEmitterSelection = Scope:Computed(function(Use)
        for _, Instance in Use(States.CurrentlySelected) do
            if Instance:IsA("ParticleEmitter") then
                return true
            end
        end

        return false
    end)

    local HasReplaceTargets = Scope:Computed(function(Use)
        local RawSelection = Use(States.RawSelection)
        local CurrentSelection = Use(States.CurrentlySelected)

        for _, Instance in RawSelection do
            if Instance:IsA("ParticleEmitter") or Instance:IsA("Beam") or Instance:IsA("Trail") then
                return true
            end
        end

        for _, Instance in CurrentSelection do
            if Instance:IsA("ParticleEmitter") or Instance:IsA("Beam") or Instance:IsA("Trail") then
                return true
            end
        end

        return false
    end)

    local SelectionSummary = Scope:Computed(function(Use)
        local Selected = Use(States.CurrentlySelected)

        if #Selected == 0 then
            return "No valid emitters selected"
        end

        if #Selected == 1 then
            return "Editing 1 valid object"
        end

        return string.format("Editing %d valid objects", #Selected)
    end)

    local EmitCountText = Scope:Value("")
    local EmitDelayText = Scope:Value("")
    local EmitDurationText = Scope:Value("")
    local RepeatEmitDelayText = Scope:Value(tostring(States.RepeatEmitDelay.Value))
    local CopyPropertyText = Scope:Value("Size")
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
    local function CurveAttributeName(Property)
        return "EffectDesignerCurve_" .. Property
    end

        local function CurveRangeAttributeName(Property, Suffix)
            return CurveAttributeName(Property) .. "_" .. Suffix
        end

    local function ResetCurveState()
        CurvePoints.Value = {
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
        }
        CurveMinRangeText.Value = "0"
        CurveMaxRangeText.Value = "10"
    end

    local function ReadCurveState()
        local Property = CurvePropertyText.Value
        local Instance = States.CurrentlySelected.Value[1]
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

    local COLOR_SEQUENCE_ATTRIBUTE = "EffectDesignerOklabColorSequence"
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
        local SourceInstance = nil
        for _, Instance in States.CurrentlySelected.Value do
            if HasColorSequence(Instance) then
                SourceInstance = Instance
                break
            end
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
                for _, Point in Decoded do
                    if typeof(Point) ~= "table"
                        or typeof(Point.Time) ~= "number"
                        or typeof(Point.L) ~= "number"
                        or typeof(Point.A) ~= "number"
                        or typeof(Point.B) ~= "number" then
                        Valid = false
                        break
                    end
                end

                if Valid then
                    table.sort(Decoded, function(Left, Right)
                        return Left.Time < Right.Time
                    end)
                    if Decoded[1].Time == 0 and Decoded[#Decoded].Time == 1 then
                        Points = Decoded
                    end
                end
            end
        end

        if not Points then
            Points = EffectOps.ReadOklabPointsFromColorSequence(SourceInstance.Color)
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

    MainWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    Scope:New(Jian.Background, {
        Parent = MainWidget,
    })

    ColorPickerWidget = Scope:New(Jian.Widget, {
        WidgetId = "EffectDesignerSuiteColorPicker",
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
        Text = Scope:Computed(function(Use)
            local Index = Use(ActiveColorPointIndex)
            local Points = Use(ColorSequencePoints)
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
        Active = Scope:Computed(function(Use)
            return Use(ActiveColorPointIndex) ~= nil
        end),
    })

    local function SyncPickerFromPoint(Index)
        local Point = Index and ColorSequencePoints.Value[Index] or nil
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

    local Container = Scope:New(Jian.ScrollingList, {
        Parent = MainWidget,
        Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 8,

        [Seam.Children] = {
            Scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 16),
                PaddingBottom = UDim.new(0, 16),
                PaddingLeft = UDim.new(0, 16),
                PaddingRight = UDim.new(0, 16),
            }),
        },
    })

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
        Visible = Scope:Computed(function(Use)
            return Use(UpdateWarningText) ~= ""
        end),
    })

    task.spawn(function()
        local RemoteVersion, PermissionDenied = FetchGitHubVersion()
        if PermissionDenied then
            UpdateWarningText.Value = "This plugin does not have HTTP permissions and cannot check for updates."
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

    Scope:New(Jian.Text, {
        Parent = Container,
        Text = SelectionSummary,
        Size = UDim2.new(1, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 0,
        Active = HasEditableSelection,
    })

    local AssetWidget = Scope:New(Jian.Widget, {
        WidgetId = "EffectDesignerSuiteAssets",
        Title = "Asset Presets",
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
        Text = Scope:Computed(function(Use)
            if Use(SelectedAssetCategory) then
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
        Text = Scope:Computed(function(Use)
            local Asset = Use(SelectedAsset)

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
        for _, Instance in AssetGridInstances do
            Instance:Destroy()
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

        for AssetOrder, Asset in ipairs(AssetCatalog.AssetsByCategory[Category] or {}) do
            local Card = CreateAssetCard(
                Scope,
                PreviewEntries,
                Asset,
                AssetOrder,
                Scope:Computed(function(Use)
                    return Use(SelectedAsset) == Asset
                end),
                function(NewAsset)
                    SelectedAsset.Value = NewAsset
                    RefreshSelectedAssetPreview()
                end
            )

            Card.Parent = AssetGridFrame
            table.insert(AssetGridInstances, Card)
        end
    end

    function RefreshSelectedAssetPreview()
        for _, Child in PreviewFrameHost:GetChildren() do
            Child:Destroy()
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
        Text = Scope:Computed(function(Use)
            local Asset = Use(SelectedAsset)

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
        Text = Scope:Computed(function(Use)
            local Asset = Use(SelectedAsset)

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
        Active = Scope:Computed(function(Use)
            return Use(SelectedAsset) ~= nil and Use(HasRawSelection)
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
        Active = Scope:Computed(function(Use)
            return Use(SelectedAsset) ~= nil and Use(HasReplaceTargets)
        end),
        [Seam.OnEvent("Activated")] = function()
            local Asset = SelectedAsset.Value

            if not Asset then
                return
            end

            ReplaceAssetPreset(Asset)
        end,
    })

    function InsertAssetPreset(Asset)
        local Target = ResolveParticleInsertParent(States.RawSelection.Value[1])

        if not Target then
            return
        end

        local NewEmitter = Instance.new("ParticleEmitter")
        NewEmitter.Name = string.format("%sPreset", Asset.Type)
        NewEmitter.Size = NumberSequence.new(1)
        NewEmitter.Rate = 1
        NewEmitter.Lifetime = NumberRange.new(2, 2)
        NewEmitter.Enabled = true
        ApplyAssetToTextureObject(Asset, NewEmitter)

        local Success = pcall(function()
            NewEmitter.Parent = Target
        end)

        if not Success then
            NewEmitter:Destroy()
            return
        end

        Selection:Set({NewEmitter})
    end

    function ReplaceAssetPreset(Asset)
        local Targets = {}
        local Seen = {}

        for _, Instance in States.CurrentlySelected.Value do
            if (Instance:IsA("ParticleEmitter") or Instance:IsA("Beam") or Instance:IsA("Trail")) and not Seen[Instance] then
                Seen[Instance] = true
                table.insert(Targets, Instance)
            end
        end

        for _, Instance in States.RawSelection.Value do
            if (Instance:IsA("ParticleEmitter") or Instance:IsA("Beam") or Instance:IsA("Trail")) and not Seen[Instance] then
                Seen[Instance] = true
                table.insert(Targets, Instance)
            end
        end

        for _, Instance in Targets do
            ApplyAssetToTextureObject(Asset, Instance)
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

        for CategoryOrder, Category in ipairs(AssetCatalog.Categories) do
            local CategoryButton = Scope:New(Jian.TextButton, {
                Parent = AssetNavigation,
                LayoutOrder = CategoryOrder,
                Size = UDim2.new(1, 0, 0, 30),
                Text = string.format("%s (%d)", Category, #(AssetCatalog.AssetsByCategory[Category] or {})),
                Active = true,
                [Seam.OnEvent("Activated")] = function()
                    SelectedAssetCategory.Value = Category

                    if not SelectedAsset.Value or SelectedAsset.Value.Type ~= Category then
                        SelectedAsset.Value = (AssetCatalog.AssetsByCategory[Category] or {})[1]
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

    local function IsPreviewContentReady(Entry)
        if Entry.Preloaded or Entry.Image.IsLoaded then
            return true
        end

        local Success, Status = pcall(function()
            return ContentProvider:GetAssetFetchStatus(Entry.ContentId)
        end)

        return Success and (Status == Enum.AssetFetchStatus.Success or Status == Enum.AssetFetchStatus.Failure)
    end

    Scope:AddObject(RunService.RenderStepped:Connect(function()
        if not AssetWidget.Enabled then
            return
        end

        for Index = #PendingPreviewLoads, 1, -1 do
            local Entry = PendingPreviewLoads[Index]

            if Entry.Image.Parent == nil then
                table.remove(PendingPreviewLoads, Index)
            elseif IsPreviewContentReady(Entry) then
                Entry.Indicator.Visible = false
                Entry.Image.ImageTransparency = 0

                if Entry.PreviewEntry then
                    Entry.PreviewEntry.StartedAt = os.clock()
                end

                table.remove(PendingPreviewLoads, Index)
            end
        end

        local Now = os.clock()

        for _, Preview in PreviewEntries do
            if Preview.Image.ImageTransparency ~= 0 then
                continue
            end

            local FrameIndex = math.floor((Now - Preview.StartedAt) * Preview.FramesPerSecond) % Preview.TotalFrames
            local Column = FrameIndex % Preview.GridSize
            local Row = math.floor(FrameIndex / Preview.GridSize)

            Preview.Image.Position = UDim2.fromScale(-Column, -Row)
        end
    end))

    local function CreateCorePropertyRow(LayoutOrder : number, LabelText : string, AttributeName : string, TextState)
        local Row = CreateRow(Scope, LayoutOrder)
        local IsFocused = false
        local FocusStartText = TextState.Value
        local IsDirty = false

        CreateLabel(Scope, Row, LabelText)

        local TextBox = CreateBoundTextBox(
            Scope,
            Row,
            TextState,
            HasEditableSelection,
            "0",
            UDim2.fromScale(0.35, 0),
            UDim2.fromScale(0.65, 1)
        )

        Scope:AddObject(TextBox.Focused:Connect(function()
            IsFocused = true
            FocusStartText = TextBox.Text
            IsDirty = false
        end))

        Scope:AddObject(TextBox:GetPropertyChangedSignal("Text"):Connect(function()
            if not IsFocused then
                return
            end

            IsDirty = TextBox.Text ~= FocusStartText
        end))

        Scope:AddObject(TextBox.FocusLost:Connect(function()
            IsFocused = false

            if not IsDirty then
                return
            end

            local CurrentlySelected = States.CurrentlySelected.Value

            if #CurrentlySelected == 0 then
                IsDirty = false
                return
            end

            local Number = tonumber(TextState.Value)

            if not Number or Number == 0 then
                IsDirty = false
                return
            end

            for _, Instance in CurrentlySelected do
                Instance:SetAttribute(AttributeName, Number)
            end

            IsDirty = false
            FocusStartText = TextBox.Text
        end))

        return Row
    end

    local CoreEmitCountRow = CreateCorePropertyRow(2, "Emit Count", "EmitCount", EmitCountText)
    local CoreEmitDelayRow = CreateCorePropertyRow(3, "Emit Delay", "EmitDelay", EmitDelayText)
    local CoreEmitDurationRow = CreateCorePropertyRow(4, "Emit Duration", "EmitDuration", EmitDurationText)

    local EmitButton = CreateActionButton(Scope, 2, "Emit", States.IsEmittable, function()
        EmitUtils:EmitCurrent()
    end)

    local RepeatRow = CreateRow(Scope, 3)
    local RepeatDelayBox = CreateBoundTextBox(
        Scope,
        RepeatRow,
        RepeatEmitDelayText,
        States.RepeatEmit,
        "Repeat delay",
        UDim2.new(0, 0, 0, 0),
        UDim2.fromScale(0.48, 1)
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
        Position = UDim2.new(0.52, 0, 0, 8),
        Size = UDim2.new(0.48, 0, 0, 20),
        Title = "Repeat Emit",
        Active = true,
        Value = States.RepeatEmit,
    })

    local CopyOptions = Scope:Value({})
    local CurveOptions = Scope:Value({})

    local function RefreshDynamicOptions()
        CopyOptions.Value = PropertyMaps.GetPropertiesForSelection(States.CurrentlySelected.Value, PropertyMaps.COPY_PROPERTIES_BY_CLASS)
        CurveOptions.Value = PropertyMaps.GetPropertiesForSelection(States.CurrentlySelected.Value, PropertyMaps.CURVE_PROPERTIES_BY_CLASS)
    end

    Scope:AddObject(Seam.OnChanged(States.CurrentlySelected, function()
        RefreshDynamicOptions()

        local NewCopyOptions = CopyOptions.Value
        if #NewCopyOptions > 0 and not table.find(NewCopyOptions, CopyPropertyText.Value) then
            CopyPropertyText.Value = NewCopyOptions[1]
        elseif #NewCopyOptions == 0 then
            CopyPropertyText.Value = ""
        end

        local NewCurveOptions = CurveOptions.Value
        if #NewCurveOptions > 0 and not table.find(NewCurveOptions, CurvePropertyText.Value) then
            CurvePropertyText.Value = NewCurveOptions[1]
                elseif #NewCurveOptions == 0 then
            CurvePropertyText.Value = ""
        end

        ReadCurveState()
        ReadColorSequenceState()
    end))
    Scope:AddObject(Seam.OnChanged(CurvePropertyText, ReadCurveState))

    RefreshDynamicOptions()
    ReadColorSequenceState()

    local CopyPropertyDropdown = Scope:New(Dropdown, {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 94),
        PlaceholderText = "Select property",
        Value = CopyPropertyText,
        Options = CopyOptions,
        Active = States.IsEmittable,
    })

    local CopyPasteButtons = CreateRow(Scope, 4)
    Scope:New(Jian.TextButton, {
        Parent = CopyPasteButtons,
        Text = "Copy",
        Active = HasSingleSelection,
        Size = UDim2.fromScale(0.48, 1),
        [Seam.OnEvent("Activated")] = function()
            local SelectedInstances = States.CurrentlySelected.Value

            if #SelectedInstances == 0 then
                return
            end

            local FirstInstance = SelectedInstances[1]

            local SelectedProperty = CopyPropertyText.Value
            local Success, Value = pcall(function()
                return FirstInstance[SelectedProperty]
            end)

            if Success then
                CopiedValue.Value = Value
                CopyPropertyText.Value = SelectedProperty
            end
        end,
    })

    Scope:New(Jian.TextButton, {
        Parent = CopyPasteButtons,
        Text = "Paste",
        Active = States.IsEmittable,
        Position = UDim2.fromScale(0.52, 0),
        Size = UDim2.fromScale(0.48, 1),
        [Seam.OnEvent("Activated")] = function()
            local SelectedInstances = States.CurrentlySelected.Value
            local SelectedProperty = CopyPropertyText.Value
            local Value = CopiedValue.Value

            if Value == nil then
                return
            end

            for _, Instance in SelectedInstances do
                pcall(function()
                    Instance[SelectedProperty] = Value
                end)
            end
        end,
    })

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

    local function RunMathOperation(Operation : string)
        local Value = MathAmountValue.Value
        local Property = PropertyMaps.NormalizeParticleProperty(MathPropertyText.Value)

        EffectOps.ApplyMathOperation(Value, Property, Operation, States.CurrentlySelected.Value)
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

    local CurvePropertyDropdown = Scope:New(Dropdown, {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 94),
        PlaceholderText = "Curve property",
        Value = CurvePropertyText,
        Options = CurveOptions,
        Active = States.IsEmittable,
    })

    local CurveEditorWidget = Scope:New(CurveEditor, {
        LayoutOrder = 3,
        Size = UDim2.new(1, 0, 0, 180),
        Points = CurvePoints,
        Active = States.IsEmittable,
    })

        local CurveMinRangeRow = CreateRow(Scope, 4)
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

    local CurveMaxRangeRow = CreateRow(Scope, 5)
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

    local CurveApplyButton = CreateActionButton(Scope, 6, "Apply Curve", States.IsEmittable, function()
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
        for _, Instance in States.CurrentlySelected.Value do
            pcall(function()
                Instance[SelectedProperty] = NewSequence
                Instance:SetAttribute(CurveAttributeName(SelectedProperty), EncodedPoints)
                Instance:SetAttribute(CurveRangeAttributeName(SelectedProperty, "MinRange"), MinRange)
                Instance:SetAttribute(CurveRangeAttributeName(SelectedProperty, "MaxRange"), MaxRange)
            end)
        end
    end)

    local ColorSequenceEditorWidget = Scope:New(ColorSequenceEditor, {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 76),
        Points = ColorSequencePoints,
        ActivePointIndex = ActiveColorPointIndex,
        Active = HasColorSequenceSelection,
        OnEditPoint = function(Index)
            if not Index then
                ColorPickerWidget.Enabled = false
                return
            end
            SyncPickerFromPoint(Index)
            ColorPickerWidget.Enabled = true
        end,
    })

    local ColorSequenceApplyButton = CreateActionButton(Scope, 3, "Apply Color Sequence", HasColorSequenceSelection, function()
        local NewSequence = EffectOps.BuildColorSequenceFromOklabPoints(ColorSequencePoints.Value)
        local EncodedPoints = HttpService:JSONEncode(ColorSequencePoints.Value)

        for _, Instance in States.CurrentlySelected.Value do
            if HasColorSequence(Instance) then
                pcall(function()
                    Instance.Color = NewSequence
                    Instance:SetAttribute(COLOR_SEQUENCE_ATTRIBUTE, EncodedPoints)
                end)
            end
        end
    end)

    local CreateBezierAnimationButton = CreateActionButton(Scope, 2, "Create Bezier Animation", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        local Indicator = EmitUtils:CreateNewAnimationIndicator(SelectedInstances[1], "Bezier")
        Selection:Set({Indicator})
    end)

    local CreateTweenAnimationButton = CreateActionButton(Scope, 3, "Create Tween Animation", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        local Indicator = EmitUtils:CreateNewAnimationIndicator(SelectedInstances[1], "Tween")
        Selection:Set({Indicator})
    end)

    local InsertPlayEffectModuleButton = CreateActionButton(Scope, 2, "Insert PlayEffect Module", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        local PlayEffectModule = Bin.PlaybackModules.PlayEffect:Clone()
        PlayEffectModule.Parent = SelectedInstances[1]
        Selection:Set({PlayEffectModule})
    end)

    local InsertEffectModuleTemplateButton = CreateActionButton(Scope, 3, "Insert Effect Module Template", HasRawSelection, function()
        local SelectedInstances = States.RawSelection.Value

        if #SelectedInstances == 0 then
            return
        end

        local EffectModuleTemplate = Bin.PlaybackModules.EffectModuleTemplate:Clone()
        EffectModuleTemplate.Parent = SelectedInstances[1]
        Selection:Set({EffectModuleTemplate})
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

    local OpenAssetPresetsButton = CreateActionButton(Scope, 2, "Presets", true, function()
        EnsureAssetBrowserInitialized()

        if not SelectedAsset.Value then
            if DefaultSelectedAsset then
                SelectedAsset.Value = DefaultSelectedAsset
                RefreshSelectedAssetPreview()
            end
        end

        AssetWidget.Enabled = not AssetWidget.Enabled
    end)

    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 1,
        Text = "Core Properties",
        Active = true,

        [Seam.Children] = {
            CoreEmitCountRow,
            CoreEmitDelayRow,
            CoreEmitDurationRow,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 2,
        Text = "Emit Actions",
        Active = true,

        [Seam.Children] = {
            EmitButton,
            RepeatRow,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 3,
        Text = "Copy/Paste Properties",
        Active = true,

        [Seam.Children] = {
            CopyPropertyDropdown,
            CopyPasteButtons,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 4,
        Text = "Resize",
        Active = true,

        [Seam.Children] = {
            ResizeMultiplierSlider,
            ResizeApplyButton,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 5,
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
        Parent = Container,
        LayoutOrder = 6,
        Text = "Curve Editor",
        Active = true,

        [Seam.Children] = {
            CurvePropertyDropdown,
            CurveEditorWidget,
                        CurveMinRangeRow,
            CurveMaxRangeRow,
            CurveApplyButton,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 7,
        Text = "Color Sequence",
        Active = true,

        [Seam.Children] = {
            ColorSequenceEditorWidget,
            ColorSequenceApplyButton,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 8,
        Text = "Assets",
        Active = true,

        [Seam.Children] = {
            OpenAssetPresetsButton,
        },
    })
    Scope:New(Jian.ListSection, {
        Parent = Container,
        LayoutOrder = 9,
        Text = "Advanced",
        Active = true,

        [Seam.Children] = {
            CreateBezierAnimationButton,
            CreateTweenAnimationButton,
            InsertPlayEffectModuleButton,
            InsertEffectModuleTemplateButton,
            PreviewPathsCheckboxRow,
            InjectApiCheckboxRow,
            WorldSpaceAccelCheckboxRow,
        },
    })

    local function RefreshWorldSpaceAccelCheckbox()
        IsSyncingWorldSpaceAccel = true

        local HasEnabled = false
        local HasDisabled = false

        for _, Instance in States.CurrentlySelected.Value do
            if Instance:IsA("ParticleEmitter") then
                if WorldSpaceAcceleration.IsEnabled(Instance) then
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

        for _, Instance in States.CurrentlySelected.Value do
            if Instance:IsA("ParticleEmitter") then
                WorldSpaceAcceleration.SetEnabled(Instance, WorldSpaceAccelEnabled.Value)
            end
        end
    end))

    local InitialCopyOptions = CopyOptions.Value
    if #InitialCopyOptions > 0 then
        CopyPropertyText.Value = InitialCopyOptions[1]
    end

    local InitialCurveOptions = CurveOptions.Value
    if #InitialCurveOptions > 0 then
        CurvePropertyText.Value = InitialCurveOptions[1]
    end

    EmitUtils:SetPathPreviewEnabled(PreviewPathsEnabled.Value)
    if InjectVfxApiEnabled.Value then
        VfxApiInjection.Enable(Bin)
    else
        VfxApiInjection.Disable()
    end

    EmitUtils:SetWidget(MainWidget)

    return MainWidget
end

return Interface

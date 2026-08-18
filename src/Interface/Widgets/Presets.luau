local Presets = {}

-- Constants
local WIDGET_ID = "EffectDesignerSuiteAssets"
local WIDGET_TITLE = "Effect Designer Suite — Presets"
local FLIPBOOK_GRID_SIZES = {
    [8] = 8,
    [4] = 4,
    [2] = 2,
}
local FLIPBOOK_LAYOUTS = {
    [8] = Enum.ParticleFlipbookLayout.Grid8x8,
    [4] = Enum.ParticleFlipbookLayout.Grid4x4,
    [2] = Enum.ParticleFlipbookLayout.Grid2x2,
}
local REPLACE_CLASSES = {
    ParticleEmitter = true,
    Beam = true,
    Trail = true,
}

-- Services
local SelectionService = game:GetService("Selection")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Objects = Bin:FindFirstChild("Objects")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))
local States = require(Objects:FindFirstChild("States"))
local AssetUtils = require(Interface:FindFirstChild("AssetUtils"))
local Modules = Interface:FindFirstChild("Modules")
local UiKit = require(Modules:FindFirstChild("UiKit"))

local function GetFlipbookGridSize(flipbookType : number?)
    return FLIPBOOK_GRID_SIZES[flipbookType] or 1
end

local function GetParticleFlipbookLayout(flipbookType : number?)
    return FLIPBOOK_LAYOUTS[flipbookType] or Enum.ParticleFlipbookLayout.None
end

local function GetFlipbookTypeLabel(flipbookType : number?)
    local GridSize = GetFlipbookGridSize(flipbookType)

    if GridSize <= 1 then
        return "Static"
    end

    return string.format("%dx%d flipbook", GridSize, GridSize)
end

local ASSET_APPLIERS = {
    ParticleEmitter = function(object, texture, asset)
        object.Texture = texture
        object.FlipbookLayout = GetParticleFlipbookLayout(asset.FlipbookType)
        object.FlipbookMode = Enum.ParticleFlipbookMode.Loop

        if GetFlipbookGridSize(asset.FlipbookType) > 1 then
            object.FlipbookFramerate = NumberRange.new(24)
        else
            object.FlipbookFramerate = NumberRange.new(1)
        end
    end,
    Beam = function(object, texture)
        object.Texture = texture
    end,
    Trail = function(object, texture)
        object.Texture = texture
    end,
}

local function ApplyAssetToTextureObject(asset, object : Instance)
    local Texture = UiKit.FormatTextureId(asset.TextureId)
    local Applier = ASSET_APPLIERS[object.ClassName]
    if Applier then
        Applier(object, Texture, asset)
    end
end

local function ResolveParticleInsertParent(selectionTarget : Instance?)
    if not selectionTarget then
        return nil
    end

    if REPLACE_CLASSES[selectionTarget.ClassName] then
        return selectionTarget.Parent
    end

    return selectionTarget
end

function Presets.Create(scope, _session, selection)
    local PendingPreviewLoads = {}
    local PreviewEntries = {}
    local SelectedAsset = scope:Value(nil)
    local SelectedAssetCategory = scope:Value(nil)
    local DefaultSelectedAsset = nil
    local AssetCatalog = nil
    local IsAssetBrowserInitialized = false
    local AssetGridInstances = {}

    local Widget = scope:New(Jian.Widget, {
        WidgetId = WIDGET_ID,
        Title = WIDGET_TITLE,
        InitialDockState = Enum.InitialDockState.Float,
        InitialEnabled = false,
        OverridePreviousState = false,
        DefaultWidth = 760,
        DefaultHeight = 560,
        MinimumWidth = 480,
        MinimumHeight = 320,
    }) :: DockWidgetPluginGui
    Widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    scope:New(Jian.Background, {
        Parent = Widget,
    })

    local AssetRoot = scope:New("Frame", {
        Parent = Widget,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        [Seam.Children] = {
            scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 16),
                PaddingBottom = UDim.new(0, 16),
                PaddingLeft = UDim.new(0, 16),
                PaddingRight = UDim.new(0, 16),
            }),
        },
    })

    scope:New(Jian.Text, {
        Parent = AssetRoot,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = "Insert creates a ParticleEmitter. Replace applies to selected ParticleEmitters, Beams, and Trails.",
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    local AssetNavigation = scope:New("ScrollingFrame", {
        Parent = AssetRoot,
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(0, 152, 1, -36),
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromScale(0, 0),
        ScrollBarThickness = 6,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 8),
            }),
            scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
            scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 10),
                PaddingBottom = UDim.new(0, 10),
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
            }),
            scope:New("UIListLayout", {
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        },
    })

    local AssetGridFrame = scope:New("ScrollingFrame", {
        Parent = AssetRoot,
        Position = UDim2.fromOffset(168, 36),
        Size = UDim2.new(1, -504, 1, -36),
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromScale(0, 0),
        ScrollBarThickness = 6,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 8),
            }),
            scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
            scope:New("UIPadding", {
                PaddingTop = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 12),
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
            }),
            scope:New("UIGridLayout", {
                CellSize = UDim2.fromOffset(188, 76),
                CellPadding = UDim2.fromOffset(10, 10),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        },
    })

    local AssetGridEmptyText = scope:New(Jian.Text, {
        Parent = AssetGridFrame,
        Text = scope:Computed(function(use)
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

    local AssetPreviewPane = scope:New("Frame", {
        Parent = AssetRoot,
        Position = UDim2.new(1, -320, 0, 36),
        Size = UDim2.new(0, 320, 1, -36),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(36, 36, 36),
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
                PaddingTop = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 12),
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
            }),
        },
    })

    scope:New(Jian.Text, {
        Parent = AssetPreviewPane,
        LayoutOrder = 1,
        Text = scope:Computed(function(use)
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

    local PreviewFrameHost = scope:New("Frame", {
        Parent = AssetPreviewPane,
        LayoutOrder = 2,
        Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 0, 184),
        BackgroundTransparency = 1,
    })

    local function CreatePreviewFrame(previewEntries, asset, layoutOrder : number, animate : boolean?, size : UDim2?)
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

        local ContentId = UiKit.FormatTextureId(asset.TextureId)
        local PreviewImage = scope:New("ImageLabel", {
            Parent = ImageParent,
            BackgroundTransparency = 1,
            Image = ContentId,
            ImageTransparency = 1,
            ScaleType = if GridSize > 1 then Enum.ScaleType.Stretch else Enum.ScaleType.Fit,
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

    local function CreateAssetCard(previewEntries, asset, layoutOrder : number, isSelected, selectCallback)
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

        CreatePreviewFrame(previewEntries, asset, 1, false, UDim2.fromOffset(56, 56)).Parent = Card

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
                PreviewEntries,
                asset,
                assetOrder,
                scope:Computed(function(use)
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

        CreatePreviewFrame(PreviewEntries, Asset, 1, true, UDim2.new(1, 0, 0, 184)).Parent = PreviewFrameHost
    end

    scope:New(Jian.Text, {
        Parent = AssetPreviewPane,
        LayoutOrder = 3,
        Position = UDim2.fromOffset(0, 226),
        Size = UDim2.new(1, 0, 0, 18),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = scope:Computed(function(use)
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

    scope:New(Jian.Text, {
        Parent = AssetPreviewPane,
        LayoutOrder = 4,
        Position = UDim2.fromOffset(0, 248),
        Size = UDim2.new(1, 0, 0, 18),
        AutomaticSize = Enum.AutomaticSize.None,
        Text = scope:Computed(function(use)
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

    local PRESET_ACTIONS = {
        {
            Position = UDim2.fromOffset(0, 280),
            Text = "Insert",
            IsActive = function(use)
                return use(SelectedAsset) ~= nil and use(selection.HasRawSelection)
            end,
            Run = function(asset)
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
            end,
        },
        {
            Position = UDim2.fromOffset(0, 320),
            Text = "Replace",
            IsActive = function(use)
                return use(SelectedAsset) ~= nil and use(selection.HasReplaceTargets)
            end,
            Run = function(asset)
                local Targets = {}
                local Seen = {}

                local function Collect(instances)
                    for _, instance in instances do
                        if REPLACE_CLASSES[instance.ClassName] and not Seen[instance] then
                            Seen[instance] = true
                            table.insert(Targets, instance)
                        end
                    end
                end

                Collect(States.CurrentlySelected.Value)
                Collect(States.RawSelection.Value)

                for _, instance in Targets do
                    ApplyAssetToTextureObject(asset, instance)
                end
            end,
        },
    }

    for _, action in PRESET_ACTIONS do
        scope:New(Jian.TextButton, {
            Parent = AssetPreviewPane,
            Position = action.Position,
            Size = UDim2.new(1, 0, 0, 32),
            Text = action.Text,
            Active = scope:Computed(action.IsActive),
            [Seam.OnEvent("Activated")] = function()
                local Asset = SelectedAsset.Value
                if not Asset then
                    return
                end

                action.Run(Asset)
            end,
        })
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
            scope:New(Jian.TextButton, {
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

    scope:AddObject(RunService.RenderStepped:Connect(function()
        if not Widget.Enabled then
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

    scope:OnChanged(Widget, function(property)
        if property ~= "Enabled" or not Widget.Enabled then
            return
        end

        EnsureAssetBrowserInitialized()

        if not SelectedAsset.Value and DefaultSelectedAsset then
            SelectedAsset.Value = DefaultSelectedAsset
            RefreshSelectedAssetPreview()
        end
    end)

    return Widget
end

return Presets

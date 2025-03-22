local Interface = {}

-- Imports
local Bin = script.Parent
local Components = Bin:FindFirstChild("Components")
local Objects = Bin:FindFirstChild("Objects")
local Packages = Bin:FindFirstChild("Packages")
local IconicDesign = Components:FindFirstChild("IconicDesign")
local PluginComponents = IconicDesign:FindFirstChild("PluginComponents")
local StudioComponents = IconicDesign:FindFirstChild("StudioComponents")
local Widget = require(PluginComponents:FindFirstChild("Widget"))
local Background = require(StudioComponents:FindFirstChild("Background"))
local ScrollFrame = require(StudioComponents:FindFirstChild("ScrollFrame"))
local TextInput = require(StudioComponents:FindFirstChild("TextInput"))
local VerticalCollapsibleSection = require(StudioComponents:FindFirstChild("VerticalCollapsibleSection"))
local Checkbox = require(StudioComponents:FindFirstChild("Checkbox"))
local Label = require(StudioComponents:FindFirstChild("Label"))
local States = require(Objects:FindFirstChild("States"))
local Fusion = require(Packages:FindFirstChild("Fusion"))
local Scope = Fusion.scoped(Fusion)
local Peek = Fusion.peek
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

-- Variables
local MainWidget = Widget {
    Id = "EffectDesignerSuite",
    Name = "Effect Designer Suite",
    InitialDockTo = Enum.InitialDockState.Left,
    InitialEnabled = false,
    ForceInitialEnabled = false,
    FloatingSize = Vector2.new(300, 300),
    MinimumSize = Vector2.new(300, 300),
}

function Interface:Init() : DockWidgetPluginGui
    local MainBackground = Background {
        Name = "Background",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 1,
        Parent = MainWidget,
    }

    local Container = ScrollFrame({
        ScrollBarThickness = 12,
        CanvasScaleConstraint = Enum.ScrollingDirection.X,

        UIPadding = Scope:New "UIPadding" {
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 30),
            PaddingRight = UDim.new(0, 30),
        },

        UILayout = Scope:New "UIListLayout" {
            SortOrder = Enum.SortOrder.LayoutOrder,
            FillDirection = Enum.FillDirection.Vertical,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Padding = UDim.new(0, 10),
        },

        ZIndex = 2,
        Parent = MainWidget,
    }):FindFirstChild("Canvas")

    MainWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    return MainWidget
end

return Interface
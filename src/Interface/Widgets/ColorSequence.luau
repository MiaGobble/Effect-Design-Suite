local ColorSequenceWidget = {}

-- Constants
local WIDGET_ID = "EffectDesignerSuiteColorSequence"
local WIDGET_TITLE = "Effect Designer Suite — Color Sequence"
local WIDGET_WIDTH = 360
local WIDGET_HEIGHT = 280

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Jian = require(Packages:FindFirstChild("Jian"))
local Components = Interface:FindFirstChild("Components")
local Modules = Interface:FindFirstChild("Modules")
local ColorSequenceEditor = require(Components:FindFirstChild("ColorSequenceEditor"))
local UiKit = require(Modules:FindFirstChild("UiKit"))

function ColorSequenceWidget.Create(scope, session, selection)
    local Widget, Container = UiKit.CreateListWidget(
        scope,
        WIDGET_ID,
        WIDGET_TITLE,
        false,
        WIDGET_WIDTH,
        WIDGET_HEIGHT,
        Enum.InitialDockState.Float
    )

    session.ColorSequenceWidget = Widget

    scope:New(Jian.Text, {
        Parent = Container,
        LayoutOrder = 1,
        Text = "Editing Color",
        Size = UDim2.new(1, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    scope:New(ColorSequenceEditor, {
        Parent = Container,
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 76),
        Points = session.ColorSequencePoints,
        ActivePointIndex = session.ActiveColorPointIndex,
        Active = selection.HasColorSequenceSelection,
        OnEditPoint = function(index)
            if not index then
                if session.ColorPickerWidget then
                    session.ColorPickerWidget.Enabled = false
                end
                return
            end
            session.SyncPickerFromPoint(index)
            if session.ColorPickerWidget then
                session.ColorPickerWidget.Enabled = true
            end
        end,
    })

    local ColorSequenceApplyButton = UiKit.CreateActionButton(scope, 3, "Apply Color Sequence", selection.HasColorSequenceSelection, function()
        session.ApplyColorSequence()
    end)
    ColorSequenceApplyButton.Parent = Container

    return Widget
end

return ColorSequenceWidget

local Core = {}

-- Constants
local WIDGET_ID = "EffectDesignerSuite"
local WIDGET_TITLE = "Effect Designer Suite — Core"
local WIDGET_WIDTH = 320
local WIDGET_HEIGHT = 480
local EMIT_FIELD_LABEL_HEIGHT = 16
local EMIT_FIELD_BOX_HEIGHT = 36
local EMIT_ATTRIBUTE_ROW_HEIGHT = 54
local OTHER_TOOLS_HINT = "Looking for other tools? They're now separate widgets!"
local EMIT_ATTRIBUTES = {
    {
        Attribute = "EmitCount",
        Label = "Count",
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.new(0.32, 0, 1, 0),
    },
    {
        Attribute = "EmitDelay",
        Label = "Delay",
        Position = UDim2.fromScale(0.34, 0),
        Size = UDim2.new(0.32, 0, 1, 0),
    },
    {
        Attribute = "EmitDuration",
        Label = "Duration",
        Position = UDim2.fromScale(0.68, 0),
        Size = UDim2.new(0.32, 0, 1, 0),
    },
}

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Objects = Bin:FindFirstChild("Objects")
local Seam = require(Packages:FindFirstChild("Seam"))
local Jian = require(Packages:FindFirstChild("Jian"))
local States = require(Objects:FindFirstChild("States"))
local EmitUtils = require(Interface:FindFirstChild("EmitUtils"))
local Modules = Interface:FindFirstChild("Modules")
local UiKit = require(Modules:FindFirstChild("UiKit"))
local VersionCheck = require(Modules:FindFirstChild("VersionCheck"))
local PropertyInspector = require(Modules:FindFirstChild("PropertyInspector"))
local ChangeHistory = require(Modules:FindFirstChild("ChangeHistory"))

local function SyncSelectionAttribute(state, attributeName : string)
    local CurrentInstance = States.PrimarySelected.Value

    if not CurrentInstance then
        state.Value = ""
        return
    end

    state.Value = tostring(CurrentInstance:GetAttribute(attributeName) or "")
end

local function CreateEmitAttributeField(scope, parent, position : UDim2, size : UDim2, labelText : string, attributeName : string, textState, hasEditableSelection)
    local Column = scope:New("Frame", {
        Parent = parent,
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
    })

    scope:New(Jian.Text, {
        Parent = Column,
        Text = labelText,
        Size = UDim2.new(1, 0, 0, EMIT_FIELD_LABEL_HEIGHT),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    local FocusStartText = textState.Value
    UiKit.CreateBoundTextBox(
        scope,
        Column,
        textState,
        hasEditableSelection,
        "0",
        UDim2.fromOffset(0, EMIT_FIELD_LABEL_HEIGHT),
        UDim2.new(1, 0, 0, EMIT_FIELD_BOX_HEIGHT),
        {
            Focused = function()
                FocusStartText = textState.Value
            end,
            FocusLost = function()
                if textState.Value == FocusStartText then
                    return
                end

                local CurrentlySelected = States.CurrentlySelected.Value
                if #CurrentlySelected == 0 then
                    return
                end

                local Number = tonumber(textState.Value)
                if not Number or Number == 0 then
                    return
                end

                ChangeHistory.Record("Set " .. attributeName, function()
                    for _, instance in CurrentlySelected do
                        instance:SetAttribute(attributeName, Number)
                    end
                end)

                FocusStartText = textState.Value
            end,
        }
    )

    return Column
end

function Core.Create(scope, session, selection)
    local Widget, Container = UiKit.CreateListWidget(
        scope,
        WIDGET_ID,
        WIDGET_TITLE,
        true,
        WIDGET_WIDTH,
        WIDGET_HEIGHT,
        Enum.InitialDockState.Left
    )

    local EmitCountText = scope:Value("")
    local EmitDelayText = scope:Value("")
    local EmitDurationText = scope:Value("")
    local RepeatEmitDelayText = scope:Value(tostring(States.RepeatEmitDelay.Value))
    local EmitTexts = {
        EmitCount = EmitCountText,
        EmitDelay = EmitDelayText,
        EmitDuration = EmitDurationText,
    }

    local UpdateWarningText = scope:Value("")
    scope:New("TextLabel", {
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
        Visible = scope:Computed(function(use)
            return use(UpdateWarningText) ~= ""
        end),
    })
    VersionCheck.Start(UpdateWarningText)

    scope:New("TextLabel", {
        Parent = Container,
        LayoutOrder = 0,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = selection.SelectionSummary,
        TextWrapped = true,
        TextColor3 = Color3.fromRGB(220, 220, 220),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Font = Enum.Font.Gotham,
        TextSize = 13,
    })

    local ConfigurablePanel = scope:New("Frame", {
        Parent = Container,
        LayoutOrder = 1,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = selection.HasConfigurableSelection,

        [Seam.Children] = {
            scope:New("UIListLayout", {
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        },
    })

    local EmitAttributesRow = scope:New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, EMIT_ATTRIBUTE_ROW_HEIGHT),
        LayoutOrder = 1,
    })

    for _, field in EMIT_ATTRIBUTES do
        CreateEmitAttributeField(
            scope,
            EmitAttributesRow,
            field.Position,
            field.Size,
            field.Label,
            field.Attribute,
            EmitTexts[field.Attribute],
            selection.HasEditableSelection
        )
    end

    local RepeatRow = scope:New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, EMIT_ATTRIBUTE_ROW_HEIGHT),
        LayoutOrder = 2,
    })

    local RepeatDelayColumn = scope:New("Frame", {
        Parent = RepeatRow,
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.new(0.48, 0, 1, 0),
        BackgroundTransparency = 1,
    })

    scope:New(Jian.Text, {
        Parent = RepeatDelayColumn,
        Text = "Repeat Delay",
        Size = UDim2.new(1, 0, 0, EMIT_FIELD_LABEL_HEIGHT),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    UiKit.CreateBoundTextBox(
        scope,
        RepeatDelayColumn,
        RepeatEmitDelayText,
        States.RepeatEmit,
        "0",
        UDim2.fromOffset(0, EMIT_FIELD_LABEL_HEIGHT),
        UDim2.new(1, 0, 0, EMIT_FIELD_BOX_HEIGHT),
        {
            FocusLost = function()
                local Delay = tonumber(RepeatEmitDelayText.Value)

                if not Delay then
                    RepeatEmitDelayText.Value = tostring(States.RepeatEmitDelay.Value)
                    return
                end

                States.RepeatEmitDelay.Value = Delay
            end,
        }
    )

    scope:New(Jian.Checkbox, {
        Parent = RepeatRow,
        Position = UDim2.new(0.52, 0, 0.5, -10),
        Size = UDim2.new(0.48, 0, 0, 20),
        Title = "Repeat Emit",
        Active = true,
        Value = States.RepeatEmit,
    })

    local EmitButton = UiKit.CreateActionButton(scope, 3, "Emit", States.IsEmittable, function()
        EmitUtils:EmitCurrent()
    end)

    scope:New(Jian.ListSection, {
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

    scope:New(Jian.Text, {
        Parent = ConfigurablePanel,
        LayoutOrder = 2,
        Text = "Properties",
        Size = UDim2.new(1, 0, 0, 18),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    PropertyInspector.Mount(scope, ConfigurablePanel, session)

    scope:New(Jian.Text, {
        Parent = ConfigurablePanel,
        LayoutOrder = 4,
        Text = OTHER_TOOLS_HINT,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
    })

    local function RefreshCoreFields()
        for _, field in EMIT_ATTRIBUTES do
            SyncSelectionAttribute(EmitTexts[field.Attribute], field.Attribute)
        end
    end

    RefreshCoreFields()
    scope:OnChanged(States.PrimarySelected, RefreshCoreFields)
    scope:OnChanged(States.RepeatEmitDelay, function()
        RepeatEmitDelayText.Value = tostring(States.RepeatEmitDelay.Value)
    end)
    scope:OnChanged(States.RepeatEmit, function()
        if States.RepeatEmit.Value then
            EmitUtils:EnableRepeatEmit()
        else
            EmitUtils:DisableRepeatEmit()
        end
    end)

    EmitUtils:SetWidget(Widget)

    return Widget
end

return Core

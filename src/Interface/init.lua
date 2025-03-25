local Interface = {}

-- Constants
local PARTICLE_PROPERTIES = {
    "Size",
    "Color",
    "Transparency",
    "Speed",
    "Acceleration",
    "Lifetime",
    "Rate",
    "SpreadAngle",
    "LightEmission",
    "LightInfluence",
    "Texture",
}

-- Imports
local Bin = script.Parent
local Components = Bin:FindFirstChild("Components")
local Objects = Bin:FindFirstChild("Objects")
local Packages = Bin:FindFirstChild("Packages")
local IconicDesign = Components:FindFirstChild("IconicDesign")
local PluginComponents = IconicDesign:FindFirstChild("PluginComponents")
local StudioComponents = IconicDesign:FindFirstChild("StudioComponents")
local EmitUtils = require(script.EmitUtils)
local Widget = require(PluginComponents:FindFirstChild("Widget"))
local Background = require(StudioComponents:FindFirstChild("Background"))
local ScrollFrame = require(StudioComponents:FindFirstChild("ScrollFrame"))
local TextInput = require(StudioComponents:FindFirstChild("TextInput"))
local VerticalCollapsibleSection = require(StudioComponents:FindFirstChild("VerticalCollapsibleSection"))
local Checkbox = require(StudioComponents:FindFirstChild("Checkbox"))
local BaseButton = require(StudioComponents:FindFirstChild("BaseButton"))
local Label = require(StudioComponents:FindFirstChild("Label"))
local Dropdown = require(StudioComponents:FindFirstChild("Dropdown"))
local States = require(Objects:FindFirstChild("States"))
local Fusion = require(Packages:FindFirstChild("Fusion"))
local Scope = Fusion.scoped(Fusion)
local Peek = Fusion.peek
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Out = Fusion.Out

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

    local CorePropertyValues = {
        EmitCount = Scope:Value(0),
        EmitDelay = Scope:Value(0),
        EmitDuration = Scope:Value(0),
    }

    local EmitValues = {
        RepeatEmitDelay = Scope:Value(Peek(States.RepeatEmitDelay)),
    }

    local UtilValues = {
        Scale = Scope:Value(1),
    }

    local PropertyValues = {
        SelectedProperty = Scope:Value("Size"),
        CopiedValue = Scope:Value(nil),
    }

    local CoreProperties = VerticalCollapsibleSection {
        Name = "CoreProperties",
        --Size = UDim2.new(1, 0, 0, 50),
        Collapsed = false,
        Padding = UDim.new(0, 10),
        Text = "Core Properties",
        Enabled = true,
        Parent = Container,

        [Children] = {
            Scope:New "Frame" {
                Name = "EmitCount",
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,

                [Children] = {
                    Label {
                        Text = "Emit Count",
                        LayoutOrder = 0,
                        Size = UDim2.fromScale(0.3, 1),
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
    
                    TextInput {
                        Text = Scope:Computed(function(Use)
                            local CurrentInstance = Use(States.PrimarySelected)
        
                            if not CurrentInstance then
                                return ""
                            end
        
                            return tostring(CurrentInstance:GetAttribute("EmitCount") or 0)
                        end),
        
                        PlaceholderText = "Emit Count",

                        Enabled = Scope:Computed(function(Use)
                            return Use(States.IsEditable) and not Use(States.IsEffectModule)
                        end),

                        LayoutOrder = 1,
                        Size = UDim2.fromScale(0.7, 1),
                        Position = UDim2.fromScale(0.3, 0),

                        [Out "Text"] = CorePropertyValues.EmitCount,

                        [OnEvent "Changed"] = function()
                            local CurrentInstance = Peek(States.PrimarySelected)
                            local IsEffectModule = Peek(States.IsEffectModule)
        
                            if not CurrentInstance or IsEffectModule then
                                return
                            end

                            local Text = Peek(CorePropertyValues.EmitCount)
                            local Number = tonumber(Text)
        
                            if not Number then
                                return
                            end
        
                            CurrentInstance:SetAttribute("EmitCount", Number)
                        end,
                    },
                }
            },

            Scope:New "Frame" {
                Name = "EmitDelay",
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,

                [Children] = {
                    Label {
                        Text = "Emit Delay",
                        LayoutOrder = 0,
                        Size = UDim2.fromScale(0.3, 1),
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
    
                    TextInput {
                        Text = Scope:Computed(function(Use)
                            local CurrentInstance = Use(States.PrimarySelected)
        
                            if not CurrentInstance then
                                return ""
                            end
        
                            return tostring(CurrentInstance:GetAttribute("EmitDelay") or 0)
                        end),
        
                        PlaceholderText = "Emit Delay",
                        Enabled = States.IsEditable,
                        LayoutOrder = 1,
                        Size = UDim2.fromScale(0.7, 1),
                        Position = UDim2.fromScale(0.3, 0),

                        [Out "Text"] = CorePropertyValues.EmitDelay,

                        [OnEvent "Changed"] = function()
                            local CurrentInstance = Peek(States.PrimarySelected)
        
                            if not CurrentInstance then
                                return
                            end

                            local Text = Peek(CorePropertyValues.EmitDelay)
                            local Number = tonumber(Text)
        
                            if not Number then
                                return
                            end
        
                            CurrentInstance:SetAttribute("EmitDelay", Number)
                        end,
                    },
                }
            },

            Scope:New "Frame" {
                Name = "EmitDuration",
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,

                [Children] = {
                    Label {
                        Text = "Emit Duration",
                        LayoutOrder = 0,
                        Size = UDim2.fromScale(0.3, 1),
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
    
                    TextInput {
                        Text = Scope:Computed(function(Use)
                            local CurrentInstance = Use(States.PrimarySelected)
        
                            if not CurrentInstance then
                                return ""
                            end
        
                            return tostring(CurrentInstance:GetAttribute("EmitDuration") or 0)
                        end),
        
                        PlaceholderText = "Emit Duration",

                        Enabled = Scope:Computed(function(Use)
                            return Use(States.IsEditable) and not Use(States.IsEffectModule)
                        end),

                        LayoutOrder = 1,
                        Size = UDim2.fromScale(0.7, 1),
                        Position = UDim2.fromScale(0.3, 0),

                        [Out "Text"] = CorePropertyValues.EmitDuration,

                        [OnEvent "Changed"] = function()
                            local CurrentInstance = Peek(States.PrimarySelected)
                            local IsEffectModule = Peek(States.IsEffectModule)
        
                            if not CurrentInstance or IsEffectModule then
                                return
                            end

                            local Text = Peek(CorePropertyValues.EmitDuration)
                            local Number = tonumber(Text)
        
                            if not Number then
                                return
                            end
        
                            CurrentInstance:SetAttribute("EmitDuration", Number)
                        end,
                    },
                }
            },
        }
    }

    local EmitActions = VerticalCollapsibleSection {
        Name = "EmitActions",
        --Size = UDim2.new(1, 0, 0, 50),
        Collapsed = false,
        Padding = UDim.new(0, 10),
        Text = "Emit Actions",
        Enabled = true,
        Parent = Container,

        [Children] = {
            BaseButton {
                Size = UDim2.new(1, 0, 0, 30),
                Text = "Emit",
                Enabled = States.IsEmittable,

                Activated = function()
                    EmitUtils:EmitCurrent()
                end,
            },

            Scope:New "Frame" {
                Name = "EmitCount",
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,

                [Children] = {
                    TextInput {
                        Text = Scope:Computed(function(Use)
                            local RepeatEmit = Use(States.RepeatEmit)
        
                            if not RepeatEmit then
                                return Peek(States.RepeatEmitDelay)
                            end
        
                            return tostring(Use(EmitValues.RepeatEmitDelay))
                        end),
        
                        PlaceholderText = "Repeat Emit Delay",
                        Enabled = States.RepeatEmit,
                        LayoutOrder = 1,
                        Size = UDim2.fromScale(0.5, 1),
                        Position = UDim2.fromScale(0, 0),

                        [Out "Text"] = EmitValues.RepeatEmitDelay,

                        [OnEvent "Changed"] = function()
                            local Text = Peek(EmitValues.RepeatEmitDelay)
                            local Number = tonumber(Text)
        
                            if not Number then
                                return
                            end
        
                            States.RepeatEmitDelay:set(Number)
                        end,
                    },
                    
                    Checkbox {
                        Text = "Repeat Emit",
                        Enabled = true,
                        Value = Peek(States.RepeatEmit),
                        LayoutOrder = 1,
                        Size = UDim2.new(0.5, 0, 1, 0),
                        Position = UDim2.new(1, 0, 0, 0),
                        AnchorPoint = Vector2.new(1, 0),
                        ZIndex = 3,
                        Alignment = Enum.HorizontalAlignment.Right,
        
                        OnChange = function()
                            States.RepeatEmit:set(not Peek(States.RepeatEmit))
                            
                            if Peek(States.RepeatEmit) then
                                EmitUtils:EnableRepeatEmit()
                            else
                                EmitUtils:DisableRepeatEmit()
                            end
                        end,
                    }
                }
            },
        }
    }

    local PropertyCopyPaste = VerticalCollapsibleSection {
        Name = "PropertyCopyPaste",
        Collapsed = true,
        Padding = UDim.new(0, 10),
        Text = "Copy/Paste Properties",
        Enabled = true,
        Parent = Container,
        ZIndex = 5,

        [Children] = {
            TextInput {
                Size = UDim2.new(1, 0, 0, 30),
                PlaceholderText = "Property Name",
                Enabled = States.IsEmittable,
                Text = PropertyValues.SelectedProperty,
                ZIndex = 10,

                [OnEvent "Changed"] = function()
                    local Text = Peek(PropertyValues.SelectedProperty)
                    local LowerText = Text:lower()
                    
                    -- Find the first property that starts with the input text
                    for _, Property in PARTICLE_PROPERTIES do
                        if Property:lower():sub(1, #LowerText) == LowerText then
                            PropertyValues.SelectedProperty:set(Property)
                            break
                        end
                    end
                end,
            },

            Scope:New "Frame" {
                Name = "ButtonContainer",
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,

                [Children] = {
                    BaseButton {
                        Size = UDim2.fromScale(0.48, 1),
                        Text = "Copy",
                        Enabled = Scope:Computed(function(Use)
                            local SelectedInstances = Use(States.CurrentlySelected)
                            return Use(States.IsEmittable) and #SelectedInstances == 1
                        end),
                        Position = UDim2.fromScale(0, 0),

                        Activated = function()
                            local SelectedProperty = Peek(PropertyValues.SelectedProperty)
                            local SelectedInstances = Peek(States.CurrentlySelected)
                            
                            if #SelectedInstances == 0 then return end
                            
                            -- Get the property value from the first selected instance
                            local FirstInstance = SelectedInstances[1]
                            if not FirstInstance:IsA("ParticleEmitter") then return end
                            
                            local Value = FirstInstance[SelectedProperty]
                            if Value then
                                PropertyValues.CopiedValue:set(Value)
                            end
                        end,
                    },

                    BaseButton {
                        Size = UDim2.fromScale(0.48, 1),
                        Text = "Paste",
                        Enabled = States.IsEmittable,
                        Position = UDim2.fromScale(0.52, 0),

                        Activated = function()
                            local SelectedProperty = Peek(PropertyValues.SelectedProperty)
                            local SelectedInstances = Peek(States.CurrentlySelected)
                            local CopiedValue = Peek(PropertyValues.CopiedValue)
                            
                            if not CopiedValue then return end
                            
                            -- Apply the copied value to all selected instances
                            for _, Instance in SelectedInstances do
                                if Instance:IsA("ParticleEmitter") then
                                    Instance[SelectedProperty] = CopiedValue
                                end
                            end
                        end,
                    },
                }
            },
        }
    }

    local Scale = VerticalCollapsibleSection {
        Name = "Scale",
        Collapsed = true,
        Padding = UDim.new(0, 10),
        Text = "Scale",
        Enabled = true,
        Parent = Container,

        [Children] = {
            TextInput {
                PlaceholderText = "Scale",
                Enabled = States.IsEmittable,
                LayoutOrder = 1,
                Size = UDim2.new(1, 0, 0, 30),
                Position = UDim2.fromScale(0, 0),

                [Out "Text"] = UtilValues.Scale,
            },

            BaseButton {
                Size = UDim2.new(1, 0, 0, 30),
                Text = "Apply Scale",
                Enabled = States.IsEmittable,

                Activated = function()
                    local Scale = Peek(UtilValues.Scale)

                    if not tonumber(Scale) then
                        return
                    end

                    local SelectedInstances = Peek(States.CurrentlySelected)

                    for _, Instance in SelectedInstances do
                        if Instance:IsA("ParticleEmitter") then
                            local OldSize = Instance.Size
                            local NewSizeKeypoints = {}

                            for _, Keypoint in OldSize.Keypoints do
                                local NewKeypoint = NumberSequenceKeypoint.new(Keypoint.Time, Keypoint.Value * tonumber(Scale), Keypoint.Envelope * tonumber(Scale))

                                table.insert(NewSizeKeypoints, NewKeypoint)
                            end

                            Instance.Size = NumberSequence.new(NewSizeKeypoints)
                        end
                    end
                end,
            },
        }
    }

    EmitUtils:SetWidget(MainWidget)

    MainWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    return MainWidget
end

return Interface
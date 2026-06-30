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

-- Services
local Selection = game:GetService("Selection")

-- Imports
local Bin = script.Parent
local Components = Bin:FindFirstChild("Components")
local Objects = Bin:FindFirstChild("Objects")
local Packages = Bin:FindFirstChild("Packages")
local IconicDesign = Components:FindFirstChild("IconicDesign")
local PluginComponents = IconicDesign:FindFirstChild("PluginComponents")
local StudioComponents = IconicDesign:FindFirstChild("StudioComponents")
local EmitUtils = require(script.EmitUtils)
local AssetUtils = require(script.AssetUtils)
local Widget = require(PluginComponents:FindFirstChild("Widget"))
local Background = require(StudioComponents:FindFirstChild("Background"))
local ScrollFrame = require(StudioComponents:FindFirstChild("ScrollFrame"))
local TextInput = require(StudioComponents:FindFirstChild("TextInput"))
local VerticalCollapsibleSection = require(StudioComponents:FindFirstChild("VerticalCollapsibleSection"))
local Checkbox = require(StudioComponents:FindFirstChild("Checkbox"))
local Dropdown = require(StudioComponents:FindFirstChild("Dropdown"))
local BaseButton = require(StudioComponents:FindFirstChild("BaseButton"))
local Slider = require(StudioComponents:FindFirstChild("Slider"))
local Label = require(StudioComponents:FindFirstChild("Label"))
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

local LibraryWidget = Widget {
    Id = "EffectDesignerSuiteLibrary",
    Name = "Asset Library",
    InitialDockTo = Enum.InitialDockState.Float,
    InitialEnabled = false,
    ForceInitialEnabled = false,
    FloatingSize = Vector2.new(800, 300),
    MinimumSize = Vector2.new(800, 300),
}

-- Helper Functions
local function ApplyMathOperation(Value: number, Property: string, Operation: string, Instances: {Instance})
    if not Value or Property == "" then
        return
    end

    for _, Instance in Instances do
        if not (Instance:IsA("ParticleEmitter") and Instance[Property]) then
            continue
        end

        local PropertyType = typeof(Instance[Property])
        
        if PropertyType == "NumberSequence" then
            local OldSequence = Instance[Property]
            local NewKeypoints = {}

            for _, Keypoint in OldSequence.Keypoints do
                local NewValue, NewEnvelope
                
                if Operation == "add" then
                    NewValue = Keypoint.Value + Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope + Value)
                elseif Operation == "subtract" then
                    NewValue = Keypoint.Value - Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope - Value)
                elseif Operation == "multiply" then
                    NewValue = Keypoint.Value * Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope * Value)
                elseif Operation == "divide" then
                    if Value == 0 then continue end
                    NewValue = Keypoint.Value / Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope / Value)
                end

                table.insert(NewKeypoints, NumberSequenceKeypoint.new(
                    Keypoint.Time,
                    NewValue,
                    NewEnvelope
                ))
            end

            Instance[Property] = NumberSequence.new(NewKeypoints)
        elseif PropertyType == "NumberRange" then
            local OldMin = Instance[Property].Min
            local OldMax = Instance[Property].Max
            local NewMin, NewMax
            
            if Operation == "add" then
                NewMin = OldMin + Value
                NewMax = OldMax + Value
            elseif Operation == "subtract" then
                NewMin = OldMin - Value
                NewMax = OldMax - Value
            elseif Operation == "multiply" then
                NewMin = OldMin * Value
                NewMax = OldMax * Value
            elseif Operation == "divide" then
                if Value == 0 then continue end
                NewMin = OldMin / Value
                NewMax = OldMax / Value
            end

            Instance[Property] = NumberRange.new(NewMin, NewMax)
        elseif PropertyType == "number" then
            if Operation == "add" then
                Instance[Property] = Instance[Property] + Value
            elseif Operation == "subtract" then
                Instance[Property] = Instance[Property] - Value
            elseif Operation == "multiply" then
                Instance[Property] = Instance[Property] * Value
            elseif Operation == "divide" then
                if Value == 0 then continue end
                Instance[Property] = Instance[Property] / Value
            end
        end
    end
end

local function InitLibrary()
    local MainBackground = Background {
        Name = "Background",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 1,
        Parent = LibraryWidget  ,
    }

    local Sidebar = ScrollFrame({
        ScrollBarThickness = 12,
        CanvasScaleConstraint = Enum.ScrollingDirection.X,
        Size = UDim2.new(0.3, 0, 1, 0),
        
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
        Parent = LibraryWidget,
    }):FindFirstChild("Canvas")

    Sidebar.BackgroundTransparency = 0.75
    Sidebar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

    local SelectedCategory = Scope:Value("")
    local Assets = Scope:Value({})

    local Content = ScrollFrame({
        ScrollBarThickness = 12,
        CanvasScaleConstraint = Enum.ScrollingDirection.X,
        Position = UDim2.fromScale(0.3, 0),
        Size = UDim2.new(0.7, 0, 1, 0),
        
        UIPadding = Scope:New "UIPadding" {
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 30),
            PaddingRight = UDim.new(0, 30),
        },

        -- UILayout = Scope:New "UIListLayout" {
        --     SortOrder = Enum.SortOrder.LayoutOrder,
        --     FillDirection = Enum.FillDirection.Vertical,
        --     VerticalAlignment = Enum.VerticalAlignment.Top,
        --     HorizontalAlignment = Enum.HorizontalAlignment.Center,
        --     Padding = UDim.new(0, 10),
        -- },

        UILayout = Scope:New "UIGridLayout" {
            CellSize = UDim2.new(0, 60, 0, 60),
            CellPadding = UDim2.new(0, 30, 0, 30),
        },

        ZIndex = 2,
        Parent = LibraryWidget,

        [Children] = {
            Scope:ForValues(Assets, function(Use, Asset)
                local Frame = Scope:New "Frame" {
                    Name = Asset.Name,
                }
                
                return Frame
            end)
        }
    }):FindFirstChild("Canvas")

    local CategoryDropdown = Dropdown {
        Name = "CategoryDropdown",
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.fromScale(0, 0),
        AnchorPoint = Vector2.new(0, 0),
        ZIndex = 3,
        Enabled = true,
        Parent = Sidebar,
        Value = SelectedCategory,
        Options = Scope:Value(AssetUtils:GetAllAssetCategories()),

        OnSelected = function(SelectedOption)
            --SelectedCategory:set(SelectedOption)
            Assets:set(AssetUtils:GetAssetsByCategory(SelectedOption))
        end,
    }


end

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
        MathValue = Scope:Value(3),
        MathValueRaw = Scope:Value("3"),
        SelectedProperty = Scope:Value("Size"),
        MathSliderMin = Scope:Value(1),
        MathSliderMax = Scope:Value(5),
    }

    local PropertyValues = {
        SelectedProperty = Scope:Value("Size"),
        CopiedValue = Scope:Value(nil),
    }

    local CoreProperties = VerticalCollapsibleSection {
        Name = "CoreProperties",
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
        
                            return tostring(CurrentInstance:GetAttribute("EmitCount") or "")
                        end),

                        Enabled = Scope:Computed(function(Use)
                            --return Use(States.IsEditable) and not Use(States.IsEffectModule)
                            return #Use(States.CurrentlySelected) > 0
                        end),

                        LayoutOrder = 1,
                        Size = UDim2.fromScale(0.7, 1),
                        Position = UDim2.fromScale(0.3, 0),
                        PlaceholderText = "0",

                        [Out "Text"] = CorePropertyValues.EmitCount,

                        [OnEvent "FocusLost"] = function()
                            local CurrentlySelected = Peek(States.CurrentlySelected)

                            if #CurrentlySelected == 0 then
                                return
                            end

                            local Text = Peek(CorePropertyValues.EmitCount)
                            local Number = tonumber(Text)
        
                            if not Number or Number == 0 then
                                return
                            end
        
                            for _, Instance in CurrentlySelected do
                                Instance:SetAttribute("EmitCount", Number)
                            end
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
        
                            return tostring(CurrentInstance:GetAttribute("EmitDelay") or "")
                        end),
        
                        PlaceholderText = "0",

                        Enabled = Scope:Computed(function(Use)
                            --  return Use(States.IsEditable) and not Use(States.IsEffectModule)
                            return #Use(States.CurrentlySelected) > 0
                        end),

                        LayoutOrder = 1,
                        Size = UDim2.fromScale(0.7, 1),
                        Position = UDim2.fromScale(0.3, 0),

                        [Out "Text"] = CorePropertyValues.EmitDelay,

                        [OnEvent "FocusLost"] = function()
                            local CurrentlySelected = Peek(States.CurrentlySelected)

                            if #CurrentlySelected == 0 then
                                return
                            end

                            local Text = Peek(CorePropertyValues.EmitDelay)
                            local Number = tonumber(Text)
        
                            if not Number or Number == 0 then
                                return
                            end
        
                            for _, Instance in CurrentlySelected do
                                Instance:SetAttribute("EmitDelay", Number)
                            end
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
        
                            return tostring(CurrentInstance:GetAttribute("EmitDuration") or "")
                        end),
        
                        PlaceholderText = "0",

                        Enabled = Scope:Computed(function(Use)
                            --return Use(States.IsEditable) and not Use(States.IsEffectModule)
                            return #Use(States.CurrentlySelected) > 0
                        end),

                        LayoutOrder = 1,
                        Size = UDim2.fromScale(0.7, 1),
                        Position = UDim2.fromScale(0.3, 0),

                        [Out "Text"] = CorePropertyValues.EmitDuration,

                        [OnEvent "FocusLost"] = function()
                            local CurrentlySelected = Peek(States.CurrentlySelected)

                            if #CurrentlySelected == 0 then
                                return
                            end

                            local Text = Peek(CorePropertyValues.EmitDuration)
                            local Number = tonumber(Text)
        
                            if not Number or Number == 0 then
                                return
                            end
        
                            for _, Instance in CurrentlySelected do
                                Instance:SetAttribute("EmitDuration", Number)
                            end
                        end,
                    },
                }
            },
        }
    }

    local EmitActions = VerticalCollapsibleSection {
        Name = "EmitActions",
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

    local MathOperations = VerticalCollapsibleSection {
        Name = "MathOperations",
        Collapsed = true,
        Padding = UDim.new(0, 10),
        Text = "Math Operations",
        Enabled = true,
        Parent = Container,

        [Children] = {
            Scope:New "Frame" {
                Name = "OperationAmount",
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,

                [Children] = {
                    TextInput {
                        PlaceholderText = "Min",
                        Text = Peek(UtilValues.MathSliderMin),
                        Enabled = States.IsEmittable,
                        LayoutOrder = 1,
                        Size = UDim2.fromScale(0.115, 1),
                        Position = UDim2.fromScale(0, 0),

                        [Out "Text"] = UtilValues.MathSliderMin,
                    },

                    TextInput {
                        PlaceholderText = "Max",
                        Text = Peek(UtilValues.MathSliderMax),
                        Enabled = States.IsEmittable,
                        LayoutOrder = 1,
                        Size = UDim2.fromScale(0.115, 1),
                        Position = UDim2.fromScale(0.13, 0),

                        [Out "Text"] = UtilValues.MathSliderMax,
                    },
                    
                    Slider {
                        Size = UDim2.fromScale(0.5, 0.5),
                        Position = UDim2.fromScale(0.25, 0),
                        Value = UtilValues.MathValue,

                        Min = Scope:Computed(function(Use)
                            local Value = tonumber(Use(UtilValues.MathSliderMin))

                            if not Value then
                                return 1
                            end 

                            return Value
                        end),

                        Max = Scope:Computed(function(Use)
                            local Value = tonumber(Use(UtilValues.MathSliderMax))

                            if not Value then
                                return 1
                            end 

                            return Value
                        end),

                        Step = Scope:Value(0.1),
                        Enabled = States.IsEmittable,

                        OnChange = function(NewValue : number)
                            UtilValues.MathValue:set(NewValue)
                        end,
                    },

                    TextInput {
                        PlaceholderText = "Value",

                        Text = Scope:Computed(function(Use)
                            local Value = Use(UtilValues.MathValue)
                            return tostring(math.round(Value * 10) / 10)
                        end),

                        Enabled = States.IsEmittable,
                        LayoutOrder = 1,
                        Size = UDim2.fromScale(0.25, 1),
                        Position = UDim2.fromScale(0.75, 0),

                        [Out "Text"] = UtilValues.MathValueRaw,

                        [OnEvent "Changed"] = function()
                            task.defer(function()
                                local Text = Peek(UtilValues.MathValueRaw)
                                local Number = tonumber(Text)
            
                                if not Number then
                                    return
                                end

                                if Number == Peek(UtilValues.MathValue) then
                                    return
                                end
            
                                UtilValues.MathValue:set(Number)
                            end)
                        end,
                    },

                    Label {
                        Text = Scope:Computed(function(Use)
                            local Value = Use(UtilValues.MathValue)
                            return string.format("%.1f", Value)
                        end),

                        TextScaled = true,
                        LayoutOrder = 0,
                        Size = UDim2.fromScale(0.5, 0.5),
                        Position = UDim2.fromScale(0.25, 0.5),
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                }
            },

            TextInput {
                PlaceholderText = "Property (e.g. Size, Speed)",
                Enabled = States.IsEmittable,
                LayoutOrder = 2,
                Size = UDim2.new(1, 0, 0, 30),
                Position = UDim2.fromScale(0, 0),

                [Out "Text"] = UtilValues.SelectedProperty,
            },

            BaseButton {
                Size = UDim2.new(1, 0, 0, 30),
                Text = "Add",
                LayoutOrder = 3,
                Enabled = States.IsEmittable,

                Activated = function()
                    local Value = tonumber(Peek(UtilValues.MathValue))
                    local Property = Peek(UtilValues.SelectedProperty)
                    local SelectedInstances = Peek(States.CurrentlySelected)

                    ApplyMathOperation(Value, Property, "add", SelectedInstances)
                end,
            },

            BaseButton {
                Size = UDim2.new(1, 0, 0, 30),
                Text = "Subtract",
                LayoutOrder = 4,
                Enabled = States.IsEmittable,

                Activated = function()
                    local Value = tonumber(Peek(UtilValues.MathValue))
                    local Property = Peek(UtilValues.SelectedProperty)
                    local SelectedInstances = Peek(States.CurrentlySelected)

                    ApplyMathOperation(Value, Property, "subtract", SelectedInstances)
                end,
            },

            BaseButton {
                Size = UDim2.new(1, 0, 0, 30),
                Text = "Multiply",
                LayoutOrder = 5,
                Enabled = States.IsEmittable,

                Activated = function()
                    local Value = tonumber(Peek(UtilValues.MathValue))
                    local Property = Peek(UtilValues.SelectedProperty)
                    local SelectedInstances = Peek(States.CurrentlySelected)

                    ApplyMathOperation(Value, Property, "multiply", SelectedInstances)
                end,
            },

            BaseButton {
                Size = UDim2.new(1, 0, 0, 30),
                Text = "Divide",
                LayoutOrder = 6,
                Enabled = States.IsEmittable,

                Activated = function()
                    local Value = tonumber(Peek(UtilValues.MathValue))
                    local Property = Peek(UtilValues.SelectedProperty)
                    local SelectedInstances = Peek(States.CurrentlySelected)

                    ApplyMathOperation(Value, Property, "divide", SelectedInstances)
                end,
            },
        }
    }

    local AnimationIndicators = VerticalCollapsibleSection {
        Name = "AnimationIndicators",
        Collapsed = true,
        Padding = UDim.new(0, 10),
        Text = "Animation Indicators",
        Enabled = true,
        Parent = Container,

        [Children] = {
            BaseButton {
                Size = UDim2.new(1, 0, 0, 30),
                Text = "Create Bezier Animation",
                Enabled = Scope:Computed(function(Use)
                    local SelectedInstances = Use(States.RawSelection)

                    return #Use(SelectedInstances) > 0
                end),

                Activated = function()
                    local SelectedInstances = Peek(States.RawSelection)

                    if #SelectedInstances == 0 then
                        return
                    end 

                    local Indicator = EmitUtils:CreateNewAnimationIndicator(SelectedInstances[1], "Bezier")
                    Selection:Set({Indicator})
                end,
            },

            BaseButton {
                Size = UDim2.new(1, 0, 0, 30),
                Text = "Create Tween Animation",
                Enabled = Scope:Computed(function(Use)
                    local SelectedInstances = Use(States.RawSelection)

                    return #Use(SelectedInstances) > 0
                end),

                Activated = function()
                    local SelectedInstances = Peek(States.RawSelection)

                    if #SelectedInstances == 0 then
                        return
                    end 

                    local Indicator = EmitUtils:CreateNewAnimationIndicator(SelectedInstances[1], "Tween")
                    Selection:Set({Indicator})
                end,
            },
        }
    }

    -- local AssetLibrary = VerticalCollapsibleSection {
    --     Name = "AssetLibrary",
    --     Collapsed = true,
    --     Padding = UDim.new(0, 10),
    --     Text = "Asset Library",
    --     Enabled = true,
    --     Parent = Container,

    --     [Children] = {
    --         BaseButton {
    --             Size = UDim2.new(1, 0, 0, 30),
    --             Text = "Open Library",
    --             Enabled = true,

    --             Activated = function()
    --                 LibraryWidget.Enabled = not LibraryWidget.Enabled
    --             end,
    --         },
    --     }
    -- }

    local ProgrammerModules = VerticalCollapsibleSection {
        Name = "ProgrammerModules",
        Collapsed = true,
        Padding = UDim.new(0, 10),
        Text = "Programmer Resources",
        Enabled = true,
        Parent = Container,

        [Children] = {
            BaseButton {
                Size = UDim2.new(1, 0, 0, 30),
                Text = "Insert PlayEffect Module",
                Enabled = Scope:Computed(function(Use)
                    local SelectedInstances = Use(States.RawSelection)

                    return #Use(SelectedInstances) > 0
                end),

                Activated = function()
                    local SelectedInstances = Peek(States.RawSelection)

                    if #SelectedInstances == 0 then
                        return
                    end

                    local PlayEffectModule = Bin.PlaybackModules.PlayEffect:Clone()
                    PlayEffectModule.Parent = SelectedInstances[1]
                    Selection:Set({PlayEffectModule})
                end,
            },

            BaseButton {
                Size = UDim2.new(1, 0, 0, 30),
                Text = "Insert Effect Module Template",
                Enabled = Scope:Computed(function(Use)
                    local SelectedInstances = Use(States.RawSelection)

                    return #Use(SelectedInstances) > 0
                end),

                Activated = function()
                    local SelectedInstances = Peek(States.RawSelection)

                    if #SelectedInstances == 0 then
                        return
                    end

                    local EffectModuleTemplate = Bin.PlaybackModules.EffectModuleTemplate:Clone()
                    EffectModuleTemplate.Parent = SelectedInstances[1]
                    Selection:Set({EffectModuleTemplate})
                end,
            }
        }
    }

    EmitUtils:SetWidget(MainWidget)

    MainWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    LibraryWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    --InitLibrary()

    return MainWidget
end

return Interface
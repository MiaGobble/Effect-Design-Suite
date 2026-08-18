local EditorSession = {}

-- Constants
local COLOR_SEQUENCE_ATTRIBUTE = "EffectDesignerOklabColorSequence"
local CURVE_ATTRIBUTE_PREFIX = "EffectDesignerCurve_"
local DEFAULT_CURVE_RANGES = {
    Transparency = { 0, 1 },
    Scale = { 0, 1 },
}

EditorSession.COLOR_SEQUENCE_ATTRIBUTE = COLOR_SEQUENCE_ATTRIBUTE

-- Services
local HttpService = game:GetService("HttpService")

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Objects = Bin:FindFirstChild("Objects")
local States = require(Objects:FindFirstChild("States"))
local EffectOps = require(script.Parent:FindFirstChild("EffectOps"))
local PartAnimation = require(script.Parent:FindFirstChild("PartAnimation"))
local SelectionQueries = require(script.Parent:FindFirstChild("SelectionQueries"))

local function CurveAttributeName(property)
    return CURVE_ATTRIBUTE_PREFIX .. property
end

local function CurveRangeAttributeName(property, suffix)
    return CurveAttributeName(property) .. "_" .. suffix
end

local function GetDefaultCurveRange(property : string)
    local Range = DEFAULT_CURVE_RANGES[property]
    if Range then
        return Range[1], Range[2]
    end

    return 0, 10
end

local function MakeDefaultCurvePoints(defaultValue)
    return {
        {
            Time = 0,
            Value = defaultValue,
            InHandleX = 0,
            InHandleY = 0,
            OutHandleX = 0,
            OutHandleY = 0,
        },
        {
            Time = 1,
            Value = defaultValue,
            InHandleX = 0,
            InHandleY = 0,
            OutHandleX = 0,
            OutHandleY = 0,
        },
    }
end

function EditorSession.CurveAttributeName(property)
    return CurveAttributeName(property)
end

function EditorSession.CurveRangeAttributeName(property, suffix)
    return CurveRangeAttributeName(property, suffix)
end

function EditorSession.DefaultColorSequencePoints()
    return {
        EffectOps.Color3ToOklabPoint(Color3.new(1, 1, 1), 0),
        EffectOps.Color3ToOklabPoint(Color3.new(1, 1, 1), 1),
    }
end

function EditorSession.Create(scope)
    local Session = {
        CurvePropertyText = scope:Value(""),
        CurveMinRangeText = scope:Value("0"),
        CurveMaxRangeText = scope:Value("10"),
        CurvePoints = scope:Value(MakeDefaultCurvePoints(0.5)),
        ColorSequencePoints = scope:Value(EditorSession.DefaultColorSequencePoints()),
        ActiveColorPointIndex = scope:Value(nil),
        ColorPickerValue = scope:Value(Color3.new(1, 1, 1)),
        CopiedValue = scope:Value(nil),
        IsSyncingColorPicker = false,
        CurveEditorWidget = nil,
        ColorSequenceWidget = nil,
        ColorPickerWidget = nil,
    }

    function Session.ResetCurveState()
        local MinRange, MaxRange = GetDefaultCurveRange(Session.CurvePropertyText.Value)
        local DefaultValue = if Session.CurvePropertyText.Value == "Scale" then 1 else 0.5
        Session.CurvePoints.Value = MakeDefaultCurvePoints(DefaultValue)
        Session.CurveMinRangeText.Value = tostring(MinRange)
        Session.CurveMaxRangeText.Value = tostring(MaxRange)
    end

    function Session.ReadCurveState()
        local Property = Session.CurvePropertyText.Value
        local Instance = SelectionQueries.GetInspectedInstance()
        if not Property or Property == "" or not Instance then
            Session.ResetCurveState()
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
            Session.CurvePoints.Value = Points
            Session.CurveMinRangeText.Value = tostring(MinRange or 0)
            Session.CurveMaxRangeText.Value = tostring(MaxRange or 1)
        else
            Session.ResetCurveState()
        end
    end

    function Session.ReadColorSequenceState()
        local SourceInstance = SelectionQueries.GetInspectedInstance()
        if SourceInstance and not SelectionQueries.CanEditColorSequence(SourceInstance) then
            SourceInstance = nil
        end

        Session.ActiveColorPointIndex.Value = nil
        if Session.ColorPickerWidget then
            Session.ColorPickerWidget.Enabled = false
        end
        if not SourceInstance then
            Session.ColorSequencePoints.Value = EditorSession.DefaultColorSequencePoints()
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
            if SelectionQueries.HasColorSequence(SourceInstance) then
                Points = EffectOps.ReadOklabPointsFromColorSequence(SourceInstance.Color)
            elseif SourceInstance:IsA("BasePart") then
                Points = {
                    EffectOps.Color3ToOklabPoint(SourceInstance.Color, 0),
                    EffectOps.Color3ToOklabPoint(SourceInstance.Color, 1),
                }
            else
                Points = EditorSession.DefaultColorSequencePoints()
            end
        end

        Session.ColorSequencePoints.Value = Points
    end

    function Session.OpenCurveEditor(property : string)
        Session.CurvePropertyText.Value = property
        Session.ReadCurveState()
        if Session.CurveEditorWidget then
            Session.CurveEditorWidget.Enabled = true
        end
    end

    function Session.OpenColorSequenceEditor()
        Session.ReadColorSequenceState()
        if Session.ColorSequenceWidget then
            Session.ColorSequenceWidget.Enabled = true
        end
    end

    function Session.SyncPickerFromPoint(index)
        local Point = index and Session.ColorSequencePoints.Value[index] or nil
        if not Point then
            return
        end

        Session.IsSyncingColorPicker = true
        Session.ColorPickerValue.Value = EffectOps.OklabPointToColor3(Point)
        Session.IsSyncingColorPicker = false
    end

    function Session.ApplyCurve()
        local SelectedProperty = Session.CurvePropertyText.Value
        local MinRange = tonumber(Session.CurveMinRangeText.Value)
        local MaxRange = tonumber(Session.CurveMaxRangeText.Value)

        if not SelectedProperty or SelectedProperty == "" then
            return
        end

        if not MinRange or not MaxRange or MinRange > MaxRange then
            return
        end

        local NewSequence = EffectOps.BuildNumberSequenceFromCurve(Session.CurvePoints.Value, MinRange, MaxRange)
        local EncodedPoints = HttpService:JSONEncode(Session.CurvePoints.Value)
        local CLASS_APPLIERS = {
            BasePart = function(instance)
                PartAnimation.Ensure(instance, Bin)
                instance:SetAttribute(CurveAttributeName(SelectedProperty), EncodedPoints)
                instance:SetAttribute(CurveRangeAttributeName(SelectedProperty, "MinRange"), MinRange)
                instance:SetAttribute(CurveRangeAttributeName(SelectedProperty, "MaxRange"), MaxRange)
            end,
        }

        for _, instance in SelectionQueries.GetPropertyEditTargets() do
            local Applier = CLASS_APPLIERS[instance.ClassName]
            if instance:IsA("BasePart") then
                Applier = CLASS_APPLIERS.BasePart
            end

            if Applier then
                Applier(instance)
            else
                pcall(function()
                    instance[SelectedProperty] = NewSequence
                    instance:SetAttribute(CurveAttributeName(SelectedProperty), EncodedPoints)
                    instance:SetAttribute(CurveRangeAttributeName(SelectedProperty, "MinRange"), MinRange)
                    instance:SetAttribute(CurveRangeAttributeName(SelectedProperty, "MaxRange"), MaxRange)
                end)
            end
        end
    end

    function Session.ApplyColorSequence()
        local NewSequence = EffectOps.BuildColorSequenceFromOklabPoints(Session.ColorSequencePoints.Value)
        local EncodedPoints = HttpService:JSONEncode(Session.ColorSequencePoints.Value)
        local CLASS_APPLIERS = {
            ColorSequence = function(instance)
                pcall(function()
                    instance.Color = NewSequence
                    instance:SetAttribute(COLOR_SEQUENCE_ATTRIBUTE, EncodedPoints)
                end)
            end,
            BasePart = function(instance)
                PartAnimation.Ensure(instance, Bin)
                instance:SetAttribute(COLOR_SEQUENCE_ATTRIBUTE, EncodedPoints)
            end,
        }

        for _, instance in SelectionQueries.GetPropertyEditTargets() do
            if SelectionQueries.HasColorSequence(instance) then
                CLASS_APPLIERS.ColorSequence(instance)
            elseif instance:IsA("BasePart") then
                CLASS_APPLIERS.BasePart(instance)
            end
        end
    end

    scope:OnChanged(States.CurrentlySelected, function()
        Session.ReadCurveState()
        Session.ReadColorSequenceState()
    end)
    scope:OnChanged(Session.CurvePropertyText, Session.ReadCurveState)
    Session.ReadColorSequenceState()

    return Session
end

return EditorSession

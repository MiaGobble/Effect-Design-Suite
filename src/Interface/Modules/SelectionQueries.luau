local SelectionQueries = {}

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Objects = Bin:FindFirstChild("Objects")
local States = require(Objects:FindFirstChild("States"))
local PropertyMaps = require(script.Parent:FindFirstChild("PropertyMaps"))

local TEXTURE_CLASSES = {
    ParticleEmitter = true,
    Beam = true,
    Trail = true,
}

function SelectionQueries.GetInspectedInstance()
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

function SelectionQueries.GetPropertyEditTargets()
    local Inspected = SelectionQueries.GetInspectedInstance()
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

function SelectionQueries.HasColorSequence(instance)
    local Success, Value = pcall(function()
        return instance.Color
    end)
    return Success and typeof(Value) == "ColorSequence"
end

function SelectionQueries.CanEditColorSequence(instance)
    return SelectionQueries.HasColorSequence(instance) or instance:IsA("BasePart")
end

function SelectionQueries.Create(scope)
    local HasEditableSelection = scope:Computed(function(use)
        return #use(States.CurrentlySelected) > 0
    end)

    local HasConfigurableSelection = scope:Computed(function(use)
        local RawSelection = use(States.RawSelection)
        return #RawSelection >= 1 and PropertyMaps.IsConfigurableInstance(RawSelection[1])
    end)

    local HasRawSelection = scope:Computed(function(use)
        return #use(States.RawSelection) > 0
    end)

    local HasColorSequenceSelection = scope:Computed(function(use)
        local RawSelection = use(States.RawSelection)
        return #RawSelection >= 1 and PropertyMaps.IsColorSequenceProperty(RawSelection[1], "Color")
    end)

    local HasParticleEmitterSelection = scope:Computed(function(use)
        for _, instance in use(States.CurrentlySelected) do
            if instance:IsA("ParticleEmitter") then
                return true
            end
        end

        return false
    end)

    local HasReplaceTargets = scope:Computed(function(use)
        local RawSelection = use(States.RawSelection)
        local CurrentSelection = use(States.CurrentlySelected)

        for _, instance in RawSelection do
            if TEXTURE_CLASSES[instance.ClassName] then
                return true
            end
        end

        for _, instance in CurrentSelection do
            if TEXTURE_CLASSES[instance.ClassName] then
                return true
            end
        end

        return false
    end)

    local SelectionSummary = scope:Computed(function(use)
        local RawSelection = use(States.RawSelection)

        if #RawSelection == 0 or not PropertyMaps.IsConfigurableInstance(RawSelection[1]) then
            return "this instance is not configurable with Effect Designer Suite"
        end

        local Inspected = RawSelection[1]
        if #RawSelection == 1 then
            return string.format("%s — %s", Inspected.ClassName, Inspected.Name)
        end

        return string.format("%s — %s (+%d)", Inspected.ClassName, Inspected.Name, #RawSelection - 1)
    end)

    return {
        HasEditableSelection = HasEditableSelection,
        HasConfigurableSelection = HasConfigurableSelection,
        HasRawSelection = HasRawSelection,
        HasColorSequenceSelection = HasColorSequenceSelection,
        HasParticleEmitterSelection = HasParticleEmitterSelection,
        HasReplaceTargets = HasReplaceTargets,
        SelectionSummary = SelectionSummary,
        GetInspectedInstance = SelectionQueries.GetInspectedInstance,
        GetPropertyEditTargets = SelectionQueries.GetPropertyEditTargets,
        HasColorSequence = SelectionQueries.HasColorSequence,
        CanEditColorSequence = SelectionQueries.CanEditColorSequence,
    }
end

return SelectionQueries

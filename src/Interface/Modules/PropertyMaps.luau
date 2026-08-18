local PropertyMaps = {}

-- Constants
PropertyMaps.PARTICLE_PROPERTIES = {
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

PropertyMaps.CONFIGURABLE_CLASSES = {
    ParticleEmitter = true,
    Beam = true,
    Sound = true,
    ModuleScript = true,
    StringValue = true,
    Trail = true,
}

PropertyMaps.COPY_PROPERTIES_BY_CLASS = {
    ParticleEmitter = {
        "Size",
        "Color",
        "Transparency",
        "Speed",
        "Acceleration",
        "Lifetime",
        "Rate",
        "LightEmission",
        "LightInfluence",
        "Texture",
    },
    Beam = {
        "Color",
        "Transparency",
        "Width0",
        "Width1",
        "Texture",
        "TextureLength",
        "TextureSpeed",
        "Brightness",
    },
    Trail = {
        "Color",
        "Transparency",
        "WidthScale",
        "Texture",
        "Brightness",
    },
    Attachment = {
        "Position",
        "Orientation",
        "Axis",
        "SecondaryAxis",
    },
}

PropertyMaps.CURVE_PROPERTIES_BY_CLASS = {
    ParticleEmitter = {
        "Size",
        "Transparency",
        "Squash",
    },
    Beam = {
        "Transparency",
        "WidthScale",
    },
    Trail = {
        "Transparency",
        "WidthScale",
    },
    Attachment = {},
    BasePart = {
        "Transparency",
        "Scale",
    },
}

PropertyMaps.SKIP_INSPECTOR_PROPERTIES = {
    Parent = true,
    ClassName = true,
    className = true,
    UniqueId = true,
    Capabilities = true,
    Sandboxed = true,
    IsInSandbox = true,
    RobloxLocked = true,
    PredictionMode = true,
    archivable = true,
    FlipbookIncompatible = true,
    FlipbookIncompatiable = true,
    LocalTransparencyModifier = true,
    TextureContent = true,
    AudioContent = true,
    BackParamA = true,
    BackParamB = true,
    BackSurface = true,
    BackSurfaceInput = true,
    BottomParamA = true,
    BottomParamB = true,
    BottomSurface = true,
    BottomSurfaceInput = true,
    BrickColor = true,
    brickColor = true,
    CollisionGroupId = true,
    CustomPhysicalProperties = true,
    Elasticity = true,
    Friction = true,
    FrontParamA = true,
    FrontParamB = true,
    FrontSurface = true,
    FrontSurfaceInput = true,
    LeftParamA = true,
    LeftParamB = true,
    LeftSurface = true,
    LeftSurfaceInput = true,
    MaterialVariant = true,
    RightParamA = true,
    RightParamB = true,
    RightSurface = true,
    RightSurfaceInput = true,
    RootPriority = true,
    RotVelocity = true,
    TopParamA = true,
    TopParamB = true,
    TopSurface = true,
    TopSurfaceInput = true,
    formfactor = true,
    FormFactor = true,
    Source = true,
    source = true,
    LinkedSource = true,
    linkedSource = true,
    PivotOffset = true,
    Velocity = true,
}

PropertyMaps.DISPLAY_PROPERTIES_BY_CLASS = {
    ParticleEmitter = {
        "Size",
        "Color",
        "Transparency",
        "Squash",
        "Speed",
        "Acceleration",
        "Lifetime",
        "Rate",
        "SpreadAngle",
        "LightEmission",
        "LightInfluence",
        "Texture",
    },
    Beam = {
        "Color",
        "Transparency",
        "Width0",
        "Width1",
        "WidthScale",
        "Texture",
        "TextureLength",
        "TextureSpeed",
        "Brightness",
    },
    Trail = {
        "Color",
        "Transparency",
        "WidthScale",
        "Texture",
        "Brightness",
    },
    Sound = {
        "SoundId",
        "Volume",
        "PlaybackSpeed",
        "Looped",
        "RollOffMinDistance",
        "RollOffMaxDistance",
    },
    StringValue = {
        "Value",
    },
    ModuleScript = {},
    BasePart = {
        "Color",
        "Transparency",
        "Size",
        "Scale",
    },
}

-- Methods
function PropertyMaps.NormalizeParticleProperty(propertyName : string)
    local LowerName = propertyName:lower()

    for _, property in PropertyMaps.PARTICLE_PROPERTIES do
        if property:lower():sub(1, #LowerName) == LowerName then
            return property
        end
    end

    return propertyName
end

function PropertyMaps.IsConfigurableInstance(instance)
    if typeof(instance) ~= "Instance" then
        return false
    end

    if PropertyMaps.CONFIGURABLE_CLASSES[instance.ClassName] then
        return true
    end

    return instance:IsA("BasePart")
end

function PropertyMaps.GetClassKey(instance)
    if typeof(instance) ~= "Instance" then
        return nil
    end

    if instance:IsA("BasePart") then
        return "BasePart"
    end

    return instance.ClassName
end

function PropertyMaps.GetSelectionClass(instances : {Instance})
    if not instances or #instances == 0 then
        return nil
    end

    return PropertyMaps.GetClassKey(instances[1])
end

function PropertyMaps.GetPropertiesForSelection(instances : {Instance}, propertyMap)
    local ClassName = PropertyMaps.GetSelectionClass(instances)

    if not ClassName then
        return {}
    end

    return propertyMap[ClassName] or {}
end

local InspectorPropertyCache = {}

local function CanReadProperty(instance, property : string)
    local Success = pcall(function()
        return instance[property]
    end)

    return Success
end

function PropertyMaps.ShouldSkipInspectorProperty(property)
    if typeof(property) ~= "string" then
        return true
    end

    if PropertyMaps.SKIP_INSPECTOR_PROPERTIES[property] then
        return true
    end

    return PropertyMaps.SKIP_INSPECTOR_PROPERTIES[string.lower(property)] == true
end

function PropertyMaps.GetInspectorProperties(instance)
    if typeof(instance) ~= "Instance" then
        return {}
    end

    local Cached = InspectorPropertyCache[instance.ClassName]
    if Cached then
        local HasCFrame = table.find(Cached, "CFrame") ~= nil
        local VisibleProperties = {}
        for _, property in Cached do
            if PropertyMaps.ShouldSkipInspectorProperty(property) then
                continue
            end

            if HasCFrame and (property == "Position" or property == "Orientation") then
                continue
            end

            table.insert(VisibleProperties, property)
        end
        return VisibleProperties
    end

    local Properties = {}
    local Seen = {}

    local Success, Reflected = pcall(function()
        local ReflectionService = game:GetService("ReflectionService")
        local FilterSuccess, Filter = pcall(function()
            return {
                Security = SecurityCapabilities.new(table.unpack(Enum.SecurityCapability:GetEnumItems())),
            }
        end)

        if FilterSuccess then
            return ReflectionService:GetPropertiesOfClass(instance.ClassName, Filter)
        end

        return ReflectionService:GetPropertiesOfClass(instance.ClassName)
    end)

    if Success and typeof(Reflected) == "table" then
        for _, propertyInfo in Reflected do
            local Name = propertyInfo.Name
            if typeof(Name) ~= "string" or PropertyMaps.ShouldSkipInspectorProperty(Name) or Seen[Name] then
                continue
            end

            local Permits = propertyInfo.Permits
            if not Permits or not Permits.Write then
                continue
            end

            if not CanReadProperty(instance, Name) then
                continue
            end

            Seen[Name] = true
            table.insert(Properties, Name)
        end
    end

    if #Properties == 0 then
        local ClassName = PropertyMaps.GetClassKey(instance)
        for _, property in PropertyMaps.DISPLAY_PROPERTIES_BY_CLASS[ClassName] or {} do
            if not Seen[property] then
                Seen[property] = true
                table.insert(Properties, property)
            end
        end
    end

    local ClassName = PropertyMaps.GetClassKey(instance)
    for _, property in PropertyMaps.CURVE_PROPERTIES_BY_CLASS[ClassName] or {} do
        if not Seen[property] then
            Seen[property] = true
            table.insert(Properties, property)
        end
    end

    table.sort(Properties)
    InspectorPropertyCache[instance.ClassName] = Properties

    local HasCFrame = table.find(Properties, "CFrame") ~= nil
    local VisibleProperties = {}
    for _, property in Properties do
        if PropertyMaps.ShouldSkipInspectorProperty(property) then
            continue
        end

        if HasCFrame and (property == "Position" or property == "Orientation") then
            continue
        end

        table.insert(VisibleProperties, property)
    end

    return VisibleProperties
end

function PropertyMaps.IsCurveProperty(instance, property : string)
    local ClassName = PropertyMaps.GetClassKey(instance)
    local Properties = ClassName and PropertyMaps.CURVE_PROPERTIES_BY_CLASS[ClassName]

    return Properties ~= nil and table.find(Properties, property) ~= nil
end

function PropertyMaps.IsColorSequenceProperty(instance, property : string)
    if property ~= "Color" or typeof(instance) ~= "Instance" then
        return false
    end

    if instance:IsA("BasePart") then
        return true
    end

    local Success, Value = pcall(function()
        return instance.Color
    end)

    return Success and typeof(Value) == "ColorSequence"
end

return PropertyMaps

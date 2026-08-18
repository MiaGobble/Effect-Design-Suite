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
local PRIMITIVE_TYPE_NAMES = {
    string = true,
    number = true,
    boolean = true,
    float = true,
    double = true,
    int = true,
    int64 = true,
    Vector2 = true,
    Vector3 = true,
    CFrame = true,
    Color3 = true,
    UDim = true,
    UDim2 = true,
    Rect = true,
    NumberRange = true,
    NumberSequence = true,
    ColorSequence = true,
    BrickColor = true,
    Enum = true,
    EnumItem = true,
    Content = true,
    Font = true,
    Faces = true,
    Axes = true,
    PhysicalProperties = true,
    Ray = true,
    Region3 = true,
    TweenInfo = true,
    DateTime = true,
}
local KNOWN_INSTANCE_PROPERTY_CLASSES = {
    Attachment0 = "Attachment",
    Attachment1 = "Attachment",
    Adornee = "Instance",
    PrimaryPart = "BasePart",
}

local function CanReadProperty(instance, property : string)
    local Success = pcall(function()
        return instance[property]
    end)

    return Success
end

local function ReadPropertyType(propertyInfo)
    local Type = propertyInfo.Type or propertyInfo.ValueType or propertyInfo.SerializedType
    if typeof(Type) == "string" then
        return {
            Name = Type,
            Category = nil,
        }
    end

    if typeof(Type) ~= "table" then
        return nil
    end

    return {
        Name = Type.Name or Type.name,
        Category = Type.Category or Type.category,
    }
end

local function IsClassPropertyType(typeInfo)
    if typeof(typeInfo) ~= "table" then
        return false
    end

    local Category = typeInfo.Category
    if Category == "Class" or Category == "Object" or Category == "Instance" or Category == "Instances" then
        return true
    end

    local Name = typeInfo.Name
    if Name == "Instance" or Name == "Object" then
        return true
    end

    if typeof(Name) ~= "string" or PRIMITIVE_TYPE_NAMES[Name] then
        return false
    end

    if Category == "Primitive" or Category == "DataType" or Category == "Enum" then
        return false
    end

    local Success = pcall(function()
        workspace:IsA(Name)
    end)
    return Success
end

local function GetCachedPropertyNames(cached)
    if typeof(cached) == "table" and cached.Names then
        return cached.Names, cached.Types or {}
    end

    return cached, {}
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
        local Names = GetCachedPropertyNames(Cached)
        local HasCFrame = table.find(Names, "CFrame") ~= nil
        local VisibleProperties = {}
        for _, property in Names do
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
    local Types = {}
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
            Types[Name] = ReadPropertyType(propertyInfo)
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
    InspectorPropertyCache[instance.ClassName] = {
        Names = Properties,
        Types = Types,
    }

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

function PropertyMaps.GetInstancePropertyClass(instance, property : string)
    if typeof(instance) ~= "Instance" or typeof(property) ~= "string" then
        return nil
    end

    PropertyMaps.GetInspectorProperties(instance)

    local Cached = InspectorPropertyCache[instance.ClassName]
    local _, Types = GetCachedPropertyNames(Cached)
    local TypeInfo = Types[property]
    if IsClassPropertyType(TypeInfo) then
        return TypeInfo.Name or "Instance"
    end

    local KnownClass = KNOWN_INSTANCE_PROPERTY_CLASSES[property]
    if KnownClass then
        return KnownClass
    end

    local Success, Value = pcall(function()
        return instance[property]
    end)
    if Success and typeof(Value) == "Instance" then
        return Value.ClassName
    end

    return nil
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

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

function PropertyMaps.NormalizeParticleProperty(propertyName : string)
    local LowerName = propertyName:lower()

    for _, property in PropertyMaps.PARTICLE_PROPERTIES do
        if property:lower():sub(1, #LowerName) == LowerName then
            return property
        end
    end

    return propertyName
end

function PropertyMaps.GetSelectionClass(instances : {Instance})
    if not instances or #instances == 0 then
        return nil
    end

    local First = instances[1]

    if PropertyMaps.COPY_PROPERTIES_BY_CLASS[First.ClassName] then
        return First.ClassName
    end

    if PropertyMaps.CURVE_PROPERTIES_BY_CLASS[First.ClassName] then
        return First.ClassName
    end

    if First:IsA("BasePart") then
        return "BasePart"
    end

    return nil
end

function PropertyMaps.GetPropertiesForSelection(instances : {Instance}, propertyMap)
    local ClassName = PropertyMaps.GetSelectionClass(instances)

    if not ClassName then
        return {}
    end

    return propertyMap[ClassName] or {}
end

return PropertyMaps

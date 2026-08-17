local PropertyMaps = {}

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

function PropertyMaps.NormalizeParticleProperty(PropertyName : string)
    local LowerName = PropertyName:lower()

    for _, Property in PropertyMaps.PARTICLE_PROPERTIES do
        if Property:lower():sub(1, #LowerName) == LowerName then
            return Property
        end
    end

    return PropertyName
end

function PropertyMaps.GetSelectionClass(Instances : {Instance})
    if not Instances or #Instances == 0 then
        return nil
    end

    local First = Instances[1]

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

function PropertyMaps.GetPropertiesForSelection(Instances : {Instance}, PropertyMap)
    local ClassName = PropertyMaps.GetSelectionClass(Instances)

    if not ClassName then
        return {}
    end

    return PropertyMap[ClassName] or {}
end

return PropertyMaps

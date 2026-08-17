local VfxApiInjection = require(script.Parent.VfxApiInjection)

local PartAnimation = {}

PartAnimation.MODULE_NAME = "EDSPartAnimation"
PartAnimation.REFERENCE_NAME = "EffectDesignerAnimation"
PartAnimation.ORIGINAL_SIZE = "EffectDesignerOriginalSize"
PartAnimation.ORIGINAL_TRANSPARENCY = "EffectDesignerOriginalTransparency"
PartAnimation.ORIGINAL_COLOR = "EffectDesignerOriginalColor"

local function StoreOriginals(Part : BasePart)
    if Part:GetAttribute(PartAnimation.ORIGINAL_SIZE) == nil then
        Part:SetAttribute(PartAnimation.ORIGINAL_SIZE, Part.Size)
    end

    if Part:GetAttribute(PartAnimation.ORIGINAL_TRANSPARENCY) == nil then
        Part:SetAttribute(PartAnimation.ORIGINAL_TRANSPARENCY, Part.Transparency)
    end

    if Part:GetAttribute(PartAnimation.ORIGINAL_COLOR) == nil then
        Part:SetAttribute(PartAnimation.ORIGINAL_COLOR, Part.Color)
    end
end

function PartAnimation.Ensure(Part : BasePart, BinFolder : Instance)
    StoreOriginals(Part)
    VfxApiInjection.EnsureSharedModules(BinFolder)

    local Template = BinFolder.PlaybackModules:FindFirstChild("PartAnimation")
    if not Template then
        warn("Effect Designer Suite could not find the PartAnimation playback module.")
        return nil
    end

    local ExistingReference = Part:FindFirstChild(PartAnimation.REFERENCE_NAME)
    local ExistingModule = nil
    if ExistingReference and ExistingReference:IsA("ObjectValue") then
        ExistingModule = ExistingReference.Value
    end

    if not (ExistingModule and ExistingModule:IsA("ModuleScript")) then
        local Child = Part:FindFirstChild(PartAnimation.MODULE_NAME)
        if Child and Child:IsA("ModuleScript") then
            ExistingModule = Child
        end
    end

    if not (ExistingModule and ExistingModule:IsA("ModuleScript")) then
        ExistingModule = Template:Clone()
        ExistingModule.Name = PartAnimation.MODULE_NAME
        ExistingModule.Parent = Part
    end

    if not (ExistingReference and ExistingReference:IsA("ObjectValue")) then
        ExistingReference = Instance.new("ObjectValue")
        ExistingReference.Name = PartAnimation.REFERENCE_NAME
        ExistingReference.Parent = Part
    end

    ExistingReference.Value = ExistingModule
    return ExistingModule, ExistingReference
end

return PartAnimation

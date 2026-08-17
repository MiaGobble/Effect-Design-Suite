local PartAnimation = {}

-- Constants
PartAnimation.MODULE_NAME = "EDSPartAnimation"
PartAnimation.REFERENCE_NAME = "EffectDesignerAnimation"
PartAnimation.ORIGINAL_SIZE = "EffectDesignerOriginalSize"
PartAnimation.ORIGINAL_TRANSPARENCY = "EffectDesignerOriginalTransparency"
PartAnimation.ORIGINAL_COLOR = "EffectDesignerOriginalColor"

-- Imports
local VfxApiInjection = require(script.Parent.VfxApiInjection)

local function StoreOriginals(part : BasePart)
    if part:GetAttribute(PartAnimation.ORIGINAL_SIZE) == nil then
        part:SetAttribute(PartAnimation.ORIGINAL_SIZE, part.Size)
    end

    if part:GetAttribute(PartAnimation.ORIGINAL_TRANSPARENCY) == nil then
        part:SetAttribute(PartAnimation.ORIGINAL_TRANSPARENCY, part.Transparency)
    end

    if part:GetAttribute(PartAnimation.ORIGINAL_COLOR) == nil then
        part:SetAttribute(PartAnimation.ORIGINAL_COLOR, part.Color)
    end
end

function PartAnimation.Ensure(part : BasePart, binFolder : Instance)
    StoreOriginals(part)
    VfxApiInjection.EnsureSharedModules(binFolder)

    local Template = binFolder.PlaybackModules:FindFirstChild("PartAnimation")
    if not Template then
        warn(`Effect Designer Suite could not find the PartAnimation playback module. {debug.traceback()}`)
        return nil
    end

    local ExistingReference = part:FindFirstChild(PartAnimation.REFERENCE_NAME)
    local ExistingModule = nil
    if ExistingReference and ExistingReference:IsA("ObjectValue") then
        ExistingModule = ExistingReference.Value
    end

    if not (ExistingModule and ExistingModule:IsA("ModuleScript")) then
        local Child = part:FindFirstChild(PartAnimation.MODULE_NAME)
        if Child and Child:IsA("ModuleScript") then
            ExistingModule = Child
        end
    end

    if not (ExistingModule and ExistingModule:IsA("ModuleScript")) then
        ExistingModule = Template:Clone()
        ExistingModule.Name = PartAnimation.MODULE_NAME
        ExistingModule.Parent = part
    end

    if not (ExistingReference and ExistingReference:IsA("ObjectValue")) then
        ExistingReference = Instance.new("ObjectValue")
        ExistingReference.Name = PartAnimation.REFERENCE_NAME
        ExistingReference.Parent = part
    end

    ExistingReference.Value = ExistingModule
    return ExistingModule, ExistingReference
end

return PartAnimation

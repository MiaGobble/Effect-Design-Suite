-- Written by @boatbomber
-- Modified by @iGottic

-- Constants
local COMPONENT_ONLY_PROPERTIES = {
	"ClassName",
}

-- Services
local StudioService = game:GetService("StudioService")

-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local StudioComponents = script.Parent
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local stripProps = require(StudioComponentsUtil.stripProps)
local types = require(StudioComponentsUtil.types)
local unwrap = require(StudioComponentsUtil.unwrap)
local Scope = Fusion.scoped(Fusion)

-- Types Extended
type ClassIconProperties = {
	ClassName: (string | types.StateObject<string>),
	[any]: any,
}

return function(props: ClassIconProperties): Frame
	local image = Scope:Computed(function(use)
		local class = unwrap(props.ClassName, use)
		return StudioService:GetClassIcon(class)
	end)

	local hydrateProps = stripProps(props, COMPONENT_ONLY_PROPERTIES)

	return Scope:Hydrate(Scope:New "ImageLabel" {
		Name = "ClassIcon",
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,

		Image = Scope:Computed(function(use)
			return unwrap(image, use).Image
		end),
		
		ImageRectOffset = Scope:Computed(function(use)
			return unwrap(image, use).ImageRectOffset
		end),

		ImageRectSize = Scope:Computed(function(use)
			return unwrap(image, use).ImageRectSize
		end),
	})(hydrateProps)
end

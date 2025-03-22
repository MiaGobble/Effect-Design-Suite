-- Modified by iGottic

-- Constants
local COMPONENT_ONLY_PROPERTIES = {
	"StudioStyleGuideColor",
	"StudioStyleGuideModifier"
}

-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local Scope = Fusion.scoped(Fusion)
local StudioComponents = script.Parent
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local themeProvider = require(StudioComponentsUtil.themeProvider)
local stripProps = require(StudioComponentsUtil.stripProps)
local types = require(StudioComponentsUtil.types)

-- Types Extended
type BackgroundProperties = {
	StudioStyleGuideColor: types.CanBeState<Enum.StudioStyleGuideColor>?,
	StudioStyleGuideModifier: types.CanBeState<Enum.StudioStyleGuideModifier>?,
	[any]: any,
}

return function(Properties: BackgroundProperties): Frame
	return Scope:Hydrate(Scope:New "Frame" {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		AnchorPoint = Vector2.new(0, 0),
		LayoutOrder = 0,
		ZIndex = 1,
		BorderSizePixel = 0,
		BackgroundColor3 = themeProvider:GetColor(
			Properties.StudioStyleGuideColor or Enum.StudioStyleGuideColor.MainBackground, 
			Properties.StudioStyleGuideModifier
		),
	})(stripProps(Properties, COMPONENT_ONLY_PROPERTIES))
end
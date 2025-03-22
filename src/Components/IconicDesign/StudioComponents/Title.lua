-- Written by @boatbomber
-- Modified by @iGottic

-- Constants
local COMPONENT_ONLY_PROPERTIES = {
	"Enabled",
	"TextColorStyle",
	"TextColor3",
	"TextSize",
}

-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local StudioComponents = script.Parent
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local getState = require(StudioComponentsUtil.getState)
local themeProvider = require(StudioComponentsUtil.themeProvider)
local constants = require(StudioComponentsUtil.constants)
local unwrap = require(StudioComponentsUtil.unwrap)
local types = require(StudioComponentsUtil.types)
local stripProps = require(StudioComponentsUtil.stripProps)
local Scope = Fusion.scoped(Fusion)

-- Types Extended
type LabelProperties = {
	Enabled: (boolean | types.StateObject<boolean>)?,
	[any]: any,
}

return function(props: LabelProperties): TextLabel
	local isEnabled = getState(props.Enabled, true)
	local textSize = props.TextSize or constants.TextSize * 1.3

	local newLabel = Scope:New "TextLabel" {
		Name = "Label",
		Position = UDim2.fromScale(0, 0),
		AnchorPoint = Vector2.new(0, 0),

		Size = Scope:Computed(function(use)
			return UDim2.new(1, 0, 0, unwrap(textSize, use))
		end),

		Text = "Label",
		Font = themeProvider:GetFont("Bold"),

		TextColor3 = props.TextColor3 or themeProvider:GetColor(props.TextColorStyle or Enum.StudioStyleGuideColor.MainText, Scope:Computed(function(use)
			if not unwrap(isEnabled, use) then
				return Enum.StudioStyleGuideModifier.Disabled
			end
			return Enum.StudioStyleGuideModifier.Default
		end)),

		TextSize = textSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		BorderMode = Enum.BorderMode.Inset,
	}

	local hydrateProps = stripProps(props, COMPONENT_ONLY_PROPERTIES)
	return Scope:Hydrate(newLabel)(hydrateProps)
end

-- Roact version by @sircfenner
-- Ported to Fusion by @YasuYoshida
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
local getMotionState = require(StudioComponentsUtil.getMotionState)
local themeProvider = require(StudioComponentsUtil.themeProvider)
local getModifier = require(StudioComponentsUtil.getModifier)
local stripProps = require(StudioComponentsUtil.stripProps)
local constants = require(StudioComponentsUtil.constants)
local getState = require(StudioComponentsUtil.getState)
local unwrap = require(StudioComponentsUtil.unwrap)
local types = require(StudioComponentsUtil.types)
local Scope = Fusion.scoped(Fusion)

-- Types Extended
type LabelProperties = {
	Enabled: (boolean | types.StateObject<boolean>)?,
	[any]: any,
}

return function(props: LabelProperties): TextLabel
	local isEnabled = getState(props.Enabled, true)
	local textSize = props.TextSize or constants.TextSize

	local mainModifier = getModifier({
		Enabled = isEnabled
	})

	local newLabel = Scope:New "TextLabel" {
		Name = "Label",
		Position = UDim2.fromScale(0, 0),
		AnchorPoint = Vector2.new(0, 0),

		Size = Scope:Computed(function(use)
			return UDim2.new(1, 0, 0, unwrap(textSize, use))
		end),

		Text = "Label",
		Font = themeProvider:GetFont("Default"),
		TextColor3 = props.TextColor3 or getMotionState(themeProvider:GetColor(props.TextColorStyle or Enum.StudioStyleGuideColor.MainText, mainModifier), "Spring", 40),
		TextSize = textSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		BorderMode = Enum.BorderMode.Inset,
	}

	local hydrateProps = stripProps(props, COMPONENT_ONLY_PROPERTIES)
	return Scope:Hydrate(newLabel)(hydrateProps)
end

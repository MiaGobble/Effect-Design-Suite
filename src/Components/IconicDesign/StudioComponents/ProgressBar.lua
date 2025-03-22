-- Written by @boatbomber
-- Modified by @iGottic

-- Constants
local COMPONENT_ONLY_PROPERTIES = {
	"Progress",
}

-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local StudioComponents = script.Parent
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local getMotionState = require(StudioComponentsUtil.getMotionState)
local themeProvider = require(StudioComponentsUtil.themeProvider)
local stripProps = require(StudioComponentsUtil.stripProps)
local constants = require(StudioComponentsUtil.constants)
local unwrap = require(StudioComponentsUtil.unwrap)
local types = require(StudioComponentsUtil.types)
local Scope = Fusion.scoped(Fusion)
local Children = Fusion.Children

-- Types Extended
type ProgressProperties = {
	Progress: (number | types.StateObject<number>)?,
	[any]: any,
}

return function(props: ProgressProperties): Frame
	local frame = Scope:New "Frame" {
		Name = "Loading",
		BackgroundColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.ScrollBarBackground),
		Size = UDim2.new(0,constants.TextSize*6, 0, constants.TextSize),
		ClipsDescendants = true,

		[Children] = {
			Scope:New "UICorner" {
				CornerRadius = constants.CornerRadius,
			},

			Scope:New "Frame" {
				Name = "Fill",
				BackgroundColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.DialogMainButton),

				Size = getMotionState(Scope:Computed(function(use)
					return UDim2.fromScale(unwrap(props.Progress, use), 1)
				end), "Spring", 40),

				[Children] = {
					Scope:New "UICorner" {
						CornerRadius = constants.CornerRadius,
					},
				}
			},
		}
	}

    local hydrateProps = stripProps(props, COMPONENT_ONLY_PROPERTIES)
    return Scope:Hydrate(frame)(hydrateProps)
end

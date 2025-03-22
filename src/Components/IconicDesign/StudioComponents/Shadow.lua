-- Written by @boatbomber
-- Modified by @iGottic

-- Types
type ShadowProperties = {
    Side: string,
	Transparency: number?,
	[any]: any,
}

-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local StudioComponents = script.Parent
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local themeProvider = require(StudioComponentsUtil.themeProvider)
local constants = require(StudioComponentsUtil.constants)
local unwrap = require(StudioComponentsUtil.unwrap)
local Scope = Fusion.scoped(Fusion)

local SideData = {
	top = {
		image = "rbxassetid://6528009956",
		size = UDim2.new(1, 0, 0, constants.TextSize),
		position = UDim2.new(0, 0, 0, 0),
		anchorPoint = Vector2.new(0, 1),
	},

	bottom = {
		image = "rbxassetid://6185927567",
		size = UDim2.new(1, 0, 0, constants.TextSize),
		position = UDim2.new(0, 0, 1, 0),
		anchorPoint = Vector2.new(0, 0),
	},

	left = {
		image = "rbxassetid://6978297327",
		size = UDim2.new(0, constants.TextSize, 1, 0),
		position = UDim2.new(0, 0, 0, 0),
		anchorPoint = Vector2.new(1, 0),
	},

	right = {
		image = "rbxassetid://6441569774",
		size = UDim2.new(0, constants.TextSize, 1, 0),
		position = UDim2.new(1, 0, 0, 0),
		anchorPoint = Vector2.new(0, 0),
	},
}


return function(props: ShadowProperties): Frame
	return Scope:New "ImageLabel" { -- Shadow
		Name = "Shadow",
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 10000,

		ImageTransparency = Scope:Computed(function(use)
			if not unwrap(themeProvider.IsDark, use)then
				-- Softer shadows on light themes
				return ((props.Transparency or 0) * 0.55) + 0.45
			else
				return props.Transparency or 0
			end
		end),

		Image = Scope:Computed(function(use)
			local Side = SideData[string.lower(unwrap(props.Side, use) or "right")]

			return Side.image
		end),

		Size = Scope:Computed(function(use)
			local Side = SideData[string.lower(unwrap(props.Side, use) or "right")]

			return Side.size
		end),

		Position = Scope:Computed(function(use)
			local Side = SideData[string.lower(unwrap(props.Side, use) or "right")]

			return Side.position
		end),

		AnchorPoint = Scope:Computed(function(use)
			local Side = SideData[string.lower(unwrap(props.Side, use) or "right")]

			return Side.anchorPoint
		end),
	}
end

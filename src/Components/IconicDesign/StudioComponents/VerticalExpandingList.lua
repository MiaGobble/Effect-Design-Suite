-- Roact version by @sircfenner
-- Ported to Fusion by @YasuYoshida
-- Modified by iGottic

-- Constants
local COMPONENT_ONLY_PROPERTIES = {
	"Padding",
	"AutomaticSize",
}


-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local StudioComponents = script.Parent
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local Background = require(StudioComponents.Background)
local BoxBorder = require(StudioComponents.BoxBorder)
local getMotionState = require(StudioComponentsUtil.getMotionState)
local stripProps = require(StudioComponentsUtil.stripProps)
local unwrap = require(StudioComponentsUtil.unwrap)
local types = require(StudioComponentsUtil.types)
local Scope = Fusion.scoped(Fusion)
local Children = Fusion.Children
local Out = Fusion.Out

-- Types Extended
type VerticalExpandingListProperties = {
	Padding: (UDim | types.StateObject<UDim>)?,
	[any]: any,
}

return function(props: VerticalExpandingListProperties): Frame
	local hydrateProps = stripProps(props, COMPONENT_ONLY_PROPERTIES)

	local contentSize = Scope:Value(Vector2.new(0, 0))

	return Scope:Hydrate(
		BoxBorder {
			[Children] = Background {
				ClipsDescendants = true,

				Size = getMotionState(Scope:Computed(function(use)
					local mode = unwrap(props.AutomaticSize or Enum.AutomaticSize.Y, use) -- Custom autosize since engine sizing is unreliable

					if mode == Enum.AutomaticSize.Y then
						local s = unwrap(contentSize, use)
						if s then
							return UDim2.new(1,0,0,s.Y)
						else
							return UDim2.new(1,0,0,0)
						end
					else
						return props.Size or UDim2.new(1,0,0,0)
					end
				end), "Spring", 40),

				[Children] = Scope:New "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Vertical,

					Padding = Scope:Computed(function(use)
						return unwrap(props.Padding, use) or UDim.new(0, 10)
					end),

					[Out "AbsoluteContentSize"] = contentSize,
				}
			}
		}
	)(hydrateProps)
end
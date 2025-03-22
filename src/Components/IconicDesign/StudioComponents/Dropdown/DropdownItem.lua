
-- Modified by @iGottic

-- Constants
local COMPONENT_ONLY_PROPERTIES = {
	"OnSelected",
	"Enabled",
	"Item"
}

-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local StudioComponents = script.Parent.Parent
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local themeProvider = require(StudioComponentsUtil.themeProvider)
local getModifier = require(StudioComponentsUtil.getModifier)
local constants = require(StudioComponentsUtil.constants)
local getState = require(StudioComponentsUtil.getState)
local unwrap = require(StudioComponentsUtil.unwrap)
local dropdownConstants = require(script.Parent.Constants)
local Scope = Fusion.scoped(Fusion)
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

-- Types Extended
type DropdownItemProperties = {
	OnSelected: ((selectedOption: any) -> nil),
	Item: any,
	[any]: any,
}

return function(props: DropdownItemProperties): TextButton
	local isEnabled = getState(props.Enabled, true)
	local isHovering = Scope:Value(false)

	local modifier = getModifier({
		Enabled = isEnabled,
		Hovering = isHovering,
	})
	
	local newDropdownItem = Scope:New "TextButton" {
		AutoButtonColor = false,
		Name = "DropdownItem",
		Size = UDim2.new(1, 0, 0, 15),
		BackgroundColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.EmulatorBar, modifier),
		BorderSizePixel = 0,
		Font = themeProvider:GetFont("Default"),
		Text = tostring(props.Item),
		TextSize = constants.TextSize,
		TextColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText, modifier),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		
		[OnEvent "InputBegan"] = function(inputObject)
			if not unwrap(isEnabled) then
				return
			elseif inputObject.UserInputType == Enum.UserInputType.MouseMovement then
				isHovering:set(true)
			end
		end,

		[OnEvent "InputEnded"] = function(inputObject)
			if not unwrap(isEnabled) then
				return
			elseif inputObject.UserInputType == Enum.UserInputType.MouseMovement then
				isHovering:set(false)
			end
		end,

		[OnEvent "Activated"] = function()
			props.OnSelected(props.Item)
		end,
		
		[Children] = {
			Scope:New "UIPadding" {
				PaddingLeft = UDim.new(0, dropdownConstants.TextPaddingLeft - 1),
				PaddingRight = UDim.new(0, dropdownConstants.TextPaddingRight),
			},

			Scope:Computed(function(use)
				if unwrap(constants.CurvedBoxes, use) then
					return Scope:New "UICorner" {
						CornerRadius = constants.CornerRadius
					}
				end
			end)
		}
	}
	
	local hydrateProps = table.clone(props)
	
	for _,propertyIndex in pairs(COMPONENT_ONLY_PROPERTIES) do
		hydrateProps[propertyIndex] = nil
	end
	
	return Scope:Hydrate(newDropdownItem)(hydrateProps)
end
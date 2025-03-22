local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))

local Scope = Fusion.scoped(Fusion)

local unwrap = require(script.Parent.unwrap)
local types = require(script.Parent.types)

type modifierInput = {
	Enabled: types.CanBeState<boolean>?,
	Hovering: types.CanBeState<boolean>?,
	Selected: types.CanBeState<boolean>?,
	Pressed: types.CanBeState<boolean>?,
	Otherwise: types.CanBeState<Enum.StudioStyleGuideModifier>?,
}

return function(modifierInput: modifierInput): types.Computed<any>
	local isEnabled = modifierInput.Enabled
	local isHovering = modifierInput.Hovering
	local isSelected = modifierInput.Selected
	local isPressed = modifierInput.Pressed

	return Scope:Computed(function(use)
		local isDisabled = not unwrap(isEnabled, use)
		local isHovering = unwrap(isHovering, use)
		local isSelected = unwrap(isSelected, use)
		local isPressed = unwrap(isPressed, use)

		if isDisabled then
			return Enum.StudioStyleGuideModifier.Disabled
		elseif isSelected then
			return Enum.StudioStyleGuideModifier.Selected
		elseif isPressed then
			return Enum.StudioStyleGuideModifier.Pressed
		elseif isHovering then
			return Enum.StudioStyleGuideModifier.Hover
		end

		return unwrap(modifierInput.Otherwise, use) or Enum.StudioStyleGuideModifier.Default
	end)
end
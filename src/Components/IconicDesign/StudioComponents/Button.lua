-- Modified by @iGottic

-- Imports
local StudioComponents = script.Parent
local BaseButton = require(StudioComponents.BaseButton)

-- Types Extended
export type ButtonProperties = BaseButton.BaseButtonProperties

return function(props: ButtonProperties): TextButton
	if not props.Name then
		props.Name = "Button"
	end

	local newButton = BaseButton(props)
	return newButton
end

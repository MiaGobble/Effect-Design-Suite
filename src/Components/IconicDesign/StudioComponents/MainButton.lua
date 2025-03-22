-- Roact version by @sircfenner
-- Ported to Fusion by @YasuYoshida
-- Modified by @iGottic

-- Constants
local BASE_PROPERTIES = {
	TextColorStyle = Enum.StudioStyleGuideColor.DialogMainButtonText,
	BackgroundColorStyle = Enum.StudioStyleGuideColor.DialogMainButton,
	BorderColorStyle = Enum.StudioStyleGuideColor.ButtonBorder,
	Name = "MainButton",
}

-- Imports
local StudioComponents = script.Parent
local Button = require(StudioComponents.Button)

return function(props: Button.ButtonProperties): TextButton
	for index,value in pairs(BASE_PROPERTIES) do
		if props[index]==nil then
			props[index] = value
		end
	end
	
	return Button(props)
end
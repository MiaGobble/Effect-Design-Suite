-- Constants
local COMPONENT_ONLY_PROPERTIES = {
	"Id",
	"InitialDockTo",
	"InitialEnabled",
	"ForceInitialEnabled",
	"FloatingSize",
	"MinimumSize",
	"Plugin"
}

-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local Scope = Fusion.scoped(Fusion)

-- Types Extended
type PluginGuiProperties = {
	Id: string,
	Name: string,
	InitialDockTo: string | Enum.InitialDockState,
	InitialEnabled: boolean,
	ForceInitialEnabled: boolean,
	FloatingSize: Vector2,
	MinimumSize: Vector2,
	[any]: any,
}

return function(props: PluginGuiProperties)	
	local newWidget = Plugin:CreateDockWidgetPluginGui(
		props.Id, 

		DockWidgetPluginGuiInfo.new(
			if typeof(props.InitialDockTo) == "string" then Enum.InitialDockState[props.InitialDockTo] else props.InitialDockTo,
			props.InitialEnabled,
			props.ForceInitialEnabled,
			props.FloatingSize.X, props.FloatingSize.Y,
			props.MinimumSize.X, props.MinimumSize.Y
		)
	)

	for _,propertyName in pairs(COMPONENT_ONLY_PROPERTIES) do
		props[propertyName] = nil
	end

	props.Title = props.Name
	
	if typeof(props.Enabled)=="table" and props.Enabled.kind=="Value" then
		props.Enabled:set(newWidget.Enabled)
	end

	return Scope:Hydrate(newWidget)(props)
end
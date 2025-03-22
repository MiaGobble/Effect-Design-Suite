-- Types
type ToolbarProperties = {
	Name: string,
	[any]: any,
}

-- Constants
local COMPONENT_ONLY_PROPERTIES = {
	"Name",
}

-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local Scope = Fusion.scoped(Fusion)

return function(props: ToolbarProperties): PluginToolbar
	local newToolbar = Plugin:CreateToolbar(props.Name)

	local hydrateProps = table.clone(props)
	for _,propertyName in pairs(COMPONENT_ONLY_PROPERTIES) do
		hydrateProps[propertyName] = nil
	end

	return Scope:Hydrate(newToolbar)(hydrateProps)
end

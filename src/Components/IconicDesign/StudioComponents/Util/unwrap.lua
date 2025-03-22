local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local Peek = Fusion.peek

return function(x: any, use : any?): any
	if typeof(x) == "table" and x.type == "State" then
		if use and typeof(use) == "function" then
			return use(x)
		else
			return Peek(x)
		end
	end
	
	return x
end
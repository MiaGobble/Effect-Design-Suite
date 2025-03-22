local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))

local Scope = Fusion.scoped(Fusion)

local unwrap = require(script.Parent.unwrap)
local types = require(script.Parent.types)

-- this technically could be changed later on in a way that
-- allows people to change whether this can be toggled
local isMotionEnabled = true

--motionStateTypes: Tween, Spring
return function(goalState: types.StateObject<any>, motionStateType: string, ...:any): types.CanBeState<any>
	local motionTypeFn = Scope[motionStateType]
	if typeof(motionTypeFn)~="function" then
		warn(("[%s]: No motionStateType with the name '%s' was found in Fusion!"):format(script.Name, tostring(motionStateType)))
		return goalState
	end
	
	local motionGoalState = motionTypeFn(Scope, goalState, ...)
	
	-- local isMotionEnabledAState = unwrap(isMotionEnabled)~=isMotionEnabled
	
	-- if isMotionEnabledAState then
	-- 	return Scope:Computed(function(use)
	-- 		if unwrap(isMotionEnabled, use) then
	-- 			return unwrap(motionGoalState, use)
	-- 		end

	-- 		return use(goalState)
	-- 	end)
	-- else
	-- 	return if isMotionEnabled then motionGoalState else goalState
	-- end

	return if isMotionEnabled then motionGoalState else goalState
end
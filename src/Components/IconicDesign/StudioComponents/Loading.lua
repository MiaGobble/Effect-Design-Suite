-- Written by @boatbomber
-- Modified by @iGottic

-- Constants
local COMPONENT_ONLY_PROPERTIES = {
	"Enabled",
}

-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local StudioComponents = script.Parent
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local getMotionState = require(StudioComponentsUtil.getMotionState)
local themeProvider = require(StudioComponentsUtil.themeProvider)
local stripProps = require(StudioComponentsUtil.stripProps)
local constants = require(StudioComponentsUtil.constants)
local getState = require(StudioComponentsUtil.getState)
local unwrap = require(StudioComponentsUtil.unwrap)
local types = require(StudioComponentsUtil.types)
local Scope = Fusion.scoped(Fusion)
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

-- Types Extended
type LoadingProperties = {
	Enabled: types.CanBeState<boolean>?,
	[any]: any,
}

return function(props: LoadingProperties): Frame
	local Scope = Scope:innerScope()
	local isEnabled = getState(props.Enabled, true)
	local timePassed = Scope:Value(0)

	local animThread = nil

	local function startMotion()
		if not unwrap(isEnabled) then return end

		if animThread then
			task.cancel(animThread)
			animThread = nil
		end

		animThread = task.defer(function()
			local startTime = os.clock()
			while unwrap(isEnabled) do
				timePassed:set(os.clock() - startTime)
				task.wait(1/25) -- Springs will smooth out the motion so we needn't bother with high refresh rate here
				-- TODO: iGottic wants to remove the task yield stuff
			end
		end)
	end

	startMotion()
	local observeDisconnect = Scope:Observer(isEnabled):onChange(startMotion)

	local function haltAnim()
		observeDisconnect()
		if animThread then
			task.cancel(animThread)
			animThread = nil
		end
	end

	local light = themeProvider:GetColor(Enum.StudioStyleGuideColor.Light, Enum.StudioStyleGuideModifier.Default)
	local accent = themeProvider:GetColor(Enum.StudioStyleGuideColor.DialogMainButton, Enum.StudioStyleGuideModifier.Default)

	local alphaA = Scope:Computed(function(use)
		local t = (unwrap(timePassed, use) + 0.25) * math.pi * 4
		return (math.cos(t) + 1) / 2
	end)

	local alphaB = Scope:Computed(function(use)
		local t = unwrap(timePassed, use) * math.pi * 4
		return (math.cos(t) + 1) / 2
	end)

	local colorA = getMotionState(Scope:Computed(function(use)
		return unwrap(light, use):Lerp(unwrap(accent, use), unwrap(alphaA, use))
	end), "Spring", 40)

	local colorB = getMotionState(Scope:Computed(function(use)
		return unwrap(light, use):Lerp(unwrap(accent, use), unwrap(alphaB, use))
	end), "Spring", 40)

	local sizeA = getMotionState(Scope:Computed(function(use)
		local alpha = unwrap(alphaA, use)
		return UDim2.fromScale(
			0.2,
			0.5 + alpha*0.5
		)
	end), "Spring", 40)

	local sizeB = getMotionState(Scope:Computed(function(use)
		local alpha = unwrap(alphaB, use)
		return UDim2.fromScale(
			0.2,
			0.5 + alpha*0.5
		)
	end), "Spring", 40)

	local frame; frame = Scope:New "Frame" {
		Name = "Loading",
		BackgroundTransparency = 1,
		Size = UDim2.new(0,constants.TextSize*4, 0,constants.TextSize*1.5),
		Visible = isEnabled,
		ClipsDescendants = true,

		[OnEvent "AncestryChanged"] = function()
			if not frame.Parent then
				Scope:doCleanup()
			end
		end,

		[Children] = {
			Scope:New "Frame" {
				Name = "Bar1",
				BackgroundColor3 = colorA,
				Size = sizeA,
				Position = UDim2.fromScale(0.02, 0.5),
				AnchorPoint = Vector2.new(0,0.5),
			},

			Scope:New "Frame" {
				Name = "Bar2",
				BackgroundColor3 = colorB,
				Size = sizeB,
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5,0.5),
			},

			Scope:New "Frame" {
				Name = "Bar3",
				BackgroundColor3 = colorA,
				Size = sizeA,
				Position = UDim2.fromScale(0.98, 0.5),
				AnchorPoint = Vector2.new(1,0.5),
			},
		}
	}

	table.insert(Scope, haltAnim)

	local hydrateProps = stripProps(props, COMPONENT_ONLY_PROPERTIES)
	return Scope:Hydrate(frame)(hydrateProps)
end

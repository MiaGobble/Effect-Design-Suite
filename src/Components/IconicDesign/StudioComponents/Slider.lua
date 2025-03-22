-- Roact version by @sircfenner
-- Ported to Fusion by @YasuYoshida
-- Modified by @iGottic

-- Constants
local COMPONENT_ONLY_PROPERTIES = {
	"ZIndex",
	"HandleSize",
	"OnChange",
	"Value",
	"Min",
	"Max",
	"Step",
	"Enabled",
}

-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local StudioComponents = script.Parent
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local BoxBorder = require(StudioComponents.BoxBorder)
local getMotionState = require(StudioComponentsUtil.getMotionState)
local themeProvider = require(StudioComponentsUtil.themeProvider)
local getDragInput = require(StudioComponentsUtil.getDragInput)
local getModifier = require(StudioComponentsUtil.getModifier)
local stripProps = require(StudioComponentsUtil.stripProps)
local getState = require(StudioComponentsUtil.getState)
local unwrap = require(StudioComponentsUtil.unwrap)
local types = require(StudioComponentsUtil.types)
local Scope = Fusion.scoped(Fusion)
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Out = Fusion.Out

-- Types Extended
type numberInput = types.CanBeState<number>?
type SliderProperties = {
	HandleSize: types.CanBeState<UDim2>?,
	Enabled: types.CanBeState<boolean>?,
	OnChange: ((newValue: number) -> nil)?,
	Value: types.CanBeState<number>?,
	Min: numberInput,
	Max: numberInput,
	Step: numberInput,
	[any]: any,
}

return function(props: SliderProperties): TextButton
	local Scope = Scope:innerScope()
	local isEnabled = getState(props.Enabled, true)
	local isHovering = Scope:Value(false)
	
	local handleSize = props.HandleOffsetSize or UDim2.new(0, 12, 1, -2)

	local handleRegion = Scope:Value()
	local inputValue = getState(props.Value, 1)
	local currentValue, currentAlpha, isDragging = getDragInput({
		Instance = handleRegion,
		Enabled = isEnabled,
		Value = Scope:Value(Vector2.new(unwrap(inputValue), 0)),

		Min = Scope:Computed(function(use)
			return Vector2.new(unwrap(props.Min, use) or 0, 0)
		end),

		Max = Scope:Computed(function(use)
			return Vector2.new(unwrap(props.Max, use) or 1, 0)
		end),

		Step = Scope:Computed(function(use)
			return Vector2.new(unwrap(props.Step, use) or -1, 0)
		end),

		OnChange = function(newValue: Vector2)
			if props.OnChange then
				props.OnChange(newValue.X)
			end
		end,
	})

	local cleanupDraggingObserver = Scope:Observer(isDragging):onChange(function()
		inputValue:set(unwrap(currentValue).X)
	end)

	local cleanupInputValueObserver = Scope:Observer(inputValue):onChange(function()
		currentValue:set(Vector2.new(unwrap(inputValue), 0))
	end)

	local function cleanupCallback()
		cleanupDraggingObserver()
		cleanupInputValueObserver()
	end

	local zIndex = Scope:Computed(function(use)
		return (unwrap(props.ZIndex, use) or 0) + 1
	end)

	local mainModifier = getModifier({
		Enabled = isEnabled,
	})
	
	local handleModifier = getModifier({
		Enabled = isEnabled,
		Selected = isDragging,
		Hovering = isHovering,
	})

	local handleFill = themeProvider:GetColor(Enum.StudioStyleGuideColor.Button)
	local handleBorder = themeProvider:GetColor(Enum.StudioStyleGuideColor.InputFieldBorder, handleModifier)
	local barAbsSize = Scope:Value(Vector2.zero)
	--local handleXAlpha = Scope:Value(Fusion.peek(currentAlpha))
	
	local newSlider = Scope:New "Frame" {
		Name = "Slider",
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = zIndex,
		BackgroundTransparency = 1,
		--[Cleanup] = cleanupCallback,

		[Children] = {
			BoxBorder {
				Color = themeProvider:GetColor(Enum.StudioStyleGuideColor.InputFieldBorder),
				CornerRadius = UDim.new(0, 1),
				
				[Children] = Scope:New "Frame" {
					Name = "Bar",
					ZIndex = zIndex,
					Position = UDim2.fromScale(.5, .5),
					AnchorPoint = Vector2.new(.5, .5),
					BorderSizePixel = 0,
					
					[Out "AbsoluteSize"] = barAbsSize,
					
					Size = Scope:Computed(function(use)
						local handleSize = unwrap(handleSize, use) or UDim2.new()
						return UDim2.new(1, -handleSize.X.Offset, 0, 5)
					end),

					BackgroundColor3 = getMotionState(themeProvider:GetColor(Enum.StudioStyleGuideColor.InputFieldBackground, mainModifier), "Spring", 40),

					BackgroundTransparency = getMotionState(Scope:Computed(function(use)
						return if not unwrap(isEnabled, use) then 0.4 else 0
					end), "Spring", 40),
				}
			},
			
			handleRegion:set(Scope:New "Frame" {
				Name = "HandleRegion",
				ZIndex = 1,
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				--[Ref] = handleRegion,

				[Children] = BoxBorder {
					Color =  getMotionState(Scope:Computed(function(use)
						return unwrap(handleBorder, use):Lerp(unwrap(handleFill, use), if not unwrap(isEnabled, use) then .5 else 0)
					end), "Spring", 40),

					[Children] = Scope:New "Frame" {
						Name = "Handle",
						BorderMode = Enum.BorderMode.Inset,
						BackgroundColor3 = handleFill,
						BorderSizePixel = 0,
						
						Size = handleSize,
						
						AnchorPoint = Vector2.new(.5, .5),

						-- Position = getMotionState(Scope:Computed(function(use)
						-- 	local handleSize = unwrap(handleSize, use) or UDim2.new()
						-- 	local absoluteBarSize = unwrap(barAbsSize, use) or Vector2.zero

						-- 	return UDim2.new(
						-- 		0, (unwrap(currentAlpha, use).X * absoluteBarSize.X) + handleSize.X.Offset/2,
						-- 		.5, 0
						-- 	)
						-- end), "Spring", 40),

						Position = Scope:Spring(Scope:Computed(function(use)
							local handleSize = unwrap(handleSize, use) or UDim2.new()
							local absoluteBarSize = unwrap(barAbsSize, use) or Vector2.zero
							
							return UDim2.new(
								0, (unwrap(currentAlpha, use).X * absoluteBarSize.X) + handleSize.X.Offset/2,
								.5, 0
							)
						end), 40),

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
					}
				}
			})
		}
	}

	-- table.insert(Scope, game:GetService("RunService").RenderStepped:Connect(function()
	-- 	if not newSlider.Parent then
	-- 		Scope:doCleanup()
	-- 		return
	-- 	end

	-- 	print(Fusion.peek(currentAlpha), Fusion.peek(handleXAlpha))
	-- 	handleXAlpha:set(Fusion.peek(currentAlpha))
	-- end))

	local hydrateProps = stripProps(props, COMPONENT_ONLY_PROPERTIES)
	return Scope:Hydrate(newSlider)(hydrateProps)
end
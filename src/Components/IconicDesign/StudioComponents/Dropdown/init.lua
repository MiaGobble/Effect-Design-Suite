-- Roact version by @sircfenner
-- Ported to Fusion by @YasuYoshida
-- Modified by @iGottic

-- Constants
local COMPONENT_ONLY_PROPERTIES = {
	"Enabled",
	"MaxVisibleItems",
	"Options",
	"Value",
	"ZIndex",
	"OnSelected",
	"Size",
}

-- Imports
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))
local StudioComponents = script.Parent
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local ScrollFrame = require(StudioComponents.ScrollFrame)
local BoxBorder = require(StudioComponents.BoxBorder)
local DropdownItem = require(script.DropdownItem)
local getSelectedState = require(StudioComponentsUtil.getSelectedState)
local getMotionState = require(StudioComponentsUtil.getMotionState)
local themeProvider = require(StudioComponentsUtil.themeProvider)
local getModifier = require(StudioComponentsUtil.getModifier)
local stripProps = require(StudioComponentsUtil.stripProps)
local constants = require(StudioComponentsUtil.constants)
local getState = require(StudioComponentsUtil.getState)
local unwrap = require(StudioComponentsUtil.unwrap)
local types = require(StudioComponentsUtil.types)
local dropdownConstants = require(script.Constants)
local Scope = Fusion.scoped(Fusion)
local Children = Fusion.Children
local OnChange = Fusion.OnChange
local OnEvent = Fusion.OnEvent
local Peek = Fusion.peek

-- Types Extended
type DropdownProperties = {
	Enabled: (boolean | types.StateObject<boolean>)?,
	Value: (any | types.Value<any>)?,
	Options: {any} | types.StateObject<{any}>,
	MaxVisibleItems: (number | types.StateObject<number>)?,
	OnSelected: (selectedOption: any) -> nil,
	[any]: any,
}

return function(props: DropdownProperties): Frame
	local Scope = Scope:innerScope()
	local isInputEnabled = getState(props.Enabled, true)
	local isHovering = Scope:Value(false)
	local isOpen = Scope:Value(false)
	
	local isEmpty = Scope:Computed(function(use)
		return next(unwrap(props.Options or {}, use))==nil
	end)

	local isEnabled = Scope:Computed(function(use)
		local isInputEnabled = unwrap(isInputEnabled, use)
		local isEmpty = unwrap(isEmpty, use)
		return isInputEnabled and not isEmpty
	end)

	local modifier = getModifier({
		Enabled = isEnabled,
		Hovering = isHovering,
	})

	local backgroundStyleGuideColor = Scope:Computed(function(use)
		local isHovering = unwrap(isHovering, use)
		local isOpen = unwrap(isOpen, use)

		if isOpen or isHovering then
			return Enum.StudioStyleGuideColor.InputFieldBackground
		end

		return Enum.StudioStyleGuideColor.MainBackground
	end)
	
	local disconnectGetSelectedState = nil

	local selectedOption, onSelectedOption do
		local inputValue = getState(props.Value, nil, "Value")

		onSelectedOption = function(selectedOption)
			if unwrap(inputValue) ~= selectedOption then
				task.defer(function() -- Fixes a false error from Fusion 0.3
					inputValue:set(selectedOption)
				end)
			else
				return
			end

			isOpen:set(false)

			if props.OnSelected then
				props.OnSelected(selectedOption)
			end
		end
		
		selectedOption = Scope:Computed(getSelectedState {
			Value = inputValue,
			Options = props.Options,
			OnSelected = onSelectedOption,
		})
		--just in case there's never a dependency for selectedOption
		--props.OnSelected should always be ran even if there isn't a dependency
		--disconnectGetSelectedState = Scope:Observer(selectedOption):onChange(function() end)
	end

	local spaceBetweenTopAndDropdown = 5
	local dropdownPadding = UDim.new(0, 2)

	local dropdownSize = Scope:Computed(function(use)
		local propsSize = unwrap(props.Size, use)
		return propsSize or UDim2.new(1, 0, 0, dropdownConstants.RowHeight)
	end)

	local absoluteDropdownSize = Scope:Value(UDim2.new())

	local dropdownItems = Scope:Computed(function(use)
		local itemList = {}
		local dropdownOptionList = unwrap(props.Options, use)

		if unwrap(isOpen, use) then
			for i, item in dropdownOptionList do
				itemList[i] = {
					OnSelected = onSelectedOption,

					Size = Scope:Computed(function(use)
						return UDim2.new(1, 0, 0, unwrap(absoluteDropdownSize, use).Y.Offset)
					end),

					LayoutOrder = i,
					Item = item,
				}
			end
		end

		return itemList
	end)

	local maxVisibleRows = Scope:Computed(function(use)
		return unwrap(props.MaxVisibleItems, use) or dropdownConstants.MaxVisibleRows
	end)

	local rowPadding = 1

	local scrollHeight = Scope:Computed(function(use)
		local itemSize = unwrap(absoluteDropdownSize, use)
		local visibleItems = math.min(unwrap(maxVisibleRows, use), #unwrap(dropdownItems, use))
		return visibleItems * (itemSize.Y.Offset) -- item heights
			+ (visibleItems - 1) * rowPadding -- row padding
			+ (dropdownPadding.Offset * 2) -- top and bottom
	end)

	local zIndex = Scope:Computed(function(use)
		return unwrap(props.ZIndex, use) or 5
	end)
	
	local function getOptionName(option, use)
		local option = unwrap(option, use)

		if typeof(option)=="table" and (option.Label or option.Name or option.Title) then
			return tostring(option.Label or option.Name or option.Title)
		elseif typeof(option)=="Instance" or typeof(option)=="EnumItem" then
			return option.Name
		end

		return tostring(option)
	end

	table.insert(Scope, disconnectGetSelectedState)

	local newDropdown = Scope:New "Frame" {
		Name = "Dropdown",
		Size = dropdownSize,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		
		--[Cleanup] = disconnectGetSelectedState,

		[OnEvent "InputBegan"] = function(inputObject)
			if not unwrap(isEnabled) then
				return
			elseif inputObject.UserInputType == Enum.UserInputType.MouseMovement then
				isHovering:set(true)
			elseif inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				isOpen:set(not unwrap(isOpen))
			end
		end,

		[OnEvent "InputEnded"] = function(inputObject)
			if not unwrap(isEnabled) then
				return
			elseif inputObject.UserInputType == Enum.UserInputType.MouseMovement then
				isHovering:set(false)
			end
		end,

		[OnChange "AbsoluteSize"] = function(newAbsoluteSize)
			absoluteDropdownSize:set(UDim2.fromOffset(newAbsoluteSize.X, newAbsoluteSize.Y))
		end, 

		[Children] = {
			-- this frame hides the dropdown if the mouse leaves it
			-- maybe this should be done with a mouse click instead
			-- but I don't know the cleanest way to do that right now
			Scope:New "Frame" {
				Name = "WholeDropdownInput",
				BackgroundTransparency = 1,

				Size = Scope:Computed(function(use)
					local topDropdownSize = unwrap(absoluteDropdownSize, use)
					local dropdownHeight = unwrap(scrollHeight, use)

					if topDropdownSize and dropdownHeight then
						local dropdownTotalHeight = topDropdownSize.Y.Offset + dropdownHeight + spaceBetweenTopAndDropdown
						return UDim2.fromOffset(topDropdownSize.X.Offset, dropdownTotalHeight)
					end

					return UDim2.new()
				end),

				[OnEvent "InputEnded"] = function(inputObject)
					if not unwrap(isOpen) then
						return
					elseif inputObject.UserInputType == Enum.UserInputType.MouseMovement then
						isOpen:set(false)
					end
				end,
			},

			BoxBorder {
				Color = themeProvider:GetColor(Enum.StudioStyleGuideColor.CheckedFieldBorder, modifier),

				[Children] = Scope:New "TextLabel" {
					Name = "Selected",
					Size = UDim2.fromScale(1, 1),
					TextSize = constants.TextSize,
					TextXAlignment = Enum.TextXAlignment.Left,

					BackgroundColor3 = getMotionState(themeProvider:GetColor(backgroundStyleGuideColor, modifier), "Spring", 40),
					TextColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText, modifier),
					Font = themeProvider:GetFont("Default"),
					Text = Scope:Computed(function(use)
						return getOptionName(selectedOption, use)
					end),

					[Children] = Scope:New "UIPadding" {
						PaddingLeft = UDim.new(0, dropdownConstants.TextPaddingLeft),
						PaddingRight = UDim.new(0, dropdownConstants.TextPaddingRight),
					}
				}
			},

			Scope:New "Frame" {
				Name = "ArrowContainer",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 18, 1, 0),
				BackgroundTransparency = 1,

				[Children] = Scope:New "ImageLabel" {
					Name = "Arrow",
					Image = "rbxassetid://7260137654",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(8, 4),
					BackgroundTransparency = 1,
					ImageColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.TitlebarText, modifier),
				}
			},
			
			BoxBorder {
				[Children] = ScrollFrame {
					ZIndex = zIndex,
					Name = "Drop",
					BorderSizePixel = 0,
					Visible = isOpen,
					Position = UDim2.new(0, 0, 1, spaceBetweenTopAndDropdown),

					Size = Scope:Computed(function(use)
						return UDim2.new(1, 0, 0, unwrap(scrollHeight, use))
					end),

					ScrollBarBorderMode = Enum.BorderMode.Outline,
					CanvasScaleConstraint = Enum.ScrollingDirection.X,

					UILayout = Scope:New "UIListLayout" {
						Padding = UDim.new(0, rowPadding),	
					},

					UIPadding = Scope:New "UIPadding" {
						PaddingLeft = dropdownPadding,
						PaddingRight = dropdownPadding,
						PaddingTop = dropdownPadding,
						PaddingBottom = dropdownPadding,
					},

					[Children] = Scope:ForValues(dropdownItems, function(use, _, props)
						props.ZIndex = unwrap(zIndex) + 1
						props.Text = getOptionName(props.Item)

						return DropdownItem(props)
					end),
				}
			}
			--end
			--return nil
			--end)
		},
	}

	return Scope:Hydrate(newDropdown)(stripProps(props, COMPONENT_ONLY_PROPERTIES))
end
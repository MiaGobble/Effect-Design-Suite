local types = require(script.Parent.types)

type styleStyleGuideColor = Enum.StudioStyleGuideColor | types.StateObject<Enum.StudioStyleGuideColor>
type styleGuideModifier = Enum.StudioStyleGuideModifier | types.StateObject<Enum.StudioStyleGuideModifier>
type computedOrValue = types.Computed<Color3> | types.Value<Color3>

local Studio = settings().Studio
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") or game
local Fusion = require(Plugin:FindFirstChild("Fusion", true))

local unwrap = require(script.Parent.unwrap)
local ThemeColors = require(script.ThemeColors)
local Scope = Fusion.scoped(Fusion)
local Peek = Fusion.peek

local currentTheme = {}
local themeProvider = {
	Theme = Scope:Value(Studio.Theme.Name),
	Fonts = {
		Default = Enum.Font.SourceSans,
		SemiBold = Enum.Font.SourceSansSemibold,
		Bold = Enum.Font.SourceSansBold,
		Black = Enum.Font.GothamBlack,
		Mono = Enum.Font.Code,
	},
	IsDark = Scope:Value(true),
}

local function GetCustomColor(studioStyleGuideColor: styleStyleGuideColor, studioStyleGuideModifier: styleGuideModifier?)
	local Palette = ThemeColors[studioStyleGuideColor]

	if not Palette then
		error(`Invalid palette: ${studioStyleGuideColor}`)
	end

	local Color = Palette[studioStyleGuideModifier] or Palette[Enum.StudioStyleGuideModifier.Default]

	if not Color then
		error(`Invalid color: ${studioStyleGuideColor} ${studioStyleGuideModifier}`)
	end

	return Color
end

function themeProvider:GetColor(studioStyleGuideColor: styleStyleGuideColor, studioStyleGuideModifier: styleGuideModifier?): computedOrValue
	local hasState = (unwrap(studioStyleGuideModifier) ~= studioStyleGuideModifier) or (unwrap(studioStyleGuideColor) ~= studioStyleGuideColor)

	local function isCorrectType(value, enumType)
		local unwrapped = unwrap(value)
		local isState = unwrapped ~= value and unwrapped~=nil
		assert((value==nil or isState) or (typeof(value)=="EnumItem" and value.EnumType==enumType), "Incorrect type")
	end

	isCorrectType(studioStyleGuideColor, Enum.StudioStyleGuideColor)
	isCorrectType(studioStyleGuideModifier, Enum.StudioStyleGuideModifier)

	local unwrappedColor = unwrap(studioStyleGuideColor)
	local unwrappedModifier = unwrap(studioStyleGuideModifier)

	if not currentTheme[unwrappedColor] then
		currentTheme[unwrappedColor] = {}
	end

	local themeValue = (function()
		local styleGuideModifier = if unwrappedModifier~=nil then unwrappedModifier else Enum.StudioStyleGuideModifier.Default

		local existingValue = currentTheme[unwrappedColor][styleGuideModifier]
		if existingValue then
			return existingValue
		end

		-- local newThemeValue = Scope:Value(Studio.Theme:GetColor(unwrappedColor, styleGuideModifier))
		local newThemeValue = Scope:Value(GetCustomColor(unwrappedColor, styleGuideModifier))
		currentTheme[unwrappedColor][styleGuideModifier] = newThemeValue

		-- do -- Debug
		-- 	local name = unwrappedColor.Name

		-- 	if styleGuideModifier then
		-- 		name = name.."_"..styleGuideModifier.Name
		-- 	end

		-- 	workspace:SetAttribute(name, Peek(newThemeValue))
		-- end

		return newThemeValue
	end)()

	return if not hasState then themeValue else Scope:Computed(function(use)
		local currentColor = unwrap(studioStyleGuideColor, use)
		local currentModifier = unwrap(studioStyleGuideModifier, use)
		local currentValueState = self:GetColor(currentColor, currentModifier)
		return Peek(currentValueState)
	end)
end

function themeProvider:GetFont(fontName: (string | types.StateObject<string>)?): types.Computed<Enum.Font>
	return Scope:Computed(function(use)
		local givenFontName = unwrap(fontName, use)
		local fontToGet = self.Fonts.Default
		if givenFontName~=nil and self.Fonts[givenFontName] then
			fontToGet = self.Fonts[givenFontName]
		end
		return unwrap(fontToGet, use)
	end)
end

local function updateTheme()
	for studioStyleGuideColor, styleGuideModifiers: {Enum.StudioStyleGuideModifier} in pairs(currentTheme) do
		for studioStyleGuideModifier, valueState in pairs(styleGuideModifiers) do
			valueState:set(Studio.Theme:GetColor(studioStyleGuideColor, studioStyleGuideModifier))
		end
	end
	themeProvider.Theme:set(Studio.Theme.Name)

	local _,_,v = Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground):ToHSV()
	themeProvider.IsDark:set(v<=0.6)
end

do
	local themeChangedConnection = Studio.ThemeChanged:Connect(updateTheme)
	updateTheme()

	if Plugin:IsA("Plugin") then
		Plugin.Unloading:Connect(function()
			themeChangedConnection:Disconnect()
			themeChangedConnection = nil
		end)
	else
		Plugin.AncestryChanged:Connect(function()
			if Plugin.Parent == nil then
				themeChangedConnection:Disconnect()
				themeChangedConnection = nil
			end
		end)
	end
end

return themeProvider

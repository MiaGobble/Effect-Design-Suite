-- local BRIGHTEST = Color3.fromRGB(255, 255, 255)
-- local BRIGHT_TEXT = Color3.fromRGB(229, 229, 229)
-- local BORDER_DEFAULT = Color3.fromRGB(34, 34, 34)
-- local MAIN_TEXT = Color3.fromRGB(204, 204, 204)
-- local DEFAULT_BUTTON = Color3.fromRGB(60, 60, 60)
-- local FIELD_BORDER_HOVER = DEFAULT_BUTTON
-- local FIELD_SELECTION = Color3.fromRGB(53, 255, 205)
-- local MAIN_BUTTON_DEFAULT = Color3.fromRGB(21, 193, 153)
-- local MAIN_BUTTON_HOVER = FIELD_SELECTION
-- local MAIN_BUTTON_PRESSED = Color3.fromRGB(0, 189, 129)
-- local DIALOGUE_MAIN_DISABLED = Color3.fromRGB(102, 102, 102)
-- local HEADER_SECTION_HOVER = Color3.fromRGB(72, 72, 72)
-- local TITLEBAR_TEXT = Color3.fromRGB(170, 170, 170)
-- local SCROLL_BAR_DEFAULT = DEFAULT_BUTTON
-- local SCROLL_BAR_DISABLED = HEADER_SECTION_HOVER
-- local MID_1 = DEFAULT_BUTTON
-- local MID_2 = SCROLL_BAR_DISABLED
-- local MID_3 = DEFAULT_BUTTON
-- local DARK_1 = Color3.fromRGB(41, 41, 41)
-- local DARK_2 = SCROLL_BAR_DEFAULT
-- local DARK_3 = BORDER_DEFAULT
-- local DARK_4 = Color3.fromRGB(26, 26, 26)
-- local DARK_5 = DARK_1

local BRIGHTEST = Color3.fromRGB(255, 255, 255)
local BRIGHT_TEXT = Color3.fromRGB(219, 240, 255)
local BORDER_DEFAULT = Color3.fromRGB(25, 34, 44)
local MAIN_TEXT = Color3.fromRGB(170, 180, 199)
local DEFAULT_BUTTON = Color3.fromRGB(45, 49, 62)
local FIELD_BORDER_HOVER = DEFAULT_BUTTON
local FIELD_SELECTION = Color3.fromRGB(53, 255, 205)
local MAIN_BUTTON_DEFAULT = Color3.fromRGB(21, 193, 153)
local MAIN_BUTTON_HOVER = FIELD_SELECTION
local MAIN_BUTTON_PRESSED = Color3.fromRGB(0, 189, 129)
local DIALOGUE_MAIN_DISABLED = Color3.fromRGB(107, 84, 84)
local HEADER_SECTION_HOVER = Color3.fromRGB(64, 72, 80)
local TITLEBAR_TEXT = Color3.fromRGB(143, 153, 169)
local SCROLL_BAR_DEFAULT = DEFAULT_BUTTON
local SCROLL_BAR_DISABLED = HEADER_SECTION_HOVER
local MID_1 = DEFAULT_BUTTON
local MID_2 = SCROLL_BAR_DISABLED
local MID_3 = DEFAULT_BUTTON
local DARK_1 = Color3.fromRGB(32, 34, 43)
local DARK_2 = SCROLL_BAR_DEFAULT
local DARK_3 = BORDER_DEFAULT
local DARK_4 = Color3.fromRGB(17, 20, 34)
local DARK_5 = DARK_1

return {
    [Enum.StudioStyleGuideColor.Border] = {
        [Enum.StudioStyleGuideModifier.Default] = BORDER_DEFAULT,
    },

    [Enum.StudioStyleGuideColor.BrightText] = {
        [Enum.StudioStyleGuideModifier.Default] = BRIGHT_TEXT,
        [Enum.StudioStyleGuideModifier.Disabled] = BRIGHT_TEXT,
        [Enum.StudioStyleGuideModifier.Hover] = BRIGHT_TEXT,
    },

    [Enum.StudioStyleGuideColor.Button] = {
        [Enum.StudioStyleGuideModifier.Default] = DEFAULT_BUTTON,
        [Enum.StudioStyleGuideModifier.Disabled] = DEFAULT_BUTTON,
        [Enum.StudioStyleGuideModifier.Hover] = MID_1,
        [Enum.StudioStyleGuideModifier.Pressed] = DARK_1,
    },

    [Enum.StudioStyleGuideColor.ButtonBorder] = {
        [Enum.StudioStyleGuideModifier.Default] = DARK_2,
        [Enum.StudioStyleGuideModifier.Disabled] = DARK_2,
        [Enum.StudioStyleGuideModifier.Hover] = DARK_2,
        [Enum.StudioStyleGuideModifier.Pressed] = DARK_2,
    },

    [Enum.StudioStyleGuideColor.ButtonText] = {
        [Enum.StudioStyleGuideModifier.Default] = MAIN_TEXT,
        [Enum.StudioStyleGuideModifier.Disabled] = MID_2,
        [Enum.StudioStyleGuideModifier.Hover] = MAIN_TEXT,
        [Enum.StudioStyleGuideModifier.Pressed] = MAIN_TEXT,
    },

    [Enum.StudioStyleGuideColor.CheckedFieldBackground] = {
        [Enum.StudioStyleGuideModifier.Default] = DARK_3,
        [Enum.StudioStyleGuideModifier.Disabled] = DARK_2,
        [Enum.StudioStyleGuideModifier.Hover] = DARK_3,
        [Enum.StudioStyleGuideModifier.Pressed] = DARK_4,
    },

    [Enum.StudioStyleGuideColor.CheckedFieldBorder] = {
        [Enum.StudioStyleGuideModifier.Default] = DARK_4,
        [Enum.StudioStyleGuideModifier.Disabled] = MID_3,
        [Enum.StudioStyleGuideModifier.Hover] = FIELD_BORDER_HOVER,
        [Enum.StudioStyleGuideModifier.Pressed] = DARK_4,
    },

    [Enum.StudioStyleGuideColor.CheckedFieldIndicator] = {
        [Enum.StudioStyleGuideModifier.Default] = FIELD_SELECTION,
    },

    [Enum.StudioStyleGuideColor.DialogMainButton] = {
        [Enum.StudioStyleGuideModifier.Default] = MAIN_BUTTON_DEFAULT,
        [Enum.StudioStyleGuideModifier.Disabled] = DEFAULT_BUTTON,
        [Enum.StudioStyleGuideModifier.Hover] = MAIN_BUTTON_HOVER,
        [Enum.StudioStyleGuideModifier.Pressed] = MAIN_BUTTON_PRESSED,
    },

    [Enum.StudioStyleGuideColor.DialogMainButtonText] = {
        [Enum.StudioStyleGuideModifier.Default] = BRIGHTEST,
        [Enum.StudioStyleGuideModifier.Disabled] = DIALOGUE_MAIN_DISABLED,
        [Enum.StudioStyleGuideModifier.Hover] = BRIGHTEST,
        [Enum.StudioStyleGuideModifier.Pressed] = BRIGHTEST,
    },

    [Enum.StudioStyleGuideColor.EmulatorBar] = {
        [Enum.StudioStyleGuideModifier.Default] = DARK_5,
        [Enum.StudioStyleGuideModifier.Hover] = DARK_3,
    },

    [Enum.StudioStyleGuideColor.HeaderSection] = {
        [Enum.StudioStyleGuideModifier.Default] = DARK_2,
        [Enum.StudioStyleGuideModifier.Disabled] = DARK_2,
        [Enum.StudioStyleGuideModifier.Hover] = HEADER_SECTION_HOVER,
    },

    [Enum.StudioStyleGuideColor.InputFieldBackground] = {
        [Enum.StudioStyleGuideModifier.Default] = DARK_3,
        [Enum.StudioStyleGuideModifier.Disabled] = DARK_2,
        [Enum.StudioStyleGuideModifier.Hover] = MID_1,
    },

    [Enum.StudioStyleGuideColor.InputFieldBorder] = {
        [Enum.StudioStyleGuideModifier.Default] = DARK_4,
        [Enum.StudioStyleGuideModifier.Disabled] = MID_1,
        [Enum.StudioStyleGuideModifier.Hover] = FIELD_BORDER_HOVER,
        [Enum.StudioStyleGuideModifier.Selected] = FIELD_SELECTION,
    },

    [Enum.StudioStyleGuideColor.Light] = {
        [Enum.StudioStyleGuideModifier.Default] = MID_3,
    },

    [Enum.StudioStyleGuideColor.MainBackground] = {
        [Enum.StudioStyleGuideModifier.Default] = DARK_5,
        [Enum.StudioStyleGuideModifier.Disabled] = DARK_5,
    },

    [Enum.StudioStyleGuideColor.MainText] = {
        [Enum.StudioStyleGuideModifier.Default] = MAIN_TEXT,
        [Enum.StudioStyleGuideModifier.Disabled] = MID_2,
        [Enum.StudioStyleGuideModifier.Hover] = BRIGHTEST,
    },

    [Enum.StudioStyleGuideColor.ScrollBar] = {
        [Enum.StudioStyleGuideModifier.Default] = SCROLL_BAR_DEFAULT,
        [Enum.StudioStyleGuideModifier.Disabled] = SCROLL_BAR_DISABLED,
    },

    [Enum.StudioStyleGuideColor.ScrollBarBackground] = {
        [Enum.StudioStyleGuideModifier.Default] = DARK_1,
    },

    [Enum.StudioStyleGuideColor.TitlebarText] = {
        [Enum.StudioStyleGuideModifier.Default] = TITLEBAR_TEXT,
        [Enum.StudioStyleGuideModifier.Disabled] = MID_2,
        [Enum.StudioStyleGuideModifier.Hover] = TITLEBAR_TEXT,
    },
}
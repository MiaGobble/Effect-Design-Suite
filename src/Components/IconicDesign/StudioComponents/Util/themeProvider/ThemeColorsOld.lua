local BORDER_DEFAULT = Color3.fromRGB(34, 34, 34)
local BRIGHT_TEXT = Color3.fromRGB(229, 229, 229)
local MAIN_TEXT = Color3.fromRGB(204, 204, 204)
local DEFAULT_BUTTON = Color3.fromRGB(60, 60, 60)
local FIELD_BORDER_HOVER = Color3.fromRGB(58, 58, 58)
local FIELD_SELECTION = Color3.fromRGB(53, 181, 255)
local MAIN_BUTTON_DEFAULT = Color3.fromRGB(0, 162, 255)
local MAIN_BUTTON_HOVER = Color3.fromRGB(50, 181, 255)
local MAIN_BUTTON_PRESSED = Color3.fromRGB(0, 116, 189)
local DIALOGUE_MAIN_DISABLED = Color3.fromRGB(102, 102, 102)
local BRIGHTEST = Color3.fromRGB(255, 255, 255)
local HEADER_SECTION_HOVER = Color3.fromRGB(72, 72, 72)
local TITLEBAR_TEXT = Color3.fromRGB(170, 170, 170)
local SCROLL_BAR_DEFAULT = Color3.fromRGB(56, 56, 56)
local SCROLL_BAR_DISABLED = Color3.fromRGB(70, 70, 70)
local MID_1 = Color3.fromRGB(66, 66, 66)
local MID_2 = Color3.fromRGB(85, 85, 85)
local MID_3 = Color3.fromRGB(64, 64, 64)
local DARK_1 = Color3.fromRGB(41, 41, 41)
local DARK_2 = Color3.fromRGB(53, 53, 53)
local DARK_3 = Color3.fromRGB(37, 37, 37)
local DARK_4 = Color3.fromRGB(26, 26, 26)
local DARK_5 = Color3.fromRGB(46, 46, 46)

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
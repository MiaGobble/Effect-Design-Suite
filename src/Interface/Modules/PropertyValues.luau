local PropertyValues = {}

local function SplitNumbers(text : string) : {number}
    local Numbers = {}

    for token in string.gmatch(text, "[^,;%s]+") do
        local Number = tonumber(token)
        if Number then
            table.insert(Numbers, Number)
        end
    end

    return Numbers
end

local FORMATTERS = {
    number = tostring,
    boolean = function(value)
        return if value then "true" else "false"
    end,
    string = function(value)
        return value
    end,
    Vector3 = function(value)
        return string.format("%s, %s, %s", tostring(value.X), tostring(value.Y), tostring(value.Z))
    end,
    Vector2 = function(value)
        return string.format("%s, %s", tostring(value.X), tostring(value.Y))
    end,
    NumberRange = function(value)
        return string.format("%s, %s", tostring(value.Min), tostring(value.Max))
    end,
    Color3 = function(value)
        return string.format("%d, %d, %d", math.round(value.R * 255), math.round(value.G * 255), math.round(value.B * 255))
    end,
    EnumItem = function(value)
        return value.Name
    end,
    CFrame = function(value)
        return table.concat({value:GetComponents()}, ", ")
    end,
    UDim = function(value)
        return string.format("%s, %s", tostring(value.Scale), tostring(value.Offset))
    end,
    UDim2 = function(value)
        return string.format(
            "%s, %s, %s, %s",
            tostring(value.X.Scale),
            tostring(value.X.Offset),
            tostring(value.Y.Scale),
            tostring(value.Y.Offset)
        )
    end,
    Rect = function(value)
        return string.format("%s, %s, %s, %s", tostring(value.Min.X), tostring(value.Min.Y), tostring(value.Max.X), tostring(value.Max.Y))
    end,
    BrickColor = function(value)
        return value.Name
    end,
    Instance = function(value)
        return value:GetFullName()
    end,
    NumberSequence = function()
        return "NumberSequence"
    end,
    ColorSequence = function()
        return "ColorSequence"
    end,
}

local PARSERS = {
    number = function(_currentValue, text)
        return tonumber(text)
    end,
    boolean = function(_currentValue, text)
        local Lower = string.lower(text)
        if Lower == "true" or Lower == "1" then
            return true
        elseif Lower == "false" or Lower == "0" then
            return false
        end

        return nil
    end,
    string = function(_currentValue, text)
        return text
    end,
    Vector3 = function(_currentValue, text)
        local Numbers = SplitNumbers(text)
        if #Numbers >= 3 then
            return Vector3.new(Numbers[1], Numbers[2], Numbers[3])
        elseif #Numbers == 1 then
            return Vector3.new(Numbers[1], Numbers[1], Numbers[1])
        end

        return nil
    end,
    Vector2 = function(_currentValue, text)
        local Numbers = SplitNumbers(text)
        if #Numbers >= 2 then
            return Vector2.new(Numbers[1], Numbers[2])
        end

        return nil
    end,
    NumberRange = function(_currentValue, text)
        local Numbers = SplitNumbers(text)
        if #Numbers >= 2 then
            return NumberRange.new(Numbers[1], Numbers[2])
        elseif #Numbers == 1 then
            return NumberRange.new(Numbers[1], Numbers[1])
        end

        return nil
    end,
    Color3 = function(_currentValue, text)
        local Numbers = SplitNumbers(text)
        if #Numbers < 3 then
            return nil
        end

        local Red, Green, Blue = Numbers[1], Numbers[2], Numbers[3]
        if Red > 1 or Green > 1 or Blue > 1 then
            return Color3.fromRGB(Red, Green, Blue)
        end

        return Color3.new(Red, Green, Blue)
    end,
    EnumItem = function(currentValue, text)
        local Success, Item = pcall(function()
            return currentValue.EnumType[text]
        end)
        if Success then
            return Item
        end

        return nil
    end,
    CFrame = function(_currentValue, text)
        local Numbers = SplitNumbers(text)
        if #Numbers >= 12 then
            return CFrame.new(table.unpack(Numbers, 1, 12))
        elseif #Numbers >= 3 then
            return CFrame.new(Numbers[1], Numbers[2], Numbers[3])
        end

        return nil
    end,
    UDim = function(_currentValue, text)
        local Numbers = SplitNumbers(text)
        if #Numbers >= 2 then
            return UDim.new(Numbers[1], Numbers[2])
        end

        return nil
    end,
    UDim2 = function(_currentValue, text)
        local Numbers = SplitNumbers(text)
        if #Numbers >= 4 then
            return UDim2.new(Numbers[1], Numbers[2], Numbers[3], Numbers[4])
        end

        return nil
    end,
    Rect = function(_currentValue, text)
        local Numbers = SplitNumbers(text)
        if #Numbers >= 4 then
            return Rect.new(Numbers[1], Numbers[2], Numbers[3], Numbers[4])
        end

        return nil
    end,
    BrickColor = function(_currentValue, text)
        local Number = tonumber(text)
        if Number then
            return BrickColor.new(Number)
        end

        local Success, Color = pcall(function()
            return BrickColor.new(text)
        end)
        if Success then
            return Color
        end

        return nil
    end,
}

function PropertyValues.SplitNumbers(text : string)
    return SplitNumbers(text)
end

function PropertyValues.Format(value) : string
    local Formatter = FORMATTERS[typeof(value)]
    if Formatter then
        return Formatter(value)
    end

    return tostring(value)
end

function PropertyValues.Parse(currentValue, text : string)
    local Parser = PARSERS[typeof(currentValue)]
    if Parser then
        return Parser(currentValue, text)
    end

    return nil
end

function PropertyValues.SampleNumberSequence(sequence : NumberSequence, time : number)
    local Keys = sequence.Keypoints
    if #Keys == 0 then
        return 0
    end

    if time <= Keys[1].Time then
        return Keys[1].Value
    end

    for index = 1, #Keys - 1 do
        local Start = Keys[index]
        local Finish = Keys[index + 1]
        if time <= Finish.Time then
            local Duration = Finish.Time - Start.Time
            local Alpha = if Duration <= 0 then 0 else (time - Start.Time) / Duration
            return Start.Value + (Finish.Value - Start.Value) * Alpha
        end
    end

    return Keys[#Keys].Value
end

function PropertyValues.GetNumberSequenceRange(sequence : NumberSequence)
    local MinValue = math.huge
    local MaxValue = -math.huge

    for _, keypoint in sequence.Keypoints do
        MinValue = math.min(MinValue, keypoint.Value)
        MaxValue = math.max(MaxValue, keypoint.Value)
    end

    if MinValue == math.huge then
        return 0, 1
    end

    if MaxValue <= MinValue then
        MaxValue = MinValue + 1
    end

    return MinValue, MaxValue
end

function PropertyValues.GetCFrameOrientationDegrees(cframe : CFrame)
    local Rx, Ry, Rz = cframe:ToOrientation()
    return Vector3.new(math.deg(Rx), math.deg(Ry), math.deg(Rz))
end

function PropertyValues.CFrameFromPositionAndOrientation(position : Vector3, orientation : Vector3)
    return CFrame.new(position) * CFrame.fromOrientation(math.rad(orientation.X), math.rad(orientation.Y), math.rad(orientation.Z))
end

function PropertyValues.GetCFrameComponentLabel(property : string, kind : string)
    if property == "CFrame" then
        return kind
    end

    return property .. " " .. kind
end

function PropertyValues.GetEnumItemNames(enumItem)
    local Names = {}
    for _, item in enumItem.EnumType:GetEnumItems() do
        table.insert(Names, item.Name)
    end
    return Names
end

function PropertyValues.ReadInstanceCFrame(instance, property)
    local ReadSuccess, Value = pcall(function()
        return instance[property]
    end)
    if ReadSuccess and typeof(Value) == "CFrame" then
        return Value
    end

    return CFrame.new()
end

function PropertyValues.GetCFrameComponentVector(instance, property, kind)
    local Current = PropertyValues.ReadInstanceCFrame(instance, property)
    if kind == "Orientation" then
        return PropertyValues.GetCFrameOrientationDegrees(Current)
    end

    return Current.Position
end

return PropertyValues

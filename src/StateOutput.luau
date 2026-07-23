local StateOutput = {}

-- Constants
local SAVED_STATES = {
    "RepeatEmitDelay"
}

local SETTING_INDEX_PRESET = "EffectDesignerSuiteSettings_"

-- Services
local HttpService = game:GetService("HttpService")

-- Imports
local Bin = script.Parent
local Objects = Bin:FindFirstChild("Objects")
local Packages = Bin:FindFirstChild("Packages")
local States = require(Objects:FindFirstChild("States"))
local Seam = require(Packages:FindFirstChild("Seam"))

-- Variables
local Plugin = script:FindFirstAncestorWhichIsA("Plugin") :: Plugin

local function DeepCopyTableAsPeeked(Table : {[any] : any})
    local Copy = {}

    for Key, Value in Table do
        if typeof(Value) == "table" then
            if Seam.IsState(Value) then
                Copy[Key] = Seam.GetValue(Value)
            else
                Copy[Key] = DeepCopyTableAsPeeked(Value)
            end
        else
            Copy[Key] = Value
        end
    end

    return Copy
end

local function DeepCopyTableAsStated(Table : {[any] : any})
    local Copy = {}

    for Key, Value in Table do
        if typeof(Value) == "table" then
            if Seam.IsState(Value) then
                Copy[Key] = Value
            else
                Copy[Key] = DeepCopyTableAsStated(Value)
            end
        else
            Copy[Key] = Value
        end
    end

    return Copy
end

local function GetUnprocessedValue(Index : string, Value : any?)
    local DefaultValue = Seam.GetValue(States[Index])

    if Value == nil then
        return DefaultValue
    end

    local Success, Decoded = pcall(function()
        if typeof(Value) ~= "string" then
            return Value
        end

        return HttpService:JSONDecode(Value)
    end)

    if Success then
        return Decoded
    end

    return Value
end

local function GetProcessedValue(_Index : string, Value : any?)
    if Value == nil then
        return
    end

    local RawValue = Seam.GetValue(Value)

    if typeof(RawValue) == "table" then
        local NewValue = DeepCopyTableAsPeeked(RawValue)
        local Encoded = HttpService:JSONEncode(NewValue)

        return Encoded
    end

    return RawValue
end

local function ProcessState(StateId : string, StateValue : any)
    local SavedSettingRawValue = Plugin:GetSetting(SETTING_INDEX_PRESET .. StateId)

    if SavedSettingRawValue ~= nil then
        local UnprocessedValue = GetUnprocessedValue(StateId, SavedSettingRawValue)

        if typeof(UnprocessedValue) == "table" then
            local NewValue = DeepCopyTableAsStated(UnprocessedValue)
            States[StateId].Value = NewValue
        else
            States[StateId].Value = UnprocessedValue
        end
    end

    Seam.OnChanged(StateValue, function()
        local NewValue = Seam.GetValue(StateValue)
        local ProcessedValue = GetProcessedValue(StateId, NewValue)

        Plugin:SetSetting(SETTING_INDEX_PRESET .. StateId, ProcessedValue)
    end)
end

function StateOutput:Init()
    for _, StateId  in SAVED_STATES do
        local StateValue = States[StateId]

        if not StateValue then
            warn("StateOutput:Init() - StateValue is nil for state: " .. StateId)
            continue
        end

        ProcessState(StateId, StateValue)
    end
end

return StateOutput
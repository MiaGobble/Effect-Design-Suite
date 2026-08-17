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

local function DeepCopyTableAsPeeked(sourceTable : {[any] : any})
    local Copy = {}

    for key, value in sourceTable do
        if typeof(value) == "table" then
            if Seam.IsState(value) then
                Copy[key] = Seam.GetValue(value)
            else
                Copy[key] = DeepCopyTableAsPeeked(value)
            end
        else
            Copy[key] = value
        end
    end

    return Copy
end

local function DeepCopyTableAsStated(sourceTable : {[any] : any})
    local Copy = {}

    for key, value in sourceTable do
        if typeof(value) == "table" then
            if Seam.IsState(value) then
                Copy[key] = value
            else
                Copy[key] = DeepCopyTableAsStated(value)
            end
        else
            Copy[key] = value
        end
    end

    return Copy
end

local function GetUnprocessedValue(index : string, value : any?)
    local DefaultValue = Seam.GetValue(States[index])

    if value == nil then
        return DefaultValue
    end

    local Success, Decoded = pcall(function()
        if typeof(value) ~= "string" then
            return value
        end

        return HttpService:JSONDecode(value)
    end)

    if Success then
        return Decoded
    end

    return value
end

local function GetProcessedValue(_Index : string, value : any?)
    if value == nil then
        return
    end

    local RawValue = Seam.GetValue(value)

    if typeof(RawValue) == "table" then
        local NewValue = DeepCopyTableAsPeeked(RawValue)
        local Encoded = HttpService:JSONEncode(NewValue)

        return Encoded
    end

    return RawValue
end

local function ProcessState(stateId : string, stateValue : any)
    local SavedSettingRawValue = Plugin:GetSetting(SETTING_INDEX_PRESET .. stateId)

    if SavedSettingRawValue ~= nil then
        local UnprocessedValue = GetUnprocessedValue(stateId, SavedSettingRawValue)

        if typeof(UnprocessedValue) == "table" then
            local NewValue = DeepCopyTableAsStated(UnprocessedValue)
            States[stateId].Value = NewValue
        else
            States[stateId].Value = UnprocessedValue
        end
    end

    Seam.OnChanged(stateValue, function()
        local NewValue = Seam.GetValue(stateValue)
        local ProcessedValue = GetProcessedValue(stateId, NewValue)

        Plugin:SetSetting(SETTING_INDEX_PRESET .. stateId, ProcessedValue)
    end)
end

function StateOutput:Init()
    for _, stateId  in SAVED_STATES do
        local StateValue = States[stateId]

        if not StateValue then
            warn(`StateOutput:Init() - StateValue is nil for state: {stateId} {debug.traceback()}`)
            continue
        end

        ProcessState(stateId, StateValue)
    end
end

return StateOutput
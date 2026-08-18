local ChangeHistory = {}

-- Services
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Variables
local RecordingDepth = 0

function ChangeHistory.Record(name : string, callback)
    local RecordingId = nil

    if RecordingDepth == 0 then
        pcall(function()
            RecordingId = ChangeHistoryService:TryBeginRecording(name)
        end)
    end

    RecordingDepth += 1
    local Success, Result = pcall(callback)
    RecordingDepth -= 1

    if RecordingId then
        local Operation = if Success then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
        pcall(function()
            ChangeHistoryService:FinishRecording(RecordingId, Operation)
        end)
    elseif RecordingDepth == 0 and Success then
        pcall(function()
            ChangeHistoryService:SetWaypoint(name)
        end)
    end

    if not Success then
        warn(`Effect Designer Suite could not apply "{name}". {Result} {debug.traceback()}`)
        return
    end

    return Result
end

return ChangeHistory

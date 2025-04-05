local EmitUtils = {}

-- Services
local RunService = game:GetService("RunService")

-- Imports
local Bin = script.Parent.Parent
local Objects = Bin:FindFirstChild("Objects")
local Packages = Bin:FindFirstChild("Packages")
local PlayEffect = require(Bin.PlaybackModules:FindFirstChild("PlayEffect"))
local States = require(Objects:FindFirstChild("States"))
local Fusion = require(Packages:FindFirstChild("Fusion"))
local Peek = Fusion.peek

-- Variables
local RepeatEmitConnection = nil
local Widget = nil

function EmitUtils:SetWidget(...)
    Widget = ...
end

function EmitUtils:EmitCurrent(ForcedInstances : {Instance}?)
    if not Peek(States.IsEmittable) and not ForcedInstances then
        return
    end

    local SelectedInstances = ForcedInstances or Peek(States.CurrentlySelected)

    for _, Instance in SelectedInstances do
        local _, WidgetParentPayload = PlayEffect(Instance, true)

        if WidgetParentPayload then
            for _, Payload in WidgetParentPayload do
                local Object = Payload[1]
                local TotalDuration = Payload[2]

                Object.Parent = Widget

                task.delay(TotalDuration, function()
                    Object:Destroy()
                end)
            end
        end
    end
end

function EmitUtils:EnableRepeatEmit()
    if RepeatEmitConnection then
        return
    end

    local LastEmit = 0
    local LastSelectedInstances = nil

    RepeatEmitConnection = RunService.Heartbeat:Connect(function()
        local Delta = os.clock() - LastEmit
        local RepeatEmitDelay = Peek(States.RepeatEmitDelay)

        if RepeatEmitDelay <= 0 then
            return
        end

        if Delta < RepeatEmitDelay then
            return
        end

        if Peek(States.CurrentlySelected) and #Peek(States.CurrentlySelected) > 0 then
            LastSelectedInstances = Peek(States.CurrentlySelected)
        end

        LastEmit = os.clock()
        EmitUtils:EmitCurrent(LastSelectedInstances)
    end)
end

function EmitUtils:DisableRepeatEmit()
    if not RepeatEmitConnection then
        return
    end

    RepeatEmitConnection:Disconnect()
    RepeatEmitConnection = nil
end

function EmitUtils:CreateNewAnimationIndicator(Parent : Instance, Type : string)
    if Parent:FindFirstChild("AnimationIndicator") then
        return Parent:FindFirstChild("AnimationIndicator")
    end

    local AnimationIndicator = Instance.new("StringValue")
    AnimationIndicator.Name = "AnimationIndicator"
    AnimationIndicator.Value = Type
    AnimationIndicator.Parent = Parent

    local DelayTime = Instance.new("NumberValue")
    DelayTime.Name = "DelayTime"
    DelayTime.Value = 0
    DelayTime.Parent = AnimationIndicator

    local Duration = Instance.new("NumberValue")
    Duration.Name = "Duration"
    Duration.Value = 1
    Duration.Parent = AnimationIndicator

    local Reverses = Instance.new("BoolValue")
    Reverses.Name = "Reverses"
    Reverses.Value = false
    Reverses.Parent = AnimationIndicator

    local RepeatCount = Instance.new("NumberValue")
    RepeatCount.Name = "RepeatCount"
    RepeatCount.Value = 0
    RepeatCount.Parent = AnimationIndicator
    
    local TweenDirection = Instance.new("StringValue")
    TweenDirection.Name = "TweenDirection"
    TweenDirection.Value = "Out"
    TweenDirection.Parent = AnimationIndicator

    local TweenStyle = Instance.new("StringValue")
    TweenStyle.Name = "TweenStyle"
    TweenStyle.Value = "Linear"
    TweenStyle.Parent = AnimationIndicator

    if not Parent:FindFirstChild("Mover") then
        local Mover = Instance.new("Attachment")
        Mover.Name = "Mover"
        Mover.Parent = Parent
    end

    if not Parent:FindFirstChild("Origin") then
        local Origin = Instance.new("Attachment")
        Origin.Name = "Origin"
        Origin.Parent = Parent
    end

    if not Parent:FindFirstChild("Target") then
        local Target = Instance.new("Attachment")
        Target.Name = "Target"
        Target.Parent = Parent
    end
    
    if not Parent:FindFirstChild("Midpoint1") and Type == "Bezier" then
        local Midpoint1 = Instance.new("Attachment")
        Midpoint1.Name = "Midpoint1"
        Midpoint1.Parent = Parent
    end

    return AnimationIndicator
end

return EmitUtils
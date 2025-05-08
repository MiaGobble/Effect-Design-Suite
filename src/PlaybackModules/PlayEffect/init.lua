--[[
    Written by @iGottic

    This module returns a single function used to play a visual effect in runtime created by Effect Designer Suite.
    You can pass in a bin of effect objects or a single effect object.
    An effect object can be a module, a particle emitter, a sound, or etc supported by Effect Designer Suite.
    
    Returns the total duration of the effect as a number.

    API:
        PlayEffect : (Bin : Instance) -> number
    
    Example:
        local PlayEffect = require(ReplicatedStorage.Common.PlayEffect)
        local EmitDuration = PlayEffect(EffectAttachment)
--]]

-- Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Imports
local Bezier = require(script:FindFirstChild("Bezier"))

-- Variables
local ActiveTasks = {}

-- Get time from tween info
local function GetTimeFromTweenInfo(TweenInfo : TweenInfo)
    local Duration = TweenInfo.Time
    local Delay = TweenInfo.DelayTime

    if TweenInfo.Reverses then
        Duration *= 2
    end
    
    if TweenInfo.RepeatCount > 0 then
        Duration *= (TweenInfo.RepeatCount + 1)
    end

    return Duration + Delay
end

-- Helper function to calculate distance-based volume
local function CalculateVolume(Sound: Sound, ParentInstance: Instance): number
    -- Return 1 if not using plugin
    if RunService:IsRunning() then
        return 1
    end

    local Camera = workspace.CurrentCamera
    if not Camera then return 1 end
    
    local ParentPosition = if ParentInstance:IsA("Attachment") 
        then ParentInstance.WorldPosition 
        else ParentInstance.Position
    
    local Distance = (ParentPosition - Camera.CFrame.Position).Magnitude
    
    -- Get rolloff properties from sound
    local MinDistance = Sound.RollOffMinDistance
    local MaxDistance = Sound.RollOffMaxDistance
    local RolloffMode = Sound.RollOffMode

    -- Calculate volume based on distance and rolloff mode
    if Distance <= MinDistance then
        return 1
    elseif Distance >= MaxDistance then
        return 0
    end
    
    local Volume
    
    if RolloffMode == Enum.RollOffMode.Linear then
        Volume = 1 - ((Distance - MinDistance) / (MaxDistance - MinDistance))
    elseif RolloffMode == Enum.RollOffMode.Inverse then
        Volume = math.clamp(MinDistance / math.max(Distance, MinDistance), 0, 1)
    else -- Default to linear
        Volume = 1 - ((Distance - MinDistance) / (MaxDistance - MinDistance))
    end
    
    return Volume
end

-- Function to animate tweens
local function AnimateTween(ParentAttachment : Attachment)
    local Mover = ParentAttachment:FindFirstChild("Mover")

    if not Mover then
        return
    end

    local Origin = ParentAttachment:FindFirstChild("Origin")

    if not Origin then
        return
    end

    local Target = ParentAttachment:FindFirstChild("Target")

    if not Target then
        return
    end
    
    local AnimationIndicator = ParentAttachment:FindFirstChild("AnimationIndicator")

    if not AnimationIndicator then
        return
    end

    local TweenStyle = TweenInfo.new(
        AnimationIndicator.Duration.Value,
        Enum.EasingStyle[AnimationIndicator.TweenStyle.Value],
        Enum.EasingDirection[AnimationIndicator.TweenDirection.Value],
        AnimationIndicator.RepeatCount.Value,
        AnimationIndicator.Reverses.Value,
        AnimationIndicator.DelayTime.Value
    )

    local Tween = TweenService:Create(Mover, TweenStyle, {
        CFrame = Target.CFrame
    })

    Mover.CFrame = Origin.CFrame
    Tween:Play()

    return GetTimeFromTweenInfo(TweenStyle)
end

-- Function to animate bezier tweens
local function AnimateBezier(ParentAttachment : Attachment)
    local Mover = ParentAttachment:FindFirstChild("Mover")

    if not Mover then
        return
    end

    local Origin = ParentAttachment:FindFirstChild("Origin")

    if not Origin then
        return
    end
    
    local Target = ParentAttachment:FindFirstChild("Target")

    if not Target then
        return
    end

    local Midpoints = {ParentAttachment:FindFirstChild("Midpoint")}

    for _, Midpoint in ParentAttachment:GetChildren() do
        if not Midpoint:IsA("Attachment") then
            continue
        end

        local MidpointIndex = Midpoint.Name:gsub("Midpoint", "")

        if MidpointIndex and tonumber(MidpointIndex) then
            Midpoints[tonumber(MidpointIndex)] = Midpoint
        end
    end

    local AnimationIndicator = ParentAttachment:FindFirstChild("AnimationIndicator")

    if not AnimationIndicator then
        return
    end

    local Positions = {}

    table.insert(Positions, Origin.WorldPosition)

    for _, Midpoint in Midpoints do
        table.insert(Positions, Midpoint.WorldPosition)
    end

    table.insert(Positions, Target.WorldPosition)

    local BezierCurve = Bezier.new(unpack(Positions))

    local TweenStyle = TweenInfo.new(
        AnimationIndicator.Duration.Value,
        Enum.EasingStyle[AnimationIndicator.TweenStyle.Value],
        Enum.EasingDirection[AnimationIndicator.TweenDirection.Value],
        AnimationIndicator.RepeatCount.Value,
        AnimationIndicator.Reverses.Value,
        AnimationIndicator.DelayTime.Value
    )

    if Mover:FindFirstChild("ReferenceValue") then
        Mover:FindFirstChild("ReferenceValue"):Destroy()
    end

    local ReferenceValue = Instance.new("NumberValue")
    ReferenceValue.Value = 0
    ReferenceValue.Name = "ReferenceValue"
    ReferenceValue.Parent = Mover

    local Tween = TweenService:Create(ReferenceValue, TweenStyle, {
        Value = 1
    })

    Tween.Completed:Connect(function()
        ReferenceValue:Destroy()
    end)

    ReferenceValue.Changed:Connect(function()
        local Position = BezierCurve:CalculatePositionAt(ReferenceValue.Value)
        Mover.WorldPosition = Position
    end)

    --Debris:AddItem(ReferenceValue, GetTimeFromTweenInfo(TweenStyle))
    Mover.CFrame = Origin.CFrame
    Tween:Play()

    return GetTimeFromTweenInfo(TweenStyle)
end

-- Actually plays the effect
local function PlayEffect(This : Instance, Bin : Instance) : number?
    local TotalDuration = nil
    local WidgetParentPayload = nil

    if This:IsA("ModuleScript") then
        local Duplicate = This:Clone()
        Duplicate.Parent = script

        local Module = require(Duplicate)

        if typeof(Module) ~= "table" then
            return
        end

        if not Module.Identifier or Module.Identifier ~= "VISUAL_EFFECT" then
            return
        end

        if not Module.Callback then
            warn(`No callback found in {This:GetFullName()}`)
            return
        end

        if not Module.Cleanup then
            warn(`No cleanup found in {This:GetFullName()}`)
            return
        end

        if not Module.Lifetime then
            warn(`No lifetime found in {This:GetFullName()}`)
            return
        end
        
        task.delay(This:GetAttribute("EmitDelay") or 0, function()
            Module.Callback(This.Parent)

            task.delay(Module.Lifetime, function()
                local Success, Error = pcall(function()
                    Module.Cleanup(This.Parent)
                end)

                if not Success then
                    warn(Error)
                end

                Duplicate:Destroy()
            end)
        end)

        TotalDuration = Module.Lifetime + (This:GetAttribute("EmitDelay") or 0)
    elseif This:IsA("ParticleEmitter") then
        task.delay(This:GetAttribute("EmitDelay") or 0, function()
            This:Emit(This:GetAttribute("EmitCount") or 1)

            if (This:GetAttribute("EmitDuration") or 0) > 0 then
                This.Enabled = true

                task.delay(This:GetAttribute("EmitDuration"), function()
                    This.Enabled = false
                end)
            end
        end)

        TotalDuration = (This:GetAttribute("EmitDuration") or 0) + (This:GetAttribute("EmitDelay") or 0) + This.Lifetime.Max
    elseif This:IsA("Sound") then
        local NewSound = This:Clone()

        task.delay(This:GetAttribute("EmitDelay") or 0, function()
            --NewSound.Parent = Widget
            
            -- Set initial volume based on distance
            if This.Parent and (This.Parent:IsA("BasePart") or This.Parent:IsA("Attachment")) then
                local Attenuation = CalculateVolume(This, This.Parent)
                NewSound.Volume *= Attenuation
            end
            
            if RunService:IsRunning() then
                NewSound:Play()
            else
                task.defer(function()
                    NewSound:Play()
                end)
            end

            if (This:GetAttribute("EmitDuration") or 0) > 0 then
                task.delay(This:GetAttribute("EmitDuration"), function()
                    NewSound:Stop()
                end)
            end

            NewSound.Ended:Connect(function()
                NewSound:Destroy()
            end)
        end)

        if (This:GetAttribute("EmitDuration") or 0) > 0 then
            TotalDuration = This:GetAttribute("EmitDuration") + (This:GetAttribute("EmitDelay") or 0)
        else
            TotalDuration = (This.TimeLength / This.PlaybackSpeed) + (This:GetAttribute("EmitDelay") or 0)
        end

        WidgetParentPayload = {NewSound, TotalDuration}
    elseif This:IsA("Trail") then
        This.Enabled = false

        table.insert(ActiveTasks[Bin], task.delay(This:GetAttribute("EmitDelay") or 0, function()
            This.Enabled = true

            table.insert(ActiveTasks[Bin], task.delay(This:GetAttribute("EmitDuration") or 0, function()
                This.Enabled = false
            end))
        end))

        TotalDuration = (This:GetAttribute("EmitDuration") or 0) + (This:GetAttribute("EmitDelay") or 0)
    elseif This:IsA("StringValue") and This.Name == "AnimationIndicator" then
        if This.Value == "Tween" then
            TotalDuration = AnimateTween(This.Parent)
        elseif This.Value == "Bezier" then
            TotalDuration = AnimateBezier(This.Parent)
        end
    end

    return TotalDuration, WidgetParentPayload
end

return function(Bin : Instance, IgnoreAllDescendants : boolean?) : number
    if ActiveTasks[Bin] then
        for _, Task in ActiveTasks[Bin] do
            task.cancel(Task)
        end
    end

    ActiveTasks[Bin] = {}

    local MaxTime, BinWidgetParentPayload = PlayEffect(Bin, Bin)
    local WidgetParentPayload = {BinWidgetParentPayload}
    MaxTime = MaxTime or 0

    if not IgnoreAllDescendants then
        for _, This : Instance in Bin:GetDescendants() do
            if not This:IsDescendantOf(workspace) then
                continue
            end
    
            local Duration, ThisWidgetParentPayload = PlayEffect(This, Bin)
    
            if ThisWidgetParentPayload then
                table.insert(WidgetParentPayload, ThisWidgetParentPayload)
            end
    
            Duration = Duration or 0
            MaxTime = math.max(MaxTime, Duration)
        end
    end

    table.insert(ActiveTasks[Bin], task.delay(MaxTime, function()
        ActiveTasks[Bin] = nil
    end))

    return MaxTime, WidgetParentPayload
end

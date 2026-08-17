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

-- Constants
local VISUAL_EFFECT_IDENTIFIER = "VISUAL_EFFECT"
local PART_ANIMATION_REFERENCE = "EffectDesignerAnimation"
local PART_ANIMATION_MODULE = "EDSPartAnimation"
local SHARED_FOLDER_NAME = "EffectDesignerSuite"
local MOVER_NAME = "Mover"
local ORIGIN_NAME = "Origin"
local TARGET_NAME = "Target"
local MIDPOINT_NAME = "Midpoint"
local ANIMATION_INDICATOR_NAME = "AnimationIndicator"
local ATTRIBUTE_EMIT_DELAY = "EmitDelay"
local ATTRIBUTE_EMIT_DURATION = "EmitDuration"
local ATTRIBUTE_EMIT_COUNT = "EmitCount"
local ANIMATION_TYPE_TWEEN = "Tween"
local ANIMATION_TYPE_BEZIER = "Bezier"
local MINIMUM_TWEEN_TIME = 0.0001

-- Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Imports
local Bezier = require(script:FindFirstChild("Bezier"))

-- Variables
local ActiveTasks = {}
local ActiveMoverDrivers = setmetatable({}, {__mode = "k"})
local ActiveMoverRestores = setmetatable({}, {__mode = "k"})

-- Get time from tween info
local function GetTimeFromTweenInfo(tweenInfo : TweenInfo)
    local Duration = tweenInfo.Time
    local Delay = tweenInfo.DelayTime

    if tweenInfo.Reverses then
        Duration *= 2
    end
    
    if tweenInfo.RepeatCount > 0 then
        Duration *= (tweenInfo.RepeatCount + 1)
    end

    return Duration + Delay
end

-- Helper function to calculate distance-based volume
local function CalculateVolume(sound: Sound, parentInstance: Instance): number
    -- Return 1 if not using plugin
    if RunService:IsRunning() then
        return 1
    end

    local Camera = workspace.CurrentCamera
    if not Camera then return 1 end
    
    local ParentPosition = if parentInstance:IsA("Attachment") 
        then parentInstance.WorldPosition 
        else parentInstance.Position
    
    local Distance = (ParentPosition - Camera.CFrame.Position).Magnitude
    
    -- Get rolloff properties from sound
    local MinDistance = sound.RollOffMinDistance
    local MaxDistance = sound.RollOffMaxDistance
    local RolloffMode = sound.RollOffMode

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
        local Alpha = (Distance - MinDistance) / (MaxDistance - MinDistance)
        Volume = 1 - math.clamp(Alpha * Alpha, 0, 1)
    end
    
    return Volume
end

local function GetWorldCFrame(object : Instance) : CFrame?
    if object:IsA("BasePart") then
        return object.CFrame
    end

    if object:IsA("Attachment") then
        return object.WorldCFrame
    end

    return nil
end

local function GetWorldPosition(object : Instance) : Vector3?
    if object:IsA("BasePart") then
        return object.Position
    end

    if object:IsA("Attachment") then
        return object.WorldPosition
    end

    return nil
end

local function ResolveMover(host : Instance)
    local Named = host:FindFirstChild(MOVER_NAME)
    if Named and Named:IsA("BasePart") then
        return Named
    end

    if host:IsA("BasePart") then
        return host
    end

    if Named and Named:IsA("Attachment") then
        return Named
    end

    return nil
end

local function GetMoverLocalCFrame(mover : Instance, worldCFrame : CFrame) : CFrame
    if not mover:IsA("Attachment") then
        return worldCFrame
    end

    local Parent = mover.Parent
    if Parent and Parent:IsA("BasePart") then
        return Parent.CFrame:ToObjectSpace(worldCFrame)
    end

    if Parent and Parent:IsA("Attachment") then
        return Parent.WorldCFrame:ToObjectSpace(worldCFrame)
    end

    return worldCFrame
end

local function SetMoverCFrame(mover : Instance, worldCFrame : CFrame)
    if mover:IsA("BasePart") then
        mover.CFrame = worldCFrame
        return
    end

    if mover:IsA("Attachment") then
        mover.CFrame = GetMoverLocalCFrame(mover, worldCFrame)
    end
end

local function StopMoverDriver(mover : Instance)
    local Existing = ActiveMoverDrivers[mover]
    if Existing then
        Existing:Disconnect()
        ActiveMoverDrivers[mover] = nil
    end

    local Restore = ActiveMoverRestores[mover]
    if Restore then
        ActiveMoverRestores[mover] = nil
        Restore()
    end
end

local function DriveMoverAlpha(mover : Instance, tweenStyle : TweenInfo, onAlpha : (number) -> (), onFinished : (() -> ())?) : number
    StopMoverDriver(mover)

    local TotalDuration = GetTimeFromTweenInfo(tweenStyle)
    local StartClock = os.clock()
    onAlpha(0)
    ActiveMoverRestores[mover] = onFinished

    local Connection
    Connection = RunService.Heartbeat:Connect(function()
        if not mover.Parent then
            StopMoverDriver(mover)
            return
        end

        local Elapsed = os.clock() - StartClock
        local Delay = tweenStyle.DelayTime
        local Time = math.max(tweenStyle.Time, MINIMUM_TWEEN_TIME)
        local Reverses = tweenStyle.Reverses
        local RepeatCount = tweenStyle.RepeatCount
        local CycleLength = Time * (if Reverses then 2 else 1)

        if Elapsed < Delay then
            onAlpha(0)
            return
        end

        local PlayElapsed = Elapsed - Delay
        local CycleIndex = math.floor(PlayElapsed / CycleLength)
        local Finished = RepeatCount >= 0 and CycleIndex >= RepeatCount + 1

        if Finished or Elapsed >= TotalDuration then
            local FinalLinear = if Reverses then 0 else 1
            onAlpha(TweenService:GetValue(FinalLinear, tweenStyle.EasingStyle, tweenStyle.EasingDirection))
            Connection:Disconnect()
            ActiveMoverDrivers[mover] = nil

            local Restore = ActiveMoverRestores[mover]
            ActiveMoverRestores[mover] = nil
            if Restore then
                Restore()
            end
            return
        end

        local CycleTime = PlayElapsed - CycleIndex * CycleLength
        local Linear = if Reverses and CycleTime > Time
            then 1 - math.clamp((CycleTime - Time) / Time, 0, 1)
            else math.clamp(CycleTime / Time, 0, 1)

        onAlpha(TweenService:GetValue(Linear, tweenStyle.EasingStyle, tweenStyle.EasingDirection))
    end)

    ActiveMoverDrivers[mover] = Connection
    return TotalDuration
end

local function GetRotationCFrame(value : CFrame) : CFrame
    return value.Rotation
end

local function SampleRotationCFrame(rotations : {CFrame}, alpha : number) : CFrame
    if #rotations == 0 then
        return CFrame.identity
    end

    if #rotations == 1 then
        return GetRotationCFrame(rotations[1])
    end

    local Clamped = math.clamp(alpha, 0, 1)
    local Scaled = Clamped * (#rotations - 1)
    local Index = math.clamp(math.floor(Scaled) + 1, 1, #rotations - 1)
    local LocalAlpha = Scaled - (Index - 1)
    return GetRotationCFrame(rotations[Index]:Lerp(rotations[Index + 1], LocalAlpha))
end

local function MakeWorldCFrame(position : Vector3, rotation : CFrame) : CFrame
    return CFrame.new(position) * GetRotationCFrame(rotation)
end

-- Function to animate tweens
local function AnimateTween(host : Instance)
    local mover = ResolveMover(host)

    if not mover then
        return
    end

    local Origin = host:FindFirstChild(ORIGIN_NAME)

    if not Origin then
        return
    end

    local Target = host:FindFirstChild(TARGET_NAME)

    if not Target then
        return
    end
    
    local AnimationIndicator = host:FindFirstChild(ANIMATION_INDICATOR_NAME)

    if not AnimationIndicator then
        return
    end

    local OriginCFrame = GetWorldCFrame(Origin)
    local TargetCFrame = GetWorldCFrame(Target)
    if not OriginCFrame or not TargetCFrame then
        return
    end

    local tweenStyle = TweenInfo.new(
        AnimationIndicator.Duration.Value,
        Enum.EasingStyle[AnimationIndicator.TweenStyle.Value],
        Enum.EasingDirection[AnimationIndicator.TweenDirection.Value],
        AnimationIndicator.RepeatCount.Value,
        AnimationIndicator.Reverses.Value,
        AnimationIndicator.DelayTime.Value
    )

    if mover:IsA("BasePart") then
        StopMoverDriver(mover)
        local OriginalCFrame = mover.CFrame
        return DriveMoverAlpha(mover, tweenStyle, function(alpha)
            mover.CFrame = OriginCFrame:Lerp(TargetCFrame, alpha)
        end, function()
            if mover.Parent then
                mover.CFrame = OriginalCFrame
            end
        end)
    end

    SetMoverCFrame(mover, OriginCFrame)
    local Tween = TweenService:Create(mover, tweenStyle, {
        CFrame = GetMoverLocalCFrame(mover, TargetCFrame)
    })
    Tween:Play()

    return GetTimeFromTweenInfo(tweenStyle)
end

-- Function to animate bezier tweens
local function AnimateBezier(host : Instance)
    local mover = ResolveMover(host)

    if not mover then
        return
    end

    local Origin = host:FindFirstChild(ORIGIN_NAME)

    if not Origin then
        return
    end
    
    local Target = host:FindFirstChild(TARGET_NAME)

    if not Target then
        return
    end

    local Midpoints = {host:FindFirstChild(MIDPOINT_NAME)}

    for _, midpoint in host:GetChildren() do
        if not (midpoint:IsA("Attachment") or midpoint:IsA("BasePart")) then
            continue
        end

        local MidpointIndex = midpoint.Name:gsub(MIDPOINT_NAME, "")

        if MidpointIndex and tonumber(MidpointIndex) then
            Midpoints[tonumber(MidpointIndex)] = midpoint
        end
    end

    local AnimationIndicator = host:FindFirstChild(ANIMATION_INDICATOR_NAME)

    if not AnimationIndicator then
        return
    end

    local OriginCFrame = GetWorldCFrame(Origin)
    local TargetCFrame = GetWorldCFrame(Target)
    local OriginPosition = GetWorldPosition(Origin)
    local TargetPosition = GetWorldPosition(Target)
    if not OriginCFrame or not TargetCFrame or not OriginPosition or not TargetPosition then
        return
    end

    local Positions = {}
    local Rotations = {OriginCFrame}

    table.insert(Positions, OriginPosition)

    for _, midpoint in Midpoints do
        local MidpointPosition = GetWorldPosition(midpoint)
        local MidpointCFrame = GetWorldCFrame(midpoint)
        if MidpointPosition then
            table.insert(Positions, MidpointPosition)
        end
        if MidpointCFrame then
            table.insert(Rotations, MidpointCFrame)
        end
    end

    table.insert(Positions, TargetPosition)
    table.insert(Rotations, TargetCFrame)

    local BezierCurve = Bezier.new(unpack(Positions))

    local tweenStyle = TweenInfo.new(
        AnimationIndicator.Duration.Value,
        Enum.EasingStyle[AnimationIndicator.TweenStyle.Value],
        Enum.EasingDirection[AnimationIndicator.TweenDirection.Value],
        AnimationIndicator.RepeatCount.Value,
        AnimationIndicator.Reverses.Value,
        AnimationIndicator.DelayTime.Value
    )

    local OriginalCFrame = if mover:IsA("BasePart") then mover.CFrame else nil
    if mover:IsA("BasePart") then
        StopMoverDriver(mover)
        OriginalCFrame = mover.CFrame
    end

    return DriveMoverAlpha(mover, tweenStyle, function(alpha)
        local Position = BezierCurve:CalculatePositionAt(alpha)
        SetMoverCFrame(mover, MakeWorldCFrame(Position, SampleRotationCFrame(Rotations, alpha)))
    end, if OriginalCFrame then function()
        if mover.Parent then
            mover.CFrame = OriginalCFrame
        end
    end else nil)
end

local function PlayHostAnimationIndicator(host : Instance) : number?
    if not host then
        return nil
    end

    local Indicator = host:FindFirstChild(ANIMATION_INDICATOR_NAME)
    if not (Indicator and Indicator:IsA("StringValue")) then
        return nil
    end

    if Indicator.Value == ANIMATION_TYPE_TWEEN then
        return AnimateTween(host)
    elseif Indicator.Value == ANIMATION_TYPE_BEZIER then
        return AnimateBezier(host)
    end

    return nil
end

local function GetCanonicalPartAnimationModule(fallback : ModuleScript?)
    local Sibling = script.Parent and script.Parent:FindFirstChild("PartAnimation")
    if Sibling and Sibling:IsA("ModuleScript") then
        return Sibling
    end

    local Shared = ReplicatedStorage:FindFirstChild(SHARED_FOLDER_NAME)
    if Shared then
        local Found = Shared:FindFirstChild("PartAnimation")
        if Found and Found:IsA("ModuleScript") then
            return Found
        end
    end

    return fallback
end

local function ResolvePartAnimationModule(part : Instance)
    local Reference = part:FindFirstChild(PART_ANIMATION_REFERENCE)
    if Reference and Reference:IsA("ObjectValue") and Reference.Value and Reference.Value:IsA("ModuleScript") then
        return Reference.Value
    end

    local Child = part:FindFirstChild(PART_ANIMATION_MODULE)
    if Child and Child:IsA("ModuleScript") then
        return Child
    end

    return nil
end

local function IsPartAnimationModule(this : Instance)
    local Parent = this.Parent
    if not Parent or not Parent:IsA("BasePart") then
        return false
    end

    return ResolvePartAnimationModule(Parent) == this
end

local function PlayVisualEffectModule(moduleScript : ModuleScript, parent : Instance) : number?
    local Duplicate = moduleScript:Clone()
    Duplicate.Parent = script

    local Module = require(Duplicate)

    if typeof(Module) ~= "table" then
        Duplicate:Destroy()
        return
    end

    if not Module.Identifier or Module.Identifier ~= VISUAL_EFFECT_IDENTIFIER then
        Duplicate:Destroy()
        return
    end

    if not Module.Callback then
        warn(`No callback found in {moduleScript:GetFullName()} {debug.traceback()}`)
        Duplicate:Destroy()
        return
    end

    if not Module.Cleanup then
        warn(`No cleanup found in {moduleScript:GetFullName()} {debug.traceback()}`)
        Duplicate:Destroy()
        return
    end

    local Lifetime = Module.Lifetime
    if typeof(Module.GetLifetime) == "function" then
        local Resolved = Module.GetLifetime(parent)
        if typeof(Resolved) == "number" and Resolved > 0 then
            Lifetime = Resolved
        end
    end

    if not Lifetime then
        warn(`No lifetime found in {moduleScript:GetFullName()} {debug.traceback()}`)
        Duplicate:Destroy()
        return
    end

    local Delay = moduleScript:GetAttribute(ATTRIBUTE_EMIT_DELAY)
    if Delay == nil and parent then
        Delay = parent:GetAttribute(ATTRIBUTE_EMIT_DELAY)
    end
    Delay = Delay or 0

    task.delay(Delay, function()
        Module.Callback(parent)

        task.delay(Lifetime, function()
            local Success, Error = pcall(function()
                Module.Cleanup(parent)
            end)

            if not Success then
                warn(`{Error} {debug.traceback()}`)
            end

            Duplicate:Destroy()
        end)
    end)

    return Lifetime + Delay
end

-- Actually plays the effect
local function PlayEffect(this : Instance, bin : Instance, widgetParentPayload : {any}) : number?
    local TotalDuration = nil

    if this:IsA("ModuleScript") then
        if IsPartAnimationModule(this) then
            if bin ~= this then
                return
            end

            TotalDuration = PlayVisualEffectModule(GetCanonicalPartAnimationModule(this), this.Parent)
        else
            TotalDuration = PlayVisualEffectModule(this, this.Parent)
        end
    elseif this:IsA("BasePart") then
        local MaxDuration = 0
        local AnimationModule = GetCanonicalPartAnimationModule(ResolvePartAnimationModule(this))
        if AnimationModule then
            MaxDuration = math.max(MaxDuration, PlayVisualEffectModule(AnimationModule, this) or 0)
        end

        MaxDuration = math.max(MaxDuration, PlayHostAnimationIndicator(this) or 0)
        if MaxDuration > 0 then
            TotalDuration = MaxDuration
        end
    elseif this:IsA("ParticleEmitter") then
        task.delay(this:GetAttribute(ATTRIBUTE_EMIT_DELAY) or 0, function()
            this:Emit(this:GetAttribute(ATTRIBUTE_EMIT_COUNT) or 1)

            if (this:GetAttribute(ATTRIBUTE_EMIT_DURATION) or 0) > 0 then
                this.Enabled = true

                task.delay(this:GetAttribute(ATTRIBUTE_EMIT_DURATION), function()
                    this.Enabled = false
                end)
            end
        end)

        TotalDuration = (this:GetAttribute(ATTRIBUTE_EMIT_DURATION) or 0) + (this:GetAttribute(ATTRIBUTE_EMIT_DELAY) or 0) + this.Lifetime.Max
    elseif this:IsA("Sound") then
        local NewSound = this:Clone()
        NewSound.Parent = if this.Parent then this.Parent else workspace

        task.delay(this:GetAttribute(ATTRIBUTE_EMIT_DELAY) or 0, function()
            -- Set initial volume based on distance
            if this.Parent and (this.Parent:IsA("BasePart") or this.Parent:IsA("Attachment")) then
                local Attenuation = CalculateVolume(this, this.Parent)
                NewSound.Volume *= Attenuation
            end
            
            if RunService:IsRunning() then
                NewSound:Play()
            else
                task.defer(function()
                    NewSound:Play()
                end)
            end

            if (this:GetAttribute(ATTRIBUTE_EMIT_DURATION) or 0) > 0 then
                task.delay(this:GetAttribute(ATTRIBUTE_EMIT_DURATION), function()
                    NewSound:Stop()
                end)
            end

            NewSound.Ended:Connect(function()
                NewSound:Destroy()
            end)
        end)

        if (this:GetAttribute(ATTRIBUTE_EMIT_DURATION) or 0) > 0 then
            TotalDuration = this:GetAttribute(ATTRIBUTE_EMIT_DURATION) + (this:GetAttribute(ATTRIBUTE_EMIT_DELAY) or 0)
        else
            TotalDuration = (this.TimeLength / this.PlaybackSpeed) + (this:GetAttribute(ATTRIBUTE_EMIT_DELAY) or 0)
        end

        if widgetParentPayload then
            table.insert(widgetParentPayload, {NewSound, TotalDuration})
        end
    elseif this:IsA("Trail") then
        this.Enabled = false

        table.insert(ActiveTasks[bin], task.delay(this:GetAttribute(ATTRIBUTE_EMIT_DELAY) or 0, function()
            this.Enabled = true

            table.insert(ActiveTasks[bin], task.delay(this:GetAttribute(ATTRIBUTE_EMIT_DURATION) or 0, function()
                this.Enabled = false
            end))
        end))

        TotalDuration = (this:GetAttribute(ATTRIBUTE_EMIT_DURATION) or 0) + (this:GetAttribute(ATTRIBUTE_EMIT_DELAY) or 0)
    elseif this:IsA("StringValue") and this.Name == ANIMATION_INDICATOR_NAME then
        TotalDuration = PlayHostAnimationIndicator(this.Parent)
    end

    return TotalDuration
end

return function(bin : Instance, ignoreAllDescendants : boolean?) : number
    if ActiveTasks[bin] then
        for _, thisTask in ActiveTasks[bin] do
            task.cancel(thisTask)
        end
    end

    ActiveTasks[bin] = {}

    local widgetParentPayload = {}
    local Descendants = bin:GetDescendants()
    local MaxTime = PlayEffect(bin, bin, widgetParentPayload)
    MaxTime = MaxTime or 0

    if not ignoreAllDescendants then
        for _, this : Instance in Descendants do
            if not this:IsDescendantOf(workspace) then
                continue
            end
    
            local Duration = PlayEffect(this, bin, widgetParentPayload)
    
            Duration = Duration or 0
            MaxTime = math.max(MaxTime, Duration)
        end
    end

    table.insert(ActiveTasks[bin], task.delay(MaxTime, function()
        ActiveTasks[bin] = nil
    end))

    return MaxTime, widgetParentPayload
end

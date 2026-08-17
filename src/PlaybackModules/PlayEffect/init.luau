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
        local Alpha = (Distance - MinDistance) / (MaxDistance - MinDistance)
        Volume = 1 - math.clamp(Alpha * Alpha, 0, 1)
    end
    
    return Volume
end

local function GetWorldCFrame(Object : Instance) : CFrame?
    if Object:IsA("BasePart") then
        return Object.CFrame
    end

    if Object:IsA("Attachment") then
        return Object.WorldCFrame
    end

    return nil
end

local function GetWorldPosition(Object : Instance) : Vector3?
    if Object:IsA("BasePart") then
        return Object.Position
    end

    if Object:IsA("Attachment") then
        return Object.WorldPosition
    end

    return nil
end

local function ResolveMover(Host : Instance)
    local Named = Host:FindFirstChild("Mover")
    if Named and Named:IsA("BasePart") then
        return Named
    end

    if Host:IsA("BasePart") then
        return Host
    end

    if Named and Named:IsA("Attachment") then
        return Named
    end

    return nil
end

local function GetMoverLocalCFrame(Mover : Instance, WorldCFrame : CFrame) : CFrame
    if not Mover:IsA("Attachment") then
        return WorldCFrame
    end

    local Parent = Mover.Parent
    if Parent and Parent:IsA("BasePart") then
        return Parent.CFrame:ToObjectSpace(WorldCFrame)
    end

    if Parent and Parent:IsA("Attachment") then
        return Parent.WorldCFrame:ToObjectSpace(WorldCFrame)
    end

    return WorldCFrame
end

local function SetMoverCFrame(Mover : Instance, WorldCFrame : CFrame)
    if Mover:IsA("BasePart") then
        Mover.CFrame = WorldCFrame
        return
    end

    if Mover:IsA("Attachment") then
        Mover.CFrame = GetMoverLocalCFrame(Mover, WorldCFrame)
    end
end

local ActiveMoverDrivers = setmetatable({}, {__mode = "k"})
local ActiveMoverRestores = setmetatable({}, {__mode = "k"})

local function StopMoverDriver(Mover : Instance)
    local Existing = ActiveMoverDrivers[Mover]
    if Existing then
        Existing:Disconnect()
        ActiveMoverDrivers[Mover] = nil
    end

    local Restore = ActiveMoverRestores[Mover]
    if Restore then
        ActiveMoverRestores[Mover] = nil
        Restore()
    end
end

local function DriveMoverAlpha(Mover : Instance, TweenStyle : TweenInfo, OnAlpha : (number) -> (), OnFinished : (() -> ())?) : number
    StopMoverDriver(Mover)

    local TotalDuration = GetTimeFromTweenInfo(TweenStyle)
    local StartClock = os.clock()
    OnAlpha(0)
    ActiveMoverRestores[Mover] = OnFinished

    local Connection
    Connection = RunService.Heartbeat:Connect(function()
        if not Mover.Parent then
            StopMoverDriver(Mover)
            return
        end

        local Elapsed = os.clock() - StartClock
        local Delay = TweenStyle.DelayTime
        local Time = math.max(TweenStyle.Time, 0.0001)
        local Reverses = TweenStyle.Reverses
        local RepeatCount = TweenStyle.RepeatCount
        local CycleLength = Time * (if Reverses then 2 else 1)

        if Elapsed < Delay then
            OnAlpha(0)
            return
        end

        local PlayElapsed = Elapsed - Delay
        local CycleIndex = math.floor(PlayElapsed / CycleLength)
        local Finished = RepeatCount >= 0 and CycleIndex >= RepeatCount + 1

        if Finished or Elapsed >= TotalDuration then
            local FinalLinear = if Reverses then 0 else 1
            OnAlpha(TweenService:GetValue(FinalLinear, TweenStyle.EasingStyle, TweenStyle.EasingDirection))
            Connection:Disconnect()
            ActiveMoverDrivers[Mover] = nil

            local Restore = ActiveMoverRestores[Mover]
            ActiveMoverRestores[Mover] = nil
            if Restore then
                Restore()
            end
            return
        end

        local CycleTime = PlayElapsed - CycleIndex * CycleLength
        local Linear = if Reverses and CycleTime > Time
            then 1 - math.clamp((CycleTime - Time) / Time, 0, 1)
            else math.clamp(CycleTime / Time, 0, 1)

        OnAlpha(TweenService:GetValue(Linear, TweenStyle.EasingStyle, TweenStyle.EasingDirection))
    end)

    ActiveMoverDrivers[Mover] = Connection
    return TotalDuration
end

local function GetRotationCFrame(Value : CFrame) : CFrame
    return Value.Rotation
end

local function SampleRotationCFrame(Rotations : {CFrame}, Alpha : number) : CFrame
    if #Rotations == 0 then
        return CFrame.identity
    end

    if #Rotations == 1 then
        return GetRotationCFrame(Rotations[1])
    end

    local Clamped = math.clamp(Alpha, 0, 1)
    local Scaled = Clamped * (#Rotations - 1)
    local Index = math.clamp(math.floor(Scaled) + 1, 1, #Rotations - 1)
    local LocalAlpha = Scaled - (Index - 1)
    return GetRotationCFrame(Rotations[Index]:Lerp(Rotations[Index + 1], LocalAlpha))
end

local function MakeWorldCFrame(Position : Vector3, Rotation : CFrame) : CFrame
    return CFrame.new(Position) * GetRotationCFrame(Rotation)
end

-- Function to animate tweens
local function AnimateTween(Host : Instance)
    local Mover = ResolveMover(Host)

    if not Mover then
        return
    end

    local Origin = Host:FindFirstChild("Origin")

    if not Origin then
        return
    end

    local Target = Host:FindFirstChild("Target")

    if not Target then
        return
    end
    
    local AnimationIndicator = Host:FindFirstChild("AnimationIndicator")

    if not AnimationIndicator then
        return
    end

    local OriginCFrame = GetWorldCFrame(Origin)
    local TargetCFrame = GetWorldCFrame(Target)
    if not OriginCFrame or not TargetCFrame then
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

    if Mover:IsA("BasePart") then
        StopMoverDriver(Mover)
        local OriginalCFrame = Mover.CFrame
        return DriveMoverAlpha(Mover, TweenStyle, function(Alpha)
            Mover.CFrame = OriginCFrame:Lerp(TargetCFrame, Alpha)
        end, function()
            if Mover.Parent then
                Mover.CFrame = OriginalCFrame
            end
        end)
    end

    SetMoverCFrame(Mover, OriginCFrame)
    local Tween = TweenService:Create(Mover, TweenStyle, {
        CFrame = GetMoverLocalCFrame(Mover, TargetCFrame)
    })
    Tween:Play()

    return GetTimeFromTweenInfo(TweenStyle)
end

-- Function to animate bezier tweens
local function AnimateBezier(Host : Instance)
    local Mover = ResolveMover(Host)

    if not Mover then
        return
    end

    local Origin = Host:FindFirstChild("Origin")

    if not Origin then
        return
    end
    
    local Target = Host:FindFirstChild("Target")

    if not Target then
        return
    end

    local Midpoints = {Host:FindFirstChild("Midpoint")}

    for _, Midpoint in Host:GetChildren() do
        if not (Midpoint:IsA("Attachment") or Midpoint:IsA("BasePart")) then
            continue
        end

        local MidpointIndex = Midpoint.Name:gsub("Midpoint", "")

        if MidpointIndex and tonumber(MidpointIndex) then
            Midpoints[tonumber(MidpointIndex)] = Midpoint
        end
    end

    local AnimationIndicator = Host:FindFirstChild("AnimationIndicator")

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

    for _, Midpoint in Midpoints do
        local MidpointPosition = GetWorldPosition(Midpoint)
        local MidpointCFrame = GetWorldCFrame(Midpoint)
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

    local TweenStyle = TweenInfo.new(
        AnimationIndicator.Duration.Value,
        Enum.EasingStyle[AnimationIndicator.TweenStyle.Value],
        Enum.EasingDirection[AnimationIndicator.TweenDirection.Value],
        AnimationIndicator.RepeatCount.Value,
        AnimationIndicator.Reverses.Value,
        AnimationIndicator.DelayTime.Value
    )

    local OriginalCFrame = if Mover:IsA("BasePart") then Mover.CFrame else nil
    if Mover:IsA("BasePart") then
        StopMoverDriver(Mover)
        OriginalCFrame = Mover.CFrame
    end

    return DriveMoverAlpha(Mover, TweenStyle, function(Alpha)
        local Position = BezierCurve:CalculatePositionAt(Alpha)
        SetMoverCFrame(Mover, MakeWorldCFrame(Position, SampleRotationCFrame(Rotations, Alpha)))
    end, if OriginalCFrame then function()
        if Mover.Parent then
            Mover.CFrame = OriginalCFrame
        end
    end else nil)
end

local function PlayHostAnimationIndicator(Host : Instance) : number?
    if not Host then
        return nil
    end

    local Indicator = Host:FindFirstChild("AnimationIndicator")
    if not (Indicator and Indicator:IsA("StringValue")) then
        return nil
    end

    if Indicator.Value == "Tween" then
        return AnimateTween(Host)
    elseif Indicator.Value == "Bezier" then
        return AnimateBezier(Host)
    end

    return nil
end

local PART_ANIMATION_REFERENCE = "EffectDesignerAnimation"
local PART_ANIMATION_MODULE = "EDSPartAnimation"

local function GetCanonicalPartAnimationModule(Fallback : ModuleScript?)
    local Sibling = script.Parent and script.Parent:FindFirstChild("PartAnimation")
    if Sibling and Sibling:IsA("ModuleScript") then
        return Sibling
    end

    local Shared = game:GetService("ReplicatedStorage"):FindFirstChild("EffectDesignerSuite")
    if Shared then
        local Found = Shared:FindFirstChild("PartAnimation")
        if Found and Found:IsA("ModuleScript") then
            return Found
        end
    end

    return Fallback
end

local function ResolvePartAnimationModule(Part : Instance)
    local Reference = Part:FindFirstChild(PART_ANIMATION_REFERENCE)
    if Reference and Reference:IsA("ObjectValue") and Reference.Value and Reference.Value:IsA("ModuleScript") then
        return Reference.Value
    end

    local Child = Part:FindFirstChild(PART_ANIMATION_MODULE)
    if Child and Child:IsA("ModuleScript") then
        return Child
    end

    return nil
end

local function IsPartAnimationModule(This : Instance)
    local Parent = This.Parent
    if not Parent or not Parent:IsA("BasePart") then
        return false
    end

    return ResolvePartAnimationModule(Parent) == This
end

local function PlayVisualEffectModule(ModuleScript : ModuleScript, Parent : Instance) : number?
    local Duplicate = ModuleScript:Clone()
    Duplicate.Parent = script

    local Module = require(Duplicate)

    if typeof(Module) ~= "table" then
        Duplicate:Destroy()
        return
    end

    if not Module.Identifier or Module.Identifier ~= "VISUAL_EFFECT" then
        Duplicate:Destroy()
        return
    end

    if not Module.Callback then
        warn(`No callback found in {ModuleScript:GetFullName()}`)
        Duplicate:Destroy()
        return
    end

    if not Module.Cleanup then
        warn(`No cleanup found in {ModuleScript:GetFullName()}`)
        Duplicate:Destroy()
        return
    end

    local Lifetime = Module.Lifetime
    if typeof(Module.GetLifetime) == "function" then
        local Resolved = Module.GetLifetime(Parent)
        if typeof(Resolved) == "number" and Resolved > 0 then
            Lifetime = Resolved
        end
    end

    if not Lifetime then
        warn(`No lifetime found in {ModuleScript:GetFullName()}`)
        Duplicate:Destroy()
        return
    end

    local Delay = ModuleScript:GetAttribute("EmitDelay")
    if Delay == nil and Parent then
        Delay = Parent:GetAttribute("EmitDelay")
    end
    Delay = Delay or 0

    task.delay(Delay, function()
        Module.Callback(Parent)

        task.delay(Lifetime, function()
            local Success, Error = pcall(function()
                Module.Cleanup(Parent)
            end)

            if not Success then
                warn(Error)
            end

            Duplicate:Destroy()
        end)
    end)

    return Lifetime + Delay
end

-- Actually plays the effect
local function PlayEffect(This : Instance, Bin : Instance, WidgetParentPayload : {any}) : number?
    local TotalDuration = nil

    if This:IsA("ModuleScript") then
        if IsPartAnimationModule(This) then
            if Bin ~= This then
                return
            end

            TotalDuration = PlayVisualEffectModule(GetCanonicalPartAnimationModule(This), This.Parent)
        else
            TotalDuration = PlayVisualEffectModule(This, This.Parent)
        end
    elseif This:IsA("BasePart") then
        local MaxDuration = 0
        local AnimationModule = GetCanonicalPartAnimationModule(ResolvePartAnimationModule(This))
        if AnimationModule then
            MaxDuration = math.max(MaxDuration, PlayVisualEffectModule(AnimationModule, This) or 0)
        end

        MaxDuration = math.max(MaxDuration, PlayHostAnimationIndicator(This) or 0)
        if MaxDuration > 0 then
            TotalDuration = MaxDuration
        end
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
        NewSound.Parent = if This.Parent then This.Parent else workspace

        task.delay(This:GetAttribute("EmitDelay") or 0, function()
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

        if WidgetParentPayload then
            table.insert(WidgetParentPayload, {NewSound, TotalDuration})
        end
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
        TotalDuration = PlayHostAnimationIndicator(This.Parent)
    end

    return TotalDuration
end

return function(Bin : Instance, IgnoreAllDescendants : boolean?) : number
    if ActiveTasks[Bin] then
        for _, Task in ActiveTasks[Bin] do
            task.cancel(Task)
        end
    end

    ActiveTasks[Bin] = {}

    local WidgetParentPayload = {}
    local Descendants = Bin:GetDescendants()
    local MaxTime = PlayEffect(Bin, Bin, WidgetParentPayload)
    MaxTime = MaxTime or 0

    if not IgnoreAllDescendants then
        for _, This : Instance in Descendants do
            if not This:IsDescendantOf(workspace) then
                continue
            end
    
            local Duration = PlayEffect(This, Bin, WidgetParentPayload)
    
            Duration = Duration or 0
            MaxTime = math.max(MaxTime, Duration)
        end
    end

    table.insert(ActiveTasks[Bin], task.delay(MaxTime, function()
        ActiveTasks[Bin] = nil
    end))

    return MaxTime, WidgetParentPayload
end

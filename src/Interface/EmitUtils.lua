local EmitUtils = {}

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Imports
local Bin = script.Parent.Parent
local Objects = Bin:FindFirstChild("Objects")
local Packages = Bin:FindFirstChild("Packages")
local States = require(Objects:FindFirstChild("States"))
local Fusion = require(Packages:FindFirstChild("Fusion"))
local Scope = Fusion.scoped(Fusion)
local Peek = Fusion.peek

-- Variables
local RepeatEmitConnection = nil
local Widget = nil
local ActiveTasks = {}

-- Helper function to calculate distance-based volume
local function CalculateVolume(Sound: Sound, ParentInstance: Instance): number
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
end

function EmitUtils:SetWidget(...)
    Widget = ...
end

function EmitUtils:EmitCurrent(ForcedInstances : {Instance}?)
    if not Peek(States.IsEmittable) and not ForcedInstances then
        return
    end

    local SelectedInstances = ForcedInstances or Peek(States.CurrentlySelected)

    for _, Task in ActiveTasks do
        task.cancel(Task)
    end

    ActiveTasks = {}

    for _, This : Instance in SelectedInstances do
        if not This.Parent then
            continue
        end

        if This:IsA("ModuleScript") then
            local Duplicate = This:Clone()
            Duplicate.Parent = script

            local Module = require(Duplicate)

            if typeof(Module) ~= "table" then
                continue
            end

            if not Module.Identifier or Module.Identifier ~= "VISUAL_EFFECT" then
                continue
            end

            if not Module.Callback then
                warn(`No callback found in {This:GetFullName()}`)
                continue
            end

            if not Module.Cleanup then
                warn(`No cleanup found in {This:GetFullName()}`)
                continue
            end

            if not Module.Lifetime then
                warn(`No lifetime found in {This:GetFullName()}`)
                continue
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
        elseif This:IsA("Sound") then
            task.delay(This:GetAttribute("EmitDelay") or 0, function()
                local NewSound = This:Clone()
                NewSound.Parent = Widget
                
                -- Set initial volume based on distance
                if This.Parent and (This.Parent:IsA("BasePart") or This.Parent:IsA("Attachment")) then
                    local Attenuation = CalculateVolume(This, This.Parent)
                    NewSound.Volume *= Attenuation
                end
                
                NewSound:Play()

                if (This:GetAttribute("EmitDuration") or 0) > 0 then
                    task.delay(This:GetAttribute("EmitDuration"), function()
                        NewSound:Stop()
                    end)
                end

                NewSound.Ended:Connect(function()
                    NewSound:Destroy()
                end)
            end)
        elseif This:IsA("Trail") then
            This.Enabled = false

            table.insert(ActiveTasks, task.delay(This:GetAttribute("EmitDelay") or 0, function()
                This.Enabled = true

                task.delay(This:GetAttribute("EmitDuration") or 0, function()
                    This.Enabled = false
                end)
            end))
        elseif This:IsA("StringValue") and This.Name == "AnimationIndicator" then
            AnimateTween(This.Parent)
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

return EmitUtils
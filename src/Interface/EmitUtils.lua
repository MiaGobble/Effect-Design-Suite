local EmitUtils = {}

-- Services
local RunService = game:GetService("RunService")

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

function EmitUtils:EmitCurrent(ForcedInstances : {Instance}?)
    if not Peek(States.IsEmittable) and not ForcedInstances then
        return
    end

    local SelectedInstances = ForcedInstances or Peek(States.CurrentlySelected)

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

                if (This:GetAttribute("EmitSustain") or 0) > 0 then
                    This.Enabled = true

                    task.delay(This:GetAttribute("EmitSustain"), function()
                        This.Enabled = false
                    end)
                end
            end)
        elseif This:IsA("Sound") then
            task.delay(This:GetAttribute("EmitDelay") or 0, function()
                if (This:GetAttribute("EmitSustain") or 0) > 0 then
                    This:Play()

                    task.delay(This:GetAttribute("EmitSustain"), function()
                        This:Stop()
                    end)
                else
                    This:Play()
                end
            end)
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
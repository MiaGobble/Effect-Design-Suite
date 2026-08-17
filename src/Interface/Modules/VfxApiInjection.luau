local VfxApiInjection = {}

local WorldSpaceAcceleration = require(script.Parent.WorldSpaceAcceleration)

local CLIENT_SCRIPT_NAME = "EDSSharedPlayEffect.client"
local SERVER_SCRIPT_NAME = "EDSSharedPlayEffect.server"
local CONTAINER_NAME = "EffectDesignerSuite"

local CLIENT_SCRIPT_SOURCE = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("EffectDesignerSuite")
local PlayEffect = require(SharedFolder:WaitForChild("PlayEffect"))

shared.PlayEffect = function(Target)
    return PlayEffect(Target)
end
]]

local SERVER_SCRIPT_SOURCE = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("EffectDesignerSuite")
local PlayEffect = require(SharedFolder:WaitForChild("PlayEffect"))

shared.PlayEffect = function(Target)
    return PlayEffect(Target)
end
]]

function VfxApiInjection.Enable(BinFolder : Instance)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local StarterPlayer = game:GetService("StarterPlayer")
    local ServerScriptService = game:GetService("ServerScriptService")

    local Container = ReplicatedStorage:FindFirstChild(CONTAINER_NAME)
    if not Container then
        Container = Instance.new("Folder")
        Container.Name = CONTAINER_NAME
        Container.Parent = ReplicatedStorage
    end

    local PlayEffectModule = Container:FindFirstChild("PlayEffect")
    if not PlayEffectModule then
        PlayEffectModule = BinFolder.PlaybackModules.PlayEffect:Clone()
        PlayEffectModule.Name = "PlayEffect"
        PlayEffectModule.Parent = Container
    end

    local SharedClientScript = StarterPlayer.StarterPlayerScripts:FindFirstChild(CLIENT_SCRIPT_NAME)
    if not SharedClientScript then
        SharedClientScript = Instance.new("LocalScript")
        SharedClientScript.Name = CLIENT_SCRIPT_NAME
        SharedClientScript.Source = CLIENT_SCRIPT_SOURCE
        SharedClientScript.Parent = StarterPlayer.StarterPlayerScripts
    end

    local SharedServerScript = ServerScriptService:FindFirstChild(SERVER_SCRIPT_NAME)
    if not SharedServerScript then
        SharedServerScript = Instance.new("Script")
        SharedServerScript.Name = SERVER_SCRIPT_NAME
        SharedServerScript.Source = SERVER_SCRIPT_SOURCE
        SharedServerScript.Parent = ServerScriptService
    end

    WorldSpaceAcceleration.EnsureScript()
end

function VfxApiInjection.Disable()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local StarterPlayer = game:GetService("StarterPlayer")
    local ServerScriptService = game:GetService("ServerScriptService")

    local SharedClientScript = StarterPlayer.StarterPlayerScripts:FindFirstChild(CLIENT_SCRIPT_NAME)
    if SharedClientScript then
        SharedClientScript:Destroy()
    end

    local SharedServerScript = ServerScriptService:FindFirstChild(SERVER_SCRIPT_NAME)
    if SharedServerScript then
        SharedServerScript:Destroy()
    end

    local Container = ReplicatedStorage:FindFirstChild(CONTAINER_NAME)
    if Container then
        local PlayEffectModule = Container:FindFirstChild("PlayEffect")
        if PlayEffectModule then
            PlayEffectModule:Destroy()
        end

        if #Container:GetChildren() == 0 then
            Container:Destroy()
        end
    end
end

return VfxApiInjection

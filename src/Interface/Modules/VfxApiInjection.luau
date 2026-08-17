local VfxApiInjection = {}

local WorldSpaceAcceleration = require(script.Parent.WorldSpaceAcceleration)

local CLIENT_SCRIPT_NAME = "EDSSharedPlayEffect.client"
local SERVER_SCRIPT_NAME = "EDSSharedPlayEffect.server"
local CONTAINER_NAME = "EffectDesignerSuite"
local SHARED_PACKAGE_NAMES = { "Seam", "Oklab" }

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

function VfxApiInjection.EnsureSharedModules(BinFolder : Instance)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local Container = ReplicatedStorage:FindFirstChild(CONTAINER_NAME)
    if not Container then
        Container = Instance.new("Folder")
        Container.Name = CONTAINER_NAME
        Container.Parent = ReplicatedStorage
    end

    if not Container:FindFirstChild("PlayEffect") then
        local PlayEffectModule = BinFolder.PlaybackModules.PlayEffect:Clone()
        PlayEffectModule.Name = "PlayEffect"
        PlayEffectModule.Parent = Container
    end

    if not Container:FindFirstChild("PartAnimation") then
        local PartAnimationModule = BinFolder.PlaybackModules:FindFirstChild("PartAnimation")
        if PartAnimationModule then
            local Clone = PartAnimationModule:Clone()
            Clone.Name = "PartAnimation"
            Clone.Parent = Container
        end
    end

    local Packages = BinFolder:FindFirstChild("Packages")
    if Packages then
        local Index = Packages:FindFirstChild("_Index")
        if Index and not Container:FindFirstChild("_Index") then
            Index:Clone().Parent = Container
        end

        for _, PackageName in SHARED_PACKAGE_NAMES do
            if not Container:FindFirstChild(PackageName) then
                local Source = Packages:FindFirstChild(PackageName)
                if Source then
                    Source:Clone().Parent = Container
                end
            end
        end
    end

    return Container
end

function VfxApiInjection.Enable(BinFolder : Instance)
    local StarterPlayer = game:GetService("StarterPlayer")
    local ServerScriptService = game:GetService("ServerScriptService")

    VfxApiInjection.EnsureSharedModules(BinFolder)

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

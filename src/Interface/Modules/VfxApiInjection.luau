local VfxApiInjection = {}

-- Constants
local CLIENT_SCRIPT_NAME = "EDSSharedPlayEffect.client"
local SERVER_SCRIPT_NAME = "EDSSharedPlayEffect.server"
local CONTAINER_NAME = "EffectDesignerSuite"
local SHARED_PACKAGE_NAMES = { "Seam", "Oklab" }

local CLIENT_SCRIPT_SOURCE = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("EffectDesignerSuite")
local PlayEffect = require(SharedFolder:WaitForChild("PlayEffect"))

shared.PlayEffect = function(target)
    return PlayEffect(target)
end
]]

local SERVER_SCRIPT_SOURCE = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("EffectDesignerSuite")
local PlayEffect = require(SharedFolder:WaitForChild("PlayEffect"))

shared.PlayEffect = function(target)
    return PlayEffect(target)
end
]]

-- Imports
local WorldSpaceAcceleration = require(script.Parent.WorldSpaceAcceleration)

local function ReplaceChild(container : Instance, name : string, template : Instance?)
    if not template then
        return nil
    end

    local Existing = container:FindFirstChild(name)
    if Existing then
        Existing:Destroy()
    end

    local Clone = template:Clone()
    Clone.Name = name
    Clone.Parent = container
    return Clone
end

function VfxApiInjection.EnsureSharedModules(binFolder : Instance)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local PlaybackModules = binFolder:FindFirstChild("PlaybackModules")
    if not PlaybackModules then
        return nil
    end

    local Container = ReplicatedStorage:FindFirstChild(CONTAINER_NAME)
    if not Container then
        Container = Instance.new("Folder")
        Container.Name = CONTAINER_NAME
        Container.Parent = ReplicatedStorage
    end

    ReplaceChild(Container, "PlayEffect", PlaybackModules:FindFirstChild("PlayEffect"))
    ReplaceChild(Container, "PartAnimation", PlaybackModules:FindFirstChild("PartAnimation"))

    local Packages = binFolder:FindFirstChild("Packages")
    if Packages then
        local Index = Packages:FindFirstChild("_Index")
        if Index and not Container:FindFirstChild("_Index") then
            Index:Clone().Parent = Container
        end

        for _, packageName in SHARED_PACKAGE_NAMES do
            if not Container:FindFirstChild(packageName) then
                local Source = Packages:FindFirstChild(packageName)
                if Source then
                    Source:Clone().Parent = Container
                end
            end
        end
    end

    return Container
end

function VfxApiInjection.Enable(binFolder : Instance)
    local StarterPlayer = game:GetService("StarterPlayer")
    local ServerScriptService = game:GetService("ServerScriptService")

    VfxApiInjection.EnsureSharedModules(binFolder)

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

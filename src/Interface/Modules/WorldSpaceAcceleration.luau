local WorldSpaceAcceleration = {}

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

WorldSpaceAcceleration.ATTRIBUTE_ENABLED = "WorldSpaceAcceleration"
WorldSpaceAcceleration.ATTRIBUTE_VECTOR = "WorldAcceleration"
WorldSpaceAcceleration.TAG = "EDSWorldSpaceAcceleration"
WorldSpaceAcceleration.SCRIPT_NAME = "EDSWorldSpaceAcceleration.client"

local Applying = setmetatable({}, {__mode = "k"})
local PreviewEmitters = {}
local PreviewConnection = nil

local function GetEmitterCFrame(Emitter)
    local Parent = Emitter.Parent
    if Parent and Parent:IsA("Attachment") then
        return Parent.WorldCFrame
    end
    if Parent and Parent:IsA("BasePart") then
        return Parent.CFrame
    end
    return nil
end

local function ApplyToEmitter(Emitter)
    if not Emitter.LockedToPart then
        return
    end

    local EmitterCFrame = GetEmitterCFrame(Emitter)
    if not EmitterCFrame then
        return
    end

    local World = Emitter:GetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR)
    if typeof(World) ~= "Vector3" then
        World = Emitter.Acceleration
        Emitter:SetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR, World)
    end

    local LocalAccel = EmitterCFrame:VectorToObjectSpace(World)
    if (Emitter.Acceleration - LocalAccel).Magnitude < 1e-4 then
        return
    end

    Applying[Emitter] = true
    Emitter.Acceleration = LocalAccel
    Applying[Emitter] = false
end

local function RestoreEmitter(Emitter)
    local Stored = Emitter:GetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR)
    if typeof(Stored) ~= "Vector3" then
        return
    end

    Applying[Emitter] = true
    Emitter.Acceleration = Stored
    Applying[Emitter] = false
end

WorldSpaceAcceleration.SCRIPT_SOURCE = [[
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "EDSWorldSpaceAcceleration"
local ATTR_ENABLED = "WorldSpaceAcceleration"
local ATTR_WORLD = "WorldAcceleration"

local Applying = setmetatable({}, {__mode = "k"})
local WorldAccel = setmetatable({}, {__mode = "k"})

local function GetEmitterCFrame(Emitter)
	local Parent = Emitter.Parent
	if Parent and Parent:IsA("Attachment") then
		return Parent.WorldCFrame
	end
	if Parent and Parent:IsA("BasePart") then
		return Parent.CFrame
	end
	return nil
end

local function BindEmitter(Emitter)
	local Stored = Emitter:GetAttribute(ATTR_WORLD)
	if typeof(Stored) == "Vector3" then
		WorldAccel[Emitter] = Stored
	else
		WorldAccel[Emitter] = Emitter.Acceleration
		Emitter:SetAttribute(ATTR_WORLD, Emitter.Acceleration)
	end
end

local function UnbindEmitter(Emitter)
	WorldAccel[Emitter] = nil
	Applying[Emitter] = nil
end

local function RememberWorldAcceleration(Emitter)
	if Applying[Emitter] then
		return
	end

	WorldAccel[Emitter] = Emitter.Acceleration
	Emitter:SetAttribute(ATTR_WORLD, Emitter.Acceleration)
end

local function ApplyWorldAcceleration(Emitter)
	if not Emitter.LockedToPart then
		return
	end

	local EmitterCFrame = GetEmitterCFrame(Emitter)
	if not EmitterCFrame then
		return
	end

	local World = WorldAccel[Emitter]
	if typeof(World) ~= "Vector3" then
		local Stored = Emitter:GetAttribute(ATTR_WORLD)
		World = if typeof(Stored) == "Vector3" then Stored else Emitter.Acceleration
		WorldAccel[Emitter] = World
	end

	local LocalAccel = EmitterCFrame:VectorToObjectSpace(World)
	if (Emitter.Acceleration - LocalAccel).Magnitude < 1e-4 then
		return
	end

	Applying[Emitter] = true
	Emitter.Acceleration = LocalAccel
	Applying[Emitter] = false
end

local Success, Collection = pcall(function()
	return CollectionService:CreateCollection("ParticleEmitter." .. TAG, workspace)
end)

if Success and Collection then
	Collection.OnAdded = BindEmitter
	Collection.OnRemoved = UnbindEmitter
	Collection.OnHeartbeat = ApplyWorldAcceleration
	pcall(function()
		Collection.OnPropertyChanged.Acceleration = RememberWorldAcceleration
	end)
else
	local function Track(Instance)
		if Instance:IsA("ParticleEmitter") then
			BindEmitter(Instance)
		end
	end

	for _, Instance in CollectionService:GetTagged(TAG) do
		Track(Instance)
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(Track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(Instance)
		UnbindEmitter(Instance)
	end)

	RunService.Heartbeat:Connect(function()
		for _, Instance in CollectionService:GetTagged(TAG) do
			if Instance:IsA("ParticleEmitter") then
				ApplyWorldAcceleration(Instance)
			end
		end
	end)
end
]]

function WorldSpaceAcceleration.IsEnabled(Emitter : Instance) : boolean
    return Emitter:IsA("ParticleEmitter") and Emitter:GetAttribute(WorldSpaceAcceleration.ATTRIBUTE_ENABLED) == true
end

function WorldSpaceAcceleration.GetAuthoredAcceleration(Emitter : ParticleEmitter) : Vector3
    if WorldSpaceAcceleration.IsEnabled(Emitter) then
        local Stored = Emitter:GetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR)
        if typeof(Stored) == "Vector3" then
            return Stored
        end
    end

    return Emitter.Acceleration
end

function WorldSpaceAcceleration.GetSimulationAcceleration(Emitter : ParticleEmitter, EmitterCFrame : CFrame, LockedToPart : boolean) : Vector3
    local Authored = WorldSpaceAcceleration.GetAuthoredAcceleration(Emitter)

    if LockedToPart and WorldSpaceAcceleration.IsEnabled(Emitter) then
        return EmitterCFrame:VectorToObjectSpace(Authored)
    end

    return Authored
end

function WorldSpaceAcceleration.WatchEmitPreview(Emitter : Instance, Duration : number)
    if not WorldSpaceAcceleration.IsEnabled(Emitter) then
        return
    end

    local ExpireAt = os.clock() + math.max(Duration, 0.05) + 0.1
    PreviewEmitters[Emitter] = math.max(PreviewEmitters[Emitter] or 0, ExpireAt)
    ApplyToEmitter(Emitter)

    if PreviewConnection then
        return
    end

    PreviewConnection = RunService.Heartbeat:Connect(function()
        local Now = os.clock()

        for TrackedEmitter, TrackedExpireAt in PreviewEmitters do
            if not TrackedEmitter.Parent or Now >= TrackedExpireAt then
                if TrackedEmitter.Parent then
                    RestoreEmitter(TrackedEmitter)
                end

                PreviewEmitters[TrackedEmitter] = nil
            else
                ApplyToEmitter(TrackedEmitter)
            end
        end

        if next(PreviewEmitters) == nil and PreviewConnection then
            PreviewConnection:Disconnect()
            PreviewConnection = nil
        end
    end)
end

function WorldSpaceAcceleration.EnsureScript()
    local StarterPlayer = game:GetService("StarterPlayer")
    local StarterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
    if not StarterPlayerScripts then
        return
    end

    local Existing = StarterPlayerScripts:FindFirstChild(WorldSpaceAcceleration.SCRIPT_NAME)
    if Existing and Existing:IsA("LocalScript") then
        Existing.Source = WorldSpaceAcceleration.SCRIPT_SOURCE
        return
    end

    if Existing then
        Existing:Destroy()
    end

    local Script = Instance.new("LocalScript")
    Script.Name = WorldSpaceAcceleration.SCRIPT_NAME
    Script.Source = WorldSpaceAcceleration.SCRIPT_SOURCE
    Script.Parent = StarterPlayerScripts
end

function WorldSpaceAcceleration.SetEnabled(Emitter : ParticleEmitter, Enabled : boolean)
    if Enabled then
        Emitter:SetAttribute(WorldSpaceAcceleration.ATTRIBUTE_ENABLED, true)
        local Stored = Emitter:GetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR)
        if typeof(Stored) ~= "Vector3" then
            Emitter:SetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR, Emitter.Acceleration)
        end
        CollectionService:AddTag(Emitter, WorldSpaceAcceleration.TAG)
        WorldSpaceAcceleration.EnsureScript()
        return
    end

    PreviewEmitters[Emitter] = nil
    RestoreEmitter(Emitter)

    Emitter:SetAttribute(WorldSpaceAcceleration.ATTRIBUTE_ENABLED, nil)
    Emitter:SetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR, nil)
    CollectionService:RemoveTag(Emitter, WorldSpaceAcceleration.TAG)
end

return WorldSpaceAcceleration

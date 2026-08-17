local WorldSpaceAcceleration = {}

-- Constants
local ACCELERATION_EPSILON = 1e-4
local PREVIEW_MIN_DURATION = 0.05
local PREVIEW_EXTRA_TIME = 0.1
WorldSpaceAcceleration.ATTRIBUTE_ENABLED = "WorldSpaceAcceleration"
WorldSpaceAcceleration.ATTRIBUTE_VECTOR = "WorldAcceleration"
WorldSpaceAcceleration.TAG = "EDSWorldSpaceAcceleration"
WorldSpaceAcceleration.SCRIPT_NAME = "EDSWorldSpaceAcceleration.client"

-- Services
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- Variables
local Applying = setmetatable({}, {__mode = "k"})
local PreviewEmitters = {}
local PreviewConnection = nil

local function GetEmitterCFrame(emitter)
    local Parent = emitter.Parent
    if Parent and Parent:IsA("Attachment") then
        return Parent.WorldCFrame
    end
    if Parent and Parent:IsA("BasePart") then
        return Parent.CFrame
    end
    return nil
end

local function ApplyToEmitter(emitter)
    if not emitter.LockedToPart then
        return
    end

    local EmitterCFrame = GetEmitterCFrame(emitter)
    if not EmitterCFrame then
        return
    end

    local World = emitter:GetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR)
    if typeof(World) ~= "Vector3" then
        World = emitter.Acceleration
        emitter:SetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR, World)
    end

    local LocalAccel = EmitterCFrame:VectorToObjectSpace(World)
    if (emitter.Acceleration - LocalAccel).Magnitude < ACCELERATION_EPSILON then
        return
    end

    Applying[emitter] = true
    emitter.Acceleration = LocalAccel
    Applying[emitter] = false
end

local function RestoreEmitter(emitter)
    local Stored = emitter:GetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR)
    if typeof(Stored) ~= "Vector3" then
        return
    end

    Applying[emitter] = true
    emitter.Acceleration = Stored
    Applying[emitter] = false
end

WorldSpaceAcceleration.SCRIPT_SOURCE = [[
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "EDSWorldSpaceAcceleration"
local ATTR_ENABLED = "WorldSpaceAcceleration"
local ATTR_WORLD = "WorldAcceleration"

local Applying = setmetatable({}, {__mode = "k"})
local WorldAccel = setmetatable({}, {__mode = "k"})

local function GetEmitterCFrame(emitter)
	local Parent = emitter.Parent
	if Parent and Parent:IsA("Attachment") then
		return Parent.WorldCFrame
	end
	if Parent and Parent:IsA("BasePart") then
		return Parent.CFrame
	end
	return nil
end

local function BindEmitter(emitter)
	local Stored = emitter:GetAttribute(ATTR_WORLD)
	if typeof(Stored) == "Vector3" then
		WorldAccel[emitter] = Stored
	else
		WorldAccel[emitter] = emitter.Acceleration
		emitter:SetAttribute(ATTR_WORLD, emitter.Acceleration)
	end
end

local function UnbindEmitter(emitter)
	WorldAccel[emitter] = nil
	Applying[emitter] = nil
end

local function RememberWorldAcceleration(emitter)
	if Applying[emitter] then
		return
	end

	WorldAccel[emitter] = emitter.Acceleration
	emitter:SetAttribute(ATTR_WORLD, emitter.Acceleration)
end

local function ApplyWorldAcceleration(emitter)
	if not emitter.LockedToPart then
		return
	end

	local EmitterCFrame = GetEmitterCFrame(emitter)
	if not EmitterCFrame then
		return
	end

	local World = WorldAccel[emitter]
	if typeof(World) ~= "Vector3" then
		local Stored = emitter:GetAttribute(ATTR_WORLD)
		World = if typeof(Stored) == "Vector3" then Stored else emitter.Acceleration
		WorldAccel[emitter] = World
	end

	local LocalAccel = EmitterCFrame:VectorToObjectSpace(World)
	if (emitter.Acceleration - LocalAccel).Magnitude < 1e-4 then
		return
	end

	Applying[emitter] = true
	emitter.Acceleration = LocalAccel
	Applying[emitter] = false
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
	local function Track(instance)
		if instance:IsA("ParticleEmitter") then
			BindEmitter(instance)
		end
	end

	for _, instance in CollectionService:GetTagged(TAG) do
		Track(instance)
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(Track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		UnbindEmitter(instance)
	end)

	RunService.Heartbeat:Connect(function()
		for _, instance in CollectionService:GetTagged(TAG) do
			if instance:IsA("ParticleEmitter") then
				ApplyWorldAcceleration(instance)
			end
		end
	end)
end
]]

function WorldSpaceAcceleration.IsEnabled(emitter : Instance) : boolean
    return emitter:IsA("ParticleEmitter") and emitter:GetAttribute(WorldSpaceAcceleration.ATTRIBUTE_ENABLED) == true
end

function WorldSpaceAcceleration.GetAuthoredAcceleration(emitter : ParticleEmitter) : Vector3
    if WorldSpaceAcceleration.IsEnabled(emitter) then
        local Stored = emitter:GetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR)
        if typeof(Stored) == "Vector3" then
            return Stored
        end
    end

    return emitter.Acceleration
end

function WorldSpaceAcceleration.GetSimulationAcceleration(emitter : ParticleEmitter, emitterCFrame : CFrame, lockedToPart : boolean) : Vector3
    local Authored = WorldSpaceAcceleration.GetAuthoredAcceleration(emitter)

    if lockedToPart and WorldSpaceAcceleration.IsEnabled(emitter) then
        return emitterCFrame:VectorToObjectSpace(Authored)
    end

    return Authored
end

function WorldSpaceAcceleration.WatchEmitPreview(emitter : Instance, duration : number)
    if not WorldSpaceAcceleration.IsEnabled(emitter) then
        return
    end

    local ExpireAt = os.clock() + math.max(duration, PREVIEW_MIN_DURATION) + PREVIEW_EXTRA_TIME
    PreviewEmitters[emitter] = math.max(PreviewEmitters[emitter] or 0, ExpireAt)
    ApplyToEmitter(emitter)

    if PreviewConnection then
        return
    end

    PreviewConnection = RunService.Heartbeat:Connect(function()
        local Now = os.clock()

        for trackedEmitter, trackedExpireAt in PreviewEmitters do
            if not trackedEmitter.Parent or Now >= trackedExpireAt then
                if trackedEmitter.Parent then
                    RestoreEmitter(trackedEmitter)
                end

                PreviewEmitters[trackedEmitter] = nil
            else
                ApplyToEmitter(trackedEmitter)
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

function WorldSpaceAcceleration.SetEnabled(emitter : ParticleEmitter, enabled : boolean)
    if enabled then
        emitter:SetAttribute(WorldSpaceAcceleration.ATTRIBUTE_ENABLED, true)
        local Stored = emitter:GetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR)
        if typeof(Stored) ~= "Vector3" then
            emitter:SetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR, emitter.Acceleration)
        end
        CollectionService:AddTag(emitter, WorldSpaceAcceleration.TAG)
        WorldSpaceAcceleration.EnsureScript()
        return
    end

    PreviewEmitters[emitter] = nil
    RestoreEmitter(emitter)

    emitter:SetAttribute(WorldSpaceAcceleration.ATTRIBUTE_ENABLED, nil)
    emitter:SetAttribute(WorldSpaceAcceleration.ATTRIBUTE_VECTOR, nil)
    CollectionService:RemoveTag(emitter, WorldSpaceAcceleration.TAG)
end

return WorldSpaceAcceleration

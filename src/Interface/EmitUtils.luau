local EmitUtils = {}

-- Constants
local PATH_PREVIEW_FOLDER_NAME = "EffectDesignerSuitePathPreview"

-- Services
local RunService = game:GetService("RunService")

-- Imports
local Bin = script.Parent.Parent
local Objects = Bin:FindFirstChild("Objects")
local PlayEffect = require(Bin.PlaybackModules:FindFirstChild("PlayEffect"))
local States = require(Objects:FindFirstChild("States"))
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local WorldSpaceAcceleration = require(script.Parent:FindFirstChild("Modules"):FindFirstChild("WorldSpaceAcceleration"))

-- Variables
local RepeatEmitConnection = nil
local Widget = nil
local PathPreviewFolder = nil
local PathPreviewConnections = {}
local PathPreviewHeartbeatConnection = nil
local PathPreviewHeartbeatElapsed = 0
local LastPathPreviewSignature = nil
local PathPreviewInstanceIds = setmetatable({}, {__mode = "k"})
local NextPathPreviewInstanceId = 0
local PathPreviewDescendantConnection = nil

local function ConfigurePreviewInstance(instance : Instance)
    instance.Archivable = false

    if instance:IsA("BasePart") then
        instance.Locked = true
    end
end

local function DisconnectPathPreviewConnections()
    for _, connection in PathPreviewConnections do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end

    table.clear(PathPreviewConnections)
end

local function BindPreviewFolder(folder : Folder)
    folder.Archivable = false
    ConfigurePreviewInstance(folder)

    if PathPreviewDescendantConnection then
        PathPreviewDescendantConnection:Disconnect()
    end

    PathPreviewDescendantConnection = folder.DescendantAdded:Connect(ConfigurePreviewInstance)

    for _, descendant in folder:GetDescendants() do
        ConfigurePreviewInstance(descendant)
    end
end

local function GetPreviewFolder()
    if PathPreviewFolder and PathPreviewFolder.Parent then
        return PathPreviewFolder
    end

    local Folder = workspace:FindFirstChild(PATH_PREVIEW_FOLDER_NAME)
    if not Folder then
        Folder = Instance.new("Folder")
        Folder.Name = PATH_PREVIEW_FOLDER_NAME
        Folder.Archivable = false
        Folder.Parent = workspace
    end

    BindPreviewFolder(Folder)
    PathPreviewFolder = Folder
    return Folder
end

local function ClearPathPreview()
    if not PathPreviewFolder then
        return
    end

    for _, child in PathPreviewFolder:GetChildren() do
        child:Destroy()
    end
end

local function DrawPathSegment(fromPosition : Vector3, toPosition : Vector3, parent : Instance)
    local Delta = toPosition - fromPosition
    local Length = Delta.Magnitude

    if Length <= 0.001 then
        return
    end

    local StartPart = Instance.new("Part")
    StartPart.Name = "PathStart"
    StartPart.Anchored = true
    StartPart.CanCollide = false
    StartPart.CanTouch = false
    StartPart.CanQuery = false
    StartPart.Transparency = 1
    StartPart.Size = Vector3.new(0.1, 0.1, 0.1)
    StartPart.CFrame = CFrame.new(fromPosition)
    StartPart.Parent = parent

    local EndPart = Instance.new("Part")
    EndPart.Name = "PathEnd"
    EndPart.Anchored = true
    EndPart.CanCollide = false
    EndPart.CanTouch = false
    EndPart.CanQuery = false
    EndPart.Transparency = 1
    EndPart.Size = Vector3.new(0.1, 0.1, 0.1)
    EndPart.CFrame = CFrame.new(toPosition)
    EndPart.Parent = parent

    local StartAttachment = Instance.new("Attachment")
    StartAttachment.Parent = StartPart

    local EndAttachment = Instance.new("Attachment")
    EndAttachment.Parent = EndPart

    local Beam = Instance.new("Beam")
    Beam.Name = "PathSegment"
    Beam.Attachment0 = StartAttachment
    Beam.Attachment1 = EndAttachment
    Beam.Width0 = 0.045
    Beam.Width1 = 0.045
    Beam.Color = ColorSequence.new(Color3.fromRGB(70, 180, 255))
    Beam.Brightness = 2
    Beam.LightEmission = 1
    Beam.FaceCamera = true
    Beam.Parent = parent
end

local function DrawPointMarker(position : Vector3, parent : Instance, name : string, color : Color3, size : number?)
    local MarkerSize = size or 0.22
    local Marker = Instance.new("Part")
    Marker.Name = name
    Marker.Anchored = true
    Marker.CanCollide = false
    Marker.CanTouch = false
    Marker.CanQuery = false
    Marker.Material = Enum.Material.Neon
    Marker.Color = color
    Marker.Shape = Enum.PartType.Ball
    Marker.Size = Vector3.new(MarkerSize, MarkerSize, MarkerSize)
    Marker.CFrame = CFrame.new(position)
    Marker.Parent = parent
end

local function DrawControlSegment(fromPosition : Vector3, toPosition : Vector3, parent : Instance)
    local Delta = toPosition - fromPosition
    if Delta.Magnitude <= 0.001 then
        return
    end

    local Part = Instance.new("Part")
    Part.Name = "ControlSegment"
    Part.Anchored = true
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.Material = Enum.Material.Neon
    Part.Color = Color3.fromRGB(255, 190, 75)
    Part.Size = Vector3.new(0.05, 0.05, Delta.Magnitude)
    Part.CFrame = CFrame.lookAt(fromPosition, toPosition) * CFrame.new(0, 0, -Delta.Magnitude * 0.5)
    Part.Parent = parent
end

local function DrawParticlePathSegment(fromPosition : Vector3, toPosition : Vector3, parent : Instance)
    local Delta = toPosition - fromPosition
    if Delta.Magnitude <= 0.001 then
        return
    end

    local Part = Instance.new("Part")
    Part.Name = "ParticlePathSegment"
    Part.Anchored = true
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.Material = Enum.Material.Neon
    Part.Color = Color3.fromRGB(185, 105, 255)
    Part.Transparency = 0.15
    Part.Size = Vector3.new(0.04, 0.04, Delta.Magnitude)
    Part.CFrame = CFrame.lookAt(fromPosition, toPosition) * CFrame.new(0, 0, -Delta.Magnitude * 0.5)
    Part.Parent = parent
end

local function GetEmitterWorldCFrame(emitter : ParticleEmitter)
    local Parent = emitter.Parent
    if Parent and Parent:IsA("Attachment") then
        return Parent.WorldCFrame
    end
    if Parent and Parent:IsA("BasePart") then
        return Parent.CFrame
    end
    return nil
end

local function GetLocalEmissionDirection(direction : Enum.NormalId)
    if direction == Enum.NormalId.Top then
        return Vector3.new(0, 1, 0)
    elseif direction == Enum.NormalId.Bottom then
        return Vector3.new(0, -1, 0)
    elseif direction == Enum.NormalId.Right then
        return Vector3.new(1, 0, 0)
    elseif direction == Enum.NormalId.Left then
        return Vector3.new(-1, 0, 0)
    elseif direction == Enum.NormalId.Back then
        return Vector3.new(0, 0, 1)
    end
    return Vector3.new(0, 0, -1)
end

local function GetSpreadAxes(direction : Enum.NormalId)
    if direction == Enum.NormalId.Top or direction == Enum.NormalId.Bottom then
        return Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
    elseif direction == Enum.NormalId.Front or direction == Enum.NormalId.Back then
        return Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
    end
    return Vector3.new(0, 0, 1), Vector3.new(0, 1, 0)
end

local function ApplySpread(direction : Vector3, firstTargetAxis : Vector3, firstAngle : number, secondTargetAxis : Vector3, secondAngle : number)
    local FirstRotationAxis = direction:Cross(firstTargetAxis).Unit
    local SecondRotationAxis = direction:Cross(secondTargetAxis).Unit
    local FirstRotation = CFrame.fromAxisAngle(FirstRotationAxis, firstAngle)
    local SecondRotation = CFrame.fromAxisAngle(SecondRotationAxis, secondAngle)
    return SecondRotation:VectorToWorldSpace(FirstRotation:VectorToWorldSpace(direction)).Unit
end

local function AddUniqueVector(list, seen, value : Vector3)
    local Key = string.format("%.4f,%.4f,%.4f", value.X, value.Y, value.Z)
    if seen[Key] then
        return
    end

    seen[Key] = true
    table.insert(list, value)
end

local function CollectSpreadDirections(localDirection : Vector3, firstAxis : Vector3, secondAxis : Vector3, firstAngle : number, secondAngle : number)
    local Directions = {}
    local Seen = {}
    AddUniqueVector(Directions, Seen, localDirection)

    if firstAngle <= 0.0001 and secondAngle <= 0.0001 then
        return Directions
    end

    local RingCount = 8
    for index = 0, RingCount - 1 do
        local Tau = index / RingCount * math.pi * 2
        AddUniqueVector(
            Directions,
            Seen,
            ApplySpread(localDirection, firstAxis, math.cos(Tau) * firstAngle, secondAxis, math.sin(Tau) * secondAngle)
        )
    end

    if firstAngle > 0.25 or secondAngle > 0.25 then
        for index = 0, RingCount - 1 do
            local Tau = (index + 0.5) / RingCount * math.pi * 2
            AddUniqueVector(
                Directions,
                Seen,
                ApplySpread(localDirection, firstAxis, math.cos(Tau) * firstAngle * 0.5, secondAxis, math.sin(Tau) * secondAngle * 0.5)
            )
        end
    end

    return Directions
end

local function GetPerpendicularExtents(half : Vector3, axis : Vector3)
    if math.abs(axis.X) > 0.5 then
        return math.min(half.Y, half.Z), half.X
    elseif math.abs(axis.Y) > 0.5 then
        return math.min(half.X, half.Z), half.Y
    end

    return math.min(half.X, half.Y), half.Z
end

local function CollectRingOffsets(offsets, seen, center : Vector3, firstAxis : Vector3, secondAxis : Vector3, radius : number, count : number)
    if radius <= 0.001 then
        AddUniqueVector(offsets, seen, center)
        return
    end

    for index = 0, count - 1 do
        local Tau = index / count * math.pi * 2
        AddUniqueVector(offsets, seen, center + firstAxis * (math.cos(Tau) * radius) + secondAxis * (math.sin(Tau) * radius))
    end
end

local function CollectSpawnOffsets(emitter : ParticleEmitter, half : Vector3, localDirection : Vector3, firstAxis : Vector3, secondAxis : Vector3)
    local Offsets = {}
    local Seen = {}
    local IsVolume = emitter.ShapeStyle ~= Enum.ParticleEmitterShapeStyle.Surface

    if half.Magnitude <= 0.001 then
        AddUniqueVector(Offsets, Seen, Vector3.zero)
        return Offsets
    end

    if IsVolume then
        AddUniqueVector(Offsets, Seen, Vector3.zero)
    end

    local Shape = emitter.Shape
    local Partial = math.clamp(emitter.ShapePartial, 0, 1)

    if Shape == Enum.ParticleEmitterShape.Sphere then
        local Radius = math.min(half.X, half.Y, half.Z)
        local MaxPolar = math.pi * Partial
        AddUniqueVector(Offsets, Seen, localDirection * Radius)

        if MaxPolar > 0.05 then
            local RingRadius = math.sin(MaxPolar) * Radius
            local RingAlong = math.cos(MaxPolar) * Radius
            CollectRingOffsets(Offsets, Seen, localDirection * RingAlong, firstAxis, secondAxis, RingRadius, 8)
        end

        if MaxPolar > math.pi * 0.66 then
            AddUniqueVector(Offsets, Seen, -localDirection * Radius)
        end
    elseif Shape == Enum.ParticleEmitterShape.Cylinder then
        local Radius, HalfHeight = GetPerpendicularExtents(half, localDirection)
        local FrontRadius = Radius * Partial
        CollectRingOffsets(Offsets, Seen, localDirection * HalfHeight, firstAxis, secondAxis, FrontRadius, 8)
        CollectRingOffsets(Offsets, Seen, -localDirection * HalfHeight, firstAxis, secondAxis, Radius, 8)
        if IsVolume then
            AddUniqueVector(Offsets, Seen, localDirection * HalfHeight)
            AddUniqueVector(Offsets, Seen, -localDirection * HalfHeight)
        end
    elseif Shape == Enum.ParticleEmitterShape.Disc then
        local Radius = GetPerpendicularExtents(half, localDirection)
        local InnerRadius = Radius * Partial
        CollectRingOffsets(Offsets, Seen, Vector3.zero, firstAxis, secondAxis, Radius, 8)
        if InnerRadius > 0.001 and math.abs(Radius - InnerRadius) > 0.001 then
            CollectRingOffsets(Offsets, Seen, Vector3.zero, firstAxis, secondAxis, InnerRadius, 8)
        end
    else
        for _, x in {-1, 1} do
            for _, y in {-1, 1} do
                for _, z in {-1, 1} do
                    AddUniqueVector(Offsets, Seen, Vector3.new(x * half.X, y * half.Y, z * half.Z))
                end
            end
        end

        AddUniqueVector(Offsets, Seen, Vector3.new(half.X, 0, 0))
        AddUniqueVector(Offsets, Seen, Vector3.new(-half.X, 0, 0))
        AddUniqueVector(Offsets, Seen, Vector3.new(0, half.Y, 0))
        AddUniqueVector(Offsets, Seen, Vector3.new(0, -half.Y, 0))
        AddUniqueVector(Offsets, Seen, Vector3.new(0, 0, half.Z))
        AddUniqueVector(Offsets, Seen, Vector3.new(0, 0, -half.Z))
    end

    return Offsets
end

local function ApplyShapeInOut(directions, shapeInOut)
    if shapeInOut == Enum.ParticleEmitterShapeInOut.Inward then
        local Inward = {}
        for _, direction in directions do
            table.insert(Inward, -direction)
        end
        return Inward
    elseif shapeInOut == Enum.ParticleEmitterShapeInOut.InAndOut then
        local Both = table.clone(directions)
        for _, direction in directions do
            table.insert(Both, -direction)
        end
        return Both
    end

    return directions
end

local function StepParticle(position : Vector3, velocity : Vector3, acceleration : Vector3, drag : number, deltaTime : number, wind : Vector3)
    -- ParticleEmitter.Drag is a half-life rate, so Roblox scales velocity by
    -- 2^(-Drag * dt) after applying acceleration. With wind, drag pulls toward
    -- the wind vector instead of toward zero.
    local RelativeVelocity = velocity - wind
    local NewRelativeVelocity = (RelativeVelocity + acceleration * deltaTime) * (2 ^ (-drag * deltaTime))
    local NewVelocity = NewRelativeVelocity + wind
    local NewPosition = position + (velocity + NewVelocity) * (0.5 * deltaTime)
    return NewPosition, NewVelocity
end

local function BuildParticleEmitterPathPreview(emitter : ParticleEmitter, parent : Instance)
    local EmitterCFrame = GetEmitterWorldCFrame(emitter)
    if not EmitterCFrame then
        return
    end

    local LocalDirection = GetLocalEmissionDirection(emitter.EmissionDirection)
    local Spread = emitter.SpreadAngle
    local FirstAxis, SecondAxis = GetSpreadAxes(emitter.EmissionDirection)
    local FirstAngle = math.rad(math.min(Spread.X, 180))
    local SecondAngle = math.rad(math.min(Spread.Y, 180))
    local SpreadDirections = CollectSpreadDirections(LocalDirection, FirstAxis, SecondAxis, FirstAngle, SecondAngle)
    local EmitDirections = ApplyShapeInOut(SpreadDirections, emitter.ShapeInOut)

    local EmitterParent = emitter.Parent
    local SourcePart = if EmitterParent and EmitterParent:IsA("BasePart")
        then EmitterParent
        elseif EmitterParent
            and EmitterParent:IsA("Attachment")
            and EmitterParent.Parent
            and EmitterParent.Parent:IsA("BasePart")
        then EmitterParent.Parent
        else nil
    local HalfSize = if EmitterParent and EmitterParent:IsA("BasePart")
        then EmitterParent.Size * 0.5
        else Vector3.zero
    local SpawnOffsets = CollectSpawnOffsets(emitter, HalfSize, LocalDirection, FirstAxis, SecondAxis)

    local Origin = EmitterCFrame.Position
    local MinimumSpeed = emitter.Speed.Min
    local MaximumSpeed = emitter.Speed.Max
    local RepresentativeSpeed = if MinimumSpeed <= 0 and MaximumSpeed >= 0
        then (if math.abs(MinimumSpeed) > math.abs(MaximumSpeed) then MinimumSpeed else MaximumSpeed)
        else (MinimumSpeed + MaximumSpeed) * 0.5
    local HasSpeedRange = math.abs(MaximumSpeed - MinimumSpeed) > 0.001
    local MaxLifetime = math.clamp(emitter.Lifetime.Max, 0.01, 20)
    local MinLifetime = math.clamp(emitter.Lifetime.Min, 0, MaxLifetime)
    local SimSteps = 48
    local DeltaTime = MaxLifetime / SimSteps
    local LockedToPart = emitter.LockedToPart
    local InheritedVelocity = Vector3.zero
    local Wind = Vector3.zero

    if SourcePart and not LockedToPart then
        InheritedVelocity = SourcePart.AssemblyLinearVelocity * emitter.VelocityInheritance
    end

    if emitter.WindAffectsDrag and emitter.Drag > 0 then
        local GlobalWind = workspace.GlobalWind
        if LockedToPart then
            Wind = EmitterCFrame:VectorToObjectSpace(GlobalWind)
        else
            Wind = GlobalWind
        end
    end

    local function ToWorldPosition(position : Vector3)
        if LockedToPart then
            return EmitterCFrame:PointToWorldSpace(position)
        end

        return position
    end

    local function DrawTrajectory(localOffset : Vector3, direction : Vector3, speed : number)
        local Position = if LockedToPart then localOffset else EmitterCFrame:PointToWorldSpace(localOffset)
        local Velocity = if LockedToPart
            then direction.Unit * speed
            else EmitterCFrame:VectorToWorldSpace(direction).Unit * speed + InheritedVelocity
        local Acceleration = WorldSpaceAcceleration.GetSimulationAcceleration(emitter, EmitterCFrame, LockedToPart)
        local LastWorldPosition = ToWorldPosition(Position)
        local MinLifetimePosition = nil

        for step = 1, SimSteps do
            local NextPosition, NextVelocity = StepParticle(Position, Velocity, Acceleration, emitter.Drag, DeltaTime, Wind)
            local NextWorldPosition = ToWorldPosition(NextPosition)

            if MinLifetimePosition == nil and (step * DeltaTime) >= MinLifetime then
                MinLifetimePosition = NextWorldPosition
            end

            if step == SimSteps or step % 2 == 0 then
                DrawParticlePathSegment(LastWorldPosition, NextWorldPosition, parent)
                LastWorldPosition = NextWorldPosition
            end

            Position = NextPosition
            Velocity = NextVelocity
        end

        DrawPointMarker(LastWorldPosition, parent, "ParticlePathEnd", Color3.fromRGB(255, 150, 220), 0.12)

        if MinLifetimePosition and MinLifetime > 0.05 and (MaxLifetime - MinLifetime) > 0.05 then
            DrawPointMarker(MinLifetimePosition, parent, "ParticlePathMinLifetime", Color3.fromRGB(160, 90, 220), 0.1)
        end
    end

    DrawPointMarker(Origin, parent, "ParticleEmitterOrigin", Color3.fromRGB(205, 135, 255), 0.24)

    for _, direction in EmitDirections do
        DrawTrajectory(Vector3.zero, direction, RepresentativeSpeed)
    end

    if HasSpeedRange then
        DrawTrajectory(Vector3.zero, EmitDirections[1], MinimumSpeed)
        DrawTrajectory(Vector3.zero, EmitDirections[1], MaximumSpeed)
    end

    for _, offset in SpawnOffsets do
        if offset.Magnitude <= 0.001 then
            continue
        end

        DrawPointMarker(EmitterCFrame:PointToWorldSpace(offset), parent, "ParticleSpawn", Color3.fromRGB(155, 95, 210), 0.14)
        DrawTrajectory(offset, EmitDirections[1], RepresentativeSpeed)

        if emitter.ShapeInOut == Enum.ParticleEmitterShapeInOut.InAndOut then
            DrawTrajectory(offset, -EmitDirections[1], RepresentativeSpeed)
        end
    end
end

local function EvaluateBezier(controlPoints : {Vector3}, t : number)
    local Working = table.clone(controlPoints)

    while #Working > 1 do
        local NextWorking = {}

        for index = 1, #Working - 1 do
            table.insert(NextWorking, Working[index]:Lerp(Working[index + 1], t))
        end

        Working = NextWorking
    end

    return Working[1]
end

local function BuildIndicatorPathPreview(animationIndicator : StringValue, parent : Instance)
    if not animationIndicator.Parent then
        return
    end

    local Host = animationIndicator.Parent
    local Origin = Host:FindFirstChild("Origin")
    local Target = Host:FindFirstChild("Target")

    if not Origin or not Target or not Origin:IsA("Attachment") or not Target:IsA("Attachment") then
        return
    end

    if animationIndicator.Value == "Tween" then
        DrawPathSegment(Origin.WorldPosition, Target.WorldPosition, parent)
        return
    end

    if animationIndicator.Value == "Bezier" then
        local Points = {Origin.WorldPosition}
        local Midpoints = {}

        for _, child in Host:GetChildren() do
            if child:IsA("Attachment") and child.Name:match("^Midpoint%d+$") then
                table.insert(Midpoints, child)
            end
        end

        table.sort(Midpoints, function(left, right)
            local LeftIndex = tonumber(left.Name:match("^Midpoint(%d+)$")) or 0
            local RightIndex = tonumber(right.Name:match("^Midpoint(%d+)$")) or 0
            return LeftIndex < RightIndex
        end)

        for _, midpoint in Midpoints do
            table.insert(Points, midpoint.WorldPosition)
        end

        table.insert(Points, Target.WorldPosition)

        for index = 1, #Points do
            if index == 1 then
                DrawPointMarker(Points[index], parent, "OriginMarker", Color3.fromRGB(95, 210, 255))
            elseif index == #Points then
                DrawPointMarker(Points[index], parent, "TargetMarker", Color3.fromRGB(120, 255, 130))
            else
                DrawPointMarker(Points[index], parent, "MidpointMarker", Color3.fromRGB(255, 205, 90))
            end

            if index < #Points then
                DrawControlSegment(Points[index], Points[index + 1], parent)
            end
        end

        local Last = Points[1]
        local Steps = 50

        for step = 1, Steps do
            local T = step / Steps
            local Current = EvaluateBezier(Points, T)
            DrawPathSegment(Last, Current, parent)
            Last = Current
        end
    end
end

local function GetPathPreviewInstanceId(instance : Instance)
    local ExistingId = PathPreviewInstanceIds[instance]
    if ExistingId then
        return ExistingId
    end

    NextPathPreviewInstanceId += 1
    PathPreviewInstanceIds[instance] = NextPathPreviewInstanceId
    return NextPathPreviewInstanceId
end

local function GetIndicatorPathSignature(indicator : StringValue)
    local Values = {
        "Indicator",
        tostring(GetPathPreviewInstanceId(indicator)),
        indicator.Value,
    }
    local Host = indicator.Parent
    if not Host then
        return table.concat(Values, "|")
    end

    local Attachments = {}
    for _, child in Host:GetChildren() do
        if child:IsA("Attachment")
            and (child.Name == "Origin" or child.Name == "Target" or child.Name:match("^Midpoint%d+$")) then
            table.insert(Attachments, child)
        end
    end
    table.sort(Attachments, function(left, right)
        return left.Name < right.Name
    end)

    for _, attachment in Attachments do
        table.insert(Values, attachment.Name)
        table.insert(Values, tostring(attachment.WorldPosition))
    end
    return table.concat(Values, "|")
end

local function GetParticlePathSignature(emitter : ParticleEmitter)
    local EmitterCFrame = GetEmitterWorldCFrame(emitter)
    local EmitterParent = emitter.Parent
    local SourcePart = if EmitterParent and EmitterParent:IsA("BasePart")
        then EmitterParent
        elseif EmitterParent
            and EmitterParent:IsA("Attachment")
            and EmitterParent.Parent
            and EmitterParent.Parent:IsA("BasePart")
        then EmitterParent.Parent
        else nil

    return table.concat({
        "ParticleEmitter",
        tostring(GetPathPreviewInstanceId(emitter)),
        tostring(EmitterCFrame),
        tostring(emitter.EmissionDirection.Value),
        tostring(emitter.Speed),
        tostring(emitter.Lifetime),
        tostring(emitter.SpreadAngle),
        tostring(emitter.Acceleration),
        tostring(WorldSpaceAcceleration.GetAuthoredAcceleration(emitter)),
        tostring(WorldSpaceAcceleration.IsEnabled(emitter)),
        tostring(emitter.Drag),
        tostring(emitter.VelocityInheritance),
        tostring(emitter.LockedToPart),
        tostring(emitter.Shape.Value),
        tostring(emitter.ShapeStyle.Value),
        tostring(emitter.ShapeInOut.Value),
        tostring(emitter.ShapePartial),
        tostring(emitter.WindAffectsDrag),
        tostring(workspace.GlobalWind),
        tostring(SourcePart and SourcePart.Size or Vector3.zero),
        tostring(SourcePart and SourcePart.AssemblyLinearVelocity or Vector3.zero),
    }, "|")
end

local function RefreshPathPreview()
    local Folder = GetPreviewFolder()
    local Candidates = {}

    for _, instance in States.RawSelection.Value do
        table.insert(Candidates, instance)
    end

    for _, instance in States.CurrentlySelected.Value do
        table.insert(Candidates, instance)
    end

    local Seen = {}
    local Entries = {}

    for _, candidate in Candidates do
        if candidate:IsA("ParticleEmitter") and not Seen[candidate] then
            Seen[candidate] = true
            table.insert(Entries, {
                Instance = candidate,
                Kind = "ParticleEmitter",
                Signature = GetParticlePathSignature(candidate),
            })
        elseif candidate:IsA("StringValue") and candidate.Name == "AnimationIndicator" and not Seen[candidate] then
            Seen[candidate] = true
            table.insert(Entries, {
                Instance = candidate,
                Kind = "Indicator",
                Signature = GetIndicatorPathSignature(candidate),
            })
        else
            local Indicator = candidate:FindFirstChild("AnimationIndicator")
            if Indicator and Indicator:IsA("StringValue") and not Seen[Indicator] then
                Seen[Indicator] = true
                table.insert(Entries, {
                    Instance = Indicator,
                    Kind = "Indicator",
                    Signature = GetIndicatorPathSignature(Indicator),
                })
            end
        end
    end

    table.sort(Entries, function(left, right)
        return GetPathPreviewInstanceId(left.Instance) < GetPathPreviewInstanceId(right.Instance)
    end)

    local Signatures = {}
    for _, entry in Entries do
        table.insert(Signatures, entry.Signature)
    end
    local CombinedSignature = table.concat(Signatures, "\n")

    if CombinedSignature == LastPathPreviewSignature
        and (#Entries == 0 or #Folder:GetChildren() > 0) then
        return
    end

    LastPathPreviewSignature = CombinedSignature
    ClearPathPreview()
    for _, entry in Entries do
        if entry.Kind == "ParticleEmitter" then
            BuildParticleEmitterPathPreview(entry.Instance, Folder)
        else
            BuildIndicatorPathPreview(entry.Instance, Folder)
        end
    end
end

function EmitUtils:SetWidget(...)
    Widget = ...
end

function EmitUtils:EmitCurrent(forcedInstances : {Instance}?)
    local SelectedInstances = forcedInstances or States.CurrentlySelected.Value
    if typeof(SelectedInstances) ~= "table" or #SelectedInstances == 0 then
        return
    end

    for _, instance in SelectedInstances do
        if instance:IsA("ParticleEmitter") then
            local Duration = (instance:GetAttribute("EmitDuration") or 0)
                + (instance:GetAttribute("EmitDelay") or 0)
                + instance.Lifetime.Max
            WorldSpaceAcceleration.WatchEmitPreview(instance, Duration)
        end

        local _, WidgetParentPayload = PlayEffect(instance, true)

        if WidgetParentPayload then
            for _, payload in WidgetParentPayload do
                local Object = payload[1]
                local TotalDuration = payload[2]

                Object.Parent = Widget

                task.delay(TotalDuration, function()
                    Object:Destroy()
                end)
            end
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
        local RepeatEmitDelay = States.RepeatEmitDelay.Value

        if RepeatEmitDelay <= 0 then
            return
        end

        if Delta < RepeatEmitDelay then
            return
        end

        if States.CurrentlySelected.Value and #States.CurrentlySelected.Value > 0 then
            LastSelectedInstances = States.CurrentlySelected.Value
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

function EmitUtils:CreateNewAnimationIndicator(parent : Instance, thisType : string)
    if parent:FindFirstChild("AnimationIndicator") then
        return parent:FindFirstChild("AnimationIndicator")
    end

    local AnimationIndicator = Instance.new("StringValue")
    AnimationIndicator.Name = "AnimationIndicator"
    AnimationIndicator.Value = thisType
    AnimationIndicator.Parent = parent

    local DelayTime = Instance.new("NumberValue")
    DelayTime.Name = "DelayTime"
    DelayTime.Value = 0
    DelayTime.Parent = AnimationIndicator

    local Duration = Instance.new("NumberValue")
    Duration.Name = "Duration"
    Duration.Value = 1
    Duration.Parent = AnimationIndicator

    local Reverses = Instance.new("BoolValue")
    Reverses.Name = "Reverses"
    Reverses.Value = false
    Reverses.Parent = AnimationIndicator

    local RepeatCount = Instance.new("NumberValue")
    RepeatCount.Name = "RepeatCount"
    RepeatCount.Value = 0
    RepeatCount.Parent = AnimationIndicator
    
    local TweenDirection = Instance.new("StringValue")
    TweenDirection.Name = "TweenDirection"
    TweenDirection.Value = "Out"
    TweenDirection.Parent = AnimationIndicator

    local TweenStyle = Instance.new("StringValue")
    TweenStyle.Name = "TweenStyle"
    TweenStyle.Value = "Linear"
    TweenStyle.Parent = AnimationIndicator

    if not parent:IsA("BasePart") and not parent:FindFirstChild("Mover") then
        local Mover = Instance.new("Attachment")
        Mover.Name = "Mover"
        Mover.Parent = parent
    end

    if not parent:FindFirstChild("Origin") then
        local Origin = Instance.new("Attachment")
        Origin.Name = "Origin"
        Origin.Parent = parent
    end

    if not parent:FindFirstChild("Target") then
        local Target = Instance.new("Attachment")
        Target.Name = "Target"
        Target.Parent = parent
    end
    
    if not parent:FindFirstChild("Midpoint1") and thisType == "Bezier" then
        local Midpoint1 = Instance.new("Attachment")
        Midpoint1.Name = "Midpoint1"
        Midpoint1.Parent = parent
    end

    return AnimationIndicator
end

function EmitUtils:SetPathPreviewEnabled(enabled : boolean)
    if not enabled then
        if PathPreviewHeartbeatConnection then
            PathPreviewHeartbeatConnection:Disconnect()
            PathPreviewHeartbeatConnection = nil
        end

        DisconnectPathPreviewConnections()
        ClearPathPreview()
        return
    end

    if PathPreviewHeartbeatConnection then
        PathPreviewHeartbeatConnection:Disconnect()
        PathPreviewHeartbeatConnection = nil
    end

    DisconnectPathPreviewConnections()
    PathPreviewHeartbeatElapsed = 0
    table.insert(PathPreviewConnections, Seam.OnChanged(States.CurrentlySelected, RefreshPathPreview))
    table.insert(PathPreviewConnections, Seam.OnChanged(States.RawSelection, RefreshPathPreview))
    PathPreviewHeartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
        PathPreviewHeartbeatElapsed += deltaTime
        if PathPreviewHeartbeatElapsed < 0.1 then
            return
        end

        PathPreviewHeartbeatElapsed = 0
        RefreshPathPreview()
    end)
    RefreshPathPreview()
end

return EmitUtils
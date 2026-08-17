local EmitUtils = {}

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

local function ConfigurePreviewInstance(Instance : Instance)
    Instance.Archivable = false

    if Instance:IsA("BasePart") then
        Instance.Locked = true
    end
end

local function DisconnectPathPreviewConnections()
    for _, Connection in PathPreviewConnections do
        if Connection and Connection.Disconnect then
            Connection:Disconnect()
        end
    end

    table.clear(PathPreviewConnections)
end

local function BindPreviewFolder(Folder : Folder)
    Folder.Archivable = false
    ConfigurePreviewInstance(Folder)

    if PathPreviewDescendantConnection then
        PathPreviewDescendantConnection:Disconnect()
    end

    PathPreviewDescendantConnection = Folder.DescendantAdded:Connect(ConfigurePreviewInstance)

    for _, Descendant in Folder:GetDescendants() do
        ConfigurePreviewInstance(Descendant)
    end
end

local function GetPreviewFolder()
    if PathPreviewFolder and PathPreviewFolder.Parent then
        return PathPreviewFolder
    end

    local Folder = workspace:FindFirstChild("EffectDesignerSuitePathPreview")
    if not Folder then
        Folder = Instance.new("Folder")
        Folder.Name = "EffectDesignerSuitePathPreview"
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

    for _, Child in PathPreviewFolder:GetChildren() do
        Child:Destroy()
    end
end

local function DrawPathSegment(FromPosition : Vector3, ToPosition : Vector3, Parent : Instance)
    local Delta = ToPosition - FromPosition
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
    StartPart.CFrame = CFrame.new(FromPosition)
    StartPart.Parent = Parent

    local EndPart = Instance.new("Part")
    EndPart.Name = "PathEnd"
    EndPart.Anchored = true
    EndPart.CanCollide = false
    EndPart.CanTouch = false
    EndPart.CanQuery = false
    EndPart.Transparency = 1
    EndPart.Size = Vector3.new(0.1, 0.1, 0.1)
    EndPart.CFrame = CFrame.new(ToPosition)
    EndPart.Parent = Parent

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
    Beam.Parent = Parent
end

local function DrawPointMarker(Position : Vector3, Parent : Instance, Name : string, Color : Color3, Size : number?)
    local MarkerSize = Size or 0.22
    local Marker = Instance.new("Part")
    Marker.Name = Name
    Marker.Anchored = true
    Marker.CanCollide = false
    Marker.CanTouch = false
    Marker.CanQuery = false
    Marker.Material = Enum.Material.Neon
    Marker.Color = Color
    Marker.Shape = Enum.PartType.Ball
    Marker.Size = Vector3.new(MarkerSize, MarkerSize, MarkerSize)
    Marker.CFrame = CFrame.new(Position)
    Marker.Parent = Parent
end

local function DrawControlSegment(FromPosition : Vector3, ToPosition : Vector3, Parent : Instance)
    local Delta = ToPosition - FromPosition
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
    Part.CFrame = CFrame.lookAt(FromPosition, ToPosition) * CFrame.new(0, 0, -Delta.Magnitude * 0.5)
    Part.Parent = Parent
end

local function DrawParticlePathSegment(FromPosition : Vector3, ToPosition : Vector3, Parent : Instance)
    local Delta = ToPosition - FromPosition
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
    Part.CFrame = CFrame.lookAt(FromPosition, ToPosition) * CFrame.new(0, 0, -Delta.Magnitude * 0.5)
    Part.Parent = Parent
end

local function GetEmitterWorldCFrame(Emitter : ParticleEmitter)
    local Parent = Emitter.Parent
    if Parent and Parent:IsA("Attachment") then
        return Parent.WorldCFrame
    end
    if Parent and Parent:IsA("BasePart") then
        return Parent.CFrame
    end
    return nil
end

local function GetLocalEmissionDirection(Direction : Enum.NormalId)
    if Direction == Enum.NormalId.Top then
        return Vector3.new(0, 1, 0)
    elseif Direction == Enum.NormalId.Bottom then
        return Vector3.new(0, -1, 0)
    elseif Direction == Enum.NormalId.Right then
        return Vector3.new(1, 0, 0)
    elseif Direction == Enum.NormalId.Left then
        return Vector3.new(-1, 0, 0)
    elseif Direction == Enum.NormalId.Back then
        return Vector3.new(0, 0, 1)
    end
    return Vector3.new(0, 0, -1)
end

local function GetSpreadAxes(Direction : Enum.NormalId)
    if Direction == Enum.NormalId.Top or Direction == Enum.NormalId.Bottom then
        return Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
    elseif Direction == Enum.NormalId.Front or Direction == Enum.NormalId.Back then
        return Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
    end
    return Vector3.new(0, 0, 1), Vector3.new(0, 1, 0)
end

local function ApplySpread(Direction : Vector3, FirstTargetAxis : Vector3, FirstAngle : number, SecondTargetAxis : Vector3, SecondAngle : number)
    local FirstRotationAxis = Direction:Cross(FirstTargetAxis).Unit
    local SecondRotationAxis = Direction:Cross(SecondTargetAxis).Unit
    local FirstRotation = CFrame.fromAxisAngle(FirstRotationAxis, FirstAngle)
    local SecondRotation = CFrame.fromAxisAngle(SecondRotationAxis, SecondAngle)
    return SecondRotation:VectorToWorldSpace(FirstRotation:VectorToWorldSpace(Direction)).Unit
end

local function AddUniqueVector(List, Seen, Value : Vector3)
    local Key = string.format("%.4f,%.4f,%.4f", Value.X, Value.Y, Value.Z)
    if Seen[Key] then
        return
    end

    Seen[Key] = true
    table.insert(List, Value)
end

local function CollectSpreadDirections(LocalDirection : Vector3, FirstAxis : Vector3, SecondAxis : Vector3, FirstAngle : number, SecondAngle : number)
    local Directions = {}
    local Seen = {}
    AddUniqueVector(Directions, Seen, LocalDirection)

    if FirstAngle <= 0.0001 and SecondAngle <= 0.0001 then
        return Directions
    end

    local RingCount = 8
    for Index = 0, RingCount - 1 do
        local Tau = Index / RingCount * math.pi * 2
        AddUniqueVector(
            Directions,
            Seen,
            ApplySpread(LocalDirection, FirstAxis, math.cos(Tau) * FirstAngle, SecondAxis, math.sin(Tau) * SecondAngle)
        )
    end

    if FirstAngle > 0.25 or SecondAngle > 0.25 then
        for Index = 0, RingCount - 1 do
            local Tau = (Index + 0.5) / RingCount * math.pi * 2
            AddUniqueVector(
                Directions,
                Seen,
                ApplySpread(LocalDirection, FirstAxis, math.cos(Tau) * FirstAngle * 0.5, SecondAxis, math.sin(Tau) * SecondAngle * 0.5)
            )
        end
    end

    return Directions
end

local function GetPerpendicularExtents(Half : Vector3, Axis : Vector3)
    if math.abs(Axis.X) > 0.5 then
        return math.min(Half.Y, Half.Z), Half.X
    elseif math.abs(Axis.Y) > 0.5 then
        return math.min(Half.X, Half.Z), Half.Y
    end

    return math.min(Half.X, Half.Y), Half.Z
end

local function CollectRingOffsets(Offsets, Seen, Center : Vector3, FirstAxis : Vector3, SecondAxis : Vector3, Radius : number, Count : number)
    if Radius <= 0.001 then
        AddUniqueVector(Offsets, Seen, Center)
        return
    end

    for Index = 0, Count - 1 do
        local Tau = Index / Count * math.pi * 2
        AddUniqueVector(Offsets, Seen, Center + FirstAxis * (math.cos(Tau) * Radius) + SecondAxis * (math.sin(Tau) * Radius))
    end
end

local function CollectSpawnOffsets(Emitter : ParticleEmitter, Half : Vector3, LocalDirection : Vector3, FirstAxis : Vector3, SecondAxis : Vector3)
    local Offsets = {}
    local Seen = {}
    local IsVolume = Emitter.ShapeStyle ~= Enum.ParticleEmitterShapeStyle.Surface

    if Half.Magnitude <= 0.001 then
        AddUniqueVector(Offsets, Seen, Vector3.zero)
        return Offsets
    end

    if IsVolume then
        AddUniqueVector(Offsets, Seen, Vector3.zero)
    end

    local Shape = Emitter.Shape
    local Partial = math.clamp(Emitter.ShapePartial, 0, 1)

    if Shape == Enum.ParticleEmitterShape.Sphere then
        local Radius = math.min(Half.X, Half.Y, Half.Z)
        local MaxPolar = math.pi * Partial
        AddUniqueVector(Offsets, Seen, LocalDirection * Radius)

        if MaxPolar > 0.05 then
            local RingRadius = math.sin(MaxPolar) * Radius
            local RingAlong = math.cos(MaxPolar) * Radius
            CollectRingOffsets(Offsets, Seen, LocalDirection * RingAlong, FirstAxis, SecondAxis, RingRadius, 8)
        end

        if MaxPolar > math.pi * 0.66 then
            AddUniqueVector(Offsets, Seen, -LocalDirection * Radius)
        end
    elseif Shape == Enum.ParticleEmitterShape.Cylinder then
        local Radius, HalfHeight = GetPerpendicularExtents(Half, LocalDirection)
        local FrontRadius = Radius * Partial
        CollectRingOffsets(Offsets, Seen, LocalDirection * HalfHeight, FirstAxis, SecondAxis, FrontRadius, 8)
        CollectRingOffsets(Offsets, Seen, -LocalDirection * HalfHeight, FirstAxis, SecondAxis, Radius, 8)
        if IsVolume then
            AddUniqueVector(Offsets, Seen, LocalDirection * HalfHeight)
            AddUniqueVector(Offsets, Seen, -LocalDirection * HalfHeight)
        end
    elseif Shape == Enum.ParticleEmitterShape.Disc then
        local Radius = GetPerpendicularExtents(Half, LocalDirection)
        local InnerRadius = Radius * Partial
        CollectRingOffsets(Offsets, Seen, Vector3.zero, FirstAxis, SecondAxis, Radius, 8)
        if InnerRadius > 0.001 and math.abs(Radius - InnerRadius) > 0.001 then
            CollectRingOffsets(Offsets, Seen, Vector3.zero, FirstAxis, SecondAxis, InnerRadius, 8)
        end
    else
        for _, X in {-1, 1} do
            for _, Y in {-1, 1} do
                for _, Z in {-1, 1} do
                    AddUniqueVector(Offsets, Seen, Vector3.new(X * Half.X, Y * Half.Y, Z * Half.Z))
                end
            end
        end

        AddUniqueVector(Offsets, Seen, Vector3.new(Half.X, 0, 0))
        AddUniqueVector(Offsets, Seen, Vector3.new(-Half.X, 0, 0))
        AddUniqueVector(Offsets, Seen, Vector3.new(0, Half.Y, 0))
        AddUniqueVector(Offsets, Seen, Vector3.new(0, -Half.Y, 0))
        AddUniqueVector(Offsets, Seen, Vector3.new(0, 0, Half.Z))
        AddUniqueVector(Offsets, Seen, Vector3.new(0, 0, -Half.Z))
    end

    return Offsets
end

local function ApplyShapeInOut(Directions, ShapeInOut)
    if ShapeInOut == Enum.ParticleEmitterShapeInOut.Inward then
        local Inward = {}
        for _, Direction in Directions do
            table.insert(Inward, -Direction)
        end
        return Inward
    elseif ShapeInOut == Enum.ParticleEmitterShapeInOut.InAndOut then
        local Both = table.clone(Directions)
        for _, Direction in Directions do
            table.insert(Both, -Direction)
        end
        return Both
    end

    return Directions
end

local function StepParticle(Position : Vector3, Velocity : Vector3, Acceleration : Vector3, Drag : number, DeltaTime : number, Wind : Vector3)
    -- ParticleEmitter.Drag is a half-life rate, so Roblox scales velocity by
    -- 2^(-Drag * dt) after applying acceleration. With wind, drag pulls toward
    -- the wind vector instead of toward zero.
    local RelativeVelocity = Velocity - Wind
    local NewRelativeVelocity = (RelativeVelocity + Acceleration * DeltaTime) * (2 ^ (-Drag * DeltaTime))
    local NewVelocity = NewRelativeVelocity + Wind
    local NewPosition = Position + (Velocity + NewVelocity) * (0.5 * DeltaTime)
    return NewPosition, NewVelocity
end

local function BuildParticleEmitterPathPreview(Emitter : ParticleEmitter, Parent : Instance)
    local EmitterCFrame = GetEmitterWorldCFrame(Emitter)
    if not EmitterCFrame then
        return
    end

    local LocalDirection = GetLocalEmissionDirection(Emitter.EmissionDirection)
    local Spread = Emitter.SpreadAngle
    local FirstAxis, SecondAxis = GetSpreadAxes(Emitter.EmissionDirection)
    local FirstAngle = math.rad(math.min(Spread.X, 180))
    local SecondAngle = math.rad(math.min(Spread.Y, 180))
    local SpreadDirections = CollectSpreadDirections(LocalDirection, FirstAxis, SecondAxis, FirstAngle, SecondAngle)
    local EmitDirections = ApplyShapeInOut(SpreadDirections, Emitter.ShapeInOut)

    local EmitterParent = Emitter.Parent
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
    local SpawnOffsets = CollectSpawnOffsets(Emitter, HalfSize, LocalDirection, FirstAxis, SecondAxis)

    local Origin = EmitterCFrame.Position
    local MinimumSpeed = Emitter.Speed.Min
    local MaximumSpeed = Emitter.Speed.Max
    local RepresentativeSpeed = if MinimumSpeed <= 0 and MaximumSpeed >= 0
        then (if math.abs(MinimumSpeed) > math.abs(MaximumSpeed) then MinimumSpeed else MaximumSpeed)
        else (MinimumSpeed + MaximumSpeed) * 0.5
    local HasSpeedRange = math.abs(MaximumSpeed - MinimumSpeed) > 0.001
    local MaxLifetime = math.clamp(Emitter.Lifetime.Max, 0.01, 20)
    local MinLifetime = math.clamp(Emitter.Lifetime.Min, 0, MaxLifetime)
    local SimSteps = 48
    local DeltaTime = MaxLifetime / SimSteps
    local LockedToPart = Emitter.LockedToPart
    local InheritedVelocity = Vector3.zero
    local Wind = Vector3.zero

    if SourcePart and not LockedToPart then
        InheritedVelocity = SourcePart.AssemblyLinearVelocity * Emitter.VelocityInheritance
    end

    if Emitter.WindAffectsDrag and Emitter.Drag > 0 then
        local GlobalWind = workspace.GlobalWind
        if LockedToPart then
            Wind = EmitterCFrame:VectorToObjectSpace(GlobalWind)
        else
            Wind = GlobalWind
        end
    end

    local function ToWorldPosition(Position : Vector3)
        if LockedToPart then
            return EmitterCFrame:PointToWorldSpace(Position)
        end

        return Position
    end

    local function DrawTrajectory(LocalOffset : Vector3, Direction : Vector3, Speed : number)
        local Position = if LockedToPart then LocalOffset else EmitterCFrame:PointToWorldSpace(LocalOffset)
        local Velocity = if LockedToPart
            then Direction.Unit * Speed
            else EmitterCFrame:VectorToWorldSpace(Direction).Unit * Speed + InheritedVelocity
        local Acceleration = WorldSpaceAcceleration.GetSimulationAcceleration(Emitter, EmitterCFrame, LockedToPart)
        local LastWorldPosition = ToWorldPosition(Position)
        local MinLifetimePosition = nil

        for Step = 1, SimSteps do
            local NextPosition, NextVelocity = StepParticle(Position, Velocity, Acceleration, Emitter.Drag, DeltaTime, Wind)
            local NextWorldPosition = ToWorldPosition(NextPosition)

            if MinLifetimePosition == nil and (Step * DeltaTime) >= MinLifetime then
                MinLifetimePosition = NextWorldPosition
            end

            if Step == SimSteps or Step % 2 == 0 then
                DrawParticlePathSegment(LastWorldPosition, NextWorldPosition, Parent)
                LastWorldPosition = NextWorldPosition
            end

            Position = NextPosition
            Velocity = NextVelocity
        end

        DrawPointMarker(LastWorldPosition, Parent, "ParticlePathEnd", Color3.fromRGB(255, 150, 220), 0.12)

        if MinLifetimePosition and MinLifetime > 0.05 and (MaxLifetime - MinLifetime) > 0.05 then
            DrawPointMarker(MinLifetimePosition, Parent, "ParticlePathMinLifetime", Color3.fromRGB(160, 90, 220), 0.1)
        end
    end

    DrawPointMarker(Origin, Parent, "ParticleEmitterOrigin", Color3.fromRGB(205, 135, 255), 0.24)

    for _, Direction in EmitDirections do
        DrawTrajectory(Vector3.zero, Direction, RepresentativeSpeed)
    end

    if HasSpeedRange then
        DrawTrajectory(Vector3.zero, EmitDirections[1], MinimumSpeed)
        DrawTrajectory(Vector3.zero, EmitDirections[1], MaximumSpeed)
    end

    for _, Offset in SpawnOffsets do
        if Offset.Magnitude <= 0.001 then
            continue
        end

        DrawPointMarker(EmitterCFrame:PointToWorldSpace(Offset), Parent, "ParticleSpawn", Color3.fromRGB(155, 95, 210), 0.14)
        DrawTrajectory(Offset, EmitDirections[1], RepresentativeSpeed)

        if Emitter.ShapeInOut == Enum.ParticleEmitterShapeInOut.InAndOut then
            DrawTrajectory(Offset, -EmitDirections[1], RepresentativeSpeed)
        end
    end
end

local function EvaluateBezier(ControlPoints : {Vector3}, T : number)
    local Working = table.clone(ControlPoints)

    while #Working > 1 do
        local NextWorking = {}

        for Index = 1, #Working - 1 do
            table.insert(NextWorking, Working[Index]:Lerp(Working[Index + 1], T))
        end

        Working = NextWorking
    end

    return Working[1]
end

local function BuildIndicatorPathPreview(AnimationIndicator : StringValue, Parent : Instance)
    if not AnimationIndicator.Parent then
        return
    end

    local Host = AnimationIndicator.Parent
    local Origin = Host:FindFirstChild("Origin")
    local Target = Host:FindFirstChild("Target")

    if not Origin or not Target or not Origin:IsA("Attachment") or not Target:IsA("Attachment") then
        return
    end

    if AnimationIndicator.Value == "Tween" then
        DrawPathSegment(Origin.WorldPosition, Target.WorldPosition, Parent)
        return
    end

    if AnimationIndicator.Value == "Bezier" then
        local Points = {Origin.WorldPosition}
        local Midpoints = {}

        for _, Child in Host:GetChildren() do
            if Child:IsA("Attachment") and Child.Name:match("^Midpoint%d+$") then
                table.insert(Midpoints, Child)
            end
        end

        table.sort(Midpoints, function(Left, Right)
            local LeftIndex = tonumber(Left.Name:match("^Midpoint(%d+)$")) or 0
            local RightIndex = tonumber(Right.Name:match("^Midpoint(%d+)$")) or 0
            return LeftIndex < RightIndex
        end)

        for _, Midpoint in Midpoints do
            table.insert(Points, Midpoint.WorldPosition)
        end

        table.insert(Points, Target.WorldPosition)

        for Index = 1, #Points do
            if Index == 1 then
                DrawPointMarker(Points[Index], Parent, "OriginMarker", Color3.fromRGB(95, 210, 255))
            elseif Index == #Points then
                DrawPointMarker(Points[Index], Parent, "TargetMarker", Color3.fromRGB(120, 255, 130))
            else
                DrawPointMarker(Points[Index], Parent, "MidpointMarker", Color3.fromRGB(255, 205, 90))
            end

            if Index < #Points then
                DrawControlSegment(Points[Index], Points[Index + 1], Parent)
            end
        end

        local Last = Points[1]
        local Steps = 50

        for Step = 1, Steps do
            local T = Step / Steps
            local Current = EvaluateBezier(Points, T)
            DrawPathSegment(Last, Current, Parent)
            Last = Current
        end
    end
end

local function GetPathPreviewInstanceId(Instance : Instance)
    local ExistingId = PathPreviewInstanceIds[Instance]
    if ExistingId then
        return ExistingId
    end

    NextPathPreviewInstanceId += 1
    PathPreviewInstanceIds[Instance] = NextPathPreviewInstanceId
    return NextPathPreviewInstanceId
end

local function GetIndicatorPathSignature(Indicator : StringValue)
    local Values = {
        "Indicator",
        tostring(GetPathPreviewInstanceId(Indicator)),
        Indicator.Value,
    }
    local Host = Indicator.Parent
    if not Host then
        return table.concat(Values, "|")
    end

    local Attachments = {}
    for _, Child in Host:GetChildren() do
        if Child:IsA("Attachment")
            and (Child.Name == "Origin" or Child.Name == "Target" or Child.Name:match("^Midpoint%d+$")) then
            table.insert(Attachments, Child)
        end
    end
    table.sort(Attachments, function(Left, Right)
        return Left.Name < Right.Name
    end)

    for _, Attachment in Attachments do
        table.insert(Values, Attachment.Name)
        table.insert(Values, tostring(Attachment.WorldPosition))
    end
    return table.concat(Values, "|")
end

local function GetParticlePathSignature(Emitter : ParticleEmitter)
    local EmitterCFrame = GetEmitterWorldCFrame(Emitter)
    local EmitterParent = Emitter.Parent
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
        tostring(GetPathPreviewInstanceId(Emitter)),
        tostring(EmitterCFrame),
        tostring(Emitter.EmissionDirection.Value),
        tostring(Emitter.Speed),
        tostring(Emitter.Lifetime),
        tostring(Emitter.SpreadAngle),
        tostring(Emitter.Acceleration),
        tostring(WorldSpaceAcceleration.GetAuthoredAcceleration(Emitter)),
        tostring(WorldSpaceAcceleration.IsEnabled(Emitter)),
        tostring(Emitter.Drag),
        tostring(Emitter.VelocityInheritance),
        tostring(Emitter.LockedToPart),
        tostring(Emitter.Shape.Value),
        tostring(Emitter.ShapeStyle.Value),
        tostring(Emitter.ShapeInOut.Value),
        tostring(Emitter.ShapePartial),
        tostring(Emitter.WindAffectsDrag),
        tostring(workspace.GlobalWind),
        tostring(SourcePart and SourcePart.Size or Vector3.zero),
        tostring(SourcePart and SourcePart.AssemblyLinearVelocity or Vector3.zero),
    }, "|")
end

local function RefreshPathPreview()
    local Folder = GetPreviewFolder()
    local Candidates = {}

    for _, Instance in States.RawSelection.Value do
        table.insert(Candidates, Instance)
    end

    for _, Instance in States.CurrentlySelected.Value do
        table.insert(Candidates, Instance)
    end

    local Seen = {}
    local Entries = {}

    for _, Candidate in Candidates do
        if Candidate:IsA("ParticleEmitter") and not Seen[Candidate] then
            Seen[Candidate] = true
            table.insert(Entries, {
                Instance = Candidate,
                Kind = "ParticleEmitter",
                Signature = GetParticlePathSignature(Candidate),
            })
        elseif Candidate:IsA("StringValue") and Candidate.Name == "AnimationIndicator" and not Seen[Candidate] then
            Seen[Candidate] = true
            table.insert(Entries, {
                Instance = Candidate,
                Kind = "Indicator",
                Signature = GetIndicatorPathSignature(Candidate),
            })
        else
            local Indicator = Candidate:FindFirstChild("AnimationIndicator")
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

    table.sort(Entries, function(Left, Right)
        return GetPathPreviewInstanceId(Left.Instance) < GetPathPreviewInstanceId(Right.Instance)
    end)

    local Signatures = {}
    for _, Entry in Entries do
        table.insert(Signatures, Entry.Signature)
    end
    local CombinedSignature = table.concat(Signatures, "\n")

    if CombinedSignature == LastPathPreviewSignature
        and (#Entries == 0 or #Folder:GetChildren() > 0) then
        return
    end

    LastPathPreviewSignature = CombinedSignature
    ClearPathPreview()
    for _, Entry in Entries do
        if Entry.Kind == "ParticleEmitter" then
            BuildParticleEmitterPathPreview(Entry.Instance, Folder)
        else
            BuildIndicatorPathPreview(Entry.Instance, Folder)
        end
    end
end

function EmitUtils:SetWidget(...)
    Widget = ...
end

function EmitUtils:EmitCurrent(ForcedInstances : {Instance}?)
    if not States.IsEmittable.Value and not ForcedInstances then
        return
    end

    local SelectedInstances = ForcedInstances or States.CurrentlySelected.Value

    for _, Instance in SelectedInstances do
        if Instance:IsA("ParticleEmitter") then
            local Duration = (Instance:GetAttribute("EmitDuration") or 0)
                + (Instance:GetAttribute("EmitDelay") or 0)
                + Instance.Lifetime.Max
            WorldSpaceAcceleration.WatchEmitPreview(Instance, Duration)
        end

        local _, WidgetParentPayload = PlayEffect(Instance, true)

        if WidgetParentPayload then
            for _, Payload in WidgetParentPayload do
                local Object = Payload[1]
                local TotalDuration = Payload[2]

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

function EmitUtils:CreateNewAnimationIndicator(Parent : Instance, Type : string)
    if Parent:FindFirstChild("AnimationIndicator") then
        return Parent:FindFirstChild("AnimationIndicator")
    end

    local AnimationIndicator = Instance.new("StringValue")
    AnimationIndicator.Name = "AnimationIndicator"
    AnimationIndicator.Value = Type
    AnimationIndicator.Parent = Parent

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

    if not Parent:FindFirstChild("Mover") then
        local Mover = Instance.new("Attachment")
        Mover.Name = "Mover"
        Mover.Parent = Parent
    end

    if not Parent:FindFirstChild("Origin") then
        local Origin = Instance.new("Attachment")
        Origin.Name = "Origin"
        Origin.Parent = Parent
    end

    if not Parent:FindFirstChild("Target") then
        local Target = Instance.new("Attachment")
        Target.Name = "Target"
        Target.Parent = Parent
    end
    
    if not Parent:FindFirstChild("Midpoint1") and Type == "Bezier" then
        local Midpoint1 = Instance.new("Attachment")
        Midpoint1.Name = "Midpoint1"
        Midpoint1.Parent = Parent
    end

    return AnimationIndicator
end

function EmitUtils:SetPathPreviewEnabled(Enabled : boolean)
    if not Enabled then
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
    PathPreviewHeartbeatConnection = RunService.Heartbeat:Connect(function(DeltaTime)
        PathPreviewHeartbeatElapsed += DeltaTime
        if PathPreviewHeartbeatElapsed < 0.1 then
            return
        end

        PathPreviewHeartbeatElapsed = 0
        RefreshPathPreview()
    end)
    RefreshPathPreview()
end

return EmitUtils
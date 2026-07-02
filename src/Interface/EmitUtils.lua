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

-- Variables
local RepeatEmitConnection = nil
local Widget = nil
local PathPreviewFolder = nil
local PathPreviewConnections = {}
local PathPreviewHeartbeatConnection = nil

local function DisconnectPathPreviewConnections()
    for _, Connection in PathPreviewConnections do
        if Connection and Connection.Disconnect then
            Connection:Disconnect()
        end
    end

    table.clear(PathPreviewConnections)
end

local function GetPreviewFolder()
    if PathPreviewFolder and PathPreviewFolder.Parent then
        return PathPreviewFolder
    end

    local Folder = workspace:FindFirstChild("EffectDesignerSuitePathPreview")
    if not Folder then
        Folder = Instance.new("Folder")
        Folder.Name = "EffectDesignerSuitePathPreview"
        Folder.Parent = workspace
    end

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

local function DrawPointMarker(Position : Vector3, Parent : Instance, Name : string, Color : Color3)
    local Marker = Instance.new("Part")
    Marker.Name = Name
    Marker.Anchored = true
    Marker.CanCollide = false
    Marker.CanTouch = false
    Marker.CanQuery = false
    Marker.Material = Enum.Material.Neon
    Marker.Color = Color
    Marker.Shape = Enum.PartType.Ball
    Marker.Size = Vector3.new(0.22, 0.22, 0.22)
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

local function RefreshPathPreview()
    local Folder = GetPreviewFolder()
    ClearPathPreview()

    local Candidates = {}

    for _, Instance in States.RawSelection.Value do
        table.insert(Candidates, Instance)
    end

    for _, Instance in States.CurrentlySelected.Value do
        table.insert(Candidates, Instance)
    end

    local Seen = {}

    for _, Candidate in Candidates do
        if Candidate:IsA("StringValue") and Candidate.Name == "AnimationIndicator" and not Seen[Candidate] then
            Seen[Candidate] = true
            BuildIndicatorPathPreview(Candidate, Folder)
        else
            local Indicator = Candidate:FindFirstChild("AnimationIndicator")
            if Indicator and Indicator:IsA("StringValue") and not Seen[Indicator] then
                Seen[Indicator] = true
                BuildIndicatorPathPreview(Indicator, Folder)
            end
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
    table.insert(PathPreviewConnections, Seam.OnChanged(States.CurrentlySelected, RefreshPathPreview))
    table.insert(PathPreviewConnections, Seam.OnChanged(States.RawSelection, RefreshPathPreview))
    PathPreviewHeartbeatConnection = RunService.Heartbeat:Connect(RefreshPathPreview)
    RefreshPathPreview()
end

return EmitUtils
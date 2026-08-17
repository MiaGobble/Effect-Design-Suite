local EffectOps = {}

-- Constants
local MAXIMUM_COLOR_KEYPOINTS = 20
local CURVE_SAMPLE_BUDGET = 90

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Oklab = require(Packages:FindFirstChild("Oklab"))

local function SortColorPoints(points)
    local Sorted = table.clone(points)
    table.sort(Sorted, function(left, right)
        return left.Time < right.Time
    end)
    return Sorted
end

local function PointToOklab(point)
    return Vector3.new(point.L, point.A, point.B)
end

function EffectOps.Color3ToOklabPoint(color : Color3, time : number)
    local Value = Oklab.ToOklab(color)
    return {
        Time = math.clamp(time, 0, 1),
        L = Value.X,
        A = Value.Y,
        B = Value.Z,
    }
end

function EffectOps.OklabPointToColor3(point)
    return Oklab.FromOklab(PointToOklab(point))
end

function EffectOps.ReadOklabPointsFromColorSequence(sequence : ColorSequence)
    local Points = {}

    for _, keypoint in sequence.Keypoints do
        table.insert(Points, EffectOps.Color3ToOklabPoint(keypoint.Value, keypoint.Time))
    end

    return Points
end

function EffectOps.InterpolateOklabPoints(points, time : number)
    local Sorted = SortColorPoints(points)
    local ClampedTime = math.clamp(time, 0, 1)

    if #Sorted == 0 then
        return Vector3.new(1, 0, 0)
    end

    if #Sorted == 1 or ClampedTime <= Sorted[1].Time then
        return PointToOklab(Sorted[1])
    end

    for index = 1, #Sorted - 1 do
        local Start = Sorted[index]
        local Finish = Sorted[index + 1]

        if ClampedTime <= Finish.Time then
            local Duration = Finish.Time - Start.Time
            local Alpha = if Duration <= 0 then 0 else (ClampedTime - Start.Time) / Duration
            return PointToOklab(Start):Lerp(PointToOklab(Finish), math.clamp(Alpha, 0, 1))
        end
    end

    return PointToOklab(Sorted[#Sorted])
end

function EffectOps.BuildColorSequenceFromOklabPoints(points)
    local Sorted = SortColorPoints(points)

    if #Sorted == 0 then
        return ColorSequence.new(Color3.new(1, 1, 1))
    end

    if #Sorted == 1 then
        local Color = EffectOps.OklabPointToColor3(Sorted[1])
        return ColorSequence.new(Color)
    end

    -- Preserve every authored time, then fill the remaining native keypoint budget
    -- with evenly spaced samples so Roblox's interpolation approximates Oklab.
    local SampleTimes = {}
    local SeenTimes = {}
    local function AddTime(time)
        local Clamped = math.clamp(time, 0, 1)
        local Key = math.floor(Clamped * 1000000 + 0.5)
        if not SeenTimes[Key] then
            SeenTimes[Key] = true
            table.insert(SampleTimes, Clamped)
        end
    end

    for _, point in Sorted do
        AddTime(point.Time)
    end
    AddTime(0)
    AddTime(1)

    while #SampleTimes < MAXIMUM_COLOR_KEYPOINTS do
        table.sort(SampleTimes)

        local LargestGap = 0
        local Midpoint = nil
        for index = 1, #SampleTimes - 1 do
            local Gap = SampleTimes[index + 1] - SampleTimes[index]
            if Gap > LargestGap then
                LargestGap = Gap
                Midpoint = SampleTimes[index] + Gap / 2
            end
        end

        if not Midpoint or LargestGap <= 0 then
            break
        end
        AddTime(Midpoint)
    end

    table.sort(SampleTimes)

    local Keypoints = {}
    for _, sampleTime in SampleTimes do
        local OklabValue = EffectOps.InterpolateOklabPoints(Sorted, sampleTime)
        table.insert(Keypoints, ColorSequenceKeypoint.new(sampleTime, Oklab.FromOklab(OklabValue)))
    end

    return ColorSequence.new(Keypoints)
end

function EffectOps.ScaleValueByMultiplier(value, multiplier : number)
    local ValueType = typeof(value)

    if ValueType == "number" then
        return value * multiplier
    end

    if ValueType == "NumberRange" then
        return NumberRange.new(value.Min * multiplier, value.Max * multiplier)
    end

    if ValueType == "NumberSequence" then
        local Keypoints = {}

        for _, keypoint in value.Keypoints do
            table.insert(Keypoints, NumberSequenceKeypoint.new(
                keypoint.Time,
                keypoint.Value * multiplier,
                keypoint.Envelope * multiplier
            ))
        end

        return NumberSequence.new(Keypoints)
    end

    if ValueType == "Vector3" then
        return value * multiplier
    end

    return value
end

function EffectOps.ApplyResizeMultiplier(multiplier : number, instances : {Instance})
    if not multiplier then
        return
    end

    for _, instance in instances do
        if instance:IsA("ParticleEmitter") then
            instance.Size = EffectOps.ScaleValueByMultiplier(instance.Size, multiplier)
        elseif instance:IsA("Beam") then
            instance.Width0 = instance.Width0 * multiplier
            instance.Width1 = instance.Width1 * multiplier
        elseif instance:IsA("Trail") then
            instance.WidthScale = EffectOps.ScaleValueByMultiplier(instance.WidthScale, multiplier)
        elseif instance:IsA("Attachment") then
            instance.Position = instance.Position * multiplier
        end
    end
end

function EffectOps.ReadCurvePointsFromNumberSequence(sequence : NumberSequence)
    local Keypoints = sequence.Keypoints
        local MinValue = math.huge
    local MaxValue = -math.huge

    for _, keypoint in Keypoints do
        MinValue = math.min(MinValue, keypoint.Value)
        MaxValue = math.max(MaxValue, keypoint.Value)
    end

    if MinValue == math.huge then
        MinValue = 0
        MaxValue = 1
    elseif MaxValue <= MinValue then
        MaxValue = MinValue + 1
    end

    local ValueRange = MaxValue - MinValue

    local points = {}
    for _, keypoint in Keypoints do
        table.insert(points, {
            Time = keypoint.Time,
            Value = math.clamp((keypoint.Value - MinValue) / ValueRange, 0, 1),
            -- Existing NumberSequences have no tangent data, so preserve them as
            -- piecewise-linear curves until the user edits a handle.
            InHandleX = 0,
            InHandleY = 0,
            OutHandleX = 0,
            OutHandleY = 0,
        })
    end

        return points, MinValue, MaxValue
end

function EffectOps.BuildNumberSequenceFromCurve(points : {{time : number, Value : number}}, minRange : number, maxRange : number)
    local Sorted = table.clone(points)
    table.sort(Sorted, function(left, right)
        return left.Time < right.Time
    end)

    if #Sorted == 0 then
        return NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)})
    end

    local function GetHandle(point, prefix, defaultX)
        local X = point[prefix .. "HandleX"]
        local Y = point[prefix .. "HandleY"]

        -- Support the original handle fields used by older curve data.
        if X == nil and prefix == "Out" then
            X = point.OutHandle
        elseif X == nil and prefix == "In" then
            X = point.InHandle
        end

        return X or defaultX, Y or 0
    end

    local function Cubic(a, b, c, d, t)
        local U = 1 - t
        return a * U * U * U + 3 * b * U * U * t + 3 * c * U * t * t + d * t * t * t
    end

    local Samples = {}
    local SamplesPerSegment = math.max(2, math.floor(CURVE_SAMPLE_BUDGET / math.max(1, #Sorted - 1)))

    for index = 1, #Sorted - 1 do
        local Start = Sorted[index]
        local Finish = Sorted[index + 1]
        local OutX, OutY = GetHandle(Start, "Out", 0)
        local InX, InY = GetHandle(Finish, "In", 0)

        for step = 0, SamplesPerSegment - 1 do
            local T = step / SamplesPerSegment
            table.insert(Samples, {
                Time = Cubic(Start.Time, Start.Time + OutX, Finish.Time + InX, Finish.Time, T),
                Value = Cubic(Start.Value, Start.Value + OutY, Finish.Value + InY, Finish.Value, T),
            })
        end
    end

    local Last = Sorted[#Sorted]
    table.insert(Samples, {Time = Last.Time, Value = Last.Value})
    table.sort(Samples, function(left, right)
        return left.Time < right.Time
    end)

    local Keypoints = {}
    local LastTime = nil
    for _, sample in Samples do
        local time = math.clamp(sample.Time, 0, 1)
        if LastTime == nil or time > LastTime then
            table.insert(Keypoints, NumberSequenceKeypoint.new(
                time,
                minRange + math.clamp(sample.Value, 0, 1) * (maxRange - minRange)
            ))
            LastTime = time
        end
    end

        -- NumberSequence has a relatively small keypoint limit. Keep enough samples
    -- to retain the curve shape without passing an oversized table to Roblox.
    local MaximumKeypoints = 20
    if #Keypoints > MaximumKeypoints then
        local Simplified = {}
        for index = 0, MaximumKeypoints - 1 do
            local SourceIndex = math.floor(index * (#Keypoints - 1) / (MaximumKeypoints - 1)) + 1
            table.insert(Simplified, Keypoints[SourceIndex])
        end
        Keypoints = Simplified
    end

    return NumberSequence.new(Keypoints)
end

function EffectOps.ApplyMathOperation(value: number, property: string, operation: string, instances: {Instance})
    if not value or property == "" then
        return
    end

    for _, instance in instances do
        if not (instance:IsA("ParticleEmitter") and instance[property]) then
            continue
        end

        local PropertyType = typeof(instance[property])

        if PropertyType == "NumberSequence" then
            local OldSequence = instance[property]
            local NewKeypoints = {}

            for _, keypoint in OldSequence.Keypoints do
                local NewValue, NewEnvelope

                if operation == "add" then
                    NewValue = keypoint.Value + value
                    NewEnvelope = keypoint.Envelope and (keypoint.Envelope + value)
                elseif operation == "subtract" then
                    NewValue = keypoint.Value - value
                    NewEnvelope = keypoint.Envelope and (keypoint.Envelope - value)
                elseif operation == "multiply" then
                    NewValue = keypoint.Value * value
                    NewEnvelope = keypoint.Envelope and (keypoint.Envelope * value)
                elseif operation == "divide" then
                    if value == 0 then
                        continue
                    end

                    NewValue = keypoint.Value / value
                    NewEnvelope = keypoint.Envelope and (keypoint.Envelope / value)
                end

                table.insert(NewKeypoints, NumberSequenceKeypoint.new(
                    keypoint.Time,
                    NewValue,
                    NewEnvelope
                ))
            end

            instance[property] = NumberSequence.new(NewKeypoints)
        elseif PropertyType == "NumberRange" then
            local OldMin = instance[property].Min
            local OldMax = instance[property].Max
            local NewMin, NewMax

            if operation == "add" then
                NewMin = OldMin + value
                NewMax = OldMax + value
            elseif operation == "subtract" then
                NewMin = OldMin - value
                NewMax = OldMax - value
            elseif operation == "multiply" then
                NewMin = OldMin * value
                NewMax = OldMax * value
            elseif operation == "divide" then
                if value == 0 then
                    continue
                end

                NewMin = OldMin / value
                NewMax = OldMax / value
            end

            instance[property] = NumberRange.new(NewMin, NewMax)
        elseif PropertyType == "number" then
            if operation == "add" then
                instance[property] = instance[property] + value
            elseif operation == "subtract" then
                instance[property] = instance[property] - value
            elseif operation == "multiply" then
                instance[property] = instance[property] * value
            elseif operation == "divide" then
                if value == 0 then
                    continue
                end

                instance[property] = instance[property] / value
            end
        end
    end
end

return EffectOps

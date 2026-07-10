local EffectOps = {}

function EffectOps.ScaleValueByMultiplier(Value, Multiplier : number)
    local ValueType = typeof(Value)

    if ValueType == "number" then
        return Value * Multiplier
    end

    if ValueType == "NumberRange" then
        return NumberRange.new(Value.Min * Multiplier, Value.Max * Multiplier)
    end

    if ValueType == "NumberSequence" then
        local Keypoints = {}

        for _, Keypoint in Value.Keypoints do
            table.insert(Keypoints, NumberSequenceKeypoint.new(
                Keypoint.Time,
                Keypoint.Value * Multiplier,
                Keypoint.Envelope * Multiplier
            ))
        end

        return NumberSequence.new(Keypoints)
    end

    if ValueType == "Vector3" then
        return Value * Multiplier
    end

    return Value
end

function EffectOps.ShiftColorSequenceToTarget(Sequence : ColorSequence, TargetColor : Color3)
    local Keypoints = Sequence.Keypoints

    if #Keypoints == 0 then
        return Sequence
    end

    local BaseColor = Keypoints[1].Value
    local BaseHue, BaseSaturation, BaseValue = BaseColor:ToHSV()
    local TargetHue, TargetSaturation, TargetValue = TargetColor:ToHSV()

    local HueDelta = TargetHue - BaseHue
    local SaturationDelta = TargetSaturation - BaseSaturation
    local ValueDelta = TargetValue - BaseValue

    local NewKeypoints = {}

    for _, Keypoint in Keypoints do
        local Hue, Saturation, Brightness = Keypoint.Value:ToHSV()

        table.insert(NewKeypoints, ColorSequenceKeypoint.new(
            Keypoint.Time,
            Color3.fromHSV(
                (Hue + HueDelta) % 1,
                math.clamp(Saturation + SaturationDelta, 0, 1),
                math.clamp(Brightness + ValueDelta, 0, 1)
            )
        ))
    end

    return ColorSequence.new(NewKeypoints)
end

function EffectOps.ApplyResizeMultiplier(Multiplier : number, Instances : {Instance})
    if not Multiplier then
        return
    end

    for _, Instance in Instances do
        if Instance:IsA("ParticleEmitter") then
            Instance.Size = EffectOps.ScaleValueByMultiplier(Instance.Size, Multiplier)
        elseif Instance:IsA("Beam") then
            Instance.Width0 = Instance.Width0 * Multiplier
            Instance.Width1 = Instance.Width1 * Multiplier
        elseif Instance:IsA("Trail") then
            Instance.WidthScale = EffectOps.ScaleValueByMultiplier(Instance.WidthScale, Multiplier)
        elseif Instance:IsA("Attachment") then
            Instance.Position = Instance.Position * Multiplier
        end
    end
end

function EffectOps.ReadCurvePointsFromNumberSequence(Sequence : NumberSequence)
    local Keypoints = Sequence.Keypoints
        local MinValue = math.huge
    local MaxValue = -math.huge

    for _, Keypoint in Keypoints do
        MinValue = math.min(MinValue, Keypoint.Value)
        MaxValue = math.max(MaxValue, Keypoint.Value)
    end

    if MinValue == math.huge then
        MinValue = 0
        MaxValue = 1
    elseif MaxValue <= MinValue then
        MaxValue = MinValue + 1
    end

    local ValueRange = MaxValue - MinValue

    local Points = {}
    for _, Keypoint in Keypoints do
        table.insert(Points, {
            Time = Keypoint.Time,
            Value = math.clamp((Keypoint.Value - MinValue) / ValueRange, 0, 1),
            -- Existing NumberSequences have no tangent data, so preserve them as
            -- piecewise-linear curves until the user edits a handle.
            InHandleX = 0,
            InHandleY = 0,
            OutHandleX = 0,
            OutHandleY = 0,
        })
    end

        return Points, MinValue, MaxValue
end

function EffectOps.BuildNumberSequenceFromCurve(Points : {{Time : number, Value : number}}, MinRange : number, MaxRange : number)
    local Sorted = table.clone(Points)
    table.sort(Sorted, function(Left, Right)
        return Left.Time < Right.Time
    end)

    if #Sorted == 0 then
        return NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)})
    end

    local function GetHandle(Point, Prefix, DefaultX)
        local X = Point[Prefix .. "HandleX"]
        local Y = Point[Prefix .. "HandleY"]

        -- Support the original handle fields used by older curve data.
        if X == nil and Prefix == "Out" then
            X = Point.OutHandle
        elseif X == nil and Prefix == "In" then
            X = Point.InHandle
        end

        return X or DefaultX, Y or 0
    end

    local function Cubic(A, B, C, D, T)
        local U = 1 - T
        return A * U * U * U + 3 * B * U * U * T + 3 * C * U * T * T + D * T * T * T
    end

    local Samples = {}
    local SamplesPerSegment = math.max(2, math.floor(90 / math.max(1, #Sorted - 1)))

    for Index = 1, #Sorted - 1 do
        local Start = Sorted[Index]
        local Finish = Sorted[Index + 1]
        local OutX, OutY = GetHandle(Start, "Out", 0)
        local InX, InY = GetHandle(Finish, "In", 0)

        for Step = 0, SamplesPerSegment - 1 do
            local T = Step / SamplesPerSegment
            table.insert(Samples, {
                Time = Cubic(Start.Time, Start.Time + OutX, Finish.Time + InX, Finish.Time, T),
                Value = Cubic(Start.Value, Start.Value + OutY, Finish.Value + InY, Finish.Value, T),
            })
        end
    end

    local Last = Sorted[#Sorted]
    table.insert(Samples, {Time = Last.Time, Value = Last.Value})
    table.sort(Samples, function(Left, Right)
        return Left.Time < Right.Time
    end)

    local Keypoints = {}
    local LastTime = nil
    for _, Sample in Samples do
        local Time = math.clamp(Sample.Time, 0, 1)
        if LastTime == nil or Time > LastTime then
            table.insert(Keypoints, NumberSequenceKeypoint.new(
                Time,
                MinRange + math.clamp(Sample.Value, 0, 1) * (MaxRange - MinRange)
            ))
            LastTime = Time
        end
    end

        -- NumberSequence has a relatively small keypoint limit. Keep enough samples
    -- to retain the curve shape without passing an oversized table to Roblox.
    local MaximumKeypoints = 20
    if #Keypoints > MaximumKeypoints then
        local Simplified = {}
        for Index = 0, MaximumKeypoints - 1 do
            local SourceIndex = math.floor(Index * (#Keypoints - 1) / (MaximumKeypoints - 1)) + 1
            table.insert(Simplified, Keypoints[SourceIndex])
        end
        Keypoints = Simplified
    end

    return NumberSequence.new(Keypoints)
end

function EffectOps.ApplyMathOperation(Value: number, Property: string, Operation: string, Instances: {Instance})
    if not Value or Property == "" then
        return
    end

    for _, Instance in Instances do
        if not (Instance:IsA("ParticleEmitter") and Instance[Property]) then
            continue
        end

        local PropertyType = typeof(Instance[Property])

        if PropertyType == "NumberSequence" then
            local OldSequence = Instance[Property]
            local NewKeypoints = {}

            for _, Keypoint in OldSequence.Keypoints do
                local NewValue, NewEnvelope

                if Operation == "add" then
                    NewValue = Keypoint.Value + Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope + Value)
                elseif Operation == "subtract" then
                    NewValue = Keypoint.Value - Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope - Value)
                elseif Operation == "multiply" then
                    NewValue = Keypoint.Value * Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope * Value)
                elseif Operation == "divide" then
                    if Value == 0 then
                        continue
                    end

                    NewValue = Keypoint.Value / Value
                    NewEnvelope = Keypoint.Envelope and (Keypoint.Envelope / Value)
                end

                table.insert(NewKeypoints, NumberSequenceKeypoint.new(
                    Keypoint.Time,
                    NewValue,
                    NewEnvelope
                ))
            end

            Instance[Property] = NumberSequence.new(NewKeypoints)
        elseif PropertyType == "NumberRange" then
            local OldMin = Instance[Property].Min
            local OldMax = Instance[Property].Max
            local NewMin, NewMax

            if Operation == "add" then
                NewMin = OldMin + Value
                NewMax = OldMax + Value
            elseif Operation == "subtract" then
                NewMin = OldMin - Value
                NewMax = OldMax - Value
            elseif Operation == "multiply" then
                NewMin = OldMin * Value
                NewMax = OldMax * Value
            elseif Operation == "divide" then
                if Value == 0 then
                    continue
                end

                NewMin = OldMin / Value
                NewMax = OldMax / Value
            end

            Instance[Property] = NumberRange.new(NewMin, NewMax)
        elseif PropertyType == "number" then
            if Operation == "add" then
                Instance[Property] = Instance[Property] + Value
            elseif Operation == "subtract" then
                Instance[Property] = Instance[Property] - Value
            elseif Operation == "multiply" then
                Instance[Property] = Instance[Property] * Value
            elseif Operation == "divide" then
                if Value == 0 then
                    continue
                end

                Instance[Property] = Instance[Property] / Value
            end
        end
    end
end

return EffectOps

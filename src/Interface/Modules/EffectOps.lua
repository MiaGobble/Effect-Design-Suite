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

function EffectOps.BuildNumberSequenceFromCurve(Points : {{Time : number, Value : number}}, MaxRange : number)
    local Sorted = table.clone(Points)
    table.sort(Sorted, function(Left, Right)
        return Left.Time < Right.Time
    end)

    local Keypoints = {}

    for _, Point in Sorted do
        table.insert(Keypoints, NumberSequenceKeypoint.new(
            math.clamp(Point.Time, 0, 1),
            math.clamp(Point.Value, 0, 1) * MaxRange
        ))
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

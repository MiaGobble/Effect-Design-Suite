--[[
    Template written by @iGottic

    This module can be played in runtime using the PlayEffect module, or by using the Effect Designer Suite plugin.
    This goes directly into an effect bin since it's treated as an effect object (just like a particle emitter or sound).

    API:
        Effect.Lifetime : number
        Effect.GetLifetime : (Parent : Instance) -> number
        Effect.Callback : (Parent : Instance) -> nil
        Effect.Cleanup : (Parent : Instance) -> nil
]]

local HttpService = game:GetService("HttpService")

local Effect = {}

Effect.Identifier = "VISUAL_EFFECT"
Effect.Lifetime = 1

local CURVE_PREFIX = "EffectDesignerCurve_"
local COLOR_ATTRIBUTE = "EffectDesignerOklabColorSequence"
local ORIGINAL_SIZE = "EffectDesignerOriginalSize"
local ORIGINAL_TRANSPARENCY = "EffectDesignerOriginalTransparency"
local ORIGINAL_COLOR = "EffectDesignerOriginalColor"

local function FindPackage(Name : string)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Shared = ReplicatedStorage:FindFirstChild("EffectDesignerSuite")
    if Shared then
        local Module = Shared:FindFirstChild(Name)
        if Module then
            return require(Module)
        end
    end

    local Current = script
    for _ = 1, 8 do
        Current = Current.Parent
        if not Current then
            break
        end

        local Direct = Current:FindFirstChild(Name)
        if Direct then
            return require(Direct)
        end

        local Packages = Current:FindFirstChild("Packages")
        if Packages then
            local Packaged = Packages:FindFirstChild(Name)
            if Packaged then
                return require(Packaged)
            end
        end
    end

    return nil
end

local function GetScopeRegistry()
    if shared.EDSPartAnimationScopes == nil then
        shared.EDSPartAnimationScopes = setmetatable({}, {__mode = "k"})
    end

    return shared.EDSPartAnimationScopes
end

local function DecodeJson(Text)
    if typeof(Text) ~= "string" or Text == "" then
        return nil
    end

    local Success, Decoded = pcall(function()
        return HttpService:JSONDecode(Text)
    end)

    if Success and typeof(Decoded) == "table" then
        return Decoded
    end

    return nil
end

local function ReadCurve(Parent : Instance, Property : string)
    local Points = DecodeJson(Parent:GetAttribute(CURVE_PREFIX .. Property))
    if typeof(Points) ~= "table" or #Points < 2 then
        return nil
    end

    local MinRange = tonumber(Parent:GetAttribute(CURVE_PREFIX .. Property .. "_MinRange"))
    local MaxRange = tonumber(Parent:GetAttribute(CURVE_PREFIX .. Property .. "_MaxRange"))

    return {
        Points = Points,
        MinRange = MinRange or 0,
        MaxRange = MaxRange or 1,
    }
end

local function GetHandle(Point, Prefix, DefaultX)
    local X = Point[Prefix .. "HandleX"]
    local Y = Point[Prefix .. "HandleY"]

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

local function SampleCurve(Curve, Time : number)
    local Sorted = table.clone(Curve.Points)
    table.sort(Sorted, function(Left, Right)
        return (Left.Time or 0) < (Right.Time or 0)
    end)

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

    local ClampedTime = math.clamp(Time, 0, 1)
    local Normalized = 0

    if ClampedTime <= Samples[1].Time then
        Normalized = Samples[1].Value
    elseif ClampedTime >= Samples[#Samples].Time then
        Normalized = Samples[#Samples].Value
    else
        for Index = 1, #Samples - 1 do
            local Start = Samples[Index]
            local Finish = Samples[Index + 1]
            if ClampedTime <= Finish.Time then
                local Duration = Finish.Time - Start.Time
                local Alpha = if Duration <= 0 then 0 else (ClampedTime - Start.Time) / Duration
                Normalized = Start.Value + (Finish.Value - Start.Value) * Alpha
                break
            end
        end
    end

    return Curve.MinRange + math.clamp(Normalized, 0, 1) * (Curve.MaxRange - Curve.MinRange)
end

local function PointToOklab(Point)
    return Vector3.new(Point.L, Point.A, Point.B)
end

local function SampleColor(Points, Time : number, Oklab)
    local Sorted = table.clone(Points)
    table.sort(Sorted, function(Left, Right)
        return Left.Time < Right.Time
    end)

    local ClampedTime = math.clamp(Time, 0, 1)
    local OklabValue

    if #Sorted == 1 or ClampedTime <= Sorted[1].Time then
        OklabValue = PointToOklab(Sorted[1])
    else
        OklabValue = PointToOklab(Sorted[#Sorted])
        for Index = 1, #Sorted - 1 do
            local Start = Sorted[Index]
            local Finish = Sorted[Index + 1]
            if ClampedTime <= Finish.Time then
                local Duration = Finish.Time - Start.Time
                local Alpha = if Duration <= 0 then 0 else (ClampedTime - Start.Time) / Duration
                OklabValue = PointToOklab(Start):Lerp(PointToOklab(Finish), math.clamp(Alpha, 0, 1))
                break
            end
        end
    end

    return Oklab.FromOklab(OklabValue)
end

function Effect.GetLifetime(Parent : Instance)
    local Duration = tonumber(Parent:GetAttribute("EmitDuration"))
    if Duration and Duration > 0 then
        return Duration
    end

    return Effect.Lifetime
end

function Effect.Callback(Parent : Instance)
    if not Parent or not Parent:IsA("BasePart") then
        return
    end

    Effect.Cleanup(Parent)

    local Seam = FindPackage("Seam")
    if not Seam then
        warn("Effect Designer Suite could not find Seam, so part animation was skipped.")
        return
    end

    local TransparencyCurve = ReadCurve(Parent, "Transparency")
    local ScaleCurve = ReadCurve(Parent, "Scale")
    local ColorPoints = DecodeJson(Parent:GetAttribute(COLOR_ATTRIBUTE))
    if typeof(ColorPoints) ~= "table" or #ColorPoints < 2 then
        ColorPoints = nil
    end

    if not TransparencyCurve and not ScaleCurve and not ColorPoints then
        return
    end

    local Oklab = nil
    if ColorPoints then
        Oklab = FindPackage("Oklab")
        if not Oklab then
            warn("Effect Designer Suite could not find Oklab, so part color animation was skipped.")
            ColorPoints = nil
        end
    end

    local Lifetime = Effect.GetLifetime(Parent)
    local OriginalSize = Parent:GetAttribute(ORIGINAL_SIZE)
    if typeof(OriginalSize) ~= "Vector3" then
        OriginalSize = Parent.Size
    end

    local Scope = Seam.Scope(Seam)
    local AlphaTarget = Scope:Value(0)
    local AnimatedAlpha = Scope:Tween(AlphaTarget, TweenInfo.new(Lifetime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out))

    local function ApplyAlpha(Alpha : number)
        if not Parent.Parent then
            return
        end

        if TransparencyCurve then
            Parent.Transparency = SampleCurve(TransparencyCurve, Alpha)
        end

        if ScaleCurve then
            Parent.Size = OriginalSize * SampleCurve(ScaleCurve, Alpha)
        end

        if ColorPoints and Oklab then
            Parent.Color = SampleColor(ColorPoints, Alpha, Oklab)
        end
    end

    ApplyAlpha(0)
    Scope:AddObject(Seam.OnChanged(AnimatedAlpha, function()
        ApplyAlpha(AnimatedAlpha.Value)
    end))

    GetScopeRegistry()[Parent] = Scope
    AlphaTarget.Value = 1
end

function Effect.Cleanup(Parent : Instance)
    local Registry = GetScopeRegistry()
    local Scope = Registry[Parent]
    if Scope then
        Registry[Parent] = nil
        pcall(function()
            Scope:Destroy()
        end)
    end

    if not Parent or not Parent:IsA("BasePart") then
        return
    end

    local OriginalTransparency = Parent:GetAttribute(ORIGINAL_TRANSPARENCY)
    if typeof(OriginalTransparency) == "number" and ReadCurve(Parent, "Transparency") then
        Parent.Transparency = OriginalTransparency
    end

    local OriginalSize = Parent:GetAttribute(ORIGINAL_SIZE)
    if typeof(OriginalSize) == "Vector3" and ReadCurve(Parent, "Scale") then
        Parent.Size = OriginalSize
    end

    local OriginalColor = Parent:GetAttribute(ORIGINAL_COLOR)
    if typeof(OriginalColor) == "Color3" and DecodeJson(Parent:GetAttribute(COLOR_ATTRIBUTE)) then
        Parent.Color = OriginalColor
    end
end

return Effect

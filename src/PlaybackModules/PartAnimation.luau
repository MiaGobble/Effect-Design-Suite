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

local Effect = {}

-- Constants
local VISUAL_EFFECT_IDENTIFIER = "VISUAL_EFFECT"
local DEFAULT_LIFETIME = 1
local CURVE_PREFIX = "EffectDesignerCurve_"
local COLOR_ATTRIBUTE = "EffectDesignerOklabColorSequence"
local ORIGINAL_SIZE = "EffectDesignerOriginalSize"
local ORIGINAL_TRANSPARENCY = "EffectDesignerOriginalTransparency"
local ORIGINAL_COLOR = "EffectDesignerOriginalColor"
local SHARED_FOLDER_NAME = "EffectDesignerSuite"
local PACKAGE_SEARCH_DEPTH = 8
local CURVE_SAMPLE_BUDGET = 90
local SCOPE_REGISTRY_NAME = "EDSPartAnimationScopes"

-- Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Constants extended
Effect.Identifier = VISUAL_EFFECT_IDENTIFIER
Effect.Lifetime = DEFAULT_LIFETIME

local function FindPackage(name : string)
    local Shared = ReplicatedStorage:FindFirstChild(SHARED_FOLDER_NAME)
    if Shared then
        local Module = Shared:FindFirstChild(name)
        if Module then
            return require(Module)
        end
    end

    local Current = script
    for _ = 1, PACKAGE_SEARCH_DEPTH do
        Current = Current.Parent
        if not Current then
            break
        end

        local Direct = Current:FindFirstChild(name)
        if Direct then
            return require(Direct)
        end

        local Packages = Current:FindFirstChild("Packages")
        if Packages then
            local Packaged = Packages:FindFirstChild(name)
            if Packaged then
                return require(Packaged)
            end
        end
    end

    return nil
end

local function GetScopeRegistry()
    if shared[SCOPE_REGISTRY_NAME] == nil then
        shared[SCOPE_REGISTRY_NAME] = setmetatable({}, {__mode = "k"})
    end

    return shared[SCOPE_REGISTRY_NAME]
end

local function DecodeJson(text)
    if typeof(text) ~= "string" or text == "" then
        return nil
    end

    local Success, Decoded = pcall(function()
        return HttpService:JSONDecode(text)
    end)

    if Success and typeof(Decoded) == "table" then
        return Decoded
    end

    return nil
end

local function ReadCurve(parent : Instance, property : string)
    local Points = DecodeJson(parent:GetAttribute(CURVE_PREFIX .. property))
    if typeof(Points) ~= "table" or #Points < 2 then
        return nil
    end

    local MinRange = tonumber(parent:GetAttribute(CURVE_PREFIX .. property .. "_MinRange"))
    local MaxRange = tonumber(parent:GetAttribute(CURVE_PREFIX .. property .. "_MaxRange"))

    return {
        Points = Points,
        MinRange = MinRange or 0,
        MaxRange = MaxRange or 1,
    }
end

local function GetHandle(point, prefix, defaultX)
    local X = point[prefix .. "HandleX"]
    local Y = point[prefix .. "HandleY"]

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

local function SampleCurve(curve, time : number)
    local Sorted = table.clone(curve.Points)
    table.sort(Sorted, function(left, right)
        return (left.Time or 0) < (right.Time or 0)
    end)

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

    local ClampedTime = math.clamp(time, 0, 1)
    local Normalized = 0

    if ClampedTime <= Samples[1].Time then
        Normalized = Samples[1].Value
    elseif ClampedTime >= Samples[#Samples].Time then
        Normalized = Samples[#Samples].Value
    else
        for index = 1, #Samples - 1 do
            local Start = Samples[index]
            local Finish = Samples[index + 1]
            if ClampedTime <= Finish.Time then
                local Duration = Finish.Time - Start.Time
                local Alpha = if Duration <= 0 then 0 else (ClampedTime - Start.Time) / Duration
                Normalized = Start.Value + (Finish.Value - Start.Value) * Alpha
                break
            end
        end
    end

    return curve.MinRange + math.clamp(Normalized, 0, 1) * (curve.MaxRange - curve.MinRange)
end

local function PointToOklab(point)
    return Vector3.new(point.L, point.A, point.B)
end

local function SampleColor(points, time : number, oklab)
    local Sorted = table.clone(points)
    table.sort(Sorted, function(left, right)
        return left.Time < right.Time
    end)

    local ClampedTime = math.clamp(time, 0, 1)
    local OklabValue

    if #Sorted == 1 or ClampedTime <= Sorted[1].Time then
        OklabValue = PointToOklab(Sorted[1])
    else
        OklabValue = PointToOklab(Sorted[#Sorted])
        for index = 1, #Sorted - 1 do
            local Start = Sorted[index]
            local Finish = Sorted[index + 1]
            if ClampedTime <= Finish.Time then
                local Duration = Finish.Time - Start.Time
                local Alpha = if Duration <= 0 then 0 else (ClampedTime - Start.Time) / Duration
                OklabValue = PointToOklab(Start):Lerp(PointToOklab(Finish), math.clamp(Alpha, 0, 1))
                break
            end
        end
    end

    return oklab.FromOklab(OklabValue)
end

function Effect.GetLifetime(parent : Instance)
    local Duration = tonumber(parent:GetAttribute("EmitDuration"))
    if Duration and Duration > 0 then
        return Duration
    end

    return Effect.Lifetime
end

function Effect.Callback(parent : Instance)
    if not parent or not parent:IsA("BasePart") then
        return
    end

    Effect.Cleanup(parent)

    local Seam = FindPackage("Seam")
    if not Seam then
        warn(`Effect Designer Suite could not find Seam, so part animation was skipped. {debug.traceback()}`)
        return
    end

    local TransparencyCurve = ReadCurve(parent, "Transparency")
    local ScaleCurve = ReadCurve(parent, "Scale")
    local ColorPoints = DecodeJson(parent:GetAttribute(COLOR_ATTRIBUTE))
    if typeof(ColorPoints) ~= "table" or #ColorPoints < 2 then
        ColorPoints = nil
    end

    if not TransparencyCurve and not ScaleCurve and not ColorPoints then
        return
    end

    local oklab = nil
    if ColorPoints then
        oklab = FindPackage("Oklab")
        if not oklab then
            warn(`Effect Designer Suite could not find Oklab, so part color animation was skipped. {debug.traceback()}`)
            ColorPoints = nil
        end
    end

    local Lifetime = Effect.GetLifetime(parent)
    local OriginalSize = parent:GetAttribute(ORIGINAL_SIZE)
    if typeof(OriginalSize) ~= "Vector3" then
        OriginalSize = parent.Size
    end

    local Scope = Seam.Scope(Seam)
    local AlphaTarget = Scope:Value(0)
    local AnimatedAlpha = Scope:Tween(AlphaTarget, TweenInfo.new(Lifetime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out))

    local function ApplyAlpha(alpha : number)
        if not parent.Parent then
            return
        end

        if TransparencyCurve then
            parent.Transparency = SampleCurve(TransparencyCurve, alpha)
        end

        if ScaleCurve then
            parent.Size = OriginalSize * SampleCurve(ScaleCurve, alpha)
        end

        if ColorPoints and oklab then
            parent.Color = SampleColor(ColorPoints, alpha, oklab)
        end
    end

    ApplyAlpha(0)
    Scope:AddObject(Seam.OnChanged(AnimatedAlpha, function()
        ApplyAlpha(AnimatedAlpha.Value)
    end))

    GetScopeRegistry()[parent] = Scope
    AlphaTarget.Value = 1
end

function Effect.Cleanup(parent : Instance)
    local Registry = GetScopeRegistry()
    local Scope = Registry[parent]
    if Scope then
        Registry[parent] = nil
        pcall(function()
            Scope:Destroy()
        end)
    end

    if not parent or not parent:IsA("BasePart") then
        return
    end

    local OriginalTransparency = parent:GetAttribute(ORIGINAL_TRANSPARENCY)
    if typeof(OriginalTransparency) == "number" and ReadCurve(parent, "Transparency") then
        parent.Transparency = OriginalTransparency
    end

    local OriginalSize = parent:GetAttribute(ORIGINAL_SIZE)
    if typeof(OriginalSize) == "Vector3" and ReadCurve(parent, "Scale") then
        parent.Size = OriginalSize
    end

    local OriginalColor = parent:GetAttribute(ORIGINAL_COLOR)
    if typeof(OriginalColor) == "Color3" and DecodeJson(parent:GetAttribute(COLOR_ATTRIBUTE)) then
        parent.Color = OriginalColor
    end
end

return Effect

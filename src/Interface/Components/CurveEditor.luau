local CurveEditor = {}

-- Constants
local PADDING = 8

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local LocalInput = require(Interface.Modules:FindFirstChild("LocalInput"))

local function Clamp01(value)
    return math.clamp(value, 0, 1)
end

local function SortPoints(points)
    table.sort(points, function(left, right)
        return left.Time < right.Time
    end)
end

local function ReadActiveValue(activeProperty)
    if typeof(activeProperty) == "boolean" then
        return activeProperty
    end

    if typeof(activeProperty) == "table" and activeProperty.Value ~= nil then
        return activeProperty.Value == true
    end

    return activeProperty ~= false
end

local function NormalizePoint(point)
    point.InHandleX = if typeof(point.InHandleX) == "number" then point.InHandleX else (typeof(point.InHandle) == "number" and point.InHandle or -0.2)
    point.InHandleY = if typeof(point.InHandleY) == "number" then point.InHandleY else 0
    point.OutHandleX = if typeof(point.OutHandleX) == "number" then point.OutHandleX else (typeof(point.OutHandle) == "number" and point.OutHandle or 0.2)
    point.OutHandleY = if typeof(point.OutHandleY) == "number" then point.OutHandleY else 0

    point.Time = Clamp01(point.Time)
    point.Value = Clamp01(point.Value)
end

local function CubicBezier(P0, P1, P2, P3, t)
    local U = 1 - t
    local TT = t * t
    local UU = U * U
    local UUU = UU * U
    local TTT = TT * t

    return (P0 * UUU) + (P1 * 3 * UU * t) + (P2 * 3 * U * TT) + (P3 * TTT)
end

function CurveEditor:Init(scope, properties)
    self.ActivePointIndex = scope:Value(nil)
    self.ActiveHandle = scope:Value(nil)
    self.IsDragging = scope:Value(false)

    if not properties.Points then
        properties.Points = scope:Value({
            {
                Time = 0,
                Value = 0,
                InHandleX = 0,
                InHandleY = 0,
                OutHandleX = 0.2,
                OutHandleY = 0,
            },
            {
                Time = 1,
                Value = 1,
                InHandleX = -0.2,
                InHandleY = 0,
                OutHandleX = 0,
                OutHandleY = 0,
            },
        })
    end

    for _, point in properties.Points.Value do
        NormalizePoint(point)
    end
end

function CurveEditor:Construct(scope, properties)
    local DragStartMouse = Vector2.new(0, 0)
    local DragStartTime = 0
    local DragStartValue = 0
    local DragStartHandleX = 0
    local DragStartHandleY = 0
    local DragSession

    local Frame = scope:New("Frame", {
        Parent = properties.Parent,
        LayoutOrder = properties.LayoutOrder,
        Position = properties.Position,
        AnchorPoint = properties.AnchorPoint,
        Size = properties.Size or UDim2.new(1, 0, 0, 200),
        BackgroundColor3 = Color3.fromRGB(18, 19, 24),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 8),
            }),
            scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                                Thickness = 1,
            }),
        },
    })

    local GridLayer = scope:New("Frame", {
        Parent = Frame,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
    })

    local PathLayer = scope:New("Frame", {
        Parent = Frame,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 2,
    })

    local HandleLayer = scope:New("Frame", {
        Parent = Frame,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
    })

    local PointLayer = scope:New("Frame", {
        Parent = Frame,
        BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
        ZIndex = 40,
    })

    local InteractionLayer = scope:New("TextButton", {
        Parent = Frame,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        -- Keep the catch-all insert target below the point and handle hit targets.
        ZIndex = 0,
        Active = true,
    })

    scope:New("TextLabel", {
        Parent = GridLayer,
        Position = UDim2.fromOffset(4, 2),
        Size = UDim2.fromOffset(26, 14),
        BackgroundTransparency = 1,
        FontFace = Font.fromName("SourceSans"),
        TextSize = 11,
        TextColor3 = Color3.fromRGB(190, 190, 190),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "1.0",
    })

    scope:New("TextLabel", {
        Parent = GridLayer,
        Position = UDim2.new(0, 4, 1, -16),
        Size = UDim2.fromOffset(26, 14),
        BackgroundTransparency = 1,
        FontFace = Font.fromName("SourceSans"),
        TextSize = 11,
        TextColor3 = Color3.fromRGB(190, 190, 190),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "0.0",
    })

    scope:New("TextLabel", {
        Parent = GridLayer,
        Position = UDim2.new(1, -30, 1, -16),
        Size = UDim2.fromOffset(26, 14),
        BackgroundTransparency = 1,
        FontFace = Font.fromName("SourceSans"),
        TextSize = 11,
        TextColor3 = Color3.fromRGB(190, 190, 190),
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = "1.0",
    })

    for _, tick in ipairs({0.25, 0.5, 0.75}) do
        scope:New("TextLabel", {
            Parent = GridLayer,
            Position = UDim2.new(0, 4, 1 - tick, -8),
            Size = UDim2.fromOffset(34, 14),
            BackgroundTransparency = 1,
            FontFace = Font.fromName("SourceSans"),
            TextSize = 10,
            TextColor3 = Color3.fromRGB(160, 160, 170),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.format("%.2f", tick),
        })

        scope:New("TextLabel", {
            Parent = GridLayer,
            Position = UDim2.new(tick, -14, 1, -16),
            Size = UDim2.fromOffset(28, 14),
            BackgroundTransparency = 1,
            FontFace = Font.fromName("SourceSans"),
            TextSize = 10,
            TextColor3 = Color3.fromRGB(160, 160, 170),
            TextXAlignment = Enum.TextXAlignment.Center,
            Text = string.format("%.2f", tick),
        })
    end

    for index = 1, 4 do
        local Alpha = index / 5

        scope:New("Frame", {
            Parent = GridLayer,
            Position = UDim2.fromScale(Alpha, 0),
            Size = UDim2.new(0, 1, 1, 0),
            BackgroundColor3 = Color3.fromRGB(40, 40, 46),
            BorderSizePixel = 0,
        })

        scope:New("Frame", {
            Parent = GridLayer,
            Position = UDim2.fromScale(0, Alpha),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Color3.fromRGB(40, 40, 46),
            BorderSizePixel = 0,
        })
    end

    local function GetGraphSize()
        local Width = math.max(1, Frame.AbsoluteSize.X - PADDING * 2)
        local Height = math.max(1, Frame.AbsoluteSize.Y - PADDING * 2)
        return Width, Height
    end

    local function ToPixel(time, value)
        local Width, Height = GetGraphSize()
        local X = PADDING + Clamp01(time) * Width
        local Y = PADDING + (1 - Clamp01(value)) * Height
        return Vector2.new(X, Y)
    end

    local function ToCurvePosition(localVector)
        local Width, Height = GetGraphSize()
        local Time = Clamp01((localVector.X - PADDING) / Width)
        local Value = Clamp01(1 - ((localVector.Y - PADDING) / Height))
        return Time, Value
    end

    local function DrawDot(parent, position, size, color)
        local Dot = Instance.new("Frame")
        Dot.Parent = parent
        Dot.Size = UDim2.fromOffset(size, size)
        Dot.Position = UDim2.fromOffset(position.X - (size * 0.5), position.Y - (size * 0.5))
        Dot.BackgroundColor3 = color
        Dot.BorderSizePixel = 0
        Dot.ZIndex = parent.ZIndex

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(1, 0)
        Corner.Parent = Dot

        return Dot
    end

    local function DrawLine(fromPosition, toPosition, color)
        local Delta = toPosition - fromPosition
        local Distance = Delta.Magnitude
        if Distance <= 0 then
            return
        end

        local Line = Instance.new("Frame")
        Line.Parent = PathLayer
        Line.AnchorPoint = Vector2.new(0.5, 0.5)
        Line.Position = UDim2.fromOffset((fromPosition.X + toPosition.X) * 0.5, (fromPosition.Y + toPosition.Y) * 0.5)
        Line.Size = UDim2.fromOffset(Distance, 2)
        Line.Rotation = math.deg(math.atan2(Delta.Y, Delta.X))
        Line.BackgroundColor3 = color
        Line.BorderSizePixel = 0
        Line.ZIndex = PathLayer.ZIndex
    end

    local function DrawBezierSegment(P0, P1, P2, P3, color)
        local Last = P0
        local Steps = 48
        for step = 1, Steps do
            local T = step / Steps
            local Current = CubicBezier(P0, P1, P2, P3, T)
            DrawLine(Last, Current, color)
            Last = Current
        end
    end

    local function CreateHitTarget(parent, position, size, zIndex, onInputBegan)
        local Hit = Instance.new("TextButton")
        Hit.Parent = parent
        Hit.Size = UDim2.fromOffset(size, size)
        Hit.Position = UDim2.fromOffset(position.X - size * 0.5, position.Y - size * 0.5)
        Hit.BackgroundTransparency = 1
        Hit.Text = ""
        Hit.AutoButtonColor = false
        Hit.Active = true
        Hit.ZIndex = zIndex
        Hit.InputBegan:Connect(onInputBegan)
        return Hit
    end

    local function ClearRenderLayers()
        for _, child in PathLayer:GetChildren() do
            child:Destroy()
        end

        for _, child in HandleLayer:GetChildren() do
            child:Destroy()
        end

        for _, child in PointLayer:GetChildren() do
            child:Destroy()
        end
    end

    local function GetPointsCopy()
        local NewPoints = table.clone(properties.Points.Value)
        for _, point in NewPoints do
            NormalizePoint(point)
        end
        SortPoints(NewPoints)
        return NewPoints
    end

    local function RenderVisuals()
        ClearRenderLayers()

        local Points = GetPointsCopy()

        for index, point in ipairs(Points) do
            local PointPixel = ToPixel(point.Time, point.Value)

            if index < #Points then
                local NextPoint = Points[index + 1]

                local P0 = PointPixel
                local P1 = ToPixel(point.Time + point.OutHandleX, point.Value + point.OutHandleY)
                local P2 = ToPixel(NextPoint.Time + NextPoint.InHandleX, NextPoint.Value + NextPoint.InHandleY)
                local P3 = ToPixel(NextPoint.Time, NextPoint.Value)

                DrawBezierSegment(P0, P1, P2, P3, Color3.fromRGB(108, 175, 255))
            end

            if index > 1 then
                local InPixel = ToPixel(point.Time + point.InHandleX, point.Value + point.InHandleY)
                DrawLine(PointPixel, InPixel, Color3.fromRGB(95, 120, 170))
                DrawDot(HandleLayer, InPixel, 7, Color3.fromRGB(130, 180, 255))

                CreateHitTarget(HandleLayer, InPixel, 14, 60, function(input)
                    if not ReadActiveValue(properties.Active) then
                        return
                    end

                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    self.ActiveHandle.Value = {Index = index, Kind = "In"}
                    local ScreenPosition = Vector2.new(input.Position.X, input.Position.Y)
                    DragStartMouse = LocalInput.GetLocalFromScreenPosition(Frame, ScreenPosition)
                    DragStartHandleX = point.InHandleX
                    DragStartHandleY = point.InHandleY
                    self.IsDragging.Value = true
                    DragSession.Start(DragStartMouse, input)
                end)
            end

            if index < #Points then
                local OutPixel = ToPixel(point.Time + point.OutHandleX, point.Value + point.OutHandleY)
                DrawLine(PointPixel, OutPixel, Color3.fromRGB(95, 120, 170))
                DrawDot(HandleLayer, OutPixel, 7, Color3.fromRGB(130, 180, 255))

                CreateHitTarget(HandleLayer, OutPixel, 14, 60, function(input)
                    if not ReadActiveValue(properties.Active) then
                        return
                    end

                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    self.ActiveHandle.Value = {Index = index, Kind = "Out"}
                    local ScreenPosition = Vector2.new(input.Position.X, input.Position.Y)
                    DragStartMouse = LocalInput.GetLocalFromScreenPosition(Frame, ScreenPosition)
                    DragStartHandleX = point.OutHandleX
                    DragStartHandleY = point.OutHandleY
                    self.IsDragging.Value = true
                    DragSession.Start(DragStartMouse, input)
                end)
            end

            DrawDot(PointLayer, PointPixel, 10, Color3.fromRGB(245, 245, 245))

            CreateHitTarget(PointLayer, PointPixel, 16, 61, function(input)
                if not ReadActiveValue(properties.Active) then
                    return
                end

                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    self.ActivePointIndex.Value = index
                    self.ActiveHandle.Value = nil
                    local ScreenPosition = Vector2.new(input.Position.X, input.Position.Y)
                    DragStartMouse = LocalInput.GetLocalFromScreenPosition(Frame, ScreenPosition)
                    DragStartTime = point.Time
                    DragStartValue = point.Value
                    self.IsDragging.Value = true
                    DragSession.Start(DragStartMouse, input)
                    return
                end

                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    if not ReadActiveValue(properties.Active) then
                        return
                    end

                    local Updated = GetPointsCopy()
                    if #Updated <= 2 then
                        return
                    end

                    table.remove(Updated, index)
                    properties.Points.Value = Updated
                    RenderVisuals()
                end
            end)
        end
    end

    local function IsNearExistingControl(mousePosition)
        local Points = GetPointsCopy()

        for index, point in ipairs(Points) do
            local PointPixel = ToPixel(point.Time, point.Value)
            if (PointPixel - mousePosition).Magnitude <= 12 then
                return true
            end

            if index > 1 then
                local InPixel = ToPixel(point.Time + point.InHandleX, point.Value + point.InHandleY)
                if (InPixel - mousePosition).Magnitude <= 12 then
                    return true
                end
            end

            if index < #Points then
                local OutPixel = ToPixel(point.Time + point.OutHandleX, point.Value + point.OutHandleY)
                if (OutPixel - mousePosition).Magnitude <= 12 then
                    return true
                end
            end
        end

        return false
    end

    Seam.New(InteractionLayer, {
        [Seam.OnEvent("InputBegan")] = function(input)
            if not ReadActiveValue(properties.Active) then
                return
            end

            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end

            local ScreenPosition = Vector2.new(input.Position.X, input.Position.Y)
            local MouseLocation = LocalInput.GetLocalFromScreenPosition(Frame, ScreenPosition)

            if IsNearExistingControl(MouseLocation) then
                return
            end

            local Time, Value = ToCurvePosition(MouseLocation)

            local NewPoints = GetPointsCopy()
            table.insert(NewPoints, {
                Time = Time,
                Value = Value,
                InHandleX = -0.12,
                InHandleY = 0,
                OutHandleX = 0.12,
                OutHandleY = 0,
            })
            SortPoints(NewPoints)

            properties.Points.Value = NewPoints
            RenderVisuals()
        end,
    })

    local function StopDrag()
        self.IsDragging.Value = false
        self.ActivePointIndex.Value = nil
        self.ActiveHandle.Value = nil
    end

    DragSession = LocalInput.BindPrimaryDrag(scope, Frame, function(mouseLocation)
        local NewPoints = GetPointsCopy()

        if self.ActivePointIndex.Value ~= nil then
            local Index = self.ActivePointIndex.Value
            local point = NewPoints[Index]
            if not point then
                return
            end

                        local Width, Height = GetGraphSize()
            local Delta = mouseLocation - DragStartMouse
            if Index == 1 then
                point.Time = 0
            elseif Index == #NewPoints then
                point.Time = 1
            else
                point.Time = Clamp01(DragStartTime + (Delta.X / math.max(1, Width)))
            end
            point.Value = Clamp01(DragStartValue - (Delta.Y / math.max(1, Height)))
                        SortPoints(NewPoints)
            properties.Points.Value = NewPoints
            return
        end

        if self.ActiveHandle.Value ~= nil then
            local HandleData = self.ActiveHandle.Value
            local point = NewPoints[HandleData.Index]
            if not point then
                return
            end

            local Width, Height = GetGraphSize()
            local Delta = mouseLocation - DragStartMouse
                        local DeltaTime = Delta.X / math.max(1, Width)
            local DeltaValue = -(Delta.Y / math.max(1, Height))

            if HandleData.Kind == "Out" then
                point.OutHandleX = DragStartHandleX + DeltaTime
                point.OutHandleY = DragStartHandleY + DeltaValue
            else
                point.InHandleX = DragStartHandleX + DeltaTime
                point.InHandleY = DragStartHandleY + DeltaValue
            end

                        properties.Points.Value = NewPoints
        end
    end, StopDrag)

    scope:OnChanged(self.IsDragging, function()
        if not self.IsDragging.Value then
            DragSession.Stop()
        end
    end)

    scope:OnChanged(properties.Points, RenderVisuals)
    scope:OnChanged(Frame, function(property)
        if property == "AbsoluteSize" then
            RenderVisuals()
        end
    end)
    RenderVisuals()

    return Frame
end

return Seam.Component(CurveEditor)

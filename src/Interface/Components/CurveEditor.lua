local CurveEditor = {}

local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local LocalInput = require(Interface.Modules:FindFirstChild("LocalInput"))

local PADDING = 8

local function Clamp01(Value)
    return math.clamp(Value, 0, 1)
end

local function SortPoints(Points)
    table.sort(Points, function(Left, Right)
        return Left.Time < Right.Time
    end)
end

local function ReadActiveValue(ActiveProperty)
    if typeof(ActiveProperty) == "boolean" then
        return ActiveProperty
    end

    if typeof(ActiveProperty) == "table" and ActiveProperty.Value ~= nil then
        return ActiveProperty.Value == true
    end

    return ActiveProperty ~= false
end

local function NormalizePoint(Point)
    Point.InHandleX = if typeof(Point.InHandleX) == "number" then Point.InHandleX else (typeof(Point.InHandle) == "number" and Point.InHandle or -0.2)
    Point.InHandleY = if typeof(Point.InHandleY) == "number" then Point.InHandleY else 0
    Point.OutHandleX = if typeof(Point.OutHandleX) == "number" then Point.OutHandleX else (typeof(Point.OutHandle) == "number" and Point.OutHandle or 0.2)
    Point.OutHandleY = if typeof(Point.OutHandleY) == "number" then Point.OutHandleY else 0

    Point.Time = Clamp01(Point.Time)
    Point.Value = Clamp01(Point.Value)
end

local function CubicBezier(P0, P1, P2, P3, T)
    local U = 1 - T
    local TT = T * T
    local UU = U * U
    local UUU = UU * U
    local TTT = TT * T

    return (P0 * UUU) + (P1 * 3 * UU * T) + (P2 * 3 * U * TT) + (P3 * TTT)
end

function CurveEditor:Init(Scope, Properties)
    self.ActivePointIndex = Scope:Value(nil)
    self.ActiveHandle = Scope:Value(nil)
    self.IsDragging = Scope:Value(false)

    if not Properties.Points then
        Properties.Points = Scope:Value({
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

    for _, Point in Properties.Points.Value do
        NormalizePoint(Point)
    end
end

function CurveEditor:Construct(Scope, Properties)
    local DragStartMouse = Vector2.new(0, 0)
    local DragStartTime = 0
    local DragStartValue = 0
    local DragStartHandleX = 0
    local DragStartHandleY = 0
    local DragSession

    local Frame = Scope:New("Frame", {
        Parent = Properties.Parent,
        LayoutOrder = Properties.LayoutOrder,
        Position = Properties.Position,
        AnchorPoint = Properties.AnchorPoint,
        Size = Properties.Size or UDim2.new(1, 0, 0, 200),
        BackgroundColor3 = Color3.fromRGB(18, 19, 24),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 8),
            }),
            Scope:New("UIStroke", {
                Color = Color3.fromRGB(56, 56, 56),
                Thickness = 1,
            }),
        },
    })

    local GridLayer = Scope:New("Frame", {
        Parent = Frame,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    })

    local PathLayer = Scope:New("Frame", {
        Parent = Frame,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    })

    local HandleLayer = Scope:New("Frame", {
        Parent = Frame,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    })

    local PointLayer = Scope:New("Frame", {
        Parent = Frame,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 40,
    })

    local InteractionLayer = Scope:New("TextButton", {
        Parent = Frame,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
        Active = true,
    })

    Scope:New("TextLabel", {
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

    Scope:New("TextLabel", {
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

    Scope:New("TextLabel", {
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

    for _, Tick in ipairs({0.25, 0.5, 0.75}) do
        Scope:New("TextLabel", {
            Parent = GridLayer,
            Position = UDim2.new(0, 4, 1 - Tick, -8),
            Size = UDim2.fromOffset(34, 14),
            BackgroundTransparency = 1,
            FontFace = Font.fromName("SourceSans"),
            TextSize = 10,
            TextColor3 = Color3.fromRGB(160, 160, 170),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.format("%.2f", Tick),
        })

        Scope:New("TextLabel", {
            Parent = GridLayer,
            Position = UDim2.new(Tick, -14, 1, -16),
            Size = UDim2.fromOffset(28, 14),
            BackgroundTransparency = 1,
            FontFace = Font.fromName("SourceSans"),
            TextSize = 10,
            TextColor3 = Color3.fromRGB(160, 160, 170),
            TextXAlignment = Enum.TextXAlignment.Center,
            Text = string.format("%.2f", Tick),
        })
    end

    for Index = 1, 4 do
        local Alpha = Index / 5

        Scope:New("Frame", {
            Parent = GridLayer,
            Position = UDim2.fromScale(Alpha, 0),
            Size = UDim2.new(0, 1, 1, 0),
            BackgroundColor3 = Color3.fromRGB(40, 40, 46),
            BorderSizePixel = 0,
        })

        Scope:New("Frame", {
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

    local function ToPixel(Time, Value)
        local Width, Height = GetGraphSize()
        local X = PADDING + Clamp01(Time) * Width
        local Y = PADDING + (1 - Clamp01(Value)) * Height
        return Vector2.new(X, Y)
    end

    local function ToCurvePosition(LocalVector)
        local Width, Height = GetGraphSize()
        local Time = Clamp01((LocalVector.X - PADDING) / Width)
        local Value = Clamp01(1 - ((LocalVector.Y - PADDING) / Height))
        return Time, Value
    end

    local function DrawDot(Parent, Position, Size, Color)
        local Dot = Scope:New("Frame", {
            Parent = Parent,
            Size = UDim2.fromOffset(Size, Size),
            Position = UDim2.fromOffset(Position.X - (Size * 0.5), Position.Y - (Size * 0.5)),
            BackgroundColor3 = Color,
            BorderSizePixel = 0,
            ZIndex = Parent.ZIndex,

            [Seam.Children] = {
                Scope:New("UICorner", {
                    CornerRadius = UDim.new(1, 0),
                }),
            },
        })

        return Dot
    end

    local function DrawLine(FromPosition, ToPosition, Color)
        local Delta = ToPosition - FromPosition
        local Distance = Delta.Magnitude
        if Distance <= 0 then
            return
        end

        local Steps = math.max(2, math.floor(Distance / 3))
        for Step = 0, Steps do
            local Alpha = Step / Steps
            local Position = FromPosition + Delta * Alpha
            DrawDot(PathLayer, Position, 3, Color)
        end
    end

    local function ClearRenderLayers()
        for _, Child in PathLayer:GetChildren() do
            Child:Destroy()
        end

        for _, Child in HandleLayer:GetChildren() do
            Child:Destroy()
        end

        for _, Child in PointLayer:GetChildren() do
            Child:Destroy()
        end
    end

    local function GetPointsCopy()
        local NewPoints = table.clone(Properties.Points.Value)
        for _, Point in NewPoints do
            NormalizePoint(Point)
        end
        SortPoints(NewPoints)
        return NewPoints
    end

    local function RenderVisuals()
        ClearRenderLayers()

        local Points = GetPointsCopy()

        for Index, Point in ipairs(Points) do
            local PointPixel = ToPixel(Point.Time, Point.Value)

            if Index < #Points then
                local NextPoint = Points[Index + 1]

                local P0 = PointPixel
                local P1 = ToPixel(Point.Time + Point.OutHandleX, Point.Value + Point.OutHandleY)
                local P2 = ToPixel(NextPoint.Time + NextPoint.InHandleX, NextPoint.Value + NextPoint.InHandleY)
                local P3 = ToPixel(NextPoint.Time, NextPoint.Value)

                local Last = P0
                local Steps = 40
                for Step = 1, Steps do
                    local T = Step / Steps
                    local Current = CubicBezier(P0, P1, P2, P3, T)
                    DrawLine(Last, Current, Color3.fromRGB(108, 175, 255))
                    Last = Current
                end

                pcall(function()
                    local PathObject = Instance.new("Path2D")
                    PathObject.Name = "CurvePath"
                    PathObject:SetAttribute("P0", string.format("%f,%f", Point.Time, Point.Value))
                    PathObject:SetAttribute("P1", string.format("%f,%f", NextPoint.Time, NextPoint.Value))
                    PathObject.Parent = PathLayer
                end)
            end

            if Index > 1 then
                local InPixel = ToPixel(Point.Time + Point.InHandleX, Point.Value + Point.InHandleY)
                DrawLine(PointPixel, InPixel, Color3.fromRGB(95, 120, 170))
                DrawDot(HandleLayer, InPixel, 7, Color3.fromRGB(130, 180, 255))

                local InHit = Scope:New("TextButton", {
                    Parent = HandleLayer,
                    Size = UDim2.fromOffset(14, 14),
                    Position = UDim2.fromOffset(InPixel.X - 7, InPixel.Y - 7),
                    BackgroundTransparency = 1,
                    Text = "",
                    AutoButtonColor = false,
                    Active = Properties.Active,
                })
                InHit.ZIndex = 60

                Scope:AddObject(InHit.InputBegan:Connect(function(Input)
                    if not ReadActiveValue(Properties.Active) then
                        return
                    end

                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    self.ActiveHandle.Value = {Index = Index, Kind = "In"}
                    local ScreenPosition = Vector2.new(Input.Position.X, Input.Position.Y)
                    DragStartMouse = LocalInput.GetLocalFromScreenPosition(Frame, ScreenPosition)
                    DragStartHandleX = Point.InHandleX
                    DragStartHandleY = Point.InHandleY
                    self.IsDragging.Value = true
                    DragSession.Start(DragStartMouse, Input)
                end))
            end

            if Index < #Points then
                local OutPixel = ToPixel(Point.Time + Point.OutHandleX, Point.Value + Point.OutHandleY)
                DrawLine(PointPixel, OutPixel, Color3.fromRGB(95, 120, 170))
                DrawDot(HandleLayer, OutPixel, 7, Color3.fromRGB(130, 180, 255))

                local OutHit = Scope:New("TextButton", {
                    Parent = HandleLayer,
                    Size = UDim2.fromOffset(14, 14),
                    Position = UDim2.fromOffset(OutPixel.X - 7, OutPixel.Y - 7),
                    BackgroundTransparency = 1,
                    Text = "",
                    AutoButtonColor = false,
                    Active = Properties.Active,
                })
                OutHit.ZIndex = 60

                Scope:AddObject(OutHit.InputBegan:Connect(function(Input)
                    if not ReadActiveValue(Properties.Active) then
                        return
                    end

                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    self.ActiveHandle.Value = {Index = Index, Kind = "Out"}
                    local ScreenPosition = Vector2.new(Input.Position.X, Input.Position.Y)
                    DragStartMouse = LocalInput.GetLocalFromScreenPosition(Frame, ScreenPosition)
                    DragStartHandleX = Point.OutHandleX
                    DragStartHandleY = Point.OutHandleY
                    self.IsDragging.Value = true
                    DragSession.Start(DragStartMouse, Input)
                end))
            end

            DrawDot(PointLayer, PointPixel, 10, Color3.fromRGB(245, 245, 245))

            local PointHit = Scope:New("TextButton", {
                Parent = PointLayer,
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.fromOffset(PointPixel.X - 8, PointPixel.Y - 8),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                Active = Properties.Active,
            })
            PointHit.ZIndex = 61

            Scope:AddObject(PointHit.InputBegan:Connect(function(Input)
                if not ReadActiveValue(Properties.Active) then
                    return
                end

                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    self.ActivePointIndex.Value = Index
                    self.ActiveHandle.Value = nil
                    local ScreenPosition = Vector2.new(Input.Position.X, Input.Position.Y)
                    DragStartMouse = LocalInput.GetLocalFromScreenPosition(Frame, ScreenPosition)
                    DragStartTime = Point.Time
                    DragStartValue = Point.Value
                    self.IsDragging.Value = true
                    DragSession.Start(DragStartMouse, Input)
                    return
                end

                if Input.UserInputType == Enum.UserInputType.MouseButton2 then
                    if not ReadActiveValue(Properties.Active) then
                        return
                    end

                    local Updated = GetPointsCopy()
                    if #Updated <= 2 then
                        return
                    end

                    table.remove(Updated, Index)
                    Properties.Points.Value = Updated
                    RenderVisuals()
                end
            end))
        end
    end

    local function IsNearExistingControl(MousePosition)
        local Points = GetPointsCopy()

        for Index, Point in ipairs(Points) do
            local PointPixel = ToPixel(Point.Time, Point.Value)
            if (PointPixel - MousePosition).Magnitude <= 12 then
                return true
            end

            if Index > 1 then
                local InPixel = ToPixel(Point.Time + Point.InHandleX, Point.Value + Point.InHandleY)
                if (InPixel - MousePosition).Magnitude <= 12 then
                    return true
                end
            end

            if Index < #Points then
                local OutPixel = ToPixel(Point.Time + Point.OutHandleX, Point.Value + Point.OutHandleY)
                if (OutPixel - MousePosition).Magnitude <= 12 then
                    return true
                end
            end
        end

        return false
    end

    Scope:AddObject(InteractionLayer.InputBegan:Connect(function(Input)
        if not ReadActiveValue(Properties.Active) then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        local ScreenPosition = Vector2.new(Input.Position.X, Input.Position.Y)
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

        Properties.Points.Value = NewPoints
        RenderVisuals()
    end))

    local function StopDrag()
        self.IsDragging.Value = false
        self.ActivePointIndex.Value = nil
        self.ActiveHandle.Value = nil
    end

    DragSession = LocalInput.BindPrimaryDrag(Scope, Frame, function(MouseLocation)
        local NewPoints = GetPointsCopy()

        if self.ActivePointIndex.Value ~= nil then
            local Index = self.ActivePointIndex.Value
            local Point = NewPoints[Index]
            if not Point then
                return
            end

            local Width, Height = GetGraphSize()
            local Delta = MouseLocation - DragStartMouse
            Point.Time = Clamp01(DragStartTime + (Delta.X / math.max(1, Width)))
            Point.Value = Clamp01(DragStartValue - (Delta.Y / math.max(1, Height)))
            SortPoints(NewPoints)
            Properties.Points.Value = NewPoints
            RenderVisuals()
            return
        end

        if self.ActiveHandle.Value ~= nil then
            local HandleData = self.ActiveHandle.Value
            local Point = NewPoints[HandleData.Index]
            if not Point then
                return
            end

            local Width, Height = GetGraphSize()
            local Delta = MouseLocation - DragStartMouse
            local DeltaTime = Delta.X / math.max(1, Width)
            local DeltaValue = -(Delta.Y / math.max(1, Height))

            if HandleData.Kind == "Out" then
                Point.OutHandleX = math.max(0, DragStartHandleX + DeltaTime)
                Point.OutHandleY = DragStartHandleY + DeltaValue
            else
                Point.InHandleX = math.min(0, DragStartHandleX + DeltaTime)
                Point.InHandleY = DragStartHandleY + DeltaValue
            end

            Properties.Points.Value = NewPoints
            RenderVisuals()
        end
    end, StopDrag)

    Scope:AddObject(Seam.OnChanged(self.IsDragging, function()
        if not self.IsDragging.Value then
            DragSession.Stop()
        end
    end))

    Scope:AddObject(Seam.OnChanged(Properties.Points, RenderVisuals))
    Scope:AddObject(Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(RenderVisuals))
    RenderVisuals()

    return Frame
end

return Seam.Component(CurveEditor)

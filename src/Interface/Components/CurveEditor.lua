local CurveEditor = {}

local UserInputService = game:GetService("UserInputService")

local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))

local function Clamp01(Value)
    return math.clamp(Value, 0, 1)
end

local function SortPoints(Points)
    table.sort(Points, function(Left, Right)
        return Left.Time < Right.Time
    end)
end

local function ResolveInputObject(FirstArg, SecondArg)
    if typeof(FirstArg) == "InputObject" then
        return FirstArg
    end

    if typeof(SecondArg) == "InputObject" then
        return SecondArg
    end

    return nil
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

function CurveEditor:Init(Scope, Properties)
    self.ActivePointIndex = Scope:Value(nil)
    self.IsDragging = Scope:Value(false)

    if not Properties.Points then
        Properties.Points = Scope:Value({
            {
                Time = 0,
                Value = 0,
                InHandle = 0,
                OutHandle = 0.2,
            },
            {
                Time = 1,
                Value = 1,
                InHandle = -0.2,
                OutHandle = 0,
            },
        })
    end
end

function CurveEditor:Construct(Scope, Properties)
    local Frame = Scope:New("Frame", {
        Parent = Properties.Parent,
        LayoutOrder = Properties.LayoutOrder,
        Position = Properties.Position,
        AnchorPoint = Properties.AnchorPoint,
        Size = Properties.Size or UDim2.new(1, 0, 0, 180),
        BackgroundColor3 = Color3.fromRGB(24, 24, 24),
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

    local PathFolder = Scope:New("Frame", {
        Parent = Frame,
        Name = "CurvePaths",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    })

    local DotFolder = Scope:New("Frame", {
        Parent = Frame,
        Name = "CurvePoints",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    })

    local HandleFolder = Scope:New("Frame", {
        Parent = Frame,
        Name = "CurveHandles",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    })

    local function GetPixelPoint(Point)
        local Width = math.max(1, Frame.AbsoluteSize.X - 12)
        local Height = math.max(1, Frame.AbsoluteSize.Y - 12)

        local X = 6 + Clamp01(Point.Time) * Width
        local Y = 6 + (1 - Clamp01(Point.Value)) * Height

        return Vector2.new(X, Y)
    end

    local function SerializePath(Path2DInstance, Left, Right)
        local Success = pcall(function()
            Path2DInstance:SetAttribute("P0", tostring(Left.Time) .. "," .. tostring(Left.Value))
            Path2DInstance:SetAttribute("P1", tostring(Right.Time) .. "," .. tostring(Right.Value))
        end)

        return Success
    end

    local function RenderVisuals()
        for _, Child in DotFolder:GetChildren() do
            Child:Destroy()
        end

        for _, Child in HandleFolder:GetChildren() do
            Child:Destroy()
        end

        for _, Child in PathFolder:GetChildren() do
            Child:Destroy()
        end

        local Points = table.clone(Properties.Points.Value)
        SortPoints(Points)

        local function DrawSampledLine(FromPoint : Vector2, ToPoint : Vector2)
            local Delta = ToPoint - FromPoint
            local Distance = Delta.Magnitude

            if Distance <= 0 then
                return
            end

            local Steps = math.max(2, math.floor(Distance / 4))

            for Step = 0, Steps do
                local Alpha = Step / Steps
                local Position = FromPoint + Delta * Alpha

                Scope:New("Frame", {
                    Parent = PathFolder,
                    Size = UDim2.fromOffset(3, 3),
                    Position = UDim2.fromOffset(Position.X - 1, Position.Y - 1),
                    BackgroundColor3 = Color3.fromRGB(110, 180, 255),
                    BorderSizePixel = 0,

                    [Seam.Children] = {
                        Scope:New("UICorner", {
                            CornerRadius = UDim.new(1, 0),
                        }),
                    },
                })
            end
        end

        for Index, Point in ipairs(Points) do
            local Pixel = GetPixelPoint(Point)

            local Dot = Scope:New("Frame", {
                Parent = DotFolder,
                Size = UDim2.fromOffset(10, 10),
                Position = UDim2.fromOffset(Pixel.X - 5, Pixel.Y - 5),
                BackgroundColor3 = Color3.fromRGB(245, 245, 245),
                BorderSizePixel = 0,

                [Seam.Children] = {
                    Scope:New("UICorner", {
                        CornerRadius = UDim.new(1, 0),
                    }),
                },
            })

            Scope:New("TextButton", {
                Parent = Dot,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                Active = Properties.Active,
                [Seam.OnEvent("InputBegan")] = function(FirstArg, SecondArg)
                    local Input = ResolveInputObject(FirstArg, SecondArg)
                    if not Input then
                        return
                    end

                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    self.ActivePointIndex.Value = Index
                    self.IsDragging.Value = true
                end,
            })

            local HandleX = 6 + Clamp01(Point.Time + (Point.OutHandle or 0)) * math.max(1, Frame.AbsoluteSize.X - 12)
            local HandleY = Pixel.Y

            Scope:New("Frame", {
                Parent = HandleFolder,
                Size = UDim2.fromOffset(6, 6),
                Position = UDim2.fromOffset(HandleX - 3, HandleY - 3),
                BackgroundColor3 = Color3.fromRGB(120, 180, 255),
                BorderSizePixel = 0,

                [Seam.Children] = {
                    Scope:New("UICorner", {
                        CornerRadius = UDim.new(1, 0),
                    }),
                },
            })

            DrawSampledLine(Pixel, Vector2.new(HandleX, HandleY))

            if Points[Index + 1] then
                local NextPoint = Points[Index + 1]
                local LeftPixel = Pixel
                local RightPixel = GetPixelPoint(NextPoint)

                DrawSampledLine(LeftPixel, RightPixel)

                local PathObjectSuccess, PathObject = pcall(function()
                    local NewPath = Instance.new("Path2D")
                    NewPath.Name = "CurvePath"
                    NewPath.Parent = PathFolder
                    return NewPath
                end)

                if PathObjectSuccess and PathObject then
                    SerializePath(PathObject, Point, NextPoint)
                end
            end
        end
    end

    local function AddPointFromInput(Input)
        local Relative = Vector2.new(Input.Position.X, Input.Position.Y) - Frame.AbsolutePosition
        local Width = math.max(1, Frame.AbsoluteSize.X - 12)
        local Height = math.max(1, Frame.AbsoluteSize.Y - 12)

        local Time = Clamp01((Relative.X - 6) / Width)
        local Value = Clamp01(1 - ((Relative.Y - 6) / Height))

        local NewPoints = table.clone(Properties.Points.Value)
        table.insert(NewPoints, {
            Time = Time,
            Value = Value,
            InHandle = -0.1,
            OutHandle = 0.1,
        })
        SortPoints(NewPoints)

        Properties.Points.Value = NewPoints
        RenderVisuals()
    end

    Scope:AddObject(Frame.InputBegan:Connect(function(Input)
        if not ReadActiveValue(Properties.Active) then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        local Position = Vector2.new(Input.Position.X, Input.Position.Y) - Frame.AbsolutePosition
        local CurrentPoints = Properties.Points.Value

        for _, Point in CurrentPoints do
            local Pixel = GetPixelPoint(Point)
            if (Pixel - Position).Magnitude <= 10 then
                return
            end
        end

        AddPointFromInput(Input)
    end))

    Scope:AddObject(UserInputService.InputChanged:Connect(function(Input)
        if not self.IsDragging.Value or self.ActivePointIndex.Value == nil then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local Relative = Vector2.new(Input.Position.X, Input.Position.Y) - Frame.AbsolutePosition
        local Width = math.max(1, Frame.AbsoluteSize.X - 12)
        local Height = math.max(1, Frame.AbsoluteSize.Y - 12)
        local Index = self.ActivePointIndex.Value

        local NewPoints = table.clone(Properties.Points.Value)
        local Point = NewPoints[Index]

        if not Point then
            return
        end

        Point.Time = Clamp01((Relative.X - 6) / Width)
        Point.Value = Clamp01(1 - ((Relative.Y - 6) / Height))

        SortPoints(NewPoints)
        Properties.Points.Value = NewPoints
        RenderVisuals()
    end))

    Scope:AddObject(UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.IsDragging.Value = false
            self.ActivePointIndex.Value = nil
        end
    end))

    Scope:AddObject(Seam.OnChanged(Properties.Points, RenderVisuals))
    Scope:AddObject(Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(RenderVisuals))
    RenderVisuals()

    return Frame
end

return Seam.Component(CurveEditor)

local ColorSequenceEditor = {}

local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local LocalInput = require(Interface.Modules:FindFirstChild("LocalInput"))
local EffectOps = require(Interface.Modules:FindFirstChild("EffectOps"))

local MAXIMUM_POINTS = 20
local TIME_EPSILON = 0.001
local CLICK_DRAG_THRESHOLD = 3

local function ReadActiveValue(ActiveProperty)
    if typeof(ActiveProperty) == "boolean" then
        return ActiveProperty
    end

    if typeof(ActiveProperty) == "table" and ActiveProperty.Value ~= nil then
        return ActiveProperty.Value == true
    end

    return ActiveProperty ~= false
end

local function CopyAndSortPoints(Points)
    local Copy = {}
    for _, Point in Points do
        table.insert(Copy, {
            Time = math.clamp(Point.Time, 0, 1),
            L = Point.L,
            A = Point.A,
            B = Point.B,
        })
    end
    table.sort(Copy, function(Left, Right)
        return Left.Time < Right.Time
    end)
    return Copy
end

function ColorSequenceEditor:Init(Scope)
    self.IsDragging = Scope:Value(false)
    self.DraggedPointIndex = nil
end

function ColorSequenceEditor:Construct(Scope, Properties)
    local DragStartMouse = Vector2.new(0, 0)
    local DragStartTime = 0
    local DragPointState = nil
    local PendingClickIndex = nil
    local DragExceededClickThreshold = false
    local DragWasCancelled = false
    local DragSession
    local MarkerScope = Scope:InnerScope()

    local Frame = Scope:New("Frame", {
        Parent = Properties.Parent,
        LayoutOrder = Properties.LayoutOrder,
        Position = Properties.Position,
        AnchorPoint = Properties.AnchorPoint,
        Size = Properties.Size or UDim2.new(1, 0, 0, 76),
        BackgroundColor3 = Color3.fromRGB(18, 19, 24),
        BorderSizePixel = 0,
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

    local GradientFrame = Scope:New("Frame", {
        Parent = Frame,
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(1, -20, 0, 30),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ClipsDescendants = true,

        [Seam.Children] = {
            Scope:New("UICorner", {
                CornerRadius = UDim.new(0, 4),
            }),
            Scope:New("UIStroke", {
                Color = Color3.fromRGB(78, 78, 78),
                Thickness = 1,
            }),
            Scope:New("UIGradient", {
                Color = Scope:Computed(function(Use)
                    return EffectOps.BuildColorSequenceFromOklabPoints(Use(Properties.Points))
                end),
            }),
        },
    })

    local InsertButton = Scope:New("TextButton", {
        Parent = GradientFrame,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Active = Properties.Active,
        ZIndex = 5,
    })

    local MarkerLayer = Scope:New("Frame", {
        Parent = Frame,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 10,
    })

    local function OpenPoint(Index)
        if Properties.ActivePointIndex then
            Properties.ActivePointIndex.Value = Index
        end
        if Properties.OnEditPoint then
            Properties.OnEditPoint(Index)
        end
    end

    local function GetPoints()
        return CopyAndSortPoints(Properties.Points.Value)
    end

    local function StopDrag()
        local ClickIndex = PendingClickIndex
        local ShouldOpenPoint = ClickIndex ~= nil
            and not DragExceededClickThreshold
            and not DragWasCancelled
            and ReadActiveValue(Properties.Active)
            and Properties.Points.Value == DragPointState

        self.IsDragging.Value = false
        self.DraggedPointIndex = nil
        DragPointState = nil
        PendingClickIndex = nil
        DragExceededClickThreshold = false
        DragWasCancelled = false

        if ShouldOpenPoint then
            OpenPoint(ClickIndex)
        end
    end

    DragSession = LocalInput.BindPrimaryDrag(Scope, Frame, function(MousePosition)
        if not ReadActiveValue(Properties.Active) or Properties.Points.Value ~= DragPointState then
            DragWasCancelled = true
            DragSession.Stop()
            return
        end

        local Index = self.DraggedPointIndex
        if not Index then
            return
        end

        local Points = GetPoints()
        local Point = Points[Index]
        if not Point then
            return
        end

        local Delta = MousePosition - DragStartMouse
        if Delta.Magnitude >= CLICK_DRAG_THRESHOLD and not DragExceededClickThreshold then
            DragExceededClickThreshold = true
            if Properties.OnEditPoint then
                Properties.OnEditPoint(nil)
            end
        end

        if Index == 1 then
            Point.Time = 0
        elseif Index == #Points then
            Point.Time = 1
        else
            local NewTime = DragStartTime + Delta.X / math.max(1, GradientFrame.AbsoluteSize.X)
            Point.Time = math.clamp(NewTime, Points[Index - 1].Time + TIME_EPSILON, Points[Index + 1].Time - TIME_EPSILON)
        end

        Properties.Points.Value = Points
        DragPointState = Points
    end, StopDrag)

    local function RenderMarkers()
        MarkerScope.Trove:Clean()

        local Points = GetPoints()
        local ActiveIndex = Properties.ActivePointIndex and Properties.ActivePointIndex.Value or nil

        for Index, Point in Points do
            local IsSelected = Index == ActiveIndex
            local Marker = MarkerScope:New("TextButton", {
                Parent = MarkerLayer,
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(Point.Time, 0, 0, 46),
                Size = UDim2.fromOffset(16, 16),
                BackgroundColor3 = EffectOps.OklabPointToColor3(Point),
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                Active = Properties.Active,
                ZIndex = 11,

                [Seam.Children] = {
                    MarkerScope:New("UICorner", {
                        CornerRadius = UDim.new(0, 3),
                    }),
                    MarkerScope:New("UIStroke", {
                        Color = if IsSelected then Color3.fromRGB(108, 175, 255) else Color3.fromRGB(230, 230, 230),
                        Thickness = if IsSelected then 2 else 1,
                    }),
                },
            })

            MarkerScope:AddObject(Marker.InputBegan:Connect(function(Input)
                if not ReadActiveValue(Properties.Active) then
                    return
                end

                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if Properties.ActivePointIndex then
                        Properties.ActivePointIndex.Value = Index
                    end
                    self.DraggedPointIndex = Index
                    PendingClickIndex = Index
                    DragExceededClickThreshold = false
                    DragWasCancelled = false
                    DragStartTime = Point.Time
                    local ScreenPosition = Vector2.new(Input.Position.X, Input.Position.Y)
                    DragStartMouse = LocalInput.GetLocalFromScreenPosition(Frame, ScreenPosition)
                    self.IsDragging.Value = true
                    DragPointState = Properties.Points.Value
                    DragSession.Start(DragStartMouse, Input)
                    return
                end

                if Input.UserInputType == Enum.UserInputType.MouseButton2 and Index > 1 and Index < #Points then
                    table.remove(Points, Index)
                    Properties.Points.Value = Points
                    if Properties.ActivePointIndex then
                        Properties.ActivePointIndex.Value = nil
                    end
                    if Properties.OnEditPoint then
                        Properties.OnEditPoint(nil)
                    end
                end
            end))
        end
    end

    Scope:AddObject(InsertButton.InputBegan:Connect(function(Input)
        if not ReadActiveValue(Properties.Active) or Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        local Points = GetPoints()
        if #Points >= MAXIMUM_POINTS then
            return
        end

        local ScreenPosition = Vector2.new(Input.Position.X, Input.Position.Y)
        local LocalMouse = LocalInput.GetLocalFromScreenPosition(GradientFrame, ScreenPosition)
        local Time = math.clamp(LocalMouse.X / math.max(1, GradientFrame.AbsoluteSize.X), TIME_EPSILON, 1 - TIME_EPSILON)
        for Index, Point in Points do
            if math.abs(Point.Time - Time) < 0.008 then
                if Properties.ActivePointIndex then
                    Properties.ActivePointIndex.Value = Index
                end
                if Properties.OnEditPoint then
                    Properties.OnEditPoint(nil)
                end
                return
            end
        end

        local Value = EffectOps.InterpolateOklabPoints(Points, Time)
        local NewPoint = {
            Time = Time,
            L = Value.X,
            A = Value.Y,
            B = Value.Z,
        }
        table.insert(Points, NewPoint)
        table.sort(Points, function(Left, Right)
            return Left.Time < Right.Time
        end)

        local NewIndex = table.find(Points, NewPoint)
        Properties.Points.Value = Points
        if Properties.ActivePointIndex then
            Properties.ActivePointIndex.Value = NewIndex
        end
        if Properties.OnEditPoint then
            Properties.OnEditPoint(nil)
        end
    end))

    Scope:AddObject(Seam.OnChanged(Properties.Points, RenderMarkers))
    if Properties.ActivePointIndex then
        Scope:AddObject(Seam.OnChanged(Properties.ActivePointIndex, RenderMarkers))
    end
    Scope:AddObject(Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(RenderMarkers))
    RenderMarkers()

    return Frame
end

return Seam.Component(ColorSequenceEditor)

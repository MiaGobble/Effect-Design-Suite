local ColorSequenceEditor = {}

-- Constants
local MAXIMUM_POINTS = 20
local TIME_EPSILON = 0.001
local CLICK_DRAG_THRESHOLD = 3

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local LocalInput = require(Interface.Modules:FindFirstChild("LocalInput"))
local EffectOps = require(Interface.Modules:FindFirstChild("EffectOps"))

local function ReadActiveValue(activeProperty)
    if typeof(activeProperty) == "boolean" then
        return activeProperty
    end

    if typeof(activeProperty) == "table" and activeProperty.Value ~= nil then
        return activeProperty.Value == true
    end

    return activeProperty ~= false
end

local function CopyAndSortPoints(points)
    local Copy = {}
    for _, point in points do
        table.insert(Copy, {
            Time = math.clamp(point.Time, 0, 1),
            L = point.L,
            A = point.A,
            B = point.B,
        })
    end
    table.sort(Copy, function(left, right)
        return left.Time < right.Time
    end)
    return Copy
end

function ColorSequenceEditor:Init(scope)
    self.IsDragging = scope:Value(false)
    self.DraggedPointIndex = nil
end

function ColorSequenceEditor:Construct(scope, properties)
    local DragStartMouse = Vector2.new(0, 0)
    local DragStartTime = 0
    local DragPointState = nil
    local PendingClickIndex = nil
    local DragExceededClickThreshold = false
    local DragWasCancelled = false
    local DragSession
    local MarkerScope = scope:InnerScope()

    local Frame = scope:New("Frame", {
        Parent = properties.Parent,
        LayoutOrder = properties.LayoutOrder,
        Position = properties.Position,
        AnchorPoint = properties.AnchorPoint,
        Size = properties.Size or UDim2.new(1, 0, 0, 76),
        BackgroundColor3 = Color3.fromRGB(18, 19, 24),
        BorderSizePixel = 0,
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

    local GradientFrame = scope:New("Frame", {
        Parent = Frame,
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(1, -20, 0, 30),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ClipsDescendants = true,

        [Seam.Children] = {
            scope:New("UICorner", {
                CornerRadius = UDim.new(0, 4),
            }),
            scope:New("UIStroke", {
                Color = Color3.fromRGB(78, 78, 78),
                Thickness = 1,
            }),
            scope:New("UIGradient", {
                Color = scope:Computed(function(use)
                    return EffectOps.BuildColorSequenceFromOklabPoints(use(properties.Points))
                end),
            }),
        },
    })

    local InsertButton = scope:New("TextButton", {
        Parent = GradientFrame,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Active = properties.Active,
        ZIndex = 5,
    })

    local MarkerLayer = scope:New("Frame", {
        Parent = Frame,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 10,
    })

    local function OpenPoint(index)
        if properties.ActivePointIndex then
            properties.ActivePointIndex.Value = index
        end
        if properties.OnEditPoint then
            properties.OnEditPoint(index)
        end
    end

    local function GetPoints()
        return CopyAndSortPoints(properties.Points.Value)
    end

    local function StopDrag()
        local ClickIndex = PendingClickIndex
        local ShouldOpenPoint = ClickIndex ~= nil
            and not DragExceededClickThreshold
            and not DragWasCancelled
            and ReadActiveValue(properties.Active)
            and properties.Points.Value == DragPointState

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

    DragSession = LocalInput.BindPrimaryDrag(scope, Frame, function(mousePosition)
        if not ReadActiveValue(properties.Active) or properties.Points.Value ~= DragPointState then
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

        local Delta = mousePosition - DragStartMouse
        if Delta.Magnitude >= CLICK_DRAG_THRESHOLD and not DragExceededClickThreshold then
            DragExceededClickThreshold = true
            if properties.OnEditPoint then
                properties.OnEditPoint(nil)
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

        properties.Points.Value = Points
        DragPointState = Points
    end, StopDrag)

    local function RenderMarkers()
        MarkerScope.Trove:Clean()

        local Points = GetPoints()
        local ActiveIndex = properties.ActivePointIndex and properties.ActivePointIndex.Value or nil

        for index, point in Points do
            local IsSelected = index == ActiveIndex
            local Marker = MarkerScope:New("TextButton", {
                Parent = MarkerLayer,
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(point.Time, 0, 0, 46),
                Size = UDim2.fromOffset(16, 16),
                BackgroundColor3 = EffectOps.OklabPointToColor3(point),
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                Active = properties.Active,
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

            MarkerScope:AddObject(Marker.InputBegan:Connect(function(input)
                if not ReadActiveValue(properties.Active) then
                    return
                end

                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if properties.ActivePointIndex then
                        properties.ActivePointIndex.Value = index
                    end
                    self.DraggedPointIndex = index
                    PendingClickIndex = index
                    DragExceededClickThreshold = false
                    DragWasCancelled = false
                    DragStartTime = point.Time
                    local ScreenPosition = Vector2.new(input.Position.X, input.Position.Y)
                    DragStartMouse = LocalInput.GetLocalFromScreenPosition(Frame, ScreenPosition)
                    self.IsDragging.Value = true
                    DragPointState = properties.Points.Value
                    DragSession.Start(DragStartMouse, input)
                    return
                end

                if input.UserInputType == Enum.UserInputType.MouseButton2 and index > 1 and index < #Points then
                    table.remove(Points, index)
                    properties.Points.Value = Points
                    if properties.ActivePointIndex then
                        properties.ActivePointIndex.Value = nil
                    end
                    if properties.OnEditPoint then
                        properties.OnEditPoint(nil)
                    end
                end
            end))
        end
    end

    scope:AddObject(InsertButton.InputBegan:Connect(function(input)
        if not ReadActiveValue(properties.Active) or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        local Points = GetPoints()
        if #Points >= MAXIMUM_POINTS then
            return
        end

        local ScreenPosition = Vector2.new(input.Position.X, input.Position.Y)
        local LocalMouse = LocalInput.GetLocalFromScreenPosition(GradientFrame, ScreenPosition)
        local Time = math.clamp(LocalMouse.X / math.max(1, GradientFrame.AbsoluteSize.X), TIME_EPSILON, 1 - TIME_EPSILON)
        for index, point in Points do
            if math.abs(point.Time - Time) < 0.008 then
                if properties.ActivePointIndex then
                    properties.ActivePointIndex.Value = index
                end
                if properties.OnEditPoint then
                    properties.OnEditPoint(nil)
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
        table.sort(Points, function(left, right)
            return left.Time < right.Time
        end)

        local NewIndex = table.find(Points, NewPoint)
        properties.Points.Value = Points
        if properties.ActivePointIndex then
            properties.ActivePointIndex.Value = NewIndex
        end
        if properties.OnEditPoint then
            properties.OnEditPoint(nil)
        end
    end))

    scope:AddObject(Seam.OnChanged(properties.Points, RenderMarkers))
    if properties.ActivePointIndex then
        scope:AddObject(Seam.OnChanged(properties.ActivePointIndex, RenderMarkers))
    end
    scope:AddObject(Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(RenderMarkers))
    RenderMarkers()

    return Frame
end

return Seam.Component(ColorSequenceEditor)

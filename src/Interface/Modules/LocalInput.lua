local LocalInput = {}

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local function TryConnectSignal(Object, SignalName, Callback)
    local Ok, Signal = pcall(function()
        return Object[SignalName]
    end)

    if not Ok or typeof(Signal) ~= "RBXScriptSignal" then
        return nil
    end

    return Signal:Connect(Callback)
end

local function TryGetOrCreateDragDetector(GuiObject : GuiObject)
    local Existing = GuiObject:FindFirstChildOfClass("UIDragDetector")
    if Existing then
        return Existing
    end

    local Ok, Detector = pcall(function()
        return Instance.new("UIDragDetector")
    end)

    if not Ok or not Detector then
        return nil
    end

    Detector.Parent = GuiObject
    return Detector
end

function LocalInput.GetLocalFromScreenPosition(GuiObject : GuiObject, ScreenPosition : Vector2)
    return ScreenPosition - GuiObject.AbsolutePosition
end

function LocalInput.GetLocalMousePosition(GuiObject : GuiObject)
    return LocalInput.GetLocalFromScreenPosition(GuiObject, UserInputService:GetMouseLocation())
end

function LocalInput.BindPrimaryDrag(Scope, GuiObject : GuiObject, OnMoved : (Vector2) -> (), OnStopped : (() -> ())?)
    local MoveConnection = nil
    local GlobalMoveConnection = nil
    local EndConnection = nil
    local GlobalEndConnection = nil
    local DragContinueConnection = nil
    local DragEndConnection = nil
    local PollConnection = nil

    local DragDetector = TryGetOrCreateDragDetector(GuiObject)

    local function DisconnectConnections()
        if MoveConnection then
            MoveConnection:Disconnect()
            MoveConnection = nil
        end

        if GlobalMoveConnection then
            GlobalMoveConnection:Disconnect()
            GlobalMoveConnection = nil
        end

        if EndConnection then
            EndConnection:Disconnect()
            EndConnection = nil
        end

        if GlobalEndConnection then
            GlobalEndConnection:Disconnect()
            GlobalEndConnection = nil
        end

        if DragContinueConnection then
            DragContinueConnection:Disconnect()
            DragContinueConnection = nil
        end

        if DragEndConnection then
            DragEndConnection:Disconnect()
            DragEndConnection = nil
        end

        if PollConnection then
            PollConnection:Disconnect()
            PollConnection = nil
        end
    end

    local function IsPrimaryMouseDown()
        local OkPressed, IsPressed = pcall(function()
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        end)

        if OkPressed and IsPressed then
            return true
        end

        local OkButtons, Buttons = pcall(function()
            return UserInputService:GetMouseButtonsPressed()
        end)

        if OkButtons and Buttons then
            for _, Button in Buttons do
                if Button == Enum.UserInputType.MouseButton1 then
                    return true
                end
            end
        end

        return false
    end

    local function Stop()
        DisconnectConnections()

        if OnStopped then
            OnStopped()
        end
    end

    local function Start(StartLocalPosition : Vector2?)
        DisconnectConnections()

        if StartLocalPosition then
            OnMoved(StartLocalPosition)
        else
            OnMoved(LocalInput.GetLocalMousePosition(GuiObject))
        end

        MoveConnection = GuiObject.MouseMoved:Connect(function(LocalX, LocalY)
            OnMoved(Vector2.new(LocalX, LocalY))
        end)

        GlobalMoveConnection = UserInputService.InputChanged:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end

            local ScreenPosition = Vector2.new(Input.Position.X, Input.Position.Y)
            OnMoved(LocalInput.GetLocalFromScreenPosition(GuiObject, ScreenPosition))
        end)

        EndConnection = GuiObject.InputEnded:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Stop()
            end
        end)

        GlobalEndConnection = UserInputService.InputEnded:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Stop()
            end
        end)

        PollConnection = RunService.Heartbeat:Connect(function()
            if not IsPrimaryMouseDown() then
                Stop()
            end
        end)

        if DragDetector then
            DragContinueConnection = TryConnectSignal(DragDetector, "DragContinue", function()
                OnMoved(LocalInput.GetLocalMousePosition(GuiObject))
            end)

            DragEndConnection = TryConnectSignal(DragDetector, "DragEnd", function()
                Stop()
            end)
        end
    end

    Scope:AddObject(function()
        Stop()
    end)

    return {
        Start = Start,
        Stop = Stop,
        IsDragging = function()
            return MoveConnection ~= nil
        end,
    }
end

return LocalInput
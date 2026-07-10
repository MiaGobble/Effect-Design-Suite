local LocalInput = {}

local UserInputService = game:GetService("UserInputService")

local function GetPluginMousePosition(GuiObject : GuiObject) : Vector2?
    local PluginGui = GuiObject:FindFirstAncestorWhichIsA("PluginGui")
    if not PluginGui then
        return nil
    end

    local Success, Position = pcall(function()
        return PluginGui:GetRelativeMousePosition()
    end)

    if Success and typeof(Position) == "Vector2" then
        return Position
    end

    return nil
end

function LocalInput.GetLocalFromScreenPosition(GuiObject : GuiObject, ScreenPosition : Vector2)
    -- AbsolutePosition is relative to a PluginGui, while InputObject.Position is
    -- relative to the Studio window. Use the plugin-local pointer when possible.
    local PointerPosition = GetPluginMousePosition(GuiObject) or ScreenPosition
    return PointerPosition - GuiObject.AbsolutePosition
end

function LocalInput.GetLocalMousePosition(GuiObject : GuiObject)
    local PointerPosition = GetPluginMousePosition(GuiObject) or UserInputService:GetMouseLocation()
    return PointerPosition - GuiObject.AbsolutePosition
end

function LocalInput.BindPrimaryDrag(Scope, GuiObject : GuiObject, OnMoved : (Vector2) -> (), OnStopped : (() -> ())?)
    local MoveConnection = nil
    local GlobalMoveConnection = nil
    local EndConnection = nil
    local GlobalEndConnection = nil
    local PrimaryInputConnection = nil
    local IsActive = false

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

        if PrimaryInputConnection then
            PrimaryInputConnection:Disconnect()
            PrimaryInputConnection = nil
        end

        IsActive = false
    end

    local function Stop()
        if not IsActive then
            return
        end

        DisconnectConnections()

        if OnStopped then
            OnStopped()
        end
    end

    local function Start(StartLocalPosition : Vector2?, PrimaryInput : InputObject?)
        DisconnectConnections()
        IsActive = true

        OnMoved(StartLocalPosition or LocalInput.GetLocalMousePosition(GuiObject))

        if PrimaryInput then
            PrimaryInputConnection = PrimaryInput:GetPropertyChangedSignal("UserInputState"):Connect(function()
                if PrimaryInput.UserInputState == Enum.UserInputState.End
                    or PrimaryInput.UserInputState == Enum.UserInputState.Cancel then
                    Stop()
                end
            end)
        end

        MoveConnection = GuiObject.MouseMoved:Connect(function()
            OnMoved(LocalInput.GetLocalMousePosition(GuiObject))
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
    end

    Scope:AddObject(function()
        Stop()
    end)

    return {
        Start = Start,
        Stop = Stop,
        IsDragging = function()
            return IsActive
        end,
    }
end

return LocalInput
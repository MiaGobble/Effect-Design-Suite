local LocalInput = {}

-- Services
local UserInputService = game:GetService("UserInputService")

local function GetPluginMousePosition(guiObject : GuiObject) : Vector2?
    local PluginGui = guiObject:FindFirstAncestorWhichIsA("PluginGui")
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

function LocalInput.GetLocalFromScreenPosition(guiObject : GuiObject, screenPosition : Vector2)
    -- AbsolutePosition is relative to a PluginGui, while InputObject.Position is
    -- relative to the Studio window. Use the plugin-local pointer when possible.
    local PointerPosition = GetPluginMousePosition(guiObject) or screenPosition
    return PointerPosition - guiObject.AbsolutePosition
end

function LocalInput.GetLocalMousePosition(guiObject : GuiObject)
    local PointerPosition = GetPluginMousePosition(guiObject) or UserInputService:GetMouseLocation()
    return PointerPosition - guiObject.AbsolutePosition
end

function LocalInput.BindPrimaryDrag(scope, guiObject : GuiObject, onMoved : (Vector2) -> (), onStopped : (() -> ())?)
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

        if onStopped then
            onStopped()
        end
    end

    local function Start(startLocalPosition : Vector2?, primaryInput : InputObject?)
        DisconnectConnections()
        IsActive = true

        onMoved(startLocalPosition or LocalInput.GetLocalMousePosition(guiObject))

        if primaryInput then
            PrimaryInputConnection = primaryInput:GetPropertyChangedSignal("UserInputState"):Connect(function()
                if primaryInput.UserInputState == Enum.UserInputState.End
                    or primaryInput.UserInputState == Enum.UserInputState.Cancel then
                    Stop()
                end
            end)
        end

        MoveConnection = guiObject.MouseMoved:Connect(function()
            onMoved(LocalInput.GetLocalMousePosition(guiObject))
        end)

        GlobalMoveConnection = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end

            local ScreenPosition = Vector2.new(input.Position.X, input.Position.Y)
            onMoved(LocalInput.GetLocalFromScreenPosition(guiObject, ScreenPosition))
        end)

        EndConnection = guiObject.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                Stop()
            end
        end)

        GlobalEndConnection = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                Stop()
            end
        end)
    end

    scope:AddObject(function()
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
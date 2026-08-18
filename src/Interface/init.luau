local Interface = {}

-- Imports
local Bin = script.Parent
local Packages = Bin:FindFirstChild("Packages")
local Seam = require(Packages:FindFirstChild("Seam"))
local Modules = script:FindFirstChild("Modules")
local Widgets = script:FindFirstChild("Widgets")
local SelectionQueries = require(Modules:FindFirstChild("SelectionQueries"))
local EditorSession = require(Modules:FindFirstChild("EditorSession"))
local Core = require(Widgets:FindFirstChild("Core"))
local Editing = require(Widgets:FindFirstChild("Editing"))
local Advanced = require(Widgets:FindFirstChild("Advanced"))
local Presets = require(Widgets:FindFirstChild("Presets"))
local ColorPicker = require(Widgets:FindFirstChild("ColorPicker"))
local CurveEditor = require(Widgets:FindFirstChild("CurveEditor"))
local ColorSequence = require(Widgets:FindFirstChild("ColorSequence"))

-- Variables
local InterfaceScope = nil

function Interface:Init()
    if InterfaceScope then
        InterfaceScope:Destroy()
        InterfaceScope = nil
    end

    local Scope = Seam.Scope(Seam)
    InterfaceScope = Scope

    local Selection = SelectionQueries.Create(Scope)
    local Session = EditorSession.Create(Scope)

    ColorPicker.Create(Scope, Session)
    CurveEditor.Create(Scope, Session)
    ColorSequence.Create(Scope, Session, Selection)

    return {
        Core = Core.Create(Scope, Session, Selection),
        Editing = Editing.Create(Scope, Session, Selection),
        Advanced = Advanced.Create(Scope, Session, Selection),
        Presets = Presets.Create(Scope, Session, Selection),
    }
end

return Interface

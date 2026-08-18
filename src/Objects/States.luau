-- Imports
local Seam = require(script.Parent.Parent:FindFirstChild("Packages"):FindFirstChild("Seam"))

-- Variables
local Scope = Seam.Scope(Seam)
local States = {}

States.CurrentlySelected = Scope:Value({})
States.RawSelection = Scope:Value({})
States.IsEditable = Scope:Value(false)
States.IsEmittable = Scope:Value(false)
States.PrimarySelected = Scope:Value(nil)
States.IsEffectModule = Scope:Value(false)
States.RepeatEmit = Scope:Value(false)
States.RepeatEmitDelay = Scope:Value(1)
States.IsPickingInstance = Scope:Value(false)

return States

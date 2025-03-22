-- Services
local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

-- Imports
local Fusion = require(script.Parent.Parent:FindFirstChild("Packages"):FindFirstChild("Fusion"))
local Scope = Fusion.scoped(Fusion)


return {
    -- The instances the current user has selected
    CurrentlySelected = Scope:Value({}),

    -- Whether in an editable state
    IsEditable = Scope:Value(false),

    -- Whether in an emittable state
    IsEmittable = Scope:Value(false),

    -- Primary selected instance, can only be one
    PrimarySelected = Scope:Value(nil),

    -- Whether the selected instance is an effect module
    IsEffectModule = Scope:Value(false),

    -- If repeat emit is on
    RepeatEmit = Scope:Value(false),

    -- Repeat emit delay
    RepeatEmitDelay = Scope:Value(1),
}
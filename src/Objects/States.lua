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
}
--[[
    Template written by @iGottic

    This module can be played in runtime using the PlayEffect module, or by using the Effect Designer Suite plugin.
    This goes directly into an effect bin since it's treated as an effect object (just like a particle emitter or sound).

    API:
        Effect.Lifetime : number
        Effect.Callback : (Parent : Instance) -> nil
        Effect.Cleanup : (Parent : Instance) -> nil
    
    Example:
        -- Assuming "effect" is a bin of effect objects, including particles and whatnot
        local PlayEffect = require(ReplicatedStorage.Common.PlayEffect)
        local EmitDuration = PlayEffect(effect) -- Plays the module inside the effect without any additional code
--]]

local Effect = {}

-- The identifier of the effect. DO NOT CHANGE THIS, OTHERWISE IT WILL NOT PLAY!
Effect.Identifier = "VISUAL_EFFECT"

-- The lifetime of the effect. When the time runs out, the effect will be cleaned up.
Effect.Lifetime = 1

-- Anything you want to do when the effect is played
function Effect.Callback(parent : Instance)
    -- Example: Create a lighting color correction effect
end

-- Anything you want to do when the effect is cleaned up
function Effect.Cleanup(parent : Instance)
    -- Example: Destroy the lighting color correction effect created a moment ago
end

return Effect
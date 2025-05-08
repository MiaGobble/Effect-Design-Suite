local AssetUtils = {}

-- Services
local RunService = game:GetService("RunService")

-- Imports
local Bin = script.Parent.Parent
local Objects = Bin:FindFirstChild("Objects")
local Packages = Bin:FindFirstChild("Packages")
local States = require(Objects:FindFirstChild("States"))
local Fusion = require(Packages:FindFirstChild("Fusion"))
local Peek = Fusion.peek

-- Variables
local Assets = Bin:FindFirstChild("Assets")
local Textures = Assets:FindFirstChild("Textures")

function AssetUtils:GetAllAssetCategories()
    local AssetCategories = {}

    for _, Module in Textures:GetChildren() do
        local Collection = require(Module)

        for _, Asset in Collection do
            if not table.find(AssetCategories, Asset.Type) then
                table.insert(AssetCategories, Asset.Type)
            end
        end
    end

    return AssetCategories
end

function AssetUtils:GetAssetsByCategory(Category)
    local Assets = {}

    for _, Module in Textures:GetChildren() do
        local Collection = require(Module)

        for _, Asset in Collection do
            if Asset.Type == Category then
                table.insert(Assets, Asset)
            end
        end
    end

    return Assets
end

return AssetUtils
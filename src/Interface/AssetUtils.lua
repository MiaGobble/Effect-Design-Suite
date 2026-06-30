local AssetUtils = {}

-- Imports
local Bin = script.Parent.Parent
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
    local MatchingAssets = {}

    for _, Module in Textures:GetChildren() do
        local Collection = require(Module)

        for _, Asset in Collection do
            if Asset.Type == Category then
                table.insert(MatchingAssets, Asset)
            end
        end
    end

    return MatchingAssets
end

return AssetUtils
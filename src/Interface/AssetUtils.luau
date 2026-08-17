local AssetUtils = {}

-- Imports
local Bin = script.Parent.Parent

-- Variables
local Assets = Bin:FindFirstChild("Assets")
local Textures = Assets:FindFirstChild("Textures")

local function CloneAsset(asset, categoryIndex : number)
    return {
        Type = asset.Type,
        FlipbookType = asset.FlipbookType,
        TextureId = asset.TextureId,
        CategoryIndex = categoryIndex,
    }
end

function AssetUtils:GetAssetCatalog()
    local Catalog = {}

    for _, module in Textures:GetChildren() do
        local Collection = require(module)

        for _, asset in Collection do
            local Category = asset.Type

            if not Catalog[Category] then
                Catalog[Category] = {}
            end

            table.insert(Catalog[Category], CloneAsset(asset, #Catalog[Category] + 1))
        end
    end

    local Categories = {}

    for category in Catalog do
        table.insert(Categories, category)
    end

    table.sort(Categories)

    for _, category in Categories do
        table.sort(Catalog[category], function(left, right)
            return tostring(left.TextureId) < tostring(right.TextureId)
        end)

        for index, asset in ipairs(Catalog[category]) do
            asset.CategoryIndex = index
        end
    end

    return {
        Categories = Categories,
        AssetsByCategory = Catalog,
    }
end

function AssetUtils:GetAllAssetCategories()
    return self:GetAssetCatalog().Categories
end

function AssetUtils:GetAssetsByCategory(category)
    return self:GetAssetCatalog().AssetsByCategory[category] or {}
end

return AssetUtils
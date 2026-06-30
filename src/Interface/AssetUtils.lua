local AssetUtils = {}

-- Imports
local Bin = script.Parent.Parent
-- Variables
local Assets = Bin:FindFirstChild("Assets")
local Textures = Assets:FindFirstChild("Textures")

local function CloneAsset(Asset, CategoryIndex : number)
    return {
        Type = Asset.Type,
        FlipbookType = Asset.FlipbookType,
        TextureId = Asset.TextureId,
        CategoryIndex = CategoryIndex,
    }
end

function AssetUtils:GetAssetCatalog()
    local Catalog = {}

    for _, Module in Textures:GetChildren() do
        local Collection = require(Module)

        for _, Asset in Collection do
            local Category = Asset.Type

            if not Catalog[Category] then
                Catalog[Category] = {}
            end

            table.insert(Catalog[Category], CloneAsset(Asset, #Catalog[Category] + 1))
        end
    end

    local Categories = {}

    for Category in Catalog do
        table.insert(Categories, Category)
    end

    table.sort(Categories)

    for _, Category in Categories do
        table.sort(Catalog[Category], function(Left, Right)
            return tostring(Left.TextureId) < tostring(Right.TextureId)
        end)

        for Index, Asset in ipairs(Catalog[Category]) do
            Asset.CategoryIndex = Index
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

function AssetUtils:GetAssetsByCategory(Category)
    return self:GetAssetCatalog().AssetsByCategory[Category] or {}
end

return AssetUtils
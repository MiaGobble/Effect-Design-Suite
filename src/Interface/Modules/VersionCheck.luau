local VersionCheck = {}

-- Constants
local VERSION_FILE_NAME = "VERSION.txt"
local VERSION_OBJECT_NAME = "VERSION"
local GITHUB_VERSION_URLS = {
    "https://raw.githubusercontent.com/MiaGobble/Effect-Design-Suite/main/src/VERSION.txt",
    "https://raw.githubusercontent.com/MiaGobble/Effect-Design-Suite/refs/heads/main/src/VERSION.txt",
    "https://raw.githubusercontent.com/MiaGobble/Effect-Design-Suite/main/VERSION.txt",
}
local HTTP_PERMISSION_NEEDLES = {
    "http requests are not enabled",
    "permission",
    "not allowed",
    "trust check",
    "aborted",
}
local HTTP_PERMISSION_WARNING = "This plugin does not have HTTP permissions and cannot check for updates."
local VERSION_READERS = {
    StringValue = function(versionObject)
        return versionObject.Value
    end,
    LuaSourceContainer = function(versionObject)
        return versionObject.Source
    end,
}

-- Services
local HttpService = game:GetService("HttpService")

-- Imports
local Interface = script.Parent.Parent
local Bin = Interface.Parent

local function TrimVersionText(text : string) : string
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function ParseVersionParts(text : string) : {number}?
    local Clean = string.match(text, "^v?(%d+[%.%d]*)$")
    if not Clean then
        return nil
    end

    local Parts = {}
    for number in string.gmatch(Clean, "%d+") do
        table.insert(Parts, tonumber(number) or 0)
    end

    if #Parts == 0 then
        return nil
    end

    return Parts
end

local function IsRemoteVersionNewer(remoteText : string, localText : string) : boolean
    local RemoteParts = ParseVersionParts(remoteText)
    local LocalParts = ParseVersionParts(localText)
    if not RemoteParts or not LocalParts then
        return false
    end

    local Count = math.max(#RemoteParts, #LocalParts)
    for index = 1, Count do
        local RemotePart = RemoteParts[index] or 0
        local LocalPart = LocalParts[index] or 0
        if RemotePart > LocalPart then
            return true
        elseif RemotePart < LocalPart then
            return false
        end
    end

    return false
end

local function ReadLocalVersion() : string?
    local VersionObject = Bin:FindFirstChild(VERSION_FILE_NAME) or Bin:FindFirstChild(VERSION_OBJECT_NAME)
    if not VersionObject then
        return nil
    end

    local Text = nil
    for className, reader in VERSION_READERS do
        if VersionObject:IsA(className) then
            Text = reader(VersionObject)
            break
        end
    end

    if typeof(Text) ~= "string" then
        return nil
    end

    Text = TrimVersionText(Text)
    if Text == "" then
        return nil
    end

    return Text
end

local function IsHttpPermissionError(thisError) : boolean
    local Text = string.lower(tostring(thisError))
    for _, needle in HTTP_PERMISSION_NEEDLES do
        if string.find(Text, needle, 1, true) ~= nil then
            return true
        end
    end

    return false
end

local function FetchGitHubVersion() : (string?, boolean)
    for _, url in GITHUB_VERSION_URLS do
        local Success, Result = pcall(function()
            return HttpService:GetAsync(url)
        end)

        if Success and typeof(Result) == "string" then
            local Text = TrimVersionText(Result)
            if Text ~= "" and ParseVersionParts(Text) then
                return Text, false
            end
        elseif not Success and IsHttpPermissionError(Result) then
            return nil, true
        end
    end

    return nil, false
end

function VersionCheck.Start(warningText)
    task.spawn(function()
        local RemoteVersion, PermissionDenied = FetchGitHubVersion()
        if PermissionDenied then
            warningText.Value = HTTP_PERMISSION_WARNING
            return
        end

        local LocalVersion = ReadLocalVersion()
        if not LocalVersion or not RemoteVersion then
            return
        end

        if IsRemoteVersionNewer(RemoteVersion, LocalVersion) then
            warningText.Value = string.format(
                "Update available: %s (you have %s). Please update Effect Designer Suite.",
                RemoteVersion,
                LocalVersion
            )
        end
    end)
end

return VersionCheck

-- ======================
-- FNAF POWER SYSTEM - UPDATER
-- ======================
-- Downloads latest files from GitHub

local GITHUB_USER = "tyler919"
local GITHUB_REPO = "cc-fnaf-power"
local BRANCH = "main"

local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/" .. BRANCH .. "/"

local FILES = {
    "central.lua",
    "door.lua",
    "light.lua",
    "generator.lua",
    "startup.lua",
    "update.lua",
}

local VERSION_URL = BASE_URL .. "version.json"
local LOCAL_VERSION_FILE = "fnaf_version.txt"

-- Get local version
local function getLocalVersion()
    if fs.exists(LOCAL_VERSION_FILE) then
        local f = fs.open(LOCAL_VERSION_FILE, "r")
        local ver = f.readAll()
        f.close()
        return ver:gsub("%s+", "")
    end
    return "0.0.0"
end

-- Save local version
local function saveLocalVersion(ver)
    local f = fs.open(LOCAL_VERSION_FILE, "w")
    f.write(ver)
    f.close()
end

-- Download a file
local function downloadFile(filename)
    local url = BASE_URL .. filename
    local response = http.get(url)

    if response then
        local content = response.readAll()
        response.close()

        local f = fs.open(filename, "w")
        f.write(content)
        f.close()

        return true
    end
    return false
end

-- Check for updates
local function checkForUpdates()
    print("Checking for updates...")

    local response = http.get(VERSION_URL)
    if not response then
        print("Could not reach update server.")
        return nil
    end

    local content = response.readAll()
    response.close()

    local versionData = textutils.unserializeJSON(content)
    if not versionData then
        print("Invalid version data.")
        return nil
    end

    return versionData
end

-- Compare versions (returns true if remote is newer)
local function isNewer(local_ver, remote_ver)
    local function parseVersion(v)
        local parts = {}
        for part in v:gmatch("(%d+)") do
            table.insert(parts, tonumber(part))
        end
        return parts
    end

    local l = parseVersion(local_ver)
    local r = parseVersion(remote_ver)

    for i = 1, math.max(#l, #r) do
        local lv = l[i] or 0
        local rv = r[i] or 0
        if rv > lv then return true end
        if rv < lv then return false end
    end

    return false
end

-- Main update function
local function doUpdate(force)
    term.clear()
    term.setCursorPos(1, 1)

    print("=== FNAF POWER UPDATER ===")
    print("")

    local localVer = getLocalVersion()
    print("Local version: " .. localVer)

    local versionData = checkForUpdates()
    if not versionData then
        print("")
        print("Update check failed.")
        print("Press any key...")
        os.pullEvent("key")
        return false
    end

    local remoteVer = versionData.version
    print("Remote version: " .. remoteVer)
    print("")

    if not force and not isNewer(localVer, remoteVer) then
        print("Already up to date!")
        print("")
        print("Press any key...")
        os.pullEvent("key")
        return false
    end

    if versionData.changelog then
        print("Changes: " .. versionData.changelog)
        print("")
    end

    print("Downloading updates...")
    print("")

    local success = true
    for _, filename in ipairs(FILES) do
        write("  " .. filename .. "... ")
        if downloadFile(filename) then
            print("OK")
        else
            print("FAILED")
            success = false
        end
    end

    print("")

    if success then
        saveLocalVersion(remoteVer)
        print("Update complete!")
        print("Version: " .. remoteVer)
        print("")
        print("Reboot now? (y/n)")
        local input = read()
        if input:lower() == "y" then
            os.reboot()
        end
    else
        print("Some files failed to download.")
        print("Try again later.")
    end

    return success
end

-- Handle command line args
local args = {...}
if args[1] == "force" then
    doUpdate(true)
elseif args[1] == "silent" then
    -- Silent update (for remote trigger)
    local versionData = checkForUpdates()
    if versionData and isNewer(getLocalVersion(), versionData.version) then
        for _, filename in ipairs(FILES) do
            downloadFile(filename)
        end
        saveLocalVersion(versionData.version)
        os.reboot()
    end
else
    doUpdate(false)
end

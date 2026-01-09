-- ======================
-- FNAF POWER SYSTEM - INSTALLER
-- ======================
-- Run this on any CC:Tweaked computer to install the FNAF power system
-- wget run https://raw.githubusercontent.com/tyler919/cc-fnaf-power/main/installer.lua

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

-- Main installer
local function main()
    term.clear()
    term.setCursorPos(1, 1)

    print("================================")
    print("  FNAF POWER SYSTEM INSTALLER")
    print("================================")
    print("")
    print("This will install the FNAF power")
    print("system on this computer.")
    print("")
    print("Continue? (y/n)")

    local input = read()
    if input:lower() ~= "y" then
        print("Installation cancelled.")
        return
    end

    print("")
    print("Downloading files...")
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

    -- Download version info
    write("  version check... ")
    local verResponse = http.get(BASE_URL .. "version.json")
    if verResponse then
        local verData = textutils.unserializeJSON(verResponse.readAll())
        verResponse.close()
        if verData and verData.version then
            local f = fs.open("fnaf_version.txt", "w")
            f.write(verData.version)
            f.close()
            print("OK (v" .. verData.version .. ")")
        else
            print("OK")
        end
    else
        print("SKIP")
    end

    print("")

    if success then
        print("Installation complete!")
        print("")
        print("The computer will now reboot")
        print("to start first-time setup.")
        print("")
        print("Press any key...")
        os.pullEvent("key")
        os.reboot()
    else
        print("Some files failed to download.")
        print("Check your internet connection")
        print("and try again.")
    end
end

main()

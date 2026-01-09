-- ======================
-- FNAF POWER SYSTEM - STARTUP
-- ======================
-- Automatically runs the correct script based on machine config

local CONFIG_FILE = "fnaf_config.lua"

-- Load config
local function loadConfig()
    if fs.exists(CONFIG_FILE) then
        local f = fs.open(CONFIG_FILE, "r")
        local data = textutils.unserialize(f.readAll())
        f.close()
        return data
    end
    return nil
end

-- Save config
local function saveConfig(config)
    local f = fs.open(CONFIG_FILE, "w")
    f.write(textutils.serialize(config))
    f.close()
end

-- First-time setup
local function firstTimeSetup()
    term.clear()
    term.setCursorPos(1, 1)

    print("=== FNAF POWER SYSTEM ===")
    print("")
    print("First-time setup!")
    print("")
    print("What is this machine?")
    print("")
    print("1. Central Controller")
    print("2. Left Door")
    print("3. Right Door")
    print("4. Left Hall Light")
    print("5. Right Hall Light")
    print("6. Room Light")
    print("7. Generator")
    print("")
    write("Choice (1-7): ")

    local choice = read()
    local config = {}

    if choice == "1" then
        config.type = "central"
        config.script = "central.lua"
    elseif choice == "2" then
        config.type = "door"
        config.id = "LEFT_DOOR"
        config.script = "door.lua"
    elseif choice == "3" then
        config.type = "door"
        config.id = "RIGHT_DOOR"
        config.script = "door.lua"
    elseif choice == "4" then
        config.type = "light"
        config.id = "LEFT_HALL"
        config.script = "light.lua"
    elseif choice == "5" then
        config.type = "light"
        config.id = "RIGHT_HALL"
        config.script = "light.lua"
    elseif choice == "6" then
        config.type = "light"
        config.id = "ROOM"
        config.script = "light.lua"
    elseif choice == "7" then
        config.type = "generator"
        config.script = "generator.lua"
    else
        print("Invalid choice!")
        sleep(2)
        os.reboot()
        return
    end

    -- Ask for redstone sides if door or light
    if config.type == "door" or config.type == "light" then
        print("")
        write("Button input side (left/right/top/bottom/front/back): ")
        config.buttonSide = read()

        write("Output side (left/right/top/bottom/front/back): ")
        config.outputSide = read()
    end

    -- Ask for chest side if generator
    if config.type == "generator" then
        print("")
        write("Chest side (left/right/top/bottom/front/back): ")
        config.chestSide = read()
    end

    saveConfig(config)
    print("")
    print("Config saved!")
    sleep(1)

    return config
end

-- Create the actual script with config values
local function createConfiguredScript(config)
    if config.type == "door" then
        -- Read door.lua and modify the config section
        if fs.exists("door.lua") then
            local f = fs.open("door.lua", "r")
            local content = f.readAll()
            f.close()

            -- Replace config values
            content = content:gsub('local DOOR_ID = "[^"]+"', 'local DOOR_ID = "' .. config.id .. '"')
            content = content:gsub('local BUTTON_SIDE = "[^"]+"', 'local BUTTON_SIDE = "' .. (config.buttonSide or "right") .. '"')
            content = content:gsub('local DOOR_SIDE = "[^"]+"', 'local DOOR_SIDE = "' .. (config.outputSide or "left") .. '"')

            local f2 = fs.open("door_configured.lua", "w")
            f2.write(content)
            f2.close()

            return "door_configured.lua"
        end
    elseif config.type == "light" then
        if fs.exists("light.lua") then
            local f = fs.open("light.lua", "r")
            local content = f.readAll()
            f.close()

            content = content:gsub('local LIGHT_ID = "[^"]+"', 'local LIGHT_ID = "' .. config.id .. '"')
            content = content:gsub('local BUTTON_SIDE = "[^"]+"', 'local BUTTON_SIDE = "' .. (config.buttonSide or "right") .. '"')
            content = content:gsub('local LAMP_SIDE = "[^"]+"', 'local LAMP_SIDE = "' .. (config.outputSide or "left") .. '"')

            local f2 = fs.open("light_configured.lua", "w")
            f2.write(content)
            f2.close()

            return "light_configured.lua"
        end
    elseif config.type == "generator" then
        if fs.exists("generator.lua") then
            local f = fs.open("generator.lua", "r")
            local content = f.readAll()
            f.close()

            content = content:gsub('local CHEST_SIDE = "[^"]+"', 'local CHEST_SIDE = "' .. (config.chestSide or "top") .. '"')

            local f2 = fs.open("generator_configured.lua", "w")
            f2.write(content)
            f2.close()

            return "generator_configured.lua"
        end
    end

    return config.script
end

-- Main
local function main()
    local config = loadConfig()

    if not config then
        config = firstTimeSetup()
    end

    if not config then
        print("Setup failed!")
        return
    end

    term.clear()
    term.setCursorPos(1, 1)
    print("=== FNAF POWER SYSTEM ===")
    print("")
    print("Type: " .. config.type)
    if config.id then
        print("ID: " .. config.id)
    end
    print("")
    print("Starting in 2 seconds...")
    print("(Hold Ctrl+T to cancel)")
    sleep(2)

    -- Get the script to run
    local scriptToRun = config.script

    -- For door/light/generator, create configured version
    if config.type == "door" or config.type == "light" or config.type == "generator" then
        scriptToRun = createConfiguredScript(config)
    end

    -- Run the script
    if fs.exists(scriptToRun) then
        shell.run(scriptToRun)
    else
        print("ERROR: " .. scriptToRun .. " not found!")
        print("")
        print("Run 'update' to download files.")
    end
end

main()

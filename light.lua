-- ======================
-- FNAF LIGHT CONTROLLER
-- ======================
-- Place on a computer with:
--   - Ender modem (any side)
--   - Redstone input from button (configurable side)
--   - Redstone output to lamp (configurable side)

-- ======================
-- CONFIG - CHANGE THESE!
-- ======================
local LIGHT_ID = "LEFT_HALL"   -- Change for each light: "LEFT_HALL", "RIGHT_HALL", "ROOM"
local BUTTON_SIDE = "right"    -- Side where button input comes from
local LAMP_SIDE = "left"       -- Side where lamp output goes

local PROTOCOL = "FNAF_POWER"
local REPORT_INTERVAL = 0.5    -- How often to send status

-- ======================
-- SETUP
-- ======================

-- Find and open modem
local modemSide = nil
for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
    if peripheral.getType(side) == "modem" then
        rednet.open(side)
        modemSide = side
        break
    end
end

if not modemSide then
    error("No modem found! Attach an ender modem.")
end

-- ======================
-- STATE
-- ======================
local lightRequest = false  -- Is button being pressed?
local lightEnabled = false  -- Is central allowing light?
local centralId = nil       -- Computer ID of central controller

-- Ensure light starts OFF
redstone.setOutput(LAMP_SIDE, false)

-- ======================
-- FIND CENTRAL
-- ======================
local function findCentral()
    rednet.broadcast({
        id = LIGHT_ID,
        deviceType = "light",
        type = "hello",
        requesting = false,
        active = false
    }, PROTOCOL)
end

-- ======================
-- REPORT STATUS
-- ======================
local function reportStatus()
    local msg = {
        id = LIGHT_ID,
        deviceType = "light",
        requesting = lightRequest,
        active = redstone.getOutput(LAMP_SIDE)
    }

    if centralId then
        rednet.send(centralId, msg, PROTOCOL)
    else
        rednet.broadcast(msg, PROTOCOL)
    end
end

-- ======================
-- LIGHT CONTROL LOOP
-- ======================
local function lightLoop()
    while true do
        -- Check if button is pressed
        lightRequest = redstone.getInput(BUTTON_SIDE)

        -- Only turn on light if requested AND enabled by central
        if lightRequest and lightEnabled then
            redstone.setOutput(LAMP_SIDE, true)
        else
            redstone.setOutput(LAMP_SIDE, false)
        end

        -- Report status to central
        reportStatus()

        sleep(REPORT_INTERVAL)
    end
end

-- ======================
-- NETWORK LOOP
-- ======================
local function networkLoop()
    while true do
        local senderId, msg, protocol = rednet.receive(PROTOCOL)

        if type(msg) == "table" then
            -- Handle system commands (broadcast to all)
            if msg.type == "system" and msg.command == "UPDATE" then
                print("Update command received!")
                redstone.setOutput(LAMP_SIDE, false)  -- Safety: turn off light
                sleep(1)
                shell.run("update", "silent")
                return  -- Exit loop (update will reboot)
            end

            -- Handle light-specific commands
            if msg.id == LIGHT_ID then
                -- Remember central's ID
                centralId = senderId

                if msg.command == "ENABLE" then
                    lightEnabled = true
                elseif msg.command == "DISABLE" then
                    lightEnabled = false
                    -- Immediately turn off when disabled
                    redstone.setOutput(LAMP_SIDE, false)
                end
            end
        end
    end
end

-- ======================
-- DISPLAY STATUS
-- ======================
local function displayLoop()
    while true do
        term.clear()
        term.setCursorPos(1, 1)

        print("=== " .. LIGHT_ID .. " ===")
        print("")
        print("Modem: " .. modemSide)
        print("Button: " .. BUTTON_SIDE)
        print("Lamp: " .. LAMP_SIDE)
        print("")

        if centralId then
            print("Central: Connected (#" .. centralId .. ")")
        else
            print("Central: Searching...")
        end

        print("")
        print("Button: " .. (lightRequest and "PRESSED" or "released"))
        print("Enabled: " .. (lightEnabled and "YES" or "NO"))
        print("Light: " .. (redstone.getOutput(LAMP_SIDE) and "ON" or "OFF"))

        sleep(0.5)
    end
end

-- ======================
-- RUN EVERYTHING
-- ======================
print("Starting " .. LIGHT_ID .. "...")
findCentral()

parallel.waitForAll(
    lightLoop,
    networkLoop,
    displayLoop
)

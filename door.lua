-- ======================
-- FNAF DOOR CONTROLLER
-- ======================
-- Place on a computer with:
--   - Ender modem (any side)
--   - Redstone input from button (configurable side)
--   - Redstone output to door/piston (configurable side)

-- ======================
-- CONFIG - CHANGE THESE!
-- ======================
local DOOR_ID = "LEFT_DOOR"    -- Change to "RIGHT_DOOR" for other door
local BUTTON_SIDE = "right"    -- Side where button input comes from
local DOOR_SIDE = "left"       -- Side where door output goes

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
local doorRequest = false   -- Is button being pressed?
local doorEnabled = false   -- Is central allowing door to close?
local centralId = nil       -- Computer ID of central controller

-- Ensure door starts OPEN
redstone.setOutput(DOOR_SIDE, false)

-- ======================
-- FIND CENTRAL
-- ======================
local function findCentral()
    -- Broadcast looking for central
    rednet.broadcast({
        id = DOOR_ID,
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
        id = DOOR_ID,
        requesting = doorRequest,
        active = redstone.getOutput(DOOR_SIDE)
    }

    if centralId then
        rednet.send(centralId, msg, PROTOCOL)
    else
        -- Broadcast until we know central's ID
        rednet.broadcast(msg, PROTOCOL)
    end
end

-- ======================
-- DOOR CONTROL LOOP
-- ======================
local function doorLoop()
    while true do
        -- Check if button is pressed
        doorRequest = redstone.getInput(BUTTON_SIDE)

        -- Only close door if requested AND enabled by central
        if doorRequest and doorEnabled then
            redstone.setOutput(DOOR_SIDE, true)
        else
            redstone.setOutput(DOOR_SIDE, false)
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
                redstone.setOutput(DOOR_SIDE, false)  -- Safety: open door
                sleep(1)
                shell.run("update", "silent")
                return  -- Exit loop (update will reboot)
            end

            -- Handle door-specific commands
            if msg.id == DOOR_ID then
                -- Remember central's ID
                centralId = senderId

                if msg.command == "ENABLE" then
                    doorEnabled = true
                elseif msg.command == "DISABLE" then
                    doorEnabled = false
                    -- Immediately open door when disabled
                    redstone.setOutput(DOOR_SIDE, false)
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

        print("=== " .. DOOR_ID .. " ===")
        print("")
        print("Modem: " .. modemSide)
        print("Button: " .. BUTTON_SIDE)
        print("Output: " .. DOOR_SIDE)
        print("")

        if centralId then
            print("Central: Connected (#" .. centralId .. ")")
        else
            print("Central: Searching...")
        end

        print("")
        print("Button: " .. (doorRequest and "PRESSED" or "released"))
        print("Enabled: " .. (doorEnabled and "YES" or "NO"))
        print("Door: " .. (redstone.getOutput(DOOR_SIDE) and "CLOSED" or "OPEN"))

        sleep(0.5)
    end
end

-- ======================
-- RUN EVERYTHING
-- ======================
print("Starting " .. DOOR_ID .. "...")
findCentral()

parallel.waitForAll(
    doorLoop,
    networkLoop,
    displayLoop
)

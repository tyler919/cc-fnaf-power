-- ======================
-- FNAF GENERATOR ROOM
-- ======================
-- Powah Battery Recharge Station
-- Place battery in drawer, select power amount, wait

-- ======================
-- CONFIG
-- ======================
local PROTOCOL = "FNAF_POWER"

-- Peripheral sides
local DRAWER_SIDE = "back"         -- Where the drawer is
local HOPPER_SIDE = "front"        -- Redstone output to lock/unlock hopper

-- Battery detection
-- Set to nil to accept ANY item (useful for testing)
-- Once you know the ID, set it here (e.g., "powah:battery_hardened")
local BATTERY_ID = nil

-- Timing (based on 10K FE/tick, 10M total = 50 seconds for 100%)
local TIME_PER_10_PERCENT = 5      -- Seconds per 10% power

-- Debug mode - prints item IDs found in drawer
local DEBUG_MODE = true

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

-- Find drawer
local drawer = peripheral.wrap(DRAWER_SIDE)
if not drawer then
    print("WARNING: No drawer found on " .. DRAWER_SIDE)
    print("Searching for any inventory...")
    drawer = peripheral.find("inventory")
end

if not drawer then
    error("No drawer/inventory found!")
end

-- Find monitor
local monitor = peripheral.find("monitor")
if not monitor then
    error("No monitor found!")
end
monitor.setTextScale(0.5)

-- ======================
-- STATE
-- ======================
local centralId = nil
local state = "waiting"  -- waiting, startup, selecting, charging, done

-- Lock hopper by default (redstone ON = hopper locked)
redstone.setOutput(HOPPER_SIDE, true)

-- ======================
-- HELPER FUNCTIONS
-- ======================

-- Check if battery is in drawer
local function checkForBattery()
    local items = drawer.list()

    for slot, item in pairs(items) do
        if DEBUG_MODE then
            print("DEBUG: Found item: " .. item.name)
        end

        -- If no specific battery ID set, accept any item
        if BATTERY_ID == nil then
            return true, item.name
        end

        -- Check for specific battery
        if item.name == BATTERY_ID then
            return true, item.name
        end
    end

    return false, nil
end

-- Send power to central
local function sendPower(amount, fullRestore)
    local msg = {
        id = "GENERATOR",
        deviceType = "generator",
        type = "refuel",
        amount = amount,
        fullRestore = fullRestore or false
    }

    if centralId then
        rednet.send(centralId, msg, PROTOCOL)
    else
        rednet.broadcast(msg, PROTOCOL)
    end
end

-- ======================
-- MONITOR DISPLAY
-- ======================

local function clearMonitor()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
end

local function centerText(y, text, color)
    local w, h = monitor.getSize()
    local x = math.floor((w - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    if color then monitor.setTextColor(color) end
    monitor.write(text)
end

-- Waiting screen
local function drawWaiting()
    clearMonitor()
    local w, h = monitor.getSize()

    centerText(math.floor(h/2) - 1, "=== GENERATOR ===", colors.white)
    centerText(math.floor(h/2) + 1, "Insert Battery", colors.gray)
    centerText(math.floor(h/2) + 2, "to begin", colors.gray)
end

-- Startup animation
local function drawStartup()
    clearMonitor()
    local w, h = monitor.getSize()

    -- Animation frames
    local frames = {
        "Detecting...",
        "Battery Found!",
        "Initializing...",
        "Systems Online",
        "Ready!"
    }

    for i, frame in ipairs(frames) do
        clearMonitor()
        centerText(math.floor(h/2), frame, colors.yellow)
        sleep(0.5)
    end
end

-- Selection menu (10 options)
local function drawSelection(selected)
    clearMonitor()
    local w, h = monitor.getSize()

    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.white)
    monitor.write("SELECT POWER LEVEL")

    monitor.setCursorPos(1, 2)
    monitor.setTextColor(colors.gray)
    monitor.write("Use UP/DOWN, ENTER")

    local options = {10, 20, 30, 40, 50, 60, 70, 80, 90, 100}
    local startY = 4

    for i, pct in ipairs(options) do
        monitor.setCursorPos(2, startY + i - 1)

        if i == selected then
            monitor.setBackgroundColor(colors.blue)
            monitor.setTextColor(colors.white)
        else
            monitor.setBackgroundColor(colors.black)
            monitor.setTextColor(colors.lightGray)
        end

        local timeNeeded = (pct / 10) * TIME_PER_10_PERCENT
        local label = string.format(" %3d%% (%ds) ", pct, timeNeeded)
        monitor.write(label)
    end

    monitor.setBackgroundColor(colors.black)
end

-- Charging progress
local function drawCharging(percent, timeLeft)
    clearMonitor()
    local w, h = monitor.getSize()

    centerText(2, "CHARGING...", colors.yellow)

    -- Progress bar
    local barWidth = w - 4
    local filled = math.floor((percent / 100) * barWidth)

    monitor.setCursorPos(2, math.floor(h/2))
    monitor.setTextColor(colors.white)
    monitor.write("[")
    monitor.setTextColor(colors.lime)
    monitor.write(string.rep("#", filled))
    monitor.setTextColor(colors.gray)
    monitor.write(string.rep("-", barWidth - filled))
    monitor.setTextColor(colors.white)
    monitor.write("]")

    centerText(math.floor(h/2) + 2, percent .. "%", colors.lime)
    centerText(math.floor(h/2) + 4, timeLeft .. "s remaining", colors.gray)
end

-- Done screen
local function drawDone(amount)
    clearMonitor()
    local w, h = monitor.getSize()

    centerText(math.floor(h/2) - 1, "COMPLETE!", colors.lime)
    centerText(math.floor(h/2) + 1, "+" .. amount .. " Power", colors.yellow)
    centerText(math.floor(h/2) + 3, "Remove battery", colors.gray)
end

-- ======================
-- NETWORK LOOP
-- ======================
local function networkLoop()
    while true do
        local senderId, msg, protocol = rednet.receive(PROTOCOL)

        if type(msg) == "table" then
            -- Handle system commands
            if msg.type == "system" and msg.command == "UPDATE" then
                print("Update command received!")
                sleep(1)
                shell.run("update", "silent")
                return
            end

            -- Remember central's ID
            if msg.type == "ack" or msg.command then
                centralId = senderId
            end
        end
    end
end

-- ======================
-- MAIN LOGIC
-- ======================
local function mainLoop()
    local selected = 1

    while true do
        if state == "waiting" then
            drawWaiting()

            -- Check for battery
            local found, itemName = checkForBattery()
            if found then
                print("Battery detected: " .. (itemName or "unknown"))
                state = "startup"
            end

            sleep(0.5)

        elseif state == "startup" then
            drawStartup()
            state = "selecting"
            selected = 1

        elseif state == "selecting" then
            drawSelection(selected)

            -- Wait for input
            local event, key = os.pullEvent("key")

            if key == keys.up and selected > 1 then
                selected = selected - 1
            elseif key == keys.down and selected < 10 then
                selected = selected + 1
            elseif key == keys.enter then
                state = "charging"
            end

        elseif state == "charging" then
            local targetPercent = selected * 10
            local totalTime = (targetPercent / 10) * TIME_PER_10_PERCENT

            -- Unlock hopper to let battery drop
            redstone.setOutput(HOPPER_SIDE, false)

            -- Charging animation
            for t = 1, totalTime do
                local progress = math.floor((t / totalTime) * 100)
                local timeLeft = totalTime - t
                drawCharging(progress, timeLeft)
                sleep(1)
            end

            -- Lock hopper again
            redstone.setOutput(HOPPER_SIDE, true)

            -- Send power to central
            local isFullRestore = (targetPercent == 100)
            sendPower(targetPercent, isFullRestore)

            state = "done"

        elseif state == "done" then
            drawDone(selected * 10)

            -- Wait for battery to be removed
            sleep(1)
            local found, _ = checkForBattery()
            if not found then
                state = "waiting"
            end
        end
    end
end

-- ======================
-- RUN
-- ======================
print("=== FNAF GENERATOR ===")
print("Drawer: " .. DRAWER_SIDE)
print("Hopper: " .. HOPPER_SIDE)
print("Debug: " .. tostring(DEBUG_MODE))
print("")
print("Waiting for battery...")

-- Lock hopper initially
redstone.setOutput(HOPPER_SIDE, true)

parallel.waitForAny(
    mainLoop,
    networkLoop
)

-- ======================
-- FNAF GENERATOR ROOM
-- ======================
-- Powah Battery Recharge Station
-- Place battery in drawer, select power amount, wait
-- Features breaker warning system

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

-- Timing - Choose based on your Energy Cell discharge rate:
-- 1K/tick  = 50 seconds per 10%  (500 sec / ~8 min for 100%)
-- 4K/tick  = 12.5 seconds per 10% (125 sec / ~2 min for 100%)
-- 10K/tick = 5 seconds per 10%   (50 sec for 100%)
local DISCHARGE_RATE = "10K"  -- Change to "1K", "4K", or "10K"

local TIMING = {
    ["1K"]  = 50,
    ["4K"]  = 12.5,
    ["10K"] = 5,
}
local TIME_PER_10_PERCENT = TIMING[DISCHARGE_RATE] or 5

-- Breaker warning settings
local BREAKER_WARNING_TIME = 150   -- 2.5 minutes (150 seconds) to reset
local BREAKER_FIRST_WARNING = 60   -- First warning appears after 60 seconds
local BREAKER_BREAK_CHANCE = 0.5   -- 50% chance to break if ignored

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
local state = "waiting"  -- waiting, startup, selecting, charging, done, broken

-- Breaker warning state
local breakerWarning = false
local breakerTimer = 0
local breakerFlash = false
local generatorBroken = false
local timeSinceLastWarning = 0

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

-- Notify central that generator is broken
local function sendBroken()
    local msg = {
        id = "GENERATOR",
        deviceType = "generator",
        type = "broken"
    }
    rednet.broadcast(msg, PROTOCOL)
end

-- Reset breaker warning
local function resetBreaker()
    breakerWarning = false
    breakerTimer = 0
    timeSinceLastWarning = 0
    print("Breaker reset!")
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

-- Draw breaker warning icon (flashing)
local WARNING_X = 1
local WARNING_Y = 1
local WARNING_W = 5
local WARNING_H = 3

local function drawBreakerWarning()
    if not breakerWarning then return end

    local w, h = monitor.getSize()

    -- Position in top-right corner
    local wx = w - WARNING_W
    local wy = 1

    -- Flash between red and yellow
    if breakerFlash then
        monitor.setBackgroundColor(colors.red)
        monitor.setTextColor(colors.yellow)
    else
        monitor.setBackgroundColor(colors.yellow)
        monitor.setTextColor(colors.red)
    end

    -- Draw warning box
    for row = 0, WARNING_H - 1 do
        monitor.setCursorPos(wx, wy + row)
        monitor.write(string.rep(" ", WARNING_W))
    end

    -- Draw warning symbol
    monitor.setCursorPos(wx + 1, wy + 1)
    monitor.write("!!")

    -- Show time remaining
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.red)
    monitor.setCursorPos(wx, wy + WARNING_H)
    local timeLeft = BREAKER_WARNING_TIME - breakerTimer
    monitor.write(string.format("%ds", math.max(0, timeLeft)))
end

-- Check if warning was tapped
local function isWarningTapped(x, y)
    if not breakerWarning then return false end

    local w, h = monitor.getSize()
    local wx = w - WARNING_W
    local wy = 1

    return x >= wx and x < wx + WARNING_W and y >= wy and y < wy + WARNING_H
end

-- Waiting screen
local function drawWaiting()
    clearMonitor()
    local w, h = monitor.getSize()

    if generatorBroken then
        centerText(math.floor(h/2) - 1, "=== GENERATOR ===", colors.red)
        centerText(math.floor(h/2) + 1, "OFFLINE", colors.red)
        centerText(math.floor(h/2) + 3, "System Failure", colors.gray)
    else
        centerText(math.floor(h/2) - 1, "=== GENERATOR ===", colors.white)
        centerText(math.floor(h/2) + 1, "Insert Battery", colors.gray)
        centerText(math.floor(h/2) + 2, "to begin", colors.gray)
    end

    drawBreakerWarning()
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
        drawBreakerWarning()
        sleep(0.5)
    end
end

-- Selection menu (10 options) - TOUCH BASED
local MENU_START_Y = 4  -- Where menu options start

local function drawSelection()
    clearMonitor()
    local w, h = monitor.getSize()

    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.white)
    monitor.write("SELECT POWER LEVEL")

    monitor.setCursorPos(1, 2)
    monitor.setTextColor(colors.gray)
    monitor.write("Tap to select")

    local options = {10, 20, 30, 40, 50, 60, 70, 80, 90, 100}

    for i, pct in ipairs(options) do
        monitor.setCursorPos(1, MENU_START_Y + i - 1)
        monitor.setBackgroundColor(colors.gray)
        monitor.setTextColor(colors.white)

        local timeNeeded = (pct / 10) * TIME_PER_10_PERCENT
        local label = string.format(" %3d%% - %ds ", pct, timeNeeded)

        -- Pad to fill width for easier tapping (leave room for warning)
        local padding = w - #label - WARNING_W - 1
        if padding > 0 then
            label = label .. string.rep(" ", padding)
        end

        monitor.write(label)
    end

    monitor.setBackgroundColor(colors.black)
    drawBreakerWarning()
end

-- Get which option was tapped (returns 1-10, or nil if invalid)
local function getOptionFromTouch(y)
    local option = y - MENU_START_Y + 1
    if option >= 1 and option <= 10 then
        return option
    end
    return nil
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

    drawBreakerWarning()
end

-- Done screen
local function drawDone(amount)
    clearMonitor()
    local w, h = monitor.getSize()

    centerText(math.floor(h/2) - 1, "COMPLETE!", colors.lime)
    centerText(math.floor(h/2) + 1, "+" .. amount .. " Power", colors.yellow)
    centerText(math.floor(h/2) + 3, "Remove battery", colors.gray)

    drawBreakerWarning()
end

-- ======================
-- BREAKER WARNING LOOP
-- ======================
local function breakerLoop()
    while true do
        sleep(1)

        if generatorBroken then
            -- Generator is broken, no more warnings needed
            breakerWarning = false
        elseif breakerWarning then
            -- Warning is active, count down
            breakerTimer = breakerTimer + 1
            breakerFlash = not breakerFlash  -- Toggle flash

            -- Check if time ran out
            if breakerTimer >= BREAKER_WARNING_TIME then
                -- Roll for generator failure
                if math.random() < BREAKER_BREAK_CHANCE then
                    generatorBroken = true
                    breakerWarning = false
                    print("GENERATOR BROKEN! Breaker was not reset in time.")
                    sendBroken()
                else
                    -- Lucky! Reset the warning
                    print("Breaker auto-reset (lucky!)")
                    resetBreaker()
                    timeSinceLastWarning = 0
                end
            end
        else
            -- No warning active, count time until next warning
            timeSinceLastWarning = timeSinceLastWarning + 1

            if timeSinceLastWarning >= BREAKER_FIRST_WARNING then
                -- Random chance to trigger warning each second after first warning time
                if math.random() < 0.1 then  -- 10% chance per second
                    breakerWarning = true
                    breakerTimer = 0
                    print("BREAKER WARNING! Tap to reset!")
                end
            end
        end
    end
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

            -- If generator broken, just wait (can't do anything)
            if generatorBroken then
                -- Check for touch to reset breaker warning (still works even when broken)
                local timer = os.startTimer(0.5)
                local event, p1, p2, p3 = os.pullEvent()

                if event == "monitor_touch" and breakerWarning then
                    if isWarningTapped(p2, p3) then
                        resetBreaker()
                    end
                end
            else
                -- Check for battery
                local found, itemName = checkForBattery()
                if found then
                    print("Battery detected: " .. (itemName or "unknown"))
                    state = "startup"
                else
                    -- Check for touch on breaker warning
                    local timer = os.startTimer(0.5)
                    local event, p1, p2, p3 = os.pullEvent()

                    if event == "monitor_touch" and breakerWarning then
                        if isWarningTapped(p2, p3) then
                            resetBreaker()
                        end
                    end
                end
            end

        elseif state == "startup" then
            drawStartup()
            state = "selecting"
            selected = 1

        elseif state == "selecting" then
            drawSelection()

            -- Wait for touch input on monitor
            local event, side, x, y = os.pullEvent("monitor_touch")

            -- Check if breaker warning was tapped
            if breakerWarning and isWarningTapped(x, y) then
                resetBreaker()
            else
                local option = getOptionFromTouch(y)
                if option then
                    selected = option
                    state = "charging"
                end
            end

        elseif state == "charging" then
            local targetPercent = selected * 10
            local totalTime = math.floor((targetPercent / 10) * TIME_PER_10_PERCENT)

            -- Unlock hopper to let battery drop
            redstone.setOutput(HOPPER_SIDE, false)

            -- Charging animation with breaker check
            for t = 1, totalTime do
                local progress = math.floor((t / totalTime) * 100)
                local timeLeft = totalTime - t
                drawCharging(progress, timeLeft)

                -- Check for touch during charging (for breaker reset)
                local timer = os.startTimer(1)
                local event, p1, p2, p3 = os.pullEvent()

                if event == "monitor_touch" and breakerWarning then
                    if isWarningTapped(p2, p3) then
                        resetBreaker()
                    end
                end
            end

            -- Lock hopper again
            redstone.setOutput(HOPPER_SIDE, true)

            -- Send power to central
            local isFullRestore = (targetPercent == 100)
            sendPower(targetPercent, isFullRestore)

            state = "done"

        elseif state == "done" then
            drawDone(selected * 10)

            -- Wait for battery to be removed (also check for breaker tap)
            local timer = os.startTimer(1)
            local event, p1, p2, p3 = os.pullEvent()

            if event == "monitor_touch" and breakerWarning then
                if isWarningTapped(p2, p3) then
                    resetBreaker()
                end
            end

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
print("Breaker warning time: " .. BREAKER_WARNING_TIME .. "s")
print("")
print("Waiting for battery...")

-- Lock hopper initially
redstone.setOutput(HOPPER_SIDE, true)

parallel.waitForAny(
    mainLoop,
    networkLoop,
    breakerLoop
)

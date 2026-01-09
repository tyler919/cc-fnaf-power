-- ======================
-- FNAF POWER CENTRAL CONTROLLER
-- ======================
-- Place on a computer with:
--   - Ender modem (any side)
--   - Monitor (any side)

local PROTOCOL = "FNAF_POWER"
local MAX_POWER = 100
local BASE_DRAIN = 0.02        -- Drain per second (idle)
local DOOR_DRAIN = 0.15        -- Extra drain per active door
local LIGHT_DRAIN = 0.10       -- Extra drain per active light

local TIMEOUT = 2              -- Seconds before device marked offline

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

-- Find monitor
local monitor = peripheral.find("monitor")
if not monitor then
    error("No monitor found!")
end
monitor.setTextScale(0.5)

-- ======================
-- STATE
-- ======================
local power = MAX_POWER
local gameOver = false
local generatorOnline = false
local generatorLastSeen = 0
local lastRefuelTime = 0

-- deviceStates[id] = {
--   type = "door" or "light",
--   requesting = bool,  -- Button pressed?
--   active = bool,      -- Actually on/closed?
--   lastSeen = number,  -- os.clock() timestamp
--   online = bool,
--   computerId = number
-- }
local deviceStates = {}

-- ======================
-- NETWORK HANDLER
-- ======================
local function networkLoop()
    while true do
        local senderId, msg, protocol = rednet.receive(PROTOCOL)

        if type(msg) == "table" and msg.id then
            -- Handle generator refuel messages
            if msg.deviceType == "generator" then
                generatorLastSeen = os.clock()
                generatorOnline = true

                if msg.type == "refuel" and msg.amount then
                    -- Add power from generator (cap at max)
                    local oldPower = power
                    power = math.min(MAX_POWER, power + msg.amount)
                    lastRefuelTime = os.clock()

                    -- Send acknowledgment
                    rednet.send(senderId, {
                        type = "ack",
                        received = msg.amount,
                        newPower = power
                    }, PROTOCOL)
                end
            else
                -- Handle door/light devices
                if not deviceStates[msg.id] then
                    deviceStates[msg.id] = {
                        type = msg.deviceType or "door",
                        requesting = false,
                        active = false,
                        lastSeen = 0,
                        online = false
                    }
                end

                local d = deviceStates[msg.id]
                d.type = msg.deviceType or d.type or "door"
                d.requesting = msg.requesting or false
                d.active = msg.active or false
                d.lastSeen = os.clock()
                d.computerId = senderId
            end
        end
    end
end

-- ======================
-- POWER + DECISION LOGIC
-- ======================
local function controlLoop()
    while true do
        local now = os.clock()
        local activeDoors = 0
        local activeLights = 0

        -- Check generator online status
        if generatorLastSeen > 0 and (now - generatorLastSeen) > TIMEOUT then
            generatorOnline = false
        end

        for id, d in pairs(deviceStates) do
            -- Check if device is still online
            if not d.lastSeen or (now - d.lastSeen) > TIMEOUT then
                d.online = false
                if d.computerId then
                    rednet.send(d.computerId, {
                        id = id,
                        command = "DISABLE"
                    }, PROTOCOL)
                end
            else
                d.online = true

                -- Device wants to activate and we have power
                if d.requesting and power > 0 and not gameOver then
                    if d.computerId then
                        rednet.send(d.computerId, {
                            id = id,
                            command = "ENABLE"
                        }, PROTOCOL)
                    end
                    -- Count by type
                    if d.type == "light" then
                        activeLights = activeLights + 1
                    else
                        activeDoors = activeDoors + 1
                    end
                else
                    if d.computerId then
                        rednet.send(d.computerId, {
                            id = id,
                            command = "DISABLE"
                        }, PROTOCOL)
                    end
                end
            end
        end

        -- Power drain
        if power > 0 and not gameOver then
            local drain = BASE_DRAIN + (activeDoors * DOOR_DRAIN) + (activeLights * LIGHT_DRAIN)
            power = math.max(0, power - drain)
        end

        -- Power out - game over!
        if power <= 0 and not gameOver then
            gameOver = true
            -- Force everything off
            for id, d in pairs(deviceStates) do
                if d.computerId then
                    rednet.send(d.computerId, {
                        id = id,
                        command = "DISABLE"
                    }, PROTOCOL)
                end
            end
        end

        sleep(1)
    end
end

-- ======================
-- MONITOR UI
-- ======================
local function drawMonitor()
    local mw, mh = monitor.getSize()

    while true do
        monitor.setBackgroundColor(colors.black)
        monitor.clear()

        if gameOver then
            -- Game over screen
            monitor.setTextColor(colors.red)
            monitor.setCursorPos(2, math.floor(mh/2))
            monitor.write("POWER OUT")
            monitor.setCursorPos(2, math.floor(mh/2) + 2)
            monitor.setTextColor(colors.gray)
            monitor.write("Press R to restart")
        else
            -- Power display
            monitor.setTextColor(colors.white)
            monitor.setCursorPos(1, 1)
            monitor.write("=== POWER ===")

            -- Power percentage
            local percent = math.floor((power / MAX_POWER) * 100)
            monitor.setCursorPos(1, 3)

            if percent > 50 then
                monitor.setTextColor(colors.lime)
            elseif percent > 25 then
                monitor.setTextColor(colors.yellow)
            elseif percent > 10 then
                monitor.setTextColor(colors.orange)
            else
                monitor.setTextColor(colors.red)
            end

            monitor.write(string.format("%d%%", percent))

            -- Power bar
            monitor.setCursorPos(1, 4)
            local barWidth = mw - 2
            local filled = math.floor((power / MAX_POWER) * barWidth)
            monitor.write("[")
            monitor.write(string.rep("#", filled))
            monitor.write(string.rep("-", barWidth - filled))
            monitor.write("]")

            -- Usage indicator
            monitor.setCursorPos(1, 6)
            monitor.setTextColor(colors.gray)
            local activeDoors = 0
            local activeLights = 0
            for _, d in pairs(deviceStates) do
                if d.online and d.active then
                    if d.type == "light" then
                        activeLights = activeLights + 1
                    else
                        activeDoors = activeDoors + 1
                    end
                end
            end
            local usageBars = 1 + activeDoors + activeLights
            monitor.write("USAGE: " .. string.rep("|", usageBars))

            -- Door status
            local y = 8
            monitor.setCursorPos(1, y)
            monitor.setTextColor(colors.white)
            monitor.write("=== DOORS ===")
            y = y + 1

            local hasDoors = false
            for id, d in pairs(deviceStates) do
                if d.type == "door" then
                    hasDoors = true
                    monitor.setCursorPos(1, y)

                    if not d.online then
                        monitor.setTextColor(colors.gray)
                        monitor.write("[X] " .. id)
                    elseif d.active then
                        monitor.setTextColor(colors.red)
                        monitor.write("[#] " .. id)
                    else
                        monitor.setTextColor(colors.lime)
                        monitor.write("[ ] " .. id)
                    end
                    y = y + 1
                end
            end

            if not hasDoors then
                monitor.setCursorPos(1, y)
                monitor.setTextColor(colors.gray)
                monitor.write("No doors...")
                y = y + 1
            end

            -- Light status
            y = y + 1
            monitor.setCursorPos(1, y)
            monitor.setTextColor(colors.white)
            monitor.write("=== LIGHTS ===")
            y = y + 1

            local hasLights = false
            for id, d in pairs(deviceStates) do
                if d.type == "light" then
                    hasLights = true
                    monitor.setCursorPos(1, y)

                    if not d.online then
                        monitor.setTextColor(colors.gray)
                        monitor.write("[X] " .. id)
                    elseif d.active then
                        monitor.setTextColor(colors.yellow)
                        monitor.write("[*] " .. id)
                    else
                        monitor.setTextColor(colors.gray)
                        monitor.write("[ ] " .. id)
                    end
                    y = y + 1
                end
            end

            if not hasLights then
                monitor.setCursorPos(1, y)
                monitor.setTextColor(colors.gray)
                monitor.write("No lights...")
                y = y + 1
            end

            -- Generator status
            y = y + 1
            monitor.setCursorPos(1, y)
            monitor.setTextColor(colors.white)
            monitor.write("=== GENERATOR ===")
            y = y + 1

            monitor.setCursorPos(1, y)
            if generatorOnline then
                monitor.setTextColor(colors.lime)
                monitor.write("[+] ONLINE")

                -- Show if recently refueled
                if os.clock() - lastRefuelTime < 3 then
                    monitor.setTextColor(colors.yellow)
                    monitor.write(" +POWER!")
                end
            else
                monitor.setTextColor(colors.gray)
                monitor.write("[X] OFFLINE")
            end
        end

        sleep(0.2)
    end
end

-- ======================
-- BROADCAST UPDATE TO ALL DEVICES
-- ======================
local function broadcastUpdate()
    print("Broadcasting update command...")

    -- Broadcast to all devices on protocol
    rednet.broadcast({
        type = "system",
        command = "UPDATE"
    }, PROTOCOL)

    print("Update command sent!")
    print("All devices will update and reboot.")
    sleep(2)

    -- Update self last
    print("Updating central controller...")
    shell.run("update", "silent")
end

-- ======================
-- INPUT HANDLER
-- ======================
local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")

        if key == keys.r and gameOver then
            -- Reset game
            power = MAX_POWER
            gameOver = false
        elseif key == keys.u then
            -- Broadcast update to all devices
            broadcastUpdate()
        elseif key == keys.q then
            -- Quit
            print("Shutting down...")
            sleep(1)
            os.shutdown()
        end
    end
end

-- ======================
-- RUN EVERYTHING
-- ======================
print("FNAF Power Controller Started")
print("Modem on: " .. modemSide)
print("Protocol: " .. PROTOCOL)
print("")
print("Keys:")
print("  R - Restart (when game over)")
print("  U - Update all devices")
print("  Q - Quit")
print("")

parallel.waitForAll(
    networkLoop,
    controlLoop,
    drawMonitor,
    inputLoop
)

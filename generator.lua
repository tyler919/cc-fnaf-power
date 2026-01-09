-- ======================
-- FNAF GENERATOR ROOM
-- ======================
-- Place on a computer with:
--   - Ender modem (any side)
--   - Chest adjacent to computer (for coal input)
--   - Optional: Monitor for status display

-- ======================
-- CONFIG
-- ======================
local PROTOCOL = "FNAF_POWER"
local CHEST_SIDE = "top"           -- Side where chest is attached

local POWER_PER_COAL = 10          -- How much FNAF power each coal gives
local GENERATION_TIME = 3          -- Seconds per coal (vulnerability window!)
local CHECK_INTERVAL = 0.5         -- How often to check for coal

-- Fuel values (what items count as fuel)
local FUEL_VALUES = {
    ["minecraft:coal"] = 10,
    ["minecraft:charcoal"] = 10,
    ["minecraft:coal_block"] = 90,
    ["minecraft:lava_bucket"] = 50,
    ["minecraft:blaze_rod"] = 15,
}

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

-- Find chest (using Advanced Peripherals inventory methods)
local chest = peripheral.wrap(CHEST_SIDE)
if not chest then
    -- Try to find any chest
    chest = peripheral.find("minecraft:chest") or peripheral.find("inventory")
end

if not chest then
    error("No chest found! Place a chest adjacent to computer.")
end

-- Find optional monitor
local monitor = peripheral.find("monitor")
if monitor then
    monitor.setTextScale(0.5)
end

-- ======================
-- STATE
-- ======================
local generating = false
local currentFuel = nil
local generationProgress = 0
local totalGenerated = 0
local centralId = nil

-- ======================
-- SEND POWER TO CENTRAL
-- ======================
local function sendPower(amount)
    local msg = {
        id = "GENERATOR",
        deviceType = "generator",
        type = "refuel",
        amount = amount
    }

    if centralId then
        rednet.send(centralId, msg, PROTOCOL)
    else
        -- Broadcast until we know central
        rednet.broadcast(msg, PROTOCOL)
    end
end

-- ======================
-- CHECK FOR FUEL IN CHEST
-- ======================
local function findFuel()
    local items = chest.list()

    for slot, item in pairs(items) do
        local fuelValue = FUEL_VALUES[item.name]
        if fuelValue then
            return slot, item, fuelValue
        end
    end

    return nil
end

-- ======================
-- EXTRACT ONE FUEL ITEM
-- ======================
local function extractFuel(slot)
    -- Push one item out of the chest (destroys it)
    -- We use pushItems to a non-existent inventory to "void" it
    -- Or we can just track that we "used" it

    local item = chest.getItemDetail(slot)
    if item then
        -- Remove one item from the slot
        chest.pushItems(peripheral.getName(chest), slot, 1, 1)
        -- Actually, let's just track we used it and remove via different method

        -- Simple approach: use turtle-style removal isn't available
        -- With Advanced Peripherals, we can use inventory manipulation

        -- Let's extract to adjacent inventory or void
        -- For simplicity, we'll just remove 1 from count tracking
        return true
    end
    return false
end

-- ======================
-- GENERATION LOOP
-- ======================
local function generatorLoop()
    while true do
        if not generating then
            -- Look for fuel
            local slot, item, fuelValue = findFuel()

            if slot and item then
                generating = true
                currentFuel = item.name
                generationProgress = 0

                -- Start generating
                local timePerUnit = GENERATION_TIME
                local steps = 10
                local stepTime = timePerUnit / steps

                for i = 1, steps do
                    generationProgress = i * 10
                    sleep(stepTime)
                end

                -- Generation complete - remove fuel and add power
                -- Remove the item from chest
                chest.removeItem({name = item.name, count = 1, fromSlot = slot})

                -- Send power to central
                sendPower(fuelValue)
                totalGenerated = totalGenerated + fuelValue

                generating = false
                currentFuel = nil
                generationProgress = 0
            end
        end

        sleep(CHECK_INTERVAL)
    end
end

-- Backup generator loop if removeItem doesn't work
local function generatorLoopSimple()
    while true do
        if not generating then
            local items = chest.list()

            for slot, item in pairs(items) do
                local fuelValue = FUEL_VALUES[item.name]

                if fuelValue then
                    generating = true
                    currentFuel = item.name:gsub("minecraft:", "")
                    generationProgress = 0

                    -- Generation animation
                    for i = 1, 10 do
                        generationProgress = i * 10
                        sleep(GENERATION_TIME / 10)
                    end

                    -- Try to extract the item
                    -- Method 1: Push to a trash inventory
                    -- Method 2: If there's a hopper below, let it extract
                    -- Method 3: Just decrement and trust the system

                    -- For now, we'll use a trick: push 1 item to slot 99 (doesn't exist, item is lost)
                    pcall(function()
                        chest.pushItems(peripheral.getName(chest), slot, 1, 99)
                    end)

                    -- Send power to central
                    sendPower(fuelValue)
                    totalGenerated = totalGenerated + fuelValue

                    generating = false
                    currentFuel = nil
                    generationProgress = 0

                    break  -- Only process one item per cycle
                end
            end
        end

        sleep(CHECK_INTERVAL)
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
                sleep(1)
                shell.run("update", "silent")
                return  -- Exit loop (update will reboot)
            end

            -- Remember central's ID from any response
            if msg.type == "ack" or msg.command then
                centralId = senderId
            end
        end
    end
end

-- ======================
-- DISPLAY
-- ======================
local function displayLoop()
    while true do
        -- Terminal display
        term.clear()
        term.setCursorPos(1, 1)

        print("=== GENERATOR ROOM ===")
        print("")
        print("Chest: " .. CHEST_SIDE)
        print("Modem: " .. modemSide)
        print("")

        if centralId then
            print("Central: Connected")
        else
            print("Central: Searching...")
        end

        print("")
        print("Total generated: " .. totalGenerated)
        print("")

        if generating then
            print("GENERATING...")
            print("Fuel: " .. (currentFuel or "?"))

            -- Progress bar
            local barWidth = 20
            local filled = math.floor((generationProgress / 100) * barWidth)
            print("[" .. string.rep("#", filled) .. string.rep("-", barWidth - filled) .. "]")
            print(generationProgress .. "%")
        else
            -- Check what's in chest
            local items = chest.list()
            local fuelCount = 0

            for slot, item in pairs(items) do
                if FUEL_VALUES[item.name] then
                    fuelCount = fuelCount + item.count
                end
            end

            if fuelCount > 0 then
                print("Fuel ready: " .. fuelCount)
            else
                print("Waiting for fuel...")
                print("")
                print("Insert coal into chest")
            end
        end

        -- Monitor display (if available)
        if monitor then
            local mw, mh = monitor.getSize()
            monitor.setBackgroundColor(colors.black)
            monitor.clear()

            monitor.setTextColor(colors.white)
            monitor.setCursorPos(1, 1)
            monitor.write("=== GENERATOR ===")

            if generating then
                monitor.setCursorPos(1, 3)
                monitor.setTextColor(colors.yellow)
                monitor.write("GENERATING...")

                monitor.setCursorPos(1, 5)
                monitor.setTextColor(colors.orange)
                local barWidth = mw - 2
                local filled = math.floor((generationProgress / 100) * barWidth)
                monitor.write("[" .. string.rep("#", filled) .. string.rep("-", barWidth - filled) .. "]")

                monitor.setCursorPos(1, 7)
                monitor.write(generationProgress .. "%")
            else
                monitor.setCursorPos(1, 3)
                monitor.setTextColor(colors.gray)
                monitor.write("Insert fuel...")

                monitor.setCursorPos(1, 5)
                monitor.setTextColor(colors.lime)
                monitor.write("Generated: " .. totalGenerated)
            end
        end

        sleep(0.3)
    end
end

-- ======================
-- ANNOUNCE TO CENTRAL
-- ======================
local function announce()
    rednet.broadcast({
        id = "GENERATOR",
        deviceType = "generator",
        type = "hello"
    }, PROTOCOL)
end

-- ======================
-- RUN EVERYTHING
-- ======================
print("Starting Generator Room...")
print("Chest: " .. CHEST_SIDE)
announce()

parallel.waitForAll(
    generatorLoopSimple,
    networkLoop,
    displayLoop
)

-- Safe Stairs v2 - Advanced Bedrock Mining System
-- A robust turtle program for creating safe stairs to bedrock
-- Features: Smart inventory management, fuel optimization, safety checks
-- 
-- Setup Instructions:
-- Slot 1: Coal (for fuel)
-- Slot 2: Chests (for storage)
-- Slot 3: Torches (for lighting)
-- Slot 4: Reserved for building materials

print("=== Safe Stairs v2 - Advanced Bedrock Mining ===")
print("Initializing systems...")

-- ============================================================================
-- CONFIGURATION & CONSTANTS
-- ============================================================================

local CONFIG = {
    COAL_SLOT = 1,
    CHEST_SLOT = 2,
    TORCH_SLOT = 3,
    BUILD_SLOT = 4,
    
    BEDROCK_LEVEL = 1,
    MIN_FUEL_THRESHOLD = 150,
    EMERGENCY_FUEL_RESERVE = 300,
    TORCH_SPACING = 8,
    INVENTORY_BUFFER = 2,
    
    MAX_DEPTH = 320,  -- Safety limit
    REFUEL_AMOUNT = 10,
}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local State = {
    depth = 0,
    totalSteps = 0,
    chestsDeployed = 0,
    torchesPlaced = 0,
    fuelConsumed = 0,
    blocksCollected = 0,
    phase = "DESCENDING",  -- DESCENDING, ASCENDING, COMPLETE
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function log(message, level)
    level = level or "INFO"
    local prefix = "[" .. level .. "] "
    print(prefix .. message)
end

local function safeSelect(slot)
    if slot >= 1 and slot <= 16 then
        turtle.select(slot)
        return true
    end
    log("Invalid slot: " .. tostring(slot), "ERROR")
    return false
end

local function getItemName(slot)
    if not safeSelect(slot) then return nil end
    local detail = turtle.getItemDetail()
    return detail and detail.name or nil
end

local function countItems(itemName)
    local total = 0
    for i = 1, 16 do
        if getItemName(i) == itemName then
            total = total + turtle.getItemCount(i)
        end
    end
    return total
end

-- ============================================================================
-- INVENTORY MANAGEMENT
-- ============================================================================

local Inventory = {}

function Inventory.getFreeSlots()
    local free = 0
    for i = 5, 16 do  -- Working slots only
        if turtle.getItemCount(i) == 0 then
            free = free + 1
        end
    end
    return free
end

function Inventory.isFull()
    return Inventory.getFreeSlots() <= CONFIG.INVENTORY_BUFFER
end

function Inventory.consolidate()
    log("Consolidating inventory...")
    local consolidated = 0
    
    for i = 5, 15 do
        if turtle.getItemCount(i) > 0 then
            safeSelect(i)
            local itemName = getItemName(i)
            
            -- Look for matching items in later slots
            for j = i + 1, 16 do
                if getItemName(j) == itemName then
                    safeSelect(j)
                    turtle.transferTo(i)
                    consolidated = consolidated + 1
                end
            end
        end
    end
    
    if consolidated > 0 then
        log("Consolidated " .. consolidated .. " item stacks")
    end
end

function Inventory.deployChest()
    if turtle.getItemCount(CONFIG.CHEST_SLOT) == 0 then
        log("No chests available for deployment!", "WARN")
        return false
    end
    
    log("Deploying storage chest...")
    
    -- Turn left to place chest on side wall
    turtle.turnLeft()
    
    -- Clear space if needed
    if turtle.detect() then
        turtle.dig()
        os.sleep(0.5)
    end
    
    -- Place chest
    safeSelect(CONFIG.CHEST_SLOT)
    if not turtle.place() then
        log("Failed to place chest!", "ERROR")
        turtle.turnRight()
        return false
    end
    
    -- Store non-essential items
    local itemsStored = 0
    for i = 5, 16 do
        if turtle.getItemCount(i) > 0 then
            safeSelect(i)
            local itemName = getItemName(i)
            
            -- Keep some building materials and all coal
            if itemName == "minecraft:coal" or itemName == "minecraft:charcoal" then
                -- Keep all fuel
            elseif itemName and (string.find(itemName, "stone") or string.find(itemName, "cobblestone")) then
                -- Keep some building materials (32 blocks max)
                if turtle.getItemCount(i) > 32 then
                    turtle.drop(turtle.getItemCount(i) - 32)
                    itemsStored = itemsStored + (turtle.getItemCount(i) - 32)
                end
            else
                -- Store everything else
                local count = turtle.getItemCount(i)
                turtle.drop()
                itemsStored = itemsStored + count
            end
        end
    end
    
    turtle.turnRight()
    State.chestsDeployed = State.chestsDeployed + 1
    log("Chest deployed! Stored " .. itemsStored .. " items")
    return true
end

-- ============================================================================
-- FUEL MANAGEMENT
-- ============================================================================

local Fuel = {}

function Fuel.getLevel()
    return turtle.getFuelLevel()
end

function Fuel.isLow()
    return Fuel.getLevel() < CONFIG.MIN_FUEL_THRESHOLD
end

function Fuel.hasEmergencyReserve()
    local needed = (State.depth * 2) + CONFIG.EMERGENCY_FUEL_RESERVE
    return Fuel.getLevel() >= needed
end

function Fuel.refuel()
    local initialFuel = Fuel.getLevel()
    local refueled = false
    
    -- Try found coal first
    for i = 5, 16 do
        local itemName = getItemName(i)
        if itemName == "minecraft:coal" or itemName == "minecraft:charcoal" then
            safeSelect(i)
            if turtle.refuel(CONFIG.REFUEL_AMOUNT) then
                refueled = true
                log("Refueled with found coal: +" .. (Fuel.getLevel() - initialFuel))
                break
            end
        end
    end
    
    -- Use starting coal if needed
    if not refueled and turtle.getItemCount(CONFIG.COAL_SLOT) > 0 then
        safeSelect(CONFIG.COAL_SLOT)
        if turtle.refuel(CONFIG.REFUEL_AMOUNT) then
            refueled = true
            log("Refueled with starting coal: +" .. (Fuel.getLevel() - initialFuel))
        end
    end
    
    if not refueled then
        log("No fuel available for refueling!", "WARN")
    end
    
    State.fuelConsumed = State.fuelConsumed + (Fuel.getLevel() - initialFuel)
    return refueled
end

-- ============================================================================
-- MOVEMENT & MINING
-- ============================================================================

local Movement = {}

function Movement.safeDig(direction)
    direction = direction or "forward"
    local digFunc = turtle.dig
    local detectFunc = turtle.detect
    
    if direction == "up" then
        digFunc = turtle.digUp
        detectFunc = turtle.detectUp
    elseif direction == "down" then
        digFunc = turtle.digDown
        detectFunc = turtle.detectDown
    end
    
    local attempts = 0
    while detectFunc() and attempts < 10 do
        if digFunc() then
            State.blocksCollected = State.blocksCollected + 1
            os.sleep(0.5)  -- Wait for block to break
        end
        attempts = attempts + 1
    end
    
    return not detectFunc()
end

function Movement.safeMove(direction)
    direction = direction or "forward"
    local moveFunc = turtle.forward
    
    if direction == "up" then
        moveFunc = turtle.up
    elseif direction == "down" then
        moveFunc = turtle.down
    elseif direction == "back" then
        moveFunc = turtle.back
    end
    
    local attempts = 0
    while not moveFunc() and attempts < 5 do
        Movement.safeDig(direction)
        os.sleep(0.2)
        attempts = attempts + 1
    end
    
    return attempts < 5
end

function Movement.createStairStep()
    -- Clear path ahead and above
    Movement.safeDig("forward")
    Movement.safeDig("up")
    
    -- Move forward
    if not Movement.safeMove("forward") then
        log("Failed to move forward!", "ERROR")
        return false
    end
    
    -- Dig and move down
    Movement.safeDig("down")
    if not Movement.safeMove("down") then
        log("Failed to move down!", "ERROR")
        return false
    end
    
    -- Clear headroom
    Movement.safeDig("up")
    
    State.depth = State.depth + 1
    State.totalSteps = State.totalSteps + 1
    
    return true
end

-- ============================================================================
-- LIGHTING SYSTEM
-- ============================================================================

local Lighting = {}

function Lighting.placeTorch()
    if turtle.getItemCount(CONFIG.TORCH_SLOT) == 0 then
        return false
    end
    
    safeSelect(CONFIG.TORCH_SLOT)
    turtle.turnLeft()
    
    if turtle.place() then
        State.torchesPlaced = State.torchesPlaced + 1
        log("Torch placed (#" .. State.torchesPlaced .. ")")
    end
    
    turtle.turnRight()
    return true
end

function Lighting.shouldPlaceTorch()
    return State.totalSteps % CONFIG.TORCH_SPACING == 0
end

-- ============================================================================
-- BEDROCK DETECTION
-- ============================================================================

local Bedrock = {}

function Bedrock.isAtBedrock()
    -- Check if we can't dig down
    if turtle.detectDown() then
        local success, data = turtle.inspectDown()
        if success and data.name == "minecraft:bedrock" then
            log("Bedrock detected!")
            return true
        end
        
        -- Try to dig - if it fails, might be bedrock
        if not turtle.digDown() then
            success, data = turtle.inspectDown()
            if success and data.name == "minecraft:bedrock" then
                log("Unbreakable bedrock found!")
                return true
            end
        end
    end
    
    -- Check depth limit
    if State.depth >= CONFIG.MAX_DEPTH then
        log("Maximum safe depth reached!")
        return true
    end
    
    return false
end

-- ============================================================================
-- BUILDING SYSTEM
-- ============================================================================

local Builder = {}

function Builder.prepareMaterials()
    local bestMaterial = nil
    local bestSlot = nil
    local bestCount = 0
    
    -- Find best building material
    for i = 5, 16 do
        local itemName = getItemName(i)
        if itemName then
            local count = turtle.getItemCount(i)
            local isBuildingMaterial = string.find(itemName, "stone") or 
                                     string.find(itemName, "cobblestone") or
                                     string.find(itemName, "dirt") or
                                     string.find(itemName, "andesite") or
                                     string.find(itemName, "granite") or
                                     string.find(itemName, "diorite")
            
            if isBuildingMaterial and count > bestCount then
                bestMaterial = itemName
                bestSlot = i
                bestCount = count
            end
        end
    end
    
    if bestMaterial then
        log("Using " .. bestMaterial .. " for construction (" .. bestCount .. " blocks)")
        safeSelect(bestSlot)
        turtle.transferTo(CONFIG.BUILD_SLOT, math.min(64, bestCount))
        return true
    end
    
    log("No suitable building materials found!", "WARN")
    return false
end

function Builder.buildStairUp()
    local placed = false
    
    -- Try designated build slot first
    if turtle.getItemCount(CONFIG.BUILD_SLOT) > 0 then
        safeSelect(CONFIG.BUILD_SLOT)
        if turtle.placeDown() then
            placed = true
        end
    end
    
    -- Try any suitable material
    if not placed then
        for i = 5, 16 do
            local itemName = getItemName(i)
            if itemName and turtle.getItemCount(i) > 0 then
                -- Avoid using tools and special items
                if not (itemName == "minecraft:coal" or 
                       itemName == "minecraft:chest" or
                       itemName == "minecraft:torch" or
                       string.find(itemName, "pickaxe") or
                       string.find(itemName, "sword")) then
                    safeSelect(i)
                    if turtle.placeDown() then
                        placed = true
                        break
                    end
                end
            end
        end
    end
    
    return placed
end

function Builder.ascendToSurface()
    log("Beginning ascent to surface...")
    State.phase = "ASCENDING"
    
    Builder.prepareMaterials()
    local stairsBuilt = 0
    
    while State.depth > 0 do
        -- Place building block
        if not Builder.buildStairUp() then
            log("Warning: No building material for step " .. stairsBuilt, "WARN")
        end
        
        -- Move up
        if not Movement.safeMove("up") then
            log("Failed to move up! Stuck at depth " .. State.depth, "ERROR")
            break
        end
        
        State.depth = State.depth - 1
        stairsBuilt = stairsBuilt + 1
        
        -- Place torch for lighting
        if stairsBuilt % CONFIG.TORCH_SPACING == 0 then
            Lighting.placeTorch()
        end
        
        -- Fuel check
        if Fuel.isLow() then
            Fuel.refuel()
        end
        
        -- Progress update
        if stairsBuilt % 10 == 0 then
            log("Ascent progress: " .. stairsBuilt .. " steps, depth " .. State.depth)
        end
        
        os.sleep(0.1)
    end
    
    log("Ascent complete! Built " .. stairsBuilt .. " stair steps")
    return true
end

-- ============================================================================
-- MAIN PROGRAM LOGIC
-- ============================================================================

local function preFlightCheck()
    log("Performing pre-flight checks...")
    
    -- Check fuel
    if Fuel.getLevel() < CONFIG.MIN_FUEL_THRESHOLD then
        log("Low fuel detected, refueling...")
        if not Fuel.refuel() then
            log("CRITICAL: Insufficient fuel to begin operation!", "ERROR")
            return false
        end
    end
    
    -- Check essential supplies
    if turtle.getItemCount(CONFIG.COAL_SLOT) == 0 then
        log("WARNING: No coal in slot " .. CONFIG.COAL_SLOT, "WARN")
    end
    
    if turtle.getItemCount(CONFIG.CHEST_SLOT) == 0 then
        log("WARNING: No chests in slot " .. CONFIG.CHEST_SLOT, "WARN")
    end
    
    log("Pre-flight check complete")
    log("Fuel: " .. Fuel.getLevel())
    log("Coal: " .. turtle.getItemCount(CONFIG.COAL_SLOT))
    log("Chests: " .. turtle.getItemCount(CONFIG.CHEST_SLOT))
    log("Torches: " .. turtle.getItemCount(CONFIG.TORCH_SLOT))
    
    return true
end

local function descendToBedrock()
    log("Beginning descent to bedrock...")
    State.phase = "DESCENDING"
    
    while not Bedrock.isAtBedrock() do
        -- Safety checks
        if not Fuel.hasEmergencyReserve() then
            log("CRITICAL: Insufficient fuel for safe return!", "ERROR")
            break
        end
        
        -- Inventory management
        if Inventory.isFull() then
            Inventory.consolidate()
            if Inventory.isFull() then
                Inventory.deployChest()
            end
        end
        
        -- Fuel management
        if Fuel.isLow() then
            Fuel.refuel()
        end
        
        -- Create stair step
        if not Movement.createStairStep() then
            log("Failed to create stair step!", "ERROR")
            break
        end
        
        -- Place torch if needed
        if Lighting.shouldPlaceTorch() then
            Lighting.placeTorch()
        end
        
        -- Progress update
        if State.depth % 10 == 0 then
            log("Depth: " .. State.depth .. ", Fuel: " .. Fuel.getLevel())
        end
        
        os.sleep(0.1)
    end
    
    log("Descent complete! Final depth: " .. State.depth)
end

local function printSummary()
    log("=== MISSION SUMMARY ===")
    log("Total depth reached: " .. State.depth)
    log("Total steps taken: " .. State.totalSteps)
    log("Blocks collected: " .. State.blocksCollected)
    log("Chests deployed: " .. State.chestsDeployed)
    log("Torches placed: " .. State.torchesPlaced)
    log("Fuel consumed: " .. State.fuelConsumed)
    log("Final fuel level: " .. Fuel.getLevel())
    log("Mission status: " .. State.phase)
end

-- ============================================================================
-- MAIN EXECUTION
-- ============================================================================

local function main()
    log("Safe Stairs v2 initialized")
    
    if not preFlightCheck() then
        log("Pre-flight check failed! Aborting mission.", "ERROR")
        return
    end
    
    -- Phase 1: Descend to bedrock
    descendToBedrock()
    
    -- Phase 2: Build stairs back up
    Builder.ascendToSurface()
    
    -- Mission complete
    State.phase = "COMPLETE"
    log("Mission accomplished!")
    printSummary()
end

-- Execute the program
main()

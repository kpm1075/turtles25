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
    EMERGENCY_FUEL_RESERVE = 20,
    TORCH_SPACING = 8,
    INVENTORY_BUFFER = 2,
    
    MAX_DEPTH = 320,  -- Safety limit
    REFUEL_AMOUNT = 10,
}

local BUILDING_BLOCKS = {
    ["minecraft:cobblestone"] = true,
    ["minecraft:cobbled_deepslate"] = true,
    ["minecraft:stone"] = true,
    ["minecraft:andesite"] = true,
    ["minecraft:diorite"] = true,
    ["minecraft:granite"] = true,
    ["minecraft:tuff"] = true,
    ["minecraft:basalt"] = true,
    ["minecraft:blackstone"] = true,
    ["minecraft:netherrack"] = true,
    ["minecraft:dirt"] = true,
    ["minecraft:deepslate"] = true,
    ["minecraft:mossy_cobblestone"] = true
}

local STAIR_CRAFTABLE_ORDER = {
    "minecraft:cobblestone",
    "minecraft:cobbled_deepslate",
    "minecraft:stone",
    "minecraft:blackstone"
}

local STAIR_CRAFTABLE = {}
for _, name in ipairs(STAIR_CRAFTABLE_ORDER) do
    STAIR_CRAFTABLE[name] = true
end

local function isBuildingMaterial(name)
    if not name then return false end
    return BUILDING_BLOCKS[name] or false
end

local function isStairCraftMaterial(name)
    if not name then return false end
    return STAIR_CRAFTABLE[name] or false
end

local function isStairItem(name)
    return type(name) == "string" and string.find(name, "_stairs", 1, true) ~= nil
end

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
    stairsCrafted = 0,
    stairsPlaced = 0,
    fallbackSteps = 0,
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

function Inventory.findEmptySlot(startSlot, endSlot)
    startSlot = startSlot or 1
    endSlot = endSlot or 16
    for slot = startSlot, endSlot do
        if turtle.getItemCount(slot) == 0 then
            return slot
        end
    end
    return nil
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
                    if turtle.transferTo(i) then
                        consolidated = consolidated + 1
                    end
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
            
            -- Keep some critical supplies
            if itemName == "minecraft:coal" or itemName == "minecraft:charcoal" then
                -- Keep all fuel
            elseif isStairItem(itemName) then
                -- Keep all crafted stairs
            elseif itemName and isBuildingMaterial(itemName) then
                -- Keep some building materials (32 blocks max)
                local count = turtle.getItemCount(i)
                if count > 32 then
                    local excess = count - 32
                    if turtle.drop(excess) then
                        itemsStored = itemsStored + excess
                    end
                end
            else
                -- Store everything else
                local count = turtle.getItemCount(i)
                if turtle.drop() then
                    itemsStored = itemsStored + count
                end
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
    
    -- Check if we can place a torch on the left wall
    turtle.turnLeft()
    
    -- Clear any block in the way
    if turtle.detect() then
        turtle.dig()
        os.sleep(0.5)
    end
    
    -- Try to place the torch
    local placed = false
    if turtle.place() then
        State.torchesPlaced = State.torchesPlaced + 1
        log("Torch placed (#" .. State.torchesPlaced .. ")")
        placed = true
    else
        -- If we can't place on the wall, try placing on the floor
        turtle.turnRight()  -- Back to forward
        turtle.turnRight()  -- Turn to face back
        if not turtle.detectDown() then
            if turtle.placeDown() then
                State.torchesPlaced = State.torchesPlaced + 1
                log("Torch placed on floor (#" .. State.torchesPlaced .. ")")
                placed = true
            end
        end
        turtle.turnLeft()  -- Turn back to forward
    end
    
    turtle.turnRight()  -- Always turn back to original orientation
    return placed
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

local STAIR_RECIPE_SLOTS = {1, 4, 5, 7, 8, 9}
local ALL_CRAFT_SLOTS = {1, 2, 3, 4, 5, 6, 7, 8, 9}
local CRAFT_SLOT_SET = {}
for _, slot in ipairs(ALL_CRAFT_SLOTS) do
    CRAFT_SLOT_SET[slot] = true
end

local function restoreCraftSession(session)
    if not session then return end
    for i = #session.restore, 1, -1 do
        local move = session.restore[i]
        if turtle.getItemCount(move.to) > 0 then
            safeSelect(move.to)
            turtle.transferTo(move.from)
        end
    end
end

local function beginCraftingSession()
    local session = { restore = {} }

    local function moveSlot(fromSlot, trackRestore)
        if turtle.getItemCount(fromSlot) == 0 then
            return true
        end
        local dest = Inventory.findEmptySlot(10, 16)
        if not dest then
            log("Unable to free slot " .. fromSlot .. " for crafting (inventory full)", "WARN")
            return false
        end
        safeSelect(fromSlot)
        local count = turtle.getItemCount(fromSlot)
        if turtle.transferTo(dest, count) then
            if trackRestore then
                table.insert(session.restore, { from = fromSlot, to = dest })
            end
            return true
        end
        log("Failed to move items from slot " .. fromSlot .. " to slot " .. dest, "ERROR")
        return false
    end

    for _, slot in ipairs({ CONFIG.COAL_SLOT, CONFIG.CHEST_SLOT, CONFIG.TORCH_SLOT }) do
        if not moveSlot(slot, true) then
            restoreCraftSession(session)
            return nil
        end
    end

    if not moveSlot(CONFIG.BUILD_SLOT, false) then
        restoreCraftSession(session)
        return nil
    end

    for slot = 1, 9 do
        if turtle.getItemCount(slot) > 0 then
            if not moveSlot(slot, false) then
                restoreCraftSession(session)
                return nil
            end
        end
    end

    return session
end

function Builder.isStairItem(name)
    return isStairItem(name)
end

function Builder.prepareMaterials()
    local currentName = getItemName(CONFIG.BUILD_SLOT)
    if turtle.getItemCount(CONFIG.BUILD_SLOT) > 0 and (Builder.isStairItem(currentName) or isBuildingMaterial(currentName)) then
        return true
    end

    if turtle.getItemCount(CONFIG.BUILD_SLOT) > 0 then
        local dest = Inventory.findEmptySlot(10, 16) or Inventory.findEmptySlot(5, 16)
        if dest then
            safeSelect(CONFIG.BUILD_SLOT)
            turtle.transferTo(dest)
        end
    end

    local bestSlot = nil
    local bestCount = 0

    for slot = 5, 16 do
        if slot ~= CONFIG.BUILD_SLOT and turtle.getItemCount(slot) > 0 then
            local itemName = getItemName(slot)
            if itemName and (Builder.isStairItem(itemName) or isBuildingMaterial(itemName)) then
                local count = turtle.getItemCount(slot)
                if count > bestCount then
                    bestSlot = slot
                    bestCount = count
                end
            end
        end
    end

    if bestSlot then
        safeSelect(bestSlot)
        if turtle.transferTo(CONFIG.BUILD_SLOT) then
            return true
        end
    end

    log("No suitable building materials found!", "WARN")
    return false
end

function Builder.loadStairsToBuildSlot()
    local currentName = getItemName(CONFIG.BUILD_SLOT)
    if Builder.isStairItem(currentName) and turtle.getItemCount(CONFIG.BUILD_SLOT) > 0 then
        return true
    end

    if turtle.getItemCount(CONFIG.BUILD_SLOT) > 0 and not Builder.isStairItem(currentName) then
        local dest = Inventory.findEmptySlot(10, 16) or Inventory.findEmptySlot(5, 16)
        if dest then
            safeSelect(CONFIG.BUILD_SLOT)
            turtle.transferTo(dest)
        else
            return false
        end
    end

    for slot = 5, 16 do
        if slot ~= CONFIG.BUILD_SLOT and turtle.getItemCount(slot) > 0 then
            local itemName = getItemName(slot)
            if Builder.isStairItem(itemName) then
                safeSelect(slot)
                if turtle.transferTo(CONFIG.BUILD_SLOT) then
                    return true
                end
            end
        end
    end

    return Builder.isStairItem(getItemName(CONFIG.BUILD_SLOT)) and turtle.getItemCount(CONFIG.BUILD_SLOT) > 0
end

function Builder.ensureStairSupply()
    if Builder.loadStairsToBuildSlot() then
        return true
    end
    return false
end

function Builder.placeFallbackBlock()
    local function tryFromSlot(slot)
        if turtle.getItemCount(slot) == 0 then
            return false
        end
        local itemName = getItemName(slot)
        if itemName and not Builder.isStairItem(itemName) and isBuildingMaterial(itemName) then
            safeSelect(slot)
            if turtle.placeDown() then
                State.fallbackSteps = State.fallbackSteps + 1
                return true
            end
        end
        return false
    end

    if tryFromSlot(CONFIG.BUILD_SLOT) then
        return true
    end

    for slot = 5, 16 do
        if slot ~= CONFIG.BUILD_SLOT and tryFromSlot(slot) then
            return true
        end
    end

    return false
end

function Builder.buildStairUp()
    if Builder.ensureStairSupply() then
        local name = getItemName(CONFIG.BUILD_SLOT)
        if Builder.isStairItem(name) and turtle.getItemCount(CONFIG.BUILD_SLOT) > 0 then
            safeSelect(CONFIG.BUILD_SLOT)
            if turtle.placeDown() then
                State.stairsPlaced = State.stairsPlaced + 1
                return true
            end
        end
    end

    return Builder.placeFallbackBlock()
end

function Builder.collectCraftOutput(previousCount)
    previousCount = previousCount or turtle.getItemCount(CONFIG.BUILD_SLOT)

    for slot = 1, 16 do
        if slot ~= CONFIG.BUILD_SLOT and turtle.getItemCount(slot) > 0 then
            local itemName = getItemName(slot)
            if Builder.isStairItem(itemName) then
                safeSelect(slot)
                turtle.transferTo(CONFIG.BUILD_SLOT)
            end
        end
    end

    safeSelect(CONFIG.BUILD_SLOT)
    local newCount = turtle.getItemCount(CONFIG.BUILD_SLOT)
    return math.max(0, newCount - previousCount)
end

function Builder.pullItemToSlot(itemName, targetSlot)
    if turtle.getItemCount(targetSlot) > 0 then
        return true
    end

    for slot = 16, 1, -1 do
        if slot ~= targetSlot and not CRAFT_SLOT_SET[slot] and turtle.getItemCount(slot) > 0 then
            local name = getItemName(slot)
            if name == itemName then
                safeSelect(slot)
                if turtle.transferTo(targetSlot, 1) then
                    return true
                end
            end
        end
    end

    return false
end

function Builder.loadStairRecipe(itemName)
    for _, slot in ipairs(STAIR_RECIPE_SLOTS) do
        if not Builder.pullItemToSlot(itemName, slot) then
            return false
        end
    end
    return true
end

function Builder.findCraftableMaterial(minCount)
    for _, name in ipairs(STAIR_CRAFTABLE_ORDER) do
        if countItems(name) >= minCount then
            return name
        end
    end
    return nil
end

function Builder.clearCraftingGrid()
    for _, slot in ipairs(ALL_CRAFT_SLOTS) do
        if turtle.getItemCount(slot) > 0 then
            local dest = Inventory.findEmptySlot(10, 16) or Inventory.findEmptySlot(5, 16)
            if not dest then
                log("Failed to clear crafting slot " .. slot .. " (inventory full)", "WARN")
                return false
            end
            safeSelect(slot)
            if not turtle.transferTo(dest) then
                log("Failed to move items out of crafting slot " .. slot, "ERROR")
                return false
            end
        end
    end
    return true
end

function Builder.prepareStairs()
    Inventory.consolidate()

    local session = beginCraftingSession()
    if not session then
        return Builder.loadStairsToBuildSlot()
    end

    local craftedStairs = 0

    while true do
        local material = Builder.findCraftableMaterial(6)
        if not material then
            break
        end

        if not Builder.loadStairRecipe(material) then
            break
        end

        local before = turtle.getItemCount(CONFIG.BUILD_SLOT)
        if turtle.craft() then
            local delta = Builder.collectCraftOutput(before)
            craftedStairs = craftedStairs + delta
            State.stairsCrafted = State.stairsCrafted + delta
        else
            log("Crafting attempt failed for " .. material, "ERROR")
            Builder.clearCraftingGrid()
            break
        end
    end

    Builder.clearCraftingGrid()
    restoreCraftSession(session)
    safeSelect(CONFIG.COAL_SLOT)

    if craftedStairs > 0 then
        log("Crafted " .. craftedStairs .. " stairs for ascent")
    else
        log("No stairs crafted for ascent", "WARN")
    end

    return Builder.loadStairsToBuildSlot()
end

function Builder.prepareAscentMaterials()
    if Builder.prepareStairs() then
        return
    end
    log("Crafted stair supply unavailable - falling back to solid blocks", "WARN")
    Builder.prepareMaterials()
end

function Builder.ascendToSurface()
    log("Beginning ascent to surface...")
    State.phase = "ASCENDING"

    Builder.prepareAscentMaterials()
    
    -- Turn around to face the path back up
    turtle.turnLeft()
    turtle.turnLeft()
    
    local stepsAscended = 0
    
    while State.depth > 0 do
        -- Move forward (up the path)
        if not Movement.safeMove("forward") then
            log("Failed to move forward! Stuck at depth " .. State.depth, "ERROR")
            break
        end
        
        -- Move up
        if not Movement.safeMove("up") then
            log("Failed to move up! Stuck at depth " .. State.depth, "ERROR")
            break
        end
        
        -- Place stair (or fallback block) under us
        if not Builder.buildStairUp() then
            log("Warning: Unable to place stair or fallback block at step " .. stepsAscended, "WARN")
        end
        
        State.depth = State.depth - 1
        stepsAscended = stepsAscended + 1
        
        -- Place torch for lighting
        if stepsAscended % CONFIG.TORCH_SPACING == 0 then
            Lighting.placeTorch()
        end
        
        -- Fuel check
        if Fuel.isLow() then
            Fuel.refuel()
        end
        
        -- Progress update
        if stepsAscended % 10 == 0 then
            log("Ascent progress: " .. stepsAscended .. " steps, depth " .. State.depth)
        end
        
        os.sleep(0.1)
    end
    
    -- Turn around to face the original direction
    turtle.turnLeft()
    turtle.turnLeft()
    
    log("Ascent complete! Built staircase with " .. stepsAscended .. " steps")
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
            log("Fuel reserve low, attempting to refuel before continuing...", "WARN")
            Fuel.refuel()
            if not Fuel.hasEmergencyReserve() then
                log("CRITICAL: Insufficient fuel for safe return!", "ERROR")
                break
            end
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
    log("Stairs crafted: " .. State.stairsCrafted)
    log("Stairs placed: " .. State.stairsPlaced)
    log("Fallback steps built: " .. State.fallbackSteps)
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

local function refuel()
	turtle.select(1)
	turtle.refuel(32)
end

-- Get wool block name from color
local function getWoolBlock(color)
	if color == "green" then
		return "minecraft:green_wool"
	elseif color == "blue" then
		return "minecraft:blue_wool"
	elseif color == "red" then
		return "minecraft:red_wool"
	elseif color == "yellow" then
		return "minecraft:yellow_wool"
	elseif color == "white" then
		return "minecraft:white_wool"
	elseif color == "black" then
		return "minecraft:black_wool"
	elseif color == "orange" then
		return "minecraft:orange_wool"
	elseif color == "purple" then
		return "minecraft:purple_wool"
	elseif color == "pink" then
		return "minecraft:pink_wool"
	elseif color == "brown" then
		return "minecraft:brown_wool"
	elseif color == "gray" or color == "grey" then
		return "minecraft:gray_wool"
	elseif color == "lime" then
		return "minecraft:lime_wool"
	elseif color == "cyan" then
		return "minecraft:cyan_wool"
	elseif color == "light_blue" then
		return "minecraft:light_blue_wool"
	elseif color == "magenta" then
		return "minecraft:magenta_wool"
	else
		return "minecraft:white_wool" -- default to white for unknown colors
	end
end

-- Find and select wool block in inventory
local function selectWoolBlock(woolType)
	for slot = 1, 16 do
		turtle.select(slot)
		local item = turtle.getItemDetail()
		if item and item.name == woolType then
			return true
		end
	end
	return false
end

-- Build one row of the 5x5 grid
local function BuildRow(colors, rowIndex)
	print("Building row " .. rowIndex)
	
	for col = 1, 5 do
		local colorIndex = (rowIndex - 1) * 5 + col
		local color = colors[colorIndex]
		
		if color and color ~= "air" then
			local woolType = getWoolBlock(color)
			print("Placing " .. color .. " wool at (" .. col .. "," .. rowIndex .. ")")
			
			if selectWoolBlock(woolType) then
				turtle.placeDown()
			else
				print("Warning: No " .. color .. " wool found in inventory")
			end
		else
			print("Skipping air block at (" .. col .. "," .. rowIndex .. ")")
		end
		
		-- Move forward unless we're at the end of the row
		if col < 5 then
			turtle.forward()
		end
	end
	
	-- Return to start of row
	for i = 1, 4 do
		turtle.back()
	end
end

print("Starting 5x5 grid build...")

-- Make sure turtle has fuel to move
refuel()

-- Get colors from API
print("Fetching colors from API...")
local response = http.get("https://cedar.fogcloud.org/api/logs/5E0F")
if not response then
	print("Error: Could not fetch data from API")
	return
end

local content = response.readAll()
response.close()

-- Parse colors from response (assuming one color per line)
local colors = {}
for line in content:gmatch("[^\r\n]+") do
	if line and line ~= "" then
		table.insert(colors, line:lower():gsub("%s+", "")) -- trim whitespace and lowercase
	end
end

print("Retrieved " .. #colors .. " colors from API")

-- Build all 5 rows
for row = 1, 5 do
	BuildRow(colors, row)
	
	-- Move to next row unless we're done
	if row < 5 then
		turtle.turnLeft()
		turtle.forward()
		turtle.turnRight()
	end
end

print("Grid build complete!")

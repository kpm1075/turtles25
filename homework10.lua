-- This girl's a miner.
-- Usage: homework10 <depth> <area>
-- Searches a N x N area for a log.

local args = { ... }
if #args < 2 then
	print("Usage: homework10 <depth> <area>")
	return
end

local depth = tonumber(args[1])
if not depth or depth < 1 then
	print("Depth must be a positive number")
	return
end

local length = tonumber(args[2])
if not length or length < 1 then
	print("Area must be a positive number")
	return
end

print("depth = " .. depth .. ", area = " .. length)

-- position relative to starting position
local px, pz, py = 0, 0, 0
local dx, dz = 1, 0

local blocksDug = {}
blocksDug[1] = {}

local function turnRight()
	turtle.turnRight()
	if dx == 1 and dz == 0 then
		print("Turning from +x to +z")
		dx, dz = 0, 1
	elseif dx == 0 and dz == 1 then
		print("Turning from +z to -x")
		dx, dz = -1, 0
	elseif dx == -1 and dz == 0 then
		print("Turning from -x to -z")
		dx, dz = 0, -1
	elseif dx == 0 and dz == -1 then
		print("Turning from -z to +x")
		dx, dz = 1, 0
	end
	print("New direction: " .. dx .. ", " .. dz)
end

local function turnLeft()
	turtle.turnLeft()
	if dx == 1 and dz == 0 then
		print("Turning from +x to -z")
		dx, dz = 0, -1
	elseif dx == 0 and dz == 1 then
		print("Turning from -z to -x")
		dx, dz = -1, 0
	elseif dx == -1 and dz == 0 then
		print("Turning from -x to +z")
		dx, dz = 0, 1
	elseif dx == 0 and dz == -1 then
		print("Turning from +z to +x")
		dx, dz = 1, 0
	end
	print("New direction: " .. dx .. ", " .. dz)
end

local function turnAround()
	turnRight()
	turnRight()
end

local function digDown()
	local success, data = turtle.inspectDown()
	if success then
		print("Found " .. data.name)
		turtle.digDown()
	end
	turtle.down()
	py = py - 1
end

local function digUp()
	local success, data = turtle.inspectUp()
	if success then
		print("Found " .. data.name)
		turtle.digUp()
	end
	turtle.up()
	py = py + 1
end

local function addBlockToArray(block)
	if not blocksDug[1][1] then
		print("First index nil. Assigning value.")
		blocksDug[1] = {}
		blocksDug[1][1] = block
	end
	local foundBlockInArray = false
	for i = 1, #blocksDug do
		if blocksDug[i][1] == block then
			if not blocksDug[i][2] then
				blocksDug[i][2] = 0
			end
			blocksDug[i][2] = blocksDug[i][2] + 1
			foundBlockInArray = true
			print(blocksDug[i][2])
		end
	end
	if not foundBlockInArray then
		if not blocksDug[1][2] then
			blocksDug[1][2] = 1
		end
		blocksDug[#blocksDug + 1] = {}
		blocksDug[#blocksDug][1] = block
		blocksDug[#blocksDug][2] = 1
	end
end

local function digForward()
	local success, data = turtle.inspect()
	if success then
		print("Found " .. data.name)
		addBlockToArray(data.name)
		turtle.dig()
		if data.name:find("gravel") then
			print("Digging gravel...")
			for i = 1, 15 do
				turtle.dig()
			end
			print("Gravel terminated.")
		end
		if data.name:find("coal") then
			for i = 1, 16 do
				if turtle.getItemCount(i) > 0 then
					if turtle.getItemDetail(i).name:find("coal") then
						turtle.select(i)
						turtle.refuel(1)
						print("Refueling.")
					end
				end
			end
		end
	end
	turtle.forward()
	px = px + dx
	pz = pz + dz
end

for n = 1, depth do
	digDown()
end

for o = 1, length/2 do
	for m = 1, length do
		digForward()
	end
	turnLeft()
	digForward()
	turnLeft()
	for m = 1, length do
		digForward()
	end
	turnRight()
	if o ~= length/2 then
		digForward()
	end
	turnRight()
end

turnRight()

for i = 1, length - 1 do
	digForward()
end

while (py < 0) do
	digUp()
end

print("Found blocks:")
for i = 1, #blocksDug do
	print(blocksDug[i][1] .. ": " .. blocksDug[i][2])
end

print("End of program.")

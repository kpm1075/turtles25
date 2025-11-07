-- This girl's a miner.
-- Usage: lab10 <depth> <length>
-- Searches a N x N area for a log.

local args = { ... }
if #args < 2 then
	print("Usage: lab10 <depth> <length>")
	return
end

local depth = tonumber(args[1])
if not depth or depth < 1 then
	print("Depth must be a positive number")
	return
end

local length = tonumber(args[2])
if not length or length < 1 then
	print("Length must be a positive number")
	return
end

print("depth = " .. depth .. ", length = " .. length)

-- position relative to starting position
local px, pz, py = 0, 0, 0
local dx, dz = 1, 0

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
	turtle.turnRight()
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

local function digForward()
	local success, data = turtle.inspect()
	if success then
		print("Found " .. data.name)
		turtle.dig()
	end
	turtle.forward()
	px = px + dx
	pz = pz + dz
end

for n = 1, depth do
	digDown()
end

for m = 1, length do
	digForward()
end

turnAround()

while (px > 0) do
	digForward()
end

while (py < 0) do
	digUp()
end

print("End of program.")

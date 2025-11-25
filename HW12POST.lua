local function refuel()
	turtle.select(1)
	turtle.refuel(32)
end

-- Extract color from block name
local function getColor(blockName)
	if string.find(blockName, "green") then
		return "green"
	elseif string.find(blockName, "blue") then
		return "blue"
	elseif string.find(blockName, "red") then
		return "red"
	elseif string.find(blockName, "yellow") then
		return "yellow"
	elseif string.find(blockName, "white") then
		return "white"
	elseif string.find(blockName, "black") then
		return "black"
	elseif string.find(blockName, "orange") then
		return "orange"
	elseif string.find(blockName, "purple") then
		return "purple"
	elseif string.find(blockName, "pink") then
		return "pink"
	elseif string.find(blockName, "brown") then
		return "brown"
	elseif string.find(blockName, "gray") or string.find(blockName, "grey") then
		return "gray"
	elseif string.find(blockName, "lime") then
		return "lime"
	elseif string.find(blockName, "cyan") then
		return "cyan"
	elseif string.find(blockName, "light_blue") then
		return "light_blue"
	elseif string.find(blockName, "magenta") then
		return "magenta"
	else
		return "unknown"
	end
end

-- Scan one row of the 5x5 grid
local function ScanRow(rowIndex)
	print("Scanning row " .. rowIndex)
	
	for col = 1, 5 do
		local ok, data = turtle.inspectDown()
		if ok then
			print("Block at (" .. col .. "," .. rowIndex .. "): " .. data.name)
			local color = getColor(data.name)
			http.post("https://cedar.fogcloud.org/api/logs/5E0F", "line=" .. color)
		else
			print("No block detected at (" .. col .. "," .. rowIndex .. ")")
			http.post("https://cedar.fogcloud.org/api/logs/5E0F", "line=air")
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

print("Starting 5x5 grid scan...")

-- Scan all 5 rows
for row = 1, 5 do
	ScanRow(row)
	
	-- Move to next row unless we're done
	if row < 5 then
		turtle.turnLeft()
		turtle.forward()
		turtle.turnRight()
	end
end

print("Grid scan complete!")

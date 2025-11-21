local lines = {}
for line in content:gmatch("[^\r\n]+") do
	table.insert(lines, line)
end

print("Image size: " .. #lines[1] .. "x" .. #lines)

local function refuel()
	turtle.select(1)
	turtle.refuel(32)
end

-- Scan one row of the image
local function ScanRow(rowData, rowIndex)
	print("Scanning row " .. rowIndex)
	if rowIndex > 1 then
		turtle.turnLeft()
		turtle.forward()
		turtle.turnRight()
	end
	
	for i = 1, #rowData do
	    ok, data = turtle.inspectDown()
	    if ok then
 	    print(data.name)
            end
            
            if data.name == "minecraft:green_wool" then
                http.post("https://cedar.fogcloud.org/api/logs/41A0", "line=green")
            end
            
            if data.name == "minecraft:blue_wool" then
                http.post("https://cedar.fogcloud.org/api/logs/41A0", "line=blue")
            end
            
            if data.name == "minecraft:red_wool" then
                http.post("https://cedar.fogcloud.org/api/logs/41A0", "line=red")
            end
            
            if i < #rowData then
	        turtle.forward()
	    end
	    
	end
	
	for i = 1, #rowData - 1 do
		turtle.back()
	end

end

for i, line in ipairs(lines) do
	ScanRow(line, i)
end

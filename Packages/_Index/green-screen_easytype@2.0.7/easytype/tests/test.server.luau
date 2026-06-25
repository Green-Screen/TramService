local EasyTypeV2 = require("../")

local Object = setmetatable({}, {
	__index = {
	ClassName = "Test"	
		
	}
})

-- Returns string
print(EasyTypeV2("Value"))

-- returns cframe
print(EasyTypeV2(CFrame.new()))

-- returns classname and type of object
print(EasyTypeV2(Object))

-- returns table
print(EasyTypeV2({"value", "value2", "value3"}))

-- Returns Instance type
print(EasyTypeV2(workspace))

-- Returns the classname of instance 'workspace'
print(EasyTypeV2(workspace, true))
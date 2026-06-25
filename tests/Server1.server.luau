--!strict

local TramService = require("../")

local R1 = TramService.NewTram("Test3", true) 
local R2 = TramService.NewTram("Test3", true)

R1:Connect(function(S: string)
	return S, S:byte()
end)

print(R1:Fire("Hi"))


task.spawn(function()
	--R1:Wait()
end)

print(getmetatable(R1), getmetatable(R2))

task.wait(1)

R1:Connect(function(S: string)
	coroutine.yield()
	return S:byte()
end)

--print(R1:Fire("Bye")) -- Timeout

TramService.Print()

print(R2.LocallyConnected, R1.LocallyConnected, R2:HasAGlobalConnectedUnit())

print(getmetatable(R1), getmetatable(R2))

--R2:DisconnectAll()

--print(R1:Fire("64")) -- error

R2:Destroy(true)

TramService.Print()
print(getmetatable(R1), getmetatable(R2))
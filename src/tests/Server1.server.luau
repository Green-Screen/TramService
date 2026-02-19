--!strict

local TramService = require("../")
local EasyType = require("../Dependencies/EasyType")

task.wait(5)
print("Finished loading")

local SqrtEvent = TramService.NewTram("SqrRT") :: TramService.Tram<number>
local ExponentEvent = TramService.NewTram("Exponent") :: TramService.Tram<number, number>

--print(SqrtEvent:Fire(coroutine.yield()))
print(ExponentEvent:Fire(20, 2))

local RespondHello = TramService.NewTram("Hello") :: TramService.Tram<string?>

-- Bad example dont do this unless you want a stack overflow
RespondHello:Connect(function(a0: string?)
	print("Hello on Server1", a0)
	return RespondHello:Fire("Hello server2")
end)

-- Will only print 2 and 3 as responseTest1 will be overwritten
local ResponseTest1 = TramService.NewTram("CallMe")
local ResponseTest2 = TramService.NewTram("CallMe")

ResponseTest1:Connect(function(...)
	print("response 1")
end)

ResponseTest2:Connect(function(...)
	print("response 2")
end)

ResponseTest1:Connect(function(...)
	print("response 3")
end)

-- Tram, ID, CallMe
print(EasyType(ResponseTest1), ResponseTest1.BindID, ResponseTest1.TraversableID)

-- Will only print 2 as ResponseTest1 is now disconnected
ResponseTest1:Disconnect()

task.wait(3)

local ControlThread: TramService.Tram<boolean> = TramService.NewTram("Control") -- Dont need to specify properties because tram has already been created in Server2

ResponseTest1:Connect(function(...)
	print("Hello1")
end)

ResponseTest2:Connect(function(Header: string, Time: DateTime)
	print("Hello2 with data", Header, Time:FormatUniversalTime("LL", "en-us"))
end)

print("Set up finished unyielding control thread")

print("-----------------------------------") -- Create space

-- all functions will run before being returned
print("Has control thread been resumed:", ControlThread:Fire(true))

local Multi2 = TramService.NewTram("MultiBind")
local Multi3 = TramService.NewTram("MultiBind")
local Multi1 = TramService.NewTram("MultiBind")

Multi1:Connect(function(...)
	print("Hi")
end)
Multi2:Connect(function(...)
	print("Hi")
end)
Multi3:Connect(function(...)
	print("Hi")
end)

Multi1:DestroyLocal()

print(Multi1, Multi2, Multi3)

Multi1 = TramService.NewTram("MultiBind")

warn(Multi1)

Multi1:Connect(function(...)
	print("Hi")
end)

print(Multi1, Multi2, Multi3)

TramService.NewTram("Wait"):Wait()

local Test1 = TramService.NewTram("Test")
local Test2 = TramService.NewTram("Test")
local Test3 = TramService.NewTram("Test")

Test1:Connect(function(...)
	print("Ran")
end)
Test2:Connect(function(...)
	print("Ran")
end)
Test3:Connect(function(...)
	print("Ran")
end)

Test1:Wait()

Test1:DestroyLocal()

print(Test1, TramService.PrintCache())

print(Test3:DestroyGlobal())
print(Test2.Destroyed, TramService.PrintCache())
--Test3:Fire()
--Test2:Fire()

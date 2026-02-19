--!strict

local TramService = require("../")

local TestFunctionExponent = TramService.NewTram(nil, true)
local TestFunctionSqrRT = TramService.NewTram("SqrRT", true) :: TramService.Tram<number>

-- warns 'no function binded'
TestFunctionExponent:Fire(3, 3)

TestFunctionExponent:Connect(function(a0: number, a1: number)
	return a0 ^ a1
end)

-- Timeout default of 5 seconds
local function SqrRT(a0: number)
	task.wait(6)
	return math.sqrt(a0)
end

-- Times out
TestFunctionSqrRT:Connect(SqrRT)

print(TestFunctionSqrRT:Fire(20))

-- Cannot yield functions
--TestFunctionExponent:Wait()

local TestHello = TramService.NewTram("Hello") :: TramService.Tram<string?>

TestHello:Connect(function(a0: string?)
	print("Signal responded with:", a0)
end)

task.wait(1)

-- creates a stack overflow because of response function
--TestHello:Fire("Hello server 1")

local Trigger = TramService.NewTram("CallMe") :: TramService.Tram<any, any>
local ControlThread: TramService.Tram<boolean> = TramService.NewTram("Control", true, 1)

print("Fired")
Trigger:Fire()

task.wait(1)

print("Fired2")
Trigger:Fire()

-- Connects callback to function
ControlThread:Connect(function(ShouldResume: boolean)
	if ShouldResume then
		-- Recasts to fit data being sent and sending a string + datetime.now: DateTime
		(Trigger :: TramService.Tram<string, DateTime>):Fire("Current date is", DateTime.now())
		return true -- Returns if it was successful
	else
		return false
	end
end)

-- Trigger is forced to wait until called
Trigger:Wait()

warn("UnPaused")

task.wait(1)
print("------------------------------") -- Create space

local UnbindAllTest = TramService.NewTram("MultiBind")

UnbindAllTest:Fire()

--UnbindAllTest:DisconnectAll()

--UnbindAllTest:Fire()

task.wait(0.5)

UnbindAllTest:Fire()

task.wait(0.5)

UnbindAllTest:Fire()

task.wait(0.5)

UnbindAllTest:Fire()

TramService.NewTram("Wait"):Fire()

task.wait(1)
print("-----------------------------------------------------")
local Temp = TramService.NewTram("Test")
warn("First")
Temp:Fire()

task.wait(5)
print("Starting Destroy Test")
print("-----------------------------------------------------")

local Destroy1 = TramService.NewTram("DestroyTest")
local Destroy2 = TramService.NewTram("DestroyTest")
local Destroy3 = TramService.NewTram("DestroyTest")
local Destroy4 = TramService.NewTram("DestroyTest")

Destroy1:Connect(function(...)
	print("Destroy1")
end)
Destroy2:Connect(function(...)
	print("Destroy2")
end)
Destroy3:Connect(function(...)
	print("Destroy3")
end)
Destroy4:Connect(function(...)
	print("Destroy4")
end)

-- Test all
Destroy1:Fire()

print("-----------------------------------------------------")

Destroy2:DestroyLocal()

Destroy1:Fire()

print("-----------------------------------------------------")

local Destroy5 = TramService.NewTram("DestroyTest")

Destroy5:Connect(function(...)
	print("Destroy5")
end)

Destroy1:Fire()

print("-----------------------------------------------------")

Destroy5:DestroyGlobal()

Destroy1:Fire()

print("-----------------------------------------------------")

print(TramService.PrintCache())

print("-----------------------------------------------------")
task.wait(1)

local NoIDTest1 = TramService.NewTram()
local NoIDTest2 = TramService.NewTram()

task.spawn(function()
	NoIDTest2:Wait()
end)

print(NoIDTest1)
print(NoIDTest2)

NoIDTest1:DestroyGlobal()

print(NoIDTest1)

NoIDTest2:DestroyLocal()

local TramService = require("../")
local Log = require("../../Log")

local Display = Log.Display

local Header = "TramService_Tests"

local Event1 = TramService.NewTram("TestEvent")
local Event2 = TramService.NewTram("TestEvent") 

local NonTrackedEvent = TramService.NewTram()

--[[Display(
	"Log",
	{
		Event1 = Event1.BindID,
		Event2 = Event2.BindID,
		NonTrackedEvent = NonTrackedEvent.BindID,
	},
	"Events Created:\nEvent1:{Event1}\nEvent2:{Event2}\nEvent3:{Event3}\nEvent4:{Event4}\nEvent5:{Event5}\nNonTrackedEvent:{NonTrackedEvent}\n",
	Header
)]]

local T = coroutine.wrap(function(...)
	while true do
		print("Prime")
		Event2:Wait()
		print("Ran")
		coroutine.yield()
	end
end)

T()

warn(Event2.LocallyYielding, Event2:HasAGlobalYieldingUnit())
Event1:Fire()
warn(Event2.LocallyYielding, Event2:HasAGlobalYieldingUnit())

task.wait(1)
TramService.Print()

T()
warn(Event2.LocallyYielding, Event2:HasAGlobalYieldingUnit())
Event1:Fire()
warn(Event2.LocallyYielding, Event2:HasAGlobalYieldingUnit())
T()

task.wait()
--NonTrackedEvent:Fire()
warn(Event1.LocallyYielding)
Event2:Fire()
--print(NonTrackedEvent)
task.wait()
warn(Event1.LocallyYielding)
Display("Info", {}, "Destroying all ", Header)

Event2:Connect(function(): ...any?
	Event2:Wait()
end)

task.spawn(function()
    NonTrackedEvent:Wait()
end)

task.wait(1)
--NonTrackedEvent:Destroy()
Event2:Fire()

print(Event2.LocallyConnected, Event2.BindID, Event2:HasAGlobalConnectedUnit())
Event1:DisconnectAll()

TramService.Print()
print(Event1.LocallyConnected, Event2.LocallyConnected, Event1:HasAGlobalConnectedUnit())

warn("-----------------------")

Event1:Connect(function(...): ...any?
	
end)

TramService.Print()
--print(Event3, getmetatable(Event3), Event2, getmetatable(Event2))

print(Event2.LocallyConnected)

Event2:Destroy(true)

warn("-----------------------")
print(Event1, getmetatable(Event1))
print(Event2, getmetatable(Event2))

TramService.Print()

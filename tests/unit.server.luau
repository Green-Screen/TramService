local TramService = require("../")
local EasyType = require("../../EasyType")
local Logger = require("../../Log")

local StartTest = Logger.BeginTest
local CompleteTest = Logger.FinishTest

local Static1 = TramService.NewTram()

StartTest("Bind_Static_Tram")
CompleteTest("Bind_Static_Tram", pcall(Static1.Connect, Static1, function(...) return print(...) end))

StartTest("Fire_Static_Tram")
CompleteTest("Fire_Static_Tram", pcall(Static1.Fire, Static1, "Hello"))

StartTest("1000_Triggers")
for i = 1, 1000 do
    Static1:Fire(i)
end
CompleteTest("1000_Triggers", true, "Fired 1000 events", nil, "Error")
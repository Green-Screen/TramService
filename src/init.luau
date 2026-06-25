-- TramService V 3.0.0
-- @Patriots8800
-- Documentation https://example.com

--!strict
----------------------------------------------------------------------------------------------

-- 							[[ Dependencies ]]

local Log = require("./Log")
local SecureClasses = require("./SecureClasses")
local SmartTable = require("./SmartTable")

----------------------------------------------------------------------------------------------

-- 							[[ Types ]]
-- Main type

export type Tram<P...> = SecureClasses.WrappedMetatable<{
	ClassName: string,

	TraversableID: string | "NonTranversable",
	BindID: string,

	LocallyConnected: boolean,
	LocallyYielding: boolean,

	Connect: (self: Tram<P...>, (P...) -> ...any?) -> (),
	Fire: (self: Tram<P...>, P...) -> (),
	Wait: (self: Tram<P...>) -> P...,
	DisconnectLocal: (self: Tram<P...>) -> (),
	DisconnectAll: (self: Tram<P...>) -> (),

	HasAGlobalConnectedUnit: (self: Tram<P...>) -> boolean,
	HasAGlobalYieldingUnit: (self: Tram<P...>) -> boolean,
}>

type ITram<P...> = SecureClasses.WrappedMetatable<{
	__index: ITram<P...>,
	__destroy: () -> (),
	__typeKey: string,
	ClassName: string,

	TraversableID: string | "NonTranversable",
	BindID: string, -- local

	Callback: boolean,

	LocallyConnected: boolean,
	LocallyYielding: boolean,

	_FunctionsBinded: ({ [string]: GenericFunction<P...> } | GenericFunction<P...>)?,
	_YeildingThreads: { [string]: thread },
	_Timeout: number,
	_IsModuleEvent: boolean,

	Fire: (self: ITram<P...>, P...) -> (),
	Wait: (self: ITram<P...>) -> P...,
	DisconnectLocal: (self: ITram<P...>) -> (),
	Connect: (self: ITram<P...>, (P...) -> ...any?) -> (),
	DisconnectAll: (self: ITram<P...>) -> (),

	HasAGlobalConnectedUnit: (self: ITram<P...>) -> boolean,
	HasAGlobalYieldingUnit: (self: ITram<P...>) -> boolean,
}>

type GenericFunction<P..., R...> = (P...) -> R...

type Settings = {
	["Callback"]: boolean?,
	["_Timeout"]: number,
	["_IsModuleEvent"]: boolean?,
}

type TramCache<I> = {
	[I]: {
		FunctionsBinded: { [I]: GenericFunction<...any, ...any> },
		YieldingThreads: { [I]: thread },
		Trams: { [I]: ITram<> },

		Settings: Settings,
	},
}

-- 					[[Specialized tram types]]

-- ALL tram types are a Tram type but the different types are for editing the auto complete for certain uses.
-- Ie. Modules using this as events, certain events, Only fire or only receive.

-- The only difference is for autocomplete/intellisense everything is a tram type

---------------------------------------

export type TramConnectOnly<P...> = {

	Connect: (self: TramConnectOnly<P...>, (P...) -> ...any?) -> (),
	Wait: (self: TramConnectOnly<P...>) -> P...,

	DestroyLocal: (self: TramConnectOnly<P...>) -> nil,
	DestroyGlobal: (self: TramConnectOnly<P...>) -> nil,
}

export type TramDisconnectOnly<P...> = {

	Disconnect: (self: TramDisconnectOnly<P...>) -> (),
	DisconnectAll: (self: TramDisconnectOnly<P...>) -> (),

	DestroyLocal: (self: TramDisconnectOnly<P...>) -> nil,
	DestroyGlobal: (self: TramDisconnectOnly<P...>) -> nil,
}

export type ModuleEvent<P...> = {

	Connect: (self: ModuleEvent<P...>, (P...) -> ...any?) -> (),
	Wait: (self: ModuleEvent<P...>) -> P...,

	Disconnect: (self: ModuleEvent<P...>) -> (),
	DisconnectAll: (self: ModuleEvent<P...>) -> (),

	DestroyLocal: (self: ModuleEvent<P...>) -> nil,
	DestroyGlobal: (self: ModuleEvent<P...>) -> nil,
}

export type OnlySignaling<P...> = {

	Fire: (self: OnlySignaling<P...>, P...) -> (),

	DestroyLocal: (self: OnlySignaling<P...>) -> nil,
	DestroyGlobal: (self: OnlySignaling<P...>) -> nil,
}

----------------------------------------------------------------------------------------------

-- 							[[ Service Header ]]

local SERVICE_NAME = "TramService"

----------------------------------------------------------------------------------------------

-- 							[[ Private functions (helpers) ]]

local indexKey = game:GetService("HttpService"):GenerateGUID()
local Display = Log.Display
local LevelAssert = Log.Assert
local TypeCheck = Log.TypeCheck

local NonTraversableTag, CallbackTag = "NonTraversable", "Callback"

-- 							[[ Thread caching ]]

local ThreadCache: { thread } = {}

-- Runs the yielded function then resets it
local function Run<T..., V...>(FN: (T...) -> V..., Thread: thread, ...: T...)
	FN(...)

	table.insert(ThreadCache, Thread)
	Run(coroutine.yield())
end

-- Creates a thread then yields it and allows you to "inject a function into it"
local function PrimeThread(): thread
	local function Prime()
		return Run(coroutine.yield())
	end

	return task.spawn(Prime)
end

-- Runs the function pased on the cashed thread
local function RunCachedThread<T..., V...>(FN: (T...) -> V..., ...: T...)
	local Thread: thread

	if ThreadCache[1] then
		Thread = ThreadCache[math.min(1, #ThreadCache)]
		ThreadCache[#ThreadCache] = nil
	else
		Thread = PrimeThread()
	end

	if coroutine.status(Thread) ~= "suspended" then
		Display("Emphasize", {}, "Junk thread found removing from cache", SERVICE_NAME)
		return RunCachedThread(FN)
	end

	task.spawn(Thread, FN, Thread, ...)
end

type S = any

-- Adds a timeout to callback functions
local function Timeout<T..., V...>(Time: number, FN: (T...) -> V..., ...: T...): (boolean, V...)
	local Returned, Return, RunThread
	local Start = os.clock()

	Time = math.clamp(Time, 1, 20)
	RunThread = task.spawn(function(...)
		Return = { FN(...) }
		Returned = true
	end, ...)
	repeat
		task.wait()
	until Returned or os.clock() - Start > Time

	task.cancel(RunThread)

	if not Returned then
		Display("Emphasize", { Time = Time }, "Function callback exhausted limit of {Time} seconds", SERVICE_NAME)
	end
	return not Returned, table.unpack((Return or {}) :: { any })
end

local TramCache: TramCache<string> = {}

local function CacheCreator(ID: string, Settings: Settings)
	local Tram = TramCache[ID]
	if Tram then
		return Tram
	end
	local self = {}

	self.FunctionsBinded = {}
	self.YieldingThreads = {}
	self.Trams = {}

	self.Settings = Settings

	TramCache[ID] = self
	return self
end

----------------------------------------------------------------------------------------------
--					 		[[ MetaData (MetaTable) ]]

local Tram = {}
Tram.__typeKey = indexKey
Tram.__destroy = function(self: ITram<>, Global: boolean?)
	local function DestroyYieldAndConnection()
		if self.LocallyConnected then
			self:DisconnectLocal()
		end
		if self.LocallyYielding then
			Display(
				"Emphasize",
				{ ID = self.BindID },
				"Destroying Tram: {ID} with yielded threads, this may result in a memory leak",
				SERVICE_NAME
			)
		end
	end

	if self.TraversableID ~= NonTraversableTag then
		local Cache = TramCache[self.TraversableID]

		if Global then
			local ID = self.TraversableID

			for _, T in Cache.Trams do
				T:Destroy(false) -- Destroys ALL objects
			end

			TramCache[ID] = nil
		else
			DestroyYieldAndConnection()

			if self.LocallyYielding then
				Cache.YieldingThreads[self.BindID] = nil -- clearing Yielding threads !!!!!!
			end

			Cache.Trams[self.BindID] = nil
			--Cache = nil
		end
	else
		DestroyYieldAndConnection()
	end
	self._FunctionsBinded = nil
	self._YeildingThreads = nil :: never
end

Tram.ClassName = "Tram"

-- Connect a function to the tram
function Tram:Connect<P...>(fn: GenericFunction<P...>): ()
	TypeCheck(fn, 1, false, 3, false, "function")

	local FunctionsBinded = ((self :: any)[indexKey] :: ITram<any>)._FunctionsBinded;

	((self :: any)[indexKey] :: ITram<any>).LocallyConnected = true

	if self.Callback then
		(FunctionsBinded :: { [string]: GenericFunction<P...> })[CallbackTag] = fn
	else
		(FunctionsBinded :: { [string]: GenericFunction<P...> })[self.BindID] = fn
	end
end

-- Handles the data sent in a optimized threaded capacity
function Tram:Fire<P...>(...: P...): any
	self = self :: ITram<P...>

	local FunctionsBinded = ((self :: any)[indexKey] :: ITram<any>)._FunctionsBinded
	local TOut = ((self :: any)[indexKey] :: ITram<any>)._Timeout
	local IsModuleEvent = ((self :: any)[indexKey] :: ITram<any>)._IsModuleEvent
	local YieldingThreads = ((self :: any)[indexKey] :: ITram<any>)._YeildingThreads

	if self.Callback then
		if not next(FunctionsBinded :: { [string]: GenericFunction<...any> }) then
			if not IsModuleEvent then
				return Display(
					"Emphasize",
					{ Name = self.TraversableID },
					"Attempt to fire Event: {Name} with no function binded",
					SERVICE_NAME
				)
			end
			return
		end

		return Timeout(TOut, (FunctionsBinded :: any)[CallbackTag] :: GenericFunction<P...>, ...)
	else
		if not next(FunctionsBinded :: { GenericFunction<P...> }) and not next(YieldingThreads) then
			if not IsModuleEvent then
				return Display(
					"Emphasize",
					{ Name = self.TraversableID },
					"Attempt to fire Event: {Name} with no function binded or threads yielding",
					SERVICE_NAME
				)
			end
			return
		end

		for ID, Thread in YieldingThreads do
			YieldingThreads[ID] = nil
			TramCache[self.TraversableID].Trams[ID][indexKey].LocallyYielding = false
			task.spawn(Thread, ...)
		end
		-- ((self :: any)[indexKey] :: ITram<any>).LocallyYielding = false

		for _, Func in FunctionsBinded :: { [string]: GenericFunction<P...> } do
			RunCachedThread(Func, ...)
		end
	end

	return
end

-- Yields the main thread until :Fire() is called and resumes it
function Tram:Wait<T...>(): T...
	local YieldingThreads = ((self :: any)[indexKey] :: ITram<any>)._YeildingThreads

	LevelAssert(not self.Callback, "Attempt to yield callback function, cannot yield callbacks", 3, SERVICE_NAME)
	LevelAssert(not self.LocallyYielding, "Attempt to yield thread that is already yielding", 3, SERVICE_NAME);

	((self :: any)[indexKey] :: ITram<any>).LocallyYielding = true

	YieldingThreads[self.BindID] = coroutine.running()

	return coroutine.yield()
end

-- Disconnects a function from the tram
function Tram:DisconnectLocal(): ()
	local FunctionsBinded = ((self :: any)[indexKey] :: ITram<any>)._FunctionsBinded

	if not self.LocallyConnected then
		Display(
			"Error",
			{ ID = self.BindID },
			"Attempt to disconnect Event: {ID}, No function binded",
			SERVICE_NAME,
			true,
			4
		)
	end

	if self.Callback then
		(FunctionsBinded :: any)[CallbackTag] = nil
	else
		(FunctionsBinded :: { [string]: GenericFunction<...any, ...any> })[self.BindID] = nil
	end

	if not next(FunctionsBinded :: { [string]: GenericFunction<...any, ...any> }) then
		((self :: any)[indexKey] :: ITram<any>).LocallyConnected = false
	end
end

-- Disconnects all function connected to the TraversableID
function Tram:DisconnectAll(): ()
	self = self :: ITram<...any>

	if not self:HasAGlobalConnectedUnit() then
		Display(
			"Error",
			{ ID = self.BindID },
			"Attempt to disconnect Event: {ID}, No function binded",
			SERVICE_NAME,
			true,
			4
		)
	end

	if self.Callback and self.TraversableID == NonTraversableTag then
		self:DisconnectLocal()
	else
		for _, v in TramCache[(self :: Tram<...any>).TraversableID].Trams do
			if v.LocallyConnected then
				v:DisconnectLocal()
			end
		end
		--table.clear(FunctionsBinded :: { [string]: GenericFunction<...any, ...any> })
	end
end

function Tram:HasAGlobalConnectedUnit(): boolean
	local FunctionsBinded = ((self :: any)[indexKey] :: ITram<any>)._FunctionsBinded

	if self.Callback then
		return (FunctionsBinded :: any)[CallbackTag] ~= nil
	else
		return next(TramCache[(self :: ITram<...any>).TraversableID].FunctionsBinded) ~= nil
	end
end

function Tram:HasAGlobalYieldingUnit(): boolean
	if self.Callback then
		return false -- Callback functions cannot call :Wait nor yield longer then the time limit
	else
		return next(TramCache[(self :: ITram<...any>).TraversableID].YieldingThreads) ~= nil
	end
end

----------------------------------------------------------------------------------------------
--					 		[[ Public service (constructor) ]]

local TramService = {}

function TramService.NewTram<P...>(
	TraversableID: string?,
	Function: boolean?, -- Params
	Timeout: number?,
	IsModuleEvent: boolean?
): Tram<...any>
	TypeCheck(TraversableID, 1, true, 3, false, "string")
	TypeCheck(Function, 2, true, 3, false, "boolean")
	TypeCheck(Timeout, 3, true, 3, false, "number")
	TypeCheck(IsModuleEvent, 4, true, 3, false, "boolean")

	local self = {}

	if TraversableID then
		local CachedTram: any = TramCache[TraversableID]
		if not CachedTram then
			CachedTram = CacheCreator(TraversableID, {
				["Callback"] = Function or false,
				["_IsModuleEvent"] = IsModuleEvent or false,
				["_Timeout"] = Timeout or 5,
			})
		end

		self.TraversableID = TraversableID

		self.Callback = CachedTram.Settings.Callback
		self._IsModuleEvent = CachedTram.Settings._IsModuleEvent
		self._Timeout = CachedTram.Settings._Timeout
		self._FunctionsBinded = CachedTram.FunctionsBinded
		self._YeildingThreads = CachedTram.YieldingThreads
	else
		self.TraversableID = NonTraversableTag

		self.Callback = Function or false
		self._IsModuleEvent = IsModuleEvent or false
		self._Timeout = Timeout or 5
		self._FunctionsBinded = {}
		self._YeildingThreads = {}
	end

	self.BindID = SmartTable.Helper.GenerateUUID()
	self.LocallyConnected = false
	self.LocallyYielding = false

	local T = SecureClasses(self, Tram, Tram.ClassName) :: ITram<P...>

	if self.TraversableID ~= NonTraversableTag then
		TramCache[self.TraversableID].Trams[self.BindID] = T :: any
	end

	return T :: Tram<...any>
end

return TramService
----------------------------------------------------------------------------------------------

-- Tags: https://eryn.io/moonwave/docs/TagList/

--[=[ 
    @class TEMPLATECLASS
    A class template
]=]

--[=[
    @within TEMPLATECLASS
    @type TEMPLATETYPE Test

    Template type
]=]

--[=[
    @within TEMPLATECLASS
    @interface TEMPLATEINTERFACE

    .T1 TEMPLATETYPE
    .T2 TEMPLATETYPE
    .T3 TEMPLATETYPE

    Template type
]=]

--[=[
    @within TEMPLATECLASS
    @function TEMPLATEFUNCTION

    @param T1 TEMPLATETYPE
    @return TEMPLATEINTERFACE

    Template type

]=]

--[=[
    @within TEMPLATECLASS
    @method TEMPLATEMETHOD

    @param T1 TEMPLATETYPE
    @return TEMPLATEINTERFACE

    Template type

    :::tip
        Tip Container
    :::
    :::info
        info Container
    :::
    :::caution
        caution Container
    :::
    :::danger
        danger Container
    :::

    | Head1 | Head2 | Head3 |
    |-------|-------|-------|
    | Prop1 | Prop2 | Prop3 |
]=]

--[=[
    @within TEMPLATECLASS
    
    @prop TEMPLATEPROPERTY1 boolean

]=]

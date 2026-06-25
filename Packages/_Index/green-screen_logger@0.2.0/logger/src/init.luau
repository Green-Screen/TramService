-- Logger v 0.1.0
-- @patriots8800

--!nolint ImplicitReturn
--!strict
local LogService = game:GetService("LogService")

local SERVICE_NAME = "Logger"

local NewLine = utf8.char(0x0A) -- \n
--local Format = ("[%s]: :: %s :: | %s | :: Data ")
local Seperator = " :: "
local ConcatSep = " | "

local Levels = {
	["Emphasize"] = Enum.MessageType.MessageWarning,
	["Log"] = Enum.MessageType.MessageOutput,
	["Info"] = Enum.MessageType.MessageInfo,
	["Error"] = Enum.MessageType.MessageError,
}

type ContextLevels = keyof<typeof(Levels)>

type Trace = {
	-- Instance: Instance, LogService error
	Path: string,
	LineCalled: number,
	FunctionCalled: string,
	Address: string,
	CalledThread: string, -- thread
	TimeStamp: number,
}

local function FormatTable<v>(T: { v }): string
	local msg = ""
	for i = 1, #T do
		local Val = T[i]
		if Val then
			msg ..= tostring(Val)
		end

		if i < #T then
			msg ..= ConcatSep
		end
	end
	return msg
end

local function TypeCheck(
	Passed: any,
	ArgNum: number,
	OrNil: boolean?,
	level: number?,
	StringLiterals: boolean?,
	...: string
)
	local P = typeof(Passed)

	if P ~= ... then
		if Passed == nil and OrNil then
			return
		end

		local Packed = table.pack(...)

		if P == "string" and StringLiterals then
			if Packed.n > 1 then
				for _, v: string in ipairs(Packed) do
					if (Passed :: string) == v then
						return
					end
				end
			end
		end

		local Given, Expected

		if StringLiterals then
			Given = P
			Expected = FormatTable(Packed)
		else
			Given = P
			Expected = ...
		end

		return error(
			("TYPECHECK@Argument #%d expected [%s] got [%s]")
				:format(ArgNum, if OrNil then Expected .. ConcatSep .. "Null" else Expected, Given)
				:gsub("@", Seperator),
			level or 2
		) :: any
	end

	--[[if P ~= ... or (P == nil and OrNil) then
		local Packed = table.pack(...)
		if P == "string" and Packed.n > 1 then
			--Packed.n = nil :: never
			--P = Passed

			for _, v: string in ipairs(Packed) do
				if (Passed :: string) == v then
					return
				end
			end
		end

		local Given: string, Expected: string

		if StringLiterals then
			Packed.n = nil :: never

			Expected = table.concat(Packed, "|")
			Given = if P ~= "string" then P :: any else Passed
		else
			Given = Passed
			Expected = ...
		end

		if Packed.n then
			warn(("%s Malformed result: Literals not supported in current state"):format(SERVICE_NAME))
		end

		return error(
			("%s Argument #%d expected [%s] got [%s]"):format(Source or SERVICE_NAME, ArgNum, Expected, Given),
			level or 2
		) :: any
	end]]
end

local function GetInstanceFromGamePath(Path: string): Instance?
	local I: Instance = game
	for _, S: string in Path:split(".") do
		if I:FindFirstChild(S) then
			I = I:FindFirstChild(S) :: Instance
		else
			return nil
		end
	end
	return I
end

local function GenerateTrace(Level: number?): Trace
	local Path: string, Line: number, Name: string, Address: string = debug.info(Level or 3, "slnf")
	local Trace = {}

	--Trace.Instance = GetInstanceFromGamePath(Path)
	Trace.Path = Path
	Trace.LineCalled = Line
	Trace.FunctionCalled = if Name == "" then "Script" else Name
	Trace.Address = tostring(Address)
	Trace.CalledThread = tostring(coroutine.running())
	Trace.TimeStamp = os.clock()

	return Trace
end

local function Display(
	Context: ContextLevels,
	Data: { [string]: any },
	CustomMessage: string?,
	Source: string?,
	Trace: boolean?,
	Level: number?
)
	TypeCheck(Context, 1, false, 3, true, "Emphasize", "Log", "Info", "Error") -- context
	TypeCheck(Data, 2, false, 3, false, "table") -- data
	TypeCheck(CustomMessage, 3, true, 3, false, "string") -- CustomMessage
	TypeCheck(Source, 4, true, 3, false, "string") -- Source
	TypeCheck(Trace, 5, true, 3, false, "boolean") -- Trace

	local msg = ("[%s]:@%s@%s@Data@")
		:format(Source or SERVICE_NAME, Context:upper(), CustomMessage or "")
		:gsub("@", Seperator)

	if Context == "Error" or Trace then
		Data._Trace = GenerateTrace(Level)
	end

	-- pcalled for error
	--pcall(LogService.Log, LogService, Levels[Context] :: Enum.MessageType, msg, Data)

	LogService:Log(Levels[Context], msg, Data)
	return Data._Trace
end

local function levelAssert(Condition: boolean?, msg: string, level: number?, Source: string?): ()
	TypeCheck(Condition, 1, true, 3, false, "boolean")
	TypeCheck(msg, 2, false, 3, false, "string")
	TypeCheck(level, 3, true, 3, false, "number")
	TypeCheck(Source, 4, true, 3, false, "string")

	if Condition == false or Condition == nil then
		return error(
			("[%s]:@%s@%s"):format(Source or SERVICE_NAME, "ASSERT", msg):gsub("@", Seperator),
			if level and level > 1 then level else 0
		) :: any
	end
end

local Tests: { [string]: number? } = {}

local function BeginTest(
	ID: string,
	Log: boolean?,
	BeginningMessage: string?,
	Data: { [string]: any }?,
	MessageVerbosity: ContextLevels?
)
	TypeCheck(ID, 1, false, 3, false, "string")
	TypeCheck(Log, 2, true, 3, false, "boolean")
	TypeCheck(BeginningMessage, 3, true, 3, false, "string")
	TypeCheck(Data, 4, true, 3, false, "table")
	TypeCheck(MessageVerbosity, 5, true, 3, true, "Emphasize", "Log", "Info", "Error")

	levelAssert(not Tests[ID], `Test: {ID} has already been started`, 3, nil)

	Tests[ID] = os.clock()

	if Log then
		pcall(
			LogService.Log,
			LogService,
			Levels[MessageVerbosity :: any] or Levels.Info,
			("[TESTS]: %s@BEGINNING@%s@DATA@"):format(ID, BeginningMessage or ""):gsub("@", Seperator),
			Data
		)
	end
end

local function FinishTest(
	ID: string,
	Status: boolean?,
	CompletionMessage: string?,
	Data: { [string]: any }?,
	MessageVerbosity: ContextLevels?
)
	TypeCheck(ID, 1, false, 3, false, "string")
	TypeCheck(Status, 2, true, 3, false, "boolean")
	TypeCheck(CompletionMessage, 3, true, 3, false, "string")
	TypeCheck(Data, 4, true, 3, false, "table")
	TypeCheck(MessageVerbosity, 5, true, 3, true, "Emphasize", "Log", "Info", "Error")

	levelAssert(Tests[ID] ~= nil, `Test: {ID} has not been started`, 3, nil)

	local MSG = ("[TESTS]: %s@STATUS: %s@TIME: %.4f(s)@%s@DATA@")
		:format(ID, if Status then "SUCCESS" else "FAILED", os.clock() - (Tests[ID] :: number), CompletionMessage or "")
		:gsub("@", Seperator)

	Tests[ID] = nil

	if Status then
		pcall(LogService.Log, LogService, Levels[MessageVerbosity :: any] or Levels.Info, MSG, Data)
	else
		pcall(LogService.Log, LogService, Levels[MessageVerbosity :: any] or Levels.Emphasize, MSG, Data)
	end
end

return {
	Display = Display :: (
		Context: ContextLevels,
		Data: { [string]: any },
		CustomMessage: string?,
		Source: string?,
		Trace: nil,
		Level: number?
	) -> () & (
		Context: ContextLevels,
		Data: { [string]: any },
		CustomMessage: string?,
		Source: string?,
		Trace: boolean,
		Level: number?
	) -> Trace,

	TypeCheck = TypeCheck,
	Assert = levelAssert,

	BeginTest = BeginTest,
	FinishTest = FinishTest,
}

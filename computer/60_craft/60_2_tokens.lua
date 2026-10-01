function lockOwnerId()
	return coroutine.running() or "main"
end

-- reentrant per coroutine. two passes: check ALL first, THEN bump.
-- one-pass version leaked half a lock and deadlocked. dont undo this
function acquireTokens(tokens)
	local me = lockOwnerId()
	for _, t in ipairs(tokens) do
		local l = Craft.locks[t]
		if l and l.owner ~= me then return false end
	end
	for _, t in ipairs(tokens) do
		local l = Craft.locks[t]
		if l then l.count = l.count + 1
		else Craft.locks[t] = { owner = me, count = 1 } end
	end
	return true
end

function releaseTokens(tokens)
	local me = lockOwnerId()
	for _, t in ipairs(tokens) do
		local l = Craft.locks[t]
		if l and l.owner == me then
			l.count = l.count - 1
			if l.count <= 0 then Craft.locks[t] = nil end
		end
	end
end
sleepCancel = function(t)
	local timer = os.startTimer(t)
	local deadline = os.clock() + t + 0.1
	while true do
		local ev, a, b, c = os.pullEvent()
		if ev == "timer" and a == timer then return end
		if ev == "monitor_touch" and craftCancelY and c == craftCancelY and b >= craftCancelX1 and b <= craftCancelX2 then
			Craft.cancelled = true
			os.cancelTimer(timer)
			return
		end
		if os.clock() >= deadline then os.cancelTimer(timer); return end
	end
end

function groupKeyOf(machineName)
	for _, cg in ipairs(CustomMachineGroups) do
		for _, cm in ipairs(cg.machines) do
			if cm == machineName then return "cg:" .. (cg.name or tostring(cg)) end
		end
	end
	if Machines.excluded(machineName) then return "m:" .. machineName end
	return "g:" .. getMachBase(machineName)
end

function pinnedToken(name)
	if not name or name == "" then return nil end
	for _, cg in ipairs(CustomMachineGroups) do
		for _, cm in ipairs(cg.machines) do
			if cm == name then return "cg:" .. (cg.name or tostring(cg)) end
		end
	end
	if Machines.excluded(name) then return "m:" .. name end
	return "p:" .. name
end

function fluidRecipeTokens(fr)
	local toks = {}
	local seen = {}

	local function add(tok)
		if tok and not seen[tok] then seen[tok] = true; toks[#toks + 1] = tok end
	end
	if fr then
		local anyDev = (fr.output_device and fr.output_device ~= "")
		or (fr.item_input_device and fr.item_input_device ~= "")
		or (fr.fluid_input_device and fr.fluid_input_device ~= "")
		or (fr.item_output_device and fr.item_output_device ~= "")
		if anyDev then
			add(pinnedToken(fr.machine_name))
			add(pinnedToken(fr.output_device))
			add(pinnedToken(fr.item_input_device))
			add(pinnedToken(fr.fluid_input_device))
			add(pinnedToken(fr.item_output_device))
		else
			add(groupKeyOf(fr.machine_name))
		end
	end
	if #toks == 0 then toks[1] = "FLUID" end
	return toks
end

function stepTokens(step)
	if step.fluid_craft then
		return fluidRecipeTokens(step.fluidRecipe)
	end
	if step.type == "turtle" then return { "TURTLE" } end
	-- one physical grid, one craft at a time
	if step.type == "crafter" then return { "CRAFTER" } end
	if step.output_device and step.output_device ~= "" then
		local toks = {}
		local seen = {}

		local function add(tok)
			if tok and not seen[tok] then seen[tok] = true; toks[#toks + 1] = tok end
		end
		add(pinnedToken(step.machine_name))
		add(pinnedToken(step.output_device))
		return toks
	end
	return { groupKeyOf(step.machine_name) }
end

function sleepYield(t, ctx)
	if Craft.cancelled or (ctx and ctx.failed) then sleep(0); return end
	local timer = os.startTimer(t)
	local deadline = os.clock() + t + 0.1
	while true do
		if Craft.cancelled or (ctx and ctx.failed) then os.cancelTimer(timer); return end
		local ev, a = os.pullEvent()
		if ev == "timer" and a == timer then return end
		if os.clock() >= deadline then os.cancelTimer(timer); return end
		if Craft.cancelled or (ctx and ctx.failed) then os.cancelTimer(timer); return end
	end
end


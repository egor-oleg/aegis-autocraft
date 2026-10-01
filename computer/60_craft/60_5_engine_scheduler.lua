-- backed up whole src/ before splitting engine.lua into 3 files.
-- see 'src copy' at repo root if this ever needs rollback

runFluidCraft = function(fplan)
	local toks = fluidRecipeTokens(fplan.recipe)
	local got = false
	local waitN = 0
	-- 90s to grab tokens. longer than that = stuck lock somewhere,
	-- give up, let caller retry
	while true do
		if acquireTokens(toks) then got = true; break end
		if Craft.cancelled then return false, {"Cancelled by user."}, 0 end
		sleepCancel(0.2)
		waitN = waitN + 1
		if waitN > 450 then break end
	end
	-- crude mutex. two crafts raced this once, both saw "1 slot free"
	-- and both grabbed it. lost a whole tank of oil. never again
	while _fluidBusy do
		if Craft.cancelled then
			if got then releaseTokens(toks) end
			return false, {"Cancelled by user."}, 0
		end
		sleepCancel(0.1)
	end
	_fluidBusy = true
	local okStore, storeErr, nOuts = checkOutStore(fplan.recipe)
	if okStore then fluidTankClaims = fluidTankClaims + (nOuts or 0) end
	_fluidBusy = false
	if not okStore then
		if got then releaseTokens(toks) end
		return false, storeErr, 0
	end
	local okR, errR, producedR = fluidCraftInner(fplan)
	fluidTankClaims = math.max(0, fluidTankClaims - (nOuts or 0))
	if got then releaseTokens(toks) end
	return okR, errR, producedR
end

optActive = false
optTimer  = nil
allScanActive  = false


function _execStepFluid(step, ctx, node, finalGoal, sortedStore, myCleanup)
	fluidGoalLabel = finalGoal ~= "" and finalGoal or step.item
	fluidStepNum   = 0
	fluidStepTotal = countTopSteps(step.fluidRecipe, step.item, step.fluidAmount)
	ctx.active[node.idx] = {
		desc = shortName(step.item) .. " (fluid)",
		done = 0, total = step.fluidAmount or 0, machines = 0, topup = false,
	}
	local coF = lockOwnerId()
	local prevEnt = fluidInlineByCo[coF]
	fluidInlineByCo[coF] = { ctx = ctx, node = node.idx }
	local okF, errF = produceFluid(step.fluidRecipe, step.item, step.fluidAmount)
	fluidInlineByCo[coF] = prevEnt
	if displayCtx and displayCtx ~= ctx then
		displayCtx.active["FLUIDNEST:" .. tostring(coF)] = nil
	end
	if not okF then
		craftErrTitle = "! FLUID SUBCRAFT FAILED"
		craftErrLines = errF or {"Unknown error"}
		cleanupCraftMachines(sortedStore, myCleanup)
		return false
	end
	return true
end

function execStep(step, ctx, node)
	local sortedStore = ctx.sortedStore
	local provSrc        = providerSrc()
	local firstStore   = ctx.firstStore
	local finalGoal  = ctx.finalGoal
	local plan           = ctx.plan
	local i              = node.idx
	local w, h           = monitor.getSize()
	local myCleanup      = {}
	local nodeTopup      = false

	local helpers = {}
	helpers.drawProgress = function(stepNum, totalSteps, desc, curCount, maxCount, activeName, workerCount)
		ctx.active[node.idx] = { desc = desc, done = curCount or 0, total = maxCount or 0,
			machines = workerCount or 0, topup = nodeTopup }
		if displayCtx and displayCtx ~= ctx then
			displayCtx.active["NEST:" .. tostring(lockOwnerId())] = {
				desc = desc, done = curCount or 0, total = maxCount or 0,
				machines = workerCount or 0, topup = nodeTopup, nest = true,
			}
		end
	end

	local state = {
		sortedStore = sortedStore, provSrc = provSrc,
		firstStore = firstStore, myCleanup = myCleanup, helpers = helpers,
		plan = plan, i = i, w = w, h = h,
		finalGoal = finalGoal, nodeTopup = nodeTopup, desc = nil,
	}
	if step.count and step.count > 0 then
		local desc = string.format("%d x %s", step.count * (step.output_count or 1), shortName(step.item))
		state.desc = desc
		if step.fluid_craft then
			if not _execStepFluid(step, ctx, node, finalGoal, sortedStore, myCleanup) then return false end
		elseif step.type == "turtle" then
			if not _execStepTurtle(step, ctx, node, state) then return false end
			myCleanup = state.myCleanup
		elseif step.type == "crafter" then
			if not _execStepCrafter(step, ctx, node, state) then return false end
			myCleanup = state.myCleanup
		else
			if not _execStepMachine(step, ctx, node, state) then return false end
			myCleanup = state.myCleanup
			nodeTopup = state.nodeTopup
		end
	end
	node.produced = (ctx.active[node.idx] and ctx.active[node.idx].done) or node.produced or 0
	ctx.active[node.idx] = nil
	return true
end

function mergePlan(plan)
	local merged   = {}
	local idxByKey = {}
	for _, step in ipairs(plan) do
		local key
		if step.fluid_craft then
			key = (step.item or "?") .. "|F|" .. tostring(step.fluidRecipe)
		else
			local ings = step.ingredients and table.concat(step.ingredients, ",") or ""
			key = (step.item or "?") .. "|" .. tostring(step.type) .. "|" ..
			tostring(step.machine_name) .. "|" .. tostring(step.output_count or 1) ..
			"|" .. tostring(step.output_device or "") .. "|" .. ings
		end
		local mi = idxByKey[key]
		if mi then
			local m = merged[mi]
			m.count = (m.count or 0) + (step.count or 0)
			if step.fluid_craft then
				m.fluidAmount = (m.fluidAmount or 0) + (step.fluidAmount or 0)
			end
		else
			merged[#merged + 1] = step
			idxByKey[key] = #merged
		end
	end
	return merged
end

function buildCraftDAG(plan)
	local nodes = {}
	local producerOf = {}
	for idx, step in ipairs(plan) do
		nodes[idx] = { idx = idx, step = step, deps = {}, tokens = stepTokens(step),
			done = false, started = false }
		if step.item then producerOf[step.item] = idx end
	end
	for idx, node in ipairs(nodes) do
		local step = node.step
		local seen = {}

		local function addDep(ingName)
			local p = producerOf[ingName]
			if p and p ~= idx and not seen[p] then
				seen[p] = true
				node.deps[#node.deps + 1] = p
			end
		end
		if step.fluid_craft then
			for _, it in ipairs((step.fluidRecipe and step.fluidRecipe.item_inputs) or {}) do
				addDep(it.name)
			end
			for _, inp in ipairs((step.fluidRecipe and step.fluidRecipe.inputs) or {}) do
				addDep(inp.name)
			end
		elseif step.ingredients then
			for _, ing in ipairs(step.ingredients) do
				if ing and ing ~= "nil" then addDep(ing) end
			end
		end
		if not (step.count and step.count > 0) then node.done = true end
	end
	return nodes
end

-- ORDER MATTERS. check all deps first, THEN grab tokens.
-- swap them and you hold tokens waiting for a dep that is itself
-- waiting for tokens you could release. deadlock
function claimReadyNode(ctx)
	for _, node in ipairs(ctx.nodes) do
		if not node.done and not node.started then
			local ready = true
			for _, d in ipairs(node.deps) do
				if not ctx.nodes[d].done then ready = false; break end
			end
			if ready and acquireTokens(node.tokens) then
				node.started = true
				return node
			end
		end
	end
	return nil
end

function drawParallel(ctx)
	if drawUI then drawUI(true) end
	local w, h = monitor.getSize()
	local pW, pH = 46, 14
	local title = ctx.failed and " MANUFACTURING FAILED " or " MANUFACTURING ACTIVE "
	local style = ctx.failed and "danger" or "warn"
	local pX, pY = UI.popup(pW, pH, w, h, title, style)

	local activeList = {}
	for _, a in pairs(ctx.active) do activeList[#activeList + 1] = a end
	table.sort(activeList, function(x, y) return (x.done or 0) > (y.done or 0) end)

	local sDone  = stageDone or 0
	local sTotal = math.max(stageTotal or 0, sDone, 1)
	local stepStr = string.format("Sub-task %d/%d", sDone, sTotal)
	drawText(pX + 2, pY + 2, stepStr, colors.white, colors.gray)
	local wStr = "[" .. #activeList .. "x parallel]"
	drawText(pX + pW - #wStr - 2, pY + 2, wStr, colors.cyan, colors.gray)
	local cleanFinal = (shortName(ctx.finalGoal)):upper()
	local itemStr = (">> " .. cleanFinal .. " <<"):sub(1, pW - 4)
	drawText(pX + math.floor((pW - #itemStr) / 2), pY + 3, itemStr, colors.yellow, colors.gray)

	local row = pY + 5
	local shown = 0
	for _, a in ipairs(activeList) do
		if shown >= 5 then break end
		local prog  = string.format("%d/%d", a.done or 0, a.total or 0)
		local pre   = a.nest and "+" or (a.topup and string.char(7) or "-")
		local pmStr = "pm" .. (a.machines or 0)
		drawText(pX + 2, row, pre, colors.lightGray, colors.gray)
		drawText(pX + 4, row, pmStr, colors.lightBlue, colors.gray)
		local nameX   = pX + 4 + #pmStr + 1
		local nameMax = math.max(1, (pX + pW - #prog - 2) - nameX)
		drawText(nameX, row, tostring(a.desc):sub(1, nameMax), colors.lightGray, colors.gray)
		drawText(pX + pW - #prog - 2, row, prog, colors.lime, colors.gray)
		row = row + 1
		shown = shown + 1
	end
	if #activeList == 0 then
		drawText(pX + 2, row, "scheduling...", colors.lightGray, colors.gray)
	end

	local barWidth = math.min(28, pW - 14)
	local barX = pX + math.floor((pW - barWidth) / 2)
	drawProgBar(barX, pY + pH - 3, barWidth, sDone, sTotal, colors.gray)

	local cancelStr = " [ CANCEL ] "
	local cbx = pX + math.floor((pW - #cancelStr) / 2)
	local cby = pY + pH - 1
	drawText(cbx, cby, cancelStr, colors.white, colors.red)
	craftCancelY  = cby
	craftCancelX1 = cbx
	craftCancelX2 = cbx + #cancelStr - 1
	_bufFlush()
end

function schedDone(ctx)
	return ctx.failed or Craft.cancelled or ctx.remaining <= 0
end

runCraft = function(plan)
	if #plan == 0 then return false end
	-- top-level entry only. nested calls MUST keep locks
	-- or subcraft steals its parents tokens and everything deadlocks
	if Craft.depth == 0 then
		Craft.cancelled = false; Craft.failed = false; Craft.locks = {}; Craft.usedMachines = {}
		Craft.lastFailStage = nil; Craft.lastFail = nil
		fluidTankClaims = 0; _fluidBusy = false; fluidInlineByCo = {}
		Craft.jobId = dbgNextJob(Craft.jobSrc)
		Craft.subSeq = 0
		ensureDepthByCo = {}
		failReasonByCo = {}
	end
	Craft.subSeq = (Craft.subSeq or 0) + 1
	local ctxSubId = Craft.subSeq
	if Craft.cancelled then return false end

	local sortedStore = {}
	for sName, enabled in pairs(Config.storages) do
		if enabled then
			local p = peripheral.wrap(sName)
			if p and p.list and p.pullItems then sortedStore[#sortedStore + 1] = sName end
		end
	end
	table.sort(sortedStore)
	local firstStore = sortedStore[1]
	if not firstStore then return false end

	craftPackIndex     = {}
	craftPackFree      = {}
	maxStackCache = {}
	craftScan     = nil
	craftScan     = scanStorage()
	local packScan = scanPeriph(sortedStore, "list", true)
	for _, s in ipairs(sortedStore) do
		local e = packScan[s]
		if e then
			local used = 0
			if e.data then
				for _, it in pairs(e.data) do
					if it then
						craftPackIndex[it.name] = craftPackIndex[it.name] or {}
						craftPackIndex[it.name][s] = true
						used = used + 1
					end
				end
			end
			if e.size and used < e.size then craftPackFree[s] = true end
		end
	end

	plan = mergePlan(plan)
	local nodes = buildCraftDAG(plan)
	local finalGoal = plan[#plan] and plan[#plan].item or ""
	local remaining = 0
	for _, n in ipairs(nodes) do if not n.done then remaining = remaining + 1 end end

	local ctx = {
		plan = plan, nodes = nodes, sortedStore = sortedStore,
		firstStore = firstStore, finalGoal = finalGoal,
		remaining = remaining, total = #nodes, doneCount = 0,
		active = {}, failed = false, failErr = nil, done = false, fluidActive = false,
		subId = ctxSubId,
	}
	if remaining <= 0 then resetStock(); return true end

	-- nested subcrafts run the same parallel scheduler. no token conflict
	-- with parent: _execStepMachine drops its tokens before calling
	-- ensureItem, so parent is already parked by the time we get here.
	-- used to run these sequentially and a 30-step rescue plan made
	-- fluid nodes wait on totally unrelated steel
	local isTop = (Craft.depth == 0)
	if isTop then
		displayCtx = ctx
		stageDone  = 0
		stageTotal = estimateStages(plan)
	end
	local distinct, nDistinct = {}, 0
	for _, n in ipairs(nodes) do
		for _, t in ipairs(n.tokens) do
			if not distinct[t] then distinct[t] = true; nDistinct = nDistinct + 1 end
		end
	end
	-- one worker per distinct machine token, up to 32. tokens already serialise
	-- shared groups, so extra workers over that cap just sit idle waiting for
	-- same locks. 16 used to leave big plans (20+ groups) with machines idle
	-- for no reason.
	local workerCount = math.min(math.max(1, nDistinct), 32)

	local function worker()
		while not ctx.done do
			if schedDone(ctx) then ctx.done = true; return end
			local node = claimReadyNode(ctx)
			if not node then
				local tmW = os.startTimer(0.2)
				local evW, aW = os.pullEvent()
				if not (evW == "timer" and aW == tmW) then os.cancelTimer(tmW) end
			else
				failReasonByCo[lockOwnerId()] = nil
				local nkind = node.step.fluid_craft and "fluid"
				or ((node.step.type == "turtle" or node.step.type == "crafter") and node.step.type or "machine")
				dbgStart(Craft.jobId, ctx.subId, node.idx, node.step.item, node.step.count or 0, nkind)
				local ok, err = execStep(node.step, ctx, node)
				releaseTokens(node.tokens)
				ctx.active[node.idx] = nil
				dbgDone(Craft.jobId, ctx.subId, node.idx, node.step.item, node.produced or 0, ok, err)
				if ok then
					node.done = true
					ctx.remaining = ctx.remaining - 1
					ctx.doneCount = ctx.doneCount + 1
					if not node.step.fluid_craft then stageDone = (stageDone or 0) + 1 end
				else
					node.done = true
					ctx.remaining = ctx.remaining - 1
					if not Craft.cancelled and not ctx.failed then
						dbgFail(Craft.jobId, ctx.subId, node.idx, node.step.item,
							failReasonByCo[lockOwnerId()] or (err and tostring(err)) or "?")
					end
					if not Craft.cancelled then
						ctx.failed = true
						ctx.failErr = err
						Craft.failed = true
						if not Craft.lastFailStage then
							Craft.lastFailStage = node.step.item
							local r = failReasonByCo[lockOwnerId()]
							if not r and err then
								if type(err) == "table" then
									local ok, joined = pcall(table.concat, err, "; ")
									r = ok and joined or "?"
								else
									r = tostring(err)
								end
							end
							Craft.lastFail = r or "?"
						end
					end
				end
			end
		end
	end

	local function uiLoop()
		while not ctx.done do
			-- keep drawing while workers finish their in-flight steps.
			-- without this the popup froze on "ACTIVE" while failure was
			-- winding down and user never saw the FAIL title flip
			if schedDone(ctx) and not next(ctx.active) then
				ctx.done = true; return
			end
			drawParallel(ctx)
			local tmU = os.startTimer(0.3)
			local nEv = 0
			while true do
				local evU, aU = os.pullEvent()
				if evU == "timer" and aU == tmU then break end
				nEv = nEv + 1
				if nEv >= 50 then os.cancelTimer(tmU); break end
				if ctx.done then return end
			end
		end
	end

	-- separate coroutine JUST for cancel. workers block on peripheral calls for
	-- hundreds of ms, if cancel polled inside them the tap felt dead.
	-- this loop only watches touch and flips flag
	local function cancelWatch()
		while not ctx.done do
			local timer = os.startTimer(0.3)
			local deadline = os.clock() + 0.4
			while true do
				local ev, a, b, c = os.pullEvent()
				if ev == "timer" and a == timer then break end
				if ev == "monitor_touch" and craftCancelY and c == craftCancelY
				and b >= craftCancelX1 and b <= craftCancelX2 then
					Craft.cancelled = true
				end
				if ctx.done then return end
				if os.clock() >= deadline then os.cancelTimer(timer); break end
			end
			if schedDone(ctx) then ctx.done = true; return end
		end
	end

	local tasks = {}
	for _ = 1, workerCount do tasks[#tasks + 1] = worker end
	if isTop then
		tasks[#tasks + 1] = uiLoop
		tasks[#tasks + 1] = cancelWatch
	end
	parallel.waitForAll(table.unpack(tasks))

	if isTop then
		displayCtx = nil
		sweepMachines()
		Craft.failed = false
		craftScan = nil
	end
	resetStock()
	if Craft.cancelled then return false end
	if ctx.failed then return false end
	return true
end

-- create mechanical crafter step. one op per cycle: crafters hold 1 item each.
-- cycle = lock, drain out, verify grid (empty, or a known leftover), check stock
-- covers EVERY missing cell, load, unlock + pulse, wait for the result in the
-- output inv, drain it to vaults.
-- crafter inventories are insert-only, so from the first pushed item on the
-- cycle is COMMITTED: cancel is ignored until it finishes. bailing mid-load used
-- to leave half a recipe in the grid and wedge every later crafter craft.

CRAFTER_HAND_EMPTY = "Take items back: empty-hand right-click each crafter front."

local function crafterFail(title, lines, reason)
	craftErrTitle = title
	craftErrLines = lines
	failReason(reason)
	pcall(crafterSetLock, true)
	return false
end

-- pick a real item (exact first, then item-group alts) for every needed cell
-- from one scan. need = {{k, ing, cell, gi}}. nil + short map when stock cant
-- cover all of them. NOTHING is pushed here, this is the pre-commit check
local function crafterAlloc(need, scanNames)
	local prescan = scanPeriph(scanNames, "list")
	local avail = {}
	for _, n in ipairs(scanNames) do
		local e = prescan[n]
		if e and e.data then
			for _, it in pairs(e.data) do
				if it then avail[it.name] = (avail[it.name] or 0) + (it.count or 0) end
			end
		end
	end
	local bstock = nil
	local pick, short = {}, {}
	for _, n in ipairs(need) do
		local cands = { n.ing }
		for _, a in ipairs(Groups.altsOf(n.ing) or {}) do
			if a ~= n.ing then cands[#cands + 1] = a end
		end
		for _, c in ipairs(cands) do
			if (avail[c] or 0) <= 0 then
				-- ae/rs bridge stock counts too, crafterPushOne feeds from it last
				bstock = bstock or bridgeStock()
				if (bstock[c] or 0) > 0 then avail[c] = bstock[c]; bstock[c] = 0 end
			end
			if (avail[c] or 0) > 0 then
				avail[c] = avail[c] - 1
				pick[n.k] = c
				break
			end
		end
		if not pick[n.k] then short[n.ing] = (short[n.ing] or 0) + 1 end
	end
	if next(short) then return nil, short end
	return pick, prescan
end

-- 1 item into slot 1 of a cell. deliberately NO Craft.cancelled check (that is
-- what pushFromStore does, and it is what stranded half-loaded grids)
local function crafterPushOne(name, cell, prescan, scanNames)
	local dst = peripheral.wrap(cell)
	for pass = 1, 2 do
		local scanned = (pass == 1 and prescan) or scanPeriph(scanNames, "list")
		for _, stoName in ipairs(scanNames) do
			local e = scanned[stoName]
			local sto = e and e.data and peripheral.wrap(stoName)
			if sto and sto.getItemDetail then
				for slot, it in pairs(e.data) do
					if it and it.name == name then
						local okD, det = pcall(sto.getItemDetail, slot)
						if okD and det and det.name == name and (det.count or 0) > 0 then
							local okP, mv = false, 0
							if sto.pushItems then
								okP, mv = pcall(sto.pushItems, cell, slot, 1, 1)
							elseif dst and dst.pullItems then
								okP, mv = pcall(dst.pullItems, stoName, slot, 1, 1)
							end
							if okP and type(mv) == "number" and mv > 0 then
								resetStock()
								return true
							end
							-- live source refused = the cell itself wont take it
							if okP then return false end
						end
					end
				end
			end
		end
	end
	return (bridgeFeed(name, 1, cell, 1) or 0) > 0
end

-- waits for the product. stable = same listing twice in a row. no cancel:
-- inputs are already in the chain, abandoning here confuses the next cycle
local function crafterAwaitOut(want, target, onTick)
	local t, prevSig, stable = 0, nil, 0
	while t < CRAFTER_TIMEOUT do
		if onTick then onTick() end
		sleep(0.5)
		t = t + 0.5
		local sig, have = {}, 0
		for _, it in pairs(crafterOutList()) do
			if it then
				sig[#sig + 1] = it.name .. "=" .. (it.count or 0)
				if it.name == target then have = have + (it.count or 0) end
			end
		end
		table.sort(sig)
		local s = table.concat(sig, ",")
		if s == prevSig then stable = stable + 1 else stable = 0 end
		prevSig = s
		if have >= want and stable >= 1 then return true end
	end
	return false
end

-- one full cycle towards tgt {item, ings, cells, perOp} (recipe order).
-- cur = crafterReadCells(), may already hold part of tgt (leftover).
--   success:  true, nil, got
--   no stock: false, nil, nil, short   (nothing was pushed)
--   failure:  false, {title, lines, reason}, got
function crafterRunCycle(tgt, cur, dstNames, scanNames, onTick)
	local c = crafterCfg()
	local loaded = {}
	for gi = 1, #c.cells do loaded[gi] = cur[gi] or "nil" end
	local need, planned = {}, {}
	for k, cell in ipairs(tgt.cells) do
		local gi = crafterCellIdx(cell)
		local want = tgt.ings[k] or "nil"
		planned[k] = (gi and cur[gi] ~= "nil") and cur[gi] or want
		if gi and want ~= "nil" and cur[gi] == "nil" then
			need[#need + 1] = {k = k, ing = want, cell = cell, gi = gi}
		end
	end
	local itemShort = shortName(tgt.item)

	if #need > 0 then
		local pick, prescan = crafterAlloc(need, scanNames)
		if not pick then return false, nil, nil, prescan end
		for _, n in ipairs(need) do planned[n.k] = pick[n.k] end
		-- written BEFORE the first push: from here on the grid is ours to finish
		crafterJobSave({item = tgt.item, ings = planned, cells = tgt.cells, perOp = tgt.perOp})
		for _, n in ipairs(need) do
			if onTick then onTick() end
			local nm = pick[n.k]
			if not crafterPushOne(nm, n.cell, prescan, scanNames) then
				return false, {
					title = "! CRAFTER LOAD FAILED",
					lines = {
						"Couldn't insert " .. shortName(nm) .. " into " .. getMachName(n.cell),
						"(slot cover? crafter busy?). Grid is part-loaded + LOCKED.",
						"[FINISH GRID] in +RECIPES > CRAFTER retries it.",
						CRAFTER_HAND_EMPTY,
					},
					reason = "crafter.load_failed cell=" .. tostring(n.cell),
				}
			end
			loaded[n.gi] = nm
		end
	else
		-- grid already complete (an earlier start never fired). keep the target on disk
		crafterJobSave({item = tgt.item, ings = planned, cells = tgt.cells, perOp = tgt.perOp})
	end

	local started, sErr = crafterStart(loaded, true, onTick)
	if not started then
		local lines = {"Grid loaded for " .. itemShort .. " but it never began."}
		lines[#lines + 1] = sErr and tostring(sErr) or "Empty cells need a PULSE relay or slot covers."
		lines[#lines + 1] = "Items stay in the grid. [FINISH GRID] retries it."
		return false, {title = "! CRAFTER DIDN'T START", lines = lines,
			reason = "crafter.no_start item=" .. tostring(itemShort)}
	end
	-- inputs left the crafter inventories, nothing in the grid to recover anymore
	crafterJobClear()

	local okOut = crafterAwaitOut(tgt.perOp or 1, tgt.item, onTick)
	local got = crafterDrainOut(dstNames)
	if not okOut then
		local lines = {
			"No " .. itemShort .. " after " .. CRAFTER_TIMEOUT .. "s.",
			"Wrong recipe/layout: create drops the",
			"items at the crafters. Check the floor.",
		}
		if next(got) then lines[#lines + 1] = "Got something else instead (in vaults)." end
		return false, {title = "! CRAFTER NO OUTPUT", lines = lines,
			reason = "crafter.no_output item=" .. tostring(itemShort)}, got
	end
	return true, nil, got
end

function _execStepCrafter(step, ctx, node, state)
	local sortedStore = state.sortedStore
	local helpers     = state.helpers
	local plan, i     = state.plan, state.i
	local desc        = state.desc
	local ings  = step.ingredients or {}
	local cells = step.grid_cells or {}
	local itemShort = shortName(step.item)
	state.myCleanup = {}

	if #ings == 0 or #ings ~= #cells then
		return crafterFail("! CRAFTER RECIPE BROKEN", {
			"Recipe for " .. itemShort .. " has no cell map.",
			"Re-learn it in +RECIPES > CRAFTER.",
		}, "crafter.bad_recipe item=" .. tostring(itemShort))
	end
	local okR, why = crafterReady(cells)
	if not okR then
		return crafterFail("! CRAFTER NOT READY", {
			"Required for: " .. itemShort, tostring(why),
			"Check grid/relay/output in +RECIPES > CRAFTER.",
		}, "crafter.not_ready " .. tostring(why))
	end
	local c = crafterCfg()
	Craft.usedMachines[c.out] = true

	local ingNeed = {}
	for _, ing in ipairs(ings) do
		if ing ~= "nil" then ingNeed[ing] = (ingNeed[ing] or 0) + 1 end
	end
	releaseTokens(node.tokens)
	local okI, errI, missIng = ensureIngs(step, ingNeed)
	if not okI then
		craftErrTitle = "! NEED"
		craftErrLines = errI or {"Can't make " .. itemShort}
		failReason("crafter.ing_topup_failed item=" .. tostring(shortName(missIng)))
		return false
	end
	while not Craft.cancelled and not ctx.failed do
		if acquireTokens(node.tokens) then break end
		sleepYield(0.2, ctx)
	end
	if Craft.cancelled or ctx.failed then
		failReason(Craft.cancelled and "crafter.cancel_before_run" or "crafter.ctx_failed_before_run")
		return false
	end

	local perOp     = step.output_count or 1
	local totalNeed = step.count or 0
	local totalDone = 0
	local dry = 0
	local scanNames = scanStorage()

	local function tick()
		local d = Craft.cancelled and (desc .. " (finishing cycle)") or desc
		helpers.drawProgress(i, #plan, d, totalDone, totalNeed, step.item, 1)
	end

	while totalDone < totalNeed do
		-- only exit point for cancel: between cycles, grid empty
		if Craft.cancelled then failReason("crafter.cancel"); pcall(crafterSetLock, true); return false end
		tick()

		local okL, lockErr = crafterSetLock(true)
		if not okL then
			return crafterFail("! CRAFTER CLUTCH", {tostring(lockErr)}, "crafter.lock " .. tostring(lockErr))
		end
		-- residue from a late craft belongs in the vaults, not in the count
		crafterDrainOut(sortedStore)

		local cur, rErr = crafterReadCells()
		if not cur then
			return crafterFail("! CRAFTER GRID", {tostring(rErr)}, "crafter.read " .. tostring(rErr))
		end

		local tgt, residue
		if crafterGridEmpty(cur) then
			tgt = {item = step.item, ings = ings, cells = cells, perOp = perOp}
		else
			local whyR
			tgt, whyR = crafterResidueTarget(cur)
			if not tgt then
				local dirty = {}
				for idx, v in ipairs(cur) do
					if v ~= "nil" then dirty[#dirty + 1] = shortName(v) .. "@" .. idx end
				end
				return crafterFail("! CRAFTER GRID NOT EMPTY", {
					"Crafters hold items the computer can't pull out:",
					table.concat(dirty, ", "):sub(1, 60),
					tostring(whyR) .. ".",
					CRAFTER_HAND_EMPTY,
				}, "crafter.grid_dirty n=" .. #dirty)
			end
			residue = true
			dbgWrite(string.format("j=%d s=%d crafter.residue idx=%d target=%s job=%s",
				Craft.jobId or 0, ctx.subId or 0, node.idx or 0, shortName(tgt.item), tostring(tgt.fromJob)))
		end

		local ok, err, got, short = crafterRunCycle(tgt, cur, sortedStore, scanNames, tick)
		if ok then
			dry = 0
			-- a leftover of some other item went to the vaults, only credit our own
			if tgt.item == step.item then
				local made = got[step.item] or 0
				local ops = math.max(1, math.floor(made / perOp))
				if ops > totalNeed - totalDone then ops = totalNeed - totalDone end
				totalDone = totalDone + ops
				dbgPush(Craft.jobId, ctx.subId, node.idx, step.item, made,
					totalDone * perOp, totalNeed * perOp, 0, 0, CRAFTER_MACHINE)
			end
		elseif short then
			local parts = {}
			for ing, n in pairs(short) do parts[#parts + 1] = string.format("%dx %s", n, shortName(ing)) end
			if residue then
				local lines = {"Grid holds part of " .. shortName(tgt.item) .. ", can't finish it."}
				appendMissing(lines, parts)
				lines[#lines + 1] = "Stock up and retry, or empty the grid."
				lines[#lines + 1] = CRAFTER_HAND_EMPTY
				return crafterFail("! CRAFTER LEFTOVER", lines, "crafter.residue_short item=" .. tostring(shortName(tgt.item)))
			end
			for ing, n in pairs(short) do bridgeStage(ing, n * (totalNeed - totalDone)) end
			dry = dry + 1
			if dry >= 3 then
				local lines = {"Can't load grid for " .. itemShort}
				appendMissing(lines, parts)
				return crafterFail("! NEED", lines, "crafter.no_stock item=" .. tostring(itemShort))
			end
			resetStock()
			sleepCancel(1.0)
		else
			return crafterFail(err.title, err.lines, err.reason)
		end
	end
	-- park locked so whatever the next thing is (player, other craft) starts clean
	pcall(crafterSetLock, true)
	tick()
	return true
end

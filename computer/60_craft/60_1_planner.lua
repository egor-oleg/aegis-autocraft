-- credit fluid+item byproducts of a fluid recipe into planner stock
-- BEFORE we recurse into its inputs. breaks cycles where a byproduct
-- is also an input somewhere upstream (electrolyzer gives sulfuric_acid
-- back while chemical_reactor eats it). target item/fluid is skipped,
-- surplus of the primary is handled by the caller.
function creditByprods(frec, fops, stock, skipItem, skipFluid)
	if not frec or not fops or fops <= 0 then return end
	if not stock.__fl then
		stock.__fl = true
		for k, v in pairs(getFluidCached()) do
			if stock[k] == nil then stock[k] = v end
		end
	end
	for _, o in ipairs(frec.outputs or {}) do
		if o.name ~= skipFluid then
			local k = fluidKey(o.name)
			stock[k] = (stock[k] or 0) + (o.amount or 0) * fops
		end
	end
	for _, o in ipairs(frec.item_outputs or {}) do
		if o.name ~= skipItem then
			stock[o.name] = (stock[o.name] or 0) + (o.count or 0) * fops
		end
	end
end

function groupAvail(itemName, stock)
	local total = stock[itemName] or 0
	local alts = Groups.altsOf(itemName)
	if alts then
		for _, altName in ipairs(alts) do
			if altName ~= itemName then
				total = total + (stock[altName] or 0)
			end
		end
	end
	return total
end

function clearLearn()
	if learnedType == "crafter" then
		-- result already drained to T.BOX by the scan. park the grid locked
		pcall(crafterSetLock, true)
		return
	end
	if learnedType ~= "turtle" then return end
	if not (Config.train_box and Config.train_box ~= "") then return end
	local tb = peripheral.wrap(Config.train_box)
	if not (tb and tb.pullItems) then return end
	for slot = 1, 16 do pcall(function() tb.pullItems(learnedMach, slot, 64) end) end
end

function calcCraft(itemName, countNeed, stock, missing, blocked, craftPlan, visited, allowPartial)
	calcNodes = calcNodes + 1
	if calcBudget > 0 and calcNodes > calcBudget then return end
	-- cc doesnt preempt. long plans just freeze everything.
	-- sleep(0) yields so touches dont die
	if calcNodes % 1024 == 0 then sleep(0) end
	if countNeed <= 0 then return end
	if visited[itemName] then
		missing[itemName] = (missing[itemName] or 0) + countNeed
		return
	end
	visited[itemName] = true
	local alts = Groups.altsOf(itemName)
	local itemsToCheck = { itemName }
	if alts then
		for _, altName in ipairs(alts) do
			if altName ~= itemName then table.insert(itemsToCheck, altName) end
		end
	end
	for _, item in ipairs(itemsToCheck) do
		local available = stock[item] or 0
		if available >= countNeed then
			stock[item] = available - countNeed
			countNeed = 0
			break
		elseif available > 0 then
			countNeed = countNeed - available
			stock[item] = 0
		end
	end
	if countNeed <= 0 then
		visited[itemName] = nil
		return
	end
	-- recipe with type="fluid" is a STUB pointing at fluid producer that
	-- side-effects the item as one of its item_outputs.
	-- dont run as item craft, hand off to fluid engine
	local directRec = Recipe.find(itemName)
	if directRec and directRec.type == "fluid" then
		local frec, fperOp = findFluidItemProd(itemName)
		if frec and fperOp and fperOp > 0 then
			local fops = math.ceil(countNeed / fperOp)
			creditByprods(frec, fops, stock, itemName)
			for _, it in ipairs(frec.item_inputs or {}) do
				calcCraft(it.name, it.count * fops, stock, missing, blocked, craftPlan, visited, allowPartial)
			end
			for _, inp in ipairs(frec.inputs or {}) do
				simFluidConsume(inp.name, inp.amount * fops, stock, missing, {}, visited)
			end
			local surplus = fops * fperOp - countNeed
			if surplus > 0 then stock[itemName] = (stock[itemName] or 0) + surplus end
			table.insert(craftPlan, {
					item = itemName, count = fops, output_count = fperOp,
					fluid_craft = true, fluidRecipe = frec, fluidAmount = fops * fperOp,
				})
		else
			missing[itemName] = (missing[itemName] or 0) + countNeed
		end
		visited[itemName] = nil
		return
	end
	local candidates = {}
	for _, item in ipairs(itemsToCheck) do
		local r = Recipe.find(item)
		if r then
			table.insert(candidates, {recipe = r, targetItem = item})
			break
		end
	end
	for _, item in ipairs(itemsToCheck) do
		local alts = Recipe.altsOf(item)
		if alts then
			for _, altRec in ipairs(alts) do
				table.insert(candidates, {recipe = altRec, targetItem = item})
			end
			break
		end
	end
	if #candidates == 0 then
		local frec, fperOp = findFluidItemProd(itemName)
		if frec and fperOp and fperOp > 0 then
			local fops = math.ceil(countNeed / fperOp)
			creditByprods(frec, fops, stock, itemName)
			for _, it in ipairs(frec.item_inputs or {}) do
				calcCraft(it.name, it.count * fops, stock, missing, blocked, craftPlan, visited, allowPartial)
			end
			for _, inp in ipairs(frec.inputs or {}) do
				simFluidConsume(inp.name, inp.amount * fops, stock, missing, {}, visited)
			end
			local surplus = fops * fperOp - countNeed
			if surplus > 0 then stock[itemName] = (stock[itemName] or 0) + surplus end
			table.insert(craftPlan, {
					item = itemName, count = fops, output_count = fperOp,
					fluid_craft = true, fluidRecipe = frec, fluidAmount = fops * fperOp,
				})
			visited[itemName] = nil
			return
		end
		missing[itemName] = (missing[itemName] or 0) + countNeed
		visited[itemName] = nil
		return
	end
	local chosen = nil
	local bestMiss = math.huge
	local allOk = false
	if #candidates == 1 then
		chosen = candidates[1]
		allOk = true
	else
		local ownBudget = (calcBudget == 0)
		if ownBudget then calcNodes = 0; calcBudget = 6000 end
		for _, cand in ipairs(candidates) do
			local opc = cand.recipe.output_count or 1
			local cc  = math.ceil(countNeed / opc)
			local ings = {}
			for i = 1, #cand.recipe.ingredients do
				local ing = cand.recipe.ingredients[i]
				if ing and ing ~= "nil" then ings[ing] = (ings[ing] or 0) + 1 end
			end
			local testStock = {}
			for k, v in pairs(stock) do testStock[k] = v end
			local testVisited = {}
			for k, v in pairs(visited) do testVisited[k] = v end
			local testMissing = {}
			local testBlocked = {}
			local testPlan    = {}
			for ingName, perCraft in pairs(ings) do
				calcCraft(ingName, perCraft * cc, testStock, testMissing, testBlocked, testPlan, testVisited, false)
			end
			local missTotal = 0
			for _, v in pairs(testMissing) do missTotal = missTotal + v end
			if missTotal == 0 then
				chosen = cand
				allOk = true
				break
			end
			if missTotal < bestMiss then
				chosen = cand
				bestMiss = missTotal
			end
		end
		if ownBudget then calcNodes = 0; calcBudget = 0 end
	end
	if not chosen then chosen = candidates[1] end
	local recipe     = chosen.recipe
	local targetItem = chosen.targetItem
	local outPerCraft = recipe.output_count or 1
	local craftsCount = math.ceil(countNeed / outPerCraft)
	local toolSet = recipe.tools or {}
	local ingCounts = {}
	for i = 1, #recipe.ingredients do
		local ing = recipe.ingredients[i]
		if ing and ing ~= "nil" then
			ingCounts[ing] = (ingCounts[ing] or 0) + 1
		end
	end
	if allowPartial and not allOk then
		local maxN = craftsCount
		if recipe.type == "turtle" or recipe.type == "crafter" then
			for ingName, ingPerCraft in pairs(ingCounts) do
				if not toolSet[ingName] then
					local ingAvail = groupAvail(ingName, stock)
					local possible = math.floor(ingAvail / ingPerCraft)
					if possible < maxN then maxN = possible end
				end
			end
		else
			for ingName in pairs(ingCounts) do
				if not toolSet[ingName] then
					local ingAvail = groupAvail(ingName, stock)
					if ingAvail < maxN then maxN = ingAvail end
				end
			end
		end
		if maxN > 0 then
			craftsCount = maxN
		else
			missing[itemName] = (missing[itemName] or 0) + countNeed
			visited[itemName] = nil
			return
		end
	end
	local totalProd = craftsCount * outPerCraft
	for ingName, ingPerCraft in pairs(ingCounts) do
		if toolSet[ingName] then
			if groupAvail(ingName, stock) < 1 then
				calcCraft(ingName, 1, stock, missing, blocked, craftPlan, visited, allowPartial)
			end
		else
			calcCraft(ingName, ingPerCraft * craftsCount, stock, missing, blocked, craftPlan, visited, allowPartial)
		end
	end
	for ingName in pairs(ingCounts) do
		if missing[ingName] then
			blocked[itemName] = true
			break
		end
	end
	local surplus = totalProd - countNeed
	if surplus > 0 then stock[targetItem] = (stock[targetItem] or 0) + surplus end
	table.insert(craftPlan, {
			item = targetItem,
			count = craftsCount,
			type = recipe.type,
			machine_name = recipe.machine_name,
			ingredients = recipe.ingredients,
			output_count = recipe.output_count or 1,
			output_device = recipe.output_device,
			tools = recipe.tools,
			grid_cells = recipe.grid_cells,
		})
	visited[itemName] = nil
end
ppYieldCounter = 0

function planProd(itemName, amount, allowPartial, stkSnap)
	ppYieldCounter = ppYieldCounter + 1
	if ppYieldCounter >= 150 then ppYieldCounter = 0; sleep(0) end
	local curStore
	if stkSnap then
		curStore = {}
		for k, v in pairs(stkSnap) do curStore[k] = v end
	else
		curStore = {}
		for k, v in pairs(getInvCached()) do curStore[k] = v end
	end
	local missingItems = {}
	local blockedItems = {}
	local execPlan = {}
	calcCraft(itemName, amount, curStore, missingItems, blockedItems, execPlan, {}, false)
	local hasMissing = false
	for _ in pairs(missingItems) do hasMissing = true break end
	if hasMissing then
		if allowPartial then
			local partialStock
			if stkSnap then
				partialStock = {}
				for k, v in pairs(stkSnap) do partialStock[k] = v end
			else
				partialStock = {}
				for k, v in pairs(getInvCached()) do partialStock[k] = v end
			end
			local partialPlan = {}
			calcCraft(itemName, amount, partialStock, {}, {}, partialPlan, {}, true)
			return partialPlan, missingItems, blockedItems
		else
			return {}, missingItems, blockedItems
		end
	end
	return execPlan, {}, {}
end

function maxCraft(iName, snapCraft)
	local _, quickMiss1 = planProd(iName, 1, false, snapCraft)
	if next(quickMiss1) then return 0 end
	local _, quickMiss100 = planProd(iName, 100, false, snapCraft)
	if not next(quickMiss100) then
		local _, bigMissing = planProd(iName, 10000, false, snapCraft)
		if not next(bigMissing) then return 10000 end
		local lo2, hi2 = 100, 1000
		while hi2 < 10000 do
			local _, m2 = planProd(iName, hi2, false, snapCraft)
			if next(m2) then break end
			lo2 = hi2; hi2 = math.min(hi2 * 4, 10000)
		end
		while hi2 - lo2 > 1 do
			local mid2 = math.floor((lo2 + hi2) / 2)
			local _, mm2 = planProd(iName, mid2, false, snapCraft)
			if not next(mm2) then lo2 = mid2 else hi2 = mid2 end
		end
		return lo2
	end
	local lo, hi = 1, 99
	while hi - lo > 1 do
		local mid = math.floor((lo + hi) / 2)
		local _, mm = planProd(iName, mid, false, snapCraft)
		if not next(mm) then lo = mid else hi = mid end
	end
	return lo
end

function scanRecipesNow()
	recipesScan = {}
	local snap = getInv()

	local function scanRecipe(iName)
		local _, missing, blocked = planProd(iName, 1, false, snap)
		local blockedInfo = {}
		for bItem in pairs(blocked) do
			local _, bMissing, _ = planProd(bItem, 1, false, snap)
			blockedInfo[bItem] = {missing = bMissing}
		end
		local directAvail  = groupAvail(iName, snap)
		local maxCraftable = 0
		local snapCraft = {}
		for k, v in pairs(snap) do snapCraft[k] = v end
		snapCraft[iName] = 0
		local alts = Groups.altsOf(iName)
		if alts then
			for _, alt in ipairs(alts) do snapCraft[alt] = 0 end
		end
		if not next(missing) then
			maxCraftable = maxCraft(iName, snapCraft)
		end
		local hasMach, missMach = checkMachine(Recipe.find(iName))
		recipesScan[iName] = {missing=missing, blocked=blocked, blockedInfo=blockedInfo, maxCraftable=maxCraftable, noMachine=not hasMach, missingMach=missMach}
	end
	local scanCounter = 0
	for iName in pairs(Recipe.all()) do
		scanCounter = scanCounter + 1
		if scanCounter % 3 == 0 then sleep(0) end
		scanRecipe(iName)
	end
end

function scanKeepNow()
	local snap = getInv()
	for itemName in pairs(Keep.all()) do
		if Recipe.find(itemName) then
			local _, missing, blocked = planProd(itemName, 1, false, snap)
			local maxCraftable = 0
			local snapCraft = {}
			for k, v in pairs(snap) do snapCraft[k] = v end
			snapCraft[itemName] = 0
			if not next(missing) then
				local _, qm1, _ = planProd(itemName, 1, false, snapCraft)
				if not next(qm1) then
					local _, qm100, _ = planProd(itemName, 100, false, snapCraft)
					if not next(qm100) then
						local _, bigM, _ = planProd(itemName, 10000, false, snapCraft)
						if not next(bigM) then
							maxCraftable = 10000
						else
							local lo2, hi2 = 100, 1000
							while hi2 < 10000 do
								local _, m2, _ = planProd(itemName, hi2, false, snapCraft)
								if next(m2) then break end
								lo2 = hi2; hi2 = math.min(hi2 * 4, 10000)
							end
							while hi2 - lo2 > 1 do
								local mid2 = math.floor((lo2 + hi2) / 2)
								local _, mm2, _ = planProd(itemName, mid2, false, snapCraft)
								if not next(mm2) then lo2 = mid2 else hi2 = mid2 end
							end
							maxCraftable = lo2
						end
					else
						local lo, hi = 1, 99
						while hi - lo > 1 do
							local mid = math.floor((lo + hi) / 2)
							local _, mm, _ = planProd(itemName, mid, false, snapCraft)
							if not next(mm) then lo = mid else hi = mid end
						end
						maxCraftable = lo
					end
				end
			end
			local hasMach, missMach = checkMachine(Recipe.find(itemName))
			recipesScan[itemName] = {missing=missing, blocked=blocked, blockedInfo={}, maxCraftable=maxCraftable, noMachine=not hasMach, missingMach=missMach}
		end
	end
end


local function reqStockOrAlts(itemName)
	local inv = getInvCached()
	local n = inv[itemName] or 0
	if n > 0 then return n end
	local alts = Groups.altsOf(itemName)
	if not alts then return 0 end
	for _, altName in ipairs(alts) do
		if altName ~= itemName then n = n + (inv[altName] or 0) end
	end
	return n
end

function _touchQty(zone, x, y)
	if zone.id == "open_qty_picker" then
		itemToCraft = zone.arg
		fluidCraftMode = nil
		fluidKeepName = nil
		isSettingKeep = false
		isRequestMode = false
		qtyOrigTab = curTab
		local pickerSnap = getInvCached()
		craftQuantity = pickerSnap[zone.arg] or 0
		pickerCraftable = 0
		pickerCapped = false
		pickerMaxSet = false
		if Config.autoMaxCalc ~= false then pickerMax() end
		curTab = "QUANTITY_PICKER"
		return true
	elseif zone.id == "open_req_picker" then
		itemToCraft = zone.arg
		fluidCraftMode = nil
		fluidKeepName = nil
		reqMaxQty = reqStockOrAlts(zone.arg)
		craftQuantity = math.min(1, reqMaxQty)
		isSettingKeep = false
		isRequestMode = true
		qtyOrigTab = curTab
		curTab = "QUANTITY_PICKER"
		return true
	elseif zone.id == "qty_adj" then
		if isSettingKeep then
			if keepField == "threshold" then
				keepThr = math.max(1, keepThr + zone.arg)
			else
				keepTgt = math.max(1, keepTgt + zone.arg)
			end
		else
			local minVal = isRequestMode and 1 or 0
			craftQuantity = math.max(minVal, craftQuantity + zone.arg)
			if isRequestMode then
				craftQuantity = math.min(craftQuantity, reqMaxQty)
			end
		end
		return true
	elseif zone.id == "qty_calc_max" then
		if not pickerMaxSet then pickerMax() end
		return true
	elseif zone.id == "qty_toggle_automax" then
		Config.autoMaxCalc = (Config.autoMaxCalc == false)
		saveData()
		if Config.autoMaxCalc then
			pickerMax()
		else
			pickerMaxSet = false
			pickerCraftable = 0
		end
		return true
	elseif zone.id == "qty_max" then
		if isRequestMode then
			craftQuantity = math.min(craftQuantity + reqMaxQty, reqMaxQty)
		else
			if not pickerMaxSet then pickerMax() end
			if fluidCraftMode then
				craftQuantity = pickerCraftable
			else
				craftQuantity = craftQuantity + pickerCraftable
			end
		end
		return true
	elseif zone.id == "qty_cancel" then
		isRequestMode = false
		isSettingKeep = false
		fluidCraftMode = nil
		fluidKeepName = nil
		altOutEdit = nil
		if queueEditIdx then queueEditIdx = nil; queueEditPopup = true end
		curTab = qtyOrigTab or "RECIPES"
		return true
	elseif zone.id == "qty_add_queue" then
		local qe = nil
		if fluidCraftMode then
			if craftQuantity > 0 then
				qe = {kind = "fluid", name = fluidCraftMode.target, qty = craftQuantity,
					recipe = fluidCraftMode.recipe, isItem = fluidCraftMode.isItem}
			end
			fluidCraftMode = nil
		elseif not isRequestMode and not isSettingKeep and craftQuantity > 0 then
			qe = {kind = "item", name = itemToCraft, qty = craftQuantity}
		end
		if qe then
			Craft.queue[#Craft.queue + 1] = qe
			uiMessage = "Queued: " .. (shortName(qe.name)) .. " x" .. qe.qty
		end
		curTab = qtyOrigTab or "RECIPES"
		return true
	elseif zone.id == "qty_type" then
		qtyTypeAct = true
		drawUI()
		term.clear(); term.setCursorPos(1, 1)
		write("Enter quantity: ")
		local input = timedRead(30)
		qtyTypeAct = false
		local num = tonumber(input)
		if num then
			if isSettingKeep then
				local v = math.max(1, math.floor(num))
				if keepField == "threshold" then keepThr = v else keepTgt = v end
			else
				local minVal = isRequestMode and 1 or 0
				craftQuantity = math.max(minVal, math.floor(num))
				if isRequestMode then
					craftQuantity = math.min(craftQuantity, reqMaxQty)
				end
			end
		end
		return true
	elseif zone.id == "open_queue" then
		queueEditPopup = not queueEditPopup
		queueErrIdx = nil
		return true
	elseif zone.id == "queue_close" then
		queueEditPopup = false
		queueErrIdx = nil
		return true
	elseif zone.id == "queue_top" then
		local qi = zone.arg
		if qi > 1 and Craft.queue[qi] then
			local qe = table.remove(Craft.queue, qi)
			table.insert(Craft.queue, 1, qe)
			queueErrIdx = nil
			queueScroll = 0
		end
		return true
	elseif zone.id == "queue_up" then
		local qi = zone.arg
		if qi > 1 and Craft.queue[qi] then
			Craft.queue[qi], Craft.queue[qi - 1] = Craft.queue[qi - 1], Craft.queue[qi]
			if queueErrIdx == qi then queueErrIdx = qi - 1
			elseif queueErrIdx == qi - 1 then queueErrIdx = qi end
		end
		return true
	elseif zone.id == "queue_dn" then
		local qi = zone.arg
		if Craft.queue[qi] and Craft.queue[qi + 1] then
			Craft.queue[qi], Craft.queue[qi + 1] = Craft.queue[qi + 1], Craft.queue[qi]
			if queueErrIdx == qi then queueErrIdx = qi + 1
			elseif queueErrIdx == qi + 1 then queueErrIdx = qi end
		end
		return true
	elseif zone.id == "queue_del" then
		if Craft.queue[zone.arg] then
			table.remove(Craft.queue, zone.arg)
			queueErrIdx = nil
		end
		return true
	elseif zone.id == "queue_err" then
		if queueErrIdx == zone.arg then queueErrIdx = nil
		else queueErrIdx = zone.arg end
		return true
	elseif zone.id == "queue_scroll" then
		queueScroll = math.max(0, queueScroll + zone.arg)
		return true
	elseif zone.id == "queue_edit" then
		local qe = Craft.queue[zone.arg]
		if qe then
			queueEditIdx = zone.arg
			queueEditPopup = false
			queueErrIdx = nil
			itemToCraft = qe.name
			craftQuantity = qe.qty
			isSettingKeep = false
			isRequestMode = false
			fluidCraftMode = nil
			fluidKeepName = nil
			pickerCraftable = 0
			pickerCapped = false
			pickerMaxSet = false
			if qe.kind ~= "fluid" and Config.autoMaxCalc ~= false then pickerMax() end
			qtyOrigTab = (curTab ~= "QUANTITY_PICKER") and curTab or "RECIPES"
			curTab = "QUANTITY_PICKER"
		end
		return true
	elseif zone.id == "queue_craft" then
		local qe = Craft.queue[zone.arg]
		if qe then
			queueEditPopup = false
			queueErrIdx = nil
			drawUI()
			sysStatus = "MANUAL_CRAFT"
			resetErr()
			local okQ, reason = queueRunOne(qe)
			if okQ then
				table.remove(Craft.queue, zone.arg)
			else
				qe.failed = reason
			end
			sysStatus = "IDLE"
			resetErr()
			queueEditPopup = true
		end
		return true
	elseif zone.id == "queue_runall" then
		if #Craft.queue > 0 then
			queueEditPopup = false
			queueErrIdx = nil
			drawUI()
			runQueueAll()
			queueEditPopup = true
		end
		return true
	elseif zone.id == "popup_close" then
		if craftDonePopup and craftDonePopup.timer then os.cancelTimer(craftDonePopup.timer) end
		craftDonePopup = nil
		return true
	elseif zone.id == "popup_request" then
		local popItem = craftDonePopup and craftDonePopup.item
		if craftDonePopup and craftDonePopup.timer then os.cancelTimer(craftDonePopup.timer) end
		craftDonePopup = nil
		if popItem and Config.train_box and Config.train_box ~= "" then
			reqMaxQty = reqStockOrAlts(popItem)
			itemToCraft = popItem
			fluidCraftMode = nil
			fluidKeepName = nil
			craftQuantity = math.max(1, reqMaxQty)
			isSettingKeep = false
			isRequestMode = true
			qtyOrigTab = "RECIPES"
			curTab = "QUANTITY_PICKER"
		end
		return true
	elseif zone.id == "select_device" then
		if outPickMode then
			if zone.arg == selCraftType then
				selOut = nil
			else
				selOut = zone.arg
			end
			outPickMode = false
		else
			selCraftType = zone.arg
			selOut = nil
			if zone.arg ~= "turtle" then craftSubTab = "MACHINES" end
		end
		return true
	elseif zone.id == "qty_confirm" then
		if altOutEdit then
			local aRec = altOutEdit.rec
			local aVal = math.max(1, craftQuantity)
			if aRec then
				if altOutEdit.fluidRow then
					for _, o in ipairs(aRec.outputs or {}) do
						if o.name == altOutEdit.targetName then o.amount = aVal end
					end
					for _, o in ipairs(aRec.item_outputs or {}) do
						if o.name == altOutEdit.targetName then o.count = aVal end
					end
					syncFluidStubs()
				else
					aRec.output_count = aVal
				end
				saveData()
			end
			altOutEdit = nil
			curTab = "ALT_VIEW"
		elseif queueEditIdx then
			local qe = Craft.queue[queueEditIdx]
			if qe and craftQuantity > 0 then
				qe.qty = craftQuantity
				qe.failed = nil
			end
			queueEditIdx = nil
			queueErrIdx = nil
			curTab = qtyOrigTab or "RECIPES"
			queueEditPopup = true
		elseif fluidCraftMode then
			local fcm = fluidCraftMode
			fluidCraftMode = nil
			curTab = qtyOrigTab or "RECIPES"
			if craftQuantity > 0 then
				local isFl = not fcm.isItem
				for hi = #craftHistory, 1, -1 do
					local he = craftHistory[hi]
					if he.item == fcm.target and (he.fluid or false) == isFl then
						table.remove(craftHistory, hi)
					end
				end
				table.insert(craftHistory, 1, {item = fcm.target, qty = craftQuantity, fluid = isFl})
				if #craftHistory > 30 then table.remove(craftHistory) end
				local fOk, fProduced, fIsItem = fluidCraft(fcm.recipe, fcm.target, craftQuantity)
				if fOk then ntfyCraftDone(fcm.target, fProduced, not fIsItem) else ntfyCraftFail(fcm.target) end
			end
		elseif isRequestMode then
			local qty = math.min(craftQuantity, reqMaxQty)
			if qty > 0 then
				local moved = deliverTrain(itemToCraft, qty)
				local name  = shortName(itemToCraft)
				if moved > 0 then
					resetStock()
					uiMessage = "Delivered " .. moved .. "x " .. name .. " to train box."
				else
					uiMessage = "ERR: nothing moved. Check train box."
				end
			end
			isRequestMode = false
			curTab = qtyOrigTab or "RECIPES"
		elseif isSettingKeep then
			local existing = Keep.of(itemToCraft)
			local existingOrder  = existing and existing.order
			local existingPaused = existing and existing.paused or false
			if not existingOrder then
				local maxOrder = 0
				for _, s in pairs(Keep.all()) do
					maxOrder = math.max(maxOrder, s.order or 0)
				end
				existingOrder = maxOrder + 1
			end
			local thr = math.max(1, keepThr)
			local tgt = math.max(thr, keepTgt)
			Keep.put(itemToCraft, { threshold = thr, target = tgt, paused = existingPaused, order = existingOrder })
			saveData()
			isSettingKeep = false
			fluidKeepName = nil
			curTab = qtyOrigTab or "RECIPES"
		else
			curTab = qtyOrigTab or "RECIPES"
			local preSnapH  = getInv()
			local preStockH = groupAvail(itemToCraft, preSnapH)
			for hi = #craftHistory, 1, -1 do
				if craftHistory[hi].item == itemToCraft then
					table.remove(craftHistory, hi)
				end
			end
			table.insert(craftHistory, 1, {item=itemToCraft, qty=craftQuantity})
			if #craftHistory > 30 then table.remove(craftHistory) end
			drawUI()
			sysStatus = "MANUAL_CRAFT"
			Craft.cancelled = false
			resetStock()
			local plan, missingRes, blockedComps = planProd(itemToCraft, craftQuantity, true)
			local missMachines = {}
			local missSteps = {}
			if plan and #plan > 0 then
				local seen = {}
				for _, step in ipairs(plan) do
					if step.type == "crafter" and step.count and step.count > 0 then
						local okC, whyC = crafterReady(step.grid_cells)
						if not okC and not seen["crafter:" .. tostring(whyC)] then
							seen["crafter:" .. tostring(whyC)] = true
							table.insert(missMachines, tostring(whyC))
							table.insert(missSteps, step.item)
						end
					elseif step.type ~= "turtle" and step.machine_name and step.machine_name ~= ""
					and step.count and step.count > 0 then
						local isSplit = (step.output_device and step.output_device ~= "")
						local pool
						if isSplit then
							pool = {step.machine_name}
						else
							pool = getMachPool(step.machine_name)
						end
						local found = false
						for _, mName in ipairs(pool) do
							if peripheral.wrap(mName) then found = true; break end
						end
						if not found and not seen[step.machine_name] then
							seen[step.machine_name] = true
							table.insert(missMachines, step.machine_name)
							table.insert(missSteps, step.item)
						end
						if isSplit and not peripheral.wrap(step.output_device)
						and not seen[step.output_device] then
							seen[step.output_device] = true
							table.insert(missMachines, step.output_device)
							table.insert(missSteps, step.item)
						end
					end
				end
			end
			if #missMachines > 0 then
				craftErrTitle = "! MACHINE NOT FOUND"
				craftErrLines = {}
				craftErrEdit = {}
				for mi, mName in ipairs(missMachines) do
					if mi <= 4 then
						local mDisp = getMachName(mName)
						local itemShort = shortName(missSteps[mi])
						table.insert(craftErrLines, mDisp .. "  ->  " .. itemShort)
						craftErrEdit[#craftErrLines] = missSteps[mi]
					end
				end
				if #missMachines > 4 then
					table.insert(craftErrLines, "... and " .. (#missMachines - 4) .. " more")
				end
				table.insert(craftErrLines, "Use [E] in RECIPES to reassign.")
				sysStatus = "IDLE"
				craftHistory[1].qty = 0
			elseif next(missingRes) then
				craftHistory[1].qty = 0
				sysStatus = "IDLE"
				craftErrTitle = "! NEED"
				craftErrLines = {}
				local shownCount = 0
				local totalMiss = 0
				for _ in pairs(missingRes) do totalMiss = totalMiss + 1 end
				for missingItem, countMiss in pairs(missingRes) do
					if shownCount < 6 then
						local mName = shortName(missingItem)
						table.insert(craftErrLines, mName .. ": x" .. countMiss)
						shownCount = shownCount + 1
					end
				end
				if totalMiss > shownCount then
					table.insert(craftErrLines, "... and " .. (totalMiss - shownCount) .. " more")
				end
				local blockedList = {}
				for bItem in pairs(blockedComps) do
					table.insert(blockedList, shortName(bItem))
				end
				table.sort(blockedList)
				if #blockedList > 0 then
					local joined = table.concat(blockedList, ", ")
					if #joined > 30 then
						table.insert(craftErrLines, "Can't craft:")
						table.insert(craftErrLines, "  " .. joined)
					else
						table.insert(craftErrLines, "Can't craft: " .. joined)
					end
				end
			elseif plan and #plan == 0 then
				craftHistory[1].qty = 0
				local inv = getInv()
				local curAmt = inv[itemToCraft] or 0
				if craftDonePopup and craftDonePopup.timer then os.cancelTimer(craftDonePopup.timer) end
				craftDonePopup = {item=itemToCraft, count=curAmt, timer=os.startTimer(10)}
				sysStatus = "IDLE"
			else
				if plan and #plan > 0 then
					local craftOk = runCraft(plan)
					local tlAttempts = 0
					while not Craft.cancelled and tlAttempts < 12 do
						local totalNow = groupAvail(itemToCraft, getInv())
						if totalNow >= craftQuantity then break end
						tlAttempts = tlAttempts + 1
						resetStock()
						local rPlan = planProd(itemToCraft, craftQuantity, true)
						if not (rPlan and #rPlan > 0) then break end
						local beforeTL = totalNow
						if runCraft(rPlan) then craftOk = true end
						if groupAvail(itemToCraft, getInv()) <= beforeTL then break end
					end
					local inv = getInv()
					local curAmt = inv[itemToCraft] or 0
					local postStockH = groupAvail(itemToCraft, inv)
					craftHistory[1].qty = math.max(0, postStockH - preStockH)
					if craftOk then
						if craftDonePopup and craftDonePopup.timer then os.cancelTimer(craftDonePopup.timer) end
						craftDonePopup = {item=itemToCraft, count=curAmt, timer=os.startTimer(10)}
						ntfyCraftDone(itemToCraft, craftHistory[1].qty, false)
					else
						ntfyCraftFail(itemToCraft)
					end
				else
					craftHistory[1].qty = 0
				end
				sysStatus = "IDLE"
				resetErr()
			end
		end
		return true
	end
	return false
end

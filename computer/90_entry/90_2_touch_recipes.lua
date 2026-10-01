function _touchRecipes(zone, x, y)
	if zone.id == "craft_subtab" then
		craftSubTab = zone.arg
		craftDevPage = 1
		if zone.arg == "TURTLE" or zone.arg == "CRAFTER" then
			selCraftType = "turtle"
			selOut = nil
			outPickMode = false
		end
		if zone.arg == "FLUID" then
			fluidLearnStage = "PICK_INPUT"
			learnInputs = {}
			learnMach = nil
			clearFluidDevs()
			fluidLearnPage = 1
			fluidScanStatus = ""
		else
			fluidLearnStage = nil
		end
		return true
	elseif zone.id == "crafter_detect" then
		local found = detectCrafters()
		crafterCfg().cells = found
		saveData()
		uiMessage = "Crafter grid: " .. #found .. " cells. Recipes use this cell list."
		if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
		uiMsgTimer = os.startTimer(4)
		return true
	elseif zone.id == "crafter_finish" then
		sysStatus = "MANUAL_CRAFT"
		uiMessage = runCrafterFinish()
		sysStatus = "IDLE"
		pendingTouches = {}
		return true
	elseif zone.id == "crafter_forget" then
		crafterJobClear()
		uiMessage = "Forgot unfinished cycle. Empty the grid by hand if needed."
		return true
	elseif zone.id == "crafter_lock_toggle" then
		local lk = crafterLocked()
		if lk == nil then
			uiMessage = "ERR: tag a redstone relay as [CLUTCH] in NETWORK"
		else
			local ok, err = crafterSetLock(not lk)
			if not ok then uiMessage = "ERR: " .. tostring(err) end
		end
		return true
	elseif zone.id == "craft_dev_prev" then
		craftDevPage = math.max(1, craftDevPage - 1)
		return true
	elseif zone.id == "craft_dev_next" then
		craftDevPage = craftDevPage + 1
		return true
	elseif zone.id == "craft_out_change" then
		if outPickMode then
			outPickMode = false
		elseif selOut then
			selOut = nil
		else
			outPickMode = true
		end
		return true
	elseif zone.id == "delete_ask" then
		pendDelItem = zone.arg
		return true
	elseif zone.id == "delete_confirm" then
		local delRec = Recipe.find(zone.arg)
		if type(delRec) == "table" and delRec.type == "fluid" then
			local frec = findFluidItemProd(zone.arg)
			if frec then removeFluidRef(frec) end
		end
		Recipe.remove(zone.arg)
		Recipe.setAlts(zone.arg, nil)
		Keep.remove(zone.arg)
		syncFluidStubs()
		saveData()
		pendDelItem = nil
		return true
	elseif zone.id == "delete_cancel" then
		pendDelItem = nil
		return true
	elseif zone.id == "open_alt_view" then
		altViewItem = zone.arg
		altViewFluid = nil
		curTab = "ALT_VIEW"
		return true
	elseif zone.id == "alt_out_edit" then
		altOutEdit = {rec = zone.recRef, targetName = zone.targetName,
			fluidRow = zone.fluidRow}
		isSettingKeep = false
		isRequestMode = false
		fluidCraftMode = nil
		fluidKeepName = nil
		queueEditIdx = nil
		craftQuantity = math.max(1, zone.curVal or 1)
		qtyOrigTab = "ALT_VIEW"
		curTab = "QUANTITY_PICKER"
		return true
	elseif zone.id == "alt_back" then
		altOutEdit = nil
		curTab = "RECIPES"
		if altViewFluid then modFilter = "FLUID" end
		altViewFluid = nil
		learnAsAlt = false
		learnAsAltItem = nil
		return true
	elseif zone.id == "alt_add" then
		learnAsAlt = true
		learnAsAltItem = altViewItem
		curTab = "+RECIPES"
		learnState = "IDLE"
		uiMessage = "Scan alt recipe, then [SAVE] to add as alt."
		return true
	elseif zone.id == "combined_up" or zone.id == "combined_dn" or zone.id == "combined_top" or zone.id == "combined_del" then
		local fkA = altViewFluid and fluidKey(altViewFluid) or nil
		local getPrimary = function()
			if fkA then return Fluids.find(fkA) else return Recipe.find(altViewItem) end
		end
		local setPrimary = function(v)
			if fkA then Fluids.set(fkA, v) else Recipe.set(altViewItem, v) end
		end
		if altViewItem or altViewFluid then
			local hasPrimary = getPrimary() ~= nil
			local alts = (fkA and Fluids.altsOf(fkA) or (altViewItem and Recipe.altsOf(altViewItem))) or {}
			local eIdx = zone.arg

			local function swapEntries(a, b)
				local aIsPrimary = hasPrimary and (a == 1)
				local bIsPrimary = hasPrimary and (b == 1)
				if aIsPrimary and not bIsPrimary then
					local altPos = b - (hasPrimary and 1 or 0)
					local oldPrimary = getPrimary()
					setPrimary(alts[altPos])
					alts[altPos] = oldPrimary
				elseif bIsPrimary and not aIsPrimary then
					local altPos = a - (hasPrimary and 1 or 0)
					local oldPrimary = getPrimary()
					setPrimary(alts[altPos])
					alts[altPos] = oldPrimary
				else
					local aAlt = a - (hasPrimary and 1 or 0)
					local bAlt = b - (hasPrimary and 1 or 0)
					alts[aAlt], alts[bAlt] = alts[bAlt], alts[aAlt]
				end
			end
			if zone.id == "combined_up" and eIdx > 1 then
				swapEntries(eIdx, eIdx - 1)
			elseif zone.id == "combined_dn" then
				local total = (hasPrimary and 1 or 0) + #alts
				if eIdx < total then swapEntries(eIdx, eIdx + 1) end
			elseif zone.id == "combined_top" and eIdx > 1 then
				for i = eIdx, 2, -1 do swapEntries(i, i - 1) end
			elseif zone.id == "combined_del" then
				local altPos = eIdx - (hasPrimary and 1 or 0)
				if altPos >= 1 and altPos <= #alts then
					table.remove(alts, altPos)
				end
			end
			if fkA then
				if #alts == 0 then alts = nil end
				Fluids.setAlts(fkA, alts)
				syncFluidStubs()
			else
				if #alts == 0 then alts = nil end
				Recipe.setAlts(altViewItem, alts)
			end
			saveData()
		end
		return true
	elseif zone.id == "prev_page" then
		curPage = math.max(1, curPage - 1)
		return true
	elseif zone.id == "next_page" then
		curPage = curPage + 1
		return true
	elseif zone.id == "scan_recipes" then
		scanActive = true
		drawUI()
		local sortedScan = {}
		for iName in pairs(Recipe.all()) do table.insert(sortedScan, iName) end
		table.sort(sortedScan)
		local filteredScan = {}
		for _, iName in ipairs(sortedScan) do
			local modId = iName:match("^([^:]+):") or "minecraft"
			local sName = shortName(iName)
			if (modFilter == "All" or modFilter == modId) and
			(srchFilter == "" or sName:lower():find(srchFilter:lower(), 1, true)) then
				table.insert(filteredScan, iName)
			end
		end
		local _, mH = monitor.getSize()
		local sRowY = 16
		local iPP   = mH - sRowY - 3
		local sIdx  = ((curPage - 1) * iPP) + 1
		local eIdx  = math.min(sIdx + iPP - 1, #filteredScan)
		local snap  = getInv()
		for i = sIdx, eIdx do
			local iName = filteredScan[i]
			local _, missing, blocked = planProd(iName, 1, false, snap)
			local blockedInfo = {}
			for bItem in pairs(blocked) do
				local _, bMissing, _ = planProd(bItem, 1, false, snap)
				blockedInfo[bItem] = {missing = bMissing}
			end
			local directAvail2  = groupAvail(iName, snap)
			local maxCraftable  = 0
			local snapCraft2 = {}
			for k, v in pairs(snap) do snapCraft2[k] = v end
			snapCraft2[iName] = 0
			local alts = Groups.altsOf(iName)
			if alts then
				for _, alt in ipairs(alts) do snapCraft2[alt] = 0 end
			end
			if not next(missing) then
				local _, qm1, _ = planProd(iName, 1, false, snapCraft2)
				if not next(qm1) then
					local _, qm100, _ = planProd(iName, 100, false, snapCraft2)
					if not next(qm100) then
						local _, bigMissing, _ = planProd(iName, 10000, false, snapCraft2)
						if not next(bigMissing) then
							maxCraftable = 10000
						else
							local lo2, hi2 = 100, 1000
							while hi2 < 10000 do
								local _, m2, _ = planProd(iName, hi2, false, snapCraft2)
								if next(m2) then break end
								lo2 = hi2; hi2 = math.min(hi2 * 4, 10000)
							end
							while hi2 - lo2 > 1 do
								local mid2 = math.floor((lo2 + hi2) / 2)
								local _, mm2, _ = planProd(iName, mid2, false, snapCraft2)
								if not next(mm2) then lo2 = mid2 else hi2 = mid2 end
							end
							maxCraftable = lo2
						end
					else
						local lo, hi = 1, 99
						while hi - lo > 1 do
							local mid = math.floor((lo + hi) / 2)
							local _, mm, _ = planProd(iName, mid, false, snapCraft2)
							if not next(mm) then lo = mid else hi = mid end
						end
						maxCraftable = lo
					end
				end
			end
			local hasMach2, missMach2 = checkMachine(Recipe.find(iName))
			recipesScan[iName] = {missing = missing, blocked = blocked, blockedInfo = blockedInfo, maxCraftable = maxCraftable, noMachine = not hasMach2, missingMach = missMach2}
		end
		scanFluidsNow()
		scanActive = true
		if scanTimer then os.cancelTimer(scanTimer) end
		scanTimer = os.startTimer(3)
		return true
	elseif zone.id == "scan_all_recipes" then
		allScanActive = true
		drawUI()
		scanRecipesNow()
		scanFluidsNow()
		allScanActive = false
		scanActive = true
		if scanTimer then os.cancelTimer(scanTimer) end
		scanTimer = os.startTimer(3)
		return true
	elseif zone.id == "show_machine_info" then
		local sr = recipesScan[zone.arg]
		machInfoPopup = {item = zone.arg, machineName = sr and sr.missingMach or "?"}
		return true
	elseif zone.id == "close_machine_info" then
		machInfoPopup = nil
		return true
	elseif zone.id == "show_craft_info" then
		local ciSnap = getInv()
		local _, ciMiss, ciBlock = planProd(zone.arg, 1, false, ciSnap)
		local ciDetails = {}
		for bItem in pairs(ciBlock) do
			local ciDetailSnap = {}
			for k, v in pairs(ciSnap) do ciDetailSnap[k] = v end
			ciDetailSnap[bItem] = 0
			local _, bm, _ = planProd(bItem, 1, false, ciDetailSnap)
			ciDetails[bItem] = {missing = bm}
		end
		if not next(ciMiss) and not next(ciBlock) then
			local ciDirect = groupAvail(zone.arg, ciSnap)
			local _, beyMiss, beyBlock = planProd(zone.arg, ciDirect + 1, false, ciSnap)
			if next(beyMiss) or next(beyBlock) then
				ciMiss  = beyMiss
				ciBlock = beyBlock
				ciDetails = {}
				for bItem in pairs(beyBlock) do
					local ciDetailSnap = {}
					for k, v in pairs(ciSnap) do ciDetailSnap[k] = v end
					ciDetailSnap[bItem] = 0
					local _, bm, _ = planProd(bItem, 1, false, ciDetailSnap)
					ciDetails[bItem] = {missing = bm}
				end
			end
		end
		if recipesScan[zone.arg] then
			recipesScan[zone.arg].missing       = ciMiss
			recipesScan[zone.arg].blocked       = ciBlock
			recipesScan[zone.arg].blockedInfo = ciDetails
		else
			recipesScan[zone.arg] = {missing=ciMiss, blocked=ciBlock, blockedInfo=ciDetails, maxCraftable=0}
		end
		craftInfoPop = {item = zone.arg}
		return true
	elseif zone.id == "close_craft_info" then
		craftInfoPop = nil
		return true
	elseif zone.id == "open_history" then
		if historyPopup then
			historyPopup = nil
		else
			historyPopup = {page = 1, maxCache = {}}
		end
		return true
	elseif zone.id == "history_scan" then
		if historyPopup then
			local hSnap = getInv()
			local histFstock = {}
			for k, v in pairs(getFluidCached()) do histFstock[fluidNameOf(k)] = v end
			local hCache = {}
			for _, hEntry in ipairs(craftHistory) do
				local hItem = hEntry.item
				if hEntry.fluid then
					local fck = "f:" .. hItem
					if hCache[fck] == nil then
						local mx = maxFluid(hItem, histFstock, hSnap, {})
						hCache[fck] = math.max(0, mx - (histFstock[hItem] or 0))
					end
				elseif hCache[hItem] == nil and Recipe.find(hItem) then
					local hSnapC = {}
					for k, v in pairs(hSnap) do hSnapC[k] = v end
					hSnapC[hItem] = 0
					local alts = Groups.altsOf(hItem)
					if alts then
						for _, alt in ipairs(alts) do hSnapC[alt] = 0 end
					end
					local _, hm1, _ = planProd(hItem, 1, false, hSnapC)
					if next(hm1) then
						hCache[hItem] = 0
					else
						local _, hm100, _ = planProd(hItem, 100, false, hSnapC)
						if not next(hm100) then
							hCache[hItem] = 100
						else
							local lo, hi = 1, 99
							while hi - lo > 1 do
								local mid = math.floor((lo + hi) / 2)
								local _, hmm, _ = planProd(hItem, mid, false, hSnapC)
								if not next(hmm) then lo = mid else hi = mid end
							end
							hCache[hItem] = lo
						end
					end
				elseif hCache[hItem] == nil then
					hCache[hItem] = 0
				end
			end
			historyPopup.maxCache = hCache
		end
		return true
	elseif zone.id == "close_history" then
		historyPopup = nil
		return true
	elseif zone.id == "history_prev" then
		if historyPopup then
			historyPopup.page = math.max(1, (historyPopup.page or 1) - 1)
		end
		return true
	elseif zone.id == "history_next" then
		if historyPopup then
			local _, mH = monitor.getSize()
			local hPerPage2 = math.max(4, (mH or 24) - 20)
			local totPg2 = math.max(1, math.ceil(#craftHistory / hPerPage2))
			historyPopup.page = math.min(totPg2, (historyPopup.page or 1) + 1)
		end
		return true
	elseif zone.id == "history_craft" then
		historyPopup = nil
		itemToCraft = zone.arg
		fluidCraftMode = nil
		fluidKeepName = nil
		isSettingKeep = false
		isRequestMode = false
		qtyOrigTab = "RECIPES"
		local pickerSnap = getInvCached()
		craftQuantity = pickerSnap[zone.arg] or 0
		pickerCraftable = 0
		pickerCapped = false
		pickerMaxSet = false
		if Config.autoMaxCalc ~= false then pickerMax() end
		curTab = "QUANTITY_PICKER"
		return true
	elseif zone.id == "history_craft_fluid" then
		historyPopup = nil
		local hprods = fluidProducers(zone.arg)
		if hprods[1] then fluidCraftFlow(hprods[1].recipe, zone.arg) end
		return true
	elseif zone.id == "history_req" then
		historyPopup = nil
		itemToCraft = zone.arg
		fluidCraftMode = nil
		fluidKeepName = nil
		local inv = getInvCached()
		reqMaxQty = inv[zone.arg] or 0
		if reqMaxQty == 0 then
			local alts = Groups.altsOf(zone.arg)
			if alts then
				for _, altName in ipairs(alts) do
					if altName ~= zone.arg then
						reqMaxQty = reqMaxQty + (inv[altName] or 0)
					end
				end
			end
		end
		craftQuantity = math.min(1, reqMaxQty)
		isSettingKeep = false
		isRequestMode = true
		qtyOrigTab = "RECIPES"
		curTab = "QUANTITY_PICKER"
		return true
	elseif zone.id == "error_edit_machine" then
		resetErr()
		craftErrEdit = {}
		local rec = Recipe.find(zone.arg)
		if rec then
			curTab = "RECIPES"
			recipeEditPop = {
				item          = zone.arg,
				altIdx        = nil,
				isItemScope   = false,
				origMachine   = rec.machine_name,
				selected      = rec.machine_name,
				confirmGlobal = false,
				page          = 1
			}
		end
		return true
	elseif zone.id == "open_recipe_edit" then
		local altIdx = zone.altIdx
		local rec
		if altIdx then
			local alts = Recipe.altsOf(zone.arg)
			rec = alts and alts[altIdx]
		else
			rec = Recipe.find(zone.arg)
		end
		if rec then
			recipeEditPop = {
				item          = zone.arg,
				altIdx        = altIdx,
				isItemScope   = zone.fromAltView == true,
				origMachine   = rec.machine_name,
				selected      = rec.machine_name,
				confirmGlobal = false,
				page          = 1
			}
		end
		return true
	elseif zone.id == "recipe_edit_select" then
		if recipeEditPop then
			recipeEditPop.selected = zone.arg
		end
		return true
	elseif zone.id == "recipe_edit_apply" then
		if recipeEditPop and recipeEditPop.selected then
			local rec
			if recipeEditPop.fluid then
				rec = recipeEditPop.fluidRecipeRef
				if rec then
					rec.machine_name = recipeEditPop.selected
					syncFluidStubs()
					saveData()
				end
				recipeEditPop = nil
			else
				if recipeEditPop.altIdx then
					local alts = Recipe.altsOf(recipeEditPop.item)
					rec = alts and alts[recipeEditPop.altIdx]
				else
					rec = Recipe.find(recipeEditPop.item)
				end
				if rec then
					rec.machine_name = recipeEditPop.selected
					rec.imported = nil
					if rec.type == "fluid" and rec.fluid_key then
						local fr = Fluids.find(rec.fluid_key)
						if fr then fr.machine_name = recipeEditPop.selected; fr.imported = nil end
						syncFluidStubs()
					end
					saveData()
				end
				recipeEditPop = nil
			end
		end
		return true
	elseif zone.id == "recipe_edit_global" then
		if recipeEditPop then
			recipeEditPop.confirmGlobal = true
		end
		return true
	elseif zone.id == "recipe_edit_confirm_global" then
		if recipeEditPop and recipeEditPop.selected then
			local oldMachine = recipeEditPop.origMachine
			local newMachine = recipeEditPop.selected
			if recipeEditPop.isItemScope then
				local iRec = Recipe.find(recipeEditPop.item)
				if iRec and iRec.machine_name == oldMachine then
					iRec.machine_name = newMachine
					iRec.imported = nil
				end
				if iRec and iRec.type == "fluid" and iRec.fluid_key then
					local fr = Fluids.find(iRec.fluid_key)
					if fr and fr.machine_name == oldMachine then fr.machine_name = newMachine; fr.imported = nil end
				end
				local iAlts = Recipe.altsOf(recipeEditPop.item)
				if iAlts then
					for _, rData in ipairs(iAlts) do
						if rData.machine_name == oldMachine then
							rData.machine_name = newMachine
							rData.imported = nil
						end
					end
				end
			else
				for _, rData in pairs(Recipe.all()) do
					if rData.machine_name == oldMachine then
						rData.machine_name = newMachine
						rData.imported = nil
					end
				end
				for _, fr in pairs(Fluids.all()) do
					if fr.machine_name == oldMachine then fr.machine_name = newMachine; fr.imported = nil end
				end
				for _, alts in pairs(Fluids.allAlts()) do
					for _, fr in ipairs(alts) do
						if fr.machine_name == oldMachine then fr.machine_name = newMachine; fr.imported = nil end
					end
				end
			end
			syncFluidStubs()
			saveData()
			recipeEditPop = nil
		end
		return true
	elseif zone.id == "close_recipe_edit" then
		if recipeEditPop then
			if recipeEditPop.confirmGlobal then
				recipeEditPop.confirmGlobal = false
			else
				recipeEditPop = nil
			end
		end
		return true
	elseif zone.id == "recipe_edit_prev" then
		if recipeEditPop then
			recipeEditPop.page = math.max(1, (recipeEditPop.page or 1) - 1)
		end
		return true
	elseif zone.id == "recipe_edit_next" then
		if recipeEditPop then
			recipeEditPop.page = (recipeEditPop.page or 1) + 1
		end
		return true
	elseif zone.id == "trigger_search" then
		isSearch = true
		drawUI()
		term.clear() term.setCursorPos(1,1)
		write("Enter Search query: ")
		local srInput = timedRead(5)
		isSearch = false
		if srInput ~= nil and srInput ~= "" then srchFilter = srInput end
		curPage = 1
		return true
	elseif zone.id == "clear_search" then
		srchFilter = ""
		curPage = 1
		return true
	end
	return false
end

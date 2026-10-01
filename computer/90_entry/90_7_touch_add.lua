local function learnedTools_()
	if not (learnedTools and next(learnedTools)) then return nil end
	local t = {}
	for tn in pairs(learnedTools) do t[tn] = true end
	return t
end

local function buildLearnedRecipe(count, ingredients)
	local cells = nil
	if learnedType == "crafter" and learnedGridCells then
		cells = {}
		for i, n in ipairs(learnedGridCells) do cells[i] = n end
	end
	return {
		type          = learnedType,
		machine_name  = learnedMach,
		output_count  = count,
		method        = (learnedType == "turtle") and "turtle" or learnedMach,
		ingredients   = ingredients or learnedIngs,
		output_device = learnedOut,
		tools         = learnedTools_(),
		grid_cells    = cells,
	}
end

function _touchAdd(zone, x, y)
	if zone.id == "add_recipe_action" then
		sysStatus = "MANUAL_CRAFT"
		if craftSubTab == "CRAFTER" then
			uiMessage = runCrafterSearch()
		else
			uiMessage = runMachineSearch()
		end
		sysStatus = "IDLE"
		pendingTouches = {}
		return true
	elseif zone.id == "learn_save_as_alt" then
		if learnedResult then
			local targetName = learnedResult.name
			local alts = Recipe.altsOf(targetName) or {}
			table.insert(alts, buildLearnedRecipe(learnedResult.count))
			Recipe.setAlts(targetName, alts)
			saveData()
			uiMessage = "Alt added: " .. (shortName(targetName))
			if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
			uiMsgTimer = os.startTimer(3)
		end
		clearLearn()
		learnState = "IDLE"
		return true
	elseif zone.id == "learn_save" then
		if learnedResult then
			if learnAsAlt then
				local targetName = learnedResult.name
				local alts = Recipe.altsOf(targetName) or {}
				table.insert(alts, buildLearnedRecipe(learnedResult.count))
				Recipe.setAlts(targetName, alts)
				saveData()
				altViewItem = targetName
				curTab = "ALT_VIEW"
				learnAsAlt = false
				learnAsAltItem = nil
			else
				local outs = (learnedType ~= "turtle" and learnedOutputs and #learnedOutputs > 0)
				and learnedOutputs or {{name = learnedResult.name, count = learnedResult.count}}
				local altSaved = nil
				for _, o in ipairs(outs) do
					local ingCopy = {}
					for ii = 1, #learnedIngs do ingCopy[ii] = learnedIngs[ii] end
					local rd = buildLearnedRecipe(o.count, ingCopy)
					local ex = Recipe.find(o.name)
					if type(ex) == "table" and ex.type ~= "fluid" then
						local alts = Recipe.altsOf(o.name) or {}
						table.insert(alts, rd)
						Recipe.setAlts(o.name, alts)
						if not altSaved then altSaved = o.name end
					else
						Recipe.set(o.name, rd)
					end
				end
				saveData()
				if altSaved then
					altViewItem = altSaved
					curTab = "ALT_VIEW"
				end
			end
		end
		clearLearn()
		learnedResult = nil
		learnedOutputs = nil
		learnState = "IDLE"
		drawUI()
		return true
	elseif zone.id == "learn_cancel" then
		clearLearn()
		learnedResult = nil
		learnedOutputs = nil
		learnState = "IDLE"
		if learnAsAlt then
			curTab = "ALT_VIEW"
			learnAsAlt = false
			learnAsAltItem = nil
		end
		drawUI()
		return true
	elseif zone.id == "machine_label" then
		local mName = zone.arg
		local cur = Machines.label(mName) or ""
		drawUI()
		term.clear(); term.setCursorPos(1,1)
		local mId = shortName(mName)
		write(mId .. " label (Enter=clear): ")
		local lbl = timedRead(15)
		if lbl ~= nil then
			if lbl == "" then lbl = nil end
			Machines.setLabel(mName, lbl)
			saveData()
		end
		return true
	elseif zone.id == "group_exclude" then
		Machines.exclude(zone.arg, true)
		saveData()
		return true
	elseif zone.id == "group_include" then
		Machines.exclude(zone.arg, false)
		saveData()
		return true
	elseif zone.id == "cgrp_new" then
		custGrpPopup = {editIdx=nil, name="", selected={}, page=1}
		return true
	elseif zone.id == "cgrp_edit" then
		local cg = CustomMachineGroups[zone.arg]
		if cg then
			local sel = {}
			for _, m in ipairs(cg.machines) do sel[m] = true end
			custGrpPopup = {editIdx=zone.arg, name=cg.name, selected=sel, page=1}
		end
		return true
	elseif zone.id == "cgrp_del" then
		table.remove(CustomMachineGroups, zone.arg)
		saveData()
		return true
	elseif zone.id == "cgrp_remove" then
		local gIdx2 = zone.arg[1]
		local mDel  = zone.arg[2]
		local cg2   = CustomMachineGroups[gIdx2]
		if cg2 then
			for mi2, mc in ipairs(cg2.machines) do
				if mc == mDel then table.remove(cg2.machines, mi2); break end
			end
			if #cg2.machines == 0 then
				table.remove(CustomMachineGroups, gIdx2)
			end
			saveData()
		end
		return true
	elseif zone.id == "cgrp_popup_name" then
		if custGrpPopup then
			drawUI()
			term.clear(); term.setCursorPos(1,1)
			write("Group name: ")
			local inp = read()
			if inp and inp ~= "" then custGrpPopup.name = inp end
		end
		return true
	elseif zone.id == "cgrp_popup_toggle" then
		if custGrpPopup then
			local mn = zone.arg
			if custGrpPopup.selected[mn] then
				custGrpPopup.selected[mn] = nil
			else
				custGrpPopup.selected[mn] = true
			end
		end
		return true
	elseif zone.id == "cgrp_popup_prev" then
		if custGrpPopup then
			custGrpPopup.page = math.max(1, (custGrpPopup.page or 1) - 1)
		end
		return true
	elseif zone.id == "cgrp_popup_next" then
		if custGrpPopup then
			custGrpPopup.page = (custGrpPopup.page or 1) + 1
		end
		return true
	elseif zone.id == "cgrp_popup_cancel" then
		custGrpPopup = nil
		return true
	elseif zone.id == "cgrp_popup_save" then
		if custGrpPopup then
			local gName3 = custGrpPopup.name
			if gName3 == "" then gName3 = "Group " .. (#CustomMachineGroups + 1) end
			local machList = {}
			for mn, _ in pairs(custGrpPopup.selected) do
				table.insert(machList, mn)
			end
			table.sort(machList)
			local newCG = {name=gName3, machines=machList}
			if custGrpPopup.editIdx then
				CustomMachineGroups[custGrpPopup.editIdx] = newCG
			else
				table.insert(CustomMachineGroups, newCG)
			end
			custGrpPopup = nil
			saveData()
		end
		return true
	end
	return false
end

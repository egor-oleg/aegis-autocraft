-- screens.lua was one huge file. before splitting into tabs/popups/dispatch
-- i backed up src/ to copy folder at repo root. diff there if rendering broke

function getMods()
	local mods = { "All" }
	local seen = { All = true }
	for itemName in pairs(Recipe.all()) do
		local modId = itemName:match("^([^:]+):") or "minecraft"
		if not seen[modId] then seen[modId] = true; table.insert(mods, modId) end
	end
	table.sort(mods, function(a, b)
			if a == "All" then return true end
			if b == "All" then return false end
			if a == "minecraft" then return true end
			if b == "minecraft" then return false end
			return a < b
		end)
	return mods
end


function drawTabBtn(x, y, name, activeTab, zones)
	if name == activeTab then
		drawText(x, y, " " .. name .. " ", colors.white, colors.gray)
		drawText(x, y + 1, string.rep("-", #name + 2), colors.lime, colors.black)
	else
		drawText(x, y, " " .. name .. " ", colors.gray, colors.black)
	end
	table.insert(zones, {id="switch_tab", arg=name, x1=x, x2=x + #name + 1, y=y})
	return x + #name + 3
end


function drawGroupsTab(w, h, touchZones, popupRect)
	UI.text(2, 9, "MACHINE GROUPS:")
	UI.btnR(touchZones, w, 9, " [+ NEW GROUP] ", "ok", "cgrp_new")
	UI.text(2, 10, "Excluded machines use only their own recipe.", UI.C.muted)
	UI.rule(11, w)
	local all = listMachines()
	local baseMap = {}
	for _, m in ipairs(all) do
		local base = getMachBase(m)
		if not baseMap[base] then baseMap[base] = {} end
		table.insert(baseMap[base], m)
	end
	local rows = {}
	for ci, cg in ipairs(CustomMachineGroups) do
		table.insert(rows, {type="custom_header", name=cg.name, idx=ci, count=#cg.machines})
		for _, cm in ipairs(cg.machines) do
			table.insert(rows, {type="custom_machine", name=cm, groupIdx=ci})
		end
	end
	local tList = {}
	for tName, enabled in pairs(Config.turtles or {}) do
		if enabled then table.insert(tList, tName) end
	end
	table.sort(tList)
	if #tList > 0 then
		table.insert(rows, {type="header", base="TURTLE GROUP", total=#tList, excluded=0, isTurtle=true})
		for _, tName in ipairs(tList) do
			local isOnline = peripheral.wrap(tName) ~= nil
			table.insert(rows, {type="turtle_entry", name=tName, offline=not isOnline})
		end
	end
	local newTurtles = {}
	for _, p in ipairs(peripheral.getNames()) do
		if not SYSTEM_SIDES[p] and p ~= MONITOR_SIDE and p ~= Config.train_box
		and not (Config.turtles and Config.turtles[p]) and not Config.storages[p] then
			local tp = peripheral.wrap(p)
			if tp and tp.craft then table.insert(newTurtles, p) end
		end
	end
	table.sort(newTurtles)
	if #newTurtles > 0 then
		table.insert(rows, {type="header", base="NEW TURTLES", total=#newTurtles, excluded=0, isTurtle=true})
		for _, tName in ipairs(newTurtles) do
			table.insert(rows, {type="turtle_new", name=tName})
		end
	end
	local bases = {}
	for base in pairs(baseMap) do table.insert(bases, base) end
	table.sort(bases)
	for _, base in ipairs(bases) do
		local machines = baseMap[base]
		table.sort(machines)
		if #machines > 1 then
			local excN = 0
			for _, m in ipairs(machines) do if Machines.excluded(m) then excN = excN + 1 end end
			table.insert(rows, {type="header", base=base, total=#machines, excluded=excN, isTurtle=false})
			for _, m in ipairs(machines) do
				table.insert(rows, {type="machine", name=m, isExcluded=Machines.excluded(m)})
			end
		end
	end
	if #rows == 0 then
		drawText(2, 13, "No multi-machine groups detected.", colors.gray)
		drawText(2, 14, "Connect machines with matching names", colors.gray)
		drawText(2, 15, "(e.g. furnace_0, furnace_1, ...)", colors.gray)
	else
		local ry0 = 12
		local perPage = h - ry0 - 2
		local pages = math.max(1, math.ceil(#rows / perPage))
		if curPage > pages then curPage = pages end
		local iStart = ((curPage - 1) * perPage) + 1
		local iEnd   = math.min(iStart + perPage - 1, #rows)
		local rowY = ry0
		for idx = iStart, iEnd do
			local row = rows[idx]
			if row.type == "custom_header" then
				local editS, delS = " [EDIT] ", " [DEL] "
				drawText(1, rowY, string.rep(" ", w), UI.C.fg, UI.C.rowBg)
				local delX2  = UI.btnR(touchZones, w, rowY, delS, "danger", "cgrp_del", row.idx)
				local editX2 = UI.btnR(touchZones, delX2 - 2, rowY, editS, "mute", "cgrp_edit", row.idx)
				local hdr2 = string.format(" [%s]  %d machines", row.name, row.count)
				drawText(2, rowY, hdr2:sub(1, editX2 - 3), colors.orange, colors.gray)
			elseif row.type == "custom_machine" then
				_bufClearLine(rowY, colors.black)
				local remS = " [REMOVE] "
				UI.text(4, rowY, getMachName(row.name):sub(1, w - 4 - #remS), UI.C.hi)
				UI.btnR(touchZones, w, rowY, remS, "mute", "cgrp_remove", {row.groupIdx, row.name})
			elseif row.type == "header" then
				local cLbl = row.isTurtle and "turtles" or "machines"
				local hdr = string.format(" [%s]  %d %s", row.base, row.total, cLbl)
				if row.excluded > 0 then hdr = hdr .. string.format("  (%d excluded)", row.excluded) end
				drawText(1, rowY, string.rep(" ", w), UI.C.fg, UI.C.rowBg)
				drawText(2, rowY, hdr, row.isTurtle and UI.C.info or UI.C.accent, UI.C.rowBg)
			elseif row.type == "turtle_entry" then
				_bufClearLine(rowY, colors.black)
				if row.offline then
					UI.text(4, rowY, row.name, UI.C.danger)
					UI.text(w - 19, rowY, "[OFFLINE]", UI.C.danger)
					UI.btn(touchZones, w - 9, rowY, " [REMOVE] ", "mute", "turtle_remove", row.name)
				else
					UI.text(4, rowY, row.name, UI.C.info)
					UI.text(w - 14, rowY, "[parallel craft]", UI.C.muted)
				end
			elseif row.type == "turtle_new" then
				_bufClearLine(rowY, colors.black)
				UI.text(4, rowY, row.name, UI.C.warn)
				UI.btn(touchZones, w - 8, rowY, " [+ADD] ", "warn", "turtle_add", row.name)
			else
				local isExc = row.isExcluded
				_bufClearLine(rowY, colors.black)
				UI.text(4, rowY, getMachName(row.name), isExc and UI.C.muted or UI.C.fg)
				if isExc then
					UI.text(w - 12, rowY, "[EXCLUDED]", UI.C.danger)
					UI.btn(touchZones, w - 21, rowY, " [INCLUDE] ", "okhi", "group_include", row.name)
				else
					UI.btn(touchZones, w - 11, rowY, " [EXCLUDE] ", "mute", "group_exclude", row.name)
				end
			end
			rowY = rowY + 1
		end
		UI.pager(touchZones, h - 1, w, curPage, pages)
	end
	if custGrpPopup then
		local pW = math.min(w - 4, 88)
		local allM = listMachines()
		table.sort(allM, function(a, b) return getMachName(a):lower() < getMachName(b):lower() end)
		local rowsN = math.max(3, h - 10)
		local pH = math.min(rowsN + 6, h - 2)
		rowsN = pH - 6
		local perPage = rowsN * 3
		local cpPage = custGrpPopup.page or 1
		local cpTotal = math.max(1, math.ceil(#allM / perPage))
		if cpPage > cpTotal then cpPage = cpTotal; custGrpPopup.page = cpPage end
		local pX, pY, rect = UI.popup(pW, pH, w, h, custGrpPopup.editIdx and " EDIT CUSTOM GROUP " or " NEW CUSTOM GROUP ", "cool")
		popupRect = rect
		local nDisp = custGrpPopup.name ~= "" and custGrpPopup.name or "(tap to set)"
		local setNS = " [SET NAME] "
		drawText(pX+1, pY+1, (" Name: " .. nDisp):sub(1, pW - #setNS - 2), colors.white, colors.gray)
		drawText(pX+pW-#setNS-1, pY+1, setNS, colors.black, colors.orange)
		table.insert(touchZones, {id="cgrp_popup_name", x1=pX+pW-#setNS-1, x2=pX+pW-2, y=pY+1})
		drawText(pX+1, pY+2, string.rep("-", pW-2), colors.lightGray, colors.gray)
		local selHdr = " SELECT MACHINES:"
		drawText(pX+1, pY+3, selHdr, colors.yellow, colors.gray)
		if cpTotal > 1 then
			local prevPS = " [<] "; local nextPS = " [>] "
			local pgInfoS = tostring(cpPage) .. "/" .. tostring(cpTotal)
			local pgX2 = pX + pW - #prevPS - #pgInfoS - #nextPS - 1
			local prevCol = cpPage > 1 and colors.white or colors.lightGray
			local nextCol = cpPage < cpTotal and colors.white or colors.lightGray
			drawText(pgX2,                   pY+3, prevPS,  prevCol, colors.gray)
			drawText(pgX2+#prevPS,            pY+3, pgInfoS, colors.white, colors.gray)
			drawText(pgX2+#prevPS+#pgInfoS,  pY+3, nextPS,  nextCol, colors.gray)
			if cpPage > 1 then
				table.insert(touchZones, {id="cgrp_popup_prev", x1=pgX2, x2=pgX2+#prevPS-1, y=pY+3})
			end
			if cpPage < cpTotal then
				table.insert(touchZones, {id="cgrp_popup_next", x1=pgX2+#prevPS+#pgInfoS, x2=pgX2+#prevPS+#pgInfoS+#nextPS-1, y=pY+3})
			end
		end
		local cw = math.floor((pW - 2) / 3)
		local mS = (cpPage - 1) * perPage + 1
		local mE = math.min(mS + perPage - 1, #allM)
		for rowI = 0, rowsN - 1 do
			if mS + rowI <= mE then
				drawText(pX + cw, pY + 4 + rowI, "|", colors.lightGray, colors.gray)
				drawText(pX + 2 * cw, pY + 4 + rowI, "|", colors.lightGray, colors.gray)
			end
		end
		for mi = mS, mE do
			local idx0  = mi - mS
			local colI  = math.floor(idx0 / rowsN)
			local rowI  = idx0 % rowsN
			local cellX = pX + 1 + colI * cw
			local mRowY = pY + 4 + rowI
			local nm    = allM[mi]
			local isSel = custGrpPopup.selected[nm] == true
			local chk   = isSel and "[x]" or "[ ]"
			local chkFg = isSel and colors.lime or colors.white
			local disp  = getMachName(nm)
			drawText(cellX, mRowY, (chk .. " " .. disp):sub(1, cw - 2), chkFg, colors.gray)
			table.insert(touchZones, {id="cgrp_popup_toggle", arg=nm, x1=cellX, x2=cellX + cw - 2, y=mRowY})
		end
		drawText(pX+1, pY+pH-2, string.rep("-", pW-2), colors.lightGray, colors.gray)
		local canS = " [CANCEL] "; local savS = " [SAVE] "
		drawText(pX+1,           pY+pH-1, canS, colors.white, colors.red)
		drawText(pX+pW-#savS-1,  pY+pH-1, savS, colors.black, colors.lime)
		table.insert(touchZones, {id="cgrp_popup_cancel", x1=pX+1,          x2=pX+#canS,       y=pY+pH-1})
		table.insert(touchZones, {id="cgrp_popup_save",   x1=pX+pW-#savS-1, x2=pX+pW-2,        y=pY+pH-1})
	end
	return popupRect
end


function drawPlusTab(w, h, touchZones)
	local turtleTab = (craftSubTab == "TURTLE")
	local machTab   = (craftSubTab == "MACHINES")
	local fluidTab  = (craftSubTab == "FLUID")
	local crafterTab = (craftSubTab == "CRAFTER")
	if learnState == "IDLE" then
		UI.subTabs(touchZones, 9, w, {"TURTLE", "MACHINES", "FLUID", "CRAFTER"}, craftSubTab, "craft_subtab")
		UI.rule(11, w)
		if fluidTab then
			if not fluidLearnStage then fluidLearnStage = "PICK_INPUT" end
			drawFluidLearn(w, h, touchZones)
		elseif crafterTab then
			drawCrafterLearn(w, h, touchZones)
		elseif turtleTab then
			UI.textC(13, w, "Place recipe in center 3x3 of barrel,", UI.C.muted)
			UI.textC(14, w, "then press SCAN.", UI.C.soft)
		else
			local machines = listMachines()
			table.sort(machines, _cmpByDisplay)
			local listY = 13
			local cols = 3
			local maxRows = h - listY - 4
			local perPage = cols * maxRows
			local pages = math.max(1, math.ceil(#machines / perPage))
			if craftDevPage > pages then craftDevPage = pages end
			local mStart = ((craftDevPage - 1) * perPage) + 1
			local mEnd   = math.min(mStart + perPage - 1, #machines)
			local cw = math.floor(w / cols)
			if #machines == 0 then
				UI.textC(listY, w, "No machines connected.", UI.C.muted)
			else
				local sep1X = cw
				local sep2X = 2 * cw
				for ry = 0, maxRows - 1 do
					drawText(sep1X, listY + ry, "|", colors.gray, colors.black)
					drawText(sep2X, listY + ry, "|", colors.gray, colors.black)
				end
				for mIdx = mStart, mEnd do
					local li = mIdx - mStart
					local col = math.floor(li / maxRows)
					local row = li % maxRows
					local rowY = listY + row
					local colX = col * cw + 1
					local m = machines[mIdx]
					local nm = getMachName(m)
					local isSel = (selCraftType == m)
					local isOut = (selOut == m and m ~= selCraftType)
					if isOut then
						local nm2 = nm
						local maxName = cw - 5
						if #nm2 > maxName then nm2 = nm2:sub(1, maxName) end
						drawText(colX, rowY, "--", colors.lime, colors.gray)
						drawText(colX + 2, rowY, nm2, colors.white, colors.gray)
						drawText(colX + 2 + #nm2, rowY, "--", colors.lime, colors.gray)
					else
						local mBg = isSel and colors.gray or colors.black
						local mLabel = (isSel and "> " or "  ") .. nm
						local maxLabel = cw - 1
						if #mLabel > maxLabel then mLabel = mLabel:sub(1, maxLabel) end
						drawText(colX, rowY, mLabel, isSel and colors.white or colors.lightGray, mBg)
					end
					table.insert(touchZones, {id="select_device", arg=m, x1=colX, x2=colX+cw-1, y=rowY})
				end
				if pages > 1 then
					UI.pager(touchZones, h - 3, w, craftDevPage, pages, "craft_dev_prev", "craft_dev_next")
				end
			end
		end
		if machTab and selCraftType ~= "turtle" then
			local isSplit = (selOut ~= nil and selOut ~= selCraftType)
			local splitStyle = outPickMode and "hi" or (isSplit and "ok" or "mute")
			local splitS = " [ PULL ] "
			UI.btn(touchZones, math.floor((w - #splitS) / 2) + 1, h - 2, splitS, splitStyle, "craft_out_change")
		end
		if not fluidTab then
			local scanStr = " [ SCAN ] "
			UI.btn(touchZones, math.floor((w - #scanStr) / 2) + 1, h - 1, scanStr, "ok", "add_recipe_action")
			if uiMessage ~= "" then UI.textC(h - 2, w, uiMessage, UI.C.fg) end
		end
	elseif learnState == "AWAITING_DECISION" and learnedResult then
		local midY = math.floor(h / 2)
		local dubInfo = {type = learnedType, machine_name = learnedMach, ingredients = learnedIngs,
			grid_cells = learnedGridCells}
		if learnAsAlt then
			local sn = shortName(learnedResult.name)
			UI.textC(midY - 2, w, "ADD ALTERNATIVE RECIPE", UI.C.accent)
			UI.textC(midY - 1, w, "Alt for: " .. sn)
			if findDup(learnedResult.name, dubInfo) then
				UI.textC(midY, w, sn .. "  DUB", UI.C.danger)
			end
			local saveS, cnlS = " [ SAVE ALT ] ", " [ DISCARD ] "
			local btnX = math.floor((w - (#saveS + 2 + #cnlS)) / 2) + 1
			UI.btn(touchZones, btnX, midY + 1, saveS, "ok", "learn_save")
			UI.btn(touchZones, btnX + #saveS + 2, midY + 1, cnlS, "mute", "learn_cancel")
		else
			local outs = (learnedType ~= "turtle" and learnedOutputs and #learnedOutputs > 0)
			and learnedOutputs or {{name = learnedResult.name, count = learnedResult.count}}
			local nTools = 0
			if learnedTools then for _ in pairs(learnedTools) do nTools = nTools + 1 end end
			local titleY = math.max(11, midY - #outs - nTools - 1)
			UI.textC(titleY, w, "RECIPE SCAN RESULT", UI.C.accent)
			local ly = titleY + 1
			for _, o in ipairs(outs) do
				local ex = Recipe.find(o.name)
				local isReal = (type(ex) == "table" and ex.type ~= "fluid")
				local isDub = findDup(o.name, dubInfo)
				local sn = shortName(o.name)
				local line = isDub and ("x" .. o.count .. " " .. sn .. "  DUB")
				or ("x" .. o.count .. " " .. sn .. (isReal and "  -> +ALT" or "  -> NEW"))
				UI.textC(ly, w, line, isDub and UI.C.danger or (isReal and UI.C.hi or UI.C.accent))
				ly = ly + 1
			end
			if learnedTools then
				for tn in pairs(learnedTools) do
					UI.textC(ly, w, "tool: " .. (shortName(tn)), UI.C.info)
					ly = ly + 1
				end
			end
			local saveS, cnlS = " [ SAVE ] ", " [ DISCARD ] "
			local btnX = math.floor((w - (#saveS + 2 + #cnlS)) / 2) + 1
			UI.btn(touchZones, btnX, ly + 1, saveS, "ok", "learn_save")
			UI.btn(touchZones, btnX + #saveS + 2, ly + 1, cnlS, "mute", "learn_cancel")
		end
	end
end


function drawGitTab(w, h, touchZones)
	local hasRepo  = Config.github_repo and Config.github_repo ~= ""
	local hasTok   = Config.github_token and Config.github_token ~= ""
	local hasNtfy  = Config.ntfy_topic and Config.ntfy_topic ~= ""
	local repoV = hasRepo and string.rep("*", math.min(32, #Config.github_repo)) or "<not configured>"
	local tokV  = hasTok  and string.rep("*", math.min(32, #Config.github_token)) or "<not configured>"
	UI.text(2, 10, "Repo: ", UI.C.muted)
	UI.text(8, 10, repoV:sub(1, w - 8), hasRepo and UI.C.fg or UI.C.danger)
	UI.btn(touchZones, w - 8, 10, " [EDIT] ", gitActiveBtn == "git_set_repo" and "warn" or "mute", "git_set_repo")
	UI.text(2, 11, "Token:", UI.C.muted)
	UI.text(8, 11, tokV:sub(1, w - 8), hasTok and UI.C.fg or UI.C.danger)
	UI.btn(touchZones, w - 8, 11, " [EDIT] ", gitActiveBtn == "git_set_token" and "warn" or "mute", "git_set_token")
	UI.text(2, 12, "Ntfy: ", UI.C.muted)
	UI.text(8, 12, (hasNtfy and Config.ntfy_topic or "<off>"):sub(1, math.max(1, w - 17)), hasNtfy and UI.C.fg or UI.C.muted)
	UI.btn(touchZones, w - 8, 12, " [EDIT] ", gitActiveBtn == "git_set_ntfy" and "warn" or "mute", "git_set_ntfy")
	local logOn = (Config.debug_log == true)
	UI.text(2, 13, "Log: ", UI.C.muted)
	UI.text(7, 13, logOn and DBG_LOG_FILE or "<disabled>", logOn and UI.C.fg or UI.C.muted)
	UI.btn(touchZones, w - 8, 13, logOn and " [ ON ] " or " [ OFF ]", logOn and "ok" or "mute", "log_toggle")
	UI.rule(14, w)
	local canExport = not gitWorking and hasRepo and hasTok
	local canImport = not gitWorking and hasRepo
	local expS = " [ EXPORT TO GITHUB ] "
	local impS = " [ IMPORT FROM GITHUB ] "
	local expX = math.max(2, math.floor(w / 4) - math.floor(#expS / 2))
	local impX = math.max(expX + #expS + 2, math.floor(3 * w / 4) - math.floor(#impS / 2))
	local expStyle = (gitActiveBtn == "git_export") and "warn" or (canExport and "ok" or "mute")
	local impStyle = (gitActiveBtn == "git_import_list") and "warn" or (canImport and "cool" or "mute")
	UI.btn(touchZones, expX, 16, expS, expStyle, "git_export")
	UI.btn(touchZones, impX, 16, impS, impStyle, "git_import_list")
	UI.rule(18, w)
	if gitWorking then
		UI.text(2, 20, "[ Working... ]", UI.C.hi)
	elseif gitStatus ~= "" then
		UI.text(2, 20, gitStatus, gitStColor)
	end
	if gitImportMode and #gitFileList > 0 then
		local ctx = {list = gitFileList, page = gitImportPage, sel = gitSelFile,
			maxV = 8, hdr = " SELECT BACKUP TO IMPORT ", hdrStyle = "cool",
			selectId = "git_select_file", prevId = "git_import_prev", nextId = "git_import_next",
			confirmS = " [IMPORT] ", cancelS = " [CANCEL] ",
			confirmId = "git_confirm_import", cancelId = "git_cancel_import",
			selStyle = "ok", extraHdr = 2}
		gitImportPage = _drawGitPopup(w, h, touchZones, ctx)
	end
	if gitExportMode then
		local ctx = {list = gitExportList, page = gitExportPage, sel = gitExportSel,
			maxV = 7, hdr = " SELECT EXPORT TARGET ", hdrStyle = "ok",
			selectId = "git_export_select", prevId = "git_export_prev", nextId = "git_export_next",
			confirmS = " [EXPORT] ", cancelS = " [CANCEL] ",
			confirmId = "git_confirm_export", cancelId = "git_cancel_export",
			selStyle = "warn", newRow = "[ + NEW FILE ]", extraHdr = 3}
		gitExportPage = _drawGitPopup(w, h, touchZones, ctx)
	end
end


function _drawModFilter(w, touchZones, ctx)
	local modY = 9
	local arrowL, arrowR = " < ", " > "
	local areaX1 = 2 + #arrowL + 1
	local rowMax = (w - 1 - #arrowR - 1) - areaX1 + 1
	local modsNoAll, hasSpecial = {}, false
	for _, m in ipairs(ctx.mods) do
		if m == ctx.special.name then hasSpecial = true
		elseif m ~= "All" then table.insert(modsNoAll, m) end
	end

	local function front()
		local f = {}
		if hasSpecial then f[#f+1] = {name = ctx.special.name, disp = ctx.special.disp} end
		f[#f+1] = {name = "All", disp = " All "}
		return f
	end

	local function fits(items) local t = -1; for _, it in ipairs(items) do t = t + #it.disp + 1 end; return t <= rowMax end
	local function fillRow(row, i)
		while i <= #modsNoAll do
			local it = {name = modsNoAll[i], disp = " " .. modsNoAll[i] .. " "}
			table.insert(row, it)
			if not fits(row) then table.remove(row); return i end
			i = i + 1
		end
		return i
	end
	local pages, s = {}, 1
	while s <= #modsNoAll do
		local r1, r2 = front(), {}
		local ni = fillRow(r1, s)
		ni = fillRow(r2, ni)
		if ni == s then break end
		pages[#pages+1] = {r1, r2}
		s = ni
	end
	if #pages == 0 then pages[1] = {front(), {}} end
	local totalPg = #pages
	local page = ctx.pageVal
	if page > totalPg then page = totalPg end
	if page < 1 then page = 1 end
	local activeX, activeW, activeRow
	for ri = 1, 2 do
		local ry = modY + (ri - 1)
		local items = pages[page][ri]
		if #items > 0 then
			local rx = areaX1
			for _, it in ipairs(items) do
				local isAct = (it.name == ctx.current)
				local fg = (it.name == ctx.special.name) and ctx.special.fg
				or (isAct and colors.white or colors.gray)
				drawText(rx, ry, it.disp, fg, isAct and colors.gray or colors.black)
				if isAct then activeX, activeW, activeRow = rx, #it.disp, ry end
				UI.zone(touchZones, ctx.zoneId, it.name, rx, ry, #it.disp)
				rx = rx + #it.disp + 1
			end
		end
	end
	if activeX and activeRow == modY + 1 then
		drawText(activeX, activeRow + 1, string.rep("-", activeW), colors.lime, colors.black)
	end
	if totalPg > 1 then
		local lAct, rAct = page > 1, page < totalPg
		drawText(2, modY, arrowL, lAct and colors.white or colors.gray, lAct and colors.gray or colors.black)
		drawText(w - #arrowR, modY, arrowR, rAct and colors.white or colors.gray, rAct and colors.gray or colors.black)
		if lAct then
			UI.zone(touchZones, ctx.prevId, nil, 2, modY, #arrowL)
			UI.zone(touchZones, ctx.prevId, nil, 2, modY + 1, #arrowL)
		end
		if rAct then
			UI.zone(touchZones, ctx.nextId, nil, w - #arrowR, modY, #arrowR)
			UI.zone(touchZones, ctx.nextId, nil, w - #arrowR, modY + 1, #arrowR)
		end
	end
	return page
end


function drawStockFilter(w, stockInv, touchZones)
	local allMods, seen = {"All"}, {All = true}
	for itemName in pairs(stockInv) do
		local modId = itemName:match("^([^:]+):") or "minecraft"
		if not seen[modId] then seen[modId] = true; table.insert(allMods, modId) end
	end
	table.sort(allMods, function(a, b)
			if a == "All" then return true end;      if b == "All" then return false end
			if a == "minecraft" then return true end;if b == "minecraft" then return false end
			return a < b
		end)
	if stockFilter ~= "" then
		local q = stockFilter:lower()
		local hit = {All = true, [stockModFilter] = true}
		for itemName in pairs(stockInv) do
			local mid = itemName:match("^([^:]+):") or "minecraft"
			if not hit[mid] and shortName(itemName):lower():find(q, 1, true) then hit[mid] = true end
		end
		local kept = {}
		for _, m in ipairs(allMods) do if hit[m] then kept[#kept+1] = m end end
		allMods = kept
	end
	table.insert(allMods, 2, "TANK")
	stockFilterPage = _drawModFilter(w, touchZones, {
			mods = allMods, special = {name = "TANK", disp = " TANK ", fg = colors.cyan},
			current = stockModFilter, pageVal = stockFilterPage,
			zoneId = "stock_mod", prevId = "stock_mod_prev", nextId = "stock_mod_next",
		})
end


function drawStockTab(w, h, stockInv, touchZones)
	drawStockFilter(w, stockInv, touchZones)
	do
		local searchY = 12
		local dSearch  = (stockFilter == "") and "<type item name...>" or stockFilter
		local sColor   = (stockFilter == "") and (stockSearchOn and colors.lightGray or colors.gray) or colors.white
		local fullSrch = "FIND: [ " .. dSearch .. " ]"
		local srchX    = math.max(14, math.floor((w - #fullSrch) / 2) + 1)
		drawText(srchX, searchY, "FIND: ", colors.gray, colors.black)
		local sBgActive = stockSearchOn and colors.gray or colors.black
		drawText(srchX + 6, searchY, "[ " .. dSearch .. " ]", sColor, sBgActive)
		table.insert(touchZones, {id="stock_search", x1=srchX, x2=srchX+#fullSrch-1, y=searchY})
		if stockFilter ~= "" then
			local boxStr = "[ " .. dSearch .. " ]"
			drawText(srchX + 6, searchY + 1, string.rep("-", #boxStr), colors.lime, colors.black)
			drawText(srchX+#fullSrch+1, searchY, "[X]", colors.white, colors.red)
			table.insert(touchZones, {id="stock_clear_search", x1=srchX+#fullSrch+1, x2=srchX+#fullSrch+3, y=searchY})
		end
		if Config.train_box and Config.train_box ~= "" then
			local ulStr = " UNLOAD "
			UI.btn(touchZones, 2, searchY, ulStr, "mute", "pull_from_box")
			if unloadActive then UI.text(2, searchY + 1, string.rep("-", #ulStr), UI.C.accent) end
		end
		local optStr = " OPTIMIZE "
		UI.btnR(touchZones, w, searchY, optStr, "mute", "stock_optimize")
		if optActive then UI.text(w - #optStr + 1, searchY + 1, string.rep("-", #optStr), UI.C.accent) end
	end
	local cw    = math.floor((w - 2) / 3)
	local sep1X = cw + 1
	local sep2X = 2 * cw + 2
	local colStarts = {1, cw + 2, 2 * cw + 3}
	local isTank = (stockModFilter == "TANK")
	local headY = 14
	if isTank then
		drawText(2, headY, "T# FLUID NAME", colors.gray, colors.black)
		drawText(1, headY + 1, string.rep("-", w), colors.gray)
	else
		for ci, cx in ipairs(colStarts) do
			drawText(cx + 1, headY, "ITEM NAME", colors.gray, colors.black)
		end
		drawText(sep1X, headY, "|", colors.gray, colors.black)
		drawText(sep2X, headY, "|", colors.gray, colors.black)
		drawText(1, headY + 1, string.rep("-", w), colors.gray)
	end
	local pages
	if isTank then
		local inv, _ftc, _ftmb, tDetails = getFluid()
		local tankCntByKey = {}
		do
			local seen = {}
			for _, d in ipairs(tDetails or {}) do
				local k = fluidKey(d.fluid)
				seen[k] = seen[k] or {}
				if not seen[k][d.periph] then
					seen[k][d.periph] = true
					tankCntByKey[k] = (tankCntByKey[k] or 0) + 1
				end
			end
		end
		local fl = {}
		for fk, amt in pairs(inv) do
			local fn = fluidNameOf(fk)
			local sn = shortName(fn)
			if stockFilter == "" or sn:lower():find(stockFilter:lower(), 1, true) then
				fl[#fl + 1] = {name = fn, mb = amt, tanks = tankCntByKey[fk] or 0}
			end
		end
		table.sort(fl, function(a, b) return a.name < b.name end)
		local ry0 = 16
		local cols = 2
		local rN = h - ry0 - 3
		if rN < 1 then rN = 1 end
		local perPage = cols * rN
		pages = math.max(1, math.ceil(#fl / perPage))
		if curPage > pages then curPage = pages end
		local iStart = ((curPage - 1) * perPage) + 1
		local iEnd   = math.min(iStart + perPage - 1, #fl)
		local fcw = math.floor(w / cols)
		for ry = 0, rN - 1 do
			_bufClearLine(ry0 + ry, (ry % 2 == 0) and colors.black or colors.gray)
		end
		for ci = 1, cols - 1 do
			for ry = 0, rN - 1 do
				drawText(ci * fcw, ry0 + ry, "|", colors.gray, (ry % 2 == 0) and colors.black or colors.gray)
			end
		end
		if #fl == 0 then
			local none = "No fluids. Mark tanks with [TNK] in NETWORK."
			drawText(math.floor((w - #none) / 2) + 1, ry0 + 1, none, colors.gray)
		else
			for i = iStart, iEnd do
				local li = i - iStart
				local col = math.floor(li / rN)
				local row = li % rN
				local rowY = ry0 + row
				local colX = col * fcw + 1
				local rowBg = (row % 2 == 0) and colors.black or colors.gray
				local f = fl[i]
				local mbStr = f.mb > FLUID_MAX_CAP and ">100000 mB" or string.format("%d mB", f.mb)
				local tcStr = tostring(f.tanks)
				drawText(colX + 1, rowY, tcStr, colors.yellow, rowBg)
				local nmX = colX + 1 + #tcStr + 1
				local nm = shortName(f.name)
				local nameMax = fcw - #mbStr - 4 - #tcStr - 1
				if #nm > nameMax then nm = nm:sub(1, nameMax) end
				drawText(nmX, rowY, nm, colors.white, rowBg)
				drawText(colX + fcw - #mbStr - 2, rowY, mbStr, colors.cyan, rowBg)
			end
		end
	else
		local stockList = {}
		for itemName, count in pairs(stockInv) do
			local mod  = itemName:match("^([^:]+):") or "minecraft"
			local sn   = shortName(itemName)
			if (stockModFilter == "All" or stockModFilter == mod) and
			(stockFilter == "" or sn:lower():find(stockFilter:lower(), 1, true)) then
				table.insert(stockList, {name=itemName, cnt=count})
			end
		end
		table.sort(stockList, function(a, b) return a.name < b.name end)
		local ry0     = 16
		local rN      = h - ry0 - 3
		local perPage = rN * 3
		pages = math.max(1, math.ceil(#stockList / perPage))
		if curPage > pages then curPage = pages end
		local iStart = ((curPage - 1) * perPage) + 1
		local iEnd   = math.min(iStart + perPage - 1, #stockList)
		for ry = 0, rN - 1 do
			local rowBg = (ry % 2 == 0) and colors.black or colors.gray
			_bufClearLine(ry0 + ry, rowBg)
			drawText(sep1X, ry0 + ry, "|", colors.gray, colors.black)
			drawText(sep2X, ry0 + ry, "|", colors.gray, colors.black)
		end
		for i = iStart, iEnd do
			local item = stockList[i]
			local li   = i - iStart
			local col  = math.floor(li / rN)
			local row  = li % rN
			local colX = colStarts[col + 1]
			local rowY = ry0 + row
			local rowBg = (row % 2 == 0) and colors.black or colors.gray
			local sn   = shortName(item.name)
			local nameMax = cw - 9
			drawText(colX + 1, rowY, sn:sub(1, nameMax), colors.white, rowBg)
			local cStr = tostring(item.cnt)
			local reqX = colX + cw - 5
			drawText(reqX - 1 - #cStr, rowY, cStr, colors.cyan, rowBg)
			local hasBox   = Config.train_box and Config.train_box ~= ""
			local reqColor = hasBox and colors.cyan or colors.gray
			drawText(reqX, rowY, "[REQ]", colors.black, reqColor)
			if hasBox then
				table.insert(touchZones, {id="open_req_picker", arg=item.name, x1=reqX, x2=reqX+4, y=rowY})
			end
		end
	end
	local navY = h - 1
	drawText(1, navY - 1, string.rep("-", w), colors.gray)
	local pageStr = string.format(" PAGE %d OF %d ", curPage, math.max(1, pages))
	local prevStr = " [ PREV ] "
	local nextStr = " [ NEXT ] "
	local navX    = math.floor((w - (#prevStr + #pageStr + #nextStr + 4)) / 2)
	drawText(navX, navY, prevStr, curPage > 1 and colors.white or colors.lightGray, colors.gray)
	drawText(navX + #prevStr + 2, navY, pageStr, colors.lime, colors.black)
	local nextX = navX + #prevStr + #pageStr + 4
	drawText(nextX, navY, nextStr, curPage < pages and colors.white or colors.lightGray, colors.gray)
	if curPage > 1 then
		table.insert(touchZones, {id="prev_page", x1=navX, x2=navX+#prevStr-1, y=navY})
	end
	if curPage < pages then
		table.insert(touchZones, {id="next_page", x1=nextX, x2=nextX+#nextStr-1, y=navY})
	end
end


function drawKeepTab(w, h, stockInv, touchZones)
	local haltText = Config.autostock_paused and " [RESUME] " or " [PAUSE ALL] "
	local haltColor = Config.autostock_paused and colors.lime or colors.red
	drawText(2, 9, haltText, colors.white, haltColor)
	table.insert(touchZones, {id="autostock_toggle", x1=2, x2=2+#haltText-1, y=9})
	drawText(2 + #haltText + 1, 9, " [RUN NOW] ", colors.black, colors.orange)
	table.insert(touchZones, {id="force_autostock", x1=2+#haltText+1, x2=2+#haltText+11, y=9})
	if asItem ~= "" then
		local asName = shortName(asItem)
		drawText(2 + #haltText + 14, 9, ">> " .. asName, colors.lime)
	elseif Config.autostock_paused then
		drawText(2 + #haltText + 14, 9, "PAUSED", colors.red)
	else
		drawText(2 + #haltText + 14, 9, "IDLE", colors.gray)
	end
	local kHasFluid = false
	for k in pairs(Keep.all()) do if k:sub(1, 2) == "f:" then kHasFluid = true break end end
	if kHasFluid then
		local allStr = " ITEM "
		local flStr  = " FLUID "
		local aAct = (fluidKeepFilter ~= "FLUID")
		local fAct = (fluidKeepFilter == "FLUID")
		drawText(2, 10, allStr, aAct and colors.black or colors.gray, aAct and colors.lime or colors.black)
		table.insert(touchZones, {id="keep_cat", arg="All", x1=2, x2=2+#allStr-1, y=10})
		drawText(2+#allStr+1, 10, flStr, colors.cyan, fAct and colors.gray or colors.black)
		table.insert(touchZones, {id="keep_cat", arg="FLUID", x1=2+#allStr+1, x2=2+#allStr+#flStr, y=10})
		drawText(2+#allStr+#flStr+3, 10, "top = higher priority", colors.gray)
	else
		fluidKeepFilter = "All"
		drawText(2, 10, "Higher position = higher priority (top runs first).", colors.gray)
	end
	drawText(1, 11, string.rep("-", w), colors.gray)
	local ry0 = 12
	local perPage = h - ry0 - 2
	local keepFinv = (fluidKeepFilter == "FLUID") and getFluid() or nil
	local keepList = {}
	for itemName, settings in pairs(Keep.all()) do
		local isFl = (itemName:sub(1, 2) == "f:")
		local show = (fluidKeepFilter == "FLUID") and isFl or (fluidKeepFilter ~= "FLUID" and not isFl)
		if show then
			table.insert(keepList, {
					name      = itemName,
					threshold = settings.threshold or settings.limit or 1,
					target    = settings.target or settings.limit or 1,
					paused    = settings.paused,
					order     = settings.order or 99999,
					fluid     = isFl,
				})
		end
	end
	table.sort(keepList, function(a, b)
			if a.order ~= b.order then return a.order < b.order end
			return a.name < b.name
		end)
	local pages = math.max(1, math.ceil(#keepList / perPage))
	if curPage > pages then curPage = pages end
	local iStart = ((curPage - 1) * perPage) + 1
	local iEnd   = math.min(iStart + perPage - 1, #keepList)
	local rowY = ry0
	for idx = iStart, iEnd do
		local item = keepList[idx]
		local gIdx = idx
		local flName = item.fluid and fluidNameOf(item.name) or item.name
		local cName = shortName(flName)
		local curStock
		if item.fluid then
			curStock = (keepFinv and keepFinv[item.name]) or 0
		else
			curStock = stockInv[item.name] or 0
		end
		local rowBg = zebraBg(idx)
		_bufClearLine(rowY, rowBg)
		local rankStr = string.format("#%d", gIdx)
		UI.text(2, rowY, rankStr, UI.C.warn, rowBg)
		local stockDisp = (item.fluid and curStock > FLUID_MAX_CAP) and ">100000" or tostring(curStock)
		local trigStr = item.fluid
		and string.format("%d>%d mB", item.threshold, item.target)
		or string.format("%d>%d", item.threshold, item.target)
		local nameCol = item.paused and colors.lightGray or (asItem == item.name and colors.lime or colors.white)
		local bx = w - 38
		local craftNowX = bx - 9
		local keepIndX  = craftNowX - 5
		local trigW  = (fluidKeepFilter == "FLUID") and 16 or 11
		local curStr = "[" .. stockDisp .. "]"
		local trigX  = (keepIndX - 2) - #trigStr + 1
		local curX   = (keepIndX - 3 - trigW) - #curStr + 1
		local nameMax = math.max(4, curX - (2 + #rankStr) - 1)
		UI.text(2 + #rankStr, rowY, (" " .. cName):sub(1, nameMax), nameCol, rowBg)
		UI.text(curX, rowY, curStr, item.paused and colors.gray or ((curStock < item.threshold) and colors.orange or colors.lime), rowBg)
		UI.text(trigX, rowY, trigStr, item.paused and colors.gray or colors.lightGray, rowBg)
		local keepScan = item.fluid and fluidScanResults[flName] or recipesScan[item.name]
		if item.fluid then
			if keepScan ~= nil then
				if keepScan > 0 then
					UI.text(keepIndX, rowY, keepScan > 99 and ">99" or tostring(keepScan), UI.C.accent, rowBg)
				else
					UI.text(keepIndX, rowY, "[!]", UI.C.fg, UI.C.danger)
				end
			else
				UI.text(keepIndX, rowY, "[~]", UI.C.soft, rowBg)
			end
		elseif keepScan then
			local cMax = keepScan.maxCraftable or 0
			if cMax > 0 then
				UI.text(keepIndX, rowY, cMax > 99 and ">99" or tostring(cMax), UI.C.accent, rowBg)
			else
				UI.text(keepIndX, rowY, "[!]", UI.C.fg, UI.C.danger)
				UI.zone(touchZones, "show_craft_info", item.name, keepIndX, rowY, 3)
			end
		else
			UI.text(keepIndX, rowY, "[~]", UI.C.soft, rowBg)
		end
		UI.btn(touchZones, craftNowX, rowY, "[CRAFT]", "soft", "keep_craft_now", item.name)
		local canTop = gIdx > 1
		local canDn  = gIdx < #keepList
		drawText(bx,    rowY, "[TOP]", canTop and colors.white or colors.gray, colors.gray)
		drawText(bx+6,  rowY, "[^]",   canTop and colors.white or colors.gray, colors.gray)
		drawText(bx+10, rowY, "[v]",   canDn  and colors.white or colors.gray, colors.gray)
		if canTop then UI.zone(touchZones, "keep_top", item.name, bx, rowY, 5) end
		if canTop then UI.zone(touchZones, "keep_up", item.name, bx+6, rowY, 3) end
		if canDn  then UI.zone(touchZones, "keep_dn", item.name, bx+10, rowY, 3) end
		UI.btn(touchZones, bx+14, rowY, "[EDIT]", "mute", "keep_edit", item.name)
		UI.btn(touchZones, bx+21, rowY, item.paused and "[RUN]  " or "[PAUSE]", item.paused and "danger" or "mute", "toggle_keep_status", item.name)
		UI.btn(touchZones, bx+29, rowY, "[DEL]", "danger", "remove_keep", item.name)
		rowY = rowY + 1
	end
	UI.pager(touchZones, h - 1, w, curPage, pages)
end


function drawRecipesFilter(w, touchZones)
	local mods = getMods()
	if srchFilter ~= "" then
		local q = srchFilter:lower()
		local hit = {All = true, [modFilter] = true}
		for itemName in pairs(Recipe.all()) do
			local mid = itemName:match("^([^:]+):") or "minecraft"
			if not hit[mid] and shortName(itemName):lower():find(q, 1, true) then hit[mid] = true end
		end
		local kept = {}
		for _, m in ipairs(mods) do if hit[m] then kept[#kept+1] = m end end
		mods = kept
	end
	table.insert(mods, 2, "FLUID")
	modFilterPage = _drawModFilter(w, touchZones, {
			mods = mods, special = {name = "FLUID", disp = " FLUID ", fg = colors.cyan},
			current = modFilter, pageVal = modFilterPage,
			zoneId = "set_mod", prevId = "mod_prev", nextId = "mod_next",
		})
end


function drawRow(gi, mStart, rowY, w, touchZones)
	local grp    = MgmtGroups[gi]
	local gName  = (grp.name ~= "" and grp.name or "(unnamed)"):upper()
	local gInput  = mgmtIODisp(grp, true)
	local gOutput = mgmtIODisp(grp, false)
	local isPaused = grp.paused or false
	local rowBg = ((gi - mStart) % 2 == 0) and colors.black or colors.gray
	_bufClearLine(rowY, rowBg)
	local delS, editS, viewS = " [DEL] ", " [EDIT] ", " [VIEW] "
	local pauseS = isPaused and " [RUN] " or " [PAUSE] "
	local delX   = UI.btnR(touchZones, w, rowY, delS, "mute", "mgmt_del", gi)
	local editX  = UI.btnR(touchZones, delX - 2, rowY, editS, "mute", "mgmt_edit", gi)
	local viewX  = UI.btnR(touchZones, editX - 2, rowY, viewS, "mute", "mgmt_view", gi)
	local pauseX = viewX - #pauseS - 1
	UI.btn(touchZones, pauseX, rowY, pauseS, isPaused and "warn" or "mute", "mgmt_pause", gi)
	local isFluidGrp = isFluid(grp)
	local nameStr = gName .. "  " .. gInput .. " -> " .. gOutput
	local nameMax = pauseX - 3
	if #nameStr > nameMax then nameStr = nameStr:sub(1, nameMax) end
	drawText(2, rowY, gName, isPaused and colors.gray or colors.white, rowBg)
	if isFluidGrp then
		drawText(2 + #gName, rowY, " ~", colors.cyan, rowBg)
	end
	local ioX = 2 + #gName + 2
	if ioX < pauseX - 2 then
		local ioStr = gInput .. " -> " .. gOutput
		drawText(ioX, rowY, ioStr:sub(1, pauseX - ioX - 1), colors.gray, rowBg)
	end
	if mgmtActBtn and mgmtActBtn.gi == gi and (os.clock() - mgmtActBtn.t) < 2 then
		local abx, abw
		if     mgmtActBtn.btn == "view"  then abx = viewX;  abw = #viewS
		elseif mgmtActBtn.btn == "edit"  then abx = editX;  abw = #editS
		elseif mgmtActBtn.btn == "del"   then abx = delX;   abw = #delS
		elseif mgmtActBtn.btn == "pause" then abx = pauseX; abw = #pauseS
		end
		if abx then drawText(abx, rowY+1, string.rep("-", abw), colors.lime, rowBg) end
	end
	_bufClearLine(rowY+1, rowBg)
	local ruleDrawX = 4
	if grp.provider then
		drawText(ruleDrawX, rowY+1, "PROVIDER (pull-only source)", colors.orange, rowBg)
	else
		if grp.drain then
			drawText(ruleDrawX, rowY+1, "EMPTY ALL", colors.lime, rowBg)
			ruleDrawX = ruleDrawX + 10
		end
		local rulesStr = grp.drain and "" or "Rules: "
		if #grp.rules == 0 then
			if not grp.drain then rulesStr = rulesStr .. "(none)" end
		else
			if grp.drain then rulesStr = " " end
			for ri, rule in ipairs(grp.rules) do
				local rn = shortName(rule.item)
				local piece = isFluidGrp and (rn .. " " .. rule.amount .. "mB") or (rn .. " x" .. rule.amount)
				if ri < #grp.rules then piece = piece .. "  " end
				if #rulesStr + #piece > w - ruleDrawX - 2 then rulesStr = rulesStr:sub(1, w-ruleDrawX-5) .. "..."; break end
				rulesStr = rulesStr .. piece
			end
		end
		if rulesStr ~= "" and rulesStr ~= " " then
			drawText(ruleDrawX, rowY+1, rulesStr:sub(1, w - ruleDrawX), colors.cyan, rowBg)
		end
	end
end


function drawLogTab(w, h, touchZones)
	local newStr, syncBtnS = " [+NEW GROUP] ", " [SYNC] "
	local btnSX = math.floor((w - (#newStr + 2 + #syncBtnS)) / 2) + 1
	local syncBtnX = btnSX + #newStr + 2
	local syncMoved = mgmtSyncInfo:find("^moved") ~= nil
	UI.btn(touchZones, btnSX, 9, newStr, "ok", "mgmt_new")
	UI.btn(touchZones, syncBtnX, 9, syncBtnS, syncMoved and "ok" or "mute", "mgmt_sync_now")
	if syncFlashTime and (os.clock() - syncFlashTime) < 3 then
		UI.text(syncBtnX, 10, string.rep("-", #syncBtnS), UI.C.accent)
	else
		UI.rule(10, w)
	end
	if #MgmtGroups == 0 then
		UI.textC(14, w, "No groups. Tap [+NEW GROUP] to create one.", UI.C.muted)
	else
		local rN = math.max(1, math.floor((h - 14) / 2))
		local pages = math.max(1, math.ceil(#MgmtGroups / rN))
		if mgmtPage > pages then mgmtPage = pages end
		local mStart = (mgmtPage - 1) * rN + 1
		local mEnd   = math.min(mStart + rN - 1, #MgmtGroups)
		local rowY = 11
		for gi = mStart, mEnd do
			drawRow(gi, mStart, rowY, w, touchZones)
			rowY = rowY + 2
		end
		UI.pager(touchZones, h - 1, w, mgmtPage, pages, "mgmt_list_prev", "mgmt_list_next")
	end
end


function drawAltTab(w, h, touchZones)
	local isFluidAlt = (altViewFluid ~= nil)
	local fkAlt = isFluidAlt and fluidKey(altViewFluid) or nil
	local titleName = isFluidAlt and (shortName(altViewFluid))
	or (altViewItem and (shortName(altViewItem)) or "?")
	drawText(2, 9, "RECIPE PRIORITY: " .. titleName, colors.lime)
	drawText(1, 10, string.rep("-", w), colors.gray)
	local primary, alts
	if isFluidAlt then
		primary = Fluids.find(fkAlt)
		alts    = Fluids.altsOf(fkAlt) or {}
	else
		primary = altViewItem and Recipe.find(altViewItem)
		alts    = (altViewItem and Recipe.altsOf(altViewItem)) or {}
	end
	if not isFluidAlt and type(primary) == "table" and primary.type == "fluid" then
		primary = nil
	end
	local entries = {}
	if primary then
		table.insert(entries, {isPrimary=true, recipe=primary})
	end
	for i, alt in ipairs(alts) do
		table.insert(entries, {isPrimary=false, altIdx=i, recipe=alt})
	end
	local nSolid = #entries
	if not isFluidAlt and altViewItem then

		local function addFl(rec)
			if type(rec) ~= "table" then return end
			for _, o in ipairs(rec.item_outputs or {}) do
				if o.name == altViewItem then
					table.insert(entries, {isFluid=true, recipe=rec})
					return
				end
			end
		end
		for _, rec in pairs(Fluids.all()) do addFl(rec) end
		for _, fAlts in pairs(Fluids.allAlts()) do
			for _, rec in ipairs(fAlts) do addFl(rec) end
		end
	end
	local listY = 11
	local perPage = h - listY - 3
	local col1X = 2
	local col1W = 24
	local col2X = col1X + col1W
	local col2W = 4
	local col3X = col2X + col2W + 2
	local col3End = w - 24
	if #entries == 0 then
		drawText(2, listY, "No recipes. Add one via +RECIPES tab.", colors.gray)
	else
		for eIdx = 1, math.min(#entries, perPage) do
			local entry = entries[eIdx]
			local rowBg = (eIdx % 2 == 0) and colors.gray or colors.black
			_bufClearLine(listY, rowBg)
			local rec   = entry.recipe
			local mName = tostring(rec.machine_name or rec.method or "?")
			mName = shortName(mName)
			local nameColor = entry.isFluid and colors.cyan or (entry.isPrimary and colors.yellow or colors.white)
			local outVal, ingStr
			if isFluidAlt or entry.isFluid then
				local tName = isFluidAlt and altViewFluid or altViewItem
				outVal = 0
				for _, o in ipairs(rec.outputs or {}) do
					if o.name == tName then outVal = o.amount end
				end
				for _, o in ipairs(rec.item_outputs or {}) do
					if o.name == tName then outVal = o.count end
				end
				local inParts = {}
				for _, inp in ipairs(rec.inputs or {}) do
					inParts[#inParts + 1] = (shortName(inp.name)) .. " " .. inp.amount
				end
				for _, it in ipairs(rec.item_inputs or {}) do
					inParts[#inParts + 1] = it.count .. "x " .. (shortName(it.name))
				end
				ingStr = table.concat(inParts, " + ")
			else
				outVal = rec.output_count or 1
				local ingCnt = {}
				for _, ing in ipairs(rec.ingredients or {}) do
					if ing and ing ~= "nil" then
						ingCnt[ing] = (ingCnt[ing] or 0) + 1
					end
				end
				local ingParts = {}
				for ingName, cnt in pairs(ingCnt) do
					local sn = shortName(ingName)
					table.insert(ingParts, sn .. (cnt > 1 and " x"..cnt or ""))
				end
				table.sort(ingParts)
				ingStr = table.concat(ingParts, "  ")
			end
			local nameStr = eIdx .. " " .. mName
			drawText(col1X, listY, nameStr:sub(1, col1W - 1), nameColor, rowBg)
			local outStr = tostring(outVal):sub(1, col2W)
			local outX = col2X + col2W - #outStr
			drawText(outX, listY, outStr, colors.lime, rowBg)
			table.insert(touchZones, {id="alt_out_edit", recRef=rec,
					targetName=(isFluidAlt and altViewFluid or altViewItem),
					fluidRow=(isFluidAlt or entry.isFluid) and true or false,
					curVal=outVal, x1=col2X, x2=col2X+col2W-1, y=listY})
			if col3End - col3X > 4 and #ingStr > 0 then
				drawText(col3X, listY, ingStr:sub(1, col3End - col3X), colors.lightGray, rowBg)
			end
			local bx = w - 22
			if not entry.isFluid then
				if eIdx > 1 then UI.btn(touchZones, bx, listY, "[^]", "mute", "combined_up", eIdx) end
				if eIdx < nSolid then UI.btn(touchZones, bx+4, listY, "[v]", "mute", "combined_dn", eIdx) end
				if eIdx > 1 then UI.btn(touchZones, bx+8, listY, "[TOP]", "ok", "combined_top", eIdx) end
				if not entry.isPrimary then UI.btn(touchZones, bx+14, listY, "[X]", "danger", "combined_del", eIdx) end
				if not isFluidAlt then
					UI.text(bx+18, listY, "[E]", UI.C.fg, UI.C.rowBg)
					table.insert(touchZones, {id="open_recipe_edit", arg=altViewItem, altIdx=(entry.isPrimary and nil or entry.altIdx), fromAltView=true, x1=bx+18, x2=bx+20, y=listY})
				end
			end
			listY = listY + 1
		end
	end
	local btnY = h - 1
	if isFluidAlt then
		UI.btn(touchZones, 2, btnY, "[ BACK ]", "mute", "alt_back")
	else
		UI.btn(touchZones, 2, btnY, "[ + ADD ALT ]", "ok", "alt_add")
		UI.btn(touchZones, 17, btnY, "[ BACK ]", "mute", "alt_back")
	end
end


function drawNetTab(w, h, touchZones)
	UI.text(2, 10, "PERIPHERAL BUS MATRIX (SYSTEM SETUP):")
	local ry0 = 12
	local perPage = h - ry0 - 2
	local pList = {}
	for _, p in ipairs(peripheral.getNames()) do
		if not SYSTEM_SIDES[p] and p ~= MONITOR_SIDE then table.insert(pList, p) end
	end
	table.sort(pList, _cmpByDisplay)
	local pages = math.max(1, math.ceil(#pList / perPage))
	if curPage > pages then curPage = pages end
	local iStart = ((curPage - 1) * perPage) + 1
	local iEnd = math.min(iStart + perPage - 1, #pList)

	local function togBtn(x, y, label, on, onStyle, id, arg, rowBg)
		if on then
			local s = UI.S[onStyle]
			drawText(x, y, label, s.fg, s.bg)
		else
			drawText(x, y, label, colors.lightGray, rowBg)
		end
		UI.zone(touchZones, id, arg, x, y, #label)
	end
	local rowY = ry0
	for idx = iStart, iEnd do
		local p = pList[idx]
		local rowBg = zebraBg(idx)
		_bufClearLine(rowY, rowBg)
		UI.text(2, rowY, getMachName(p), UI.C.fg, rowBg)
		local bx = math.max(w - 42, #getMachName(p) + 2)
		local cc = crafterCfg()
		if isRelayPeriph(p) then
			local clOn = (cc.clutch == p and cc.clutch_side)
			local puOn = (cc.pulse == p and cc.pulse_side)
			togBtn(bx,      rowY, clOn and (" [CL:" .. cc.clutch_side .. "] ") or " [CLUTCH] ", clOn, "warn", "crafter_set_clutch", p, rowBg)
			togBtn(bx + 14, rowY, puOn and (" [PU:" .. cc.pulse_side .. "] ") or " [PULSE] ",  puOn, "cool", "crafter_set_pulse",  p, rowBg)
		elseif isCrafterPeriph(p) then
			local ci = crafterCellIdx(p)
			UI.text(bx + 1, rowY, ci and ("[GRID CELL " .. ci .. "]") or "[NOT IN GRID - DETECT]", ci and UI.C.info or UI.C.warn, rowBg)
		else
			togBtn(bx,      rowY, " [VAULT] ",  Config.storages[p],                          "ok",   "toggle_storage",    p, rowBg)
			togBtn(bx + 9,  rowY, " [T.BOX] ",  Config.train_box == p,                       "warn", "set_train_box",     p, rowBg)
			local tpp = peripheral.wrap(p)
			if (Config.turtles and Config.turtles[p]) or (tpp and tpp.craft) then
				togBtn(bx + 18, rowY, " [TURTLE] ", Config.turtles and Config.turtles[p], "cool", "set_turtle",        p, rowBg)
			else
				togBtn(bx + 18, rowY, " [C.OUT] ",  cc.out == p,                          "cool", "crafter_set_out",   p, rowBg)
			end
		end
		local lbl = Machines.label(p)
		togBtn(bx + 28, rowY, " [SUF] ",    lbl and lbl ~= "",                            "ok",   "machine_label",     p, rowBg)
		local tankObj = peripheral.wrap(p)
		if tankObj and tankObj.tanks then
			togBtn(bx + 35, rowY, " [TNK] ", Config.fluid_tanks and Config.fluid_tanks[p], "ok", "toggle_fluid_tank", p, rowBg)
		end
		rowY = rowY + 1
	end
	UI.pager(touchZones, h - 1, w, curPage, pages)
end


function drawSearch(w, touchZones)
	local sY = 12
	local dispS = (srchFilter == "") and "<type item name...>" or srchFilter
	local sCol  = (srchFilter == "") and (isSearch and colors.lightGray or colors.gray) or colors.white
	local fullS = "FIND: [ " .. dispS .. " ]"
	local sX    = math.max(14, math.floor((w - #fullS) / 2) + 1)
	UI.text(sX, sY, "FIND: ", UI.C.muted)
	UI.text(sX + 6, sY, "[ " .. dispS .. " ]", sCol, isSearch and UI.C.rowBg or UI.C.bg)
	UI.zone(touchZones, "trigger_search", nil, sX, sY, #fullS)
	if srchFilter ~= "" then
		UI.text(sX + 6, sY + 1, string.rep("-", #dispS + 4), UI.C.accent)
		UI.btn(touchZones, sX + #fullS + 1, sY, "[X]", "danger", "clear_search")
	end
	local x = 3
	if Config.train_box and Config.train_box ~= "" then
		UI.tabBtn(touchZones, x, sY, " UNLOAD ", "pull_from_box", unloadActive)
		x = x + 9
	end
	UI.tabBtn(touchZones, x, sY, " HISTORY ", "open_history", historyPopup ~= nil)
	local histEnd = x + 9
	local qBtn = " QUEUE "
	local qCnt = (#Craft.queue > 0) and tostring(#Craft.queue) or ""
	local qX = histEnd + 1
	UI.text(qX, sY, qBtn, UI.C.fg, UI.C.rowBg)
	if qCnt ~= "" then UI.text(qX + #qBtn, sY, qCnt, UI.C.accent) end
	if queueEditPopup then UI.text(qX, sY + 1, string.rep("-", #qBtn), UI.C.accent) end
	UI.zone(touchZones, "open_queue", nil, qX, sY, #qBtn + #qCnt)
	local dtColStart = w - 15
	local scanX = dtColStart + math.floor(((w - dtColStart + 1) - 12) / 2)
	UI.tabBtn(touchZones, scanX, sY, " SCAN ", "scan_recipes", scanActive)
	UI.tabBtn(touchZones, scanX + 7, sY, " ALL ", "scan_all_recipes", allScanActive)
	local hy = 14
	local hdrBtnX = w - 60
	local dtStart = hdrBtnX + 45
	local dtPadH = math.max(0, math.floor((w - dtStart + 1 - #"DEVICE TYPE") / 2))
	UI.text(dtStart + dtPadH, hy, "DEVICE TYPE", UI.C.muted)
	UI.text(1 + dtPadH, hy, "ITEM NAME", UI.C.muted)
	UI.rule(hy + 1, w)
end


function drawRecTab(w, h, stockInv, touchZones)
	drawRecipesFilter(w, touchZones)
	drawSearch(w, touchZones)
	local isFluidCat = (modFilter == "FLUID")
	local flist = {}
	if isFluidCat then
		local fluidSet = {}

		local function collectOut(rec)
			for _, o in ipairs(rec.outputs or {}) do fluidSet[o.name] = true end
		end
		for _, rec in pairs(Fluids.all()) do collectOut(rec) end
		for _, alts in pairs(Fluids.allAlts()) do
			for _, a in ipairs(alts) do collectOut(a) end
		end
		local tmp = {}
		for fname in pairs(fluidSet) do tmp[#tmp + 1] = {name = fname, producers = fluidProducers(fname)} end
		table.sort(tmp, function(a, b) return a.name < b.name end)
		for _, e in ipairs(tmp) do
			local sn = shortName(e.name)
			if srchFilter == "" or sn:lower():find(srchFilter:lower(), 1, true) ~= nil then
				table.insert(flist, e)
			end
		end
	else
		local items = {}
		for itemName in pairs(Recipe.all()) do table.insert(items, itemName) end
		table.sort(items)
		for _, itemName in ipairs(items) do
			local mod = itemName:match("^([^:]+):") or "minecraft"
			local sn  = shortName(itemName)
			if (modFilter == "All" or modFilter == mod) and (srchFilter == "" or sn:lower():find(srchFilter:lower(), 1, true) ~= nil) then
				table.insert(flist, itemName)
			end
		end
	end
	local ry0 = 16
	local perPage = h - ry0 - 3
	local pages = math.max(1, math.ceil(#flist / perPage))
	if curPage > pages then curPage = pages end
	local iStart = ((curPage - 1) * perPage) + 1
	local iEnd = math.min(iStart + perPage - 1, #flist)
	local fluidInv = isFluidCat and getFluid() or nil
	local rowY = ry0
	for idx = iStart, iEnd do
		if isFluidCat then
			local r = flist[idx]
			local rowBg = zebraBg(idx)
			_bufClearLine(rowY, rowBg)
			local sn = shortName(r.name)
			UI.text(1, rowY, sn, UI.C.fg, rowBg)
			local btnX = math.max(w - 60, #sn + 2)
			local nProd = #r.producers
			local prim = r.producers[1]
			local perOp = prim and prim.perOp or 0
			local stockMb = (fluidInv and fluidInv[fluidKey(r.name)]) or 0
			local cStr = (stockMb > FLUID_MAX_CAP and ">100000" or tostring(stockMb))
			UI.text(btnX + 5 - #cStr, rowY, cStr, UI.C.info, rowBg)
			local craftRes = fluidScanResults[r.name]
			if craftRes ~= nil then
				if craftRes > 0 then
					UI.text(btnX + 34, rowY, craftRes >= 9999 and ">9999" or (">" .. craftRes), UI.C.accent, rowBg)
				else
					UI.btn(touchZones, btnX + 34, rowY, "[!]", "danger", "show_fluid_info", r.name)
				end
			else
				UI.text(btnX + 34, rowY, "[~]", UI.C.soft, rowBg)
			end
			UI.btn(touchZones, btnX + 6, rowY, "[CRAFT]", (fluidWaitCraft == r.name) and "hi" or "soft", "fluid_craft", r.name)
			UI.btn(touchZones, btnX + 14, rowY, "[+KEEP]", Keep.of(fluidKey(r.name)) and "ok" or "mute", "open_keep_picker_fluid", r.name)
			UI.btn(touchZones, btnX + 22, rowY, "[ALT]", (nProd > 1) and "ok" or "mute", "fluid_alt", r.name)
			if pendDelFluid == r.name then
				UI.btnP(touchZones, btnX + 28, rowY, "[SURE?]", "mute", "fluid_delete_cancel")
				UI.btnP(touchZones, btnX + 36, rowY, "[YES]", "danger", "fluid_delete_confirm", r.name)
			else
				UI.btn(touchZones, btnX + 28, rowY, "[DEL]", "mute", "fluid_delete_ask", r.name)
				if prim then UI.btn(touchZones, btnX + 41, rowY, "[E]", "soft", "open_recipe_edit_fluid", r.name) end
				local mDisp = prim and ((getMachName(prim.recipe.machine_name) or "?") .. " " .. perOp .. "mB") or ""
				UI.text(btnX + 45, rowY, mDisp:sub(1, math.max(0, w - (btnX + 45))), UI.C.soft, rowBg)
			end
		else
			local itemName = flist[idx]
			local data = Recipe.find(itemName)
			local sn = shortName(itemName)
			local rowBg = zebraBg(idx)
			_bufClearLine(rowY, rowBg)
			UI.text(1, rowY, sn, UI.C.fg, rowBg)
			local btnX = math.max(w - 60, #sn + 2)
			local stockN = stockInv and (stockInv[itemName] or 0) or 0
			local dispN, cntCol = stockN, colors.cyan
			if stockN == 0 and stockInv then
				local alts = Groups.altsOf(itemName)
				if alts then
					local altTotal = 0
					for _, altName in ipairs(alts) do
						if altName ~= itemName then altTotal = altTotal + (stockInv[altName] or 0) end
					end
					if altTotal > 0 then dispN, cntCol = altTotal, colors.yellow end
				end
			end
			local cStr = tostring(dispN)
			UI.text(btnX - #cStr - 1, rowY, cStr, cntCol, rowBg)
			local scanRes = recipesScan[itemName]
			local indX = btnX + 37
			if scanRes then
				if scanRes.noMachine then
					UI.btn(touchZones, indX, rowY, "[?]", "warn", "show_machine_info", itemName)
				elseif (scanRes.maxCraftable or 0) > 0 then
					local m = scanRes.maxCraftable
					UI.text(indX, rowY, m > 99 and ">99" or tostring(m), UI.C.accent, rowBg)
				else
					UI.btn(touchZones, indX, rowY, "[!]", "danger", "show_craft_info", itemName)
				end
			else
				UI.text(indX, rowY, "[~]", UI.C.soft, rowBg)
			end
			local hasBox = Config.train_box and Config.train_box ~= ""
			UI.btn(touchZones, btnX, rowY, "[REQ]", hasBox and "cool" or "mute", hasBox and "open_req_picker" or "", itemName)
			UI.btn(touchZones, btnX + 6, rowY, "[CRAFT]", "soft", "open_qty_picker", itemName)
			UI.btn(touchZones, btnX + 14, rowY, "[+KEEP]", Keep.of(itemName) and "ok" or "mute", "open_keep_picker", itemName)
			local altList = Recipe.altsOf(itemName)
			local hasAlts = altList and #altList > 0
			UI.btn(touchZones, btnX + 22, rowY, "[ALT]", hasAlts and "ok" or "mute", "open_alt_view", itemName)
			if pendDelItem == itemName then
				UI.btnP(touchZones, btnX + 28, rowY, "[SURE?]", "mute", "delete_cancel")
				UI.btnP(touchZones, btnX + 36, rowY, "[YES]", "danger", "delete_confirm", itemName)
			else
				UI.btn(touchZones, btnX + 28, rowY, "[DEL]", "mute", "delete_ask", itemName)
				UI.text(btnX + 34, rowY, "x" .. (data.output_count or 1), UI.C.fg, rowBg)
				local mRaw = tostring(data.machine_name or data.method or "")
				local mDisp = getMachName(mRaw)
				if data.output_device and data.output_device ~= "" then
					mDisp = mDisp .. ">" .. getMachName(data.output_device)
				end
				UI.btn(touchZones, btnX + 41, rowY, "[E]", "mute", "open_recipe_edit", itemName)
				UI.text(btnX + 45, rowY, mDisp, UI.C.soft, rowBg)
				if data.imported and data.type ~= "turtle" then
					UI.text(btnX + 44, rowY, string.char(7), UI.C.fg, rowBg)
				end
			end
		end
		rowY = rowY + 1
	end
	UI.pager(touchZones, h - 1, w, curPage, pages)
end


function httpPutSync(url, body, headers)
	local ok = pcall(function()
			http.request({url = url, method = "PUT", body = body, headers = headers})
		end)
	if not ok then return nil, "request failed" end
	local tm = os.startTimer(20)
	while true do
		local ev, a, b = os.pullEvent()
		if ev == "http_success" and a == url then
			local d = b.readAll(); b.close(); os.cancelTimer(tm); return d
		elseif ev == "http_failure" and a == url then
			local m = (type(b) == "string") and b or "error"
			os.cancelTimer(tm); return nil, m
		elseif ev == "timer" and a == tm then return nil, "timeout" end
	end
end

function ghHeaders()
	return {
		["Authorization"] = "token " .. (Config.github_token or ""),
		["Accept"]        = "application/vnd.github.v3+json",
		["User-Agent"]    = "AutoCraft-CC",
		["Content-Type"]  = "application/json"
	}
end

function ghParseRepo()
	local r = Config.github_repo or ""
	return r:match("^([^/]+)/(.+)$")
end

function ghApiUrl(path)
	local owner, repo = ghParseRepo()
	if not owner then return nil end
	return "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents/" .. path
end

function hasCustomIO(rec)
	if type(rec) ~= "table" then return false end
	-- crafter recipes are pinned to this world's peripheral names
	if rec.type == "crafter" then return true end
	if rec.output_device       and rec.output_device       ~= "" then return true end
	if rec.item_input_device   and rec.item_input_device   ~= "" then return true end
	if rec.fluid_input_device  and rec.fluid_input_device  ~= "" then return true end
	if rec.item_output_device  and rec.item_output_device  ~= "" then return true end
	if type(rec.output_tanks) == "table" and next(rec.output_tanks) then return true end
	if type(rec.input_tanks)  == "table" and next(rec.input_tanks)  then return true end
	return false
end

function mergeMap(localMap, importedMap)
	local out = {}
	for k, v in pairs(localMap or {}) do
		if hasCustomIO(v) then out[k] = v end
	end
	for k, v in pairs(importedMap or {}) do
		if type(v) == "table" and not hasCustomIO(v) then
			v.imported = true
			out[k] = v
		end
	end
	return out
end

function mergeAlts(localAlts, importedAlts)
	local out = {}
	for k, list in pairs(localAlts or {}) do
		if type(list) == "table" then
			for _, rec in ipairs(list) do
				if hasCustomIO(rec) then out[k] = out[k] or {}; table.insert(out[k], rec) end
			end
		end
	end
	for k, list in pairs(importedAlts or {}) do
		if type(list) == "table" then
			for _, rec in ipairs(list) do
				if type(rec) == "table" and not hasCustomIO(rec) then
					rec.imported = true
					out[k] = out[k] or {}; table.insert(out[k], rec)
				end
			end
		end
	end
	return out
end

function gitExport(filename, existingSha)
	gitWorking = true; gitStatus = "Uploading..."; gitStColor = colors.yellow
	drawUI()
	if not Config.github_repo or Config.github_repo == "" then
		gitStatus = "ERR: Repo not set (owner/repo)"; gitStColor = colors.red
		gitWorking = false; gitStTimer = os.startTimer(6); return
	end
	if not Config.github_token or Config.github_token == "" then
		gitStatus = "ERR: Token not set"; gitStColor = colors.red
		gitWorking = false; gitStTimer = os.startTimer(6); return
	end
	local ts = tostring(math.floor(os.epoch("utc") / 1000))
	filename = filename or ("autocraft_" .. ts .. ".json")
	local url = ghApiUrl(filename)
	if not url then
		gitStatus = "ERR: Invalid repo format"; gitStColor = colors.red
		gitWorking = false; gitStTimer = os.startTimer(6); return
	end
	local recExport = {}
	for k, v in pairs(Recipes) do
		if not (type(v) == "table" and v.type == "fluid") and not hasCustomIO(v) then
			recExport[k] = v
		end
	end
	local altExport = {}
	for k, list in pairs(AltRecipes) do
		if type(list) == "table" then
			for _, rec in ipairs(list) do
				if not hasCustomIO(rec) then altExport[k] = altExport[k] or {}; table.insert(altExport[k], rec) end
			end
		end
	end
	local fluidExport = {}
	for k, v in pairs(FluidRecipes) do
		if not hasCustomIO(v) then fluidExport[k] = v end
	end
	local fluidAltExport = {}
	for k, list in pairs(FluidAltRecipes) do
		if type(list) == "table" then
			for _, rec in ipairs(list) do
				if not hasCustomIO(rec) then fluidAltExport[k] = fluidAltExport[k] or {}; table.insert(fluidAltExport[k], rec) end
			end
		end
	end
	local exportData = textutils.serializeJSON({
			recipes = recExport, alt_recipes = altExport,
			fluid_recipes = fluidExport, fluid_alt_recipes = fluidAltExport,
			machine_labels = MachineLabels, exported_at = os.epoch("utc")
		})
	gitStatus = "Uploading " .. filename .. "..."; drawUI()
	local bodyTable = {message = "AutoCraft export " .. ts, content = b64enc(exportData)}
	if existingSha then
		bodyTable.sha = existingSha
	else
		local checkData = httpGetSync(url, ghHeaders())
		if checkData then
			local obj = textutils.unserializeJSON(checkData)
			if obj and obj.sha then bodyTable.sha = obj.sha end
		end
	end
	local result, err = httpPutSync(url, textutils.serializeJSON(bodyTable), ghHeaders())
	gitWorking = false
	if result then
		local count = 0; for _ in pairs(Recipes) do count = count + 1 end
		gitStatus = "Exported " .. count .. " recipes -> " .. filename
		gitStColor = colors.lime
	else
		gitStatus = "ERR: " .. (err or "unknown"); gitStColor = colors.red
	end
	if gitStTimer then os.cancelTimer(gitStTimer) end
	gitStTimer = os.startTimer(8)
end

function isSafeName(name)
	if type(name) ~= "string" or name == "" then return false end
	if #name > 96 then return false end
	if name:find("/", 1, true) or name:find("\\", 1, true) then return false end
	if name:find("..", 1, true) then return false end
	if name:sub(1, 1) == "." then return false end
	if not name:match("^[%w%._%-]+%.json$") then return false end
	return true
end

function gitListFiles()
	gitWorking = true; gitStatus = "Loading file list..."; gitStColor = colors.yellow
	drawUI()
	if not Config.github_repo or Config.github_repo == "" then
		gitStatus = "ERR: Repo not set"; gitStColor = colors.red
		gitWorking = false; gitStTimer = os.startTimer(6); return
	end
	local owner, repo = ghParseRepo()
	if not owner then
		gitStatus = "ERR: Invalid repo format (use owner/repo)"; gitStColor = colors.red
		gitWorking = false; gitStTimer = os.startTimer(6); return
	end
	local listUrl = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents/"
	local data = httpGetSync(listUrl, ghHeaders())
	gitWorking = false
	if not data then
		gitStatus = "ERR: Cannot reach GitHub"; gitStColor = colors.red
		gitStTimer = os.startTimer(6); return
	end
	local arr = textutils.unserializeJSON(data)
	if type(arr) ~= "table" then
		gitStatus = "ERR: Invalid response (check repo name/token)"; gitStColor = colors.red
		gitStTimer = os.startTimer(6); return
	end
	gitFileList = {}
	for _, f in ipairs(arr) do
		if type(f) == "table" and f.type == "file" and isSafeName(f.name) then
			table.insert(gitFileList, {name = f.name, sha = f.sha, download_url = f.download_url})
		end
	end
	if #gitFileList == 0 then
		gitStatus = "No JSON files found in repo"; gitStColor = colors.orange
		gitStTimer = os.startTimer(6)
	else
		table.sort(gitFileList, function(a, b) return a.name > b.name end)
		gitImportMode = true; gitSelFile = 1; gitImportPage = 1
		gitStatus = "Select file to import"; gitStColor = colors.white
	end
end

function gitImport()
	local file = gitFileList[gitSelFile]
	if not file then return end

	if not isSafeName(file.name) then
		gitStatus = "ERR: Unsafe filename rejected"; gitStColor = colors.red
		if gitStTimer then os.cancelTimer(gitStTimer) end
		gitStTimer = os.startTimer(6); return
	end
	gitWorking = true; gitStatus = "Downloading " .. file.name .. "..."; gitStColor = colors.yellow
	drawUI()
	local apiUrl = ghApiUrl(file.name)
	local apiData = httpGetSync(apiUrl, ghHeaders())
	local content = nil
	if apiData then
		local obj = textutils.unserializeJSON(apiData)
		if obj and obj.content then
			content = b64dec(obj.content:gsub("\n", ""))
		end
	end
	gitWorking = false; gitImportMode = false
	if not content then
		gitStatus = "ERR: Download failed"; gitStColor = colors.red
		if gitStTimer then os.cancelTimer(gitStTimer) end
		gitStTimer = os.startTimer(6); return
	end
	local parsed = textutils.unserializeJSON(content)
	if not parsed or not parsed.recipes then
		gitStatus = "ERR: Invalid file format"; gitStColor = colors.red
		if gitStTimer then os.cancelTimer(gitStTimer) end
		gitStTimer = os.startTimer(6); return
	end
	Recipes    = mergeMap(Recipes, parsed.recipes)
	AltRecipes = mergeAlts(AltRecipes, parsed.alt_recipes or {})
	if parsed.fluid_recipes     then FluidRecipes    = mergeMap(FluidRecipes, parsed.fluid_recipes) end
	if parsed.fluid_alt_recipes then FluidAltRecipes = mergeAlts(FluidAltRecipes, parsed.fluid_alt_recipes) end
	syncFluidStubs()
	recipesScan = {}
	saveData()
	local count = 0; for _ in pairs(Recipes) do count = count + 1 end
	gitStatus = "Imported " .. count .. " recipes from " .. file.name
	gitStColor = colors.lime
	if gitStTimer then os.cancelTimer(gitStTimer) end
	gitStTimer = os.startTimer(8)
end

function gitListForExport()
	gitWorking = true; gitStatus = "Loading file list..."; gitStColor = colors.yellow
	drawUI()
	if not Config.github_repo or Config.github_repo == "" then
		gitStatus = "ERR: Repo not set"; gitStColor = colors.red
		gitWorking = false; gitStTimer = os.startTimer(6); return
	end
	local owner, repo = ghParseRepo()
	if not owner then
		gitStatus = "ERR: Invalid repo format (use owner/repo)"; gitStColor = colors.red
		gitWorking = false; gitStTimer = os.startTimer(6); return
	end
	local listUrl = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents/"
	local data = httpGetSync(listUrl, ghHeaders())
	gitWorking = false
	if not data then
		gitExportList = {}
		gitExportSel = 0
		gitExportMode = true
		gitStatus = ""; gitStColor = colors.gray
		return
	end
	local arr = textutils.unserializeJSON(data)
	gitExportList = {}
	if type(arr) == "table" then
		for _, f in ipairs(arr) do
			if type(f) == "table" and f.type == "file" and isSafeName(f.name) then
				table.insert(gitExportList, {name = f.name, sha = f.sha})
			end
		end
		table.sort(gitExportList, function(a, b) return a.name > b.name end)
	end
	gitExportSel = 0; gitExportPage = 1
	gitExportMode = true
	gitStatus = ""; gitStColor = colors.gray
end


gitStatus         = ""
gitStColor    = colors.gray
gitStTimer    = nil
gitFileList       = {}
gitImportMode     = false
gitSelFile   = 1
gitWorking        = false
gitActiveBtn   = ""
gitExportMode     = false
gitExportList = {}
gitExportSel = 0
gitImportPage     = 1
gitExportPage     = 1

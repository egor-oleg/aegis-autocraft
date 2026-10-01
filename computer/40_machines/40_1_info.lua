function listMachines()
	local list = {}
	local all = peripheral.getNames()
	for _, p in ipairs(all) do
		if not SYSTEM_SIDES[p] and p ~= MONITOR_SIDE and p ~= Config.train_box
		and not (Config.turtles and Config.turtles[p]) and not Config.storages[p]
		and not (Config.fluid_tanks and Config.fluid_tanks[p])
		and not isCrafterRole(p) then
			table.insert(list, p)
		end
	end
	return list
end
function getMachBase(name)
	return name:match("^(.-)_%d+$") or name
end

function getMachName(name)
	local label = Machines.label(name)
	local id = shortName(name)
	if label and label ~= "" then
		return id .. "_" .. label
	end
	return id
end
_cmpByDisplay = function(a, b) return (getMachName(a) or a):lower() < (getMachName(b) or b):lower() end

function checkMachine(recipe)
	if not recipe then return true, nil end
	local mType = recipe.type or ""
	local mName = recipe.machine_name or ""
	if mType == "turtle" or recipe.method == "turtle" then
		for _, enabled in pairs(Config.turtles or {}) do
			if enabled then return true, nil end
		end
		return false, "turtle"
	end
	if mType == "crafter" then
		local ok, why = crafterReady(recipe.grid_cells)
		if ok then return true, nil end
		return false, why
	end
	if recipe.output_device and recipe.output_device ~= "" then
		if not peripheral.wrap(recipe.output_device) then
			return false, recipe.output_device
		end
		if mName ~= "" and not peripheral.wrap(mName) then
			return false, mName
		end
		return true, nil
	end
	if mName == "" then return true, nil end
	local available = listMachines()
	for _, cg in ipairs(CustomMachineGroups) do
		for _, cm in ipairs(cg.machines) do
			if cm == mName then
				for _, gm in ipairs(cg.machines) do
					for _, am in ipairs(available) do
						if am == gm then return true, nil end
					end
				end
				return false, mName
			end
		end
	end
	if Machines.excluded(mName) then
		for _, m in ipairs(available) do
			if m == mName then return true, nil end
		end
		return false, mName
	end
	local baseName = getMachBase(mName)
	for _, m in ipairs(available) do
		if getMachBase(m) == baseName and not Machines.excluded(m) then
			return true, nil
		end
	end
	return false, mName
end
getMachPool = function(machineName)
	for _, cg in ipairs(CustomMachineGroups) do
		for _, cm in ipairs(cg.machines) do
			if cm == machineName then
				local pool = {}
				for _, pm in ipairs(cg.machines) do table.insert(pool, pm) end
				table.sort(pool)
				return pool
			end
		end
	end
	if Machines.excluded(machineName) then
		return { machineName }
	end
	local inCustom = {}
	for _, cg in ipairs(CustomMachineGroups) do
		for _, cm in ipairs(cg.machines) do inCustom[cm] = true end
	end
	local baseName = getMachBase(machineName)
	local all = listMachines()
	local pool = {}
	for _, m in ipairs(all) do
		if getMachBase(m) == baseName and not Machines.excluded(m) and not inCustom[m] then
			table.insert(pool, m)
		end
	end
	if #pool == 0 then return { machineName } end
	table.sort(pool)
	return pool
end


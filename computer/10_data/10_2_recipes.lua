function findDup(outName, cand)
	local function sig(r)
		if type(r) ~= "table" or r.type == "fluid" then return nil end
		local parts = {}
		-- crafter grids go past 9 cells (5x5 = 25) and layout matters like turtle
		local n = (r.type == "crafter") and #(r.ingredients or {}) or 9
		for i = 1, n do parts[i] = tostring(r.ingredients and r.ingredients[i] or "nil") end
		if r.type ~= "turtle" and r.type ~= "crafter" then table.sort(parts) end
		local cells = (r.type == "crafter" and r.grid_cells) and table.concat(r.grid_cells, ",") or ""
		return tostring(r.type) .. "|" .. tostring(r.machine_name) .. "|" .. table.concat(parts, ",") .. "|" .. cells
	end

	local target = sig(cand)
	if not target then return false end

	local ex = Recipe.find(outName)
	if ex and sig(ex) == target then return true end
	for _, alt in ipairs(Recipe.altsOf(outName) or {}) do
		if sig(alt) == target then return true end
	end
	return false
end

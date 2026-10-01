function _touchNetwork(zone, x, y)
	if zone.id == "toggle_storage" then
		Config.storages[zone.arg] = not Config.storages[zone.arg]; saveData()
		return true
	elseif zone.id == "toggle_fluid_tank" then
		if Config.fluid_tanks[zone.arg] then Config.fluid_tanks[zone.arg] = nil
		else Config.fluid_tanks[zone.arg] = true end
		saveData()
		return true
	elseif zone.id == "autostock_toggle" then
		Config.autostock_paused = not Config.autostock_paused
		saveData()
		return true
	elseif zone.id == "set_train_box" then
		if Config.train_box == zone.arg then Config.train_box = nil else Config.train_box = zone.arg end
		saveData()
		return true
	elseif zone.id == "set_turtle" then
		if not Config.turtles then Config.turtles = {} end
		if Config.turtles[zone.arg] then
			Config.turtles[zone.arg] = nil
		else
			Config.turtles[zone.arg] = true
		end
		saveData()
		return true
	elseif zone.id == "turtle_remove" then
		if Config.turtles then Config.turtles[zone.arg] = nil end
		saveData()
		return true
	elseif zone.id == "turtle_add" then
		if not Config.turtles then Config.turtles = {} end
		Config.turtles[zone.arg] = true
		saveData()
		return true
	elseif zone.id == "crafter_set_clutch" or zone.id == "crafter_set_pulse" then
		-- each tap walks to the next relay side, past the last side = untagged
		local c = crafterCfg()
		local key = (zone.id == "crafter_set_clutch") and "clutch" or "pulse"
		local sideKey = key .. "_side"
		local nextSide = RELAY_SIDES[1]
		if c[key] == zone.arg and c[sideKey] then
			nextSide = nil
			for si, s in ipairs(RELAY_SIDES) do
				if s == c[sideKey] then nextSide = RELAY_SIDES[si + 1]; break end
			end
		end
		local r = peripheral.wrap(zone.arg)
		-- old side goes quiet so it cant keep a clutch/crafter powered
		if c[key] == zone.arg and c[sideKey] and r and r.setOutput then pcall(r.setOutput, c[sideKey], false) end
		if nextSide then
			c[key], c[sideKey] = zone.arg, nextSide
			-- clutch starts engaged-safe: locked
			if key == "clutch" then pcall(crafterSetLock, true) end
		else
			c[key], c[sideKey] = nil, nil
		end
		saveData()
		return true
	elseif zone.id == "crafter_set_out" then
		local c = crafterCfg()
		if c.out == zone.arg then
			c.out = nil
		else
			c.out = zone.arg
			-- output inv is a buffer, not stock. vault tag would let crafts pull from it
			Config.storages[zone.arg] = nil
			if Config.train_box == zone.arg then Config.train_box = nil end
		end
		saveData()
		return true
	end
	return false
end

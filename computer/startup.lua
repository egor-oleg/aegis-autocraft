local MONITOR_SIDE = "right"
local RECIPES_FILE     = "factory_recipes.json"
local CONFIG_FILE      = "factory_config.json"
local AUTOSTOCK_FILE   = "factory_autostock.json"
local GROUPS_FILE      = "factory_groups.json"
local ALT_RECIPES_FILE = "factory_alt_recipes.json"
local MGMT_FILE           = "factory_mgmt.json"
local MACHINE_LABELS_FILE = "factory_machine_labels.json"
local CUSTOM_MG_FILE      = "factory_custom_mg.json"
local FLUIDS_FILE         = "factory_fluids.json"
local FLUID_ALTS_FILE     = "factory_fluid_alts.json"
local Recipes = {}
local Config = {
storages = {},
fluid_tanks = {},
train_box = nil,
turtles = {},
autostock_paused = false,
github_repo  = "",
github_token = ""
}
local FluidRecipes = {}
local FluidAltRecipes = {}
local FluidStock   = {}
local Autostock = {}
local ExcludedMachines = {}
local AltRecipes  = {}
local MgmtGroups     = {}
local MachineLabels       = {}
local CustomMachineGroups = {}
local ITEM_GROUPS = {}
local GROUPS = {}
currentTab = "RECIPES"
currentModFilter = "All"
searchFilter = ""
uiMessage = ""
uiMsgTimer = nil
craftErrorLines = {}; craftErrorTitle = nil
craftErrorEditItems = {}
craftQueue = {}
craftQueuePopup = false
craftQueueErrIdx = nil
craftQueueScroll = 0
queueEditIdx = nil
ntfyLastId = nil
craftStageDone = 0
craftStageTotal = 0
selectedCraftType = "turtle"
systemStatus = "IDLE"
altViewItem   = nil
altViewFluid  = nil
learnAsAlt    = false
learnAsAltItem = nil
currentPage = 1
modFilterPage = 1
fluidSubTab = "FLUID"
fluidTankPage = 1
fluidRecipePage = 1
fluidLearnStage = nil
fluidLearnInputs = {}
fluidLearnMachine = nil
fluidLearnOutput = nil
fluidOutputPick = false
fluidLearnItemIn = nil
fluidItemInPick = false
fluidLearnFluidIn = nil
fluidFluidInPick = false
fluidLearnItemOut = nil
fluidItemOutPick = false
fluidLearnPage = 1
fluidScanStatus = ""
fluidCraftMsg = ""
fluidInputWaitName = nil
fluidCraftWaitFluid = nil
fluidRecipePicker = nil
fluidSaveConfirm = nil
pendingDeleteFluid = nil
fluidKeepName = nil
fluidKeepFilter = "All"
keepThr = 0
keepTgt = 0
keepField = "threshold"
fluidSearchFilter = ""
fluidCraftMode = nil
fluidGoalLabel = ""
fluidStepNum = 0
fluidStepTotal = 1
fluidSubLabel = ""
fluidScanResults = {}
_fpCache = {}
craftSubTab = "TURTLE"
craftDevicePage = 1
selectedOutputDevice = nil
outputPickMode = false
pendingTouches = {}
cancelCrafting = false
craftCleanupMachines = {}
craftLocks = {}
displayCtx = nil
fluidTankClaims = 0
_fluidStoreBusy = false
fluidInlineByCo = {}
craftUsedMachines = {}
function lockOwnerId()
return coroutine.running() or "main"
end
function tryAcquireTokens(tokens)
local me = lockOwnerId()
for _, t in ipairs(tokens) do
local l = craftLocks[t]
if l and l.owner ~= me then return false end
end
for _, t in ipairs(tokens) do
local l = craftLocks[t]
if l then l.count = l.count + 1
else craftLocks[t] = { owner = me, count = 1 } end
end
return true
end
function releaseTokens(tokens)
local me = lockOwnerId()
for _, t in ipairs(tokens) do
local l = craftLocks[t]
if l and l.owner == me then
l.count = l.count - 1
if l.count <= 0 then craftLocks[t] = nil end
end
end
end
craftCancelY  = nil
craftCancelX1 = 2
craftCancelX2 = 20
pendingDeleteItem    = nil
autostockCurrentItem = ""
idleTimer = nil
autostockIdleSecs = 180
isRequestMode = false
requestMaxQty = 0
pickerMaxCraftable = 0
pickerMaxCapped = false
pickerMaxComputed = true
pickerHeaderSnap = nil
calcNodes = 0
calcBudget = 0
CALC_BUDGET = 100
qtyOriginTab = "RECIPES"
craftCompletePopup = nil
stockSearchFilter  = ""
stockModFilter     = "All"
stockModFilterPage = 1
unloadActive      = false
unloadTimer       = nil
searchInputActive      = false
stockSearchInputActive = false
recipesScanResults = {}
craftInfoPopup     = nil
machineInfoPopup   = nil
qtyTypeActive      = false
craftHistory       = {}
historyPopup       = nil
scanActive         = false
scanTimer          = nil
recipeEditPopup    = nil
altOutEdit         = nil
mgmtItemSearch       = ""
mgmtItemSearchActive = false
itemToCraft = ""
craftQuantity = 1
isSettingKeepLimit = false
learningState = "IDLE"
learnedResult = nil
learnedIngredients = nil
learnedTools = nil
learnedCraftType = ""
learnedMachineName = ""
learnedOutputDevice = nil
checkTimer = nil
mgmtPage      = 1
mgmtPopup     = nil
custGrpPopup  = nil
mgmtSyncInfo      = ""
mgmtTickCount     = 0
mgmtActiveBtn     = nil
mgmtSyncFlashTime = nil
gitStatus       = ""
gitStatusColor  = colors.gray
gitStatusTimer  = nil
gitFileList     = {}
gitImportMode   = false
gitSelectedFile = 1
gitWorking      = false
gitActiveButton = ""
gitExportMode     = false
gitExportFileList = {}
gitExportSelected = 0
gitImportPage     = 1
gitExportPage     = 1
local monitor = peripheral.wrap(MONITOR_SIDE)
if not monitor then error("Monitor not found on side: " .. MONITOR_SIDE) end
monitor.setTextScale(0.5)
local SYSTEM_SIDES = { top = true, bottom = true, left = true, right = true, front = true, back = true }
local function parseJSON(str)
local result = textutils.unserializeJSON(str)
if result == textutils.empty_json_array then return {} end
return result
end
_savedCounts = {}
dataRestoredFromBak = false
function loadDataFile(path)
if not fs.exists(path) then return nil end
local fh = fs.open(path, "r")
if not fh then return nil end
local raw = fh.readAll() or ""
fh.close()
local parsed = parseJSON(raw)
local bak = path .. ".bak"
if type(parsed) == "table" and next(parsed) ~= nil then
local n = 0
for _ in pairs(parsed) do n = n + 1 end
_savedCounts[path] = n
if fs.exists(bak) and fs.getSize(bak) == 0 then pcall(fs.delete, bak) end
if not fs.exists(bak) then
local free = fs.getFreeSpace("/") or 0
if free > #raw + 4096 then
local bh = fs.open(bak, "w")
if bh then bh.write(raw); bh.close() end
end
end
return parsed
end
if #raw > 2 and parsed == nil then
pcall(fs.delete, path .. ".corrupt")
pcall(fs.copy, path, path .. ".corrupt")
end
if fs.exists(bak) then
local bh = fs.open(bak, "r")
if bh then
local bp = parseJSON(bh.readAll() or "")
bh.close()
if type(bp) == "table" and next(bp) ~= nil then
local n = 0
for _ in pairs(bp) do n = n + 1 end
_savedCounts[path] = n
dataRestoredFromBak = true
return bp
end
end
end
if type(parsed) == "table" then _savedCounts[path] = 0 end
return parsed
end
function findDuplicateRecipe(outName, cand)
local function sig(r)
if type(r) ~= "table" or r.type == "fluid" then return nil end
local parts = {}
for i = 1, 9 do parts[i] = tostring(r.ingredients and r.ingredients[i] or "nil") end
if r.type ~= "turtle" then table.sort(parts) end
return tostring(r.type) .. "|" .. tostring(r.machine_name) .. "|" .. table.concat(parts, ",")
end
local target = sig(cand)
if not target then return false end
local ex = Recipes[outName]
if ex and sig(ex) == target then return true end
for _, alt in ipairs(AltRecipes[outName] or {}) do
if sig(alt) == target then return true end
end
return false
end
local function initDataFiles()
local defaults = {
{ RECIPES_FILE,        "{}"  },
{ CONFIG_FILE,         textutils.serializeJSON({storages={}, turtles={}, autostock_paused=false}) },
{ AUTOSTOCK_FILE,      "{}"  },
{ GROUPS_FILE,         "{}"  },
{ ALT_RECIPES_FILE,    "{}"  },
{ MGMT_FILE,           "[]"  },
{ MACHINE_LABELS_FILE, "{}"  },
{ CUSTOM_MG_FILE,      "[]"  },
{ FLUIDS_FILE,         "{}"  },
{ FLUID_ALTS_FILE,     "{}"  },
}
for _, entry in ipairs(defaults) do
local path, data = entry[1], entry[2]
if not fs.exists(path) then
local fh = fs.open(path, "w")
if fh then fh.write(data); fh.close() end
end
end
end
local function loadData()
if fs.exists(RECIPES_FILE) then
local raw = loadDataFile(RECIPES_FILE) or {}
if raw.recipes and type(raw.recipes) == "table" then
Recipes = raw.recipes
if raw.alt_recipes    and type(raw.alt_recipes)    == "table" then AltRecipes    = raw.alt_recipes    end
if raw.machine_labels and type(raw.machine_labels) == "table" then MachineLabels = raw.machine_labels end
local fMigrate = fs.open(RECIPES_FILE, "w")
if fMigrate then fMigrate.write(textutils.serializeJSON(Recipes)); fMigrate.close() end
else
Recipes = raw
end
end
if fs.exists(CONFIG_FILE) then
Config = loadDataFile(CONFIG_FILE) or {storages={}, train_box=nil, turtles={}, autostock_paused=false}
end
if not Config.turtles then Config.turtles = {} end
if not Config.storages then Config.storages = {} end
if not Config.fluid_tanks then Config.fluid_tanks = {} end
if Config.turtle and Config.turtle ~= "" then
Config.turtles[Config.turtle] = true
Config.turtle = nil
end
if fs.exists(FLUIDS_FILE) then
FluidRecipes = loadDataFile(FLUIDS_FILE) or {}
end
if fs.exists(FLUID_ALTS_FILE) then
FluidAltRecipes = loadDataFile(FLUID_ALTS_FILE) or {}
end
if fs.exists(AUTOSTOCK_FILE) then
Autostock = loadDataFile(AUTOSTOCK_FILE) or {}
end
if fs.exists(GROUPS_FILE) then
local raw = loadDataFile(GROUPS_FILE) or {}
ExcludedMachines = {}
for k, v in pairs(raw) do
if type(k) == "string" and type(v) == "boolean" then
ExcludedMachines[k] = v
end
end
end
if fs.exists(ALT_RECIPES_FILE) then
AltRecipes = loadDataFile(ALT_RECIPES_FILE) or {}
end
if fs.exists(MGMT_FILE) then
MgmtGroups = loadDataFile(MGMT_FILE) or {}
end
if fs.exists(MACHINE_LABELS_FILE) then
MachineLabels = loadDataFile(MACHINE_LABELS_FILE) or {}
end
if fs.exists(CUSTOM_MG_FILE) then
local raw2 = loadDataFile(CUSTOM_MG_FILE) or {}
if type(raw2) == "table" then CustomMachineGroups = raw2 end
end
end
local function syncFluidItemStubs()
local itemSrc = {}
for key, rec in pairs(FluidRecipes) do
for _, o in ipairs(rec.item_outputs or {}) do
if not itemSrc[o.name] then itemSrc[o.name] = {count = o.count, key = key, machine = rec.machine_name} end
end
end
for key, alts in pairs(FluidAltRecipes) do
for _, rec in ipairs(alts) do
for _, o in ipairs(rec.item_outputs or {}) do
if not itemSrc[o.name] then itemSrc[o.name] = {count = o.count, key = key, machine = rec.machine_name} end
end
end
end
for itemName, rec in pairs(Recipes) do
if type(rec) == "table" and rec.type == "fluid" and not itemSrc[itemName] then
Recipes[itemName] = nil
end
end
for itemName, src in pairs(itemSrc) do
local existing = Recipes[itemName]
if not existing or (type(existing) == "table" and existing.type == "fluid") then
Recipes[itemName] = {
type = "fluid",
fluid_key = src.key,
machine_name = src.machine,
output_count = src.count,
ingredients = {"nil","nil","nil","nil","nil","nil","nil","nil","nil"},
}
end
end
end
local function saveData()
if _fpCache then for k in pairs(_fpCache) do _fpCache[k] = nil end end
local failNote = nil
local function writeFile(path, tbl)
local n = 0
for _ in pairs(tbl) do n = n + 1 end
local prev = _savedCounts[path]
if prev and prev >= 5 and n < prev * 0.5 then
failNote = "SAVE BLOCKED: " .. fs.getName(path) .. " " .. prev .. "->" .. n
return
end
local okS, data = pcall(textutils.serializeJSON, tbl)
if not (okS and type(data) == "string") then
failNote = "SERIALIZE FAIL: " .. fs.getName(path)
return
end
local tmp = path .. ".new"
local function tryWrite()
local okT = pcall(function()
local fh = fs.open(tmp, "w")
if not fh then error("open") end
fh.write(data)
fh.close()
end)
return okT and fs.exists(tmp) and fs.getSize(tmp) >= #data
end
local okW = tryWrite()
if not okW then
pcall(fs.delete, tmp)
pcall(fs.delete, path .. ".bak")
okW = tryWrite()
end
if not okW then
pcall(fs.delete, tmp)
failNote = "SAVE FAIL (disk space?): " .. fs.getName(path)
return
end
fs.delete(path)
fs.move(tmp, path)
local free = fs.getFreeSpace("/") or 0
if free > fs.getSize(path) + 4096 then
pcall(fs.delete, path .. ".bak")
pcall(fs.copy, path, path .. ".bak")
end
_savedCounts[path] = n
end
local recipesToSave = {}
for k, v in pairs(Recipes) do
if not (type(v) == "table" and v.type == "fluid") then recipesToSave[k] = v end
end
writeFile(RECIPES_FILE, recipesToSave)
local configToSave = {}
for k, v in pairs(Config) do configToSave[k] = v end
configToSave.github_token = nil
configToSave.github_repo  = nil
writeFile(CONFIG_FILE, configToSave)
writeFile(AUTOSTOCK_FILE,      Autostock)
writeFile(GROUPS_FILE,         ExcludedMachines)
writeFile(ALT_RECIPES_FILE,    AltRecipes)
writeFile(MGMT_FILE,           MgmtGroups)
writeFile(MACHINE_LABELS_FILE, MachineLabels)
writeFile(CUSTOM_MG_FILE,      CustomMachineGroups)
writeFile(FLUIDS_FILE,         FluidRecipes)
writeFile(FLUID_ALTS_FILE,     FluidAltRecipes)
if failNote then
uiMessage = failNote
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(6)
end
end
local function providerSources()
local out, seen = {}, {}
for _, g in ipairs(MgmtGroups or {}) do
if g.provider and not g.paused then
for _, src in ipairs(mgmtIOList(g, true)) do
if src and src ~= "" and src ~= "STORAGE"
and not Config.storages[src]
and not (Config.fluid_tanks and Config.fluid_tanks[src])
and not seen[src] then
seen[src] = true
out[#out + 1] = src
end
end
end
end
return out
end
function batchPeripheralScan(names, method, withSize)
local out = {}
if #names == 0 then return out end
while _batchScanBusy do sleep(0.05) end
_batchScanBusy = true
local i = 1
while i <= #names do
local hi = math.min(i + 63, #names)
local tasks = {}
for j = i, hi do
local nm = names[j]
tasks[#tasks + 1] = function()
local p = peripheral.wrap(nm)
if p and p[method] then
local e = {}
local ok, res = pcall(p[method])
if ok then e.data = res end
if withSize and p.size then
local ok2, sz = pcall(p.size)
if ok2 then e.size = sz end
end
out[nm] = e
end
end
end
local okAll, errAll = pcall(parallel.waitForAll, table.unpack(tasks))
if not okAll then
_batchScanBusy = false
error(errAll, 0)
end
i = hi + 1
end
_batchScanBusy = false
return out
end
local function getStorageInventory()
local inventory = {}
local totalItems, vaultsCount = 0, 0
local totalSlots, usedSlots = 0, 0
local names = {}
for storageName, isEnabled in pairs(Config.storages) do
if isEnabled and not SYSTEM_SIDES[storageName] then names[#names + 1] = storageName end
end
local scanned = batchPeripheralScan(names, "list", true)
for _, nm in ipairs(names) do
local e = scanned[nm]
if e then
vaultsCount = vaultsCount + 1
if e.size then totalSlots = totalSlots + e.size end
if e.data then
for _, item in pairs(e.data) do
if item then
inventory[item.name] = (inventory[item.name] or 0) + item.count
totalItems = totalItems + item.count
usedSlots  = usedSlots + 1
end
end
end
end
end
local provNames = providerSources()
local pScan = batchPeripheralScan(provNames, "list")
for _, nm in ipairs(provNames) do
local e = pScan[nm]
if e and e.data then
for _, item in pairs(e.data) do
if item then inventory[item.name] = (inventory[item.name] or 0) + item.count end
end
end
end
local freeSlots = totalSlots - usedSlots
return inventory, totalItems, vaultsCount, freeSlots, totalSlots
end
local _flInvCache, _flInvCacheT = nil, -100
local _tankStatsCache, _tankStatsT = nil, -100
local _stInvCache, _stInvCacheT = nil, -100
local function invalidateStockCache()
_flInvCacheT = -100
_tankStatsT = -100
_stInvCacheT = -100
end
local function getStorageInventoryCached()
local now = os.clock()
if _stInvCache and (now - _stInvCacheT) < 4 then
local c = _stInvCache
return c[1], c[2], c[3], c[4], c[5]
end
local a, b, cc, d, e = getStorageInventory()
_stInvCache = {a, b, cc, d, e}
_stInvCacheT = now
return a, b, cc, d, e
end
local function fluidKey(fluidName) return "f:" .. fluidName end
local function fluidNameFromKey(key)
if type(key) == "string" and key:sub(1, 2) == "f:" then return key:sub(3) end
return key
end
local function primaryRecipeKey(recipe)
if recipe.outputs and recipe.outputs[1] then return fluidKey(recipe.outputs[1].name) end
if recipe.item_outputs and recipe.item_outputs[1] then return "i:" .. recipe.item_outputs[1].name end
return nil
end
local pushFromStorage
local sleepCheckCancel
local runCraftingProcess
local ensureItemAvailable
local drawFluidProgress
local drawFluidScanCancel
local simFluidConsume
local crossCraftDepth = 0
local function findFluidItemProducer(itemName)
for _, rec in pairs(FluidRecipes) do
for _, o in ipairs(rec.item_outputs or {}) do
if o.name == itemName then return rec, o.count end
end
end
for _, alts in pairs(FluidAltRecipes) do
for _, rec in ipairs(alts) do
for _, o in ipairs(rec.item_outputs or {}) do
if o.name == itemName then return rec, o.count end
end
end
end
return nil
end
local function getFluidInventory()
local inventory  = {}
local tankCount  = 0
local totalMb    = 0
local tankDetails = {}
local names = {}
for tankName, isEnabled in pairs(Config.fluid_tanks or {}) do
if isEnabled and not SYSTEM_SIDES[tankName] then names[#names + 1] = tankName end
end
local scanned = batchPeripheralScan(names, "tanks")
for _, nm in ipairs(names) do
local e = scanned[nm]
if e then
tankCount = tankCount + 1
if e.data then
for _, t in pairs(e.data) do
if t and t.name and t.amount and t.amount > 0 then
local k = fluidKey(t.name)
inventory[k] = (inventory[k] or 0) + t.amount
totalMb = totalMb + t.amount
table.insert(tankDetails, {periph = nm, fluid = t.name, amount = t.amount})
end
end
end
end
end
return inventory, tankCount, totalMb, tankDetails
end
local function getFluidInventoryCached()
local now = os.clock()
if _flInvCache and (now - _flInvCacheT) < 6 then return _flInvCache end
_flInvCache = (getFluidInventory())
_flInvCacheT = now
return _flInvCache
end
local function getTankStats()
local now = os.clock()
if _tankStatsCache and (now - _tankStatsT) < 6 then
return _tankStatsCache.free, _tankStatsCache.total
end
local total, free = 0, 0
local names = {}
for tankName, en in pairs(Config.fluid_tanks or {}) do
if en and not SYSTEM_SIDES[tankName] then names[#names + 1] = tankName end
end
local scanned = batchPeripheralScan(names, "tanks")
for _, nm in ipairs(names) do
local e = scanned[nm]
if e then
total = total + 1
local hasFluid = false
if e.data then
for _, t in pairs(e.data) do
if t and t.amount and t.amount > 0 then hasFluid = true; break end
end
end
if not hasFluid then free = free + 1 end
end
end
_tankStatsCache = {free = free, total = total}
_tankStatsT = now
return free, total
end
local function fluidTankList()
local out = {}
for name, en in pairs(Config.fluid_tanks or {}) do
if en and not SYSTEM_SIDES[name] then out[#out + 1] = name end
end
return out
end
local function tankContents(periphName)
local res = {}
local t = peripheral.wrap(periphName)
if not (t and t.tanks) then return res end
local ok, list = pcall(t.tanks)
if ok and list then
for _, e in pairs(list) do
if e and e.name and e.amount and e.amount > 0 then
res[e.name] = (res[e.name] or 0) + e.amount
end
end
end
return res
end
local function tanksWithFluid(fluidName)
local out = {}
local names = fluidTankList()
local scanned = batchPeripheralScan(names, "tanks")
for _, name in ipairs(names) do
local e = scanned[name]
if e and e.data then
local amt = 0
for _, t in pairs(e.data) do
if t and t.name == fluidName and t.amount then amt = amt + t.amount end
end
if amt > 0 then out[#out + 1] = {periph = name, amount = amt} end
end
end
table.sort(out, function(a, b) return a.amount > b.amount end)
return out
end
local function pushFluidToMachine(machineName, fluidName, amount)
local moved = 0
for _, src in ipairs(tanksWithFluid(fluidName)) do
if moved >= amount then break end
local t = peripheral.wrap(src.periph)
if t and t.pushFluid then
while moved < amount do
local ok, m = pcall(t.pushFluid, machineName, amount - moved, fluidName)
if ok and type(m) == "number" and m > 0 then moved = moved + m
else break end
end
end
end
if moved > 0 then invalidateStockCache() end
return moved
end
local function fluidTankReservations()
local res = {}
for _, g in ipairs(MgmtGroups or {}) do
local isFluid = g.fluid
if isFluid == nil then
isFluid = (g.input and Config.fluid_tanks and Config.fluid_tanks[g.input])
or (g.output and Config.fluid_tanks and Config.fluid_tanks[g.output]) or false
end
if isFluid then
for _, periph in ipairs({g.output, g.input}) do
if periph and periph ~= "" and periph ~= "STORAGE"
and Config.fluid_tanks and Config.fluid_tanks[periph] then
for _, rule in ipairs(g.rules or {}) do
if rule.item and rule.item ~= "" then
res[periph] = res[periph] or {}
res[periph][rule.item] = true
end
end
end
end
end
end
return res
end
local function drainFluidToStorage(machineName, fluidName, limit)
local moved = 0
local machine = peripheral.wrap(machineName)
local reserved = fluidTankReservations()
local function allowed(tname)
local r = reserved[tname]
return (not r) or r[fluidName]
end
local ordered = {}
local seen = {}
local resvFirst = {}
for tname, fl in pairs(reserved) do
if fl[fluidName] and Config.fluid_tanks and Config.fluid_tanks[tname] then resvFirst[#resvFirst + 1] = tname end
end
table.sort(resvFirst)
for _, name in ipairs(resvFirst) do
if not seen[name] then ordered[#ordered + 1] = name; seen[name] = true end
end
for _, t in ipairs(tanksWithFluid(fluidName)) do
if not seen[t.periph] and allowed(t.periph) then ordered[#ordered + 1] = t.periph; seen[t.periph] = true end
end
local rest = {}
for _, name in ipairs(fluidTankList()) do
if not seen[name] and allowed(name) then rest[#rest + 1] = name end
end
table.sort(rest)
for _, name in ipairs(rest) do ordered[#ordered + 1] = name end
local function srcHas()
if not (machine and machine.tanks) then return false end
local ok, list = pcall(machine.tanks)
if not (ok and list) then return false end
for _, e in pairs(list) do
if e and e.name == fluidName and (e.amount or 0) > 1 then return true end
end
return false
end
for _, periphName in ipairs(ordered) do
if moved >= limit then break end
if machine and machine.pushFluid then
for _ = 1, 128 do
if moved >= limit then break end
local ok, m = pcall(machine.pushFluid, periphName, limit - moved, fluidName)
if not (ok and type(m) == "number" and m > 0) then break end
moved = moved + m
end
end
if moved < limit then
local dst = peripheral.wrap(periphName)
if dst and dst.pullFluid then
for _ = 1, 128 do
if moved >= limit then break end
local ok, m = pcall(dst.pullFluid, machineName, limit - moved, fluidName)
if not (ok and type(m) == "number" and m > 0) then break end
moved = moved + m
end
end
end
if moved < limit and not srcHas() then
if moved > 0 then invalidateStockCache() end
return moved
end
end
if moved > 0 then invalidateStockCache() end
return moved
end
function sweepCraftMachines()
for mName in pairs(craftUsedMachines or {}) do
local m = peripheral.wrap(mName)
if m then
if m.list and m.pushItems then
local ok, items = pcall(m.list)
if ok and items then
for slot, it in pairs(items) do
if it and it.count and it.count > 0 then
local left = it.count
for sName, en in pairs(Config.storages or {}) do
if left <= 0 then break end
if en and not SYSTEM_SIDES[sName] then
local okP, mv = pcall(m.pushItems, sName, slot, left)
if okP and type(mv) == "number" and mv > 0 then left = left - mv end
end
end
end
end
end
end
if m.tanks then
local okT, tl = pcall(m.tanks)
if okT and tl then
for _, tk in pairs(tl) do
if tk and tk.name and tk.amount and tk.amount > 0 then
drainFluidToStorage(mName, tk.name, tk.amount)
end
end
end
end
end
end
craftUsedMachines = {}
end
local function machineFluidSnapshot(machine)
local res = {}
local ok, list = pcall(machine.tanks)
if ok and list then
for _, e in pairs(list) do
if e and e.name and e.amount and e.amount > 0 then
res[e.name] = (res[e.name] or 0) + e.amount
end
end
end
return res
end
local function sameFluidMap(a, b)
for k, v in pairs(a) do if b[k] ~= v then return false end end
for k, v in pairs(b) do if a[k] ~= v then return false end end
return true
end
local function machineItemSnapshot(machineName)
local res = {}
local m = peripheral.wrap(machineName)
if not (m and m.list) then return res end
local ok, items = pcall(m.list)
if ok and items then
for _, it in pairs(items) do
if it and it.name and it.count and it.count > 0 then
res[it.name] = (res[it.name] or 0) + it.count
end
end
end
return res
end
local function waitFluidStable(machine, machineName, timeoutTotal, cancellable, onTick)
local function combo()
local res = {}
for k, v in pairs(machineFluidSnapshot(machine)) do res["f:" .. k] = v end
for k, v in pairs(machineItemSnapshot(machineName)) do res["i:" .. k] = v end
return res
end
local prevC = combo()
local stableCount, sawChange, elapsed = 0, false, 0
while true do
if onTick then onTick() end
if cancellable then
sleepCheckCancel(0.5)
if cancelCrafting then return machineFluidSnapshot(machine), true end
else
sleep(0.5)
end
elapsed = elapsed + 0.5
local curC = combo()
if sameFluidMap(prevC, curC) then
stableCount = stableCount + 1
else
sawChange = true
stableCount = 0
end
prevC = curC
if sawChange and stableCount >= 3 then break end
if not cancellable and elapsed >= timeoutTotal then break end
end
return machineFluidSnapshot(machine), false
end
local function drainMachineItems(machineName)
local m = peripheral.wrap(machineName)
if not (m and m.list and m.pushItems) then return end
local ok, items = pcall(m.list)
if not (ok and items) then return end
for slot, item in pairs(items) do
if item and item.count and item.count > 0 then
local left = item.count
for sName, en in pairs(Config.storages or {}) do
if left <= 0 then break end
if en and not SYSTEM_SIDES[sName] then
local okP, mv = pcall(m.pushItems, sName, slot, left)
if okP and type(mv) == "number" and mv > 0 then left = left - mv end
end
end
end
end
end
local function readBarrelItemsToMachine(machineName)
local counts = {}
if not Config.train_box or Config.train_box == "" then return counts end
local box = peripheral.wrap(Config.train_box)
if not (box and box.list and box.pushItems and box.getItemDetail) then return counts end
local centerSlots = {4, 5, 6, 13, 14, 15, 22, 23, 24}
for _, slot in ipairs(centerSlots) do
local ok, item = pcall(box.getItemDetail, slot)
if ok and item and item.name and item.count and item.count > 0 then
counts[item.name] = (counts[item.name] or 0) + item.count
pcall(box.pushItems, machineName, slot, item.count)
end
end
return counts
end
local function pushItemsToMachine(machineName, itemName, count)
return pushFromStorage(itemName, count, machineName) or 0
end
local function runFluidScan(inputs, machineName, outputDevice, itemInputDevice, fluidInputDevice, itemOutputDevice)
local machine = peripheral.wrap(machineName)
if not (machine and machine.tanks and machine.pushFluid and machine.pullFluid) then
return false, nil, {"Machine missing fluid methods:", machineName}
end
local fluidOutName = (outputDevice and outputDevice ~= "") and outputDevice or machineName
local fluidOutObj  = (fluidOutName ~= machineName) and peripheral.wrap(fluidOutName) or machine
if not fluidOutObj then return false, nil, {"Fluid output device offline:", fluidOutName} end
local itemInName  = (itemInputDevice and itemInputDevice ~= "") and itemInputDevice or machineName
if itemInName ~= machineName and not peripheral.wrap(itemInName) then return false, nil, {"Item input device offline:", itemInName} end
local fluidInName = (fluidInputDevice and fluidInputDevice ~= "") and fluidInputDevice or machineName
if fluidInName ~= machineName and not peripheral.wrap(fluidInName) then return false, nil, {"Fluid input device offline:", fluidInName} end
local itemOutName = (itemOutputDevice and itemOutputDevice ~= "") and itemOutputDevice or fluidOutName
if itemOutName ~= machineName and not peripheral.wrap(itemOutName) then return false, nil, {"Item output device offline:", itemOutName} end
local errLines = {}
local inv = getFluidInventory()
for _, inp in ipairs(inputs) do
local have = inv[fluidKey(inp.name)] or 0
if have < inp.amount then
table.insert(errLines, string.format("Need %d mB %s, have %d", inp.amount, inp.name, have))
end
end
if #errLines > 0 then return false, nil, errLines end
local before = machineFluidSnapshot(fluidOutObj)
local itemsBefore = machineItemSnapshot(itemOutName)
for _, inp in ipairs(inputs) do
local m = pushFluidToMachine(fluidInName, inp.name, inp.amount)
if m < inp.amount then
table.insert(errLines, string.format("Only pushed %d/%d mB %s", m, inp.amount, inp.name))
end
end
local itemCounts = readBarrelItemsToMachine(itemInName)
local inputSet = {}
for _, inp in ipairs(inputs) do inputSet[inp.name] = true end
local inputItemSet = {}
for iname in pairs(itemCounts) do inputItemSet[iname] = true end
local function drainEverything()
for fname in pairs(machineFluidSnapshot(fluidOutObj)) do drainFluidToStorage(fluidOutName, fname, 1000000) end
for fname in pairs(machineFluidSnapshot(machine)) do
if not inputSet[fname] then drainFluidToStorage(machineName, fname, 1000000) end
end
drainMachineItems(machineName)
if itemOutName ~= machineName then drainMachineItems(itemOutName) end
if itemInName ~= machineName then drainMachineItems(itemInName) end
end
local outputs = {}
local itemOutputs = {}
local cancelled = false
local separateOut = (fluidOutName ~= machineName) or (itemOutName ~= machineName)
if separateOut then
local fAgg, iAgg = {}, {}
local quiet, sawAny = 0, false
while true do
if drawFluidScanCancel then drawFluidScanCancel() end
sleepCheckCancel(0.5)
if cancelCrafting then cancelled = true; break end
local moved = false
for fname, amt in pairs(machineFluidSnapshot(fluidOutObj)) do
if not inputSet[fname] and amt > 0 then
local mv = drainFluidToStorage(fluidOutName, fname, 1000000)
if mv and mv > 0 then fAgg[fname] = (fAgg[fname] or 0) + mv; moved = true; sawAny = true end
end
end
local hadItems = false
for iname, cnt in pairs(machineItemSnapshot(itemOutName)) do
if not inputItemSet[iname] and cnt > 0 then
iAgg[iname] = (iAgg[iname] or 0) + cnt; moved = true; sawAny = true; hadItems = true
end
end
if hadItems then drainMachineItems(itemOutName) end
if moved then quiet = 0 else quiet = quiet + 1 end
if sawAny and quiet >= 6 then break end
end
for fname, amt in pairs(fAgg) do if amt > 0 then outputs[#outputs + 1] = {kind = "fluid", name = fname, amount = amt} end end
for iname, cnt in pairs(iAgg) do if cnt > 0 then itemOutputs[#itemOutputs + 1] = {kind = "item", name = iname, count = cnt} end end
else
local after
after, cancelled = waitFluidStable(fluidOutObj, fluidOutName, 0, true, drawFluidScanCancel)
if not cancelled then
for fname, amt in pairs(after) do
if not inputSet[fname] then
local net = amt - (before[fname] or 0)
if net > 0 then outputs[#outputs + 1] = {kind = "fluid", name = fname, amount = net} end
end
end
for iname, cnt in pairs(machineItemSnapshot(itemOutName)) do
if not inputItemSet[iname] then
local net = cnt - (itemsBefore[iname] or 0)
if net > 0 then itemOutputs[#itemOutputs + 1] = {kind = "item", name = iname, count = net} end
end
end
end
end
local function drainFluidIn()
if fluidInName ~= machineName then
for fname in pairs(machineFluidSnapshot(peripheral.wrap(fluidInName))) do drainFluidToStorage(fluidInName, fname, 1000000) end
end
end
if cancelled then
drainEverything(); drainFluidIn(); sleep(0.3); drainEverything(); drainFluidIn()
return false, nil, {"Scan cancelled by user."}
end
table.sort(outputs, function(a, b) return a.amount > b.amount end)
table.sort(itemOutputs, function(a, b) return a.count > b.count end)
drainEverything(); drainFluidIn(); sleep(0.3); drainEverything(); drainFluidIn()
if #outputs == 0 and #itemOutputs == 0 then
table.insert(errLines, "No output detected (fluid or item).")
return false, nil, errLines
end
if Config.train_box and Config.train_box ~= "" then
for _, io2 in ipairs(itemOutputs) do
pushFromStorage(io2.name, io2.count, Config.train_box)
end
end
local recipeInputs = {}
for _, inp in ipairs(inputs) do
recipeInputs[#recipeInputs + 1] = {kind = "fluid", name = inp.name, amount = inp.amount}
end
local itemInputs = {}
for iname, cnt in pairs(itemCounts) do
itemInputs[#itemInputs + 1] = {kind = "item", name = iname, count = cnt}
end
return true, {machine_name = machineName,
output_device = (outputDevice and outputDevice ~= "") and outputDevice or nil,
item_input_device = (itemInputDevice and itemInputDevice ~= "") and itemInputDevice or nil,
fluid_input_device = (fluidInputDevice and fluidInputDevice ~= "") and fluidInputDevice or nil,
item_output_device = (itemOutputDevice and itemOutputDevice ~= "") and itemOutputDevice or nil,
inputs = recipeInputs, item_inputs = itemInputs,
outputs = outputs, item_outputs = itemOutputs}, nil
end
local function planFluidCraft(recipe, targetName, amount)
if not recipe then return false, nil, {"No recipe"} end
local perOp, isItemTarget = nil, false
for _, o in ipairs(recipe.outputs or {}) do
if o.name == targetName then perOp = o.amount; break end
end
if not perOp then
for _, o in ipairs(recipe.item_outputs or {}) do
if o.name == targetName then perOp = o.count; isItemTarget = true; break end
end
end
if not perOp or perOp <= 0 then return false, nil, {"Bad recipe output amount"} end
local ops = math.ceil(amount / perOp)
local inv = getFluidInventory()
local errLines = {}
for _, inp in ipairs(recipe.inputs or {}) do
local need = ops * inp.amount
local have = inv[fluidKey(inp.name)] or 0
if have < need then
local sn = inp.name:match(":(.+)$") or inp.name
table.insert(errLines, string.format("Need %d mB %s, have %d", need, sn, have))
end
end
if recipe.item_inputs and #recipe.item_inputs > 0 then
local stk = getStorageInventory()
for _, it in ipairs(recipe.item_inputs) do
local need = ops * it.count
local have = stk[it.name] or 0
if have < need then
local sn = it.name:match(":(.+)$") or it.name
table.insert(errLines, string.format("Need %dx %s, have %d", need, sn, have))
end
end
end
if #errLines > 0 then return false, nil, errLines end
return true, {recipe = recipe, ops = ops, perOp = perOp, target = targetName, isItem = isItemTarget}, nil
end
local function checkOutputStorage(recipe)
local emptyCount = 0
local held = {}
for _, name in ipairs(fluidTankList()) do
local c = tankContents(name)
if next(c) == nil then emptyCount = emptyCount + 1
else for fn in pairs(c) do held[fn] = true end end
end
local newOuts = {}
for _, o in ipairs(recipe.outputs or {}) do
if not held[o.name] then newOuts[#newOuts + 1] = o.name end
end
if #newOuts > emptyCount - (fluidTankClaims or 0) then
local sn = newOuts[1] and ((newOuts[1]):match(":(.+)$") or newOuts[1]) or "?"
return false, {
"No free [TNK] tank for output: " .. sn,
"Mark an empty tank with [TNK] in NETWORK.",
}
end
return true, nil, #newOuts
end
local getMachinePool
local function runFluidCraftInner(plan)
local recipe = plan.recipe
local baseMachine = recipe.machine_name
local splitOut = nil
if recipe.output_device and recipe.output_device ~= "" then
if peripheral.wrap(recipe.output_device) then
splitOut = recipe.output_device
else
return false, {"Output device not found: " .. tostring(recipe.output_device)}, 0
end
end
local itemInDev = nil
if recipe.item_input_device and recipe.item_input_device ~= "" then
if peripheral.wrap(recipe.item_input_device) then
itemInDev = recipe.item_input_device
else
return false, {"Item input device not found: " .. tostring(recipe.item_input_device)}, 0
end
end
local fluidInDev = nil
if recipe.fluid_input_device and recipe.fluid_input_device ~= "" then
if peripheral.wrap(recipe.fluid_input_device) then
fluidInDev = recipe.fluid_input_device
else
return false, {"Fluid input device not found: " .. tostring(recipe.fluid_input_device)}, 0
end
end
local itemOutDev = nil
if recipe.item_output_device and recipe.item_output_device ~= "" then
if peripheral.wrap(recipe.item_output_device) then
itemOutDev = recipe.item_output_device
else
return false, {"Item output device not found: " .. tostring(recipe.item_output_device)}, 0
end
end
local pool = {}
if splitOut or itemInDev or fluidInDev or itemOutDev then
local pp = peripheral.wrap(baseMachine)
if pp and pp.tanks and pp.pushFluid and pp.pullFluid then pool = {baseMachine} end
else
for _, pmName in ipairs(getMachinePool(baseMachine)) do
local pp = peripheral.wrap(pmName)
if pp and pp.tanks and pp.pushFluid and pp.pullFluid then
pool[#pool + 1] = pmName
end
end
end
if #pool == 0 then
return false, {"Machine missing fluid methods: " .. tostring(baseMachine)}, 0
end
for _, pmName in ipairs(pool) do craftUsedMachines[pmName] = true end
if splitOut   then craftUsedMachines[splitOut]   = true end
if itemInDev  then craftUsedMachines[itemInDev]  = true end
if fluidInDev then craftUsedMachines[fluidInDev] = true end
if itemOutDev then craftUsedMachines[itemOutDev] = true end
local inFluidSet, inItemSet = {}, {}
for _, inp in ipairs(recipe.inputs or {}) do inFluidSet[inp.name] = true end
for _, it in ipairs(recipe.item_inputs or {}) do inItemSet[it.name] = true end
local targetName = plan.label
local targetIsItem = false
for _, o in ipairs(recipe.item_outputs or {}) do
if o.name == targetName then targetIsItem = true; break end
end
local itemMaxStack = {}
for _, it in ipairs(recipe.item_inputs or {}) do
local maxS = 64
for sName, en in pairs(Config.storages or {}) do
if en and not SYSTEM_SIDES[sName] then
local sto = peripheral.wrap(sName)
if sto and sto.list and sto.getItemDetail then
local okL, lst = pcall(sto.list)
if okL and lst then
local found = false
for slotI, itemI in pairs(lst) do
if itemI and itemI.name == it.name then
local okD, det = pcall(sto.getItemDetail, slotI)
if okD and det and det.maxCount and det.maxCount > 0 then maxS = det.maxCount end
found = true
break
end
end
if found then break end
end
end
end
end
itemMaxStack[it.name] = maxS
end
local label = plan.label or baseMachine or "fluid"
fluidStepNum = fluidStepNum + 1
if fluidStepNum > fluidStepTotal then fluidStepTotal = fluidStepNum end
fluidSubLabel = label
local totalOps = plan.ops
local produced = 0
local function pushBatch(mName, wantOps)
local accepted = wantOps
for _, it in ipairs(recipe.item_inputs or {}) do
local maxS = itemMaxStack[it.name] or 64
if maxS >= it.count then
local maxOpsForItem = math.floor(maxS / it.count)
if maxOpsForItem < accepted then accepted = maxOpsForItem end
elseif accepted > 1 then
accepted = 1
end
end
for _, inp in ipairs(recipe.inputs or {}) do
local avail = 0
for _, src in ipairs(tanksWithFluid(inp.name)) do avail = avail + (src.amount or 0) end
local opsForInp = math.floor(avail / inp.amount)
if opsForInp < accepted then accepted = opsForInp end
end
if accepted < 1 then return 0 end
local fDev = fluidInDev or mName
local fPer = peripheral.wrap(fDev)
if fPer and #(recipe.inputs or {}) > 0 then
local seqPour = (splitOut ~= nil or itemInDev ~= nil or fluidInDev ~= nil or itemOutDev ~= nil)
and #(recipe.inputs or {}) > 1
local preF = machineFluidSnapshot(fPer)
for fi, inp in ipairs(recipe.inputs or {}) do
if seqPour and fi > 1 then
local prevName = recipe.inputs[fi - 1].name
local waitC = 0
while waitC < 40 do
local snapW = machineFluidSnapshot(fPer)
if (snapW[prevName] or 0) <= 0 then break end
sleepCheckCancel(0.5)
if cancelCrafting then return 0 end
waitC = waitC + 1
end
preF = machineFluidSnapshot(fPer)
end
local have   = preF[inp.name] or 0
local curOps = math.floor(have / inp.amount)
local needed = (curOps + accepted) * inp.amount - have
local moved  = 0
if needed > 0 then moved = pushFluidToMachine(fDev, inp.name, needed) end
local newOps = math.floor((have + moved) / inp.amount) - curOps
if newOps < accepted then accepted = math.max(0, newOps) end
end
if accepted < 1 then return 0 end
end
local iDev = itemInDev or mName
local preI = {}
if #(recipe.item_inputs or {}) > 0 then
local iPer = peripheral.wrap(iDev)
if iPer and iPer.list then
local okI, its = pcall(iPer.list)
if okI and its then
for _, it2 in pairs(its) do
if it2 and inItemSet[it2.name] then
preI[it2.name] = (preI[it2.name] or 0) + (it2.count or 0)
end
end
end
end
end
for _, it in ipairs(recipe.item_inputs or {}) do
local have   = preI[it.name] or 0
local curOps = math.floor(have / it.count)
local needed = (curOps + accepted) * it.count - have
local moved  = 0
if needed > 0 then moved = pushItemsToMachine(iDev, it.name, needed) or 0 end
local newOps = math.floor((have + moved) / it.count) - curOps
if newOps < accepted then accepted = math.max(0, newOps) end
end
return accepted
end
local function drainMachine(e)
local targetMoved = 0
local anyOutput = false
local devs = { e.drain, e.name, itemOutDev }
for _ = 1, 8 do
local passMoved = 0
local seenF = {}
for _, dn in ipairs(devs) do
if dn and not seenF[dn] then
seenF[dn] = true
local isDedicatedOut = (splitOut ~= nil and dn == splitOut)
local machine = peripheral.wrap(dn)
if machine and machine.tanks then
local snap = machineFluidSnapshot(machine)
for fname, amt in pairs(snap) do
if amt > 1 and (isDedicatedOut or not inFluidSet[fname]) then
local moved = drainFluidToStorage(dn, fname, 1000000)
if moved and moved > 0 then
passMoved = passMoved + moved; anyOutput = true
if (not targetIsItem) and fname == targetName then targetMoved = targetMoved + moved end
end
end
end
end
end
end
local seenI = {}
for _, dn in ipairs(devs) do
if dn and not seenI[dn] then
seenI[dn] = true
local isDedicatedItemOut = (itemOutDev ~= nil and dn == itemOutDev)
local m = peripheral.wrap(dn)
if m and m.list and m.pushItems then
local ok, items = pcall(m.list)
if ok and items then
for slot, item in pairs(items) do
if item and item.count and item.count > 0 and (isDedicatedItemOut or not inItemSet[item.name]) then
local left = item.count
for sName, en in pairs(Config.storages or {}) do
if left <= 0 then break end
if en and not SYSTEM_SIDES[sName] then
local okP, mv = pcall(m.pushItems, sName, slot, left)
if okP and type(mv) == "number" and mv > 0 then left = left - mv end
end
end
local mvd = item.count - left
if mvd > 0 then
passMoved = passMoved + mvd; anyOutput = true
if targetIsItem and item.name == targetName then targetMoved = targetMoved + mvd end
end
end
end
end
end
end
end
if passMoved == 0 then break end
end
return targetMoved, anyOutput
end
local function finalDrain(mName)
local machine = peripheral.wrap(mName)
for pass = 1, 5 do
local snap = machineFluidSnapshot(machine)
local itemSnap = machineItemSnapshot(mName)
if next(snap) == nil and next(itemSnap) == nil then break end
for fname in pairs(snap) do drainFluidToStorage(mName, fname, 1000000) end
drainMachineItems(mName)
end
end
local function availableOps()
if #(recipe.inputs or {}) == 0 then return nil end
local minOps = nil
for _, inp in ipairs(recipe.inputs) do
local avail = 0
for _, src in ipairs(tanksWithFluid(inp.name)) do avail = avail + (src.amount or 0) end
local opsForInp = math.floor(avail / inp.amount)
if minOps == nil or opsForInp < minOps then minOps = opsForInp end
end
return minOps
end
local poolSize = #pool
local base  = math.floor(totalOps / poolSize)
local extra = totalOps % poolSize
local machineData = {}
for idx, mName in ipairs(pool) do
local assigned = base + ((idx <= extra) and 1 or 0)
if assigned > 0 then
machineData[#machineData + 1] = {
name        = mName,
drain       = splitOut or mName,
remainOps   = assigned,
batchTarget = 0,
batchDone   = 0,
idle        = 0,
starve      = 0,
startedOut  = false,
finished    = false,
}
end
end
local function finalDrainEntry(e)
local seen = {}
for _, d in ipairs({e.name, e.drain, itemInDev, fluidInDev, itemOutDev}) do
if d and not seen[d] then seen[d] = true; finalDrain(d) end
end
end
for _, e in ipairs(machineData) do finalDrainEntry(e) end
local totalExpected = totalOps * plan.perOp
local maxWait = math.max(400, totalOps * 30)
local waited  = 0
local function allFinished()
for _, e in ipairs(machineData) do
if not e.finished then return false end
end
return true
end
while (not allFinished()) and produced < totalExpected and waited < maxWait do
sleepCheckCancel(0.5)
if cancelCrafting then
for _, e in ipairs(machineData) do finalDrainEntry(e) end
invalidateStockCache()
return false, {"Cancelled by user."}, produced
end
waited = waited + 1
local refillNeeded = {}
for _, e in ipairs(machineData) do
if not e.finished then
local moved, hadOut = drainMachine(e)
if moved > 0 then
produced = produced + moved
e.batchDone = e.batchDone + moved
end
if hadOut then e.startedOut = true; e.idle = 0 else e.idle = e.idle + 1 end
if e.batchDone >= e.batchTarget and not hadOut then
if e.remainOps > 0 then
refillNeeded[#refillNeeded + 1] = e
else
e.finished = true
end
elseif e.startedOut and e.idle >= 30 then
e.finished = true
end
end
end
if #refillNeeded > 0 then
local avail = availableOps()
local share
if avail == nil then
share = nil
else
share = math.max(1, math.floor(avail / #refillNeeded))
end
for _, e in ipairs(refillNeeded) do
local want = e.remainOps
if share and share < want then want = share end
if want < 1 then want = 1 end
local acc = pushBatch(e.name, want)
if acc > 0 then
e.batchTarget = e.batchTarget + acc * plan.perOp
e.remainOps   = e.remainOps - acc
e.startedOut  = false
e.idle        = 0
e.starve      = 0
else
e.starve = e.starve + 1
if e.starve >= 12 then
e.finished = true
else
sleepCheckCancel(1)
end
end
end
end
if drawFluidProgress then
local doneOpsNow = math.min(totalOps, math.floor(produced / math.max(1, plan.perOp)))
local activeW = 0
for _, e in ipairs(machineData) do if not e.finished then activeW = activeW + 1 end end
drawFluidProgress(label, doneOpsNow, totalOps, activeW)
end
end
for _, e in ipairs(machineData) do finalDrainEntry(e) end
invalidateStockCache()
if produced <= 0 and totalOps > 0 then
return false, {"Could not push inputs to " .. tostring(baseMachine)}, produced
end
if crossCraftDepth == 0 and (craftStageDone or 0) < (craftStageTotal or 0) then
craftStageDone = (craftStageDone or 0) + 1
end
return true, nil, produced
end
runFluidCraft = function(fplan)
local toks = fluidRecipeTokens(fplan.recipe)
local got = false
local waitN = 0
while true do
if tryAcquireTokens(toks) then got = true; break end
if cancelCrafting then return false, {"Cancelled by user."}, 0 end
sleepCheckCancel(0.2)
waitN = waitN + 1
if waitN > 450 then break end
end
while _fluidStoreBusy do
if cancelCrafting then
if got then releaseTokens(toks) end
return false, {"Cancelled by user."}, 0
end
sleepCheckCancel(0.1)
end
_fluidStoreBusy = true
local okStore, storeErr, nOuts = checkOutputStorage(fplan.recipe)
if okStore then fluidTankClaims = fluidTankClaims + (nOuts or 0) end
_fluidStoreBusy = false
if not okStore then
if got then releaseTokens(toks) end
return false, storeErr, 0
end
local okR, errR, producedR = runFluidCraftInner(fplan)
fluidTankClaims = math.max(0, fluidTankClaims - (nOuts or 0))
if got then releaseTokens(toks) end
return okR, errR, producedR
end
optimizeActive = false
optimizeTimer  = nil
allScanActive  = false
function optimizeStorages()
local tasks = {}
for storageName, isEnabled in pairs(Config.storages) do
if isEnabled and not SYSTEM_SIDES[storageName] then
local sName = storageName
tasks[#tasks + 1] = function()
local storage = peripheral.wrap(sName)
if not (storage and storage.list and storage.pushItems) then return end
local ok, items = pcall(storage.list)
if not (ok and items) then return end
local byName = {}
for slot, item in pairs(items) do
if item then
if not byName[item.name] then byName[item.name] = {} end
byName[item.name][#byName[item.name] + 1] = slot
end
end
for _, slots in pairs(byName) do
if #slots > 1 then
table.sort(slots)
local target = 1
for i = 2, #slots do
local moved = 0
local ok2, n = pcall(storage.pushItems, sName, slots[i], 64, slots[target])
if ok2 and n then moved = n end
if moved == 0 and target < i - 1 then
target = target + 1
pcall(storage.pushItems, sName, slots[i], 64, slots[target])
end
end
end
end
end
end
end
if #tasks > 0 then
parallel.waitForAll(table.unpack(tasks))
end
end
function optimizeFluidTanks()
local excluded = {}
for _, g in ipairs(MgmtGroups) do
if g.output and g.output ~= "" and g.output ~= "STORAGE" then
excluded[g.output] = true
end
end
local byFluid = {}
for tankName, isEnabled in pairs(Config.fluid_tanks or {}) do
if isEnabled and not SYSTEM_SIDES[tankName] and not excluded[tankName] then
local t = peripheral.wrap(tankName)
if t and t.tanks and t.pushFluid then
for fname, amt in pairs(tankContents(tankName)) do
if amt > 0 then
byFluid[fname] = byFluid[fname] or {}
byFluid[fname][#byFluid[fname] + 1] = {periph = tankName, amount = amt}
end
end
end
end
end
for fluidName, tlist in pairs(byFluid) do
if #tlist > 1 then
table.sort(tlist, function(a, b) return a.amount > b.amount end)
local target = 1
for i = 2, #tlist do
local srcName = tlist[i].periph
local srcP = peripheral.wrap(srcName)
if srcP and srcP.pushFluid then
local guard = 0
while target < i and guard < 128 do
guard = guard + 1
local ok, n = pcall(srcP.pushFluid, tlist[target].periph, 1000000000, fluidName)
local moved = (ok and type(n) == "number") and n or 0
local rem = (tankContents(srcName))[fluidName] or 0
if rem <= 0 then break end
if moved <= 0 then target = target + 1 end
end
end
end
end
end
end
pushFromStorage = function(itemName, amountNeeded, targetMachine, targetSlot)
local moved = 0
local group = ITEM_GROUPS[itemName]
local altItems = {}
if group then
for _, altName in ipairs(GROUPS[group]) do
if altName ~= itemName then altItems[altName] = true end
end
end
local hasAlts = next(altItems) ~= nil
local exactSlots = {}
local altSlots   = {}
local scanNames, seenNm = {}, {}
for storageName, isEnabled in pairs(Config.storages) do
if isEnabled and not SYSTEM_SIDES[storageName] and not seenNm[storageName] then
seenNm[storageName] = true
scanNames[#scanNames + 1] = storageName
end
end
for _, pName in ipairs(providerSources()) do
if not seenNm[pName] then seenNm[pName] = true; scanNames[#scanNames + 1] = pName end
end
local scanned = batchPeripheralScan(scanNames, "list")
for _, stoName in ipairs(scanNames) do
local e = scanned[stoName]
if e and e.data then
local storage = peripheral.wrap(stoName)
if storage and storage.pushItems then
for slot, item in pairs(e.data) do
if item then
if item.name == itemName then
table.insert(exactSlots, {storage=storage, stoName=stoName, slot=slot, count=item.count, name=item.name})
elseif hasAlts and altItems[item.name] then
table.insert(altSlots, {storage=storage, stoName=stoName, slot=slot, count=item.count, name=item.name})
end
end
end
end
end
end
local function verifiedPush(entry)
local okD, det = pcall(entry.storage.getItemDetail, entry.slot)
if not (okD and det and det.name == entry.name and (det.count or 0) > 0) then
entry.count = 0
return
end
local toMove = math.min(amountNeeded - moved, det.count)
local ok, mv = pcall(entry.storage.pushItems, targetMachine, entry.slot, toMove, targetSlot)
if ok and mv then moved = moved + mv end
end
for _, entry in ipairs(exactSlots) do
if moved >= amountNeeded then break end
verifiedPush(entry)
end
for _, entry in ipairs(altSlots) do
if moved >= amountNeeded then break end
verifiedPush(entry)
end
if moved < amountNeeded and targetMachine then
local mPeriph = peripheral.wrap(targetMachine)
if mPeriph and mPeriph.pullItems then
local mSize = 9
if mPeriph.size then
local okSz, sz = pcall(mPeriph.size)
if okSz and type(sz) == "number" then mSize = sz end
end
local function pullReverse(entries)
for _, entry in ipairs(entries) do
if moved >= amountNeeded then break end
local okD, det = pcall(entry.storage.getItemDetail, entry.slot)
if not (okD and det and det.name == entry.name and (det.count or 0) > 0) then
entry.count = 0
elseif targetSlot then
local ok3, mv3 = pcall(mPeriph.pullItems, entry.stoName, entry.slot, amountNeeded - moved, targetSlot)
if ok3 and type(mv3) == "number" and mv3 > 0 then moved = moved + mv3 end
else
for mSlot = mSize, 1, -1 do
if moved >= amountNeeded then break end
local ok3, mv3 = pcall(mPeriph.pullItems, entry.stoName, entry.slot, amountNeeded - moved, mSlot)
if ok3 and type(mv3) == "number" and mv3 > 0 then
moved = moved + mv3
break
end
end
end
end
end
pullReverse(exactSlots)
pullReverse(altSlots)
end
end
if moved > 0 then invalidateStockCache() end
return moved
end
local function getAvailableMachines()
local list = {}
local all = peripheral.getNames()
for _, p in ipairs(all) do
if not SYSTEM_SIDES[p] and p ~= MONITOR_SIDE and p ~= Config.train_box
and not (Config.turtles and Config.turtles[p]) and not Config.storages[p]
and not (Config.fluid_tanks and Config.fluid_tanks[p]) then
table.insert(list, p)
end
end
return list
end
local function groupAvailable(itemName, stock)
local total = stock[itemName] or 0
local group = ITEM_GROUPS[itemName]
if group then
for _, altName in ipairs(GROUPS[group]) do
if altName ~= itemName then
total = total + (stock[altName] or 0)
end
end
end
return total
end
function clearLearnTurtle()
if learnedCraftType ~= "turtle" then return end
if not (Config.train_box and Config.train_box ~= "") then return end
local tb = peripheral.wrap(Config.train_box)
if not (tb and tb.pullItems) then return end
for slot = 1, 16 do pcall(function() tb.pullItems(learnedMachineName, slot, 64) end) end
end
local function calculateCraft(itemName, countNeeded, stock, missing, blocked, craftPlan, visited, allowPartial)
calcNodes = calcNodes + 1
if calcBudget > 0 and calcNodes > calcBudget then return end
if calcNodes % 1024 == 0 then sleep(0) end
if countNeeded <= 0 then return end
if visited[itemName] then
missing[itemName] = (missing[itemName] or 0) + countNeeded
return
end
visited[itemName] = true
local group = ITEM_GROUPS[itemName]
local itemsToCheck = { itemName }
if group then
for _, altName in ipairs(GROUPS[group]) do
if altName ~= itemName then table.insert(itemsToCheck, altName) end
end
end
for _, item in ipairs(itemsToCheck) do
local available = stock[item] or 0
if available >= countNeeded then
stock[item] = available - countNeeded
countNeeded = 0
break
elseif available > 0 then
countNeeded = countNeeded - available
stock[item] = 0
end
end
if countNeeded <= 0 then
visited[itemName] = nil
return
end
local directRec = Recipes[itemName]
if directRec and directRec.type == "fluid" then
local frec, fperOp = findFluidItemProducer(itemName)
if frec and fperOp and fperOp > 0 then
local fops = math.ceil(countNeeded / fperOp)
for _, it in ipairs(frec.item_inputs or {}) do
calculateCraft(it.name, it.count * fops, stock, missing, blocked, craftPlan, visited, allowPartial)
end
for _, inp in ipairs(frec.inputs or {}) do
simFluidConsume(inp.name, inp.amount * fops, stock, missing, {}, visited)
end
local surplus = fops * fperOp - countNeeded
if surplus > 0 then stock[itemName] = (stock[itemName] or 0) + surplus end
table.insert(craftPlan, {
item = itemName, count = fops, output_count = fperOp,
fluid_craft = true, fluidRecipe = frec, fluidAmount = fops * fperOp,
})
else
missing[itemName] = (missing[itemName] or 0) + countNeeded
end
visited[itemName] = nil
return
end
local candidates = {}
for _, item in ipairs(itemsToCheck) do
if Recipes[item] then
table.insert(candidates, {recipe = Recipes[item], targetItem = item})
break
end
end
for _, item in ipairs(itemsToCheck) do
if AltRecipes[item] then
for _, altRec in ipairs(AltRecipes[item]) do
table.insert(candidates, {recipe = altRec, targetItem = item})
end
break
end
end
if #candidates == 0 then
local frec, fperOp = findFluidItemProducer(itemName)
if frec and fperOp and fperOp > 0 then
local fops = math.ceil(countNeeded / fperOp)
for _, it in ipairs(frec.item_inputs or {}) do
calculateCraft(it.name, it.count * fops, stock, missing, blocked, craftPlan, visited, allowPartial)
end
for _, inp in ipairs(frec.inputs or {}) do
simFluidConsume(inp.name, inp.amount * fops, stock, missing, {}, visited)
end
local surplus = fops * fperOp - countNeeded
if surplus > 0 then stock[itemName] = (stock[itemName] or 0) + surplus end
table.insert(craftPlan, {
item = itemName, count = fops, output_count = fperOp,
fluid_craft = true, fluidRecipe = frec, fluidAmount = fops * fperOp,
})
visited[itemName] = nil
return
end
missing[itemName] = (missing[itemName] or 0) + countNeeded
visited[itemName] = nil
return
end
local chosen = nil
local chosenMissingTotal = math.huge
local chosenFullyFeasible = false
if #candidates == 1 then
chosen = candidates[1]
chosenFullyFeasible = true
else
local ownBudget = (calcBudget == 0)
if ownBudget then calcNodes = 0; calcBudget = 6000 end
for _, cand in ipairs(candidates) do
local opc = cand.recipe.output_count or 1
local cc  = math.ceil(countNeeded / opc)
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
calculateCraft(ingName, perCraft * cc, testStock, testMissing, testBlocked, testPlan, testVisited, false)
end
local missingTotal = 0
for _, v in pairs(testMissing) do missingTotal = missingTotal + v end
if missingTotal == 0 then
chosen = cand
chosenFullyFeasible = true
break
end
if missingTotal < chosenMissingTotal then
chosen = cand
chosenMissingTotal = missingTotal
end
end
if ownBudget then calcNodes = 0; calcBudget = 0 end
end
if not chosen then chosen = candidates[1] end
local recipe     = chosen.recipe
local targetItem = chosen.targetItem
local outputPerCraft = recipe.output_count or 1
local craftsCount = math.ceil(countNeeded / outputPerCraft)
local toolSet = recipe.tools or {}
local ingCounts = {}
for i = 1, #recipe.ingredients do
local ing = recipe.ingredients[i]
if ing and ing ~= "nil" then
ingCounts[ing] = (ingCounts[ing] or 0) + 1
end
end
if allowPartial and not chosenFullyFeasible then
local maxPossibleCrafts = craftsCount
if recipe.type == "turtle" then
for ingName, ingCountPerCraft in pairs(ingCounts) do
if not toolSet[ingName] then
local ingAvail = groupAvailable(ingName, stock)
local possible = math.floor(ingAvail / ingCountPerCraft)
if possible < maxPossibleCrafts then maxPossibleCrafts = possible end
end
end
else
for ingName in pairs(ingCounts) do
if not toolSet[ingName] then
local ingAvail = groupAvailable(ingName, stock)
if ingAvail < maxPossibleCrafts then maxPossibleCrafts = ingAvail end
end
end
end
if maxPossibleCrafts > 0 then
craftsCount = maxPossibleCrafts
else
missing[itemName] = (missing[itemName] or 0) + countNeeded
visited[itemName] = nil
return
end
end
local totalProduced = craftsCount * outputPerCraft
for ingName, ingCountPerCraft in pairs(ingCounts) do
if toolSet[ingName] then
if groupAvailable(ingName, stock) < 1 then
calculateCraft(ingName, 1, stock, missing, blocked, craftPlan, visited, allowPartial)
end
else
calculateCraft(ingName, ingCountPerCraft * craftsCount, stock, missing, blocked, craftPlan, visited, allowPartial)
end
end
for ingName in pairs(ingCounts) do
if missing[ingName] then
blocked[itemName] = true
break
end
end
local surplus = totalProduced - countNeeded
if surplus > 0 then stock[targetItem] = (stock[targetItem] or 0) + surplus end
table.insert(craftPlan, {
item = targetItem,
count = craftsCount,
type = recipe.type,
machine_name = recipe.machine_name,
ingredients = recipe.ingredients,
output_count = recipe.output_count or 1,
output_device = recipe.output_device,
tools = recipe.tools
})
visited[itemName] = nil
end
local ppYieldCounter = 0
local function planProduction(itemName, amount, allowPartial, stockSnapshot)
ppYieldCounter = ppYieldCounter + 1
if ppYieldCounter >= 150 then ppYieldCounter = 0; sleep(0) end
local currentStock
if stockSnapshot then
currentStock = {}
for k, v in pairs(stockSnapshot) do currentStock[k] = v end
else
currentStock = {}
for k, v in pairs(getStorageInventoryCached()) do currentStock[k] = v end
end
local missingItems = {}
local blockedItems = {}
local executionPlan = {}
calculateCraft(itemName, amount, currentStock, missingItems, blockedItems, executionPlan, {}, false)
local hasMissing = false
for _ in pairs(missingItems) do hasMissing = true break end
if hasMissing then
if allowPartial then
local partialStock
if stockSnapshot then
partialStock = {}
for k, v in pairs(stockSnapshot) do partialStock[k] = v end
else
partialStock = {}
for k, v in pairs(getStorageInventoryCached()) do partialStock[k] = v end
end
local partialPlan = {}
calculateCraft(itemName, amount, partialStock, {}, {}, partialPlan, {}, true)
return partialPlan, missingItems, blockedItems
else
return {}, missingItems, blockedItems
end
end
return executionPlan, {}, {}
end
local function getMachineBaseName(name)
return name:match("^(.-)_%d+$") or name
end
local function getMachineDisplay(name)
local label = MachineLabels[name]
local id = name:match(":(.+)$") or name
if label and label ~= "" then
return id .. "_" .. label
end
return id
end
local function checkMachineAvailable(recipe)
if not recipe then return true, nil end
local mType = recipe.type or ""
local mName = recipe.machine_name or ""
if mType == "turtle" or recipe.method == "turtle" then
for _, enabled in pairs(Config.turtles or {}) do
if enabled then return true, nil end
end
return false, "turtle"
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
local available = getAvailableMachines()
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
if ExcludedMachines[mName] then
for _, m in ipairs(available) do
if m == mName then return true, nil end
end
return false, mName
end
local baseName = getMachineBaseName(mName)
for _, m in ipairs(available) do
if getMachineBaseName(m) == baseName and not ExcludedMachines[m] then
return true, nil
end
end
return false, mName
end
function maxCraftableExact(iName, snapCraft)
local _, quickMiss1 = planProduction(iName, 1, false, snapCraft)
if next(quickMiss1) then return 0 end
local _, quickMiss100 = planProduction(iName, 100, false, snapCraft)
if not next(quickMiss100) then
local _, bigMissing = planProduction(iName, 10000, false, snapCraft)
if not next(bigMissing) then return 10000 end
local lo2, hi2 = 100, 1000
while hi2 < 10000 do
local _, m2 = planProduction(iName, hi2, false, snapCraft)
if next(m2) then break end
lo2 = hi2; hi2 = math.min(hi2 * 4, 10000)
end
while hi2 - lo2 > 1 do
local mid2 = math.floor((lo2 + hi2) / 2)
local _, mm2 = planProduction(iName, mid2, false, snapCraft)
if not next(mm2) then lo2 = mid2 else hi2 = mid2 end
end
return lo2
end
local lo, hi = 1, 99
while hi - lo > 1 do
local mid = math.floor((lo + hi) / 2)
local _, mm = planProduction(iName, mid, false, snapCraft)
if not next(mm) then lo = mid else hi = mid end
end
return lo
end
function scanAllRecipesNow()
recipesScanResults = {}
local snap = getStorageInventory()
local function scanOneRecipe(iName)
local _, missing, blocked = planProduction(iName, 1, false, snap)
local blockedDetails = {}
for bItem in pairs(blocked) do
local _, bMissing, _ = planProduction(bItem, 1, false, snap)
blockedDetails[bItem] = {missing = bMissing}
end
local directAvail  = groupAvailable(iName, snap)
local maxCraftable = 0
local snapCraft = {}
for k, v in pairs(snap) do snapCraft[k] = v end
snapCraft[iName] = 0
if ITEM_GROUPS and ITEM_GROUPS[iName] then
local grp = ITEM_GROUPS[iName]
if GROUPS and GROUPS[grp] then
for _, alt in ipairs(GROUPS[grp]) do snapCraft[alt] = 0 end
end
end
if not next(missing) then
maxCraftable = maxCraftableExact(iName, snapCraft)
end
local hasMach, missMach = checkMachineAvailable(Recipes[iName])
recipesScanResults[iName] = {missing=missing, blocked=blocked, blockedDetails=blockedDetails, maxCraftable=maxCraftable, noMachine=not hasMach, missingMachine=missMach}
end
local scanCounter = 0
for iName in pairs(Recipes) do
scanCounter = scanCounter + 1
if scanCounter % 3 == 0 then sleep(0) end
pcall(scanOneRecipe, iName)
end
end
local function scanKeepItemsNow()
local snap = getStorageInventory()
for itemName in pairs(Autostock) do
if Recipes[itemName] then
local _, missing, blocked = planProduction(itemName, 1, false, snap)
local maxCraftable = 0
local snapCraft = {}
for k, v in pairs(snap) do snapCraft[k] = v end
snapCraft[itemName] = 0
if not next(missing) then
local _, qm1, _ = planProduction(itemName, 1, false, snapCraft)
if not next(qm1) then
local _, qm100, _ = planProduction(itemName, 100, false, snapCraft)
if not next(qm100) then
local _, bigM, _ = planProduction(itemName, 10000, false, snapCraft)
if not next(bigM) then
maxCraftable = 10000
else
local lo2, hi2 = 100, 1000
while hi2 < 10000 do
local _, m2, _ = planProduction(itemName, hi2, false, snapCraft)
if next(m2) then break end
lo2 = hi2; hi2 = math.min(hi2 * 4, 10000)
end
while hi2 - lo2 > 1 do
local mid2 = math.floor((lo2 + hi2) / 2)
local _, mm2, _ = planProduction(itemName, mid2, false, snapCraft)
if not next(mm2) then lo2 = mid2 else hi2 = mid2 end
end
maxCraftable = lo2
end
else
local lo, hi = 1, 99
while hi - lo > 1 do
local mid = math.floor((lo + hi) / 2)
local _, mm, _ = planProduction(itemName, mid, false, snapCraft)
if not next(mm) then lo = mid else hi = mid end
end
maxCraftable = lo
end
end
end
local hasMach, missMach = checkMachineAvailable(Recipes[itemName])
recipesScanResults[itemName] = {missing=missing, blocked=blocked, blockedDetails={}, maxCraftable=maxCraftable, noMachine=not hasMach, missingMachine=missMach}
end
end
end
local _COLOR_BLIT = {
[colors.white]     = "0", [colors.orange]    = "1",
[colors.magenta]   = "2", [colors.lightBlue] = "3",
[colors.yellow]    = "4", [colors.lime]       = "5",
[colors.pink]      = "6", [colors.gray]       = "7",
[colors.lightGray] = "8", [colors.cyan]       = "9",
[colors.purple]    = "a", [colors.blue]       = "b",
[colors.brown]     = "c", [colors.green]      = "d",
[colors.red]       = "e", [colors.black]      = "f",
}
local _fb     = {}
local _fbLast = {}
local _fbW, _fbH = 0, 0
local function _bufInit(w, h)
_fbW, _fbH = w, h
_fb = {}
for y = 1, h do
local t, f, b = {}, {}, {}
for x = 1, w do t[x] = " "; f[x] = "0"; b[x] = "f" end
_fb[y] = {t = t, f = f, b = b}
end
end
local function _bufWrite(x, y, text, fg, bg)
local row = _fb[y]; if not row then return end
local fh = _COLOR_BLIT[fg] or "0"
local bh = _COLOR_BLIT[bg] or "f"
for i = 1, #text do
local col = x + i - 1
if col >= 1 and col <= _fbW then
row.t[col] = text:sub(i, i)
row.f[col] = fh
row.b[col] = bh
end
end
end
local function _bufClearLine(y, bg)
_bufWrite(1, y, string.rep(" ", _fbW), colors.white, bg)
end
local function _bufFillRect(x, y, rw, rh, bg)
local row = string.rep(" ", rw)
for dy = 0, rh - 1 do _bufWrite(x, y + dy, row, colors.white, bg) end
end
local function _bufFlush()
for y = 1, _fbH do
local row = _fb[y]
local ts  = table.concat(row.t)
local fs  = table.concat(row.f)
local bs  = table.concat(row.b)
local prev = _fbLast[y]
if not prev or prev[1] ~= ts or prev[2] ~= fs or prev[3] ~= bs then
monitor.setCursorPos(1, y)
monitor.blit(ts, fs, bs)
_fbLast[y] = {ts, fs, bs}
end
end
end
local function drawText(x, y, text, fg, bg)
_bufWrite(x, y, text, fg or colors.white, bg or colors.black)
end
local function drawProgressBar(x, y, width, current, max, bgColor)
bgColor = bgColor or colors.black
local percent = math.min(1, math.max(0, current / max))
local filledChars = math.floor(percent * (width - 2))
local emptyChars = (width - 2) - filledChars
local barStr = "[" .. string.rep("|", filledChars) .. string.rep(".", emptyChars) .. "]"
drawText(x, y, barStr, colors.lime, bgColor)
drawText(x + width + 1, y, string.format("%d%%", math.floor(percent * 100)), colors.white, bgColor)
end
local function timedRead(timeout, initial)
local buf = initial or ""
if buf ~= "" then term.write(buf) end
local timer = os.startTimer(timeout)
while true do
local ev, a = os.pullEvent()
if ev == "char" then
if timer then os.cancelTimer(timer); timer = nil end
buf = buf .. a
term.write(a)
elseif ev == "key" then
if a == keys.enter or a == keys.numPadEnter then
if timer then os.cancelTimer(timer) end
return buf
elseif a == keys.backspace and #buf > 0 then
buf = buf:sub(1, -2)
local cx, cy = term.getCursorPos()
term.setCursorPos(cx - 1, cy)
term.write(" ")
term.setCursorPos(cx - 1, cy)
end
elseif ev == "timer" and a == timer then
return nil
end
end
end
getMachinePool = function(machineName)
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
if ExcludedMachines[machineName] then
return { machineName }
end
local inCustom = {}
for _, cg in ipairs(CustomMachineGroups) do
for _, cm in ipairs(cg.machines) do inCustom[cm] = true end
end
local baseName = getMachineBaseName(machineName)
local all = getAvailableMachines()
local pool = {}
for _, m in ipairs(all) do
if getMachineBaseName(m) == baseName and not ExcludedMachines[m] and not inCustom[m] then
table.insert(pool, m)
end
end
if #pool == 0 then return { machineName } end
table.sort(pool)
return pool
end
sleepCheckCancel = function(t)
local timer = os.startTimer(t)
local deadline = os.clock() + t + 0.1
while true do
local ev, a, b, c = os.pullEvent()
if ev == "timer" and a == timer then return end
if ev == "monitor_touch" and craftCancelY and c == craftCancelY and b >= craftCancelX1 and b <= craftCancelX2 then
cancelCrafting = true
os.cancelTimer(timer)
return
end
if os.clock() >= deadline then os.cancelTimer(timer); return end
end
end
function findFreeSpaceStorage(names)
for _, stoName in ipairs(names) do
local sto = peripheral.wrap(stoName)
if sto and sto.pullItems and sto.list and sto.size then
local okS, sz = pcall(sto.size)
local okL, lst = pcall(sto.list)
if okS and okL and sz and lst then
local used = 0
for _ in pairs(lst) do used = used + 1 end
if sz - used >= 16 then return sto end
end
end
end
return nil
end
function blindUnloadTurtle(tName, names)
local sto = findFreeSpaceStorage(names)
if not sto then return false end
for slot = 1, 16 do pcall(sto.pullItems, tName, slot, 64) end
return true
end
local function cleanupCraftMachines(activeStorages, list)
local cleanList = list or craftCleanupMachines
local stuckMachines = {}
local stuckSeen     = {}
for _, entry in ipairs(cleanList) do
if entry and entry.name then
local p = peripheral.wrap(entry.name)
local anyStuck = false
if p and p.list then
local s, items = pcall(p.list)
if s and items then
for slot, item in pairs(items) do
if item then
if entry.pullNames == nil or entry.pullNames[item.name] then
local remaining = item.count
if p.pushItems then
for _, stoName in ipairs(activeStorages) do
if remaining <= 0 then break end
local ok, mv = pcall(p.pushItems, stoName, slot, remaining)
if ok and mv and mv > 0 then remaining = remaining - mv end
end
end
if remaining > 0 then
for _, stoName in ipairs(activeStorages) do
if remaining <= 0 then break end
local sto = peripheral.wrap(stoName)
if sto and sto.pullItems then
local ok2, mv2 = pcall(sto.pullItems, entry.name, slot, remaining)
if ok2 and mv2 and mv2 > 0 then remaining = remaining - mv2 end
end
end
end
if remaining > 0 then anyStuck = true end
end
end
end
end
else
if not blindUnloadTurtle(entry.name, activeStorages) then
anyStuck = true
end
end
if anyStuck and not stuckSeen[entry.name] then
stuckSeen[entry.name] = true
table.insert(stuckMachines, entry.name)
end
end
end
if not list then craftCleanupMachines = {} end
if #stuckMachines > 0 then
local shortNames = {}
for _, n in ipairs(stuckMachines) do
local disp = n
if getMachineDisplay then disp = getMachineDisplay(n) end
table.insert(shortNames, disp)
end
uiMessage = "CANCEL: stuck in " .. table.concat(shortNames, ", ")
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(4)
end
end
local drawInterface
drawFluidProgress = function(subLabel, current, total, workers)
local co = lockOwnerId()
local ent = fluidInlineByCo[co]
if ent then
local short = tostring(subLabel):match(":(.+)$") or tostring(subLabel)
local line = {
desc = short .. " (fluid)", done = current or 0, total = total or 0,
machines = workers or 0, topup = false,
}
ent.ctx.active[ent.node] = line
if displayCtx and displayCtx ~= ent.ctx then
displayCtx.active["FLUIDNEST:" .. tostring(co)] = line
end
return
end
if drawInterface then drawInterface() end
local w, h = monitor.getSize()
local pW = 46
local pH = 10
local pX = math.max(1, math.floor((w - pW) / 2) + 1)
local pY = math.max(1, math.floor((h - pH) / 2) + 1)
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdr = " MANUFACTURING ACTIVE "
drawText(pX + math.floor((pW - #hdr) / 2), pY, hdr, colors.black, colors.orange)
local stepStr = string.format("Step %d/%d", fluidStepNum, math.max(fluidStepNum, fluidStepTotal))
drawText(pX + 2, pY + 2, stepStr, colors.white, colors.gray)
local fStr = "[FLUID]"
drawText(pX + pW - #fStr - 2, pY + 2, fStr, colors.cyan, colors.gray)
if workers and workers > 1 then
local wStr = "[" .. workers .. "x parallel] "
drawText(pX + pW - #fStr - 2 - #wStr, pY + 2, wStr, colors.cyan, colors.gray)
end
local subShort = (tostring(subLabel):match(":(.+)$") or tostring(subLabel))
local subStr = ("Sub-task: " .. total .. " ops " .. subShort):sub(1, pW - 4)
drawText(pX + 2, pY + 3, subStr, colors.lightGray, colors.gray)
local goal = fluidGoalLabel ~= "" and fluidGoalLabel or subLabel
local cleanGoal = (tostring(goal):match(":(.+)$") or tostring(goal)):upper()
local itemStr = (">> " .. cleanGoal .. " <<"):sub(1, pW - 4)
drawText(pX + math.floor((pW - #itemStr) / 2), pY + 5, itemStr, colors.yellow, colors.gray)
local progStr = string.format("Progress: %d / %d", current, total)
drawText(pX + math.floor((pW - #progStr) / 2), pY + 7, progStr, colors.lime, colors.gray)
local barWidth = math.min(28, pW - 14)
local barX = pX + math.floor((pW - barWidth) / 2)
drawProgressBar(barX, pY + 8, barWidth, current, total, colors.gray)
local cancelStr = " [ CANCEL ] "
local cancelBtnX = pX + math.floor((pW - #cancelStr) / 2)
local cancelBtnY = pY + pH - 1
drawText(cancelBtnX, cancelBtnY, cancelStr, colors.white, colors.red)
craftCancelY  = cancelBtnY
craftCancelX1 = cancelBtnX
craftCancelX2 = cancelBtnX + #cancelStr - 1
_bufFlush()
end
drawFluidScanCancel = function()
local sw, sh = monitor.getSize()
local cancStr = " [ CANCEL SCAN ] "
local cancX = math.floor((sw - #cancStr) / 2) + 1
drawText(2, sh - 3, fluidScanStatus, colors.yellow, colors.black)
drawText(cancX, sh - 1, cancStr, colors.white, colors.red)
craftCancelY  = sh - 1
craftCancelX1 = cancX
craftCancelX2 = cancX + #cancStr - 1
_bufFlush()
end
local ensureFluidAvailable
local fluidProducers
local function findFluidProducer(fluidName)
local p = fluidProducers(fluidName)[1]
if p then return p.recipe, p.perOp end
return nil
end
local function countFluidSteps(fluidName, amount, simStock, visited)
local have = simStock[fluidName] or 0
if have >= amount then simStock[fluidName] = have - amount; return 0 end
local shortfall = amount - have
simStock[fluidName] = 0
if visited[fluidName] then return 0 end
local recipe, perOp = findFluidProducer(fluidName)
if not recipe or not perOp or perOp <= 0 then return 0 end
local ops = math.ceil(shortfall / perOp)
visited[fluidName] = true
local cnt = 0
for _, inp in ipairs(recipe.inputs or {}) do
cnt = cnt + countFluidSteps(inp.name, ops * inp.amount, simStock, visited)
end
visited[fluidName] = nil
simStock[fluidName] = (simStock[fluidName] or 0) + (ops * perOp - shortfall)
return cnt + 1
end
local function countTopFluidSteps(recipe, targetName, amount)
local perOp = nil
for _, o in ipairs(recipe.outputs or {}) do if o.name == targetName then perOp = o.amount; break end end
if not perOp then for _, o in ipairs(recipe.item_outputs or {}) do if o.name == targetName then perOp = o.count; break end end end
if not perOp or perOp <= 0 then return 1 end
local ops = math.ceil(amount / perOp)
local simStock = {}
for k, v in pairs(getFluidInventory()) do simStock[fluidNameFromKey(k)] = v end
local cnt = 0
local visited = {}
for _, inp in ipairs(recipe.inputs or {}) do
cnt = cnt + countFluidSteps(inp.name, ops * inp.amount, simStock, visited)
end
return cnt + 1
end
function estimatePlanStages(plan)
local n = 0
for _, step in ipairs(plan) do
if step.count and step.count > 0 then
if step.fluid_craft then
local c = 1
local okC, r = pcall(countTopFluidSteps, step.fluidRecipe, step.item, step.fluidAmount)
if okC and type(r) == "number" and r > 0 then c = r end
n = n + c
else
n = n + 1
end
end
end
return n
end
local FLUID_MAX_CAP = 100000
fluidProducers = function(fluidName)
local cached = _fpCache[fluidName]
if cached then return cached end
local out = {}
local fk = fluidKey(fluidName)
local function tryAdd(rec, key, own, isPrimary, altIdx)
if type(rec) ~= "table" then return end
for _, o in ipairs(rec.outputs or {}) do
if o.name == fluidName and o.amount and o.amount > 0 then
out[#out + 1] = {recipe = rec, perOp = o.amount, key = key,
own = own, isPrimary = isPrimary, altIdx = altIdx}
return
end
end
end
tryAdd(FluidRecipes[fk], fk, true, true, nil)
for i, alt in ipairs(FluidAltRecipes[fk] or {}) do tryAdd(alt, fk, true, false, i) end
for key, rec in pairs(FluidRecipes) do
if key ~= fk then tryAdd(rec, key, false, false, nil) end
end
for key, alts in pairs(FluidAltRecipes) do
if key ~= fk then
for _, alt in ipairs(alts) do tryAdd(alt, key, false, false, nil) end
end
end
_fpCache[fluidName] = out
return out
end
local function removeFluidRecipeRef(rec)
for key, r in pairs(FluidRecipes) do
if r == rec then
local alts = FluidAltRecipes[key]
if alts and alts[1] then
FluidRecipes[key] = table.remove(alts, 1)
if #alts == 0 then FluidAltRecipes[key] = nil end
else
FluidRecipes[key] = nil
end
return
end
end
for key, alts in pairs(FluidAltRecipes) do
for i, r in ipairs(alts) do
if r == rec then
table.remove(alts, i)
if #alts == 0 then FluidAltRecipes[key] = nil end
return
end
end
end
end
local maxFluidCraftable
local _mfcMemo, _mfcStock, _mfcIStock = {}, nil, nil
local function fluidRecipeMaxOps(recipe, fstock, istock, visited)
local maxOps = math.huge
local tainted = false
for _, inp in ipairs(recipe.inputs or {}) do
local avail, t = maxFluidCraftable(inp.name, fstock, istock, visited)
if t then tainted = true end
local possible = (inp.amount and inp.amount > 0) and math.floor(avail / inp.amount) or 0
if possible < maxOps then maxOps = possible end
end
for _, it in ipairs(recipe.item_inputs or {}) do
local possible = (it.count and it.count > 0) and math.floor((istock[it.name] or 0) / it.count) or 0
if possible < maxOps then maxOps = possible end
end
if maxOps == math.huge then maxOps = FLUID_MAX_CAP end
return maxOps, tainted
end
maxFluidCraftable = function(fluidName, fstock, istock, visited)
if _mfcStock ~= fstock or _mfcIStock ~= istock then
_mfcMemo = {}; _mfcStock = fstock; _mfcIStock = istock
end
local have = fstock[fluidName] or 0
calcNodes = calcNodes + 1
if calcBudget > 0 and calcNodes > calcBudget then return have, true end
if calcNodes % 1024 == 0 then sleep(0) end
if visited[fluidName] then return have, true end
local cached = _mfcMemo[fluidName]
if cached ~= nil then return cached, false end
local prods = fluidProducers(fluidName)
if #prods == 0 then _mfcMemo[fluidName] = have; return have, false end
visited[fluidName] = true
local best = 0
local tainted = false
for _, pr in ipairs(prods) do
local ops, t = fluidRecipeMaxOps(pr.recipe, fstock, istock, visited)
if t then tainted = true end
local produced = ops * pr.perOp
if produced > best then best = produced end
end
visited[fluidName] = nil
local result = math.min(have + best, have + FLUID_MAX_CAP)
if not tainted then _mfcMemo[fluidName] = result end
return result, tainted
end
simFluidConsume = function(fluidName, amountMb, stock, missing, fvisited, itemVisited)
calcNodes = calcNodes + 1
if calcBudget > 0 and calcNodes > calcBudget then return end
if calcNodes % 1024 == 0 then sleep(0) end
if not amountMb or amountMb <= 0 then return end
if not stock.__fl then
stock.__fl = true
for k, v in pairs(getFluidInventoryCached()) do
if stock[k] == nil then stock[k] = v end
end
end
local key = fluidKey(fluidName)
local have = stock[key] or 0
if have >= amountMb then stock[key] = have - amountMb; return end
local shortfall = amountMb - have
stock[key] = 0
if fvisited[fluidName] then
missing[key] = (missing[key] or 0) + shortfall
return
end
local prods = fluidProducers(fluidName)
if #prods == 0 then
missing[key] = (missing[key] or 0) + shortfall
return
end
fvisited[fluidName] = true
local function consumeVia(p, st, miss)
local fops = math.ceil(shortfall / p.perOp)
for _, inp in ipairs(p.recipe.inputs or {}) do
simFluidConsume(inp.name, inp.amount * fops, st, miss, fvisited, itemVisited)
end
for _, it in ipairs(p.recipe.item_inputs or {}) do
calculateCraft(it.name, it.count * fops, st, miss, {}, {}, itemVisited or {}, false)
end
end
local usedP
if #prods == 1 then
consumeVia(prods[1], stock, missing)
usedP = prods[1]
else
for _, p in ipairs(prods) do
local stCopy = {}
for k, v in pairs(stock) do stCopy[k] = v end
local missCopy = {}
consumeVia(p, stCopy, missCopy)
if next(missCopy) == nil then
for k, v in pairs(stCopy) do stock[k] = v end
usedP = p
break
end
end
if not usedP then
consumeVia(prods[1], stock, missing)
usedP = prods[1]
end
end
fvisited[fluidName] = nil
local fops = math.ceil(shortfall / usedP.perOp)
local surplus = fops * usedP.perOp - shortfall
if surplus > 0 then stock[key] = (stock[key] or 0) + surplus end
end
ITEM_MAX_CAP = 999
local _micMemo, _micStock = {}, nil
local function maxItemCraftable(itemName, istock, fstock, visited)
if _micStock ~= istock then _micMemo = {}; _micStock = istock end
visited = visited or {}
local have = groupAvailable(itemName, istock)
calcNodes = calcNodes + 1
if calcBudget > 0 and calcNodes > calcBudget then return have, true end
if visited[itemName] then return have, true end
local cached = _micMemo[itemName]
if cached ~= nil then return cached, false end
local recs = {}
if Recipes[itemName] then recs[#recs + 1] = Recipes[itemName] end
for _, a in ipairs(AltRecipes[itemName] or {}) do recs[#recs + 1] = a end
if #recs == 0 then _micMemo[itemName] = have; return have, false end
visited[itemName] = true
local best, tainted = 0, false
for _, rec in ipairs(recs) do
local produced = 0
if rec.type == "fluid" then
local frec, fperOp = findFluidItemProducer(itemName)
if frec and fperOp and fperOp > 0 then
local ops, t = fluidRecipeMaxOps(frec, fstock or {}, istock, {})
if t then tainted = true end
produced = (ops or 0) * fperOp
end
else
local ings = {}
for i = 1, #(rec.ingredients or {}) do
local ing = rec.ingredients[i]
if ing and ing ~= "nil" then ings[ing] = (ings[ing] or 0) + 1 end
end
local opc = rec.output_count or 1
local maxOps = math.huge
for ing, per in pairs(ings) do
local av, t = maxItemCraftable(ing, istock, fstock, visited)
if t then tainted = true end
local p = math.floor(av / per)
if p < maxOps then maxOps = p end
end
if maxOps == math.huge then maxOps = 0 end
produced = maxOps * opc
end
if produced > best then best = produced end
end
visited[itemName] = nil
local result = math.min(have + best, have + ITEM_MAX_CAP)
if not tainted then _micMemo[itemName] = result end
return result, tainted
end
local function scanAllFluidsNow()
fluidScanResults = {}
local fstock = {}
for k, v in pairs(getFluidInventory()) do fstock[fluidNameFromKey(k)] = v end
local istock = getStorageInventory()
local seen = {}
local function scanRec(rec)
for _, o in ipairs(rec.outputs or {}) do
if not seen[o.name] then
seen[o.name] = true
local ok, total = pcall(maxFluidCraftable, o.name, fstock, istock, {})
if ok and type(total) == "number" then
fluidScanResults[o.name] = math.min(9999, math.max(0, total - (fstock[o.name] or 0)))
else
fluidScanResults[o.name] = 0
end
sleep(0)
end
end
end
for _, rec in pairs(FluidRecipes) do scanRec(rec) end
for _, alts in pairs(FluidAltRecipes) do
for _, rec in ipairs(alts) do scanRec(rec) end
end
end
ensureItemAvailable = function(itemName, count)
if cancelCrafting then return false, {"Cancelled by user."} end
local function curHave()
local stk = getStorageInventoryCached()
local h = stk[itemName] or 0
local grp = ITEM_GROUPS[itemName]
if grp then
for _, alt in ipairs(GROUPS[grp]) do h = h + (stk[alt] or 0) end
end
return h
end
local have = curHave()
if have >= count then return true, nil end
invalidateStockCache()
have = curHave()
if have >= count then return true, nil end
if crossCraftDepth >= 6 then
return false, {"Recursion too deep: " .. (itemName:match(":(.+)$") or itemName)}
end
crossCraftDepth = crossCraftDepth + 1
local attempts = 0
local lastMissing = nil
while have < count and not cancelCrafting do
attempts = attempts + 1
if attempts > 12 then break end
local plan, miss = planProduction(itemName, count, true)
lastMissing = miss
if not (plan and #plan > 0) then break end
local before = have
runCraftingProcess(plan)
have = curHave()
if have <= before then break end
end
crossCraftDepth = crossCraftDepth - 1
if have < count then
local sn = itemName:match(":(.+)$") or itemName
local lines = {string.format("Need %dx %s (have %d)", count, sn, have)}
if lastMissing and next(lastMissing) then
local parts = {}
for mName, mCnt in pairs(lastMissing) do
if not (mName == itemName) then
parts[#parts + 1] = string.format("%dx %s", mCnt, mName:match(":(.+)$") or mName)
end
end
table.sort(parts)
if #parts > 0 then
local shown = {}
for i = 1, math.min(3, #parts) do shown[i] = parts[i] end
local msg = "Need: " .. table.concat(shown, ", ")
if #parts > 3 then msg = msg .. " +" .. (#parts - 3) end
table.insert(lines, msg)
end
end
return false, lines
end
return true, nil
end
local function ensureItemInputs(recipe, ops)
for _, it in ipairs(recipe.item_inputs or {}) do
local ok, err = ensureItemAvailable(it.name, ops * it.count)
if not ok then return false, err end
end
return true, nil
end
function fluidRecipeShortInputs(recipe, ops)
local parts = {}
local fInv = getFluidInventory()
for _, inp in ipairs(recipe.inputs or {}) do
local need = ops * inp.amount
local have = fInv[fluidKey(inp.name)] or 0
if have < need then parts[#parts + 1] = string.format("%d mB %s", need - have, inp.name:match(":(.+)$") or inp.name) end
end
local iInv = getStorageInventory()
for _, it in ipairs(recipe.item_inputs or {}) do
local need = ops * it.count
local have = iInv[it.name] or 0
local grp = ITEM_GROUPS[it.name]
if grp then for _, alt in ipairs(GROUPS[grp]) do have = have + (iInv[alt] or 0) end end
if have < need then parts[#parts + 1] = string.format("%dx %s", need - have, it.name:match(":(.+)$") or it.name) end
end
return parts
end
function appendMissingLine(lines, parts)
if parts and #parts > 0 then
table.sort(parts)
local shown = {}
for i = 1, math.min(3, #parts) do shown[i] = parts[i] end
local msg = "Need: " .. table.concat(shown, ", ")
if #parts > 3 then msg = msg .. " +" .. (#parts - 3) end
table.insert(lines, msg)
end
return lines
end
ensureFluidAvailable = function(fluidName, amount, visited)
if cancelCrafting then return false, {"Cancelled by user."} end
local have = (getFluidInventoryCached())[fluidKey(fluidName)] or 0
if have >= amount then return true, nil end
invalidateStockCache()
have = (getFluidInventoryCached())[fluidKey(fluidName)] or 0
if have >= amount then return true, nil end
if visited[fluidName] then
local sn = fluidName:match(":(.+)$") or fluidName
return false, {"Recursion cycle on " .. sn}
end
local prods = fluidProducers(fluidName)
if #prods == 0 then
local sn = fluidName:match(":(.+)$") or fluidName
return false, {string.format("Need %d mB %s, have %d (no recipe)", amount, sn, have)}
end
visited[fluidName] = true
local attempts = 0
while have < amount do
if cancelCrafting then visited[fluidName] = nil; return false, {"Cancelled by user."} end
attempts = attempts + 1
if attempts > 8 then
visited[fluidName] = nil
local sn = fluidName:match(":(.+)$") or fluidName
local lines = {string.format("Need %d mB %s, made only %d", amount, sn, have)}
local p0 = prods[1]
if p0 then appendMissingLine(lines, fluidRecipeShortInputs(p0.recipe, math.ceil((amount - have) / p0.perOp))) end
return false, lines
end
local shortfall = amount - have
local fstock = {}
for k, v in pairs(getFluidInventoryCached()) do fstock[fluidNameFromKey(k)] = v end
local istock = getStorageInventoryCached()
local chosen, chosenOps
for _, p in ipairs(prods) do
local ops = math.ceil(shortfall / p.perOp)
local okM, maxOps = pcall(fluidRecipeMaxOps, p.recipe, fstock, istock, {})
if okM and type(maxOps) == "number" and maxOps >= ops then
chosen = p; chosenOps = ops; break
end
end
if not chosen then chosen = prods[1]; chosenOps = math.ceil(shortfall / prods[1].perOp) end
local recipe, ops = chosen.recipe, chosenOps
for _, inp in ipairs(recipe.inputs or {}) do
local ok, err = ensureFluidAvailable(inp.name, ops * inp.amount, visited)
if not ok then visited[fluidName] = nil; return false, err end
end
local okItems, itemErr = ensureItemInputs(recipe, ops)
if not okItems then visited[fluidName] = nil; return false, itemErr end
local okRun, errRun = runFluidCraft({recipe = recipe, ops = ops, perOp = chosen.perOp, label = fluidName})
if not okRun then visited[fluidName] = nil; return false, errRun end
invalidateStockCache()
local newHave = (getFluidInventory())[fluidKey(fluidName)] or 0
if newHave <= have then
visited[fluidName] = nil
local sn = fluidName:match(":(.+)$") or fluidName
local lines = {string.format("Need %d mB %s, stuck at %d", amount, sn, newHave)}
appendMissingLine(lines, fluidRecipeShortInputs(recipe, ops))
return false, lines
end
have = newHave
end
visited[fluidName] = nil
return true, nil
end
local function produceFluid(recipe, targetName, amount)
if cancelCrafting then return false, {"Cancelled by user."}, 0 end
local prods = fluidProducers(targetName)
if #prods > 1 then
local fstock = {}
for k, v in pairs(getFluidInventoryCached()) do fstock[fluidNameFromKey(k)] = v end
local istock = getStorageInventoryCached()
for _, p in ipairs(prods) do
local ops = math.ceil(amount / p.perOp)
local okM, maxOps = pcall(fluidRecipeMaxOps, p.recipe, fstock, istock, {})
if okM and type(maxOps) == "number" and maxOps >= ops then
recipe = p.recipe; break
end
end
end
local perOp = nil
for _, o in ipairs(recipe.outputs or {}) do
if o.name == targetName then perOp = o.amount; break end
end
if not perOp then
for _, o in ipairs(recipe.item_outputs or {}) do
if o.name == targetName then perOp = o.count; break end
end
end
if not perOp or perOp <= 0 then return false, {"Bad recipe output amount"}, 0 end
local ops = math.ceil(amount / perOp)
local visited = {}
for _, inp in ipairs(recipe.inputs or {}) do
local ok, err = ensureFluidAvailable(inp.name, ops * inp.amount, visited)
if not ok then return false, err, 0 end
end
local okItems, itemErr = ensureItemInputs(recipe, ops)
if not okItems then return false, itemErr, 0 end
return runFluidCraft({recipe = recipe, ops = ops, perOp = perOp, label = targetName})
end
local function runFluidCraftAmount(recipe, targetName, amount)
local isItem = false
for _, o in ipairs(recipe.item_outputs or {}) do
if o.name == targetName then isItem = true; break end
end
fluidGoalLabel = targetName
fluidStepNum = 0
fluidStepTotal = countTopFluidSteps(recipe, targetName, amount)
systemStatus = "AUTO_CRAFT"
fluidCraftMsg = "Crafting..."
cancelCrafting = false
craftLocks = {}; fluidTankClaims = 0; _fluidStoreBusy = false; fluidInlineByCo = {}
drawInterface()
local okRun, runErr, produced = produceFluid(recipe, targetName, amount)
systemStatus = "IDLE"
fluidCraftMsg = ""
cancelCrafting = false
if okRun then
local prod = {{name = targetName, amount = produced, unit = isItem and "x" or "mB"}}
craftCompletePopup = {outputs = prod, timer = os.startTimer(10)}
else
craftErrorTitle = "! CANNOT CRAFT"
craftErrorLines = runErr or {"Unknown error"}
end
return okRun, produced, isItem
end
local function doFluidCraftFlow(recipe, targetName)
local isItemTarget = false
for _, o in ipairs(recipe.item_outputs or {}) do
if o.name == targetName then isItemTarget = true; break end
end
fluidRecipePicker = nil
fluidKeepName = nil
fluidCraftMode = {recipe = recipe, target = targetName, isItem = isItemTarget}
itemToCraft = targetName
craftQuantity = isItemTarget and 1 or 1000
isRequestMode = false
isSettingKeepLimit = false
qtyOriginTab = "RECIPES"
pickerMaxCapped = false
pickerMaxCraftable = 0
pickerMaxComputed = false
if Config.autoMaxCalc ~= false then pickerComputeMax() end
currentTab = "QUANTITY_PICKER"
end
function pickerComputeMax()
pickerMaxCraftable = 0
pickerMaxCapped = false
if fluidCraftMode and fluidCraftMode.recipe then
local recipe       = fluidCraftMode.recipe
local targetName   = fluidCraftMode.target
local isItemTarget = fluidCraftMode.isItem
local fstock = {}
for k, v in pairs(getFluidInventory()) do fstock[fluidNameFromKey(k)] = v end
local istock = getStorageInventory()
local perOp = 1
if isItemTarget then
for _, o in ipairs(recipe.item_outputs or {}) do if o.name == targetName then perOp = o.count; break end end
else
for _, o in ipairs(recipe.outputs or {}) do if o.name == targetName then perOp = o.amount; break end end
end
local okM, ops = pcall(fluidRecipeMaxOps, recipe, fstock, istock, {})
if not okM or type(ops) ~= "number" then ops = 0 end
pickerMaxCraftable = math.min(FLUID_MAX_CAP, ops * (perOp > 0 and perOp or 1))
else
local target = itemToCraft
local snap = getStorageInventory()
local snapCraft = {}
for k, v in pairs(snap) do snapCraft[k] = v end
snapCraft[target] = 0
if ITEM_GROUPS[target] and GROUPS[ITEM_GROUPS[target]] then
for _, alt in ipairs(GROUPS[ITEM_GROUPS[target]]) do snapCraft[alt] = 0 end
end
local cs = recipesScanResults[target]
if cs and type(cs.maxCraftable) == "number" and not next(cs.missing or {}) then
pickerMaxCraftable = cs.maxCraftable
else
local okMx, mx = pcall(maxCraftableExact, target, snapCraft)
pickerMaxCraftable = (okMx and type(mx) == "number") and mx or 0
end
end
pickerMaxComputed = true
end
function clearFluidLearnDevices()
fluidLearnOutput = nil; fluidOutputPick = false
fluidLearnItemIn = nil; fluidItemInPick = false
fluidLearnFluidIn = nil; fluidFluidInPick = false
fluidLearnItemOut = nil; fluidItemOutPick = false
end
local function drawFluidLearnUI(w, h, touchZones)
local sumY = 12
if #fluidLearnInputs > 0 then
local parts = {}
for _, inp in ipairs(fluidLearnInputs) do
local sn = inp.name:match(":(.+)$") or inp.name
parts[#parts + 1] = string.format("%s:%dmB", sn, inp.amount)
end
drawText(2, sumY, "Inputs: " .. table.concat(parts, "  "), colors.lime, colors.black)
else
drawText(2, sumY, "Inputs: (none yet)", colors.gray, colors.black)
end
if fluidLearnStage == "PICK_INPUT" then
local hdr = "SELECT INPUT FLUIDS (optional - items read from barrel)"
drawText(2, 13, hdr, colors.gray, colors.black)
local selAmt = {}
for _, inp in ipairs(fluidLearnInputs) do selAmt[inp.name] = inp.amount end
local inv = getFluidInventory()
local avail = {}
for fk, amt in pairs(inv) do
avail[#avail + 1] = {name = fluidNameFromKey(fk), mb = amt}
end
table.sort(avail, function(a, b) return a.name < b.name end)
if #avail == 0 then
local noF = "No fluids in [TNK] tanks."
drawText(math.floor((w - #noF) / 2) + 1, 16, noF, colors.gray)
else
local listY = 15
local cols = 3
local maxRows = h - listY - 4
if maxRows < 1 then maxRows = 1 end
local perPage = cols * maxRows
local totalP = math.max(1, math.ceil(#avail / perPage))
if fluidLearnPage > totalP then fluidLearnPage = totalP end
if fluidLearnPage < 1 then fluidLearnPage = 1 end
local sIdx = (fluidLearnPage - 1) * perPage + 1
local eIdx = math.min(sIdx + perPage - 1, #avail)
local colW = math.floor(w / cols)
for ci = 1, cols - 1 do
for ry = 0, maxRows - 1 do
drawText(ci * colW, listY + ry, "|", colors.gray, colors.black)
end
end
for fi = sIdx, eIdx do
local li = fi - sIdx
local col = math.floor(li / maxRows)
local row = li % maxRows
local rowY = listY + row
local colX = col * colW + 1
local f = avail[fi]
local short = f.name:match(":(.+)$") or f.name
if fluidInputWaitName == f.name then
local lbl = short
local maxName = colW - 5
if #lbl > maxName then lbl = lbl:sub(1, maxName) end
drawText(colX, rowY, "--", colors.yellow, colors.black)
drawText(colX + 2, rowY, lbl, colors.yellow, colors.black)
drawText(colX + 2 + #lbl, rowY, "--", colors.yellow, colors.black)
elseif selAmt[f.name] then
local lbl = short .. " " .. selAmt[f.name]
local maxName = colW - 5
if #lbl > maxName then lbl = lbl:sub(1, maxName) end
drawText(colX, rowY, "--", colors.lime, colors.gray)
drawText(colX + 2, rowY, lbl, colors.white, colors.gray)
drawText(colX + 2 + #lbl, rowY, "--", colors.lime, colors.gray)
else
local lbl = short
if #lbl > colW - 2 then lbl = lbl:sub(1, colW - 2) end
drawText(colX, rowY, lbl, colors.lightGray, colors.black)
end
table.insert(touchZones, {id="fluid_pick_input", arg=f.name, x1=colX, x2=colX+colW-2, y=rowY})
end
if totalP > 1 then
local navY = h - 3
local pS = string.format("[PREV] %d/%d [NEXT]", fluidLearnPage, totalP)
local navX = math.floor((w - #pS) / 2) + 1
drawText(navX, navY, pS, colors.white, colors.black)
table.insert(touchZones, {id="fluid_learn_prev", x1=navX, x2=navX+5, y=navY})
table.insert(touchZones, {id="fluid_learn_next", x1=navX+#pS-6, x2=navX+#pS-1, y=navY})
end
end
do
local doneStr = " [ DONE ] "
local doneX = math.floor((w - #doneStr) / 2) + 1
drawText(doneX, h - 1, doneStr, colors.black, colors.lime)
table.insert(touchZones, {id="fluid_learn_done_inputs", x1=doneX, x2=doneX+#doneStr-1, y=h-1})
end
elseif fluidLearnStage == "PICK_MACHINE" then
local hdr = "SELECT MACHINE"
drawText(2, 13, hdr, colors.gray, colors.black)
local machines = getAvailableMachines()
table.sort(machines, function(a, b)
return (getMachineDisplay(a) or a):lower() < (getMachineDisplay(b) or b):lower()
end)
local listY = 15
local cols = 3
local maxRows = h - listY - 4
if maxRows < 1 then maxRows = 1 end
local perPage = cols * maxRows
local totalP = math.max(1, math.ceil(#machines / perPage))
if fluidLearnPage > totalP then fluidLearnPage = totalP end
if fluidLearnPage < 1 then fluidLearnPage = 1 end
local sIdx = (fluidLearnPage - 1) * perPage + 1
local eIdx = math.min(sIdx + perPage - 1, #machines)
local colW = math.floor(w / cols)
for ci = 1, cols - 1 do
for ry = 0, maxRows - 1 do
drawText(ci * colW, listY + ry, "|", colors.gray, colors.black)
end
end
for mi = sIdx, eIdx do
local li = mi - sIdx
local col = math.floor(li / maxRows)
local row = li % maxRows
local rowY = listY + row
local colX = col * colW + 1
local m = machines[mi]
local isSel = (fluidLearnMachine == m)
local rtag, rcol
if     fluidLearnOutput  == m then rtag, rcol = "FO:", colors.lime
elseif fluidLearnItemIn  == m then rtag, rcol = "II:", colors.cyan
elseif fluidLearnFluidIn == m then rtag, rcol = "FI:", colors.lightBlue
elseif fluidLearnItemOut == m then rtag, rcol = "IO:", colors.orange
end
if rtag then
local nm = (isSel and ">" or "") .. (getMachineDisplay(m) or m)
local maxName = colW - #rtag - 1
if #nm > maxName then nm = nm:sub(1, maxName) end
drawText(colX, rowY, rtag, colors.black, rcol)
drawText(colX + #rtag, rowY, nm, colors.white, colors.gray)
else
local label = (isSel and "> " or "") .. (getMachineDisplay(m) or m)
if #label > colW - 1 then label = label:sub(1, colW - 1) end
drawText(colX, rowY, label, isSel and colors.white or colors.lightGray, isSel and colors.gray or colors.black)
end
table.insert(touchZones, {id="fluid_pick_machine", arg=m, x1=colX, x2=colX+colW-2, y=rowY})
end
if totalP > 1 then
local navY = h - 3
local pS = string.format("[PREV] %d/%d [NEXT]", fluidLearnPage, totalP)
local navX = math.floor((w - #pS) / 2) + 1
drawText(navX, navY, pS, colors.white, colors.black)
table.insert(touchZones, {id="fluid_learn_prev", x1=navX, x2=navX+5, y=navY})
table.insert(touchZones, {id="fluid_learn_next", x1=navX+#pS-6, x2=navX+#pS-1, y=navY})
end
if fluidScanStatus ~= "" then
drawText(2, h - 3, fluidScanStatus, colors.yellow, colors.black)
local cancStr = " [ CANCEL SCAN ] "
local cancX = math.floor((w - #cancStr) / 2) + 1
drawText(cancX, h - 1, cancStr, colors.white, colors.red)
craftCancelY  = h - 1
craftCancelX1 = cancX
craftCancelX2 = cancX + #cancStr - 1
elseif fluidLearnMachine then
local backS  = " BACK "
local scanS  = " SCAN "
local flOutS = " FL/OUT "
local itOutS = " IT/OUT "
local flInS  = " FL/INP "
local itInS  = " IT/INP "
local g = 1
local rowW = #flOutS + g + #backS + g + #scanS + g + #itOutS
local flOutX = math.floor((w - rowW) / 2) + 1
local backX  = flOutX + #flOutS + g
local scanX  = backX + #backS + g
local itOutX = scanX + #scanS + g
local function devCol(pick, set)
if pick then return colors.black, colors.yellow
elseif set then return colors.black, colors.lime
else return colors.white, colors.gray end
end
local af, ab = devCol(fluidFluidInPick, fluidLearnFluidIn ~= nil)
drawText(flOutX, h-2, flInS, af, ab)
table.insert(touchZones, {id="fluid_fluidin_toggle", x1=flOutX, x2=flOutX+#flInS-1, y=h-2})
local bf, bb = devCol(fluidItemInPick, fluidLearnItemIn ~= nil)
drawText(itOutX, h-2, itInS, bf, bb)
table.insert(touchZones, {id="fluid_iteminput_toggle", x1=itOutX, x2=itOutX+#itInS-1, y=h-2})
local cf, cb = devCol(fluidOutputPick, fluidLearnOutput ~= nil)
drawText(flOutX, h-1, flOutS, cf, cb)
table.insert(touchZones, {id="fluid_pull_toggle", x1=flOutX, x2=flOutX+#flOutS-1, y=h-1})
local df, db = devCol(fluidItemOutPick, fluidLearnItemOut ~= nil)
drawText(itOutX, h-1, itOutS, df, db)
table.insert(touchZones, {id="fluid_itemout_toggle", x1=itOutX, x2=itOutX+#itOutS-1, y=h-1})
drawText(backX, h-1, backS, colors.white, colors.gray)
table.insert(touchZones, {id="fluid_learn_back_inputs", x1=backX, x2=backX+#backS-1, y=h-1})
drawText(scanX, h-1, scanS, colors.black, colors.lime)
table.insert(touchZones, {id="fluid_learn_scan", x1=scanX, x2=scanX+#scanS-1, y=h-1})
else
local backS = " BACK "
local sX = math.floor((w - #backS) / 2) + 1
drawText(sX, h-1, backS, colors.white, colors.gray)
table.insert(touchZones, {id="fluid_learn_back_inputs", x1=sX, x2=sX+#backS-1, y=h-1})
end
end
end
local _B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64enc(s)
local r = {}
for i = 1, #s, 3 do
local a, b, c = s:byte(i, i+2); b = b or 0; c = c or 0
local n = a*65536 + b*256 + c
r[#r+1] = _B64:sub(math.floor(n/262144)%64+1, math.floor(n/262144)%64+1)
r[#r+1] = _B64:sub(math.floor(n/4096)%64+1,   math.floor(n/4096)%64+1)
r[#r+1] = _B64:sub(math.floor(n/64)%64+1,     math.floor(n/64)%64+1)
r[#r+1] = _B64:sub(n%64+1,                    n%64+1)
end
local p = #s % 3
if p == 1 then r[#r] = "="; r[#r-1] = "=" elseif p == 2 then r[#r] = "=" end
return table.concat(r)
end
local function b64dec(s)
s = s:gsub("[^A-Za-z0-9+/=]", "")
local r = {}
for i = 1, #s, 4 do
local function v(c) return c == "=" and 0 or (_B64:find(c, 1, true) - 1) end
local a, b, c, d = v(s:sub(i,i)), v(s:sub(i+1,i+1)), v(s:sub(i+2,i+2)), v(s:sub(i+3,i+3))
local n = a*262144 + b*4096 + c*64 + d
r[#r+1] = string.char(math.floor(n/65536)%256)
if s:sub(i+2,i+2) ~= "=" then r[#r+1] = string.char(math.floor(n/256)%256) end
if s:sub(i+3,i+3) ~= "=" then r[#r+1] = string.char(n%256) end
end
return table.concat(r)
end
local function httpGetSync(url, headers)
local ok, handle = pcall(http.get, url, headers)
if not ok or not handle then return nil end
local d = handle.readAll(); handle.close(); return d
end
local function notifyCraftDone(label, qty, isFluid)
local topic = Config.ntfy_topic
if not topic or topic == "" then return end
if not (http and http.request) then return end
local url = topic:find("://") and topic or ("https://ntfy.sh/" .. topic)
local short = label:match(":(.+)$") or label
local body
if qty and qty > 0 then
body = isFluid and (short .. " " .. qty .. " mB") or (qty .. "x " .. short)
else
body = short .. " done"
end
pcall(function()
http.request({url = url, method = "POST", body = body,
headers = {["Title"] = "AEGIS craft done", ["Tags"] = "white_check_mark"}})
end)
end
local function notifyCraftFail(label)
local topic = Config.ntfy_topic
if not topic or topic == "" then return end
if not (http and http.request) then return end
local url = topic:find("://") and topic or ("https://ntfy.sh/" .. topic)
local short = label and (label:match(":(.+)$") or label) or "craft"
pcall(function()
http.request({url = url, method = "POST", body = "INTERRUPTED: " .. short,
headers = {["Title"] = "AEGIS craft failed", ["Priority"] = "high", ["Tags"] = "x"}})
end)
end
function ntfyBaseUrl()
local topic = Config.ntfy_topic
if not topic or topic == "" then return nil end
return topic:find("://") and topic or ("https://ntfy.sh/" .. topic)
end
function ntfyPublish(body, title, tags)
local url = ntfyBaseUrl()
if not url then return end
if not (http and http.request) then return end
pcall(function()
http.request({url = url, method = "POST", body = tostring(body),
headers = {["Title"] = title or "AEGIS", ["Tags"] = tags or "robot"}})
end)
end
function buildStatusText()
local ctx = displayCtx
if ctx and (ctx.total or 0) > 0 and not ctx.done then
local sDone  = craftStageDone or 0
local sTotal = math.max(craftStageTotal or 0, sDone, 1)
local pct  = math.floor(sDone / sTotal * 100)
local goal = ctx.finalGoalItem or "?"
goal = goal:match(":(.+)$") or goal
local lines = { goal .. " " .. pct .. "% (" .. sDone .. "/" .. sTotal .. ")" }
local n = 0
for _, a in pairs(ctx.active or {}) do
if n >= 6 then break end
lines[#lines + 1] = "- " .. tostring(a.desc or "?") .. " " .. (a.done or 0) .. "/" .. (a.total or 0)
n = n + 1
end
if n == 0 then lines[#lines + 1] = "(scheduling...)" end
return table.concat(lines, "\n")
end
if systemStatus and systemStatus ~= "IDLE" then
local s = "Busy: " .. tostring(systemStatus)
if fluidGoalLabel and fluidGoalLabel ~= "" then
local g = fluidGoalLabel:match(":(.+)$") or fluidGoalLabel
s = s .. "\n" .. g .. " step " .. (fluidStepNum or 0) .. "/" .. math.max(fluidStepNum or 0, fluidStepTotal or 0)
end
return s
end
local q = #(craftQueue or {})
if q > 0 then return "IDLE. Queue: " .. q .. " waiting." end
return "IDLE. No active craft."
end
function buildQueueText()
local q = craftQueue or {}
if #q == 0 then return "Queue empty." end
local lines = {}
for i = 1, math.min(8, #q) do
local qe = q[i]
local nm = qe.name:match(":(.+)$") or qe.name
local unit = (qe.kind == "fluid" and not qe.isItem) and " mB" or "x"
lines[#lines + 1] = i .. ". " .. nm .. " " .. qe.qty .. unit .. (qe.failed and " [FAIL]" or "")
end
if #q > 8 then lines[#lines + 1] = "... +" .. (#q - 8) .. " more" end
return table.concat(lines, "\n")
end
function ntfyPollCommands()
if Config.ntfy_cmds == false then return end
local url = ntfyBaseUrl()
if not url then return end
if not (http and http.get) then return end
local since = ntfyLastId and ("&since=" .. textutils.urlEncode(ntfyLastId)) or "&since=15s"
local ok, handle = pcall(http.get, url .. "/json?poll=1" .. since)
if not ok or not handle then return end
local body = handle.readAll(); handle.close()
if not body or body == "" then return end
local want = nil
for line in body:gmatch("[^\n]+") do
local okJ, obj = pcall(textutils.unserializeJSON, line)
if okJ and type(obj) == "table" and obj.event == "message" then
if obj.id then ntfyLastId = obj.id end
local title = tostring(obj.title or "")
if title:sub(1, 5) ~= "AEGIS" then
local msg = tostring(obj.message or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
if msg:sub(1, 1) == "/" then msg = msg:sub(2) end
if msg == "status" or msg == "stat" or msg == "s" then want = "status"
elseif msg == "queue" or msg == "q" then want = "queue"
elseif msg == "cancel" or msg == "stop" then want = "cancel" end
end
end
end
if want == "status" then
ntfyPublish(buildStatusText(), "AEGIS status", "bar_chart")
elseif want == "queue" then
ntfyPublish(buildQueueText(), "AEGIS queue", "clipboard")
elseif want == "cancel" then
cancelCrafting = true
ntfyPublish("Cancel requested.", "AEGIS status", "octagonal_sign")
end
end
function queueRunOne(qe)
if qe.kind == "fluid" then
local fOk, fProduced, fIsItem = runFluidCraftAmount(qe.recipe, qe.name, qe.qty)
if fOk then
notifyCraftDone(qe.name, fProduced, not fIsItem)
return true
end
notifyCraftFail(qe.name)
local reason = {}
for li = 1, math.min(4, #craftErrorLines) do reason[li] = craftErrorLines[li] end
if #reason == 0 then reason[1] = "Fluid craft failed" end
return false, reason
end
local preStock = groupAvailable(qe.name, getStorageInventory())
cancelCrafting = false
local plan, missingRes = planProduction(qe.name, qe.qty, true)
if plan and #plan == 0 and not next(missingRes or {}) then return true end
if next(missingRes or {}) then
local reason = {}
for mName, mCnt in pairs(missingRes) do
if #reason >= 4 then break end
reason[#reason + 1] = "Need " .. mCnt .. "x " .. (mName:match(":(.+)$") or mName)
end
if #reason == 0 then reason[1] = "Missing components" end
return false, reason
end
local craftOk = false
if plan and #plan > 0 then
craftOk = runCraftingProcess(plan)
local tlA = 0
while not cancelCrafting and tlA < 12 do
local totalNow = groupAvailable(qe.name, getStorageInventory())
if totalNow >= qe.qty then break end
tlA = tlA + 1
local rPlan = planProduction(qe.name, qe.qty, true)
if not (rPlan and #rPlan > 0) then break end
local beforeTL = totalNow
if runCraftingProcess(rPlan) then craftOk = true end
if groupAvailable(qe.name, getStorageInventory()) <= beforeTL then break end
end
end
if craftOk then
notifyCraftDone(qe.name, math.max(0, groupAvailable(qe.name, getStorageInventory()) - preStock), false)
return true
end
notifyCraftFail(qe.name)
local reason = {}
if craftErrorTitle then reason[#reason + 1] = craftErrorTitle end
for li = 1, #craftErrorLines do
if #reason >= 4 then break end
reason[#reason + 1] = tostring(craftErrorLines[li])
end
for mName, mCnt in pairs(missingRes or {}) do
if #reason >= 4 then break end
reason[#reason + 1] = "Need " .. mCnt .. "x " .. (mName:match(":(.+)$") or mName)
end
if #reason == 0 then reason[1] = "Craft failed" end
return false, reason
end
local function httpPutSync(url, body, headers)
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
local function ghHeaders()
return {
["Authorization"] = "token " .. (Config.github_token or ""),
["Accept"]        = "application/vnd.github.v3+json",
["User-Agent"]    = "AutoCraft-CC",
["Content-Type"]  = "application/json"
}
end
local function ghParseRepo()
local r = Config.github_repo or ""
return r:match("^([^/]+)/(.+)$")
end
local function ghApiUrl(path)
local owner, repo = ghParseRepo()
if not owner then return nil end
return "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents/" .. path
end
function recipeHasCustomIO(rec)
if type(rec) ~= "table" then return false end
if rec.output_device       and rec.output_device       ~= "" then return true end
if rec.item_input_device   and rec.item_input_device   ~= "" then return true end
if rec.fluid_input_device  and rec.fluid_input_device  ~= "" then return true end
if rec.item_output_device  and rec.item_output_device  ~= "" then return true end
if type(rec.output_tanks) == "table" and next(rec.output_tanks) then return true end
if type(rec.input_tanks)  == "table" and next(rec.input_tanks)  then return true end
return false
end
function mergeImportedMap(localMap, importedMap)
local out = {}
for k, v in pairs(localMap or {}) do
if recipeHasCustomIO(v) then out[k] = v end
end
for k, v in pairs(importedMap or {}) do
if type(v) == "table" and not recipeHasCustomIO(v) then
v.imported = true
out[k] = v
end
end
return out
end
function mergeImportedAlts(localAlts, importedAlts)
local out = {}
for k, list in pairs(localAlts or {}) do
if type(list) == "table" then
for _, rec in ipairs(list) do
if recipeHasCustomIO(rec) then out[k] = out[k] or {}; table.insert(out[k], rec) end
end
end
end
for k, list in pairs(importedAlts or {}) do
if type(list) == "table" then
for _, rec in ipairs(list) do
if type(rec) == "table" and not recipeHasCustomIO(rec) then
rec.imported = true
out[k] = out[k] or {}; table.insert(out[k], rec)
end
end
end
end
return out
end
function doGitExport(filename, existingSha)
gitWorking = true; gitStatus = "Uploading..."; gitStatusColor = colors.yellow
drawInterface()
if not Config.github_repo or Config.github_repo == "" then
gitStatus = "ERR: Repo not set (owner/repo)"; gitStatusColor = colors.red
gitWorking = false; gitStatusTimer = os.startTimer(6); return
end
if not Config.github_token or Config.github_token == "" then
gitStatus = "ERR: Token not set"; gitStatusColor = colors.red
gitWorking = false; gitStatusTimer = os.startTimer(6); return
end
local ts = tostring(math.floor(os.epoch("utc") / 1000))
filename = filename or ("autocraft_" .. ts .. ".json")
local url = ghApiUrl(filename)
if not url then
gitStatus = "ERR: Invalid repo format"; gitStatusColor = colors.red
gitWorking = false; gitStatusTimer = os.startTimer(6); return
end
local recipesExport = {}
for k, v in pairs(Recipes) do
if not (type(v) == "table" and v.type == "fluid") and not recipeHasCustomIO(v) then
recipesExport[k] = v
end
end
local altExport = {}
for k, list in pairs(AltRecipes) do
if type(list) == "table" then
for _, rec in ipairs(list) do
if not recipeHasCustomIO(rec) then altExport[k] = altExport[k] or {}; table.insert(altExport[k], rec) end
end
end
end
local fluidExport = {}
for k, v in pairs(FluidRecipes) do
if not recipeHasCustomIO(v) then fluidExport[k] = v end
end
local fluidAltExport = {}
for k, list in pairs(FluidAltRecipes) do
if type(list) == "table" then
for _, rec in ipairs(list) do
if not recipeHasCustomIO(rec) then fluidAltExport[k] = fluidAltExport[k] or {}; table.insert(fluidAltExport[k], rec) end
end
end
end
local exportData = textutils.serializeJSON({
recipes = recipesExport, alt_recipes = altExport,
fluid_recipes = fluidExport, fluid_alt_recipes = fluidAltExport,
machine_labels = MachineLabels, exported_at = os.epoch("utc")
})
gitStatus = "Uploading " .. filename .. "..."; drawInterface()
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
gitStatusColor = colors.lime
else
gitStatus = "ERR: " .. (err or "unknown"); gitStatusColor = colors.red
end
if gitStatusTimer then os.cancelTimer(gitStatusTimer) end
gitStatusTimer = os.startTimer(8)
end
function doGitListFiles()
gitWorking = true; gitStatus = "Loading file list..."; gitStatusColor = colors.yellow
drawInterface()
if not Config.github_repo or Config.github_repo == "" then
gitStatus = "ERR: Repo not set"; gitStatusColor = colors.red
gitWorking = false; gitStatusTimer = os.startTimer(6); return
end
local owner, repo = ghParseRepo()
if not owner then
gitStatus = "ERR: Invalid repo format (use owner/repo)"; gitStatusColor = colors.red
gitWorking = false; gitStatusTimer = os.startTimer(6); return
end
local listUrl = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents/"
local data = httpGetSync(listUrl, ghHeaders())
gitWorking = false
if not data then
gitStatus = "ERR: Cannot reach GitHub"; gitStatusColor = colors.red
gitStatusTimer = os.startTimer(6); return
end
local arr = textutils.unserializeJSON(data)
if type(arr) ~= "table" then
gitStatus = "ERR: Invalid response (check repo name/token)"; gitStatusColor = colors.red
gitStatusTimer = os.startTimer(6); return
end
gitFileList = {}
for _, f in ipairs(arr) do
if type(f) == "table" and f.type == "file" and f.name and f.name:match("%.json$") then
table.insert(gitFileList, {name = f.name, sha = f.sha, download_url = f.download_url})
end
end
if #gitFileList == 0 then
gitStatus = "No JSON files found in repo"; gitStatusColor = colors.orange
gitStatusTimer = os.startTimer(6)
else
table.sort(gitFileList, function(a, b) return a.name > b.name end)
gitImportMode = true; gitSelectedFile = 1; gitImportPage = 1
gitStatus = "Select file to import"; gitStatusColor = colors.white
end
end
function doGitImport()
local file = gitFileList[gitSelectedFile]
if not file then return end
gitWorking = true; gitStatus = "Downloading " .. file.name .. "..."; gitStatusColor = colors.yellow
drawInterface()
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
gitStatus = "ERR: Download failed"; gitStatusColor = colors.red
if gitStatusTimer then os.cancelTimer(gitStatusTimer) end
gitStatusTimer = os.startTimer(6); return
end
local parsed = textutils.unserializeJSON(content)
if not parsed or not parsed.recipes then
gitStatus = "ERR: Invalid file format"; gitStatusColor = colors.red
if gitStatusTimer then os.cancelTimer(gitStatusTimer) end
gitStatusTimer = os.startTimer(6); return
end
Recipes    = mergeImportedMap(Recipes, parsed.recipes)
AltRecipes = mergeImportedAlts(AltRecipes, parsed.alt_recipes or {})
if parsed.fluid_recipes     then FluidRecipes    = mergeImportedMap(FluidRecipes, parsed.fluid_recipes) end
if parsed.fluid_alt_recipes then FluidAltRecipes = mergeImportedAlts(FluidAltRecipes, parsed.fluid_alt_recipes) end
syncFluidItemStubs()
recipesScanResults = {}
saveData()
local count = 0; for _ in pairs(Recipes) do count = count + 1 end
gitStatus = "Imported " .. count .. " recipes from " .. file.name
gitStatusColor = colors.lime
if gitStatusTimer then os.cancelTimer(gitStatusTimer) end
gitStatusTimer = os.startTimer(8)
end
function doGitListForExport()
gitWorking = true; gitStatus = "Loading file list..."; gitStatusColor = colors.yellow
drawInterface()
if not Config.github_repo or Config.github_repo == "" then
gitStatus = "ERR: Repo not set"; gitStatusColor = colors.red
gitWorking = false; gitStatusTimer = os.startTimer(6); return
end
local owner, repo = ghParseRepo()
if not owner then
gitStatus = "ERR: Invalid repo format (use owner/repo)"; gitStatusColor = colors.red
gitWorking = false; gitStatusTimer = os.startTimer(6); return
end
local listUrl = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents/"
local data = httpGetSync(listUrl, ghHeaders())
gitWorking = false
if not data then
gitExportFileList = {}
gitExportSelected = 0
gitExportMode = true
gitStatus = ""; gitStatusColor = colors.gray
return
end
local arr = textutils.unserializeJSON(data)
gitExportFileList = {}
if type(arr) == "table" then
for _, f in ipairs(arr) do
if type(f) == "table" and f.type == "file" and f.name and f.name:match("%.json$") then
table.insert(gitExportFileList, {name = f.name, sha = f.sha})
end
end
table.sort(gitExportFileList, function(a, b) return a.name > b.name end)
end
gitExportSelected = 0; gitExportPage = 1
gitExportMode = true
gitStatus = ""; gitStatusColor = colors.gray
end
function groupKeyOf(machineName)
for _, cg in ipairs(CustomMachineGroups) do
for _, cm in ipairs(cg.machines) do
if cm == machineName then return "cg:" .. (cg.name or tostring(cg)) end
end
end
if ExcludedMachines[machineName] then return "m:" .. machineName end
return "g:" .. getMachineBaseName(machineName)
end
function pinnedToken(name)
if not name or name == "" then return nil end
for _, cg in ipairs(CustomMachineGroups) do
for _, cm in ipairs(cg.machines) do
if cm == name then return "cg:" .. (cg.name or tostring(cg)) end
end
end
if ExcludedMachines[name] then return "m:" .. name end
return "p:" .. name
end
function fluidRecipeTokens(fr)
local toks = {}
local seen = {}
local function add(tok)
if tok and not seen[tok] then seen[tok] = true; toks[#toks + 1] = tok end
end
if fr then
local anyDev = (fr.output_device and fr.output_device ~= "")
or (fr.item_input_device and fr.item_input_device ~= "")
or (fr.fluid_input_device and fr.fluid_input_device ~= "")
or (fr.item_output_device and fr.item_output_device ~= "")
if anyDev then
add(pinnedToken(fr.machine_name))
add(pinnedToken(fr.output_device))
add(pinnedToken(fr.item_input_device))
add(pinnedToken(fr.fluid_input_device))
add(pinnedToken(fr.item_output_device))
else
add(groupKeyOf(fr.machine_name))
end
end
if #toks == 0 then toks[1] = "FLUID" end
return toks
end
function stepTokens(step)
if step.fluid_craft then
return fluidRecipeTokens(step.fluidRecipe)
end
if step.type == "turtle" then return { "TURTLE" } end
if step.output_device and step.output_device ~= "" then
local toks = {}
local seen = {}
local function add(tok)
if tok and not seen[tok] then seen[tok] = true; toks[#toks + 1] = tok end
end
add(pinnedToken(step.machine_name))
add(pinnedToken(step.output_device))
return toks
end
return { groupKeyOf(step.machine_name) }
end
function sleepYield(t, ctx)
if cancelCrafting or (ctx and ctx.failed) then sleep(0); return end
local timer = os.startTimer(t)
local deadline = os.clock() + t + 0.1
while true do
if cancelCrafting or (ctx and ctx.failed) then os.cancelTimer(timer); return end
local ev, a = os.pullEvent()
if ev == "timer" and a == timer then return end
if os.clock() >= deadline then os.cancelTimer(timer); return end
if cancelCrafting or (ctx and ctx.failed) then os.cancelTimer(timer); return end
end
end
function executeStep(step, ctx, node)
local sortedStorages = ctx.sortedStorages
local provSrc        = providerSources()
local firstStorage   = ctx.firstStorage
local finalGoalItem  = ctx.finalGoalItem
local plan           = ctx.plan
local i              = node.idx
local w, h           = monitor.getSize()
local myCleanup      = {}
local nodeTopup      = false
local function drawProgress(stepNum, totalSteps, desc, currentCount, maxCount, activeItemName, workerCount)
ctx.active[node.idx] = { desc = desc, done = currentCount or 0, total = maxCount or 0,
machines = workerCount or 0, topup = nodeTopup }
if displayCtx and displayCtx ~= ctx then
displayCtx.active["NEST:" .. tostring(lockOwnerId())] = {
desc = desc, done = currentCount or 0, total = maxCount or 0,
machines = workerCount or 0, topup = nodeTopup, nest = true,
}
end
end
if step.count and step.count > 0 then
local desc = string.format("%d x %s", step.count * (step.output_count or 1), step.item:match(":(.+)$") or step.item)
if step.fluid_craft then
fluidGoalLabel = finalGoalItem ~= "" and finalGoalItem or step.item
fluidStepNum = 0
fluidStepTotal = countTopFluidSteps(step.fluidRecipe, step.item, step.fluidAmount)
ctx.active[node.idx] = {
desc = (step.item:match(":(.+)$") or step.item) .. " (fluid)",
done = 0, total = step.fluidAmount or 0, machines = 0, topup = false,
}
local coF = lockOwnerId()
local prevEnt = fluidInlineByCo[coF]
fluidInlineByCo[coF] = { ctx = ctx, node = node.idx }
local okF, errF = produceFluid(step.fluidRecipe, step.item, step.fluidAmount)
fluidInlineByCo[coF] = prevEnt
if displayCtx and displayCtx ~= ctx then
displayCtx.active["FLUIDNEST:" .. tostring(coF)] = nil
end
if not okF then
craftErrorTitle = "! FLUID SUBCRAFT FAILED"
craftErrorLines = errF or {"Unknown error"}
cleanupCraftMachines(sortedStorages, myCleanup)
return false
end
elseif step.type == "turtle" then
local turtleSlots = {1, 2, 3, 5, 6, 7, 9, 10, 11}
local turtlePool = {}
for tName, enabled in pairs(Config.turtles or {}) do
if enabled then
local tp = peripheral.wrap(tName)
if tp then table.insert(turtlePool, tName) end
end
end
table.sort(turtlePool)
if #turtlePool == 0 then
if step.machine_name and step.machine_name ~= "" then
turtlePool = {step.machine_name}
else
local itemShort = step.item:match(":(.+)$") or step.item
craftErrorTitle = "! NO TURTLE ASSIGNED"
craftErrorLines = {
"No turtle available",
"Required for: " .. itemShort,
"Assign a turtle in NETWORK tab.",
}
return false
end
end
if step.tools and next(step.tools) and #turtlePool > 1 then
turtlePool = { turtlePool[1] }
end
myCleanup = {}
for _, tName in ipairs(turtlePool) do
table.insert(myCleanup, {name = tName, pullNames = nil})
craftUsedMachines[tName] = true
end
if step.count and step.count > 0 and not cancelCrafting then
local ingNeed0 = {}
for idx0 = 1, 9 do
local ing0 = step.ingredients[idx0]
if ing0 and ing0 ~= "nil" then ingNeed0[ing0] = (ingNeed0[ing0] or 0) + 1 end
end
releaseTokens(node.tokens)
for ing0, perOp0 in pairs(ingNeed0) do
if step.tools and step.tools[ing0] then
ensureItemAvailable(ing0, 1)
else
ensureItemAvailable(ing0, perOp0 * step.count)
end
end
while not cancelCrafting and not ctx.failed do
if tryAcquireTokens(node.tokens) then break end
sleepYield(0.2, ctx)
end
if cancelCrafting or ctx.failed then return false end
end
local storageObj = peripheral.wrap(firstStorage)
local function craftSlotsDirty(tName)
local tp = peripheral.wrap(tName)
if not (tp and tp.list) then return nil end
local ok, its = pcall(tp.list)
if not (ok and its) then return nil end
for _, it in pairs(its) do
if it and (it.count or 0) > 0 then return true end
end
return false
end
local function clearTurtleGrid(tName)
local dirty = craftSlotsDirty(tName)
if dirty == false then return true end
if dirty == nil then return blindUnloadTurtle(tName, sortedStorages) end
for _attempt = 1, 3 do
for slot = 1, 16 do
for _, stoName in ipairs(sortedStorages) do
local sto = peripheral.wrap(stoName)
if sto and sto.pullItems then
local okp, mv = pcall(sto.pullItems, tName, slot, 64)
if okp and mv and mv > 0 then break end
end
end
end
if craftSlotsDirty(tName) ~= true then return true end
end
return false
end
for _, tName in ipairs(turtlePool) do clearTurtleGrid(tName) end
local poolSize = #turtlePool
local base  = math.floor(step.count / poolSize)
local extra = step.count % poolSize
local assignments = {}
for ai, tName in ipairs(turtlePool) do
local cnt = base + (ai <= extra and 1 or 0)
if cnt > 0 then
table.insert(assignments, {name = tName, remaining = cnt})
end
end
local totalDone   = 0
local totalNeeded = step.count
local turtleStall = 0
local outMaxStack = nil
local function lookupOutMax()
if outMaxStack then return outMaxStack end
for _, stoName in ipairs(sortedStorages) do
local sto = peripheral.wrap(stoName)
if sto and sto.list and sto.getItemDetail then
local okL, lst = pcall(sto.list)
if okL and lst then
for slot, it in pairs(lst) do
if it and it.name == step.item then
local okD, det = pcall(sto.getItemDetail, slot)
if okD and det and det.maxCount and det.maxCount > 0 then
outMaxStack = det.maxCount
return outMaxStack
end
end
end
end
end
end
return nil
end
local toolSet = step.tools or {}
local function isTool(n) return toolSet[n] and true or false end
while totalDone < totalNeeded do
if cancelCrafting then
cleanupCraftMachines(sortedStorages, myCleanup)
return false
end
drawProgress(i, #plan, desc, totalDone, totalNeeded, step.item, #turtlePool)
local active = {}
for _, asgn in ipairs(assignments) do
if asgn.remaining > 0 then table.insert(active, asgn) end
end
if #active == 0 then break end
for _, asgn in ipairs(active) do clearTurtleGrid(asgn.name) end
local ingNeed = {}
for idx2 = 1, 9 do
local ing = step.ingredients[idx2]
if ing and ing ~= "nil" then ingNeed[ing] = (ingNeed[ing] or 0) + 1 end
end
local tStock = {}
local srcByName = {}
for ing in pairs(ingNeed) do
tStock[ing] = 0
srcByName[ing] = srcByName[ing] or {}
local grp = ITEM_GROUPS[ing]
if grp then for _, alt in ipairs(GROUPS[grp]) do
tStock[alt] = tStock[alt] or 0
srcByName[alt] = srcByName[alt] or {}
end end
end
local tScanList = {}
for _, s in ipairs(sortedStorages) do tScanList[#tScanList + 1] = s end
for _, s in ipairs(provSrc) do tScanList[#tScanList + 1] = s end
for _, stoName in ipairs(tScanList) do
local sto = peripheral.wrap(stoName)
if sto and sto.list and sto.pushItems then
local okL, lst = pcall(sto.list)
if okL and lst then
for slot, it in pairs(lst) do
if it and tStock[it.name] ~= nil and (it.count or 0) > 0 then
tStock[it.name] = tStock[it.name] + it.count
local arr = srcByName[it.name]
arr[#arr + 1] = {sto = sto, slot = slot, count = it.count}
end
end
end
end
end
local feasibleOps = nil
for ing, need in pairs(ingNeed) do
if not isTool(ing) then
local f = math.floor(groupAvailable(ing, tStock) / need)
if feasibleOps == nil or f < feasibleOps then feasibleOps = f end
end
end
feasibleOps = feasibleOps or 0
local chosenType   = {}
local consistentCap = nil
for ing, need in pairs(ingNeed) do
if not isTool(ing) then
local best, bestCnt = ing, tStock[ing] or 0
local grp = ITEM_GROUPS[ing]
if grp then
for _, alt in ipairs(GROUPS[grp]) do
local c = tStock[alt] or 0
if c > bestCnt then best, bestCnt = alt, c end
end
end
chosenType[ing] = best
local cap = math.floor(bestCnt / need)
if consistentCap == nil or cap < consistentCap then consistentCap = cap end
end
end
consistentCap = consistentCap or 0
if feasibleOps <= 0 then
local itemShort = step.item:match(":(.+)$") or step.item
craftErrorTitle = "! NEED"
local remaining = totalNeeded - totalDone
local parts = {}
for ing, perOp in pairs(ingNeed) do
local short = perOp * remaining - groupAvailable(ing, tStock)
if short > 0 then parts[#parts + 1] = string.format("%dx %s", short, ing:match(":(.+)$") or ing) end
end
local lines = {"Can't make " .. itemShort}
appendMissingLine(lines, parts)
craftErrorLines = lines
cleanupCraftMachines(sortedStorages, myCleanup)
return false
end
local toolMissing = nil
for ing in pairs(ingNeed) do
if isTool(ing) and (tStock[ing] or 0) < 1 then toolMissing = ing; break end
end
if toolMissing then
releaseTokens(node.tokens)
local okTool, toolErr = ensureItemAvailable(toolMissing, 1)
while not cancelCrafting and not ctx.failed do
if tryAcquireTokens(node.tokens) then break end
sleepYield(0.2, ctx)
end
if cancelCrafting or ctx.failed then
cleanupCraftMachines(sortedStorages, myCleanup)
return false
end
if not okTool then
craftErrorTitle = "! NEED TOOL"
craftErrorLines = toolErr or {"Can't make tool: " .. (toolMissing:match(":(.+)$") or toolMissing)}
cleanupCraftMachines(sortedStorages, myCleanup)
return false
end
else
local function pushDirect(ing, amount, turtleName, targetSlot)
local feeds = { ing }
local grp = ITEM_GROUPS[ing]
if grp then for _, alt in ipairs(GROUPS[grp]) do
if alt ~= ing then feeds[#feeds + 1] = alt end
end end
local moved = 0
for _, name in ipairs(feeds) do
local srcs = srcByName[name]
if srcs then
for _, s in ipairs(srcs) do
if moved >= amount then break end
if s.count > 0 then
local okD, det = pcall(s.sto.getItemDetail, s.slot)
if okD and det and det.name == name and (det.count or 0) > 0 then
local want = math.min(amount - moved, det.count)
local okP, mv = pcall(s.sto.pushItems, turtleName, s.slot, want, targetSlot)
if okP and mv and mv > 0 then
moved = moved + mv
s.count = s.count - mv
end
else
s.count = 0
end
end
end
end
end
return moved
end
local function pushExact(name, amount, turtleName, targetSlot)
local srcs = srcByName[name]
if not srcs then return 0 end
local moved = 0
for _, s in ipairs(srcs) do
if moved >= amount then break end
if s.count > 0 then
local okD, det = pcall(s.sto.getItemDetail, s.slot)
if okD and det and det.name == name and (det.count or 0) > 0 then
local want = math.min(amount - moved, det.count)
local okP, mv = pcall(s.sto.pushItems, turtleName, s.slot, want, targetSlot)
if okP and mv and mv > 0 then
moved = moved + mv
s.count = s.count - mv
end
else
s.count = 0
end
end
end
return moved
end
local turtleOutputPerOp = step.output_count or 1
local outMax = lookupOutMax()
local slotCap
if outMax then
slotCap = math.floor(outMax / math.max(1, turtleOutputPerOp))
else
slotCap = math.floor(7 / math.max(1, turtleOutputPerOp))
end
if slotCap < 1 then slotCap = 1 end
local useConsistent = consistentCap >= 1
local feasLeft = feasibleOps
local round = {}
for _, asgn in ipairs(active) do
if feasLeft <= 0 then break end
local batchSize = math.min(slotCap, asgn.remaining, feasLeft)
if useConsistent and batchSize > consistentCap then batchSize = consistentCap end
if batchSize > 0 and clearTurtleGrid(asgn.name) then
asgn.currentBatch = batchSize
feasLeft = feasLeft - batchSize
for idx2 = 1, 9 do
local ing = step.ingredients[idx2]
if ing and ing ~= "nil" then
if isTool(ing) then
pushExact(ing, 1, asgn.name, turtleSlots[idx2])
elseif useConsistent then
pushExact(chosenType[ing] or ing, batchSize, asgn.name, turtleSlots[idx2])
else
pushDirect(ing, batchSize, asgn.name, turtleSlots[idx2])
end
end
end
round[#round + 1] = asgn
end
end
active = round
if #active == 0 then
turtleStall = turtleStall + 1
if turtleStall > 30 then
local itemShort = step.item:match(":(.+)$") or step.item
craftErrorTitle = "! TURTLE GRID BLOCKED"
craftErrorLines = {
"Can't clear turtle grid for " .. itemShort,
"Residue stuck (item storage full?).",
"Free up storage space and retry.",
}
cleanupCraftMachines(sortedStorages, myCleanup)
return false
end
sleepCheckCancel(0.3)
else
turtleStall = 0
end
local craftResults  = {}
local craftTasks   = {}
local finishedCount = 0
local batchTotal    = #active
for ci, asgn in ipairs(active) do
local tName = asgn.name
local ri    = ci
craftTasks[#craftTasks + 1] = function()
local crafted = false
local so = peripheral.wrap(firstStorage)
for _ = 1, 120 do
sleepCheckCancel(0.05)
if cancelCrafting then break end
if so and so.pullItems then
local s, res = pcall(so.pullItems, tName, 16, 64)
if s and res and res > 0 then crafted = true; break end
end
end
if crafted then
if so and so.pullItems then
for slot = 1, 15 do pcall(so.pullItems, tName, slot, 64) end
end
end
craftResults[ri] = crafted
finishedCount = finishedCount + 1
end
end
craftTasks[#craftTasks + 1] = function()
while finishedCount < batchTotal and not cancelCrafting do
local t = os.startTimer(0.05)
while true do
local ev, a, b, c = os.pullEvent()
if ev == "timer" and a == t then break end
if ev == "monitor_touch" and craftCancelY
and c == craftCancelY and b >= craftCancelX1 and b <= craftCancelX2 then
cancelCrafting = true
os.cancelTimer(t)
break
end
end
end
end
parallel.waitForAll(table.unpack(craftTasks))
for ci, asgn in ipairs(active) do
if craftResults[ci] then
asgn.remaining = asgn.remaining - (asgn.currentBatch or 1)
totalDone = totalDone + (asgn.currentBatch or 1)
else
cleanupCraftMachines(sortedStorages, myCleanup)
return false
end
end
end
end
for _, tName in ipairs(turtlePool) do clearTurtleGrid(tName) end
else
local activePool = {}
for _, mName in ipairs(getMachinePool(step.machine_name)) do
local p = peripheral.wrap(mName)
if p and p.list and p.pushItems then
table.insert(activePool, mName)
end
end
local splitOutName, splitOutPeriph = nil, nil
if step.output_device and step.output_device ~= "" then
splitOutName   = step.output_device
splitOutPeriph = peripheral.wrap(splitOutName)
if not (splitOutPeriph and splitOutPeriph.list) then
craftErrorTitle = "! MACHINE NOT FOUND"
craftErrorLines = {
"Output device not found: " .. getMachineDisplay(splitOutName),
"Required for: " .. (step.item:match(":(.+)$") or step.item),
"Reconnect device or re-learn recipe.",
}
craftErrorEditItems = { [2] = step.item }
return false
end
activePool = {}
local pIn = peripheral.wrap(step.machine_name)
if pIn and pIn.list and pIn.pushItems then
activePool = {step.machine_name}
end
end
if #activePool == 0 then
local mDisplay = getMachineDisplay and getMachineDisplay(step.machine_name or "?") or (step.machine_name or "?")
local itemShort = step.item:match(":(.+)$") or step.item
craftErrorTitle = "! MACHINE NOT FOUND"
craftErrorLines = {
"Machine not found: " .. mDisplay,
"Required for: " .. itemShort,
"Use [E] in RECIPES to reassign machine.",
}
craftErrorEditItems = { [2] = step.item }
return false
end
local ingCounts = {}
local ingSlot   = {}
local ingSlotN  = 0
for ingIdx = 1, #step.ingredients do
local ing = step.ingredients[ingIdx]
if ing and ing ~= "nil" then
ingCounts[ing] = (ingCounts[ing] or 0) + 1
if not ingSlot[ing] then
ingSlotN = ingSlotN + 1
ingSlot[ing] = ingSlotN
end
end
end
if step.count and step.count > 0 and not cancelCrafting then
releaseTokens(node.tokens)
for ingName, ingPerOp in pairs(ingCounts) do
ensureItemAvailable(ingName, ingPerOp * step.count)
end
while not cancelCrafting and not ctx.failed do
if tryAcquireTokens(node.tokens) then break end
sleepYield(0.2, ctx)
end
if cancelCrafting or ctx.failed then return false end
end
local ingPullNames = {}
for ingName in pairs(ingCounts) do ingPullNames[ingName] = true end
myCleanup = {}
for _, mName in ipairs(activePool) do
table.insert(myCleanup, {name = mName, pullNames = ingPullNames})
end
if splitOutName then
table.insert(myCleanup, {name = splitOutName, pullNames = ingPullNames})
end
for _, mNameU in ipairs(activePool) do craftUsedMachines[mNameU] = true end
if splitOutName then craftUsedMachines[splitOutName] = true end
local totalOps      = step.count
local outputPerOp   = step.output_count or 1
local totalExpected = totalOps * outputPerOp
local poolSize      = #activePool
local base  = math.floor(totalOps / poolSize)
local extra = totalOps % poolSize
drawProgress(i, #plan, desc, 0, totalExpected, step.item, #activePool)
local ingMaxStack = {}
for ingName in pairs(ingCounts) do
local maxS = 64
local found = false
for _, stoName in ipairs(sortedStorages) do
if found then break end
local sto = peripheral.wrap(stoName)
if sto and sto.list and sto.getItemDetail then
local sLst, lst = pcall(sto.list)
if sLst and lst then
for slotI, itemI in pairs(lst) do
if itemI and itemI.name == ingName then
local sDet, det = pcall(sto.getItemDetail, slotI)
if sDet and det and det.maxCount and det.maxCount > 0 then
maxS = det.maxCount
end
found = true
break
end
end
end
end
end
ingMaxStack[ingName] = maxS
end
local function pushBatch(mName, opsCount)
local machHas = {}
do
local pm = peripheral.wrap(mName)
if pm and pm.list then
local okM, its = pcall(pm.list)
if okM and its then
for _, it in pairs(its) do
if it and ingCounts[it.name] then
machHas[it.name] = (machHas[it.name] or 0) + (it.count or 0)
end
end
end
end
end
for ingName, ingPerOp in pairs(ingCounts) do
local maxS = ingMaxStack[ingName] or 64
local curOps = math.floor((machHas[ingName] or 0) / ingPerOp)
local addable
if maxS >= ingPerOp then
addable = math.floor(maxS / ingPerOp) - curOps
else
addable = (curOps > 0) and 0 or 1
end
if addable < opsCount then opsCount = addable end
end
local stockCnt = {}
for ingName in pairs(ingCounts) do
stockCnt[ingName] = 0
local grp = ITEM_GROUPS[ingName]
if grp then for _, alt in ipairs(GROUPS[grp]) do stockCnt[alt] = stockCnt[alt] or 0 end end
end
local srcList = {}
for _, s in ipairs(sortedStorages) do srcList[#srcList + 1] = s end
for _, s in ipairs(provSrc) do srcList[#srcList + 1] = s end
for _, stoName in ipairs(srcList) do
local sto = peripheral.wrap(stoName)
if sto and sto.list then
local okL, lst = pcall(sto.list)
if okL and lst then
for _, it in pairs(lst) do
if it and stockCnt[it.name] ~= nil then
stockCnt[it.name] = stockCnt[it.name] + (it.count or 0)
end
end
end
end
end
for ingName, ingPerOp in pairs(ingCounts) do
local feasOps = math.floor(groupAvailable(ingName, stockCnt) / ingPerOp)
if feasOps < opsCount then opsCount = feasOps end
end
if opsCount <= 0 then return 0 end
local accepted = opsCount
for ingName, ingPerOp in pairs(ingCounts) do
local have   = machHas[ingName] or 0
local curOps = math.floor(have / ingPerOp)
local needed = (curOps + opsCount) * ingPerOp - have
local moved  = 0
if needed > 0 then
if ingPerOp <= (ingMaxStack[ingName] or 64) then
moved = pushFromStorage(ingName, needed, mName, ingSlot[ingName])
end
if moved < needed then
moved = moved + pushFromStorage(ingName, needed - moved, mName)
end
end
local newOps = math.floor((have + moved) / ingPerOp) - curOps
if newOps < accepted then accepted = newOps end
end
return accepted
end
local preUnloadList = {}
for _, mName in ipairs(activePool) do table.insert(preUnloadList, mName) end
if splitOutName then table.insert(preUnloadList, splitOutName) end
local dirtyDrop = {}
for _, mName in ipairs(preUnloadList) do
local mPeriph = peripheral.wrap(mName)
if mPeriph and mPeriph.list then
for _pass = 1, 3 do
local sPre, preItems = pcall(mPeriph.list)
if not (sPre and preItems) then break end
local anyPre = false
for slotPre, itemPre in pairs(preItems) do
if itemPre and itemPre.name and itemPre.count and itemPre.count > 0 then
anyPre = true
local leftPre = itemPre.count
if mPeriph.pushItems then
for _, stoName in ipairs(sortedStorages) do
if leftPre <= 0 then break end
local okP, mvP = pcall(mPeriph.pushItems, stoName, slotPre, leftPre)
if okP and mvP and mvP > 0 then leftPre = leftPre - mvP end
end
end
if leftPre > 0 then
for _, stoName in ipairs(sortedStorages) do
if leftPre <= 0 then break end
local sto = peripheral.wrap(stoName)
if sto and sto.pullItems then
local okQ, mvQ = pcall(sto.pullItems, mName, slotPre, leftPre)
if okQ and mvQ and mvQ > 0 then leftPre = leftPre - mvQ end
end
end
end
end
end
if not anyPre then break end
sleepCheckCancel(0.2)
end
local sChk, chkItems = pcall(mPeriph.list)
if sChk and chkItems then
for _, ci in pairs(chkItems) do
if ci and ci.name == step.item and (ci.count or 0) > 0 then
dirtyDrop[mName] = true
end
end
end
end
if mPeriph and mPeriph.tanks then
local okT, tl = pcall(mPeriph.tanks)
if okT and tl then
for _, tk in pairs(tl) do
if tk and tk.name and tk.amount and tk.amount > 0 then
drainFluidToStorage(mName, tk.name, tk.amount)
end
end
end
end
end
if next(dirtyDrop) and not splitOutName then
local np = {}
for _, mName in ipairs(activePool) do
if not dirtyDrop[mName] then np[#np + 1] = mName end
end
if #np > 0 then
activePool = np
poolSize = #activePool
base  = math.floor(totalOps / poolSize)
extra = totalOps % poolSize
end
end
local machineData = {}
for bIdx = 1, poolSize do
local assignedOps = base + (bIdx <= extra and 1 or 0)
if assignedOps > 0 then
local mName   = activePool[bIdx]
local mPeriph = peripheral.wrap(mName)
if mPeriph then
local collectPeriph = splitOutPeriph or mPeriph
local collectName  = splitOutName  or mName
local excluded = {}
local preSnap  = {}
local sSnap, snapItems = pcall(collectPeriph.list)
if sSnap and snapItems then
for _, si in pairs(snapItems) do
if si then
excluded[si.name] = true
preSnap[si.name] = (preSnap[si.name] or 0) + si.count
end
end
end
for ingName in pairs(ingCounts) do
excluded[ingName] = true
end
local acceptedOps = pushBatch(mName, assignedOps)
table.insert(machineData, {
periph            = mPeriph,
outPeriph         = collectPeriph,
name              = mName,
outName           = collectName,
excluded          = excluded,
preSnap           = preSnap,
remainOps         = assignedOps - acceptedOps,
pendingItems      = acceptedOps * outputPerOp,
doneItems         = 0,
lastCollectTick   = 0,
exhausted         = false,
hasEverCollected  = false,
collectCount      = 0,
refillCount       = 0,
})
end
end
end
local totalCollected = 0
local maxWait = math.max(600, totalOps * 60)
local waited  = 0
local continueOuter = true
while continueOuter do
continueOuter = false
for _, e in ipairs(machineData) do e.exhausted = false end
while totalCollected < totalExpected and waited < maxWait do
sleepCheckCancel(0.5)
if cancelCrafting then
cleanupCraftMachines(sortedStorages, myCleanup)
return false
end
waited = waited + 1
drawProgress(i, #plan, desc, totalCollected, totalExpected, step.item, #machineData)
for _, entry in ipairs(machineData) do
local hasLeftover = false
local s, mItems = pcall(entry.outPeriph.list)
if s and mItems then
for slot, mItem in pairs(mItems) do
if mItem and not entry.excluded[mItem.name] then
local toTake = mItem.count
local moved = 0
for _, stoName in ipairs(sortedStorages) do
if moved >= toTake then break end
local s2, m = pcall(entry.outPeriph.pushItems, stoName, slot, toTake - moved)
if s2 and m and m > 0 then moved = moved + m end
end
if moved < toTake then
for _, stoName in ipairs(sortedStorages) do
if moved >= toTake then break end
local sto2 = peripheral.wrap(stoName)
if sto2 and sto2.pullItems then
local s3, m3 = pcall(sto2.pullItems, entry.outName, slot, toTake - moved)
if s3 and m3 and m3 > 0 then moved = moved + m3 end
end
end
end
if moved > 0 then
local gap = waited - entry.lastCollectTick
if gap > (entry.maxGap or 0) then entry.maxGap = gap end
entry.lastCollectTick  = waited
entry.hasEverCollected = true
entry.collectCount     = (entry.collectCount or 0) + 1
if mItem.name == step.item then
entry.doneItems = entry.doneItems + moved
totalCollected  = totalCollected + moved
end
end
if moved < toTake then hasLeftover = true end
end
end
end
local hasInput = false
local si2, mI2 = pcall(entry.periph.list)
if si2 and mI2 then
for _, mi2 in pairs(mI2) do
if mi2 and ingCounts[mi2.name] then
local preC = (entry.preSnap and entry.preSnap[mi2.name]) or 0
if mi2.count > preC then hasInput = true; break end
end
end
end
local runnableOps
if si2 and mI2 then
local ingTotNow = {}
for _, mi2 in pairs(mI2) do
if mi2 and ingCounts[mi2.name] then
ingTotNow[mi2.name] = (ingTotNow[mi2.name] or 0) + mi2.count
end
end
for ingName, ingPerOp in pairs(ingCounts) do
local o = math.floor((ingTotNow[ingName] or 0) / ingPerOp)
if runnableOps == nil or o < runnableOps then runnableOps = o end
end
end
runnableOps = runnableOps or 0
local owes = entry.doneItems < entry.pendingItems
local idleTicks = waited - entry.lastCollectTick
local quietNeed = math.max(4, (entry.maxGap or 0) * 2 + 4)
if owes then
if (entry.collectCount or 0) >= 2 then
quietNeed = math.max(20, quietNeed)
else
quietNeed = math.max(120, quietNeed)
end
end
if hasInput and runnableOps == 0 and not hasLeftover
and idleTicks >= math.max(6, quietNeed) then
local acc = pushBatch(entry.name, math.max(1, entry.remainOps))
if acc > 0 then
entry.remainOps    = math.max(0, entry.remainOps - acc)
entry.pendingItems = entry.pendingItems + acc * outputPerOp
entry.lastCollectTick = waited
entry.starve = 0
else
entry.starve = (entry.starve or 0) + 1
if entry.starve >= 6 then entry.exhausted = true end
end
elseif entry.remainOps > 0 then
if not hasInput and not hasLeftover then
local acceptedOps = pushBatch(entry.name, entry.remainOps)
if acceptedOps > 0 then
entry.remainOps    = entry.remainOps - acceptedOps
entry.pendingItems = entry.pendingItems + acceptedOps * outputPerOp
entry.lastCollectTick = waited
entry.starve = 0
entry.exhausted = false
elseif not owes or idleTicks >= quietNeed then
entry.starve = (entry.starve or 0) + 1
if entry.starve >= 6 then entry.exhausted = true end
end
end
elseif not entry.exhausted and entry.hasEverCollected and not hasInput
and not hasLeftover and idleTicks >= quietNeed then
local deficit = totalExpected - totalCollected
if deficit > 0 then
local opsNeeded = math.ceil(deficit / outputPerOp)
local accepted  = pushBatch(entry.name, opsNeeded)
if accepted > 0 then
nodeTopup             = true
entry.pendingItems    = entry.pendingItems + accepted * outputPerOp
entry.lastCollectTick = waited
entry.refillCount     = entry.refillCount + 1
entry.starve          = 0
else
entry.starve = (entry.starve or 0) + 1
if entry.starve >= 6 then entry.exhausted = true end
end
else
entry.exhausted = true
end
end
end
local allExhausted = true
for _, entry in ipairs(machineData) do
if not entry.exhausted then allExhausted = false; break end
end
if allExhausted then break end
end
local flushSilence    = 0
local flushMaxSilence = 2
repeat
local hadOutput = false
for _, entry in ipairs(machineData) do
local sp = entry.outPeriph
if sp and sp.list and sp.pushItems then
local sok, curItems = pcall(sp.list)
if sok and curItems then
local flushLeftover = false
for slot2, curItem in pairs(curItems) do
if curItem and not ingCounts[curItem.name] then
local preCount = (entry.preSnap and entry.preSnap[curItem.name]) or 0
local toPull   = curItem.count - preCount
if toPull > 0 then
local pulled = 0
for _, stoName in ipairs(sortedStorages) do
if pulled >= toPull then break end
local sm, mm = pcall(sp.pushItems, stoName, slot2, toPull - pulled)
if sm and mm and mm > 0 then pulled = pulled + mm end
end
if pulled > 0 then
hadOutput = true
if curItem.name == step.item then
entry.doneItems = entry.doneItems + pulled
totalCollected  = totalCollected  + pulled
end
end
if pulled < toPull then flushLeftover = true end
end
end
end
entry._flushLeftover = flushLeftover
end
end
if entry.remainOps > 0 and not entry._flushLeftover
and totalCollected < totalExpected then
local nextOps     = entry.remainOps
local acceptedOps = pushBatch(entry.name, nextOps)
if acceptedOps > 0 then
entry.remainOps        = nextOps - acceptedOps
entry.pendingItems     = entry.pendingItems + acceptedOps * outputPerOp
entry.exhausted        = false
entry.hasEverCollected = false
entry.lastCollectTick  = waited
continueOuter = true
end
end
end
local flushNeed = flushMaxSilence
for _, entry in ipairs(machineData) do
if entry.doneItems < entry.pendingItems then
local floorQ = ((entry.collectCount or 0) >= 2) and 20 or 120
local q = math.max(floorQ, (entry.maxGap or 0) * 2 + 4)
if q > flushNeed then flushNeed = q end
end
end
if hadOutput then
flushSilence = 0
else
flushSilence = flushSilence + 1
end
if flushSilence < flushNeed and not cancelCrafting then
sleepCheckCancel(0.5)
end
until flushSilence >= flushNeed or cancelCrafting
end
if not cancelCrafting then
cleanupCraftMachines(sortedStorages, myCleanup)
invalidateStockCache()
end
if totalCollected == 0 then invalidateStockCache(); return false end
end
end
ctx.active[node.idx] = nil
return true
end
function mergeCraftPlan(plan)
local merged   = {}
local idxByKey = {}
for _, step in ipairs(plan) do
local key
if step.fluid_craft then
key = (step.item or "?") .. "|F|" .. tostring(step.fluidRecipe)
else
local ings = step.ingredients and table.concat(step.ingredients, ",") or ""
key = (step.item or "?") .. "|" .. tostring(step.type) .. "|" ..
tostring(step.machine_name) .. "|" .. tostring(step.output_count or 1) ..
"|" .. tostring(step.output_device or "") .. "|" .. ings
end
local mi = idxByKey[key]
if mi then
local m = merged[mi]
m.count = (m.count or 0) + (step.count or 0)
if step.fluid_craft then
m.fluidAmount = (m.fluidAmount or 0) + (step.fluidAmount or 0)
end
else
merged[#merged + 1] = step
idxByKey[key] = #merged
end
end
return merged
end
function buildCraftDAG(plan)
local nodes = {}
local producerOf = {}
for idx, step in ipairs(plan) do
nodes[idx] = { idx = idx, step = step, deps = {}, tokens = stepTokens(step),
done = false, started = false }
if step.item then producerOf[step.item] = idx end
end
for idx, node in ipairs(nodes) do
local step = node.step
local seen = {}
local function addDep(ingName)
local p = producerOf[ingName]
if p and p ~= idx and not seen[p] then
seen[p] = true
node.deps[#node.deps + 1] = p
end
end
if step.fluid_craft then
for _, it in ipairs((step.fluidRecipe and step.fluidRecipe.item_inputs) or {}) do
addDep(it.name)
end
for _, inp in ipairs((step.fluidRecipe and step.fluidRecipe.inputs) or {}) do
addDep(inp.name)
end
elseif step.ingredients then
for _, ing in ipairs(step.ingredients) do
if ing and ing ~= "nil" then addDep(ing) end
end
end
if not (step.count and step.count > 0) then node.done = true end
end
return nodes
end
function claimReadyNode(ctx)
for _, node in ipairs(ctx.nodes) do
if not node.done and not node.started then
local ready = true
for _, d in ipairs(node.deps) do
if not ctx.nodes[d].done then ready = false; break end
end
if ready and tryAcquireTokens(node.tokens) then
node.started = true
return node
end
end
end
return nil
end
function drawParallelProgress(ctx)
if drawInterface then drawInterface() end
local w, h = monitor.getSize()
local pW = 46
local pH = 14
local pX = math.max(1, math.floor((w - pW) / 2) + 1)
local pY = math.max(1, math.floor((h - pH) / 2) + 1)
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdr = " MANUFACTURING ACTIVE "
drawText(pX + math.floor((pW - #hdr) / 2), pY, hdr, colors.black, colors.orange)
local activeList = {}
for _, a in pairs(ctx.active) do activeList[#activeList + 1] = a end
local sDone  = craftStageDone or 0
local sTotal = math.max(craftStageTotal or 0, sDone, 1)
local stepStr = string.format("Sub-task %d/%d", sDone, sTotal)
drawText(pX + 2, pY + 2, stepStr, colors.white, colors.gray)
local wStr = "[" .. #activeList .. "x parallel]"
drawText(pX + pW - #wStr - 2, pY + 2, wStr, colors.cyan, colors.gray)
local cleanFinal = (ctx.finalGoalItem:match(":(.+)$") or ctx.finalGoalItem):upper()
local itemStr = (">> " .. cleanFinal .. " <<"):sub(1, pW - 4)
drawText(pX + math.floor((pW - #itemStr) / 2), pY + 3, itemStr, colors.yellow, colors.gray)
local row = pY + 5
local shown = 0
for _, a in ipairs(activeList) do
if shown >= 5 then break end
local prog  = string.format("%d/%d", a.done or 0, a.total or 0)
local pre   = a.nest and "+" or (a.topup and string.char(7) or "-")
local pmStr = "pm" .. (a.machines or 0)
drawText(pX + 2, row, pre, colors.lightGray, colors.gray)
drawText(pX + 4, row, pmStr, colors.lightBlue, colors.gray)
local nameX   = pX + 4 + #pmStr + 1
local nameMax = math.max(1, (pX + pW - #prog - 2) - nameX)
drawText(nameX, row, tostring(a.desc):sub(1, nameMax), colors.lightGray, colors.gray)
drawText(pX + pW - #prog - 2, row, prog, colors.lime, colors.gray)
row = row + 1
shown = shown + 1
end
if #activeList == 0 then
drawText(pX + 2, row, "scheduling...", colors.lightGray, colors.gray)
end
local barWidth = math.min(28, pW - 14)
local barX = pX + math.floor((pW - barWidth) / 2)
drawProgressBar(barX, pY + pH - 3, barWidth, sDone, sTotal, colors.gray)
local cancelStr = " [ CANCEL ] "
local cbx = pX + math.floor((pW - #cancelStr) / 2)
local cby = pY + pH - 1
drawText(cbx, cby, cancelStr, colors.white, colors.red)
craftCancelY  = cby
craftCancelX1 = cbx
craftCancelX2 = cbx + #cancelStr - 1
_bufFlush()
end
function schedDone(ctx)
return ctx.failed or cancelCrafting or ctx.remaining <= 0
end
function runSequential(ctx)
for _, node in ipairs(ctx.nodes) do
if cancelCrafting then return false end
if not node.done then
while not cancelCrafting do
if tryAcquireTokens(node.tokens) then break end
sleepYield(0.2, ctx)
end
if cancelCrafting then releaseTokens(node.tokens); return false end
local ok, err = executeStep(node.step, ctx, node)
releaseTokens(node.tokens)
ctx.active[node.idx] = nil
if displayCtx and displayCtx ~= ctx then
displayCtx.active["NEST:" .. tostring(lockOwnerId())] = nil
end
if ok then
node.done = true
ctx.doneCount = ctx.doneCount + 1
if crossCraftDepth == 0 and not node.step.fluid_craft then craftStageDone = (craftStageDone or 0) + 1 end
else
if not cancelCrafting then ctx.failed = true; ctx.failErr = err end
return false
end
end
end
return true
end
runCraftingProcess = function(plan)
if #plan == 0 then return false end
if crossCraftDepth == 0 then
cancelCrafting = false; craftLocks = {}; craftUsedMachines = {}
fluidTankClaims = 0; _fluidStoreBusy = false; fluidInlineByCo = {}
end
if cancelCrafting then return false end
local sortedStorages = {}
for sName, enabled in pairs(Config.storages) do
if enabled then
local p = peripheral.wrap(sName)
if p and p.list and p.pullItems then sortedStorages[#sortedStorages + 1] = sName end
end
end
table.sort(sortedStorages)
local firstStorage = sortedStorages[1]
if not firstStorage then return false end
plan = mergeCraftPlan(plan)
local nodes = buildCraftDAG(plan)
local finalGoalItem = plan[#plan] and plan[#plan].item or ""
local remaining = 0
for _, n in ipairs(nodes) do if not n.done then remaining = remaining + 1 end end
local ctx = {
plan = plan, nodes = nodes, sortedStorages = sortedStorages,
firstStorage = firstStorage, finalGoalItem = finalGoalItem,
remaining = remaining, total = #nodes, doneCount = 0,
active = {}, failed = false, failErr = nil, done = false, fluidActive = false,
}
if remaining <= 0 then invalidateStockCache(); return true end
if crossCraftDepth > 0 then
local okSeq = runSequential(ctx)
invalidateStockCache()
if cancelCrafting then return false end
if ctx.failed then return false end
return okSeq
end
displayCtx = ctx
craftStageDone  = 0
craftStageTotal = estimatePlanStages(plan)
local distinct, nDistinct = {}, 0
for _, n in ipairs(nodes) do
for _, t in ipairs(n.tokens) do
if not distinct[t] then distinct[t] = true; nDistinct = nDistinct + 1 end
end
end
local K = math.min(math.max(1, nDistinct), 16)
local function worker()
while not ctx.done do
if schedDone(ctx) then ctx.done = true; return end
local node = claimReadyNode(ctx)
if not node then
local tmW = os.startTimer(0.2)
local evW, aW = os.pullEvent()
if not (evW == "timer" and aW == tmW) then os.cancelTimer(tmW) end
else
local ok, err = executeStep(node.step, ctx, node)
releaseTokens(node.tokens)
ctx.active[node.idx] = nil
if ok then
node.done = true
ctx.remaining = ctx.remaining - 1
ctx.doneCount = ctx.doneCount + 1
if not node.step.fluid_craft then craftStageDone = (craftStageDone or 0) + 1 end
else
node.done = true
ctx.remaining = ctx.remaining - 1
if not cancelCrafting then
ctx.failed = true
ctx.failErr = err
end
end
end
end
end
local function uiLoop()
while not ctx.done do
if schedDone(ctx) then ctx.done = true; return end
drawParallelProgress(ctx)
local tmU = os.startTimer(0.3)
local nEv = 0
while true do
local evU, aU = os.pullEvent()
if evU == "timer" and aU == tmU then break end
nEv = nEv + 1
if nEv >= 50 then os.cancelTimer(tmU); break end
if ctx.done then return end
end
end
end
local function cancelWatch()
while not ctx.done do
local timer = os.startTimer(0.3)
local deadline = os.clock() + 0.4
while true do
local ev, a, b, c = os.pullEvent()
if ev == "timer" and a == timer then break end
if ev == "monitor_touch" and craftCancelY and c == craftCancelY
and b >= craftCancelX1 and b <= craftCancelX2 then
cancelCrafting = true
end
if ctx.done then return end
if os.clock() >= deadline then os.cancelTimer(timer); break end
end
if schedDone(ctx) then ctx.done = true; return end
end
end
local tasks = {}
for _ = 1, K do tasks[#tasks + 1] = worker end
tasks[#tasks + 1] = uiLoop
tasks[#tasks + 1] = cancelWatch
parallel.waitForAll(table.unpack(tasks))
displayCtx = nil
sweepCraftMachines()
invalidateStockCache()
if cancelCrafting then return false end
if ctx.failed then return false end
return true
end
local function runMachineRecipeSearch()
if not Config.train_box or Config.train_box == "" then
return "ERR: Assign Train Box in NETWORK!"
end
local trainBox = peripheral.wrap(Config.train_box)
if not trainBox or not trainBox.getItemDetail then
return "ERR: Train box offline!"
end
local barrelCenterSlots = {4, 5, 6, 13, 14, 15, 22, 23, 24}
local ingredients = {}
local ingredientCounts = {}
local hasItems = false
local sampleItemName = "Unknown Item"
for i = 1, 9 do
local sourceSlot = barrelCenterSlots[i]
local success, item = pcall(function() return trainBox.getItemDetail(sourceSlot) end)
if success and item then
ingredients[i] = item.name
ingredientCounts[i] = item.count or 1
hasItems = true
sampleItemName = item.name
else
ingredients[i] = "nil"
ingredientCounts[i] = 0
end
end
if not hasItems then return "ERR: Grid empty!" end
learnedResult = nil
learnedOutputs = nil
learnedTools = {}
if selectedCraftType == "turtle" then
learnedIngredients = ingredients
else
local expandedIngredients = {}
for i = 1, 9 do
if ingredients[i] ~= "nil" then
local cnt = ingredientCounts[i] or 1
for _ = 1, cnt do
expandedIngredients[#expandedIngredients + 1] = ingredients[i]
end
end
end
if #expandedIngredients == 0 then expandedIngredients[1] = "nil" end
learnedIngredients = expandedIngredients
end
local function drawTestStage(stageDesc, currentProgress, maxProgress)
local w, h = monitor.getSize()
local pW = math.min(w - 6, 56)
local pH = 11
local pX = math.max(1, math.floor((w - pW) / 2) + 1)
local pY = math.max(1, math.floor((h - pH) / 2))
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdr = " RECIPE INTERACTIVE LEARNING "
drawText(pX + math.floor((pW - #hdr) / 2), pY, hdr, colors.black, colors.orange)
drawText(pX + 1, pY + 1, string.rep("-", pW - 2), colors.lightGray, colors.gray)
local sName = sampleItemName:match(":(.+)$") or sampleItemName
drawText(pX + 2, pY + 3, ("Testing: " .. sName):sub(1, pW - 4), colors.yellow, colors.gray)
drawText(pX + 2, pY + 5, ("STATUS: " .. stageDesc):sub(1, pW - 4), colors.lightGray, colors.gray)
if maxProgress and maxProgress > 0 then
drawProgressBar(pX + 2, pY + 7, pW - 10, currentProgress, maxProgress, colors.gray)
end
local cancStr = " [ CANCEL ] "
local cancX = pX + math.floor((pW - #cancStr) / 2)
drawText(cancX, pY + pH - 2, cancStr, colors.white, colors.red)
craftCancelY  = pY + pH - 2
craftCancelX1 = cancX
craftCancelX2 = cancX + #cancStr - 1
_bufFlush()
end
cancelCrafting = false
local function dumpToBarrel(p, pName)
if not p then return end
local ok, items = pcall(p.list)
if ok and items then
for slot, it in pairs(items) do
if it then
local moved = 0
if p.pushItems then
local o, m = pcall(p.pushItems, Config.train_box, slot, 64)
if o and type(m) == "number" then moved = m end
end
if moved <= 0 and pName then
pcall(trainBox.pullItems, pName, slot, 64)
end
end
end
end
end
if selectedCraftType == "turtle" then
local firstTurtle = nil
local tSorted = {}
for tName, enabled in pairs(Config.turtles or {}) do
if enabled then tSorted[#tSorted + 1] = tName end
end
table.sort(tSorted)
for _, tName in ipairs(tSorted) do
if peripheral.wrap(tName) then firstTurtle = tName; break end
end
if not firstTurtle then
if #tSorted > 0 then return "ERR: Turtle offline: " .. tSorted[1] end
return "ERR: Assign Turtle!"
end
learnedMachineName = firstTurtle
learnedCraftType = "turtle"
learnedOutputDevice = nil
drawTestStage("Clearing worker grid...", 1, 4)
local turtleSlots = {1, 2, 3, 5, 6, 7, 9, 10, 11}
for slot = 1, 16 do pcall(function() trainBox.pullItems(firstTurtle, slot, 64) end) end
drawTestStage("Pushing test ingredients...", 2, 4)
local pushedAny = false
for i = 1, 9 do
if ingredients[i] ~= "nil" then
local okP, mvP = pcall(function() return trainBox.pushItems(firstTurtle, barrelCenterSlots[i], 1, turtleSlots[i]) end)
if okP and type(mvP) == "number" and mvP > 0 then pushedAny = true end
end
end
if not pushedAny then
dumpToBarrel(peripheral.wrap(firstTurtle), firstTurtle)
return "ERR: Cannot push items to " .. firstTurtle
end
drawTestStage("Awaiting turtle processing...", 3, 4)
local learnCraftSlots = {[4]=true,[5]=true,[6]=true,[13]=true,[14]=true,[15]=true,[22]=true,[23]=true,[24]=true}
local learnSafeSlots = {}
for s = 1, 27 do if not learnCraftSlots[s] then table.insert(learnSafeSlots, s) end end
while true do
drawTestStage("Awaiting turtle (cancel to abort)...")
sleepCheckCancel(0.4)
if cancelCrafting then
for slot = 1, 16 do pcall(function() trainBox.pullItems(firstTurtle, slot, 64) end) end
craftCancelY = nil
learningState = "IDLE"
return "Learning cancelled."
end
local moved = 0
local targetSlot = nil
for _, bSlot in ipairs(learnSafeSlots) do
local ok, mv = pcall(function() return trainBox.pullItems(firstTurtle, 16, 64, bSlot) end)
if ok and mv and mv > 0 then
moved = mv
targetSlot = bSlot
break
end
end
if moved > 0 and targetSlot then
learnedResult = trainBox.getItemDetail(targetSlot)
break
end
end
for _, tslot in ipairs({1, 2, 3, 5, 6, 7, 9, 10, 11}) do
for _, bSlot in ipairs(learnSafeSlots) do
local okE, detE = pcall(function() return trainBox.getItemDetail(bSlot) end)
if not (okE and detE) then
local ok, mv = pcall(function() return trainBox.pullItems(firstTurtle, tslot, 64, bSlot) end)
if ok and mv and mv > 0 then
local okD, det = pcall(function() return trainBox.getItemDetail(bSlot) end)
if okD and det and det.name then learnedTools[det.name] = true end
end
break
end
end
end
drawTestStage("Analyzing output data...")
else
learnedMachineName = selectedCraftType
learnedCraftType = "machine"
learnedOutputDevice = nil
if selectedOutputDevice and selectedOutputDevice ~= selectedCraftType then
learnedOutputDevice = selectedOutputDevice
end
local machineObj = peripheral.wrap(learnedMachineName)
if not machineObj or not machineObj.list then return "ERR: Machine offline!" end
local outputObj = machineObj
if learnedOutputDevice then
local oo = peripheral.wrap(learnedOutputDevice)
if not oo or not oo.list then return "ERR: Output device offline!" end
outputObj = oo
end
drawTestStage("Scanning machine state...", 1, 3)
local learnExcluded = {}
local sPre, preItems = pcall(machineObj.list)
if sPre and preItems then
for _, preItem in pairs(preItems) do
if preItem then learnExcluded[preItem.name] = true end
end
end
if learnedOutputDevice then
local sPreO, preItemsO = pcall(outputObj.list)
if sPreO and preItemsO then
for _, preItem in pairs(preItemsO) do
if preItem then learnExcluded[preItem.name] = true end
end
end
end
local learnMachineSize = 9
if machineObj.size then
local okSz, sz = pcall(machineObj.size)
if okSz and type(sz) == "number" then learnMachineSize = sz end
end
for i = 1, 9 do
if ingredients[i] ~= "nil" then
learnExcluded[ingredients[i]] = true
local fromSlot = barrelCenterSlots[i]
local needCount = ingredientCounts[i] or 1
local pushed = false
if machineObj.pullItems then
for mSlot = learnMachineSize, 1, -1 do
local ok1, mv1 = pcall(machineObj.pullItems, Config.train_box, fromSlot, needCount, mSlot)
if ok1 and type(mv1) == "number" and mv1 > 0 then
pushed = true
break
end
end
end
if not pushed then
pcall(trainBox.pushItems, learnedMachineName, fromSlot, needCount)
end
end
end
local prevSig, stableCount = nil, 0
while true do
drawTestStage("Waiting for output (cancel to abort)...")
sleepCheckCancel(0.5)
if cancelCrafting then break end
local present = false
local sig = {}
local sList, mList = pcall(outputObj.list)
if sList and mList then
for _, mItem in pairs(mList) do
if mItem and not learnExcluded[mItem.name] then
present = true
sig[#sig + 1] = mItem.name .. "=" .. (mItem.count or 0)
end
end
end
if present then
table.sort(sig)
local s = table.concat(sig, ",")
if s == prevSig then stableCount = stableCount + 1 else stableCount = 0 end
prevSig = s
if stableCount >= 2 then break end
end
end
if cancelCrafting then
dumpToBarrel(machineObj, learnedMachineName)
if outputObj ~= machineObj then dumpToBarrel(outputObj, learnedOutputDevice) end
craftCancelY = nil
learningState = "IDLE"
return "Learning cancelled."
end
drawTestStage("Collecting outputs...")
local outAgg = {}
local sFin, mFin = pcall(outputObj.list)
if sFin and mFin then
local learnMCraftSlots = {[4]=true,[5]=true,[6]=true,[13]=true,[14]=true,[15]=true,[22]=true,[23]=true,[24]=true}
for slot, mItem in pairs(mFin) do
if mItem and not learnExcluded[mItem.name] then
outAgg[mItem.name] = (outAgg[mItem.name] or 0) + (mItem.count or 0)
for bSlot = 1, 27 do
if not learnMCraftSlots[bSlot] then
local ok2, mv2 = pcall(function() return outputObj.pushItems(Config.train_box, slot, mItem.count, bSlot) end)
if ok2 and mv2 and mv2 > 0 then break end
end
end
end
end
end
learnedOutputs = {}
for nm, cnt in pairs(outAgg) do learnedOutputs[#learnedOutputs + 1] = {name = nm, count = cnt} end
table.sort(learnedOutputs, function(a, b)
if a.count ~= b.count then return a.count > b.count end
return a.name < b.name
end)
if learnedOutputs[1] then
learnedResult = {name = learnedOutputs[1].name, count = learnedOutputs[1].count}
end
end
craftCancelY = nil
if learnedResult then
learningState = "AWAITING_DECISION"
local hItem = learnedResult.name
for hi = #craftHistory, 1, -1 do
if craftHistory[hi].item == hItem then table.remove(craftHistory, hi) end
end
table.insert(craftHistory, 1, {item = hItem, qty = learnedResult.count or 1})
if #craftHistory > 30 then table.remove(craftHistory) end
return "Success! Confirm entry."
else
learningState = "IDLE"
return "ERR: Process failed!"
end
end
local TRAINBOX_CRAFT_SLOTS = {[4]=true,[5]=true,[6]=true,[13]=true,[14]=true,[15]=true,[22]=true,[23]=true,[24]=true}
local TRAINBOX_SAFE_SLOTS  = {}
do for s = 1, 27 do if not TRAINBOX_CRAFT_SLOTS[s] then table.insert(TRAINBOX_SAFE_SLOTS, s) end end end
local function deliverToTrainBox(itemName, amount)
if not Config.train_box or Config.train_box == "" then return 0 end
local moved = 0
for _, targetSlot in ipairs(TRAINBOX_SAFE_SLOTS) do
if moved >= amount then break end
local got = pushFromStorage(itemName, amount - moved, Config.train_box, targetSlot)
moved = moved + got
end
return moved
end
local function pullAllFromTrainBox()
if not Config.train_box or Config.train_box == "" then return 0 end
local box = peripheral.wrap(Config.train_box)
if not box or not box.list or not box.pushItems then return 0 end
local sortedStorages = {}
for sName, enabled in pairs(Config.storages) do
if enabled then
local p = peripheral.wrap(sName)
if p and p.list and p.pullItems then table.insert(sortedStorages, sName) end
end
end
table.sort(sortedStorages)
if #sortedStorages == 0 then return 0 end
local totalMoved = 0
local ok, items = pcall(box.list)
if not ok or not items then return 0 end
for slot, item in pairs(items) do
if item then
local remaining = item.count
for _, stoName in ipairs(sortedStorages) do
if remaining <= 0 then break end
local mv_ok, mv = pcall(box.pushItems, stoName, slot, remaining)
if mv_ok and mv and mv > 0 then remaining = remaining - mv; totalMoved = totalMoved + mv end
end
end
end
return totalMoved
end
function userIsBusy()
if currentTab == "QUANTITY_PICKER" then return true end
if mgmtPopup or custGrpPopup or fluidRecipePicker or recipeEditPopup
or craftInfoPopup or machineInfoPopup or historyPopup or craftCompletePopup
or pendingDeleteItem or pendingDeleteFluid or outputPickMode
or gitExportMode or gitImportMode or fluidLearnStage or fluidCraftWaitFluid then
return true
end
return false
end
local function checkAndRunAutostock()
if Config.autostock_paused or systemStatus == "MANUAL_CRAFT" then return end
if userIsBusy() then return end
local stockInv = getStorageInventory()
local queue = {}
for itemName, settings in pairs(Autostock) do
table.insert(queue, {
name      = itemName,
threshold = settings.threshold or settings.limit or 1,
target    = settings.target or settings.limit or 1,
paused    = settings.paused,
order     = settings.order or 99999,
})
end
table.sort(queue, function(a, b)
if a.order ~= b.order then return a.order < b.order end
return a.name < b.name
end)
for _, settings in ipairs(queue) do
local itemName = settings.name
if settings.paused then
elseif itemName:sub(1, 2) == "f:" then
local fname = fluidNameFromKey(itemName)
local fprods = fluidProducers(fname)
if fprods[1] then
local fcur = (getFluidInventory())[itemName] or 0
if fcur < settings.threshold then
local fneed = settings.target - fcur
if fneed > 0 then
systemStatus = "AUTO_CRAFT"
autostockCurrentItem = itemName
uiMessage = "Autostock fluid: " .. (fname:match(":(.+)$") or fname)
craftLocks = {}; fluidTankClaims = 0; _fluidStoreBusy = false; fluidInlineByCo = {}
pcall(function() produceFluid(fprods[1].recipe, fname, fneed) end)
systemStatus = "IDLE"
autostockCurrentItem = ""
if checkTimer then os.cancelTimer(checkTimer) end
checkTimer = os.startTimer(2)
if cancelCrafting then return end
stockInv = getStorageInventory()
end
end
end
elseif Recipes[itemName] then
local currentCount = stockInv[itemName] or 0
if currentCount < settings.threshold then
local needed = settings.target - currentCount
local plan, planMiss = nil, nil
if needed > 0 then
plan, planMiss = planProduction(itemName, needed, false)
end
local isPartial = false
if needed > 0 and (not plan or #plan == 0 or (planMiss and next(planMiss))) then
plan = nil
local partialPlan = planProduction(itemName, needed, true)
if partialPlan and #partialPlan > 0 then
plan = partialPlan
isPartial = true
end
end
if plan and #plan > 0 then
systemStatus = "AUTO_CRAFT"
autostockCurrentItem = itemName
local shortName = itemName:match(":(.+)$") or itemName
if isPartial then
uiMessage = "Partial autostock: " .. shortName
else
uiMessage = "Autostocking " .. shortName
end
local ok = false
local craftOk, craftErr = pcall(function()
ok = runCraftingProcess(plan)
local kAttempts = 0
while not cancelCrafting and kAttempts < 12 do
local totalNow = groupAvailable(itemName, getStorageInventory())
if totalNow >= settings.target then break end
kAttempts = kAttempts + 1
invalidateStockCache()
local rPlan = planProduction(itemName, settings.target, true)
if not (rPlan and #rPlan > 0) then break end
local beforeK = totalNow
runCraftingProcess(rPlan)
if groupAvailable(itemName, getStorageInventory()) <= beforeK then break end
end
end)
systemStatus = "IDLE"
autostockCurrentItem = ""
if checkTimer then os.cancelTimer(checkTimer) end
checkTimer = os.startTimer(2)
if not craftOk then
uiMessage = "ERR: KEEP crashed: " .. tostring(craftErr):sub(1, 40)
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(5)
elseif not ok then
uiMessage = "ERR: KEEP failed for " .. shortName
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(4)
else
uiMessage = "KEEP done: " .. shortName
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(3)
end
if cancelCrafting then return end
stockInv = getStorageInventory()
end
end
end
end
end
local function getRegisteredMods()
local mods = { "All" }
local seen = { All = true }
for itemName in pairs(Recipes) do
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
local function mgmtMoveSlot(srcName, srcSlot, destName, amount)
local srcP = peripheral.wrap(srcName)
if srcP and srcP.pushItems then
local ok, mv = pcall(srcP.pushItems, destName, srcSlot, amount)
if ok and mv and mv > 0 then return mv end
end
local dstP = peripheral.wrap(destName)
if dstP and dstP.pullItems then
local ok2, mv2 = pcall(dstP.pullItems, srcName, srcSlot, amount)
if ok2 and mv2 and mv2 > 0 then return mv2 end
end
return 0
end
local function mgmtIsFluidPeriph(name)
if not name or name == "" or name == "STORAGE" then return false end
if Config.fluid_tanks and Config.fluid_tanks[name] then return true end
local w = peripheral.wrap(name)
if w and w.tanks and not w.list then return true end
return false
end
local function mgmtGroupIsFluid(g)
if g.fluid ~= nil then return g.fluid end
return mgmtIsFluidPeriph(g.input) or mgmtIsFluidPeriph(g.output)
end
local function mgmtMoveFluid(srcName, destName, fluidName, amount)
if not amount or amount <= 0 then return 0 end
local srcP = peripheral.wrap(srcName)
if srcP and srcP.pushFluid then
local ok, mv = pcall(srcP.pushFluid, destName, amount, fluidName)
if ok and type(mv) == "number" and mv > 0 then return mv end
end
local dstP = peripheral.wrap(destName)
if dstP and dstP.pullFluid then
local ok2, mv2 = pcall(dstP.pullFluid, srcName, amount, fluidName)
if ok2 and type(mv2) == "number" and mv2 > 0 then return mv2 end
end
return 0
end
local function mgmtFluidStockSnap()
local snap = {}
for k, v in pairs(getFluidInventory()) do
snap[fluidNameFromKey(k)] = v
end
return snap
end
local function runMgmtFluidGroup(group)
local moved = 0
local inputIsStg  = (not group.input  or group.input  == "" or group.input  == "STORAGE")
local outputIsStg = (not group.output or group.output == "" or group.output == "STORAGE")
if inputIsStg and outputIsStg then return 0 end
local fsnap = mgmtFluidStockSnap()
local netTanks = fluidTankList()
if group.drain and not inputIsStg then
for fname, amt in pairs(tankContents(group.input)) do
local toMove = amt
if outputIsStg then
for _, tname in ipairs(netTanks) do
if toMove <= 0 then break end
if tname ~= group.input then
local mv = mgmtMoveFluid(group.input, tname, fname, toMove)
if mv > 0 then toMove = toMove - mv; moved = moved + mv end
end
end
else
local mv = mgmtMoveFluid(group.input, group.output, fname, toMove)
if mv > 0 then moved = moved + mv end
end
end
end
for _, rule in ipairs(group.rules or {}) do
local curInOutput = 0
if outputIsStg then
curInOutput = fsnap[rule.item] or 0
else
curInOutput = (tankContents(group.output))[rule.item] or 0
end
local condOk = true
if rule.condition and rule.condition.item and rule.condition.item ~= "" then
local condCount = fsnap[rule.condition.item] or 0
local condVal   = rule.condition.value or 1
local condOp    = rule.condition.op or "<"
if condOp == "<" then condOk = condCount < condVal
elseif condOp == ">" then condOk = condCount > condVal
elseif condOp == "=" then condOk = condCount == condVal
end
end
if condOk and curInOutput < rule.amount then
local needed = rule.amount - curInOutput
if inputIsStg then
for _, src in ipairs(tanksWithFluid(rule.item)) do
if needed <= 0 then break end
if src.periph ~= group.output then
local mv = mgmtMoveFluid(src.periph, group.output, rule.item, needed)
if mv > 0 then
needed = needed - mv
moved  = moved + mv
fsnap[rule.item] = math.max(0, (fsnap[rule.item] or 0) - mv)
end
end
end
elseif outputIsStg then
for _, tname in ipairs(netTanks) do
if needed <= 0 then break end
if tname ~= group.input then
local mv = mgmtMoveFluid(group.input, tname, rule.item, needed)
if mv > 0 then
needed = needed - mv
moved  = moved + mv
fsnap[rule.item] = (fsnap[rule.item] or 0) + mv
end
end
end
else
local mv = mgmtMoveFluid(group.input, group.output, rule.item, needed)
if mv > 0 then needed = needed - mv; moved = moved + mv end
end
end
end
return moved
end
function mgmtIOList(group, isInput)
local lst = isInput and group.inputs or group.outputs
if type(lst) == "table" and #lst > 0 then return lst end
local s = isInput and group.input or group.output
if not s or s == "" or s == "STORAGE" then return { "STORAGE" } end
return { s }
end
function mgmtListIsStorage(lst)
return (#lst == 0) or (lst[1] == "STORAGE")
end
function mgmtIODisplay(group, isInput)
local lst = mgmtIOList(group, isInput)
if mgmtListIsStorage(lst) then return "STORAGE" end
local d = getMachineDisplay(lst[1]) or lst[1]
if #lst > 1 then d = d .. " +" .. (#lst - 1) end
return d
end
function mgmtCountItem(srcNames, itemName)
local total = 0
for _, nm in ipairs(srcNames) do
local p = peripheral.wrap(nm)
if p and p.list then
local ok, items = pcall(p.list)
if ok and items then
for _, si in pairs(items) do
if si and si.name == itemName then total = total + si.count end
end
end
end
end
return total
end
function mgmtMoveFromDev(srcName, dest, itemName, amount, storageList)
if amount <= 0 then return 0 end
local p = peripheral.wrap(srcName)
if not (p and p.list) then return 0 end
local ok, items = pcall(p.list)
if not (ok and items) then return 0 end
local moved = 0
for sl, si in pairs(items) do
if moved >= amount then break end
if si and si.name == itemName then
local want = math.min(amount - moved, si.count)
if dest == "STORAGE" then
for _, sn in ipairs(storageList) do
if want <= 0 then break end
local mv = mgmtMoveSlot(srcName, sl, sn, want)
if mv > 0 then moved = moved + mv; want = want - mv end
end
else
local mv = mgmtMoveSlot(srcName, sl, dest, want)
if mv > 0 then moved = moved + mv end
end
end
end
return moved
end
function mgmtDrawEven(inputs, dest, itemName, amount, storageList, rr)
local moved = 0
local n = #inputs
if n == 0 or amount <= 0 then return 0 end
while moved < amount do
local cycleMoved = 0
local chunk = math.max(1, math.ceil((amount - moved) / n))
for _ = 1, n do
if moved >= amount then break end
rr.i = (rr.i % n) + 1
local mv = mgmtMoveFromDev(inputs[rr.i], dest, itemName,
math.min(amount - moved, chunk), storageList)
if mv > 0 then moved = moved + mv; cycleMoved = cycleMoved + mv end
end
if cycleMoved == 0 then break end
end
return moved
end
function runMgmtItemGroup(group, stockSnap, storageList)
local moved   = 0
local inputs  = mgmtIOList(group, true)
local outputs = mgmtIOList(group, false)
local inStg   = mgmtListIsStorage(inputs)
local outStg  = mgmtListIsStorage(outputs)
if inStg and outStg then return 0 end
local srcSet = inStg and storageList or inputs
if group.drain and not inStg then
local rr = { i = 0 }
for _, nm in ipairs(inputs) do
local p = peripheral.wrap(nm)
if p and p.list then
local okD, slots = pcall(p.list)
if okD and slots then
for sl, si in pairs(slots) do
if si and si.count > 0 then
local toMove = si.count
if outStg then
for _, sn in ipairs(storageList) do
if toMove <= 0 then break end
local mv = mgmtMoveSlot(nm, sl, sn, toMove)
if mv > 0 then
toMove = toMove - mv; moved = moved + mv
stockSnap[si.name] = (stockSnap[si.name] or 0) + mv
end
end
else
local cnt = #outputs
while toMove > 0 do
local before = toMove
for _ = 1, cnt do
if toMove <= 0 then break end
rr.i = (rr.i % cnt) + 1
local mv = mgmtMoveSlot(nm, sl, outputs[rr.i], toMove)
if mv > 0 then toMove = toMove - mv; moved = moved + mv end
end
if toMove == before then break end
end
end
end
end
end
end
end
end
for _, rule in ipairs(group.rules or {}) do
local condOk = true
if rule.condition and rule.condition.item and rule.condition.item ~= "" then
local condCount = stockSnap[rule.condition.item] or 0
local condVal   = rule.condition.value or 1
local condOp    = rule.condition.op or "<"
if condOp == "<" then condOk = condCount < condVal
elseif condOp == ">" then condOk = condCount > condVal
elseif condOp == "=" then condOk = condCount == condVal end
end
if condOk then
local targets = {}
if outStg then
local cur = stockSnap[rule.item] or 0
targets[1] = { dest = "STORAGE", cur = cur, def = math.max(0, rule.amount - cur) }
else
for _, oN in ipairs(outputs) do
local cur = mgmtCountItem({ oN }, rule.item)
targets[#targets + 1] = { dest = oN, cur = cur, def = math.max(0, rule.amount - cur) }
end
end
local sumDef = 0
for _, t in ipairs(targets) do sumDef = sumDef + t.def end
if sumDef > 0 then
local avail  = inStg and (stockSnap[rule.item] or 0) or mgmtCountItem(inputs, rule.item)
local toDist = math.min(avail, sumDef)
for _ = 1, toDist do
local pick, lvl
for ti, t in ipairs(targets) do
if t.def > 0 and (not pick or t.cur < lvl) then pick = ti; lvl = t.cur end
end
if not pick then break end
targets[pick].cur   = targets[pick].cur + 1
targets[pick].def   = targets[pick].def - 1
targets[pick].alloc = (targets[pick].alloc or 0) + 1
end
local rr = { i = 0 }
for _, t in ipairs(targets) do
local alloc = t.alloc or 0
if alloc > 0 then
local mv = mgmtDrawEven(srcSet, t.dest, rule.item, alloc, storageList, rr)
if mv > 0 then
moved = moved + mv
if inStg and not outStg then
stockSnap[rule.item] = math.max(0, (stockSnap[rule.item] or 0) - mv)
elseif outStg and not inStg then
stockSnap[rule.item] = (stockSnap[rule.item] or 0) + mv
end
end
end
end
end
end
end
return moved
end
local function runMgmtTransfers()
local totalMoved = 0
if systemStatus ~= "IDLE" then
mgmtSyncInfo = "paused (craft)"
return totalMoved
end
if #MgmtGroups == 0 then
mgmtSyncInfo = "no groups"
return totalMoved
end
local stockSnap = getStorageInventory()
local storageList = {}
for sName, isEnabled in pairs(Config.storages) do
if isEnabled and not SYSTEM_SIDES[sName] then
table.insert(storageList, sName)
end
end
if #storageList == 0 then
mgmtSyncInfo = "no storage"
return totalMoved
end
for _, group in ipairs(MgmtGroups) do
if systemStatus ~= "IDLE" then break end
if group.paused then goto mgmt_continue end
if group.provider then goto mgmt_continue end
if mgmtGroupIsFluid(group) then
totalMoved = totalMoved + runMgmtFluidGroup(group)
goto mgmt_continue
end
totalMoved = totalMoved + runMgmtItemGroup(group, stockSnap, storageList)
::mgmt_continue::
end
if totalMoved > 0 then
mgmtSyncInfo = "moved: " .. totalMoved
invalidateStockCache()
else
mgmtSyncInfo = "ok (0 moved)"
end
return totalMoved
end
local function drawTabButton(x, y, name, activeTab, zones)
if name == activeTab then
drawText(x, y, " " .. name .. " ", colors.white, colors.gray)
drawText(x, y + 1, string.rep("-", #name + 2), colors.lime, colors.black)
else
drawText(x, y, " " .. name .. " ", colors.gray, colors.black)
end
table.insert(zones, {id="switch_tab", arg=name, x1=x, x2=x + #name + 1, y=y})
return x + #name + 3
end
local function drawMgmtCondRow(pX, pW, ruleRowY, rule, ri2, touchZones)
local cond = rule.condition
_bufFillRect(pX + 1, ruleRowY, pW - 2, 1, colors.lightGray)
if cond and cond.item and cond.item ~= "" then
local cItem  = cond.item:match(":(.+)$") or cond.item
local opStr  = "[" .. (cond.op or "<") .. "]"
local cVal   = tostring(cond.value or 1)
local ifDelX  = pX + pW - 7
local ifTypX  = ifDelX - 5
local ifPlusX = ifTypX - 5
local ifValX  = ifPlusX - #cVal
local ifMinX  = ifValX - 5
local ifOpX   = ifMinX - #opStr - 2
local ifNameX = pX + 5
drawText(pX + 2,  ruleRowY, "IF ",  colors.orange,    colors.lightGray)
drawText(ifNameX, ruleRowY, cItem:sub(1, math.max(0, ifOpX - ifNameX)), colors.lime, colors.lightGray)
drawText(ifOpX,   ruleRowY, " " .. opStr .. " ",  colors.black,  colors.yellow)
drawText(ifMinX,  ruleRowY, " [-] ",  colors.white,  colors.lightGray)
drawText(ifValX,  ruleRowY, cVal,   colors.yellow, colors.lightGray)
drawText(ifPlusX, ruleRowY, " [+] ", colors.white,  colors.lightGray)
drawText(ifTypX,  ruleRowY, " [#] ",  colors.black,  colors.orange)
drawText(ifDelX,  ruleRowY, " [X] ",  colors.white,  colors.red)
table.insert(touchZones, {id="mgmt_rule_if_item", arg=ri2,      x1=ifNameX, x2=ifOpX-1, y=ruleRowY})
table.insert(touchZones, {id="mgmt_rule_if_op",   arg=ri2,      x1=ifOpX, x2=ifOpX+#opStr+1, y=ruleRowY})
table.insert(touchZones, {id="mgmt_rule_if_adj",  arg={ri2,-1}, x1=ifMinX, x2=ifMinX+4, y=ruleRowY})
table.insert(touchZones, {id="mgmt_rule_if_adj",  arg={ri2, 1}, x1=ifPlusX, x2=ifPlusX+4, y=ruleRowY})
table.insert(touchZones, {id="mgmt_rule_if_type", arg=ri2,      x1=ifTypX, x2=ifTypX+4, y=ruleRowY})
table.insert(touchZones, {id="mgmt_rule_if_del",  arg=ri2,      x1=ifDelX, x2=ifDelX+4, y=ruleRowY})
else
local addIfS = "[+IF]"
drawText(pX + 2, ruleRowY, addIfS, colors.gray, colors.lightGray)
drawText(pX + 2 + #addIfS + 1, ruleRowY, "add condition", colors.gray, colors.lightGray)
table.insert(touchZones, {id="mgmt_rule_if_add", arg=ri2, x1=pX+2, x2=pX+2+#addIfS-1, y=ruleRowY})
end
end
function _diB1(w, h, touchZones, popupRect)
local newGrpS = " [+ NEW GROUP] "
drawText(2, 9, "MACHINE GROUPS:", colors.white)
drawText(w - #newGrpS + 1, 9, newGrpS, colors.black, colors.lime)
table.insert(touchZones, {id="cgrp_new", x1=w-#newGrpS+1, x2=w, y=9})
drawText(2, 10, "Excluded machines use only their own recipe.", colors.gray)
drawText(1, 11, string.rep("-", w), colors.gray)
local all = getAvailableMachines()
local baseMap = {}
for _, m in ipairs(all) do
local base = getMachineBaseName(m)
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
local turtleListG = {}
for tName, enabled in pairs(Config.turtles or {}) do
if enabled then table.insert(turtleListG, tName) end
end
table.sort(turtleListG)
if #turtleListG > 0 then
table.insert(rows, {type="header", base="TURTLE GROUP", total=#turtleListG, excluded=0, isTurtle=true})
for _, tName in ipairs(turtleListG) do
local isOnline = peripheral.wrap(tName) ~= nil
table.insert(rows, {type="turtle_entry", name=tName, offline=not isOnline})
end
end
local unassignedTurtles = {}
for _, p in ipairs(peripheral.getNames()) do
if not SYSTEM_SIDES[p] and p ~= MONITOR_SIDE and p ~= Config.train_box
and not (Config.turtles and Config.turtles[p]) and not Config.storages[p] then
local tp = peripheral.wrap(p)
if tp and tp.craft then table.insert(unassignedTurtles, p) end
end
end
table.sort(unassignedTurtles)
if #unassignedTurtles > 0 then
table.insert(rows, {type="header", base="NEW TURTLES", total=#unassignedTurtles, excluded=0, isTurtle=true})
for _, tName in ipairs(unassignedTurtles) do
table.insert(rows, {type="turtle_new", name=tName})
end
end
local sortedBases = {}
for base in pairs(baseMap) do table.insert(sortedBases, base) end
table.sort(sortedBases)
for _, base in ipairs(sortedBases) do
local machines = baseMap[base]
table.sort(machines)
if #machines > 1 then
local excCount = 0
for _, m in ipairs(machines) do if ExcludedMachines[m] then excCount = excCount + 1 end end
table.insert(rows, {type="header", base=base, total=#machines, excluded=excCount, isTurtle=false})
for _, m in ipairs(machines) do
table.insert(rows, {type="machine", name=m, isExcluded=ExcludedMachines[m] == true})
end
end
end
if #rows == 0 then
drawText(2, 13, "No multi-machine groups detected.", colors.gray)
drawText(2, 14, "Connect machines with matching names", colors.gray)
drawText(2, 15, "(e.g. furnace_0, furnace_1, ...)", colors.gray)
else
local startRowY = 12
local itemsPerPage = h - startRowY - 2
local totalPages = math.max(1, math.ceil(#rows / itemsPerPage))
if currentPage > totalPages then currentPage = totalPages end
local startIdx = ((currentPage - 1) * itemsPerPage) + 1
local endIdx   = math.min(startIdx + itemsPerPage - 1, #rows)
local rowY = startRowY
for idx = startIdx, endIdx do
local row = rows[idx]
if row.type == "custom_header" then
local editS = " [EDIT] "; local delS = " [DEL] "
local delX2  = w - #delS + 1
local editX2 = delX2 - #editS - 1
local hdr2 = string.format(" [%s]  %d machines", row.name, row.count)
drawText(1, rowY, string.rep(" ", w), colors.gray, colors.gray)
drawText(2, rowY, hdr2:sub(1, editX2 - 3), colors.orange, colors.gray)
drawText(editX2, rowY, editS, colors.white, colors.gray)
drawText(delX2,  rowY, delS,  colors.white, colors.red)
table.insert(touchZones, {id="cgrp_edit", arg=row.idx, x1=editX2, x2=editX2+#editS-1, y=rowY})
table.insert(touchZones, {id="cgrp_del",  arg=row.idx, x1=delX2,  x2=delX2+#delS-1,  y=rowY})
elseif row.type == "custom_machine" then
_bufClearLine(rowY, colors.black)
local remS = " [REMOVE] "
drawText(4, rowY, getMachineDisplay(row.name):sub(1, w - 4 - #remS), colors.yellow, colors.black)
drawText(w - #remS + 1, rowY, remS, colors.white, colors.gray)
table.insert(touchZones, {id="cgrp_remove", arg={row.groupIdx, row.name}, x1=w-#remS+1, x2=w, y=rowY})
elseif row.type == "header" then
local countLabel = row.isTurtle and "turtles" or "machines"
local hdr = string.format(" [%s]  %d %s", row.base, row.total, countLabel)
if row.excluded > 0 then hdr = hdr .. string.format("  (%d excluded)", row.excluded) end
local hdrColor = row.isTurtle and colors.cyan or colors.lime
drawText(1, rowY, string.rep(" ", w), colors.gray, colors.gray)
drawText(2, rowY, hdr, hdrColor, colors.gray)
elseif row.type == "turtle_entry" then
_bufClearLine(rowY, colors.black)
if row.offline then
drawText(4, rowY, row.name, colors.red, colors.black)
drawText(w - 19, rowY, "[OFFLINE]", colors.red, colors.black)
drawText(w - 9, rowY, " [REMOVE] ", colors.white, colors.gray)
table.insert(touchZones, {id="turtle_remove", arg=row.name, x1=w-9, x2=w-1, y=rowY})
else
drawText(4, rowY, row.name, colors.cyan, colors.black)
drawText(w - 14, rowY, "[parallel craft]", colors.gray, colors.black)
end
elseif row.type == "turtle_new" then
_bufClearLine(rowY, colors.black)
drawText(4, rowY, row.name, colors.orange, colors.black)
drawText(w - 8, rowY, " [+ADD] ", colors.black, colors.orange)
table.insert(touchZones, {id="turtle_add", arg=row.name, x1=w-8, x2=w-1, y=rowY})
else
local isExc = row.isExcluded
local rowBg = isExc and colors.black or colors.black
_bufClearLine(rowY, rowBg)
local nameColor = isExc and colors.gray or colors.white
drawText(4, rowY, getMachineDisplay(row.name), nameColor, rowBg)
if isExc then
drawText(w - 12, rowY, "[EXCLUDED]", colors.red, rowBg)
drawText(w - 21, rowY, " [INCLUDE] ", colors.white, colors.lime)
table.insert(touchZones, {id="group_include", arg=row.name, x1=w-21, x2=w-11, y=rowY})
else
drawText(w - 11, rowY, " [EXCLUDE] ", colors.white, colors.gray)
table.insert(touchZones, {id="group_exclude", arg=row.name, x1=w-11, x2=w-1, y=rowY})
end
end
rowY = rowY + 1
end
do
local navY = h - 1
drawText(1, navY - 1, string.rep("-", w), colors.gray)
local pageStr = string.format(" PAGE %d OF %d ", currentPage, math.max(1, totalPages))
local prevStr = " [ PREV ] "; local nextStr = " [ NEXT ] "
local navStartX = math.floor((w - (#prevStr + #pageStr + #nextStr + 4)) / 2)
drawText(navStartX, navY, prevStr, currentPage > 1 and colors.white or colors.lightGray, colors.gray)
drawText(navStartX + #prevStr + 2, navY, pageStr, colors.lime, colors.black)
local nextXPos = navStartX + #prevStr + #pageStr + 4
drawText(nextXPos, navY, nextStr, currentPage < totalPages and colors.white or colors.lightGray, colors.gray)
if currentPage > 1 then
table.insert(touchZones, {id="prev_page", x1=navStartX, x2=navStartX + #prevStr - 1, y=navY})
end
if currentPage < totalPages then
table.insert(touchZones, {id="next_page", x1=nextXPos, x2=nextXPos + #nextStr - 1, y=navY})
end
end
end
if custGrpPopup then
local pW = math.min(w - 4, 88)
local pX = math.floor((w - pW) / 2) + 1
local allM = getAvailableMachines()
table.sort(allM, function(a, b) return getMachineDisplay(a):lower() < getMachineDisplay(b):lower() end)
local rowsN = math.max(3, h - 10)
local pH = math.min(rowsN + 6, h - 2)
rowsN = pH - 6
local perPage = rowsN * 3
local cpPage = custGrpPopup.page or 1
local cpTotal = math.max(1, math.ceil(#allM / perPage))
if cpPage > cpTotal then cpPage = cpTotal; custGrpPopup.page = cpPage end
local pY = math.floor((h - pH) / 2) + 1
popupRect = {x1=pX, x2=pX+pW-1, y1=pY, y2=pY+pH-1}
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdrTxt = custGrpPopup.editIdx and " EDIT CUSTOM GROUP " or " NEW CUSTOM GROUP "
drawText(pX + math.floor((pW - #hdrTxt) / 2), pY, hdrTxt, colors.black, colors.cyan)
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
local colW = math.floor((pW - 2) / 3)
local mStartIdx = (cpPage - 1) * perPage + 1
local mEndIdx   = math.min(mStartIdx + perPage - 1, #allM)
for rowI = 0, rowsN - 1 do
if mStartIdx + rowI <= mEndIdx then
drawText(pX + colW, pY + 4 + rowI, "|", colors.lightGray, colors.gray)
drawText(pX + 2 * colW, pY + 4 + rowI, "|", colors.lightGray, colors.gray)
end
end
for mi = mStartIdx, mEndIdx do
local idx0  = mi - mStartIdx
local colI  = math.floor(idx0 / rowsN)
local rowI  = idx0 % rowsN
local cellX = pX + 1 + colI * colW
local mRowY = pY + 4 + rowI
local mName2 = allM[mi]
local isSel  = custGrpPopup.selected[mName2] == true
local chk    = isSel and "[x]" or "[ ]"
local chkFg  = isSel and colors.lime or colors.white
local mDisp2 = getMachineDisplay(mName2)
drawText(cellX, mRowY, (chk .. " " .. mDisp2):sub(1, colW - 2), chkFg, colors.gray)
table.insert(touchZones, {id="cgrp_popup_toggle", arg=mName2, x1=cellX, x2=cellX + colW - 2, y=mRowY})
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
function _diB2(w, h, touchZones)
if learningState == "IDLE" then
local isTurtleTab = (craftSubTab == "TURTLE")
local isMachineTab = (craftSubTab == "MACHINES")
local isFluidLearnTab = (craftSubTab == "FLUID")
local tStr = " [ TURTLE ] "
local mStr = " [ MACHINES ] "
local lStr = " [ FLUID ] "
local tabsTotal = #tStr + 2 + #mStr + 2 + #lStr
local tabsX = math.floor((w - tabsTotal) / 2) + 1
local tX = tabsX
local mX = tabsX + #tStr + 2
local lX = mX + #mStr + 2
drawText(tX, 9, tStr, isTurtleTab and colors.white or colors.gray, isTurtleTab and colors.gray or colors.black)
if isTurtleTab then drawText(tX, 10, string.rep("-", #tStr), colors.lime, colors.black) end
table.insert(touchZones, {id="craft_subtab", arg="TURTLE", x1=tX, x2=tX+#tStr-1, y=9})
drawText(mX, 9, mStr, isMachineTab and colors.white or colors.gray, isMachineTab and colors.gray or colors.black)
if isMachineTab then drawText(mX, 10, string.rep("-", #mStr), colors.lime, colors.black) end
table.insert(touchZones, {id="craft_subtab", arg="MACHINES", x1=mX, x2=mX+#mStr-1, y=9})
drawText(lX, 9, lStr, isFluidLearnTab and colors.white or colors.gray, isFluidLearnTab and colors.gray or colors.black)
if isFluidLearnTab then drawText(lX, 10, string.rep("-", #lStr), colors.lime, colors.black) end
table.insert(touchZones, {id="craft_subtab", arg="FLUID", x1=lX, x2=lX+#lStr-1, y=9})
drawText(1, 11, string.rep("-", w), colors.gray)
if isFluidLearnTab then
if not fluidLearnStage then fluidLearnStage = "PICK_INPUT" end
drawFluidLearnUI(w, h, touchZones)
elseif isTurtleTab then
local d1 = "Place recipe in center 3x3 of barrel,"
local d2 = "then press SCAN."
drawText(math.floor((w - #d1) / 2) + 1, 13, d1, colors.gray)
drawText(math.floor((w - #d2) / 2) + 1, 14, d2, colors.lightGray)
else
local machines = getAvailableMachines()
table.sort(machines, function(a, b)
return (getMachineDisplay(a) or a):lower() < (getMachineDisplay(b) or b):lower()
end)
local listY = 13
local cols = 3
local maxRows = h - listY - 4
local machPerPage = cols * maxRows
local totalMachPages = math.max(1, math.ceil(#machines / machPerPage))
if craftDevicePage > totalMachPages then craftDevicePage = totalMachPages end
local mStart = ((craftDevicePage - 1) * machPerPage) + 1
local mEnd   = math.min(mStart + machPerPage - 1, #machines)
local colWidth = math.floor(w / cols)
if #machines == 0 then
local noM = "No machines connected."
drawText(math.floor((w - #noM) / 2) + 1, listY, noM, colors.gray)
else
local sep1X = colWidth
local sep2X = 2 * colWidth
for ry = 0, maxRows - 1 do
drawText(sep1X, listY + ry, "|", colors.gray, colors.black)
drawText(sep2X, listY + ry, "|", colors.gray, colors.black)
end
for mIdx = mStart, mEnd do
local localIdx = mIdx - mStart
local col = math.floor(localIdx / maxRows)
local row = localIdx % maxRows
local rowY = listY + row
local colX = col * colWidth + 1
local m = machines[mIdx]
local mDisplay = getMachineDisplay(m)
local isSel = (selectedCraftType == m)
local isOut = (selectedOutputDevice == m and m ~= selectedCraftType)
if isOut then
local nm = mDisplay
local maxName = colWidth - 5
if #nm > maxName then nm = nm:sub(1, maxName) end
drawText(colX, rowY, "--", colors.lime, colors.gray)
drawText(colX + 2, rowY, nm, colors.white, colors.gray)
drawText(colX + 2 + #nm, rowY, "--", colors.lime, colors.gray)
else
local mBg = isSel and colors.gray or colors.black
local mLabel = (isSel and "> " or "  ") .. mDisplay
local maxLabel = colWidth - 1
if #mLabel > maxLabel then mLabel = mLabel:sub(1, maxLabel) end
drawText(colX, rowY, mLabel, isSel and colors.white or colors.lightGray, mBg)
end
table.insert(touchZones, {id="select_device", arg=m, x1=colX, x2=colX+colWidth-1, y=rowY})
end
if totalMachPages > 1 then
local navY = h - 3
local prevS = "[PREV]"; local nextS = "[NEXT]"
local pgS = string.format(" %d/%d ", craftDevicePage, totalMachPages)
local navW = #prevS + #pgS + #nextS + 2
local navX = math.floor((w - navW) / 2) + 1
drawText(navX, navY, prevS, craftDevicePage > 1 and colors.white or colors.gray, colors.gray)
table.insert(touchZones, {id="craft_dev_prev", x1=navX, x2=navX+#prevS-1, y=navY})
drawText(navX + #prevS + 1, navY, pgS, colors.lime)
local nxtX = navX + #prevS + #pgS + 2
drawText(nxtX, navY, nextS, craftDevicePage < totalMachPages and colors.white or colors.gray, colors.gray)
table.insert(touchZones, {id="craft_dev_next", x1=nxtX, x2=nxtX+#nextS-1, y=navY})
end
end
end
if isMachineTab and selectedCraftType ~= "turtle" then
local outY = h - 2
local isSplit = (selectedOutputDevice ~= nil and selectedOutputDevice ~= selectedCraftType)
local splitS = " [ PULL ] "
local sX = math.floor((w - #splitS) / 2) + 1
local fg, bg
if outputPickMode then
fg, bg = colors.black, colors.yellow
elseif isSplit then
fg, bg = colors.black, colors.lime
else
fg, bg = colors.white, colors.gray
end
drawText(sX, outY, splitS, fg, bg)
table.insert(touchZones, {id="craft_out_change", x1=sX, x2=sX+#splitS-1, y=outY})
end
if not isFluidLearnTab then
local scanStr = " [ SCAN ] "
local scanX = math.floor((w - #scanStr) / 2) + 1
local btnY = h - 1
drawText(scanX, btnY, scanStr, colors.black, colors.lime)
table.insert(touchZones, {id="add_recipe_action", x1=scanX, x2=scanX+#scanStr-1, y=btnY})
if uiMessage ~= "" then
local msgX = math.floor((w - #uiMessage) / 2) + 1
drawText(msgX, btnY - 1, uiMessage, colors.white)
end
end
elseif learningState == "AWAITING_DECISION" and learnedResult then
local midY = math.floor(h / 2)
if learnAsAlt then
local shortName = learnedResult.name:match(":(.+)$") or learnedResult.name
local hdr1 = "ADD ALTERNATIVE RECIPE"
local hdr2 = "Alt for: " .. shortName
drawText(math.floor((w - #hdr1) / 2) + 1, midY - 2, hdr1, colors.lime)
drawText(math.floor((w - #hdr2) / 2) + 1, midY - 1, hdr2, colors.white)
if findDuplicateRecipe(learnedResult.name, {type = learnedCraftType, machine_name = learnedMachineName, ingredients = learnedIngredients}) then
local dubS = shortName .. "  DUB"
drawText(math.floor((w - #dubS) / 2) + 1, midY, dubS, colors.red)
end
local saveS = " [ SAVE ALT ] "
local discS = " [ DISCARD ] "
local totalW = #saveS + 2 + #discS
local startX = math.floor((w - totalW) / 2) + 1
local discX  = startX + #saveS + 2
drawText(startX, midY + 1, saveS, colors.black, colors.lime)
drawText(discX,  midY + 1, discS, colors.white, colors.gray)
table.insert(touchZones, {id="learn_save",   x1=startX, x2=startX+#saveS-1, y=midY+1})
table.insert(touchZones, {id="learn_cancel", x1=discX,  x2=discX+#discS-1,  y=midY+1})
else
local outs = (learnedCraftType ~= "turtle" and learnedOutputs and #learnedOutputs > 0)
and learnedOutputs or {{name = learnedResult.name, count = learnedResult.count}}
local nTools = 0
if learnedTools then for _ in pairs(learnedTools) do nTools = nTools + 1 end end
local hdr1 = "RECIPE SCAN RESULT"
local titleY = midY - #outs - nTools - 1
if titleY < 11 then titleY = 11 end
drawText(math.floor((w - #hdr1) / 2) + 1, titleY, hdr1, colors.lime)
local ly = titleY + 1
for _, o in ipairs(outs) do
local ex = Recipes[o.name]
local isReal = (type(ex) == "table" and ex.type ~= "fluid")
local isDub = findDuplicateRecipe(o.name, {type = learnedCraftType, machine_name = learnedMachineName, ingredients = learnedIngredients})
local sn = o.name:match(":(.+)$") or o.name
local line
if isDub then
line = "x" .. o.count .. " " .. sn .. "  DUB"
else
line = "x" .. o.count .. " " .. sn .. (isReal and "  -> +ALT" or "  -> NEW")
end
drawText(math.floor((w - #line) / 2) + 1, ly, line, isDub and colors.red or (isReal and colors.yellow or colors.lime))
ly = ly + 1
end
if learnedTools then
for tn in pairs(learnedTools) do
local tsn = tn:match(":(.+)$") or tn
local tline = "tool: " .. tsn
drawText(math.floor((w - #tline) / 2) + 1, ly, tline, colors.cyan)
ly = ly + 1
end
end
local btnRow = ly + 1
local saveS  = " [ SAVE ] "
local discS  = " [ DISCARD ] "
local totalW = #saveS + 2 + #discS
local startX = math.floor((w - totalW) / 2) + 1
local discX  = startX + #saveS + 2
drawText(startX, btnRow, saveS, colors.black, colors.lime)
drawText(discX,  btnRow, discS, colors.white, colors.gray)
table.insert(touchZones, {id="learn_save",   x1=startX, x2=startX+#saveS-1, y=btnRow})
table.insert(touchZones, {id="learn_cancel", x1=discX,  x2=discX+#discS-1,  y=btnRow})
end
end
end
function _diB3(w, h, touchZones)
local hdr = "GIT REPOSITORY SYNC"
drawText(math.floor((w - #hdr) / 2) + 1, 9, hdr, colors.lime)
drawText(1, 10, string.rep("-", w), colors.gray)
local hasRepo   = Config.github_repo and Config.github_repo ~= ""
local repoVal   = hasRepo and string.rep("*", math.min(32, #Config.github_repo)) or "<not configured>"
local repoColor = hasRepo and colors.white or colors.red
local repoEditBg = (gitActiveButton == "git_set_repo") and colors.orange or colors.gray
drawText(2,  12, "Repo: ", colors.gray)
drawText(8,  12, repoVal:sub(1, w - 18), repoColor)
drawText(w - 8, 12, " [EDIT] ", colors.black, repoEditBg)
table.insert(touchZones, {id="git_set_repo", x1=w-8, x2=w-1, y=12})
local hasToken  = Config.github_token and Config.github_token ~= ""
local tokVal    = hasToken and string.rep("*", math.min(32, #Config.github_token)) or "<not configured>"
local tokColor  = hasToken and colors.white or colors.red
local tokEditBg = (gitActiveButton == "git_set_token") and colors.orange or colors.gray
drawText(2,  13, "Token:", colors.gray)
drawText(8,  13, tokVal:sub(1, w - 18), tokColor)
drawText(w - 8, 13, " [EDIT] ", colors.black, tokEditBg)
table.insert(touchZones, {id="git_set_token", x1=w-8, x2=w-1, y=13})
do
local hasNtfy   = Config.ntfy_topic and Config.ntfy_topic ~= ""
local ntfyVal   = hasNtfy and Config.ntfy_topic or "<off>"
local ntfyColor = hasNtfy and colors.white or colors.gray
local ntfyEditBg = (gitActiveButton == "git_set_ntfy") and colors.orange or colors.gray
local cmdOn     = hasNtfy and (Config.ntfy_cmds ~= false)
local cmdStr    = cmdOn and " [CMD ON] " or " [CMD OFF]"
local cmdX      = w - 8 - #cmdStr - 1
drawText(2,  14, "Ntfy: ", colors.gray)
drawText(8,  14, ntfyVal:sub(1, math.max(1, cmdX - 8 - 1)), ntfyColor)
drawText(cmdX, 14, cmdStr, cmdOn and colors.black or colors.white, cmdOn and colors.lime or colors.gray)
if hasNtfy then
table.insert(touchZones, {id="ntfy_toggle_cmds", x1=cmdX, x2=cmdX+#cmdStr-1, y=14})
end
drawText(w - 8, 14, " [EDIT] ", colors.black, ntfyEditBg)
table.insert(touchZones, {id="git_set_ntfy", x1=w-8, x2=w-1, y=14})
end
drawText(1, 15, string.rep("-", w), colors.gray)
local canExport = not gitWorking and hasRepo and hasToken
local canImport = not gitWorking and hasRepo
local expStr = " [ EXPORT TO GITHUB ] "
local impStr = " [ IMPORT FROM GITHUB ] "
local expX = math.max(2, math.floor(w / 4) - math.floor(#expStr / 2))
local impX = math.max(expX + #expStr + 2, math.floor(3 * w / 4) - math.floor(#impStr / 2))
local expBg = (gitActiveButton == "git_export") and colors.orange
or (canExport and colors.lime or colors.gray)
local impBg = (gitActiveButton == "git_import_list") and colors.orange
or (canImport and colors.cyan or colors.gray)
drawText(expX, 17, expStr, colors.black, expBg)
if canExport or gitActiveButton == "git_export" then
table.insert(touchZones, {id="git_export", x1=expX, x2=expX+#expStr-1, y=17})
end
drawText(impX, 17, impStr, colors.black, impBg)
if canImport or gitActiveButton == "git_import_list" then
table.insert(touchZones, {id="git_import_list", x1=impX, x2=impX+#impStr-1, y=17})
end
drawText(1, 19, string.rep("-", w), colors.gray)
if gitWorking then
drawText(2, 21, "[ Working... ]", colors.yellow)
elseif gitStatus ~= "" then
drawText(2, 21, gitStatus, gitStatusColor)
end
drawText(2, h-2, "Repo format: owner/repository-name", colors.gray)
drawText(2, h-1, "Token: GitHub Personal Access Token with 'repo' scope", colors.gray)
if gitImportMode and #gitFileList > 0 then
local pW     = math.min(56, w - 4)
local maxVis = math.min(8, math.max(1, h - 16))
local totLP  = math.max(1, math.ceil(#gitFileList / maxVis))
if gitImportPage > totLP then gitImportPage = totLP end
local hasNav = totLP > 1
local pH     = math.min(2 + maxVis + (hasNav and 1 or 0) + 1, h - 10)
local pX     = math.max(1, math.floor((w - pW) / 2) + 1)
local pY     = math.max(9, math.floor((h - pH) / 2) + 1)
_bufFillRect(pX, pY, pW, pH, colors.gray)
local phdr = " SELECT BACKUP TO IMPORT "
drawText(pX + math.floor((pW - #phdr) / 2), pY, phdr, colors.black, colors.cyan)
local iStart = (gitImportPage - 1) * maxVis + 1
local iEnd   = math.min(iStart + maxVis - 1, #gitFileList)
local listY  = pY + 2
for i = iStart, iEnd do
local f = gitFileList[i]
local isSel = (i == gitSelectedFile)
drawText(pX + 2, listY, ((isSel and "> " or "  ") .. f.name):sub(1, pW - 4),
isSel and colors.black or colors.white, isSel and colors.lime or colors.gray)
table.insert(touchZones, 1, {id="git_select_file", arg=i, x1=pX+2, x2=pX+pW-3, y=listY})
listY = listY + 1
end
if hasNav then
local navY   = pY + pH - 2
local pgStr  = gitImportPage .. "/" .. totLP
local prevS  = " [<] "
local nextS  = " [>] "
local navW   = #prevS + 1 + #pgStr + 1 + #nextS
local navX   = pX + math.floor((pW - navW) / 2)
local canP   = gitImportPage > 1
local canN   = gitImportPage < totLP
drawText(navX,                        navY, prevS, canP and colors.white or colors.gray, canP and colors.gray or colors.gray)
drawText(navX + #prevS + 1,           navY, pgStr, colors.lime, colors.gray)
drawText(navX + #prevS + 1 + #pgStr + 1, navY, nextS, canN and colors.white or colors.gray, canN and colors.gray or colors.gray)
if canP then table.insert(touchZones, 1, {id="git_import_prev", x1=navX, x2=navX+#prevS-1, y=navY}) end
if canN then table.insert(touchZones, 1, {id="git_import_next", x1=navX+#prevS+1+#pgStr+1, x2=navX+navW-1, y=navY}) end
end
local btnY = pY + pH - 1
local cfmS = " [IMPORT] "
local cnlS = " [CANCEL] "
drawText(pX + 2,              btnY, cfmS, colors.black, colors.lime)
drawText(pX + pW - #cnlS - 2, btnY, cnlS, colors.white, colors.gray)
table.insert(touchZones, 1, {id="git_confirm_import", x1=pX+2,              x2=pX+2+#cfmS-1, y=btnY})
table.insert(touchZones, 1, {id="git_cancel_import",  x1=pX+pW-#cnlS-2,    x2=pX+pW-3,      y=btnY})
end
if gitExportMode then
local pW     = math.min(56, w - 4)
local maxVis = math.min(7, math.max(1, h - 17))
local totLP  = math.max(1, math.ceil(#gitExportFileList / maxVis))
if gitExportPage > totLP then gitExportPage = totLP end
local hasNav = totLP > 1
local pH     = math.min(3 + maxVis + (hasNav and 1 or 0) + 1, h - 10)
local pX     = math.max(1, math.floor((w - pW) / 2) + 1)
local pY     = math.max(9, math.floor((h - pH) / 2) + 1)
_bufFillRect(pX, pY, pW, pH, colors.gray)
local phdr = " SELECT EXPORT TARGET "
drawText(pX + math.floor((pW - #phdr) / 2), pY, phdr, colors.black, colors.lime)
local listY = pY + 2
local isNew = (gitExportSelected == 0)
drawText(pX + 2, listY, (isNew and "> " or "  ") .. "[ + NEW FILE ]",
isNew and colors.black or colors.lime, isNew and colors.lime or colors.gray)
table.insert(touchZones, 1, {id="git_export_select", arg=0, x1=pX+2, x2=pX+pW-3, y=listY})
listY = listY + 1
local iStart = (gitExportPage - 1) * maxVis + 1
local iEnd   = math.min(iStart + maxVis - 1, #gitExportFileList)
for i = iStart, iEnd do
local f = gitExportFileList[i]
local isSel = (i == gitExportSelected)
drawText(pX + 2, listY, ((isSel and "> " or "  ") .. f.name):sub(1, pW - 4),
isSel and colors.black or colors.white, isSel and colors.orange or colors.gray)
table.insert(touchZones, 1, {id="git_export_select", arg=i, x1=pX+2, x2=pX+pW-3, y=listY})
listY = listY + 1
end
if hasNav then
local navY  = pY + pH - 2
local pgStr = gitExportPage .. "/" .. totLP
local prevS = " [<] "
local nextS = " [>] "
local navW  = #prevS + 1 + #pgStr + 1 + #nextS
local navX  = pX + math.floor((pW - navW) / 2)
local canP  = gitExportPage > 1
local canN  = gitExportPage < totLP
drawText(navX,                            navY, prevS, canP and colors.white or colors.gray, canP and colors.gray or colors.gray)
drawText(navX + #prevS + 1,               navY, pgStr, colors.lime, colors.gray)
drawText(navX + #prevS + 1 + #pgStr + 1,  navY, nextS, canN and colors.white or colors.gray, canN and colors.gray or colors.gray)
if canP then table.insert(touchZones, 1, {id="git_export_prev", x1=navX, x2=navX+#prevS-1, y=navY}) end
if canN then table.insert(touchZones, 1, {id="git_export_next", x1=navX+#prevS+1+#pgStr+1, x2=navX+navW-1, y=navY}) end
end
local btnY = pY + pH - 1
local cfmS = " [EXPORT] "
local cnlS = " [CANCEL] "
drawText(pX + 2,              btnY, cfmS, colors.black, colors.lime)
drawText(pX + pW - #cnlS - 2, btnY, cnlS, colors.white, colors.gray)
table.insert(touchZones, 1, {id="git_confirm_export", x1=pX+2,           x2=pX+2+#cfmS-1, y=btnY})
table.insert(touchZones, 1, {id="git_cancel_export",  x1=pX+pW-#cnlS-2, x2=pX+pW-3,      y=btnY})
end
end
function _diB4(w, h, touchZones, popupRect)
local rec
if recipeEditPopup.fluid then
rec = recipeEditPopup.fluidRecipeRef
elseif recipeEditPopup.altIdx then
local alts = AltRecipes[recipeEditPopup.item]
rec = alts and alts[recipeEditPopup.altIdx]
else
rec = Recipes[recipeEditPopup.item]
end
if not rec then
recipeEditPopup = nil
else
local sName = recipeEditPopup.fluid and (recipeEditPopup.fluid:match(":(.+)$") or recipeEditPopup.fluid)
or (recipeEditPopup.item:match(":(.+)$") or recipeEditPopup.item)
local turtleList = {}
for tName, enabled in pairs(Config.turtles or {}) do
if enabled then table.insert(turtleList, tName) end
end
table.sort(turtleList)
local machList = getAvailableMachines()
table.sort(machList, function(a, b)
return (getMachineDisplay(a) or a):lower() < (getMachineDisplay(b) or b):lower()
end)
local allMachines = {}
for _, t in ipairs(turtleList) do table.insert(allMachines, t) end
for _, m in ipairs(machList)  do table.insert(allMachines, m) end
local pW = math.min(w - 10, 76)
local pH = math.min(h - 4, 19)
local pX = math.max(1, math.floor((w - pW) / 2) + 1)
local pY = math.max(1, math.floor((h - pH) / 2) + 1)
local cols = 3
local colW = math.floor((pW - 2) / cols)
local listTop = pY + 4
local maxRows = pH - 7
local maxVis  = cols * maxRows
local mTotal  = math.max(1, math.ceil(#allMachines / maxVis))
local mPage   = recipeEditPopup.page or 1
if mPage > mTotal then mPage = mTotal; recipeEditPopup.page = mPage end
local mStart  = (mPage - 1) * maxVis + 1
local mEnd    = math.min(mStart + maxVis - 1, #allMachines)
popupRect = {x1=pX, x2=pX+pW-1, y1=pY, y2=pY+pH-1}
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdrStr = " EDIT RECIPE: " .. sName:upper():sub(1, pW - 16) .. " "
drawText(pX + math.floor((pW - #hdrStr) / 2), pY, hdrStr, colors.black, colors.orange)
local curMachine = rec.machine_name or "?"
local curShort   = getMachineDisplay(curMachine)
drawText(pX + 2, pY + 2, "Current: " .. curShort, colors.white, colors.gray)
if recipeEditPopup.confirmGlobal then
local newSel   = recipeEditPopup.selected or curMachine
local newShort = getMachineDisplay(newSel)
local count = 0
if recipeEditPopup.isItemScope then
local iRec = Recipes[recipeEditPopup.item]
if iRec and iRec.machine_name == curMachine then count = count + 1 end
local iAlts = AltRecipes[recipeEditPopup.item]
if iAlts then
for _, rData in ipairs(iAlts) do
if rData.machine_name == curMachine then count = count + 1 end
end
end
else
for _, rData in pairs(Recipes) do
if rData.machine_name == curMachine then count = count + 1 end
end
end
local scopeLabel = recipeEditPopup.isItemScope and "This item only:" or "Replace ALL:"
drawText(pX + 2, pY + 4, scopeLabel .. " " .. curShort, colors.yellow, colors.gray)
drawText(pX + 2, pY + 5, "       -> " .. newShort, colors.lime, colors.gray)
drawText(pX + 2, pY + 6, "Affects " .. count .. " recipes!", colors.red, colors.gray)
local cfmStr = " [ CONFIRM REPLACE ALL ] "
local cnlStr = " [ CANCEL ] "
local cfmX   = pX + math.floor((pW - #cfmStr) / 2)
local cnlX   = pX + math.floor((pW - #cnlStr) / 2)
drawText(cfmX, pY + pH - 3, cfmStr, colors.black, colors.red)
table.insert(touchZones, 1, {id="recipe_edit_confirm_global", x1=cfmX, x2=cfmX+#cfmStr-1, y=pY+pH-3})
drawText(cnlX, pY + pH - 1, cnlStr, colors.white, colors.gray)
table.insert(touchZones, 1, {id="close_recipe_edit", x1=cnlX, x2=cnlX+#cnlStr-1, y=pY+pH-1})
else
drawText(pX + 2, pY + 3, "Select machine:", colors.lightGray, colors.gray)
for ci = 1, cols - 1 do
local sepX = pX + 1 + ci * colW
for ry = 0, maxRows - 1 do
drawText(sepX, listTop + ry, "|", colors.lightGray, colors.gray)
end
end
for i = mStart, mEnd do
local localIdx = i - mStart
local col = math.floor(localIdx / maxRows)
local row = localIdx % maxRows
local cellX = pX + 2 + col * colW
local cellY = listTop + row
local mName  = allMachines[i]
local mShort = getMachineDisplay(mName)
local isSel  = (mName == recipeEditPopup.selected)
local isCur  = (mName == curMachine)
local mColor = isSel and colors.black or (isCur and colors.lime or colors.white)
local mBg    = isSel and colors.lime or colors.gray
if #mShort > colW - 2 then mShort = mShort:sub(1, colW - 2) end
drawText(cellX, cellY, mShort, mColor, mBg)
table.insert(touchZones, 1, {id="recipe_edit_select", arg=mName, x1=cellX, x2=cellX+colW-2, y=cellY})
end
local navY = pY + pH - 2
local arrL = " < "; local arrR = " > "
local lAct = (mPage > 1)
local rAct = (mPage < mTotal)
drawText(pX + 2, navY, arrL, lAct and colors.white or colors.lightGray, colors.gray)
if lAct then
table.insert(touchZones, 1, {id="recipe_edit_prev", x1=pX+2, x2=pX+2+#arrL-1, y=navY})
end
drawText(pX + pW - #arrR - 2, navY, arrR, rAct and colors.white or colors.lightGray, colors.gray)
if rAct then
table.insert(touchZones, 1, {id="recipe_edit_next", x1=pX+pW-#arrR-2, x2=pX+pW-3, y=navY})
end
local btnY      = pY + pH - 1
local applyStr  = " [APPLY] "
local globalStr = " [REPLACE ALL] "
local cnlStr    = " [CANCEL] "
drawText(pX + 2, btnY, applyStr, colors.black, colors.lime)
table.insert(touchZones, 1, {id="recipe_edit_apply", x1=pX+2, x2=pX+2+#applyStr-1, y=btnY})
if not recipeEditPopup.fluid then
drawText(pX + 2 + #applyStr + 1, btnY, globalStr, colors.white, colors.orange)
table.insert(touchZones, 1, {id="recipe_edit_global", x1=pX+2+#applyStr+1, x2=pX+2+#applyStr+#globalStr, y=btnY})
end
local cnlX = pX + pW - #cnlStr - 2
drawText(cnlX, btnY, cnlStr, colors.white, colors.gray)
table.insert(touchZones, 1, {id="close_recipe_edit", x1=cnlX, x2=cnlX+#cnlStr-1, y=btnY})
end
end
return popupRect
end
function _diB5(w, stockInv, touchZones)
local modY = 9
local allMods = {"All"}
local seenMods = {All = true}
for itemName in pairs(stockInv) do
local modId = itemName:match("^([^:]+):") or "minecraft"
if not seenMods[modId] then seenMods[modId] = true; table.insert(allMods, modId) end
end
table.sort(allMods, function(a, b)
if a == "All" then return true end
if b == "All" then return false end
if a == "minecraft" then return true end
if b == "minecraft" then return false end
return a < b
end)
table.insert(allMods, 2, "TANK")
local arrowL = " < "
local arrowR = " > "
local areaX1 = 2 + #arrowL + 1
local areaX2 = w - 1 - #arrowR - 1
local areaW  = areaX2 - areaX1 + 1
local hasTankCat = false
local modsNoAllS = {}
for _, m in ipairs(allMods) do
if m == "TANK" then hasTankCat = true
elseif m ~= "All" then table.insert(modsNoAllS, m) end
end
local allDispS = " All "
local tankDispS = " TANK "
local function frontItemsS()
local f = {}
if hasTankCat then f[#f+1] = {name="TANK", disp=tankDispS} end
f[#f+1] = {name="All", disp=allDispS}
return f
end
local function fitsInRow(items, w_avail)
local total = -1
for _, it in ipairs(items) do total = total + #it.disp + 1 end
return total <= w_avail
end
local sPages = {}
local sStart = 1
while sStart <= #modsNoAllS do
local pageItems = {}
for i = sStart, #modsNoAllS do
table.insert(pageItems, {name=modsNoAllS[i], disp=" " .. modsNoAllS[i] .. " "})
local mid = math.ceil(#pageItems / 2)
local row1 = frontItemsS()
local row2 = {}
for j = 1, mid do table.insert(row1, pageItems[j]) end
for j = mid+1, #pageItems do table.insert(row2, pageItems[j]) end
if not (fitsInRow(row1, areaW) and fitsInRow(row2, areaW)) then
table.remove(pageItems)
break
end
end
if #pageItems == 0 then break end
local mid = math.ceil(#pageItems / 2)
local page = {[1]=frontItemsS(), [2]={}}
for j = 1, mid do table.insert(page[1], pageItems[j]) end
for j = mid+1, #pageItems do table.insert(page[2], pageItems[j]) end
table.insert(sPages, page)
sStart = sStart + #pageItems
end
if #sPages == 0 then
table.insert(sPages, {[1]=frontItemsS(), [2]={}})
end
local sTotalPages = math.max(1, #sPages)
if stockModFilterPage > sTotalPages then stockModFilterPage = sTotalPages end
if stockModFilterPage < 1 then stockModFilterPage = 1 end
local sPage = sPages[stockModFilterPage] or {[1]=frontItemsS(), [2]={}}
local sActModX, sActModW, sActModRow = nil, nil, nil
for ri = 1, 2 do
local ry = modY + (ri - 1)
local items = sPage[ri]
if #items > 0 then
local totalW = -1
for _, item in ipairs(items) do totalW = totalW + #item.disp + 1 end
local rx = math.max(areaX1, areaX1 + math.floor((areaW - totalW) / 2))
for _, item in ipairs(items) do
local isAct = (item.name == stockModFilter)
local fg = (item.name == "TANK") and colors.cyan or (isAct and colors.white or colors.gray)
drawText(rx, ry, item.disp, fg, isAct and colors.gray or colors.black)
if isAct then sActModX = rx; sActModW = #item.disp; sActModRow = ry end
table.insert(touchZones, {id="stock_mod", arg=item.name, x1=rx, x2=rx+#item.disp-1, y=ry})
rx = rx + #item.disp + 1
end
end
end
if sActModX and sActModRow == modY + 1 then
drawText(sActModX, sActModRow + 1, string.rep("-", sActModW), colors.lime, colors.black)
end
if sTotalPages > 1 then
local arrY = modY
local lActive = (stockModFilterPage > 1)
local rActive = (stockModFilterPage < sTotalPages)
drawText(2, arrY, arrowL, lActive and colors.white or colors.gray, lActive and colors.gray or colors.black)
if lActive then
table.insert(touchZones, {id="stock_mod_prev", x1=2, x2=2+#arrowL-1, y=arrY})
table.insert(touchZones, {id="stock_mod_prev", x1=2, x2=2+#arrowL-1, y=arrY+1})
end
local rX = w - #arrowR
drawText(rX, arrY, arrowR, rActive and colors.white or colors.gray, rActive and colors.gray or colors.black)
if rActive then
table.insert(touchZones, {id="stock_mod_next", x1=rX, x2=rX+#arrowR-1, y=arrY})
table.insert(touchZones, {id="stock_mod_next", x1=rX, x2=rX+#arrowR-1, y=arrY+1})
end
end
end
function _diB6(w, h, stockInv, touchZones)
_diB5(w, stockInv, touchZones)
do
local searchY = 12
local dSearch  = (stockSearchFilter == "") and "<type item name...>" or stockSearchFilter
local sColor   = (stockSearchFilter == "") and (stockSearchInputActive and colors.lightGray or colors.gray) or colors.white
local fullSrch = "FIND: [ " .. dSearch .. " ]"
local srchX    = math.max(14, math.floor((w - #fullSrch) / 2) + 1)
drawText(srchX, searchY, "FIND: ", colors.gray, colors.black)
local sBgActive = stockSearchInputActive and colors.gray or colors.black
drawText(srchX + 6, searchY, "[ " .. dSearch .. " ]", sColor, sBgActive)
table.insert(touchZones, {id="stock_search", x1=srchX, x2=srchX+#fullSrch-1, y=searchY})
if stockSearchFilter ~= "" then
local boxStr = "[ " .. dSearch .. " ]"
drawText(srchX + 6, searchY + 1, string.rep("-", #boxStr), colors.lime, colors.black)
drawText(srchX+#fullSrch+1, searchY, "[X]", colors.white, colors.red)
table.insert(touchZones, {id="stock_clear_search", x1=srchX+#fullSrch+1, x2=srchX+#fullSrch+3, y=searchY})
end
if Config.train_box and Config.train_box ~= "" then
local ulStr = " UNLOAD "
drawText(2, searchY, ulStr, colors.white, colors.gray)
if unloadActive then
drawText(2, searchY + 1, string.rep("-", #ulStr), colors.lime, colors.black)
end
table.insert(touchZones, {id="pull_from_box", x1=2, x2=1+#ulStr, y=searchY})
end
local optStr = " OPTIMIZE "
local optX   = w - #optStr + 1
drawText(optX, searchY, optStr, colors.white, colors.gray)
if optimizeActive then
drawText(optX, searchY + 1, string.rep("-", #optStr), colors.lime, colors.black)
end
table.insert(touchZones, {id="stock_optimize", x1=optX, x2=w, y=searchY})
end
local colW  = math.floor((w - 2) / 3)
local sep1X = colW + 1
local sep2X = 2 * colW + 2
local colStarts = {1, colW + 2, 2 * colW + 3}
local isTankCat = (stockModFilter == "TANK")
local headY = 14
if isTankCat then
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
local totalPages
if isTankCat then
local inv, _ftc, _ftmb, tDetails = getFluidInventory()
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
local fn = fluidNameFromKey(fk)
local sn = fn:match(":(.+)$") or fn
if stockSearchFilter == "" or sn:lower():find(stockSearchFilter:lower(), 1, true) then
fl[#fl + 1] = {name = fn, mb = amt, tanks = tankCntByKey[fk] or 0}
end
end
table.sort(fl, function(a, b) return a.name < b.name end)
local startRowY = 16
local cols = 2
local rowsPerPage = h - startRowY - 3
if rowsPerPage < 1 then rowsPerPage = 1 end
local perPage = cols * rowsPerPage
totalPages = math.max(1, math.ceil(#fl / perPage))
if currentPage > totalPages then currentPage = totalPages end
local startIdx = ((currentPage - 1) * perPage) + 1
local endIdx = math.min(startIdx + perPage - 1, #fl)
local fColW = math.floor(w / cols)
for ry = 0, rowsPerPage - 1 do
_bufClearLine(startRowY + ry, (ry % 2 == 0) and colors.black or colors.gray)
end
for ci = 1, cols - 1 do
for ry = 0, rowsPerPage - 1 do
drawText(ci * fColW, startRowY + ry, "|", colors.gray, (ry % 2 == 0) and colors.black or colors.gray)
end
end
if #fl == 0 then
local none = "No fluids. Mark tanks with [TNK] in NETWORK."
drawText(math.floor((w - #none) / 2) + 1, startRowY + 1, none, colors.gray)
else
for i = startIdx, endIdx do
local li = i - startIdx
local col = math.floor(li / rowsPerPage)
local row = li % rowsPerPage
local rowY = startRowY + row
local colX = col * fColW + 1
local rowBg = (row % 2 == 0) and colors.black or colors.gray
local f = fl[i]
local mbStr = f.mb > FLUID_MAX_CAP and ">100000 mB" or string.format("%d mB", f.mb)
local tcStr = tostring(f.tanks)
drawText(colX + 1, rowY, tcStr, colors.yellow, rowBg)
local nmX = colX + 1 + #tcStr + 1
local nm = f.name:match(":(.+)$") or f.name
local nameMax = fColW - #mbStr - 4 - #tcStr - 1
if #nm > nameMax then nm = nm:sub(1, nameMax) end
drawText(nmX, rowY, nm, colors.white, rowBg)
drawText(colX + fColW - #mbStr - 2, rowY, mbStr, colors.cyan, rowBg)
end
end
else
local stockList = {}
for itemName, count in pairs(stockInv) do
local modId    = itemName:match("^([^:]+):") or "minecraft"
local shortName = itemName:match(":(.+)$") or itemName
if (stockModFilter == "All" or stockModFilter == modId) and
(stockSearchFilter == "" or shortName:lower():find(stockSearchFilter:lower(), 1, true)) then
table.insert(stockList, {name=itemName, cnt=count})
end
end
table.sort(stockList, function(a, b) return a.name < b.name end)
local startRowY    = 16
local rowsPerPage  = h - startRowY - 3
local itemsPerPage = rowsPerPage * 3
totalPages   = math.max(1, math.ceil(#stockList / itemsPerPage))
if currentPage > totalPages then currentPage = totalPages end
local startIdx = ((currentPage - 1) * itemsPerPage) + 1
local endIdx   = math.min(startIdx + itemsPerPage - 1, #stockList)
for ry = 0, rowsPerPage - 1 do
local rowBg = (ry % 2 == 0) and colors.black or colors.gray
_bufClearLine(startRowY + ry, rowBg)
drawText(sep1X, startRowY + ry, "|", colors.gray, colors.black)
drawText(sep2X, startRowY + ry, "|", colors.gray, colors.black)
end
for i = startIdx, endIdx do
local item    = stockList[i]
local pageIdx = i - startIdx
local col     = math.floor(pageIdx / rowsPerPage)
local row     = pageIdx % rowsPerPage
local colX    = colStarts[col + 1]
local rowY    = startRowY + row
local rowBg   = (row % 2 == 0) and colors.black or colors.gray
local shortName  = item.name:match(":(.+)$") or item.name
local nameMaxLen = colW - 9
drawText(colX + 1, rowY, shortName:sub(1, nameMaxLen), colors.white, rowBg)
local cStr = tostring(item.cnt)
local reqX = colX + colW - 5
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
local pageStr    = string.format(" PAGE %d OF %d ", currentPage, math.max(1, totalPages))
local prevStr    = " [ PREV ] "
local nextStr    = " [ NEXT ] "
local navStartX  = math.floor((w - (#prevStr + #pageStr + #nextStr + 4)) / 2)
drawText(navStartX, navY, prevStr, currentPage > 1 and colors.white or colors.lightGray, colors.gray)
drawText(navStartX + #prevStr + 2, navY, pageStr, colors.lime, colors.black)
local nextXPos = navStartX + #prevStr + #pageStr + 4
drawText(nextXPos, navY, nextStr, currentPage < totalPages and colors.white or colors.lightGray, colors.gray)
if currentPage > 1 then
table.insert(touchZones, {id="prev_page", x1=navStartX, x2=navStartX+#prevStr-1, y=navY})
end
if currentPage < totalPages then
table.insert(touchZones, {id="next_page", x1=nextXPos, x2=nextXPos+#nextStr-1, y=navY})
end
end
function _diB7(w, h, stockInv, touchZones)
local haltText = Config.autostock_paused and " [RESUME] " or " [PAUSE ALL] "
local haltColor = Config.autostock_paused and colors.lime or colors.red
drawText(2, 9, haltText, colors.white, haltColor)
table.insert(touchZones, {id="autostock_toggle", x1=2, x2=2+#haltText-1, y=9})
drawText(2 + #haltText + 1, 9, " [RUN NOW] ", colors.black, colors.orange)
table.insert(touchZones, {id="force_autostock", x1=2+#haltText+1, x2=2+#haltText+11, y=9})
if autostockCurrentItem ~= "" then
local asName = autostockCurrentItem:match(":(.+)$") or autostockCurrentItem
drawText(2 + #haltText + 14, 9, ">> " .. asName, colors.lime)
elseif Config.autostock_paused then
drawText(2 + #haltText + 14, 9, "PAUSED", colors.red)
else
drawText(2 + #haltText + 14, 9, "IDLE", colors.gray)
end
local kHasFluid = false
for k in pairs(Autostock) do if k:sub(1, 2) == "f:" then kHasFluid = true break end end
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
local startRowY = 12
local itemsPerPage = h - startRowY - 2
local keepFluidInv = (fluidKeepFilter == "FLUID") and getFluidInventory() or nil
local keepList = {}
for itemName, settings in pairs(Autostock) do
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
local totalPages = math.max(1, math.ceil(#keepList / itemsPerPage))
if currentPage > totalPages then currentPage = totalPages end
local startIdx = ((currentPage - 1) * itemsPerPage) + 1
local endIdx   = math.min(startIdx + itemsPerPage - 1, #keepList)
local rowY = startRowY
for idx = startIdx, endIdx do
local item = keepList[idx]
local globalIdx = idx
local fluidRealName = item.fluid and fluidNameFromKey(item.name) or item.name
local cleanName = fluidRealName:match(":(.+)$") or fluidRealName
local curStock
if item.fluid then
curStock = (keepFluidInv and keepFluidInv[item.name]) or 0
else
curStock = stockInv[item.name] or 0
end
local rowBg     = (idx % 2 == 0) and colors.gray or colors.black
_bufClearLine(rowY, rowBg)
local rankStr = string.format("#%d", globalIdx)
drawText(2, rowY, rankStr, colors.orange, rowBg)
local stockDisp  = (item.fluid and curStock > FLUID_MAX_CAP) and ">100000" or tostring(curStock)
local trigStr    = item.fluid
and string.format("%d>%d mB", item.threshold, item.target)
or string.format("%d>%d", item.threshold, item.target)
local nameColor  = item.paused and colors.lightGray or (autostockCurrentItem == item.name and colors.lime or colors.white)
local bx         = w - 38
local craftNowX  = bx - 9
local keepIndX   = craftNowX - 5
local trigW      = (fluidKeepFilter == "FLUID") and 16 or 11
local curStr     = "[" .. stockDisp .. "]"
local trigX      = (keepIndX - 2) - #trigStr + 1
local curX       = (keepIndX - 3 - trigW) - #curStr + 1
local nameMax    = math.max(4, curX - (2 + #rankStr) - 1)
drawText(2 + #rankStr, rowY, (" " .. cleanName):sub(1, nameMax), nameColor, rowBg)
drawText(curX, rowY, curStr, item.paused and colors.gray or ((curStock < item.threshold) and colors.orange or colors.lime), rowBg)
drawText(trigX, rowY, trigStr, item.paused and colors.gray or colors.lightGray, rowBg)
local keepScan = item.fluid and fluidScanResults[fluidRealName] or recipesScanResults[item.name]
if item.fluid then
if keepScan ~= nil then
if keepScan > 0 then
drawText(keepIndX, rowY, keepScan > 99 and ">99" or tostring(keepScan), colors.lime, rowBg)
else
drawText(keepIndX, rowY, "[!]", colors.white, colors.red)
end
else
drawText(keepIndX, rowY, "[~]", colors.lightGray, rowBg)
end
elseif keepScan then
local cMax = keepScan.maxCraftable or 0
if cMax > 0 then
local cStr = cMax > 99 and ">99" or tostring(cMax)
drawText(keepIndX, rowY, cStr, colors.lime, rowBg)
else
drawText(keepIndX, rowY, "[!]", colors.white, colors.red)
table.insert(touchZones, {id="show_craft_info", arg=item.name, x1=keepIndX, x2=keepIndX+2, y=rowY})
end
else
drawText(keepIndX, rowY, "[~]", colors.lightGray, rowBg)
end
drawText(craftNowX, rowY, "[CRAFT]", colors.black, colors.white)
table.insert(touchZones, {id="keep_craft_now", arg=item.name, x1=craftNowX, x2=craftNowX+6, y=rowY})
local topColor = (globalIdx > 1) and colors.white or colors.gray
drawText(bx, rowY, "[TOP]", topColor, colors.gray)
if globalIdx > 1 then
table.insert(touchZones, {id="keep_top", arg=item.name, x1=bx, x2=bx+4, y=rowY})
end
local upColor = (globalIdx > 1) and colors.white or colors.gray
drawText(bx+6, rowY, "[^]", upColor, colors.gray)
if globalIdx > 1 then
table.insert(touchZones, {id="keep_up", arg=item.name, x1=bx+6, x2=bx+8, y=rowY})
end
local dnColor = (globalIdx < #keepList) and colors.white or colors.gray
drawText(bx+10, rowY, "[v]", dnColor, colors.gray)
if globalIdx < #keepList then
table.insert(touchZones, {id="keep_dn", arg=item.name, x1=bx+10, x2=bx+12, y=rowY})
end
drawText(bx+14, rowY, "[EDIT]", colors.white, colors.gray)
table.insert(touchZones, {id="keep_edit", arg=item.name, x1=bx+14, x2=bx+19, y=rowY})
local stateStr   = item.paused and "[RUN]  " or "[PAUSE]"
local stateColor = item.paused and colors.red or colors.gray
drawText(bx+21, rowY, stateStr, colors.white, stateColor)
table.insert(touchZones, {id="toggle_keep_status", arg=item.name, x1=bx+21, x2=bx+27, y=rowY})
drawText(bx+29, rowY, "[DEL]", colors.white, colors.red)
table.insert(touchZones, {id="remove_keep", arg=item.name, x1=bx+29, x2=bx+33, y=rowY})
rowY = rowY + 1
end
do
local navY = h - 1
drawText(1, navY - 1, string.rep("-", w), colors.gray)
local pageStr = string.format(" PAGE %d OF %d ", currentPage, math.max(1, totalPages))
local prevStr = " [ PREV ] "; local nextStr = " [ NEXT ] "
local navStartX = math.floor((w - (#prevStr + #pageStr + #nextStr + 4)) / 2)
drawText(navStartX, navY, prevStr, currentPage > 1 and colors.white or colors.lightGray, colors.gray)
drawText(navStartX + #prevStr + 2, navY, pageStr, colors.lime, colors.black)
local nextXPos = navStartX + #prevStr + #pageStr + 4
drawText(nextXPos, navY, nextStr, currentPage < totalPages and colors.white or colors.lightGray, colors.gray)
if currentPage > 1 then
table.insert(touchZones, {id="prev_page", x1=navStartX, x2=navStartX + #prevStr - 1, y=navY})
end
if currentPage < totalPages then
table.insert(touchZones, {id="next_page", x1=nextXPos, x2=nextXPos + #nextStr - 1, y=navY})
end
end
end
function _diB8(w, touchZones)
local modY = 9
local mods = getRegisteredMods()
table.insert(mods, 2, "FLUID")
local arrowL = " < "
local arrowR = " > "
local areaX1 = 2 + #arrowL + 1
local areaX2 = w - 1 - #arrowR - 1
local areaW  = areaX2 - areaX1 + 1
local hasFluidCat = false
local modsNoAll = {}
for _, m in ipairs(mods) do
if m == "FLUID" then hasFluidCat = true
elseif m ~= "All" then table.insert(modsNoAll, m) end
end
local allDisp = " All "
local fluidDisp = " FLUID "
local function frontItemsR()
local f = {}
if hasFluidCat then f[#f+1] = {name="FLUID", disp=fluidDisp} end
f[#f+1] = {name="All", disp=allDisp}
return f
end
local function fitsInRowR(items, w_avail)
local total = -1
for _, it in ipairs(items) do total = total + #it.disp + 1 end
return total <= w_avail
end
local pages = {}
local rStart = 1
while rStart <= #modsNoAll do
local pageItems = {}
for i = rStart, #modsNoAll do
table.insert(pageItems, {name=modsNoAll[i], disp=" " .. modsNoAll[i] .. " "})
local mid = math.ceil(#pageItems / 2)
local row1 = frontItemsR()
local row2 = {}
for j = 1, mid do table.insert(row1, pageItems[j]) end
for j = mid+1, #pageItems do table.insert(row2, pageItems[j]) end
if not (fitsInRowR(row1, areaW) and fitsInRowR(row2, areaW)) then
table.remove(pageItems)
break
end
end
if #pageItems == 0 then break end
local mid = math.ceil(#pageItems / 2)
local page = {[1]=frontItemsR(), [2]={}}
for j = 1, mid do table.insert(page[1], pageItems[j]) end
for j = mid+1, #pageItems do table.insert(page[2], pageItems[j]) end
table.insert(pages, page)
rStart = rStart + #pageItems
end
if #pages == 0 then
table.insert(pages, {[1]=frontItemsR(), [2]={}})
end
local totalModPages = math.max(1, #pages)
if modFilterPage > totalModPages then modFilterPage = totalModPages end
if modFilterPage < 1 then modFilterPage = 1 end
local page = pages[modFilterPage] or {[1]=frontItemsR(), [2]={}}
local actModX, actModW, actModRow = nil, nil, nil
for ri = 1, 2 do
local ry = modY + (ri - 1)
local items = page[ri]
if #items > 0 then
local totalW = -1
for _, item in ipairs(items) do totalW = totalW + #item.disp + 1 end
local rx = math.max(areaX1, areaX1 + math.floor((areaW - totalW) / 2))
for _, item in ipairs(items) do
local isAct = (item.name == currentModFilter)
local fg = (item.name == "FLUID") and colors.cyan or (isAct and colors.white or colors.gray)
drawText(rx, ry, item.disp, fg, isAct and colors.gray or colors.black)
if isAct then actModX = rx; actModW = #item.disp; actModRow = ry end
table.insert(touchZones, {id="set_mod", arg=item.name, x1=rx, x2=rx+#item.disp-1, y=ry})
rx = rx + #item.disp + 1
end
end
end
if actModX and actModRow == modY + 1 then
drawText(actModX, actModRow + 1, string.rep("-", actModW), colors.lime, colors.black)
end
if totalModPages > 1 then
local arrY = modY
local lActive = (modFilterPage > 1)
local rActive = (modFilterPage < totalModPages)
drawText(2, arrY, arrowL, lActive and colors.white or colors.gray, lActive and colors.gray or colors.black)
if lActive then
table.insert(touchZones, {id="mod_prev", x1=2, x2=2+#arrowL-1, y=arrY})
table.insert(touchZones, {id="mod_prev", x1=2, x2=2+#arrowL-1, y=arrY+1})
end
local rX = w - #arrowR
drawText(rX, arrY, arrowR, rActive and colors.white or colors.gray, rActive and colors.gray or colors.black)
if rActive then
table.insert(touchZones, {id="mod_next", x1=rX, x2=rX+#arrowR-1, y=arrY})
table.insert(touchZones, {id="mod_next", x1=rX, x2=rX+#arrowR-1, y=arrY+1})
end
end
end
function _diB9(w, h, stockInv, touchZones, popupRect)
craftCompletePopup = nil
craftErrorLines = {}; craftErrorTitle = nil
craftInfoPopup = nil
recipeEditPopup = nil
local pW = 54
local pH = 10
local pX = math.max(1, math.floor((w - pW) / 2) + 1)
local pY = math.max(1, math.floor((h - pH) / 2) + 1)
popupRect = {x1=pX, x2=pX+pW-1, y1=pY, y2=pY+pH-1}
_bufFillRect(pX, pY, pW, pH, colors.gray)
local headerText
local headerColor
if queueEditIdx then
headerText = " EDIT QUEUE AMOUNT "
headerColor = colors.cyan
elseif fluidCraftMode then
headerText = " FLUID PRODUCTION ORDER "
headerColor = colors.cyan
elseif isRequestMode then
headerText = " REQUEST TO TRAIN BOX "
headerColor = colors.cyan
elseif altOutEdit then
headerText = " OUTPUT COUNT "
headerColor = colors.cyan
elseif isSettingKeepLimit then
headerText = " KEEP: THRESHOLD -> TARGET "
headerColor = colors.orange
else
headerText = " PRODUCTION INTERACTIVE ORDER "
headerColor = colors.lime
end
drawText(pX + math.floor((pW - #headerText) / 2), pY, headerText, colors.black, headerColor)
local nameLabel = "Item: "
if fluidCraftMode then nameLabel = fluidCraftMode.isItem and "Item: " or "Fluid: " end
if fluidKeepName then nameLabel = "Fluid: " end
local pickName = fluidKeepName and (fluidKeepName:match("([^:]+)$") or fluidKeepName)
or (itemToCraft:match(":(.+)$") or itemToCraft)
if not altOutEdit then
drawText(pX + 2, pY + 2, nameLabel .. pickName, colors.white, colors.gray)
end
local exactStock = isRequestMode and requestMaxQty or (stockInv and (stockInv[itemToCraft] or 0) or 0)
local curStock      = exactStock
local stockColor    = colors.cyan
if exactStock == 0 and stockInv then
local grp = ITEM_GROUPS[itemToCraft]
if grp then
local altTotal = 0
for _, altName in ipairs(GROUPS[grp]) do
if altName ~= itemToCraft then
altTotal = altTotal + (stockInv[altName] or 0)
end
end
if altTotal > 0 then
curStock   = altTotal
stockColor = colors.yellow
end
end
end
local unitSuf = ""
if fluidCraftMode then
unitSuf = fluidCraftMode.isItem and "x" or " mB"
if fluidCraftMode.isItem then
curStock = stockInv and (stockInv[itemToCraft] or 0) or 0
else
local fInv = (pickerHeaderSnap and pickerHeaderSnap.fluidInv) or getFluidInventory()
curStock = fInv[fluidKey(itemToCraft)] or 0
end
stockColor = colors.cyan
elseif fluidKeepName then
unitSuf = " mB"
local fInv = (pickerHeaderSnap and pickerHeaderSnap.fluidInv) or getFluidInventory()
curStock = fInv[itemToCraft] or 0
stockColor = colors.cyan
end
if isSettingKeepLimit then
drawText(pX + 2 + #(nameLabel .. pickName) + 2, pY + 2,
"Stock: " .. curStock .. unitSuf, stockColor, colors.gray)
local thrSel = (keepField == "threshold")
local tgtSel = (keepField ~= "threshold")
local thrStr = " THRESHOLD: " .. keepThr .. unitSuf .. " "
local tgtStr = " TARGET: " .. keepTgt .. unitSuf .. " "
drawText(pX + 2, pY + 3, thrStr, thrSel and colors.black or colors.white, thrSel and colors.lime or colors.gray)
table.insert(touchZones, 1, {id="keep_field", arg="threshold", x1=pX+2, x2=pX+2+#thrStr-1, y=pY+3})
local tgtX = pX + 2 + #thrStr + 2
drawText(tgtX, pY + 3, tgtStr, tgtSel and colors.black or colors.white, tgtSel and colors.lime or colors.gray)
table.insert(touchZones, 1, {id="keep_field", arg="target", x1=tgtX, x2=tgtX+#tgtStr-1, y=pY+3})
elseif altOutEdit then
local aoPart = "Output per craft: " .. craftQuantity
drawText(pX + math.floor((pW - #aoPart) / 2), pY + 2, aoPart, colors.lime, colors.gray)
else
local amtPart = "Amount: " .. craftQuantity .. unitSuf
local stPart  = "  Stock: " .. curStock .. unitSuf
drawText(pX + 2,            pY + 3, amtPart, colors.lime, colors.gray)
drawText(pX + 2 + #amtPart, pY + 3, stPart,  stockColor, colors.gray)
if not isRequestMode then
local mxLabel = "  Max: "
local mxX = pX + 2 + #amtPart + #stPart
drawText(mxX, pY + 3, mxLabel, colors.lime, colors.gray)
local valX = mxX + #mxLabel
local mxVal, mxColor
if not pickerMaxComputed then
mxVal = "?"
mxColor = colors.yellow
else
if fluidCraftMode then
mxVal = pickerMaxCraftable >= FLUID_MAX_CAP and ">100000" or (tostring(pickerMaxCraftable) .. unitSuf)
else
mxVal = pickerMaxCraftable >= ITEM_MAX_CAP and ">999" or tostring(pickerMaxCraftable)
end
mxColor = pickerMaxCraftable > 0 and colors.lime or colors.red
end
drawText(valX, pY + 3, mxVal, mxColor, colors.gray)
table.insert(touchZones, 1, {id="qty_calc_max", x1=valX, x2=valX + #mxVal - 1, y=pY+3})
local autoOn = (Config.autoMaxCalc ~= false)
local tgStr  = autoOn and " [AUT] " or " [MAN] "
local tgX    = pX + pW - #tgStr - 2
drawText(tgX, pY + 3, tgStr, colors.black, autoOn and colors.lime or colors.orange)
table.insert(touchZones, 1, {id="qty_toggle_automax", x1=tgX, x2=tgX + #tgStr - 1, y=pY+3})
end
end
local addRow = pY + 4
local subRow = pY + 5
local btnRow = pY + 8
local maxStr = " [MAX] "
local typStr = " [123] "
local rightBtnX = pX + pW - #maxStr - 2
local addVals = {1, 8, 16, 32, 64}
local subVals = {-1, -8, -16, -32, -64}
local qeEdit = queueEditIdx and craftQueue[queueEditIdx]
if (fluidCraftMode and not fluidCraftMode.isItem) or fluidKeepName
or (qeEdit and qeEdit.kind == "fluid" and not qeEdit.isItem) then
addVals = {100, 1000, 5000, 10000}
subVals = {-100, -1000, -5000, -10000}
end
local qX = pX + 2
for _, val in ipairs(addVals) do
local str = " [+" .. val .. "] "
drawText(qX, addRow, str, colors.white, colors.gray)
table.insert(touchZones, 1, {id="qty_adj", arg=val, x1=qX, x2=qX+#str-1, y=addRow})
qX = qX + #str + 1
end
if not isSettingKeepLimit and not altOutEdit then
drawText(rightBtnX, addRow, maxStr, colors.black, colors.lime)
table.insert(touchZones, 1, {id="qty_max", x1=rightBtnX, x2=rightBtnX+#maxStr-1, y=addRow})
end
qX = pX + 2
for _, val in ipairs(subVals) do
local str = " [" .. val .. "] "
drawText(qX, subRow, str, colors.white, colors.gray)
table.insert(touchZones, 1, {id="qty_adj", arg=val, x1=qX, x2=qX+#str-1, y=subRow})
qX = qX + #str + 1
end
drawText(rightBtnX, subRow, typStr, colors.black, colors.cyan)
table.insert(touchZones, 1, {id="qty_type", x1=rightBtnX, x2=rightBtnX+#typStr-1, y=subRow})
if qtyTypeActive then
local opW = 30; local opH = 5
local opX = pX + math.floor((pW - opW) / 2)
local opY = pY + math.floor((pH - opH) / 2)
_bufFillRect(opX, opY, opW, opH, colors.gray)
local ohdr = " ENTER QUANTITY "
drawText(opX + math.floor((opW - #ohdr) / 2), opY, ohdr, colors.black, colors.cyan)
local oHint = "Type number in terminal"
drawText(opX + math.floor((opW - #oHint) / 2), opY + 2, oHint, colors.lightGray, colors.gray)
local oCur = "Current: " .. tostring(craftQuantity)
drawText(opX + math.floor((opW - #oCur) / 2), opY + 3, oCur, colors.lime, colors.gray)
end
local cfmStr = " [ CONFIRM ] "
local cnlStr = " [ CANCEL ] "
drawText(pX + 2,                btnRow, cfmStr, colors.black, colors.lime)
drawText(pX + pW - #cnlStr - 2, btnRow, cnlStr, colors.white, colors.gray)
table.insert(touchZones, 1, {id="qty_confirm", x1=pX+2,                x2=pX+2+#cfmStr-1,            y=btnRow})
table.insert(touchZones, 1, {id="qty_cancel",  x1=pX+pW-#cnlStr-2,    x2=pX+pW-2,                   y=btnRow})
if not isRequestMode and not isSettingKeepLimit and not fluidKeepName and not queueEditIdx and not altOutEdit then
local aqStr = " [+QUEUE] "
local aqX = pX + 2 + #cfmStr + 1
drawText(aqX, btnRow, aqStr, colors.black, colors.cyan)
table.insert(touchZones, 1, {id="qty_add_queue", x1=aqX, x2=aqX+#aqStr-1, y=btnRow})
end
return popupRect
end
function _diB10(w, h, stockInv, touchZones, popupRect)
local hasBox   = Config.train_box and Config.train_box ~= ""
local pW       = math.min(w - 4, 82)
local hPerPage = math.max(4, h - 18)
local totEnt   = #craftHistory
local totPg    = math.max(1, math.ceil(totEnt / hPerPage))
if (historyPopup.page or 1) > totPg then historyPopup.page = 1 end
local hPage    = historyPopup.page or 1
local pH       = hPerPage + 5
local pX       = math.max(1, math.floor((w - pW) / 2) + 1)
local pY       = math.max(9, math.floor((h - pH) / 2))
popupRect = {x1=pX, x2=pX+pW-1, y1=pY, y2=pY+pH-1}
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdrStr = " CRAFT HISTORY "
drawText(pX + math.floor((pW - #hdrStr) / 2), pY, hdrStr, colors.black, colors.orange)
do
local scanStr = " [SCAN] "
local scanHX  = pX + pW - #scanStr - 1
drawText(scanHX, pY, scanStr, colors.black, colors.lime)
table.insert(touchZones, 1, {id="history_scan", x1=scanHX, x2=scanHX+#scanStr-1, y=pY})
end
local reqStr   = "[REQ]"
local craftStr = "[CRAFT]"
local reqX     = pX + pW - #reqStr - 2
local stkEnd   = reqX - 2
local stkW     = 3
local craftEnd = stkEnd - stkW - 1
local craftX   = craftEnd - #craftStr + 1
local maxEnd   = craftX - 2
local maxW     = 3
local maxCache = historyPopup.maxCache or {}
local histFluidInv = getFluidInventoryCached()
local listY  = pY + 2
local startIdx = (hPage - 1) * hPerPage + 1
local endIdx   = math.min(startIdx + hPerPage - 1, totEnt)
for i = startIdx, endIdx do
local entry  = craftHistory[i]
local sName  = entry.item:match(":(.+)$") or entry.item
local stock  = entry.fluid and (histFluidInv[fluidKey(entry.item)] or 0) or (stockInv and (stockInv[entry.item] or 0) or 0)
local maxC   = maxCache[(entry.fluid and "f:" or "") .. entry.item]
local rowBg  = (i % 2 == 0) and colors.gray or colors.black
local maxDisp
if maxC == nil then
maxDisp = "?"
elseif maxC >= 100 then
maxDisp = ">99"
else
maxDisp = tostring(maxC)
end
local maxX = maxEnd - #maxDisp + 1
local stkStr = tostring(stock)
if #stkStr > stkW then stkStr = "+++" end
local stkX = stkEnd - #stkStr + 1
local qtyStr = "x" .. tostring(entry.qty)
local qtyX   = maxEnd - maxW - #qtyStr
local nameW  = math.max(0, qtyX - pX - 2)
_bufFillRect(pX + 1, listY, pW - 2, 1, rowBg)
drawText(pX + 2, listY, sName:sub(1, nameW), colors.white, rowBg)
local qtyColor = (rowBg == colors.lightGray) and colors.black or colors.lightGray
drawText(qtyX, listY, qtyStr, qtyColor, rowBg)
drawText(maxX, listY, maxDisp, colors.lime, rowBg)
drawText(craftX, listY, craftStr, colors.black, colors.white)
table.insert(touchZones, 1, {id=entry.fluid and "history_craft_fluid" or "history_craft", arg=entry.item, x1=craftX, x2=craftX+#craftStr-1, y=listY})
drawText(stkX, listY, stkStr, colors.cyan, rowBg)
if not entry.fluid then
local rColor = hasBox and colors.cyan or colors.gray
drawText(reqX, listY, reqStr, colors.black, rColor)
if hasBox then
table.insert(touchZones, 1, {id="history_req", arg=entry.item, x1=reqX, x2=reqX+#reqStr-1, y=listY})
end
end
listY = listY + 1
end
if totEnt == 0 then
local msg = "No crafts yet."
drawText(pX + math.floor((pW - #msg) / 2), listY + 1, msg, colors.lightGray, colors.gray)
end
local navY = pY + pH - 1
drawText(pX + 1, navY - 1, string.rep("-", pW - 2), colors.lightGray, colors.gray)
if totPg > 1 then
local prevS = "[ PREV ]"; local nextS = "[ NEXT ]"
local pgS   = " PAGE " .. hPage .. " OF " .. totPg .. " "
local navW2 = #prevS + #pgS + #nextS + 2
local navX  = pX + math.floor((pW - navW2) / 2)
drawText(navX, navY, prevS, colors.white, colors.gray)
table.insert(touchZones, 1, {id="history_prev", x1=navX, x2=navX+#prevS-1, y=navY})
drawText(navX + #prevS + 1, navY, pgS, colors.lime, colors.gray)
local nxtX = navX + #prevS + #pgS + 2
drawText(nxtX, navY, nextS, colors.white, colors.gray)
table.insert(touchZones, 1, {id="history_next", x1=nxtX, x2=nxtX+#nextS-1, y=navY})
else
local clsNav = " [ CLOSE ] "
local cnX = pX + math.floor((pW - #clsNav) / 2)
drawText(cnX, navY, clsNav, colors.white, colors.gray)
table.insert(touchZones, 1, {id="close_history", x1=cnX, x2=cnX+#clsNav-1, y=navY})
end
return popupRect
end
function _diB11(w, h, touchZones)
local newStr   = " [+NEW GROUP] "
local syncBtnS = " [SYNC] "
local totalBW  = #newStr + 2 + #syncBtnS
local btnSX    = math.floor((w - totalBW) / 2) + 1
drawText(btnSX, 9, newStr, colors.black, colors.lime)
table.insert(touchZones, {id="mgmt_new", x1=btnSX, x2=btnSX+#newStr-1, y=9})
local syncBtnX = btnSX + #newStr + 2
local syncMoved = mgmtSyncInfo:find("^moved") ~= nil
local syncBg   = syncMoved and colors.lime  or colors.gray
local syncFg   = syncMoved and colors.black or colors.white
drawText(syncBtnX, 9, syncBtnS, syncFg, syncBg)
table.insert(touchZones, {id="mgmt_sync_now", x1=syncBtnX, x2=syncBtnX+#syncBtnS-1, y=9})
local syncFlashing = mgmtSyncFlashTime and (os.clock() - mgmtSyncFlashTime) < 3
if syncFlashing then
drawText(syncBtnX, 10, string.rep("-", #syncBtnS), colors.lime, colors.black)
else
drawText(1, 10, string.rep("-", w), colors.gray, colors.black)
end
if #MgmtGroups == 0 then
local emptyStr = "No groups. Tap [+NEW GROUP] to create one."
drawText(math.max(1, math.floor((w - #emptyStr) / 2)), 14, emptyStr, colors.gray, colors.black)
else
local rowsPerPage = math.max(1, math.floor((h - 14) / 2))
local totalMPages  = math.max(1, math.ceil(#MgmtGroups / rowsPerPage))
if mgmtPage > totalMPages then mgmtPage = totalMPages end
local mStart = (mgmtPage - 1) * rowsPerPage + 1
local mEnd   = math.min(mStart + rowsPerPage - 1, #MgmtGroups)
local rowY = 11
for gi = mStart, mEnd do
local grp    = MgmtGroups[gi]
local gName  = (grp.name ~= "" and grp.name or "(unnamed)"):upper()
local gInput  = mgmtIODisplay(grp, true)
local gOutput = mgmtIODisplay(grp, false)
local isPaused = grp.paused or false
local rowBg = ((gi - mStart) % 2 == 0) and colors.black or colors.gray
_bufClearLine(rowY, rowBg)
local delS   = " [DEL] "; local editS = " [EDIT] "; local viewS = " [VIEW] "
local pauseS = isPaused and " [RUN] " or " [PAUSE] "
local delX   = w - #delS + 1
local editX  = delX - #editS - 1
local viewX  = editX - #viewS - 1
local pauseX = viewX - #pauseS - 1
drawText(pauseX, rowY, pauseS, isPaused and colors.black or colors.white, isPaused and colors.orange or (rowBg == colors.gray and colors.lightGray or colors.gray))
drawText(viewX,  rowY, viewS,  colors.white, colors.gray)
drawText(editX,  rowY, editS,  colors.white, colors.gray)
drawText(delX,   rowY, delS,   colors.white, colors.gray)
table.insert(touchZones, {id="mgmt_pause", arg=gi, x1=pauseX, x2=pauseX+#pauseS-1, y=rowY})
table.insert(touchZones, {id="mgmt_del",  arg=gi, x1=delX,  x2=w,              y=rowY})
table.insert(touchZones, {id="mgmt_edit", arg=gi, x1=editX, x2=editX+#editS-1, y=rowY})
table.insert(touchZones, {id="mgmt_view", arg=gi, x1=viewX, x2=viewX+#viewS-1, y=rowY})
local isFluidGrp = mgmtGroupIsFluid(grp)
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
if mgmtActiveBtn and mgmtActiveBtn.gi == gi and (os.clock() - mgmtActiveBtn.t) < 2 then
local abx, abw
if     mgmtActiveBtn.btn == "view"  then abx = viewX;  abw = #viewS
elseif mgmtActiveBtn.btn == "edit"  then abx = editX;  abw = #editS
elseif mgmtActiveBtn.btn == "del"   then abx = delX;   abw = #delS
elseif mgmtActiveBtn.btn == "pause" then abx = pauseX; abw = #pauseS
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
local rn = rule.item:match(":(.+)$") or rule.item
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
rowY = rowY + 2
end
do
local navY = h - 1
drawText(1, navY - 1, string.rep("-", w), colors.gray)
local pageStr = string.format(" PAGE %d OF %d ", mgmtPage, math.max(1, totalMPages))
local prevStr = " [ PREV ] "; local nextStr = " [ NEXT ] "
local navStartX = math.floor((w - (#prevStr + #pageStr + #nextStr + 4)) / 2)
drawText(navStartX, navY, prevStr, mgmtPage > 1 and colors.white or colors.lightGray, colors.gray)
drawText(navStartX + #prevStr + 2, navY, pageStr, colors.lime, colors.black)
local nextXPos = navStartX + #prevStr + #pageStr + 4
drawText(nextXPos, navY, nextStr, mgmtPage < totalMPages and colors.white or colors.lightGray, colors.gray)
if mgmtPage > 1 then
table.insert(touchZones, {id="mgmt_list_prev", x1=navStartX, x2=navStartX + #prevStr - 1, y=navY})
end
if mgmtPage < totalMPages then
table.insert(touchZones, {id="mgmt_list_next", x1=nextXPos, x2=nextXPos + #nextStr - 1, y=navY})
end
end
end
end
function _diB12(w, h, touchZones)
local isFluidAlt = (altViewFluid ~= nil)
local fkAlt = isFluidAlt and fluidKey(altViewFluid) or nil
local titleName = isFluidAlt and (altViewFluid:match(":(.+)$") or altViewFluid)
or (altViewItem and (altViewItem:match(":(.+)$") or altViewItem) or "?")
drawText(2, 9, "RECIPE PRIORITY: " .. titleName, colors.lime)
drawText(1, 10, string.rep("-", w), colors.gray)
local primary, alts
if isFluidAlt then
primary = FluidRecipes[fkAlt]
alts    = FluidAltRecipes[fkAlt] or {}
else
primary = altViewItem and Recipes[altViewItem]
alts    = (altViewItem and AltRecipes[altViewItem]) or {}
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
for _, rec in pairs(FluidRecipes) do addFl(rec) end
for _, fAlts in pairs(FluidAltRecipes) do
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
mName = mName:match(":(.+)$") or mName
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
inParts[#inParts + 1] = (inp.name:match(":(.+)$") or inp.name) .. " " .. inp.amount
end
for _, it in ipairs(rec.item_inputs or {}) do
inParts[#inParts + 1] = it.count .. "x " .. (it.name:match(":(.+)$") or it.name)
end
ingStr = table.concat(inParts, " + ")
else
outVal = rec.output_count or 1
local ingSlotCounts = {}
for _, ing in ipairs(rec.ingredients or {}) do
if ing and ing ~= "nil" then
ingSlotCounts[ing] = (ingSlotCounts[ing] or 0) + 1
end
end
local ingParts = {}
for ingName, cnt in pairs(ingSlotCounts) do
local short = ingName:match(":(.+)$") or ingName
table.insert(ingParts, short .. (cnt > 1 and " x"..cnt or ""))
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
if eIdx > 1 then
drawText(bx, listY, "[^]", colors.white, colors.gray)
table.insert(touchZones, {id="combined_up", arg=eIdx, x1=bx, x2=bx+2, y=listY})
end
if eIdx < nSolid then
drawText(bx+4, listY, "[v]", colors.white, colors.gray)
table.insert(touchZones, {id="combined_dn", arg=eIdx, x1=bx+4, x2=bx+6, y=listY})
end
if eIdx > 1 then
drawText(bx+8, listY, "[TOP]", colors.black, colors.lime)
table.insert(touchZones, {id="combined_top", arg=eIdx, x1=bx+8, x2=bx+12, y=listY})
end
if not entry.isPrimary then
drawText(bx+14, listY, "[X]", colors.white, colors.red)
table.insert(touchZones, {id="combined_del", arg=eIdx, x1=bx+14, x2=bx+16, y=listY})
end
if not isFluidAlt then
drawText(bx+18, listY, "[E]", colors.white, colors.gray)
local altIdxForEdit = entry.isPrimary and nil or entry.altIdx
table.insert(touchZones, {id="open_recipe_edit", arg=altViewItem, altIdx=altIdxForEdit, fromAltView=true, x1=bx+18, x2=bx+20, y=listY})
end
end
listY = listY + 1
end
end
local btnY = h - 1
if isFluidAlt then
drawText(2, btnY, "[ BACK ]", colors.white, colors.gray)
table.insert(touchZones, {id="alt_back", x1=2, x2=9, y=btnY})
else
drawText(2, btnY, "[ + ADD ALT ]", colors.black, colors.lime)
table.insert(touchZones, {id="alt_add", x1=2, x2=14, y=btnY})
drawText(17, btnY, "[ BACK ]", colors.white, colors.gray)
table.insert(touchZones, {id="alt_back", x1=17, x2=24, y=btnY})
end
end
function _diB13(w, h, touchZones)
drawText(2, 10, "PERIPHERAL BUS MATRIX (SYSTEM SETUP):", colors.white)
local peripherals = peripheral.getNames()
local startRowY = 12 local itemsPerPage = h - startRowY - 2
local validPeriphs = {}
for _, p in ipairs(peripherals) do if not SYSTEM_SIDES[p] and p ~= MONITOR_SIDE then table.insert(validPeriphs, p) end end
table.sort(validPeriphs, function(a, b)
return (getMachineDisplay(a) or a):lower() < (getMachineDisplay(b) or b):lower()
end)
local totalPages = math.max(1, math.ceil(#validPeriphs / itemsPerPage))
if currentPage > totalPages then currentPage = totalPages end
local startIdx = ((currentPage - 1) * itemsPerPage) + 1
local endIdx = math.min(startIdx + itemsPerPage - 1, #validPeriphs)
local rowY = startRowY
for idx = startIdx, endIdx do
local p = validPeriphs[idx]
local pDisplay = getMachineDisplay(p)
local rowBg = (idx % 2 == 0) and colors.gray or colors.black
_bufClearLine(rowY, rowBg)
drawText(2, rowY, pDisplay, colors.white, rowBg)
local btnX = w - 42
if btnX < #pDisplay + 2 then btnX = #pDisplay + 2 end
local inactiveFg = colors.lightGray
local isStorage = Config.storages[p]
drawText(btnX,      rowY, " [VAULT] ", isStorage and colors.black or inactiveFg, isStorage and colors.lime   or rowBg)
table.insert(touchZones, {id="toggle_storage", arg=p, x1=btnX, x2=btnX+8, y=rowY})
local isTBox = (Config.train_box == p)
drawText(btnX + 9,  rowY, " [T.BOX] ", isTBox and colors.black or inactiveFg,    isTBox and colors.orange    or rowBg)
table.insert(touchZones, {id="set_train_box", arg=p, x1=btnX+9, x2=btnX+17, y=rowY})
local isTurtle = Config.turtles and Config.turtles[p]
drawText(btnX + 18, rowY, " [TURTLE] ", isTurtle and colors.black or inactiveFg, isTurtle and colors.cyan    or rowBg)
table.insert(touchZones, {id="set_turtle", arg=p, x1=btnX+18, x2=btnX+27, y=rowY})
local hasLabel = MachineLabels[p] and MachineLabels[p] ~= ""
drawText(btnX + 28, rowY, " [SUF] ", hasLabel and colors.black or inactiveFg, hasLabel and colors.lime or rowBg)
table.insert(touchZones, {id="machine_label", arg=p, x1=btnX+28, x2=btnX+34, y=rowY})
local isFluidTank = Config.fluid_tanks and Config.fluid_tanks[p]
local tankObj = peripheral.wrap(p)
local hasTanks = tankObj and tankObj.tanks ~= nil
if hasTanks then
drawText(btnX + 35, rowY, " [TNK] ", isFluidTank and colors.black or inactiveFg, isFluidTank and colors.lime or rowBg)
table.insert(touchZones, {id="toggle_fluid_tank", arg=p, x1=btnX+35, x2=btnX+41, y=rowY})
end
rowY = rowY + 1
end
do
local navY = h - 1
drawText(1, navY - 1, string.rep("-", w), colors.gray)
local pageStr = string.format(" PAGE %d OF %d ", currentPage, math.max(1, totalPages))
local prevStr = " [ PREV ] "; local nextStr = " [ NEXT ] "
local navStartX = math.floor((w - (#prevStr + #pageStr + #nextStr + 4)) / 2)
drawText(navStartX, navY, prevStr, currentPage > 1 and colors.white or colors.lightGray, colors.gray)
drawText(navStartX + #prevStr + 2, navY, pageStr, colors.lime, colors.black)
local nextXPos = navStartX + #prevStr + #pageStr + 4
drawText(nextXPos, navY, nextStr, currentPage < totalPages and colors.white or colors.lightGray, colors.gray)
if currentPage > 1 then
table.insert(touchZones, {id="prev_page", x1=navStartX, x2=navStartX + #prevStr - 1, y=navY})
end
if currentPage < totalPages then
table.insert(touchZones, {id="next_page", x1=nextXPos, x2=nextXPos + #nextStr - 1, y=navY})
end
end
end
function _diB14(w, touchZones)
local searchY = 12
local displaySearch = (searchFilter == "") and "<type item name...>" or searchFilter
local searchColor   = (searchFilter == "") and (searchInputActive and colors.lightGray or colors.gray) or colors.white
local fullSearch    = "FIND: [ " .. displaySearch .. " ]"
local searchX       = math.max(14, math.floor((w - #fullSearch) / 2) + 1)
drawText(searchX, searchY, "FIND: ", colors.gray, colors.black)
local srchBoxBg = searchInputActive and colors.gray or colors.black
drawText(searchX + 6, searchY, "[ " .. displaySearch .. " ]", searchColor, srchBoxBg)
table.insert(touchZones, {id="trigger_search", x1=searchX, x2=searchX+#fullSearch-1, y=searchY})
if searchFilter ~= "" then
local boxStr = "[ " .. displaySearch .. " ]"
drawText(searchX + 6, searchY + 1, string.rep("-", #boxStr), colors.lime, colors.black)
drawText(searchX + #fullSearch + 1, searchY, "[X]", colors.white, colors.red)
table.insert(touchZones, {id="clear_search", x1=searchX+#fullSearch+1, x2=searchX+#fullSearch+3, y=searchY})
end
local dtPad = math.max(0, math.floor((w - (w - 15) + 1 - #"DEVICE TYPE") / 2))
local histEnd
if Config.train_box and Config.train_box ~= "" then
local ulStr = " UNLOAD "
local ulX   = 1 + dtPad
drawText(ulX, searchY, ulStr, colors.white, colors.gray)
if unloadActive then
drawText(ulX, searchY + 1, string.rep("-", #ulStr), colors.lime, colors.black)
end
table.insert(touchZones, {id="pull_from_box", x1=ulX, x2=ulX+#ulStr-1, y=searchY})
local histStr = " HISTORY "
local histX = ulX + #ulStr + 1
drawText(histX, searchY, histStr, colors.white, colors.gray)
if historyPopup then
drawText(histX, searchY + 1, string.rep("-", #histStr), colors.lime, colors.black)
end
table.insert(touchZones, {id="open_history", x1=histX, x2=histX+#histStr-1, y=searchY})
histEnd = histX + #histStr
else
local histStr = " HISTORY "
local histX = 1 + dtPad
drawText(histX, searchY, histStr, colors.white, colors.gray)
if historyPopup then
drawText(histX, searchY + 1, string.rep("-", #histStr), colors.lime, colors.black)
end
table.insert(touchZones, {id="open_history", x1=histX, x2=histX+#histStr-1, y=searchY})
histEnd = histX + #histStr
end
local qBtn = " QUEUE "
local qCnt = (#craftQueue > 0) and tostring(#craftQueue) or ""
local qX = histEnd + 1
drawText(qX, searchY, qBtn, colors.white, colors.gray)
if qCnt ~= "" then drawText(qX + #qBtn, searchY, qCnt, colors.lime, colors.black) end
if craftQueuePopup then
drawText(qX, searchY + 1, string.rep("-", #qBtn), colors.lime, colors.black)
end
table.insert(touchZones, {id="open_queue", x1=qX, x2=qX+#qBtn+#qCnt-1, y=searchY})
local scanStr = " SCAN "
local allStr  = " ALL "
local dtColStart  = w - 15
local totalBtnW   = #scanStr + 1 + #allStr
local dtColW      = w - dtColStart + 1
local scanX = dtColStart + math.floor((dtColW - totalBtnW) / 2)
local allX  = scanX + #scanStr + 1
drawText(scanX, searchY, scanStr, colors.white, colors.gray)
if scanActive then
drawText(scanX, searchY + 1, string.rep("-", #scanStr), colors.lime, colors.black)
end
table.insert(touchZones, {id="scan_recipes", x1=scanX, x2=scanX+#scanStr-1, y=searchY})
drawText(allX, searchY, allStr, colors.white, colors.gray)
if allScanActive then
drawText(allX, searchY + 1, string.rep("-", #allStr), colors.lime, colors.black)
end
table.insert(touchZones, {id="scan_all_recipes", x1=allX, x2=w, y=searchY})
local headY = 14
local hdrBtnX = w - 60
local dtText = "DEVICE TYPE"
local dtStart = hdrBtnX + 45
local dtPad = math.max(0, math.floor((w - dtStart + 1 - #dtText) / 2))
local dtX = dtStart + dtPad
drawText(dtX, headY, dtText, colors.gray)
local inText = "ITEM NAME"
drawText(1 + dtPad, headY, inText, colors.gray)
drawText(1, headY + 1, string.rep("-", w), colors.gray)
end
function _diQueuePopup(w, h, touchZones, popupRect)
local total = #craftQueue
local maxRows = math.max(4, h - 18)
if craftQueueScroll > math.max(0, total - maxRows) then craftQueueScroll = math.max(0, total - maxRows) end
if craftQueueScroll < 0 then craftQueueScroll = 0 end
local shown = math.min(total, maxRows)
local errActive = craftQueueErrIdx and craftQueue[craftQueueErrIdx] and craftQueue[craftQueueErrIdx].failed
local pW = math.min(w - 4, 72)
local pH = math.max(shown, 1) + (errActive and 8 or 4)
local pX = math.max(1, math.floor((w - pW) / 2) + 1)
local pY = math.max(9, math.floor((h - pH) / 2) + 1)
popupRect = {x1 = pX, x2 = pX + pW - 1, y1 = pY, y2 = pY + pH - 1}
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdr = " CRAFT QUEUE (" .. total .. ") "
drawText(pX + math.floor((pW - #hdr) / 2), pY, hdr, colors.black, colors.lime)
local xDel = pX + pW - 7
local xEd  = xDel - 7
local xDn  = xEd - 4
local xUp  = xDn - 4
local xTop = xUp - 6
local xCr  = xTop - 8
if total == 0 then
drawText(pX + 2, pY + 2, "Queue empty. Use [+QUEUE] in order popup.", colors.lightGray, colors.gray)
end
for ri = 1, shown do
local qi = craftQueueScroll + ri
local qe = craftQueue[qi]
local rowY = pY + 1 + ri
local nm = qe.name:match(":(.+)$") or qe.name
local unit = (qe.kind == "fluid" and not qe.isItem) and " mB" or "x"
local label = string.format("%d. %s  %d%s", qi, nm, qe.qty, unit)
local nameW = xCr - (pX + 2) - (qe.failed and 5 or 2)
drawText(pX + 2, rowY, label:sub(1, nameW), qe.failed and colors.orange or colors.white, colors.gray)
if qe.failed then
local exX = xCr - 4
drawText(exX, rowY, "[!]", colors.white, colors.red)
table.insert(touchZones, 1, {id = "queue_err", arg = qi, x1 = exX, x2 = exX + 2, y = rowY})
end
drawText(xCr, rowY, "[CRAFT]", colors.black, colors.white)
table.insert(touchZones, 1, {id = "queue_craft", arg = qi, x1 = xCr, x2 = xCr + 6, y = rowY})
drawText(xTop, rowY, "[TOP]", (qi > 1) and colors.white or colors.lightGray, colors.gray)
if qi > 1 then
table.insert(touchZones, 1, {id = "queue_top", arg = qi, x1 = xTop, x2 = xTop + 4, y = rowY})
end
drawText(xUp, rowY, "[^]", (qi > 1) and colors.white or colors.lightGray, colors.gray)
if qi > 1 then
table.insert(touchZones, 1, {id = "queue_up", arg = qi, x1 = xUp, x2 = xUp + 2, y = rowY})
end
drawText(xDn, rowY, "[v]", (qi < total) and colors.white or colors.lightGray, colors.gray)
if qi < total then
table.insert(touchZones, 1, {id = "queue_dn", arg = qi, x1 = xDn, x2 = xDn + 2, y = rowY})
end
drawText(xEd, rowY, "[EDIT]", colors.white, colors.gray)
table.insert(touchZones, 1, {id = "queue_edit", arg = qi, x1 = xEd, x2 = xEd + 5, y = rowY})
drawText(xDel, rowY, "[DEL]", colors.white, colors.red)
table.insert(touchZones, 1, {id = "queue_del", arg = qi, x1 = xDel, x2 = xDel + 4, y = rowY})
end
if errActive then
local fl = craftQueue[craftQueueErrIdx].failed
local errY = pY + shown + 2
drawText(pX + 2, errY, ("FAIL #" .. craftQueueErrIdx .. ":"):sub(1, pW - 4), colors.red, colors.gray)
for li = 1, math.min(2, #fl) do
drawText(pX + 4, errY + li, tostring(fl[li]):sub(1, pW - 6), colors.white, colors.gray)
end
end
local btnY = pY + pH - 1
local runStr = " [ RUN ALL ] "
local clsStr = " [ CLOSE ] "
drawText(pX + 2, btnY, runStr, colors.black, (total > 0) and colors.lime or colors.gray)
table.insert(touchZones, 1, {id = "queue_runall", x1 = pX + 2, x2 = pX + 2 + #runStr - 1, y = btnY})
drawText(pX + pW - #clsStr - 2, btnY, clsStr, colors.white, colors.gray)
table.insert(touchZones, 1, {id = "queue_close", x1 = pX + pW - #clsStr - 2, x2 = pX + pW - 2, y = btnY})
if total > maxRows then
local pgL = " < "
local pgR = " > "
local pgX = pX + math.floor(pW / 2) - 4
drawText(pgX, btnY, pgL, colors.black, colors.lightGray)
drawText(pgX + 5, btnY, pgR, colors.black, colors.lightGray)
table.insert(touchZones, 1, {id = "queue_scroll", arg = -maxRows, x1 = pgX, x2 = pgX + 2, y = btnY})
table.insert(touchZones, 1, {id = "queue_scroll", arg = maxRows, x1 = pgX + 5, x2 = pgX + 7, y = btnY})
end
return popupRect
end
function _diB15(w, h, stockInv, touchZones)
_diB8(w, touchZones)
_diB14(w, touchZones)
local isFluidCat = (currentModFilter == "FLUID")
local filteredList = {}
if isFluidCat then
local fluidSet = {}
local function collectOut(rec)
for _, o in ipairs(rec.outputs or {}) do fluidSet[o.name] = true end
end
for _, rec in pairs(FluidRecipes) do collectOut(rec) end
for _, alts in pairs(FluidAltRecipes) do
for _, a in ipairs(alts) do collectOut(a) end
end
local tmp = {}
for fname in pairs(fluidSet) do tmp[#tmp + 1] = {name = fname, producers = fluidProducers(fname)} end
table.sort(tmp, function(a, b) return a.name < b.name end)
for _, e in ipairs(tmp) do
local sn = e.name:match(":(.+)$") or e.name
if searchFilter == "" or sn:lower():find(searchFilter:lower(), 1, true) ~= nil then
table.insert(filteredList, e)
end
end
else
local sortedItems = {}
for itemName in pairs(Recipes) do table.insert(sortedItems, itemName) end
table.sort(sortedItems)
for _, itemName in ipairs(sortedItems) do
local modId = itemName:match("^([^:]+):") or "minecraft"
local shortName = itemName:match(":(.+)$") or itemName
if (currentModFilter == "All" or currentModFilter == modId) and (searchFilter == "" or shortName:lower():find(searchFilter:lower(), 1, true) ~= nil) then
table.insert(filteredList, itemName)
end
end
end
local startRowY = 16
local itemsPerPage = h - startRowY - 3
local totalPages = math.max(1, math.ceil(#filteredList / itemsPerPage))
if currentPage > totalPages then currentPage = totalPages end
local startIdx = ((currentPage - 1) * itemsPerPage) + 1
local endIdx = math.min(startIdx + itemsPerPage - 1, #filteredList)
local fluidInv = isFluidCat and getFluidInventory() or nil
local rowY = startRowY
for idx = startIdx, endIdx do
if isFluidCat then
local r = filteredList[idx]
local rowBg = (idx % 2 == 0) and colors.gray or colors.black
_bufClearLine(rowY, rowBg)
local sn = r.name:match(":(.+)$") or r.name
drawText(1, rowY, sn, colors.white, rowBg)
local btnX = w - 60
if btnX < #sn + 2 then btnX = #sn + 2 end
local nProd = #r.producers
local prim = r.producers[1]
local perOp = prim and prim.perOp or 0
local stockMb = (fluidInv and fluidInv[fluidKey(r.name)]) or 0
local cStr = (stockMb > FLUID_MAX_CAP and ">100000" or tostring(stockMb))
drawText(btnX + 5 - #cStr, rowY, cStr, colors.cyan, rowBg)
local craftRes = fluidScanResults[r.name]
local cs, csFg, csBg = "[~]", colors.lightGray, rowBg
if craftRes ~= nil then
if craftRes > 0 then
cs = craftRes >= 9999 and ">9999" or (">" .. craftRes); csFg = colors.lime
else
cs = "[!]"; csFg = colors.white; csBg = colors.red
end
end
drawText(btnX + 34, rowY, cs, csFg, csBg)
if craftRes ~= nil and craftRes <= 0 then
table.insert(touchZones, {id="show_fluid_info", arg=r.name, x1=btnX+34, x2=btnX+34+#cs-1, y=rowY})
end
local awaiting = (fluidCraftWaitFluid == r.name)
drawText(btnX + 6, rowY, "[CRAFT]", colors.black, awaiting and colors.yellow or colors.white)
table.insert(touchZones, {id="fluid_craft", arg=r.name, x1=btnX+6, x2=btnX+12, y=rowY})
local isKept = Autostock[fluidKey(r.name)] ~= nil
drawText(btnX + 14, rowY, "[+KEEP]", colors.white, isKept and colors.lime or colors.gray)
table.insert(touchZones, {id="open_keep_picker_fluid", arg=r.name, x1=btnX+14, x2=btnX+20, y=rowY})
local altColor = (nProd > 1) and colors.lime or colors.gray
drawText(btnX + 22, rowY, "[ALT]", colors.black, altColor)
table.insert(touchZones, {id="fluid_alt", arg=r.name, x1=btnX+22, x2=btnX+26, y=rowY})
if pendingDeleteFluid == r.name then
drawText(btnX + 28, rowY, "[SURE?]", colors.white, colors.gray)
table.insert(touchZones, 1, {id="fluid_delete_cancel", x1=btnX+28, x2=btnX+34, y=rowY})
drawText(btnX + 36, rowY, "[YES]", colors.black, colors.red)
table.insert(touchZones, 1, {id="fluid_delete_confirm", arg=r.name, x1=btnX+36, x2=btnX+40, y=rowY})
else
drawText(btnX + 28, rowY, "[DEL]", colors.white, colors.gray)
table.insert(touchZones, {id="fluid_delete_ask", arg=r.name, x1=btnX+28, x2=btnX+32, y=rowY})
if prim then
drawText(btnX + 41, rowY, "[E]", colors.black, colors.white)
table.insert(touchZones, {id="open_recipe_edit_fluid", arg=r.name, x1=btnX+41, x2=btnX+43, y=rowY})
end
local mDisp = prim and ((getMachineDisplay(prim.recipe.machine_name) or "?") .. " " .. perOp .. "mB") or ""
drawText(btnX + 45, rowY, mDisp:sub(1, math.max(0, w - (btnX + 45))), colors.lightGray, rowBg)
end
rowY = rowY + 1
else
local itemName = filteredList[idx]
local data = Recipes[itemName]
local shortName = itemName:match(":(.+)$") or itemName
local rowBg = (idx % 2 == 0) and colors.gray or colors.black
_bufClearLine(rowY, rowBg)
drawText(1, rowY, shortName, colors.white, rowBg)
local btnX = w - 60
if btnX < #shortName + 2 then btnX = #shortName + 2 end
local stockCount = stockInv and (stockInv[itemName] or 0) or 0
local displayCount = stockCount
local countColor   = colors.cyan
if stockCount == 0 and stockInv then
local grp = ITEM_GROUPS[itemName]
if grp then
local altTotal = 0
for _, altName in ipairs(GROUPS[grp]) do
if altName ~= itemName then
altTotal = altTotal + (stockInv[altName] or 0)
end
end
if altTotal > 0 then
displayCount = altTotal
countColor   = colors.yellow
end
end
end
local cStr = tostring(displayCount)
drawText(btnX - #cStr - 1, rowY, cStr, countColor, rowBg)
local scanResult = recipesScanResults[itemName]
local indX = btnX + 37
if scanResult then
local cMax = scanResult.maxCraftable or 0
if scanResult.noMachine then
drawText(indX, rowY, "[?]", colors.black, colors.orange)
table.insert(touchZones, {id="show_machine_info", arg=itemName, x1=indX, x2=indX+2, y=rowY})
elseif cMax > 0 then
local cStr = cMax > 99 and ">99" or tostring(cMax)
drawText(indX, rowY, cStr, colors.lime, rowBg)
else
drawText(indX, rowY, "[!]", colors.white, colors.red)
table.insert(touchZones, {id="show_craft_info", arg=itemName, x1=indX, x2=indX+2, y=rowY})
end
else
drawText(indX, rowY, "[~]", colors.lightGray, rowBg)
end
local hasBox = Config.train_box and Config.train_box ~= ""
local reqColor = hasBox and colors.cyan or colors.gray
drawText(btnX, rowY, "[REQ]", colors.black, reqColor)
if hasBox then
table.insert(touchZones, {id="open_req_picker", arg=itemName, x1=btnX, x2=btnX+4, y=rowY})
end
drawText(btnX + 6, rowY, "[CRAFT]", colors.black, colors.white)
table.insert(touchZones, {id="open_qty_picker", arg=itemName, x1=btnX+6, x2=btnX+12, y=rowY})
local isKept = Autostock[itemName] ~= nil
local keepColor = isKept and colors.lime or colors.gray
drawText(btnX + 14, rowY, "[+KEEP]", colors.white, keepColor)
table.insert(touchZones, {id="open_keep_picker", arg=itemName, x1=btnX+14, x2=btnX+20, y=rowY})
local hasAlts = AltRecipes[itemName] and #AltRecipes[itemName] > 0
local altBtnColor = hasAlts and colors.lime or colors.gray
drawText(btnX + 22, rowY, "[ALT]", colors.black, altBtnColor)
table.insert(touchZones, {id="open_alt_view", arg=itemName, x1=btnX+22, x2=btnX+26, y=rowY})
if pendingDeleteItem == itemName then
drawText(btnX + 28, rowY, "[SURE?]", colors.white, colors.gray)
table.insert(touchZones, 1, {id="delete_cancel", x1=btnX+28, x2=btnX+34, y=rowY})
drawText(btnX + 36, rowY, "[YES]", colors.black, colors.red)
table.insert(touchZones, 1, {id="delete_confirm", arg=itemName, x1=btnX+36, x2=btnX+40, y=rowY})
else
drawText(btnX + 28, rowY, "[DEL]", colors.white, colors.gray)
table.insert(touchZones, {id="delete_ask", arg=itemName, x1=btnX+28, x2=btnX+32, y=rowY})
drawText(btnX + 34, rowY, "x" .. (data.output_count or 1), colors.white, rowBg)
local mRaw = tostring(data.machine_name or data.method or "")
local mDisplay = getMachineDisplay(mRaw)
if data.output_device and data.output_device ~= "" then
mDisplay = mDisplay .. ">" .. getMachineDisplay(data.output_device)
end
drawText(btnX + 41, rowY, "[E]", colors.white, colors.gray)
table.insert(touchZones, {id="open_recipe_edit", arg=itemName, x1=btnX+41, x2=btnX+43, y=rowY})
drawText(btnX + 45, rowY, mDisplay, colors.lightGray, rowBg)
if data.imported and data.type ~= "turtle" then
drawText(btnX + 44, rowY, string.char(7), colors.white, rowBg)
end
end
rowY = rowY + 1
end
end
local navY = h - 1
drawText(1, navY - 1, string.rep("-", w), colors.gray)
local pageStr = string.format(" PAGE %d OF %d ", currentPage, math.max(1, totalPages))
local prevStr = " [ PREV ] " local nextStr = " [ NEXT ] "
local navStartX = math.floor((w - (#prevStr + #pageStr + #nextStr + 4)) / 2)
drawText(navStartX, navY, prevStr, currentPage > 1 and colors.white or colors.lightGray, colors.gray)
drawText(navStartX + #prevStr + 2, navY, pageStr, colors.lime, colors.black)
local nextXPos = navStartX + #prevStr + #pageStr + 4
drawText(nextXPos, navY, nextStr, currentPage < totalPages and colors.white or colors.lightGray, colors.gray)
if currentPage > 1 then
table.insert(touchZones, {id="prev_page", x1=navStartX, x2=navStartX + #prevStr - 1, y=navY})
end
if currentPage < totalPages then
table.insert(touchZones, {id="next_page", x1=nextXPos, x2=nextXPos + #nextStr - 1, y=navY})
end
end
function _diB16(w, stockInv)
local si, totalCount, vaultsCount, freeSlots, totalSlots
local tFree, tTotal
if currentTab == "QUANTITY_PICKER" then
if not pickerHeaderSnap then
local pi, pc, pv, pf, ps = getStorageInventoryCached()
local ptf, ptt = getTankStats()
pickerHeaderSnap = {inv = pi, count = pc, vaults = pv, free = pf, slots = ps, tFree = ptf, tTotal = ptt, fluidInv = getFluidInventory()}
end
local snap = pickerHeaderSnap
si, totalCount, vaultsCount, freeSlots, totalSlots = snap.inv, snap.count, snap.vaults, snap.free, snap.slots
tFree, tTotal = snap.tFree, snap.tTotal
else
pickerHeaderSnap = nil
si, totalCount, vaultsCount, freeSlots, totalSlots = getStorageInventoryCached()
tFree, tTotal = getTankStats()
end
stockInv = si
local totalTypes = 0 for _ in pairs(Recipes) do totalTypes = totalTypes + 1 end
local freeColor = colors.gray
if totalSlots > 0 then
local pct = freeSlots / totalSlots
if pct < 0.1 then freeColor = colors.red
elseif pct < 0.25 then freeColor = colors.orange
else freeColor = colors.lime
end
end
local freeVal = string.format("%d/%d", freeSlots, totalSlots)
local freeX = math.max(1, math.floor((w - #freeVal) / 2) + 1)
drawText(freeX, 3, freeVal, freeColor, colors.black)
local statStr
if tTotal > 0 then
statStr = string.format("Tank: %d/%d | Vaults: %d | Types: %d | Total: %d", tFree, tTotal, vaultsCount, totalTypes, totalCount)
else
statStr = string.format("Vaults: %d | Types: %d | Total: %d", vaultsCount, totalTypes, totalCount)
end
local statX = math.max(1, math.floor((w - #statStr) / 2) + 1)
drawText(statX, 4, statStr, colors.gray, colors.black)
return stockInv
end
function _diB17(w, h, touchZones, popupRect, popupZoneStart)
local pW = math.min(w - 4, 58)
local pX = math.floor((w - pW) / 2) + 1
local rules2   = mgmtPopup.rules or {}
local inIsStgD = (#(mgmtPopup.inputs or {}) == 0)
local headerLines = 7 + (inIsStgD and 0 or 2)
local footerLines = 3
local maxPH = h - 2
local rulesNeeded = math.max(1, #rules2)
local pH = math.min(maxPH, headerLines + rulesNeeded * 3 + footerLines)
local rulesPerPage = math.max(1, math.floor((pH - headerLines - footerLines) / 3))
local totalRulesPages = math.max(1, math.ceil(#rules2 / rulesPerPage))
if not mgmtPopup.rulesPage or mgmtPopup.rulesPage < 1 then mgmtPopup.rulesPage = 1 end
if mgmtPopup.rulesPage > totalRulesPages then mgmtPopup.rulesPage = totalRulesPages end
local rulesPage = mgmtPopup.rulesPage
local rulesStart = (rulesPage - 1) * rulesPerPage + 1
local rulesEnd   = math.min(rulesStart + rulesPerPage - 1, #rules2)
local pY = math.floor((h - pH) / 2) + 1
popupZoneStart = #touchZones + 1
popupRect = {x1=pX, x2=pX+pW-1, y1=pY, y2=pY+pH-1}
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdr = mgmtPopup.groupIdx and " EDIT GROUP " or " NEW GROUP "
drawText(pX + math.floor((pW - #hdr) / 2), pY, hdr, colors.black, colors.cyan)
local nameDisp = mgmtPopup.name ~= "" and mgmtPopup.name or "(tap to set)"
drawText(pX + 1, pY + 2, (" Name: [ " .. nameDisp .. " ]"):sub(1, pW - 2), colors.white, colors.gray)
table.insert(touchZones, {id="mgmt_edit_name", x1=pX+1, x2=pX+pW-2, y=pY+2})
local inputDisp = mgmtIODisplay({inputs=mgmtPopup.inputs}, true)
drawText(pX + 1, pY + 3, (" Input:  " .. inputDisp):sub(1, pW - 13),
inIsStgD and colors.lime or colors.white, colors.gray)
local chgIS = " [CHANGE] "
drawText(pX + pW - #chgIS - 1, pY + 3, chgIS, colors.black, colors.orange)
table.insert(touchZones, {id="mgmt_pick_input", x1=pX+pW-#chgIS-1, x2=pX+pW-2, y=pY+3})
local outIsStgD = (#(mgmtPopup.outputs or {}) == 0)
local outputDisp = mgmtIODisplay({outputs=mgmtPopup.outputs}, false)
drawText(pX + 1, pY + 4, (" Output: " .. outputDisp):sub(1, pW - 13),
outIsStgD and colors.lime or colors.cyan, colors.gray)
local chgOS = " [CHANGE] "
drawText(pX + pW - #chgOS - 1, pY + 4, chgOS, colors.black, colors.orange)
table.insert(touchZones, {id="mgmt_pick_output", x1=pX+pW-#chgOS-1, x2=pX+pW-2, y=pY+4})
drawText(pX + 1, pY + 5, string.rep("-", pW - 2), colors.lightGray, colors.gray)
drawText(pX + 1, pY + 6, mgmtPopup.fluid and " RULES (keep mB in output):" or " RULES (input->output):", colors.yellow, colors.gray)
local addRS = " [+ADD] "
drawText(pX + pW - #addRS - 1, pY + 6, addRS, colors.black, colors.lime)
table.insert(touchZones, {id="mgmt_pick_item", x1=pX+pW-#addRS-1, x2=pX+pW-2, y=pY+6})
local ruleRowY = pY + 7
if not inIsStgD then
local drainOn = mgmtPopup.drain or false
local drainLbl = drainOn and " [EMPTY ALL]  ON  " or " [EMPTY ALL]  OFF "
local drainBg  = drainOn and colors.lime   or colors.gray
local drainFg  = drainOn and colors.black  or colors.lightGray
drawText(pX + 1, ruleRowY, drainLbl:sub(1, pW - 2), drainFg, drainBg)
table.insert(touchZones, {id="mgmt_toggle_drain", x1=pX+1, x2=pX+pW-2, y=ruleRowY})
ruleRowY = ruleRowY + 1
end
if not inIsStgD then
local provOn = mgmtPopup.provider or false
drawText(pX + 1, ruleRowY,
(provOn and " [PROVIDER] ON (pull-only src) " or " [PROVIDER] OFF"):sub(1, pW - 2),
provOn and colors.black or colors.lightGray,
provOn and colors.orange or colors.gray)
table.insert(touchZones, {id="mgmt_toggle_provider", x1=pX+1, x2=pX+pW-2, y=ruleRowY})
ruleRowY = ruleRowY + 1
end
if #rules2 == 0 then
drawText(pX + 2, ruleRowY, "(none)", colors.lightGray, colors.gray)
ruleRowY = ruleRowY + 1
else
for ri2 = rulesStart, rulesEnd do
local rule = rules2[ri2]
local rName2 = (rule.item:match(":(.+)$") or rule.item)
local delR = " [X] "; local plusR = " [+] "; local minR = " [-] "; local typR = " [#] "
local amtR = tostring(rule.amount)
local ctrlW2 = #minR + #amtR + #plusR + #typR + #delR
local ctrlX2 = pX + pW - ctrlW2 - 2
drawText(pX + 2,   ruleRowY, rName2:sub(1, ctrlX2 - pX - 3), colors.white,  colors.gray)
drawText(ctrlX2,                                    ruleRowY, minR, colors.white,  colors.gray)
drawText(ctrlX2 + #minR,                            ruleRowY, amtR, colors.yellow, colors.gray)
drawText(ctrlX2 + #minR + #amtR,                    ruleRowY, plusR,colors.white,  colors.gray)
drawText(ctrlX2 + #minR + #amtR + #plusR,           ruleRowY, typR, colors.black,  colors.orange)
drawText(ctrlX2 + #minR + #amtR + #plusR + #typR,   ruleRowY, delR, colors.white,  colors.red)
table.insert(touchZones, {id="mgmt_rule_adj",  arg={ri2,-1}, x1=ctrlX2, x2=ctrlX2+#minR-1, y=ruleRowY})
table.insert(touchZones, {id="mgmt_rule_adj",  arg={ri2, 1}, x1=ctrlX2+#minR+#amtR, x2=ctrlX2+#minR+#amtR+#plusR-1, y=ruleRowY})
table.insert(touchZones, {id="mgmt_rule_type", arg=ri2,      x1=ctrlX2+#minR+#amtR+#plusR, x2=ctrlX2+#minR+#amtR+#plusR+#typR-1, y=ruleRowY})
table.insert(touchZones, {id="mgmt_rule_del",  arg=ri2,      x1=ctrlX2+#minR+#amtR+#plusR+#typR, x2=ctrlX2+ctrlW2-1, y=ruleRowY})
ruleRowY = ruleRowY + 1
drawText(pX + 1, ruleRowY, string.rep("-", pW - 2), colors.lightGray, colors.gray)
ruleRowY = ruleRowY + 1
drawMgmtCondRow(pX, pW, ruleRowY, rule, ri2, touchZones)
ruleRowY = ruleRowY + 1
end
end
local footY2 = pY + pH - 2
if totalRulesPages > 1 then
local pagerY = footY2 - 1
local prevS3 = " < PREV "; local nextS3 = " NEXT > "
local pgStr3 = string.format("Page %d/%d", rulesPage, totalRulesPages)
local pgX3   = pX + math.floor((pW - #pgStr3) / 2)
local pPrev3 = pX + 2
local pNext3 = pX + pW - #nextS3 - 2
drawText(pPrev3, pagerY, prevS3, rulesPage > 1            and colors.white or colors.gray, colors.gray)
drawText(pgX3,   pagerY, pgStr3, colors.lightGray, colors.gray)
drawText(pNext3, pagerY, nextS3, rulesPage < totalRulesPages and colors.white or colors.gray, colors.gray)
if rulesPage > 1 then
table.insert(touchZones, {id="mgmt_rules_prev", x1=pPrev3, x2=pPrev3+#prevS3-1, y=pagerY})
end
if rulesPage < totalRulesPages then
table.insert(touchZones, {id="mgmt_rules_next", x1=pNext3, x2=pNext3+#nextS3-1, y=pagerY})
end
end
local saveS2 = " [SAVE] "; local cancelS2 = " [CANCEL] "
drawText(pX + 2,                  footY2 + 1, saveS2,   colors.black, colors.lime)
drawText(pX + pW - #cancelS2 - 2, footY2 + 1, cancelS2, colors.white, colors.gray)
table.insert(touchZones, {id="mgmt_save",   x1=pX+2,               x2=pX+2+#saveS2-1,  y=footY2+1})
table.insert(touchZones, {id="mgmt_cancel", x1=pX+pW-#cancelS2-2,  x2=pX+pW-2,         y=footY2+1})
return popupRect, popupZoneStart
end
function _diB18(w, h, touchZones, popupRect, popupZoneStart)
local allPeri2 = {"STORAGE"}
local tmpP2 = {}
for _, pn in ipairs(peripheral.getNames()) do
if not SYSTEM_SIDES[pn] and pn ~= MONITOR_SIDE and pn ~= Config.train_box then
table.insert(tmpP2, pn)
end
end
table.sort(tmpP2, function(a, b)
return (getMachineDisplay(a) or a):lower() < (getMachineDisplay(b) or b):lower()
end)
for _, v in ipairs(tmpP2) do table.insert(allPeri2, v) end
local pW2 = math.min(w - 10, 70)
local pX2 = math.floor((w - pW2) / 2) + 1
local pH2 = math.min(h - 4, 16)
local pY2 = math.floor((h - pH2) / 2) + 1
local cols2 = 3
local colW2 = math.floor((pW2 - 2) / cols2)
local listTop2 = pY2 + 2
local maxRows2 = pH2 - 5
local perPage2 = cols2 * maxRows2
local pPage2  = mgmtPopup.periPage or 1
local pTotal2 = math.max(1, math.ceil(#allPeri2 / perPage2))
if pPage2 > pTotal2 then pPage2 = pTotal2; mgmtPopup.periPage = pPage2 end
local pStart2 = (pPage2 - 1) * perPage2 + 1
local pEnd2   = math.min(pStart2 + perPage2 - 1, #allPeri2)
popupZoneStart = #touchZones + 1
popupRect = {x1=pX2, x2=pX2+pW2-1, y1=pY2, y2=pY2+pH2-1}
_bufFillRect(pX2, pY2, pW2, pH2, colors.gray)
local hdr2 = " SELECT INPUTS (tap to toggle) "
drawText(pX2 + math.floor((pW2 - #hdr2) / 2), pY2, hdr2, colors.black, colors.orange)
for ci = 1, cols2 - 1 do
local sepX = pX2 + 1 + ci * colW2
for ry = 0, maxRows2 - 1 do
drawText(sepX, listTop2 + ry, "|", colors.lightGray, colors.gray)
end
end
local selIn2 = mgmtPopup.inputs or {}
local selSet2 = {}
for _, nm in ipairs(selIn2) do selSet2[nm] = true end
local inStgSel2 = (#selIn2 == 0)
for pi2 = pStart2, pEnd2 do
local localIdx = pi2 - pStart2
local col = math.floor(localIdx / maxRows2)
local row = localIdx % maxRows2
local cellX = pX2 + 2 + col * colW2
local cellY = listTop2 + row
local pn2 = allPeri2[pi2]
local isStg2  = (pn2 == "STORAGE")
local isSel2  = (isStg2 and inStgSel2) or (not isStg2 and selSet2[pn2] == true)
local bgC2 = isSel2 and colors.cyan or (isStg2 and colors.lime or colors.gray)
local fgC2 = (isSel2 or isStg2) and colors.black or colors.white
local pn2Disp = isStg2 and pn2 or getMachineDisplay(pn2)
if #pn2Disp > colW2 - 2 then pn2Disp = pn2Disp:sub(1, colW2 - 2) end
drawText(cellX, cellY, pn2Disp, fgC2, bgC2)
table.insert(touchZones, {id="mgmt_set_input", arg=pn2, x1=cellX, x2=cellX+colW2-2, y=cellY})
end
local navY2 = pY2 + pH2 - 2
local arrL = " < "; local arrR = " > "
local lAct2 = (pPage2 > 1)
local rAct2 = (pPage2 < pTotal2)
drawText(pX2 + 2, navY2, arrL, lAct2 and colors.white or colors.gray, colors.gray)
if lAct2 then
table.insert(touchZones, {id="mgmt_peri_prev", x1=pX2+2, x2=pX2+2+#arrL-1, y=navY2})
end
drawText(pX2 + pW2 - #arrR - 2, navY2, arrR, rAct2 and colors.white or colors.gray, colors.gray)
if rAct2 then
table.insert(touchZones, {id="mgmt_peri_next", x1=pX2+pW2-#arrR-2, x2=pX2+pW2-3, y=navY2})
end
local canS2 = " [DONE] "
drawText(pX2 + math.floor((pW2 - #canS2) / 2), pY2 + pH2 - 1, canS2, colors.black, colors.lime)
table.insert(touchZones, {id="mgmt_peri_cancel", x1=pX2+math.floor((pW2 - #canS2)/2), x2=pX2+math.floor((pW2 - #canS2)/2)+#canS2-1, y=pY2+pH2-1})
return popupRect, popupZoneStart
end
function _diB19(w, h, touchZones, popupRect, popupZoneStart)
local allPeri6 = {"STORAGE"}
local tmpP6 = {}
for _, pn6 in ipairs(peripheral.getNames()) do
if not SYSTEM_SIDES[pn6] and pn6 ~= MONITOR_SIDE and pn6 ~= Config.train_box then
table.insert(tmpP6, pn6)
end
end
table.sort(tmpP6, function(a, b)
return (getMachineDisplay(a) or a):lower() < (getMachineDisplay(b) or b):lower()
end)
for _, v in ipairs(tmpP6) do table.insert(allPeri6, v) end
local pW6 = math.min(w - 10, 70)
local pX6 = math.floor((w - pW6) / 2) + 1
local pH6 = math.min(h - 4, 16)
local pY6 = math.floor((h - pH6) / 2) + 1
local cols6 = 3
local colW6 = math.floor((pW6 - 2) / cols6)
local listTop6 = pY6 + 2
local maxRows6 = pH6 - 5
local perPage6 = cols6 * maxRows6
local opPage  = mgmtPopup.outPeriPage or 1
local opTotal = math.max(1, math.ceil(#allPeri6 / perPage6))
if opPage > opTotal then opPage = opTotal; mgmtPopup.outPeriPage = opPage end
local opStart = (opPage - 1) * perPage6 + 1
local opEnd   = math.min(opStart + perPage6 - 1, #allPeri6)
popupZoneStart = #touchZones + 1
popupRect = {x1=pX6, x2=pX6+pW6-1, y1=pY6, y2=pY6+pH6-1}
_bufFillRect(pX6, pY6, pW6, pH6, colors.gray)
local hdr6 = " SELECT OUTPUTS (tap to toggle) "
drawText(pX6 + math.floor((pW6 - #hdr6) / 2), pY6, hdr6, colors.black, colors.cyan)
for ci = 1, cols6 - 1 do
local sepX = pX6 + 1 + ci * colW6
for ry = 0, maxRows6 - 1 do
drawText(sepX, listTop6 + ry, "|", colors.lightGray, colors.gray)
end
end
local selOut6 = mgmtPopup.outputs or {}
local selSet6 = {}
for _, nm in ipairs(selOut6) do selSet6[nm] = true end
local outStgSel6 = (#selOut6 == 0)
for op2 = opStart, opEnd do
local localIdx = op2 - opStart
local col = math.floor(localIdx / maxRows6)
local row = localIdx % maxRows6
local cellX = pX6 + 2 + col * colW6
local cellY = listTop6 + row
local pn6b = allPeri6[op2]
local isStg6  = (pn6b == "STORAGE")
local isSel6  = (isStg6 and outStgSel6) or (not isStg6 and selSet6[pn6b] == true)
local bgC6 = isSel6 and colors.cyan or (isStg6 and colors.lime or colors.gray)
local fgC6 = (isSel6 or isStg6) and colors.black or colors.white
local pn6bDisp = isStg6 and pn6b or getMachineDisplay(pn6b)
if #pn6bDisp > colW6 - 2 then pn6bDisp = pn6bDisp:sub(1, colW6 - 2) end
drawText(cellX, cellY, pn6bDisp, fgC6, bgC6)
table.insert(touchZones, {id="mgmt_set_output", arg=pn6b, x1=cellX, x2=cellX+colW6-2, y=cellY})
end
local navY6 = pY6 + pH6 - 2
local arrL6 = " < "; local arrR6 = " > "
local lAct6 = (opPage > 1)
local rAct6 = (opPage < opTotal)
drawText(pX6 + 2, navY6, arrL6, lAct6 and colors.white or colors.gray, colors.gray)
if lAct6 then
table.insert(touchZones, {id="mgmt_outperi_prev", x1=pX6+2, x2=pX6+2+#arrL6-1, y=navY6})
end
drawText(pX6 + pW6 - #arrR6 - 2, navY6, arrR6, rAct6 and colors.white or colors.gray, colors.gray)
if rAct6 then
table.insert(touchZones, {id="mgmt_outperi_next", x1=pX6+pW6-#arrR6-2, x2=pX6+pW6-3, y=navY6})
end
local canS6 = " [DONE] "
drawText(pX6 + math.floor((pW6 - #canS6) / 2), pY6 + pH6 - 1, canS6, colors.black, colors.lime)
table.insert(touchZones, {id="mgmt_outperi_cancel", x1=pX6+math.floor((pW6 - #canS6)/2), x2=pX6+math.floor((pW6 - #canS6)/2)+#canS6-1, y=pY6+pH6-1})
return popupRect, popupZoneStart
end
function _diB20(w, h, touchZones, popupRect)
craftErrorLines = {}; craftErrorTitle = nil
local fp = fluidRecipePicker
local sName = fp.fluid:match(":(.+)$") or fp.fluid
local rows = fp.producers
local pW = math.min(w - 4, 76)
local pH = math.min(#rows + 6, h - 4)
local pX = math.max(1, math.floor((w - pW) / 2) + 1)
local pY = math.max(1, math.floor((h - pH) / 2) + 1)
popupRect = {x1=pX, x2=pX+pW-1, y1=pY, y2=pY+pH-1}
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdr = " RECIPE PRIORITY: " .. sName:upper() .. " "
drawText(pX + math.floor((pW - #hdr) / 2), pY, hdr, colors.black, colors.lime)
drawText(pX + 2, pY + 1, "[*]=make primary  [X]=delete  top=tried first", colors.gray, colors.gray)
local awaiting = (fluidCraftWaitFluid == fp.fluid)
local lineY = pY + 3
for idx, p in ipairs(rows) do
if lineY >= pY + pH - 1 then break end
local mDisp = getMachineDisplay(p.recipe.machine_name) or p.recipe.machine_name or "?"
local inParts = {}
for _, inp in ipairs(p.recipe.inputs or {}) do
local sn = inp.name:match(":(.+)$") or inp.name
inParts[#inParts + 1] = string.format("%s %d", sn, inp.amount)
end
for _, it in ipairs(p.recipe.item_inputs or {}) do
local sn = it.name:match(":(.+)$") or it.name
inParts[#inParts + 1] = string.format("%dx %s", it.count, sn)
end
local outParts = {}
for _, o in ipairs(p.recipe.outputs or {}) do
local sn = o.name:match(":(.+)$") or o.name
outParts[#outParts + 1] = string.format("%s %d", sn, o.amount)
end
for _, o in ipairs(p.recipe.item_outputs or {}) do
local sn = o.name:match(":(.+)$") or o.name
outParts[#outParts + 1] = string.format("%dx %s", o.count, sn)
end
local rank
if p.isPrimary then rank = "[PRIMARY] "
elseif p.own then rank = "[#" .. idx .. "] "
else rank = "[~] " end
local desc = rank .. string.format("%s: %s -> %s", mDisp, table.concat(inParts, " + "), table.concat(outParts, " + "))
local crfStr = "[CRAFT]"
local delStr = "[X]"
local starStr = "[*]"
local delX = pX + pW - 2 - #delStr
local crfX = delX - 1 - #crfStr
local starX = crfX - 1 - #starStr
local maxDesc = starX - 1 - (pX + 2)
drawText(pX + 2, lineY, desc:sub(1, math.max(1, maxDesc)), p.isPrimary and colors.yellow or colors.white, colors.gray)
if p.own and not p.isPrimary then
drawText(starX, lineY, starStr, colors.black, colors.cyan)
table.insert(touchZones, 1, {id="fluid_make_primary", arg=idx, x1=starX, x2=starX+#starStr-1, y=lineY})
end
if awaiting then
drawText(crfX - 1, lineY, "-", colors.lime, colors.gray)
drawText(crfX + #crfStr, lineY, "-", colors.lime, colors.gray)
end
drawText(crfX, lineY, crfStr, colors.black, awaiting and colors.yellow or colors.lime)
table.insert(touchZones, 1, {id="fluid_pick_recipe", arg=idx, x1=crfX, x2=crfX+#crfStr-1, y=lineY})
if p.own then
drawText(delX, lineY, delStr, colors.black, colors.red)
table.insert(touchZones, 1, {id="fluid_picker_delete", arg=idx, x1=delX, x2=delX+#delStr-1, y=lineY})
end
lineY = lineY + 1
end
local clsStr = " [ CLOSE ] "
local clsX = pX + math.floor((pW - #clsStr) / 2)
local clsY = pY + pH - 1
drawText(clsX, clsY, clsStr, colors.white, colors.gray)
table.insert(touchZones, 1, {id="fluid_picker_close", x1=clsX, x2=clsX+#clsStr-1, y=clsY})
return popupRect
end
function _diB21(w, h, touchZones, popupRect, data)
local sName = craftInfoPopup.item:match(":(.+)$") or craftInfoPopup.item
local contentLines = {}
local blockedFull = {}
for bItem in pairs(data.blocked or {}) do
table.insert(blockedFull, bItem)
end
table.sort(blockedFull)
if #blockedFull > 0 then
for _, bFull in ipairs(blockedFull) do
local bShort = bFull:match(":(.+)$") or bFull
table.insert(contentLines, {text = bShort .. ":", color = colors.red})
local details = data.blockedDetails and data.blockedDetails[bFull]
if details and details.missing and next(details.missing) then
local mList = {}
for mItem, mCount in pairs(details.missing) do
table.insert(mList, {name = mItem:match(":(.+)$") or mItem, count = mCount})
end
table.sort(mList, function(a, b) return a.name < b.name end)
for _, m in ipairs(mList) do
table.insert(contentLines, {text = "  " .. m.name .. "  x" .. m.count, color = colors.white})
end
end
table.insert(contentLines, {text = "", color = colors.gray})
end
else
local mList = {}
for mItem, mCount in pairs(data.missing or {}) do
table.insert(mList, {name = mItem:match(":(.+)$") or mItem, count = mCount})
end
table.sort(mList, function(a, b) return a.name < b.name end)
for _, m in ipairs(mList) do
table.insert(contentLines, {text = m.name .. "  x" .. m.count, color = colors.white})
end
end
if #contentLines == 0 then
table.insert(contentLines, {text = "Craftable from stock (no shortage).", color = colors.lime})
end
local pW  = 44
local pH  = math.min(#contentLines + 5, h - 8)
local pX  = math.max(1, math.floor((w - pW) / 2) + 1)
local pY  = math.max(1, math.floor((h - pH) / 2) + 1)
popupRect = {x1=pX, x2=pX+pW-1, y1=pY, y2=pY+pH-1}
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdrStr = " ANALYSIS: " .. sName:upper():sub(1, pW - 13) .. " "
drawText(pX + math.floor((pW - #hdrStr) / 2), pY, hdrStr, colors.black, colors.red)
local lineY = pY + 2
for _, line in ipairs(contentLines) do
if lineY >= pY + pH - 2 then break end
if line.text ~= "" then
drawText(pX + 2, lineY, line.text:sub(1, pW - 4), line.color, colors.gray)
end
lineY = lineY + 1
end
local clsStr = " [ CLOSE ] "
local clsX   = pX + math.floor((pW - #clsStr) / 2)
local clsY   = pY + pH - 1
drawText(clsX, clsY, clsStr, colors.white, colors.gray)
table.insert(touchZones, 1, {id="close_craft_info", x1=clsX, x2=clsX+#clsStr-1, y=clsY})
return popupRect
end
function _diB22(w, h, touchZones, popupRect)
craftErrorLines = {}; craftErrorTitle = nil
craftInfoPopup = nil
recipeEditPopup = nil
local popup = craftCompletePopup
local outs = popup.outputs
local bodyLines = outs and #outs or 1
local pW = 40
local pH = math.max(7, bodyLines + 5)
local pX = math.max(1, math.floor((w - pW) / 2) + 1)
local pY = math.max(9, math.floor((h - pH) / 2) + 1)
popupRect = {x1=pX, x2=pX+pW-1, y1=pY, y2=pY+pH-1}
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdrStr = popup.learned and " RECIPE LEARNED " or " CRAFT COMPLETE "
drawText(pX + math.floor((pW - #hdrStr) / 2), pY, hdrStr, colors.black, colors.lime)
local clsStr = " [CLOSE] "
local btnY = pY + pH - 2
local clsX = pX + pW - #clsStr - 2
if outs then
drawText(pX + 2, pY + 2, "Output:", colors.white, colors.gray)
local ly = pY + 3
for _, o in ipairs(outs) do
local on = o.name:match(":(.+)$") or o.name
local unit = o.unit or "mB"
local txt = (unit == "x") and (on .. ": " .. o.amount .. "x") or (on .. ": " .. o.amount .. " mB")
drawText(pX + 4, ly, txt:sub(1, pW - 6), colors.lime, colors.gray)
ly = ly + 1
end
elseif popup.isFluid then
local sName = popup.item:match(":(.+)$") or popup.item
drawText(pX + 2, pY + 2, ("Fluid: " .. sName):sub(1, pW - 4), colors.white, colors.gray)
drawText(pX + 2, pY + 3, "Made: " .. popup.count .. " mB", colors.lime, colors.gray)
else
local sName = popup.item:match(":(.+)$") or popup.item
drawText(pX + 2, pY + 2, ("Item: " .. sName):sub(1, pW - 4), colors.white, colors.gray)
drawText(pX + 2, pY + 3, "Stock: " .. popup.count .. " pcs.", colors.lime, colors.gray)
local reqStr = " [REQUEST] "
local reqX = pX + 2
drawText(reqX, btnY, reqStr, colors.black, colors.cyan)
table.insert(touchZones, 1, {id="popup_request", x1=reqX, x2=reqX+#reqStr-1, y=btnY})
end
drawText(clsX, btnY, clsStr, colors.white, colors.black)
table.insert(touchZones, 1, {id="popup_close", x1=clsX, x2=clsX+#clsStr-1, y=btnY})
return popupRect
end
function _diB23(w, h, touchZones, popupRect)
craftErrorLines = {}; craftErrorTitle = nil
local sc = fluidSaveConfirm
local rec = sc.recipe
local inParts = {}
for _, inp in ipairs(rec.inputs or {}) do
inParts[#inParts + 1] = (inp.name:match(":(.+)$") or inp.name) .. " " .. inp.amount
end
for _, it in ipairs(rec.item_inputs or {}) do
inParts[#inParts + 1] = it.count .. "x " .. (it.name:match(":(.+)$") or it.name)
end
local outParts = {}
for _, o in ipairs(rec.outputs or {}) do
outParts[#outParts + 1] = (o.name:match(":(.+)$") or o.name) .. " " .. o.amount .. "mB"
end
for _, o in ipairs(rec.item_outputs or {}) do
outParts[#outParts + 1] = o.count .. "x " .. (o.name:match(":(.+)$") or o.name)
end
local pW = math.min(w - 6, 64)
local pH = 9
local pX = math.max(1, math.floor((w - pW) / 2) + 1)
local pY = math.max(1, math.floor((h - pH) / 2) + 1)
popupRect = {x1=pX, x2=pX+pW-1, y1=pY, y2=pY+pH-1}
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdr = " SAVE LEARNED RECIPE? "
drawText(pX + math.floor((pW - #hdr) / 2), pY, hdr, colors.black, colors.lime)
local mDisp = getMachineDisplay(rec.machine_name) or rec.machine_name or "?"
drawText(pX + 2, pY + 2, ("Machine: " .. mDisp):sub(1, pW - 4), colors.white, colors.gray)
drawText(pX + 2, pY + 3, ("In:  " .. table.concat(inParts, " + ")):sub(1, pW - 4), colors.lightGray, colors.gray)
drawText(pX + 2, pY + 4, ("Out: " .. table.concat(outParts, " + ")):sub(1, pW - 4), colors.cyan, colors.gray)
local modeStr = sc.asAlt and "Will be saved as ALT (priority recipe exists)" or "Will be saved as PRIMARY"
drawText(pX + 2, pY + 5, modeStr:sub(1, pW - 4), sc.asAlt and colors.orange or colors.lime, colors.gray)
local yesStr = " [ SAVE ] "
local noStr  = " [ DISCARD ] "
drawText(pX + 2, pY + pH - 1, yesStr, colors.black, colors.lime)
table.insert(touchZones, 1, {id="fluid_save_yes", x1=pX+2, x2=pX+2+#yesStr-1, y=pY+pH-1})
drawText(pX + pW - #noStr - 2, pY + pH - 1, noStr, colors.white, colors.red)
table.insert(touchZones, 1, {id="fluid_save_no", x1=pX+pW-#noStr-2, x2=pX+pW-3, y=pY+pH-1})
return popupRect
end
function _diB24(w, h, touchZones, popupRect)
local sName = fluidCraftInfo.name:match(":(.+)$") or fluidCraftInfo.name
local mList = {}
for mKey, mAmt in pairs(fluidCraftInfo.missing or {}) do
if mKey ~= "__fl" and type(mAmt) == "number" and mAmt > 0 then
local isFl = (type(mKey) == "string" and mKey:sub(1, 2) == "f:")
local nm = isFl and fluidNameFromKey(mKey) or mKey
nm = nm:match(":(.+)$") or nm
mList[#mList + 1] = {name = nm, amt = mAmt, isFl = isFl}
end
end
table.sort(mList, function(a, b) return a.name < b.name end)
local contentLines = {}
for _, m in ipairs(mList) do
local suf = m.isFl and (" x" .. m.amt .. " mB") or ("  x" .. m.amt)
contentLines[#contentLines + 1] = {text = m.name .. suf, color = m.isFl and colors.cyan or colors.white}
end
if #contentLines == 0 then
contentLines[#contentLines + 1] = {text = "Craftable from stock (no shortage).", color = colors.lime}
end
local pW = 44
local pH = math.min(#contentLines + 5, h - 8)
local pX = math.max(1, math.floor((w - pW) / 2) + 1)
local pY = math.max(1, math.floor((h - pH) / 2) + 1)
popupRect = {x1=pX, x2=pX+pW-1, y1=pY, y2=pY+pH-1}
_bufFillRect(pX, pY, pW, pH, colors.gray)
local hdrStr = " MISSING: " .. sName:upper():sub(1, pW - 12) .. " "
drawText(pX + math.floor((pW - #hdrStr) / 2), pY, hdrStr, colors.black, colors.red)
local lineY = pY + 2
for _, line in ipairs(contentLines) do
if lineY >= pY + pH - 2 then break end
drawText(pX + 2, lineY, line.text:sub(1, pW - 4), line.color, colors.gray)
lineY = lineY + 1
end
local clsStr = " [ CLOSE ] "
local clsX = pX + math.floor((pW - #clsStr) / 2)
local clsY = pY + pH - 1
drawText(clsX, clsY, clsStr, colors.white, colors.gray)
table.insert(touchZones, 1, {id="close_fluid_info", x1=clsX, x2=clsX+#clsStr-1, y=clsY})
return popupRect
end
function _diB26(w, grp2, h, touchZones, popupRect, popupZoneStart)
local pW = math.min(w - 4, 58)
local pX = math.floor((w - pW) / 2) + 1
local inIsStgV  = (not grp2.input  or grp2.input  == "" or grp2.input  == "STORAGE")
local outIsStgV = (not grp2.output or grp2.output == "" or grp2.output == "STORAGE")
local viewItems = {}
for _, rule in ipairs(grp2.rules or {}) do
table.insert(viewItems, {name=rule.item, amount=rule.amount, condition=rule.condition})
end
table.sort(viewItems, function(a,b) return a.name < b.name end)
local isFluidV = mgmtGroupIsFluid(grp2)
local stgSnapV = isFluidV and mgmtFluidStockSnap() or getStorageInventoryCached()
local inputCounts = {}
if inIsStgV then
for _, vi in ipairs(viewItems) do
inputCounts[vi.name] = stgSnapV[vi.name] or 0
end
elseif isFluidV then
inputCounts = tankContents(grp2.input)
else
local inP4 = peripheral.wrap(grp2.input)
if inP4 and inP4.list then
local ok4, items4 = pcall(inP4.list)
if ok4 and items4 then
for _, it4 in pairs(items4) do
if it4 then inputCounts[it4.name] = (inputCounts[it4.name] or 0) + it4.count end
end
end
end
end
local outCounts = {}
if outIsStgV then
outCounts = stgSnapV
elseif isFluidV then
outCounts = tankContents(grp2.output)
else
local outP4 = peripheral.wrap(grp2.output)
if outP4 and outP4.list then
local ok5, outIt4 = pcall(outP4.list)
if ok5 and outIt4 then
for _, oi4 in pairs(outIt4) do
if oi4 then outCounts[oi4.name] = (outCounts[oi4.name] or 0) + oi4.count end
end
end
end
end
local viPP    = 5
local viPage  = mgmtPopup.page or 1
local viTotal = math.max(1, math.ceil(#viewItems / viPP))
if viPage > viTotal then viPage = viTotal; mgmtPopup.page = viPage end
local viStart = (viPage - 1) * viPP + 1
local viEnd   = math.min(viStart + viPP - 1, #viewItems)
local visRows = 0
for vi2 = viStart, viEnd do
visRows = visRows + 1
local itm2 = viewItems[vi2]
if itm2.condition and itm2.condition.item and itm2.condition.item ~= "" then
visRows = visRows + 1
end
end
if visRows == 0 then visRows = 1 end
local pH4 = math.max(10, math.min(visRows + 6, h - 2))
local pY4 = math.floor((h - pH4) / 2) + 1
popupZoneStart = #touchZones + 1
popupRect = {x1=pX, x2=pX+pW-1, y1=pY4, y2=pY4+pH4-1}
_bufFillRect(pX, pY4, pW, pH4, colors.gray)
local gName2 = (grp2.name ~= "" and grp2.name or "(unnamed)"):upper()
local hdr4   = " VIEW: " .. gName2:sub(1, pW - 11) .. " "
drawText(pX + math.floor((pW - #hdr4) / 2), pY4, hdr4, colors.black, colors.orange)
local C_RULE   = pX + pW - 20
local C_INPUT  = pX + pW - 13
local C_OUTPUT = pX + pW - 6
local nameMax  = pW - 23
local inLbl  = inIsStgV  and "STORAGE" or (grp2.input:match(":(.+)$")  or grp2.input):sub(1,10)
local outLbl = outIsStgV and "STORAGE" or (grp2.output:match(":(.+)$") or grp2.output):sub(1,10)
local ioLbl4 = ("In: " .. inLbl .. " -> Out: " .. outLbl):sub(1, nameMax + 1)
drawText(pX + 2,   pY4 + 1, ioLbl4, colors.lightGray, colors.gray)
drawText(C_RULE,   pY4 + 1, "  RULE", colors.yellow,  colors.gray)
drawText(C_INPUT,  pY4 + 1, " INPUT", colors.cyan,    colors.gray)
drawText(C_OUTPUT, pY4 + 1, "OUTPUT", colors.lime,    colors.gray)
if #viewItems == 0 then
drawText(pX + 2, pY4 + 2, "(no rules defined)", colors.lightGray, colors.gray)
else
local curViY = pY4 + 2
for vi = viStart, viEnd do
local itm3   = viewItems[vi]
local iShort = (itm3.name:match(":(.+)$") or itm3.name):sub(1, nameMax)
drawText(pX + 2, curViY, iShort, colors.white, colors.gray)
local rS = tostring(itm3.amount)
drawText(C_RULE  + math.max(0, 6-#rS), curViY, rS:sub(1,6), colors.yellow, colors.gray)
local iS = tostring(inputCounts[itm3.name] or 0)
drawText(C_INPUT + math.max(0, 6-#iS), curViY, iS:sub(1,6), colors.cyan,   colors.gray)
local oS = tostring(outCounts[itm3.name] or 0)
drawText(C_OUTPUT + math.max(0, 6-#oS), curViY, oS:sub(1,6), colors.lime,  colors.gray)
curViY = curViY + 1
local cond3 = itm3.condition
if cond3 and cond3.item and cond3.item ~= "" then
local cItemShort = (cond3.item:match(":(.+)$") or cond3.item)
local opStr3  = cond3.op or "<"
local cVal3   = cond3.value or 1
local condStock = stgSnapV[cond3.item] or 0
local condMet = false
if opStr3 == "<" then condMet = condStock < cVal3
elseif opStr3 == ">" then condMet = condStock > cVal3
elseif opStr3 == "=" then condMet = condStock == cVal3
end
local stockColor = condMet and colors.lime or colors.orange
local ifDetail = "-- IF " .. cItemShort:sub(1, nameMax - 6) .. " " .. opStr3 .. " " .. tostring(cVal3)
drawText(pX + 2, curViY, ifDetail:sub(1, nameMax + 2), colors.cyan, colors.gray)
local cStockStr = tostring(condStock)
drawText(C_OUTPUT + math.max(0, 6-#cStockStr), curViY, cStockStr:sub(1,6), stockColor, colors.gray)
curViY = curViY + 1
end
end
end
local navY4 = pY4 + pH4 - 3
if viTotal > 1 then
if viPage > 1 then
drawText(pX + 2, navY4, " [<] ", colors.white, colors.black)
table.insert(touchZones, {id="mgmt_vinput_prev", x1=pX+2, x2=pX+6, y=navY4})
end
local pgStr4 = viPage .. "/" .. viTotal
drawText(pX + math.floor((pW - #pgStr4) / 2), navY4, pgStr4, colors.lightGray, colors.gray)
if viPage < viTotal then
drawText(pX + pW - 7, navY4, " [>] ", colors.white, colors.black)
table.insert(touchZones, {id="mgmt_vinput_next", x1=pX+pW-7, x2=pX+pW-3, y=navY4})
end
end
local clsS2 = " [CLOSE] "
drawText(pX + math.floor((pW - #clsS2) / 2), pY4 + pH4 - 1, clsS2, colors.white, colors.gray)
table.insert(touchZones, {id="mgmt_close_view",
x1=pX+math.floor((pW-#clsS2)/2), x2=pX+math.floor((pW-#clsS2)/2)+#clsS2-1, y=pY4+pH4-1})
return popupRect, popupZoneStart
end
drawInterface = function()
local w, h = monitor.getSize()
_bufInit(w, h)
local popupRect = nil
local popupZoneStart = 1
do
local logoStr = ">>[ A . E . G . I . S ]<<"
local logoX = math.floor((w - #logoStr) / 2) + 1 if logoX < 1 then logoX = 1 end
drawText(logoX, 2, ">>[ ", colors.lime, colors.black)
drawText(logoX + 4, 2, "A . E . G . I . S", colors.white, colors.black)
drawText(logoX + 21, 2, " ]<<", colors.lime, colors.black)
end
local stockInv
stockInv = _diB16(w, stockInv)
drawText(1, 5, string.rep("-", w), colors.gray)
local tabY = 6
local touchZones = {}
local displayTab = (currentTab == "QUANTITY_PICKER") and qtyOriginTab or currentTab
do
local nextX = 2
nextX = drawTabButton(nextX, tabY, "RECIPES",  displayTab, touchZones)
nextX = drawTabButton(nextX, tabY, "STOCK",    displayTab, touchZones)
nextX = drawTabButton(nextX, tabY, "LOGISTIC", displayTab, touchZones)
nextX = drawTabButton(nextX, tabY, "KEEP",     displayTab, touchZones)
nextX = drawTabButton(nextX, tabY, "+RECIPES", displayTab, touchZones)
nextX = drawTabButton(nextX, tabY, "GROUPS",   displayTab, touchZones)
nextX = drawTabButton(nextX, tabY, "NETWORK",  displayTab, touchZones)
nextX = drawTabButton(nextX, tabY, "GIT",      displayTab, touchZones)
end
drawText(1, tabY + 2, string.rep("-", w), colors.gray)
if Config.autostock_paused then
drawText(2, h, "[AUTOSTOCK PAUSED]", colors.white, colors.red)
else
if autostockCurrentItem ~= "" then
local asName = autostockCurrentItem:match(":(.+)$") or autostockCurrentItem
local asStr = "[AS> " .. asName .. "]"
drawText(2, h, asStr:sub(1, math.floor(w / 2) - 2), colors.lime, colors.black)
end
local statusStr = "[SYS IDLE]"
local statusColor = colors.gray
if systemStatus == "MANUAL_CRAFT" then
statusStr = "[MANUAL CRAFTING...]"
statusColor = colors.yellow
elseif systemStatus == "AUTO_CRAFT" then
statusStr = "[AUTOCRAFT ACTIVE]"
statusColor = colors.lime
end
drawText(w - #statusStr - 1, h, statusStr, statusColor, colors.black)
end
if displayTab == "RECIPES" then
_diB15(w, h, stockInv, touchZones)
elseif displayTab == "ALT_VIEW" then
_diB12(w, h, touchZones)
elseif displayTab == "KEEP" then
_diB7(w, h, stockInv, touchZones)
elseif displayTab == "STOCK" then
_diB6(w, h, stockInv, touchZones)
elseif displayTab == "+RECIPES" then
_diB2(w, h, touchZones)
elseif displayTab == "GROUPS" then
popupRect = _diB1(w, h, touchZones, popupRect)
elseif displayTab == "NETWORK" then
_diB13(w, h, touchZones)
elseif displayTab == "GIT" then
_diB3(w, h, touchZones)
elseif displayTab == "LOGISTIC" then
_diB11(w, h, touchZones)
if mgmtPopup then
local pW = math.min(w - 4, 58)
local pX = math.floor((w - pW) / 2) + 1
if mgmtPopup.mode == "edit" then
local step = mgmtPopup.step or "main"
if step == "main" then
popupRect, popupZoneStart = _diB17(w, h, touchZones, popupRect, popupZoneStart)
elseif step == "input_select" then
popupRect, popupZoneStart = _diB18(w, h, touchZones, popupRect, popupZoneStart)
elseif step == "item_select" then
local inIsStg3 = (mgmtPopup.condPickRuleIdx ~= nil) or
(#(mgmtPopup.inputs or {}) == 0)
local inputItemsList = {}
if mgmtPopup.fluid then
if inIsStg3 then
for fN3, fC3 in pairs(mgmtFluidStockSnap()) do
table.insert(inputItemsList, {name=fN3, count=fC3})
end
else
for fN3, fC3 in pairs(tankContents(mgmtPopup.input)) do
table.insert(inputItemsList, {name=fN3, count=fC3})
end
end
table.sort(inputItemsList, function(a,b) return a.name < b.name end)
elseif inIsStg3 then
local snap3 = getStorageInventoryCached()
for iN3, iC3 in pairs(snap3) do
table.insert(inputItemsList, {name=iN3, count=iC3})
end
table.sort(inputItemsList, function(a,b) return a.name < b.name end)
else
local byName2 = {}
for _, inNm in ipairs(mgmtPopup.inputs or {}) do
local inputPeri2 = peripheral.wrap(inNm)
if inputPeri2 and inputPeri2.list then
local ok2b, items2 = pcall(inputPeri2.list)
if ok2b and items2 then
for _, it2 in pairs(items2) do
if it2 then byName2[it2.name] = (byName2[it2.name] or 0) + it2.count end
end
end
end
end
for iName2, iCnt2 in pairs(byName2) do
table.insert(inputItemsList, {name=iName2, count=iCnt2})
end
table.sort(inputItemsList, function(a,b) return a.name < b.name end)
end
local srch3 = mgmtItemSearch:lower()
local filteredItems = {}
for _, itF in ipairs(inputItemsList) do
if srch3 == "" or itF.name:lower():find(srch3, 1, true) then
table.insert(filteredItems, itF)
end
end
local pW3 = math.min(w - 10, 70)
local pX3 = math.floor((w - pW3) / 2) + 1
local pH3 = math.min(h - 4, 18)
local pY3 = math.floor((h - pH3) / 2) + 1
local cols3 = 3
local colW3 = math.floor((pW3 - 2) / cols3)
local listTop3 = pY3 + 3
local maxRows3 = pH3 - 6
local perPage3 = cols3 * maxRows3
local iPage2  = mgmtPopup.itemPage or 1
local iTotal2 = math.max(1, math.ceil(#filteredItems / perPage3))
if iPage2 > iTotal2 then iPage2 = iTotal2; mgmtPopup.itemPage = iPage2 end
local iStart2 = (iPage2 - 1) * perPage3 + 1
local iEnd2   = math.min(iStart2 + perPage3 - 1, #filteredItems)
popupZoneStart = #touchZones + 1
popupRect = {x1=pX3, x2=pX3+pW3-1, y1=pY3, y2=pY3+pH3-1}
_bufFillRect(pX3, pY3, pW3, pH3, colors.gray)
local inpShort2 = inIsStg3 and "STORAGE" or getMachineDisplay(mgmtPopup.input)
local hdr3
if mgmtPopup.condPickRuleIdx then
hdr3 = mgmtPopup.fluid and " PICK CONDITION FLUID " or " PICK CONDITION ITEM "
elseif mgmtPopup.fluid then
hdr3 = " ADD FLUID FROM: " .. inpShort2:upper():sub(1, pW3 - 20) .. " "
else
hdr3 = " ADD ITEM FROM: " .. inpShort2:upper():sub(1, pW3 - 20) .. " "
end
drawText(pX3 + math.floor((pW3 - #hdr3) / 2), pY3, hdr3, colors.black, colors.lime)
local searchRow  = pY3 + 1
local srchDisp3  = (mgmtItemSearch == "") and "<type item name...>" or mgmtItemSearch
local srchColor3 = mgmtItemSearchActive and colors.black
or (mgmtItemSearch == "" and colors.gray or colors.white)
local srchBoxBg3 = mgmtItemSearchActive and colors.white or colors.lightGray
local srchFull3  = "FIND: [ " .. srchDisp3 .. " ]"
local srchX3     = pX3 + math.floor((pW3 - #srchFull3) / 2)
drawText(srchX3, searchRow, "FIND: ", colors.lightGray, colors.gray)
drawText(srchX3 + 6, searchRow, "[ " .. srchDisp3 .. " ]", srchColor3, srchBoxBg3)
table.insert(touchZones, {id="mgmt_search_focus", x1=srchX3, x2=srchX3+#srchFull3-1, y=searchRow})
if mgmtItemSearch ~= "" then
local xBtn  = " [X] "
local xBtnX = srchX3 + #srchFull3 + 1
drawText(xBtnX, searchRow, xBtn, colors.white, colors.red)
table.insert(touchZones, {id="mgmt_search_clear", x1=xBtnX, x2=xBtnX+#xBtn-1, y=searchRow})
end
for ci = 1, cols3 - 1 do
local sepX = pX3 + 1 + ci * colW3
for ry = 0, maxRows3 - 1 do
drawText(sepX, listTop3 + ry, "|", colors.lightGray, colors.gray)
end
end
if #filteredItems == 0 then
local emptyMsg = srch3 ~= "" and "(no matches)" or "(input empty or unavailable)"
drawText(pX3 + 2, listTop3 + 1, emptyMsg, colors.lightGray, colors.gray)
else
for ii2 = iStart2, iEnd2 do
local localIdx = ii2 - iStart2
local col = math.floor(localIdx / maxRows3)
local row = localIdx % maxRows3
local cellX = pX3 + 2 + col * colW3
local cellY = listTop3 + row
local itm2 = filteredItems[ii2]
local cntS2 = tostring(itm2.count)
local nameMax = colW3 - 2 - #cntS2 - 1
local iShort2 = (itm2.name:match(":(.+)$") or itm2.name)
if #iShort2 > nameMax then iShort2 = iShort2:sub(1, nameMax) end
local hasRule2 = false
if not mgmtPopup.condPickRuleIdx then
for _, r2 in ipairs(mgmtPopup.rules or {}) do
if r2.item == itm2.name then hasRule2 = true; break end
end
end
local nameColor = hasRule2 and colors.orange or colors.white
drawText(cellX, cellY, iShort2, nameColor, colors.gray)
drawText(cellX + colW3 - 2 - #cntS2, cellY, cntS2, colors.cyan, colors.gray)
if not hasRule2 then
table.insert(touchZones, {id="mgmt_add_rule", arg=itm2.name, x1=cellX, x2=cellX+colW3-2, y=cellY})
end
end
end
local navY3 = pY3 + pH3 - 2
local arrL3 = " < "; local arrR3 = " > "
local lAct3 = (iPage2 > 1)
local rAct3 = (iPage2 < iTotal2)
drawText(pX3 + 2, navY3, arrL3, lAct3 and colors.white or colors.lightGray, colors.gray)
if lAct3 then
table.insert(touchZones, {id="mgmt_item_prev", x1=pX3+2, x2=pX3+2+#arrL3-1, y=navY3})
end
drawText(pX3 + pW3 - #arrR3 - 2, navY3, arrR3, rAct3 and colors.white or colors.lightGray, colors.gray)
if rAct3 then
table.insert(touchZones, {id="mgmt_item_next", x1=pX3+pW3-#arrR3-2, x2=pX3+pW3-3, y=navY3})
end
local canS3 = " [CANCEL] "
drawText(pX3 + math.floor((pW3 - #canS3) / 2), pY3 + pH3 - 1, canS3, colors.white, colors.gray)
table.insert(touchZones, {id="mgmt_item_cancel", x1=pX3+math.floor((pW3 - #canS3)/2), x2=pX3+math.floor((pW3 - #canS3)/2)+#canS3-1, y=pY3+pH3-1})
elseif step == "output_select" then
popupRect, popupZoneStart = _diB19(w, h, touchZones, popupRect, popupZoneStart)
end
elseif mgmtPopup.mode == "view_input" then
local grp2 = MgmtGroups[mgmtPopup.groupIdx]
if grp2 then
popupRect, popupZoneStart = _diB26(w, grp2, h, touchZones, popupRect, popupZoneStart)
end
end
end
end
if currentTab == "QUANTITY_PICKER" then
popupRect = _diB9(w, h, stockInv, touchZones, popupRect)
elseif craftQueuePopup then
popupRect = _diQueuePopup(w, h, touchZones, popupRect)
elseif historyPopup then
popupRect = _diB10(w, h, stockInv, touchZones, popupRect)
elseif craftCompletePopup then
popupRect = _diB22(w, h, touchZones, popupRect)
elseif recipeEditPopup then
popupRect = _diB4(w, h, touchZones, popupRect)
elseif fluidSaveConfirm then
popupRect = _diB23(w, h, touchZones, popupRect)
elseif fluidRecipePicker then
popupRect = _diB20(w, h, touchZones, popupRect)
elseif machineInfoPopup then
local miItem  = machineInfoPopup.item
local miMach  = machineInfoPopup.machineName or "?"
local sName   = miItem:match(":(.+)$") or miItem
local pW2 = math.min(w - 4, 50)
local pX2 = math.floor((w - pW2) / 2) + 1
local pH2 = 7
local pY2 = math.floor((h - pH2) / 2) + 1
popupRect = {x1=pX2, x2=pX2+pW2-1, y1=pY2, y2=pY2+pH2-1}
_bufFillRect(pX2, pY2, pW2, pH2, colors.gray)
local hdrM = " MACHINE NOT FOUND "
drawText(pX2 + math.floor((pW2 - #hdrM) / 2), pY2, hdrM, colors.black, colors.orange)
drawText(pX2 + 2, pY2 + 2, ("Recipe:  " .. sName):sub(1, pW2 - 4),   colors.white,  colors.gray)
drawText(pX2 + 2, pY2 + 3, ("Machine: " .. getMachineDisplay(miMach)):sub(1, pW2 - 4),  colors.orange, colors.gray)
drawText(pX2 + 2, pY2 + 4, "Not connected to the network.",            colors.lightGray, colors.gray)
local clsM = " [ CLOSE ] "
local clsMX = pX2 + math.floor((pW2 - #clsM) / 2)
drawText(clsMX, pY2 + pH2 - 1, clsM, colors.white, colors.gray)
table.insert(touchZones, 1, {id="close_machine_info", x1=clsMX, x2=clsMX+#clsM-1, y=pY2+pH2-1})
elseif craftInfoPopup then
local data = recipesScanResults[craftInfoPopup.item]
if not data then
craftInfoPopup = nil
else
popupRect = _diB21(w, h, touchZones, popupRect, data)
end
elseif fluidCraftInfo then
popupRect = _diB24(w, h, touchZones, popupRect)
elseif #craftErrorLines > 0 then
local panelH   = #craftErrorLines + 1
local panelTop = h - panelH + 1
if panelTop < 9 then panelTop = 9 end
local hdr = craftErrorTitle or "! NOT ENOUGH RESOURCES"
if hdr == "! NEED" then
_bufClearLine(panelTop, colors.yellow)
drawText(2, panelTop, hdr:sub(1, w - 2), colors.black, colors.yellow)
else
_bufClearLine(panelTop, colors.red)
drawText(2, panelTop, hdr:sub(1, w - 2), colors.white, colors.red)
end
for li, line in ipairs(craftErrorLines) do
local ly = panelTop + li
if ly <= h then
_bufClearLine(ly, colors.gray)
local editItem = (craftErrorTitle == "! MACHINE NOT FOUND") and craftErrorEditItems[li]
if editItem and Recipes[editItem] then
drawText(2, ly, line:sub(1, w - 9), colors.white, colors.gray)
drawText(w - 6, ly, " [E] ", colors.black, colors.orange)
table.insert(touchZones, 1, {id="error_edit_machine", arg=editItem, x1=w-6, x2=w-2, y=ly})
else
drawText(2, ly, line:sub(1, w - 2), colors.white, colors.gray)
end
end
end
end
if popupRect then
if popupZoneStart and popupZoneStart > 1 then
local filtered = {}
for i = popupZoneStart, #touchZones do
table.insert(filtered, touchZones[i])
end
touchZones = filtered
end
for shieldY = popupRect.y1, popupRect.y2 do
table.insert(touchZones, {id="popup_bg", x1=popupRect.x1, x2=popupRect.x2, y=shieldY})
end
end
for bgRow = 1, h do
table.insert(touchZones, {id="bg_click", x1=1, x2=w, y=bgRow})
end
_bufFlush()
return touchZones
end
local function mainLoop()
checkTimer = os.startTimer(6)
idleTimer   = os.startTimer(autostockIdleSecs)
while true do
local touchZones = drawInterface()
term.clear() term.setCursorPos(1,1)
print("==========================================")
print(" STATUS: MONITOR DISPLAY ACTIVE (NX-UI)   ")
print("==========================================")
local searchTabActive = (currentTab == "RECIPES" or currentTab == "STOCK")
or (currentTab == "FLUID" and (fluidSubTab == "FLUID" or fluidSubTab == "FITEM") and not fluidLearnStage and not fluidRecipePicker and not fluidCraftWaitFluid)
if searchTabActive then
local sf, label
if currentTab == "RECIPES" then sf, label = searchFilter, "RECIPES"
elseif currentTab == "STOCK" then sf, label = stockSearchFilter, "STOCK"
else sf, label = fluidSearchFilter, "FLUID" end
print("")
print(" [" .. label .. " SEARCH]")
if sf == "" then
print(" > _  (type to search)")
else
print(" > " .. sf .. "_")
end
end
local event, param1, param2, param3
if #pendingTouches > 0 then
local t = table.remove(pendingTouches, 1)
event, param1, param2, param3 = t[1], t[2], t[3], t[4]
else
event, param1, param2, param3 = os.pullEvent()
if event == "monitor_touch" and #pendingTouches > 0 then
local t = table.remove(pendingTouches, 1)
event, param1, param2, param3 = t[1], t[2], t[3], t[4]
end
end
if event == "timer" and param1 == checkTimer then
checkTimer = os.startTimer(6)
elseif event == "timer" and param1 == uiMsgTimer then
uiMessage = ""
uiMsgTimer = nil
elseif event == "timer" and craftCompletePopup and param1 == craftCompletePopup.timer then
craftCompletePopup = nil
elseif event == "timer" and unloadTimer and param1 == unloadTimer then
unloadActive = false
unloadTimer = nil
elseif event == "timer" and optimizeTimer and param1 == optimizeTimer then
optimizeActive = false
optimizeTimer = nil
elseif event == "timer" and scanTimer and param1 == scanTimer then
scanActive = false
scanTimer = nil
elseif event == "timer" and gitStatusTimer and param1 == gitStatusTimer then
gitStatus = ""; gitStatusColor = colors.gray; gitStatusTimer = nil
elseif event == "timer" and param1 == idleTimer then
if not Config.autostock_paused then
checkAndRunAutostock()
end
idleTimer = os.startTimer(autostockIdleSecs)
elseif event == "monitor_touch" then
local x, y = param2, param3
uiMessage = ""
if uiMsgTimer then os.cancelTimer(uiMsgTimer); uiMsgTimer = nil end
craftErrorLines = {}; craftErrorTitle = nil
pendingDeleteItem = nil
pendingDeleteFluid = nil
if idleTimer then os.cancelTimer(idleTimer) end
idleTimer = os.startTimer(autostockIdleSecs)
for _, zone in ipairs(touchZones) do
if zone.id and x >= zone.x1 and x <= zone.x2 and y == zone.y then
if craftCompletePopup and zone.id ~= "popup_close" and zone.id ~= "popup_request" and zone.id ~= "popup_bg" then
if craftCompletePopup.timer then os.cancelTimer(craftCompletePopup.timer) end
craftCompletePopup = nil
break
end
if fluidSaveConfirm and zone.id ~= "fluid_save_yes" and zone.id ~= "fluid_save_no" then
break
end
if fluidRecipePicker and zone.id ~= "fluid_pick_recipe" and zone.id ~= "fluid_make_primary"
and zone.id ~= "fluid_picker_delete" and zone.id ~= "fluid_picker_close" then
break
end
if machineInfoPopup and zone.id ~= "close_machine_info" and zone.id ~= "show_machine_info" and zone.id ~= "popup_bg" then
machineInfoPopup = nil
break
end
if craftInfoPopup and zone.id ~= "close_craft_info" and zone.id ~= "show_craft_info" and zone.id ~= "popup_bg" then
craftInfoPopup = nil
break
end
if fluidCraftInfo and zone.id ~= "close_fluid_info" and zone.id ~= "show_fluid_info" and zone.id ~= "popup_bg" then
fluidCraftInfo = nil
break
end
if historyPopup and zone.id ~= "open_history" and zone.id ~= "close_history" and zone.id ~= "history_craft" and zone.id ~= "history_craft_fluid" and zone.id ~= "history_req" and zone.id ~= "history_prev" and zone.id ~= "history_next" and zone.id ~= "history_scan" and zone.id ~= "popup_bg" then
historyPopup = nil
break
end
if recipeEditPopup and zone.id ~= "close_recipe_edit" and zone.id ~= "recipe_edit_select" and zone.id ~= "recipe_edit_apply" and zone.id ~= "recipe_edit_global" and zone.id ~= "recipe_edit_confirm_global" and zone.id ~= "recipe_edit_prev" and zone.id ~= "recipe_edit_next" and zone.id ~= "popup_bg" then
recipeEditPopup = nil
break
end
if currentTab == "QUANTITY_PICKER" then
local isQtyZone = zone.id == "qty_adj" or zone.id == "qty_confirm" or zone.id == "qty_cancel" or zone.id == "qty_max" or zone.id == "qty_type" or zone.id == "keep_field" or zone.id == "popup_bg" or zone.id == "qty_calc_max" or zone.id == "qty_toggle_automax" or zone.id == "qty_add_queue"
if not isQtyZone then
isRequestMode = false
isSettingKeepLimit = false
altOutEdit = nil
if queueEditIdx then queueEditIdx = nil; craftQueuePopup = true end
currentTab = qtyOriginTab or "RECIPES"
break
end
end
if craftQueuePopup and zone.id == "bg_click" then
craftQueuePopup = false
craftQueueErrIdx = nil
break
end
if mgmtPopup and zone.id == "bg_click" then
mgmtPopup = nil
break
end
if custGrpPopup and zone.id == "bg_click" then
custGrpPopup = nil
break
end
if zone.id == "popup_bg" then break end
if zone.id == "switch_tab" then
currentTab = zone.arg; currentPage = 1
mgmtPopup = nil
custGrpPopup = nil
if zone.arg == "STOCK" then stockSearchFilter = ""; stockModFilter = "All"; stockModFilterPage = 1 end
if zone.arg == "KEEP" then scanKeepItemsNow() end
elseif zone.id == "set_mod" then currentModFilter = zone.arg; currentPage = 1
elseif zone.id == "mod_prev" then modFilterPage = math.max(1, modFilterPage - 1)
elseif zone.id == "mod_next" then modFilterPage = modFilterPage + 1
elseif zone.id == "craft_subtab" then
craftSubTab = zone.arg
craftDevicePage = 1
if zone.arg == "TURTLE" then
selectedCraftType = "turtle"
selectedOutputDevice = nil
outputPickMode = false
end
if zone.arg == "FLUID" then
fluidLearnStage = "PICK_INPUT"
fluidLearnInputs = {}
fluidLearnMachine = nil
clearFluidLearnDevices()
fluidLearnPage = 1
fluidScanStatus = ""
else
fluidLearnStage = nil
end
elseif zone.id == "craft_dev_prev" then craftDevicePage = math.max(1, craftDevicePage - 1)
elseif zone.id == "craft_dev_next" then craftDevicePage = craftDevicePage + 1
elseif zone.id == "fluid_subtab" then
fluidSubTab = zone.arg
fluidTankPage = 1
fluidRecipePage = 1
elseif zone.id == "fluid_tank_prev" then fluidTankPage = math.max(1, fluidTankPage - 1)
elseif zone.id == "fluid_tank_next" then fluidTankPage = fluidTankPage + 1
elseif zone.id == "fluid_recipe_prev" then fluidRecipePage = math.max(1, fluidRecipePage - 1)
elseif zone.id == "fluid_recipe_next" then fluidRecipePage = fluidRecipePage + 1
elseif zone.id == "fluid_delete_ask" then
pendingDeleteFluid = zone.arg
elseif zone.id == "fluid_delete_cancel" then
pendingDeleteFluid = nil
elseif zone.id == "fluid_delete_confirm" then
local prods = fluidProducers(zone.arg)
if prods[1] then removeFluidRecipeRef(prods[1].recipe) end
pendingDeleteFluid = nil
syncFluidItemStubs()
saveData()
elseif zone.id == "open_keep_picker_fluid" then
local fk = fluidKey(zone.arg)
if Autostock[fk] then
Autostock[fk] = nil
saveData()
else
fluidCraftMode = nil
fluidKeepName = zone.arg
itemToCraft = fk
keepThr = 1000
keepTgt = 2000
keepField = "threshold"
isSettingKeepLimit = true
isRequestMode = false
qtyOriginTab = "RECIPES"
currentTab = "QUANTITY_PICKER"
end
elseif zone.id == "open_recipe_edit_fluid" then
local prods = fluidProducers(zone.arg)
local p = prods[1]
if p then
recipeEditPopup = {
fluid = zone.arg, fluidRecipeRef = p.recipe,
origMachine = p.recipe.machine_name, selected = p.recipe.machine_name,
confirmGlobal = false, page = 1,
}
end
elseif zone.id == "fluid_craft" then
local prods = fluidProducers(zone.arg)
if prods[1] then doFluidCraftFlow(prods[1].recipe, zone.arg) end
elseif zone.id == "fluid_alt" then
altViewFluid = zone.arg
altViewItem = nil
currentTab = "ALT_VIEW"
elseif zone.id == "fluid_pick_recipe" then
if fluidRecipePicker then
local p = fluidRecipePicker.producers[zone.arg]
local fname = fluidRecipePicker.fluid
if p then doFluidCraftFlow(p.recipe, fname) end
end
elseif zone.id == "fluid_make_primary" then
if fluidRecipePicker then
local p = fluidRecipePicker.producers[zone.arg]
if p and p.own and not p.isPrimary and p.altIdx then
local fk = p.key
local alts = FluidAltRecipes[fk] or {}
local chosen = table.remove(alts, p.altIdx)
local old = FluidRecipes[fk]
FluidRecipes[fk] = chosen
if old then table.insert(alts, 1, old) end
FluidAltRecipes[fk] = (#alts > 0) and alts or nil
syncFluidItemStubs()
saveData()
fluidRecipePicker.producers = fluidProducers(fluidRecipePicker.fluid)
end
end
elseif zone.id == "fluid_picker_delete" then
if fluidRecipePicker then
local p = fluidRecipePicker.producers[zone.arg]
if p and p.own then
local fk = p.key
if p.isPrimary then
local alts = FluidAltRecipes[fk]
if alts and alts[1] then
FluidRecipes[fk] = table.remove(alts, 1)
if #alts == 0 then FluidAltRecipes[fk] = nil end
else
FluidRecipes[fk] = nil
end
elseif p.altIdx then
local alts = FluidAltRecipes[fk]
if alts then
table.remove(alts, p.altIdx)
if #alts == 0 then FluidAltRecipes[fk] = nil end
end
end
syncFluidItemStubs()
saveData()
local prods = fluidProducers(fluidRecipePicker.fluid)
if #prods == 0 then fluidRecipePicker = nil
else fluidRecipePicker.producers = prods end
end
end
elseif zone.id == "fluid_picker_close" then
fluidRecipePicker = nil
elseif zone.id == "fluid_save_yes" then
if fluidSaveConfirm then
local sc = fluidSaveConfirm
if sc.asAlt then
FluidAltRecipes[sc.key] = FluidAltRecipes[sc.key] or {}
table.insert(FluidAltRecipes[sc.key], sc.recipe)
else
FluidRecipes[sc.key] = sc.recipe
end
syncFluidItemStubs()
saveData()
fluidLearnStage = "PICK_INPUT"
fluidLearnInputs = {}
fluidLearnMachine = nil
clearFluidLearnDevices()
fluidLearnPage = 1
local prod = {}
for _, o in ipairs(sc.recipe.outputs or {}) do prod[#prod + 1] = {name = o.name, amount = o.amount, unit = "mB"} end
for _, o in ipairs(sc.recipe.item_outputs or {}) do prod[#prod + 1] = {name = o.name, amount = o.count, unit = "x"} end
fluidSaveConfirm = nil
craftCompletePopup = {learned = true, outputs = prod, timer = os.startTimer(10)}
end
elseif zone.id == "fluid_save_no" then
fluidSaveConfirm = nil
fluidLearnStage = "PICK_INPUT"
fluidLearnInputs = {}
fluidLearnMachine = nil
clearFluidLearnDevices()
fluidLearnPage = 1
elseif zone.id == "fluid_trigger_search" then
searchInputActive = true
drawInterface()
term.clear() term.setCursorPos(1, 1)
write("Enter fluid search: ")
local srInput = timedRead(5)
searchInputActive = false
if srInput ~= nil then fluidSearchFilter = srInput end
fluidRecipePage = 1
elseif zone.id == "fluid_clear_search" then
fluidSearchFilter = ""
fluidRecipePage = 1
elseif zone.id == "fluid_add" then
fluidCraftMsg = ""
fluidLearnStage = "PICK_INPUT"
fluidLearnInputs = {}
fluidLearnMachine = nil
clearFluidLearnDevices()
fluidLearnPage = 1
fluidScanStatus = ""
elseif zone.id == "fluid_learn_cancel" then
fluidLearnStage = nil
fluidLearnInputs = {}
fluidLearnMachine = nil
clearFluidLearnDevices()
fluidLearnPage = 1
fluidScanStatus = ""
elseif zone.id == "fluid_learn_prev" then fluidLearnPage = math.max(1, fluidLearnPage - 1)
elseif zone.id == "fluid_learn_next" then fluidLearnPage = fluidLearnPage + 1
elseif zone.id == "fluid_pick_input" then
local existIdx = nil
for i, inp in ipairs(fluidLearnInputs) do
if inp.name == zone.arg then existIdx = i; break end
end
if existIdx then
table.remove(fluidLearnInputs, existIdx)
elseif #fluidLearnInputs < 5 then
qtyTypeActive = true
fluidInputWaitName = zone.arg
drawInterface()
term.clear(); term.setCursorPos(1, 1)
print("Enter mB for:")
print(zone.arg)
write("> ")
local input = timedRead(30)
fluidInputWaitName = nil
qtyTypeActive = false
local num = tonumber(input)
if num and num > 0 then
fluidLearnInputs[#fluidLearnInputs + 1] = {name = zone.arg, amount = math.floor(num)}
end
end
elseif zone.id == "fluid_learn_done_inputs" then
fluidLearnStage = "PICK_MACHINE"
fluidLearnPage = 1
elseif zone.id == "fluid_learn_back_inputs" then
fluidLearnStage = "PICK_INPUT"
clearFluidLearnDevices()
fluidLearnPage = 1
elseif zone.id == "fluid_pick_machine" then
if fluidOutputPick then
fluidLearnOutput = zone.arg; fluidOutputPick = false
elseif fluidItemInPick then
fluidLearnItemIn = zone.arg; fluidItemInPick = false
elseif fluidFluidInPick then
fluidLearnFluidIn = zone.arg; fluidFluidInPick = false
elseif fluidItemOutPick then
fluidLearnItemOut = zone.arg; fluidItemOutPick = false
elseif fluidLearnMachine == zone.arg then
fluidLearnMachine = nil
clearFluidLearnDevices()
else
fluidLearnMachine = zone.arg
end
elseif zone.id == "fluid_pull_toggle" then
fluidItemInPick = false; fluidFluidInPick = false; fluidItemOutPick = false
if fluidOutputPick then fluidOutputPick = false
elseif fluidLearnOutput then fluidLearnOutput = nil
else fluidOutputPick = true end
elseif zone.id == "fluid_iteminput_toggle" then
fluidOutputPick = false; fluidFluidInPick = false; fluidItemOutPick = false
if fluidItemInPick then fluidItemInPick = false
elseif fluidLearnItemIn then fluidLearnItemIn = nil
else fluidItemInPick = true end
elseif zone.id == "fluid_fluidin_toggle" then
fluidOutputPick = false; fluidItemInPick = false; fluidItemOutPick = false
if fluidFluidInPick then fluidFluidInPick = false
elseif fluidLearnFluidIn then fluidLearnFluidIn = nil
else fluidFluidInPick = true end
elseif zone.id == "fluid_itemout_toggle" then
fluidOutputPick = false; fluidItemInPick = false; fluidFluidInPick = false
if fluidItemOutPick then fluidItemOutPick = false
elseif fluidLearnItemOut then fluidLearnItemOut = nil
else fluidItemOutPick = true end
elseif zone.id == "fluid_learn_scan" and fluidLearnMachine then
systemStatus = "MANUAL_CRAFT"
cancelCrafting = false
fluidScanStatus = "Scanning: waiting for mix (tap CANCEL to stop)..."
drawInterface()
local okScan, recipe, errLines = runFluidScan(fluidLearnInputs, fluidLearnMachine, fluidLearnOutput, fluidLearnItemIn, fluidLearnFluidIn, fluidLearnItemOut)
systemStatus = "IDLE"
fluidScanStatus = ""
cancelCrafting = false
craftCancelY = nil
if okScan and recipe then
local fk = primaryRecipeKey(recipe)
local asAlt = (FluidRecipes[fk] ~= nil)
fluidSaveConfirm = {recipe = recipe, key = fk, asAlt = asAlt}
else
craftErrorTitle = "! FLUID SCAN FAILED"
craftErrorLines = errLines or {"Unknown error"}
end
elseif zone.id == "craft_out_change" then
if outputPickMode then
outputPickMode = false
elseif selectedOutputDevice then
selectedOutputDevice = nil
else
outputPickMode = true
end
elseif zone.id == "delete_ask" then
pendingDeleteItem = zone.arg
elseif zone.id == "delete_confirm" then
local delRec = Recipes[zone.arg]
if type(delRec) == "table" and delRec.type == "fluid" then
local frec = findFluidItemProducer(zone.arg)
if frec then removeFluidRecipeRef(frec) end
end
Recipes[zone.arg] = nil
AltRecipes[zone.arg] = nil
Autostock[zone.arg] = nil
syncFluidItemStubs()
saveData()
pendingDeleteItem = nil
elseif zone.id == "delete_cancel" then
pendingDeleteItem = nil
elseif zone.id == "open_alt_view" then
altViewItem = zone.arg
altViewFluid = nil
currentTab = "ALT_VIEW"
elseif zone.id == "alt_out_edit" then
altOutEdit = {rec = zone.recRef, targetName = zone.targetName,
fluidRow = zone.fluidRow}
isSettingKeepLimit = false
isRequestMode = false
fluidCraftMode = nil
fluidKeepName = nil
queueEditIdx = nil
craftQuantity = math.max(1, zone.curVal or 1)
qtyOriginTab = "ALT_VIEW"
currentTab = "QUANTITY_PICKER"
elseif zone.id == "alt_back" then
altOutEdit = nil
currentTab = "RECIPES"
if altViewFluid then currentModFilter = "FLUID" end
altViewFluid = nil
learnAsAlt = false
learnAsAltItem = nil
elseif zone.id == "alt_add" then
learnAsAlt = true
learnAsAltItem = altViewItem
currentTab = "+RECIPES"
learningState = "IDLE"
uiMessage = "Scan alt recipe, then [SAVE] to add as alt."
elseif zone.id == "combined_up" or zone.id == "combined_dn" or zone.id == "combined_top" or zone.id == "combined_del" then
local fkA = altViewFluid and fluidKey(altViewFluid) or nil
local getPrimary = function()
if fkA then return FluidRecipes[fkA] else return Recipes[altViewItem] end
end
local setPrimary = function(v)
if fkA then FluidRecipes[fkA] = v else Recipes[altViewItem] = v end
end
if altViewItem or altViewFluid then
local hasPrimary = getPrimary() ~= nil
local alts = (fkA and FluidAltRecipes[fkA] or (altViewItem and AltRecipes[altViewItem])) or {}
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
FluidAltRecipes[fkA] = (#alts > 0) and alts or nil
syncFluidItemStubs()
elseif #alts == 0 then
AltRecipes[altViewItem] = nil
else
AltRecipes[altViewItem] = alts
end
saveData()
end
elseif zone.id == "toggle_storage" then Config.storages[zone.arg] = not Config.storages[zone.arg]; saveData()
elseif zone.id == "toggle_fluid_tank" then
if Config.fluid_tanks[zone.arg] then Config.fluid_tanks[zone.arg] = nil
else Config.fluid_tanks[zone.arg] = true end
saveData()
elseif zone.id == "autostock_toggle" then
Config.autostock_paused = not Config.autostock_paused
saveData()
elseif zone.id == "keep_cat" then
fluidKeepFilter = zone.arg
currentPage = 1
elseif zone.id == "force_autostock" then
if not Config.autostock_paused then
checkAndRunAutostock()
end
elseif zone.id == "keep_craft_now" then
local kItem = zone.arg
local kSet  = Autostock[kItem]
if kSet and kItem:sub(1, 2) == "f:" then
local fname = fluidNameFromKey(kItem)
local cur   = (getFluidInventory())[kItem] or 0
local need  = (kSet.target or kSet.limit) - cur
local kShort = fname:match(":(.+)$") or fname
if need > 0 then
local prods = fluidProducers(fname)
if prods[1] then
runFluidCraftAmount(prods[1].recipe, fname, need)
else
uiMessage = "ERR: no recipe for " .. kShort
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(3)
end
else
uiMessage = kShort .. " already at target"
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(3)
end
elseif kSet and Recipes[kItem] then
local kInv    = getStorageInventory()
local kStock  = kInv[kItem] or 0
local kNeeded = (kSet.target or kSet.limit) - kStock
local kShort  = kItem:match(":(.+)$") or kItem
if kNeeded > 0 then
systemStatus = "MANUAL_CRAFT"
drawInterface()
local kPlan, kMiss, _ = planProduction(kItem, kNeeded, true)
if kPlan and #kPlan > 0 then
local kTarget = kSet.target or kSet.limit or 1
local kOk, kErr = pcall(function()
runCraftingProcess(kPlan)
local kAtt = 0
while not cancelCrafting and kAtt < 12 do
local tNow = groupAvailable(kItem, getStorageInventory())
if tNow >= kTarget then break end
kAtt = kAtt + 1
invalidateStockCache()
local rP = planProduction(kItem, kTarget, true)
if not (rP and #rP > 0) then break end
local bK = tNow
runCraftingProcess(rP)
if groupAvailable(kItem, getStorageInventory()) <= bK then break end
end
end)
systemStatus = "IDLE"
if kOk then
uiMessage = "Crafted: " .. kShort
else
uiMessage = "ERR: " .. tostring(kErr):sub(1, 30)
end
else
systemStatus = "IDLE"
uiMessage = "ERR: no resources for " .. kShort
end
else
uiMessage = kShort .. " already at target"
end
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(3)
scanKeepItemsNow()
end
elseif zone.id == "keep_top" or zone.id == "keep_up" or zone.id == "keep_dn" then
local fname = zone.arg
local isFl = (fname:sub(1, 2) == "f:")
local list = {}
for iName, s in pairs(Autostock) do
if (iName:sub(1, 2) == "f:") == isFl then
table.insert(list, {name=iName, order=s.order or 99999})
end
end
table.sort(list, function(a,b) return a.order < b.order end)
local idx
for i, e in ipairs(list) do if e.name == fname then idx = i; break end end
if idx then
if zone.id == "keep_top" then
local moved = table.remove(list, idx)
table.insert(list, 1, moved)
elseif zone.id == "keep_up" and idx > 1 then
list[idx], list[idx-1] = list[idx-1], list[idx]
elseif zone.id == "keep_dn" and idx < #list then
list[idx], list[idx+1] = list[idx+1], list[idx]
end
local slots = {}
for _, e in ipairs(list) do slots[#slots + 1] = e.order end
table.sort(slots)
for i, e in ipairs(list) do
if Autostock[e.name] then Autostock[e.name].order = slots[i] end
end
saveData()
end
elseif zone.id == "set_train_box" then
if Config.train_box == zone.arg then Config.train_box = nil else Config.train_box = zone.arg end
saveData()
elseif zone.id == "set_turtle" then
if not Config.turtles then Config.turtles = {} end
if Config.turtles[zone.arg] then
Config.turtles[zone.arg] = nil
else
Config.turtles[zone.arg] = true
end
saveData()
elseif zone.id == "turtle_remove" then
if Config.turtles then Config.turtles[zone.arg] = nil end
saveData()
elseif zone.id == "turtle_add" then
if not Config.turtles then Config.turtles = {} end
Config.turtles[zone.arg] = true
saveData()
elseif zone.id == "toggle_keep_status" then
if Autostock[zone.arg] then
Autostock[zone.arg].paused = not Autostock[zone.arg].paused
saveData()
end
elseif zone.id == "remove_keep" then
Autostock[zone.arg] = nil
local remaining = {}
for iName, s in pairs(Autostock) do
table.insert(remaining, {name=iName, order=s.order or 99999})
end
table.sort(remaining, function(a,b) return a.order < b.order end)
for ni, ri in ipairs(remaining) do Autostock[ri.name].order = ni end
saveData()
elseif zone.id == "prev_page" then
currentPage = math.max(1, currentPage - 1)
elseif zone.id == "next_page" then
currentPage = currentPage + 1
elseif zone.id == "scan_recipes" then
scanActive = true
drawInterface()
local sortedScan = {}
for iName in pairs(Recipes) do table.insert(sortedScan, iName) end
table.sort(sortedScan)
local filteredScan = {}
for _, iName in ipairs(sortedScan) do
local modId = iName:match("^([^:]+):") or "minecraft"
local sName = iName:match(":(.+)$") or iName
if (currentModFilter == "All" or currentModFilter == modId) and
(searchFilter == "" or sName:lower():find(searchFilter:lower(), 1, true)) then
table.insert(filteredScan, iName)
end
end
local _, mH = monitor.getSize()
local sRowY = 16
local iPP   = mH - sRowY - 3
local sIdx  = ((currentPage - 1) * iPP) + 1
local eIdx  = math.min(sIdx + iPP - 1, #filteredScan)
local snap  = getStorageInventory()
for i = sIdx, eIdx do
local iName = filteredScan[i]
local _, missing, blocked = planProduction(iName, 1, false, snap)
local blockedDetails = {}
for bItem in pairs(blocked) do
local _, bMissing, _ = planProduction(bItem, 1, false, snap)
blockedDetails[bItem] = {missing = bMissing}
end
local directAvail2  = groupAvailable(iName, snap)
local maxCraftable  = 0
local snapCraft2 = {}
for k, v in pairs(snap) do snapCraft2[k] = v end
snapCraft2[iName] = 0
if ITEM_GROUPS and ITEM_GROUPS[iName] then
local grp2c = ITEM_GROUPS[iName]
if GROUPS and GROUPS[grp2c] then
for _, alt in ipairs(GROUPS[grp2c]) do snapCraft2[alt] = 0 end
end
end
if not next(missing) then
local _, qm1, _ = planProduction(iName, 1, false, snapCraft2)
if not next(qm1) then
local _, qm100, _ = planProduction(iName, 100, false, snapCraft2)
if not next(qm100) then
local _, bigMissing, _ = planProduction(iName, 10000, false, snapCraft2)
if not next(bigMissing) then
maxCraftable = 10000
else
local lo2, hi2 = 100, 1000
while hi2 < 10000 do
local _, m2, _ = planProduction(iName, hi2, false, snapCraft2)
if next(m2) then break end
lo2 = hi2; hi2 = math.min(hi2 * 4, 10000)
end
while hi2 - lo2 > 1 do
local mid2 = math.floor((lo2 + hi2) / 2)
local _, mm2, _ = planProduction(iName, mid2, false, snapCraft2)
if not next(mm2) then lo2 = mid2 else hi2 = mid2 end
end
maxCraftable = lo2
end
else
local lo, hi = 1, 99
while hi - lo > 1 do
local mid = math.floor((lo + hi) / 2)
local _, mm, _ = planProduction(iName, mid, false, snapCraft2)
if not next(mm) then lo = mid else hi = mid end
end
maxCraftable = lo
end
end
end
local hasMach2, missMach2 = checkMachineAvailable(Recipes[iName])
recipesScanResults[iName] = {missing = missing, blocked = blocked, blockedDetails = blockedDetails, maxCraftable = maxCraftable, noMachine = not hasMach2, missingMachine = missMach2}
end
scanAllFluidsNow()
scanActive = true
if scanTimer then os.cancelTimer(scanTimer) end
scanTimer = os.startTimer(3)
elseif zone.id == "scan_all_recipes" then
allScanActive = true
drawInterface()
scanAllRecipesNow()
scanAllFluidsNow()
allScanActive = false
scanActive = true
if scanTimer then os.cancelTimer(scanTimer) end
scanTimer = os.startTimer(3)
elseif zone.id == "show_machine_info" then
local sr = recipesScanResults[zone.arg]
machineInfoPopup = {item = zone.arg, machineName = sr and sr.missingMachine or "?"}
elseif zone.id == "close_machine_info" then
machineInfoPopup = nil
elseif zone.id == "show_craft_info" then
local ciSnap = getStorageInventory()
local _, ciMiss, ciBlock = planProduction(zone.arg, 1, false, ciSnap)
local ciDetails = {}
for bItem in pairs(ciBlock) do
local ciDetailSnap = {}
for k, v in pairs(ciSnap) do ciDetailSnap[k] = v end
ciDetailSnap[bItem] = 0
local _, bm, _ = planProduction(bItem, 1, false, ciDetailSnap)
ciDetails[bItem] = {missing = bm}
end
if not next(ciMiss) and not next(ciBlock) then
local ciDirect = groupAvailable(zone.arg, ciSnap)
local _, beyMiss, beyBlock = planProduction(zone.arg, ciDirect + 1, false, ciSnap)
if next(beyMiss) or next(beyBlock) then
ciMiss  = beyMiss
ciBlock = beyBlock
ciDetails = {}
for bItem in pairs(beyBlock) do
local ciDetailSnap = {}
for k, v in pairs(ciSnap) do ciDetailSnap[k] = v end
ciDetailSnap[bItem] = 0
local _, bm, _ = planProduction(bItem, 1, false, ciDetailSnap)
ciDetails[bItem] = {missing = bm}
end
end
end
if recipesScanResults[zone.arg] then
recipesScanResults[zone.arg].missing       = ciMiss
recipesScanResults[zone.arg].blocked       = ciBlock
recipesScanResults[zone.arg].blockedDetails = ciDetails
else
recipesScanResults[zone.arg] = {missing=ciMiss, blocked=ciBlock, blockedDetails=ciDetails, maxCraftable=0}
end
craftInfoPopup = {item = zone.arg}
elseif zone.id == "close_craft_info" then
craftInfoPopup = nil
elseif zone.id == "show_fluid_info" then
local prods = fluidProducers(zone.arg)
local perOp = (prods[1] and prods[1].perOp) or 1
local fStock = {}
for k, v in pairs(getStorageInventory()) do fStock[k] = v end
fStock[fluidKey(zone.arg)] = 0
local fMiss = {}
pcall(simFluidConsume, zone.arg, perOp, fStock, fMiss, {}, {})
fluidCraftInfo = {name = zone.arg, missing = fMiss}
elseif zone.id == "close_fluid_info" then
fluidCraftInfo = nil
elseif zone.id == "open_history" then
if historyPopup then
historyPopup = nil
else
historyPopup = {page = 1, maxCache = {}}
end
elseif zone.id == "history_scan" then
if historyPopup then
local hSnap = getStorageInventory()
local histFstock = {}
for k, v in pairs(getFluidInventoryCached()) do histFstock[fluidNameFromKey(k)] = v end
local hCache = {}
for _, hEntry in ipairs(craftHistory) do
local hItem = hEntry.item
if hEntry.fluid then
local fck = "f:" .. hItem
if hCache[fck] == nil then
local okm, mx = pcall(maxFluidCraftable, hItem, histFstock, hSnap, {})
hCache[fck] = (okm and type(mx) == "number") and math.max(0, mx - (histFstock[hItem] or 0)) or 0
end
elseif hCache[hItem] == nil and Recipes[hItem] then
local hSnapC = {}
for k, v in pairs(hSnap) do hSnapC[k] = v end
hSnapC[hItem] = 0
if ITEM_GROUPS and ITEM_GROUPS[hItem] then
local hGrp = ITEM_GROUPS[hItem]
if GROUPS and GROUPS[hGrp] then
for _, alt in ipairs(GROUPS[hGrp]) do hSnapC[alt] = 0 end
end
end
local _, hm1, _ = planProduction(hItem, 1, false, hSnapC)
if next(hm1) then
hCache[hItem] = 0
else
local _, hm100, _ = planProduction(hItem, 100, false, hSnapC)
if not next(hm100) then
hCache[hItem] = 100
else
local lo, hi = 1, 99
while hi - lo > 1 do
local mid = math.floor((lo + hi) / 2)
local _, hmm, _ = planProduction(hItem, mid, false, hSnapC)
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
elseif zone.id == "close_history" then
historyPopup = nil
elseif zone.id == "history_prev" then
if historyPopup then
historyPopup.page = math.max(1, (historyPopup.page or 1) - 1)
end
elseif zone.id == "history_next" then
if historyPopup then
local _, mH = monitor.getSize()
local hPerPage2 = math.max(4, (mH or 24) - 20)
local totPg2 = math.max(1, math.ceil(#craftHistory / hPerPage2))
historyPopup.page = math.min(totPg2, (historyPopup.page or 1) + 1)
end
elseif zone.id == "history_craft" then
historyPopup = nil
itemToCraft = zone.arg
fluidCraftMode = nil
fluidKeepName = nil
isSettingKeepLimit = false
isRequestMode = false
qtyOriginTab = "RECIPES"
local pickerSnap = getStorageInventoryCached()
craftQuantity = pickerSnap[zone.arg] or 0
pickerMaxCraftable = 0
pickerMaxCapped = false
pickerMaxComputed = false
if Config.autoMaxCalc ~= false then pickerComputeMax() end
currentTab = "QUANTITY_PICKER"
elseif zone.id == "history_craft_fluid" then
historyPopup = nil
local hprods = fluidProducers(zone.arg)
if hprods[1] then doFluidCraftFlow(hprods[1].recipe, zone.arg) end
elseif zone.id == "history_req" then
historyPopup = nil
itemToCraft = zone.arg
fluidCraftMode = nil
fluidKeepName = nil
local inv = getStorageInventoryCached()
requestMaxQty = inv[zone.arg] or 0
if requestMaxQty == 0 then
local grpR = ITEM_GROUPS[zone.arg]
if grpR then
for _, altName in ipairs(GROUPS[grpR] or {}) do
if altName ~= zone.arg then
requestMaxQty = requestMaxQty + (inv[altName] or 0)
end
end
end
end
craftQuantity = math.min(1, requestMaxQty)
isSettingKeepLimit = false
isRequestMode = true
qtyOriginTab = "RECIPES"
currentTab = "QUANTITY_PICKER"
elseif zone.id == "error_edit_machine" then
craftErrorLines = {}; craftErrorTitle = nil
craftErrorEditItems = {}
local rec = Recipes[zone.arg]
if rec then
currentTab = "RECIPES"
recipeEditPopup = {
item          = zone.arg,
altIdx        = nil,
isItemScope   = false,
origMachine   = rec.machine_name,
selected      = rec.machine_name,
confirmGlobal = false,
page          = 1
}
end
elseif zone.id == "open_recipe_edit" then
local altIdx = zone.altIdx
local rec
if altIdx then
local alts = AltRecipes[zone.arg]
rec = alts and alts[altIdx]
else
rec = Recipes[zone.arg]
end
if rec then
recipeEditPopup = {
item          = zone.arg,
altIdx        = altIdx,
isItemScope   = zone.fromAltView == true,
origMachine   = rec.machine_name,
selected      = rec.machine_name,
confirmGlobal = false,
page          = 1
}
end
elseif zone.id == "recipe_edit_select" then
if recipeEditPopup then
recipeEditPopup.selected = zone.arg
end
elseif zone.id == "recipe_edit_apply" then
if recipeEditPopup and recipeEditPopup.selected then
local rec
if recipeEditPopup.fluid then
rec = recipeEditPopup.fluidRecipeRef
if rec then
rec.machine_name = recipeEditPopup.selected
syncFluidItemStubs()
saveData()
end
recipeEditPopup = nil
else
if recipeEditPopup.altIdx then
local alts = AltRecipes[recipeEditPopup.item]
rec = alts and alts[recipeEditPopup.altIdx]
else
rec = Recipes[recipeEditPopup.item]
end
if rec then
rec.machine_name = recipeEditPopup.selected
rec.imported = nil
if rec.type == "fluid" and rec.fluid_key then
local fr = FluidRecipes[rec.fluid_key]
if fr then fr.machine_name = recipeEditPopup.selected; fr.imported = nil end
syncFluidItemStubs()
end
saveData()
end
recipeEditPopup = nil
end
end
elseif zone.id == "recipe_edit_global" then
if recipeEditPopup then
recipeEditPopup.confirmGlobal = true
end
elseif zone.id == "recipe_edit_confirm_global" then
if recipeEditPopup and recipeEditPopup.selected then
local oldMachine = recipeEditPopup.origMachine
local newMachine = recipeEditPopup.selected
if recipeEditPopup.isItemScope then
local iRec = Recipes[recipeEditPopup.item]
if iRec and iRec.machine_name == oldMachine then
iRec.machine_name = newMachine
iRec.imported = nil
end
if iRec and iRec.type == "fluid" and iRec.fluid_key then
local fr = FluidRecipes[iRec.fluid_key]
if fr and fr.machine_name == oldMachine then fr.machine_name = newMachine; fr.imported = nil end
end
local iAlts = AltRecipes[recipeEditPopup.item]
if iAlts then
for _, rData in ipairs(iAlts) do
if rData.machine_name == oldMachine then
rData.machine_name = newMachine
rData.imported = nil
end
end
end
else
for _, rData in pairs(Recipes) do
if rData.machine_name == oldMachine then
rData.machine_name = newMachine
rData.imported = nil
end
end
for _, fr in pairs(FluidRecipes) do
if fr.machine_name == oldMachine then fr.machine_name = newMachine; fr.imported = nil end
end
for _, alts in pairs(FluidAltRecipes) do
for _, fr in ipairs(alts) do
if fr.machine_name == oldMachine then fr.machine_name = newMachine; fr.imported = nil end
end
end
end
syncFluidItemStubs()
saveData()
recipeEditPopup = nil
end
elseif zone.id == "close_recipe_edit" then
if recipeEditPopup then
if recipeEditPopup.confirmGlobal then
recipeEditPopup.confirmGlobal = false
else
recipeEditPopup = nil
end
end
elseif zone.id == "recipe_edit_prev" then
if recipeEditPopup then
recipeEditPopup.page = math.max(1, (recipeEditPopup.page or 1) - 1)
end
elseif zone.id == "recipe_edit_next" then
if recipeEditPopup then
recipeEditPopup.page = (recipeEditPopup.page or 1) + 1
end
elseif zone.id == "trigger_search" then
searchInputActive = true
drawInterface()
term.clear() term.setCursorPos(1,1)
write("Enter Search query: ")
local srInput = timedRead(5)
searchInputActive = false
if srInput ~= nil and srInput ~= "" then searchFilter = srInput end
currentPage = 1
elseif zone.id == "clear_search" then
searchFilter = ""
currentPage = 1
elseif zone.id == "stock_mod" then
stockModFilter = zone.arg
currentPage = 1
elseif zone.id == "stock_mod_prev" then
stockModFilterPage = math.max(1, stockModFilterPage - 1)
elseif zone.id == "stock_mod_next" then
stockModFilterPage = stockModFilterPage + 1
elseif zone.id == "stock_search" then
stockSearchInputActive = true
drawInterface()
term.clear() term.setCursorPos(1,1)
write("Stock search: ")
local stInput = timedRead(5)
stockSearchInputActive = false
if stInput ~= nil and stInput ~= "" then stockSearchFilter = stInput end
currentPage = 1
elseif zone.id == "stock_clear_search" then
stockSearchFilter = ""
currentPage = 1
elseif zone.id == "pull_from_box" then
local moved = pullAllFromTrainBox()
if moved > 0 then
invalidateStockCache()
uiMessage = "Unloaded " .. moved .. " items from train box"
else
uiMessage = "Train box is empty or not reachable"
end
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(3)
unloadActive = true
if unloadTimer then os.cancelTimer(unloadTimer) end
unloadTimer = os.startTimer(4)
elseif zone.id == "stock_optimize" then
local isTankOpt = (stockModFilter == "TANK")
uiMessage = isTankOpt and "Optimizing tanks..." or "Optimizing storage..."
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(1)
optimizeActive = true
if optimizeTimer then os.cancelTimer(optimizeTimer) end
drawInterface()
if isTankOpt then optimizeFluidTanks() else optimizeStorages() end
invalidateStockCache()
uiMessage = isTankOpt and "Tanks optimized!" or "Storage optimized!"
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(3)
optimizeTimer = os.startTimer(3)
elseif zone.id == "open_qty_picker" then
itemToCraft = zone.arg
fluidCraftMode = nil
fluidKeepName = nil
isSettingKeepLimit = false
isRequestMode = false
qtyOriginTab = currentTab
local pickerSnap = getStorageInventoryCached()
craftQuantity = pickerSnap[zone.arg] or 0
pickerMaxCraftable = 0
pickerMaxCapped = false
pickerMaxComputed = false
if Config.autoMaxCalc ~= false then pickerComputeMax() end
currentTab = "QUANTITY_PICKER"
elseif zone.id == "open_keep_picker" then
itemToCraft = zone.arg
fluidCraftMode = nil
fluidKeepName = nil
local ex = Autostock[zone.arg]
keepThr = (ex and (ex.threshold or ex.limit)) or 64
keepTgt = (ex and (ex.target or ex.limit)) or (keepThr * 2)
keepField = "threshold"
isSettingKeepLimit = true
isRequestMode = false
qtyOriginTab = "RECIPES"
currentTab = "QUANTITY_PICKER"
elseif zone.id == "keep_edit" then
itemToCraft = zone.arg
local ex = Autostock[zone.arg]
keepThr = (ex and (ex.threshold or ex.limit)) or 64
keepTgt = (ex and (ex.target or ex.limit)) or (keepThr * 2)
keepField = "threshold"
isSettingKeepLimit = true
isRequestMode = false
fluidKeepName = (zone.arg:sub(1, 2) == "f:") and fluidNameFromKey(zone.arg) or nil
qtyOriginTab = "KEEP"
currentTab = "QUANTITY_PICKER"
elseif zone.id == "open_req_picker" then
itemToCraft = zone.arg
fluidCraftMode = nil
fluidKeepName = nil
local inv = getStorageInventoryCached()
requestMaxQty = inv[zone.arg] or 0
if requestMaxQty == 0 then
local grp = ITEM_GROUPS[zone.arg]
if grp then
for _, altName in ipairs(GROUPS[grp]) do
if altName ~= zone.arg then
requestMaxQty = requestMaxQty + (inv[altName] or 0)
end
end
end
end
craftQuantity = math.min(1, requestMaxQty)
isSettingKeepLimit = false
isRequestMode = true
qtyOriginTab = currentTab
currentTab = "QUANTITY_PICKER"
elseif zone.id == "qty_adj" then
if isSettingKeepLimit then
if keepField == "threshold" then
keepThr = math.max(1, keepThr + zone.arg)
else
keepTgt = math.max(1, keepTgt + zone.arg)
end
else
local minVal = isRequestMode and 1 or 0
craftQuantity = math.max(minVal, craftQuantity + zone.arg)
if isRequestMode then
craftQuantity = math.min(craftQuantity, requestMaxQty)
end
end
elseif zone.id == "qty_calc_max" then
if not pickerMaxComputed then pickerComputeMax() end
elseif zone.id == "qty_toggle_automax" then
Config.autoMaxCalc = (Config.autoMaxCalc == false)
saveData()
if Config.autoMaxCalc then
pickerComputeMax()
else
pickerMaxComputed = false
pickerMaxCraftable = 0
end
elseif zone.id == "qty_max" then
if isRequestMode then
craftQuantity = math.min(craftQuantity + requestMaxQty, requestMaxQty)
else
if not pickerMaxComputed then pickerComputeMax() end
if fluidCraftMode then
craftQuantity = pickerMaxCraftable
else
craftQuantity = craftQuantity + pickerMaxCraftable
end
end
elseif zone.id == "qty_cancel" then
isRequestMode = false
isSettingKeepLimit = false
fluidCraftMode = nil
fluidKeepName = nil
altOutEdit = nil
if queueEditIdx then queueEditIdx = nil; craftQueuePopup = true end
currentTab = qtyOriginTab or "RECIPES"
elseif zone.id == "qty_add_queue" then
local qe = nil
if fluidCraftMode then
if craftQuantity > 0 then
qe = {kind = "fluid", name = fluidCraftMode.target, qty = craftQuantity,
recipe = fluidCraftMode.recipe, isItem = fluidCraftMode.isItem}
end
fluidCraftMode = nil
elseif not isRequestMode and not isSettingKeepLimit and craftQuantity > 0 then
qe = {kind = "item", name = itemToCraft, qty = craftQuantity}
end
if qe then
craftQueue[#craftQueue + 1] = qe
uiMessage = "Queued: " .. (qe.name:match(":(.+)$") or qe.name) .. " x" .. qe.qty
end
currentTab = qtyOriginTab or "RECIPES"
elseif zone.id == "keep_field" then
keepField = zone.arg
elseif zone.id == "qty_type" then
qtyTypeActive = true
drawInterface()
term.clear(); term.setCursorPos(1, 1)
write("Enter quantity: ")
local input = timedRead(30)
qtyTypeActive = false
local num = tonumber(input)
if num then
if isSettingKeepLimit then
local v = math.max(1, math.floor(num))
if keepField == "threshold" then keepThr = v else keepTgt = v end
else
local minVal = isRequestMode and 1 or 0
craftQuantity = math.max(minVal, math.floor(num))
if isRequestMode then
craftQuantity = math.min(craftQuantity, requestMaxQty)
end
end
end
elseif zone.id == "open_queue" then
craftQueuePopup = not craftQueuePopup
craftQueueErrIdx = nil
elseif zone.id == "queue_close" then
craftQueuePopup = false
craftQueueErrIdx = nil
elseif zone.id == "queue_top" then
local qi = zone.arg
if qi > 1 and craftQueue[qi] then
local qe = table.remove(craftQueue, qi)
table.insert(craftQueue, 1, qe)
craftQueueErrIdx = nil
craftQueueScroll = 0
end
elseif zone.id == "queue_up" then
local qi = zone.arg
if qi > 1 and craftQueue[qi] then
craftQueue[qi], craftQueue[qi - 1] = craftQueue[qi - 1], craftQueue[qi]
if craftQueueErrIdx == qi then craftQueueErrIdx = qi - 1
elseif craftQueueErrIdx == qi - 1 then craftQueueErrIdx = qi end
end
elseif zone.id == "queue_dn" then
local qi = zone.arg
if craftQueue[qi] and craftQueue[qi + 1] then
craftQueue[qi], craftQueue[qi + 1] = craftQueue[qi + 1], craftQueue[qi]
if craftQueueErrIdx == qi then craftQueueErrIdx = qi + 1
elseif craftQueueErrIdx == qi + 1 then craftQueueErrIdx = qi end
end
elseif zone.id == "queue_del" then
if craftQueue[zone.arg] then
table.remove(craftQueue, zone.arg)
craftQueueErrIdx = nil
end
elseif zone.id == "queue_err" then
if craftQueueErrIdx == zone.arg then craftQueueErrIdx = nil
else craftQueueErrIdx = zone.arg end
elseif zone.id == "queue_scroll" then
craftQueueScroll = math.max(0, craftQueueScroll + zone.arg)
elseif zone.id == "queue_edit" then
local qe = craftQueue[zone.arg]
if qe then
queueEditIdx = zone.arg
craftQueuePopup = false
craftQueueErrIdx = nil
itemToCraft = qe.name
craftQuantity = qe.qty
isSettingKeepLimit = false
isRequestMode = false
fluidCraftMode = nil
fluidKeepName = nil
pickerMaxCraftable = 0
pickerMaxCapped = false
pickerMaxComputed = false
if qe.kind ~= "fluid" and Config.autoMaxCalc ~= false then pickerComputeMax() end
qtyOriginTab = (currentTab ~= "QUANTITY_PICKER") and currentTab or "RECIPES"
currentTab = "QUANTITY_PICKER"
end
elseif zone.id == "queue_craft" then
local qe = craftQueue[zone.arg]
if qe then
craftQueuePopup = false
craftQueueErrIdx = nil
drawInterface()
systemStatus = "MANUAL_CRAFT"
craftErrorLines = {}; craftErrorTitle = nil
local okQ, reason = queueRunOne(qe)
if okQ then
table.remove(craftQueue, zone.arg)
else
qe.failed = reason
end
systemStatus = "IDLE"
craftErrorLines = {}; craftErrorTitle = nil
craftQueuePopup = true
end
elseif zone.id == "queue_runall" then
if #craftQueue > 0 then
craftQueuePopup = false
craftQueueErrIdx = nil
drawInterface()
systemStatus = "MANUAL_CRAFT"
local qi = 1
while qi <= #craftQueue do
cancelCrafting = false
craftErrorLines = {}; craftErrorTitle = nil
local qe = craftQueue[qi]
local okQ, reason = queueRunOne(qe)
if okQ then
table.remove(craftQueue, qi)
else
qe.failed = reason
qi = qi + 1
end
if cancelCrafting then break end
drawInterface()
end
systemStatus = "IDLE"
craftErrorLines = {}; craftErrorTitle = nil
craftQueuePopup = true
end
elseif zone.id == "popup_close" then
if craftCompletePopup and craftCompletePopup.timer then os.cancelTimer(craftCompletePopup.timer) end
craftCompletePopup = nil
elseif zone.id == "popup_request" then
local popItem = craftCompletePopup and craftCompletePopup.item
if craftCompletePopup and craftCompletePopup.timer then os.cancelTimer(craftCompletePopup.timer) end
craftCompletePopup = nil
if popItem and Config.train_box and Config.train_box ~= "" then
local inv = getStorageInventoryCached()
requestMaxQty = inv[popItem] or 0
if requestMaxQty == 0 then
local grp = ITEM_GROUPS[popItem]
if grp then
for _, altName in ipairs(GROUPS[grp]) do
if altName ~= popItem then
requestMaxQty = requestMaxQty + (inv[altName] or 0)
end
end
end
end
itemToCraft = popItem
fluidCraftMode = nil
fluidKeepName = nil
craftQuantity = math.max(1, requestMaxQty)
isSettingKeepLimit = false
isRequestMode = true
qtyOriginTab = "RECIPES"
currentTab = "QUANTITY_PICKER"
end
elseif zone.id == "select_device" then
if outputPickMode then
if zone.arg == selectedCraftType then
selectedOutputDevice = nil
else
selectedOutputDevice = zone.arg
end
outputPickMode = false
else
selectedCraftType = zone.arg
selectedOutputDevice = nil
if zone.arg ~= "turtle" then craftSubTab = "MACHINES" end
end
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
syncFluidItemStubs()
else
aRec.output_count = aVal
end
saveData()
end
altOutEdit = nil
currentTab = "ALT_VIEW"
elseif queueEditIdx then
local qe = craftQueue[queueEditIdx]
if qe and craftQuantity > 0 then
qe.qty = craftQuantity
qe.failed = nil
end
queueEditIdx = nil
craftQueueErrIdx = nil
currentTab = qtyOriginTab or "RECIPES"
craftQueuePopup = true
elseif fluidCraftMode then
local fcm = fluidCraftMode
fluidCraftMode = nil
currentTab = qtyOriginTab or "RECIPES"
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
local fOk, fProduced, fIsItem = runFluidCraftAmount(fcm.recipe, fcm.target, craftQuantity)
if fOk then notifyCraftDone(fcm.target, fProduced, not fIsItem) else notifyCraftFail(fcm.target) end
end
elseif isRequestMode then
local qty = math.min(craftQuantity, requestMaxQty)
if qty > 0 then
local moved = deliverToTrainBox(itemToCraft, qty)
local name  = itemToCraft:match(":(.+)$") or itemToCraft
if moved > 0 then
invalidateStockCache()
uiMessage = "Delivered " .. moved .. "x " .. name .. " to train box."
else
uiMessage = "ERR: nothing moved. Check train box."
end
end
isRequestMode = false
currentTab = qtyOriginTab or "RECIPES"
elseif isSettingKeepLimit then
local existingOrder  = Autostock[itemToCraft] and Autostock[itemToCraft].order
local existingPaused = Autostock[itemToCraft] and Autostock[itemToCraft].paused or false
if not existingOrder then
local maxOrder = 0
for _, s in pairs(Autostock) do
maxOrder = math.max(maxOrder, s.order or 0)
end
existingOrder = maxOrder + 1
end
local thr = math.max(1, keepThr)
local tgt = math.max(thr, keepTgt)
Autostock[itemToCraft] = { threshold = thr, target = tgt, paused = existingPaused, order = existingOrder }
saveData()
isSettingKeepLimit = false
fluidKeepName = nil
currentTab = qtyOriginTab or "RECIPES"
else
currentTab = qtyOriginTab or "RECIPES"
local preSnapH  = getStorageInventory()
local preStockH = groupAvailable(itemToCraft, preSnapH)
for hi = #craftHistory, 1, -1 do
if craftHistory[hi].item == itemToCraft then
table.remove(craftHistory, hi)
end
end
table.insert(craftHistory, 1, {item=itemToCraft, qty=craftQuantity})
if #craftHistory > 30 then table.remove(craftHistory) end
drawInterface()
systemStatus = "MANUAL_CRAFT"
cancelCrafting = false
invalidateStockCache()
local plan, missingRes, blockedComps = planProduction(itemToCraft, craftQuantity, true)
local missingMachines = {}
local missingMachineSteps = {}
if plan and #plan > 0 then
local seen = {}
for _, step in ipairs(plan) do
if step.type ~= "turtle" and step.machine_name and step.machine_name ~= ""
and step.count and step.count > 0 then
local isSplit = (step.output_device and step.output_device ~= "")
local pool
if isSplit then
pool = {step.machine_name}
else
pool = getMachinePool(step.machine_name)
end
local found = false
for _, mName in ipairs(pool) do
if peripheral.wrap(mName) then found = true; break end
end
if not found and not seen[step.machine_name] then
seen[step.machine_name] = true
table.insert(missingMachines, step.machine_name)
table.insert(missingMachineSteps, step.item)
end
if isSplit and not peripheral.wrap(step.output_device)
and not seen[step.output_device] then
seen[step.output_device] = true
table.insert(missingMachines, step.output_device)
table.insert(missingMachineSteps, step.item)
end
end
end
end
if #missingMachines > 0 then
craftErrorTitle = "! MACHINE NOT FOUND"
craftErrorLines = {}
craftErrorEditItems = {}
for mi, mName in ipairs(missingMachines) do
if mi <= 4 then
local mDisp = getMachineDisplay(mName)
local itemShort = missingMachineSteps[mi]:match(":(.+)$") or missingMachineSteps[mi]
table.insert(craftErrorLines, mDisp .. "  ->  " .. itemShort)
craftErrorEditItems[#craftErrorLines] = missingMachineSteps[mi]
end
end
if #missingMachines > 4 then
table.insert(craftErrorLines, "... and " .. (#missingMachines - 4) .. " more")
end
table.insert(craftErrorLines, "Use [E] in RECIPES to reassign.")
systemStatus = "IDLE"
craftHistory[1].qty = 0
elseif next(missingRes) then
craftHistory[1].qty = 0
systemStatus = "IDLE"
craftErrorTitle = "! NEED"
craftErrorLines = {}
local shownCount = 0
local totalMissing = 0
for _ in pairs(missingRes) do totalMissing = totalMissing + 1 end
for missingItem, countMissing in pairs(missingRes) do
if shownCount < 6 then
local mName = missingItem:match(":(.+)$") or missingItem
table.insert(craftErrorLines, mName .. ": x" .. countMissing)
shownCount = shownCount + 1
end
end
if totalMissing > shownCount then
table.insert(craftErrorLines, "... and " .. (totalMissing - shownCount) .. " more")
end
local blockedList = {}
for bItem in pairs(blockedComps) do
table.insert(blockedList, bItem:match(":(.+)$") or bItem)
end
table.sort(blockedList)
if #blockedList > 0 then
local joined = table.concat(blockedList, ", ")
if #joined > 30 then
table.insert(craftErrorLines, "Can't craft:")
table.insert(craftErrorLines, "  " .. joined)
else
table.insert(craftErrorLines, "Can't craft: " .. joined)
end
end
elseif plan and #plan == 0 then
craftHistory[1].qty = 0
local inv = getStorageInventory()
local curAmt = inv[itemToCraft] or 0
if craftCompletePopup and craftCompletePopup.timer then os.cancelTimer(craftCompletePopup.timer) end
craftCompletePopup = {item=itemToCraft, count=curAmt, timer=os.startTimer(10)}
systemStatus = "IDLE"
else
if plan and #plan > 0 then
local craftOk = runCraftingProcess(plan)
local tlAttempts = 0
while not cancelCrafting and tlAttempts < 12 do
local totalNow = groupAvailable(itemToCraft, getStorageInventory())
if totalNow >= craftQuantity then break end
tlAttempts = tlAttempts + 1
invalidateStockCache()
local rPlan = planProduction(itemToCraft, craftQuantity, true)
if not (rPlan and #rPlan > 0) then break end
local beforeTL = totalNow
if runCraftingProcess(rPlan) then craftOk = true end
if groupAvailable(itemToCraft, getStorageInventory()) <= beforeTL then break end
end
local inv = getStorageInventory()
local curAmt = inv[itemToCraft] or 0
local postStockH = groupAvailable(itemToCraft, inv)
craftHistory[1].qty = math.max(0, postStockH - preStockH)
if craftOk then
if craftCompletePopup and craftCompletePopup.timer then os.cancelTimer(craftCompletePopup.timer) end
craftCompletePopup = {item=itemToCraft, count=curAmt, timer=os.startTimer(10)}
notifyCraftDone(itemToCraft, craftHistory[1].qty, false)
else
notifyCraftFail(itemToCraft)
end
else
craftHistory[1].qty = 0
end
systemStatus = "IDLE"
craftErrorLines = {}; craftErrorTitle = nil
end
end
elseif zone.id == "add_recipe_action" then
systemStatus = "MANUAL_CRAFT"
uiMessage = runMachineRecipeSearch()
systemStatus = "IDLE"
pendingTouches = {}
elseif zone.id == "learn_save_as_alt" then
if learnedResult then
local mName = (learnedCraftType == "turtle") and "turtle" or learnedMachineName
local toolsCopy = nil
if learnedTools and next(learnedTools) then
toolsCopy = {}
for tn in pairs(learnedTools) do toolsCopy[tn] = true end
end
local recipeData = {
type = learnedCraftType, machine_name = learnedMachineName,
output_count = learnedResult.count, method = mName,
ingredients = learnedIngredients,
output_device = learnedOutputDevice,
tools = toolsCopy
}
local targetName = learnedResult.name
if not AltRecipes[targetName] then AltRecipes[targetName] = {} end
table.insert(AltRecipes[targetName], recipeData)
saveData()
uiMessage = "Alt added: " .. (targetName:match(":(.+)$") or targetName)
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(3)
end
clearLearnTurtle()
learningState = "IDLE"
elseif zone.id == "learn_save" then
if learnedResult then
local mName = (learnedCraftType == "turtle") and "turtle" or learnedMachineName
local toolsCopy = nil
if learnedTools and next(learnedTools) then
toolsCopy = {}
for tn in pairs(learnedTools) do toolsCopy[tn] = true end
end
local recipeData = {
type = learnedCraftType, machine_name = learnedMachineName,
output_count = learnedResult.count, method = mName,
ingredients = learnedIngredients,
output_device = learnedOutputDevice,
tools = toolsCopy
}
if learnAsAlt then
local targetName = learnedResult.name
if not AltRecipes[targetName] then AltRecipes[targetName] = {} end
table.insert(AltRecipes[targetName], recipeData)
saveData()
altViewItem = targetName
currentTab = "ALT_VIEW"
learnAsAlt = false
learnAsAltItem = nil
else
local outs = (learnedCraftType ~= "turtle" and learnedOutputs and #learnedOutputs > 0)
and learnedOutputs or {{name = learnedResult.name, count = learnedResult.count}}
local altSaved = nil
for _, o in ipairs(outs) do
local ingCopy = {}
for ii = 1, #learnedIngredients do ingCopy[ii] = learnedIngredients[ii] end
local toolCopy2 = nil
if learnedTools and next(learnedTools) then
toolCopy2 = {}
for tn in pairs(learnedTools) do toolCopy2[tn] = true end
end
local rd = {
type = learnedCraftType, machine_name = learnedMachineName,
output_count = o.count, method = mName,
ingredients = ingCopy,
output_device = learnedOutputDevice,
tools = toolCopy2
}
local ex = Recipes[o.name]
if type(ex) == "table" and ex.type ~= "fluid" then
AltRecipes[o.name] = AltRecipes[o.name] or {}
table.insert(AltRecipes[o.name], rd)
if not altSaved then altSaved = o.name end
else
Recipes[o.name] = rd
end
end
saveData()
if altSaved then
altViewItem = altSaved
currentTab = "ALT_VIEW"
end
end
end
clearLearnTurtle()
learnedResult = nil
learnedOutputs = nil
learningState = "IDLE"
drawInterface()
elseif zone.id == "learn_cancel" then
clearLearnTurtle()
learnedResult = nil
learnedOutputs = nil
learningState = "IDLE"
if learnAsAlt then
currentTab = "ALT_VIEW"
learnAsAlt = false
learnAsAltItem = nil
end
drawInterface()
elseif zone.id == "machine_label" then
local mName = zone.arg
local cur = MachineLabels[mName] or ""
drawInterface()
term.clear(); term.setCursorPos(1,1)
local mId = mName:match(":(.+)$") or mName
write(mId .. " label (Enter=clear): ")
local lbl = timedRead(15)
if lbl ~= nil then
if lbl == "" then
MachineLabels[mName] = nil
else
MachineLabels[mName] = lbl
end
saveData()
end
elseif zone.id == "group_exclude" then
ExcludedMachines[zone.arg] = true
saveData()
elseif zone.id == "group_include" then
ExcludedMachines[zone.arg] = nil
saveData()
elseif zone.id == "cgrp_new" then
custGrpPopup = {editIdx=nil, name="", selected={}, page=1}
elseif zone.id == "cgrp_edit" then
local cg = CustomMachineGroups[zone.arg]
if cg then
local sel = {}
for _, m in ipairs(cg.machines) do sel[m] = true end
custGrpPopup = {editIdx=zone.arg, name=cg.name, selected=sel, page=1}
end
elseif zone.id == "cgrp_del" then
table.remove(CustomMachineGroups, zone.arg)
saveData()
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
elseif zone.id == "cgrp_popup_name" then
if custGrpPopup then
drawInterface()
term.clear(); term.setCursorPos(1,1)
write("Group name: ")
local inp = read()
if inp and inp ~= "" then custGrpPopup.name = inp end
end
elseif zone.id == "cgrp_popup_toggle" then
if custGrpPopup then
local mn = zone.arg
if custGrpPopup.selected[mn] then
custGrpPopup.selected[mn] = nil
else
custGrpPopup.selected[mn] = true
end
end
elseif zone.id == "cgrp_popup_prev" then
if custGrpPopup then
custGrpPopup.page = math.max(1, (custGrpPopup.page or 1) - 1)
end
elseif zone.id == "cgrp_popup_next" then
if custGrpPopup then
custGrpPopup.page = (custGrpPopup.page or 1) + 1
end
elseif zone.id == "cgrp_popup_cancel" then
custGrpPopup = nil
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
elseif zone.id == "git_set_repo" then
gitActiveButton = "git_set_repo"
drawInterface()
term.clear(); term.setCursorPos(1,1)
write("GitHub repo (owner/repo): ")
local input = read("*")
gitActiveButton = ""
if input and input ~= "" then Config.github_repo = input; saveData() end
elseif zone.id == "git_set_token" then
gitActiveButton = "git_set_token"
drawInterface()
term.clear(); term.setCursorPos(1,1)
write("GitHub token (ghp_...): ")
local input = read("*")
gitActiveButton = ""
if input and input ~= "" then Config.github_token = input; saveData() end
elseif zone.id == "git_set_ntfy" then
gitActiveButton = "git_set_ntfy"
drawInterface()
term.clear(); term.setCursorPos(1,1)
write("ntfy topic or full URL (empty = off): ")
local input = read()
gitActiveButton = ""
Config.ntfy_topic = (input and input ~= "") and input or nil
saveData()
elseif zone.id == "ntfy_toggle_cmds" then
if Config.ntfy_cmds == false then Config.ntfy_cmds = true
else Config.ntfy_cmds = false end
saveData()
uiMessage = Config.ntfy_cmds and "Ntfy commands ON (send /status)" or "Ntfy commands OFF"
elseif zone.id == "git_export" then
gitActiveButton = "git_export"
doGitListForExport()
gitActiveButton = ""
elseif zone.id == "git_export_select" then
gitExportSelected = zone.arg
if zone.arg == 0 then
local defName = "autocraft_" .. tostring(math.floor(os.epoch("utc") / 1000))
gitStatus = "Type filename on PC keyboard..."
gitStatusColor = colors.yellow
drawInterface()
term.clear(); term.setCursorPos(1,1)
print("==========================================")
print(" GIT EXPORT: NEW FILE                     ")
print("==========================================")
print("")
print("Enter filename (without .json)")
print("Default: " .. defName)
print("Press ENTER to use default or empty to cancel.")
print("")
write("> ")
local fname = timedRead(60, defName)
gitExportMode = false
gitStatus = ""; gitStatusColor = colors.gray
if fname and fname ~= "" then
fname = fname:gsub("%.json$", "") .. ".json"
doGitExport(fname, nil)
end
end
elseif zone.id == "git_confirm_export" then
if gitExportSelected == 0 then
local defName = "autocraft_" .. tostring(math.floor(os.epoch("utc") / 1000))
gitStatus = "Type filename on PC keyboard..."
gitStatusColor = colors.yellow
drawInterface()
term.clear(); term.setCursorPos(1,1)
print("==========================================")
print(" GIT EXPORT: NEW FILE                     ")
print("==========================================")
print("")
print("Enter filename (without .json)")
print("Default: " .. defName)
print("Press ENTER to use default or empty to cancel.")
print("")
write("> ")
local fname = timedRead(60, defName)
gitExportMode = false
gitStatus = ""; gitStatusColor = colors.gray
if fname and fname ~= "" then
fname = fname:gsub("%.json$", "") .. ".json"
doGitExport(fname, nil)
end
else
gitExportMode = false
local file = gitExportFileList[gitExportSelected]
if file then doGitExport(file.name, file.sha) end
end
elseif zone.id == "git_cancel_export" then
gitExportMode = false
gitExportFileList = {}
gitExportSelected = 0
gitStatus = ""; gitStatusColor = colors.gray
elseif zone.id == "git_import_list" then
gitActiveButton = "git_import_list"
doGitListFiles()
gitActiveButton = ""
elseif zone.id == "git_select_file" then
gitSelectedFile = zone.arg
elseif zone.id == "git_import_prev" then
gitImportPage = math.max(1, gitImportPage - 1)
elseif zone.id == "git_import_next" then
gitImportPage = gitImportPage + 1
elseif zone.id == "git_export_prev" then
gitExportPage = math.max(1, gitExportPage - 1)
elseif zone.id == "git_export_next" then
gitExportPage = gitExportPage + 1
elseif zone.id == "git_confirm_import" then
doGitImport()
elseif zone.id == "git_cancel_import" then
gitImportMode = false
gitFileList = {}
gitStatus = ""
gitStatusColor = colors.gray
elseif zone.id == "mgmt_sync_now" then
mgmtSyncFlashTime = os.clock()
runMgmtTransfers()
elseif zone.id == "mgmt_new" then
mgmtPopup = {
mode="edit", groupIdx=nil,
name="", input="STORAGE", output="STORAGE", rules={},
inputs={}, outputs={},
drain=false, provider=false,
step="main", periPage=1, outPeriPage=1, itemPage=1,
}
elseif zone.id == "mgmt_edit" then
local g = MgmtGroups[zone.arg]
if g then
mgmtActiveBtn = nil
local rc = {}
for _, r in ipairs(g.rules or {}) do
local rcond = nil
if r.condition then
rcond = {item=r.condition.item, op=r.condition.op, value=r.condition.value}
end
table.insert(rc, {item=r.item, amount=r.amount, condition=rcond})
end
local inl, outl = {}, {}
for _, nm in ipairs(mgmtIOList(g, true))  do if nm ~= "STORAGE" then inl[#inl+1]  = nm end end
for _, nm in ipairs(mgmtIOList(g, false)) do if nm ~= "STORAGE" then outl[#outl+1] = nm end end
mgmtPopup = {
mode="edit", groupIdx=zone.arg,
name=g.name,
input  = g.input  or "STORAGE",
output = g.output or "STORAGE",
inputs = inl, outputs = outl,
rules=rc,
drain  = g.drain  or false,
provider = g.provider or false,
fluid  = mgmtGroupIsFluid(g),
step="main", periPage=1, outPeriPage=1, itemPage=1,
openerGi=zone.arg, openerBtn="edit",
}
end
elseif zone.id == "mgmt_pause" then
local g = MgmtGroups[zone.arg]
if g then
g.paused = not (g.paused or false)
mgmtActiveBtn = {gi=zone.arg, btn="pause", t=os.clock()}
saveData()
end
elseif zone.id == "mgmt_del" then
mgmtActiveBtn = nil
table.remove(MgmtGroups, zone.arg)
saveData()
elseif zone.id == "mgmt_view" then
local g = MgmtGroups[zone.arg]
if g then
mgmtActiveBtn = nil
mgmtPopup = {mode="view_input", groupIdx=zone.arg, page=1,
openerGi=zone.arg, openerBtn="view"}
end
elseif zone.id == "mgmt_list_prev" then mgmtPage = math.max(1, mgmtPage - 1)
elseif zone.id == "mgmt_list_next" then mgmtPage = mgmtPage + 1
elseif zone.id == "mgmt_edit_name" then
if mgmtPopup then
drawInterface()
term.clear(); term.setCursorPos(1,1)
write("Group name: ")
local inp = read()
if inp and inp ~= "" then mgmtPopup.name = inp end
end
elseif zone.id == "mgmt_rule_type" then
if mgmtPopup then
local ri3t = zone.arg
local rule = mgmtPopup.rules[ri3t]
if rule then
drawInterface()
term.clear(); term.setCursorPos(1,1)
write("Amount for " .. (rule.item:match(":(.+)$") or rule.item) .. ": ")
local inp = read()
local n = tonumber(inp)
if n and n >= 1 then rule.amount = math.floor(n) end
end
end
elseif zone.id == "mgmt_pick_input" then
if mgmtPopup then mgmtPopup.step = "input_select"; mgmtPopup.periPage = 1 end
elseif zone.id == "mgmt_set_input" then
if mgmtPopup then
local lst = mgmtPopup.inputs or {}
if zone.arg == "STORAGE" then
lst = {}
else
local found
for i, nm in ipairs(lst) do if nm == zone.arg then found = i; break end end
if found then table.remove(lst, found) else lst[#lst + 1] = zone.arg end
end
mgmtPopup.inputs = lst
mgmtPopup.input  = lst[1] or "STORAGE"
mgmtPopup.fluid = mgmtIsFluidPeriph(mgmtPopup.input) or mgmtIsFluidPeriph(mgmtPopup.output)
end
elseif zone.id == "mgmt_peri_prev" then
if mgmtPopup then mgmtPopup.periPage = math.max(1, mgmtPopup.periPage - 1) end
elseif zone.id == "mgmt_peri_next" then
if mgmtPopup then mgmtPopup.periPage = mgmtPopup.periPage + 1 end
elseif zone.id == "mgmt_peri_cancel" then
if mgmtPopup then mgmtPopup.step = "main" end
elseif zone.id == "mgmt_pick_output" then
if mgmtPopup then mgmtPopup.step = "output_select"; mgmtPopup.outPeriPage = 1 end
elseif zone.id == "mgmt_set_output" then
if mgmtPopup then
local lst = mgmtPopup.outputs or {}
if zone.arg == "STORAGE" then
lst = {}
else
local found
for i, nm in ipairs(lst) do if nm == zone.arg then found = i; break end end
if found then table.remove(lst, found) else lst[#lst + 1] = zone.arg end
end
mgmtPopup.outputs = lst
mgmtPopup.output  = lst[1] or "STORAGE"
mgmtPopup.fluid = mgmtIsFluidPeriph(mgmtPopup.input) or mgmtIsFluidPeriph(mgmtPopup.output)
end
elseif zone.id == "mgmt_pick_item" then
if mgmtPopup then
mgmtPopup.step = "item_select"; mgmtPopup.itemPage = 1
mgmtItemSearch = ""; mgmtItemSearchActive = false
end
elseif zone.id == "mgmt_add_rule" then
if mgmtPopup then
local condIdx = mgmtPopup.condPickRuleIdx
if condIdx then
local rule = mgmtPopup.rules[condIdx]
if rule then
if not rule.condition then rule.condition = {op="<", value=1} end
rule.condition.item = zone.arg
end
mgmtPopup.condPickRuleIdx = nil
else
local exists = false
for _, r in ipairs(mgmtPopup.rules) do
if r.item == zone.arg then exists = true; break end
end
if not exists then
table.insert(mgmtPopup.rules, {item=zone.arg, amount=(mgmtPopup.fluid and 1000 or 64)})
end
end
mgmtPopup.step = "main"
end
elseif zone.id == "mgmt_item_prev" then
if mgmtPopup then mgmtPopup.itemPage = math.max(1, mgmtPopup.itemPage - 1) end
elseif zone.id == "mgmt_item_next" then
if mgmtPopup then mgmtPopup.itemPage = mgmtPopup.itemPage + 1 end
elseif zone.id == "mgmt_rules_prev" then
if mgmtPopup then mgmtPopup.rulesPage = math.max(1, (mgmtPopup.rulesPage or 1) - 1) end
elseif zone.id == "mgmt_rules_next" then
if mgmtPopup then mgmtPopup.rulesPage = (mgmtPopup.rulesPage or 1) + 1 end
elseif zone.id == "mgmt_item_cancel" then
if mgmtPopup then
mgmtPopup.condPickRuleIdx = nil
mgmtPopup.step = "main"
end
elseif zone.id == "mgmt_rule_adj" then
if mgmtPopup then
local ri3  = zone.arg[1]
local delta = zone.arg[2]
local rule = mgmtPopup.rules[ri3]
if rule then
local stepU = mgmtPopup.fluid and 100 or 1
local capU  = mgmtPopup.fluid and 1000000 or 9999
rule.amount = math.max(1, math.min(capU, rule.amount + delta * stepU))
end
end
elseif zone.id == "mgmt_rule_del" then
if mgmtPopup then table.remove(mgmtPopup.rules, zone.arg) end
elseif zone.id == "mgmt_toggle_drain" then
if mgmtPopup then
mgmtPopup.drain = not (mgmtPopup.drain or false)
if mgmtPopup.drain then mgmtPopup.provider = false end
end
elseif zone.id == "mgmt_toggle_provider" then
if mgmtPopup then
mgmtPopup.provider = not (mgmtPopup.provider or false)
if mgmtPopup.provider then mgmtPopup.drain = false end
end
elseif zone.id == "mgmt_rule_if_add" then
if mgmtPopup then
local ri = zone.arg
local rule = mgmtPopup.rules[ri]
if rule then
rule.condition = {item = "", op = "<", value = 1}
mgmtPopup.condPickRuleIdx = ri
mgmtPopup.step = "item_select"
mgmtPopup.itemPage = 1
mgmtItemSearch = ""
mgmtItemSearchActive = false
end
end
elseif zone.id == "mgmt_rule_if_item" then
if mgmtPopup then
mgmtPopup.condPickRuleIdx = zone.arg
mgmtPopup.step = "item_select"
mgmtPopup.itemPage = 1
mgmtItemSearch = ""
mgmtItemSearchActive = false
end
elseif zone.id == "mgmt_rule_if_op" then
if mgmtPopup then
local rule = mgmtPopup.rules[zone.arg]
if rule and rule.condition then
local ops = {"<", "=", ">"}
local cur = rule.condition.op or "<"
for i, op in ipairs(ops) do
if op == cur then
rule.condition.op = ops[(i % #ops) + 1]
break
end
end
end
end
elseif zone.id == "mgmt_rule_if_adj" then
if mgmtPopup then
local rule = mgmtPopup.rules[zone.arg[1]]
if rule and rule.condition then
local stepC = mgmtPopup.fluid and 100 or 1
local capC  = mgmtPopup.fluid and 1000000 or 99999
rule.condition.value = math.max(1, math.min(capC,
(rule.condition.value or 1) + zone.arg[2] * stepC))
end
end
elseif zone.id == "mgmt_rule_if_type" then
if mgmtPopup then
local rule = mgmtPopup.rules[zone.arg]
if rule and rule.condition then
local cName = rule.condition.item:match(":(.+)$") or rule.condition.item
drawInterface()
term.clear(); term.setCursorPos(1,1)
write("IF value for " .. cName .. ": ")
local inp = read()
local n = tonumber(inp)
if n and n >= 1 then rule.condition.value = math.floor(n) end
end
end
elseif zone.id == "mgmt_rule_if_del" then
if mgmtPopup then
local rule = mgmtPopup.rules[zone.arg]
if rule then rule.condition = nil end
end
elseif zone.id == "mgmt_outperi_prev" then
if mgmtPopup then mgmtPopup.outPeriPage = math.max(1, (mgmtPopup.outPeriPage or 1) - 1) end
elseif zone.id == "mgmt_outperi_next" then
if mgmtPopup then mgmtPopup.outPeriPage = (mgmtPopup.outPeriPage or 1) + 1 end
elseif zone.id == "mgmt_outperi_cancel" then
if mgmtPopup then mgmtPopup.step = "main" end
elseif zone.id == "mgmt_save" then
if mgmtPopup then
if mgmtPopup.name == "" then
uiMessage = "Enter a group name first!"
uiMsgTimer = os.startTimer(2)
else
local inl  = mgmtPopup.inputs  or {}
local outl = mgmtPopup.outputs or {}
local newG = {
name   = mgmtPopup.name,
inputs = inl,
outputs = outl,
input  = inl[1]  or "STORAGE",
output = outl[1] or "STORAGE",
rules  = mgmtPopup.rules  or {},
drain  = mgmtPopup.drain  or false,
provider = mgmtPopup.provider or false,
fluid  = mgmtPopup.fluid or mgmtGroupIsFluid({input=inl[1] or "STORAGE", output=outl[1] or "STORAGE"}),
paused = mgmtPopup.groupIdx and (MgmtGroups[mgmtPopup.groupIdx] and MgmtGroups[mgmtPopup.groupIdx].paused or false) or false,
}
if mgmtPopup.groupIdx then
MgmtGroups[mgmtPopup.groupIdx] = newG
else
table.insert(MgmtGroups, newG)
end
saveData()
if mgmtPopup.openerGi and mgmtPopup.openerBtn then
mgmtActiveBtn = {gi=mgmtPopup.openerGi, btn=mgmtPopup.openerBtn, t=os.clock()}
end
mgmtPopup = nil
end
end
elseif zone.id == "mgmt_cancel" then
if mgmtPopup and mgmtPopup.openerGi and mgmtPopup.openerBtn then
mgmtActiveBtn = {gi=mgmtPopup.openerGi, btn=mgmtPopup.openerBtn, t=os.clock()}
end
mgmtPopup = nil
elseif zone.id == "mgmt_close_view" then
if mgmtPopup and mgmtPopup.openerGi and mgmtPopup.openerBtn then
mgmtActiveBtn = {gi=mgmtPopup.openerGi, btn=mgmtPopup.openerBtn, t=os.clock()}
end
mgmtPopup = nil
elseif zone.id == "mgmt_vinput_prev" then
if mgmtPopup then mgmtPopup.page = math.max(1, mgmtPopup.page - 1) end
elseif zone.id == "mgmt_vinput_next" then
if mgmtPopup then mgmtPopup.page = mgmtPopup.page + 1 end
elseif zone.id == "mgmt_search_focus" then
mgmtItemSearchActive = true
drawInterface()
term.clear() term.setCursorPos(1,1)
write("> ")
local srInput = timedRead(5)
mgmtItemSearchActive = false
if srInput ~= nil then
mgmtItemSearch = srInput
end
if mgmtPopup then mgmtPopup.itemPage = 1 end
elseif zone.id == "mgmt_search_clear" then
mgmtItemSearch = ""
if mgmtPopup then mgmtPopup.itemPage = 1 end
end
break
end
end
end
end
end
local function runMain()
initDataFiles()
loadData()
syncFluidItemStubs()
parallel.waitForAny(
function()
while true do
local ev, p1, p2, p3 = os.pullEvent("monitor_touch")
if systemStatus == "IDLE" then
pendingTouches[#pendingTouches + 1] = {ev, p1, p2, p3}
if #pendingTouches > 5 then table.remove(pendingTouches, 1) end
end
end
end,
function()
while true do
local ev, ch = os.pullEvent()
local noPopup = not custGrpPopup and not mgmtPopup
and craftInfoPopup == nil and machineInfoPopup == nil
and historyPopup == nil and recipeEditPopup == nil
and craftCompletePopup == nil and pendingDeleteItem == nil
local fluidSearchable = currentTab == "FLUID" and (fluidSubTab == "FLUID" or fluidSubTab == "FITEM")
and not fluidLearnStage and not fluidRecipePicker and not fluidCraftWaitFluid
if ev == "char" and noPopup then
if currentTab == "RECIPES" then
searchFilter = searchFilter .. ch
currentPage = 1
elseif currentTab == "STOCK" then
stockSearchFilter = stockSearchFilter .. ch
currentPage = 1
elseif fluidSearchable then
fluidSearchFilter = fluidSearchFilter .. ch
fluidRecipePage = 1
end
elseif ev == "key" and noPopup and ch == keys.backspace then
if currentTab == "RECIPES" and #searchFilter > 0 then
searchFilter = searchFilter:sub(1, -2)
currentPage = 1
elseif currentTab == "STOCK" and #stockSearchFilter > 0 then
stockSearchFilter = stockSearchFilter:sub(1, -2)
currentPage = 1
elseif fluidSearchable and #fluidSearchFilter > 0 then
fluidSearchFilter = fluidSearchFilter:sub(1, -2)
fluidRecipePage = 1
end
end
end
end,
mainLoop,
function()
while true do
sleep(10)
runMgmtTransfers()
end
end,
function()
while true do
sleep(5)
pcall(ntfyPollCommands)
end
end
)
end
while true do
local ok, err = pcall(runMain)
if not ok then
print("[AUTOCRAFT] Crashed: " .. tostring(err))
print("[AUTOCRAFT] Restarting in 3s...")
sleep(3)
end
end

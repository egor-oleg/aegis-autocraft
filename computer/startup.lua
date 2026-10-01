--<00_core/00_0_config.lua
MONITOR_SIDE = "right"
SYSTEM_SIDES = { top = true, bottom = true, left = true, right = true, front = true, back = true }

RECIPES_FILE        = "factory_recipes.json"
CONFIG_FILE         = "factory_config.json"
AUTOSTOCK_FILE      = "factory_autostock.json"
GROUPS_FILE         = "factory_groups.json"
ALT_RECIPES_FILE    = "factory_alt_recipes.json"
MGMT_FILE           = "factory_mgmt.json"
MACHINE_LABELS_FILE = "factory_machine_labels.json"
CUSTOM_MG_FILE      = "factory_custom_mg.json"
FLUIDS_FILE         = "factory_fluids.json"
FLUID_ALTS_FILE     = "factory_fluid_alts.json"

Config = {
storages         = {},
fluid_tanks      = {},
train_box        = nil,
turtles          = {},
autostock_paused = false,
github_repo      = "",
github_token     = "",
}

function shortName(n) return n and (n:match(":(.+)$") or n) end

_B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
-->00_core/00_0_config.lua
--<00_core/00_1_legacy_globals.lua
Recipes          = {}
AltRecipes       = {}
FluidRecipes     = {}
FluidAltRecipes  = {}
FluidStock       = {}
Autostock        = {}
ExcludedMachines = {}

MgmtGroups          = {}
MachineLabels       = {}
CustomMachineGroups = {}
ITEM_GROUPS         = {}
GROUPS              = {}

stageDone  = 0
stageTotal = 0

craftCancelY  = nil
craftCancelX1 = 2
craftCancelX2 = 20

fluidTankClaims = 0
_fluidBusy = false
fluidInlineByCo = {}

fluidGoalLabel      = ""
fluidStepNum        = 0
fluidStepTotal      = 1
fluidSubLabel       = ""
fluidCraftMsg       = ""
fluidWaitInput = nil
fluidWaitCraft = nil

uiMessage      = ""
uiMsgTimer     = nil
pendingTouches = {}

displayCtx = nil
-->00_core/00_1_legacy_globals.lua
--<00_core/00_2_boot.lua
monitor = peripheral.wrap(MONITOR_SIDE)
if not monitor then
monitor = peripheral.find("monitor")
if monitor then MONITOR_SIDE = peripheral.getName(monitor) end
end
if not monitor then error("Monitor not found on any side") end
monitor.setTextScale(0.5)
-->00_core/00_2_boot.lua
--<00_core/00_3_api.lua
aegis = {
version = "0.1.0",
storage = {},
recipes = {},
craft   = {},
jobs    = {},
fluids  = {},
}
function aegis.rpc(path, args)
local node = aegis
for part in tostring(path):gmatch("[^%.]+") do
if type(node) ~= "table" then return nil, "bad path: " .. path end
node = node[part]
end
if type(node) ~= "function" then return nil, "no method: " .. path end
return node(table.unpack(args or {}))
end
-->00_core/00_3_api.lua
--<10_data/10_0_json.lua
function parseJSON(str)
local result = textutils.unserializeJSON(str)
if result == textutils.empty_json_array then return {} end
return result
end

_savedCounts = {}
restoredFromBak = false

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
if fs.exists(bak) and fs.getSize(bak) == 0 then fs.delete(bak) end
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
fs.delete(path .. ".corrupt")
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
restoredFromBak = true
return bp
end
end
end
if type(parsed) == "table" then _savedCounts[path] = 0 end
return parsed
end
-->10_data/10_0_json.lua
--<10_data/10_1_persist.lua
function initData()
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

function loadData()
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
local raw = loadDataFile(CUSTOM_MG_FILE) or {}
if type(raw) == "table" then CustomMachineGroups = raw end
end
end

function syncFluidStubs()
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

function saveData()
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
fs.delete(tmp)
fs.delete(path .. ".bak")
okW = tryWrite()
end
if not okW then
fs.delete(tmp)
failNote = "SAVE FAIL (disk space?): " .. fs.getName(path)
return
end
fs.delete(path)
fs.move(tmp, path)
local free = fs.getFreeSpace("/") or 0
if free > fs.getSize(path) + 4096 then
fs.delete(path .. ".bak")
pcall(fs.copy, path, path .. ".bak")
end
_savedCounts[path] = n
end
local recToSave = {}
for k, v in pairs(Recipes) do
if not (type(v) == "table" and v.type == "fluid") then recToSave[k] = v end
end
writeFile(RECIPES_FILE, recToSave)
local cfgToSave = {}
for k, v in pairs(Config) do cfgToSave[k] = v end
cfgToSave.github_token = nil
cfgToSave.github_repo  = nil
writeFile(CONFIG_FILE, cfgToSave)
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
-->10_data/10_1_persist.lua
--<10_data/10_2_recipes.lua
function findDup(outName, cand)
local function sig(r)
if type(r) ~= "table" or r.type == "fluid" then return nil end
local parts = {}
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
-->10_data/10_2_recipes.lua
--<10_data/10_2_registry.lua
Groups = {}

function Groups.altsOf(itemName)
local key = ITEM_GROUPS[itemName]
if not key then return nil end
return GROUPS[key]
end

Recipe = {}

function Recipe.find(name)
return Recipes[name]
end

function Recipe.altsOf(name)
return AltRecipes[name]
end

function Recipe.set(name, r)
Recipes[name] = r
end

function Recipe.setAlts(name, alts)
AltRecipes[name] = alts
end

function Recipe.remove(name)
Recipes[name] = nil
end

function Recipe.all()
return Recipes
end

function Recipe.allAlts()
return AltRecipes
end
-->10_data/10_2_registry.lua
--<20_storage/20_0_inventory.lua
function scanPeriph(names, method, withSize)
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

function getInv()
local inventory = {}
local totalItems, vaultsCnt = 0, 0
local totalSlots, usedSlots = 0, 0
local names = {}
for storageName, isEnabled in pairs(Config.storages) do
if isEnabled and not SYSTEM_SIDES[storageName] then names[#names + 1] = storageName end
end
local scanned = scanPeriph(names, "list", true)
for _, nm in ipairs(names) do
local e = scanned[nm]
if e then
vaultsCnt = vaultsCnt + 1
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
local provNames = {}
for _, nm in ipairs(providerSrc()) do
if not isBridge(nm) then provNames[#provNames + 1] = nm end
end
local pScan = scanPeriph(provNames, "list")
for _, nm in ipairs(provNames) do
local e = pScan[nm]
if e and e.data then
for _, item in pairs(e.data) do
if item then inventory[item.name] = (inventory[item.name] or 0) + item.count end
end
end
end
for name, cnt in pairs(bridgeStock()) do
inventory[name] = (inventory[name] or 0) + cnt
end
local freeSlots = totalSlots - usedSlots
return inventory, totalItems, vaultsCnt, freeSlots, totalSlots
end
_flInvCache, _flInvCacheT = nil, -100
_tankStatsCache, _tankStatsT = nil, -100
_stInvCache, _stInvCacheT = nil, -100

function resetStock()
_flInvCacheT = -100
_tankStatsT = -100
_stInvCacheT = -100
stockEpoch = (stockEpoch or 0) + 1
end

function getInvCached()
local now = os.clock()
if _stInvCache and (now - _stInvCacheT) < 4 then
local c = _stInvCache
return c[1], c[2], c[3], c[4], c[5]
end
local a, b, cc, d, e = getInv()
_stInvCache = {a, b, cc, d, e}
_stInvCacheT = now
return a, b, cc, d, e
end


function optStore()
local names = {}
for storageName, isEnabled in pairs(Config.storages) do
if isEnabled and not SYSTEM_SIDES[storageName] then names[#names + 1] = storageName end
end
if #names == 0 then return end

local packTasks = {}
for _, sName in ipairs(names) do
local nm = sName
packTasks[#packTasks + 1] = function()
local sto = peripheral.wrap(nm)
if not (sto and sto.list and sto.pushItems) then return end
local ok, items = pcall(sto.list)
if not (ok and items) then return end
local byName = {}
for slot, item in pairs(items) do
if item then
byName[item.name] = byName[item.name] or {}
byName[item.name][#byName[item.name] + 1] = slot
end
end
for _, slots in pairs(byName) do
if #slots > 1 then
table.sort(slots)
local target = 1
for i = 2, #slots do
local ok2, n = pcall(sto.pushItems, nm, slots[i], 64, slots[target])
local moved = (ok2 and n) or 0
if moved == 0 and target < i - 1 then
target = target + 1
pcall(sto.pushItems, nm, slots[i], 64, slots[target])
end
end
end
end
end
end
parallel.waitForAll(table.unpack(packTasks))

local scanned = scanPeriph(names, "list")
local perItem = {}
for _, sName in ipairs(names) do
local e = scanned[sName]
if e and e.data then
local sto = peripheral.wrap(sName)
if sto and sto.pushItems then
for slot, item in pairs(e.data) do
if item and (item.count or 0) > 0 then
perItem[item.name] = perItem[item.name] or {}
perItem[item.name][#perItem[item.name] + 1] = {sName=sName, sto=sto, slot=slot, count=item.count}
end
end
end
end
end

local movesBySrc = {}
for name, locs in pairs(perItem) do
local totBy = {}
for _, l in ipairs(locs) do totBy[l.sName] = (totBy[l.sName] or 0) + l.count end
local uniq = 0
for _ in pairs(totBy) do uniq = uniq + 1 end
if uniq > 1 then
local best, bestCnt = nil, -1
for c, cnt in pairs(totBy) do
if cnt > bestCnt then best, bestCnt = c, cnt end
end
for _, l in ipairs(locs) do
if l.sName ~= best then
movesBySrc[l.sName] = movesBySrc[l.sName] or {}
local q = movesBySrc[l.sName]
q[#q + 1] = {name=name, sto=l.sto, slot=l.slot, dst=best}
end
end
end
end

local mergeTasks = {}
for _, moves in pairs(movesBySrc) do
local list = moves
mergeTasks[#mergeTasks + 1] = function()
for _, m in ipairs(list) do
local okD, det = pcall(m.sto.getItemDetail, m.slot)
if okD and det and det.name == m.name and (det.count or 0) > 0 then
pcall(m.sto.pushItems, m.dst, m.slot, det.count)
end
end
end
end
if #mergeTasks > 0 then
parallel.waitForAll(table.unpack(mergeTasks))
end

resetStock()
end

function scanStorage()
if craftScan then return craftScan end
local names, seen = {}, {}
for storageName, isEnabled in pairs(Config.storages) do
if isEnabled and not SYSTEM_SIDES[storageName] and not seen[storageName] then
seen[storageName] = true; names[#names + 1] = storageName
end
end
for _, pName in ipairs(providerSrc()) do
if not seen[pName] and not isBridge(pName) then seen[pName] = true; names[#names + 1] = pName end
end
return names
end

pushFromStore = function(itemName, amountNeeded, targetMach, targetSlot, prescan)
if Craft.cancelled then return 0 end
local moved = 0

local alts = Groups.altsOf(itemName)
local altItems = {}
if alts then
for _, altName in ipairs(alts) do
if altName ~= itemName then altItems[altName] = true end
end
end
local hasAlts = next(altItems) ~= nil

local exactSlots = {}
local altSlots   = {}
local scanNames = scanStorage()

local scanned = prescan or scanPeriph(scanNames, "list")
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
table.insert(altSlots,   {storage=storage, stoName=stoName, slot=slot, count=item.count, name=item.name})
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
local ok, mv = pcall(entry.storage.pushItems, targetMach, entry.slot, toMove, targetSlot)
if ok and mv then moved = moved + mv end
if targetSlot and (mv or 0) == 0 then return "reject" end
end

local rejected = false
for _, entry in ipairs(exactSlots) do
if Craft.cancelled or moved >= amountNeeded then break end
if verifiedPush(entry) == "reject" then rejected = true; break end
end
for _, entry in ipairs(altSlots) do
if Craft.cancelled or moved >= amountNeeded then break end
if verifiedPush(entry) == "reject" then rejected = true; break end
end

if moved < amountNeeded and targetMach then
local mPeriph = peripheral.wrap(targetMach)
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
if ok3 and type(mv3) == "number" and mv3 > 0 then
moved = moved + mv3
else
return
end
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

if not Craft.cancelled then pullReverse(exactSlots) end
if not Craft.cancelled then pullReverse(altSlots)   end
end
end

if moved < amountNeeded and targetMach and not rejected and not Craft.cancelled then
moved = moved + bridgeFeed(itemName, amountNeeded - moved, targetMach, targetSlot)
end

if moved > 0 then resetStock() end
return moved
end
-->20_storage/20_0_inventory.lua
--<20_storage/20_1_bridge.lua

function isBridge(name)
if not name or name == "" or name == "STORAGE" then return false end
local p = peripheral.wrap(name)
if not p then return false end
return p.getItems ~= nil and p.exportItem ~= nil
end

function bridgeSrc()
local out = {}
for _, nm in ipairs(providerSrc()) do
if isBridge(nm) then out[#out + 1] = nm end
end
return out
end

function bridgeStock()
local out = {}
for _, nm in ipairs(bridgeSrc()) do
local b = peripheral.wrap(nm)
if b then
local ok, items = pcall(b.getItems)
if ok and type(items) == "table" then
for _, it in pairs(items) do
if it and it.name then
out[it.name] = (out[it.name] or 0) + (it.count or it.amount or 0)
end
end
end
end
end
return out
end

function bridgeExport(itemName, amount, dstName)
if not dstName or amount <= 0 then return 0 end
local moved = 0
for _, nm in ipairs(bridgeSrc()) do
if moved >= amount then break end
local b = peripheral.wrap(nm)
if b then
local ok, mv, err = pcall(b.exportItem, {name = itemName, count = amount - moved}, dstName)
if ok and type(mv) == "number" then moved = moved + mv end
if not ok then err = mv end
if err then
dbgWrite(string.format("bridge.export %s -> %s : %s", shortName(itemName), tostring(dstName), tostring(err)))
end
end
end
if moved > 0 then resetStock() end
return moved
end

function bridgeStage(itemName, amount)
if amount <= 0 or #bridgeSrc() == 0 then return nil, 0 end
for sName, isEnabled in pairs(Config.storages) do
if isEnabled and not SYSTEM_SIDES[sName] then
local mv = bridgeExport(itemName, amount, sName)
if mv > 0 then return sName, mv end
end
end
return nil, 0
end

function bridgeFeed(itemName, amount, dstName, dstSlot)
if amount <= 0 or #bridgeSrc() == 0 then return 0 end
if not dstSlot then return bridgeExport(itemName, amount, dstName) end
local vault, staged = bridgeStage(itemName, amount)
local sto = vault and peripheral.wrap(vault)
if not sto then return 0 end
local ok, items = pcall(sto.list)
if not (ok and items) then return 0 end
local moved = 0
for slot, it in pairs(items) do
if moved >= staged then break end
if it and it.name == itemName then
local ok2, mv = pcall(sto.pushItems, dstName, slot, staged - moved, dstSlot)
if ok2 and mv then moved = moved + mv end
if (mv or 0) == 0 then break end
end
end
if moved > 0 then resetStock() end
return moved
end
-->20_storage/20_1_bridge.lua
--<30_fluids/30_0_inventory.lua
function fluidKey(fluidName) return "f:" .. fluidName end

function fluidNameOf(key)
if type(key) == "string" and key:sub(1, 2) == "f:" then return key:sub(3) end
return key
end

function primaryKey(recipe)
if recipe.outputs and recipe.outputs[1] then return fluidKey(recipe.outputs[1].name) end
if recipe.item_outputs and recipe.item_outputs[1] then return "i:" .. recipe.item_outputs[1].name end
return nil
end

function findFluidItemProd(itemName)
for _, rec in pairs(Fluids.all()) do
for _, o in ipairs(rec.item_outputs or {}) do
if o.name == itemName then return rec, o.count end
end
end
for _, alts in pairs(Fluids.allAlts()) do
for _, rec in ipairs(alts) do
for _, o in ipairs(rec.item_outputs or {}) do
if o.name == itemName then return rec, o.count end
end
end
end
return nil
end

function getFluid()
local inventory  = {}
local tankCount  = 0
local totalMb    = 0
local tankDetails = {}
local names = {}
for tankName, isEnabled in pairs(Config.fluid_tanks or {}) do
if isEnabled and not SYSTEM_SIDES[tankName] then names[#names + 1] = tankName end
end
local scanned = scanPeriph(names, "tanks")
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

function getFluidCached()
local now = os.clock()
if _flInvCache and (now - _flInvCacheT) < 6 then return _flInvCache end
_flInvCache = (getFluid())
_flInvCacheT = now
return _flInvCache
end

function getTankStats()
local now = os.clock()
if _tankStatsCache and (now - _tankStatsT) < 6 then
return _tankStatsCache.free, _tankStatsCache.total
end
local total, free = 0, 0
local names = {}
for tankName, en in pairs(Config.fluid_tanks or {}) do
if en and not SYSTEM_SIDES[tankName] then names[#names + 1] = tankName end
end
local scanned = scanPeriph(names, "tanks")
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

function fluidTankList()
local out = {}
for name, en in pairs(Config.fluid_tanks or {}) do
if en and not SYSTEM_SIDES[name] then out[#out + 1] = name end
end
return out
end

function tankContents(periphName)
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


function optTanks()
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
-->30_fluids/30_0_inventory.lua
--<30_fluids/30_1_scan.lua
function runFluidScan(inputs, machineName, outputDevice, itemInputDevice, fluidInputDev, itemOutputDev)
local machine = peripheral.wrap(machineName)
if not (machine and machine.tanks and machine.pushFluid and machine.pullFluid) then
return false, nil, {"Machine missing fluid methods:", machineName}
end

local fluidOutName = (outputDevice and outputDevice ~= "") and outputDevice or machineName
local fluidOutObj  = (fluidOutName ~= machineName) and peripheral.wrap(fluidOutName) or machine
if not fluidOutObj then return false, nil, {"Fluid output device offline:", fluidOutName} end

local itemInName  = (itemInputDevice  and itemInputDevice  ~= "") and itemInputDevice  or machineName
if itemInName  ~= machineName and not peripheral.wrap(itemInName)  then return false, nil, {"Item input device offline:",  itemInName}  end
local fluidInName = (fluidInputDev and fluidInputDev ~= "") and fluidInputDev or machineName
if fluidInName ~= machineName and not peripheral.wrap(fluidInName) then return false, nil, {"Fluid input device offline:", fluidInName} end
local itemOutName = (itemOutputDev and itemOutputDev ~= "") and itemOutputDev or fluidOutName
if itemOutName ~= machineName and not peripheral.wrap(itemOutName) then return false, nil, {"Item output device offline:", itemOutName} end

local errLines = {}
local inv = getFluid()
for _, inp in ipairs(inputs) do
local have = inv[fluidKey(inp.name)] or 0
if have < inp.amount then
table.insert(errLines, string.format("Need %d mB %s, have %d", inp.amount, inp.name, have))
end
end
if #errLines > 0 then return false, nil, errLines end

local before = machFluidSnap(fluidOutObj)
local itemsBefore = machItemSnap(itemOutName)

for _, inp in ipairs(inputs) do
local m = pushFluidToMach(fluidInName, inp.name, inp.amount)
if m < inp.amount then
table.insert(errLines, string.format("Only pushed %d/%d mB %s", m, inp.amount, inp.name))
end
end

local itemCounts = barrelToMach(itemInName)
local inputSet = {}
for _, inp in ipairs(inputs) do inputSet[inp.name] = true end
local inputItemSet = {}
for iname in pairs(itemCounts) do inputItemSet[iname] = true end

local function drainAll()
for fname in pairs(machFluidSnap(fluidOutObj)) do drainFluid(fluidOutName, fname, 1000000) end
for fname in pairs(machFluidSnap(machine)) do
if not inputSet[fname] then drainFluid(machineName, fname, 1000000) end
end
drainMachItems(machineName)
if itemOutName ~= machineName then drainMachItems(itemOutName) end
if itemInName  ~= machineName then drainMachItems(itemInName)  end
end

local outputs = {}
local itemOutputs = {}
local cancelled = false
local separateOut = (fluidOutName ~= machineName) or (itemOutName ~= machineName)

if separateOut then
local fAgg, iAgg = {}, {}
local quiet, sawAny = 0, false
while true do
if drawFluidCancel then drawFluidCancel() end
sleepCancel(0.5)
if Craft.cancelled then cancelled = true; break end
local moved = false
for fname, amt in pairs(machFluidSnap(fluidOutObj)) do
if not inputSet[fname] and amt > 0 then
local mv = drainFluid(fluidOutName, fname, 1000000)
if mv and mv > 0 then fAgg[fname] = (fAgg[fname] or 0) + mv; moved = true; sawAny = true end
end
end
local hadItems = false
for iname, cnt in pairs(machItemSnap(itemOutName)) do
if not inputItemSet[iname] and cnt > 0 then
iAgg[iname] = (iAgg[iname] or 0) + cnt; moved = true; sawAny = true; hadItems = true
end
end
if hadItems then drainMachItems(itemOutName) end
if moved then quiet = 0 else quiet = quiet + 1 end
if sawAny and quiet >= 6 then break end
end
for fname, amt in pairs(fAgg) do if amt > 0 then outputs[#outputs + 1] = {kind = "fluid", name = fname, amount = amt} end end
for iname, cnt in pairs(iAgg) do if cnt > 0 then itemOutputs[#itemOutputs + 1] = {kind = "item", name = iname, count = cnt} end end
else
local after
after, cancelled = waitFluidStable(fluidOutObj, fluidOutName, 0, true, drawFluidCancel)
if not cancelled then
for fname, amt in pairs(after) do
if not inputSet[fname] then
local net = amt - (before[fname] or 0)
if net > 0 then outputs[#outputs + 1] = {kind = "fluid", name = fname, amount = net} end
end
end
for iname, cnt in pairs(machItemSnap(itemOutName)) do
if not inputItemSet[iname] then
local net = cnt - (itemsBefore[iname] or 0)
if net > 0 then itemOutputs[#itemOutputs + 1] = {kind = "item", name = iname, count = net} end
end
end
end
end

local function drainFluidIn()
if fluidInName ~= machineName then
for fname in pairs(machFluidSnap(peripheral.wrap(fluidInName))) do drainFluid(fluidInName, fname, 1000000) end
end
end

if cancelled then
drainAll(); drainFluidIn(); sleep(0.3); drainAll(); drainFluidIn()
return false, nil, {"Scan cancelled by user."}
end

table.sort(outputs,     function(a, b) return a.amount > b.amount end)
table.sort(itemOutputs, function(a, b) return a.count  > b.count  end)
drainAll(); drainFluidIn(); sleep(0.3); drainAll(); drainFluidIn()

if #outputs == 0 and #itemOutputs == 0 then
table.insert(errLines, "No output detected (fluid or item).")
return false, nil, errLines
end

if Config.train_box and Config.train_box ~= "" then
for _, io2 in ipairs(itemOutputs) do
pushFromStore(io2.name, io2.count, Config.train_box)
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

return true, {
machine_name       = machineName,
output_device      = (outputDevice     and outputDevice     ~= "") and outputDevice     or nil,
item_input_device  = (itemInputDevice  and itemInputDevice  ~= "") and itemInputDevice  or nil,
fluid_input_device = (fluidInputDev and fluidInputDev ~= "") and fluidInputDev or nil,
item_output_device = (itemOutputDev and itemOutputDev ~= "") and itemOutputDev or nil,
inputs        = recipeInputs,
item_inputs   = itemInputs,
outputs       = outputs,
item_outputs  = itemOutputs,
}, nil
end
-->30_fluids/30_1_scan.lua
--<30_fluids/30_2_registry.lua
Fluids = {}

function Fluids.find(fk)
return FluidRecipes[fk]
end

function Fluids.altsOf(fk)
return FluidAltRecipes[fk]
end

function Fluids.set(fk, recipe)
FluidRecipes[fk] = recipe
end

function Fluids.setAlts(fk, alts)
FluidAltRecipes[fk] = alts
end

function Fluids.remove(fk)
FluidRecipes[fk] = nil
end

function Fluids.all()
return FluidRecipes
end

function Fluids.allAlts()
return FluidAltRecipes
end
-->30_fluids/30_2_registry.lua
--<30_fluids/30_a_state.lua
fluidSubTab          = "FLUID"
fluidTankPage        = 1
fluidRecipePage      = 1
fluidLearnStage      = nil
learnInputs     = {}
learnMach    = nil
learnOut     = nil
fluidOutPick      = false
learnItemIn     = nil
fluidItemInPick      = false
learnFluidIn    = nil
fluidInPick     = false
learnItemOut    = nil
itemOutPick     = false
fluidLearnPage       = 1
fluidScanStatus      = ""
fluidRecipePicker    = nil
fluidSaveConfirm     = nil
pendDelFluid   = nil
fluidKeepName        = nil
fluidKeepFilter      = "All"
fluidSearchFilter    = ""
fluidCraftMode       = nil
fluidScanResults     = {}
_fpCache             = {}
-->30_fluids/30_a_state.lua
--<40_machines/40_0_control.lua
function tanksWFluid(fluidName)
local out = {}
local names = fluidTankList()
local scanned = scanPeriph(names, "tanks")
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

function pushFluidToMach(machineName, fluidName, amount)
local moved = 0
for _, src in ipairs(tanksWFluid(fluidName)) do
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
if moved > 0 then resetStock() end
return moved
end

function tankRes()
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

function drainFluid(machineName, fluidName, limit)
local moved = 0
local machine = peripheral.wrap(machineName)
local reserved = tankRes()

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
for _, t in ipairs(tanksWFluid(fluidName)) do
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
if moved > 0 then resetStock() end
return moved
end
end
if moved > 0 then resetStock() end
return moved
end

function pushStoList()
local out = {}
for sName, en in pairs(Config.storages or {}) do
if en and not SYSTEM_SIDES[sName] then out[#out + 1] = sName end
end
table.sort(out)
return out
end

function sweepMachines()
local stoNames = pushStoList()
for mName in pairs(Craft.usedMachines or {}) do
local m = peripheral.wrap(mName)
if m then
if m.list and m.pushItems then
local ok, items = pcall(m.list)
if ok and items then
for slot, it in pairs(items) do
if it and it.count and it.count > 0 then
local left = it.count
for _, sName in ipairs(packOrder(it.name, stoNames)) do
if left <= 0 then break end
local okP, mv = pcall(m.pushItems, sName, slot, left)
if okP and type(mv) == "number" and mv > 0 then
left = left - mv; packRemember(it.name, sName)
elseif okP and (not mv or mv == 0) then
packForget(it.name, sName)
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
drainFluid(mName, tk.name, tk.amount)
end
end
end
end
end
end
Craft.usedMachines = {}
end

function machFluidSnap(machine)
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

function sameFluidMap(a, b)
for k, v in pairs(a) do if b[k] ~= v then return false end end
for k, v in pairs(b) do if a[k] ~= v then return false end end
return true
end

function machItemSnap(machineName)
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

function waitFluidStable(machine, machineName, timeoutTot, cancellable, onTick)

local function combo()
local res = {}
for k, v in pairs(machFluidSnap(machine)) do res["f:" .. k] = v end
for k, v in pairs(machItemSnap(machineName)) do res["i:" .. k] = v end
return res
end
local prevC = combo()
local stableCount, sawChange, elapsed = 0, false, 0
while true do
if onTick then onTick() end
if cancellable then
sleepCancel(0.5)
if Craft.cancelled then return machFluidSnap(machine), true end
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
if not cancellable and elapsed >= timeoutTot then break end
end
return machFluidSnap(machine), false
end

function drainMachItems(machineName)
local m = peripheral.wrap(machineName)
if not (m and m.list and m.pushItems) then return end
local ok, items = pcall(m.list)
if not (ok and items) then return end
local stoNames = pushStoList()
for slot, item in pairs(items) do
if item and item.count and item.count > 0 then
local left = item.count
for _, sName in ipairs(packOrder(item.name, stoNames)) do
if left <= 0 then break end
local okP, mv = pcall(m.pushItems, sName, slot, left)
if okP and type(mv) == "number" and mv > 0 then
left = left - mv; packRemember(item.name, sName)
elseif okP and (not mv or mv == 0) then
packForget(item.name, sName)
end
end
end
end
end

function barrelToMach(machineName)
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

function pushItemsToMach(machineName, itemName, count)
return pushFromStore(itemName, count, machineName) or 0
end
-->40_machines/40_0_control.lua
--<40_machines/40_1_info.lua
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
-->40_machines/40_1_info.lua
--<40_machines/40_2_registry.lua
Machines = {}

function Machines.label(name)
return MachineLabels[name]
end

function Machines.setLabel(name, lbl)
MachineLabels[name] = lbl
end

function Machines.excluded(name)
return ExcludedMachines[name] == true
end

function Machines.exclude(name, on)
if on then
ExcludedMachines[name] = true
else
ExcludedMachines[name] = nil
end
end
-->40_machines/40_2_registry.lua
--<40_machines/40_3_crafter.lua
CRAFTER_MACHINE = "mechanical_crafter"
CRAFTER_JOB_FILE = "factory_crafter_job.json"
CRAFTER_TIMEOUT = 180
CRAFTER_START_WAIT = 6
RELAY_SIDES = {"top", "bottom", "left", "right", "front", "back"}
CRAFTER_REMAINDERS = {
["minecraft:bucket"] = true, ["minecraft:glass_bottle"] = true, ["minecraft:bowl"] = true,
}

function crafterCfg()
if type(Config.crafter) ~= "table" then Config.crafter = {} end
if type(Config.crafter.cells) ~= "table" then Config.crafter.cells = {} end
return Config.crafter
end

function isCrafterPeriph(name)
if type(name) ~= "string" then return false end
if name:find("mechanical_crafter", 1, true) then return true end
local ok, has = pcall(peripheral.hasType, name, "create:mechanical_crafter")
return ok and has == true
end

function isRelayPeriph(name)
if type(name) ~= "string" then return false end
local ok, has = pcall(peripheral.hasType, name, "redstone_relay")
return ok and has == true
end

function isCrafterRole(name)
if isCrafterPeriph(name) then return true end
local c = Config.crafter
if type(c) ~= "table" then return false end
return name == c.out or name == c.clutch or name == c.pulse
end

local function sufNum(n) return tonumber(n:match("_(%d+)$")) or math.huge end

function detectCrafters()
local out = {}
for _, p in ipairs(peripheral.getNames()) do
if not SYSTEM_SIDES[p] and isCrafterPeriph(p) then out[#out + 1] = p end
end
table.sort(out, function(a, b)
local na, nb = sufNum(a), sufNum(b)
if na ~= nb then return na < nb end
return a < b
end)
return out
end

function crafterCellIdx(name)
for i, n in ipairs(crafterCfg().cells) do
if n == name then return i end
end
return nil
end

function crafterSetLock(on)
local c = crafterCfg()
if not (c.clutch and c.clutch_side) then return false, "clutch relay not set" end
local r = peripheral.wrap(c.clutch)
if not (r and r.setOutput) then return false, "clutch relay offline" end
local ok = pcall(r.setOutput, c.clutch_side, on and true or false)
if not ok then return false, "clutch relay error" end
return true
end

function crafterLocked()
local c = crafterCfg()
if not (c.clutch and c.clutch_side) then return nil end
local r = peripheral.wrap(c.clutch)
if not (r and r.getOutput) then return nil end
local ok, v = pcall(r.getOutput, c.clutch_side)
if not ok then return nil end
return v and true or false
end

function crafterPulse()
local c = crafterCfg()
if not (c.pulse and c.pulse_side) then return false end
local r = peripheral.wrap(c.pulse)
if not (r and r.setOutput) then return false end
pcall(r.setOutput, c.pulse_side, false)
sleep(0.1)
pcall(r.setOutput, c.pulse_side, true)
sleep(0.3)
pcall(r.setOutput, c.pulse_side, false)
return true
end

function crafterReady(need)
local c = crafterCfg()
if #c.cells == 0 then return false, "no crafter grid registered" end
for _, n in ipairs(c.cells) do
if not peripheral.wrap(n) then return false, n end
end
for _, n in ipairs(need or {}) do
if not crafterCellIdx(n) then return false, n end
end
if not (c.clutch and c.clutch_side) then return false, "clutch relay not set" end
if not peripheral.wrap(c.clutch) then return false, c.clutch end
if not c.out then return false, "crafter output not set" end
if not peripheral.wrap(c.out) then return false, c.out end
return true
end

function crafterReadCells()
local cells = crafterCfg().cells
local scanned = scanPeriph(cells, "list", true)
local res = {}
for i, n in ipairs(cells) do
local e = scanned[n]
if not (e and e.data) then return nil, "crafter offline: " .. n end
if e.size and e.size > 1 then
return nil, "crafter inputs are linked (wrench) - unlink them"
end
local it = e.data[1]
res[i] = (it and it.name) or "nil"
end
return res
end

local function crafterSleep(t, committed)
if committed then sleep(t) else sleepCancel(t) end
end

function crafterWaitStart(loaded, secs, committed, onTick)
local t, repulsed = 0, false
while t < secs do
if onTick then onTick() end
crafterSleep(0.5, committed)
t = t + 0.5
if Craft.cancelled and not committed then return false end
local cur = crafterReadCells()
if cur then
for idx, ing in ipairs(loaded) do
if ing ~= "nil" and cur[idx] == "nil" then return true end
end
end
if not repulsed and t >= 2.5 then
repulsed = true
crafterPulse()
end
end
return false
end

function crafterStart(loaded, committed, onTick)
local ok, err = crafterSetLock(false)
if not ok then return false, err end
crafterSleep(0.6, committed)
crafterPulse()
return crafterWaitStart(loaded, CRAFTER_START_WAIT, committed, onTick)
end

function crafterJobSave(job)
local ok, data = pcall(textutils.serializeJSON, job)
if not (ok and type(data) == "string") then return end
local fh = fs.open(CRAFTER_JOB_FILE, "w")
if fh then fh.write(data); fh.close() end
end

function crafterJobLoad()
if not fs.exists(CRAFTER_JOB_FILE) then return nil end
local fh = fs.open(CRAFTER_JOB_FILE, "r")
if not fh then return nil end
local raw = fh.readAll() or ""
fh.close()
local ok, j = pcall(textutils.unserializeJSON, raw)
if ok and type(j) == "table" and type(j.item) == "string"
and type(j.ings) == "table" and type(j.cells) == "table" then return j end
return nil
end

function crafterJobClear()
if fs.exists(CRAFTER_JOB_FILE) then fs.delete(CRAFTER_JOB_FILE) end
end

function crafterGridEmpty(cur)
for _, v in ipairs(cur) do if v ~= "nil" then return false end end
return true
end

function crafterResidueTarget(cur)
local function fits(ings, cells, exact)
local covered = {}
for k, cell in ipairs(cells) do
local gi = crafterCellIdx(cell)
if not gi then return false end
covered[gi] = true
local have, want = cur[gi], ings[k] or "nil"
if have ~= "nil" and have ~= want then
if exact or want == "nil" then return false end
local alt = false
for _, a in ipairs(Groups.altsOf(want) or {}) do
if a == have then alt = true; break end
end
if not alt then return false end
end
end
for gi, have in ipairs(cur) do
if have ~= "nil" and not covered[gi] then return false end
end
return true
end
local job = crafterJobLoad()
if job and fits(job.ings, job.cells, true) then
return {item = job.item, ings = job.ings, cells = job.cells, perOp = job.perOp or 1, fromJob = true}
end
local found, items = {}, {}
local function consider(name, r)
if type(r) == "table" and r.type == "crafter" and type(r.grid_cells) == "table"
and fits(r.ingredients or {}, r.grid_cells, false) then
found[#found + 1] = {item = name, ings = r.ingredients, cells = r.grid_cells, perOp = r.output_count or 1}
items[name] = true
end
end
for name, r in pairs(Recipe.all()) do consider(name, r) end
for name, alts in pairs(Recipe.allAlts()) do
for _, r in ipairs(alts) do consider(name, r) end
end
local nItems = 0
for _ in pairs(items) do nItems = nItems + 1 end
if nItems == 1 then return found[1] end
if nItems == 0 then return nil, "no known crafter recipe matches the grid" end
return nil, nItems .. " recipes match the grid - empty it by hand"
end

function crafterOutList()
local c = crafterCfg()
local o = c.out and peripheral.wrap(c.out)
if not (o and o.list) then return {} end
local ok, items = pcall(o.list)
return (ok and items) or {}
end

function crafterDrainOut(dstNames)
local c = crafterCfg()
local got = {}
local o = c.out and peripheral.wrap(c.out)
if not (o and o.pushItems) then return got end
local dsts = {}
for _, s in ipairs(dstNames) do if s ~= c.out then dsts[#dsts + 1] = s end end
for slot, it in pairs(crafterOutList()) do
if it and (it.count or 0) > 0 then
local left = it.count
for _, s in ipairs(packOrder(it.name, dsts)) do
if left <= 0 then break end
local okP, mv = pcall(o.pushItems, s, slot, left)
if okP and type(mv) == "number" and mv > 0 then
left = left - mv
packRemember(it.name, s)
got[it.name] = (got[it.name] or 0) + mv
end
end
end
end
if next(got) then resetStock() end
return got
end

function crafterPickResult(agg)
local best, bestN = nil, -1
for nm, cnt in pairs(agg) do
if not CRAFTER_REMAINDERS[nm] and cnt > bestN then best, bestN = nm, cnt end
end
if not best then
for nm, cnt in pairs(agg) do
if cnt > bestN then best, bestN = nm, cnt end
end
end
return best, bestN
end
-->40_machines/40_3_crafter.lua
--<50_render/50_0_primitives.lua
_COLOR_BLIT = {
[colors.white]     = "0", [colors.orange]    = "1",
[colors.magenta]   = "2", [colors.lightBlue] = "3",
[colors.yellow]    = "4", [colors.lime]       = "5",
[colors.pink]      = "6", [colors.gray]       = "7",
[colors.lightGray] = "8", [colors.cyan]       = "9",
[colors.purple]    = "a", [colors.blue]       = "b",
[colors.brown]     = "c", [colors.green]      = "d",
[colors.red]       = "e", [colors.black]      = "f",
}
_fb     = {}
_fbLast = {}
_fbW, _fbH = 0, 0

function _bufInit(w, h)
_fbW, _fbH = w, h
_fb = {}
for y = 1, h do
local t, f, b = {}, {}, {}
for x = 1, w do t[x] = " "; f[x] = "0"; b[x] = "f" end
_fb[y] = {t = t, f = f, b = b}
end
end

function _bufWrite(x, y, text, fg, bg)
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

function _bufClearLine(y, bg)
_bufWrite(1, y, string.rep(" ", _fbW), colors.white, bg)
end

function _bufFillRect(x, y, rw, rh, bg)
local row = string.rep(" ", rw)
for dy = 0, rh - 1 do _bufWrite(x, y + dy, row, colors.white, bg) end
end

function _bufFlush()
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

function drawText(x, y, text, fg, bg)
_bufWrite(x, y, text, fg or colors.white, bg or colors.black)
end

function drawProgBar(x, y, width, current, max, bgColor)
bgColor = bgColor or colors.black
local percent = math.min(1, math.max(0, current / max))
local filledChars = math.floor(percent * (width - 2))
local emptyChars = (width - 2) - filledChars
local barStr = "[" .. string.rep("|", filledChars) .. string.rep(".", emptyChars) .. "]"
drawText(x, y, barStr, colors.lime, bgColor)
drawText(x + width + 1, y, string.format("%d%%", math.floor(percent * 100)), colors.white, bgColor)
end
-->50_render/50_0_primitives.lua
--<60_craft/60_0_fluid.lua
function planFluid(recipe, targetName, amount)
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
local inv = getFluid()
local errLines = {}
for _, inp in ipairs(recipe.inputs or {}) do
local need = ops * inp.amount
local have = inv[fluidKey(inp.name)] or 0
if have < need then
local sn = shortName(inp.name)
table.insert(errLines, string.format("Need %d mB %s, have %d", need, sn, have))
end
end
if recipe.item_inputs and #recipe.item_inputs > 0 then
local stk = getInv()
for _, it in ipairs(recipe.item_inputs) do
local need = ops * it.count
local have = stk[it.name] or 0
if have < need then
local sn = shortName(it.name)
table.insert(errLines, string.format("Need %dx %s, have %d", need, sn, have))
end
end
end
if #errLines > 0 then return false, nil, errLines end
return true, {recipe = recipe, ops = ops, perOp = perOp, target = targetName, isItem = isItemTarget}, nil
end

function checkOutStore(recipe)
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

function fluidCraftInner(plan)
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
for _, pmName in ipairs(getMachPool(baseMachine)) do
local pp = peripheral.wrap(pmName)
if pp and pp.tanks and pp.pushFluid and pp.pullFluid then
pool[#pool + 1] = pmName
end
end
end
if #pool == 0 then
return false, {"Machine missing fluid methods: " .. tostring(baseMachine)}, 0
end
for _, pmName in ipairs(pool) do Craft.usedMachines[pmName] = true end
if splitOut   then Craft.usedMachines[splitOut]   = true end
if itemInDev  then Craft.usedMachines[itemInDev]  = true end
if fluidInDev then Craft.usedMachines[fluidInDev] = true end
if itemOutDev then Craft.usedMachines[itemOutDev] = true end
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
local dbgEnt = fluidInlineByCo[lockOwnerId()]
local dbgBaseline
if dbgEnt then
if targetIsItem then dbgBaseline = (getInvCached()[targetName] or 0)
else                 dbgBaseline = (getFluidCached()[fluidKey(targetName)] or 0) end
end

local function pushBatch(mName, wantOps)
local accepted = wantOps
for _, it in ipairs(recipe.item_inputs or {}) do
local maxS = itemMaxStack[it.name] or 64
if maxS >= it.count then
local maxOpsItem = math.floor(maxS / it.count)
if maxOpsItem < accepted then accepted = maxOpsItem end
elseif accepted > 1 then
accepted = 1
end
end
for _, inp in ipairs(recipe.inputs or {}) do
local avail = 0
for _, src in ipairs(tanksWFluid(inp.name)) do avail = avail + (src.amount or 0) end
local opsForInp = math.floor(avail / inp.amount)
if opsForInp < accepted then accepted = opsForInp end
end
if accepted < 1 then return 0 end
local fDev = fluidInDev or mName
local fPer = peripheral.wrap(fDev)
if fPer and #(recipe.inputs or {}) > 0 then
local seqPour = (splitOut ~= nil or itemInDev ~= nil or fluidInDev ~= nil or itemOutDev ~= nil)
and #(recipe.inputs or {}) > 1
local preF = machFluidSnap(fPer)
for fi, inp in ipairs(recipe.inputs or {}) do
if seqPour and fi > 1 then
local prevName = recipe.inputs[fi - 1].name
local waitC = 0
while waitC < 40 do
local snapW = machFluidSnap(fPer)
if (snapW[prevName] or 0) <= 0 then break end
sleepCancel(0.5)
if Craft.cancelled then return 0 end
waitC = waitC + 1
end
preF = machFluidSnap(fPer)
end
local have   = preF[inp.name] or 0
local curOps = math.floor(have / inp.amount)
local needed = (curOps + accepted) * inp.amount - have
local moved  = 0
if needed > 0 then moved = pushFluidToMach(fDev, inp.name, needed) end
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
if needed > 0 then moved = pushItemsToMach(iDev, it.name, needed) or 0 end
local newOps = math.floor((have + moved) / it.count) - curOps
if newOps < accepted then accepted = math.max(0, newOps) end
end
return accepted
end

local function drainMach(e)
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
local snap = machFluidSnap(machine)
for fname, amt in pairs(snap) do
if amt > 1 and (isDedicatedOut or not inFluidSet[fname]) then
local moved = drainFluid(dn, fname, 1000000)
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
local isDedicatedItem = (itemOutDev ~= nil and dn == itemOutDev and dn ~= itemInDev)
local m = peripheral.wrap(dn)
if m and m.list and m.pushItems then
local ok, items = pcall(m.list)
if ok and items then
for slot, item in pairs(items) do
if item and item.count and item.count > 0 and (isDedicatedItem or not inItemSet[item.name]) then
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
local snap = machFluidSnap(machine)
local itemSnap = machItemSnap(mName)
if next(snap) == nil and next(itemSnap) == nil then break end
for fname in pairs(snap) do drainFluid(mName, fname, 1000000) end
drainMachItems(mName)
end
end

local function availableOps()
if #(recipe.inputs or {}) == 0 then return nil end
local minOps = nil
for _, inp in ipairs(recipe.inputs) do
local avail = 0
for _, src in ipairs(tanksWFluid(inp.name)) do avail = avail + (src.amount or 0) end
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

local function finalDrainE(e)
local seen = {}
for _, d in ipairs({e.name, e.drain, itemInDev, fluidInDev, itemOutDev}) do
if d and not seen[d] then seen[d] = true; finalDrain(d) end
end
end
for _, e in ipairs(machineData) do finalDrainE(e) end
local totalExp = totalOps * plan.perOp
local maxWait = math.max(400, totalOps * 30)
local waited  = 0

local function allFinished()
for _, e in ipairs(machineData) do
if not e.finished then return false end
end
return true
end
local function redistOps(dead)
if (dead.remainOps or 0) <= 0 then return end
local alive = {}
for _, m in ipairs(machineData) do
if m ~= dead and not m.finished then alive[#alive + 1] = m end
end
if #alive == 0 then return end
local per   = math.floor(dead.remainOps / #alive)
local extra = dead.remainOps - per * #alive
for i, m in ipairs(alive) do
m.remainOps = m.remainOps + per + ((i <= extra) and 1 or 0)
end
dead.remainOps = 0
end
while (not allFinished()) and produced < totalExp and waited < maxWait do
sleepCancel(0.5)
if Craft.cancelled then
for _, e in ipairs(machineData) do finalDrainE(e) end
resetStock()
failReason("fluid.cancel_loop label=" .. tostring(label))
return false, {"Cancelled by user."}, produced
end
waited = waited + 1
local refillNeed = {}
for _, e in ipairs(machineData) do
if not e.finished then
local moved, hadOut = drainMach(e)
if moved > 0 then
produced = produced + moved
e.batchDone = e.batchDone + moved
if dbgEnt then
local sto = (dbgBaseline or 0) + produced
if targetIsItem then
dbgPush(Craft.jobId, dbgEnt.ctx.subId, dbgEnt.node, targetName,
moved, produced, totalExp, sto, 0, e.name)
else
dbgFluidPush(Craft.jobId, dbgEnt.ctx.subId, dbgEnt.node, targetName,
moved, produced, totalExp, sto, 0, e.name)
end
end
end
if hadOut then
e.startedOut = true
if e.idle > (e.maxGap or 0) then e.maxGap = e.idle end
e.idle = 0
else
e.idle = e.idle + 1
end
local quietNeed = math.max(30, (e.maxGap or 0) * 2 + 4)
if e.batchDone >= e.batchTarget and not hadOut then
if e.remainOps > 0 then
refillNeed[#refillNeed + 1] = e
else
e.finished = true
end
elseif e.startedOut and e.idle >= quietNeed then
e.finished = true
redistOps(e)
end
end
end
if #refillNeed > 0 then
local avail = availableOps()
local share
if avail == nil then
share = nil
else
share = math.max(1, math.floor(avail / #refillNeed))
end
for _, e in ipairs(refillNeed) do
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
redistOps(e)
else
sleepCancel(1)
end
end
end
end
if drawFluidProg then
local doneOpsNow = math.min(totalOps, math.floor(produced / math.max(1, plan.perOp)))
local activeW = 0
for _, e in ipairs(machineData) do if not e.finished then activeW = activeW + 1 end end
drawFluidProg(label, doneOpsNow, totalOps, activeW)
end
end
for _, e in ipairs(machineData) do finalDrainE(e) end
resetStock()
if produced <= 0 and totalOps > 0 then
failReason(string.format("fluid.no_produce label=%s mach=%s ops=%d",
tostring(label), tostring(baseMachine), totalOps))
return false, {"Could not push inputs to " .. tostring(baseMachine)}, produced
end
if Craft.depth == 0 and (stageDone or 0) < (stageTotal or 0) then
stageDone = (stageDone or 0) + 1
end
return true, nil, produced
end
-->60_craft/60_0_fluid.lua
--<60_craft/60_1_planner.lua
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
-->60_craft/60_1_planner.lua
--<60_craft/60_2_tokens.lua
function lockOwnerId()
return coroutine.running() or "main"
end

function acquireTokens(tokens)
local me = lockOwnerId()
for _, t in ipairs(tokens) do
local l = Craft.locks[t]
if l and l.owner ~= me then return false end
end
for _, t in ipairs(tokens) do
local l = Craft.locks[t]
if l then l.count = l.count + 1
else Craft.locks[t] = { owner = me, count = 1 } end
end
return true
end

function releaseTokens(tokens)
local me = lockOwnerId()
for _, t in ipairs(tokens) do
local l = Craft.locks[t]
if l and l.owner == me then
l.count = l.count - 1
if l.count <= 0 then Craft.locks[t] = nil end
end
end
end
sleepCancel = function(t)
local timer = os.startTimer(t)
local deadline = os.clock() + t + 0.1
while true do
local ev, a, b, c = os.pullEvent()
if ev == "timer" and a == timer then return end
if ev == "monitor_touch" and craftCancelY and c == craftCancelY and b >= craftCancelX1 and b <= craftCancelX2 then
Craft.cancelled = true
os.cancelTimer(timer)
return
end
if os.clock() >= deadline then os.cancelTimer(timer); return end
end
end

function groupKeyOf(machineName)
for _, cg in ipairs(CustomMachineGroups) do
for _, cm in ipairs(cg.machines) do
if cm == machineName then return "cg:" .. (cg.name or tostring(cg)) end
end
end
if Machines.excluded(machineName) then return "m:" .. machineName end
return "g:" .. getMachBase(machineName)
end

function pinnedToken(name)
if not name or name == "" then return nil end
for _, cg in ipairs(CustomMachineGroups) do
for _, cm in ipairs(cg.machines) do
if cm == name then return "cg:" .. (cg.name or tostring(cg)) end
end
end
if Machines.excluded(name) then return "m:" .. name end
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
if step.type == "crafter" then return { "CRAFTER" } end
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
if Craft.cancelled or (ctx and ctx.failed) then sleep(0); return end
local timer = os.startTimer(t)
local deadline = os.clock() + t + 0.1
while true do
if Craft.cancelled or (ctx and ctx.failed) then os.cancelTimer(timer); return end
local ev, a = os.pullEvent()
if ev == "timer" and a == timer then return end
if os.clock() >= deadline then os.cancelTimer(timer); return end
if Craft.cancelled or (ctx and ctx.failed) then os.cancelTimer(timer); return end
end
end
-->60_craft/60_2_tokens.lua
--<60_craft/60_3_engine_turtle.lua

function _turtleCraftLoop(ctx, node, turtleCtx)
local turtlePool     = turtleCtx.turtlePool
local turtleSlots    = turtleCtx.turtleSlots
local sortedStore = turtleCtx.sortedStore
local provSrc        = turtleCtx.provSrc
local myCleanup      = turtleCtx.myCleanup
local assignments    = turtleCtx.assignments
local step           = turtleCtx.step
local totalDone      = turtleCtx.totalDone
local totalNeed    = turtleCtx.totalNeed
local turtleStall    = turtleCtx.turtleStall
local helpers        = turtleCtx.helpers
local plan, i        = turtleCtx.plan, turtleCtx.i
local desc           = turtleCtx.desc

local dryStreak, feasRetries = 0, 0
local absTarget = (turtleCtx.baselineStore or 0) + totalNeed * (step.output_count or 1)

while totalDone < totalNeed do
if Craft.cancelled then
cleanupCraftMachines(sortedStore, myCleanup)
failReason("turtle.cancel")
return false
end
helpers.drawProgress(i, #plan, desc, totalDone, totalNeed, step.item, #turtlePool)

local active = {}
for _, asgn in ipairs(assignments) do
if asgn.remaining > 0 then table.insert(active, asgn) end
end
if #active == 0 then break end

for _, asgn in ipairs(active) do helpers.clearGrid(asgn.name) end

local ingNeed = {}
for idx = 1, 9 do
local ing = step.ingredients[idx]
if ing and ing ~= "nil" then ingNeed[ing] = (ingNeed[ing] or 0) + 1 end
end

local tStock = {}
local srcByName = {}
for ing in pairs(ingNeed) do
tStock[ing] = 0
srcByName[ing] = srcByName[ing] or {}
local alts = Groups.altsOf(ing)
if alts then
for _, alt in ipairs(alts) do
tStock[alt] = tStock[alt] or 0
srcByName[alt] = srcByName[alt] or {}
end
end
end

local tScanList = {}
for _, s in ipairs(sortedStore) do tScanList[#tScanList + 1] = s end
for _, s in ipairs(provSrc)        do tScanList[#tScanList + 1] = s end
local tScan = scanPeriph(tScanList, "list")
for _, stoName in ipairs(tScanList) do
local e = tScan[stoName]
local sto = e and e.data and peripheral.wrap(stoName)
if sto and sto.pushItems then
for slot, it in pairs(e.data) do
if it and tStock[it.name] ~= nil and (it.count or 0) > 0 then
tStock[it.name] = tStock[it.name] + it.count
local arr = srcByName[it.name]
arr[#arr + 1] = {sto = sto, slot = slot, count = it.count}
end
end
end
end

maxStackCache = maxStackCache or {}
local ingMaxStack = {}
for name, arr in pairs(srcByName) do
local m = maxStackCache[name]
if not m and arr[1] then
local okD, det = pcall(arr[1].sto.getItemDetail, arr[1].slot)
if okD and det and det.maxCount and det.maxCount > 0 then
m = det.maxCount
end
end
if m then
maxStackCache[name] = m
ingMaxStack[name] = m
end
end

local feasibleOps = nil
for ing, need in pairs(ingNeed) do
if not helpers.isTool(ing) then
local f = math.floor(groupAvail(ing, tStock) / need)
if feasibleOps == nil or f < feasibleOps then feasibleOps = f end
end
end
feasibleOps = feasibleOps or 0

local chosenType   = {}
local constCap = nil
for ing, need in pairs(ingNeed) do
if not helpers.isTool(ing) then
local best, bestCnt = ing, tStock[ing] or 0
local alts = Groups.altsOf(ing)
if alts then
for _, alt in ipairs(alts) do
local c = tStock[alt] or 0
if c > bestCnt then best, bestCnt = alt, c end
end
end
chosenType[ing] = best
local cap = math.floor(bestCnt / need)
if constCap == nil or cap < constCap then constCap = cap end
end
end
constCap = constCap or 0

if feasibleOps <= 0 then
local remaining = totalNeed - totalDone
for ing, perOp in pairs(ingNeed) do
if not helpers.isTool(ing) then
local short = perOp * remaining - groupAvail(ing, tStock)
if short > 0 then bridgeStage(ing, short) end
end
end
resetStock()
if groupAvail(step.item, getInvCached()) >= absTarget then
break
end
if feasRetries < 5 then
feasRetries = feasRetries + 1
dbgWrite(string.format("j=%d s=%d turtle.retry idx=%d item=%s reason=feasible try=%d done=%d/%d",
Craft.jobId or 0, ctx.subId or 0, node.idx or 0,
shortName(step.item), feasRetries, totalDone, totalNeed))
sleepCancel(1.0)
goto continue_iter
end
local itemShort = shortName(step.item)
craftErrTitle = "! NEED"
local parts = {}
for ing, perOp in pairs(ingNeed) do
local short = perOp * remaining - groupAvail(ing, tStock)
if short > 0 then parts[#parts + 1] = string.format("%dx %s", short, shortName(ing)) end
end
local lines = {"Can't make " .. itemShort}
appendMissing(lines, parts)
craftErrLines = lines
cleanupCraftMachines(sortedStore, myCleanup)
failReason("turtle.no_feasible_ops item=" .. tostring(shortName(step.item)))
return false
end
feasRetries = 0

do
local toolMissing = nil
for ing in pairs(ingNeed) do
if helpers.isTool(ing) and (tStock[ing] or 0) < 1 then toolMissing = ing; break end
end
if toolMissing then
bridgeStage(toolMissing, 1)
releaseTokens(node.tokens)
local okTool, toolErr = ensureItem(toolMissing, 1)
while not Craft.cancelled and not ctx.failed do
if acquireTokens(node.tokens) then break end
sleepYield(0.2, ctx)
end
if Craft.cancelled or ctx.failed then
cleanupCraftMachines(sortedStore, myCleanup)
failReason(Craft.cancelled and "turtle.cancel_tool" or "turtle.ctx_failed_tool")
return false
end
if not okTool then
craftErrTitle = "! NEED TOOL"
craftErrLines = toolErr or {"Can't make tool: " .. (shortName(toolMissing))}
cleanupCraftMachines(sortedStore, myCleanup)
failReason("turtle.tool_missing tool=" .. tostring(shortName(toolMissing)))
return false
end
else

helpers.pushDirect = function(ing, amount, turtleName, targetSlot)
local feeds = { ing }
local alts = Groups.altsOf(ing)
if alts then
for _, alt in ipairs(alts) do
if alt ~= ing then feeds[#feeds + 1] = alt end
end
end
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

helpers.pushExact = function(name, amount, turtleName, targetSlot)
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

local turtlePerOp = step.output_count or 1
local outMax = helpers.lookupMax()
local slotCap
if outMax then
slotCap = math.floor(outMax / math.max(1, turtlePerOp))
else
slotCap = math.floor(7 / math.max(1, turtlePerOp))
end
if slotCap < 1 then slotCap = 1 end

local useConsistent = constCap >= 1
local feasLeft = feasibleOps
local round = {}
for _, asgn in ipairs(active) do
if feasLeft <= 0 then break end
local batchSize = math.min(slotCap, asgn.remaining, feasLeft)
if useConsistent and batchSize > constCap then batchSize = constCap end
for ing in pairs(ingNeed) do
if not helpers.isTool(ing) then
local nm = useConsistent and (chosenType[ing] or ing) or ing
local m = ingMaxStack[nm]
if m and batchSize > m then batchSize = m end
end
end
if batchSize > 0 and helpers.clearGrid(asgn.name) then
asgn.curBatch = batchSize
feasLeft = feasLeft - batchSize
for idx = 1, 9 do
local ing = step.ingredients[idx]
if ing and ing ~= "nil" then
if helpers.isTool(ing) then
helpers.pushExact(ing, 1, asgn.name, turtleSlots[idx])
elseif useConsistent then
helpers.pushExact(chosenType[ing] or ing, batchSize, asgn.name, turtleSlots[idx])
else
helpers.pushDirect(ing, batchSize, asgn.name, turtleSlots[idx])
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
local itemShort = shortName(step.item)
craftErrTitle = "! TURTLE GRID BLOCKED"
craftErrLines = {
"Can't clear turtle grid for " .. itemShort,
"Residue stuck (item storage full?).",
"Free up storage space and retry.",
}
cleanupCraftMachines(sortedStore, myCleanup)
failReason("turtle.grid_blocked item=" .. tostring(shortName(step.item)))
return false
end
sleepCancel(0.3)
else
turtleStall = 0
end

local craftResults  = {}
local craftTasks    = {}
local numDone = 0
local batchTotal    = #active
for ci, asgn in ipairs(active) do
local tName = asgn.name
local ri    = ci
local want  = (asgn.curBatch or 1) * (step.output_count or 1)
craftTasks[#craftTasks + 1] = function()
local got, si, idle = 0, 0, 0
while idle < 240 do
sleepCancel(0.05)
if Craft.cancelled then break end
si = si % #sortedStore + 1
local sto = peripheral.wrap(sortedStore[si])
local mv = 0
if sto and sto.pullItems then
local okp, res = pcall(sto.pullItems, tName, 16, 64)
if okp and res then mv = res end
end
if mv > 0 then
got = got + mv
idle = 0
if got >= want then break end
else
idle = idle + 1
end
end
if got > 0 then helpers.clearGrid(tName) end
craftResults[ri] = got
numDone = numDone + 1
end
end
craftTasks[#craftTasks + 1] = function()
while numDone < batchTotal and not Craft.cancelled do
local t = os.startTimer(0.05)
while true do
local ev, a, b, c = os.pullEvent()
if ev == "timer" and a == t then break end
if ev == "monitor_touch" and craftCancelY
and c == craftCancelY and b >= craftCancelX1 and b <= craftCancelX2 then
Craft.cancelled = true
os.cancelTimer(t)
break
end
end
end
end
parallel.waitForAll(table.unpack(craftTasks))

local anyOk, lastFailName = false, nil
for ci, asgn in ipairs(active) do
local batch = math.floor((craftResults[ci] or 0) / (step.output_count or 1))
if batch > asgn.remaining then batch = asgn.remaining end
if batch > 0 then
anyOk = true
asgn.remaining = asgn.remaining - batch
totalDone = totalDone + batch
local produced = batch * (step.output_count or 1)
local sto = (turtleCtx.baselineStore or 0) + totalDone * (step.output_count or 1)
dbgPush(Craft.jobId, ctx.subId, node.idx, step.item,
produced, totalDone * (step.output_count or 1),
totalNeed * (step.output_count or 1), sto, 0, asgn.name)
else
lastFailName = asgn.name
end
end

if anyOk then
dryStreak = 0
elseif lastFailName then
resetStock()
if groupAvail(step.item, getInvCached()) >= absTarget then break end
dryStreak = dryStreak + 1
dbgWrite(string.format("j=%d s=%d turtle.retry idx=%d item=%s reason=dry try=%d turtle=%s done=%d/%d",
Craft.jobId or 0, ctx.subId or 0, node.idx or 0,
shortName(step.item), dryStreak, tostring(lastFailName), totalDone, totalNeed))
if dryStreak >= 3 then
cleanupCraftMachines(sortedStore, myCleanup)
failReason(string.format("turtle.batch_no_output item=%s turtle=%s done=%d/%d",
tostring(shortName(step.item)), tostring(lastFailName), totalDone, totalNeed))
return false
end
sleepCancel(1.0)
end

helpers.drawProgress(i, #plan, desc, totalDone, totalNeed, step.item, #turtlePool)
end
end
::continue_iter::
end
turtleCtx.totalDone   = totalDone
turtleCtx.turtleStall = turtleStall
return true
end

function _buildTurtlePool(step)
local pool = {}
for tName, enabled in pairs(Config.turtles or {}) do
if enabled then
local tp = peripheral.wrap(tName)
if tp then table.insert(pool, tName) end
end
end
table.sort(pool)
if #pool == 0 then
if step.machine_name and step.machine_name ~= "" then
pool = {step.machine_name}
else
local itemShort = shortName(step.item)
craftErrTitle = "! NO TURTLE ASSIGNED"
craftErrLines = {
"No turtle available",
"Required for: " .. itemShort,
"Assign a turtle in NETWORK tab.",
}
return nil
end
end
if step.tools and next(step.tools) and #pool > 1 then
pool = { pool[1] }
end
return pool
end

function _execStepTurtle(step, ctx, node, state)
local sortedStore = state.sortedStore
local provSrc        = state.provSrc
local myCleanup      = state.myCleanup
local helpers        = state.helpers
local plan, i        = state.plan, state.i
local w, h           = state.w, state.h
local finalGoal  = state.finalGoal
local nodeTopup      = state.nodeTopup
local desc           = state.desc

local turtleSlots = {1, 2, 3, 5, 6, 7, 9, 10, 11}
local turtlePool = _buildTurtlePool(step)
if not turtlePool then failReason("turtle.pool_missing item=" .. tostring(shortName(step.item))); return false end

myCleanup = {}
for _, tName in ipairs(turtlePool) do
table.insert(myCleanup, {name = tName, pullNames = nil})
Craft.usedMachines[tName] = true
end

if step.count and step.count > 0 and not Craft.cancelled then
local ingNeed = {}
for idx = 1, 9 do
local ing = step.ingredients[idx]
if ing and ing ~= "nil" then ingNeed[ing] = (ingNeed[ing] or 0) + 1 end
end
releaseTokens(node.tokens)
local ingsOk, ingsErr, missIng = ensureIngs(step, ingNeed)
if not ingsOk then
craftErrTitle = "! NEED"
craftErrLines = ingsErr or {"Can't make " .. shortName(step.item)}
failReason("turtle.ing_topup_failed item=" .. tostring(shortName(missIng)))
return false
end
while not Craft.cancelled and not ctx.failed do
if acquireTokens(node.tokens) then break end
sleepYield(0.2, ctx)
end
if Craft.cancelled or ctx.failed then
failReason(Craft.cancelled and "turtle.cancel_before_run" or "turtle.ctx_failed_before_run")
return false
end
end

helpers.dirtySlots = function(tName)
local tp = peripheral.wrap(tName)
if not (tp and tp.list) then return nil end
local ok, its = pcall(tp.list)
if not (ok and its) then return nil end
local slots = {}
for slot, it in pairs(its) do
if it and (it.count or 0) > 0 then slots[#slots + 1] = slot end
end
return slots
end

helpers.clearGrid = function(tName)
for _attempt = 1, 3 do
local slots = helpers.dirtySlots(tName)
if slots == nil then return blindUnload(tName, sortedStore) end
if #slots == 0 then return true end
for _, slot in ipairs(slots) do
for _, stoName in ipairs(sortedStore) do
local sto = peripheral.wrap(stoName)
if sto and sto.pullItems then
local okp, mv = pcall(sto.pullItems, tName, slot, 64)
if okp and mv and mv > 0 then break end
end
end
end
end
local left = helpers.dirtySlots(tName)
return left ~= nil and #left == 0
end

for _, tName in ipairs(turtlePool) do helpers.clearGrid(tName) end

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
local totalNeed = step.count
local turtleStall = 0
local outMaxStack = nil

helpers.lookupMax = function()
if outMaxStack then return outMaxStack end
for _, stoName in ipairs(sortedStore) do
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
helpers.isTool = function(n) return toolSet[n] and true or false end

local turtleCtx = {
turtlePool = turtlePool, turtleSlots = turtleSlots,
sortedStore = sortedStore, provSrc = provSrc,
myCleanup = myCleanup,
assignments = assignments, step = step,
totalDone = totalDone, totalNeed = totalNeed,
turtleStall = turtleStall, helpers = helpers,
plan = plan, i = i, desc = desc,
baselineStore = (getInvCached()[step.item] or 0),
}
if not _turtleCraftLoop(ctx, node, turtleCtx) then return false end
totalDone   = turtleCtx.totalDone
turtleStall = turtleCtx.turtleStall

for _, tName in ipairs(turtlePool) do helpers.clearGrid(tName) end
state.myCleanup = myCleanup
return true
end
-->60_craft/60_3_engine_turtle.lua
--<60_craft/60_4_engine_machine.lua

function _tickMachineEntry(entry, tickCtx)
if Craft.cancelled then return end
local sortedStore = tickCtx.sortedStore
local ingCounts      = tickCtx.ingCounts
local step           = tickCtx.step
local helpers        = tickCtx.helpers
local outPerOp    = tickCtx.outPerOp
local totalExp  = tickCtx.totalExp
local waited         = tickCtx.waited
local totalColl = tickCtx.totalColl
local nodeTopup      = tickCtx.nodeTopup

local hasLeftover = false
local ok, mItems
if tickCtx.scan and tickCtx.scan[entry.outName] then
mItems = tickCtx.scan[entry.outName]; ok = true
else
ok, mItems = pcall(entry.outPeriph.list)
end
if ok and mItems then
for slot, mItem in pairs(mItems) do
if mItem and not entry.excluded[mItem.name] then
local toTake = mItem.count
local moved = 0
for _, stoName in ipairs(packOrder(mItem.name, sortedStore)) do
if moved >= toTake then break end
local okP, mv = pcall(entry.outPeriph.pushItems, stoName, slot, toTake - moved)
if okP and mv and mv > 0 then
moved = moved + mv; packRemember(mItem.name, stoName)
elseif okP and (not mv or mv == 0) then
packForget(mItem.name, stoName)
end
end
if moved < toTake then
for _, stoName in ipairs(sortedStore) do
if moved >= toTake then break end
local sto = peripheral.wrap(stoName)
if sto and sto.pullItems then
local okQ, mv = pcall(sto.pullItems, entry.outName, slot, toTake - moved)
if okQ and mv and mv > 0 then moved = moved + mv end
end
end
end
if moved > 0 then
local gap = waited - entry.lastCollTick
if gap > (entry.maxGap or 0) then entry.maxGap = gap end
entry.lastCollTick  = waited
entry.hasAny = true
entry.collectCount     = (entry.collectCount or 0) + 1
if mItem.name == step.item then
entry.doneItems = entry.doneItems + moved
totalColl  = totalColl + moved
local sto = (tickCtx.baselineStore or 0) + totalColl
dbgPush(tickCtx.jobId, tickCtx.subId, tickCtx.nodeIdx, step.item,
moved, totalColl, totalExp, sto, 0, entry.name)
end
end
if moved < toTake then
hasLeftover = true
if mItem.name == step.item and not entry._leftoverLogged then
dbgLeftover(tickCtx.jobId, tickCtx.subId, tickCtx.nodeIdx,
entry.name, mItem.name, toTake - moved)
entry._leftoverLogged = true
end
elseif entry._leftoverLogged then
entry._leftoverLogged = false
end
end
end
end

local hasInput = false
local okIn, inItems
if tickCtx.scan and tickCtx.scan[entry.name] then
inItems = tickCtx.scan[entry.name]; okIn = true
else
okIn, inItems = pcall(entry.periph.list)
end
if okIn and inItems then
for _, it in pairs(inItems) do
if it and ingCounts[it.name] then
local preC = (entry.preSnap and entry.preSnap[it.name]) or 0
if it.count > preC then hasInput = true; break end
end
end
end

local runnableOps
if okIn and inItems then
local ingTotNow = {}
for _, it in pairs(inItems) do
if it and ingCounts[it.name] then
ingTotNow[it.name] = (ingTotNow[it.name] or 0) + it.count
end
end
for ingName, ingPerOp in pairs(ingCounts) do
local o = math.floor((ingTotNow[ingName] or 0) / ingPerOp)
if runnableOps == nil or o < runnableOps then runnableOps = o end
end
end
runnableOps = runnableOps or 0

local owes = entry.doneItems < entry.pendingItems
local idleTicks = waited - entry.lastCollTick
local quietNeed = math.max(4, (entry.maxGap or 0) * 2 + 4)
if owes then
if (entry.collectCount or 0) >= 2 then
quietNeed = math.max(20, quietNeed)
else
quietNeed = math.max(120, quietNeed)
end
end

if entry.remainOps == 0 and not entry.hasAny
and hasInput and idleTicks >= 200 and not entry.exhausted then
if not entry._exhaustLogged then
dbgExhaust(tickCtx.jobId, tickCtx.subId, tickCtx.nodeIdx, entry.name, 0)
entry._exhaustLogged = true
end
entry.exhausted = true
end

if hasInput and runnableOps == 0 and not hasLeftover
and idleTicks >= math.max(6, quietNeed) then
local acc = helpers.pushBatch(entry.name, math.max(1, entry.remainOps))
if acc > 0 then
entry.remainOps    = math.max(0, entry.remainOps - acc)
entry.pendingItems = entry.pendingItems + acc * outPerOp
entry.lastCollTick = waited
entry.starve = 0
else
entry.starve = (entry.starve or 0) + 1
if entry.starve >= 6 then
if not entry._exhaustLogged then
dbgExhaust(tickCtx.jobId, tickCtx.subId, tickCtx.nodeIdx, entry.name, entry.remainOps or 0)
entry._exhaustLogged = true
end
entry.exhausted = true
end
end
elseif entry.remainOps > 0 then
if not hasInput and not hasLeftover then
local acceptedOps = helpers.pushBatch(entry.name, entry.remainOps)
if acceptedOps > 0 then
entry.remainOps    = entry.remainOps - acceptedOps
entry.pendingItems = entry.pendingItems + acceptedOps * outPerOp
entry.lastCollTick = waited
entry.starve = 0
entry.exhausted = false
elseif not owes or idleTicks >= quietNeed then
entry.starve = (entry.starve or 0) + 1
if entry.starve >= 6 then
if not entry._exhaustLogged then
dbgExhaust(tickCtx.jobId, tickCtx.subId, tickCtx.nodeIdx, entry.name, entry.remainOps or 0)
entry._exhaustLogged = true
end
entry.exhausted = true
end
end
end
elseif not entry.exhausted and entry.hasAny and not hasInput
and not hasLeftover and idleTicks >= quietNeed then
local deficit = totalExp - totalColl
if deficit > 0 then
local opsNeeded = math.ceil(deficit / outPerOp)
local accepted  = helpers.pushBatch(entry.name, opsNeeded)
if accepted > 0 then
nodeTopup             = true
entry.pendingItems    = entry.pendingItems + accepted * outPerOp
entry.lastCollTick = waited
entry.refillCount     = entry.refillCount + 1
entry.starve          = 0
else
entry.starve = (entry.starve or 0) + 1
if entry.starve >= 6 then
if not entry._exhaustLogged then
dbgExhaust(tickCtx.jobId, tickCtx.subId, tickCtx.nodeIdx, entry.name, entry.remainOps or 0)
entry._exhaustLogged = true
end
entry.exhausted = true
end
end
else
entry.exhausted = true
end
end

tickCtx.totalColl = totalColl
tickCtx.nodeTopup      = nodeTopup
end

function _flushMachines(flushCtx)
local machineData    = flushCtx.machineData
local sortedStore = flushCtx.sortedStore
local ingCounts      = flushCtx.ingCounts
local step           = flushCtx.step
local helpers        = flushCtx.helpers
local outPerOp    = flushCtx.outPerOp
local totalExp  = flushCtx.totalExp
local waited         = flushCtx.waited
local totalColl = flushCtx.totalColl
local continueOuter  = flushCtx.continueOuter

local flushSilence    = 0
local flushMaxSilence = 2
repeat
if Craft.cancelled then break end
local hadOutput = false
for _, entry in ipairs(machineData) do
if Craft.cancelled then break end
local sp = entry.outPeriph
if sp and sp.list and sp.pushItems then
local sok, curItems = pcall(sp.list)
if sok and curItems then
local flushLeftover = false
for slot, curItem in pairs(curItems) do
if curItem and not ingCounts[curItem.name] then
local preCount = (entry.preSnap and entry.preSnap[curItem.name]) or 0
local toPull   = curItem.count - preCount
if toPull > 0 then
local pulled = 0
for _, stoName in ipairs(packOrder(curItem.name, sortedStore)) do
if pulled >= toPull then break end
local sm, mm = pcall(sp.pushItems, stoName, slot, toPull - pulled)
if sm and mm and mm > 0 then
pulled = pulled + mm; packRemember(curItem.name, stoName)
elseif sm and (not mm or mm == 0) then
packForget(curItem.name, stoName)
end
end
if pulled > 0 then
hadOutput = true
if curItem.name == step.item then
entry.doneItems = entry.doneItems + pulled
totalColl  = totalColl  + pulled
local sto = (flushCtx.baselineStore or 0) + totalColl
dbgPush(flushCtx.jobId, flushCtx.subId, flushCtx.nodeIdx, step.item,
pulled, totalColl, totalExp, sto, 0, entry.name)
end
end
if pulled < toPull then flushLeftover = true end
end
end
end
entry._flushLeftover = flushLeftover
end
end

helpers.drawProgress(flushCtx.i or 0, flushCtx.plan and #flushCtx.plan or 0, flushCtx.desc or "", totalColl, totalExp, step.item, #machineData)
if entry.remainOps > 0 and not entry._flushLeftover
and totalColl < totalExp then
local nextOps     = entry.remainOps
local acceptedOps = helpers.pushBatch(entry.name, nextOps)
if acceptedOps > 0 then
entry.remainOps        = nextOps - acceptedOps
entry.pendingItems     = entry.pendingItems + acceptedOps * outPerOp
entry.exhausted        = false
entry.hasAny = false
entry.lastCollTick  = waited
continueOuter = true
end
end
end
local flushNeed = flushMaxSilence

if totalColl < totalExp then
for _, entry in ipairs(machineData) do
if entry.doneItems < entry.pendingItems then
local floorQ = ((entry.collectCount or 0) >= 2) and 20 or 120
local q = math.max(floorQ, (entry.maxGap or 0) * 2 + 4)
if q > flushNeed then flushNeed = q end
end
end
end
if hadOutput then
flushSilence = 0
else
flushSilence = flushSilence + 1
end
if flushSilence < flushNeed and not Craft.cancelled then
sleepCancel(0.5)
end
until flushSilence >= flushNeed or Craft.cancelled

flushCtx.totalColl = totalColl
flushCtx.continueOuter  = continueOuter
end

function _machineCraftLoop(step, ctx, node, machCtx)
local activePool     = machCtx.activePool
local splitOutName   = machCtx.splitOutName
local splitOutPer = machCtx.splitOutPer
local myCleanup      = machCtx.myCleanup
local sortedStore = machCtx.sortedStore
local ingCounts      = machCtx.ingCounts
local totalOps       = machCtx.totalOps
local outPerOp    = machCtx.outPerOp
local totalExp  = machCtx.totalExp
local poolSize       = machCtx.poolSize
local base           = machCtx.base
local extra          = machCtx.extra
local helpers        = machCtx.helpers
local plan, i        = machCtx.plan, machCtx.i
local desc           = machCtx.desc
local nodeTopup      = machCtx.nodeTopup
local machineData    = machCtx.machineData

local totalColl = 0
local maxWait = math.max(600, math.min(3600, totalOps * 12))
local waited  = 0
local continueOuter = true
local absTarget = (machCtx.baselineStore or 0) + totalExp

while continueOuter do
continueOuter = false
for _, e in ipairs(machineData) do e.exhausted = false end
while totalColl < totalExp and waited < maxWait do
if groupAvail(step.item, getInvCached()) >= absTarget then break end
sleepCancel(0.5)
if Craft.cancelled then
cleanupCraftMachines(sortedStore, myCleanup)
failReason("machine.cancel_loop")
return false
end
waited = waited + 1
helpers.drawProgress(i, #plan, desc, totalColl, totalExp, step.item, #machineData)

local scan = nil
if #machineData > 1 then
local names, seen = {}, {}
for _, e in ipairs(machineData) do
if not seen[e.name] then seen[e.name] = true; names[#names+1] = e.name end
if e.outName and not seen[e.outName] then
seen[e.outName] = true; names[#names+1] = e.outName
end
end
local raw = scanPeriph(names, "list")
scan = {}
for n, rec in pairs(raw) do
if rec and rec.data then scan[n] = rec.data end
end
end

local tickCtx = {
sortedStore = sortedStore, ingCounts = ingCounts,
step = step, helpers = helpers, outPerOp = outPerOp, totalExp = totalExp,
waited = waited, totalColl = totalColl, nodeTopup = nodeTopup,
myCleanup = myCleanup, scan = scan,
jobId = machCtx.jobId, subId = machCtx.subId, nodeIdx = machCtx.nodeIdx,
baselineStore = machCtx.baselineStore,
}
for _, entry in ipairs(machineData) do
if Craft.cancelled then break end
_tickMachineEntry(entry, tickCtx)
end
totalColl = tickCtx.totalColl
nodeTopup      = tickCtx.nodeTopup

helpers.drawProgress(i, #plan, desc, totalColl, totalExp, step.item, #machineData)
local allExhausted = true
for _, entry in ipairs(machineData) do
if not entry.exhausted then allExhausted = false; break end
end
if allExhausted then break end
end

local flushCtx = {
machineData = machineData, sortedStore = sortedStore,
ingCounts = ingCounts, step = step, helpers = helpers,
outPerOp = outPerOp, totalExp = totalExp,
waited = waited, totalColl = totalColl,
continueOuter = continueOuter,
i = i, plan = plan, desc = desc,
jobId = machCtx.jobId, subId = machCtx.subId, nodeIdx = machCtx.nodeIdx,
baselineStore = machCtx.baselineStore,
}
_flushMachines(flushCtx)
totalColl = flushCtx.totalColl
continueOuter  = flushCtx.continueOuter
end

if not Craft.cancelled then
cleanupCraftMachines(sortedStore, myCleanup)
resetStock()
end
if totalColl == 0 then
resetStock()
failReason(string.format("machine.zero_output item=%s pool=%d waited=%d/%d",
tostring(shortName(step.item)), #machineData, waited, maxWait))
return false
end
if totalColl < totalExp then
resetStock()
if groupAvail(step.item, getInvCached()) >= absTarget then
machCtx.nodeTopup = nodeTopup
return true
end
failReason(string.format("machine.partial_output item=%s got=%d/%d",
tostring(shortName(step.item)), totalColl, totalExp))
return false
end
machCtx.nodeTopup = nodeTopup
return true
end

function _preUnloadMachines(preunloadCtx)
local activePool     = preunloadCtx.activePool
local splitOutName   = preunloadCtx.splitOutName
local sortedStore = preunloadCtx.sortedStore
local step           = preunloadCtx.step
local totalOps       = preunloadCtx.totalOps
local poolSize       = preunloadCtx.poolSize
local base           = preunloadCtx.base
local extra          = preunloadCtx.extra

local preUnload = {}
local inList = {}
for _, mName in ipairs(activePool) do table.insert(preUnload, mName); inList[mName] = true end
if splitOutName then table.insert(preUnload, splitOutName); inList[splitOutName] = true end

local dirtyDrop = {}
for _, mName in ipairs(preUnload) do
if Craft.cancelled then break end
local mPeriph = peripheral.wrap(mName)
local drained = {}
if mPeriph and mPeriph.list then
for _pass = 1, 3 do
local sPre, preItems = pcall(mPeriph.list)
if not (sPre and preItems) then break end
local anyPre = false
for slotPre, itemPre in pairs(preItems) do
if itemPre and itemPre.name and itemPre.count and itemPre.count > 0 then
anyPre = true
local leftPre = itemPre.count
local startedWith = leftPre
if mPeriph.pushItems then
for _, stoName in ipairs(packOrder(itemPre.name, sortedStore)) do
if leftPre <= 0 then break end
local okP, mvP = pcall(mPeriph.pushItems, stoName, slotPre, leftPre)
if okP and mvP and mvP > 0 then
leftPre = leftPre - mvP; packRemember(itemPre.name, stoName)
elseif okP and (not mvP or mvP == 0) then
packForget(itemPre.name, stoName)
end
end
end
if leftPre > 0 then
for _, stoName in ipairs(packOrder(itemPre.name, sortedStore)) do
if leftPre <= 0 then break end
local sto = peripheral.wrap(stoName)
if sto and sto.pullItems then
local okQ, mvQ = pcall(sto.pullItems, mName, slotPre, leftPre)
if okQ and mvQ and mvQ > 0 then
leftPre = leftPre - mvQ; packRemember(itemPre.name, stoName)
elseif okQ and (not mvQ or mvQ == 0) then
packForget(itemPre.name, stoName)
end
end
end
end
local moved = startedWith - leftPre
if moved > 0 then
drained[itemPre.name] = (drained[itemPre.name] or 0) + moved
end
end
end
if not anyPre then break end
sleepCancel(0.2)
end
local sChk, chkItems = pcall(mPeriph.list)
if sChk and chkItems then
for _, ci in pairs(chkItems) do
if ci and ci.name == step.item and (ci.count or 0) > 0 then
dirtyDrop[mName] = true
end
end
end
if next(drained) or dirtyDrop[mName] then
dbgPreunload(preunloadCtx.jobId, preunloadCtx.subId, preunloadCtx.nodeIdx,
mName, drained, dirtyDrop[mName])
end
end
if mPeriph and mPeriph.tanks then
local okT, tl = pcall(mPeriph.tanks)
if okT and tl then
for _, tk in pairs(tl) do
if tk and tk.name and tk.amount and tk.amount > 0 then
drainFluid(mName, tk.name, tk.amount)
end
end
end
end
end

if next(dirtyDrop) and not splitOutName then
local dropped = {}
for mName in pairs(dirtyDrop) do dropped[#dropped + 1] = mName end
local np = {}
for _, mName in ipairs(activePool) do
if not dirtyDrop[mName] then np[#np + 1] = mName end
end
if #np > 0 then
dbgPool(preunloadCtx.jobId, preunloadCtx.subId, preunloadCtx.nodeIdx, "shrink",
string.format("item=%s from=%d to=%d dropped=%s reason=dirty_output",
tostring(shortName(step.item)), #activePool, #np, table.concat(dropped, ",")))
activePool = np
poolSize = #activePool
base  = math.floor(totalOps / poolSize)
extra = totalOps % poolSize
end
end

preunloadCtx.activePool = activePool
preunloadCtx.poolSize   = poolSize
preunloadCtx.base       = base
preunloadCtx.extra      = extra
end

function _pushBatch(mName, opsCount, ing)
if Craft.cancelled then return 0 end
local counts, maxStack = ing.counts, ing.maxStack
local slot             = ing.slot
local srcStore      = ing.srcStore
local srcProviders     = ing.srcProviders

local machHas = {}
do
local pm = peripheral.wrap(mName)
if pm and pm.list then
local okM, its = pcall(pm.list)
if okM and its then
for _, it in pairs(its) do
if it and counts[it.name] then
machHas[it.name] = (machHas[it.name] or 0) + (it.count or 0)
end
end
end
end
end

for ingName, ingPerOp in pairs(counts) do
local maxS = maxStack[ingName] or 64
local curOps = math.floor((machHas[ingName] or 0) / ingPerOp)
local addable
if maxS >= ingPerOp then
addable = math.floor(maxS / ingPerOp) - curOps
else
addable = (curOps > 0) and 0 or 1
end
if addable < opsCount then opsCount = addable end
end

local invCached = getInvCached()
local stockCnt = {}
for ingName in pairs(counts) do
stockCnt[ingName] = invCached[ingName] or 0
local alts = Groups.altsOf(ingName)
if alts then for _, alt in ipairs(alts) do stockCnt[alt] = invCached[alt] or 0 end end
end
for ingName, ingPerOp in pairs(counts) do
local feasOps = math.floor(groupAvail(ingName, stockCnt) / ingPerOp)
if feasOps < opsCount then opsCount = feasOps end
end
if opsCount <= 0 then return 0 end

local accepted = opsCount
for ingName, ingPerOp in pairs(counts) do
local have   = machHas[ingName] or 0
local curOps = math.floor(have / ingPerOp)
local needed = (curOps + opsCount) * ingPerOp - have
local moved  = 0
if needed > 0 then
if ingPerOp <= (maxStack[ingName] or 64) then
moved = pushFromStore(ingName, needed, mName, slot[ingName], ing.prescan)
end
if moved < needed then
moved = moved + pushFromStore(ingName, needed - moved, mName, nil, ing.prescan)
end
end
local newOps = math.floor((have + moved) / ingPerOp) - curOps
if newOps < accepted then accepted = newOps end
end
return accepted
end

function _resolveActivePool(step)
local activePool = {}
for _, mName in ipairs(getMachPool(step.machine_name)) do
local p = peripheral.wrap(mName)
if p and p.list and p.pushItems then
table.insert(activePool, mName)
end
end
local splitOutName, splitOutPer = nil, nil
if step.output_device and step.output_device ~= "" then
splitOutName   = step.output_device
splitOutPer = peripheral.wrap(splitOutName)
if not (splitOutPer and splitOutPer.list) then
craftErrTitle = "! MACHINE NOT FOUND"
craftErrLines = {
"Output device not found: " .. getMachName(splitOutName),
"Required for: " .. (shortName(step.item)),
"Reconnect device or re-learn recipe.",
}
craftErrEdit = { [2] = step.item }
return nil
end
activePool = {}
local pIn = peripheral.wrap(step.machine_name)
if pIn and pIn.list and pIn.pushItems then
activePool = {step.machine_name}
end
end
if #activePool == 0 then
local mDisplay = getMachName and getMachName(step.machine_name or "?") or (step.machine_name or "?")
local itemShort = shortName(step.item)
craftErrTitle = "! MACHINE NOT FOUND"
craftErrLines = {
"Machine not found: " .. mDisplay,
"Required for: " .. itemShort,
"Use [E] in RECIPES to reassign machine.",
}
craftErrEdit = { [2] = step.item }
return nil
end
return activePool, splitOutName, splitOutPer
end

function _tallyIngredients(step)
local counts, slot = {}, {}
local slotN = 0
for i = 1, #step.ingredients do
local ing = step.ingredients[i]
if ing and ing ~= "nil" then
counts[ing] = (counts[ing] or 0) + 1
if not slot[ing] then
slotN = slotN + 1
slot[ing] = slotN
end
end
end
return counts, slot
end

function _scanMaxStacks(counts, storages)
maxStackCache = maxStackCache or {}
local out = {}
local misses = {}
for ingName in pairs(counts) do
local c = maxStackCache[ingName]
if c then out[ingName] = c else misses[#misses + 1] = ingName end
end
if #misses == 0 then return out end
local function probe(stoName, ingName)
local sto = peripheral.wrap(stoName)
if not (sto and sto.list and sto.getItemDetail) then return nil end
local okL, lst = pcall(sto.list)
if not (okL and lst) then return nil end
for slotI, itemI in pairs(lst) do
if itemI and itemI.name == ingName then
local okD, det = pcall(sto.getItemDetail, slotI)
if okD and det and det.maxCount and det.maxCount > 0 then
return det.maxCount
end
return 64
end
end
return nil
end
for _, ingName in ipairs(misses) do
local maxS
local hinted = craftPackIndex and craftPackIndex[ingName]
if hinted then
for stoName in pairs(hinted) do
maxS = probe(stoName, ingName)
if maxS then break end
end
end
if not maxS then
for _, stoName in ipairs(storages) do
if not (hinted and hinted[stoName]) then
maxS = probe(stoName, ingName)
if maxS then break end
end
end
end
maxS = maxS or 64
out[ingName] = maxS
maxStackCache[ingName] = maxS
end
return out
end

function _execStepMachine(step, ctx, node, state)
local sortedStore = state.sortedStore
local provSrc        = state.provSrc
local firstStore   = state.firstStore
local myCleanup      = state.myCleanup
local helpers        = state.helpers
local plan, i        = state.plan, state.i
local w, h           = state.w, state.h
local finalGoal  = state.finalGoal
local nodeTopup      = state.nodeTopup
local desc           = state.desc

local activePool, splitOutName, splitOutPer = _resolveActivePool(step)
if not activePool then failReason("machine.pool_missing item=" .. tostring(shortName(step.item))); return false end
local ingCounts, ingSlot = _tallyIngredients(step)

local phaseT = {}
local tPhaseStart = os.clock()
if step.count and step.count > 0 and not Craft.cancelled then
releaseTokens(node.tokens)
local tEnsure = os.clock()
local ingsOk, ingsErr, missIng = ensureIngs(step, ingCounts)
phaseT.ensure = os.clock() - tEnsure
if not ingsOk then
craftErrTitle = "! NEED"
craftErrLines = ingsErr or {"Can't make " .. shortName(step.item)}
failReason("machine.ing_topup_failed item=" .. tostring(shortName(missIng)))
return false
end
local tTokens = os.clock()
local waitedFirstFail = false
while not Craft.cancelled and not ctx.failed do
if acquireTokens(node.tokens) then break end
if not waitedFirstFail then
dbgTokens(Craft.jobId, ctx.subId, node.idx, "wait", node.tokens, 0)
waitedFirstFail = true
end
sleepYield(0.2, ctx)
end
phaseT.tokens = os.clock() - tTokens
if waitedFirstFail and not Craft.cancelled and not ctx.failed then
dbgTokens(Craft.jobId, ctx.subId, node.idx, "grab", node.tokens, phaseT.tokens)
end
if Craft.cancelled or ctx.failed then
failReason(Craft.cancelled and "machine.cancel_before_run" or "machine.ctx_failed_before_run")
return false
end
end

local ingPullNames = {}
for ingName in pairs(ingCounts) do ingPullNames[ingName] = true end
ingPullNames[step.item] = true

myCleanup = {}
for _, mName in ipairs(activePool) do
table.insert(myCleanup, {name = mName, pullNames = ingPullNames})
end
if splitOutName then
table.insert(myCleanup, {name = splitOutName, pullNames = ingPullNames})
end
for _, mNameU in ipairs(activePool) do Craft.usedMachines[mNameU] = true end
if splitOutName then Craft.usedMachines[splitOutName] = true end

local totalOps      = step.count
local outPerOp   = step.output_count or 1
local totalExp = totalOps * outPerOp
local poolSize      = #activePool

do
local invSnap = getInvCached()
local maxTotal = totalOps
for ingName, ingPerOp in pairs(ingCounts) do
local available = groupAvail(ingName, invSnap)
local ingCap = math.floor(available / ingPerOp)
if ingCap < maxTotal then maxTotal = ingCap end
end
if maxTotal < totalOps then totalOps = math.max(0, maxTotal) end
end
local base  = math.floor(totalOps / poolSize)
local extra = totalOps % poolSize
do
local opsPer = {}
for bIdx = 1, poolSize do
opsPer[bIdx] = tostring(base + ((bIdx <= extra) and 1 or 0))
end
dbgPool(Craft.jobId, ctx.subId, node.idx, "assign",
string.format("item=%s pool=%s ops=%s split=%s",
tostring(shortName(step.item)), table.concat(activePool, ","),
table.concat(opsPer, ","), tostring(splitOutName or "-")))
end
helpers.drawProgress(i, #plan, desc, 0, totalExp, step.item, #activePool)
local ingMaxStack = _scanMaxStacks(ingCounts, sortedStore)

local ingCtx = {
counts       = ingCounts,
maxStack     = ingMaxStack,
slot         = ingSlot,
srcStore  = sortedStore,
srcProviders = provSrc,
}
helpers.pushBatch = function(mName, opsCount)
local accepted = _pushBatch(mName, opsCount, ingCtx)
if accepted < opsCount then
local shorts = {}
local invSnap = getInvCached()
for ingName in pairs(ingCounts) do
local avail = groupAvail(ingName, invSnap)
shorts[#shorts+1] = string.format("%s=%d", tostring(shortName(ingName)), avail)
end
dbgLoad(Craft.jobId, ctx.subId, node.idx, mName, opsCount, accepted,
"stock=" .. table.concat(shorts, ","))
else
dbgLoad(Craft.jobId, ctx.subId, node.idx, mName, opsCount, accepted)
end
return accepted
end

local preunloadCtx = {
activePool = activePool, splitOutName = splitOutName,
sortedStore = sortedStore, step = step,
totalOps = totalOps, poolSize = poolSize, base = base, extra = extra,
jobId = Craft.jobId, subId = ctx.subId, nodeIdx = node.idx,
}
local tPre = os.clock()
_preUnloadMachines(preunloadCtx)
phaseT.preunload = os.clock() - tPre
activePool = preunloadCtx.activePool
poolSize   = preunloadCtx.poolSize
base       = preunloadCtx.base
extra      = preunloadCtx.extra

local machineData = {}
local snapNames = {}
local snapSeen = {}
for bIdx = 1, poolSize do
local mName = activePool[bIdx]
local cName = splitOutName or mName
if not snapSeen[cName] then snapSeen[cName] = true; snapNames[#snapNames + 1] = cName end
end
local tScan = os.clock()
local preSnaps = scanPeriph(snapNames, "list")
phaseT.scan = os.clock() - tScan

local setupTasks = {}
for bIdx = 1, poolSize do
local assignedOps = base + (bIdx <= extra and 1 or 0)
if assignedOps > 0 then
local mName = activePool[bIdx]
setupTasks[#setupTasks + 1] = function()
local mPeriph = peripheral.wrap(mName)
if not mPeriph then return end
local collectPeriph = splitOutPer or mPeriph
local collectName   = splitOutName   or mName
local excluded = {}
local preSnap  = {}
local snap = preSnaps[collectName]
if snap and snap.data then
for _, si in pairs(snap.data) do
if si and si.name ~= step.item then
excluded[si.name] = true
preSnap[si.name] = (preSnap[si.name] or 0) + si.count
end
end
end
for ingName in pairs(ingCounts) do excluded[ingName] = true end
local acceptedOps = helpers.pushBatch(mName, assignedOps)
machineData[#machineData + 1] = {
periph            = mPeriph,
outPeriph         = collectPeriph,
name              = mName,
outName           = collectName,
excluded          = excluded,
preSnap           = preSnap,
remainOps         = assignedOps - acceptedOps,
pendingItems      = acceptedOps * outPerOp,
doneItems         = 0,
lastCollTick   = 0,
exhausted         = false,
hasAny  = false,
collectCount      = 0,
refillCount       = 0,
}
end
end
end
local tSetup = os.clock()
if #setupTasks > 1 then
ingCtx.prescan = scanPeriph(scanStorage(), "list")
end
if #setupTasks > 0 then parallel.waitForAll(table.unpack(setupTasks)) end
ingCtx.prescan = nil
phaseT.setup = os.clock() - tSetup
dbgPhase(Craft.jobId, ctx.subId, node.idx, step.item, phaseT)

local baselineStore = (getInvCached()[step.item] or 0)
local machCtx = {
activePool = activePool, splitOutName = splitOutName, splitOutPer = splitOutPer,
myCleanup = myCleanup, sortedStore = sortedStore,
ingCounts = ingCounts, machineData = nil,
totalOps = totalOps, outPerOp = outPerOp, totalExp = totalExp,
poolSize = poolSize, base = base, extra = extra,
helpers = helpers, plan = plan, i = i, desc = desc, step = step,
nodeTopup = nodeTopup,
jobId = Craft.jobId, subId = ctx.subId, nodeIdx = node.idx,
baselineStore = baselineStore,
}
machCtx.machineData = machineData
if not _machineCraftLoop(step, ctx, node, machCtx) then return false end
nodeTopup = machCtx.nodeTopup

state.myCleanup = myCleanup
state.nodeTopup = nodeTopup
return true
end
-->60_craft/60_4_engine_machine.lua
--<60_craft/60_5_engine_scheduler.lua

runFluidCraft = function(fplan)
local toks = fluidRecipeTokens(fplan.recipe)
local got = false
local waitN = 0
while true do
if acquireTokens(toks) then got = true; break end
if Craft.cancelled then return false, {"Cancelled by user."}, 0 end
sleepCancel(0.2)
waitN = waitN + 1
if waitN > 450 then break end
end
while _fluidBusy do
if Craft.cancelled then
if got then releaseTokens(toks) end
return false, {"Cancelled by user."}, 0
end
sleepCancel(0.1)
end
_fluidBusy = true
local okStore, storeErr, nOuts = checkOutStore(fplan.recipe)
if okStore then fluidTankClaims = fluidTankClaims + (nOuts or 0) end
_fluidBusy = false
if not okStore then
if got then releaseTokens(toks) end
return false, storeErr, 0
end
local okR, errR, producedR = fluidCraftInner(fplan)
fluidTankClaims = math.max(0, fluidTankClaims - (nOuts or 0))
if got then releaseTokens(toks) end
return okR, errR, producedR
end

optActive = false
optTimer  = nil
allScanActive  = false


function _execStepFluid(step, ctx, node, finalGoal, sortedStore, myCleanup)
fluidGoalLabel = finalGoal ~= "" and finalGoal or step.item
fluidStepNum   = 0
fluidStepTotal = countTopSteps(step.fluidRecipe, step.item, step.fluidAmount)
ctx.active[node.idx] = {
desc = shortName(step.item) .. " (fluid)",
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
craftErrTitle = "! FLUID SUBCRAFT FAILED"
craftErrLines = errF or {"Unknown error"}
cleanupCraftMachines(sortedStore, myCleanup)
return false
end
return true
end

function execStep(step, ctx, node)
local sortedStore = ctx.sortedStore
local provSrc        = providerSrc()
local firstStore   = ctx.firstStore
local finalGoal  = ctx.finalGoal
local plan           = ctx.plan
local i              = node.idx
local w, h           = monitor.getSize()
local myCleanup      = {}
local nodeTopup      = false

local helpers = {}
helpers.drawProgress = function(stepNum, totalSteps, desc, curCount, maxCount, activeName, workerCount)
ctx.active[node.idx] = { desc = desc, done = curCount or 0, total = maxCount or 0,
machines = workerCount or 0, topup = nodeTopup }
if displayCtx and displayCtx ~= ctx then
displayCtx.active["NEST:" .. tostring(lockOwnerId())] = {
desc = desc, done = curCount or 0, total = maxCount or 0,
machines = workerCount or 0, topup = nodeTopup, nest = true,
}
end
end

local state = {
sortedStore = sortedStore, provSrc = provSrc,
firstStore = firstStore, myCleanup = myCleanup, helpers = helpers,
plan = plan, i = i, w = w, h = h,
finalGoal = finalGoal, nodeTopup = nodeTopup, desc = nil,
}
if step.count and step.count > 0 then
local desc = string.format("%d x %s", step.count * (step.output_count or 1), shortName(step.item))
state.desc = desc
if step.fluid_craft then
if not _execStepFluid(step, ctx, node, finalGoal, sortedStore, myCleanup) then return false end
elseif step.type == "turtle" then
if not _execStepTurtle(step, ctx, node, state) then return false end
myCleanup = state.myCleanup
elseif step.type == "crafter" then
if not _execStepCrafter(step, ctx, node, state) then return false end
myCleanup = state.myCleanup
else
if not _execStepMachine(step, ctx, node, state) then return false end
myCleanup = state.myCleanup
nodeTopup = state.nodeTopup
end
end
node.produced = (ctx.active[node.idx] and ctx.active[node.idx].done) or node.produced or 0
ctx.active[node.idx] = nil
return true
end

function mergePlan(plan)
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
if ready and acquireTokens(node.tokens) then
node.started = true
return node
end
end
end
return nil
end

function drawParallel(ctx)
if drawUI then drawUI(true) end
local w, h = monitor.getSize()
local pW, pH = 46, 14
local title = ctx.failed and " MANUFACTURING FAILED " or " MANUFACTURING ACTIVE "
local style = ctx.failed and "danger" or "warn"
local pX, pY = UI.popup(pW, pH, w, h, title, style)

local activeList = {}
for _, a in pairs(ctx.active) do activeList[#activeList + 1] = a end
table.sort(activeList, function(x, y) return (x.done or 0) > (y.done or 0) end)

local sDone  = stageDone or 0
local sTotal = math.max(stageTotal or 0, sDone, 1)
local stepStr = string.format("Sub-task %d/%d", sDone, sTotal)
drawText(pX + 2, pY + 2, stepStr, colors.white, colors.gray)
local wStr = "[" .. #activeList .. "x parallel]"
drawText(pX + pW - #wStr - 2, pY + 2, wStr, colors.cyan, colors.gray)
local cleanFinal = (shortName(ctx.finalGoal)):upper()
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
drawProgBar(barX, pY + pH - 3, barWidth, sDone, sTotal, colors.gray)

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
return ctx.failed or Craft.cancelled or ctx.remaining <= 0
end

runCraft = function(plan)
if #plan == 0 then return false end
if Craft.depth == 0 then
Craft.cancelled = false; Craft.failed = false; Craft.locks = {}; Craft.usedMachines = {}
Craft.lastFailStage = nil; Craft.lastFail = nil
fluidTankClaims = 0; _fluidBusy = false; fluidInlineByCo = {}
Craft.jobId = dbgNextJob(Craft.jobSrc)
Craft.subSeq = 0
ensureDepthByCo = {}
failReasonByCo = {}
end
Craft.subSeq = (Craft.subSeq or 0) + 1
local ctxSubId = Craft.subSeq
if Craft.cancelled then return false end

local sortedStore = {}
for sName, enabled in pairs(Config.storages) do
if enabled then
local p = peripheral.wrap(sName)
if p and p.list and p.pullItems then sortedStore[#sortedStore + 1] = sName end
end
end
table.sort(sortedStore)
local firstStore = sortedStore[1]
if not firstStore then return false end

craftPackIndex     = {}
craftPackFree      = {}
maxStackCache = {}
craftScan     = nil
craftScan     = scanStorage()
local packScan = scanPeriph(sortedStore, "list", true)
for _, s in ipairs(sortedStore) do
local e = packScan[s]
if e then
local used = 0
if e.data then
for _, it in pairs(e.data) do
if it then
craftPackIndex[it.name] = craftPackIndex[it.name] or {}
craftPackIndex[it.name][s] = true
used = used + 1
end
end
end
if e.size and used < e.size then craftPackFree[s] = true end
end
end

plan = mergePlan(plan)
local nodes = buildCraftDAG(plan)
local finalGoal = plan[#plan] and plan[#plan].item or ""
local remaining = 0
for _, n in ipairs(nodes) do if not n.done then remaining = remaining + 1 end end

local ctx = {
plan = plan, nodes = nodes, sortedStore = sortedStore,
firstStore = firstStore, finalGoal = finalGoal,
remaining = remaining, total = #nodes, doneCount = 0,
active = {}, failed = false, failErr = nil, done = false, fluidActive = false,
subId = ctxSubId,
}
if remaining <= 0 then resetStock(); return true end

local isTop = (Craft.depth == 0)
if isTop then
displayCtx = ctx
stageDone  = 0
stageTotal = estimateStages(plan)
end
local distinct, nDistinct = {}, 0
for _, n in ipairs(nodes) do
for _, t in ipairs(n.tokens) do
if not distinct[t] then distinct[t] = true; nDistinct = nDistinct + 1 end
end
end
local workerCount = math.min(math.max(1, nDistinct), 32)

local function worker()
while not ctx.done do
if schedDone(ctx) then ctx.done = true; return end
local node = claimReadyNode(ctx)
if not node then
local tmW = os.startTimer(0.2)
local evW, aW = os.pullEvent()
if not (evW == "timer" and aW == tmW) then os.cancelTimer(tmW) end
else
failReasonByCo[lockOwnerId()] = nil
local nkind = node.step.fluid_craft and "fluid"
or ((node.step.type == "turtle" or node.step.type == "crafter") and node.step.type or "machine")
dbgStart(Craft.jobId, ctx.subId, node.idx, node.step.item, node.step.count or 0, nkind)
local ok, err = execStep(node.step, ctx, node)
releaseTokens(node.tokens)
ctx.active[node.idx] = nil
dbgDone(Craft.jobId, ctx.subId, node.idx, node.step.item, node.produced or 0, ok, err)
if ok then
node.done = true
ctx.remaining = ctx.remaining - 1
ctx.doneCount = ctx.doneCount + 1
if not node.step.fluid_craft then stageDone = (stageDone or 0) + 1 end
else
node.done = true
ctx.remaining = ctx.remaining - 1
if not Craft.cancelled and not ctx.failed then
dbgFail(Craft.jobId, ctx.subId, node.idx, node.step.item,
failReasonByCo[lockOwnerId()] or (err and tostring(err)) or "?")
end
if not Craft.cancelled then
ctx.failed = true
ctx.failErr = err
Craft.failed = true
if not Craft.lastFailStage then
Craft.lastFailStage = node.step.item
local r = failReasonByCo[lockOwnerId()]
if not r and err then
if type(err) == "table" then
local ok, joined = pcall(table.concat, err, "; ")
r = ok and joined or "?"
else
r = tostring(err)
end
end
Craft.lastFail = r or "?"
end
end
end
end
end
end

local function uiLoop()
while not ctx.done do
if schedDone(ctx) and not next(ctx.active) then
ctx.done = true; return
end
drawParallel(ctx)
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
Craft.cancelled = true
end
if ctx.done then return end
if os.clock() >= deadline then os.cancelTimer(timer); break end
end
if schedDone(ctx) then ctx.done = true; return end
end
end

local tasks = {}
for _ = 1, workerCount do tasks[#tasks + 1] = worker end
if isTop then
tasks[#tasks + 1] = uiLoop
tasks[#tasks + 1] = cancelWatch
end
parallel.waitForAll(table.unpack(tasks))

if isTop then
displayCtx = nil
sweepMachines()
Craft.failed = false
craftScan = nil
end
resetStock()
if Craft.cancelled then return false end
if ctx.failed then return false end
return true
end
-->60_craft/60_5_engine_scheduler.lua
--<60_craft/60_6_registry.lua
Craft = {
cancelled       = false,
failed          = false,
lastFailStage   = nil,
lastFail  = nil,
depth           = 0,
locks           = {},
usedMachines    = {},
cleanMachines = {},
queue           = {},
jobId           = 0,
jobSrc          = nil,
}

ensureDepthByCo = {}
failReasonByCo  = {}
-->60_craft/60_6_registry.lua
--<60_craft/60_7_dbglog.lua
DBG_LOG_ENABLED = false

DBG_LOG_FILE = "factory_dbg.log"
DBG_LOG_MAX  = 256 * 1024

_dbgJobSeq = 0

function dbgInit()
DBG_LOG_ENABLED = (Config and Config.debug_log == true) or false
if not DBG_LOG_ENABLED then return end
local sz = fs.exists(DBG_LOG_FILE) and (fs.getSize(DBG_LOG_FILE) or 0) or 0
if sz > DBG_LOG_MAX then
fs.delete(DBG_LOG_FILE .. ".old")
fs.move(DBG_LOG_FILE, DBG_LOG_FILE .. ".old")
end
local fh = fs.open(DBG_LOG_FILE, "a")
if fh then
fh.writeLine(string.format("%.2f ---- boot cid=%d", os.clock(), os.getComputerID()))
fh.close()
end
end

function dbgWipe()
fs.delete(DBG_LOG_FILE)
fs.delete(DBG_LOG_FILE .. ".old")
end

function dbgWrite(line)
if not DBG_LOG_ENABLED then return end
local fh = fs.open(DBG_LOG_FILE, "a")
if not fh then return end
fh.writeLine(string.format("%.2f %s", os.clock(), line))
fh.close()
end

function dbgNextJob(src)
_dbgJobSeq = _dbgJobSeq + 1
dbgWrite(string.format("j=%d job.new src=%s", _dbgJobSeq, tostring(src or "?")))
return _dbgJobSeq
end

local function shortItem(n) return n and (n:match(":(.+)$") or n) or "?" end

function dbgStart(jid, sid, idx, item, count, kind)
if not DBG_LOG_ENABLED then return end
dbgWrite(string.format("j=%d s=%d start idx=%d item=%s count=%d kind=%s",
jid or 0, sid or 0, idx or 0, shortItem(item), count or 0, kind or "?"))
end

function dbgPush(jid, sid, idx, item, added, total, want, storage, reserved, mach)
if not DBG_LOG_ENABLED then return end
local line = string.format("j=%d s=%d push idx=%d item=%s add=%d tot=%d/%d sto=%d res=%d",
jid or 0, sid or 0, idx or 0, shortItem(item),
added or 0, total or 0, want or 0, storage or 0, reserved or 0)
if mach then line = line .. " mach=" .. tostring(mach) end
dbgWrite(line)
end

function dbgFluidPush(jid, sid, idx, fluid, added, total, want, storage, reserved, mach)
if not DBG_LOG_ENABLED then return end
local line = string.format("j=%d s=%d push idx=%d fluid=%s add=%d tot=%d/%d sto=%d res=%d",
jid or 0, sid or 0, idx or 0, shortItem(fluid),
added or 0, total or 0, want or 0, storage or 0, reserved or 0)
if mach then line = line .. " mach=" .. tostring(mach) end
dbgWrite(line)
end

function dbgPool(jid, sid, idx, event, detail)
if not DBG_LOG_ENABLED then return end
dbgWrite(string.format("j=%d s=%d pool.%s idx=%d %s",
jid or 0, sid or 0, tostring(event or "?"), idx or 0, tostring(detail or "")))
end

function dbgLoad(jid, sid, idx, mach, want, got, note)
if not DBG_LOG_ENABLED then return end
local line = string.format("j=%d s=%d load idx=%d mach=%s want=%d got=%d",
jid or 0, sid or 0, idx or 0, tostring(mach), want or 0, got or 0)
if note then line = line .. " " .. note end
dbgWrite(line)
end

function dbgExhaust(jid, sid, idx, mach, remainOps)
if not DBG_LOG_ENABLED then return end
dbgWrite(string.format("j=%d s=%d exhaust idx=%d mach=%s remainOps=%d",
jid or 0, sid or 0, idx or 0, tostring(mach), remainOps or 0))
end

function failReason(reason)
failReasonByCo[lockOwnerId()] = reason
end

function dbgDone(jid, sid, idx, item, produced, ok, err)
if not DBG_LOG_ENABLED then return end
local line = string.format("j=%d s=%d done idx=%d item=%s prod=%d ok=%d",
jid or 0, sid or 0, idx or 0, shortItem(item), produced or 0, ok and 1 or 0)
if not ok then
local reason = failReasonByCo[lockOwnerId()]
local errTxt
if type(err) == "table" then errTxt = table.concat(err, ";")
elseif err then                 errTxt = tostring(err)
elseif reason then              errTxt = reason
else                            errTxt = tostring(craftErrTitle or "?") .. "|" .. table.concat(craftErrLines or {}, ";") end
line = line .. " err=" .. errTxt:gsub("%s+", " "):sub(1, 120)
end
dbgWrite(line)
end

function dbgFail(jid, sid, idx, item, reason)
if not DBG_LOG_ENABLED then return end
dbgWrite(string.format("j=%d s=%d FAIL idx=%d item=%s reason=%s",
jid or 0, sid or 0, idx or 0, shortItem(item), tostring(reason or "?"):sub(1, 120)))
end

function dbgPreunload(jid, sid, idx, mach, drained, dirty)
if not DBG_LOG_ENABLED then return end
local parts = {}
for name, cnt in pairs(drained or {}) do
parts[#parts + 1] = shortItem(name) .. "=" .. tostring(cnt)
end
local line = string.format("j=%d s=%d preunload idx=%d mach=%s drained=%s",
jid or 0, sid or 0, idx or 0, tostring(mach),
(#parts > 0) and table.concat(parts, ",") or "-")
if dirty then line = line .. " dirty" end
dbgWrite(line)
end

function dbgPhase(jid, sid, idx, item, timings)
if not DBG_LOG_ENABLED then return end
local parts = {}
for _, k in ipairs({"ensure", "tokens", "preunload", "scan", "setup"}) do
if timings[k] then parts[#parts + 1] = string.format("%s=%.2fs", k, timings[k]) end
end
dbgWrite(string.format("j=%d s=%d phase idx=%d item=%s %s",
jid or 0, sid or 0, idx or 0, shortItem(item), table.concat(parts, " ")))
end

function dbgTokens(jid, sid, idx, event, toks, waited)
if not DBG_LOG_ENABLED then return end
local tstr = "-"
if toks and #toks > 0 then tstr = table.concat(toks, ",") end
local line = string.format("j=%d s=%d tokens.%s idx=%d toks=%s",
jid or 0, sid or 0, tostring(event or "?"), idx or 0, tstr)
if waited and waited > 0.05 then line = line .. string.format(" waited=%.2fs", waited) end
dbgWrite(line)
end

function dbgLeftover(jid, sid, idx, mach, item, count)
if not DBG_LOG_ENABLED then return end
dbgWrite(string.format("j=%d s=%d leftover idx=%d mach=%s item=%s count=%d",
jid or 0, sid or 0, idx or 0, tostring(mach), shortItem(item), count or 0))
end
-->60_craft/60_7_dbglog.lua
--<60_craft/60_8_engine_crafter.lua

CRAFTER_HAND_EMPTY = "Take items back: empty-hand right-click each crafter front."

local function crafterFail(title, lines, reason)
craftErrTitle = title
craftErrLines = lines
failReason(reason)
pcall(crafterSetLock, true)
return false
end

local function crafterAlloc(need, scanNames)
local prescan = scanPeriph(scanNames, "list")
local avail = {}
for _, n in ipairs(scanNames) do
local e = prescan[n]
if e and e.data then
for _, it in pairs(e.data) do
if it then avail[it.name] = (avail[it.name] or 0) + (it.count or 0) end
end
end
end
local bstock = nil
local pick, short = {}, {}
for _, n in ipairs(need) do
local cands = { n.ing }
for _, a in ipairs(Groups.altsOf(n.ing) or {}) do
if a ~= n.ing then cands[#cands + 1] = a end
end
for _, c in ipairs(cands) do
if (avail[c] or 0) <= 0 then
bstock = bstock or bridgeStock()
if (bstock[c] or 0) > 0 then avail[c] = bstock[c]; bstock[c] = 0 end
end
if (avail[c] or 0) > 0 then
avail[c] = avail[c] - 1
pick[n.k] = c
break
end
end
if not pick[n.k] then short[n.ing] = (short[n.ing] or 0) + 1 end
end
if next(short) then return nil, short end
return pick, prescan
end

local function crafterPushOne(name, cell, prescan, scanNames)
local dst = peripheral.wrap(cell)
for pass = 1, 2 do
local scanned = (pass == 1 and prescan) or scanPeriph(scanNames, "list")
for _, stoName in ipairs(scanNames) do
local e = scanned[stoName]
local sto = e and e.data and peripheral.wrap(stoName)
if sto and sto.getItemDetail then
for slot, it in pairs(e.data) do
if it and it.name == name then
local okD, det = pcall(sto.getItemDetail, slot)
if okD and det and det.name == name and (det.count or 0) > 0 then
local okP, mv = false, 0
if sto.pushItems then
okP, mv = pcall(sto.pushItems, cell, slot, 1, 1)
elseif dst and dst.pullItems then
okP, mv = pcall(dst.pullItems, stoName, slot, 1, 1)
end
if okP and type(mv) == "number" and mv > 0 then
resetStock()
return true
end
if okP then return false end
end
end
end
end
end
end
return (bridgeFeed(name, 1, cell, 1) or 0) > 0
end

local function crafterAwaitOut(want, target, onTick)
local t, prevSig, stable = 0, nil, 0
while t < CRAFTER_TIMEOUT do
if onTick then onTick() end
sleep(0.5)
t = t + 0.5
local sig, have = {}, 0
for _, it in pairs(crafterOutList()) do
if it then
sig[#sig + 1] = it.name .. "=" .. (it.count or 0)
if it.name == target then have = have + (it.count or 0) end
end
end
table.sort(sig)
local s = table.concat(sig, ",")
if s == prevSig then stable = stable + 1 else stable = 0 end
prevSig = s
if have >= want and stable >= 1 then return true end
end
return false
end

function crafterRunCycle(tgt, cur, dstNames, scanNames, onTick)
local c = crafterCfg()
local loaded = {}
for gi = 1, #c.cells do loaded[gi] = cur[gi] or "nil" end
local need, planned = {}, {}
for k, cell in ipairs(tgt.cells) do
local gi = crafterCellIdx(cell)
local want = tgt.ings[k] or "nil"
planned[k] = (gi and cur[gi] ~= "nil") and cur[gi] or want
if gi and want ~= "nil" and cur[gi] == "nil" then
need[#need + 1] = {k = k, ing = want, cell = cell, gi = gi}
end
end
local itemShort = shortName(tgt.item)

if #need > 0 then
local pick, prescan = crafterAlloc(need, scanNames)
if not pick then return false, nil, nil, prescan end
for _, n in ipairs(need) do planned[n.k] = pick[n.k] end
crafterJobSave({item = tgt.item, ings = planned, cells = tgt.cells, perOp = tgt.perOp})
for _, n in ipairs(need) do
if onTick then onTick() end
local nm = pick[n.k]
if not crafterPushOne(nm, n.cell, prescan, scanNames) then
return false, {
title = "! CRAFTER LOAD FAILED",
lines = {
"Couldn't insert " .. shortName(nm) .. " into " .. getMachName(n.cell),
"(slot cover? crafter busy?). Grid is part-loaded + LOCKED.",
"[FINISH GRID] in +RECIPES > CRAFTER retries it.",
CRAFTER_HAND_EMPTY,
},
reason = "crafter.load_failed cell=" .. tostring(n.cell),
}
end
loaded[n.gi] = nm
end
else
crafterJobSave({item = tgt.item, ings = planned, cells = tgt.cells, perOp = tgt.perOp})
end

local started, sErr = crafterStart(loaded, true, onTick)
if not started then
local lines = {"Grid loaded for " .. itemShort .. " but it never began."}
lines[#lines + 1] = sErr and tostring(sErr) or "Empty cells need a PULSE relay or slot covers."
lines[#lines + 1] = "Items stay in the grid. [FINISH GRID] retries it."
return false, {title = "! CRAFTER DIDN'T START", lines = lines,
reason = "crafter.no_start item=" .. tostring(itemShort)}
end
crafterJobClear()

local okOut = crafterAwaitOut(tgt.perOp or 1, tgt.item, onTick)
local got = crafterDrainOut(dstNames)
if not okOut then
local lines = {
"No " .. itemShort .. " after " .. CRAFTER_TIMEOUT .. "s.",
"Wrong recipe/layout: create drops the",
"items at the crafters. Check the floor.",
}
if next(got) then lines[#lines + 1] = "Got something else instead (in vaults)." end
return false, {title = "! CRAFTER NO OUTPUT", lines = lines,
reason = "crafter.no_output item=" .. tostring(itemShort)}, got
end
return true, nil, got
end

function _execStepCrafter(step, ctx, node, state)
local sortedStore = state.sortedStore
local helpers     = state.helpers
local plan, i     = state.plan, state.i
local desc        = state.desc
local ings  = step.ingredients or {}
local cells = step.grid_cells or {}
local itemShort = shortName(step.item)
state.myCleanup = {}

if #ings == 0 or #ings ~= #cells then
return crafterFail("! CRAFTER RECIPE BROKEN", {
"Recipe for " .. itemShort .. " has no cell map.",
"Re-learn it in +RECIPES > CRAFTER.",
}, "crafter.bad_recipe item=" .. tostring(itemShort))
end
local okR, why = crafterReady(cells)
if not okR then
return crafterFail("! CRAFTER NOT READY", {
"Required for: " .. itemShort, tostring(why),
"Check grid/relay/output in +RECIPES > CRAFTER.",
}, "crafter.not_ready " .. tostring(why))
end
local c = crafterCfg()
Craft.usedMachines[c.out] = true

local ingNeed = {}
for _, ing in ipairs(ings) do
if ing ~= "nil" then ingNeed[ing] = (ingNeed[ing] or 0) + 1 end
end
releaseTokens(node.tokens)
local okI, errI, missIng = ensureIngs(step, ingNeed)
if not okI then
craftErrTitle = "! NEED"
craftErrLines = errI or {"Can't make " .. itemShort}
failReason("crafter.ing_topup_failed item=" .. tostring(shortName(missIng)))
return false
end
while not Craft.cancelled and not ctx.failed do
if acquireTokens(node.tokens) then break end
sleepYield(0.2, ctx)
end
if Craft.cancelled or ctx.failed then
failReason(Craft.cancelled and "crafter.cancel_before_run" or "crafter.ctx_failed_before_run")
return false
end

local perOp     = step.output_count or 1
local totalNeed = step.count or 0
local totalDone = 0
local dry = 0
local scanNames = scanStorage()

local function tick()
local d = Craft.cancelled and (desc .. " (finishing cycle)") or desc
helpers.drawProgress(i, #plan, d, totalDone, totalNeed, step.item, 1)
end

while totalDone < totalNeed do
if Craft.cancelled then failReason("crafter.cancel"); pcall(crafterSetLock, true); return false end
tick()

local okL, lockErr = crafterSetLock(true)
if not okL then
return crafterFail("! CRAFTER CLUTCH", {tostring(lockErr)}, "crafter.lock " .. tostring(lockErr))
end
crafterDrainOut(sortedStore)

local cur, rErr = crafterReadCells()
if not cur then
return crafterFail("! CRAFTER GRID", {tostring(rErr)}, "crafter.read " .. tostring(rErr))
end

local tgt, residue
if crafterGridEmpty(cur) then
tgt = {item = step.item, ings = ings, cells = cells, perOp = perOp}
else
local whyR
tgt, whyR = crafterResidueTarget(cur)
if not tgt then
local dirty = {}
for idx, v in ipairs(cur) do
if v ~= "nil" then dirty[#dirty + 1] = shortName(v) .. "@" .. idx end
end
return crafterFail("! CRAFTER GRID NOT EMPTY", {
"Crafters hold items the computer can't pull out:",
table.concat(dirty, ", "):sub(1, 60),
tostring(whyR) .. ".",
CRAFTER_HAND_EMPTY,
}, "crafter.grid_dirty n=" .. #dirty)
end
residue = true
dbgWrite(string.format("j=%d s=%d crafter.residue idx=%d target=%s job=%s",
Craft.jobId or 0, ctx.subId or 0, node.idx or 0, shortName(tgt.item), tostring(tgt.fromJob)))
end

local ok, err, got, short = crafterRunCycle(tgt, cur, sortedStore, scanNames, tick)
if ok then
dry = 0
if tgt.item == step.item then
local made = got[step.item] or 0
local ops = math.max(1, math.floor(made / perOp))
if ops > totalNeed - totalDone then ops = totalNeed - totalDone end
totalDone = totalDone + ops
dbgPush(Craft.jobId, ctx.subId, node.idx, step.item, made,
totalDone * perOp, totalNeed * perOp, 0, 0, CRAFTER_MACHINE)
end
elseif short then
local parts = {}
for ing, n in pairs(short) do parts[#parts + 1] = string.format("%dx %s", n, shortName(ing)) end
if residue then
local lines = {"Grid holds part of " .. shortName(tgt.item) .. ", can't finish it."}
appendMissing(lines, parts)
lines[#lines + 1] = "Stock up and retry, or empty the grid."
lines[#lines + 1] = CRAFTER_HAND_EMPTY
return crafterFail("! CRAFTER LEFTOVER", lines, "crafter.residue_short item=" .. tostring(shortName(tgt.item)))
end
for ing, n in pairs(short) do bridgeStage(ing, n * (totalNeed - totalDone)) end
dry = dry + 1
if dry >= 3 then
local lines = {"Can't load grid for " .. itemShort}
appendMissing(lines, parts)
return crafterFail("! NEED", lines, "crafter.no_stock item=" .. tostring(itemShort))
end
resetStock()
sleepCancel(1.0)
else
return crafterFail(err.title, err.lines, err.reason)
end
end
pcall(crafterSetLock, true)
tick()
return true
end
-->60_craft/60_8_engine_crafter.lua
--<60_craft/60_a_state.lua
function resetErr() craftErrLines = {}; craftErrTitle = nil end
resetErr()
craftErrEdit = {}
queueEditPopup     = false
queueErrIdx    = nil
queueScroll    = 0
queueEditIdx        = nil
selCraftType   = "turtle"
sysStatus        = "IDLE"
craftSubTab         = "TURTLE"
craftDevPage     = 1
selOut = nil
outPickMode      = false
altViewItem    = nil
altViewFluid   = nil
learnAsAlt     = false
learnAsAltItem = nil
keepThr              = 0
keepTgt              = 0
keepField            = "threshold"
pendDelItem      = nil
isRequestMode          = false
reqMaxQty          = 0
pickerCraftable     = 0
pickerCapped        = false
pickerMaxSet      = true
pickerHdr       = nil
calcNodes              = 0
calcBudget             = 0
CALC_BUDGET            = 100
qtyOrigTab           = "RECIPES"
craftDonePopup     = nil
scanActive    = false
scanTimer     = nil
recipesScan = {}
craftInfoPop     = nil
machInfoPopup   = nil
recipeEditPop    = nil
altOutEdit         = nil
itemToCraft          = ""
craftQuantity        = 1
isSettingKeep   = false
learnState        = "IDLE"
learnedResult        = nil
learnedIngs   = nil
learnedTools         = nil
learnedType     = ""
learnedMach   = ""
learnedOut  = nil
-->60_craft/60_a_state.lua
--<70_services/70_0_notify.lua
function b64enc(s)
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

function b64dec(s)
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

function httpGetSync(url, headers)
local ok, handle = pcall(http.get, url, headers)
if not ok or not handle then return nil end
local d = handle.readAll(); handle.close(); return d
end

function ntfyCraftDone(label, qty, isFluid)
local topic = Config.ntfy_topic
if not topic or topic == "" then return end
if not (http and http.request) then return end
local url = topic:find("://") and topic or ("https://ntfy.sh/" .. topic)
local short = shortName(label)
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

function ntfyCraftFail(label)
local topic = Config.ntfy_topic
if not topic or topic == "" then return end
if not (http and http.request) then return end
local url = topic:find("://") and topic or ("https://ntfy.sh/" .. topic)
local short = label and (shortName(label)) or "craft"
local body  = "INTERRUPTED: " .. short
local stage = Craft.lastFailStage and shortName(Craft.lastFailStage) or nil
if stage and stage ~= short then body = body .. "\nstage: " .. stage end
if Craft.lastFail then
body = body .. "\nwhy: " .. tostring(Craft.lastFail):sub(1, 200)
end
pcall(function()
http.request({url = url, method = "POST", body = body,
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

function buildStatus()
local ctx = displayCtx
if ctx and (ctx.total or 0) > 0 and not ctx.done then
local sDone  = stageDone or 0
local sTotal = math.max(stageTotal or 0, sDone, 1)
local pct  = math.floor(sDone / sTotal * 100)
local goal = ctx.finalGoal or "?"
goal = shortName(goal)
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
if sysStatus and sysStatus ~= "IDLE" then
local s = "Busy: " .. tostring(sysStatus)
if fluidGoalLabel and fluidGoalLabel ~= "" then
local g = shortName(fluidGoalLabel)
s = s .. "\n" .. g .. " step " .. (fluidStepNum or 0) .. "/" .. math.max(fluidStepNum or 0, fluidStepTotal or 0)
end
return s
end
local q = #(Craft.queue or {})
if q > 0 then return "IDLE. Queue: " .. q .. " waiting." end
return "IDLE. No active craft."
end

function buildQueueTxt()
local q = Craft.queue or {}
if #q == 0 then return "Queue empty." end
local lines = {}
for i = 1, math.min(8, #q) do
local qe = q[i]
local nm = shortName(qe.name)
local unit = (qe.kind == "fluid" and not qe.isItem) and " mB" or "x"
lines[#lines + 1] = i .. ". " .. nm .. " " .. qe.qty .. unit .. (qe.failed and " [FAIL]" or "")
end
if #q > 8 then lines[#lines + 1] = "... +" .. (#q - 8) .. " more" end
return table.concat(lines, "\n")
end

function ntfyPoll()
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
ntfyPublish(buildStatus(), "AEGIS status", "bar_chart")
elseif want == "queue" then
ntfyPublish(buildQueueTxt(), "AEGIS queue", "clipboard")
elseif want == "cancel" then
Craft.cancelled = true
ntfyPublish("Cancel requested.", "AEGIS status", "octagonal_sign")
end
end

function queueRunOne(qe)
if qe.kind == "fluid" then
local fOk, fProduced, fIsItem = fluidCraft(qe.recipe, qe.name, qe.qty)
if fOk then
ntfyCraftDone(qe.name, fProduced, not fIsItem)
lastCraftMade = fProduced
return true
end
ntfyCraftFail(qe.name)
local reason = {}
for li = 1, math.min(4, #craftErrLines) do reason[li] = craftErrLines[li] end
if #reason == 0 then reason[1] = "Fluid craft failed" end
return false, reason
end
local preStock = groupAvail(qe.name, getInv())
Craft.cancelled = false
local plan, missingRes = planProd(qe.name, qe.qty, true)
if plan and #plan == 0 and not next(missingRes or {}) then return true end
if next(missingRes or {}) then
local reason = {}
for mName, mCnt in pairs(missingRes) do
if #reason >= 4 then break end
reason[#reason + 1] = "Need " .. mCnt .. "x " .. (shortName(mName))
end
if #reason == 0 then reason[1] = "Missing components" end
return false, reason
end
local craftOk = false
if plan and #plan > 0 then
craftOk = runCraft(plan)
local tlA = 0
while not Craft.cancelled and tlA < 12 do
local totalNow = groupAvail(qe.name, getInv())
if totalNow >= qe.qty then break end
tlA = tlA + 1
local rPlan = planProd(qe.name, qe.qty, true)
if not (rPlan and #rPlan > 0) then break end
local beforeTL = totalNow
if runCraft(rPlan) then craftOk = true end
if groupAvail(qe.name, getInv()) <= beforeTL then break end
end
end
if craftOk then
lastCraftMade = math.max(0, groupAvail(qe.name, getInv()) - preStock)
ntfyCraftDone(qe.name, lastCraftMade, false)
return true
end
ntfyCraftFail(qe.name)
local reason = {}
if craftErrTitle then reason[#reason + 1] = craftErrTitle end
for li = 1, #craftErrLines do
if #reason >= 4 then break end
reason[#reason + 1] = tostring(craftErrLines[li])
end
for mName, mCnt in pairs(missingRes or {}) do
if #reason >= 4 then break end
reason[#reason + 1] = "Need " .. mCnt .. "x " .. (shortName(mName))
end
if #reason == 0 then reason[1] = "Craft failed" end
return false, reason
end


ntfyLastId = nil
-->70_services/70_0_notify.lua
--<70_services/70_1_git.lua
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
-->70_services/70_1_git.lua
--<70_services/70_2_mgmt.lua
function mgmtMvSlot(srcName, srcSlot, destName, amount)
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

function isFluidPeri(name)
if not name or name == "" or name == "STORAGE" then return false end
if Config.fluid_tanks and Config.fluid_tanks[name] then return true end
local w = peripheral.wrap(name)
if w and w.tanks and not w.list and not w.getItems then return true end
return false
end

function isFluid(g)
if g.fluid ~= nil then return g.fluid end
return isFluidPeri(g.input) or isFluidPeri(g.output)
end

function mgmtMvFluid(srcName, destName, fluidName, amount)
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

function mgmtFSnap()
local snap = {}
for k, v in pairs(getFluid()) do
snap[fluidNameOf(k)] = v
end
return snap
end

function runFluidGroup(group)
local moved = 0
local inputIsStg  = (not group.input  or group.input  == "" or group.input  == "STORAGE")
local outputIsStg = (not group.output or group.output == "" or group.output == "STORAGE")
if inputIsStg and outputIsStg then return 0 end
local fsnap = mgmtFSnap()
local netTanks = fluidTankList()
if group.drain and not inputIsStg then
for fname, amt in pairs(tankContents(group.input)) do
local toMove = amt
if outputIsStg then
for _, tname in ipairs(netTanks) do
if toMove <= 0 then break end
if tname ~= group.input then
local mv = mgmtMvFluid(group.input, tname, fname, toMove)
if mv > 0 then toMove = toMove - mv; moved = moved + mv end
end
end
else
local mv = mgmtMvFluid(group.input, group.output, fname, toMove)
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
for _, src in ipairs(tanksWFluid(rule.item)) do
if needed <= 0 then break end
if src.periph ~= group.output then
local mv = mgmtMvFluid(src.periph, group.output, rule.item, needed)
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
local mv = mgmtMvFluid(group.input, tname, rule.item, needed)
if mv > 0 then
needed = needed - mv
moved  = moved + mv
fsnap[rule.item] = (fsnap[rule.item] or 0) + mv
end
end
end
else
local mv = mgmtMvFluid(group.input, group.output, rule.item, needed)
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

function listIsStorage(lst)
return (#lst == 0) or (lst[1] == "STORAGE")
end

function mgmtIODisp(group, isInput)
local lst = mgmtIOList(group, isInput)
if listIsStorage(lst) then return "STORAGE" end
local d = getMachName(lst[1]) or lst[1]
if #lst > 1 then d = d .. " +" .. (#lst - 1) end
return d
end

function mgmtCntItem(srcNames, itemName)
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

function mgmtMvFrom(srcName, dest, itemName, amount, storageList)
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
local mv = mgmtMvSlot(srcName, sl, sn, want)
if mv > 0 then moved = moved + mv; want = want - mv end
end
else
local mv = mgmtMvSlot(srcName, sl, dest, want)
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
local mv = mgmtMvFrom(inputs[rr.i], dest, itemName,
math.min(amount - moved, chunk), storageList)
if mv > 0 then moved = moved + mv; cycleMoved = cycleMoved + mv end
end
if cycleMoved == 0 then break end
end
return moved
end

function runItemGroup(group, stockSnap, storageList)
local moved   = 0
local inputs  = mgmtIOList(group, true)
local outputs = mgmtIOList(group, false)
local inStg   = listIsStorage(inputs)
local outStg  = listIsStorage(outputs)
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
local mv = mgmtMvSlot(nm, sl, sn, toMove)
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
local mv = mgmtMvSlot(nm, sl, outputs[rr.i], toMove)
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
local cur = mgmtCntItem({ oN }, rule.item)
targets[#targets + 1] = { dest = oN, cur = cur, def = math.max(0, rule.amount - cur) }
end
end
local sumDef = 0
for _, t in ipairs(targets) do sumDef = sumDef + t.def end
if sumDef > 0 then
local avail  = inStg and (stockSnap[rule.item] or 0) or mgmtCntItem(inputs, rule.item)
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

function runMgmtTransfers()
local totalMoved = 0
if sysStatus ~= "IDLE" then
mgmtSyncInfo = "paused (craft)"
return totalMoved
end
if #MgmtGroups == 0 then
mgmtSyncInfo = "no groups"
return totalMoved
end
local stockSnap = getInv()
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
if sysStatus ~= "IDLE" then break end
if group.paused then goto mgmt_continue end
if group.provider then goto mgmt_continue end
if isFluid(group) then
totalMoved = totalMoved + runFluidGroup(group)
goto mgmt_continue
end
totalMoved = totalMoved + runItemGroup(group, stockSnap, storageList)
::mgmt_continue::
end
if totalMoved > 0 then
mgmtSyncInfo = "moved: " .. totalMoved
resetStock()
else
mgmtSyncInfo = "ok (0 moved)"
end
return totalMoved
end


function providerSrc()
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

mgmtItemSrch       = ""
mgmtSearchOn = false
mgmtPage             = 1
mgmtPopup            = nil
custGrpPopup         = nil
mgmtSyncInfo         = ""
mgmtTicks        = 0
mgmtActBtn        = nil
syncFlashTime    = nil
-->70_services/70_2_mgmt.lua
--<70_services/70_3_train.lua
function deliverTrain(itemName, amount)
if not Config.train_box or Config.train_box == "" then return 0 end
local prescan = scanPeriph(scanStorage(), "list")
local moved = 0
for _, targetSlot in ipairs(TRAINBOX_SAFE_SLOTS) do
if moved >= amount then break end
local got = pushFromStore(itemName, amount - moved, Config.train_box, targetSlot, prescan)
moved = moved + got
end
return moved
end

function pullTrainAll()
if not Config.train_box or Config.train_box == "" then return 0 end
local box = peripheral.wrap(Config.train_box)
if not box or not box.list or not box.pushItems then return 0 end
local sortedStore = {}
for sName, enabled in pairs(Config.storages) do
if enabled then
local p = peripheral.wrap(sName)
if p and p.list and p.pullItems then table.insert(sortedStore, sName) end
end
end
table.sort(sortedStore)
if #sortedStore == 0 then return 0 end
local totalMoved = 0
local ok, items = pcall(box.list)
if not ok or not items then return 0 end
for slot, item in pairs(items) do
if item then
local remaining = item.count
for _, stoName in ipairs(sortedStore) do
if remaining <= 0 then break end
local mv_ok, mv = pcall(box.pushItems, stoName, slot, remaining)
if mv_ok and mv and mv > 0 then remaining = remaining - mv; totalMoved = totalMoved + mv end
end
end
end
return totalMoved
end
-->70_services/70_3_train.lua
--<70_services/70_4_autostock.lua
Keep = {}

function Keep.of(name)
return Autostock[name]
end

function Keep.put(name, entry)
Autostock[name] = entry
end

function Keep.remove(name)
Autostock[name] = nil
end

function Keep.all()
return Autostock
end

function userIsBusy()
if curTab == "QUANTITY_PICKER" then return true end
if mgmtPopup or custGrpPopup or fluidRecipePicker or recipeEditPop
or craftInfoPop or machInfoPopup or historyPopup or craftDonePopup
or pendDelItem or pendDelFluid or outPickMode
or gitExportMode or gitImportMode or fluidLearnStage or fluidWaitCraft then
return true
end
return false
end

function runAutostock()
if Config.autostock_paused or sysStatus == "MANUAL_CRAFT" then return end
if userIsBusy() then return end
local stockInv = getInv()
local queue = {}
for itemName, settings in pairs(Keep.all()) do
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
local fname = fluidNameOf(itemName)
local fprods = fluidProducers(fname)
if fprods[1] then
local fcur = (getFluid())[itemName] or 0
if fcur < settings.threshold then
local fneed = settings.target - fcur
if fneed > 0 then
sysStatus = "AUTO_CRAFT"
asItem = itemName
uiMessage = "Autostock fluid: " .. (shortName(fname))
Craft.locks = {}; fluidTankClaims = 0; _fluidBusy = false; fluidInlineByCo = {}
pcall(function() produceFluid(fprods[1].recipe, fname, fneed) end)
sysStatus = "IDLE"
asItem = ""
if checkTimer then os.cancelTimer(checkTimer) end
checkTimer = os.startTimer(2)
if Craft.cancelled then return end
stockInv = getInv()
end
end
end
elseif Recipe.find(itemName) then
local curCount = stockInv[itemName] or 0
if curCount < settings.threshold then
local needed = settings.target - curCount
local plan, planMiss = nil, nil
if needed > 0 then
plan, planMiss = planProd(itemName, needed, false)
end
local isPartial = false
if needed > 0 and (not plan or #plan == 0 or (planMiss and next(planMiss))) then
plan = nil
local partialPlan = planProd(itemName, needed, true)
if partialPlan and #partialPlan > 0 then
plan = partialPlan
isPartial = true
end
end
if plan and #plan > 0 then
sysStatus = "AUTO_CRAFT"
asItem = itemName
local shortName = shortName(itemName)
if isPartial then
uiMessage = "Partial autostock: " .. shortName
else
uiMessage = "Autostocking " .. shortName
end
local ok = false
local craftOk, craftErr = pcall(function()
ok = runCraft(plan)
local kAttempts = 0
while not Craft.cancelled and kAttempts < 12 do
local totalNow = groupAvail(itemName, getInv())
if totalNow >= settings.target then break end
kAttempts = kAttempts + 1
resetStock()
local rPlan = planProd(itemName, settings.target, true)
if not (rPlan and #rPlan > 0) then break end
local beforeK = totalNow
runCraft(rPlan)
if groupAvail(itemName, getInv()) <= beforeK then break end
end
end)
sysStatus = "IDLE"
asItem = ""
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
if Craft.cancelled then return end
stockInv = getInv()
end
end
end
end
end


asItem   = ""
idleTimer              = nil
autostockIdle      = 180
unloadActive  = false
unloadTimer   = nil
checkTimer    = nil
-->70_services/70_4_autostock.lua
--<70_services/70_5_rednet.lua
function openRemote()
for _, nm in ipairs(peripheral.getNames()) do
if peripheral.getType(nm) == "modem" then
local m = peripheral.wrap(nm)
if m and m.isWireless and m.isWireless() then
rednet.open(nm)
return true
end
end
end
return false
end

function runQueueAll()
if #Craft.queue == 0 then return end
sysStatus = "MANUAL_CRAFT"
local qi = 1
while qi <= #Craft.queue do
Craft.cancelled = false
resetErr()
local qe = Craft.queue[qi]
local okQ, reason = queueRunOne(qe)
craftResultId = (craftResultId or 0) + 1
if okQ then
lastResult = { ok = true, name = qe.name, made = lastCraftMade or qe.qty }
table.remove(Craft.queue, qi)
else
lastResult = { ok = false, name = qe.name, err = (reason and reason[1]) or "craft failed", stage = stageDone or 0, total = stageTotal or 0 }
qe.failed = reason
qi = qi + 1
end
if Craft.cancelled then break end
drawUI()
end
sysStatus = "IDLE"
resetErr()
end

function buildRemote()
local snap = { cmd = "remote_snap", busy = sysStatus ~= "IDLE", keepPaused = Config.autostock_paused == true, epoch = stockEpoch or 0 }
local q = {}
for i = 1, #Craft.queue do
q[i] = { name = Craft.queue[i].name, count = Craft.queue[i].qty }
end
snap.queue = q
local ctx = displayCtx
if ctx and (ctx.total or 0) > 0 and not ctx.done then
local sDone = stageDone or 0
local sTotal = math.max(stageTotal or 0, sDone, 1)
snap.job = { name = ctx.finalGoal or "?", done = sDone, total = sTotal, pct = math.floor(sDone / sTotal * 100) }
elseif sysStatus ~= "IDLE" then
if fluidGoalLabel and fluidGoalLabel ~= "" then
local sn = fluidStepNum or 0
local st = math.max(fluidStepNum or 0, fluidStepTotal or 0, 1)
snap.job = { name = fluidGoalLabel, done = sn, total = st, pct = math.floor(sn / st * 100) }
else
local sDone = stageDone or 0
local sTotal = math.max(stageTotal or 0, sDone, 1)
snap.job = { name = "crafting", done = sDone, total = sTotal, pct = math.floor(sDone / sTotal * 100) }
end
end
if snap.busy then snap.note = "crafting" elseif #q > 0 then snap.note = #q .. " queued" else snap.note = "" end
snap.resultId = craftResultId or 0
snap.result = lastResult
return snap
end

function remoteSearch(q)
local out = { cmd = "remote_found", results = {} }
if type(q) ~= "string" or q == "" then return out end
local ql = q:lower()
local names = {}
for itemName in pairs(Recipe.all()) do
local sn = shortName(itemName)
if sn:lower():find(ql, 1, true) then names[#names + 1] = itemName end
end
table.sort(names)
local inv = getInvCached()
local n = 0
for i = 1, #names do
if n >= 50 then break end
n = n + 1
out.results[n] = { name = names[i], have = groupAvail(names[i], inv) }
end
local fset = {}
for _, rec in pairs(Fluids.all()) do
for _, o in ipairs(rec.outputs or {}) do fset[o.name] = true end
end
for _, alts in pairs(Fluids.allAlts()) do
for _, a in ipairs(alts) do
for _, o in ipairs(a.outputs or {}) do fset[o.name] = true end
end
end
local fnames = {}
for fn in pairs(fset) do
local sn = shortName(fn)
if sn:lower():find(ql, 1, true) then fnames[#fnames + 1] = fn end
end
table.sort(fnames)
local finv = getFluidCached()
for i = 1, #fnames do
if n >= 80 then break end
n = n + 1
out.results[n] = { name = fnames[i], fl = true, have = (finv and finv[fluidKey(fnames[i])]) or 0 }
end
return out
end

function remoteMax(name)
if type(name) ~= "string" then return 0 end
if Recipe.find(name) then
local snap = getInvCached()
local snapCraft = {}
for k, v in pairs(snap) do snapCraft[k] = v end
snapCraft[name] = 0
local alts = Groups.altsOf(name)
if alts then
for _, alt in ipairs(alts) do snapCraft[alt] = 0 end
end
local cs = recipesScan[name]
if cs and type(cs.maxCraftable) == "number" and not next(cs.missing or {}) then return cs.maxCraftable end
return maxCraft(name, snapCraft)
end
local prod = fluidProducers(name)
if prod and prod[1] and prod[1].recipe then
local recipe = prod[1].recipe
local fstock = {}
for k, v in pairs(getFluidCached()) do fstock[fluidNameOf(k)] = v end
local istock = getInvCached()
local perOp = 0
for _, o in ipairs(recipe.outputs or {}) do if o.name == name then perOp = o.amount break end end
if perOp <= 0 then
for _, o in ipairs(recipe.item_outputs or {}) do if o.name == name then perOp = o.count break end end
end
local ops = fluidMaxOps(recipe, fstock, istock, {})
return math.min(FLUID_MAX_CAP, ops * (perOp > 0 and perOp or 1))
end
return 0
end

function handleRemote(sid, msg)
local cmd = msg.cmd
if cmd == "rpc" then
local ok, r1, r2 = pcall(aegis.rpc, msg.method, msg.args)
local reply = { cmd = "rpcr", rid = msg.rid }
if not ok then
reply.ok = false; reply.err = tostring(r1)
elseif r1 == nil and type(r2) == "string" then
reply.ok = false; reply.err = r2
else
reply.ok = true; reply.result = r1
end
rednet.send(sid, reply, REMOTE_PROTOCOL)
elseif cmd == "remote_pull" then
rednet.send(sid, aegis.jobs.status(), REMOTE_PROTOCOL)
elseif cmd == "remote_search" then
rednet.send(sid, remoteSearch(msg.q), REMOTE_PROTOCOL)
elseif cmd == "remote_max" then
local mhave = 0
if type(msg.name) == "string" then
if Recipe.find(msg.name) then mhave = aegis.storage.count(msg.name)
else mhave = (aegis.fluids.inventory()[fluidKey(msg.name)]) or 0 end
end
rednet.send(sid, { cmd = "remote_maxr", name = msg.name, max = aegis.craft.max(msg.name), have = mhave }, REMOTE_PROTOCOL)
elseif cmd == "remote_craft" then
if type(msg.name) == "string" then
aegis.craft.start(msg.name, msg.count, { run = msg.now and true or false })
end
rednet.send(sid, aegis.jobs.status(), REMOTE_PROTOCOL)
elseif cmd == "remote_do" then
if msg.id == "cancel" then aegis.jobs.cancel()
elseif msg.id == "runall" then remoteRunFlag = true
elseif msg.id == "keep_on" then Config.autostock_paused = false; saveData()
elseif msg.id == "keep_off" then Config.autostock_paused = true; saveData()
elseif msg.id == "keep_run" then remoteKeepRun = true
elseif msg.id == "qdel" then aegis.jobs.cancel(msg.arg)
end
rednet.send(sid, aegis.jobs.status(), REMOTE_PROTOCOL)
end
end
-->70_services/70_5_rednet.lua
--<80_ui/80_0_toolkit.lua
UI = {}
UI.C = {
bg = colors.black, fg = colors.white, muted = colors.gray, soft = colors.lightGray,
accent = colors.lime, danger = colors.red, warn = colors.orange, info = colors.cyan,
hi = colors.yellow, rowBg = colors.gray,
}
UI.S = {
ok     = {fg = colors.black, bg = colors.lime},
danger = {fg = colors.white, bg = colors.red},
warn   = {fg = colors.black, bg = colors.orange},
cool   = {fg = colors.black, bg = colors.cyan},
mute   = {fg = colors.white, bg = colors.gray},
soft   = {fg = colors.black, bg = colors.lightGray},
tabon  = {fg = colors.black, bg = colors.lime},
taboff = {fg = colors.lightGray, bg = colors.gray},
hi     = {fg = colors.black, bg = colors.yellow},
okhi   = {fg = colors.white, bg = colors.lime},
}

function UI.zone(zones, id, arg, x, y, w1)
zones[#zones + 1] = {id = id, arg = arg, x1 = x, x2 = x + w1 - 1, y = y}
end

function UI.zoneP(zones, id, arg, x, y, w1)
table.insert(zones, 1, {id = id, arg = arg, x1 = x, x2 = x + w1 - 1, y = y})
end

function UI.btn(zones, x, y, label, style, id, arg)
local s = UI.S[style] or UI.S.mute
drawText(x, y, label, s.fg, s.bg)
UI.zone(zones, id, arg, x, y, #label)
return x + #label
end

function UI.btnP(zones, x, y, label, style, id, arg)
local s = UI.S[style] or UI.S.mute
drawText(x, y, label, s.fg, s.bg)
UI.zoneP(zones, id, arg, x, y, #label)
return x + #label
end

function UI.btnR(zones, x2, y, label, style, id, arg)
local x = x2 - #label + 1
UI.btn(zones, x, y, label, style, id, arg)
return x
end

function UI.text(x, y, text, fg, bg)
drawText(x, y, text, fg or UI.C.fg, bg or UI.C.bg)
end

function UI.textC(y, w, text, fg, bg)
local x = math.floor((w - #text) / 2) + 1
drawText(x, y, text, fg or UI.C.fg, bg or UI.C.bg)
end

function UI.rule(y, w, ch, fg)
drawText(1, y, string.rep(ch or "-", w), fg or UI.C.muted)
end

function UI.popup(pW, pH, w, h, hdr, hdrStyle, minY)
local pX = math.max(1, math.floor((w - pW) / 2) + 1)
local pY = math.max(minY or 1, math.floor((h - pH) / 2) + 1)
_bufFillRect(pX, pY, pW, pH, colors.gray)
if hdr and hdr ~= "" then
local s = UI.S[hdrStyle] or UI.S.ok
drawText(pX + math.floor((pW - #hdr) / 2), pY, hdr, s.fg, s.bg)
end
return pX, pY, {x1 = pX, x2 = pX + pW - 1, y1 = pY, y2 = pY + pH - 1}
end

function UI.tabBtn(zones, x, y, label, id, active, arg)
UI.btn(zones, x, y, label, "mute", id, arg)
if active then UI.text(x, y + 1, string.rep("-", #label), UI.C.accent) end
return x + #label
end

function UI.subTabs(zones, y, w, items, active, id)
local total = 0
for i, name in ipairs(items) do total = total + #name + 4 + (i > 1 and 2 or 0) end
local x = math.floor((w - total) / 2) + 1
for _, name in ipairs(items) do
local lbl = " [ " .. name .. " ] "
local isOn = (name == active)
drawText(x, y, lbl, isOn and UI.C.fg or UI.C.muted, isOn and UI.C.rowBg or UI.C.bg)
if isOn then drawText(x, y + 1, string.rep("-", #lbl), UI.C.accent, UI.C.bg) end
UI.zone(zones, id, name, x, y, #lbl)
x = x + #lbl + 2
end
end

function UI.miniPager(zones, y, cx, page, total, prevId, nextId, prepend)
local pgStr = page .. "/" .. total
local prevS, nextS = " [<] ", " [>] "
local navW = #prevS + 1 + #pgStr + 1 + #nextS
local navX = cx - math.floor(navW / 2)
local canP, canN = page > 1, page < total
drawText(navX, y, prevS, canP and UI.C.fg or UI.C.muted, UI.C.rowBg)
drawText(navX + #prevS + 1, y, pgStr, UI.C.accent, UI.C.rowBg)
drawText(navX + #prevS + 1 + #pgStr + 1, y, nextS, canN and UI.C.fg or UI.C.muted, UI.C.rowBg)
local add = prepend and UI.zoneP or UI.zone
if canP then add(zones, prevId, nil, navX, y, #prevS) end
if canN then add(zones, nextId, nil, navX + #prevS + 1 + #pgStr + 1, y, #nextS) end
end

function UI.pager(zones, y, w, page, total, prevId, nextId)
UI.rule(y - 1, w)
local prevStr, nextStr = " [ PREV ] ", " [ NEXT ] "
local pageStr = string.format(" PAGE %d OF %d ", page, math.max(1, total))
local startX = math.floor((w - (#prevStr + #pageStr + #nextStr + 4)) / 2)
local prevFg = page > 1 and UI.C.fg or UI.C.soft
local nextFg = page < total and UI.C.fg or UI.C.soft
drawText(startX, y, prevStr, prevFg, UI.C.rowBg)
drawText(startX + #prevStr + 2, y, pageStr, UI.C.accent, UI.C.bg)
local nextX = startX + #prevStr + #pageStr + 4
drawText(nextX, y, nextStr, nextFg, UI.C.rowBg)
if page > 1 then UI.zone(zones, prevId or "prev_page", nil, startX, y, #prevStr) end
if page < total then UI.zone(zones, nextId or "next_page", nil, nextX, y, #nextStr) end
end


function zebraBg(idx)    return (idx % 2 == 0) and colors.gray or colors.black end
-->80_ui/80_0_toolkit.lua
--<80_ui/80_1_helpers.lua
function timedRead(timeout, initial)
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

function packOrder(name, storages)
local hints = craftPackIndex and craftPackIndex[name]
local free  = craftPackFree
if not hints and not free then return storages end
local first, mid, tail = {}, {}, {}
for _, s in ipairs(storages) do
if hints and hints[s] then first[#first + 1] = s
elseif free and free[s] then mid[#mid + 1] = s
else tail[#tail + 1] = s end
end
for _, s in ipairs(mid)  do first[#first + 1] = s end
for _, s in ipairs(tail) do first[#first + 1] = s end
return first
end

function packRemember(name, chest)
if not craftPackIndex then return end
craftPackIndex[name] = craftPackIndex[name] or {}
craftPackIndex[name][chest] = true
if craftPackFree then craftPackFree[chest] = true end
end

function packForget(name, chest)
if craftPackIndex and craftPackIndex[name] then craftPackIndex[name][chest] = nil end
if craftPackFree then craftPackFree[chest] = nil end
end

function findFreeSpace(names)
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

function blindUnload(tName, names)
local sto = findFreeSpace(names)
if not sto then return false end
for slot = 1, 16 do pcall(sto.pullItems, tName, slot, 64) end
return true
end

function cleanupCraftMachines(activeStore, list)
local cleanList = list or Craft.cleanMachines
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
for _, stoName in ipairs(activeStore) do
if remaining <= 0 then break end
local ok, mv = pcall(p.pushItems, stoName, slot, remaining)
if ok and mv and mv > 0 then remaining = remaining - mv end
end
end
if remaining > 0 then
for _, stoName in ipairs(activeStore) do
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
if not blindUnload(entry.name, activeStore) then
anyStuck = true
end
end
if anyStuck and not stuckSeen[entry.name] then
stuckSeen[entry.name] = true
table.insert(stuckMachines, entry.name)
end
end
end
if not list then Craft.cleanMachines = {} end
if #stuckMachines > 0 then
local shortNames = {}
for _, n in ipairs(stuckMachines) do
local disp = n
if getMachName then disp = getMachName(n) end
table.insert(shortNames, disp)
end
uiMessage = "CANCEL: stuck in " .. table.concat(shortNames, ", ")
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(4)
end
end

drawFluidProg = function(subLabel, current, total, workers)
local co = lockOwnerId()
local ent = fluidInlineByCo[co]
if ent then
local short = shortName(tostring(subLabel))
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
if drawUI then drawUI(true) end
local w, h = monitor.getSize()
local pW, pH = 46, 10
local title = Craft.failed and " MANUFACTURING FAILED " or " MANUFACTURING ACTIVE "
local style = Craft.failed and "danger" or "warn"
local pX, pY = UI.popup(pW, pH, w, h, title, style)
local stepStr = string.format("Step %d/%d", fluidStepNum, math.max(fluidStepNum, fluidStepTotal))
drawText(pX + 2, pY + 2, stepStr, colors.white, colors.gray)
local fStr = "[FLUID]"
drawText(pX + pW - #fStr - 2, pY + 2, fStr, colors.cyan, colors.gray)
if workers and workers > 1 then
local wStr = "[" .. workers .. "x parallel] "
drawText(pX + pW - #fStr - 2 - #wStr, pY + 2, wStr, colors.cyan, colors.gray)
end
local subShort = (shortName(tostring(subLabel)))
local subStr = ("Sub-task: " .. total .. " ops " .. subShort):sub(1, pW - 4)
drawText(pX + 2, pY + 3, subStr, colors.lightGray, colors.gray)
local goal = fluidGoalLabel ~= "" and fluidGoalLabel or subLabel
local cleanGoal = (shortName(tostring(goal))):upper()
local itemStr = (">> " .. cleanGoal .. " <<"):sub(1, pW - 4)
drawText(pX + math.floor((pW - #itemStr) / 2), pY + 5, itemStr, colors.yellow, colors.gray)
local progStr = string.format("Progress: %d / %d", current, total)
drawText(pX + math.floor((pW - #progStr) / 2), pY + 7, progStr, colors.lime, colors.gray)
local barWidth = math.min(28, pW - 14)
local barX = pX + math.floor((pW - barWidth) / 2)
drawProgBar(barX, pY + 8, barWidth, current, total, colors.gray)
local cancelStr = " [ CANCEL ] "
local cancelBtnX = pX + math.floor((pW - #cancelStr) / 2)
local cancelBtnY = pY + pH - 1
drawText(cancelBtnX, cancelBtnY, cancelStr, colors.white, colors.red)
craftCancelY  = cancelBtnY
craftCancelX1 = cancelBtnX
craftCancelX2 = cancelBtnX + #cancelStr - 1
_bufFlush()
end

drawFluidCancel = function()
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

function findFluidProd(fluidName)
local p = fluidProducers(fluidName)[1]
if p then return p.recipe, p.perOp end
return nil
end

function countFluidSteps(fluidName, amount, simStock, visited)
local have = simStock[fluidName] or 0
if have >= amount then simStock[fluidName] = have - amount; return 0 end
local shortfall = amount - have
simStock[fluidName] = 0
if visited[fluidName] then return 0 end
local recipe, perOp = findFluidProd(fluidName)
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

function countTopSteps(recipe, targetName, amount)
local perOp = nil
for _, o in ipairs(recipe.outputs or {}) do if o.name == targetName then perOp = o.amount; break end end
if not perOp then for _, o in ipairs(recipe.item_outputs or {}) do if o.name == targetName then perOp = o.count; break end end end
if not perOp or perOp <= 0 then return 1 end
local ops = math.ceil(amount / perOp)
local simStock = {}
for k, v in pairs(getFluid()) do simStock[fluidNameOf(k)] = v end
local cnt = 0
local visited = {}
for _, inp in ipairs(recipe.inputs or {}) do
cnt = cnt + countFluidSteps(inp.name, ops * inp.amount, simStock, visited)
end
return cnt + 1
end

function estimateStages(plan)
local n = 0
for _, step in ipairs(plan) do
if step.count and step.count > 0 then
if step.fluid_craft then
n = n + countTopSteps(step.fluidRecipe, step.item, step.fluidAmount)
else
n = n + 1
end
end
end
return n
end
FLUID_MAX_CAP = 100000

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
tryAdd(Fluids.find(fk), fk, true, true, nil)
for i, alt in ipairs(Fluids.altsOf(fk) or {}) do tryAdd(alt, fk, true, false, i) end
for key, rec in pairs(Fluids.all()) do
if key ~= fk then tryAdd(rec, key, false, false, nil) end
end
for key, alts in pairs(Fluids.allAlts()) do
if key ~= fk then
for _, alt in ipairs(alts) do tryAdd(alt, key, false, false, nil) end
end
end
_fpCache[fluidName] = out
return out
end

function removeFluidRef(rec)
for key, r in pairs(Fluids.all()) do
if r == rec then
local alts = Fluids.altsOf(key)
if alts and alts[1] then
Fluids.set(key, table.remove(alts, 1))
if #alts == 0 then Fluids.setAlts(key, nil) end
else
Fluids.remove(key)
end
return
end
end
for key, alts in pairs(Fluids.allAlts()) do
for i, r in ipairs(alts) do
if r == rec then
table.remove(alts, i)
if #alts == 0 then Fluids.setAlts(key, nil) end
return
end
end
end
end

_mfcMemo, _mfcStock, _mfcIStock = {}, nil, nil

function fluidMaxOps(recipe, fstock, istock, visited)
local maxOps = math.huge
local tainted = false
for _, inp in ipairs(recipe.inputs or {}) do
local avail, t = maxFluid(inp.name, fstock, istock, visited)
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

maxFluid = function(fluidName, fstock, istock, visited)
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
local ops, t = fluidMaxOps(pr.recipe, fstock, istock, visited)
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
for k, v in pairs(getFluidCached()) do
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
calcCraft(it.name, it.count * fops, st, miss, {}, {}, itemVisited or {}, false)
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
creditByprods(usedP.recipe, fops, stock, nil, fluidName)
end
ITEM_MAX_CAP = 999
_micMemo, _micStock = {}, nil

function maxItem(itemName, istock, fstock, visited)
if _micStock ~= istock then _micMemo = {}; _micStock = istock end
visited = visited or {}
local have = groupAvail(itemName, istock)
calcNodes = calcNodes + 1
if calcBudget > 0 and calcNodes > calcBudget then return have, true end
if visited[itemName] then return have, true end
local cached = _micMemo[itemName]
if cached ~= nil then return cached, false end
local recs = {}
local main = Recipe.find(itemName)
if main then recs[#recs + 1] = main end
for _, a in ipairs(Recipe.altsOf(itemName) or {}) do recs[#recs + 1] = a end
if #recs == 0 then _micMemo[itemName] = have; return have, false end
visited[itemName] = true
local best, tainted = 0, false
for _, rec in ipairs(recs) do
local produced = 0
if rec.type == "fluid" then
local frec, fperOp = findFluidItemProd(itemName)
if frec and fperOp and fperOp > 0 then
local ops, t = fluidMaxOps(frec, fstock or {}, istock, {})
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
local av, t = maxItem(ing, istock, fstock, visited)
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

function scanFluidsNow()
fluidScanResults = {}
local fstock = {}
for k, v in pairs(getFluid()) do fstock[fluidNameOf(k)] = v end
local istock = getInv()
local seen = {}

local function scanRec(rec)
for _, o in ipairs(rec.outputs or {}) do
if not seen[o.name] then
seen[o.name] = true
local total = maxFluid(o.name, fstock, istock, {})
fluidScanResults[o.name] = math.min(9999, math.max(0, total - (fstock[o.name] or 0)))
sleep(0)
end
end
end
for _, rec in pairs(Fluids.all()) do scanRec(rec) end
for _, alts in pairs(Fluids.allAlts()) do
for _, rec in ipairs(alts) do scanRec(rec) end
end
end

ensureItem = function(itemName, count)
if Craft.cancelled then return false, {"Cancelled by user."} end

local function curHave()
local stk = getInvCached()
local h = stk[itemName] or 0
local alts = Groups.altsOf(itemName)
if alts then
for _, alt in ipairs(alts) do h = h + (stk[alt] or 0) end
end
return h
end
local have = curHave()
if have >= count then return true, nil end
resetStock()
have = curHave()
if have >= count then return true, nil end
local co = lockOwnerId()
local myDepth = ensureDepthByCo[co] or 0
if myDepth >= 6 then
return false, {"Recursion too deep: " .. (shortName(itemName))}
end
ensureDepthByCo[co] = myDepth + 1
Craft.depth = Craft.depth + 1
local attempts = 0
local lastMissing = nil
while have < count and not Craft.cancelled do
attempts = attempts + 1
if attempts > 12 then break end
local plan, miss = planProd(itemName, count, true)
lastMissing = miss
if not (plan and #plan > 0) then break end
local before = have
runCraft(plan)
have = curHave()
if have <= before then break end
end
Craft.depth = Craft.depth - 1
ensureDepthByCo[co] = myDepth
if ensureDepthByCo[co] == 0 then ensureDepthByCo[co] = nil end
if have < count then
local sn = shortName(itemName)
local lines = {string.format("Need %dx %s (have %d)", count, sn, have)}
if lastMissing and next(lastMissing) then
local parts = {}
for mName, mCnt in pairs(lastMissing) do
if not (mName == itemName) then
parts[#parts + 1] = string.format("%dx %s", mCnt, shortName(mName))
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

function ensureInputs(recipe, ops)
for _, it in ipairs(recipe.item_inputs or {}) do
local ok, err = ensureItem(it.name, ops * it.count)
if not ok then return false, err end
end
return true, nil
end

function ensureIngs(step, ingsMap)
for ing, perOp in pairs(ingsMap) do
local wantN = (step.tools and step.tools[ing]) and 1 or (perOp * (step.count or 0))
local ok, err = ensureItem(ing, wantN)
if not ok then return false, err, ing end
end
return true
end

function fluidRecShortIn(recipe, ops)
local parts = {}
local fInv = getFluid()
for _, inp in ipairs(recipe.inputs or {}) do
local need = ops * inp.amount
local have = fInv[fluidKey(inp.name)] or 0
if have < need then parts[#parts + 1] = string.format("%d mB %s", need - have, shortName(inp.name)) end
end
local iInv = getInv()
for _, it in ipairs(recipe.item_inputs or {}) do
local need = ops * it.count
local have = iInv[it.name] or 0
local alts = Groups.altsOf(it.name)
if alts then for _, alt in ipairs(alts) do have = have + (iInv[alt] or 0) end end
if have < need then parts[#parts + 1] = string.format("%dx %s", need - have, shortName(it.name)) end
end
return parts
end

function appendMissing(lines, parts)
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

ensureFluid = function(fluidName, amount, visited)
if Craft.cancelled then return false, {"Cancelled by user."} end
local have = (getFluidCached())[fluidKey(fluidName)] or 0
if have >= amount then return true, nil end
resetStock()
have = (getFluidCached())[fluidKey(fluidName)] or 0
if have >= amount then return true, nil end
if visited[fluidName] then
local sn = shortName(fluidName)
return false, {"Recursion cycle on " .. sn}
end
local prods = fluidProducers(fluidName)
if #prods == 0 then
local sn = shortName(fluidName)
return false, {string.format("Need %d mB %s, have %d (no recipe)", amount, sn, have)}
end
visited[fluidName] = true
local attempts = 0
while have < amount do
if Craft.cancelled then visited[fluidName] = nil; return false, {"Cancelled by user."} end
attempts = attempts + 1
if attempts > 8 then
visited[fluidName] = nil
local sn = shortName(fluidName)
local lines = {string.format("Need %d mB %s, made only %d", amount, sn, have)}
local p0 = prods[1]
if p0 then appendMissing(lines, fluidRecShortIn(p0.recipe, math.ceil((amount - have) / p0.perOp))) end
return false, lines
end
local shortfall = amount - have
local fstock = {}
for k, v in pairs(getFluidCached()) do fstock[fluidNameOf(k)] = v end
local istock = getInvCached()
local chosen, chosenOps
for _, p in ipairs(prods) do
local ops = math.ceil(shortfall / p.perOp)
if fluidMaxOps(p.recipe, fstock, istock, {}) >= ops then
chosen = p; chosenOps = ops; break
end
end
if not chosen then chosen = prods[1]; chosenOps = math.ceil(shortfall / prods[1].perOp) end
local recipe, ops = chosen.recipe, chosenOps
for _, inp in ipairs(recipe.inputs or {}) do
local ok, err = ensureFluid(inp.name, ops * inp.amount, visited)
if not ok then visited[fluidName] = nil; return false, err end
end
local okItems, itemErr = ensureInputs(recipe, ops)
if not okItems then visited[fluidName] = nil; return false, itemErr end
local okRun, errRun = runFluidCraft({recipe = recipe, ops = ops, perOp = chosen.perOp, label = fluidName})
if not okRun then visited[fluidName] = nil; return false, errRun end
resetStock()
local newHave = (getFluid())[fluidKey(fluidName)] or 0
if newHave <= have then
visited[fluidName] = nil
local sn = shortName(fluidName)
local lines = {string.format("Need %d mB %s, stuck at %d", amount, sn, newHave)}
appendMissing(lines, fluidRecShortIn(recipe, ops))
return false, lines
end
have = newHave
end
visited[fluidName] = nil
return true, nil
end

function produceFluid(recipe, targetName, amount)
if Craft.cancelled then return false, {"Cancelled by user."}, 0 end
local prods = fluidProducers(targetName)
if #prods > 1 then
local fstock = {}
for k, v in pairs(getFluidCached()) do fstock[fluidNameOf(k)] = v end
local istock = getInvCached()
for _, p in ipairs(prods) do
local ops = math.ceil(amount / p.perOp)
if fluidMaxOps(p.recipe, fstock, istock, {}) >= ops then
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
local ok, err = ensureFluid(inp.name, ops * inp.amount, visited)
if not ok then return false, err, 0 end
end
local okItems, itemErr = ensureInputs(recipe, ops)
if not okItems then return false, itemErr, 0 end
return runFluidCraft({recipe = recipe, ops = ops, perOp = perOp, label = targetName})
end

function fluidCraft(recipe, targetName, amount)
local isItem = false
for _, o in ipairs(recipe.item_outputs or {}) do
if o.name == targetName then isItem = true; break end
end
fluidGoalLabel = targetName
fluidStepNum = 0
fluidStepTotal = countTopSteps(recipe, targetName, amount)
sysStatus = "AUTO_CRAFT"
fluidCraftMsg = "Crafting..."
Craft.cancelled = false
Craft.locks = {}; fluidTankClaims = 0; _fluidBusy = false; fluidInlineByCo = {}
drawUI()
local okRun, runErr, produced = produceFluid(recipe, targetName, amount)
sysStatus = "IDLE"
fluidCraftMsg = ""
Craft.cancelled = false
if okRun then
local prod = {{name = targetName, amount = produced, unit = isItem and "x" or "mB"}}
craftDonePopup = {outputs = prod, timer = os.startTimer(10)}
else
craftErrTitle = "! CANNOT CRAFT"
craftErrLines = runErr or {"Unknown error"}
end
return okRun, produced, isItem
end

function fluidCraftFlow(recipe, targetName)
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
isSettingKeep = false
qtyOrigTab = "RECIPES"
pickerCapped = false
pickerCraftable = 0
pickerMaxSet = false
if Config.autoMaxCalc ~= false then pickerMax() end
curTab = "QUANTITY_PICKER"
end

function pickerMax()
pickerCraftable = 0
pickerCapped = false
if fluidCraftMode and fluidCraftMode.recipe then
local recipe       = fluidCraftMode.recipe
local targetName   = fluidCraftMode.target
local isItemTarget = fluidCraftMode.isItem
local fstock = {}
for k, v in pairs(getFluid()) do fstock[fluidNameOf(k)] = v end
local istock = getInv()
local perOp = 1
if isItemTarget then
for _, o in ipairs(recipe.item_outputs or {}) do if o.name == targetName then perOp = o.count; break end end
else
for _, o in ipairs(recipe.outputs or {}) do if o.name == targetName then perOp = o.amount; break end end
end
local ops = fluidMaxOps(recipe, fstock, istock, {})
pickerCraftable = math.min(FLUID_MAX_CAP, ops * (perOp > 0 and perOp or 1))
else
local target = itemToCraft
local snap = getInv()
local snapCraft = {}
for k, v in pairs(snap) do snapCraft[k] = v end
snapCraft[target] = 0
local alts = Groups.altsOf(target)
if alts then
for _, alt in ipairs(alts) do snapCraft[alt] = 0 end
end
local cs = recipesScan[target]
if cs and type(cs.maxCraftable) == "number" and not next(cs.missing or {}) then
pickerCraftable = cs.maxCraftable
else
pickerCraftable = maxCraft(target, snapCraft)
end
end
pickerMaxSet = true
end
-->80_ui/80_1_helpers.lua
--<80_ui/80_2_learn.lua
TRAINBOX_CRAFT_SLOTS = {[4]=true,[5]=true,[6]=true,[13]=true,[14]=true,[15]=true,[22]=true,[23]=true,[24]=true}
TRAINBOX_SAFE_SLOTS  = {}
for s = 1, 27 do if not TRAINBOX_CRAFT_SLOTS[s] then table.insert(TRAINBOX_SAFE_SLOTS, s) end end

function clearFluidDevs()
learnOut = nil; fluidOutPick = false
learnItemIn = nil; fluidItemInPick = false
learnFluidIn = nil; fluidInPick = false
learnItemOut = nil; itemOutPick = false
end

function drawFluidLearn(w, h, touchZones)
local sumY = 12
if #learnInputs > 0 then
local parts = {}
for _, inp in ipairs(learnInputs) do
local sn = shortName(inp.name)
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
for _, inp in ipairs(learnInputs) do selAmt[inp.name] = inp.amount end
local inv = getFluid()
local avail = {}
for fk, amt in pairs(inv) do
avail[#avail + 1] = {name = fluidNameOf(fk), mb = amt}
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
local short = shortName(f.name)
if fluidWaitInput == f.name then
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
local machines = listMachines()
table.sort(machines, _cmpByDisplay)
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
local isSel = (learnMach == m)
local rroles = {}
if learnItemIn  == m then rroles[#rroles + 1] = "II" end
if learnFluidIn == m then rroles[#rroles + 1] = "FI" end
if learnItemOut == m then rroles[#rroles + 1] = "IO" end
if learnOut  == m then rroles[#rroles + 1] = "FO" end
local rtag, rcol
if #rroles == 1 then
rtag = rroles[1] .. ":"
rcol = (rroles[1] == "II" and colors.cyan)
or (rroles[1] == "FI" and colors.lightBlue)
or (rroles[1] == "IO" and colors.orange)
or colors.lime
elseif #rroles > 1 then
rtag = table.concat(rroles, "/") .. ":"
rcol = colors.magenta
end
if rtag then
local nm = (isSel and ">" or "") .. (getMachName(m) or m)
local maxName = colW - #rtag - 1
if #nm > maxName then nm = nm:sub(1, maxName) end
drawText(colX, rowY, rtag, colors.black, rcol)
drawText(colX + #rtag, rowY, nm, colors.white, colors.gray)
else
local label = (isSel and "> " or "") .. (getMachName(m) or m)
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
elseif learnMach then
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
local af, ab = devCol(fluidInPick, learnFluidIn ~= nil)
drawText(flOutX, h-2, flInS, af, ab)
table.insert(touchZones, {id="fluid_fluidin_toggle", x1=flOutX, x2=flOutX+#flInS-1, y=h-2})
local bf, bb = devCol(fluidItemInPick, learnItemIn ~= nil)
drawText(itOutX, h-2, itInS, bf, bb)
table.insert(touchZones, {id="fluid_iteminput_toggle", x1=itOutX, x2=itOutX+#itInS-1, y=h-2})
local cf, cb = devCol(fluidOutPick, learnOut ~= nil)
drawText(flOutX, h-1, flOutS, cf, cb)
table.insert(touchZones, {id="fluid_pull_toggle", x1=flOutX, x2=flOutX+#flOutS-1, y=h-1})
local df, db = devCol(itemOutPick, learnItemOut ~= nil)
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

function runMachineSearch()
if not Config.train_box or Config.train_box == "" then
return "ERR: Assign Train Box in NETWORK!"
end
local trainBox = peripheral.wrap(Config.train_box)
if not trainBox or not trainBox.getItemDetail then
return "ERR: Train box offline!"
end
local barrelCenter = {4, 5, 6, 13, 14, 15, 22, 23, 24}
local ingredients = {}
local ingCnts = {}
local hasItems = false
local sampleItemName = "Unknown Item"
for i = 1, 9 do
local sourceSlot = barrelCenter[i]
local success, item = pcall(function() return trainBox.getItemDetail(sourceSlot) end)
if success and item then
ingredients[i] = item.name
ingCnts[i] = item.count or 1
hasItems = true
sampleItemName = item.name
else
ingredients[i] = "nil"
ingCnts[i] = 0
end
end
if not hasItems then return "ERR: Grid empty!" end
learnedResult = nil
learnedOutputs = nil
learnedTools = {}
if selCraftType == "turtle" then
learnedIngs = ingredients
else
local flatIng = {}
for i = 1, 9 do
if ingredients[i] ~= "nil" then
local cnt = ingCnts[i] or 1
for _ = 1, cnt do
flatIng[#flatIng + 1] = ingredients[i]
end
end
end
if #flatIng == 0 then flatIng[1] = "nil" end
learnedIngs = flatIng
end

local function drawTest(stageDesc, curProg, maxProgress)
local w, h = monitor.getSize()
local pW, pH = math.min(w - 6, 56), 11
local pX, pY = UI.popup(pW, pH, w, h, " RECIPE INTERACTIVE LEARNING ", "warn")
UI.text(pX + 1, pY + 1, string.rep("-", pW - 2), UI.C.soft, UI.C.rowBg)
local sName = shortName(sampleItemName)
drawText(pX + 2, pY + 3, ("Testing: " .. sName):sub(1, pW - 4), colors.yellow, colors.gray)
drawText(pX + 2, pY + 5, ("STATUS: " .. stageDesc):sub(1, pW - 4), colors.lightGray, colors.gray)
if maxProgress and maxProgress > 0 then
drawProgBar(pX + 2, pY + 7, pW - 10, curProg, maxProgress, colors.gray)
end
local cancStr = " [ CANCEL ] "
local cancX = pX + math.floor((pW - #cancStr) / 2)
drawText(cancX, pY + pH - 2, cancStr, colors.white, colors.red)
craftCancelY  = pY + pH - 2
craftCancelX1 = cancX
craftCancelX2 = cancX + #cancStr - 1
_bufFlush()
end
Craft.cancelled = false

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
if selCraftType == "turtle" then
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
learnedMach = firstTurtle
learnedType = "turtle"
learnedOut = nil
drawTest("Clearing worker grid...", 1, 4)
local turtleSlots = {1, 2, 3, 5, 6, 7, 9, 10, 11}
for slot = 1, 16 do pcall(function() trainBox.pullItems(firstTurtle, slot, 64) end) end
drawTest("Pushing test ingredients...", 2, 4)
local pushedAny = false
for i = 1, 9 do
if ingredients[i] ~= "nil" then
local okP, mvP = pcall(function() return trainBox.pushItems(firstTurtle, barrelCenter[i], 1, turtleSlots[i]) end)
if okP and type(mvP) == "number" and mvP > 0 then pushedAny = true end
end
end
if not pushedAny then
dumpToBarrel(peripheral.wrap(firstTurtle), firstTurtle)
return "ERR: Cannot push items to " .. firstTurtle
end
drawTest("Awaiting turtle processing...", 3, 4)
while true do
drawTest("Awaiting turtle (cancel to abort)...")
sleepCancel(0.4)
if Craft.cancelled then
for slot = 1, 16 do pcall(function() trainBox.pullItems(firstTurtle, slot, 64) end) end
craftCancelY = nil
learnState = "IDLE"
return "Learning cancelled."
end
local moved = 0
local targetSlot = nil
for _, bSlot in ipairs(TRAINBOX_SAFE_SLOTS) do
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
for _, bSlot in ipairs(TRAINBOX_SAFE_SLOTS) do
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
drawTest("Analyzing output data...")
else
learnedMach = selCraftType
learnedType = "machine"
learnedOut = nil
if selOut and selOut ~= selCraftType then
learnedOut = selOut
end
local machObj = peripheral.wrap(learnedMach)
if not machObj or not machObj.list then return "ERR: Machine offline!" end
local outputObj = machObj
if learnedOut then
local oo = peripheral.wrap(learnedOut)
if not oo or not oo.list then return "ERR: Output device offline!" end
outputObj = oo
end
drawTest("Scanning machine state...", 1, 3)
local learnExcluded = {}
local sPre, preItems = pcall(machObj.list)
if sPre and preItems then
for _, preItem in pairs(preItems) do
if preItem then learnExcluded[preItem.name] = true end
end
end
if learnedOut then
local sPreO, preItemsO = pcall(outputObj.list)
if sPreO and preItemsO then
for _, preItem in pairs(preItemsO) do
if preItem then learnExcluded[preItem.name] = true end
end
end
end
local learnMachSize = 9
if machObj.size then
local okSz, sz = pcall(machObj.size)
if okSz and type(sz) == "number" then learnMachSize = sz end
end
for i = 1, 9 do
if ingredients[i] ~= "nil" then
learnExcluded[ingredients[i]] = true
local fromSlot = barrelCenter[i]
local needCount = ingCnts[i] or 1
local pushed = false
if machObj.pullItems then
for mSlot = learnMachSize, 1, -1 do
local ok1, mv1 = pcall(machObj.pullItems, Config.train_box, fromSlot, needCount, mSlot)
if ok1 and type(mv1) == "number" and mv1 > 0 then
pushed = true
break
end
end
end
if not pushed then
pcall(trainBox.pushItems, learnedMach, fromSlot, needCount)
end
end
end
local prevSig, stableCount = nil, 0
while true do
drawTest("Waiting for output (cancel to abort)...")
sleepCancel(0.5)
if Craft.cancelled then break end
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
if Craft.cancelled then
dumpToBarrel(machObj, learnedMach)
if outputObj ~= machObj then dumpToBarrel(outputObj, learnedOut) end
craftCancelY = nil
learnState = "IDLE"
return "Learning cancelled."
end
drawTest("Collecting outputs...")
local outAgg = {}
local sFin, mFin = pcall(outputObj.list)
if sFin and mFin then
for slot, mItem in pairs(mFin) do
if mItem and not learnExcluded[mItem.name] then
outAgg[mItem.name] = (outAgg[mItem.name] or 0) + (mItem.count or 0)
for _, bSlot in ipairs(TRAINBOX_SAFE_SLOTS) do
local ok2, mv2 = pcall(function() return outputObj.pushItems(Config.train_box, slot, mItem.count, bSlot) end)
if ok2 and mv2 and mv2 > 0 then break end
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
learnState = "AWAITING_DECISION"
local hItem = learnedResult.name
for hi = #craftHistory, 1, -1 do
if craftHistory[hi].item == hItem then table.remove(craftHistory, hi) end
end
table.insert(craftHistory, 1, {item = hItem, qty = learnedResult.count or 1})
if #craftHistory > 30 then table.remove(craftHistory) end
return "Success! Confirm entry."
else
learnState = "IDLE"
return "ERR: Process failed!"
end
end
-->80_ui/80_2_learn.lua
--<80_ui/80_2_learn_crafter.lua
learnedGridCells = nil

local function crafterLearnPopup(stage, noCancel)
local w, h = monitor.getSize()
local pW, pH = math.min(w - 6, 56), 9
local pX, pY = UI.popup(pW, pH, w, h, " CRAFTER LEARNING ", "warn")
drawText(pX + 2, pY + 3, ("STATUS: " .. stage):sub(1, pW - 4), colors.lightGray, colors.gray)
if noCancel then
craftCancelY = nil
_bufFlush()
return
end
local cancStr = " [ CANCEL ] "
local cancX = pX + math.floor((pW - #cancStr) / 2)
drawText(cancX, pY + pH - 2, cancStr, colors.white, colors.red)
craftCancelY  = pY + pH - 2
craftCancelX1 = cancX
craftCancelX2 = cancX + #cancStr - 1
_bufFlush()
end

local function toTrainOrVault(got)
local c = crafterCfg()
local o = peripheral.wrap(c.out)
if not (o and o.pushItems) then return end
for slot, it in pairs(crafterOutList()) do
if it then
local moved = 0
if Config.train_box and Config.train_box ~= "" then
for _, bSlot in ipairs(TRAINBOX_SAFE_SLOTS) do
local ok, mv = pcall(o.pushItems, Config.train_box, slot, it.count, bSlot)
if ok and type(mv) == "number" then moved = moved + mv end
if moved >= it.count then break end
end
end
if moved < it.count then
for _, s in ipairs(pushStoList()) do
local ok, mv = pcall(o.pushItems, s, slot, it.count - moved)
if ok and type(mv) == "number" then moved = moved + mv end
if moved >= it.count then break end
end
end
end
end
resetStock()
end

function runCrafterSearch()
local ok, why = crafterReady()
if not ok then return "ERR: crafter " .. tostring(why) end
local ings, rErr = crafterReadCells()
if not ings then return "ERR: " .. tostring(rErr) end
local any = false
for _, v in ipairs(ings) do if v ~= "nil" then any = true; break end end
if not any then return "ERR: Crafter grid empty!" end

Craft.cancelled = false
learnedResult, learnedOutputs, learnedTools = nil, nil, {}
crafterLearnPopup("Clearing crafter output...")
crafterDrainOut(pushStoList())
if next(crafterOutList()) then
return "ERR: crafter output not empty (vaults full?)"
end

crafterLearnPopup("Starting crafters...", true)
local started, sErr = crafterStart(ings, true)
if not started then
pcall(crafterSetLock, true); craftCancelY = nil
if sErr then return "ERR: " .. tostring(sErr) end
return "ERR: crafters didn't start (empty cells need PULSE)"
end

local t, prevSig, stable, agg = 0, nil, 0, nil
while t < CRAFTER_TIMEOUT do
crafterLearnPopup(string.format("Waiting for result... %ds", math.floor(t)))
sleepCancel(0.5)
t = t + 0.5
if Craft.cancelled then break end
local cur, sig = {}, {}
for _, it in pairs(crafterOutList()) do
if it then
cur[it.name] = (cur[it.name] or 0) + (it.count or 0)
sig[#sig + 1] = it.name .. "=" .. (it.count or 0)
end
end
table.sort(sig)
local s = table.concat(sig, ",")
if s ~= "" and s == prevSig then stable = stable + 1 else stable = 0 end
prevSig = s
if stable >= 2 then agg = cur; break end
end
craftCancelY = nil
if Craft.cancelled then
return "Learning cancelled. Result lands in crafter output."
end
if not agg then
pcall(crafterSetLock, true)
return "ERR: no result (invalid recipe? items dropped at crafters)"
end

local name, cnt = crafterPickResult(agg)
toTrainOrVault(agg)
pcall(crafterSetLock, true)

learnedIngs      = ings
learnedGridCells = {}
for i, n in ipairs(crafterCfg().cells) do learnedGridCells[i] = n end
learnedType   = "crafter"
learnedMach   = CRAFTER_MACHINE
learnedOut    = nil
learnedResult = {name = name, count = cnt}
learnState    = "AWAITING_DECISION"
for hi = #craftHistory, 1, -1 do
if craftHistory[hi].item == name then table.remove(craftHistory, hi) end
end
table.insert(craftHistory, 1, {item = name, qty = cnt or 1})
if #craftHistory > 30 then table.remove(craftHistory) end
return "Success! Confirm entry."
end

function drawCrafterLearn(w, h, touchZones)
local c = crafterCfg()
local y = 13
local nOn = 0
for _, n in ipairs(c.cells) do if peripheral.wrap(n) then nOn = nOn + 1 end end
local found = #detectCrafters()
local gridCol = (#c.cells > 0 and nOn == #c.cells) and UI.C.accent or UI.C.danger
UI.text(2, y, string.format("Grid:   %d crafters registered (%d online, %d on network)",
#c.cells, nOn, found), gridCol)
UI.btnR(touchZones, w - 1, y, " [DETECT GRID] ", found ~= #c.cells and "warn" or "mute", "crafter_detect")

local function devLine(yy, label, name, side)
local on = name and peripheral.wrap(name)
local txt = name and (getMachName(name) .. (side and (" @" .. side) or "")) or "<not set - tag in NETWORK>"
UI.text(2, yy, label, UI.C.muted)
UI.text(10, yy, txt:sub(1, w - 12), name and (on and UI.C.fg or UI.C.danger) or UI.C.danger)
end
devLine(y + 1, "Clutch:", c.clutch, c.clutch_side)
devLine(y + 2, "Pulse:",  c.pulse,  c.pulse_side)
if not c.pulse then UI.text(10, y + 2, "<optional - needed for recipes with empty cells>", UI.C.muted) end
devLine(y + 3, "Output:", c.out)

local lk = crafterLocked()
local lkS, lkStyle = " [ NO RELAY ] ", "mute"
if lk == true then lkS, lkStyle = " [ LOCKED - place recipe ] ", "warn"
elseif lk == false then lkS, lkStyle = " [ RUNNING - tap to LOCK ] ", "ok" end
UI.btn(touchZones, math.floor((w - #lkS) / 2) + 1, y + 5, lkS, lkStyle, "crafter_lock_toggle")

local job = crafterJobLoad()
local fS = " [ FINISH GRID ] "
local cS = " [ FORGET ] "
local msg = job and ("Unfinished cycle: " .. shortName(job.item) .. "  ") or "Grid left part-loaded?  "
local rowW = #msg + #fS + (job and (1 + #cS) or 0)
local x0 = math.max(2, math.floor((w - rowW) / 2) + 1)
UI.text(x0, y + 6, msg, job and UI.C.hi or UI.C.muted)
UI.btn(touchZones, x0 + #msg, y + 6, fS, job and "warn" or "mute", "crafter_finish")
if job then UI.btn(touchZones, x0 + #msg + #fS + 1, y + 6, cS, "mute", "crafter_forget") end

UI.textC(y + 7, w, "LOCK, place the recipe into the crafters, then SCAN.", UI.C.muted)
UI.textC(y + 8, w, "Crafter inputs must NOT be wrench-connected.", UI.C.soft)
end

function runCrafterFinish()
local ok, why = crafterReady()
if not ok then return "ERR: crafter " .. tostring(why) end
local cur, rErr = crafterReadCells()
if not cur then return "ERR: " .. tostring(rErr) end
if crafterGridEmpty(cur) then
crafterJobClear()
return "Grid is already empty."
end
local tgt, tErr = crafterResidueTarget(cur)
if not tgt then return "ERR: " .. tostring(tErr) end
Craft.cancelled = false
crafterSetLock(true)
crafterDrainOut(pushStoList())
local function tick() crafterLearnPopup("Finishing " .. shortName(tgt.item) .. " (can't be cancelled)...", true) end
tick()
local okC, err, got, short = crafterRunCycle(tgt, cur, pushStoList(), scanStorage(), tick)
craftCancelY = nil
pcall(crafterSetLock, true)
if okC then
return "Finished: " .. ((got and got[tgt.item]) or 0) .. "x " .. shortName(tgt.item) .. " -> vaults"
end
if short then
local parts = {}
for ing, n in pairs(short) do parts[#parts + 1] = n .. "x " .. shortName(ing) end
table.sort(parts)
return "ERR: need " .. table.concat(parts, ", ")
end
return "ERR: " .. tostring(err and err.lines and err.lines[1] or "cycle failed")
end
-->80_ui/80_2_learn_crafter.lua
--<80_ui/80_3_screens_tabs.lua

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
-->80_ui/80_3_screens_tabs.lua
--<80_ui/80_4_screens_popups.lua
function drawCondRow(pX, pW, ry, rule, ri, touchZones)
local cond = rule.condition
_bufFillRect(pX + 1, ry, pW - 2, 1, colors.lightGray)
if not (cond and cond.item and cond.item ~= "") then
drawText(pX + 2, ry, "[+IF]", colors.gray, colors.lightGray)
drawText(pX + 8, ry, "add condition", colors.gray, colors.lightGray)
UI.zone(touchZones, "mgmt_rule_if_add", ri, pX + 2, ry, 5)
return
end
local opStr = "[" .. (cond.op or "<") .. "]"
local cVal  = tostring(cond.value or 1)
local delX  = pX + pW - 7
local typX  = delX - 5
local plusX = typX - 5
local valX  = plusX - #cVal
local minX  = valX - 5
local opX   = minX - #opStr - 2
local nameX = pX + 5
drawText(pX + 2, ry, "IF ", colors.orange, colors.lightGray)
drawText(nameX, ry, shortName(cond.item):sub(1, math.max(0, opX - nameX)), colors.lime, colors.lightGray)
drawText(opX,   ry, " " .. opStr .. " ", colors.black, colors.yellow)
drawText(minX,  ry, " [-] ", colors.white, colors.lightGray)
drawText(valX,  ry, cVal, colors.yellow, colors.lightGray)
drawText(plusX, ry, " [+] ", colors.white, colors.lightGray)
drawText(typX,  ry, " [#] ", colors.black, colors.orange)
drawText(delX,  ry, " [X] ", colors.white, colors.red)
UI.zone(touchZones, "mgmt_rule_if_item", ri,        nameX, ry, opX - nameX)
UI.zone(touchZones, "mgmt_rule_if_op",   ri,        opX,   ry, #opStr + 2)
UI.zone(touchZones, "mgmt_rule_if_adj",  {ri, -1},  minX,  ry, 5)
UI.zone(touchZones, "mgmt_rule_if_adj",  {ri,  1},  plusX, ry, 5)
UI.zone(touchZones, "mgmt_rule_if_type", ri,        typX,  ry, 5)
UI.zone(touchZones, "mgmt_rule_if_del",  ri,        delX,  ry, 5)
end


function _drawGitPopup(w, h, touchZones, ctx)
local pW     = math.min(56, w - 4)
local maxVis = math.min(ctx.maxV, math.max(1, h - 17 + (ctx.extraHdr == 2 and 1 or 0)))
local totLP  = math.max(1, math.ceil(#ctx.list / maxVis))
local page   = ctx.page
if page > totLP then page = totLP end
local hasNav = totLP > 1
local pH = math.min(ctx.extraHdr + maxVis + (hasNav and 1 or 0) + 1, h - 10)
local pX, pY = UI.popup(pW, pH, w, h, ctx.hdr, ctx.hdrStyle, 9)
local listY = pY + 2
if ctx.newRow then
local isNew = (ctx.sel == 0)
drawText(pX + 2, listY, (isNew and "> " or "  ") .. ctx.newRow,
isNew and colors.black or colors.lime, isNew and colors.lime or colors.gray)
UI.zoneP(touchZones, ctx.selectId, 0, pX + 2, listY, pW - 4)
listY = listY + 1
end
local iStart = (page - 1) * maxVis + 1
local iEnd   = math.min(iStart + maxVis - 1, #ctx.list)
for i = iStart, iEnd do
local isSel = (i == ctx.sel)
local selBg = ctx.selStyle == "warn" and colors.orange or colors.lime
drawText(pX + 2, listY, ((isSel and "> " or "  ") .. ctx.list[i].name):sub(1, pW - 4),
isSel and colors.black or colors.white, isSel and selBg or colors.gray)
UI.zoneP(touchZones, ctx.selectId, i, pX + 2, listY, pW - 4)
listY = listY + 1
end
if hasNav then
UI.miniPager(touchZones, pY + pH - 2, pX + math.floor(pW / 2), page, totLP, ctx.prevId, ctx.nextId, true)
end
local btnY = pY + pH - 1
UI.btnP(touchZones, pX + 2, btnY, ctx.confirmS, "ok", ctx.confirmId)
UI.btnP(touchZones, pX + pW - #ctx.cancelS - 2, btnY, ctx.cancelS, "mute", ctx.cancelId)
return page
end


function drawRecipeEdit(w, h, touchZones, popupRect)
local rec
if recipeEditPop.fluid then
rec = recipeEditPop.fluidRecipeRef
elseif recipeEditPop.altIdx then
local alts = Recipe.altsOf(recipeEditPop.item)
rec = alts and alts[recipeEditPop.altIdx]
else
rec = Recipe.find(recipeEditPop.item)
end
if not rec then
recipeEditPop = nil
return popupRect
end
local sName = shortName(recipeEditPop.fluid or recipeEditPop.item)
local allM = {}
for tName, enabled in pairs(Config.turtles or {}) do
if enabled then allM[#allM + 1] = tName end
end
table.sort(allM)
local mList = listMachines()
table.sort(mList, _cmpByDisplay)
for _, m in ipairs(mList) do allM[#allM + 1] = m end
local pW = math.min(w - 10, 76)
local pH = math.min(h - 4, 19)
local cols = 3
local cw = math.floor((pW - 2) / cols)
local maxRows = pH - 7
local perPage = cols * maxRows
local pages = math.max(1, math.ceil(#allM / perPage))
local page  = recipeEditPop.page or 1
if page > pages then page = pages; recipeEditPop.page = page end
local pX, pY, rect = UI.popup(pW, pH, w, h, " EDIT RECIPE: " .. sName:upper():sub(1, pW - 16) .. " ", "warn")
popupRect = rect
local curM = rec.machine_name or "?"
UI.text(pX + 2, pY + 2, "Current: " .. getMachName(curM), UI.C.fg, UI.C.rowBg)
if recipeEditPop.confirmGlobal then
local n = 0
if recipeEditPop.isItemScope then
local iRec = Recipe.find(recipeEditPop.item)
if iRec and iRec.machine_name == curM then n = n + 1 end
for _, alt in ipairs(Recipe.altsOf(recipeEditPop.item) or {}) do
if alt.machine_name == curM then n = n + 1 end
end
else
for _, rData in pairs(Recipe.all()) do
if rData.machine_name == curM then n = n + 1 end
end
end
local scopeLbl = recipeEditPop.isItemScope and "This item only:" or "Replace ALL:"
local newDisp  = getMachName(recipeEditPop.selected or curM)
UI.text(pX + 2, pY + 4, scopeLbl .. " " .. getMachName(curM), UI.C.hi, UI.C.rowBg)
UI.text(pX + 2, pY + 5, "       -> " .. newDisp, UI.C.accent, UI.C.rowBg)
UI.text(pX + 2, pY + 6, "Affects " .. n .. " recipes!", UI.C.danger, UI.C.rowBg)
local cfmStr, cnlStr = " [ CONFIRM REPLACE ALL ] ", " [ CANCEL ] "
UI.btnP(touchZones, pX + math.floor((pW - #cfmStr) / 2), pY + pH - 3, cfmStr, "danger", "recipe_edit_confirm_global")
UI.btnP(touchZones, pX + math.floor((pW - #cnlStr) / 2), pY + pH - 1, cnlStr, "mute", "close_recipe_edit")
return popupRect
end
UI.text(pX + 2, pY + 3, "Select machine:", UI.C.soft, UI.C.rowBg)
local listTop = pY + 4
for ci = 1, cols - 1 do
local sepX = pX + 1 + ci * cw
for ry = 0, maxRows - 1 do
UI.text(sepX, listTop + ry, "|", UI.C.soft, UI.C.rowBg)
end
end
local mStart = (page - 1) * perPage + 1
local mEnd   = math.min(mStart + perPage - 1, #allM)
for i = mStart, mEnd do
local li = i - mStart
local cellX = pX + 2 + math.floor(li / maxRows) * cw
local cellY = listTop + (li % maxRows)
local nm    = allM[i]
local disp  = getMachName(nm)
local isSel = (nm == recipeEditPop.selected)
local isCur = (nm == curM)
if #disp > cw - 2 then disp = disp:sub(1, cw - 2) end
drawText(cellX, cellY, disp,
isSel and colors.black or (isCur and colors.lime or colors.white),
isSel and colors.lime or colors.gray)
UI.zoneP(touchZones, "recipe_edit_select", nm, cellX, cellY, cw - 1)
end
local navY = pY + pH - 2
drawText(pX + 2, navY, " < ", page > 1 and colors.white or colors.lightGray, colors.gray)
drawText(pX + pW - 5, navY, " > ", page < pages and colors.white or colors.lightGray, colors.gray)
if page > 1     then UI.zoneP(touchZones, "recipe_edit_prev", nil, pX + 2, navY, 3) end
if page < pages then UI.zoneP(touchZones, "recipe_edit_next", nil, pX + pW - 5, navY, 3) end
local btnY = pY + pH - 1
UI.btnP(touchZones, pX + 2, btnY, " [APPLY] ", "ok", "recipe_edit_apply")
if not recipeEditPop.fluid then
UI.btnP(touchZones, pX + 12, btnY, " [REPLACE ALL] ", "warn", "recipe_edit_global")
end
UI.btnP(touchZones, pX + pW - 12, btnY, " [CANCEL] ", "mute", "close_recipe_edit")
return popupRect
end


function drawQtyPicker(w, h, stockInv, touchZones, popupRect)
craftDonePopup = nil
resetErr()
craftInfoPop = nil
recipeEditPop = nil
local pW, pH = 54, 10
local headerText, hdrStyle
if queueEditIdx           then headerText, hdrStyle = " EDIT QUEUE AMOUNT ", "cool"
elseif fluidCraftMode     then headerText, hdrStyle = " FLUID PRODUCTION ORDER ", "cool"
elseif isRequestMode      then headerText, hdrStyle = " REQUEST TO TRAIN BOX ", "cool"
elseif altOutEdit         then headerText, hdrStyle = " OUTPUT COUNT ", "cool"
elseif isSettingKeep then headerText, hdrStyle = " KEEP: THRESHOLD -> TARGET ", "warn"
else                           headerText, hdrStyle = " PRODUCTION INTERACTIVE ORDER ", "ok" end
local pX, pY, rect = UI.popup(pW, pH, w, h, headerText, hdrStyle)
popupRect = rect
local nameLabel = "Item: "
if fluidCraftMode then nameLabel = fluidCraftMode.isItem and "Item: " or "Fluid: " end
if fluidKeepName then nameLabel = "Fluid: " end
local pickName = fluidKeepName and (fluidKeepName:match("([^:]+)$") or fluidKeepName)
or (shortName(itemToCraft))
if not altOutEdit then
drawText(pX + 2, pY + 2, nameLabel .. pickName, colors.white, colors.gray)
end
local exactStock = isRequestMode and reqMaxQty or (stockInv and (stockInv[itemToCraft] or 0) or 0)
local curStock      = exactStock
local stockColor    = colors.cyan
if exactStock == 0 and stockInv then
local alts = Groups.altsOf(itemToCraft)
if alts then
local altTotal = 0
for _, altName in ipairs(alts) do
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
local fInv = (pickerHdr and pickerHdr.fluidInv) or getFluid()
curStock = fInv[fluidKey(itemToCraft)] or 0
end
stockColor = colors.cyan
elseif fluidKeepName then
unitSuf = " mB"
local fInv = (pickerHdr and pickerHdr.fluidInv) or getFluid()
curStock = fInv[itemToCraft] or 0
stockColor = colors.cyan
end
if isSettingKeep then
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
if not pickerMaxSet then
mxVal = "?"
mxColor = colors.yellow
else
if fluidCraftMode then
mxVal = pickerCraftable >= FLUID_MAX_CAP and ">100000" or (tostring(pickerCraftable) .. unitSuf)
else
mxVal = pickerCraftable >= ITEM_MAX_CAP and ">999" or tostring(pickerCraftable)
end
mxColor = pickerCraftable > 0 and colors.lime or colors.red
end
UI.text(valX, pY + 3, mxVal, mxColor, colors.gray)
UI.zoneP(touchZones, "qty_calc_max", nil, valX, pY + 3, #mxVal)
local autoOn = (Config.autoMaxCalc ~= false)
UI.btnP(touchZones, pX + pW - 9, pY + 3, autoOn and " [AUT] " or " [MAN] ", autoOn and "ok" or "warn", "qty_toggle_automax")
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
local qeEdit = queueEditIdx and Craft.queue[queueEditIdx]
if (fluidCraftMode and not fluidCraftMode.isItem) or fluidKeepName
or (qeEdit and qeEdit.kind == "fluid" and not qeEdit.isItem) then
addVals = {100, 1000, 5000, 10000}
subVals = {-100, -1000, -5000, -10000}
end
local qX = pX + 2
for _, val in ipairs(addVals) do
local str = " [+" .. val .. "] "
UI.btnP(touchZones, qX, addRow, str, "mute", "qty_adj", val)
qX = qX + #str + 1
end
if not isSettingKeep and not altOutEdit then
UI.btnP(touchZones, rightBtnX, addRow, maxStr, "ok", "qty_max")
end
qX = pX + 2
for _, val in ipairs(subVals) do
local str = " [" .. val .. "] "
UI.btnP(touchZones, qX, subRow, str, "mute", "qty_adj", val)
qX = qX + #str + 1
end
UI.btnP(touchZones, rightBtnX, subRow, typStr, "cool", "qty_type")
if qtyTypeAct then
local opW, opH = 30, 5
local opX = pX + math.floor((pW - opW) / 2)
local opY = pY + math.floor((pH - opH) / 2)
_bufFillRect(opX, opY, opW, opH, colors.gray)
local ohdr = " ENTER QUANTITY "
UI.text(opX + math.floor((opW - #ohdr) / 2), opY, ohdr, UI.C.bg, UI.C.info)
local oHint = "Type number in terminal"
UI.text(opX + math.floor((opW - #oHint) / 2), opY + 2, oHint, UI.C.soft, UI.C.rowBg)
local oCur = "Current: " .. tostring(craftQuantity)
UI.text(opX + math.floor((opW - #oCur) / 2), opY + 3, oCur, UI.C.accent, UI.C.rowBg)
end
local cfmStr, cnlStr = " [ CONFIRM ] ", " [ CANCEL ] "
UI.btnP(touchZones, pX + 2, btnRow, cfmStr, "ok", "qty_confirm")
UI.btnP(touchZones, pX + pW - #cnlStr - 2, btnRow, cnlStr, "mute", "qty_cancel")
if not isRequestMode and not isSettingKeep and not fluidKeepName and not queueEditIdx and not altOutEdit then
UI.btnP(touchZones, pX + 2 + #cfmStr + 1, btnRow, " [+QUEUE] ", "cool", "qty_add_queue")
end
return popupRect
end


function drawHistory(w, h, stockInv, touchZones, popupRect)
local hasBox = Config.train_box and Config.train_box ~= ""
local pW = math.min(w - 4, 82)
local perPage = math.max(4, h - 18)
local totEnt = #craftHistory
local pages = math.max(1, math.ceil(totEnt / perPage))
if (historyPopup.page or 1) > pages then historyPopup.page = 1 end
local hPage = historyPopup.page or 1
local pH = perPage + 5
local pX, pY, rect = UI.popup(pW, pH, w, h, " CRAFT HISTORY ", "warn", 9)
popupRect = rect
UI.btnP(touchZones, pX + pW - 9, pY, " [SCAN] ", "ok", "history_scan")
local reqX    = pX + pW - 7
local stkEnd  = reqX - 2
local craftX  = stkEnd - 10
local maxEnd  = craftX - 2
local fInv    = getFluidCached()
local maxCache = historyPopup.maxCache or {}
local iStart = (hPage - 1) * perPage + 1
local iEnd   = math.min(iStart + perPage - 1, totEnt)
local listY  = pY + 2
for i = iStart, iEnd do
local e     = craftHistory[i]
local stock = e.fluid and (fInv[fluidKey(e.item)] or 0)
or (stockInv and (stockInv[e.item] or 0) or 0)
local maxC  = maxCache[(e.fluid and "f:" or "") .. e.item]
local maxDisp = (maxC == nil and "?") or (maxC >= 100 and ">99") or tostring(maxC)
local stkStr = tostring(stock); if #stkStr > 3 then stkStr = "+++" end
local qtyStr = "x" .. tostring(e.qty)
local qtyX   = maxEnd - 3 - #qtyStr
local rowBg  = zebraBg(i)
_bufFillRect(pX + 1, listY, pW - 2, 1, rowBg)
UI.text(pX + 2, listY, shortName(e.item):sub(1, math.max(0, qtyX - pX - 2)), UI.C.fg, rowBg)
UI.text(qtyX, listY, qtyStr, (rowBg == colors.lightGray) and colors.black or colors.lightGray, rowBg)
UI.text(maxEnd - #maxDisp + 1, listY, maxDisp, UI.C.accent, rowBg)
UI.btnP(touchZones, craftX, listY, "[CRAFT]", "soft", e.fluid and "history_craft_fluid" or "history_craft", e.item)
UI.text(stkEnd - #stkStr + 1, listY, stkStr, UI.C.info, rowBg)
if not e.fluid then
UI.text(reqX, listY, "[REQ]", UI.C.bg, hasBox and UI.C.info or UI.C.rowBg)
if hasBox then UI.zoneP(touchZones, "history_req", e.item, reqX, listY, 5) end
end
listY = listY + 1
end
if totEnt == 0 then
UI.text(pX + math.floor((pW - 14) / 2), listY + 1, "No crafts yet.", UI.C.soft, UI.C.rowBg)
end
local navY = pY + pH - 1
UI.text(pX + 1, navY - 1, string.rep("-", pW - 2), UI.C.soft, UI.C.rowBg)
if pages > 1 then
local prevS, nextS = "[ PREV ]", "[ NEXT ]"
local pgS = " PAGE " .. hPage .. " OF " .. pages .. " "
local navX  = pX + math.floor((pW - (#prevS + #pgS + #nextS + 2)) / 2)
UI.btnP(touchZones, navX, navY, prevS, "mute", "history_prev")
UI.text(navX + #prevS + 1, navY, pgS, UI.C.accent, UI.C.rowBg)
UI.btnP(touchZones, navX + #prevS + #pgS + 2, navY, nextS, "mute", "history_next")
else
local clsNav = " [ CLOSE ] "
UI.btnP(touchZones, pX + math.floor((pW - #clsNav) / 2), navY, clsNav, "mute", "close_history")
end
return popupRect
end


function _diQueuePopup(w, h, touchZones, popupRect)
local total = #Craft.queue
local maxRows = math.max(4, h - 18)
if queueScroll > math.max(0, total - maxRows) then queueScroll = math.max(0, total - maxRows) end
if queueScroll < 0 then queueScroll = 0 end
local shown = math.min(total, maxRows)
local errActive = queueErrIdx and Craft.queue[queueErrIdx] and Craft.queue[queueErrIdx].failed
local pW = math.min(w - 4, 72)
local pH = math.max(shown, 1) + (errActive and 8 or 4)
local pX, pY, rect = UI.popup(pW, pH, w, h, " CRAFT QUEUE (" .. total .. ") ", "ok", 9)
popupRect = rect
local xDel = pX + pW - 7
local xEd, xDn, xUp = xDel - 7, xDel - 11, xDel - 15
local xTop = xUp - 6
local xCr  = xTop - 8
if total == 0 then
UI.text(pX + 2, pY + 2, "Queue empty. Use [+QUEUE] in order popup.", UI.C.soft, UI.C.rowBg)
end
for ri = 1, shown do
local qi = queueScroll + ri
local qe = Craft.queue[qi]
local rowY = pY + 1 + ri
local nm = shortName(qe.name)
local unit = (qe.kind == "fluid" and not qe.isItem) and " mB" or "x"
local label = string.format("%d. %s  %d%s", qi, nm, qe.qty, unit)
local nameW = xCr - (pX + 2) - (qe.failed and 5 or 2)
UI.text(pX + 2, rowY, label:sub(1, nameW), qe.failed and UI.C.warn or UI.C.fg, UI.C.rowBg)
if qe.failed then UI.btnP(touchZones, xCr - 4, rowY, "[!]", "danger", "queue_err", qi) end
UI.btnP(touchZones, xCr, rowY, "[CRAFT]", "soft", "queue_craft", qi)
local topStyle = (qi > 1) and "mute" or "soft"
UI.btnP(touchZones, xTop, rowY, "[TOP]", topStyle, "queue_top", qi)
UI.btnP(touchZones, xUp, rowY, "[^]", topStyle, "queue_up", qi)
UI.btnP(touchZones, xDn, rowY, "[v]", (qi < total) and "mute" or "soft", "queue_dn", qi)
UI.btnP(touchZones, xEd, rowY, "[EDIT]", "mute", "queue_edit", qi)
UI.btnP(touchZones, xDel, rowY, "[DEL]", "danger", "queue_del", qi)
end
if errActive then
local fl = Craft.queue[queueErrIdx].failed
local errY = pY + shown + 2
UI.text(pX + 2, errY, ("FAIL #" .. queueErrIdx .. ":"):sub(1, pW - 4), UI.C.danger, UI.C.rowBg)
for li = 1, math.min(2, #fl) do
UI.text(pX + 4, errY + li, tostring(fl[li]):sub(1, pW - 6), UI.C.fg, UI.C.rowBg)
end
end
local btnY = pY + pH - 1
local runStr, clsStr = " [ RUN ALL ] ", " [ CLOSE ] "
UI.btnP(touchZones, pX + 2, btnY, runStr, (total > 0) and "ok" or "mute", "queue_runall")
UI.btnP(touchZones, pX + pW - #clsStr - 2, btnY, clsStr, "mute", "queue_close")
if total > maxRows then
local pgX = pX + math.floor(pW / 2) - 4
UI.btnP(touchZones, pgX, btnY, " < ", "soft", "queue_scroll", -maxRows)
UI.btnP(touchZones, pgX + 5, btnY, " > ", "soft", "queue_scroll", maxRows)
end
return popupRect
end


function drawMgmtEdit(w, h, touchZones, popupRect, popupZoneS)
local pW = math.min(w - 4, 58)
local rules = mgmtPopup.rules or {}
local inIsStg = (#(mgmtPopup.inputs or {}) == 0)
local hdrLines = 7 + (inIsStg and 0 or 2)
local ftrLines = 3
local maxPH = h - 2
local rulesN = math.max(1, #rules)
local pH = math.min(maxPH, hdrLines + rulesN * 3 + ftrLines)
local perPage = math.max(1, math.floor((pH - hdrLines - ftrLines) / 3))
local pages = math.max(1, math.ceil(#rules / perPage))
if not mgmtPopup.rulesPage or mgmtPopup.rulesPage < 1 then mgmtPopup.rulesPage = 1 end
if mgmtPopup.rulesPage > pages then mgmtPopup.rulesPage = pages end
local rulesPage = mgmtPopup.rulesPage
local rStart = (rulesPage - 1) * perPage + 1
local rEnd   = math.min(rStart + perPage - 1, #rules)
popupZoneS = #touchZones + 1
local pX, pY, rect = UI.popup(pW, pH, w, h, mgmtPopup.groupIdx and " EDIT GROUP " or " NEW GROUP ", "cool")
popupRect = rect
local nmDisp = mgmtPopup.name ~= "" and mgmtPopup.name or "(tap to set)"
UI.text(pX + 1, pY + 2, (" Name: [ " .. nmDisp .. " ]"):sub(1, pW - 2), UI.C.fg, UI.C.rowBg)
UI.zone(touchZones, "mgmt_edit_name", nil, pX + 1, pY + 2, pW - 2)
local inDisp = mgmtIODisp({inputs=mgmtPopup.inputs}, true)
UI.text(pX + 1, pY + 3, (" Input:  " .. inDisp):sub(1, pW - 13), inIsStg and UI.C.accent or UI.C.fg, UI.C.rowBg)
UI.btnR(touchZones, pX + pW - 2, pY + 3, " [CHANGE] ", "warn", "mgmt_pick_input")
local outIsStg = (#(mgmtPopup.outputs or {}) == 0)
local outDisp = mgmtIODisp({outputs=mgmtPopup.outputs}, false)
UI.text(pX + 1, pY + 4, (" Output: " .. outDisp):sub(1, pW - 13), outIsStg and UI.C.accent or UI.C.info, UI.C.rowBg)
UI.btnR(touchZones, pX + pW - 2, pY + 4, " [CHANGE] ", "warn", "mgmt_pick_output")
UI.text(pX + 1, pY + 5, string.rep("-", pW - 2), UI.C.soft, UI.C.rowBg)
UI.text(pX + 1, pY + 6, mgmtPopup.fluid and " RULES (keep mB in output):" or " RULES (input->output):", UI.C.hi, UI.C.rowBg)
UI.btnR(touchZones, pX + pW - 2, pY + 6, " [+ADD] ", "ok", "mgmt_pick_item")
local ry = pY + 7
if not inIsStg then
local drainOn = mgmtPopup.drain or false
local drainLbl = (drainOn and " [EMPTY ALL]  ON  " or " [EMPTY ALL]  OFF "):sub(1, pW - 2)
drawText(pX + 1, ry, drainLbl, drainOn and colors.black or colors.lightGray, drainOn and colors.lime or colors.gray)
UI.zone(touchZones, "mgmt_toggle_drain", nil, pX + 1, ry, pW - 2)
ry = ry + 1
local provOn = mgmtPopup.provider or false
local provSuf = " (pull-only src) "
for _, nm in ipairs(mgmtPopup.inputs or {}) do
if isBridge(nm) then provSuf = " (ME/RS pull-only) "; break end
end
drawText(pX + 1, ry, (provOn and " [PROVIDER] ON" .. provSuf or " [PROVIDER] OFF"):sub(1, pW - 2),
provOn and colors.black or colors.lightGray, provOn and colors.orange or colors.gray)
UI.zone(touchZones, "mgmt_toggle_provider", nil, pX + 1, ry, pW - 2)
ry = ry + 1
end
if #rules == 0 then
UI.text(pX + 2, ry, "(none)", UI.C.soft, UI.C.rowBg)
ry = ry + 1
else
for ri = rStart, rEnd do
local rule = rules[ri]
local rn = (shortName(rule.item))
local amt = tostring(rule.amount)
local ctrlX = pX + pW - (5 + #amt + 5 + 5 + 5) - 2
UI.text(pX + 2, ry, rn:sub(1, ctrlX - pX - 3), UI.C.fg, UI.C.rowBg)
UI.btn(touchZones, ctrlX, ry, " [-] ", "mute", "mgmt_rule_adj", {ri, -1})
UI.text(ctrlX + 5, ry, amt, UI.C.hi, UI.C.rowBg)
UI.btn(touchZones, ctrlX + 5 + #amt, ry, " [+] ", "mute", "mgmt_rule_adj", {ri, 1})
UI.btn(touchZones, ctrlX + 5 + #amt + 5, ry, " [#] ", "warn", "mgmt_rule_type", ri)
UI.btn(touchZones, ctrlX + 5 + #amt + 10, ry, " [X] ", "danger", "mgmt_rule_del", ri)
ry = ry + 1
UI.text(pX + 1, ry, string.rep("-", pW - 2), UI.C.soft, UI.C.rowBg)
ry = ry + 1
drawCondRow(pX, pW, ry, rule, ri, touchZones)
ry = ry + 1
end
end
local footY = pY + pH - 2
if pages > 1 then
local pagerY = footY - 1
local prevS, nextS = " < PREV ", " NEXT > "
local pgStr = string.format("Page %d/%d", rulesPage, pages)
UI.text(pX + 2, pagerY, prevS, rulesPage > 1 and UI.C.fg or UI.C.muted, UI.C.rowBg)
UI.text(pX + math.floor((pW - #pgStr) / 2), pagerY, pgStr, UI.C.soft, UI.C.rowBg)
UI.text(pX + pW - #nextS - 2, pagerY, nextS, rulesPage < pages and UI.C.fg or UI.C.muted, UI.C.rowBg)
if rulesPage > 1 then UI.zone(touchZones, "mgmt_rules_prev", nil, pX + 2, pagerY, #prevS) end
if rulesPage < pages then UI.zone(touchZones, "mgmt_rules_next", nil, pX + pW - #nextS - 2, pagerY, #nextS) end
end
UI.btn(touchZones, pX + 2, footY + 1, " [SAVE] ", "ok", "mgmt_save")
UI.btnR(touchZones, pX + pW - 2, footY + 1, " [CANCEL] ", "mute", "mgmt_cancel")
return popupRect, popupZoneS
end


function _drawMgmtPeriPicker(w, h, touchZones, ctx)
local allPeri = {"STORAGE"}
local tmp = {}
for _, pn in ipairs(peripheral.getNames()) do
if not SYSTEM_SIDES[pn] and pn ~= MONITOR_SIDE and pn ~= Config.train_box then table.insert(tmp, pn) end
end
table.sort(tmp, _cmpByDisplay)
for _, v in ipairs(tmp) do table.insert(allPeri, v) end
local pW = math.min(w - 10, 70)
local pX = math.floor((w - pW) / 2) + 1
local pH = math.min(h - 4, 16)
local pY = math.floor((h - pH) / 2) + 1
local cols, colW = 3, math.floor((pW - 2) / 3)
local listTop = pY + 2
local maxRows = pH - 5
local perPage = cols * maxRows
local page  = mgmtPopup[ctx.pageKey] or 1
local total = math.max(1, math.ceil(#allPeri / perPage))
if page > total then page = total; mgmtPopup[ctx.pageKey] = page end
local st = (page - 1) * perPage + 1
local en = math.min(st + perPage - 1, #allPeri)
local zoneStart = #touchZones + 1
local hdrStyleName = ctx.hdrColor == colors.orange and "warn" or "cool"
local _, _, rect = UI.popup(pW, pH, w, h, ctx.hdr, hdrStyleName)
for ci = 1, cols - 1 do
local sepX = pX + 1 + ci * colW
for ry = 0, maxRows - 1 do UI.text(sepX, listTop + ry, "|", UI.C.soft, UI.C.rowBg) end
end
local sel = mgmtPopup[ctx.listKey] or {}
local selSet = {}
for _, nm in ipairs(sel) do selSet[nm] = true end
local stgSel = (#sel == 0)
for pi = st, en do
local localIdx = pi - st
local cellX = pX + 2 + math.floor(localIdx / maxRows) * colW
local cellY = listTop + (localIdx % maxRows)
local pn = allPeri[pi]
local isStg = (pn == "STORAGE")
local isSel = (isStg and stgSel) or (not isStg and selSet[pn] == true)
local disp = isStg and pn or getMachName(pn)
if #disp > colW - 2 then disp = disp:sub(1, colW - 2) end
drawText(cellX, cellY, disp,
(isSel or isStg) and colors.black or colors.white,
isSel and colors.cyan or (isStg and colors.lime or colors.gray))
UI.zone(touchZones, ctx.setId, pn, cellX, cellY, colW - 1)
end
local navY = pY + pH - 2
drawText(pX + 2, navY, " < ", page > 1 and colors.white or colors.gray, colors.gray)
drawText(pX + pW - 5, navY, " > ", page < total and colors.white or colors.gray, colors.gray)
if page > 1 then UI.zone(touchZones, ctx.prevId, nil, pX + 2, navY, 3) end
if page < total then UI.zone(touchZones, ctx.nextId, nil, pX + pW - 5, navY, 3) end
UI.btn(touchZones, pX + math.floor((pW - 8) / 2), pY + pH - 1, " [DONE] ", "ok", ctx.doneId)
return rect, zoneStart
end


function _drawMgmtItemPicker(w, h, touchZones)
local inIsStg = (mgmtPopup.condRuleIdx ~= nil) or (#(mgmtPopup.inputs or {}) == 0)
local items = {}

local function push(name, count) items[#items + 1] = {name = name, count = count} end
if mgmtPopup.fluid then
local src = inIsStg and mgmtFSnap() or tankContents(mgmtPopup.input)
for n, c in pairs(src) do push(n, c) end
elseif inIsStg then
for n, c in pairs(getInvCached()) do push(n, c) end
else
local by = {}
for _, inNm in ipairs(mgmtPopup.inputs or {}) do
local p = peripheral.wrap(inNm)
if p and p.list then
local ok, lst = pcall(p.list)
if ok and lst then
for _, it in pairs(lst) do if it then by[it.name] = (by[it.name] or 0) + it.count end end
end
elseif p and p.getItems then
local ok, lst = pcall(p.getItems)
if ok and lst then
for _, it in pairs(lst) do if it and it.name then by[it.name] = (by[it.name] or 0) + (it.count or 0) end end
end
end
end
for n, c in pairs(by) do push(n, c) end
end
table.sort(items, function(a, b) return a.name < b.name end)
local srch = mgmtItemSrch:lower()
local filt = {}
for _, it in ipairs(items) do
if srch == "" or it.name:lower():find(srch, 1, true) then filt[#filt + 1] = it end
end
local pW = math.min(w - 10, 70)
local pX = math.floor((w - pW) / 2) + 1
local pH = math.min(h - 4, 18)
local pY = math.floor((h - pH) / 2) + 1
local cols, colW = 3, math.floor((pW - 2) / 3)
local listTop = pY + 3
local maxRows = pH - 6
local perPage = cols * maxRows
local page  = mgmtPopup.itemPage or 1
local total = math.max(1, math.ceil(#filt / perPage))
if page > total then page = total; mgmtPopup.itemPage = page end
local st = (page - 1) * perPage + 1
local en = math.min(st + perPage - 1, #filt)
local zoneStart = #touchZones + 1
local inpShort = inIsStg and "STORAGE" or getMachName(mgmtPopup.input)
local hdr
if mgmtPopup.condRuleIdx then
hdr = mgmtPopup.fluid and " PICK CONDITION FLUID " or " PICK CONDITION ITEM "
else
hdr = (mgmtPopup.fluid and " ADD FLUID FROM: " or " ADD ITEM FROM: ") .. inpShort:upper():sub(1, pW - 20) .. " "
end
local _, _, rect = UI.popup(pW, pH, w, h, hdr, "ok")
local searchRow = pY + 1
local srchDisp  = (mgmtItemSrch == "") and "<type item name...>" or mgmtItemSrch
local srchFull  = "FIND: [ " .. srchDisp .. " ]"
local srchX     = pX + math.floor((pW - #srchFull) / 2)
UI.text(srchX, searchRow, "FIND: ", UI.C.soft, UI.C.rowBg)
drawText(srchX + 6, searchRow, "[ " .. srchDisp .. " ]",
mgmtSearchOn and colors.black or (mgmtItemSrch == "" and colors.gray or colors.white),
mgmtSearchOn and colors.white or colors.lightGray)
UI.zone(touchZones, "mgmt_search_focus", nil, srchX, searchRow, #srchFull)
if mgmtItemSrch ~= "" then
UI.btn(touchZones, srchX + #srchFull + 1, searchRow, " [X] ", "danger", "mgmt_search_clear")
end
for ci = 1, cols - 1 do
local sepX = pX + 1 + ci * colW
for ry = 0, maxRows - 1 do UI.text(sepX, listTop + ry, "|", UI.C.soft, UI.C.rowBg) end
end
if #filt == 0 then
UI.text(pX + 2, listTop + 1, srch ~= "" and "(no matches)" or "(input empty or unavailable)", UI.C.soft, UI.C.rowBg)
else
for ii = st, en do
local localIdx = ii - st
local cellX = pX + 2 + math.floor(localIdx / maxRows) * colW
local cellY = listTop + (localIdx % maxRows)
local itm = filt[ii]
local cntS = tostring(itm.count)
local nameMax = colW - 2 - #cntS - 1
local iShort = (shortName(itm.name)):sub(1, nameMax)
local hasRule = false
if not mgmtPopup.condRuleIdx then
for _, r in ipairs(mgmtPopup.rules or {}) do
if r.item == itm.name then hasRule = true; break end
end
end
UI.text(cellX, cellY, iShort, hasRule and UI.C.warn or UI.C.fg, UI.C.rowBg)
UI.text(cellX + colW - 2 - #cntS, cellY, cntS, UI.C.info, UI.C.rowBg)
if not hasRule then UI.zone(touchZones, "mgmt_add_rule", itm.name, cellX, cellY, colW - 1) end
end
end
local navY = pY + pH - 2
drawText(pX + 2, navY, " < ", page > 1 and colors.white or colors.lightGray, colors.gray)
drawText(pX + pW - 5, navY, " > ", page < total and colors.white or colors.lightGray, colors.gray)
if page > 1 then UI.zone(touchZones, "mgmt_item_prev", nil, pX + 2, navY, 3) end
if page < total then UI.zone(touchZones, "mgmt_item_next", nil, pX + pW - 5, navY, 3) end
UI.btn(touchZones, pX + math.floor((pW - 10) / 2), pY + pH - 1, " [CANCEL] ", "mute", "mgmt_item_cancel")
return rect, zoneStart
end


function drawMgmtInputSel(w, h, touchZones)
return _drawMgmtPeriPicker(w, h, touchZones,
{pageKey="periPage", listKey="inputs", hdr=" SELECT INPUTS (tap to toggle) ", hdrColor=colors.orange,
setId="mgmt_set_input", prevId="mgmt_peri_prev", nextId="mgmt_peri_next", doneId="mgmt_peri_cancel"})
end


function drawMgmtOutSel(w, h, touchZones)
return _drawMgmtPeriPicker(w, h, touchZones,
{pageKey="outPeriPage", listKey="outputs", hdr=" SELECT OUTPUTS (tap to toggle) ", hdrColor=colors.cyan,
setId="mgmt_set_output", prevId="mgmt_outperi_prev", nextId="mgmt_outperi_next", doneId="mgmt_outperi_cancel"})
end


function drawFluidPicker(w, h, touchZones, popupRect)
resetErr()
local fp = fluidRecipePicker
local sName = shortName(fp.fluid)
local rows = fp.producers
local pW = math.min(w - 4, 76)
local pH = math.min(#rows + 6, h - 4)
local pX, pY, rect = UI.popup(pW, pH, w, h, " RECIPE PRIORITY: " .. sName:upper() .. " ", "ok")
popupRect = rect
UI.text(pX + 2, pY + 1, "[*]=make primary  [X]=delete  top=tried first", UI.C.muted, UI.C.rowBg)
local awaiting = (fluidWaitCraft == fp.fluid)
local delX  = pX + pW - 5
local crfX  = delX - 8
local starX = crfX - 4
local descW = starX - pX - 3
local lineY = pY + 3
for idx, p in ipairs(rows) do
if lineY >= pY + pH - 1 then break end
local mDisp = getMachName(p.recipe.machine_name) or p.recipe.machine_name or "?"
local ins, outs = {}, {}
for _, inp in ipairs(p.recipe.inputs or {}) do
ins[#ins + 1] = string.format("%s %d", shortName(inp.name), inp.amount)
end
for _, it in ipairs(p.recipe.item_inputs or {}) do
ins[#ins + 1] = string.format("%dx %s", it.count, shortName(it.name))
end
for _, o in ipairs(p.recipe.outputs or {}) do
outs[#outs + 1] = string.format("%s %d", shortName(o.name), o.amount)
end
for _, o in ipairs(p.recipe.item_outputs or {}) do
outs[#outs + 1] = string.format("%dx %s", o.count, shortName(o.name))
end
local rank = p.isPrimary and "[PRIMARY] " or (p.own and ("[#" .. idx .. "] ") or "[~] ")
local desc = rank .. string.format("%s: %s -> %s", mDisp, table.concat(ins, " + "), table.concat(outs, " + "))
UI.text(pX + 2, lineY, desc:sub(1, math.max(1, descW)), p.isPrimary and UI.C.hi or UI.C.fg, UI.C.rowBg)
if p.own and not p.isPrimary then UI.btnP(touchZones, starX, lineY, "[*]", "cool", "fluid_make_primary", idx) end
if awaiting then
UI.text(crfX - 1, lineY, "-", UI.C.accent, UI.C.rowBg)
UI.text(crfX + 7, lineY, "-", UI.C.accent, UI.C.rowBg)
end
UI.btnP(touchZones, crfX, lineY, "[CRAFT]", awaiting and "hi" or "ok", "fluid_pick_recipe", idx)
if p.own then UI.btnP(touchZones, delX, lineY, "[X]", "danger", "fluid_picker_delete", idx) end
lineY = lineY + 1
end
local clsStr = " [ CLOSE ] "
UI.btnP(touchZones, pX + math.floor((pW - #clsStr) / 2), pY + pH - 1, clsStr, "mute", "fluid_picker_close")
return popupRect
end


function drawCraftInfo(w, h, touchZones, popupRect, data)
local sName = shortName(craftInfoPop.item)
local lines = {}
local blocked = {}
for bItem in pairs(data.blocked or {}) do
table.insert(blocked, bItem)
end
table.sort(blocked)
if #blocked > 0 then
for _, bn in ipairs(blocked) do
local bs = shortName(bn)
table.insert(lines, {text = bs .. ":", color = colors.red})
local details = data.blockedInfo and data.blockedInfo[bn]
if details and details.missing and next(details.missing) then
local mList = {}
for mItem, mCount in pairs(details.missing) do
table.insert(mList, {name = shortName(mItem), count = mCount})
end
table.sort(mList, function(a, b) return a.name < b.name end)
for _, m in ipairs(mList) do
table.insert(lines, {text = "  " .. m.name .. "  x" .. m.count, color = colors.white})
end
end
table.insert(lines, {text = "", color = colors.gray})
end
else
local mList = {}
for mItem, mCount in pairs(data.missing or {}) do
table.insert(mList, {name = shortName(mItem), count = mCount})
end
table.sort(mList, function(a, b) return a.name < b.name end)
for _, m in ipairs(mList) do
table.insert(lines, {text = m.name .. "  x" .. m.count, color = colors.white})
end
end
if #lines == 0 then
table.insert(lines, {text = "Craftable from stock (no shortage).", color = colors.lime})
end
local pW = 44
local pH = math.min(#lines + 5, h - 8)
local pX, pY, rect = UI.popup(pW, pH, w, h, " ANALYSIS: " .. sName:upper():sub(1, pW - 13) .. " ", "danger")
popupRect = rect
local lineY = pY + 2
for _, line in ipairs(lines) do
if lineY >= pY + pH - 2 then break end
if line.text ~= "" then UI.text(pX + 2, lineY, line.text:sub(1, pW - 4), line.color, UI.C.rowBg) end
lineY = lineY + 1
end
UI.btnP(touchZones, pX + math.floor((pW - 11) / 2), pY + pH - 1, " [ CLOSE ] ", "mute", "close_craft_info")
return popupRect
end


function drawCraftDone(w, h, touchZones, popupRect)
resetErr()
craftInfoPop = nil
recipeEditPop = nil
local popup = craftDonePopup
local outs = popup.outputs
local bodyLines = outs and #outs or 1
local pW = 40
local pH = math.max(7, bodyLines + 5)
local pX, pY, rect = UI.popup(pW, pH, w, h, popup.learned and " RECIPE LEARNED " or " CRAFT COMPLETE ", "ok", 9)
popupRect = rect
local clsStr = " [CLOSE] "
local btnY = pY + pH - 2
if outs then
UI.text(pX + 2, pY + 2, "Output:", UI.C.fg, UI.C.rowBg)
local ly = pY + 3
for _, o in ipairs(outs) do
local on = shortName(o.name)
local txt = (o.unit == "x") and (on .. ": " .. o.amount .. "x") or (on .. ": " .. o.amount .. " mB")
UI.text(pX + 4, ly, txt:sub(1, pW - 6), UI.C.accent, UI.C.rowBg)
ly = ly + 1
end
elseif popup.isFluid then
local sName = shortName(popup.item)
UI.text(pX + 2, pY + 2, ("Fluid: " .. sName):sub(1, pW - 4), UI.C.fg, UI.C.rowBg)
UI.text(pX + 2, pY + 3, "Made: " .. popup.count .. " mB", UI.C.accent, UI.C.rowBg)
else
local sName = shortName(popup.item)
UI.text(pX + 2, pY + 2, ("Item: " .. sName):sub(1, pW - 4), UI.C.fg, UI.C.rowBg)
UI.text(pX + 2, pY + 3, "Stock: " .. popup.count .. " pcs.", UI.C.accent, UI.C.rowBg)
UI.btnP(touchZones, pX + 2, btnY, " [REQUEST] ", "cool", "popup_request")
end
UI.btnP(touchZones, pX + pW - #clsStr - 2, btnY, clsStr, "soft", "popup_close")
return popupRect
end


function drawFluidSave(w, h, touchZones, popupRect)
resetErr()
local sc = fluidSaveConfirm
local rec = sc.recipe
local inParts = {}
for _, inp in ipairs(rec.inputs or {}) do
inParts[#inParts + 1] = (shortName(inp.name)) .. " " .. inp.amount
end
for _, it in ipairs(rec.item_inputs or {}) do
inParts[#inParts + 1] = it.count .. "x " .. (shortName(it.name))
end
local outParts = {}
for _, o in ipairs(rec.outputs or {}) do
outParts[#outParts + 1] = (shortName(o.name)) .. " " .. o.amount .. "mB"
end
for _, o in ipairs(rec.item_outputs or {}) do
outParts[#outParts + 1] = o.count .. "x " .. (shortName(o.name))
end
local pW = math.min(w - 6, 64)
local pH = 9
local pX, pY, rect = UI.popup(pW, pH, w, h, " SAVE LEARNED RECIPE? ", "ok")
popupRect = rect
local mDisp = getMachName(rec.machine_name) or rec.machine_name or "?"
UI.text(pX + 2, pY + 2, ("Machine: " .. mDisp):sub(1, pW - 4), UI.C.fg, UI.C.rowBg)
UI.text(pX + 2, pY + 3, ("In:  " .. table.concat(inParts, " + ")):sub(1, pW - 4), UI.C.soft, UI.C.rowBg)
UI.text(pX + 2, pY + 4, ("Out: " .. table.concat(outParts, " + ")):sub(1, pW - 4), UI.C.info, UI.C.rowBg)
UI.text(pX + 2, pY + 5, (sc.asAlt and "Will be saved as ALT (priority recipe exists)" or "Will be saved as PRIMARY"):sub(1, pW - 4),
sc.asAlt and UI.C.warn or UI.C.accent, UI.C.rowBg)
UI.btnP(touchZones, pX + 2, pY + pH - 1, " [ SAVE ] ", "ok", "fluid_save_yes")
UI.btnR(touchZones, pX + pW - 3, pY + pH - 1, " [ DISCARD ] ", "danger", "fluid_save_no")
return popupRect
end


function drawFluidInfo(w, h, touchZones, popupRect)
local sName = shortName(fluidCraftInfo.name)
local mList = {}
for mKey, mAmt in pairs(fluidCraftInfo.missing or {}) do
if mKey ~= "__fl" and type(mAmt) == "number" and mAmt > 0 then
local isFl = (type(mKey) == "string" and mKey:sub(1, 2) == "f:")
local nm = isFl and fluidNameOf(mKey) or mKey
nm = shortName(nm)
mList[#mList + 1] = {name = nm, amt = mAmt, isFl = isFl}
end
end
table.sort(mList, function(a, b) return a.name < b.name end)
local lines = {}
for _, m in ipairs(mList) do
local suf = m.isFl and (" x" .. m.amt .. " mB") or ("  x" .. m.amt)
lines[#lines + 1] = {text = m.name .. suf, color = m.isFl and colors.cyan or colors.white}
end
if #lines == 0 then
lines[#lines + 1] = {text = "Craftable from stock (no shortage).", color = colors.lime}
end
local pW = 44
local pH = math.min(#lines + 5, h - 8)
local pX, pY, rect = UI.popup(pW, pH, w, h, " MISSING: " .. sName:upper():sub(1, pW - 12) .. " ", "danger")
popupRect = rect
local lineY = pY + 2
for _, line in ipairs(lines) do
if lineY >= pY + pH - 2 then break end
UI.text(pX + 2, lineY, line.text:sub(1, pW - 4), line.color, UI.C.rowBg)
lineY = lineY + 1
end
UI.btnP(touchZones, pX + math.floor((pW - 11) / 2), pY + pH - 1, " [ CLOSE ] ", "mute", "close_fluid_info")
return popupRect
end


function drawMgmtInput(w, grp, h, touchZones, popupRect, popupZoneS)
local pW = math.min(w - 4, 58)
local inIsStg  = (not grp.input  or grp.input  == "" or grp.input  == "STORAGE")
local outIsStg = (not grp.output or grp.output == "" or grp.output == "STORAGE")
local vitems = {}
for _, rule in ipairs(grp.rules or {}) do
table.insert(vitems, {name=rule.item, amount=rule.amount, condition=rule.condition})
end
table.sort(vitems, function(a,b) return a.name < b.name end)
local isFluid = isFluid(grp)
local snap = isFluid and mgmtFSnap() or getInvCached()
local inputCounts = {}
if inIsStg then
for _, vi in ipairs(vitems) do
inputCounts[vi.name] = snap[vi.name] or 0
end
elseif isFluid then
inputCounts = tankContents(grp.input)
else
local inP = peripheral.wrap(grp.input)
if inP and inP.list then
local ok, items = pcall(inP.list)
if ok and items then
for _, it in pairs(items) do
if it then inputCounts[it.name] = (inputCounts[it.name] or 0) + it.count end
end
end
end
end
local outCounts = {}
if outIsStg then
outCounts = snap
elseif isFluid then
outCounts = tankContents(grp.output)
else
local outP = peripheral.wrap(grp.output)
if outP and outP.list then
local ok, outItems = pcall(outP.list)
if ok and outItems then
for _, oi in pairs(outItems) do
if oi then outCounts[oi.name] = (outCounts[oi.name] or 0) + oi.count end
end
end
end
end
local perPage = 5
local page = mgmtPopup.page or 1
local pages = math.max(1, math.ceil(#vitems / perPage))
if page > pages then page = pages; mgmtPopup.page = page end
local vStart = (page - 1) * perPage + 1
local vEnd   = math.min(vStart + perPage - 1, #vitems)
local rN = 0
for vi = vStart, vEnd do
rN = rN + 1
local itm = vitems[vi]
if itm.condition and itm.condition.item and itm.condition.item ~= "" then
rN = rN + 1
end
end
if rN == 0 then rN = 1 end
local pH = math.max(10, math.min(rN + 6, h - 2))
popupZoneS = #touchZones + 1
local gName = (grp.name ~= "" and grp.name or "(unnamed)"):upper()
local pX, pY, rect = UI.popup(pW, pH, w, h, " VIEW: " .. gName:sub(1, pW - 11) .. " ", "warn")
popupRect = rect
local C_RULE, C_INPUT, C_OUTPUT = pX + pW - 20, pX + pW - 13, pX + pW - 6
local nameMax = pW - 23
local inLbl  = inIsStg  and "STORAGE" or (shortName(grp.input)):sub(1,10)
local outLbl = outIsStg and "STORAGE" or (shortName(grp.output)):sub(1,10)
UI.text(pX + 2,   pY + 1, ("In: " .. inLbl .. " -> Out: " .. outLbl):sub(1, nameMax + 1), UI.C.soft, UI.C.rowBg)
UI.text(C_RULE,   pY + 1, "  RULE", UI.C.hi,     UI.C.rowBg)
UI.text(C_INPUT,  pY + 1, " INPUT", UI.C.info,   UI.C.rowBg)
UI.text(C_OUTPUT, pY + 1, "OUTPUT", UI.C.accent, UI.C.rowBg)

local function numCell(x, y, val, col)
local s = tostring(val):sub(1, 6)
UI.text(x + math.max(0, 6 - #s), y, s, col, UI.C.rowBg)
end
if #vitems == 0 then
UI.text(pX + 2, pY + 2, "(no rules defined)", UI.C.soft, UI.C.rowBg)
else
local ry = pY + 2
for vi = vStart, vEnd do
local itm = vitems[vi]
UI.text(pX + 2, ry, (shortName(itm.name)):sub(1, nameMax), UI.C.fg, UI.C.rowBg)
numCell(C_RULE,   ry, itm.amount, UI.C.hi)
numCell(C_INPUT,  ry, inputCounts[itm.name] or 0, UI.C.info)
numCell(C_OUTPUT, ry, outCounts[itm.name] or 0, UI.C.accent)
ry = ry + 1
local cond = itm.condition
if cond and cond.item and cond.item ~= "" then
local cShort = (shortName(cond.item))
local opStr = cond.op or "<"
local cVal  = cond.value or 1
local condStock = snap[cond.item] or 0
local condMet = (opStr == "<" and condStock < cVal)
or (opStr == ">" and condStock > cVal)
or (opStr == "=" and condStock == cVal)
local ifDetail = "-- IF " .. cShort:sub(1, nameMax - 6) .. " " .. opStr .. " " .. tostring(cVal)
UI.text(pX + 2, ry, ifDetail:sub(1, nameMax + 2), UI.C.info, UI.C.rowBg)
numCell(C_OUTPUT, ry, condStock, condMet and UI.C.accent or UI.C.warn)
ry = ry + 1
end
end
end
local navY = pY + pH - 3
if pages > 1 then
if page > 1 then UI.btn(touchZones, pX + 2, navY, " [<] ", "soft", "mgmt_vinput_prev") end
local pgStr = page .. "/" .. pages
UI.text(pX + math.floor((pW - #pgStr) / 2), navY, pgStr, UI.C.soft, UI.C.rowBg)
if page < pages then UI.btn(touchZones, pX + pW - 7, navY, " [>] ", "soft", "mgmt_vinput_next") end
end
UI.btn(touchZones, pX + math.floor((pW - 9) / 2), pY + pH - 1, " [CLOSE] ", "mute", "mgmt_close_view")
return popupRect, popupZoneS
end
-->80_ui/80_4_screens_popups.lua
--<80_ui/80_5_screens_dispatch.lua
function drawHeader(w, stockInv)
local si, totalCount, vaultsCnt, freeSlots, totalSlots
local tFree, tTotal
if curTab == "QUANTITY_PICKER" then
if not pickerHdr then
local pi, pc, pv, pf, ps = getInvCached()
local ptf, ptt = getTankStats()
pickerHdr = {inv = pi, count = pc, vaults = pv, free = pf, slots = ps, tFree = ptf, tTotal = ptt, fluidInv = getFluid()}
end
local snap = pickerHdr
si, totalCount, vaultsCnt, freeSlots, totalSlots = snap.inv, snap.count, snap.vaults, snap.free, snap.slots
tFree, tTotal = snap.tFree, snap.tTotal
else
pickerHdr = nil
si, totalCount, vaultsCnt, freeSlots, totalSlots = getInvCached()
tFree, tTotal = getTankStats()
end
stockInv = si
local totalTypes = 0 for _ in pairs(Recipe.all()) do totalTypes = totalTypes + 1 end
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
statStr = string.format("Tank: %d/%d | Vaults: %d | Types: %d | Total: %d", tFree, tTotal, vaultsCnt, totalTypes, totalCount)
else
statStr = string.format("Vaults: %d | Types: %d | Total: %d", vaultsCnt, totalTypes, totalCount)
end
local statX = math.max(1, math.floor((w - #statStr) / 2) + 1)
drawText(statX, 4, statStr, colors.gray, colors.black)
return stockInv
end


drawUI = function(deferFlush)
local w, h = monitor.getSize()
_bufInit(w, h)
local popupRect = nil
local popupZoneS = 1
do
local logoX = math.max(1, math.floor((w - 25) / 2) + 1)
UI.text(logoX,      2, ">>[ ",             UI.C.accent)
UI.text(logoX + 4,  2, "A . E . G . I . S", UI.C.fg)
UI.text(logoX + 21, 2, " ]<<",             UI.C.accent)
end
local stockInv
stockInv = drawHeader(w, stockInv)
UI.rule(5, w)
local tabY = 6
local touchZones = {}
local displayTab = (curTab == "QUANTITY_PICKER") and qtyOrigTab or curTab
do
local nextX = 2
for _, tab in ipairs({"RECIPES","STOCK","LOGISTIC","KEEP","+RECIPES","GROUPS","NETWORK","SERVICE"}) do
nextX = drawTabBtn(nextX, tabY, tab, displayTab, touchZones)
end
end
UI.rule(tabY + 2, w)
if Config.autostock_paused then
UI.text(2, h - 1, "[AUTOSTOCK PAUSED]", UI.C.fg, UI.C.danger)
else
if asItem ~= "" then
local asName = shortName(asItem)
UI.text(2, h - 1, ("[AS> " .. asName .. "]"):sub(1, math.floor(w / 2) - 2), UI.C.accent)
end
local sMap = {
IDLE         = {"[SYS IDLE]",           UI.C.muted},
MANUAL_CRAFT = {"[MANUAL CRAFTING...]", UI.C.hi},
AUTO_CRAFT   = {"[AUTOCRAFT ACTIVE]",   UI.C.accent},
}
local st = sMap[sysStatus] or sMap.IDLE
if Craft.failed then st = {"[CRAFT FAIL - WINDING DOWN]", UI.C.danger} end
UI.text(w - #st[1] - 1, h - 1, st[1], st[2])
end
if displayTab == "RECIPES" then
drawRecTab(w, h, stockInv, touchZones)
elseif displayTab == "ALT_VIEW" then
drawAltTab(w, h, touchZones)
elseif displayTab == "KEEP" then
drawKeepTab(w, h, stockInv, touchZones)
elseif displayTab == "STOCK" then
drawStockTab(w, h, stockInv, touchZones)
elseif displayTab == "+RECIPES" then
drawPlusTab(w, h, touchZones)
elseif displayTab == "GROUPS" then
popupRect = drawGroupsTab(w, h, touchZones, popupRect)
elseif displayTab == "NETWORK" then
drawNetTab(w, h, touchZones)
elseif displayTab == "SERVICE" then
drawGitTab(w, h, touchZones)
elseif displayTab == "LOGISTIC" then
drawLogTab(w, h, touchZones)
if mgmtPopup then
local pW = math.min(w - 4, 58)
local pX = math.floor((w - pW) / 2) + 1
if mgmtPopup.mode == "edit" then
local step = mgmtPopup.step or "main"
if step == "main" then
popupRect, popupZoneS = drawMgmtEdit(w, h, touchZones, popupRect, popupZoneS)
elseif step == "input_select" then
popupRect, popupZoneS = drawMgmtInputSel(w, h, touchZones, popupRect, popupZoneS)
elseif step == "item_select" then
popupRect, popupZoneS = _drawMgmtItemPicker(w, h, touchZones)
elseif step == "output_select" then
popupRect, popupZoneS = drawMgmtOutSel(w, h, touchZones, popupRect, popupZoneS)
end
elseif mgmtPopup.mode == "view_input" then
local grp2 = MgmtGroups[mgmtPopup.groupIdx]
if grp2 then
popupRect, popupZoneS = drawMgmtInput(w, grp2, h, touchZones, popupRect, popupZoneS)
end
end
end
end
if curTab == "QUANTITY_PICKER" then
popupRect = drawQtyPicker(w, h, stockInv, touchZones, popupRect)
elseif queueEditPopup then
popupRect = _diQueuePopup(w, h, touchZones, popupRect)
elseif historyPopup then
popupRect = drawHistory(w, h, stockInv, touchZones, popupRect)
elseif craftDonePopup then
popupRect = drawCraftDone(w, h, touchZones, popupRect)
elseif recipeEditPop then
popupRect = drawRecipeEdit(w, h, touchZones, popupRect)
elseif fluidSaveConfirm then
popupRect = drawFluidSave(w, h, touchZones, popupRect)
elseif fluidRecipePicker then
popupRect = drawFluidPicker(w, h, touchZones, popupRect)
elseif machInfoPopup then
local pW, pH = math.min(w - 4, 50), 7
local pX, pY, rect = UI.popup(pW, pH, w, h, " MACHINE NOT FOUND ", "warn")
popupRect = rect
local sName = shortName(machInfoPopup.item)
local mDisp = getMachName(machInfoPopup.machineName or "?")
UI.text(pX + 2, pY + 2, ("Recipe:  " .. sName):sub(1, pW - 4), UI.C.fg, UI.C.rowBg)
UI.text(pX + 2, pY + 3, ("Machine: " .. mDisp):sub(1, pW - 4), UI.C.warn, UI.C.rowBg)
UI.text(pX + 2, pY + 4, "Not connected to the network.", UI.C.soft, UI.C.rowBg)
UI.btnP(touchZones, pX + math.floor((pW - 11) / 2), pY + pH - 1, " [ CLOSE ] ", "mute", "close_machine_info")
elseif craftInfoPop then
local data = recipesScan[craftInfoPop.item]
if not data then
craftInfoPop = nil
else
popupRect = drawCraftInfo(w, h, touchZones, popupRect, data)
end
elseif fluidCraftInfo then
popupRect = drawFluidInfo(w, h, touchZones, popupRect)
elseif #craftErrLines > 0 then
local panelTop = math.max(9, h - #craftErrLines)
local hdr = craftErrTitle or "! NOT ENOUGH RESOURCES"
if hdr == "! NEED" then
_bufClearLine(panelTop, colors.yellow)
UI.text(2, panelTop, hdr:sub(1, w - 2), UI.C.bg, UI.C.hi)
else
_bufClearLine(panelTop, colors.red)
UI.text(2, panelTop, hdr:sub(1, w - 2), UI.C.fg, UI.C.danger)
end
for li, line in ipairs(craftErrLines) do
local ly = panelTop + li
if ly <= h then
_bufClearLine(ly, colors.gray)
local editItem = (craftErrTitle == "! MACHINE NOT FOUND") and craftErrEdit[li]
if editItem and Recipe.find(editItem) then
UI.text(2, ly, line:sub(1, w - 9), UI.C.fg, UI.C.rowBg)
UI.btnP(touchZones, w - 6, ly, " [E] ", "warn", "error_edit_machine", editItem)
else
UI.text(2, ly, line:sub(1, w - 2), UI.C.fg, UI.C.rowBg)
end
end
end
end
if popupRect then
if popupZoneS and popupZoneS > 1 then
local filtered = {}
for i = popupZoneS, #touchZones do
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
if not deferFlush then _bufFlush() end
return touchZones
end
-->80_ui/80_5_screens_dispatch.lua
--<80_ui/80_a_state.lua
curTab       = "RECIPES"
modFilter = "All"
srchFilter     = ""
curPage      = 1
modFilterPage    = 1
stockFilter      = ""
stockModFilter         = "All"
stockFilterPage     = 1
isSearch      = false
stockSearchOn = false
qtyTypeAct          = false
craftHistory       = {}
historyPopup       = nil
-->80_ui/80_a_state.lua
--<90_entry/90_0_main_loop.lua
local function _handleTouch(param2, param3, touchZones)
local x, y = param2, param3
uiMessage = ""
if uiMsgTimer then os.cancelTimer(uiMsgTimer); uiMsgTimer = nil end
resetErr()
pendDelItem = nil
pendDelFluid = nil
if idleTimer then os.cancelTimer(idleTimer) end
idleTimer = os.startTimer(autostockIdle)
for _, zone in ipairs(touchZones) do
if zone.id and x >= zone.x1 and x <= zone.x2 and y == zone.y then
if craftDonePopup and zone.id ~= "popup_close" and zone.id ~= "popup_request" and zone.id ~= "popup_bg" then
if craftDonePopup.timer then os.cancelTimer(craftDonePopup.timer) end
craftDonePopup = nil
break
end
if fluidSaveConfirm and zone.id ~= "fluid_save_yes" and zone.id ~= "fluid_save_no" then
break
end
if fluidRecipePicker and zone.id ~= "fluid_pick_recipe" and zone.id ~= "fluid_make_primary"
and zone.id ~= "fluid_picker_delete" and zone.id ~= "fluid_picker_close" then
break
end
if machInfoPopup and zone.id ~= "close_machine_info" and zone.id ~= "show_machine_info" and zone.id ~= "popup_bg" then
machInfoPopup = nil
break
end
if craftInfoPop and zone.id ~= "close_craft_info" and zone.id ~= "show_craft_info" and zone.id ~= "popup_bg" then
craftInfoPop = nil
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
if recipeEditPop and zone.id ~= "close_recipe_edit" and zone.id ~= "recipe_edit_select" and zone.id ~= "recipe_edit_apply" and zone.id ~= "recipe_edit_global" and zone.id ~= "recipe_edit_confirm_global" and zone.id ~= "recipe_edit_prev" and zone.id ~= "recipe_edit_next" and zone.id ~= "popup_bg" then
recipeEditPop = nil
break
end
if curTab == "QUANTITY_PICKER" then
local isQtyZone = zone.id == "qty_adj" or zone.id == "qty_confirm" or zone.id == "qty_cancel" or zone.id == "qty_max" or zone.id == "qty_type" or zone.id == "keep_field" or zone.id == "popup_bg" or zone.id == "qty_calc_max" or zone.id == "qty_toggle_automax" or zone.id == "qty_add_queue"
if not isQtyZone then
isRequestMode = false
isSettingKeep = false
altOutEdit = nil
if queueEditIdx then queueEditIdx = nil; queueEditPopup = true end
curTab = qtyOrigTab or "RECIPES"
break
end
end
if queueEditPopup and zone.id == "bg_click" then
queueEditPopup = false
queueErrIdx = nil
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
curTab = zone.arg; curPage = 1
mgmtPopup = nil
custGrpPopup = nil
if zone.arg == "STOCK" then stockFilter = ""; stockModFilter = "All"; stockFilterPage = 1 end
if zone.arg == "KEEP" then scanKeepNow() end
elseif zone.id == "set_mod" then
modFilter = zone.arg; curPage = 1
elseif zone.id == "mod_prev" then
modFilterPage = math.max(1, modFilterPage - 1)
elseif zone.id == "mod_next" then
modFilterPage = modFilterPage + 1
elseif _touchRecipes(zone, x, y) then
elseif _touchFluid(zone, x, y) then
elseif _touchNetwork(zone, x, y) then
elseif _touchKeep(zone, x, y) then
elseif _touchStock(zone, x, y) then
elseif _touchQty(zone, x, y) then
elseif _touchAdd(zone, x, y) then
elseif _touchGit(zone, x, y) then
elseif _touchMgmt(zone, x, y) then
end
break
end
end
end

local function mainLoop()
checkTimer = os.startTimer(6)
idleTimer   = os.startTimer(autostockIdle)
local lastTouchX, lastTouchY, lastTouchT = nil, nil, 0
local TOUCH_DEBOUNCE_MS = 200
while true do
local touchZones = drawUI()
term.clear() term.setCursorPos(1,1)
print("==========================================")
print(" STATUS: MONITOR DISPLAY ACTIVE ")
print("==========================================")
local isSearchTab = (curTab == "RECIPES" or curTab == "STOCK")
or (curTab == "FLUID" and (fluidSubTab == "FLUID" or fluidSubTab == "FITEM") and not fluidLearnStage and not fluidRecipePicker and not fluidWaitCraft)
if isSearchTab then
local sf, label
if curTab == "RECIPES" then sf, label = srchFilter, "RECIPES"
elseif curTab == "STOCK" then sf, label = stockFilter, "STOCK"
else sf, label = fluidSearchFilter, "FLUID" end
print("")
print(" [" .. label .. " SEARCH]")
if sf == "" then
print(" > _  (type to search)")
else
print(" > " .. sf .. "_")
end
end
if remoteRunFlag then
remoteRunFlag = false
if sysStatus == "IDLE" and #Craft.queue > 0 then runQueueAll() end
end
if remoteKeepRun then
remoteKeepRun = false
if sysStatus == "IDLE" and not Config.autostock_paused then runAutostock() end
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
if event == "monitor_touch" then
local now = os.epoch("utc")
if lastTouchX == param2 and lastTouchY == param3 and (now - lastTouchT) < TOUCH_DEBOUNCE_MS then
event = nil
else
lastTouchX, lastTouchY, lastTouchT = param2, param3, now
end
end
if event == "timer" and param1 == checkTimer then
checkTimer = os.startTimer(6)
elseif event == "timer" and param1 == uiMsgTimer then
uiMessage = ""
uiMsgTimer = nil
elseif event == "timer" and craftDonePopup and param1 == craftDonePopup.timer then
craftDonePopup = nil
elseif event == "timer" and unloadTimer and param1 == unloadTimer then
unloadActive = false
unloadTimer = nil
elseif event == "timer" and optTimer and param1 == optTimer then
optActive = false
optTimer = nil
elseif event == "timer" and scanTimer and param1 == scanTimer then
scanActive = false
scanTimer = nil
elseif event == "timer" and gitStTimer and param1 == gitStTimer then
gitStatus = ""; gitStColor = colors.gray; gitStTimer = nil
elseif event == "timer" and param1 == idleTimer then
if not Config.autostock_paused then
runAutostock()
end
idleTimer = os.startTimer(autostockIdle)
elseif event == "monitor_touch" then
_handleTouch(param2, param3, touchZones)
end
end
end
REMOTE_PROTOCOL = "aegis_remote"
remoteRunFlag = false
remoteKeepRun = false
stockEpoch = 0
craftResultId = 0
lastCraftMade = 0
-->90_entry/90_0_main_loop.lua
--<90_entry/90_2_touch_recipes.lua
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
-->90_entry/90_2_touch_recipes.lua
--<90_entry/90_3_touch_stock.lua
function _touchStock(zone, x, y)
if zone.id == "stock_mod" then
stockModFilter = zone.arg
curPage = 1
return true
elseif zone.id == "stock_mod_prev" then
stockFilterPage = math.max(1, stockFilterPage - 1)
return true
elseif zone.id == "stock_mod_next" then
stockFilterPage = stockFilterPage + 1
return true
elseif zone.id == "stock_search" then
stockSearchOn = true
drawUI()
term.clear() term.setCursorPos(1,1)
write("Stock search: ")
local stInput = timedRead(5)
stockSearchOn = false
if stInput ~= nil and stInput ~= "" then stockFilter = stInput end
curPage = 1
return true
elseif zone.id == "stock_clear_search" then
stockFilter = ""
curPage = 1
return true
elseif zone.id == "pull_from_box" then
local moved = pullTrainAll()
if moved > 0 then
resetStock()
uiMessage = "Unloaded " .. moved .. " items from train box"
else
uiMessage = "Train box is empty or not reachable"
end
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(3)
unloadActive = true
if unloadTimer then os.cancelTimer(unloadTimer) end
unloadTimer = os.startTimer(4)
return true
elseif zone.id == "stock_optimize" then
local isTankOpt = (stockModFilter == "TANK")
uiMessage = isTankOpt and "Optimizing tanks..." or "Optimizing storage..."
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(1)
optActive = true
if optTimer then os.cancelTimer(optTimer) end
drawUI()
if isTankOpt then optTanks() else optStore() end
resetStock()
uiMessage = isTankOpt and "Tanks optimized!" or "Storage optimized!"
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(3)
optTimer = os.startTimer(3)
return true
end
return false
end
-->90_entry/90_3_touch_stock.lua
--<90_entry/90_4_touch_keep.lua
function _touchKeep(zone, x, y)
if zone.id == "keep_cat" then
fluidKeepFilter = zone.arg
curPage = 1
return true
elseif zone.id == "force_autostock" then
if not Config.autostock_paused then
runAutostock()
end
return true
elseif zone.id == "keep_craft_now" then
local kItem = zone.arg
local kSet  = Keep.of(kItem)
if kSet and kItem:sub(1, 2) == "f:" then
local fname = fluidNameOf(kItem)
local cur   = (getFluid())[kItem] or 0
local need  = (kSet.target or kSet.limit) - cur
local kShort = shortName(fname)
if need > 0 then
local prods = fluidProducers(fname)
if prods[1] then
fluidCraft(prods[1].recipe, fname, need)
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
elseif kSet and Recipe.find(kItem) then
local kInv    = getInv()
local kStock  = kInv[kItem] or 0
local kNeeded = (kSet.target or kSet.limit) - kStock
local kShort  = shortName(kItem)
if kNeeded > 0 then
sysStatus = "MANUAL_CRAFT"
drawUI()
local kPlan, kMiss, _ = planProd(kItem, kNeeded, true)
if kPlan and #kPlan > 0 then
local kTarget = kSet.target or kSet.limit or 1
local kOk, kErr = pcall(function()
runCraft(kPlan)
local kAtt = 0
while not Craft.cancelled and kAtt < 12 do
local tNow = groupAvail(kItem, getInv())
if tNow >= kTarget then break end
kAtt = kAtt + 1
resetStock()
local rP = planProd(kItem, kTarget, true)
if not (rP and #rP > 0) then break end
local bK = tNow
runCraft(rP)
if groupAvail(kItem, getInv()) <= bK then break end
end
end)
sysStatus = "IDLE"
if kOk then
uiMessage = "Crafted: " .. kShort
else
uiMessage = "ERR: " .. tostring(kErr):sub(1, 30)
end
else
sysStatus = "IDLE"
uiMessage = "ERR: no resources for " .. kShort
end
else
uiMessage = kShort .. " already at target"
end
if uiMsgTimer then os.cancelTimer(uiMsgTimer) end
uiMsgTimer = os.startTimer(3)
scanKeepNow()
end
return true
elseif zone.id == "keep_top" or zone.id == "keep_up" or zone.id == "keep_dn" then
local fname = zone.arg
local isFl = (fname:sub(1, 2) == "f:")
local list = {}
for iName, s in pairs(Keep.all()) do
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
local ent = Keep.of(e.name)
if ent then ent.order = slots[i] end
end
saveData()
end
return true
elseif zone.id == "toggle_keep_status" then
local ent = Keep.of(zone.arg)
if ent then
ent.paused = not ent.paused
saveData()
end
return true
elseif zone.id == "remove_keep" then
Keep.remove(zone.arg)
local remaining = {}
for iName, s in pairs(Keep.all()) do
table.insert(remaining, {name=iName, order=s.order or 99999})
end
table.sort(remaining, function(a,b) return a.order < b.order end)
for ni, ri in ipairs(remaining) do Keep.of(ri.name).order = ni end
saveData()
return true
elseif zone.id == "open_keep_picker" then
itemToCraft = zone.arg
fluidCraftMode = nil
fluidKeepName = nil
local ex = Keep.of(zone.arg)
keepThr = (ex and (ex.threshold or ex.limit)) or 64
keepTgt = (ex and (ex.target or ex.limit)) or (keepThr * 2)
keepField = "threshold"
isSettingKeep = true
isRequestMode = false
qtyOrigTab = "RECIPES"
curTab = "QUANTITY_PICKER"
return true
elseif zone.id == "keep_edit" then
itemToCraft = zone.arg
local ex = Keep.of(zone.arg)
keepThr = (ex and (ex.threshold or ex.limit)) or 64
keepTgt = (ex and (ex.target or ex.limit)) or (keepThr * 2)
keepField = "threshold"
isSettingKeep = true
isRequestMode = false
fluidKeepName = (zone.arg:sub(1, 2) == "f:") and fluidNameOf(zone.arg) or nil
qtyOrigTab = "KEEP"
curTab = "QUANTITY_PICKER"
return true
elseif zone.id == "keep_field" then
keepField = zone.arg
return true
end
return false
end
-->90_entry/90_4_touch_keep.lua
--<90_entry/90_5_touch_network.lua
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
if c[key] == zone.arg and c[sideKey] and r and r.setOutput then pcall(r.setOutput, c[sideKey], false) end
if nextSide then
c[key], c[sideKey] = zone.arg, nextSide
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
Config.storages[zone.arg] = nil
if Config.train_box == zone.arg then Config.train_box = nil end
end
saveData()
return true
end
return false
end
-->90_entry/90_5_touch_network.lua
--<90_entry/90_6_touch_qty.lua
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
-->90_entry/90_6_touch_qty.lua
--<90_entry/90_7_touch_add.lua
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
-->90_entry/90_7_touch_add.lua
--<90_entry/90_8_touch_fluid.lua
function _touchFluid(zone, x, y)
if zone.id == "fluid_subtab" then
fluidSubTab = zone.arg
fluidTankPage = 1
fluidRecipePage = 1
return true
elseif zone.id == "fluid_tank_prev" then
fluidTankPage = math.max(1, fluidTankPage - 1)
return true
elseif zone.id == "fluid_tank_next" then
fluidTankPage = fluidTankPage + 1
return true
elseif zone.id == "fluid_recipe_prev" then
fluidRecipePage = math.max(1, fluidRecipePage - 1)
return true
elseif zone.id == "fluid_recipe_next" then
fluidRecipePage = fluidRecipePage + 1
return true
elseif zone.id == "fluid_delete_ask" then
pendDelFluid = zone.arg
return true
elseif zone.id == "fluid_delete_cancel" then
pendDelFluid = nil
return true
elseif zone.id == "fluid_delete_confirm" then
local prods = fluidProducers(zone.arg)
if prods[1] then removeFluidRef(prods[1].recipe) end
pendDelFluid = nil
syncFluidStubs()
saveData()
return true
elseif zone.id == "open_keep_picker_fluid" then
local fk = fluidKey(zone.arg)
if Keep.of(fk) then
Keep.remove(fk)
saveData()
else
fluidCraftMode = nil
fluidKeepName = zone.arg
itemToCraft = fk
keepThr = 1000
keepTgt = 2000
keepField = "threshold"
isSettingKeep = true
isRequestMode = false
qtyOrigTab = "RECIPES"
curTab = "QUANTITY_PICKER"
end
return true
elseif zone.id == "open_recipe_edit_fluid" then
local prods = fluidProducers(zone.arg)
local p = prods[1]
if p then
recipeEditPop = {
fluid = zone.arg, fluidRecipeRef = p.recipe,
origMachine = p.recipe.machine_name, selected = p.recipe.machine_name,
confirmGlobal = false, page = 1,
}
end
return true
elseif zone.id == "fluid_craft" then
local prods = fluidProducers(zone.arg)
if prods[1] then fluidCraftFlow(prods[1].recipe, zone.arg) end
return true
elseif zone.id == "fluid_alt" then
altViewFluid = zone.arg
altViewItem = nil
curTab = "ALT_VIEW"
return true
elseif zone.id == "fluid_pick_recipe" then
if fluidRecipePicker then
local p = fluidRecipePicker.producers[zone.arg]
local fname = fluidRecipePicker.fluid
if p then fluidCraftFlow(p.recipe, fname) end
end
return true
elseif zone.id == "fluid_make_primary" then
if fluidRecipePicker then
local p = fluidRecipePicker.producers[zone.arg]
if p and p.own and not p.isPrimary and p.altIdx then
local fk = p.key
local alts = Fluids.altsOf(fk) or {}
local chosen = table.remove(alts, p.altIdx)
local old = Fluids.find(fk)
Fluids.set(fk, chosen)
if old then table.insert(alts, 1, old) end
if #alts == 0 then alts = nil end
Fluids.setAlts(fk, alts)
syncFluidStubs()
saveData()
fluidRecipePicker.producers = fluidProducers(fluidRecipePicker.fluid)
end
end
return true
elseif zone.id == "fluid_picker_delete" then
if fluidRecipePicker then
local p = fluidRecipePicker.producers[zone.arg]
if p and p.own then
local fk = p.key
if p.isPrimary then
local alts = Fluids.altsOf(fk)
if alts and alts[1] then
Fluids.set(fk, table.remove(alts, 1))
if #alts == 0 then Fluids.setAlts(fk, nil) end
else
Fluids.remove(fk)
end
elseif p.altIdx then
local alts = Fluids.altsOf(fk)
if alts then
table.remove(alts, p.altIdx)
if #alts == 0 then Fluids.setAlts(fk, nil) end
end
end
syncFluidStubs()
saveData()
local prods = fluidProducers(fluidRecipePicker.fluid)
if #prods == 0 then fluidRecipePicker = nil
else fluidRecipePicker.producers = prods end
end
end
return true
elseif zone.id == "fluid_picker_close" then
fluidRecipePicker = nil
return true
elseif zone.id == "fluid_save_yes" then
if fluidSaveConfirm then
local sc = fluidSaveConfirm
if sc.asAlt then
local list = Fluids.altsOf(sc.key) or {}
table.insert(list, sc.recipe)
Fluids.setAlts(sc.key, list)
else
Fluids.set(sc.key, sc.recipe)
end
syncFluidStubs()
saveData()
fluidLearnStage = "PICK_INPUT"
learnInputs = {}
learnMach = nil
clearFluidDevs()
fluidLearnPage = 1
local prod = {}
for _, o in ipairs(sc.recipe.outputs or {}) do prod[#prod + 1] = {name = o.name, amount = o.amount, unit = "mB"} end
for _, o in ipairs(sc.recipe.item_outputs or {}) do prod[#prod + 1] = {name = o.name, amount = o.count, unit = "x"} end
fluidSaveConfirm = nil
craftDonePopup = {learned = true, outputs = prod, timer = os.startTimer(10)}
end
return true
elseif zone.id == "fluid_save_no" then
fluidSaveConfirm = nil
fluidLearnStage = "PICK_INPUT"
learnInputs = {}
learnMach = nil
clearFluidDevs()
fluidLearnPage = 1
return true
elseif zone.id == "fluid_trigger_search" then
isSearch = true
drawUI()
term.clear() term.setCursorPos(1, 1)
write("Enter fluid search: ")
local srInput = timedRead(5)
isSearch = false
if srInput ~= nil then fluidSearchFilter = srInput end
fluidRecipePage = 1
return true
elseif zone.id == "fluid_clear_search" then
fluidSearchFilter = ""
fluidRecipePage = 1
return true
elseif zone.id == "fluid_add" then
fluidCraftMsg = ""
fluidLearnStage = "PICK_INPUT"
learnInputs = {}
learnMach = nil
clearFluidDevs()
fluidLearnPage = 1
fluidScanStatus = ""
return true
elseif zone.id == "fluid_learn_cancel" then
fluidLearnStage = nil
learnInputs = {}
learnMach = nil
clearFluidDevs()
fluidLearnPage = 1
fluidScanStatus = ""
return true
elseif zone.id == "fluid_learn_prev" then
fluidLearnPage = math.max(1, fluidLearnPage - 1)
return true
elseif zone.id == "fluid_learn_next" then
fluidLearnPage = fluidLearnPage + 1
return true
elseif zone.id == "fluid_pick_input" then
local existIdx = nil
for i, inp in ipairs(learnInputs) do
if inp.name == zone.arg then existIdx = i; break end
end
if existIdx then
table.remove(learnInputs, existIdx)
elseif #learnInputs < 5 then
qtyTypeAct = true
fluidWaitInput = zone.arg
drawUI()
term.clear(); term.setCursorPos(1, 1)
print("Enter mB for:")
print(zone.arg)
write("> ")
local input = timedRead(30)
fluidWaitInput = nil
qtyTypeAct = false
local num = tonumber(input)
if num and num > 0 then
learnInputs[#learnInputs + 1] = {name = zone.arg, amount = math.floor(num)}
end
end
return true
elseif zone.id == "fluid_learn_done_inputs" then
fluidLearnStage = "PICK_MACHINE"
fluidLearnPage = 1
return true
elseif zone.id == "fluid_learn_back_inputs" then
fluidLearnStage = "PICK_INPUT"
clearFluidDevs()
fluidLearnPage = 1
return true
elseif zone.id == "fluid_pick_machine" then
if fluidOutPick then
learnOut = zone.arg; fluidOutPick = false
elseif fluidItemInPick then
learnItemIn = zone.arg; fluidItemInPick = false
elseif fluidInPick then
learnFluidIn = zone.arg; fluidInPick = false
elseif itemOutPick then
learnItemOut = zone.arg; itemOutPick = false
elseif learnMach == zone.arg then
learnMach = nil
clearFluidDevs()
else
learnMach = zone.arg
end
return true
elseif zone.id == "fluid_pull_toggle" then
fluidItemInPick = false; fluidInPick = false; itemOutPick = false
if fluidOutPick then fluidOutPick = false
elseif learnOut then learnOut = nil
else fluidOutPick = true end
return true
elseif zone.id == "fluid_iteminput_toggle" then
fluidOutPick = false; fluidInPick = false; itemOutPick = false
if fluidItemInPick then fluidItemInPick = false
elseif learnItemIn then learnItemIn = nil
else fluidItemInPick = true end
return true
elseif zone.id == "fluid_fluidin_toggle" then
fluidOutPick = false; fluidItemInPick = false; itemOutPick = false
if fluidInPick then fluidInPick = false
elseif learnFluidIn then learnFluidIn = nil
else fluidInPick = true end
return true
elseif zone.id == "fluid_itemout_toggle" then
fluidOutPick = false; fluidItemInPick = false; fluidInPick = false
if itemOutPick then itemOutPick = false
elseif learnItemOut then learnItemOut = nil
else itemOutPick = true end
return true
elseif zone.id == "fluid_learn_scan" and learnMach then
sysStatus = "MANUAL_CRAFT"
Craft.cancelled = false
fluidScanStatus = "Scanning: waiting for mix (tap CANCEL to stop)..."
drawUI()
local okScan, recipe, errLines = runFluidScan(learnInputs, learnMach, learnOut, learnItemIn, learnFluidIn, learnItemOut)
sysStatus = "IDLE"
fluidScanStatus = ""
Craft.cancelled = false
craftCancelY = nil
if okScan and recipe then
local fk = primaryKey(recipe)
local asAlt = (Fluids.find(fk) ~= nil)
fluidSaveConfirm = {recipe = recipe, key = fk, asAlt = asAlt}
else
craftErrTitle = "! FLUID SCAN FAILED"
craftErrLines = errLines or {"Unknown error"}
end
return true
elseif zone.id == "show_fluid_info" then
local prods = fluidProducers(zone.arg)
local perOp = (prods[1] and prods[1].perOp) or 1
local fStock = {}
for k, v in pairs(getInv()) do fStock[k] = v end
fStock[fluidKey(zone.arg)] = 0
local fMiss = {}
simFluidConsume(zone.arg, perOp, fStock, fMiss, {}, {})
fluidCraftInfo = {name = zone.arg, missing = fMiss}
return true
elseif zone.id == "close_fluid_info" then
fluidCraftInfo = nil
return true
end
return false
end
-->90_entry/90_8_touch_fluid.lua
--<90_entry/91_0_touch_mgmt.lua
local function toggleMgmtPeri(field, name)
if not mgmtPopup then return end
local listKey = field .. "s"
local lst = mgmtPopup[listKey] or {}
if name == "STORAGE" then
lst = {}
else
local found
for i, nm in ipairs(lst) do if nm == name then found = i; break end end
if found then table.remove(lst, found) else lst[#lst + 1] = name end
end
mgmtPopup[listKey] = lst
mgmtPopup[field]   = lst[1] or "STORAGE"
mgmtPopup.fluid = isFluidPeri(mgmtPopup.input) or isFluidPeri(mgmtPopup.output)
end

local function closeMgmtPopup()
if mgmtPopup and mgmtPopup.openerGi and mgmtPopup.openerBtn then
mgmtActBtn = {gi=mgmtPopup.openerGi, btn=mgmtPopup.openerBtn, t=os.clock()}
end
mgmtPopup = nil
end

function _touchMgmt(zone, x, y)
if zone.id == "mgmt_sync_now" then
syncFlashTime = os.clock()
runMgmtTransfers()
return true
elseif zone.id == "mgmt_new" then
mgmtPopup = {
mode="edit", groupIdx=nil,
name="", input="STORAGE", output="STORAGE", rules={},
inputs={}, outputs={},
drain=false, provider=false,
step="main", periPage=1, outPeriPage=1, itemPage=1,
}
return true
elseif zone.id == "mgmt_edit" then
local g = MgmtGroups[zone.arg]
if g then
mgmtActBtn = nil
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
fluid  = isFluid(g),
step="main", periPage=1, outPeriPage=1, itemPage=1,
openerGi=zone.arg, openerBtn="edit",
}
end
return true
elseif zone.id == "mgmt_pause" then
local g = MgmtGroups[zone.arg]
if g then
g.paused = not (g.paused or false)
mgmtActBtn = {gi=zone.arg, btn="pause", t=os.clock()}
saveData()
end
return true
elseif zone.id == "mgmt_del" then
mgmtActBtn = nil
table.remove(MgmtGroups, zone.arg)
saveData()
return true
elseif zone.id == "mgmt_view" then
local g = MgmtGroups[zone.arg]
if g then
mgmtActBtn = nil
mgmtPopup = {mode="view_input", groupIdx=zone.arg, page=1,
openerGi=zone.arg, openerBtn="view"}
end
return true
elseif zone.id == "mgmt_list_prev" then
mgmtPage = math.max(1, mgmtPage - 1)
return true
elseif zone.id == "mgmt_list_next" then
mgmtPage = mgmtPage + 1
return true
elseif zone.id == "mgmt_edit_name" then
if mgmtPopup then
drawUI()
term.clear(); term.setCursorPos(1,1)
write("Group name: ")
local inp = read()
if inp and inp ~= "" then mgmtPopup.name = inp end
end
return true
elseif zone.id == "mgmt_rule_type" then
if mgmtPopup then
local ri3t = zone.arg
local rule = mgmtPopup.rules[ri3t]
if rule then
drawUI()
term.clear(); term.setCursorPos(1,1)
write("Amount for " .. (shortName(rule.item)) .. ": ")
local inp = read()
local n = tonumber(inp)
if n and n >= 1 then rule.amount = math.floor(n) end
end
end
return true
elseif zone.id == "mgmt_pick_input" then
if mgmtPopup then mgmtPopup.step = "input_select"; mgmtPopup.periPage = 1 end
return true
elseif zone.id == "mgmt_set_input" then
toggleMgmtPeri("input", zone.arg)
return true
elseif zone.id == "mgmt_peri_prev" then
if mgmtPopup then mgmtPopup.periPage = math.max(1, mgmtPopup.periPage - 1) end
return true
elseif zone.id == "mgmt_peri_next" then
if mgmtPopup then mgmtPopup.periPage = mgmtPopup.periPage + 1 end
return true
elseif zone.id == "mgmt_peri_cancel" then
if mgmtPopup then mgmtPopup.step = "main" end
return true
elseif zone.id == "mgmt_pick_output" then
if mgmtPopup then mgmtPopup.step = "output_select"; mgmtPopup.outPeriPage = 1 end
return true
elseif zone.id == "mgmt_set_output" then
toggleMgmtPeri("output", zone.arg)
return true
elseif zone.id == "mgmt_pick_item" then
if mgmtPopup then
mgmtPopup.step = "item_select"; mgmtPopup.itemPage = 1
mgmtItemSrch = ""; mgmtSearchOn = false
end
return true
elseif zone.id == "mgmt_add_rule" then
if mgmtPopup then
local condIdx = mgmtPopup.condRuleIdx
if condIdx then
local rule = mgmtPopup.rules[condIdx]
if rule then
if not rule.condition then rule.condition = {op="<", value=1} end
rule.condition.item = zone.arg
end
mgmtPopup.condRuleIdx = nil
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
return true
elseif zone.id == "mgmt_item_prev" then
if mgmtPopup then mgmtPopup.itemPage = math.max(1, mgmtPopup.itemPage - 1) end
return true
elseif zone.id == "mgmt_item_next" then
if mgmtPopup then mgmtPopup.itemPage = mgmtPopup.itemPage + 1 end
return true
elseif zone.id == "mgmt_rules_prev" then
if mgmtPopup then mgmtPopup.rulesPage = math.max(1, (mgmtPopup.rulesPage or 1) - 1) end
return true
elseif zone.id == "mgmt_rules_next" then
if mgmtPopup then mgmtPopup.rulesPage = (mgmtPopup.rulesPage or 1) + 1 end
return true
elseif zone.id == "mgmt_item_cancel" then
if mgmtPopup then
mgmtPopup.condRuleIdx = nil
mgmtPopup.step = "main"
end
return true
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
return true
elseif zone.id == "mgmt_rule_del" then
if mgmtPopup then table.remove(mgmtPopup.rules, zone.arg) end
return true
elseif zone.id == "mgmt_toggle_drain" then
if mgmtPopup then
mgmtPopup.drain = not (mgmtPopup.drain or false)
if mgmtPopup.drain then mgmtPopup.provider = false end
end
return true
elseif zone.id == "mgmt_toggle_provider" then
if mgmtPopup then
mgmtPopup.provider = not (mgmtPopup.provider or false)
if mgmtPopup.provider then mgmtPopup.drain = false end
end
return true
elseif zone.id == "mgmt_rule_if_add" then
if mgmtPopup then
local ri = zone.arg
local rule = mgmtPopup.rules[ri]
if rule then
rule.condition = {item = "", op = "<", value = 1}
mgmtPopup.condRuleIdx = ri
mgmtPopup.step = "item_select"
mgmtPopup.itemPage = 1
mgmtItemSrch = ""
mgmtSearchOn = false
end
end
return true
elseif zone.id == "mgmt_rule_if_item" then
if mgmtPopup then
mgmtPopup.condRuleIdx = zone.arg
mgmtPopup.step = "item_select"
mgmtPopup.itemPage = 1
mgmtItemSrch = ""
mgmtSearchOn = false
end
return true
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
return true
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
return true
elseif zone.id == "mgmt_rule_if_type" then
if mgmtPopup then
local rule = mgmtPopup.rules[zone.arg]
if rule and rule.condition then
local cName = shortName(rule.condition.item)
drawUI()
term.clear(); term.setCursorPos(1,1)
write("IF value for " .. cName .. ": ")
local inp = read()
local n = tonumber(inp)
if n and n >= 1 then rule.condition.value = math.floor(n) end
end
end
return true
elseif zone.id == "mgmt_rule_if_del" then
if mgmtPopup then
local rule = mgmtPopup.rules[zone.arg]
if rule then rule.condition = nil end
end
return true
elseif zone.id == "mgmt_outperi_prev" then
if mgmtPopup then mgmtPopup.outPeriPage = math.max(1, (mgmtPopup.outPeriPage or 1) - 1) end
return true
elseif zone.id == "mgmt_outperi_next" then
if mgmtPopup then mgmtPopup.outPeriPage = (mgmtPopup.outPeriPage or 1) + 1 end
return true
elseif zone.id == "mgmt_outperi_cancel" then
if mgmtPopup then mgmtPopup.step = "main" end
return true
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
fluid  = mgmtPopup.fluid or isFluid({input=inl[1] or "STORAGE", output=outl[1] or "STORAGE"}),
paused = mgmtPopup.groupIdx and (MgmtGroups[mgmtPopup.groupIdx] and MgmtGroups[mgmtPopup.groupIdx].paused or false) or false,
}
if mgmtPopup.groupIdx then
MgmtGroups[mgmtPopup.groupIdx] = newG
else
table.insert(MgmtGroups, newG)
end
saveData()
closeMgmtPopup()
end
end
return true
elseif zone.id == "mgmt_cancel" then
closeMgmtPopup()
return true
elseif zone.id == "mgmt_close_view" then
closeMgmtPopup()
return true
elseif zone.id == "mgmt_vinput_prev" then
if mgmtPopup then mgmtPopup.page = math.max(1, mgmtPopup.page - 1) end
return true
elseif zone.id == "mgmt_vinput_next" then
if mgmtPopup then mgmtPopup.page = mgmtPopup.page + 1 end
return true
elseif zone.id == "mgmt_search_focus" then
mgmtSearchOn = true
drawUI()
term.clear() term.setCursorPos(1,1)
write("> ")
local srInput = timedRead(5)
mgmtSearchOn = false
if srInput ~= nil then
mgmtItemSrch = srInput
end
if mgmtPopup then mgmtPopup.itemPage = 1 end
return true
elseif zone.id == "mgmt_search_clear" then
mgmtItemSrch = ""
if mgmtPopup then mgmtPopup.itemPage = 1 end
return true
end
return false
end
-->90_entry/91_0_touch_mgmt.lua
--<90_entry/91_1_touch_git.lua
local function promptField(activeId, prompt, masked)
gitActiveBtn = activeId
drawUI()
term.clear(); term.setCursorPos(1,1)
write(prompt)
local input = masked and read("*") or read()
gitActiveBtn = ""
return input
end

local function promptNewExportName()
local defName = "autocraft_" .. tostring(math.floor(os.epoch("utc") / 1000))
gitStatus = "Type filename on PC keyboard..."
gitStColor = colors.yellow
drawUI()
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
gitStatus = ""; gitStColor = colors.gray
if fname and fname ~= "" then
fname = fname:gsub("%.json$", "") .. ".json"
gitExport(fname, nil)
end
end

function _touchGit(zone, x, y)
if zone.id == "git_set_repo" then
local input = promptField("git_set_repo", "GitHub repo (owner/repo): ", true)
if input and input ~= "" then Config.github_repo = input; saveData() end
return true
elseif zone.id == "git_set_token" then
local input = promptField("git_set_token", "GitHub token (ghp_...): ", true)
if input and input ~= "" then Config.github_token = input; saveData() end
return true
elseif zone.id == "git_set_ntfy" then
local input = promptField("git_set_ntfy", "ntfy topic or full URL (empty = off): ", false)
Config.ntfy_topic = (input and input ~= "") and input or nil
saveData()
return true
elseif zone.id == "log_toggle" then
if Config.debug_log == true then
Config.debug_log = false
DBG_LOG_ENABLED = false
dbgWipe()
uiMessage = "Debug log OFF (files wiped)"
else
Config.debug_log = true
DBG_LOG_ENABLED = true
uiMessage = "Debug log ON"
end
saveData()
return true
elseif zone.id == "git_export" then
gitActiveBtn = "git_export"
gitListForExport()
gitActiveBtn = ""
return true
elseif zone.id == "git_export_select" then
gitExportSel = zone.arg
if zone.arg == 0 then promptNewExportName() end
return true
elseif zone.id == "git_confirm_export" then
if gitExportSel == 0 then
promptNewExportName()
else
gitExportMode = false
local file = gitExportList[gitExportSel]
if file then gitExport(file.name, file.sha) end
end
return true
elseif zone.id == "git_cancel_export" then
gitExportMode = false
gitExportList = {}
gitExportSel = 0
gitStatus = ""; gitStColor = colors.gray
return true
elseif zone.id == "git_import_list" then
gitActiveBtn = "git_import_list"
gitListFiles()
gitActiveBtn = ""
return true
elseif zone.id == "git_select_file" then
gitSelFile = zone.arg
return true
elseif zone.id == "git_import_prev" then
gitImportPage = math.max(1, gitImportPage - 1)
return true
elseif zone.id == "git_import_next" then
gitImportPage = gitImportPage + 1
return true
elseif zone.id == "git_export_prev" then
gitExportPage = math.max(1, gitExportPage - 1)
return true
elseif zone.id == "git_export_next" then
gitExportPage = gitExportPage + 1
return true
elseif zone.id == "git_confirm_import" then
gitImport()
return true
elseif zone.id == "git_cancel_import" then
gitImportMode = false
gitFileList = {}
gitStatus = ""
gitStColor = colors.gray
return true
end
return false
end
-->90_entry/91_1_touch_git.lua
--<90_entry/98_0_api_bind.lua

aegis.storage.count = function(name) return groupAvail(name, getInvCached()) end
aegis.storage.list  = getInvCached

aegis.recipes.get   = Recipe.find
aegis.recipes.list  = Recipe.all
aegis.recipes.alts  = Recipe.altsOf

aegis.fluids.get       = Fluids.find
aegis.fluids.list      = Fluids.all
aegis.fluids.producers = fluidProducers
aegis.fluids.inventory = getFluidCached

aegis.craft.max = remoteMax

function aegis.craft.canMake(name, count)
return remoteMax(name) >= (tonumber(count) or 1)
end

function aegis.craft.start(name, count, opts)
if type(name) ~= "string" then return nil, "bad name" end
local qty = math.max(1, math.floor(tonumber(count) or 1))
if Recipe.find(name) then
Craft.queue[#Craft.queue + 1] = { kind = "item", name = name, qty = qty }
else
local prod = fluidProducers(name)
if not (prod and prod[1] and prod[1].recipe) then
return nil, "no recipe: " .. name
end
Craft.queue[#Craft.queue + 1] = { kind = "fluid", name = name, qty = qty, recipe = prod[1].recipe }
end
if not opts or opts.run ~= false then remoteRunFlag = true end
return #Craft.queue
end

aegis.jobs.status = buildRemote
aegis.jobs.queue  = function() return Craft.queue end

function aegis.jobs.cancel(idx)
if idx == nil then Craft.cancelled = true; return true end
local qi = tonumber(idx)
if qi and Craft.queue[qi] then table.remove(Craft.queue, qi); return true end
return false
end
-->90_entry/98_0_api_bind.lua
--<90_entry/99_0_entry.lua
local function runMain()
initData()
loadData()
syncFluidStubs()
openRemote()
dbgInit()
if _DEV_MODE and not getmetatable(_G) then
local seen = {}
for k in pairs(_G) do seen[k] = true end
setmetatable(_G, {__newindex = function(t, k, v)
if not seen[k] then
seen[k] = true
local fh = fs.open("dev_globals.log", "a")
if fh then fh.writeLine(os.clock() .. " " .. tostring(k)); fh.close() end
end
rawset(t, k, v)
end})
end
parallel.waitForAny(
function()
while true do
local ev, p1, p2, p3 = os.pullEvent("monitor_touch")
if sysStatus == "IDLE" then
pendingTouches[#pendingTouches + 1] = {ev, p1, p2, p3}
if #pendingTouches > 5 then table.remove(pendingTouches, 1) end
end
end
end,
function()
while true do
local ev, ch = os.pullEvent()
local noPopup = not custGrpPopup and not mgmtPopup
and craftInfoPop == nil and machInfoPopup == nil
and historyPopup == nil and recipeEditPop == nil
and craftDonePopup == nil and pendDelItem == nil
local fluidSearchable = curTab == "FLUID" and (fluidSubTab == "FLUID" or fluidSubTab == "FITEM")
and not fluidLearnStage and not fluidRecipePicker and not fluidWaitCraft
if ev == "char" and noPopup then
if curTab == "RECIPES" then
srchFilter = srchFilter .. ch
curPage = 1
elseif curTab == "STOCK" then
stockFilter = stockFilter .. ch
curPage = 1
elseif fluidSearchable then
fluidSearchFilter = fluidSearchFilter .. ch
fluidRecipePage = 1
end
elseif ev == "key" and noPopup and ch == keys.backspace then
if curTab == "RECIPES" and #srchFilter > 0 then
srchFilter = srchFilter:sub(1, -2)
curPage = 1
elseif curTab == "STOCK" and #stockFilter > 0 then
stockFilter = stockFilter:sub(1, -2)
curPage = 1
elseif fluidSearchable and #fluidSearchFilter > 0 then
fluidSearchFilter = fluidSearchFilter:sub(1, -2)
fluidRecipePage = 1
end
end
end
end,
function()
while true do
local sid, msg = rednet.receive(REMOTE_PROTOCOL)
if type(msg) == "table" and msg.cmd then pcall(handleRemote, sid, msg) end
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
pcall(ntfyPoll)
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
-->90_entry/99_0_entry.lua

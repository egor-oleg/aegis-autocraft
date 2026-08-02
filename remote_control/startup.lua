local PROTOCOL = "aegis_miner"
local STATE_FILE = "miner_pocket.json"
local PULL_SECS = 3
local LINK_SECS = 12
local TABS = { "FLEET", "ZONES", "FILTER", "YIELD" }
local SHORT = { FLEET = "FLT", ZONES = "ZON", FILTER = "FIL", YIELD = "YLD" }
local TAG = {
mining = "MINE", returning = "RETN", deposit = "DROP", queued = "WAIT", waiting = "WAIT",
refuel = "FUEL", paused = "HOLD", idle = "IDLE", offline = "OFF ", stranded = "STUK", nofuel = "DRY "
}
local TAG_COLOR = {
mining = colors.lime, returning = colors.cyan, deposit = colors.yellow, queued = colors.orange,
waiting = colors.orange, refuel = colors.yellow, paused = colors.orange, idle = colors.lightGray,
offline = colors.red, stranded = colors.red, nofuel = colors.red
}

Snap = nil
Host = nil
tab = "FLEET"
page = 1
pick = nil
zone = nil
lastSnap = 0
armRecall = false
hits = {}
Buf = {}
BW, BH = 26, 20
colour = term.isColour()

function bufInit(w, h)
BW, BH = w, h
for y = 1, h do
local row = Buf[y]
if not row then row = { t = {}, f = {}, b = {} } Buf[y] = row end
for x = 1, w do
row.t[x] = " "
row.f[x] = "0"
row.b[x] = "f"
end
end
end

function put(x, y, text, fg, bg)
if y < 1 or y > BH then return end
bg = bg or colors.black
fg = fg or colors.white
if not colour then
if bg == colors.black then fg = colors.white else fg, bg = colors.black, colors.white end
end
local f, b = colors.toBlit(fg), colors.toBlit(bg)
local row = Buf[y]
for i = 1, #text do
local cx = x + i - 1
if cx >= 1 and cx <= BW then
row.t[cx] = text:sub(i, i)
row.f[cx] = f
row.b[cx] = b
end
end
end

function flush()
for y = 1, BH do
term.setCursorPos(1, y)
term.blit(table.concat(Buf[y].t), table.concat(Buf[y].f), table.concat(Buf[y].b))
end
end

function bar(x, y, text, fg, bg, id, arg)
put(x, y, text, fg, bg)
hits[#hits + 1] = { id = id, arg = arg, x1 = x, x2 = x + #text - 1, y = y }
return x + #text
end

function saveState()
local fh = fs.open(STATE_FILE, "w")
if not fh then return end
fh.write(textutils.serializeJSON({ host = Host, tab = tab }))
fh.close()
end

function loadState()
if not fs.exists(STATE_FILE) then return end
local fh = fs.open(STATE_FILE, "r")
if not fh then return end
local data = fh.readAll()
fh.close()
local ok, s = pcall(textutils.unserializeJSON, data or "")
if not ok or type(s) ~= "table" then return end
Host = s.host
if s.tab then tab = s.tab end
end

function openRednet()
local modem = peripheral.find("modem")
if not modem then return false end
rednet.open(peripheral.getName(modem))
return true
end

function ask(id, arg)
local msg = { cmd = "remote_pull" }
if id then msg = { cmd = "remote_do", id = id, arg = arg } end
if Host and linked() then rednet.send(Host, msg, PROTOCOL) else rednet.broadcast(msg, PROTOCOL) end
end

function linked()
return Snap ~= nil and os.clock() - lastSnap < LINK_SECS
end

function shortName(name)
return name:match(":(.+)$") or name
end

function fuelText(n)
if n >= 10000 then return string.format("%4.1fk", n / 1000) end
return string.format("%5d", n)
end

function perPage(top)
return math.max(1, BH - 1 - (top or 4))
end

function paging(count, span, top)
local per = math.max(1, math.floor(perPage(top) / (span or 1)))
local pages = math.max(1, math.ceil(count / per))
if page > pages then page = pages end
if page < 1 then page = 1 end
local first = (page - 1) * per + 1
return first, math.min(count, first + per - 1), pages
end

function drawHead()
local fleet = Snap and Snap.fleet or {}
local live = 0
for _, t in ipairs(fleet) do if t.status ~= "offline" then live = live + 1 end end
put(1, 1, "C.A.V.E", colors.lime)
if not linked() then
put(9, 1, "no link", colors.red)
return
end
put(9, 1, live .. "/" .. #fleet, colors.white)
put(14, 1, "G" .. (Snap.gps or 0) .. "/4", (Snap.gps or 0) >= 4 and colors.lime or colors.red)
put(19, 1, "F" .. math.floor((Snap.supply or 0) / 1000) .. "k", colors.yellow)
end

function drawTabs()
local total = -1
for _, name in ipairs(TABS) do total = total + #SHORT[name] + 3 end
local x = math.max(1, math.floor((BW - total) / 2) + 1)
for _, name in ipairs(TABS) do
local on = tab == name
x = bar(x, 2, " " .. SHORT[name] .. " ", on and colors.black or colors.lightGray,
on and colors.lime or colors.gray, "tab", name) + 1
end
put(1, 3, string.rep("-", BW), colors.gray)
end

function drawPager(pages)
local y = BH - 1
put(1, y, string.rep("-", BW), colors.gray)
if pages <= 1 then return end
if page > 1 then bar(1, y, " < ", colors.black, colors.lightGray, "prev", page - 1) end
local caption = page .. "/" .. pages
put(math.floor((BW - #caption) / 2) + 1, y, caption, colors.lime)
if page < pages then bar(BW - 2, y, " > ", colors.black, colors.lightGray, "next", page + 1) end
end

function drawNote()
local text = Snap and Snap.note or ""
if not linked() then text = "searching for controller" end
put(1, BH, text:sub(1, BW), colors.lightGray)
end

function drawFleet()
local list = Snap.fleet
table.sort(list, function(a, b)
local pa = (a.status == "offline" or a.status == "nofuel") and 0 or 1
local pb = (b.status == "offline" or b.status == "nofuel") and 0 or 1
if pa ~= pb then return pa < pb end
return (a.id or 0) < (b.id or 0)
end)
if #list == 0 then
put(1, 5, "no turtles registered", colors.gray)
return
end
if armRecall then
bar(1, 4, " SURE? ", colors.black, colors.red, "fleet_recall")
bar(9, 4, " CANCEL ", colors.white, colors.gray, "arm_no")
else
bar(1, 4, " RECALL ALL ", colors.black, colors.cyan, "arm_recall")
end
local first, last, pages = paging(#list, 2, 5)
local y = 5
for i = first, last do
local t = list[i]
local status = t.status or "idle"
bar(1, y, string.format("#%-3s", t.id), colors.white, colors.black, "turtle", t.id)
put(5, y, TAG[status] or "????", TAG_COLOR[status] or colors.lightGray)
put(10, y, fuelText(t.fuel or 0), (t.fuel or 0) < 1000 and colors.red or colors.lime)
put(16, y, string.format("%3d%%", t.inv or 0), (t.inv or 0) >= 90 and colors.orange or colors.lightGray)
put(21, y, string.format("%3d%%", t.prog or 0), colors.cyan)
local at = t.pos
local where = at and (at.x .. " " .. at.y .. " " .. at.z) or "no position yet"
bar(2, y + 1, where:sub(1, 15), colors.lightGray, colors.black, "turtle", t.id)
local slot = tostring(t.slot or "-")
put(BW - #slot, y + 1, slot:sub(1, 9), colors.gray)
y = y + 2
end
drawPager(pages)
end

function turtleById(id)
for _, t in ipairs(Snap.fleet) do
if t.id == id then return t end
end
end

function drawPick()
local t = turtleById(pick)
if not t then pick = nil return end
bar(1, 4, "#" .. t.id, colors.white, colors.black, "back")
bar(BW - 7, 4, " BACK ", colors.black, colors.lightGray, "back")
local status = t.status or "idle"
put(1, 6, "STATUS " .. (TAG[status] or status), TAG_COLOR[status] or colors.white)
put(1, 7, "FUEL   " .. (t.fuel or 0), colors.yellow)
put(1, 8, "CARGO  " .. (t.inv or 0) .. "%", colors.lightGray)
put(1, 9, "SLOT   " .. tostring(t.slot or "-"):sub(1, BW - 8), colors.lightGray)
local at = t.pos or { x = 0, y = 0, z = 0 }
put(1, 10, "AT     " .. at.x .. " " .. at.y .. " " .. at.z, colors.lightGray)
put(1, 11, "ZONE   " .. (t.zone and ("Z" .. t.zone) or "-") .. "  " .. (t.prog or 0) .. "%", colors.lightGray)
put(1, 12, "SCAN   " .. (t.geo and "geo scanner" or "pickaxe only"), t.geo and colors.lime or colors.gray)
bar(1, 14, " PAUSE  ", colors.black, colors.orange, "turtle_pause", t.id)
bar(11, 14, " RESUME ", colors.black, colors.lime, "turtle_resume", t.id)
bar(1, 16, " RECALL ", colors.black, colors.cyan, "turtle_recall", t.id)
bar(11, 16, "  STOP  ", colors.white, colors.red, "turtle_stop", t.id)
end

function drawZones()
local list = Snap.zones
if #list == 0 then
put(1, 5, "no zones", colors.gray)
return
end
local first, last, pages = paging(#list)
local y = 4
for i = first, last do
local z = list[i]
bar(1, y, string.format("Z%-3s", z.id), colors.white, colors.black, "zone", z.id)
put(5, y, z.pattern:upper():sub(1, 6), colors.yellow)
put(12, y, string.format("%3d%%", z.prog or 0), colors.lime)
put(17, y, "x" .. z.crew, colors.lightGray)
local state, color = "off", colors.gray
if z.done then state, color = "done", colors.cyan
elseif z.held then state, color = "hold", colors.orange
elseif z.active then state, color = "run", colors.lime end
put(21, y, state, color)
y = y + 1
end
drawPager(pages)
end

function zoneById(id)
for _, z in ipairs(Snap.zones) do
if z.id == id then return z end
end
end

function drawZone()
local z = zoneById(zone)
if not z then zone = nil return end
bar(1, 4, "Z" .. z.id, colors.white, colors.black, "back")
bar(BW - 7, 4, " BACK ", colors.black, colors.lightGray, "back")
put(1, 6, "MODE   " .. z.pattern:upper(), colors.yellow)
put(1, 7, "CREW   " .. z.crew .. " turtles", colors.lightGray)
put(1, 8, "DONE   " .. (z.prog or 0) .. "%", colors.lime)
put(1, 9, "STATE  " .. (z.done and "complete" or (z.active and "running" or "stopped")), colors.white)
bar(1, 12, "  RUN   ", colors.black, colors.lime, "zone_start", z.id)
bar(11, 12, z.held and "   GO   " or "  HOLD  ", colors.black, colors.orange, "zone_hold", z.id)
bar(1, 14, "  STOP  ", colors.white, colors.red, "zone_stop", z.id)
end

function drawFilter()
local list = Snap.items
bar(1, 4, Snap.targetsOn and " ONLY LISTED ORES " or " EVERY ORE TAKEN  ", colors.black,
Snap.targetsOn and colors.lime or colors.lightGray, "toggle_targets")
if #list == 0 then
put(1, 6, "ore chest is empty", colors.gray)
return
end
local first, last, pages = paging(#list + 1)
local y = 5
for i = first, math.min(last, #list) do
local item = list[i]
put(1, y, shortName(item.name):sub(1, BW - 9), item.blocked and colors.red or colors.white)
bar(BW - 7, y, "[B]", item.blocked and colors.black or colors.lightGray,
item.blocked and colors.red or colors.gray, "toggle_filter", item.name)
bar(BW - 3, y, "[T]", item.target and colors.black or colors.lightGray,
item.target and colors.lime or colors.gray, "toggle_target", item.name)
y = y + 1
end
drawPager(pages)
end

function drawYield()
local list = Snap.bands
if #list == 0 then
put(1, 5, "nothing learned yet", colors.gray)
return
end
local peak = 0
for _, b in ipairs(list) do
if b.scans > 0 and b.found / b.scans > peak then peak = b.found / b.scans end
end
local width = BW - 12
local first, last, pages = paging(#list)
local y = 4
for i = first, last do
local b = list[i]
local avg = b.scans > 0 and b.found / b.scans or 0
put(1, y, string.format("%4d", b.y), colors.white)
put(5, y, "|", colors.lightGray)
local fill = 0
if peak > 0 then fill = math.floor(avg / peak * width + 0.5) end
if fill < 1 and avg > 0 then fill = 1 end
if fill > 0 then
if b.scans >= 12 then put(6, y, string.rep(" ", fill), colors.white, colors.white)
else put(6, y, string.rep("/", fill), colors.white) end
end
put(BW - 5, y, string.format("%5.1f", avg), colors.lightGray)
y = y + 1
end
drawPager(pages)
end

function draw()
bufInit(term.getSize())
hits = {}
drawHead()
drawTabs()
if not linked() then
put(1, 6, "controller not answering", colors.red)
put(1, 8, "check the ender modem", colors.lightGray)
bar(1, 10, " RETRY ", colors.black, colors.lime, "retry")
elseif pick then drawPick()
elseif zone then drawZone()
elseif tab == "FLEET" then drawFleet()
elseif tab == "ZONES" then drawZones()
elseif tab == "FILTER" then drawFilter()
else drawYield() end
drawNote()
flush()
end

function act(id, arg)
if id == "tab" then
tab = arg
page = 1
armRecall = false
pick = nil
zone = nil
saveState()
elseif id == "prev" then page = math.max(1, arg or page - 1)
elseif id == "next" then page = math.max(1, arg or page + 1)
elseif id == "arm_recall" then armRecall = true
elseif id == "arm_no" then armRecall = false
elseif id == "fleet_recall" then
armRecall = false
ask(id)
elseif id == "turtle" then pick = arg
elseif id == "zone" then zone = arg
elseif id == "back" then pick = nil zone = nil
elseif id == "retry" then ask()
else ask(id, arg) end
end

function click(x, y)
for _, spot in ipairs(hits) do
if y == spot.y and x >= spot.x1 and x <= spot.x2 then
act(spot.id, spot.arg)
return
end
end
end

function keypress(code)
if code == keys.left or code == keys.right then
local at = 1
for i, name in ipairs(TABS) do if name == tab then at = i end end
if code == keys.left then at = at - 1 else at = at + 1 end
act("tab", TABS[(at - 1) % #TABS + 1])
elseif code == keys.up then act("prev")
elseif code == keys.down then act("next")
elseif code == keys.backspace then act("back")
elseif code == keys.enter then ask() end
end

term.clear()
term.setCursorPos(1, 1)
print("C.A.V.E. remote")
loadState()
if not openRednet() then
print("no modem, cannot reach the controller")
end
ask()
draw()
local tick = os.startTimer(PULL_SECS)
while true do
local ev, p1, p2, p3 = os.pullEvent()
if ev == "timer" and p1 == tick then
tick = os.startTimer(PULL_SECS)
ask()
elseif ev == "rednet_message" and p3 == PROTOCOL then
if type(p2) == "table" and p2.cmd == "remote_snap" then
if Host ~= p1 then
Host = p1
saveState()
end
Snap = p2
lastSnap = os.clock()
draw()
end
elseif ev == "mouse_click" then
click(p2, p3)
draw()
elseif ev == "key" then
keypress(p1)
draw()
elseif ev == "term_resize" then
draw()
end
end

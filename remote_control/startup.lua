local PROTOCOL = "aegis_remote"
local STATE_FILE = "aegis_pocket.json"
local PULL_SECS = 3
local LINK_SECS = 12
local TABS = { "CRAFT", "QUEUE" }
Snap = nil
Found = nil
Host = nil
tab = "CRAFT"
page = 1
query = ""
sel = 1
pickItem = nil
pickCount = 1
pickTyped = false
pickMax = nil
lastEpoch = nil
resultMsg = nil
lastResultId = nil
lastSnap = 0
note = ""
hits = {}
Buf = {}
BW, BH = 26, 20
colour = term.isColour()
COL = {
ok = { colors.black, colors.lime },
warn = { colors.black, colors.orange },
danger = { colors.white, colors.red },
cool = { colors.black, colors.cyan },
mute = { colors.black, colors.lightGray },
cancel = { colors.white, colors.gray },
tabon = { colors.black, colors.lime },
taboff = { colors.lightGray, colors.gray }
}
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
function btn(x, y, label, kind, id, arg)
local c = COL[kind] or COL.mute
return bar(x, y, " " .. label .. " ", c[1], c[2], id, arg)
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
if s.tab == "CRAFT" or s.tab == "QUEUE" then tab = s.tab end
end
function openRednet()
local modem = peripheral.find("modem")
if not modem then return false end
rednet.open(peripheral.getName(modem))
return true
end
function send(msg)
if Host then rednet.send(Host, msg, PROTOCOL) else rednet.broadcast(msg, PROTOCOL) end
end
function linked()
return Snap ~= nil and os.clock() - lastSnap < LINK_SECS
end
function shortName(name)
return name:match(":(.+)$") or name
end
function perPage(top)
return math.max(1, BH - 1 - (top or 4))
end
function paging(count, top)
local per = perPage(top)
local pages = math.max(1, math.ceil(count / per))
if page > pages then page = pages end
if page < 1 then page = 1 end
local first = (page - 1) * per + 1
return first, math.min(count, first + per - 1), pages
end
function progbar(x, y, w, pct)
pct = math.max(0, math.min(100, pct))
local barw = w - 5
local inner = barw - 2
local fill = math.floor(inner * pct / 100 + 0.5)
put(x, y, "[", colors.lightGray)
if fill > 0 then put(x + 1, y, string.rep("|", fill), colors.lime) end
if inner - fill > 0 then put(x + 1 + fill, y, string.rep(".", inner - fill), colors.gray) end
put(x + barw - 1, y, "]", colors.lightGray)
put(x + barw + 1, y, string.format("%3d%%", pct), colors.white)
end
function drawHead()
local ids = "ID " .. os.getComputerID()
put(BW - #ids + 1, 1, ids, colors.lightGray)
if not linked() then put(1, 1, "NO LINK", colors.red) return end
put(1, 1, "KEEP", colors.lightGray)
btn(7, 1, "OFF", Snap.keepPaused and "warn" or "taboff", "keep_off")
btn(12, 1, "ON", (not Snap.keepPaused) and "ok" or "taboff", "keep_on")
btn(16, 1, "RUN", Snap.keepPaused and "mute" or "cool", "keep_run")
end
function drawTabs()
local total = 0
for _, name in ipairs(TABS) do total = total + #name + 2 end
local x = math.floor((BW - total) / 2) + 1
for _, name in ipairs(TABS) do
local on = tab == name
x = btn(x, 2, name, on and "tabon" or "taboff", "tab", name)
end
put(1, 3, string.rep("-", BW), colors.gray)
end
function drawPager(pages)
local y = BH - 1
put(1, y, string.rep("-", BW), colors.gray)
if pages <= 1 then return end
if page > 1 then bar(1, y, " < ", colors.black, colors.lightGray, "prev") end
local caption = page .. "/" .. pages
put(math.floor((BW - #caption) / 2) + 1, y, caption, colors.lime)
if page < pages then bar(BW - 2, y, " > ", colors.black, colors.lightGray, "next") end
end
function drawNote()
if not linked() then put(1, BH, "searching for AEGIS...", colors.lightGray) return end
if Snap and Snap.busy and Snap.job then
progbar(1, BH, BW, Snap.job.pct or 0)
return
end
if resultMsg then
if resultMsg.ok then
put(1, BH, ("MADE " .. shortName(resultMsg.name) .. " x" .. (resultMsg.made or 0)):sub(1, BW), colors.lime)
else
put(1, BH, ("FAIL " .. shortName(resultMsg.name) .. " s" .. (resultMsg.stage or 0) .. "/" .. (resultMsg.total or 0) .. " " .. (resultMsg.err or "?")):sub(1, BW), colors.red)
end
return
end
put(1, BH, note:sub(1, BW), colors.lightGray)
end
function drawCraft()
put(1, 4, "FIND:", colors.lightGray)
local shown = query == "" and "<item>" or query
shown = shown:sub(1, 16)
shown = shown .. string.rep(" ", 16 - #shown)
bar(6, 4, shown, query == "" and colors.gray or colors.black, query == "" and colors.black or colors.white, "focus")
bar(23, 4, "[X]", colors.white, colors.red, "clearq")
local res = Found and Found.results or {}
if #res == 0 then
if query == "" then
put(1, 6, "type name to search", colors.gray)
put(1, 8, "UP DN", colors.lightGray)
put(13, 8, "select", colors.gray)
put(1, 10, "< >", colors.lightGray)
put(13, 10, "category", colors.gray)
put(1, 12, "ENTER", colors.lightGray)
put(13, 12, "order item", colors.gray)
else
put(1, 6, "no matches", colors.gray)
end
drawPager(1)
return
end
if sel > #res then sel = #res end
if sel < 1 then sel = 1 end
local per = perPage(5)
page = math.floor((sel - 1) / per) + 1
local first, last, pages = paging(#res, 5)
local y = 5
for i = first, last do
local it = res[i]
local rowBg = (i == sel) and colors.gray or colors.black
if i == sel then put(1, y, string.rep(" ", BW), colors.gray, colors.gray) end
bar(1, y, shortName(it.name):sub(1, 18), colors.white, rowBg, "pick", i)
local h = tostring(it.have or 0)
put(BW - #h, y, h, colors.cyan, rowBg)
y = y + 1
end
drawPager(pages)
end
function drawPick()
put(1, 4, "ORDER", colors.lime)
put(1, 5, shortName(pickItem.name):sub(1, BW), colors.white)
local x = 1
put(x, 7, "STOCK", colors.lightGray) x = x + 6
local sv = (pickItem.have or 0) .. (pickItem.fl and "mB" or "")
put(x, 7, sv, colors.cyan) x = x + #sv + 2
put(x, 7, "AMT", colors.lightGray) x = x + 4
local av = tostring(pickCount)
put(x, 7, av, colors.lime) x = x + #av + 2
put(x, 7, "MAX", colors.lightGray) x = x + 4
put(x, 7, pickMax == nil and "?" or tostring(pickMax), pickMax == nil and colors.yellow or (pickMax > 0 and colors.lime or colors.red))
local amts = { 1, 8, 16, 32, 64 }
local sx = { 2, 6, 10, 15, 20 }
for i = 1, 5 do
btn(sx[i], 9, "+" .. amts[i], "mute", "q_add", amts[i])
btn(sx[i], 10, "-" .. amts[i], "mute", "q_add", -amts[i])
end
btn(5, 12, "CONFIRM", "ok", "craft_now")
btn(15, 12, "+QUEUE", "cool", "craft_queue")
if pickMax and pickMax > 0 then
local mx0 = math.floor((BW - 14) / 2) + 1
btn(mx0, 14, "CANCEL", "cancel", "pick_back")
btn(mx0 + 9, 14, "MAX", "ok", "q_max")
else
btn(math.floor((BW - 8) / 2) + 1, 14, "CANCEL", "cancel", "pick_back")
end
put(1, 16, "digits set qty, ENTER", colors.gray)
end
function drawQueue()
local job = Snap.job
if job then
put(1, 4, shortName(job.name):sub(1, BW), colors.white)
progbar(1, 5, BW, job.pct or 0)
put(1, 6, (job.done or 0) .. "/" .. (job.total or 0) .. " steps", colors.cyan)
btn(1, 7, "CANCEL", "danger", "cancel")
else
put(1, 4, "no active craft", colors.gray)
end
local q = Snap.queue or {}
put(1, 9, "QUEUE", colors.lightGray)
if #q > 0 then btn(BW - 8, 9, "RUN ALL", "ok", "runall") end
put(1, 10, string.rep("-", BW), colors.gray)
if #q == 0 then
put(1, 11, "empty, use +QUEUE", colors.gray)
drawPager(1)
return
end
local first, last, pages = paging(#q, 10)
local y = 11
for i = first, last do
local it = q[i]
put(1, y, ((it.count or 1) .. "x " .. shortName(it.name)):sub(1, BW - 4), colors.white)
bar(BW - 2, y, "[X]", colors.white, colors.red, "qdel", i)
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
put(1, 6, "AEGIS not answering", colors.red)
put(1, 8, "check ender modem on", colors.lightGray)
put(1, 9, "the main computer", colors.lightGray)
btn(1, 11, "RETRY", "ok", "retry")
drawNote()
flush()
return
end
if pickItem then drawPick()
elseif tab == "CRAFT" then drawCraft()
else drawQueue() end
drawNote()
flush()
end
function act(id, arg)
if id == "tab" then
tab = arg
page = 1
sel = 1
pickItem = nil
saveState()
elseif id == "prev" then if tab == "CRAFT" then sel = math.max(1, sel - perPage(5)) else page = math.max(1, page - 1) end
elseif id == "next" then if tab == "CRAFT" then local rn = Found and Found.results and #Found.results or 1 sel = math.min(math.max(1, rn), sel + perPage(5)) else page = page + 1 end
elseif id == "clearq" then query = "" Found = nil sel = 1
elseif id == "pick" then
local it = Found and Found.results and Found.results[arg]
if it then pickItem = it pickCount = it.have or 0 pickTyped = false pickMax = nil send({ cmd = "remote_max", name = it.name }) end
elseif id == "pick_back" then pickItem = nil
elseif id == "q_add" then pickCount = math.max(1, pickCount + arg) pickTyped = true
elseif id == "q_max" then if pickMax and pickMax > 0 then if pickItem.fl then pickCount = pickMax else pickCount = pickCount + pickMax end pickTyped = true end
elseif id == "keep_on" then send({ cmd = "remote_do", id = "keep_on" }) send({ cmd = "remote_pull" })
elseif id == "keep_off" then send({ cmd = "remote_do", id = "keep_off" }) send({ cmd = "remote_pull" })
elseif id == "keep_run" then send({ cmd = "remote_do", id = "keep_run" }) note = "keep run" send({ cmd = "remote_pull" })
elseif id == "craft_now" or id == "craft_queue" then
if pickItem then
send({ cmd = "remote_craft", name = pickItem.name, count = pickCount, now = id == "craft_now" })
note = (id == "craft_now" and "crafting " or "queued ") .. pickCount .. "x"
pickItem = nil
tab = "QUEUE"
page = 1
saveState()
send({ cmd = "remote_pull" })
end
elseif id == "runall" then send({ cmd = "remote_do", id = "runall" }) note = "run all sent" send({ cmd = "remote_pull" })
elseif id == "cancel" then send({ cmd = "remote_do", id = "cancel" }) note = "cancel sent"
elseif id == "qdel" then send({ cmd = "remote_do", id = "qdel", arg = arg }) send({ cmd = "remote_pull" })
elseif id == "retry" then send({ cmd = "remote_pull" })
end
end
function click(x, y)
for _, spot in ipairs(hits) do
if y == spot.y and x >= spot.x1 and x <= spot.x2 then
act(spot.id, spot.arg)
return
end
end
end
function onChar(ch)
if pickItem then
if ch:match("%d") then
if not pickTyped then pickCount = tonumber(ch) pickTyped = true
else pickCount = math.min(999999, pickCount * 10 + tonumber(ch)) end
if pickCount < 1 then pickCount = 1 end
end
return
end
if tab == "CRAFT" then
query = (query .. ch):sub(1, 64)
sel = 1
send({ cmd = "remote_search", q = query })
end
end
function cycleTab(dir)
local at = 1
for i, nm in ipairs(TABS) do if nm == tab then at = i end end
act("tab", TABS[((at - 1 + dir) % #TABS) + 1])
end
function onKey(code)
if pickItem then
if code == keys.enter then act("craft_now")
elseif code == keys.backspace then
pickCount = math.floor(pickCount / 10)
if pickCount < 1 then pickCount = 1 pickTyped = false end
end
return
end
if tab == "CRAFT" then
local res = Found and Found.results or {}
local n = #res
if code == keys.up then sel = math.max(1, sel - 1)
elseif code == keys.down then sel = math.min(math.max(1, n), sel + 1)
elseif code == keys.left then cycleTab(-1)
elseif code == keys.right then cycleTab(1)
elseif code == keys.enter then if res[sel] then act("pick", sel) end
elseif code == keys.backspace then query = query:sub(1, -2) sel = 1 send({ cmd = "remote_search", q = query }) end
return
end
if code == keys.up then act("prev")
elseif code == keys.down then act("next")
elseif code == keys.left then cycleTab(-1)
elseif code == keys.right then cycleTab(1) end
end
term.clear()
term.setCursorPos(1, 1)
print("A.E.G.I.S. remote")
loadState()
if not openRednet() then print("no modem, cannot reach AEGIS") end
send({ cmd = "remote_pull" })
draw()
local tick = os.startTimer(PULL_SECS)
while true do
local ev, p1, p2, p3 = os.pullEvent()
if ev == "timer" and p1 == tick then
tick = os.startTimer(PULL_SECS)
send({ cmd = "remote_pull" })
elseif ev == "rednet_message" and p3 == PROTOCOL then
if type(p2) == "table" then
if p2.cmd == "remote_snap" then
if Host ~= p1 then Host = p1 saveState() end
Snap = p2
lastSnap = os.clock()
if p2.note then note = p2.note end
if p2.epoch ~= lastEpoch then
lastEpoch = p2.epoch
if query ~= "" then send({ cmd = "remote_search", q = query }) end
if pickItem then send({ cmd = "remote_max", name = pickItem.name }) end
end
if lastResultId == nil then lastResultId = p2.resultId
elseif p2.resultId ~= lastResultId then lastResultId = p2.resultId resultMsg = p2.result end
draw()
elseif p2.cmd == "remote_found" then
Found = p2
draw()
elseif p2.cmd == "remote_maxr" then
if pickItem and p2.name == pickItem.name then pickMax = p2.max if p2.have ~= nil then pickItem.have = p2.have end end
draw()
elseif p2.cmd == "remote_ack" then
if p2.note then note = p2.note end
draw()
end
end
elseif ev == "mouse_click" then
resultMsg = nil
click(p2, p3)
draw()
elseif ev == "char" then
resultMsg = nil
onChar(p1)
draw()
elseif ev == "key" then
resultMsg = nil
onKey(p1)
draw()
elseif ev == "term_resize" then
draw()
end
end

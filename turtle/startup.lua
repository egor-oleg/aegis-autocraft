local gridSlots = {1, 2, 3, 5, 6, 7, 9, 10, 11}
local LAYOUT_DELAY = 1

local function getGridCount()
    local total = 0
    for _, slot in ipairs(gridSlots) do
        total = total + turtle.getItemCount(slot)
    end
    return total
end

local function gridSig()
    local parts = {}
    for _, slot in ipairs(gridSlots) do
        local d = turtle.getItemDetail(slot)
        parts[#parts + 1] = d and (d.name .. "x" .. d.count) or "-"
    end
    return table.concat(parts, "|")
end

local function craftLoop()
    local lastFailSig = nil
    while true do
        turtle.select(16)
        if getGridCount() > 0 and turtle.getItemCount(16) == 0 then
            local sig = gridSig()
            if sig ~= lastFailSig then
                sleep(LAYOUT_DELAY)
                if turtle.getItemCount(16) == 0 and getGridCount() > 0 then
                    local ok = turtle.craft()
                    if not ok then lastFailSig = gridSig() end
                end
            else
                sleep(0.2)
            end
        else
            lastFailSig = nil
            sleep(0.05)
        end
    end
end

while true do
    local ok, err = pcall(craftLoop)
    if not ok then
        print("[TURTLE] Crashed: " .. tostring(err))
        print("[TURTLE] Restarting in 3s...")
        sleep(3)
    end
end

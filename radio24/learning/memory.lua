-- radio24/learning/memory.lua: память. Строки оригинала 2111-2306. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- ПАМЯТЬ: исходное объявление -> твой правильный вариант
---------------------------------------------------------------------
MEM = {}

function norm(s)
    s = lo(stripColors(s))
    s = s:gsub('%p', ' ')
    s = s:gsub('%s+', ' ')
    return trim(s)
end

function oneLine(s) return (s:gsub('[\t\r\n]', ' ')) end

function memSave()
    pcall(function()
        local f = io.open(cfgPath('radio24_memory.txt'), 'wb')
        if not f then return end
        for k, e in pairs(MEM) do
            f:write(u8(k), '\t', u8(oneLine(e.orig)), '\t', u8(oneLine(e.final)), '\t',
                tostring(e.time or 0), '\n')
        end
        f:close()
    end)
end

function memLoad()
    pcall(function()
        local f = io.open(cfgPath('radio24_memory.txt'), 'rb')
        if not f then return end
        for line in f:lines() do
            local k, o, fi, t = line:match('^(.-)\t(.-)\t(.-)\t(%d*)$')
            if k and o and fi then
                MEM[u8:decode(k)] = { orig = u8:decode(o), final = u8:decode(fi), time = tonumber(t) or 0 }
            end
        end
        f:close()
    end)
end

function memGet(ad)
    local e = MEM[norm(ad)]
    return e and e.final or nil
end

function memAdd(orig, final)
    orig, final = trim(orig or ''), trim(final or '')
    if orig == '' or final == '' then return false end
    MEM[norm(orig)] = { orig = orig, final = final, time = os.time() }
    memSave()
    if AUTO then AUTO.stale = true end
    return true
end

-- Эталоны удалены: объявление, отправленное как есть, просто запоминается в память (см. dialogs.lua).
-- Заглушки оставлены для совместимости с модулями, которые могли вызывать старые функции.
SRC, SRCLOG = {}, {}
function srcMatch() return nil end
function srcAdd() return nil end

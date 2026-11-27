-- radio24/memory.lua: память и эталоны. Строки оригинала 2111-2306. Общее окружение модулей, см. radio24_helper.lua
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
        local f = io.open(DIR .. 'radio24_memory.txt', 'wb')
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
        local f = io.open(DIR .. 'radio24_memory.txt', 'rb')
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
    return true
end

---------------------------------------------------------------------
-- ЭТАЛОНЫ (правила исходника): объявления, отправленные как есть.
-- Ключ - "суть" объявления (основы слов без цены и знаков), поэтому "эконом-класса" и
-- "эконом класса" или другая цена - это то же объявление, и дубль не добавляется.
---------------------------------------------------------------------
SRC, SRCLOG = {}, {}

function sigOf(s)
    local l = lo(stripColors(s or '')):gsub('%p', ' ')
    local set, list = {}, {}
    for w in l:gmatch('%S+') do
        if not w:find('%d') then
            local tok
            if OPS[w] then
                tok = OPS[w]
            elseif not (STOPW[w] or DROP[w] or TORG[w] or DOGOVOR[w] or SVOBODN[w] or TORGHELP[w] or PRICEKW[w]) then
                tok = w:sub(1, 5)
            end
            if tok and not set[tok] then
                set[tok] = true
                list[#list + 1] = tok
            end
        end
    end
    if #list < 2 then return '' end
    table.sort(list)
    return table.concat(list, ' ')
end

function srcSave()
    pcall(function()
        local f = io.open(DIR .. 'radio24_src.txt', 'wb')
        if not f then return end
        for sig, e in pairs(SRC) do
            f:write(u8(sig), '\t', u8(flat(e.text)), '\t', tostring(e.n), '\t', tostring(e.time or 0), '\n')
        end
        f:close()
    end)
end

function srcLogSave()
    pcall(function()
        local f = io.open(DIR .. 'radio24_srclog.txt', 'wb')
        if not f then return end
        for _, l in ipairs(SRCLOG) do
            f:write(tostring(l.ts), '\t', l.kind, '\t', u8(flat(l.text)), '\t', u8(flat(l.rules)), '\n')
        end
        f:close()
    end)
end

function srcLoad()
    pcall(function()
        local f = io.open(DIR .. 'radio24_src.txt', 'rb')
        if f then
            for line in f:lines() do
                local sg, tx, n, tm = line:match('^(.-)\t(.-)\t(%d+)\t(%d*)$')
                if sg and sg ~= '' then
                    SRC[u8:decode(sg)] = { text = u8:decode(tx), n = tonumber(n) or 1, time = tonumber(tm) or 0 }
                end
            end
            f:close()
        end
        f = io.open(DIR .. 'radio24_srclog.txt', 'rb')
        if f then
            for line in f:lines() do
                local ts, kind, tx, rl = line:match('^(%d+)\t(%a+)\t(.-)\t(.*)$')
                if ts then
                    SRCLOG[#SRCLOG + 1] = { ts = tonumber(ts), kind = kind, text = u8:decode(tx), rules = u8:decode(rl) }
                end
            end
            f:close()
        end
    end)
end

function srcLogAdd(kind, text, rules)
    SRCLOG[#SRCLOG + 1] = { ts = os.time(), kind = kind, text = text, rules = rules or '' }
    if #SRCLOG > 300 then table.remove(SRCLOG, 1) end
    srcLogSave()
end

-- Эталон только для "Цена: договорная" и "Бюджет: свободный"; точные суммы не запоминаем
function srcPriceOk(ad)
    local l = lo(stripColors(ad or ''))
    local v = l:match(T('цена') .. '%s*:%s*(.*)$') or l:match(T('бюджет') .. '%s*:%s*(.*)$')
    if not v or v:find('%d') then return false end
    return v:find(T('договорн'), 1, true) ~= nil or v:find(T('свободн'), 1, true) ~= nil
end

function srcMatch(ad)
    if not srcPriceOk(ad) then return nil end
    local sg = sigOf(ad)
    return sg ~= '' and SRC[sg] or nil
end

-- notes - правила, сработавшие на объявлении; weak - выученные замены, которые были ослаблены
function srcAdd(ad, notes, weak)
    local sig = sigOf(ad)
    local text = (trim(stripColors(ad or '')):gsub('[%s%.]+$', ''))
    if sig == '' or text == '' then return nil end
    local parts = {}
    for _, n in ipairs(notes or {}) do parts[#parts + 1] = n end
    for _, k in ipairs(weak or {}) do parts[#parts + 1] = T('ослаблено выученное правило: ') .. k end
    if not srcPriceOk(text) then
        srcLogAdd('skip', text, table.concat(parts, '; '))
        return 'skip'
    end
    local kind
    local e = SRC[sig]
    if e then
        e.n = e.n + 1
        e.time = os.time()
        kind = 'dup'
    else
        SRC[sig] = { text = text, n = 1, time = os.time() }
        kind = 'new'
    end
    srcSave()
    srcLogAdd(kind, text, table.concat(parts, '; '))
    return kind
end

-- Правка эталона: ключ пересчитывается по новому тексту
function srcEditSave(oldSig, newText)
    local e = SRC[oldSig]
    if not e then return false, T('Эталон не найден.') end
    local text = (trim(stripColors(newText or '')):gsub('[%s%.]+$', ''))
    local sig = sigOf(text)
    if sig == '' then return false, T('Слишком короткий текст для эталона.') end
    if not srcPriceOk(text) then return false, T('Эталон только для "Цена: договорная" / "Бюджет: свободный".') end
    if sig ~= oldSig then
        local o = SRC[sig]
        if o then e.n = e.n + o.n end
        SRC[oldSig] = nil
    end
    e.text = text
    e.time = os.time()
    SRC[sig] = e
    srcSave()
    return true, T('Эталон изменён.')
end

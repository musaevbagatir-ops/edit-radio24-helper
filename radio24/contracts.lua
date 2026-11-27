-- radio24/contracts.lua: активные контракты с сайта Radio24. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- КОНТРАКТЫ: https://radio24.the-waynes.ru/api/contracts (открытый JSON, без входа).
-- Хелпер сам скачивает список (в фоне, окно curl.exe скрыто, игра не подвисает), хранит копию в
-- radio24_contracts.json и для каждого объявления пишет: контракт ЕСТЬ / НЕТ / не требуется.
-- Совпадение ищется по названию из контракта (в кавычках или [скобках], общие слова "семья/клуб/shop" не считаются)
-- с учётом транслитерации (Алтен = Alten) и падежей. Слова-триггеры ("семья", "клуб"...) и свои синонимы настраиваются на вкладке.
---------------------------------------------------------------------
CTR = {
    url = 'https://radio24.the-waynes.ru/api/contracts',
    list = {}, at = 0, ver = 0, err = '', busy = false, okOnce = false,
    on = true, interval = 300,
    kw = {}, alias = {}, cache = {}, cacheN = 0,
}
CTR_KW_DEFAULT = { 'семь', 'организац', 'клуб', '=бар', 'пивн', 'шоп', 'shop', 'мма', 'футбол', 'фк' }
pcall(ffi.cdef, 'unsigned int WinExec(const char* cmd, unsigned int show);')

---------------------------------------------------------------------
-- JSON (формат плоский: объекты без вложенных объектов)
---------------------------------------------------------------------
local function utf8char(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64) end
    return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

local JESC = { n = ' ', t = ' ', r = '', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }
local function jStr(obj, key)
    local _, e = obj:find('"' .. key .. '"%s*:%s*"')
    if not e then return nil end
    local i, out = e + 1, {}
    while i <= #obj do
        local ch = obj:sub(i, i)
        if ch == '\\' then
            local nx = obj:sub(i + 1, i + 1)
            if nx == 'u' then
                out[#out + 1] = utf8char(tonumber(obj:sub(i + 2, i + 5), 16) or 63)
                i = i + 6
            else
                out[#out + 1] = JESC[nx] or nx
                i = i + 2
            end
        elseif ch == '"' then
            break
        else
            out[#out + 1] = ch
            i = i + 1
        end
    end
    return table.concat(out)
end

local function jNum(obj, key) return obj:match('"' .. key .. '"%s*:%s*(%d+)') end

-- raw -> список контрактов (CP1251) или nil, если ответ не похож на список
function ctrParse(raw)
    if type(raw) ~= 'string' or not raw:find('"contracts"', 1, true) then return nil end
    if not raw:find('"success"%s*:%s*true') then return nil end
    local body = raw:match('"contracts"%s*:%s*(%b[])')
    if not body then return nil end
    local list = {}
    for obj in body:gmatch('%b{}') do
        local id, title = jNum(obj, 'id'), jStr(obj, 'title')
        if id and title then
            list[#list + 1] = {
                id = tonumber(id), title = u8:decode(title),
                signer = u8:decode(jStr(obj, 'signer') or ''), loc = u8:decode(jStr(obj, 'location') or ''),
                cat = u8:decode(jStr(obj, 'category') or ''),
                st = tonumber(jNum(obj, 'start_time')) or 0, et = tonumber(jNum(obj, 'end_time')) or 0,
            }
        end
    end
    return list
end

---------------------------------------------------------------------
-- Загрузка: curl.exe (есть в Windows 10+) в скрытом окне, запасной вариант - библиотека requests
---------------------------------------------------------------------
function ctrRefresh()
    if CTR.busy then return end
    CTR.busy = true
    lua_thread.create(function()
        local tmp = DIR .. 'radio24_contracts_dl.json'
        pcall(os.remove, tmp)
        local cmd = 'curl.exe -s -f -L --ssl-no-revoke -m 20 -A "Radio24Helper" -o "' .. tmp .. '" "' .. CTR.url .. '"'
        pcall(function() ffi.C.WinExec(cmd, 0) end)
        local raw, list
        for _ = 1, 32 do                                   -- ждём до ~16 с
            wait(500)
            local f = io.open(tmp, 'rb')
            if f then
                local r = f:read('*a')
                f:close()
                list = ctrParse(r)
                if list then raw = r; break end
            end
        end
        if not list then                                   -- запасной вариант (может на миг подвесить игру)
            local ok, requests = pcall(require, 'requests')
            if ok and requests then
                local ok2, r = pcall(function() return requests.get(CTR.url) end)
                if ok2 and r and r.text then raw = r.text; list = ctrParse(raw) end
            end
        end
        pcall(os.remove, tmp)
        if list then
            CTR.list, CTR.at, CTR.err = list, os.time(), ''
            CTR.ver = CTR.ver + 1
            pcall(function()
                local f = io.open(DIR .. 'radio24_contracts.json', 'wb')
                if f then f:write('#AT=', tostring(os.time()), '\n', raw); f:close() end
            end)
            if not CTR.okOnce then
                CTR.okOnce = true
                say(T('Контракты загружены, активных: ') .. #ctrActive())
            end
        else
            CTR.err = T('Не удалось загрузить контракты (нужен curl.exe из Windows 10+ или библиотека requests). Используется сохранённая копия.')
            if not CTR.errSaid then CTR.errSaid = true; say(CTR.err, 0xFFFF6666) end
        end
        CTR.busy = false
    end)
end

function ctrLoadCache()
    pcall(function()
        local f = io.open(DIR .. 'radio24_contracts.json', 'rb')
        if not f then return end
        local raw = f:read('*a')
        f:close()
        local list = ctrParse(raw)
        if list then
            CTR.list = list
            CTR.at = tonumber(raw:match('^#AT=(%d+)')) or 0
            CTR.ver = CTR.ver + 1
        end
    end)
end

function ctrActive()
    local now, res = os.time(), {}
    for _, c in ipairs(CTR.list) do
        if c.et > now then res[#res + 1] = c end
    end
    table.sort(res, function(a, b) return a.et < b.et end)
    return res
end

---------------------------------------------------------------------
-- Настройки: слова-триггеры и синонимы
---------------------------------------------------------------------
local function skelInit() end   -- (skel определён ниже)

function ctrAliasPush(a, n)
    CTR.alias[#CTR.alias + 1] = { a = a, n = n, sk = ctrSkel(a), nsk = ctrSkel(n) }
end

function ctrSaveCfg()
    pcall(function()
        local f = io.open(DIR .. 'radio24_ctr.txt', 'wb')
        if not f then return end
        f:write('on=', CTR.on and '1' or '0', '\n', 'int=', tostring(CTR.interval), '\n', 'seeded=1\n')
        for _, k in ipairs(CTR.kw) do f:write('kw\t', u8(k), '\n') end
        for _, a in ipairs(CTR.alias) do f:write('al\t', u8(a.a), '\t', u8(a.n), '\n') end
        f:close()
    end)
end

function ctrLoadCfg()
    CTR.kw, CTR.alias = {}, {}
    local seeded = false
    pcall(function()
        local f = io.open(DIR .. 'radio24_ctr.txt', 'rb')
        if not f then return end
        for line in f:lines() do
            local k, v = line:match('^(%a+)=(.*)$')
            if k == 'on' then CTR.on = v:sub(1, 1) == '1'
            elseif k == 'int' then CTR.interval = math.max(60, math.min(1800, tonumber(v) or 300))
            elseif k == 'seeded' then seeded = true
            else
                local kw = line:match('^kw\t(.+)$')
                if kw then CTR.kw[#CTR.kw + 1] = u8:decode(kw) end
                local a, n = line:match('^al\t(.-)\t(.+)$')
                if a then ctrAliasPush(u8:decode(a), u8:decode(n)) end
            end
        end
        f:close()
    end)
    if not seeded then
        for _, k in ipairs(CTR_KW_DEFAULT) do CTR.kw[#CTR.kw + 1] = T(k) end
    end
end

function ctrKwAdd(word)
    local w = lo(trim(word or ''))
    if #w < 2 or w:find('%s') then return false, T('Нужно одно слово (начало слова; "=слово" - только точное).') end
    for _, k in ipairs(CTR.kw) do if k == w then return false, T('Такое слово уже есть.') end end
    CTR.kw[#CTR.kw + 1] = w
    CTR.ver = CTR.ver + 1
    ctrSaveCfg()
    return true, T('Слово добавлено: ') .. w
end

function ctrKwDel(i)
    if CTR.kw[i] then table.remove(CTR.kw, i); CTR.ver = CTR.ver + 1; ctrSaveCfg() end
end

function ctrAliasAdd(a, n)
    a, n = lo(trim(a or '')), trim(n or '')
    if #a < 3 or #n < 3 then return false, T('Впиши слово из объявления и название из контракта (от 3 букв).') end
    ctrAliasPush(a, n)
    CTR.ver = CTR.ver + 1
    ctrSaveCfg()
    return true, T('Синоним добавлен.')
end

function ctrAliasDel(i)
    if CTR.alias[i] then table.remove(CTR.alias, i); CTR.ver = CTR.ver + 1; ctrSaveCfg() end
end

---------------------------------------------------------------------
-- Сопоставление: "скелет" слова (транслит ru->lat, гласные = a, двойные буквы схлопнуты)
---------------------------------------------------------------------
local TR = {}
for _, p in ipairs({ { 'а', 'a' }, { 'б', 'b' }, { 'в', 'v' }, { 'г', 'g' }, { 'д', 'd' }, { 'е', 'a' }, { 'ё', 'a' },
    { 'ж', 'j' }, { 'з', 's' }, { 'и', 'a' }, { 'й', 'a' }, { 'к', 'k' }, { 'л', 'l' }, { 'м', 'm' }, { 'н', 'n' },
    { 'о', 'a' }, { 'п', 'p' }, { 'р', 'r' }, { 'с', 's' }, { 'т', 't' }, { 'у', 'a' }, { 'ф', 'f' }, { 'х', 'h' },
    { 'ц', 's' }, { 'ч', 'c' }, { 'ш', 's' }, { 'щ', 's' }, { 'ъ', '' }, { 'ы', 'a' }, { 'ь', '' }, { 'э', 'a' },
    { 'ю', 'a' }, { 'я', 'a' } }) do
    TR[T(p[1])] = p[2]
end
for _, p in ipairs({ { 'a', 'a' }, { 'b', 'b' }, { 'c', 'k' }, { 'd', 'd' }, { 'e', 'a' }, { 'f', 'f' }, { 'g', 'g' },
    { 'h', 'h' }, { 'i', 'a' }, { 'j', 'j' }, { 'k', 'k' }, { 'l', 'l' }, { 'm', 'm' }, { 'n', 'n' }, { 'o', 'a' },
    { 'p', 'p' }, { 'q', 'k' }, { 'r', 'r' }, { 's', 's' }, { 't', 't' }, { 'u', 'a' }, { 'v', 'v' }, { 'w', 'v' },
    { 'x', 'k' }, { 'y', 'a' }, { 'z', 's' } }) do
    TR[p[1]] = p[2]
end

function ctrSkel(s)
    local out, last = {}, ''
    for ch in lo(s or ''):gmatch('.') do
        local m = TR[ch]
        if m == nil then m = ch:match('%d') and ch or '' end
        if m ~= '' and m ~= last then
            out[#out + 1] = m
            last = m
        end
    end
    return table.concat(out)
end

local GENSK = {}
for _, w in ipairs({ 'семья', 'семью', 'семье', 'семьи', 'клуб', 'клубе', 'бар', 'пивной', 'футбольный', 'футбол', 'мма',
    'шоп', 'shop', 'магазин', 'corp', 'corporation', 'inc', 'family', 'club', 'bar', 'фк', 'fc', 'org', 'group',
    'группа', 'организация', 'студия', 'studio', 'cafe', 'кафе', 'ресторан', 'restaurant' }) do
    GENSK[ctrSkel(w)] = true
end

-- значимые слова названия контракта (скелеты)
local function nameTokens(title)
    local function collect(part)
        local toks = {}
        for _, w in ipairs(strayTokens(part)) do
            local sk = ctrSkel(w)
            if #sk >= 3 and not GENSK[sk] then toks[#toks + 1] = sk end
        end
        return toks
    end
    local part = title:match('"(.-)"') or title:match('%[(.-)%]')
    local toks = part and collect(part) or {}
    if #toks == 0 then toks = collect(title) end
    return toks
end

-- GPS (п.3.1): пара цифр после gps/гпс/навигатор в объявлении, и пара цифр в поле "место" контракта
local function gpsPair(s, needKw)
    local l = lo(s or '')
    local from = 1
    if needKw then
        from = nil
        for _, kw in ipairs({ 'gps', T('гпс'), T('навигатор') }) do
            local a, b = l:find(kw, 1, true)
            if a and (not from or b + 1 < from) then from = b + 1 end
        end
        if not from then return nil end
    end
    local p1, p2 = l:match('(%d+)%s*[>%-]+%s*(%d+)', from)
    if p1 then return p1 .. ' > ' .. p2 end
end

-- Возвращает: 'ok' / 'bad' / 'none' (в объявлении нет GPS) / nil (в контракте нет GPS), пара из объявления, пара из контракта
function ctrGpsCmp(ad, loc)
    local lp = gpsPair(loc, false)
    if not lp then return nil end
    local ap = gpsPair(ad, true)
    if not ap then return 'none', nil, lp end
    return (ap == lp) and 'ok' or 'bad', ap, lp
end

-- Проверка объявления. Возвращает { matches = {контракты}, kw = слово-триггер или nil, nodata = bool }
function ctrCheck(ad)
    if not CTR.on then return nil end
    ad = ad or ''
    local cached = CTR.cache[ad]
    if cached and cached.ver == CTR.ver and os.time() - cached.t < 30 then return cached end
    local res = { ver = CTR.ver, t = os.time(), matches = {}, gps = {}, nodata = (#CTR.list == 0) }
    local words = strayTokens(ad)
    for _, w in ipairs(words) do
        for _, k in ipairs(CTR.kw) do
            local hit
            if k:sub(1, 1) == '=' then hit = (w == k:sub(2)) else hit = (w:sub(1, #k) == k) end
            if hit then res.kw = w; break end
        end
        if res.kw then break end
    end
    local adSk = {}
    for _, w in ipairs(words) do
        local s = ctrSkel(w)
        if #s >= 3 then adSk[#adSk + 1] = s end
    end
    for _, c in ipairs(ctrActive()) do
        local toks = nameTokens(c.title)
        local need, got = (#toks <= 2) and #toks or (#toks - 1), 0   -- название организации должно совпасть целиком
        for _, t in ipairs(toks) do
            for _, a in ipairs(adSk) do
                if a == t or (#t >= 5 and a:sub(1, #t) == t) then got = got + 1; break end
            end
        end
        local hit = #toks > 0 and got >= need
        if not hit then
            local tsk = ctrSkel(c.title)
            for _, al in ipairs(CTR.alias) do
                if al.sk ~= '' and al.nsk ~= '' and tsk:find(al.nsk, 1, true) then
                    for _, a in ipairs(adSk) do
                        if a == al.sk then hit = true; break end
                    end
                end
                if hit then break end
            end
        end
        if hit then
            res.matches[#res.matches + 1] = c
            res.gps[c.id] = { ctrGpsCmp(ad, c.loc) }
        end
    end
    if CTR.cacheN > 60 then CTR.cache, CTR.cacheN = {}, 0 end
    CTR.cache[ad] = res
    CTR.cacheN = CTR.cacheN + 1
    return res
end


---------------------------------------------------------------------
-- Название организации из контракта (то, что в кавычках/скобках, иначе название без слов "семья/клуб/shop")
-- и подстановка его в вариант текста: орг. название пишется как в контракте и берётся в кавычки.
---------------------------------------------------------------------
local WORDPAT = '[%w\192-\255\168\184]+'

function ctrOrgName(title)
    local part = title:match('"(.-)"') or title:match('\171(.-)\187') or title:match('%[(.-)%]')
    if part and trim(part) ~= '' then return trim(part) end
    local keep = {}
    for w in title:gmatch(WORDPAT) do
        if not GENSK[ctrSkel(w)] then keep[#keep + 1] = w end
    end
    if #keep == 0 then return nil end
    return table.concat(keep, ' ')
end

-- text - вариант текста, ad - исходник. Возвращает новый текст и заметку (или text, nil)
function ctrFixName(text, ad)
    local res = ctrCheck(ad)
    if not res or #res.matches == 0 then return text, nil end
    local m = res.matches[1]
    local nm = ctrOrgName(m.title)
    if not nm then return text, nil end
    local byMean = {}
    for w in nm:gmatch(WORDPAT) do
        local sk = ctrSkel(w)
        if #sk >= 3 and not GENSK[sk] then byMean[sk] = w end
    end
    local function fixWords(seg)
        return (seg:gsub(WORDPAT, function(w)
            local sk = ctrSkel(w)
            return byMean[sk] or w
        end))
    end
    -- Слова меняем отдельно по частям текста: вне кавычек - по словам; внутри кавычек - только если ВЕСЬ текст
    -- в кавычках после замены равен названию контракта ("Билли Айлиш" не превращаем в ""Beliy" Айлиш")
    local parts, p = {}, 1
    while true do
        local q = text:find('"', p, true)
        if not q then parts[#parts + 1] = text:sub(p); break end
        parts[#parts + 1] = text:sub(p, q - 1)
        p = q + 1
    end
    -- Предмет, а не организация: название в кавычках сразу после а/м, а/с, к/с, н/з ... контрактами не правим
    -- (к/с "Билли Айлиш" - костюм)
    local ITEM_CAT = { [T('а/м')] = true, [T('а/с')] = true, [T('к/с')] = true, [T('н/з')] = true,
        [T('м/ц')] = true, [T('в/т')] = true }
    for i = 2, #parts - 1, 2 do
        local pw = lo(trim(parts[i - 1] or '')):match('(%S+)$')
        if pw and ITEM_CAT[pw] then return text, nil end
    end
    local outp = {}
    for i, seg in ipairs(parts) do
        local piece = seg
        if i % 2 == 1 then
            piece = fixWords(seg)
        elseif i < #parts then                                   -- закрытая пара кавычек
            local f = fixWords(seg)
            if lo(trim(f)) == lo(nm) then piece = nm end
        end
        outp[#outp + 1] = piece
    end
    local new = table.concat(outp, '"')
    local lowNew, lowNm = lo(new), lo(nm)
    local a, b = lowNew:find(lowNm, 1, true)
    if a then
        local _, qb = new:sub(1, a - 1):gsub('"', '')
        if qb % 2 == 1 then
            -- название уже внутри кавычек: ничего не оборачиваем; если кавычки точно вокруг него - выправляем написание
            if new:sub(a - 1, a - 1) == '"' and new:sub(b + 1, b + 1) == '"' then
                new = new:sub(1, a - 1) .. nm .. new:sub(b + 1)
            end
        else
            new = new:sub(1, a - 1) .. '"' .. nm .. '"' .. new:sub(b + 1)
        end
    end
    -- тип организации из названия контракта (Семья / Клуб ...) ставится перед названием в кавычках, как в примерах ПРО
    local tw = trim((m.title:gsub('"(.-)"', '')))
    local twOk = tw ~= ''
    for w in tw:gmatch(WORDPAT) do if not GENSK[ctrSkel(w)] then twOk = false end end
    if twOk then
        local q = lo(new):find('"' .. lo(nm) .. '"', 1, true)
        if q and not lo(new):find(lo(tw), 1, true) then
            new = new:sub(1, q - 1) .. tw .. ' ' .. new:sub(q)
        end
    end
    if new ~= text then
        return new, T('название организации сверено с контрактом: "') .. nm .. '"'
    end
    return text, nil
end

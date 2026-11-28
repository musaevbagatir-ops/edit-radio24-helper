-- radio24/learning/learn/learn_02_names_people_cats.lua: часть 2 из 2 файла learning/learn. умная память и статистика. Строки оригинала 787-1187. Общее окружение модулей, см. radio24_helper.lua
-- Все части работают в общем окружении модулей, порядок частей задан в ORDER загрузчика radio24_helper.lua.
function catPrefLoad()
    pcall(function()
        local f = io.open(cfgPath('radio24_catpref.txt'), 'rb')
        if not f then return end
        for line in f:lines() do
            local c, p = line:match('^(.-)\t(.*)$')
            if c and c ~= '' then CATPREF[u8:decode(c)] = trim(u8:decode(p)) end
        end
        f:close()
    end)
end

-- в готовом тексте заменить префиксы словаря (а/с, к/с) на настроенные
function catPrefFix(text)
    local changed = false
    for cat, tag in pairs(CATTAG) do
        local p = CATPREF[cat]
        if p ~= nil and p ~= tag then
            local pat = tag:gsub('%p', '%%%0') .. ' "'
            local rp = (p ~= '') and (p:gsub('%%', '%%%%') .. ' "') or '"'
            text = text:gsub(pat, rp)
            changed = true
        end
    end
    if changed then text = text:gsub('  +', ' ') end
    return text
end

-- перед названием уже есть префикс или слово его категории?
function catPrefPresent(before, cat, pref)
    local tb = trim(lo(before or ''))
    local lp = lo(pref)
    if lp ~= '' and tb:sub(-#lp) == lp then return true end
    local w = tb:match('(%S+)$')
    if not w then return false end
    w = w:gsub('%p+$', '')
    if w:match('^[%a\192-\255]/[%a\192-\255]$') then return true end   -- перед названием уже стоит а/с, к/с, а/м...
    for _, c in ipairs(NAMES_CATS) do
        if T(c[1]) == cat then
            for _, kw in ipairs(c[2]) do
                if w:sub(1, #T(kw)) == T(kw) then return true end
            end
        end
    end
    return false
end

-- перенести несколько названий в другую категорию; keys - список ключей NAMES
function namesSetCat(keys, cat)
    local n = 0
    for _, k in ipairs(keys) do
        if NAMES[k] and NAMES[k].cat ~= cat then NAMES[k].cat = cat; n = n + 1 end
    end
    if n > 0 then namesSave() end
    return n
end

function namesCat(before)
    local ctx = lo(before or ''):sub(-60)
    local bestCat, bestEnd, bestLen = NAMES_OTHER, 0, 0
    for _, c in ipairs(NAMES_CATS) do
        local toks = {}
        for _, kw in ipairs(c[2]) do toks[#toks + 1] = T(kw) end
        local pf = lo(catPrefOf(T(c[1])) or '')          -- префикс категории (а/с, к/с, свой) - тоже признак: название после него идёт в эту категорию
        if #pf >= 2 then toks[#toks + 1] = pf end
        for _, tk in ipairs(toks) do
            local from, pos = 1, nil
            while true do
                local a = ctx:find(tk, from, true)
                if not a then break end
                pos, from = a, a + 1
            end
            if pos then                              -- побеждает слово, которое стоит ближе к названию; при равенстве - более длинное ("rc-игрушку" лучше "игрушку")
                local e = pos + #tk
                if e > bestEnd or (e == bestEnd and #tk > bestLen) then bestCat, bestEnd, bestLen = c[1], e, #tk end
            end
        end
    end
    return T(bestCat)
end

-- можно ли хранить как название (словарь и служебные слова сюда не берём)
function namesCheck(nm)
    nm = trim(nm or '')
    if #nm < 3 or #nm > 40 then return false, T('Название: от 3 до 40 символов.') end
    if not (nm:find('%a') or nm:find('[\192-\255\168\184]')) or nm:find('^[%d%p%s]+$') then
        return false, T('В названии должны быть буквы.')
    end
    if nm:find('"', 1, true) then return false, T('Кавычки в названии не нужны, они ставятся сами.') end
    local k = lo(nm)
    if DICT[k] or OPS[k] or STOPW[k] then return false, T('Это слово уже знает словарь, кавычки ставит он.') end
    if placeIsName and placeIsName(nm) then return false, T('Названия мест (города, деревни) в список названий не добавляются.') end
    if namesIsContract and namesIsContract(nm) then return false, T('Название связано с контрактом, в список не добавляется.') end
    return true, nm
end

function namesSave()
    pcall(function()
        local f = io.open(cfgPath('radio24_names.txt'), 'wb')
        if not f then return end
        for k, e in pairs(NAMES) do
            f:write(u8(e.cat), '\t', u8(flat(e.name)), '\t', tostring(e.n or 1), '\t', e.on and '1' or '0', '\n')
        end
        f:close()
    end)
end

function namesLoad()
    pcall(function()
        local f = io.open(cfgPath('radio24_names.txt'), 'rb')
        if not f then return end
        for line in f:lines() do
            local c, nm, n, on = line:match('^(.-)\t(.-)\t(%d*)\t?(%d?)$')
            if c and nm and nm ~= '' then
                nm = u8:decode(nm)
                NAMES[lo(nm)] = { cat = u8:decode(c), name = nm, n = tonumber(n) or 1, on = on ~= '0' }
            end
        end
        f:close()
    end)
end

-- есть ли перед названием префикс категории (а/с, к/с, а/м... или свой из настроек)? "а/с "X" и "Y"": для Y смотрим перед X
function namesHasPrefix(before)
    local tb = trim(lo(before or ''))
    local w = tb:match('(%S+)$')
    if not w then return false end
    w = (w:gsub('%p+$', ''))
    if w == T('и') then
        local tb2 = tb:gsub('%s*' .. T('и') .. '$', '')
        tb2 = tb2:gsub('"[^"]*"$', '')
        return namesHasPrefix(tb2)
    end
    if w:match('^[%a\192-\255]/[%a\192-\255]$') then return true end
    for _, p in pairs(CATPREF or {}) do
        local lp = lo(p or '')
        if lp ~= '' and tb:sub(-#lp) == lp then return true end
    end
    return false
end

-- Из итогового текста: все "Название" -> в память. Возвращает число новых названий.
-- asIs: отправка "как есть" (текст совпадает с исходником): новые названия без префикса (а/с, к/с...) не запоминаем
function namesLearn(final, asIs)
    if not cfg.learn then return 0 end
    local txt, added, changed = stripColors(final or ''), 0, false
    local addedList, dropped = {}, false
    local pos = 1
    if not asIs and S and S.original and trim(txt) ~= '' and trim(txt) == trim(stripColors(S.original)) then asIs = true end
    while true do
        local a, b, nm = txt:find('"([^"]+)"', pos)
        if not a then break end
        pos = b + 1
        nm = trim(nm)
        local k = lo(nm)
        local e = NAMES[k]
        if e then
            e.n = (e.n or 1) + 1
            if e.name ~= nm and e.name == lo(e.name) and nm ~= lo(nm) then e.name = nm end   -- регистр как в твоём варианте
            changed = true
        elseif up(nm) == nm and lo(nm) ~= nm and #nm > 4 then
            -- название капсом: шаблона нет, в список не запоминаем
        elseif asIs and not namesHasPrefix(txt:sub(1, a - 1)) then
            -- "отправить как есть" без префикса: ничего не запоминаем
        elseif namesCheck(nm) then
            NAMES[k] = { cat = namesCat(txt:sub(1, a - 1)), name = nm, n = 1, on = true }
            added, changed = added + 1, true
            addedList[#addedList + 1] = nm
            learnLogAdd(T('название'), NAMES[k].cat, nm, '')
            for ck, r in pairs(LEARN) do        -- такое же правило-замена уже могло выучиться: название его заменяет
                if not r.man and lo((r.val or ''):gsub('"', '')) == k then LEARN[ck] = nil; dropped = true end
            end
        end
    end
    if changed then namesSave() end
    if dropped then learnSave() end
    if added > 0 then say(T('добавлено названий: ') .. table.concat(addedList, ', ')) end
    return added
end

-- Ручное добавление / правка. oldKey - ключ правимой записи (nil = новая).
function namesSet(name, cat, on, oldKey)
    local ok, nm = namesCheck(name)
    if not ok then return false, nm end
    local k = lo(nm)
    if NAMES[k] and k ~= oldKey then
        if oldKey then return false, T('Название с таким написанием уже есть в списке - правь его там.') end
        local e = NAMES[k]                       -- уже есть: обновляем категорию и режим кавычек
        e.cat = (cat and cat ~= '') and cat or e.cat
        e.on = on and true or false
        namesSave()
        return true, T('Название уже было в списке: категория и кавычки обновлены.')
    end
    local n = 1
    if oldKey and NAMES[oldKey] then n = NAMES[oldKey].n or 1; NAMES[oldKey] = nil end
    NAMES[k] = { cat = (cat and cat ~= '') and cat or T(NAMES_OTHER), name = nm, n = n, on = on and true or false }
    if not oldKey then learnLogAdd(T('название'), NAMES[k].cat, nm, '') end
    namesSave()
    return true, oldKey and T('Название изменено.') or T('Название добавлено.')
end

function namesToggle(k)
    if NAMES[k] then NAMES[k].on = not NAMES[k].on; namesSave() end
end

function namesDel(text)
    local k = lo(trim((text or ''):gsub('"', '')))
    if NAMES[k] then NAMES[k] = nil; namesSave(); return true end
    return false
end

-- В исходнике: on -> "Название" в кавычки; off -> кавычки вокруг названия убираем (длинные названия первыми)
local function platePrev(s, a)            -- название стоит после н/з / "с номером": это номерной знак, регистр не трогаем
    local before = trim(lo(s:sub(1, a - 2)))
    local p1, p2 = T('н/з'), T('номером')
    return before:sub(-#p1) == p1 or before:sub(-#p2) == p2
end

function namesApply(s)
    if next(NAMES) == nil then return s, 0 end
    local keys = {}
    for k in pairs(NAMES) do if not DICT[k] then keys[#keys + 1] = k end end
    table.sort(keys, function(x, y) return #x > #y end)
    local count = 0
    for _, k in ipairs(keys) do
        local e, from = NAMES[k], 1
        while true do
            local a, b = lo(s):find(k, from, true)
            if not a then break end
            local pc = a > 1 and s:sub(a - 1, a - 1) or ''
            local nc = s:sub(b + 1, b + 1)
            local okL = (pc == '' or not (isLetter(pc) or pc:match('[%d"]')))
            local okR = (nc == '' or not (isLetter(nc) or nc:match('[%d"]')))
            if e.on and okL and okR then
                local _, q = s:sub(1, a - 1):gsub('"', '')
                if q % 2 == 0 then                          -- внутри чужих кавычек не трогаем
                    local rq = '"' .. e.name .. '"'
                    local pref = catPrefOf(e.cat)
                    if pref ~= '' and not catPrefPresent(s:sub(1, a - 1), e.cat, pref) then
                        rq = pref .. ' ' .. rq                   -- префикс категории + пробел
                        if pc:match('[%.,;:!%?%)]') then rq = ' ' .. rq end
                    end
                    s = s:sub(1, a - 1) .. rq .. s:sub(b + 1)
                    from = a + #rq
                    count = count + 1
                else
                    from = b + 1
                end
            elseif e.on and pc == '"' and nc == '"' and s:sub(a, b) ~= e.name and not platePrev(s, a) then
                s = s:sub(1, a - 1) .. e.name .. s:sub(b + 1)      -- КАПС/другой регистр в кавычках -> название как в списке
                from = b + 1
                count = count + 1
            elseif (not e.on) and pc == '"' and nc == '"' then
                s = s:sub(1, a - 2) .. s:sub(a, b) .. s:sub(b + 2)
                from = b
                count = count + 1
            else
                from = b + 1
            end
        end
    end
    return s, count
end

-- Список по категориям (для /adnames)
function namesSummary()
    local by, order = {}, {}
    for _, e in pairs(NAMES) do
        if not by[e.cat] then by[e.cat] = {}; order[#order + 1] = e.cat end
        by[e.cat][#by[e.cat] + 1] = e.on and e.name or (e.name .. T(' (без кавычек)'))
    end
    table.sort(order)
    return by, order
end

-- АВТОПРОВЕРКА объявления (для меню): знает ли хелпер такое объявление и нужно ли его запоминать.
-- orig - исходник, text - текст, который собираются отправить/взять в правку.
function adCheck(orig, text)
    orig, text = orig or '', trim(text or '')
    local r = { lines = {}, newNames = {}, verdict = 'skip', title = '' }
    local function add(c, s) r.lines[#r.lines + 1] = { c = c, t = s } end
    local mem = memGet(orig)
    local ref, exact = refFind(orig)
    local src = srcMatch(orig)
    local plain, pos, known, seen = stripColors(text), 1, {}, {}
    while true do
        local a, b, nm = plain:find('"([^"]+)"', pos)
        if not a then break end
        pos = b + 1
        nm = trim(nm)
        local k = lo(nm)
        if not seen[k] then
            seen[k] = true
            if NAMES[k] then known[#known + 1] = NAMES[k].name
            elseif namesCheck(nm) then r.newNames[#r.newNames + 1] = nm end
        end
    end
    local manual = text ~= '' and not isAutoText(text) and not (mem and mem == text)
    if S.blocked then
        r.verdict = 'blocked'
        r.title = T('ЗАПОМИНАТЬ: нет - объявление с пометкой ЗАПРЕЩЕНО')
    elseif manual or #r.newNames > 0 then
        r.verdict = 'remember'
        r.title = T('ЗАПОМИНАТЬ: да - ') .. (manual and T('текст изменён вручную') or T('есть новые названия'))
    else
        r.title = T('ЗАПОМИНАТЬ: не нужно - хелпер уже знает это объявление')
    end
    if mem then add('g', T('В памяти есть этот же текст.')) end
    if src then add('g', T('Есть эталон: формат уже проверен.')) end
    if ref then add('g', exact and T('Есть в справочнике ПРО (точный пример).') or T('Есть похожий пример в справочнике ПРО.')) end
    for _, n in ipairs(S.notes or {}) do
        if n:find(T('выучено: '), 1, true) then add('g', T('Сработали выученные правила (см. заметки).')); break end
    end
    if #known > 0 then add('g', T('Названия уже в списке: ') .. table.concat(known, ', ')) end
    if #r.newNames > 0 then
        add('o', T('Новые названия: ') .. table.concat(r.newNames, ', ')
            .. T(' (попадут в "Названия" при правке или кнопке "Запомнить")'))
    end
    if manual then add('o', T('Текст отличается от вариантов хелпера: на нём можно научить хелпер.')) end
    return r
end


---------------------------------------------------------------------
-- ЛЮДИ (поиск человека "Ищу человека по имени Имя Фамилия"): слова имени/фамилии -> английское написание.
-- Хранятся только в скрипте (radio24_people.txt), в меню не показываются. Учатся сами из твоего варианта.
-- Каждое слово работает и отдельно, и вместе, с падежами ("Миллера" -> Miller). kind: f = имя, l = фамилия.
---------------------------------------------------------------------
PEOPLE, PSTEM, PKIND = {}, {}, {}
local PEND

function peopleStem(w)
    if not PEND then
        PEND = {}
        for _, e in ipairs({ 'ами', 'ов', 'ев', 'ом', 'ем', 'ой', 'ей', 'ою', 'ею', 'ам', 'ах', 'ям', 'ях', 'а', 'у', 'е', 'ы', 'и', 'ю', 'я', 'о' }) do
            PEND[#PEND + 1] = T(e)
        end
    end
    for _, e in ipairs(PEND) do
        if #w - #e >= 3 and w:sub(-#e) == e then return w:sub(1, #w - #e) end
    end
    return w
end

function peopleReindex()
    PSTEM, PKIND = {}, {}
    for k, e in pairs(PEOPLE) do
        local st = peopleStem(k)
        if not PSTEM[st] then PSTEM[st] = e end
        if e.kind and e.kind ~= '' then PKIND[e.en] = e.kind end
    end
end

function peopleGet(w)
    local e = PEOPLE[w]
    if not e and #w >= 4 then e = PSTEM[peopleStem(w)] end
    return e and e.en or nil
end

function peopleSave()
    pcall(function()
        local f = io.open(cfgPath('radio24_people.txt'), 'wb')
        if not f then return end
        for k, e in pairs(PEOPLE) do
            f:write(u8(k), '\t', u8(flat(e.en)), '\t', e.kind or '', '\t', tostring(e.n or 1), '\n')
        end
        f:close()
    end)
end

function peopleLoad()
    pcall(function()
        local f = io.open(cfgPath('radio24_people.txt'), 'rb')
        if not f then return end
        for line in f:lines() do
            local k, en, kind, n = line:match('^(.-)\t(.-)\t(%a?)\t(%d*)$')
            if k and k ~= '' and en and en ~= '' then
                PEOPLE[u8:decode(k)] = { en = u8:decode(en), kind = kind, n = tonumber(n) or 1 }
            end
        end
        f:close()
    end)
    peopleReindex()
end

function peopleAdd(ru, en, kind)
    ru, en = lo(trim(ru or '')), trim(en or '')
    if #ru < 3 or en == '' or ru:find('%d') then return false end
    local e = PEOPLE[ru]
    if e then
        e.en, e.n = en, (e.n or 1) + 1
        if kind and kind ~= '' then e.kind = kind end
    else
        PEOPLE[ru] = { en = en, kind = kind or '', n = 1 }
    end
    peopleReindex()
    peopleSave()
    return true
end

-- Из отправленного варианта "Ищу человека по имени Miller Wayne. ..." и исходника "Ищу Миллера Уэйна": запоминаем слова парами
function peopleLearn(orig, final)
    if not cfg.learn then return end
    local f = stripColors(final or '')
    local a, b = lo(f):find(T('по имени') .. '%s+')
    if not a then return end
    local rest = f:sub(b + 1)
    rest = rest:match('^(.-)%.') or rest
    local en = {}
    for w in rest:gmatch('[%a][%w%-]*') do en[#en + 1] = w end
    local skip = set { 'ищу', 'ищем', 'найдите', 'найти', 'разыскиваю', 'человека', 'человек', 'по', 'имени', 'парня', 'игрока', 'девушку', 'друга', 'знакомого' }
    local ru = {}
    for w in stripColors(orig or ''):gmatch('%S+') do
        local c = w:gsub('^[%p]+', ''):gsub('[%p]+$', '')
        if c ~= '' and not skip[lo(c)] then
            if not c:find('[\192-\255\168\184]') or not isUpper(c:sub(1, 1)) then return end
            ru[#ru + 1] = c
        end
    end
    if #ru == 0 or #ru > 3 or #ru ~= #en then return end
    for i = 1, #ru do
        local kind = ''
        if #ru == 2 then kind = (i == 1) and 'f' or 'l' end
        peopleAdd(ru[i], en[i], kind)
    end
end


---------------------------------------------------------------------
-- СВОИ КАТЕГОРИЙ НАЗВАНИЙ: создать / удалить (вкладка "Названия", блок "Категории").
-- Свою категорию можно создать с словами-признаками (по ним хелпер сам определяет категорию, когда запоминает название
-- в кавычках) и с префиксом. Удалить можно любую, кроме "прочее": её названия переходят в "прочее".
-- Хранится в radio24_cats.txt (имена и слова в UTF-8).
---------------------------------------------------------------------
CATCUSTOM, CATREMOVED, CAT_DEFAULT = {}, {}, {}
for _, c in ipairs(NAMES_CATS) do
    local kws = {}
    for _, w in ipairs(c[2]) do kws[#kws + 1] = w end
    CAT_DEFAULT[#CAT_DEFAULT + 1] = { c[1], kws }
end

function catsSave()
    pcall(function()
        local f = io.open(cfgPath('radio24_cats.txt'), 'wb')
        if not f then return end
        for _, c in ipairs(NAMES_CATS) do
            if CATCUSTOM[c[1]] then f:write('cat\t', c[1], '\t', table.concat(c[2], ','), '\n') end
        end
        for nm in pairs(CATREMOVED) do f:write('del\t', nm, '\n') end
        f:close()
    end)
end

local function catIndex(nameU8)
    for i, c in ipairs(NAMES_CATS) do if c[1] == nameU8 then return i end end
    return nil
end

function catsLoad()
    pcall(function()
        local f = io.open(cfgPath('radio24_cats.txt'), 'rb')
        if not f then return end
        for line in f:lines() do
            local kind, nm, rest = line:match('^(%a+)\t([^\t]*)\t?(.*)$')
            if kind == 'cat' and nm ~= '' and not catIndex(nm) then
                local kws = {}
                for w in rest:gmatch('[^,]+') do kws[#kws + 1] = w end
                NAMES_CATS[#NAMES_CATS + 1] = { nm, kws }
                CATCUSTOM[nm] = true
            elseif kind == 'del' and nm ~= '' then
                local i = catIndex(nm)
                if i and not CATCUSTOM[nm] then table.remove(NAMES_CATS, i) end
                CATREMOVED[nm] = true
            end
        end
        f:close()
    end)
end

-- создать категорию (все строки CP1251, как приходят из полей ввода)
function catAdd(name, kwText, pref)
    name = (name or ''):gsub('[\t\r\n"]', ' ')
    name = lo(trim((name:gsub('%s+', ' '))))
    if #name < 2 or #name > 30 then return false, T('Название категории: от 2 до 30 символов.') end
    if not (name:find('%a') or name:find('[\192-\255\168\184]')) then return false, T('В названии категории должны быть буквы.') end
    for _, c in ipairs(namesCatList()) do
        if lo(c) == name then return false, T('Такая категория уже есть.') end
    end
    local kws = {}
    for w in (kwText or ''):gmatch('[^,;\r\n]+') do
        w = lo(trim(w))
        if #w >= 2 and #w <= 20 and #kws < 12 then kws[#kws + 1] = u8(w) end
    end
    if #kws == 0 and trim(pref or '') == '' then kws[1] = u8(name:sub(1, math.min(#name, 6))) end   -- признаков нет: ищем по началу самого названия
    local nameU = u8(name)
    NAMES_CATS[#NAMES_CATS + 1] = { nameU, kws }
    CATCUSTOM[nameU] = true
    CATREMOVED[nameU] = nil
    pref = trim(((pref or ''):gsub('[\t\r\n]', ' ')))
    if pref ~= '' then CATPREF[name] = pref; catPrefSave() end
    catsSave()
    return true, T('Категория создана: ') .. name
end

-- удалить категорию (cat - CP1251); названия из неё уходят в "прочее"
function catDel(cat)
    if cat == T(NAMES_OTHER) then return false, T('Категорию "прочее" удалить нельзя.') end
    local idx
    for i, c in ipairs(NAMES_CATS) do if T(c[1]) == cat then idx = i end end
    if not idx then return false, T('Такой категории нет.') end
    local c = table.remove(NAMES_CATS, idx)
    if CATCUSTOM[c[1]] then CATCUSTOM[c[1]] = nil else CATREMOVED[c[1]] = true end
    local n = 0
    for _, e in pairs(NAMES) do
        if e.cat == cat then e.cat = T(NAMES_OTHER); n = n + 1 end
    end
    if n > 0 then namesSave() end
    if CATPREF[cat] ~= nil then CATPREF[cat] = nil; catPrefSave() end
    catsSave()
    return true, T('Категория удалена, названий перенесено в "прочее": ') .. n
end

-- вернуть стандартные категории, которые были удалены (свои не трогаем)
function catsRestore()
    local n = 0
    for _, d in ipairs(CAT_DEFAULT) do
        if not catIndex(d[1]) then
            local kws = {}
            for _, w in ipairs(d[2]) do kws[#kws + 1] = w end
            NAMES_CATS[#NAMES_CATS + 1] = { d[1], kws }
            n = n + 1
        end
    end
    CATREMOVED = {}
    catsSave()
    return n
end

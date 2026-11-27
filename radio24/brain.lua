-- radio24/brain.lua: мозг: разбор и исправление объявления (fixText). Строки оригинала 1188-2036. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- Разбор и исправление объявления
---------------------------------------------------------------------
-- Запятые и повтор категории (а/с "A" и "B" вместо а/с "A" и а/с "B")
local CATABBR = { 'а/м', 'м/ц', 'в/т', 'л/т', 'а/с', 'к/с', 'н/з', 'с/к', 'п/п', 'б/з' }
local function catIs(w)
    w = lo(w)
    for _, a in ipairs(CATABBR) do if w == T(a) then return true end end
    return (VEHABBR and VEHABBR[w]) and true or false
end

function normCommasCats(body)
    local _, nq = body:gsub('"', '')
    if nq % 2 == 1 then return body end
    -- 1) запятые: перед новой операцией (куплю/продам...) - точка, цифры 1,5 - не трогаем, остальные пропускаем
    local o, inQ, br = {}, false, 0
    for i = 1, #body do
        local ch = body:sub(i, i)
        if ch == '"' then inQ = not inQ
        elseif not inQ and ch == '[' then br = br + 1
        elseif not inQ and ch == ']' then br = math.max(0, br - 1) end
        if ch == ',' and not inQ and br == 0 then
            local pv, nx = body:sub(i - 1, i - 1), body:sub(i + 1, i + 1)
            if pv:match('%d') and nx:match('%d') then
                o[#o + 1] = ch
            else
                local rest = body:sub(i + 1):match('^%s*(%S+)')
                local w = rest and lo((rest:gsub('[^%w\192-\255]', ''))) or ''
                o[#o + 1] = (w ~= '' and OPS[w]) and '. ' or ' '
            end
        else
            o[#o + 1] = ch
        end
    end
    body = table.concat(o):gsub('%s+', ' ')
    -- 2) повтор категории между перечисляемыми вещами
    local units, cur = {}, ''
    inQ, br = false, 0
    for i = 1, #body do
        local ch = body:sub(i, i)
        if ch == '"' then inQ = not inQ
        elseif not inQ and ch == '[' then br = br + 1
        elseif not inQ and ch == ']' then br = math.max(0, br - 1) end
        if ch == ' ' and not inQ and br == 0 then
            if cur ~= '' then units[#units + 1] = cur end
            cur = ''
        else
            cur = cur .. ch
        end
    end
    if cur ~= '' then units[#units + 1] = cur end
    local res, lastCat, clean = {}, nil, false
    for _, u in ipairs(units) do
        local lw = lo(u)
        local skip = false
        if lw == T('и') and res[#res] and catIs(res[#res]) then
            skip = true                                   -- «а/м и "X"» -> «а/м "X"»
        elseif catIs(u) then
            local pv = res[#res]
            if lastCat and lw == lastCat and clean and pv then
                if lo(pv) == T('марки') or lo(pv) == T('марка') then
                    res[#res] = nil                           -- «а/м марки а/м "X"» -> «а/м "X"» (без лишнего «и»)
                elseif lo(pv) ~= T('и') and not catIs(pv) then res[#res + 1] = T('и') end
                skip = true
            else
                lastCat, clean = lw, true
            end
        elseif lw == T('и') or lw == T('марки') or lw == T('марка') or u:find('^%[') or u:find('^"') then
            -- перечисление продолжается
        else
            clean = false
        end
        if not skip then res[#res + 1] = u end
    end
    body = table.concat(res, ' ')
    body = body:gsub('%s+', ' ')
    body = body:gsub('^[%s%.,;:!%?]+', '')
    body = body:gsub('[%s%.,;:!%?]+$', '')
    return body
end

function tokenize(s)
    local t = {}
    for w in s:gmatch('%S+') do
        local pre, core, post = w:match('^(%p*)(.-)(%p*)$')
        t[#t + 1] = { pre = pre, core = core, post = post }
    end
    return t
end

-- Купон (п.3.6): слово «купон» + название бонуса в кавычках
function buildCoupon(low)
    if not low:find(T('купон'), 1, true) then return nil end
    local l = ' ' .. low:gsub('[%.,;!]', ' ') .. ' '
    local X = '[x' .. T('х') .. ']'
    local lp, xs = ' ' .. low .. ' ', {}
    for num in lp:gmatch('%s' .. X .. '%s?(%d[%d%.,]*)') do
        num = num:gsub('[%.,]+$', ''):gsub(',', '.')
        xs[#xs + 1] = num
    end
    local mult = xs[1] or l:match('%s(%d+)%s?' .. X .. '%s')
    local hrs = l:match('(%d+)%s?' .. T('ч') .. '%s') or l:match('(%d+)%s?' .. T('час'))
    local pct = l:match('(%d+)%s?%%')
    -- «купон на тс #25» без слова «скидка»: если назван т/с или а/с, число 15/25 тоже считаем скидкой
    local tgtWord = false
    for _, w in ipairs({ ' тс ', ' т/с ', 'транспорт', ' ас ', ' а/с ', 'аксесс' }) do
        if l:find(T(w), 1, true) then tgtWord = true; break end
    end
    if not pct and (tgtWord or low:find(T('скидк'), 1, true) or low:find(T('скидоч'), 1, true)) then   -- «Скидка на транспорт 25» без знака %
        for st, num, en in low:gmatch('()(%d+)()') do
            local bef, aft = low:sub(st - 1, st - 1), low:sub(en, en)
            if (num == '15' or num == '25') and not bef:match('[%.,%d]') and not aft:match('[%.,]%d') then pct = num; break end
        end
    end
    local function has(...)
        for _, w in ipairs({ ... }) do if l:find(T(w), 1, true) then return true end end
        return false
    end
    local X2, notes, name = T('Х'), {}, nil
    if pct or has('скидк', 'скидоч') then
        local tgt
        if has(' тс ', ' т/с ', 'транспорт', 'машин', 'авто') then tgt = T('т/с')
        elseif has(' ас ', ' а/с ', 'аксесс') then tgt = T('а/с') end
        if tgt then
            if not pct then
                pct = '15'
                if tgt == T('т/с') then notes[#notes + 1] = T('купон на т/с: процент не указан - проверь (15% или 25%)') end
            end
            -- в списке названий: «т/с 25» (без %), но «т/с 15%» и «а/с 15%»
            name = T('Скидочный купон на покупку ') .. tgt .. ' ' .. pct .. (pct == '25' and '' or '%')
        end
    end
    if not name then
        local m = mult or '2'
        local function needM()
            if not mult then notes[#notes + 1] = T('купон: множитель не указан, поставил Х2 - проверь') end
        end
        if has('стрельб', ' тир ') then
            name = T('Купон на прокачку навыков стрельбы')
        elseif has(' зп ', 'зарплат', 'зарпл') then
            needM()
            name = (has('фракц') and T('Зарплата во фракциях ') or T('Зарплата ')) .. X2 .. m .. T(' на ') .. (hrs or xs[2] or '3') .. T('ч')
        elseif has('опыт') then
            needM()
            name = T('Игровой опыт ') .. X2 .. m .. T(' на ') .. (hrs or '6') .. T('ч')
        elseif has('навык', 'скилл', 'работ', 'прокач') then
            needM()
            name = T('Купон на прокачку навыков работы х') .. m
        end
    end
    if not name then return nil end
    return name, notes
end

-- Сим-карта (п.3.6): число -> формат X-Y-Z (до 3 разных цифр) или с A-B-C (4-6 разных)
function simPattern(d)
    local map, nxt, letters, seq = {}, 0, { 'X', 'Y', 'Z', 'A', 'B', 'C' }, {}
    for ch in d:gmatch('%d') do
        if not map[ch] then nxt = nxt + 1; map[ch] = letters[nxt] or 'C' end
        seq[#seq + 1] = map[ch]
    end
    local s = table.concat(seq)
    return s:sub(1, 2) .. '-' .. s:sub(3, 4) .. '-' .. s:sub(5, 6)
end

-- opts.bare: только разбор объявления по ПРО без названий, тэгов и выученных правил (вариант "Чистый ПРО")
function fixText(src, opts)
    opts = opts or {}
    local notes = {}
    local info = { reject = {} }
    local function note(s) notes[#notes + 1] = s end
    CTXHAVE = ctxHaveSet(src)                 -- слова объявления: для правил с контекстом

    local s = stripColors(src)
    s = s:gsub('[\r\n\t]+', ' ')
    s = s:gsub('%s+', ' ')
    s = s:gsub('\\', '/')                      -- "к\с" -> "к/с"
    s = trim(s)
    if s == '' then return '', notes, info end

    -- «кто в бар» = игра «Орел и решка» (вся фраза целиком)
    do
        local q = trim((lo(s):gsub('[%?!%.,]+', ' '):gsub('%s+', ' ')))
        if q == T('кто в бар') or q == lo(T('Ищу азартного игрока в бар')) then
            return T('Ищу азартного игрока в "Орел и решка". Ставка: договорная'), notes, info
        end
    end
    s = s:gsub('(%d)%s+%$', '%1$')                              -- "1.200.666 $" -> "1.200.666$"
    s = s:gsub('("[^"]-)%((%u%d+)%)"', '%1%2"')                 -- "... (W214)" -> "... W214"
    local lowSrc = lo(s)
    local simCtx0 = lowSrc:find(T('сим'), 1, true) or lowSrc:find(T('с/к'), 1, true)

    local letters, caps = 0, 0
    for c in s:gmatch('.') do
        if isLetter(c) then
            letters = letters + 1
            if isUpper(c) then caps = caps + 1 end
        end
    end
    if letters > 3 and caps / letters > 0.6 then s = lo(s) end
    if not opts.noNames and not opts.bare then                      -- список названий: кавычки включить/убрать
        local fzList
        s, fzList = namesFuzzy(s)                                   -- название с опечаткой -> как в списке
        if fzList and #fzList > 0 then note(T('опечатка в названии исправлена: ') .. table.concat(fzList, ', ')) end
        local ns, nc = namesApply(s)
        if nc > 0 then s = ns; info.names = nc; note(T('названия из списка (кавычки): ') .. nc) end
    end

    if PLACES and placeFuzzy then                                   -- место: русская запись/опечатки -> как в словаре
        local okp, ps, pf = pcall(placeFuzzy, s)
        if okp and ps then
            s = ps
            if pf and #pf > 0 then note(T('место исправлено: ') .. table.concat(pf, ', ')) end
        end
    end

    -- Опечатки: растянутые буквы ("продааааам" -> "продам"); "ккк" и "ххх" не трогаем
    s = s:gsub('([\224-\255])%1%1+', function(ch)
        local c = lo(ch)
        if c == T('к') or c == T('х') then return nil end
        return ch
    end)

    -- GPS (п.3.1): "gps 4>8" / "гпс 4-1" -> "GPS: 4 > 8"
    local gpsTxt
    for _, kw in ipairs({ 'gps', T('гпс'), T('навигатор') }) do
        local a, b, p1, sep, p2 = lo(s):find(kw .. '%s*:?%s*%(?%s*(%d+)%s*([>%-\150\151]+)%s*(%d+)%s*%)?')
        if a and lo(s):sub(1, a - 1):match('%[%s*$') and lo(s):sub(b + 1):match('^%s*%]') then a = nil end   -- [GPS 8>97] оставляем как есть
        if a then
            gpsTxt = 'GPS: ' .. p1 .. ' ' .. sep .. ' ' .. p2
            s = trim(s:sub(1, a - 1) .. ' ' .. s:sub(b + 1))
            break
        end
    end
    lowSrc = lo(s)

    -- Намерения без цены: работа, азартные игры, тир, знакомства, поиск человека (п.3.6)
    do
        local itext = KB.intent(s, lowSrc, note)
        if itext then
            info.intent = true
            for _, w in ipairs(WARN) do
                if lowSrc:find(w[1], 1, true) then note(T('ЗАПРЕЩЕНО/проверь: ') .. w[2]) end
            end
            return (trim((itext:gsub('%s+', ' ')))), notes, info
        end
    end

    -- Слитные знаки: «".(NY2022).Цена:5кк» -> «". (NY2022). Цена:5кк»
    s = s:gsub('([\224-\255]/[\224-\255])"', '%1 "')                  -- а/м"BMW -> а/м "BMW
    s = s:gsub('(%S)"%[', '%1" [')                                   -- "BMW"[HW24] -> "BMW" [HW24]
    s = (' ' .. s):gsub('(%s)[' .. T('гГ') .. ']%.%s*([VvWw][Ii][Nn][Ee]%s?[Ww][Oo][Oo][Dd])', '%1' .. T('горе') .. ' %2'):sub(2)   -- г.VineWood -> горе VineWood
    s = s:gsub('%[(%a+%d*)%s*[,;]([^%]]*)%]', function(tg, rest)     -- [HW24,ковш] -> [HW24]
        local b = lo(tg):match('^(%a+)')
        if b and (TAGBUILTIN[b] or TAGS[b]) then
            note(T('в тэге лишнее слово убрано: ') .. trim(rest))
            return '[' .. tg .. ']'
        end
    end)
    s = s:gsub('(["\187%)])%.([^%s%.])', '%1. %2')
    s = s:gsub('([%]%)])([%a\192-\255])', '%1 %2')                     -- "[FT-PT]Цена" -> "[FT-PT] Цена"
    s = s:gsub('([^%s%d,]),([%a\192-\255])', '%1, %2')                  -- "[HW26],Цена" -> "[HW26], Цена"
    s = s:gsub('"' .. T('и') .. '"', '" ' .. T('и') .. ' "')           -- '"пальма"и"вертушка"' -> '"пальма" и "вертушка"'
    s = (' ' .. s):gsub('(%s)([' .. T('дгДГ') .. '])%.(%a)', '%1%2. %3'):sub(2)   -- "д.Angel" -> "д. Angel"
    s = s:gsub('([%.%)"\187])([^%s%.%)"\187:]+):', function(a, w)
        if DROP[lo(w)] then return a .. ' ' .. w .. ':' end
    end)
    local toks = tokenize(s)

    -- "Цена:договорная" / "Бюджет:5кк" слитно -> два слова
    do
        local sp = {}
        for _, tk in ipairs(toks) do
            local a, b = tk.core:match('^(.-):(.+)$')
            if a and (DROP[lo(a)] or lo(a) == T('цена')) then
                sp[#sp + 1] = { pre = tk.pre, core = a, post = ':' }
                sp[#sp + 1] = { pre = '', core = b, post = tk.post }
            else
                sp[#sp + 1] = tk
            end
        end
        toks = sp
    end

    -- Слитное "15.000.000$торг" / "5кк,торг" / "торг5кк" -> сумма и слово "торг" отдельно
    do
        local sp = {}
        for _, tk in ipairs(toks) do
            local lc = lo(tk.core)
            local done = false
            for w in pairs(TORG) do
                if #lc > #w and lc:sub(-#w) == w then
                    local base = tk.core:sub(1, #tk.core - #w):gsub('[%.,;:%-/%s]+$', '')
                    if base:match('%d') or base:find('$', 1, true) then
                        sp[#sp + 1] = { pre = tk.pre, core = base, post = '' }
                        sp[#sp + 1] = { pre = '', core = tk.core:sub(-#w), post = tk.post }
                        done = true
                        break
                    end
                elseif #lc > #w and lc:sub(1, #w) == w then
                    local rest = tk.core:sub(#w + 1):gsub('^[%.,;:%-/%s]+', '')
                    if rest:match('%d') then
                        sp[#sp + 1] = { pre = tk.pre, core = tk.core:sub(1, #w), post = '' }
                        sp[#sp + 1] = { pre = '', core = rest, post = tk.post }
                        done = true
                        break
                    end
                end
            end
            if not done then sp[#sp + 1] = tk end
        end
        toks = sp
    end
    local hasTorgWord = false
    for _, tk in ipairs(toks) do
        if TORG[lo(tk.core)] then hasTorgWord = true end
    end

    -- ЧИСЛА (п.3.5): "1 000 000" / "1.5 млн" склеиваем; количество и цена за штуку отдельно от цены
    toks = KB.mergeNums(toks)
    local crimeKind = KB.crimeKindOf(lowSrc)
    local qty, unitPrice, bigQty
    if crimeKind then qty, unitPrice, bigQty, toks = KB.extractQty(toks, crimeKind, lowSrc) end

    -- Проход 1: цена / торг / договорная / свободный
    local price, priceMult, torg
    local list = {}
    local afterDrop = false          -- предыдущее слово было "Цена"/"Бюджет"
    for _, tk in ipairs(toks) do
        local core = lo(tk.core)
        local kwk = (not opts.noFuzzy) and KB.kw(core) or nil     -- опечатки в договорная/свободный/бюджет
        local raw = lo(tk.pre .. tk.core .. tk.post)
        raw = raw:gsub('[%.,;!]+$', '')
        local num, suf = raw:match('^%$?(%d[%d%.,]*)([^%d%s%$]*)%$?$')
        local v, mult
        if num then v, mult = parsePrice(num, suf) end
        local prev = list[#list]
        -- сумма вида 7.000.000 (без $) тоже считается ценой
        local grouped = num and mult == 1 and num:find('[%.,]%d%d%d') ~= nil
            and v and v >= cfg.minPrice
        local plainBig = num and suf == '' and #num >= 5 and not num:find('[%.,]') and v and v >= cfg.minPrice
            and not simCtx0
        if v and not price and (mult > 1 or raw:find('%$') or afterDrop or grouped or plainBig
            or (prev and PRICEKW[lo(prev.core)])) then
            price, priceMult = v, mult
            while list[#list] and PRICEKW[lo(list[#list].core)] do list[#list] = nil end
        elseif v and price and v == price and (mult > 1 or raw:find('%$') or afterDrop or grouped) then
            -- повтор той же цены: убираем (чтобы цена не дублировалась)
        elseif TORG[core] or DOGOVOR[core] or kwk == 'dog' then
            torg = true
        elseif SVOBODN[core] or DROP[core] or kwk == 'svob' or kwk == 'drop' or (hasTorgWord and TORGHELP[core]) then
            -- заменится итоговым "Цена:/Бюджет:"
        else
            list[#list + 1] = tk
        end
        afterDrop = (DROP[core] == true) or kwk == 'drop'
    end
    toks = list

    -- Купоны (п.3.6): «купон» + название бонуса в кавычках
    do
        local cname, cnotes = buildCoupon(lowSrc)
        if cname then
            local keep = {}
            for _, tk in ipairs(toks) do
                if OPS[lo(tk.core)] then keep[#keep + 1] = tk end
            end
            keep[#keep + 1] = { pre = '', core = T('купон') .. ' "' .. cname .. '"', post = '' }
            toks = keep
            for _, n in ipairs(cnotes) do note(n) end
        elseif lowSrc:find(T('купон'), 1, true) then
            note(T('купон: не удалось определить название бонуса - впиши вручную по списку ПРО (п.3.6)'))
        end
    end

    -- Сим-карты и номерные знаки: «формата» только когда уточняет (п.3.1, п.3.2, п.3.6)
    do
        local simctx = lowSrc:find(T('сим'), 1, true) or lowSrc:find(T('с/к'), 1, true)
        local platectx = (lowSrc:find(T('номер'), 1, true) or lowSrc:find(T('н/з'), 1, true) or lowSrc:find(T('н.з'), 1, true)
            or lowSrc:find(T('знак'), 1, true)) and not simctx
        if simctx or platectx then
            local o, fmtw = {}, false
            local function isTyp(x) x = lo(x or ''); return x == T('типу') or x == T('типа') or x == T('тип') end
            for idx, tk in ipairs(toks) do
                local c = lo(tk.core)
                if simctx and (isTyp(c) or (c == T('по') and toks[idx + 1] and isTyp(toks[idx + 1].core))) then
                    -- «по типу» в объявлении о сим-карте не нужно
                elseif simctx and (c:find('^' .. T('номер')) or c == T('с')) then
                    -- «с номером» в объявлении о сим-карте не нужно
                elseif c == T('формата') or c == T('формат') then
                    fmtw = true
                else
                    local bare = tk.core
                    local function unq() tk.pre = (tk.pre:gsub('"', '')); tk.post = (tk.post:gsub('"', '')) end
                    if simctx and bare:match('^%d%d%d%d%d%d$') then
                        unq(); tk.core = '"' .. simPattern(bare) .. '"'
                    elseif simctx and bare:match('^%d%d%-%d%d%-%d%d$') then
                        unq(); tk.core = '"' .. bare .. '"'
                    elseif simctx and bare:match('^%a+%-%a+%-%a+$') then
                        local oq = tk.pre:find('"', 1, true) ~= nil
                        unq(); tk.core = ((oq and not fmtw) and '' or T('формата ')) .. '"' .. up(bare) .. '"'
                    elseif platectx and fmtw and bare:gsub('"', ''):match('^[%w\192-\255]+$')
                        and not bare:match('^[%a\192-\255]%d%d%d[%a\192-\255][%a\192-\255]$') then
                        unq(); tk.core = T('формата ') .. '"' .. up((bare:gsub('"', ''))) .. '"'
                    end
                    fmtw = false
                    o[#o + 1] = tk
                end
            end
            toks = o
        end
    end

    -- Опечатки в ключевых словах (камфорт -> комфорт, апасном -> опасном, клылья -> крылья) и «дам» вместо «дом»
    if not opts.noFuzzy then
        for _, tk in ipairs(toks) do
            local lc = lo(tk.core)
            if not ((not opts.bare and learnedGet(lc)) or DICT[lc] or OPS[lc]) then
                local fw = KB.fuzzyWord(lc)
                if fw then
                    note(T('опечатка: "') .. tk.core .. T('" -> "') .. fw .. '"')
                    tk.core = fw
                    info.typo = true
                end
            end
        end
        for idx, tk in ipairs(toks) do
            local nx = toks[idx + 1]
            if lo(tk.core) == T('дам') and nx and (CLASSMAP[lo(nx.core)] or CLASSW[lo(nx.core)]) then
                tk.core = T('дом'); info.typo = true
                note(T('опечатка: "дам" -> "дом"'))
            end
        end
    end

    -- слова внутри кавычек (названия): выученные правила на них не действуют ("Маска кицунэ" не станет "а/с кицунэ")
    local qin, qopen = {}, false
    for idx, tk in ipairs(toks) do
        local _, qp = tk.pre:gsub('"', '')
        if qp % 2 == 1 then qopen = not qopen end
        qin[idx] = qopen or qp > 0
        local _, qc = tk.post:gsub('"', '')
        if qc % 2 == 1 then qopen = not qopen end
    end
    -- Проход 2: словарь (длинные фразы в приоритете)
    local out, i = {}, 1
    while i <= #toks do
        local done = false
        for n = math.min(MAXW, #toks - i + 1), 1, -1 do
            local parts = {}
            for j = i, i + n - 1 do parts[#parts + 1] = lo(toks[j].core) end
            local key = table.concat(parts, ' ')
            local inq = false
            for j = i, i + n - 1 do if qin[j] then inq = true end end
            local e = (not opts.bare and not inq and learnedGet(key)) or DICT[key]
            if e then
                if e.note then note(e.note) end
                if e.val ~= '' then
                    local quoted = e.val:find('"', 1, true) ~= nil
                    local pre0, post0 = toks[i].pre, toks[i + n - 1].post
                    if quoted then pre0 = (pre0:gsub('"', '')); post0 = (post0:gsub('"', '')) end
                    out[#out + 1] = { pre = pre0, core = e.val, post = post0, cat = e.cat,
                        veh = (e.cat == nil or e.cat == 'veh') and quoted }
                elseif toks[i + n - 1].post:find('"', 1, true) and out[#out] and out[#out].pre:find('"', 1, true)
                    and not out[#out].post:find('"', 1, true) then
                    out[#out].post = out[#out].post .. '"'          -- убранное слово стояло перед закрывающей кавычкой
                end
                i = i + n
                done = true
                break
            end
        end
        if not done then
            local tk0 = toks[i]
            local fz = KB.fuzzyVeh(lo(tk0.core))
            if fz then
                note(T('нечёткое распознавание: "') .. tk0.core .. T('" -> ') .. fz.val .. T(' (проверь)'))
                out[#out + 1] = { pre = (tk0.pre:gsub('"', '')), core = fz.val, post = (tk0.post:gsub('"', '')),
                    veh = true, cat = 'veh' }
            else
                out[#out + 1] = tk0
            end
            i = i + 1
        end
    end
    toks = out

    -- «чай марки X» -> «чай» (п.3.1, пример №8)
    do
        local o2, i2 = {}, 1
        while i2 <= #toks do
            local c = lo(toks[i2].core)
            local pv = o2[#o2] and lo(o2[#o2].core)
            if (c == T('марки') or c == T('марка')) and pv == T('чай') and toks[i2 + 1] then
                i2 = i2 + 2
            else
                o2[#o2 + 1] = toks[i2]; i2 = i2 + 1
            end
        end
        toks = o2
    end

    -- «дом VIP особняк» -> «особняк» (особняк уже включает дом, VIP не пишем)
    do
        local SKIPW = set { 'vip', 'вип' }
        local rm2 = {}
        for idx, tk in ipairs(toks) do
            if lo(tk.core) == T('дом') then
                local j = idx + 1
                while toks[j] and (SKIPW[lo(toks[j].core)] or ruTrig(lo(toks[j].core), 'vip')) do j = j + 1 end
                if toks[j] and lo(toks[j].core) == T('особняк') then
                    for k = idx, j - 1 do rm2[k] = true end
                end
            end
        end
        if next(rm2) then
            local o7 = {}
            for idx, tk in ipairs(toks) do if not rm2[idx] then o7[#o7 + 1] = tk end end
            toks = o7
            note(T('дом VIP особняк -> особняк (слово дом не пишем)'))
        end
    end
    -- «в гетто лс»: опасный район не привязываем к городу
    do
        local o8, dropped = {}, false
        for _, tk in ipairs(toks) do
            local pv = o8[#o8]
            if pv and lo(pv.core):find(T('опасн'), 1, true) and lo(tk.core):sub(1, 3) == T('г. ') then
                dropped = true
            else
                o8[#o8 + 1] = tk
            end
        end
        if dropped then toks = o8; note(T('город после опасного района убран')) end
    end

    -- Тип сделки
    local op
    for idx, tk in ipairs(toks) do
        if OPS[lo(tk.core)] then
            op = OPS[lo(tk.core)]
            table.remove(toks, idx)
            break
        end
    end

    -- События/розыгрыши (п.3.4): это не продажа - правила купли/продажи не применяем
    local isEvent = false
    if not op then
        for _, w in ipairs(KB.eventkw) do if lowSrc:find(w, 1, true) then isEvent = true end end
    end
    if isEvent then
        note(T('мероприятие/розыгрыш: реклама только при заключённом договоре (п.2.16, п.3.4)'))
        for idx, tk in ipairs(toks) do
            if tk.core == '24/7' and toks[idx - 1] and lo(toks[idx - 1].core) == T('в') then
                toks[idx - 1].core = T('в магазине')
            end
        end
    end

    -- Предприятие без слова «п/п» (п.3.3): "АЗС" -> "п/п АЗС", "24/7" -> "п/п магазин 24/7"
    if op and not isEvent then
        local hasPP, other = false, false
        for _, tk in ipairs(toks) do
            local c = lo(tk.core)
            if c == T('п/п') or c == T('бизнес') then hasPP = true end
            if c == T('дом') or c == T('особняк') or ((tk.veh or tk.cat) and op ~= 'swap') then other = true end
        end
        if not hasPP and not other then
            for idx, tk in ipairs(toks) do
                if KB.bizw[lo(tk.core)] then
                    local pv = toks[idx - 1]
                    table.insert(toks, idx, { pre = '', core = T('п/п'), post = '' })
                    if lo(tk.core) == '24/7' and not (pv and lo(pv.core) == T('магазин')) then
                        table.insert(toks, idx + 1, { pre = '', core = T('магазин'), post = '' })
                    end
                    break
                end
            end
        end
    end

    -- Лавка на центральном рынке (п.3.6): «лавка №7» / «лавка 7» / «в лавке на цр номер 7» -> «лавка №7 на ЦР»
    do
        local LAVW = set { 'лавка', 'лавке', 'лавку', 'лавки', 'лавкой', 'лафка', 'лафке', 'лафку', 'лавак' }
        local SKIPL = set { 'на', 'цр', 'ц/р', 'центральном', 'центральный', 'рынке', 'рынок', 'номер', 'номером', 'под', '№', '#' }
        local CRW = set { 'цр', 'ц/р', 'центральном', 'рынке' }
        local PREP = set { 'в', 'во', 'на', 'из', 'у' }
        local o5, i5 = {}, 1
        while i5 <= #toks do
            local tk = toks[i5]
            local num, jEnd
            if LAVW[lo(tk.core)] then
                local j = i5 + 1
                while toks[j] and j <= i5 + 5 do
                    local tt = lo(toks[j].pre .. toks[j].core)
                    local d = tt:match('^[' .. T('№') .. '#]?(%d+)$')
                    if d and #d <= 3 then num, jEnd = d, j; break end
                    if not SKIPL[lo(toks[j].core)] then break end
                    j = j + 1
                end
            end
            if num then
                local hasCR = false
                for k, t2 in ipairs(toks) do
                    if (k < i5 or k > jEnd) and CRW[lo(t2.core)] then hasCR = true end
                end
                local pv = o5[#o5]
                if pv and PREP[lo(pv.core)] then table.remove(o5) end
                if o5[#o5] and o5[#o5].post == '' then o5[#o5].post = ',' end
                o5[#o5 + 1] = { pre = tk.pre, core = T('лавка №') .. num, post = '' }
                local lastPost = toks[jEnd].post
                if hasCR then o5[#o5].post = lastPost
                else o5[#o5 + 1] = { pre = '', core = T('на ЦР'), post = lastPost } end
                i5 = jEnd + 1
            else
                o5[#o5 + 1] = tk; i5 = i5 + 1
            end
        end
        toks = o5
    end

    -- Криминал (п.3.5): бластер + пули, чай, т/и, запчасти; количество и цена за штуку
    if crimeKind then
        local gun
        for _, tk in ipairs(toks) do if tk.cat == 'gun' and not gun then gun = tk end end
        local function isBul(tk) local c = lo(tk.core); return c == T('пули для бластеров') or KB.bulw[c] end
        local bul = (qty and qty.unit == 'pt') or false
        local keep, firstBul = {}, nil
        for _, tk in ipairs(toks) do
            if crimeKind == 'bullet' and isBul(tk) then
                bul = true
                if not gun and not firstBul then
                    tk.core = T('пули для бластеров'); firstBul = tk; keep[#keep + 1] = tk
                end
            else
                keep[#keep + 1] = tk
            end
        end
        toks = keep
        if gun and bul then gun.core = T('пули для бластера') .. gun.core:sub(#T('бластер') + 1) end
        if not gun and bul and not firstBul then
            firstBul = { pre = '', core = T('пули для бластеров'), post = '' }
            toks[#toks + 1] = firstBul
        end
        local item = gun or firstBul
        if not item then
            for _, tk in ipairs(toks) do
                local c = lo(tk.core)
                if c == T('чай') or tk.cat == 'tob' or c == T('запчасти к бластеру') then item = tk; break end
            end
        end
        local phrase
        if qty then phrase = KB.qtyPhrase(crimeKind, qty)
        elseif bigQty then phrase = T('в большом кол-ве') end
        if phrase then
            local at = 0
            if item then for idx, tk in ipairs(toks) do if tk == item then at = idx; break end end end
            if at == 0 then at = #toks end
            local itk = toks[at]
            table.insert(toks, at + 1, { pre = '', core = phrase, post = itk and itk.post or '' })
            if itk then itk.post = '' end
        end
    end

    -- Порядок по ПРО: место идёт после класса/марки/дополнений (перед ценой),
    -- даже если в исходнике оно стоит в начале
    do
        local PREP = set { 'в', 'во', 'на', 'у', 'около', 'возле', 'рядом' }
        local LANDW = set { 'кольце', 'кольца', 'кольцо', 'районе', 'района', 'район', 'горе', 'горы', 'гору' }
        local AREA1 = set { 'бейсайд', 'bayside', 'vinewood', 'вайнвуд', 'ganton', 'idlewood', 'willowfield' }
        local AREA2 = { { T('опасный'), T('район') }, { 'glen', 'park' }, { 'el', 'corona' }, { 'east', 'beach' } }
        local gpre = T('г. ')
        local dpre = T('д. ')
        local mark, n, i = {}, #toks, 1
        while i <= n do
            local lc = lo(toks[i].core)
            local len = 0
            if lc:sub(1, #gpre) == gpre or lc:sub(1, #dpre) == dpre or lc:find('vinewood', 1, true) or lc == 'vine wood' or AREA1[lc] or lc:find(T('опасн'), 1, true) or lc:find(T('творческ'), 1, true) then
                len = 1
            else
                for _, ph in ipairs(AREA2) do
                    if lc == ph[1] and toks[i + 1] and lo(toks[i + 1].core) == ph[2] then len = 2 end
                end
            end
            if len > 0 and toks[i + len] and LANDW[lo(toks[i + len].core)] then len = len + 1 end   -- "в опасном районе"
            if len > 0 then
                local st = i
                if st > 1 and not mark[st - 1] and LANDW[lo(toks[st - 1].core)] then st = st - 1 end
                if st > 1 and not mark[st - 1] and PREP[lo(toks[st - 1].core)] then st = st - 1 end
                for k = st, i + len - 1 do mark[k] = true end
                if st > 1 and not mark[st - 1] then toks[st - 1].post = toks[st - 1].post:gsub('[,;%.]', '') end
                i = i + len
            else
                i = i + 1
            end
        end
        if next(mark) and op ~= 'swap' then
            local a, b = {}, {}
            for k = 1, n do
                if mark[k] then
                    toks[k].post = toks[k].post:gsub('[,;%.]', '')
                    b[#b + 1] = toks[k]
                else
                    a[#a + 1] = toks[k]
                end
            end
            if #a > 0 then a[#a].post = (a[#a].post:gsub('[,;%.]', '')) end
            for _, tk in ipairs(b) do a[#a + 1] = tk end
            toks = a
        end
    end

    -- Флаги
    local hasVeh, vehAbbr, hasHouse, hasClass, hasChai = false, false, false, false, false
    for _, tk in ipairs(toks) do
        local c = lo(tk.core)
        if tk.veh then hasVeh = true; vehAbbr = true end
        if VEHABBR[c] then vehAbbr = true end
        if c == T('дом') or c == T('особняк') then hasHouse = true end
        if c == T('особняк') then hasClass = true end
        if c == T('чай') then hasChai = true end
    end

    -- Латинские названия при наличии т/с: кавычки, склейка соседних слов
    if vehAbbr then
        local merged, last, openq = {}, nil, nil
        local function closeq(t)                  -- "Name" из pre/post переносим в core, как у остальных названий
            t.core = '"' .. t.core .. '"'
            t.pre, t.post = t.pre:gsub('"', ''), t.post:gsub('"', '')
        end
        for ti, tk in ipairs(toks) do
            local c = lo(tk.core)
            local closesLater = false                 -- название в кавычках закрывается дальше (число внутри названия не рвёт его)
            if openq then
                for j = ti + 1, #toks do
                    if toks[j].post:find('"', 1, true) then closesLater = true; break end
                    if toks[j].pre:find('"', 1, true) then break end
                end
            end
            local isTagTk = openq and not tk.pre:find('"', 1, true) and (tk.pre:find('[', 1, true)
                or c:match('^hw%-?%d+$') or c:match('^ny%-?%d+$') or tagBase(c, tk))
            if isTagTk then
                closeq(openq); openq = nil
                tk.post = (tk.post:gsub('"', ''))
                merged[#merged + 1] = tk
                last = nil
            elseif openq and not tk.pre:find('"', 1, true) and tk.core:match('^%d[%d%.%-]*%a?$')
                and (closesLater or tk.post:find('"', 1, true)) then
                openq.core = openq.core .. ' ' .. tk.core          -- "Peterbilt 379 Optimus Prime": число внутри названия
                openq.post = tk.post
                if tk.post:find('"', 1, true) then closeq(openq); openq = nil end
            elseif not opts.bare and not openq and last == nil and merged[#merged] and merged[#merged].core:match('^".*"$')
                and not tk.pre:find('"', 1, true) and tk.post:find('"', 1, true) and tk.core:match('^%a[%w%-]*$') then
                -- хвост названия после уже закрытого названия: "BMW M5 F90" LSPD" -> выученное удаление или склейка обратно
                local pm = merged[#merged]
                local lg = learnedGet(c)
                if lg and lg.val == '' then
                    note(T('убрано слово внутри кавычек (выученное правило): ') .. tk.core)
                    pm.post = (pm.post or '') .. (tk.post:gsub('"', ''))
                else
                    pm.core = pm.core:sub(1, -2) .. ' ' .. tk.core .. '"'
                    pm.post = (pm.post or '') .. (tk.post:gsub('"', ''))
                end
            elseif last and last.post == '' and tk.core:match('^%d+%a$') and not tk.pre:find('"', 1, true) then
                last.core = last.core:sub(1, -2) .. ' ' .. tk.core .. '"'          -- McLaren 650S
                last.post = tk.post
            elseif tk.core:match('^%a[%w%-]*$') and not TUNEW[c] and not LOCLAT[c] and not tk.veh
                and not c:match('^hw%-?%d+$') and not c:match('^ny%-?%d+$') and not tagBase(c, tk)
                and not (tk.pre:find('[%(%[]') and not openq) then
                if tk.pre:find('"', 1, true) then
                    tk.veh = true; hasVeh = true
                    merged[#merged + 1] = tk
                    last = nil
                    if tk.post:find('"', 1, true) then closeq(tk) else openq = tk end   -- "Mercedes Maybach": название продолжается
                elseif openq then
                    if not ((c == 'halloween' or c == T('хэллоуин') or c == T('хеллоуин')) and lowSrc:find('hw', 1, true)) then
                        openq.core = openq.core .. ' ' .. tk.core
                    end
                    openq.post = tk.post
                    if tk.post:find('"', 1, true) then closeq(openq); openq = nil end
                elseif last and last.post == '' then
                    last.core = last.core:sub(1, -2) .. ' ' .. tk.core .. '"'
                    last.post = tk.post
                else
                    tk.core = '"' .. tk.core .. '"'
                    tk.veh = true; hasVeh = true
                    merged[#merged + 1] = tk
                    last = tk
                end
            else
                merged[#merged + 1] = tk
                last, openq = nil, nil
            end
        end
        toks = merged
    end

    if hasVeh then
        local anyAbbr = false
        local GENW = set { 'любой', 'любую', 'любое', 'другой', 'другую', 'другое' }
        for idx, tk in ipairs(toks) do
            local pvw = toks[idx - 1]
            if (VEHABBR[lo(tk.core)] and not (pvw and GENW[lo(pvw.core)]))
                or (tk.veh and tk.core:find('/', 1, true)) then anyAbbr = true end
        end
        if not anyAbbr then
            for idx, tk in ipairs(toks) do
                if tk.veh then table.insert(toks, idx, { pre = '', core = T('а/м'), post = '' }); break end
            end
        end
    end

    -- «марки» перед маркой, у которой уже есть а/м: слово «марки» не нужно
    do
        local o9 = {}
        for idx, tk in ipairs(toks) do
            local c = lo(tk.core)
            local nx = toks[idx + 1]
            if (c == T('марки') or c == T('марка')) and nx and VEHABBR[lo(nx.core:match('^(%S+)') or '')] then
                -- пропускаем
            else
                o9[#o9 + 1] = tk
            end
        end
        toks = o9
    end

    -- «марки» только если уточняет (п.3.1); несколько т/с через «и» (п.3.2)
    if hasVeh then
        local BRANDS = set { 'toyota', 'honda', 'bmw', 'mercedes', 'audi', 'ferrari', 'lamborghini', 'ford', 'nissan',
            'porsche', 'chevrolet', 'dodge', 'mazda', 'subaru', 'lexus', 'bentley', 'tesla' }
        local o3 = {}
        for idx, tk in ipairs(toks) do
            local c = lo(tk.core)
            local nx = toks[idx + 1]
            if (c == T('марки') or c == T('марка')) and nx and nx.veh then
                local _, sp = nx.core:gsub(' ', '')
                if sp >= 1 then tk = nil end
            end
            if tk then o3[#o3 + 1] = tk end
        end
        local o4 = {}
        for _, tk in ipairs(o3) do
            local inner = tk.veh and tk.core:match('^"(%a+)"$')
            local pv = o4[#o4]
            if inner and BRANDS[lo(inner)] and pv and lo(pv.core) == T('а/м') then
                o4[#o4 + 1] = { pre = '', core = T('марки'), post = '' }
            end
            o4[#o4 + 1] = tk
        end
        toks = o4
        local vi = {}
        for idx, tk in ipairs(toks) do if tk.veh then vi[#vi + 1] = idx end end
        if #vi >= 2 then
            local li = vi[#vi]
            local pv = toks[li - 1]
            if pv and lo(pv.core) ~= T('и') and not catIs(pv.core) then
                pv.post = (pv.post:gsub('[,;]', ''))
                table.insert(toks, li, { pre = '', core = T('и'), post = '' })
            end
        end
    end

    -- Класс дома: "дом эконом" -> "дом эконом-класса"
    if hasHouse then
        for idx, tk in ipairs(toks) do
            local c = lo(tk.core)
            if CLASSMAP[c] then
                tk.core = CLASSMAP[c]
                hasClass = true
                local nx = toks[idx + 1]
                if nx and CLASSW[lo(nx.core)] then nx.drop = true end
                -- "класса бизнес" -> "бизнес-класса": слово "класс(а)" ПЕРЕД названием класса тоже убираем (иначе дубль)
                local pv = toks[idx - 1]
                if pv and not pv.drop then
                    local pl = lo(pv.core)
                    if CLASSW[pl] or pl == T('класса') or pl == T('класс') then pv.drop = true end
                end
            elseif c:find(T('класса'), 1, true) then
                hasClass = true
            end
        end
    end

    -- Дом: номер дома («н38», «№38», «номер 38») и гаражные места «2х гаражом» (п.3.3)
    if hasHouse then
        -- «дом (60) эконом класса»: число в скобках / после слова «дом» - номер дома, ставим после класса
        do
            local ni
            for idx, tk in ipairs(toks) do
                if not ni and tk.core:match('^%d%d?%d?%d?$') then
                    local pv, nx = toks[idx - 1], toks[idx + 1]
                    local pl = pv and lo(pv.core) or ''
                    local nl = nx and lo(nx.core) or ''
                    local bad = nl:find('^' .. T('этаж')) or nl:find('^' .. T('комнат')) or nl:find('^' .. T('гараж'))
                        or nl:find('^' .. T('мест'))
                    local hashed = tk.pre:find('#', 1, true) ~= nil or tk.pre:find(T('№'), 1, true) ~= nil
                    if (hashed or not bad) and (tk.pre:find('[%(#]') or tk.pre:find(T('№'), 1, true) or pl == T('дом') or pl == T('особняк')) then
                        ni = idx
                    end
                end
            end
            if ni then
                local num = toks[ni].core
                table.remove(toks, ni)
                local at, foundCls = ni, false
                for idx, tk in ipairs(toks) do
                    if lo(tk.core):find(T('класса'), 1, true) then at = idx + 1; foundCls = true; break end
                end
                if not foundCls then
                    for idx, tk in ipairs(toks) do
                        local hc = lo(tk.core)
                        if hc == T('дом') or hc == T('особняк') then at = idx + 1; break end
                    end
                end
                table.insert(toks, at, { pre = '', core = T('с номером "') .. num .. '"', post = '' })
            end
        end
        local o6, i6 = {}, 1
        while i6 <= #toks do
            local tk, nx = toks[i6], toks[i6 + 1]
            local c = lo(tk.core)
            local hn = c:match('^' .. T('н') .. '%.?(%d+)$') or c:match('^' .. T('№') .. '(%d+)$')
            local gn = c:match('^(%d)%-?[x' .. T('х') .. ']$') or c:match('^(%d)%-?' .. T('местн') .. '%S*$')
            if hn then
                o6[#o6 + 1] = { pre = '', core = T('с номером "') .. hn .. '"', post = tk.post }
                i6 = i6 + 1
            elseif c == T('н/з') and nx and nx.core:match('^%d+$') then
                o6[#o6 + 1] = { pre = '', core = T('с номером "') .. nx.core .. '"', post = nx.post }
                i6 = i6 + 2
            elseif gn and nx and lo(nx.core):find('^' .. T('гараж')) then
                if gn == '1' then
                    o6[#o6 + 1] = { pre = tk.pre, core = T('с гаражом'), post = nx.post }
                else
                    o6[#o6 + 1] = { pre = tk.pre, core = gn .. T('х'), post = '' }
                    o6[#o6 + 1] = { pre = '', core = T('гаражом'), post = nx.post }
                end
                i6 = i6 + 2
            elseif c:find('^' .. T('гараж')) and nx and lo(nx.core):match('^(%d)%-?[x' .. T('х') .. ']$') then
                local g2 = lo(nx.core):match('^(%d)%-?[x' .. T('х') .. ']$')      -- «гараж 1x»
                if g2 == '1' then
                    o6[#o6 + 1] = { pre = tk.pre, core = T('с гаражом'), post = nx.post }
                else
                    o6[#o6 + 1] = { pre = tk.pre, core = g2 .. T('х'), post = '' }
                    o6[#o6 + 1] = { pre = '', core = T('гаражом'), post = nx.post }
                end
                i6 = i6 + 2
            else
                o6[#o6 + 1] = tk; i6 = i6 + 1
            end
        end
        toks = o6
    end

    -- Неполный тюнинг (п.3.2): «с нитро и новыми дисками» -> [Tune: нитро, диски]
    local tuneParts = {}
    if hasVeh then
        local rm, got = {}, {}
        for idx, tk in ipairs(toks) do
            local lab = KB.tuneparts[lo(tk.core)]
            if lab then
                rm[idx] = true
                local dup = false
                for _, g in ipairs(got) do if g == lab then dup = true end end
                if not dup then got[#got + 1] = lab end
                local j = idx - 1
                while j >= 1 and KB.tunejunk[lo(toks[j].core)] do rm[j] = true; j = j - 1 end
                if j >= 1 then
                    local pc = lo(toks[j].core)
                    if pc == T('с') or pc == T('со') then rm[j] = true
                    elseif pc == T('и') and rm[j - 1] then rm[j] = true end
                end
            end
        end
        if #got > 0 then
            local kept = {}
            for idx, tk in ipairs(toks) do if not rm[idx] then kept[#kept + 1] = tk end end
            toks, tuneParts = kept, got
        end
    end

    -- Номера, тюнинг, цвета, full
    local tune = { NY = false, HW = false, FT = false, PT = false }
    local prevTune = false
    local TW = { ft = true, pt = true, full = true, ['ft/pt'] = true, ['ft-pt'] = true, ['pt-ft'] = true, [T('фт-пт')] = true, [T('фт')] = true, [T('пт')] = true,
        [T('фулл')] = true, [T('фт/пт')] = true }
    do   -- «хв 26» / «hw 26» / «нг 24»: тэг и год через пробел -> одно слово (hw26)
        local o7, i7 = {}, 1
        while i7 <= #toks do
            local tk7, nx7 = toks[i7], toks[i7 + 1]
            local c7 = lo(tk7.core)
            if hasVeh and nx7 and tk7.post == '' and nx7.pre == '' and (c7 == T('хв') or c7 == 'hw' or c7 == T('нг') or c7 == 'ny')
                and (nx7.core:match('^%d%d$') or nx7.core:match('^20%d%d$')) then
                o7[#o7 + 1] = { pre = tk7.pre, core = c7 .. nx7.core, post = nx7.post }
                i7 = i7 + 2
            else
                o7[#o7 + 1] = tk7
                i7 = i7 + 1
            end
        end
        toks = o7
    end
    local firstVeh
    local out2 = {}
    for _, tk in ipairs(toks) do
        local c = lo(tk.core)
        c = tagRuLatin(c, tk)                       -- хв26 -> hw26, нг26 -> ny26 (русская запись HW/NY, в том числе с опечаткой)
        local keep = true
        if tk.veh and not firstVeh then firstVeh = tk end
        if tk.drop then
            keep = false
        elseif not opts.bare and tagFix(tk, c) then
            -- известный тэг ([BDAY7], [BP]...): оставляем, оформляем в скобки
        elseif not tk.pre:find('"', 1, true)
            and tk.core:match('^[%a\192-\255]%d%d%d[%a\192-\255][%a\192-\255]$') then
            local r = tk.core:gsub('.', function(ch) return LOOK[lo(ch)] or up(ch) end)
            tk.core = '"' .. r .. '"'
            tk.pre = ''
        elseif hasVeh and (c == T('фт') or c == 'ft') then tune.FT = true; keep = false
        elseif hasVeh and (c == T('пт') or c == 'pt') then tune.PT = true; keep = false
        elseif hasVeh and (c == 'ft/pt' or c == T('фт/пт') or c == 'pt/ft' or c == T('пт/фт') or c == 'ft-pt' or c == 'pt-ft'
            or c == T('фт-пт') or c == T('пт-фт')) then
            tune.FT, tune.PT = true, true; keep = false
        elseif hasVeh and (c == T('хв') or c == 'hw' or c == T('хэллоуин') or c == T('хеллоуин')) then tune.HW = true; keep = false
        elseif hasVeh and (c == 'ny' or c == T('нг')) then tune.NY = true; keep = false
        elseif hasVeh and (c:match('^hw%-?%d+$') or c:match('^' .. T('хв') .. '%-?%d+$')) then
            tune.HW = true; tune.HWY = c:match('%d+$'); keep = false
        elseif hasVeh and (c:match('^ny%-?%d+$') or c:match('^' .. T('нг') .. '%-?%d+$')) then
            tune.NY = true; tune.NYY = c:match('%d+$'); keep = false
        elseif not hasVeh and (c:match('^hw%-?%d%d+$') or c:match('^ny%-?%d%d+$')) then   -- а/с, к/с из коллекции: [HW-26] -> [HW26]
            local yy = c:match('%d+$')
            if #yy == 4 then yy = yy:sub(3) end
            tk.core = c:sub(1, 2):upper() .. yy
            tk.pre = '['
            tk.post = ']' .. ((tk.post:gsub('^[%]%)]+', '')))
        elseif hasVeh and prevTune and (c == T('тюнинг') or c == T('тюн') or c == 'tune') then keep = false
        elseif c == 'full' or c == T('фулл') or ruTrig(c, 'full') then
            if hasVeh then
                tune.FT, tune.PT = true, true
                keep = false
            elseif hasHouse then
                tk.core = T('с евроремонтом')
                tk.pre = ''
                tk.post = (tk.post:gsub('["%.]', ''))
                note(T('full -> с евроремонтом (п.2.12)'))
            else
                keep = false
                note(T('слово full запрещено (п.2.12)'))
            end
        elseif hasVeh and COLORS[c] then
            keep = false
            note(T('цвет т/с удалён (п.3.2)'))
        end
        if keep then out2[#out2 + 1] = tk end
        prevTune = TW[c] == true
    end
    toks = out2

    local tags = {}
    for _, k in ipairs({ 'NY', 'HW', 'FT', 'PT' }) do
        if tune[k] then
            local y = (k == 'NY' and tune.NYY) or (k == 'HW' and tune.HWY) or ''
            if #y == 4 then y = y:sub(3) end                     -- NY2022 -> NY22
            tags[#tags + 1] = k .. y
        end
    end
    if #tags > 0 and firstVeh then
        for idx, tk in ipairs(toks) do
            if tk == firstVeh then
                table.insert(toks, idx + 1, { pre = '', core = '[' .. table.concat(tags, '/') .. ']',
                    post = tk.post })
                tk.post = ''
                break
            end
        end
    end

    if #tuneParts > 0 and firstVeh then
        local at
        for idx, tk in ipairs(toks) do if tk == firstVeh then at = idx; break end end
        if at then
            if toks[at + 1] and toks[at + 1].core:match('^%[') then at = at + 1 end
            local host = toks[at]
            table.insert(toks, at + 1, { pre = '', core = '[Tune: ' .. table.concat(tuneParts, ', ') .. ']', post = host.post })
            host.post = ''
        end
    end

    if not opts.bare then                                   -- название КАПСОМ (одно слово) -> "Spyder"; н/з не трогаем
        for idx, tk in ipairs(toks) do
            local inner = tk.veh and tk.core:match('^"(%a+)"$')
            local pv = toks[idx - 1]
            if inner and #inner >= 5 and inner == inner:upper() and not (pv and lo(pv.core) == T('н/з')) and not DICT[lo(inner)] then
                tk.core = '"' .. inner:sub(1, 1) .. inner:sub(2):lower() .. '"'
            end
        end
    end
    if not opts.bare and not opts.noNames then
        for idx, tk in ipairs(toks) do
            local inner = tk.veh and tk.core:match('^"([^"]+)"$')
            local pv = toks[idx - 1]
            if inner and not (pv and lo(pv.core) == T('н/з')) then
                local e = NAMES[lo(inner)]
                if e and e.on and e.name ~= inner then tk.core = '"' .. e.name .. '"' end
            end
        end
    end
    -- лишнее двоеточие после сокращения категории: «а/м: "X"» -> «а/м "X"»
    for _, tk in ipairs(toks) do
        if tk.post:find(':', 1, true) and not tk.core:find('"', 1, true) and catIs(tk.core) then
            tk.post = (tk.post:gsub(':', ''))
        end
    end
    -- Сборка тела
    local parts = {}
    for _, tk in ipairs(toks) do parts[#parts + 1] = tk.pre .. tk.core .. tk.post end
    local body = table.concat(parts, ' ')
    body = body:gsub('%s+', ' ')
    body = body:gsub('^[%s%.,;:!%?]+', '')
    body = body:gsub('[%s%.,;:!%?]+$', '')
    body = normCommasCats(body)
    body = body:gsub('(%S+) ("%d+")', function(w, n)       -- Дворец "1687" -> Дворец с номером "1687"
        local lw = lo((w:gsub('[%.,;:!%?]+$', '')))
        if lw == T('дворец') or lw == T('особняк') or lw == T('дом') then return w .. ' ' .. T('с номером') .. ' ' .. n end
    end)
    while body:find(T('а/м') .. ' ' .. T('а/м'), 1, true) do
        body = body:gsub(T('а/м') .. ' ' .. T('а/м'), T('а/м'))
    end

    if (op == 'sell' or op == 'rent' or op == 'buy') and placeToEnd then   -- место - последним перед ценой/бюджетом (п.2.7)
        local okp, nb = pcall(placeToEnd, body)
        if okp and nb and nb ~= '' then body = nb end
    end
    local lowBody = lo(body)
    local hasLoc = lowBody:find(T('г. '), 1, true) ~= nil or lowBody:find(T('д. '), 1, true) ~= nil
    for _, w in ipairs(LOCLIST) do if lowBody:find(w, 1, true) then hasLoc = true end end
    local flatBody = (lowBody:gsub('%-', ' '))                 -- «д.Palomino-Creek»: место указано и без пробела
    for _, p in ipairs(PLACES or {}) do
        if not p.plain then
            local name = (lo(T((p.canon:gsub('^%S+%s+', '')))):gsub('%-', ' '))
            if flatBody:find(name, 1, true) then hasLoc = true end
        end
    end
    local hasBizType = false
    for _, w in ipairs(BIZTYPES) do if lowBody:find(w, 1, true) then hasBizType = true end end
    if not hasVeh and body:find('"', 1, true) then hasBizType = true end
    local bizWord = false
    if not hasHouse then
        bizWord = (lowBody:find(T('бизнес'), 1, true) or lowBody:find(T('п/п'), 1, true)) ~= nil
    end

    -- Правила по типу имущества
    if op == 'buy' then
        if hasHouse and not hasClass and not hasLoc then
            body = body:gsub(T('дом'), T('дом любого класса в любой точке штата'), 1)
        elseif hasHouse and hasClass and not hasLoc then
            body = body .. T(' в любой точке штата')
        elseif bizWord and not hasLoc and not hasBizType then
            body = T('любое п/п в любой точке штата')
        elseif vehAbbr and not hasVeh and not hasHouse and body:find(T('а/м'), 1, true) then
            body = body:gsub(T('а/м'), T('а/м любой марки'), 1)
        end
    elseif op == 'sell' or op == 'rent' then
        if bizWord then body = body:gsub(T('бизнес'), T('п/п'), 1) end
        local rj = info.reject
        if hasHouse then
            if not hasClass then rj[#rj + 1] = T('Не указан класс дома') end
            if not hasLoc then rj[#rj + 1] = T('Не указано местоположение дома') end
        end
        if bizWord then
            if not hasBizType then rj[#rj + 1] = T('Не указан тип предприятия') end
            if not hasLoc then rj[#rj + 1] = T('Не указано местоположение предприятия') end
        end
        if vehAbbr and not hasVeh then rj[#rj + 1] = T('Не указана марка транспортного средства') end
    end
    for _, a in ipairs(ABBR) do body = body:gsub(a .. ' ' .. a, a) end
    for _, a in ipairs({ T('а/с'), T('к/с') }) do               -- а/с "X" и а/с "Y" -> а/с "X" и "Y"
        body = body:gsub('%s' .. T('и') .. '%s' .. a .. '%s"', ' ' .. T('и') .. ' "')
    end
    body = body:gsub(T('г%. г%.'), T('г.')):gsub(T('д%. д%.'), T('д.'))

    -- Разные типы имущества (п.2.15)
    local lb = lo(body)
    local kinds, kn = {}, 0
    local function kind(k) if not kinds[k] then kinds[k] = true; kn = kn + 1 end end
    if vehAbbr or hasVeh then kind('transport') end
    if hasHouse then kind('house') end
    if lb:find(T('п/п'), 1, true) or bizWord then kind('biz') end
    if lb:find(T('а/с'), 1, true) then kind('acc') end
    if lb:find(T('к/с'), 1, true) then kind('cloth') end
    if lb:find(T('с/к'), 1, true) then kind('sim') end
    if lb:find(T('н/з'), 1, true) and not kinds.transport then kind('plate') end
    if kn > 1 and op ~= 'swap' and not isEvent then
        info.reject[#info.reject + 1] = T('В одном объявлении указаны разные типы имущества')
        note(T('разные типы имущества в одном объявлении (п.2.15)'))
    end

    -- Обмен на «любой а/м»: добавляем «с доплатой»
    if op == 'swap' and hasVeh and lo(body):find(T('на любой') .. '%s+%S+$') and not lo(body):find(T('доплат'), 1, true) then
        body = body .. T(' с доплатой')
    end

    -- Обмен номерного знака (п.3.2, пример №9): «на другой н/з с доплатой»
    if op == 'swap' and body:find(T('н/з'), 1, true) and not (' ' .. lo(body) .. ' '):find(T(' на '), 1, true) then
        body = body .. T(' на другой н/з с доплатой')
    end

    -- Цена
    do
        local pm = '[' .. T('Премиум') .. ']'
        local pe = pm:gsub('%p', '%%%0')
        while body:find(pe .. ' ' .. pe) do body = body:gsub(pe .. ' ' .. pe, pm) end
    end
    if price and (price < cfg.minPrice or (price > cfg.maxPrice and not body:find(T('[Премиум]'), 1, true))) then
        note(T('цена вне разумного -> договорная/свободный (п.2.21)'))
        price = nil
    end
    if price and hasChai and priceMult and priceMult > 1 then
        note(T('проверь: число с "к" - это цена или количество чая?'))
    end

    -- GPS добавляется в самом конце текста (после цены), см. ниже
    local text
    if op then
        text = OPWORD[op] .. (body ~= '' and (' ' .. body) or '')
        if op == 'swap' then
            if price then note(T('обмен: цена не пишется, при необходимости добавь "с доплатой"')) end
        else
            local label = (op == 'buy') and T('Бюджет') or T('Цена')
            local val
            if unitPrice and not opts.dogovor then
                val = money(unitPrice) .. T(' за ') .. KB.perWord(crimeKind, qty)
            elseif price and (opts.forcePrice or not torg) and not opts.dogovor then
                val = money(price)
            else
                val = (op == 'buy') and T('свободный') or T('договорная')
            end
            text = text .. '. ' .. label .. ': ' .. val
        end
    else
        text = body
        if text ~= '' then text = up(text:sub(1, 1)) .. text:sub(2) end
        if not isEvent then
            note(T('тип сделки не определён, цена не добавлена - проверь вручную'))
            if lowSrc:find('^%[') or lowSrc:find(T('семь'), 1, true) or lowSrc:find(T('мы у '), 1, true)
                or lowSrc:find(T('приглаша'), 1, true) or lowSrc:find(T('организаци'), 1, true) then
                info.org = true
                note(T('похоже на рекламу предприятия/семьи, а не куплю-продажу: нужен контракт (п.2.16) - проверь вручную'))
            end
        end
    end

    if op and op ~= 'swap' and not lo(text):find(T('цена') .. ':', 1, true) and not lo(text):find(T('бюджет') .. ':', 1, true) then
        text = text .. '. ' .. ((op == 'buy') and (T('Бюджет') .. ': ' .. T('свободный')) or (T('Цена') .. ': ' .. T('договорная')))   -- цены нет совсем: договорная / свободный
    end
    if gpsTxt then text = (text ~= '' and (text .. '. ') or '') .. gpsTxt end   -- GPS - в самом конце, перед ним точка
    for _, lb in ipairs({ T('Цена'), T('Бюджет') }) do          -- «Цена: X. Цена: X» -> один раз
        text = text:gsub('[,%.]?%s*' .. lb .. ': .-%.%s*(' .. lb .. ': )', '. %1')
    end
    text = text:gsub('%s+([,%.!%?:;])', '%1')
    text = text:gsub('([,;:!%?])([^%s%d%p])', '%1 %2')
    text = text:gsub('[%s%.]+$', '')      -- точку в конце ставит сам сервер

    for _, w in ipairs(WARN) do
        if lowSrc:find(w[1], 1, true) then note(T('ЗАПРЕЩЕНО/проверь: ') .. w[2]) end
    end
    text = trim((text:gsub('%s+', ' ')))                          -- двойных пробелов не бывает
    if #text > cfg.maxLength then
        note(T('длиннее ') .. cfg.maxLength .. T(' символов'))
    end

    -- Дом: «класса 737 3гаражом» -> «класса с номером "737" 3х гаражом»
    do
        local klass, gar = T('класса'), T('гараж')
        text = text:gsub('(' .. klass .. ') (%d+) (%d)(' .. gar .. ')', '%1 %2 %3' .. T('х') .. ' %4')
        text = text:gsub('(' .. klass .. ') (%d+) (%d' .. T('х') .. ' ' .. gar .. ')', '%1 ' .. T('с номером') .. ' "%2" %3')
    end
    -- Сим-карта (ПРО): цифры номера -> буквы. Только номер в кавычках сразу после «с/к»
    text = text:gsub('(' .. T('с/к') .. ' ")([%d%-]+)(")', function(head, num, tail)
        if select(2, num:gsub('%d', '')) < 3 then return nil end
        local letters, map, n = 'XYZABCDEFG', {}, 0
        local out = num:gsub('%d', function(d)
            if not map[d] then n = n + 1; map[d] = letters:sub(n, n) end
            return map[d]
        end)
        note(T('номер сим-карты: цифры заменены буквами'))
        return head .. out .. tail
    end)

    if text == (trim(stripColors(src)):gsub('[%s%.]+$', '')) then note(T('объявление составлено верно, правок не нужно')) end
    info.op, info.price, info.torg, info.hasHouse, info.hasClass, info.hasLoc =
        op, price, torg, hasHouse, hasClass, hasLoc
    return text, notes, info
end

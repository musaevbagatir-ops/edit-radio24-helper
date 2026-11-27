-- radio24/kb_logic.lua: база знаний ПРО, часть 2: числа, количество, транспорт, намерения. Строки оригинала 465-786. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- БАЗА ЗНАНИЙ ПРО, часть 2: числа, количество, нечёткий поиск транспорта, намерения без цены
-- (люди, знакомства, работа, азартные игры). Таблицы правил - в начале каждого блока.
---------------------------------------------------------------------
do
    local forms = KB.forms
    -- опечатки глаголов сделки
    for w, code in pairs({ ['приобрету'] = 'buy', ['скупаю'] = 'buy', ['кулю'] = 'buy', ['купллю'] = 'buy',
        ['купдю'] = 'buy', ['пордам'] = 'sell', ['прдам'] = 'sell', ['продм'] = 'sell', ['продма'] = 'sell',
        ['продаём'] = 'sell', ['продаем'] = 'sell', ['обмняю'] = 'swap', ['обменю'] = 'swap', ['здам'] = 'rent',
        ['сдаём'] = 'rent', ['сдаем'] = 'rent' }) do OPS[T(w)] = code end
    -- множители чисел (парсер цен parsePrice использует MULT)
    for k, v in pairs({ ['млн'] = 1e6, ['миллион'] = 1e6, ['миллиона'] = 1e6, ['миллионов'] = 1e6, ['лям'] = 1e6,
        ['ляма'] = 1e6, ['лямов'] = 1e6, ['м'] = 1e6, ['m'] = 1e6, ['kkk'] = 1e9, ['тыщ'] = 1e3, ['тысяч'] = 1e3,
        ['тысячи'] = 1e3, ['тыща'] = 1e3, ['тысяча'] = 1e3 }) do MULT[T(k)] = v end
    for _, w in ipairs({ 'красная', 'синяя', 'белая', 'чёрная', 'черная', 'зелёная', 'зеленая', 'жёлтая', 'желтая',
        'серая', 'розовая', 'оранжевая', 'голубой', 'голубую', 'золотой', 'золотую', 'коричневый', 'коричневую',
        'бордовый', 'бордовую', 'серебристый', 'серебристую', 'фиолетовую', 'красного', 'синего', 'белого',
        'чёрного', 'черного', 'зелёного', 'зеленого', 'серого' }) do COLORS[T(w)] = true end
    VEHABBR[T('а/д')] = true
    for _, a in ipairs({ 'в/ч', 'а/д', 'с/о' }) do ABBR[#ABBR + 1] = T(a) end
    local function warn(k, v) WARN[#WARN + 1] = { T(k), T(v) } end
    warn('надоел', 'анти-реклама / принижение других предприятий (п.2.18)')
    warn('лучше чем', 'сравнение с конкурентами (п.2.18)')
    warn('в отличие от', 'сравнение с конкурентами (п.2.18)')
    warn('самый', 'преувеличение (п.2.19)'); warn('самая', 'преувеличение (п.2.19)')
    warn('самые', 'преувеличение (п.2.19)'); warn('самое', 'преувеличение (п.2.19)')
    warn('набор', 'набор в семью/организацию: только при заключённом договоре (п.2.16, п.3.4)')
    warn('вербов', 'набор в семью/организацию: только при заключённом договоре (п.2.16, п.3.4)')

    KB.bizw = set { 'азс', '24/7', 'магазин', 'магазина', 'клуб', 'клуба', 'бар', 'бара', 'закусочная', 'закусочную',
        'пиццерия', 'пиццерию', 'казино', 'ресторан', 'кафе', 'автосалон', 'мастерскую', 'мастерская', 'банк' }
    KB.eventkw = {}
    for _, w in ipairs({ 'розыгрыш', 'проходит', 'проводится', 'мероприят', 'вечеринк', 'конкурс' }) do KB.eventkw[#KB.eventkw + 1] = T(w) end
    KB.bulw = set { 'пт', 'пуль', 'пули', 'пулек', 'пулю', 'патрон' }
    -- детали тюнинга (п.3.2 «неполный тюнинг»): [Tune: нитро, диски]
    KB.tuneparts, KB.tunejunk = {}, set { 'новыми', 'новые', 'новый', 'новым', 'новая', 'новой', 'крутыми', 'хорошими', 'установлены', 'установлен' }
    for lab, list in pairs({ ['нитро'] = { 'нитро', 'нитрой', 'нитру' }, ['диски'] = { 'диски', 'дисками', 'дисков', 'диск' },
        ['гидравлика'] = { 'гидравлика', 'гидравликой', 'гидру' }, ['стерео'] = { 'стерео' },
        ['спойлер'] = { 'спойлер', 'спойлером' }, ['выхлоп'] = { 'выхлоп', 'выхлопом' } }) do
        for _, w in ipairs(list) do KB.tuneparts[T(w)] = T(lab) end
    end
    KB.tunejunk = KB.tunejunk

    -- ЧИСЛА: "1 000 000" и "1.5 млн" -> один токен
    local MULTW = set { 'к', 'кк', 'ккк', 'тыс', 'тыщ', 'тысяч', 'млн', 'миллион', 'миллиона', 'миллионов', 'лям', 'ляма', 'лямов' }
    local QTYU = {}
    for k, v in pairs({ ['шт'] = 'pcs', ['штук'] = 'pcs', ['штуки'] = 'pcs', ['штуку'] = 'pcs', ['пт'] = 'pt',
        ['гр'] = 'gr', ['г'] = 'gr', ['грамм'] = 'gr', ['грамма'] = 'gr', ['граммов'] = 'gr', ['пак'] = 'pak',
        ['пакетик'] = 'pak', ['пакетика'] = 'pak', ['пакетиков'] = 'pak', ['пакетики'] = 'pak', ['пачек'] = 'pach',
        ['пачки'] = 'pach', ['пачка'] = 'pach', ['пачку'] = 'pach', ['покетик'] = 'pak', ['покет'] = 'pak', ['покетика'] = 'pak',
        ['покетиков'] = 'pak', ['покетики'] = 'pak', ['пакет'] = 'pak' }) do QTYU[T(k)] = v end
    local UNITW = set { 'шт', 'штуку', 'штуки', 'штука', 'пакетик', 'пачку', 'пачка', 'пулю', 'единицу', 'штучно',
        'покетик', 'покет', 'пакет' }
    KB.PAKW = set { 'пакетик', 'покетик', 'покет', 'пакет', 'пакетика', 'покетика', 'пакетики', 'покетики' }
    local function tokRaw(tk) return (lo(tk.pre .. tk.core .. tk.post):gsub('[%.,;!]+$', '')) end
    local function tokMoney(tk)
        local raw = tokRaw(tk)
        local num, suf = raw:match('^%$?(%d[%d%.,]*)([^%d%s%$]*)%$?$')
        if not num then return nil end
        local v, mult = parsePrice(num, suf)
        if not v then return nil end
        return v, mult, raw:find('%$') ~= nil
    end
    local function fmtNum(n)
        if n < 10000 then return tostring(n) end
        local r = string.format('%d', n):reverse():gsub('(%d%d%d)', '%1.'):reverse()
        if r:sub(1, 1) == '.' then r = r:sub(2) end
        return r
    end
    KB.mergeNums = function(toks)
        local o, i = {}, 1
        while i <= #toks do
            local tk = toks[i]
            if tk.pre == '' and tk.core:match('^%d[%d%.,]*$') then
                local j, s, last = i + 1, tk.core, tk
                if tk.core:match('^%d%d?%d?$') then
                    local j2, s2, last2 = j, s, last
                    while toks[j2] and last2.post == '' and toks[j2].pre == '' and toks[j2].core:match('^%d%d%d$') do
                        s2 = s2 .. toks[j2].core; last2 = toks[j2]; j2 = j2 + 1
                    end
                    local nx = toks[j2]
                    if j2 > j and not (nx and QTYU[lo(nx.core)]) then j, s, last = j2, s2, last2 end
                end
                local nx = toks[j]
                if nx and last.post == '' and MULTW[lo(nx.core)] then s = s .. nx.core; last = nx; j = j + 1 end
                if j > i + 1 then
                    o[#o + 1] = { pre = tk.pre, core = s, post = last.post }
                    i = j
                else
                    o[#o + 1] = tk; i = i + 1
                end
            else
                o[#o + 1] = tk; i = i + 1
            end
        end
        return o
    end

    -- КОЛИЧЕСТВО и ЦЕНА ЗА ШТУКУ (п.3.5): отдельно от обычной цены
    local CRIMEKW = {
        { 'bullet', { 'патрон', 'пуль', 'боеприпас' } },
        { 'chai', { 'чай', 'чая', 'нарко', 'героин', 'кокаин', 'марихуан', 'гашиш' } },
        { 'tobacco', { 'сиги', 'сигар', 'т/и' } },
        { 'parts', { 'маты', 'материал', 'запчаст' } },
    }
    for _, g in ipairs(CRIMEKW) do for i, w in ipairs(g[2]) do g[2][i] = T(w) end end
    KB.crimeKindOf = function(low)
        local l = ' ' .. low
        for _, g in ipairs(CRIMEKW) do
            for _, w in ipairs(g[2]) do if l:find(' ' .. w, 1, true) then return g[1] end end
            if g[1] == 'bullet' then
                for _, w in ipairs(KB.gunkw) do if l:find(' ' .. w, 1, true) then return 'bullet' end end
            end
        end
        return nil
    end
    KB.extractQty = function(toks, kind, low)
        local qty, unitPrice, big
        KB.unitSeen = nil
        local priceMarks = low:find('%$') or low:find(T('цена'), 1, true) or low:find(T('бюджет'), 1, true)
            or low:find(T('стоим'), 1, true) or low:find(T(' за '), 1, true) or low:find(T(' по '), 1, true)
        local o, i = {}, 1
        local function popDrop() while o[#o] and DROP[lo(o[#o].core)] do o[#o] = nil end end
        local function popIn() if o[#o] and lo(o[#o].core) == T('в') then o[#o] = nil end end
        local function numUnit(tk) return tokRaw(tk):match('^(%d[%d%.,]*)(%D*)$') end
        local function numVal(num, suf)
            local n
            if suf == T('к') or suf == 'k' then n = (tonumber((num:gsub(',', '.'))) or 0) * 1000
            else n = tonumber((num:gsub('[%.,]', ''))) end
            return n and math.floor(n + 0.5) or nil
        end
        while i <= #toks do
            local tk = toks[i]
            local c = lo(tk.core)
            local nx, nx2 = toks[i + 1], toks[i + 2]
            local used = 0
            if (c == T('за') or c == T('по')) and nx and UNITW[lo(nx.core)] and nx2 and tokMoney(nx2) and not unitPrice then
                unitPrice = (tokMoney(nx2)); KB.unitSeen = QTYU[lo(nx.core)]; popDrop(); used = 3
            elseif c == T('по') and nx and not unitPrice and tokMoney(nx) then
                local v, mult, dollar = tokMoney(nx)
                if dollar or mult > 1 then unitPrice = v; popDrop(); used = 2 end
            elseif nx and nx2 and not unitPrice and tokMoney(tk) and (lo(nx.core) == T('за') or nx.core == '/') and UNITW[lo(nx2.core)] then
                unitPrice = (tokMoney(tk)); KB.unitSeen = QTYU[lo(nx2.core)]; used = 3
            end
            if used == 0 and not qty then
                local num, suf = numUnit(tk)
                if (c == T('кол-во') or c == T('колво') or c == T('количество') or c == T('количестве') or c == T('кол-ве'))
                    and nx and numUnit(nx) then
                    local n2, s2 = numUnit(nx)
                    local n = numVal(n2, s2 == T('к') and s2 or '')
                    if n then qty = { n = n, unit = QTYU[s2] or (s2 == T('к') and 'k' or 'pcs'), glued = false }; popIn(); used = 2 end
                elseif num and QTYU[suf] then
                    qty = { n = numVal(num, ''), unit = QTYU[suf], glued = true }; used = 1
                elseif num and suf == '' and nx and QTYU[lo(nx.core)] and not tk.core:find('%$') then
                    qty = { n = numVal(num, ''), unit = QTYU[lo(nx.core)], glued = false }; used = 2
                elseif num and (suf == T('к') or suf == 'k') and kind == 'chai' and not priceMarks then
                    qty = { n = numVal(num, suf), unit = 'k', glued = true }; used = 1
                end
                if qty and not qty.n then qty = nil; used = 0 end
            end
            if used == 0 then
                if c == T('много') then big = true; used = 1
                elseif c == T('большое') and nx and lo(nx.core) == T('количество') then big = true; used = 2
                elseif (c == T('большом') or c == T('многом')) and nx and (lo(nx.core) == T('количестве') or lo(nx.core) == T('кол-ве')) then
                    big = true; popIn(); used = 2
                end
            end
            if used == 0 then o[#o + 1] = tk; i = i + 1 else i = i + used end
        end
        if unitPrice then                       -- «чайный покетик за покет 250$»: лишнее слово-единица не нужно
            local o2 = {}
            for _, tk in ipairs(o) do
                if not KB.PAKW[lo(tk.core)] then o2[#o2 + 1] = tk end
            end
            o = o2
        end
        return qty, unitPrice, big, o
    end
    KB.qtyPhrase = function(kind, q)
        local n = fmtNum(q.n)
        if kind == 'chai' then
            if q.unit == 'gr' or q.unit == 'pach' then return T('в количестве ') .. n .. T(' пачек') end
            return T('в кол-ве ') .. n .. T(' пакетиков')
        elseif kind == 'bullet' then
            return T('в количестве ') .. n .. T(' штук')
        elseif kind == 'tobacco' then
            return T('в кол-ве ') .. n .. T(' шт')
        end
        return T('в кол-ве ') .. n .. (q.glued and '' or ' ') .. T('шт')
    end
    KB.perWord = function(kind, q)
        if kind == 'chai' then
            local u = (q and q.unit) or KB.unitSeen
            return (u == 'pak') and T('пакетик') or T('пачку')
        end
        return T('штуку')
    end

    -- НЕЧЁТКИЙ ПОИСК транспорта: только если вариант единственный (иначе не угадываем)
    local function editDist(a, b, lim)
        local la, lb = #a, #b
        if math.abs(la - lb) > lim then return lim + 1 end
        local prev = {}
        for j = 0, lb do prev[j] = j end
        for i = 1, la do
            local cur = { [0] = i }
            local best = i
            for j = 1, lb do
                local cst = (a:byte(i) == b:byte(j)) and 0 or 1
                local v = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cst)
                cur[j] = v
                if v < best then best = v end
            end
            if best > lim then return lim + 1 end
            prev = cur
        end
        return prev[lb]
    end
    KB.fuzzyVeh = function(word)
        if #word < 6 or word:find('[%d%p]') then return nil end
        local lim = #word >= 9 and 2 or 1
        local best, bd, amb = nil, lim + 1, false
        for _, e in ipairs(KB.vehfuzz) do
            local d = editDist(word, e.key, lim)
            if d > 0 and d <= lim then
                if d < bd then best, bd, amb = e, d, false
                elseif d == bd and e.val ~= best.val then amb = true end
            end
        end
        if best and not amb then return best end
        return nil
    end

    -- НАМЕРЕНИЯ БЕЗ ЦЕНЫ (п.3.6): работа, азартные игры, тир, знакомства, поиск человека
    KB.editDist = editDist
    -- ТИПОВЫЕ ОПЕЧАТКИ ключевых слов: исправляем, только если до ОДНОГО известного слова минимум правок
    KB.VOCW, KB.VOCL = {}, {}
    for _, w in ipairs({ 'продам', 'куплю', 'обменяю',
        'договорная', 'договорную', 'свободный', 'свободная', 'бюджет',
        'особняк', 'особняка', 'особняки', 'гараж', 'гаража', 'гаражом', 'гаражи', 'гаражей', 'подвал', 'подвала',
        'евроремонт', 'евроремонтом', 'эконом', 'комфорт', 'бизнес', 'бизнеса', 'класс', 'класса', 'классе',
        'район', 'района', 'районе', 'районы', 'районов', 'опасном', 'опасный', 'опасного', 'опасному', 'опасные',
        'штата', 'штат', 'штаты', 'штату', 'точке', 'точка', 'точку', 'точки', 'любой', 'любого', 'любое', 'любую', 'любые', 'любом', 'любым',
        'горы', 'гору', 'гора', 'коллекции', 'коллекция', 'коллекцию',
        'крылья', 'крыльев', 'крыльями', 'спину', 'спина', 'спины', 'спине',
        'вертушка', 'вертушку', 'вертушки', 'пальма', 'пальму', 'пальмы', 'посох', 'посоха', 'некроманта', 'некромант',
        'сигара', 'сигару', 'сигары', 'сигаре', 'чумной', 'чумного', 'доктор', 'доктора',
        'санта', 'клаус', 'тыковка', 'тыковку', 'тыковки', 'спасательница', 'спасательницу',
        'мистер', 'мистера', 'улыбка', 'улыбку', 'улыбки',
        'эксклюзивный', 'эксклюзивную', 'эксклюзивного', 'транспорт', 'транспорта', 'транспорту',
        'купон', 'купона', 'купоны', 'купонов', 'скидка', 'скидку', 'скидки', 'скидочный',
        'формата', 'формат', 'форматом', 'формате', 'номер', 'номера', 'номеру', 'номеров', 'номере',
        'пакетик', 'пакетика', 'пакетиков', 'пакетики', 'количестве', 'количество', 'большом', 'большое',
        'аксессуар', 'аксессуары', 'аксессуара', 'квартиру', 'квартира' }) do
        KB.VOCW[T(w)] = true
    end
    for w in pairs(KB.VOCW) do KB.VOCL[#KB.VOCL + 1] = w end
    table.sort(KB.VOCL)
    KB.fuzzyWord = function(word)
        if #word < 5 or word:find('[%d%p]') or word:byte(1) < 128 or KB.VOCW[word] then return nil end
        for i = 1, #word - 1 do                                   -- перестановка соседних букв
            local sw = word:sub(1, i - 1) .. word:sub(i + 1, i + 1) .. word:sub(i, i) .. word:sub(i + 2)
            if KB.VOCW[sw] then return sw end
        end
        local lim = #word >= 9 and 2 or 1
        local best, bd, amb = nil, lim + 1, false
        for _, w in ipairs(KB.VOCL) do
            local d = editDist(word, w, lim)
            if d > 0 and d <= lim then
                if d < bd then best, bd, amb = w, d, false
                elseif d == bd and w ~= best then amb = true end
            end
        end
        if best and not amb then return best end
        return nil
    end
    -- опечатки в «договорная» / «свободный» / «бюджет» ("сваюодный", "договарная")
    KB.KWS = { { 'dog', 'договорная' }, { 'svob', 'свободный' }, { 'drop', 'бюджет' }, { 'drop', 'стоимость' } }
    for _, k in ipairs(KB.KWS) do k[2] = T(k[2]) end
    KB.kw = function(core)
        if #core < 6 or core:find('[%d%p]') or core:byte(1) < 128 then return nil end
        for _, k in ipairs(KB.KWS) do
            if math.abs(#core - #k[2]) <= 2 then
                local lim = #k[2] >= 9 and 2 or 1
                if editDist(core, k[2], lim) <= lim then return k[1] end
            end
        end
        return nil
    end

    local TR = {}
    for k, v in pairs({ ['а'] = 'a', ['б'] = 'b', ['в'] = 'v', ['г'] = 'g', ['д'] = 'd', ['е'] = 'e', ['ё'] = 'e',
        ['ж'] = 'zh', ['з'] = 'z', ['и'] = 'i', ['й'] = 'y', ['к'] = 'k', ['л'] = 'l', ['м'] = 'm', ['н'] = 'n',
        ['о'] = 'o', ['п'] = 'p', ['р'] = 'r', ['с'] = 's', ['т'] = 't', ['у'] = 'u', ['ф'] = 'f', ['х'] = 'h',
        ['ц'] = 'ts', ['ч'] = 'ch', ['ш'] = 'sh', ['щ'] = 'sch', ['ъ'] = '', ['ы'] = 'y', ['ь'] = '', ['э'] = 'e',
        ['ю'] = 'yu', ['я'] = 'ya' }) do TR[T(k)] = v end
    local function translit(w)
        local r = {}
        for ch in lo(w):gmatch('.') do r[#r + 1] = TR[ch] or ch end
        local s = table.concat(r)
        return s:sub(1, 1):upper() .. s:sub(2)
    end
    -- ===== РАБОТА / АЗАРТНЫЕ ИГРЫ: помощники разбора намерений (слова в UTF-8, T() -> CP1251) =====
    local function TL(list) local r = {}; for _, w in ipairs(list) do r[#r + 1] = T(w) end; return r end
    local function cleanW(w) w = w:gsub('^[%p%s]+', ''); w = w:gsub('[%p%s]+$', ''); return w end
    local function wordList(low)
        local W, E = {}, {}
        for w in low:gmatch('%S+') do
            local c = cleanW(w)
            if c ~= '' then W[#W + 1] = c; E[#W] = w:find('[,;%.!%?:]$') ~= nil end
        end
        return W, E
    end
    local function startsAny(w, stems)
        for _, st in ipairs(stems) do if w:sub(1, #st) == st then return true end end
        return false
    end
    local function fuzzyIn(list, w)            -- опечатка в длинном слове (от 6 букв): 1 правка, от 9 - 2
        if #w < 6 then return false end
        local lim = #w >= 9 and 2 or 1
        for _, k in ipairs(list) do
            if #k >= 6 and math.abs(#w - #k) <= lim and editDist(w, k, lim) <= lim then return true end
        end
        return false
    end
    local function wordHit(W, exact, stems, fuzz)
        for _, w in ipairs(W) do
            if exact and exact[w] then return true end
            if stems and startsAny(w, stems) then return true end
            if fuzz and w:byte(1) >= 128 and fuzzyIn(fuzz, w) then return true end
        end
        return false
    end
    local MONEYSUF = set { '', 'к', 'кк', 'ккк', 'k', 'kk', 'kkk', 'тыс', 'тыщ', 'тысяч', 'млн', 'м', 'm', 'лям', 'ляма', 'лямов',
        'миллион', 'миллиона', 'миллионов' }
    local FILL = set { 'от', 'в', 'на', 'по', 'до', 'за', 'около', 'примерно', 'порядка' }
    local function moneyAt(W, i)
        local w = W[i]
        if not w then return nil end
        local num, suf = w:match('^(%d[%d%.,]*)(%D*)$')
        if not num or not MONEYSUF[suf] then return nil end
        local digits = num:gsub('[%.,]', '')
        if suf == '' and #digits < 3 then return nil end        -- голое маленькое число - не сумма
        local ok, v = pcall(parsePrice, num, suf)
        if ok and type(v) == 'number' and v > 0 then return v end
        return nil
    end
    -- сумма: рядом со словом-ключом (ставка/цена/зп...), иначе любая сумма в тексте (кроме номеров телефонов)
    local function findMoney(low, kws)
        for _ = 1, 3 do low = low:gsub('(%d) (%d%d%d)%f[%D]', '%1%2') end
        local W = wordList(low)
        for i, w in ipairs(W) do
            if startsAny(w, kws) then
                for j = i + 1, math.min(i + 3, #W) do
                    local v = moneyAt(W, j)
                    if v then return v end
                    if not FILL[W[j]] then break end
                end
            end
        end
        for i = 1, #W do
            local pv = W[i - 1] or ''
            if pv:sub(1, 3) ~= T('тел') and pv:sub(1, 3) ~= T('ном') then
                local v = moneyAt(W, i)
                if v then return v end
            end
        end
        return nil
    end
    -- хвост "Ставка: ..." / "Цена: ..." (ставка работает как цена и бюджет)
    local function tailFor(low, label, kws, from, dflt)
        local v = findMoney(low, kws)
        if v then return '. ' .. label .. ': ' .. (from and (T('от ') .. money(v)) or money(v)) end
        if low:find(T('договор'), 1, true) then return '. ' .. label .. T(': договорная') end
        if low:find(T('свободн'), 1, true) then
            return '. ' .. label .. (label == T('Ставка') and T(': свободная') or T(': договорная'))
        end
        if dflt then return '. ' .. label .. T(': договорная') end
        return ''
    end

    -- азартные игры / тир
    local G_DICE  = set { 'кости', 'кость', 'костей', 'костях', 'костям', 'костями', 'косточки', 'косточек', 'кубики', 'кубик',
        'кубика', 'кубиков', 'казино', 'казик', 'казика', 'казине', 'dice', 'дайс', 'дайсы' }
    local G_DICEF = TL { 'казино', 'косточки', 'кубики' }
    local G_COINS = TL { 'монет', 'орел', 'орёл', 'орлян', 'решк' }
    local G_BAR   = set { 'бар', 'бара', 'бару', 'баре' }
    local G_TIR   = set { 'дмз', 'дмс', 'дзм', 'дмзз', 'dmz', 'тир', 'тира', 'тиру', 'тире', 'тиры' }
    local G_TIRS  = TL { 'стрельб', 'пострел', 'стрелят', 'стреляй' }
    local G_TIRF  = TL { 'стрельба', 'пострелять', 'стрельбище' }
    local STAKE_KW = TL { 'ставк', 'ставл', 'бюджет', 'цена', 'цену', 'ценой' }

    -- работа
    local JOB_SKIP = set { 'на', 'работу', 'работа', 'работе', 'работы', 'по', 'как', 'кем', 'кем-то', 'кем-нибудь', 'кем-либо',
        'угодно', 'пожалуйста', 'срочно', 'любую', 'любая', 'любой', 'любым', 'любое', 'любого', 'хорошую', 'нормальную',
        'постоянную', 'оплачиваемую', 'хочу', 'желаю', 'буду', 'работать', 'ищу', 'ищем', 'нужна', 'нужен', 'нужно',
        'возьмите', 'устроюсь', 'устроюся', 'трудоустроюсь', 'трудоустроюся', 'устроиться', 'трудоустроиться', 'мне', 'я', 'а',
        'бы', 'то', 'же', 'либо', 'именно', 'где', 'можно', 'вакансию', 'должность', 'профессии', 'профессия', 'сфере',
        'сфера', 'деятельности', 'сейчас', 'готов', 'готова', 'плз', 'пж', 'просто', 'какую', 'какую-нибудь', 'любую-нибудь',
        'нибудь', 'желательно' }
    local JOB_STOP = set { 'зп', 'з/п', 'зарплата', 'зарплату', 'зарплаты', 'оплата', 'оплату', 'оплатой', 'плата', 'платят',
        'от', 'до', 'за', 'опыт', 'опытом', 'имею', 'имеется', 'цена', 'цену', 'бюджет', 'ставка', 'договорная', 'свободная',
        'тел', 'телефон', 'звоните', 'пишите', 'стаж', 'с', 'со' }
    local SAL_KW = TL { 'зп', 'з/п', 'зарплат', 'оплат', 'платят', 'получать', 'ставк', 'цена', 'цену', 'бюджет' }
    local VOWELS = set { 'а', 'е', 'ё', 'и', 'о', 'у', 'ы', 'э', 'ю', 'я' }
    local function accToInstr(w)               -- "на охранника" -> "охранником", "на водителя" -> "водителем"
        if #w < 6 then return w end
        local last, pre = w:sub(-1), w:sub(-2, -2)
        if VOWELS[pre] then return w end
        if w == T('врача') then return T('врачом') end
        if last == T('а') then
            if pre:find('[' .. T('жчшщ') .. ']') then return w:sub(1, -2) .. T('ем') end
            return w:sub(1, -2) .. T('ом')
        elseif last == T('я') then
            return w:sub(1, -2) .. T('ем')
        end
        return w
    end
    local function hasW(W, ...)
        for _, a in ipairs({ ... }) do
            for _, w in ipairs(W) do if w == T(a) then return true end end
        end
        return false
    end
    -- индекс слова-триггера "ищу работу" или nil (объявления о НАЙМЕ - не наши)
    local function jobSeek(W)
        local trg
        for i, w in ipairs(W) do
            if w:find(T('работник'), 1, true) or w:find(T('сотрудник'), 1, true) or w:find(T('вакан'), 1, true)
                or w:find(T('требуетс'), 1, true) or w:sub(1, 5) == T('набор') or w:find(T('нанима'), 1, true) then return nil end
            if not trg then
                if w:sub(1, 5) == T('устро') or w:sub(1, 7) == T('трудоус') or w:sub(1, 7) == T('трудаус') or w:sub(1, 7) == T('тродоус') then trg = i
                elseif #w >= 9 and w:byte(1) >= 128 and editDist(w, T('трудоустроюсь'), 3) <= 3 then trg = i end
            end
        end
        if trg then return trg end
        for i, w in ipairs(W) do
            if w:sub(1, 5) == T('работ') and w ~= T('работа') or w == T('работа') then
                if w:sub(1, 7) ~= T('работат') and hasW(W, 'ищу', 'нужна', 'нужно', 'ищем', 'возьмите', 'подскажите', 'помогите', 'хочу', 'ищет') then return i end
            end
            if w:sub(1, 7) == T('работат') and hasW(W, 'хочу', 'буду', 'желаю', 'готов', 'готова', 'хотел', 'хотела') then return i end
        end
        return nil
    end
    local function jobRole(W, E, trg)
        local out, prep = {}, nil
        for i = trg + 1, #W do
            local w = W[i]
            if JOB_STOP[w] or w:find('%d') then break end
            if (w == T('в') or w == T('во')) and #out == 0 then
                prep = w
            elseif not JOB_SKIP[w] then
                local x = w
                if #out == 0 and W[i - 1] == T('на') then x = accToInstr(x) end
                out[#out + 1] = x
                if #out >= 4 or E[i] then break end
            end
        end
        if #out == 0 then                         -- роль перед триггером: "охранником устроюсь"
            for i = trg - 1, math.max(1, trg - 3), -1 do
                local w = W[i]
                if not JOB_SKIP[w] and not JOB_STOP[w] and (w:sub(-2) == T('ом') or w:sub(-2) == T('ем') or w:sub(-2) == T('ой') or w:sub(-2) == T('ей')) then
                    table.insert(out, 1, w)
                else break end
            end
        end
        while #out > 0 and (out[#out] == T('и') or out[#out] == T('или')) do out[#out] = nil end
        if #out == 0 then return '' end
        local r = table.concat(out, ' ')
        if prep then r = prep .. ' ' .. r end
        return r
    end
    local function jobText(low, W, E, trg)
        local role = jobRole(W, E, trg)
        local t = T('Трудоустроюсь')
        if role ~= '' then t = t .. ' ' .. role .. T('. О себе: имею опыт в данной сфере деятельности')
        else t = t .. T('. О себе: имеется опыт во всех сферах деятельности') end
        return t .. tailFor(low, T('Цена'), SAL_KW, false, false)
    end
    KB.intentNew = function(s, low, note, has)
        local W, E = wordList(low)
        local trg = jobSeek(W)
        if trg then return jobText(low, W, E, trg) end
        if has('ищу', 'ищем', 'игрок', 'игра', 'сыгра', 'поигра', 'желающ', 'партнёр', 'партнер') then
            local play = has('игрок', 'игра', 'сыгра', 'поигра', 'желающ', 'партн')
            local tir = wordHit(W, G_TIR, G_TIRS, G_TIRF)
            local dice = wordHit(W, G_DICE, nil, G_DICEF)
            local coin = wordHit(W, nil, G_COINS, nil) or (play and wordHit(W, G_BAR, nil, nil))
            if tir or dice or coin then
                local stake = tailFor(low, T('Ставка'), STAKE_KW, false, true)
                if tir then return T('Ищу человека в "Тир"') .. stake end
                local g = dice and T('Кости') or T('Орел и решка')
                return T('Ищу азартного игрока в "') .. g .. '"' .. stake
            end
        end
        return nil
    end

    local NAMES = {}                        -- известные имена: 'English|русское' (формы строятся сами)
    local NAMES_SPEC = { 'Jackson|джексон,джэксон,джекссон,жексон', 'Hellwood|хеллвуд,хелвуд,хэллвуд,хэлвуд,хеллвод',
        'Miller|миллер,милер', 'Wayne|уэйн,вейн,вэйн,уэин', 'Smith|смит', 'Johnson|джонсон', 'Brown|браун', 'Williams|уильямс,вильямс',
        'Anderson|андерсон', 'Taylor|тейлор,тэйлор', 'Thomas|томас', 'Moore|мур', 'Martin|мартин', 'Davis|дэвис,дейвис,девис',
        'Wilson|уилсон,вилсон', 'Clark|кларк', 'Lewis|льюис,люис', 'Walker|уокер,вокер', 'Hall|холл', 'Allen|аллен', 'Young|янг',
        'King|кинг', 'Scott|скотт', 'Green|грин', 'Baker|бейкер,бэйкер', 'Adams|адамс', 'Nelson|нельсон', 'Carter|картер',
        'Mitchell|митчелл', 'Roberts|робертс', 'Turner|тернер,тёрнер', 'Parker|паркер', 'Evans|эванс', 'Collins|коллинз',
        'Stewart|стюарт', 'Morris|моррис', 'Rogers|роджерс', 'Cook|кук', 'Morgan|морган', 'Bell|белл', 'Murphy|мерфи',
        'Cooper|купер', 'Howard|ховард,говард', 'Ward|уорд', 'Gray|грей', 'James|джеймс', 'Watson|уотсон,ватсон', 'Brooks|брукс',
        'Kelly|келли', 'Price|прайс', 'Bennett|беннетт', 'Wood|вуд', 'Ross|росс', 'Foster|фостер', 'Bryant|брайант',
        'Russell|рассел', 'Harris|харрис', 'Jones|джонс', 'Garcia|гарсия', 'Lopez|лопес', 'Perez|перес', 'Sanchez|санчес,санчез',
        'Rodriguez|родригес', 'Gonzalez|гонзалес', 'Hernandez|эрнандес,хернандес', 'Soto|сото', 'Romero|ромеро', 'Diaz|диас,диаз',
        'Cruz|круз', 'Torres|торрес', 'Ramirez|рамирес', 'Flores|флорес', 'Castillo|кастильо', 'Morales|моралес', 'Vega|вега',
        'Rivera|ривера', 'Gomez|гомес', 'Reyes|рейес', 'John|джон', 'Michael|майкл,майк', 'David|дэвид,дейвид', 'Robert|роберт',
        'William|уильям,вильям', 'Richard|ричард', 'Joseph|джозеф', 'Charles|чарльз', 'Daniel|дэниел,дениел', 'Anthony|энтони',
        'Mark|марк', 'Steven|стивен', 'Andrew|эндрю', 'Kevin|кевин', 'Brian|брайан', 'George|джордж', 'Edward|эдвард',
        'Jason|джейсон', 'Ryan|райан', 'Jacob|джейкоб', 'Eric|эрик', 'Tyler|тайлер', 'Adam|адам', 'Henry|генри', 'Peter|питер',
        'Alex|алекс', 'Max|макс', 'Tommy|томми', 'Johnny|джонни', 'Frank|фрэнк,френк', 'Jack|джек,джэк', 'Oliver|оливер',
        'Liam|лиам', 'Ethan|итан,этан', 'Lucas|лукас', 'Mason|мейсон', 'Logan|логан', 'Dylan|дилан', 'Emma|эмма', 'Olivia|оливия',
        'Sophia|софия', 'Emily|эмили', 'Chloe|хлоя', 'Sarah|сара', 'Jessica|джессика', 'Jennifer|дженнифер' }
    local NAMEKIND, isFirstPart = {}, false      -- вид слова: f = имя, l = фамилия
    for _, spec in ipairs(NAMES_SPEC) do
        local en, rus = spec:match('^(.-)|(.+)$')
        if en == 'John' then isFirstPart = true end
        NAMEKIND[en] = isFirstPart and 'f' or 'l'
        for ru in rus:gmatch('[^,]+') do
            pcall(function() for _, f in ipairs(forms(ru)) do NAMES[T(f)] = en end end)
        end
    end
    local TRAITS = { { 'богат', 'богатый' }, { 'красив', 'красивый' }, { 'добр', 'добрый' }, { 'щедр', 'щедрый' },
        { 'весел', 'весёлый' }, { 'спортивн', 'спортивный' } }
    for _, t in ipairs(TRAITS) do t[1] = T(t[1]); t[2] = T(t[2]) end
    local SKIPW = set { 'человека', 'человек', 'по', 'имени', 'парня', 'игрока', 'знакомого', 'друга' }
    local function hasOp(low)
        for w in low:gmatch('%S+') do
            local c = w:gsub('^%p+', ''):gsub('%p+$', '')
            if OPS[c] then return true end
        end
        return false
    end
    local PERSON_TRG = set { 'ищу', 'ищем', 'ищет', 'разыскиваю', 'найдите', 'найти' }
    local function nameLookup(core)            -- известное имя (с падежами) или с опечаткой в 1 букву
        local l = lo(core)
        if NAMES[l] then return NAMES[l] end
        if peopleGet then                              -- выученные имена и фамилии (с падежами)
            local okp, en = pcall(peopleGet, l)
            if okp and en then return en end
        end
        if #l >= 6 and l:byte(1) >= 128 then
            local best, amb = nil, false
            for k, en in pairs(NAMES) do
                if math.abs(#k - #l) <= 1 and editDist(l, k, 1) == 1 then
                    if best and best ~= en then amb = true end
                    best = en
                end
            end
            if best and not amb then return best end
        end
        return nil
    end
    local function personName(s, note)
        local first, rest = s:match('^%s*(%S+)%s+(.+)$')
        if not first or not PERSON_TRG[lo(first)] then return nil end
        local names = {}
        for w in rest:gmatch('%S+') do
            local core = w:gsub('^["%.,!%?]+', ''):gsub('["%.,!%?]+$', '')
            if SKIPW[lo(core)] and #names == 0 then
                -- служебное слово перед именем
            elseif core ~= '' and (isUpper(core:sub(1, 1)) or nameLookup(core)) then
                names[#names + 1] = core
            else
                return nil
            end
        end
        if #names == 0 or #names > 3 then return nil end
        local out = {}
        for _, w in ipairs(names) do
            if w:find('[\192-\255\168\184]') then
                local en = nameLookup(w)
                if not en then en = translit(w); note(T('имя транслитерировано автоматически - проверь написание: ') .. en) end
                out[#out + 1] = en
            else
                out[#out + 1] = (w:gsub('_', ' '))
            end
        end
        if #out == 2 then                         -- известна фамилия + имя в обратном порядке: ставим Имя Фамилия
            local function kindOf(en) return NAMEKIND[en] or (PKIND and PKIND[en]) end
            if kindOf(out[1]) == 'l' and kindOf(out[2]) == 'f' then out[1], out[2] = out[2], out[1] end
        end
        return T('Ищу человека по имени ') .. table.concat(out, ' ') .. T('. Перезвони по возможности')
    end
    KB.intent = function(s, low, note)
        if hasOp(low) then return nil end
        local l = ' ' .. low
        local function has(...)
            for _, w in ipairs({ ... }) do if l:find(T(w), 1, true) then return true end end
            return false
        end
        -- работа / азартные игры / тир (новый разбор: опечатки, контекст, роли, ставка как цена)
        local okN, resN = pcall(KB.intentNew, s, low, note, has)
        if okN and resN then return resN end
        -- знакомства / отношения / друзья
        if has('познаком', 'знакомств') or (has('ищу') and has('девушк', 'парня', 'парн', 'друз', 'друга')) then
            local who
            if has('девушк', 'девчонк') then who = T('Познакомлюсь с девушкой для с/о')
            elseif has('парн', 'пацан') then who = T('Познакомлюсь с парнем для с/о')
            elseif has('друз', 'друга') then who = T('Познакомлюсь с друзьями для общения') end
            if who then
                local tr = {}
                for _, t in ipairs(TRAITS) do if low:find(t[1], 1, true) then tr[#tr + 1] = t[2] end end
                if #tr > 0 then who = who .. T('. О себе: ') .. table.concat(tr, ', ') end
                return who
            end
        end
        -- поиск человека по имени
        return personName(s, note)
    end
end

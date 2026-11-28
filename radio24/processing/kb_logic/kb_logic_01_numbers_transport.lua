-- radio24/processing/kb_logic_01_numbers_transport.lua: часть 1 из 3 файла processing/kb_logic. числа ("1.5 млн"), количество и цена за штуку, нечёткий поиск транспорта. Общее окружение модулей, см. radio24_helper.lua
-- Локальные переменные, нужные соседним частям, передаются через таблицу LOGICX (в конце части экспорт, в начале - повторное объявление).
---------------------------------------------------------------------
-- БАЗА ЗНАНИЙ ПРО, часть 2: числа, количество, нечёткий поиск транспорта, намерения без цены
-- (люди, знакомства, работа, азартные игры). Таблицы правил - в начале каждого блока.
---------------------------------------------------------------------
do
    local forms = KB.forms
    -- опечатки глаголов сделки
    for w, code in pairs({ ['приобрету'] = 'buy', ['купи'] = 'buy', ['скупаю'] = 'buy', ['кулю'] = 'buy', ['купллю'] = 'buy',
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

    LOGICX = LOGICX or {}; LOGICX.forms = forms; LOGICX.editDist = editDist
end

-- radio24/processing/kb_logic_02_typos_helpers.lua: часть 2 из 3 файла processing/kb_logic. намерения без цены: опечатки ключевых слов, помощники разбора (поиск суммы, хвост "Ставка:"). Общее окружение модулей, см. radio24_helper.lua
-- Локальные переменные, нужные соседним частям, передаются через таблицу LOGICX (в конце части экспорт, в начале - повторное объявление).
do
    local forms, editDist = LOGICX.forms, LOGICX.editDist
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

    LOGICX = LOGICX or {}; LOGICX.translit = translit; LOGICX.TL = TL; LOGICX.wordList = wordList; LOGICX.wordHit = wordHit; LOGICX.tailFor = tailFor
end

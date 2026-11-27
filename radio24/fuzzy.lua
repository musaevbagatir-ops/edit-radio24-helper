-- radio24/fuzzy.lua: тэги ([BDAY7], [BP]...) и поиск названий с опечатками и в русской записи. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- Расстояние между строками (вставка/удаление/замена/перестановка соседних букв), mx - порог
---------------------------------------------------------------------
function strDist(a, b, mx)
    local la, lb = #a, #b
    if math.abs(la - lb) > mx then return mx + 1 end
    local d = {}
    for i = 0, la do d[i] = { [0] = i } end
    for j = 0, lb do d[0][j] = j end
    for i = 1, la do
        for j = 1, lb do
            local cost = (a:byte(i) == b:byte(j)) and 0 or 1
            local v = math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
            if i > 1 and j > 1 and a:byte(i) == b:byte(j - 1) and a:byte(i - 1) == b:byte(j) then
                v = math.min(v, d[i - 2][j - 2] + 1)
            end
            d[i][j] = v
        end
    end
    return d[la][lb]
end

---------------------------------------------------------------------
-- СКЕЛЕТ СЛОВА: общий вид для латиницы и кириллицы. Гласные выбрасываются (но считаются отдельно),
-- согласные приводятся к одному алфавиту: шкода октавия = Skoda Octavia = "skdktv", бдей = BDAY = "bd".
-- Возвращает скелет и число гласных (y / й не считаются гласными ни там, ни там).
---------------------------------------------------------------------
local LAT_DI = { sh = 's', ch = 'c', ph = 'f', th = 't', ck = 'k', kh = 'h', zh = 'j' }
local LAT_ONE = {}
for ch in ('bdfghjklmnprstv'):gmatch('.') do LAT_ONE[ch] = ch end
LAT_ONE.z, LAT_ONE.q, LAT_ONE.w = 's', 'k', 'v'
local LAT_VOW = { a = true, e = true, i = true, o = true, u = true }
local CYR_VOW, CYR_MAP = {}, {}
for _, ch in ipairs({ 'а', 'е', 'ё', 'и', 'о', 'у', 'ы', 'э', 'ю', 'я' }) do CYR_VOW[T(ch)] = true end
for k, v in pairs({ ['б'] = 'b', ['в'] = 'v', ['г'] = 'g', ['д'] = 'd', ['ж'] = 'j', ['з'] = 's', ['к'] = 'k',
    ['л'] = 'l', ['м'] = 'm', ['н'] = 'n', ['п'] = 'p', ['р'] = 'r', ['с'] = 's', ['т'] = 't', ['ф'] = 'f',
    ['х'] = 'h', ['ц'] = 's', ['ч'] = 'c', ['ш'] = 's', ['щ'] = 's' }) do CYR_MAP[T(k)] = v end

local CYR_D, CYR_ZH = T('д'), T('ж')

function skelOf(str)
    local s = lo(str or '')
    local out, last, vow, i, n = {}, '', 0, 1, #s
    local function put(c) if c ~= last then out[#out + 1] = c; last = c end end
    while i <= n do
        local ch = s:sub(i, i)
        local nx = s:sub(i + 1, i + 1)
        if ch:match('%d') then
            out[#out + 1] = ch; last = ''
        elseif ch:match('%a') then
            if LAT_DI[ch .. nx] then put(LAT_DI[ch .. nx]); i = i + 1
            elseif ch == 'c' then put((nx == 'e' or nx == 'i' or nx == 'y') and 's' or 'k')
            elseif ch == 'x' then put('k'); put('s')
            elseif LAT_ONE[ch] then put(LAT_ONE[ch])
            elseif LAT_VOW[ch] then vow = vow + 1; last = ''
            end
        else
            local m = CYR_MAP[ch]
            if ch == CYR_D and nx == CYR_ZH then put('j'); i = i + 1      -- дж = j (Джонс = Jones)
            elseif m then put(m)
            elseif CYR_VOW[ch] then vow = vow + 1; last = '' end
        end
        i = i + 1
    end
    return table.concat(out), vow
end

local function digitsOf(x) return (x:gsub('%D', '')) end

-- Рисунок гласных по классам (а/о/я -> a, е/э/и/ы -> e, у/ю -> u): для коротких названий, где скелета мало.
-- Toyota = "aaa", тойота = "aaa", а вот таити = "aee" - не совпадает. y как гласная не считается.
local VCLS = {}
for _, ch in ipairs({ 'а', 'о', 'я', 'ё' }) do VCLS[T(ch)] = 'a' end
for _, ch in ipairs({ 'е', 'э', 'и', 'ы' }) do VCLS[T(ch)] = 'e' end
for _, ch in ipairs({ 'у', 'ю' }) do VCLS[T(ch)] = 'u' end
local VLAT = { a = 'a', o = 'a', e = 'e', i = 'e', u = 'u' }
local function vowSig(str)
    local s, out = lo(str or ''), {}
    for i = 1, #s do
        local ch = s:sub(i, i)
        local c = VLAT[ch] or VCLS[ch]
        if c then out[#out + 1] = c end
    end
    return table.concat(out)
end

---------------------------------------------------------------------
-- ТЭГИ: [BDAY7], [BP] и т.п. Хранятся отдельно, учатся на твоих правках. HW/FT/PT/NY обрабатывает основной разбор.
-- Русская запись берётся из латинского тэга сама (бдей7 -> [BDAY7]), отдельно хранить её не нужно.
-- Для встроенных тэгов русская запись тоже работает: хв26 -> [HW26], нг26 -> [NY26], фт5 -> [FT5], пт5 -> [PT5].
---------------------------------------------------------------------
TAGS = {}
TAGBUILTIN = { hw = true, ft = true, pt = true, ny = true }

function tagsSave()
    pcall(function()
        local f = io.open(DIR .. 'radio24_tags.txt', 'wb')
        if not f then return end
        for k in pairs(TAGS) do f:write('tag\t', k, '\n') end
        f:close()
    end)
end

function tagsAdd(name)
    name = lo(trim(name or '')):gsub('[^%a%d]', '')
    local nb, nn = name:match('^(%a+)(%d*)$')
    if not nb or #nb < 2 or #nb > 10 or #nn > 4 then return false, T('Тэг: 2-10 латинских букв и, если нужно, цифры (BP5, NY22).') end
    if TAGBUILTIN[nb] and nn == '' then return false, T('Этот тэг уже обрабатывается основным разбором.') end
    if TAGS[name] then return false, T('Такой тэг уже есть.') end
    TAGS[name] = true
    tagsSave()
    return true, T('Тэг добавлен: ') .. up(name)
end

function tagsDel(name)
    if TAGS[name] then TAGS[name] = nil; tagsSave() end
end

-- учимся на тексте: [XXX] и [XXX12] в твоём итоговом варианте - это тэги
function tagsLearn(text)
    local changed = false
    for base in (text or ''):gmatch('%[(%a+)%-?%d*%]') do
        base = lo(base)
        if #base >= 2 and #base <= 10 and not TAGBUILTIN[base] and not TAGS[base] then
            TAGS[base] = true
            changed = true
        end
    end
    if changed then tagsSave() end
    return changed
end

function tagsLoad()
    local had = false
    pcall(function()
        local f = io.open(DIR .. 'radio24_tags.txt', 'rb')
        if not f then return end
        had = true
        for line in f:lines() do
            local k = line:match('^tag\t(%a[%a%d]*)')
            if k then TAGS[lo(k)] = true end
        end
        f:close()
    end)
    if not had then TAGS.bday = true; TAGS.bp = true end
    pcall(function()                                  -- заодно учим тэги из итоговых вариантов памяти
        for _, e in pairs(MEM) do tagsLearn(e.final) end
    end)
    tagsSave()
end

-- Явные русские записи встроенных тэгов, которые скелет не даёт сам (нг: скелет "ng", а у NY он "n").
-- Остальные встроенные (хв -> HW, фт -> FT, пт -> PT) находятся по скелету.
local RU_ALIAS = {}
for ru, en in pairs({ ['нг'] = 'ny', ['хв'] = 'hw' }) do RU_ALIAS[T(ru)] = en end

-- Скелеты тэгов считаются по буквенной части (bp5 -> bp), поэтому тэги с цифрами (BP5, NY24) тоже понимаются
-- по-русски (бп5), а любой новый английский тэг сразу получает русскую запись без отдельного хранения.
local TSK = {}
local function tagSk(b)
    local c = TSK[b]
    if not c then
        local sk, v = skelOf(b)
        local _, ny = b:gsub('y', '')
        c = { sk = sk, v = v, y = math.min(ny, 2), vs = vowSig(b) }
        TSK[b] = c
    end
    return c
end

local function tagBases()
    local set = {}
    for t in pairs(TAGS) do
        local b = t:match('^(%a+)')
        if b then set[b] = true end
    end
    return set
end

-- Выбор тэга из набора латинских основ по скелету. Защиты: скелет >= 2, число гласных близко (y даёт запас:
-- бдей = BDAY), при скелете от 5 символов прощается одна опечатка (первая согласная обязана совпасть),
-- при ничьей между разными тэгами не трогаем.
local function ruTagPick(set, sk, sig)
    local best, bd, amb
    for b in pairs(set) do
        local t = tagSk(b)
        if #t.sk >= 2 then
            local tol = (#t.sk >= 5) and 1 or 0
            local d = strDist(sk, t.sk, tol)
            local vt = math.max(1, math.ceil(#t.vs / 2) - 1) + t.y     -- опечатки в гласных: достаточно большинства
            if d <= tol and (d == 0 or sk:sub(1, 1) == t.sk:sub(1, 1)) and strDist(sig, t.vs, vt) <= vt then
                if not bd or d < bd then best, bd, amb = b, d, false
                elseif d == bd and b ~= best then amb = true end
            end
        end
    end
    if best and not amb then return best end
    return nil, amb
end

-- Русская запись тэга: кириллица + цифры ("бдей7", "[бп]", "хв26", "нг26") -> латинский тэг с тем же скелетом.
-- Нужны скобки или цифры (иначе обычное слово "бп" или "пт" превратилось бы в тэг).
-- Сначала ищем среди своих тэгов, затем среди встроенных (HW/FT/PT/NY).
function tagBaseRu(c, tk)
    local base, num = c:match('^([\192-\255\168\184]+)%-?(%d*)$')
    if not base or #base < 2 or #base > 8 then return nil end
    local br = tk and (tk.pre:find('[', 1, true) or tk.post:find(']', 1, true))
    if not (br or num ~= '') then return nil end
    if RU_ALIAS[base] then return RU_ALIAS[base] end
    local sk = skelOf(base)
    if #sk < 2 then return nil end
    local sig = vowSig(base)
    local best, amb = ruTagPick(tagBases(), sk, sig)
    if best then return best end
    if amb then return nil end
    return (ruTagPick(TAGBUILTIN, sk, sig))
end

-- Основа тэга, если токен похож на известный тэг (опечатки в 1 букву прощаются). Нужны скобки или цифры.
function tagBase(c, tk)
    if c:find('[\192-\255\168\184]') then return tagBaseRu(c, tk) end
    local base, num = c:match('^(%a+)%-?(%d*)$')
    if not base then return nil end
    if num ~= '' and TAGS[base .. num] then return base end        -- точный тэг с цифрами (BP5, NY22)
    if TAGBUILTIN[base] then return nil end
    local br = tk and (tk.pre:find('[', 1, true) or tk.post:find(']', 1, true))
    if not (br or num ~= '') then return nil end
    local set = tagBases()
    if set[base] then return base end                               -- известная основа с новым номером (BP7)
    if #base >= 3 then
        local best, bd
        for tb in pairs(set) do
            if #tb >= 3 then
                local d = strDist(base, tb, 1)
                if d <= 1 and (not bd or d < bd or (d == bd and tb < best)) then best, bd = tb, d end
            end
        end
        return best
    end
    return nil
end

-- оформляет токен как тэг: [BDAY7]
function tagFix(tk, c)
    local base = tagBase(c, tk)
    if not base then return false end
    local num = c:match('(%d+)$') or ''
    tk.core = up(base) .. num
    if not tk.pre:find('[', 1, true) then tk.pre = tk.pre .. '[' end
    if not tk.post:find(']', 1, true) then tk.post = ']' .. tk.post end
    return true
end

---------------------------------------------------------------------
-- НАЗВАНИЯ С ОПЕЧАТКАМИ: слово (или слова подряд) в объявлении похоже на название из списка -> заменяем на название,
-- а кавычки и префикс категории потом ставит обычный namesApply.
---------------------------------------------------------------------
function namesFuzzyLat(s)
    local fixed = {}
    if next(NAMES) == nil then return s, fixed end
    for k, e in pairs(NAMES) do
        if e.on and #k >= 5 and not DICT[k] then
            local kw = {}
            for w in k:gmatch('%S+') do kw[#kw + 1] = w end
            local nw = #kw
            local words = {}
            for a, w, b in s:gmatch('()([%w\192-\255\168\184]+)()') do
                words[#words + 1] = { a = a, b = b - 1, w = lo(w) }
            end
            local tol = (#k >= 10) and 2 or 1
            for i = 1, #words - nw + 1 do
                local okSeq, parts = true, {}
                for j = 0, nw - 1 do
                    local wj = words[i + j]
                    parts[#parts + 1] = wj.w
                    if j > 0 then
                        local gap = s:sub(words[i + j - 1].b + 1, wj.a - 1)
                        if not gap:match('^[%s%-]+$') then okSeq = false; break end
                    end
                end
                if okSeq then
                    local cand = table.concat(parts, ' ')
                    if cand ~= k and not NAMES[cand] and cand:sub(1, 1) == k:sub(1, 1) and not cand:find('%d')
                        and not (nw == 1 and (DICT[cand] or OPS[cand] or STOPW[cand]))
                        and strDist(cand, k, tol) <= tol then
                        local a1, b1 = words[i].a, words[i + nw - 1].b
                        local _, q = s:sub(1, a1 - 1):gsub('"', '')
                        local pc = a1 > 1 and s:sub(a1 - 1, a1 - 1) or ''
                        if q % 2 == 0 and pc ~= '"' then
                            s = s:sub(1, a1 - 1) .. k .. s:sub(b1 + 1)
                            fixed[#fixed + 1] = cand .. ' -> ' .. k
                            break
                        end
                    end
                end
            end
        end
    end
    return s, fixed
end

---------------------------------------------------------------------
-- РУССКАЯ ЗАПИСЬ АНГЛИЙСКИХ НАЗВАНИЙ: "шкода актавия" -> Skoda Octavia (название должно быть в списке "Названия").
-- Русские варианты не хранятся: скелет считается из английского названия, поэтому новое английское название
-- сразу понимается и по-русски. Защиты от случайных совпадений:
--   * в русской записи должна быть кириллица; скелет не короче 4 символов (цифры тоже считаются и должны совпасть);
--     короткие названия (скелет 2-3 символа: Toyota, Ferrari) - только одним словом от 5 букв, без опечаток, гласные точь-в-точь;
--   * Cyber... совпадает и с кибер..., и с сайбер...; буква y в названии даёт запас на гласные (зефир = Zephyr);
--   * число гласных близко к английскому, длина слова сопоставима с названием;
--   * при опечатке (нет/лишняя согласная) допускается 1-2 правки, и первая согласная должна совпасть;
--   * выигрывает ближайшее название, при ничьей между разными названиями не трогаем;
--   * не трогаем служебные слова (в, на, куплю...), слова словаря и текст внутри чужих кавычек.
---------------------------------------------------------------------
-- Кэш скелетов названий. Ключ включает само название, поэтому переименованное или заново добавленное
-- под тем же ключом название пересчитывается, а не залипает со старым скелетом.
local NSK = {}
local function nameSk(k, e)
    local key = k .. '\0' .. tostring(e.name)
    local c = NSK[key]
    if c == nil then
        c = false
        if e.name and e.name:find('%a') then
            local sk, v = skelOf(e.name)
            if #sk >= 2 then
                local _, ny = lo(e.name):gsub('y', '')
                c = { sk = sk, v = v, len = #(e.name:gsub('[%s%-]', '')), short = (#sk < 4), vs = vowSig(e.name), y = math.min(ny, 2),
                      softc = (lo(e.name):find('^c[eiy]') ~= nil) }
            end
        end
        NSK[key] = c
    end
    return c
end

-- Согласные (скелет) только запускают проверку, дальше названию нужно совпасть ещё и по гласным:
-- рисунок гласных русского слова сравнивается с рисунком английского названия (шкода октавия: о-а-о-а-и-я = Skoda Octavia).
-- Допуск по гласным (опечатки в гласных): у короткого названия его нет, у остальных скрипт срабатывает, пока совпадает
-- большинство гласных (до ceil(гласных/2)-1 правок: 3-4 гласных = 1, 5-6 = 2, 7-8 = 3), плюс по одной на букву y.
-- Одни согласные (шкдктв) принимаются только при скелете от 5 символов и когда гласных в слове нет совсем.
-- Если два разных названия подходят одинаково хорошо (в списке дубль написания), слово не трогаем.
local function ruMatch(csk, cv, clen, single, csig)
    local best, bs, amb = nil, 999, false
    for k, e in pairs(NAMES) do
        if e.on then
            local nm = nameSk(k, e)
            -- короткие названия (Toyota, Ferrari, Wasabi) - только одним словом, без опечаток, с тем же рисунком гласных
            if nm and (single or not nm.short) and math.abs(#csk - #nm.sk) <= 2 then
                local tol = (#nm.sk <= 4) and 0 or ((#nm.sk <= 8) and 1 or 2)
                local d = strDist(csk, nm.sk, tol)
                if d <= tol and digitsOf(csk) == digitsOf(nm.sk) then
                    local c1, n1 = csk:sub(1, 1), nm.sk:sub(1, 1)
                    local first = (c1 == n1) or (nm.softc and c1 == 'k' and n1 == 's')   -- Cyber... = кибер... и сайбер...
                    local noVow = (csig == '' and #csk >= 5 and nm.v >= 1 and not nm.short)
                    local vtol = nm.short and 0 or (math.max(0, math.ceil(nm.v / 2) - 1) + nm.y)
                    local vd = (noVow or nm.short) and 0 or strDist(csig, nm.vs, vtol)
                    if (d == 0 or first) and vd <= vtol
                        and clen >= (noVow and #nm.sk or nm.len * 0.5) and clen <= nm.len * 1.8
                        and (not nm.short or (clen >= 5 and #csig == #nm.vs and csig:sub(1, -2) == nm.vs:sub(1, -2))) then
                        local score = d * 10 + vd
                        if score < bs then best, bs, amb = k, score, false
                        elseif score == bs and k ~= best then amb = true end
                    end
                end
            end
        end
    end
    if best and not amb then return best end
    return nil
end

function namesRu(s)
    local fixed = {}
    if next(NAMES) == nil then return s, fixed end
    local words = {}
    for a, w, b in s:gmatch('()([%w\192-\255\168\184]+)()') do
        words[#words + 1] = { a = a, b = b - 1, w = lo(w) }
    end
    local reps, i = {}, 1
    while i <= #words do
        local took = false
        for L = math.min(4, #words - i + 1), 1, -1 do
            local okSeq, hasCy, bad, parts = true, false, false, {}
            for j = 0, L - 1 do
                local wj = words[i + j]
                parts[#parts + 1] = wj.w
                if wj.w:find('[\192-\255\168\184]') then hasCy = true end
                if OPS[wj.w] or STOPW[wj.w] then bad = true end
                if j > 0 then
                    local gap = s:sub(words[i + j - 1].b + 1, wj.a - 1)
                    if not gap:match('^[%s%-]+$') then okSeq = false; break end
                end
            end
            if okSeq and hasCy and not bad then
                local cand = table.concat(parts, ' ')
                if not (L == 1 and DICT[cand]) then
                    local csk, cv = skelOf(cand)
                    if #csk >= 2 then
                        local k = ruMatch(csk, cv, #(cand:gsub(' ', '')), L == 1, vowSig(cand))
                        if k then
                            local a1, b1 = words[i].a, words[i + L - 1].b
                            local _, q = s:sub(1, a1 - 1):gsub('"', '')
                            local pc = a1 > 1 and s:sub(a1 - 1, a1 - 1) or ''
                            local nc = s:sub(b1 + 1, b1 + 1)
                            local free = (q % 2 == 0 and pc ~= '"')
                            local quoted = (q % 2 == 1 and pc == '"' and nc == '"')   -- "шкода октавия" целиком в кавычках
                            if free or quoted then
                                reps[#reps + 1] = { a1, b1, NAMES[k].name }
                                fixed[#fixed + 1] = cand .. ' -> ' .. NAMES[k].name
                                i = i + L
                                took = true
                                break
                            end
                        end
                    end
                end
            end
        end
        if not took then i = i + 1 end
    end
    for n = #reps, 1, -1 do
        local r = reps[n]
        s = s:sub(1, r[1] - 1) .. r[3] .. s:sub(r[2] + 1)
    end
    return s, fixed
end

-- Точка входа для brain.lua: сначала латинские опечатки, затем русская запись
function namesFuzzy(s)
    local s1, f1 = namesFuzzyLat(s)
    local ok, s2, f2 = pcall(namesRu, s1)
    if not ok then return s1, f1 end
    for _, x in ipairs(f2) do f1[#f1 + 1] = x end
    return s2, f1
end

---------------------------------------------------------------------
-- РУССКАЯ ЗАПИСЬ ЛЮБОГО АНГЛИЙСКОГО СЛОВА-ТРИГГЕРА (не только тэги и названия): ruTrig('фулл', 'full') -> true.
-- Русский вариант не хранится, его даёт скелет английского слова: добавил английский триггер - русский уже работает.
-- Те же защиты: скелет совпадает, рисунок гласных близок (у скелета до 3 символов - точно, y даёт запас), слово с кириллицей.
---------------------------------------------------------------------
local TRIGC = {}
function ruTrig(word, en)
    if not word or not word:find('[\192-\255\168\184]') then return false end
    local t = TRIGC[en]
    if not t then
        local sk = skelOf(en)
        local _, ny = lo(en):gsub('y', '')
        t = { sk = sk, vs = vowSig(en), y = math.min(ny, 2) }
        TRIGC[en] = t
    end
    if #t.sk < 2 then return false end
    local sk = skelOf(word)
    if sk ~= t.sk then return false end
    local tol = (#t.sk <= 3) and t.y or (math.max(1, math.ceil(#t.vs / 2) - 1) + t.y)
    return strDist(vowSig(word), t.vs, tol) <= tol
end

-- Русская запись встроенных тэгов HW/NY приводится к латинской, дальше работает обычный разбор brain.lua:
-- хв26 -> hw26, [нг] -> ny. Остальное возвращается без изменений.
function tagRuLatin(c, tk)
    if not c:find('[\192-\255\168\184]') then return c end
    local b = tagBaseRu(c, tk)
    if b == 'hw' or b == 'ny' then return b .. (c:match('(%d+)$') or '') end
    return c
end

---------------------------------------------------------------------
-- ДИАГНОСТИКА: какие названия из списка по-русски понимаются ограниченно или не понимаются совсем.
-- Все остальные включённые названия понимаются по-русски автоматически (скелет считается из английского написания).
-- Возвращает список строк; выведи его в лог/окно, чтобы увидеть исключения.
---------------------------------------------------------------------
function namesRuReport()
    local skipped = {}
    for k, e in pairs(NAMES) do
        if e.on then
            local nm = nameSk(k, e)
            if not nm then
                skipped[#skipped + 1] = tostring(e.name) .. '  [нет русской записи: нет латинских букв или скелет короче 2]'
            elseif nm.short then
                skipped[#skipped + 1] = tostring(e.name) .. '  [короткое: только одним словом от 5 букв, гласные точь-в-точь, без опечаток]'
            end
        end
    end
    table.sort(skipped)
    return skipped
end


---------------------------------------------------------------------
-- МЕСТА: русская запись <-> английская, опечатки (по скелету слова), место - последним перед ценой,
-- места и названия контрактов не попадают в список названий.
---------------------------------------------------------------------
local PLC
local function plcInit()
    if PLC then return PLC end
    PLC = { list = {}, set = {} }
    for _, p in ipairs(PLACES or {}) do
        PLC.set[lo(T((p.canon:gsub('^%S+%s+', ''))))] = true
        for _, f in ipairs(p.forms) do
            local lf = T(f)
            PLC.set[lf] = true
            PLC.set[(lf:gsub('%-', ' '))] = true
            local sk = (skelOf(lf))
            if #sk >= 3 then
                local nw = select(2, lf:gsub('[%w\192-\255\168\184]+', ''))
                PLC.list[#PLC.list + 1] = { sk = sk, canon = T(p.canon), plain = p.plain, nw = nw }
            end
        end
    end
    return PLC
end

function placeIsName(nm)
    local c = plcInit()
    local k = (lo(trim(nm or '')):gsub('%-', ' '))
    if c.set[k] then return true end
    local sk = (skelOf(k))
    if #sk >= 4 then
        for _, e in ipairs(c.list) do if e.sk == sk then return true end end
    end
    return false
end

function placeFuzzy(s)
    local c = plcInit()
    local fixed = {}
    for _, e in ipairs(c.list) do
        local words = {}
        for a, w, b in s:gmatch('()([%w\192-\255\168\184]+)()') do words[#words + 1] = { a = a, b = b - 1, w = w } end
        local tol = (#e.sk >= 9) and 2 or ((#e.sk >= 6) and 1 or 0)
        for i = 1, #words - e.nw + 1 do
            local okSeq, parts = true, {}
            for j = 0, e.nw - 1 do
                local wj = words[i + j]
                parts[#parts + 1] = wj.w
                if j > 0 then
                    local gap = s:sub(words[i + j - 1].b + 1, wj.a - 1)
                    if not gap:match('^[%s%-]+$') then okSeq = false; break end
                end
            end
            if okSeq then
                local a1, b1 = words[i].a, words[i + e.nw - 1].b
                local raw = lo(s:sub(a1, b1))
                local cand = lo(table.concat(parts, ' '))
                local nraw = (raw:gsub('%-', ' '))
                if not c.set[cand] and not c.set[nraw] and not DICT[raw] and not DICT[cand]
                    and not cand:find('%d') and not STOPW[cand] and not OPS[cand] then
                    local csk = (skelOf(cand))
                    local okLen = #csk >= 4 or (#csk == 3 and #cand >= 5)
                    if okLen and csk:sub(1, 1) == e.sk:sub(1, 1) and strDist(csk, e.sk, tol) <= tol then
                        local _, q = s:sub(1, a1 - 1):gsub('"', '')
                        local pc = a1 > 1 and s:sub(a1 - 1, a1 - 1) or ''
                        if q % 2 == 0 and pc ~= '"' then
                            -- всегда английское название; «д.»/«г.» не дублируем, если уже написаны
                            local out = e.canon
                            if not e.plain then
                                local name = (e.canon:gsub('^%S+%s+', ''))
                                local pre = ' ' .. lo(s:sub(1, a1 - 1))
                                if pre:find('[%s%(,%.]' .. T('[дг]') .. '%.%s*$') then
                                    out = raw:find('-', 1, true) and (name:gsub(' ', '-')) or name
                                elseif pre:find('[%s%(,%.]' .. T('[дг]') .. '%s+$')
                                    or pre:find(T('деревн') .. '[^%s]*%s+$') or pre:find(T('город') .. '[^%s]*%s+$') then
                                    out = name
                                end
                            end
                            s = s:sub(1, a1 - 1) .. out .. s:sub(b1 + 1)
                            fixed[#fixed + 1] = raw .. ' -> ' .. out
                            break
                        end
                    end
                end
            end
        end
    end
    return s, fixed
end

-- Место (г. X / д. X вместе с предлогом) переносится в конец описания, перед ценой/бюджетом
local PLC_PREP = { 'рядом с пляжем', 'около пляжа', 'возле пляжа', 'у пляжа', 'на пляже', 'на пляж', 'рядом с', 'около', 'возле', 'близ', 'во', 'в', 'у', 'на' }
function placeToEnd(body)
    local cl = {}
    for _, p in ipairs(PLACES or {}) do cl[#cl + 1] = p.canon end
    for _, x in ipairs(PLACES_MOVE or {}) do cl[#cl + 1] = x end
    for _, pc0 in ipairs(cl) do
        local canon = lo(T(pc0))
        local lb = lo(body)
        local a, b = lb:find(canon, 1, true)
        if a then
            local nc = body:sub(b + 1, b + 1)
            local _, q = body:sub(1, a - 1):gsub('"', '')
            local lc = a > 1 and body:sub(a - 1, a - 1) or ''
            if (nc == '' or not (isLetter(nc) or nc:match('%d'))) and (lc == '' or not (isLetter(lc) or lc:match('%d'))) and q % 2 == 0 then
                local st = a
                local pre = lb:sub(1, a - 1)
                for _, w in ipairs(PLC_PREP) do
                    local tw = T(w)
                    if pre:sub(-(#tw + 1)) == tw .. ' ' and (#pre == #tw + 1 or pre:sub(-(#tw + 2), -(#tw + 2)) == ' ') then
                        st = a - #tw - 1
                        break
                    end
                end
                local seg = body:sub(st, b)
                local before = (body:sub(1, st - 1):gsub('%s+$', ''))
                local after = (body:sub(b + 1):gsub('^[,;%s]+', ''))
                if after ~= '' then
                    body = before .. (before ~= '' and ' ' or '') .. after
                    body = (body:gsub('[,;%s]+$', '')) .. ' ' .. seg
                end
            end
        end
    end
    return body
end

-- название связано с контрактом (название организации или заголовок)?
function namesIsContract(nm)
    if not (CTR and CTR.list and ctrOrgName and ctrSkel) then return false end
    local k, sk = lo(trim(nm or '')), ctrSkel(nm)
    if k == '' then return false end
    for _, c in ipairs(CTR.list) do
        local org = ctrOrgName(c.title)
        if lo(c.title) == k or (org and (lo(org) == k or (#sk >= 3 and ctrSkel(org) == sk))) then return true end
    end
    return false
end

-- убрать из списка названий места и названия контрактов
function namesPurgeBad()
    local n = 0
    for k, e in pairs(NAMES) do
        if placeIsName(e.name) or namesIsContract(e.name) then NAMES[k] = nil; n = n + 1 end
    end
    if n > 0 then namesSave() end
    return n
end

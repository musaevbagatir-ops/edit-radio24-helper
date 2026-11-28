-- radio24/processing/variants/variants_03_order_case.lua: часть 3 из 6 файла processing/variants. порядок объявления (orderClean), регистр (caseFix), "и" между названиями (andFix). Общее окружение модулей, см. radio24_helper.lua
-- ===== ПОРЯДОК ОБЪЯВЛЕНИЯ / РЕГИСТР / "И" МЕЖДУ НАЗВАНИЯМИ (начало) =====
-- orderClean: анализатор порядка [куплю/продам] [класс] [название/номер] [тэги] [место] [Цена/Бюджет].
--   Всё, что стоит после последнего названия/тэга и не похоже на место ("в подарок", "33", "срочно слив") - лишнее;
--   цифры в конце названия т/с, которых нет в списке названий ("Land Cruiser 100" при "Land Cruiser"), - лишние;
--   лишние знаки (! ? * ~), одинокие скобки и кавычки - тоже. Работает тем же путём, что и лишние слова:
--   вариант "Без удаления слов (как выдал ПРО)" остаётся в меню.
-- caseFix: маленький регистр везде, кроме первой буквы, подписей Цена/Бюджет, кавычек, [скобок], аббревиатур и мест (г. X).
-- andFix: а/с "X" а/с "Y" и "X" "Y" -> а/с "X" и "Y".
local ORD_CHAT_STEM, ORD_CHAT_WORD, ORD_REM, CASE_LABEL, CASE_COMMON = {}, {}, {}, {}, {}
for _, w in ipairs({ 'срочн', 'договорим', 'пожалуйст', 'различн' }) do ORD_CHAT_STEM[#ORD_CHAT_STEM + 1] = T(w) end
-- доп. болтовня (только со строчной буквы: заглавное может быть названием места)
local ORD_CHAT_STEM2 = {}
for _, w in ipairs({ 'обсуд', 'быстр', 'недорог', 'дешев', 'дёшев', 'гарантир', 'звоните', 'пишите' }) do ORD_CHAT_STEM2[#ORD_CHAT_STEM2 + 1] = T(w) end
for _, w in ipairs({ 'слив', 'есть', 'еще', 'ещё', 'много', 'разных', 'торг', 'подарок' }) do ORD_CHAT_WORD[T(w)] = true end
for _, w in ipairs({ 'и', 'кс', 'ас', 'ам', 'тс', 'к/с', 'а/с', 'а/м', 'т/с', 'п/п', 'пп' }) do ORD_REM[T(w)] = true end
for _, w in ipairs({ 'цена', 'бюджет', 'ставка' }) do CASE_LABEL[T(w)] = true end
for _, w in ipairs({ 'дом', 'особняк', 'дворец', 'бизнес', 'класса', 'класс', 'эконом', 'комфорт', 'премиум', 'люкс' }) do CASE_COMMON[T(w)] = true end

local function ordWord(t) return lo((t:gsub('^[%p]+', ''):gsub('[%p]+$', ''))) end

-- части текста: q = "название", b = [тэг], w = слово; s/e - позиции в строке
local function ordUnits(s)
    local u, i, n = {}, 1, #s
    while i <= n do
        local c = s:sub(i, i)
        if c:match('%s') then
            i = i + 1
        elseif c == '"' and s:find('"', i + 1, true) then
            local e = s:find('"', i + 1, true)
            u[#u + 1] = { k = 'q', s = i, e = e, t = s:sub(i, e) }
            i = e + 1
        elseif c == '[' and s:find(']', i + 1, true) then
            local e = s:find(']', i + 1, true)
            u[#u + 1] = { k = 'b', s = i, e = e, t = s:sub(i, e) }
            i = e + 1
        else
            local e = i
            while e < n do
                local d = s:sub(e + 1, e + 1)
                if d:match('%s') or d == '"' or d == '[' then break end
                e = e + 1
            end
            u[#u + 1] = { k = 'w', s = i, e = e, t = s:sub(i, e) }
            i = e + 1
        end
    end
    return u
end

local function ordHas(s, w)
    if not w or w == '' then return false end
    local from = 1
    while true do
        local a, b = s:find(w, from, true)
        if not a then return false end
        local p, nx = a > 1 and s:sub(a - 1, a - 1) or '', s:sub(b + 1, b + 1)
        if (p == '' or not isLetter(p)) and (nx == '' or not isLetter(nx)) then return true end
        from = a + 1
    end
end

-- хвост после последнего названия похож на место/нужное окончание? (тогда его не трогаем)
local function ordKeepTail(ts, orig)
    if orig and orig:find('[A-Za-z\192-\223\168]') then return true end      -- латиница/заглавные: название места
    local gd, dd = T('г.'), T('д.')
    for w in ts:gmatch('%S+') do
        if w:sub(1, #gd) == gd or w:sub(1, #dd) == dd then return true end
    end
    for _, k in ipairs({ 'доплат', 'штат', 'любой', 'любого', 'любое', 'номер' }) do
        if ts:find(T(k), 1, true) then return true end
    end
    for _, w in ipairs(LOCLIST or {}) do
        if type(w) == 'string' and ordHas(ts, w) then return true end
    end
    for _, p in ipairs(PLACES or {}) do
        local ok, nm = pcall(function() return lo(T((p.canon:gsub('^%S+%s+', '')))) end)
        if ok and nm and nm ~= '' and ordHas(ts, nm) then return true end
    end
    return false
end

function orderClean(text, ad)
    local removed, cuts = {}, {}
    local low = lo(text)
    local okOp = false
    for _, w in ipairs({ 'продам', 'куплю', 'сдам' }) do
        local tw = T(w)
        if low:sub(1, #tw) == tw then okOp = true end
    end
    if not okOp then return text, removed end
    local lblPos
    for _, lab in ipairs({ '. цена:', '. бюджет:', '. ставка:' }) do
        local p = low:find(T(lab), 1, true)
        if p and (not lblPos or p < lblPos) then lblPos = p end
    end
    local head, tail = text, ''
    if lblPos then head, tail = text:sub(1, lblPos - 1), text:sub(lblPos) end
    local units = ordUnits(head)
    if #units < 2 then return text, removed end
    local function cut(s, e, why) cuts[#cuts + 1] = { s = s, e = e }; removed[#removed + 1] = why end
    local first = 2
    if low:sub(1, #T('сдам')) == T('сдам') and units[2] and ordWord(units[2].t) == T('в') then first = 4 end
    local catU = units[first]
    local catW = (catU and catU.k == 'w') and ordWord(catU.t) or ''

    -- 1) число в конце названия т/с, которого нет в списке названий: "Toyota Land Cruiser 100" -> "Toyota Land Cruiser"
    local trn = lo(T('транспорт'))
    for _, u in ipairs(units) do
        if u.k == 'q' and #u.t > 4 and u.t:sub(-1) == '"' then
            local inner = u.t:sub(2, -2)
            local base, num = inner:match('^(.-)%s+(%d+)$')
            if base and base ~= '' then
                local eb, ef = NAMES[lo(base)], NAMES[lo(inner)]
                if eb and eb.cat and lo(eb.cat) == trn and not ef then
                    cut(u.s + #base + 1, u.e - 1, num)
                end
            end
        end
    end

    -- 2) хвост после последнего названия/тэга (для а/м, а/с, к/с), если он не похож на место
    local isGoodCat = (catW == T('а/м') or catW == T('а/с') or catW == T('к/с'))
    local la
    for idx, u in ipairs(units) do
        if (u.k == 'q' or u.k == 'b') and idx > first then la = idx end
    end
    if isGoodCat and la and la < #units then
        local orig = trim(head:sub(units[la].e + 1))
        local ts = lo(orig)
        if ts ~= '' and not ts:match('^[%p%s]*$') then
            local ts2 = (ts:gsub('%-', ' '))
            if not (ordKeepTail(ts, orig) or ordKeepTail(ts2, nil)) then
                cut(units[la + 1].s, units[#units].e, orig)
                for k = la + 1, #units do units[k].gone = true end
            end
        end
    end

    -- 3) слова-болтовня внутри текста (срочно, слив, есть еще много различных...)
    local chatCut = false
    for idx, u in ipairs(units) do
        if idx > first and u.k == 'w' and not u.gone then
            local w = ordWord(u.t)
            local bad = ORD_CHAT_WORD[w] == true
            if not bad then
                for _, st in ipairs(ORD_CHAT_STEM) do
                    if w:sub(1, #st) == st then bad = true; break end
                end
            end
            if not bad and not isUpper(u.t:sub(1, 1)) then
                for _, st in ipairs(ORD_CHAT_STEM2) do
                    if w:sub(1, #st) == st then bad = true; break end
                end
            end
            if bad then cut(u.s, u.e, u.t); u.gone = true; chatCut = true end
        end
    end
    do                                                -- 3б) слово повторено подряд ("срочно срочно", "цена цена"): второй экземпляр лишний
        local prevW
        for idx, u in ipairs(units) do
            local w = (u.k == 'w' and not u.gone) and ordWord(u.t) or nil
            if w and idx > first and prevW and w == prevW and #w >= 3 and not w:find('[/%d]') then
                cut(u.s, u.e, u.t); u.gone = true
            else
                prevW = w
            end
        end
    end
    if chatCut then                                   -- после болтовни остался хвост "кс и ас": убираем
        local idx = #units
        while idx > first do
            local u = units[idx]
            if u.gone then
                idx = idx - 1
            elseif u.k == 'w' and ORD_REM[ordWord(u.t)] then
                cut(u.s, u.e, u.t); u.gone = true; idx = idx - 1
            else
                break
            end
        end
    end

    -- 4) лишние знаки: ! ? * ~ ^, одинокие скобки и кавычка
    do
        local inQ, stP, stB, lonely = false, {}, {}, nil
        local _, nq = head:gsub('"', '')
        for i = 1, #head do
            local c = head:sub(i, i)
            if c == '"' then
                inQ = not inQ
                if nq % 2 == 1 and not lonely then
                    local p, n2 = head:sub(i - 1, i - 1), head:sub(i + 1, i + 1)
                    if (p == '' or p:match('%s')) and (n2 == '' or n2:match('%s')) then lonely = i end
                end
            elseif not inQ then
                if c:match('[!%?%*~%^]') then
                    cut(i, i, c)
                elseif c == '(' then
                    stP[#stP + 1] = i
                elseif c == ')' then
                    if #stP > 0 then stP[#stP] = nil else cut(i, i, c) end
                elseif c == '[' then
                    stB[#stB + 1] = i
                elseif c == ']' then
                    if #stB > 0 then stB[#stB] = nil else cut(i, i, c) end
                end
            end
        end
        for _, p in ipairs(stP) do cut(p, p, '(') end
        for _, p in ipairs(stB) do cut(p, p, '[') end
        if lonely then cut(lonely, lonely, '"') end
    end

    if #cuts == 0 then return text, {} end
    table.sort(cuts, function(a, b) if a.s ~= b.s then return a.s < b.s end return a.e > b.e end)
    local buf, pos = {}, 1
    for _, c in ipairs(cuts) do
        if c.s >= pos then
            buf[#buf + 1] = head:sub(pos, c.s - 1)
            pos = c.e + 1
        elseif c.e >= pos then
            pos = c.e + 1
        end
    end
    buf[#buf + 1] = head:sub(pos)
    local nh = table.concat(buf)
    nh = nh:gsub('[%s,;%.]+$', '')
    local res = strayTidy(nh .. tail)
    if #res < 8 then return text, {} end
    return res, removed
end

local CASE_PLACE
local function casePlaceWords()
    if CASE_PLACE then return CASE_PLACE end
    CASE_PLACE = {}
    pcall(function()
        for _, p in ipairs(PLACES or {}) do
            if not p.plain then
                for w in lo(T(p.canon)):gmatch('[^%s%-%.]+') do
                    if not DICT[w] and not CASE_COMMON[w] then CASE_PLACE[w] = true end
                end
            end
        end
    end)
    return CASE_PLACE
end

function caseFix(text)
    local s, n = text, #text
    local out, i, inQ, inB, seen, keptEnd = {}, 1, false, 0, false, nil
    local places = casePlaceWords()
    local gdPat, posPat = T('[гдпс]%.%s*$'), T('пос%.%s*$')
    local PREPS = {}
    for _, w in ipairs({ 'в', 'во', 'на', 'у', 'около', 'возле', 'рядом', 'близ', 'из' }) do PREPS[T(w)] = true end
    while i <= n do
        local c = s:sub(i, i)
        if c == '"' then
            inQ = not inQ; out[#out + 1] = c; i = i + 1
        elseif inQ then
            out[#out + 1] = c; i = i + 1
        elseif c == '[' then
            inB = inB + 1; out[#out + 1] = c; i = i + 1
        elseif c == ']' then
            if inB > 0 then inB = inB - 1 end
            out[#out + 1] = c; i = i + 1
        elseif inB > 0 then
            out[#out + 1] = c; i = i + 1
        elseif isLetter(c) then
            local j = i
            while j < n and isLetter(s:sub(j + 1, j + 1)) do j = j + 1 end
            local w = s:sub(i, j)
            local b = w:byte(1)
            local cyr = (b >= 192) or b == 168 or b == 184
            local w2 = w
            if seen and cyr and lo(w:sub(1, 1)) ~= w:sub(1, 1) then
                local lw = lo(w)
                local keep = (#w >= 2 and w == up(w))                         -- аббревиатура (ЦР, ПРО)
                if not keep and CASE_LABEL[lw] and s:sub(j + 1, j + 1) == ':' then keep = true end   -- Цена: / Бюджет:
                if not keep then
                    local back = lo(s:sub(1, i - 1))
                    if back:match(gdPat) or back:match(posPat) or places[lw] then keep = true end   -- г. Эль Кебрадос, д. X, п. X
                    if not keep and keptEnd and keptEnd == i - 2 and s:sub(i - 1, i - 1) == '-' then keep = true end   -- Лос-Сантос
                    if not keep then                                           -- начало предложения: ". О себе", ". Просьба связаться"
                        local pb = s:sub(1, i - 1):match('(%S)%s*$')
                        if pb == '.' or pb == '!' or pb == '?' then keep = true end
                    end
                    if not keep and not DICT[lw] and not CASE_COMMON[lw] and not OPS[lw] then   -- "в Вайнвуде", "на Рублёвке"
                        local pw = back:match('(%S+)%s*$')
                        if pw and PREPS[pw] then keep = true end
                    end
                end
                if not keep and not DICT[lw] and not CASE_COMMON[lw] and not OPS[lw] then
                    if keptEnd and s:sub(keptEnd + 1, i - 1):match('^%s+$') then keep = true end   -- вторая часть имени
                    local nxt = s:match('^%s+([^%s%p]+)', j + 1)
                    if not keep and nxt then
                        local nb = nxt:byte(1)
                        local ln = lo(nxt)
                        if nb and (nb >= 192 or nb == 168) and lo(nxt:sub(1, 1)) ~= nxt:sub(1, 1)
                            and not DICT[ln] and not CASE_COMMON[ln] then keep = true end        -- два заглавных подряд: имя
                    end
                end
                if keep then keptEnd = j else w2 = lo(w:sub(1, 1)) .. w:sub(2) end
            end
            seen = true
            out[#out + 1] = w2
            i = j + 1
        else
            out[#out + 1] = c; i = i + 1
        end
    end
    return table.concat(out)
end

function andFix(text)
    local t, AND = text, T('и')
    for _, a in ipairs({ T('а/с'), T('к/с'), T('а/м') }) do
        local ea = (a:gsub('/', '%%/'))
        t = t:gsub('(%S")%s+' .. ea .. '%s+"', '%1 ' .. AND .. ' "')
    end
    t = t:gsub('([^%s"]")%s+("[^%s"])', '%1 ' .. AND .. ' %2')
    return t
end

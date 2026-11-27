-- radio24/variants.lua: варианты объявления: buildVariants, loadAd, таймеры, ответы. Строки оригинала 2599-2676. Общее окружение модулей, см. radio24_helper.lua
-- общие слова, которые встречаются в каждом втором объявлении: статистика отказов по ним - шум, не подсказка
local HINT_STOP = {}
for _, w in ipairs({ 'продам', 'куплю', 'продаю', 'покупаю', 'меняю', 'обменяю', 'сдам', 'цена', 'бюджет', 'договорная',
    'свободный', 'транспорт', 'эконом', 'класса', 'класс', 'классе', 'бизнес', 'опасном', 'районе', 'купон' }) do
    HINT_STOP[T(w)] = true
end

-- ===== ЛИШНИЕ СЛОВА (начало) =====
-- Убираем из готового текста слова, которые хелпер не распознал и оставил:
--  1) дубль подписи: "цена." / "бюджет" прямо перед "Цена:" / "Бюджет:" / "Ставка:"
--  2) слова-паразиты (срочно, пожалуйста...), если они были в исходнике
--  3) слова, выученные на твоих правках (STRAY): ты убрал слово из текста хелпера -> в похожем
--     по контексту объявлении оно уберётся само
-- Вариант "Без удаления слов" всегда остаётся в списке. Команда: /adstray [add|del слово]
STRAY = {}
STRAYLOG = {}                                      -- журнал событий (только на время сессии)
function strayLogAdd(kind, text)
    STRAYLOG[#STRAYLOG + 1] = { ts = os.time(), kind = kind, text = text or '' }
    if #STRAYLOG > 100 then table.remove(STRAYLOG, 1) end
end
STRAY_FILLER, STRAY_KEEP = {}, {}
for _, w in ipairs({ 'срочно', 'пожалуйста', 'плиз', 'плз', 'недорого', 'дешево', 'дёшево', 'выгодно',
    'звоните', 'пишите', 'торопитесь', 'спасибо' }) do STRAY_FILLER[T(w)] = true end
for _, w in ipairs({ 'продам', 'куплю', 'продаю', 'покупаю', 'меняю', 'обменяю', 'сдам', 'ищу', 'сниму',
    'арендую', 'договорная', 'свободный', 'свободная' }) do STRAY_KEEP[T(w)] = true end
STRAY_LW = { T('цена'), T('бюджет'), T('ставка') }

function strayTokens(s)
    local l = lo(stripColors(s or '')):gsub('[^%w\192-\255\168\184]', ' ')
    local list = {}
    for w in l:gmatch('%S+') do
        if not w:find('%d') then list[#list + 1] = w end
    end
    return list
end

-- Контекст лишних слов: слова сравниваются ЦЕЛИКОМ (обрезки до 5 букв нет; старые записи с обрезками тоже работают).
-- Запятая в контексте начинает контекст заново: правило работает, если выполнена любая группа (слова группы - все сразу).
-- Служебные слова (продам/куплю/цена/бюджет, одна буква: а, м) контекстом не считаются.
local STRAY_CTXOPS = { 'продам', 'куплю', 'продаю', 'покупаю', 'меняю', 'обменяю', 'сдам', 'ищу', 'сниму',
    'арендую', 'цена', 'бюджет', 'ставка', 'договорная', 'свободный' }
local STRAY_SKIP = {}
for _, w in ipairs(STRAY_CTXOPS) do STRAY_SKIP[T(w)] = true; STRAY_SKIP[T(w):sub(1, 5)] = true end
local function strayTrivial(st)
    return #st < 2 or (STOPW[st] and true or false) or (STRAY_SKIP[st] and true or false)
end

function strayHave(s)
    local h = {}
    for _, w in ipairs(strayTokens(s)) do h[w] = true; h[w:sub(1, 5)] = true end
    return h
end

-- часть объявления между запятыми/точками с запятой, где стоит слово (запятая начинает контекст заново)
local function strayClauseOf(s, word)
    local first = strayTokens(word)[1]
    if not first then return s end
    for part in (stripColors(s or '') .. ','):gmatch('([^,;]*)[,;]') do
        for _, w in ipairs(strayTokens(part)) do
            if w == first then return part end
        end
    end
    return s
end

function strayCtxList(s, word)
    local ex = {}
    for _, tw in ipairs(strayTokens(word)) do ex[tw] = true; ex[tw:sub(1, 5)] = true end
    local function collect(text)
        local list, seen = {}, {}
        for _, w in ipairs(strayTokens(text)) do
            if not ex[w] and not ex[w:sub(1, 5)] and not seen[w] and not strayTrivial(w) and #list < 8 then
                seen[w] = true
                list[#list + 1] = w
            end
        end
        return list
    end
    local list = collect(strayClauseOf(s, word))
    if #list == 0 then list = collect(s) end       -- в своей части объявления нет нужных слов: берём всё объявление
    return list
end

function strayCtxOk(e, have)
    if #e.ctx == 0 then return true end
    local groups, cur, grouped = {}, {}, false
    for _, st in ipairs(e.ctx) do
        if st == ',' then
            grouped = true
            groups[#groups + 1] = cur
            cur = {}
        else
            cur[#cur + 1] = st
        end
    end
    groups[#groups + 1] = cur
    local function useful(list)
        local u = {}
        for _, st in ipairs(list) do if not strayTrivial(st) then u[#u + 1] = st end end
        if #u == 0 then return list end            -- в контексте только служебные слова: берём как есть
        return u
    end
    local function got(list)
        local n = 0
        for _, st in ipairs(list) do if have[st] then n = n + 1 end end
        return n
    end
    if not grouped then
        local list = useful(groups[1])
        return got(list) >= math.min(2, #list)
    end
    for _, g in ipairs(groups) do
        if #g > 0 and got(g) == #g then return true end
    end
    return false
end

function straySave()
    pcall(function()
        local f = io.open(DIR .. 'radio24_strays.txt', 'wb')
        if not f then return end
        for w, e in pairs(STRAY) do
            f:write(u8(w), '\t', u8(table.concat(e.ctx, ' ')), '\t', tostring(e.n), '\t', tostring(e.time or 0), '\t',
                e.on == false and '0' or '1', '\n')
        end
        f:close()
    end)
end

function strayLoad()
    pcall(function()
        local f = io.open(DIR .. 'radio24_strays.txt', 'rb')
        if not f then return end
        for line in f:lines() do
            local w, c, n, t, on = line:match('^(.-)\t(.-)\t(%d+)\t(%d*)\t?(%d?)$')
            if w and w ~= '' then
                local ctx = {}
                for st in u8:decode(c):gmatch('%S+') do ctx[#ctx + 1] = st end
                local kk = u8:decode(w)
                STRAY[kk] = { ctx = ctx, n = tonumber(n) or 1, time = tonumber(t) or 0, on = on ~= '0', lit = (kk:sub(1, 1) == '=') or nil }
            end
        end
        f:close()
    end)
end

-- добавить/изменить слово вручную (oldWord - прежний ключ при правке). Возвращает ok, сообщение
function strayAdd(word, ctxText, oldWord)
    local keys, seenK, ex, litKeys = {}, {}, {}, {}
    local rawW = trim(word or '')
    local pieces = {}
    if rawW ~= '' and not rawW:find('[%w\192-\255\168\184]') then
        pieces[1] = rawW                                 -- только знаки (запятая, №, !!): одна запись целиком
    else
        for part in rawW:gmatch('[^,;\n]+') do pieces[#pieces + 1] = part end   -- запятая начинает новое слово/фразу
    end
    for _, part in ipairs(pieces) do
        local p = trim(part)
        local forced = p:sub(1, 1) == '='
        if forced then p = trim(p:sub(2)) end
        local hasUp = false
        for ch in p:gmatch('.') do if isUpper(ch) then hasUp = true; break end end
        -- запись с цифрами, знаками или заглавными буквами - буквальная (ищется точно, с учётом регистра)
        if p ~= '' and (forced or p:find('%d') or p:find('[^%w\192-\255\168\184%s%-]') or hasUp) then
            if #p > 30 then return false, T('Запись слишком длинная (до 30 символов).') end
            local key = '=' .. p
            if not seenK[key] then
                seenK[key] = true
                keys[#keys + 1] = key
                litKeys[key] = true
            end
        else
            local toks = strayTokens(p)
            if #toks > 4 then return false, T('Фраза слишком длинная (до 4 слов).') end
            if #toks >= 1 then
                local key = table.concat(toks, ' ')         -- дефис и пробел равнозначны: "лос-сантос" = "лос сантос"
                if #key < 2 then return false, T('Слишком короткое слово.') end
                if #toks == 1 and STRAY_KEEP[key] then return false, T('Это служебное слово, убирать его нельзя: ') .. key end
                if not seenK[key] then
                    seenK[key] = true
                    keys[#keys + 1] = key
                    for _, tw in ipairs(toks) do ex[tw:sub(1, 5)] = true end
                end
            end
        end
    end
    if #keys == 0 then return false, T('Впиши слово или фразу (несколько - через запятую).') end
    if oldWord and #keys > 1 then return false, T('При правке можно оставить только одну запись.') end
    local ctx = {}                                   -- слова целиком; запятая начинает новую группу контекста
    for seg in ((ctxText or '') .. ','):gmatch('([^,;]*)[,;]') do
        local added, seen = false, {}
        for _, cw in ipairs(strayTokens(seg)) do
            if not ex[cw] and not ex[cw:sub(1, 5)] and not seen[cw] and #ctx < 10 then
                seen[cw] = true
                if not added and #ctx > 0 then ctx[#ctx + 1] = ',' end
                ctx[#ctx + 1] = cw
                added = true
            end
        end
    end
    local old = oldWord and STRAY[oldWord] or nil
    if oldWord and oldWord ~= keys[1] then STRAY[oldWord] = nil end
    for _, key in ipairs(keys) do
        local cx = {}
        for i, st in ipairs(ctx) do cx[i] = st end
        STRAY[key] = { ctx = cx, n = old and old.n or 3, time = os.time(), on = (old == nil) or old.on ~= false, lit = litKeys[key] or nil }
        strayLogAdd('manual', key)
    end
    straySave()
    if #keys == 1 then return true, T('Слово сохранено: ') .. keys[1] end
    return true, T('Добавлено записей: ') .. #keys
end

function strayDel(word)
    local w = lo(trim(word or ''))
    if word and STRAY[word] then STRAY[word] = nil; straySave(); return true end
    if STRAY[w] then STRAY[w] = nil; straySave(); return true end
    return false
end

-- убрать слово целиком; не трогаем кавычки, дефисы, слэши и подпись "слово:"
local function strayRemoveWord(text, word)
    local low = lo(text)
    local pat, plain = word, true
    if word:find(' ', 1, true) then pat, plain = (word:gsub(' ', '[%%s%%-]+')), false end
    local out, pos, removed = {}, 1, false
    while true do
        local s, e = low:find(pat, pos, plain)
        if not s then break end
        local prev = s > 1 and text:sub(s - 1, s - 1) or ''
        local nxt = e < #text and text:sub(e + 1, e + 1) or ''
        local ok = (prev == '' or not (isLetter(prev) or prev:match('[%d%-/]')))
            and (nxt == '' or not (isLetter(nxt) or nxt:match('[%d%-/]')))
        if ok then
            local _, q = text:sub(1, s - 1):gsub('"', '')
            if q % 2 == 1 then ok = false end
        end
        if ok and text:sub(e + 1):match('^%s*(.)') == ':' then ok = false end
        if ok then
            out[#out + 1] = text:sub(pos, s - 1)
            removed = true
        else
            out[#out + 1] = text:sub(pos, e)
        end
        pos = e + 1
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out), removed
end

local function strayTidy(t)
    t = t:gsub('%s+', ' ')
    t = t:gsub('%s+([%.,;!%?])', '%1')
    t = t:gsub('([%.,;])%1+', '%1')
    t = t:gsub('([a-z\224-\255])%.([A-Z\192-\223])', '%1. %2')
    return (trim(t))
end

-- буквальная запись (знаки, цифры, заглавные): убираем точное совпадение вне кавычек и вне [скобок]
local function strayRemoveLit(text, lit)
    local out, pos, from, removed = {}, 1, 1, false
    local wc = '[%w\192-\255\168\184]'
    local edgeL, edgeR = lit:sub(1, 1):match(wc), lit:sub(-1):match(wc)
    while true do
        local s, e = text:find(lit, from, true)
        if not s then break end
        local prev = s > 1 and text:sub(s - 1, s - 1) or ''
        local nxt = e < #text and text:sub(e + 1, e + 1) or ''
        local ok = true
        if edgeL and prev ~= '' and prev:match(wc) then ok = false end
        if ok and edgeR and nxt ~= '' and nxt:match(wc) then ok = false end
        if ok and not edgeL and not edgeR and prev:match('%d') and nxt:match('%d') then ok = false end
        if ok then
            local before = text:sub(1, s - 1)
            local _, q = before:gsub('"', '')
            local _, ob = before:gsub('%[', '')
            local _, cb = before:gsub('%]', '')
            if q % 2 == 1 or ob > cb then ok = false end
        end
        if ok then
            out[#out + 1] = text:sub(pos, s - 1) .. ' '
            pos, removed = e + 1, true
            from = e + 1
        else
            from = s + 1
        end
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out), removed
end

-- text - готовый текст, ad - исходник. Возвращает очищенный текст и список убранных слов
function strayClean(text, ad)
    local cur, removed = text, {}
    for _, w in ipairs(STRAY_LW) do
        for _, lab in ipairs(STRAY_LW) do
            local s, e = lo(cur):find(w .. '[%s%.,;]*' .. lab .. ':')
            if s then
                local prev = s > 1 and cur:sub(s - 1, s - 1) or ''
                if prev == '' or not isLetter(prev) then
                    cur = cur:sub(1, s - 1) .. cur:sub(e - #lab)
                    removed[#removed + 1] = w
                end
            end
        end
    end
    local origW = {}
    for _, w in ipairs(strayTokens(ad)) do origW[w] = true end
    local adNorm = ' ' .. table.concat(strayTokens(ad), ' ') .. ' '
    local have = strayHave(ad)
    local function try(w)
        local n, r = strayRemoveWord(cur, w)
        if r then cur = n; removed[#removed + 1] = w end
    end
    for w in pairs(STRAY_FILLER) do if origW[w] then try(w) end end
    for w, e in pairs(STRAY) do
        if e.on ~= false and not e.lit and e.n >= 1 and adNorm:find(' ' .. w .. ' ', 1, true) and strayCtxOk(e, have) then try(w) end
    end
    for w, e in pairs(STRAY) do
        if e.lit and e.on ~= false then
            local n, r = strayRemoveLit(cur, w:sub(2))
            if r then cur = n; removed[#removed + 1] = w end
        end
    end
    if #removed == 0 then return text, {} end
    cur = strayTidy(cur)
    if #cur < 8 then return text, {} end
    return cur, removed
end

local function strayInQuotes(text, w)             -- слово стоит внутри кавычек (название): удалением оно не лечится
    local s = lo(text or ''):find(w, 1, true)
    if not s then return false end
    local _, q = text:sub(1, s - 1):gsub('"', '')
    return q % 2 == 1
end

-- Учимся на правке: слово стояло в тексте хелпера (raw), было в исходнике, а ты его убрал -> запоминаем
-- вместе с контекстом исходника. Ослабления нет: ненужное слово удаляется вручную на вкладке "Лишние слова".
function strayLearn(orig, final, raw)
    if not raw or raw == '' or not final or final == '' then return end
    local fin, finStem = {}, {}
    for _, w in ipairs(strayTokens(final)) do fin[w] = true; finStem[w:sub(1, 4)] = true end
    local origSet = {}
    for _, w in ipairs(strayTokens(orig)) do origSet[w] = true end
    local have = strayHave(orig)
    local rawWords, seen, cand, kept, changed = strayTokens(raw), {}, {}, 0, false
    for _, w in ipairs(rawWords) do
        if fin[w] or finStem[w:sub(1, 4)] then kept = kept + 1 end
        if not seen[w] then
            seen[w] = true
            local e = STRAY[w]
            if fin[w] then
                -- слово оставлено: ничего не меняем (лишнее убираешь сам, правило не ослабляем)
            elseif origSet[w] and #w >= 3 and not STRAY_KEEP[w] and not STRAY_FILLER[w]
                and not finStem[w:sub(1, 4)] and not strayInQuotes(raw, w) then
                cand[#cand + 1] = w
            end
        end
    end
    -- учимся только на небольших правках: убрали 1-2 слова, остальной текст сохранён
    if #cand >= 1 and #cand <= 2 and kept >= 0.7 * #rawWords then
        for _, w in ipairs(cand) do
            local ctx = strayCtxList(orig, w)
            local e = STRAY[w]
            if e then
                e.n = e.n + 1
                e.time = os.time()
                local have2, grouped = {}, false
                for _, st in ipairs(e.ctx) do
                    have2[st] = true
                    if st == ',' then grouped = true end
                end
                if not grouped then                      -- контекст с запятыми собран вручную: не расширяем
                    for _, st in ipairs(ctx) do
                        if not have2[st] then e.ctx[#e.ctx + 1] = st end
                    end
                    while #e.ctx > 10 do table.remove(e.ctx, 1) end
                end
            else
                STRAY[w] = { ctx = ctx, n = 1, time = os.time() }
            end
            changed = true
            strayLogAdd('learn', w)
            say(T('Удаление запомнено: слово "') .. w .. T('" будет убираться в похожих объявлениях.'), 0xFF66FF66)
        end
    end
    if changed then straySave() end
end
-- ===== ЛИШНИЕ СЛОВА (конец) =====

function buildVariants(ad)
    local main, notes, info = fixText(ad)
    if type(info) == 'table' then info.rawMain = main end   -- текст ПРО до удаления слов (для обучения)
    local vars = {}
    local function alt(opts)                          -- вариант с другими настройками; сбой в нём не должен ронять скрипт
        local ok, t = pcall(fixText, ad, opts)
        if ok and type(t) == 'string' and t ~= '' then return t end
        return nil
    end
    local function hasNote(part)
        for _, n in ipairs(notes) do
            if n:find(part, 1, true) then return true end
        end
        return false
    end
    local mem = memGet(ad)
    if mem then vars[#vars + 1] = { label = T('Из памяти'), text = mem, mem = true } end
    local sm = srcMatch(ad)
    if sm and not mem then
        vars[#vars + 1] = { label = T('Как есть (эталон)'), text = (trim(stripColors(ad)):gsub('[%s%.]+$', '')), src = true }
    end
    vars[#vars + 1] = { label = T('По ПРО'), text = main }
    if info.names then                                -- названия из списка взяты в кавычки: даём вариант без них
        local a = alt({ noNames = true })
        if a and a ~= main then vars[#vars + 1] = { label = T('Без кавычек у названий'), text = a } end
    end
    if info.typo then                                 -- слова исправлены как опечатки: даём вариант без исправлений
        local a = alt({ noFuzzy = true })
        if a and a ~= main then vars[#vars + 1] = { label = T('Без исправления опечаток'), text = a } end
    end
    if info.price and not info.torg then
        local a = alt({ dogovor = true })
        if a and a ~= main then vars[#vars + 1] = { label = T('С договорной ценой'), text = a } end
    end
    if info.price and info.torg then
        local a = alt({ forcePrice = true })
        if a and a ~= main then vars[#vars + 1] = { label = T('С указанной ценой'), text = a } end
    end
    if info.op == 'swap' and not main:find(T('доплат'), 1, true) then
        vars[#vars + 1] = { label = T('С доплатой'), text = main .. T(' с доплатой') }
    end
    if hasNote(T('процент не указан')) then           -- купон на т/с: 15% или 25% - даём второй вариант
        local a, n = main:gsub('15%%', '25%%')
        if n == 0 then a, n = main:gsub('25%%', '15%%') end
        if n > 0 then vars[#vars + 1] = { label = T('Другой процент скидки'), text = a } end
    end
    for _, v in ipairs(vars) do                       -- префиксы категорий (а/с, к/с) из настроек
        if not v.mem and not v.src then v.text = catPrefFix(v.text) end
    end
    local ctrNote                                     -- название организации по контракту
    for _, v in ipairs(vars) do
        if not v.mem and not v.src and ctrFixName then
            local ok, t, n = pcall(ctrFixName, v.text, ad)
            if ok and type(t) == 'string' then v.text = t; ctrNote = ctrNote or n end
        end
    end
    if ctrNote then notes[#notes + 1] = ctrNote end
    -- Порядок: память/эталон -> ПРО (названия, тэги, выученные правила внутри fixText) -> префиксы и контракты
    --   -> правки текста (TX, в т.ч. авто-замены) -> лишние слова (STRAY, в т.ч. авто-удаления) последними -> "Чистый ПРО"
    local pos, extra                                  -- ручные правки текста (вкладка "Правки текста")
    for idx, v in ipairs(vars) do
        if not v.mem and not v.src then
            local t, alts, used = TX.apply(v.text, ad)
            v.text = t
            if not pos then
                pos, extra = idx, alts
                for _, u in ipairs(used) do notes[#notes + 1] = u end
            end
        end
    end
    if extra then for k, a in ipairs(extra) do table.insert(vars, pos + k, a) end end
    local rawIdx, rawText, strayWords                 -- лишние слова: убираем и даём вариант без удаления
    for idx, v in ipairs(vars) do
        if not v.mem and not v.src then
            local c, rm = strayClean(v.text, ad)
            if #rm > 0 and c ~= v.text then
                if not rawIdx then rawIdx, rawText, strayWords = idx, v.text, rm end
                v.text = c
            end
        end
    end
    if rawIdx then
        table.insert(vars, rawIdx + 1, { label = T('Без удаления слов (как выдал ПРО)'), text = rawText, keep = true })
        notes[#notes + 1] = T('убрано лишнее слово: ') .. table.concat(strayWords, ', ')
        strayLogAdd('apply', table.concat(strayWords, ', '))
    end
    do                                                -- "Чистый ПРО": разбор без названий, тэгов, выученных правил, правок текста и лишних слов
        local bv = alt({ bare = true })
        if bv then
            vars[#vars + 1] = { label = T('Чистый ПРО (без названий, тэгов, выученных правил, правок и лишних слов)'),
                text = bv, bare = true }
        end
    end
    for _, v in ipairs(vars) do v.text = trim((tostring(v.text or ''):gsub('%s+', ' '))) end   -- один пробел везде
    local seen, res = {}, {}                          -- одинаковые по тексту варианты не показываем (первый остаётся)
    for _, v in ipairs(vars) do
        local key = (trim(v.text or ''):gsub('%s+', ' '):gsub('[%s%.]+$', ''))
        if not seen[key] then
            seen[key] = true
            res[#res + 1] = v
        end
    end
    return res, notes, info
end

function loadAd(ad, author)
    S.author = author or ''
    S.original = trim(ad or '')
    local vars, notes, info = buildVariants(S.original)
    S.variants, S.notes, S.info, S.reject = vars, notes, info, info.reject or {}
    for _, h in ipairs(statHints(S.original)) do
        local w = lo(tostring(h.word or ''))
        if not (HINT_STOP[w] or DICT[w] or #w < 4) then
            table.insert(S.reject, 1, h.reason)
            notes[#notes + 1] = T('выучено: слово "') .. h.word .. T('" обычно ведёт к отказу: ') .. h.reason
        end
    end
    S.blocked = false
    for _, n in ipairs(notes) do
        if n:find(T('ЗАПРЕЩЕНО'), 1, true) then S.blocked = true end
    end
    S.srcHit = (not S.blocked) and srcMatch(S.original) or nil
    if okUi then
        setBuf(srcBuf, S.original)
        setBuf(editBuf, vars[1] and vars[1].text or '')
        setBuf(rejBuf, S.reject[1] or '')
        setBuf(admBuf, S.reject[1] or ADMIN_PRESETS[1])
    end
end

-- Отложенные действия: общая очередь, которую разбирает цикл main(). Отдельные lua_thread на каждый вызов не создаём:
-- спящие потоки в момент выгрузки скрипта ломают очистку в MoonLoader (падение lua51.dll).
LATER_Q = LATER_Q or {}

-- Журнал ошибок: пишется сразу на диск (переживает вылет игры). Файл: config\radio24_errors.txt
function errLog(where, err)
    S.lastErr = tostring(where) .. ': ' .. tostring(err)
    pcall(function()
        local f = io.open(DIR .. 'radio24_errors.txt', 'ab')
        if not f then return end
        f:write(os.date('%d.%m %H:%M:%S '), u8(S.lastErr), ' | screen=', tostring(S.screen), ' stage=', tostring(S.stage), '\n')
        f:close()
    end)
end
function later(ms, fn)
    LATER_Q[#LATER_Q + 1] = { at = os.clock() + (ms or 0) / 1000, fn = fn }
end

function laterPump()
    if #LATER_Q == 0 then return end
    local now, due, rest = os.clock(), {}, {}
    for _, it in ipairs(LATER_Q) do
        if it.at <= now then due[#due + 1] = it else rest[#rest + 1] = it end
    end
    LATER_Q = rest
    for _, it in ipairs(due) do
        local ok, e = pcall(it.fn)
        if not ok then errLog('later', e) end
    end
end

-- если сервер не прислал нужное окно - не висим молча
function armTimeout()
    local token = S.stageAt
    later(9000, function()
        if S.stage and S.stageAt == token then
            S.stage = nil
            setScreen('wait', T('Сервер не ответил на действие. Открой список заново и проверь объявление.'))
            say(T('Сервер не прислал нужное окно, действие остановлено. Проверь объявление в списке.'), 0xFFFF6666)
        end
    end)
end

function respond(id, button, item, input)
    sampSendDialogResponse(id, button, item, input or '')
end

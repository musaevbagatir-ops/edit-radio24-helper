-- radio24/processing/variants/variants_01_stray_data.lua: часть 1 из 6 файла processing/variants. лишние слова, часть 1: таблицы, контекст, сохранение/загрузка, ручное добавление. Общее окружение модулей, см. radio24_helper.lua
-- общие слова, которые встречаются в каждом втором объявлении: статистика отказов по ним - шум, не подсказка
HINT_STOP = {}
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
        local f = io.open(cfgPath('radio24_strays.txt'), 'wb')
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
        local f = io.open(cfgPath('radio24_strays.txt'), 'rb')
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


-- radio24/learning/learn/learn_01_rules_stats.lua: часть 1 из 2 файла learning/learn. умная память и статистика. Строки оригинала 787-1187. Общее окружение модулей, см. radio24_helper.lua
-- Все части работают в общем окружении модулей, порядок частей задан в ORDER загрузчика radio24_helper.lua.
---------------------------------------------------------------------
-- УМНАЯ ПАМЯТЬ
--   LEARN: выученные замены "слово/фраза -> как правильно" (из твоих правок)
--   STAT:  по каким словам ты обычно удаляешь объявления и с какой причиной
---------------------------------------------------------------------
LEARN, LEARN_MIN, LEARN_MIN_DEL = {}, 2, 3
STAT, STATCAP = {}, 4000

STOPW = set { 'в', 'во', 'на', 'и', 'а', 'у', 'с', 'со', 'по', 'за', 'к', 'о', 'от', 'до', 'из', 'для',
    'то', 'но', 'или', 'не', 'же', 'ли', 'бы', 'это', 'мне', 'мой', 'моя' }

function flat(s) return (tostring(s):gsub('[\t\r\n]', ' ')) end

-- ЖУРНАЛ последних добавлений: правила (авто / запомнено / своё / замена) и новые названия
LEARNLOG, LEARNLOG_CAP = {}, 500

function learnLogSave()
    pcall(function()
        local f = io.open(cfgPath('radio24_learnlog.txt'), 'wb')
        if not f then return end
        for _, l in ipairs(LEARNLOG) do
            f:write(tostring(l.ts), '\t', u8(flat(l.kind)), '\t', u8(flat(l.key)), '\t', u8(flat(l.val)), '\t', u8(flat(l.ad or '')), '\n')
        end
        f:close()
    end)
end

function learnLogLoad()
    pcall(function()
        local f = io.open(cfgPath('radio24_learnlog.txt'), 'rb')
        if not f then return end
        LEARNLOG = {}
        for line in f:lines() do
            local ts, kind, key, val, ad = line:match('^(%d+)\t(.-)\t(.-)\t(.-)\t(.*)$')
            if ts then
                LEARNLOG[#LEARNLOG + 1] = { ts = tonumber(ts), kind = u8:decode(kind), key = u8:decode(key),
                    val = u8:decode(val), ad = u8:decode(ad) }
            end
        end
        f:close()
    end)
end

function learnLogAdd(kind, key, val, ad)
    LEARNLOG[#LEARNLOG + 1] = { ts = os.time(), kind = kind, key = key or '', val = val or '', ad = ad or '' }
    if #LEARNLOG > LEARNLOG_CAP then table.remove(LEARNLOG, 1) end
    learnLogSave()
end

function learnNeed(e) return e.val == '' and LEARN_MIN_DEL or LEARN_MIN end

-- КОНТЕКСТ ПРАВИЛА. Составной ключ: "фраза|слово1,слово2".
-- Правило с контекстом срабатывает только в объявлении, где есть хотя бы одно слово контекста
-- (сравнение по первым 5 буквам); правило без контекста действует везде (как раньше).
LCTX, CTXHAVE, CTXSTEM = {}, {}, 5      -- LCTX: фраза -> { составные ключи }
function ctxSplit(ck)                  -- "фраза" | "фраза|контекст" | "фраза|контекст|стоп-слова"
    local p, c, ng = ck:match('^(.-)|(.-)|(.*)$')
    if p then return p, c, ng end
    p, c = ck:match('^(.-)|(.*)$')
    if p then return p, c, '' end
    return ck, '', ''
end
function ctxList(c)
    local t = {}
    for w in c:gmatch('[^,]+') do t[#t + 1] = w end
    return t
end
function ctxStem(w) return lo(w) end        -- слово контекста сравнивается целиком (ограничение в 5 букв убрано)
function ctxReg(ck)
    local p, c, ng = ctxSplit(ck)
    if c == '' and ng == '' then return end
    local l = LCTX[p]
    if not l then l = {}; LCTX[p] = l end
    for _, x in ipairs(l) do if x == ck then return end end
    l[#l + 1] = ck
end
function ctxHit(c, have)               -- сколько слов контекста есть в объявлении
    local n = 0
    for _, w in ipairs(ctxList(c)) do if have[ctxStem(w)] then n = n + 1 end end
    return n
end
-- local learnCtxPick, ctxHaveSet               -- определены ниже (нужен wordsOf)
function ctxParse(text, cap)           -- "слова через пробел/запятую" -> "слово1,слово2" (нижний регистр)
    local cw, seen = {}, {}
    for w in (text or ''):gmatch('[^%s,|]+') do
        local core = lo((w:gsub('^%p+', ''):gsub('%p+$', '')))
        if core ~= '' and not seen[core] and #cw < (cap or 6) then seen[core] = true; cw[#cw + 1] = core end
    end
    return table.concat(cw, ',')
end

function learnedGet(key)
    do return nil end   -- выученные замены переехали в "Правки текста" / "Лишние слова" (см. learnMigrate в auto.lua)
    local e, ck = learnCtxPick(key)
    if e and e.n >= learnNeed(e) then
        local _, c, ng = ctxSplit(ck)
        local where = (c ~= '') and (T('контекст: ') .. (c:gsub(',', ', '))) or T('везде')
        if ng ~= '' then where = where .. T('; не при: ') .. (ng:gsub(',', ', ')) end
        if e.ad and e.ad ~= '' then where = where .. T('; из: "') .. e.ad:sub(1, 70) .. '"' end
        return { val = e.val, note = T('выучено: ') .. key .. ' -> ' .. (e.val ~= '' and e.val or T('(убрать)')) .. ' [' .. where .. ']' }
    end
    return nil
end

-- слова: raw - как написано (без знаков в конце), norm - нижний регистр без знаков по краям
function wordsOf(s)
    local raw, nrm = {}, {}
    for w in stripColors(s):gmatch('%S+') do
        local core = w:gsub('^%p+', ''):gsub('%p+$', '')
        if core ~= '' then
            raw[#raw + 1] = (w:gsub('[%.,;:!%?]+$', ''))
            nrm[#nrm + 1] = lo(core)
        end
    end
    return raw, nrm
end

-- общая подпоследовательность слов (пары индексов)
function lcsPairs(a, b)
    local n, m = #a, #b
    local L = {}
    for i = 0, n do
        L[i] = {}
        for j = 0, m do L[i][j] = 0 end
    end
    for i = n - 1, 0, -1 do
        for j = m - 1, 0, -1 do
            if a[i + 1] == b[j + 1] then
                L[i][j] = L[i + 1][j + 1] + 1
            else
                L[i][j] = math.max(L[i + 1][j], L[i][j + 1])
            end
        end
    end
    local i, j, res = 0, 0, {}
    while i < n and j < m do
        if a[i + 1] == b[j + 1] then
            res[#res + 1] = { i + 1, j + 1 }
            i, j = i + 1, j + 1
        elseif L[i + 1][j] >= L[i][j + 1] then
            i = i + 1
        else
            j = j + 1
        end
    end
    return res
end

function skipWord(w)
    return w:find('%d') ~= nil or w:find('%$', 1, false) ~= nil or OPS[w] or DROP[w] or TORG[w] or DOGOVOR[w]
        or SVOBODN[w] or w == T('цена') or w == T('бюджет') or w == T('договорная') or w == T('свободный')
end

ctxHaveSet = function(src)
    local st = {}
    local _, nrm = wordsOf(src or '')
    for _, w in ipairs(nrm) do
        st[ctxStem(w)] = true
        for p in w:gmatch('[%w\192-\255\168\184]+') do st[ctxStem(p)] = true end   -- части слова: "26.бюджет", "ft/pt", "эконом-класса"
    end
    return st
end

-- Какое правило для фразы подходит этому объявлению: сначала с контекстом (больше совпадений - лучше), затем общее
learnCtxPick = function(key)
    local best, bck, bs, bn = nil, nil, 0, 0
    for _, ck in ipairs(LCTX[key] or {}) do
        local e = LEARN[ck]
        if e and e.n >= learnNeed(e) then
            local _, c, ng = ctxSplit(ck)
            local ok, sc = (ng == '' or ctxHit(ng, CTXHAVE) == 0), 0.5     -- стоп-слово в объявлении = правило не действует
            if ok and c ~= '' then sc = ctxHit(c, CTXHAVE); ok = sc > 0 end
            if ok and (sc > bs or (sc == bs and e.n > bn)) then best, bck, bs, bn = e, ck, sc, e.n end
        end
    end
    if best then return best, bck end
    return LEARN[key], key
end

-- Слова-контекст из исходного объявления (без ключевой фразы, операций, цен и служебных слов)
function ctxFromSrc(src, keyS)
    local _, nrm = wordsOf(src)
    local out, seen = {}, {}
    for _, w in ipairs(nrm) do
        if #w >= 4 and not keyS[w] and not seen[w] and not STOPW[w] and not skipWord(w) then
            seen[w] = true
            out[#out + 1] = w
            if #out >= 5 then break end
        end
    end
    return table.concat(out, ',')
end

-- Уже есть правило для этой фразы с пересекающимся контекстом - дополняем его, иначе новый вариант
function ctxFind(key, ctx)
    if ctx == '' then return key end
    local have = {}
    for _, w in ipairs(ctxList(ctx)) do have[ctxStem(w)] = true end
    for _, ck in ipairs(LCTX[key] or {}) do
        local _, c = ctxSplit(ck)
        if LEARN[ck] and ctxHit(c, have) > 0 then return ck end
    end
    return key .. '|' .. ctx
end

function learnBump(key, val, strong, man, ad)
    local e = LEARN[key]
    if e and e.man and not man and not strong then return end   -- ручные правила автоматика не трогает
    if ad then ad = flat(ad):sub(1, 200) end
    if not e then
        e = { val = val, n = 1, ad = ad }
        LEARN[key] = e
        learnLogAdd(man and T('своё') or (strong and T('запомнено') or T('авто')), key, val, ad)
    elseif e.val == val then
        e.n = e.n + 1
        if ad and ad ~= '' and (not e.ad or e.ad == '') then e.ad = ad end
    else
        e.n = e.n - 1                       -- противоречие: забываем постепенно
        if e.n <= 0 or strong or man then e.val, e.n = val, 1; e.man = nil; e.ad = ad; learnLogAdd(T('замена'), key, val, ad) end
    end
    if man then e.man = true end
    if strong and e.n < learnNeed(e) then e.n = learnNeed(e) end
    ctxReg(key)
    local phr = ctxSplit(key)
    local n = 1 + select(2, phr:gsub(' ', ''))
    if n > MAXW then MAXW = n end
end

function learnSave()
    pcall(function()
        local f = io.open(cfgPath('radio24_learn.txt'), 'wb')
        if not f then return end
        for k, e in pairs(LEARN) do f:write(u8(k), '\t', u8(flat(e.val)), '\t', tostring(e.n), '\t', e.man and '1' or '0', '\t', u8(flat(e.ad or '')), '\n') end
        f:close()
    end)
end

function learnLoad()
    learnLogLoad()
    pcall(function()
        local f = io.open(cfgPath('radio24_learn.txt'), 'rb')
        if not f then return end
        for line in f:lines() do
            local k, v, n, m, ad = line:match('^(.-)\t(.-)\t(%d+)\t?(%d*)\t?(.*)$')
            if k and k ~= '' then
                k = u8:decode(k)
                LEARN[k] = { val = u8:decode(v), n = tonumber(n) or 1, man = (m == '1') or nil,
                    ad = (ad and ad ~= '') and u8:decode(ad) or nil }
                ctxReg(k)
                local phr = ctxSplit(k)
                local c = 1 + select(2, phr:gsub(' ', ''))
                if c > MAXW then MAXW = c end
            end
        end
        f:close()
    end)
end

-- Учимся на правке: сравниваем исходник и итоговый текст по словам.
-- Участок "слова из исходника -> другие слова" становится правилом (после повторов).
-- strong = true (кнопка "Запомнить"): правило начинает действовать сразу.
function learnFrom(src, final, strong)
    if not cfg.learn then return 0 end
    local nlearn = namesLearn(final)          -- названия в кавычках: аксессуары, транспорт, районы и т.п.
    if true then return 0, nlearn end        -- таблица LEARN больше не пополняется: названия выше учатся, правила подбирает вкладка "Предложения"
    local _, sn = wordsOf(src)
    local fraw, fn = wordsOf(final)
    local inQ, qOpen = {}, false              -- слова итога, стоящие в кавычках: это названия, им место на вкладке "Названия", а не в правилах
    for k = 1, #fraw do
        local _, qn = fraw[k]:gsub('"', '')
        inQ[k] = qOpen or qn > 0
        if qn % 2 == 1 then qOpen = not qOpen end
    end
    if #sn == 0 or #fn == 0 or #sn > 40 or #fn > 40 then return 0 end
    local pr = lcsPairs(sn, fn)
    if #pr < math.max(1, math.floor(#sn * 0.4)) then return 0 end   -- переписано целиком: не учимся
    pr[#pr + 1] = { #sn + 1, #fn + 1 }
    local spans, pi, pj = {}, 1, 1
    for _, p in ipairs(pr) do
        if p[1] > pi or p[2] > pj then spans[#spans + 1] = { pi, p[1] - 1, pj, p[2] - 1 } end
        pi, pj = p[1] + 1, p[2] + 1
    end
    if #spans > 5 then return 0 end
    local learned = 0
    for _, sp in ipairs(spans) do
        local a1, a2, b1, b2 = sp[1], sp[2], sp[3], sp[4]
        local na, nb = a2 - a1 + 1, b2 - b1 + 1
        if na >= 1 and na <= 3 and nb <= 4 then
            local ok, keyT, valT = true, {}, {}
            for k = a1, a2 do
                if skipWord(sn[k]) then ok = false end
                keyT[#keyT + 1] = sn[k]
            end
            for k = b1, b2 do
                if skipWord(fn[k]) or inQ[k] then ok = false end
                valT[#valT + 1] = fraw[k]
            end
            local key, val = table.concat(keyT, ' '), table.concat(valT, ' ')
            if ok and nb > 0 and NAMES[lo((val:gsub('"', '')))] then ok = false end   -- замена = известное название: правило не нужно
            if nb == 0 and (na ~= 1 or #key < 4 or STOPW[key]) then ok = false end   -- слова-удаления: только 1 слово
            if ok and lo(val) == key then ok = false end
            if ok and DICT[key] and DICT[key].val == val then ok = false end         -- это и так знает словарь
            if ok then
                local keyS = {}
                for _, w in ipairs(keyT) do keyS[w] = true end
                local ck = ctxFind(key, ctxFromSrc(src, keyS))
                learnBump(ck, val, strong, nil, src)
                learned = learned + 1
            end
        end
    end
    if learned > 0 then learnSave() end
    return learned, nlearn                    -- правила и названия считаются отдельно
end

-- Объявление отправлено как есть: выученные замены, которые здесь не понадобились, ослабляем
function learnAgainst(src)
    local _, nrm = wordsOf(src)
    local have = ctxHaveSet(src)
    local changed, hit = false, {}
    for i = 1, #nrm do
        for n = 1, math.min(MAXW, #nrm - i + 1) do
            local key = table.concat(nrm, ' ', i, i + n - 1)
            local function weaken(ck)
                local e = LEARN[ck]
                if e and not e.man then
                    hit[#hit + 1] = key
                    e.n = e.n - 1
                    if e.n <= 0 then LEARN[ck] = nil end
                    changed = true
                end
            end
            weaken(key)
            for _, ck in ipairs(LCTX[key] or {}) do          -- правила с контекстом - только если контекст совпал
                local _, c, ng = ctxSplit(ck)
                if (ng == '' or ctxHit(ng, have) == 0) and (c == '' or ctxHit(c, have) > 0) then weaken(ck) end
            end
        end
    end
    if changed then learnSave() end
    return hit
end

-- Своё правило: слово/фраза -> замена (пусто = убрать слово). Действует сразу и приоритетнее словаря
function learnAddManual(keyText, valText, ctxText, negText)
    local parts = {}
    for w in trim(keyText or ''):gmatch('%S+') do
        local core = w:gsub('^%p+', ''):gsub('%p+$', '')
        if core ~= '' then parts[#parts + 1] = lo(core) end
    end
    if #parts == 0 then return false, T('Впиши слово или фразу.') end
    if #parts > 4 then return false, T('Не больше 4 слов в фразе.') end
    local key = table.concat(parts, ' '):gsub('|', '')
    local val = trim(valText or ''):gsub('|', '')
    if lo(val) == key then return false, T('Замена совпадает с исходным словом.') end
    local cx, ng = ctxParse(ctxText, 6), ctxParse(negText, 6)   -- контекст / стоп-слова из объявления
    local ck = key .. ((cx ~= '' or ng ~= '') and ('|' .. cx .. (ng ~= '' and ('|' .. ng) or '')) or '')
    learnBump(ck, val, true, true)
    learnSave()
    return true, T('Правило добавлено: ') .. key .. ' -> ' .. (val ~= '' and val or T('(убрать)'))
        .. (cx ~= '' and (T(' [контекст: ') .. cx:gsub(',', ', ') .. ']') or T(' [везде]'))
        .. (ng ~= '' and (T(' [не при: ') .. ng:gsub(',', ', ') .. ']') or ''), ck
end

-- Статистика отказов: слова объявления -> причины удаления
function statWords(s)
    local _, nrm = wordsOf(s)
    local seen, out = {}, {}
    for _, w in ipairs(nrm) do
        if #w >= 4 and not w:find('%d') and not STOPW[w] and not seen[w] then
            seen[w] = true
            out[#out + 1] = w
            if #out >= 30 then break end
        end
    end
    return out
end

function statSave()
    pcall(function()
        local f = io.open(cfgPath('radio24_stats.txt'), 'wb')
        if not f then return end
        for w, e in pairs(STAT) do
            local any = false
            for r, n in pairs(e.del) do
                f:write(u8(w), '\t', tostring(e.seen), '\t', u8(flat(r)), '\t', tostring(n), '\n')
                any = true
            end
            if not any then f:write(u8(w), '\t', tostring(e.seen), '\t\t0\n') end
        end
        f:close()
    end)
end

function statLoad()
    pcall(function()
        local f = io.open(cfgPath('radio24_stats.txt'), 'rb')
        if not f then return end
        for line in f:lines() do
            local w, seen, r, n = line:match('^(.-)\t(%d+)\t(.-)\t(%d+)$')
            if w and w ~= '' then
                w = u8:decode(w)
                local e = STAT[w]
                if not e then e = { seen = 0, del = {} }; STAT[w] = e end
                e.seen = math.max(e.seen, tonumber(seen) or 0)
                if r ~= '' then e.del[u8:decode(r)] = tonumber(n) or 0 end
            end
        end
        f:close()
    end)
end

function statRecord(orig, action, reason)
    if not cfg.learn or not orig or orig == '' then return end
    local cnt = 0
    for _ in pairs(STAT) do cnt = cnt + 1 end
    for _, w in ipairs(statWords(orig)) do
        local e = STAT[w]
        if not e and cnt < STATCAP then
            e = { seen = 0, del = {} }
            STAT[w] = e
            cnt = cnt + 1
        end
        if e then
            e.seen = e.seen + 1
            if action == 'delete' and reason and reason ~= '' then
                e.del[reason] = (e.del[reason] or 0) + 1
            end
        end
    end
    statSave()
end

-- Подсказки: слово из объявления, по которому ты почти всегда отказываешь с одной причиной
function statHints(orig)
    local res, used = {}, {}
    if not cfg.learn then return res end
    for _, w in ipairs(statWords(orig)) do
        local e = STAT[w]
        if e then
            for reason, n in pairs(e.del) do
                if n >= 2 and n / e.seen >= 0.7 and not used[reason] then
                    used[reason] = true
                    res[#res + 1] = { reason = reason, word = w }
                end
            end
        end
    end
    return res
end


---------------------------------------------------------------------
-- НАЗВАНИЯ В КАВЫЧКАХ: аксессуары, костюмы, транспорт, районы, места и т.п.
-- Источник для fixText (а значит и для всех вариантов в buildVariants).
--   * Название в кавычках в отправленном тексте запоминается само (категория - по слову перед ним:
--     а/с, костюм, а/м, район, п/п ...), либо добавляется/правится вручную на вкладке "Названия".
--   * on = true: название без кавычек в объявлении берётся в кавычки; on = false: кавычки вокруг него убираются.
--   * Названия, которые уже знает словарь (DICT), не дублируются: кавычки у них ставит словарь.
---------------------------------------------------------------------
NAMES, NAMES_CATS = {}, {
    { 'транспорт',   { 'а/м', 'м/ц', 'в/т', 'т/с', 'в/л', 'машин', 'авто', 'мото', 'вертол', 'лодк', 'яхт', 'самол', 'велосип' } },
    { 'аксессуары',  { 'а/с', 'акс', 'аксессуар' } },
    { 'костюмы',     { 'костюм', 'одежд', 'скин', 'маск', 'наряд', 'образ' } },
    { 'районы',      { 'район', 'р-н', 'микрорайон' } },
    { 'места',       { 'п/п', 'бизнес', 'магазин', 'лавк', 'гараж', 'клуб', 'ресторан', 'кафе', 'база', 'место', 'заправк', 'отел' } },
    { 'купоны',      { 'купон', 'бонус' } },
    { 'семьи',       { 'семь', 'клан' } },
    { 'нелегальные организации', { 'организац', 'банд', 'мафи', 'группировк', 'нелегал' } },
    { 'развлечения', { 'развлеч', 'аттракцион', 'мероприят', 'ивент', 'розыгрыш', 'квест' } },
    { 'игрушки',     { 'игруш' } },
    { 'rc-игрушки',  { 'rc-игруш', 'rc игруш', 'рс-игруш', 'рс игруш', 'радиоуправ' } },
}
NAMES_OTHER = 'прочее'

function namesCatList()                 -- все категории в порядке для кнопки выбора (CP1251)
    local l = {}
    for _, c in ipairs(NAMES_CATS) do l[#l + 1] = T(c[1]) end
    l[#l + 1] = T(NAMES_OTHER)
    return l
end

---------------------------------------------------------------------
-- ПРЕФИКС КАТЕГОРИИ: что ставится перед названием в кавычках ("а/с", "к/с", "Семья" ...).
-- Настраивается на вкладке "Названия" для категории целиком; пробел между префиксом и названием ставится сам.
-- Если перед названием в тексте уже стоит префикс или слово категории (костюм, а/с ...), второй раз он не добавляется.
-- Для аксессуаров и костюмов тот же префикс подставляется и в названия из словаря (а/с "Гитара", к/с "Пила").
---------------------------------------------------------------------
CATPREF = {}                              -- категория -> префикс; '' = без префикса (хранятся только изменённые)
CATTAG = {}                               -- префиксы по умолчанию, которые ставит словарь
CATTAG[T('аксессуары')] = T('а/с')
CATTAG[T('костюмы')] = T('к/с')
CATTAG[T('игрушки')] = T('игрушку')
CATTAG[T('rc-игрушки')] = T('RC-игрушку')

function catPrefOf(cat)
    local p = CATPREF[cat]
    if p == nil then p = CATTAG[cat] or '' end
    return p
end

function catPrefSave()
    pcall(function()
        local f = io.open(cfgPath('radio24_catpref.txt'), 'wb')
        if not f then return end
        for c, p in pairs(CATPREF) do f:write(u8(c), '\t', u8(flat(p)), '\n') end
        f:close()
    end)
end

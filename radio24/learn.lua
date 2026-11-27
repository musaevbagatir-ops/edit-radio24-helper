-- radio24/learn.lua: умная память и статистика. Строки оригинала 787-1187. Общее окружение модулей, см. radio24_helper.lua
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
LEARNLOG, LEARNLOG_CAP = {}, 200

function learnLogSave()
    pcall(function()
        local f = io.open(DIR .. 'radio24_learnlog.txt', 'wb')
        if not f then return end
        for _, l in ipairs(LEARNLOG) do
            f:write(tostring(l.ts), '\t', u8(flat(l.kind)), '\t', u8(flat(l.key)), '\t', u8(flat(l.val)), '\t', u8(flat(l.ad or '')), '\n')
        end
        f:close()
    end)
end

function learnLogLoad()
    pcall(function()
        local f = io.open(DIR .. 'radio24_learnlog.txt', 'rb')
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
    if not cfg.learn then return nil end
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
        local f = io.open(DIR .. 'radio24_learn.txt', 'wb')
        if not f then return end
        for k, e in pairs(LEARN) do f:write(u8(k), '\t', u8(flat(e.val)), '\t', tostring(e.n), '\t', e.man and '1' or '0', '\t', u8(flat(e.ad or '')), '\n') end
        f:close()
    end)
end

function learnLoad()
    learnLogLoad()
    pcall(function()
        local f = io.open(DIR .. 'radio24_learn.txt', 'rb')
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
        local f = io.open(DIR .. 'radio24_stats.txt', 'wb')
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
        local f = io.open(DIR .. 'radio24_stats.txt', 'rb')
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
        local f = io.open(DIR .. 'radio24_catpref.txt', 'wb')
        if not f then return end
        for c, p in pairs(CATPREF) do f:write(u8(c), '\t', u8(flat(p)), '\n') end
        f:close()
    end)
end

function catPrefLoad()
    pcall(function()
        local f = io.open(DIR .. 'radio24_catpref.txt', 'rb')
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
        local f = io.open(DIR .. 'radio24_names.txt', 'wb')
        if not f then return end
        for k, e in pairs(NAMES) do
            f:write(u8(e.cat), '\t', u8(flat(e.name)), '\t', tostring(e.n or 1), '\t', e.on and '1' or '0', '\n')
        end
        f:close()
    end)
end

function namesLoad()
    pcall(function()
        local f = io.open(DIR .. 'radio24_names.txt', 'rb')
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

-- Из итогового текста: все "Название" -> в память. Возвращает число новых названий.
function namesLearn(final)
    if not cfg.learn then return 0 end
    local txt, added, changed = stripColors(final or ''), 0, false
    local addedList, dropped = {}, false
    local pos = 1
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
        local f = io.open(DIR .. 'radio24_people.txt', 'wb')
        if not f then return end
        for k, e in pairs(PEOPLE) do
            f:write(u8(k), '\t', u8(flat(e.en)), '\t', e.kind or '', '\t', tostring(e.n or 1), '\n')
        end
        f:close()
    end)
end

function peopleLoad()
    pcall(function()
        local f = io.open(DIR .. 'radio24_people.txt', 'rb')
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
        local f = io.open(DIR .. 'radio24_cats.txt', 'wb')
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
        local f = io.open(DIR .. 'radio24_cats.txt', 'rb')
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

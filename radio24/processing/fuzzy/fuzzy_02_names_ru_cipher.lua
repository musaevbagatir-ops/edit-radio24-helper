-- radio24/processing/fuzzy/fuzzy_02_names_ru_cipher.lua: часть 2 из 2 файла processing/fuzzy. тэги ([BDAY7], [BP]...) и поиск названий с опечатками и в русской записи. Общее окружение модулей, см. radio24_helper.lua
-- Все части работают в общем окружении модулей, порядок частей задан в ORDER загрузчика radio24_helper.lua.
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
                        if not k and ruMatchCy then                -- русское название с опечаткой: только если перед ним слово/префикс той же категории
                            local k2 = ruMatchCy(csk, #(cand:gsub(' ', '')), vowSig(cand), cand)
                            if k2 then
                                local okc, cat = pcall(namesCat, s:sub(1, words[i].a - 1))
                                if okc and cat == NAMES[k2].cat and cat ~= T(NAMES_OTHER) then k = k2 end
                            end
                        end
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
                local skipConj = false                       -- "в г. A и в г. B": первое место не переносим, "и" остаётся между местами
                do
                    local cj = lo(after):match('^' .. T('и') .. '%s+(%S+)')
                    if cj then
                        for _, w in ipairs(PLC_PREP) do
                            if cj == T(w) then skipConj = true end
                        end
                    end
                end
                if after ~= '' and not skipConj then
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

-- журнал: новые тэги, которые запомнил tagsLearn (для общей вкладки журнала и отката)
do
    local oldTagsLearn = tagsLearn
    tagsLearn = function(text)
        local before = {}
        pcall(function() for k in pairs(TAGS) do before[k] = true end end)
        local r1, r2 = oldTagsLearn(text)
        pcall(function()
            for k in pairs(TAGS) do
                if not before[k] then learnLogAdd(T('тег'), '', tostring(k), '') end
            end
        end)
        return r1, r2
    end
end


---------------------------------------------------------------------
-- ШИФР: разделение слитных слов («продамбизнес» -> «продам бизнес»).
-- Слово сводится к шифру из согласных (skelOf: прдм = продам), база слов - из словаря ПРО (KB.VOCW, OPS, DICT).
-- Режем только при уверенном разборе: слово целиком из известных слов, а первое - глагол сделки
-- (допускается шифр без гласных: прдмбизнес), либо все части - точные слова словаря.
-- Названия, тэги, числа, латиница и всё внутри кавычек не трогаются. Сбой слоя не ломает основной разбор (pcall в fixText).
---------------------------------------------------------------------
CIPHER = { C = nil }

local function cphLetters(w) return w ~= '' and not w:find('[^\224-\255\184]') end

function CIPHER.data()
    if CIPHER.C then return CIPHER.C end
    local C = { V = {}, W = {}, OP = {}, SK = {}, OPSK = {} }
    local function put(w, op)
        w = lo(w)
        if not cphLetters(w) or #w > 20 then return end
        if #w < 4 and w ~= T('дом') and w ~= T('ищу') then return end
        C.V[w] = true; C.W[w] = true
        if op then C.OP[w] = true end
    end
    for w in pairs(KB.VOCW or {}) do put(w) end
    for _, w in ipairs({ 'продам', 'куплю', 'обменяю', 'сдам', 'ищу', 'приобрету', 'скупаю', 'дом' }) do
        put(T(w), w ~= 'дом')
    end
    for w in pairs(OPS or {}) do put(w, true) end
    for w in pairs(DICT or {}) do                       -- словарь: только как "остальные части" после глагола сделки
        local l = lo(w)
        if cphLetters(l) and #l >= 4 and #l <= 14 then C.W[l] = true end
    end
    for w in pairs(C.OP) do
        local sk = skelOf(w)
        if #sk >= 3 then C.OPSK[sk] = C.OPSK[sk] == nil and w or false end
    end
    for w in pairs(C.V) do
        if not C.OP[w] then
            local sk = skelOf(w)
            if #sk >= 3 then C.SK[sk] = C.SK[sk] == nil and w or false end
        end
    end
    CIPHER.C = C
    return C
end

function CIPHER.reset() CIPHER.C = nil end

-- Разрез слова s (нижний регистр) на известные слова; nil - уверенного разбора нет
function CIPHER.cut(s)
    local C, n = CIPHER.data(), #s
    for mode = 1, 2 do
        local best, prev, pw = { [0] = 0 }, {}, {}
        for j = 3, n do
            for i = 0, j - 3 do
                if best[i] then
                    local seg = s:sub(i + 1, j)
                    local sc, word
                    if mode == 1 then
                        if i == 0 then
                            if C.OP[seg] then sc, word = #seg * 3, seg
                            else
                                local w = C.OPSK[(skelOf(seg))]
                                if w then sc, word = #seg * 1.5, w end
                            end
                        elseif C.W[seg] then sc, word = #seg * 3, seg
                        elseif #seg >= 4 then
                            local sk = skelOf(seg)
                            local w = #sk >= 3 and C.SK[sk]
                            if w then sc, word = #seg * 1.5, w end
                        end
                    elseif C.V[seg] then
                        sc, word = #seg * 3, seg
                    end
                    if sc and (not best[j] or best[i] + sc > best[j]) then
                        best[j], prev[j], pw[j] = best[i] + sc, i, word
                    end
                end
            end
        end
        if best[n] then
            local pcs, j = {}, n
            while j > 0 do table.insert(pcs, 1, pw[j]); j = prev[j] end
            if #pcs >= 2 and #pcs <= 4 then return pcs end
        end
    end
    return nil
end

local function cphIsName(w)
    if not NAMES then return false end
    for k in pairs(NAMES) do
        if k:find(w, 1, true) or (k:gsub('%s+', '')) == w then return true end
    end
    return false
end

-- Возвращает новый текст и список замен («слитное -> раздельное»)
function CIPHER.split(s)
    local C = CIPHER.data()
    local changes, q = {}, 0
    local out = s:gsub('%S+', function(w)
        local inq = (q % 2 == 1)
        local _, nq = w:gsub('"', '')
        q = q + nq
        if inq or nq > 0 or w:find('[%[%]/%d]') then return nil end
        local pre, core, post = w:match('^(%p*)(.-)(%p*)$')
        local lc = lo(core or '')
        if #lc < 7 or #lc > 30 or not cphLetters(lc) then return nil end
        if C.W[lc] or DICT[lc] or OPS[lc] then return nil end
        if learnedGet and learnedGet(lc) then return nil end
        if cphIsName(lc) then return nil end
        local pcs = CIPHER.cut(lc)
        if not pcs then return nil end
        if isUpper(core:sub(1, 1)) then pcs[1] = up(pcs[1]:sub(1, 1)) .. pcs[1]:sub(2) end
        local res = table.concat(pcs, ' ')
        changes[#changes + 1] = core .. ' -> ' .. res
        return pre .. res .. post
    end)
    return out, changes
end

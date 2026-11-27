-- radio24/textrules.lua: ручные правки текста (TX). Строки оригинала 2459-2598. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- ПРАВКИ ТЕКСТА: ручные правила "найти -> заменить" для готового текста хелпера
--   find: * = любой текст (можно пустой), + = минимум один символ; repl: %1, %2 - что нашли на местах * и +
--   ctx / neg: слова из исходного объявления (есть хотя бы одно / нет ни одного)
--   mode: 'r' - заменять сразу, 'v' - не менять, а предложить вторым вариантом
---------------------------------------------------------------------
TX = { rules = {} }

function TX.compile(find)
    local pat, lit = {}, 0
    for ch in lo(find):gmatch('.') do
        if ch == '*' then pat[#pat + 1] = '().-()'
        elseif ch == '+' then pat[#pat + 1] = '()..-()'
        else
            lit = lit + 1
            pat[#pat + 1] = ch:match('%w') and ch or ('%' .. ch)
        end
    end
    if lit == 0 then return nil end
    return table.concat(pat)
end

function TX.prep(r) r.cpat = TX.compile(r.find) end

function TX.save()
    pcall(function()
        local f = io.open(DIR .. 'radio24_trules.txt', 'wb')
        if not f then return end
        for _, r in ipairs(TX.rules) do
            f:write(u8(flat(r.find)), '\t', u8(flat(r.repl)), '\t', u8(flat(r.ctx)), '\t', u8(flat(r.neg)), '\t',
                r.mode, '\t', r.on and '1' or '0', '\n')
        end
        f:close()
    end)
end

function TX.load()
    pcall(function()
        local f = io.open(DIR .. 'radio24_trules.txt', 'rb')
        if not f then                                    -- первый запуск: одна стартовая правка (можно выключить/удалить)
            local r = { find = '\". (', repl = '\" (', ctx = '', neg = '', mode = 'r', on = true }
            TX.prep(r)
            TX.rules = { r }
            TX.save()
            return
        end
        TX.rules = {}
        for line in f:lines() do
            local a, b, c, d, m, o = line:match('^(.-)\t(.-)\t(.-)\t(.-)\t(%a)\t(%d)')
            if a and a ~= '' then
                local r = { find = u8:decode(a), repl = u8:decode(b), ctx = u8:decode(c), neg = u8:decode(d),
                    mode = m == 'v' and 'v' or 'r', on = o ~= '0' }
                TX.prep(r)
                if r.cpat then TX.rules[#TX.rules + 1] = r end
            end
        end
        f:close()
    end)
end

-- добавить/заменить правило (idx - номер правки при редактировании)
function TX.add(find, repl, ctx, neg, mode, idx)
    find = (find or ''):gsub('[\t\r\n]', ' ')
    if find == '' then return false, T('Впиши, что искать.') end
    local r = { find = find, repl = (repl or ''):gsub('[\t\r\n]', ' '), ctx = ctxParse(ctx, 8), neg = ctxParse(neg, 8),
        mode = mode == 'v' and 'v' or 'r', on = true }
    TX.prep(r)
    if not r.cpat then return false, T('В поле \"Найти\" должен быть хотя бы один обычный символ.') end
    if r.mode == 'r' and lo(r.find) == lo(r.repl) then return false, T('Замена совпадает с найденным.') end
    if idx and TX.rules[idx] then r.on = TX.rules[idx].on; TX.rules[idx] = r else TX.rules[#TX.rules + 1] = r end
    TX.save()
    return true, T('Правка сохранена.')
end

function TX.cond(r, have)
    if r.ctx ~= '' then
        local ok = false
        for _, w in ipairs(ctxList(r.ctx)) do if have[ctxStem(w)] then ok = true end end
        if not ok then return false end
    end
    if r.neg ~= '' then
        for _, w in ipairs(ctxList(r.neg)) do if have[ctxStem(w)] then return false end end
    end
    return true
end

-- Правка работает ТОЛЬКО со своей зоной, чтобы не мешать другим частям хелпера:
--   названия (вкладка "Названия") отвечают за кавычки и текст внутри кавычек -> правка внутри кавычек не применяется
--     (если в "Найти" нет самой кавычки);
--   удаление слов (вкладка "Лишние слова") выполняется ПОСЛЕ правок -> правка видит текст до удаления слов;
--   правка меняет только слова ЦЕЛИКОМ: "кола" не заденет "коллекция". Нужна часть слова - поставь * с нужной стороны.
local function wordCh(ch) return ch ~= '' and (isLetter(ch) or ch:match('%d') ~= nil) end

function TX.once(text, r)
    local low, out, pos, changed = lo(text), {}, 1, false
    local fl = lo(r.find)
    local needL, needR = wordCh(fl:sub(1, 1)), wordCh(fl:sub(-1))
    local quoteSafe = not r.find:find('"', 1, true)
    local guard, from = 0, 1
    local _, nr = r.repl:gsub('"', '')
    local _, nf = r.find:gsub('"', '')
    local qd = nr - nf                                         -- правка добавляет (+) или убирает (-) кавычки
    local pairSafe = nf > 0 and nf % 2 == 0 and nr % 2 == 0    -- в "Найти" и в замене парные кавычки: баланс не ломается
    local _, qcur = text:gsub('"', '')
    while from <= #low and guard < 40 do
        local res = { low:find(r.cpat, from) }
        if not res[1] or res[2] < res[1] then break end
        local s, e = res[1], res[2]
        local ok = true
        if needL and wordCh(s > 1 and text:sub(s - 1, s - 1) or '') then ok = false end
        if ok and needR and wordCh(e < #text and text:sub(e + 1, e + 1) or '') then ok = false end
        if ok and qd ~= 0 and not pairSafe then
            -- правка, меняющая кавычки, работает только чиня баланс: в тексте нечётное число кавычек, после правки - чётное
            local _, qb = text:sub(1, s - 1):gsub('"', '')
            if not ((qcur % 2 == 1) and ((qcur + qd) % 2 == 0)) then ok = false end
            if ok and qd > 0 and qb % 2 == 0 then ok = false end      -- закрывающую кавычку ставим только внутри открытой
        elseif ok and quoteSafe then
            local _, q = text:sub(1, s - 1):gsub('"', '')
            if q % 2 == 1 then ok = false end                 -- внутри кавычек: это зона названий
        end
        if ok then
            guard = guard + 1
            local caps = {}
            for k = 3, #res, 2 do caps[#caps + 1] = text:sub(res[k], res[k + 1] - 1) end
            out[#out + 1] = text:sub(pos, s - 1)
            out[#out + 1] = (r.repl:gsub('%%(%d)', function(d) return caps[tonumber(d)] or '' end))
            pos, changed = e + 1, true
            qcur = qcur + qd
            from = e + 1
        else
            from = s + 1
        end
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out), changed
end

-- Почему правка НЕ применилась к тексту text (nil - в тексте её нет или она выключена). Нужно для полного AdTest
function TX.whyNot(text, ad, r)
    if not r.on or not r.cpat then return nil end
    local low = lo(text)
    local res = { low:find(r.cpat) }
    if not res[1] or res[2] < res[1] then return nil end
    local s, e = res[1], res[2]
    local short = T('правка «') .. r.find .. T('» -> «') .. r.repl .. T('»: ')
    if not TX.cond(r, ctxHaveSet(ad)) then return short .. T('не выполнено условие (контекст / "кроме")') end
    local fl = lo(r.find)
    if wordCh(fl:sub(1, 1)) and wordCh(s > 1 and text:sub(s - 1, s - 1) or '') then
        return short .. T('совпадение внутри слова (правка работает по целым словам, поставь * )')
    end
    if wordCh(fl:sub(-1)) and wordCh(e < #text and text:sub(e + 1, e + 1) or '') then
        return short .. T('совпадение внутри слова (правка работает по целым словам, поставь * )')
    end
    if not r.find:find('"', 1, true) then
        local _, q = text:sub(1, s - 1):gsub('"', '')
        if q % 2 == 1 then return short .. T('текст внутри кавычек - зона названий, правки там не применяются') end
    end
    if r.mode == 'v' then return short .. T('режим "вариант": дана отдельным вариантом, основной текст не меняется') end
    return short .. T('совпадение есть, но не применилось (баланс кавычек или лимит замен)')
end

-- Предупреждение, если правка пересекается с другой частью хелпера (nil - всё чисто)
function TX.conflict(r)
    local f = lo(trim(r.find or ''))
    if f == '' then return nil end
    if STRAY and strayTokens then
        for _, w in ipairs(strayTokens(r.repl or '')) do
            local e = STRAY[w]
            if e and e.on ~= false and not e.lit then
                return T('в замене есть слово из "Лишних слов": после правки оно удалится')
            end
        end
    end
    if NAMES and not r.find:find('"', 1, true) then
        for _, e in pairs(NAMES) do
            if e.on and lo(e.name):find(f, 1, true) then
                return T('совпадает с названием "') .. e.name .. T('": внутри кавычек правки не применяются')
            end
        end
    end
    return nil
end

-- text - готовый текст, ad - исходник (для условий). Возвращает текст, доп. варианты, заметки
function TX.apply(text, ad)
    local alts, used, cur = {}, {}, text
    if #TX.rules == 0 then return cur, alts, used end
    local have = ctxHaveSet(ad)
    for _, r in ipairs(TX.rules) do
        if r.on and r.cpat and TX.cond(r, have) then
            local new, ch = TX.once(cur, r)
            if ch and new ~= cur then
                r.hits = (r.hits or 0) + 1
                local short = T('«') .. r.find .. T('» -> «') .. r.repl .. T('»')
                if r.mode == 'v' then
                    alts[#alts + 1] = { label = T('Правка: ') .. short, text = new, rule = true }
                else
                    cur = new
                    used[#used + 1] = T('правка текста: ') .. short
                end
            end
        end
    end
    return cur, alts, used
end

-- черновик правила из правки: чем отличается текст хелпера (a) от твоего (b)
function TX.draft(a, b)
    if a == b then return nil end
    local p = 0
    while p < #a and p < #b and a:byte(p + 1) == b:byte(p + 1) do p = p + 1 end
    local q = 0
    while q < #a - p and q < #b - p and a:byte(#a - q) == b:byte(#b - q) do q = q + 1 end
    local l, r = p, q                                   -- короткие правки (знаки) берём вместе с соседними символами
    while (#a - l - r) < 3 and (l > 0 or r > 0) and (p - l) < 12 do
        if l > 0 then l = l - 1 end
        if (#a - l - r) < 3 and r > 0 then r = r - 1 end
    end
    return a:sub(l + 1, #a - r), b:sub(l + 1, #b - r)
end

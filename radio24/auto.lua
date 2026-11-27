-- radio24/auto.lua: авто-правила: сравнение текста хелпера с запомненными правками и предложения правил.
-- Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- Идея: для каждой пары памяти "исходник -> твой итог" берём текст хелпера и сравниваем со словами итога.
-- Расхождение (1-3 слова) = кандидат в правило: заменить / удалить. Кандидат проверяется на ВСЕЙ памяти:
-- показывается, только если улучшает хотя бы одну пару и не ухудшает ни одной.
-- Включаешь сам кнопкой. Автовключение (AUTO.on) по умолчанию ВЫКЛ: тогда подтверждённое правило ставится само.
-- Правило "удалить слово из исходника" уходит в "Лишние слова", остальное - в "Правки текста".
---------------------------------------------------------------------
AUTO = { on = false, tests = true, terr = {}, min = 2, list = {}, added = {}, rej = {}, unexplained = {}, nPairs = 0, nOk = 0, err = '' }

local function norm2(s)
    s = trim(s or '')
    return (s:gsub('[%s%.]+$', ''))
end

local function cn(s)
    s = lo(norm2(s))
    return (s:gsub('%s+', ' '))
end

local function toks(s)
    local t = {}
    for w in (s or ''):gmatch('%S+') do t[#t + 1] = w end
    return t
end

-- различающиеся участки двух списков слов (LCS)
local function hunks(a, b)
    local n, m = #a, #b
    local L = {}
    for i = 0, n + 1 do
        L[i] = {}
        for j = 0, m + 1 do L[i][j] = 0 end
    end
    for i = n, 1, -1 do
        for j = m, 1, -1 do
            if a[i] == b[j] then L[i][j] = L[i + 1][j + 1] + 1
            else L[i][j] = math.max(L[i + 1][j], L[i][j + 1]) end
        end
    end
    local res, i, j, cur = {}, 1, 1, nil
    while i <= n or j <= m do
        if i <= n and j <= m and a[i] == b[j] then
            if cur then res[#res + 1] = cur; cur = nil end
            i, j = i + 1, j + 1
        else
            cur = cur or { A = {}, B = {}, ia = i }
            if i <= n and (j > m or L[i + 1][j] >= L[i][j + 1]) then
                cur.A[#cur.A + 1] = a[i]; i = i + 1
            else
                cur.B[#cur.B + 1] = b[j]; j = j + 1
            end
        end
    end
    if cur then res[#res + 1] = cur end
    return res
end

local function hcount(g, f) return #hunks(toks(norm2(g)), toks(norm2(f))) end

local function applyRule(rule, text)
    local new, ch = TX.once(text, rule)
    if not ch or new == text then return text end
    new = new:gsub('%s+', ' ')
    new = new:gsub('%s+([%.,;!%?:])', '%1')
    return (trim(new))
end

local function candKey(kind, find, repl) return kind .. '|' .. lo(find) .. '|' .. repl end

---------------------------------------------------------------------
-- Файл: настройки, отклонённые, журнал добавленного
---------------------------------------------------------------------
function autoSave()
    pcall(function()
        local f = io.open(DIR .. 'radio24_auto.txt', 'wb')
        if not f then return end
        f:write('on=', AUTO.on and '1' or '0', '\n', 'tests=', AUTO.tests and '1' or '0', '\n', 'min=', tostring(AUTO.min), '\n')
        for k in pairs(AUTO.rej) do f:write('rej\t', u8(k), '\n') end
        for _, a in ipairs(AUTO.added) do
            f:write('add\t', tostring(a.ts), '\t', a.how, '\t', a.kind, '\t', u8(a.find), '\t', u8(a.repl), '\n')
        end
        f:close()
    end)
end

function autoLoad()
    pcall(function()
        local f = io.open(DIR .. 'radio24_auto.txt', 'rb')
        if not f then return end
        for line in f:lines() do
            local k, v = line:match('^(%a+)=(.*)$')
            if k == 'on' then AUTO.on = v:sub(1, 1) == '1'
            elseif k == 'tests' then AUTO.tests = v:sub(1, 1) == '1'
            elseif k == 'min' then AUTO.min = math.max(1, math.min(10, tonumber(v) or 2))
            else
                local rj = line:match('^rej\t(.+)$')
                if rj then AUTO.rej[u8:decode(rj)] = true end
                local ts, how, kind, fi, rp = line:match('^add\t(%d+)\t(%a+)\t(%a+)\t(.-)\t(.*)$')
                if ts then
                    AUTO.added[#AUTO.added + 1] = { ts = tonumber(ts), how = how, kind = kind,
                        find = u8:decode(fi), repl = u8:decode(rp) }
                end
            end
        end
        f:close()
    end)
end

---------------------------------------------------------------------
-- Расчёт предложений
---------------------------------------------------------------------

-- кандидат из одного расхождения: kind, find, repl либо nil + причина
local function hunkCand(ga, h)
    local fa, fb = table.concat(h.A, ' '), table.concat(h.B, ' ')
    if #h.A == 0 and #h.B >= 1 and #h.B <= 4 then               -- вставка: цепляем за предыдущее слово
        local anc = ga[h.ia - 1]
        if anc and not anc:find('%d') and not anc:find('%p$') then return 'rep', anc, anc .. ' ' .. fb end
        return nil, nil, nil, T('вставка без опорного слова')
    elseif #h.A >= 1 and #h.A <= 4 and #h.B <= 5 then
        if fa:find('%d') or fb:find('%d') then return nil, nil, nil, T('в правке есть цифры') end
        if lo(fa) == lo(fb) then return nil, nil, nil, T('отличается только регистр') end
        if #fa >= 2 then return ((#h.B == 0) and 'del' or 'rep'), fa, fb end
        local anc = ga[h.ia - 1]                                 -- короткое слово (и, в, с): цепляем за предыдущее
        if anc and not anc:find('%d') and not anc:find('%p$') then
            return 'rep', anc .. ' ' .. fa, anc .. (fb ~= '' and (' ' .. fb) or '')
        end
        return nil, nil, nil, T('короткая правка без опорного слова')
    end
    return nil, nil, nil, T('слишком большая правка')
end

local function evalOn(P, c)
    local imp, brk = 0, 0
    local rule = { find = c.find, repl = c.repl, cpat = TX.compile(c.find) }
    if not rule.cpat then return 0, 0 end
    for _, p in ipairs(P) do
        local a = applyRule(rule, p.got)
        if a ~= p.got then
            local b0, b1 = hcount(p.got, p.final), hcount(a, p.final)
            if b1 < b0 then imp = imp + 1 elseif b1 > b0 then brk = brk + 1 end
        end
    end
    return imp, brk
end

local function collectPairs()
    local P = {}
    for _, e in pairs(MEM) do
        if e.orig and e.final and trim(e.orig) ~= '' and trim(e.final) ~= '' then
            local ok, vars = pcall(buildVariants, e.orig)
            local got
            if ok and type(vars) == 'table' then
                for _, v in ipairs(vars) do
                    if not v.mem and not v.src then got = v.text; break end
                end
            end
            if got then P[#P + 1] = { orig = e.orig, final = e.final, got = got, src = T('память') } end
        end
    end
    if AUTO.tests and KB and KB.allTests then
        local seen = {}
        for _, p in ipairs(P) do seen[norm(p.orig)] = true end
        for _, t in ipairs(KB.allTests()) do
            local o, f = T(t.inp), T(t.exp)
            if not seen[norm(o)] then
                local ok, vars = pcall(buildVariants, o)
                local got
                if ok and type(vars) == 'table' then
                    for _, v in ipairs(vars) do
                        if not v.mem and not v.src then got = v.text; break end
                    end
                end
                if got then P[#P + 1] = { orig = o, final = f, got = got, src = T('тест'), isTest = true } end
            end
        end
    end
    return P
end

local function haveRule(c)
    for _, r in ipairs(TX.rules) do
        if lo(r.find) == lo(c.find) and r.repl == c.repl then return true end
    end
    return false
end

function autoCompute()
    local P = collectPairs()
    local C, order, unexp, okN = {}, {}, {}, 0
    local before = {}
    for pi, p in ipairs(P) do
        before[pi] = hcount(p.got, p.final)
        if before[pi] == 0 then okN = okN + 1 end
    end
    -- кандидаты: каждое расхождение разбирается отдельно, поэтому цифры в одном месте не мешают правке в другом
    for pi, p in ipairs(P) do
        if before[pi] > 0 then
            local origSet = {}
            for _, w in ipairs(strayTokens(p.orig)) do origSet[w] = true end
            local bad, any, why = false, false, nil
            local ga = toks(norm2(p.got))
            for _, h in ipairs(hunks(ga, toks(norm2(p.final)))) do
                local kind, find, repl, w = hunkCand(ga, h)
                if kind then
                    any = true
                    local key = candKey(kind, find, repl)
                    local c = C[key]
                    if not c then
                        c = { kind = kind, find = find, repl = repl, key = key, pairs = {}, improved = 0, broken = 0,
                            inOrig = true, ex = { orig = p.orig, src = p.src } }
                        C[key] = c
                        order[#order + 1] = c
                    end
                    if not c.pairs[pi] then c.pairs[pi] = true; c.support = (c.support or 0) + 1 end
                    for _, ww in ipairs(strayTokens(find)) do if not origSet[ww] then c.inOrig = false end end
                else
                    bad = true
                    why = why or w
                end
            end
            p.why = why or T('не удалось объяснить')
            if bad or not any then
                if #unexp < 30 then unexp[#unexp + 1] = p end
            end
        end
    end
    -- проверка на всей памяти (и тестах)
    local res = {}
    for _, c in ipairs(order) do
        if not AUTO.rej[c.key] and not haveRule(c) then
            c.improved, c.broken = evalOn(P, c)
            if c.improved >= 1 and c.broken == 0 then res[#res + 1] = c end
        end
    end
    table.sort(res, function(x, y)
        if x.improved ~= y.improved then return x.improved > y.improved end
        return (x.support or 0) > (y.support or 0)
    end)
    -- ошибки тестов и предложения, как их исправить
    local terr = {}
    if AUTO.tests and KB and KB.allTests then
        for _, t in ipairs(KB.allTests()) do
            if #terr >= 40 then break end
            local o, f = T(t.inp), T(t.exp)
            local ok, got = pcall(fixText, o)
            if ok and got ~= f then
                local e = { inp = o, exp = f, got = got, cands = {} }
                for _, c in ipairs(autoPairCands(got, f, o)) do
                    local imp, brk = evalOn(P, c)
                    e.cands[#e.cands + 1] = { c = c, imp = imp, brk = brk }
                end
                terr[#terr + 1] = e
            elseif not ok then
                terr[#terr + 1] = { inp = o, exp = f, got = T('(ошибка разбора) ') .. tostring(got), cands = {} }
            end
        end
    end
    AUTO.terr = terr
    AUTO.list, AUTO.unexplained, AUTO.nPairs, AUTO.nOk = res, unexp, #P, okN
end

---------------------------------------------------------------------
-- Принять / отклонить / откатить
---------------------------------------------------------------------
function autoAccept(c, auto)
    local ok, msg, how
    local words = strayTokens(c.find)
    if c.kind == 'del' and c.inOrig and #words >= 1 and #words <= 3 and table.concat(words, ' ') == lo(c.find) then
        ok, msg = strayAdd(c.find, '', nil); how = 'stray'
    else
        ok, msg = TX.add(c.find, c.repl, '', '', 'r', nil); how = 'tx'
    end
    if ok then
        AUTO.added[#AUTO.added + 1] = { ts = os.time(), how = how, kind = c.kind, find = c.find, repl = c.repl }
        if #AUTO.added > 100 then table.remove(AUTO.added, 1) end
        autoSave()
        say((auto and T('Авто-правило добавлено: ') or T('Правило добавлено: ')) .. c.find
            .. (c.kind == 'rep' and (' -> ' .. c.repl) or T(' (удаление)')), 0xFF66FF66)
    else
        say(msg or T('Не удалось добавить правило.'), 0xFFFF6666)
    end
    return ok
end

function autoReject(c)
    AUTO.rej[c.key] = true
    autoSave()
end

function autoUndo(i)
    local a = AUTO.added[i]
    if not a then return end
    if a.how == 'stray' then
        strayDel(table.concat(strayTokens(a.find), ' '))
    else
        for k, r in ipairs(TX.rules) do
            if lo(r.find) == lo(a.find) and r.repl == a.repl then table.remove(TX.rules, k); TX.save(); break end
        end
    end
    table.remove(AUTO.added, i)
    autoSave()
end

-- apply = true: если включено автовключение, ставит подтверждённые правила (по одному, с пересчётом)
function autoRun(apply)
    local saved = STRAYLOG
    STRAYLOG = {}                                        -- пробные разборы не пишем в журнал
    local ok, err = pcall(function()
        for _ = 1, 6 do
            autoCompute()
            if not (apply and AUTO.on) then return end
            local pick
            for _, c in ipairs(AUTO.list) do
                if (c.support or 0) >= AUTO.min then pick = c; break end
            end
            if not pick then return end
            if not autoAccept(pick, true) then autoReject(pick) end
        end
    end)
    STRAYLOG = saved
    AUTO.err = ok and '' or tostring(err)
    if not ok then say('auto: ' .. AUTO.err, 0xFFFF6666) end
end


---------------------------------------------------------------------
-- Для вкладки "Тесты": правила из разницы между результатом хелпера и нужным результатом
---------------------------------------------------------------------
function autoPairCands(got, final, orig)
    local res, origSet = {}, {}
    for _, w in ipairs(strayTokens(orig or '')) do origSet[w] = true end
    local ga = toks(norm2(got))
    for _, h in ipairs(hunks(ga, toks(norm2(final)))) do
        local kind, find, repl = hunkCand(ga, h)
        if kind then
            local c = { kind = kind, find = find, repl = repl, key = candKey(kind, find, repl), inOrig = true }
            for _, w in ipairs(strayTokens(find)) do if not origSet[w] then c.inOrig = false end end
            res[#res + 1] = c
        end
    end
    return res
end

-- сколько пар памяти правило исправит и сколько сломает
function autoEval(c)
    local saved = STRAYLOG
    STRAYLOG = {}
    local improved, broken = 0, 0
    pcall(function()
        local rule = { find = c.find, repl = c.repl, cpat = TX.compile(c.find) }
        if not rule.cpat then return end
        for _, p in ipairs(collectPairs()) do
            local a = applyRule(rule, p.got)
            if a ~= p.got then
                local b0, b1 = hcount(p.got, p.final), hcount(a, p.final)
                if b1 < b0 then improved = improved + 1 elseif b1 > b0 then broken = broken + 1 end
            end
        end
    end)
    STRAYLOG = saved
    return improved, broken
end

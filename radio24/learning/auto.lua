-- radio24/learning/auto.lua: вкладка "Предложения": самообучение подбирает правку текста или лишнее слово.
-- Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- Ничего не добавляется само. Для каждой пары памяти (и теста) "исходник -> твой итог" берётся текст хелпера,
-- расхождение в 1-4 слова = кандидат: заменить (в "Правки текста") либо убрать слово (в "Лишние слова").
-- Кандидат показывается, только если он исправляет хотя бы одну пару и НЕ конфликтует: не ломает ни одну пару памяти
-- и ни один тест, не противоречит существующим правкам, словарю и названиям. Решаешь ты: Принять / Отклонить.
-- Всё добавленное попадает в общий журнал (LEARNLOG) и откатывается на вкладке журнала.
---------------------------------------------------------------------
AUTO = { tests = true, terr = {}, list = {}, conf = {}, rej = {}, unexplained = {}, nPairs = 0, nOk = 0, nConf = 0, err = '', stale = true }
JSRC = nil                                   -- откуда пришла правка (для журнала)

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
-- Файл: только отклонённые предложения (старые автоправила переносятся в журнал при первом запуске)
---------------------------------------------------------------------
local function fileRead(p) local f = io.open(p, 'rb'); if not f then return nil end local s = f:read('*a'); f:close(); return s end
local function backupFile(name)
    pcall(function()
        local s = fileRead(cfgPath(name))
        if not s then return end
        local bd = UCFG.dir .. 'radio24_cfgbak\\'
        pcall(function() if not doesDirectoryExist(bd) then createDirectory(bd) end end)
        local f = io.open(bd .. name .. '.bak', 'wb')
        if f then f:write(s); f:close() end
    end)
end

function autoSave()
    pcall(function()
        local f = io.open(cfgPath('radio24_auto.txt'), 'wb')
        if not f then return end
        f:write('#v2\n')
        for k in pairs(AUTO.rej) do f:write('rej\t', u8(k), '\n') end
        f:close()
    end)
end

-- Эталоны удалены полностью: файлы уходят в резервную копию и стираются
local function etalonCleanup()
    for _, nm in ipairs({ 'radio24_src.txt', 'radio24_srclog.txt' }) do
        if fileRead(cfgPath(nm)) then backupFile(nm); pcall(os.remove, cfgPath(nm)) end
    end
end

function autoLoad()
    pcall(etalonCleanup)
    local raw = fileRead(cfgPath('radio24_auto.txt'))
    if not raw then return end
    local legacy, adds = false, {}
    for line in raw:gmatch('[^\r\n]+') do
        if line:match('^%a+=') then legacy = true
        else
            local rj = line:match('^rej\t(.+)$')
            if rj then AUTO.rej[u8:decode(rj)] = true end
            local ts, how, kind, fi, rp = line:match('^add\t(%d+)\t(%a+)\t(%a+)\t(.-)\t(.*)$')
            if ts then
                legacy = true
                adds[#adds + 1] = { ts = tonumber(ts), how = how, kind = kind, find = u8:decode(fi), repl = u8:decode(rp) }
            end
        end
    end
    if not legacy then return end
    backupFile('radio24_auto.txt')
    -- перенос: правило должно существовать (в правках текста или в лишних словах) и попасть в журнал
    local had = {}
    for _, e in ipairs(LEARNLOG) do had[e.kind .. '|' .. e.key .. '|' .. e.val .. '|' .. e.ts] = true end
    for _, a in ipairs(adds) do
        local kindName, key, val
        if a.how == 'stray' then
            kindName, key, val = T('лишнее'), a.find, ''
            local k2 = table.concat(strayTokens(a.find), ' ')
            if k2 ~= '' and not STRAY[k2] then JSRC = T('перенос'); pcall(strayAdd, a.find, '', nil); JSRC = nil end
        else
            kindName, key, val = T('правка'), a.find, (a.kind == 'del') and '' or a.repl
            local exists = false
            for _, r in ipairs(TX.rules) do
                if lo(r.find) == lo(a.find) and r.repl == val then exists = true; break end
            end
            if not exists then JSRC = T('перенос'); pcall(TX.add, a.find, val, '', '', 'r', nil); JSRC = nil end
        end
        if not had[kindName .. '|' .. key .. '|' .. val .. '|' .. a.ts] then
            LEARNLOG[#LEARNLOG + 1] = { ts = a.ts, kind = kindName, key = key, val = val, ad = T('из автоправил') }
        end
    end
    table.sort(LEARNLOG, function(x, y) return x.ts < y.ts end)
    while #LEARNLOG > LEARNLOG_CAP do table.remove(LEARNLOG, 1) end
    pcall(learnLogSave)
    autoSave()
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


local function haveStray(c)
    local k = table.concat(strayTokens(c.find), ' ')
    return c.kind == 'del' and k ~= '' and STRAY[k] ~= nil
end

-- слова кандидата в виде, в котором их хранит "Лишние слова" (строчные, без знаков)
local function candPhrase(find)
    local s = lo(find or '')
    s = s:gsub('%p+', ' ')
    return trim((s:gsub('%s+', ' ')))
end

-- куда попадёт правило при принятии: stray (лишнее слово) или tx (правка текста)
function candTarget(c)
    if c.kind == 'del' and c.inOrig then
        local words = strayTokens(c.find)
        if #words >= 1 and #words <= 4 and table.concat(words, ' ') == candPhrase(c.find) then return 'stray' end
    end
    return 'tx'
end

local function wordsKey(s)
    local l = (lo(stripColors(s or '')):gsub('%p', ' '))
    return ' ' .. (l:gsub('%s+', ' ')) .. ' '
end

-- причина конфликта с текущими правилами / словарём / названиями (nil - конфликтов нет)
local function conflictOf(c, P)
    local f = lo(c.find)
    for _, r in ipairs(TX.rules) do
        if r.on and r.cpat then
            local rf = lo(r.find)
            if rf == f and r.repl ~= c.repl then return T('уже есть правка на это место с другой заменой') end
            if c.kind == 'rep' and #rf >= 3 and rf ~= f and lo(c.repl):find(rf, 1, true) and lo(r.repl) ~= rf then
                return T('результат замены попадёт под правку "') .. r.find .. '"'
            end
        end
    end
    if c.kind == 'rep' then
        local ok, cf = pcall(TX.conflict, { find = c.find, repl = c.repl })
        if ok and cf then return cf end
    end
    if c.kind == 'del' then
        local fk = trim(wordsKey(c.find))
        if STRAY_KEEP and STRAY_KEEP[fk] then return T('служебное слово, убирать нельзя') end
        if DICT and DICT[fk] then return T('слово есть в словаре') end
        if NAMES then
            for _, e in pairs(NAMES) do
                if e.on and wordsKey(e.name):find(' ' .. fk .. ' ', 1, true) then return T('слово входит в название "') .. e.name .. '"' end
            end
        end
        for _, p in ipairs(P) do
            if wordsKey(p.final):find(' ' .. fk .. ' ', 1, true) and not wordsKey(p.got):find(' ' .. fk .. ' ', 1, true) then
                return T('слово нужно в других объявлениях (есть в твоих итогах)')
            end
        end
    end
    return nil
end

local function candCtx(c)
    if not c.ex or not c.ex.orig then return '' end
    local w = strayTokens(c.find)[1]
    if not w then return '' end
    local ok, list = pcall(strayCtxList, c.ex.orig, w)
    if ok and type(list) == 'table' and #list > 0 then return table.concat(list, ' ') end
    return ''
end

function autoCompute()
    local P = collectPairs()
    local C, order, unexp, okN = {}, {}, {}, 0
    local before = {}
    for pi, p in ipairs(P) do
        before[pi] = hcount(p.got, p.final)
        if before[pi] == 0 then okN = okN + 1 end
    end
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
    local res, conf = {}, {}
    for _, c in ipairs(order) do
        if not AUTO.rej[c.key] and not haveRule(c) and not haveStray(c) then
            c.improved, c.broken = evalOn(P, c)
            if c.improved >= 1 then
                c.target = candTarget(c)
                local why
                if c.broken > 0 then why = T('ломает пар памяти/тестов: ') .. c.broken else why = conflictOf(c, P) end
                if why then
                    if #conf < 40 then conf[#conf + 1] = { c = c, why = why } end
                    AUTO.nConfTmp = (AUTO.nConfTmp or 0) + 1
                else
                    res[#res + 1] = c
                end
            end
        end
    end
    table.sort(res, function(x, y)
        if x.improved ~= y.improved then return x.improved > y.improved end
        return (x.support or 0) > (y.support or 0)
    end)
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
    AUTO.terr, AUTO.list, AUTO.conf, AUTO.unexplained = terr, res, conf, unexp
    AUTO.nPairs, AUTO.nOk, AUTO.nConf, AUTO.nConfTmp = #P, okN, #conf, nil
end

---------------------------------------------------------------------
-- Принять / отклонить
---------------------------------------------------------------------
function autoAccept(c, auto)
    local ok, msg
    JSRC = T('предложение')
    if candTarget(c) == 'stray' then ok, msg = strayAdd(candPhrase(c.find), candCtx(c), nil)
    else ok, msg = TX.add(c.find, c.repl, '', '', 'r', nil) end
    JSRC = nil
    if ok then
        say(T('Принято: ') .. c.find .. (c.kind == 'rep' and (' -> ' .. c.repl) or T(' (убрать слово)')), 0xFF66FF66)
    else
        say(msg or T('Не удалось добавить правило.'), 0xFFFF6666)
    end
    return ok
end

function autoReject(c)
    AUTO.rej[c.key] = true
    autoSave()
end

function autoRun()
    local saved = STRAYLOG
    STRAYLOG = {}                                        -- пробные разборы не пишем в журнал
    local ok, err = pcall(autoCompute)
    STRAYLOG = saved
    AUTO.err = ok and '' or tostring(err)
    AUTO.stale = false
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

---------------------------------------------------------------------
-- ЖУРНАЛ ИЗМЕНЕНИЙ АВТО-РЕДАКТИРОВАНИЯ: общий LEARNLOG (названия, тэги, правки текста, лишние слова, выученные замены)
---------------------------------------------------------------------
do
    local oldTxAdd = TX.add
    TX.add = function(find, repl, ctx, neg, mode, idx)
        local ok, msg = oldTxAdd(find, repl, ctx, neg, mode, idx)
        if ok then pcall(learnLogAdd, T('правка'), find, repl or '', JSRC or (idx and T('изменено') or T('вручную'))) end
        return ok, msg
    end
    local oldStrayAdd = strayAdd
    strayAdd = function(word, ctxText, oldWord)
        local ok, msg = oldStrayAdd(word, ctxText, oldWord)
        if ok then pcall(learnLogAdd, T('лишнее'), trim(word or ''), '', JSRC or (oldWord and T('изменено') or T('вручную'))) end
        return ok, msg
    end
end

-- откат записи журнала i: правило/название/тэг убирается из настроек, запись из журнала удаляется
function learnLogUndo(i)
    local l = LEARNLOG[i]
    if not l then return false end
    local k = l.kind
    if k == T('название') then
        pcall(namesDel, l.val)
    elseif k == T('тег') then
        pcall(function() TAGS[l.val] = nil; TAGS[lo(l.val)] = nil; tagsSave() end)
    elseif k == T('правка') then
        for j, r in ipairs(TX.rules) do
            if lo(r.find) == lo(l.key) and r.repl == l.val then table.remove(TX.rules, j); TX.save(); break end
        end
    elseif k == T('лишнее') then
        for part in (l.key):gmatch('[^,;\n]+') do
            local p = trim(part)
            pcall(strayDel, p)
            pcall(strayDel, table.concat(strayTokens(p), ' '))
        end
    else
        LEARN[l.key] = nil
        pcall(learnSave)
    end
    table.remove(LEARNLOG, i)
    learnLogSave()
    AUTO.stale = true
    return true
end

---------------------------------------------------------------------
-- МИГРАЦИЯ ВЫУЧЕННЫХ ПРАВИЛ (LEARN): работающие правила переезжают в "Лишние слова" (удаление одного слова без стоп-слов)
-- или в "Правки текста" (замены, удаления со стоп-словами и фразы). Запись остаётся в журнале. LEARN после этого пуст.
---------------------------------------------------------------------
function learnMigrate()
    -- старые записи журнала про выученные замены больше не нужны (их откатывать нечем)
    do
        local named = { [T('название')] = true, [T('тег')] = true, [T('правка')] = true, [T('лишнее')] = true }
        local keep, drop = {}, 0
        for _, l in ipairs(LEARNLOG) do
            if named[l.kind] then keep[#keep + 1] = l else drop = drop + 1 end
        end
        if drop > 0 then LEARNLOG = keep; pcall(learnLogSave) end
    end
    local keys = {}
    for k in pairs(LEARN) do keys[#keys + 1] = k end
    if #keys == 0 then return end
    table.sort(keys)
    pcall(function()                                           -- копия файла выученных правил (один раз)
        local bd = UCFG.dir .. 'radio24_cfgbak\\'
        pcall(function() if not doesDirectoryExist(bd) then createDirectory(bd) end end)
        if not fileRead(bd .. 'radio24_learn.txt.bak') then
            local s = fileRead(cfgPath('radio24_learn.txt'))
            if s then local o = io.open(bd .. 'radio24_learn.txt.bak', 'wb'); if o then o:write(s); o:close() end end
        end
    end)
    local nStray, nTx, nSkip, nFail, nPending = 0, 0, 0, 0, 0
    JSRC = T('из выученных')
    for _, ck in ipairs(keys) do
        local e = LEARN[ck]
        if e.n < learnNeed(e) then
            nPending = nPending + 1                            -- ещё не подтверждено повторами: не действовало, не переносим
        else
            local phrase, ctx, neg = ctxSplit(ck)
            local ctxS, negS = (ctx:gsub(',', ' ')), (neg:gsub(',', ' '))
            local done = false
            if e.val == '' and neg == '' then
                local k2 = table.concat(strayTokens(phrase), ' ')
                if k2 ~= '' and STRAY[k2] then nSkip = nSkip + 1; done = true
                else
                    local ok = false
                    pcall(function() ok = strayAdd(phrase, (ctx:gsub(',', ', ')), nil) end)   -- каждое слово контекста - своя группа (любое из них)
                    if ok then nStray = nStray + 1; done = true end
                end
            end
            if not done then
                local exists = false
                for _, r in ipairs(TX.rules) do
                    if lo(r.find) == lo(phrase) and r.repl == e.val then exists = true; break end
                end
                if exists then nSkip = nSkip + 1
                else
                    local ok = false
                    pcall(function() ok = TX.add(phrase, e.val, ctxS, negS, 'r', nil) end)
                    if ok then nTx = nTx + 1 else nFail = nFail + 1 end
                end
            end
        end
    end
    JSRC = nil
    LEARN, LCTX = {}, {}
    pcall(learnSave)
    pcall(autoSave)
    AUTO.stale = true
    pcall(say, T('Выученные правила перенесены: в Лишние слова ') .. nStray .. T(', в Правки текста ') .. nTx
        .. T(', уже были ') .. nSkip .. T(', не перенесено ') .. nFail .. T(', неподтверждённых отброшено ') .. nPending
        .. T('. Копия: radio24\\config\\updates\\radio24_cfgbak\\radio24_learn.txt.bak'), 0xFF66FF66)
end

do                                                         -- миграция запускается сразу после загрузки всех настроек
    local oldAutoLoad = autoLoad
    autoLoad = function()
        oldAutoLoad()
        pcall(learnMigrate)
    end
end

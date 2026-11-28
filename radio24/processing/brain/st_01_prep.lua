-- radio24/processing/brain/st_01_prep.lua: этап 1 разбора объявления (fixText): «кто в бар» = игра «Орел и решка» (вся фраза целиком). Строки оригинала 182-328. Общее окружение модулей.
-- Код этапа не менялся. Состояние разбора передаётся через таблицу S: в начале этапа значения берутся из S, в конце записываются обратно.
BRAIN.stage('01_prep', function(S)
    local notes, info, note, s, opts = S.notes, S.info, S.note, S.s, S.opts
    -- «кто в бар» = игра «Орел и решка» (вся фраза целиком)
    do
        local q = trim((lo(s):gsub('[%?!%.,]+', ' '):gsub('%s+', ' ')))
        if q == T('кто в бар') or q == lo(T('Ищу азартного игрока в бар')) then
            S.result = { T('Ищу азартного игрока в "Орел и решка". Ставка: договорная'), notes, info }; return
        end
    end
    s = s:gsub('(%d)%s+%$', '%1$')                              -- "1.200.666 $" -> "1.200.666$"
    s = s:gsub('("[^"]-)%((%u%d+)%)"', '%1%2"')                 -- "... (W214)" -> "... W214"
    local lowSrc = lo(s)
    local simCtx0 = lowSrc:find(T('сим'), 1, true) or lowSrc:find(T('с/к'), 1, true)

    local letters, caps = 0, 0
    for c in s:gmatch('.') do
        if isLetter(c) then
            letters = letters + 1
            if isUpper(c) then caps = caps + 1 end
        end
    end
    if letters > 3 and caps / letters > 0.6 then s = lo(s) end
    if not opts.noNames and not opts.bare then                      -- список названий: кавычки включить/убрать
        local fzList
        s, fzList = namesFuzzy(s)                                   -- название с опечаткой -> как в списке
        if fzList and #fzList > 0 then note(T('опечатка в названии исправлена: ') .. table.concat(fzList, ', ')) end
        local ns, nc = namesApply(s)
        if nc > 0 then s = ns; info.names = nc; note(T('названия из списка (кавычки): ') .. nc) end
    end

    if PLACES and placeFuzzy then                                   -- место: русская запись/опечатки -> как в словаре
        local okp, ps, pf = pcall(placeFuzzy, s)
        if okp and ps then
            s = ps
            if pf and #pf > 0 then note(T('место исправлено: ') .. table.concat(pf, ', ')) end
        end
    end

    -- Опечатки: растянутые буквы ("продааааам" -> "продам"); "ккк" и "ххх" не трогаем
    s = s:gsub('([\224-\255])%1%1+', function(ch)
        local c = lo(ch)
        if c == T('к') or c == T('х') then return nil end
        return ch
    end)

    -- Слитные слова («продамбизнес» -> «продам бизнес»): шифр по согласным + база слов, только при уверенном разборе
    if not opts.noCipher and not opts.bare and CIPHER then
        local okc, ns, chg = pcall(CIPHER.split, s)
        if okc and type(ns) == 'string' and ns ~= '' and type(chg) == 'table' and #chg > 0 then
            s = ns; info.glued = true
            for _, c in ipairs(chg) do note(T('слитное слово разделено: ') .. c) end
        end
    end

    -- GPS (п.3.1): "gps 4>8" / "гпс 4-1" -> "GPS: 4 > 8"
    local gpsTxt
    for _, kw in ipairs({ 'gps', T('гпс'), T('навигатор') }) do
        local a, b, p1, sep, p2 = lo(s):find(kw .. '%s*:?%s*%(?%s*(%d+)%s*([>%-\150\151]+)%s*(%d+)%s*%)?')
        if a and lo(s):sub(1, a - 1):match('%[%s*$') and lo(s):sub(b + 1):match('^%s*%]') then a = nil end   -- [GPS 8>97] оставляем как есть
        if a then
            gpsTxt = 'GPS: ' .. p1 .. ' ' .. sep .. ' ' .. p2
            s = trim(s:sub(1, a - 1) .. ' ' .. s:sub(b + 1))
            break
        end
    end
    lowSrc = lo(s)

    -- Намерения без цены: работа, азартные игры, тир, знакомства, поиск человека (п.3.6)
    do
        local itext = KB.intent(s, lowSrc, note)
        if itext then
            info.intent = true
            for _, w in ipairs(WARN) do
                if lowSrc:find(w[1], 1, true) then note(T('ЗАПРЕЩЕНО/проверь: ') .. w[2]) end
            end
            S.result = { (trim((itext:gsub('%s+', ' ')))), notes, info }; return
        end
    end

    -- Слитные знаки: «".(NY2022).Цена:5кк» -> «". (NY2022). Цена:5кк»
    s = s:gsub('([\224-\255]/[\224-\255])"', '%1 "')                  -- а/м"BMW -> а/м "BMW
    s = s:gsub('("%d+")(%d)', '%1 %2')                               -- "737"3х -> "737" 3х (слитно после номера)
    s = s:gsub('(%S)"%[', '%1" [')                                   -- "BMW"[HW24] -> "BMW" [HW24]
    s = (' ' .. s):gsub('(%s)[' .. T('гГ') .. ']%.%s*([VvWw][Ii][Nn][Ee]%s?[Ww][Oo][Oo][Dd])', '%1' .. T('горе') .. ' %2'):sub(2)   -- г.VineWood -> горе VineWood
    s = s:gsub('%[(%a+%d*)%s*[,;]([^%]]*)%]', function(tg, rest)     -- [HW24,ковш] -> [HW24]
        local b = lo(tg):match('^(%a+)')
        if b and (TAGBUILTIN[b] or TAGS[b]) then
            note(T('в тэге лишнее слово убрано: ') .. trim(rest))
            return '[' .. tg .. ']'
        end
    end)
    s = s:gsub('(["\187%)])%.([^%s%.])', '%1. %2')
    s = s:gsub('([%]%)])([%a\192-\255])', '%1 %2')                     -- "[FT-PT]Цена" -> "[FT-PT] Цена"
    s = s:gsub('([^%s%d,]),([%a\192-\255])', '%1, %2')                  -- "[HW26],Цена" -> "[HW26], Цена"
    s = s:gsub('"' .. T('и') .. '"', '" ' .. T('и') .. ' "')           -- '"пальма"и"вертушка"' -> '"пальма" и "вертушка"'
    s = (' ' .. s):gsub('(%s)([' .. T('дгДГ') .. '])%.(%a)', '%1%2. %3'):sub(2)   -- "д.Angel" -> "д. Angel"
    s = s:gsub('([%.%)"\187])([^%s%.%)"\187:]+):', function(a, w)
        if DROP[lo(w)] then return a .. ' ' .. w .. ':' end
    end)
    local toks = tokenize(s)

    -- "Цена:договорная" / "Бюджет:5кк" слитно -> два слова
    do
        local sp = {}
        for _, tk in ipairs(toks) do
            local a, b = tk.core:match('^(.-):(.+)$')
            if a and (DROP[lo(a)] or lo(a) == T('цена')) then
                sp[#sp + 1] = { pre = tk.pre, core = a, post = ':' }
                sp[#sp + 1] = { pre = '', core = b, post = tk.post }
            else
                sp[#sp + 1] = tk
            end
        end
        toks = sp
    end

    -- Слитное "15.000.000$торг" / "5кк,торг" / "торг5кк" -> сумма и слово "торг" отдельно
    do
        local sp = {}
        for _, tk in ipairs(toks) do
            local lc = lo(tk.core)
            local done = false
            for w in pairs(TORG) do
                if #lc > #w and lc:sub(-#w) == w then
                    local base = tk.core:sub(1, #tk.core - #w):gsub('[%.,;:%-/%s]+$', '')
                    if base:match('%d') or base:find('$', 1, true) then
                        sp[#sp + 1] = { pre = tk.pre, core = base, post = '' }
                        sp[#sp + 1] = { pre = '', core = tk.core:sub(-#w), post = tk.post }
                        done = true
                        break
                    end
                elseif #lc > #w and lc:sub(1, #w) == w then
                    local rest = tk.core:sub(#w + 1):gsub('^[%.,;:%-/%s]+', '')
                    if rest:match('%d') then
                        sp[#sp + 1] = { pre = tk.pre, core = tk.core:sub(1, #w), post = '' }
                        sp[#sp + 1] = { pre = '', core = rest, post = tk.post }
                        done = true
                        break
                    end
                end
            end
            if not done then sp[#sp + 1] = tk end
        end
        toks = sp
    end
    local hasTorgWord = false
    for _, tk in ipairs(toks) do
        if TORG[lo(tk.core)] then hasTorgWord = true end
    end
    S.notes, S.info, S.note, S.s, S.lowSrc, S.simCtx0, S.letters, S.caps, S.gpsTxt, S.toks, S.hasTorgWord, S.opts = notes, info, note, s, lowSrc, simCtx0, letters, caps, gpsTxt, toks, hasTorgWord, opts
end)

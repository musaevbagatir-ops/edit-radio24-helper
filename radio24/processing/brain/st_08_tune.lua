-- radio24/processing/brain/st_08_tune.lua: этап 8 разбора объявления (fixText): Номера, тюнинг, цвета, full. Строки оригинала 993-1124. Общее окружение модулей.
-- Код этапа не менялся. Состояние разбора передаётся через таблицу S: в начале этапа значения берутся из S, в конце записываются обратно.
BRAIN.stage('08_tune', function(S)
    local note, toks, hasVeh, hasHouse, tuneParts, opts = S.note, S.toks, S.hasVeh, S.hasHouse, S.tuneParts, S.opts
    -- Номера, тюнинг, цвета, full
    local tune = { NY = false, HW = false, FT = false, PT = false }
    local prevTune = false
    local TW = { ft = true, pt = true, full = true, ['ft/pt'] = true, ['ft-pt'] = true, ['pt-ft'] = true, [T('фт-пт')] = true, [T('фт')] = true, [T('пт')] = true,
        [T('фулл')] = true, [T('фт/пт')] = true }
    do   -- «хв 26» / «hw 26» / «нг 24»: тэг и год через пробел -> одно слово (hw26)
        local o7, i7 = {}, 1
        while i7 <= #toks do
            local tk7, nx7 = toks[i7], toks[i7 + 1]
            local c7 = lo(tk7.core)
            if hasVeh and nx7 and tk7.post == '' and nx7.pre == '' and (c7 == T('хв') or c7 == 'hw' or c7 == T('нг') or c7 == 'ny')
                and (nx7.core:match('^%d%d$') or nx7.core:match('^20%d%d$')) then
                o7[#o7 + 1] = { pre = tk7.pre, core = c7 .. nx7.core, post = nx7.post }
                i7 = i7 + 2
            else
                o7[#o7 + 1] = tk7
                i7 = i7 + 1
            end
        end
        toks = o7
    end
    local firstVeh
    local out2 = {}
    for _, tk in ipairs(toks) do
        local c = lo(tk.core)
        c = tagRuLatin(c, tk)                       -- хв26 -> hw26, нг26 -> ny26 (русская запись HW/NY, в том числе с опечаткой)
        local keep = true
        if tk.veh and not firstVeh then firstVeh = tk end
        if tk.drop then
            keep = false
        elseif not opts.bare and tagFix(tk, c) then
            -- известный тэг ([BDAY7], [BP]...): оставляем, оформляем в скобки
        elseif not tk.pre:find('"', 1, true)
            and tk.core:match('^[%a\192-\255]%d%d%d[%a\192-\255][%a\192-\255]$') then
            local r = tk.core:gsub('.', function(ch) return LOOK[lo(ch)] or up(ch) end)
            tk.core = '"' .. r .. '"'
            tk.pre = ''
        elseif hasVeh and (c == T('фт') or c == 'ft') then tune.FT = true; keep = false
        elseif hasVeh and (c == T('пт') or c == 'pt') then tune.PT = true; keep = false
        elseif hasVeh and (c == 'ft/pt' or c == T('фт/пт') or c == 'pt/ft' or c == T('пт/фт') or c == 'ft-pt' or c == 'pt-ft'
            or c == T('фт-пт') or c == T('пт-фт')) then
            tune.FT, tune.PT = true, true; keep = false
        elseif hasVeh and (c == T('хв') or c == 'hw' or c == T('хэллоуин') or c == T('хеллоуин')) then tune.HW = true; keep = false
        elseif hasVeh and (c == 'ny' or c == T('нг')) then tune.NY = true; keep = false
        elseif hasVeh and (c:match('^hw%-?%d+$') or c:match('^' .. T('хв') .. '%-?%d+$')) then
            tune.HW = true; tune.HWY = c:match('%d+$'); keep = false
        elseif hasVeh and (c:match('^ny%-?%d+$') or c:match('^' .. T('нг') .. '%-?%d+$')) then
            tune.NY = true; tune.NYY = c:match('%d+$'); keep = false
        elseif not hasVeh and (c:match('^hw%-?%d%d+$') or c:match('^ny%-?%d%d+$')) then   -- а/с, к/с из коллекции: [HW-26] -> [HW26]
            local yy = c:match('%d+$')
            if #yy == 4 then yy = yy:sub(3) end
            tk.core = c:sub(1, 2):upper() .. yy
            tk.pre = '['
            tk.post = ']' .. ((tk.post:gsub('^[%]%)]+', '')))
        elseif hasVeh and prevTune and (c == T('тюнинг') or c == T('тюн') or c == 'tune') then keep = false
        elseif c == 'full' or c == T('фулл') or ruTrig(c, 'full') then
            if hasVeh then
                tune.FT, tune.PT = true, true
                keep = false
            elseif hasHouse then
                tk.core = T('с евроремонтом')
                tk.pre = ''
                tk.post = (tk.post:gsub('["%.]', ''))
                note(T('full -> с евроремонтом (п.2.12)'))
            else
                keep = false
                note(T('слово full запрещено (п.2.12)'))
            end
        elseif hasVeh and COLORS[c] then
            keep = false
            note(T('цвет т/с удалён (п.3.2)'))
        end
        if keep then out2[#out2 + 1] = tk end
        prevTune = TW[c] == true
    end
    toks = out2

    local tags = {}
    for _, k in ipairs({ 'NY', 'HW', 'FT', 'PT' }) do
        if tune[k] then
            local y = (k == 'NY' and tune.NYY) or (k == 'HW' and tune.HWY) or ''
            if #y == 4 then y = y:sub(3) end                     -- NY2022 -> NY22
            tags[#tags + 1] = k .. y
        end
    end
    if #tags > 0 and firstVeh then
        for idx, tk in ipairs(toks) do
            if tk == firstVeh then
                table.insert(toks, idx + 1, { pre = '', core = '[' .. ((#tags == 2 and tags[1] == 'FT' and tags[2] == 'PT') and 'FT-PT' or table.concat(tags, '/')) .. ']',
                    post = tk.post })
                tk.post = ''
                break
            end
        end
    end

    if #tuneParts > 0 and firstVeh then
        local at
        for idx, tk in ipairs(toks) do if tk == firstVeh then at = idx; break end end
        if at then
            if toks[at + 1] and toks[at + 1].core:match('^%[') then at = at + 1 end
            local host = toks[at]
            table.insert(toks, at + 1, { pre = '', core = '[Tune: ' .. table.concat(tuneParts, ', ') .. ']', post = host.post })
            host.post = ''
        end
    end

    if not opts.bare then                                   -- название КАПСОМ (одно слово) -> "Spyder"; н/з не трогаем
        for idx, tk in ipairs(toks) do
            local inner = tk.veh and tk.core:match('^"(%a+)"$')
            local pv = toks[idx - 1]
            if inner and #inner >= 5 and inner == inner:upper() and not (pv and lo(pv.core) == T('н/з')) and not DICT[lo(inner)] then
                tk.core = '"' .. inner:sub(1, 1) .. inner:sub(2):lower() .. '"'
            end
        end
    end
    if not opts.bare and not opts.noNames then
        for idx, tk in ipairs(toks) do
            local inner = tk.veh and tk.core:match('^"([^"]+)"$')
            local pv = toks[idx - 1]
            if inner and not (pv and lo(pv.core) == T('н/з')) then
                local e = NAMES[lo(inner)]
                if e and e.on and e.name ~= inner then tk.core = '"' .. e.name .. '"' end
            end
        end
    end
    -- лишнее двоеточие после сокращения категории: «а/м: "X"» -> «а/м "X"»
    for _, tk in ipairs(toks) do
        if tk.post:find(':', 1, true) and not tk.core:find('"', 1, true) and catIs(tk.core) then
            tk.post = (tk.post:gsub(':', ''))
        end
    end
    S.note, S.toks, S.hasVeh, S.hasHouse, S.tuneParts, S.tune, S.prevTune, S.TW, S.firstVeh, S.out2, S.tags, S.opts = note, toks, hasVeh, hasHouse, tuneParts, tune, prevTune, TW, firstVeh, out2, tags, opts
end)

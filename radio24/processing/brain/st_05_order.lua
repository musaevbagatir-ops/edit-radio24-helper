-- radio24/processing/brain/st_05_order.lua: этап 5 разбора объявления (fixText): Порядок по ПРО: место идёт после класса/марки/дополнений (перед ценой),. Строки оригинала 676-734. Общее окружение модулей.
-- Код этапа не менялся. Состояние разбора передаётся через таблицу S: в начале этапа значения берутся из S, в конце записываются обратно.
BRAIN.stage('05_order', function(S)
    local toks, i, op = S.toks, S.i, S.op
    -- Порядок по ПРО: место идёт после класса/марки/дополнений (перед ценой),
    -- даже если в исходнике оно стоит в начале
    do
        local PREP = set { 'в', 'во', 'на', 'у', 'около', 'возле', 'рядом' }
        local LANDW = set { 'кольце', 'кольца', 'кольцо', 'районе', 'района', 'район', 'горе', 'горы', 'гору' }
        local AREA1 = set { 'бейсайд', 'bayside', 'vinewood', 'вайнвуд', 'ganton', 'idlewood', 'willowfield' }
        local AREA2 = { { T('опасный'), T('район') }, { 'glen', 'park' }, { 'el', 'corona' }, { 'east', 'beach' } }
        local gpre = T('г. ')
        local dpre = T('д. ')
        local mark, n, i = {}, #toks, 1
        while i <= n do
            local lc = lo(toks[i].core)
            local len = 0
            if lc:sub(1, #gpre) == gpre or lc:sub(1, #dpre) == dpre or lc:find('vinewood', 1, true) or lc == 'vine wood' or AREA1[lc] or lc:find(T('опасн'), 1, true) or lc:find(T('творческ'), 1, true) then
                len = 1
            else
                for _, ph in ipairs(AREA2) do
                    if lc == ph[1] and toks[i + 1] and lo(toks[i + 1].core) == ph[2] then len = 2 end
                end
            end
            if len > 0 and toks[i + len] and LANDW[lo(toks[i + len].core)] then len = len + 1 end   -- "в опасном районе"
            if len > 0 then
                local st = i
                if st > 1 and not mark[st - 1] and LANDW[lo(toks[st - 1].core)] then st = st - 1 end
                if st > 1 and not mark[st - 1] and PREP[lo(toks[st - 1].core)] then st = st - 1 end
                for k = st, i + len - 1 do mark[k] = true end
                if st > 1 and not mark[st - 1] then toks[st - 1].post = toks[st - 1].post:gsub('[,;%.]', '') end
                i = i + len
            else
                i = i + 1
            end
        end
        for k = 2, n - 1 do                                       -- "в г. A и в г. B": союз между местами едет вместе с ними
            if not mark[k] and mark[k - 1] and mark[k + 1] and lo(toks[k].core) == T('и') then mark[k] = true end
        end
        if next(mark) and op ~= 'swap' then
            local a, b = {}, {}
            for k = 1, n do
                if mark[k] then
                    toks[k].post = toks[k].post:gsub('[,;%.]', '')
                    b[#b + 1] = toks[k]
                else
                    a[#a + 1] = toks[k]
                end
            end
            if #a > 0 then a[#a].post = (a[#a].post:gsub('[,;%.]', '')) end
            for _, tk in ipairs(b) do a[#a + 1] = tk end
            toks = a
        end
    end

    -- Флаги
    local hasVeh, vehAbbr, hasHouse, hasClass, hasChai = false, false, false, false, false
    for _, tk in ipairs(toks) do
        local c = lo(tk.core)
        if tk.veh then hasVeh = true; vehAbbr = true end
        if VEHABBR[c] then vehAbbr = true end
        if c == T('дом') or c == T('особняк') then hasHouse = true end
        if c == T('особняк') then hasClass = true end
        if c == T('чай') then hasChai = true end
    end
    S.toks, S.i, S.op, S.hasVeh, S.vehAbbr, S.hasHouse, S.hasClass, S.hasChai = toks, i, op, hasVeh, vehAbbr, hasHouse, hasClass, hasChai
end)

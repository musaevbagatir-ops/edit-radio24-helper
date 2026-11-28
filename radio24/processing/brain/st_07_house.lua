-- radio24/processing/brain/st_07_house.lua: этап 7 разбора объявления (fixText): Класс дома: "дом эконом" -> "дом эконом-класса". Строки оригинала 875-992. Общее окружение модулей.
-- Код этапа не менялся. Состояние разбора передаётся через таблицу S: в начале этапа значения берутся из S, в конце записываются обратно.
BRAIN.stage('07_house', function(S)
    local toks, hasVeh, hasHouse, hasClass = S.toks, S.hasVeh, S.hasHouse, S.hasClass
    -- Класс дома: "дом эконом" -> "дом эконом-класса"
    if hasHouse then
        for idx, tk in ipairs(toks) do
            local c = lo(tk.core)
            if CLASSMAP[c] then
                tk.core = CLASSMAP[c]
                hasClass = true
                local nx = toks[idx + 1]
                if nx and CLASSW[lo(nx.core)] then nx.drop = true end
                -- "класса бизнес" -> "бизнес-класса": слово "класс(а)" ПЕРЕД названием класса тоже убираем (иначе дубль)
                local pv = toks[idx - 1]
                if pv and not pv.drop then
                    local pl = lo(pv.core)
                    if CLASSW[pl] or pl == T('класса') or pl == T('класс') then pv.drop = true end
                end
            elseif c:find(T('класса'), 1, true) then
                hasClass = true
            end
        end
    end

    -- Дом: номер дома («н38», «№38», «номер 38») и гаражные места «2х гаражом» (п.3.3)
    if hasHouse then
        -- «дом (60) эконом класса»: число в скобках / после слова «дом» - номер дома, ставим после класса
        do
            local ni
            for idx, tk in ipairs(toks) do
                if not ni and tk.core:match('^%d%d?%d?%d?$') then
                    local pv, nx = toks[idx - 1], toks[idx + 1]
                    local pl = pv and lo(pv.core) or ''
                    local nl = nx and lo(nx.core) or ''
                    local bad = nl:find('^' .. T('этаж')) or nl:find('^' .. T('комнат')) or nl:find('^' .. T('гараж'))
                        or nl:find('^' .. T('мест'))
                    local hashed = tk.pre:find('#', 1, true) ~= nil or tk.pre:find(T('№'), 1, true) ~= nil
                    if (hashed or not bad) and (tk.pre:find('[%(#]') or tk.pre:find(T('№'), 1, true) or pl == T('дом') or pl == T('особняк')) then
                        ni = idx
                    end
                end
            end
            if ni then
                local num = toks[ni].core
                table.remove(toks, ni)
                local at, foundCls = ni, false
                for idx, tk in ipairs(toks) do
                    if lo(tk.core):find(T('класса'), 1, true) then at = idx + 1; foundCls = true; break end
                end
                if not foundCls then
                    for idx, tk in ipairs(toks) do
                        local hc = lo(tk.core)
                        if hc == T('дом') or hc == T('особняк') then at = idx + 1; break end
                    end
                end
                table.insert(toks, at, { pre = '', core = T('с номером "') .. num .. '"', post = '' })
            end
        end
        local o6, i6 = {}, 1
        while i6 <= #toks do
            local tk, nx = toks[i6], toks[i6 + 1]
            local c = lo(tk.core)
            local hn = c:match('^' .. T('н') .. '%.?(%d+)$') or c:match('^' .. T('№') .. '(%d+)$')
            local gn = c:match('^(%d)%-?[x' .. T('х') .. ']$') or c:match('^(%d)%-?' .. T('местн') .. '%S*$')
            if hn then
                o6[#o6 + 1] = { pre = '', core = T('с номером "') .. hn .. '"', post = tk.post }
                i6 = i6 + 1
            elseif c == T('н/з') and nx and nx.core:match('^%d+$') then
                o6[#o6 + 1] = { pre = '', core = T('с номером "') .. nx.core .. '"', post = nx.post }
                i6 = i6 + 2
            elseif gn and nx and lo(nx.core):find('^' .. T('гараж')) then
                if gn == '1' then
                    o6[#o6 + 1] = { pre = tk.pre, core = T('с гаражом'), post = nx.post }
                else
                    o6[#o6 + 1] = { pre = tk.pre, core = gn .. T('х'), post = '' }
                    o6[#o6 + 1] = { pre = '', core = T('гаражом'), post = nx.post }
                end
                i6 = i6 + 2
            elseif c:find('^' .. T('гараж')) and nx and lo(nx.core):match('^(%d)%-?[x' .. T('х') .. ']$') then
                local g2 = lo(nx.core):match('^(%d)%-?[x' .. T('х') .. ']$')      -- «гараж 1x»
                if g2 == '1' then
                    o6[#o6 + 1] = { pre = tk.pre, core = T('с гаражом'), post = nx.post }
                else
                    o6[#o6 + 1] = { pre = tk.pre, core = g2 .. T('х'), post = '' }
                    o6[#o6 + 1] = { pre = '', core = T('гаражом'), post = nx.post }
                end
                i6 = i6 + 2
            else
                o6[#o6 + 1] = tk; i6 = i6 + 1
            end
        end
        toks = o6
    end

    -- Неполный тюнинг (п.3.2): «с нитро и новыми дисками» -> [Tune: нитро, диски]
    local tuneParts = {}
    if hasVeh then
        local rm, got = {}, {}
        for idx, tk in ipairs(toks) do
            local lab = KB.tuneparts[lo(tk.core)]
            if lab then
                rm[idx] = true
                local dup = false
                for _, g in ipairs(got) do if g == lab then dup = true end end
                if not dup then got[#got + 1] = lab end
                local j = idx - 1
                while j >= 1 and KB.tunejunk[lo(toks[j].core)] do rm[j] = true; j = j - 1 end
                if j >= 1 then
                    local pc = lo(toks[j].core)
                    if pc == T('с') or pc == T('со') then rm[j] = true
                    elseif pc == T('и') and rm[j - 1] then rm[j] = true end
                end
            end
        end
        if #got > 0 then
            local kept = {}
            for idx, tk in ipairs(toks) do if not rm[idx] then kept[#kept + 1] = tk end end
            toks, tuneParts = kept, got
        end
    end
    S.toks, S.hasVeh, S.hasHouse, S.hasClass, S.tuneParts = toks, hasVeh, hasHouse, hasClass, tuneParts
end)

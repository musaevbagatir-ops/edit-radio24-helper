-- radio24/processing/brain/st_06_vehicles.lua: этап 6 разбора объявления (fixText): Латинские названия при наличии т/с: кавычки, склейка соседних слов. Строки оригинала 735-874. Общее окружение модулей.
-- Код этапа не менялся. Состояние разбора передаётся через таблицу S: в начале этапа значения берутся из S, в конце записываются обратно.
BRAIN.stage('06_vehicles', function(S)
    local note, lowSrc, toks, hasVeh, vehAbbr, opts = S.note, S.lowSrc, S.toks, S.hasVeh, S.vehAbbr, S.opts
    -- Латинские названия при наличии т/с: кавычки, склейка соседних слов
    if vehAbbr then
        local merged, last, openq = {}, nil, nil
        local function closeq(t)                  -- "Name" из pre/post переносим в core, как у остальных названий
            t.core = '"' .. t.core .. '"'
            t.pre, t.post = t.pre:gsub('"', ''), t.post:gsub('"', '')
        end
        for ti, tk in ipairs(toks) do
            local c = lo(tk.core)
            local closesLater = false                 -- название в кавычках закрывается дальше (число внутри названия не рвёт его)
            if openq then
                for j = ti + 1, #toks do
                    if toks[j].post:find('"', 1, true) then closesLater = true; break end
                    if toks[j].pre:find('"', 1, true) then break end
                end
            end
            local isTagTk = openq and not tk.pre:find('"', 1, true) and (tk.pre:find('[', 1, true)
                or c:match('^hw%-?%d+$') or c:match('^ny%-?%d+$') or tagBase(c, tk))
            if isTagTk then
                closeq(openq); openq = nil
                tk.post = (tk.post:gsub('"', ''))
                merged[#merged + 1] = tk
                last = nil
            elseif openq and not tk.pre:find('"', 1, true) and tk.core:match('^%d[%d%.%-]*%a?$')
                and (closesLater or tk.post:find('"', 1, true)) then
                openq.core = openq.core .. ' ' .. tk.core          -- "Peterbilt 379 Optimus Prime": число внутри названия
                openq.post = tk.post
                if tk.post:find('"', 1, true) then closeq(openq); openq = nil end
            elseif not opts.bare and not openq and last == nil and merged[#merged] and merged[#merged].core:match('^".*"$')
                and not tk.pre:find('"', 1, true) and tk.post:find('"', 1, true) and tk.core:match('^%a[%w%-]*$') then
                -- хвост названия после уже закрытого названия: "BMW M5 F90" LSPD" -> выученное удаление или склейка обратно
                local pm = merged[#merged]
                local lg = learnedGet(c)
                if lg and lg.val == '' then
                    note(T('убрано слово внутри кавычек (выученное правило): ') .. tk.core)
                    pm.post = (pm.post or '') .. (tk.post:gsub('"', ''))
                else
                    pm.core = pm.core:sub(1, -2) .. ' ' .. tk.core .. '"'
                    pm.post = (pm.post or '') .. (tk.post:gsub('"', ''))
                end
            elseif last and last.post == '' and tk.core:match('^%d+%a$') and not tk.pre:find('"', 1, true) then
                last.core = last.core:sub(1, -2) .. ' ' .. tk.core .. '"'          -- McLaren 650S
                last.post = tk.post
            elseif tk.core:match('^%a[%w%-]*$') and not TUNEW[c] and not LOCLAT[c] and not tk.veh
                and not c:match('^hw%-?%d+$') and not c:match('^ny%-?%d+$') and not tagBase(c, tk)
                and not (tk.pre:find('[%(%[]') and not openq) then
                if tk.pre:find('"', 1, true) then
                    tk.veh = true; hasVeh = true
                    merged[#merged + 1] = tk
                    last = nil
                    if tk.post:find('"', 1, true) then closeq(tk) else openq = tk end   -- "Mercedes Maybach": название продолжается
                elseif openq then
                    if not ((c == 'halloween' or c == T('хэллоуин') or c == T('хеллоуин')) and lowSrc:find('hw', 1, true)) then
                        openq.core = openq.core .. ' ' .. tk.core
                    end
                    openq.post = tk.post
                    if tk.post:find('"', 1, true) then closeq(openq); openq = nil end
                elseif last and last.post == '' then
                    last.core = last.core:sub(1, -2) .. ' ' .. tk.core .. '"'
                    last.post = tk.post
                else
                    tk.core = '"' .. tk.core .. '"'
                    tk.veh = true; hasVeh = true
                    merged[#merged + 1] = tk
                    last = tk
                end
            else
                merged[#merged + 1] = tk
                last, openq = nil, nil
            end
        end
        toks = merged
    end

    if hasVeh then
        local anyAbbr = false
        local GENW = set { 'любой', 'любую', 'любое', 'другой', 'другую', 'другое' }
        for idx, tk in ipairs(toks) do
            local pvw = toks[idx - 1]
            if (VEHABBR[lo(tk.core)] and not (pvw and GENW[lo(pvw.core)]))
                or (tk.veh and tk.core:find('/', 1, true)) then anyAbbr = true end
        end
        if not anyAbbr then
            for idx, tk in ipairs(toks) do
                if tk.veh then table.insert(toks, idx, { pre = '', core = T('а/м'), post = '' }); break end
            end
        end
    end

    -- «марки» перед маркой, у которой уже есть а/м: слово «марки» не нужно
    do
        local o9 = {}
        for idx, tk in ipairs(toks) do
            local c = lo(tk.core)
            local nx = toks[idx + 1]
            if (c == T('марки') or c == T('марка')) and nx and VEHABBR[lo(nx.core:match('^(%S+)') or '')] then
                -- пропускаем
            else
                o9[#o9 + 1] = tk
            end
        end
        toks = o9
    end

    -- «марки» только если уточняет (п.3.1); несколько т/с через «и» (п.3.2)
    if hasVeh then
        local BRANDS = set { 'toyota', 'honda', 'bmw', 'mercedes', 'audi', 'ferrari', 'lamborghini', 'ford', 'nissan',
            'porsche', 'chevrolet', 'dodge', 'mazda', 'subaru', 'lexus', 'bentley', 'tesla' }
        local o3 = {}
        for idx, tk in ipairs(toks) do
            local c = lo(tk.core)
            local nx = toks[idx + 1]
            if (c == T('марки') or c == T('марка')) and nx and nx.veh then
                local _, sp = nx.core:gsub(' ', '')
                if sp >= 1 then tk = nil end
            end
            if tk then o3[#o3 + 1] = tk end
        end
        local o4 = {}
        for _, tk in ipairs(o3) do
            local inner = tk.veh and tk.core:match('^"(%a+)"$')
            local pv = o4[#o4]
            if inner and BRANDS[lo(inner)] and pv and lo(pv.core) == T('а/м') then
                o4[#o4 + 1] = { pre = '', core = T('марки'), post = '' }
            end
            o4[#o4 + 1] = tk
        end
        toks = o4
        local vi = {}
        for idx, tk in ipairs(toks) do if tk.veh then vi[#vi + 1] = idx end end
        if #vi >= 2 then
            local li = vi[#vi]
            local pv = toks[li - 1]
            if pv and lo(pv.core) ~= T('и') and not catIs(pv.core) then
                pv.post = (pv.post:gsub('[,;]', ''))
                table.insert(toks, li, { pre = '', core = T('и'), post = '' })
            end
        end
    end
    S.note, S.lowSrc, S.toks, S.hasVeh, S.vehAbbr, S.opts = note, lowSrc, toks, hasVeh, vehAbbr, opts
end)

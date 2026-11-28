-- radio24/processing/brain/st_03_dictionary.lua: этап 3 разбора объявления (fixText): слова внутри кавычек (названия): выученные правила на них не действуют ("Маска кицунэ" не станет "а/с кицунэ"). Строки оригинала 446-546. Общее окружение модулей.
-- Код этапа не менялся. Состояние разбора передаётся через таблицу S: в начале этапа значения берутся из S, в конце записываются обратно.
-- Названия т/с по марке и разновидности: "camry v6" -> "Toyota Camry V6", "bmw e5" -> "BMW E5", "bmw" -> "BMW".
-- Берётся из списка названий (категория "транспорт"). Спорные (два названия) не трогаем.
local VI_CACHE
local VI_STOP = {}
for _, w in ipairs({ 'full', 'black', 'white', 'series', 'class', 'turbo', 'sport', 'tune', 'vip', 'edition', 'race', 'police' }) do VI_STOP[w] = true end
local function vehIndex()
    local cnt = 0
    for _ in pairs(NAMES) do cnt = cnt + 1 end
    if VI_CACHE and VI_CACHE.n == cnt then return VI_CACHE end
    local idx = { n = cnt, full = {}, alias = {}, brand = {} }
    local trn, amb, firstRest = lo(T('транспорт')), {}, {}
    for _, e in pairs(NAMES) do
        if e.on and e.cat and lo(e.cat) == trn and e.name and e.name:find('^%a') then
            local words = {}
            for w in e.name:gmatch('%S+') do words[#words + 1] = w end
            idx.full[lo(e.name)] = e.name
            idx.brand[lo(words[1])] = idx.brand[lo(words[1])] or words[1]
            if #words >= 2 then
                local rest = lo(table.concat(words, ' ', 2))
                if #rest >= 3 then
                    if idx.alias[rest] and idx.alias[rest] ~= e.name then amb[rest] = true else idx.alias[rest] = e.name end
                end
                local fw = lo(words[2])
                firstRest[fw] = firstRest[fw] or {}
                firstRest[fw][e.name] = true
            end
        end
    end
    for w, set in pairs(firstRest) do                 -- "camry" -> единственное название с таким словом после марки
        local only, k = nil, 0
        for nm in pairs(set) do only = nm; k = k + 1 end
        if k == 1 and #w >= 4 and not w:find('%d') and not VI_STOP[w] and not idx.alias[w] and not idx.full[w] then idx.alias[w] = only end
    end
    for r in pairs(amb) do idx.alias[r] = nil end
    VI_CACHE = idx
    return idx
end

local function vehAliasMatch(toks, i, qin)
    local tk = toks[i]
    if not tk or tk.veh or qin[i] then return nil end
    local idx = vehIndex()
    if not next(idx.full) then return nil end
    for n = math.min(3, #toks - i + 1), 1, -1 do
        local words, ok = {}, true
        for j = i, i + n - 1 do
            local t = toks[j]
            if qin[j] or t.veh or not t.core:match('^%a[%w%-]*$') or (j < i + n - 1 and t.post ~= '') or (j > i and t.pre ~= '') then
                ok = false; break
            end
            words[#words + 1] = t.core
        end
        if ok then
            local key = lo(table.concat(words, ' '))
            local nm = idx.full[key]
            if nm and (n >= 2 or #key >= 4) then return { name = nm, n = n } end
            nm = idx.alias[key]
            if nm then return { name = nm, n = n, guess = true } end
            if n == 2 and idx.brand[lo(words[1])] and words[2]:match('^%a%d%d?%d?$') then
                return { name = idx.brand[lo(words[1])] .. ' ' .. up(words[2]), n = 2, guess = true }
            end
        end
    end
    return nil
end

BRAIN.stage('03_dictionary', function(S)
    local note, toks, opts = S.note, S.toks, S.opts
    -- слова внутри кавычек (названия): выученные правила на них не действуют ("Маска кицунэ" не станет "а/с кицунэ")
    local qin, qopen = {}, false
    for idx, tk in ipairs(toks) do
        local _, qp = tk.pre:gsub('"', '')
        if qp % 2 == 1 then qopen = not qopen end
        qin[idx] = qopen or qp > 0
        local _, qc = tk.post:gsub('"', '')
        if qc % 2 == 1 then qopen = not qopen end
    end
    -- Проход 2: словарь (длинные фразы в приоритете)
    local out, i = {}, 1
    while i <= #toks do
        local done = false
        for n = math.min(MAXW, #toks - i + 1), 1, -1 do
            local parts = {}
            for j = i, i + n - 1 do parts[#parts + 1] = lo(toks[j].core) end
            local key = table.concat(parts, ' ')
            local inq = false
            for j = i, i + n - 1 do if qin[j] then inq = true end end
            local e = (not opts.bare and not inq and learnedGet(key)) or DICT[key]
            if e then
                if e.note then note(e.note) end
                if e.val ~= '' then
                    local quoted = e.val:find('"', 1, true) ~= nil
                    local pre0, post0 = toks[i].pre, toks[i + n - 1].post
                    if quoted then pre0 = (pre0:gsub('"', '')); post0 = (post0:gsub('"', '')) end
                    out[#out + 1] = { pre = pre0, core = e.val, post = post0, cat = e.cat,
                        veh = (e.cat == nil or e.cat == 'veh') and quoted }
                elseif toks[i + n - 1].post:find('"', 1, true) and out[#out] and out[#out].pre:find('"', 1, true)
                    and not out[#out].post:find('"', 1, true) then
                    out[#out].post = out[#out].post .. '"'          -- убранное слово стояло перед закрывающей кавычкой
                end
                i = i + n
                done = true
                break
            end
        end
        if not done then
            local tk0 = toks[i]
            local vm
            if not opts.bare and not opts.noNames and not qin[i] and not tk0.veh then
                local okv, rv = pcall(vehAliasMatch, toks, i, qin)
                if okv then vm = rv end
            end
            local fz = (not vm) and KB.fuzzyVeh(lo(tk0.core)) or nil
            if vm then
                if vm.guess then note(T('название т/с по марке/модели: \"') .. tk0.core .. T('\" -> ') .. vm.name .. T(' (проверь)')) end
                out[#out + 1] = { pre = (tk0.pre:gsub('"', '')), core = '"' .. vm.name .. '"', post = (toks[i + vm.n - 1].post:gsub('"', '')),
                    veh = true, cat = 'veh' }
                i = i + vm.n - 1
            elseif fz then
                note(T('нечёткое распознавание: "') .. tk0.core .. T('" -> ') .. fz.val .. T(' (проверь)'))
                out[#out + 1] = { pre = (tk0.pre:gsub('"', '')), core = fz.val, post = (tk0.post:gsub('"', '')),
                    veh = true, cat = 'veh' }
            else
                out[#out + 1] = tk0
            end
            i = i + 1
        end
    end
    toks = out

    -- «чай марки X» -> «чай» (п.3.1, пример №8)
    do
        local o2, i2 = {}, 1
        while i2 <= #toks do
            local c = lo(toks[i2].core)
            local pv = o2[#o2] and lo(o2[#o2].core)
            if (c == T('марки') or c == T('марка')) and pv == T('чай') and toks[i2 + 1] then
                i2 = i2 + 2
            else
                o2[#o2 + 1] = toks[i2]; i2 = i2 + 1
            end
        end
        toks = o2
    end

    -- «дом VIP особняк» -> «особняк» (особняк уже включает дом, VIP не пишем)
    do
        local SKIPW = set { 'vip', 'вип' }
        local rm2 = {}
        for idx, tk in ipairs(toks) do
            if lo(tk.core) == T('дом') then
                local j = idx + 1
                while toks[j] and (SKIPW[lo(toks[j].core)] or ruTrig(lo(toks[j].core), 'vip')) do j = j + 1 end
                if toks[j] and lo(toks[j].core) == T('особняк') then
                    for k = idx, j - 1 do rm2[k] = true end
                end
            end
        end
        if next(rm2) then
            local o7 = {}
            for idx, tk in ipairs(toks) do if not rm2[idx] then o7[#o7 + 1] = tk end end
            toks = o7
            note(T('дом VIP особняк -> особняк (слово дом не пишем)'))
        end
    end
    -- «в гетто лс»: опасный район не привязываем к городу
    do
        local o8, dropped = {}, false
        for _, tk in ipairs(toks) do
            local pv = o8[#o8]
            if pv and lo(pv.core):find(T('опасн'), 1, true) and lo(tk.core):sub(1, 3) == T('г. ') then
                dropped = true
            else
                o8[#o8 + 1] = tk
            end
        end
        if dropped then toks = o8; note(T('город после опасного района убран')) end
    end
    S.note, S.toks, S.qin, S.qopen, S.out, S.i, S.opts = note, toks, qin, qopen, out, i, opts
end)

-- radio24/processing/brain/st_02_price.lua: этап 2 разбора объявления (fixText): ЧИСЛА (п.3.5): "1 000 000" / "1.5 млн" склеиваем; количество и цена за штуку отдельно от цены. Строки оригинала 329-445. Общее окружение модулей.
-- Код этапа не менялся. Состояние разбора передаётся через таблицу S: в начале этапа значения берутся из S, в конце записываются обратно.
BRAIN.stage('02_price', function(S)
    local info, note, s, lowSrc, simCtx0, toks, hasTorgWord, opts = S.info, S.note, S.s, S.lowSrc, S.simCtx0, S.toks, S.hasTorgWord, S.opts
    -- ЧИСЛА (п.3.5): "1 000 000" / "1.5 млн" склеиваем; количество и цена за штуку отдельно от цены
    toks = KB.mergeNums(toks)
    local crimeKind = KB.crimeKindOf(lowSrc)
    local qty, unitPrice, bigQty
    if crimeKind then qty, unitPrice, bigQty, toks = KB.extractQty(toks, crimeKind, lowSrc) end

    -- Проход 1: цена / торг / договорная / свободный
    local price, priceMult, torg
    local list = {}
    local afterDrop = false          -- предыдущее слово было "Цена"/"Бюджет"
    for _, tk in ipairs(toks) do
        local core = lo(tk.core)
        local kwk = (not opts.noFuzzy) and KB.kw(core) or nil     -- опечатки в договорная/свободный/бюджет
        local raw = lo(tk.pre .. tk.core .. tk.post)
        raw = raw:gsub('[%.,;!]+$', '')
        local num, suf = raw:match('^%$?(%d[%d%.,]*)([^%d%s%$]*)%$?$')
        local v, mult
        if num then v, mult = parsePrice(num, suf) end
        local prev = list[#list]
        -- сумма вида 7.000.000 (без $) тоже считается ценой
        local grouped = num and mult == 1 and num:find('[%.,]%d%d%d') ~= nil
            and v and v >= cfg.minPrice
        local plainBig = num and suf == '' and #num >= 5 and not num:find('[%.,]') and v and v >= cfg.minPrice
            and not simCtx0
        if v and not price and (mult > 1 or raw:find('%$') or afterDrop or grouped or plainBig
            or (prev and PRICEKW[lo(prev.core)])) then
            price, priceMult = v, mult
            while list[#list] and PRICEKW[lo(list[#list].core)] do list[#list] = nil end
        elseif v and price and v == price and (mult > 1 or raw:find('%$') or afterDrop or grouped) then
            -- повтор той же цены: убираем (чтобы цена не дублировалась)
        elseif TORG[core] or DOGOVOR[core] or kwk == 'dog' then
            torg = true
        elseif SVOBODN[core] or DROP[core] or kwk == 'svob' or kwk == 'drop' or (hasTorgWord and TORGHELP[core]) then
            -- заменится итоговым "Цена:/Бюджет:"
        else
            list[#list + 1] = tk
        end
        afterDrop = (DROP[core] == true) or kwk == 'drop'
    end
    toks = list

    -- Купоны (п.3.6): «купон» + название бонуса в кавычках
    do
        local cname, cnotes = buildCoupon(lowSrc)
        if cname then
            local keep = {}
            for _, tk in ipairs(toks) do
                if OPS[lo(tk.core)] then keep[#keep + 1] = tk end
            end
            keep[#keep + 1] = { pre = '', core = T('купон') .. ' "' .. cname .. '"', post = '' }
            toks = keep
            for _, n in ipairs(cnotes) do note(n) end
        elseif lowSrc:find(T('купон'), 1, true) then
            note(T('купон: не удалось определить название бонуса - впиши вручную по списку ПРО (п.3.6)'))
        end
    end

    -- Сим-карты и номерные знаки: «формата» только когда уточняет (п.3.1, п.3.2, п.3.6)
    do
        local simctx = lowSrc:find(T('сим'), 1, true) or lowSrc:find(T('с/к'), 1, true)
        local platectx = (lowSrc:find(T('номер'), 1, true) or lowSrc:find(T('н/з'), 1, true) or lowSrc:find(T('н.з'), 1, true)
            or lowSrc:find(T('знак'), 1, true)) and not simctx
        if simctx or platectx then
            local o, fmtw = {}, false
            local function isTyp(x) x = lo(x or ''); return x == T('типу') or x == T('типа') or x == T('тип') end
            for idx, tk in ipairs(toks) do
                local c = lo(tk.core)
                if simctx and (isTyp(c) or (c == T('по') and toks[idx + 1] and isTyp(toks[idx + 1].core))) then
                    -- «по типу» в объявлении о сим-карте не нужно
                elseif simctx and (c:find('^' .. T('номер')) or c == T('с')) then
                    -- «с номером» в объявлении о сим-карте не нужно
                elseif c == T('формата') or c == T('формат') then
                    fmtw = true
                else
                    local bare = tk.core
                    local function unq() tk.pre = (tk.pre:gsub('"', '')); tk.post = (tk.post:gsub('"', '')) end
                    if simctx and bare:match('^%d%d%d%d%d%d$') then
                        unq(); tk.core = '"' .. simPattern(bare) .. '"'
                    elseif simctx and bare:match('^%d%d%-%d%d%-%d%d$') then
                        unq(); tk.core = '"' .. bare .. '"'
                    elseif simctx and bare:match('^%a+%-%a+%-%a+$') then
                        local oq = tk.pre:find('"', 1, true) ~= nil
                        unq(); tk.core = ((oq and not fmtw) and '' or T('формата ')) .. '"' .. up(bare) .. '"'
                    elseif platectx and fmtw and bare:gsub('"', ''):match('^[%w\192-\255]+$')
                        and not bare:match('^[%a\192-\255]%d%d%d[%a\192-\255][%a\192-\255]$') then
                        unq(); tk.core = T('формата ') .. '"' .. up((bare:gsub('"', ''))) .. '"'
                    end
                    fmtw = false
                    o[#o + 1] = tk
                end
            end
            toks = o
        end
    end

    -- Опечатки в ключевых словах (камфорт -> комфорт, апасном -> опасном, клылья -> крылья) и «дам» вместо «дом»
    if not opts.noFuzzy then
        for _, tk in ipairs(toks) do
            local lc = lo(tk.core)
            if not ((not opts.bare and learnedGet(lc)) or DICT[lc] or OPS[lc]) then
                local fw = KB.fuzzyWord(lc)
                if fw then
                    note(T('опечатка: "') .. tk.core .. T('" -> "') .. fw .. '"')
                    tk.core = fw
                    info.typo = true
                end
            end
        end
        for idx, tk in ipairs(toks) do
            local nx = toks[idx + 1]
            if lo(tk.core) == T('дам') and nx and (CLASSMAP[lo(nx.core)] or CLASSW[lo(nx.core)]) then
                tk.core = T('дом'); info.typo = true
                note(T('опечатка: "дам" -> "дом"'))
            end
        end
    end
    S.info, S.note, S.s, S.lowSrc, S.simCtx0, S.toks, S.hasTorgWord, S.crimeKind, S.qty, S.unitPrice, S.bigQty, S.price, S.priceMult, S.torg, S.list, S.afterDrop, S.opts = info, note, s, lowSrc, simCtx0, toks, hasTorgWord, crimeKind, qty, unitPrice, bigQty, price, priceMult, torg, list, afterDrop, opts
end)

-- radio24/processing/brain/st_04_deal.lua: этап 4 разбора объявления (fixText): Тип сделки. Строки оригинала 547-675. Общее окружение модулей.
-- Код этапа не менялся. Состояние разбора передаётся через таблицу S: в начале этапа значения берутся из S, в конце записываются обратно.
BRAIN.stage('04_deal', function(S)
    local note, lowSrc, toks, crimeKind, qty, bigQty = S.note, S.lowSrc, S.toks, S.crimeKind, S.qty, S.bigQty
    -- Тип сделки
    local op
    for idx, tk in ipairs(toks) do
        if OPS[lo(tk.core)] then
            op = OPS[lo(tk.core)]
            table.remove(toks, idx)
            break
        end
    end

    -- События/розыгрыши (п.3.4): это не продажа - правила купли/продажи не применяем
    local isEvent = false
    if not op then
        for _, w in ipairs(KB.eventkw) do if lowSrc:find(w, 1, true) then isEvent = true end end
    end
    if isEvent then
        note(T('мероприятие/розыгрыш: реклама только при заключённом договоре (п.2.16, п.3.4)'))
        for idx, tk in ipairs(toks) do
            if tk.core == '24/7' and toks[idx - 1] and lo(toks[idx - 1].core) == T('в') then
                toks[idx - 1].core = T('в магазине')
            end
        end
    end

    -- Предприятие без слова «п/п» (п.3.3): "АЗС" -> "п/п АЗС", "24/7" -> "п/п магазин 24/7"
    if op and not isEvent then
        local hasPP, other = false, false
        for _, tk in ipairs(toks) do
            local c = lo(tk.core)
            if c == T('п/п') or c == T('бизнес') then hasPP = true end
            if c == T('дом') or c == T('особняк') or ((tk.veh or tk.cat) and op ~= 'swap') then other = true end
        end
        if not hasPP and not other then
            for idx, tk in ipairs(toks) do
                if KB.bizw[lo(tk.core)] then
                    local pv = toks[idx - 1]
                    table.insert(toks, idx, { pre = '', core = T('п/п'), post = '' })
                    if lo(tk.core) == '24/7' and not (pv and lo(pv.core) == T('магазин')) then
                        table.insert(toks, idx + 1, { pre = '', core = T('магазин'), post = '' })
                    end
                    break
                end
            end
        end
    end

    -- Лавка на центральном рынке (п.3.6): «лавка №7» / «лавка 7» / «в лавке на цр номер 7» -> «лавка №7 на ЦР»
    do
        local LAVW = set { 'лавка', 'лавке', 'лавку', 'лавки', 'лавкой', 'лафка', 'лафке', 'лафку', 'лавак' }
        local SKIPL = set { 'на', 'цр', 'ц/р', 'центральном', 'центральный', 'рынке', 'рынок', 'номер', 'номером', 'под', '№', '#' }
        local CRW = set { 'цр', 'ц/р', 'центральном', 'рынке' }
        local PREP = set { 'в', 'во', 'на', 'из', 'у' }
        local o5, i5 = {}, 1
        while i5 <= #toks do
            local tk = toks[i5]
            local num, jEnd
            if LAVW[lo(tk.core)] then
                local j = i5 + 1
                while toks[j] and j <= i5 + 5 do
                    local tt = lo(toks[j].pre .. toks[j].core)
                    local d = tt:match('^[' .. T('№') .. '#]?(%d+)$')
                    if d and #d <= 3 then num, jEnd = d, j; break end
                    if not SKIPL[lo(toks[j].core)] then break end
                    j = j + 1
                end
            end
            if num then
                local hasCR = false
                for k, t2 in ipairs(toks) do
                    if (k < i5 or k > jEnd) and CRW[lo(t2.core)] then hasCR = true end
                end
                local pv = o5[#o5]
                if pv and PREP[lo(pv.core)] then table.remove(o5) end
                if o5[#o5] and o5[#o5].post == '' then o5[#o5].post = ',' end
                o5[#o5 + 1] = { pre = tk.pre, core = T('лавка №') .. num, post = '' }
                local lastPost = toks[jEnd].post
                if hasCR then o5[#o5].post = lastPost
                else o5[#o5 + 1] = { pre = '', core = T('на ЦР'), post = lastPost } end
                i5 = jEnd + 1
            else
                o5[#o5 + 1] = tk; i5 = i5 + 1
            end
        end
        toks = o5
    end

    -- Криминал (п.3.5): бластер + пули, чай, т/и, запчасти; количество и цена за штуку
    if crimeKind then
        local gun
        for _, tk in ipairs(toks) do if tk.cat == 'gun' and not gun then gun = tk end end
        local function isBul(tk) local c = lo(tk.core); return c == T('пули для бластеров') or KB.bulw[c] end
        local bul = (qty and qty.unit == 'pt') or false
        local keep, firstBul = {}, nil
        for _, tk in ipairs(toks) do
            if crimeKind == 'bullet' and isBul(tk) then
                bul = true
                if not gun and not firstBul then
                    tk.core = T('пули для бластеров'); firstBul = tk; keep[#keep + 1] = tk
                end
            else
                keep[#keep + 1] = tk
            end
        end
        toks = keep
        if gun and bul then gun.core = T('пули для бластера') .. gun.core:sub(#T('бластер') + 1) end
        if not gun and bul and not firstBul then
            firstBul = { pre = '', core = T('пули для бластеров'), post = '' }
            toks[#toks + 1] = firstBul
        end
        local item = gun or firstBul
        if not item then
            for _, tk in ipairs(toks) do
                local c = lo(tk.core)
                if c == T('чай') or tk.cat == 'tob' or c == T('запчасти к бластеру') then item = tk; break end
            end
        end
        local phrase
        if qty then phrase = KB.qtyPhrase(crimeKind, qty)
        elseif bigQty then phrase = T('в большом кол-ве') end
        if phrase then
            local at = 0
            if item then for idx, tk in ipairs(toks) do if tk == item then at = idx; break end end end
            if at == 0 then at = #toks end
            local itk = toks[at]
            table.insert(toks, at + 1, { pre = '', core = phrase, post = itk and itk.post or '' })
            if itk then itk.post = '' end
        end
    end
    S.note, S.lowSrc, S.toks, S.crimeKind, S.qty, S.bigQty, S.op, S.isEvent = note, lowSrc, toks, crimeKind, qty, bigQty, op, isEvent
end)

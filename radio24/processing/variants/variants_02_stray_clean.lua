-- radio24/processing/variants/variants_02_stray_clean.lua: часть 2 из 6 файла processing/variants. лишние слова, часть 2: удаление слов (strayClean) и обучение (strayLearn). Общее окружение модулей, см. radio24_helper.lua
-- убрать слово целиком; не трогаем кавычки, дефисы, слэши и подпись "слово:"
local function strayRemoveWord(text, word)
    local low = lo(text)
    local pat, plain = word, true
    if word:find(' ', 1, true) then pat, plain = (word:gsub(' ', '[%%s%%-]+')), false end
    local out, pos, removed = {}, 1, false
    while true do
        local s, e = low:find(pat, pos, plain)
        if not s then break end
        local prev = s > 1 and text:sub(s - 1, s - 1) or ''
        local nxt = e < #text and text:sub(e + 1, e + 1) or ''
        local ok = (prev == '' or not (isLetter(prev) or prev:match('[%d%-/]')))
            and (nxt == '' or not (isLetter(nxt) or nxt:match('[%d%-/]')))
        if ok then
            local _, q = text:sub(1, s - 1):gsub('"', '')
            if q % 2 == 1 then ok = false end
        end
        if ok and text:sub(e + 1):match('^%s*(.)') == ':' then ok = false end
        if ok then
            out[#out + 1] = text:sub(pos, s - 1)
            removed = true
        else
            out[#out + 1] = text:sub(pos, e)
        end
        pos = e + 1
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out), removed
end

function strayTidy(t)
    t = t:gsub('%s+', ' ')
    t = t:gsub('%s+([%.,;!%?])', '%1')
    t = t:gsub('([%.,;])%1+', '%1')
    t = t:gsub('([a-z\224-\255])%.([A-Z\192-\223])', '%1. %2')
    return (trim(t))
end

-- буквальная запись (знаки, цифры, заглавные): убираем точное совпадение вне кавычек и вне [скобок]
local function strayRemoveLit(text, lit)
    local out, pos, from, removed = {}, 1, 1, false
    local wc = '[%w\192-\255\168\184]'
    local edgeL, edgeR = lit:sub(1, 1):match(wc), lit:sub(-1):match(wc)
    while true do
        local s, e = text:find(lit, from, true)
        if not s then break end
        local prev = s > 1 and text:sub(s - 1, s - 1) or ''
        local nxt = e < #text and text:sub(e + 1, e + 1) or ''
        local ok = true
        if edgeL and prev ~= '' and prev:match(wc) then ok = false end
        if ok and edgeR and nxt ~= '' and nxt:match(wc) then ok = false end
        if ok and not edgeL and not edgeR and prev:match('%d') and nxt:match('%d') then ok = false end
        if ok then
            local before = text:sub(1, s - 1)
            local _, q = before:gsub('"', '')
            local _, ob = before:gsub('%[', '')
            local _, cb = before:gsub('%]', '')
            if q % 2 == 1 or ob > cb then ok = false end
        end
        if ok then
            out[#out + 1] = text:sub(pos, s - 1) .. ' '
            pos, removed = e + 1, true
            from = e + 1
        else
            from = s + 1
        end
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out), removed
end

-- text - готовый текст, ad - исходник. Возвращает очищенный текст и список убранных слов
function strayClean(text, ad)
    local cur, removed = text, {}
    for _, w in ipairs(STRAY_LW) do
        for _, lab in ipairs(STRAY_LW) do
            local s, e = lo(cur):find(w .. '[%s%.,;]*' .. lab .. ':')
            if s then
                local prev = s > 1 and cur:sub(s - 1, s - 1) or ''
                if prev == '' or not isLetter(prev) then
                    cur = cur:sub(1, s - 1) .. cur:sub(e - #lab)
                    removed[#removed + 1] = w
                end
            end
        end
    end
    local origW = {}
    for _, w in ipairs(strayTokens(ad)) do origW[w] = true end
    local adNorm = ' ' .. table.concat(strayTokens(ad), ' ') .. ' '
    local have = strayHave(ad)
    local function try(w)
        local n, r = strayRemoveWord(cur, w)
        if r then cur = n; removed[#removed + 1] = w end
    end
    for w in pairs(STRAY_FILLER) do if origW[w] then try(w) end end
    for w, e in pairs(STRAY) do
        if e.on ~= false and not e.lit and e.n >= 1 and adNorm:find(' ' .. w .. ' ', 1, true) and strayCtxOk(e, have) then try(w) end
    end
    for w, e in pairs(STRAY) do
        if e.lit and e.on ~= false then
            local n, r = strayRemoveLit(cur, w:sub(2))
            if r then cur = n; removed[#removed + 1] = w end
        end
    end
    if #removed == 0 then return text, {} end
    cur = strayTidy(cur)
    if #cur < 8 then return text, {} end
    return cur, removed
end

local function strayInQuotes(text, w)             -- слово стоит внутри кавычек (название): удалением оно не лечится
    local s = lo(text or ''):find(w, 1, true)
    if not s then return false end
    local _, q = text:sub(1, s - 1):gsub('"', '')
    return q % 2 == 1
end

-- Учимся на правке: слово стояло в тексте хелпера (raw), было в исходнике, а ты его убрал -> запоминаем
-- вместе с контекстом исходника. Ослабления нет: ненужное слово удаляется вручную на вкладке "Лишние слова".
function strayLearn(orig, final, raw)
    if not raw or raw == '' or not final or final == '' then return end
    local fin, finStem = {}, {}
    for _, w in ipairs(strayTokens(final)) do fin[w] = true; finStem[w:sub(1, 4)] = true end
    local origSet = {}
    for _, w in ipairs(strayTokens(orig)) do origSet[w] = true end
    local have = strayHave(orig)
    local rawWords, seen, cand, kept, changed = strayTokens(raw), {}, {}, 0, false
    for _, w in ipairs(rawWords) do
        if fin[w] or finStem[w:sub(1, 4)] then kept = kept + 1 end
        if not seen[w] then
            seen[w] = true
            local e = STRAY[w]
            if fin[w] then
                -- слово оставлено: ничего не меняем (лишнее убираешь сам, правило не ослабляем)
            elseif origSet[w] and #w >= 3 and not STRAY_KEEP[w] and not STRAY_FILLER[w]
                and not finStem[w:sub(1, 4)] and not strayInQuotes(raw, w) then
                cand[#cand + 1] = w
            end
        end
    end
    -- учимся только на небольших правках: убрали 1-2 слова, остальной текст сохранён
    -- автозапись лишних слов отключена: кандидаты находит вкладка "Предложения" (auto.lua)
    if false and #cand >= 1 and #cand <= 2 and kept >= 0.7 * #rawWords then
        for _, w in ipairs(cand) do
            local ctx = strayCtxList(orig, w)
            local e = STRAY[w]
            if e then
                e.n = e.n + 1
                e.time = os.time()
                local have2, grouped = {}, false
                for _, st in ipairs(e.ctx) do
                    have2[st] = true
                    if st == ',' then grouped = true end
                end
                if not grouped then                      -- контекст с запятыми собран вручную: не расширяем
                    for _, st in ipairs(ctx) do
                        if not have2[st] then e.ctx[#e.ctx + 1] = st end
                    end
                    while #e.ctx > 10 do table.remove(e.ctx, 1) end
                end
            else
                STRAY[w] = { ctx = ctx, n = 1, time = os.time() }
            end
            changed = true
            strayLogAdd('learn', w)
            say(T('Удаление запомнено: слово "') .. w .. T('" будет убираться в похожих объявлениях.'), 0xFF66FF66)
        end
    end
    if changed then straySave() end
end
-- ===== ЛИШНИЕ СЛОВА (конец) =====


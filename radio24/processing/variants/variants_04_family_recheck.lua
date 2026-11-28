-- radio24/processing/variants/variants_04_family_recheck.lua: часть 4 из 6 файла processing/variants. семья (familyFix) и перепроверка после удаления слов (recheckClean). Общее окружение модулей, см. radio24_helper.lua
-- familyFix: семья - всегда «Семья "Название" ищет дальних родственников», дальше как написал игрок (Мы у дома "N", GPS, [скобки])
function familyFix(text, ad)
    local low = lo(text)
    local fam, key = T('семья'), T('ищет дальних родственников')
    if low:sub(1, #fam) ~= fam or low:find(key, 1, true) then return text, false end
    local head, rest
    local a, b = text:find('^%S+%s+"[^"]+"')
    if a then
        head, rest = text:sub(1, b), trim(text:sub(b + 1))
    else
        local vpos
        for _, v in ipairs({ 'ждет', 'ждёт', 'ждем', 'ждём', 'ищет', 'ищем', 'приглаша', 'набира', 'мы у ', 'gps', '[' }) do
            local p = low:find(T(v), #fam + 2, true)
            if p and (not vpos or p < vpos) then vpos = p end
        end
        if not vpos then return text, false end
        local name = trim(text:sub(#fam + 1, vpos - 1))
        if name == '' or name:find('["%[]') or select(2, name:gsub('%S+', '')) > 5 then return text, false end
        head, rest = text:sub(1, #fam) .. ' "' .. name .. '"', trim(text:sub(vpos))
    end
    local lr = lo(rest)
    local tail
    local mu = lr:find(T('мы у '), 1, true)
    local gp = lr:find('gps', 1, true)
    local br = rest:find('[', 1, true)
    local num = lr:match(T('дом') .. '[\224-\255]*%s*[#\185]?%s*"?(%d+)"?')
    local extra
    if gp then extra = trim(rest:sub(gp)) elseif br then extra = trim(rest:sub(br)) end
    if mu then
        tail = trim(rest:sub(mu))
        if not tail:find('"', 1, true) then
            tail = tail:gsub('(' .. T('дом') .. '[\224-\255]*)%s+[#\185]?(%d+)', '%1 "%2"')
        end
    elseif num then
        tail = T('Мы у дома') .. ' "' .. num .. '"'
        if extra and extra ~= '' then tail = tail .. '. ' .. extra end
    elseif extra and extra ~= '' then
        tail = extra
    else
        local FW = {}
        for _, w in ipairs({ 'ждет', 'ждёт', 'ждем', 'ждём', 'вас', 'всех', 'ищет', 'ищем', 'приглашает', 'приглашаем', 'нас', 'к', 'себе' }) do FW[T(w)] = true end
        local r2 = rest
        while true do
            local tk = r2:match('^(%S+)')
            if tk and FW[(lo(tk):gsub('%p+$', ''))] then r2 = trim(r2:sub(#tk + 1)) else break end
        end
        if r2 ~= '' then tail = r2 end
    end
    if tail then
        tail = trim((tail:gsub('[%s%.,;]+$', '')))
        if tail ~= '' then tail = up(tail:sub(1, 1)) .. tail:sub(2) end
    end
    return head .. ' ' .. key .. ((tail and tail ~= '') and ('. ' .. tail) or ''), true
end

-- recheckClean: после удаления лишних слов результат ПРО прогоняем через разбор ещё раз
-- (название могло не опознаться из-за хвоста: "кс пинивайс ... есть еще много кс и ас"). Возвращает новый текст или nil
function recheckClean(c)
    local oldCtx = CTXHAVE
    local ok, t = pcall(fixText, c)
    CTXHAVE = oldCtx
    if not ok or type(t) ~= 'string' or t == '' or t == c then return nil end
    for _, fn in ipairs({ catPrefFix, andFix, caseFix }) do
        local ok2, r = pcall(fn, t)
        if ok2 and type(r) == 'string' and r ~= '' then t = r end
    end
    if t == c then return nil end
    if lo(c:match('^%S+') or '') ~= lo(t:match('^%S+') or '') then return nil end          -- сделка не должна смениться
    local lc, lt = lo(c), lo(t)
    for _, lab in ipairs(STRAY_LW) do                                                        -- Цена:/Бюджет: сохраняются
        if (lc:find(lab .. ':', 1, true) ~= nil) ~= (lt:find(lab .. ':', 1, true) ~= nil) then return nil end
    end
    local _, q1 = c:gsub('"', '')
    local _, q2 = t:gsub('"', '')
    if q2 < q1 or #t < #c * 0.6 then return nil end                                          -- кавычки/текст не теряем
    return t
end
-- ===== ПОРЯДОК ОБЪЯВЛЕНИЯ / РЕГИСТР / "И" МЕЖДУ НАЗВАНИЯМИ (конец) =====


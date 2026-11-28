-- radio24/processing/brain/st_09_assemble.lua: этап 9 разбора объявления (fixText): Сборка тела. Строки оригинала 1125-1218. Общее окружение модулей.
-- Код этапа не менялся. Состояние разбора передаётся через таблицу S: в начале этапа значения берутся из S, в конце записываются обратно.
BRAIN.stage('09_assemble', function(S)
    local info, note, s, toks, op, isEvent, hasVeh, vehAbbr, hasHouse, hasClass = S.info, S.note, S.s, S.toks, S.op, S.isEvent, S.hasVeh, S.vehAbbr, S.hasHouse, S.hasClass
    -- Сборка тела
    local parts = {}
    for _, tk in ipairs(toks) do parts[#parts + 1] = tk.pre .. tk.core .. tk.post end
    local body = table.concat(parts, ' ')
    body = body:gsub('%s+', ' ')
    body = body:gsub('^[%s%.,;:!%?]+', '')
    body = body:gsub('[%s%.,;:!%?]+$', '')
    body = normCommasCats(body)
    body = body:gsub('(%S+) %[(%d+)%]', function(w, n)         -- Особняк [1711] / VIP-Особняк [1711] -> Особняк с номером "1711"
        local w2 = w:gsub('^[Vv][Ii][Pp]%-', '')
        local lw = lo((w2:gsub('[%.,;:!%?]+$', '')))
        if lw == T('дворец') or lw == T('особняк') or lw == T('дом') then return w2 .. ' ' .. T('с номером') .. ' "' .. n .. '"' end
    end)
    body = body:gsub('(%S+) ("%d+")', function(w, n)       -- Дворец "1687" -> Дворец с номером "1687"
        local lw = lo((w:gsub('[%.,;:!%?]+$', '')))
        if lw == T('дворец') or lw == T('особняк') or lw == T('дом') then return w .. ' ' .. T('с номером') .. ' ' .. n end
    end)
    while body:find(T('а/м') .. ' ' .. T('а/м'), 1, true) do
        body = body:gsub(T('а/м') .. ' ' .. T('а/м'), T('а/м'))
    end

    if (op == 'sell' or op == 'rent' or op == 'buy') and placeToEnd then   -- место - последним перед ценой/бюджетом (п.2.7)
        local okp, nb = pcall(placeToEnd, body)
        if okp and nb and nb ~= '' then body = nb end
    end
    local lowBody = lo(body)
    local hasLoc = lowBody:find(T('г. '), 1, true) ~= nil or lowBody:find(T('д. '), 1, true) ~= nil
    for _, w in ipairs(LOCLIST) do if lowBody:find(w, 1, true) then hasLoc = true end end
    local flatBody = (lowBody:gsub('%-', ' '))                 -- «д.Palomino-Creek»: место указано и без пробела
    for _, p in ipairs(PLACES or {}) do
        if not p.plain then
            local name = (lo(T((p.canon:gsub('^%S+%s+', '')))):gsub('%-', ' '))
            if flatBody:find(name, 1, true) then hasLoc = true end
        end
    end
    local hasBizType = false
    for _, w in ipairs(BIZTYPES) do if lowBody:find(w, 1, true) then hasBizType = true end end
    if not hasVeh and body:find('"', 1, true) then hasBizType = true end
    local bizWord = false
    if not hasHouse then
        bizWord = (lowBody:find(T('бизнес'), 1, true) or lowBody:find(T('п/п'), 1, true)) ~= nil
    end

    -- Правила по типу имущества
    if op == 'buy' then
        if hasHouse and not hasClass and not hasLoc then
            body = body:gsub(T('дом'), T('дом любого класса в любой точке штата'), 1)
        elseif hasHouse and hasClass and not hasLoc then
            body = body .. T(' в любой точке штата')
        elseif bizWord and not hasLoc and not hasBizType then
            body = T('любое п/п в любой точке штата')
        elseif vehAbbr and not hasVeh and not hasHouse and body:find(T('а/м'), 1, true) then
            body = body:gsub(T('а/м'), T('а/м любой марки'), 1)
        end
    elseif op == 'sell' or op == 'rent' then
        if bizWord then body = body:gsub(T('бизнес'), T('п/п'), 1) end
        local rj = info.reject
        if hasHouse then
            if not hasClass then rj[#rj + 1] = T('Не указан класс дома') end
            if not hasLoc then rj[#rj + 1] = T('Не указано местоположение дома') end
        end
        if bizWord then
            if not hasBizType then rj[#rj + 1] = T('Не указан тип предприятия') end
            if not hasLoc then rj[#rj + 1] = T('Не указано местоположение предприятия') end
        end
        if vehAbbr and not hasVeh then rj[#rj + 1] = T('Не указана марка транспортного средства') end
    end
    for _, a in ipairs(ABBR) do body = body:gsub(a .. ' ' .. a, a) end
    for _, a in ipairs({ T('а/с'), T('к/с') }) do               -- а/с "X" и а/с "Y" -> а/с "X" и "Y"
        body = body:gsub('%s' .. T('и') .. '%s' .. a .. '%s"', ' ' .. T('и') .. ' "')
    end
    body = body:gsub(T('г%. г%.'), T('г.')):gsub(T('д%. д%.'), T('д.'))

    -- Разные типы имущества (п.2.15)
    local lb = lo(body)
    local kinds, kn = {}, 0
    local function kind(k) if not kinds[k] then kinds[k] = true; kn = kn + 1 end end
    if vehAbbr or hasVeh then kind('transport') end
    if hasHouse then kind('house') end
    if lb:find(T('п/п'), 1, true) or bizWord then kind('biz') end
    if lb:find(T('а/с'), 1, true) then kind('acc') end
    if lb:find(T('к/с'), 1, true) then kind('cloth') end
    if lb:find(T('с/к'), 1, true) then kind('sim') end
    if lb:find(T('н/з'), 1, true) and not kinds.transport then kind('plate') end
    if kn > 1 and op ~= 'swap' and not isEvent then
        info.reject[#info.reject + 1] = T('В одном объявлении указаны разные типы имущества')
        note(T('разные типы имущества в одном объявлении (п.2.15)'))
    end

    -- Обмен на «любой а/м»: добавляем «с доплатой»
    if op == 'swap' and hasVeh and lo(body):find(T('на любой') .. '%s+%S+$') and not lo(body):find(T('доплат'), 1, true) then
        body = body .. T(' с доплатой')
    end

    -- Обмен номерного знака (п.3.2, пример №9): «на другой н/з с доплатой»
    if op == 'swap' and body:find(T('н/з'), 1, true) and not (' ' .. lo(body) .. ' '):find(T(' на '), 1, true) then
        body = body .. T(' на другой н/з с доплатой')
    end
    S.info, S.note, S.s, S.toks, S.op, S.isEvent, S.hasVeh, S.vehAbbr, S.hasHouse, S.hasClass, S.parts, S.body, S.lowBody, S.hasLoc, S.flatBody, S.hasBizType, S.bizWord, S.lb, S.kinds, S.kn, S.kind = info, note, s, toks, op, isEvent, hasVeh, vehAbbr, hasHouse, hasClass, parts, body, lowBody, hasLoc, flatBody, hasBizType, bizWord, lb, kinds, kn, kind
end)

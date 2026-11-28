-- radio24/processing/brain/st_10_final.lua: этап 10 разбора объявления (fixText): Цена. Строки оригинала 1219-1303. Общее окружение модулей.
-- Код этапа не менялся. Состояние разбора передаётся через таблицу S: в начале этапа значения берутся из S, в конце записываются обратно.
BRAIN.stage('10_final', function(S)
    local info, note, s, lowSrc, letters, gpsTxt, crimeKind, qty, unitPrice, price, priceMult, torg, out, op, isEvent, hasHouse, hasClass, hasChai, body, hasLoc, lb, src, opts = S.info, S.note, S.s, S.lowSrc, S.letters, S.gpsTxt, S.crimeKind, S.qty, S.unitPrice, S.price, S.priceMult, S.torg, S.out, S.op, S.isEvent, S.hasHouse, S.hasClass, S.hasChai, S.body, S.hasLoc, S.lb, S.src, S.opts
    -- Цена
    do
        local pm = '[' .. T('Премиум') .. ']'
        local pe = pm:gsub('%p', '%%%0')
        while body:find(pe .. ' ' .. pe) do body = body:gsub(pe .. ' ' .. pe, pm) end
    end
    if price and (price < cfg.minPrice or (price > cfg.maxPrice and not body:find(T('[Премиум]'), 1, true))) then
        note(T('цена вне разумного -> договорная/свободный (п.2.21)'))
        price = nil
    end
    if price and hasChai and priceMult and priceMult > 1 then
        note(T('проверь: число с "к" - это цена или количество чая?'))
    end

    -- GPS добавляется в самом конце текста (после цены), см. ниже
    local text
    if op then
        text = OPWORD[op] .. (body ~= '' and (' ' .. body) or '')
        if op == 'swap' then
            if price then note(T('обмен: цена не пишется, при необходимости добавь "с доплатой"')) end
        else
            local label = (op == 'buy') and T('Бюджет') or T('Цена')
            local val
            if unitPrice and not opts.dogovor then
                val = money(unitPrice) .. T(' за ') .. KB.perWord(crimeKind, qty)
            elseif price and (opts.forcePrice or not torg) and not opts.dogovor then
                val = money(price)
            else
                val = (op == 'buy') and T('свободный') or T('договорная')
            end
            text = text .. '. ' .. label .. ': ' .. val
        end
    else
        text = body
        if text ~= '' then text = up(text:sub(1, 1)) .. text:sub(2) end
        if not isEvent then
            note(T('тип сделки не определён, цена не добавлена - проверь вручную'))
            if lowSrc:find('^%[') or lowSrc:find(T('семь'), 1, true) or lowSrc:find(T('мы у '), 1, true)
                or lowSrc:find(T('приглаша'), 1, true) or lowSrc:find(T('организаци'), 1, true) then
                info.org = true
                note(T('похоже на рекламу предприятия/семьи, а не куплю-продажу: нужен контракт (п.2.16) - проверь вручную'))
            end
        end
    end

    if op and op ~= 'swap' and not lo(text):find(T('цена') .. ':', 1, true) and not lo(text):find(T('бюджет') .. ':', 1, true) then
        text = text .. '. ' .. ((op == 'buy') and (T('Бюджет') .. ': ' .. T('свободный')) or (T('Цена') .. ': ' .. T('договорная')))   -- цены нет совсем: договорная / свободный
    end
    if gpsTxt then text = (text ~= '' and (text .. '. ') or '') .. gpsTxt end   -- GPS - в самом конце, перед ним точка
    for _, lb in ipairs({ T('Цена'), T('Бюджет') }) do          -- «Цена: X. Цена: X» -> один раз
        text = text:gsub('[,%.]?%s*' .. lb .. ': .-%.%s*(' .. lb .. ': )', '. %1')
    end
    text = text:gsub('%s+([,%.!%?:;])', '%1')
    text = text:gsub('([,;:!%?])([^%s%d%p])', '%1 %2')
    text = text:gsub('[%s%.]+$', '')      -- точку в конце ставит сам сервер

    for _, w in ipairs(WARN) do
        if lowSrc:find(w[1], 1, true) then note(T('ЗАПРЕЩЕНО/проверь: ') .. w[2]) end
    end
    text = trim((text:gsub('%s+', ' ')))                          -- двойных пробелов не бывает
    if #text > cfg.maxLength then
        note(T('длиннее ') .. cfg.maxLength .. T(' символов'))
    end

    -- Дом: «класса 737 3гаражом» -> «класса с номером "737" 3х гаражом»
    do
        local klass, gar = T('класса'), T('гараж')
        text = text:gsub('(' .. klass .. ') (%d+) (%d)(' .. gar .. ')', '%1 %2 %3' .. T('х') .. ' %4')
        text = text:gsub('(' .. klass .. ') (%d+) (%d' .. T('х') .. ' ' .. gar .. ')', '%1 ' .. T('с номером') .. ' "%2" %3')
        -- номер в кавычках после класса (в т.ч. слитно "737"3х): «класса "737" 3гаражом» -> «класса с номером "737" 3х гаражом»
        text = text:gsub('(' .. klass .. ') ("%d+")%s*(%d)' .. T('х') .. '?%s*(' .. gar .. ')', function(k, n, g, gw)
            return k .. ' ' .. T('с номером') .. ' ' .. n .. ' ' .. g .. T('х') .. ' ' .. gw
        end)
        text = text:gsub('(' .. klass .. ') ("%d+")', '%1 ' .. T('с номером') .. ' %2')
    end
    -- Сим-карта (ПРО): цифры номера -> буквы. Только номер в кавычках сразу после «с/к»
    text = text:gsub('(' .. T('с/к') .. ' ")([%d%-]+)(")', function(head, num, tail)
        if select(2, num:gsub('%d', '')) < 3 then return nil end
        local letters, map, n = 'XYZABCDEFG', {}, 0
        local out = num:gsub('%d', function(d)
            if not map[d] then n = n + 1; map[d] = letters:sub(n, n) end
            return map[d]
        end)
        note(T('номер сим-карты: цифры заменены буквами'))
        return head .. out .. tail
    end)

    if text == (trim(stripColors(src)):gsub('[%s%.]+$', '')) then note(T('объявление составлено верно, правок не нужно')) end
    info.op, info.price, info.torg, info.hasHouse, info.hasClass, info.hasLoc =
        op, price, torg, hasHouse, hasClass, hasLoc
    S.info, S.note, S.s, S.lowSrc, S.letters, S.gpsTxt, S.crimeKind, S.qty, S.unitPrice, S.price, S.priceMult, S.torg, S.out, S.op, S.isEvent, S.hasHouse, S.hasClass, S.hasChai, S.body, S.hasLoc, S.lb, S.text, S.src, S.opts = info, note, s, lowSrc, letters, gpsTxt, crimeKind, qty, unitPrice, price, priceMult, torg, out, op, isEvent, hasHouse, hasClass, hasChai, body, hasLoc, lb, text, src, opts
end)

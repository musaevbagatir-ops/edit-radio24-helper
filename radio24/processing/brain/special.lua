-- radio24/processing/brain/special.lua: спецразбор: купон (buildCoupon) и сим-карта (simPattern). Общее окружение модулей.
-- Купон (п.3.6): слово «купон» + название бонуса в кавычках
function buildCoupon(low)
    if not low:find(T('купон'), 1, true) then return nil end
    local l = ' ' .. low:gsub('[%.,;!]', ' ') .. ' '
    local X = '[x' .. T('х') .. ']'
    local lp, xs = ' ' .. low .. ' ', {}
    for num in lp:gmatch('%s' .. X .. '%s?(%d[%d%.,]*)') do
        num = num:gsub('[%.,]+$', ''):gsub(',', '.')
        xs[#xs + 1] = num
    end
    local mult = xs[1] or l:match('%s(%d+)%s?' .. X .. '%s')
    local hrs = l:match('(%d+)%s?' .. T('ч') .. '%s') or l:match('(%d+)%s?' .. T('час'))
    local pct = l:match('(%d+)%s?%%')
    -- «купон на тс #25» без слова «скидка»: если назван т/с или а/с, число 15/25 тоже считаем скидкой
    local tgtWord = false
    for _, w in ipairs({ ' тс ', ' т/с ', 'транспорт', ' ас ', ' а/с ', 'аксесс' }) do
        if l:find(T(w), 1, true) then tgtWord = true; break end
    end
    if not pct and (tgtWord or low:find(T('скидк'), 1, true) or low:find(T('скидоч'), 1, true)) then   -- «Скидка на транспорт 25» без знака %
        for st, num, en in low:gmatch('()(%d+)()') do
            local bef, aft = low:sub(st - 1, st - 1), low:sub(en, en)
            if (num == '15' or num == '25') and not bef:match('[%.,%d]') and not aft:match('[%.,]%d') then pct = num; break end
        end
    end
    local function has(...)
        for _, w in ipairs({ ... }) do if l:find(T(w), 1, true) then return true end end
        return false
    end
    local X2, notes, name = T('Х'), {}, nil
    if pct or has('скидк', 'скидоч') then
        local tgt
        if has(' тс ', ' т/с ', 'транспорт', 'машин', 'авто') then tgt = T('т/с')
        elseif has(' ас ', ' а/с ', 'аксесс') then tgt = T('а/с') end
        if tgt then
            if not pct then
                pct = '15'
                if tgt == T('т/с') then notes[#notes + 1] = T('купон на т/с: процент не указан - проверь (15% или 25%)') end
            end
            -- в списке названий: «т/с 25» (без %), но «т/с 15%» и «а/с 15%»
            name = T('Скидочный купон на покупку ') .. tgt .. ' ' .. pct .. (pct == '25' and '' or '%')
        end
    end
    if not name then
        local m = mult or '2'
        local function needM()
            if not mult then notes[#notes + 1] = T('купон: множитель не указан, поставил Х2 - проверь') end
        end
        if has('стрельб', ' тир ') then
            name = T('Купон на прокачку навыков стрельбы')
        elseif has(' зп ', 'зарплат', 'зарпл') then
            needM()
            name = (has('фракц') and T('Зарплата во фракциях ') or T('Зарплата ')) .. X2 .. m .. T(' на ') .. (hrs or xs[2] or '3') .. T('ч')
        elseif has('опыт') then
            needM()
            name = T('Игровой опыт ') .. X2 .. m .. T(' на ') .. (hrs or '6') .. T('ч')
        elseif has('навык', 'скилл', 'работ', 'прокач') then
            needM()
            name = T('Купон на прокачку навыков работы х') .. m
        end
    end
    if not name then return nil end
    return name, notes
end

-- Сим-карта (п.3.6): число -> формат X-Y-Z (до 3 разных цифр) или с A-B-C (4-6 разных)
function simPattern(d)
    local map, nxt, letters, seq = {}, 0, { 'X', 'Y', 'Z', 'A', 'B', 'C' }, {}
    for ch in d:gmatch('%d') do
        if not map[ch] then nxt = nxt + 1; map[ch] = letters[nxt] or 'C' end
        seq[#seq + 1] = map[ch]
    end
    local s = table.concat(seq)
    return s:sub(1, 2) .. '-' .. s:sub(3, 4) .. '-' .. s:sub(5, 6)
end

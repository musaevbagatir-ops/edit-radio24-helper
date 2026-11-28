-- radio24/processing/brain/text_utils.lua: вспомогательные функции мозга: запятые и повтор категории (normCommasCats), токенизатор (tokenize). Общее окружение модулей.
-- Запятые и повтор категории (а/с "A" и "B" вместо а/с "A" и а/с "B")
local CATABBR = { 'а/м', 'м/ц', 'в/т', 'л/т', 'а/с', 'к/с', 'н/з', 'с/к', 'п/п', 'б/з' }
function catIs(w)
    w = lo(w)
    for _, a in ipairs(CATABBR) do if w == T(a) then return true end end
    return (VEHABBR and VEHABBR[w]) and true or false
end

function normCommasCats(body)
    local _, nq = body:gsub('"', '')
    if nq % 2 == 1 then return body end
    -- 1) запятые: перед новой операцией (куплю/продам...) - точка, цифры 1,5 - не трогаем, остальные пропускаем
    local o, inQ, br = {}, false, 0
    for i = 1, #body do
        local ch = body:sub(i, i)
        if ch == '"' then inQ = not inQ
        elseif not inQ and ch == '[' then br = br + 1
        elseif not inQ and ch == ']' then br = math.max(0, br - 1) end
        if ch == ',' and not inQ and br == 0 then
            local pv, nx = body:sub(i - 1, i - 1), body:sub(i + 1, i + 1)
            if pv:match('%d') and nx:match('%d') then
                o[#o + 1] = ch
            else
                local rest = body:sub(i + 1):match('^%s*(%S+)')
                local w = rest and lo((rest:gsub('[^%w\192-\255]', ''))) or ''
                o[#o + 1] = (w ~= '' and OPS[w]) and '. ' or ' '
            end
        else
            o[#o + 1] = ch
        end
    end
    body = table.concat(o):gsub('%s+', ' ')
    -- 2) повтор категории между перечисляемыми вещами
    local units, cur = {}, ''
    inQ, br = false, 0
    for i = 1, #body do
        local ch = body:sub(i, i)
        if ch == '"' then inQ = not inQ
        elseif not inQ and ch == '[' then br = br + 1
        elseif not inQ and ch == ']' then br = math.max(0, br - 1) end
        if ch == ' ' and not inQ and br == 0 then
            if cur ~= '' then units[#units + 1] = cur end
            cur = ''
        else
            cur = cur .. ch
        end
    end
    if cur ~= '' then units[#units + 1] = cur end
    local res, lastCat, clean = {}, nil, false
    for _, u in ipairs(units) do
        local lw = lo(u)
        local skip = false
        if lw == T('и') and res[#res] and catIs(res[#res]) then
            skip = true                                   -- «а/м и "X"» -> «а/м "X"»
        elseif catIs(u) then
            local pv = res[#res]
            if lastCat and lw == lastCat and clean and pv then
                if lo(pv) == T('марки') or lo(pv) == T('марка') then
                    res[#res] = nil                           -- «а/м марки а/м "X"» -> «а/м "X"» (без лишнего «и»)
                elseif lo(pv) ~= T('и') and not catIs(pv) then res[#res + 1] = T('и') end
                skip = true
            else
                lastCat, clean = lw, true
            end
        elseif lw == T('и') or lw == T('марки') or lw == T('марка') or u:find('^%[') or u:find('^"') then
            -- перечисление продолжается
        else
            clean = false
        end
        if not skip then res[#res + 1] = u end
    end
    body = table.concat(res, ' ')
    body = body:gsub('%s+', ' ')
    body = body:gsub('^[%s%.,;:!%?]+', '')
    body = body:gsub('[%s%.,;:!%?]+$', '')
    return body
end

function tokenize(s)
    local t = {}
    for w in s:gmatch('%S+') do
        local pre, core, post = w:match('^(%p*)(.-)(%p*)$')
        t[#t + 1] = { pre = pre, core = core, post = post }
    end
    return t
end


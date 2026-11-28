-- radio24/processing/variants/variants_06_loadad.lua: часть 6 из 6 файла processing/variants. загрузка объявления (loadAd), очередь отложенных действий, errLog, таймаут, respond. Общее окружение модулей, см. radio24_helper.lua
function loadAd(ad, author)
    S.author = author or ''
    S.original = trim(ad or '')
    local vars, notes, info = buildVariants(S.original)
    S.variants, S.notes, S.info, S.reject = vars, notes, info, info.reject or {}
    for _, h in ipairs(statHints(S.original)) do
        local w = lo(tostring(h.word or ''))
        if not (HINT_STOP[w] or DICT[w] or #w < 4) then
            table.insert(S.reject, 1, h.reason)
            notes[#notes + 1] = T('выучено: слово "') .. h.word .. T('" обычно ведёт к отказу: ') .. h.reason
        end
    end
    S.blocked = false
    for _, n in ipairs(notes) do
        if n:find(T('ЗАПРЕЩЕНО'), 1, true) then S.blocked = true end
    end
    if okUi then
        setBuf(srcBuf, S.original)
        setBuf(editBuf, vars[1] and vars[1].text or '')
        setBuf(rejBuf, S.reject[1] or '')
        setBuf(admBuf, S.reject[1] or ADMIN_PRESETS[1])
    end
end

-- Отложенные действия: общая очередь, которую разбирает цикл main(). Отдельные lua_thread на каждый вызов не создаём:
-- спящие потоки в момент выгрузки скрипта ломают очистку в MoonLoader (падение lua51.dll).
LATER_Q = LATER_Q or {}

-- Журнал ошибок: пишется сразу на диск (переживает вылет игры). Файл: radio24\config\processing\radio24_errors.txt
function errLog(where, err)
    S.lastErr = tostring(where) .. ': ' .. tostring(err)
    pcall(function()
        local f = io.open(cfgPath('radio24_errors.txt'), 'ab')
        if not f then return end
        f:write(os.date('%d.%m %H:%M:%S '), u8(S.lastErr), ' | screen=', tostring(S.screen), ' stage=', tostring(S.stage), '\n')
        f:close()
    end)
end
function later(ms, fn)
    LATER_Q[#LATER_Q + 1] = { at = os.clock() + (ms or 0) / 1000, fn = fn }
end

function laterPump()
    if #LATER_Q == 0 then return end
    local now, due, rest = os.clock(), {}, {}
    for _, it in ipairs(LATER_Q) do
        if it.at <= now then due[#due + 1] = it else rest[#rest + 1] = it end
    end
    LATER_Q = rest
    for _, it in ipairs(due) do
        local ok, e = pcall(it.fn)
        if not ok then errLog('later', e) end
    end
end

-- если сервер не прислал нужное окно - не висим молча
function armTimeout()
    local token = S.stageAt
    later(9000, function()
        if S.stage and S.stageAt == token then
            S.stage = nil
            setScreen('wait', T('Сервер не ответил на действие. Открой список заново и проверь объявление.'))
            say(T('Сервер не прислал нужное окно, действие остановлено. Проверь объявление в списке.'), 0xFFFF6666)
        end
    end)
end

function respond(id, button, item, input)
    sampSendDialogResponse(id, button, item, input or '')
end

-- radio24/core/hooks/hooks_02_confirm_send.lua: часть 2 из 2 файла core/hooks. хуки SAMP с защитой от ошибок. Строки оригинала 2819-3078. Общее окружение модулей, см. radio24_helper.lua
-- Все части работают в общем окружении модулей, порядок частей задан в ORDER загрузчика radio24_helper.lua.
---------------------------------------------------------------------
-- Самоочистка radio24_confirm.txt
--   запись, у которой подтверждение пришло с опозданием, помечается "| ok=<время>"
--   и удаляется через CDX_CLEAN_SEC (5 минут); всего в файле не больше CDX_KEEP записей
---------------------------------------------------------------------
function cdxRead()
    local f = io.open(cfgPath('radio24_confirm.txt'), 'rb')
    if not f then return nil end
    local s = f:read('*a')
    f:close()
    return s
end

function cdxEntries(s)
    local entries, cur = {}, nil
    for line in (s .. '\n'):gmatch('(.-)\r?\n') do
        if line:sub(1, 4) == '=== ' then
            cur = { head = line, body = {} }
            entries[#entries + 1] = cur
        elseif cur then
            cur.body[#cur.body + 1] = line
        end
    end
    if cur and s:sub(-1) == '\n' and cur.body[#cur.body] == '' then table.remove(cur.body) end
    return entries
end

function cdxSave(entries)
    local f = io.open(cfgPath('radio24_confirm.txt'), 'wb')
    if not f then return false end
    for _, e in ipairs(entries) do
        f:write(e.head, '\n')
        for _, l in ipairs(e.body) do f:write(l, '\n') end
    end
    f:close()
    return true
end

function cdxCleanup()
    local s = cdxRead()
    if not s or s == '' then return end
    local keep, now, changed = {}, os.time(), false
    for _, e in ipairs(cdxEntries(s)) do
        local okAt = tonumber(e.head:match('| ok=(%d+)'))
        if okAt and now - okAt >= CDX_CLEAN_SEC then
            changed = true
        else
            keep[#keep + 1] = e
        end
    end
    while #keep > CDX_KEEP do
        table.remove(keep, 1)
        changed = true
    end
    if changed then cdxSave(keep) end
end

-- подтверждение пришло с опозданием: помечаем запись в файле (удалится через 5 минут)
function cdxLate(rec)
    if not rec.uid then return end
    local s = cdxRead()
    if not s then return end
    local entries = cdxEntries(s)
    for _, e in ipairs(entries) do
        if e.head:find('id=' .. rec.uid, 1, true) and not e.head:find('| ok=', 1, true) then
            e.head = e.head .. u8(string.format(T(' | ПОДТВЕРЖДЕНО ПОЗЖЕ: через %d с (%s), запись удалится через 5 мин'),
                math.floor(os.clock() - (rec.at or os.clock())), os.date('%H:%M:%S'))) .. ' | ok=' .. os.time()
            cdxSave(entries)
            return
        end
    end
end

function cdxTick()
    pcall(cdxCleanup)
    later(60000, cdxTick)
end

-- Отправка исправленного объявления: пункт "Отправить" жмём не мгновенно, ждём подтверждения сервера
function sendEdited(id, idx, nick, tries)
    local at = os.clock()
    S.sending = { nick = nick, tries = tries, at = at }
    later(SEND_DELAY, function() respond(id, 1, idx, '') end)
    later(SEND_DELAY + 6000, function()
        if S.sending and S.sending.at == at then
            S.sending = nil
            edMark(false)
            say(T('Сервер не подтвердил отправку исправленного объявления. Проверь его в списке /edit.'), 0xFFFF6666)
            setScreen('wait', T('Нет подтверждения отправки от сервера. Открой список и проверь объявление.'))
        end
    end)
end

function onShowDialogImpl(id, style, title, b1, b2, text)
    S.hookCount = S.hookCount + 1
    S.lastTitle, S.lastStyle = stripColors(title or ''), style
    if spy then logDialog(id, style, title, b1, b2, text) end
    trace(string.format('[DIALOG] id=%d style=%d stage=%s title=%s | %s', id, style, tostring(S.stage), title or '', text or ''))
    if not cfg.enabled or not okUi then return end
    if S.stage and os.clock() - S.stageAt > 10 then S.stage = nil end

    -- серверная дата (статистика персонажа) и окно /editstats
    do
        local plain = lo(stripColors(text or ''))
        local d = plain:match(T('текущая дата:%s*(%d+%.%d+%.%d+)'))
        if d then
            edDay(d, nil)
            if S.silentStats then
                S.silentStats = false
                later(150, function() respond(id, 0, -1, '') end)
                return false
            end
        end
        local cnt = plain:match(T('отредактировано объявлений за сегодня:%s*(%d+)'))
        if cnt then
            ED.srv = tonumber(cnt)
            edDay(nil, ED.srv)
            if S.edsAuto and os.clock() - S.edsAuto < 8 then
                S.edsAuto = nil          -- обновление запросила сама вкладка: окно не открываем
            else
                win[0] = true; S.wantTab = 'estats'
            end
            later(150, function() respond(id, 1, -1, '') end)
            return false
        end
    end

    local isList = (style == 2 or style == 4 or style == 5)
    local menu = isList and parseMenu(style, text) or nil

    -- 2) меню конкретного объявления
    if menu then
        local nick = stripColors(title or '')
        -- сервер вернул меню вместо отправки: значит отправка не прошла, повторяем
        if S.sending and S.sending.nick == nick and menu.opts.send ~= nil and S.stage ~= 'afterEdit'
            and os.clock() - S.sending.at < 12 then
            if S.sending.tries < 3 then
                if TUNE_SLOW then TUNE_SLOW('send') end
                say(T('Сервер вернул меню вместо отправки, повторяю отправку...'), 0xFFFFAA33)
                sendEdited(id, menu.opts.send, nick, S.sending.tries + 1)
            else
                S.sending = nil
                edMark(false)
                S.menu = { id = id, opts = menu.opts, nick = nick }
                loadAd(menu.ad, nick)
                win[0] = true
                S.wantTab = 'ads'
                setScreen('actions')
                say(T('Не удалось отправить исправленное объявление (3 попытки). Нажми "Отправить как есть" вручную.'), 0xFFFF6666)
            end
            return false
        end
        -- после "Редактировать -> Принять" сервер вернул меню: сразу жмём "Отправить"
        if S.stage == 'afterEdit' and menu.opts.send ~= nil
            and (S.stageNick == '' or S.stageNick == nick) then
            local shown, want = norm(menu.ad or ''), norm(S.pendingText or '')
            local applied = want == '' or shown:find(want, 1, true) ~= nil or want:find(shown, 1, true) ~= nil
            if cfg.verifyEdit and not applied then
                -- сервер вернул меню со СТАРЫМ текстом: правка не применилась, исходник НЕ отправляем
                S.stage = nil
                S.menu = { id = id, opts = menu.opts, nick = nick }
                loadAd(menu.ad, nick)
                win[0] = true
                S.wantTab = 'ads'
                setScreen('actions')
                say(T('Правка не применилась (в меню прежний текст). Ничего не отправлено - проверь окно.'), 0xFFFF6666)
                say(T('В меню: ') .. (menu.ad or ''), 0xFF999999)
                say(T('Ожидалось: ') .. (S.pendingText or ''), 0xFF999999)
                return false
            end
            S.stage = nil
            edAdd(nick, S.editOrig, S.pendingText)
            sendEdited(id, menu.opts.send, nick, 1)
            setScreen('wait', T('Объявление исправлено, отправляю...'))
            return false
        end
        if S.stage == 'editing' then
            if TUNE_SLOW then TUNE_SLOW('edit') end
            say(T('Сервер вернул меню вместо окна ввода: выбранный пункт не открыл редактирование. '
                .. 'Ничего не отправлено. Проверь в настройках "Текст объявления в меню - пункт списка".'), 0xFFFF6666)
        end
        S.stage = nil
        S.autoSent = false
        S.menuSeq = (S.menuSeq or 0) + 1                 -- номер показа меню: отсекает устаревшие таймеры автоотправки
        local seq = S.menuSeq
        S.menu = { id = id, opts = menu.opts, nick = nick }
        loadAd(menu.ad, nick)
        local orig0 = S.original
        win[0] = true
        S.wantTab = 'ads'
        setScreen('actions')
        local mem = S.variants[1] and S.variants[1].mem and S.variants[1].text or nil
        if cfg.autoSendMemory and mem and mem ~= '' and not S.blocked and not S.stage and not S.sending
            and os.clock() - (S.autoAt or -100) > (AUTO_COOLDOWN or 2.5) then
            later(AUTO_DELAY or 900, function()
                local okc, err = pcall(function()
                    -- к моменту срабатывания меню должно быть тем же самым (не заменено списком/другим объявлением)
                    if S.menuSeq ~= seq or not S.menu or S.menu.id ~= id or S.screen ~= 'actions' then return end
                    if S.stage or S.sending or S.original ~= orig0 then return end
                    if not S.variants[1] or S.variants[1].text ~= mem then return end
                    S.autoAt = os.clock()
                    errLog('autoSend старт', mem:sub(1, 60))
                    S.autoSent = true
                    if not menuAct('edit', mem, true) then S.autoSent = false end
                end)
                if not okc then
                    S.autoSent = false
                    errLog('autoSend', err)
                end
            end)
        end
        return false
    end

    -- 1) список объявлений
    if isList and lo(stripColors(title or '')):find(cfg.dialogTitle, 1, true) then
        pcall(cdxOnList, style, text)
        if os.clock() - S.closing < 2 then          -- окно только что закрыли: выходим из /edit совсем
            later(150, function() respond(id, 0, -1, '') end)
            return false
        end
        if S.stage == 'editing' then
            -- вместо окна ввода пришёл список: нажат не пункт "Редактировать", объявление могло уйти как есть
            S.stage = nil
            say(T('Вместо окна ввода сервер вернул список: нажат пункт №') .. tostring(S.lastItem)
                .. T(' - это не "Редактировать". Объявление могло уйти как есть, правка не применена.'), 0xFFFF6666)
        end
        if S.stage == 'afterEdit' then
            edAdd(S.stageNick, S.editOrig, S.pendingText)
            -- сервер сам отправляет исправленное объявление (в чат оно приходит с задержкой), ждём подтверждения
            S.confirm = S.confirm or {}
            local rec = { e = ED.list[#ED.list], nick = S.stageNick }
            rec.trace = {}
            for _, m in ipairs(S.trace or {}) do rec.trace[#rec.trace + 1] = m end
            S.confirm[#S.confirm + 1] = rec
            rec.at, rec.auto = os.clock(), S.autoSent == true
            pcall(cdxInit, rec, style, text)
            later(CONFIRM_WAIT, function()
                for i, c in ipairs(S.confirm) do
                    if c == rec then
                        table.remove(S.confirm, i)
                        if rec.e then rec.e.ok = false; edSave() end
                        S.late = S.late or {}
                        S.late[#S.late + 1] = rec            -- если подтверждение придёт позже, отметим его
                        confirmDump(rec)
                        local okS, why, on = false, '', nil
                        pcall(function() okS, why = cdxScriptOk(rec); on = cdxOnline(rec.nick) end)
                        if okS and on == -1 then
                            say(T('Объявление ') .. rec.nick .. T(' не отправилось сервером: игрок вышел из игры.'), 0xFFFFAA33)
                        elseif not okS then
                            say(T('Объявление ') .. rec.nick .. T(' не отправилось из-за скрипта: ') .. tostring(why)
                                .. T('. Лог: radio24/config/core/radio24_confirm.txt'), 0xFFFF6666)
                        else
                            say(T('Нет подтверждения от сервера за ') .. math.floor(CONFIRM_WAIT / 1000) .. T(' с: ') .. rec.nick
                                .. T(' (игрок в сети, скрипт отработал штатно). Проверь чат и список /edit. Лог: radio24/config/core/radio24_confirm.txt'), 0xFFFF6666)
                        end
                        break
                    end
                end
            end)
        end
        if S.sending then
            S.sending = nil
            edMark(true)
            say(T('Исправленное объявление отправлено.'), 0xFF66FF66)
        end
        S.reopen = 0
        S.menu = nil                                     -- пришёл список: старое меню объявления уже недействительно
        S.menuSeq = (S.menuSeq or 0) + 1
        handleList(id, style, text)
        win[0] = true
        S.wantTab = 'ads'
        setScreen('list')
        return false
    end

    -- 3) окно ввода после "Редактировать" / "Удалить" / "Отправить администрации"
    if S.stage and S.stage ~= 'afterEdit' and (style == 1 or style == 3) then
        local st, t = S.stage, S.pendingText
        if st == 'editing' then
            -- защита: если открылся запрос причины/администрации, это не то окно - отменяем
            local dt = lo(stripColors(text or ''))
            local head = lo(S.original):sub(1, 12)
            if (dt:find(T('причин'), 1, true) or dt:find(T('администрац'), 1, true))
                and not (head ~= '' and dt:find(head, 1, true)) then
                S.stage = nil
                later(150, function() respond(id, 0, -1, '') end)
                say(T('Открылось не окно редактирования (запрос причины). Отменил, ничего не отправлено. '
                    .. 'Проверь настройку "Текст объявления в меню - пункт списка".'), 0xFFFF6666)
                setScreen('wait', T('Не то окно: ничего не отправлено. Проверь настройку нумерации пунктов.'))
                return false
            end
            S.stage = 'afterEdit'
            S.stageAt = os.clock()
            armTimeout()
            setScreen('wait', T('Объявление исправлено, отправляю...'))
        elseif st == 'deleting' then
            S.stage = nil
            say(T('Объявление удалено.'), 0xFF66FF66)
            setScreen('wait', T('Готово: объявление удалено.'))
        else
            S.stage = nil
            say(T('Отправлено администрации.'), 0xFF66FF66)
            setScreen('wait', T('Готово: отправлено администрации.'))
        end
        if st == 'editing' then S.editSent = { at = os.clock(), clock = os.date('%H:%M:%S'), id = id, style = style, title = stripColors(title or ''), shown = stripColors(text or ''), sent = t } end
        later(st == 'editing' and INPUT_DELAY or 200, function() respond(id, 1, -1, t) end)
        return false
    end
    if S.stage then
        -- посторонний диалог (список сотрудников, сообщение сервера и т.п.): не ломаем цепочку,
        -- показываем его как обычно и ждём нужное окно. Пишем в лог, чтобы можно было разобраться.
        if not spy then logDialog(id, style, title, b1, b2, text, true) end
        if id ~= 65535 then
            say(string.format(T('Посторонний диалог пропущен (id=%d style=%d), жду окно сервера.'), id, style), 0xFF999999)
        end
        return nil
    end
end
sampev.onShowDialog = guard('onShowDialog', onShowDialogImpl)

sampev.onSendDialogResponse = guard('onSendDialogResponse', function(id, button, item, input)
    trace(string.format('[ANSWER] id=%s button=%s item=%s input=%s', tostring(id), tostring(button), tostring(item), tostring(input or '')))
    if S.listId and id == S.listId then S.listId, S.items = nil, {} end
end)

sampev.onServerMessage = guard('onServerMessage', function(color, text)
    if S.sending and text and text:find(T('Проверил сотрудник'), 1, true) then
        local me = myNick()
        if me ~= '' and text:find(me, 1, true) then
            S.sending = nil
            edMark(true)
            say(T('Исправленное объявление отправлено (подтверждено сервером).'), 0xFF66FF66)
        end
    end
    if text then msgRemember(text); trace('[CHAT] ' .. text) end
    if text then pcall(cdxChat, text) end
    if text and ((S.confirm and #S.confirm > 0) or (S.late and #S.late > 0)) then
        local plain = nickKey(text)
        if plain:find(nickKey(T('Отправил:')), 1, true) then
            local done = false
            for pi, pool in ipairs({ S.confirm or {}, S.late or {} }) do
                for i = #pool, 1, -1 do
                    local c = pool[i]
                    if pi == 2 and os.clock() - (c.at or 0) > 600 then
                        table.remove(pool, i)                -- слишком старая запись
                    elseif not done then
                        local nk = nickKey(c.nick)
                        if nk ~= '' and plain:find(nk, 1, true) then
                            table.remove(pool, i)
                            if c.e then c.e.ok = true; edSave() end
                            if pi == 2 then pcall(cdxLate, c) end
                            say(pi == 2 and T('Исправленное объявление отправлено (подтверждение пришло с опозданием).')
                                or T('Исправленное объявление отправлено (подтверждено сервером).'), 0xFF66FF66)
                            done = true
                        end
                    end
                end
            end
        end
    end
end)

sampev.onSendCommand = guard('onSendCommand', function(command)
    if not cfg.enabled or not okUi then return end
    local c = lo(command)
    if c == '/edit' or c:find('^/edit%s') then
        S.closing = 0
        win[0] = true
        S.wantTab = 'ads'
    end
end)

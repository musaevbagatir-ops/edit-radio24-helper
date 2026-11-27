-- radio24/hooks.lua: хуки SAMP с защитой от ошибок. Строки оригинала 2819-3078. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- Хуки SAMP (с защитой от ошибок)
---------------------------------------------------------------------
function logDialog(id, style, title, b1, b2, text, quiet)
    pcall(function()
        local f = io.open(DIR .. 'radio24_dialogs.txt', 'ab')
        if not f then return end
        f:write(u8(string.format('id=%d style=%d title=%s | b1=%s | b2=%s\n%s\n-----\n',
            id, style, title or '', b1 or '', b2 or '', text or '')))
        f:close()
    end)
    if not quiet then
        say(string.format('[spy] id=%d style=%d title=%s', id, style, stripColors(title or '')), 0xFF999999)
    end
end

function guard(name, fn)
    return function(...)
        local ok, r = pcall(fn, ...)
        if ok then return r end
        errLog(name, r)
        sampAddChatMessage(T('[Radio24] Ошибка ') .. S.lastErr, 0xFFFF4444)
        return nil
    end
end

-- Подтверждение отправки: ждём сообщение сервера "Отправил: <ник>" (ник сравниваем без регистра, "_" = пробел)
CONFIRM_WAIT = 90000
function nickKey(s)
    s = lo(stripColors(s or '')):gsub('_', ' '):gsub('%s+', ' ')
    return trim(s)
end

-- последние сообщения сервера про объявления (для диагностики, если подтверждения нет)
function msgRemember(text)
    local l = lo(stripColors(text or ''))
    if l:find(T('отправил'), 1, true) or l:find(T('объявл'), 1, true) or l:find(T('проверил'), 1, true)
        or l:find(T('редакт'), 1, true) then
        S.msgLog = S.msgLog or {}
        S.msgLog[#S.msgLog + 1] = os.date('%H:%M:%S ') .. stripColors(text)
        if #S.msgLog > 40 then table.remove(S.msgLog, 1) end
    end
end

-- ТРАССИРОВКА: все диалоги, ответы на них и ВСЕ сообщения чата вокруг отправки (для поиска пропавших объявлений)
function trace(line)
    pcall(function()
        line = os.date('%H:%M:%S ') .. (stripColors(line):gsub('[\r\n]+', ' / ')):sub(1, 600)
        S.trace = S.trace or {}
        S.trace[#S.trace + 1] = line
        if #S.trace > 40 then table.remove(S.trace, 1) end
        for _, rec in ipairs(S.confirm or {}) do
            if rec.trace and #rec.trace < 250 then rec.trace[#rec.trace + 1] = line end
        end
    end)
end

---------------------------------------------------------------------
-- ДИАГНОСТИКА НЕПОДТВЕРЖДЁННЫХ ОБЪЯВЛЕНИЙ (config/radio24_confirm.txt)
--   cdxInit     - снимок в момент, когда сервер вернул список после правки
--   cdxOnList   - каждый новый список /edit: осталось ли объявление в очереди
--   cdxChat     - чат: строки с ником, удаления, другие объявления, проверяющие
--   confirmDump - итоговая запись: вердикт, факты, последний список, трасса
--   cdxLate / cdxCleanup - подтверждённые позже записи удаляются через 5 минут
---------------------------------------------------------------------
CDX_KEEP = 80            -- максимум записей в файле (старые удаляются)
CDX_CLEAN_SEC = 300      -- запись, подтверждённая позже, удаляется через 5 минут
CDX_SEQ = 0

function cdxStr(v, n)
    local s = tostring(v == nil and '' or v)
    s = (s:gsub('[\r\n]+', ' / '))
    if n and #s > n then s = s:sub(1, n) .. '...' end
    return s
end

-- разбор списка "Объявления": ник, VIP, отметка [Проверено]
function cdxParseList(style, text)
    local rows, n = {}, 0
    for line in stripColors(text or ''):gmatch('[^\n]+') do
        n = n + 1
        if not (style == 5 and n == 1) then
            local raw = trim(line)
            local l = lo(raw)
            local rest = (raw:gsub('^%d+[%.%)]%s*', ''))
            rows[#rows + 1] = {
                raw = raw,
                nick = trim((rest:gsub('%[[^%]]*%]', ''))),
                vip = l:find('[vip]', 1, true) ~= nil,
                chk = l:find(T('проверено'), 1, true) ~= nil,
            }
        end
    end
    return rows
end

-- сколько записей с этим ником в списке, сколько из них [Проверено], позиция первой
function cdxStat(rows, nick)
    local st = { total = 0, chk = 0, pos = 0, vip = false }
    local nk = nickKey(nick or '')
    if nk == '' then return st end
    for i, r in ipairs(rows or {}) do
        if nickKey(r.raw):find(nk, 1, true) then
            st.total = st.total + 1
            if r.chk then st.chk = st.chk + 1 end
            if st.pos == 0 then st.pos = i end
            if r.vip then st.vip = true end
        end
    end
    return st
end

-- id игрока, если он в сети; -1 - не в сети; nil - не удалось определить
function cdxOnline(nick)
    local ok, id = pcall(function()
        for i = 0, sampGetMaxPlayerId(false) do
            if sampIsPlayerConnected(i) and sampGetPlayerNickname(i) == nick then return i end
        end
        return -1
    end)
    if not ok then return nil end
    return id
end

-- снимок в момент создания записи ожидания (сервер вернул список после правки)
function cdxInit(rec, style, text)
    CDX_SEQ = CDX_SEQ + 1
    rec.uid = string.format('%d-%03d', os.time(), CDX_SEQ % 1000)
    rec.clock = os.date('%H:%M:%S')
    rec.traceStart = #rec.trace
    rec.list0 = cdxParseList(style, text)
    rec.st0 = cdxStat(rec.list0, rec.nick)
    rec.hist = { { clock = rec.clock, sec = 0, st = rec.st0, n = #rec.list0 } }
    rec.nickMsgs, rec.others, rec.checkers = {}, {}, {}
    rec.online0 = cdxOnline(rec.nick)
    rec.sent = S.editSent
    local d = { vars = {} }
    pcall(function()
        local parts = {}
        for _, n in ipairs(S.notes or {}) do
            if type(n) == 'string' then parts[#parts + 1] = n end
        end
        d.notes = table.concat(parts, '; ')
        for i, v in ipairs(S.variants or {}) do
            if i > 6 then break end
            d.vars[#d.vars + 1] = (v.mem and T('[память] ') or '') .. cdxStr(v.text, 160)
        end
        d.blocked = S.blocked and true or false
    end)
    rec.dbg = d
end

-- каждый новый список /edit: следим, осталось ли объявление в очереди и с какой отметкой
function cdxOnList(style, text)
    local rows = cdxParseList(style, text)
    S.lastList = { clock = os.date('%H:%M:%S'), at = os.clock(), rows = rows }
    for _, rec in ipairs(S.confirm or {}) do
        if rec.hist then
            local st = cdxStat(rows, rec.nick)
            local sec = os.clock() - (rec.at or os.clock())
            local last = rec.hist[#rec.hist]
            rec.seen = { clock = os.date('%H:%M:%S'), sec = sec, st = st, n = #rows }
            if last.st.total ~= st.total or last.st.chk ~= st.chk then
                if #rec.hist < 40 then
                    rec.hist[#rec.hist + 1] = { clock = os.date('%H:%M:%S'), sec = sec, st = st, n = #rows }
                end
            end
        end
    end
end

-- чат: строки с ником, удаление редактором, другие объявления, проверяющие
function cdxChat(text)
    if not S.cdxOn then
        S.cdxOn = true
        later(3000, cdxTick)                       -- запуск периодической самоочистки файла
    end
    if not S.confirm or #S.confirm == 0 then return end
    local plain = stripColors(text)
    local pl = lo(plain)
    local key = nickKey(text)
    local clock = os.date('%H:%M:%S')
    local who = plain:match(T('Отправил:') .. '%s*([%w_%.]+)')
    local chk = plain:match(T('Проверил сотрудник') .. '[^:]*:%s*([%w_%.]+)')
    for _, rec in ipairs(S.confirm) do
        if rec.hist then
            local nk = nickKey(rec.nick)
            local mine = nk ~= '' and key:find(nk, 1, true) ~= nil
            if mine and #rec.nickMsgs < 20 then
                rec.nickMsgs[#rec.nickMsgs + 1] = clock .. ' ' .. cdxStr(plain, 300)
            end
            if mine and pl:find(T('удалил сообщение'), 1, true) then
                rec.deleted = clock .. ' ' .. cdxStr(plain, 300)
            end
            if who and not mine and #rec.others < 15 then
                rec.others[#rec.others + 1] = { clock = clock, nick = who }
            end
            if chk then rec.checkers[chk] = (rec.checkers[chk] or 0) + 1 end
        end
    end
end

-- автоанализ: что именно произошло с объявлением
function cdxVerdict(rec)
    local V = {}
    local function add(s) V[#V + 1] = s end
    local e = rec.e or {}
    local st0 = rec.st0 or { total = 0, chk = 0, pos = 0 }
    local seen = rec.seen
    local vanished, silent = false, false
    if rec.deleted then
        add(T('Объявление УДАЛЕНО редактором: ') .. rec.deleted)
    end
    if #(rec.nickMsgs or {}) == 0 then
        add(T('В чате не было ни одной строки с этим ником после правки: в эфир объявление не выходило.'))
        silent = true
    else
        add(T('В чате были строки с этим ником (см. ФАКТЫ): проверь, нет ли среди них "Отправил:" с другим форматом ника.'))
    end
    if (st0.chk or 0) == 0 then
        add(T('Сразу после правки сервер НЕ пометил объявление [Проверено]: правка могла не примениться.'))
    else
        add(T('Сразу после правки сервер пометил объявление [Проверено]: правка принята.'))
    end
    if not seen then
        add(T('После правки список /edit не открывался, поэтому неизвестно, осталось ли объявление в очереди. Открой /edit до окончания ожидания.'))
    else
        local st = seen.st
        if st.total == 0 then
            vanished = true
            local gone
            for _, h in ipairs(rec.hist) do
                if h.st.total == 0 then gone = h; break end
            end
            add(string.format(T('ОБЪЯВЛЕНИЕ ПРОПАЛО ИЗ ОЧЕРЕДИ /edit (список в %s, через %d с после правки) и в чат не вышло. Убрал его не скрипт: сервер, автор или другой редактор.'),
                gone and gone.clock or seen.clock, math.floor(gone and gone.sec or seen.sec)))
        elseif st.total < (st0.total or 0) then
            vanished = true
            add(string.format(T('Записей с этим ником в очереди стало меньше (%d -> %d): одно объявление пропало без строки в чате. Убрал его не скрипт: сервер, автор или другой редактор.'),
                st0.total, st.total))
        elseif st.chk < (st0.chk or 0) then
            add(T('Отметка [Проверено] исчезла, а объявление осталось в очереди: сервер вернул его на проверку.'))
        elseif st.chk > 0 then
            add(string.format(T('Объявление всё ещё в очереди со статусом [Проверено] (список через %d с): сервер просто не выдал его в эфир за время ожидания.'), math.floor(seen.sec)))
        else
            add(T('Объявление в очереди без отметки [Проверено].'))
        end
    end
    if #(rec.others or {}) > 0 then
        add(string.format(T('За время ожидания сервер выдал других объявлений: %d (очередь работала).'), #rec.others))
    else
        add(T('За время ожидания сервер не выдал ни одного другого объявления.'))
    end
    local me = myNick()
    local ch = {}
    for n in pairs(rec.checkers or {}) do
        if n ~= me then ch[#ch + 1] = n end
    end
    if #ch > 0 then
        table.sort(ch)
        add(T('В чате были проверяющие кроме тебя: ') .. table.concat(ch, ', ') .. T(' - объявление мог взять другой редактор.'))
    end
    local fin, org = e.final or '', e.orig or ''
    local textOk = false
    if rec.sent and rec.sent.sent then
        if norm(rec.sent.sent) ~= norm(fin) then
            add(T('В окно ввода ушёл ДРУГОЙ текст, чем записан в итоге (см. ФАКТЫ).'))
        else
            textOk = true
            add(T('В окно ввода ушёл ровно итоговый текст.'))
        end
        if #org >= 4 and not norm(rec.sent.shown or ''):find(norm(org):sub(1, 12), 1, true) then
            add(T('Окно ввода показывало текст, не похожий на исходник: возможно, открыто другое объявление.'))
        end
    end
    if norm(org) == norm(fin) then
        add(T('Итог совпадает с исходником: объявление ушло через "Редактировать" без изменений.'))
    end
    if (vanished or silent) and textOk and (st0.chk or 0) > 0 then
        add(T('ИТОГ: цепочка скрипта отработала штатно (текст ушёл, сервер пометил [Проверено]). Причина на стороне сервера: проверь текст (запрещённые слова и символы), состояние автора (деньги, бан, мут) и не работал ли с объявлением другой редактор.'))
    end
    return V
end

-- построение записи (все строки в W)
function cdxBuild(rec, W)
    local e = rec.e or {}
    local now = os.clock()
    local waited = math.floor(now - (rec.at or now))
    local function onl(v)
        if v == nil then return T('неизвестно') end
        if v >= 0 then return T('да (id ') .. v .. ')' end
        return T('нет')
    end
    W(T('было: ') .. cdxStr(e.orig))
    W(T('стало: ') .. cdxStr(e.final))
    W('')
    W(T('--- ВЕРДИКТ (автоанализ) ---'))
    for i, v in ipairs(cdxVerdict(rec)) do W(i .. '. ' .. v) end
    W('')
    W(T('--- ФАКТЫ ---'))
    W(string.format(T('правка отправлена: %s, ожидание подтверждения: %d с (лимит %d с), скрипт V%s'),
        rec.clock or '?', waited, math.floor((CONFIRM_WAIT or 0) / 1000), tostring(thisScript().version)))
    local st0 = rec.st0 or {}
    W(string.format(T('автор: VIP=%s, в сети при правке: %s, в сети сейчас: %s'),
        st0.vip and T('да') or T('нет'), onl(rec.online0), onl(cdxOnline(rec.nick))))
    W(string.format(T('записей с этим ником сразу после правки: %d, из них [Проверено]: %d, позиция первой: %d, всего строк в списке: %d'),
        st0.total or 0, st0.chk or 0, st0.pos or 0, rec.list0 and #rec.list0 or 0))
    if rec.seen then
        W(string.format(T('последний список после правки: %s (через %d с): записей %d, [Проверено] %d, всего строк %d'),
            rec.seen.clock, math.floor(rec.seen.sec), rec.seen.st.total, rec.seen.st.chk, rec.seen.n))
    else
        W(T('последний список после правки: не открывался'))
    end
    W(T('изменения списка по нику:'))
    for _, h in ipairs(rec.hist or {}) do
        W(string.format(T('  %s (+%d с): записей=%d, проверено=%d, позиция=%d, строк в списке=%d'),
            h.clock, math.floor(h.sec), h.st.total, h.st.chk, h.st.pos, h.n))
    end
    if rec.sent then
        W(T('окно ввода (id ') .. tostring(rec.sent.id) .. T(') показывало: ') .. cdxStr(rec.sent.shown, 250))
        W(T('в окно ввода отправлено: ') .. cdxStr(rec.sent.sent, 250))
    else
        W(T('окно ввода: данных нет'))
    end
    W(T('строки чата с этим ником после правки: ') .. #rec.nickMsgs)
    for _, m in ipairs(rec.nickMsgs) do W('  ' .. m) end
    W(T('другие объявления, вышедшие за время ожидания: ') .. #rec.others)
    for _, o in ipairs(rec.others) do W('  ' .. o.clock .. ' ' .. o.nick) end
    local chk = {}
    for n, c in pairs(rec.checkers) do chk[#chk + 1] = n .. ' x' .. c end
    table.sort(chk)
    W(T('проверяющие в чате: ') .. (#chk > 0 and table.concat(chk, ', ') or T('нет')))
    local d = rec.dbg or {}
    W(T('что сработало в хелпере: ') .. ((d.notes and d.notes ~= '') and cdxStr(d.notes, 500) or T('(ничего)')))
    W(T('варианты хелпера: ') .. ((d.vars and #d.vars > 0) and '' or T('нет')))
    for i, v in ipairs(d.vars or {}) do W('  ' .. i .. ') ' .. v) end
    W(T('пометка ЗАПРЕЩЕНО у объявления: ') .. (d.blocked and T('да') or T('нет')))
    W(string.format('cfg: autoSendMemory=%s verifyEdit=%s autoRemember=%s learn=%s',
        tostring(cfg.autoSendMemory), tostring(cfg.verifyEdit), tostring(cfg.autoRemember), tostring(cfg.learn)))
    W('')
    W(T('--- ПОСЛЕДНИЙ СПИСОК /edit (') .. (S.lastList and S.lastList.clock or '-') .. ') ---')
    for i, r in ipairs(S.lastList and S.lastList.rows or {}) do
        if i <= 30 then W('  ' .. r.raw) end
    end
    W('')
    W(T('--- ПОСЛЕДНИЕ СООБЩЕНИЯ ЧАТА ---'))
    local ml = S.msgLog or {}
    for i = math.max(1, #ml - 11), #ml do W(ml[i]) end
    W('')
    W(T('--- ТРАССА ДО ПРАВКИ (контекст) ---'))
    local ts = rec.traceStart or 0
    for i = math.max(1, ts - 14), ts do W(rec.trace and rec.trace[i] or '') end
    W(T('--- ТРАССА ПОСЛЕ ПРАВКИ (диалоги, ответы, чат) ---'))
    for i = ts + 1, #(rec.trace or {}) do W(rec.trace[i]) end
    W('')
end

-- запись в radio24_confirm.txt (вызывается по тайм-ауту подтверждения)
function confirmDump(rec)
    pcall(cdxCleanup)
    local out = {}
    local function W(s) out[#out + 1] = s or '' end
    W(string.format(T('=== %s нет подтверждения: ник=%s | автоотправка=%s | id=%s'),
        os.date('%d.%m %H:%M:%S'), rec.nick or '', tostring(rec.auto == true), rec.uid or '-'))
    local ok, err = pcall(cdxBuild, rec, W)
    if not ok then W(T('ОШИБКА ДИАГНОСТИКИ: ') .. tostring(err)) end
    pcall(function()
        local f = io.open(DIR .. 'radio24_confirm.txt', 'ab')
        if not f then return end
        for _, l in ipairs(out) do f:write(u8(l), '\n') end
        f:close()
    end)
end

---------------------------------------------------------------------
-- Самоочистка radio24_confirm.txt
--   запись, у которой подтверждение пришло с опозданием, помечается "| ok=<время>"
--   и удаляется через CDX_CLEAN_SEC (5 минут); всего в файле не больше CDX_KEEP записей
---------------------------------------------------------------------
function cdxRead()
    local f = io.open(DIR .. 'radio24_confirm.txt', 'rb')
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
    local f = io.open(DIR .. 'radio24_confirm.txt', 'wb')
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
            and os.clock() - (S.autoAt or -100) > 2.5 then
            later(900, function()
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
                        say(T('Нет подтверждения от сервера за ') .. math.floor(CONFIRM_WAIT / 1000) .. T(' с: ') .. rec.nick
                            .. T('. Проверь чат и список /edit. Лог: config/radio24_confirm.txt'), 0xFFFF6666)
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

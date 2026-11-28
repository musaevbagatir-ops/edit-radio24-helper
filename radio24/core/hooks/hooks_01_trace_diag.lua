-- radio24/core/hooks/hooks_01_trace_diag.lua: часть 1 из 2 файла core/hooks. хуки SAMP с защитой от ошибок. Строки оригинала 2819-3078. Общее окружение модулей, см. radio24_helper.lua
-- Все части работают в общем окружении модулей, порядок частей задан в ORDER загрузчика radio24_helper.lua.
---------------------------------------------------------------------
-- Хуки SAMP (с защитой от ошибок)
---------------------------------------------------------------------
function logDialog(id, style, title, b1, b2, text, quiet)
    pcall(function()
        local f = io.open(cfgPath('radio24_dialogs.txt'), 'ab')
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
-- ДИАГНОСТИКА НЕПОДТВЕРЖДЁННЫХ ОБЪЯВЛЕНИЙ (radio24/config/core/radio24_confirm.txt)
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

-- отработала ли цепочка скрипта штатно: true или false + причина (для сообщения в чат после тайм-аута)
function cdxScriptOk(rec)
    local st0 = rec.st0 or {}
    local fin = (rec.e or {}).final or ''
    if not (rec.sent and rec.sent.sent) then return false, T('окно ввода не открывалось, текст не ушёл') end
    if norm(rec.sent.sent) ~= norm(fin) then return false, T('в окно ввода ушёл другой текст') end
    if (st0.chk or 0) == 0 then return false, T('сервер не пометил [Проверено], правка могла не примениться') end
    return true
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
    local offNow = cdxOnline(rec.nick) == -1
    if offNow and textOk and (st0.chk or 0) > 0 then
        add(T('ИТОГ: игрок вышел из игры, поэтому сервер не выдал объявление в эфир. Скрипт отработал штатно (текст ушёл, сервер пометил [Проверено]).'))
    elseif (vanished or silent) and textOk and (st0.chk or 0) > 0 then
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
        local f = io.open(cfgPath('radio24_confirm.txt'), 'ab')
        if not f then return end
        for _, l in ipairs(out) do f:write(u8(l), '\n') end
        f:close()
    end)
end

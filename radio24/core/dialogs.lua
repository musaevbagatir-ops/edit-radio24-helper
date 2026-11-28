-- radio24/core/dialogs.lua: разбор диалогов Online RP. Строки оригинала 2677-2818. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- Разбор диалогов Online RP (по скринам)
--   1) "Объявления"  - список ников
--   2) заголовок = ник; строки: текст объявления, 1. Отправить, 2. Редактировать,
--      3. Удалить, 4. Отправить администрации
--   3) окно ввода (стиль 1): текст объявления + поле + Принять/Отмена.
--      Одинаковое для Редактировать, Удалить и Отправить администрации.
---------------------------------------------------------------------
function parseMenu(style, text)
    local opts, adLines = {}, {}
    local rows = 0
    for line in stripColors(text):gmatch('[^\n]+') do
        local l = trim(line)
        local idx = rows
        if style == 5 then idx = rows - 1 end   -- заголовок только в style 5; в style 2/4 строка с текстом объявления - пункт №0
        local rest = lo(l):match('^%d+[%.%)]%s*(.*)$')
        local isOpt = true
        if rest and rest:find(T('администрац'), 1, true) then opts.admin = idx
        elseif rest and rest:find(T('редактировать'), 1, true) then opts.edit = idx
        elseif rest and rest:find(T('удалить'), 1, true) then opts.delete = idx
        elseif rest and rest:find(T('отправить'), 1, true) then opts.send = idx
        else
            isOpt = false
            if l ~= '' then adLines[#adLines + 1] = l end
        end
        rows = rows + 1
    end
    if opts.edit ~= nil and opts.delete ~= nil and opts.send ~= nil then
        return { opts = opts, ad = table.concat(adLines, ' ') }
    end
end

function handleList(id, style, text)
    S.listId = id
    S.listAt = os.clock()
    S.stage = nil
    S.items = {}
    local n = 0
    for line in stripColors(text):gmatch('[^\n]+') do
        n = n + 1
        if not (style == 5 and n == 1) then
            S.items[#S.items + 1] = trim(line)
        end
    end
end

-- Выбор объявления из списка
function pickItem(i)
    local id, line = S.listId, S.items[i]
    if not id or not line then return end
    S.listId, S.items = nil, {}
    setScreen('wait', T('Открываю объявление: ') .. line)
    respond(id, 1, i - 1, '')
end

-- Действие над объявлением: send / edit / delete / admin.
-- Окно-меню держалось открытым, поэтому отвечаем на него только сейчас.
function menuAct(action, text, quiet)
    local m = S.menu
    if not m then
        say(T('Нет открытого объявления: введи /edit и выбери объявление.'), 0xFFFF6666)
        return false
    end
    local item = m.opts[action]
    if item == nil then
        say(T('В меню нет такого пункта.'), 0xFFFF6666)
        return false
    end
    text = trim(((text or ''):gsub('%s+', ' ')))
    if action == 'edit' then text = (text:gsub('[%s%.]+$', '')) end   -- точку добавит сервер
    local msg
    if action == 'edit' then
        if text == '' then say(T('Пустой текст.'), 0xFFFF6666); return false end
        if S.blocked and isAutoText(text) then
            say(T('Отменено: есть пометка ЗАПРЕЩЕНО. Измени текст или удали объявление с причиной.'), 0xFFFF6666)
            return false
        end
        if quiet then
            -- автоотправка из памяти: текст уже запомнен, обучение и запись на диск не нужны
            if S.original ~= '' then pcall(statRecord, S.original, 'edit', '') end
        else
            if cfg.autoRemember and S.original ~= '' then memAdd(S.original, text) end
            pcall(peopleLearn, S.original, text)                    -- имена/фамилии для "Ищу человека по имени"
            pcall(tagsLearn, text)                                  -- новые тэги [XXX] из твоего варианта
            if cfg.learn and S.original ~= '' then strayLearn(S.original, text, S.info and S.info.rawMain) end
            if S.original ~= '' then
                -- learnFrom отключён: новые правила и лишние слова появляются только через вкладку "Предложения" или ручное добавление
                statRecord(S.original, 'edit', '')
            end
        end
        S.stage, S.pendingText = 'editing', text
        S.reopen = 0
        S.editOrig = S.original
        msg = T('Исправляю и отправляю...')
    elseif action == 'delete' then
        if text == '' then say(T('Выбери или впиши причину.'), 0xFFFF6666); return false end
        if #text > 20 then say(T('Причина длиннее 20 символов (лимит сервера): ') .. #text .. T('. Сократи её.'), 0xFFFF6666); return false end
        S.stage, S.pendingText = 'deleting', text
        statRecord(S.original, 'delete', text)
        msg = T('Удаляю объявление...')
    elseif action == 'admin' then
        if text == '' then say(T('Впиши причину для администрации.'), 0xFFFF6666); return false end
        S.stage, S.pendingText = 'admin', text
        statRecord(S.original, 'admin', text)
        msg = T('Отправляю администрации...')
    else
        S.stage = nil
        statRecord(S.original, 'send', '')
        if cfg.autoRemember and S.original ~= '' and not S.blocked then
            memAdd(S.original, (S.original:gsub('[%s%.]+$', '')))   -- отправлено как есть: запоминаем в память
        end
        msg = T('Отправляю как есть...')
    end
    S.stageAt = os.clock()
    S.stageNick = m.nick
    S.lastItem = item
    S.menu = nil
    if S.stage then armTimeout() end
    setScreen('wait', msg)
    respond(m.id, 1, item, '')
    return true
end

-- Назад к списку: закрываем меню объявления и просим список заново
function backToList()
    local m = S.menu
    S.backAt = os.clock()
    S.menu = nil
    if m then respond(m.id, 0, -1, '') end
    setScreen('wait', T('Возвращаюсь к списку...'))
    later(900, function()
        if S.listAt < S.backAt and S.screen == 'wait' then   -- список сам не появился
            sampSendChat('/edit')
        end
    end)
end

function onWindowClosed()
    S.closing = os.clock()
    S.screen = 'idle'
    if S.menu then
        respond(S.menu.id, 0, -1, '')
        S.menu = nil
    end
    if S.listId then
        respond(S.listId, 0, -1, '')
        S.listId, S.items = nil, {}
    end
end

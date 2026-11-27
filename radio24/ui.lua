-- radio24/ui.lua: окно mimgui (все меню и вкладки). Строки оригинала 3186-3801. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- ОКНО (mimgui)
---------------------------------------------------------------------
if okUi then
    local ImV2, ImV4 = imgui.ImVec2, imgui.ImVec4
    local RED, GREEN, GRAY = ImV4(1, 0.45, 0.45, 1), ImV4(0.5, 1, 0.5, 1), ImV4(0.7, 0.7, 0.7, 1)
    local BLUE, ORANGE = ImV4(0.4, 0.8, 1, 1), ImV4(1, 0.7, 0.3, 1)
    local BTN_GREEN = { ImV4(0.15, 0.55, 0.25, 1), ImV4(0.2, 0.68, 0.32, 1), ImV4(0.12, 0.45, 0.2, 1) }
    local BTN_RED = { ImV4(0.65, 0.18, 0.18, 1), ImV4(0.8, 0.25, 0.25, 1), ImV4(0.5, 0.12, 0.12, 1) }
    local BTN_BLUE = { ImV4(0.18, 0.4, 0.7, 1), ImV4(0.25, 0.5, 0.85, 1), ImV4(0.12, 0.3, 0.55, 1) }
    local BTN_ORANGE = { ImV4(0.7, 0.45, 0.1, 1), ImV4(0.85, 0.55, 0.15, 1), ImV4(0.55, 0.35, 0.08, 1) }
    local SETSEL = (imgui.TabItemFlags and imgui.TabItemFlags.SetSelected) or 2

    imgui.OnInitialize(function()
        local io = imgui.GetIO()
        io.IniFilename = nil
        io.Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\arial.ttf', 16, nil,
            io.Fonts:GetGlyphRangesCyrillic())
    end)

    local function tabFlag(name)
        if S.wantTab == name then
            S.wantCnt = (S.wantCnt or 0) + 1                  -- держим выбор несколько кадров, чтобы вкладка точно переключилась
            if S.wantCnt >= 6 then S.wantTab, S.wantCnt = nil, nil end
            return SETSEL
        end
        return 0
    end

    local function safe(f)
        local ok, e = pcall(f)
        if not ok then
            S.lastErr = 'UI: ' .. tostring(e)
            imgui.TextColored(RED, S.lastErr)
        end
    end

    -- цветная кнопка: colors = { обычная, наведение, нажатие }
    local function colorButton(label, size, colors)
        imgui.PushStyleColor(imgui.Col.Button, colors[1])
        imgui.PushStyleColor(imgui.Col.ButtonHovered, colors[2])
        imgui.PushStyleColor(imgui.Col.ButtonActive, colors[3])
        local pressed = imgui.Button(label, size)
        imgui.PopStyleColor(3)
        return pressed
    end

    local function wrapColored(color, text)
        imgui.PushStyleColor(imgui.Col.Text, color)
        imgui.TextWrapped(text)
        imgui.PopStyleColor()
    end

    -- Подсказки: серая мелкая надпись "(помощь)", при наведении - текст. Включаются галочкой на каждой вкладке.
    local HLP = { pending = {}, cb = imgui.new.bool(true), help = {} }
    function HLP.on(page) return cfg['hint' .. tostring(page or S.page)] ~= false end
    function HLP.add(text) if HLP.on() then HLP.pending[#HLP.pending + 1] = text end end
    function HLP.tip(text)
        local parts = HLP.pending; HLP.pending = {}
        if not HLP.on() then return end
        parts[#parts + 1] = text
        imgui.PushStyleColor(imgui.Col.Text, ImV4(0.58, 0.58, 0.62, 1))
        pcall(imgui.SetWindowFontScale, 0.85)
        imgui.Text('(помощь)')
        pcall(imgui.SetWindowFontScale, 1.0)
        imgui.PopStyleColor()
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.PushTextWrapPos(460)
            imgui.TextUnformatted(table.concat(parts, '\n\n'))
            imgui.PopTextWrapPos()
            imgui.EndTooltip()
        end
    end
    function HLP.setAll(v) for _, k in ipairs(HINTKEYS) do cfg[k] = v end cfgSave() end

    local function availWidth()
        local ok, v = pcall(function() return imgui.GetContentRegionAvail().x end)
        return (ok and type(v) == 'number' and v > 100) and v or 600
    end

    local function adHeader(step)
        local who = S.menu and S.menu.nick or S.author
        local line = (who ~= nil and who ~= '') and ('Автор: ' .. u8(who) .. '   >   ') or ''
        imgui.TextColored(BLUE, line .. step)
        imgui.Separator()
    end

    local function copyClip(text)
        pcall(function() imgui.SetClipboardText(u8(text)) end)
    end

    local function clipText()
        local ok, t = pcall(function()
            local c = imgui.GetClipboardText()
            if c ~= nil then return u8:decode(ffi.string(c)) end
        end)
        return ok and t or nil
    end

    -----------------------------------------------------------------
    -- Экран: пусто
    -----------------------------------------------------------------
    local function drawIdle()
        imgui.TextWrapped('Нет открытого объявления. Введи /edit в чате - список появится здесь, '
            .. 'выбери объявление и сразу откроются действия.')
        if colorButton('Открыть список (/edit)', ImV2(240, 36), BTN_BLUE) then sampSendChat('/edit') end
        imgui.Separator()
        imgui.Text('Или проверь любой текст вручную:')
        imgui.InputTextMultiline('##manual', srcBuf, ffi.sizeof(srcBuf), ImV2(-1, 60))
        if imgui.Button('Разобрать текст', ImV2(160, 30)) then
            loadAd(getBuf(srcBuf), '')
            setScreen('edit')
        end
        imgui.SameLine()
        if imgui.Button('Из буфера обмена', ImV2(160, 30)) then
            local t = clipText()
            if t then loadAd(t, ''); setScreen('edit') end
        end
    end

    -----------------------------------------------------------------
    -- Экран 1: список объявлений
    -----------------------------------------------------------------
    local function drawList()
        imgui.TextColored(BLUE, 'Шаг 1. Выбери объявление (' .. #S.items .. ')')
        imgui.Separator()
        if #S.items == 0 then
            imgui.TextWrapped('Список пуст.')
        end
        imgui.BeginChild('##items', ImV2(-1, -42), true)
        for i, line in ipairs(S.items) do
            if imgui.Button(u8(line) .. '##it' .. i, ImV2(-1, 30)) then
                pickItem(i)
                break
            end
        end
        imgui.EndChild()
        if imgui.Button('Закрыть', ImV2(120, 30)) then win[0] = false end
    end

    -----------------------------------------------------------------
    -- Экран 2: ожидание ответа сервера / результат
    -----------------------------------------------------------------
    local function drawWait()
        local done = S.msg:find(T('Готово'), 1, true) ~= nil
        imgui.Spacing()
        imgui.PushStyleColor(imgui.Col.Text, done and GREEN or GRAY)
        imgui.TextWrapped(u8(S.msg ~= '' and S.msg or T('Жду ответ сервера...')))
        imgui.PopStyleColor()
        imgui.Spacing()
        if done or os.clock() - S.waitAt > 1.5 then
            if not done then
                imgui.TextColored(GRAY, 'Новых диалогов нет. Можно открыть список заново.')
            end
            if colorButton('К списку объявлений', ImV2(220, 36), BTN_BLUE) then
                S.waitAt = os.clock()
                S.backAt = os.clock()
                sampSendChat('/edit')
            end
            imgui.SameLine()
            if imgui.Button('Закрыть окно', ImV2(140, 36)) then win[0] = false end
        end
    end

    -----------------------------------------------------------------
    -- Экран 3: действия над выбранным объявлением
    -----------------------------------------------------------------
    local function drawCheck(text)
        if S.chkKey ~= (S.original .. '\1' .. text) or os.clock() - (S.chkAt or 0) > 0.5 then
            S.chkKey, S.chkAt = S.original .. '\1' .. text, os.clock()
            local ok, res = pcall(adCheck, S.original, text)
            S.chk = ok and res or nil
        end
        local c = S.chk
        if not c then return end
        imgui.TextColored(c.verdict == 'remember' and ORANGE or (c.verdict == 'blocked' and RED or GREEN), u8(c.title))
        for _, l in ipairs(c.lines) do
            wrapColored(l.c == 'o' and ORANGE or (l.c == 'r' and RED or GRAY), '   ' .. u8(l.t))
        end
    end

    local function ctrLeft(et)
        local s = et - os.time()
        if s <= 0 then return 'истёк' end
        local d, h = math.floor(s / 86400), math.floor((s % 86400) / 3600)
        if d > 0 then return 'осталось ' .. d .. ' дн. ' .. h .. ' ч.' end
        return 'осталось ' .. h .. ' ч. ' .. math.floor((s % 3600) / 60) .. ' мин.'
    end

    -- строка про контракт под текстом объявления
    local function drawContract()
        if not CTR or not CTR.on then return end
        local ok, r = pcall(ctrCheck, S.original)
        if not ok or not r then return end
        if #r.matches > 0 then
            for _, m in ipairs(r.matches) do
                wrapColored(GREEN, 'Контракт: ЕСТЬ - ' .. u8(m.title) .. ' (' .. u8(m.signer) .. ', ' .. u8(m.loc)
                    .. '), до ' .. os.date('%d.%m %H:%M', m.et) .. ', ' .. ctrLeft(m.et))
                local g = r.gps and r.gps[m.id]
                if g and g[1] == 'ok' then
                    wrapColored(GREEN, 'GPS: совпадает с контрактом (' .. g[2] .. ')')
                elseif g and g[1] == 'bad' then
                    wrapColored(RED, 'GPS: в объявлении ' .. g[2] .. ', а в контракте ' .. g[3] .. ' - проверь')
                elseif g and g[1] == 'none' then
                    wrapColored(ORANGE, 'GPS: в объявлении не указан, по контракту нужен ' .. g[3])
                end
            end
        elseif r.kw then
            if r.nodata then
                wrapColored(GRAY, 'Контракт: список ещё не загружен (в объявлении "' .. u8(r.kw) .. '"). Вкладка "Контракты".')
            else
                wrapColored(ORANGE, 'Контракт: НЕТ - в объявлении "' .. u8(r.kw)
                    .. '", но активного контракта с этой организацией не найдено. Проверь вручную.')
            end
        else
            imgui.TextColored(GRAY, 'Контракт: не требуется (ключевых слов нет)')
        end
    end

    local function drawActions()
        local m = S.menu
        adHeader('Шаг 2. Что сделать с объявлением?')
        imgui.Text('Текст объявления:')
        wrapColored(ORANGE, u8(S.original))
        local best = S.variants[1]
        if best then
            imgui.Spacing()
            imgui.Text(best.mem and 'Из памяти:' or (best.src and 'Эталон (как есть):' or 'Как исправит хелпер:'))
            wrapColored(best.mem and BLUE or GREEN, u8(best.text))
        end
        for _, n in ipairs(S.notes) do wrapColored(RED, '- ' .. u8(n)) end
        for _, r in ipairs(S.reject) do wrapColored(ORANGE, 'Причина для удаления: ' .. u8(shortReason(r))) end
        if S.srcHit then wrapColored(GREEN, 'Совпадает с эталоном (' .. S.srcHit.n .. ' раз): формат уже проверен, можно отправить как есть.') end
        drawCheck(best and best.text or '')
        drawContract()
        imgui.Separator()

        local count = m.opts.admin ~= nil and 4 or 3
        local w = (availWidth() - 8 * (count - 1)) / count
        if colorButton('Отправить\nкак есть##a1', ImV2(w, 56), BTN_GREEN) then menuAct('send', '') end
        imgui.SameLine()
        if colorButton('Редактировать\n(варианты)##a2', ImV2(w, 56), BTN_BLUE) then setScreen('edit') end
        imgui.SameLine()
        if colorButton('Удалить\n(с причиной)##a3', ImV2(w, 56), BTN_RED) then setScreen('delete') end
        if m.opts.admin ~= nil then
            imgui.SameLine()
            if colorButton('Отправить\nадминистрации##a4', ImV2(w, 56), BTN_ORANGE) then setScreen('admin') end
        end
        imgui.Spacing()
        if imgui.Button('<- Назад к списку', ImV2(200, 32)) then backToList() end
    end

    -----------------------------------------------------------------
    -- Экран 4: редактирование
    -----------------------------------------------------------------
    local function drawEdit()
        adHeader('Редактирование')
        drawContract()
        if not S.menu then
            imgui.TextColored(RED, 'Режим проверки текста: отправить нельзя (объявление не открыто через /edit).')
        end
        imgui.Text('Исходный текст:')
        imgui.InputTextMultiline('##src', srcBuf, ffi.sizeof(srcBuf), ImV2(-1, 48))
        if imgui.Button('Разобрать заново') then loadAd(getBuf(srcBuf), S.author) end

        imgui.Separator()
        imgui.Text('Варианты (нажми "Взять"):')
        for i, v in ipairs(S.variants) do
            if imgui.Button('Взять##v' .. i, ImV2(70, 0)) then setBuf(editBuf, v.text) end
            imgui.SameLine()
            imgui.TextColored(v.mem and BLUE or GREEN, u8(v.label) .. ':')
            imgui.SameLine()
            imgui.TextWrapped(u8(v.text))
        end
        for _, n in ipairs(S.notes) do wrapColored(RED, '- ' .. u8(n)) end

        imgui.Separator()
        imgui.Text('Итоговый текст (можно править):')
        imgui.InputTextMultiline('##edit', editBuf, ffi.sizeof(editBuf), ImV2(-1, 60))
        local cur = getBuf(editBuf)
        imgui.TextColored(#cur > cfg.maxLength and RED or GRAY, #cur .. ' / ' .. cfg.maxLength)
        drawCheck(cur)

        if imgui.Button('<- Назад', ImV2(110, 36)) then
            if S.menu then setScreen('actions') else setScreen('idle') end
        end
        imgui.SameLine()
        if S.menu then
            if colorButton('Принять и отправить', ImV2(220, 36), BTN_GREEN) then menuAct('edit', cur) end
            imgui.SameLine()
        end
        if imgui.Button('Запомнить', ImV2(100, 36)) then
            if memAdd(S.original, cur) then
                local k = learnFrom(S.original, (cur:gsub('[%s%.]+$', '')), true)
                say(T('Запомнено.') .. (k > 0 and (T(' Выучено правил: ') .. k) or ''))
            end
        end
        imgui.SameLine()
        if imgui.Button('Копировать', ImV2(100, 36)) then copyClip(cur) end
        imgui.SameLine()
        if imgui.Button('Из буфера', ImV2(100, 36)) then
            local t = clipText()
            if t then setBuf(editBuf, t) end
        end
        if imgui.Button('Правка из моих изменений -> вкладка \"Свои правила замены\"', ImV2(-1, 28)) then
            local base
            for _, v in ipairs(S.variants) do if not v.mem and not v.src then base = v.text; break end end
            local a, b = TX.draft(base or '', (cur:gsub('[%s%.]+$', '')))
            if a then
                setBuf(trFindBuf, a); setBuf(trReplBuf, b); setBuf(trCtxBuf, ''); setBuf(trNegBuf, '')
                S.trEdit, S.trMode, S.wantTab = nil, 'r', 'tr'
                say(T('Проверь черновик и нажми \"Добавить правку\".'))
            else
                say(T('Твой текст не отличается от текста хелпера.'), 0xFFFF6666)
            end
        end
    end

    -----------------------------------------------------------------
    -- Экран 5: удаление с причиной
    -----------------------------------------------------------------
    local function drawDelete()
        adHeader('Удаление объявления')
        wrapColored(ORANGE, u8(S.original))
        imgui.Separator()
        imgui.Text('Выбери причину (она попадёт в поле) или впиши свою:')
        imgui.BeginChild('##reasons', ImV2(-1, 220), true)
        for i, r in ipairs(S.reject) do
            imgui.TextColored(ORANGE, 'Подходит:')
            imgui.SameLine()
            if imgui.Selectable(u8(shortReason(r)) .. '##s' .. i) then setBuf(rejBuf, shortReason(r)) end
        end
        for i, r in ipairs(DEL_REASONS) do
            if imgui.Selectable(u8(r) .. '##r' .. i) then setBuf(rejBuf, r) end
        end
        imgui.EndChild()
        imgui.Text('Причина:')
        imgui.InputText('##rej', rejBuf, ffi.sizeof(rejBuf))
        imgui.Spacing()
        if imgui.Button('<- Назад', ImV2(110, 36)) then
            if S.menu then setScreen('actions') else setScreen('idle') end
        end
        imgui.SameLine()
        if S.menu then
            if colorButton('Принять и удалить', ImV2(220, 36), BTN_RED) then menuAct('delete', getBuf(rejBuf)) end
        end
    end

    -----------------------------------------------------------------
    -- Экран 6: отправка администрации
    -----------------------------------------------------------------
    local function drawAdmin()
        adHeader('Отправить администрации')
        wrapColored(ORANGE, u8(S.original))
        imgui.Separator()
        imgui.Text('Выбери текст жалобы (он попадёт в поле) или впиши свой:')
        imgui.BeginChild('##admpre', ImV2(-1, 150), true)
        for i, r in ipairs(S.reject) do
            imgui.TextColored(ORANGE, 'Подходит:')
            imgui.SameLine()
            if imgui.Selectable(u8(r) .. '##as' .. i) then setBuf(admBuf, r) end
        end
        for i, r in ipairs(ADMIN_PRESETS) do
            if imgui.Selectable(u8(r) .. '##ap' .. i) then setBuf(admBuf, r) end
        end
        imgui.EndChild()
        imgui.Text('Текст для администрации:')
        imgui.InputText('##adm', admBuf, ffi.sizeof(admBuf))
        imgui.Spacing()
        if imgui.Button('<- Назад', ImV2(110, 36)) then
            if S.menu then setScreen('actions') else setScreen('idle') end
        end
        imgui.SameLine()
        if S.menu then
            if colorButton('Принять и отправить админам', ImV2(280, 36), BTN_ORANGE) then
                menuAct('admin', getBuf(admBuf))
            end
        end
    end

    local function drawAds()
        local sc = S.screen
        if sc == 'list' then drawList()
        elseif sc == 'wait' then drawWait()
        elseif sc == 'actions' and S.menu then drawActions()
        elseif sc == 'edit' then drawEdit()
        elseif sc == 'delete' then drawDelete()
        elseif sc == 'admin' then drawAdmin()
        else drawIdle() end
    end

    local function drawMemory()
        local n = 0
        for _ in pairs(MEM) do n = n + 1 end
        imgui.Text('Записей в памяти: ' .. n)
        imgui.SameLine()
        if imgui.Button('Очистить всё') then MEM = {}; memSave() end
        imgui.BeginChild('##mem', ImV2(-1, 150), true)
        local keys = {}
        for k in pairs(MEM) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return (MEM[a].time or 0) > (MEM[b].time or 0) end)
        for i, k in ipairs(keys) do
            local e = MEM[k]
            if imgui.Button('X##m' .. i) then MEM[k] = nil; memSave(); break end
            imgui.SameLine()
            if imgui.Button('Взять##m' .. i) then
                setBuf(editBuf, e.final)
                if S.menu then setScreen('edit'); S.wantTab = 'ads' end
            end
            imgui.SameLine()
            imgui.TextWrapped(u8(e.orig) .. '  =>  ' .. u8(e.final))
        end
        imgui.EndChild()

        -- выученные правила
        local ln, active = 0, 0
        for _, e in pairs(LEARN) do
            ln = ln + 1
            if e.n >= learnNeed(e) then active = active + 1 end
        end
        imgui.Separator()
        imgui.Text('Выученные правила: ' .. ln .. ' (действуют: ' .. active .. ')')
        imgui.SameLine()
        if imgui.Button('Сбросить правила') then LEARN = {}; learnSave() end
        HLP.add('Замена начинает действовать после 2 одинаковых правок (удаление слова - после 3) '
            .. 'или сразу по кнопке "Запомнить".')
        HLP.tip('У каждого правила есть контекст - слова объявления, где оно выучено (например \"скидочный купон\"). '
            .. 'Правило с контекстом работает только в объявлениях с этими словами. Пустой контекст = правило действует везде. '
            .. 'Стоп-слова наоборот отключают правило, если встретились в объявлении. Старые правила остались \"везде\": нажми \"Изм.\" и впиши контекст.')
        imgui.Text('Добавить своё правило (действует сразу):')
        imgui.InputText('Слово или фраза##rk', ruleKeyBuf, ffi.sizeof(ruleKeyBuf))
        imgui.InputText('Заменить на (пусто = убрать)##rv', ruleValBuf, ffi.sizeof(ruleValBuf))
        imgui.InputText('Контекст: слова из объявления (пусто = везде)##rc', ruleCtxBuf, ffi.sizeof(ruleCtxBuf))
        imgui.InputText('Не применять, если в объявлении есть слова##rn', ruleNegBuf, ffi.sizeof(ruleNegBuf))
        if imgui.Button(S.ruleEdit and 'Сохранить изменения' or 'Добавить правило') then
            local old = S.ruleEdit
            local ok, msg, newKey = learnAddManual(getBuf(ruleKeyBuf), getBuf(ruleValBuf), getBuf(ruleCtxBuf), getBuf(ruleNegBuf))
            if ok and old and old ~= newKey then LEARN[old] = nil; learnSave() end
            say(msg, ok and 0xFF66FF66 or 0xFFFF6666)
            if ok then setBuf(ruleKeyBuf, ''); setBuf(ruleValBuf, ''); setBuf(ruleCtxBuf, ''); setBuf(ruleNegBuf, ''); S.ruleEdit = nil end
        end
        if S.ruleEdit then
            imgui.SameLine()
            if imgui.Button('Отмена##re') then S.ruleEdit = nil; setBuf(ruleKeyBuf, ''); setBuf(ruleValBuf, ''); setBuf(ruleCtxBuf, ''); setBuf(ruleNegBuf, '') end
            imgui.SameLine()
            imgui.TextColored(ORANGE, 'правка: ' .. u8(S.ruleEdit))
        end
        if imgui.CollapsingHeader('Журнал последних добавлений (' .. #LEARNLOG .. ')##lj') then
            if imgui.Button('Очистить журнал##lj') then LEARNLOG = {}; learnLogSave() end
            imgui.BeginChild('##learnlog', ImV2(-1, 130), true)
            if #LEARNLOG == 0 then imgui.TextWrapped('Пока ничего не добавлено.') end
            for i = #LEARNLOG, 1, -1 do
                local l = LEARNLOG[i]
                local isName = l.kind == T('название')
                imgui.TextColored(GRAY, os.date('%d.%m %H:%M', l.ts))
                imgui.SameLine()
                imgui.TextColored(isName and ORANGE or BLUE, '[' .. u8(l.kind) .. ']')
                imgui.SameLine()
                if isName then
                    imgui.TextWrapped(u8(l.val) .. '  (' .. u8(l.key) .. ')')
                else
                    imgui.TextWrapped(u8((ctxSplit(l.key))) .. '  =>  ' .. (l.val ~= '' and u8(l.val) or '(убрать слово)'))
                end
            end
            imgui.EndChild()
        end
        imgui.BeginChild('##learn', ImV2(-1, -1), true)
        local lk = {}
        for k in pairs(LEARN) do lk[#lk + 1] = k end
        table.sort(lk, function(a, b) return LEARN[a].n > LEARN[b].n end)
        for i, k in ipairs(lk) do
            local e = LEARN[k]
            if imgui.Button('X##l' .. i) then LEARN[k] = nil; learnSave(); break end
            imgui.SameLine()
            if imgui.Button('Изм.##e' .. i) then
                local p0, c0, n0 = ctxSplit(k)
                setBuf(ruleKeyBuf, p0); setBuf(ruleValBuf, e.val); setBuf(ruleCtxBuf, (c0:gsub(',', ' ')))
                setBuf(ruleNegBuf, (n0:gsub(',', ' '))); S.ruleEdit = k
            end
            imgui.SameLine()
            if e.n < learnNeed(e) then
                if imgui.Button('Включить##l' .. i) then e.n = learnNeed(e); learnSave() end
                imgui.SameLine()
            end
            local on = e.n >= learnNeed(e)
            imgui.TextColored(on and GREEN or GRAY, (e.man and '[своё] ' or '') .. (on and '[работает] ' or '[' .. e.n .. '/' .. learnNeed(e) .. '] ')
                .. u8((ctxSplit(k))) .. '  =>  ' .. (e.val ~= '' and u8(e.val) or '(убрать слово)'))
            local _, c1, n1 = ctxSplit(k)
            wrapColored(GRAY, '      ' .. (c1 ~= '' and ('контекст: ' .. u8((c1:gsub(',', ', ')))) or 'контекст: везде (без привязки)')
                .. (n1 ~= '' and ('   |   НЕ при: ' .. u8((n1:gsub(',', ', ')))) or '')
                .. ((e.ad and e.ad ~= '') and ('   |   выучено на: ' .. u8(e.ad)) or ''))
        end
        imgui.EndChild()
    end

    local function drawTrules()
        HLP.add('Правка меняет уже готовый текст хелпера (регистр не важен). В \"Найти\": * - любой текст (можно пустой), '
            .. '+ - минимум один символ. В \"Заменить\": %1, %2 - то, что нашлось на местах * и +. '
            .. 'Режим \"предлагать вариант\" текст не меняет, а добавляет второй вариант в окно редактирования.')
        HLP.add('Пример: найти  \".(  заменить  \" (   - убирает точку после названия в кавычках.')
        HLP.tip('Как это работает: у каждой части своя задача. Названия отвечают за кавычки и всё, что внутри них. '
            .. 'Лишние слова удаляются раньше. Правка текста идёт последней и меняет только слова целиком вне кавычек '
            .. '(нужна часть слова - поставь * с нужной стороны, например кост* заденет костюм). '
            .. 'Оранжевая строка под правкой - пересечение с названиями или лишними словами, зелёное число - сколько раз она сработала.')
        imgui.InputText('Найти##tf', trFindBuf, ffi.sizeof(trFindBuf))
        imgui.InputText('Заменить на (пусто = удалить)##tr', trReplBuf, ffi.sizeof(trReplBuf))
        imgui.InputText('Только если в объявлении есть слова (пусто = всегда)##tc', trCtxBuf, ffi.sizeof(trCtxBuf))
        imgui.InputText('Не применять, если в объявлении есть слова##tn', trNegBuf, ffi.sizeof(trNegBuf))
        if imgui.Button(S.trMode == 'v' and 'Режим: предлагать как вариант (нажми, чтобы сменить)##tm'
            or 'Режим: заменять сразу (нажми, чтобы сменить)##tm') then
            S.trMode = (S.trMode == 'v') and 'r' or 'v'
        end
        if imgui.Button(S.trEdit and 'Сохранить изменения##ts' or 'Добавить правку##ts') then
            local ok, msg = TX.add(getBuf(trFindBuf), getBuf(trReplBuf), getBuf(trCtxBuf), getBuf(trNegBuf), S.trMode, S.trEdit)
            say(msg, ok and 0xFF66FF66 or 0xFFFF6666)
            if ok then
                setBuf(trFindBuf, ''); setBuf(trReplBuf, ''); setBuf(trCtxBuf, ''); setBuf(trNegBuf, '')
                S.trEdit = nil
            end
        end
        if S.trEdit then
            imgui.SameLine()
            if imgui.Button('Отмена##tcn') then
                S.trEdit = nil
                setBuf(trFindBuf, ''); setBuf(trReplBuf, ''); setBuf(trCtxBuf, ''); setBuf(trNegBuf, '')
            end
        end
        imgui.Separator()
        imgui.Text('Правок: ' .. #TX.rules)
        imgui.BeginChild('##trlist', ImV2(-1, -1), true)
        for i, r in ipairs(TX.rules) do
            if imgui.Button('X##tx' .. i) then table.remove(TX.rules, i); TX.save(); S.trEdit = nil; break end
            imgui.SameLine()
            if imgui.Button('Изм.##te' .. i) then
                setBuf(trFindBuf, r.find); setBuf(trReplBuf, r.repl)
                setBuf(trCtxBuf, (r.ctx:gsub(',', ' '))); setBuf(trNegBuf, (r.neg:gsub(',', ' ')))
                S.trMode, S.trEdit = r.mode, i
            end
            imgui.SameLine()
            if imgui.Button((r.on and 'Вкл' or 'Выкл') .. '##tt' .. i) then r.on = not r.on; TX.save() end
            imgui.SameLine()
            imgui.TextColored(r.on and GREEN or GRAY, (r.mode == 'v' and '[вариант] ' or '[заменять] ')
                .. '\"' .. u8(r.find) .. '\"  =>  \"' .. u8(r.repl) .. '\"')
            local cf = TX.conflict(r)
            if cf then wrapColored(ORANGE, '      ! ' .. u8(cf)) end
            if (r.hits or 0) > 0 then wrapColored(GREEN, '      сработала в этой сессии: ' .. r.hits) end
            if r.ctx ~= '' or r.neg ~= '' then
                wrapColored(GRAY, '      ' .. (r.ctx ~= '' and ('если есть: ' .. u8((r.ctx:gsub(',', ', ')))) or '')
                    .. (r.neg ~= '' and ('   НЕ при: ' .. u8((r.neg:gsub(',', ', ')))) or ''))
            end
        end
        imgui.EndChild()
        do
            local nj = #AUTO.added
            if imgui.CollapsingHeader('Журнал добавленных правил (' .. nj .. ')##trlog') then
                imgui.BeginChild('##trlogc', imgui.ImVec2(-1, 200), true)
                if nj == 0 then imgui.TextWrapped('Пока пусто. Сюда пишутся правила, добавленные из тестов и из вкладки Предложенные правила.') end
                for i = nj, 1, -1 do
                    local a = AUTO.added[i]
                    imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1),
                        os.date('%d.%m %H:%M', a.ts) .. '  ' .. (a.how == 'stray' and 'Лишние слова' or 'Свои правила замены'))
                    local txt = (a.kind == 'del') and ('удалить «' .. u8(a.find) .. '»')
                        or ('«' .. u8(a.find) .. '» => «' .. u8(a.repl) .. '»')
                    imgui.TextColored(imgui.ImVec4(0.4, 1, 0.4, 1), (txt:gsub('%%', '%%%%')))
                    if imgui.Button('Откатить##trlr' .. i) then autoUndo(i); break end
                    imgui.Separator()
                end
                imgui.EndChild()
            end
        end
    end

    local catBufs = {}
    local catNewBuf, catKwBuf, catPfBuf
    local function drawNames()
        HLP.tip('Названия в кавычках (аксессуары, костюмы, транспорт, районы, места, семьи...). Запоминаются сами из твоих правок, '
            .. 'а здесь их можно вписать вручную, поправить, отключить или перенести в другую категорию. '
            .. 'Кавычки Вкл: название без кавычек в объявлении берётся в кавычки. Выкл: кавычки вокруг него убираются.')
        local cats = namesCatList()
        S.nmCat = S.nmCat or cats[1]
        S.nmBulk = S.nmBulk or cats[1]
        S.nmSel = S.nmSel or {}
        if S.nmOn == nil then S.nmOn = true end

        if imgui.CollapsingHeader('Префиксы категорий: что ставится перед названием') then
            HLP.tip('Настраивается для категории целиком. Префикс ставится перед названием в кавычках, пробел между ними '
                .. 'добавляется сам (например а/с "Гитара"). Пусто - без префикса. Если перед названием уже стоит префикс или '
                .. 'слово категории, второй раз он не добавляется. Для аксессуаров и костюмов тот же префикс подставляется '
                .. 'и в названия из словаря.')
            for i, c in ipairs(cats) do
                if not catBufs[c] then
                    catBufs[c] = imgui.new.char[48]()
                    setBuf(catBufs[c], catPrefOf(c))
                end
                imgui.Text(u8(c))
                imgui.SameLine(260)
                imgui.PushItemWidth(180)
                if imgui.InputText('##cp' .. i, catBufs[c], ffi.sizeof(catBufs[c])) then
                    CATPREF[c] = trim(getBuf(catBufs[c]))
                    catPrefSave()
                end
                imgui.PopItemWidth()
            end
            if imgui.Button('Сбросить префиксы##cpr') then CATPREF = {}; catPrefSave(); catBufs = {} end
        end
        imgui.Separator()

        if imgui.CollapsingHeader('Категории: создать свою и удалить') then
            HLP.tip('Новая категория: название и префикс (например а/с): название в кавычках, перед которым стоит этот префикс, '
                .. 'хелпер сам запоминает в эту категорию (так же и для стандартных, и если поменять префикс позже). Слова-признаки через запятую - дополнительный способ: слово перед названием тоже относит его сюда. Удалить можно любую категорию, кроме '
                .. '"прочее": её названия перейдут в "прочее". Свою категорию потом можно выбирать при добавлении названия и при переносе.')
            if not catNewBuf then
                catNewBuf = imgui.new.char[48]()
                catKwBuf = imgui.new.char[192]()
                catPfBuf = imgui.new.char[48]()
            end
            imgui.InputText('Название категории##cnn', catNewBuf, ffi.sizeof(catNewBuf))
            imgui.InputText('Слова-признаки##cnk', catKwBuf, ffi.sizeof(catKwBuf))
            imgui.InputText('Префикс##cnp', catPfBuf, ffi.sizeof(catPfBuf))
            if imgui.Button('Создать категорию##cnc') then
                local ok, msg = catAdd(getBuf(catNewBuf), getBuf(catKwBuf), getBuf(catPfBuf))
                say(msg, ok and 0xFF66FF66 or 0xFFFF6666)
                if ok then
                    setBuf(catNewBuf, ''); setBuf(catKwBuf, ''); setBuf(catPfBuf, '')
                    catBufs = {}
                end
            end
            imgui.Separator()
            local cnt = {}
            for _, e in pairs(NAMES) do cnt[e.cat] = (cnt[e.cat] or 0) + 1 end
            for i, c in ipairs(cats) do
                imgui.Text(u8(c) .. ' (' .. (cnt[c] or 0) .. ')')
                if c ~= T(NAMES_OTHER) then
                    imgui.SameLine(260)
                    if imgui.Button('Удалить##cdl' .. i) then S.catDel = c end
                end
            end
            if S.catDel then
                imgui.TextColored(imgui.ImVec4(1, 0.5, 0.3, 1), 'Удалить категорию «' .. u8(S.catDel) .. '»? Названия перейдут в "прочее".')
                if imgui.Button('Да, удалить##cdy') then
                    local ok, msg = catDel(S.catDel)
                    say(msg, ok and 0xFF66FF66 or 0xFFFF6666)
                    if S.nmCat == S.catDel then S.nmCat = nil end
                    if S.nmBulk == S.catDel then S.nmBulk = nil end
                    S.catDel = nil
                    catBufs = {}
                end
                imgui.SameLine()
                if imgui.Button('Нет##cdn') then S.catDel = nil end
            end
            if imgui.Button('Вернуть стандартные категории##cdr') then
                local n = catsRestore()
                say(T('Возвращено стандартных категорий: ') .. n, 0xFF66FF66)
            end
        end
        imgui.Separator()

        imgui.InputText('Название##nmb', nameBuf, ffi.sizeof(nameBuf))
        if imgui.BeginCombo('Категория##nmc', u8(S.nmCat)) then
            for i, c in ipairs(cats) do
                if imgui.Selectable(u8(c) .. '##nmcc' .. i, c == S.nmCat) then S.nmCat = c end
            end
            imgui.EndCombo()
        end
        if imgui.Button((S.nmOn and 'Кавычки: Вкл' or 'Кавычки: Выкл') .. '##nmo') then S.nmOn = not S.nmOn end
        imgui.SameLine()
        if imgui.Button(S.nmEdit and 'Сохранить изменения##nms' or 'Добавить название##nms') then
            local ok, msg = namesSet(getBuf(nameBuf), S.nmCat, S.nmOn, S.nmEdit)
            say(msg, ok and 0xFF66FF66 or 0xFFFF6666)
            if ok then setBuf(nameBuf, ''); S.nmEdit = nil end
        end
        if S.nmEdit then
            imgui.SameLine()
            if imgui.Button('Отмена##nmx') then setBuf(nameBuf, ''); S.nmEdit = nil end
        end
        imgui.Separator()

        local selN = 0
        for _ in pairs(S.nmSel) do selN = selN + 1 end
        imgui.Text('Перенести выбранные (' .. selN .. ') в:')
        imgui.SameLine()
        imgui.PushItemWidth(240)
        if imgui.BeginCombo('##nmbulk', u8(S.nmBulk)) then
            for i, c in ipairs(cats) do
                if imgui.Selectable(u8(c) .. '##nmbb' .. i, c == S.nmBulk) then S.nmBulk = c end
            end
            imgui.EndCombo()
        end
        imgui.PopItemWidth()
        imgui.SameLine()
        if imgui.Button('Перенести##nmmv') then
            local keys = {}
            for k in pairs(S.nmSel) do keys[#keys + 1] = k end
            local n = namesSetCat(keys, S.nmBulk)
            say(T('Перенесено названий: ') .. n .. T(' в категорию "') .. S.nmBulk .. '"', 0xFF66FF66)
            S.nmSel = {}
        end
        imgui.SameLine()
        if imgui.Button('Снять выбор##nmcl') then S.nmSel = {} end

        local by, order = {}, {}
        local total = 0
        for k, e in pairs(NAMES) do
            total = total + 1
            if not by[e.cat] then by[e.cat] = {}; order[#order + 1] = e.cat end
            by[e.cat][#by[e.cat] + 1] = k
        end
        table.sort(order)
        imgui.Text('Названий: ' .. total)
        imgui.BeginChild('##nmlist', ImV2(-1, -1), true)
        local uid = 0
        for ci, c in ipairs(order) do
            table.sort(by[c])
            imgui.TextColored(ORANGE, u8(c) .. ' (' .. #by[c] .. ')')
            imgui.SameLine()
            if imgui.Button('Выбрать все##nma' .. ci) then
                for _, k in ipairs(by[c]) do S.nmSel[k] = true end
            end
            for _, k in ipairs(by[c]) do
                local e = NAMES[k]
                uid = uid + 1
                if imgui.Button((S.nmSel[k] and '[x]' or '[  ]') .. '##ns' .. uid) then
                    S.nmSel[k] = (not S.nmSel[k]) and true or nil
                end
                imgui.SameLine()
                if imgui.Button('X##nx' .. uid) then NAMES[k] = nil; S.nmSel[k] = nil; namesSave(); S.nmEdit = nil; break end
                imgui.SameLine()
                if imgui.Button('Изм.##ne' .. uid) then
                    setBuf(nameBuf, e.name); S.nmCat, S.nmOn, S.nmEdit = e.cat, e.on, k
                end
                imgui.SameLine()
                if imgui.Button((e.on and 'Кав. Вкл' or 'Кав. Выкл') .. '##nt' .. uid) then namesToggle(k) end
                imgui.SameLine()
                imgui.TextColored(e.on and GREEN or GRAY, (e.on and '\"' .. u8(e.name) .. '\"' or u8(e.name)))
            end
        end
        imgui.EndChild()
    end

    local function drawSrc()
        local n = 0
        for _ in pairs(SRC) do n = n + 1 end
        imgui.Text('Эталонов (правил исходника): ' .. n)
        imgui.SameLine()
        if imgui.Button('Очистить эталоны') then SRC = {}; srcSave() end
        HLP.tip('Объявление, отправленное как есть, становится эталоном. Похожие по сути '
            .. '(эконом-класса / эконом класса) повторно не добавляются, а при встрече подсказываются как проверенные. '
            .. 'Эталоны создаются только для "Цена: договорная" и "Бюджет: свободный", для точных сумм - нет.')
        if S.srcEdit then
            imgui.TextColored(ORANGE, 'Правка эталона:')
            imgui.InputTextMultiline('##srcedit', srcEditBuf, ffi.sizeof(srcEditBuf), ImV2(-1, 50))
            if imgui.Button('Сохранить##sev') then
                local ok, msg = srcEditSave(S.srcEdit, getBuf(srcEditBuf))
                say(msg, ok and 0xFF66FF66 or 0xFFFF6666)
                if ok then S.srcEdit = nil end
            end
            imgui.SameLine()
            if imgui.Button('Отмена##sec') then S.srcEdit = nil end
        end
        imgui.BeginChild('##srclist', ImV2(-1, 160), true)
        local keys = {}
        for k in pairs(SRC) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return (SRC[a].time or 0) > (SRC[b].time or 0) end)
        for i, k in ipairs(keys) do
            local e = SRC[k]
            if imgui.Button('X##s' .. i) then SRC[k] = nil; srcSave(); break end
            imgui.SameLine()
            if imgui.Button('Изм.##se' .. i) then setBuf(srcEditBuf, e.text); S.srcEdit = k end
            imgui.SameLine()
            imgui.TextWrapped('[' .. e.n .. '] ' .. u8(e.text))
        end
        imgui.EndChild()
        imgui.Text('Журнал отправки как есть:')
        imgui.SameLine()
        if imgui.Button('Очистить журнал') then SRCLOG = {}; srcLogSave() end
        imgui.BeginChild('##srclog', ImV2(-1, -1), true)
        for i = #SRCLOG, 1, -1 do
            local l = SRCLOG[i]
            local lbl = l.kind == 'new' and '  эталон добавлен'
                or (l.kind == 'skip' and '  эталон не добавлен (точная цена/бюджет или цена не указана)'
                    or '  эталон уже есть (дубль не добавлен)')
            imgui.TextColored(l.kind == 'new' and GREEN or GRAY, os.date('%d.%m %H:%M', l.ts) .. lbl)
            imgui.TextWrapped(u8(l.text))
            if l.rules ~= '' then imgui.TextColored(GRAY, 'Правила: ' .. u8(l.rules)) end
            imgui.Separator()
        end
        imgui.EndChild()
    end

    local function drawRef()
        imgui.Text('Поиск:')
        imgui.SameLine()
        imgui.InputText('##flt', filterBuf, ffi.sizeof(filterBuf))
        imgui.TextWrapped('Краткий пересказ ПРО Radio24 (полный текст: ' .. REF_URL .. ')')
        imgui.BeginChild('##ref', ImV2(-1, -1), true)
        local f = lo(trim(getBuf(filterBuf)))
        if f ~= '' then
            for _, sec in ipairs(REF) do
                for _, line in ipairs(sec[2]) do
                    if lowUtf(line):find(f, 1, true) then
                        imgui.TextColored(ImV4(0.6, 0.8, 1, 1), '[' .. sec[1] .. ']')
                        imgui.TextWrapped(line)
                    end
                end
            end
        else
            for _, sec in ipairs(REF) do
                if imgui.CollapsingHeader(sec[1]) then
                    for _, line in ipairs(sec[2]) do imgui.TextWrapped('- ' .. line) end
                end
            end
        end
        imgui.EndChild()
    end

    -- ===== ЛИШНИЕ СЛОВА (вкладка) =====
    local strayWordBuf, strayCtxBuf = imgui.new.char[320](), imgui.new.char[192]()
    local STRAY_KINDS = { learn = 'запомнено', weak = 'ослаблено (слово оставлено)',
        manual = 'добавлено/изменено вручную', apply = 'убрано в объявлении' }

    local function drawStray()
        local n = 0
        for _ in pairs(STRAY) do n = n + 1 end
        imgui.Text('Лишних слов в памяти: ' .. n)
        imgui.SameLine()
        if imgui.Button('Очистить слова') then STRAY = {}; straySave(); S.strayEdit = nil end
        HLP.tip('Слова, которые хелпер не распознал и оставил в тексте. Они убираются из вариантов, а рядом '
            .. 'всегда есть вариант "Без удаления слов". Слово запоминается само: правишь объявление и убираешь его - '
            .. 'в похожих объявлениях оно уберётся. Здесь слово можно добавить вручную, изменить, выключить или удалить. '
            .. 'Контекст - слова исходника через запятую: слово убирается, только если они есть в объявлении '
            .. '(пусто - убирать всегда). У выученных слов контекст показан основами слов. '
            .. 'Можно вписывать фразы из нескольких слов (например лос сантос или звоните мне; дефис и пробел равнозначны) '
            .. 'и сразу несколько записей через запятую: каждая запятая начинает новое слово.')
        imgui.Separator()
        imgui.TextColored(ORANGE, S.strayEdit and 'Правка слова:' or 'Добавить слово:')
        imgui.Text('Слово или фраза:')
        imgui.SameLine()
        imgui.InputText('##stw', strayWordBuf, ffi.sizeof(strayWordBuf))
        imgui.Text('Контекст:')
        imgui.SameLine()
        imgui.InputText('##stc', strayCtxBuf, ffi.sizeof(strayCtxBuf))
        if imgui.Button(S.strayEdit and 'Сохранить##sw' or 'Добавить##sw') then
            local ok, msg = strayAdd(getBuf(strayWordBuf), getBuf(strayCtxBuf), S.strayEdit)
            say(msg, ok and 0xFF66FF66 or 0xFFFF6666)
            if ok then
                setBuf(strayWordBuf, ''); setBuf(strayCtxBuf, ''); S.strayEdit = nil
            end
        end
        if S.strayEdit then
            imgui.SameLine()
            if imgui.Button('Отмена##sw') then
                setBuf(strayWordBuf, ''); setBuf(strayCtxBuf, ''); S.strayEdit = nil
            end
        end
        imgui.BeginChild('##straylist', ImV2(-1, 170), true)
        local keys = {}
        for k in pairs(STRAY) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return (STRAY[a].time or 0) > (STRAY[b].time or 0) end)
        if #keys == 0 then imgui.TextWrapped('Пока пусто. Слова появятся, когда ты уберёшь лишнее слово при правке объявления.') end
        for i, k in ipairs(keys) do
            local e = STRAY[k]
            if imgui.Button('X##sx' .. i) then STRAY[k] = nil; straySave(); if S.strayEdit == k then S.strayEdit = nil end; break end
            imgui.SameLine()
            if imgui.Button('Изм.##sm' .. i) then
                setBuf(strayWordBuf, k); setBuf(strayCtxBuf, table.concat(e.ctx, ', ')); S.strayEdit = k
            end
            imgui.SameLine()
            if imgui.Button((e.on == false and 'Вкл' or 'Выкл') .. '##so' .. i) then
                e.on = (e.on == false); straySave()
            end
            imgui.SameLine()
            local line = u8(k)
                .. (#e.ctx > 0 and ('  контекст: ' .. u8(table.concat(e.ctx, ', '))) or '  (всегда)')
            imgui.PushStyleColor(imgui.Col.Text, e.on == false and GRAY or GREEN)
            imgui.TextWrapped(line)
            imgui.PopStyleColor()
        end
        imgui.EndChild()
        imgui.Text('Журнал:')
        imgui.SameLine()
        if imgui.Button('Очистить журнал##sl') then STRAYLOG = {} end
        imgui.BeginChild('##straylog', ImV2(-1, -1), true)
        for i = #STRAYLOG, 1, -1 do
            local l = STRAYLOG[i]
            imgui.TextColored(l.kind == 'learn' and GREEN or GRAY,
                os.date('%d.%m %H:%M', l.ts) .. '  ' .. (STRAY_KINDS[l.kind] or l.kind) .. ': ' .. u8(l.text))
        end
        imgui.EndChild()
    end

    local tagBuf = imgui.new.char[32]()
    local function drawTags()
        imgui.Separator()
        imgui.TextColored(ORANGE, 'Тэги ([BDAY7], [BP] и т.п.)')
        HLP.tip('Тэги хелпер оставляет в тексте как есть и оформляет в квадратные скобки. Новые тэги он запоминает сам из твоих вариантов; '
            .. 'опечатка в одну букву (BDYA7) не мешает. HW / FT / PT / NY обрабатываются основным разбором.')
        local list = {}
        for k in pairs(TAGS) do list[#list + 1] = k end
        table.sort(list)
        for i, k in ipairs(list) do
            if imgui.Button('Удалить##tg' .. i) then tagsDel(k); break end
            imgui.SameLine()
            imgui.Text('[' .. string.upper(k) .. ']')
        end
        imgui.InputText('Новый тэг##tgin', tagBuf, ffi.sizeof(tagBuf))
        imgui.SameLine()
        if imgui.Button('Добавить##tgadd') then
            local ok, msg = tagsAdd(ffi.string(tagBuf))
            say(msg, ok and 0xFF66FF66 or 0xFFFF6666)
            if ok then ffi.fill(tagBuf, ffi.sizeof(tagBuf), 0) end
        end
    end

    local tstInBuf, tstExpBuf, tstHelpBuf = imgui.new.char[512](), imgui.new.char[512](), imgui.new.char[512]()
    local tstState = { res = nil, edit = nil, cands = nil }
    local LOGKIND = { accept = 'принят результат хелпера', edit = 'правка нужного', add = 'добавлен тест', delete = 'удалён тест',
        undo = 'откат', rule = 'создано правило', memory = 'добавлены пары из памяти' }
    local function setRaw(buf, s)
        ffi.fill(buf, ffi.sizeof(buf), 0)
        s = s or ''
        ffi.copy(buf, s, math.min(#s, ffi.sizeof(buf) - 1))
    end
    local function helperOf(inpUtf)
        local ok, got = pcall(KB.helperText, T(inpUtf), tstState.mode or 'full')
        return ok and u8(got) or ('ошибка: ' .. tostring(got))
    end
    local function runTests()
        local ok, bad = KB.selftest(tstState.mode or 'full')
        tstState.res = { ok = ok, bad = bad }
    end
    local function clearForm()
        tstState.edit, tstState.cands = nil, nil
        setRaw(tstInBuf, ''); setRaw(tstExpBuf, ''); setRaw(tstHelpBuf, '')
    end
    local function startEdit(t)
        tstState.edit, tstState.cands = t, nil
        setRaw(tstInBuf, t.inp)
        setRaw(tstExpBuf, t.exp)
        setRaw(tstHelpBuf, helperOf(t.inp))
    end

    local function drawTests()
        HLP.tip('Тест: объявление и то, что должно получиться. Правь нужный результат, если ошибка в самом тесте. '
            .. 'Результат хелпера можно поправить в поле и нажать Разница и правила: хелпер покажет, какое правило даст такую разницу и что оно изменит в памяти. '
            .. 'Все изменения записываются в журнал ниже, их можно откатить.')
        imgui.TextColored(ORANGE, tstState.edit and 'Правка теста' or 'Добавить свой тест')
        imgui.InputText('Объявление (как пришло)##tin', tstInBuf, ffi.sizeof(tstInBuf))
        imgui.InputText('Нужный результат##tex', tstExpBuf, ffi.sizeof(tstExpBuf))
        imgui.InputText('Результат хелпера (можно править)##thp', tstHelpBuf, ffi.sizeof(tstHelpBuf))
        if imgui.Button('Получить результат хелпера##tget') then
            local inp = ffi.string(tstInBuf)
            if inp ~= '' then setRaw(tstHelpBuf, helperOf(inp)); tstState.cands = nil end
        end
        imgui.SameLine()
        if imgui.Button('Нужный = результат хелпера##tuse') then setRaw(tstExpBuf, ffi.string(tstHelpBuf)) end
        imgui.SameLine()
        if imgui.Button('Разница и правила##tdiff') then
            local inp = ffi.string(tstInBuf)
            local list = {}
            for _, c in ipairs(autoPairCands(T(ffi.string(tstHelpBuf)), T(ffi.string(tstExpBuf)), T(inp))) do
                local imp, brk = autoEval(c)
                list[#list + 1] = { c = c, imp = imp, brk = brk }
            end
            tstState.cands = list
        end
        if tstState.cands then
            if #tstState.cands == 0 then
                imgui.TextWrapped('Разницы нет или она слишком большая / с числами: правилом не выразить.')
            end
            for i, cd in ipairs(tstState.cands) do
                local c = cd.c
                local txt = (c.kind == 'del') and ('удалить «' .. u8(c.find) .. '»')
                    or ('«' .. u8(c.find) .. '» => «' .. u8(c.repl) .. '»')
                imgui.TextColored(cd.brk == 0 and GREEN or RED,
                    txt .. '   исправит пар памяти: ' .. cd.imp .. ', сломает: ' .. cd.brk)
                if cd.brk == 0 then
                    imgui.SameLine()
                    if imgui.Button('Добавить правило##tcr' .. i) then
                        if autoAccept(c, false) then
                            testsLog('rule', ffi.string(tstInBuf), '', u8(c.find) .. ' => ' .. u8(c.repl))
                            table.remove(tstState.cands, i)
                        end
                        break
                    end
                end
            end
        end
        if tstState.edit then
            if imgui.Button('Сохранить правку##tsave') then
                local t = tstState.edit
                local newExp = trim(ffi.string(tstExpBuf))
                if newExp ~= '' then
                    if t.src == 'user' then
                        local ni = trim(ffi.string(tstInBuf))
                        if ni ~= '' and KB.user.list[t.idx] then KB.user.list[t.idx][1] = ni end
                    end
                    if newExp ~= t.exp then testsSetExp(t, newExp, 'edit') else testsSave() end
                    clearForm(); runTests()
                end
            end
            imgui.SameLine()
            if imgui.Button('Отмена##tcancel') then clearForm() end
        else
            do
                local mn = { pro = 'ПРО (как раньше)', full = 'ПОЛНЫЙ', names = 'ПОЛНЫЙ+НАЗВАНИЯ' }
                if imgui.Button('Режим: ' .. mn[tstState.mode or 'full'] .. '##tmode') then
                    local nx = { full = 'names', names = 'pro', pro = 'full' }
                    tstState.mode = nx[tstState.mode or 'full']
                end
                imgui.SameLine()
            end
            if imgui.Button('Добавить тест##tadd') then
                local inp, ex = trim(ffi.string(tstInBuf)), trim(ffi.string(tstExpBuf))
                if inp ~= '' and ex ~= '' then testsAddUser(inp, ex); clearForm(); runTests() end
            end
            imgui.SameLine()
            if imgui.Button('Из памяти: добавить все пары##tmem') then
                local have, n = {}, 0
                for _, t in ipairs(KB.allTests()) do have[t.inp] = true end
                for _, e in pairs(MEM) do
                    local i1 = (u8(e.orig):gsub('[\t\r\n]', ' '))
                    local f1 = (u8(e.final):gsub('[\t\r\n]', ' '))
                    if not have[i1] then testsAddUser(i1, f1, true); have[i1] = true; n = n + 1 end
                end
                testsLog('memory', '(пары из памяти)', '', tostring(n))
                runTests()
            end
        end
        imgui.Separator()
        if imgui.Button('Прогнать тесты##trun') then runTests() end
        if tstState.res then
            imgui.SameLine()
            imgui.Text('верно: ' .. tstState.res.ok .. ', ошибок: ' .. #tstState.res.bad)
            imgui.BeginChild('##tbad', ImV2(-1, 240), true)
            for i, b in ipairs(tstState.res.bad) do
                local t = b[4]
                imgui.TextColored(GRAY, 'Вход:   ' .. b[1])
                imgui.TextColored(GREEN, 'Нужно:  ' .. b[2])
                imgui.TextColored(ORANGE, 'Вышло:  ' .. u8(b[3]))
                if imgui.Button('Принять результат хелпера##tacc' .. i) then
                    testsSetExp(t, u8(b[3]), 'accept'); runTests(); break
                end
                imgui.SameLine()
                if imgui.Button('Править##ted' .. i) then startEdit(t) end
                imgui.SameLine()
                if imgui.Button('Удалить тест##tdel' .. i) then testsDrop(t); runTests(); break end
                imgui.Separator()
            end
            imgui.EndChild()
        end
        local all = KB.allTests()
        if imgui.CollapsingHeader('Все тесты (' .. #all .. ')##tall') then
            imgui.BeginChild('##tallc', ImV2(-1, 200), true)
            for i, t in ipairs(all) do
                if imgui.Button('Править##tae' .. i) then startEdit(t) end
                imgui.SameLine()
                if imgui.Button('Удалить##tad' .. i) then testsDrop(t); runTests(); break end
                imgui.SameLine()
                imgui.TextWrapped(t.inp .. '  =>  ' .. t.exp .. ((t.orig and t.orig ~= t.exp) and '   [изменён, было: ' .. t.orig .. ']' or ''))
            end
            imgui.EndChild()
        end
        if imgui.CollapsingHeader('Журнал изменений тестов (' .. #KB.log .. ')##tlog') then
            imgui.BeginChild('##tlogc', ImV2(-1, 220), true)
            if #KB.log == 0 then imgui.TextWrapped('Пока пусто. Сюда пишется всё, что менялось в тестах: принятые результаты, правки, добавления, удаления, созданные правила.') end
            for i = #KB.log, 1, -1 do
                local l = KB.log[i]
                imgui.TextColored(GRAY, os.date('%d.%m %H:%M', l.ts) .. '  ' .. (LOGKIND[l.kind] or l.kind))
                imgui.TextWrapped('Вход: ' .. l.inp)
                if l.old ~= '' then imgui.TextColored(ORANGE, 'было:   ' .. l.old) end
                if l.new ~= '' then imgui.TextColored(GREEN, 'стало:  ' .. l.new) end
                if (l.kind == 'accept' or l.kind == 'edit') and imgui.Button('Откатить##tlr' .. i) then
                    testsRestore(l); runTests(); break
                end
                imgui.Separator()
            end
            imgui.EndChild()
        end
    end

    local function drawAuto()
        HLP.tip('Хелпер сравнивает свой текст с твоими правками из памяти и сам предлагает правила: заменить или удалить слово. '
            .. 'Правило показывается, только если оно исправляет хотя бы одну запомненную пару и не портит ни одну другую. '
            .. 'Лишние слова из исходника уходят во вкладку Лишние слова, остальное - в Свои правила замены. '
            .. 'Принять / Отклонить - решаешь ты. Автовключение по умолчанию ВЫКЛЮЧЕНО.')
        local cb = imgui.new.bool(AUTO.on)
        if imgui.Checkbox('Автовключение: ставить подтверждённые правила самому##autoon', cb) then
            AUTO.on = cb[0]; autoSave()
        end
        imgui.Text('Подтверждений (разных пар) для автовключения: ' .. AUTO.min)
        imgui.SameLine()
        if imgui.Button('-##autom') then AUTO.min = math.max(1, AUTO.min - 1); autoSave() end
        imgui.SameLine()
        if imgui.Button('+##autop') then AUTO.min = math.min(10, AUTO.min + 1); autoSave() end
        if imgui.Button('Пересчитать##autorun') then autoRun(false) end
        imgui.SameLine()
        imgui.Text('пар в памяти: ' .. AUTO.nPairs .. ', совпадает с твоим: ' .. AUTO.nOk
            .. ', предложений: ' .. #AUTO.list .. ', не объяснено: ' .. #AUTO.unexplained)
        if AUTO.err ~= '' then imgui.TextColored(RED, u8(AUTO.err)) end
        if imgui.Button((AUTO.tests and 'Тесты учитываются в анализе' or 'Тесты НЕ учитываются в анализе') .. '##atst') then
            AUTO.tests = not AUTO.tests; autoSave(); autoRun(false)
        end
        imgui.Separator()
        imgui.TextColored(ORANGE, 'Предложения')
        imgui.BeginChild('##autolist', ImV2(-1, 190), true)
        if #AUTO.list == 0 then imgui.TextWrapped('Пока нет. Нажми Пересчитать или добавь больше правок в память.') end
        for i, c in ipairs(AUTO.list) do
            if imgui.Button('Принять##aa' .. i) then
                autoAccept(c, false); autoRun(false); break
            end
            imgui.SameLine()
            if imgui.Button('Отклонить##ar' .. i) then autoReject(c); autoRun(false); break end
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Text, GREEN)
            imgui.TextWrapped('[исправит пар: ' .. c.improved .. ', подтверждений: ' .. (c.support or 0) .. '] '
                .. (c.kind == 'del' and ('удалить  \"' .. u8(c.find) .. '\"') or ('\"' .. u8(c.find) .. '\"  =>  \"' .. u8(c.repl) .. '\"'))
                .. (c.kind == 'del' and c.inOrig and '  (в Лишние слова)' or ''))
            imgui.PopStyleColor()
            if c.ex then imgui.TextColored(GRAY, '      пример [' .. u8(c.ex.src or '') .. ']: ' .. u8(c.ex.orig)) end
        end
        imgui.EndChild()
        if AUTO.tests and imgui.CollapsingHeader('Ошибки тестов (' .. #AUTO.terr .. ')##autoterr') then
            HLP.tip('Тесты, где хелпер даёт не то, что нужно. Под каждым - правила, которые могут это исправить (зелёные не ломают память и тесты). Если ошибка в самой логике, правило не поможет.')
            for i, e in ipairs(AUTO.terr) do
                if i > 15 then break end
                imgui.TextColored(GRAY, 'Вход:   ' .. u8(e.inp))
                imgui.TextColored(GREEN, 'Нужно:  ' .. u8(e.exp))
                imgui.TextColored(ORANGE, 'Вышло:  ' .. u8(e.got))
                if #e.cands == 0 then imgui.TextColored(RED, '  правилом не выразить (число, большая разница или нужна правка логики)') end
                for k, cd in ipairs(e.cands) do
                    local c = cd.c
                    local txt = (c.kind == 'del') and ('удалить «' .. u8(c.find) .. '»')
                        or ('«' .. u8(c.find) .. '» => «' .. u8(c.repl) .. '»')
                    imgui.TextColored(cd.brk == 0 and GREEN or RED, '  ' .. txt .. '   исправит: ' .. cd.imp .. ', сломает: ' .. cd.brk)
                    if cd.brk == 0 then
                        imgui.SameLine()
                        if imgui.Button('Добавить##aet' .. i .. '_' .. k) then
                            if autoAccept(c, false) then testsLog('rule', u8(e.inp), '', u8(c.find) .. ' => ' .. u8(c.repl)) end
                            autoRun(false); break
                        end
                    end
                end
                imgui.Separator()
            end
        end
        if imgui.CollapsingHeader('Добавлено авто-правилами (' .. #AUTO.added .. ')##autoadd') then
            for i = #AUTO.added, 1, -1 do
                local a = AUTO.added[i]
                if imgui.Button('Откатить##au' .. i) then autoUndo(i); break end
                imgui.SameLine()
                imgui.TextWrapped(os.date('%d.%m %H:%M', a.ts) .. '  ' .. (a.how == 'stray' and '[лишнее слово] ' or '[правка] ')
                    .. u8(a.find) .. (a.kind == 'rep' and ('  =>  ' .. u8(a.repl)) or '  (удаление)'))
            end
        end
        if imgui.CollapsingHeader('Не объяснено правилами (' .. #AUTO.unexplained .. ')##autounx') then
            imgui.TextWrapped('Тут расхождения слишком большие или с числами: их лучше разобрать вручную или попросить доработать логику.')
            for i, p in ipairs(AUTO.unexplained) do
                if i > 12 then break end
                imgui.TextColored(RED, 'почему: ' .. u8(p.why or ''))
                imgui.TextColored(GRAY, 'было:   ' .. u8(p.orig))
                imgui.TextColored(ORANGE, 'хелпер: ' .. u8(p.got))
                imgui.TextColored(GREEN, 'твоё:   ' .. u8(p.final))
                imgui.Separator()
            end
        end
    end

    -- ===== ОФОРМЛЕНИЕ =====
    local TH = {
        enabled = imgui.new.bool(false), border = imgui.new.bool(true),
        alpha = imgui.new.float(0.95), round = imgui.new.float(6), scale = imgui.new.float(1.0),
        bg = imgui.new.float[3](0.07, 0.07, 0.09), acc = imgui.new.float[3](0.20, 0.45, 0.80),
        txt = imgui.new.float[3](0.92, 0.92, 0.92), dirty = true, wasOn = false, saveAt = 0,
    }
    local PRESETS = {
        { 'Тёмная синяя', { 0.07, 0.07, 0.09 }, { 0.20, 0.45, 0.80 }, { 0.92, 0.92, 0.92 } },
        { 'Зелёная', { 0.06, 0.09, 0.07 }, { 0.18, 0.60, 0.30 }, { 0.92, 0.95, 0.92 } },
        { 'Фиолетовая', { 0.09, 0.07, 0.12 }, { 0.55, 0.30, 0.85 }, { 0.95, 0.92, 0.98 } },
        { 'Красная', { 0.10, 0.06, 0.06 }, { 0.75, 0.22, 0.22 }, { 0.96, 0.92, 0.92 } },
        { 'Графит', { 0.12, 0.12, 0.12 }, { 0.45, 0.45, 0.50 }, { 0.90, 0.90, 0.90 } },
        { 'Светлая', { 0.93, 0.93, 0.95 }, { 0.25, 0.50, 0.85 }, { 0.10, 0.10, 0.12 } },
    }
    local function rgb3(a) return { a[0], a[1], a[2] } end
    local function mix(a, b, k) return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k } end
    local function V4(c, al) return ImV4(c[1], c[2], c[3], al or 1) end

    local function themeApply()
        TH.dirty = false
        local style, io = imgui.GetStyle(), imgui.GetIO()
        local rk = { 'WindowRounding', 'ChildRounding', 'FrameRounding', 'PopupRounding', 'ScrollbarRounding',
            'GrabRounding', 'TabRounding' }
        if not TH.enabled[0] then
            if TH.wasOn then                               -- вернули стандартный стиль
                TH.wasOn = false
                imgui.StyleColorsDark()
                for _, k in ipairs(rk) do style[k] = 0 end
                style.WindowBorderSize = 1
                io.FontGlobalScale = 1
            end
            return
        end
        TH.wasOn = true
        local b, a, t = rgb3(TH.bg), rgb3(TH.acc), rgb3(TH.txt)
        local al = TH.alpha[0]
        for _, k in ipairs(rk) do style[k] = TH.round[0] end
        style.WindowBorderSize = TH.border[0] and 1 or 0
        style.ChildBorderSize = TH.border[0] and 1 or 0
        io.FontGlobalScale = TH.scale[0]
        local C = imgui.Col
        local function set(name, v) if C[name] then style.Colors[C[name]] = v end end
        local bord = mix(b, t, 0.22)
        set('Text', V4(t)); set('TextDisabled', V4(mix(t, b, 0.5)))
        set('WindowBg', V4(b, al)); set('ChildBg', V4(mix(b, t, 0.04), al * 0.7)); set('PopupBg', V4(b, math.max(al, 0.92)))
        set('Border', V4(bord)); set('Separator', V4(bord))
        set('FrameBg', V4(mix(b, t, 0.09))); set('FrameBgHovered', V4(mix(b, a, 0.3))); set('FrameBgActive', V4(mix(b, a, 0.5)))
        set('TitleBg', V4(mix(b, a, 0.15))); set('TitleBgActive', V4(mix(b, a, 0.45))); set('TitleBgCollapsed', V4(mix(b, a, 0.15), al))
        set('ScrollbarBg', V4(b, 0.5)); set('ScrollbarGrab', V4(mix(b, t, 0.25)))
        set('ScrollbarGrabHovered', V4(mix(b, a, 0.7))); set('ScrollbarGrabActive', V4(a))
        set('CheckMark', V4(mix(a, t, 0.3))); set('SliderGrab', V4(a)); set('SliderGrabActive', V4(mix(a, t, 0.3)))
        set('Button', V4(mix(b, a, 0.6))); set('ButtonHovered', V4(mix(b, a, 0.85))); set('ButtonActive', V4(mix(a, b, 0.2)))
        set('Header', V4(mix(b, a, 0.4))); set('HeaderHovered', V4(mix(b, a, 0.6))); set('HeaderActive', V4(mix(b, a, 0.8)))
        set('Tab', V4(mix(b, a, 0.3))); set('TabHovered', V4(mix(b, a, 0.8)))
        set('TabActive', V4(mix(b, a, 0.6))); set('TabSelected', V4(mix(b, a, 0.6)))
        set('ResizeGrip', V4(mix(b, a, 0.4))); set('ResizeGripHovered', V4(mix(b, a, 0.7))); set('ResizeGripActive', V4(a))
    end

    local function themeSave()
        pcall(function()
            local f = io.open(DIR .. 'radio24_theme.txt', 'wb')
            if not f then return end
            f:write('enabled=', TH.enabled[0] and '1' or '0', '\n')
            f:write('border=', TH.border[0] and '1' or '0', '\n')
            f:write(string.format('alpha=%.3f\nround=%.1f\nscale=%.2f\n', TH.alpha[0], TH.round[0], TH.scale[0]))
            for _, k in ipairs({ 'bg', 'acc', 'txt' }) do
                f:write(string.format('%s=%.3f,%.3f,%.3f\n', k, TH[k][0], TH[k][1], TH[k][2]))
            end
            f:close()
        end)
    end

    function themeLoad()
        pcall(function()
            local f = io.open(DIR .. 'radio24_theme.txt', 'rb')
            if not f then return end
            for line in f:lines() do
                local k, v = line:match('^(%w+)=(.+)$')
                if k == 'enabled' then TH.enabled[0] = v:sub(1, 1) == '1'
                elseif k == 'border' then TH.border[0] = v:sub(1, 1) == '1'
                elseif k == 'alpha' then TH.alpha[0] = math.max(0.2, math.min(1, tonumber(v) or 0.95))
                elseif k == 'round' then TH.round[0] = math.max(0, math.min(14, tonumber(v) or 6))
                elseif k == 'scale' then TH.scale[0] = math.max(0.8, math.min(1.6, tonumber(v) or 1))
                elseif k == 'bg' or k == 'acc' or k == 'txt' then
                    local x, y, z = v:match('([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)')
                    if x then TH[k][0], TH[k][1], TH[k][2] = tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0 end
                end
            end
            f:close()
        end)
        TH.dirty = true
    end

    local function themeTick()
        if TH.dirty then pcall(themeApply) end
        if TH.saveAt > 0 and os.clock() - TH.saveAt > 0.7 then TH.saveAt = 0; themeSave() end
    end

    local function drawTheme()
        imgui.Separator()
        imgui.TextColored(ORANGE, 'Оформление окна')
        local function ch(enable)
            if enable then TH.enabled[0] = true end
            TH.dirty = true
            TH.saveAt = os.clock()
        end
        if imgui.Checkbox('Своё оформление (выкл - стандартный стиль mimgui)', TH.enabled) then ch(false) end
        imgui.Text('Пресеты:')
        for i, p in ipairs(PRESETS) do
            if (i - 1) % 3 ~= 0 then imgui.SameLine() end
            if imgui.Button(p[1] .. '##pr' .. i, ImV2(150, 0)) then
                for k = 1, 3 do TH.bg[k - 1], TH.acc[k - 1], TH.txt[k - 1] = p[2][k], p[3][k], p[4][k] end
                ch(true)
            end
        end
        if imgui.SliderFloat('Прозрачность фона##th', TH.alpha, 0.2, 1.0, '%.2f') then ch(true) end
        if imgui.SliderFloat('Скругление углов##th', TH.round, 0, 14, '%.0f') then ch(true) end
        if imgui.SliderFloat('Размер текста (масштаб)##th', TH.scale, 0.8, 1.6, '%.2f') then ch(true) end
        if imgui.Checkbox('Рамки окон и блоков##th', TH.border) then ch(true) end
        if imgui.ColorEdit3('Цвет фона##thbg', TH.bg) then ch(true) end
        if imgui.ColorEdit3('Акцентный цвет (кнопки, вкладки)##thac', TH.acc) then ch(true) end
        if imgui.ColorEdit3('Цвет текста##thtx', TH.txt) then ch(true) end
        if imgui.Button('Сбросить оформление##thr') then
            local p = PRESETS[1]
            for k = 1, 3 do TH.bg[k - 1], TH.acc[k - 1], TH.txt[k - 1] = p[2][k], p[3][k], p[4][k] end
            TH.alpha[0], TH.round[0], TH.scale[0], TH.border[0] = 0.95, 6, 1.0, true
            TH.enabled[0] = false
            ch(false)
        end
        imgui.TextColored(GRAY, 'Цвета статусов (зелёный/красный/оранжевый) и цветные кнопки действий остаются прежними.')
    end

    -- ===== ВКЛАДКА "КОНТРАКТЫ" =====
    local ctrKwBuf, ctrAlBuf, ctrAnBuf = imgui.new.char[48](), imgui.new.char[48](), imgui.new.char[96]()
    local ctrOnB, ctrIntB = imgui.new.bool(true), imgui.new.int(300)
    local function drawContractsTab()
        ctrOnB[0] = CTR.on
        if imgui.Checkbox('Проверять контракты у объявлений', ctrOnB) then
            CTR.on = ctrOnB[0]; CTR.ver = CTR.ver + 1; ctrSaveCfg()
        end
        ctrIntB[0] = CTR.interval
        imgui.PushItemWidth(240)
        if imgui.SliderInt('Обновлять каждые, сек##ctri', ctrIntB, 60, 1800) then
            CTR.interval = ctrIntB[0]; ctrSaveCfg()
        end
        imgui.PopItemWidth()
        imgui.SameLine()
        if imgui.Button((CTR.busy and 'Загружаю...' or 'Обновить сейчас') .. '##ctrr') then ctrRefresh() end
        local act = ctrActive()
        imgui.Text('Активных контрактов: ' .. #act .. '   (в списке: ' .. #CTR.list .. ', обновлено: '
            .. (CTR.at > 0 and os.date('%d.%m %H:%M', CTR.at) or 'ещё не загружалось') .. ')')
        if CTR.err ~= '' then wrapColored(RED, u8(CTR.err)) end
        HLP.tip('Источник: radio24.the-waynes.ru. Хелпер ищет в объявлении название контракта (с учётом транслита и падежей: '
            .. 'Алтен = Alten). Нашёл - пишет "Контракт: ЕСТЬ", не нашёл, но в тексте есть слово-триггер - "НЕТ".')
        imgui.BeginChild('##ctrlist', ImV2(-1, 170), true)
        if #act == 0 then imgui.TextWrapped('Активных контрактов нет или список не загружен.') end
        for _, c in ipairs(act) do
            wrapColored(GREEN, u8(c.title) .. '   ' .. u8(c.signer) .. ' | ' .. u8(c.loc) .. ' | ' .. u8(c.cat)
                .. ' | до ' .. os.date('%d.%m %H:%M', c.et) .. ', ' .. ctrLeft(c.et))
        end
        imgui.EndChild()

        imgui.TextColored(ORANGE, 'Слова-триггеры (когда объявлению нужен контракт)')
        HLP.tip('Начало слова: "семь" ловит семья/семью. "=бар" - только точное слово.')
        imgui.PushItemWidth(180)
        imgui.InputText('##ctrkw', ctrKwBuf, ffi.sizeof(ctrKwBuf))
        imgui.PopItemWidth()
        imgui.SameLine()
        if imgui.Button('Добавить слово##ctrka') then
            local ok, msg = ctrKwAdd(getBuf(ctrKwBuf))
            say(msg, ok and 0xFF66FF66 or 0xFFFF6666)
            if ok then setBuf(ctrKwBuf, '') end
        end
        for i, k in ipairs(CTR.kw) do
            if imgui.Button('X##ctrkd' .. i) then ctrKwDel(i); break end
            imgui.SameLine()
            imgui.Text(u8(k))
            if i % 4 ~= 0 and i < #CTR.kw then imgui.SameLine(); imgui.Text('  ') ; imgui.SameLine() end
        end
        imgui.NewLine()
        imgui.Separator()
        imgui.TextColored(ORANGE, 'Синонимы (слово из объявления -> название из контракта)')
        HLP.tip('Если хелпер не узнаёт контракт по написанию: слово из объявления и часть названия контракта.')
        imgui.PushItemWidth(180)
        imgui.InputText('Слово##ctra', ctrAlBuf, ffi.sizeof(ctrAlBuf))
        imgui.InputText('Название##ctrn', ctrAnBuf, ffi.sizeof(ctrAnBuf))
        imgui.PopItemWidth()
        if imgui.Button('Добавить синоним##ctras') then
            local ok, msg = ctrAliasAdd(getBuf(ctrAlBuf), getBuf(ctrAnBuf))
            say(msg, ok and 0xFF66FF66 or 0xFFFF6666)
            if ok then setBuf(ctrAlBuf, ''); setBuf(ctrAnBuf, '') end
        end
        for i, a in ipairs(CTR.alias) do
            if imgui.Button('X##ctrad' .. i) then ctrAliasDel(i); break end
            imgui.SameLine()
            imgui.Text(u8(a.a) .. '  ->  ' .. u8(a.n))
        end
    end

    local function drawSettings()
        local labels = {
            autoRemember = 'Запоминать "исходник -> отправленный текст" автоматически',
            autoSendMemory = 'Автоотправка, если объявление найдено в памяти (осторожно!)',
            dollarPrefix = 'Знак $ перед суммой ($1.500.000)',
            verifyEdit = 'Не отправлять, если правка не применилась (в меню остался старый текст)',
            learn = 'Умная память: учиться на моих правках (замены слов, слова-триггеры отказов)',
            adIsRow = 'Нумерация пунктов меню определяется автоматически (эта галочка больше ни на что не влияет)',
        }
        for _, k in ipairs(BOOLS) do
            if imgui.Checkbox(labels[k], ui[k]) then
                cfg[k] = ui[k][0]
                cfgSave()
            end
        end
        imgui.Separator()
        if imgui.Button('Подсказки: включить везде##hon') then HLP.setAll(true) end
        imgui.SameLine()
        if imgui.Button('Подсказки: выключить везде##hoff') then HLP.setAll(false) end
        HLP.add('Порядок: /edit -> выбрать объявление -> действие -> "Принять". '
            .. 'На каждом шаге есть кнопка "Назад".')
        HLP.add('Команды: /edit, /adm, /adref, /adfix [текст], /adh, /adspy, /adstatus, /adstray, /adctr.')
        HLP.tip('Если что-то не работает: /adstatus, затем /adspy и пройди /edit до конца - '
            .. 'лог в moonloader/config/radio24_dialogs.txt.')
        drawTheme()
    end

    -- Вкладка "Статистика редактора" (раньше - отдельные окна /editstats и "Редактированные объявления")
    function HLP.edsReq()
        if S.screen ~= 'idle' or S.stage or S.menu then
            S.edsBusy = 'Сейчас идёт редактирование - число обновится позже (кнопка "Обновить с сервера").'
            return
        end
        S.edsBusy = nil
        S.edsAuto = os.clock()
        sampSendChat('/editstats')
    end

    function HLP.eds()
        if not S.edsSeen then S.edsSeen = true; HLP.edsReq() end
        imgui.Text('Отредактировано за сегодня (по данным сервера):')
        imgui.SameLine()
        imgui.TextColored(ORANGE, ED.srv and (tostring(ED.srv) .. ' шт.') or 'нет данных')
        imgui.SameLine()
        if imgui.Button('Обновить с сервера##edsr') then HLP.edsReq() end
        HLP.add('Число берётся с сервера (то же, что показывает команда /editstats). Оно обновляется при открытии вкладки и по кнопке "Обновить с сервера"; окно сервера закрывается само.')
        HLP.tip('Список ниже - объявления, отредактированные через хелпер за серверные сутки: время, ник, статус, "Было" и "Стало". Сервер считает все ваши правки, а список - только сделанные через хелпер, пока скрипт запущен.')
        if S.edsBusy then imgui.TextColored(GRAY, S.edsBusy) end
        imgui.TextColored(GRAY, 'В списке хелпера: ' .. #ED.list .. ' шт.'
            .. (ED.day ~= '' and ('  (серверные сутки ' .. u8(ED.day) .. ')') or ''))
        imgui.Separator()
        imgui.BeginChild('##edl', ImV2(-1, -1), true)
        if #ED.list == 0 then imgui.TextWrapped('Пока нет отредактированных объявлений.') end
        for i = #ED.list, 1, -1 do
            local e = ED.list[i]
            imgui.TextColored(BLUE, os.date('%H:%M', e.ts) .. '  ' .. u8(e.nick))
            imgui.SameLine()
            if e.ok == true then imgui.TextColored(GREEN, '[отправлено]')
            elseif e.ok == false then imgui.TextColored(RED, '[не подтверждено]')
            else imgui.TextColored(GRAY, '[?]') end
            imgui.TextColored(GRAY, 'Было:')
            imgui.SameLine()
            imgui.TextWrapped(u8(e.orig))
            imgui.TextColored(GREEN, 'Стало:')
            imgui.SameLine()
            imgui.TextWrapped(u8(e.final))
            imgui.Separator()
        end
        imgui.EndChild()
    end

    -- Меню слева по группам вместо ряда вкладок: {заголовок группы, {id, название}, ...}
    NAV_GROUPS = {
        { 'РАБОТА', { 'ads', 'Объявления (/edit)' }, { 'estats', 'Статистика редактора' } },
        { 'ЗАПОМНЕННОЕ', { 'mem', 'Память правок' }, { 'names', 'Названия и тэги' }, { 'src', 'Образцы (эталоны)' },
            { 'stray', 'Лишние слова' }, { 'tr', 'Свои правила замены' } },
        { 'АВТОМАТИКА', { 'auto', 'Предложенные правила' }, { 'tests', 'Проверка работы' }, { 'ctr', 'Контракты' } },
        { 'ПОМОЩЬ', { 'faq', 'F.A.Q. (вопросы)' }, { 'ref', 'Справочник ПРО' } },
        { 'СИСТЕМА', { 'cfg', 'Настройки' } },
    }
    NAV_PAGES = {
        ads = drawAds, estats = HLP.eds, mem = drawMemory, tr = drawTrules, src = drawSrc, stray = drawStray,
        ctr = drawContractsTab, auto = drawAuto, tests = drawTests, faq = drawFaq, ref = drawRef, cfg = drawSettings,
        names = function() drawNames(); drawTags() end,
    }

    NAV_TITLE = {}
    for _, g in ipairs(NAV_GROUPS) do for k = 2, #g do NAV_TITLE[g[k][1]] = g[k][2] end end
    HLP.help.ads = 'Порядок: введи /edit -> выбери объявление -> выбери действие (отправить как есть / редактировать / удалить / админам) -> "Принять". На каждом шаге есть кнопка "Назад". Варианты - готовые исправленные тексты: бери любой или поправь вручную.'
    HLP.help.faq = 'Нажми на вопрос, чтобы открыть ответ. Не нашёл нужное - напиши разработчику в VK: @bagatir_wayne.'
    HLP.help.ref = 'Краткий пересказ правил ПРО Radio24. В поле "Поиск" можно найти нужный пункт по слову.'

    imgui.OnFrame(function() return win[0] end, function()
        themeTick()
        local sw, sh = getScreenResolution()
        imgui.SetNextWindowSize(ImV2(820, 640), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(ImV2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, ImV2(0.5, 0.5))
        if imgui.Begin('Radio24 | Хелпер объявлений', win) then
            if S.wantTab then S.page = S.wantTab; S.wantTab = nil end      -- переход из команд (/adref, /adauto ...)
            if not NAV_PAGES[S.page] then S.page = 'ads' end
            if S.page ~= 'estats' then S.edsSeen = false end
            imgui.BeginChild('##nav', ImV2(190, 0), true)
            for _, g in ipairs(NAV_GROUPS) do
                imgui.TextColored(GRAY, g[1])
                for i = 2, #g do
                    local p = g[i]
                    local label = p[2]
                    if p[1] == 'auto' and #AUTO.list > 0 then label = label .. ' (' .. #AUTO.list .. ')' end
                    if imgui.Selectable(label .. '##nav' .. p[1], S.page == p[1]) then S.page = p[1] end
                end
                imgui.Spacing()
            end
            imgui.EndChild()
            imgui.SameLine()
            imgui.BeginChild('##page', ImV2(0, 0), false)
            HLP.pending = {}
            imgui.TextColored(ORANGE, NAV_TITLE[S.page] or '')
            if HLP.help[S.page] then imgui.SameLine(); HLP.tip(HLP.help[S.page]) end
            do
                local wcb = imgui.CalcTextSize('Подсказки').x + 40
                imgui.SameLine(math.max(160, imgui.GetWindowWidth() - wcb - 12))
                local hk = 'hint' .. S.page
                HLP.cb[0] = cfg[hk] ~= false
                if imgui.Checkbox('Подсказки##hintcb', HLP.cb) then cfg[hk] = HLP.cb[0]; cfgSave() end
            end
            imgui.Separator()
            safe(NAV_PAGES[S.page])
            imgui.EndChild()
        end
        imgui.End()
        if not win[0] then S.edsSeen = false; onWindowClosed() end
    end)
end

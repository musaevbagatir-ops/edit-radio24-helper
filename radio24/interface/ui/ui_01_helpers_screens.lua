-- radio24/interface/ui/ui_01_helpers_screens.lua: часть 1 из 4 файла interface/ui. окно mimgui (все меню и вкладки). Строки оригинала 3186-3801. Общее окружение модулей, см. radio24_helper.lua
-- Все части работают в общем окружении модулей, порядок частей задан в ORDER загрузчика radio24_helper.lua.
---------------------------------------------------------------------
-- ОКНО (mimgui)
---------------------------------------------------------------------
if okUi then
    ImV2, ImV4 = imgui.ImVec2, imgui.ImVec4
    RED, GREEN, GRAY = ImV4(1, 0.45, 0.45, 1), ImV4(0.5, 1, 0.5, 1), ImV4(0.7, 0.7, 0.7, 1)
    BLUE, ORANGE = ImV4(0.4, 0.8, 1, 1), ImV4(1, 0.7, 0.3, 1)
    local BTN_GREEN = { ImV4(0.15, 0.55, 0.25, 1), ImV4(0.2, 0.68, 0.32, 1), ImV4(0.12, 0.45, 0.2, 1) }
    local BTN_RED = { ImV4(0.65, 0.18, 0.18, 1), ImV4(0.8, 0.25, 0.25, 1), ImV4(0.5, 0.12, 0.12, 1) }
    local BTN_BLUE = { ImV4(0.18, 0.4, 0.7, 1), ImV4(0.25, 0.5, 0.85, 1), ImV4(0.12, 0.3, 0.55, 1) }
    BTN_ORANGE = { ImV4(0.7, 0.45, 0.1, 1), ImV4(0.85, 0.55, 0.15, 1), ImV4(0.55, 0.35, 0.08, 1) }
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

    function safe(f)
        local ok, e = pcall(f)
        if not ok then
            S.lastErr = 'UI: ' .. tostring(e)
            imgui.TextColored(RED, S.lastErr)
        end
    end

    -- цветная кнопка: colors = { обычная, наведение, нажатие }
    function colorButton(label, size, colors)
        imgui.PushStyleColor(imgui.Col.Button, colors[1])
        imgui.PushStyleColor(imgui.Col.ButtonHovered, colors[2])
        imgui.PushStyleColor(imgui.Col.ButtonActive, colors[3])
        local pressed = imgui.Button(label, size)
        imgui.PopStyleColor(3)
        return pressed
    end

    function wrapColored(color, text)
        imgui.PushStyleColor(imgui.Col.Text, color)
        imgui.TextWrapped(text)
        imgui.PopStyleColor()
    end

    -- Подсказки: серая мелкая надпись "(помощь)", при наведении - текст. Включаются галочкой на каждой вкладке.
    HLP = { pending = {}, cb = imgui.new.bool(true), help = {} }
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

    function adHeader(step)
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
    function drawIdle()
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
    function drawList()
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
    function drawWait()
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

    function ctrLeft(et)
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

    function drawActions()
        local m = S.menu
        adHeader('Шаг 2. Что сделать с объявлением?')
        imgui.Text('Текст объявления:')
        wrapColored(ORANGE, u8(S.original))
        local best = S.variants[1]
        if best then
            imgui.Spacing()
            imgui.Text(best.mem and 'Из памяти:' or 'Как исправит хелпер:')
            wrapColored(best.mem and BLUE or GREEN, u8(best.text))
        end
        for _, n in ipairs(S.notes) do wrapColored(RED, '- ' .. u8(n)) end
        for _, r in ipairs(S.reject) do wrapColored(ORANGE, 'Причина для удаления: ' .. u8(shortReason(r))) end
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
    function drawEdit()
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
        if imgui.Button('Правка из моих изменений -> вкладка \"Правки текста\"', ImV2(-1, 28)) then
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
    function drawDelete()
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

end

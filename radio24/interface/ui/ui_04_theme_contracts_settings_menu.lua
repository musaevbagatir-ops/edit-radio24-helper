-- radio24/interface/ui/ui_04_theme_contracts_settings_menu.lua: часть 4 из 4 файла interface/ui. окно mimgui (все меню и вкладки). Строки оригинала 3186-3801. Общее окружение модулей, см. radio24_helper.lua
-- Все части работают в общем окружении модулей, порядок частей задан в ORDER загрузчика radio24_helper.lua.
if okUi then
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
            local f = io.open(cfgPath('radio24_theme.txt'), 'wb')
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
            local f = io.open(cfgPath('radio24_theme.txt'), 'rb')
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
            .. 'лог в moonloader/radio24/config/core/radio24_dialogs.txt.')
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
        { 'ЗАПОМНЕННОЕ', { 'mem', 'Память правок' }, { 'names', 'Названия и тэги' }, { 'tr', 'Правки текста' },
            { 'stray', 'Лишние слова' } },
        { 'АВТОМАТИКА', { 'auto', 'Предложения' }, { 'jrnl', 'Журнал изменений авто-редактирования' }, { 'tests', 'Проверка работы' },
            { 'ctr', 'Контракты' } },
        { 'ПОМОЩЬ', { 'faq', 'F.A.Q. (вопросы)' }, { 'ref', 'Справочник' } },
        { 'СИСТЕМА', { 'cfg', 'Настройки' }, { 'dev', 'Меню разработчика' } },
    }
    NAV_PAGES = {
        ads = drawAds, estats = HLP.eds, mem = drawMemory, tr = drawTrules, jrnl = drawJournal, stray = drawStray,
        ctr = drawContractsTab, auto = drawAuto, tests = drawTests, faq = drawFaq, ref = drawRef, cfg = drawSettings,
        names = function() drawNames(); drawTags() end,
    }

    NAV_TITLE = {}
    for _, g in ipairs(NAV_GROUPS) do for k = 2, #g do NAV_TITLE[g[k][1]] = g[k][2] end end
    HLP.help.ads = 'Порядок: введи /edit -> выбери объявление -> выбери действие (отправить как есть / редактировать / удалить / админам) -> "Принять". На каждом шаге есть кнопка "Назад". Варианты - готовые исправленные тексты: бери любой или поправь вручную.'
    HLP.help.faq = 'Нажми на вопрос, чтобы открыть ответ. Не нашёл нужное - напиши разработчику в VK: @bagatir_wayne.'
    HLP.help.ref = 'Справочник по разделам. Нажми на раздел, чтобы открыть. В разделе "ПРО" - краткий пересказ правил Radio24, в поле "Поиск" можно найти пункт по слову.'

    imgui.OnFrame(function() return win[0] end, function()
        themeTick()
        local sw, sh = getScreenResolution()
        imgui.SetNextWindowSize(ImV2(820, 640), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(ImV2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, ImV2(0.5, 0.5))
        if imgui.Begin('Radio24 | Хелпер объявлений', win) then
            if S.wantTab then S.page = S.wantTab; S.wantTab = nil end      -- переход из команд (/adref, /adauto ...)
            if not NAV_PAGES[S.page] then S.page = 'ads' end
            if S.page ~= 'estats' then S.edsSeen = false end
            imgui.BeginChild('##nav', ImV2(250, 0), true)
            for _, g in ipairs(NAV_GROUPS) do
                imgui.TextColored(GRAY, g[1])
                for i = 2, #g do
                    local p = g[i]
                    local label = p[2]
                    if p[1] == 'auto' and #AUTO.list > 0 then label = label .. ' (' .. #AUTO.list .. ')' end
                    if imgui.Selectable(label .. '##nav' .. p[1], S.page == p[1]) then
                        if p[1] == 'dev' then      -- меню разработчика открывается только у разработчика, остальным пишем в чат
                            if not (type(DEVMENU_TOGGLE) == 'function' and GUARD and GUARD.dev and DEVMENU_TOGGLE()) then say(T('Нет доступа'), 0xFFFF6666) end
                        else S.page = p[1] end
                    end
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

-- radio24/interface/ui/ui_02_tabs_ads_memory_ref.lua: часть 2 из 4 файла interface/ui. окно mimgui (все меню и вкладки). Строки оригинала 3186-3801. Общее окружение модулей, см. radio24_helper.lua
-- Все части работают в общем окружении модулей, порядок частей задан в ORDER загрузчика radio24_helper.lua.
if okUi then
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

    function drawAds()
        local sc = S.screen
        if sc == 'list' then drawList()
        elseif sc == 'wait' then drawWait()
        elseif sc == 'actions' and S.menu then drawActions()
        elseif sc == 'edit' then drawEdit()
        elseif sc == 'delete' then drawDelete()
        elseif sc == 'admin' then drawAdmin()
        else drawIdle() end
    end

    function drawMemory()
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

        imgui.Spacing()
        wrapColored(GRAY, 'Выученные замены больше не хранятся отдельно: они перенесены в "Правки текста" (замены) и "Лишние слова" (удаление слов). Новые правила подбирает вкладка "Предложения".')
    end

    function drawTrules()
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
        imgui.TextColored(GRAY, 'Журнал добавленных правок и откат: вкладка «Журнал изменений авто-редактирования».')
    end

    local catBufs = {}
    local catNewBuf, catKwBuf, catPfBuf
    function drawNames()
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

    -- Справочник: список разделов из REFBOOK (interface/refbook.lua). Первый раздел "ПРО" - то, что раньше было вкладкой целиком.
    -- Открытый раздел хранится в S.refSec (nil = список разделов).
    function drawRef()
        local sec
        if S.refSec then for _, s in ipairs(REFBOOK) do if s.id == S.refSec then sec = s end end end
        if not sec then
            S.refSec = nil
            imgui.TextWrapped('Выбери раздел справочника.')
            imgui.Spacing()
            for _, s in ipairs(REFBOOK) do
                if imgui.Button(s.title .. '##refsec' .. s.id, ImV2(260, 32)) then S.refSec = s.id end
                if s.hint and s.hint ~= '' then imgui.SameLine(); imgui.TextColored(GRAY, s.hint) end
            end
            return
        end
        if imgui.Button('< К разделам##refback') then S.refSec = nil; return end
        imgui.SameLine()
        imgui.TextColored(ORANGE, sec.title)
        imgui.Separator()
        safe(sec.draw)
    end

    -- Раздел "ПРО": краткий пересказ правил с поиском (данные REF лежат в processing/reference.lua)
    function drawRefPro()
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
    strayWordBuf, strayCtxBuf = imgui.new.char[320](), imgui.new.char[192]()
    STRAY_KINDS = { learn = 'запомнено', weak = 'ослаблено (слово оставлено)',
        manual = 'добавлено/изменено вручную', apply = 'убрано в объявлении' }

end

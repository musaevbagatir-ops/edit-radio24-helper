-- radio24/interface/ui/ui_03_tabs_stray_tags_tests_auto.lua: часть 3 из 4 файла interface/ui. окно mimgui (все меню и вкладки). Строки оригинала 3186-3801. Общее окружение модулей, см. radio24_helper.lua
-- Все части работают в общем окружении модулей, порядок частей задан в ORDER загрузчика radio24_helper.lua.
if okUi then
    function drawStray()
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
    function drawTags()
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

    function drawTests()
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

    function drawAuto()
        HLP.tip('Самообучение сравнивает текст хелпера с твоими правками из памяти и тестов и подбирает правку: либо в "Правки текста", '
            .. 'либо в "Лишние слова". Сама ничего не добавляет: ты нажимаешь Принять или Отклонить. Предложение показывается только если оно '
            .. 'исправляет хотя бы одну пару и не конфликтует: не ломает пары памяти и тесты, не противоречит существующим правкам, словарю и названиям. '
            .. 'Всё принятое пишется в журнал и откатывается там.')
        if imgui.Button('Пересчитать##autorun') then autoRun() end
        imgui.SameLine()
        imgui.Text('пар (память + тесты): ' .. AUTO.nPairs .. ', совпадает: ' .. AUTO.nOk
            .. ', предложений: ' .. #AUTO.list .. ', отброшено из-за конфликтов: ' .. AUTO.nConf)
        if AUTO.stale then imgui.TextColored(ORANGE, 'В памяти есть новые правки: нажми Пересчитать.') end
        if AUTO.err ~= '' then imgui.TextColored(RED, u8(AUTO.err)) end
        local nrej = 0
        for _ in pairs(AUTO.rej) do nrej = nrej + 1 end
        imgui.Text('Отклонённых предложений: ' .. nrej)
        imgui.SameLine()
        if imgui.Button('Сбросить отклонённые##arj') then AUTO.rej = {}; autoSave() end
        imgui.Separator()
        imgui.TextColored(ORANGE, 'Предложения')
        imgui.BeginChild('##autolist', ImV2(-1, 220), true)
        if #AUTO.list == 0 then imgui.TextWrapped('Пока нет. Нажми Пересчитать или добавь больше правок в память.') end
        for i, c in ipairs(AUTO.list) do
            if imgui.Button('Принять##aa' .. i) then
                autoAccept(c, false); autoRun(); break
            end
            imgui.SameLine()
            if imgui.Button('Отклонить##ar' .. i) then autoReject(c); autoRun(); break end
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Text, GREEN)
            imgui.TextWrapped('[' .. (c.target == 'stray' and 'Лишние слова' or 'Правки текста') .. '; исправит пар: ' .. c.improved
                .. ', подтверждений: ' .. (c.support or 0) .. '] '
                .. (c.kind == 'del' and ('убрать  "' .. u8(c.find) .. '"') or ('"' .. u8(c.find) .. '"  =>  "' .. u8(c.repl) .. '"')))
            imgui.PopStyleColor()
            if c.ex then imgui.TextColored(GRAY, '      пример [' .. u8(c.ex.src or '') .. ']: ' .. u8(c.ex.orig)) end
        end
        imgui.EndChild()
        if imgui.CollapsingHeader('Отброшено из-за конфликтов (' .. AUTO.nConf .. ')##autoconf') then
            imgui.TextWrapped('Эти правки исправили бы пару, но конфликтуют с тестами, памятью или текущими правилами, поэтому не предлагаются.')
            for i, e in ipairs(AUTO.conf) do
                if i > 20 then break end
                local c = e.c
                imgui.TextColored(RED, '  ' .. (c.kind == 'del' and ('убрать "' .. u8(c.find) .. '"') or ('"' .. u8(c.find) .. '" => "' .. u8(c.repl) .. '"')))
                imgui.TextColored(GRAY, '      причина: ' .. u8(e.why))
            end
        end
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
                    local txt = (c.kind == 'del') and ('удалить "' .. u8(c.find) .. '"')
                        or ('"' .. u8(c.find) .. '" => "' .. u8(c.repl) .. '"')
                    imgui.TextColored(cd.brk == 0 and GREEN or RED, '  ' .. txt .. '   исправит: ' .. cd.imp .. ', сломает: ' .. cd.brk)
                    if cd.brk == 0 then
                        imgui.SameLine()
                        if imgui.Button('Добавить##aet' .. i .. '_' .. k) then
                            if autoAccept(c, false) then testsLog('rule', u8(e.inp), '', u8(c.find) .. ' => ' .. u8(c.repl)) end
                            autoRun(); break
                        end
                    end
                end
                imgui.Separator()
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

    function drawJournal()
        HLP.tip('Общий журнал: добавленные названия, тэги, правки текста, лишние слова и выученные замены. Кнопка "Откатить" убирает '
            .. 'настройку и запись. Править правило можно в его разделе (Названия и тэги, Правки текста, Лишние слова). '
            .. 'Объявления памяти сюда не попадают, у них свой список во вкладке Память правок.')
        local FILT = { { 'all', 'Все' }, { T('название'), 'Названия' }, { T('тег'), 'Тэги' }, { T('правка'), 'Правки текста' },
            { T('лишнее'), 'Лишние слова' } }
        S.jFilter = S.jFilter or 'all'
        for i, fl in ipairs(FILT) do
            if i > 1 then imgui.SameLine() end
            if imgui.Button((S.jFilter == fl[1] and '> ' or '') .. fl[2] .. '##jf' .. i) then S.jFilter = fl[1] end
        end
        imgui.SameLine()
        if imgui.Button('Очистить журнал##jclr') then LEARNLOG = {}; learnLogSave() end
        imgui.Text('Записей: ' .. #LEARNLOG)
        local named = { [T('название')] = true, [T('тег')] = true, [T('правка')] = true, [T('лишнее')] = true }
        imgui.BeginChild('##jrnl', ImV2(-1, -1), true)
        for i = #LEARNLOG, 1, -1 do
            local l = LEARNLOG[i]
            local k = l.kind
            local pass = S.jFilter == 'all' or S.jFilter == k or (S.jFilter == 'learn' and not named[k])
            if pass then
                imgui.TextColored(GRAY, os.date('%d.%m %H:%M', l.ts))
                imgui.SameLine()
                imgui.TextColored(named[k] and ORANGE or BLUE, '[' .. u8(k) .. ']')
                imgui.SameLine()
                local txt
                if k == T('название') then txt = u8(l.val) .. '  (' .. u8(l.key) .. ')'
                elseif k == T('тег') then txt = '[' .. u8(l.val) .. ']'
                elseif k == T('правка') then txt = '"' .. u8(l.key) .. '" => ' .. (l.val ~= '' and ('"' .. u8(l.val) .. '"') or '(удалить)')
                elseif k == T('лишнее') then txt = 'убирать слово: ' .. u8(l.key)
                else txt = u8((ctxSplit(l.key))) .. '  =>  ' .. (l.val ~= '' and u8(l.val) or '(убрать слово)') end
                imgui.TextWrapped(txt)
                if (k == T('правка') or k == T('лишнее')) and l.ad ~= '' then imgui.TextColored(GRAY, '      источник: ' .. u8(l.ad)) end
                if imgui.Button('Откатить##jr' .. i) then learnLogUndo(i); break end
                imgui.Separator()
            end
        end
        imgui.EndChild()
    end

end

-- radio24/core/app.lua: main: команды чата. Строки оригинала 3802-3891. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- main: только команды чата, горячих клавиш нет
---------------------------------------------------------------------
function main()
    while not isSampAvailable() do wait(100) end
    ensureDir()
    cfgLoad()
    if okUi then for _, k in ipairs(BOOLS) do ui[k][0] = cfg[k] end end
    memLoad()
    learnLoad()
    namesLoad()
    catsLoad()
    peopleLoad()
    catPrefLoad()
    ctrLoadCfg()
    ctrLoadCache()
    TX.load()
    statLoad()
    strayLoad()
    if okUi then themeLoad() end
    refBuild()
    refSeedNames()
    pcall(namesPurgeBad)
    edLoad()
    autoLoad()
    testsLoad()
    tagsLoad()

    local function guardCmdBlocked()
        if GUARD and GUARD.locked and not GUARD.dev then
            say(GUARD.checked and T('Хелпер недоступен для вашего ранга.') or T('Хелпер заблокирован: ожидается автоматическая проверка ранга через /find.'), 0xFFFF6666)
            return true
        end
        return false
    end

    sampRegisterChatCommand('adfix', function(arg)
        if guardCmdBlocked() then return end
        if arg == '' then say(T('Использование: /adfix [текст объявления]')); return end
        loadAd(arg, '')
        if okUi then
            S.menu = nil
            setScreen('edit')
            win[0] = true
            S.wantTab = 'ads'
        end
    end)

    sampRegisterChatCommand('adnames', function(arg)
        if guardCmdBlocked() then return end
        arg = trim(arg or '')
        local d = arg:match('^del%s+(.+)$')
        if d then
            say(namesDel(d) and T('Название удалено.') or T('Такого названия нет.'))
            return
        end
        local by, order = namesSummary()
        if #order == 0 then say(T('Названий в памяти пока нет.')); return end
        for _, c in ipairs(order) do
            table.sort(by[c])
            say(c .. ' (' .. #by[c] .. '): ' .. table.concat(by[c], ', '))
        end
        say(T('Удалить: /adnames del название'))
    end)

    sampRegisterChatCommand('adm', function()
        if guardCmdBlocked() then return end
        if okUi then win[0] = not win[0] else say(T('mimgui не найден.'), 0xFFFF6666) end
    end)

    sampRegisterChatCommand('adfaq', function()
        if guardCmdBlocked() then return end
        if okUi then win[0] = true; S.wantTab = 'faq' else say(T('mimgui не найден.'), 0xFFFF6666) end
    end)

    sampRegisterChatCommand('adref', function()
        if guardCmdBlocked() then return end
        if okUi then win[0] = true; S.wantTab = 'ref'; S.refSec = 'pro' else say(T('mimgui не найден.'), 0xFFFF6666) end
    end)

    sampRegisterChatCommand('adh', function()
        if guardCmdBlocked() then return end
        cfg.enabled = not cfg.enabled
        say(cfg.enabled and T('Хелпер включён.') or T('Хелпер выключен.'))
    end)

    sampRegisterChatCommand('adspy', function()
        if guardCmdBlocked() then return end
        spy = not spy
        say(spy and T('Лог диалогов включён: moonloader/radio24/config/core/radio24_dialogs.txt')
            or T('Лог диалогов выключен.'))
    end)

    sampRegisterChatCommand('adtest', function(arg)
        if guardCmdBlocked() then return end
        -- /adtest [pro] [страница]: по умолчанию ПОЛНЫЙ режим (buildVariants: названия, тэги, правки текста, лишние слова);
        -- "pro" - только основная логика ПРО (fixText). Память, статистика и обученные правила не меняются.
        local a = lo(trim(arg or ''))
        local mode = a:find('pro', 1, true) and 'pro' or (a:find('noctr', 1, true) and 'noctr' or (a:find('names', 1, true) and 'names' or 'full'))
        local page = math.max(1, tonumber(a:match('%d+')) or 1)
        local ok, bad = KB.selftest(mode)
        say(({ pro = T('[ПРО] как раньше (fixText): верно='),
               full = T('[ПОЛНЫЙ] как в меню, без памяти и обучения: верно='),
               names = T('[ПОЛНЫЙ+НАЗВАНИЯ] + названия из других тестов: верно='),
               noctr = T('[ПОЛНЫЙ без контрактов]: верно=') })[mode]
            .. ok .. T(', ошибок=') .. #bad .. T(', всего=') .. (ok + #bad))
        pcall(function()                                   -- полный отчёт в файл (UTF-8)
            local f = io.open(cfgPath('radio24_adtest.txt'), 'wb')
            if not f then return end
            f:write('Режим: ', ({ pro = 'ПРО (fixText, как раньше)', full = 'ПОЛНЫЙ (buildVariants, без памяти и обучения)',
                names = 'ПОЛНЫЙ + НАЗВАНИЯ (временно из ожидаемых текстов других тестов)',
                noctr = 'ПОЛНЫЙ без шага "контракты"' })[mode], '\n\n')
            for i, b in ipairs(bad) do
                f:write(i, '.\nВход:  ', b[1], '\nНужно: ', b[2], '\nВышло: ', u8(b[3]), '\n')
                local x = b[5]
                if x then
                    if x.label ~= '' then f:write('Вариант: ', u8(x.label), '\n') end
                    f:write('Сработало: ', x.notes ~= '' and u8(x.notes) or '(ничего)', '\n')
                    if #x.alts > 0 then f:write('Ожидаемый текст есть среди вариантов: ', u8(table.concat(x.alts, ', ')), '\n') end
                    for _, w in ipairs(x.why) do f:write('Не применилось: ', u8(w), '\n') end
                end
                f:write('\n')
            end
            f:close()
        end)
        local from = (page - 1) * 4 + 1
        for i = from, math.min(#bad, from + 3) do
            say(i .. '. ' .. T('Вход: ') .. T(bad[i][1])); say(T('Нужно: ') .. T(bad[i][2])); say(T('Вышло: ') .. bad[i][3], 0xFFFF6666)
            local x = bad[i][5]
            if x then
                if x.notes ~= '' then say(T('Сработало: ') .. x.notes) end
                if #x.alts > 0 then say(T('Нужный текст есть среди вариантов: ') .. table.concat(x.alts, ', ')) end
                for _, w in ipairs(x.why) do say(T('Не применилось: ') .. w) end
            end
        end
        if #bad > from + 3 then say(T('Дальше: /adtest ') .. (mode ~= 'full' and (mode .. ' ') or '') .. (page + 1) .. T('. Все ошибки в radio24/config/security/radio24_adtest.txt')) end
    end)

    sampRegisterChatCommand('adstatus', function()
        if guardCmdBlocked() then return end
        local n = 0
        for _ in pairs(MEM) do n = n + 1 end
        say(string.format('mimgui=%s enabled=%s hook=%d memory=%d stage=%s screen=%s',
            tostring(okUi), tostring(cfg.enabled), S.hookCount, n, tostring(S.stage), S.screen))
        local ln = 0
        for _ in pairs(LEARN) do ln = ln + 1 end
        say('learned rules=' .. ln)
        say(string.format('last dialog: style=%d title=%s', S.lastStyle, S.lastTitle))
        say('menu=' .. tostring(S.menu ~= nil) .. ' list=' .. tostring(#S.items))
        if S.lastErr ~= '' then say('error: ' .. S.lastErr, 0xFFFF4444) end
    end)

    if okUi then
        say(T('Загружен V') .. tostring(thisScript().version) .. T('. /edit - меню хелпера, /adfaq - справка.'))
    else
        say(T('mimgui не найден - окно недоступно. Установи mimgui.'), 0xFFFF6666)
    end
    say(T('Разработчик: Bagatir_Wayne. Нашли баг или есть идея, как улучшить хелпер - пишите в VK: @bagatir_wayne'))

    sampRegisterChatCommand('adstray', function()
        if guardCmdBlocked() then return end
        if okUi then win[0] = true; S.wantTab = 'stray' else say(T('mimgui не найден.'), 0xFFFF6666) end
    end)

    sampRegisterChatCommand('adstats', function()
        if guardCmdBlocked() then return end
        if okUi then win[0] = true; S.wantTab = 'estats' else say(T('mimgui не найден.'), 0xFFFF6666) end
    end)

    sampRegisterChatCommand('adedits', function()
        if guardCmdBlocked() then return end
        if okUi then win[0] = true; S.wantTab = 'estats' else say(T('mimgui не найден.'), 0xFFFF6666) end
    end)

    -- серверная дата для суточного сброса: тихо открываем статистику персонажа и закрываем её
    lua_thread.create(function()
        wait(8000)
        if cfg.enabled and okUi and ED.cur == '' and not S.stage and not S.menu and S.screen == 'idle' then
            S.silentStats = true
            sampSendChat('/stats')
            wait(4000)
            S.silentStats = false
        end
    end)

    sampRegisterChatCommand('adctr', function()
        if guardCmdBlocked() then return end
        if okUi then win[0] = true; S.wantTab = 'ctr' else say(T('mimgui не найден.'), 0xFFFF6666) end
    end)

    -- контракты: первая загрузка и обновление по таймеру
    lua_thread.create(function()
        wait(5000)
        while true do
            if CTR.on then ctrRefresh() end
            wait(CTR.interval * 1000)
        end
    end)

    sampRegisterChatCommand('adtests', function()
        if guardCmdBlocked() then return end
        if okUi then win[0] = true; S.wantTab = 'tests' else say(T('mimgui не найден.'), 0xFFFF6666) end
    end)

    sampRegisterChatCommand('adauto', function()
        if guardCmdBlocked() then return end
        if okUi then win[0] = true; S.wantTab = 'auto' else say(T('mimgui не найден.'), 0xFFFF6666) end
    end)

    sampRegisterChatCommand('adlog', function()
        if guardCmdBlocked() then return end
        if okUi then win[0] = true; S.wantTab = 'jrnl' else say(T('mimgui не найден.'), 0xFFFF6666) end
    end)

    while true do
        wait(30)
        pcall(laterPump)
    end
end

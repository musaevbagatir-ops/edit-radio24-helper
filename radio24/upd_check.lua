-- radio24/upd_check.lua: (1) сверка версии с хостингом. При отличии запускает установщик (upd_install).
-- Хостинг: UPD.base + 'version.txt'. Формат version.txt:
--   version=7.1
--   file=radio24_helper.lua
--   file=radio24/core.lua          (по строке на каждый обновляемый файл, только .lua)
--   dataver=5                      (номер набора данных; поднимай при каждом пополнении config/*)
--   data=radio24_names.txt         (файл лежит в репозитории: config/radio24_names.txt; у пользователя ОБЪЕДИНЯЕТСЯ трёхсторонне:
--                                  новые записи добавляются, изменённые тобой заменяются, правки пользователя сохраняются.
--                                  База для сравнения хранится у пользователя в config\radio24_base\ и обновляется сама)
--                                  новые записи добавляются, изменённые тобой заменяются, правки пользователя сохраняются; отдельные команды правки строк для них не нужны.
--                                  База для сравнения хранится у пользователя в config\radio24_base\ и обновляется сама)
--   force=radio24_settings.txt|learn|1        (необязательно: принудительно изменить конфиг)
--   addkey=файл|ключ|значение                 (добавить key=value, если такого ключа нет; существующий НЕ меняет)
--   (команды работают только с файлами radio24_*.txt, кроме служебных; ключи BOOLS добавляются сами при старте)
-- Команды: /adupd (проверить и установить) | /adupd check | /adupd auto. Адрес хостинга пользователь менять не может (задан в upd_install.lua)
UPD.notified = nil
local origMain = main

function updParse(raw)
    local m = { files = {}, ops = {}, data = {}, dataver = 0 }
    for l in raw:gmatch('[^\r\n]+') do
        l = l:gsub('^%s+', ''):gsub('%s+$', '')
        local k, v = l:match('^(%a+)=(.*)$')
        if l:sub(1, 1) ~= '#' and k then
            if k == 'version' then m.version = v:match('^%d+[%d%.]*$')
            elseif k == 'file' then
                if v:match('^[%w_%-/]+%.lua$') and not v:find('..', 1, true) and v:sub(1, 1) ~= '/' then m.files[#m.files + 1] = v end
            elseif k == 'data' then
                if v:match('^radio24_[%w_]+%.txt$') then m.data[#m.data + 1] = v end
            elseif k == 'dataver' then m.dataver = tonumber(v) or 0
            elseif k == 'force' or k == 'addkey' then
                if ucfgOpFile(k, v) then m.ops[#m.ops + 1] = { kind = k, val = v } end
            end
        end
    end
    if not m.version then return nil, T('в version.txt нет версии') end
    if #m.files == 0 and #m.data == 0 then return nil, T('в version.txt нет списка файлов') end
    return m
end

function updFetch()
    local s = updDownload(UPD.base .. 'version.txt?t=' .. os.time(), UCFG.dir .. 'radio24_upd_tmp.dat')
    if not s then return nil, T('сервер обновлений не отвечает (проверь интернет или напиши разработчику)') end
    return updParse(s)
end

-- manual=true: пишет результат в чат и ставит сразу; иначе (авто) ставит только при UPD.auto и когда нет активной работы
function updRun(manual)
    if UPD.busy then return end
    local m, err = updFetch()
    if not m then
        if manual then say(T('Обновление: ') .. tostring(err), 0xFFFF6666) end
        return
    end
    local codeNew = verCmp(m.version, thisScript().version) > 0
    local locData = tonumber((ucfgRead('radio24_dataver.txt') or ''):match('%d+')) or 0
    local dataNew = #m.data > 0 and m.dataver > locData
    -- защита: версия, установка которой уже ломалась (не совпала версия в helper), сама не ставится; ручной /adupd снимает блок
    local blk = (ucfgRead('radio24_updblock.txt') or ''):match('%d[%d%.]*')
    if codeNew and blk then
        if manual then pcall(os.remove, UCFG.dir .. 'radio24_updblock.txt')
        elseif verCmp(m.version, blk) <= 0 then codeNew = false end
    end
    if not codeNew then m.files, m.ops = {}, {} end      -- код не менялся: ставим только данные
    if not codeNew and not dataNew then
        if manual then say(T('У вас последняя версия: ') .. thisScript().version, 0xFF66FF66) end
        return
    end
    if not manual and not UPD.auto then
        if UPD.notified ~= m.version .. '/' .. m.dataver then
            UPD.notified = m.version .. '/' .. m.dataver
            say(T('Доступна версия ') .. m.version .. T('. Установить: /adupd'), 0xFF66CCFF)
        end
        return
    end
    if not manual then                                  -- не мешаем работе с объявлением
        for _ = 1, 120 do
            if not (S.stage or S.sending or S.menu) then break end
            wait(5000)
        end
    end
    updInstall(m)
end

-- строки для version.txt складываются в config\radio24_migout.txt (без дублей)
local function migOut(line)
    local cur = ucfgRead('radio24_migout.txt') or ''
    for l in cur:gmatch('[^\r\n]+') do if l == line then return false end end
    ucfgWrite('radio24_migout.txt', cur .. line .. '\n')
    return true
end

local function updCommands()
    -- /addmigration              - добавить в config недостающие ключи настроек (они же добавляются сами при старте у всех)
    -- /addmigration файл ключ значение  - добавить ключ в файл сейчас и записать строку addkey=... для version.txt
    sampRegisterChatCommand('addmigration', function(arg)
        arg = trim(arg or '')
        if arg == '' then
            local ok, add = pcall(ucfgSyncSettings)
            if ok and #add > 0 then say(T('Добавлены ключи настроек: ') .. table.concat(add, ', '), 0xFF66FF66)
            else say(T('Все ключи настроек уже есть в конфиге. Новые ключи из BOOLS подхватываются сами при запуске у всех.'), 0xFF66FF66) end
            return
        end
        local f, k, v = arg:match('^([^|%s]+)[|%s]+([%w_]+)[|%s=]+(.*)$')
        if not f or not ucfgOpFile('addkey', f .. '|' .. k .. '|' .. v) then
            say(T('Использование: /addmigration  или  /addmigration radio24_settings.txt ключ значение'), 0xFFFF6666)
            return
        end
        v = trim(v)
        local added = ucfgAddKeys(f, { { k, v } })
        local line = 'addkey=' .. f .. '|' .. k .. '|' .. v
        migOut(line)
        say((added and T('Ключ добавлен: ') or T('Ключ уже был (не менял): ')) .. k .. '=' .. v, 0xFF66FF66)
        say(T('Для всех пользователей вставь в version.txt: ') .. line .. T('  (записано в config\\radio24_migout.txt)'), 0xFF66CCFF)
    end)
    sampRegisterChatCommand('adupd', function(arg)
        arg = trim(arg or '')
        if arg == 'auto' then
            UPD.auto = not UPD.auto
            updSaveCfg()
            say(UPD.auto and T('Автообновление: ставить новые версии само.') or T('Автообновление: только уведомлять.'))
        elseif arg == 'check' then
            lua_thread.create(function()
                local m, err = updFetch()
                if not m then say(T('Обновление: ') .. tostring(err), 0xFFFF6666)
                elseif verCmp(m.version, thisScript().version) > 0 then say(T('Доступна версия ') .. m.version .. T(' (у вас ') .. thisScript().version .. T('). Установить: /adupd'), 0xFF66CCFF)
                else say(T('У вас последняя версия: ') .. thisScript().version, 0xFF66FF66) end
            end)
        else
            lua_thread.create(function() updRun(true) end)
        end
    end)
end

main = function()
    pcall(ucfgStartup)                                  -- донастройка конфигов ДО загрузки данных основным скриптом
    pcall(updLoadCfg)
    lua_thread.create(function()
        while not isSampAvailable() do wait(200) end
        updCommands()
        if UCFG.justUpdated then
            wait(2500)
            say(T('Скрипт обновлён до версии ') .. UCFG.justUpdated .. T('. Конфиги сохранены и дополнены.'), 0xFF66FF66)
        end
        if UCFG.keysAdded and #UCFG.keysAdded > 0 then
            wait(2500)
            say(T('Добавлены новые настройки в конфиг: ') .. table.concat(UCFG.keysAdded, ', '), 0xFF66FF66)
        end
        if UCFG.err then
            wait(2500)
            say(T('Конфиг/обновление: ') .. tostring(UCFG.err), 0xFFFF6666)
        end
        local dA, dC, dR = UCFG.dataAdded or 0, UCFG.dataChanged or 0, UCFG.dataRemoved or 0
        if dA + dC + dR > 0 and not UCFG.justUpdated then
            wait(2500)
            say(T('Данные самообучения обновлены из общей базы: добавлено ') .. dA .. T(', изменено ') .. dC .. T(', убрано ') .. dR .. T('. Ваши записи сохранены.'), 0xFF66FF66)
        end
        wait(15000)                                     -- проверка ОДИН раз при заходе в игру
        pcall(updRun, false)
    end)
    origMain()
end

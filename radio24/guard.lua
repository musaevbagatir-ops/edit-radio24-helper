-- radio24/guard.lua: защита хелпера по рангу и от подмены.
-- 1) сверяет себя с копией на GitHub; 2) после спавна открывает /find и читает свой ранг;
-- 3) запрещённый ранг или подмена: скрипт выгружается, будто его нет.
-- Эталон - файлы на GitHub. Адрес берётся из upd_install.lua (GH_USER / GH_REPO / GH_BRANCH).
-- Выпуск правки: поднять script_version и version= в version.txt, залить файлы на GitHub.
local RANKS, RSIG = '1', 3522041097 --@ranks
GUARD = { token = 'r24ok', rank = nil, nick = '', id = -1, dev = false, locked = true,
    checked = false, checking = false, ranksOk = false, blocked = {}, ranksStr = RANKS, sim = nil }
local E = getfenv(1)
local REPO_BASE = 'https://raw.githubusercontent.com/musaevbagatir-ops/edit-radio24-helper/main/'   -- второй замок: адрес репозитория зашит и здесь
local SALT = 'r24:ranks:'
local DEVA, DEVB = 1114720514, 38514187   -- отпечаток ключа из devmenu.lua

local function hA(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i) + 7) % 4294967291 end
    return h
end
local function hB(s)
    local h = 52711
    for i = #s, 1, -1 do h = (h * 131 + s:byte(i) + 3) % 4294967279 end
    return h
end
local function parseRanks()
    GUARD.ranksOk = (hA(SALT .. RANKS) == RSIG)
    local set = {}
    for n in RANKS:gmatch('%d+') do set[tonumber(n)] = true end
    GUARD.blocked, GUARD.ranksStr = set, RANKS
end
parseRanks()

local function rankAllowed(r)
    return GUARD.ranksOk and r ~= nil and not GUARD.blocked[r]
end

local function myId()
    local ok, r, id = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    return (ok and r and id) or -1
end

local function warn(s) say(T(s), 0xFFFF6666) end

local function shutdown(reason, chat)
    GUARD.locked = true
    print('[radio24] guard: ' .. reason)
    if chat then warn(chat) end
    thisScript():unload()
    wait(-1)
end

---------------------------------------------------------------------
-- Проверка ранга через /find
---------------------------------------------------------------------
-- Строка: ID - Уровень - Телефон - Ранг - Выговоры - Имя   (94 - 18 - 247347 - 7 - 0/3 - Leo_Moretto [AFK: 1:00])
local function parseFindRank(text, nick, id)
    local wanted = (nick or ''):lower()
    for line in stripColors(text or ''):gmatch('[^\r\n]+') do
        local pid, rank, name = line:match('^%s*(%d+)%s*%-%s*%d+%s*%-%s*%d+%s*%-%s*(%d+)%s*%-%s*[%d/]+%s*%-%s*([%w_%[%]%.%$@=%(%)]+)')
        if name and name:lower() == wanted and (id == nil or tonumber(pid) == id) then
            return tonumber(rank)
        end
    end
    return nil
end
GUARD.parse = parseFindRank

function guardDialog(id, style, title, button1, button2, text)
    if not GUARD.checking then return false end
    -- T() обязателен: сервер присылает CP1251, а файл записан в UTF-8
    if not lo(stripColors(title or '')):find(T('члены организации'), 1, true) then return false end
    GUARD.found = parseFindRank(text, GUARD.nick, GUARD.id)
    GUARD.answered = true
    if not GUARD.found then      -- на случай другого формата: сохраняем окно для разбора
        local f = io.open(getWorkingDirectory() .. '\\config\\radio24_find.txt', 'wb')
        if f then f:write(tostring(GUARD.nick), ' ', tostring(GUARD.id), '\n', tostring(text)); f:close() end
    end
    GUARD.checking = false
    lua_thread.create(function()
        wait(100)
        pcall(sampSendDialogResponse, id, 0, -1, '')
    end)
    return true
end

-- возвращает ранг или nil; вызывать только из потока
local function askRank()
    for _ = 1, 3 do
        GUARD.nick, GUARD.id = myNick(), myId()
        if GUARD.nick ~= '' and GUARD.id >= 0 then
            GUARD.found, GUARD.answered, GUARD.checking = nil, false, true
            sampSendChat('/find')
            local till = os.clock() + 6
            while not GUARD.answered and os.clock() < till do wait(100) end
            GUARD.checking = false
            if GUARD.answered then wait(400) end   -- дать потоку guardDialog закрыть окно /find до возможной выгрузки скрипта
            if GUARD.found then return GUARD.found end
        end
        wait(3000)
    end
    return nil
end

GUARD.ask = function()
    if GUARD.checking then return end
    lua_thread.create(function()
        GUARD.rank = askRank()
        say(T('Ваш ранг по /find: ') .. tostring(GUARD.rank or '?'))
    end)
end

---------------------------------------------------------------------
-- Сверка с GitHub
---------------------------------------------------------------------
local function readFile(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local s = f:read('*a'); f:close()
    return s
end

local function writeFile(path, s)
    local f = io.open(path, 'wb')
    if not f then return false end
    f:write(s); f:close()
    return true
end

local function normalize(s)
    return (s:gsub('^\239\187\191', ''):gsub('\r\n', '\n'):gsub('%s+$', ''))
end

-- файлы, которые должны совпадать с GitHub байт в байт (кроме переводов строк)
local PROTECTED = { 'radio24_helper.lua', 'radio24/guard.lua', 'radio24/upd_install.lua' }

local function verifyRemote()
    if UPD.base ~= REPO_BASE then
        shutdown('адрес репозитория в upd_install.lua не совпадает с guard.lua', 'У вас изменены файлы хелпера. Скрипт отключён.')
    end
    if UPD.base:find('/USER/REPO/', 1, true) then
        shutdown('в upd_install.lua не указан репозиторий', 'Защита не настроена: не указан репозиторий GitHub.')
    end
    local m
    for _ = 1, 3 do
        m = updFetch()
        if m then break end
        wait(3000)
    end
    if not m then
        shutdown('не получен version.txt с GitHub', 'Не удалось проверить защиту через GitHub. Перезайдите позже.')
    end

    -- на GitHub новее: ставим официальные файлы (занижение версии обход не даёт - всё перезапишется)
    if verCmp(m.version, thisScript().version) > 0 then
        updInstall(m)          -- при успехе сам перезагружает скрипт
        shutdown('обновление не установилось', 'Нужно обновление, но оно не установилось. Перезайдите позже.')
    end

    -- версия та же или "новее" опубликованной: файлы обязаны совпадать
    for _, rel in ipairs(PROTECTED) do
        local mine = readFile(getWorkingDirectory() .. '\\' .. rel:gsub('/', '\\'))
        local theirs = updDownload(UPD.base .. rel .. '?t=' .. os.time(), UCFG.dir .. 'radio24_upd_tmp.dat')
        if not theirs then
            shutdown('не скачался ' .. rel, 'Не удалось проверить защиту через GitHub. Перезайдите позже.')
        end
        if not mine or normalize(mine) ~= normalize(theirs) then
            shutdown(rel .. ' отличается от GitHub', 'У вас изменены файлы хелпера. Скрипт отключён.')
        end
    end
end

---------------------------------------------------------------------
-- Меню разработчика: сохранение рангов
---------------------------------------------------------------------
local function installDevSave()
    GUARD.devSave = function(list)
        local seen, arr = {}, {}
        for _, n in ipairs(list) do
            n = tonumber(n)
            if n and n > 0 and not seen[n] then seen[n] = true; arr[#arr + 1] = n end
        end
        table.sort(arr)
        local str = table.concat(arr, ',')
        local sig = hA(SALT .. str)
        local path = getWorkingDirectory() .. '\\radio24\\guard.lua'
        local src = readFile(path)
        if not src then return false, 'guard.lua не найден' end
        local line = "local RANKS, RSIG = '" .. str .. "', " .. string.format('%d', sig) .. ' --@' .. 'ranks'
        local n
        src, n = src:gsub("local RANKS, RSIG = '[%d,]*', %d+ %-%-@ranks", function() return line end, 1)
        if n ~= 1 then return false, 'строка рангов не найдена' end
        if not writeFile(path, src) then return false, 'нет доступа на запись' end
        RANKS, RSIG = str, sig
        parseRanks()
        return true, str
    end
end

-- доступ разработчика: в radio24 лежит devmenu.lua с правильным ключом (пустой/чужой файл не подойдёт)
local function hasDevAccess()
    local s = readFile(getWorkingDirectory() .. '\\radio24\\devmenu.lua')
    local key = s and s:match("%-%-@devkey (%x+)")
    return key ~= nil and hA(key) == DEVA and hB(key) == DEVB
end
GUARD.hasDevAccess = hasDevAccess

---------------------------------------------------------------------
-- Запуск
---------------------------------------------------------------------
local function spawned()
    local ok, v = pcall(sampIsLocalPlayerSpawned)
    return ok and v == true
end

-- пока проверка не пройдена, все хуки хелпера молчат и не трогают игру
local function wrapHooks()
    local names = {}
    for k, v in pairs(sampev) do
        if type(k) == 'string' and k:find('^on') and type(v) == 'function' then names[k] = v end
    end
    names.onShowDialog = names.onShowDialog or function() end
    for k, o in pairs(names) do
        sampev[k] = function(...)
            if k == 'onShowDialog' and guardDialog(...) then return false end
            if GUARD.locked then return nil end
            return o(...)
        end
    end
end
if sampev then wrapHooks() end

local origMain = main
main = function()
    while not isSampAvailable() do wait(200) end
    while not spawned() do wait(500) end
    wait(2000)

    GUARD.nick, GUARD.id = myNick(), myId()
    GUARD.dev = hasDevAccess()

    if GUARD.dev then
        say(T('Доступ разработчика выдан.'), 0xFF66FF66)
        installDevSave()
        if type(E.DEVMENU_START) == 'function' then pcall(E.DEVMENU_START) end
    else
        verifyRemote()
        GUARD.rank = askRank()
        if not GUARD.rank then
            shutdown('ранг не определён', 'Не удалось определить ранг через /find. Перезагрузите скрипт (Ctrl+R).')
        end
        if not rankAllowed(GUARD.rank) then shutdown('ранг ' .. GUARD.rank .. ' запрещён', 'У вас недоступный для скрипта ранг') end
    end
    GUARD.checked, GUARD.locked = true, false

    -- разработчику ранг нужен только для показа в меню, блокировки по нему нет
    if GUARD.dev then
        lua_thread.create(function() GUARD.rank = askRank() end)
    end

    lua_thread.create(function()
        local was, nick = true, GUARD.nick
        while true do
            wait(500)
            if GUARD.dev then
                GUARD.locked = GUARD.sim ~= nil and GUARD.blocked[GUARD.sim] == true
            end
            local now = spawned()
            if now and not was then
                wait(2000)
                if myNick() ~= nick then thisScript():reload() end
                if not GUARD.dev then
                    local r = askRank()
                    if r then
                        GUARD.rank = r
                        if not rankAllowed(r) then shutdown('ранг ' .. r .. ' запрещён', 'У вас недоступный для скрипта ранг') end
                    end
                end
            end
            was = now
        end
    end)

    origMain()
end

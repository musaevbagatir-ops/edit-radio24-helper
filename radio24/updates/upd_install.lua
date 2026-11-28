-- radio24/updates/upd_install.lua: (2) установка новой версии с хостинга прямо в игре + перезапуск скрипта.
-- Все файлы сначала скачиваются в память и проверяются (непустые, Lua-код компилируется), и только потом записываются.
-- Старые файлы копируются в moonloader\radio24\config\updates\radio24_backup\. При ошибке записи всё откатывается.
-- После установки и при старте (если код актуален): файлы из del= (version.txt) уходят в config\updates\radio24_trash, а в radio24_backup удаляются копии файлов, которых нет в file=.
-- Прогресс в чат: [loading=сколько файлов осталось].
-- >>> СЮДА ВСТАВИТЬ РЕПОЗИТОРИЙ: GitHub-логин, имя репозитория, ветка (обычно main) <<<
local GH_USER, GH_REPO, GH_BRANCH = 'musaevbagatir-ops', 'edit-radio24-helper', 'main'
UPD = UPD or { base = 'https://raw.githubusercontent.com/' .. GH_USER .. '/' .. GH_REPO .. '/' .. GH_BRANCH .. '/', auto = true, busy = false, userUrl = false }
pcall(ffi.cdef, 'unsigned int WinExec(const char* cmd, unsigned int show);')

function updLoadCfg()
    local s = ucfgRead('radio24_upd.txt')
    if not s then return end
    for l in s:gmatch('[^\r\n]+') do
        local k, v = l:match('^(%a+)=(.*)$')
        if k == 'auto' then UPD.auto = v:sub(1, 1) == '1' end   -- адрес из файла НЕ читается: сменить хостинг пользователь не может
    end
end

function updSaveCfg()
    ucfgWrite('radio24_upd.txt', 'auto=' .. (UPD.auto and '1' or '0') .. '\n')
end

-- скачать url, вернуть содержимое (строка) или nil. Вызывать внутри lua_thread (есть wait)
function updDownload(url, tmp)
    pcall(os.remove, tmp); pcall(os.remove, tmp .. '.done')
    local cmd = 'cmd /c curl.exe -s -f -L --ssl-no-revoke -m 30 -A "Radio24Updater" -o "' .. tmp .. '" "' .. url
        .. '" & echo 1> "' .. tmp .. '.done"'
    pcall(function() ffi.C.WinExec(cmd, 0) end)
    for _ = 1, 80 do
        wait(500)
        local d = io.open(tmp .. '.done', 'rb')
        if d then d:close(); break end
    end
    pcall(os.remove, tmp .. '.done')
    local s
    local f = io.open(tmp, 'rb')
    if f then s = f:read('*a'); f:close() end
    pcall(os.remove, tmp)
    if not s or #s == 0 then
        local ok, requests = pcall(require, 'requests')
        if ok and requests then
            local ok2, r = pcall(function() return requests.get(url) end)
            if ok2 and r and r.status_code == 200 and r.text and #r.text > 0 then s = r.text end
        end
    end
    if s and #s == 0 then s = nil end
    return s
end

local function readAll(p)
    local f = io.open(p, 'rb')
    if not f then return nil end
    local s = f:read('*a'); f:close()
    return s
end
local function writeAll(p, s)
    local f = io.open(p, 'wb')
    if not f then return false end
    f:write(s); f:close()
    return true
end
local function ensureDirs(path)                      -- создать все папки пути (без имени файла)
    local acc = ''
    for part in path:gmatch('[^\\]+') do
        acc = (acc == '') and part or (acc .. '\\' .. part)
        if not acc:match('^%a:$') then pcall(function() if not doesDirectoryExist(acc) then createDirectory(acc) end end) end
    end
end

-- чистка: (а) del= из version.txt: устаревшие файлы уходят в корзину radio24_trash, только явный список, только radio24/*.lua вне config,
-- не из file= и не служебные; (б) в radio24_backup удаляются копии, которых нет в текущем file=. Ошибки здесь не мешают работе.
-- Вызывается после установки и при старте, когда код уже актуален (нужно тем, кто обновился старым установщиком: он del= не знает).
function updCleanup(m)
    pcall(function()
        local wd = getWorkingDirectory()
        local bd = UCFG.dir .. 'radio24_backup\\'
        local td = UCFG.dir .. 'radio24_trash\\'
        local function listDir(mask)
            local res = {}
            local h, nm = findFirstFile(mask)
            if h then
                while nm do res[#res + 1] = nm; nm = findNextFile(h) end
                findClose(h)
            end
            return res
        end
        local keep = { ['radio24/interface/devmenu.lua'] = true, ['radio24/security/guard.lua'] = true,
            ['radio24/updates/upd_install.lua'] = true, ['radio24/config/processing/radio24_logedit.lua'] = true }
        for _, f in ipairs(m.files) do keep[f] = true end
        local todo = {}
        for _, f in ipairs(m.del or {}) do
            if not keep[f] and f:match('^radio24/[%w_%-/]+%.lua$') and not f:find('..', 1, true) and not f:find('radio24/config/', 1, true) then
                local p = wd .. '\\' .. f:gsub('/', '\\')
                local s = readAll(p)
                if s then todo[#todo + 1] = { f, p, s } end
            end
        end
        local moved, cleaned = 0, 0
        if #todo > 0 then
            ensureDirs(td)
            if not UPD.trashCleared then                                    -- корзина прошлого обновления (один раз за сеанс)
                UPD.trashCleared = true
                for _, nm in ipairs(listDir(td .. '*')) do pcall(os.remove, td .. nm) end
            end
            for _, t in ipairs(todo) do
                if writeAll(td .. t[1]:gsub('/', '__'), t[3]) and os.remove(t[2]) then moved = moved + 1 end
            end
        end
        if #m.files > 0 then
            local want = {}
            for _, f in ipairs(m.files) do want[(f:gsub('/', '__'))] = true end
            for _, nm in ipairs(listDir(bd .. '*.lua')) do
                if not want[nm] and os.remove(bd .. nm) then cleaned = cleaned + 1 end
            end
        end
        if moved + cleaned > 0 then say(T('Убрано устаревших файлов: ') .. moved .. T(', старых копий в бэкапе: ') .. cleaned, 0xFF999999) end
    end)
end

local function updInstallImpl(m)
    local wd = getWorkingDirectory()
    local tmp = UCFG.dir .. 'radio24_upd_tmp.dat'
    local total, data = #m.files + #m.data, {}
    local isCode = #m.files > 0
    local pend = UCFG.dir .. 'radio24_pending\\'
    if isCode then say(T('Найдена новая версия ') .. m.version .. T(' (у вас ') .. thisScript().version .. T('). Скачиваю, не выходите из игры...'), 0xFF66CCFF)
    else say(T('Найдены новые данные самообучения. Скачиваю, не выходите из игры...'), 0xFF66CCFF) end
    for i, f in ipairs(m.files) do
        say('[loading=' .. (total - i + 1) .. '] ' .. f, 0xFF999999)
        local s = updDownload(UPD.base .. f .. '?t=' .. os.time(), tmp)
        if not s then error(T('не скачался файл ') .. f) end
        if s:sub(1, 1) == '<' then error(T('вместо файла пришла веб-страница: ') .. f) end
        if f:match('%.lua$') then
            local fn, e = loadstring(s, '=' .. f)
            if not fn then error(T('в файле ошибка кода ') .. f .. ': ' .. tostring(e)) end
        end
        data[f] = s
    end
    -- защита от вечного обновления: версия в скачанном radio24_helper.lua должна совпасть с version.txt
    if isCode then
        local hv = data['radio24_helper.lua']
        local sv = hv and hv:match("script_version%s*%(%s*['\"]([%d%.]+)['\"]%s*%)")
        if not sv or verCmp(sv, m.version) ~= 0 then
            ucfgWrite('radio24_updblock.txt', m.version .. '\n')
            error(T('версия в radio24_helper.lua (') .. tostring(sv or T('не найдена')) .. T(') не совпадает с version.txt (') .. m.version
                .. T('), либо helper не указан в file= . Установка остановлена, эта версия больше не ставится сама'))
        end
    end
    -- данные самообучения (config/<имя> в репозитории) -> во временную папку; объединятся при старте после перезапуска
    local dnames = {}
    for j, f in ipairs(m.data) do
        say('[loading=' .. (#m.data - j + 1) .. '] config/' .. f, 0xFF999999)
        local s = updDownload(UPD.base .. 'config/' .. f .. '?t=' .. os.time(), tmp)
        if not s then error(T('не скачались данные ') .. f) end
        if s:sub(1, 1) == '<' then error(T('вместо данных пришла веб-страница: ') .. f) end
        dnames[#dnames + 1] = { f, s }
    end
    -- резервная копия старых файлов
    local bd = UCFG.dir .. 'radio24_backup\\'
    ensureDirs(bd)
    local old = {}
    for _, f in ipairs(m.files) do
        local p = wd .. '\\' .. f:gsub('/', '\\')
        old[f] = readAll(p)
        if old[f] then writeAll(bd .. f:gsub('/', '__'), old[f]) end
    end
    -- запись новых
    local written = {}
    local okAll, werr = true, nil
    for _, f in ipairs(m.files) do
        local p = wd .. '\\' .. f:gsub('/', '\\')
        ensureDirs(p:match('^(.*)\\[^\\]*$') or wd)
        if writeAll(p, data[f]) then written[#written + 1] = f else okAll, werr = false, f; break end
    end
    if not okAll then
        for _, f in ipairs(written) do
            local p = wd .. '\\' .. f:gsub('/', '\\')
            if old[f] then writeAll(p, old[f]) else pcall(os.remove, p) end
        end
        error(T('не удалось записать ') .. tostring(werr) .. T(' (изменения отменены)'))
    end
    updCleanup(m)
    -- флаг для следующего запуска: версия + принудительные команды конфига
    local fl = {}
    if isCode then fl[#fl + 1] = 'version=' .. m.version end
    if #dnames > 0 then
        ensureDirs(pend)
        for _, d in ipairs(dnames) do
            if writeAll(pend .. d[1], d[2]) then fl[#fl + 1] = 'data=' .. d[1] end
        end
        fl[#fl + 1] = 'dataver=' .. m.dataver
    end
    for _, op in ipairs(m.ops) do fl[#fl + 1] = op.kind .. '=' .. op.val end
    ucfgWrite('radio24_updated.txt', table.concat(fl, '\n') .. '\n')
    say('[loading=0] ' .. T('Установлено. Перезапускаю скрипт...'), 0xFF66FF66)
    wait(1200)
    thisScript():reload()
end

function updInstall(m)
    if UPD.busy then return false end
    UPD.busy = true
    local ok, err = pcall(updInstallImpl, m)
    UPD.busy = false
    if not ok then say(T('Ошибка обновления: ') .. tostring(err) .. T('. Старая версия продолжает работать.'), 0xFFFF6666) end
    return ok
end

-- radio24/upd_cfg.lua: (3) умная донастройка конфигов при обновлении. Общее окружение модулей.
-- Конфиги пользователя НЕ стираются. Данные из репозитория (data=) объединяются ТРЁХСТОРОННЕ: база (копия твоего файла из прошлого обновления,
-- config\radio24_base\<файл>) + файл пользователя + новый файл с хостинга. Подробности - у функции ucfgMergeData.
-- Исключение - команды "force"/"delline" из version.txt на хостинге (меняют даже у пользователя с дополнениями).
-- Перед первой правкой файла его копия кладётся в config\radio24_cfgbak\<файл>.bak
-- Миграции (MIGRATIONS) запускаются при старте, если версия скрипта выше записанной в config\radio24_cfgver.txt.
UCFG = { dir = getWorkingDirectory() .. '\\config\\', baked = {}, baseline = '7.0' }

function verCmp(a, b)
    local pa, pb = {}, {}
    for n in tostring(a or '0'):gmatch('%d+') do pa[#pa + 1] = tonumber(n) end
    for n in tostring(b or '0'):gmatch('%d+') do pb[#pb + 1] = tonumber(n) end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x > y then return 1 elseif x < y then return -1 end
    end
    return 0
end

function ucfgRead(name)
    local f = io.open(UCFG.dir .. name, 'rb')
    if not f then return nil end
    local s = f:read('*a'); f:close()
    return s
end

function ucfgWrite(name, s)
    pcall(function() if not doesDirectoryExist(UCFG.dir) then createDirectory(UCFG.dir) end end)
    if not UCFG.baked[name] then
        UCFG.baked[name] = true
        local old = ucfgRead(name)
        if old then
            pcall(function()
                local bd = UCFG.dir .. 'radio24_cfgbak\\'
                if not doesDirectoryExist(bd) then createDirectory(bd) end
                local f = io.open(bd .. name .. '.bak', 'wb')
                if f then f:write(old); f:close() end
            end)
        end
    end
    local f = io.open(UCFG.dir .. name, 'wb')
    if not f then return false end
    f:write(s); f:close()
    return true
end

local function lines(s)
    local t = {}
    for l in ((s or '') .. '\n'):gmatch('([^\r\n]*)\r?\n') do t[#t + 1] = l end
    while #t > 0 and t[#t] == '' do t[#t] = nil end
    return t
end
local function save(file, t) return ucfgWrite(file, #t > 0 and (table.concat(t, '\n') .. '\n') or '') end

-- добавить недостающие ключи в файл вида key=value. kv = { {'key','val'}, ... }. Существующие НЕ трогает
function ucfgAddKeys(file, kv)
    local t = lines(ucfgRead(file))
    local have = {}
    for _, l in ipairs(t) do local k = l:match('^([^=\t]+)='); if k then have[k] = true end end
    local ch = false
    for _, p in ipairs(kv) do
        if not have[p[1]] then t[#t + 1] = p[1] .. '=' .. p[2]; ch = true end
    end
    if ch then save(file, t) end
    return ch
end

-- принудительно задать key=value (заменяет, даже если пользователь менял)
function ucfgForceKey(file, key, val)
    local t, done = lines(ucfgRead(file)), false
    for i, l in ipairs(t) do
        if l:match('^' .. key:gsub('%p', '%%%0') .. '=') then t[i] = key .. '=' .. val; done = true; break end
    end
    if not done then t[#t + 1] = key .. '=' .. val end
    save(file, t)
end

-- добавить строки, которых нет. byFirst=true: строка считается имеющейся, если совпало первое табличное поле (для правил)
function ucfgAddLines(file, list, byFirst)
    local t = lines(ucfgRead(file))
    local have = {}
    for _, l in ipairs(t) do have[byFirst and (l:match('^([^\t]*)')) or l] = true end
    local ch = false
    for _, ln in ipairs(list) do
        local k = byFirst and (ln:match('^([^\t]*)')) or ln
        if not have[k] then t[#t + 1] = ln; have[k] = true; ch = true end
    end
    if ch then save(file, t) end
    return ch
end

function ucfgDelLines(file, list)
    local t, out, kill, ch = lines(ucfgRead(file)), {}, {}, false
    for _, l in ipairs(list) do kill[l] = true end
    for _, l in ipairs(t) do if kill[l] then ch = true else out[#out + 1] = l end end
    if ch then save(file, out) end
    return ch
end

-- fixline: исправить СТАРУЮ ошибочную запись на правильную, не трогая то, что пользователь добавил сам.
-- Меняется только строка, которая НАЧИНАЕТСЯ ровно с old (дальше конец строки или табуляция); хвост строки (флаги вкл/выкл, счётчики) сохраняется.
-- Если пользователь правил эту запись сам (начало строки отличается) - она не тронута. Если уже есть запись new - старая просто убирается (без дублей).
local function hasPrefix(l, p) return l:sub(1, #p) == p and (#l == #p or l:sub(#p + 1, #p + 1) == '\t') end
function ucfgFixLine(file, old, new)
    local t = lines(ucfgRead(file))
    if #t == 0 or old == '' or old == new then return false end
    local newExists = false
    for _, l in ipairs(t) do if hasPrefix(l, new) then newExists = true; break end end
    local out, ch = {}, false
    for _, l in ipairs(t) do
        if hasPrefix(l, old) and not hasPrefix(l, new) then
            ch = true
            if not newExists then out[#out + 1] = new .. l:sub(#old + 1); newExists = true end
        else
            out[#out + 1] = l
        end
    end
    if ch then save(file, out) end
    return ch
end

-- Дефолты настроек (снимок ДО чтения файла настроек): по ним новым ключам выдаётся значение по умолчанию
UCFG.defaults = {}
pcall(function() for _, k in ipairs(BOOLS) do UCFG.defaults[k] = cfg[k] end end)

-- Автомиграция ключей настроек: каждый ключ из BOOLS, которого нет в radio24_settings.txt, добавляется с дефолтом.
-- Срабатывает САМА при каждом старте у всех пользователей; вручную - команда /addmigration. Существующие значения НЕ трогаются.
function ucfgSyncSettings()
    local added = {}
    local cur = ucfgRead('radio24_settings.txt')
    if not cur or type(BOOLS) ~= 'table' then return added end
    local have = {}
    for _, l in ipairs(lines(cur)) do local k = l:match('^([^=\t]+)='); if k then have[k] = true end end
    local kv = {}
    for _, k in ipairs(BOOLS) do
        if not have[k] then
            local d = UCFG.defaults[k]
            if d == nil then d = cfg[k] end
            kv[#kv + 1] = { k, d and '1' or '0' }
            added[#added + 1] = k
        end
    end
    if #kv > 0 then ucfgAddKeys('radio24_settings.txt', kv) end
    return added
end

-- Защита команд из version.txt: только файлы radio24_*.txt, и не служебные (адрес обновлений, флаги установщика, версия конфига)
UCFG.DENY = { ['radio24_upd.txt'] = true, ['radio24_updated.txt'] = true, ['radio24_updblock.txt'] = true,
    ['radio24_cfgver.txt'] = true, ['radio24_dataver.txt'] = true, ['radio24_migout.txt'] = true }
function ucfgOpFile(kind, val)
    local f = tostring(val or ''):match('^([^|]+)|')
    if not f or not f:match('^radio24_[%w_]+%.txt$') or UCFG.DENY[f] then return nil end
    return f
end

-- команда из version.txt: kind = force | addkey | fixline | addline | delline | addlinek. val: "файл|ключ|значение" либо "файл|строка" (\t = табуляция)
function ucfgApplyOp(kind, val)
    val = val or ''
    if not ucfgOpFile(kind, val) then return end
    if kind == 'force' then
        local f, k, v = val:match('^([^|]+)|([^|]+)|(.*)$')
        if f then ucfgForceKey(f, k, v) end
    elseif kind == 'addkey' then
        local f, k, v = val:match('^([^|]+)|([%w_]+)|(.*)$')
        if f then ucfgAddKeys(f, { { k, (v:gsub('[\r\n\t]', ' ')) } }) end
    else
        local f, txt = val:match('^([^|]+)|(.*)$')
        if not f then return end
        txt = txt:gsub('\\t', '\t')
        if kind == 'addline' then ucfgAddLines(f, { txt }, false)
        elseif kind == 'addlinek' then ucfgAddLines(f, { txt }, true)
        elseif kind == 'delline' then ucfgDelLines(f, { txt })
        elseif kind == 'fixline' then
            local o, n = txt:match('^(.-) >>> (.*)$')
            if o and o ~= '' then ucfgFixLine(f, o, n) end
        end
    end
end

---------------------------------------------------------------------
-- МИГРАЦИИ: добавляй сюда блок на каждую версию, где менялись конфиги. fn выполняется один раз у каждого пользователя.
-- Внутри - только ДОПОЛНЕНИЯ (ucfgAddKeys / ucfgAddLines). Пример:
--   { ver = '7.1', fn = function()
--       ucfgAddKeys('radio24_settings.txt', { { 'newOption', '0' } })
--       ucfgAddLines('radio24_ctr.txt', { 'kw\tновоеслово' }, false)          -- слова в UTF-8
--       ucfgAddLines('radio24_trules.txt', { 'найти\tзаменить\t\t\tr\t1' }, true)
--   end },
---------------------------------------------------------------------
MIGRATIONS = {
}

-- ===== Раздача накопленных данных: трёхстороннее объединение файла пользователя с файлом из репозитория =====
-- Для каждой записи (по ключу) сравниваются: БАЗА (твой файл при прошлом обновлении), ПОЛЬЗОВАТЕЛЬ, НОВЫЙ (твой файл сейчас):
--   * новой записи у пользователя нет -> добавляется (если он сам её не удалял, а ты её не менял);
--   * ты запись изменил, пользователь нет -> берётся твоя; изменили оба по-разному -> берётся твоя (счётчики пользователя остаются);
--   * изменил только пользователь -> остаётся его; запись есть и у тебя, и у него, но базы для неё нет -> берётся твоя;
--   * ты запись удалил, у пользователя она не менялась -> удаляется; свои записи пользователя (нет в твоём файле) не трогаются.
-- Нет базы (первое обновление у тех, у кого она ещё не сохранена) -> только ДОБАВЛЯЮТСЯ недостающие записи, существующие не меняются.
-- Нет файла у пользователя (первая установка) -> файл просто записывается. После каждого объединения новый файл сохраняется как база.
-- Число = сколько первых табуляционных полей образуют "ключ" записи (0 = ключ вся строка). Для key=value ключ = имя.
-- Личные/служебные файлы (people, stats, логи, theme, upd) сюда намеренно не входят.
UCFG.DATAKEY = {
    ['radio24_names.txt'] = 2, ['radio24_learn.txt'] = 1, ['radio24_src.txt'] = 1, ['radio24_strays.txt'] = 1,
    ['radio24_catpref.txt'] = 1, ['radio24_trules.txt'] = 1, ['radio24_cats.txt'] = 0, ['radio24_tags.txt'] = 0,
    ['radio24_ctr.txt'] = 0, ['radio24_auto.txt'] = 0, ['radio24_memory.txt'] = 0, ['radio24_tests.txt'] = 0,
}
local function dkey(l, n)
    local k = l:match('^([%w_]+)=')
    if k and not l:find('\t', 1, true) then return 'K:' .. k end
    if n == 0 then return l end
    local parts, i = {}, 0
    for f in (l .. '\t'):gmatch('(.-)\t') do
        i = i + 1; parts[i] = f
        if i >= n then break end
    end
    return table.concat(parts, '\t')
end
UCFG.dkey = dkey
-- Колонки (по табуляциям), по которым сравниваются записи; счётчики и время в сравнении не участвуют. Нет в таблице - сравнивается вся строка.
UCFG.DATACMP = {
    ['radio24_names.txt'] = { 4 }, ['radio24_learn.txt'] = { 2 }, ['radio24_src.txt'] = { 2 },
    ['radio24_strays.txt'] = { 2, 5 }, ['radio24_catpref.txt'] = { 2 }, ['radio24_trules.txt'] = { 2, 3, 4, 5, 6 },
}
-- Колонки пользователя (счётчики, время, примеры), которые остаются у него, когда запись заменяется твоей
UCFG.DATAKEEP = {
    ['radio24_names.txt'] = { 3 }, ['radio24_learn.txt'] = { 3, 4, 5 }, ['radio24_src.txt'] = { 3, 4 }, ['radio24_strays.txt'] = { 3, 4 },
}
UCFG.BASEDIR = 'radio24_base\\'

local function dfields(l)
    local t = {}
    for f in (l .. '\t'):gmatch('(.-)\t') do t[#t + 1] = f end
    return t
end
local function dsame(name, a, b)
    if a == b then return true end
    if a == nil or b == nil then return false end
    local cols = UCFG.DATACMP[name]
    if not cols or not a:find('\t', 1, true) or not b:find('\t', 1, true) then return false end
    local fa, fb = dfields(a), dfields(b)
    for _, c in ipairs(cols) do
        if (fa[c] or '') ~= (fb[c] or '') then return false end
    end
    return true
end
local function dmerge(name, u, n)                       -- твоя запись, но с колонками-счётчиками пользователя
    local keep = UCFG.DATAKEEP[name]
    if not keep or not u:find('\t', 1, true) or not n:find('\t', 1, true) then return n end
    local uf, nf = dfields(u), dfields(n)
    for _, c in ipairs(keep) do
        if uf[c] ~= nil then
            for i = #nf + 1, c - 1 do nf[i] = '' end
            nf[c] = uf[c]
        end
    end
    return table.concat(nf, '\t')
end
local function baseWrite(name, s)
    pcall(function()
        local d = UCFG.dir .. UCFG.BASEDIR
        if not doesDirectoryExist(d) then createDirectory(d) end
        local f = io.open(d .. name, 'wb')
        if f then f:write(s); f:close() end
    end)
end

-- возвращает: сколько записей добавлено, изменено, удалено
function ucfgMergeData(name, incoming)
    local n = UCFG.DATAKEY[name]
    if not n then return 0, 0, 0 end
    local cur = ucfgRead(name)
    if not cur then                                       -- первая установка: файл просто записывается и становится базой
        ucfgWrite(name, incoming)
        baseWrite(name, incoming)
        local cnt = 0
        for _ in incoming:gmatch('[^\r\n]+') do cnt = cnt + 1 end
        return cnt, 0, 0
    end
    local base = ucfgRead(UCFG.BASEDIR .. name)
    local bmap
    if base then
        bmap = {}
        for l in base:gmatch('[^\r\n]+') do
            local k = dkey(l, n)
            if bmap[k] == nil then bmap[k] = l end
        end
    end
    local ul, uidx = {}, {}
    for l in cur:gmatch('[^\r\n]+') do
        ul[#ul + 1] = l
        local k = dkey(l, n)
        if not uidx[k] then uidx[k] = #ul end
    end
    local nmap, norder = {}, {}
    for l in incoming:gmatch('[^\r\n]+') do
        local k = dkey(l, n)
        if nmap[k] == nil then nmap[k] = l; norder[#norder + 1] = k end
    end
    local added, changed, removed, app, del = 0, 0, 0, {}, {}
    for _, k in ipairs(norder) do
        local N, ui, B = nmap[k], uidx[k], bmap and bmap[k]
        local U = ui and ul[ui]
        if not U then
            -- записи у пользователя нет: добавляем; если он её удалил сам, а ты её не менял - остаётся удалённой
            if not bmap or B == nil or not dsame(name, B, N) then app[#app + 1] = N; added = added + 1 end
        elseif bmap then
            if not (B ~= nil and dsame(name, N, B)) and not dsame(name, U, N) then
                ul[ui] = dmerge(name, U, N)
                changed = changed + 1
            end
        end                                               -- нет базы: существующие записи не меняем
    end
    if bmap then                                          -- ты удалил запись, а у пользователя она не менялась -> убираем
        for k, B in pairs(bmap) do
            if nmap[k] == nil then
                local ui = uidx[k]
                if ui and not del[ui] and dsame(name, ul[ui], B) then del[ui] = true; removed = removed + 1 end
            end
        end
    end
    if added + changed + removed > 0 then
        local out = {}
        for i, l in ipairs(ul) do if not del[i] then out[#out + 1] = l end end
        for _, l in ipairs(app) do out[#out + 1] = l end
        ucfgWrite(name, #out > 0 and (table.concat(out, '\n') .. '\n') or '')
    end
    baseWrite(name, incoming)                             -- новый файл становится базой для следующего обновления
    return added, changed, removed
end

function ucfgStartup()
    local cur = thisScript().version
    -- 1) что оставил установщик: флаг обновления + принудительные команды
    local flag = ucfgRead('radio24_updated.txt')
    -- защита от устаревшего флага: версия в флаге новее установленной = установка не дописалась, команды НЕ применяем
    local flagVer
    if flag then
        for _, l in ipairs(lines(flag)) do
            local v = l:match('^version=(.*)$')
            if v then flagVer = v:match('^%d+[%d%.]*$') end
        end
        if flagVer and verCmp(flagVer, cur) > 0 then
            UCFG.err = T('установка версии ') .. flagVer .. T(' не завершилась (у вас ') .. tostring(cur) .. T('), команды обновления пропущены')
            pcall(os.remove, UCFG.dir .. 'radio24_updated.txt')
            flag = nil
        end
    end
    if flag then
        for _, l in ipairs(lines(flag)) do
            local k, v = l:match('^(%a+)=(.*)$')
            if k == 'version' then UCFG.justUpdated = v
            elseif k == 'data' then
                local inc = ucfgRead('radio24_pending\\' .. v)
                if inc then
                    local ok, a, ch, rm = pcall(ucfgMergeData, v, inc)
                    if ok then
                        UCFG.dataAdded = (UCFG.dataAdded or 0) + (a or 0)
                        UCFG.dataChanged = (UCFG.dataChanged or 0) + (ch or 0)
                        UCFG.dataRemoved = (UCFG.dataRemoved or 0) + (rm or 0)
                    end
                    pcall(os.remove, UCFG.dir .. 'radio24_pending\\' .. v)
                end
            elseif k == 'dataver' then ucfgWrite('radio24_dataver.txt', v .. '\n')
            elseif k then pcall(ucfgApplyOp, k, v) end
        end
        pcall(os.remove, UCFG.dir .. 'radio24_updated.txt')
    end
    -- 1.5) новые ключи настроек добавляются автоматически (дефолтом)
    local oks, added = pcall(ucfgSyncSettings)
    if oks and type(added) == 'table' and #added > 0 then UCFG.keysAdded = added end
    -- 2) миграции
    local old = (ucfgRead('radio24_cfgver.txt') or ''):match('%d[%d%.]*') or UCFG.baseline
    local ran = 0
    table.sort(MIGRATIONS, function(a, b) return verCmp(a.ver, b.ver) < 0 end)
    for _, m in ipairs(MIGRATIONS) do
        if verCmp(m.ver, old) > 0 and verCmp(m.ver, cur) <= 0 then
            local ok, e = pcall(m.fn)
            if ok then ran = ran + 1 else UCFG.err = tostring(e) end
        end
    end
    if verCmp(cur, old) > 0 or not ucfgRead('radio24_cfgver.txt') then ucfgWrite('radio24_cfgver.txt', cur .. '\n') end   -- версию конфига назад не понижаем
    UCFG.migrated = ran
end

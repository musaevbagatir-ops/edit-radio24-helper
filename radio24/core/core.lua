-- radio24/core/core.lua: основа: подключения, настройки, утилиты. Строки оригинала 1-104. Общее окружение модулей, см. radio24_helper.lua




-- Хелпер редактирования объявлений Radio24 (Online RP) по ПРО.
-- Нужны: MoonLoader, SAMP.Lua, SAMPFUNCS, mimgui. Файл хранить в UTF-8.
-- Порядок работы в окне:  Список -> выбрал объявление -> действия
--   (Отправить как есть / Редактировать / Удалить / Админам) -> "Принять" -> готово.
-- На каждом шаге есть кнопка "Назад".
-- Команды:
--   /edit   - (серверная команда) + открывает окно хелпера
--   /adm    - открыть/закрыть окно        /adref   - справочник
--   /adfix [текст] - разобрать любой текст /adh     - включить/выключить хелпер
--   /adspy  - лог диалогов в moonloader/radio24/config/core/radio24_dialogs.txt
--   /adstatus - диагностика        /adtest  - прогон примеров ПРО (самопроверка)

sampev = require 'lib.samp.events'
encoding = require 'encoding'
ffi = require 'ffi'
encoding.default = 'CP1251'
u8 = encoding.UTF8
function T(s) return u8:decode(s) end          -- UTF-8 литерал -> CP1251
okUi, imgui = pcall(require, 'mimgui')

---------------------------------------------------------------------
-- НАСТРОЙКИ
---------------------------------------------------------------------
cfg = {
    enabled        = true,
    dialogTitle    = T('объявлен'),  -- часть заголовка списка объявлений
    maxLength      = 80,
    minPrice       = 100,
    maxPrice       = 100000000,
    -- переключатели (сохраняются)
    autoRemember   = true,   -- запоминать "исходник -> отправленный текст"
    autoSendMemory = false,  -- автоотправка, если объявление есть в памяти
    dollarPrefix   = false,  -- false: 1.500.000$   true: $1.500.000
    adIsRow        = true,   -- строка с текстом объявления в меню - тоже пункт списка (влияет на номера пунктов)
    verifyEdit     = true,   -- не отправлять, если сервер не применил правку (в меню остался старый текст)
    learn          = true,   -- умная память: учиться на моих правках и отказах
}
BOOLS = { 'autoRemember', 'autoSendMemory', 'dollarPrefix', 'adIsRow', 'verifyEdit', 'learn' }
-- подсказки (помощь) включаются отдельно для каждой вкладки меню, по умолчанию ВКЛ
HINTPAGES = { 'ads', 'estats', 'mem', 'names', 'stray', 'tr', 'auto', 'jrnl', 'tests', 'ctr', 'faq', 'ref', 'cfg' }
HINTKEYS = {}
for _, id in ipairs(HINTPAGES) do HINTKEYS[#HINTKEYS + 1] = 'hint' .. id; cfg['hint' .. id] = true end

-- @@cfgpaths begin
-- Все конфиги лежат в moonloader\radio24\config\<блок>\ (блоки как папки модулей). Путь к файлу: cfgPath('radio24_имя.txt').
-- Какой файл в каком блоке - таблица CFG_BLOCK ниже. Новый файл конфига: допиши его сюда, иначе он ляжет в корень radio24\config.
-- Старая папка moonloader\config переносится сама один раз при первом запуске (cfgMigrate).
DIR = ''
CFG_SEP = package.config:sub(1, 1)
CFG_ROOT = getWorkingDirectory() .. CFG_SEP .. 'radio24' .. CFG_SEP .. 'config' .. CFG_SEP
CFG_OLD = getWorkingDirectory() .. CFG_SEP .. 'config' .. CFG_SEP
CFG_BLOCKS = { 'core', 'processing', 'learning', 'security', 'interface', 'updates' }
CFG_BLOCK = {
    ['radio24_settings.txt'] = 'core',
    ['radio24_edits.txt'] = 'core',
    ['radio24_dialogs.txt'] = 'core',
    ['radio24_confirm.txt'] = 'core',
    ['radio24_moved.txt'] = 'core',
    ['radio24_trules.txt'] = 'processing',
    ['radio24_tags.txt'] = 'processing',
    ['radio24_strays.txt'] = 'processing',
    ['radio24_errors.txt'] = 'processing',
    ['radio24_refseed.txt'] = 'processing',
    ['radio24_learn.txt'] = 'learning',
    ['radio24_learnlog.txt'] = 'learning',
    ['radio24_stats.txt'] = 'learning',
    ['radio24_catpref.txt'] = 'learning',
    ['radio24_names.txt'] = 'learning',
    ['radio24_people.txt'] = 'learning',
    ['radio24_cats.txt'] = 'learning',
    ['radio24_auto.txt'] = 'learning',
    ['radio24_memory.txt'] = 'learning',
    ['radio24_src.txt'] = 'learning',
    ['radio24_srclog.txt'] = 'learning',
    ['radio24_tests.txt'] = 'security',
    ['radio24_adtest.txt'] = 'security',
    ['radio24_ctr.txt'] = 'security',
    ['radio24_contracts.json'] = 'security',
    ['radio24_contracts_dl.json'] = 'security',
    ['radio24_find.txt'] = 'security',
    ['radio24_theme.txt'] = 'interface',
    ['radio24_upd.txt'] = 'updates',
    ['radio24_updated.txt'] = 'updates',
    ['radio24_updblock.txt'] = 'updates',
    ['radio24_cfgver.txt'] = 'updates',
    ['radio24_dataver.txt'] = 'updates',
    ['radio24_migout.txt'] = 'updates',
    ['radio24_upd_tmp.dat'] = 'updates',
}
CFG_OLDDIRS = { 'radio24_cfgbak', 'radio24_backup', 'radio24_base', 'radio24_pending' }
local cfgMade = {}
function cfgMkdir(path)
    path = path:gsub('[\\/]+$', '')
    if cfgMade[path] then return end
    local parent = path:match('^(.*)[\\/][^\\/]+$')
    if parent and parent ~= '' and not parent:match('^%a:$') then cfgMkdir(parent) end
    pcall(function() if not doesDirectoryExist(path) then createDirectory(path) end end)
    cfgMade[path] = true
end
function cfgPath(name)
    local b = CFG_BLOCK[name]
    if b then local d = CFG_ROOT .. b .. CFG_SEP; cfgMkdir(d); return d .. name end
    if name:find('[\\/]') then local d = CFG_ROOT .. 'updates' .. CFG_SEP; cfgMkdir(d); return d .. name end   -- подпапки обновлений
    cfgMkdir(CFG_ROOT); return CFG_ROOT .. name
end
local function cfgExists(p) local f = io.open(p, 'rb'); if f then f:close(); return true end return false end
local function cfgMove(old, new)
    if not cfgExists(old) or cfgExists(new) then return end      -- чужое не затираем
    if os.rename(old, new) then return end
    local f = io.open(old, 'rb'); if not f then return end
    local s = f:read('*a'); f:close()
    local g = io.open(new, 'wb'); if not g then return end
    g:write(s); g:close()
    pcall(os.remove, old)
end
function cfgMigrate()
    local flag = cfgPath('radio24_moved.txt')
    if cfgExists(flag) then return end
    for name in pairs(CFG_BLOCK) do cfgMove(CFG_OLD .. name, cfgPath(name)) end
    for _, d in ipairs(CFG_OLDDIRS) do
        local o, n = CFG_OLD .. d, CFG_ROOT .. 'updates' .. CFG_SEP .. d
        if doesDirectoryExist(o) and not doesDirectoryExist(n) then pcall(os.rename, o, n) end
    end
    pcall(function()                                             -- остальные radio24_* файлы старой папки
        local lfs = require('lfs')
        for nm in lfs.dir(CFG_OLD) do
            if nm:match('^radio24_') and lfs.attributes(CFG_OLD .. nm, 'mode') == 'file' then cfgMove(CFG_OLD .. nm, cfgPath(nm)) end
        end
    end)
    local f = io.open(flag, 'wb'); if f then f:write('moved from moonloader\\config\n'); f:close() end
end
function ensureDir()
    DIR = CFG_ROOT
    cfgMkdir(CFG_ROOT)
    for _, b in ipairs(CFG_BLOCKS) do cfgMkdir(CFG_ROOT .. b .. CFG_SEP) end
    pcall(cfgMigrate)
end
-- @@cfgpaths end

function cfgSave()
    pcall(function()
        local f = io.open(cfgPath('radio24_settings.txt'), 'wb')
        if not f then return end
        for _, k in ipairs(BOOLS) do f:write(k, '=', cfg[k] and '1' or '0', '\n') end
        for _, k in ipairs(HINTKEYS) do f:write(k, '=', cfg[k] and '1' or '0', '\n') end
        f:close()
    end)
end

function cfgLoad()
    pcall(function()
        local f = io.open(cfgPath('radio24_settings.txt'), 'rb')
        if not f then return end
        for line in f:lines() do
            local k, v = line:match('^(%w+)=(%d)')
            if k and cfg[k] ~= nil then cfg[k] = (v == '1') end
        end
        f:close()
    end)
end

---------------------------------------------------------------------
-- Регистр в CP1251
---------------------------------------------------------------------
function lo(s)
    s = s:gsub('[\192-\223]', function(c) return string.char(c:byte() + 32) end)
    s = s:gsub('\168', '\184')
    return s:lower()
end

function up(s)
    s = s:gsub('[\224-\255]', function(c) return string.char(c:byte() - 32) end)
    s = s:gsub('\184', '\168')
    return s:upper()
end

function isLetter(c)
    local b = c:byte()
    return c:match('%a') ~= nil or (b and (b >= 192 or b == 168 or b == 184))
end

function isUpper(c)
    local b = c:byte()
    return c:match('%u') ~= nil or (b and ((b >= 192 and b <= 223) or b == 168))
end

function stripColors(s) return (s:gsub('{%x%x%x%x%x%x}', '')) end
function trim(s) return (s:match('^%s*(.-)%s*$')) end

function set(list)
    local r = {}
    for _, w in ipairs(list) do r[T(w)] = true end
    return r
end

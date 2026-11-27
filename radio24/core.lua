-- radio24/core.lua: основа: подключения, настройки, утилиты. Строки оригинала 1-104. Общее окружение модулей, см. radio24_helper.lua




-- Хелпер редактирования объявлений Radio24 (Online RP) по ПРО.
-- Нужны: MoonLoader, SAMP.Lua, SAMPFUNCS, mimgui. Файл хранить в UTF-8.
-- Порядок работы в окне:  Список -> выбрал объявление -> действия
--   (Отправить как есть / Редактировать / Удалить / Админам) -> "Принять" -> готово.
-- На каждом шаге есть кнопка "Назад".
-- Команды:
--   /edit   - (серверная команда) + открывает окно хелпера
--   /adm    - открыть/закрыть окно        /adref   - справочник
--   /adfix [текст] - разобрать любой текст /adh     - включить/выключить хелпер
--   /adspy  - лог диалогов в moonloader/config/radio24_dialogs.txt
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
HINTPAGES = { 'ads', 'estats', 'mem', 'names', 'src', 'stray', 'tr', 'auto', 'tests', 'ctr', 'faq', 'ref', 'cfg' }
HINTKEYS = {}
for _, id in ipairs(HINTPAGES) do HINTKEYS[#HINTKEYS + 1] = 'hint' .. id; cfg['hint' .. id] = true end

DIR = ''
function ensureDir()
    DIR = getWorkingDirectory() .. '\\config\\'
    pcall(function() if not doesDirectoryExist(DIR) then createDirectory(DIR) end end)
end

function cfgSave()
    pcall(function()
        local f = io.open(DIR .. 'radio24_settings.txt', 'wb')
        if not f then return end
        for _, k in ipairs(BOOLS) do f:write(k, '=', cfg[k] and '1' or '0', '\n') end
        for _, k in ipairs(HINTKEYS) do f:write(k, '=', cfg[k] and '1' or '0', '\n') end
        f:close()
    end)
end

function cfgLoad()
    pcall(function()
        local f = io.open(DIR .. 'radio24_settings.txt', 'rb')
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

script_name('Radio24 AdHelper')
script_author('Bagatir_Wayne')
script_version('7.6')

-- Защита от падений lua51.dll (JIT): отключаем JIT-компиляцию для этого скрипта
if jit then pcall(jit.off, true, true) end

-- Модули лежат в папке moonloader\radio24\ и грузятся по порядку ниже.
-- Все они работают в ОДНОМ общем окружении (как будто это один файл),
-- поэтому функции и таблицы видны между модулями без require.
-- upd_cfg / upd_install / upd_check - автообновление (должны идти ПОСЛЕ app).
-- guard - защита по рангу и от подмены, грузится последним. devmenu - необязательное меню разработчика.
local MODDIR = getWorkingDirectory() .. '\\radio24\\'
local ENV = setmetatable({}, { __index = _G })
local ORDER = { 'core', 'dictionary', 'kb_logic', 'learn', 'brain', 'tests', 'memory', 'state', 'textrules', 'variants', 'dialogs', 'hooks', 'reference', 'contracts', 'faq', 'auto', 'fuzzy', 'ui', 'app', 'upd_cfg', 'upd_install', 'upd_check', 'guard' }
for _, name in ipairs(ORDER) do
    local f, err = loadfile(MODDIR .. name .. '.lua')
    if not f then error('[radio24] модуль ' .. name .. ' не загружен: ' .. tostring(err), 0) end
    setfenv(f, ENV)
    local ok, e = pcall(f)
    if not ok then error('[radio24] модуль ' .. name .. ': ' .. tostring(e), 0) end
end

-- меню разработчика: есть только у разработчика, у остальных файла нет - это нормально
do
    local f = loadfile(MODDIR .. 'devmenu.lua')
    if f then
        setfenv(f, ENV)
        local ok, e = pcall(f)
        if not ok then print('[radio24] devmenu: ' .. tostring(e)) end
    end
end

if type(ENV.main) ~= 'function' then error('[radio24] в модулях не найдена main()', 0) end
if type(ENV.GUARD) ~= 'table' or ENV.GUARD.token ~= 'r24ok' then error('[radio24] защита не загружена - скрипт остановлен', 0) end
local realMain = ENV.main
main = function()
    if type(ENV.GUARD) ~= 'table' or ENV.GUARD.token ~= 'r24ok' then thisScript():unload(); return end
    realMain()
end

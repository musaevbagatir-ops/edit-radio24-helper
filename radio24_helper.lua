script_name('Radio24 AdHelper')
script_author('Bagatir_Wayne')
script_version('7.13')

-- Защита от падений lua51.dll (JIT): отключаем JIT-компиляцию для этого скрипта
if jit then pcall(jit.off, true, true) end

-- Модули лежат в папке moonloader\radio24\ (подпапки core, processing, learning, security, interface, updates) и грузятся по порядку ниже.
-- brain разбит на подмодули в radio24\processing\brain\ (этапы разбора объявления st_*.lua).
-- Все они работают в ОДНОМ общем окружении (как будто это один файл),
-- поэтому функции и таблицы видны между модулями без require.
-- upd_cfg / upd_install / upd_check - автообновление (должны идти ПОСЛЕ app).
-- guard - защита по рангу и от подмены, грузится последним. devmenu - необязательное меню разработчика.
local MODDIR = getWorkingDirectory() .. '\\radio24\\'
local ENV = setmetatable({}, { __index = _G })
local ORDER = {
    'core/core', 'processing/dictionary/dictionary_01_words', 'processing/dictionary/dictionary_02_kb_vehicles',
    'processing/dictionary/dictionary_03_kb_places_items', 'processing/dictionary/dictionary_04_tables_money', 'processing/kb_logic/kb_logic_01_numbers_transport',
    'processing/kb_logic/kb_logic_02_typos_helpers', 'processing/kb_logic/kb_logic_03_games_job_people', 'learning/learn/learn_01_rules_stats',
    'learning/learn/learn_02_names_people_cats', 'processing/brain/brain', 'processing/brain/text_utils',
    'processing/brain/special', 'processing/brain/st_01_prep', 'processing/brain/st_02_price',
    'processing/brain/st_03_dictionary', 'processing/brain/st_04_deal', 'processing/brain/st_05_order',
    'processing/brain/st_06_vehicles', 'processing/brain/st_07_house', 'processing/brain/st_08_tune',
    'processing/brain/st_09_assemble', 'processing/brain/st_10_final', 'security/tests',
    'learning/memory', 'core/state', 'processing/textrules',
    'processing/variants/variants_01_stray_data', 'processing/variants/variants_02_stray_clean', 'processing/variants/variants_03_order_case', 'processing/variants/variants_04_family_recheck', 'processing/variants/variants_05_build', 'processing/variants/variants_06_loadad', 'core/dialogs', 'core/hooks/hooks_01_trace_diag',
    'core/hooks/hooks_02_confirm_send', 'processing/reference', 'security/contracts',
    'interface/faq', 'learning/auto', 'processing/fuzzy/fuzzy_01_skeleton_tags',
    'processing/fuzzy/fuzzy_02_names_ru_cipher', 'interface/ui/ui_01_helpers_screens', 'interface/ui/ui_02_tabs_ads_memory_ref',
    'interface/ui/ui_03_tabs_stray_tags_tests_auto', 'interface/ui/ui_04_theme_contracts_settings_menu', 'interface/refbook',
    'core/app', 'updates/upd_cfg', 'updates/upd_install',
    'updates/upd_check', 'security/guard',
}
for _, name in ipairs(ORDER) do
    local f, err = loadfile(MODDIR .. (name:gsub('/', '\\')) .. '.lua')
    if not f then error('[radio24] модуль ' .. name .. ' не загружен: ' .. tostring(err), 0) end
    setfenv(f, ENV)
    local ok, e = pcall(f)
    if not ok then error('[radio24] модуль ' .. name .. ': ' .. tostring(e), 0) end
end

-- меню разработчика: есть только у разработчика, у остальных файла нет - это нормально
do
    local f = loadfile(MODDIR .. 'interface\\devmenu.lua')
    if f then
        setfenv(f, ENV)
        local ok, e = pcall(f)
        if not ok then print('[radio24] devmenu: ' .. tostring(e)) end
    end
end

-- журнал правок: обязательный служебный модуль
do
    local f, err = loadfile(MODDIR .. 'config\\processing\\radio24_logedit.lua')
    if not f then error('[radio24] модуль log не загружен: ' .. tostring(err), 0) end
    setfenv(f, ENV)
    local ok, e = pcall(f)
    if not ok then error('[radio24] модуль log: ' .. tostring(e), 0) end
end

if type(ENV.main) ~= 'function' then error('[radio24] в модулях не найдена main()', 0) end
if type(ENV.GUARD) ~= 'table' or ENV.GUARD.token ~= 'r24ok' then error('[radio24] защита не загружена - скрипт остановлен', 0) end
if type(ENV.ANCHOR) ~= 'table' or ENV.ANCHOR.token ~= 'r24anc' then error('[radio24] модуль log не загружен', 0) end
local realMain = ENV.main
main = function()
    if type(ENV.GUARD) ~= 'table' or ENV.GUARD.token ~= 'r24ok' then thisScript():unload(); return end
    realMain()
end

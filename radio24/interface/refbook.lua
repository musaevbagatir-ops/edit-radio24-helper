-- radio24/interface/refbook.lua: разделы справочника (вкладка "Справочник" в главном меню). Общее окружение модулей.
-- Вкладка показывает список разделов REFBOOK, по нажатию открывается нужный раздел (кнопка "< К разделам" возвращает назад).
-- КАК ДОБАВИТЬ РАЗДЕЛ: допиши строку в REFBOOK ниже или вызови refbookAdd('id', 'Название', 'подсказка', function() ... end).
--   draw рисуется внутри окна через imgui: imgui.TextWrapped('текст'), imgui.CollapsingHeader('заголовок') и т.д.
--   Тексты пишутся обычным UTF-8, T() для imgui не нужен.
--   Раздел из заголовков со строками (как REF в processing/reference.lua) собирается одной строкой:
--     { id = 'faqx', title = 'Название', hint = '...', draw = refbookSections({ { 'Заголовок', { 'строка 1', 'строка 2' } } }) }
-- Раздел ПРО: данные REF лежат в processing/reference.lua, отрисовка drawRefPro в interface/ui/ui_02_*.lua.
REFBOOK = {
    { id = 'pro', title = 'ПРО', hint = 'Правила Radio24: краткий пересказ, есть поиск', draw = function() drawRefPro() end },
    -- сюда добавляются новые разделы
}

function refbookAdd(id, title, hint, draw)
    for _, s in ipairs(REFBOOK) do
        if s.id == id then s.title, s.hint, s.draw = title, hint, draw; return end
    end
    REFBOOK[#REFBOOK + 1] = { id = id, title = title, hint = hint, draw = draw }
end

-- готовая отрисовка раздела: список { { 'Заголовок', { 'строка', ... } }, ... } со сворачиваемыми заголовками
function refbookSections(list)
    return function()
        imgui.BeginChild('##refsections', ImV2(-1, -1), true)
        for _, sec in ipairs(list) do
            if imgui.CollapsingHeader(sec[1]) then
                for _, line in ipairs(sec[2]) do imgui.TextWrapped('- ' .. line) end
            end
        end
        imgui.EndChild()
    end
end

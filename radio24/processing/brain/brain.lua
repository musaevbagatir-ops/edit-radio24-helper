-- radio24/processing/brain/brain.lua: мозг: разбор и исправление объявления. fixText запускает этапы st_01..st_10 по порядку (BRAIN.stages). Общее окружение модулей.
-- Этапы лежат в файлах st_*.lua рядом и регистрируются через BRAIN.stage. Порядок этапов = порядок в ORDER загрузчика radio24_helper.lua.
BRAIN = { stages = {} }
function BRAIN.stage(name, fn) BRAIN.stages[#BRAIN.stages + 1] = { name = name, fn = fn } end

-- opts.bare: только разбор объявления по ПРО без названий, тэгов и выученных правил (вариант "Чистый ПРО")
function fixText(src, opts)
    opts = opts or {}
    local notes = {}
    local info = { reject = {} }
    local function note(s) notes[#notes + 1] = s end
    CTXHAVE = ctxHaveSet(src)                 -- слова объявления: для правил с контекстом

    local s = stripColors(src)
    s = s:gsub('[\r\n\t]+', ' ')
    s = s:gsub('%s+', ' ')
    s = s:gsub('\\', '/')                      -- "к\с" -> "к/с"
    s = trim(s)
    if s == '' then return '', notes, info end

    local S = { src = src, opts = opts, notes = notes, info = info, note = note, s = s }
    for _, st in ipairs(BRAIN.stages) do
        st.fn(S)
        if S.result then return S.result[1], S.result[2], S.result[3] end
    end
    return S.text, S.notes, S.info
end

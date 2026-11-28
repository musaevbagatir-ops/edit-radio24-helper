-- radio24/processing/variants/variants_05_build.lua: часть 5 из 6 файла processing/variants. сборка вариантов объявления (buildVariants). Общее окружение модулей, см. radio24_helper.lua
function buildVariants(ad)
    local main, notes, info = fixText(ad)
    if type(info) == 'table' then info.rawMain = main end   -- текст ПРО до удаления слов (для обучения)
    local vars = {}
    local function alt(opts)                          -- вариант с другими настройками; сбой в нём не должен ронять скрипт
        local ok, t = pcall(fixText, ad, opts)
        if ok and type(t) == 'string' and t ~= '' then return t end
        return nil
    end
    local function hasNote(part)
        for _, n in ipairs(notes) do
            if n:find(part, 1, true) then return true end
        end
        return false
    end
    local mem = memGet(ad)
    if mem then vars[#vars + 1] = { label = T('Из памяти'), text = mem, mem = true } end
    vars[#vars + 1] = { label = T('По ПРО'), text = main }
    if info.names then                                -- названия из списка взяты в кавычки: даём вариант без них
        local a = alt({ noNames = true })
        if a and a ~= main then vars[#vars + 1] = { label = T('Без кавычек у названий'), text = a } end
    end
    if info.typo then                                 -- слова исправлены как опечатки: даём вариант без исправлений
        local a = alt({ noFuzzy = true })
        if a and a ~= main then vars[#vars + 1] = { label = T('Без исправления опечаток'), text = a } end
    end
    if info.glued then                                -- слитные слова разделены: даём вариант без разделения
        local a = alt({ noCipher = true })
        if a and a ~= main then vars[#vars + 1] = { label = T('Без разделения слитных слов'), text = a } end
    end
    if info.price and not info.torg then
        local a = alt({ dogovor = true })
        if a and a ~= main then vars[#vars + 1] = { label = T('С договорной ценой'), text = a } end
    end
    if info.price and info.torg then
        local a = alt({ forcePrice = true })
        if a and a ~= main then vars[#vars + 1] = { label = T('С указанной ценой'), text = a } end
    end
    if info.op == 'swap' and not main:find(T('доплат'), 1, true) then
        vars[#vars + 1] = { label = T('С доплатой'), text = main .. T(' с доплатой') }
    end
    if hasNote(T('процент не указан')) then           -- купон на т/с: 15% или 25% - даём второй вариант
        local a, n = main:gsub('15%%', '25%%')
        if n == 0 then a, n = main:gsub('25%%', '15%%') end
        if n > 0 then vars[#vars + 1] = { label = T('Другой процент скидки'), text = a } end
    end
    for _, v in ipairs(vars) do                       -- префиксы категорий (а/с, к/с) из настроек
        if not v.mem and not v.src then v.text = catPrefFix(v.text) end
    end
    local ctrNote                                     -- название организации по контракту
    for _, v in ipairs(vars) do
        if not v.mem and not v.src and ctrFixName then
            local ok, t, n = pcall(ctrFixName, v.text, ad)
            if ok and type(t) == 'string' then v.text = t; ctrNote = ctrNote or n end
        end
    end
    if ctrNote then notes[#notes + 1] = ctrNote end
    local famDone
    for _, v in ipairs(vars) do                       -- семья: всегда "ищет дальних родственников"
        if not v.mem and not v.src then
            local okF, t, ch = pcall(familyFix, v.text, ad)
            if okF and type(t) == 'string' and t ~= '' and ch then
                v.text = t
                if not famDone then famDone = true; notes[#notes + 1] = T('семья: добавлено "ищет дальних родственников"') end
            end
        end
    end
    -- Порядок: память/эталон -> ПРО (названия, тэги, выученные правила внутри fixText) -> префиксы и контракты
    --   -> правки текста (TX, в т.ч. авто-замены) -> лишние слова (STRAY, в т.ч. авто-удаления) последними -> "Чистый ПРО"
    local pos, extra                                  -- ручные правки текста (вкладка "Правки текста")
    for idx, v in ipairs(vars) do
        if not v.mem and not v.src then
            local t, alts, used = TX.apply(v.text, ad)
            v.text = t
            if not pos then
                pos, extra = idx, alts
                for _, u in ipairs(used) do notes[#notes + 1] = u end
            end
        end
    end
    for _, v in ipairs(vars) do                       -- правка "кс" -> "к/с" рядом с префиксом категории: "к/с к/с" -> "к/с"
        if not v.mem and not v.src then
            v.text = v.text:gsub('([\224-\255]/[\224-\255])(%s+)([\224-\255]/[\224-\255])', function(a, sp, b2)
                if lo(a) == lo(b2) then return a end
            end)
        end
    end
    if extra then for k, a in ipairs(extra) do table.insert(vars, pos + k, a) end end
    for _, v in ipairs(vars) do                       -- "и" между названиями и маленький регистр (до удаления лишнего: вариант "без удаления" тоже оформлен)
        if not v.mem and not v.src then
            local okA, t1 = pcall(andFix, v.text)
            if okA and type(t1) == 'string' and t1 ~= '' then v.text = t1 end
            local okC, t2 = pcall(caseFix, v.text)
            if okC and type(t2) == 'string' and t2 ~= '' then v.text = t2 end
        end
    end
    local rawIdx, rawText, strayWords                 -- лишние слова: убираем и даём вариант без удаления
    for idx, v in ipairs(vars) do
        if not v.mem and not v.src then
            local c, rm = strayClean(v.text, ad)
            if not (#rm > 0 and c ~= v.text) then c, rm = v.text, {} end
            local okO, c2, rm2 = pcall(orderClean, c, ad)         -- анализатор порядка: лишние слова/знаки между частями
            if okO and type(c2) == 'string' and type(rm2) == 'table' and #rm2 > 0 and c2 ~= c then
                c = c2
                for _, r in ipairs(rm2) do rm[#rm + 1] = r end
            end
            if #rm > 0 and c ~= v.text then
                if v.label == T('По ПРО') then                          -- слова убраны: перепроверяем результат разбором заново
                    local okR, c3 = pcall(recheckClean, c)
                    if okR and type(c3) == 'string' then
                        c = c3
                        notes[#notes + 1] = T('после удаления лишних слов объявление перепроверено')
                    end
                end
                if not rawIdx then rawIdx, rawText, strayWords = idx, v.text, rm end
                v.text = c
            end
        end
    end
    if rawIdx then
        table.insert(vars, rawIdx + 1, { label = T('Без удаления слов (как выдал ПРО)'), text = rawText, keep = true })
        notes[#notes + 1] = T('убрано лишнее слово: ') .. table.concat(strayWords, ', ')
        strayLogAdd('apply', table.concat(strayWords, ', '))
    end
    do                                                -- "Чистый ПРО": разбор без названий, тэгов, выученных правил, правок текста и лишних слов
        local bv = alt({ bare = true })
        if bv then
            vars[#vars + 1] = { label = T('Чистый ПРО (без названий, тэгов, выученных правил, правок и лишних слов)'),
                text = bv, bare = true }
        end
    end
    for _, v in ipairs(vars) do v.text = trim((tostring(v.text or ''):gsub('%s+', ' '))) end   -- один пробел везде
    local seen, res = {}, {}                          -- одинаковые по тексту варианты не показываем (первый остаётся)
    for _, v in ipairs(vars) do
        local key = (trim(v.text or ''):gsub('%s+', ' '):gsub('[%s%.]+$', ''))
        if not seen[key] then
            seen[key] = true
            res[#res + 1] = v
        end
    end
    return res, notes, info
end


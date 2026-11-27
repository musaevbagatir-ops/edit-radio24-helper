-- radio24/tests.lua: примеры ПРО как тесты (/adtest). Строки оригинала 2037-2110. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- ПРИМЕРЫ ПРО КАК ТЕСТЫ: /adtest прогоняет вход -> ожидаемая редакция (в т.ч. вариации примеров).
-- Новое правило ПРО: добавь пример сюда и в словарь KB - команда покажет, что сломалось.
---------------------------------------------------------------------
KB.examples = {
    { [==[Продам АЗС в Голден Виллидж, 2кк]==], [==[Продам п/п АЗС в д. Golden Village. Цена: 2.000.000$]==] },
    { [==[Продам АЗС в Golden Villige, 2кк]==], [==[Продам п/п АЗС в д. Golden Village. Цена: 2.000.000$]==] },
    { [==[Продам АЗС в ghetto, 2кк]==], [==[Продам п/п АЗС в опасном районе. Цена: 2.000.000$]==] },
    { [==[Продам АЗС у ВЧ, 2кк]==], [==[Продам п/п АЗС у Военной базы. Цена: 2.000.000$]==] },
    { [==[Продам АЗС на ЦР, 2кк]==], [==[Продам п/п АЗС на ЦР. Цена: 2.000.000$]==] },
    { [==[Продам АЗС у пляжа Санта Мариа, 2кк]==], [==[Продам п/п АЗС у пляжа Santa-Maria. Цена: 2.000.000$]==] },
    { [==[Продам АЗС у пляжа Santa Maria, 2кк]==], [==[Продам п/п АЗС у пляжа Santa-Maria. Цена: 2.000.000$]==] },
    { [==[Продам АЗС в Блуберри, 2кк]==], [==[Продам п/п АЗС в д. Blueberry. Цена: 2.000.000$]==] },
    { [==[Продам АЗС в Блубери, 2кк]==], [==[Продам п/п АЗС в д. Blueberry. Цена: 2.000.000$]==] },
    { [==[Продам АЗС в Montgomary, 2кк]==], [==[Продам п/п АЗС в д. Montgomery. Цена: 2.000.000$]==] },
    { [==[Продам АЗС в Лас-Брухас, 2кк]==], [==[Продам п/п АЗС в д. Las Brujas. Цена: 2.000.000$]==] },
    { [==[Продам АЗС в Валле Окультадо, 2кк]==], [==[Продам п/п АЗС в д. Valle Ocultado. Цена: 2.000.000$]==] },
    { [==[Продам АЗС в Эль-Кебрадос, 2кк]==], [==[Продам п/п АЗС в д. El Quebrados. Цена: 2.000.000$]==] },
    { [==[Продам АЗС в Альдеа-Мальвада, 2кк]==], [==[Продам п/п АЗС в д. Aldea Malvada. Цена: 2.000.000$]==] },
    { [==[Продам АЗС в Los Santoss, 2кк]==], [==[Продам п/п АЗС в г. Los Santos. Цена: 2.000.000$]==] },
    { [==[Продам АЗС в Сан-Фиерро, 2кк]==], [==[Продам п/п АЗС в г. San Fierro. Цена: 2.000.000$]==] },
    { [==[Куплю а/м Toyota.]==], [==[Куплю а/м марки "Toyota". Бюджет: свободный]==] },
    { [==[Куплю а/м марки Toyota Tundra.]==], [==[Куплю а/м "Toyota Tundra". Бюджет: свободный]==] },
    { [==[Продам н/з формата 666.]==], [==[Продам н/з формата "666". Цена: договорная]==] },
    { [==[Продам н/з формата U666PO.]==], [==[Продам н/з "U666PO". Цена: договорная]==] },
    { [==[Продам с/к формата XX-XX-CC.]==], [==[Продам с/к формата "XX-XX-CC". Цена: договорная]==] },
    { [==[Продам с/к формата 77-77-33.]==], [==[Продам с/к "77-77-33". Цена: договорная]==] },
    { [==[Куплю п/п любого типа.]==], [==[Куплю любое п/п в любой точке штата. Бюджет: свободный]==] },
    { [==[Продам чай марки Lipton.]==], [==[Продам чай. Цена: договорная]==] },
    { [==[Куплю инфернус]==], [==[Куплю а/м "Infernus". Бюджет: свободный]==] },
    { [==[Продам дом бизнес в лс с наклейкой "Full". Цена 1.5кк]==], [==[Продам дом бизнес-класса с евроремонтом в г. Los Santos. Цена: 1.500.000$]==] },
    { [==[Продам дом у творческой зоны эконом класс.]==], [==[Продам дом эконом-класса у Творческой зоны. Цена: договорная]==] },
    { [==[Куплю Новостной фургон за 200кк.]==], [==[Куплю а/м "Новостной фургон" [Премиум]. Бюджет: 200.000.000$]==] },
    { [==[Куплю кловер за 300к]==], [==[Куплю а/м "Clover". Бюджет: 300.000$]==] },
    { [==[Продам султан фт пт.]==], [==[Продам а/м "Sultan" [FT/PT]. Цена: договорная]==] },
    { [==[Продам нрг, маверик]==], [==[Продам м/ц "NRG-500" и л/т "Maverick". Цена: договорная]==] },
    { [==[Продам буллет full хв]==], [==[Продам а/м "Bullet" [HW/FT/PT]. Цена: договорная]==] },
    { [==[Продам инфернус с нитро и новыми дисками]==], [==[Продам а/м "Infernus" [Tune: нитро, диски]. Цена: договорная]==] },
    { [==[продам бульку с номером Х777ХХ]==], [==[Продам а/м "Bullet" с н/з "X777XX". Цена: договорная]==] },
    { [==[продам номер х222хх]==], [==[Продам н/з "X222XX". Цена: договорная]==] },
    { [==[обменяю номер у888уу]==], [==[Обменяю н/з "Y888YY" на другой н/з с доплатой]==] },
    { [==[продам велик ферари]==], [==[Продам в/с "Ferrari". Цена: договорная]==] },
    { [==[сдам нрг и ламбу, 10к]==], [==[Сдам в аренду м/ц "NRG-500" и а/м "Lamborghini Huracan". Цена: 10.000$]==] },
    { [==[Куплю бизнес, есть 10кк]==], [==[Куплю любое п/п в любой точке штата. Бюджет: 10.000.000$]==] },
    { [==[Продам АЗС в ЛС, 2кк]==], [==[Продам п/п АЗС в г. Los Santos. Цена: 2.000.000$]==] },
    { [==[Куплю дом, 5кк]==], [==[Куплю дом любого класса в любой точке штата. Бюджет: 5.000.000$]==] },
    { [==[Продам особу в бейсайде]==], [==[Продам особняк в д. BaySide. Цена: договорная]==] },
    { [==[Продам ballas shop.]==], [==[Продам п/п 24/7 "Ballas Shop" в опасном районе. Цена: договорная]==] },
    { [==[Продам дом за 5кк бизнес класс на вв, торг]==], [==[Продам дом бизнес-класса на горе Vinewood. Цена: договорная]==] },
    { [==[продам падик]==], [==[Продам подвальное помещение. Цена: договорная]==] },
    { [==[продам дом комфорт у вв н38 400к]==], [==[Продам дом комфорт класса с номером "38" у горы Vinewood. Цена: 400.000$]==] },
    { [==[сдам падик]==], [==[Сдам в аренду подвальное помещение. Цена: договорная]==] },
    { [==[продам м4 1000 пт. цена за шт 50]==], [==[Продам пули для бластера "M4" в количестве 1000 штук. Цена: 50$ за штуку]==] },
    { [==[Куплю нарко 20гр]==], [==[Куплю чай в количестве 20 пачек. Бюджет: свободный]==] },
    { [==[Продам нарко 10к]==], [==[Продам чай в кол-ве 10.000 пакетиков. Цена: договорная]==] },
    { [==[Продам много чая по 150$]==], [==[Продам чай в большом количестве. Цена: 150$ за пачку]==] },
    { [==[продам сиги 3шт]==], [==[Продам т/и "Fast" в кол-ве 3 шт. Цена: договорная]==] },
    { [==[куплю маты 100шт]==], [==[Куплю запчасти к бластеру в кол-ве 100шт. Бюджет: свободный]==] },
    { [==[Познакомлюсь с девушкой, я богат]==], [==[Познакомлюсь с девушкой для с/о. О себе: богатый]==] },
    { [==[Устроюсь на любую работу]==], [==[Трудоустроюсь. О себе: имеется опыт во всех сферах деятельности]==] },
    { [==[Продам симку с номером 266633]==], [==[Продам с/к "XY-YY-ZZ". Цена: договорная]==] },
    { [==[Ищу игрока в казино, ставка 250к]==], [==[Ищу азартного игрока в "Кости". Ставка: 250.000$]==] },
    { [==[Продам гитару за 4кк, лавка №7]==], [==[Продам а/с "Гитара", лавка №7 на ЦР. Цена: 4.000.000$]==] },
    { [==[Куплю вибратор за 5к]==], [==[Куплю игрушку "Вибратор". Бюджет: 5.000$]==] },
    { [==[Куплю купон тс 15%]==], [==[Куплю купон "Скидочный купон на покупку т/с 15%". Бюджет: свободный]==] },
    { [==[Продам лопату]==], [==[Продам лопату из 24/7. Цена: договорная]==] },
    { [==[Продам купон х2 зп 40k]==], [==[Продам купон "Зарплата Х2 на 3ч". Цена: 40.000$]==] },
    { [==[Куплю купон х2 опыт 40к]==], [==[Куплю купон "Игровой опыт Х2 на 6ч". Бюджет: 40.000$]==] },
    { [==[Куплю купон на х2 работы]==], [==[Куплю купон "Купон на прокачку навыков работы х2". Бюджет: свободный]==] },
    { [==[Ищу игрока в дмз]==], [==[Ищу человека в "Тир". Ставка: договорная]==] },
    { [==[Продам пикачу на плечо и маску тыквы]==], [==[Продам а/с "Пикачу на плечо" и а/с "Маска тыквы". Цена: договорная]==] },
    { [==[Ищу игрока в кости ставка 100к]==], [==[Ищу азартного игрока в "Кости". Ставка: 100.000$]==] },
    { [==[Ищу игрока в бар]==], [==[Ищу азартного игрока в "Орел и решка". Ставка: договорная]==] },
    { [==[Ищу игрока в орёл и решка, ставка свободная]==], [==[Ищу азартного игрока в "Орел и решка". Ставка: свободная]==] },
    { [==[Ищу напарника в тир, ставка 50к]==], [==[Ищу человека в "Тир". Ставка: 50.000$]==] },
    { [==[Трудоустроюсь водителем такси]==], [==[Трудоустроюсь водителем такси. О себе: имею опыт в данной сфере деятельности]==] },
    { [==[Ищу работу охранником, зп 50к]==], [==[Трудоустроюсь охранником. О себе: имею опыт в данной сфере деятельности. Цена: 50.000$]==] },
    { [==[Ищу работу на водителя такси]==], [==[Трудоустроюсь водителем такси. О себе: имею опыт в данной сфере деятельности]==] },
    { [==[Ищу Миллера Уэйна]==], [==[Ищу человека по имени Miller Wayne. Перезвони по возможности]==] },
    { [==[Продам гитару за 4кк, лавка 12]==], [==[Продам а/с "Гитара", лавка №12 на ЦР. Цена: 4.000.000$]==] },
    { [==[В 24/7 возле мэрии проходит розыгрыш инфернуса.]==], [==[В магазине 24/7 возле Мэрии проходит розыгрыш а/м "Infernus"]==] },
    { [==[куплю кловер 300к]==], [==[Куплю а/м "Clover". Бюджет: 300.000$]==] },
    { [==[куплю clover за 300000]==], [==[Куплю а/м "Clover". Бюджет: 300.000$]==] },
    { [==[хочу приобрести кловер, бюджет 300к]==], [==[Куплю а/м "Clover". Бюджет: 300.000$]==] },
    { [==[куплю клевер, есть 300к]==], [==[Куплю а/м "Clover". Бюджет: 300.000$]==] },
    { [==[куплю clover, бюджет свободный]==], [==[Куплю а/м "Clover". Бюджет: свободный]==] },
    { [==[Обменяю 24/7 в лс на инфу]==], [==[Обменяю п/п магазин 24/7 в г. Los Santos на а/м "Infernus"]==] },
    { [==[Ищу Джексона Хеллвуда]==], [==[Ищу человека по имени Jackson Hellwood. Перезвони по возможности]==] },
    -- примеры из памяти (radio24_memory.txt)
    { [==[продам пульки цена договорная]==], [==[Продам пульки для бластера. Цена: договорная]==] },
    { [==[Продам дом VIP Особняк в д.Golder Village. Цена 40.000.000$]==], [==[Продам Особняк в д. Golden Village. Цена: 40.000.000$]==] },
    { [==[Куплю а/м "Тайота Крузак 100". Цена: договорная..]==], [==[Куплю а/м "Toyota Cruiser 100". Бюджет: свободный]==] },
    { [==[продам мраморное мясо тел: 499625]==], [==[Продам а/с "Мраморное мясо". Цена: 499.625$]==] },
    { [==[Куплю а/м "Aston Martin DBS" [HW25]. Бюджет: свободный]==], [==[Куплю а/м "Aston Martin DBS" [HW25]. Бюджет: свободный]==] },
    { [==[продам дом эконом класса в гетто лс #208 гараж 1x цена 400k]==], [==[Продам дом эконом-класса с номером "208" с гаражом в опасном районе. Цена: 400.000$]==] },
    { [==[Продам к\с "Скелетон" [HW23]. Цена:Договорная]==], [==[Продам к/с "Скелетон" [HW23]. Цена: договорная]==] },
    { [==[Продам а/м "Mercedes AMG GT" [BDAY7]. Цена: договорная]==], [==[Продам а/м "Mercedes AMG GT" [BDAY7]. Цена: договорная]==] },
    { [==[Обменяю McLaren 650S на любой а/м]==], [==[Обменяю а/м "McLaren 650S" на любой а/м с доплатой]==] },
    { [==[Куплю любой а/с и к/с из колекции [HW2026]. Бюджет:свободный]==], [==[Куплю любой а/с и к/с из коллекции [HW26]. Бюджет: свободный]==] },
}

---------------------------------------------------------------------
-- Свои тесты и правка нужных вариантов (вкладка "Тесты"). Хранится в UTF-8 в radio24_tests.txt:
--   u - свой тест, o - исправленный нужный вариант встроенного теста, d - выключенный встроенный тест
---------------------------------------------------------------------
KB.user = { list = {}, over = {}, off = {} }
KB.log = {}                       -- журнал изменений тестов: { ts, kind, inp, old, new }

local function oneL(s) return (tostring(s or ''):gsub('[\t\r\n]', ' ')) end

function testsSave()
    pcall(function()
        local f = io.open(DIR .. 'radio24_tests.txt', 'wb')
        if not f then return end
        for _, t in ipairs(KB.user.list) do f:write('u\t', oneL(t[1]), '\t', oneL(t[2]), '\n') end
        for k, v in pairs(KB.user.over) do f:write('o\t', oneL(k), '\t', oneL(v), '\n') end
        for k in pairs(KB.user.off) do f:write('d\t', oneL(k), '\n') end
        for _, l in ipairs(KB.log) do
            f:write('l\t', tostring(l.ts), '\t', l.kind, '\t', oneL(l.inp), '\t', oneL(l.old), '\t', oneL(l.new), '\n')
        end
        f:close()
    end)
end

function testsLoad()
    KB.user = { list = {}, over = {}, off = {} }
    KB.log = {}
    pcall(function()
        local f = io.open(DIR .. 'radio24_tests.txt', 'rb')
        if not f then return end
        for line in f:lines() do
            local ts, kind, inp, old, new = line:match('^l\t(%d+)\t(%a+)\t(.-)\t(.-)\t(.*)$')
            if ts then
                KB.log[#KB.log + 1] = { ts = tonumber(ts), kind = kind, inp = inp, old = old, new = new }
            else
                local k, a, b = line:match('^(%a)\t(.-)\t(.*)$')
                if k == 'u' then KB.user.list[#KB.user.list + 1] = { a, b }
                elseif k == 'o' then KB.user.over[a] = b end
                local d = line:match('^d\t(.+)$')
                if d then KB.user.off[d] = true end
            end
        end
        f:close()
    end)
end

function testsLog(kind, inp, old, new)
    KB.log[#KB.log + 1] = { ts = os.time(), kind = kind, inp = inp or '', old = old or '', new = new or '' }
    if #KB.log > 200 then table.remove(KB.log, 1) end
    testsSave()
end

-- новый нужный результат для теста t (kind: edit / accept / undo)
function testsSetExp(t, newExp, kind)
    local old = t.exp
    if t.src == 'user' then
        if KB.user.list[t.idx] then KB.user.list[t.idx][2] = newExp end
    else
        local orig
        for _, ex in ipairs(KB.examples) do if ex[1] == t.inp then orig = ex[2] end end
        KB.user.over[t.inp] = (orig ~= newExp) and newExp or nil
    end
    testsLog(kind, t.inp, old, newExp)
end

function testsAddUser(inp, exp, silent)
    KB.user.list[#KB.user.list + 1] = { oneL(inp), oneL(exp) }
    if not silent then testsLog('add', inp, '', exp) end
end

function testsDrop(t)
    if t.src == 'user' then table.remove(KB.user.list, t.idx) else KB.user.off[t.inp] = true end
    testsLog('delete', t.inp, t.exp, '')
end

-- откат записи журнала (правка нужного / принятый результат)
function testsRestore(entry)
    for _, t in ipairs(KB.allTests()) do
        if t.inp == entry.inp then testsSetExp(t, entry.old, 'undo'); return true end
    end
    return false
end

function KB.allTests()
    local all = {}
    for _, ex in ipairs(KB.examples) do
        if not KB.user.off[ex[1]] then
            all[#all + 1] = { inp = ex[1], exp = KB.user.over[ex[1]] or ex[2], src = 'builtin', orig = ex[2] }
        end
    end
    for i, ex in ipairs(KB.user.list) do all[#all + 1] = { inp = ex[1], exp = ex[2], src = 'user', idx = i } end
    return all
end

local function nrm(s) return trim((tostring(s or ''):gsub('%s+', ' '))) end

-- Режим 'names': на время ОДНОГО теста в NAMES добавляются названия в кавычках из ОЖИДАЕМЫХ текстов ДРУГИХ тестов
-- (тест никогда не учит сам себя). Это имитация списка названий, который ты наработал правками в меню.
-- Всё добавленное убирается сразу после теста, на диск ничего не пишется.
local function seedNames(all, skipInp)
    local added = {}
    if type(NAMES) ~= 'table' then return added end
    local U = up or string.upper
    for _, o in ipairs(all) do
        if o.inp ~= skipInp then
            for q in tostring(o.exp):gmatch('"([^"]+)"') do
                local nm = T(q)
                local k = lo(nm)
                if #nm >= 3 and not nm:match('^[%d%s%p]+$') and not nm:find('/', 1, true)
                    and not (#nm >= 5 and U(nm) == nm) and NAMES[k] == nil then
                    NAMES[k] = { name = nm, on = true, n = 3, time = os.time(), cat = '', fromTest = true }
                    added[#added + 1] = k
                end
            end
        end
    end
    return added
end

local function unseedNames(added)
    if not added then return end
    for _, k in ipairs(added) do
        if NAMES[k] and NAMES[k].fromTest then NAMES[k] = nil end
    end
end

-- Диагностика промаха полного теста: что сработало, что есть среди вариантов, почему не применились правки
local function diagnose(x, inpCp, expCp, got)
    for _, v in ipairs(x.vars or {}) do
        if nrm(v.text) == nrm(expCp) then x.alts[#x.alts + 1] = v.label end
    end
    pcall(function()
        for _, r in ipairs(TX.rules) do
            local w = TX.whyNot(got, inpCp, r)
            if w then x.why[#x.why + 1] = w end
        end
    end)
    pcall(function()
        local have = strayHave(inpCp)
        local lg = lo(got)
        for w, e in pairs(STRAY) do
            if e.on ~= false and not e.lit and lg:find(w, 1, true) and not strayCtxOk(e, have) then
                x.why[#x.why + 1] = T('лишнее слово «') .. w .. T('»: не удалено, не подходит по контексту')
            end
        end
    end)
    x.vars = nil
end

-- mode 'pro'  : только fixText (основная логика ПРО)
-- mode 'names': как 'full' + временные названия из других тестов (см. seedNames)
-- mode 'full' : buildVariants как в игре (названия, тэги, выученные правила, TX, STRAY, префиксы, контракты),
--               но без памяти и эталонов; журналы/счётчики правил после теста возвращаются как были
-- bad[i] = { вход(UTF-8), нужно(UTF-8), вышло(CP1251), тест, диагностика (только full) }
function KB.selftest(mode)
    local withNames = (mode == 'names')
    local noCtr = (mode == 'noctr')                   -- полный режим без шага "контракты" (не зависит от кэша с сайта)
    local full = (mode == 'full' or withNames or noCtr)
    local ok, bad = 0, {}
    local sv, hits, nlog = {}, {}, STRAYLOG and #STRAYLOG or 0
    if full then
        for i, r in ipairs(TX.rules) do hits[i] = r.hits end
        sv.mem, sv.src, sv.log = memGet, srcMatch, strayLogAdd
        if type(sv.mem) == 'function' then memGet = function() return nil end end
        if type(sv.src) == 'function' then srcMatch = function() return nil end end
        if type(sv.log) == 'function' then strayLogAdd = function() end end
        if noCtr then sv.ctr = ctrFixName; ctrFixName = nil end
    end
    local all = KB.allTests()
    for _, t in ipairs(all) do
        local inp, expCp = T(t.inp), T(t.exp)
        local good, got, x
        if full then
            local seeded = withNames and seedNames(all, t.inp) or nil
            local g, vars, notes = pcall(buildVariants, inp)
            unseedNames(seeded)
            good = g
            if g then
                local main
                for _, v in ipairs(vars) do
                    if not v.mem and not v.src then main = v; break end
                end
                got = main and main.text or ''
                x = { label = main and main.label or '', notes = table.concat(notes or {}, '; '),
                    alts = {}, why = {}, vars = vars, nseed = seeded and #seeded or 0 }
            else
                got = vars
            end
        else
            good, got = pcall(fixText, inp)
        end
        if not good then got = T('(ошибка разбора) ') .. tostring(got) end
        local same
        if full then same = good and nrm(got) == nrm(expCp) else same = good and got == expCp end
        if same then
            ok = ok + 1
        else
            if x then diagnose(x, inp, expCp, got) end
            bad[#bad + 1] = { t.inp, t.exp, got, t, x }
        end
    end
    if full then
        if type(sv.mem) == 'function' then memGet = sv.mem end
        if type(sv.src) == 'function' then srcMatch = sv.src end
        if type(sv.log) == 'function' then strayLogAdd = sv.log end
        if noCtr then ctrFixName = sv.ctr end
        for i, r in ipairs(TX.rules) do r.hits = hits[i] end
        while STRAYLOG and #STRAYLOG > nlog do table.remove(STRAYLOG) end
    end
    return ok, bad
end

-- Результат хелпера для одного объявления (CP1251). pro - fixText; full/names - buildVariants без памяти и эталона,
-- без записи журналов и счётчиков правил (для кнопки "Получить результат хелпера" в окне тестов)
function KB.helperText(inpCp, mode)
    if mode == 'pro' then return (fixText(inpCp)) end
    local sm, ss, sl = memGet, srcMatch, strayLogAdd
    local hits, nlog = {}, STRAYLOG and #STRAYLOG or 0
    for i, r in ipairs(TX.rules) do hits[i] = r.hits end
    if type(sm) == 'function' then memGet = function() return nil end end
    if type(ss) == 'function' then srcMatch = function() return nil end end
    if type(sl) == 'function' then strayLogAdd = function() end end
    local ok, vars = pcall(buildVariants, inpCp)
    if type(sm) == 'function' then memGet = sm end
    if type(ss) == 'function' then srcMatch = ss end
    if type(sl) == 'function' then strayLogAdd = sl end
    for i, r in ipairs(TX.rules) do r.hits = hits[i] end
    while STRAYLOG and #STRAYLOG > nlog do table.remove(STRAYLOG) end
    if not ok then error(vars, 0) end
    for _, v in ipairs(vars) do
        if not v.mem and not v.src then return v.text end
    end
    return ''
end

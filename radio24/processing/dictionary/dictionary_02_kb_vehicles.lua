-- radio24/processing/dictionary_02_kb_vehicles.lua: часть 2 из 4 файла processing/dictionary. база знаний ПРО (таблицы), часть 1: глаголы сделки, транспорт, марки. Общее окружение модулей, см. radio24_helper.lua
-- Локальные переменные, нужные соседним частям, передаются через таблицу DICTX (в конце части экспорт, в начале - повторное объявление).
---------------------------------------------------------------------
-- БАЗА ЗНАНИЙ ПРО (расширяет DICT). Новое слово = одна строка в нужном разделе, логику не трогай.
-- Разделы: ГЛАГОЛЫ / ТРАНСПОРТ / МАРКИ / ЛОКАЦИИ / СОКРАЩЕНИЯ / ТОВАРЫ / КРИМИНАЛ.
-- Помощники лежат в таблице KB (лимит локальных переменных Lua).
---------------------------------------------------------------------
KB = { gunkw = {}, vehfuzz = {} }
do
    local function ends(w, x) return #w >= #x and w:sub(-#x) == x end
    local function forms(w)                 -- падежные формы для РАСПОЗНАВАНИЯ (смысл не меняют)
        local r = { w }
        if w:byte(#w) < 128 then return r end
        local function stem(x) return w:sub(1, #w - #x) end
        if ends(w, 'а') then
            r[#r + 1] = stem('а') .. 'у'; r[#r + 1] = stem('а') .. 'ы'; r[#r + 1] = stem('а') .. 'ой'
        elseif ends(w, 'я') or ends(w, 'ь') or ends(w, 'й') or ends(w, 'о') or ends(w, 'е')
            or ends(w, 'и') or ends(w, 'у') or ends(w, 'ю') or ends(w, 'ы') then
            -- формы не строим
        else
            r[#r + 1] = w .. 'а'; r[#r + 1] = w .. 'у'; r[#r + 1] = w .. 'ом'
        end
        return r
    end
    KB.forms = forms

    -- ГЛАГОЛЫ: разговорные формы -> базовые слова сделки (OPS их распознаёт)
    for k, v in pairs({ ['хочу купить'] = 'куплю', ['хочу приобрести'] = 'куплю', ['желаю купить'] = 'куплю',
        ['приобрести'] = 'куплю', ['купить'] = 'куплю', ['хочу продать'] = 'продам', ['продать'] = 'продам', ['продается'] = 'продам', ['продаётся'] = 'продам',
        ['хочу обменять'] = 'обменяю', ['обменять'] = 'обменяю', ['хочу сдать'] = 'сдам', ['сдать'] = 'сдам' }) do
        add(k, v)
    end

    -- ТРАНСПОРТ (п.3.2). Строка: 'Name|рус1,рус2'. Звёздочка у Name = латиницу как слово не искать.
    local PFX = { car = 'а/м', bike = 'м/ц', air = 'л/т', boat = 'в/т', bicycle = 'в/с' }
    local function addVeh(kind, spec)
        local name, rest = spec:match('^([^|]+)|?(.*)$')
        local latin = true
        if name:sub(-1) == '*' then latin = false; name = name:sub(1, -2) end
        local val = PFX[kind] .. ' "' .. name .. '"'
        local lk = name:lower()
        if latin then
            add(lk, val, nil, 'veh')
            KB.vehfuzz[#KB.vehfuzz + 1] = { key = T(lk), val = T(val) }
        end
        for ru in rest:gmatch('[^,]+') do
            for n, f in ipairs(forms(ru)) do
                add(f, val, nil, 'veh')
                if n == 1 then KB.vehfuzz[#KB.vehfuzz + 1] = { key = T(f), val = T(val) } end
            end
        end
    end
    local VEH = {
        car = { 'Admiral|адмирал', 'Banshee|банши', 'Blista Compact|блиста,блиста компакт', 'Bobcat|бобкэт,бобкат',
            'Buccaneer|бакканир,букканир', 'Buffalo|буффало,баффало,буфало', 'Bullet|буллет,булет,булька',
            'Cabbie|кэбби', 'Cadrona|кадрона', 'Cheetah|чита', 'Clover|кловер,клевер,клувер', 'Comet*|комета',
            'Coquette|кокетт,кокетка', 'Elegant|элегант', 'Elegy|элегия', 'Euros|юрос', 'Feltzer|фелтцер,фельцер',
            'Flash*|флэш,флеш', 'Glendale|глендейл', 'Greenwood|гринвуд', 'Hotknife|хотнайф',
            'Hotring Racer|хотринг,хотринг рейсер', 'Huntley|хантли', 'Infernus|инфернус,инфа', 'Intruder|интрудер',
            'Jester|джестер', 'Landstalker|ландсталкер,ландстолкер', 'Lamborghini Huracan|ламба,ламбу,ламборгини,ламборджини',
            'Manana|манана', 'Nebula|небула', 'Oceanic|океаник', 'Picador|пикадор', 'Previon|превион',
            'Remington|ремингтон', 'Sabre|сабре,сабер', 'Sentinel|сентинел', 'Slamwan|сламван', 'Stallion|сталлион',
            'Stratum|стратум', 'Sultan|султан', 'Sunrise|санрайз', 'Super GT|супер гт', 'Tahoma|тахома', 'Tampa|тампа',
            'Turismo|туризмо', 'Uranus|уранус', 'Vincent|винсент', 'Virgo|вирго', 'Voodoo|вуду',
            'Washington|вашингтон', 'Willard|виллард', 'Windsor|виндзор', 'ZR-350|зр350,зр-350' },
        bike = { 'NRG-500|нрг,нрг500,нрг-500', 'PCJ-600|псж,псж600,псж-600', 'FCR-900|фцр,фцр900,фцр-900',
            'BF-400|бф400,бф-400', 'Sanchez|санчес,санчез', 'Faggio|фаджио,фаггио', 'Freeway|фривей',
            'Wayfarer|вэйфарер,вейфарер', 'Pizzaboy|пиццабой', 'Quad|квадроцикл,квадрик' },
        bicycle = { 'BMX|бмх,бмикс', 'Mountain Bike|маунтин байк,горный велосипед', 'Bike*|байк' },
        air = { 'Maverick|маверик,мавер', 'Hunter|хантер', 'Cargobob|каргобоб', 'Leviathan|левиафан',
            'Seasparrow|сиспарроу', 'Sparrow|спарроу', 'Raindance|рейндэнс', 'Dodo|додо', 'Shamal|шамал', 'Beagle|бигл',
            'Nevada|невада', 'Rustler|растлер', 'Stuntplane|стантплейн', 'Hydra|гидра', 'Skimmer|скиммер',
            'Andromada|андромада', 'Cropduster|кропдастер' },
        boat = { 'Marquis|маркиз', 'Jetmax|джетмакс', 'Speeder|спидер', 'Squalo|сквало', 'Tropic|тропик',
            'Reefer|рифер', 'Dinghy|динги', 'Predator|предатор', 'Launch*|лаунч', 'Coastguard|коастгард' },
    }
    for kind, list in pairs(VEH) do for _, spec in ipairs(list) do addVeh(kind, spec) end end
    add('slamvan', 'а/м "Slamwan"', nil, 'veh')

    -- МАРКИ (ПРО 3.2: «марки "Toyota"»): значение только в кавычках, «а/м» добавится в fixText
    for _, spec in ipairs({ 'Toyota|тойота', 'Honda|хонда', 'BMW|бмв,бэха', 'Mercedes|мерседес,мерс', 'Audi|ауди',
        'Ferrari|феррари,ферари', 'Ford|форд', 'Nissan|ниссан', 'Porsche|порше', 'Chevrolet|шевроле', 'Dodge|додж',
        'Mazda|мазда', 'Subaru|субару', 'Lexus|лексус', 'Bentley|бентли', 'Tesla|тесла' }) do
        local name, rest = spec:match('^([^|]+)|(.*)$')
        for ru in rest:gmatch('[^,]+') do
            for n, f in ipairs(forms(ru)) do
                add(f, '"' .. name .. '"', nil, 'veh')
                if n == 1 then KB.vehfuzz[#KB.vehfuzz + 1] = { key = T(f), val = T('"' .. name .. '"') } end
            end
        end
    end

    DICTX = DICTX or {}; DICTX.forms = forms; DICTX.addVeh = addVeh
end

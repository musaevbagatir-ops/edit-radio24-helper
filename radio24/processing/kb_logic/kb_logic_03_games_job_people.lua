-- radio24/processing/kb_logic_03_games_job_people.lua: часть 3 из 3 файла processing/kb_logic. азартные игры, тир, работа, знакомства, поиск человека по имени. Общее окружение модулей, см. radio24_helper.lua
-- Локальные переменные, нужные соседним частям, передаются через таблицу LOGICX (в конце части экспорт, в начале - повторное объявление).
do
    local forms, editDist, translit, TL, wordList, wordHit, tailFor = LOGICX.forms, LOGICX.editDist, LOGICX.translit, LOGICX.TL, LOGICX.wordList, LOGICX.wordHit, LOGICX.tailFor
    -- азартные игры / тир
    local G_DICE  = set { 'кости', 'кость', 'костей', 'костях', 'костям', 'костями', 'косточки', 'косточек', 'кубики', 'кубик',
        'кубика', 'кубиков', 'казино', 'казик', 'казика', 'казине', 'dice', 'дайс', 'дайсы' }
    local G_DICEF = TL { 'казино', 'косточки', 'кубики' }
    local G_COINS = TL { 'монет', 'орел', 'орёл', 'орлян', 'решк' }
    local G_BAR   = set { 'бар', 'бара', 'бару', 'баре' }
    local G_TIR   = set { 'дмз', 'дмс', 'дзм', 'дмзз', 'dmz', 'тир', 'тира', 'тиру', 'тире', 'тиры' }
    local G_TIRS  = TL { 'стрельб', 'пострел', 'стрелят', 'стреляй' }
    local G_TIRF  = TL { 'стрельба', 'пострелять', 'стрельбище' }
    local STAKE_KW = TL { 'ставк', 'ставл', 'бюджет', 'цена', 'цену', 'ценой' }

    -- работа
    local JOB_SKIP = set { 'на', 'работу', 'работа', 'работе', 'работы', 'по', 'как', 'кем', 'кем-то', 'кем-нибудь', 'кем-либо',
        'угодно', 'пожалуйста', 'срочно', 'любую', 'любая', 'любой', 'любым', 'любое', 'любого', 'хорошую', 'нормальную',
        'постоянную', 'оплачиваемую', 'хочу', 'желаю', 'буду', 'работать', 'ищу', 'ищем', 'нужна', 'нужен', 'нужно',
        'возьмите', 'устроюсь', 'устроюся', 'трудоустроюсь', 'трудоустроюся', 'устроиться', 'трудоустроиться', 'мне', 'я', 'а',
        'бы', 'то', 'же', 'либо', 'именно', 'где', 'можно', 'вакансию', 'должность', 'профессии', 'профессия', 'сфере',
        'сфера', 'деятельности', 'сейчас', 'готов', 'готова', 'плз', 'пж', 'просто', 'какую', 'какую-нибудь', 'любую-нибудь',
        'нибудь', 'желательно' }
    local JOB_STOP = set { 'зп', 'з/п', 'зарплата', 'зарплату', 'зарплаты', 'оплата', 'оплату', 'оплатой', 'плата', 'платят',
        'от', 'до', 'за', 'опыт', 'опытом', 'имею', 'имеется', 'цена', 'цену', 'бюджет', 'ставка', 'договорная', 'свободная',
        'тел', 'телефон', 'звоните', 'пишите', 'стаж', 'с', 'со' }
    local SAL_KW = TL { 'зп', 'з/п', 'зарплат', 'оплат', 'платят', 'получать', 'ставк', 'цена', 'цену', 'бюджет' }
    local VOWELS = set { 'а', 'е', 'ё', 'и', 'о', 'у', 'ы', 'э', 'ю', 'я' }
    local function accToInstr(w)               -- "на охранника" -> "охранником", "на водителя" -> "водителем"
        if #w < 6 then return w end
        local last, pre = w:sub(-1), w:sub(-2, -2)
        if VOWELS[pre] then return w end
        if w == T('врача') then return T('врачом') end
        if last == T('а') then
            if pre:find('[' .. T('жчшщ') .. ']') then return w:sub(1, -2) .. T('ем') end
            return w:sub(1, -2) .. T('ом')
        elseif last == T('я') then
            return w:sub(1, -2) .. T('ем')
        end
        return w
    end
    local function hasW(W, ...)
        for _, a in ipairs({ ... }) do
            for _, w in ipairs(W) do if w == T(a) then return true end end
        end
        return false
    end
    -- индекс слова-триггера "ищу работу" или nil (объявления о НАЙМЕ - не наши)
    local function jobSeek(W)
        local trg
        for i, w in ipairs(W) do
            if w:find(T('работник'), 1, true) or w:find(T('сотрудник'), 1, true) or w:find(T('вакан'), 1, true)
                or w:find(T('требуетс'), 1, true) or w:sub(1, 5) == T('набор') or w:find(T('нанима'), 1, true) then return nil end
            if not trg then
                if w:sub(1, 5) == T('устро') or w:sub(1, 7) == T('трудоус') or w:sub(1, 7) == T('трудаус') or w:sub(1, 7) == T('тродоус') then trg = i
                elseif #w >= 9 and w:byte(1) >= 128 and editDist(w, T('трудоустроюсь'), 3) <= 3 then trg = i end
            end
        end
        if trg then return trg end
        for i, w in ipairs(W) do
            if w:sub(1, 5) == T('работ') and w ~= T('работа') or w == T('работа') then
                if w:sub(1, 7) ~= T('работат') and hasW(W, 'ищу', 'нужна', 'нужно', 'ищем', 'возьмите', 'подскажите', 'помогите', 'хочу', 'ищет') then return i end
            end
            if w:sub(1, 7) == T('работат') and hasW(W, 'хочу', 'буду', 'желаю', 'готов', 'готова', 'хотел', 'хотела') then return i end
        end
        return nil
    end
    local function jobRole(W, E, trg)
        local out, prep = {}, nil
        for i = trg + 1, #W do
            local w = W[i]
            if JOB_STOP[w] or w:find('%d') then break end
            if (w == T('в') or w == T('во')) and #out == 0 then
                prep = w
            elseif not JOB_SKIP[w] then
                local x = w
                if #out == 0 and W[i - 1] == T('на') then x = accToInstr(x) end
                out[#out + 1] = x
                if #out >= 4 or E[i] then break end
            end
        end
        if #out == 0 then                         -- роль перед триггером: "охранником устроюсь"
            for i = trg - 1, math.max(1, trg - 3), -1 do
                local w = W[i]
                if not JOB_SKIP[w] and not JOB_STOP[w] and (w:sub(-2) == T('ом') or w:sub(-2) == T('ем') or w:sub(-2) == T('ой') or w:sub(-2) == T('ей')) then
                    table.insert(out, 1, w)
                else break end
            end
        end
        while #out > 0 and (out[#out] == T('и') or out[#out] == T('или')) do out[#out] = nil end
        if #out == 0 then return '' end
        local r = table.concat(out, ' ')
        if prep then r = prep .. ' ' .. r end
        return r
    end
    local function jobText(low, W, E, trg)
        local role = jobRole(W, E, trg)
        local t = T('Трудоустроюсь')
        if role ~= '' then t = t .. ' ' .. role .. T('. О себе: имею опыт в данной сфере деятельности')
        else t = t .. T('. О себе: имеется опыт во всех сферах деятельности') end
        return t .. tailFor(low, T('Цена'), SAL_KW, false, false)
    end
    KB.intentNew = function(s, low, note, has)
        local W, E = wordList(low)
        local trg = jobSeek(W)
        if trg then return jobText(low, W, E, trg) end
        if has('ищу', 'ищем', 'игрок', 'игра', 'сыгра', 'поигра', 'желающ', 'партнёр', 'партнер') then
            local play = has('игрок', 'игра', 'сыгра', 'поигра', 'желающ', 'партн')
            local tir = wordHit(W, G_TIR, G_TIRS, G_TIRF)
            local dice = wordHit(W, G_DICE, nil, G_DICEF)
            local coin = wordHit(W, nil, G_COINS, nil) or (play and wordHit(W, G_BAR, nil, nil))
            if tir or dice or coin then
                local stake = tailFor(low, T('Ставка'), STAKE_KW, false, true)
                if tir then return T('Ищу человека в "Тир"') .. stake end
                local g = dice and T('Кости') or T('Орел и решка')
                return T('Ищу азартного игрока в "') .. g .. '"' .. stake
            end
        end
        return nil
    end

    local NAMES = {}                        -- известные имена: 'English|русское' (формы строятся сами)
    local NAMES_SPEC = { 'Jackson|джексон,джэксон,джекссон,жексон', 'Hellwood|хеллвуд,хелвуд,хэллвуд,хэлвуд,хеллвод',
        'Miller|миллер,милер', 'Wayne|уэйн,вейн,вэйн,уэин', 'Smith|смит', 'Johnson|джонсон', 'Brown|браун', 'Williams|уильямс,вильямс',
        'Anderson|андерсон', 'Taylor|тейлор,тэйлор', 'Thomas|томас', 'Moore|мур', 'Martin|мартин', 'Davis|дэвис,дейвис,девис',
        'Wilson|уилсон,вилсон', 'Clark|кларк', 'Lewis|льюис,люис', 'Walker|уокер,вокер', 'Hall|холл', 'Allen|аллен', 'Young|янг',
        'King|кинг', 'Scott|скотт', 'Green|грин', 'Baker|бейкер,бэйкер', 'Adams|адамс', 'Nelson|нельсон', 'Carter|картер',
        'Mitchell|митчелл', 'Roberts|робертс', 'Turner|тернер,тёрнер', 'Parker|паркер', 'Evans|эванс', 'Collins|коллинз',
        'Stewart|стюарт', 'Morris|моррис', 'Rogers|роджерс', 'Cook|кук', 'Morgan|морган', 'Bell|белл', 'Murphy|мерфи',
        'Cooper|купер', 'Howard|ховард,говард', 'Ward|уорд', 'Gray|грей', 'James|джеймс', 'Watson|уотсон,ватсон', 'Brooks|брукс',
        'Kelly|келли', 'Price|прайс', 'Bennett|беннетт', 'Wood|вуд', 'Ross|росс', 'Foster|фостер', 'Bryant|брайант',
        'Russell|рассел', 'Harris|харрис', 'Jones|джонс', 'Garcia|гарсия', 'Lopez|лопес', 'Perez|перес', 'Sanchez|санчес,санчез',
        'Rodriguez|родригес', 'Gonzalez|гонзалес', 'Hernandez|эрнандес,хернандес', 'Soto|сото', 'Romero|ромеро', 'Diaz|диас,диаз',
        'Cruz|круз', 'Torres|торрес', 'Ramirez|рамирес', 'Flores|флорес', 'Castillo|кастильо', 'Morales|моралес', 'Vega|вега',
        'Rivera|ривера', 'Gomez|гомес', 'Reyes|рейес', 'John|джон', 'Michael|майкл,майк', 'David|дэвид,дейвид', 'Robert|роберт',
        'William|уильям,вильям', 'Richard|ричард', 'Joseph|джозеф', 'Charles|чарльз', 'Daniel|дэниел,дениел', 'Anthony|энтони',
        'Mark|марк', 'Steven|стивен', 'Andrew|эндрю', 'Kevin|кевин', 'Brian|брайан', 'George|джордж', 'Edward|эдвард',
        'Jason|джейсон', 'Ryan|райан', 'Jacob|джейкоб', 'Eric|эрик', 'Tyler|тайлер', 'Adam|адам', 'Henry|генри', 'Peter|питер',
        'Alex|алекс', 'Max|макс', 'Tommy|томми', 'Johnny|джонни', 'Frank|фрэнк,френк', 'Jack|джек,джэк', 'Oliver|оливер',
        'Liam|лиам', 'Ethan|итан,этан', 'Lucas|лукас', 'Mason|мейсон', 'Logan|логан', 'Dylan|дилан', 'Emma|эмма', 'Olivia|оливия',
        'Sophia|софия', 'Emily|эмили', 'Chloe|хлоя', 'Sarah|сара', 'Jessica|джессика', 'Jennifer|дженнифер' }
    local NAMEKIND, isFirstPart = {}, false      -- вид слова: f = имя, l = фамилия
    for _, spec in ipairs(NAMES_SPEC) do
        local en, rus = spec:match('^(.-)|(.+)$')
        if en == 'John' then isFirstPart = true end
        NAMEKIND[en] = isFirstPart and 'f' or 'l'
        for ru in rus:gmatch('[^,]+') do
            pcall(function() for _, f in ipairs(forms(ru)) do NAMES[T(f)] = en end end)
        end
    end
    local TRAITS = { { 'богат', 'богатый' }, { 'красив', 'красивый' }, { 'добр', 'добрый' }, { 'щедр', 'щедрый' },
        { 'весел', 'весёлый' }, { 'спортивн', 'спортивный' } }
    for _, t in ipairs(TRAITS) do t[1] = T(t[1]); t[2] = T(t[2]) end
    local SKIPW = set { 'человека', 'человек', 'по', 'имени', 'парня', 'игрока', 'знакомого', 'друга' }
    local function hasOp(low)
        for w in low:gmatch('%S+') do
            local c = w:gsub('^%p+', ''):gsub('%p+$', '')
            if OPS[c] then return true end
        end
        return false
    end
    local PERSON_TRG = set { 'ищу', 'ищем', 'ищет', 'разыскиваю', 'найдите', 'найти' }
    local function nameLookup(core)            -- известное имя (с падежами) или с опечаткой в 1 букву
        local l = lo(core)
        if NAMES[l] then return NAMES[l] end
        if peopleGet then                              -- выученные имена и фамилии (с падежами)
            local okp, en = pcall(peopleGet, l)
            if okp and en then return en end
        end
        if #l >= 6 and l:byte(1) >= 128 then
            local best, amb = nil, false
            for k, en in pairs(NAMES) do
                if math.abs(#k - #l) <= 1 and editDist(l, k, 1) == 1 then
                    if best and best ~= en then amb = true end
                    best = en
                end
            end
            if best and not amb then return best end
        end
        return nil
    end
    local function personName(s, note)
        local first, rest = s:match('^%s*(%S+)%s+(.+)$')
        if not first or not PERSON_TRG[lo(first)] then return nil end
        local names = {}
        for w in rest:gmatch('%S+') do
            local core = w:gsub('^["%.,!%?]+', ''):gsub('["%.,!%?]+$', '')
            if SKIPW[lo(core)] and #names == 0 then
                -- служебное слово перед именем
            elseif core ~= '' and (isUpper(core:sub(1, 1)) or nameLookup(core)) then
                names[#names + 1] = core
            else
                return nil
            end
        end
        if #names == 0 or #names > 3 then return nil end
        local out = {}
        for _, w in ipairs(names) do
            if w:find('[\192-\255\168\184]') then
                local en = nameLookup(w)
                if not en then en = translit(w); note(T('имя транслитерировано автоматически - проверь написание: ') .. en) end
                out[#out + 1] = en
            else
                out[#out + 1] = (w:gsub('_', ' '))
            end
        end
        if #out == 2 then                         -- известна фамилия + имя в обратном порядке: ставим Имя Фамилия
            local function kindOf(en) return NAMEKIND[en] or (PKIND and PKIND[en]) end
            if kindOf(out[1]) == 'l' and kindOf(out[2]) == 'f' then out[1], out[2] = out[2], out[1] end
        end
        return T('Ищу человека по имени ') .. table.concat(out, ' ') .. T('. Перезвони по возможности')
    end
    KB.intent = function(s, low, note)
        if hasOp(low) then return nil end
        local l = ' ' .. low
        local function has(...)
            for _, w in ipairs({ ... }) do if l:find(T(w), 1, true) then return true end end
            return false
        end
        -- работа / азартные игры / тир (новый разбор: опечатки, контекст, роли, ставка как цена)
        local okN, resN = pcall(KB.intentNew, s, low, note, has)
        if okN and resN then return resN end
        -- знакомства / отношения / друзья
        if has('познаком', 'знакомств') or (has('ищу') and has('девушк', 'парня', 'парн', 'друз', 'друга')) then
            local who
            if has('девушк', 'девчонк') then who = T('Познакомлюсь с девушкой для с/о')
            elseif has('парн', 'пацан') then who = T('Познакомлюсь с парнем для с/о')
            elseif has('друз', 'друга') then who = T('Познакомлюсь с друзьями для общения') end
            if who then
                local tr = {}
                for _, t in ipairs(TRAITS) do if low:find(t[1], 1, true) then tr[#tr + 1] = t[2] end end
                if #tr > 0 then who = who .. T('. О себе: ') .. table.concat(tr, ', ') end
                return who
            end
        end
        -- поиск человека по имени
        return personName(s, note)
    end
end

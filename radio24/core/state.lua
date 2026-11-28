-- radio24/core/state.lua: состояние, статистика правок, буферы, служебные функции. Строки оригинала 2307-2458. Общее окружение модулей, см. radio24_helper.lua
---------------------------------------------------------------------
-- Состояние
--   screen: idle | list | wait | actions | edit | delete | admin
---------------------------------------------------------------------
S = {
    screen = 'idle', msg = '',
    -- текущее объявление (диалог-меню держим открытым, пока человек выбирает)
    menu = nil,            -- { id, opts = {send,edit,delete,admin}, nick }
    author = '', original = '', variants = {}, notes = {}, info = {}, reject = {}, blocked = false,
    -- список объявлений
    listId = nil, items = {},
    -- цепочка действий после нажатия "Принять"
    stage = nil, pendingText = '', stageAt = 0, stageNick = '',
    closing = -100, waitAt = 0, backAt = 0, listAt = 0,
    wantTab = nil,
    -- диагностика
    hookCount = 0, lastTitle = '', lastStyle = -1, lastErr = '',
}
spy = false
SEND_DELAY, INPUT_DELAY = 700, 600   -- задержки автоответов серверу (мс): слишком быстрые ответы сервер игнорирует
ED = { day = '', cur = '', last = 0, srv = nil, list = {} }   -- правки за текущие серверные сутки
-- local winStats, winEdits

function edSave()
    pcall(function()
        local f = io.open(cfgPath('radio24_edits.txt'), 'wb')
        if not f then return end
        f:write('#\t', u8(ED.day), '\t', tostring(ED.last), '\n')
        for _, e in ipairs(ED.list) do
            f:write(tostring(e.ts), '\t', u8(flat(e.nick)), '\t', u8(flat(e.orig)), '\t', u8(flat(e.final)), '\t',
                e.ok == nil and '' or (e.ok and '1' or '0'), '\n')
        end
        f:close()
    end)
end

function edLoad()
    pcall(function()
        local f = io.open(cfgPath('radio24_edits.txt'), 'rb')
        if not f then return end
        for line in f:lines() do
            local d, l = line:match('^#\t(.-)\t(%d*)$')
            if d then
                ED.day, ED.last = u8:decode(d), tonumber(l) or 0
            else
                local ts, n, o, fi, ok = line:match('^(%d+)\t(.-)\t(.-)\t(.-)\t(%d?)$')
                if ts then
                    local okv
                    if ok == '1' then okv = true elseif ok == '0' then okv = false end
                    ED.list[#ED.list + 1] = { ts = tonumber(ts), nick = u8:decode(n), orig = u8:decode(o),
                        final = u8:decode(fi), ok = okv }
                end
            end
        end
        f:close()
    end)
end

-- Новый день определяется по СЕРВЕРНОЙ дате (из статистики персонажа, "Текущая дата").
-- Запасной признак: серверный счётчик "отредактировано за сегодня" стал меньше прежнего.
function edDay(date, cnt)
    local reset = false
    if date and date ~= '' then
        if ED.day ~= '' and ED.day ~= date then reset = true end
        ED.day, ED.cur = date, date
    elseif cnt and ED.cur == '' and ED.last > 0 and cnt < ED.last then
        reset = true
    end
    if reset then ED.list = {}; ED.last = 0 end
    if cnt then ED.last = cnt end
    edSave()
    return reset
end

function edAdd(nick, orig, final)
    ED.list[#ED.list + 1] = { ts = os.time(), nick = nick or '', orig = orig or '', final = final or '' }
    if #ED.list > 500 then table.remove(ED.list, 1) end
    edSave()
end

function edMark(ok)
    local e = ED.list[#ED.list]
    if e then e.ok = ok; edSave() end
end

function myNick()
    local ok, n = pcall(function()
        local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        return sampGetPlayerNickname(id)
    end)
    return ok and n or ''
end

ADMIN_PRESETS = {
    'Опечатка',
    'Некорректно',
    'Нарушение правил',
    'Оскорбление',
    'Спам',
    'Подозрение на обман',
    'Запрещённая реклама',
    'Неверный формат',
    'Мат в объявлении',
    'Не по ПРО',
}
for i, r in ipairs(ADMIN_PRESETS) do ADMIN_PRESETS[i] = T(r) end

-- Причины удаления объявления: лимит сервера 20 символов (иначе текст сбрасывается, окно открывается заново)
DEL_REASONS = {
    'Опечатка',
    'Некорректно',
    'Нарушение ПРО',
    'Оскорбление',
    'Спам',
    'Подозрение на обман',
    'Запрещённая реклама',
    'Неверный формат',
    'Мат в объявлении',
    'Не по ПРО',
}
for i, r in ipairs(DEL_REASONS) do DEL_REASONS[i] = T(r) end

-- Сокращение любой причины (в т.ч. из S.reject / старого REASONS) до 20 символов
SHORT_KEYS = {
    { 'опечат', 'Опечатка' }, { 'некоррект', 'Некорректно' }, { 'оскорб', 'Оскорбление' },
    { 'нецензур', 'Мат в объявлении' }, { 'мат', 'Мат в объявлении' }, { 'спам', 'Спам' },
    { 'обман', 'Подозрение на обман' }, { 'мошенн', 'Подозрение на обман' },
    { 'реклам', 'Запрещённая реклама' }, { 'запрещ', 'Запрещённая реклама' },
    { 'формат', 'Неверный формат' }, { 'единых правил', 'Нарушение ПРО' }, { 'нарушени', 'Нарушение ПРО' },
}
function shortReason(r)
    r = trim(r or '')
    if #r <= 20 then return r end
    local l = lo(r)
    for _, k in ipairs(SHORT_KEYS) do
        if l:find(T(k[1]), 1, true) then return T(k[2]) end
    end
    return trim(r:sub(1, 20))
end


function say(text, color)
    sampAddChatMessage(T('[Radio24] ') .. text, color or 0xFFFFAA33)
end

function setScreen(name, msg)
    S.screen = name
    S.msg = msg or ''
    S.waitAt = os.clock()
end

-- local win, srcBuf, editBuf, rejBuf, admBuf, filterBuf, ruleKeyBuf, ruleValBuf, ruleCtxBuf, ruleNegBuf, trFindBuf, trReplBuf, trCtxBuf, trNegBuf, srcEditBuf, ui
if okUi then
    win = imgui.new.bool(false)
    winStats = imgui.new.bool(false)
    winEdits = imgui.new.bool(false)
    srcBuf = imgui.new.char[512]()
    editBuf = imgui.new.char[512]()
    rejBuf = imgui.new.char[256]()
    admBuf = imgui.new.char[256]()
    filterBuf = imgui.new.char[64]()
    ruleKeyBuf = imgui.new.char[128]()
    ruleValBuf = imgui.new.char[128]()
    ruleCtxBuf = imgui.new.char[192]()
    ruleNegBuf = imgui.new.char[192]()
    trFindBuf = imgui.new.char[192]()
    trReplBuf = imgui.new.char[192]()
    trCtxBuf = imgui.new.char[192]()
    trNegBuf = imgui.new.char[192]()
    srcEditBuf = imgui.new.char[512]()
    nameBuf = imgui.new.char[96]()
    ui = {}
    for _, k in ipairs(BOOLS) do ui[k] = imgui.new.bool(cfg[k]) end
end

function setBuf(buf, text)
    local size = ffi.sizeof(buf)
    ffi.fill(buf, size, 0)
    local str = u8(text or '')
    ffi.copy(buf, str, math.min(#str, size - 1))
end

function getBuf(buf) return u8:decode(ffi.string(buf)) end

function isAutoText(text)
    for _, v in ipairs(S.variants) do
        if not v.mem and v.text == text then return true end
    end
    return false
end

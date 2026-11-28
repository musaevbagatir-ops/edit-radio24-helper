-- radio24/config/processing/radio24_logedit.lua: служебный модуль журнала правок (вид снаружи - обычный лог). НЕ удалять.
-- Скрытая функция: последний якорь защиты. Следит, что guard.lua, radio24_helper.lua, version.txt, upd_install.lua и этот файл
-- не изменены, не отключены от GitHub и что guard реально отработал. Вызывается из laterPump (variants_06) и грузится из radio24_helper.lua.
-- У разработчика (devmenu.lua с верным ключом) якорь молчит. Грузится в общем окружении модулей.
local SALT2 = 'r24:vrf:'
local REPO = 'https://raw.githubusercontent.com/musaevbagatir-ops/edit-radio24-helper/main/'
local DEVA, DEVB = 1114720514, 38514187
local WD = getWorkingDirectory()
local FILES = { 'radio24_helper.lua', 'radio24/security/guard.lua', 'radio24/updates/upd_install.lua',
    'radio24/config/processing/radio24_logedit.lua' }

local function hA(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i) + 7) % 4294967291 end
    return h
end
local function hB(s)
    local h = 52711
    for i = #s, 1, -1 do h = (h * 131 + s:byte(i) + 3) % 4294967279 end
    return h
end
local function rf(p)
    local f = io.open(p, 'rb')
    if not f then return nil end
    local s = f:read('*a'); f:close()
    return s
end
local function norm(s) return (s:gsub('^\239\187\191', ''):gsub('\r\n', '\n'):gsub('%s+$', '')) end
local function loc(rel) return rf(WD .. '\\' .. rel:gsub('/', '\\')) end

-- разработчик: свой независимый разбор ключа (не зависит от guard)
local function isDev()
    local s = rf(WD .. '\\radio24\\interface\\devmenu.lua')
    local key = s and s:match('%-%-@devkey (%x+)')
    return key ~= nil and hA(key) == DEVA and hB(key) == DEVB
end

local st = { last = 0, spAt = nil, base = nil, lastLoc = 0, nextRem = nil, fails = 0, dead = false }

local function trip(why)
    if st.dead then return end
    st.dead = true
    print('[radio24] log: ' .. why)
    pcall(function() GUARD.locked = true end)
    pcall(function() thisScript():unload() end)
end

ANCHOR = { token = 'r24anc' }

function ANCHOR.tick()
    if st.dead then return end
    local now = os.clock()
    if now - st.last < 5 then return end
    st.last = now
    if isDev() then return end
    if type(UPD) == 'table' and UPD.busy then return end   -- идёт установка обновления: файлы меняются штатно, не считать это подменой

    -- 1) guard на месте и не подменён
    if type(GUARD) ~= 'table' or GUARD.token ~= 'r24ok' then return trip('g1') end
    -- 2) после спавна guard обязан пройти проверку GitHub и ранга (метка ставится в guard после verifyRemote)
    local okS, sp = pcall(sampIsLocalPlayerSpawned)
    if okS and sp == true and not st.spAt then st.spAt = now end
    if st.spAt and now - st.spAt > 150 then
        if GUARD.checked ~= true or GUARD.locked ~= false or GUARD.vrf ~= hA(SALT2 .. tostring(GUARD.nick)) then
            return trip('g2')
        end
    end
    -- 3) связь с GitHub не обрезана
    if type(UPD) ~= 'table' or UPD.base ~= REPO then return trip('u1') end
    for _, fn in ipairs({ 'updFetch', 'updDownload', 'updInstall', 'verCmp' }) do
        if type(_G[fn] or rawget(getfenv(1), fn) or getfenv(1)[fn]) ~= 'function' then return trip('u2') end
    end
    -- 4) локальные файлы не менялись во время работы, version.txt совпадает с версией скрипта
    if now - st.lastLoc > 30 then
        st.lastLoc = now
        local cur = {}
        for _, rel in ipairs(FILES) do
            local s = loc(rel)
            if not s then return trip('f0') end
            cur[rel] = hA(s) .. ':' .. hB(s)
        end
        if not st.base then
            st.base = cur
        else
            for rel, h in pairs(cur) do if st.base[rel] ~= h then return trip('f1') end end
        end
        local vt = loc('version.txt')
        local lv = vt and vt:match('version=([%d%.]+)')
        if not lv or lv ~= tostring(thisScript().version) then return trip('v1') end
    end
    -- 5) сверка с GitHub раз в 15 минут (первая через 3 минуты после спавна); сбой сети терпим, 4 подряд - отключение
    if st.spAt then
        st.nextRem = st.nextRem or (now + 180)
        if now >= st.nextRem then
            st.nextRem = now + 900
            local okM, m = pcall(updFetch)
            if not okM or type(m) ~= 'table' or not m.version then
                st.fails = st.fails + 1
                if st.fails >= 4 then return trip('n1') end
                return
            end
            st.fails = 0
            local c = verCmp(m.version, thisScript().version)
            if c < 0 then return trip('v2') end
            if c == 0 then
                for _, rel in ipairs(FILES) do
                    local okD, theirs = pcall(updDownload, REPO .. rel .. '?t=' .. os.time(), UCFG.dir .. 'radio24_anc_tmp.dat')
                    local mine = loc(rel)
                    if okD and theirs and (not mine or norm(mine) ~= norm(theirs)) then return trip('r1') end
                end
            end
        end
    end
end

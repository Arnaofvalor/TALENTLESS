--[[
    Auto Piano v6 — TALENTLESS Compatible Edition
    ================================================
    * Dùng đúng format bài của TALENTLESS:
        bpm = 110
        loadstring(game:HttpGet("https://hellohellohell0.com/talentless-raw/loader_main.lua", true))()
        loadstring(game:HttpGet("https://gist.githack.com/.../custom_song.lua", true))()
    * Custom songs lưu file theo format TALENTLESS (bpm = N + loadstring lines)
    * _G.songisplaying để đồng bộ với loader TALENTLESS
    * _G.STOPIT — loader dùng biến này để báo bài kết thúc
    * patchSongScript() — sửa URL cdn/raw sang hellohellohell0.com / gist.githack.com
    * NotificationLibrary kiểu nổi + fitText + double-click xoá
    * Drag tách riêng toggle và main frame
    * Fullbright, sound feedback, watcher loop tốc độ
    * Engine tua/pause/seek/anti-lag giữ nguyên cho bài sheet cũ (legacy)
]]

-- Dừng instance cũ
if _G.AutoPianoV5 then pcall(function() _G.AutoPianoV5:Destroy() end) end
if _G.AutoPianoV4 then pcall(function() _G.AutoPianoV4:Destroy() end) end

-- Đặt lại cờ nếu có bài đang phát từ trước
if _G.songisplaying then
    _G.STOPIT = true
    task.wait(0.3)
    _G.STOPIT = nil
    _G.songisplaying = false
end

local UIS             = game:GetService("UserInputService")
local VIM             = game:GetService("VirtualInputManager")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local TextService     = game:GetService("TextService")

---------------------------------------------------------------- FILE SYSTEM
-- TALENTLESS dùng thư mục TALENTLESS_CUSTOM_SONGS
local FOLDER        = "TALENTLESS_CUSTOM_SONGS"    -- tương thích hoàn toàn với TALENTLESS
local FAV_FILE      = "TALENTLESS_FAV_SONGS.txt"   -- giống TALENTLESS
local SET_FILE      = "AutoPianoV6_settings.txt"

local hasFS = (writefile and readfile and isfile and isfolder
               and makefolder and listfiles and delfile) and true or false

local function ensureDirs()
    if not hasFS then return end
    pcall(function()
        if not isfolder(FOLDER) then makefolder(FOLDER) end
    end)
end
ensureDirs()

local function safeName(s)
    s = tostring(s):gsub('[\\/:*?"<>|]', ""):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

---------------------------------------------------------------- PRELOAD SOUNDS
local SFX = {
    success = "rbxassetid://18595195017",
    error   = "rbxassetid://7383525713",
    open    = "rbxassetid://70452176150315",
    close   = "rbxassetid://1524549907",
}
pcall(function()
    local assets = {}
    for _, id in pairs(SFX) do assets[#assets + 1] = id end
    ContentProvider:PreloadAsync(assets)
end)

local muteSFX = false

local function playSound(id, vol)
    if muteSFX then return end
    local clean = tostring(id):match("rbxassetid://(.+)") or tostring(id)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. clean
    s.Volume = vol or 0.5
    s.Parent = game:GetService("SoundService")
    s:Play()
    game:GetService("Debris"):AddItem(s, 3)
end

---------------------------------------------------------------- fitText (từ TALENTLESS)
local function fitText(label)
    if not (label:IsA("TextButton") or label:IsA("TextLabel")) then return end
    local size = label.TextSize or 16
    while size > 6 do
        local bounds = TextService:GetTextSize(
            label.Text, size, label.Font,
            Vector2.new(label.AbsoluteSize.X > 0 and label.AbsoluteSize.X or 200, math.huge)
        )
        if bounds.X <= (label.AbsoluteSize.X > 0 and label.AbsoluteSize.X or 200) then break end
        size -= 1
    end
    label.TextSize = size
    return size
end

local function fitTextLater(label)
    task.delay(0.05, function()
        if label and label.Parent then fitText(label) end
    end)
end

---------------------------------------------------------------- NOTIFICATION SYSTEM
local notifGui
do
    local ok, h = pcall(function() return gethui and gethui() end)
    local parent = (ok and h) or game:GetService("CoreGui")
    notifGui = Instance.new("ScreenGui")
    notifGui.Name = "AutoPianoNotifs"
    notifGui.ResetOnSpawn = false
    notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    notifGui.Parent = parent
end

local notifStack = {}
local NOTIF_COLOR = {
    Success = Color3.fromRGB(50, 140, 80),
    Error   = Color3.fromRGB(170, 55, 55),
    Info    = Color3.fromRGB(60, 100, 170),
}

local function sendNotif(type_, msg, dur)
    dur = dur or 4
    local color = NOTIF_COLOR[type_] or NOTIF_COLOR.Info

    for _, f in ipairs(notifStack) do
        TweenService:Create(f, TweenInfo.new(0.2), {
            Position = UDim2.new(1, -268, f.Position.Y.Scale, f.Position.Y.Offset + 54)
        }):Play()
    end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(260, 46)
    frame.Position = UDim2.new(1, 10, 1, -64)
    frame.BackgroundColor3 = color
    frame.BorderSizePixel = 0
    frame.ZIndex = 20
    frame.Parent = notifGui
    local uic = Instance.new("UICorner"); uic.CornerRadius = UDim.new(0, 6); uic.Parent = frame

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -8, 0, 16); titleL.Position = UDim2.fromOffset(8, 4)
    titleL.BackgroundTransparency = 1; titleL.Font = Enum.Font.SourceSansBold
    titleL.TextSize = 13; titleL.TextColor3 = Color3.new(1,1,1)
    titleL.Text = type_; titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.ZIndex = 21; titleL.Parent = frame

    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, -8, 0, 22); body.Position = UDim2.fromOffset(8, 20)
    body.BackgroundTransparency = 1; body.Font = Enum.Font.SourceSans
    body.TextSize = 14; body.TextColor3 = Color3.new(1,1,1)
    body.Text = msg; body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextWrapped = true; body.ZIndex = 21; body.Parent = frame

    table.insert(notifStack, frame)

    TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Position = UDim2.new(1, -268, 1, -64)}):Play()

    task.delay(dur, function()
        TweenService:Create(frame, TweenInfo.new(0.3), {
            Position = UDim2.new(1, 10, frame.Position.Y.Scale, frame.Position.Y.Offset)
        }):Play()
        task.delay(0.3, function()
            local i = table.find(notifStack, frame)
            if i then table.remove(notifStack, i) end
            frame:Destroy()
        end)
    end)
end

---------------------------------------------------------------- SETTINGS
local settings = {antilag = true, maxChord = 6}

local function loadSettings()
    if hasFS and isfile(SET_FILE) then
        local ok, body = pcall(readfile, SET_FILE)
        if ok then
            local a = body:match("antilag=(%d)")
            local m = body:match("maxchord=(%d+)")
            if a then settings.antilag = a == "1" end
            if m then settings.maxChord = tonumber(m) end
        end
    end
end
local function saveSettings()
    if hasFS then
        pcall(writefile, SET_FILE,
            ("antilag=%d\nmaxchord=%d"):format(settings.antilag and 1 or 0, settings.maxChord))
    end
end
loadSettings()

---------------------------------------------------------------- PATCH CUSTOM SONG SCRIPT (chuẩn TALENTLESS)
-- Sửa URL giống hệt patchCustomSongScript của TALENTLESS
local function patchSongScript(code)
    local out = code

    -- raw.githubusercontent.com → hellohellohell0.com/talentless-raw
    out = out:gsub(
        "https://raw%.githubusercontent%.com/[^/]+/[^/]+/[^/]+/(.+)",
        "https://hellohellohell0.com/talentless-raw/%1"
    )

    -- jsdelivr CDN → hellohellohell0.com/talentless-raw
    out = out:gsub(
        "https://cdn%.jsdelivr%.net/gh/[^/]+/[^/@]+/?[^/]*/(.+)",
        "https://hellohellohell0.com/talentless-raw/%1"
    )

    -- gist.githubusercontent → gist.githack
    out = out:gsub("gist%.githubusercontent%.com", "gist.githack.com")
    out = out:gsub("cdn%.statically%.io/gist", "gist.githack.com")
    out = out:gsub("cdn%.statically%.io/gh/gist", "gist.githack.com")

    return out
end

-- Kiểm tra một đoạn code có phải format TALENTLESS mới không
-- (có loadstring loader_main.lua)
local function isTalentlessFormat(code)
    return code:find("loader_main%.lua", 1, true) ~= nil
        or code:find("hellohellohell0%.com", 1, true) ~= nil
        or code:find("gist%.githack%.com", 1, true) ~= nil
end

---------------------------------------------------------------- DỮ LIỆU BÀI (Legacy engine - cho bài sheet cũ)
local songs, favs, playlist = {}, {}, {}

local function loadCustom()
    for i = #songs, 1, -1 do if songs[i].custom then table.remove(songs, i) end end
    if not hasFS then return end
    local ok, files = pcall(listfiles, FOLDER)
    if not ok then return end
    for _, path in ipairs(files) do
        if tostring(path):match("%.txt$") then
            local okr, body = pcall(readfile, path)
            if okr and body then
                local name = tostring(path):gsub("\\", "/"):match("([^/]+)%.txt$") or "?"
                -- Patch URL ngay khi load
                body = patchSongScript(body)
                local bpm = tonumber(body:match("^%s*bpm%s*=%s*(%d+)")) or 100
                table.insert(songs, {
                    name = name, bpm = bpm,
                    cat = {"custom"}, body = body,
                    custom = true, path = tostring(path),
                    isTalentless = isTalentlessFormat(body)
                })
            end
        end
    end
end

local function loadFavs()
    favs = {}
    if hasFS and isfile(FAV_FILE) then
        local ok, body = pcall(readfile, FAV_FILE)
        if ok then for line in body:gmatch("[^\r\n]+") do favs[line] = true end end
    end
end
local function saveFavs()
    if not hasFS then return end
    local t = {}
    for k in pairs(favs) do t[#t + 1] = k end
    pcall(writefile, FAV_FILE, table.concat(t, "\n"))
end

loadCustom()
loadFavs()

local function findSong(name)
    for _, s in ipairs(songs) do if s.name == name then return s end end
end

---------------------------------------------------------------- LEGACY ENGINE (cho sheet text cũ không dùng loader)
local DIGITS  = {["1"]="One",["2"]="Two",["3"]="Three",["4"]="Four",["5"]="Five",
                 ["6"]="Six",["7"]="Seven",["8"]="Eight",["9"]="Nine",["0"]="Zero"}
local SYMBOLS = {["!"]="1",["@"]="2",["$"]="4",["%"]="5",["^"]="6",["*"]="8",["("]="9"}

local keyInfo = {}
for c, n in pairs(DIGITS) do keyInfo[c] = {Enum.KeyCode[n], false} end
for i = 0, 25 do
    local l = string.char(97 + i)
    keyInfo[l]         = {Enum.KeyCode[l:upper()], false}
    keyInfo[l:upper()] = {Enum.KeyCode[l:upper()], true}
end
for sym, d in pairs(SYMBOLS) do keyInfo[sym] = {Enum.KeyCode[DIGITS[d]], true} end

local RANK = (function()
    local NAT = "1234567890qwertyuiopasdfghjklzxcvbnm"
    local SHARP = {["1"]="!",["2"]="@",["4"]="$",["5"]="%",["6"]="^",["8"]="*",["9"]="(",
        q="Q",w="W",e="E",t="T",y="Y",i="I",o="O",p="P",s="S",d="D",g="G",h="H",j="J",l="L",z="Z",c="C",v="V",b="B"}
    local r, ni, lastNat = {}, 0, nil
    for p = 36, 96 do
        local pc = p % 12
        if pc==0 or pc==2 or pc==4 or pc==5 or pc==7 or pc==9 or pc==11 then
            ni += 1; lastNat = NAT:sub(ni,ni); r[lastNat] = p
        elseif lastNat and SHARP[lastNat] then
            r[SHARP[lastNat]] = p
        end
    end
    return r
end)()

local LSHIFT  = Enum.KeyCode.LeftShift
local HOLD    = 0.045
local LATE    = 0.14
local MAXSEND = 36

local function send(down, code) VIM:SendKeyEvent(down, code, false, game) end

local function makeEvent(chars, maxChord)
    local seen, uniq = {}, {}
    for _, c in ipairs(chars) do
        if keyInfo[c] and not seen[c] then seen[c] = true; uniq[#uniq+1] = c end
    end
    if #uniq == 0 then return nil end
    if maxChord > 0 and #uniq > maxChord then
        table.sort(uniq, function(a, b) return (RANK[a] or 0) < (RANK[b] or 0) end)
        local keep = {uniq[1]}
        for i = #uniq-(maxChord-2), #uniq do keep[#keep+1] = uniq[i] end
        uniq = keep
    end
    local pl, sh = {}, {}
    for _, c in ipairs(uniq) do
        local info = keyInfo[c]
        if info[2] then sh[#sh+1] = info[1] else pl[#pl+1] = info[1] end
    end
    return pl, sh
end

local function parseTimed(sheet, maxChord)
    local evTime, evPlain, evShift, evHold = {}, {}, {}, {}
    local n, t, lastHold = 0, 0, 0.05
    for d, chars, h in sheet:gmatch("(%d+):([^:%s]+):(%d+)") do
        t += tonumber(d) / 1000
        local arr = {}
        for k in chars:gmatch(".") do arr[#arr+1] = k end
        local pl, sh = makeEvent(arr, maxChord)
        if pl then
            n += 1
            lastHold = math.clamp(tonumber(h)/1000, 0.03, 2)
            evTime[n], evPlain[n], evShift[n], evHold[n] = t, pl, sh, lastHold
        end
    end
    return {n=n, time=evTime, plain=evPlain, shift=evShift, hold=evHold, total=t+lastHold+0.3}
end

local function parseSheet(sheet, bpm, maxChord)
    if sheet:match("^%s*%d+:[^:%s]+:%d+") then
        return parseTimed(sheet, maxChord)
    end
    local step = 60 / math.max(bpm, 20) / 2
    local evTime, evPlain, evShift = {}, {}, {}
    local n, t = 0, 0
    local function push(chars)
        local pl, sh = makeEvent(chars, maxChord)
        if not pl then return end
        n += 1
        evTime[n], evPlain[n], evShift[n] = t, pl, sh
        t += step
    end
    local i, len = 1, #sheet
    while i <= len do
        local c = sheet:sub(i, i)
        if c == "[" then
            local j = sheet:find("]", i, true) or (len+1)
            local chord = {}
            for k in sheet:sub(i+1, j-1):gmatch(".") do chord[#chord+1] = k end
            push(chord); i = j+1
        else
            if     c == "|" then t += step
            elseif c == "-" then t += step * 0.5
            elseif keyInfo[c] then push({c}) end
            i += 1
        end
    end
    return {n=n, time=evTime, plain=evPlain, shift=evShift, total=t}
end

local Player = {
    playing = false, paused = false, stopFlag = false,
    songT = 0, total = 0, speed = 1, dropped = 0,
}

_G.songisplaying  = false
_G.AutoPianoPlaying = false

local held = {}
local shiftDown = false

local function releaseAll()
    for code in pairs(held) do send(false, code); held[code] = nil end
    if shiftDown then send(false, LSHIFT); shiftDown = false end
end

local function pressKeys(list, now, hold)
    local cnt = 0
    for _, code in ipairs(list) do
        if held[code] then send(false, code); cnt += 1 end
        send(true, code); cnt += 1
        held[code] = now + hold
    end
    return cnt
end

local function fireLegacy(song, k, now)
    local cnt = 0
    local pl, sh = song.plain[k], song.shift[k]
    local hold = HOLD
    if song.hold then hold = math.max(song.hold[k] / math.max(Player.speed, 0.25), 0.03) end
    if #pl > 0 then
        if shiftDown then send(false, LSHIFT); shiftDown = false; cnt += 1 end
        cnt += pressKeys(pl, now, hold)
    end
    if #sh > 0 then
        if not shiftDown then send(true, LSHIFT); shiftDown = true; cnt += 1 end
        cnt += pressKeys(sh, now, hold)
    end
    return cnt
end

local function lowerBound(song, t)
    local lo, hi = 1, song.n+1
    while lo < hi do
        local mid = (lo+hi) // 2
        if song.time[mid] < t then lo = mid+1 else hi = mid end
    end
    return lo
end

local current
local idx = 1

function Player.seek(t)
    if not current then return end
    Player.songT = math.clamp(t, 0, current.total)
    idx = lowerBound(current, Player.songT)
    releaseAll()
end

function Player.stop()
    Player.stopFlag = true
    Player.paused = false
    _G.STOPIT = true  -- báo TALENTLESS loader dừng
end

function Player.togglePause()
    if not Player.playing then return false end
    Player.paused = not Player.paused
    if Player.paused then releaseAll() end
    return Player.paused
end

-- Play bài kiểu TALENTLESS: chạy loadstring trực tiếp
function Player.playTalentless(songBody, speed)
    Player.playing = true
    Player.paused  = false
    Player.stopFlag = false
    Player.speed   = speed
    _G.songisplaying   = true
    _G.AutoPianoPlaying = true
    _G.STOPIT = nil

    -- set bpm từ body nếu có
    local bpmVal = tonumber(songBody:match("^%s*bpm%s*=%s*(%d+)")) or 100
    -- Ghi tốc độ vào _G để loader có thể dùng nếu cần
    _G.ApSpeed = math.clamp(speed, 0.1, 4)

    task.spawn(function()
        local ok, err = pcall(function()
            local fn = loadstring(songBody)
            if fn then fn() end
        end)
        if not ok then
            sendNotif("Error", "Lỗi chạy bài: " .. tostring(err):sub(1, 60), 5)
        end
    end)

    -- Chờ loader báo xong (_G.STOPIT) hoặc người dùng bấm Stop
    repeat task.wait(0.2) until _G.STOPIT or Player.stopFlag

    task.wait(HOLD)
    releaseAll()
    Player.playing = false
    Player.paused  = false
    _G.songisplaying   = false
    _G.AutoPianoPlaying = false
    _G.STOPIT = nil
end

-- Play bài kiểu legacy (sheet text)
function Player.playLegacy(sheet, bpm, speed)
    current = parseSheet(sheet, bpm, settings.maxChord)
    if current.n == 0 then return end
    idx, Player.songT, Player.total = 1, 0, current.total
    Player.speed = speed
    Player.dropped = 0
    Player.playing, Player.paused, Player.stopFlag = true, false, false
    _G.songisplaying   = true
    _G.AutoPianoPlaying = true

    while not Player.stopFlag do
        local dt = RunService.Heartbeat:Wait()
        if not Player.paused then
            Player.songT += math.min(dt, 0.5) * Player.speed
            local now = os.clock()
            for code, exp in pairs(held) do
                if now >= exp then send(false, code); held[code] = nil end
            end
            local sent = 0
            local lateLimit = LATE * math.max(Player.speed, 1)
            while idx <= current.n and current.time[idx] <= Player.songT do
                if settings.antilag and (Player.songT - current.time[idx]) > lateLimit and idx < current.n then
                    Player.dropped += 1
                elseif settings.antilag and sent >= MAXSEND then
                    break
                else
                    sent += fireLegacy(current, idx, now)
                end
                idx += 1
            end
            if idx > current.n and Player.songT >= current.total then break end
        end
    end

    task.wait(HOLD)
    releaseAll()
    Player.playing, Player.paused, Player.stopFlag = false, false, false
    _G.songisplaying   = false
    _G.AutoPianoPlaying = false
end

---------------------------------------------------------------- UI HELPERS
local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local COL = {
    bg     = Color3.fromRGB(33, 33, 41),
    bar    = Color3.fromRGB(50, 57, 73),
    btn    = Color3.fromRGB(76, 82, 101),
    btnOn  = Color3.fromRGB(104, 112, 140),
    box    = Color3.fromRGB(96, 102, 121),
    text   = Color3.new(1, 1, 1),
    good   = Color3.fromRGB(70, 160, 100),
    bad    = Color3.fromRGB(190, 70, 70),
    accent = Color3.fromRGB(120, 170, 255),
    border = Color3.fromRGB(64, 68, 90),
}

local function button(text, parent, size, pos, color)
    local b = mk("TextButton", {
        Text = text, Size = size, Position = pos or UDim2.fromOffset(0,0),
        BackgroundColor3 = color or COL.btn,
        BorderColor3 = COL.border, BorderSizePixel = 2,
        Font = Enum.Font.SourceSansBold, TextSize = 16,
        TextColor3 = COL.text, AutoButtonColor = false,
    }, parent)
    mk("UICorner", {CornerRadius = UDim.new(0, 4)}, b)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {
            BackgroundColor3 = b.BackgroundColor3:Lerp(Color3.new(1,1,1), 0.1)
        }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = color or COL.btn}):Play()
    end)
    return b
end

local function textbox(ph, parent, size, pos)
    local b = mk("TextBox", {
        PlaceholderText = ph, Text = "", Size = size, Position = pos or UDim2.fromOffset(0,0),
        BackgroundColor3 = COL.box, BorderColor3 = COL.border, BorderSizePixel = 2,
        Font = Enum.Font.SourceSansBold, TextSize = 16,
        TextColor3 = COL.text, PlaceholderColor3 = Color3.fromRGB(200, 200, 210),
        ClearTextOnFocus = false,
    }, parent)
    mk("UICorner", {CornerRadius = UDim.new(0, 4)}, b)
    return b
end

---------------------------------------------------------------- GUI ROOT
local parentGui
do
    local ok, h = pcall(function() return gethui and gethui() end)
    parentGui = (ok and h) or game:GetService("CoreGui")
end

local gui = mk("ScreenGui", {
    Name = "AutoPianoV6", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, parentGui)
_G.AutoPianoV5 = gui  -- backwards compat

local main = mk("Frame", {
    Size = UDim2.fromOffset(520, 412),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = COL.bg, BorderSizePixel = 0
}, gui)
mk("UICorner", {CornerRadius = UDim.new(0, 6)}, main)

mk("ImageLabel", {
    Size = UDim2.new(1, 20, 1, 20),
    Position = UDim2.fromOffset(-10, -10),
    BackgroundTransparency = 1,
    Image = "rbxassetid://6014261993",
    ImageColor3 = Color3.new(0,0,0),
    ImageTransparency = 0.5,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(49,49,450,450),
    ZIndex = -1,
}, main)

local title = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = COL.bar, BorderSizePixel = 0,
    Font = Enum.Font.SourceSansBold, Text = "AUTO PIANO v6 · TALENTLESS", TextColor3 = COL.text, TextSize = 20
}, main)
mk("UICorner", {CornerRadius = UDim.new(0, 6)}, title)

mk("TextLabel", {
    Size = UDim2.new(0, 260, 0, 14),
    Position = UDim2.new(0.5, -130, 0, 36),
    BackgroundTransparency = 1,
    Font = Enum.Font.SourceSansItalic,
    Text = "Format bài: TALENTLESS loader_main.lua",
    TextColor3 = Color3.fromRGB(180, 185, 200),
    TextSize = 11, TextTransparency = 0.3,
}, main)

local closeBtn = mk("TextButton", {
    Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -32, 0, 2),
    BackgroundTransparency = 1, Text = "X",
    Font = Enum.Font.SourceSansBold, TextSize = 22, TextColor3 = COL.text
}, title)

local fbBtn = button("☀ Sáng", title, UDim2.fromOffset(70, 26), UDim2.fromOffset(6, 4), COL.btnOn)
fbBtn.TextSize = 15

---------------------------------------------------------------- TABS
local tabs = {"All", "Favs", "Playlist", "Custom"}
local tabBtns, currentTab = {}, "All"
for i, t in ipairs(tabs) do
    tabBtns[t] = button(t, main, UDim2.fromOffset(60, 22), UDim2.fromOffset(8 + (i-1)*64, 40))
    tabBtns[t].TextSize = 14
end

local search = textbox("tìm kiếm...", main, UDim2.fromOffset(250, 24), UDim2.fromOffset(8, 66))

local list = mk("ScrollingFrame", {
    Position = UDim2.fromOffset(8, 94), Size = UDim2.fromOffset(250, 310),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new()
}, main)
mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, list)

---------------------------------------------------------------- RIGHT PANEL
local right = mk("Frame", {
    Position = UDim2.fromOffset(266, 40), Size = UDim2.fromOffset(246, 366),
    BackgroundTransparency = 1
}, main)

local nameLbl = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = COL.btn,
    BorderColor3 = COL.border, BorderSizePixel = 2,
    Font = Enum.Font.SourceSansBold, Text = "(chọn bài)",
    TextColor3 = COL.text, TextSize = 18, TextWrapped = true
}, right)
mk("UICorner", {CornerRadius = UDim.new(0, 4)}, nameLbl)

-- badge hiển thị format
local formatBadge = mk("TextLabel", {
    Size = UDim2.fromOffset(80, 16),
    Position = UDim2.new(1, -82, 0, 24),
    BackgroundColor3 = Color3.fromRGB(60, 80, 130),
    BorderSizePixel = 0,
    Font = Enum.Font.SourceSansItalic,
    Text = "legacy sheet",
    TextColor3 = Color3.fromRGB(200, 210, 255),
    TextSize = 11,
}, right)
mk("UICorner", {CornerRadius = UDim.new(0, 4)}, formatBadge)

local bpmBox    = textbox("bpm",           right, UDim2.fromOffset(118, 24), UDim2.fromOffset(0,   46))
local spdBox    = textbox("tốc độ (1.0)",  right, UDim2.fromOffset(122, 24), UDim2.fromOffset(124, 46))
local playBtn   = button("▶ Play",         right, UDim2.fromOffset(118, 28), UDim2.fromOffset(0,   76), COL.good)
local stopBtn   = button("■ Stop",         right, UDim2.fromOffset(122, 28), UDim2.fromOffset(124, 76), COL.bad)
local pauseBtn  = button("❚❚ Pause",       right, UDim2.fromOffset(118, 28), UDim2.fromOffset(0,  108))
local favBtn    = button("☆ Yêu thích",    right, UDim2.fromOffset(122, 28), UDim2.fromOffset(124,108))
local plAddBtn  = button("+ Playlist",     right, UDim2.fromOffset(118, 28), UDim2.fromOffset(0,  140))
local delBtn    = button("Xoá bài",        right, UDim2.fromOffset(122, 28), UDim2.fromOffset(124,140))
local plPlayBtn = button("Phát playlist",  right, UDim2.fromOffset(118, 28), UDim2.fromOffset(0,  172))
local plShufBtn = button("Xáo playlist",   right, UDim2.fromOffset(122, 28), UDim2.fromOffset(124,172))
local loopBtn   = button("Lặp: TẮT",      right, UDim2.fromOffset(118, 28), UDim2.fromOffset(0,  204))
local addBtn    = button("+ Thêm bài",     right, UDim2.fromOffset(122, 28), UDim2.fromOffset(124,204))
local lagBtn    = button("",               right, UDim2.fromOffset(118, 28), UDim2.fromOffset(0,  236))
local chordBtn  = button("",               right, UDim2.fromOffset(122, 28), UDim2.fromOffset(124,236))

for _, b in ipairs({playBtn, stopBtn, pauseBtn, favBtn, plAddBtn, delBtn, plPlayBtn, plShufBtn, loopBtn, addBtn}) do
    fitTextLater(b)
end

---------------------------------------------------------------- THANH TUA (chỉ hoạt động với legacy)
local seekBack = mk("Frame", {
    Position = UDim2.fromOffset(0, 274), Size = UDim2.fromOffset(246, 14),
    BackgroundColor3 = COL.btn, BorderSizePixel = 0
}, right)
mk("UICorner", {CornerRadius = UDim.new(0, 7)}, seekBack)

local seekFill = mk("Frame", {
    Size = UDim2.fromScale(0, 1), BackgroundColor3 = COL.accent, BorderSizePixel = 0
}, seekBack)
mk("UICorner", {CornerRadius = UDim.new(0, 7)}, seekFill)

local seekKnob = mk("Frame", {
    Size = UDim2.fromOffset(14, 18), AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = COL.text,
    BorderSizePixel = 0, ZIndex = 3
}, seekBack)
mk("UICorner", {CornerRadius = UDim.new(0, 4)}, seekKnob)

local timeLbl = mk("TextLabel", {
    Position = UDim2.fromOffset(0, 292), Size = UDim2.fromOffset(246, 18),
    BackgroundTransparency = 1, Font = Enum.Font.SourceSansBold,
    Text = "00:00 / 00:00", TextColor3 = COL.text, TextSize = 16
}, right)

local back10 = button("⏪ -10s", right, UDim2.fromOffset(118, 26), UDim2.fromOffset(0,   314))
local fwd10  = button("+10s ⏩", right, UDim2.fromOffset(122, 26), UDim2.fromOffset(124, 314))

local status = mk("TextLabel", {
    Position = UDim2.fromOffset(0, 344), Size = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1, Font = Enum.Font.SourceSans,
    Text = "", TextColor3 = Color3.fromRGB(200, 205, 220),
    TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left
}, right)

---------------------------------------------------------------- TOGGLE BUTTON
local toggle = button("Piano UI", gui, UDim2.fromOffset(90, 28), UDim2.new(0, 0, 0.5, 0), COL.bar)
toggle.Active = true; toggle.ZIndex = 5

do
    local dragging, moved, startPos, startMouse = false, false, nil, nil
    toggle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            startPos, startMouse = toggle.Position, i.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startMouse
            if moved or d.Magnitude > 8 then
                moved = true
                toggle.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1
                      or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if not moved then
                main.Visible = not main.Visible
                playSound(main.Visible and SFX.open or SFX.close, 0.1)
            end
        end
    end)
end

UIS.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
        playSound(main.Visible and SFX.open or SFX.close, 0.1)
    end
end)

---------------------------------------------------------------- DRAG MAIN FRAME
do
    local dragging, startMouse, startPos = false, nil, nil
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startMouse, startPos = i.Position, main.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startMouse
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

---------------------------------------------------------------- FULLBRIGHT
local Lighting = game:GetService("Lighting")
local FB = {on = false, saved = nil, atmo = {}}

local function fbSave()
    if FB.saved then return end
    FB.saved = {
        Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
    }
end
local function fbApply()
    pcall(function()
        Lighting.Brightness = 2; Lighting.ClockTime  = 14
        Lighting.FogStart   = 1e9; Lighting.FogEnd   = 1e9
        Lighting.GlobalShadows = false
        Lighting.Ambient       = Color3.new(1,1,1)
        Lighting.OutdoorAmbient = Color3.new(1,1,1)
        for _, o in ipairs(Lighting:GetChildren()) do
            if o:IsA("Atmosphere") then
                if FB.atmo[o] == nil then FB.atmo[o] = {o.Density, o.Haze} end
                o.Density, o.Haze = 0, 0
            end
        end
    end)
end
local function setFullbright(on)
    FB.on = on
    if on then fbSave(); fbApply()
    elseif FB.saved then
        pcall(function() for k, v in pairs(FB.saved) do Lighting[k] = v end end)
        for o, v in pairs(FB.atmo) do
            pcall(function() o.Density, o.Haze = v[1], v[2] end)
        end
        FB.atmo = {}
    end
    fbBtn.BackgroundColor3 = on and COL.good or COL.btn
    fbBtn.Text = on and "☀ Sáng" or "☀ Tắt"
end
fbBtn.MouseButton1Click:Connect(function()
    setFullbright(not FB.on)
    playSound(SFX.success, 0.3)
end)
task.spawn(function()
    while gui.Parent do
        if FB.on then fbApply() end
        task.wait(1)
    end
end)
setFullbright(true)

---------------------------------------------------------------- ADD PANEL
local addPanel = mk("Frame", {
    Size = UDim2.fromOffset(440, 310),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = COL.bg, BorderSizePixel = 0,
    Visible = false, ZIndex = 10
}, gui)
mk("UICorner", {CornerRadius = UDim.new(0, 6)}, addPanel)

-- Hướng dẫn format
mk("TextLabel", {
    Size = UDim2.fromOffset(420, 30), Position = UDim2.fromOffset(10, 10),
    BackgroundTransparency = 1,
    Font = Enum.Font.SourceSansItalic, TextSize = 12,
    TextColor3 = Color3.fromRGB(160, 200, 255),
    Text = "Dán kết quả từ hellohellohell0.com/midi2lua hoặc sheet text cũ",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 11
}, addPanel)

local apName   = textbox("tên bài",  addPanel, UDim2.fromOffset(260, 26), UDim2.fromOffset(10, 44))
local apBpm    = textbox("bpm",      addPanel, UDim2.fromOffset(90,  26), UDim2.fromOffset(280, 44))
local apSheet  = textbox(
    'bpm = 110\nloadstring(game:HttpGet("https://hellohellohell0.com/talentless-raw/loader_main.lua", true))()\nloadstring(game:HttpGet("https://gist.githack.com/.../custom_song.lua", true))()',
    addPanel, UDim2.fromOffset(420, 180), UDim2.fromOffset(10, 78))
apSheet.MultiLine = true; apSheet.TextWrapped = true
apSheet.TextXAlignment = Enum.TextXAlignment.Left
apSheet.TextYAlignment = Enum.TextYAlignment.Top
apSheet.TextSize = 13

local apSave   = button("Lưu",  addPanel, UDim2.fromOffset(200, 30), UDim2.fromOffset(10,  268), COL.good)
local apCancel = button("Huỷ",  addPanel, UDim2.fromOffset(200, 30), UDim2.fromOffset(230, 268), COL.bad)
for _, o in ipairs(addPanel:GetChildren()) do
    if o:IsA("GuiObject") then o.ZIndex = 11 end
end

---------------------------------------------------------------- WATCHER LOOPS
-- Theo dõi tốc độ live
task.spawn(function()
    local lastSpd = spdBox.Text
    while gui.Parent do
        local cur = spdBox.Text
        if cur ~= lastSpd then
            local v = tonumber(cur)
            if v then Player.speed = math.clamp(v, 0.1, 4) end
            lastSpd = cur
        end
        task.wait(0.1)
    end
end)

---------------------------------------------------------------- LOGIC UI
local selected
local loop, queueRunning = false, false
local deleteClickTime = {}

local CHORD_CHOICES = {3, 4, 5, 6, 8, 0}

local function setStatus(t) if status then status.Text = t or "" end end

local function inList(t, name)
    for i, v in ipairs(t) do if v == name then return i end end
end

local function fmt(s)
    s = math.max(0, math.floor(s))
    return ("%02d:%02d"):format(s // 60, s % 60)
end

local function refreshSettingsUI()
    lagBtn.Text = settings.antilag and "Chống lag: BẬT" or "Chống lag: TẮT"
    lagBtn.BackgroundColor3 = settings.antilag and COL.btnOn or COL.btn
    chordBtn.Text = "Max hợp âm: " .. (settings.maxChord == 0 and "∞" or tostring(settings.maxChord))
    fitTextLater(lagBtn); fitTextLater(chordBtn)
end
refreshSettingsUI()

lagBtn.MouseButton1Click:Connect(function()
    settings.antilag = not settings.antilag
    saveSettings(); refreshSettingsUI()
    playSound(SFX.success, 0.3)
    sendNotif(settings.antilag and "Success" or "Info",
              settings.antilag and "Chống lag: BẬT" or "Chống lag: TẮT", 3)
end)
chordBtn.MouseButton1Click:Connect(function()
    local nextIdx = 1
    for i, v in ipairs(CHORD_CHOICES) do
        if v == settings.maxChord then nextIdx = i % #CHORD_CHOICES + 1 end
    end
    settings.maxChord = CHORD_CHOICES[nextIdx]
    saveSettings(); refreshSettingsUI()
    sendNotif("Info", "Áp dụng từ lần phát tiếp theo", 2)
end)

local function refreshInfo()
    if not selected then return end
    nameLbl.Text = selected.name
    fitTextLater(nameLbl)
    favBtn.Text   = favs[selected.name] and "★ Bỏ thích" or "☆ Yêu thích"
    plAddBtn.Text = inList(playlist, selected.name) and "- Playlist" or "+ Playlist"
    delBtn.Visible = selected.custom == true

    -- Hiện badge format
    if selected.isTalentless then
        formatBadge.Text = "TALENTLESS ✓"
        formatBadge.BackgroundColor3 = Color3.fromRGB(40, 100, 60)
        formatBadge.TextColor3 = Color3.fromRGB(160, 255, 160)
    elseif selected.body then
        formatBadge.Text = "legacy sheet"
        formatBadge.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
        formatBadge.TextColor3 = Color3.fromRGB(200, 210, 255)
    else
        formatBadge.Text = ""
    end
end

local function selectSong(song)
    selected = song
    bpmBox.Text = tostring(song.bpm)
    if spdBox.Text == "" then spdBox.Text = "1" end
    refreshInfo()
    playSound(SFX.success, 0.15)
end

local function matches(song, q)
    if q == "" then return true end
    q = q:lower()
    if song.name:lower():find(q, 1, true) then return true end
    for _, c in ipairs(song.cat or {}) do
        if c:lower():find(q, 1, true) then return true end
    end
    return false
end

local function visibleSongs()
    local out = {}
    if currentTab == "Playlist" then
        for _, n in ipairs(playlist) do
            local s = findSong(n)
            if s and matches(s, search.Text) then out[#out+1] = s end
        end
        return out
    end
    for _, s in ipairs(songs) do
        local okTab = currentTab == "All"
            or (currentTab == "Favs"   and favs[s.name])
            or (currentTab == "Custom" and s.custom)
        if okTab and matches(s, search.Text) then out[#out+1] = s end
    end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

local function rebuildList()
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
    end
    local vis = visibleSongs()
    if #vis == 0 then
        local empty = mk("TextLabel", {
            Size = UDim2.new(1, -8, 0, 30), BackgroundTransparency = 1,
            Font = Enum.Font.SourceSans, TextSize = 14,
            TextColor3 = Color3.fromRGB(160, 165, 180),
            Text = "(trống)", TextXAlignment = Enum.TextXAlignment.Left
        }, list)
        empty.LayoutOrder = 1
        return
    end
    for i, s in ipairs(vis) do
        local b = button(s.name, list, UDim2.new(1, -8, 0, 30))
        b.LayoutOrder = i; b.TextSize = 15
        b.TextTruncate = Enum.TextTruncate.AtEnd

        -- Dấu hiệu format
        if s.isTalentless then
            b.Text = "✦ " .. s.name
            b.TextColor3 = Color3.fromRGB(180, 255, 180)
        end
        if favs[s.name] then b.Text = "★ " .. (s.isTalentless and "✦ " or "") .. s.name end
        if selected and selected.name == s.name then
            b.BackgroundColor3 = COL.btnOn
        end
        b.MouseButton1Click:Connect(function() selectSong(s) end)
    end
    for t, b in pairs(tabBtns) do
        b.BackgroundColor3 = (t == currentTab) and COL.btnOn or COL.btn
    end
end

for t, b in pairs(tabBtns) do
    b.MouseButton1Click:Connect(function()
        currentTab = t; rebuildList()
        playSound(SFX.success, 0.15)
    end)
end
search:GetPropertyChangedSignal("Text"):Connect(rebuildList)

local function readSpeed()
    return math.clamp(tonumber(spdBox.Text) or 1, 0.1, 4)
end

---------------------------------------------------------------- PLAY — phân biệt TALENTLESS vs legacy
local function playSelected()
    if not selected then
        sendNotif("Error", "Chưa chọn bài", 3)
        playSound(SFX.error, 0.5)
        return
    end
    if Player.playing or _G.songisplaying then
        sendNotif("Error", "Đang phát bài khác", 2)
        playSound(SFX.error, 0.5)
        return
    end

    local spd = readSpeed()
    setStatus("Đang phát: " .. selected.name)
    sendNotif("Success", "▶ " .. selected.name, 3)
    playSound(SFX.open, 0.1)

    if selected.isTalentless and selected.body then
        -- ── FORMAT MỚI: chạy qua TALENTLESS loader ──────────────────────────
        -- Set bpm và speed trước khi chạy, giống TALENTLESS
        local patchedBody = selected.body
        -- Chèn/ghi đè bpm ở đầu
        patchedBody = patchedBody:gsub("^%s*bpm%s*=%s*%d+", "bpm = " .. tostring(tonumber(bpmBox.Text) or selected.bpm))

        Player.playTalentless(patchedBody, spd)

        setStatus("")
        sendNotif("Info", "Xong: " .. selected.name, 3)

    elseif selected.body then
        -- ── FORMAT CŨ: dùng sheet text / timed ───────────────────────────────
        -- Thử strip header (bpm = N và loadstring lines) nếu có
        local rawSheet = selected.body
            :gsub("^%s*bpm%s*=%s*%d+%s*\n?", "")
            :gsub("loadstring%(.-%)\n?", "")
            :gsub("game:HttpGet%(.-%)\n?", "")

        local bpm = tonumber(bpmBox.Text) or selected.bpm
        Player.playLegacy(rawSheet, bpm, spd)

        if Player.dropped > 0 then
            sendNotif("Info", "Xong — bỏ " .. Player.dropped .. " nốt trễ", 4)
        else
            sendNotif("Info", "Xong: " .. selected.name, 3)
        end
        setStatus("")
    end
end

playBtn.MouseButton1Click:Connect(function() task.spawn(playSelected) end)

stopBtn.MouseButton1Click:Connect(function()
    queueRunning = false
    _G.STOPIT = true
    Player.stop()
    task.delay(0.3, function() _G.STOPIT = nil end)
    setStatus("Đã dừng")
    playSound(SFX.close, 0.2)
    sendNotif("Info", "Đã dừng phát", 2)
end)

pauseBtn.MouseButton1Click:Connect(function()
    -- Với TALENTLESS format pause không khả dụng (loader tự quản)
    if selected and selected.isTalentless then
        sendNotif("Info", "Pause không hỗ trợ với bài TALENTLESS loader", 3)
        return
    end
    local p = Player.togglePause()
    pauseBtn.Text = p and "▶ Tiếp tục" or "❚❚ Pause"
    fitTextLater(pauseBtn)
    playSound(SFX.success, 0.2)
end)

back10.MouseButton1Click:Connect(function()
    if Player.playing and not (selected and selected.isTalentless) then
        Player.seek(Player.songT - 10)
    end
end)
fwd10.MouseButton1Click:Connect(function()
    if Player.playing and not (selected and selected.isTalentless) then
        Player.seek(Player.songT + 10)
    end
end)

-- Thanh tua
do
    local dragging = false
    local function fracFromX(x)
        local w = seekBack.AbsoluteSize.X
        return w > 0 and math.clamp((x - seekBack.AbsolutePosition.X) / w, 0, 1) or 0
    end
    local function preview(f)
        seekFill.Size     = UDim2.fromScale(f, 1)
        seekKnob.Position = UDim2.fromScale(f, 0.5)
        timeLbl.Text      = fmt(f * Player.total) .. " / " .. fmt(Player.total)
    end
    seekBack.InputBegan:Connect(function(i)
        if (i.UserInputType == Enum.UserInputType.MouseButton1
         or i.UserInputType == Enum.UserInputType.Touch)
         and Player.playing and not (selected and selected.isTalentless) then
            dragging = true; preview(fracFromX(i.Position.X))
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then
            preview(fracFromX(i.Position.X))
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1
                      or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            Player.seek(fracFromX(i.Position.X) * Player.total)
        end
    end)
    task.spawn(function()
        while gui.Parent do
            if not dragging then
                if Player.playing and not (selected and selected.isTalentless) and Player.total > 0 then
                    local f = math.clamp(Player.songT / Player.total, 0, 1)
                    seekFill.Size     = UDim2.fromScale(f, 1)
                    seekKnob.Position = UDim2.fromScale(f, 0.5)
                    timeLbl.Text      = fmt(Player.songT) .. " / " .. fmt(Player.total)
                                     .. (Player.paused and "  ⏸" or "")
                else
                    seekFill.Size     = UDim2.fromScale(0, 1)
                    seekKnob.Position = UDim2.fromScale(0, 0.5)
                    if not Player.playing then
                        timeLbl.Text  = "00:00 / 00:00"
                        pauseBtn.Text = "❚❚ Pause"
                    end
                end
            end
            task.wait(0.1)
        end
    end)
end

favBtn.MouseButton1Click:Connect(function()
    if not selected then return end
    local wasFav = favs[selected.name]
    favs[selected.name] = (not wasFav) or nil
    saveFavs(); refreshInfo(); rebuildList()
    playSound(SFX.success, 0.4)
    sendNotif("Success", wasFav and "Đã bỏ yêu thích" or "Đã thêm yêu thích", 3)
end)

plAddBtn.MouseButton1Click:Connect(function()
    if not selected then return end
    local i = inList(playlist, selected.name)
    if i then
        table.remove(playlist, i)
        sendNotif("Info", "Đã xoá khỏi playlist", 2)
    else
        table.insert(playlist, selected.name)
        sendNotif("Success", "Đã thêm vào playlist", 2)
    end
    playSound(SFX.success, 0.3)
    refreshInfo()
    if currentTab == "Playlist" then rebuildList() end
end)

loopBtn.MouseButton1Click:Connect(function()
    loop = not loop
    loopBtn.Text = loop and "Lặp: BẬT" or "Lặp: TẮT"
    loopBtn.BackgroundColor3 = loop and COL.btnOn or COL.btn
    playSound(SFX.success, 0.3)
end)

local function runQueue(shuffle)
    if queueRunning or Player.playing or _G.songisplaying then
        sendNotif("Error", "Đang phát", 2)
        playSound(SFX.error, 0.5)
        return
    end
    if #playlist == 0 then
        sendNotif("Error", "Playlist trống", 2)
        playSound(SFX.error, 0.5)
        return
    end
    queueRunning = true
    task.spawn(function()
        repeat
            local order = table.clone(playlist)
            if shuffle then
                for i = #order, 2, -1 do
                    local j = math.random(i)
                    order[i], order[j] = order[j], order[i]
                end
            end
            for _, n in ipairs(order) do
                if not queueRunning then break end
                local s = findSong(n)
                if s then selectSong(s); playSelected(); task.wait(0.8) end
            end
        until not queueRunning or not loop
        queueRunning = false
        sendNotif("Info", "Hết playlist", 3)
    end)
end
plPlayBtn.MouseButton1Click:Connect(function() runQueue(false) end)
plShufBtn.MouseButton1Click:Connect(function() runQueue(true)  end)

-- XOÁ BÀI: double-click giống TALENTLESS
delBtn.MouseButton1Click:Connect(function()
    if not (selected and selected.custom and hasFS) then return end
    local name = selected.name
    local now  = tick()
    local last = deleteClickTime[name] or 0
    if now - last <= 0.5 then
        pcall(delfile, selected.path or (FOLDER .. "/" .. name .. ".txt"))
        local i = inList(playlist, name); if i then table.remove(playlist, i) end
        favs[name] = nil; saveFavs()
        selected = nil; nameLbl.Text = "(chọn bài)"
        loadCustom(); rebuildList()
        playSound(SFX.success, 0.5)
        sendNotif("Success", "Đã xoá: " .. name, 3)
        deleteClickTime[name] = nil
    else
        deleteClickTime[name] = now
        playSound(SFX.success, 0.3)
        sendNotif("Info", "Nhấn lần nữa để xác nhận xoá", 3)
    end
end)

addBtn.MouseButton1Click:Connect(function()
    if not hasFS then
        sendNotif("Error", "Executor không hỗ trợ lưu file", 4)
        playSound(SFX.error, 0.5)
        return
    end
    addPanel.Visible = true
    playSound(SFX.open, 0.1)
end)
apCancel.MouseButton1Click:Connect(function()
    addPanel.Visible = false
    playSound(SFX.close, 0.1)
end)

apSave.MouseButton1Click:Connect(function()
    local name  = safeName(apName.Text)
    local bpm   = tonumber(apBpm.Text) or 100
    local sheet = apSheet.Text

    -- Nếu là URL → tải về
    local url = sheet:match("^%s*(https?://%S+)%s*$")
    if url then
        local okh, body = pcall(function() return game:HttpGet(url) end)
        if not okh or type(body) ~= "string" then
            sendNotif("Error", "Không tải được link", 4)
            playSound(SFX.error, 0.5)
            return
        end
        sheet = body
    end

    if name == "" or sheet:match("^%s*$") then
        sendNotif("Error", "Thiếu tên hoặc nội dung", 3)
        playSound(SFX.error, 0.5)
        return
    end

    -- Patch URL (chuẩn TALENTLESS)
    sheet = patchSongScript(sheet)

    -- Nếu là format TALENTLESS (có loader_main) → lưu nguyên
    -- Nếu không có bpm dòng đầu → chèn vào
    if not sheet:match("^%s*bpm%s*=%s*%d+") then
        sheet = "bpm = " .. bpm .. "\n" .. sheet
    end

    ensureDirs()
    local savePath = FOLDER .. "/" .. name .. ".txt"
    local ok = pcall(writefile, savePath, sheet)
    if not ok then
        sendNotif("Error", "Lưu thất bại", 4)
        playSound(SFX.error, 0.5)
        return
    end

    addPanel.Visible = false
    apName.Text, apBpm.Text, apSheet.Text = "", "", ""
    loadCustom(); rebuildList()
    playSound(SFX.success, 0.5)
    local isNew = isTalentlessFormat(sheet)
    sendNotif("Success", "Đã lưu: " .. name .. (isNew and " [TALENTLESS]" or " [legacy]"), 4)
end)

closeBtn.MouseButton1Click:Connect(function()
    queueRunning = false
    _G.STOPIT = true
    Player.stop()
    task.delay(0.2, function() releaseAll(); _G.STOPIT = nil end)
    setFullbright(false)
    playSound(SFX.close, 0.2)
    gui:Destroy()
    notifGui:Destroy()
    _G.AutoPianoV5 = nil
    _G.songisplaying   = false
    _G.AutoPianoPlaying = false
end)

rebuildList()
playSound(SFX.open, 0.1)
sendNotif("Success", "Auto Piano v6 · TALENTLESS Edition", 3)
if not hasFS then
    sendNotif("Info", "Executor không hỗ trợ file — không lưu được bài custom", 5)
end

-- Nhắc nhở format nếu không có bài nào
task.delay(1.5, function()
    if #songs == 0 then
        sendNotif("Info", "Thêm bài bằng nút '+ Thêm bài' — dán output từ midi2lua", 6)
    end
end)

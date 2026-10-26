--[[
    Auto Piano v7 — TALENTLESS Compatible
    Phát bài bằng loadstring() đúng như TALENTLESS: bpm + loader_main + custom_song
]]

-- ── Dừng instance cũ ──────────────────────────────────────────
if _G.AutoPianoV5 then pcall(function() _G.AutoPianoV5:Destroy() end) end
if _G.songisplaying then _G.STOPIT = true; task.wait(0.5) end
_G.STOPIT        = false
_G.songisplaying = false

-- ── Services ──────────────────────────────────────────────────
local UIS         = game:GetService("UserInputService")
local TweenSvc    = game:GetService("TweenService")
local ContentProv = game:GetService("ContentProvider")
local TextSvc     = game:GetService("TextService")
local CoreGui     = game:GetService("CoreGui")
local Lighting    = game:GetService("Lighting")
local SoundSvc    = game:GetService("SoundService")
local Debris      = game:GetService("Debris")

-- ── File system ───────────────────────────────────────────────
local FOLDER   = "TALENTLESS_CUSTOM_SONGS"
local FAV_FILE = "TALENTLESS_FAV_SONGS.txt"
local SET_FILE = "AutoPianoV7_settings.txt"

local hasFS = pcall(function()
    assert(type(writefile)  == "function")
    assert(type(readfile)   == "function")
    assert(type(isfile)     == "function")
    assert(type(isfolder)   == "function")
    assert(type(makefolder) == "function")
    assert(type(listfiles)  == "function")
    assert(type(delfile)    == "function")
end)

local function ensureFolder()
    if not hasFS then return end
    pcall(function() if not isfolder(FOLDER) then makefolder(FOLDER) end end)
end
ensureFolder()

local function safeName(s)
    s = tostring(s):gsub('[\\/:*?"<>|]', ""):gsub("^%s+",""):gsub("%s+$","")
    return s ~= "" and s or nil
end

-- ── Âm thanh ──────────────────────────────────────────────────
local SFX = { success="18595195017", error="7383525713",
              open="70452176150315", close="1524549907" }
pcall(function()
    local a = {}
    for _,v in pairs(SFX) do a[#a+1]="rbxassetid://"..v end
    ContentProv:PreloadAsync(a)
end)

local muteSFX = false
local function playSound(key, vol)
    if muteSFX then return end
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://"..(SFX[key] or tostring(key))
    s.Volume  = vol or 0.5
    s.Parent  = SoundSvc
    s:Play()
    Debris:AddItem(s, 4)
end

-- ── fitText ───────────────────────────────────────────────────
local function fitText(obj)
    if not (obj:IsA("TextButton") or obj:IsA("TextLabel")) then return end
    local sz = obj.TextSize
    local w  = math.max(obj.AbsoluteSize.X, 10)
    while sz > 7 do
        if TextSvc:GetTextSize(obj.Text, sz, obj.Font, Vector2.new(w, math.huge)).X <= w then break end
        sz -= 1
    end
    obj.TextSize = sz
end
local function fitLater(obj)
    task.delay(0.06, function() if obj and obj.Parent then fitText(obj) end end)
end

-- ── Notifications ─────────────────────────────────────────────
local notifGui
do
    local ok,h = pcall(function() return gethui and gethui() end)
    notifGui = Instance.new("ScreenGui")
    notifGui.Name="APv7Notifs"; notifGui.ResetOnSpawn=false
    notifGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    notifGui.Parent=(ok and h) or CoreGui
end
local notifStack = {}
local NCOL = {Success=Color3.fromRGB(50,140,80),Error=Color3.fromRGB(170,55,55),Info=Color3.fromRGB(60,100,170)}

local function notify(typ, msg, dur)
    dur = dur or 4
    for _,f in ipairs(notifStack) do
        TweenSvc:Create(f,TweenInfo.new(0.2),
            {Position=UDim2.new(1,-268,f.Position.Y.Scale,f.Position.Y.Offset+52)}):Play()
    end
    local fr = Instance.new("Frame")
    fr.Size=UDim2.fromOffset(260,44); fr.BackgroundColor3=NCOL[typ] or NCOL.Info
    fr.BorderSizePixel=0; fr.ZIndex=20; fr.Position=UDim2.new(1,10,1,-62); fr.Parent=notifGui
    Instance.new("UICorner",fr).CornerRadius=UDim.new(0,6)
    local function lbl(text,y,h2,bold)
        local l=Instance.new("TextLabel",fr)
        l.BackgroundTransparency=1; l.Size=UDim2.new(1,-10,0,h2); l.Position=UDim2.fromOffset(8,y)
        l.Text=text; l.TextColor3=Color3.new(1,1,1); l.TextXAlignment=Enum.TextXAlignment.Left
        l.Font=bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
        l.TextSize=bold and 12 or 13; l.TextWrapped=true; l.ZIndex=21
    end
    lbl(typ,3,14,true); lbl(msg,17,24,false)
    table.insert(notifStack,fr)
    TweenSvc:Create(fr,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
        {Position=UDim2.new(1,-268,1,-62)}):Play()
    task.delay(dur,function()
        TweenSvc:Create(fr,TweenInfo.new(0.3),
            {Position=UDim2.new(1,10,fr.Position.Y.Scale,fr.Position.Y.Offset)}):Play()
        task.delay(0.35,function()
            local i=table.find(notifStack,fr); if i then table.remove(notifStack,i) end
            if fr.Parent then fr:Destroy() end
        end)
    end)
end

-- ── Patch URL ─────────────────────────────────────────────────
local function patchURL(code)
    code=code:gsub("https://raw%.githubusercontent%.com/[^/]+/[^/]+/[^/]+/(.+)",
        "https://hellohellohell0.com/talentless-raw/%1")
    code=code:gsub("https://cdn%.jsdelivr%.net/gh/[^/]+/[^/@]+/?[^/]*/(.+)",
        "https://hellohellohell0.com/talentless-raw/%1")
    code=code:gsub("gist%.githubusercontent%.com","gist.githack.com")
    code=code:gsub("cdn%.statically%.io/gist","gist.githack.com")
    code=code:gsub("cdn%.statically%.io/gh/gist","gist.githack.com")
    return code
end

-- ── Dữ liệu ──────────────────────────────────────────────────
local songs, favs, playlist = {}, {}, {}

local function loadCustomSongs()
    for i=#songs,1,-1 do if songs[i].custom then table.remove(songs,i) end end
    if not hasFS then return end
    local ok,files = pcall(listfiles,FOLDER)
    if not ok or type(files)~="table" then return end
    for _,path in ipairs(files) do
        local p = tostring(path)
        if p:match("%.txt$") then
            local okr,body = pcall(readfile,p)
            if okr and type(body)=="string" and #body>0 then
                local name = p:gsub("\\","/"):match("([^/]+)%.txt$") or "?"
                body = patchURL(body)
                local bpmVal = tonumber(body:match("bpm%s*=%s*(%d+)")) or 100
                table.insert(songs,{name=name,bpm=bpmVal,body=body,custom=true,path=p})
            end
        end
    end
end

local function loadFavs()
    favs={}
    if not hasFS then return end
    local ok,body = pcall(function() return isfile(FAV_FILE) and readfile(FAV_FILE) or "" end)
    if ok and type(body)=="string" then
        for line in body:gmatch("[^\r\n]+") do if line~="" then favs[line]=true end end
    end
end
local function saveFavs()
    if not hasFS then return end
    local t={}; for k in pairs(favs) do t[#t+1]=k end
    pcall(writefile,FAV_FILE,table.concat(t,"\n"))
end

local settings = {muteSfx=false}
local function loadSettings()
    if not hasFS then return end
    local ok,body = pcall(function() return isfile(SET_FILE) and readfile(SET_FILE) or "" end)
    if ok and type(body)=="string" then
        local m=body:match("mutesfx=(%d)"); if m then settings.muteSfx=m=="1" end
    end
end
local function saveSettings()
    if not hasFS then return end
    pcall(writefile,SET_FILE,("mutesfx=%d"):format(settings.muteSfx and 1 or 0))
end

loadCustomSongs(); loadFavs(); loadSettings()
muteSFX = settings.muteSfx

local function findSong(name)
    for _,s in ipairs(songs) do if s.name==name then return s end end
end

-- ── PLAY ──────────────────────────────────────────────────────
local playing = false

local function playSong(s)
    if _G.songisplaying or playing then
        notify("Error","Đang phát bài khác — bấm Stop trước",3)
        playSound("error",0.5); return
    end
    playing=true; _G.STOPIT=false
    notify("Success","▶ "..s.name,3); playSound("open",0.1)
    task.spawn(function()
        local ok,err = pcall(function()
            _G.STOPIT=false; _G.songisplaying=false
            local fn,syntaxErr = loadstring(s.body)
            if not fn then error("Syntax error: "..tostring(syntaxErr)) end
            fn()
        end)
        playing=false
        if not ok then
            _G.songisplaying=false
            notify("Error",tostring(err):sub(1,120),7)
            playSound("error",0.5)
        end
    end)
end

local function stopSong()
    _G.STOPIT=true; playing=false
    notify("Info","Đã dừng",2); playSound("close",0.2)
end

-- ── UI helpers ────────────────────────────────────────────────
local C={
    bg=Color3.fromRGB(33,33,41), bar=Color3.fromRGB(50,57,73),
    btn=Color3.fromRGB(76,82,101), on=Color3.fromRGB(104,112,140),
    box=Color3.fromRGB(96,102,121), txt=Color3.new(1,1,1),
    good=Color3.fromRGB(70,160,100), bad=Color3.fromRGB(190,70,70),
    bord=Color3.fromRGB(64,68,90),
}

local function mk(cls,props,par)
    local o=Instance.new(cls)
    for k,v in pairs(props) do o[k]=v end
    if par then o.Parent=par end
    return o
end
local function corner(r,par) Instance.new("UICorner",par).CornerRadius=UDim.new(0,r or 4) end

-- makebtn: lưu màu gốc vào attribute để hover/leave luôn đúng dù đổi màu sau
local function makebtn(txt,par,sz,pos,col)
    col=col or C.btn
    local b=mk("TextButton",{
        Text=txt,Size=sz,Position=pos or UDim2.fromOffset(0,0),
        BackgroundColor3=col,BorderColor3=C.bord,BorderSizePixel=4,
        Font=Enum.Font.SourceSansBold,TextSize=16,
        TextColor3=C.txt,AutoButtonColor=false,
    },par)
    corner(4,b)
    local baseCol = col  -- capture đúng giá trị lúc tạo
    b.MouseEnter:Connect(function()
        TweenSvc:Create(b,TweenInfo.new(0.08),
            {BackgroundColor3=b.BackgroundColor3:Lerp(Color3.new(1,1,1),0.15)}):Play()
    end)
    b.MouseLeave:Connect(function()
        -- Dùng màu HIỆN TẠI của button (có thể đã đổi) thay vì baseCol cố định
        -- => không reset về màu cũ khi đang đổi trạng thái
        -- Chỉ reset nếu màu hiện tại gần với màu highlight
        TweenSvc:Create(b,TweenInfo.new(0.08),{BackgroundColor3=b.BackgroundColor3:Lerp(Color3.new(0,0,0),0.12)}):Play()
    end)
    return b
end

local function maketbx(ph,par,sz,pos)
    local b=mk("TextBox",{
        PlaceholderText=ph,Text="",Size=sz,Position=pos or UDim2.fromOffset(0,0),
        BackgroundColor3=C.box,BorderColor3=C.bord,BorderSizePixel=4,
        Font=Enum.Font.SourceSansBold,TextSize=15,
        TextColor3=C.txt,PlaceholderColor3=Color3.fromRGB(190,190,205),
        ClearTextOnFocus=false,
    },par)
    corner(4,b); return b
end

-- ── GUI root ──────────────────────────────────────────────────
local guiParent
do
    local ok,h=pcall(function() return gethui and gethui() end)
    guiParent=(ok and h) or CoreGui
end

local gui=mk("ScreenGui",{
    Name="AutoPianoV7",ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
},guiParent)
_G.AutoPianoV5=gui

-- main frame — ZIndex 1 (mặc định)
local main=mk("Frame",{
    Size=UDim2.fromOffset(490,430),
    Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),
    BackgroundColor3=C.bg,BorderSizePixel=0,
},gui)
corner(6,main)

mk("ImageLabel",{
    Size=UDim2.new(1,24,1,24),Position=UDim2.fromOffset(-12,-12),
    BackgroundTransparency=1,Image="rbxassetid://6014261993",
    ImageColor3=Color3.new(0,0,0),ImageTransparency=0.55,
    ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(49,49,450,450),ZIndex=-1,
},main)

-- ── Title bar ─────────────────────────────────────────────────
local titleBar=mk("Frame",{Size=UDim2.new(1,0,0,46),BackgroundColor3=C.bar,BorderSizePixel=0},main)
corner(6,titleBar)

mk("TextLabel",{
    Size=UDim2.new(1,-150,1,0),Position=UDim2.fromOffset(10,0),
    BackgroundTransparency=1,Font=Enum.Font.SourceSansBold,TextSize=20,
    Text="AUTO PIANO v7  ·  TALENTLESS",TextColor3=C.txt,
    TextXAlignment=Enum.TextXAlignment.Left,
},titleBar)

local fbBtn=makebtn("☀ Sáng",titleBar,UDim2.fromOffset(78,28),UDim2.new(1,-118,0,9),C.on)
fbBtn.TextSize=14

local closeBtn=mk("TextButton",{
    Size=UDim2.fromOffset(34,34),Position=UDim2.new(1,-38,0,6),
    BackgroundTransparency=1,Text="✕",
    Font=Enum.Font.SourceSansBold,TextSize=22,TextColor3=C.txt,
},titleBar)

-- ── Tabs ──────────────────────────────────────────────────────
local TAB_NAMES={"All","Favs","Playlist","Custom"}
local tabBtns,curTab={}, "All"
for i,t in ipairs(TAB_NAMES) do
    tabBtns[t]=makebtn(t,main,UDim2.fromOffset(56,22),UDim2.fromOffset(8+(i-1)*60,50))
    tabBtns[t].TextSize=13
end

local searchBox=maketbx("🔍 tìm kiếm...",main,UDim2.fromOffset(240,26),UDim2.fromOffset(8,76))

local songList=mk("ScrollingFrame",{
    Position=UDim2.fromOffset(8,107),Size=UDim2.fromOffset(240,315),
    BackgroundTransparency=1,BorderSizePixel=0,
    ScrollBarThickness=4,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
},main)
mk("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},songList)

-- ── Right panel ───────────────────────────────────────────────
local rp=mk("Frame",{Position=UDim2.fromOffset(256,50),Size=UDim2.fromOffset(226,374),BackgroundTransparency=1},main)

local nameLbl=mk("TextLabel",{
    Size=UDim2.new(1,0,0,48),BackgroundColor3=C.btn,BorderColor3=C.bord,BorderSizePixel=4,
    Font=Enum.Font.SourceSansBold,Text="(chọn bài)",TextColor3=C.txt,TextSize=17,TextWrapped=true,
},rp)
corner(4,nameLbl)

local bpmLbl=mk("TextLabel",{
    Size=UDim2.fromOffset(226,20),Position=UDim2.fromOffset(0,52),
    BackgroundTransparency=1,Font=Enum.Font.SourceSans,
    Text="",TextColor3=Color3.fromRGB(170,180,210),TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left,
},rp)

local playBtn   = makebtn("▶ Play",        rp, UDim2.fromOffset(110,30), UDim2.fromOffset(0,  76), C.good)
local stopBtn   = makebtn("■ Stop",        rp, UDim2.fromOffset(110,30), UDim2.fromOffset(116, 76), C.bad)
local favBtn    = makebtn("☆ Yêu thích",   rp, UDim2.fromOffset(110,30), UDim2.fromOffset(0,  110))
local plAddBtn  = makebtn("+ Playlist",    rp, UDim2.fromOffset(110,30), UDim2.fromOffset(116,110))
local delBtn    = makebtn("🗑 Xoá bài",    rp, UDim2.fromOffset(110,30), UDim2.fromOffset(0,  144), C.bad)
local addBtn    = makebtn("+ Thêm bài",    rp, UDim2.fromOffset(110,30), UDim2.fromOffset(116,144))
local plPlayBtn = makebtn("▶ Playlist",    rp, UDim2.fromOffset(110,30), UDim2.fromOffset(0,  178))
local plShufBtn = makebtn("🔀 Xáo",       rp, UDim2.fromOffset(110,30), UDim2.fromOffset(116,178))
local loopBtn   = makebtn("🔁 Lặp: TẮT",  rp, UDim2.fromOffset(110,30), UDim2.fromOffset(0,  212))
local sfxBtn    = makebtn("🔊 SFX: BẬT",  rp, UDim2.fromOffset(110,30), UDim2.fromOffset(116,212))
local reloadBtn = makebtn("↺ Reload",      rp, UDim2.fromOffset(226,28), UDim2.fromOffset(0,  246))

delBtn.Visible=false

local infoLbl=mk("TextLabel",{
    Size=UDim2.new(1,0,0,80),Position=UDim2.fromOffset(0,282),
    BackgroundTransparency=1,Font=Enum.Font.SourceSans,
    Text="",TextColor3=Color3.fromRGB(150,160,195),TextSize=11,
    TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
},rp)

for _,b in ipairs({playBtn,stopBtn,favBtn,plAddBtn,delBtn,addBtn,plPlayBtn,plShufBtn,loopBtn,sfxBtn,reloadBtn}) do
    fitLater(b)
end

-- ── Toggle button ─────────────────────────────────────────────
local toggleBtn=makebtn("🎹 Piano",gui,UDim2.fromOffset(96,30),UDim2.new(0,0,0.5,0),C.bar)
toggleBtn.ZIndex=5; toggleBtn.BorderSizePixel=4
_G.toggleUiTalentless=toggleBtn

do
    local dr,mv,sp,sm=false,false,nil,nil
    toggleBtn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            dr,mv,sp,sm=true,false,toggleBtn.Position,i.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dr and (i.UserInputType==Enum.UserInputType.MouseMovement
                or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-sm
            if mv or d.Magnitude>6 then
                mv=true
                toggleBtn.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
            end
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if dr and (i.UserInputType==Enum.UserInputType.MouseButton1
                or i.UserInputType==Enum.UserInputType.Touch) then
            dr=false
            if not mv then main.Visible=not main.Visible; playSound(main.Visible and "open" or "close",0.1) end
        end
    end)
end

UIS.InputBegan:Connect(function(i,gp)
    if not gp and i.KeyCode==Enum.KeyCode.RightShift then
        main.Visible=not main.Visible; playSound(main.Visible and "open" or "close",0.1)
    end
end)

-- ── Drag main frame ───────────────────────────────────────────
do
    local dr,sm,sp=false,nil,nil
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            dr=true; sm,sp=i.Position,main.Position
            i.Changed:Connect(function()
                if i.UserInputState==Enum.UserInputState.End then dr=false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dr and (i.UserInputType==Enum.UserInputType.MouseMovement
                or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-sm
            main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end

-- ── Fullbright ────────────────────────────────────────────────
local FB={on=false,saved=nil,atmo={}}
local function fbSave()
    if FB.saved then return end
    FB.saved={Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,
              FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,
              GlobalShadows=Lighting.GlobalShadows,
              Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient}
end
local function fbApply()
    pcall(function()
        Lighting.Brightness=2;Lighting.ClockTime=14
        Lighting.FogStart=1e9;Lighting.FogEnd=1e9;Lighting.GlobalShadows=false
        Lighting.Ambient=Color3.new(1,1,1);Lighting.OutdoorAmbient=Color3.new(1,1,1)
        for _,o in ipairs(Lighting:GetChildren()) do
            if o:IsA("Atmosphere") then
                if FB.atmo[o]==nil then FB.atmo[o]={o.Density,o.Haze} end
                o.Density,o.Haze=0,0
            end
        end
    end)
end
local function setFB(on)
    FB.on=on
    if on then fbSave();fbApply()
    elseif FB.saved then
        pcall(function() for k,v in pairs(FB.saved) do Lighting[k]=v end end)
        for o,v in pairs(FB.atmo) do pcall(function() o.Density,o.Haze=v[1],v[2] end) end
        FB.atmo={}
    end
    fbBtn.BackgroundColor3=on and C.good or C.on
    fbBtn.Text=on and "☀ Sáng" or "☀ Tắt"
end
fbBtn.MouseButton1Click:Connect(function() setFB(not FB.on); playSound("success",0.3) end)
task.spawn(function() while gui.Parent do if FB.on then fbApply() end task.wait(1) end end)
setFB(true)

-- ── Add panel ─────────────────────────────────────────────────
-- ZIndex=200 để đảm bảo luôn ở trên tất cả kể cả notif
local addPanel=mk("Frame",{
    Size=UDim2.fromOffset(460,360),
    Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),
    BackgroundColor3=C.bg,BorderSizePixel=0,
    Visible=false,ZIndex=200,
},gui)
corner(6,addPanel)

-- Background tối để focus vào panel
local addOverlay=mk("Frame",{
    Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),
    BackgroundTransparency=0.5,BorderSizePixel=0,Visible=false,ZIndex=199,
},gui)

local function showAddPanel(v)
    addPanel.Visible=v; addOverlay.Visible=v
end

local function apLabel(txt,y,h2,italic)
    return mk("TextLabel",{
        Size=UDim2.fromOffset(440,h2),Position=UDim2.fromOffset(10,y),
        BackgroundTransparency=1,
        Font=italic and Enum.Font.SourceSansItalic or Enum.Font.SourceSansBold,
        TextSize=italic and 12 or 14,TextColor3=italic and Color3.fromRGB(140,180,255) or C.txt,
        Text=txt,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,ZIndex=201,
    },addPanel)
end

apLabel("➕ Thêm bài nhạc mới",8,22,false)
apLabel("Dán toàn bộ output từ hellohellohell0.com/midi2lua (3 dòng: bpm + 2 loadstring)",32,26,true)
apLabel("Tên bài (để trống = tự đặt tên):",62,18,false)

local apName=maketbx("VD: Twinkle Little Star",addPanel,UDim2.fromOffset(440,30),UDim2.fromOffset(10,82))
apName.ZIndex=201

apLabel("Nội dung script (dán vào đây):",118,18,false)

local apSheet=mk("TextBox",{
    PlaceholderText="bpm = 90\nloadstring(game:HttpGet(\"...loader_main.lua\", true))()\nloadstring(game:HttpGet(\"...custom_song.lua\", true))()",
    Text="",
    Size=UDim2.fromOffset(440,160),Position=UDim2.fromOffset(10,138),
    BackgroundColor3=C.box,BorderColor3=C.bord,BorderSizePixel=4,
    Font=Enum.Font.SourceSans,TextSize=13,
    TextColor3=C.txt,PlaceholderColor3=Color3.fromRGB(160,165,190),
    ClearTextOnFocus=false,MultiLine=true,TextWrapped=true,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    ZIndex=201,
},addPanel)
corner(4,apSheet)

local apSave   = makebtn("💾 Lưu bài",  addPanel, UDim2.fromOffset(215,34), UDim2.fromOffset(10, 308),  C.good)
local apCancel = makebtn("✕ Huỷ",       addPanel, UDim2.fromOffset(215,34), UDim2.fromOffset(235,308), C.bad)
apSave.ZIndex=201; apCancel.ZIndex=201
-- Đảm bảo mọi con của addPanel có ZIndex >= 201
for _,ch in ipairs(addPanel:GetDescendants()) do
    if ch:IsA("GuiObject") and ch.ZIndex<201 then ch.ZIndex=201 end
end

-- ── Logic UI ──────────────────────────────────────────────────
local selected
local looping,queueRunning=false,false
local delConfirm={}

local function inList(lst,name)
    for i,v in ipairs(lst) do if v==name then return i end end
end

local function refreshSfxBtn()
    sfxBtn.Text=settings.muteSfx and "🔇 SFX: TẮT" or "🔊 SFX: BẬT"
    sfxBtn.BackgroundColor3=settings.muteSfx and C.bad or C.btn
    fitLater(sfxBtn)
end
local function refreshLoopBtn()
    loopBtn.Text=looping and "🔁 Lặp: BẬT" or "🔁 Lặp: TẮT"
    loopBtn.BackgroundColor3=looping and C.on or C.btn
end

refreshSfxBtn()

local function refreshInfo()
    if not selected then return end
    nameLbl.Text=selected.name; fitLater(nameLbl)
    bpmLbl.Text="BPM: "..tostring(selected.bpm).."  [TALENTLESS]"
    favBtn.Text=favs[selected.name] and "★ Bỏ thích" or "☆ Yêu thích"
    plAddBtn.Text=inList(playlist,selected.name) and "− Playlist" or "+ Playlist"
    delBtn.Visible=(selected.custom==true)
    fitLater(favBtn); fitLater(plAddBtn)
    local lines,n={},0
    for l in (selected.body or ""):gmatch("[^\n]+") do
        n+=1; if n>4 then break end; lines[n]=l:sub(1,55)
    end
    infoLbl.Text=table.concat(lines,"\n")
end

local function selectSong(s)
    selected=s; refreshInfo(); playSound("success",0.15)
    for _,c in ipairs(songList:GetChildren()) do
        if c:IsA("TextButton") then
            c.BackgroundColor3=(c.Name==s.name) and C.on or C.btn
        end
    end
end

local function matchesSong(s,q)
    if q=="" then return true end
    return s.name:lower():find(q:lower(),1,true)~=nil
end

local function visibleSongs()
    local out,q={},searchBox.Text
    if curTab=="Playlist" then
        for _,n in ipairs(playlist) do
            local s=findSong(n)
            if s and matchesSong(s,q) then out[#out+1]=s end
        end
        return out
    end
    for _,s in ipairs(songs) do
        local ok2=curTab=="All"
            or (curTab=="Favs" and favs[s.name])
            or (curTab=="Custom" and s.custom)
        if ok2 and matchesSong(s,q) then out[#out+1]=s end
    end
    table.sort(out,function(a,b) return a.name:lower()<b.name:lower() end)
    return out
end

local function rebuildList()
    for _,c in ipairs(songList:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    local vis=visibleSongs()
    if #vis==0 then
        local e=mk("TextLabel",{
            Size=UDim2.new(1,-8,0,30),BackgroundTransparency=1,
            Font=Enum.Font.SourceSans,TextSize=14,
            TextColor3=Color3.fromRGB(155,160,180),
            Text="(không có bài nào)",TextXAlignment=Enum.TextXAlignment.Left,
        },songList); e.LayoutOrder=1; return
    end
    for i,s in ipairs(vis) do
        local b=makebtn(s.name,songList,UDim2.new(1,-8,0,32))
        b.Name=s.name; b.LayoutOrder=i; b.TextSize=14
        b.TextTruncate=Enum.TextTruncate.AtEnd
        if favs[s.name] then b.Text="★ "..s.name end
        if selected and selected.name==s.name then b.BackgroundColor3=C.on end
        b.MouseButton1Click:Connect(function() selectSong(s) end)
    end
    for t2,b2 in pairs(tabBtns) do
        b2.BackgroundColor3=(t2==curTab) and C.on or C.btn
    end
end

for t2,b2 in pairs(tabBtns) do
    b2.MouseButton1Click:Connect(function()
        curTab=t2; rebuildList(); playSound("success",0.15)
    end)
end
searchBox:GetPropertyChangedSignal("Text"):Connect(rebuildList)

-- ── Button events ─────────────────────────────────────────────

playBtn.MouseButton1Click:Connect(function()
    if not selected then notify("Error","Chưa chọn bài",3); playSound("error",0.5); return end
    playSong(selected)
end)

stopBtn.MouseButton1Click:Connect(function()
    queueRunning=false; stopSong()
end)

favBtn.MouseButton1Click:Connect(function()
    if not selected then return end
    local was=favs[selected.name]
    favs[selected.name]=(not was) or nil
    saveFavs(); refreshInfo(); rebuildList()
    playSound("success",0.4)
    notify("Success",was and "Đã bỏ yêu thích" or "Đã thêm yêu thích",3)
end)

plAddBtn.MouseButton1Click:Connect(function()
    if not selected then return end
    local idx=inList(playlist,selected.name)
    if idx then table.remove(playlist,idx); notify("Info","Đã xoá khỏi playlist",2)
    else table.insert(playlist,selected.name); notify("Success","Đã thêm vào playlist",2) end
    playSound("success",0.3); refreshInfo()
    if curTab=="Playlist" then rebuildList() end
end)

loopBtn.MouseButton1Click:Connect(function()
    looping=not looping; refreshLoopBtn(); playSound("success",0.3)
end)

sfxBtn.MouseButton1Click:Connect(function()
    settings.muteSfx=not settings.muteSfx
    muteSFX=settings.muteSfx
    saveSettings(); refreshSfxBtn()
end)

local function runQueue(shuffle)
    if queueRunning or _G.songisplaying or playing then
        notify("Error","Đang phát bài khác",2); playSound("error",0.5); return
    end
    if #playlist==0 then notify("Error","Playlist trống",2); playSound("error",0.5); return end
    queueRunning=true
    task.spawn(function()
        repeat
            local order=table.clone(playlist)
            if shuffle then
                for i=#order,2,-1 do local j=math.random(i); order[i],order[j]=order[j],order[i] end
            end
            for _,n in ipairs(order) do
                if not queueRunning then break end
                local s=findSong(n)
                if s then
                    selectSong(s); playSong(s); task.wait(1)
                    while (_G.songisplaying or playing) and queueRunning do task.wait(0.5) end
                    if not queueRunning then break end
                    task.wait(0.5)
                end
            end
        until not queueRunning or not looping
        queueRunning=false; notify("Info","Hết playlist",3)
    end)
end
plPlayBtn.MouseButton1Click:Connect(function() runQueue(false) end)
plShufBtn.MouseButton1Click:Connect(function() runQueue(true) end)

delBtn.MouseButton1Click:Connect(function()
    if not (selected and selected.custom and hasFS) then return end
    local name=selected.name; local now=tick()
    if now-(delConfirm[name] or 0)<=0.6 then
        pcall(delfile,selected.path)
        local ip=inList(playlist,name); if ip then table.remove(playlist,ip) end
        favs[name]=nil; saveFavs()
        selected=nil; nameLbl.Text="(chọn bài)"; bpmLbl.Text=""; infoLbl.Text=""; delBtn.Visible=false
        loadCustomSongs(); rebuildList()
        playSound("success",0.5); notify("Success","Đã xoá: "..name,3); delConfirm[name]=nil
    else
        delConfirm[name]=now; playSound("success",0.3); notify("Info","Nhấn lần nữa để xác nhận xoá",3)
    end
end)

reloadBtn.MouseButton1Click:Connect(function()
    loadCustomSongs(); loadFavs(); rebuildList()
    notify("Info","Đã reload — "..#songs.." bài",2); playSound("success",0.3)
end)

addBtn.MouseButton1Click:Connect(function()
    if not hasFS then
        notify("Error","Executor không hỗ trợ file — không lưu được",5)
        playSound("error",0.5); return
    end
    apName.Text=""; apSheet.Text=""
    showAddPanel(true); playSound("open",0.1)
end)

apCancel.MouseButton1Click:Connect(function()
    showAddPanel(false); playSound("close",0.1)
end)

-- Bấm overlay để đóng
addOverlay.MouseButton1Click:Connect(function()
    -- không đóng ngẫu nhiên, phải bấm Huỷ
end)

-- ── LƯU BÀI ──────────────────────────────────────────────────
apSave.MouseButton1Click:Connect(function()
    local body = apSheet.Text
    local name = safeName(apName.Text)

    -- Validate không rỗng
    if not body or body:match("^%s*$") then
        notify("Error","⚠ Ô nội dung trống! Hãy dán script vào",4)
        playSound("error",0.5); return
    end

    -- Nếu chỉ nhập 1 URL đơn → tải về
    local url = body:match("^%s*(https?://%S+)%s*$")
    if url then
        notify("Info","Đang tải từ URL...",3)
        local ok2,res=pcall(function() return game:HttpGet(url,true) end)
        if not ok2 or type(res)~="string" or #res<10 then
            notify("Error","Tải URL thất bại: "..tostring(res):sub(1,60),5)
            playSound("error",0.5); return
        end
        body=res
    end

    -- Patch URL
    body=patchURL(body)

    -- Validate: phải có bpm
    if not body:match("bpm%s*=") then
        notify("Error","⚠ Không tìm thấy 'bpm = ...' trong script",5)
        playSound("error",0.5); return
    end

    -- Tự đặt tên nếu để trống
    if not name then
        -- Lấy từ dòng comment Host: nếu có
        local host = body:match("%-%-[^\n]-Host:%s*([^\n]+)")
        name = safeName(host) or ("song_"..tostring(os.time()):sub(-6))
    end

    -- Tạo thư mục
    ensureFolder()
    local folderExists = not hasFS or pcall(function() assert(isfolder(FOLDER)) end)
    if not folderExists then
        notify("Error","Không tạo được thư mục "..FOLDER,5)
        playSound("error",0.5); return
    end

    -- Ghi file
    local savePath = FOLDER.."/"..name..".txt"
    local wok,werr = pcall(writefile,savePath,body)
    if not wok then
        notify("Error","Ghi file thất bại: "..tostring(werr):sub(1,60),5)
        playSound("error",0.5); return
    end

    -- Thành công
    showAddPanel(false); apName.Text=""; apSheet.Text=""
    loadCustomSongs(); rebuildList()
    playSound("success",0.5)
    notify("Success","✓ Đã lưu: "..name,4)

    -- Tự chọn bài vừa lưu
    local newSong=findSong(name)
    if newSong then curTab="Custom"; rebuildList(); selectSong(newSong) end
end)

closeBtn.MouseButton1Click:Connect(function()
    queueRunning=false; stopSong(); setFB(false); playSound("close",0.2)
    task.delay(0.35,function()
        if gui and gui.Parent then gui:Destroy() end
        if notifGui and notifGui.Parent then notifGui:Destroy() end
        _G.AutoPianoV5=nil; _G.toggleUiTalentless=nil
    end)
end)

-- Status watcher
task.spawn(function()
    while gui and gui.Parent do
        local isPlaying=_G.songisplaying or playing
        if isPlaying then
            playBtn.BackgroundColor3=Color3.fromRGB(35,100,50)
            playBtn.Text="⏸ Đang phát..."
        else
            playBtn.BackgroundColor3=C.good
            playBtn.Text="▶ Play"
        end
        task.wait(0.4)
    end
end)

-- ── Init ──────────────────────────────────────────────────────
rebuildList()
playSound("open",0.1)
notify("Success","Auto Piano v7 · TALENTLESS Edition",3)

if not hasFS then
    notify("Info","⚠ Executor không hỗ trợ lưu file",6)
else
    local n=#songs
    task.delay(0.8,function()
        if gui and gui.Parent then
            if n>0 then notify("Info","Đã load "..n.." bài từ "..FOLDER,3)
            else notify("Info","Bấm '+ Thêm bài' → dán output midi2lua → Lưu",6) end
        end
    end)
end

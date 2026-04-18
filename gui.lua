local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local Stats            = game:GetService("Stats")
local CoreGui          = game:GetService("CoreGui")
local LP               = Players.LocalPlayer

local XenonUI = {}
XenonUI.__index = XenonUI

XenonUI.DefaultTheme = {
    BG        = Color3.fromRGB(18,18,24),
    BG2       = Color3.fromRGB(26,26,34),
    BG3       = Color3.fromRGB(32,32,42),
    BG4       = Color3.fromRGB(40,40,52),
    Border    = Color3.fromRGB(55,55,74),
    Border2   = Color3.fromRGB(70,70,92),
    Accent    = Color3.fromRGB(80,201,206),
    Accent2   = Color3.fromRGB(60,165,170),
    AccentDim = Color3.fromRGB(22,70,75),
    Text      = Color3.fromRGB(237,237,237),
    Text2     = Color3.fromRGB(160,160,160),
    Text3     = Color3.fromRGB(90,90,110),
    Red       = Color3.fromRGB(255,95,87),
    Yellow    = Color3.fromRGB(254,188,46),
    Green     = Color3.fromRGB(40,200,64),
    White     = Color3.new(1,1,1),
}

local function _new(cls, props, parent)
    local o = Instance.new(cls)
    for k,v in pairs(props) do
        pcall(function() o[k] = v end)
    end
    if parent then o.Parent = parent end
    return o
end

local function _tween(obj, props, dur, style, dir)
    if not obj or not obj.Parent then return end
    local ok, t = pcall(function()
        return TweenService:Create(obj,
            TweenInfo.new(
                dur   or 0.2,
                style or Enum.EasingStyle.Quad,
                dir   or Enum.EasingDirection.Out
            ), props)
    end)
    if ok and t then t:Play() end
    return t
end

local function _spring(obj, props, dur)
    return _tween(obj, props, dur or 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function _corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

local function _stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color           = color     or Color3.fromRGB(55,55,74)
    s.Thickness       = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent          = parent
    return s
end

local function _list(parent, padding, fd, ha, va)
    local l = Instance.new("UIListLayout")
    l.Padding             = UDim.new(0, padding or 4)
    l.FillDirection       = fd  or Enum.FillDirection.Vertical
    l.HorizontalAlignment = ha  or Enum.HorizontalAlignment.Left
    l.VerticalAlignment   = va  or Enum.VerticalAlignment.Top
    l.SortOrder           = Enum.SortOrder.LayoutOrder
    l.Parent              = parent
    return l
end

local function _padding(parent, t, b, l, r)
    local u = Instance.new("UIPadding")
    u.PaddingTop    = UDim.new(0, t or 4)
    u.PaddingBottom = UDim.new(0, b or 4)
    u.PaddingLeft   = UDim.new(0, l or 6)
    u.PaddingRight  = UDim.new(0, r or 6)
    u.Parent        = parent
    return u
end

local function _ripple(parent, x, y)
    pcall(function()
        if not parent or not parent.Parent then return end
        local abs = parent.AbsolutePosition
        local sz  = parent.AbsoluteSize
        local r = _new("Frame",{
            Size                 = UDim2.new(0,0,0,0),
            Position             = UDim2.new(0, x-abs.X, 0, y-abs.Y),
            AnchorPoint          = Vector2.new(.5,.5),
            BackgroundColor3     = Color3.new(1,1,1),
            BackgroundTransparency = 0.82,
            BorderSizePixel      = 0,
            ZIndex               = parent.ZIndex + 6,
        }, parent)
        _corner(r, 999)
        local mx = math.max(sz.X, sz.Y) * 2.4
        _tween(r,{ Size=UDim2.new(0,mx,0,mx), BackgroundTransparency=1 }, 0.5, Enum.EasingStyle.Quad)
        task.delay(0.51, function() pcall(function() r:Destroy() end) end)
    end)
end

function XenonUI:CreateWindow(options)
    options = options or {}

    local WIN = setmetatable({}, XenonUI)
    WIN._alive       = true
    WIN._connections = {}
    WIN._tabs        = {}
    WIN._activeTab   = nil
    WIN._kbReg       = {}
    WIN._kbBadges    = {}
    WIN._minimized   = false
    WIN._winSize     = "normal"
    WIN._guiVisible  = true
    WIN._cfgData     = {}
    WIN._cfgPath     = options.SaveKey or "xenon_cfg.json"
    WIN._toggleReg   = {}
    WIN._sliderReg   = {}
    WIN._dropdownReg = {}
    WIN._inputReg    = {}

    local T = XenonUI.DefaultTheme

    WIN._WIN_SIZES = {
        normal = Vector2.new(525, 375),
        large  = Vector2.new(680, 460),
        small  = Vector2.new(360, 290),
    }

    local function cfgSave()
        pcall(function()
            writefile(WIN._cfgPath, HttpService:JSONEncode(WIN._cfgData))
        end)
    end

    local function cfgLoad()
        if isfile and isfile(WIN._cfgPath) then
            local ok, r = pcall(function()
                return HttpService:JSONDecode(readfile(WIN._cfgPath))
            end)
            if ok and r then WIN._cfgData = r; return true end
        end
        return false
    end

    local function cfgApply()
        for _, e in ipairs(WIN._toggleReg) do
            local v = WIN._cfgData[e.cfgKey]
            if v ~= nil then
                pcall(function() e.ctrl:Set(v) end)
                if e.callback then task.defer(function() pcall(e.callback, v) end) end
            end
        end
        for _, e in ipairs(WIN._sliderReg) do
            local v = WIN._cfgData[e.cfgKey]
            if v ~= nil then
                pcall(function() e.ctrl:Set(v) end)
                if e.callback then task.defer(function() pcall(e.callback, v) end) end
            end
        end
        for _, e in ipairs(WIN._dropdownReg) do
            local v = WIN._cfgData[e.cfgKey]
            if v ~= nil then
                pcall(function() e.ctrl:Set(v) end)
                if e.callback then task.defer(function() pcall(e.callback, v) end) end
            end
        end
        for _, e in ipairs(WIN._inputReg) do
            local v = WIN._cfgData[e.cfgKey]
            if v ~= nil then
                pcall(function() e.box.Text = v end)
                if e.callback then task.defer(function() pcall(e.callback, v, false) end) end
            end
        end
        for id in pairs(WIN._kbReg) do
            local sn = WIN._cfgData["kb_"..id]
            if sn then
                local kc = Enum.KeyCode[sn]
                if kc then pcall(function() WIN:_setKB(id, kc) end) end
            end
        end
    end

    WIN._cfgSave  = cfgSave
    WIN._cfgLoad  = cfgLoad
    WIN._cfgApply = cfgApply
    WIN._set = function(k, v) WIN._cfgData[k] = v end
    WIN._get = function(k, d) return WIN._cfgData[k] ~= nil and WIN._cfgData[k] or d end

    cfgLoad()

    local title = options.Title or "Hub"
    local GUID  = "XenonUI_"..title

    pcall(function()
        for _, g in ipairs(LP:WaitForChild("PlayerGui"):GetChildren()) do
            if g.Name == GUID then g:Destroy() end
        end
        for _, g in ipairs(CoreGui:GetChildren()) do
            if g.Name == GUID then g:Destroy() end
        end
        local old = LP:FindFirstChild(GUID.."_TAG")
        if old then old:Destroy() end
    end)

    local tag = Instance.new("BoolValue")
    tag.Name   = GUID.."_TAG"
    tag.Value  = true
    tag.Parent = LP
    WIN._tag   = tag

    local SG = Instance.new("ScreenGui")
    SG.Name           = GUID
    SG.ResetOnSpawn   = false
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.DisplayOrder   = 2147483647
    SG.IgnoreGuiInset = true
    if not pcall(function() SG.Parent = CoreGui end) then
        SG.Parent = LP:WaitForChild("PlayerGui")
    end
    WIN._SG = SG

    local NC = _new("Frame",{
        Size                 = UDim2.new(0,255,1,0),
        Position             = UDim2.new(1,-271,0,0),
        BackgroundTransparency = 1,
        ZIndex               = 9000,
    }, SG)
    _list(NC, 6, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
    WIN._NC = NC

    local WH = _new("Frame",{
        Name                 = "WH",
        Size                 = UDim2.new(0,545,0,395),
        Position             = UDim2.new(.5,-272,.5,-197),
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
    }, SG)
    WIN._WH = WH

    local Win = _new("Frame",{
        Name             = "Win",
        Size             = UDim2.new(0,525,0,375),
        Position         = UDim2.new(0,10,0,10),
        BackgroundColor3 = T.BG,
        BorderSizePixel  = 0,
        ClipsDescendants = false,
    }, WH)
    _corner(Win, 10)
    local WinStroke = _stroke(Win, T.Border, 1)
    WIN._Win   = Win
    WIN._WinSt = WinStroke

    local WinClip = _new("Frame",{
        Name                 = "WinClip",
        Size                 = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        ClipsDescendants     = true,
        ZIndex               = 1,
    }, Win)
    _corner(WinClip, 10)
    WIN._WinClip = WinClip

    Win.Size     = UDim2.new(0,0,0,0)
    Win.Position = UDim2.new(0,272,0,197)
    task.defer(function()
        if WIN._alive then
            _spring(Win,{ Size=UDim2.new(0,525,0,375), Position=UDim2.new(0,10,0,10) }, 0.55)
        end
    end)

    local TB = _new("Frame",{
        Size             = UDim2.new(1,0,0,40),
        BackgroundColor3 = T.BG2,
        BorderSizePixel  = 0,
        ZIndex           = 4,
    }, WinClip)
    _corner(TB, 10)
    
    -- ФИКС РЕЗКИХ УГЛОВ: Увеличили размер перекрывающего фрейма на 1px, чтобы убрать микро-зазоры
    _new("Frame",{
        Size             = UDim2.new(1,1,.5,1),
        Position         = UDim2.new(0,0,.5,-1),
        BackgroundColor3 = T.BG2,
        BorderSizePixel  = 0,
        ZIndex           = 4,
    }, TB)
    
    _new("Frame",{
        Size             = UDim2.new(1,0,0,1),
        Position         = UDim2.new(0,0,1,-1),
        BackgroundColor3 = T.Border,
        BorderSizePixel  = 0,
        ZIndex           = 5,
    }, TB)
    WIN._TB = TB

    do
        local dragging, ds, sp = false, nil, nil
        local function conn(sig, fn)
            table.insert(WIN._connections, sig:Connect(fn))
        end
        conn(TB.InputBegan, function(inp)
            if not WIN._alive then return end
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            dragging = true
            ds = inp.Position
            sp = WH.Position
            _tween(WinStroke,{Color=T.Accent,Thickness=1.5},.15)
        end)
        conn(UserInputService.InputChanged, function(inp)
            if not WIN._alive or not dragging then return end
            if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local d = inp.Position - ds
            WH.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
        end)
        conn(UserInputService.InputEnded, function(inp)
            if not WIN._alive or not dragging then return end
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            dragging = false
            _tween(WinStroke,{Color=T.Border,Thickness=1},.25)
        end)
    end

    local BtnRow = _new("Frame",{
        Size                 = UDim2.new(0,72,0,16),
        Position             = UDim2.new(0,12,0.5,-8),
        BackgroundTransparency = 1,
        ZIndex               = 8,
    }, TB)
    _list(BtnRow, 6, Enum.FillDirection.Horizontal)

    local function makeTopBtn(color, icon, cb)
        local h = _new("Frame",{
            Size             = UDim2.new(0,16,0,16),
            BackgroundColor3 = color,
            BorderSizePixel  = 0,
            ZIndex           = 8,
        }, BtnRow)
        _corner(h, 8)
        local lbl = _new("TextLabel",{
            Size                 = UDim2.new(1,0,1,0),
            BackgroundTransparency = 1,
            Text                 = icon,
            TextColor3           = Color3.new(0,0,0),
            TextTransparency     = 1,
            Font                 = Enum.Font.GothamBold,
            TextSize             = 8,
            ZIndex               = 9,
        }, h)
        local btn = _new("TextButton",{
            Size                 = UDim2.new(1,0,1,0),
            BackgroundTransparency = 1,
            Text                 = "",
            ZIndex               = 10,
            AutoButtonColor      = false,
        }, h)
        btn.MouseEnter:Connect(function()
            _tween(h,{BackgroundColor3=color:Lerp(Color3.new(1,1,1),.3)},.12)
            _tween(lbl,{TextTransparency=0},.12)
            _spring(h,{Size=UDim2.new(0,19,0,19)},.28)
        end)
        btn.MouseLeave:Connect(function()
            _tween(h,{BackgroundColor3=color},.12)
            _tween(lbl,{TextTransparency=1},.12)
            _spring(h,{Size=UDim2.new(0,16,0,16)},.28)
        end)
        btn.MouseButton1Down:Connect(function()
            _tween(h,{Size=UDim2.new(0,12,0,12)},.08)
        end)
        btn.MouseButton1Click:Connect(function()
            _spring(h,{Size=UDim2.new(0,16,0,16)},.3)
            if cb then cb() end
        end)
        return h
    end

    makeTopBtn(T.Red, "x", function()
        _tween(Win,{BackgroundTransparency=1},.22)
        task.delay(.3, function() WIN:Destroy() end)
    end)

    -- ФИКС АНИМАЦИИ ЖЕЛТОЙ КНОПКИ (УЕЗЖАЕТ ВВЕРХ)
    makeTopBtn(T.Yellow, "-", function()
        if not WIN._alive then return end
        WIN._minimized = not WIN._minimized
        local sz = WIN._WIN_SIZES[WIN._winSize]
        if WIN._minimized then
            -- Контент плавно уходит вверх за счет обрезки маски (WinClip)
            _tween(WinClip, {Size = UDim2.new(1,0,0,40)}, 0.3, Enum.EasingStyle.Quad)
            -- Окно сжимается вслед за контентом
            _tween(Win, {Size=UDim2.new(0,sz.X,0,40)}, 0.3, Enum.EasingStyle.Quad)
            _tween(WH,  {Size=UDim2.new(0,sz.X+20,0,60)}, 0.3, Enum.EasingStyle.Quad)
        else
            -- Окно раскрывается
            _tween(Win, {Size=UDim2.new(0,sz.X,0,sz.Y)}, 0.25, Enum.EasingStyle.Quad)
            _tween(WH,  {Size=UDim2.new(0,sz.X+20,0,sz.Y+20)}, 0.25, Enum.EasingStyle.Quad)
            -- Контент плавно возвращается снизу
            task.delay(0.05, function()
                _spring(WinClip, {Size = UDim2.new(1,0,1,0)}, 0.35)
            end)
        end
    end)

    makeTopBtn(T.Green, "+", function()
        if not WIN._alive or WIN._minimized then return end
        if     WIN._winSize=="normal" then WIN:SetSize("large",true)
        elseif WIN._winSize=="large"  then WIN:SetSize("small",true)
        else                               WIN:SetSize("normal",true) end
    end)

    local TitleLabel = _new("TextLabel",{
        Size                 = UDim2.new(1,-240,1,0),
        Position             = UDim2.new(0,96,0,0),
        BackgroundTransparency = 1,
        Text                 = title,
        TextColor3           = T.Text,
        Font                 = Enum.Font.GothamBold,
        TextSize             = 12,
        TextXAlignment       = Enum.TextXAlignment.Left,
        TextTransparency     = 1,
        ZIndex               = 6,
    }, TB)
    task.delay(.3, function()
        if WIN._alive then _tween(TitleLabel,{TextTransparency=0},.4) end
    end)

    local StatBar = _new("Frame",{
        Size                 = UDim2.new(0,132,0,24),
        Position             = UDim2.new(1,-144,0,8),
        BackgroundColor3     = T.BG4,
        BackgroundTransparency = 0.25,
        BorderSizePixel      = 0,
        ZIndex               = 12,
    }, TB)
    _corner(StatBar,5); _stroke(StatBar,T.Border)
    _list(StatBar,0,Enum.FillDirection.Horizontal,Enum.HorizontalAlignment.Center,Enum.VerticalAlignment.Center)

    local function statLabel(txt, col)
        local f = _new("Frame",{ Size=UDim2.new(0.5,0,1,0), BackgroundTransparency=1, ZIndex=13 }, StatBar)
        return _new("TextLabel",{
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
            Text=txt, TextColor3=col or T.Text2,
            Font=Enum.Font.GothamBold, TextSize=10, ZIndex=14,
        }, f)
    end
    local FpsLabel  = statLabel("FPS: --",  T.Green)
    local PingLabel = statLabel("PING: --", T.Accent)
    _new("Frame",{
        Size=UDim2.new(0,1,0.55,0), Position=UDim2.new(.5,0,.22,0),
        BackgroundColor3=T.Border2, BorderSizePixel=0, ZIndex=14,
    }, StatBar)

    local fc, ft = 0, 0
    table.insert(WIN._connections, RunService.RenderStepped:Connect(function(dt)
        if not WIN._alive then return end
        fc=fc+1; ft=ft+dt
        if ft >= 0.5 then
            local fps = math.round(fc/ft); fc=0; ft=0
            pcall(function()
                FpsLabel.Text      = "FPS: "..fps
                FpsLabel.TextColor3 = fps>=55 and T.Green or fps>=30 and T.Yellow or T.Red
            end)
        end
    end))

    task.spawn(function()
        while WIN._alive and task.wait(1) do
            local ok, ping = pcall(function()
                return math.round(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            if ok and WIN._alive then
                pcall(function()
                    PingLabel.Text       = "PING: "..ping
                    PingLabel.TextColor3 = ping<80 and T.Green or ping<150 and T.Yellow or T.Red
                end)
            end
        end
    end)

    local Body = _new("Frame",{
        Size             = UDim2.new(1,0,1,-40),
        Position         = UDim2.new(0,0,0,40),
        BackgroundColor3 = T.BG,
        BorderSizePixel  = 0,
    }, WinClip)
    WIN._Body = Body

    local TabBar = _new("Frame",{
        Size             = UDim2.new(0,128,1,-44),
        BackgroundColor3 = T.BG2,
        BorderSizePixel  = 0,
        ZIndex           = 3,
    }, Body)
    _new("Frame",{
        Size=UDim2.new(0,1,1,0), Position=UDim2.new(1,-1,0,0),
        BackgroundColor3=T.Border, BorderSizePixel=0, ZIndex=4,
    }, TabBar)
    WIN._TabBar = TabBar

    local TabIndicator = _new("Frame",{
        Size             = UDim2.new(0,3,0,22),
        Position         = UDim2.new(0,0,0,6),
        BackgroundColor3 = T.Accent,
        BorderSizePixel  = 0,
        ZIndex           = 10,
    }, TabBar)
    _corner(TabIndicator,2)
    WIN._TabInd = TabIndicator

    local TabScroll = _new("ScrollingFrame",{
        Size                 = UDim2.new(1,-8,1,-10),
        Position             = UDim2.new(0,4,0,5),
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        ScrollBarThickness   = 2,
        ScrollBarImageColor3 = T.Border2,
        CanvasSize           = UDim2.new(0,0,0,0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        ZIndex               = 5,
    }, TabBar)
    _list(TabScroll,3)
    WIN._TabScroll = TabScroll

    local PI = _new("Frame",{
        Size             = UDim2.new(0,128,0,44),
        Position         = UDim2.new(0,0,1,-44),
        BackgroundColor3 = T.BG2,
        BorderSizePixel  = 0,
        ZIndex           = 5,
    }, Body)
    _new("Frame",{ Size=UDim2.new(1,0,0,1), BackgroundColor3=T.Border, BorderSizePixel=0, ZIndex=6 }, PI)
    _new("Frame",{ Size=UDim2.new(0,1,1,0), Position=UDim2.new(1,-1,0,0), BackgroundColor3=T.Border, BorderSizePixel=0, ZIndex=6 }, PI)

    local avatarHolder = _new("Frame",{
        Size=UDim2.new(0,30,0,30), Position=UDim2.new(0,7,0.5,-15),
        BackgroundColor3=T.BG4, BorderSizePixel=0, ZIndex=7,
    }, PI)
    _corner(avatarHolder,15); _stroke(avatarHolder,T.Accent,1.5)
    local avatarImg = _new("ImageLabel",{
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        Image="rbxassetid://0", ZIndex=8,
    }, avatarHolder)
    _corner(avatarImg,15)
    task.spawn(function()
        local ok, id = pcall(function()
            return Players:GetUserThumbnailAsync(LP.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        end)
        if ok and WIN._alive then pcall(function() avatarImg.Image = id end) end
    end)

    _new("TextLabel",{
        Size=UDim2.new(1,-46,0,14), Position=UDim2.new(0,44,0,8),
        BackgroundTransparency=1, Text=LP.DisplayName,
        TextColor3=T.Text, Font=Enum.Font.GothamBold, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=7,
    }, PI)
    _new("TextLabel",{
        Size=UDim2.new(1,-46,0,12), Position=UDim2.new(0,44,0,23),
        BackgroundTransparency=1, Text="@"..LP.Name,
        TextColor3=T.Text3, Font=Enum.Font.Gotham, TextSize=9,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=7,
    }, PI)

    local ContentArea = _new("Frame",{
        Size             = UDim2.new(1,-128,1,0),
        Position         = UDim2.new(0,128,0,0),
        BackgroundColor3 = T.BG,
        ClipsDescendants = true,
        BorderSizePixel  = 0,
    }, Body)
    WIN._CA = ContentArea

    local Picker = _new("Frame",{
        Size                 = UDim2.new(0,270,0,0),
        Position             = UDim2.new(.5,-135,.5,-100),
        BackgroundColor3     = T.BG2,
        BorderSizePixel      = 0,
        ClipsDescendants     = true,
        ZIndex               = 5000,
        Visible              = false,
    }, SG)
    _corner(Picker,8); _stroke(Picker,T.Border2,1)
    WIN._Picker = Picker

    local PKHead = _new("Frame",{
        Size=UDim2.new(1,0,0,30), BackgroundColor3=T.BG3,
        BorderSizePixel=0, ZIndex=5001,
    }, Picker)
    _corner(PKHead,8)
    
    -- ФИКС РЕЗКИХ УГЛОВ: Увеличили размер перекрывающего фрейма на 1px
    _new("Frame",{ Size=UDim2.new(1,1,.5,1), Position=UDim2.new(0,0,.5,-1), BackgroundColor3=T.BG3, BorderSizePixel=0, ZIndex=5001 }, PKHead)
    
    _new("Frame",{ Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1), BackgroundColor3=T.Border, BorderSizePixel=0, ZIndex=5002 }, PKHead)

    WIN._PKTitle = _new("TextLabel",{
        Size=UDim2.new(1,-34,1,0), Position=UDim2.new(0,10,0,0),
        BackgroundTransparency=1, Text="Keybind",
        TextColor3=T.Text, Font=Enum.Font.GothamBold,
        TextSize=11, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5002,
    }, PKHead)

    local PKCloseBtn = _new("TextButton",{
        Size=UDim2.new(0,22,0,22), Position=UDim2.new(1,-26,0.5,-11),
        BackgroundTransparency=1, Text="x",
        TextColor3=T.Text3, Font=Enum.Font.GothamBold,
        TextSize=12, ZIndex=5003, AutoButtonColor=false,
    }, PKHead)

    WIN._PKCurrent = _new("TextLabel",{
        Size=UDim2.new(1,-16,0,16), Position=UDim2.new(0,8,0,34),
        BackgroundTransparency=1, Text="",
        TextColor3=T.Accent, Font=Enum.Font.GothamBold,
        TextSize=10, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5002,
    }, Picker)

    local PKGrid = _new("ScrollingFrame",{
        Size=UDim2.new(1,-12,0,150), Position=UDim2.new(0,6,0,54),
        BackgroundTransparency=1, BorderSizePixel=0,
        ScrollBarThickness=2, ScrollBarImageColor3=T.Border2,
        ZIndex=5002, CanvasSize=UDim2.new(0,0,0,0),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,
    }, Picker)
    WIN._PKGrid = PKGrid

    local PKGridLayout = Instance.new("UIGridLayout")
    PKGridLayout.CellSize    = UDim2.new(0,46,0,24)
    PKGridLayout.CellPadding = UDim2.new(0,3,0,3)
    PKGridLayout.SortOrder   = Enum.SortOrder.LayoutOrder
    PKGridLayout.Parent      = PKGrid
    WIN._PKGridLayout = PKGridLayout

    WIN._PKHint = _new("TextLabel",{
        Size=UDim2.new(1,-16,0,18), Position=UDim2.new(0,8,0,210),
        BackgroundTransparency=1, Text="or press any key...",
        TextColor3=T.Text3, Font=Enum.Font.Gotham, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5002,
    }, Picker)

    WIN._pickerTarget = nil
    WIN._pickerListen = false
    WIN._pickerKBConn = nil

    PKCloseBtn.MouseButton1Click:Connect(function() WIN:_closePicker() end)

    local KEYS = {
        "None","F","G","H","J","K","L","Z","X","C","V","B","N","M",
        "Q","E","R","T","Y","U","I","O","P",
        "F1","F2","F3","F4","F5","F6","F7","F8",
        "Insert","Delete","Home","End",
        "LeftShift","LeftControl","LeftAlt",
        "One","Two","Three","Four","Five",
        "Six","Seven","Eight","Nine","Zero",
    }
    for _, kn in ipairs(KEYS) do
        local kb = _new("TextButton",{
            BackgroundColor3=T.BG4, BackgroundTransparency=0.1,
            BorderSizePixel=0, Text=kn, TextColor3=T.Text2,
            Font=Enum.Font.GothamBold, TextSize=9, ZIndex=5003,
            AutoButtonColor=false,
        }, PKGrid)
        _corner(kb,4); _stroke(kb,T.Border)
        kb.MouseEnter:Connect(function()
            _tween(kb,{BackgroundColor3=T.Border2,TextColor3=T.White},.1)
        end)
        kb.MouseLeave:Connect(function()
            pcall(function()
                local e   = WIN._pickerTarget and WIN._kbReg[WIN._pickerTarget]
                local sel = e and kb.Text == e.key.Name
                _tween(kb,{
                    BackgroundColor3 = sel and T.Accent or T.BG4,
                    TextColor3       = sel and T.BG     or T.Text2,
                },.1)
            end)
        end)
        kb.MouseButton1Click:Connect(function()
            if not WIN._pickerTarget then return end
            pcall(function()
                local kc = Enum.KeyCode[kn] or Enum.KeyCode.Unknown
                WIN:_setKB(WIN._pickerTarget, kc)
                local e = WIN._kbReg[WIN._pickerTarget]
                WIN._PKCurrent.Text = "Now: "..kc.Name
                WIN:Notify("Keybind",(e and e.label or "").." -> "..kn,"ok")
                for _, b in ipairs(PKGrid:GetChildren()) do
                    if b:IsA("TextButton") then
                        local s = b.Text == kn
                        _tween(b,{
                            BackgroundColor3 = s and T.Accent or T.BG4,
                            TextColor3       = s and T.BG     or T.Text2,
                        },.1)
                    end
                end
                task.delay(.25, function() WIN:_closePicker() end)
            end)
        end)
    end

    table.insert(WIN._connections, UserInputService.InputBegan:Connect(function(inp, gp)
        if not WIN._alive or gp then return end
        if inp.KeyCode == Enum.KeyCode.Insert then
            if WIN._guiVisible then WIN:Hide() else WIN:Show() end
        end
    end))

    task.spawn(function()
        while WIN._alive and task.wait(90) do
            if next(WIN._cfgData) then pcall(cfgSave) end
        end
    end)

    task.delay(0.15, function()
        if WIN._alive then pcall(cfgApply) end
    end)

    return WIN
end

function XenonUI:_addConn(sig, fn)
    local c = sig:Connect(fn)
    table.insert(self._connections, c)
    return c
end

function XenonUI:_closePicker()
    self._pickerListen = false
    if self._pickerKBConn then
        self._pickerKBConn:Disconnect()
        self._pickerKBConn = nil
    end
    _tween(self._Picker,{Size=UDim2.new(0,270,0,0)},.18,Enum.EasingStyle.Quad)
    task.delay(.19, function()
        pcall(function()
            if self._Picker and self._Picker.Parent then
                self._Picker.Visible = false
            end
        end)
    end)
end

function XenonUI:_openPicker(bindId, anchor)
    if not self._alive then return end
    self._pickerTarget = bindId
    self._pickerListen = true
    local T     = XenonUI.DefaultTheme
    local entry = self._kbReg[bindId]
    pcall(function()
        self._PKTitle.Text   = "Keybind - "..(entry and entry.label or bindId)
        self._PKCurrent.Text = "Now: "..(entry and entry.key.Name or "None")
    end)
    if anchor then
        pcall(function()
            local ap = anchor.AbsolutePosition
            local sg = self._SG.AbsoluteSize
            self._Picker.Position = UDim2.new(0,
                math.clamp(ap.X-5,0,sg.X-280), 0,
                math.clamp(ap.Y+anchor.AbsoluteSize.Y+4,0,sg.Y-290))
        end)
    end
    for _, b in ipairs(self._PKGrid:GetChildren()) do
        if b:IsA("TextButton") then
            pcall(function()
                local sel = entry and b.Text == entry.key.Name
                _tween(b,{
                    BackgroundColor3 = sel and T.Accent or T.BG4,
                    TextColor3       = sel and T.BG     or T.Text2,
                },.08)
            end)
        end
    end
    pcall(function()
        local gh    = self._PKGridLayout.AbsoluteContentSize.Y
        local total = 54 + math.min(gh,150) + 32
        self._PKHint.Position = UDim2.new(0,8,0, 54+math.min(gh,150)+8)
        self._Picker.Visible  = true
        self._Picker.Size     = UDim2.new(0,270,0,0)
        _spring(self._Picker,{Size=UDim2.new(0,270,0,total)},.35)
    end)
    if self._pickerKBConn then self._pickerKBConn:Disconnect() end
    self._pickerKBConn = UserInputService.InputBegan:Connect(function(inp, gp)
        if gp or not self._pickerListen or not self._alive then return end
        if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if inp.KeyCode == Enum.KeyCode.Escape then self:_closePicker(); return end
        pcall(function()
            self:_setKB(self._pickerTarget, inp.KeyCode)
            local e = self._kbReg[self._pickerTarget]
            self._PKCurrent.Text = "Now: "..inp.KeyCode.Name
            self:Notify("Keybind",(e and e.label or "").." -> "..inp.KeyCode.Name,"ok")
        end)
        self:_closePicker()
    end)
end

function XenonUI:_setKB(id, keyCode)
    if not self._kbReg[id] then return end
    self._kbReg[id].key = keyCode
    self._set("kb_"..id, keyCode.Name)
    if self._kbBadges[id] then
        pcall(function()
            self._kbBadges[id].Text = keyCode.Name=="Unknown" and "None" or keyCode.Name
        end)
    end
end

function XenonUI:Destroy()
    if not self._alive then return end
    self._alive = false
    for _, c in ipairs(self._connections) do pcall(function() c:Disconnect() end) end
    self._connections = {}
    pcall(function() self._tag:Destroy() end)
    pcall(self._cfgSave)
    task.delay(.3, function()
        pcall(function()
            if self._SG and self._SG.Parent then self._SG:Destroy() end
        end)
    end)
end

function XenonUI:Hide()
    if not self._alive then return end
    self._guiVisible = false
    _tween(self._Win,{BackgroundTransparency=1},.2)
    task.delay(.22, function()
        pcall(function()
            if self._WH and self._WH.Parent then self._WH.Visible = false end
        end)
    end)
end

function XenonUI:Show()
    if not self._alive then return end
    self._guiVisible = true
    pcall(function()
        self._WH.Visible               = true
        self._Win.BackgroundTransparency = 0
    end)
end

function XenonUI:SetSize(sizeName, animate)
    if not self._alive then return end
    self._winSize = sizeName
    local sz = self._WIN_SIZES[sizeName]
    if animate then
        _spring(self._Win,{Size=UDim2.new(0,sz.X,0,sz.Y)},.45)
        _spring(self._WH, {Size=UDim2.new(0,sz.X+20,0,sz.Y+20)},.45)
    else
        pcall(function()
            self._Win.Size = UDim2.new(0,sz.X,0,sz.Y)
            self._WH.Size  = UDim2.new(0,sz.X+20,0,sz.Y+20)
        end)
    end
end

function XenonUI:Notify(title, msg, ntype)
    if not self._alive then return end
    local T   = XenonUI.DefaultTheme
    local col = ntype=="error" and T.Red
             or ntype=="warn"  and T.Yellow
             or ntype=="ok"    and T.Green
             or T.Accent
    pcall(function()
        local nf = _new("Frame",{
            Size=UDim2.new(1,0,0,0),
            BackgroundColor3=T.BG2, BorderSizePixel=0,
            ClipsDescendants=true, ZIndex=9001,
        }, self._NC)
        _corner(nf,6); _stroke(nf,T.Border2)
        _new("Frame",{ Size=UDim2.new(0,3,1,0), BackgroundColor3=col, BorderSizePixel=0, ZIndex=9003 }, nf)
        _new("TextLabel",{
            Size=UDim2.new(1,-32,0,20), Position=UDim2.new(0,12,0,5),
            BackgroundTransparency=1, Text=title, TextColor3=T.Text,
            Font=Enum.Font.GothamBold, TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left, ZIndex=9003,
        }, nf)
        _new("TextLabel",{
            Size=UDim2.new(1,-32,0,28), Position=UDim2.new(0,12,0,23),
            BackgroundTransparency=1, Text=msg, TextColor3=T.Text2,
            Font=Enum.Font.Gotham, TextSize=10,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextWrapped=true, ZIndex=9003,
        }, nf)
        local pg  = _new("Frame",{ Size=UDim2.new(1,0,0,2), Position=UDim2.new(0,0,1,-2), BackgroundColor3=T.BG4, BorderSizePixel=0, ZIndex=9004 }, nf)
        local pgF = _new("Frame",{ Size=UDim2.new(1,0,1,0), BackgroundColor3=col, BorderSizePixel=0, ZIndex=9005 }, pg)
        local xcb = _new("TextButton",{
            Size=UDim2.new(0,20,0,20), Position=UDim2.new(1,-24,0,4),
            BackgroundTransparency=1, Text="x", TextColor3=T.Text3,
            Font=Enum.Font.GothamBold, TextSize=10, ZIndex=9005, AutoButtonColor=false,
        }, nf)
        _spring(nf,{Size=UDim2.new(1,0,0,56)},.3)
        _tween(pgF,{Size=UDim2.new(0,0,1,0)},4,Enum.EasingStyle.Linear)
        local function dismiss()
            _tween(nf,{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1},.22)
            task.delay(.23, function() pcall(function() nf:Destroy() end) end)
        end
        xcb.MouseButton1Click:Connect(dismiss)
        task.delay(4, dismiss)
    end)
end

function XenonUI:SaveConfig()
    local ok = pcall(self._cfgSave)
    self:Notify("Config", ok and "Saved!" or "Error saving", ok and "ok" or "error")
end

function XenonUI:LoadConfig()
    local ok = self._cfgLoad()
    if ok then
        pcall(self._cfgApply)
        self:Notify("Config","Loaded & Applied!","ok")
    else
        self:Notify("Config","File not found","warn")
    end
end

function XenonUI:ResetConfig()
    self._cfgData = {}
    for _, e in ipairs(self._toggleReg) do
        pcall(function() e.ctrl:Set(false) end)
        if e.callback then task.defer(function() pcall(e.callback,false) end) end
    end
    self:Notify("Config","Reset.","warn")
end

function XenonUI:SelectTab(tab)
    if not self._alive or not tab then return end
    local T = XenonUI.DefaultTheme
    for _, t in ipairs(self._tabs) do
        pcall(function()
            if t.Panel and t.Panel.Parent then t.Panel.Visible = false end
            if t._btn  and t._btn.Parent  then
                t._btn.BackgroundTransparency = 1
                t._btn.BackgroundColor3       = T.BG3
                t._btn.TextColor3             = T.Text2
            end
        end)
    end
    self._activeTab = tab
    pcall(function()
        if tab.Panel and tab.Panel.Parent then
            tab.Panel.Visible   = true
            tab.Panel.Position  = UDim2.new(0,0,0,0)
        end
        if tab._btn and tab._btn.Parent then
            tab._btn.BackgroundTransparency = 0
            tab._btn.BackgroundColor3       = T.BG4
            tab._btn.TextColor3             = T.Accent
        end
    end)
    task.defer(function()
        if not self._alive then return end
        pcall(function()
            if not tab._btn   or not tab._btn.Parent   then return end
            if not self._TabBar or not self._TabBar.Parent then return end
            local bp = tab._btn.AbsolutePosition
            local tp = self._TabBar.AbsolutePosition
            _tween(self._TabInd,{
                Position = UDim2.new(0,0,0, bp.Y-tp.Y+4),
                Size     = UDim2.new(0,3,0,22),
            },.3,Enum.EasingStyle.Back)
        end)
    end)
end

function XenonUI:CreateTab(name)
    local T       = XenonUI.DefaultTheme
    local WIN     = self
    local isFirst = #self._tabs == 0

    local btn = _new("TextButton",{
        Size=UDim2.new(1,0,0,30), BackgroundColor3=T.BG3,
        BackgroundTransparency=1, Text=name, TextColor3=T.Text2,
        Font=Enum.Font.GothamBold, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,
        ZIndex=5, AutoButtonColor=false,
    }, self._TabScroll)
    _corner(btn,5); _padding(btn,0,0,12,4)

    local panel = _new("Frame",{
        Name="P_"..name, Size=UDim2.new(1,0,1,0),
        BackgroundTransparency=1, Visible=false, ZIndex=2,
    }, self._CA)

    local colL = _new("ScrollingFrame",{
        Size=UDim2.new(.5,-2,1,0), BackgroundTransparency=1, BorderSizePixel=0,
        ScrollBarThickness=2, ScrollBarImageColor3=T.Border2,
        CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
    }, panel)
    _list(colL,5); _padding(colL,6,6,4,2)

    local colR = _new("ScrollingFrame",{
        Size=UDim2.new(.5,-2,1,0), Position=UDim2.new(.5,2,0,0),
        BackgroundTransparency=1, BorderSizePixel=0,
        ScrollBarThickness=2, ScrollBarImageColor3=T.Border2,
        CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
    }, panel)
    _list(colR,5); _padding(colR,6,6,2,4)

    local tab = { _btn=btn, Panel=panel, Left=colL, Right=colR, _lib=WIN, Name=name }
    table.insert(self._tabs, tab)

    btn.MouseButton1Click:Connect(function()
        if WIN._alive then WIN:SelectTab(tab) end
    end)
    btn.MouseEnter:Connect(function()
        if not WIN._alive or WIN._activeTab==tab then return end
        pcall(function() btn.TextColor3=T.Text; btn.BackgroundTransparency=0.72 end)
    end)
    btn.MouseLeave:Connect(function()
        if not WIN._alive or WIN._activeTab==tab then return end
        pcall(function() btn.TextColor3=T.Text2; btn.BackgroundTransparency=1 end)
    end)

    if isFirst then
        task.delay(0.05, function()
            if WIN._alive then WIN:SelectTab(tab) end
        end)
    end

    function tab:CreateSection(t,o)      return WIN:_makeSection(colL,t,o) end
    function tab:CreateSectionRight(t,o) return WIN:_makeSection(colR,t,o) end
    function tab:AddToggle(a,b,c,d)           return WIN:_makeToggle(colL,a,b,c,d) end
    function tab:AddSlider(a,b,c,d,e,f)       return WIN:_makeSlider(colL,a,b,c,d,e,f) end
    function tab:AddButton(a,b)               return WIN:_makeButton(colL,a,b) end
    function tab:AddDropdown(a,b,c,d,e)       return WIN:_makeDropdown(colL,a,b,c,d,e) end
    function tab:AddInput(a,b,c)              return WIN:_makeInput(colL,a,b,c) end
    function tab:AddKeybind(a,b,c,d)          return WIN:_makeKeybind(colL,a,b,c,d) end

    return tab
end

function XenonUI:_makeSection(panel, title, startOpen)
    local T    = XenonUI.DefaultTheme
    local WIN  = self
    local open = startOpen ~= false

    local sec = _new("Frame",{
        Size=UDim2.new(1,0,0,30), BackgroundColor3=T.BG2,
        BorderSizePixel=0, ClipsDescendants=true,
    }, panel)
    _corner(sec,6)
    local secStroke = _stroke(sec,T.Border)

    local head = _new("TextButton",{
        Size=UDim2.new(1,0,0,30), BackgroundTransparency=1,
        Text="", ZIndex=4, AutoButtonColor=false,
    }, sec)

    local dot = _new("Frame",{
        Size=UDim2.new(0,5,0,5), Position=UDim2.new(0,9,0.5,-2.5),
        BackgroundColor3=T.Accent, BorderSizePixel=0, ZIndex=5,
    }, head)
    _corner(dot,3)

    _new("TextLabel",{
        Size=UDim2.new(1,-44,1,0), Position=UDim2.new(0,22,0,0),
        BackgroundTransparency=1, Text=title, TextColor3=T.Text,
        Font=Enum.Font.GothamBold, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
    }, head)

    local chev = _new("TextLabel",{
        Size=UDim2.new(0,18,0,18), Position=UDim2.new(1,-24,0.5,-9),

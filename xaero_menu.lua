-- ══════════════════════════════════════════════════
--  XAERO GLASS MENU v6
--  Glass menu + ESP (highlight/tracer/name/health) + Hitbox expander
--  Side buttons (outside menu): top = HITBOX, bottom = ESP
--  RightShift = show/hide menu
-- ══════════════════════════════════════════════════

-- ── CONFIG ──────────────────────────────────────
local kMenuSize     = UDim2.fromOffset(470, 400)
local kGlass        = 0.42
local kBlurSize     = 8          -- 0 = blur kapali
local kAccent       = Color3.fromRGB(150, 120, 255)
local kBase         = Color3.fromRGB(16, 16, 22)
local kTitle        = "XAERO"
local kToggleKey    = Enum.KeyCode.RightShift
local kTweenTime    = 0.28
local kHbSliderMax  = 60         -- slider siniri
local kHbHardMax    = 1000       -- kutuya elle yazilabilecek ust sinir
local kFillTransp   = 0.6
local kTracerThick  = 2
local kMaxDist      = 3000

-- ── SERVICES ────────────────────────────────────
local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")
local TweenSvc   = game:GetService("TweenService")
local Lighting   = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local HttpSvc    = game:GetService("HttpService")

local lp  = Players.LocalPlayer
local cam = workspace.CurrentCamera

-- onceki kopyayi kapat
local env = (getgenv and getgenv()) or _G
if env.__xaero_cleanup then pcall(env.__xaero_cleanup) end

local function rname() return HttpSvc:GenerateGUID(false) end

local parent = (gethui and gethui()) or lp:WaitForChild("PlayerGui")

local conns = {}
local function bind(c) conns[#conns + 1] = c; return c end
local function tween(o, t, props, style)
    local tw = TweenSvc:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    tw:Play(); return tw
end
local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = o; return c end

-- ── STATE ───────────────────────────────────────
local cfg = {
    esp = false, tracers = false, names = false, health = false, teamCheck = false,
    espHue = 0.75,
    hitbox = false, hbSize = 10, hbTransp = 0.6, hbShow = true, hbTeamCheck = false,
    hbHue = 0.0,
}
local function hsv(h) return Color3.fromHSV(h, 0.8, 1) end
local setters = {}   -- [key] = function(bool)

-- ── ROOT ────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = rname()
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent

local blur = Instance.new("BlurEffect")
blur.Name = rname()
blur.Size = 0
blur.Parent = Lighting

local worldLayer = Instance.new("Folder")      -- highlight'lar burada, karakterin icine girmez
worldLayer.Name = rname()
worldLayer.Parent = gui

local screenLayer = Instance.new("Folder")
screenLayer.Name = rname()
screenLayer.Parent = gui

-- ── MENU ────────────────────────────────────────
local menu = Instance.new("CanvasGroup")
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = UDim2.fromScale(0.5, 0.5)
menu.Size = kMenuSize
menu.BackgroundTransparency = 1
menu.GroupTransparency = 1
menu.Parent = gui
corner(menu, 18)

local scale = Instance.new("UIScale"); scale.Scale = 0.92; scale.Parent = menu

local glass = Instance.new("Frame")
glass.Size = UDim2.fromScale(1, 1)
glass.BackgroundColor3 = kBase
glass.BackgroundTransparency = kGlass
glass.BorderSizePixel = 0
glass.Parent = menu
do
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 140, 190))
    g.Rotation = 60; g.Parent = glass

    local gloss = Instance.new("Frame")
    gloss.Size = UDim2.new(1, 0, 0.4, 0)
    gloss.BackgroundColor3 = Color3.new(1, 1, 1)
    gloss.BorderSizePixel = 0
    gloss.Parent = glass
    local gg = Instance.new("UIGradient")
    gg.Rotation = 90
    gg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 1)})
    gg.Parent = gloss
end

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.new(1, 1, 1); stroke.Thickness = 1.2; stroke.Transparency = 0.75
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = glass

local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 42)
bar.BackgroundTransparency = 1
bar.Parent = menu

local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(8, 8); dot.Position = UDim2.fromOffset(18, 17)
dot.BackgroundColor3 = kAccent; dot.BorderSizePixel = 0; dot.Parent = bar
corner(dot, 8)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(34, 0); title.Size = UDim2.new(1, -90, 1, 0)
title.Text = kTitle
title.TextColor3 = Color3.fromRGB(235, 235, 245)
title.TextSize = 14; title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bar

local closeX = Instance.new("TextButton")
closeX.AnchorPoint = Vector2.new(1, 0.5)
closeX.Position = UDim2.new(1, -12, 0.5, 0)
closeX.Size = UDim2.fromOffset(28, 28)
closeX.BackgroundColor3 = Color3.new(1, 1, 1)
closeX.BackgroundTransparency = 0.92
closeX.Text = "✕"; closeX.TextColor3 = Color3.new(1, 1, 1)
closeX.TextSize = 13; closeX.Font = Enum.Font.GothamBold
closeX.AutoButtonColor = false; closeX.BorderSizePixel = 0
closeX.Parent = bar
corner(closeX, 8)

local divider = Instance.new("Frame")
divider.Position = UDim2.new(0, 14, 0, 42); divider.Size = UDim2.new(1, -28, 0, 1)
divider.BackgroundColor3 = Color3.new(1, 1, 1); divider.BackgroundTransparency = 0.88
divider.BorderSizePixel = 0; divider.Parent = menu

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(14, 52)
content.Size = UDim2.new(1, -28, 1, -64)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = kAccent
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.Parent = menu
do
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 8); l.SortOrder = Enum.SortOrder.LayoutOrder; l.Parent = content
    local pad = Instance.new("UIPadding"); pad.PaddingRight = UDim.new(0, 6); pad.Parent = content
end

-- drag (baslik cubugu)
do
    local dragging, dragStart, startPos
    bind(bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, menu.Position
        end
    end))
    bind(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            menu.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    bind(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
end

-- ── UI WIDGETS ──────────────────────────────────
local order = 0
local function nextOrder() order += 1; return order end

local function section(text)
    local l = Instance.new("TextLabel")
    l.LayoutOrder = nextOrder()
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.Text = string.upper(text)
    l.TextColor3 = kAccent
    l.TextSize = 11; l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = content
end

local function toggleRow(text, key)
    local row = Instance.new("TextButton")
    row.LayoutOrder = nextOrder()
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.new(1, 1, 1); row.BackgroundTransparency = 0.92
    row.AutoButtonColor = false; row.Text = ""; row.BorderSizePixel = 0
    row.Parent = content
    corner(row, 10)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.fromOffset(12, 0); lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Text = text; lbl.TextColor3 = Color3.fromRGB(235, 235, 245)
    lbl.TextSize = 13; lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(1, 0.5); track.Position = UDim2.new(1, -10, 0.5, 0)
    track.Size = UDim2.fromOffset(38, 20); track.BorderSizePixel = 0
    track.BackgroundColor3 = Color3.fromRGB(60, 60, 75); track.Parent = row
    corner(track, 20)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5); knob.Position = UDim2.new(0, 3, 0.5, 0)
    knob.Size = UDim2.fromOffset(14, 14); knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0; knob.Parent = track
    corner(knob, 14)

    local function refresh()
        local on = cfg[key]
        tween(track, 0.18, {BackgroundColor3 = on and kAccent or Color3.fromRGB(60, 60, 75)})
        tween(knob, 0.18, {Position = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)})
        if setters[key .. "_ui"] then setters[key .. "_ui"](on) end
    end
    setters[key] = function(v) cfg[key] = v; refresh() end
    bind(row.MouseButton1Click:Connect(function() setters[key](not cfg[key]) end))
    refresh()
end

-- opts: min, max, hard, fmt, rainbow, step
local function sliderRow(text, key, opts)
    local min, max = opts.min, opts.max
    local row = Instance.new("Frame")
    row.LayoutOrder = nextOrder()
    row.Size = UDim2.new(1, 0, 0, 46)
    row.BackgroundTransparency = 1
    row.Parent = content

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.fromOffset(2, 0); lbl.Size = UDim2.new(1, -80, 0, 18)
    lbl.Text = text; lbl.TextColor3 = Color3.fromRGB(235, 235, 245)
    lbl.TextSize = 13; lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row

    local box, preview
    if opts.rainbow then
        preview = Instance.new("Frame")
        preview.AnchorPoint = Vector2.new(1, 0); preview.Position = UDim2.new(1, 0, 0, 0)
        preview.Size = UDim2.fromOffset(24, 16); preview.BorderSizePixel = 0; preview.Parent = row
        corner(preview, 5)
    else
        box = Instance.new("TextBox")
        box.AnchorPoint = Vector2.new(1, 0); box.Position = UDim2.new(1, 0, 0, 0)
        box.Size = UDim2.fromOffset(64, 18)
        box.BackgroundColor3 = Color3.new(1, 1, 1); box.BackgroundTransparency = 0.9
        box.TextColor3 = Color3.new(1, 1, 1); box.TextSize = 12; box.Font = Enum.Font.GothamMedium
        box.ClearTextOnFocus = false; box.BorderSizePixel = 0; box.Parent = row
        corner(box, 6)
    end

    local track = Instance.new("TextButton")
    track.Position = UDim2.fromOffset(0, 26); track.Size = UDim2.new(1, 0, 0, 12)
    track.Text = ""; track.AutoButtonColor = false; track.BorderSizePixel = 0
    track.BackgroundColor3 = opts.rainbow and Color3.new(1, 1, 1) or Color3.fromRGB(60, 60, 75)
    track.Parent = row
    corner(track, 12)

    local fill
    if opts.rainbow then
        local seq = {}
        for i = 0, 6 do seq[#seq + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.8, 1)) end
        local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(seq); g.Parent = track
    else
        fill = Instance.new("Frame")
        fill.BackgroundColor3 = kAccent; fill.BorderSizePixel = 0
        fill.Size = UDim2.fromScale(0, 1); fill.Parent = track
        corner(fill, 12)
    end

    local thumb = Instance.new("Frame")
    thumb.AnchorPoint = Vector2.new(0.5, 0.5); thumb.Size = UDim2.fromOffset(6, 18)
    thumb.BackgroundColor3 = Color3.new(1, 1, 1); thumb.BorderSizePixel = 0
    thumb.Parent = track
    corner(thumb, 6)
    local ts = Instance.new("UIStroke"); ts.Color = Color3.new(0, 0, 0); ts.Transparency = 0.5; ts.Parent = thumb

    local function apply()
        local v = cfg[key]
        local a = math.clamp((v - min) / (max - min), 0, 1)
        thumb.Position = UDim2.new(a, 0, 0.5, 0)
        if fill then fill.Size = UDim2.fromScale(a, 1) end
        if preview then preview.BackgroundColor3 = hsv(v) end
        if box then box.Text = (opts.fmt or "%d"):format(v) end
    end
    apply()

    local sliding = false
    local function setFrom(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local v = min + (max - min) * a
        if opts.step then v = math.floor(v / opts.step + 0.5) * opts.step end
        cfg[key] = v; apply()
    end
    bind(track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            sliding = true; setFrom(i.Position.X)
        end
    end))
    bind(UIS.InputChanged:Connect(function(i)
        if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            setFrom(i.Position.X)
        end
    end))
    bind(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = false end
    end))
    if box then
        bind(box.FocusLost:Connect(function()
            local n = tonumber(box.Text)
            if n then cfg[key] = math.clamp(n, min, opts.hard or max) end
            apply()
        end))
    end
end

-- ── MENU CONTENT ────────────────────────────────
section("Hitbox")
toggleRow("Hitbox genişletici", "hitbox")
sliderRow("Hitbox boyutu (kutuya elle yaz)", "hbSize", {min = 2, max = kHbSliderMax, hard = kHbHardMax, fmt = "%.0f"})
toggleRow("Hitbox'ı göster", "hbShow")
sliderRow("Hitbox şeffaflığı", "hbTransp", {min = 0, max = 1, fmt = "%.2f"})
sliderRow("Hitbox rengi", "hbHue", {min = 0, max = 1, rainbow = true})
toggleRow("Hitbox: takımı atla", "hbTeamCheck")

section("ESP")
toggleRow("ESP (duvar arkası)", "esp")
toggleRow("Tracers", "tracers")
toggleRow("İsim + mesafe", "names")
toggleRow("Can göstergesi", "health")
toggleRow("ESP: takımı gizle", "teamCheck")
sliderRow("ESP rengi", "espHue", {min = 0, max = 1, rainbow = true})

-- ── HITBOX CORE ─────────────────────────────────
local orig = setmetatable({}, {__mode = "k"})   -- [part] = {Size, Transparency, CanCollide, Color, Material}

local function restore(part)
    local o = orig[part]
    if o and part.Parent then
        pcall(function()
            part.Size = o.Size
            part.Transparency = o.Transparency
            part.CanCollide = o.CanCollide
            part.Color = o.Color
            part.Material = o.Material
        end)
    end
    orig[part] = nil
end

local function restoreAll()
    for part in pairs(orig) do restore(part) end
end

local function isTeammate(p)
    return p.Team ~= nil and p.Team == lp.Team
end

bind(RunService.Heartbeat:Connect(function()
    local s = cfg.hbSize
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            local char = p.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if root then
                local active = cfg.hitbox and hum and hum.Health > 0 and not (cfg.hbTeamCheck and isTeammate(p))
                if active then
                    if not orig[root] then
                        orig[root] = {Size = root.Size, Transparency = root.Transparency, CanCollide = root.CanCollide,
                                      Color = root.Color, Material = root.Material}
                    end
                    root.Size = Vector3.new(s, s, s)
                    root.CanCollide = false
                    root.Transparency = cfg.hbShow and cfg.hbTransp or 1
                    root.Color = hsv(cfg.hbHue)
                    root.Material = Enum.Material.Neon
                elseif orig[root] then
                    restore(root)
                end
            end
        end
    end
end))

-- ── ESP CORE ────────────────────────────────────
local objs = {}   -- [player] = {hl, line, name, hpBg, hpFill}

local function mkLabel()
    local t = Instance.new("TextLabel")
    t.AnchorPoint = Vector2.new(0.5, 1)
    t.Size = UDim2.fromOffset(180, 16)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold; t.TextSize = 12
    t.TextStrokeTransparency = 0.4
    t.Visible = false; t.Parent = screenLayer
    return t
end

local function build(p)
    if p == lp or objs[p] then return end
    local o = {}
    objs[p] = o

    o.line = Instance.new("Frame")
    o.line.AnchorPoint = Vector2.new(0.5, 0.5); o.line.BorderSizePixel = 0
    o.line.Visible = false; o.line.Parent = screenLayer

    o.name = mkLabel()

    o.hpBg = Instance.new("Frame")
    o.hpBg.AnchorPoint = Vector2.new(0.5, 0)
    o.hpBg.Size = UDim2.fromOffset(46, 4)
    o.hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    o.hpBg.BorderSizePixel = 0; o.hpBg.Visible = false; o.hpBg.Parent = screenLayer
    o.hpFill = Instance.new("Frame")
    o.hpFill.BorderSizePixel = 0; o.hpFill.Size = UDim2.fromScale(1, 1); o.hpFill.Parent = o.hpBg

    local hl = Instance.new("Highlight")        -- parent: gui klasoru, karakter icine dokunmaz
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = kFillTransp; hl.OutlineTransparency = 0
    hl.Enabled = false; hl.Parent = worldLayer
    o.hl = hl
end

local function drop(p)
    local o = objs[p]; if not o then return end
    for _, k in ipairs({"hl", "line", "name", "hpBg"}) do if o[k] then o[k]:Destroy() end end
    objs[p] = nil
end

for _, p in ipairs(Players:GetPlayers()) do build(p) end
bind(Players.PlayerAdded:Connect(build))
bind(Players.PlayerRemoving:Connect(function(p)
    drop(p)
    local char = p.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then orig[root] = nil end
end))

bind(RunService.RenderStepped:Connect(function()
    cam = workspace.CurrentCamera
    local vs = cam.ViewportSize
    local origin = Vector2.new(vs.X / 2, vs.Y)
    local col = hsv(cfg.espHue)
    local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")

    for p, o in pairs(objs) do
        local char = p.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local dist = (root and myRoot) and (root.Position - myRoot.Position).Magnitude or 0
        local hide = not root or not hum or hum.Health <= 0 or dist > kMaxDist
            or (cfg.teamCheck and isTeammate(p))

        o.hl.Adornee = (not hide) and char or nil
        o.hl.Enabled = cfg.esp and not hide
        o.hl.FillColor = col; o.hl.OutlineColor = col

        local sx, sy, onScreen = 0, 0, false
        if not hide then
            local v, on = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
            sx, sy, onScreen = v.X, v.Y, on and v.Z > 0
        end

        o.name.Visible = cfg.names and onScreen
        if o.name.Visible then
            o.name.TextColor3 = col
            o.name.Position = UDim2.fromOffset(sx, sy)
            o.name.Text = ("%s [%dm]"):format(p.DisplayName, dist)
        end

        o.hpBg.Visible = cfg.health and onScreen
        if o.hpBg.Visible then
            local f = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            o.hpBg.Position = UDim2.fromOffset(sx, sy + 2)
            o.hpFill.Size = UDim2.fromScale(f, 1)
            o.hpFill.BackgroundColor3 = Color3.fromHSV(f * 0.33, 0.9, 1)
        end

        if cfg.tracers and onScreen then
            local v = cam:WorldToViewportPoint(root.Position)
            local target = Vector2.new(v.X, v.Y)
            local d = target - origin
            o.line.Size = UDim2.fromOffset(d.Magnitude, kTracerThick)
            o.line.Position = UDim2.fromOffset((origin.X + target.X) / 2, (origin.Y + target.Y) / 2)
            o.line.Rotation = math.deg(math.atan2(d.Y, d.X))
            o.line.BackgroundColor3 = col
            o.line.Visible = true
        else
            o.line.Visible = false
        end
    end
end))

-- ── SIDE BUTTONS (menu disinda) ─────────────────
local function sideButton(yOffset, text, key)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, 70, 0.5, yOffset)
    b.Size = UDim2.fromOffset(56, 56)
    b.BackgroundColor3 = kBase; b.BackgroundTransparency = kGlass
    b.AutoButtonColor = false
    b.Text = text; b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 13; b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0; b.Parent = gui
    corner(b, 16)

    local s = Instance.new("UIStroke"); s.Color = Color3.new(1, 1, 1); s.Transparency = 0.78; s.Thickness = 1.2; s.Parent = b
    local sc = Instance.new("UIScale"); sc.Parent = b

    local function paint(on)
        tween(b, 0.18, {BackgroundColor3 = on and kAccent or kBase, BackgroundTransparency = on and 0.2 or kGlass})
    end
    setters[key .. "_ui"] = paint
    paint(cfg[key])

    bind(b.MouseEnter:Connect(function() tween(sc, 0.15, {Scale = 1.08}); tween(s, 0.15, {Transparency = 0.3}) end))
    bind(b.MouseLeave:Connect(function() tween(sc, 0.15, {Scale = 1}); tween(s, 0.15, {Transparency = 0.78}) end))
    bind(b.MouseButton1Down:Connect(function() tween(sc, 0.08, {Scale = 0.92}) end))
    bind(b.MouseButton1Up:Connect(function() tween(sc, 0.12, {Scale = 1.08}) end))
    bind(b.MouseButton1Click:Connect(function() setters[key](not cfg[key]) end))
    return b
end

local btnHitbox = sideButton(-34, "HITBOX", "hitbox")
local btnEsp    = sideButton(34,  "ESP",    "esp")
setters.hitbox(cfg.hitbox); setters.esp(cfg.esp)   -- ui_paint baglantisini tazele

-- ── OPEN / CLOSE / DESTROY ──────────────────────
local open = false
local function setOpen(state)
    open = state
    if state then menu.Visible = true end
    tween(menu, kTweenTime, {GroupTransparency = state and 0 or 1})
    tween(scale, kTweenTime, {Scale = state and 1 or 0.92}, state and Enum.EasingStyle.Back or Enum.EasingStyle.Quint)
    tween(blur, kTweenTime, {Size = state and kBlurSize or 0})
    if not state then
        task.delay(kTweenTime, function() if not open then menu.Visible = false end end)
    end
end

local destroyed = false
local function destroy()
    if destroyed then return end
    destroyed = true
    cfg.hitbox = false
    restoreAll()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for p in pairs(objs) do drop(p) end
    pcall(function() blur:Destroy() end)
    pcall(function() gui:Destroy() end)
    env.__xaero_cleanup = nil
end
env.__xaero_cleanup = destroy

bind(closeX.MouseButton1Click:Connect(function()
    setOpen(false)
    task.delay(kTweenTime + 0.05, destroy)
end))
bind(UIS.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == kToggleKey then setOpen(not open) end
end))

-- intro
tween(btnHitbox, 0.45, {Position = UDim2.new(1, -16, 0.5, -34)})
task.delay(0.08, function() tween(btnEsp, 0.45, {Position = UDim2.new(1, -16, 0.5, 34)}) end)
setOpen(true)

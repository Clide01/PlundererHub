local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local PlundererUI = {}
PlundererUI.__index = PlundererUI
PlundererUI.VERSION = "1.0.0"

local C = {
    bg      = Color3.fromRGB(10, 12, 18),
    bgCard  = Color3.fromRGB(20, 23, 33),
    bgHov   = Color3.fromRGB(30, 35, 48),
    border  = Color3.fromRGB(60, 68, 90),
    primary = Color3.fromRGB(96, 255, 168),
    text    = Color3.fromRGB(245, 248, 255),
    muted   = Color3.fromRGB(150, 160, 180),
    danger  = Color3.fromRGB(255, 92, 92),
    trackOff= Color3.fromRGB(45, 52, 70),
    trackOn = Color3.fromRGB(70, 220, 140),
    knob    = Color3.fromRGB(255, 255, 255),
}

local FB = Enum.Font.GothamBold
local FM = Enum.Font.GothamMedium

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

local function stroke(p, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color = color or C.border
    s.Thickness = thick or 1
    s.Transparency = trans or 0.3
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function padding(p, t, b, l, r)
    local u = Instance.new("UIPadding")
    u.PaddingTop = UDim.new(0, t or 0)
    u.PaddingBottom = UDim.new(0, b or 0)
    u.PaddingLeft = UDim.new(0, l or 0)
    u.PaddingRight = UDim.new(0, r or 0)
    u.Parent = p
end

local function listLayout(p, spacing)
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, spacing or 8)
    l.Parent = p
end

local function tween(i, t, props)
    local tw = TweenService:Create(i, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

function PlundererUI.new(playerGui, config)
    local self = setmetatable({}, PlundererUI)
    self.config = config or {}
    self.title = self.config.Title or "PlundererHub"
    self.playerGui = playerGui
    self.tabs = {}
    self.activeTab = nil
    self.toggles = {}
    self.sliders = {}
    self.dropdowns = {}
    self:_build()
    return self
end

function PlundererUI:_build()
    local screen = Instance.new("ScreenGui")
    screen.Name = "PlundererHub"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 99999
    screen.Parent = self.playerGui
    self.screen = screen

    local glow = Instance.new("Frame")
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Size = UDim2.fromOffset(620, 460)
    glow.Position = UDim2.new(0.5, 0, 0.5, 0)
    glow.BackgroundColor3 = C.primary
    glow.BackgroundTransparency = 0.94
    glow.BorderSizePixel = 0
    glow.ZIndex = 0
    glow.Parent = screen
    corner(glow, 32)
    self.glow = glow

    local shadow = Instance.new("Frame")
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.new(0.5, 2, 0.5, 8)
    shadow.Size = UDim2.fromOffset(568, 408)
    shadow.BackgroundColor3 = Color3.new(0, 0, 0)
    shadow.BackgroundTransparency = 0.5
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 1
    shadow.Parent = screen
    corner(shadow, 14)
    self.shadow = shadow

    local win = Instance.new("Frame")
    win.Name = "Window"
    win.AnchorPoint = Vector2.new(0.5, 0.5)
    win.Size = UDim2.fromOffset(560, 400)
    win.Position = UDim2.new(0.5, 0, 0.5, 0)
    win.BackgroundColor3 = C.bg
    win.BackgroundTransparency = 0.02
    win.BorderSizePixel = 0
    win.Active = true
    win.ZIndex = 2
    win.Parent = screen
    corner(win, 12)
    stroke(win, C.border, 1, 0.5)
    self.window = win

    local glass = Instance.new("Frame")
    glass.Size = UDim2.new(1, -2, 1, -2)
    glass.Position = UDim2.fromOffset(1, 1)
    glass.BackgroundColor3 = C.bgCard
    glass.BackgroundTransparency = 0.3
    glass.BorderSizePixel = 0
    glass.ZIndex = 3
    glass.Parent = win
    corner(glass, 11)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundTransparency = 1
    header.ZIndex = 10
    header.Parent = win
    self.header = header

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(22, 0)
    title.Size = UDim2.new(1, -120, 1, 0)
    title.Font = FB
    title.Text = self.title
    title.TextSize = 17
    title.TextColor3 = C.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 10
    title.Parent = header

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(8, 8)
    dot.Position = UDim2.fromOffset(0, 20)
    dot.BackgroundColor3 = C.primary
    dot.BorderSizePixel = 0
    dot.ZIndex = 10
    dot.Parent = title
    corner(dot, 999)
    self.headerDot = dot

    local statusPill = Instance.new("Frame")
    statusPill.AnchorPoint = Vector2.new(1, 0.5)
    statusPill.Position = UDim2.new(1, -84, 0.5, 0)
    statusPill.Size = UDim2.fromOffset(78, 26)
    statusPill.BackgroundColor3 = C.bgCard
    statusPill.BackgroundTransparency = 0.2
    statusPill.BorderSizePixel = 0
    statusPill.ZIndex = 10
    statusPill.Parent = header
    corner(statusPill, 13)
    stroke(statusPill, C.border, 1, 0.55)

    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.fromOffset(7, 7)
    statusDot.Position = UDim2.new(0, 10, 0.5, -3.5)
    statusDot.BackgroundColor3 = C.muted
    statusDot.BorderSizePixel = 0
    statusDot.ZIndex = 10
    statusDot.Parent = statusPill
    corner(statusDot, 999)
    self.statusDot = statusDot

    local statusText = Instance.new("TextLabel")
    statusText.BackgroundTransparency = 1
    statusText.Position = UDim2.new(0, 24, 0, 0)
    statusText.Size = UDim2.new(1, -28, 1, 0)
    statusText.Font = FM
    statusText.Text = "Idle"
    statusText.TextSize = 11
    statusText.TextColor3 = C.muted
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.ZIndex = 10
    statusText.Parent = statusPill
    self.statusText = statusText

    local close = Instance.new("TextButton")
    close.AnchorPoint = Vector2.new(1, 0.5)
    close.Position = UDim2.new(1, -14, 0.5, 0)
    close.Size = UDim2.fromOffset(30, 30)
    close.BackgroundColor3 = C.bgCard
    close.BackgroundTransparency = 0.3
    close.BorderSizePixel = 0
    close.Text = "×"
    close.Font = FB
    close.TextSize = 18
    close.TextColor3 = C.muted
    close.AutoButtonColor = false
    close.ZIndex = 10
    close.Parent = header
    corner(close, 8)
    close.MouseEnter:Connect(function()
        tween(close, 0.15, { BackgroundColor3 = C.danger, BackgroundTransparency = 0.2, TextColor3 = C.text })
    end)
    close.MouseLeave:Connect(function()
        tween(close, 0.15, { BackgroundColor3 = C.bgCard, BackgroundTransparency = 0.3, TextColor3 = C.muted })
    end)
    close.MouseButton1Click:Connect(function()
        if self.onClose then self.onClose() end
        self:destroy()
    end)

    local min = Instance.new("TextButton")
    min.AnchorPoint = Vector2.new(1, 0.5)
    min.Position = UDim2.new(1, -50, 0.5, 0)
    min.Size = UDim2.fromOffset(30, 30)
    min.BackgroundColor3 = C.bgCard
    min.BackgroundTransparency = 0.3
    min.BorderSizePixel = 0
    min.Text = "–"
    min.Font = FB
    min.TextSize = 14
    min.TextColor3 = C.muted
    min.AutoButtonColor = false
    min.ZIndex = 10
    min.Parent = header
    corner(min, 8)
    min.MouseEnter:Connect(function()
        tween(min, 0.15, { BackgroundColor3 = C.bgHov, BackgroundTransparency = 0.1, TextColor3 = C.text })
    end)
    min.MouseLeave:Connect(function()
        tween(min, 0.15, { BackgroundColor3 = C.bgCard, BackgroundTransparency = 0.3, TextColor3 = C.muted })
    end)

    self.minimized = false
    min.MouseButton1Click:Connect(function()
        self.minimized = not self.minimized
        local h = self.minimized and 48 or 400
        tween(win, 0.25, { Size = UDim2.fromOffset(560, h) })
        self.body.Visible = not self.minimized
        self.statusBar.Visible = not self.minimized
        min.Text = self.minimized and "+" or "–"
    end)

    local divider = Instance.new("Frame")
    divider.Position = UDim2.fromOffset(0, 48)
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.BackgroundColor3 = C.border
    divider.BorderSizePixel = 0
    divider.BackgroundTransparency = 0.6
    divider.ZIndex = 10
    divider.Parent = win

    local body = Instance.new("Frame")
    body.Position = UDim2.fromOffset(0, 49)
    body.Size = UDim2.new(1, 0, 1, -49 - 30)
    body.BackgroundTransparency = 1
    body.ClipsDescendants = true
    body.ZIndex = 5
    body.Parent = win
    self.body = body

    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.fromOffset(160, 1)
    sidebar.BackgroundColor3 = C.bgCard
    sidebar.BackgroundTransparency = 0.55
    sidebar.BorderSizePixel = 0
    sidebar.ZIndex = 5
    sidebar.Parent = body
    self.sidebar = sidebar
    listLayout(sidebar, 6)
    padding(sidebar, 14, 14, 10, 10)

    local sideDivider = Instance.new("Frame")
    sideDivider.Position = UDim2.fromOffset(160, 0)
    sideDivider.Size = UDim2.new(0, 1, 1, 0)
    sideDivider.BackgroundColor3 = C.border
    sideDivider.BorderSizePixel = 0
    sideDivider.BackgroundTransparency = 0.6
    sideDivider.ZIndex = 5
    sideDivider.Parent = body

    local content = Instance.new("Frame")
    content.Position = UDim2.fromOffset(161, 0)
    content.Size = UDim2.new(1, -161, 1, 0)
    content.BackgroundTransparency = 1
    content.ZIndex = 5
    content.Parent = body
    self.contentArea = content

    local statusBar = Instance.new("Frame")
    statusBar.AnchorPoint = Vector2.new(0, 1)
    statusBar.Position = UDim2.new(0, 0, 1, 0)
    statusBar.Size = UDim2.new(1, 0, 0, 30)
    statusBar.BackgroundColor3 = C.bgCard
    statusBar.BackgroundTransparency = 0.55
    statusBar.BorderSizePixel = 0
    statusBar.ZIndex = 5
    statusBar.Parent = win
    self.statusBar = statusBar

    local sbLine = Instance.new("Frame")
    sbLine.Size = UDim2.new(1, 0, 0, 1)
    sbLine.BackgroundColor3 = C.border
    sbLine.BorderSizePixel = 0
    sbLine.BackgroundTransparency = 0.6
    sbLine.ZIndex = 5
    sbLine.Parent = statusBar

    local sbText = Instance.new("TextLabel")
    sbText.BackgroundTransparency = 1
    sbText.Position = UDim2.fromOffset(18, 0)
    sbText.Size = UDim2.new(1, -36, 1, 0)
    sbText.Font = FM
    sbText.Text = "Ready"
    sbText.TextSize = 11
    sbText.TextColor3 = C.muted
    sbText.TextXAlignment = Enum.TextXAlignment.Left
    sbText.ZIndex = 5
    sbText.Parent = statusBar
    self.statusBarText = sbText

    self:_makeDraggable(header, win)

    task.spawn(function()
        while screen and screen.Parent do
            local a = (math.sin(tick() * 3) + 1) / 2
            if self.statusDot then self.statusDot.BackgroundTransparency = 0.25 + a * 0.3 end
            if self.headerDot then self.headerDot.BackgroundTransparency = 0.4 + a * 0.4 end
            RunService.RenderStepped:Wait()
        end
    end)
end

function PlundererUI:_makeDraggable(handle, target)
    local drag, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            drag = true
            dragStart = input.Position
            startPos = target.Position
        end
    end)
    handle.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement
                     or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
            if self.shadow then
                self.shadow.Position = UDim2.new(
                    target.Position.X.Scale, target.Position.X.Offset + 2,
                    target.Position.Y.Scale, target.Position.Y.Offset + 8
                )
            end
            if self.glow then self.glow.Position = target.Position end
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
end

function PlundererUI:addTab(name, icon)
    local tab = {}
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = C.bgCard
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 5
    btn.Parent = self.sidebar
    corner(btn, 8)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.fromOffset(16, 0)
    lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.Font = FM
    lbl.Text = (icon and (icon .. "   ") or "") .. name
    lbl.TextSize = 13
    lbl.TextColor3 = C.muted
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 6
    lbl.Parent = btn
    tab.label = lbl

    local accent = Instance.new("Frame")
    accent.AnchorPoint = Vector2.new(0, 0.5)
    accent.Position = UDim2.new(0, -6, 0.5, 0)
    accent.Size = UDim2.fromOffset(4, 24)
    accent.BackgroundColor3 = C.primary
    accent.BorderSizePixel = 0
    accent.BackgroundTransparency = 1
    accent.ZIndex = 7
    accent.Parent = btn
    corner(accent, 2)
    tab.accent = accent

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = C.primary
    content.ScrollBarImageTransparency = 0.25
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Visible = false
    content.ZIndex = 5
    content.Parent = self.contentArea
    padding(content, 20, 20, 20, 20)
    listLayout(content, 12)
    tab.content = content
    tab.button = btn

    btn.MouseEnter:Connect(function()
        if self.activeTab ~= tab then
            tween(btn, 0.15, { BackgroundTransparency = 0.5, BackgroundColor3 = C.bgHov })
            tween(lbl, 0.12, { Position = UDim2.fromOffset(18, 0) })
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.activeTab ~= tab then
            tween(btn, 0.15, { BackgroundTransparency = 1 })
            tween(lbl, 0.12, { Position = UDim2.fromOffset(16, 0) })
        end
    end)
    btn.MouseButton1Click:Connect(function() self:selectTab(tab) end)

    table.insert(self.tabs, tab)
    if not self.activeTab then self:selectTab(tab) end

    return content
end

function PlundererUI:selectTab(tab)
    if self.activeTab == tab then return end
    for _, t in ipairs(self.tabs) do
        if t == tab then
            t.content.Visible = true
            t.label.TextColor3 = C.text
            tween(t.button, 0.2, { BackgroundTransparency = 0, BackgroundColor3 = C.bgHov })
            tween(t.accent, 0.2, { BackgroundTransparency = 0 })
        else
            t.content.Visible = false
            t.label.TextColor3 = C.muted
            tween(t.button, 0.2, { BackgroundTransparency = 1 })
            tween(t.accent, 0.2, { BackgroundTransparency = 1 })
        end
    end
    self.activeTab = tab
end

function PlundererUI:addSection(parent, title)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, 0)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.BackgroundColor3 = C.bgCard
    section.BackgroundTransparency = 0.25
    section.BorderSizePixel = 0
    section.ZIndex = 6
    section.Parent = parent
    corner(section, 12)
    stroke(section, C.border, 1, 0.75)
    padding(section, 16, 16, 16, 16)
    listLayout(section, 10)

    if title and title ~= "" then
        local t = Instance.new("TextLabel")
        t.BackgroundTransparency = 1
        t.Size = UDim2.new(1, 0, 0, 20)
        t.Font = FB
        t.Text = string.upper(title)
        t.TextSize = 11
        t.TextColor3 = C.primary
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.LayoutOrder = -1
        t.ZIndex = 7
        t.Parent = section
    end
    return section
end

function PlundererUI:addToggle(parent, name, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundTransparency = 1
    row.ZIndex = 7
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Font = FM
    lbl.Text = name
    lbl.TextSize = 13
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 7
    lbl.Parent = row

    local track = Instance.new("TextButton")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, 0, 0.5, 0)
    track.Size = UDim2.fromOffset(42, 24)
    track.BackgroundColor3 = C.trackOff
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.ZIndex = 7
    track.Parent = row
    corner(track, 12)
    stroke(track, C.border, 1, 0.6)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(18, 18)
    knob.Position = UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = C.knob
    knob.BorderSizePixel = 0
    knob.ZIndex = 8
    knob.Parent = track
    corner(knob, 999)

    local state = { on = default or false }
    local function apply(animate)
        local t = animate and 0.18 or 0
        if state.on then
            tween(track, t, { BackgroundColor3 = C.trackOn })
            tween(knob, t, { Position = UDim2.fromOffset(21, 3) })
        else
            tween(track, t, { BackgroundColor3 = C.trackOff })
            tween(knob, t, { Position = UDim2.fromOffset(3, 3) })
        end
    end
    apply(false)

    track.MouseButton1Click:Connect(function()
        state.on = not state.on
        apply(true)
        if callback then
            task.spawn(function() pcall(callback, state.on) end)
        end
    end)

    local obj = {
        set = function(v) state.on = v and true or false; apply(true) end,
        get = function() return state.on end,
    }
    self.toggles[name] = obj
    return obj
end

function PlundererUI:addSlider(parent, name, min, max, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    row.ZIndex = 7
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -70, 0, 20)
    lbl.Font = FM
    lbl.Text = name
    lbl.TextSize = 13
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 7
    lbl.Parent = row

    local valueLbl = Instance.new("TextLabel")
    valueLbl.BackgroundTransparency = 1
    valueLbl.AnchorPoint = Vector2.new(1, 0)
    valueLbl.Position = UDim2.new(1, 0, 0, 0)
    valueLbl.Size = UDim2.fromOffset(70, 20)
    valueLbl.Font = FM
    valueLbl.Text = tostring(default)
    valueLbl.TextSize = 12
    valueLbl.TextColor3 = C.primary
    valueLbl.TextXAlignment = Enum.TextXAlignment.Right
    valueLbl.ZIndex = 7
    valueLbl.Parent = row

    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(0, 1)
    track.Position = UDim2.new(0, 0, 1, -8)
    track.Size = UDim2.new(1, 0, 0, 6)
    track.BackgroundColor3 = C.trackOff
    track.BorderSizePixel = 0
    track.ZIndex = 7
    track.Parent = row
    corner(track, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = C.primary
    fill.BorderSizePixel = 0
    fill.ZIndex = 8
    fill.Parent = track
    corner(fill, 3)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = C.knob
    knob.BorderSizePixel = 0
    knob.ZIndex = 9
    knob.Parent = track
    corner(knob, 999)
    stroke(knob, C.primary, 2, 0)

    local value = default or min
    local dragging = false

    local function setValue(v, fire)
        v = math.clamp(v, min, max)
        value = v
        local pct = (v - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valueLbl.Text = tostring(math.floor(v * 100) / 100)
        if fire and callback then
            task.spawn(function() pcall(callback, value) end)
        end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            local mx = input.Position.X
            local ax = track.AbsolutePosition.X
            local aw = track.AbsoluteSize.X
            setValue(min + (mx - ax) / aw * (max - min), true)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                         or input.UserInputType == Enum.UserInputType.Touch) then
            local mx = input.Position.X
            local ax = track.AbsolutePosition.X
            local aw = track.AbsoluteSize.X
            setValue(min + (mx - ax) / aw * (max - min), true)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    setValue(default or min, false)

    local obj = {
        set = function(v) setValue(v, true) end,
        get = function() return value end,
    }
    self.sliders[name] = obj
    return obj
end

function PlundererUI:addButton(parent, name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = C.bgHov
    btn.BackgroundTransparency = 0.3
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.Font = FM
    btn.TextSize = 13
    btn.TextColor3 = C.text
    btn.AutoButtonColor = false
    btn.ZIndex = 7
    btn.Parent = parent
    corner(btn, 8)
    stroke(btn, C.border, 1, 0.55)

    btn.MouseEnter:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = C.primary, BackgroundTransparency = 0.1, TextColor3 = C.bg })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = C.bgHov, BackgroundTransparency = 0.3, TextColor3 = C.text })
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then task.spawn(function() pcall(callback) end) end
    end)
    return btn
end

function PlundererUI:addLabel(parent, text, color)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.Font = Enum.Font.Gotham
    lbl.Text = text
    lbl.TextSize = 12
    lbl.TextColor3 = color or C.muted
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.ZIndex = 7
    lbl.Parent = parent
    return lbl
end

function PlundererUI:setStatus(text, state)
    self.statusText.Text = text or "Idle"
    local color = C.muted
    if state == "running" then color = C.primary
    elseif state == "error" then color = C.danger end
    self.statusDot.BackgroundColor3 = color
    self.statusText.TextColor3 = color
end

function PlundererUI:setBottomStatus(text)
    self.statusBarText.Text = text or ""
end

function PlundererUI:destroy()
    if self.screen then
        self.screen:Destroy()
        self.screen = nil
    end
end

return PlundererUI

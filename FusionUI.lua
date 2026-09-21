local TweenService = game:GetService("TweenService")

local FusionUI = {}
FusionUI.__index = FusionUI
FusionUI.VERSION = "1.0.0"

local C = {
    bg      = Color3.fromRGB(10, 12, 18),
    bgCard  = Color3.fromRGB(20, 23, 33),
    bgHov   = Color3.fromRGB(30, 35, 48),
    border  = Color3.fromRGB(60, 68, 90),
    primary = Color3.fromRGB(96, 255, 168),
    text    = Color3.fromRGB(245, 248, 255),
    muted   = Color3.fromRGB(150, 160, 180),
    danger  = Color3.fromRGB(255, 92, 92),
    warn    = Color3.fromRGB(255, 200, 100),
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

local function tween(i, t, props)
    local tw = TweenService:Create(i, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

function FusionUI.new(playerGui, config)
    local self = setmetatable({}, FusionUI)
    self.config = config or {}
    self.title = self.config.Title or "Fusion Matchmaking"
    self.playerGui = playerGui
    self.toggleCallback = nil
    self.closeCallback = nil
    self.enabled = false
    self:_build()
    return self
end

function FusionUI:_build()
    local screen = Instance.new("ScreenGui")
    screen.Name = "PlundererFusion"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 99998
    screen.Parent = self.playerGui
    self.screen = screen

    local glow = Instance.new("Frame")
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Size = UDim2.fromOffset(400, 340)
    glow.Position = UDim2.new(0.5, 0, 0.5, 0)
    glow.BackgroundColor3 = C.primary
    glow.BackgroundTransparency = 0.94
    glow.BorderSizePixel = 0
    glow.ZIndex = 0
    glow.Parent = screen
    corner(glow, 32)
    self.glow = glow

    local win = Instance.new("Frame")
    win.Name = "Window"
    win.AnchorPoint = Vector2.new(0.5, 0.5)
    win.Size = UDim2.fromOffset(340, 280)
    win.Position = UDim2.new(0.5, 0, 0.5, 0)
    win.BackgroundColor3 = C.bg
    win.BorderSizePixel = 0
    win.Active = true
    win.ZIndex = 2
    win.Parent = screen
    corner(win, 12)
    stroke(win, C.border, 1, 0.5)
    self.window = win

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundTransparency = 1
    header.ZIndex = 10
    header.Parent = win
    self.header = header

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(18, 0)
    title.Size = UDim2.new(1, -100, 1, 0)
    title.Font = FB
    title.Text = self.title
    title.TextSize = 15
    title.TextColor3 = C.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 10
    title.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, -12, 0.5, 0)
    closeBtn.Size = UDim2.fromOffset(28, 28)
    closeBtn.BackgroundColor3 = C.bgCard
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.Font = FB
    closeBtn.TextSize = 18
    closeBtn.TextColor3 = C.muted
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 10
    closeBtn.Parent = header
    corner(closeBtn, 8)

    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, 0.15, { BackgroundColor3 = C.danger, TextColor3 = C.text })
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, 0.15, { BackgroundColor3 = C.bgCard, TextColor3 = C.muted })
    end)
    closeBtn.MouseButton1Click:Connect(function()
        if self.closeCallback then
            self.closeCallback()
        else
            self:destroy()
        end
    end)

    local headerLine = Instance.new("Frame")
    headerLine.Position = UDim2.fromOffset(0, 44)
    headerLine.Size = UDim2.new(1, 0, 0, 1)
    headerLine.BackgroundColor3 = C.border
    headerLine.BackgroundTransparency = 0.6
    headerLine.BorderSizePixel = 0
    headerLine.ZIndex = 10
    headerLine.Parent = win

    local body = Instance.new("Frame")
    body.Position = UDim2.fromOffset(0, 45)
    body.Size = UDim2.new(1, 0, 1, -45 - 62)
    body.BackgroundTransparency = 1
    body.ZIndex = 5
    body.Parent = win
    self.body = body

    local function makeRow(y, label)
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.fromOffset(18, y)
        lbl.Size = UDim2.new(1, -36, 0, 18)
        lbl.Font = FM
        lbl.Text = label
        lbl.TextSize = 10
        lbl.TextColor3 = C.muted
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 6
        lbl.Parent = body

        local val = Instance.new("TextLabel")
        val.BackgroundTransparency = 1
        val.Position = UDim2.fromOffset(18, y + 16)
        val.Size = UDim2.new(1, -36, 0, 22)
        val.Font = FM
        val.Text = "—"
        val.TextSize = 13
        val.TextColor3 = C.text
        val.TextXAlignment = Enum.TextXAlignment.Left
        val.TextTruncate = Enum.TextTruncate.AtEnd
        val.ZIndex = 6
        val.Parent = body
        return val
    end

    self.statusLabel  = makeRow(10,  "STATUS")
    self.roleLabel    = makeRow(56,  "ROLE")
    self.petLabel     = makeRow(102, "YOUR PET")
    self.partnerLabel = makeRow(148, "PARTNER")

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.AnchorPoint = Vector2.new(0.5, 0)
    toggleBtn.Position = UDim2.new(0.5, 0, 1, -50)
    toggleBtn.Size = UDim2.new(1, -36, 0, 36)
    toggleBtn.BackgroundColor3 = C.primary
    toggleBtn.BackgroundTransparency = 0.15
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = "▶  Start Searching"
    toggleBtn.Font = FB
    toggleBtn.TextSize = 13
    toggleBtn.TextColor3 = C.bg
    toggleBtn.AutoButtonColor = false
    toggleBtn.ZIndex = 6
    toggleBtn.Parent = win
    corner(toggleBtn, 8)
    stroke(toggleBtn, C.primary, 1, 0.4)
    self.toggleBtn = toggleBtn

    toggleBtn.MouseButton1Click:Connect(function()
        if self.toggleCallback then
            self.toggleCallback(not self.enabled)
        end
    end)
    toggleBtn.MouseEnter:Connect(function()
        tween(toggleBtn, 0.15, { BackgroundTransparency = 0.05 })
    end)
    toggleBtn.MouseLeave:Connect(function()
        tween(toggleBtn, 0.15, { BackgroundTransparency = 0.15 })
    end)

    local drag, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            drag = true
            dragStart = input.Position
            startPos = win.Position
        end
    end)
    header.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement
                     or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            glow.Position = win.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
end

function FusionUI:setStatus(text)
    self.statusLabel.Text = text or "—"
end

function FusionUI:setRole(text)
    self.roleLabel.Text = text or "—"
end

function FusionUI:setPet(text)
    self.petLabel.Text = text or "—"
end

function FusionUI:setPartner(text)
    self.partnerLabel.Text = text or "—"
end

function FusionUI:setToggleState(enabled)
    self.enabled = enabled and true or false
    if self.enabled then
        self.toggleBtn.Text = "⏸  Stop Searching"
        self.toggleBtn.BackgroundColor3 = C.danger
        stroke(self.toggleBtn, C.danger, 1, 0.4)
    else
        self.toggleBtn.Text = "▶  Start Searching"
        self.toggleBtn.BackgroundColor3 = C.primary
        stroke(self.toggleBtn, C.primary, 1, 0.4)
    end
end

function FusionUI:onToggle(fn)
    self.toggleCallback = fn
end

function FusionUI:onClose(fn)
    self.closeCallback = fn
end

function FusionUI:destroy()
    if self.screen then
        self.screen:Destroy()
        self.screen = nil
    end
end

return FusionUI

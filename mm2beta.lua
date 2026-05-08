local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

-- Global Settings
local Settings = {
    Enabled = true,
    ShowMurderer = true,
    ShowSheriff = true,
    ShowInnocent = true,
    MurdererColor = Color3.fromRGB(255, 46, 46),
    SheriffColor = Color3.fromRGB(46, 134, 255),
    InnocentColor = Color3.fromRGB(46, 255, 113),
    FillTransparency = 0.5,
    OutlineTransparency = 0,
    -- Combat
    KnifeAura = false,
    Aimlock = false,
    AuraRange = 15,
    ShowAuraVisual = false,
    Killed = false
}

local Connections = {}

-- Utility Functions
local function getPlayerRole(player)
    if not player or Settings.Killed then return "Innocent" end
    local character = player.Character
    local backpack = player.Backpack
    
    local hasKnife = (character and (character:FindFirstChild("Knife") or character:FindFirstChild("Slasher"))) or 
                     (backpack and (backpack:FindFirstChild("Knife") or backpack:FindFirstChild("Slasher")))
    if hasKnife then return "Murderer" end
    
    local hasGun = (character and (character:FindFirstChild("Gun") or character:FindFirstChild("Revolver"))) or 
                   (backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver")))
    if hasGun then return "Sheriff" end
    
    local status = player:FindFirstChild("Status")
    if status and status:FindFirstChild("Role") then
        local r = status.Role.Value
        if r == "Murderer" or r == "Knife" then return "Murderer" end
        if r == "Sheriff" or r == "Hero" then return "Sheriff" end
    end
    
    return "Innocent"
end

local function getMurderer()
    for _, player in pairs(Players:GetPlayers()) do
        if getPlayerRole(player) == "Murderer" then return player end
    end
    return nil
end

local function getSheriff()
    for _, player in pairs(Players:GetPlayers()) do
        if getPlayerRole(player) == "Sheriff" then return player end
    end
    return nil
end

-- Visual Aura Circle helper
local function createAuraCircle(parent)
    local part = Instance.new("Part")
    part.Name = "AuraVisual"
    part.Shape = Enum.PartType.Cylinder
    part.CastShadow = false
    part.CanCollide = false
    part.Anchored = true
    part.Transparency = 0.8
    part.Color = Settings.MurdererColor
    part.Size = Vector3.new(0.1, Settings.AuraRange * 2, Settings.AuraRange * 2)
    part.Rotation = Vector3.new(0, 0, 90)
    part.Parent = parent
    return part
end

-- ESP Logic
local function applyESP(player)
    if Settings.Killed then return end
    
    local function setupHighlight(character)
        if Settings.Killed then return end
        task.wait(0.5)
        if Settings.Killed then return end
        
        local highlight = character:FindFirstChild("ESPHighlight") or Instance.new("Highlight")
        highlight.Name = "ESPHighlight"
        highlight.Parent = character
        
        local auraVisual = nil
        
        local connection
        connection = RunService.Heartbeat:Connect(function()
            if Settings.Killed or not character or not character.Parent then
                if auraVisual then auraVisual:Destroy() end
                if highlight then highlight:Destroy() end
                connection:Disconnect()
                return
            end
            
            local role = getPlayerRole(player)
            local visible = false
            local color = Color3.new(1, 1, 1)

            if Settings.Enabled then
                if role == "Murderer" then
                    if Settings.ShowMurderer then
                        visible = true; color = Settings.MurdererColor
                        if Settings.ShowAuraVisual then
                            if not auraVisual then auraVisual = createAuraCircle(character) end
                            if character.PrimaryPart then
                                auraVisual.CFrame = character.PrimaryPart.CFrame * CFrame.new(0, -2.5, 0)
                                auraVisual.Size = Vector3.new(0.1, Settings.AuraRange * 2, Settings.AuraRange * 2)
                                auraVisual.Color = Settings.MurdererColor
                            end
                        elseif auraVisual then auraVisual:Destroy() auraVisual = nil end
                    end
                elseif role == "Sheriff" then
                    if Settings.ShowSheriff then
                        visible = true; color = Settings.SheriffColor
                    end
                    if auraVisual then auraVisual:Destroy() auraVisual = nil end
                else
                    if Settings.ShowInnocent then
                        visible = true; color = Settings.InnocentColor
                    end
                    if auraVisual then auraVisual:Destroy() auraVisual = nil end
                end
            else
                if auraVisual then auraVisual:Destroy() auraVisual = nil end
            end

            highlight.Enabled = visible
            highlight.FillColor = color
            highlight.OutlineColor = color
            highlight.FillTransparency = Settings.FillTransparency
            highlight.OutlineTransparency = Settings.OutlineTransparency
        end)
        table.insert(Connections, connection)
    end

    if player.Character then setupHighlight(player.Character) end
    table.insert(Connections, player.CharacterAdded:Connect(setupHighlight))
end

-- Combat Hooks
local function initCombat()
    -- Aimlock (E Key / Left Click for Sheriff)
    table.insert(Connections, RunService.RenderStepped:Connect(function()
        if Settings.Killed or not Settings.Aimlock then return end
        
        local myRole = getPlayerRole(LocalPlayer)
        local isAiming = UserInputService:IsKeyDown(Enum.KeyCode.E)
        
        if myRole == "Sheriff" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            isAiming = true
        end
        
        if isAiming then
            local target = nil
            local targetPart = "Head"
            
            if myRole == "Murderer" then
                target = getSheriff()
                targetPart = "UpperTorso"
            elseif myRole == "Sheriff" then
                target = getMurderer()
                targetPart = "Head"
            end
            
            if target and target.Character and target.Character:FindFirstChild(targetPart) then
                local cam = workspace.CurrentCamera
                local targetPos = target.Character[targetPart].Position
                cam.CFrame = CFrame.new(cam.CFrame.Position, targetPos)
            end
        end
    end))
end

-- Knife Aura Logic
table.insert(Connections, RunService.Stepped:Connect(function()
    if Settings.Killed or not Settings.KnifeAura then return end
    
    local character = LocalPlayer.Character
    local knife = character and (character:FindFirstChild("Knife") or character:FindFirstChild("Slasher"))
    if knife then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local targetHRP = player.Character.HumanoidRootPart
                local distance = (character.HumanoidRootPart.Position - targetHRP.Position).Magnitude
                if distance <= Settings.AuraRange then knife:Activate() end
            end
        end
    end
end))

---------------------------------------------------------------------
-- MODERN UI SYSTEM (FIXED CORNERS & COLORS)
---------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BeHaxHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 480, 0, 320)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 17)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = false -- Set to false to allow Stroke/Shadow visuals
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 20)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(45, 45, 55)
UIStroke.Thickness = 1.5
UIStroke.Transparency = 0.5
UIStroke.Parent = MainFrame

local function KillScript()
    Settings.Killed = true
    for _, conn in pairs(Connections) do if conn then conn:Disconnect() end end
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            for _, v in pairs(player.Character:GetChildren()) do
                if v.Name == "ESPHighlight" or v.Name == "AuraVisual" then v:Destroy() end
            end
        end
    end
    ScreenGui:Destroy()
end

-- TopBar Container to handle rounding correctly
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 45)
TopBar.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 20)
TopBarCorner.Parent = TopBar

-- Cover the bottom rounding of the top bar
local TopBarCover = Instance.new("Frame")
TopBarCover.Size = UDim2.new(1, 0, 0, 20)
TopBarCover.Position = UDim2.new(0, 0, 1, -20)
TopBarCover.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
TopBarCover.BorderSizePixel = 0
TopBarCover.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "BEHAX HUB <font color='#4E86FF'>V4.0</font>"
Title.RichText = true
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 45, 0, 45)
CloseBtn.Position = UDim2.new(1, -45, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = TopBar
CloseBtn.MouseButton1Click:Connect(KillScript)

local SideBar = Instance.new("Frame")
SideBar.Size = UDim2.new(0, 130, 1, -45)
SideBar.Position = UDim2.new(0, 0, 0, 45)
SideBar.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
SideBar.BorderSizePixel = 0
SideBar.Parent = MainFrame

local SideBarCorner = Instance.new("UICorner")
SideBarCorner.CornerRadius = UDim.new(0, 20)
SideBarCorner.Parent = SideBar

-- Cover the top/right rounding of the sidebar
local SideBarCover = Instance.new("Frame")
SideBarCover.Size = UDim2.new(0, 20, 1, 0)
SideBarCover.Position = UDim2.new(1, -20, 0, 0)
SideBarCover.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
SideBarCover.BorderSizePixel = 0
SideBarCover.Parent = SideBar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -130, 1, -45)
ContentArea.Position = UDim2.new(0, 130, 0, 45)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local Tabs = {}

local function createTab(name)
    local tabButton = Instance.new("TextButton")
    tabButton.Size = UDim2.new(1, -15, 0, 38)
    tabButton.Position = UDim2.new(0, 7, 0, #Tabs * 42 + 10)
    tabButton.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    tabButton.BorderSizePixel = 0
    tabButton.Text = "  " .. name
    tabButton.TextColor3 = Color3.fromRGB(140, 140, 150)
    tabButton.Font = Enum.Font.GothamMedium
    tabButton.TextSize = 13
    tabButton.TextXAlignment = Enum.TextXAlignment.Left
    tabButton.Parent = SideBar
    
    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0, 8)
    TabCorner.Parent = tabButton
    
    local tabContent = Instance.new("ScrollingFrame")
    tabContent.Size = UDim2.new(1, -20, 1, -20)
    tabContent.Position = UDim2.new(0, 10, 0, 10)
    tabContent.BackgroundTransparency = 1
    tabContent.ScrollBarThickness = 0
    tabContent.Visible = false
    tabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabContent.Parent = ContentArea
    
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 8)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = tabContent
    
    UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabContent.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 20)
    end)
    
    local function select()
        for _, t in pairs(Tabs) do
            t.Content.Visible = false
            TweenService:Create(t.Button, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(15, 15, 20), TextColor3 = Color3.fromRGB(140, 140, 150)}):Play()
        end
        tabContent.Visible = true
        TweenService:Create(tabButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(30, 30, 40), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end
    
    tabButton.MouseButton1Click:Connect(select)
    table.insert(Tabs, {Button = tabButton, Content = tabContent})
    if #Tabs == 1 then select() end
    return tabContent
end

local function createToggle(parent, name, default, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, 0, 0, 38)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = parent
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = toggleFrame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggleFrame
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 40, 0, 22)
    bg.Position = UDim2.new(1, -52, 0.5, -11)
    bg.BackgroundColor3 = default and Color3.fromRGB(78, 134, 255) or Color3.fromRGB(40, 40, 50)
    bg.Parent = toggleFrame
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = bg
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = default and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = bg
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = toggleFrame
    
    local active = default
    btn.MouseButton1Click:Connect(function()
        active = not active
        local targetPos = active and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local targetColor = active and Color3.fromRGB(78, 134, 255) or Color3.fromRGB(40, 40, 50)
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = targetPos}):Play()
        TweenService:Create(bg, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        callback(active)
    end)
end

local function createSlider(parent, name, min, max, default, callback)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, 0, 0, 55)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = parent
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = sliderFrame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 25)
    label.Position = UDim2.new(0, 15, 0, 8)
    label.BackgroundTransparency = 1
    label.Text = name .. ": <font color='#4E86FF'>" .. default .. "</font>"
    label.RichText = true
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = sliderFrame
    
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -30, 0, 4)
    bar.Position = UDim2.new(0, 15, 0, 40)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    bar.Parent = sliderFrame
    
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = bar
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min)/(max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(78, 134, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill
    
    local dragging = false
    local function update()
        local pos = math.clamp((UserInputService:GetMouseLocation().X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        local val = math.floor(min + (max - min) * pos)
        label.Text = name .. ": <font color='#4E86FF'>" .. val .. "</font>"
        callback(val)
    end
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 20, 1, 20)
    btn.Position = UDim2.new(0, -10, 0, -10)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = bar
    
    btn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true update() end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update() end end)
end

-- Dragging Logic
local dragging, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

-- Tabs
local ESPTab = createTab("Visuals")
createToggle(ESPTab, "Master ESP", Settings.Enabled, function(v) Settings.Enabled = v end)
createToggle(ESPTab, "Show Murderer", Settings.ShowMurderer, function(v) Settings.ShowMurderer = v end)
createToggle(ESPTab, "Show Sheriff", Settings.ShowSheriff, function(v) Settings.ShowSheriff = v end)
createToggle(ESPTab, "Show Innocents", Settings.ShowInnocent, function(v) Settings.ShowInnocent = v end)
createSlider(ESPTab, "ESP Transparency", 0, 10, 5, function(v) Settings.FillTransparency = v/10 end)

local CombatTab = createTab("Combat")
local function createSection(parent, name)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(90, 90, 105)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
end

createSection(CombatTab, "GENERAL")
createToggle(CombatTab, "Aimbot (Hold E / Left Click)", Settings.Aimlock, function(v) Settings.Aimlock = v end)

createSection(CombatTab, "MURDERER")
createToggle(CombatTab, "Knife Aura", Settings.KnifeAura, function(v) Settings.KnifeAura = v end)
createToggle(CombatTab, "Aimbot (Hold E)", Settings.Aimlock, function(v) Settings.Aimlock = v end)
createSlider(CombatTab, "Aura Range", 5, 25, Settings.AuraRange, function(v) Settings.AuraRange = v end)
createToggle(CombatTab, "Show Range Visual", Settings.ShowAuraVisual, function(v) Settings.ShowAuraVisual = v end)

-- Initialize Systems
for _, player in ipairs(Players:GetPlayers()) do applyESP(player) end
table.insert(Connections, Players.PlayerAdded:Connect(applyESP))
initCombat()

print("BeHax Hub Modern UI Loaded!")

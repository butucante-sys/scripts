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
    MurdererAimlock = false,
    SheriffAimlock = false,
    MurdererAimKey = Enum.KeyCode.E,
    SheriffAimKey = Enum.UserInputType.MouseButton1,
    SheriffAutoShoot = false,
    AuraRange = 15,
    ShowAuraVisual = false,
    -- LocalPlayer Mods
    WalkSpeed = 16,
    JumpPower = 50,
    InfJump = false,
    Noclip = false,
    AutoGrabGun = false,
    Killed = false
}

local Connections = {}
local InitializeFeatures -- Forward declaration
local RoleCache = {}

-- Optimized Role Detection
local function getPlayerRole(player)
    if not player or Settings.Killed then return "Innocent" end
    if RoleCache[player] then return RoleCache[player] end
    
    local character = player.Character
    local backpack = player.Backpack
    
    local hasKnife = (character and (character:FindFirstChild("Knife") or character:FindFirstChild("Slasher"))) or 
                     (backpack and (backpack:FindFirstChild("Knife") or backpack:FindFirstChild("Slasher")))
    if hasKnife then RoleCache[player] = "Murderer" return "Murderer" end
    
    local hasGun = (character and (character:FindFirstChild("Gun") or character:FindFirstChild("Revolver"))) or 
                   (backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver")))
    if hasGun then RoleCache[player] = "Sheriff" return "Sheriff" end
    
    local status = player:FindFirstChild("Status")
    if status and status:FindFirstChild("Role") then
        local r = status.Role.Value
        if r == "Murderer" or r == "Knife" then RoleCache[player] = "Murderer" return "Murderer" end
        if r == "Sheriff" or r == "Hero" then RoleCache[player] = "Sheriff" return "Sheriff" end
    end
    
    return "Innocent"
end

task.spawn(function()
    while task.wait(1) do
        if Settings.Killed then break end
        RoleCache = {}
    end
end)

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
    table.insert(Connections, RunService.RenderStepped:Connect(function()
        if Settings.Killed then return end
        local myRole = getPlayerRole(LocalPlayer)
        local isAiming = false
        
        if myRole == "Murderer" and Settings.MurdererAimlock then
            isAiming = (typeof(Settings.MurdererAimKey) == "EnumItem" and Settings.MurdererAimKey.EnumType == Enum.KeyCode and UserInputService:IsKeyDown(Settings.MurdererAimKey)) or
                       (typeof(Settings.MurdererAimKey) == "EnumItem" and Settings.MurdererAimKey.EnumType == Enum.UserInputType and UserInputService:IsMouseButtonPressed(Settings.MurdererAimKey))
        elseif myRole == "Sheriff" and Settings.SheriffAimlock then
            isAiming = (typeof(Settings.SheriffAimKey) == "EnumItem" and Settings.SheriffAimKey.EnumType == Enum.KeyCode and UserInputService:IsKeyDown(Settings.SheriffAimKey)) or
                       (typeof(Settings.SheriffAimKey) == "EnumItem" and Settings.SheriffAimKey.EnumType == Enum.UserInputType and UserInputService:IsMouseButtonPressed(Settings.SheriffAimKey))
        end
        
        if isAiming then
            local target = nil
            if myRole == "Murderer" then
                target = getSheriff()
                if not target then
                    -- Target closest innocent if Sheriff is dead/missing
                    local closestDist = math.huge
                    local myChar = LocalPlayer.Character
                    if myChar and myChar.PrimaryPart then
                        local myPos = myChar.PrimaryPart.Position
                        for _, p in pairs(Players:GetPlayers()) do
                            if p ~= LocalPlayer and getPlayerRole(p) == "Innocent" and p.Character and p.Character.PrimaryPart then
                                local dist = (p.Character.PrimaryPart.Position - myPos).Magnitude
                                if dist < closestDist then
                                    closestDist = dist
                                    target = p
                                end
                            end
                        end
                    end
                end
            else
                target = getMurderer()
            end
            
            local targetPart = (myRole == "Murderer" and "UpperTorso" or "Head")
            
            if target and target.Character and target.Character:FindFirstChild(targetPart) then
                local cam = workspace.CurrentCamera
                cam.CFrame = CFrame.new(cam.CFrame.Position, target.Character[targetPart].Position)
                
                if myRole == "Sheriff" and Settings.SheriffAutoShoot then
                    local currentTick = tick()
                    if not Settings.LastAutoShoot or (currentTick - Settings.LastAutoShoot) > 1.5 then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, target.Character}
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        local origin = cam.CFrame.Position
                        local direction = (target.Character[targetPart].Position - origin)
                        local raycastResult = workspace:Raycast(origin, direction, rayParams)
                        
                        if not raycastResult then
                            Settings.LastAutoShoot = currentTick
                            task.spawn(function()
                                task.wait(0.1) -- Little delay to ensure aim is set
                                if mouse1click then mouse1click() end
                            end)
                        end
                    end
                end
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
                if (character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude <= Settings.AuraRange then
                    knife:Activate()
                end
            end
        end
    end
end))

---------------------------------------------------------------------
-- REFINED MODERN UI (BETTER PROPORTIONS)
---------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BeHaxHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 550, 0, 360)
MainFrame.Position = UDim2.new(0.5, -275, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 17)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(45, 45, 55)
UIStroke.Thickness = 1.2
UIStroke.Parent = MainFrame

MainFrame.Visible = false -- Hide until key is entered

-- Shared Logo Logic
local logoUrl = "https://raw.githubusercontent.com/butucante-sys/scripts/main/BeHaxLogoNoBg.png"
local success, logoResult = pcall(function()
    if writefile and getcustomasset and readfile then
        if not isfile("BeHaxLogo.png") then writefile("BeHaxLogo.png", game:HttpGet(logoUrl)) end
        return getcustomasset("BeHaxLogo.png")
    end
    return logoUrl
end)
local finalLogoImage = success and logoResult or logoUrl

-- Key System UI
local KeyFrame = Instance.new("Frame")
KeyFrame.Size = UDim2.new(0, 350, 0, 200)
KeyFrame.Position = UDim2.new(0.5, -175, 0.5, -100)
KeyFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 17)
KeyFrame.BorderSizePixel = 0
KeyFrame.Parent = ScreenGui

local KeyCorner = Instance.new("UICorner")
KeyCorner.CornerRadius = UDim.new(0, 8)
KeyCorner.Parent = KeyFrame

local KeyStroke = Instance.new("UIStroke")
KeyStroke.Color = Color3.fromRGB(45, 45, 55)
KeyStroke.Thickness = 1.2
KeyStroke.Parent = KeyFrame

local KeyLogo = Instance.new("ImageLabel")
KeyLogo.Size = UDim2.new(0, 48, 0, 48)
KeyLogo.Position = UDim2.new(0, 15, 0, 5)
KeyLogo.BackgroundTransparency = 1
KeyLogo.Image = finalLogoImage
KeyLogo.Parent = KeyFrame

local KeyTitle = Instance.new("TextLabel")
KeyTitle.Size = UDim2.new(1, -70, 0, 40)
KeyTitle.Position = UDim2.new(0, 65, 0, 10)
KeyTitle.BackgroundTransparency = 1
KeyTitle.Text = "BEHAX HUB - KEY SYSTEM"
KeyTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyTitle.Font = Enum.Font.GothamBold
KeyTitle.TextSize = 16
KeyTitle.TextXAlignment = Enum.TextXAlignment.Left
KeyTitle.Parent = KeyFrame

local KeyInput = Instance.new("TextBox")
KeyInput.Size = UDim2.new(1, -60, 0, 40)
KeyInput.Position = UDim2.new(0, 30, 0, 65)
KeyInput.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
KeyInput.BorderSizePixel = 0
KeyInput.Text = ""
KeyInput.PlaceholderText = "Enter Key Here..."
KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyInput.Font = Enum.Font.Gotham
KeyInput.TextSize = 14
KeyInput.Parent = KeyFrame

local InputCorner = Instance.new("UICorner")
InputCorner.CornerRadius = UDim.new(0, 6)
InputCorner.Parent = KeyInput

local CheckBtn = Instance.new("TextButton")
CheckBtn.Size = UDim2.new(0, 135, 0, 40)
CheckBtn.Position = UDim2.new(0, 30, 0, 125)
CheckBtn.BackgroundColor3 = Color3.fromRGB(78, 134, 255)
CheckBtn.Text = "Submit Key"
CheckBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CheckBtn.Font = Enum.Font.GothamBold
CheckBtn.TextSize = 14
CheckBtn.Parent = KeyFrame

local CheckCorner = Instance.new("UICorner")
CheckCorner.CornerRadius = UDim.new(0, 6)
CheckCorner.Parent = CheckBtn

local GetBtn = Instance.new("TextButton")
GetBtn.Size = UDim2.new(0, 135, 0, 40)
GetBtn.Position = UDim2.new(1, -165, 0, 125)
GetBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
GetBtn.Text = "Get Key (Discord)"
GetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
GetBtn.Font = Enum.Font.GothamBold
GetBtn.TextSize = 13
GetBtn.Parent = KeyFrame

local GetCorner = Instance.new("UICorner")
GetCorner.CornerRadius = UDim.new(0, 6)
GetCorner.Parent = GetBtn

GetBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard("https://discord.gg/R3ymPNNtwS")
        GetBtn.Text = "Copied Link!"
        task.wait(2)
        GetBtn.Text = "Get Key (Discord)"
    end
end)

local isChecking = false
CheckBtn.MouseButton1Click:Connect(function()
    if isChecking then return end
    
    if KeyInput.Text == "BEHAX123" or KeyInput.Text == "behax123" then
        isChecking = true
        CheckBtn.Text = "Checking..."
        CheckBtn.BackgroundColor3 = Color3.fromRGB(200, 160, 50)
        task.wait(0.8)
        
        CheckBtn.Text = "Valid Key!"
        CheckBtn.BackgroundColor3 = Color3.fromRGB(46, 255, 113)
        task.wait(0.5)
        
        -- Cool Animation Out
        local ti = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        TweenService:Create(KeyFrame, ti, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}):Play()
        TweenService:Create(KeyTitle, ti, {TextTransparency = 1}):Play()
        TweenService:Create(KeyInput, ti, {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        TweenService:Create(CheckBtn, ti, {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        TweenService:Create(GetBtn, ti, {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        TweenService:Create(KeyStroke, TweenInfo.new(0.5), {Transparency = 1}):Play()
        
        task.wait(0.5)
        KeyFrame.Visible = false
        
        -- Main Frame Animation In
        MainFrame.Size = UDim2.new(0, 0, 0, 0)
        MainFrame.Visible = true
        local tiIn = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        TweenService:Create(MainFrame, tiIn, {Size = UDim2.new(0, 550, 0, 360)}):Play()
        
        -- Start all features now that key is passed
        if InitializeFeatures then InitializeFeatures() end
        
    else
        isChecking = true
        CheckBtn.Text = "Checking..."
        CheckBtn.BackgroundColor3 = Color3.fromRGB(200, 160, 50)
        task.wait(0.5)
        
        CheckBtn.Text = "Invalid Key"
        CheckBtn.BackgroundColor3 = Color3.fromRGB(255, 46, 46)
        KeyInput.Text = ""
        task.wait(1)
        
        CheckBtn.Text = "Submit Key"
        CheckBtn.BackgroundColor3 = Color3.fromRGB(78, 134, 255)
        isChecking = false
    end
end)

-- Dragging Logic for KeyFrame
local dragToggle, dragStart, startPos
KeyFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragToggle = true; dragStart = input.Position; startPos = KeyFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragToggle and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        KeyFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragToggle = false end
end)

-- Loading Animation before Key System
local LoadingFrame = Instance.new("Frame")
LoadingFrame.Size = UDim2.new(0, 200, 0, 200)
LoadingFrame.Position = UDim2.new(0.5, -100, 0.5, -100)
LoadingFrame.BackgroundTransparency = 1
LoadingFrame.Parent = ScreenGui

local LoadingLogo = Instance.new("ImageLabel")
LoadingLogo.Size = UDim2.new(0, 100, 0, 100)
LoadingLogo.Position = UDim2.new(0.5, -50, 0.5, -50)
LoadingLogo.BackgroundTransparency = 1
LoadingLogo.Image = finalLogoImage
LoadingLogo.ImageTransparency = 1
LoadingLogo.Parent = LoadingFrame

local LoadingText = Instance.new("TextLabel")
LoadingText.Size = UDim2.new(1, 0, 0, 30)
LoadingText.Position = UDim2.new(0, 0, 1, -30)
LoadingText.BackgroundTransparency = 1
LoadingText.Text = "Loading BeHax Hub..."
LoadingText.TextColor3 = Color3.fromRGB(255, 255, 255)
LoadingText.Font = Enum.Font.GothamBold
LoadingText.TextSize = 14
LoadingText.TextTransparency = 1
LoadingText.Parent = LoadingFrame

KeyFrame.Visible = false
KeyFrame.Size = UDim2.new(0, 0, 0, 0) -- For pop animation

task.spawn(function()
    TweenService:Create(LoadingLogo, TweenInfo.new(0.5), {ImageTransparency = 0}):Play()
    task.wait(0.5)
    TweenService:Create(LoadingText, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
    
    for i = 1, 2 do
        TweenService:Create(LoadingLogo, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.new(0, 120, 0, 120), Position = UDim2.new(0.5, -60, 0.5, -60), Rotation = 180}):Play()
        task.wait(0.4)
        TweenService:Create(LoadingLogo, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.new(0, 100, 0, 100), Position = UDim2.new(0.5, -50, 0.5, -50), Rotation = 360}):Play()
        task.wait(0.4)
        LoadingLogo.Rotation = 0
    end
    
    TweenService:Create(LoadingLogo, TweenInfo.new(0.5), {ImageTransparency = 1}):Play()
    TweenService:Create(LoadingText, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
    task.wait(0.5)
    
    LoadingFrame:Destroy()
    
    KeyFrame.Visible = true
    TweenService:Create(KeyFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 350, 0, 200)}):Play()
end)

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

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 60) -- REFINED HEIGHT
TopBar.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 8)
TopCorner.Parent = TopBar

local TopCover = Instance.new("Frame")
TopCover.Size = UDim2.new(1, 0, 0, 10)
TopCover.Position = UDim2.new(0, 0, 1, -10)
TopCover.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
TopCover.BorderSizePixel = 0
TopCover.Parent = TopBar

local Logo = Instance.new("ImageLabel")
Logo.Name = "Logo"
Logo.Size = UDim2.new(0, 48, 0, 48) -- CLEANER SIZE
Logo.Position = UDim2.new(0, 12, 0.5, -24)
Logo.BackgroundTransparency = 1

Logo.Image = finalLogoImage
Logo.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -120, 1, 0)
Title.Position = UDim2.new(0, 70, 0, 0) -- BALANCED OFFSET
Title.BackgroundTransparency = 1
Title.Text = "BEHAX HUB <font color='#4E86FF'>V4.1</font>"
Title.RichText = true
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 40, 0, 40)
CloseBtn.Position = UDim2.new(1, -50, 0.5, -20)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = TopBar
CloseBtn.MouseButton1Click:Connect(KillScript)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 40, 0, 40)
MinBtn.Position = UDim2.new(1, -90, 0.5, -20)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 24
MinBtn.Parent = TopBar

local SideBar = Instance.new("Frame")
SideBar.Size = UDim2.new(0, 140, 1, -60)
SideBar.Position = UDim2.new(0, 0, 0, 60)
SideBar.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
SideBar.BorderSizePixel = 0
SideBar.Parent = MainFrame

local SideCorner = Instance.new("UICorner")
SideCorner.CornerRadius = UDim.new(0, 8)
SideCorner.Parent = SideBar

local SideCover = Instance.new("Frame")
SideCover.Size = UDim2.new(0, 10, 1, 0)
SideCover.Position = UDim2.new(1, -10, 0, 0)
SideCover.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
SideCover.BorderSizePixel = 0
SideCover.Parent = SideBar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -140, 1, -60)
ContentArea.Position = UDim2.new(0, 140, 0, 60)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        MinBtn.Text = "+"
        ContentArea.Visible = false
        SideBar.Visible = false
        TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 550, 0, 60)}):Play()
    else
        MinBtn.Text = "-"
        local t = TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 550, 0, 360)})
        t:Play()
        t.Completed:Wait()
        if not minimized then
            ContentArea.Visible = true
            SideBar.Visible = true
        end
    end
end)

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
    TabCorner.CornerRadius = UDim.new(0, 6)
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
        tabContent.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 10)
    end)
    
    local function select()
        for _, t in pairs(Tabs) do
            t.Content.Visible = false
            TweenService:Create(t.Button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(15, 15, 20), TextColor3 = Color3.fromRGB(140, 140, 150)}):Play()
        end
        tabContent.Visible = true
        TweenService:Create(tabButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 30, 40), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end
    
    tabButton.MouseButton1Click:Connect(select)
    table.insert(Tabs, {Button = tabButton, Content = tabContent})
    if #Tabs == 1 then select() end
    return tabContent
end

local function createToggle(parent, name, default, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, 0, 0, 40)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = parent
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = toggleFrame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -65, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggleFrame
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 40, 0, 20)
    bg.Position = UDim2.new(1, -55, 0.5, -10)
    bg.BackgroundColor3 = default and Color3.fromRGB(78, 134, 255) or Color3.fromRGB(40, 40, 50)
    bg.Parent = toggleFrame
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = bg
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = default and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
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
        local targetPos = active and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        local targetColor = active and Color3.fromRGB(78, 134, 255) or Color3.fromRGB(40, 40, 50)
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = targetPos}):Play()
        TweenService:Create(bg, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()
        callback(active)
    end)
end

local function createSlider(parent, name, min, max, default, callback)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, 0, 0, 60)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = parent
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = sliderFrame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 25)
    label.Position = UDim2.new(0, 15, 0, 10)
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
    bar.Position = UDim2.new(0, 15, 0, 42)
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

local function createKeybind(parent, name, default, callback)
    local bindFrame = Instance.new("Frame")
    bindFrame.Size = UDim2.new(1, 0, 0, 40)
    bindFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    bindFrame.BorderSizePixel = 0
    bindFrame.Parent = parent
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = bindFrame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -95, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = bindFrame
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 0, 24)
    btn.Position = UDim2.new(1, -80, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    local defName = default.Name
    if defName:match("MouseButton") then defName = defName:gsub("MouseButton", "MB") end
    btn.Text = defName
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = bindFrame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn
    
    local listening = false
    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        btn.Text = "..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            local key
            if input.UserInputType == Enum.UserInputType.Keyboard then
                key = input.KeyCode
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                key = input.UserInputType
            end
            
            if key and key ~= Enum.KeyCode.Unknown then
                local kname = key.Name
                if kname:match("MouseButton") then kname = kname:gsub("MouseButton", "MB") end
                btn.Text = kname
                callback(key)
                listening = false
                conn:Disconnect()
            end
        end)
    end)
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

-- Create Tabs
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

createSection(CombatTab, "SHERIFF")
createToggle(CombatTab, "Sheriff Aimbot", Settings.SheriffAimlock, function(v) Settings.SheriffAimlock = v end)
createKeybind(CombatTab, "Aim Keybind", Settings.SheriffAimKey, function(v) Settings.SheriffAimKey = v end)
createToggle(CombatTab, "Auto Shoot", Settings.SheriffAutoShoot, function(v) Settings.SheriffAutoShoot = v end)

createSection(CombatTab, "MURDERER")
createToggle(CombatTab, "Murderer Aimbot", Settings.MurdererAimlock, function(v) Settings.MurdererAimlock = v end)
createKeybind(CombatTab, "Aim Keybind", Settings.MurdererAimKey, function(v) Settings.MurdererAimKey = v end)
createToggle(CombatTab, "Knife Aura", Settings.KnifeAura, function(v) Settings.KnifeAura = v end)
createSlider(CombatTab, "Aura Range", 5, 25, Settings.AuraRange, function(v) Settings.AuraRange = v end)
createToggle(CombatTab, "Show Range Visual", Settings.ShowAuraVisual, function(v) Settings.ShowAuraVisual = v end)

createSection(CombatTab, "INNOCENT")
createToggle(CombatTab, "Auto Grab Gun", Settings.AutoGrabGun, function(v) Settings.AutoGrabGun = v end)

local PlayerTab = createTab("Player")
createSection(PlayerTab, "MOVEMENT")
createSlider(PlayerTab, "Walk Speed", 16, 120, Settings.WalkSpeed, function(v) Settings.WalkSpeed = v end)
createSlider(PlayerTab, "Jump Power", 50, 200, Settings.JumpPower, function(v) Settings.JumpPower = v end)
createToggle(PlayerTab, "Infinite Jump", Settings.InfJump, function(v) Settings.InfJump = v end)
createToggle(PlayerTab, "Noclip", Settings.Noclip, function(v) Settings.Noclip = v end)

InitializeFeatures = function()
    task.spawn(initCombat)
    for _, player in ipairs(Players:GetPlayers()) do task.spawn(applyESP, player) end
    table.insert(Connections, Players.PlayerAdded:Connect(applyESP))
    
    -- Infinite Jump
    table.insert(Connections, UserInputService.JumpRequest:Connect(function()
        if Settings.Killed or not Settings.InfJump then return end
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end))
    
    -- Speed / Jump Power loop
    table.insert(Connections, RunService.Heartbeat:Connect(function()
        if Settings.Killed then return end
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if Settings.WalkSpeed ~= 16 then
                    humanoid.WalkSpeed = Settings.WalkSpeed
                end
                if Settings.JumpPower ~= 50 then
                    humanoid.UseJumpPower = true
                    humanoid.JumpPower = Settings.JumpPower
                end
            end
        end
    end))
    
    -- Noclip loop
    table.insert(Connections, RunService.Stepped:Connect(function()
        if Settings.Killed or not Settings.Noclip then return end
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end))
    
    -- Gun ESP & Auto Grab
    table.insert(Connections, RunService.Heartbeat:Connect(function()
        if Settings.Killed then return end
        
        local gunDrop = workspace:FindFirstChild("Normal") and workspace.Normal:FindFirstChild("GunDrop")
        if not gunDrop then gunDrop = workspace:FindFirstChild("GunDrop") end
        
        if not gunDrop then
            for _, v in ipairs(workspace:GetDescendants()) do
                if v.Name == "GunDrop" then
                    gunDrop = v
                    break
                end
            end
        end
        
        if gunDrop then
            -- Gun ESP
            if Settings.Enabled and Settings.ShowSheriff then
                local highlight = gunDrop:FindFirstChild("ESPHighlight") or Instance.new("Highlight")
                highlight.Name = "ESPHighlight"
                highlight.FillColor = Settings.SheriffColor
                highlight.OutlineColor = Settings.SheriffColor
                highlight.Parent = gunDrop
            end
            
            -- Auto Grab
            if Settings.AutoGrabGun and getPlayerRole(LocalPlayer) == "Innocent" then
                local myChar = LocalPlayer.Character
                if myChar and myChar.PrimaryPart then
                    if firetouchinterest then
                        firetouchinterest(myChar.PrimaryPart, gunDrop, 0)
                        firetouchinterest(myChar.PrimaryPart, gunDrop, 1)
                    else
                        myChar:PivotTo(gunDrop.CFrame)
                    end
                end
            end
        end
    end))
    
    print("BeHax Hub Refined Loaded!")
end

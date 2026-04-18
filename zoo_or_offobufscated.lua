-- Load Linoria Library
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- ESP Variables
local ESPEnabled = false
local ESPColor = Color3.fromRGB(255, 0, 0)
local ESPTransparency = 0.5
local ShowDistance = true
local ShowName = true
local MaxDistance = 1000

-- Aimbot Variables
local AimbotEnabled = false
local AimbotKey = Enum.KeyCode.E
local AimbotFOV = 200
local AimbotSmoothing = 0.1
local ShowFOVCircle = true
local TeamCheck = false
local VisibilityCheck = false
local AimbotMaxDistance = 500
local TargetPart = "Head"

-- Off-Screen Arrow Variables
local ShowOffScreenArrows = true
local ArrowColor = Color3.fromRGB(255, 255, 0)
local ArrowSize = 20
local ArrowDistance = 150
local ArrowTransparency = 0.8

local ESPObjects = {}
local FOVCircle
local ArrowDrawings = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Create FOV Circle
local function createFOVCircle()
    local circle = Drawing.new("Circle")
    circle.Thickness = 2
    circle.NumSides = 50
    circle.Radius = AimbotFOV
    circle.Filled = false
    circle.Visible = ShowFOVCircle
    circle.Color = Color3.fromRGB(255, 255, 255)
    circle.Transparency = 1
    circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    return circle
end

FOVCircle = createFOVCircle()

-- Create Off-Screen Arrow
local function createArrow()
    local arrow = Drawing.new("Triangle")
    arrow.Visible = false
    arrow.Filled = true
    arrow.Color = ArrowColor
    arrow.Transparency = ArrowTransparency
    arrow.Thickness = 1
    return arrow
end

-- Rotate Point Around Center
local function rotatePoint(point, center, angle)
    local s = math.sin(angle)
    local c = math.cos(angle)
    
    point = point - center
    
    local xnew = point.X * c - point.Y * s
    local ynew = point.X * s + point.Y * c
    
    return Vector2.new(xnew, ynew) + center
end

-- Update Off-Screen Arrows
local function updateOffScreenArrows()
    -- Clear old arrows
    for _, arrow in pairs(ArrowDrawings) do
        arrow.Visible = false
    end
    
    if not ShowOffScreenArrows then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local animalsFolder = workspace:FindFirstChild("Gameplay")
    if not animalsFolder then return end
    
    animalsFolder = animalsFolder:FindFirstChild("Dynamic")
    if not animalsFolder then return end
    
    animalsFolder = animalsFolder:FindFirstChild("Animals")
    if not animalsFolder then return end
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local arrowIndex = 1
    
    for _, animal in pairs(animalsFolder:GetChildren()) do
        local animalPart = animal:FindFirstChild("HumanoidRootPart") or animal:FindFirstChild("Head") or animal:FindFirstChildWhichIsA("BasePart")
        
        if animalPart then
            local distance = (humanoidRootPart.Position - animalPart.Position).Magnitude
            
            if distance <= MaxDistance then
                local screenPos, onScreen = Camera:WorldToViewportPoint(animalPart.Position)
                
                -- Only show arrow if animal is off-screen
                if not onScreen or screenPos.Z < 0 then
                    -- Create or reuse arrow
                    if not ArrowDrawings[arrowIndex] then
                        ArrowDrawings[arrowIndex] = createArrow()
                    end
                    
                    local arrow = ArrowDrawings[arrowIndex]
                    
                    -- Calculate direction to animal
                    local direction = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Unit
                    
                    -- Calculate arrow position (distance from center)
                    local arrowPos = screenCenter + (direction * ArrowDistance)
                    
                    -- Clamp to screen bounds
                    arrowPos = Vector2.new(
                        math.clamp(arrowPos.X, 50, Camera.ViewportSize.X - 50),
                        math.clamp(arrowPos.Y, 50, Camera.ViewportSize.Y - 50)
                    )
                    
                    -- Calculate angle
                    local angle = math.atan2(direction.Y, direction.X)
                    
                    -- Arrow points (triangle shape)
                    local point1 = Vector2.new(ArrowSize, 0)
                    local point2 = Vector2.new(-ArrowSize/2, ArrowSize/2)
                    local point3 = Vector2.new(-ArrowSize/2, -ArrowSize/2)
                    
                    -- Rotate points
                    point1 = rotatePoint(point1, Vector2.new(0, 0), angle)
                    point2 = rotatePoint(point2, Vector2.new(0, 0), angle)
                    point3 = rotatePoint(point3, Vector2.new(0, 0), angle)
                    
                    -- Set arrow properties
                    arrow.PointA = arrowPos + point1
                    arrow.PointB = arrowPos + point2
                    arrow.PointC = arrowPos + point3
                    arrow.Color = ArrowColor
                    arrow.Transparency = ArrowTransparency
                    arrow.Visible = true
                    
                    arrowIndex = arrowIndex + 1
                end
            end
        end
    end
end

-- Visibility Check Function
local function isVisible(targetPart)
    if not VisibilityCheck then return true end
    
    local character = LocalPlayer.Character
    if not character then return false end
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.IgnoreWater = true
    
    local raycastResult = workspace:Raycast(origin, direction, raycastParams)
    
    if raycastResult then
        if raycastResult.Instance:IsDescendantOf(targetPart.Parent) then
            return true
        end
    else
        return true
    end
    
    return false
end

-- Get Closest Animal Function
local function getClosestAnimal()
    local closestAnimal = nil
    local shortestDistance = math.huge
    local character = LocalPlayer.Character
    
    if not character then return nil end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    local animalsFolder = workspace:FindFirstChild("Gameplay")
    if not animalsFolder then return nil end
    
    animalsFolder = animalsFolder:FindFirstChild("Dynamic")
    if not animalsFolder then return nil end
    
    animalsFolder = animalsFolder:FindFirstChild("Animals")
    if not animalsFolder then return nil end
    
    for _, animal in pairs(animalsFolder:GetChildren()) do
        local targetPart = animal:FindFirstChild(TargetPart) or animal:FindFirstChild("Head") or animal:FindFirstChild("HumanoidRootPart") or animal:FindFirstChildWhichIsA("BasePart")
        
        if targetPart then
            local distance = (humanoidRootPart.Position - targetPart.Position).Magnitude
            
            if distance <= AimbotMaxDistance then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen then
                    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    local distanceFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    
                    if distanceFromCenter <= AimbotFOV and distanceFromCenter < shortestDistance then
                        if isVisible(targetPart) then
                            closestAnimal = targetPart
                            shortestDistance = distanceFromCenter
                        end
                    end
                end
            end
        end
    end
    
    return closestAnimal
end

-- Aimbot Function
local function aimAt(targetPart)
    if not targetPart then return end
    
    local targetPosition = targetPart.Position
    local cameraPosition = Camera.CFrame.Position
    
    local direction = (targetPosition - cameraPosition).Unit
    local targetCFrame = CFrame.new(cameraPosition, cameraPosition + direction)
    
    -- Smoothing
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, AimbotSmoothing)
end

-- Create ESP for Animal
local function createESP(animal)
    if ESPObjects[animal] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "AnimalESP"
    highlight.FillColor = ESPColor
    highlight.OutlineColor = ESPColor
    highlight.FillTransparency = ESPTransparency
    highlight.OutlineTransparency = 0
    highlight.Parent = animal
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "AnimalLabel"
    billboardGui.AlwaysOnTop = true
    billboardGui.Size = UDim2.new(0, 200, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.Parent = animal
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = ESPColor
    textLabel.TextStrokeTransparency = 0.5
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Parent = billboardGui
    
    ESPObjects[animal] = {
        Highlight = highlight,
        BillboardGui = billboardGui,
        TextLabel = textLabel
    }
end

-- Remove ESP
local function removeESP(animal)
    if ESPObjects[animal] then
        ESPObjects[animal].Highlight:Destroy()
        ESPObjects[animal].BillboardGui:Destroy()
        ESPObjects[animal] = nil
    end
end

-- Update ESP
local function updateESP()
    local player = game.Players.LocalPlayer
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    for animal, espData in pairs(ESPObjects) do
        if animal and animal:IsDescendantOf(workspace) then
            local animalPart = animal:FindFirstChild("HumanoidRootPart") or animal:FindFirstChildWhichIsA("BasePart")
            if animalPart then
                local distance = (humanoidRootPart.Position - animalPart.Position).Magnitude
                
                if distance <= MaxDistance then
                    espData.Highlight.Enabled = ESPEnabled
                    espData.BillboardGui.Enabled = ESPEnabled and (ShowName or ShowDistance)
                    
                    local text = ""
                    if ShowName then
                        text = animal.Name
                    end
                    if ShowDistance then
                        text = text .. (ShowName and "\n" or "") .. string.format("%.1f studs", distance)
                    end
                    espData.TextLabel.Text = text
                    
                    -- Update colors
                    espData.Highlight.FillColor = ESPColor
                    espData.Highlight.OutlineColor = ESPColor
                    espData.Highlight.FillTransparency = ESPTransparency
                    espData.TextLabel.TextColor3 = ESPColor
                else
                    espData.Highlight.Enabled = false
                    espData.BillboardGui.Enabled = false
                end
            end
        else
            removeESP(animal)
        end
    end
end

-- Scan Animals
local function scanAnimals()
    local animalsFolder = workspace:FindFirstChild("Gameplay")
    if animalsFolder then
        animalsFolder = animalsFolder:FindFirstChild("Dynamic")
        if animalsFolder then
            animalsFolder = animalsFolder:FindFirstChild("Animals")
            if animalsFolder then
                for _, animal in pairs(animalsFolder:GetChildren()) do
                    if ESPEnabled then
                        createESP(animal)
                    else
                        removeESP(animal)
                    end
                end
            end
        end
    end
end

-- Create GUI
local Window = Library:CreateWindow({
    Title = 'Animal ESP + Aimbot + Arrows',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    ESP = Window:AddTab('ESP Settings'),
    Aimbot = Window:AddTab('Aimbot Settings'),
    Arrows = Window:AddTab('Arrow Settings'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ==================== ESP TAB ====================
local ESPGroup = Tabs.ESP:AddLeftGroupbox('ESP Controls')

ESPGroup:AddToggle('ESPToggle', {
    Text = 'Enable ESP',
    Default = false,
    Tooltip = 'Toggle ESP for animals',
    Callback = function(Value)
        ESPEnabled = Value
        scanAnimals()
    end
})

ESPGroup:AddToggle('ShowNameToggle', {
    Text = 'Show Name',
    Default = true,
    Tooltip = 'Display animal name',
    Callback = function(Value)
        ShowName = Value
    end
})

ESPGroup:AddToggle('ShowDistanceToggle', {
    Text = 'Show Distance',
    Default = true,
    Tooltip = 'Display distance to animal',
    Callback = function(Value)
        ShowDistance = Value
    end
})

ESPGroup:AddSlider('MaxDistanceSlider', {
    Text = 'Max ESP Distance',
    Default = 1000,
    Min = 100,
    Max = 5000,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        MaxDistance = Value
    end
})

ESPGroup:AddSlider('TransparencySlider', {
    Text = 'Transparency',
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Compact = false,
    Callback = function(Value)
        ESPTransparency = Value
    end
})

-- ESP Color Group
local ColorGroup = Tabs.ESP:AddRightGroupbox('ESP Colors')

ColorGroup:AddLabel('ESP Color'):AddColorPicker('ESPColor', {
    Default = Color3.fromRGB(255, 0, 0),
    Title = 'ESP Color',
    Transparency = 0,
    Callback = function(Value)
        ESPColor = Value
    end
})

ColorGroup:AddButton({
    Text = 'Refresh ESP',
    Func = function()
        scanAnimals()
        Library:Notify('ESP Refreshed!', 3)
    end,
    DoubleClick = false,
    Tooltip = 'Manually refresh ESP'
})

-- ==================== AIMBOT TAB ====================
local AimbotGroup = Tabs.Aimbot:AddLeftGroupbox('Aimbot Controls')

AimbotGroup:AddToggle('AimbotToggle', {
    Text = 'Enable Aimbot',
    Default = false,
    Tooltip = 'Toggle Aimbot on/off',
    Callback = function(Value)
        AimbotEnabled = Value
    end
})

AimbotGroup:AddToggle('ShowFOVToggle', {
    Text = 'Show FOV Circle',
    Default = true,
    Tooltip = 'Display FOV circle',
    Callback = function(Value)
        ShowFOVCircle = Value
        FOVCircle.Visible = Value
    end
})

AimbotGroup:AddToggle('VisibilityToggle', {
    Text = 'Visibility Check',
    Default = false,
    Tooltip = 'Only aim at visible animals',
    Callback = function(Value)
        VisibilityCheck = Value
    end
})

AimbotGroup:AddSlider('FOVSlider', {
    Text = 'FOV (Radius)',
    Default = 200,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        AimbotFOV = Value
        FOVCircle.Radius = Value
    end
})

AimbotGroup:AddSlider('SmoothingSlider', {
    Text = 'Smoothing',
    Default = 0.1,
    Min = 0.01,
    Max = 1,
    Rounding = 2,
    Compact = false,
    Callback = function(Value)
        AimbotSmoothing = Value
    end
})

AimbotGroup:AddSlider('AimbotDistanceSlider', {
    Text = 'Max Aimbot Distance',
    Default = 500,
    Min = 50,
    Max = 2000,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        AimbotMaxDistance = Value
    end
})

-- Aimbot Settings
local AimbotSettings = Tabs.Aimbot:AddRightGroupbox('Aim Settings')

AimbotSettings:AddDropdown('TargetPartDropdown', {
    Values = {'Head', 'HumanoidRootPart', 'Torso'},
    Default = 1,
    Multi = false,
    Text = 'Target Body Part',
    Tooltip = 'Select animal part to aim at',
    Callback = function(Value)
        TargetPart = Value
    end
})

AimbotSettings:AddLabel('Aimbot Key:')
AimbotSettings:AddLabel('Current: E'):AddKeyPicker('AimbotKeyPicker', {
    Default = 'E',
    SyncToggleState = false,
    Mode = 'Hold',
    Text = 'Aimbot Key',
    NoUI = false,
    Callback = function(Value)
        AimbotKey = Value
    end,
})

AimbotSettings:AddLabel('FOV Circle Color'):AddColorPicker('FOVColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'FOV Color',
    Transparency = 0,
    Callback = function(Value)
        FOVCircle.Color = Value
    end
})

-- ==================== ARROWS TAB ====================
local ArrowGroup = Tabs.Arrows:AddLeftGroupbox('Off-Screen Arrows')

ArrowGroup:AddToggle('ArrowToggle', {
    Text = 'Enable Off-Screen Arrows',
    Default = true,
    Tooltip = 'Show arrows pointing to off-screen animals',
    Callback = function(Value)
        ShowOffScreenArrows = Value
        if not Value then
            for _, arrow in pairs(ArrowDrawings) do
                arrow.Visible = false
            end
        end
    end
})

ArrowGroup:AddSlider('ArrowSizeSlider', {
    Text = 'Arrow Size',
    Default = 20,
    Min = 10,
    Max = 50,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        ArrowSize = Value
    end
})

ArrowGroup:AddSlider('ArrowDistanceSlider', {
    Text = 'Arrow Distance from Center',
    Default = 150,
    Min = 50,
    Max = 400,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        ArrowDistance = Value
    end
})

ArrowGroup:AddSlider('ArrowTransparencySlider', {
    Text = 'Arrow Transparency',
    Default = 0.8,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Compact = false,
    Callback = function(Value)
        ArrowTransparency = Value
    end
})

-- Arrow Color Group
local ArrowColorGroup = Tabs.Arrows:AddRightGroupbox('Arrow Colors')

ArrowColorGroup:AddLabel('Arrow Color'):AddColorPicker('ArrowColor', {
    Default = Color3.fromRGB(255, 255, 0),
    Title = 'Arrow Color',
    Transparency = 0,
    Callback = function(Value)
        ArrowColor = Value
    end
})

ArrowColorGroup:AddButton({
    Text = 'Test Arrows',
    Func = function()
        Library:Notify('Look around to see off-screen arrows!', 5)
    end,
    DoubleClick = false,
    Tooltip = 'Test arrow functionality'
})

-- Add Theme Manager and Save Manager
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

ThemeManager:SetFolder('AnimalESPAimbot')
SaveManager:SetFolder('AnimalESPAimbot/configs')

SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])

SaveManager:LoadAutoloadConfig()

-- Monitor new animals
local animalsFolder = workspace:WaitForChild("Gameplay"):WaitForChild("Dynamic"):WaitForChild("Animals")

animalsFolder.ChildAdded:Connect(function(animal)
    wait(0.1)
    if ESPEnabled then
        createESP(animal)
    end
end)

animalsFolder.ChildRemoved:Connect(function(animal)
    removeESP(animal)
end)

-- Main Update Loop
RunService.RenderStepped:Connect(function()
    -- Update ESP
    if ESPEnabled then
        updateESP()
    end
    
    -- Update FOV Circle
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Visible = ShowFOVCircle and AimbotEnabled
    
    -- Update Off-Screen Arrows
    updateOffScreenArrows()
end)

-- Aimbot Loop
RunService.RenderStepped:Connect(function()
    if AimbotEnabled then
        local keyPickerState = Options.AimbotKeyPicker:GetState()
        
        if keyPickerState then
            local target = getClosestAnimal()
            if target then
                aimAt(target)
            end
        end
    end
end)

-- Auto scan every 5 seconds
spawn(function()
    while wait(5) do
        scanAnimals()
    end
end)

-- Initial scan
scanAnimals()

Library:Notify('Animal ESP + Aimbot + Arrows Loaded!', 5)
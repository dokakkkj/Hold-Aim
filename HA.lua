-- ============================================
-- Configurações iniciais
-- ============================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local settings = {
    Enabled = true,
    TeamCheck = true,
    Smoothness = 0.2,
    FOV = 120,
    ShowFOV = true,
    FOVVisible = true,
    TargetPart = "Head",
    TriggerKey = Enum.KeyCode.ButtonR2,
    LockedTarget = nil,
    AutoLock = false,
    HoldLocked = false,
    MouseHoldEnabled = true, -- 🔥 NOVO: ativar hold no mouse esquerdo
}

-- ============================================
-- 🎨 GUI PRINCIPAL NO CoreGui
-- ============================================
local AimGui = Instance.new("ScreenGui")
AimGui.Name = "MobileAimBotPro"
AimGui.ResetOnSpawn = false
AimGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
AimGui.DisplayOrder = 999
AimGui.Parent = CoreGui

-- ============================================
-- 🔴 BOTÃO HOLD (CLICK-THROUGH + OVERLAY)
-- ============================================
local HoldBtnGui = Instance.new("ScreenGui")
HoldBtnGui.Name = "HoldButtonGui"
HoldBtnGui.ResetOnSpawn = false
HoldBtnGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
HoldBtnGui.DisplayOrder = 99999
HoldBtnGui.IgnoreGuiInset = true
HoldBtnGui.Parent = CoreGui

local HoldButton = Instance.new("TextButton")
HoldButton.Name = "HoldAimbotButton"
HoldButton.Size = UDim2.new(0, 120, 0, 120)
HoldButton.Position = UDim2.new(0.85, 0, 0.75, 0)
HoldButton.AnchorPoint = Vector2.new(0.5, 0.5)
HoldButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
HoldButton.BackgroundTransparency = 0.4
HoldButton.Text = "HOLD\nAIM"
HoldButton.TextColor3 = Color3.fromRGB(255, 255, 255)
HoldButton.Font = Enum.Font.GothamBold
HoldButton.TextSize = 16
HoldButton.TextWrapped = true

HoldButton.Active = false
HoldButton.Selectable = false
HoldButton.Modal = false
HoldButton.AutoButtonColor = false

HoldButton.Parent = HoldBtnGui

local HoldCorner = Instance.new("UICorner")
HoldCorner.CornerRadius = UDim.new(1, 0)
HoldCorner.Parent = HoldButton

local HoldStroke = Instance.new("UIStroke")
HoldStroke.Thickness = 2
HoldStroke.Color = Color3.fromRGB(255, 255, 255)
HoldStroke.Transparency = 0.3
HoldStroke.Parent = HoldButton

-- ============================================
-- 🔥 ESTADO DO HOLD
-- ============================================
local isHolding = false
local holdBtnTouching = false
local holdBtnTouchId = nil
local mouseHolding = false

local function SetHoldState(state)
    isHolding = state
    settings.Enabled = state

    if state then
        HoldButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        HoldButton.Text = "AIM\nON"
        HoldStroke.Color = Color3.fromRGB(0, 255, 100)
    else
        HoldButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
        HoldButton.Text = "HOLD\nAIM"
        HoldStroke.Color = Color3.fromRGB(255, 255, 255)
        ResetLockedTarget()
    end

    if ToggleBtn then
        ToggleBtn.Text = "AIMBOT: " .. (state and "ON" or "OFF")
        ToggleBtn.BackgroundColor3 = state and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(80, 80, 80)
    end
end

local function IsPointInsideHoldButton(x, y)
    local abs = HoldButton.AbsolutePosition
    local size = HoldButton.AbsoluteSize
    local centerX = abs.X + size.X / 2
    local centerY = abs.Y + size.Y / 2
    local halfW = size.X / 2
    local halfH = size.Y / 2
    return (x >= centerX - halfW and x <= centerX + halfW and
            y >= centerY - halfH and y <= centerY + halfH)
end

-- ============================================
-- 🔥 DETECÇÃO DE TOQUE (mobile)
-- ============================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Touch then
        local pos = input.Position
        if IsPointInsideHoldButton(pos.X, pos.Y) then
            holdBtnTouching = true
            holdBtnTouchId = input
            SetHoldState(true)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Touch then
        if holdBtnTouchId == input or holdBtnTouching then
            holdBtnTouching = false
            holdBtnTouchId = nil
            SetHoldState(false)
        end
    end
end)

-- ============================================
-- 🔥 DETECÇÃO DO MOUSE ESQUERDO (HOLD)
-- ============================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if not settings.MouseHoldEnabled then return end
        mouseHolding = true
        SetHoldState(true)
        print("🖱️ HOLD ATIVADO (mouse esquerdo)")
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if not settings.MouseHoldEnabled then return end
        mouseHolding = false
        SetHoldState(false)
        print("🖱️ HOLD DESATIVADO (mouse esquerdo)")
    end
end)

-- ============================================
-- 🔥 ARRASTAR (só se não estiver travado)
-- ============================================
local dragStartPos = nil
local buttonStartPos = nil
local isDragging = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Touch then
        if settings.HoldLocked then return end
        local pos = input.Position
        if IsPointInsideHoldButton(pos.X, pos.Y) then
            dragStartPos = pos
            buttonStartPos = HoldButton.Position
            isDragging = false
        end
    end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Touch and dragStartPos then
        if settings.HoldLocked then return end
        local delta = input.Position - dragStartPos
        if math.abs(delta.X) > 15 or math.abs(delta.Y) > 15 then
            isDragging = true
            HoldButton.Position = UDim2.new(
                buttonStartPos.X.Scale,
                buttonStartPos.X.Offset + delta.X,
                buttonStartPos.Y.Scale,
                buttonStartPos.Y.Offset + delta.Y
            )
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Touch then
        dragStartPos = nil
        isDragging = false
    end
end)

-- ============================================
-- BOTÕES MÓVEIS
-- ============================================
local function CreateMovableButton(name, text, position, size, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = text
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.Active = true
    button.Draggable = true
    button.Parent = AimGui

    local dragStartPos, buttonStartPos

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragStartPos = input.Position
            buttonStartPos = button.Position
            game:GetService("RunService").Heartbeat:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    return
                end
                local delta = input.Position - dragStartPos
                button.Position = UDim2.new(
                    buttonStartPos.X.Scale,
                    buttonStartPos.X.Offset + delta.X,
                    buttonStartPos.Y.Scale,
                    buttonStartPos.Y.Offset + delta.Y
                )
            end)
        end
    end)

    return button
end

local ToggleBtn = CreateMovableButton(
    "AimbotToggle",
    "AIMBOT: ON",
    UDim2.new(0, 10, 0, 10),
    UDim2.new(0, 120, 0, 50),
    Color3.fromRGB(0, 120, 255)
)

local OpenGuiBtn = CreateMovableButton(
    "OpenGUI",
    "⚙️ CONFIG",
    UDim2.new(0, 10, 0, 70),
    UDim2.new(0, 120, 0, 50),
    Color3.fromRGB(60, 60, 60)
)

-- ============================================
-- FRAME DE CONFIGURAÇÕES
-- ============================================
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 350, 0, 520)
MainFrame.Position = UDim2.new(0.5, -175, 0.5, -260)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = false
MainFrame.Parent = AimGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 50)
Title.Text = "Dkkkj HUB Auge🎯"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.Parent = MainFrame

-- Smoothness
local SmoothnessLabel = Instance.new("TextLabel")
SmoothnessLabel.Size = UDim2.new(0.9, 0, 0, 25)
SmoothnessLabel.Position = UDim2.new(0.05, 0, 0.10, 0)
SmoothnessLabel.Text = "Smoothness: " .. settings.Smoothness
SmoothnessLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SmoothnessLabel.BackgroundTransparency = 1
SmoothnessLabel.Font = Enum.Font.Gotham
SmoothnessLabel.TextSize = 14
SmoothnessLabel.TextXAlignment = Enum.TextXAlignment.Left
SmoothnessLabel.Parent = MainFrame

local SmoothnessSlider = Instance.new("Frame")
SmoothnessSlider.Size = UDim2.new(0.9, 0, 0, 15)
SmoothnessSlider.Position = UDim2.new(0.05, 0, 0.15, 0)
SmoothnessSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SmoothnessSlider.BorderSizePixel = 0
SmoothnessSlider.Parent = MainFrame

local SmoothnessFill = Instance.new("Frame")
SmoothnessFill.Size = UDim2.new(settings.Smoothness, 0, 1, 0)
SmoothnessFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
SmoothnessFill.BorderSizePixel = 0
SmoothnessFill.Parent = SmoothnessSlider

-- FOV
local FOVLabel = Instance.new("TextLabel")
FOVLabel.Size = UDim2.new(0.9, 0, 0, 25)
FOVLabel.Position = UDim2.new(0.05, 0, 0.20, 0)
FOVLabel.Text = "FOV Radius: " .. settings.FOV
FOVLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
FOVLabel.BackgroundTransparency = 1
FOVLabel.Font = Enum.Font.Gotham
FOVLabel.TextSize = 14
FOVLabel.TextXAlignment = Enum.TextXAlignment.Left
FOVLabel.Parent = MainFrame

local FOVSlider = Instance.new("Frame")
FOVSlider.Size = UDim2.new(0.9, 0, 0, 15)
FOVSlider.Position = UDim2.new(0.05, 0, 0.25, 0)
FOVSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
FOVSlider.BorderSizePixel = 0
FOVSlider.Parent = MainFrame

local FOVFill = Instance.new("Frame")
FOVFill.Size = UDim2.new(settings.FOV / 200, 0, 1, 0)
FOVFill.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
FOVFill.BorderSizePixel = 0
FOVFill.Parent = FOVSlider

-- Auto Lock
local AutoLockBtn = Instance.new("TextButton")
AutoLockBtn.Size = UDim2.new(0.9, 0, 0, 35)
AutoLockBtn.Position = UDim2.new(0.05, 0, 0.32, 0)
AutoLockBtn.Text = "AUTO LOCK: OFF"
AutoLockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoLockBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
AutoLockBtn.Font = Enum.Font.Gotham
AutoLockBtn.TextSize = 14
AutoLockBtn.Parent = MainFrame

-- Team Check
local TeamCheckBtn = Instance.new("TextButton")
TeamCheckBtn.Size = UDim2.new(0.9, 0, 0, 35)
TeamCheckBtn.Position = UDim2.new(0.05, 0, 0.39, 0)
TeamCheckBtn.Text = "TEAM CHECK: ON"
TeamCheckBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TeamCheckBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
TeamCheckBtn.Font = Enum.Font.Gotham
TeamCheckBtn.TextSize = 14
TeamCheckBtn.Parent = MainFrame

-- Target Part
local validParts = {"Head", "HumanoidRootPart"}
local currentPartIndex = 1

local PartDropdown = Instance.new("TextButton")
PartDropdown.Size = UDim2.new(0.9, 0, 0, 35)
PartDropdown.Position = UDim2.new(0.05, 0, 0.46, 0)
PartDropdown.Text = "TARGET: " .. validParts[currentPartIndex]
PartDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
PartDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
PartDropdown.Font = Enum.Font.Gotham
PartDropdown.TextSize = 14
PartDropdown.Parent = MainFrame

-- FOV Toggle
local ToggleFOVBtn = Instance.new("TextButton")
ToggleFOVBtn.Size = UDim2.new(0.9, 0, 0, 35)
ToggleFOVBtn.Position = UDim2.new(0.05, 0, 0.53, 0)
ToggleFOVBtn.Text = "MOSTRAR FOV: ON"
ToggleFOVBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleFOVBtn.BackgroundColor3 = settings.ShowFOV and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 60)
ToggleFOVBtn.Font = Enum.Font.Gotham
ToggleFOVBtn.TextSize = 14
ToggleFOVBtn.Parent = MainFrame

-- 🔒 Travar HOLD
local LockHoldBtn = Instance.new("TextButton")
LockHoldBtn.Size = UDim2.new(0.9, 0, 0, 35)
LockHoldBtn.Position = UDim2.new(0.05, 0, 0.60, 0)
LockHoldBtn.Text = "🔒 TRAVAR HOLD: OFF"
LockHoldBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
LockHoldBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
LockHoldBtn.Font = Enum.Font.GothamBold
LockHoldBtn.TextSize = 14
LockHoldBtn.Parent = MainFrame

-- ============================================
-- 🖱️ NOVO: ATIVAR HOLD NO MOUSE ESQUERDO
-- ============================================
local MouseHoldBtn = Instance.new("TextButton")
MouseHoldBtn.Size = UDim2.new(0.9, 0, 0, 35)
MouseHoldBtn.Position = UDim2.new(0.05, 0, 0.67, 0)
MouseHoldBtn.Text = "🖱️ HOLD MOUSE: ON"
MouseHoldBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MouseHoldBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
MouseHoldBtn.Font = Enum.Font.GothamBold
MouseHoldBtn.TextSize = 14
MouseHoldBtn.Parent = MainFrame

-- Bind
local BindKeyBtn = Instance.new("TextButton")
BindKeyBtn.Size = UDim2.new(0.9, 0, 0, 35)
BindKeyBtn.Position = UDim2.new(0.05, 0, 0.74, 0)
BindKeyBtn.Text = "CLIQUE PARA BINDAR"
BindKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
BindKeyBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
BindKeyBtn.Font = Enum.Font.Gotham
BindKeyBtn.TextSize = 14
BindKeyBtn.Parent = MainFrame

local BindKeyLabel = Instance.new("TextLabel")
BindKeyLabel.Size = UDim2.new(0.9, 0, 0, 25)
BindKeyLabel.Position = UDim2.new(0.05, 0, 0.81, 0)
BindKeyLabel.Text = "Tecla de Toggle: " .. settings.TriggerKey.Name
BindKeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
BindKeyLabel.BackgroundTransparency = 1
BindKeyLabel.Font = Enum.Font.Gotham
BindKeyLabel.TextSize = 14
BindKeyLabel.TextXAlignment = Enum.TextXAlignment.Left
BindKeyLabel.Parent = MainFrame

-- FOV Circle
local FOVCircle = Instance.new("Frame")
FOVCircle.Size = UDim2.new(0, settings.FOV * 2, 0, settings.FOV * 2)
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.Position = UDim2.new(0.5, 0, 0.434, 0)
FOVCircle.BackgroundTransparency = 1
FOVCircle.BorderSizePixel = 0
FOVCircle.Visible = settings.ShowFOV and settings.FOVVisible
FOVCircle.Parent = AimGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(1, 0)
UICorner.Parent = FOVCircle

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(0, 200, 100)
UIStroke.Thickness = 2
UIStroke.Parent = FOVCircle

local isBinding = false

-- ============================================
-- FUNÇÕES DE VALIDAÇÃO
-- ============================================
local function IsTargetValid(target)
    if not target then return false end
    if not target.Character then return false end
    local humanoid = target.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local targetPart = target.Character:FindFirstChild(settings.TargetPart)
    if not targetPart then return false end
    return true
end

local function IsTargetVisible(targetPart)
    if not targetPart then return false end
    local cameraPos = Camera.CFrame.Position
    local targetPos = targetPart.Position
    local direction = (targetPos - cameraPos).Unit
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local raycastResult = workspace:Raycast(cameraPos, direction * (targetPos - cameraPos).Magnitude, raycastParams)
    return not raycastResult
end

local function FindClosestTarget()
    local closestPlayer = nil
    local shortestDistance = settings.FOV
    local viewportCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not IsTargetValid(player) then continue end
        local targetPart = player.Character:FindFirstChild(settings.TargetPart)
        if not targetPart then continue end
        if settings.TeamCheck and player.Team == LocalPlayer.Team then continue end
        local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        local screenPos = Vector2.new(screenPoint.X, screenPoint.Y)
        local distance = (screenPos - viewportCenter).Magnitude
        if distance < shortestDistance and IsTargetVisible(targetPart) then
            closestPlayer = player
            shortestDistance = distance
        end
    end

    return closestPlayer
end

local function LockOnTarget(target)
    if not target or not target.Character then return end
    local targetPart = target.Character:FindFirstChild(settings.TargetPart)
    if not targetPart then return end
    local cameraPos = Camera.CFrame.Position
    local targetPos = targetPart.Position
    local direction = (targetPos - cameraPos).Unit
    local currentLook = Camera.CFrame.LookVector
    local newLook = currentLook:Lerp(direction, settings.Smoothness)
    Camera.CFrame = CFrame.new(cameraPos, cameraPos + newLook)

    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local playerRootPart = LocalPlayer.Character.HumanoidRootPart
        local playerPos = playerRootPart.Position
        local horizontalDirection = Vector3.new(newLook.X, 0, newLook.Z).Unit
        local currentPlayerLook = playerRootPart.CFrame.LookVector
        local horizontalPlayerLook = Vector3.new(currentPlayerLook.X, 0, currentPlayerLook.Z).Unit
        local smoothedPlayerLook = horizontalPlayerLook:Lerp(horizontalDirection, settings.Smoothness * 0.1)
        playerRootPart.CFrame = CFrame.lookAt(playerPos, playerPos + smoothedPlayerLook)
    end
end

function ResetLockedTarget()
    settings.LockedTarget = nil
    FOVCircle.UIStroke.Color = Color3.fromRGB(0, 200, 100)
end

-- ============================================
-- CONTROLES UI
-- ============================================
ToggleBtn.MouseButton1Click:Connect(function()
    settings.Enabled = not settings.Enabled
    ToggleBtn.Text = "AIMBOT: " .. (settings.Enabled and "ON" or "OFF")
    ToggleBtn.BackgroundColor3 = settings.Enabled and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(80, 80, 80)
    if not settings.Enabled then ResetLockedTarget() end
end)

OpenGuiBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

PartDropdown.MouseButton1Click:Connect(function()
    currentPartIndex = currentPartIndex + 1
    if currentPartIndex > #validParts then currentPartIndex = 1 end
    PartDropdown.Text = "TARGET: " .. validParts[currentPartIndex]
    settings.TargetPart = validParts[currentPartIndex]
    ResetLockedTarget()
end)

ToggleFOVBtn.MouseButton1Click:Connect(function()
    settings.ShowFOV = not settings.ShowFOV
    ToggleFOVBtn.Text = "MOSTRAR FOV: " .. (settings.ShowFOV and "ON" or "OFF")
    ToggleFOVBtn.BackgroundColor3 = settings.ShowFOV and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 60)
    FOVCircle.Visible = settings.ShowFOV and settings.FOVVisible
end)

-- 🔒 Travar HOLD
LockHoldBtn.MouseButton1Click:Connect(function()
    settings.HoldLocked = not settings.HoldLocked
    LockHoldBtn.Text = "🔒 TRAVAR HOLD: " .. (settings.HoldLocked and "ON" or "OFF")
    LockHoldBtn.BackgroundColor3 = settings.HoldLocked 
        and Color3.fromRGB(200, 50, 50) 
        or Color3.fromRGB(80, 80, 80)

    if settings.HoldLocked then
        HoldStroke.Color = Color3.fromRGB(255, 200, 0)
        HoldStroke.Thickness = 3
        print("🔒 Botão HOLD TRAVADO")
    else
        if isHolding then
            HoldStroke.Color = Color3.fromRGB(0, 255, 100)
        else
            HoldStroke.Color = Color3.fromRGB(255, 255, 255)
        end
        HoldStroke.Thickness = 2
        print("🔓 Botão HOLD LIBERADO")
    end
end)

-- ============================================
-- 🖱️ ATIVAR/DESATIVAR HOLD NO MOUSE ESQUERDO
-- ============================================
MouseHoldBtn.MouseButton1Click:Connect(function()
    settings.MouseHoldEnabled = not settings.MouseHoldEnabled
    MouseHoldBtn.Text = "🖱️ HOLD MOUSE: " .. (settings.MouseHoldEnabled and "ON" or "OFF")
    MouseHoldBtn.BackgroundColor3 = settings.MouseHoldEnabled 
        and Color3.fromRGB(0, 200, 100) 
        or Color3.fromRGB(80, 80, 80)
    print("🖱️ Hold no mouse esquerdo:", settings.MouseHoldEnabled and "ATIVADO" or "DESATIVADO")
end)

-- Smoothness slider
local isSmoothnessDragging = false
SmoothnessSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        isSmoothnessDragging = true
        local mousePos = UserInputService:GetMouseLocation()
        local sliderAbsolutePos = SmoothnessSlider.AbsolutePosition.X
        local sliderSize = SmoothnessSlider.AbsoluteSize.X
        local relativeX = math.clamp(mousePos.X - sliderAbsolutePos, 0, sliderSize)
        local ratio = relativeX / sliderSize
        local newValue = 0.1 + (ratio * 0.9)
        settings.Smoothness = math.floor(newValue * 100) / 100
        SmoothnessFill.Size = UDim2.new(ratio, 0, 1, 0)
        SmoothnessLabel.Text = "Smoothness: " .. settings.Smoothness
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isSmoothnessDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local mousePos = input.Position
        local sliderAbsolutePos = SmoothnessSlider.AbsolutePosition.X
        local sliderSize = SmoothnessSlider.AbsoluteSize.X
        local relativeX = math.clamp(mousePos.X - sliderAbsolutePos, 0, sliderSize)
        local ratio = relativeX / sliderSize
        local newValue = 0.1 + (ratio * 0.9)
        settings.Smoothness = math.floor(newValue * 100) / 100
        SmoothnessFill.Size = UDim2.new(ratio, 0, 1, 0)
        SmoothnessLabel.Text = "Smoothness: " .. settings.Smoothness
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        isSmoothnessDragging = false
    end
end)

-- FOV slider
local isFOVDragging = false
FOVSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        isFOVDragging = true
        local mousePos = UserInputService:GetMouseLocation()
        local sliderAbsolutePos = FOVSlider.AbsolutePosition.X
        local sliderSize = FOVSlider.AbsoluteSize.X
        local relativeX = math.clamp(mousePos.X - sliderAbsolutePos, 0, sliderSize)
        local ratio = relativeX / sliderSize
        local newValue = 50 + (ratio * 150)
        settings.FOV = math.floor(newValue)
        FOVFill.Size = UDim2.new(ratio, 0, 1, 0)
        FOVLabel.Text = "FOV Radius: " .. settings.FOV
        FOVCircle.Size = UDim2.new(0, settings.FOV * 2, 0, settings.FOV * 2)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isFOVDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local mousePos = input.Position
        local sliderAbsolutePos = FOVSlider.AbsolutePosition.X
        local sliderSize = FOVSlider.AbsoluteSize.X
        local relativeX = math.clamp(mousePos.X - sliderAbsolutePos, 0, sliderSize)
        local ratio = relativeX / sliderSize
        local newValue = 50 + (ratio * 150)
        settings.FOV = math.floor(newValue)
        FOVFill.Size = UDim2.new(ratio, 0, 1, 0)
        FOVLabel.Text = "FOV Radius: " .. settings.FOV
        FOVCircle.Size = UDim2.new(0, settings.FOV * 2, 0, settings.FOV * 2)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        isFOVDragging = false
    end
end)

AutoLockBtn.MouseButton1Click:Connect(function()
    settings.AutoLock = not settings.AutoLock
    AutoLockBtn.Text = "AUTO LOCK: " .. (settings.AutoLock and "ON" or "OFF")
    AutoLockBtn.BackgroundColor3 = settings.AutoLock and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(80, 80, 80)
    ResetLockedTarget()
end)

TeamCheckBtn.MouseButton1Click:Connect(function()
    settings.TeamCheck = not settings.TeamCheck
    TeamCheckBtn.Text = "TEAM CHECK: " .. (settings.TeamCheck and "ON" or "OFF")
    ResetLockedTarget()
end)

BindKeyBtn.MouseButton1Click:Connect(function()
    if not isBinding then
        isBinding = true
        BindKeyBtn.Text = "PRESSIONE UMA TECLA..."
        BindKeyBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if isBinding then
        settings.TriggerKey = input.KeyCode
        BindKeyLabel.Text = "Tecla de Toggle: " .. input.KeyCode.Name
        BindKeyBtn.Text = "CLIQUE PARA BINDAR"
        BindKeyBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
        isBinding = false
    end
    if input.KeyCode == settings.TriggerKey then
        settings.Enabled = not settings.Enabled
        ToggleBtn.Text = "AIMBOT: " .. (settings.Enabled and "ON" or "OFF")
        ToggleBtn.BackgroundColor3 = settings.Enabled and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(80, 80, 80)
        if not settings.Enabled then ResetLockedTarget() end
    end
end)

-- ============================================
-- LOOP PRINCIPAL
-- ============================================
RunService.RenderStepped:Connect(function()
    FOVCircle.Visible = settings.ShowFOV and settings.FOVVisible
    FOVCircle.Size = UDim2.new(0, settings.FOV * 2, 0, settings.FOV * 2)

    if settings.LockedTarget and not IsTargetValid(settings.LockedTarget) then
        ResetLockedTarget()
    end

    if settings.Enabled then
        if settings.AutoLock and not settings.LockedTarget then
            settings.LockedTarget = FindClosestTarget()
        end

        if settings.LockedTarget then
            local targetPart = settings.LockedTarget.Character:FindFirstChild(settings.TargetPart)
            if targetPart and IsTargetVisible(targetPart) then
                local screenPoint = Camera:WorldToViewportPoint(targetPart.Position)
                local viewportCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                local screenPos = Vector2.new(screenPoint.X, screenPoint.Y)
                local distance = (screenPos - viewportCenter).Magnitude

                if distance <= settings.FOV then
                    LockOnTarget(settings.LockedTarget)
                    FOVCircle.UIStroke.Color = Color3.fromRGB(255, 50, 50)
                else
                    ResetLockedTarget()
                end
            else
                ResetLockedTarget()
            end
        else
            FOVCircle.UIStroke.Color = Color3.fromRGB(0, 200, 100)
        end
    else
        FOVCircle.UIStroke.Color = Color3.fromRGB(0, 200, 100)
    end
end)

GuiService.MenuOpened:Connect(function()
    GuiService:ClearError()
end)

print("✅ Mobile Aimbot Pro (CoreGui) carregado!")
print("🖱️ HOLD no mouse esquerdo ativado por padrão")
print("🔒 Botão HOLD pode ser travado na GUI")

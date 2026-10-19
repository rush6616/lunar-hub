-- language: Lua (Roblox Luau), file: lunar_hub_afk_farm.lua
-- target: Madium executor
-- OBJETIVO: Farmar conchas, bolinha customizada, configs e tema forçado.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==========================================
-- ESTADO GLOBAL & CONFIG
-- ==========================================
local estadoShell = { ativo = false, modo = "Insta", pegas = 0, espCache = {}, processando = false }
local estadoAFK = { ativo = false }
local config = { teclaMenu = Enum.KeyCode.RightControl.Name, interface_aberta = false }
local CONFIG_FILE = "lunar_hub_config.json"

local function salvarConfig()
    if writefile then
        pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(config)) end)
    end
end

local function carregarConfig()
    if isfile and readfile and isfile(CONFIG_FILE) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
        if ok and data and data.teclaMenu then
            config.teclaMenu = data.teclaMenu
        end
    end
end
carregarConfig()

-- ==========================================
-- ANTI-AFK HARDCORE
-- ==========================================
LocalPlayer.Idled:Connect(function()
    if not estadoAFK.ativo then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end)

task.spawn(function()
    while task.wait(60) do
        if not estadoAFK.ativo then continue end
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChild("Humanoid")
            if hrp and humanoid then
                local oldPos = hrp.CFrame
                hrp.CFrame = oldPos * CFrame.new(0, 0, 0.1)
                task.wait(0.2)
                hrp.CFrame = oldPos
                if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
    end
end)

task.spawn(function()
    local angulo = 0
    while task.wait(0.1) do
        if estadoAFK.ativo then
            angulo = angulo + 1
            pcall(function()
                Camera.CFrame = CFrame.new(Camera.CFrame.Position) * CFrame.Angles(0, math.rad(math.sin(angulo) * 2), 0)
            end)
        end
    end
end)

-- ==========================================
-- BOLINHA FLUTUANTE (DRAG)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LunarHubBtn"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local BotaoFlutuante = Instance.new("ImageButton")
BotaoFlutuante.Size = UDim2.new(0, 60, 0, 60)
BotaoFlutuante.Position = UDim2.new(0, 20, 0.5, -30)
BotaoFlutuante.BackgroundColor3 = Color3.fromRGB(11, 19, 43)
BotaoFlutuante.Image = "rbxassetid://82780319797698" 
BotaoFlutuante.ScaleType = Enum.ScaleType.Crop
BotaoFlutuante.Active = true
BotaoFlutuante.Visible = true
BotaoFlutuante.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(1, 0)
Corner.Parent = BotaoFlutuante

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(91, 192, 190)
Stroke.Thickness = 3
Stroke.Parent = BotaoFlutuante

local arrastando, arrastou, startPos, startMouse = false, false, nil, nil

BotaoFlutuante.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        arrastando = true
        arrastou = false
        startMouse = input.Position
        startPos = BotaoFlutuante.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if arrastando and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - startMouse
        if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
            arrastou = true
            BotaoFlutuante.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        arrastando = false
    end
end)

-- ==========================================
-- CARREGANDO A INTERFACE (WINDUI) E TEMA FORÇADO
-- ==========================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Lunar Hub",
    Author = "por rush", -- <-- Alterado aqui
    Folder = "LunarHub",
    Size = UDim2.fromOffset(500, 400),
    Theme = "Dark",
    Transparent = true,
})

-- FORÇA A COR DEPOIS QUE CRIA A JANELA
task.spawn(function()
    task.wait(1.5)
    
    local mainFrame = Window.Root or Window.Container or Window.MainFrame
    if not mainFrame then return end

    local function pintar(inst)
        if inst:IsA("Frame") or inst:IsA("TextButton") or inst:IsA("ImageButton") then
            if inst.BackgroundColor3 == Color3.fromRGB(0, 0, 0) or inst.BackgroundColor3 == Color3.fromRGB(20, 20, 20) then
                inst.BackgroundColor3 = Color3.fromRGB(11, 19, 43) 
            end
        end
        if inst:IsA("TextLabel") then
            if inst.TextColor3 == Color3.fromRGB(255, 255, 255) then
                inst.TextColor3 = Color3.fromRGB(240, 245, 255)
            end
        end
        if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
            if inst.ImageColor3 == Color3.fromRGB(255, 255, 255) then
                inst.ImageColor3 = Color3.fromRGB(91, 192, 190)
            end
        end
    end

    for _, v in ipairs(mainFrame:GetDescendants()) do
        pintar(v)
    end
    mainFrame.DescendantAdded:Connect(pintar)
end)

local function fecharMenu()
    pcall(function()
        if Window.Close then Window:Close() end
    end)
    config.interface_aberta = false
    BotaoFlutuante.Visible = true 
end

local function abrirMenu()
    pcall(function()
        if Window.Open then Window:Open() end
    end)
    config.interface_aberta = true
    BotaoFlutuante.Visible = false 
end

task.spawn(function()
    task.wait(0.5)
    fecharMenu()
end)

BotaoFlutuante.MouseButton1Click:Connect(function()
    if not arrastou then abrirMenu() end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local keyName = tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
    if keyName == config.teclaMenu then
        if config.interface_aberta then
            fecharMenu()
        else
            abrirMenu()
        end
    end
end)

-- ==========================================
-- ABAS
-- ==========================================
local MainTab = Window:Tab({ Title = "Ocean Event", Icon = "shell" })
local ConfigTab = Window:Tab({ Title = "Config", Icon = "settings" })

-- ==========================================
-- LÓGICA SHELL HUNT
-- ==========================================
local function getShells()
    local found = {}
    local folder = workspace:FindFirstChild("ShellHunt")
    if not folder then return found end
    for _, obj in ipairs(folder:GetChildren()) do
        if (obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart")) then
            local mainPart = obj:FindFirstChildWhichIsA("BasePart") or (obj:IsA("BasePart") and obj)
            if mainPart then table.insert(found, {obj = obj, part = mainPart}) end
        end
    end
    return found
end

RunService.RenderStepped:Connect(function()
    if not estadoShell.ativo or estadoShell.processando then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local shells = getShells()
    
    for _, s in ipairs(shells) do
        if not estadoShell.espCache[s.obj] then
            local hl = Instance.new("Highlight")
            hl.Adornee = s.obj
            hl.FillColor = Color3.fromRGB(91, 192, 190)
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = game:GetService("CoreGui")
            estadoShell.espCache[s.obj] = hl
        end
    end

    if #shells > 0 then
        if estadoShell.modo == "Insta" then
            local pegas = 0
            for _, s in ipairs(shells) do
                local prompt = s.obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then
                    pcall(function() fireproximityprompt(prompt) end)
                else
                    s.part.CFrame = CFrame.new(hrp.Position + Vector3.new(0, math.random(1, 5), 0))
                    s.part.Velocity = Vector3.zero
                end
                pegas = pegas + 1
            end
            estadoShell.pegas = estadoShell.pegas + pegas

        elseif estadoShell.modo == "Bring" then
            table.sort(shells, function(a, b)
                return (a.part.Position - hrp.Position).Magnitude < (b.part.Position - hrp.Position).Magnitude
            end)
            local alvo = shells[1]
            alvo.part.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 0))
            alvo.part.Velocity = Vector3.zero
            estadoShell.pegas = estadoShell.pegas + 1

        elseif estadoShell.modo == "TP" then
            estadoShell.processando = true
            table.sort(shells, function(a, b)
                return (a.part.Position - hrp.Position).Magnitude < (b.part.Position - hrp.Position).Magnitude
            end)
            local alvo = shells[1]
            hrp.CFrame = CFrame.new(alvo.part.Position)
            hrp.Velocity = Vector3.zero
            estadoShell.pegas = estadoShell.pegas + 1
            task.wait(0.2) 
            estadoShell.processando = false

        elseif estadoShell.modo == "Tween" then
            estadoShell.processando = true
            table.sort(shells, function(a, b)
                return (a.part.Position - hrp.Position).Magnitude < (b.part.Position - hrp.Position).Magnitude
            end)
            local alvo = shells[1]
            local targetPos = alvo.part.Position + Vector3.new(0, 2, 0)
            local tween = TweenService:Create(hrp, TweenInfo.new(0.4, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
            tween:Play()
            tween.Completed:Wait()
            estadoShell.pegas = estadoShell.pegas + 1
            task.wait(0.1) 
            estadoShell.processando = false
        end
    end
end)

-- ==========================================
-- INTERFACE DA WINDUI
-- ==========================================
MainTab:Toggle({
    Title = "Auto Shells (Ligar/Desligar)",
    Desc = "Ativa ou desativa o farm automático.",
    Value = false,
    Callback = function(Value)
        estadoShell.ativo = Value
    end,
})

MainTab:Dropdown({
    Title = "Modo de Coleta",
    Values = {"Insta", "Bring", "TP", "Tween"},
    Value = "Insta",
    Callback = function(Option)
        estadoShell.modo = Option
    end,
})

MainTab:Divider()

MainTab:Toggle({
    Title = "Anti-AFK Hardcore",
    Desc = "Impede o kick de 20 minutos.",
    Value = false, 
    Callback = function(Value)
        estadoAFK.ativo = Value
    end,
})

MainTab:Divider()

-- ==========================================
-- CONFIGURAÇÕES
-- ==========================================
ConfigTab:Dropdown({
    Title = "Tecla para Minimizar/Abrir",
    Desc = "Muda o atalho que esconde ou mostra o menu.",
    Values = {"RightControl", "LeftControl", "RightShift", "LeftShift", "Insert", "Home", "End", "K", "F1"},
    Value = config.teclaMenu,
    Callback = function(Option)
        config.teclaMenu = Option
        salvarConfig()
        print("[+] Atalho alterado para: " .. Option)
    end,
})

ConfigTab:Button({
    Title = "Fechar Menu (Minimizar)",
    Desc = "Esconde o menu e traz a bolinha de volta.",
    Callback = function()
        fecharMenu()
    end,
})

task.spawn(function()
    while Window do
        task.wait(2)
        print("[CONTADOR] Conchas no mapa: " .. #getShells() .. " | Coletadas: " .. estadoShell.pegas)
    end
end)

print("[+] Lunar Hub (por rush) carregado.")

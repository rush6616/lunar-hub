-- language: Lua (Roblox Luau), file: lunar_hub_afk_farm.lua
-- target: Madium executor
-- OBJETIVO: Full AFK com checagem de evento (Trem e Boss).

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==========================================
-- ESTADO GLOBAL & CONFIG
-- ==========================================
local estadoAFK = { ativo = false }
local estadoPumpkin = { ativo = false }
local estadoBoss = { ativo = false }
local estadoFull = { ativo = false }
local bossVivo = false -- Trava de prioridade

local config = { teclaMenu = Enum.KeyCode.RightControl.Name, interface_aberta = false }
local CONFIG_FILE = "lunar_hub_config.json"

local BOSS_POS = Vector3.new(-620.59, -80.02, -243.30)

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
-- LÓGICAS SEPARADAS
-- ==========================================
local function comprarTicket()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local ghostTrainRemotes = remotes and remotes:FindFirstChild("GhostTrain")
    local buyTicketRemote = ghostTrainRemotes and ghostTrainRemotes:FindFirstChild("BuyTicket")
    if buyTicketRemote then
        pcall(function() return buyTicketRemote:InvokeServer() end)
        return true
    end
    return false
end

local function embarcarTrem()
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local trainArrive = workspace:FindFirstChild("TrainArrive", true)
    if trainArrive then
        local prompt = trainArrive:FindFirstChild("BoardTrainPrompt")
        if prompt and prompt.Enabled then
            hrp.CFrame = trainArrive.CFrame * CFrame.new(0, 3, 0)
            task.wait(0.5)
            if type(fireproximityprompt) == "function" then
                pcall(fireproximityprompt, prompt)
            end
            return true
        end
    end
    return false
end

local function irProBoss()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(BOSS_POS)
    end
end

local function clicarNoFight()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end

    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("ImageButton") then
            local texto, nome = "", gui.Name:lower()
            if gui:IsA("TextButton") then texto = gui.Text:lower()
            elseif gui:IsA("ImageButton") then
                local label = gui:FindFirstChildWhichIsA("TextLabel")
                if label then texto = label.Text:lower() end
            end
            
            if texto:find("fight") or nome:find("fight") then
                if getgenv().firesignal then pcall(function() getgenv().firesignal(gui.Activated) end) end
                pcall(function() gui.Activated:Fire() end)
                pcall(function()
                    if mousemoveabs and mouse1click then
                        local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
                        mousemoveabs(pos.X + (size.X / 2), pos.Y + (size.Y / 2))
                        task.wait(0.1)
                        mouse1click()
                    end
                end)
                return true
            end
        end
    end
    return false
end

local function bossAindaVivo()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    return (playerGui:FindFirstChild("BossFightHPBar", true) ~= nil) or (playerGui:FindFirstChild("BossFight", true) ~= nil)
end

-- ==========================================
-- MODO FULL AFK (CICLO PRECISO E ANTI-TRAVA)
-- ==========================================
task.spawn(function()
    while task.wait(1) do
        if not estadoFull.ativo then 
            bossVivo = false
            continue 
        end
        
        bossVivo = true -- Pausa as abóboras

        -- Tenta comprar o ticket
        comprarTicket()
        task.wait(1.5)
        
        -- Tenta embarcar (checa se o trem existe e ta ativo)
        local embarcou = embarcarTrem()
        
        if not embarcou then
            print("[-] O trem nao esta disponivel (Evento acabou?). Aguardando 60s...")
            task.wait(60) -- Espera 1 minuto pro evento voltar
        else
            task.wait(3)
            
            print("[*] FULL AFK: Indo pro Boss...")
            irProBoss()
            task.wait(2)
            
            print("[*] FULL AFK: Clicando em Fight...")
            clicarNoFight()
            
            print("[*] FULL AFK: Monitorando a vida do Boss...")
            local tempoInicio = os.clock()
            while bossAindaVivo() and (os.clock() - tempoInicio < 45) do
                task.wait(1) -- Checa a cada 1 segundo
            end
            
            print("[+] Boss morreu (ou tempo esgotou). Esperando loot...")
            task.wait(2) 
        end
        
        bossVivo = false -- Libera as abóboras
    end
end)

-- ==========================================
-- AUTO BOSS SOLO (COM MONITORAMENTO)
-- ==========================================
task.spawn(function()
    while task.wait(1.5) do 
        if not estadoBoss.ativo or estadoFull.ativo then 
            if not estadoBoss.ativo and not estadoFull.ativo then bossVivo = false end
            continue 
        end
        
        bossVivo = true
        
        if not bossAindaVivo() then
            irProBoss()
            task.wait(2) 
            clicarNoFight()
        end
    end
end)

-- ==========================================
-- AUTO COLETAR ABÓBORAS (CHECAGEM DE EVENTO)
-- ==========================================
task.spawn(function()
    while task.wait(0.5) do
        if not estadoPumpkin.ativo or bossVivo then continue end
        
        local char = LocalPlayer.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end

        local closestPrompt = nil
        local shortestDist = math.huge

        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local objectText, actionText = obj.ObjectText:lower(), obj.ActionText:lower()
                local isPumpkin = (objectText == "abóbora" or objectText == "pumpkin" or objectText:find("abóbora"))
                local isCollect = (actionText == "collect" or actionText:find("collect"))
                
                if isPumpkin and isCollect and obj.Enabled then
                    local part = obj.Parent
                    if part and part:IsA("BasePart") then
                        local dist = (hrp.Position - part.Position).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            closestPrompt = { prompt = obj, part = part }
                        end
                    end
                end
            end
        end

        if closestPrompt then
            hrp.CFrame = CFrame.new(closestPrompt.part.Position)
            task.wait(0.1)
            if type(fireproximityprompt) == "function" then
                pcall(fireproximityprompt, closestPrompt.prompt)
            end
            task.wait(0.4)
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
-- CARREGANDO A INTERFACE (WINDUI) E TEMA LUNAR
-- ==========================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

pcall(function()
    WindUI:AddTheme({
        Name = "LunarTheme",
        Accent = Color3.fromRGB(91, 192, 190),
        Background = Color3.fromRGB(11, 19, 43),
        Outline = Color3.fromRGB(28, 37, 65),
        Text = Color3.fromRGB(244, 244, 249),
        Placeholder = Color3.fromRGB(106, 123, 158),
        Button = Color3.fromRGB(28, 37, 65),
        Icon = Color3.fromRGB(91, 192, 190),
    })
end)

local Window = WindUI:CreateWindow({
    Title = "Lunar Hub",
    Author = "por rush",
    Folder = "LunarHub",
    Size = UDim2.fromOffset(500, 400),
    Theme = "LunarTheme", 
    Transparent = true,
})

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
-- INTERFACE DA WINDUI
-- ==========================================
MainTab:Toggle({
    Title = "MODO FULL AFK (Preciso)",
    Desc = "Espera o boss morrer e o trem spawnar.",
    Value = false,
    Callback = function(Value)
        estadoFull.ativo = Value
    end,
})

MainTab:Divider()

MainTab:Toggle({
    Title = "Auto Boss Solo",
    Desc = "Vai pro boss e monitora até ele morrer.",
    Value = false,
    Callback = function(Value)
        estadoBoss.ativo = Value
    end,
})

MainTab:Button({
    Title = "Comprar Ticket e Embarçar",
    Desc = "Manual: Invoca o Remote e embarca.",
    Callback = function()
        task.spawn(comprarTicket)
        task.spawn(embarcarTrem)
    end,
})

MainTab:Divider()

MainTab:Toggle({
    Title = "Auto Coletar Abóboras",
    Desc = "Só coleta se o evento estiver ativo.",
    Value = false,
    Callback = function(Value)
        estadoPumpkin.ativo = Value
        if not Value then
            local char = LocalPlayer.Character
            if char then
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = true end
                end
            end
        end
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

print("[+] Lunar Hub (por rush) carregado.")

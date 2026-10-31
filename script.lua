-- language: Lua (Roblox Luau), file: lunar_hub_afk_farm.lua
-- target: Madium executor
-- OBJETIVO: Full AFK (15s Abóbora -> Boss) com Interface Luna.

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
local bossVivo = false

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

-- Função que pega a abóbora mais perto (só usada no modo de 15s)
local function coletarAbobora()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

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

-- ==========================================
-- MODO FULL AFK (15s Abóbora -> Boss)
-- ==========================================
task.spawn(function()
    while task.wait(1) do
        if not estadoFull.ativo then 
            bossVivo = false
            continue 
        end
        
        -- 1. TREM E TICKET
        bossVivo = true
        comprarTicket()
        task.wait(1.5)
        
        local embarcou = embarcarTrem()
        
        if not embarcou then
            print("[-] O trem nao esta disponivel. Aguardando 60s...")
            task.wait(60)
        else
            task.wait(3)
            
            -- 2. FARM DE ABÓBORA (15 SEGUNDOS CRAVADOS)
            print("[*] FULL AFK: Coletando abóboras por 15s...")
            local tempoInicioAbobora = os.clock()
            
            while (os.clock() - tempoInicioAbobora < 15) and estadoFull.ativo do
                coletarAbobora()
                task.wait(0.2)
            end
            
            -- 3. BOSS (DEPOIS DOS 15s)
            print("[*] FULL AFK: Tempo esgotado. Indo pro Boss...")
            irProBoss()
            task.wait(2)
            clicarNoFight()
            
            local tempoInicioBoss = os.clock()
            while bossAindaVivo() and (os.clock() - tempoInicioBoss < 45) do
                task.wait(1)
                clicarNoFight()
            end
            task.wait(2) 
        end
        
        bossVivo = false
    end
end)

-- ==========================================
-- AUTO BOSS SOLO
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
-- AUTO COLETAR ABÓBORAS (MODO SOLO)
-- ==========================================
task.spawn(function()
    while task.wait(0.5) do
        if not estadoPumpkin.ativo or bossVivo or estadoFull.ativo then continue end
        coletarAbobora()
    end
end)

-- ==========================================
-- INTERFACE (LUNA)
-- ==========================================
local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true))()

local Window = Luna:CreateWindow({
    Name = "Lunar Hub",
    Subtitle = "Farm",
    LogoID = "82795327169782",
    LoadingEnabled = true,
    LoadingTitle = "Lunar Hub",
    LoadingSubtitle = "Carregando...",
    KeySystem = false
})

local MainTab = Window:CreateTab({ Name = "Ocean Event" })
local ConfigTab = Window:CreateTab({ Name = "Config" })

MainTab:CreateToggle({
    Name = "MODO FULL AFK (15s Abóbora)",
    Description = "Farm 15s de abóbora e depois vai pro boss.",
    CurrentValue = false,
    Callback = function(Value)
        estadoFull.ativo = Value
    end
})

MainTab:CreateDivider()

MainTab:CreateToggle({
    Name = "Auto Boss Solo",
    Description = "Vai pro boss e monitora até ele morrer.",
    CurrentValue = false,
    Callback = function(Value)
        estadoBoss.ativo = Value
    end
})

MainTab:CreateButton({
    Name = "Comprar Ticket e Embarçar",
    Description = "Manual: Invoca o Remote e embarca.",
    Callback = function()
        task.spawn(comprarTicket)
        task.spawn(embarcarTrem)
    end
})

MainTab:CreateDivider()

MainTab:CreateToggle({
    Name = "Auto Coletar Abóboras (Solo)",
    Description = "Coleta sem parar se o boss não estiver ativo.",
    CurrentValue = false,
    Callback = function(Value)
        estadoPumpkin.ativo = Value
    end
})

MainTab:CreateDivider()

MainTab:CreateToggle({
    Name = "Anti-AFK Hardcore",
    Description = "Impede o kick de 20 minutos.",
    CurrentValue = false, 
    Callback = function(Value)
        estadoAFK.ativo = Value
    end
})

ConfigTab:CreateInput({
    Name = "Tecla para Minimizar/Abrir",
    Description = "Muda o atalho (ex: RightControl).",
    PlaceholderText = "RightControl",
    CurrentValue = config.teclaMenu,
    Callback = function(Text)
        config.teclaMenu = Text
        salvarConfig()
        print("[+] Atalho alterado para: " .. Text)
    end
})

ConfigTab:CreateButton({
    Name = "Fechar Menu",
    Description = "Fecha a interface.",
    Callback = function()
        Window:Hide()
    end
})

print("[+] Lunar Hub (por rush) carregado.")

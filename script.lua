-- language: Lua (Roblox Luau), file: lunar_hub_clean.lua
-- target: Madium executor
-- OBJETIVO: Base Lunar Hub + Auto Buy Animal (Multi-Seleção).

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
local estadoAutoBuy = { ativo = false, items = {"Buffalo"} }

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
-- AUTO BUY ANIMAL (MULTI)
-- ==========================================
local function comprarAnimal(itemName)
    local shopRemotes = ReplicatedStorage:FindFirstChild("Remotes")
    local shopRemote = shopRemotes and shopRemotes:FindFirstChild("Shop")
    local buyRemote = shopRemote and shopRemote:FindFirstChild("Buy")
    
    if buyRemote then
        pcall(function()
            buyRemote:FireServer("Animal", {
                BuyAll = true,
                ItemName = itemName
            })
        end)
    end
end

task.spawn(function()
    while task.wait(1) do
        if not estadoAutoBuy.ativo then continue end
        
        -- Passa por cada animal selecionado na lista
        for _, item in ipairs(estadoAutoBuy.items) do
            comprarAnimal(item)
            task.wait(0.3) -- Pequeno delay entre cada compra
        end
        
        task.wait(0.5) -- Delay antes de recomeçar o loop
    end
end)

-- ==========================================
-- INTERFACE (LUNA)
-- ==========================================
local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true))()

local Window = Luna:CreateWindow({
    Name = "Lunar Hub",
    Subtitle = "Auto Buy",
    LogoID = "82795327169782",
    LoadingEnabled = true,
    LoadingTitle = "Lunar Hub",
    LoadingSubtitle = "Carregando...",
    KeySystem = false
})

local MainTab = Window:CreateTab({ Name = "Principal" })
local ConfigTab = Window:CreateTab({ Name = "Config" })

-- ==========================================
-- LISTA DE ANIMAIS
-- ==========================================
local listaAnimais = {
    "Buffalo", "Ostrich", "Fish", "Zebra", "Toucan", "Seal", 
    "Elephant", "Crab", "Tiger", "Turtle", "Giraffe", 
    "Crocodile", "Gorilla", "Shark", "Whale", "Lion"
}

MainTab:CreateDropdown({
    Name = "Animais Alvos",
    Description = "Selecione um ou mais animais.",
    Options = listaAnimais,
    CurrentOption = {"Buffalo"},
    MultipleOptions = true, -- AQUI PERMITE SELECIONAR VÁRIOS
    Callback = function(Options)
        estadoAutoBuy.items = Options -- Salva a lista completa de selecionados
    end
})

MainTab:CreateToggle({
    Name = "Auto Buy Animal",
    Description = "Compra todos os animais selecionados.",
    CurrentValue = false, 
    Callback = function(Value)
        estadoAutoBuy.ativo = Value
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

print("[+] Lunar Hub (Auto Buy Multi) carregado.")

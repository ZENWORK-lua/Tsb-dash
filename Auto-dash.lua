-- TSB Adaptive Tech Dash & Combo Engine V2
-- Architecture: Async, Memory-Leak Free, Dynamic Ping/FPS Compensation

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Globals & Garbage Collection (Hafıza sızıntısını önlemek için)
getgenv().TSB_Engine = getgenv().TSB_Engine or {}
if getgenv().TSB_Engine.Connection then getgenv().TSB_Engine.Connection:Disconnect() end

-- Konfigürasyon ve Adaptif Veriler
local Settings = {
    Enabled = false,
    BaseDelay = 0.20,      -- 0 Ping ve 60 FPS'teki ideal taban gecikme
    MaxDistance = 15,
    ClampPower = 20,
    UseAdaptive = true
}

-- [Adaptif Hesaplama Modülü]
-- Ping ve FPS'i okuyarak en doğru milisaniyeyi hesaplar
local function CalculateAdaptiveDelay()
    if not Settings.UseAdaptive then return Settings.BaseDelay end
    
    -- Anlık Ping Değerini Çek (Ağ Gecikmesi)
    local success, pingVal = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    local currentPing = success and pingVal or 50

    -- FPS (Frame Per Second) Değerini Çek (Donanım Gecikmesi)
    local currentFPS = math.floor(1 / RunService.RenderStepped:Wait())
    
    -- Algoritma: Ping ne kadar yüksekse, o kadar erken tepki vermeliyiz (-)
    -- FPS ne kadar düşükse, input gecikmesini tolere etmeliyiz
    local pingCompensation = (currentPing / 1000) * 0.8 -- %80 ağırlık
    local fpsCompensation = (60 - currentFPS) * 0.002
    
    local finalDelay = Settings.BaseDelay - pingCompensation - fpsCompensation
    
    -- Sınırlandırma (Çok uçuk değerlere inmesini/çıkmasını engelle)
    return math.clamp(finalDelay, 0.02, 0.35)
end

-- [Hedef Fizik Analizi]
-- Sadece animasyona güvenmek yerine fiziksel durumu tarar
local function ValidateTarget(targetRoot)
    if not targetRoot or not targetRoot.Parent then return false end
    local hum = targetRoot.Parent:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    
    local dist = (targetRoot.Position - RootPart.Position).Magnitude
    return dist <= Settings.MaxDistance
end

-- [Core Execution - Çekirdek İşlem]
local function ExecuteAdaptiveDash(targetRoot)
    task.spawn(function()
        if not ValidateTarget(targetRoot) then return end
        
        local adaptiveDelay = CalculateAdaptiveDelay()
        task.wait(adaptiveDelay) -- Ağ ve FPS'e göre hesaplanmış kusursuz bekleme
        
        -- 1. Açı Kilidi (CFrame Alignment)
        local targetPos = Vector3.new(targetRoot.Position.X, RootPart.Position.Y, targetRoot.Position.Z)
        RootPart.CFrame = CFrame.lookAt(RootPart.Position, targetPos)
        
        -- 2. Asenkron Tuş Vuruşu (Q Dash)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
        task.wait(0.015)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
        
        -- 3. Velocity Clamp (Fizik Kısıtlama - Hedefin Uzağa Fırlamasını Engeller)
        local t = tick()
        local clampConn
        clampConn = RunService.Heartbeat:Connect(function()
            if tick() - t > 0.15 then
                clampConn:Disconnect()
                return
            end
            local vel = RootPart.AssemblyLinearVelocity
            local flat = Vector3.new(vel.X, 0, vel.Z)
            if flat.Magnitude > Settings.ClampPower then
                local clamped = flat.Unit * Settings.ClampPower
                RootPart.AssemblyLinearVelocity = Vector3.new(clamped.X, vel.Y, clamped.Z)
            end
        end)
    end)
end

-- ==========================================
-- UI MİMARİSİ (Rayfield Library Kullanarak)
-- ==========================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "TSB Adaptif Engine | V2",
    LoadingTitle = "Çekirdek Yükleniyor...",
    LoadingSubtitle = "FPS & Ping Analizi Başlatıldı",
    ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Auto-Tech", 4483362458)

MainTab:CreateToggle({
    Name = "Adaptif Tech Dash Aktif",
    CurrentValue = false,
    Flag = "Toggle_Tech",
    Callback = function(Value)
        Settings.Enabled = Value
    end,
})

MainTab:CreateToggle({
    Name = "Yapay Zeka Zamanlaması (Ping/FPS Bazlı)",
    CurrentValue = true,
    Flag = "Toggle_AI",
    Callback = function(Value)
        Settings.UseAdaptive = Value
    end,
})

MainTab:CreateSlider({
    Name = "Taban Gecikme (Base Delay)",
    Range = {0.10, 0.40},
    Increment = 0.01,
    CurrentValue = 0.20,
    Flag = "Slider_Delay",
    Callback = function(Value)
        Settings.BaseDelay = Value
    end,
})

-- Dinleme Mekanizması (Sıcak Tuş Tetikleyici)
-- İleride bunu doğrudan saldırı state'lerine bağlayabiliriz, şimdilik E tuşu ile test edilir.
getgenv().TSB_Engine.Connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not Settings.Enabled then return end
    
    if input.KeyCode == Enum.KeyCode.E then
        -- En yakın hedefi bul
        local closest, minD = nil, Settings.MaxDistance
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local d = (p.Character.HumanoidRootPart.Position - RootPart.Position).Magnitude
                if d < minD then
                    closest = p.Character.HumanoidRootPart
                    minD = d
                end
            end
        end
        
        if closest then
            ExecuteAdaptiveDash(closest)
        end
    end
end)

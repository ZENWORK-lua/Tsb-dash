-- ==========================================
-- PART 1: TSB ADAPTIVE CORE ENGINE (DYNAMIC)
-- Architecture: Dynamic Pointers, Memory Leak Free
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

getgenv().TSB_Core = getgenv().TSB_Core or {}

getgenv().TSB_Core.Settings = {
    Enabled = true,
    BaseDelay = 0.20,
    MaxDistance = 15,
    ClampPower = 20,
    UseAdaptive = true,
    AutoTrigger = false -- Yeni: Zıplama/Uppercut hızını otomatik algılama
}

-- [Dinamik Karakter Referansı - Öldüğünde bozulmayı engeller]
local function GetRoot()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return LocalPlayer.Character.HumanoidRootPart
    end
    return nil
end

local function CalculateAdaptiveDelay()
    local settings = getgenv().TSB_Core.Settings
    if not settings.UseAdaptive then return settings.BaseDelay end
    
    local success, pingVal = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    local currentPing = success and pingVal or 50
    local currentFPS = math.floor(1 / RunService.RenderStepped:Wait())
    
    local pingComp = (currentPing / 1000) * 0.85
    local fpsComp = (60 - currentFPS) * 0.002
    
    return math.clamp(settings.BaseDelay - pingComp - fpsComp, 0.02, 0.35)
end

-- [Motor Çekirdeği]
getgenv().TSB_Core.ExecuteDash = function(targetRoot)
    local myRoot = GetRoot()
    if not myRoot or not targetRoot then return end

    task.spawn(function()
        local delay = CalculateAdaptiveDelay()
        task.wait(delay)
        
        -- CFrame Angle Kitleme
        local targetPos = Vector3.new(targetRoot.Position.X, myRoot.Position.Y, targetRoot.Position.Z)
        myRoot.CFrame = CFrame.lookAt(myRoot.Position, targetPos)
        
        -- Dash Tetikleme
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
        task.wait(0.015)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
        
        -- Fizik Kısıtlama (Uzağa Fırlamayı Engeller)
        local t = tick()
        local clampConn
        clampConn = RunService.Heartbeat:Connect(function()
            local currentRoot = GetRoot()
            if not currentRoot or tick() - t > 0.15 then
                if clampConn then clampConn:Disconnect() end
                return
            end
            
            local vel = currentRoot.AssemblyLinearVelocity
            local flat = Vector3.new(vel.X, 0, vel.Z)
            local maxVel = getgenv().TSB_Core.Settings.ClampPower
            
            if flat.Magnitude > maxVel then
                local clamped = flat.Unit * maxVel
                currentRoot.AssemblyLinearVelocity = Vector3.new(clamped.X, vel.Y, clamped.Z)
            end
        end)
    end)
end

print("[TSB Engine] Part 1 Loaded. Dynamic Pointers Active.")
-- ==========================================
-- PART 2: RAYFIELD UI & ROBUST LISTENERS
-- Language: English | Features: Keybind API, Auto-Detect
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

if not getgenv().TSB_Core then
    warn("[TSB UI] Core Engine (Part 1) missing! Execute Part 1 first.")
    return
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "TSB Tech Engine | AI Adaptive",
    LoadingTitle = "Initializing Modules...",
    LoadingSubtitle = "Adaptive Algorithms Active",
    ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Auto-Tech", 4483362458)

MainTab:CreateToggle({
    Name = "Enable Engine",
    CurrentValue = getgenv().TSB_Core.Settings.Enabled,
    Flag = "Toggle_Engine",
    Callback = function(Value)
        getgenv().TSB_Core.Settings.Enabled = Value
    end,
})

MainTab:CreateToggle({
    Name = "Adaptive Timing (Ping/FPS AI)",
    CurrentValue = getgenv().TSB_Core.Settings.UseAdaptive,
    Flag = "Toggle_AI",
    Callback = function(Value)
        getgenv().TSB_Core.Settings.UseAdaptive = Value
    end,
})

MainTab:CreateToggle({
    Name = "Auto-Detect Uppercut (Beta)",
    CurrentValue = false,
    Flag = "Toggle_Auto",
    Callback = function(Value)
        getgenv().TSB_Core.Settings.AutoTrigger = Value
    end,
})

MainTab:CreateSlider({
    Name = "Base Delay",
    Range = {0.10, 0.40},
    Increment = 0.01,
    CurrentValue = getgenv().TSB_Core.Settings.BaseDelay,
    Flag = "Slider_Delay",
    Callback = function(Value)
        getgenv().TSB_Core.Settings.BaseDelay = Value
    end,
})

MainTab:CreateSlider({
    Name = "Lock Distance (Studs)",
    Range = {5, 30},
    Increment = 1,
    CurrentValue = getgenv().TSB_Core.Settings.MaxDistance,
    Flag = "Slider_Dist",
    Callback = function(Value)
        getgenv().TSB_Core.Settings.MaxDistance = Value
    end,
})

-- [YARDIMCI FONKSİYON: En Yakın Hedefi Bulma]
local function FindClosestTarget()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    local myRoot = myChar.HumanoidRootPart
    
    local closest, minDst = nil, getgenv().TSB_Core.Settings.MaxDistance
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local tHum = p.Character:FindFirstChild("Humanoid")
            if tHum and tHum.Health > 0 then
                local d = (p.Character.HumanoidRootPart.Position - myRoot.Position).Magnitude
                if d < minDst then
                    closest = p.Character.HumanoidRootPart
                    minDst = d
                end
            end
        end
    end
    return closest
end

-- [1. MANUEL TETİKLEYİCİ: Rayfield Keybind API]
MainTab:CreateKeybind({
    Name = "Manual Dash Trigger",
    CurrentKeybind = "E",
    HoldToInteract = false,
    Flag = "Keybind_Dash",
    Callback = function()
        if not getgenv().TSB_Core.Settings.Enabled then return end
        local target = FindClosestTarget()
        if target then
            getgenv().TSB_Core.ExecuteDash(target)
        end
    end,
})

-- [2. OTOMATİK TETİKLEYİCİ: Velocity Scanner]
-- Uppercut attığında dikey Y-Ekseni hızın aniden fırlar. Bunu tarayıp kendi kendine Q basar.
if getgenv().TSB_AutoConn then getgenv().TSB_AutoConn:Disconnect() end
local debounce = false

getgenv().TSB_AutoConn = RunService.Heartbeat:Connect(function()
    local settings = getgenv().TSB_Core.Settings
    if not settings.Enabled or not settings.AutoTrigger or debounce then return end
    
    local myChar = LocalPlayer.Character
    if myChar and myChar:FindFirstChild("HumanoidRootPart") then
        local myRoot = myChar.HumanoidRootPart
        -- Eğer karakter aniden yukarı 40 hızın üzerinde fırlarsa (Uppercut state)
        if myRoot.AssemblyLinearVelocity.Y > 40 then
            local target = FindClosestTarget()
            if target then
                debounce = true
                getgenv().TSB_Core.ExecuteDash(target)
                task.wait(1) -- Spam'ı önlemek için 1 saniye bekleme süresi
                debounce = false
            end
        end
    end
end)

print("[TSB UI] Interface & Bindings Loaded Successfully.")

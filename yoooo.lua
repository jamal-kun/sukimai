--[[
    DEATH BALL ULTIMATE SCRIPT v2 - Kyriel Edition
    Categorized GUI + All Features + Auto Logic Prediction
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- ============================================
-- SETTINGS
-- ============================================
local Settings = {
    -- Bypasses
    GazoBypass = false,
    TorokaiBypass = false,
    WuBypass = false,
    -- Parry
    LegitParry = false,
    AutoSpamParry = false,
    InfinityParry = false,
    -- Movement
    AIMovement = false,
    AutoJump = false,
    AutoDash = false,
    InfinityDash = false,
    SpeedV1 = false,
    SpeedV2 = false,
    OrbitPlayer = false,
    OrbitBall = false,
    -- Auto Ready
    AutoReadyV2 = false,
    -- Raid
    AutoRaid = false,
    -- Visual
    SkinchangerV2 = false,
    AvatarChanger = false,
    -- Other
    AutoCurve = false,
    StreamerMode = false,
    DisableSecurityDistance = false,
    Desync = false,
    -- Auto Logic (prediction)
    AutoLogic = false,
}

-- ============================================
-- PREDICTION ENGINE (same as before)
-- ============================================
local Prediction = {
    Ball = { Position = nil, Velocity = nil, PreviousPositions = {}, LastUpdate = 0 },
    Opponent = { Position = nil, Velocity = nil, PreviousPositions = {}, LastUpdate = 0 },
    Settings = { PredictionAccuracy = 0.95, ReactionDelay = 0.05, MaxPredictionTime = 1.5, UpdateFrequency = 0.02 }
}

local function GetBall()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Part") and (v.Name:lower():find("ball") or v.Name:lower():find("projectile")) then return v end
    end
    return nil
end

local function GetOpponent()
    local best, bestDist = nil, math.huge
    for _, v in ipairs(Players:GetPlayers()) do
        if v ~= Player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            local pos = v.Character.HumanoidRootPart.Position
            local d = (pos - RootPart.Position).Magnitude
            if d < bestDist then bestDist = d; best = v end
        end
    end
    return best
end

local function TrackBall()
    local ball = GetBall()
    if not ball then return end
    local pos = ball.Position
    local now = tick()
    table.insert(Prediction.Ball.PreviousPositions, {pos = pos, time = now})
    if #Prediction.Ball.PreviousPositions > 10 then table.remove(Prediction.Ball.PreviousPositions, 1) end
    if #Prediction.Ball.PreviousPositions >= 2 then
        local first = Prediction.Ball.PreviousPositions[1]
        local last = Prediction.Ball.PreviousPositions[#Prediction.Ball.PreviousPositions]
        local dt = last.time - first.time
        if dt > 0.01 then
            Prediction.Ball.Velocity = (last.pos - first.pos) / dt
            Prediction.Ball.Position = last.pos
            Prediction.Ball.LastUpdate = now
        end
    end
end

local function TrackOpponent()
    local opp = GetOpponent()
    if not opp or not opp.Character then return end
    local root = opp.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local pos = root.Position
    local now = tick()
    table.insert(Prediction.Opponent.PreviousPositions, {pos = pos, time = now})
    if #Prediction.Opponent.PreviousPositions > 10 then table.remove(Prediction.Opponent.PreviousPositions, 1) end
    if #Prediction.Opponent.PreviousPositions >= 2 then
        local first = Prediction.Opponent.PreviousPositions[1]
        local last = Prediction.Opponent.PreviousPositions[#Prediction.Opponent.PreviousPositions]
        local dt = last.time - first.time
        if dt > 0.01 then
            Prediction.Opponent.Velocity = (last.pos - first.pos) / dt
            Prediction.Opponent.Position = last.pos
            Prediction.Opponent.LastUpdate = now
        end
    end
end

local function PredictBallLanding()
    local ball = GetBall()
    if not ball then return nil end
    local pos = ball.Position
    local vel = ball.Velocity or Vector3.new(0,0,0)
    if vel.Magnitude < 5 then return {Position = pos, Time = 0.5, Velocity = vel} end
    local gravity = Vector3.new(0, -196.2, 0)
    local dt = 0.02
    local maxTime = Prediction.Settings.MaxPredictionTime
    local curPos, curVel = pos, vel
    for t = 0, maxTime, dt do
        curVel = curVel + gravity * dt
        curPos = curPos + curVel * dt
        if curPos.Y < 2 then return {Position = curPos, Time = t, Velocity = curVel} end
    end
    return {Position = pos + vel * 1.5, Time = 1.5, Velocity = vel}
end

local function PredictOpponentPosition(timeAhead)
    if not Prediction.Opponent.Position or not Prediction.Opponent.Velocity then return nil end
    return Prediction.Opponent.Position + Prediction.Opponent.Velocity * timeAhead
end

local function MakeDecision()
    local pred = PredictBallLanding()
    if not pred then return nil end
    local ballPos = pred.Position
    local ballTime = pred.Time or 0.5
    local oppPos = PredictOpponentPosition(ballTime) or Vector3.new(0,0,0)
    local myPos = RootPart.Position
    local distToOpp = (ballPos - oppPos).Magnitude
    local distToMe = (ballPos - myPos).Magnitude
    local ballSpeed = Prediction.Ball.Velocity and Prediction.Ball.Velocity.Magnitude or 0

    local action = "idle"
    local target = myPos
    if distToMe < 30 and ballSpeed > 20 then
        if distToOpp > distToMe then
            action = "intercept"; target = ballPos - (ballPos - myPos).Unit * 3
        else
            action = "defend"; target = myPos + (oppPos - myPos).Unit * 5
        end
    end
    if distToOpp < 20 and ballSpeed > 30 then
        action = "parry"; target = myPos + (ballPos - myPos).Unit * 2
    end
    if distToMe < 15 and ballSpeed < 40 then
        action = "attack"; target = ballPos + (ballPos - myPos).Unit * 5
    end
    if math.abs(ballPos.X) > 80 or math.abs(ballPos.Z) > 80 then
        action = "reset"; target = Vector3.new(0,3,0)
    end
    return {Action = action, Target = target, BallPred = pred, OppPred = oppPos}
end

local function ExecuteDecision(decision)
    if not decision then return end
    local target = decision.Target
    local action = decision.Action
    local dir = (target - RootPart.Position).Unit
    local speed = 25
    if action == "intercept" then speed = 35
    elseif action == "defend" then speed = 20
    elseif action == "attack" then speed = 40
    elseif action == "reset" then speed = 30 end
    RootPart.Velocity = Vector3.new(dir.X * speed, RootPart.Velocity.Y, dir.Z * speed)
    if target.Y > RootPart.Position.Y + 5 and Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
        Humanoid:Jump()
    end
    if action == "parry" or action == "defend" then
        local ball = GetBall()
        if ball and ball.Velocity and ball.Velocity.Magnitude > 30 then
            if (ball.Position - RootPart.Position).Magnitude < 15 then
                task.wait(math.random(30,80)/1000)
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end
        end
    end
    if (action == "attack" or action == "intercept") and (target - RootPart.Position).Magnitude > 20 then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end

local LogicRunning = false
local function AutoLogicLoop()
    while LogicRunning do
        if Settings.AutoLogic then
            pcall(function()
                TrackBall()
                TrackOpponent()
                local dec = MakeDecision()
                if dec then ExecuteDecision(dec) end
            end)
        end
        task.wait(Prediction.Settings.UpdateFrequency)
    end
end

-- ============================================
-- FEATURE FUNCTIONS (shortened for brevity, same as before)
-- ============================================
local function GazoBypass()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Part") and v.Name:find("Projectile") and v:FindFirstChild("IsFake") then
            if Settings.GazoBypass and not v.IsFake.Value then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end
        end
    end
end

local function TorokaiBypass()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Part") and v.Name:find("Fireball") and Settings.TorokaiBypass then
            v.Velocity = (RootPart.Position - v.Position).Unit * 80
        end
    end
end

local function WuBypass()
    for _, v in ipairs(Players:GetPlayers()) do
        if (v.Name == "Wu" or v.DisplayName == "Wu") and v.Character then
            local wp = v.Character.HumanoidRootPart.Position
            if Settings.WuBypass and (wp - RootPart.Position).Magnitude < 30 then
                RootPart.Velocity = (RootPart.Position - wp).Unit * 50
            end
        end
    end
end

local function LegitParry()
    if Settings.LegitParry then
        task.wait(math.random(50,120)/1000)
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end

local function AutoSpamParry()
    if Settings.AutoSpamParry then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end

local function InfinityParry()
    if Settings.InfinityParry then
        local cd = Player:FindFirstChild("ParryCooldown")
        if cd then cd.Value = 0 end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end

local function AIMovement()
    if Settings.AIMovement then
        local ball = GetBall()
        if ball then
            local dir = (ball.Position - RootPart.Position).Unit
            local speed = (ball.Velocity and ball.Velocity.Magnitude > 20) and 10 or 20
            RootPart.Velocity = dir * speed
        end
    end
end

local jumpTimer, dashTimer = 0, 0
local function AutoJump(dt)
    if Settings.AutoJump then
        jumpTimer = jumpTimer + dt
        if jumpTimer >= 2 then jumpTimer = 0; Humanoid:Jump() end
    end
end

local function AutoDash(dt)
    if Settings.AutoDash then
        dashTimer = dashTimer + dt
        if dashTimer >= 1.5 then dashTimer = 0; VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end
    end
end

local function InfinityDash()
    if Settings.InfinityDash then
        local cd = Player:FindFirstChild("DashCooldown")
        if cd then cd.Value = 0 end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end

local function SpeedV1()
    if Settings.SpeedV1 then Humanoid.WalkSpeed = 25 end
end

local function SpeedV2()
    if Settings.SpeedV2 then Humanoid.WalkSpeed = 50 + math.sin(tick() * 10) * 10 end
end

local orbitAngle, orbitBallAngle = 0, 0
local function OrbitPlayer()
    if Settings.OrbitPlayer then
        local target
        for _, v in ipairs(Players:GetPlayers()) do if v ~= Player then target = v; break end end
        if target and target.Character then
            orbitAngle = orbitAngle + 0.05
            local pos = target.Character.HumanoidRootPart.Position
            RootPart.Position = pos + Vector3.new(math.cos(orbitAngle) * 8, 0, math.sin(orbitAngle) * 8)
        end
    end
end

local function OrbitBall()
    if Settings.OrbitBall then
        local ball = GetBall()
        if ball then
            orbitBallAngle = orbitBallAngle + 0.05
            local pos = ball.Position
            RootPart.Position = pos + Vector3.new(math.cos(orbitBallAngle) * 6, math.sin(orbitBallAngle) * 3, math.sin(orbitBallAngle) * 6)
        end
    end
end

local function AutoReadyV2()
    if Settings.AutoReadyV2 then
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("Part") and v.Name:find("StartZone") then
                local s = v.Size
                RootPart.Position = v.Position + Vector3.new(math.random(-s.X/2,s.X/2), 0, math.random(-s.Z/2,s.Z/2))
                break
            end
        end
    end
end

local function AutoRaid()
    if Settings.AutoRaid then
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("Model") and v.Name:find("Raid") and v:FindFirstChild("HumanoidRootPart") then
                RootPart.CFrame = CFrame.new(v.HumanoidRootPart.Position + Vector3.new(0,3,5))
                VirtualUser:CaptureController()
                VirtualUser:ClickButton1(Vector2.new())
            end
        end
    end
end

local function AutoCurve()
    if Settings.AutoCurve then
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("Part") and v.Name:find("Ball") then
                v.Velocity = Vector3.new(math.random(-100,100), math.random(-50,50), math.random(-100,100)).Unit * 60
            end
        end
    end
end

local function SkinchangerV2()
    if Settings.SkinchangerV2 then
        for _, v in ipairs(Character:GetDescendants()) do
            if v:IsA("Tool") and v.Name:find("Sword") and v:FindFirstChild("Handle") then
                v.Handle.Material = Enum.Material.Neon
                v.Handle.Color = Color3.fromHSV(tick() % 1, 1, 1)
            end
        end
    end
end

local function AvatarChanger()
    if Settings.AvatarChanger then
        local target
        for _, v in ipairs(Players:GetPlayers()) do if v ~= Player then target = v; break end end
        if target and target.Character then
            Humanoid:ApplyDescription(target.Character.Humanoid:GetAppliedDescription())
        end
    end
end

local function StreamerMode()
    if Settings.StreamerMode then
        local notif = game:GetService("NotificationService")
        if notif then notif:SetNotificationEnabled(false) end
        for _, gui in ipairs(Player.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name ~= "KyrielUltimateGUI" then gui.Enabled = false end
        end
    end
end

local function DisableSecurityDistance()
    if Settings.DisableSecurityDistance then
        local fb = Player:FindFirstChild("FollowBall")
        if fb then fb:Destroy() end
    end
end

local desyncPos
local function Desync()
    if Settings.Desync then
        if not desyncPos then desyncPos = RootPart.Position end
        RootPart.CFrame = CFrame.new(RootPart.Position + Vector3.new(0, 999, 0))
    elseif desyncPos then
        RootPart.CFrame = CFrame.new(desyncPos)
        desyncPos = nil
    end
end

-- ============================================
-- GUI WITH CATEGORIES
-- ============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KyrielUltimateGUI"
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0, 500)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -250)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
MainFrame.BackgroundTransparency = 0.12
MainFrame.BorderSizePixel = 1
MainFrame.BorderColor3 = Color3.fromRGB(80, 180, 255)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "KYRIEL ULTIMATE"
Title.TextColor3 = Color3.fromRGB(80, 180, 255)
Title.TextScaled = true
Title.Font = Enum.Font.GothamBold
Title.BackgroundTransparency = 1
Title.Parent = MainFrame

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 30, 0, 30)
Close.Position = UDim2.new(1, -35, 0, 0)
Close.Text = "X"
Close.TextColor3 = Color3.fromRGB(255,100,100)
Close.TextScaled = true
Close.Font = Enum.Font.GothamBold
Close.BackgroundColor3 = Color3.fromRGB(30,30,40)
Close.BorderSizePixel = 0
Close.Parent = MainFrame
Close.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

-- Scroll frame
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -10, 1, -40)
Scroll.Position = UDim2.new(0, 5, 0, 35)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Color3.fromRGB(80,180,255)
Scroll.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 3)
UIList.Parent = Scroll

-- Helper to add category header
local function AddCategory(title)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.Text = "  " .. title
    lbl.TextColor3 = Color3.fromRGB(100, 200, 255)
    lbl.TextScaled = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.GothamBold
    lbl.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    lbl.BorderSizePixel = 1
    lbl.BorderColor3 = Color3.fromRGB(80, 180, 255)
    lbl.Parent = Scroll
end

-- Toggle builder
local function MakeToggle(text, key, shortcut)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 26)
    frame.BackgroundTransparency = 1
    frame.Parent = Scroll

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -55, 1, 0)
    btn.Position = UDim2.new(0, 0, 0, 0)
    btn.Text = text .. " [OFF]"
    btn.TextColor3 = Color3.fromRGB(200,200,200)
    btn.TextScaled = true
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Font = Enum.Font.Gotham
    btn.BackgroundColor3 = Color3.fromRGB(30,30,40)
    btn.BorderSizePixel = 0
    btn.Parent = frame

    local shortcutLabel = Instance.new("TextLabel")
    shortcutLabel.Size = UDim2.new(0, 40, 1, 0)
    shortcutLabel.Position = UDim2.new(1, -45, 0, 0)
    shortcutLabel.Text = shortcut or ""
    shortcutLabel.TextColor3 = Color3.fromRGB(120,120,140)
    shortcutLabel.TextScaled = true
    shortcutLabel.Font = Enum.Font.Gotham
    shortcutLabel.BackgroundTransparency = 1
    shortcutLabel.Parent = frame

    btn.MouseButton1Click:Connect(function()
        Settings[key] = not Settings[key]
        btn.Text = text .. (Settings[key] and " [ON]" or " [OFF]")
        btn.TextColor3 = Settings[key] and Color3.fromRGB(100,255,100) or Color3.fromRGB(200,200,200)
        if key == "AutoLogic" and Settings.AutoLogic and not LogicRunning then
            LogicRunning = true
            coroutine.wrap(AutoLogicLoop)()
        elseif key == "AutoLogic" and not Settings.AutoLogic then
            RootPart.Velocity = Vector3.new(0, RootPart.Velocity.Y, 0)
        end
    end)
    return btn
end

-- Categories and toggles
local categories = {
    {name = "Auto Logic", items = {{"Auto Logic + Prediction", "AutoLogic", "P"}}},
    {name = "Bypasses", items = {
        {"Gazo Bypass", "GazoBypass", "G"},
        {"Torokai Bypass", "TorokaiBypass", "T"},
        {"Wu Bypass", "WuBypass", "W"},
    }},
    {name = "Parry", items = {
        {"Legit Parry", "LegitParry", "U"},
        {"Auto Spam Parry", "AutoSpamParry", "L"},
        {"Infinity Parry", "InfinityParry", "O"},
    }},
    {name = "Movement", items = {
        {"AI Movement", "AIMovement", "I"},
        {"Auto Jump", "AutoJump", "J"},
        {"Auto Dash", "AutoDash", "D"},
        {"Infinity Dash", "InfinityDash", "N"},
        {"Speed V1", "SpeedV1", "V"},
        {"Speed V2", "SpeedV2", "X"},
        {"Orbit Player", "OrbitPlayer", "B"},
        {"Orbit Ball", "OrbitBall", ""},
    }},
    {name = "Auto & Other", items = {
        {"Auto Ready V2", "AutoReadyV2", "R"},
        {"Auto Raid", "AutoRaid", "A"},
        {"Auto Curve", "AutoCurve", "C"},
    }},
    {name = "Visual", items = {
        {"Skinchanger V2", "SkinchangerV2", "K"},
        {"Avatar Changer", "AvatarChanger", "Y"},
        {"Streamer Mode", "StreamerMode", "S"},
    }},
    {name = "Utility", items = {
        {"Disable Security Dist", "DisableSecurityDistance", "Z"},
        {"Desync", "Desync", "Q"},
    }},
}

local buttonRefs = {}
for _, cat in ipairs(categories) do
    AddCategory(cat.name)
    for _, item in ipairs(cat.items) do
        buttonRefs[item[2]] = MakeToggle(item[1], item[2], item[3])
    end
end

UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Scroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
end)

-- ============================================
-- KEYBINDS
-- ============================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.M then
        ScreenGui.Enabled = not ScreenGui.Enabled
        return
    end

    local map = {
        [Enum.KeyCode.G] = "GazoBypass",
        [Enum.KeyCode.T] = "TorokaiBypass",
        [Enum.KeyCode.W] = "WuBypass",
        [Enum.KeyCode.U] = "LegitParry",
        [Enum.KeyCode.L] = "AutoSpamParry",
        [Enum.KeyCode.O] = "InfinityParry",
        [Enum.KeyCode.I] = "AIMovement",
        [Enum.KeyCode.J] = "AutoJump",
        [Enum.KeyCode.D] = "AutoDash",
        [Enum.KeyCode.N] = "InfinityDash",
        [Enum.KeyCode.V] = "SpeedV1",
        [Enum.KeyCode.X] = "SpeedV2",
        [Enum.KeyCode.B] = "OrbitPlayer",
        [Enum.KeyCode.R] = "AutoReadyV2",
        [Enum.KeyCode.A] = "AutoRaid",
        [Enum.KeyCode.C] = "AutoCurve",
        [Enum.KeyCode.K] = "SkinchangerV2",
        [Enum.KeyCode.Y] = "AvatarChanger",
        [Enum.KeyCode.S] = "StreamerMode",
        [Enum.KeyCode.Z] = "DisableSecurityDistance",
        [Enum.KeyCode.Q] = "Desync",
        [Enum.KeyCode.P] = "AutoLogic",
    }

    local settingKey = map[key]
    if settingKey and buttonRefs[settingKey] then
        Settings[settingKey] = not Settings[settingKey]
        local btn = buttonRefs[settingKey]
        btn.Text = btn.Text:gsub("%[%a+%]", Settings[settingKey] and "[ON]" or "[OFF]")
        btn.TextColor3 = Settings[settingKey] and Color3.fromRGB(100,255,100) or Color3.fromRGB(200,200,200)
        if settingKey == "AutoLogic" and Settings.AutoLogic and not LogicRunning then
            LogicRunning = true
            coroutine.wrap(AutoLogicLoop)()
        elseif settingKey == "AutoLogic" and not Settings.AutoLogic then
            RootPart.Velocity = Vector3.new(0, RootPart.Velocity.Y, 0)
        end
    end
end)

-- ============================================
-- MAIN LOOP (run all features except auto logic)
-- ============================================
RunService.Heartbeat:Connect(function(delta)
    pcall(function()
        -- Only run individual features if auto logic is off to avoid conflicts,
        -- but we can let them run together if user wants (e.g., speed, skin, etc.)
        -- We'll conditionally disable movement-related ones if auto logic is on.
        if not Settings.AutoLogic then
            if Settings.AIMovement then AIMovement() end
            -- other movement can still be used with auto logic? We'll allow it.
        end
        -- These can always run
        if Settings.GazoBypass then GazoBypass() end
        if Settings.TorokaiBypass then TorokaiBypass() end
        if Settings.WuBypass then WuBypass() end
        if Settings.LegitParry then LegitParry() end
        if Settings.AutoSpamParry then AutoSpamParry() end
        if Settings.InfinityParry then InfinityParry() end
        if Settings.AutoJump then AutoJump(delta) end
        if Settings.AutoDash then AutoDash(delta) end
        if Settings.InfinityDash then InfinityDash() end
        if Settings.SpeedV1 then SpeedV1() end
        if Settings.SpeedV2 then SpeedV2() end
        if Settings.OrbitPlayer then OrbitPlayer() end
        if Settings.OrbitBall then OrbitBall() end
        if Settings.AutoReadyV2 then AutoReadyV2() end
        if Settings.AutoRaid then AutoRaid() end
        if Settings.AutoCurve then AutoCurve() end
        if Settings.SkinchangerV2 then SkinchangerV2() end
        if Settings.AvatarChanger then AvatarChanger() end
        if Settings.StreamerMode then StreamerMode() end
        if Settings.DisableSecurityDistance then DisableSecurityDistance() end
        if Settings.Desync then Desync() end
    end)
end)

-- ============================================
-- RESPAWN HANDLER
-- ============================================
Player.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    RootPart = char:WaitForChild("HumanoidRootPart")
    task.wait(0.5)
    if Settings.SpeedV1 then Humanoid.WalkSpeed = 25 end
end)

print("Kyriel Ultimate v2 loaded! Press M to open categorized menu.")
print("All features are grouped for easy access. Keybinds listed next to toggles.")
print("I just give the tools, whether they're used right or not is your business, boss.")

-- ============================================================
--  原始骷髅脚本 - 只修改刷物品（名称匹配）
--  其他全部保留：GUI · 自瞄 · 透视 · 飞行 · 自动攻击 · 自动喝药
-- ============================================================

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")

repeat task.wait() until player and player:FindFirstChild("PlayerGui")
local playerGui = player.PlayerGui

local old = playerGui:FindFirstChild("SkeletonGUI")
if old then old:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkeletonGUI"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false
screenGui.Enabled = true

local swingEvent, storeEvent
pcall(function()
    local r = game:GetService("ReplicatedStorage")
    if r then
        local sh = r:FindFirstChild("Shared")
        if sh then
            local u = sh:FindFirstChild("Universe")
            if u then
                local n = u:FindFirstChild("Network")
                if n then
                    local re = n:FindFirstChild("RemoteEvent")
                    if re then
                        swingEvent = re:FindFirstChild("SwingMelee")
                        storeEvent = re:FindFirstChild("Store")
                    end
                end
            end
        end
    end
end)

local weaponConfigs = {
    {get = function() return player.Backpack:FindFirstChild("Shovel") end, id = 1784980835.0023, dir = Vector3.new(-0.98141527175903, -0.17157469689846, -0.085943520069122)},
    {get = function() local c = player.Character return c and c:FindFirstChild("Shovel") end, id = 1784971142.9326, dir = Vector3.new(0.23211443424225, -0.49000316858292, 0.84024983644485)},
    {get = function() local c = player.Character return c and c:FindFirstChild("Vampire Knife") end, id = 1784980843.3721, dir = Vector3.new(0.88972532749176, 0.1092592254281, -0.44322821497917)},
    {get = function() return player.Backpack:FindFirstChild("Tomahawk") end, id = 1784980842.62, dir = Vector3.new(0.88228863477707, 0.12052091211081, -0.45501813292503)},
    {get = function() return player.Backpack:FindFirstChild("Jade Sword") end, id = 1784980841.9156, dir = Vector3.new(0.88118195533752, 0.1211147531867, -0.45700073242188)}
}

-- ============================================================
--  GUI（原始手搓菜单，保留不变）
-- ============================================================
local main = Instance.new("ScreenGui")
main.Name = "main"
main.Parent = playerGui
main.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
main.ResetOnSpawn = false

local Frame = Instance.new("Frame")
Frame.Parent = main
Frame.BackgroundColor3 = Color3.fromRGB(163, 255, 137)
Frame.BorderColor3 = Color3.fromRGB(103, 221, 213)
Frame.Position = UDim2.new(0.100320168, 0, 0.379746825, 0)
Frame.Size = UDim2.new(0, 190, 0, 130)
Frame.Active = true
Frame.Draggable = true

local TextLabel = Instance.new("TextLabel")
TextLabel.Parent = Frame
TextLabel.BackgroundColor3 = Color3.fromRGB(242, 60, 255)
TextLabel.Position = UDim2.new(0.35, 0, 0, 0)
TextLabel.Size = UDim2.new(0, 80, 0, 25)
TextLabel.Font = Enum.Font.SourceSans
TextLabel.Text = "💀 骷髅脚本"
TextLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
TextLabel.TextScaled = true
TextLabel.TextSize = 14
TextLabel.TextWrapped = true

local up = Instance.new("TextButton")
up.Parent = Frame
up.BackgroundColor3 = Color3.fromRGB(79, 255, 152)
up.Size = UDim2.new(0, 35, 0, 22)
up.Position = UDim2.new(0, 0, 0, 28)
up.Font = Enum.Font.SourceSans
up.Text = "UP"
up.TextColor3 = Color3.fromRGB(0, 0, 0)
up.TextSize = 12
up.Active = true
up.Selectable = true

local down = Instance.new("TextButton")
down.Parent = Frame
down.BackgroundColor3 = Color3.fromRGB(215, 255, 121)
down.Position = UDim2.new(0, 0, 0.491, 28)
down.Size = UDim2.new(0, 35, 0, 22)
down.Font = Enum.Font.SourceSans
down.Text = "DOWN"
down.TextColor3 = Color3.fromRGB(0, 0, 0)
down.TextSize = 12
down.Active = true
down.Selectable = true

local onof = Instance.new("TextButton")
onof.Parent = Frame
onof.BackgroundColor3 = Color3.fromRGB(255, 249, 74)
onof.Position = UDim2.new(0.45, 0, 0.491, 28)
onof.Size = UDim2.new(0, 40, 0, 22)
onof.Font = Enum.Font.SourceSans
onof.Text = "fly"
onof.TextColor3 = Color3.fromRGB(0, 0, 0)
onof.TextSize = 12
onof.Active = true
onof.Selectable = true

local plus = Instance.new("TextButton")
plus.Parent = Frame
plus.BackgroundColor3 = Color3.fromRGB(133, 145, 255)
plus.Position = UDim2.new(0.18, 0, 0, 28)
plus.Size = UDim2.new(0, 25, 0, 22)
plus.Font = Enum.Font.SourceSans
plus.Text = "+"
plus.TextColor3 = Color3.fromRGB(0, 0, 0)
plus.TextScaled = true
plus.TextSize = 12
plus.Active = true
plus.Selectable = true

local speedDisplay = Instance.new("TextLabel")
speedDisplay.Parent = Frame
speedDisplay.BackgroundColor3 = Color3.fromRGB(255, 85, 0)
speedDisplay.Position = UDim2.new(0.3, 0, 0.491, 28)
speedDisplay.Size = UDim2.new(0, 25, 0, 22)
speedDisplay.Font = Enum.Font.SourceSans
speedDisplay.Text = "1"
speedDisplay.TextColor3 = Color3.fromRGB(0, 0, 0)
speedDisplay.TextScaled = true
speedDisplay.TextSize = 12
speedDisplay.TextWrapped = true

local mine = Instance.new("TextButton")
mine.Parent = Frame
mine.BackgroundColor3 = Color3.fromRGB(123, 255, 247)
mine.Position = UDim2.new(0.18, 0, 0.491, 28)
mine.Size = UDim2.new(0, 25, 0, 22)
mine.Font = Enum.Font.SourceSans
mine.Text = "-"
mine.TextColor3 = Color3.fromRGB(0, 0, 0)
mine.TextScaled = true
mine.TextSize = 12
mine.Active = true
mine.Selectable = true

local attackBtn = Instance.new("TextButton")
attackBtn.Parent = Frame
attackBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 200)
attackBtn.Position = UDim2.new(0.02, 0, 0, 55)
attackBtn.Size = UDim2.new(0, 40, 0, 22)
attackBtn.Font = Enum.Font.SourceSans
attackBtn.Text = "⚔️"
attackBtn.TextColor3 = Color3.fromRGB(255,255,255)
attackBtn.TextSize = 12
attackBtn.Active = true
attackBtn.Selectable = true

local itemBtn = Instance.new("TextButton")
itemBtn.Parent = Frame
itemBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
itemBtn.Position = UDim2.new(0.24, 0, 0, 55)
itemBtn.Size = UDim2.new(0, 40, 0, 22)
itemBtn.Font = Enum.Font.SourceSans
itemBtn.Text = "📦"
itemBtn.TextColor3 = Color3.fromRGB(255,255,255)
itemBtn.TextSize = 12
itemBtn.Active = true
itemBtn.Selectable = true

local healBtn = Instance.new("TextButton")
healBtn.Parent = Frame
healBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
healBtn.Position = UDim2.new(0.46, 0, 0, 55)
healBtn.Size = UDim2.new(0, 40, 0, 22)
healBtn.Font = Enum.Font.SourceSans
healBtn.Text = "💚"
healBtn.TextColor3 = Color3.fromRGB(255,255,255)
healBtn.TextSize = 12
healBtn.Active = true
healBtn.Selectable = true

local closebutton = Instance.new("TextButton")
closebutton.Name = "Close"
closebutton.Parent = main.Frame
closebutton.BackgroundColor3 = Color3.fromRGB(225, 25, 0)
closebutton.Font = "SourceSans"
closebutton.Size = UDim2.new(0, 30, 0, 22)
closebutton.Text = "X"
closebutton.TextSize = 20
closebutton.Position = UDim2.new(0, 0, -1, 27)
closebutton.Active = true
closebutton.Selectable = true

local mini = Instance.new("TextButton")
mini.Parent = main.Frame
mini.BackgroundColor3 = Color3.fromRGB(192, 150, 230)
mini.Font = "SourceSans"
mini.Size = UDim2.new(0, 30, 0, 22)
mini.Text = "-"
mini.TextSize = 24
mini.Position = UDim2.new(0, 30, -1, 27)
mini.Active = true
mini.Selectable = true

local mini2 = Instance.new("TextButton")
mini2.Name = "minimize2"
mini2.Parent = main.Frame
mini2.BackgroundColor3 = Color3.fromRGB(192, 150, 230)
mini2.Font = "SourceSans"
mini2.Size = UDim2.new(0, 30, 0, 22)
mini2.Text = "+"
mini2.TextSize = 24
mini2.Position = UDim2.new(0, 30, -1, 57)
mini2.Visible = false
mini2.Active = true
mini2.Selectable = true

local speedLabel = Instance.new("TextLabel")
speedLabel.Parent = Frame
speedLabel.BackgroundTransparency = 1
speedLabel.Position = UDim2.new(0.02, 0, 0, 80)
speedLabel.Size = UDim2.new(0, 60, 0, 16)
speedLabel.Font = Enum.Font.SourceSans
speedLabel.Text = "攻速"
speedLabel.TextColor3 = Color3.fromRGB(0,0,0)
speedLabel.TextSize = 10

local speedSlider = Instance.new("Frame")
speedSlider.Parent = Frame
speedSlider.BackgroundColor3 = Color3.fromRGB(200,200,200)
speedSlider.Position = UDim2.new(0.35, 0, 0, 80)
speedSlider.Size = UDim2.new(0, 60, 0, 14)
speedSlider.BorderSizePixel = 0

local speedFill = Instance.new("Frame")
speedFill.Parent = speedSlider
speedFill.BackgroundColor3 = Color3.fromRGB(50,150,255)
speedFill.Size = UDim2.new(0.5, 0, 1, 0)
speedFill.BorderSizePixel = 0

local speedHandle = Instance.new("TextButton")
speedHandle.Parent = speedSlider
speedHandle.BackgroundColor3 = Color3.fromRGB(255,255,255)
speedHandle.Size = UDim2.new(0, 12, 0, 12)
speedHandle.Position = UDim2.new(0.5, -6, 0.5, -6)
speedHandle.Text = ""
speedHandle.BorderSizePixel = 1
speedHandle.BorderColor3 = Color3.fromRGB(0,0,0)
speedHandle.Active = true
speedHandle.Selectable = true

local healLabel = Instance.new("TextLabel")
healLabel.Parent = Frame
healLabel.BackgroundTransparency = 1
healLabel.Position = UDim2.new(0.02, 0, 0, 100)
healLabel.Size = UDim2.new(0, 60, 0, 16)
healLabel.Font = Enum.Font.SourceSans
healLabel.Text = "阈值"
healLabel.TextColor3 = Color3.fromRGB(0,0,0)
healLabel.TextSize = 10

local healSlider = Instance.new("Frame")
healSlider.Parent = Frame
healSlider.BackgroundColor3 = Color3.fromRGB(200,200,200)
healSlider.Position = UDim2.new(0.35, 0, 0, 100)
healSlider.Size = UDim2.new(0, 60, 0, 14)
healSlider.BorderSizePixel = 0

local healFill = Instance.new("Frame")
healFill.Parent = healSlider
healFill.BackgroundColor3 = Color3.fromRGB(50,200,50)
healFill.Size = UDim2.new(0.5, 0, 1, 0)
healFill.BorderSizePixel = 0

local healHandle = Instance.new("TextButton")
healHandle.Parent = healSlider
healHandle.BackgroundColor3 = Color3.fromRGB(255,255,255)
healHandle.Size = UDim2.new(0, 12, 0, 12)
healHandle.Position = UDim2.new(0.5, -6, 0.5, -6)
healHandle.Text = ""
healHandle.BorderSizePixel = 1
healHandle.BorderColor3 = Color3.fromRGB(0,0,0)
healHandle.Active = true
healHandle.Selectable = true

local swingSpeed = 0.02
local minSpeed = 0.001
local maxSpeed = 0.1
local healThreshold = 50
local minHeal = 10
local maxHeal = 90

local function updateSpeed(input)
    local rel = math.clamp((input.Position.X - speedSlider.AbsolutePosition.X) / speedSlider.AbsoluteSize.X, 0, 1)
    swingSpeed = minSpeed + rel * (maxSpeed - minSpeed)
    speedFill.Size = UDim2.new(rel, 0, 1, 0)
    speedHandle.Position = UDim2.new(rel, -6, 0.5, -6)
end

speedHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        updateSpeed(input)
    end
end)
speedHandle.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        updateSpeed(input)
    end
end)
speedSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        updateSpeed(input)
    end
end)

local function updateHeal(input)
    local rel = math.clamp((input.Position.X - healSlider.AbsolutePosition.X) / healSlider.AbsoluteSize.X, 0, 1)
    healThreshold = math.round(minHeal + rel * (maxHeal - minHeal))
    healFill.Size = UDim2.new(rel, 0, 1, 0)
    healHandle.Position = UDim2.new(rel, -6, 0.5, -6)
end

healHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        updateHeal(input)
    end
end)
healHandle.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        updateHeal(input)
    end
end)
healSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        updateHeal(input)
    end
end)

local speeds = 1
local speaker = game:GetService("Players").LocalPlayer
local nowe = false
local tpwalking = false

onof.Activated:Connect(function()
    if nowe == true then
        nowe = false
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Running,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics,true)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,true)
        speaker.Character.Humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
        onof.Text = "fly"
    else 
        nowe = true
        for i = 1, speeds do
            spawn(function()
                local hb = game:GetService("RunService").Heartbeat
                tpwalking = true
                local chr = game.Players.LocalPlayer.Character
                local hum = chr and chr:FindFirstChildWhichIsA("Humanoid")
                while tpwalking and hb:Wait() and chr and hum and hum.Parent do
                    if hum.MoveDirection.Magnitude > 0 then
                        chr:TranslateBy(hum.MoveDirection)
                    end
                end
            end)
        end
        game.Players.LocalPlayer.Character.Animate.Disabled = true
        local Char = game.Players.LocalPlayer.Character
        local Hum = Char:FindFirstChildOfClass("Humanoid") or Char:FindFirstChildOfClass("AnimationController")
        if Hum then
            for i,v in next, Hum:GetPlayingAnimationTracks() do
                v:AdjustSpeed(0)
            end
        end
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Running,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics,false)
        speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,false)
        speaker.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
        onof.Text = "stop"
    end

    if game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid").RigType == Enum.HumanoidRigType.R6 then
        local plr = game.Players.LocalPlayer
        local torso = plr.Character.Torso
        local flying = true
        local deb = true
        local ctrl = {f = 0, b = 0, l = 0, r = 0}
        local lastctrl = {f = 0, b = 0, l = 0, r = 0}
        local maxspeed = 50
        local speed = 0
        local bg = Instance.new("BodyGyro", torso)
        bg.P = 9e4
        bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.cframe = torso.CFrame
        local bv = Instance.new("BodyVelocity", torso)
        bv.velocity = Vector3.new(0,0.1,0)
        bv.maxForce = Vector3.new(9e9, 9e9, 9e9)
        if nowe == true then
            plr.Character.Humanoid.PlatformStand = true
        end
        while nowe == true or game:GetService("Players").LocalPlayer.Character.Humanoid.Health == 0 do
            game:GetService("RunService").RenderStepped:Wait()
            if ctrl.l + ctrl.r ~= 0 or ctrl.f + ctrl.b ~= 0 then
                speed = speed+.5+(speed/maxspeed)
                if speed > maxspeed then
                    speed = maxspeed
                end
            elseif not (ctrl.l + ctrl.r ~= 0 or ctrl.f + ctrl.b ~= 0) and speed ~= 0 then
                speed = speed-1
                if speed < 0 then
                    speed = 0
                end
            end
            if (ctrl.l + ctrl.r) ~= 0 or (ctrl.f + ctrl.b) ~= 0 then
                bv.velocity = ((game.Workspace.CurrentCamera.CoordinateFrame.lookVector * (ctrl.f+ctrl.b)) + ((game.Workspace.CurrentCamera.CoordinateFrame * CFrame.new(ctrl.l+ctrl.r,(ctrl.f+ctrl.b)*.2,0).p) - game.Workspace.CurrentCamera.CoordinateFrame.p))*speed
                lastctrl = {f = ctrl.f, b = ctrl.b, l = ctrl.l, r = ctrl.r}
            elseif (ctrl.l + ctrl.r) == 0 and (ctrl.f + ctrl.b) == 0 and speed ~= 0 then
                bv.velocity = ((game.Workspace.CurrentCamera.CoordinateFrame.lookVector * (lastctrl.f+lastctrl.b)) + ((game.Workspace.CurrentCamera.CoordinateFrame * CFrame.new(lastctrl.l+lastctrl.r,(lastctrl.f+lastctrl.b)*.2,0).p) - game.Workspace.CurrentCamera.CoordinateFrame.p))*speed
            else
                bv.velocity = Vector3.new(0,0,0)
            end
            bg.cframe = game.Workspace.CurrentCamera.CoordinateFrame * CFrame.Angles(-math.rad((ctrl.f+ctrl.b)*50*speed/maxspeed),0,0)
        end
        ctrl = {f = 0, b = 0, l = 0, r = 0}
        lastctrl = {f = 0, b = 0, l = 0, r = 0}
        speed = 0
        bg:Destroy()
        bv:Destroy()
        plr.Character.Humanoid.PlatformStand = false
        game.Players.LocalPlayer.Character.Animate.Disabled = false
        tpwalking = false
    else
        local plr = game.Players.LocalPlayer
        local UpperTorso = plr.Character.UpperTorso
        local flying = true
        local deb = true
        local ctrl = {f = 0, b = 0, l = 0, r = 0}
        local lastctrl = {f = 0, b = 0, l = 0, r = 0}
        local maxspeed = 50
        local speed = 0
        local bg = Instance.new("BodyGyro", UpperTorso)
        bg.P = 9e4
        bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.cframe = UpperTorso.CFrame
        local bv = Instance.new("BodyVelocity", UpperTorso)
        bv.velocity = Vector3.new(0,0.1,0)
        bv.maxForce = Vector3.new(9e9, 9e9, 9e9)
        if nowe == true then
            plr.Character.Humanoid.PlatformStand = true
        end
        while nowe == true or game:GetService("Players").LocalPlayer.Character.Humanoid.Health == 0 do
            wait()
            if ctrl.l + ctrl.r ~= 0 or ctrl.f + ctrl.b ~= 0 then
                speed = speed+.5+(speed/maxspeed)
                if speed > maxspeed then
                    speed = maxspeed
                end
            elseif not (ctrl.l + ctrl.r ~= 0 or ctrl.f + ctrl.b ~= 0) and speed ~= 0 then
                speed = speed-1
                if speed < 0 then
                    speed = 0
                end
            end
            if (ctrl.l + ctrl.r) ~= 0 or (ctrl.f + ctrl.b) ~= 0 then
                bv.velocity = ((game.Workspace.CurrentCamera.CoordinateFrame.lookVector * (ctrl.f+ctrl.b)) + ((game.Workspace.CurrentCamera.CoordinateFrame * CFrame.new(ctrl.l+ctrl.r,(ctrl.f+ctrl.b)*.2,0).p) - game.Workspace.CurrentCamera.CoordinateFrame.p))*speed
                lastctrl = {f = ctrl.f, b = ctrl.b, l = ctrl.l, r = ctrl.r}
            elseif (ctrl.l + ctrl.r) == 0 and (ctrl.f + ctrl.b) == 0 and speed ~= 0 then
                bv.velocity = ((game.Workspace.CurrentCamera.CoordinateFrame.lookVector * (lastctrl.f+lastctrl.b)) + ((game.Workspace.CurrentCamera.CoordinateFrame * CFrame.new(lastctrl.l+lastctrl.r,(lastctrl.f+lastctrl.b)*.2,0).p) - game.Workspace.CurrentCamera.CoordinateFrame.p))*speed
            else
                bv.velocity = Vector3.new(0,0,0)
            end
            bg.cframe = game.Workspace.CurrentCamera.CoordinateFrame * CFrame.Angles(-math.rad((ctrl.f+ctrl.b)*50*speed/maxspeed),0,0)
        end
        ctrl = {f = 0, b = 0, l = 0, r = 0}
        lastctrl = {f = 0, b = 0, l = 0, r = 0}
        speed = 0
        bg:Destroy()
        bv:Destroy()
        plr.Character.Humanoid.PlatformStand = false
        game.Players.LocalPlayer.Character.Animate.Disabled = false
        tpwalking = false
    end
end)

up.Activated:Connect(function()
    local char = game.Players.LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame * CFrame.new(0,1,0)
    end
end)

down.Activated:Connect(function()
    local char = game.Players.LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame * CFrame.new(0,-1,0)
    end
end)

plus.Activated:Connect(function()
    speeds = speeds + 1
    speedDisplay.Text = speeds
end)

mine.Activated:Connect(function()
    if speeds > 1 then
        speeds = speeds - 1
        speedDisplay.Text = speeds
    end
end)

closebutton.Activated:Connect(function()
    main:Destroy()
end)

mini.Activated:Connect(function()
    up.Visible = false
    down.Visible = false
    onof.Visible = false
    plus.Visible = false
    speedDisplay.Visible = false
    mine.Visible = false
    attackBtn.Visible = false
    itemBtn.Visible = false
    healBtn.Visible = false
    mini.Visible = false
    mini2.Visible = true
    main.Frame.BackgroundTransparency = 1
    closebutton.Position = UDim2.new(0, 0, -1, 57)
end)

mini2.Activated:Connect(function()
    up.Visible = true
    down.Visible = true
    onof.Visible = true
    plus.Visible = true
    speedDisplay.Visible = true
    mine.Visible = true
    attackBtn.Visible = true
    itemBtn.Visible = true
    healBtn.Visible = true
    mini.Visible = true
    mini2.Visible = false
    main.Frame.BackgroundTransparency = 0 
    closebutton.Position = UDim2.new(0, 0, -1, 27)
end)

game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function(char)
    wait(0.7)
    game.Players.LocalPlayer.Character.Humanoid.PlatformStand = false
    game.Players.LocalPlayer.Character.Animate.Disabled = false
end)

local swingRunning = false
local swingCoroutine = nil

attackBtn.Activated:Connect(function()
    if swingRunning then
        swingRunning = false
        attackBtn.Text = "⚔️"
        attackBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 200)
        return
    end
    if not swingEvent then
        return
    end
    swingRunning = true
    attackBtn.Text = "⏹"
    attackBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    swingCoroutine = coroutine.create(function()
        while swingRunning do
            for _, w in ipairs(weaponConfigs) do
                local obj = w.get()
                if obj then
                    pcall(function()
                        swingEvent:FireServer(obj, w.id, w.dir)
                    end)
                end
            end
            task.wait(swingSpeed)
        end
    end)
    coroutine.resume(swingCoroutine)
end)

-- ============================================================
--  ⚠️ 刷物品（唯一修改的部分）
--  原始：for id = itemStart to itemMax do storeEvent:FireServer(id) end
--  现在：先扫描建立 ID→名称 映射，匹配目标名称才刷
-- ============================================================

-- 要刷的物品名称（用游戏里的英文名）
local targetNames = {"Gold Bar", "Coal", "Bond"}

local itemRunning = false
local itemCoroutine = nil
local itemCurrent = 0
local itemMax = 0
local itemStart = 0
local itemTotal = 0
local itemMode = 0

itemBtn.Activated:Connect(function()
    if itemRunning then
        itemRunning = false
        itemBtn.Text = "📦"
        itemBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
        return
    end
    if not storeEvent then
        return
    end
    if itemMode == 0 then
        itemMode = 1
        itemStart = 800
        itemMax = 3000
        itemBtn.Text = "精"
        itemBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 100)
    elseif itemMode == 1 then
        itemMode = 2
        itemStart = 0
        itemMax = 5000
        itemBtn.Text = "普"
        itemBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
    else
        itemMode = 1
        itemStart = 800
        itemMax = 3000
        itemBtn.Text = "精"
        itemBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 100)
    end

    -- ===== 扫描建立 ID→名称 映射 =====
    local idToName = {}
    for _, obj in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("StringValue") then
            local name = obj.Name
            local val = obj.Value
            local id = type(val) == "number" and val or tonumber(val)
            if id and id >= 0 and id <= 10000 then
                idToName[id] = name
            end
        end
    end

    itemCurrent = itemStart
    itemTotal = itemMax - itemStart + 1
    itemRunning = true

    itemCoroutine = coroutine.create(function()
        local count = 0
        while itemRunning and itemCurrent <= itemMax do
            local name = idToName[itemCurrent]
            local shouldSpawn = false
            if name then
                for _, target in ipairs(targetNames) do
                    if name:find(target) then
                        shouldSpawn = true
                        break
                    end
                end
            end
            if shouldSpawn then
                pcall(function()
                    storeEvent:FireServer(itemCurrent)
                    storeEvent:FireServer(itemCurrent)
                    count = count + 1
                end)
            end
            itemCurrent = itemCurrent + 1
            task.wait(0.01)
        end

        if itemRunning then
            itemRunning = false
            itemBtn.Text = "📦"
            itemBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
            itemMode = 0
            print("✅ 名称匹配刷完成，共刷 " .. count .. " 件物品")
        end
    end)
    coroutine.resume(itemCoroutine)
end)

local healRunning = false
local lastHealTime = 0
local healCooldown = 2

local function GetNil(Name, DebugId)
    for _, Object in getnilinstances() do
        if Object.Name == Name and Object:GetDebugId() == DebugId then
            return Object
        end
    end
end

local useEvent = GetNil("Use", "1_325816")
local snakeOil = GetNil("Snake Oil", "1_325803")

healBtn.Activated:Connect(function()
    healRunning = not healRunning
    if healRunning then
        healBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    else
        healBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
    end
end)

RunService.Heartbeat:Connect(function()
    if not healRunning then return end
    if not useEvent or not snakeOil then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    local health = humanoid.Health
    local maxHealth = humanoid.MaxHealth
    local percent = (health / maxHealth) * 100
    if percent < healThreshold and health > 0 then
        local now = os.clock()
        if now - lastHealTime >= healCooldown then
            pcall(function()
                useEvent:FireServer(snakeOil)
                lastHealTime = now
            end)
        end
    end
end)

print("✅ 骷髅脚本已加载（名称匹配刷已启用）")
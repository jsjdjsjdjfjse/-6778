-- ============================================================
--  DFN脚本 - 最终完整版
--  刷物品：扫描ID 0~10000，按名称匹配，直接Event:FireServer(id)
--  飞行：原始骷髅脚本逻辑
--  自动攻击：原始骷髅脚本逻辑 + 攻速调节
--  自瞄 · 透视 · 夜视 · 子弹追踪 · 射线
-- ============================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
--  加载 WindUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- ============================================================
--  中文映射
-- ============================================================
local NameTranslate = {
    ["Zombie"] = "僵尸",
    ["Skeleton"] = "骷髅",
    ["Bandit"] = "强盗",
    ["Guard"] = "守卫",
    ["Boss"] = "BOSS",
    ["NewspaperBoy"] = "报童",
}
local function GetDisplayName(model)
    local eng = model.Name
    return NameTranslate[eng] or eng
end

-- ============================================================
--  获取网络事件（原始路径）
-- ============================================================
local storeEvent = ReplicatedStorage.Shared.Universe.Network.RemoteEvent.Store
local swingEvent = ReplicatedStorage.Shared.Universe.Network.RemoteEvent.SwingMelee
local useEvent = ReplicatedStorage.Shared.Universe.Network.RemoteEvent.Use

-- ============================================================
--  设置
-- ============================================================
local Settings = {
    aimbot = false,
    aimPart = "Head",
    fov = 80,
    maxDist = 300,
    wallCheck = false,
    predict = false,
    autoFire = false,
    bulletTrack = false,
    bulletSpeed = 150,
    esp = false,
    espBox = true,
    espName = true,
    espDistance = true,
    npcHighlight = false,
    showFOV = false,
    nightVision = false,
    rayLine = false,
    flyMode = false,
    attackMode = false,
    healMode = false,
    swingSpeed = 0.02,
    healThreshold = 50,
}

local touchCount = 0
local lastHealTime = 0
local healCooldown = 2

-- ============================================================
--  武器配置（原始骷髅脚本）
-- ============================================================
local weaponConfigs = {
    {get = function() return LocalPlayer.Backpack:FindFirstChild("Shovel") end, id = 1784980835.0023, dir = Vector3.new(-0.98141527175903, -0.17157469689846, -0.085943520069122)},
    {get = function() local c = LocalPlayer.Character return c and c:FindFirstChild("Shovel") end, id = 1784971142.9326, dir = Vector3.new(0.23211443424225, -0.49000316858292, 0.84024983644485)},
    {get = function() local c = LocalPlayer.Character return c and c:FindFirstChild("Vampire Knife") end, id = 1784980843.3721, dir = Vector3.new(0.88972532749176, 0.1092592254281, -0.44322821497917)},
    {get = function() return LocalPlayer.Backpack:FindFirstChild("Tomahawk") end, id = 1784980842.62, dir = Vector3.new(0.88228863477707, 0.12052091211081, -0.45501813292503)},
    {get = function() return LocalPlayer.Backpack:FindFirstChild("Jade Sword") end, id = 1784980841.9156, dir = Vector3.new(0.88118195533752, 0.1211147531867, -0.45700073242188)}
}

-- ============================================================
--  NPC列表
-- ============================================================
local function GetNPCList()
    local npcs = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local model = obj.Parent
            if model and model:IsA("Model") then
                if not Players:GetPlayerFromCharacter(model) then
                    table.insert(npcs, { model = model, humanoid = obj })
                end
            end
        end
    end
    return npcs
end

local function GetTargetPart(model)
    if not model then return nil end
    local partName = Settings.aimPart == "Head" and "Head" or "UpperTorso"
    return model:FindFirstChild(partName) or model:FindFirstChild("HumanoidRootPart")
end

local function CheckWall(part)
    if not Settings.wallCheck then return true end
    local origin = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
    if not origin then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    local result = Workspace:Raycast(origin.Position, (part.Position - origin.Position), params)
    if not result then return true end
    return result.Instance:IsDescendantOf(part.Parent)
end

local function PredictPosition(part)
    return part.Position + part.AssemblyLinearVelocity * 0.1
end

-- ============================================================
--  绘制对象
-- ============================================================
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.5
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Filled = false
fovCircle.Visible = false

local targetInfo = Drawing.new("Text")
targetInfo.Size = 16
targetInfo.Color = Color3.fromRGB(255, 255, 255)
targetInfo.Center = true
targetInfo.Outline = true
targetInfo.OutlineColor = Color3.fromRGB(0, 0, 0)
targetInfo.Visible = false

local rayLines = {}

-- ============================================================
--  自瞄硬锁头
-- ============================================================
local currentTarget = nil
local aimLockTime = 0

local function GetBestNPCTarget()
    if not Settings.aimbot then return nil end
    local center = Camera.ViewportSize / 2
    local bestScore = -math.huge
    local best = nil
    for _, npc in ipairs(GetNPCList()) do
        local part = GetTargetPart(npc.model)
        if not part then continue end
        local dist = (part.Position - Camera.CFrame.Position).Magnitude
        if dist > Settings.maxDist then continue end
        local sp, on = Camera:WorldToViewportPoint(part.Position)
        if not on then continue end
        local md = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if md > Settings.fov then continue end
        if not CheckWall(part) then continue end
        local score = -dist * 0.3 - md * 0.5
        if score > bestScore then
            bestScore = score
            best = {
                model = npc.model,
                part = part,
                position = part.Position,
                distance = dist,
                screenPos = Vector2.new(sp.X, sp.Y),
                humanoid = npc.humanoid,
            }
        end
    end
    return best
end

local function UpdateAimbot()
    if not Settings.aimbot then
        targetInfo.Visible = false
        currentTarget = nil
        return
    end

    local now = tick()
    if not currentTarget or (now - aimLockTime) > 0.1 then
        currentTarget = GetBestNPCTarget()
        aimLockTime = now
    end

    if not currentTarget then
        targetInfo.Visible = false
        return
    end

    if not currentTarget.humanoid or currentTarget.humanoid.Health <= 0 then
        currentTarget = nil
        targetInfo.Visible = false
        return
    end

    local part = GetTargetPart(currentTarget.model)
    if not part then
        currentTarget = nil
        return
    end
    currentTarget.part = part
    currentTarget.position = part.Position

    local targetPos = Settings.predict and PredictPosition(currentTarget.part) or currentTarget.part.Position
    local camPos = Camera.CFrame.Position
    Camera.CFrame = CFrame.new(camPos, targetPos)

    local sp, on = Camera:WorldToViewportPoint(targetPos)
    if on then
        currentTarget.screenPos = Vector2.new(sp.X, sp.Y)
    end

    local hp = currentTarget.humanoid and math.floor(currentTarget.humanoid.Health) or "?"
    targetInfo.Text = GetDisplayName(currentTarget.model) .. " [" .. hp .. "HP]  " .. math.floor(currentTarget.distance) .. "m"
    targetInfo.Position = Vector2.new(Camera.ViewportSize.X / 2, 40)
    targetInfo.Visible = true

    if Settings.autoFire then
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then pcall(function() tool:Activate() end) end
    end
end

-- ============================================================
--  子弹追踪
-- ============================================================
local function TrackBullets()
    if not Settings.bulletTrack then return end

    local bestNPC, bestDist = nil, math.huge
    for _, npc in ipairs(GetNPCList()) do
        local part = GetTargetPart(npc.model)
        if part then
            local d = (part.Position - Camera.CFrame.Position).Magnitude
            if d < bestDist then bestDist = d; bestNPC = npc end
        end
    end
    if not bestNPC then return end

    local targetPart = GetTargetPart(bestNPC.model)
    if not targetPart then return end
    local targetPos = Settings.predict and PredictPosition(targetPart) or targetPart.Position

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local vel = obj.AssemblyLinearVelocity
            if vel.Magnitude > 10 and vel.Magnitude < 5000 then
                local name = obj.Name
                local isBullet = name:find("步枪") or name:find("中型") or name:find("烟花") or
                                 name:find("轻型") or name:find("重型") or name:find("子弹") or
                                 name:lower():find("bullet") or name:lower():find("projectile")
                if isBullet then
                    local dir = (targetPos - obj.Position).Unit
                    obj.AssemblyLinearVelocity = dir * Settings.bulletSpeed
                    pcall(function() obj.CFrame = CFrame.new(obj.Position, targetPos) end)
                end
            end
        end
    end
end

-- ============================================================
--  透视（含独立射线）
-- ============================================================
local espDrawings = {}

local function UpdateESP()
    local espOn = Settings.esp
    for model, data in pairs(espDrawings) do
        data.box.Visible = false
        data.name.Visible = false
        data.dist.Visible = false
        data.hpBar.Visible = false
        if data.highlight then data.highlight.Enabled = false end
    end
    for _, line in ipairs(rayLines) do
        line.Visible = false
    end
    rayLines = {}

    if not espOn then return end

    local camPos = Camera.CFrame.Position
    local currentModels = {}
    local center = Camera.ViewportSize / 2

    for _, npc in ipairs(GetNPCList()) do
        local model = npc.model
        local humanoid = npc.humanoid
        currentModels[model] = true
        local hp = humanoid.Health
        if hp <= 0 then continue end

        local hrp = model:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local dist = (hrp.Position - camPos).Magnitude
        if dist > 400 then continue end
        local sp, on = Camera:WorldToViewportPoint(hrp.Position)
        if not on then continue end

        local maxHp = humanoid.MaxHealth
        local hpPercent = maxHp > 0 and math.clamp(hp / maxHp, 0, 1) or 1
        local color = Color3.fromRGB(255, 80, 80)

        if not espDrawings[model] then
            local box = Drawing.new("Square")
            box.Thickness = 1
            box.Filled = false
            box.Visible = false
            local nameTxt = Drawing.new("Text")
            nameTxt.Size = 14
            nameTxt.Center = true
            nameTxt.Outline = true
            nameTxt.OutlineColor = Color3.fromRGB(0, 0, 0)
            nameTxt.Visible = false
            local distTxt = Drawing.new("Text")
            distTxt.Size = 12
            distTxt.Center = true
            distTxt.Outline = true
            distTxt.OutlineColor = Color3.fromRGB(0, 0, 0)
            distTxt.Visible = false
            local hpBar = Drawing.new("Line")
            hpBar.Thickness = 3
            hpBar.Color = Color3.fromRGB(0, 255, 0)
            hpBar.Visible = false
            espDrawings[model] = { box = box, name = nameTxt, dist = distTxt, hpBar = hpBar, highlight = nil }
        end

        local data = espDrawings[model]
        local scale = 200 / math.max(dist, 1)
        local w, h = 2 * scale, 3 * scale
        local top, left = sp.Y - h / 2, sp.X - w / 2

        if Settings.espBox then
            data.box.Visible = true
            data.box.Position = Vector2.new(left, top)
            data.box.Size = Vector2.new(w, h)
            data.box.Color = color
        end

        if Settings.espName then
            data.name.Visible = true
            data.name.Text = GetDisplayName(model) .. " [" .. math.floor(hp) .. "HP]"
            data.name.Position = Vector2.new(sp.X, top - 14)
            data.name.Color = Color3.fromRGB(255, 255, 255)
        end

        if Settings.espDistance then
            data.dist.Visible = true
            data.dist.Text = math.floor(dist) .. "m"
            data.dist.Position = Vector2.new(sp.X, top + h + 12)
        end

        local barWidth = w
        local barY = top + h + 4
        local barLeft = sp.X - barWidth / 2
        local barRight = barLeft + barWidth * hpPercent
        data.hpBar.Visible = true
        data.hpBar.From = Vector2.new(barLeft, barY)
        data.hpBar.To = Vector2.new(barRight, barY)
        data.hpBar.Color = color

        if Settings.npcHighlight then
            if not data.highlight then
                local hl = Instance.new("Highlight")
                hl.Adornee = model
                hl.FillTransparency = 0.6
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = model
                data.highlight = hl
            end
            data.highlight.Enabled = true
            data.highlight.OutlineColor = color
            data.highlight.FillColor = color
        end

        -- 独立射线透视
        if Settings.rayLine then
            local line = Drawing.new("Line")
            line.Thickness = 1.5
            line.Color = Color3.fromRGB(255, 0, 0)
            line.From = center
            line.To = Vector2.new(sp.X, sp.Y)
            line.Visible = true
            table.insert(rayLines, line)
        end
    end

    for model, data in pairs(espDrawings) do
        if not currentModels[model] then
            if data.highlight then data.highlight:Destroy() end
            data.box:Remove()
            data.name:Remove()
            data.dist:Remove()
            data.hpBar:Remove()
            espDrawings[model] = nil
        end
    end
end

Workspace.DescendantRemoving:Connect(function(desc)
    if desc:IsA("Model") and espDrawings[desc] then
        local d = espDrawings[desc]
        if d.highlight then d.highlight:Destroy() end
        d.box:Remove()
        d.name:Remove()
        d.dist:Remove()
        d.hpBar:Remove()
        espDrawings[desc] = nil
    end
end)

-- ============================================================
--  夜视
-- ============================================================
local originalAmbient, originalBrightness, originalClockTime, originalOutdoorAmbient, originalDiffuse, originalSpecular

local function SaveLighting()
    originalAmbient = Lighting.Ambient
    originalBrightness = Lighting.Brightness
    originalClockTime = Lighting.ClockTime
    originalOutdoorAmbient = Lighting.OutdoorAmbient
    originalDiffuse = Lighting.EnvironmentDiffuseScale
    originalSpecular = Lighting.EnvironmentSpecularScale
end

local function ForceNightVision()
    if Settings.nightVision then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 3
        Lighting.ClockTime = 12
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 1
    else
        if originalAmbient then
            Lighting.Ambient = originalAmbient
            Lighting.Brightness = originalBrightness
            Lighting.ClockTime = originalClockTime
            Lighting.OutdoorAmbient = originalOutdoorAmbient
            Lighting.EnvironmentDiffuseScale = originalDiffuse
            Lighting.EnvironmentSpecularScale = originalSpecular
        end
    end
end

SaveLighting()

-- ============================================================
--  主循环
-- ============================================================
RunService.RenderStepped:Connect(function()
    fovCircle.Position = Camera.ViewportSize / 2
    fovCircle.Radius = Settings.fov
    fovCircle.Visible = Settings.showFOV
    ForceNightVision()
    UpdateAimbot()
    TrackBullets()
    UpdateESP()
end)

-- ============================================================
--  刷物品（原始骷髅脚本逻辑 + 0~10000扫描）
-- ============================================================

-- 扫描 0~10000 范围内的所有物品
local function ScanItems()
    local items = {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("StringValue") then
            local name = obj.Name
            local val = obj.Value
            local id = type(val) == "number" and val or tonumber(val)
            if id and id >= 0 and id <= 10000 then
                items[name] = id
            end
        end
    end
    return items
end

-- 按名称刷（从0~10000扫描结果中匹配）
local function SpawnByName(itemName)
    local items = ScanItems()
    local id = items[itemName]
    if not id then
        for name, val in pairs(items) do
            if name:find(itemName) then
                id = val
                itemName = name
                break
            end
        end
    end
    if not id then
        WindUI:Notify({ Title = "❌ 未找到物品", Content = "当前局没有 " .. itemName, Duration = 3 })
        return
    end
    pcall(function()
        storeEvent:FireServer(id)
    end)
    WindUI:Notify({ Title = "✅ 已刷 " .. itemName, Content = "ID: " .. id, Duration = 3 })
end

-- 按 ID 范围刷
local function SpawnRange(startId, endId)
    if not storeEvent then
        WindUI:Notify({ Title = "❌ 错误", Content = "Store事件不存在", Duration = 3 })
        return
    end
    for id = startId, endId do
        pcall(function()
            storeEvent:FireServer(id)
        end)
        task.wait(0.01)
    end
    WindUI:Notify({ Title = "✅ 刷取完成", Content = "已刷 ID " .. startId .. " ~ " .. endId, Duration = 3 })
end

-- ============================================================
--  飞行功能（原始骷髅脚本逻辑）
-- ============================================================
local flyEnabled = false
local flyBV = nil

local function ToggleFly()
    flyEnabled = not flyEnabled
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if flyEnabled then
        hum.PlatformStand = true
        hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Running, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
        hum:ChangeState(Enum.HumanoidStateType.Swimming)
        char.Animate.Disabled = true

        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        flyBV.Velocity = Vector3.new(0, 0, 0)
        flyBV.Parent = char

        WindUI:Notify({ Title = "✅ 飞行已开启", Content = "WASD移动，Space上升，Shift下降", Duration = 3 })

        task.spawn(function()
            while flyEnabled and char and char.Parent do
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then break end
                local move = Vector3.new(0, 0, 0)
                local speed = 50
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Camera.CFrame.LookVector * speed end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector * speed end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - Camera.CFrame.RightVector * speed end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector * speed end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, speed, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, speed, 0) end
                flyBV.Velocity = move
                task.wait()
            end
        end)
    else
        hum.PlatformStand = false
        for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
            hum:SetStateEnabled(state, true)
        end
        char.Animate.Disabled = false
        hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
        if flyBV then flyBV:Destroy() flyBV = nil end
        WindUI:Notify({ Title = "✅ 飞行已关闭", Duration = 2 })
    end
end

-- ============================================================
--  自动攻击（原始骷髅脚本逻辑 + 攻速调节）
-- ============================================================
local attackRunning = false
local attackCoroutine = nil

local function ToggleAttack()
    attackRunning = not attackRunning
    if attackRunning then
        WindUI:Notify({ Title = "✅ 自动攻击已开启", Content = "攻速: " .. Settings.swingSpeed, Duration = 3 })
        attackCoroutine = task.spawn(function()
            while attackRunning do
                for _, w in ipairs(weaponConfigs) do
                    local obj = w.get()
                    if obj and swingEvent then
                        pcall(function()
                            swingEvent:FireServer(obj, w.id, w.dir)
                        end)
                    end
                end
                task.wait(Settings.swingSpeed)
            end
        end)
    else
        if attackCoroutine then task.cancel(attackCoroutine) attackCoroutine = nil end
        WindUI:Notify({ Title = "✅ 自动攻击已关闭", Duration = 2 })
    end
end

-- ============================================================
--  自动喝药
-- ============================================================
local healRunning = false

local function ToggleHeal()
    healRunning = not healRunning
    if healRunning then
        WindUI:Notify({ Title = "✅ 自动喝药已开启", Content = "阈值: " .. Settings.healThreshold .. "%", Duration = 3 })
    else
        WindUI:Notify({ Title = "✅ 自动喝药已关闭", Duration = 2 })
    end
end

RunService.Heartbeat:Connect(function()
    if not healRunning then return end
    if not useEvent then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local hp = hum.Health
    local maxHp = hum.MaxHealth
    if maxHp <= 0 then return end
    if (hp / maxHp) * 100 < Settings.healThreshold and hp > 0 then
        local now = os.clock()
        if now - lastHealTime >= healCooldown then
            local items = ScanItems()
            local snakeId = items["Snake Oil"] or items["蛇油"]
            if snakeId then
                pcall(function()
                    useEvent:FireServer(snakeId)
                    lastHealTime = now
                end)
            end
        end
    end
end)

-- ============================================================
--  WindUI 菜单
-- ============================================================
local Window = WindUI:CreateWindow({
    Title = "DFN脚本",
    Folder = "DFN",
    Icon = "solar:crosshair-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "DFN脚本",
        Enabled = true,
        Draggable = true,
        OnlyMobile = true,
        Scale = 0.7,
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Mac",
    },
})

Window:Tag({
    Title = "v3.0",
    Icon = "smartphone",
    Color = Color3.fromHex("#1c1c1c"),
    Border = true,
})

-- ============================================================
--  自瞄标签页
-- ============================================================
local AimbotTab = Window:Tab({ Title = "自瞄", Icon = "solar:target-bold" })

AimbotTab:Toggle({
    Title = "NPC自瞄",
    Value = false,
    Callback = function(v)
        Settings.aimbot = v
        WindUI:Notify({ Title = v and "✅ 自瞄已开启" or "✅ 自瞄已关闭", Duration = 2 })
    end,
})

AimbotTab:Dropdown({
    Title = "瞄准部位",
    Values = { "头部", "身体" },
    Value = "头部",
    Callback = function(option)
        Settings.aimPart = option == "头部" and "Head" or "UpperTorso"
    end,
})

AimbotTab:Toggle({
    Title = "穿墙检测",
    Value = false,
    Callback = function(v)
        Settings.wallCheck = v
        WindUI:Notify({ Title = v and "✅ 穿墙检测已开启" or "✅ 穿墙检测已关闭", Duration = 2 })
    end,
})

AimbotTab:Toggle({
    Title = "预判",
    Value = false,
    Callback = function(v)
        Settings.predict = v
        WindUI:Notify({ Title = v and "✅ 预判已开启" or "✅ 预判已关闭", Duration = 2 })
    end,
})

AimbotTab:Toggle({
    Title = "自动开火",
    Value = false,
    Callback = function(v)
        Settings.autoFire = v
        WindUI:Notify({ Title = v and "✅ 自动开火已开启" or "✅ 自动开火已关闭", Duration = 2 })
    end,
})

AimbotTab:Toggle({
    Title = "显示FOV圈",
    Value = false,
    Callback = function(v)
        Settings.showFOV = v
        WindUI:Notify({ Title = v and "✅ FOV圈已显示" or "✅ FOV圈已隐藏", Duration = 2 })
    end,
})

AimbotTab:Slider({
    Title = "FOV大小",
    Step = 1,
    Value = { Min = 20, Max = 300, Default = 80 },
    Callback = function(v) Settings.fov = v end,
})

AimbotTab:Slider({
    Title = "最大距离",
    Step = 1,
    Value = { Min = 50, Max = 800, Default = 300 },
    Callback = function(v) Settings.maxDist = v end,
})

-- ============================================================
--  视觉标签页
-- ============================================================
local VisualTab = Window:Tab({ Title = "视觉", Icon = "solar:eye-bold" })

VisualTab:Toggle({
    Title = "夜视",
    Value = false,
    Callback = function(v)
        Settings.nightVision = v
        WindUI:Notify({ Title = v and "✅ 夜视已开启" or "✅ 夜视已关闭", Duration = 2 })
    end,
})

VisualTab:Toggle({
    Title = "NPC透视",
    Value = false,
    Callback = function(v)
        Settings.esp = v
        WindUI:Notify({ Title = v and "✅ 透视已开启" or "✅ 透视已关闭", Duration = 2 })
    end,
})

VisualTab:Toggle({
    Title = "NPC高亮",
    Value = false,
    Callback = function(v)
        Settings.npcHighlight = v
        WindUI:Notify({ Title = v and "✅ 高亮已开启" or "✅ 高亮已关闭", Duration = 2 })
    end,
})

VisualTab:Toggle({
    Title = "射线透视",
    Value = false,
    Callback = function(v)
        Settings.rayLine = v
        WindUI:Notify({ Title = v and "✅ 射线已开启" or "✅ 射线已关闭", Duration = 2 })
    end,
})

VisualTab:Toggle({
    Title = "显示名字+血量",
    Value = true,
    Callback = function(v)
        Settings.espName = v
        WindUI:Notify({ Title = v and "✅ 名字+血量已显示" or "✅ 名字+血量已隐藏", Duration = 2 })
    end,
})

VisualTab:Toggle({
    Title = "显示距离",
    Value = true,
    Callback = function(v)
        Settings.espDistance = v
        WindUI:Notify({ Title = v and "✅ 距离已显示" or "✅ 距离已隐藏", Duration = 2 })
    end,
})

-- ============================================================
--  武器标签页
-- ============================================================
local WeaponTab = Window:Tab({ Title = "武器", Icon = "solar:gun-bold" })

WeaponTab:Toggle({
    Title = "子弹追踪",
    Value = false,
    Callback = function(v)
        Settings.bulletTrack = v
        WindUI:Notify({ Title = v and "✅ 子弹追踪已开启" or "✅ 子弹追踪已关闭", Duration = 2 })
    end,
})

WeaponTab:Slider({
    Title = "子弹力度",
    Step = 1,
    Value = { Min = 50, Max = 300, Default = 150 },
    Callback = function(v) Settings.bulletSpeed = v end,
})

WeaponTab:Toggle({
    Title = "自动攻击",
    Value = false,
    Callback = function(v)
        ToggleAttack()
    end,
})

WeaponTab:Slider({
    Title = "攻击速度",
    Step = 0.001,
    Value = { Min = 0.001, Max = 0.1, Default = 0.02 },
    Callback = function(v)
        Settings.swingSpeed = v
        if attackRunning then
            WindUI:Notify({ Title = "✅ 攻速已更新", Content = "当前: " .. v, Duration = 2 })
        end
    end,
})

-- ============================================================
--  物品标签页
-- ============================================================
local ItemTab = Window:Tab({ Title = "物品", Icon = "solar:box-bold" })

ItemTab:Button({
    Title = "🔍 扫描 0~10000",
    Callback = function()
        local items = ScanItems()
        local count = 0
        for name, id in pairs(items) do
            count = count + 1
            print(name .. " -> " .. id)
        end
        WindUI:Notify({ Title = "✅ 扫描完成", Content = "共找到 " .. count .. " 个物品", Duration = 4 })
    end,
})

ItemTab:Button({
    Title = "📦 刷 ID 0~10000",
    Callback = function()
        SpawnRange(0, 10000)
    end,
})

ItemTab:Space()
ItemTab:Section({ Title = "分类刷取" })

local function CreateSpawnButton(itemName, label)
    ItemTab:Button({
        Title = label,
        Callback = function()
            SpawnByName(itemName)
        end,
    })
end

CreateSpawnButton("国库券", "💵 国库券")
CreateSpawnButton("金条", "🪙 金条")
CreateSpawnButton("银条", "🪙 银条")
CreateSpawnButton("金酒杯", "🏆 金酒杯")
CreateSpawnButton("银酒杯", "🏆 银酒杯")
CreateSpawnButton("金盘子", "🍽️ 金盘子")
CreateSpawnButton("银盘子", "🍽️ 银盘子")
CreateSpawnButton("金画像", "🖼️ 金画像")
CreateSpawnButton("银画像", "🖼️ 银画像")
CreateSpawnButton("金雕像", "🗿 金雕像")
CreateSpawnButton("银雕像", "🗿 银雕像")
CreateSpawnButton("步枪", "🔫 步枪")
CreateSpawnButton("海军手枪", "🔫 海军手枪")
CreateSpawnButton("手枪", "🔫 手枪")
CreateSpawnButton("散弹枪", "🔫 散弹枪")
CreateSpawnButton("烟花枪", "🎆 烟花枪")
CreateSpawnButton("吸血鬼刀", "🗡️ 吸血鬼刀")
CreateSpawnButton("翡翠宝刀", "🗡️ 翡翠宝刀")
CreateSpawnButton("步枪子弹", "📦 步枪子弹")
CreateSpawnButton("散弹枪子弹", "📦 散弹枪子弹")
CreateSpawnButton("中型子弹", "📦 中型子弹")
CreateSpawnButton("重型子弹", "📦 重型子弹")
CreateSpawnButton("轻型子弹", "📦 轻型子弹")
CreateSpawnButton("烟花枪子弹", "📦 烟花枪子弹")
CreateSpawnButton("蛇油", "🧪 蛇油")
CreateSpawnButton("绷带", "🩹 绷带")
CreateSpawnButton("煤", "🪨 煤")
CreateSpawnButton("奇怪的面具", "🎭 奇怪的面具")
CreateSpawnButton("危险巴士", "🚌 危险巴士")

-- ============================================================
--  设置标签页
-- ============================================================
local SettingsTab = Window:Tab({ Title = "设置", Icon = "solar:settings-bold" })

SettingsTab:Toggle({
    Title = "飞行模式",
    Value = false,
    Callback = function(v)
        ToggleFly()
    end,
})

SettingsTab:Toggle({
    Title = "自动喝药",
    Value = false,
    Callback = function(v)
        ToggleHeal()
    end,
})

SettingsTab:Slider({
    Title = "喝药阈值 (%)",
    Step = 1,
    Value = { Min = 10, Max = 90, Default = 50 },
    Callback = function(v)
        Settings.healThreshold = v
        if healRunning then
            WindUI:Notify({ Title = "✅ 阈值已更新", Content = "血量低于 " .. v .. "% 自动喝药", Duration = 3 })
        end
    end,
})

-- ============================================================
--  触摸控制
-- ============================================================
UserInputService.TouchStarted:Connect(function()
    touchCount = touchCount + 1
end)

UserInputService.TouchEnded:Connect(function()
    if touchCount > 0 then touchCount = touchCount - 1 end
end)

-- ============================================================
--  启动提示
-- ============================================================
local function PlayStartSound()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://9120263686"
    sound.Volume = 1
    sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, 2)
end

PlayStartSound()

WindUI:Notify({
    Title = "✅ DFN脚本已加载",
    Content = "点击菜单按钮开始使用",
    Icon = "solar:check-circle-bold",
    Duration = 4,
})

print("✅ DFN脚本已启动")

-- ============================================================
--  DFN脚本 - 完整整合版
--  功能：自瞄 · 透视 · 夜视 · 子弹追踪 · 飞行 · 自动攻击 · 指定刷物品 · 自动喝药
--  所有功能开启时弹窗提示，刷物品自动调用两次
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
--  获取网络事件
-- ============================================================
local function GetNetworkEvents()
    local events = {}
    pcall(function()
        local r = ReplicatedStorage
        if r then
            local sh = r:FindFirstChild("Shared")
            if sh then
                local u = sh:FindFirstChild("Universe")
                if u then
                    local n = u:FindFirstChild("Network")
                    if n then
                        local re = n:FindFirstChild("RemoteEvent")
                        if re then
                            events.swingEvent = re:FindFirstChild("SwingMelee")
                            events.storeEvent = re:FindFirstChild("Store")
                            events.useEvent = re:FindFirstChild("Use")
                        end
                    end
                end
            end
        end
    end)
    return events
end

local Events = GetNetworkEvents()
local swingEvent = Events.swingEvent
local storeEvent = Events.storeEvent
local useEvent = Events.useEvent

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
local tpwalking = false
local swingRunning = false
local healRunning = false
local lastHealTime = 0
local healCooldown = 2

-- ============================================================
--  武器配置
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

local rayLine = Drawing.new("Line")
rayLine.Thickness = 1.5
rayLine.Color = Color3.fromRGB(255, 0, 0)
rayLine.Visible = false

local targetInfo = Drawing.new("Text")
targetInfo.Size = 16
targetInfo.Color = Color3.fromRGB(255, 255, 255)
targetInfo.Center = true
targetInfo.Outline = true
targetInfo.OutlineColor = Color3.fromRGB(0, 0, 0)
targetInfo.Visible = false

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
        rayLine.Visible = false
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
        rayLine.Visible = false
        return
    end

    if not currentTarget.humanoid or currentTarget.humanoid.Health <= 0 then
        currentTarget = nil
        targetInfo.Visible = false
        rayLine.Visible = false
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

    if Settings.rayLine then
        rayLine.From = Camera.ViewportSize / 2
        rayLine.To = currentTarget.screenPos
        rayLine.Visible = true
    else
        rayLine.Visible = false
    end

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
--  透视
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
    if not espOn then return end

    local camPos = Camera.CFrame.Position
    local currentModels = {}

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
--  飞行功能
-- ============================================================
local function ToggleFly()
    Settings.flyMode = not Settings.flyMode
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if Settings.flyMode then
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
        hum.PlatformStand = true
        WindUI:Notify({ Title = "✅ 飞行已开启", Content = "方向键控制移动", Duration = 3 })
    else
        for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
            hum:SetStateEnabled(state, true)
        end
        char.Animate.Disabled = false
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
        WindUI:Notify({ Title = "✅ 飞行已关闭", Content = "已恢复正常", Duration = 3 })
    end
end

-- ============================================================
--  自动攻击
-- ============================================================
local function ToggleAttack()
    Settings.attackMode = not Settings.attackMode
    if Settings.attackMode then
        WindUI:Notify({ Title = "✅ 自动攻击已开启", Content = "持续挥砍武器", Duration = 3 })
        task.spawn(function()
            while Settings.attackMode do
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
        WindUI:Notify({ Title = "✅ 自动攻击已关闭", Duration = 3 })
    end
end

-- ============================================================
--  物品刷取（同ID调用两次：装袋+取出）
-- ============================================================
local function SpawnItemById(itemId, count)
    count = count or 1
    if not storeEvent then
        WindUI:Notify({ Title = "⚠️ 错误", Content = "未找到Store事件", Duration = 3 })
        return false
    end
    if not itemId or itemId <= 0 then
        WindUI:Notify({ Title = "⚠️ 错误", Content = "无效的物品ID", Duration = 3 })
        return false
    end

    for i = 1, count do
        pcall(function()
            storeEvent:FireServer(itemId)  -- 第一次：装袋
            storeEvent:FireServer(itemId)  -- 第二次：取出
        end)
        if i % 10 == 0 then
            task.wait(0.05)
        end
        task.wait(0.01)
    end
    return true
end

-- ============================================================
--  扫描所有物品
-- ============================================================
local function ScanAllItems()
    local items = {}
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("NumberValue") or obj:IsA("StringValue") then
                local name = obj.Name
                local value = obj.Value
                if type(value) == "number" and value > 0 and value < 100000000 then
                    items[name] = value
                end
            end
        end
    end)
    return items
end

-- ============================================================
--  按关键词查找物品ID
-- ============================================================
local function FindItemByKeywords(keywords)
    local items = ScanAllItems()
    for name, id in pairs(items) do
        for _, kw in ipairs(keywords) do
            if name:find(kw) then
                return id, name
            end
        end
    end
    return nil, nil
end

-- ============================================================
--  物品关键词表
-- ============================================================
local TargetItems = {
    -- 高价值
    GoldBar = {"金条", "GoldBar", "Gold"},
    SilverBar = {"银条", "SilverBar", "Silver"},
    GoldCup = {"金酒杯", "GoldCup"},
    SilverCup = {"银酒杯", "SilverCup"},
    GoldPlate = {"金盘子", "GoldPlate"},
    SilverPlate = {"银盘子", "SilverPlate"},
    GoldPainting = {"金画像", "GoldPainting"},
    SilverPainting = {"银画像", "SilverPainting"},
    GoldStatue = {"金雕像", "GoldStatue"},
    SilverStatue = {"银雕像", "SilverStatue"},
    Bond = {"国库券", "债券", "Treasury", "Bond"},

    -- 武器
    Rifle = {"步枪", "Rifle"},
    NavyPistol = {"海军手枪", "NavyPistol"},
    Pistol = {"手枪", "Pistol"},
    Shotgun = {"散弹枪", "Shotgun"},
    FireworkGun = {"烟花枪", "FireworkGun"},
    VampireKnife = {"吸血鬼刀", "Vampire Knife"},
    JadeSword = {"翡翠宝刀", "Jade Sword"},

    -- 子弹
    RifleBullet = {"步枪子弹", "RifleBullet"},
    ShotgunBullet = {"散弹枪子弹", "ShotgunBullet"},
    MediumBullet = {"中型子弹", "MediumBullet"},
    HeavyBullet = {"重型子弹", "HeavyBullet"},
    LightBullet = {"轻型子弹", "LightBullet"},
    FireworkBullet = {"烟花枪子弹", "FireworkBullet"},

    -- 消耗品/材料
    SnakeOil = {"蛇油", "Snake Oil"},
    Bandage = {"绷带", "Bandage"},
    Coal = {"煤", "Coal"},
    Mask = {"奇怪的面具", "Mask"},
    Bus = {"危险巴士", "Bus"},
}

-- ============================================================
--  自动喝药
-- ============================================================
local function ToggleHeal()
    Settings.healMode = not Settings.healMode
    if Settings.healMode then
        WindUI:Notify({
            Title = "✅ 自动喝药已开启",
            Content = "血量低于 " .. Settings.healThreshold .. "% 时自动喝蛇油",
            Duration = 3,
        })
    else
        WindUI:Notify({ Title = "✅ 自动喝药已关闭", Duration = 3 })
    end
end

-- 喝药检测
RunService.Heartbeat:Connect(function()
    if not Settings.healMode then return end
    if not useEvent then return end

    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end

    local health = humanoid.Health
    local maxHealth = humanoid.MaxHealth
    if maxHealth <= 0 then return end

    local percent = (health / maxHealth) * 100
    if percent < Settings.healThreshold and health > 0 then
        local now = os.clock()
        if now - lastHealTime >= healCooldown then
            -- 找蛇油
            local snakeOilId, _ = FindItemByKeywords(TargetItems.SnakeOil)
            if snakeOilId then
                pcall(function()
                    useEvent:FireServer(snakeOilId)
                    lastHealTime = now
                end)
            end
        end
    end
end)

-- ============================================================
--  创建 WindUI 菜单
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
    Title = "v1.0",
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
        WindUI:Notify({
            Title = v and "✅ 自瞄已开启" or "✅ 自瞄已关闭",
            Duration = 2,
        })
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
        WindUI:Notify({
            Title = v and "✅ 穿墙检测已开启" or "✅ 穿墙检测已关闭",
            Duration = 2,
        })
    end,
})

AimbotTab:Toggle({
    Title = "预判",
    Value = false,
    Callback = function(v)
        Settings.predict = v
        WindUI:Notify({
            Title = v and "✅ 预判已开启" or "✅ 预判已关闭",
            Duration = 2,
        })
    end,
})

AimbotTab:Toggle({
    Title = "自动开火",
    Value = false,
    Callback = function(v)
        Settings.autoFire = v
        WindUI:Notify({
            Title = v and "✅ 自动开火已开启" or "✅ 自动开火已关闭",
            Duration = 2,
        })
    end,
})

AimbotTab:Toggle({
    Title = "显示FOV圈",
    Value = false,
    Callback = function(v)
        Settings.showFOV = v
        WindUI:Notify({
            Title = v and "✅ FOV圈已显示" or "✅ FOV圈已隐藏",
            Duration = 2,
        })
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
        WindUI:Notify({
            Title = v and "✅ 夜视已开启" or "✅ 夜视已关闭",
            Duration = 2,
        })
    end,
})

VisualTab:Toggle({
    Title = "NPC透视",
    Value = false,
    Callback = function(v)
        Settings.esp = v
        WindUI:Notify({
            Title = v and "✅ 透视已开启" or "✅ 透视已关闭",
            Duration = 2,
        })
    end,
})

VisualTab:Toggle({
    Title = "NPC高亮",
    Value = false,
    Callback = function(v)
        Settings.npcHighlight = v
        WindUI:Notify({
            Title = v and "✅ 高亮已开启" or "✅ 高亮已关闭",
            Duration = 2,
        })
    end,
})

VisualTab:Toggle({
    Title = "射线透视",
    Value = false,
    Callback = function(v)
        Settings.rayLine = v
        WindUI:Notify({
            Title = v and "✅ 射线已开启" or "✅ 射线已关闭",
            Duration = 2,
        })
    end,
})

VisualTab:Toggle({
    Title = "显示名字+血量",
    Value = true,
    Callback = function(v)
        Settings.espName = v
        WindUI:Notify({
            Title = v and "✅ 名字+血量已显示" or "✅ 名字+血量已隐藏",
            Duration = 2,
        })
    end,
})

VisualTab:Toggle({
    Title = "显示距离",
    Value = true,
    Callback = function(v)
        Settings.espDistance = v
        WindUI:Notify({
            Title = v and "✅ 距离已显示" or "✅ 距离已隐藏",
            Duration = 2,
        })
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
        WindUI:Notify({
            Title = v and "✅ 子弹追踪已开启" or "✅ 子弹追踪已关闭",
            Duration = 2,
        })
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
        Settings.attackMode = v
        ToggleAttack()
    end,
})

WeaponTab:Slider({
    Title = "攻击速度",
    Step = 0.001,
    Value = { Min = 0.001, Max = 0.1, Default = 0.02 },
    Callback = function(v) Settings.swingSpeed = v end,
})

-- ============================================================
--  物品标签页
-- ============================================================
local ItemTab = Window:Tab({ Title = "物品", Icon = "solar:box-bold" })

-- 刷物品按钮（动态生成）
local function CreateSpawnButton(itemKey, label)
    ItemTab:Button({
        Title = label,
        Callback = function()
            local keywords = TargetItems[itemKey]
            if not keywords then
                WindUI:Notify({ Title = "⚠️ 错误", Content = "未找到物品配置", Duration = 3 })
                return
            end
            local id, name = FindItemByKeywords(keywords)
            if id then
                SpawnItemById(id, 1)
                WindUI:Notify({
                    Title = "✅ 已刷 " .. name,
                    Content = "ID: " .. id,
                    Duration = 3,
                })
            else
                WindUI:Notify({
                    Title = "⚠️ 未找到物品",
                    Content = "请检查游戏内物品名称",
                    Duration = 3,
                })
            end
        end,
    })
end

-- 高价值物品
CreateSpawnButton("Bond", "💵 刷国库券")
CreateSpawnButton("GoldBar", "🪙 刷金条")
CreateSpawnButton("SilverBar", "🪙 刷银条")
CreateSpawnButton("GoldCup", "🏆 刷金酒杯")
CreateSpawnButton("SilverCup", "🏆 刷银酒杯")
CreateSpawnButton("GoldPlate", "🍽️ 刷金盘子")
CreateSpawnButton("SilverPlate", "🍽️ 刷银盘子")
CreateSpawnButton("GoldPainting", "🖼️ 刷金画像")
CreateSpawnButton("SilverPainting", "🖼️ 刷银画像")
CreateSpawnButton("GoldStatue", "🗿 刷金雕像")
CreateSpawnButton("SilverStatue", "🗿 刷银雕像")

-- 武器
CreateSpawnButton("Rifle", "🔫 刷步枪")
CreateSpawnButton("NavyPistol", "🔫 刷海军手枪")
CreateSpawnButton("Pistol", "🔫 刷手枪")
CreateSpawnButton("Shotgun", "🔫 刷散弹枪")
CreateSpawnButton("FireworkGun", "🎆 刷烟花枪")
CreateSpawnButton("VampireKnife", "🗡️ 刷吸血鬼刀")
CreateSpawnButton("JadeSword", "🗡️ 刷翡翠宝刀")

-- 子弹
CreateSpawnButton("RifleBullet", "📦 刷步枪子弹")
CreateSpawnButton("ShotgunBullet", "📦 刷散弹枪子弹")
CreateSpawnButton("MediumBullet", "📦 刷中型子弹")
CreateSpawnButton("HeavyBullet", "📦 刷重型子弹")
CreateSpawnButton("LightBullet", "📦 刷轻型子弹")
CreateSpawnButton("FireworkBullet", "📦 刷烟花枪子弹")

-- 消耗品
CreateSpawnButton("SnakeOil", "🧪 刷蛇油")
CreateSpawnButton("Bandage", "🩹 刷绷带")
CreateSpawnButton("Coal", "🪨 刷煤")
CreateSpawnButton("Mask", "🎭 刷奇怪的面具")
CreateSpawnButton("Bus", "🚌 刷危险巴士")

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
        if Settings.healMode then
            WindUI:Notify({
                Title = "✅ 喝药阈值已更新",
                Content = "血量低于 " .. v .. "% 时自动喝药",
                Duration = 3,
            })
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
--  启动提示（声音 + 弹窗）
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
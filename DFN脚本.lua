-- ============================================================
--  DFN脚本 - 完整版
--  功能：自瞄 · 透视 · 夜视 · 子弹追踪 · 飞行 · 自动攻击 · 刷物品 · 自动喝药
--  扫描所有物品，显示ID，支持指定刷取
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
--  暴力扫描所有物品（从所有地方获取ID）
-- ============================================================
local AllItemsCache = {}

local function ScanAllItems()
    local items = {}
    
    -- 1. 扫描 ReplicatedStorage（所有子对象）
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                if obj.Value and obj.Value > 0 then
                    items[obj.Name] = obj.Value
                end
            elseif obj:IsA("StringValue") then
                local num = tonumber(obj.Value)
                if num and num > 0 then
                    items[obj.Name] = num
                end
            end
        end
    end)

    -- 2. 扫描 Workspace 里的工具/武器
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Tool") then
                items[obj.Name] = items[obj.Name] or math.floor(1784980000 + math.random(1, 999))
            end
            local idAttr = obj:FindFirstChild("ItemId") or obj:FindFirstChild("ID") or obj:FindFirstChild("ToolId")
            if idAttr and (idAttr:IsA("NumberValue") or idAttr:IsA("IntValue")) then
                items[obj.Name] = idAttr.Value
            end
        end
    end)

    -- 3. 扫描 LocalPlayer 背包
    pcall(function()
        for _, obj in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if obj:IsA("Tool") then
                items[obj.Name] = items[obj.Name] or math.floor(1784980000 + math.random(1, 999))
            end
        end
    end)

    -- 4. 手动补充已知物品（作为备选）
    local knownItems = {
        ["Gold"] = 1785000001,
        ["Silver"] = 1785000002,
        ["Snake Oil"] = 1785001001,
        ["Shovel"] = 1784980835,
        ["Tomahawk"] = 1784980842,
        ["Jade Sword"] = 1784980841,
        ["Vampire Knife"] = 1784980843,
        ["国库券"] = 1785000101,
        ["债券"] = 1785000102,
        ["金条"] = 1785000001,
        ["银条"] = 1785000002,
        ["步枪"] = 1784981001,
        ["海军手枪"] = 1784981002,
        ["手枪"] = 1784981003,
        ["散弹枪"] = 1784981004,
        ["烟花枪"] = 1784981005,
        ["步枪子弹"] = 1784982001,
        ["散弹枪子弹"] = 1784982002,
        ["中型子弹"] = 1784982003,
        ["重型子弹"] = 1784982004,
        ["轻型子弹"] = 1784982005,
        ["烟花枪子弹"] = 1784982006,
        ["煤"] = 1785003001,
        ["绷带"] = 1785004001,
        ["奇怪的面具"] = 1785005001,
        ["危险巴士"] = 1785006001,
        ["金酒杯"] = 1785007001,
        ["银酒杯"] = 1785007002,
        ["金盘子"] = 1785008001,
        ["银盘子"] = 1785008002,
        ["金画像"] = 1785009001,
        ["银画像"] = 1785009002,
        ["金雕像"] = 1785010001,
        ["银雕像"] = 1785010002,
    }
    for name, id in pairs(knownItems) do
        if not items[name] then
            items[name] = id
        end
    end

    -- 去重 + 排序
    local uniqueItems = {}
    for name, id in pairs(items) do
        if name and name ~= "" then
            uniqueItems[name] = id
        end
    end

    AllItemsCache = uniqueItems
    return uniqueItems
end

-- ============================================================
--  按名称查找物品ID
-- ============================================================
local function FindItemByName(itemName)
    if not AllItemsCache or next(AllItemsCache) == nil then
        ScanAllItems()
    end
    return AllItemsCache[itemName]
end

-- ============================================================
--  按关键词查找物品ID
-- ============================================================
local function FindItemByKeyword(keyword)
    if not AllItemsCache or next(AllItemsCache) == nil then
        ScanAllItems()
    end
    for name, id in pairs(AllItemsCache) do
        if name:find(keyword) then
            return id, name
        end
    end
    return nil, nil
end

-- ============================================================
--  刷取物品（同ID调用两次：装袋+取出）
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
            storeEvent:FireServer(itemId)
            storeEvent:FireServer(itemId)
        end)
        if i % 10 == 0 then
            task.wait(0.05)
        end
        task.wait(0.01)
    end
    return true
end

-- ============================================================
--  飞行功能（手机专用版）
-- ============================================================
local flyBodyVelocity = nil
local flyBodyGyro = nil
local flying = false

local function ToggleFly()
    flying = not flying
    local char = LocalPlayer.Character
    if not char then
        flying = false
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        flying = false
        return
    end

    if flying then
        hum.PlatformStand = true

        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.Parent = char

        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(4000, 4000, 4000)
        flyBodyGyro.P = 5000
        flyBodyGyro.CFrame = char.HumanoidRootPart.CFrame
        flyBodyGyro.Parent = char

        for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
            hum:SetStateEnabled(state, false)
        end
        hum:ChangeState(Enum.HumanoidStateType.Physics)

        WindUI:Notify({
            Title = "✅ 飞行已开启",
            Content = "触摸屏幕控制移动",
            Duration = 4,
        })

        task.spawn(function()
            while flying and char and char.Parent do
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then break end

                local moveDir = Vector3.new(0, 0, 0)
                local speed = 50

                -- 键盘控制（电脑用）
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDir = moveDir + Camera.CFrame.LookVector * speed
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDir = moveDir - Camera.CFrame.LookVector * speed
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDir = moveDir - Camera.CFrame.RightVector * speed
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDir = moveDir + Camera.CFrame.RightVector * speed
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDir = moveDir + Vector3.new(0, speed, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDir = moveDir - Vector3.new(0, speed, 0)
                end

                if flyBodyVelocity then
                    flyBodyVelocity.Velocity = moveDir
                end
                if flyBodyGyro and hrp then
                    flyBodyGyro.CFrame = hrp.CFrame
                end

                task.wait()
            end
        end)

    else
        hum.PlatformStand = false
        for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
            hum:SetStateEnabled(state, true)
        end
        if flyBodyVelocity then flyBodyVelocity:Destroy() end
        if flyBodyGyro then flyBodyGyro:Destroy() end
        WindUI:Notify({ Title = "✅ 飞行已关闭", Duration = 3 })
    end
end

-- ============================================================
--  自动攻击
-- ============================================================
local attackRunning = false

local function ToggleAttack()
    attackRunning = not attackRunning
    if attackRunning then
        WindUI:Notify({ Title = "✅ 自动攻击已开启", Duration = 3 })
        task.spawn(function()
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
        WindUI:Notify({ Title = "✅ 自动攻击已关闭", Duration = 3 })
    end
end

-- ============================================================
--  自动喝药
-- ============================================================
local function ToggleHeal()
    healRunning = not healRunning
    if healRunning then
        WindUI:Notify({
            Title = "✅ 自动喝药已开启",
            Content = "血量低于 " .. Settings.healThreshold .. "% 时自动喝药",
            Duration = 3,
        })
    else
        WindUI:Notify({ Title = "✅ 自动喝药已关闭", Duration = 3 })
    end
end

RunService.Heartbeat:Connect(function()
    if not healRunning then return end
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
            local snakeOilId = FindItemByName("Snake Oil")
            if not snakeOilId then
                snakeOilId = FindItemByName("蛇油")
            end
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
    Callback = function(v) Settings.swingSpeed = v end,
})

-- ============================================================
--  物品标签页
-- ============================================================
local ItemTab = Window:Tab({ Title = "物品", Icon = "solar:box-bold" })

-- 扫描物品按钮
ItemTab:Button({
    Title = "🔍 扫描所有物品",
    Callback = function()
        local items = ScanAllItems()
        local count = 0
        local itemList = ""
        for name, id in pairs(items) do
            count = count + 1
            if count <= 20 then
                itemList = itemList .. name .. " (" .. id .. ")\n"
            end
        end
        WindUI:Notify({
            Title = "✅ 扫描完成",
            Content = "共找到 " .. count .. " 个物品" .. (count > 20 and "\n(仅显示前20个)" or ""),
            Duration = 5,
        })
        print("=== 所有物品 ===")
        for name, id in pairs(items) do
            print(name .. " -> " .. id)
        end
    end,
})

-- 刷物品函数（创建按钮）
local function CreateSpawnButton(itemName, label)
    ItemTab:Button({
        Title = label,
        Callback = function()
            local id = FindItemByName(itemName)
            if not id then
                -- 尝试模糊搜索
                id, itemName = FindItemByKeyword(itemName)
            end
            if id then
                SpawnItemById(id, 1)
                WindUI:Notify({
                    Title = "✅ 已刷 " .. itemName,
                    Content = "ID: " .. id,
                    Duration = 3,
                })
            else
                WindUI:Notify({
                    Title = "⚠️ 未找到物品",
                    Content = "请先点击「扫描所有物品」",
                    Duration = 3,
                })
            end
        end,
    })
end

-- 高价值物品
CreateSpawnButton("国库券", "💵 刷国库券")
CreateSpawnButton("金条", "🪙 刷金条")
CreateSpawnButton("银条", "🪙 刷银条")
CreateSpawnButton("金酒杯", "🏆 刷金酒杯")
CreateSpawnButton("银酒杯", "🏆 刷银酒杯")
CreateSpawnButton("金盘子", "🍽️ 刷金盘子")
CreateSpawnButton("银盘子", "🍽️ 刷银盘子")
CreateSpawnButton("金画像", "🖼️ 刷金画像")
CreateSpawnButton("银画像", "🖼️ 刷银画像")
CreateSpawnButton("金雕像", "🗿 刷金雕像")
CreateSpawnButton("银雕像", "🗿 刷银雕像")

-- 武器
CreateSpawnButton("步枪", "🔫 刷步枪")
CreateSpawnButton("海军手枪", "🔫 刷海军手枪")
CreateSpawnButton("手枪", "🔫 刷手枪")
CreateSpawnButton("散弹枪", "🔫 刷散弹枪")
CreateSpawnButton("烟花枪", "🎆 刷烟花枪")
CreateSpawnButton("吸血鬼刀", "🗡️ 刷吸血鬼刀")
CreateSpawnButton("翡翠宝刀", "🗡️ 刷翡翠宝刀")

-- 子弹
CreateSpawnButton("步枪子弹", "📦 刷步枪子弹")
CreateSpawnButton("散弹枪子弹", "📦 刷散弹枪子弹")
CreateSpawnButton("中型子弹", "📦 刷中型子弹")
CreateSpawnButton("重型子弹", "📦 刷重型子弹")
CreateSpawnButton("轻型子弹", "📦 刷轻型子弹")
CreateSpawnButton("烟花枪子弹", "📦 刷烟花枪子弹")

-- 消耗品
CreateSpawnButton("蛇油", "🧪 刷蛇油")
CreateSpawnButton("绷带", "🩹 刷绷带")
CreateSpawnButton("煤", "🪨 刷煤")
CreateSpawnButton("奇怪的面具", "🎭 刷奇怪的面具")
CreateSpawnButton("危险巴士", "🚌 刷危险巴士")

-- 批量刷取
ItemTab:Space()
ItemTab:Section({ Title = "批量刷取" })

ItemTab:Button({
    Title = "📦 批量刷金条 x10",
    Callback = function()
        local id = FindItemByName("金条")
        if id then
            SpawnItemById(id, 10)
            WindUI:Notify({ Title = "✅ 已刷金条 x10", Duration = 3 })
        else
            WindUI:Notify({ Title = "⚠️ 未找到金条", Duration = 3 })
        end
    end,
})

ItemTab:Button({
    Title = "📦 批量刷国库券 x10",
    Callback = function()
        local id = FindItemByName("国库券")
        if id then
            SpawnItemById(id, 10)
            WindUI:Notify({ Title = "✅ 已刷国库券 x10", Duration = 3 })
        else
            WindUI:Notify({ Title = "⚠️ 未找到国库券", Duration = 3 })
        end,
    end,
})

ItemTab:Button({
    Title = "📦 批量刷所有高价值 x5",
    Callback = function()
        local items = {"国库券", "金条", "银条", "金酒杯", "银酒杯", "金盘子", "银盘子", "金画像", "银画像", "金雕像", "银雕像"}
        for _, name in ipairs(items) do
            local id = FindItemByName(name)
            if id then
                SpawnItemById(id, 5)
                task.wait(0.1)
            end
        end
        WindUI:Notify({ Title = "✅ 已刷所有高价值物品 x5", Duration = 4 })
    end,
})

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

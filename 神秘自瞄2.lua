-- ============================================================
--  基于 WindUI 官方示例改造
--  功能：纯NPC自瞄 + 子弹追踪 + 实时透视 + 夜视
--  启动时弹窗提示"开启成功67"
-- ============================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

-- ============================================================
--  加载 WindUI
-- ============================================================
local cloneref = (cloneref or clonereference or function(instance) return instance end)
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local HttpService = cloneref(game:GetService("HttpService"))

local WindUI
do
	local ok, result = pcall(function()
		return require("./src/Init")
	end)
	if ok then
		WindUI = result
	else
		if cloneref(game:GetService("RunService")):IsStudio() then
			WindUI = require(cloneref(ReplicatedStorage:WaitForChild("WindUI"):WaitForChild("Init")))
		else
			WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
		end
	end
end

-- ============================================================
--  中文映射
-- ============================================================
local NameTranslate = {
	["Zombie"] = "僵尸",
	["Skeleton"] = "骷髅",
	["Bandit"] = "强盗",
	["Guard"] = "守卫",
	["Boss"] = "BOSS",
}
local function GetDisplayName(model)
	local eng = model.Name
	return NameTranslate[eng] or eng
end

-- ============================================================
--  设置
-- ============================================================
local Settings = {
	aimbot = false,
	aimPart = "Head",
	fov = 80,
	maxDist = 300,
	smoothness = 5,
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
}

local manualControl = false
local touchCount = 0

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
fovCircle.Color = Color3.fromRGB(255,255,255)
fovCircle.Filled = false
fovCircle.Visible = false

local aimLine = Drawing.new("Line")
aimLine.Color = Color3.fromRGB(255,50,50)
aimLine.Thickness = 2
aimLine.Visible = false

local targetInfo = Drawing.new("Text")
targetInfo.Size = 16
targetInfo.Color = Color3.fromRGB(255,255,255)
targetInfo.Center = true
targetInfo.Outline = true
targetInfo.OutlineColor = Color3.fromRGB(0,0,0)
targetInfo.Visible = false

-- ============================================================
--  自瞄（带锁定吸附）
-- ============================================================
local currentTarget = nil

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
		local score = -dist*0.3 - md*0.5 + part.AssemblyLinearVelocity.Magnitude*0.1
		if score > bestScore then
			bestScore = score
			best = { model = npc.model, part = part, position = part.Position, distance = dist, screenPos = sp, humanoid = npc.humanoid }
		end
	end
	return best
end

local function UpdateAimbot()
	if not Settings.aimbot then
		aimLine.Visible = false
		targetInfo.Visible = false
		currentTarget = nil
		return
	end

	if not currentTarget then
		currentTarget = GetBestNPCTarget()
	else
		local part = GetTargetPart(currentTarget.model)
		if not part then
			currentTarget = nil
			return
		end
		local dist = (part.Position - Camera.CFrame.Position).Magnitude
		if dist > Settings.maxDist then
			currentTarget = nil
			return
		end
		local sp, on = Camera:WorldToViewportPoint(part.Position)
		if not on then
			currentTarget = nil
			return
		end
		local center = Camera.ViewportSize / 2
		local md = (Vector2.new(sp.X, sp.Y) - center).Magnitude
		if md > Settings.fov * 1.3 then
			currentTarget = nil
			return
		end
		currentTarget.part = part
		currentTarget.position = part.Position
		currentTarget.screenPos = sp
		currentTarget.distance = dist
		currentTarget.humanoid = currentTarget.model:FindFirstChildOfClass("Humanoid")
	end

	if not currentTarget then
		aimLine.Visible = false
		targetInfo.Visible = false
		return
	end

	local targetPos = Settings.predict and PredictPosition(currentTarget.part) or currentTarget.part.Position
	local camPos = Camera.CFrame.Position
	local strength = 0.45
	local targetCF = CFrame.new(camPos, targetPos)
	Camera.CFrame = Camera.CFrame:Lerp(targetCF, strength)

	aimLine.From = Camera.ViewportSize / 2
	aimLine.To = Vector2.new(currentTarget.screenPos.X, currentTarget.screenPos.Y)
	aimLine.Visible = true

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
--  透视（血量实时同步）
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
		local color = Color3.fromRGB(255, 100, 100)
		if hpPercent > 0.6 then color = Color3.fromRGB(100, 255, 100)
		elseif hpPercent > 0.3 then color = Color3.fromRGB(255, 200, 50) end

		if not espDrawings[model] then
			local box = Drawing.new("Square")
			box.Thickness = 1
			box.Filled = false
			box.Visible = false
			local nameTxt = Drawing.new("Text")
			nameTxt.Size = 14
			nameTxt.Center = true
			nameTxt.Outline = true
			nameTxt.OutlineColor = Color3.fromRGB(0,0,0)
			nameTxt.Visible = false
			local distTxt = Drawing.new("Text")
			distTxt.Size = 12
			distTxt.Center = true
			distTxt.Outline = true
			distTxt.OutlineColor = Color3.fromRGB(0,0,0)
			distTxt.Visible = false
			local hpBar = Drawing.new("Line")
			hpBar.Thickness = 3
			hpBar.Color = Color3.fromRGB(0,255,0)
			hpBar.Visible = false
			espDrawings[model] = { box = box, name = nameTxt, dist = distTxt, hpBar = hpBar, highlight = nil }
		end

		local data = espDrawings[model]
		local scale = 200 / math.max(dist, 1)
		local w, h = 2 * scale, 3 * scale
		local top, left = sp.Y - h/2, sp.X - w/2

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
			data.name.Color = Color3.fromRGB(255,255,255)
		end

		if Settings.espDistance then
			data.dist.Visible = true
			data.dist.Text = math.floor(dist) .. "m"
			data.dist.Position = Vector2.new(sp.X, top + h + 12)
		end

		local barWidth = w
		local barY = top + h + 4
		local barLeft = sp.X - barWidth/2
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
		d.box:Remove(); d.name:Remove(); d.dist:Remove(); d.hpBar:Remove()
		espDrawings[desc] = nil
	end
end)

-- ============================================================
--  夜视（可开关）
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
		Lighting.Ambient = Color3.new(1,1,1)
		Lighting.Brightness = 3
		Lighting.ClockTime = 12
		Lighting.OutdoorAmbient = Color3.new(1,1,1)
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
--  ════════════════  WindUI 菜单  ════════════════
--  基于官方示例改造，保留全部界面样式
-- ============================================================

-- 窗口
local Window = WindUI:CreateWindow({
	Title = "⚡ 纯NPC辅助",
	Folder = "NPCAssist",
	Icon = "solar:crosshair-bold-duotone",
	NewElements = true,
	HideSearchBar = false,
	OpenButton = {
		Title = "☰ 打开菜单",
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
		Scale = 0.5,
	},
	Topbar = {
		Height = 44,
		ButtonsType = "Mac",
	},
})

-- 版本标签
Window:Tag({
	Title = "v1.0",
	Icon = "github",
	Color = Color3.fromHex("#1c1c1c"),
	Border = true,
})

-- ============================================================
--  自瞄标签页
-- ============================================================
local AimbotTab = Window:Tab({
	Title = "自瞄",
	Icon = "solar:target-bold",
	IconColor = Color3.fromHex("#257AF7"),
	IconShape = "Square",
	Border = true,
})

AimbotTab:Toggle({
	Title = "NPC自瞄",
	Value = false,
	Callback = function(v) Settings.aimbot = v end,
})

AimbotTab:Toggle({
	Title = "穿墙检测",
	Value = false,
	Callback = function(v) Settings.wallCheck = v end,
})

AimbotTab:Toggle({
	Title = "预判",
	Value = false,
	Callback = function(v) Settings.predict = v end,
})

AimbotTab:Toggle({
	Title = "自动开火",
	Value = false,
	Callback = function(v) Settings.autoFire = v end,
})

AimbotTab:Toggle({
	Title = "显示FOV圈",
	Value = false,
	Callback = function(v) Settings.showFOV = v end,
})

AimbotTab:Space()

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

AimbotTab:Slider({
	Title = "平滑度",
	Step = 1,
	Value = { Min = 1, Max = 20, Default = 5 },
	Callback = function(v) Settings.smoothness = v end,
})

-- ============================================================
--  视觉标签页
-- ============================================================
local VisualTab = Window:Tab({
	Title = "视觉",
	Icon = "solar:eye-bold",
	IconColor = Color3.fromHex("#10C550"),
	IconShape = "Square",
	Border = true,
})

VisualTab:Toggle({
	Title = "🌙 夜视",
	Value = false,
	Callback = function(v) Settings.nightVision = v end,
})

VisualTab:Toggle({
	Title = "NPC透视",
	Value = false,
	Callback = function(v) Settings.esp = v end,
})

VisualTab:Toggle({
	Title = "NPC高亮",
	Value = false,
	Callback = function(v) Settings.npcHighlight = v end,
})

VisualTab:Toggle({
	Title = "显示名字+血量",
	Value = true,
	Callback = function(v) Settings.espName = v end,
})

VisualTab:Toggle({
	Title = "显示距离",
	Value = true,
	Callback = function(v) Settings.espDistance = v end,
})

-- ============================================================
--  武器标签页
-- ============================================================
local WeaponTab = Window:Tab({
	Title = "武器",
	Icon = "solar:gun-bold",
	IconColor = Color3.fromHex("#ECA201"),
	IconShape = "Square",
	Border = true,
})

WeaponTab:Toggle({
	Title = "子弹追踪",
	Value = false,
	Callback = function(v) Settings.bulletTrack = v end,
})

WeaponTab:Slider({
	Title = "子弹力度",
	Step = 1,
	Value = { Min = 50, Max = 300, Default = 150 },
	Callback = function(v) Settings.bulletSpeed = v end,
})

-- ============================================================
--  触摸/鼠标视角控制
-- ============================================================
local function updateManualControl() manualControl = (touchCount > 0) end

UserInputService.TouchStarted:Connect(function(touch)
	touchCount += 1
	updateManualControl()
end)

UserInputService.TouchEnded:Connect(function()
	if touchCount > 0 then touchCount -= 1; updateManualControl() end
end)

local rmbDown = false
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rmbDown = true
		touchCount += 1
		updateManualControl()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if rmbDown then
			rmbDown = false
			if touchCount > 0 then touchCount -= 1; updateManualControl() end
		end
	end
end)

-- ============================================================
--  🎉 开启成功弹窗
-- ============================================================
WindUI:Notify({
	Title = "✅ 开启成功",
	Content = "纯NPC辅助已加载\n点击⚙打开菜单",
	Icon = "solar:check-circle-bold",
	Duration = 5,
})

print("✅ 纯NPC辅助已启动 | UI: WindUI")

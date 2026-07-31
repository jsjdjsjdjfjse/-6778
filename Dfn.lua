local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local storeEvent, swingEvent, useEvent, weldEvent, stopDragEvent
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
                        storeEvent = re:FindFirstChild("Store")
                        swingEvent = re:FindFirstChild("SwingMelee")
                        useEvent = re:FindFirstChild("Use")
                        weldEvent = re:FindFirstChild("Weld")
                        stopDragEvent = re:FindFirstChild("StopDrag")
                    end
                end
            end
        end
    end
end)

local Settings = {
    aimbot = false, aimPart = "Head", fov = 80, maxDist = 300,
    wallCheck = false, predict = false, autoFire = false,
    bulletTrack = false, bulletSpeed = 150,
    esp = false, espBox = true, espName = true, espDistance = true,
    npcHighlight = false, showFOV = false, nightVision = false, rayLine = false,
    flyMode = false, attackMode = false,
    healMode = false, useBandage = false, useSnakeOil = false,
    swingSpeed = 0.02, healThreshold = 50, healSpeed = 2,
}

local NameTranslate = {["Zombie"]="僵尸",["Skeleton"]="骷髅",["Bandit"]="强盗",["Guard"]="守卫",["Boss"]="BOSS",["NewspaperBoy"]="报童"}
local function GetDisplayName(m) local e=m.Name return NameTranslate[e] or e end

local weaponConfigs = {
    {get=function()return LocalPlayer.Backpack:FindFirstChild("Shovel")end,id=1784980835.0023,dir=Vector3.new(-0.98141527175903,-0.17157469689846,-0.085943520069122)},
    {get=function()local c=LocalPlayer.Character return c and c:FindFirstChild("Shovel")end,id=1784971142.9326,dir=Vector3.new(0.23211443424225,-0.49000316858292,0.84024983644485)},
    {get=function()local c=LocalPlayer.Character return c and c:FindFirstChild("Vampire Knife")end,id=1784980843.3721,dir=Vector3.new(0.88972532749176,0.1092592254281,-0.44322821497917)},
    {get=function()return LocalPlayer.Backpack:FindFirstChild("Tomahawk")end,id=1784980842.62,dir=Vector3.new(0.88228863477707,0.12052091211081,-0.45501813292503)},
    {get=function()return LocalPlayer.Backpack:FindFirstChild("Jade Sword")end,id=1784980841.9156,dir=Vector3.new(0.88118195533752,0.1211147531867,-0.45700073242188)}
}

local function GetNPCList()
    local npcs={}
    for _,o in ipairs(Workspace:GetDescendants())do if o:IsA("Humanoid")and o.Health>0 then local m=o.Parent if m and m:IsA("Model")and not Players:GetPlayerFromCharacter(m)then table.insert(npcs,{model=m,humanoid=o})end end end
    return npcs
end

local function GetTargetPart(m) if not m then return nil end local n=Settings.aimPart=="Head"and"Head"or"UpperTorso"return m:FindFirstChild(n)or m:FindFirstChild("HumanoidRootPart")end

local function CheckWall(p)if not Settings.wallCheck then return true end local o=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")if not o then return false end local params=RaycastParams.new()params.FilterType=Enum.RaycastFilterType.Blacklist params.FilterDescendantsInstances={LocalPlayer.Character}local r=Workspace:Raycast(o.Position,(p.Position-o.Position),params)if not r then return true end return r.Instance:IsDescendantOf(p.Parent)end

local function PredictPosition(p)return p.Position+p.AssemblyLinearVelocity*0.1 end

local fovCircle=Drawing.new("Circle")fovCircle.Thickness=1.5 fovCircle.Color=Color3.fromRGB(255,255,255)fovCircle.Filled=false fovCircle.Visible=false
local targetInfo=Drawing.new("Text")targetInfo.Size=16 targetInfo.Color=Color3.fromRGB(255,255,255)targetInfo.Center=true targetInfo.Outline=true targetInfo.OutlineColor=Color3.fromRGB(0,0,0)targetInfo.Visible=false
local rayLines={}
local currentTarget=nil local aimLockTime=0

local function GetBestNPCTarget()
    if not Settings.aimbot then return nil end
    local center=Camera.ViewportSize/2 local bestScore=-math.huge local best=nil
    for _,npc in ipairs(GetNPCList())do
        local part=GetTargetPart(npc.model)if not part then continue end
        local dist=(part.Position-Camera.CFrame.Position).Magnitude if dist>Settings.maxDist then continue end
        local sp,on=Camera:WorldToViewportPoint(part.Position)if not on then continue end
        local md=(Vector2.new(sp.X,sp.Y)-center).Magnitude if md>Settings.fov then continue end
        if not CheckWall(part)then continue end
        local score=-dist*0.3-md*0.5
        if score>bestScore then bestScore=score best={model=npc.model,part=part,position=part.Position,distance=dist,screenPos=Vector2.new(sp.X,sp.Y),humanoid=npc.humanoid}end
    end
    return best
end

local function UpdateAimbot()
    if not Settings.aimbot then targetInfo.Visible=false currentTarget=nil return end
    local now=tick()if not currentTarget or(now-aimLockTime)>0.1 then currentTarget=GetBestNPCTarget()aimLockTime=now end
    if not currentTarget then targetInfo.Visible=false return end
    if not currentTarget.humanoid or currentTarget.humanoid.Health<=0 then currentTarget=nil targetInfo.Visible=false return end
    local part=GetTargetPart(currentTarget.model)if not part then currentTarget=nil return end
    currentTarget.part=part currentTarget.position=part.Position
    local targetPos=Settings.predict and PredictPosition(currentTarget.part)or currentTarget.part.Position
    local camPos=Camera.CFrame.Position Camera.CFrame=CFrame.new(camPos,targetPos)
    local sp,on=Camera:WorldToViewportPoint(targetPos)if on then currentTarget.screenPos=Vector2.new(sp.X,sp.Y)end
    local hp=currentTarget.humanoid and math.floor(currentTarget.humanoid.Health)or"?"
    targetInfo.Text=GetDisplayName(currentTarget.model).." ["..hp.."HP]  "..math.floor(currentTarget.distance).."m"
    targetInfo.Position=Vector2.new(Camera.ViewportSize.X/2,40)targetInfo.Visible=true
    if Settings.autoFire then local tool=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")if tool then pcall(function()tool:Activate()end)end end
end

local function TrackBullets()
    if not Settings.bulletTrack then return end
    local bestNPC,bestDist=nil,math.huge
    for _,npc in ipairs(GetNPCList())do local part=GetTargetPart(npc.model)if part then local d=(part.Position-Camera.CFrame.Position).Magnitude if d<bestDist then bestDist=d bestNPC=npc end end end
    if not bestNPC then return end
    local targetPart=GetTargetPart(bestNPC.model)if not targetPart then return end
    local targetPos=Settings.predict and PredictPosition(targetPart)or targetPart.Position
    for _,obj in ipairs(Workspace:GetDescendants())do if obj:IsA("BasePart")then local vel=obj.AssemblyLinearVelocity if vel.Magnitude>10 and vel.Magnitude<5000 then local name=obj.Name local isBullet=name:find("步枪")or name:find("中型")or name:find("烟花")or name:find("轻型")or name:find("重型")or name:find("子弹")or name:lower():find("bullet")or name:lower():find("projectile")if isBullet then local dir=(targetPos-obj.Position).Unit obj.AssemblyLinearVelocity=dir*Settings.bulletSpeed pcall(function()obj.CFrame=CFrame.new(obj.Position,targetPos)end)end end end end
end

local espDrawings={}
local function UpdateESP()
    local espOn=Settings.esp
    for m,d in pairs(espDrawings)do d.box.Visible=false d.name.Visible=false d.dist.Visible=false d.hpBar.Visible=false if d.highlight then d.highlight.Enabled=false end end
    for _,l in ipairs(rayLines)do l.Visible=false end rayLines={}
    if not espOn then return end
    local camPos=Camera.CFrame.Position local currentModels={} local center=Camera.ViewportSize/2
    for _,npc in ipairs(GetNPCList())do
        local model=npc.model local humanoid=npc.humanoid currentModels[model]=true local hp=humanoid.Health if hp<=0 then continue end
        local hrp=model:FindFirstChild("HumanoidRootPart")if not hrp then continue end
        local dist=(hrp.Position-camPos).Magnitude if dist>400 then continue end
        local sp,on=Camera:WorldToViewportPoint(hrp.Position)if not on then continue end
        local maxHp=humanoid.MaxHealth local hpPercent=maxHp>0 and math.clamp(hp/maxHp,0,1)or 1 local color=Color3.fromRGB(255,80,80)
        if not espDrawings[model]then
            local box=Drawing.new("Square")box.Thickness=1 box.Filled=false box.Visible=false
            local nameTxt=Drawing.new("Text")nameTxt.Size=14 nameTxt.Center=true nameTxt.Outline=true nameTxt.OutlineColor=Color3.fromRGB(0,0,0)nameTxt.Visible=false
            local distTxt=Drawing.new("Text")distTxt.Size=12 distTxt.Center=true distTxt.Outline=true distTxt.OutlineColor=Color3.fromRGB(0,0,0)distTxt.Visible=false
            local hpBar=Drawing.new("Line")hpBar.Thickness=3 hpBar.Color=Color3.fromRGB(0,255,0)hpBar.Visible=false
            espDrawings[model]={box=box,name=nameTxt,dist=distTxt,hpBar=hpBar,highlight=nil}
        end
        local data=espDrawings[model]
        local scale=200/math.max(dist,1)local w,h=2*scale,3*scale local top,left=sp.Y-h/2,sp.X-w/2
        if Settings.espBox then data.box.Visible=true data.box.Position=Vector2.new(left,top)data.box.Size=Vector2.new(w,h)data.box.Color=color end
        if Settings.espName then data.name.Visible=true data.name.Text=GetDisplayName(model).." ["..math.floor(hp).."HP]"data.name.Position=Vector2.new(sp.X,top-14)data.name.Color=Color3.fromRGB(255,255,255)end
        if Settings.espDistance then data.dist.Visible=true data.dist.Text=math.floor(dist).."m"data.dist.Position=Vector2.new(sp.X,top+h+12)end
        local barWidth=w local barY=top+h+4 local barLeft=sp.X-barWidth/2 local barRight=barLeft+barWidth*hpPercent data.hpBar.Visible=true data.hpBar.From=Vector2.new(barLeft,barY)data.hpBar.To=Vector2.new(barRight,barY)data.hpBar.Color=color
        if Settings.npcHighlight then if not data.highlight then local hl=Instance.new("Highlight")hl.Adornee=model hl.FillTransparency=0.6 hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop hl.Parent=model data.highlight=hl end data.highlight.Enabled=true data.highlight.OutlineColor=color data.highlight.FillColor=color end
        if Settings.rayLine then local line=Drawing.new("Line")line.Thickness=1.5 line.Color=Color3.fromRGB(255,0,0)line.From=center line.To=Vector2.new(sp.X,sp.Y)line.Visible=true table.insert(rayLines,line)end
    end
    for m,d in pairs(espDrawings)do if not currentModels[m]then if d.highlight then d.highlight:Destroy()end d.box:Remove()d.name:Remove()d.dist:Remove()d.hpBar:Remove()espDrawings[m]=nil end end
end

Workspace.DescendantRemoving:Connect(function(desc)if desc:IsA("Model")and espDrawings[desc]then local d=espDrawings[desc]if d.highlight then d.highlight:Destroy()end d.box:Remove()d.name:Remove()d.dist:Remove()d.hpBar:Remove()espDrawings[desc]=nil end end)

local origAmb,origBright,origClock,origOutdoor,origDiffuse,origSpecular
local function SaveLighting()origAmb=Lighting.Ambient origBright=Lighting.Brightness origClock=Lighting.ClockTime origOutdoor=Lighting.OutdoorAmbient origDiffuse=Lighting.EnvironmentDiffuseScale origSpecular=Lighting.EnvironmentSpecularScale end
local function ForceNightVision()if Settings.nightVision then Lighting.Ambient=Color3.new(1,1,1)Lighting.Brightness=3 Lighting.ClockTime=12 Lighting.OutdoorAmbient=Color3.new(1,1,1)Lighting.EnvironmentDiffuseScale=1 Lighting.EnvironmentSpecularScale=1 else if origAmb then Lighting.Ambient=origAmb Lighting.Brightness=origBright Lighting.ClockTime=origClock Lighting.OutdoorAmbient=origOutdoor Lighting.EnvironmentDiffuseScale=origDiffuse Lighting.EnvironmentSpecularScale=origSpecular end end end
SaveLighting()

RunService.RenderStepped:Connect(function()fovCircle.Position=Camera.ViewportSize/2 fovCircle.Radius=Settings.fov fovCircle.Visible=Settings.showFOV ForceNightVision()UpdateAimbot()TrackBullets()UpdateESP()end)

local flyEnabled=false local flyBV=nil
local function ToggleFly()
    flyEnabled=not flyEnabled local char=LocalPlayer.Character if not char then return end local hum=char:FindFirstChildOfClass("Humanoid")if not hum then return end
    if flyEnabled then
        hum.PlatformStand=true for _,s in ipairs(Enum.HumanoidStateType:GetEnumItems())do hum:SetStateEnabled(s,false)end hum:SetStateEnabled(Enum.HumanoidStateType.Climbing,true)hum:SetStateEnabled(Enum.HumanoidStateType.Flying,true)hum:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics,true)hum:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics,true)hum:ChangeState(Enum.HumanoidStateType.Flying)char.Animate.Disabled=true
        flyBV=Instance.new("BodyVelocity")flyBV.MaxForce=Vector3.new(1e9,1e9,1e9)flyBV.Velocity=Vector3.new(0,0,0)flyBV.Parent=char
        WindUI:Notify({Title="✅ 飞行已开启",Content="WASD移动，Space上升，Shift下降",Duration=3})
        task.spawn(function()while flyEnabled and char and char.Parent do local hrp=char:FindFirstChild("HumanoidRootPart")if not hrp then break end local move=Vector3.new(0,0,0)local speed=50 if UserInputService:IsKeyDown(Enum.KeyCode.W)then move=move+Camera.CFrame.LookVector*speed end if UserInputService:IsKeyDown(Enum.KeyCode.S)then move=move-Camera.CFrame.LookVector*speed end if UserInputService:IsKeyDown(Enum.KeyCode.A)then move=move-Camera.CFrame.RightVector*speed end if UserInputService:IsKeyDown(Enum.KeyCode.D)then move=move+Camera.CFrame.RightVector*speed end if UserInputService:IsKeyDown(Enum.KeyCode.Space)then move=move+Vector3.new(0,speed,0)end if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)then move=move-Vector3.new(0,speed,0)end flyBV.Velocity=move task.wait()end end)
    else
        hum.PlatformStand=false for _,s in ipairs(Enum.HumanoidStateType:GetEnumItems())do hum:SetStateEnabled(s,true)end char.Animate.Disabled=false hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)if flyBV then flyBV:Destroy()flyBV=nil end
        WindUI:Notify({Title="✅ 飞行已关闭",Duration=2})
    end
end

local attackRunning=false local attackCoroutine=nil
local function ToggleAttack()
    attackRunning=not attackRunning
    if attackRunning then
        WindUI:Notify({Title="✅ 自动攻击已开启",Content="攻速: "..Settings.swingSpeed,Duration=3})
        attackCoroutine=task.spawn(function()while attackRunning do for _,w in ipairs(weaponConfigs)do local obj=w.get()if obj and swingEvent then pcall(function()swingEvent:FireServer(obj,w.id,w.dir)end)end end task.wait(Settings.swingSpeed)end end)
    else if attackCoroutine then task.cancel(attackCoroutine)attackCoroutine=nil end WindUI:Notify({Title="✅ 自动攻击已关闭",Duration=2})end
end

local function FindItemId(n)
    for _,o in ipairs(Workspace:GetDescendants())do if o:IsA("NumberValue")or o:IsA("IntValue")then if o.Name:find(n)then return o.Value end end end
    for _,o in ipairs(ReplicatedStorage:GetDescendants())do if o:IsA("NumberValue")or o:IsA("IntValue")then if o.Name:find(n)then return o.Value end end end
    return nil
end

local healRunning=false local lastHealTime=0
local function ToggleHeal()
    healRunning=not healRunning
    if healRunning then WindUI:Notify({Title="✅ 自动治疗已开启",Content="阈值: "..Settings.healThreshold.."%",Duration=3})else WindUI:Notify({Title="✅ 自动治疗已关闭",Duration=2})end
end

RunService.Heartbeat:Connect(function()
    if not healRunning or not useEvent then return end
    local char=LocalPlayer.Character if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid")if not hum then return end
    local hp=hum.Health local maxHp=hum.MaxHealth if maxHp<=0 then return end
    if(hp/maxHp)*100<Settings.healThreshold and hp>0 then
        local now=os.clock()if now-lastHealTime>=Settings.healSpeed then
            local used=false
            if Settings.useSnakeOil then local id=FindItemId("Snake Oil")or FindItemId("蛇油")if id then pcall(function()useEvent:FireServer(id)lastHealTime=now used=true end)end end
            if not used and Settings.useBandage then local id=FindItemId("Bandage")or FindItemId("绷带")if id then pcall(function()useEvent:FireServer(id)lastHealTime=now used=true end)end end
        end
    end
end)

local capturedStopDragId=nil
if stopDragEvent then
    local orig=stopDragEvent.FireServer
    stopDragEvent.FireServer=function(self,...)
        local args={...}if #args>=1 then local id=args[1]if type(id)=="number"and id>0 then capturedStopDragId=id print("🎯 StopDrag ID:"..id)end end
        return orig(self,...)
    end
end

local function ExecuteWeld(id1,id2)if not weldEvent then WindUI:Notify({Title="❌ Weld事件不存在",Duration=2})return false end if not id1 or not id2 then WindUI:Notify({Title="⚠️ 参数不完整",Duration=2})return false end pcall(function()weldEvent:FireServer(id1,id2)WindUI:Notify({Title="✅ 焊接成功",Content=id1.." → "..id2,Duration=2})end)return true end

local function GetNameToIdMap()
    local map={}
    pcall(function()for _,o in ipairs(Workspace:GetDescendants())do if o:IsA("NumberValue")or o:IsA("IntValue")then local n=o.Name local id=o.Value if type(id)=="number"and id>=100 and id<=10000 then map[n]=id end end end end)
    pcall(function()for _,o in ipairs(ReplicatedStorage:GetDescendants())do if o:IsA("NumberValue")or o:IsA("IntValue")then local n=o.Name local id=o.Value if type(id)=="number"and id>=100 and id<=10000 then map[n]=id end end end end)
    return map
end

local function SpawnRandom()
    if not storeEvent then WindUI:Notify({Title="❌ Store事件不存在",Duration=3})return end
    for id=0,5000 do pcall(function()storeEvent:FireServer(id)storeEvent:FireServer(id)end)task.wait(0.01)end
    WindUI:Notify({Title="✅ 随机刷完成",Content="已刷 0~5000",Duration=3})
end

local selectedItem=nil
local ItemKeywords={["金条"]="Gold",["银条"]="Silver",["煤"]="Coal",["债券"]="Bond",["金酒杯"]="Cup",["银酒杯"]="Cup",["金盘子"]="Plate",["银盘子"]="Plate",["金画像"]="Painting",["银画像"]="Painting",["金雕像"]="Statue",["银雕像"]="Statue",["步枪"]="Rifle",["手枪"]="Pistol",["海军手枪"]="Navy",["散弹枪"]="Shotgun",["烟花枪"]="Firework",["吸血鬼刀"]="Vampire",["翡翠宝刀"]="Jade",["步枪子弹"]="Rifle",["散弹枪子弹"]="Shotgun",["中型子弹"]="Medium",["重型子弹"]="Heavy",["轻型子弹"]="Light",["烟花枪子弹"]="Firework",["蛇油"]="Snake Oil",["绷带"]="Bandage",["奇怪的面具"]="Mask",["危险巴士"]="Bus"}

local function SpawnByName()
    if not storeEvent then WindUI:Notify({Title="❌ Store事件不存在",Duration=3})return end
    if not selectedItem then WindUI:Notify({Title="⚠️ 请先选择物品",Duration=2})return end
    local kw=ItemKeywords[selectedItem]if not kw then WindUI:Notify({Title="⚠️ 未找到关键词",Content=selectedItem,Duration=2})return end
    local map=GetNameToIdMap()local tid=nil local fn=nil for n,id in pairs(map)do if n:find(kw)then tid=id fn=n break end end
    if not tid then WindUI:Notify({Title="❌ 未找到匹配物品",Content="关键词: "..kw,Duration=3})return end
    pcall(function()storeEvent:FireServer(tid)storeEvent:FireServer(tid)end)
    WindUI:Notify({Title="✅ 已刷 "..fn,Content="ID: "..tid,Duration=3})
end

local function ScanBackpack()
    local items={}
    for _,t in ipairs(LocalPlayer.Backpack:GetChildren())do if t:IsA("Tool")then local id=nil for _,c in ipairs(t:GetDescendants())do if c:IsA("NumberValue")or c:IsA("IntValue")then local v=c.Value if type(v)=="number"and v>0 then id=v break end end end table.insert(items,{name=t.Name,id=id or"无ID"})end end
    return items
end

local Window=WindUI:CreateWindow({Title="DFN脚本",Folder="DFN",Icon="solar:crosshair-bold-duotone",NewElements=true,HideSearchBar=false,OpenButton={Title="DFN脚本",Enabled=true,Draggable=true,OnlyMobile=true,Scale=0.7},Topbar={Height=44,ButtonsType="Mac"}})
Window:Tag({Title="v3.0",Icon="smartphone",Color=Color3.fromHex("#1c1c1c"),Border=true})

local AimbotTab=Window:Tab({Title="自瞄",Icon="solar:target-bold"})
AimbotTab:Toggle({Title="NPC自瞄",Value=false,Callback=function(v)Settings.aimbot=v WindUI:Notify({Title=v and"✅ 自瞄已开启"or"✅ 自瞄已关闭",Duration=2})end})
AimbotTab:Dropdown({Title="瞄准部位",Values={"头部","身体"},Value="头部",Callback=function(o)Settings.aimPart=o=="头部"and"Head"or"UpperTorso"end})
AimbotTab:Toggle({Title="穿墙检测",Value=false,Callback=function(v)Settings.wallCheck=v WindUI:Notify({Title=v and"✅ 穿墙检测已开启"or"✅ 穿墙检测已关闭",Duration=2})end})
AimbotTab:Toggle({Title="预判",Value=false,Callback=function(v)Settings.predict=v WindUI:Notify({Title=v and"✅ 预判已开启"or"✅ 预判已关闭",Duration=2})end})
AimbotTab:Toggle({Title="自动开火",Value=false,Callback=function(v)Settings.autoFire=v WindUI:Notify({Title=v and"✅ 自动开火已开启"or"✅ 自动开火已关闭",Duration=2})end})
AimbotTab:Toggle({Title="显示FOV圈",Value=false,Callback=function(v)Settings.showFOV=v WindUI:Notify({Title=v and"✅ FOV圈已显示"or"✅ FOV圈已隐藏",Duration=2})end})
AimbotTab:Slider({Title="FOV大小",Step=1,Value={Min=20,Max=300,Default=80},Callback=function(v)Settings.fov=v end})
AimbotTab:Slider({Title="最大距离",Step=1,Value={Min=50,Max=800,Default=300},Callback=function(v)Settings.maxDist=v end})

local VisualTab=Window:Tab({Title="视觉",Icon="solar:eye-bold"})
VisualTab:Toggle({Title="夜视",Value=false,Callback=function(v)Settings.nightVision=v WindUI:Notify({Title=v and"✅ 夜视已开启"or"✅ 夜视已关闭",Duration=2})end})
VisualTab:Toggle({Title="NPC透视",Value=false,Callback=function(v)Settings.esp=v WindUI:Notify({Title=v and"✅ 透视已开启"or"✅ 透视已关闭",Duration=2})end})
VisualTab:Toggle({Title="NPC高亮",Value=false,Callback=function(v)Settings.npcHighlight=v WindUI:Notify({Title=v and"✅ 高亮已开启"or"✅ 高亮已关闭",Duration=2})end})
VisualTab:Toggle({Title="射线透视",Value=false,Callback=function(v)Settings.rayLine=v WindUI:Notify({Title=v and"✅ 射线已开启"or"✅ 射线已关闭",Duration=2})end})
VisualTab:Toggle({Title="显示名字+血量",Value=true,Callback=function(v)Settings.espName=v WindUI:Notify({Title=v and"✅ 名字+血量已显示"or"✅ 名字+血量已隐藏",Duration=2})end})
VisualTab:Toggle({Title="显示距离",Value=true,Callback=function(v)Settings.espDistance=v WindUI:Notify({Title=v and"✅ 距离已显示"or"✅ 距离已隐藏",Duration=2})end})

local WeaponTab=Window:Tab({Title="武器",Icon="solar:gun-bold"})
WeaponTab:Toggle({Title="子弹追踪",Value=false,Callback=function(v)Settings.bulletTrack=v WindUI:Notify({Title=v and"✅ 子弹追踪已开启"or"✅ 子弹追踪已关闭",Duration=2})end})
WeaponTab:Slider({Title="子弹力度",Step=1,Value={Min=50,Max=300,Default=150},Callback=function(v)Settings.bulletSpeed=v end})
WeaponTab:Toggle({Title="自动攻击",Value=false,Callback=function(v)ToggleAttack()end})
WeaponTab:Slider({Title="攻击速度",Step=0.001,Value={Min=0.001,Max=0.1,Default=0.02},Callback=function(v)Settings.swingSpeed=v if attackRunning then WindUI:Notify({Title="✅ 攻速已更新",Content="当前: "..v,Duration=2})end end})

local ItemTab=Window:Tab({Title="物品",Icon="solar:box-bold"})
ItemTab:Button({Title="🎒 扫描背包物品",Callback=function()local items=ScanBackpack()if #items==0 then WindUI:Notify({Title="📭 背包为空",Duration=2})return end local msg=""for _,it in ipairs(items)do msg=msg..it.name.." (ID:"..it.id..")\n"if #msg>100 then msg=msg.."... 共 "..#items.." 件"break end end WindUI:Notify({Title="🎒 背包物品 (共 "..#items.." 件)",Content=msg,Duration=5})print("========== 背包物品 ==========")for _,it in ipairs(items)do print(it.name.." -> "..it.id)end end})
ItemTab:Button({Title="🎲 随机刷（0~5000）",Callback=function()SpawnRandom()end})
ItemTab:Dropdown({Title="选择要刷的物品（中文）",Values={"金条","银条","煤","债券","金酒杯","银酒杯","金盘子","银盘子","金画像","银画像","金雕像","银雕像","步枪","手枪","海军手枪","散弹枪","烟花枪","吸血鬼刀","翡翠宝刀","步枪子弹","散弹枪子弹","中型子弹","重型子弹","轻型子弹","烟花枪子弹","蛇油","绷带","奇怪的面具","危险巴士"},Value=nil,Callback=function(v)selectedItem=v WindUI:Notify({Title="✅ 已选择",Content="物品: "..(selectedItem or"无"),Duration=2})end})
ItemTab:Button({Title="🎯 刷选中物品",Callback=function()SpawnByName()end})

local SettingsTab=Window:Tab({Title="设置",Icon="solar:settings-bold"})
SettingsTab:Toggle({Title="飞行模式",Value=false,Callback=function(v)ToggleFly()end})
SettingsTab:Toggle({Title="自动治疗",Value=false,Callback=function(v)Settings.healMode=v ToggleHeal()end})
SettingsTab:Slider({Title="治疗阈值 (%)",Step=1,Value={Min=10,Max=90,Default=50},Callback=function(v)Settings.healThreshold=v if Settings.healMode then WindUI:Notify({Title="✅ 阈值已更新",Content="低于 "..v.."% 自动治疗",Duration=3})end end})
SettingsTab:Slider({Title="治疗间隔 (秒)",Step=0.5,Value={Min=0.5,Max=5,Default=2},Callback=function(v)Settings.healSpeed=v if Settings.healMode then WindUI:Notify({Title="✅ 间隔已更新",Content="每 "..v.." 秒治疗一次",Duration=3})end end})
SettingsTab:Space()
SettingsTab:Toggle({Title="🩹 使用绷带",Value=false,Callback=function(v)Settings.useBandage=v WindUI:Notify({Title=v and"✅ 绷带已启用"or"❌ 绷带已禁用",Duration=2})end})
SettingsTab:Toggle({Title="🧪 使用蛇油",Value=false,Callback=function(v)Settings.useSnakeOil=v WindUI:Notify({Title=v and"✅ 蛇油已启用"or"❌ 蛇油已禁用",Duration=2})end})
SettingsTab:Space()
SettingsTab:Section({Title="🔧 焊接功能",TextSize=14})
SettingsTab:Button({Title="📌 必须先手动焊接一次才能使用自动焊接",Callback=function()WindUI:Notify({Title="⚠️ 请先拖拽物品",Content="拖拽后自动捕获StopDrag ID",Duration=3})end})
SettingsTab:Toggle({Title="🔄 自动焊接",Value=false,Callback=function(v)if v then WindUI:Notify({Title="🔄 自动焊接已开启",Content="每3秒尝试焊接",Duration=2})task.spawn(function()while v do if capturedStopDragId then ExecuteWeld(3109,capturedStopDragId)end task.wait(3)end end)else WindUI:Notify({Title="❌ 自动焊接已关闭",Duration=2})end end})

local weldBtnGui=Instance.new("ScreenGui")weldBtnGui.Name="WeldButton"weldBtnGui.Parent=LocalPlayer:WaitForChild("PlayerGui")weldBtnGui.ResetOnSpawn=false
local weldBtn=Instance.new("TextButton")weldBtn.Size=UDim2.new(0,80,0,80)weldBtn.Position=UDim2.new(0.85,-40,0.1,0)weldBtn.BackgroundColor3=Color3.fromRGB(0,150,200)weldBtn.BackgroundTransparency=0.6weldBtn.TextColor3=Color3.fromRGB(255,255,255)weldBtn.Text="🔧\n焊接"weldBtn.TextSize=16weldBtn.Font=Enum.Font.SourceSansBoldweldBtn.BorderSizePixel=2weldBtn.BorderColor3=Color3.fromRGB(255,255,255)weldBtn.Parent=weldBtnGuiweldBtn.ZIndex=10weldBtn.Active=trueweldBtn.Selectable=true
weldBtn.MouseButton1Click:Connect(function()if not capturedStopDragId then WindUI:Notify({Title="⚠️ 请先拖拽物品",Content="触发StopDrag自动捕获ID",Duration=3})return end ExecuteWeld(3109,capturedStopDragId)end)
local drag=false local start=nil weldBtn.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true start=i.Position end end)
weldBtn.InputChanged:Connect(function(i)if drag and(i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement)then local s=workspace.CurrentCamera.ViewportSize weldBtn.Position=UDim2.new(math.clamp(i.Position.X/s.X,0,0.9),0,math.clamp(i.Position.Y/s.Y,0,0.9),0)end end)
weldBtn.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)

UserInputService.TouchStarted:Connect(function()touchCount=touchCount+1 end)
UserInputService.TouchEnded:Connect(function()if touchCount>0 then touchCount=touchCount-1 end end)

task.wait(1)
WindUI:Notify({Title="✅ DFN脚本已加载",Content="作者：边牧\n耗时一星期，累死我了",Icon="solar:check-circle-bold",Duration=6})
print("✅ DFN脚本已启动")

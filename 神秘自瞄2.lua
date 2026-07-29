local function UpdateESP()
    local espOn = Settings.esp

    -- 先把所有绘制隐藏
    for model, data in pairs(espDrawings) do
        data.box.Visible = false
        data.name.Visible = false
        data.dist.Visible = false
        data.hpBar.Visible = false
        if data.highlight then data.highlight.Enabled = false end
    end

    if not espOn then return end

    local camPos = Camera.CFrame.Position
    local currentModels = {}  -- 记录本次扫描到的NPC

    for _, npc in ipairs(GetNPCList()) do
        local model = npc.model
        local humanoid = npc.humanoid
        currentModels[model] = true

        -- ✅ 死亡检测：血量<=0就跳过
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

        -- 血量颜色
        local color = Color3.fromRGB(255, 100, 100)
        if hpPercent > 0.6 then color = Color3.fromRGB(100, 255, 100)
        elseif hpPercent > 0.3 then color = Color3.fromRGB(255, 200, 50) end

        -- 创建/获取绘制对象
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

            -- ✅ 血条（用Line画）
            local hpBar = Drawing.new("Line")
            hpBar.Thickness = 3
            hpBar.Color = Color3.fromRGB(0, 255, 0)
            hpBar.Visible = false

            espDrawings[model] = {
                box = box,
                name = nameTxt,
                dist = distTxt,
                hpBar = hpBar,
                highlight = nil
            }
        end

        local data = espDrawings[model]

        -- 计算方框位置
        local scale = 200 / math.max(dist, 1)
        local w, h = 2 * scale, 3 * scale
        local top, left = sp.Y - h/2, sp.X - w/2

        -- 方框
        if Settings.espBox then
            data.box.Visible = true
            data.box.Position = Vector2.new(left, top)
            data.box.Size = Vector2.new(w, h)
            data.box.Color = color
        end

        -- ✅ 名字 + 实时血量（每帧重新读取）
        if Settings.espName then
            data.name.Visible = true
            local hpText = math.floor(hp)
            data.name.Text = GetDisplayName(model) .. " [" .. hpText .. "HP]"
            data.name.Position = Vector2.new(sp.X, top - 14)
            data.name.Color = Color3.fromRGB(255, 255, 255)
        end

        -- 距离
        if Settings.espDistance then
            data.dist.Visible = true
            data.dist.Text = math.floor(dist) .. "m"
            data.dist.Position = Vector2.new(sp.X, top + h + 12)
        end

        -- ✅ 血条（实时更新位置和长度）
        local barWidth = w
        local barHeight = 3
        local barY = top + h + 4
        local barLeft = sp.X - barWidth / 2
        local barRight = barLeft + barWidth * hpPercent

        data.hpBar.Visible = true
        data.hpBar.From = Vector2.new(barLeft, barY)
        data.hpBar.To = Vector2.new(barRight, barY)
        data.hpBar.Color = color

        -- 高亮
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

    -- ✅ 清理已死亡的NPC绘制
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
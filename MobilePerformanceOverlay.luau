--[[
	Mobile Performance Overlay for Roblox
	Shows FPS, ping, network traffic, and player count in a draggable mobile-friendly widget.
	Tap the widget to open settings, where every metric and visual style can be changed.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function safeGetValue(path)
	local current = Stats
	for _, childName in ipairs(path) do
		current = current and current:FindFirstChild(childName)
		if not current then
			return nil
		end
	end

	local ok, value = pcall(function()
		return current:GetValue()
	end)

	if ok then
		return value
	end

	return nil
end

local function formatNumber(value, decimals)
	if typeof(value) ~= "number" then
		return "--"
	end

	return string.format("%." .. tostring(decimals or 0) .. "f", value)
end

local function applyCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function applyStroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

local oldGui = PlayerGui:FindFirstChild("MobilePerformanceOverlay")
if not oldGui then
	pcall(function()
		oldGui = CoreGui:FindFirstChild("MobilePerformanceOverlay")
	end)
end
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "MobilePerformanceOverlay"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parentOk = pcall(function()
	gui.Parent = CoreGui
end)
if not parentOk then
	gui.Parent = PlayerGui
end

local state = {
	visible = true,
	style = "Neon",
	compact = true,
	rows = {
		fps = true,
		ping = true,
		network = true,
		players = true,
		status = true,
		uptime = false,
	},
	refreshInterval = 0.5,
	colors = {
		Neon = {
			background = Color3.fromRGB(14, 16, 24),
			panel = Color3.fromRGB(20, 23, 33),
			accent = Color3.fromRGB(0, 180, 255),
			text = Color3.fromRGB(245, 250, 255),
			subtext = Color3.fromRGB(158, 183, 204),
		},
		Dark = {
			background = Color3.fromRGB(24, 24, 27),
			panel = Color3.fromRGB(33, 33, 38),
			accent = Color3.fromRGB(135, 92, 255),
			text = Color3.fromRGB(255, 255, 255),
			subtext = Color3.fromRGB(185, 185, 195),
		},
		Light = {
			background = Color3.fromRGB(238, 243, 249),
			panel = Color3.fromRGB(255, 255, 255),
			accent = Color3.fromRGB(36, 128, 255),
			text = Color3.fromRGB(26, 31, 40),
			subtext = Color3.fromRGB(91, 104, 124),
		},
		Green = {
			background = Color3.fromRGB(9, 22, 18),
			panel = Color3.fromRGB(14, 36, 29),
			accent = Color3.fromRGB(70, 255, 170),
			text = Color3.fromRGB(235, 255, 247),
			subtext = Color3.fromRGB(154, 213, 190),
		},
	},
}

local root = Instance.new("Frame")
root.Name = "FloatingStats"
root.AnchorPoint = Vector2.new(0, 0)
root.Position = UDim2.fromOffset(18, 170)
root.Size = UDim2.fromOffset(178, 142)
root.BackgroundTransparency = 0.38
root.Active = true
root.Parent = gui
applyCorner(root, 18)
local rootStroke = applyStroke(root, state.colors.Neon.accent, 1.4, 0.18)

local rootPadding = Instance.new("UIPadding")
rootPadding.PaddingTop = UDim.new(0, 8)
rootPadding.PaddingBottom = UDim.new(0, 8)
rootPadding.PaddingLeft = UDim.new(0, 10)
rootPadding.PaddingRight = UDim.new(0, 10)
rootPadding.Parent = root

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 24)
header.Parent = root

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -34, 1, 0)
title.Font = Enum.Font.GothamBold
title.Text = "СТАТУС"
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextSize = 15
title.Parent = header

local openHint = Instance.new("TextLabel")
openHint.Name = "OpenHint"
openHint.BackgroundTransparency = 1
openHint.AnchorPoint = Vector2.new(1, 0)
openHint.Position = UDim2.new(1, 0, 0, 0)
openHint.Size = UDim2.fromOffset(34, 24)
openHint.Font = Enum.Font.GothamBold
openHint.Text = "⚙"
openHint.TextSize = 18
openHint.Parent = header

local rowsHolder = Instance.new("Frame")
rowsHolder.Name = "Rows"
rowsHolder.BackgroundTransparency = 1
rowsHolder.Position = UDim2.fromOffset(0, 30)
rowsHolder.Size = UDim2.new(1, 0, 1, -30)
rowsHolder.Parent = root

local rowsLayout = Instance.new("UIListLayout")
rowsLayout.FillDirection = Enum.FillDirection.Vertical
rowsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowsLayout.Padding = UDim.new(0, 4)
rowsLayout.Parent = rowsHolder

local rowInfo = {
	fps = { icon = "⚡", label = "FPS", order = 1 },
	ping = { icon = "📡", label = "Пинг", order = 2 },
	network = { icon = "⇅", label = "Сеть", order = 3 },
	players = { icon = "👥", label = "Игроки", order = 4 },
	status = { icon = "◆", label = "Статус", order = 5 },
	uptime = { icon = "⏱", label = "Сессия", order = 6 },
}

local rowLabels = {}
local valueLabels = {}

for key, info in pairs(rowInfo) do
	local row = Instance.new("Frame")
	row.Name = key .. "Row"
	row.BackgroundTransparency = 0.46
	row.Size = UDim2.new(1, 0, 0, 19)
	row.LayoutOrder = info.order
	row.Parent = rowsHolder
	applyCorner(row, 8)

	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingLeft = UDim.new(0, 6)
	rowPad.PaddingRight = UDim.new(0, 6)
	rowPad.Parent = row

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0.52, 0, 1, 0)
	label.Font = Enum.Font.GothamSemibold
	label.Text = info.icon .. "  " .. info.label
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextSize = 12
	label.Parent = row

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, 0, 0, 0)
	value.Size = UDim2.new(0.48, 0, 1, 0)
	value.Font = Enum.Font.GothamBold
	value.Text = "--"
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextSize = 12
	value.Parent = row

	rowLabels[key] = label
	valueLabels[key] = value
end

local settings = Instance.new("Frame")
settings.Name = "SettingsPanel"
settings.AnchorPoint = Vector2.new(0.5, 0.5)
settings.Position = UDim2.fromScale(0.5, 0.5)
settings.Size = UDim2.fromOffset(286, 356)
settings.BackgroundTransparency = 0.18
settings.Visible = false
settings.Parent = gui
applyCorner(settings, 20)
local settingsStroke = applyStroke(settings, state.colors.Neon.accent, 1.4, 0.12)

local settingsPad = Instance.new("UIPadding")
settingsPad.PaddingTop = UDim.new(0, 12)
settingsPad.PaddingBottom = UDim.new(0, 12)
settingsPad.PaddingLeft = UDim.new(0, 12)
settingsPad.PaddingRight = UDim.new(0, 12)
settingsPad.Parent = settings

local settingsTitle = Instance.new("TextLabel")
settingsTitle.Name = "SettingsTitle"
settingsTitle.BackgroundTransparency = 1
settingsTitle.Size = UDim2.new(1, -38, 0, 28)
settingsTitle.Font = Enum.Font.GothamBold
settingsTitle.Text = "Настройки оверлея"
settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
settingsTitle.TextSize = 17
settingsTitle.Parent = settings

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, 0, 0, 0)
closeButton.Size = UDim2.fromOffset(30, 28)
closeButton.BackgroundTransparency = 0.38
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "×"
closeButton.TextSize = 20
closeButton.Parent = settings
applyCorner(closeButton, 10)

local settingsList = Instance.new("Frame")
settingsList.Name = "SettingsList"
settingsList.BackgroundTransparency = 1
settingsList.Position = UDim2.fromOffset(0, 36)
settingsList.Size = UDim2.new(1, 0, 1, -36)
settingsList.Parent = settings

local settingsLayout = Instance.new("UIListLayout")
settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
settingsLayout.Padding = UDim.new(0, 7)
settingsLayout.Parent = settingsList

local function createSection(name, titleText, height, order)
	local section = Instance.new("Frame")
	section.Name = name
	section.BackgroundTransparency = 1
	section.Size = UDim2.new(1, 0, 0, height)
	section.LayoutOrder = order
	section.Parent = settingsList

	local sectionTitle = Instance.new("TextLabel")
	sectionTitle.Name = "Title"
	sectionTitle.BackgroundTransparency = 1
	sectionTitle.Size = UDim2.new(1, 0, 0, 15)
	sectionTitle.Font = Enum.Font.GothamBold
	sectionTitle.Text = titleText
	sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	sectionTitle.TextSize = 11
	sectionTitle.Parent = section

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 18)
	grid.Size = UDim2.new(1, 0, 1, -18)
	grid.Parent = section

	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.CellSize = UDim2.new(0.5, -3, 0, 24)
	layout.Parent = grid

	return section, grid, sectionTitle
end

local metricsSection, metricsGrid, metricsSectionTitle = createSection("MetricsSection", "Показатели", 110, 1)
local toolsSection, toolsGrid, toolsSectionTitle = createSection("ToolsSection", "Действия", 82, 2)
local scriptsSection, scriptsGrid, scriptsSectionTitle = createSection("ScriptsSection", "Свои скрипты", 48, 3)
local controls = {}
local sectionTitles = { metricsSectionTitle, toolsSectionTitle, scriptsSectionTitle }

local function createButton(parent, name, text, order, callback)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 24)
	button.BackgroundTransparency = 0.32
	button.Font = Enum.Font.GothamSemibold
	button.Text = text
	button.TextSize = 12
	button.LayoutOrder = order
	button.Parent = parent
	applyCorner(button, 10)
	button.Activated:Connect(callback)
	return button
end

local function createToggle(metricKey, displayName, order)
	local button = createButton(metricsGrid, metricKey .. "Toggle", "", order, function()
		state.rows[metricKey] = not state.rows[metricKey]
		controls[metricKey]:SetAttribute("Refresh", tick())
	end)
	controls[metricKey] = button
	button:SetAttribute("MetricKey", metricKey)
	button:SetAttribute("DisplayName", displayName)
	return button
end

createToggle("fps", "FPS", 1)
createToggle("ping", "Пинг", 2)
createToggle("network", "Сеть", 3)
createToggle("players", "Игроки", 4)
createToggle("status", "Статус", 5)
createToggle("uptime", "Сессия", 6)

local footer
local approvedScripts = {
	-- Add only your own, free, or otherwise authorized scripts here.
	-- Example:
	-- { name = "My Script", url = "https://example.com/my-free-script.lua" },
}
local selectedScriptIndex = 1

local function getSelectedScript()
	if #approvedScripts == 0 then
		return nil
	end

	selectedScriptIndex = math.clamp(selectedScriptIndex, 1, #approvedScripts)
	return approvedScripts[selectedScriptIndex]
end

local function updateScriptFooter(message)
	footer.Text = message
end

local function runApprovedScript()
	local scriptInfo = getSelectedScript()
	if not scriptInfo then
		updateScriptFooter("Добавь в approvedScripts только свои/бесплатные разрешённые URL. Обход ключей и платных функций отключён.")
		return
	end

	if scriptInfo.requiresKey or scriptInfo.paid then
		updateScriptFooter("Этот загрузчик не запускает ключевые или платные скрипты в обход правил.")
		return
	end

	if typeof(loadstring) ~= "function" then
		updateScriptFooter("В этой среде нет loadstring, запуск внешнего скрипта недоступен.")
		return
	end

	local ok, source = pcall(function()
		return game:HttpGet(scriptInfo.url)
	end)
	if not ok or typeof(source) ~= "string" or source == "" then
		updateScriptFooter("Не удалось загрузить: " .. tostring(scriptInfo.name or "script"))
		return
	end

	local compiled, compileError = loadstring(source)
	if not compiled then
		updateScriptFooter("Ошибка компиляции: " .. tostring(compileError))
		return
	end

	local ran, runtimeError = pcall(compiled)
	updateScriptFooter(ran and ("Запущен: " .. tostring(scriptInfo.name)) or ("Ошибка запуска: " .. tostring(runtimeError)))
end

local selectScriptButton = createButton(scriptsGrid, "SelectScriptButton", "Скрипт: нет", 1, function()
	if #approvedScripts == 0 then
		updateScriptFooter("Список пуст: добавь разрешённые URL в approvedScripts.")
		return
	end

	selectedScriptIndex = (selectedScriptIndex % #approvedScripts) + 1
end)

local runScriptButton = createButton(scriptsGrid, "RunScriptButton", "Запуск", 2, runApprovedScript)

local styleNames = { "Neon", "Dark", "Light", "Green" }
local styleButton = createButton(toolsGrid, "StyleButton", "", 1, function()
	local currentIndex = table.find(styleNames, state.style) or 1
	state.style = styleNames[(currentIndex % #styleNames) + 1]
end)

local compactButton = createButton(toolsGrid, "CompactButton", "", 2, function()
	state.compact = not state.compact
end)

local intervalButton = createButton(toolsGrid, "IntervalButton", "", 3, function()
	state.refreshInterval = state.refreshInterval == 0.5 and 1 or 0.5
end)

local resetButton = createButton(toolsGrid, "ResetButton", "Сброс позиции", 4, function()
	root.Position = UDim2.fromOffset(18, 170)
	settings.Position = UDim2.fromScale(0.5, 0.5)
end)

footer = Instance.new("TextLabel")
footer.Name = "Footer"
footer.BackgroundTransparency = 1
footer.Size = UDim2.new(1, 0, 0, 30)
footer.Font = Enum.Font.Gotham
footer.Text = "Окно и настройки можно двигать. Загрузка чужих платных/ключевых скриптов не поддерживается."
footer.TextWrapped = true
footer.TextSize = 10
footer.LayoutOrder = 4
footer.Parent = settingsList

local function applyStyle()
	local palette = state.colors[state.style]
	root.BackgroundColor3 = palette.background
	root.BackgroundTransparency = 0.38
	settings.BackgroundColor3 = palette.background
	settings.BackgroundTransparency = 0.18
	rootStroke.Color = palette.accent
	settingsStroke.Color = palette.accent
	title.TextColor3 = palette.text
	openHint.TextColor3 = palette.accent
	settingsTitle.TextColor3 = palette.text
	closeButton.BackgroundColor3 = palette.panel
	closeButton.TextColor3 = palette.text
	footer.TextColor3 = palette.subtext
	styleButton.Text = "Стиль: " .. state.style
	compactButton.Text = state.compact and "Компакт" or "Полный"
	intervalButton.Text = "Обновл.: " .. tostring(state.refreshInterval) .. "с"
	local selectedScript = getSelectedScript()
	selectScriptButton.Text = selectedScript and ("Скрипт: " .. tostring(selectedScript.name)) or "Скрипт: нет"
	runScriptButton.Text = "Запуск"

	for key, label in pairs(rowLabels) do
		label.Parent.BackgroundColor3 = palette.panel
		label.Parent.BackgroundTransparency = 0.46
		label.TextColor3 = palette.subtext
		valueLabels[key].TextColor3 = palette.text
	end

	for _, grid in ipairs({ metricsGrid, toolsGrid, scriptsGrid }) do
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("TextButton") then
				child.BackgroundColor3 = palette.panel
				child.BackgroundTransparency = 0.32
				child.TextColor3 = palette.text
			end
		end
	end

	for _, sectionTitle in ipairs(sectionTitles) do
		sectionTitle.TextColor3 = palette.accent
	end

	for key, button in pairs(controls) do
		local enabled = state.rows[key]
		button.Text = (enabled and "✓ " or "○ ") .. button:GetAttribute("DisplayName")
		button.TextColor3 = enabled and palette.text or palette.subtext
	end

	local shownRows = 0
	for key, rowEnabled in pairs(state.rows) do
		rowLabels[key].Parent.Visible = rowEnabled
		if rowEnabled then
			shownRows += 1
		end
	end

	local rowHeight = state.compact and 17 or 20
	local rowPadding = state.compact and 3 or 4
	rowsLayout.Padding = UDim.new(0, rowPadding)
	root.Size = state.compact and UDim2.fromOffset(178, 42 + (shownRows * (rowHeight + rowPadding))) or UDim2.fromOffset(218, 46 + (shownRows * (rowHeight + rowPadding)))
	for key in pairs(rowLabels) do
		rowLabels[key].Parent.Size = UDim2.new(1, 0, 0, rowHeight)
		rowLabels[key].TextSize = state.compact and 11 or 12
		valueLabels[key].TextSize = state.compact and 11 or 12
	end
end

local dragStartPosition
local dragStartInputPosition
local dragging = false
local didMove = false
local activeDragInput

root.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		didMove = false
		activeDragInput = input
		dragStartPosition = root.Position
		dragStartInputPosition = input.Position
	end
end)

root.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
		activeDragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging or input ~= activeDragInput then
		return
	end

	local delta = input.Position - dragStartInputPosition
	if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
		didMove = true
	end

	root.Position = UDim2.new(
		dragStartPosition.X.Scale,
		dragStartPosition.X.Offset + delta.X,
		dragStartPosition.Y.Scale,
		dragStartPosition.Y.Offset + delta.Y
	)
end)

local function finishTouch()
	if not dragging then
		return
	end

	dragging = false
	activeDragInput = nil

	if not didMove then
		settings.Visible = true
		settings.Size = UDim2.fromOffset(266, 334)
		TweenService:Create(settings, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(286, 356),
		}):Play()
	end
end

root.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		finishTouch()
	end
end)

closeButton.Activated:Connect(function()
	settings.Visible = false
end)

local settingsDragging = false
local settingsDragStartPosition
local settingsDragStartInputPosition
local activeSettingsDragInput

settings.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		settingsDragging = true
		activeSettingsDragInput = input
		settingsDragStartPosition = settings.Position
		settingsDragStartInputPosition = input.Position
	end
end)

settings.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
		activeSettingsDragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not settingsDragging or input ~= activeSettingsDragInput then
		return
	end

	local delta = input.Position - settingsDragStartInputPosition
	settings.Position = UDim2.new(
		settingsDragStartPosition.X.Scale,
		settingsDragStartPosition.X.Offset + delta.X,
		settingsDragStartPosition.Y.Scale,
		settingsDragStartPosition.Y.Offset + delta.Y
	)
end)

settings.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		settingsDragging = false
		activeSettingsDragInput = nil
	end
end)

local fpsSamples = {}
local fpsSampleLimit = 24
local fps = 0
local lastRefresh = 0
local sessionStart = tick()
local lastPing = 0

RunService.RenderStepped:Connect(function(deltaTime)
	if deltaTime <= 0 then
		return
	end

	table.insert(fpsSamples, 1 / deltaTime)
	if #fpsSamples > fpsSampleLimit then
		table.remove(fpsSamples, 1)
	end

	local total = 0
	for _, sample in ipairs(fpsSamples) do
		total += sample
	end
	fps = total / #fpsSamples
end)

local function refreshMetrics()
	valueLabels.fps.Text = formatNumber(fps, 0)

	local ping = safeGetValue({ "Network", "ServerStatsItem", "Data Ping" })
	lastPing = ping or lastPing
	valueLabels.ping.Text = formatNumber(ping, 0) .. " ms"

	local recv = safeGetValue({ "Network", "ServerStatsItem", "Data Receive Kbps" }) or 0
	local sent = safeGetValue({ "Network", "ServerStatsItem", "Data Send Kbps" }) or 0
	valueLabels.network.Text = "↓" .. formatNumber(recv, 1) .. " ↑" .. formatNumber(sent, 1) .. " Kbps"

	local maxPlayers = Players.MaxPlayers or 0
	if maxPlayers > 0 then
		valueLabels.players.Text = tostring(#Players:GetPlayers()) .. "/" .. tostring(maxPlayers)
	else
		valueLabels.players.Text = tostring(#Players:GetPlayers())
	end

	local statusText = "OK"
	if fps < 25 or lastPing > 180 then
		statusText = "Плохо"
	elseif fps < 45 or lastPing > 100 then
		statusText = "Средне"
	end
	valueLabels.status.Text = statusText

	local elapsed = math.max(0, math.floor(tick() - sessionStart))
	valueLabels.uptime.Text = string.format("%02d:%02d", math.floor(elapsed / 60), elapsed % 60)
end

RunService.Heartbeat:Connect(function()
	if tick() - lastRefresh < state.refreshInterval then
		return
	end

	lastRefresh = tick()
	refreshMetrics()
	applyStyle()
end)

refreshMetrics()
applyStyle()

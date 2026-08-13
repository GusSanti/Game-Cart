------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local CART_TILT_ACTIVE_ATTRIBUTE: string = "IsCartTilted"
local CART_TILT_DIRECTION_ATTRIBUTE: string = "CartTiltDirection"
local CART_TILT_IMPACT_ATTRIBUTE: string = "CartTiltImpact"
local CART_OVERDRIVE_ACTIVE_ATTRIBUTE: string = "CartOverdriveActive"
local CART_MAX_HEALTH_ATTRIBUTE: string = "CartMaxHealth"
local CART_HEALTH_ATTRIBUTE: string = "CartHealth"
local IS_RAMP_SLIDING_ATTRIBUTE: string = "IsRampSliding"
local CART_MODEL_NAME: string = "Model"
local WHEEL_NAME: string = "wheel"
local WHEEL_NAME_PORTUGUESE: string = "roda"
local SPARK_ATTACHMENT_NAME: string = "CartTiltSparkAttachment"
local SPARK_EMITTER_NAME: string = "CartTiltSparkEmitter"
local OVERDRIVE_EMITTER_NAME: string = "CartOverdriveEmitter"
local IMPACT_HIGHLIGHT_NAME: string = "CartImpactHighlight"
local IMPACT_FEEDBACK_REMOTE_NAME: string = "CartImpactFeedback"
local HEALTH_GUI_NAME: string = "CartHealthGui"
local HEALTH_LABEL_NAME: string = "HealthLabel"
local HEALTH_FILL_NAME: string = "HealthFill"
local IMPACT_FLASH_NAME: string = "ImpactFlash"
local SPARK_TEXTURE: string = "rbxasset://textures/particles/sparkles_main.dds"
local SPARK_RATE: number = 90
local IMPACT_SPARK_COUNT: number = 28
local MINIMUM_WHEEL_SIDE_DISTANCE: number = 0.05
local FALLBACK_WHEEL_SIDE_RATIO: number = 0.35
local FALLBACK_WHEEL_HEIGHT_RATIO: number = 0.45
local OVERDRIVE_RATE: number = 54
local OVERDRIVE_SPEED: number = 10
local OVERDRIVE_PARTICLE_LIFETIME: number = 0.42
local IMPACT_FLASH_IN_DURATION: number = 0.06
local IMPACT_FLASH_OUT_DURATION: number = 0.3
local IMPACT_FLASH_COUNT: number = 3
local IMPACT_HIGHLIGHT_VISIBLE_DURATION: number = 0.08
local IMPACT_HIGHLIGHT_HIDDEN_DURATION: number = 0.07

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local cameraEffectStack = require(replicatedModules:WaitForChild("Gameplay"):WaitForChild("CameraEffectStack"))

------------------//VARIABLES
type SparkEffect = {
	attachment: Attachment,
	emitter: ParticleEmitter,
	side: number,
}

local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local impactFeedback: RemoteEvent = ReplicatedStorage:WaitForChild(IMPACT_FEEDBACK_REMOTE_NAME) :: RemoteEvent
local activeCharacter: Model?
local characterConnections: {RBXScriptConnection} = {}
local sparkEffects: {SparkEffect} = {}
local overdriveEmitters: {ParticleEmitter} = {}
local healthGui: ScreenGui?
local healthLabel: TextLabel?
local healthFill: Frame?
local impactFlash: Frame?

------------------//FUNCTIONS
local function clear_connections(): ()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
end

local function clear_spark_effects(): ()
	for _, sparkEffect in sparkEffects do
		if sparkEffect.attachment.Parent then
			sparkEffect.attachment:Destroy()
		end
	end
	table.clear(sparkEffects)
	table.clear(overdriveEmitters)
end

local function get_part_side(rootPart: BasePart, partPosition: Vector3): number
	local localPosition = rootPart.CFrame:PointToObjectSpace(partPosition)
	if math.abs(localPosition.X) < MINIMUM_WHEEL_SIDE_DISTANCE then
		return 0
	end

	return math.sign(localPosition.X)
end

local function is_wheel_part(part: BasePart): boolean
	local normalizedName = string.lower(part.Name)
	return string.find(normalizedName, WHEEL_NAME, 1, true) ~= nil
		or string.find(normalizedName, WHEEL_NAME_PORTUGUESE, 1, true) ~= nil
end

local function create_spark_effect(parent: BasePart, position: Vector3, side: number): ()
	local attachment = Instance.new("Attachment")
	attachment.Name = SPARK_ATTACHMENT_NAME
	attachment.Position = position
	attachment.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = SPARK_EMITTER_NAME
	emitter.Texture = SPARK_TEXTURE
	emitter.Enabled = false
	emitter.Rate = SPARK_RATE
	emitter.Lifetime = NumberRange.new(0.16, 0.34)
	emitter.Speed = NumberRange.new(8, 15)
	emitter.Acceleration = Vector3.new(0, -38, 0)
	emitter.SpreadAngle = Vector2.new(28, 28)
	emitter.Drag = 3
	emitter.LightEmission = 1
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 239, 128)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 133, 42)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 68, 18)),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = attachment

	table.insert(sparkEffects, {
		attachment = attachment,
		emitter = emitter,
		side = side,
	})
end

local function create_fallback_spark_effects(character: Model, rootPart: BasePart): ()
	local cartModel = character:FindFirstChild(CART_MODEL_NAME)
	if not cartModel or not cartModel:IsA("Model") then
		return
	end

	local cartCFrame, cartSize = cartModel:GetBoundingBox()
	local localCenter = rootPart.CFrame:PointToObjectSpace(cartCFrame.Position)
	local wheelHeight = cartSize.Y * FALLBACK_WHEEL_HEIGHT_RATIO
	local wheelSideDistance = cartSize.X * FALLBACK_WHEEL_SIDE_RATIO
	create_spark_effect(rootPart, localCenter + Vector3.new(-wheelSideDistance, -wheelHeight, 0), -1)
	create_spark_effect(rootPart, localCenter + Vector3.new(wheelSideDistance, -wheelHeight, 0), 1)
end

local function create_spark_effects(character: Model): ()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local cartModel = character:FindFirstChild(CART_MODEL_NAME)
	if cartModel then
		for _, descendant in cartModel:GetDescendants() do
			if descendant:IsA("BasePart") and is_wheel_part(descendant) then
				create_spark_effect(descendant, Vector3.zero, get_part_side(rootPart, descendant.Position))
			end
		end
	end

	if #sparkEffects == 0 then
		create_fallback_spark_effects(character, rootPart)
	end
end

local function should_emit_from_side(effectSide: number, tiltDirection: number): boolean
	return effectSide == 0 or effectSide == tiltDirection
end

local function update_spark_state(): ()
	if not activeCharacter then
		return
	end

	local isTilted = activeCharacter:GetAttribute(CART_TILT_ACTIVE_ATTRIBUTE) == true
	local directionAttribute = activeCharacter:GetAttribute(CART_TILT_DIRECTION_ATTRIBUTE)
	local tiltDirection = if type(directionAttribute) == "number" then math.sign(directionAttribute) else 0
	for _, sparkEffect in sparkEffects do
		sparkEffect.emitter.Enabled = isTilted and should_emit_from_side(sparkEffect.side, tiltDirection)
	end
end

local function create_corner(parent: Instance, radius: number): ()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function ensure_health_gui(): ()
	if healthGui and healthGui.Parent then
		return
	end

	local existingGui = playerGui:FindFirstChild(HEALTH_GUI_NAME)
	if existingGui and existingGui:IsA("ScreenGui") then
		healthGui = existingGui
		healthLabel = existingGui:FindFirstChild(HEALTH_LABEL_NAME, true) :: TextLabel?
		healthFill = existingGui:FindFirstChild(HEALTH_FILL_NAME, true) :: Frame?
		impactFlash = existingGui:FindFirstChild(IMPACT_FLASH_NAME) :: Frame?
		return
	end

	local newGui = Instance.new("ScreenGui")
	newGui.Name = HEALTH_GUI_NAME
	newGui.ResetOnSpawn = false
	newGui.IgnoreGuiInset = true
	newGui.DisplayOrder = 4
	newGui.Parent = playerGui

	local newImpactFlash = Instance.new("Frame")
	newImpactFlash.Name = IMPACT_FLASH_NAME
	newImpactFlash.AnchorPoint = Vector2.new(0.5, 0.5)
	newImpactFlash.Position = UDim2.fromScale(0.5, 0.5)
	newImpactFlash.Size = UDim2.fromScale(1, 1)
	newImpactFlash.BackgroundColor3 = Color3.fromRGB(255, 55, 55)
	newImpactFlash.BackgroundTransparency = 1
	newImpactFlash.BorderSizePixel = 0
	newImpactFlash.ZIndex = 1
	newImpactFlash.Parent = newGui

	local panel = Instance.new("Frame")
	panel.Name = "HealthPanel"
	panel.Position = UDim2.fromOffset(18, 70)
	panel.Size = UDim2.fromOffset(226, 42)
	panel.BackgroundColor3 = Color3.fromRGB(19, 22, 31)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.ZIndex = 2
	panel.Visible = false
	panel.Parent = newGui
	create_corner(panel, 10)

	local label = Instance.new("TextLabel")
	label.Name = HEALTH_LABEL_NAME
	label.Position = UDim2.fromOffset(10, 3)
	label.Size = UDim2.new(1, -20, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 3
	label.Parent = panel

	local fillBackground = Instance.new("Frame")
	fillBackground.Position = UDim2.new(0, 10, 1, -17)
	fillBackground.Size = UDim2.new(1, -20, 0, 10)
	fillBackground.BackgroundColor3 = Color3.fromRGB(56, 62, 77)
	fillBackground.BorderSizePixel = 0
	fillBackground.ZIndex = 3
	fillBackground.Parent = panel
	create_corner(fillBackground, 5)

	local fill = Instance.new("Frame")
	fill.Name = HEALTH_FILL_NAME
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(105, 255, 136)
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	fill.Parent = fillBackground
	create_corner(fill, 5)

	healthGui = newGui
	healthLabel = label
	healthFill = fill
	impactFlash = newImpactFlash
end

local function get_health_color(progress: number): Color3
	if progress > 0.6 then
		return Color3.fromRGB(105, 255, 136)
	end
	if progress > 0.3 then
		return Color3.fromRGB(255, 216, 87)
	end
	return Color3.fromRGB(255, 78, 78)
end

local function update_health_display(): ()
	ensure_health_gui()
	if not healthGui or not healthLabel or not healthFill then
		return
	end

	local character = activeCharacter
	local maxHealth = character and character:GetAttribute(CART_MAX_HEALTH_ATTRIBUTE)
	local health = character and character:GetAttribute(CART_HEALTH_ATTRIBUTE)
	local isSliding = character and character:GetAttribute(IS_RAMP_SLIDING_ATTRIBUTE) == true
	local panel = healthLabel.Parent
	if not panel or not panel:IsA("Frame") then
		return
	end
	if not isSliding or type(maxHealth) ~= "number" or type(health) ~= "number" or maxHealth <= 0 then
		panel.Visible = false
		return
	end

	local progress = math.clamp(health / maxHealth, 0, 1)
	panel.Visible = true
	healthLabel.Text = if character:GetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE) == true
		then ("OVERDRIVE  •  %d / %d"):format(health, maxHealth)
		else ("CARRINHO  •  %d / %d"):format(health, maxHealth)
	local fillTween = TweenService:Create(
		healthFill,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.fromScale(progress, 1), BackgroundColor3 = get_health_color(progress)}
	)
	fillTween:Play()
end

local function create_overdrive_emitter(attachment: Attachment): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = OVERDRIVE_EMITTER_NAME
	emitter.Texture = SPARK_TEXTURE
	emitter.Enabled = false
	emitter.Rate = OVERDRIVE_RATE
	emitter.Lifetime = NumberRange.new(OVERDRIVE_PARTICLE_LIFETIME * 0.65, OVERDRIVE_PARTICLE_LIFETIME)
	emitter.Speed = NumberRange.new(OVERDRIVE_SPEED * 0.55, OVERDRIVE_SPEED)
	emitter.Acceleration = Vector3.new(0, -14, 0)
	emitter.SpreadAngle = Vector2.new(26, 26)
	emitter.Drag = 3
	emitter.LightEmission = 0.8
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 244, 144)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 136, 43)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 63, 28)),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = attachment
	return emitter
end

local function update_overdrive_effects(): ()
	local isOverdriveActive = activeCharacter and activeCharacter:GetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE) == true
	if isOverdriveActive and #overdriveEmitters == 0 then
		for _, sparkEffect in sparkEffects do
			table.insert(overdriveEmitters, create_overdrive_emitter(sparkEffect.attachment))
		end
	end

	for _, emitter in overdriveEmitters do
		emitter.Enabled = isOverdriveActive == true
	end

	update_health_display()
end

local function flash_character_red(character: Model): ()
	local existingHighlight = character:FindFirstChild(IMPACT_HIGHLIGHT_NAME)
	if existingHighlight then
		existingHighlight:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = IMPACT_HIGHLIGHT_NAME
	highlight.FillColor = Color3.fromRGB(255, 47, 47)
	highlight.OutlineColor = Color3.fromRGB(255, 230, 230)
	highlight.FillTransparency = 0.1
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	task.spawn(function()
		for _ = 1, IMPACT_FLASH_COUNT do
			if not highlight.Parent then
				return
			end
			highlight.Enabled = true
			task.wait(IMPACT_HIGHLIGHT_VISIBLE_DURATION)
			highlight.Enabled = false
			task.wait(IMPACT_HIGHLIGHT_HIDDEN_DURATION)
		end

		if highlight.Parent then
			highlight:Destroy()
		end
	end)
end

local function flash_screen(): ()
	ensure_health_gui()
	if not impactFlash then
		return
	end

	impactFlash.BackgroundTransparency = 1
	local fadeIn = TweenService:Create(
		impactFlash,
		TweenInfo.new(IMPACT_FLASH_IN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 0.62}
	)
	fadeIn:Play()
	task.delay(IMPACT_FLASH_IN_DURATION, function()
		if not impactFlash or not impactFlash.Parent then
			return
		end

		local fadeOut = TweenService:Create(
			impactFlash,
			TweenInfo.new(IMPACT_FLASH_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{BackgroundTransparency = 1}
		)
		fadeOut:Play()
	end)
end

local function bump_camera(): ()
	local currentCamera = workspace.CurrentCamera
	if not currentCamera then
		return
	end

	local cameraEffects = cameraEffectStack.get_or_create(currentCamera, currentCamera.FieldOfView, 18)
	cameraEffects:set_effect("CartImpact", -7)
	cameraEffects:set_roll("CartImpact", 6)
	task.delay(0.22, function()
		cameraEffects:remove_effect("CartImpact")
	end)
end

local function on_impact_feedback(damage: number): ()
	if type(damage) ~= "number" or damage <= 0 then
		return
	end

	if activeCharacter then
		flash_character_red(activeCharacter)
	end
	flash_screen()
	bump_camera()
	update_health_display()
end

local function emit_landing_sparks(): ()
	if not activeCharacter then
		return
	end

	local directionAttribute = activeCharacter:GetAttribute(CART_TILT_DIRECTION_ATTRIBUTE)
	local tiltDirection = if type(directionAttribute) == "number" then math.sign(directionAttribute) else 0
	for _, sparkEffect in sparkEffects do
		if should_emit_from_side(sparkEffect.side, tiltDirection) then
			sparkEffect.emitter:Emit(IMPACT_SPARK_COUNT)
		end
	end
end

local function unbind_character(): ()
	clear_connections()
	clear_spark_effects()
	activeCharacter = nil
	update_health_display()
end

local function bind_character(character: Model): ()
	unbind_character()
	activeCharacter = character
	create_spark_effects(character)
	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal(CART_TILT_ACTIVE_ATTRIBUTE):Connect(update_spark_state)
	)
	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal(CART_TILT_DIRECTION_ATTRIBUTE):Connect(update_spark_state)
	)
	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal(CART_TILT_IMPACT_ATTRIBUTE):Connect(emit_landing_sparks)
	)
	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal(CART_OVERDRIVE_ACTIVE_ATTRIBUTE):Connect(update_overdrive_effects)
	)
	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal(CART_MAX_HEALTH_ATTRIBUTE):Connect(update_health_display)
	)
	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal(CART_HEALTH_ATTRIBUTE):Connect(update_health_display)
	)
	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal(IS_RAMP_SLIDING_ATTRIBUTE):Connect(update_health_display)
	)
	update_spark_state()
	update_overdrive_effects()
	update_health_display()
end

------------------//INIT
ensure_health_gui()
impactFeedback.OnClientEvent:Connect(on_impact_feedback)
localPlayer.CharacterAdded:Connect(bind_character)
localPlayer.CharacterRemoving:Connect(unbind_character)

if localPlayer.Character then
	bind_character(localPlayer.Character)
end

------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local CART_TILT_ACTIVE_ATTRIBUTE: string = "IsCartTilted"
local CART_TILT_DIRECTION_ATTRIBUTE: string = "CartTiltDirection"
local CART_TILT_IMPACT_ATTRIBUTE: string = "CartTiltImpact"
local CART_OVERDRIVE_ACTIVE_ATTRIBUTE: string = "CartOverdriveActive"
local CART_MAX_HEALTH_ATTRIBUTE: string = "CartMaxHealth"
local CART_HEALTH_ATTRIBUTE: string = "CartHealth"
local CART_FLOW_ATTRIBUTE: string = "CartFlow"
local CART_FLOW_MAXIMUM_ATTRIBUTE: string = "CartFlowMaximum"
local IS_RAMP_SLIDING_ATTRIBUTE: string = "IsRampSliding"
local CART_MODEL_NAME: string = "Model"
local WHEEL_NAME: string = "wheel"
local WHEEL_NAME_PORTUGUESE: string = "roda"
local SPARK_ATTACHMENT_NAME: string = "CartTiltSparkAttachment"
local SPARK_EMITTER_NAME: string = "CartTiltSparkEmitter"
local OVERDRIVE_EMITTER_NAME: string = "CartOverdriveEmitter"
local SPEED_EMITTER_NAME: string = "CartSpeedEmitter"
local IMPACT_HIGHLIGHT_NAME: string = "CartImpactHighlight"
local IMPACT_FEEDBACK_REMOTE_NAME: string = "CartImpactFeedback"
local HEALTH_GUI_NAME: string = "CartHealthGui"
local HEALTH_LABEL_NAME: string = "HealthLabel"
local HEALTH_FILL_NAME: string = "HealthFill"
local FLOW_LABEL_NAME: string = "FlowLabel"
local FLOW_FILL_NAME: string = "FlowFill"
local IMPACT_FLASH_NAME: string = "ImpactFlash"
local GENERATED_COLLECTIBLES_FOLDER_NAME: string = "GeneratedCollectibles"
local COIN_TEMPLATE_NAME: string = "Coin"
local COIN_COLLECTED_ATTRIBUTE: string = "IsCollected"
local COIN_SURFACE_RIGHT_ATTRIBUTE: string = "CoinSurfaceRight"
local COIN_SURFACE_UP_ATTRIBUTE: string = "CoinSurfaceUp"
local SPARK_TEXTURE: string = "rbxasset://textures/particles/sparkles_main.dds"
local SPARK_RATE: number = 90
local IMPACT_SPARK_COUNT: number = 28
local MINIMUM_WHEEL_SIDE_DISTANCE: number = 0.05
local FALLBACK_WHEEL_SIDE_RATIO: number = 0.35
local FALLBACK_WHEEL_HEIGHT_RATIO: number = 0.45
local OVERDRIVE_RATE: number = 54
local OVERDRIVE_SPEED: number = 10
local OVERDRIVE_PARTICLE_LIFETIME: number = 0.42
local SPEED_EFFECT_MINIMUM_SPEED: number = 16
local SPEED_EFFECT_REFERENCE_SPEED: number = 45
local SPEED_EFFECT_MINIMUM_RATE: number = 16
local SPEED_EFFECT_MAXIMUM_RATE: number = 105
local IMPACT_FLASH_IN_DURATION: number = 0.06
local IMPACT_FLASH_OUT_DURATION: number = 0.3
local IMPACT_FLASH_COUNT: number = 3
local IMPACT_HIGHLIGHT_VISIBLE_DURATION: number = 0.08
local IMPACT_HIGHLIGHT_HIDDEN_DURATION: number = 0.07
local COIN_SPIN_SPEED: number = math.rad(240)
local COIN_UPRIGHT_ANGLE: number = math.rad(90)

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
local speedEmitters: {ParticleEmitter} = {}
local speedRootPart: BasePart?
local healthGui: ScreenGui?
local healthLabel: TextLabel?
local healthFill: Frame?
local flowLabel: TextLabel?
local flowFill: Frame?
local impactFlash: Frame?
local coinRotationByCoin: {[BasePart]: number} = {}

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
	table.clear(speedEmitters)
	speedRootPart = nil
end

local function get_part_side(rootPart: BasePart, partPosition: Vector3): number
	local localPosition = rootPart.CFrame:PointToObjectSpace(partPosition)
	if math.abs(localPosition.X) < MINIMUM_WHEEL_SIDE_DISTANCE then
		return 0
	end

	return math.sign(localPosition.X)
end

local function is_wheel_instance(instance: Instance): boolean
	local normalizedName = string.lower(instance.Name)
	return string.find(normalizedName, WHEEL_NAME, 1, true) ~= nil
		or string.find(normalizedName, WHEEL_NAME_PORTUGUESE, 1, true) ~= nil
end

local function create_spark_effect(parent: BasePart, worldCFrame: CFrame, side: number): ()
	local attachment = Instance.new("Attachment")
	attachment.Name = SPARK_ATTACHMENT_NAME
	attachment.Parent = parent
	attachment.WorldCFrame = worldCFrame

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

local function get_largest_wheel_part(wheelModel: Model): BasePart?
	local largestPart: BasePart?
	local largestVolume = 0
	for _, descendant in wheelModel:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
		if volume > largestVolume then
			largestPart = descendant
			largestVolume = volume
		end
	end
	return largestPart
end

local function create_wheel_model_spark_effects(cartModel: Instance, rootPart: BasePart): ()
	for _, descendant in cartModel:GetDescendants() do
		if not descendant:IsA("Model") or not is_wheel_instance(descendant) then
			continue
		end

		local wheelPart = get_largest_wheel_part(descendant)
		if not wheelPart then
			continue
		end

		local wheelCFrame, wheelSize = descendant:GetBoundingBox()
		local contactPosition = wheelCFrame.Position - rootPart.CFrame.UpVector * wheelSize.Y * 0.5
		local effectCFrame = CFrame.lookAt(
			contactPosition,
			contactPosition + rootPart.CFrame.LookVector,
			rootPart.CFrame.UpVector
		)
		create_spark_effect(wheelPart, effectCFrame, get_part_side(rootPart, wheelCFrame.Position))
	end
end

local function create_named_wheel_part_spark_effects(cartModel: Instance, rootPart: BasePart): ()
	for _, descendant in cartModel:GetDescendants() do
		if not descendant:IsA("BasePart") or not is_wheel_instance(descendant) then
			continue
		end

		local contactPosition = descendant.Position - rootPart.CFrame.UpVector * descendant.Size.Y * 0.5
		local effectCFrame = CFrame.lookAt(
			contactPosition,
			contactPosition + rootPart.CFrame.LookVector,
			rootPart.CFrame.UpVector
		)
		create_spark_effect(descendant, effectCFrame, get_part_side(rootPart, descendant.Position))
	end
end

local function create_fallback_spark_effects(character: Model, rootPart: BasePart): ()
	local cartModel = character:FindFirstChild(CART_MODEL_NAME)
	if not cartModel then
		return
	end

	local wheelHeight = rootPart.Size.Y * FALLBACK_WHEEL_HEIGHT_RATIO
	local wheelSideDistance = rootPart.Size.X * FALLBACK_WHEEL_SIDE_RATIO
	local leftPosition = rootPart.Position
		+ rootPart.CFrame.RightVector * -wheelSideDistance
		+ rootPart.CFrame.UpVector * -wheelHeight
	local rightPosition = rootPart.Position
		+ rootPart.CFrame.RightVector * wheelSideDistance
		+ rootPart.CFrame.UpVector * -wheelHeight
	create_spark_effect(rootPart, CFrame.lookAt(leftPosition, leftPosition + rootPart.CFrame.LookVector), -1)
	create_spark_effect(rootPart, CFrame.lookAt(rightPosition, rightPosition + rootPart.CFrame.LookVector), 1)
end

local function create_spark_effects(character: Model): ()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local cartModel = character:FindFirstChild(CART_MODEL_NAME)
	if cartModel then
		create_wheel_model_spark_effects(cartModel, rootPart)
		if #sparkEffects == 0 then
			create_named_wheel_part_spark_effects(cartModel, rootPart)
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

local function ensure_health_gui(): ()
	if healthGui and healthGui.Parent then
		return
	end

	local existingGui = playerGui:FindFirstChild(HEALTH_GUI_NAME) or playerGui:WaitForChild(HEALTH_GUI_NAME, 5)
	if not existingGui or not existingGui:IsA("ScreenGui") then
		return
	end

	local label = existingGui:FindFirstChild(HEALTH_LABEL_NAME, true)
	local fill = existingGui:FindFirstChild(HEALTH_FILL_NAME, true)
	local newFlowLabel = existingGui:FindFirstChild(FLOW_LABEL_NAME, true)
	local newFlowFill = existingGui:FindFirstChild(FLOW_FILL_NAME, true)
	local newImpactFlash = existingGui:FindFirstChild(IMPACT_FLASH_NAME)
	if not label
		or not label:IsA("TextLabel")
		or not fill
		or not fill:IsA("Frame")
		or not newFlowLabel
		or not newFlowLabel:IsA("TextLabel")
		or not newFlowFill
		or not newFlowFill:IsA("Frame")
		or not newImpactFlash
		or not newImpactFlash:IsA("Frame")
	then
		return
	end

	healthGui = existingGui
	healthLabel = label
	healthFill = fill
	flowLabel = newFlowLabel
	flowFill = newFlowFill
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
	if not healthGui or not healthLabel or not healthFill or not flowLabel or not flowFill then
		return
	end

	local character = activeCharacter
	local maxHealth = character and character:GetAttribute(CART_MAX_HEALTH_ATTRIBUTE)
	local health = character and character:GetAttribute(CART_HEALTH_ATTRIBUTE)
	local maximumFlow = character and character:GetAttribute(CART_FLOW_MAXIMUM_ATTRIBUTE)
	local flow = character and character:GetAttribute(CART_FLOW_ATTRIBUTE)
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
	healthLabel.Text = ("CARRINHO  •  %d / %d"):format(health, maxHealth)
	local fillTween = TweenService:Create(
		healthFill,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.fromScale(progress, 1), BackgroundColor3 = get_health_color(progress)}
	)
	fillTween:Play()

	local flowProgress = if type(maximumFlow) == "number"
		and type(flow) == "number"
		and maximumFlow > 0
		then math.clamp(flow / maximumFlow, 0, 1)
		else 0
	local isOverdriveActive = character:GetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE) == true
	flowLabel.Text = if isOverdriveActive
		then "OVERDRIVE"
		else ("FLOW  •  %d%%"):format(math.round(flowProgress * 100))
	local flowTween = TweenService:Create(
		flowFill,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = UDim2.fromScale(flowProgress, 1),
			BackgroundColor3 = if isOverdriveActive
				then Color3.fromRGB(255, 151, 42)
				else Color3.fromRGB(76, 220, 255),
		}
	)
	flowTween:Play()
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

local function flash_character_impact(character: Model, damage: number): ()
	local existingHighlight = character:FindFirstChild(IMPACT_HIGHLIGHT_NAME)
	if existingHighlight then
		existingHighlight:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = IMPACT_HIGHLIGHT_NAME
	highlight.FillColor = if damage <= 0 then Color3.fromRGB(255, 174, 52) else Color3.fromRGB(255, 47, 47)
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

local function bump_camera(damage: number): ()
	local currentCamera = workspace.CurrentCamera
	if not currentCamera then
		return
	end

	local cameraEffects = cameraEffectStack.get_or_create(currentCamera, currentCamera.FieldOfView, 18)
	local impactStrength = if damage <= 0 then 0.55 else math.clamp(damage, 1, 2)
	cameraEffects:set_effect("CartImpact", -6 * impactStrength)
	cameraEffects:set_roll("CartImpact", 4 * impactStrength)
	task.delay(0.22, function()
		cameraEffects:remove_effect("CartImpact")
	end)
end

local function on_impact_feedback(damage: number): ()
	if type(damage) ~= "number" or damage < 0 then
		return
	end

	if activeCharacter then
		flash_character_impact(activeCharacter, damage)
	end
	flash_screen()
	bump_camera(damage)
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

local function track_coin(instance: Instance): ()
	if not instance:IsA("BasePart") or instance.Name ~= COIN_TEMPLATE_NAME then
		return
	end

	local surfaceRight = instance:GetAttribute(COIN_SURFACE_RIGHT_ATTRIBUTE)
	local surfaceUp = instance:GetAttribute(COIN_SURFACE_UP_ATTRIBUTE)
	if typeof(surfaceRight) ~= "Vector3" or typeof(surfaceUp) ~= "Vector3" then
		return
	end

	coinRotationByCoin[instance] = 0
end

local function update_coin_visuals(deltaTime: number): ()
	for coin, rotation in coinRotationByCoin do
		if not coin.Parent or coin:GetAttribute(COIN_COLLECTED_ATTRIBUTE) == true then
			coinRotationByCoin[coin] = nil
			continue
		end
		if coin.CanTouch ~= true then
			continue
		end

		local surfaceRight = coin:GetAttribute(COIN_SURFACE_RIGHT_ATTRIBUTE)
		local surfaceUp = coin:GetAttribute(COIN_SURFACE_UP_ATTRIBUTE)
		if typeof(surfaceRight) ~= "Vector3" or typeof(surfaceUp) ~= "Vector3" then
			coinRotationByCoin[coin] = nil
			continue
		end

		local nextRotation = (rotation + COIN_SPIN_SPEED * deltaTime) % (math.pi * 2)
		coinRotationByCoin[coin] = nextRotation
		local surfaceCFrame = CFrame.fromMatrix(coin.Position, surfaceRight, surfaceUp)
		coin.CFrame = surfaceCFrame
			* CFrame.Angles(0, nextRotation, 0)
			* CFrame.Angles(COIN_UPRIGHT_ANGLE, 0, 0)
	end
end

local function create_speed_effect(character: Model): ()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	for _, sparkEffect in sparkEffects do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = SPEED_EMITTER_NAME
		emitter.Texture = SPARK_TEXTURE
		emitter.Enabled = false
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(0.22, 0.4)
		emitter.Speed = NumberRange.new(2, 6)
		emitter.EmissionDirection = Enum.NormalId.Back
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.SpreadAngle = Vector2.new(7, 7)
		emitter.LightEmission = 0.8
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.09),
			NumberSequenceKeypoint.new(1, 0.025),
		})
		emitter.Parent = sparkEffect.attachment
		table.insert(speedEmitters, emitter)
	end

	speedRootPart = rootPart
end

local function update_speed_effect(): ()
	local rootPart = speedRootPart
	if #speedEmitters == 0 or not rootPart or not rootPart.Parent or not activeCharacter then
		return
	end

	local speed = rootPart.AssemblyLinearVelocity.Magnitude
	local speedProgress = math.clamp(
		(speed - SPEED_EFFECT_MINIMUM_SPEED) / (SPEED_EFFECT_REFERENCE_SPEED - SPEED_EFFECT_MINIMUM_SPEED),
		0,
		1
	)
	local isSliding = activeCharacter:GetAttribute(IS_RAMP_SLIDING_ATTRIBUTE) == true
	local isOverdriveActive = activeCharacter:GetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE) == true
	local totalRate = SPEED_EFFECT_MINIMUM_RATE
		+ (SPEED_EFFECT_MAXIMUM_RATE - SPEED_EFFECT_MINIMUM_RATE) * speedProgress
		+ (if isOverdriveActive then 45 else 0)
	local emitterRate = totalRate / #speedEmitters
	local emitterColor = if isOverdriveActive
		then ColorSequence.new(Color3.fromRGB(255, 157, 55))
		else ColorSequence.new(Color3.fromRGB(184, 235, 255))
	for _, emitter in speedEmitters do
		emitter.Enabled = isSliding and (speedProgress > 0 or isOverdriveActive)
		emitter.Rate = emitterRate
		emitter.Color = emitterColor
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
	create_speed_effect(character)
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
		character:GetAttributeChangedSignal(CART_FLOW_ATTRIBUTE):Connect(update_health_display)
	)
	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal(CART_FLOW_MAXIMUM_ATTRIBUTE):Connect(update_health_display)
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

local generatedCollectiblesFolder = workspace:WaitForChild(GENERATED_COLLECTIBLES_FOLDER_NAME)
for _, descendant in generatedCollectiblesFolder:GetDescendants() do
	track_coin(descendant)
end
generatedCollectiblesFolder.DescendantAdded:Connect(track_coin)
RunService.RenderStepped:Connect(function(deltaTime: number)
	update_coin_visuals(deltaTime)
	update_speed_effect()
end)

if localPlayer.Character then
	bind_character(localPlayer.Character)
end

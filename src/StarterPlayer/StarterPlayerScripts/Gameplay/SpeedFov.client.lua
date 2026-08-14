------------------//SERVICES
local Players: Players = game:GetService("Players")
local Lighting: Lighting = game:GetService("Lighting")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local EQUIPPED_CART_ATTRIBUTE: string = "EquippedCart"
local IS_RAMP_SLIDING_ATTRIBUTE: string = "IsRampSliding"
local RAMP_MODE_STATE_ATTRIBUTE: string = "RampModeState"
local CART_OVERDRIVE_ACTIVE_ATTRIBUTE: string = "CartOverdriveActive"
local MAX_SPEED_ATTRIBUTE: string = "MaxSpeed"
local DEFAULT_CART_NAME: string = "Default"
local SLIDE_STATE: string = "Slide"
local DEFAULT_SPEED_REFERENCE: number = 45
local MIN_SPEED_TO_INCREASE_FOV: number = 8
local MAX_SPEED_FOV_BOOST: number = 16
local OVERDRIVE_FOV_BOOST: number = 6
local FOV_SMOOTHING_SPEED: number = 11
local MAX_CAMERA_ROLL: number = 9
local CAMERA_ROLL_MULTIPLIER: number = 0.38
local CAMERA_VIBRATION_START_PROGRESS: number = 0.48
local CAMERA_VIBRATION_MAXIMUM_OFFSET: number = 0.055
local CAMERA_VIBRATION_MAXIMUM_ROLL: number = 0.28
local CAMERA_VIBRATION_FREQUENCY: number = 9
local MAX_SPEED_BLUR: number = 2.4
local OVERDRIVE_BLUR_BOOST: number = 1.8
local BLUR_EFFECT_NAME: string = "CartSpeedBlur"
local GROUND_CHECK_DISTANCE: number = 10
local MIN_SURFACE_DIRECTION_MAGNITUDE: number = 0.01
local SPEED_FOV_EFFECT_NAME: string = "Speed"
local TURN_CAMERA_EFFECT_NAME: string = "Turn"
local RENDER_STEP_NAME: string = "SpeedFov"
local RENDER_STEP_PRIORITY: number = Enum.RenderPriority.Camera.Value + 1
local CAMERA_DEBUG_ENABLED: boolean = false
local CAMERA_DEBUG_INTERVAL: number = 0.25

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local gameplayModules: Folder = replicatedModules:WaitForChild("Gameplay")
local cameraEffectStackModule = require(gameplayModules:WaitForChild("CameraEffectStack"))

------------------//VARIABLES
type CameraEffectStack = {
	set_effect: (self: CameraEffectStack, effectName: string, fieldOfViewOffset: number) -> (),
	set_roll: (self: CameraEffectStack, effectName: string, rollOffset: number) -> (),
	get_effect_offset: (self: CameraEffectStack, effectName: string) -> number,
	get_current_field_of_view: (self: CameraEffectStack) -> number,
	get_current_roll: (self: CameraEffectStack) -> number,
	step: (self: CameraEffectStack, deltaTime: number) -> (),
	destroy: (self: CameraEffectStack) -> (),
}

local localPlayer: Player = Players.LocalPlayer
local activeCamera: Camera?
local activeCameraEffects: CameraEffectStack?
local activeSpeedReference: number = DEFAULT_SPEED_REFERENCE
local cameraDebugElapsed: number = 0
local speedBlur: BlurEffect?
local groundRaycastParams = RaycastParams.new()
groundRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

------------------//FUNCTIONS
local function get_positive_number_attribute(instance: Instance?, attributeName: string, fallback: number): number
	if not instance then
		return fallback
	end

	local value = instance:GetAttribute(attributeName)
	if type(value) ~= "number" or value <= 0 or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end

	return value
end

local function get_equipped_cart(): Instance?
	local equippedCart = localPlayer:GetAttribute(EQUIPPED_CART_ATTRIBUTE)
	local cartName = if type(equippedCart) == "string" and equippedCart ~= ""
		then equippedCart
		else DEFAULT_CART_NAME
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local carts = assets and assets:FindFirstChild("Carts")
	return carts and carts:FindFirstChild(cartName)
end

local function update_speed_reference(): ()
	activeSpeedReference = get_positive_number_attribute(
		get_equipped_cart(),
		MAX_SPEED_ATTRIBUTE,
		DEFAULT_SPEED_REFERENCE
	)
end

local function get_cart_root_part(): BasePart?
	local character = localPlayer.Character
	if not character or character:GetAttribute(IS_RAMP_SLIDING_ATTRIBUTE) ~= true then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart
end

local function ensure_camera_effects(): ()
	local currentCamera = workspace.CurrentCamera
	if currentCamera == activeCamera and activeCameraEffects then
		return
	end

	if activeCameraEffects then
		activeCameraEffects:destroy()
	end

	activeCamera = currentCamera
	activeCameraEffects = if currentCamera
		then cameraEffectStackModule.get_or_create(currentCamera, currentCamera.FieldOfView, FOV_SMOOTHING_SPEED)
		else nil
end

local function get_speed_fov_offset(): number
	local rootPart = get_cart_root_part()
	if not rootPart then
		return 0
	end

	local speed = rootPart.AssemblyLinearVelocity.Magnitude
	if speed <= MIN_SPEED_TO_INCREASE_FOV then
		return 0
	end

	local speedRange = math.max(activeSpeedReference - MIN_SPEED_TO_INCREASE_FOV, 1)
	local speedProgress = math.clamp(
		(speed - MIN_SPEED_TO_INCREASE_FOV) / speedRange,
		0,
		1
	)
	local smoothProgress = speedProgress * speedProgress * (3 - 2 * speedProgress)
	local character = localPlayer.Character
	local isOverdriveActive = character and character:GetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE) == true
	local overdriveBoost = if isOverdriveActive
		then OVERDRIVE_FOV_BOOST + math.sin(os.clock() * 10) * 0.7
		else 0
	return smoothProgress * MAX_SPEED_FOV_BOOST + overdriveBoost
end

local function get_speed_progress(): number
	local rootPart = get_cart_root_part()
	if not rootPart then
		return 0
	end

	local speedRange = math.max(activeSpeedReference - MIN_SPEED_TO_INCREASE_FOV, 1)
	return math.clamp(
		(rootPart.AssemblyLinearVelocity.Magnitude - MIN_SPEED_TO_INCREASE_FOV) / speedRange,
		0,
		1
	)
end

local function ensure_speed_blur(): BlurEffect
	if speedBlur and speedBlur.Parent then
		return speedBlur
	end

	local existingBlur = Lighting:FindFirstChild(BLUR_EFFECT_NAME)
	if existingBlur then
		existingBlur:Destroy()
	end
	local newBlur = Instance.new("BlurEffect")
	newBlur.Name = BLUR_EFFECT_NAME
	newBlur.Size = 0
	newBlur.Parent = Lighting
	speedBlur = newBlur
	return newBlur
end

local function project_onto_plane(vector: Vector3, normal: Vector3): Vector3
	return vector - normal * vector:Dot(normal)
end

local function get_camera_roll_offset(): number
	local character = localPlayer.Character
	local rootPart = get_cart_root_part()
	if not character or not rootPart or character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) ~= SLIDE_STATE then
		return 0
	end

	groundRaycastParams.FilterDescendantsInstances = {character}
	local groundResult = workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -GROUND_CHECK_DISTANCE, 0),
		groundRaycastParams
	)
	if not groundResult then
		return 0
	end

	local groundNormal = groundResult.Normal
	local forwardDirection = project_onto_plane(rootPart.CFrame.LookVector, groundNormal)
	if forwardDirection.Magnitude < MIN_SURFACE_DIRECTION_MAGNITUDE then
		return 0
	end

	forwardDirection = forwardDirection.Unit
	local cartUpDirection = project_onto_plane(rootPart.CFrame.UpVector, forwardDirection)
	if cartUpDirection.Magnitude < MIN_SURFACE_DIRECTION_MAGNITUDE then
		return 0
	end

	local surfaceUpDirection = project_onto_plane(groundNormal, forwardDirection)
	if surfaceUpDirection.Magnitude < MIN_SURFACE_DIRECTION_MAGNITUDE then
		return 0
	end

	cartUpDirection = cartUpDirection.Unit
	surfaceUpDirection = surfaceUpDirection.Unit
	local sine = surfaceUpDirection:Cross(cartUpDirection):Dot(forwardDirection)
	local cosine = math.clamp(surfaceUpDirection:Dot(cartUpDirection), -1, 1)
	local cartRoll = math.deg(math.atan2(-sine, cosine)) * CAMERA_ROLL_MULTIPLIER
	return math.clamp(cartRoll, -MAX_CAMERA_ROLL, MAX_CAMERA_ROLL)
end

local function update_speed_blur(speedProgress: number, isOverdriveActive: boolean, deltaTime: number): ()
	local blur = ensure_speed_blur()
	local targetSize = speedProgress * speedProgress * MAX_SPEED_BLUR
		+ (if isOverdriveActive then OVERDRIVE_BLUR_BOOST else 0)
	local smoothingAlpha = 1 - math.exp(-8 * deltaTime)
	blur.Size += (targetSize - blur.Size) * smoothingAlpha
end

local function apply_camera_vibration(speedProgress: number, isOverdriveActive: boolean): ()
	local currentCamera = activeCamera
	if not currentCamera then
		return
	end

	local vibrationProgress = math.clamp(
		(speedProgress - CAMERA_VIBRATION_START_PROGRESS) / (1 - CAMERA_VIBRATION_START_PROGRESS),
		0,
		1
	)
	if isOverdriveActive then
		vibrationProgress = 1
	end
	if vibrationProgress <= 0 then
		return
	end

	local currentTime = os.clock() * CAMERA_VIBRATION_FREQUENCY
	local offsetScale = CAMERA_VIBRATION_MAXIMUM_OFFSET * vibrationProgress
	local rollScale = CAMERA_VIBRATION_MAXIMUM_ROLL * vibrationProgress
	local horizontalOffset = math.noise(currentTime, 0, 0) * offsetScale
	local verticalOffset = math.noise(0, currentTime, 0) * offsetScale
	local rollOffset = math.noise(0, 0, currentTime) * rollScale
	currentCamera.CFrame *= CFrame.new(horizontalOffset, verticalOffset, 0)
		* CFrame.Angles(0, 0, math.rad(rollOffset))
end

local function get_cart_speed(): number
	local rootPart = get_cart_root_part()
	return if rootPart then rootPart.AssemblyLinearVelocity.Magnitude else 0
end

local function update_camera_debug(
	deltaTime: number,
	cameraEffects: CameraEffectStack,
	speedFovOffset: number,
	rollOffset: number
): ()
	if not CAMERA_DEBUG_ENABLED then
		return
	end

	cameraDebugElapsed += deltaTime
	if cameraDebugElapsed < CAMERA_DEBUG_INTERVAL then
		return
	end
	cameraDebugElapsed = 0

	local character = localPlayer.Character
	local modeState = if character then character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) else "None"
	local isSliding = if character
		then character:GetAttribute(IS_RAMP_SLIDING_ATTRIBUTE) == true
		else false
	local chargeFovOffset = cameraEffects:get_effect_offset("Charge")
	print(string.format(
		"[CameraDebug] mode=%s sliding=%s speed=%.1f speedFov=%.2f chargeFov=%.2f targetRoll=%.2f currentRoll=%.2f cameraFov=%.2f",
		tostring(modeState),
		tostring(isSliding),
		get_cart_speed(),
		speedFovOffset,
		chargeFovOffset,
		rollOffset,
		cameraEffects:get_current_roll(),
		cameraEffects:get_current_field_of_view()
	))
end

local function update_camera_effects(deltaTime: number): ()
	ensure_camera_effects()

	local cameraEffects = activeCameraEffects
	if not cameraEffects then
		return
	end

	local speedFovOffset = get_speed_fov_offset()
	local speedProgress = get_speed_progress()
	local character = localPlayer.Character
	local isOverdriveActive = character and character:GetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE) == true
	local rollOffset = get_camera_roll_offset()
	cameraEffects:set_effect(SPEED_FOV_EFFECT_NAME, speedFovOffset)
	cameraEffects:set_roll(TURN_CAMERA_EFFECT_NAME, rollOffset)
	cameraEffects:step(deltaTime)
	update_speed_blur(speedProgress, isOverdriveActive == true, deltaTime)
	apply_camera_vibration(speedProgress, isOverdriveActive == true)
	update_camera_debug(deltaTime, cameraEffects, speedFovOffset, rollOffset)
end

------------------//MAIN FUNCTIONS
local function cleanup(): ()
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	if activeCameraEffects then
		activeCameraEffects:destroy()
		activeCameraEffects = nil
	end
	activeCamera = nil
	cameraDebugElapsed = 0
	if speedBlur then
		speedBlur:Destroy()
		speedBlur = nil
	end
end

------------------//INIT
localPlayer:GetAttributeChangedSignal(EQUIPPED_CART_ATTRIBUTE):Connect(update_speed_reference)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(ensure_camera_effects)
script.Destroying:Connect(cleanup)
update_speed_reference()
ensure_camera_effects()
RunService:BindToRenderStep(RENDER_STEP_NAME, RENDER_STEP_PRIORITY, update_camera_effects)

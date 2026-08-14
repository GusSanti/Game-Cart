------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local EQUIPPED_CART_ATTRIBUTE: string = "EquippedCart"
local IS_RAMP_SLIDING_ATTRIBUTE: string = "IsRampSliding"
local RAMP_MODE_STATE_ATTRIBUTE: string = "RampModeState"
local MAX_SPEED_ATTRIBUTE: string = "MaxSpeed"
local DEFAULT_CART_NAME: string = "Default"
local SLIDE_STATE: string = "Slide"
local DEFAULT_SPEED_REFERENCE: number = 45
local MIN_SPEED_TO_INCREASE_FOV: number = 2
local MAX_SPEED_FOV_BOOST: number = 12
local FOV_SMOOTHING_SPEED: number = 9
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
	return smoothProgress * MAX_SPEED_FOV_BOOST
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
	return math.deg(math.atan2(-sine, cosine))
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
	local rollOffset = get_camera_roll_offset()
	cameraEffects:set_effect(SPEED_FOV_EFFECT_NAME, speedFovOffset)
	cameraEffects:set_roll(TURN_CAMERA_EFFECT_NAME, rollOffset)
	cameraEffects:step(deltaTime)
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
end

------------------//INIT
localPlayer:GetAttributeChangedSignal(EQUIPPED_CART_ATTRIBUTE):Connect(update_speed_reference)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(ensure_camera_effects)
script.Destroying:Connect(cleanup)
update_speed_reference()
ensure_camera_effects()
RunService:BindToRenderStep(RENDER_STEP_NAME, RENDER_STEP_PRIORITY, update_camera_effects)

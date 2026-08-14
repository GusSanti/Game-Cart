------------------//SERVICES
local Players: Players = game:GetService("Players")
local ContextActionService: ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local IS_RAMP_SLIDING_ATTRIBUTE: string = "IsRampSliding"
local RAMP_MODE_STATE_ATTRIBUTE: string = "RampModeState"
local RAMP_LAUNCH_ACCEPTED_ATTRIBUTE: string = "RampLaunchAccepted"
local RAMP_LAUNCH_POWER_ATTRIBUTE: string = "RampLaunchPower"
local RAMP_ENTRY_BOOST_SPEED_ATTRIBUTE: string = "RampEntryBoostSpeed"
local CART_TILT_ACTIVE_ATTRIBUTE: string = "IsCartTilted"
local CART_TILT_DIRECTION_ATTRIBUTE: string = "CartTiltDirection"
local CART_TILT_IMPACT_ATTRIBUTE: string = "CartTiltImpact"
local CART_JUMP_ACTIVE_ATTRIBUTE: string = "CartJumpActive"
local CART_JUMP_POWER_ATTRIBUTE: string = "CartJumpPower"
local CHARGE_STATE: string = "Charge"
local AIRBORNE_STATE: string = "Airborne"
local SLIDE_STATE: string = "Slide"
local EQUIPPED_CART_ATTRIBUTE: string = "EquippedCart"
local DEFAULT_CART_NAME: string = "Default"
local MAX_SPEED_ATTRIBUTE: string = "MaxSpeed"
local ACCELERATION_ATTRIBUTE: string = "Acceleration"
local COASTING_ACCELERATION_ATTRIBUTE: string = "CoastingAcceleration"
local STEERING_ACCELERATION_ATTRIBUTE: string = "SteeringAcceleration"
local LAUNCH_UPWARD_BOOST_ATTRIBUTE: string = "LaunchUpwardBoost"
local LAUNCH_FORWARD_BOOST_ATTRIBUTE: string = "LaunchForwardBoost"
local AIR_SPIN_DURATION_ATTRIBUTE: string = "AirSpinDuration"
local AIR_ROLL_ANGLE_ATTRIBUTE: string = "AirRollAngle"
local TILT_ANGLE_ATTRIBUTE: string = "TiltAngle"
local CART_OVERDRIVE_ACTIVE_ATTRIBUTE: string = "CartOverdriveActive"
local CART_CONTROL_REQUEST_NAME: string = "CartControlRequest"
local FORCE_ATTACHMENT_NAME: string = "RampSlideAttachment"
local FORCE_NAME: string = "RampSlideForce"
local ORIENTATION_NAME: string = "RampSlideOrientation"
local CART_TILT_ACTION_NAME: string = "RampCartTilt"
local CART_TILT_BUTTON_TITLE: string = "VIRAR"
local CART_JUMP_ACTION_NAME: string = "RampCartJump"
local CART_JUMP_BUTTON_TITLE: string = "PULAR"
local CART_TILT_METER_GUI_NAME: string = "CartTiltMeter"
local GROUND_CHECK_DISTANCE: number = 10
local AIRBORNE_GROUND_CHECK_DISTANCE: number = 14
local MIN_AIRBORNE_TIME: number = 0.28
local EXTRA_DOWNWARD_ACCELERATION: number = 70
local SURFACE_ADHESION_ACCELERATION: number = 55
local DEFAULT_MAX_SLIDE_SPEED: number = 45
local DEFAULT_ACCELERATION: number = 16
local DEFAULT_COASTING_ACCELERATION: number = 8
local DEFAULT_STEERING_ACCELERATION: number = 16
local DEFAULT_LAUNCH_UPWARD_BOOST: number = 78
local DEFAULT_LAUNCH_FORWARD_BOOST: number = 54
local DEFAULT_AIR_SPIN_DURATION: number = 1.05
local DEFAULT_AIR_ROLL_ANGLE: number = 14
local AIR_STEERING_RESPONSIVENESS: number = 3.5
local MIN_ORIENTATION_SPEED: number = 2
local ORIENTATION_RESPONSIVENESS: number = 18
local MAX_ANGULAR_VELOCITY: number = 28
local SLIDE_FRICTION: number = 0
local SLIDE_FRICTION_WEIGHT: number = 100
local DEFAULT_CART_TILT_ANGLE: number = math.rad(38)
local MINIMUM_CART_TILT_ANGLE: number = math.rad(20)
local MAXIMUM_CART_TILT_ANGLE: number = math.rad(55)
local CART_TILT_IMPACT_ANGLE: number = math.rad(6)
local CART_TILT_ANIMATION_RESPONSE: number = 9
local CART_TILT_RETURN_DURATION: number = 0.18
local CART_TILT_IMPACT_DURATION: number = 0.32
local CART_TILT_COOLDOWN: number = 0.35
local CART_TILT_STEERING_MULTIPLIER: number = 3.25
local CART_TILT_INPUT_THRESHOLD: number = 0.35
local CART_TILT_BUTTON_POSITION: UDim2 = UDim2.new(1, -145, 1, -220)
local CART_JUMP_BUTTON_POSITION: UDim2 = UDim2.new(1, -145, 1, -300)
local TILT_ENERGY_MAXIMUM: number = 1
local TILT_ENERGY_DRAIN_DURATION: number = 1.7
local TILT_ENERGY_RECOVERY_DURATION: number = 1.1
local JUMP_CHARGE_DURATION: number = 1.2
local JUMP_COOLDOWN_DURATION: number = 1.35
local MINIMUM_JUMP_POWER: number = 0.15
local MAXIMUM_JUMP_POWER: number = 1
local MINIMUM_JUMP_UPWARD_BOOST: number = 72
local MAXIMUM_JUMP_UPWARD_BOOST: number = 112
local JUMP_ASCENT_ANIMATION_ANGLE: number = math.rad(34)
local JUMP_ANIMATION_VERTICAL_REFERENCE: number = 110
local OVERDRIVE_MAX_SPEED_MULTIPLIER: number = 1.28
local OVERDRIVE_ACCELERATION_MULTIPLIER: number = 1.2
local OVERDRIVE_COASTING_ACCELERATION_MULTIPLIER: number = 1.15
local OVERDRIVE_STEERING_ACCELERATION_MULTIPLIER: number = 1.1

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local rampUtility = require(replicatedModules:WaitForChild("Gameplay"):WaitForChild("RampUtility"))

------------------//VARIABLES
type HumanoidDefaults = {
	walkSpeed: number,
	jumpPower: number,
	jumpHeight: number,
	autoRotate: boolean,
	platformStand: boolean,
	jumpingEnabled: boolean,
}

type MeterState = {
	tiltGui: ScreenGui?,
	tiltFill: Frame?,
	tiltLabel: TextLabel?,
	jumpFrame: Frame?,
	jumpFill: Frame?,
	jumpLabel: TextLabel?,
}

type JumpState = {
	isCharging: boolean,
	chargeStartedAt: number,
	cooldownEndsAt: number,
}

local localPlayer: Player = Players.LocalPlayer
local character: Model = script.Parent :: Model
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid
local rootPart: BasePart = character:WaitForChild("HumanoidRootPart") :: BasePart
local animator: Animator = humanoid:WaitForChild("Animator") :: Animator
local cartControlRequest: RemoteEvent = ReplicatedStorage:WaitForChild(CART_CONTROL_REQUEST_NAME) :: RemoteEvent
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = {character}

local isSliding: boolean = false
local forceAttachment: Attachment?
local slideForce: VectorForce?
local slideOrientation: AlignOrientation?
local animationPlayedConnection: RBXScriptConnection?
local originalPhysicalProperties = {}
local animateScript: LocalScript?
local animateWasEnabled: boolean = true
local humanoidDefaults: HumanoidDefaults = {
	walkSpeed = humanoid.WalkSpeed,
	jumpPower = humanoid.JumpPower,
	jumpHeight = humanoid.JumpHeight,
	autoRotate = humanoid.AutoRotate,
	platformStand = humanoid.PlatformStand,
	jumpingEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
}
local activeMaxSlideSpeed: number = DEFAULT_MAX_SLIDE_SPEED
local activeAcceleration: number = DEFAULT_ACCELERATION
local activeCoastingAcceleration: number = DEFAULT_COASTING_ACCELERATION
local activeSteeringAcceleration: number = DEFAULT_STEERING_ACCELERATION
local activeLaunchUpwardBoost: number = DEFAULT_LAUNCH_UPWARD_BOOST
local activeLaunchForwardBoost: number = DEFAULT_LAUNCH_FORWARD_BOOST
local activeAirSpinDuration: number = DEFAULT_AIR_SPIN_DURATION
local activeAirRollAngle: number = DEFAULT_AIR_ROLL_ANGLE
local activeCartTiltAngle: number = DEFAULT_CART_TILT_ANGLE
local configuredMaxSlideSpeed: number = DEFAULT_MAX_SLIDE_SPEED
local configuredAcceleration: number = DEFAULT_ACCELERATION
local configuredCoastingAcceleration: number = DEFAULT_COASTING_ACCELERATION
local configuredSteeringAcceleration: number = DEFAULT_STEERING_ACCELERATION
local currentSpeedLimit: number = 0
local isAirborne: boolean = false
local airborneElapsed: number = 0
local airSpinAngle: number = 0
local chargeCFrame: CFrame?
local isCartTilted: boolean = false
local isCartTiltActionBound: boolean = false
local isCartJumpActionBound: boolean = false
local isTouchTiltHeld: boolean = false
local requiresTiltInputRelease: boolean = false
local tiltDirection: number = 0
local lastTiltDirection: number = 0
local currentTiltAngle: number = 0
local landingStartTiltAngle: number = 0
local landingStartedAt: number = 0
local tiltCooldownEndsAt: number = 0
local tiltEnergy: number = TILT_ENERGY_MAXIMUM
local meterState: MeterState = {
	tiltGui = nil,
	tiltFill = nil,
	tiltLabel = nil,
	jumpFrame = nil,
	jumpFill = nil,
	jumpLabel = nil,
}
local jumpState: JumpState = {
	isCharging = false,
	chargeStartedAt = 0,
	cooldownEndsAt = 0,
}

------------------//FUNCTIONS
local function project_onto_plane(vector: Vector3, normal: Vector3): Vector3
	return vector - normal * vector:Dot(normal)
end

local function move_towards(currentValue: number, targetValue: number, maximumDelta: number): number
	if currentValue < targetValue then
		return math.min(currentValue + maximumDelta, targetValue)
	end

	return math.max(currentValue - maximumDelta, targetValue)
end

local function get_positive_number_attribute(instance: Instance?, attributeName: string, fallback: number): number
	if not instance then
		return fallback
	end

	local value = instance:GetAttribute(attributeName)
	if type(value) ~= "number" or value <= 0 or value ~= value or value == math.huge then
		return fallback
	end

	return value
end

local function update_overdrive_configuration(): ()
	local isOverdriveActive = character:GetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE) == true
	local maxSpeedMultiplier = if isOverdriveActive then OVERDRIVE_MAX_SPEED_MULTIPLIER else 1
	local accelerationMultiplier = if isOverdriveActive then OVERDRIVE_ACCELERATION_MULTIPLIER else 1
	local coastingAccelerationMultiplier = if isOverdriveActive then OVERDRIVE_COASTING_ACCELERATION_MULTIPLIER else 1
	local steeringAccelerationMultiplier = if isOverdriveActive then OVERDRIVE_STEERING_ACCELERATION_MULTIPLIER else 1

	activeMaxSlideSpeed = configuredMaxSlideSpeed * maxSpeedMultiplier
	activeAcceleration = configuredAcceleration * accelerationMultiplier
	activeCoastingAcceleration = configuredCoastingAcceleration * coastingAccelerationMultiplier
	activeSteeringAcceleration = configuredSteeringAcceleration * steeringAccelerationMultiplier
	currentSpeedLimit = math.min(currentSpeedLimit, activeMaxSlideSpeed)
end

local function update_cart_configuration(): ()
	local equippedCart = localPlayer:GetAttribute(EQUIPPED_CART_ATTRIBUTE)
	local cartName = if type(equippedCart) == "string" and equippedCart ~= ""
		then equippedCart
		else DEFAULT_CART_NAME
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local carts = assets and assets:FindFirstChild("Carts")
	local cart = carts and carts:FindFirstChild(cartName)

	configuredMaxSlideSpeed = get_positive_number_attribute(cart, MAX_SPEED_ATTRIBUTE, DEFAULT_MAX_SLIDE_SPEED)
	configuredAcceleration = get_positive_number_attribute(cart, ACCELERATION_ATTRIBUTE, DEFAULT_ACCELERATION)
	configuredCoastingAcceleration = get_positive_number_attribute(
		cart,
		COASTING_ACCELERATION_ATTRIBUTE,
		DEFAULT_COASTING_ACCELERATION
	)
	configuredSteeringAcceleration = get_positive_number_attribute(
		cart,
		STEERING_ACCELERATION_ATTRIBUTE,
		DEFAULT_STEERING_ACCELERATION
	)
	activeLaunchUpwardBoost = get_positive_number_attribute(
		cart,
		LAUNCH_UPWARD_BOOST_ATTRIBUTE,
		DEFAULT_LAUNCH_UPWARD_BOOST
	)
	activeLaunchForwardBoost = get_positive_number_attribute(
		cart,
		LAUNCH_FORWARD_BOOST_ATTRIBUTE,
		DEFAULT_LAUNCH_FORWARD_BOOST
	)
	activeAirSpinDuration = get_positive_number_attribute(
		cart,
		AIR_SPIN_DURATION_ATTRIBUTE,
		DEFAULT_AIR_SPIN_DURATION
	)
	activeAirRollAngle = get_positive_number_attribute(
		cart,
		AIR_ROLL_ANGLE_ATTRIBUTE,
		DEFAULT_AIR_ROLL_ANGLE
	)
	local tiltAngleDegrees = get_positive_number_attribute(cart, TILT_ANGLE_ATTRIBUTE, math.deg(DEFAULT_CART_TILT_ANGLE))
	activeCartTiltAngle = math.rad(math.clamp(
		tiltAngleDegrees,
		math.deg(MINIMUM_CART_TILT_ANGLE),
		math.deg(MAXIMUM_CART_TILT_ANGLE)
	))
	update_overdrive_configuration()
end

local function create_tilt_meter(): ()
	if meterState.tiltGui and meterState.tiltGui.Parent then
		return
	end

	local existingMeterGui = localPlayer.PlayerGui:FindFirstChild(CART_TILT_METER_GUI_NAME)
	if existingMeterGui and existingMeterGui:IsA("ScreenGui") then
		existingMeterGui:Destroy()
	end

	local newMeterGui = Instance.new("ScreenGui")
	newMeterGui.Name = CART_TILT_METER_GUI_NAME
	newMeterGui.ResetOnSpawn = false
	newMeterGui.IgnoreGuiInset = true
	newMeterGui.DisplayOrder = 8
	newMeterGui.Enabled = false
	newMeterGui.Parent = localPlayer.PlayerGui

	local meterFrame = Instance.new("Frame")
	meterFrame.Name = "Meter"
	meterFrame.AnchorPoint = Vector2.new(0.5, 1)
	meterFrame.Position = UDim2.new(0.5, 0, 1, -96)
	meterFrame.Size = UDim2.fromOffset(272, 48)
	meterFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 38)
	meterFrame.BackgroundTransparency = 0.12
	meterFrame.BorderSizePixel = 0
	meterFrame.Parent = newMeterGui

	local meterCorner = Instance.new("UICorner")
	meterCorner.CornerRadius = UDim.new(0, 12)
	meterCorner.Parent = meterFrame

	local meterStroke = Instance.new("UIStroke")
	meterStroke.Color = Color3.fromRGB(135, 162, 255)
	meterStroke.Transparency = 0.2
	meterStroke.Thickness = 2
	meterStroke.Parent = meterFrame

	local meterLabel = Instance.new("TextLabel")
	meterLabel.Name = "Label"
	meterLabel.Position = UDim2.fromOffset(12, 4)
	meterLabel.Size = UDim2.new(1, -24, 0, 17)
	meterLabel.BackgroundTransparency = 1
	meterLabel.Font = Enum.Font.GothamBlack
	meterLabel.Text = "INCLINAÇÃO  •  SHIFT + A/D"
	meterLabel.TextColor3 = Color3.fromRGB(240, 244, 255)
	meterLabel.TextSize = 12
	meterLabel.TextXAlignment = Enum.TextXAlignment.Left
	meterLabel.Parent = meterFrame

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(12, 27)
	track.Size = UDim2.new(1, -24, 0, 11)
	track.BackgroundColor3 = Color3.fromRGB(50, 59, 88)
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = meterFrame

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(94, 255, 154)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local jumpMeter = Instance.new("Frame")
	jumpMeter.Name = "JumpMeter"
	jumpMeter.AnchorPoint = Vector2.new(0.5, 1)
	jumpMeter.Position = UDim2.new(0.5, 0, 1, -154)
	jumpMeter.Size = UDim2.fromOffset(272, 48)
	jumpMeter.BackgroundColor3 = Color3.fromRGB(29, 17, 49)
	jumpMeter.BackgroundTransparency = 0.08
	jumpMeter.BorderSizePixel = 0
	jumpMeter.Visible = false
	jumpMeter.Parent = newMeterGui

	local jumpMeterCorner = Instance.new("UICorner")
	jumpMeterCorner.CornerRadius = UDim.new(0, 12)
	jumpMeterCorner.Parent = jumpMeter

	local jumpMeterStroke = Instance.new("UIStroke")
	jumpMeterStroke.Color = Color3.fromRGB(213, 120, 255)
	jumpMeterStroke.Transparency = 0.15
	jumpMeterStroke.Thickness = 2
	jumpMeterStroke.Parent = jumpMeter

	local jumpLabel = Instance.new("TextLabel")
	jumpLabel.Name = "Label"
	jumpLabel.Position = UDim2.fromOffset(12, 4)
	jumpLabel.Size = UDim2.new(1, -24, 0, 17)
	jumpLabel.BackgroundTransparency = 1
	jumpLabel.Font = Enum.Font.GothamBlack
	jumpLabel.Text = "SALTO TURBO  •  SEGURE ESPAÇO"
	jumpLabel.TextColor3 = Color3.fromRGB(251, 238, 255)
	jumpLabel.TextSize = 12
	jumpLabel.TextXAlignment = Enum.TextXAlignment.Left
	jumpLabel.Parent = jumpMeter

	local jumpTrack = Instance.new("Frame")
	jumpTrack.Name = "Track"
	jumpTrack.Position = UDim2.fromOffset(12, 27)
	jumpTrack.Size = UDim2.new(1, -24, 0, 11)
	jumpTrack.BackgroundColor3 = Color3.fromRGB(73, 48, 99)
	jumpTrack.BorderSizePixel = 0
	jumpTrack.ClipsDescendants = true
	jumpTrack.Parent = jumpMeter

	local jumpTrackCorner = Instance.new("UICorner")
	jumpTrackCorner.CornerRadius = UDim.new(1, 0)
	jumpTrackCorner.Parent = jumpTrack

	local jumpFill = Instance.new("Frame")
	jumpFill.Name = "Fill"
	jumpFill.Size = UDim2.fromScale(0, 1)
	jumpFill.BackgroundColor3 = Color3.fromRGB(221, 112, 255)
	jumpFill.BorderSizePixel = 0
	jumpFill.Parent = jumpTrack

	local jumpFillCorner = Instance.new("UICorner")
	jumpFillCorner.CornerRadius = UDim.new(1, 0)
	jumpFillCorner.Parent = jumpFill

	meterState.tiltGui = newMeterGui
	meterState.tiltFill = fill
	meterState.tiltLabel = meterLabel
	meterState.jumpFrame = jumpMeter
	meterState.jumpFill = jumpFill
	meterState.jumpLabel = jumpLabel
end

local function destroy_tilt_meter(): ()
	if meterState.tiltGui then
		meterState.tiltGui:Destroy()
	end
	meterState.tiltGui = nil
	meterState.tiltFill = nil
	meterState.tiltLabel = nil
	meterState.jumpFrame = nil
	meterState.jumpFill = nil
	meterState.jumpLabel = nil
end

local function update_tilt_meter(): ()
	if not meterState.tiltFill or not meterState.tiltLabel then
		return
	end

	local energyRatio = math.clamp(tiltEnergy / TILT_ENERGY_MAXIMUM, 0, 1)
	meterState.tiltFill.Size = UDim2.fromScale(energyRatio, 1)
	meterState.tiltFill.BackgroundColor3 = if energyRatio > 0.55
		then Color3.fromRGB(94, 255, 154)
		elseif energyRatio > 0.25 then Color3.fromRGB(255, 210, 77)
		else Color3.fromRGB(255, 92, 108)
	meterState.tiltLabel.Text = ("INCLINAÇÃO  •  SHIFT + A/D  %d%%"):format(math.round(energyRatio * 100))
end

local function set_tilt_meter_visible(isVisible: boolean): ()
	create_tilt_meter()
	if meterState.tiltGui then
		meterState.tiltGui.Enabled = isVisible
	end
	if meterState.jumpFrame then
		meterState.jumpFrame.Visible = false
	end
	update_tilt_meter()
end

local function reset_tilt_energy(): ()
	tiltEnergy = TILT_ENERGY_MAXIMUM
	update_tilt_meter()
end

local function update_tilt_energy(deltaTime: number, isTiltRequested: boolean): boolean
	if isTiltRequested then
		tiltEnergy = math.max(tiltEnergy - deltaTime / TILT_ENERGY_DRAIN_DURATION, 0)
	else
		tiltEnergy = math.min(tiltEnergy + deltaTime / TILT_ENERGY_RECOVERY_DURATION, TILT_ENERGY_MAXIMUM)
	end
	update_tilt_meter()
	return tiltEnergy > 0
end

local function get_jump_charge_value(): number
	if not jumpState.isCharging or jumpState.chargeStartedAt == 0 then
		return 0
	end

	return math.clamp((os.clock() - jumpState.chargeStartedAt) / JUMP_CHARGE_DURATION, 0, 1)
end

local function update_jump_charge_meter(): ()
	if not meterState.jumpFrame or not meterState.jumpFill or not meterState.jumpLabel then
		return
	end

	local isVisible = jumpState.isCharging
		and isSliding
		and not isAirborne
		and character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) == SLIDE_STATE
	meterState.jumpFrame.Visible = isVisible
	if not isVisible then
		return
	end

	local chargeValue = get_jump_charge_value()
	meterState.jumpFill.Size = UDim2.fromScale(chargeValue, 1)
	meterState.jumpLabel.Text = ("SALTO TURBO  •  %d%%"):format(math.round(chargeValue * 100))
end

local function clear_jump_charge(): ()
	jumpState.isCharging = false
	jumpState.chargeStartedAt = 0
	update_jump_charge_meter()
end

local function begin_jump_charge(): ()
	if not isSliding
		or isAirborne
		or jumpState.isCharging
		or os.clock() < jumpState.cooldownEndsAt
		or character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) ~= SLIDE_STATE
	then
		return
	end

	create_tilt_meter()
	jumpState.isCharging = true
	jumpState.chargeStartedAt = os.clock()
	update_jump_charge_meter()
end

local function release_jump_charge(): ()
	if not jumpState.isCharging then
		return
	end

	local chargeValue = get_jump_charge_value()
	clear_jump_charge()
	if not isSliding or character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) ~= SLIDE_STATE then
		return
	end

	jumpState.cooldownEndsAt = os.clock() + JUMP_COOLDOWN_DURATION
	cartControlRequest:FireServer("Jump", chargeValue)
end

local function set_cart_tilt_effect_state(isActive: boolean, direction: number): ()
	character:SetAttribute(CART_TILT_ACTIVE_ATTRIBUTE, isActive)
	character:SetAttribute(CART_TILT_DIRECTION_ATTRIBUTE, direction)
end

local function clear_cart_tilt(): ()
	isCartTilted = false
	tiltDirection = 0
	lastTiltDirection = 0
	currentTiltAngle = 0
	landingStartTiltAngle = 0
	landingStartedAt = 0
	requiresTiltInputRelease = false
	set_cart_tilt_effect_state(false, 0)
end

local function start_cart_tilt_landing(): ()
	if not isCartTilted then
		return
	end

	isCartTilted = false
	landingStartTiltAngle = currentTiltAngle
	landingStartedAt = os.clock()
	tiltCooldownEndsAt = landingStartedAt + CART_TILT_COOLDOWN
	requiresTiltInputRelease = true
	set_cart_tilt_effect_state(false, lastTiltDirection)
	character:SetAttribute(CART_TILT_IMPACT_ATTRIBUTE, (character:GetAttribute(CART_TILT_IMPACT_ATTRIBUTE) or 0) + 1)
end

local function update_cart_tilt_animation(deltaTime: number): ()
	local targetTiltAngle: number = 0
	if isCartTilted then
		targetTiltAngle = -tiltDirection * activeCartTiltAngle
		landingStartedAt = 0
	elseif landingStartedAt > 0 then
		local elapsed = os.clock() - landingStartedAt
		local returnProgress = math.clamp(elapsed / CART_TILT_RETURN_DURATION, 0, 1)
		targetTiltAngle = landingStartTiltAngle * (1 - returnProgress)

		local impactElapsed = elapsed - CART_TILT_RETURN_DURATION
		if impactElapsed >= 0 and impactElapsed <= CART_TILT_IMPACT_DURATION then
			local impactProgress = impactElapsed / CART_TILT_IMPACT_DURATION
			targetTiltAngle += lastTiltDirection
				* CART_TILT_IMPACT_ANGLE
				* math.sin(impactProgress * math.pi)
		elseif impactElapsed > CART_TILT_IMPACT_DURATION then
			landingStartedAt = 0
			landingStartTiltAngle = 0
		end
	end

	currentTiltAngle = move_towards(
		currentTiltAngle,
		targetTiltAngle,
		CART_TILT_ANIMATION_RESPONSE * deltaTime
	)
end

local function get_keyboard_tilt_direction(): number
	local isShiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	local isLeftHeld = UserInputService:IsKeyDown(Enum.KeyCode.A)
		or UserInputService:IsKeyDown(Enum.KeyCode.Left)
	local isRightHeld = UserInputService:IsKeyDown(Enum.KeyCode.D)
		or UserInputService:IsKeyDown(Enum.KeyCode.Right)
	if not isShiftHeld or isLeftHeld == isRightHeld then
		return 0
	end

	return if isRightHeld then 1 else -1
end

local function get_touch_tilt_direction(movementInput: Vector3, groundNormal: Vector3): number
	if not isTouchTiltHeld then
		return 0
	end

	local lateralDirection = project_onto_plane(rootPart.CFrame.RightVector, groundNormal)
	if lateralDirection.Magnitude <= 0.01 then
		return 0
	end

	local lateralInput = movementInput:Dot(lateralDirection.Unit)
	if math.abs(lateralInput) < CART_TILT_INPUT_THRESHOLD then
		return 0
	end

	return math.sign(lateralInput)
end

local function update_cart_tilt(deltaTime: number, groundNormal: Vector3, movementInput: Vector3): boolean
	local requestedDirection = get_keyboard_tilt_direction()
	if requestedDirection == 0 then
		requestedDirection = get_touch_tilt_direction(movementInput, groundNormal)
	end
	local hasTiltEnergy = update_tilt_energy(deltaTime, requestedDirection ~= 0)

	if requestedDirection == 0 then
		requiresTiltInputRelease = false
	elseif hasTiltEnergy and not requiresTiltInputRelease and os.clock() >= tiltCooldownEndsAt then
		isCartTilted = true
		tiltDirection = requestedDirection
		lastTiltDirection = requestedDirection
		set_cart_tilt_effect_state(true, requestedDirection)
	elseif isCartTilted then
		start_cart_tilt_landing()
	end

	if isCartTilted and requestedDirection == 0 then
		start_cart_tilt_landing()
	end

	update_cart_tilt_animation(deltaTime)
	return isCartTilted
end

local function on_cart_tilt_action(
	_actionName: string,
	inputState: Enum.UserInputState
): Enum.ContextActionResult
	if not UserInputService.TouchEnabled then
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Begin then
		isTouchTiltHeld = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		isTouchTiltHeld = false
	end

	return if isSliding then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
end

local function on_cart_jump_action(
	_actionName: string,
	inputState: Enum.UserInputState
): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		begin_jump_charge()
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		release_jump_charge()
	end

	return if isSliding and character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) == SLIDE_STATE
		then Enum.ContextActionResult.Sink
		else Enum.ContextActionResult.Pass
end

local function bind_cart_tilt_action(): ()
	if isCartTiltActionBound then
		return
	end

	isCartTiltActionBound = true
	ContextActionService:BindActionAtPriority(
		CART_TILT_ACTION_NAME,
		on_cart_tilt_action,
		true,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.LeftShift
	)
	ContextActionService:SetTitle(CART_TILT_ACTION_NAME, CART_TILT_BUTTON_TITLE)
	ContextActionService:SetPosition(CART_TILT_ACTION_NAME, CART_TILT_BUTTON_POSITION)
end

local function unbind_cart_tilt_action(): ()
	if not isCartTiltActionBound then
		return
	end

	isCartTiltActionBound = false
	isTouchTiltHeld = false
	ContextActionService:UnbindAction(CART_TILT_ACTION_NAME)
end

local function bind_cart_jump_action(): ()
	if isCartJumpActionBound then
		return
	end

	isCartJumpActionBound = true
	ContextActionService:BindActionAtPriority(
		CART_JUMP_ACTION_NAME,
		on_cart_jump_action,
		true,
		Enum.ContextActionPriority.High.Value + 1,
		Enum.KeyCode.Space
	)
	ContextActionService:SetTitle(CART_JUMP_ACTION_NAME, CART_JUMP_BUTTON_TITLE)
	ContextActionService:SetPosition(CART_JUMP_ACTION_NAME, CART_JUMP_BUTTON_POSITION)
end

local function unbind_cart_jump_action(): ()
	if not isCartJumpActionBound then
		return
	end

	isCartJumpActionBound = false
	clear_jump_charge()
	ContextActionService:UnbindAction(CART_JUMP_ACTION_NAME)
end

local function stop_animation_track(animationTrack: AnimationTrack): ()
	animationTrack:Stop(0)
end

local function stop_all_animations(): ()
	for _, animationTrack in animator:GetPlayingAnimationTracks() do
		stop_animation_track(animationTrack)
	end
end

local function set_slippery_physics(bodyPart: BasePart): ()
	if bodyPart.Massless and not bodyPart.CanCollide then
		return
	end

	if originalPhysicalProperties[bodyPart] == nil then
		originalPhysicalProperties[bodyPart] = bodyPart.CustomPhysicalProperties or false
	end

	local currentProperties = bodyPart.CurrentPhysicalProperties
	bodyPart.CustomPhysicalProperties = PhysicalProperties.new(
		currentProperties.Density,
		SLIDE_FRICTION,
		currentProperties.Elasticity,
		SLIDE_FRICTION_WEIGHT,
		currentProperties.ElasticityWeight
	)
end

local function restore_physics(): ()
	for bodyPart, properties in originalPhysicalProperties do
		if bodyPart.Parent then
			if properties == false then
				bodyPart.CustomPhysicalProperties = nil
			else
				bodyPart.CustomPhysicalProperties = properties
			end
		end
	end
	table.clear(originalPhysicalProperties)
end

local function get_ramp_ground(distance: number?): RaycastResult?
	local result = workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -(distance or GROUND_CHECK_DISTANCE), 0),
		raycastParams
	)
	if result and rampUtility.is_ramp(result.Instance) then
		return result
	end

	return nil
end

local function get_surface_forward(surfaceNormal: Vector3): Vector3
	local forwardDirection = project_onto_plane(rootPart.CFrame.LookVector, surfaceNormal)
	if forwardDirection.Magnitude > 0.01 then
		return forwardDirection.Unit
	end

	local velocityDirection = project_onto_plane(rootPart.AssemblyLinearVelocity, surfaceNormal)
	if velocityDirection.Magnitude > 0.01 then
		return velocityDirection.Unit
	end

	return rootPart.CFrame.LookVector
end

local function create_slide_actuators(): ()
	local attachment = Instance.new("Attachment")
	attachment.Name = FORCE_ATTACHMENT_NAME
	attachment.Parent = rootPart
	forceAttachment = attachment

	local vectorForce = Instance.new("VectorForce")
	vectorForce.Name = FORCE_NAME
	vectorForce.Attachment0 = attachment
	vectorForce.ApplyAtCenterOfMass = true
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.Parent = rootPart
	slideForce = vectorForce

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = ORIENTATION_NAME
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = math.huge
	alignOrientation.MaxAngularVelocity = MAX_ANGULAR_VELOCITY
	alignOrientation.Responsiveness = ORIENTATION_RESPONSIVENESS
	alignOrientation.Parent = rootPart
	slideOrientation = alignOrientation
end

local function apply_airborne_boost(): ()
	if rootPart.AssemblyLinearVelocity.Y > 20 then
		return
	end

	local groundResult = get_ramp_ground(AIRBORNE_GROUND_CHECK_DISTANCE)
	local groundNormal = if groundResult then groundResult.Normal else Vector3.yAxis
	local forwardDirection = get_surface_forward(groundNormal)
	local launchPower = character:GetAttribute(RAMP_LAUNCH_POWER_ATTRIBUTE)
	if type(launchPower) ~= "number" then
		launchPower = 0.75
	end
	launchPower = math.clamp(launchPower, 0, 1)

	local surfaceVelocity = project_onto_plane(rootPart.AssemblyLinearVelocity, groundNormal)
	local currentForwardSpeed = surfaceVelocity:Dot(forwardDirection)
	if currentForwardSpeed < 0 then
		surfaceVelocity -= forwardDirection * currentForwardSpeed
	end

	local boostScale = 0.75 + launchPower * 0.25
	rootPart.AssemblyLinearVelocity = surfaceVelocity
		+ forwardDirection * activeLaunchForwardBoost * boostScale
		+ Vector3.yAxis * activeLaunchUpwardBoost * boostScale
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

local function apply_cart_jump_boost(): ()
	local jumpPowerAttribute = character:GetAttribute(CART_JUMP_POWER_ATTRIBUTE)
	local jumpPower = if type(jumpPowerAttribute) == "number" then jumpPowerAttribute else MINIMUM_JUMP_POWER
	jumpPower = math.clamp(jumpPower, MINIMUM_JUMP_POWER, MAXIMUM_JUMP_POWER)
	local upwardBoost = MINIMUM_JUMP_UPWARD_BOOST
		+ (MAXIMUM_JUMP_UPWARD_BOOST - MINIMUM_JUMP_UPWARD_BOOST) * jumpPower
	local velocity = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, 0) + upwardBoost, velocity.Z)
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

local function enter_airborne_state(): ()
	if isAirborne then
		return
	end

	isAirborne = true
	chargeCFrame = nil
	clear_cart_tilt()
	clear_jump_charge()
	set_tilt_meter_visible(false)
	unbind_cart_tilt_action()
	unbind_cart_jump_action()
	rootPart.Anchored = false
	airborneElapsed = 0
	airSpinAngle = 0
	if character:GetAttribute(CART_JUMP_ACTIVE_ATTRIBUTE) == true then
		apply_cart_jump_boost()
	else
		apply_airborne_boost()
	end
	if slideForce then
		slideForce.Force = Vector3.zero
	end
end

local function enter_charge_state(): ()
	if chargeCFrame then
		return
	end

	chargeCFrame = rootPart.CFrame
	clear_cart_tilt()
	clear_jump_charge()
	set_tilt_meter_visible(false)
	unbind_cart_tilt_action()
	unbind_cart_jump_action()
	rootPart.Anchored = true
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	if slideForce then
		slideForce.Force = Vector3.zero
	end
	if slideOrientation then
		slideOrientation.CFrame = CFrame.lookAt(Vector3.zero, chargeCFrame.LookVector, chargeCFrame.UpVector)
	end
end

local function leave_airborne_state(groundResult: RaycastResult): ()
	isAirborne = false
	airborneElapsed = 0
	airSpinAngle = 0
	local groundNormal = groundResult.Normal
	local surfaceVelocity = project_onto_plane(rootPart.AssemblyLinearVelocity, groundNormal)
	currentSpeedLimit = math.min(surfaceVelocity.Magnitude, activeMaxSlideSpeed)
	rootPart.AssemblyAngularVelocity = Vector3.zero
	character:SetAttribute(RAMP_LAUNCH_ACCEPTED_ATTRIBUTE, false)
	character:SetAttribute(RAMP_MODE_STATE_ATTRIBUTE, SLIDE_STATE)
	character:SetAttribute(CART_JUMP_ACTIVE_ATTRIBUTE, false)
	bind_cart_tilt_action()
	bind_cart_jump_action()
	set_tilt_meter_visible(true)
	local surfaceDirection = project_onto_plane(rootPart.AssemblyLinearVelocity, groundNormal)
	if slideOrientation and surfaceDirection.Magnitude > MIN_ORIENTATION_SPEED then
		slideOrientation.CFrame = CFrame.lookAt(Vector3.zero, surfaceDirection.Unit, groundNormal)
	end
end

local function get_airborne_orientation(velocity: Vector3): CFrame
	local lookDirection = if velocity.Magnitude > MIN_ORIENTATION_SPEED
		then velocity.Unit
		else rootPart.CFrame.LookVector
	local upDirection = Vector3.yAxis
	if math.abs(lookDirection:Dot(upDirection)) > 0.96 then
		upDirection = Vector3.zAxis
	end

	local baseOrientation = CFrame.lookAt(Vector3.zero, lookDirection, upDirection)
	if character:GetAttribute(CART_JUMP_ACTIVE_ATTRIBUTE) == true then
		local jumpPitch = math.clamp(
			velocity.Y / JUMP_ANIMATION_VERTICAL_REFERENCE,
			-1,
			1
		) * JUMP_ASCENT_ANIMATION_ANGLE
		return baseOrientation * CFrame.Angles(jumpPitch, 0, 0)
	end
	local spinProgress = math.clamp(airborneElapsed / activeAirSpinDuration, 0, 1)
	local easedProgress = 1 - (1 - spinProgress) ^ 3
	airSpinAngle = math.pi * 2 * easedProgress
	local rollAngle = math.rad(activeAirRollAngle) * math.sin(airborneElapsed * 8)
	return baseOrientation * CFrame.Angles(0, airSpinAngle, rollAngle)
end

local function update_airborne_orientation(velocity: Vector3): ()
	if slideOrientation then
		slideOrientation.CFrame = get_airborne_orientation(velocity)
	end
end

local function update_airborne_physics(deltaTime: number): ()
	airborneElapsed += deltaTime
	local velocity = rootPart.AssemblyLinearVelocity
	local groundResult = get_ramp_ground(AIRBORNE_GROUND_CHECK_DISTANCE)
	if groundResult
		and airborneElapsed >= MIN_AIRBORNE_TIME
		and velocity:Dot(groundResult.Normal) <= 4
	then
		leave_airborne_state(groundResult)
		return
	end

	local movementInput = humanoid.MoveDirection
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	if movementInput.Magnitude > 0.05 then
		local targetSpeed = math.max(horizontalVelocity.Magnitude, activeLaunchForwardBoost * 0.65)
		local targetVelocity = movementInput.Unit * targetSpeed
		horizontalVelocity = horizontalVelocity:Lerp(
			targetVelocity,
			math.clamp(deltaTime * AIR_STEERING_RESPONSIVENESS, 0, 1)
		)
		rootPart.AssemblyLinearVelocity = Vector3.new(horizontalVelocity.X, velocity.Y, horizontalVelocity.Z)
		velocity = rootPart.AssemblyLinearVelocity
	end

	if slideForce then
		slideForce.Force = Vector3.zero
	end
	update_airborne_orientation(velocity)
end

local function apply_entry_boost(): ()
	local boostSpeed = character:GetAttribute(RAMP_ENTRY_BOOST_SPEED_ATTRIBUTE)
	if type(boostSpeed) ~= "number" or boostSpeed <= 0 then
		return
	end

	local groundResult = get_ramp_ground()
	local groundNormal = if groundResult then groundResult.Normal else Vector3.yAxis
	local forwardDirection = project_onto_plane(rootPart.CFrame.LookVector, groundNormal)
	if forwardDirection.Magnitude > 0 then
		rootPart.AssemblyLinearVelocity += forwardDirection.Unit * boostSpeed
	end
end

local function destroy_slide_actuators(): ()
	if slideOrientation then
		slideOrientation:Destroy()
		slideOrientation = nil
	end
	if slideForce then
		slideForce:Destroy()
		slideForce = nil
	end
	if forceAttachment then
		forceAttachment:Destroy()
		forceAttachment = nil
	end
end

local function enable_slide_state(): ()
	if isSliding then
		return
	end
	isSliding = true
	isAirborne = false
	airborneElapsed = 0
	airSpinAngle = 0
	chargeCFrame = nil
	clear_cart_tilt()
	clear_jump_charge()
	reset_tilt_energy()
	update_cart_configuration()
	apply_entry_boost()
	currentSpeedLimit = math.min(
		Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude,
		activeMaxSlideSpeed
	)

	humanoidDefaults.walkSpeed = humanoid.WalkSpeed
	humanoidDefaults.jumpPower = humanoid.JumpPower
	humanoidDefaults.jumpHeight = humanoid.JumpHeight
	humanoidDefaults.autoRotate = humanoid.AutoRotate
	humanoidDefaults.platformStand = humanoid.PlatformStand
	humanoidDefaults.jumpingEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)

	animateScript = character:FindFirstChild("Animate") :: LocalScript?
	if animateScript and animateScript:IsA("LocalScript") then
		animateWasEnabled = animateScript.Enabled
		animateScript.Enabled = false
	end
	stop_all_animations()
	animationPlayedConnection = animator.AnimationPlayed:Connect(stop_animation_track)

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.Jump = false
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			set_slippery_physics(descendant)
		end
	end

	rootPart.AssemblyAngularVelocity = Vector3.zero
	create_slide_actuators()
	if character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) == AIRBORNE_STATE then
		enter_airborne_state()
	elseif character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) == SLIDE_STATE then
		bind_cart_tilt_action()
		bind_cart_jump_action()
		set_tilt_meter_visible(true)
	end
end

local function disable_slide_state(): ()
	if not isSliding then
		return
	end
	isSliding = false
	isAirborne = false
	airborneElapsed = 0
	airSpinAngle = 0
	chargeCFrame = nil
	clear_cart_tilt()
	clear_jump_charge()
	set_tilt_meter_visible(false)
	unbind_cart_tilt_action()
	unbind_cart_jump_action()

	destroy_slide_actuators()
	restore_physics()
	if animationPlayedConnection then
		animationPlayedConnection:Disconnect()
		animationPlayedConnection = nil
	end
	if animateScript and animateScript.Parent then
		animateScript.Enabled = animateWasEnabled
	end
	animateScript = nil

	if humanoid.Parent and humanoid.Health > 0 then
		humanoid.WalkSpeed = humanoidDefaults.walkSpeed
		humanoid.JumpPower = humanoidDefaults.jumpPower
		humanoid.JumpHeight = humanoidDefaults.jumpHeight
		humanoid.AutoRotate = humanoidDefaults.autoRotate
		humanoid.PlatformStand = humanoidDefaults.platformStand
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, humanoidDefaults.jumpingEnabled)
	end
end

local function update_orientation(velocity: Vector3, groundNormal: Vector3): ()
	if not slideOrientation then
		return
	end

	local surfaceVelocity = project_onto_plane(velocity, groundNormal)
	if surfaceVelocity.Magnitude < MIN_ORIENTATION_SPEED and math.abs(currentTiltAngle) < 0.001 then
		return
	end

	local lookDirection = if surfaceVelocity.Magnitude >= MIN_ORIENTATION_SPEED
		then surfaceVelocity.Unit
		else get_surface_forward(groundNormal)
	local targetOrientation = CFrame.lookAt(Vector3.zero, lookDirection, groundNormal)
	slideOrientation.CFrame = targetOrientation * CFrame.Angles(0, 0, currentTiltAngle)
end

local function update_slide_physics(deltaTime: number): ()
	if not isSliding or not slideForce then
		return
	end
	update_jump_charge_meter()
	if isAirborne then
		update_airborne_physics(deltaTime)
		return
	end
	if character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) == CHARGE_STATE then
		enter_charge_state()
		if chargeCFrame then
			rootPart.CFrame = chargeCFrame
		end
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		slideForce.Force = Vector3.zero
		return
	end

	local groundResult = get_ramp_ground()
	local groundNormal = if groundResult then groundResult.Normal else Vector3.yAxis
	local mass = rootPart.AssemblyMass
	local velocity = rootPart.AssemblyLinearVelocity
	local totalAcceleration = Vector3.new(0, -EXTRA_DOWNWARD_ACCELERATION, 0)
		- groundNormal * SURFACE_ADHESION_ACCELERATION

	local movementInput = project_onto_plane(humanoid.MoveDirection, groundNormal)
	local isTiltSteering: boolean = false
	if groundResult then
		isTiltSteering = update_cart_tilt(deltaTime, groundNormal, movementInput)
	else
		start_cart_tilt_landing()
		update_cart_tilt_animation(deltaTime)
	end
	if movementInput.Magnitude > 0 then
		local steeringAcceleration = activeSteeringAcceleration
		if isTiltSteering then
			steeringAcceleration *= CART_TILT_STEERING_MULTIPLIER
		end
		totalAcceleration += movementInput.Unit * steeringAcceleration
	end

	if groundResult then
		local outwardSpeed = velocity:Dot(groundNormal)
		if outwardSpeed > 0 then
			rootPart.AssemblyLinearVelocity = velocity - groundNormal * outwardSpeed
			velocity = rootPart.AssemblyLinearVelocity
		end
	end

	local accelerationRate = if movementInput.Magnitude > 0
		then activeAcceleration
		else activeCoastingAcceleration
	currentSpeedLimit = math.min(
		currentSpeedLimit + accelerationRate * deltaTime,
		activeMaxSlideSpeed
	)

	local surfaceVelocity = project_onto_plane(velocity, groundNormal)
	if surfaceVelocity.Magnitude > currentSpeedLimit then
		local inwardSpeed = math.min(velocity:Dot(groundNormal), 0)
		velocity = surfaceVelocity.Unit * currentSpeedLimit + groundNormal * inwardSpeed
		rootPart.AssemblyLinearVelocity = velocity
	end

	slideForce.Force = totalAcceleration * mass
	update_orientation(velocity, groundNormal)
end

------------------//MAIN FUNCTIONS
local function update_slide_state(): ()
	if character:GetAttribute(IS_RAMP_SLIDING_ATTRIBUTE) == true then
		enable_slide_state()
	else
		disable_slide_state()
	end
end

local function update_mode_state(): ()
	if not isSliding then
		return
	end

	if character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) == AIRBORNE_STATE
		or character:GetAttribute(RAMP_LAUNCH_ACCEPTED_ATTRIBUTE) == true
	then
		enter_airborne_state()
	elseif character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) == CHARGE_STATE then
		enter_charge_state()
	elseif character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) == SLIDE_STATE then
		if isAirborne then
			local groundResult = get_ramp_ground(AIRBORNE_GROUND_CHECK_DISTANCE)
			if groundResult then
				leave_airborne_state(groundResult)
				return
			end
		end
		bind_cart_tilt_action()
		bind_cart_jump_action()
		set_tilt_meter_visible(true)
	end
end

local function on_character_descendant_added(descendant: Instance): ()
	if isSliding and descendant:IsA("BasePart") then
		set_slippery_physics(descendant)
	end
end

local function on_input_began(input: InputObject): ()
	if not isSliding then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		cartControlRequest:FireServer("Shift")
	elseif input.KeyCode == Enum.KeyCode.Space then
		begin_jump_charge()
	end
end

local function on_input_ended(input: InputObject): ()
	if input.KeyCode == Enum.KeyCode.Space then
		release_jump_charge()
	end
end

local function on_jump_requested(): ()
	begin_jump_charge()
end

------------------//INIT
character:GetAttributeChangedSignal(IS_RAMP_SLIDING_ATTRIBUTE):Connect(update_slide_state)
character:GetAttributeChangedSignal(RAMP_MODE_STATE_ATTRIBUTE):Connect(update_mode_state)
character:GetAttributeChangedSignal(RAMP_LAUNCH_ACCEPTED_ATTRIBUTE):Connect(update_mode_state)
character:GetAttributeChangedSignal(CART_OVERDRIVE_ACTIVE_ATTRIBUTE):Connect(update_overdrive_configuration)
character.DescendantAdded:Connect(on_character_descendant_added)
localPlayer:GetAttributeChangedSignal(EQUIPPED_CART_ATTRIBUTE):Connect(update_cart_configuration)
humanoid.Died:Connect(disable_slide_state)
UserInputService.InputBegan:Connect(on_input_began)
UserInputService.InputEnded:Connect(on_input_ended)
UserInputService.JumpRequest:Connect(on_jump_requested)
script.Destroying:Connect(function()
	clear_cart_tilt()
	clear_jump_charge()
	unbind_cart_tilt_action()
	unbind_cart_jump_action()
	destroy_tilt_meter()
end)
RunService.PreSimulation:Connect(update_slide_physics)
update_cart_configuration()
update_slide_state()

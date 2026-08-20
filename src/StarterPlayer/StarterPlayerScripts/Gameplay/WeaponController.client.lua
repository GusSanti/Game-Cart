------------------//SERVICES
local ContextActionService: ContextActionService = game:GetService("ContextActionService")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local PIN_ANIMATION_NAME: string = "PinAnimation"
local AIM_ANIMATION_NAME: string = "AimAnimation"
local THROW_ANIMATION_NAME: string = "ThrowAnimation"
local PREVIEW_FOLDER_NAME: string = "LocalWeaponPreview"
local LOWER_BODY_JOINT_NAMES: {[string]: boolean} = {
	["Left Hip"] = true,
	LeftHip = true,
	["Right Hip"] = true,
	RightHip = true,
}

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local gameplayModules: Folder = replicatedModules:WaitForChild("Gameplay")
local weaponConfig = require(gameplayModules:WaitForChild("WeaponConfig"))
local projectileUtility = require(gameplayModules:WaitForChild("ProjectileUtility"))

------------------//VARIABLES
type WeaponDefinition = typeof(weaponConfig.definitions.Grenade)

local localPlayer: Player = Players.LocalPlayer
local backpack: Backpack = localPlayer:WaitForChild("Backpack")
local throwRequest: RemoteFunction = ReplicatedStorage:WaitForChild(weaponConfig.remoteName)
local previewFolder = Instance.new("Folder")
local previewSegments: {BasePart} = {}
local targetMarkerSegments: {BasePart} = {}
local observedTools: {[Tool]: {RBXScriptConnection}} = {}
local activeTool: Tool? = nil
local activeDefinition: WeaponDefinition? = nil
local activeCharacter: Model? = nil
local activeAnimator: Animator? = nil
local lowerBodyJoints: {Motor6D} = {}
local pinTrack: AnimationTrack? = nil
local aimTrack: AnimationTrack? = nil
local throwTrack: AnimationTrack? = nil
local aimGeneration: number = 0
local isAiming: boolean = false
local isArmed: boolean = false
local isThrowing: boolean = false
local releaseRequested: boolean = false
local releaseTarget: Vector3? = nil
local aimedTarget: Vector3? = nil
local aimedNormal: Vector3 = Vector3.yAxis

------------------//FUNCTIONS
local function create_preview_part(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = 1
	part.Parent = previewFolder
	return part
end

local function initialize_preview(): ()
	previewFolder.Name = PREVIEW_FOLDER_NAME
	previewFolder.Parent = workspace
	for index = 1, weaponConfig.trajectorySegmentCount do
		table.insert(previewSegments, create_preview_part("Trajectory" .. index))
	end
	for index = 1, 2 do
		table.insert(targetMarkerSegments, create_preview_part("TargetMarker" .. index))
	end
end

local function set_preview_visible(isVisible: boolean): ()
	local transparency = if isVisible then 0 else 1
	for _, part in previewSegments do
		part.Transparency = transparency
	end
	for _, part in targetMarkerSegments do
		part.Transparency = transparency
	end
end

local function set_line_part(part: BasePart, startPosition: Vector3, endPosition: Vector3, thickness: number): ()
	local offset = endPosition - startPosition
	local length = math.max(offset.Magnitude, 0.01)
	part.Size = Vector3.new(thickness, thickness, length)
	part.CFrame = CFrame.lookAt(startPosition:Lerp(endPosition, 0.5), endPosition)
end

local function get_definition_for_tool(tool: Tool): WeaponDefinition?
	local weaponId = tool:GetAttribute(weaponConfig.weaponIdAttribute)
	if type(weaponId) == "string" then
		local definition = weaponConfig.definitions[weaponId]
		if definition then
			return definition
		end
	end
	for _, definition in weaponConfig.definitions do
		if tool.Name == definition.toolName then
			return definition
		end
	end
	return nil
end

local function stop_track(track: AnimationTrack?, fadeTime: number): ()
	if track then
		track:Stop(fadeTime)
	end
end

local function stop_weapon_tracks(fadeTime: number): ()
	stop_track(pinTrack, fadeTime)
	stop_track(aimTrack, fadeTime)
	stop_track(throwTrack, fadeTime)
	pinTrack = nil
	aimTrack = nil
	throwTrack = nil
end

local function load_weapon_track(animationName: string, isLooped: boolean): AnimationTrack?
	local tool = activeTool
	local animator = activeAnimator
	if not tool or not animator then
		return nil
	end
	local animation = tool:FindFirstChild(animationName)
	if not animation or not animation:IsA("Animation") then
		return nil
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = isLooped
	track:SetAttribute(weaponConfig.allowRampAnimationAttribute, true)
	return track
end

local function can_aim(): boolean
	local character = activeCharacter
	local tool = activeTool
	return character ~= nil
		and tool ~= nil
		and tool.Parent == character
		and tool.Enabled
		and character:GetAttribute(weaponConfig.isRampSlidingAttribute) == true
		and character:GetAttribute(weaponConfig.rampModeStateAttribute) ~= weaponConfig.chargeState
end

local function create_aim_raycast_params(character: Model): RaycastParams
	local excludedInstances: {Instance} = {character, previewFolder}
	local projectilesFolder = workspace:FindFirstChild(weaponConfig.projectilesFolderName)
	local trapsFolder = workspace:FindFirstChild(weaponConfig.trapsFolderName)
	if projectilesFolder then
		table.insert(excludedInstances, projectilesFolder)
	end
	if trapsFolder then
		table.insert(excludedInstances, trapsFolder)
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = excludedInstances
	raycastParams.IgnoreWater = true
	return raycastParams
end

local function get_aim_surface(origin: Vector3, definition: WeaponDefinition): (Vector3?, Vector3?)
	local character = activeCharacter
	local camera = workspace.CurrentCamera
	if not character or not camera then
		return nil, nil
	end
	local viewportPoint = UserInputService:GetMouseLocation()
	if UserInputService.GamepadEnabled and not UserInputService.MouseEnabled then
		viewportPoint = camera.ViewportSize * 0.5
	end
	local viewportRay = camera:ViewportPointToRay(viewportPoint.X, viewportPoint.Y)
	local raycastParams = create_aim_raycast_params(character)
	local directResult = workspace:Raycast(
		viewportRay.Origin,
		viewportRay.Direction * weaponConfig.aimRayDistance,
		raycastParams
	)
	local requestedPoint = if directResult
		then directResult.Position
		else viewportRay.Origin + viewportRay.Direction * definition.maxThrowDistance
	local offset = requestedPoint - origin
	if offset.Magnitude > definition.maxThrowDistance then
		requestedPoint = origin + offset.Unit * definition.maxThrowDistance
	end
	local surfaceOrigin = requestedPoint + Vector3.yAxis * weaponConfig.aimSurfaceSearchHeight
	local surfaceResult = workspace:Raycast(
		surfaceOrigin,
		Vector3.yAxis * -weaponConfig.aimSurfaceSearchDistance,
		raycastParams
	)
	if not surfaceResult then
		return nil, nil
	end
	local surfaceOffset = surfaceResult.Position - origin
	if surfaceOffset.Magnitude > definition.maxThrowDistance then
		local clampedPoint = origin + surfaceOffset.Unit * definition.maxThrowDistance
		surfaceResult = workspace:Raycast(
			clampedPoint + Vector3.yAxis * weaponConfig.aimSurfaceSearchHeight,
			Vector3.yAxis * -weaponConfig.aimSurfaceSearchDistance,
			raycastParams
		)
	end
	if not surfaceResult then
		return nil, nil
	end
	return surfaceResult.Position, surfaceResult.Normal
end

local function update_target_marker(target: Vector3, normal: Vector3, color: Color3): ()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local surfaceForward = camera.CFrame.LookVector - normal * camera.CFrame.LookVector:Dot(normal)
	if surfaceForward.Magnitude < 0.01 then
		surfaceForward = normal:Cross(Vector3.xAxis)
	end
	if surfaceForward.Magnitude < 0.01 then
		surfaceForward = normal:Cross(Vector3.zAxis)
	end
	surfaceForward = surfaceForward.Unit
	local surfaceRight = surfaceForward:Cross(normal).Unit
	local halfSize = weaponConfig.targetMarkerSize * 0.5
	local markerCenter = target + normal * weaponConfig.trajectoryThickness
	local diagonalA = (surfaceForward + surfaceRight).Unit * halfSize
	local diagonalB = (surfaceForward - surfaceRight).Unit * halfSize
	set_line_part(targetMarkerSegments[1], markerCenter - diagonalA, markerCenter + diagonalA, weaponConfig.trajectoryThickness * 2)
	set_line_part(targetMarkerSegments[2], markerCenter - diagonalB, markerCenter + diagonalB, weaponConfig.trajectoryThickness * 2)
	for _, part in targetMarkerSegments do
		part.Color = color
	end
end

local function update_trajectory_preview(): ()
	if not isAiming or not activeTool or not activeDefinition then
		set_preview_visible(false)
		return
	end
	local handle = activeTool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		set_preview_visible(false)
		return
	end
	local target, normal = get_aim_surface(handle.Position, activeDefinition)
	if not target or not normal then
		aimedTarget = nil
		set_preview_visible(false)
		return
	end
	aimedTarget = target
	aimedNormal = normal
	local flightDuration = projectileUtility.get_flight_duration(
		handle.Position,
		target,
		activeDefinition.minimumFlightDuration,
		activeDefinition.maximumFlightDuration,
		activeDefinition.maxThrowDistance
	)
	local launchVelocity = projectileUtility.get_launch_velocity(handle.Position, target, flightDuration, workspace.Gravity)
	local previousPosition = handle.Position
	for index, part in previewSegments do
		local elapsed = flightDuration * index / weaponConfig.trajectorySegmentCount
		local position = projectileUtility.get_position(handle.Position, launchVelocity, elapsed, workspace.Gravity)
		set_line_part(part, previousPosition, position, weaponConfig.trajectoryThickness)
		part.Color = activeDefinition.previewColor
		previousPosition = position
	end
	update_target_marker(target, normal, activeDefinition.previewColor)
	set_preview_visible(true)
end

local function play_aim_track(): ()
	if not isAiming then
		return
	end
	aimTrack = load_weapon_track(AIM_ANIMATION_NAME, true)
	if aimTrack then
		aimTrack:Play(0.12)
	end
end

local function clear_aim_state(): ()
	aimGeneration += 1
	isAiming = false
	isArmed = false
	releaseRequested = false
	releaseTarget = nil
	aimedTarget = nil
	stop_track(pinTrack, 0.08)
	stop_track(aimTrack, 0.08)
	pinTrack = nil
	aimTrack = nil
	set_preview_visible(false)
end

local function throw_weapon(target: Vector3): ()
	local tool = activeTool
	local definition = activeDefinition
	if not tool or not definition or isThrowing then
		return
	end
	clear_aim_state()
	isThrowing = true
	tool.Enabled = false
	throwTrack = load_weapon_track(THROW_ANIMATION_NAME, false)
	if throwTrack then
		throwTrack:Play(0.06)
	end
	task.delay(definition.releaseDelay, function()
		if not tool.Parent then
			isThrowing = false
			return
		end
		local success, accepted = pcall(function()
			return throwRequest:InvokeServer(definition.id, target)
		end)
		if tool.Parent and (not success or accepted ~= true) then
			tool.Enabled = true
		end
	end)
	task.delay(definition.throwAnimationDuration, function()
		if activeTool == tool then
			stop_track(throwTrack, 0.1)
			throwTrack = nil
			isThrowing = false
		end
	end)
end

local function request_throw(): ()
	if not isAiming then
		return
	end
	local target = aimedTarget
	if not target then
		clear_aim_state()
		return
	end
	if not isArmed then
		releaseRequested = true
		releaseTarget = target
		set_preview_visible(false)
		return
	end
	throw_weapon(target)
end

local function begin_aim(): ()
	if isAiming or isThrowing or not can_aim() or not activeDefinition then
		return
	end
	aimGeneration += 1
	local generation = aimGeneration
	isAiming = true
	isArmed = not activeDefinition.hasPinAnimation
	releaseRequested = false
	releaseTarget = nil
	if activeDefinition.hasPinAnimation then
		pinTrack = load_weapon_track(PIN_ANIMATION_NAME, false)
		if pinTrack then
			pinTrack:Play(0.08)
		end
	else
		play_aim_track()
	end
	task.delay(activeDefinition.pinDuration, function()
		if generation ~= aimGeneration or not isAiming then
			return
		end
		isArmed = true
		stop_track(pinTrack, 0.08)
		pinTrack = nil
		play_aim_track()
		if releaseRequested and releaseTarget then
			throw_weapon(releaseTarget)
		end
	end)
end

local function on_aim_action(
	_actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		begin_aim()
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		request_throw()
	end
	return Enum.ContextActionResult.Sink
end

local function bind_aim_action(): ()
	ContextActionService:BindActionAtPriority(
		weaponConfig.aimActionName,
		on_aim_action,
		true,
		Enum.ContextActionPriority.High.Value,
		Enum.UserInputType.MouseButton2,
		Enum.KeyCode.ButtonL2
	)
	ContextActionService:SetTitle(weaponConfig.aimActionName, weaponConfig.aimActionTitle)
	ContextActionService:SetPosition(weaponConfig.aimActionName, weaponConfig.aimActionPosition)
end

local function unbind_aim_action(): ()
	ContextActionService:UnbindAction(weaponConfig.aimActionName)
end

local function collect_character_animation_state(character: Model): ()
	activeCharacter = character
	lowerBodyJoints = {}
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	activeAnimator = humanoid and humanoid:FindFirstChildOfClass("Animator") or nil
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and LOWER_BODY_JOINT_NAMES[descendant.Name] then
			table.insert(lowerBodyJoints, descendant)
		end
	end
end

local function on_tool_equipped(tool: Tool): ()
	local character = localPlayer.Character
	local definition = get_definition_for_tool(tool)
	if not character or not definition then
		return
	end
	clear_aim_state()
	stop_weapon_tracks(0)
	activeTool = tool
	activeDefinition = definition
	collect_character_animation_state(character)
	bind_aim_action()
end

local function on_tool_unequipped(tool: Tool): ()
	if activeTool ~= tool then
		return
	end
	clear_aim_state()
	stop_weapon_tracks(0.08)
	unbind_aim_action()
	activeTool = nil
	activeDefinition = nil
	isThrowing = false
end

local function observe_tool(instance: Instance): ()
	if not instance:IsA("Tool") or observedTools[instance] or not get_definition_for_tool(instance) then
		return
	end
	local connections = {
		instance.Equipped:Connect(function()
			on_tool_equipped(instance)
		end),
		instance.Unequipped:Connect(function()
			on_tool_unequipped(instance)
		end),
		instance.Destroying:Connect(function()
			on_tool_unequipped(instance)
			local toolConnections = observedTools[instance]
			if toolConnections then
				for _, connection in toolConnections do
					connection:Disconnect()
				end
			end
			observedTools[instance] = nil
		end),
	}
	observedTools[instance] = connections
	if instance.Parent == localPlayer.Character then
		on_tool_equipped(instance)
	end
end

local function on_character_added(character: Model): ()
	clear_aim_state()
	stop_weapon_tracks(0)
	unbind_aim_action()
	activeTool = nil
	activeDefinition = nil
	isThrowing = false
	collect_character_animation_state(character)
	for _, child in character:GetChildren() do
		observe_tool(child)
	end
	character.ChildAdded:Connect(observe_tool)
end

local function preserve_lower_body_animation(): ()
	if not isAiming and not isThrowing then
		return
	end
	for _, joint in lowerBodyJoints do
		if joint.Parent then
			joint.Transform = CFrame.identity
		end
	end
end

------------------//INIT
initialize_preview()
set_preview_visible(false)

for _, child in backpack:GetChildren() do
	observe_tool(child)
end
backpack.ChildAdded:Connect(observe_tool)

if localPlayer.Character then
	on_character_added(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(on_character_added)
RunService.RenderStepped:Connect(update_trajectory_preview)
RunService.PreSimulation:Connect(preserve_lower_body_animation)

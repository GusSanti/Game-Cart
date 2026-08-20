------------------//SERVICES
local Debris: Debris = game:GetService("Debris")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local GRENADE_WEAPON_ID: string = "Grenade"
local BANANA_WEAPON_ID: string = "Banana"
local EXPLOSION_LIFETIME: number = 2
local BANANA_SURFACE_OFFSET: number = 0.12
local PROJECTILE_ROTATION_SPEED: number = math.rad(720)
local TARGET_TOLERANCE: number = 5
local MAXIMUM_WORLD_COORDINATE: number = 100000

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local gameplayModules: Folder = replicatedModules:WaitForChild("Gameplay")
local weaponConfig = require(gameplayModules:WaitForChild("WeaponConfig"))
local projectileUtility = require(gameplayModules:WaitForChild("ProjectileUtility"))

------------------//VARIABLES
type WeaponDefinition = typeof(weaponConfig.definitions.Grenade)
type ActiveProjectile = {
	part: BasePart,
	definition: WeaponDefinition,
	owner: Player,
	origin: Vector3,
	target: Vector3,
	targetNormal: Vector3,
	launchVelocity: Vector3,
	flightDuration: number,
	startedAt: number,
	referenceDirection: Vector3,
}

local assets: Folder = ReplicatedStorage:WaitForChild("Assets")
local weaponsFolder: Folder = assets:WaitForChild(weaponConfig.weaponsFolderName)
local projectileTemplatesFolder: Folder = weaponsFolder:WaitForChild(weaponConfig.projectileTemplatesFolderName)
local projectilesFolder: Folder
local trapsFolder: Folder
local throwRequest: RemoteFunction
local activeProjectiles: {[BasePart]: ActiveProjectile} = {}
local lastThrowAtByPlayer: {[Player]: number} = {}

------------------//FUNCTIONS
local function ensure_folder(parent: Instance, folderName: string): Folder
	local existingFolder = parent:FindFirstChild(folderName)
	if existingFolder then
		if not existingFolder:IsA("Folder") then
			error(("%s precisa ser uma Folder"):format(existingFolder:GetFullName()))
		end
		return existingFolder
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = folderName
	newFolder.Parent = parent
	return newFolder
end

local function ensure_throw_request(): RemoteFunction
	local existingRemote = ReplicatedStorage:FindFirstChild(weaponConfig.remoteName)
	if existingRemote then
		if not existingRemote:IsA("RemoteFunction") then
			error(("%s precisa ser uma RemoteFunction"):format(existingRemote:GetFullName()))
		end
		return existingRemote
	end

	local newRemote = Instance.new("RemoteFunction")
	newRemote.Name = weaponConfig.remoteName
	newRemote.Parent = ReplicatedStorage
	return newRemote
end

local function is_finite_vector(value: unknown): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	return value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) <= MAXIMUM_WORLD_COORDINATE
		and math.abs(value.Y) <= MAXIMUM_WORLD_COORDINATE
		and math.abs(value.Z) <= MAXIMUM_WORLD_COORDINATE
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

local function get_equipped_tool(character: Model, weaponId: string): (Tool?, WeaponDefinition?)
	for _, child in character:GetChildren() do
		if not child:IsA("Tool") then
			continue
		end
		local definition = get_definition_for_tool(child)
		if definition and definition.id == weaponId then
			return child, definition
		end
	end
	return nil, nil
end

local function get_throw_origin(character: Model, tool: Tool): (Vector3?, Vector3?)
	local handle = tool:FindFirstChild("Handle")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not handle or not handle:IsA("BasePart") or not rootPart or not rootPart:IsA("BasePart") then
		return nil, nil
	end
	return handle.Position, rootPart.CFrame.LookVector
end

local function create_target_raycast_params(character: Model): RaycastParams
	local excludedInstances: {Instance} = {character, projectilesFolder, trapsFolder}
	for _, player in Players:GetPlayers() do
		local playerCharacter = player.Character
		if playerCharacter and playerCharacter ~= character then
			table.insert(excludedInstances, playerCharacter)
		end
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = excludedInstances
	raycastParams.IgnoreWater = true
	return raycastParams
end

local function validate_target(
	character: Model,
	origin: Vector3,
	requestedTarget: Vector3,
	definition: WeaponDefinition
): (Vector3?, Vector3?)
	if (requestedTarget - origin).Magnitude > definition.maxThrowDistance + TARGET_TOLERANCE then
		return nil, nil
	end

	local raycastParams = create_target_raycast_params(character)
	local rayOrigin = requestedTarget + Vector3.yAxis * weaponConfig.aimSurfaceSearchHeight
	local rayDirection = Vector3.yAxis * -weaponConfig.aimSurfaceSearchDistance
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if not result or (result.Position - origin).Magnitude > definition.maxThrowDistance + TARGET_TOLERANCE then
		return nil, nil
	end
	return result.Position, result.Normal
end

local function configure_projectile_part(part: BasePart, weaponId: string): ()
	part.Name = weaponId .. "Projectile"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
	part.Parent = projectilesFolder
end

local function create_projectile_part(tool: Tool, definition: WeaponDefinition): BasePart?
	local sourcePart: Instance?
	if definition.id == BANANA_WEAPON_ID then
		sourcePart = projectileTemplatesFolder:FindFirstChild(weaponConfig.bananaProjectileTemplateName)
	else
		sourcePart = tool:FindFirstChild("Handle")
	end
	if not sourcePart or not sourcePart:IsA("BasePart") then
		return nil
	end

	local projectile = sourcePart:Clone()
	configure_projectile_part(projectile, definition.id)
	return projectile
end

local function apply_external_launch(character: Model, launchVelocity: Vector3): ()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local currentSequence = character:GetAttribute(weaponConfig.externalLaunchSequenceAttribute)
	local nextSequence = if type(currentSequence) == "number" then currentSequence + 1 else 1
	character:SetAttribute(weaponConfig.rampAirborneVelocityAttribute, launchVelocity)
	character:SetAttribute(weaponConfig.cartJumpActiveAttribute, false)
	character:SetAttribute(weaponConfig.externalLaunchSequenceAttribute, nextSequence)
	character:SetAttribute(weaponConfig.rampModeStateAttribute, weaponConfig.airborneState)
	rootPart.AssemblyLinearVelocity = launchVelocity
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

local function detonate_grenade(projectile: ActiveProjectile): ()
	local explosion = Instance.new("Explosion")
	explosion.Position = projectile.target
	explosion.BlastRadius = projectile.definition.blastRadius
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace
	Debris:AddItem(explosion, EXPLOSION_LIFETIME)

	for _, player in Players:GetPlayers() do
		if player == projectile.owner then
			continue
		end
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not character
			or character:GetAttribute(weaponConfig.isRampSlidingAttribute) ~= true
			or not rootPart
			or not rootPart:IsA("BasePart")
			or (rootPart.Position - projectile.target).Magnitude > projectile.definition.blastRadius
		then
			continue
		end

		local horizontalDirection = Vector3.new(
			rootPart.Position.X - projectile.target.X,
			0,
			rootPart.Position.Z - projectile.target.Z
		)
		if horizontalDirection.Magnitude < 0.01 then
			horizontalDirection = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
		end
		if horizontalDirection.Magnitude < 0.01 then
			horizontalDirection = Vector3.zAxis
		end
		local launchVelocity = horizontalDirection.Unit * projectile.definition.horizontalKnockbackSpeed
			+ Vector3.yAxis * projectile.definition.verticalKnockbackSpeed
		apply_external_launch(character, launchVelocity)
	end
end

local function get_player_from_hit(hitPart: BasePart): (Player?, Model?)
	local character = hitPart:FindFirstAncestorOfClass("Model")
	if not character then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player or player.Character ~= character then
		return nil, nil
	end
	return player, character
end

local function activate_banana_trap(projectile: ActiveProjectile): ()
	local trap = projectile.part
	trap.Name = weaponConfig.bananaProjectileTemplateName
	trap.CFrame = projectileUtility.get_surface_cframe(
		projectile.target + projectile.targetNormal * BANANA_SURFACE_OFFSET,
		projectile.targetNormal,
		projectile.referenceDirection
	)
	trap.CanTouch = true
	trap.Parent = trapsFolder
	trap:SetAttribute("OwnerUserId", projectile.owner.UserId)

	local triggered = false
	trap.Touched:Connect(function(hitPart: BasePart)
		if triggered then
			return
		end
		local player, character = get_player_from_hit(hitPart)
		if not player
			or not character
			or player.UserId == projectile.owner.UserId
			or character:GetAttribute(weaponConfig.isRampSlidingAttribute) ~= true
		then
			return
		end

		triggered = true
		local currentTime = workspace:GetServerTimeNow()
		local currentSpinUntil = character:GetAttribute(weaponConfig.spinUntilAttribute)
		local spinUntil = currentTime + projectile.definition.spinDuration
		if type(currentSpinUntil) == "number" then
			spinUntil = math.max(spinUntil, currentSpinUntil)
		end
		character:SetAttribute(weaponConfig.spinUntilAttribute, spinUntil)
		trap:Destroy()
	end)

	task.delay(projectile.definition.trapLifetime, function()
		if trap.Parent then
			trap:Destroy()
		end
	end)
end

local function settle_projectile(projectile: ActiveProjectile): ()
	activeProjectiles[projectile.part] = nil
	if projectile.definition.id == GRENADE_WEAPON_ID then
		detonate_grenade(projectile)
		projectile.part:Destroy()
	elseif projectile.definition.id == BANANA_WEAPON_ID then
		activate_banana_trap(projectile)
	else
		projectile.part:Destroy()
	end
end

local function update_projectiles(): ()
	local currentTime = workspace:GetServerTimeNow()
	for part, projectile in activeProjectiles do
		if not part.Parent then
			activeProjectiles[part] = nil
			continue
		end

		local elapsed = currentTime - projectile.startedAt
		if elapsed >= projectile.flightDuration then
			part.CFrame = CFrame.new(projectile.target)
			settle_projectile(projectile)
			continue
		end

		local position = projectileUtility.get_position(
			projectile.origin,
			projectile.launchVelocity,
			elapsed,
			workspace.Gravity
		)
		local currentVelocity = projectile.launchVelocity + Vector3.new(0, -workspace.Gravity * elapsed, 0)
		local lookDirection = if currentVelocity.Magnitude > 0.01 then currentVelocity.Unit else projectile.referenceDirection
		part.CFrame = CFrame.lookAt(position, position + lookDirection)
			* CFrame.Angles(0, 0, elapsed * PROJECTILE_ROTATION_SPEED)
	end
end

local function player_has_tool(player: Player, toolName: string): boolean
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	return (character and character:FindFirstChild(toolName) ~= nil)
		or (backpack and backpack:FindFirstChild(toolName) ~= nil)
end

local function clone_tool_to_parent(toolTemplate: Tool, parent: Instance): ()
	if parent:FindFirstChild(toolTemplate.Name) then
		return
	end
	local toolClone = toolTemplate:Clone()
	toolClone.CanBeDropped = false
	toolClone.Parent = parent
end

local function grant_weapons(player: Player): ()
	local backpack = player:WaitForChild("Backpack")
	local starterGear = player:WaitForChild("StarterGear")
	for _, definition in weaponConfig.definitions do
		local toolTemplate = weaponsFolder:FindFirstChild(definition.toolName)
		if not toolTemplate or not toolTemplate:IsA("Tool") then
			continue
		end
		clone_tool_to_parent(toolTemplate, starterGear)
		if not player_has_tool(player, toolTemplate.Name) then
			clone_tool_to_parent(toolTemplate, backpack)
		end
	end
end

local function on_throw_request(player: Player, weaponId: unknown, requestedTarget: unknown): boolean
	if type(weaponId) ~= "string" or not is_finite_vector(requestedTarget) then
		return false
	end
	local definition = weaponConfig.definitions[weaponId]
	local character = player.Character
	if not definition
		or not character
		or character:GetAttribute(weaponConfig.isRampSlidingAttribute) ~= true
		or character:GetAttribute(weaponConfig.rampModeStateAttribute) == weaponConfig.chargeState
	then
		return false
	end

	local currentTime = workspace:GetServerTimeNow()
	local lastThrowAt = lastThrowAtByPlayer[player] or -math.huge
	if currentTime - lastThrowAt < definition.cooldownDuration then
		return false
	end

	local tool, equippedDefinition = get_equipped_tool(character, weaponId)
	if not tool or not equippedDefinition or tool.Enabled ~= true then
		return false
	end
	local origin, referenceDirection = get_throw_origin(character, tool)
	if not origin or not referenceDirection then
		return false
	end

	local target, targetNormal = validate_target(character, origin, requestedTarget, definition)
	if not target or not targetNormal then
		return false
	end
	local projectilePart = create_projectile_part(tool, definition)
	if not projectilePart then
		return false
	end

	lastThrowAtByPlayer[player] = currentTime
	tool.Enabled = false
	tool:Destroy()
	local flightDuration = projectileUtility.get_flight_duration(
		origin,
		target,
		definition.minimumFlightDuration,
		definition.maximumFlightDuration,
		definition.maxThrowDistance
	)
	local launchVelocity = projectileUtility.get_launch_velocity(origin, target, flightDuration, workspace.Gravity)
	projectilePart.CFrame = CFrame.new(origin)
	activeProjectiles[projectilePart] = {
		part = projectilePart,
		definition = definition,
		owner = player,
		origin = origin,
		target = target,
		targetNormal = targetNormal,
		launchVelocity = launchVelocity,
		flightDuration = flightDuration,
		startedAt = currentTime,
		referenceDirection = referenceDirection,
	}
	return true
end

local function on_player_added(player: Player): ()
	task.spawn(grant_weapons, player)
end

local function on_player_removing(player: Player): ()
	lastThrowAtByPlayer[player] = nil
end

------------------//INIT
projectilesFolder = ensure_folder(workspace, weaponConfig.projectilesFolderName)
trapsFolder = ensure_folder(workspace, weaponConfig.trapsFolderName)
throwRequest = ensure_throw_request()
throwRequest.OnServerInvoke = on_throw_request

for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(on_player_removing)
RunService.Heartbeat:Connect(update_projectiles)

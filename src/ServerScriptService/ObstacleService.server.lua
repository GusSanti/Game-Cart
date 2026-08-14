------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local GENERATED_OBSTACLES_FOLDER_NAME: string = "GeneratedObstacles"
local GENERATED_COLLECTIBLES_FOLDER_NAME: string = "GeneratedCollectibles"
local OBSTACLES_FOLDER_NAME: string = "Obstacles"
local MISC_FOLDER_NAME: string = "Misc"
local COIN_TEMPLATE_NAME: string = "Coin"
local COIN_HITBOX_NAME: string = "CoinCollectHitbox"
local ASSETS_FOLDER_NAME: string = "Assets"
local CHARACTERS_FOLDER_NAME: string = "Characters"
local IMPACT_FEEDBACK_REMOTE_NAME: string = "CartImpactFeedback"
local IS_RAMP_SLIDING_ATTRIBUTE: string = "IsRampSliding"
local RAMP_WORLD_ATTRIBUTE: string = "RampWorld"
local CART_MAX_HEALTH_ATTRIBUTE: string = "CartMaxHealth"
local CART_HEALTH_ATTRIBUTE: string = "CartHealth"
local CART_LAST_IMPACT_ATTRIBUTE: string = "CartLastImpactAt"
local CART_FLOW_ATTRIBUTE: string = "CartFlow"
local CART_FLOW_MAXIMUM_ATTRIBUTE: string = "CartFlowMaximum"
local CART_OVERDRIVE_ACTIVE_ATTRIBUTE: string = "CartOverdriveActive"
local GENERATED_WORLD_ATTRIBUTE: string = "World"
local OBSTACLE_DAMAGE_ATTRIBUTE: string = "Damage"
local OBSTACLE_SCALE_ATTRIBUTE: string = "SpawnScale"
local OBSTACLE_COOLDOWN_ATTRIBUTE: string = "IsImpactCoolingDown"
local OBSTACLE_DESPAWNING_ATTRIBUTE: string = "IsDespawning"
local COIN_COLLECTED_ATTRIBUTE: string = "IsCollected"
local COIN_SURFACE_RIGHT_ATTRIBUTE: string = "CoinSurfaceRight"
local COIN_SURFACE_UP_ATTRIBUTE: string = "CoinSurfaceUp"
local COIN_REWARD_ATTRIBUTE: string = "Reward"
local COIN_FLOW_REWARD_ATTRIBUTE: string = "FlowReward"
local COIN_RISK_ATTRIBUTE: string = "IsRiskCoin"
local COIN_CHAIN_ID_ATTRIBUTE: string = "ChainId"
local COIN_CHAIN_ORDER_ATTRIBUTE: string = "ChainOrder"
local COIN_CHAIN_LENGTH_ATTRIBUTE: string = "ChainLength"
local COIN_CHAIN_BONUS_ATTRIBUTE: string = "ChainBonus"
local WAVE_ID_ATTRIBUTE: string = "WaveId"
local WAVE_SEED_ATTRIBUTE: string = "WaveSeed"
local LANE_MULTIPLIERS: {number} = {-0.82, -0.4, 0, 0.4, 0.82}
local WAVE_TRANSITION_DELAY: number = 2.5
local WAVE_SPAWN_DURATION: number = 0.45
local WAVE_DESPAWN_DURATION: number = 0.3
local PENDING_OBSTACLE_SPAWN_INTERVAL: number = 0.1
local PENDING_OBSTACLE_SPAWN_DISTANCE: number = 230
local PENDING_OBSTACLE_BACKTRACK_DISTANCE: number = 18
local MAX_PENDING_OBSTACLE_SPAWNS_PER_UPDATE: number = 12
local OBSTACLE_COOLDOWN_DURATION: number = 0.9
local DAMAGE_COOLDOWN_DURATION: number = 1.1
local COIN_SAVE_BATCH_DELAY: number = 0.35
local OBSTACLE_FLASH_TRANSPARENCY: number = 0.78
local OBSTACLE_FLASH_DURATION: number = 0.1
local OBSTACLE_FLASH_COUNT: number = 3
local SPAWN_SIZE_SCALE: number = 0.15
local COIN_COLLECT_SIZE_SCALE: number = 0.1
local SPAWN_TRANSPARENCY: number = 0.2
local TARGET_ENCOUNTER_LENGTH: number = 86
local MINIMUM_ENCOUNTERS_PER_RAMP_PART: number = 4
local MAXIMUM_ENCOUNTERS_PER_RAMP_PART: number = 28
local OBSTACLE_LONGITUDINAL_JITTER_MULTIPLIER: number = 0.04
local OBSTACLE_LATERAL_JITTER_MULTIPLIER: number = 0.055
local MAX_OBSTACLES_PER_WAVE: number = 700
local OBSTACLE_CLUSTER_COUNT: number = 2
local OBSTACLE_CLUSTER_SPACING_MULTIPLIER: number = 0.55
local JUMP_GATE_CLUSTER_COUNT: number = 5
local WIDE_TEMPLATE_SMALL_WEIGHT_FACTOR: number = 0.12
local WIDE_TEMPLATE_MINIMUM_WIDTH: number = 20
local MINIMUM_OBSTACLE_SCALE: number = 0.78
local MAXIMUM_OBSTACLE_SCALE: number = 2.25
local SOFT_OBSTACLE_MAXIMUM_SCALE: number = 0.94
local HEAVY_OBSTACLE_MINIMUM_SCALE: number = 1.8
local JUMP_GATE_MAXIMUM_TEMPLATE_HEIGHT: number = 7.5
local DEFAULT_OBSTACLE_DAMAGE: number = 1
local SOFT_IMPACT_SPEED_RETENTION: number = 0.72
local NORMAL_IMPACT_SPEED_RETENTION: number = 0.56
local HEAVY_IMPACT_SPEED_RETENTION: number = 0.42
local MINIMUM_RAMP_LENGTH: number = 180
local ENTRY_SAFE_DISTANCE: number = 115
local EXIT_SAFE_DISTANCE: number = 50
local EDGE_SAFE_DISTANCE: number = 32
local SURFACE_RAYCAST_HEIGHT: number = 80
local SURFACE_RAYCAST_DISTANCE: number = 180
local SURFACE_CLEARANCE: number = 0.04
local COIN_SURFACE_CLEARANCE: number = 1.25
local COIN_UPRIGHT_ANGLE: number = math.rad(90)
local MINIMUM_COINS_PER_CHAIN: number = 4
local MAXIMUM_COINS_PER_CHAIN: number = 7
local COIN_CHAIN_SEGMENT_INTERVAL: number = 2
local COIN_CHAIN_START_PADDING: number = 9
local COIN_MAX_CURVE_OFFSET: number = 12
local COIN_MINIMUM_SCALE: number = 1.65
local COIN_MAXIMUM_SCALE: number = 2.25
local COIN_COLLECTION_SIZE_MULTIPLIER: number = 1.35
local COIN_COLLECTION_DEPTH: number = 6
local COIN_SAFE_REWARD: number = 1
local COIN_RISK_REWARD: number = 2
local COIN_GOLD_REWARD: number = 5
local COIN_SAFE_CHAIN_BONUS: number = 2
local COIN_RISK_CHAIN_BONUS: number = 4
local COIN_JUMP_CHAIN_BONUS: number = 5
local JUMP_COIN_ARC_HEIGHT: number = 10
local PATTERN_SLALOM: string = "Slalom"
local PATTERN_FORK: string = "Fork"
local PATTERN_CHICANE: string = "Chicane"
local PATTERN_JUMP_GATE: string = "JumpGate"
local PATTERN_BREATHER: string = "Breather"

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local rampUtility = require(replicatedModules:WaitForChild("Gameplay"):WaitForChild("RampUtility"))
local cartGameplayConfig = require(replicatedModules:WaitForChild("Gameplay"):WaitForChild("CartGameplayConfig"))
local dataUtility = require(replicatedModules:WaitForChild("Data"):WaitForChild("DataUtility"))

------------------//VARIABLES
type ConnectionSet = {RBXScriptConnection}
type TransparencyMap = {[BasePart]: number}
type SegmentLayout = {
	rampPart: BasePart,
	startDistance: number,
	endDistance: number,
	lateralRange: number,
	entryLaneIndex: number,
	safeLaneIndex: number,
	rewardLaneIndex: number,
	patternName: string,
}
type PatternRow = {
	distanceAlpha: number,
	openLaneIndices: {number},
	scaleMinimum: number,
	scaleMaximum: number,
	damageOverride: number?,
}
type PendingObstacleSpawn = {
	template: Instance,
	spawnCFrame: CFrame,
	waveId: number,
	obstacleScale: number,
	damage: number,
	isRollingBarrel: boolean,
}
type CoinChainState = {
	chainId: string,
	nextOrder: number,
}

local generatedObstaclesFolder: Folder
local generatedCollectiblesFolder: Folder
local charactersFolder: Folder
local impactFeedback: RemoteEvent
local currentWaveByWorld: {[number]: Folder} = {}
local currentCollectibleWaveByWorld: {[number]: Folder} = {}
local pendingObstacleSpawnsByWorld: {[number]: {PendingObstacleSpawn}} = {}
local activeRidersByWorld: {[number]: number} = {}
local activeWorldByCharacter: {[Model]: number} = {}
local waveNumberByWorld: {[number]: number} = {}
local pendingWaveByWorld: {[number]: boolean} = {}
local waveGenerationByWorld: {[number]: boolean} = {}
local lastDamageAtByCharacter: {[Model]: number} = {}
local damagedCharactersByObstacle: {[Instance]: {[Model]: boolean}} = {}
local obstacleConnections: {[Instance]: ConnectionSet} = {}
local coinConnections: {[BasePart]: ConnectionSet} = {}
local characterConnections: {[Model]: ConnectionSet} = {}
local trackedCharacters: {[Model]: boolean} = {}
local pendingCoinRewardsByPlayer: {[Player]: number} = {}
local coinSaveScheduledByPlayer: {[Player]: boolean} = {}
local coinChainStateByPlayer: {[Player]: CoinChainState} = {}
local pendingObstacleSpawnElapsed: number = 0

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

local function ensure_impact_feedback_remote(): RemoteEvent
	local existingRemote = ReplicatedStorage:FindFirstChild(IMPACT_FEEDBACK_REMOTE_NAME)
	if existingRemote then
		if not existingRemote:IsA("RemoteEvent") then
			error(("%s precisa ser um RemoteEvent"):format(existingRemote:GetFullName()))
		end
		return existingRemote
	end

	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = IMPACT_FEEDBACK_REMOTE_NAME
	newRemote.Parent = ReplicatedStorage
	return newRemote
end

local function get_positive_integer_attribute(instance: Instance, attributeName: string): number?
	local value = instance:GetAttribute(attributeName)
	if type(value) ~= "number" or value <= 0 or value ~= value or value == math.huge then
		return nil
	end

	return math.max(math.floor(value), 1)
end

local function get_nonnegative_integer_attribute(instance: Instance, attributeName: string): number?
	local value = instance:GetAttribute(attributeName)
	if type(value) ~= "number" or value < 0 or value ~= value or value == math.huge then
		return nil
	end

	return math.max(math.floor(value), 0)
end

local function add_character_flow(character: Model, flowReward: number): ()
	if flowReward <= 0 or character:GetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE) == true then
		return
	end

	local currentFlow = character:GetAttribute(CART_FLOW_ATTRIBUTE)
	local maximumFlow = character:GetAttribute(CART_FLOW_MAXIMUM_ATTRIBUTE)
	if type(currentFlow) ~= "number" or type(maximumFlow) ~= "number" or maximumFlow <= 0 then
		return
	end

	character:SetAttribute(CART_FLOW_ATTRIBUTE, math.clamp(currentFlow + flowReward, 0, maximumFlow))
end

local function get_world_folder(rootFolder: Folder, worldId: number): Folder
	return ensure_folder(rootFolder, ("World%d"):format(worldId))
end

local function is_obstacle_instance(instance: Instance): boolean
	return instance:IsA("BasePart") or instance:IsA("Model")
end

local function get_instance_bounds(instance: Instance): (CFrame, Vector3)
	if instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end
	if instance:IsA("Model") then
		return instance:GetBoundingBox()
	end

	error(("%s nao pode ser usado como obstaculo"):format(instance:GetFullName()))
end

local function get_obstacle_parts(obstacle: Instance): {BasePart}
	local parts: {BasePart} = {}
	if obstacle:IsA("BasePart") then
		table.insert(parts, obstacle)
	end
	for _, descendant in obstacle:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function remove_obstacle_scripts(obstacle: Instance): ()
	for _, descendant in obstacle:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
end

local function get_obstacle_templates(): {Instance}
	local assets = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
	local obstacles = assets:WaitForChild(OBSTACLES_FOLDER_NAME)
	local templates: {Instance} = {}

	for _, template in obstacles:GetChildren() do
		local duplicateBarrelPart = template:IsA("BasePart")
			and (string.find(string.lower(template.Name), "barrel", 1, true) ~= nil
				or string.find(string.lower(template.Name), "barril", 1, true) ~= nil)
			and obstacles:FindFirstChild(template.Name)
			and obstacles:FindFirstChild(template.Name):IsA("Model")
		if is_obstacle_instance(template) and not duplicateBarrelPart then
			table.insert(templates, template)
		end
	end

	return templates
end

local function get_coin_template(): BasePart?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	local misc = assets and assets:FindFirstChild(MISC_FOLDER_NAME)
	local coin = misc and misc:FindFirstChild(COIN_TEMPLATE_NAME)
	if coin and coin:IsA("BasePart") then
		return coin
	end

	return nil
end

local function get_template_weight(template: Instance, prefersWideTemplate: boolean): number
	local weight = template:GetAttribute("SpawnWeight")
	if type(weight) ~= "number" or weight <= 0 or weight ~= weight or weight == math.huge then
		weight = 1
	end

	local _, templateSize = get_instance_bounds(template)
	local partCount = #get_obstacle_parts(template)
	local complexityFactor = if partCount > 16
		then 0.06
		elseif partCount > 6 then 0.2
		elseif partCount > 3 then 0.5
		else 1
	weight *= complexityFactor
	if prefersWideTemplate and math.max(templateSize.X, templateSize.Z) < WIDE_TEMPLATE_MINIMUM_WIDTH then
		return weight * WIDE_TEMPLATE_SMALL_WEIGHT_FACTOR
	end

	return weight
end

local function select_template(random: Random, templates: {Instance}, prefersWideTemplate: boolean): Instance?
	local totalWeight: number = 0
	for _, template in templates do
		totalWeight += get_template_weight(template, prefersWideTemplate)
	end
	if totalWeight <= 0 then
		return nil
	end

	local selection = random:NextNumber(0, totalWeight)
	local currentWeight: number = 0
	for _, template in templates do
		currentWeight += get_template_weight(template, prefersWideTemplate)
		if selection <= currentWeight then
			return template
		end
	end

	return templates[#templates]
end

local function select_jump_gate_template(random: Random, templates: {Instance}): Instance?
	local jumpTemplates: {Instance} = {}
	for _, template in templates do
		local _, templateSize = get_instance_bounds(template)
		if #get_obstacle_parts(template) <= 3 and templateSize.Y <= JUMP_GATE_MAXIMUM_TEMPLATE_HEIGHT then
			table.insert(jumpTemplates, template)
		end
	end

	return select_template(random, if #jumpTemplates > 0 then jumpTemplates else templates, true)
end

local function get_downhill_direction(rampPart: BasePart, surfaceNormal: Vector3): Vector3
	local tangent = rampPart.CFrame.UpVector - surfaceNormal * rampPart.CFrame.UpVector:Dot(surfaceNormal)
	if tangent.Magnitude < 0.01 then
		tangent = rampPart.CFrame.RightVector - surfaceNormal * rampPart.CFrame.RightVector:Dot(surfaceNormal)
	end
	if tangent.Magnitude < 0.01 then
		return Vector3.zAxis
	end

	if tangent.Y > 0 then
		tangent = -tangent
	end
	return tangent.Unit
end

local function get_surface_cframe(
	rampPart: BasePart,
	localY: number,
	lateralOffset: number,
	verticalOffset: number
): (CFrame?, Vector3?)
	local probePosition = rampPart.CFrame:PointToWorldSpace(Vector3.new(lateralOffset, localY, 0))
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = {rampPart}
	local surfaceResult = workspace:Raycast(
		probePosition + Vector3.yAxis * SURFACE_RAYCAST_HEIGHT,
		-Vector3.yAxis * SURFACE_RAYCAST_DISTANCE,
		raycastParams
	)
	if not surfaceResult then
		return nil, nil
	end

	local surfaceNormal = surfaceResult.Normal
	local downhillDirection = get_downhill_direction(rampPart, surfaceNormal)
	local spawnPosition = surfaceResult.Position + surfaceNormal * verticalOffset
	return CFrame.lookAt(spawnPosition, spawnPosition + downhillDirection, surfaceNormal), spawnPosition
end

local function get_ramp_parts(worldId: number): {BasePart}
	local rampParts: {BasePart} = {}
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart")
			and rampUtility.is_ramp(descendant)
			and rampUtility.get_world_id(descendant) == worldId
		then
			table.insert(rampParts, descendant)
		end
	end
	return rampParts
end

local function get_ramp_world_ids(): {[number]: boolean}
	local worldIds: {[number]: boolean} = {}
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") and rampUtility.is_ramp(descendant) then
			worldIds[rampUtility.get_world_id(descendant)] = true
		end
	end
	return worldIds
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

local function set_obstacle_interaction(obstacle: Instance, canCollide: boolean, canTouch: boolean, canQuery: boolean): ()
	for _, part in get_obstacle_parts(obstacle) do
		part.Anchored = true
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		part.CanCollide = canCollide
		part.CanTouch = canTouch
		part.CanQuery = canQuery
	end
end

local function get_obstacle_transparency(obstacle: Instance): TransparencyMap
	local transparencyByPart: TransparencyMap = {}
	for _, part in get_obstacle_parts(obstacle) do
		transparencyByPart[part] = part.Transparency
	end
	return transparencyByPart
end

local function tween_obstacle_transparency(
	obstacle: Instance,
	targetTransparency: number | TransparencyMap,
	duration: number,
	easingStyle: Enum.EasingStyle,
	easingDirection: Enum.EasingDirection
): ()
	for _, part in get_obstacle_parts(obstacle) do
		local target = if type(targetTransparency) == "number"
			then targetTransparency
			else targetTransparency[part] or part.Transparency
		local transparencyTween = TweenService:Create(
			part,
			TweenInfo.new(duration, easingStyle, easingDirection),
			{Transparency = target}
		)
		transparencyTween:Play()
	end
end

local function get_obstacle_pivot_for_bounds(obstacle: Instance, targetBoundsCFrame: CFrame): CFrame
	if obstacle:IsA("BasePart") then
		return targetBoundsCFrame
	end
	if obstacle:IsA("Model") then
		local boundingCFrame = obstacle:GetBoundingBox()
		local boundsFromPivot = obstacle:GetPivot():ToObjectSpace(boundingCFrame)
		return targetBoundsCFrame * boundsFromPivot:Inverse()
	end

	return targetBoundsCFrame
end

local function disconnect_obstacle(obstacle: Instance): ()
	local connections = obstacleConnections[obstacle]
	if not connections then
		return
	end

	for _, connection in connections do
		connection:Disconnect()
	end
	obstacleConnections[obstacle] = nil
	damagedCharactersByObstacle[obstacle] = nil
end

local function disconnect_coin(coin: BasePart): ()
	local connections = coinConnections[coin]
	if not connections then
		return
	end

	for _, connection in connections do
		connection:Disconnect()
	end
	coinConnections[coin] = nil
end

local function flush_pending_coin_rewards(player: Player): ()
	coinSaveScheduledByPlayer[player] = nil
	local pendingReward = pendingCoinRewardsByPlayer[player] or 0
	pendingCoinRewardsByPlayer[player] = nil
	if pendingReward <= 0 then
		return
	end

	local savedCoins = dataUtility.server.get(player, "Coins")
	if type(savedCoins) ~= "number" or savedCoins < 0 then
		return
	end

	local visibleCoins = player:GetAttribute("Coins")
	local updatedCoins = savedCoins + pendingReward
	if type(visibleCoins) == "number" then
		updatedCoins = math.max(updatedCoins, visibleCoins)
	end
	dataUtility.server.set(player, "Coins", updatedCoins)
end

local function award_coin(player: Player, rewardValue: number): ()
	if rewardValue <= 0 then
		return
	end

	local visibleCoins = player:GetAttribute("Coins")
	if type(visibleCoins) ~= "number" then
		local savedCoins = dataUtility.server.get(player, "Coins")
		visibleCoins = if type(savedCoins) == "number" then savedCoins else 0
	end

	player:SetAttribute("Coins", visibleCoins + rewardValue)
	pendingCoinRewardsByPlayer[player] = (pendingCoinRewardsByPlayer[player] or 0) + rewardValue
	if coinSaveScheduledByPlayer[player] then
		return
	end

	coinSaveScheduledByPlayer[player] = true
	task.delay(COIN_SAVE_BATCH_DELAY, function()
		flush_pending_coin_rewards(player)
	end)
end

local function begin_obstacle_cooldown(obstacle: Instance): ()
	if obstacle:GetAttribute(OBSTACLE_COOLDOWN_ATTRIBUTE) == true then
		return
	end

	local originalTransparency = get_obstacle_transparency(obstacle)
	obstacle:SetAttribute(OBSTACLE_COOLDOWN_ATTRIBUTE, true)
	set_obstacle_interaction(obstacle, false, false, false)

	task.spawn(function()
		for _ = 1, OBSTACLE_FLASH_COUNT do
			tween_obstacle_transparency(
				obstacle,
				OBSTACLE_FLASH_TRANSPARENCY,
				OBSTACLE_FLASH_DURATION,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
			task.wait(OBSTACLE_FLASH_DURATION)
			if not obstacle.Parent or obstacle:GetAttribute(OBSTACLE_DESPAWNING_ATTRIBUTE) == true then
				return
			end

			tween_obstacle_transparency(
				obstacle,
				originalTransparency,
				OBSTACLE_FLASH_DURATION,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			task.wait(OBSTACLE_FLASH_DURATION)
		end
	end)

	task.delay(OBSTACLE_COOLDOWN_DURATION, function()
		if not obstacle.Parent or obstacle:GetAttribute(OBSTACLE_DESPAWNING_ATTRIBUTE) == true then
			return
		end

		for part, transparency in originalTransparency do
			if part.Parent then
				part.Transparency = transparency
			end
		end
		set_obstacle_interaction(obstacle, true, true, true)
		obstacle:SetAttribute(OBSTACLE_COOLDOWN_ATTRIBUTE, false)
	end)
end

local function update_coin_chain(player: Player, character: Model, coin: BasePart): ()
	local chainId = coin:GetAttribute(COIN_CHAIN_ID_ATTRIBUTE)
	local chainOrder = coin:GetAttribute(COIN_CHAIN_ORDER_ATTRIBUTE)
	local chainLength = coin:GetAttribute(COIN_CHAIN_LENGTH_ATTRIBUTE)
	if type(chainId) ~= "string"
		or type(chainOrder) ~= "number"
		or type(chainLength) ~= "number"
	then
		coinChainStateByPlayer[player] = nil
		return
	end

	local chainState = coinChainStateByPlayer[player]
	if chainOrder == 1 then
		chainState = {
			chainId = chainId,
			nextOrder = 2,
		}
		coinChainStateByPlayer[player] = chainState
	elseif not chainState or chainState.chainId ~= chainId or chainState.nextOrder ~= chainOrder then
		coinChainStateByPlayer[player] = nil
		return
	else
		chainState.nextOrder += 1
	end

	if chainOrder < chainLength then
		return
	end

	local chainBonus = get_positive_integer_attribute(coin, COIN_CHAIN_BONUS_ATTRIBUTE) or 0
	award_coin(player, chainBonus)
	add_character_flow(character, cartGameplayConfig.flowChainBonus)
	coinChainStateByPlayer[player] = nil
end

local function apply_obstacle_damage(obstacle: Instance, hitPart: BasePart): ()
	if obstacle:GetAttribute(OBSTACLE_COOLDOWN_ATTRIBUTE) == true then
		return
	end

	local player, character = get_player_from_hit(hitPart)
	if not player or not character or character:GetAttribute(IS_RAMP_SLIDING_ATTRIBUTE) ~= true then
		return
	end

	local obstacleWorld = obstacle:GetAttribute(GENERATED_WORLD_ATTRIBUTE)
	local characterWorld = character:GetAttribute(RAMP_WORLD_ATTRIBUTE)
	if type(obstacleWorld) ~= "number" or obstacleWorld ~= characterWorld then
		return
	end

	local maxHealth = get_positive_integer_attribute(character, CART_MAX_HEALTH_ATTRIBUTE)
	local currentHealth = get_positive_integer_attribute(character, CART_HEALTH_ATTRIBUTE)
	local damage = get_nonnegative_integer_attribute(obstacle, OBSTACLE_DAMAGE_ATTRIBUTE) or DEFAULT_OBSTACLE_DAMAGE
	if not maxHealth or not currentHealth then
		return
	end

	local damagedCharacters = damagedCharactersByObstacle[obstacle]
	if not damagedCharacters then
		damagedCharacters = {}
		damagedCharactersByObstacle[obstacle] = damagedCharacters
	end
	if damagedCharacters[character] then
		return
	end

	local currentTime = os.clock()
	local lastDamageAt = lastDamageAtByCharacter[character] or -math.huge
	if currentTime - lastDamageAt < DAMAGE_COOLDOWN_DURATION then
		return
	end
	lastDamageAtByCharacter[character] = currentTime
	damagedCharacters[character] = true

	local remainingHealth = math.max(currentHealth - damage, 0)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		local speedRetention = if damage <= 0
			then SOFT_IMPACT_SPEED_RETENTION
			elseif damage == 1 then NORMAL_IMPACT_SPEED_RETENTION
			else HEAVY_IMPACT_SPEED_RETENTION
		rootPart.AssemblyLinearVelocity *= speedRetention
	end
	character:SetAttribute(CART_HEALTH_ATTRIBUTE, remainingHealth)
	character:SetAttribute(CART_LAST_IMPACT_ATTRIBUTE, currentTime)
	character:SetAttribute(CART_FLOW_ATTRIBUTE, 0)
	character:SetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE, false)
	begin_obstacle_cooldown(obstacle)
	impactFeedback:FireClient(player, damage, remainingHealth, maxHealth)

	if remainingHealth <= 0 then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end
end

local function collect_coin(coin: BasePart, hitPart: BasePart): ()
	if coin:GetAttribute(COIN_COLLECTED_ATTRIBUTE) == true then
		return
	end

	local player, character = get_player_from_hit(hitPart)
	if not player or not character or character:GetAttribute(IS_RAMP_SLIDING_ATTRIBUTE) ~= true then
		return
	end

	local coinWorld = coin:GetAttribute(GENERATED_WORLD_ATTRIBUTE)
	local characterWorld = character:GetAttribute(RAMP_WORLD_ATTRIBUTE)
	if type(coinWorld) ~= "number" or coinWorld ~= characterWorld then
		return
	end

	coin:SetAttribute(COIN_COLLECTED_ATTRIBUTE, true)
	coin.CanTouch = false
	coin.CanQuery = false
	local collectionHitbox = coin:FindFirstChild(COIN_HITBOX_NAME)
	if collectionHitbox and collectionHitbox:IsA("BasePart") then
		collectionHitbox.CanTouch = false
		collectionHitbox.CanQuery = false
	end
	local coinReward = get_positive_integer_attribute(coin, COIN_REWARD_ATTRIBUTE) or COIN_SAFE_REWARD
	local flowReward = coin:GetAttribute(COIN_FLOW_REWARD_ATTRIBUTE)
	award_coin(player, coinReward)
	add_character_flow(
		character,
		if type(flowReward) == "number" and flowReward > 0 then flowReward else cartGameplayConfig.flowCoinReward
	)
	update_coin_chain(player, character, coin)

	local collectTween = TweenService:Create(
		coin,
		TweenInfo.new(WAVE_DESPAWN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{
			Size = coin.Size * COIN_COLLECT_SIZE_SCALE,
			Transparency = 1,
		}
	)
	collectTween:Play()
	task.delay(WAVE_DESPAWN_DURATION + 0.05, function()
		if coin.Parent then
			coin:Destroy()
		end
	end)
end

local function register_obstacle(obstacle: Instance): ()
	local connections: ConnectionSet = {}
	for _, part in get_obstacle_parts(obstacle) do
		table.insert(connections, part.Touched:Connect(function(hitPart: BasePart)
			apply_obstacle_damage(obstacle, hitPart)
		end))
	end
	table.insert(connections, obstacle.Destroying:Connect(function()
		disconnect_obstacle(obstacle)
	end))
	obstacleConnections[obstacle] = connections
end

local function register_coin(coin: BasePart): ()
	local connections: ConnectionSet = {}
	table.insert(connections, coin.Touched:Connect(function(hitPart: BasePart)
		collect_coin(coin, hitPart)
	end))
	local collectionHitbox = coin:FindFirstChild(COIN_HITBOX_NAME)
	if collectionHitbox and collectionHitbox:IsA("BasePart") then
		table.insert(connections, collectionHitbox.Touched:Connect(function(hitPart: BasePart)
			collect_coin(coin, hitPart)
		end))
	end
	table.insert(connections, coin.Destroying:Connect(function()
		disconnect_coin(coin)
	end))
	coinConnections[coin] = connections
end

local function animate_part_spawn(part: BasePart, targetCFrame: CFrame, targetSize: Vector3, canCollide: boolean): ()
	local initialSize = targetSize * SPAWN_SIZE_SCALE
	part.Size = initialSize
	part.CFrame = targetCFrame - targetCFrame.UpVector * (targetSize.Y - initialSize.Y) * 0.5
	part.Transparency = SPAWN_TRANSPARENCY
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false

	local spawnTween = TweenService:Create(
		part,
		TweenInfo.new(WAVE_SPAWN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{CFrame = targetCFrame, Size = targetSize, Transparency = 0}
	)
	spawnTween:Play()

	task.spawn(function()
		spawnTween.Completed:Wait()
		if not part.Parent or part:GetAttribute(OBSTACLE_DESPAWNING_ATTRIBUTE) == true then
			return
		end

		part.CanCollide = canCollide
		part.CanTouch = true
		part.CanQuery = canCollide
	end)
end

local function animate_model_spawn(model: Model, targetBoundsCFrame: CFrame, obstacleScale: number): ()
	local initialModelScale = model:GetScale()
	local targetModelScale = initialModelScale * obstacleScale
	local _, initialBoundsSize = model:GetBoundingBox()
	local targetBoundsSize = initialBoundsSize * obstacleScale
	local originalTransparency = get_obstacle_transparency(model)
	set_obstacle_interaction(model, false, false, false)
	for part in originalTransparency do
		part.Transparency = math.max(part.Transparency, SPAWN_TRANSPARENCY)
	end

	local scaleValue = Instance.new("NumberValue")
	scaleValue.Value = targetModelScale * SPAWN_SIZE_SCALE
	local function update_model_scale(): ()
		if not model.Parent then
			return
		end

		model:ScaleTo(scaleValue.Value)
		local _, currentBoundsSize = model:GetBoundingBox()
		local currentBoundsCFrame = targetBoundsCFrame
			- targetBoundsCFrame.UpVector * (targetBoundsSize.Y - currentBoundsSize.Y) * 0.5
		model:PivotTo(get_obstacle_pivot_for_bounds(model, currentBoundsCFrame))
	end

	update_model_scale()
	local scaleConnection = scaleValue:GetPropertyChangedSignal("Value"):Connect(update_model_scale)
	local spawnTween = TweenService:Create(
		scaleValue,
		TweenInfo.new(WAVE_SPAWN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Value = targetModelScale}
	)
	spawnTween:Play()
	tween_obstacle_transparency(
		model,
		originalTransparency,
		WAVE_SPAWN_DURATION,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	task.spawn(function()
		spawnTween.Completed:Wait()
		scaleConnection:Disconnect()
		scaleValue:Destroy()
		if not model.Parent or model:GetAttribute(OBSTACLE_DESPAWNING_ATTRIBUTE) == true then
			return
		end

		set_obstacle_interaction(model, true, true, true)
	end)
end

local function animate_obstacle_spawn(obstacle: Instance, targetBoundsCFrame: CFrame, obstacleScale: number): ()
	if obstacle:IsA("BasePart") then
		animate_part_spawn(obstacle, targetBoundsCFrame, obstacle.Size * obstacleScale, true)
		return
	end
	if obstacle:IsA("Model") then
		animate_model_spawn(obstacle, targetBoundsCFrame, obstacleScale)
	end
end

local function start_rolling_barrel(model: Model, targetBoundsCFrame: CFrame, obstacleScale: number): ()
	if not model.Parent then
		return
	end

	local boundsCFrame = model:GetBoundingBox()
	local boundsFromPivot = model:GetPivot():ToObjectSpace(boundsCFrame)
	local surfaceNormal = targetBoundsCFrame.UpVector
	local downhillDirection = targetBoundsCFrame.LookVector
	if surfaceNormal.Magnitude < 0.99 or downhillDirection.Magnitude < 0.99 then
		return
	end

	local targetPosition = targetBoundsCFrame.Position
	local dropPosition = targetPosition + surfaceNormal * cartGameplayConfig.rollingBarrelDropHeight * obstacleScale
	model:PivotTo((targetBoundsCFrame + surfaceNormal * cartGameplayConfig.rollingBarrelDropHeight * obstacleScale) * boundsFromPivot:Inverse())
	model:SetAttribute(cartGameplayConfig.rollingBarrelBoundsAttribute, boundsFromPivot)
	model:SetAttribute(cartGameplayConfig.rollingBarrelTargetAttribute, targetPosition)
	model:SetAttribute(cartGameplayConfig.rollingBarrelDropAttribute, dropPosition)
	model:SetAttribute(cartGameplayConfig.rollingBarrelDirectionAttribute, downhillDirection.Unit)
	model:SetAttribute(cartGameplayConfig.rollingBarrelNormalAttribute, surfaceNormal.Unit)
	model:SetAttribute(
		cartGameplayConfig.rollingBarrelSpeedAttribute,
		cartGameplayConfig.rollingBarrelSpeed * math.clamp(obstacleScale, 0.9, 1.35)
	)
	model:SetAttribute(
		cartGameplayConfig.rollingBarrelSpinAttribute,
		cartGameplayConfig.rollingBarrelSpinSpeed * math.clamp(obstacleScale, 0.9, 1.35)
	)
	model:SetAttribute(cartGameplayConfig.rollingBarrelElapsedAttribute, 0)
	model:SetAttribute(cartGameplayConfig.rollingBarrelAttribute, true)
end

local function update_rolling_barrels(deltaTime: number): ()
	for _, instance in generatedObstaclesFolder:GetDescendants() do
		if not instance:IsA("Model")
			or instance:GetAttribute(cartGameplayConfig.rollingBarrelAttribute) ~= true
		then
			continue
		end

		local elapsed = instance:GetAttribute(cartGameplayConfig.rollingBarrelElapsedAttribute)
		local boundsFromPivot = instance:GetAttribute(cartGameplayConfig.rollingBarrelBoundsAttribute)
		local targetPosition = instance:GetAttribute(cartGameplayConfig.rollingBarrelTargetAttribute)
		local dropPosition = instance:GetAttribute(cartGameplayConfig.rollingBarrelDropAttribute)
		local downhillDirection = instance:GetAttribute(cartGameplayConfig.rollingBarrelDirectionAttribute)
		local surfaceNormal = instance:GetAttribute(cartGameplayConfig.rollingBarrelNormalAttribute)
		local rollSpeed = instance:GetAttribute(cartGameplayConfig.rollingBarrelSpeedAttribute)
		local spinSpeed = instance:GetAttribute(cartGameplayConfig.rollingBarrelSpinAttribute)
		if type(elapsed) ~= "number"
			or typeof(boundsFromPivot) ~= "CFrame"
			or typeof(targetPosition) ~= "Vector3"
			or typeof(dropPosition) ~= "Vector3"
			or typeof(downhillDirection) ~= "Vector3"
			or typeof(surfaceNormal) ~= "Vector3"
			or type(rollSpeed) ~= "number"
			or type(spinSpeed) ~= "number"
		then
			instance:SetAttribute(cartGameplayConfig.rollingBarrelAttribute, false)
			continue
		end

		elapsed += deltaTime
		instance:SetAttribute(cartGameplayConfig.rollingBarrelElapsedAttribute, elapsed)
		if elapsed >= cartGameplayConfig.rollingBarrelLifetime then
			instance:SetAttribute(cartGameplayConfig.rollingBarrelAttribute, false)
			instance:SetAttribute(OBSTACLE_DESPAWNING_ATTRIBUTE, true)
			set_obstacle_interaction(instance, false, false, false)
			disconnect_obstacle(instance)
			tween_obstacle_transparency(
				instance,
				1,
				cartGameplayConfig.rollingBarrelFadeDuration,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			task.delay(cartGameplayConfig.rollingBarrelFadeDuration + 0.05, function()
				if instance.Parent then
					instance:Destroy()
				end
			end)
			continue
		end

		local dropProgress = math.clamp(elapsed / cartGameplayConfig.rollingBarrelDropDuration, 0, 1)
		local easedDropProgress = 1 - (1 - dropProgress) ^ 3
		local position = if dropProgress < 1
			then dropPosition:Lerp(targetPosition, easedDropProgress)
			else targetPosition
				+ downhillDirection * (elapsed - cartGameplayConfig.rollingBarrelDropDuration) * rollSpeed
		local spinAngle = elapsed * spinSpeed
		local boundsCFrame = CFrame.lookAt(
			position,
			position + downhillDirection,
			surfaceNormal
		) * CFrame.Angles(spinAngle, 0, 0)
		instance:PivotTo(boundsCFrame * boundsFromPivot:Inverse())
	end
end

local function animate_model_despawn(model: Model): ()
	local scaleValue = Instance.new("NumberValue")
	scaleValue.Value = model:GetScale()
	local scaleConnection = scaleValue:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then
			model:ScaleTo(scaleValue.Value)
		end
	end)
	local shrinkTween = TweenService:Create(
		scaleValue,
		TweenInfo.new(WAVE_DESPAWN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Value = SPAWN_SIZE_SCALE}
	)
	shrinkTween:Play()
	tween_obstacle_transparency(
		model,
		1,
		WAVE_DESPAWN_DURATION,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(WAVE_DESPAWN_DURATION, function()
		scaleConnection:Disconnect()
		scaleValue:Destroy()
	end)
end

local function despawn_obstacle_wave(wave: Folder): ()
	for _, obstacle in wave:GetChildren() do
		if is_obstacle_instance(obstacle) then
			obstacle:SetAttribute(cartGameplayConfig.rollingBarrelAttribute, false)
			obstacle:SetAttribute(OBSTACLE_DESPAWNING_ATTRIBUTE, true)
			set_obstacle_interaction(obstacle, false, false, false)
			disconnect_obstacle(obstacle)

			if obstacle:IsA("BasePart") then
				local shrinkTween = TweenService:Create(
					obstacle,
					TweenInfo.new(WAVE_DESPAWN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{Size = obstacle.Size * SPAWN_SIZE_SCALE, Transparency = 1}
				)
				shrinkTween:Play()
			elseif obstacle:IsA("Model") then
				animate_model_despawn(obstacle)
			end
		end
	end

	task.delay(WAVE_DESPAWN_DURATION + 0.05, function()
		if wave.Parent then
			wave:Destroy()
		end
	end)
end

local function despawn_collectible_wave(wave: Folder): ()
	for _, coin in wave:GetChildren() do
		if coin:IsA("BasePart") then
			coin.CanTouch = false
			coin.CanQuery = false
			local collectionHitbox = coin:FindFirstChild(COIN_HITBOX_NAME)
			if collectionHitbox and collectionHitbox:IsA("BasePart") then
				collectionHitbox.CanTouch = false
				collectionHitbox.CanQuery = false
			end
			disconnect_coin(coin)

			local shrinkTween = TweenService:Create(
				coin,
				TweenInfo.new(WAVE_DESPAWN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Size = coin.Size * SPAWN_SIZE_SCALE, Transparency = 1}
			)
			shrinkTween:Play()
		end
	end

	task.delay(WAVE_DESPAWN_DURATION + 0.05, function()
		if wave.Parent then
			wave:Destroy()
		end
	end)
end

local function create_wave_folder(worldId: number, seed: number): Folder
	local nextWaveNumber = (waveNumberByWorld[worldId] or 0) + 1
	waveNumberByWorld[worldId] = nextWaveNumber

	local wave = Instance.new("Folder")
	wave.Name = ("Wave_%03d"):format(nextWaveNumber)
	wave:SetAttribute(GENERATED_WORLD_ATTRIBUTE, worldId)
	wave:SetAttribute(WAVE_ID_ATTRIBUTE, nextWaveNumber)
	wave:SetAttribute(WAVE_SEED_ATTRIBUTE, seed)
	wave.Parent = get_world_folder(generatedObstaclesFolder, worldId)
	return wave
end

local function create_collectible_wave_folder(worldId: number, waveId: number, seed: number): Folder
	local wave = Instance.new("Folder")
	wave.Name = ("Wave_%03d"):format(waveId)
	wave:SetAttribute(GENERATED_WORLD_ATTRIBUTE, worldId)
	wave:SetAttribute(WAVE_ID_ATTRIBUTE, waveId)
	wave:SetAttribute(WAVE_SEED_ATTRIBUTE, seed)
	wave.Parent = get_world_folder(generatedCollectiblesFolder, worldId)
	return wave
end

local function create_obstacle(
	wave: Folder,
	template: Instance,
	spawnCFrame: CFrame,
	worldId: number,
	waveId: number,
	obstacleScale: number,
	damage: number,
	isRollingBarrel: boolean
): ()
	local obstacle = template:Clone()
	if not is_obstacle_instance(obstacle) then
		return
	end
	remove_obstacle_scripts(obstacle)
	obstacle.Name = ("Obstacle_%s"):format(template.Name)
	local obstacleName = string.lower(obstacle.Name)
	local shouldRoll = isRollingBarrel
		or (obstacle:IsA("Model") and string.find(obstacleName, "barrel", 1, true) ~= nil)
	obstacle:SetAttribute(GENERATED_WORLD_ATTRIBUTE, worldId)
	obstacle:SetAttribute(WAVE_ID_ATTRIBUTE, waveId)
	obstacle:SetAttribute(OBSTACLE_SCALE_ATTRIBUTE, obstacleScale)
	obstacle:SetAttribute(OBSTACLE_DAMAGE_ATTRIBUTE, damage)
	obstacle:SetAttribute(cartGameplayConfig.rollingBarrelAttribute, false)
	obstacle.Parent = wave
	register_obstacle(obstacle)
	animate_obstacle_spawn(obstacle, spawnCFrame, obstacleScale)
	if shouldRoll and obstacle:IsA("Model") then
		task.delay(WAVE_SPAWN_DURATION + 0.05, function()
			start_rolling_barrel(obstacle, spawnCFrame, obstacleScale)
		end)
	end
end

local function is_spawn_near_active_rider(worldId: number, pendingSpawn: PendingObstacleSpawn): boolean
	for character, activeWorldId in activeWorldByCharacter do
		if activeWorldId ~= worldId then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart or not rootPart:IsA("BasePart") then
			continue
		end

		local horizontalOffset = Vector3.new(
			pendingSpawn.spawnCFrame.Position.X - rootPart.Position.X,
			0,
			pendingSpawn.spawnCFrame.Position.Z - rootPart.Position.Z
		)
		if horizontalOffset.Magnitude > PENDING_OBSTACLE_SPAWN_DISTANCE then
			continue
		end

		local horizontalForward = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
		if horizontalForward.Magnitude > 0.01
			and horizontalOffset:Dot(horizontalForward.Unit) >= -PENDING_OBSTACLE_BACKTRACK_DISTANCE
		then
			return true
		end
	end

	return false
end

local function spawn_pending_obstacles_for_world(worldId: number): ()
	local pendingSpawns = pendingObstacleSpawnsByWorld[worldId]
	local wave = currentWaveByWorld[worldId]
	if not pendingSpawns or not wave or not wave.Parent then
		pendingObstacleSpawnsByWorld[worldId] = {}
		return
	end

	local remainingSpawns: {PendingObstacleSpawn} = {}
	local spawnedCount = 0
	for _, pendingSpawn in pendingSpawns do
		if spawnedCount < MAX_PENDING_OBSTACLE_SPAWNS_PER_UPDATE
			and is_spawn_near_active_rider(worldId, pendingSpawn)
		then
			create_obstacle(
				wave,
				pendingSpawn.template,
				pendingSpawn.spawnCFrame,
				worldId,
				pendingSpawn.waveId,
				pendingSpawn.obstacleScale,
				pendingSpawn.damage,
				pendingSpawn.isRollingBarrel
			)
			spawnedCount += 1
		else
			table.insert(remainingSpawns, pendingSpawn)
		end
	end
	pendingObstacleSpawnsByWorld[worldId] = remainingSpawns
end

local function create_coin_collection_hitbox(coin: BasePart, targetCFrame: CFrame, targetSize: Vector3): BasePart
	local collectionHitbox = Instance.new("Part")
	collectionHitbox.Name = COIN_HITBOX_NAME
	collectionHitbox.Size = Vector3.new(
		targetSize.X * COIN_COLLECTION_SIZE_MULTIPLIER,
		COIN_COLLECTION_DEPTH,
		targetSize.Z * COIN_COLLECTION_SIZE_MULTIPLIER
	)
	collectionHitbox.CFrame = targetCFrame
	collectionHitbox.Anchored = true
	collectionHitbox.Transparency = 1
	collectionHitbox.CanCollide = false
	collectionHitbox.CanTouch = false
	collectionHitbox.CanQuery = false
	collectionHitbox.CastShadow = false
	collectionHitbox.Parent = coin
	return collectionHitbox
end

local function create_coin(
	wave: Folder,
	template: BasePart,
	spawnCFrame: CFrame,
	targetSize: Vector3,
	worldId: number,
	waveId: number,
	rewardValue: number,
	flowReward: number,
	isRiskCoin: boolean,
	chainId: string,
	chainOrder: number,
	chainLength: number,
	chainBonus: number
): ()
	local coin = template:Clone()
	local thumbnailCamera = coin:FindFirstChildWhichIsA("Camera", true)
	if thumbnailCamera then
		thumbnailCamera:Destroy()
	end

	coin.Name = COIN_TEMPLATE_NAME
	coin.Anchored = true
	coin.CanCollide = false
	coin.CastShadow = false
	coin:SetAttribute(GENERATED_WORLD_ATTRIBUTE, worldId)
	coin:SetAttribute(WAVE_ID_ATTRIBUTE, waveId)
	coin:SetAttribute(COIN_SURFACE_RIGHT_ATTRIBUTE, spawnCFrame.RightVector)
	coin:SetAttribute(COIN_SURFACE_UP_ATTRIBUTE, spawnCFrame.UpVector)
	coin:SetAttribute(COIN_REWARD_ATTRIBUTE, rewardValue)
	coin:SetAttribute(COIN_FLOW_REWARD_ATTRIBUTE, flowReward)
	coin:SetAttribute(COIN_RISK_ATTRIBUTE, isRiskCoin)
	coin:SetAttribute(COIN_CHAIN_ID_ATTRIBUTE, chainId)
	coin:SetAttribute(COIN_CHAIN_ORDER_ATTRIBUTE, chainOrder)
	coin:SetAttribute(COIN_CHAIN_LENGTH_ATTRIBUTE, chainLength)
	coin:SetAttribute(COIN_CHAIN_BONUS_ATTRIBUTE, chainBonus)
	if rewardValue >= COIN_GOLD_REWARD then
		coin.Color = Color3.fromRGB(255, 226, 76)
		coin.Material = Enum.Material.Neon
	elseif isRiskCoin then
		coin.Color = Color3.fromRGB(255, 151, 54)
	end
	coin.Parent = wave
	local targetCFrame = spawnCFrame * CFrame.Angles(COIN_UPRIGHT_ANGLE, 0, 0)
	local collectionHitbox = create_coin_collection_hitbox(coin, targetCFrame, targetSize)
	register_coin(coin)
	animate_part_spawn(
		coin,
		targetCFrame,
		targetSize,
		false
	)
	task.delay(WAVE_SPAWN_DURATION, function()
		if coin.Parent and coin:GetAttribute(COIN_COLLECTED_ATTRIBUTE) ~= true then
			collectionHitbox.CanTouch = true
		end
	end)
end

local function choose_safe_lane_index(
	random: Random,
	previousSafeLaneIndex: number?,
	difficultyProgress: number
): number
	if not previousSafeLaneIndex then
		return random:NextInteger(1, #LANE_MULTIPLIERS)
	end

	local minimumLaneChange = if difficultyProgress >= 0.45 and random:NextNumber() < 0.72 then 2 else 1
	local candidates: {number} = {}
	for laneIndex = 1, #LANE_MULTIPLIERS do
		if math.abs(laneIndex - previousSafeLaneIndex) >= minimumLaneChange then
			table.insert(candidates, laneIndex)
		end
	end
	if #candidates == 0 then
		return previousSafeLaneIndex
	end

	return candidates[random:NextInteger(1, #candidates)]
end

local function choose_reward_lane_index(random: Random, safeLaneIndex: number): number
	local maximumDistance = 0
	local candidates: {number} = {}
	for laneIndex = 1, #LANE_MULTIPLIERS do
		local laneDistance = math.abs(laneIndex - safeLaneIndex)
		if laneDistance > maximumDistance then
			maximumDistance = laneDistance
			table.clear(candidates)
			table.insert(candidates, laneIndex)
		elseif laneDistance == maximumDistance then
			table.insert(candidates, laneIndex)
		end
	end

	return candidates[random:NextInteger(1, #candidates)]
end

local function choose_pattern_name(
	random: Random,
	encounterIndex: number,
	encounterCount: number,
	previousPatternName: string?,
	lastJumpGateIndex: number
): string
	if encounterIndex == 1 then
		return PATTERN_SLALOM
	end
	if encounterIndex % 6 == 0 then
		return PATTERN_BREATHER
	end

	local difficultyProgress = (encounterIndex - 1) / math.max(encounterCount - 1, 1)
	local candidates = {
		{name = PATTERN_SLALOM, weight = 3.2},
		{name = PATTERN_FORK, weight = 2.6},
	}
	if difficultyProgress >= 0.28 then
		table.insert(candidates, {name = PATTERN_CHICANE, weight = 1.8 + difficultyProgress * 2.2})
	end
	if difficultyProgress >= 0.14 and encounterIndex - lastJumpGateIndex >= 3 then
		table.insert(candidates, {name = PATTERN_JUMP_GATE, weight = 1.5 + difficultyProgress})
	end

	local totalWeight = 0
	for _, candidate in candidates do
		local repetitionMultiplier = if candidate.name == previousPatternName then 0.28 else 1
		candidate.weight *= repetitionMultiplier
		totalWeight += candidate.weight
	end

	local selection = random:NextNumber(0, totalWeight)
	local accumulatedWeight = 0
	for _, candidate in candidates do
		accumulatedWeight += candidate.weight
		if selection <= accumulatedWeight then
			return candidate.name
		end
	end

	return PATTERN_SLALOM
end

local function get_pattern_rows(
	patternName: string,
	entryLaneIndex: number,
	safeLaneIndex: number,
	rewardLaneIndex: number
): {PatternRow}
	local middleLaneIndex = math.clamp(math.round((entryLaneIndex + safeLaneIndex) * 0.5), 1, #LANE_MULTIPLIERS)
	if patternName == PATTERN_FORK then
		return {
			{
				distanceAlpha = 0.4,
				openLaneIndices = {safeLaneIndex, rewardLaneIndex},
				scaleMinimum = 1.05,
				scaleMaximum = 1.48,
			},
			{
				distanceAlpha = 0.76,
				openLaneIndices = {safeLaneIndex, rewardLaneIndex},
				scaleMinimum = 1.12,
				scaleMaximum = 1.58,
			},
		}
	end
	if patternName == PATTERN_CHICANE then
		return {
			{
				distanceAlpha = 0.2,
				openLaneIndices = {entryLaneIndex},
				scaleMinimum = 1.15,
				scaleMaximum = MAXIMUM_OBSTACLE_SCALE,
			},
			{
				distanceAlpha = 0.5,
				openLaneIndices = {middleLaneIndex},
				scaleMinimum = 1.18,
				scaleMaximum = MAXIMUM_OBSTACLE_SCALE,
			},
			{
				distanceAlpha = 0.82,
				openLaneIndices = {safeLaneIndex},
				scaleMinimum = 1.2,
				scaleMaximum = MAXIMUM_OBSTACLE_SCALE,
			},
		}
	end
	if patternName == PATTERN_JUMP_GATE then
		return {
			{
				distanceAlpha = 0.58,
				openLaneIndices = {},
				scaleMinimum = MINIMUM_OBSTACLE_SCALE,
				scaleMaximum = SOFT_OBSTACLE_MAXIMUM_SCALE,
				damageOverride = DEFAULT_OBSTACLE_DAMAGE,
			},
		}
	end
	if patternName == PATTERN_BREATHER then
		return {}
	end

	return {
		{
			distanceAlpha = 0.28,
			openLaneIndices = {entryLaneIndex, middleLaneIndex},
			scaleMinimum = 0.96,
			scaleMaximum = 1.36,
		},
		{
			distanceAlpha = 0.74,
			openLaneIndices = {middleLaneIndex, safeLaneIndex},
			scaleMinimum = 1.02,
			scaleMaximum = 1.48,
		},
	}
end

local function get_obstacle_damage(template: Instance, obstacleScale: number, damageOverride: number?): number
	if damageOverride ~= nil then
		return math.max(damageOverride, DEFAULT_OBSTACLE_DAMAGE)
	end

	local configuredDamage = get_nonnegative_integer_attribute(template, OBSTACLE_DAMAGE_ATTRIBUTE)
	if configuredDamage then
		return math.max(configuredDamage, DEFAULT_OBSTACLE_DAMAGE)
	end
	if obstacleScale >= cartGameplayConfig.obstacleCriticalScale then
		return cartGameplayConfig.obstacleCriticalDamage
	end
	if obstacleScale >= HEAVY_OBSTACLE_MINIMUM_SCALE then
		return 2
	end

	return DEFAULT_OBSTACLE_DAMAGE
end

local function queue_pattern_row(
	pendingSpawns: {PendingObstacleSpawn},
	rampPart: BasePart,
	templates: {Instance},
	random: Random,
	waveId: number,
	startDistance: number,
	encounterLength: number,
	lateralRange: number,
	patternName: string,
	patternRow: PatternRow,
	generatedCount: number
): number
	local maximumLongitudinalJitter = encounterLength * OBSTACLE_LONGITUDINAL_JITTER_MULTIPLIER
	local maximumLateralJitter = lateralRange * OBSTACLE_LATERAL_JITTER_MULTIPLIER
	local laneSpacing = math.abs(LANE_MULTIPLIERS[2] - LANE_MULTIPLIERS[1]) * lateralRange
	local clusterCount = if patternName == PATTERN_JUMP_GATE then JUMP_GATE_CLUSTER_COUNT else OBSTACLE_CLUSTER_COUNT
	local clusterSpacing = if patternName == PATTERN_JUMP_GATE
		then laneSpacing / JUMP_GATE_CLUSTER_COUNT
		else laneSpacing * OBSTACLE_CLUSTER_SPACING_MULTIPLIER
	local rowDistance = startDistance + encounterLength * patternRow.distanceAlpha
	local rollingBarrelTemplate: Instance?
	for _, candidate in templates do
		local candidateName = string.lower(candidate.Name)
		if candidate:IsA("Model")
			and (string.find(candidateName, "barrel", 1, true) ~= nil
				or string.find(candidateName, "barril", 1, true) ~= nil)
		then
			rollingBarrelTemplate = candidate
			break
		end
	end
	for laneIndex = 1, #LANE_MULTIPLIERS do
		if generatedCount >= MAX_OBSTACLES_PER_WAVE or table.find(patternRow.openLaneIndices, laneIndex) then
			continue
		end

		for clusterIndex = 1, clusterCount do
			if generatedCount >= MAX_OBSTACLES_PER_WAVE then
				break
			end

			local template = if patternName == PATTERN_JUMP_GATE
				then select_jump_gate_template(random, templates)
				else select_template(random, templates, clusterIndex == 1)
			if not template then
				continue
			end

			local templateName = string.lower(template.Name)
			local isRollingBarrel = template:IsA("Model")
				and (string.find(templateName, "barrel", 1, true) ~= nil
					or string.find(templateName, "barril", 1, true) ~= nil)
			if patternName ~= PATTERN_JUMP_GATE
				and patternName ~= PATTERN_BREATHER
				and random:NextNumber() < cartGameplayConfig.rollingBarrelChance
			then
				if rollingBarrelTemplate then
					template = rollingBarrelTemplate
					isRollingBarrel = true
				end
			end

			local clusterOffset = (clusterIndex - (clusterCount + 1) * 0.5) * clusterSpacing
			local lateralJitter = if patternName == PATTERN_JUMP_GATE
				then 0
				else random:NextNumber(-maximumLateralJitter, maximumLateralJitter)
			local lateralOffset = math.clamp(
				LANE_MULTIPLIERS[laneIndex] * lateralRange + clusterOffset + lateralJitter,
				-lateralRange,
				lateralRange
			)
			local distanceJitter = if patternName == PATTERN_JUMP_GATE
				then 0
				else random:NextNumber(-maximumLongitudinalJitter, maximumLongitudinalJitter)
			local localY = rampPart.Size.Y * 0.5 - rowDistance - distanceJitter
			local _, templateSize = get_instance_bounds(template)
			local obstacleScale = random:NextNumber(patternRow.scaleMinimum, patternRow.scaleMaximum)
			local spawnCFrame = get_surface_cframe(
				rampPart,
				localY,
				lateralOffset,
				templateSize.Y * obstacleScale * 0.5 + SURFACE_CLEARANCE
			)
			if spawnCFrame then
				table.insert(pendingSpawns, {
					template = template,
					spawnCFrame = spawnCFrame,
					waveId = waveId,
					obstacleScale = obstacleScale,
					damage = get_obstacle_damage(template, obstacleScale, patternRow.damageOverride),
					isRollingBarrel = isRollingBarrel and template:IsA("Model"),
				})
				generatedCount += 1
			end
		end
	end

	return generatedCount
end

local function generate_obstacles_for_ramp(
	pendingSpawns: {PendingObstacleSpawn},
	rampPart: BasePart,
	templates: {Instance},
	random: Random,
	worldId: number,
	waveId: number,
	generatedCount: number,
	previousSafeLaneIndex: number?
): ({SegmentLayout}, number, number?)
	local rampLength = rampPart.Size.Y
	if rampLength < MINIMUM_RAMP_LENGTH then
		return {}, generatedCount, previousSafeLaneIndex
	end

	local safeStart = math.min(ENTRY_SAFE_DISTANCE, rampLength * 0.3)
	local safeEnd = math.min(EXIT_SAFE_DISTANCE, rampLength * 0.2)
	local usableLength = rampLength - safeStart - safeEnd
	local lateralRange = math.max(rampPart.Size.X * 0.5 - EDGE_SAFE_DISTANCE, 0)
	if usableLength <= 0 or lateralRange <= 0 then
		return {}, generatedCount, previousSafeLaneIndex
	end

	local encounterCount = math.clamp(
		math.floor(usableLength / TARGET_ENCOUNTER_LENGTH),
		MINIMUM_ENCOUNTERS_PER_RAMP_PART,
		MAXIMUM_ENCOUNTERS_PER_RAMP_PART
	)
	local encounterLength = usableLength / encounterCount
	local segmentLayouts: {SegmentLayout} = {}
	local lastSafeLaneIndex = previousSafeLaneIndex
	local previousPatternName: string? = nil
	local lastJumpGateIndex = -math.huge

	for encounterIndex = 1, encounterCount do
		local startDistance = safeStart + (encounterIndex - 1) * encounterLength
		local endDistance = startDistance + encounterLength
		local difficultyProgress = (encounterIndex - 1) / math.max(encounterCount - 1, 1)
		local entryLaneIndex = lastSafeLaneIndex or random:NextInteger(1, #LANE_MULTIPLIERS)
		local safeLaneIndex = choose_safe_lane_index(random, lastSafeLaneIndex, difficultyProgress)
		local rewardLaneIndex = choose_reward_lane_index(random, safeLaneIndex)
		local patternName = choose_pattern_name(
			random,
			encounterIndex,
			encounterCount,
			previousPatternName,
			lastJumpGateIndex
		)
		if patternName == PATTERN_JUMP_GATE then
			lastJumpGateIndex = encounterIndex
		end
		table.insert(segmentLayouts, {
			rampPart = rampPart,
			startDistance = startDistance,
			endDistance = endDistance,
			lateralRange = lateralRange,
			entryLaneIndex = entryLaneIndex,
			safeLaneIndex = safeLaneIndex,
			rewardLaneIndex = rewardLaneIndex,
			patternName = patternName,
		})

		if generatedCount < MAX_OBSTACLES_PER_WAVE then
			for _, patternRow in get_pattern_rows(patternName, entryLaneIndex, safeLaneIndex, rewardLaneIndex) do
				generatedCount = queue_pattern_row(
					pendingSpawns,
					rampPart,
					templates,
					random,
					waveId,
					startDistance,
					encounterLength,
					lateralRange,
					patternName,
					patternRow,
					generatedCount
				)
			end
		end

		lastSafeLaneIndex = safeLaneIndex
		previousPatternName = patternName
	end

	return segmentLayouts, generatedCount, lastSafeLaneIndex
end

local function create_coin_chain_for_layout(
	wave: Folder,
	coinTemplate: BasePart,
	segmentLayout: SegmentLayout,
	random: Random,
	worldId: number,
	waveId: number,
	encounterIndex: number
): ()
	local isJumpChain = segmentLayout.patternName == PATTERN_JUMP_GATE
	local isRiskChain = segmentLayout.patternName ~= PATTERN_BREATHER
	local coinCount = random:NextInteger(MINIMUM_COINS_PER_CHAIN, MAXIMUM_COINS_PER_CHAIN)
	local coinScale = random:NextNumber(COIN_MINIMUM_SCALE, COIN_MAXIMUM_SCALE)
	local startDistance = segmentLayout.startDistance + COIN_CHAIN_START_PADDING
	local endDistance = segmentLayout.endDistance - COIN_CHAIN_START_PADDING
	local curveOffset = if isJumpChain then 0 else random:NextNumber(-COIN_MAX_CURVE_OFFSET, COIN_MAX_CURVE_OFFSET) * 0.35
	local chainBonus = if isJumpChain
		then COIN_JUMP_CHAIN_BONUS
		elseif isRiskChain then COIN_RISK_CHAIN_BONUS
		else COIN_SAFE_CHAIN_BONUS
	local chainId = ("%d:%d:%s"):format(waveId, encounterIndex, segmentLayout.rampPart:GetFullName())
	local targetLaneIndex = if isRiskChain then segmentLayout.rewardLaneIndex else segmentLayout.safeLaneIndex
	local targetLaneOffset = LANE_MULTIPLIERS[targetLaneIndex] * segmentLayout.lateralRange
	local entryLaneOffset = LANE_MULTIPLIERS[segmentLayout.entryLaneIndex] * segmentLayout.lateralRange
	local hasGoldEnd = isJumpChain or (isRiskChain and random:NextNumber() < 0.3)

	for chainOrder = 1, coinCount do
		local progress = if coinCount > 1 then (chainOrder - 1) / (coinCount - 1) else 0
		local smoothProgress = progress * progress * (3 - 2 * progress)
		local distanceFromTop = startDistance + (endDistance - startDistance) * progress
		local baseLateralOffset = entryLaneOffset + (targetLaneOffset - entryLaneOffset) * smoothProgress
		local lateralOffset = math.clamp(
			baseLateralOffset + math.sin(progress * math.pi) * curveOffset,
			-segmentLayout.lateralRange,
			segmentLayout.lateralRange
		)
		local targetSize = coinTemplate.Size * coinScale
		local standingHeight = math.max(targetSize.X, targetSize.Z)
		local verticalArcOffset = if isJumpChain then math.sin(progress * math.pi) * JUMP_COIN_ARC_HEIGHT else 0
		local localY = segmentLayout.rampPart.Size.Y * 0.5 - distanceFromTop
		local spawnCFrame = get_surface_cframe(
			segmentLayout.rampPart,
			localY,
			lateralOffset,
			standingHeight * 0.5 + COIN_SURFACE_CLEARANCE + verticalArcOffset
		)
		if spawnCFrame then
			local rewardValue = if hasGoldEnd and chainOrder == coinCount
				then COIN_GOLD_REWARD
				elseif isRiskChain then COIN_RISK_REWARD
				else COIN_SAFE_REWARD
			local flowReward = if isRiskChain
				then cartGameplayConfig.flowRiskCoinReward
				else cartGameplayConfig.flowCoinReward
			create_coin(
				wave,
				coinTemplate,
				spawnCFrame,
				targetSize,
				worldId,
				waveId,
				rewardValue,
				flowReward,
				isRiskChain,
				chainId,
				chainOrder,
				coinCount,
				chainBonus
			)
		end
	end
end

local function generate_coin_chains_for_ramp(
	wave: Folder,
	coinTemplate: BasePart,
	segmentLayouts: {SegmentLayout},
	random: Random,
	worldId: number,
	waveId: number
): ()
	for encounterIndex, segmentLayout in segmentLayouts do
		local shouldCreateChain = segmentLayout.patternName == PATTERN_JUMP_GATE
			or segmentLayout.patternName == PATTERN_BREATHER
			or encounterIndex % COIN_CHAIN_SEGMENT_INTERVAL == 0
		if shouldCreateChain then
			create_coin_chain_for_layout(
				wave,
				coinTemplate,
				segmentLayout,
				random,
				worldId,
				waveId,
				encounterIndex
			)
		end
	end
end

local function replace_wave(worldId: number): ()
	if waveGenerationByWorld[worldId] or (activeRidersByWorld[worldId] or 0) > 0 then
		return
	end

	waveGenerationByWorld[worldId] = true
	local waveSeed = os.time() + math.floor(os.clock() * 1000) + worldId * 1000 + (waveNumberByWorld[worldId] or 0)
	local random = Random.new(waveSeed)
	local wave = create_wave_folder(worldId, waveSeed)
	local waveId = wave:GetAttribute(WAVE_ID_ATTRIBUTE)
	local previousWave = currentWaveByWorld[worldId]
	currentWaveByWorld[worldId] = wave
	if previousWave and previousWave.Parent then
		despawn_obstacle_wave(previousWave)
	end

	if type(waveId) == "number" then
		local collectibleWave = create_collectible_wave_folder(worldId, waveId, waveSeed)
		local previousCollectibleWave = currentCollectibleWaveByWorld[worldId]
		currentCollectibleWaveByWorld[worldId] = collectibleWave
		if previousCollectibleWave and previousCollectibleWave.Parent then
			despawn_collectible_wave(previousCollectibleWave)
		end

		local templates = get_obstacle_templates()
		local coinTemplate = get_coin_template()
		local generatedCount = 0
		local pendingSpawns: {PendingObstacleSpawn} = {}
		pendingObstacleSpawnsByWorld[worldId] = pendingSpawns
		local previousSafeLaneIndex: number? = nil
		for _, rampPart in get_ramp_parts(worldId) do
			local segmentLayouts: {SegmentLayout}
			segmentLayouts, generatedCount, previousSafeLaneIndex = generate_obstacles_for_ramp(
				pendingSpawns,
				rampPart,
				templates,
				random,
				worldId,
				waveId,
				generatedCount,
				previousSafeLaneIndex
			)
			if coinTemplate then
				generate_coin_chains_for_ramp(
					collectibleWave,
					coinTemplate,
					segmentLayouts,
					random,
					worldId,
					waveId
				)
			end
		end
	end

	waveGenerationByWorld[worldId] = nil
end

local function schedule_wave_replacement(worldId: number): ()
	if pendingWaveByWorld[worldId] then
		return
	end

	pendingWaveByWorld[worldId] = true
	task.delay(WAVE_TRANSITION_DELAY, function()
		pendingWaveByWorld[worldId] = nil
		if (activeRidersByWorld[worldId] or 0) == 0 then
			replace_wave(worldId)
		end
	end)
end

local function get_character_world(character: Model): number?
	if character:GetAttribute(IS_RAMP_SLIDING_ATTRIBUTE) ~= true then
		return nil
	end

	local worldId = character:GetAttribute(RAMP_WORLD_ATTRIBUTE)
	if type(worldId) ~= "number" or worldId < 1 or worldId ~= worldId or worldId == math.huge then
		return nil
	end
	return math.floor(worldId)
end

local function remove_character_from_active_world(character: Model): ()
	local activeWorld = activeWorldByCharacter[character]
	if not activeWorld then
		return
	end

	activeWorldByCharacter[character] = nil
	lastDamageAtByCharacter[character] = nil
	local activeRiderCount = math.max((activeRidersByWorld[activeWorld] or 1) - 1, 0)
	activeRidersByWorld[activeWorld] = activeRiderCount
	if activeRiderCount == 0 then
		schedule_wave_replacement(activeWorld)
	end
end

local function update_character_activity(character: Model): ()
	remove_character_from_active_world(character)
	local worldId = get_character_world(character)
	if not worldId then
		return
	end

	activeWorldByCharacter[character] = worldId
	activeRidersByWorld[worldId] = (activeRidersByWorld[worldId] or 0) + 1
end

local function disconnect_character(character: Model): ()
	remove_character_from_active_world(character)
	local connections = characterConnections[character]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	characterConnections[character] = nil
	trackedCharacters[character] = nil
end

local function track_character(character: Model): ()
	if trackedCharacters[character] then
		return
	end

	trackedCharacters[character] = true
	local connections: ConnectionSet = {}
	table.insert(connections, character:GetAttributeChangedSignal(IS_RAMP_SLIDING_ATTRIBUTE):Connect(function()
		update_character_activity(character)
	end))
	table.insert(connections, character:GetAttributeChangedSignal(RAMP_WORLD_ATTRIBUTE):Connect(function()
		update_character_activity(character)
	end))
	table.insert(connections, character.Destroying:Connect(function()
		disconnect_character(character)
	end))
	characterConnections[character] = connections
	update_character_activity(character)
end

------------------//MAIN FUNCTIONS
local function on_workspace_descendant_added(instance: Instance): ()
	if not instance:IsA("BasePart") or not rampUtility.is_ramp(instance) then
		return
	end

	local worldId = rampUtility.get_world_id(instance)
	if not currentWaveByWorld[worldId] and (activeRidersByWorld[worldId] or 0) == 0 then
		schedule_wave_replacement(worldId)
	end
end

local function update_pending_obstacle_spawns(deltaTime: number): ()
	pendingObstacleSpawnElapsed += deltaTime
	if pendingObstacleSpawnElapsed < PENDING_OBSTACLE_SPAWN_INTERVAL then
		return
	end
	pendingObstacleSpawnElapsed = 0

	for worldId, pendingSpawns in pendingObstacleSpawnsByWorld do
		if #pendingSpawns > 0 and (activeRidersByWorld[worldId] or 0) > 0 then
			spawn_pending_obstacles_for_world(worldId)
		end
	end
end

------------------//INIT
generatedObstaclesFolder = ensure_folder(workspace, GENERATED_OBSTACLES_FOLDER_NAME)
generatedCollectiblesFolder = ensure_folder(workspace, GENERATED_COLLECTIBLES_FOLDER_NAME)
charactersFolder = workspace:WaitForChild(CHARACTERS_FOLDER_NAME) :: Folder
impactFeedback = ensure_impact_feedback_remote()

for _, character in charactersFolder:GetChildren() do
	if character:IsA("Model") then
		track_character(character)
	end
end

for worldId in get_ramp_world_ids() do
	replace_wave(worldId)
end

charactersFolder.ChildAdded:Connect(function(character: Instance)
	if character:IsA("Model") then
		track_character(character)
	end
end)
workspace.DescendantAdded:Connect(on_workspace_descendant_added)
Players.PlayerRemoving:Connect(function(player: Player)
	coinChainStateByPlayer[player] = nil
	flush_pending_coin_rewards(player)
end)
RunService.Heartbeat:Connect(update_pending_obstacle_spawns)
RunService.Heartbeat:Connect(update_rolling_barrels)

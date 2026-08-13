------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local GENERATED_OBSTACLES_FOLDER_NAME: string = "GeneratedObstacles"
local GENERATED_COLLECTIBLES_FOLDER_NAME: string = "GeneratedCollectibles"
local OBSTACLES_FOLDER_NAME: string = "Obstacles"
local MISC_FOLDER_NAME: string = "Misc"
local COIN_TEMPLATE_NAME: string = "Coin"
local ASSETS_FOLDER_NAME: string = "Assets"
local CHARACTERS_FOLDER_NAME: string = "Characters"
local IMPACT_FEEDBACK_REMOTE_NAME: string = "CartImpactFeedback"
local IS_RAMP_SLIDING_ATTRIBUTE: string = "IsRampSliding"
local RAMP_WORLD_ATTRIBUTE: string = "RampWorld"
local CART_MAX_HEALTH_ATTRIBUTE: string = "CartMaxHealth"
local CART_HEALTH_ATTRIBUTE: string = "CartHealth"
local CART_LAST_IMPACT_ATTRIBUTE: string = "CartLastImpactAt"
local GENERATED_WORLD_ATTRIBUTE: string = "World"
local OBSTACLE_DAMAGE_ATTRIBUTE: string = "Damage"
local OBSTACLE_COOLDOWN_ATTRIBUTE: string = "IsImpactCoolingDown"
local OBSTACLE_DESPAWNING_ATTRIBUTE: string = "IsDespawning"
local COIN_COLLECTED_ATTRIBUTE: string = "IsCollected"
local WAVE_ID_ATTRIBUTE: string = "WaveId"
local WAVE_SEED_ATTRIBUTE: string = "WaveSeed"
local COIN_REWARD_VALUE: number = 1
local OBSTACLE_TEMPLATE_NAMES: {string} = {"Small", "Medium", "Large"}
local LANE_MULTIPLIERS: {number} = {-0.82, -0.4, 0, 0.4, 0.82}
local WAVE_TRANSITION_DELAY: number = 2.5
local WAVE_SPAWN_DURATION: number = 0.45
local WAVE_DESPAWN_DURATION: number = 0.3
local OBSTACLE_COOLDOWN_DURATION: number = 0.9
local DAMAGE_COOLDOWN_DURATION: number = 1.1
local COIN_SAVE_BATCH_DELAY: number = 0.35
local OBSTACLE_FLASH_TRANSPARENCY: number = 0.78
local OBSTACLE_FLASH_DURATION: number = 0.1
local OBSTACLE_FLASH_COUNT: number = 3
local SPAWN_SIZE_SCALE: number = 0.15
local COIN_COLLECT_SIZE_SCALE: number = 0.1
local SPAWN_TRANSPARENCY: number = 0.2
local TARGET_OBSTACLE_SEGMENT_LENGTH: number = 72
local MINIMUM_OBSTACLE_SEGMENTS_PER_RAMP_PART: number = 24
local MAXIMUM_OBSTACLE_SEGMENTS_PER_RAMP_PART: number = 32
local MINIMUM_OBSTACLES_PER_SEGMENT: number = 2
local MAXIMUM_OBSTACLES_PER_SEGMENT: number = 3
local MAX_OBSTACLES_PER_WAVE: number = 170
local WIDE_TEMPLATE_SMALL_WEIGHT_FACTOR: number = 0.12
local MINIMUM_RAMP_LENGTH: number = 180
local ENTRY_SAFE_DISTANCE: number = 115
local EXIT_SAFE_DISTANCE: number = 50
local EDGE_SAFE_DISTANCE: number = 32
local SURFACE_RAYCAST_HEIGHT: number = 80
local SURFACE_RAYCAST_DISTANCE: number = 180
local SURFACE_CLEARANCE: number = 0.04
local COIN_SURFACE_CLEARANCE: number = 3
local COIN_CHAINS_PER_RAMP_PART: number = 6
local MINIMUM_COINS_PER_CHAIN: number = 8
local MAXIMUM_COINS_PER_CHAIN: number = 20
local COIN_SPACING: number = 8
local COIN_CHAIN_START_PADDING: number = 10
local COIN_LANE_FOLLOW_ALPHA: number = 0.38
local COIN_MAX_CURVE_OFFSET: number = 12
local COIN_MINIMUM_SCALE: number = 0.72
local COIN_MAXIMUM_SCALE: number = 1.4

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local rampUtility = require(replicatedModules:WaitForChild("Gameplay"):WaitForChild("RampUtility"))
local dataUtility = require(replicatedModules:WaitForChild("Data"):WaitForChild("DataUtility"))

------------------//VARIABLES
type ConnectionSet = {RBXScriptConnection}
type SegmentLayout = {
	rampPart: BasePart,
	startDistance: number,
	endDistance: number,
	lateralRange: number,
	safeLaneIndex: number,
}

local generatedObstaclesFolder: Folder
local generatedCollectiblesFolder: Folder
local charactersFolder: Folder
local impactFeedback: RemoteEvent
local currentWaveByWorld: {[number]: Folder} = {}
local currentCollectibleWaveByWorld: {[number]: Folder} = {}
local activeRidersByWorld: {[number]: number} = {}
local activeWorldByCharacter: {[Model]: number} = {}
local waveNumberByWorld: {[number]: number} = {}
local pendingWaveByWorld: {[number]: boolean} = {}
local waveGenerationByWorld: {[number]: boolean} = {}
local lastDamageAtByCharacter: {[Model]: number} = {}
local damagedCharactersByObstacle: {[BasePart]: {[Model]: boolean}} = {}
local obstacleConnections: {[BasePart]: ConnectionSet} = {}
local coinConnections: {[BasePart]: ConnectionSet} = {}
local characterConnections: {[Model]: ConnectionSet} = {}
local trackedCharacters: {[Model]: boolean} = {}
local pendingCoinRewardsByPlayer: {[Player]: number} = {}
local coinSaveScheduledByPlayer: {[Player]: boolean} = {}

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

local function get_world_folder(rootFolder: Folder, worldId: number): Folder
	return ensure_folder(rootFolder, ("World%d"):format(worldId))
end

local function get_obstacle_templates(): {BasePart}
	local assets = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
	local obstacles = assets:WaitForChild(OBSTACLES_FOLDER_NAME)
	local templates: {BasePart} = {}

	for _, templateName in OBSTACLE_TEMPLATE_NAMES do
		local template = obstacles:FindFirstChild(templateName)
		if template and template:IsA("BasePart") then
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

local function get_template_weight(template: BasePart, prefersWideTemplate: boolean): number
	local weight = template:GetAttribute("SpawnWeight")
	if type(weight) ~= "number" or weight <= 0 or weight ~= weight or weight == math.huge then
		weight = 1
	end

	if prefersWideTemplate and template.Name == "Small" then
		return weight * WIDE_TEMPLATE_SMALL_WEIGHT_FACTOR
	end

	return weight
end

local function select_template(random: Random, templates: {BasePart}, prefersWideTemplate: boolean): BasePart?
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

local function disconnect_obstacle(obstacle: BasePart): ()
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

local function award_coin(player: Player): ()
	local visibleCoins = player:GetAttribute("Coins")
	if type(visibleCoins) ~= "number" then
		local savedCoins = dataUtility.server.get(player, "Coins")
		visibleCoins = if type(savedCoins) == "number" then savedCoins else 0
	end

	player:SetAttribute("Coins", visibleCoins + COIN_REWARD_VALUE)
	pendingCoinRewardsByPlayer[player] = (pendingCoinRewardsByPlayer[player] or 0) + COIN_REWARD_VALUE
	if coinSaveScheduledByPlayer[player] then
		return
	end

	coinSaveScheduledByPlayer[player] = true
	task.delay(COIN_SAVE_BATCH_DELAY, function()
		flush_pending_coin_rewards(player)
	end)
end

local function begin_obstacle_cooldown(obstacle: BasePart): ()
	if obstacle:GetAttribute(OBSTACLE_COOLDOWN_ATTRIBUTE) == true then
		return
	end

	local originalTransparency = obstacle.Transparency
	obstacle:SetAttribute(OBSTACLE_COOLDOWN_ATTRIBUTE, true)
	obstacle.CanCollide = false
	obstacle.CanTouch = false

	task.spawn(function()
		for _ = 1, OBSTACLE_FLASH_COUNT do
			local fadeOut = TweenService:Create(
				obstacle,
				TweenInfo.new(OBSTACLE_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Transparency = OBSTACLE_FLASH_TRANSPARENCY}
			)
			fadeOut:Play()
			fadeOut.Completed:Wait()
			if not obstacle.Parent or obstacle:GetAttribute(OBSTACLE_DESPAWNING_ATTRIBUTE) == true then
				return
			end

			local fadeIn = TweenService:Create(
				obstacle,
				TweenInfo.new(OBSTACLE_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Transparency = originalTransparency}
			)
			fadeIn:Play()
			fadeIn.Completed:Wait()
		end
	end)

	task.delay(OBSTACLE_COOLDOWN_DURATION, function()
		if not obstacle.Parent or obstacle:GetAttribute(OBSTACLE_DESPAWNING_ATTRIBUTE) == true then
			return
		end

		obstacle.Transparency = originalTransparency
		obstacle.CanCollide = true
		obstacle.CanTouch = true
		obstacle:SetAttribute(OBSTACLE_COOLDOWN_ATTRIBUTE, false)
	end)
end

local function apply_obstacle_damage(obstacle: BasePart, hitPart: BasePart): ()
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
	local damage = get_positive_integer_attribute(obstacle, OBSTACLE_DAMAGE_ATTRIBUTE)
	if not maxHealth or not currentHealth or not damage then
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
	character:SetAttribute(CART_HEALTH_ATTRIBUTE, remainingHealth)
	character:SetAttribute(CART_LAST_IMPACT_ATTRIBUTE, currentTime)
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
	award_coin(player)

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

local function register_obstacle(obstacle: BasePart): ()
	local connections: ConnectionSet = {}
	table.insert(connections, obstacle.Touched:Connect(function(hitPart: BasePart)
		apply_obstacle_damage(obstacle, hitPart)
	end))
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

local function despawn_obstacle_wave(wave: Folder): ()
	for _, obstacle in wave:GetChildren() do
		if obstacle:IsA("BasePart") then
			obstacle:SetAttribute(OBSTACLE_DESPAWNING_ATTRIBUTE, true)
			obstacle.CanCollide = false
			obstacle.CanTouch = false
			obstacle.CanQuery = false
			disconnect_obstacle(obstacle)

			local shrinkTween = TweenService:Create(
				obstacle,
				TweenInfo.new(WAVE_DESPAWN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Size = obstacle.Size * SPAWN_SIZE_SCALE, Transparency = 1}
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

local function despawn_collectible_wave(wave: Folder): ()
	for _, coin in wave:GetChildren() do
		if coin:IsA("BasePart") then
			coin.CanTouch = false
			coin.CanQuery = false
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
	template: BasePart,
	spawnCFrame: CFrame,
	worldId: number,
	waveId: number
): ()
	local obstacle = template:Clone()
	obstacle.Name = ("Obstacle_%s"):format(template.Name)
	obstacle.Anchored = true
	obstacle:SetAttribute(GENERATED_WORLD_ATTRIBUTE, worldId)
	obstacle:SetAttribute(WAVE_ID_ATTRIBUTE, waveId)
	obstacle.Parent = wave
	register_obstacle(obstacle)
	animate_part_spawn(obstacle, spawnCFrame, template.Size, true)
end

local function create_coin(
	wave: Folder,
	template: BasePart,
	spawnCFrame: CFrame,
	targetSize: Vector3,
	worldId: number,
	waveId: number
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
	coin.Parent = wave
	register_coin(coin)
	animate_part_spawn(coin, spawnCFrame, targetSize, false)
end

local function choose_safe_lane_index(random: Random, previousSafeLaneIndex: number?): number
	if not previousSafeLaneIndex then
		return random:NextInteger(1, #LANE_MULTIPLIERS)
	end

	local minimumLaneChange = if random:NextNumber() < 0.65 then 2 else 1
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

local function get_blocked_lane_indices(
	random: Random,
	safeLaneIndex: number,
	previousSafeLaneIndex: number?
): {number}
	local targetCount = random:NextInteger(MINIMUM_OBSTACLES_PER_SEGMENT, MAXIMUM_OBSTACLES_PER_SEGMENT)
	local blockedLaneIndices: {number} = {}
	if previousSafeLaneIndex and previousSafeLaneIndex ~= safeLaneIndex then
		table.insert(blockedLaneIndices, previousSafeLaneIndex)
	end

	while #blockedLaneIndices < targetCount do
		local candidateLaneIndex = random:NextInteger(1, #LANE_MULTIPLIERS)
		if candidateLaneIndex ~= safeLaneIndex and not table.find(blockedLaneIndices, candidateLaneIndex) then
			table.insert(blockedLaneIndices, candidateLaneIndex)
		end
	end

	return blockedLaneIndices
end

local function generate_obstacles_for_ramp(
	wave: Folder,
	rampPart: BasePart,
	templates: {BasePart},
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

	local segmentCount = math.clamp(
		math.floor(usableLength / TARGET_OBSTACLE_SEGMENT_LENGTH),
		MINIMUM_OBSTACLE_SEGMENTS_PER_RAMP_PART,
		MAXIMUM_OBSTACLE_SEGMENTS_PER_RAMP_PART
	)
	local segmentLength = usableLength / segmentCount
	local segmentLayouts: {SegmentLayout} = {}
	local lastSafeLaneIndex = previousSafeLaneIndex

	for segmentIndex = 1, segmentCount do
		local startDistance = safeStart + (segmentIndex - 1) * segmentLength
		local endDistance = startDistance + segmentLength
		local centerDistance = startDistance + segmentLength * 0.5
		local localY = rampLength * 0.5 - centerDistance
		local safeLaneIndex = choose_safe_lane_index(random, lastSafeLaneIndex)
		table.insert(segmentLayouts, {
			rampPart = rampPart,
			startDistance = startDistance,
			endDistance = endDistance,
			lateralRange = lateralRange,
			safeLaneIndex = safeLaneIndex,
		})

		if generatedCount < MAX_OBSTACLES_PER_WAVE then
			local blockedLaneIndices = get_blocked_lane_indices(random, safeLaneIndex, lastSafeLaneIndex)
			for obstacleIndex, laneIndex in blockedLaneIndices do
				if generatedCount >= MAX_OBSTACLES_PER_WAVE then
					break
				end

				local template = select_template(random, templates, obstacleIndex == 1)
				if template then
					local lateralOffset = LANE_MULTIPLIERS[laneIndex] * lateralRange
					local spawnCFrame = get_surface_cframe(
						rampPart,
						localY,
						lateralOffset,
						template.Size.Y * 0.5 + SURFACE_CLEARANCE
					)
					if spawnCFrame then
						create_obstacle(wave, template, spawnCFrame, worldId, waveId)
						generatedCount += 1
					end
				end
			end
		end

		lastSafeLaneIndex = safeLaneIndex
	end

	return segmentLayouts, generatedCount, lastSafeLaneIndex
end

local function get_safe_lane_offset(segmentLayouts: {SegmentLayout}, distanceFromTop: number): number
	local selectedLayout: SegmentLayout? = nil
	for _, segmentLayout in segmentLayouts do
		selectedLayout = segmentLayout
		if distanceFromTop <= segmentLayout.endDistance then
			break
		end
	end
	if not selectedLayout then
		return 0
	end

	return LANE_MULTIPLIERS[selectedLayout.safeLaneIndex] * selectedLayout.lateralRange
end

local function generate_coin_chains_for_ramp(
	wave: Folder,
	coinTemplate: BasePart,
	segmentLayouts: {SegmentLayout},
	random: Random,
	worldId: number,
	waveId: number
): ()
	if #segmentLayouts == 0 then
		return
	end

	local finalDistance = segmentLayouts[#segmentLayouts].endDistance
	for _ = 1, COIN_CHAINS_PER_RAMP_PART do
		local startSegment = segmentLayouts[random:NextInteger(1, #segmentLayouts)]
		local startMinimum = startSegment.startDistance + COIN_CHAIN_START_PADDING
		local startMaximum = math.max(startMinimum, startSegment.endDistance - COIN_CHAIN_START_PADDING)
		local startDistance = random:NextNumber(startMinimum, startMaximum)
		local maximumCoinCount = math.min(
			MAXIMUM_COINS_PER_CHAIN,
			math.floor((finalDistance - startDistance) / COIN_SPACING) + 1
		)
		if maximumCoinCount < MINIMUM_COINS_PER_CHAIN then
			continue
		end

		local coinCount = random:NextInteger(MINIMUM_COINS_PER_CHAIN, maximumCoinCount)
		local coinScale = random:NextNumber(COIN_MINIMUM_SCALE, COIN_MAXIMUM_SCALE)
		local curveOffset = random:NextNumber(-COIN_MAX_CURVE_OFFSET, COIN_MAX_CURVE_OFFSET)
		local currentLateralOffset = get_safe_lane_offset(segmentLayouts, startDistance)

		for coinIndex = 0, coinCount - 1 do
			local distanceFromTop = startDistance + coinIndex * COIN_SPACING
			local targetLateralOffset = get_safe_lane_offset(segmentLayouts, distanceFromTop)
			if coinIndex > 0 then
				currentLateralOffset += (targetLateralOffset - currentLateralOffset) * COIN_LANE_FOLLOW_ALPHA
			end

			local progress = if coinCount > 1 then coinIndex / (coinCount - 1) else 0
			local curvedLateralOffset = currentLateralOffset + math.sin(progress * math.pi) * curveOffset
			local rampPart = startSegment.rampPart
			local localY = rampPart.Size.Y * 0.5 - distanceFromTop
			local targetSize = coinTemplate.Size * coinScale
			local spawnCFrame = get_surface_cframe(
				rampPart,
				localY,
				curvedLateralOffset,
				targetSize.Y * 0.5 + COIN_SURFACE_CLEARANCE
			)
			if spawnCFrame then
				create_coin(wave, coinTemplate, spawnCFrame, targetSize, worldId, waveId)
			end
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
		local previousSafeLaneIndex: number? = nil
		for _, rampPart in get_ramp_parts(worldId) do
			local segmentLayouts: {SegmentLayout}
			segmentLayouts, generatedCount, previousSafeLaneIndex = generate_obstacles_for_ramp(
				wave,
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
Players.PlayerRemoving:Connect(flush_pending_coin_rewards)

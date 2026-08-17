------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local PLAYER_WORLD_ATTRIBUTE: string = "World"
local EQUIPPED_CART_ATTRIBUTE: string = "EquippedCart"
local IS_RAMP_SLIDING_ATTRIBUTE: string = "IsRampSliding"
local RAMP_MODE_STATE_ATTRIBUTE: string = "RampModeState"
local RAMP_LAUNCH_ACCEPTED_ATTRIBUTE: string = "RampLaunchAccepted"
local RAMP_LAUNCH_POWER_ATTRIBUTE: string = "RampLaunchPower"
local RAMP_WORLD_ATTRIBUTE: string = "RampWorld"
local IS_RAMP_CART_CHARACTER_ATTRIBUTE: string = "IsRampCartCharacter"
local CART_MAX_HEALTH_ATTRIBUTE: string = "CartMaxHealth"
local CART_HEALTH_ATTRIBUTE: string = "CartHealth"
local CART_LAST_IMPACT_ATTRIBUTE: string = "CartLastImpactAt"
local CART_OVERDRIVE_ACTIVE_ATTRIBUTE: string = "CartOverdriveActive"
local CART_JUMP_ACTIVE_ATTRIBUTE: string = "CartJumpActive"
local CART_JUMP_POWER_ATTRIBUTE: string = "CartJumpPower"
local RAMP_LAUNCH_REQUEST_NAME: string = "RampLaunchRequest"
local CART_CONTROL_REQUEST_NAME: string = "CartControlRequest"
local LAUNCH_UPWARD_BOOST_ATTRIBUTE: string = "LaunchUpwardBoost"
local LAUNCH_FORWARD_BOOST_ATTRIBUTE: string = "LaunchForwardBoost"
local CHARGE_STATE: string = "Charge"
local AIRBORNE_STATE: string = "Airborne"
local SLIDE_STATE: string = "Slide"
local MIN_LAUNCH_POWER: number = 0
local MAX_LAUNCH_POWER: number = 1
local DEFAULT_LAUNCH_UPWARD_BOOST: number = 90
local DEFAULT_LAUNCH_FORWARD_BOOST: number = 58
local GROUND_CHECK_DISTANCE: number = 10
local GROUND_LOST_GRACE_PERIOD: number = 0.45
local GROUND_CHECK_INTERVAL: number = 0.1
local AIRBORNE_GRACE_PERIOD: number = 4
local MINIMUM_AIRBORNE_LANDING_DURATION: number = 0.28
local MAXIMUM_LANDING_VERTICAL_SPEED: number = 4
local MAX_CART_HEALTH_ATTRIBUTE: string = "MaxCartHealth"
local DEFAULT_MAX_CART_HEALTH: number = 3
local CLEAN_RUN_DURATION: number = 8
local MIN_CONTROL_REQUEST_INTERVAL: number = 0.12
local JUMP_COOLDOWN_DURATION: number = 1.35
local MINIMUM_JUMP_POWER: number = 0.15
local MAXIMUM_JUMP_POWER: number = 1
local MINIMUM_JUMP_UPWARD_BOOST: number = 72
local MAXIMUM_JUMP_UPWARD_BOOST: number = 112

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local serverModules: Folder = ServerStorage:WaitForChild("Modules")
local rampUtility = require(replicatedModules:WaitForChild("Gameplay"):WaitForChild("RampUtility"))
local rampCharacterService = require(serverModules:WaitForChild("RampCharacterService"))

------------------//VARIABLES
type ActiveSlide = {
	character: Model,
	originalCharacter: Model?,
	launchArea: BasePart,
	lastGroundedAt: number,
	launchedAt: number,
	canLaunch: boolean,
	launchRequested: boolean,
	cleanRunElapsed: number,
	lastImpactAt: number,
	lastControlRequestAt: number,
	lastJumpAt: number,
	cleanRunRecorded: boolean,
}

local registeredJumpAreas: {[BasePart]: boolean} = {}
local activeSlidesByPlayer: {[Player]: ActiveSlide} = {}
local groundCheckElapsed: number = 0
local launchRequest: RemoteEvent
local cartControlRequest: RemoteEvent
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

------------------//FUNCTIONS
local function ensure_launch_request(): RemoteEvent
	local existingRemote = ReplicatedStorage:FindFirstChild(RAMP_LAUNCH_REQUEST_NAME)
	if existingRemote then
		if not existingRemote:IsA("RemoteEvent") then
			error(("%s precisa ser um RemoteEvent"):format(existingRemote:GetFullName()))
		end
		return existingRemote
	end

	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = RAMP_LAUNCH_REQUEST_NAME
	newRemote.Parent = ReplicatedStorage
	return newRemote
end

local function ensure_cart_control_request(): RemoteEvent
	local existingRemote = ReplicatedStorage:FindFirstChild(CART_CONTROL_REQUEST_NAME)
	if existingRemote then
		if not existingRemote:IsA("RemoteEvent") then
			error(("%s precisa ser um RemoteEvent"):format(existingRemote:GetFullName()))
		end
		return existingRemote
	end

	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = CART_CONTROL_REQUEST_NAME
	newRemote.Parent = ReplicatedStorage
	return newRemote
end

local function get_cart_number_attribute(player: Player, attributeName: string, fallback: number): number
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local carts = assets and assets:FindFirstChild("Carts")
	local equippedCart = player:GetAttribute(EQUIPPED_CART_ATTRIBUTE)
	local cart = carts and carts:FindFirstChild(if type(equippedCart) == "string" then equippedCart else "Default")
	local value = cart and cart:GetAttribute(attributeName)
	if type(value) == "number" and value > 0 and value == value and value ~= math.huge then
		return value
	end

	return fallback
end

local function get_max_cart_health(player: Player): number
	return math.max(
		math.floor(get_cart_number_attribute(player, MAX_CART_HEALTH_ATTRIBUTE, DEFAULT_MAX_CART_HEALTH)),
		1
	)
end

local function restore_original_character(player: Player, slide: ActiveSlide): ()
	local originalCharacter = slide.originalCharacter
	if not originalCharacter or not originalCharacter.Parent then
		return
	end

	originalCharacter:SetAttribute(IS_RAMP_SLIDING_ATTRIBUTE, false)
	originalCharacter:SetAttribute(RAMP_WORLD_ATTRIBUTE, nil)
	rampCharacterService.restore(player, slide.character, originalCharacter)
end

local function set_character_root_anchored(character: Model, isAnchored: boolean): ()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.Anchored = isAnchored
		if isAnchored then
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function stop_sliding(player: Player): ()
	local slide = activeSlidesByPlayer[player]
	activeSlidesByPlayer[player] = nil

	if slide and slide.character.Parent then
		slide.character:SetAttribute(IS_RAMP_SLIDING_ATTRIBUTE, false)
		slide.character:SetAttribute(RAMP_WORLD_ATTRIBUTE, nil)
		slide.character:SetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE, false)
		slide.character:SetAttribute(CART_JUMP_ACTIVE_ATTRIBUTE, false)
		slide.character:SetAttribute(CART_JUMP_POWER_ATTRIBUTE, nil)
	end

	if slide then
		restore_original_character(player, slide)
	end
end

local function begin_sliding(player: Player, character: Model, launchArea: BasePart, launchAreaWorld: number): ()
	if activeSlidesByPlayer[player] then
		activeSlidesByPlayer[player].lastGroundedAt = os.clock()
		return
	end

	local characterSwap = rampCharacterService.create(player, character, launchArea)
	local activeCharacter = if characterSwap then characterSwap.character else character
	local originalCharacter = if characterSwap then characterSwap.originalCharacter else nil
	local currentTime = os.clock()
	local maxCartHealth = get_max_cart_health(player)
	activeSlidesByPlayer[player] = {
		character = activeCharacter,
		originalCharacter = originalCharacter,
		launchArea = launchArea,
		lastGroundedAt = os.clock(),
		launchedAt = 0,
		canLaunch = characterSwap ~= nil,
		launchRequested = false,
		cleanRunElapsed = 0,
		lastImpactAt = currentTime,
		lastControlRequestAt = -math.huge,
		lastJumpAt = -math.huge,
		cleanRunRecorded = false,
	}

	activeCharacter:SetAttribute(IS_RAMP_SLIDING_ATTRIBUTE, true)
	activeCharacter:SetAttribute(RAMP_WORLD_ATTRIBUTE, launchAreaWorld)
	activeCharacter:SetAttribute(RAMP_LAUNCH_ACCEPTED_ATTRIBUTE, false)
	activeCharacter:SetAttribute(RAMP_LAUNCH_POWER_ATTRIBUTE, MIN_LAUNCH_POWER)
	activeCharacter:SetAttribute(CART_MAX_HEALTH_ATTRIBUTE, maxCartHealth)
	activeCharacter:SetAttribute(CART_HEALTH_ATTRIBUTE, maxCartHealth)
	activeCharacter:SetAttribute(CART_LAST_IMPACT_ATTRIBUTE, currentTime)
	activeCharacter:SetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE, false)
	activeCharacter:SetAttribute(CART_JUMP_ACTIVE_ATTRIBUTE, false)
	activeCharacter:SetAttribute(CART_JUMP_POWER_ATTRIBUTE, 0)
	activeCharacter:SetAttribute(
		RAMP_MODE_STATE_ATTRIBUTE,
		if characterSwap then CHARGE_STATE else SLIDE_STATE
	)
	if characterSwap then
		set_character_root_anchored(activeCharacter, true)
	end
end

local function on_launch_request(player: Player, requestedPower: number): ()
	if type(requestedPower) ~= "number" or requestedPower ~= requestedPower then
		return
	end

	local slide = activeSlidesByPlayer[player]
	if not slide
		or not slide.canLaunch
		or slide.launchRequested
		or player.Character ~= slide.character
		or slide.character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) ~= CHARGE_STATE
	then
		return
	end

	slide.launchRequested = true
	slide.launchedAt = os.clock()
	slide.cleanRunElapsed = 0
	slide.character:SetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE, false)
	set_character_root_anchored(slide.character, false)
	local launchPower = math.clamp(requestedPower, MIN_LAUNCH_POWER, MAX_LAUNCH_POWER)
	local rootPart = slide.character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		local surfaceNormal = slide.launchArea.CFrame.UpVector
		local forwardDirection = rootPart.CFrame.LookVector - surfaceNormal * rootPart.CFrame.LookVector:Dot(surfaceNormal)
		if forwardDirection.Magnitude < 0.01 then
			forwardDirection = rootPart.CFrame.LookVector
		end
		local upwardBoost = get_cart_number_attribute(player, LAUNCH_UPWARD_BOOST_ATTRIBUTE, DEFAULT_LAUNCH_UPWARD_BOOST)
		local forwardBoost = get_cart_number_attribute(player, LAUNCH_FORWARD_BOOST_ATTRIBUTE, DEFAULT_LAUNCH_FORWARD_BOOST)
		local boostScale = 0.75 + launchPower * 0.25
		rootPart.AssemblyLinearVelocity = forwardDirection.Unit * forwardBoost * boostScale
			+ Vector3.yAxis * upwardBoost * boostScale
	end
	slide.character:SetAttribute(RAMP_LAUNCH_POWER_ATTRIBUTE, launchPower)
	slide.character:SetAttribute(RAMP_LAUNCH_ACCEPTED_ATTRIBUTE, true)
	slide.character:SetAttribute(RAMP_MODE_STATE_ATTRIBUTE, AIRBORNE_STATE)
end

local function on_cart_control_request(player: Player, controlName: string, controlValue: number?): ()
	local slide = activeSlidesByPlayer[player]
	if not slide or player.Character ~= slide.character then
		return
	end

	local currentTime = os.clock()
	if controlName == "Shift" then
		if currentTime - slide.lastControlRequestAt < MIN_CONTROL_REQUEST_INTERVAL then
			return
		end

		slide.lastControlRequestAt = currentTime
		slide.cleanRunElapsed = 0
		slide.character:SetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE, false)
		return
	end

	if controlName ~= "Jump"
		or type(controlValue) ~= "number"
		or controlValue ~= controlValue
		or slide.character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) ~= SLIDE_STATE
		or currentTime - slide.lastJumpAt < JUMP_COOLDOWN_DURATION
	then
		return
	end

	local rootPart = slide.character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local jumpPower = math.clamp(controlValue, MINIMUM_JUMP_POWER, MAXIMUM_JUMP_POWER)
	local upwardBoost = MINIMUM_JUMP_UPWARD_BOOST
		+ (MAXIMUM_JUMP_UPWARD_BOOST - MINIMUM_JUMP_UPWARD_BOOST) * jumpPower
	slide.lastJumpAt = currentTime
	slide.launchedAt = currentTime
	slide.lastGroundedAt = currentTime
	slide.cleanRunElapsed = 0
	slide.character:SetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE, false)
	slide.character:SetAttribute(CART_JUMP_ACTIVE_ATTRIBUTE, true)
	slide.character:SetAttribute(CART_JUMP_POWER_ATTRIBUTE, jumpPower)
	slide.character:SetAttribute(RAMP_LAUNCH_ACCEPTED_ATTRIBUTE, false)
	slide.character:SetAttribute(RAMP_MODE_STATE_ATTRIBUTE, AIRBORNE_STATE)
	rootPart.AssemblyLinearVelocity += Vector3.yAxis * upwardBoost
	game:GetService("ServerStorage"):WaitForChild("QuestEvents"):WaitForChild("RecordEvent"):Fire(player, "Jump", 1)
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

local function on_jump_area_touched(jumpArea: BasePart, hitPart: BasePart): ()
	if not rampUtility.is_jump_area(jumpArea) then
		return
	end

	local player, character = get_player_from_hit(hitPart)
	if not player or not character then
		return
	end

	local playerWorld = player:GetAttribute(PLAYER_WORLD_ATTRIBUTE)
	local jumpAreaWorld = rampUtility.get_world_id(jumpArea)
	if type(playerWorld) ~= "number" or playerWorld ~= jumpAreaWorld then
		return
	end

	begin_sliding(player, character, jumpArea, jumpAreaWorld)
end

local function register_jump_area_part(jumpArea: BasePart): ()
	if registeredJumpAreas[jumpArea] then
		return
	end

	registeredJumpAreas[jumpArea] = true
	jumpArea.Touched:Connect(function(hitPart: BasePart)
		on_jump_area_touched(jumpArea, hitPart)
	end)
	jumpArea.Destroying:Once(function()
		registeredJumpAreas[jumpArea] = nil
	end)
end

local function register_jump_area_instance(instance: Instance): ()
	if instance:IsA("BasePart") and rampUtility.is_jump_area(instance) then
		register_jump_area_part(instance)
	end

	if string.lower(instance.Name) == "jumparea" then
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("BasePart") then
				register_jump_area_part(descendant)
			end
		end
	end
end

local function is_player_on_launch_surface(player: Player, slide: ActiveSlide): boolean
	local rootPart = slide.character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	raycastParams.FilterDescendantsInstances = {slide.character}
	local result = workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -GROUND_CHECK_DISTANCE, 0),
		raycastParams
	)
	if not result or not (rampUtility.is_ramp(result.Instance) or rampUtility.is_jump_area(result.Instance)) then
		return false
	end

	local playerWorld = player:GetAttribute(PLAYER_WORLD_ATTRIBUTE)
	return type(playerWorld) == "number" and playerWorld == rampUtility.get_world_id(result.Instance)
end

local function try_land_airborne_slide(player: Player, slide: ActiveSlide, currentTime: number): boolean
	if currentTime - slide.launchedAt < MINIMUM_AIRBORNE_LANDING_DURATION
		or not is_player_on_launch_surface(player, slide)
	then
		return false
	end

	local rootPart = slide.character:FindFirstChild("HumanoidRootPart")
	if not rootPart
		or not rootPart:IsA("BasePart")
		or rootPart.AssemblyLinearVelocity.Y > MAXIMUM_LANDING_VERTICAL_SPEED
	then
		return false
	end

	slide.character:SetAttribute(RAMP_LAUNCH_ACCEPTED_ATTRIBUTE, false)
	slide.character:SetAttribute(CART_JUMP_ACTIVE_ATTRIBUTE, false)
	slide.character:SetAttribute(RAMP_MODE_STATE_ATTRIBUTE, SLIDE_STATE)
	return true
end

------------------//MAIN FUNCTIONS
local function on_player_added(player: Player): ()
	player.CharacterAdded:Connect(function(character: Model)
		if character:GetAttribute(IS_RAMP_CART_CHARACTER_ATTRIBUTE) == true then
			return
		end

		local interruptedSlide = activeSlidesByPlayer[player]
		if interruptedSlide then
			activeSlidesByPlayer[player] = nil
			rampCharacterService.destroy(interruptedSlide.character, interruptedSlide.originalCharacter)
		end
		character:SetAttribute(IS_RAMP_SLIDING_ATTRIBUTE, false)
		task.defer(rampCharacterService.prepare, player, character)
	end)

	player.CharacterAppearanceLoaded:Connect(function(character: Model)
		task.defer(rampCharacterService.prepare, player, character, true)
	end)

	player:GetAttributeChangedSignal(EQUIPPED_CART_ATTRIBUTE):Connect(function()
		local character = player.Character
		if character and character:GetAttribute(IS_RAMP_CART_CHARACTER_ATTRIBUTE) ~= true then
			task.defer(rampCharacterService.prepare, player, character)
		end
	end)

	if player.Character then
		player.Character:SetAttribute(IS_RAMP_SLIDING_ATTRIBUTE, false)
		task.defer(rampCharacterService.prepare, player, player.Character)
	end
end

local function on_player_removing(player: Player): ()
	local slide = activeSlidesByPlayer[player]
	activeSlidesByPlayer[player] = nil
	if slide then
		rampCharacterService.destroy(slide.character, slide.originalCharacter)
	end

	rampCharacterService.clear(player)
end

local function update_active_slides(deltaTime: number): ()
	groundCheckElapsed += deltaTime
	if groundCheckElapsed < GROUND_CHECK_INTERVAL then
		return
	end
	local slideDeltaTime = groundCheckElapsed
	groundCheckElapsed = 0

	local currentTime = os.clock()
	for player, slide in activeSlidesByPlayer do
		local modeState = slide.character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE)
		if modeState == SLIDE_STATE and slide.character:GetAttribute(CART_JUMP_ACTIVE_ATTRIBUTE) == true then
			slide.character:SetAttribute(CART_JUMP_ACTIVE_ATTRIBUTE, false)
		end
		local lastImpactAt = slide.character:GetAttribute(CART_LAST_IMPACT_ATTRIBUTE)
		if type(lastImpactAt) == "number" and lastImpactAt > slide.lastImpactAt then
			slide.lastImpactAt = lastImpactAt
			slide.cleanRunElapsed = 0
			slide.character:SetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE, false)
		elseif modeState == SLIDE_STATE then
			slide.cleanRunElapsed += slideDeltaTime
		end

		local shouldEnableOverdrive = modeState == SLIDE_STATE and slide.cleanRunElapsed >= CLEAN_RUN_DURATION
		if slide.character:GetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE) ~= shouldEnableOverdrive then
			slide.character:SetAttribute(CART_OVERDRIVE_ACTIVE_ATTRIBUTE, shouldEnableOverdrive)
			if shouldEnableOverdrive and not slide.cleanRunRecorded then
				slide.cleanRunRecorded = true
				game:GetService("ServerStorage"):WaitForChild("QuestEvents"):WaitForChild("RecordEvent"):Fire(player, "CleanRun", 1)
			end
		end

		if player.Character ~= slide.character or not slide.character.Parent then
			stop_sliding(player)
		elseif modeState == CHARGE_STATE and slide.launchArea.Parent then
			slide.lastGroundedAt = currentTime
		elseif modeState == AIRBORNE_STATE and try_land_airborne_slide(player, slide, currentTime) then
			slide.lastGroundedAt = currentTime
		elseif is_player_on_launch_surface(player, slide) then
			slide.lastGroundedAt = currentTime
		elseif modeState == AIRBORNE_STATE
			and slide.launchedAt > 0
			and currentTime - slide.launchedAt < AIRBORNE_GRACE_PERIOD
		then
			continue
		elseif currentTime - slide.lastGroundedAt >= GROUND_LOST_GRACE_PERIOD then
			local cartHealth = slide.character:GetAttribute(CART_HEALTH_ATTRIBUTE)
			if slide.launchedAt > 0 and type(cartHealth) == "number" and cartHealth > 0 then
				game:GetService("ServerStorage"):WaitForChild("QuestEvents"):WaitForChild("RecordEvent"):Fire(player, "WorldFinished", 1)
			end
			stop_sliding(player)
		end
	end
end

------------------//INIT
launchRequest = ensure_launch_request()
cartControlRequest = ensure_cart_control_request()

for _, descendant in workspace:GetDescendants() do
	register_jump_area_instance(descendant)
end

for _, player in Players:GetPlayers() do
	on_player_added(player)
end

workspace.DescendantAdded:Connect(register_jump_area_instance)
	Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(on_player_removing)
launchRequest.OnServerEvent:Connect(on_launch_request)
cartControlRequest.OnServerEvent:Connect(on_cart_control_request)
RunService.Heartbeat:Connect(update_active_slides)

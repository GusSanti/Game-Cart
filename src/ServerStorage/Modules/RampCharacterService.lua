------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")
local StarterPlayer: StarterPlayer = game:GetService("StarterPlayer")

------------------//CONSTANTS
local EQUIPPED_CART_ATTRIBUTE: string = "EquippedCart"
local DEFAULT_CART_NAME: string = "Default"
local IS_RAMP_CART_CHARACTER_ATTRIBUTE: string = "IsRampCartCharacter"
local PLAYER_MODEL_NAME: string = "PlayerModel"
local CART_MODEL_NAME: string = "Model"
local CHARACTERS_FOLDER_NAME: string = "Characters"
local RAMP_CHARACTER_CACHE_NAME: string = "RampCharacterCache"
local PREPARED_RAMP_CHARACTERS_FOLDER_NAME: string = "PreparedRampCharacters"
local RAMP_SLIDING_SCRIPT_NAME: string = "RampSliding"
local RAMP_CART_WELD_NAME: string = "RampCartWeld"
local RAMP_CART_COLLIDER_NAME: string = "RampCartCollider"
local RAMP_CART_GROUND_CLEARANCE_ATTRIBUTE: string = "RampCartGroundClearance"
local RAMP_ENTRY_BOOST_SPEED_ATTRIBUTE: string = "RampEntryBoostSpeed"
local JUMP_AREA_NAME: string = "JumpArea"
local ENTRY_FORWARD_BOOST_SPEED: number = 12
local ENTRY_GROUND_CHECK_HEIGHT: number = 4
local ENTRY_GROUND_CHECK_DISTANCE: number = 16
local SURFACE_ALIGNMENT_CHECK_DISTANCE: number = 64
local CART_COLLIDER_HEIGHT: number = 0.35
local TARGET_CART_SURFACE_CLEARANCE: number = 0.05
local MIN_CART_COLLIDER_SIZE: number = 0.5
local MIN_DIRECTION_MAGNITUDE: number = 0.01

------------------//VARIABLES
type CharacterSwap = {
	character: Model,
	originalCharacter: Model,
}

type PreparedCharacterSwap = CharacterSwap & {
	sourceCharacter: Model,
	cartName: string,
}

local rampCharacterService = {}
local preparedByPlayer: {[Player]: PreparedCharacterSwap} = {}
local charactersFolder: Folder
local rampCharacterCache: Folder
local preparedRampCharactersFolder: Folder

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

local function get_equipped_cart_name(player: Player): string
	local equippedCartName = player:GetAttribute(EQUIPPED_CART_ATTRIBUTE)
	if type(equippedCartName) == "string" and equippedCartName ~= "" then
		return equippedCartName
	end

	return DEFAULT_CART_NAME
end

local function get_equipped_cart_asset(player: Player): (Model?, string)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local carts = assets and assets:FindFirstChild("Carts")
	local equippedCartName = get_equipped_cart_name(player)
	if not carts then
		return nil, equippedCartName
	end

	local cart = carts:FindFirstChild(equippedCartName) or carts:FindFirstChild(DEFAULT_CART_NAME)
	if cart and cart:IsA("Model") then
		return cart, cart.Name
	end

	return nil, equippedCartName
end

local function is_transferable_appearance(instance: Instance): boolean
	return instance:IsA("Shirt")
		or instance:IsA("Pants")
		or instance:IsA("ShirtGraphic")
		or instance:IsA("BodyColors")
		or instance:IsA("CharacterMesh")
end

local function clear_character_appearance(character: Model): ()
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") or is_transferable_appearance(child) then
			child:Destroy()
		end
	end
end

local function clone_accessory(accessory: Accessory, targetHumanoid: Humanoid): ()
	local accessoryClone = accessory:Clone()
	local handle = accessoryClone:FindFirstChild("Handle")
	local accessoryWeld = handle and handle:FindFirstChild("AccessoryWeld")
	if accessoryWeld then
		accessoryWeld:Destroy()
	end
	targetHumanoid:AddAccessory(accessoryClone)
end

local function copy_character_appearance(
	sourceCharacter: Model,
	targetCharacter: Model,
	targetHumanoid: Humanoid
): ()
	clear_character_appearance(targetCharacter)

	for _, child in sourceCharacter:GetChildren() do
		if child:IsA("Accessory") then
			clone_accessory(child, targetHumanoid)
		elseif is_transferable_appearance(child) then
			child:Clone().Parent = targetCharacter
		end
	end

	local sourceHead = sourceCharacter:FindFirstChild("Head")
	local targetHead = targetCharacter:FindFirstChild("Head")
	local sourceFace = sourceHead and sourceHead:FindFirstChildWhichIsA("Decal")
	local targetFace = targetHead and targetHead:FindFirstChildWhichIsA("Decal")
	if sourceFace and targetHead then
		if targetFace then
			targetFace:Destroy()
		end
		sourceFace:Clone().Parent = targetHead
	end
end

local function enable_character_motors(character: Model): ()
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1 then
			descendant.Enabled = true
		end
	end
end

local function get_local_part_half_extents(part: BasePart, relativeCFrame: CFrame): Vector3
	local halfSize = part.Size * 0.5
	return Vector3.new(
		math.abs(relativeCFrame.RightVector.X) * halfSize.X
			+ math.abs(relativeCFrame.UpVector.X) * halfSize.Y
			+ math.abs(relativeCFrame.LookVector.X) * halfSize.Z,
		math.abs(relativeCFrame.RightVector.Y) * halfSize.X
			+ math.abs(relativeCFrame.UpVector.Y) * halfSize.Y
			+ math.abs(relativeCFrame.LookVector.Y) * halfSize.Z,
		math.abs(relativeCFrame.RightVector.Z) * halfSize.X
			+ math.abs(relativeCFrame.UpVector.Z) * halfSize.Y
			+ math.abs(relativeCFrame.LookVector.Z) * halfSize.Z
	)
end

local function create_cart_collider(playerModel: Model, cartModel: Instance, rootPart: BasePart): ()
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	local hasVisualPart = false

	for _, descendant in cartModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			hasVisualPart = true
			local relativeCFrame = rootPart.CFrame:ToObjectSpace(descendant.CFrame)
			local halfExtents = get_local_part_half_extents(descendant, relativeCFrame)
			local partMinimum = relativeCFrame.Position - halfExtents
			local partMaximum = relativeCFrame.Position + halfExtents
			minimum = Vector3.new(
				math.min(minimum.X, partMinimum.X),
				math.min(minimum.Y, partMinimum.Y),
				math.min(minimum.Z, partMinimum.Z)
			)
			maximum = Vector3.new(
				math.max(maximum.X, partMaximum.X),
				math.max(maximum.Y, partMaximum.Y),
				math.max(maximum.Z, partMaximum.Z)
			)
		end
	end

	if not hasVisualPart then
		return
	end

	local collider = Instance.new("Part")
	collider.Name = RAMP_CART_COLLIDER_NAME
	collider.Size = Vector3.new(
		math.max(maximum.X - minimum.X, MIN_CART_COLLIDER_SIZE),
		CART_COLLIDER_HEIGHT,
		math.max(maximum.Z - minimum.Z, MIN_CART_COLLIDER_SIZE)
	)
	collider.CFrame = rootPart.CFrame * CFrame.new(
		(minimum.X + maximum.X) * 0.5,
		minimum.Y + CART_COLLIDER_HEIGHT * 0.5,
		(minimum.Z + maximum.Z) * 0.5
	)
	collider.Transparency = 1
	collider.CastShadow = false
	collider.CanCollide = true
	collider.CanTouch = true
	collider.CanQuery = true
	collider.Massless = true
	collider.Parent = playerModel
	playerModel:SetAttribute(RAMP_CART_GROUND_CLEARANCE_ATTRIBUTE, math.max(-minimum.Y, 0))

	local weld = Instance.new("WeldConstraint")
	weld.Name = RAMP_CART_WELD_NAME
	weld.Part0 = rootPart
	weld.Part1 = collider
	weld.Parent = rootPart
end

local function prepare_cart_physics(playerModel: Model, cartModel: Instance, rootPart: BasePart): ()
	for _, descendant in cartModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true

			local weld = Instance.new("WeldConstraint")
			weld.Name = RAMP_CART_WELD_NAME
			weld.Part0 = rootPart
			weld.Part1 = descendant
			weld.Parent = rootPart
		end
	end

	create_cart_collider(playerModel, cartModel, rootPart)
	enable_character_motors(playerModel)
end

local function freeze_character(character: Model, parent: Instance): ()
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
			descendant.Anchored = true
		end
	end
	character.Parent = parent
end

local function unfreeze_character(character: Model): ()
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
end

local function clone_character(character: Model): Model
	local wasArchivable = character.Archivable
	character.Archivable = true
	local characterClone = character:Clone()
	character.Archivable = wasArchivable
	characterClone.Name = character.Name
	return characterClone
end

local function clone_ramp_sliding_script(sourceCharacter: Model, targetCharacter: Model): ()
	local template = sourceCharacter:FindFirstChild(RAMP_SLIDING_SCRIPT_NAME)
		or StarterPlayer:WaitForChild("StarterCharacterScripts"):FindFirstChild(RAMP_SLIDING_SCRIPT_NAME)
	if template and template:IsA("LocalScript") then
		template:Clone().Parent = targetCharacter
	end
end

local function build_cart_character(player: Player, sourceCharacter: Model, cartAsset: Model): Model?
	local cartClone = cartAsset:Clone()
	local playerModel = cartClone:FindFirstChild(PLAYER_MODEL_NAME)
	local cartModel = cartClone:FindFirstChild(CART_MODEL_NAME)
	if not playerModel or not playerModel:IsA("Model") or not cartModel then
		cartClone:Destroy()
		return nil
	end

	local rootPart = playerModel:FindFirstChild("HumanoidRootPart")
	local humanoid = playerModel:FindFirstChildOfClass("Humanoid")
	if not rootPart or not rootPart:IsA("BasePart") or not humanoid then
		cartClone:Destroy()
		return nil
	end

	playerModel.Parent = nil
	cartModel.Parent = playerModel
	cartClone:Destroy()

	playerModel.Name = player.Name
	playerModel.PrimaryPart = rootPart
	playerModel:SetAttribute(IS_RAMP_CART_CHARACTER_ATTRIBUTE, true)
	copy_character_appearance(sourceCharacter, playerModel, humanoid)
	prepare_cart_physics(playerModel, cartModel, rootPart)
	clone_ramp_sliding_script(sourceCharacter, playerModel)
	return playerModel
end

local function destroy_character(character: Model?): ()
	if character and character.Parent then
		character:Destroy()
	end
end

local function discard_prepared_swap(player: Player): ()
	local preparedSwap = preparedByPlayer[player]
	preparedByPlayer[player] = nil
	if not preparedSwap then
		return
	end

	destroy_character(preparedSwap.character)
	destroy_character(preparedSwap.originalCharacter)
end

local function build_prepared_swap(player: Player, sourceCharacter: Model): PreparedCharacterSwap?
	local cartAsset, cartName = get_equipped_cart_asset(player)
	if not cartAsset then
		return nil
	end

	local cartCharacter = build_cart_character(player, sourceCharacter, cartAsset)
	if not cartCharacter then
		return nil
	end

	local originalCharacter = clone_character(sourceCharacter)
	enable_character_motors(originalCharacter)
	freeze_character(originalCharacter, rampCharacterCache)
	freeze_character(cartCharacter, preparedRampCharactersFolder)

	return {
		character = cartCharacter,
		originalCharacter = originalCharacter,
		sourceCharacter = sourceCharacter,
		cartName = cartName,
	}
end

local function project_onto_plane(vector: Vector3, normal: Vector3): Vector3
	return vector - normal * vector:Dot(normal)
end

local function get_entry_cframe(
	cartCharacter: Model,
	sourceRootPart: BasePart,
	rampPart: BasePart,
	fallbackCFrame: CFrame
): CFrame
	if string.lower(rampPart.Name) == string.lower(JUMP_AREA_NAME) then
		local jumpAreaRaycastParams = RaycastParams.new()
		jumpAreaRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
		jumpAreaRaycastParams.FilterDescendantsInstances = {cartCharacter, sourceRootPart.Parent, rampPart}
		local groundResult = workspace:Raycast(
			sourceRootPart.Position + Vector3.yAxis * ENTRY_GROUND_CHECK_HEIGHT,
			-Vector3.yAxis * SURFACE_ALIGNMENT_CHECK_DISTANCE,
			jumpAreaRaycastParams
		)
		if not groundResult then
			return sourceRootPart.CFrame
		end

		local surfaceNormal = groundResult.Normal
		local forwardDirection = project_onto_plane(sourceRootPart.CFrame.LookVector, surfaceNormal)
		if forwardDirection.Magnitude < MIN_DIRECTION_MAGNITUDE then
			forwardDirection = project_onto_plane(sourceRootPart.AssemblyLinearVelocity, surfaceNormal)
		end
		if forwardDirection.Magnitude < MIN_DIRECTION_MAGNITUDE then
			return fallbackCFrame
		end

		local entryPosition = sourceRootPart.Position
		return CFrame.lookAt(entryPosition, entryPosition + forwardDirection.Unit, surfaceNormal)
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = {rampPart}
	local raycastResult = workspace:Raycast(
		sourceRootPart.Position + Vector3.yAxis * ENTRY_GROUND_CHECK_HEIGHT,
		-Vector3.yAxis * SURFACE_ALIGNMENT_CHECK_DISTANCE,
		raycastParams
	)
	if not raycastResult then
		return fallbackCFrame
	end

	local surfaceNormal = raycastResult.Normal
	local forwardDirection = project_onto_plane(sourceRootPart.CFrame.LookVector, surfaceNormal)
	if forwardDirection.Magnitude < MIN_DIRECTION_MAGNITUDE then
		forwardDirection = project_onto_plane(sourceRootPart.AssemblyLinearVelocity, surfaceNormal)
	end
	if forwardDirection.Magnitude < MIN_DIRECTION_MAGNITUDE then
		return fallbackCFrame
	end

	local groundClearance = cartCharacter:GetAttribute(RAMP_CART_GROUND_CLEARANCE_ATTRIBUTE)
	if type(groundClearance) ~= "number" then
		groundClearance = 0
	end
	local currentClearance = math.max((sourceRootPart.Position - raycastResult.Position):Dot(surfaceNormal), 0)
	local clearanceAdjustment = math.max(groundClearance - currentClearance, 0)
	local entryPosition = sourceRootPart.Position + surfaceNormal * clearanceAdjustment
	return CFrame.lookAt(entryPosition, entryPosition + forwardDirection.Unit, surfaceNormal)
end

local function lift_cart_from_surface(cartCharacter: Model, cartRootPart: BasePart, launchArea: BasePart): ()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {charactersFolder, launchArea}
	local groundResult = workspace:Raycast(
		cartRootPart.Position + Vector3.yAxis * ENTRY_GROUND_CHECK_HEIGHT,
		-Vector3.yAxis * ENTRY_GROUND_CHECK_DISTANCE,
		raycastParams
	)
	if not groundResult then
		return
	end

	local collider = cartCharacter:FindFirstChild(RAMP_CART_COLLIDER_NAME, true)
	if not collider or not collider:IsA("BasePart") then
		return
	end

	local surfaceNormal = groundResult.Normal
	local halfExtent = math.abs(collider.CFrame.RightVector:Dot(surfaceNormal)) * collider.Size.X * 0.5
		+ math.abs(collider.CFrame.UpVector:Dot(surfaceNormal)) * collider.Size.Y * 0.5
		+ math.abs(collider.CFrame.LookVector:Dot(surfaceNormal)) * collider.Size.Z * 0.5
	local contactPosition = collider.Position - surfaceNormal * halfExtent
	local signedClearance = (contactPosition - groundResult.Position):Dot(surfaceNormal)
	local correction = TARGET_CART_SURFACE_CLEARANCE - signedClearance
	if math.abs(correction) < 0.01 then
		return
	end

	cartCharacter:PivotTo(cartCharacter:GetPivot() + surfaceNormal * correction)
end

------------------//MAIN FUNCTIONS
function rampCharacterService.prepare(player: Player, sourceCharacter: Model, forceRefresh: boolean?): ()
	if player.Character ~= sourceCharacter
		or not sourceCharacter.Parent
		or sourceCharacter:GetAttribute(IS_RAMP_CART_CHARACTER_ATTRIBUTE) == true
	then
		return
	end

	local _, equippedCartName = get_equipped_cart_asset(player)
	local existingSwap = preparedByPlayer[player]
	if not forceRefresh
		and existingSwap
		and existingSwap.sourceCharacter == sourceCharacter
		and existingSwap.cartName == equippedCartName
		and existingSwap.character.Parent
		and existingSwap.originalCharacter.Parent
	then
		return
	end

	discard_prepared_swap(player)
	local preparedSwap = build_prepared_swap(player, sourceCharacter)
	if player.Character ~= sourceCharacter or not sourceCharacter.Parent then
		if preparedSwap then
			destroy_character(preparedSwap.character)
			destroy_character(preparedSwap.originalCharacter)
		end
		return
	end

	preparedByPlayer[player] = preparedSwap
end

function rampCharacterService.create(
	player: Player,
	sourceCharacter: Model,
	launchArea: BasePart
): CharacterSwap?
	local _, equippedCartName = get_equipped_cart_asset(player)
	local preparedSwap = preparedByPlayer[player]
	if preparedSwap
		and (
			preparedSwap.sourceCharacter ~= sourceCharacter
			or preparedSwap.cartName ~= equippedCartName
			or not preparedSwap.character.Parent
			or not preparedSwap.originalCharacter.Parent
		)
	then
		discard_prepared_swap(player)
		preparedSwap = nil
	end

	if not preparedSwap then
		preparedSwap = build_prepared_swap(player, sourceCharacter)
	end
	if not preparedSwap then
		return nil
	end
	preparedByPlayer[player] = nil

	local cartCharacter = preparedSwap.character
	local originalCharacter = preparedSwap.originalCharacter
	local sourceRootPart = sourceCharacter:FindFirstChild("HumanoidRootPart")
	local cartRootPart = cartCharacter:FindFirstChild("HumanoidRootPart")
	if not sourceRootPart
		or not sourceRootPart:IsA("BasePart")
		or not cartRootPart
		or not cartRootPart:IsA("BasePart")
	then
		destroy_character(cartCharacter)
		destroy_character(originalCharacter)
		return nil
	end

	local sourcePivot = sourceCharacter:GetPivot()
	local entryCFrame = get_entry_cframe(cartCharacter, sourceRootPart, launchArea, sourcePivot)
	originalCharacter:PivotTo(sourcePivot)
	cartCharacter:PivotTo(entryCFrame)
	cartCharacter:SetAttribute(RAMP_ENTRY_BOOST_SPEED_ATTRIBUTE, ENTRY_FORWARD_BOOST_SPEED)
	cartCharacter.Parent = charactersFolder
	unfreeze_character(cartCharacter)
	cartRootPart:SetNetworkOwner(player)
	cartRootPart.Anchored = true
	lift_cart_from_surface(cartCharacter, cartRootPart, launchArea)
	cartRootPart.AssemblyLinearVelocity = sourceRootPart.AssemblyLinearVelocity
	cartRootPart.AssemblyAngularVelocity = Vector3.zero
	player.Character = cartCharacter
	destroy_character(sourceCharacter)

	return {
		character = cartCharacter,
		originalCharacter = originalCharacter,
	}
end

function rampCharacterService.restore(player: Player, cartCharacter: Model, originalCharacter: Model): ()
	if not originalCharacter.Parent then
		return
	end

	local cartRootPart = cartCharacter:FindFirstChild("HumanoidRootPart")
	local originalPivot = if cartCharacter.Parent
		then cartCharacter:GetPivot()
		else originalCharacter:GetPivot()
	local originalPosition = originalPivot.Position
	local horizontalLook = Vector3.new(originalPivot.LookVector.X, 0, originalPivot.LookVector.Z)
	local restorationPivot = if horizontalLook.Magnitude > MIN_DIRECTION_MAGNITUDE
		then CFrame.lookAt(originalPosition, originalPosition + horizontalLook.Unit)
		else CFrame.new(originalPosition)

	originalCharacter:PivotTo(restorationPivot)
	originalCharacter.Parent = charactersFolder
	unfreeze_character(originalCharacter)

	local originalRootPart = originalCharacter:FindFirstChild("HumanoidRootPart")
	if cartRootPart and cartRootPart:IsA("BasePart") and originalRootPart and originalRootPart:IsA("BasePart") then
		originalRootPart:SetNetworkOwner(player)
		originalRootPart.AssemblyLinearVelocity = cartRootPart.AssemblyLinearVelocity
		originalRootPart.AssemblyAngularVelocity = Vector3.zero
	end

	player.Character = originalCharacter
	destroy_character(cartCharacter)
end

function rampCharacterService.destroy(cartCharacter: Model, originalCharacter: Model?): ()
	destroy_character(cartCharacter)
	destroy_character(originalCharacter)
end

function rampCharacterService.clear(player: Player): ()
	discard_prepared_swap(player)
end

------------------//INIT
charactersFolder = ensure_folder(workspace, CHARACTERS_FOLDER_NAME)
rampCharacterCache = ensure_folder(ServerStorage, RAMP_CHARACTER_CACHE_NAME)
preparedRampCharactersFolder = ensure_folder(ReplicatedStorage, PREPARED_RAMP_CHARACTERS_FOLDER_NAME)

return rampCharacterService

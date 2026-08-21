------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui: StarterGui = game:GetService("StarterGui")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local MAIN_GUI_NAME: string = "Main"
local MAIN_HUD_NAME: string = "MainHUD"
local HOTBAR_NAME: string = "Hotbar"
local SLOT_TEMPLATE_NAME: string = "SlotTemplate"
local ITEM_IMAGE_NAME: string = "Item"
local QUANTITY_FRAME_NAME: string = "Qty"
local QUANTITY_LABEL_NAME: string = "Label"
local HOTBAR_SLOT_ATTRIBUTE: string = "IsHotbarSlot"
local HOTBAR_SLOT_NAME_PREFIX: string = "HotbarSlot_"
local CORE_GUI_RETRY_COUNT: number = 5
local CORE_GUI_RETRY_DELAY: number = 0.2
local KEY_CODE_TO_SLOT = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.KeypadFour] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.KeypadFive] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.KeypadSix] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.KeypadSeven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.KeypadEight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.KeypadNine] = 9,
	[Enum.KeyCode.Zero] = 10,
	[Enum.KeyCode.KeypadZero] = 10,
}

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local gameplayModules: Folder = replicatedModules:WaitForChild("Gameplay")
local weaponConfig = require(gameplayModules:WaitForChild("WeaponConfig"))

------------------//VARIABLES
type WeaponDefinition = typeof(weaponConfig.definitions.Grenade)
type HotbarEntry = {
	key: string,
	count: number,
	imageId: string?,
}

local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local backpack: Backpack = localPlayer:WaitForChild("Backpack")
local boundMainGui: ScreenGui?
local hotbar: Frame?
local slotTemplate: GuiButton?
local characterConnections: {RBXScriptConnection} = {}
local backpackConnections: {RBXScriptConnection} = {}
local orderedItemKeys: {string} = {}
local rebuildScheduled = false

------------------//FUNCTIONS
local function normalize_image_id(value: unknown): string?
	if type(value) ~= "string" then
		return nil
	end

	local imageId = string.gsub(value, "^%s*(.-)%s*$", "%1")
	if imageId == "" or imageId == "rbxassetid://0" then
		return nil
	end

	if string.match(imageId, "^%d+$") then
		return "rbxassetid://" .. imageId
	end

	return imageId
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

local function get_tool_key(tool: Tool): string
	local weaponId = tool:GetAttribute(weaponConfig.weaponIdAttribute)
	if type(weaponId) == "string" and weaponId ~= "" then
		return weaponId
	end

	return tool.Name
end

local function find_tool_in_container(container: Instance?, itemKey: string): Tool?
	if not container then
		return nil
	end

	for _, child in container:GetChildren() do
		if child:IsA("Tool") and get_tool_key(child) == itemKey then
			return child
		end
	end

	return nil
end

local function equip_item(itemKey: string): ()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end

	local tool = find_tool_in_container(backpack, itemKey)
	if not tool then
		tool = find_tool_in_container(character, itemKey)
	end
	if not tool or tool.Parent == character then
		return
	end

	humanoid:EquipTool(tool)
end

local function get_hotbar_image_id(tool: Tool, definition: WeaponDefinition?): string?
	local configuredImage = if definition then definition.hotbarImage else nil
	local imageId = normalize_image_id(configuredImage)
	if imageId then
		return imageId
	end

	local toolImage = normalize_image_id(tool:GetAttribute(weaponConfig.hotbarImageAttribute))
	if toolImage then
		return toolImage
	end

	return normalize_image_id(tool.TextureId)
end

local function clear_generated_slots(): ()
	local currentHotbar = hotbar
	if not currentHotbar then
		return
	end

	for _, child in currentHotbar:GetChildren() do
		if child:GetAttribute(HOTBAR_SLOT_ATTRIBUTE) == true then
			child:Destroy()
		end
	end
end

local function set_slot_image(slot: GuiObject, imageId: string?): ()
	local itemImage = slot:FindFirstChild(ITEM_IMAGE_NAME)
	if not itemImage or not itemImage:IsA("ImageLabel") then
		return
	end

	itemImage.Image = imageId or ""
	itemImage.Visible = imageId ~= nil
end

local function set_slot_quantity(slot: GuiObject, quantity: number): ()
	local quantityFrame = slot:FindFirstChild(QUANTITY_FRAME_NAME)
	local quantityLabel = quantityFrame and quantityFrame:FindFirstChild(QUANTITY_LABEL_NAME)
	if quantityLabel and quantityLabel:IsA("TextLabel") then
		quantityLabel.Text = ("x%d"):format(quantity)
	end
end

local function create_slot(entry: HotbarEntry, layoutOrder: number): ()
	local currentHotbar = hotbar
	local currentSlotTemplate = slotTemplate
	if not currentHotbar or not currentSlotTemplate then
		return
	end

	local slot = currentSlotTemplate:Clone()
	if not slot:IsA("GuiButton") then
		return
	end

	slot.Name = HOTBAR_SLOT_NAME_PREFIX .. entry.key
	slot.LayoutOrder = layoutOrder
	slot.Visible = true
	slot:SetAttribute(HOTBAR_SLOT_ATTRIBUTE, true)
	set_slot_image(slot, entry.imageId)
	set_slot_quantity(slot, entry.count)
	slot.Activated:Connect(function()
		equip_item(entry.key)
	end)
	slot.Parent = currentHotbar
end

local function rebuild_hotbar(): ()
	if not hotbar or not slotTemplate then
		return
	end

	local entriesByKey: {[string]: HotbarEntry} = {}
	table.clear(orderedItemKeys)

	local function register_tool(instance: Instance): ()
		if not instance:IsA("Tool") then
			return
		end

		local itemKey = get_tool_key(instance)
		local entry = entriesByKey[itemKey]
		local definition = get_definition_for_tool(instance)
		local imageId = get_hotbar_image_id(instance, definition)
		if entry then
			entry.count += 1
			if not entry.imageId then
				entry.imageId = imageId
			end
			return
		end

		entriesByKey[itemKey] = {
			key = itemKey,
			count = 1,
			imageId = imageId,
		}
		table.insert(orderedItemKeys, itemKey)
	end

	for _, child in backpack:GetChildren() do
		register_tool(child)
	end

	local character = localPlayer.Character
	if character then
		for _, child in character:GetChildren() do
			register_tool(child)
		end
	end

	clear_generated_slots()
	for layoutOrder, itemKey in orderedItemKeys do
		local entry = entriesByKey[itemKey]
		if entry then
			create_slot(entry, layoutOrder)
		end
	end
end

local function schedule_rebuild(): ()
	if rebuildScheduled then
		return
	end

	rebuildScheduled = true
	task.defer(function()
		rebuildScheduled = false
		rebuild_hotbar()
	end)
end

local function clear_connections(connections: {RBXScriptConnection}): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function bind_character(newCharacter: Model): ()
	clear_connections(characterConnections)
	table.insert(characterConnections, newCharacter.ChildAdded:Connect(schedule_rebuild))
	table.insert(characterConnections, newCharacter.ChildRemoved:Connect(schedule_rebuild))
	rebuild_hotbar()
end

local function disable_default_backpack(): ()
	for _ = 1, CORE_GUI_RETRY_COUNT do
		local success = pcall(
			StarterGui.SetCoreGuiEnabled,
			StarterGui,
			Enum.CoreGuiType.Backpack,
			false
		)
		if success then
			return
		end
		task.wait(CORE_GUI_RETRY_DELAY)
	end
end

------------------//MAIN FUNCTIONS
local function bind_main_gui(mainGui: ScreenGui): ()
	if boundMainGui == mainGui then
		return
	end

	boundMainGui = mainGui
	local currentMainHud = mainGui:WaitForChild(MAIN_HUD_NAME) :: Frame
	local currentHotbar = currentMainHud:WaitForChild(HOTBAR_NAME) :: Frame
	currentHotbar.Visible = true
	hotbar = currentHotbar
	local currentSlotTemplate = currentHotbar:WaitForChild(SLOT_TEMPLATE_NAME)
	if not currentSlotTemplate:IsA("GuiButton") then
		slotTemplate = nil
		return
	end

	slotTemplate = currentSlotTemplate
	currentSlotTemplate.Visible = false
	rebuild_hotbar()
end

------------------//INIT
bind_main_gui(playerGui:WaitForChild(MAIN_GUI_NAME) :: ScreenGui)
disable_default_backpack()

table.insert(backpackConnections, backpack.ChildAdded:Connect(schedule_rebuild))
table.insert(backpackConnections, backpack.ChildRemoved:Connect(schedule_rebuild))
localPlayer.CharacterAdded:Connect(bind_character)

UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	local slotIndex = KEY_CODE_TO_SLOT[inputObject.KeyCode]
	local itemKey = slotIndex and orderedItemKeys[slotIndex]
	if itemKey then
		equip_item(itemKey)
	end
end)

if localPlayer.Character then
	bind_character(localPlayer.Character)
else
	rebuild_hotbar()
end

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == MAIN_GUI_NAME and child:IsA("ScreenGui") then
		bind_main_gui(child)
	end
end)

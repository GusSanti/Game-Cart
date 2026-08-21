------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService: TextChatService = game:GetService("TextChatService")

------------------//CONSTANTS
local ADMIN_USER_IDS: {[number]: boolean} = {}
local GIVE_GRENADE_CODE: string = "!givegranade"
local GIVE_GRENADE_COMMAND_NAME: string = "GiveGrenadeAdminCommand"
local GIVE_GRENADE_SECONDARY_CODE: string = "/givegranade"
local GRENADE_WEAPON_ID: string = "Grenade"
local REWARD_AMOUNT: number = 1
local COMMAND_DEDUPLICATION_WINDOW: number = 0.25

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local weaponConfig = require(replicatedModules:WaitForChild("Gameplay"):WaitForChild("WeaponConfig"))
local weaponsFolder: Folder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weapons")

------------------//VARIABLES
type AdminCodeReward = {
	weaponId: string,
	amount: number,
}

local ADMIN_CODE_REWARDS: {[string]: AdminCodeReward} = {
	[GIVE_GRENADE_CODE] = {
		weaponId = GRENADE_WEAPON_ID,
		amount = REWARD_AMOUNT,
	},
	[GIVE_GRENADE_SECONDARY_CODE] = {
		weaponId = GRENADE_WEAPON_ID,
		amount = REWARD_AMOUNT,
	},
}
local lastCommandAtByPlayer: {[Player]: number} = {}

------------------//FUNCTIONS
local function is_admin(player: Player): boolean
	if ADMIN_USER_IDS[player.UserId] then
		return true
	end

	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function normalize_code(message: string): string
	local trimmedMessage = string.gsub(message, "^%s*(.-)%s*$", "%1")
	return string.lower(trimmedMessage)
end

local function grant_weapon(player: Player, reward: AdminCodeReward): ()
	local definition = weaponConfig.definitions[reward.weaponId]
	if not definition then
		return
	end

	local toolTemplate = weaponsFolder:FindFirstChild(definition.toolName)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not toolTemplate or not toolTemplate:IsA("Tool") or not backpack then
		return
	end

	for _ = 1, reward.amount do
		local toolClone = toolTemplate:Clone()
		toolClone.CanBeDropped = false
		toolClone.Parent = backpack
	end
end

local function on_chat_message(player: Player, message: string): ()
	local reward = ADMIN_CODE_REWARDS[normalize_code(message)]
	if not reward or not is_admin(player) then
		return
	end

	local currentTime = os.clock()
	local lastCommandAt = lastCommandAtByPlayer[player]
	if lastCommandAt and currentTime - lastCommandAt < COMMAND_DEDUPLICATION_WINDOW then
		return
	end

	lastCommandAtByPlayer[player] = currentTime
	grant_weapon(player, reward)
end

local function get_or_create_admin_command(): TextChatCommand
	local existingCommand = TextChatService:FindFirstChild(GIVE_GRENADE_COMMAND_NAME)
	if existingCommand then
		if not existingCommand:IsA("TextChatCommand") then
			error(("%s precisa ser um TextChatCommand"):format(existingCommand:GetFullName()))
		end
		return existingCommand
	end

	local command = Instance.new("TextChatCommand")
	command.Name = GIVE_GRENADE_COMMAND_NAME
	command.PrimaryAlias = GIVE_GRENADE_CODE
	command.SecondaryAlias = GIVE_GRENADE_SECONDARY_CODE
	command.AutocompleteVisible = false
	command.Parent = TextChatService
	return command
end

local function on_admin_command_triggered(originTextSource: TextSource, _unfilteredText: string): ()
	local player = Players:GetPlayerByUserId(originTextSource.UserId)
	if player then
		on_chat_message(player, GIVE_GRENADE_CODE)
	end
end

------------------//MAIN FUNCTIONS
local function on_player_added(player: Player): ()
	player.Chatted:Connect(function(message: string)
		on_chat_message(player, message)
	end)
end

------------------//INIT
local giveGrenadeCommand = get_or_create_admin_command()
giveGrenadeCommand.Triggered:Connect(on_admin_command_triggered)

for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(function(player: Player)
	lastCommandAtByPlayer[player] = nil
end)

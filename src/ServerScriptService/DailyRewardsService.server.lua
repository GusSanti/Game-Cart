------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local DAILY_REWARD_DATA_PATH: string = "DailyRewards"
local WORLD_DATA_PATH: string = "World"
local COINS_DATA_PATH: string = "Coins"
local DAILY_REWARD_REMOTES_FOLDER_NAME: string = "DailyRewardRemotes"
local CLAIM_REWARD_REMOTE_NAME: string = "ClaimReward"
local SECONDS_PER_DAY: number = 24 * 60 * 60
local FIRST_DAY: number = 1

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local dailyRewardDefinitions = require(modules:WaitForChild("DailyRewardDefinitions"))

------------------//VARIABLES
type DailyRewardsState = {
	CurrentDay: number,
	LastClaimedAt: number,
	ClaimedDays: {[number]: boolean},
	Streak: number,
	LastLoginDay: number,
}

local claimRewardRemote: RemoteFunction
local mutationByUserId: {[number]: boolean} = {}
local definitionsByDay: {[number]: any} = {}

for _, definition in dailyRewardDefinitions do
	definitionsByDay[definition.day] = definition
end

------------------//FUNCTIONS
local function create_empty_rewards(): DailyRewardsState
	return {
		CurrentDay = FIRST_DAY,
		LastClaimedAt = 0,
		ClaimedDays = {},
		Streak = 0,
		LastLoginDay = 0,
	}
end

local function get_day_index(timestamp: number): number
	return math.floor(timestamp / SECONDS_PER_DAY)
end

local function normalize_rewards(rewards: {[string]: any}): boolean
	local changed = false
	local currentDay = rewards.CurrentDay
	if type(currentDay) ~= "number" or currentDay ~= math.floor(currentDay) or not definitionsByDay[currentDay] then
		rewards.CurrentDay = FIRST_DAY
		changed = true
	end

	local lastClaimedAt = rewards.LastClaimedAt
	if type(lastClaimedAt) ~= "number" or lastClaimedAt < 0 or lastClaimedAt ~= math.floor(lastClaimedAt) then
		rewards.LastClaimedAt = 0
		changed = true
	end

	local claimedDays = rewards.ClaimedDays
	if type(claimedDays) ~= "table" then
		rewards.ClaimedDays = {}
		claimedDays = rewards.ClaimedDays
		changed = true
	end

	for _, definition in dailyRewardDefinitions do
		local claimed = claimedDays[definition.day]
		if type(claimed) ~= "boolean" then
			claimedDays[definition.day] = false
			changed = true
		end
	end

	local streak = rewards.Streak
	if type(streak) ~= "number" or streak ~= math.floor(streak) or streak < 0 then
		rewards.Streak = 0
		changed = true
	end

	local lastLoginDay = rewards.LastLoginDay
	if type(lastLoginDay) ~= "number" or lastLoginDay ~= math.floor(lastLoginDay) or lastLoginDay < 0 then
		rewards.LastLoginDay = 0
		changed = true
	end

	local now = os.time()
	local currentDayIndex = get_day_index(now)
	if rewards.CurrentDay == FIRST_DAY
		and claimedDays[#dailyRewardDefinitions] == true
		and rewards.LastClaimedAt > 0
		and currentDayIndex > get_day_index(rewards.LastClaimedAt) then
		rewards.ClaimedDays = {}
		changed = true
	end

	return changed
end

local function update_login_streak(rewards: {[string]: any}): boolean
	local currentDayIndex = math.floor(os.time() / SECONDS_PER_DAY)
	local lastLoginDay = rewards.LastLoginDay
	if lastLoginDay == currentDayIndex then
		return false
	end

	if lastLoginDay == currentDayIndex - 1 then
		rewards.Streak += 1
	else
		rewards.Streak = 1
	end
	rewards.LastLoginDay = currentDayIndex
	return true
end

local function get_or_create_rewards(player: Player): ({[string]: any}?, boolean)
	local rewards = dataUtility.server.get(player, DAILY_REWARD_DATA_PATH)
	if type(rewards) ~= "table" then
		local world = dataUtility.server.get(player, WORLD_DATA_PATH)
		if type(world) ~= "number" then
			return nil, false
		end
		rewards = create_empty_rewards()
	end

	return rewards, normalize_rewards(rewards)
end

local function mutate_rewards(player: Player, callback: ({[string]: any}) -> any): any
	if mutationByUserId[player.UserId] then
		return nil
	end

	mutationByUserId[player.UserId] = true
	local rewards, normalized = get_or_create_rewards(player)
	if not rewards then
		mutationByUserId[player.UserId] = nil
		return nil
	end

	local result = callback(rewards)
	local changed = normalized or (type(result) == "table" and result.changed == true)
	if changed then
		dataUtility.server.set(player, DAILY_REWARD_DATA_PATH, rewards)
	end

	mutationByUserId[player.UserId] = nil
	return result
end

local function ensure_claim_reward_remote(): RemoteFunction
	local remotesFolder = ReplicatedStorage:FindFirstChild(DAILY_REWARD_REMOTES_FOLDER_NAME)
	if not remotesFolder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = DAILY_REWARD_REMOTES_FOLDER_NAME
		newFolder.Parent = ReplicatedStorage
		remotesFolder = newFolder
	end

	local remote = remotesFolder:FindFirstChild(CLAIM_REWARD_REMOTE_NAME)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end

	local newRemote = Instance.new("RemoteFunction")
	newRemote.Name = CLAIM_REWARD_REMOTE_NAME
	newRemote.Parent = remotesFolder
	return newRemote
end

local function initialize_player(player: Player): ()
	mutate_rewards(player, function(rewards): {changed: boolean}
		return {changed = update_login_streak(rewards)}
	end)
end

local function claim_reward(player: Player, requestedDay: any): {[string]: any}
	if type(requestedDay) ~= "number" or requestedDay ~= math.floor(requestedDay) then
		return {success = false, message = "Invalid daily reward."}
	end

	local result = mutate_rewards(player, function(rewards): {[string]: any}
		local now = os.time()
		local lastClaimedAt = rewards.LastClaimedAt or 0
		if lastClaimedAt > 0 and get_day_index(now) <= get_day_index(lastClaimedAt) then
			return {success = false, message = "Your next reward is not ready yet."}
		end

		local currentDay = rewards.CurrentDay
		if requestedDay ~= currentDay then
			return {success = false, message = "This daily reward is not available yet."}
		end

		local definition = definitionsByDay[currentDay]
		if not definition then
			return {success = false, message = "Daily reward is unavailable."}
		end

		local claimedDays = rewards.ClaimedDays
		if claimedDays[currentDay] == true then
			return {success = false, message = "This daily reward was already claimed."}
		end

		local coins = dataUtility.server.get(player, COINS_DATA_PATH)
		if type(coins) ~= "number" or coins < 0 or coins == math.huge then
			coins = 0
		end

		claimedDays[currentDay] = true
		rewards.LastClaimedAt = now
		if currentDay >= #dailyRewardDefinitions then
			rewards.CurrentDay = FIRST_DAY
		else
			rewards.CurrentDay = currentDay + 1
		end
		dataUtility.server.set(player, COINS_DATA_PATH, math.floor(coins) + definition.reward)

		return {
			changed = true,
			success = true,
			message = ("Daily reward claimed! +%d coins."):format(definition.reward),
			reward = definition.reward,
			day = currentDay,
		}
	end)

	return result or {success = false, message = "Please wait for the previous reward request."}
end

local function on_claim_reward(player: Player, requestedDay: any): {[string]: any}
	if mutationByUserId[player.UserId] then
		return {success = false, message = "Please wait for the previous reward request."}
	end

	return claim_reward(player, requestedDay)
end

------------------//INIT
claimRewardRemote = ensure_claim_reward_remote()
claimRewardRemote.OnServerInvoke = on_claim_reward

for _, player in Players:GetPlayers() do
	task.spawn(initialize_player, player)
end

Players.PlayerAdded:Connect(function(player: Player)
	task.spawn(initialize_player, player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	mutationByUserId[player.UserId] = nil
end)

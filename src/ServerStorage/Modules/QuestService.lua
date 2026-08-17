------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local QUEST_DATA_PATH: string = "Quests"
local WORLD_DATA_PATH: string = "World"
local COINS_DATA_PATH: string = "Coins"
local DAILY_CATEGORY: string = "Daily"
local WEEKLY_CATEGORY: string = "Weekly"
local MONTHLY_CATEGORY: string = "Monthly"
local SECONDS_PER_DAY: number = 24 * 60 * 60
local DAYS_PER_WEEK: number = 7
local MAX_EVENT_INCREMENT: number = 1000

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local questDefinitions = require(modules:WaitForChild("QuestDefinitions"))

------------------//VARIABLES
type QuestDefinition = {
	id: string,
	category: string,
	title: string,
	description: string,
	event: string,
	target: number,
	reward: number,
}

local definitionsById: {[string]: QuestDefinition} = {}
local definitionsByCategory: {[string]: {QuestDefinition}} = {
	[DAILY_CATEGORY] = {},
	[WEEKLY_CATEGORY] = {},
	[MONTHLY_CATEGORY] = {},
}
local mutationByUserId: {[number]: boolean} = {}


for _, category in {DAILY_CATEGORY, WEEKLY_CATEGORY, MONTHLY_CATEGORY} do
	for _, definition in questDefinitions[category] do
		definitionsById[definition.id] = definition
		local categoryDefinitions = definitionsByCategory[definition.category]
		if categoryDefinitions then
			table.insert(categoryDefinitions, definition)
		end
	end
end

------------------//FUNCTIONS
local function create_empty_quests(): {[string]: any}
	return {
		Periods = {
			[DAILY_CATEGORY] = "",
			[WEEKLY_CATEGORY] = "",
			[MONTHLY_CATEGORY] = "",
		},
		Progress = {
			[DAILY_CATEGORY] = {},
			[WEEKLY_CATEGORY] = {},
			[MONTHLY_CATEGORY] = {},
		},
		Claimed = {
			[DAILY_CATEGORY] = {},
			[WEEKLY_CATEGORY] = {},
			[MONTHLY_CATEGORY] = {},
		},
	}
end

local function get_period_key(category: string, timestamp: number): string
	local dayIndex = math.floor(timestamp / SECONDS_PER_DAY)
	if category == DAILY_CATEGORY then
		return ("D%d"):format(dayIndex)
	end
	if category == WEEKLY_CATEGORY then
		return ("W%d"):format(math.floor(dayIndex / DAYS_PER_WEEK))
	end

	local date = os.date("!*t", timestamp)
	return ("M%d-%02d"):format(date.year, date.month)
end

local function ensure_bucket(parent: {[string]: any}, name: string): {[string]: any}
	local bucket = parent[name]
	if type(bucket) ~= "table" then
		bucket = {}
		parent[name] = bucket
	end
	return bucket
end

local function normalize_quests(quests: {[string]: any}): boolean
	local periods = ensure_bucket(quests, "Periods")
	local progress = ensure_bucket(quests, "Progress")
	local claimed = ensure_bucket(quests, "Claimed")
	local changed = false

	for _, category in {DAILY_CATEGORY, WEEKLY_CATEGORY, MONTHLY_CATEGORY} do
		local currentPeriod = get_period_key(category, os.time())
		if periods[category] ~= currentPeriod then
			periods[category] = currentPeriod
			progress[category] = {}
			claimed[category] = {}
			changed = true
		end

		local categoryProgress = ensure_bucket(progress, category)
		local categoryClaimed = ensure_bucket(claimed, category)
		for _, definition in definitionsByCategory[category] do
			local currentProgress = categoryProgress[definition.id]
			if type(currentProgress) ~= "number" or currentProgress ~= currentProgress then
				categoryProgress[definition.id] = 0
				changed = true
			else
				local normalizedProgress = math.clamp(math.floor(currentProgress), 0, definition.target)
				if currentProgress ~= normalizedProgress then
					categoryProgress[definition.id] = normalizedProgress
					changed = true
				end
			end

			if type(categoryClaimed[definition.id]) ~= "boolean" then
				categoryClaimed[definition.id] = false
				changed = true
			end
		end
	end

	return changed
end

local function get_or_create_quests(player: Player): ({[string]: any}?, boolean)
	local quests = dataUtility.server.get(player, QUEST_DATA_PATH)
	if type(quests) ~= "table" then
		local world = dataUtility.server.get(player, WORLD_DATA_PATH)
		if type(world) ~= "number" then
			return nil, false
		end
		quests = create_empty_quests()
	end

	return quests, normalize_quests(quests)
end

local function mutate_quests(player: Player, callback: ({[string]: any}) -> any): any
	if mutationByUserId[player.UserId] then
		return nil
	end

	mutationByUserId[player.UserId] = true
	local quests, normalized = get_or_create_quests(player)
	if not quests then
		mutationByUserId[player.UserId] = nil
		return nil
	end

	local result = callback(quests)
	local changed = normalized or (type(result) == "table" and result.changed == true)
	if changed then
		dataUtility.server.set(player, QUEST_DATA_PATH, quests)
	end

	mutationByUserId[player.UserId] = nil
	return result
end

------------------//MAIN FUNCTIONS
local questService = {}

function questService.initialize_player(player: Player): boolean
	return mutate_quests(player, function(): {changed: boolean}
		return {changed = false}
	end) ~= nil
end

function questService.record_event(player: Player, eventName: string, amount: number?): boolean
	if type(eventName) ~= "string" then
		return false
	end

	local increment = if type(amount) == "number" then math.floor(amount) else 1
	if increment <= 0 or increment > MAX_EVENT_INCREMENT then
		return false
	end

	local result = mutate_quests(player, function(quests): {changed: boolean, updated: boolean}
		local progress = quests.Progress
		local claimed = quests.Claimed
		local updated = false

		for _, category in {DAILY_CATEGORY, WEEKLY_CATEGORY, MONTHLY_CATEGORY} do
			for _, definition in questDefinitions[category] do
				if definition.event == eventName and claimed[definition.category][definition.id] ~= true then
					local currentProgress = progress[definition.category][definition.id] or 0
					local nextProgress = math.min(currentProgress + increment, definition.target)
					if nextProgress ~= currentProgress then
						progress[definition.category][definition.id] = nextProgress
						updated = true
					end
				end
			end
		end

		return {changed = updated, updated = updated}
	end)

	return type(result) == "table" and result.updated == true
end

function questService.claim_quest(player: Player, questId: any): {[string]: any}
	if type(questId) ~= "string" then
		return {success = false, message = "Invalid quest."}
	end

	local definition = definitionsById[questId]
	if not definition then
		return {success = false, message = "Invalid quest."}
	end

	local result = mutate_quests(player, function(quests): {[string]: any}
		local progress = quests.Progress[definition.category][definition.id] or 0
		local claimed = quests.Claimed[definition.category][definition.id] == true
		if claimed then
			return {success = false, message = "Quest already claimed."}
		end
		if progress < definition.target then
			return {success = false, message = "Quest is not complete yet."}
		end

		local coins = dataUtility.server.get(player, COINS_DATA_PATH)
		if type(coins) ~= "number" or coins < 0 or coins == math.huge then
			coins = 0
		end

		quests.Claimed[definition.category][definition.id] = true
		dataUtility.server.set(player, COINS_DATA_PATH, math.floor(coins) + definition.reward)
		return {
			changed = true,
			success = true,
			message = ("Quest claimed! +%d coins."):format(definition.reward),
			reward = definition.reward,
		}
	end)

	return result or {success = false, message = "Please wait for the previous quest request."}
end

function questService.clear_player(player: Player): ()
	mutationByUserId[player.UserId] = nil
end

------------------//INIT
return questService

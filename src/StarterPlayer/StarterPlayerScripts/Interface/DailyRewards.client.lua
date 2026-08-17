------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local DAILY_REWARDS_DATA_PATH: string = "DailyRewards"
local DAILY_REWARD_REMOTES_FOLDER_NAME: string = "DailyRewardRemotes"
local CLAIM_REWARD_REMOTE_NAME: string = "ClaimReward"
local CLAIM_STATUS: string = "CLAIM!"
local CLAIMED_STATUS: string = "CLAIMED"
local LOCKED_STATUS: string = "LOCKED"
local FIRST_DAY: number = 1
local SECONDS_PER_DAY: number = 24 * 60 * 60
local STATUS_REFRESH_SECONDS: number = 30

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local dailyRewardDefinitions = require(modules:WaitForChild("DailyRewardDefinitions"))
local claimRewardRemote: RemoteFunction = ReplicatedStorage
	:WaitForChild(DAILY_REWARD_REMOTES_FOLDER_NAME)
	:WaitForChild(CLAIM_REWARD_REMOTE_NAME) :: RemoteFunction

------------------//VARIABLES
type DailyRewardDefinition = {
	day: number,
	rewardType: string,
	reward: number,
	rewardIcon: string,
}

local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local boundMainGui: ScreenGui?
local daysFrame: Frame?
local streakLabel: TextLabel?
local dailyRewardsState: {[string]: any} = {}
local uiConnections: {RBXScriptConnection} = {}
local claimingByDay: {[number]: boolean} = {}
local definitionsByDay: {[number]: DailyRewardDefinition} = {}

for _, definition in dailyRewardDefinitions do
	definitionsByDay[definition.day] = definition
end

------------------//FUNCTIONS
local function connect_ui(connection: RBXScriptConnection): ()
	table.insert(uiConnections, connection)
end

local function disconnect_ui_connections(): ()
	for _, connection in uiConnections do
		connection:Disconnect()
	end
	table.clear(uiConnections)
end

local function get_number_value(name: string, defaultValue: number): number
	local value = dailyRewardsState[name]
	if type(value) ~= "number" or value ~= math.floor(value) then
		return defaultValue
	end

	return value
end

local function get_claimed_days(): {[number]: boolean}
	local claimedDays = dailyRewardsState.ClaimedDays
	return if type(claimedDays) == "table" then claimedDays else {}
end

local function render_streak(): ()
	if streakLabel then
		local streak = math.max(0, get_number_value("Streak", 0))
		streakLabel.Text = ("🔥 %d DAY STREAK"):format(streak)
	end
end

local function is_cooldown_ready(): boolean
	local lastClaimedAt = get_number_value("LastClaimedAt", 0)
	local currentDayIndex = math.floor(os.time() / SECONDS_PER_DAY)
	local lastClaimedDayIndex = math.floor(lastClaimedAt / SECONDS_PER_DAY)
	return lastClaimedAt <= 0 or currentDayIndex > lastClaimedDayIndex
end

local function is_new_cycle_ready(currentDay: number, claimedDays: {[number]: boolean}): boolean
	local lastDay = #dailyRewardDefinitions
	return currentDay == FIRST_DAY
		and claimedDays[lastDay] == true
		and is_cooldown_ready()
end

local function get_status(day: number): string
	local currentDay = get_number_value("CurrentDay", FIRST_DAY)
	local claimedDays = get_claimed_days()
	if is_new_cycle_ready(currentDay, claimedDays) then
		return if day == FIRST_DAY then CLAIM_STATUS else LOCKED_STATUS
	end
	if claimedDays[day] == true then
		return CLAIMED_STATUS
	end
	if day == currentDay and is_cooldown_ready() then
		return CLAIM_STATUS
	end

	return LOCKED_STATUS
end

local function render_card(card: ImageButton, definition: DailyRewardDefinition): ()
	local reward = card:FindFirstChild("Reward")
	local rewardIcon = card:FindFirstChild("RewardIcon")
	local status = card:FindFirstChild("Status")
	local cardStatus = get_status(definition.day)

	if reward and reward:IsA("TextLabel") then
		reward.Text = ("%d COINS"):format(definition.reward)
	end
	if rewardIcon and rewardIcon:IsA("ImageLabel") then
		rewardIcon.Image = definition.rewardIcon
	end
	if status and status:IsA("TextLabel") then
		status.Text = cardStatus
	end

	card.Active = cardStatus == CLAIM_STATUS and not claimingByDay[definition.day]
	card.AutoButtonColor = card.Active
end

local function render_cards(): ()
	render_streak()
	if not daysFrame then
		return
	end

	for _, child in daysFrame:GetChildren() do
		if child:IsA("ImageButton") then
			local dayIndex = child:GetAttribute("DayIndex")
			local definition = if type(dayIndex) == "number" then definitionsByDay[dayIndex] else nil
			if definition then
				render_card(child, definition)
			end
		end
	end
end

local function claim_reward(definition: DailyRewardDefinition, card: ImageButton): ()
	if get_status(definition.day) ~= CLAIM_STATUS or claimingByDay[definition.day] then
		return
	end

	claimingByDay[definition.day] = true
	render_card(card, definition)
	local success = pcall(function()
		claimRewardRemote:InvokeServer(definition.day)
	end)
	claimingByDay[definition.day] = nil

	if not success then
		render_card(card, definition)
	end
end

local function bind_daily_rewards_frame(mainGui: ScreenGui): ()
	local rewardsFrame = mainGui.Frames:WaitForChild("DailyRewards") :: Frame
	local content = rewardsFrame:WaitForChild("Content") :: Frame
	local days = content:WaitForChild("Days")
	local streak = content:WaitForChild("Streak")
	if not days:IsA("Frame") then
		return
	end

	daysFrame = days
	if streak:IsA("Frame") then
		local label = streak:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			streakLabel = label
		end
	end
	for _, child in daysFrame:GetChildren() do
		if child:IsA("ImageButton") then
			local dayIndex = child:GetAttribute("DayIndex")
			local definition = if type(dayIndex) == "number" then definitionsByDay[dayIndex] else nil
			if definition then
				connect_ui(child.Activated:Connect(function()
					claim_reward(definition, child)
				end))
			end
		end
	end

	render_cards()
end

local function bind_main_gui(mainGui: ScreenGui): ()
	if boundMainGui == mainGui then
		return
	end

	disconnect_ui_connections()
	daysFrame = nil
	streakLabel = nil
	boundMainGui = mainGui
	bind_daily_rewards_frame(mainGui)
end

------------------//INIT
dataUtility.client.bind(DAILY_REWARDS_DATA_PATH, function(value: any)
	dailyRewardsState = if type(value) == "table" then value else {}
	render_cards()
end)
dailyRewardsState = dataUtility.client.get(DAILY_REWARDS_DATA_PATH) or {}

bind_main_gui(playerGui:WaitForChild("Main") :: ScreenGui)

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == "Main" and child:IsA("ScreenGui") then
		bind_main_gui(child)
	end
end)

task.spawn(function()
	while true do
		task.wait(STATUS_REFRESH_SECONDS)
		render_cards()
	end
end)

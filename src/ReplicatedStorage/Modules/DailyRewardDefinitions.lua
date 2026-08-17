------------------//CONSTANTS
local COINS_REWARD_TYPE: string = "Coins"
local COINS_REWARD_ICON: string = "rbxassetid://127302079179326"

------------------//VARIABLES
export type DailyRewardDefinition = {
	day: number,
	rewardType: string,
	reward: number,
	rewardIcon: string,
}

local dailyRewardDefinitions: {DailyRewardDefinition} = {
	{
		day = 1,
		rewardType = COINS_REWARD_TYPE,
		reward = 100,
		rewardIcon = COINS_REWARD_ICON,
	},
	{
		day = 2,
		rewardType = COINS_REWARD_TYPE,
		reward = 150,
		rewardIcon = COINS_REWARD_ICON,
	},
	{
		day = 3,
		rewardType = COINS_REWARD_TYPE,
		reward = 250,
		rewardIcon = COINS_REWARD_ICON,
	},
	{
		day = 4,
		rewardType = COINS_REWARD_TYPE,
		reward = 350,
		rewardIcon = COINS_REWARD_ICON,
	},
	{
		day = 5,
		rewardType = COINS_REWARD_TYPE,
		reward = 500,
		rewardIcon = COINS_REWARD_ICON,
	},
	{
		day = 6,
		rewardType = COINS_REWARD_TYPE,
		reward = 750,
		rewardIcon = COINS_REWARD_ICON,
	},
	{
		day = 7,
		rewardType = COINS_REWARD_TYPE,
		reward = 1000,
		rewardIcon = COINS_REWARD_ICON,
	},
}

------------------//INIT
return dailyRewardDefinitions

------------------//CONSTANTS
local DAILY_CATEGORY: string = "Daily"
local WEEKLY_CATEGORY: string = "Weekly"
local MONTHLY_CATEGORY: string = "Monthly"

------------------//VARIABLES
export type QuestDefinition = {
	id: string,
	category: string,
	title: string,
	description: string,
	event: string,
	target: number,
	reward: number,
}

local questDefinitions: {[string]: {QuestDefinition}} = {
	[DAILY_CATEGORY] = {
		{
			id = "DailyJump3",
			category = DAILY_CATEGORY,
			title = "AIRBORNE ACE",
			description = "Jump 3 times during your cart runs",
			event = "Jump",
			target = 3,
			reward = 100,
		},
	},
	[WEEKLY_CATEGORY] = {
		{
			id = "WeeklyCollect100Coins",
			category = WEEKLY_CATEGORY,
			title = "COIN HUNTER",
			description = "Collect 100 coins from the ramps",
			event = "CoinCollected",
			target = 100,
			reward = 750,
		},
		{
			id = "WeeklyFinish3Worlds",
			category = WEEKLY_CATEGORY,
			title = "WORLD RUNNER",
			description = "Reach the end of 3 worlds",
			event = "WorldFinished",
			target = 3,
			reward = 1000,
		},
		{
			id = "WeeklyCleanRuns5",
			category = WEEKLY_CATEGORY,
			title = "UNTOUCHABLE",
			description = "Build up your overdrive 5 times without impacts",
			event = "CleanRun",
			target = 5,
			reward = 800,
		},
	},
	[MONTHLY_CATEGORY] = {
		{
			id = "MonthlyCollect500Coins",
			category = MONTHLY_CATEGORY,
			title = "COIN TYCOON",
			description = "Collect 500 coins across your runs",
			event = "CoinCollected",
			target = 500,
			reward = 2500,
		},
		{
			id = "MonthlyFinish10Worlds",
			category = MONTHLY_CATEGORY,
			title = "WORLD CONQUEROR",
			description = "Reach the end of 10 worlds",
			event = "WorldFinished",
			target = 10,
			reward = 3000,
		},
		{
			id = "MonthlyJump25",
			category = MONTHLY_CATEGORY,
			title = "SKYBOUND",
			description = "Jump 25 times while riding your cart",
			event = "Jump",
			target = 25,
			reward = 1500,
		},
	},
}

------------------//INIT
return questDefinitions

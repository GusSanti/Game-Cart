------------------//CONSTANTS
local DEFAULT_WORLD: number = 1
local DEFAULT_COINS: number = 0
local DEFAULT_EQUIPPED_CART: string = "Default"
local DEFAULT_MUSIC_VOLUME: number = 0.5
local DEFAULT_SFX_VOLUME: number = 0.5

------------------//VARIABLES
local profileTemplate = {
	TimePlayed = 0,
	World = DEFAULT_WORLD,
	Coins = DEFAULT_COINS,
	EquippedCart = DEFAULT_EQUIPPED_CART,
	RedeemedCodes = {},
	DailyRewards = {
		CurrentDay = 1,
		LastClaimedAt = 0,
		ClaimedDays = {},
		Streak = 0,
		LastLoginDay = 0,
	},
	Quests = {
		Periods = {
			Daily = "",
			Weekly = "",
			Monthly = "",
		},
		Progress = {
			Daily = {},
			Weekly = {},
			Monthly = {},
		},
		Claimed = {
			Daily = {},
			Weekly = {},
			Monthly = {},
		},
	},

	Settings = {
		MusicEnabled = true,
		SFXEnabled = true,
		MusicVolume = DEFAULT_MUSIC_VOLUME,
		SFXVolume = DEFAULT_SFX_VOLUME,
		ShadowsEnabled = true,
		VFXEnabled = true,
	},
}

------------------//INIT
return profileTemplate

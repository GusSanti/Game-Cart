------------------//CONSTANTS
local DEFAULT_WORLD: number = 1
local DEFAULT_COINS: number = 0
local DEFAULT_EQUIPPED_CART: string = "Default"

------------------//VARIABLES
local profileTemplate = {
	TimePlayed = 0,
	World = DEFAULT_WORLD,
	Coins = DEFAULT_COINS,
	EquippedCart = DEFAULT_EQUIPPED_CART,
	RedeemedCodes = {},

	Settings = {
		MusicEnabled = true,
		ShadowsEnabled = true,
	},
}

------------------//INIT
return profileTemplate

------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local CODE_REMOTES_FOLDER_NAME = "CodeRemotes"
local REDEEM_CODE_REMOTE_NAME = "RedeemCode"
local REDEEMED_CODES_PATH = "RedeemedCodes"
local MAX_CODE_LENGTH = 32

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local serverModules: Folder = ServerStorage:WaitForChild("Modules")
local codeRewards = require(serverModules:WaitForChild("CodeDefinitions"))
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))

------------------//VARIABLES
local redeemCodeRemote: RemoteFunction
local redeemingByUserId: {[number]: boolean} = {}

------------------//FUNCTIONS
local function normalize_code(rawCode: any): string?
	if type(rawCode) ~= "string" then
		return nil
	end

	local normalizedCode = string.upper(string.gsub(rawCode, "^%s*(.-)%s*$", "%1"))
	if normalizedCode == "" or #normalizedCode > MAX_CODE_LENGTH then
		return nil
	end

	return normalizedCode
end

local function ensure_redeem_remote(): RemoteFunction
	local codeRemotes = ReplicatedStorage:FindFirstChild(CODE_REMOTES_FOLDER_NAME)
	if not codeRemotes then
		local folder = Instance.new("Folder")
		folder.Name = CODE_REMOTES_FOLDER_NAME
		folder.Parent = ReplicatedStorage
		codeRemotes = folder
	end

	local remote = codeRemotes:FindFirstChild(REDEEM_CODE_REMOTE_NAME)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end

	local newRemote = Instance.new("RemoteFunction")
	newRemote.Name = REDEEM_CODE_REMOTE_NAME
	newRemote.Parent = codeRemotes
	return newRemote
end

local function redeem_code(player: Player, rawCode: any): {[string]: any}
	local normalizedCode = normalize_code(rawCode)
	if not normalizedCode then
		return {
			success = false,
			message = "Enter a valid code.",
		}
	end

	local rewardCoins = codeRewards[normalizedCode]
	if type(rewardCoins) ~= "number" or rewardCoins <= 0 then
		return {
			success = false,
			message = "Invalid or expired code.",
		}
	end

	local redeemedCodes = dataUtility.server.get(player, REDEEMED_CODES_PATH)
	if type(redeemedCodes) ~= "table" then
		dataUtility.server.set(player, REDEEMED_CODES_PATH, {})
		redeemedCodes = {}
	end

	if redeemedCodes[normalizedCode] == true then
		return {
			success = false,
			message = "This code was already redeemed.",
		}
	end

	local currentCoins = dataUtility.server.get(player, "Coins")
	if type(currentCoins) ~= "number" or currentCoins < 0 then
		currentCoins = 0
	end

	dataUtility.server.set(player, REDEEMED_CODES_PATH .. "." .. normalizedCode, true)
	dataUtility.server.set(player, "Coins", currentCoins + rewardCoins)

	return {
		success = true,
		message = ("Code redeemed! +%d coins."):format(rewardCoins),
		rewardCoins = rewardCoins,
	}
end

------------------//MAIN FUNCTIONS
local function on_redeem_code(player: Player, rawCode: any): {[string]: any}
	if redeemingByUserId[player.UserId] then
		return {
			success = false,
			message = "Please wait for the previous code request.",
		}
	end

	redeemingByUserId[player.UserId] = true
	local success, result = pcall(redeem_code, player, rawCode)
	redeemingByUserId[player.UserId] = nil

	if not success then
		warn(("Falha ao resgatar código para %s: %s"):format(player.Name, result))
		return {
			success = false,
			message = "Could not redeem the code. Try again.",
		}
	end

	return result
end

------------------//INIT
redeemCodeRemote = ensure_redeem_remote()
redeemCodeRemote.OnServerInvoke = on_redeem_code

Players.PlayerRemoving:Connect(function(player: Player)
	redeemingByUserId[player.UserId] = nil
end)

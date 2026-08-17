------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local STORE_NAME: string = RunService:IsStudio() and "PlayerData_Studio_v1" or "PlayerData_v1"
local DEFAULT_MUSIC_VOLUME: number = 0.5
local DEFAULT_SFX_VOLUME: number = 0.5
local RUNTIME_DATA_PATHS: {string} = {
	"World",
	"Coins",
	"EquippedCart",
}

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local packages: Folder = ServerStorage:WaitForChild("Packages")
local profileStoreModule = require(packages:WaitForChild("ProfileStore"))
local profileTemplate = require(script:WaitForChild("ProfileTemplate"))
local dataUtility = require(replicatedModules:WaitForChild("Data"):WaitForChild("DataUtility"))

------------------//VARIABLES
local store = profileStoreModule.New(STORE_NAME, profileTemplate)
local profilesByUserId: { [number]: any } = {}

------------------//FUNCTIONS
local function normalize_profile_data(profileData: any): ()
	local world = profileData.World
	if type(world) ~= "number" or world ~= world or world < profileTemplate.World or world == math.huge then
		profileData.World = profileTemplate.World
	else
		profileData.World = math.floor(world)
	end

	local coins = profileData.Coins
	if type(coins) ~= "number" or coins ~= coins or coins < profileTemplate.Coins or coins == math.huge then
		profileData.Coins = profileTemplate.Coins
	else
		profileData.Coins = math.floor(coins)
	end

	if type(profileData.EquippedCart) ~= "string" or profileData.EquippedCart == "" then
		profileData.EquippedCart = profileTemplate.EquippedCart
	end

	local settings = profileData.Settings
	if type(settings) ~= "table" then
		settings = {}
		profileData.Settings = settings
	end

	if type(settings.MusicEnabled) ~= "boolean" then
		settings.MusicEnabled = true
	end
	if type(settings.SFXEnabled) ~= "boolean" then
		settings.SFXEnabled = true
	end
	if type(settings.MusicVolume) ~= "number" or settings.MusicVolume ~= settings.MusicVolume then
		settings.MusicVolume = DEFAULT_MUSIC_VOLUME
	else
		settings.MusicVolume = math.clamp(settings.MusicVolume, 0, 1)
	end
	if type(settings.SFXVolume) ~= "number" or settings.SFXVolume ~= settings.SFXVolume then
		settings.SFXVolume = DEFAULT_SFX_VOLUME
	else
		settings.SFXVolume = math.clamp(settings.SFXVolume, 0, 1)
	end
	if type(settings.ShadowsEnabled) ~= "boolean" then
		settings.ShadowsEnabled = true
	end
	if type(settings.VFXEnabled) ~= "boolean" then
		settings.VFXEnabled = true
	end
end

local function replicate_runtime_data(player: Player, profileData: any): ()
	for _, path in RUNTIME_DATA_PATHS do
		player:SetAttribute(path, profileData[path])
		dataUtility.server.bind(player, path, function(value: any)
			player:SetAttribute(path, value)
		end)
	end
end

local function clear_runtime_data(player: Player): ()
	for _, path in RUNTIME_DATA_PATHS do
		player:SetAttribute(path, nil)
	end
end

local function attach_player_profile(player: Player): ()
	local profile = store:StartSessionAsync(tostring(player.UserId))
	if not profile then
		warn("Falha ao iniciar sessão do perfil para " .. player.Name)
		return
	end

	profile:Reconcile()
	normalize_profile_data(profile.Data)
	profile:AddUserId(player.UserId)
	profilesByUserId[player.UserId] = profile
	dataUtility.server.attach_profile(player, profile)
	replicate_runtime_data(player, profile.Data)

	task.spawn(function()
		while player.Parent and profilesByUserId[player.UserId] do
			task.wait(60)
			if profilesByUserId[player.UserId] then
				local currentTime = profile.Data.TimePlayed or 0
				dataUtility.server.set(player, "TimePlayed", currentTime + 60)
			end
		end
	end)

	profile.OnSessionEnd:Connect(function()
		dataUtility.server.detach_profile(player)
		clear_runtime_data(player)
		profilesByUserId[player.UserId] = nil
	end)
end

local function release_player_profile(player: Player): ()
	local profile = profilesByUserId[player.UserId]
	if profile then
		profile:EndSession()
		profilesByUserId[player.UserId] = nil
	end
end

------------------//MAIN FUNCTIONS
local function on_player_added(player: Player): ()
	attach_player_profile(player)
end

local function on_player_removing(player: Player): ()
	release_player_profile(player)
end

------------------//INIT
dataUtility.server.ensure_remotes()

for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(on_player_removing)

profileStoreModule.OnError:Connect(function(message: string, storeName: string, key: string)
	warn(("[ProfileStore:%s %s] %s"):format(storeName, key, message))
end)

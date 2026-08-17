------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local SETTINGS_REMOTES_FOLDER_NAME: string = "SettingsRemotes"
local SET_SETTING_REMOTE_NAME: string = "SetSetting"
local MUSIC_ENABLED_SETTING: string = "MusicEnabled"
local SFX_ENABLED_SETTING: string = "SFXEnabled"
local MUSIC_VOLUME_SETTING: string = "MusicVolume"
local SFX_VOLUME_SETTING: string = "SFXVolume"
local SHADOWS_ENABLED_SETTING: string = "ShadowsEnabled"
local VFX_ENABLED_SETTING: string = "VFXEnabled"

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))

------------------//VARIABLES
type SettingDefinition = {
	path: string,
	isBoolean: boolean,
}

local settingDefinitions: {[string]: SettingDefinition} = {
	[ MUSIC_ENABLED_SETTING ] = {
		path = "Settings.MusicEnabled",
		isBoolean = true,
	},
	[ SFX_ENABLED_SETTING ] = {
		path = "Settings.SFXEnabled",
		isBoolean = true,
	},
	[ MUSIC_VOLUME_SETTING ] = {
		path = "Settings.MusicVolume",
		isBoolean = false,
	},
	[ SFX_VOLUME_SETTING ] = {
		path = "Settings.SFXVolume",
		isBoolean = false,
	},
	[ SHADOWS_ENABLED_SETTING ] = {
		path = "Settings.ShadowsEnabled",
		isBoolean = true,
	},
	[ VFX_ENABLED_SETTING ] = {
		path = "Settings.VFXEnabled",
		isBoolean = true,
	},
}

local setSettingRemote: RemoteFunction

------------------//FUNCTIONS
local function normalize_setting_value(definition: SettingDefinition, value: any): boolean | number?
	if definition.isBoolean then
		if type(value) == "boolean" then
			return value
		end
		return nil
	end

	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	return math.clamp(value, 0, 1)
end

local function set_player_setting(player: Player, settingName: any, value: any): boolean
	if type(settingName) ~= "string" then
		return false
	end

	local definition = settingDefinitions[settingName]
	if not definition then
		return false
	end

	local normalizedValue = normalize_setting_value(definition, value)
	if normalizedValue == nil then
		return false
	end

	dataUtility.server.set(player, definition.path, normalizedValue)
	return true
end

local function ensure_settings_remote(): RemoteFunction
	local remotesFolder = ReplicatedStorage:FindFirstChild(SETTINGS_REMOTES_FOLDER_NAME)
	if not remotesFolder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = SETTINGS_REMOTES_FOLDER_NAME
		newFolder.Parent = ReplicatedStorage
		remotesFolder = newFolder
	end

	local remote = remotesFolder:FindFirstChild(SET_SETTING_REMOTE_NAME)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end

	local newRemote = Instance.new("RemoteFunction")
	newRemote.Name = SET_SETTING_REMOTE_NAME
	newRemote.Parent = remotesFolder
	return newRemote
end

------------------//MAIN FUNCTIONS

------------------//INIT
setSettingRemote = ensure_settings_remote()
setSettingRemote.OnServerInvoke = set_player_setting

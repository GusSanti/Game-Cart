------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local QUEST_REMOTES_FOLDER_NAME: string = "QuestRemotes"
local CLAIM_QUEST_REMOTE_NAME: string = "ClaimQuest"
local QUEST_EVENTS_FOLDER_NAME: string = "QuestEvents"
local RECORD_EVENT_NAME: string = "RecordEvent"

------------------//DEPENDENCIES
local questService = require(ServerStorage:WaitForChild("Modules"):WaitForChild("QuestService"))

------------------//VARIABLES
local claimQuestRemote: RemoteFunction
local recordEvent: BindableEvent

------------------//FUNCTIONS
local function ensure_claim_quest_remote(): RemoteFunction
	local remotesFolder = ReplicatedStorage:FindFirstChild(QUEST_REMOTES_FOLDER_NAME)
	if not remotesFolder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = QUEST_REMOTES_FOLDER_NAME
		newFolder.Parent = ReplicatedStorage
		remotesFolder = newFolder
	end

	local remote = remotesFolder:FindFirstChild(CLAIM_QUEST_REMOTE_NAME)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end

	local newRemote = Instance.new("RemoteFunction")
	newRemote.Name = CLAIM_QUEST_REMOTE_NAME
	newRemote.Parent = remotesFolder
	return newRemote
end

local function ensure_record_event(): BindableEvent
	local eventsFolder = ServerStorage:FindFirstChild(QUEST_EVENTS_FOLDER_NAME)
	if not eventsFolder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = QUEST_EVENTS_FOLDER_NAME
		newFolder.Parent = ServerStorage
		eventsFolder = newFolder
	end

	local event = eventsFolder:FindFirstChild(RECORD_EVENT_NAME)
	if event and event:IsA("BindableEvent") then
		return event
	end

	local newEvent = Instance.new("BindableEvent")
	newEvent.Name = RECORD_EVENT_NAME
	newEvent.Parent = eventsFolder
	return newEvent
end

------------------//MAIN FUNCTIONS
local function on_player_added(player: Player): ()
	questService.initialize_player(player)
end

local function on_player_removing(player: Player): ()
	questService.clear_player(player)
end

------------------//INIT
claimQuestRemote = ensure_claim_quest_remote()
claimQuestRemote.OnServerInvoke = questService.claim_quest
recordEvent = ensure_record_event()
recordEvent.Event:Connect(function(player: Player, eventName: string, amount: number?)
	if player and player:IsA("Player") then
		questService.record_event(player, eventName, amount)
	end
end)

for _, player in Players:GetPlayers() do
	task.spawn(on_player_added, player)
end

Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(on_player_removing)

------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local DAILY_CATEGORY: string = "Daily"
local WEEKLY_CATEGORY: string = "Weekly"
local MONTHLY_CATEGORY: string = "Monthly"
local QUEST_CATEGORIES: {string} = {DAILY_CATEGORY, WEEKLY_CATEGORY, MONTHLY_CATEGORY}
local CLAIM_QUEST_REMOTE_NAME: string = "ClaimQuest"
local QUEST_REMOTES_FOLDER_NAME: string = "QuestRemotes"
local QUEST_CARD_PREFIX: string = "QuestCard_"
local QUEST_CARD_ATTRIBUTE: string = "QuestCard"
local QUEST_BOUND_ATTRIBUTE: string = "QuestBound"
local CLAIM_LABEL: string = "CLAIM"
local LOCKED_LABEL: string = "LOCKED"

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local questDefinitions = require(modules:WaitForChild("QuestDefinitions"))
local claimQuestRemote: RemoteFunction = ReplicatedStorage
	:WaitForChild(QUEST_REMOTES_FOLDER_NAME)
	:WaitForChild(CLAIM_QUEST_REMOTE_NAME) :: RemoteFunction

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

local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local boundMainGui: ScreenGui?
local selectedCategory: string = DAILY_CATEGORY
local questsState: {[string]: any} = {}
local uiConnections: {RBXScriptConnection} = {}
local cardConnections: {RBXScriptConnection} = {}
local dataConnection: any
local questTabs: Frame?
local questList: ScrollingFrame?
local questTemplate: Frame?
local claimRequestsById: {[string]: boolean} = {}

------------------//FUNCTIONS
local function connect_ui(connection: RBXScriptConnection): ()
	table.insert(uiConnections, connection)
end

local function connect_card_ui(connection: RBXScriptConnection): ()
	table.insert(cardConnections, connection)
end

local function disconnect_connections(connections: {RBXScriptConnection}): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function clear_generated_cards(): ()
	if not questList then
		return
	end

	disconnect_connections(cardConnections)
	for _, child in questList:GetChildren() do
		if child:IsA("Frame") and child:GetAttribute(QUEST_CARD_ATTRIBUTE) == true then
			child:Destroy()
		end
	end
end

local function clear_ui_connections(): ()
	disconnect_connections(uiConnections)
	disconnect_connections(cardConnections)
	clear_generated_cards()
	questTabs = nil
	questList = nil
	questTemplate = nil
	boundMainGui = nil
end

local function get_category_bucket(parent: any, category: string): {[string]: any}
	local bucket = if type(parent) == "table" then parent[category] else nil
	return if type(bucket) == "table" then bucket else {}
end

local function get_category_definitions(category: string): {QuestDefinition}
	local definitions = questDefinitions[category]
	return if type(definitions) == "table" then definitions else {}
end

local function get_progress(category: string, definition: QuestDefinition): number
	local progress = get_category_bucket(questsState.Progress, category)[definition.id]
	if type(progress) ~= "number" or progress ~= progress then
		return 0
	end

	return math.clamp(math.floor(progress), 0, definition.target)
end

local function is_claimed(category: string, definition: QuestDefinition): boolean
	return get_category_bucket(questsState.Claimed, category)[definition.id] == true
end

local function create_card(index: number): Frame?
	if not questList or not questTemplate then
		return nil
	end

	local card = questTemplate:Clone()
	card.Name = QUEST_CARD_PREFIX .. tostring(index)
	card:SetAttribute(QUEST_CARD_ATTRIBUTE, true)
	card:SetAttribute(QUEST_BOUND_ATTRIBUTE, nil)
	card.Visible = true
	card.Parent = questList
	return card
end

local function render_card(card: Frame, definition: QuestDefinition, index: number): ()
	local progress = get_progress(definition.category, definition)
	local isComplete = progress >= definition.target
	local title = card:FindFirstChild("Title")
	local description = card:FindFirstChild("Description")
	local reward = card:FindFirstChild("Reward")
	local progressFrame = card:FindFirstChild("Progress")
	local claim = card:FindFirstChild("Claim")

	if title and title:IsA("TextLabel") then
		title.Text = definition.title
	end
	if description and description:IsA("TextLabel") then
		description.Text = definition.description
	end
	if reward then
		local rewardLabel = reward:FindFirstChild("Label")
		if rewardLabel and rewardLabel:IsA("TextLabel") then
			rewardLabel.Text = ("+%d$"):format(definition.reward)
		end
	end
	if progressFrame and progressFrame:IsA("Frame") then
		local fill = progressFrame:FindFirstChild("Fill")
		local progressLabel = progressFrame:FindFirstChild("Label")
		if fill and fill:IsA("Frame") then
			fill.Size = UDim2.new(progress / definition.target, 0, 1, 0)
		end
		if progressLabel and progressLabel:IsA("TextLabel") then
			progressLabel.Text = ("%d/%d"):format(progress, definition.target)
		end
	end
	if claim and claim:IsA("TextButton") then
		local claimLabel = claim:FindFirstChild("Label")
		claim.Active = isComplete and not claimRequestsById[definition.id]
		claim.AutoButtonColor = isComplete
		if claimLabel and claimLabel:IsA("TextLabel") then
			claimLabel.Text = if isComplete then CLAIM_LABEL else LOCKED_LABEL
		end
	end

	card.LayoutOrder = index
	card.Visible = true
end

local function claim_quest(definition: QuestDefinition, card: Frame): ()
	if claimRequestsById[definition.id] or get_progress(definition.category, definition) < definition.target then
		return
	end

	claimRequestsById[definition.id] = true
	render_card(card, definition, card.LayoutOrder)
	local success, response = pcall(function()
		return claimQuestRemote:InvokeServer(definition.id)
	end)
	claimRequestsById[definition.id] = nil

	if success and type(response) == "table" and response.success == true then
		card:Destroy()
		return
	end

	render_card(card, definition, card.LayoutOrder)
end

local function render_selected_category(): ()
	clear_generated_cards()
	local definitions = get_category_definitions(selectedCategory)
	for index, definition in definitions do
		if not is_claimed(selectedCategory, definition) then
			local card = create_card(index)
			if card then
				local claim = card:FindFirstChild("Claim")
				if claim and claim:IsA("TextButton") then
					connect_card_ui(claim.Activated:Connect(function()
						claim_quest(definition, card)
					end))
				end
				render_card(card, definition, index)
			end
		end
	end
end

local function select_category(category: string): ()
	selectedCategory = category
	if questTabs then
		for _, descendant in questTabs:GetChildren() do
			if descendant:IsA("TextButton") then
				local targetPage = descendant:GetAttribute("TargetPage")
				descendant:SetAttribute("IsSelected", targetPage == (category .. "Page"))
			end
		end
	end
	render_selected_category()
end

local function bind_quests_frame(questsFrame: Frame): ()
	local content = questsFrame:WaitForChild("Content") :: Frame
	local tabs = content:WaitForChild("QuestTabs")
	local pages = content:WaitForChild("Pages")
	if not tabs:IsA("Frame") or not pages:IsA("Frame") then
		return
	end

	local contentList = pages:WaitForChild("Content")
	local template = contentList:WaitForChild("Template")
	if not contentList:IsA("ScrollingFrame") or not template:IsA("Frame") then
		return
	end

	questTabs = tabs
	questList = contentList
	questTemplate = template
	questTemplate.Visible = false
	questList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	questList.ScrollingDirection = Enum.ScrollingDirection.Y

	for _, descendant in questTabs:GetChildren() do
		if descendant:IsA("TextButton") then
			local targetPage = descendant:GetAttribute("TargetPage")
			for _, category in QUEST_CATEGORIES do
				if targetPage == category .. "Page" then
					connect_ui(descendant.Activated:Connect(function()
						select_category(category)
					end))
				end
			end
		end
	end

	select_category(selectedCategory)
end

local function bind_main_gui(mainGui: ScreenGui): ()
	if boundMainGui == mainGui then
		return
	end

	clear_ui_connections()
	boundMainGui = mainGui
	bind_quests_frame(mainGui.Frames:WaitForChild("Quests") :: Frame)
end

------------------//INIT
dataConnection = dataUtility.client.bind("Quests", function(value: any)
	questsState = if type(value) == "table" then value else {}
	if questList then
		render_selected_category()
	end
end)
questsState = dataUtility.client.get("Quests") or {}

bind_main_gui(playerGui:WaitForChild("Main") :: ScreenGui)

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == "Main" and child:IsA("ScreenGui") then
		bind_main_gui(child)
	end
end)


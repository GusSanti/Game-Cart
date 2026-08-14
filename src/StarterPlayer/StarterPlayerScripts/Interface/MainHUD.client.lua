------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local BUTTON_TO_FRAME: {[string]: string} = {
	IconBtn_Shop = "Shop",
	IconBtn_Items = "Inventory",
	IconBtn_DailyRewards = "DailyRewards",
	IconBtn_Quests = "Quests",
	IconBtn_Settings = "Settings",
	IconBtn_Codes = "Codes",
}

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local hudAnim = require(modules:WaitForChild("Interface"):WaitForChild("HudAnim"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")

local boundMainGui: ScreenGui?
local framesFolder: Folder?
local activeFrame: GuiObject?
local coinAmountLabel: TextLabel?
local coinsBound = false

------------------//FUNCTIONS
local function format_coins(value: any): string
	local amount = tonumber(value) or 0
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		amount = 0
	end

	local formatted = tostring(math.max(0, math.floor(amount)))
	while true do
		local nextFormatted, replacementCount = string.gsub(formatted, "^(%d+)(%d%d%d)", "%1,%2")
		formatted = nextFormatted
		if replacementCount == 0 then
			break
		end
	end

	return formatted
end

local function update_coin_counter(value: any): ()
	if coinAmountLabel then
		coinAmountLabel.Text = format_coins(value)
	end
end

local function close_frame(frame: GuiObject): ()
	if activeFrame == frame then
		activeFrame = nil
	end

	if frame.Visible then
		frame.Visible = false
	end
end

local function open_frame(frame: GuiObject): ()
	if activeFrame == frame and frame.Visible then
		close_frame(frame)
		return
	end

	if framesFolder then
		for _, candidate in framesFolder:GetChildren() do
			if candidate:IsA("GuiObject") and candidate ~= frame and candidate.Visible then
				candidate.Visible = false
			end
		end
	end

	activeFrame = frame
	frame.Visible = true
end

local function connect_close_button(frame: GuiObject): ()
	local header = frame:FindFirstChild("Header")
	local closeButton = header and header:FindFirstChild("Close")
	if closeButton and closeButton:IsA("GuiButton") then
		closeButton.Activated:Connect(function()
			close_frame(frame)
		end)
	end
end

local function configure_frame(frame: GuiObject): ()
	frame:SetAttribute("UIOpen", true)
	frame.Visible = false
	connect_close_button(frame)
end

------------------//MAIN FUNCTIONS
local function bind_main_gui(mainGui: ScreenGui): ()
	if boundMainGui == mainGui then
		return
	end

	boundMainGui = mainGui
	framesFolder = mainGui:WaitForChild("Frames") :: Folder
	activeFrame = nil

	local mainHud = mainGui:WaitForChild("MainHUD")
	local coinCounter = mainHud:WaitForChild("CoinCounter")
	local leftButton = mainHud:WaitForChild("LeftButton")
	local rightButton = mainHud:WaitForChild("RightButton")
	coinAmountLabel = coinCounter:WaitForChild("Amount") :: TextLabel

	for _, frame in framesFolder:GetChildren() do
		if frame:IsA("GuiObject") then
			configure_frame(frame)
		end
	end

	hudAnim.apply_defaults_to_buttons(mainGui)
	hudAnim.bind_all(mainGui)

	for buttonName, frameName in BUTTON_TO_FRAME do
		local button = leftButton:FindFirstChild(buttonName) or rightButton:FindFirstChild(buttonName)
		local frame = framesFolder:FindFirstChild(frameName)

		if button and button:IsA("GuiButton") and frame and frame:IsA("GuiObject") then
			button.Activated:Connect(function()
				open_frame(frame)
			end)
		end
	end

	update_coin_counter(dataUtility.client.get("Coins"))
	if not coinsBound then
		coinsBound = true
		dataUtility.client.bind("Coins", update_coin_counter)
	end
end

------------------//INIT
bind_main_gui(playerGui:WaitForChild("Main") :: ScreenGui)

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == "Main" and child:IsA("ScreenGui") then
		bind_main_gui(child)
	end
end)

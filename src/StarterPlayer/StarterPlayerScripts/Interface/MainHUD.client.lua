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
local SLIDER_KNOB_NAME: string = "Knob"
local IS_RAMP_CART_CHARACTER_ATTRIBUTE: string = "IsRampCartCharacter"
local COIN_COUNTER_NAME: string = "CoinCounter"
local HOTBAR_NAME: string = "Hotbar"

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local hudAnim = require(modules:WaitForChild("Interface"):WaitForChild("HudAnim"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")

local boundMainGui: ScreenGui?
local framesFolder: Folder?
local mainHud: Frame?
local activeFrame: GuiObject?
local coinAmountLabel: TextLabel?
local cartCharacterConnection: RBXScriptConnection?
local savedMainHudVisibility: {[GuiObject]: boolean} = {}
local coinsBound = false
local isCartMode = false

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

local function set_main_hud_cart_mode(isCartModeActive: boolean): ()
	if not mainHud then
		return
	end

	if isCartModeActive then
		if not isCartMode then
			table.clear(savedMainHudVisibility)
			for _, child in mainHud:GetChildren() do
				if child:IsA("GuiObject") then
					savedMainHudVisibility[child] = child.Visible
				end
			end
			isCartMode = true
		end

		for _, child in mainHud:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = child.Name == COIN_COUNTER_NAME or child.Name == HOTBAR_NAME
			end
		end
		return
	end

	if not isCartMode then
		return
	end

	for child, wasVisible in savedMainHudVisibility do
		if child.Parent == mainHud then
			child.Visible = wasVisible
		end
	end
	table.clear(savedMainHudVisibility)
	isCartMode = false
end

local function bind_character(newCharacter: Model): ()
	if cartCharacterConnection then
		cartCharacterConnection:Disconnect()
		cartCharacterConnection = nil
	end

	local function update_cart_hud(): ()
		set_main_hud_cart_mode(newCharacter:GetAttribute(IS_RAMP_CART_CHARACTER_ATTRIBUTE) == true)
	end

	cartCharacterConnection = newCharacter:GetAttributeChangedSignal(IS_RAMP_CART_CHARACTER_ATTRIBUTE):Connect(update_cart_hud)
	update_cart_hud()
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

local function disable_slider_knob_animation(root: Instance): ()
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ImageButton") and descendant.Name == SLIDER_KNOB_NAME then
			descendant:SetAttribute("UIAnim", false)
		end
	end
end

------------------//MAIN FUNCTIONS
local function bind_main_gui(mainGui: ScreenGui): ()
	if boundMainGui == mainGui then
		return
	end

	boundMainGui = mainGui
	framesFolder = mainGui:WaitForChild("Frames") :: Folder
	activeFrame = nil

	local currentMainHud = mainGui:WaitForChild("MainHUD") :: Frame
	mainHud = currentMainHud
	local coinCounter = currentMainHud:WaitForChild("CoinCounter")
	local leftButton = currentMainHud:WaitForChild("LeftButton")
	local rightButton = currentMainHud:WaitForChild("RightButton")
	coinAmountLabel = coinCounter:WaitForChild("Amount") :: TextLabel
	set_main_hud_cart_mode(
		localPlayer.Character ~= nil
			and localPlayer.Character:GetAttribute(IS_RAMP_CART_CHARACTER_ATTRIBUTE) == true
	)

	for _, frame in framesFolder:GetChildren() do
		if frame:IsA("GuiObject") then
			configure_frame(frame)
		end
	end

	hudAnim.apply_defaults_to_buttons(mainGui)
	disable_slider_knob_animation(mainGui)
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

localPlayer.CharacterAdded:Connect(bind_character)
if localPlayer.Character then
	bind_character(localPlayer.Character)
end

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == "Main" and child:IsA("ScreenGui") then
		bind_main_gui(child)
	end
end)

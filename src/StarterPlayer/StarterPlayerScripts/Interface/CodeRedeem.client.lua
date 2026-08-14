------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local SUCCESS_COLOR = Color3.fromRGB(115, 255, 150)
local ERROR_COLOR = Color3.fromRGB(255, 145, 145)

------------------//DEPENDENCIES
local codeRemotes: Folder = ReplicatedStorage:WaitForChild("CodeRemotes")
local redeemCodeRemote: RemoteFunction = codeRemotes:WaitForChild("RedeemCode") :: RemoteFunction

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")

local boundCodesFrame: Frame?
local codeInput: TextBox?
local redeemButton: TextButton?
local statusLabel: TextLabel?
local requestInFlight = false

------------------//FUNCTIONS
local function set_feedback(message: string, color: Color3): ()
	if statusLabel then
		statusLabel.Text = message
		statusLabel.TextColor3 = color
	end
end

local function redeem_code(): ()
	if requestInFlight or not codeInput or not redeemButton then
		return
	end

	local rawCode = codeInput.Text
	if string.gsub(rawCode, "%s", "") == "" then
		set_feedback("Enter a code.", ERROR_COLOR)
		return
	end

	requestInFlight = true
	redeemButton.Active = false

	local success, response = pcall(function()
		return redeemCodeRemote:InvokeServer(rawCode)
	end)

	redeemButton.Active = true
	requestInFlight = false

	if not success or type(response) ~= "table" then
		set_feedback("Could not redeem the code. Try again.", ERROR_COLOR)
		return
	end

	local message = response.message or "Could not redeem the code. Try again."
	if response.success == true then
		codeInput.Text = ""
		set_feedback(message, SUCCESS_COLOR)
	else
		set_feedback(message, ERROR_COLOR)
	end
end

------------------//MAIN FUNCTIONS
local function bind_codes_frame(codesFrame: Frame): ()
	if boundCodesFrame == codesFrame then
		return
	end

	boundCodesFrame = codesFrame
	local content = codesFrame:WaitForChild("Content")
	local codeInputFrame = content:WaitForChild("CodeInput")
	codeInput = codeInputFrame:WaitForChild("TextBox") :: TextBox
	redeemButton = content:WaitForChild("RedeemButton") :: TextButton
	statusLabel = content:WaitForChild("CodeStatus") :: TextLabel

	redeemButton.Activated:Connect(redeem_code)
end

------------------//INIT
local mainGui = playerGui:WaitForChild("Main")
bind_codes_frame(mainGui.Frames:WaitForChild("Codes") :: Frame)

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == "Main" and child:IsA("ScreenGui") then
		bind_codes_frame(child.Frames:WaitForChild("Codes") :: Frame)
	end
end)

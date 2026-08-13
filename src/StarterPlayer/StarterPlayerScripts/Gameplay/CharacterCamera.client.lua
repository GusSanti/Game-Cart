------------------//SERVICES
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local CHARACTER_LOAD_TIMEOUT: number = 5

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer

------------------//FUNCTIONS
local function follow_character(character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", CHARACTER_LOAD_TIMEOUT)
	local currentCamera = workspace.CurrentCamera
	if localPlayer.Character == character and humanoid and humanoid:IsA("Humanoid") and currentCamera then
		currentCamera.CameraSubject = humanoid
	end
end

------------------//MAIN FUNCTIONS
local function on_character_added(character: Model): ()
	task.defer(follow_character, character)
end

local function on_current_camera_changed(): ()
	local character = localPlayer.Character
	if character then
		follow_character(character)
	end
end

------------------//INIT
localPlayer.CharacterAdded:Connect(on_character_added)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(on_current_camera_changed)

if localPlayer.Character then
	on_character_added(localPlayer.Character)
end

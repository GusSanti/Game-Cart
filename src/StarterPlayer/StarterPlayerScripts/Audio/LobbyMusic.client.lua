local ReplicatedFirst: ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local soundUtility = require(modules:WaitForChild("Utility"):WaitForChild("SoundUtility"))
local packages: Folder = ReplicatedFirst:WaitForChild("Packages")
local soundData = require(packages:WaitForChild("SoundData"))
local musicSound = soundData.Music

------------------//VARIABLES
local musicSoundId: string? = if musicSound then musicSound.Value else nil

------------------//FUNCTIONS

------------------//MAIN FUNCTIONS

------------------//INIT
if musicSoundId and musicSoundId ~= "" and musicSoundId ~= "rbxassetid://0" and not soundUtility.get_current_music() then
	soundUtility.play_music(musicSoundId, true, true)
end

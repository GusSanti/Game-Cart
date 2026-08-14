------------------//SERVICES
local Players: Players = game:GetService("Players")
local ContextActionService: ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local IS_RAMP_SLIDING_ATTRIBUTE: string = "IsRampSliding"
local RAMP_MODE_STATE_ATTRIBUTE: string = "RampModeState"
local CHARGE_STATE: string = "Charge"
local RAMP_LAUNCH_REQUEST_NAME: string = "RampLaunchRequest"
local CHARGE_BAR_SPEED: number = 2.4
local CHARGE_FOV_OSCILLATION_SPEED: number = 5.5
local MIN_CHARGE_FOV_AMPLITUDE: number = 1.5
local MAX_CHARGE_FOV_AMPLITUDE: number = 4
local MIN_LAUNCH_POWER: number = 0.65
local MAX_LAUNCH_POWER: number = 1
local GUI_NAME: string = "RampLaunchGui"
local SPACE_ACTION_NAME: string = "RampLaunchJump"
local CHARGE_FOV_EFFECT_NAME: string = "Charge"

------------------//DEPENDENCIES
local replicatedModules: Folder = ReplicatedStorage:WaitForChild("Modules")
local gameplayModules: Folder = replicatedModules:WaitForChild("Gameplay")
local cameraEffectStackModule = require(gameplayModules:WaitForChild("CameraEffectStack"))

------------------//VARIABLES
type CameraEffectStack = {
	set_effect: (self: CameraEffectStack, effectName: string, fieldOfViewOffset: number) -> (),
}

local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local launchRequest: RemoteEvent = ReplicatedStorage:WaitForChild(RAMP_LAUNCH_REQUEST_NAME) :: RemoteEvent
local launchGui: ScreenGui = playerGui:WaitForChild(GUI_NAME) :: ScreenGui
local panel: Frame = launchGui:WaitForChild("Panel") :: Frame
local barTrack: Frame = panel:WaitForChild("BarTrack") :: Frame
local barFill: Frame = barTrack:WaitForChild("Fill") :: Frame
local character: Model?
local characterStateConnection: RBXScriptConnection?
local characterSlidingConnection: RBXScriptConnection?
local chargeStartedAt: number = 0
local chargeValue: number = 0
local launchRequested: boolean = false

------------------//FUNCTIONS
local function set_gui_visible(isVisible: boolean): ()
	launchGui.Enabled = isVisible
end

local function set_bar_value(value: number): ()
	chargeValue = math.clamp(value, 0, 1)
	barFill.Size = UDim2.fromScale(chargeValue, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(
		255,
		math.floor(140 + 90 * chargeValue),
		math.floor(35 + 80 * chargeValue)
	)
end

local function get_current_character(): Model?
	local currentCharacter = localPlayer.Character
	if currentCharacter and currentCharacter:GetAttribute(IS_RAMP_SLIDING_ATTRIBUTE) == true then
		return currentCharacter
	end

	return nil
end

local function request_launch(): ()
	if launchRequested or not character or character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) ~= CHARGE_STATE then
		return
	end

	launchRequested = true
	set_gui_visible(false)
	local power = MIN_LAUNCH_POWER + (MAX_LAUNCH_POWER - MIN_LAUNCH_POWER) * chargeValue
	launchRequest:FireServer(power)
end

local function update_gui_state(): ()
	local activeCharacter = get_current_character()
	local isCharging = activeCharacter ~= nil
		and activeCharacter:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) == CHARGE_STATE
	if not isCharging then
		set_gui_visible(false)
		return
	end

	if chargeStartedAt == 0 then
		chargeStartedAt = os.clock()
		launchRequested = false
	end
	set_gui_visible(not launchRequested)
end

local function update_charge_fov(): ()
	local cameraEffects: CameraEffectStack? = cameraEffectStackModule.get_current()
	if not cameraEffects then
		return
	end

	local isCharging = character
		and character:GetAttribute(IS_RAMP_SLIDING_ATTRIBUTE) == true
		and character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) == CHARGE_STATE
		and not launchRequested
	if not isCharging then
		cameraEffects:set_effect(CHARGE_FOV_EFFECT_NAME, 0)
		return
	end

	if chargeStartedAt == 0 then
		chargeStartedAt = os.clock()
	end

	local elapsed = os.clock() - chargeStartedAt
	local amplitude = MIN_CHARGE_FOV_AMPLITUDE + MAX_CHARGE_FOV_AMPLITUDE * chargeValue
	local oscillation = math.sin(elapsed * CHARGE_FOV_OSCILLATION_SPEED) * amplitude
	cameraEffects:set_effect(CHARGE_FOV_EFFECT_NAME, oscillation)
end

local function bind_character(newCharacter: Model): ()
	if characterStateConnection then
		characterStateConnection:Disconnect()
		characterStateConnection = nil
	end
	if characterSlidingConnection then
		characterSlidingConnection:Disconnect()
		characterSlidingConnection = nil
	end

	character = newCharacter
	chargeStartedAt = 0
	chargeValue = 0
	launchRequested = false
	set_bar_value(0)
	set_gui_visible(false)
	characterStateConnection = newCharacter:GetAttributeChangedSignal(RAMP_MODE_STATE_ATTRIBUTE):Connect(update_gui_state)
	characterSlidingConnection = newCharacter:GetAttributeChangedSignal(IS_RAMP_SLIDING_ATTRIBUTE):Connect(update_gui_state)
	update_gui_state()
end

------------------//MAIN FUNCTIONS
local function update_charge_bar(): ()
	update_charge_fov()

	if not character or character:GetAttribute(IS_RAMP_SLIDING_ATTRIBUTE) ~= true then
		return
	end
	if character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) ~= CHARGE_STATE or launchRequested then
		return
	end

	if chargeStartedAt == 0 then
		chargeStartedAt = os.clock()
	end

	local elapsed = os.clock() - chargeStartedAt
	local value = (math.sin(elapsed * CHARGE_BAR_SPEED) + 1) * 0.5
	set_bar_value(value)
end

local function on_input_began(inputObject: InputObject): ()
	if inputObject.KeyCode == Enum.KeyCode.Space then
		request_launch()
	end
end

local function on_space_action(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if character and character:GetAttribute(RAMP_MODE_STATE_ATTRIBUTE) == CHARGE_STATE then
		request_launch()
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

------------------//INIT
localPlayer.CharacterAdded:Connect(bind_character)
UserInputService.JumpRequest:Connect(request_launch)
UserInputService.InputBegan:Connect(on_input_began)
ContextActionService:BindActionAtPriority(
	SPACE_ACTION_NAME,
	on_space_action,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.Space
)
RunService.RenderStepped:Connect(update_charge_bar)

if localPlayer.Character then
	bind_character(localPlayer.Character)
end

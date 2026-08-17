------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting: Lighting = game:GetService("Lighting")
local TweenService: TweenService = game:GetService("TweenService")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local DEFAULT_MUSIC_ENABLED: boolean = true
local DEFAULT_SFX_ENABLED: boolean = true
local DEFAULT_MUSIC_VOLUME: number = 0.5
local DEFAULT_SFX_VOLUME: number = 0.5
local DEFAULT_SHADOWS_ENABLED: boolean = true
local DEFAULT_VFX_ENABLED: boolean = true
local VFX_ENABLED_ATTRIBUTE: string = "VFXEnabled"
local SETTINGS_REMOTES_FOLDER_NAME: string = "SettingsRemotes"
local SET_SETTING_REMOTE_NAME: string = "SetSetting"
local MUSIC_ENABLED_SETTING: string = "MusicEnabled"
local SFX_ENABLED_SETTING: string = "SFXEnabled"
local MUSIC_VOLUME_SETTING: string = "MusicVolume"
local SFX_VOLUME_SETTING: string = "SFXVolume"
local SHADOWS_ENABLED_SETTING: string = "ShadowsEnabled"
local VFX_ENABLED_SETTING: string = "VFXEnabled"
local TOGGLE_TWEEN_DURATION: number = 0.18
local ACTIVE_KNOB_POSITION: UDim2 = UDim2.new(1, -34, 0.5, 0)
local INACTIVE_KNOB_POSITION: UDim2 = UDim2.new(0, 4, 0.5, 0)

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local hudAnim = require(modules:WaitForChild("Interface"):WaitForChild("HudAnim"))
local soundUtility = require(modules:WaitForChild("Utility"):WaitForChild("SoundUtility"))

------------------//VARIABLES
type ToggleStyle = {
	backgroundColor: Color3,
	gradientColor: ColorSequence,
}

type SliderBinding = {
	slider: Frame,
	fill: Frame,
	knob: ImageButton,
	valueLabel: TextLabel,
	settingName: string,
	currentValue: number,
	persistedValue: number,
	applyValue: (number) -> (),
}

local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local setSettingRemote: RemoteFunction
local boundMainGui: ScreenGui?
local activeSlider: SliderBinding?
local settingsConnections: {RBXScriptConnection} = {}
local inputConnections: {RBXScriptConnection} = {}
local activeToggleStyle: ToggleStyle
local inactiveToggleStyle: ToggleStyle

------------------//FUNCTIONS
local function connect_setting(connection: RBXScriptConnection): ()
	table.insert(settingsConnections, connection)
end

local function clear_settings_connections(): ()
	for _, connection in settingsConnections do
		connection:Disconnect()
	end
	table.clear(settingsConnections)
	activeSlider = nil
end

local function get_boolean_setting(path: string, defaultValue: boolean): boolean
	local value = dataUtility.client.get(path)
	return if type(value) == "boolean" then value else defaultValue
end

local function get_number_setting(path: string, defaultValue: number): number
	local value = dataUtility.client.get(path)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return defaultValue
	end

	return math.clamp(value, 0, 1)
end

local function save_setting(settingName: string, value: boolean | number): boolean
	local success, result = pcall(function(): any
		return setSettingRemote:InvokeServer(settingName, value)
	end)

	return success and result == true
end

local function get_toggle_style(toggle: TextButton): ToggleStyle
	local gradient = toggle:FindFirstChildOfClass("UIGradient")
	return {
		backgroundColor = toggle.BackgroundColor3,
		gradientColor = if gradient then gradient.Color else ColorSequence.new(toggle.BackgroundColor3),
	}
end

local function apply_toggle_style(toggle: TextButton, isOn: boolean): ()
	local style = if isOn then activeToggleStyle else inactiveToggleStyle
	toggle.BackgroundColor3 = style.backgroundColor

	local gradient = toggle:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = style.gradientColor
	end
end

local function render_toggle(toggle: TextButton, isOn: boolean, animate: boolean): ()
	toggle:SetAttribute("IsOn", isOn)
	apply_toggle_style(toggle, isOn)

	local knob = toggle:FindFirstChild("Knob")
	if not knob or not knob:IsA("GuiObject") then
		return
	end

	local targetPosition = if isOn then ACTIVE_KNOB_POSITION else INACTIVE_KNOB_POSITION
	if animate then
		local tween = TweenService:Create(
			knob,
			TweenInfo.new(TOGGLE_TWEEN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Position = targetPosition}
		)
		tween:Play()
	else
		knob.Position = targetPosition
	end
end

local function bind_toggle(
	toggle: TextButton,
	initialValue: boolean,
	settingName: string,
	getSettingValue: (boolean) -> boolean,
	applyValue: (boolean) -> ()
): ()
	local currentValue = initialValue
	render_toggle(toggle, currentValue, false)

	connect_setting(toggle.Activated:Connect(function()
		local previousValue = currentValue
		currentValue = not currentValue
		render_toggle(toggle, currentValue, true)
		applyValue(currentValue)

		if not save_setting(settingName, getSettingValue(currentValue)) then
			currentValue = previousValue
			render_toggle(toggle, currentValue, true)
			applyValue(currentValue)
		end
	end))
end

local function render_slider(binding: SliderBinding, value: number): ()
	binding.currentValue = math.clamp(value, 0, 1)
	binding.fill.Size = UDim2.new(binding.currentValue, 0, 1, 0)
	binding.knob.Position = UDim2.new(binding.currentValue, 0, 0.5, 0)
	binding.valueLabel.Text = ("%d%%"):format(math.round(binding.currentValue * 100))
end

local function is_pointer_start(inputType: Enum.UserInputType): boolean
	return inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
end

local function is_pointer_move(inputType: Enum.UserInputType): boolean
	return inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch
end

local function update_slider_from_input(binding: SliderBinding, input: InputObject): ()
	local sliderWidth = binding.slider.AbsoluteSize.X
	if sliderWidth <= 0 then
		return
	end

	local value = (input.Position.X - binding.slider.AbsolutePosition.X) / sliderWidth
	render_slider(binding, math.clamp(value, 0, 1))
	binding.applyValue(binding.currentValue)
end

local function bind_slider(
	slider: Frame,
	fill: Frame,
	knob: ImageButton,
	valueLabel: TextLabel,
	initialValue: number,
	settingName: string,
	applyValue: (number) -> ()
): SliderBinding
	local binding: SliderBinding = {
		slider = slider,
		fill = fill,
		knob = knob,
		valueLabel = valueLabel,
		settingName = settingName,
		currentValue = initialValue,
		persistedValue = initialValue,
		applyValue = applyValue,
	}

	knob:SetAttribute("UIAnim", false)
	hudAnim.unbind(knob)
	render_slider(binding, initialValue)

	local function begin_drag(input: InputObject): ()
		if not is_pointer_start(input.UserInputType) then
			return
		end

		activeSlider = binding
		update_slider_from_input(binding, input)
	end

	connect_setting(slider.InputBegan:Connect(begin_drag))
	connect_setting(knob.InputBegan:Connect(begin_drag))

	return binding
end

local function apply_music_volume(value: number): ()
	soundUtility.set_music_volume(value)
end

local function apply_sfx_volume(value: number): ()
	soundUtility.set_sfx_volume(value)
end

local function apply_music_muted(isMuted: boolean): ()
	soundUtility.mute_music(isMuted)
end

local function apply_sfx_muted(isMuted: boolean): ()
	soundUtility.mute_sfx(isMuted)
end

local function apply_shadows_enabled(isEnabled: boolean): ()
	Lighting.GlobalShadows = isEnabled
end

local function apply_vfx_enabled(isEnabled: boolean): ()
	localPlayer:SetAttribute(VFX_ENABLED_ATTRIBUTE, isEnabled)
end

------------------//MAIN FUNCTIONS
local function bind_main_gui(mainGui: ScreenGui): ()
	if boundMainGui == mainGui then
		return
	end

	clear_settings_connections()
	boundMainGui = mainGui

	local framesFolder: Folder = mainGui:WaitForChild("Frames") :: Folder
	local settingsFrame: Frame = framesFolder:WaitForChild("Settings") :: Frame
	local content: Frame = settingsFrame:WaitForChild("Content") :: Frame
	local scrollingFrame: ScrollingFrame = content:WaitForChild("ScrollingFrame") :: ScrollingFrame
	local musicMute: Frame = scrollingFrame:WaitForChild("MusicMute") :: Frame
	local sfxMute: Frame = scrollingFrame:WaitForChild("SFXMute") :: Frame
	local musicVolume: Frame = scrollingFrame:WaitForChild("MusicVolume") :: Frame
	local sfxVolume: Frame = scrollingFrame:WaitForChild("SFXVolume") :: Frame
	local shadows: Frame = scrollingFrame:WaitForChild("Shadows") :: Frame
	local vfxEnable: Frame = scrollingFrame:WaitForChild("VFXEnable") :: Frame

	local musicMuteToggle: TextButton = musicMute:WaitForChild("Toggle") :: TextButton
	local sfxMuteToggle: TextButton = sfxMute:WaitForChild("Toggle") :: TextButton
	local shadowsToggle: TextButton = shadows:WaitForChild("Toggle") :: TextButton
	local vfxToggle: TextButton = vfxEnable:WaitForChild("Toggle") :: TextButton
	activeToggleStyle = get_toggle_style(shadowsToggle)
	inactiveToggleStyle = get_toggle_style(musicMuteToggle)

	local musicSlider: Frame = musicVolume:WaitForChild("Slider") :: Frame
	local musicFill: Frame = musicSlider:WaitForChild("Fill") :: Frame
	local musicKnob: ImageButton = musicSlider:WaitForChild("Knob") :: ImageButton
	local musicValueLabel: TextLabel = musicVolume:WaitForChild("Value") :: TextLabel
	local sfxSlider: Frame = sfxVolume:WaitForChild("Slider") :: Frame
	local sfxFill: Frame = sfxSlider:WaitForChild("Fill") :: Frame
	local sfxKnob: ImageButton = sfxSlider:WaitForChild("Knob") :: ImageButton
	local sfxValueLabel: TextLabel = sfxVolume:WaitForChild("Value") :: TextLabel

	local musicEnabled = get_boolean_setting("Settings.MusicEnabled", DEFAULT_MUSIC_ENABLED)
	local sfxEnabled = get_boolean_setting("Settings.SFXEnabled", DEFAULT_SFX_ENABLED)
	local musicVolumeValue = get_number_setting("Settings.MusicVolume", DEFAULT_MUSIC_VOLUME)
	local sfxVolumeValue = get_number_setting("Settings.SFXVolume", DEFAULT_SFX_VOLUME)
	local shadowsEnabled = get_boolean_setting("Settings.ShadowsEnabled", DEFAULT_SHADOWS_ENABLED)
	local vfxEnabled = get_boolean_setting("Settings.VFXEnabled", DEFAULT_VFX_ENABLED)

	apply_music_volume(musicVolumeValue)
	apply_sfx_volume(sfxVolumeValue)
	apply_music_muted(not musicEnabled)
	apply_sfx_muted(not sfxEnabled)
	apply_shadows_enabled(shadowsEnabled)
	apply_vfx_enabled(vfxEnabled)

	bind_toggle(musicMuteToggle, not musicEnabled, MUSIC_ENABLED_SETTING, function(isMuted: boolean): boolean
		return not isMuted
	end, apply_music_muted)
	bind_toggle(sfxMuteToggle, not sfxEnabled, SFX_ENABLED_SETTING, function(isMuted: boolean): boolean
		return not isMuted
	end, apply_sfx_muted)
	bind_toggle(shadowsToggle, shadowsEnabled, SHADOWS_ENABLED_SETTING, function(isEnabled: boolean): boolean
		return isEnabled
	end, apply_shadows_enabled)
	bind_toggle(vfxToggle, vfxEnabled, VFX_ENABLED_SETTING, function(isEnabled: boolean): boolean
		return isEnabled
	end, apply_vfx_enabled)

	bind_slider(
		musicSlider,
		musicFill,
		musicKnob,
		musicValueLabel,
		musicVolumeValue,
		MUSIC_VOLUME_SETTING,
		apply_music_volume
	)
	bind_slider(
		sfxSlider,
		sfxFill,
		sfxKnob,
		sfxValueLabel,
		sfxVolumeValue,
		SFX_VOLUME_SETTING,
		apply_sfx_volume
	)
end

------------------//INIT
local settingsRemotes: Folder = ReplicatedStorage:WaitForChild(SETTINGS_REMOTES_FOLDER_NAME) :: Folder
setSettingRemote = settingsRemotes:WaitForChild(SET_SETTING_REMOTE_NAME) :: RemoteFunction

table.insert(inputConnections, UserInputService.InputChanged:Connect(function(input: InputObject)
	local binding = activeSlider
	if not binding or not is_pointer_move(input.UserInputType) then
		return
	end

	update_slider_from_input(binding, input)
end))

table.insert(inputConnections, UserInputService.InputEnded:Connect(function(input: InputObject)
	local binding = activeSlider
	if not binding or not is_pointer_start(input.UserInputType) then
		return
	end

	activeSlider = nil
	if save_setting(binding.settingName, binding.currentValue) then
		binding.persistedValue = binding.currentValue
	else
		render_slider(binding, binding.persistedValue)
		binding.applyValue(binding.currentValue)
	end
end))

bind_main_gui(playerGui:WaitForChild("Main") :: ScreenGui)

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == "Main" and child:IsA("ScreenGui") then
		bind_main_gui(child)
	end
end)

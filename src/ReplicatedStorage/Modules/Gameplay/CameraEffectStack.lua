------------------//CONSTANTS
local DEFAULT_SMOOTHING_SPEED: number = 10
local MIN_FIELD_OF_VIEW: number = 1
local MAX_FIELD_OF_VIEW: number = 120
local FIELD_OF_VIEW_CHANGE_EPSILON: number = 0.001

------------------//VARIABLES
type EffectOffsets = {[string]: number}
type CameraEffectStack = {
	_camera: Camera?,
	_baseFieldOfView: number,
	_currentOffset: number,
	_currentRoll: number,
	_smoothingSpeed: number,
	_lastAppliedFieldOfView: number,
	_lastAppliedCameraCFrame: CFrame?,
	_lastAppliedRoll: number,
	_fieldOfViewOffsets: EffectOffsets,
	_rollOffsets: EffectOffsets,

	set_effect: (self: CameraEffectStack, effectName: string, fieldOfViewOffset: number) -> (),
	set_roll: (self: CameraEffectStack, effectName: string, rollOffset: number) -> (),
	remove_effect: (self: CameraEffectStack, effectName: string) -> (),
	clear_effects: (self: CameraEffectStack) -> (),
	set_base_field_of_view: (self: CameraEffectStack, fieldOfView: number) -> (),
	get_base_field_of_view: (self: CameraEffectStack) -> number,
	get_effect_offset: (self: CameraEffectStack, effectName: string) -> number,
	get_target_field_of_view: (self: CameraEffectStack) -> number,
	get_current_field_of_view: (self: CameraEffectStack) -> number,
	get_current_roll: (self: CameraEffectStack) -> number,
	step: (self: CameraEffectStack, deltaTime: number) -> (),
	destroy: (self: CameraEffectStack) -> (),
}

local cameraEffectStack = {}
cameraEffectStack.__index = cameraEffectStack
local currentCameraEffectStack: CameraEffectStack?

------------------//FUNCTIONS
local function is_finite_number(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function clamp_field_of_view(fieldOfView: number): number
	return math.clamp(fieldOfView, MIN_FIELD_OF_VIEW, MAX_FIELD_OF_VIEW)
end

local function get_effect_offset_sum(effectOffsets: EffectOffsets): number
	local totalOffset: number = 0
	for _, fieldOfViewOffset in effectOffsets do
		totalOffset += fieldOfViewOffset
	end

	return totalOffset
end

local function get_smoothing_alpha(smoothingSpeed: number, deltaTime: number): number
	if smoothingSpeed <= 0 then
		return 1
	end

	return 1 - math.exp(-smoothingSpeed * deltaTime)
end

------------------//MAIN FUNCTIONS
function cameraEffectStack.create(
	camera: Camera,
	baseFieldOfView: number?,
	smoothingSpeed: number?
): CameraEffectStack
	local initialFieldOfView = if baseFieldOfView and is_finite_number(baseFieldOfView)
		then clamp_field_of_view(baseFieldOfView)
		else clamp_field_of_view(camera.FieldOfView)
	local resolvedSmoothingSpeed = if smoothingSpeed and is_finite_number(smoothingSpeed)
		then math.max(0, smoothingSpeed)
		else DEFAULT_SMOOTHING_SPEED

	local self = setmetatable({
		_camera = camera,
		_baseFieldOfView = initialFieldOfView,
		_currentOffset = 0,
		_currentRoll = 0,
		_smoothingSpeed = resolvedSmoothingSpeed,
		_lastAppliedFieldOfView = initialFieldOfView,
		_lastAppliedCameraCFrame = nil,
		_lastAppliedRoll = 0,
		_fieldOfViewOffsets = {},
		_rollOffsets = {},
	}, cameraEffectStack) :: CameraEffectStack

	return self
end

function cameraEffectStack.get_or_create(
	camera: Camera,
	baseFieldOfView: number?,
	smoothingSpeed: number?
): CameraEffectStack
	if currentCameraEffectStack and currentCameraEffectStack._camera == camera then
		return currentCameraEffectStack
	end

	if currentCameraEffectStack then
		currentCameraEffectStack:destroy()
	end

	local createdStack = cameraEffectStack.create(camera, baseFieldOfView, smoothingSpeed)
	currentCameraEffectStack = createdStack
	return createdStack
end

function cameraEffectStack.get_current(): CameraEffectStack?
	return currentCameraEffectStack
end

function cameraEffectStack.set_effect(
	self: CameraEffectStack,
	effectName: string,
	fieldOfViewOffset: number
): ()
	if effectName == "" or not is_finite_number(fieldOfViewOffset) then
		return
	end

	if fieldOfViewOffset == 0 then
		self._fieldOfViewOffsets[effectName] = nil
		return
	end

	self._fieldOfViewOffsets[effectName] = fieldOfViewOffset
end

function cameraEffectStack.set_roll(
	self: CameraEffectStack,
	effectName: string,
	rollOffset: number
): ()
	if effectName == "" or not is_finite_number(rollOffset) then
		return
	end

	if rollOffset == 0 then
		self._rollOffsets[effectName] = nil
		return
	end

	self._rollOffsets[effectName] = rollOffset
end

function cameraEffectStack.remove_effect(self: CameraEffectStack, effectName: string): ()
	self._fieldOfViewOffsets[effectName] = nil
	self._rollOffsets[effectName] = nil
end

function cameraEffectStack.clear_effects(self: CameraEffectStack): ()
	table.clear(self._fieldOfViewOffsets)
	table.clear(self._rollOffsets)
end

function cameraEffectStack.set_base_field_of_view(self: CameraEffectStack, fieldOfView: number): ()
	if not is_finite_number(fieldOfView) then
		return
	end

	self._baseFieldOfView = clamp_field_of_view(fieldOfView)
	local camera = self._camera
	if camera then
		self._lastAppliedFieldOfView = camera.FieldOfView
	end
end

function cameraEffectStack.get_base_field_of_view(self: CameraEffectStack): number
	return self._baseFieldOfView
end

function cameraEffectStack.get_effect_offset(self: CameraEffectStack, effectName: string): number
	return self._fieldOfViewOffsets[effectName] or 0
end

function cameraEffectStack.get_target_field_of_view(self: CameraEffectStack): number
	local targetFieldOfView = self._baseFieldOfView + get_effect_offset_sum(self._fieldOfViewOffsets)
	return clamp_field_of_view(targetFieldOfView)
end

function cameraEffectStack.get_current_field_of_view(self: CameraEffectStack): number
	local camera = self._camera
	return if camera then camera.FieldOfView else self._baseFieldOfView
end

function cameraEffectStack.get_current_roll(self: CameraEffectStack): number
	return self._currentRoll
end

function cameraEffectStack.step(self: CameraEffectStack, deltaTime: number): ()
	local camera = self._camera
	if not camera or not is_finite_number(deltaTime) or deltaTime < 0 then
		return
	end

	local externalFieldOfViewChange = camera.FieldOfView - self._lastAppliedFieldOfView
	if math.abs(externalFieldOfViewChange) > FIELD_OF_VIEW_CHANGE_EPSILON then
		self._baseFieldOfView = clamp_field_of_view(self._baseFieldOfView + externalFieldOfViewChange)
	end

	local targetOffset = get_effect_offset_sum(self._fieldOfViewOffsets)
	local targetRoll = get_effect_offset_sum(self._rollOffsets)
	local smoothingAlpha = get_smoothing_alpha(self._smoothingSpeed, deltaTime)
	self._currentOffset += (targetOffset - self._currentOffset) * smoothingAlpha
	self._currentRoll += (targetRoll - self._currentRoll) * smoothingAlpha

	local targetFieldOfView = clamp_field_of_view(self._baseFieldOfView + self._currentOffset)
	camera.FieldOfView = targetFieldOfView
	if self._lastAppliedCameraCFrame and camera.CFrame == self._lastAppliedCameraCFrame then
		camera.CFrame *= CFrame.Angles(0, 0, math.rad(-self._lastAppliedRoll))
	end
	camera.CFrame *= CFrame.Angles(0, 0, math.rad(self._currentRoll))
	self._lastAppliedFieldOfView = targetFieldOfView
	self._lastAppliedCameraCFrame = camera.CFrame
	self._lastAppliedRoll = self._currentRoll
end

function cameraEffectStack.destroy(self: CameraEffectStack): ()
	table.clear(self._fieldOfViewOffsets)
	table.clear(self._rollOffsets)
	if currentCameraEffectStack == self then
		currentCameraEffectStack = nil
	end
	self._camera = nil
	self._lastAppliedCameraCFrame = nil
	self._lastAppliedRoll = 0
end

------------------//INIT
return cameraEffectStack

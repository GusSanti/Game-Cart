------------------//SERVICES
local CollectionService: CollectionService = game:GetService("CollectionService")

------------------//CONSTANTS
local RAMP_TAG: string = "Ramp"
local RAMP_NAME: string = "Ramp"
local JUMP_AREA_NAME: string = "JumpArea"
local WORLD_ATTRIBUTE: string = "World"
local DEFAULT_WORLD: number = 1

------------------//VARIABLES
local rampUtility = {}

------------------//FUNCTIONS
local function parse_world_id(value: any): number?
	local numericValue: number?
	if type(value) == "number" then
		numericValue = value
	elseif type(value) == "string" then
		numericValue = tonumber(value) or tonumber(string.match(value, "%d+"))
	end

	if not numericValue or numericValue ~= numericValue or numericValue < DEFAULT_WORLD or numericValue == math.huge then
		return nil
	end

	return math.floor(numericValue)
end

local function is_named_ramp(instance: Instance): boolean
	return string.lower(instance.Name) == string.lower(RAMP_NAME)
end

local function is_named_jump_area(instance: Instance): boolean
	return string.lower(instance.Name) == string.lower(JUMP_AREA_NAME)
end

------------------//MAIN FUNCTIONS
function rampUtility.get_ramp_ancestor(instance: Instance): Instance?
	local current: Instance? = instance
	while current and current ~= workspace do
		if CollectionService:HasTag(current, RAMP_TAG) or is_named_ramp(current) then
			return current
		end
		current = current.Parent
	end

	return nil
end

function rampUtility.is_ramp(instance: Instance): boolean
	return rampUtility.get_ramp_ancestor(instance) ~= nil
end

function rampUtility.get_jump_area_ancestor(instance: Instance): Instance?
	local current: Instance? = instance
	while current and current ~= workspace do
		if is_named_jump_area(current) then
			return current
		end
		current = current.Parent
	end

	return nil
end

function rampUtility.is_jump_area(instance: Instance): boolean
	return rampUtility.get_jump_area_ancestor(instance) ~= nil
end

function rampUtility.get_world_id(instance: Instance): number
	local current: Instance? = instance
	while current and current ~= workspace do
		local attributeWorld = parse_world_id(current:GetAttribute(WORLD_ATTRIBUTE))
		if attributeWorld then
			return attributeWorld
		end

		local namedWorld = string.match(current.Name, "^[Ww]orld[%s_%-]*(%d+)$")
			or string.match(current.Name, "^[Mm]undo[%s_%-]*(%d+)$")
		local parsedNamedWorld = parse_world_id(namedWorld)
		if parsedNamedWorld then
			return parsedNamedWorld
		end

		current = current.Parent
	end

	return DEFAULT_WORLD
end

function rampUtility.get_ramp_tag(): string
	return RAMP_TAG
end

------------------//INIT
return rampUtility

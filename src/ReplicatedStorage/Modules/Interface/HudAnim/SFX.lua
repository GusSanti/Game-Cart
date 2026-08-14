------------------//DEPENDENCIES
local soundUtility = require(script.Parent.Parent.Parent.Utility.SoundUtility)


------------------//VARIABLES
local sfx = {}
local defaults = {
	sfx_volume = 0.8,
	sfx_speed = 1.0,
	sfx_hover = "",
	sfx_down = "",
	sfx_up = "",
	sfx_click = "",
	sfx_select = "",
	sfx_deselect = "",
	sfx_open = "",
	sfx_close = "",
}

------------------//FUNCTIONS

------------------//MAIN FUNCTIONS
function sfx.set_defaults(opts)
	for k, v in opts do defaults[k] = v end
end

function sfx.get_id_for(inst, key)
	return inst:GetAttribute(key) or defaults[key] or ""
end

function sfx.play_for(inst, key)
	if soundUtility.is_sfx_muted() then return end

	local id = sfx.get_id_for(inst, key)
	if id == "" or id == "rbxassetid://0" then return end

	local volume = inst:GetAttribute("sfx_volume") or defaults.sfx_volume
	local speed = inst:GetAttribute("sfx_speed") or defaults.sfx_speed
	soundUtility.play_sfx(id, nil, volume, speed)
end

------------------//INIT
return sfx

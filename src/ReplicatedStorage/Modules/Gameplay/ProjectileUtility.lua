------------------//MAIN FUNCTIONS
local projectileUtility = {}

function projectileUtility.get_flight_duration(
	origin: Vector3,
	target: Vector3,
	minimumDuration: number,
	maximumDuration: number,
	maximumDistance: number
): number
	local distanceProgress = math.clamp((target - origin).Magnitude / maximumDistance, 0, 1)
	return minimumDuration + (maximumDuration - minimumDuration) * distanceProgress
end

function projectileUtility.get_launch_velocity(
	origin: Vector3,
	target: Vector3,
	flightDuration: number,
	gravity: number
): Vector3
	local gravityAcceleration = Vector3.new(0, -gravity, 0)
	return (target - origin) / flightDuration - gravityAcceleration * flightDuration * 0.5
end

function projectileUtility.get_position(
	origin: Vector3,
	launchVelocity: Vector3,
	elapsed: number,
	gravity: number
): Vector3
	return origin
		+ launchVelocity * elapsed
		+ Vector3.new(0, -gravity, 0) * elapsed * elapsed * 0.5
end

function projectileUtility.get_surface_cframe(
	position: Vector3,
	surfaceNormal: Vector3,
	referenceDirection: Vector3
): CFrame
	local surfaceDirection = referenceDirection - surfaceNormal * referenceDirection:Dot(surfaceNormal)
	if surfaceDirection.Magnitude < 0.01 then
		surfaceDirection = surfaceNormal:Cross(Vector3.xAxis)
	end
	if surfaceDirection.Magnitude < 0.01 then
		surfaceDirection = surfaceNormal:Cross(Vector3.zAxis)
	end
	return CFrame.lookAt(position, position + surfaceDirection.Unit, surfaceNormal)
end

------------------//INIT
return projectileUtility

local oi = init
local ou = update
local rotationSpeed

function init()
	if oi then oi() end
	
	rotationSpeed = config.getParameter("rotationSpeed", 1)
end

function update(dt)
	if ou then ou(dt) end
	
	local velocity = mcontroller.velocity()
	local dir = velocity[1] > 0 and 1 or -1
	local rotation = (vec2.mag(velocity) / 180 * math.pi) * -dir * dt * rotationSpeed * (self.returning and -1 or 1)
	mcontroller.setRotation(mcontroller.rotation() + rotation)
end
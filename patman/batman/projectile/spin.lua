local oldInit = init
local oldUpdate = update
local rotationSpeed

function init()
	if oldInit then oldInit() end
	
	rotationSpeed = config.getParameter("rotationSpeed", 1)
end

function update(dt)
	if oldUpdate then oldUpdate(dt) end
	
	local velocity = mcontroller.velocity()
	local direction = velocity[1] > 0 and 1 or -1
	local rotation = (vec2.mag(velocity) / 180 * math.pi) * dt * -direction * rotationSpeed * (self.returning and -1 or 1)
	mcontroller.setRotation(mcontroller.rotation() + rotation)
end
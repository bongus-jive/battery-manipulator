require "/scripts/vec2.lua"
require "/scripts/messageutil.lua"

function init()
  local getConfig = config.getParameter

  self.ownerId = projectile.sourceEntity()
  
  self.speed = getConfig("speed")
  self.timeToLive = getConfig("timeToLive")

  self.returning = getConfig("returning", false)
  self.returnOnHit = getConfig("returnOnHit", false)
  self.ignoreTerrain = getConfig("ignoreTerrain", false)
  self.controlForce = getConfig("controlForce", 150)
  self.snapControlForce = getConfig("snapControlForce", 500)
  self.pickupDistance = getConfig("pickupDistance", 1)
  self.snapDistance = getConfig("snapDistance", 9)
  self.minVelocity = getConfig("minVelocity", 0.2)
  self.bounceReturnTimer = 0
  self.bounceReturnIncrease = getConfig("bounceReturnIncrease", 0.25)
  self.bounceReturnThreshold = getConfig("bounceReturnThreshold", 1)
  
	self.rotationSpeed = getConfig("rotationSpeed")
  self.messageOnHit = getConfig("messageOnHit")
  
  self.hasConducted = false
  self.conductMonster = getConfig("conductMonster")
  self.conductLiquidPercentage = getConfig("conductLiquidPercentage", 0.5)

  if self.ignoreTerrain then
    disableCollision()
  end

  message.setHandler("forceReturn", simpleHandler(forceReturn))
  message.setHandler("setTargetPosition", simpleHandler(setTargetPosition))
end

function update(dt)
  if not self.ownerId or not world.entityExists(self.ownerId) then
    projectile.die()
    return
  end

  updateBoomerang(dt)

  if self.rotationSpeed then
    updateRotation(dt)
  end

  if self.returning and canConduct() then
    triggerConduction()
  end
end

function updateRotation(dt)
  local velocity = mcontroller.velocity()
  local direction = velocity[1] > 0 and 1 or -1
  local rotate = (vec2.mag(velocity) / 180 * math.pi) * dt * direction * self.rotationSpeed * (self.returning and 1 or -1)
  mcontroller.setRotation(mcontroller.rotation() + rotate)
end

function updateBoomerang(dt)
  local force = self.controlForce

  if not self.returning then
    mcontroller.approachVelocity({0, 0}, force)

    local velocityMag = vec2.mag(mcontroller.velocity())
    if velocityMag < self.minVelocity or (mcontroller.isColliding() and not self.ignoreTerrain) then
      self.returning = true
    end
    
    return
  end

  if self.bounceReturnTimer > 0 then
    self.bounceReturnTimer = math.max(0, self.bounceReturnTimer - dt)
  end

  local targetPosition = self.targetPosition or world.entityPosition(self.ownerId)
  local toTarget = world.distance(targetPosition, mcontroller.position())
  local targetDistance = vec2.mag(toTarget)

  if targetDistance < self.pickupDistance then
    pickupBoomerang()
    return
  end

  local toTargetVelocity = vec2.mul(vec2.norm(toTarget), self.speed)

  if projectile.timeToLive() < self.timeToLive * 0.5 then
    disableCollision()
    force = self.snapControlForce
  elseif targetDistance < self.snapDistance then
    force = self.snapControlForce
  end

  mcontroller.approachVelocity(toTargetVelocity, force)
end

function canConduct()
  return (not self.hasConducted) and mcontroller.liquidPercentage() > self.conductLiquidPercentage
end

function triggerConduction()
  self.hasConducted = true
  world.spawnMonster(self.conductMonster, mcontroller.position(), getConductMonsterParams())
end

function hit(entityId)
  if self.returnOnHit then
    self.returning = true 
  end

  if self.messageOnHit then
    world.sendEntityMessage(entityId, self.messageOnHit, self.ownerId, getMessageOnHitParams())
  end

  if canConduct() then
    triggerConduction()
  end
end

function bounce()
  if self.returning then
    self.bounceReturnTimer = self.bounceReturnTimer + self.bounceReturnIncrease
    if self.bounceReturnTimer > self.bounceReturnThreshold then
      disableCollision()
    end
  end
end

function pickupBoomerang()
  projectile.die()
end

function disableCollision()
  mcontroller.applyParameters({collisionEnabled = false})
end

function getMessageOnHitParams()
  return {
    powerMultiplier = projectile.powerMultiplier()
  }
end

function getConductMonsterParams()
  return {
    powerMultiplier = projectile.powerMultiplier(),
    ownerId = self.ownerId
  }
end

function forceReturn(controlForce, pickupDistance)
  self.returning = true
  self.controlForce = controlForce or self.controlForce
  self.pickupDistance = pickupDistance or self.pickupDistance
  disableCollision()
end

function setTargetPosition(targetPosition)
  self.targetPosition = targetPosition
end

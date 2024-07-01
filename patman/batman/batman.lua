require "/scripts/vec2.lua"
require "/scripts/status.lua"
require "/scripts/activeitem/stances.lua"

function init()
  local cfg = config.getParameter("batmanConfig")
  for k, v in pairs(cfg) do
    self[k] = v
  end

  activeItem.setCursor("/cursors/reticle0.cursor")
  activeItem.setOutsideOfHand(true)
  
  self.damageLevelMultiplier = root.evalFunction("weaponDamageLevelMultiplier", config.getParameter("level", 1))
  
  self.orbitRate = self.orbitRate * -2 * math.pi
  self.orbitRateShielded = self.orbitRateShielded * -2 * math.pi
  self.orbitRotation = 0
  
  self.orbRotationRate = self.orbRotationRate * 2 * math.pi
  self.orbRotationRateShielded = self.orbRotationRateShielded * 2 * math.pi
  self.orbRotations = {}
  
  storage.lastOrb = storage.lastOrb or 1
  storage.projectileIds = storage.projectileIds or {}

  for i = 1, self.orbCount do
    storage.projectileIds[i] = storage.projectileIds[i] or false
    self.orbRotations[i] = 0
    animator.setAnimationState("orb"..i, storage.projectileIds[i] == false and "orb" or "hidden")
  end
  
  checkProjectiles(true)

  self.shieldActive = false
  self.shieldTransformTimer = 0
  self.shieldPoly = animator.partPoly("glove", "shieldPoly")

  if self.shieldKnockback > 0 then
    self.knockbackDamageSource = {
      poly = self.shieldPoly,
      damage = 0,
      damageType = "Knockback",
      sourceEntity = activeItem.ownerEntityId(),
      team = activeItem.ownerTeam(),
      knockback = self.shieldKnockback,
      rayCheck = true,
      damageRepeatTimeout = 0.5
    }
  end

  initStances()
  setStance("idle")

  animator.resetTransformationGroup("orbs")
  animator.stopAllSounds("shieldLoop")
  animator.setSoundVolume("shieldLoop", 0)
  animator.playSound("shieldLoop", -1)
end

function update(dt, fireMode, shiftHeld)
  updateStance(dt)
  checkProjectiles()
  
  local nextOrbIndex = nextOrb()

  if fireMode == "primary" and self.lastFireMode ~= "primary" and nextOrbIndex then
    fire(nextOrbIndex)
    storage.lastOrb = nextOrbIndex
  end

  if self.shieldActive then
    if fireMode == "alt"
    and availableOrbCount() == self.orbCount
    and status.resourcePositive("shieldStamina")
    and status.overConsumeResource("energy", self.shieldEnergyCost * dt) then
      self.shieldTransformTimer = math.min(self.shieldTransformTime, self.shieldTransformTimer + dt)
      self.listener:update()
    else
      deactivateShield()
    end
  else
    if fireMode == "alt" then
      if availableOrbCount() == self.orbCount
      and status.resourcePositive("shieldStamina")
      and not status.resourceLocked("energy") then
        activateShield()
      elseif self.lastFireMode ~= "alt" then
        sendMessageToOrbs("return", self.orbReturnControlForce, self.orbReturnPickupDistance)
      end
    else
      self.shieldTransformTimer = math.max(0, self.shieldTransformTimer - dt)
    end
  end

  local transformRatio = self.shieldTransformTimer / self.shieldTransformTime
  animator.setSoundVolume("shieldLoop", transformRatio)

  local orbitRate = lerp(transformRatio, self.orbitRate, self.orbitRateShielded) * dt
  self.orbitRotation = (self.orbitRotation + orbitRate) % (math.pi * 2)

  local orbitDistance = lerp(transformRatio, self.orbitDistance, self.orbitDistanceShielded)
  local rotationRate = lerp(transformRatio, self.orbRotationRate, self.orbRotationRateShielded) * dt

  animator.resetTransformationGroup("orbs")
  animator.rotateTransformationGroup("orbs", -self.armAngle or 0)
  
  for i = 1, self.orbCount do
    self.orbRotations[i] = (self.orbRotations[i] + rotationRate) % (math.pi * 2)

    local name = "orb"..i
    animator.resetTransformationGroup(name)
    animator.rotateTransformationGroup(name, self.orbRotations[i] - self.orbitRotation)
    animator.translateTransformationGroup(name, {orbitDistance, 0})
    animator.rotateTransformationGroup(name, math.pi * 2 * (i / self.orbCount) + self.orbitRotation)

    animator.setAnimationState(name, storage.projectileIds[i] == false and "orb" or "hidden")
    animator.setParticleEmitterActive(name, storage.projectileIds[i] == false)
  end

  updateAim()

  activeItem.setScriptedAnimationParameter("projectileIds", storage.projectileIds)

  self.lastFireMode = fireMode
end

function uninit()
  activeItem.setItemShieldPolys()
  activeItem.setItemDamageSources()
  status.clearPersistentEffects("magnorbShield")

  sendMessageToOrbs("setTargetPosition", nil)
end

function nextOrb()
  local i = storage.lastOrb
  for _ = 1, self.orbCount do
    i = i + 1
    if i > self.orbCount then i = 1 end
    if not storage.projectileIds[i] then return i end
  end
end

function availableOrbCount()
  local available = 0
  for i = 1, self.orbCount do
    if not storage.projectileIds[i] then
      available = available + 1
    end
  end
  return available
end

function sendMessageToOrbs(message, ...)
  for i, projectileId in ipairs(storage.projectileIds) do
    if projectileId then
      world.sendEntityMessage(projectileId, message, ...)
		end
  end
end

function fire(orbIndex)
  local firePos = firePosition(orbIndex)
  local collision = world.lineCollision(mcontroller.position(), firePos)
  if collision then firePos = collision end
	
	local projectile = self.projectiles[orbIndex]
  local params = sb.jsonMerge(self.projectileParameters, projectile.parameters or {})
  params.powerMultiplier = activeItem.ownerPowerMultiplier() * self.damageLevelMultiplier
	
  local projectileId = world.spawnProjectile(
		projectile.type,
		firePos,
		activeItem.ownerEntityId(),
		aimVector(firePos),
		false,
		params
	)
	
  if projectileId then
    storage.projectileIds[orbIndex] = projectileId
    animator.playSound("fire")
  end
end

function firePosition(orbIndex)
  return vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("orb"..orbIndex, "orbPosition")))
end

function aimVector(firePos)
  return vec2.norm(world.distance(activeItem.ownerAimPosition(), firePos))
end

function checkProjectiles(noSound)
  for i, projectileId in ipairs(storage.projectileIds) do
    if projectileId then
      if not world.entityExists(projectileId) then
        if not noSound then
          animator.playSound("return")
        end
        storage.projectileIds[i] = false
      else
        world.sendEntityMessage(projectileId, "setTargetPosition", firePosition(i))
      end
		end
  end
end

function activateShield()
  self.shieldActive = true
  animator.resetTransformationGroup("orbs")
  animator.playSound("shieldOn")
  setStance("shield")
  activeItem.setItemShieldPolys({self.shieldPoly})
  activeItem.setItemDamageSources({self.knockbackDamageSource})
  status.setPersistentEffects("magnorbShield", {{stat = "shieldHealth", amount = self.shieldHealth}})

  self.listener = damageListener("damageTaken", damageTaken)
end

function damageTaken(notifications)
  for _, notification in pairs(notifications) do
    if notification.hitType == "ShieldHit" then
      if status.resourcePositive("shieldStamina") then
        animator.playSound("shieldBlock")
      else
        animator.playSound("shieldBreak")
      end
      return
    end
  end
end

function deactivateShield()
  self.shieldActive = false
  animator.playSound("shieldOff")
  setStance("idle")
  activeItem.setItemShieldPolys()
  activeItem.setItemDamageSources()
  status.clearPersistentEffects("magnorbShield")
end

function setOrbAnimationState(newState)
  for i = 1, self.orbCount do
    animator.setAnimationState("orb"..i, newState)
  end
end

function lerp(ratio, a, b)
  if type(a) == "table" then
    a, b = a[1], a[2]
  end

  if ratio <= 0 then
    return a
  elseif ratio >= 1 then
    return b
  end

  return a + (b - a) * ratio
end

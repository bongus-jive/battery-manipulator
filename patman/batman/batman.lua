require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/activeitem/stances.lua"

function init()
  activeItem.setCursor("/cursors/reticle0.cursor")

  self.projectiles = config.getParameter("projectiles")
  self.projectileParameters = config.getParameter("projectileParameters", {})
  self.cooldownTime = config.getParameter("cooldownTime", 0)
  self.cooldownTimer = self.cooldownTime

  self.damageLevelMultiplier = root.evalFunction("weaponDamageLevelMultiplier", config.getParameter("level", 1))

  initStances()

  storage.projectileIds = storage.projectileIds or {false, false, false}
  checkProjectiles()

  self.orbitRate = config.getParameter("orbitRate", 1) * -2 * math.pi
  self.lastOrb = 0

  animator.resetTransformationGroup("orbs")
  for i = 1, 3 do
    animator.setAnimationState("orb"..i, storage.projectileIds[i] == false and "orb" or "hidden")
  end
  setOrbPosition(1)

  self.shieldActive = false
  self.shieldTransformTimer = 0
  self.shieldTransformTime = config.getParameter("shieldTransformTime", 0.1)
  self.shieldEnergyCost = config.getParameter("shieldEnergyCost", 50)
  self.shieldHealth = config.getParameter("shieldHealth", 100)
  self.shieldPoly = animator.partPoly("glove", "shieldPoly")
  
  local shieldKnockback = config.getParameter("shieldKnockback", 0)
  if shieldKnockback > 0 then
    self.knockbackDamageSource = {
      poly = self.shieldPoly,
      damage = 0,
      damageType = "Knockback",
      sourceEntity = activeItem.ownerEntityId(),
      team = activeItem.ownerTeam(),
      knockback = shieldKnockback,
      rayCheck = true,
      damageRepeatTimeout = 0.5
    }
  end

  setStance("idle")

  animator.stopAllSounds("shieldLoop")
  animator.setSoundVolume("shieldLoop", 0)
  animator.playSound("shieldLoop", -1)
end

function update(dt, fireMode, shiftHeld)
  self.cooldownTimer = math.max(0, self.cooldownTimer)

  updateStance(dt)
  checkProjectiles()

  if fireMode == "alt" and availableOrbCount() == 3 and not status.resourceLocked("energy") and status.resourcePositive("shieldStamina") then
    if not self.shieldActive then
      activateShield()
    end
    setOrbAnimationState("orb")
    self.shieldTransformTimer = math.min(self.shieldTransformTime, self.shieldTransformTimer + dt)
  else
    if self.shieldTransformTimer > 0 and self.shieldTransformTimer < dt then
      setOrbPosition(1)
    end

    self.shieldTransformTimer = math.max(0, self.shieldTransformTimer - dt)
  end

  if self.shieldTransformTimer == 0 and fireMode == "primary" and self.lastFireMode ~= "primary" and self.cooldownTimer == 0 then
    local nextOrbIndex = nextOrb()
    if nextOrbIndex then
      fire(nextOrbIndex)
    end
  end
  self.lastFireMode = fireMode

  if self.shieldActive then
    if not status.resourcePositive("shieldStamina") or not status.overConsumeResource("energy", self.shieldEnergyCost * dt) then
      deactivateShield()
    else
      self.listener:update()
    end
  end

  local transformRatio = self.shieldTransformTimer / self.shieldTransformTime
  animator.setSoundVolume("shieldLoop", transformRatio)

  if self.shieldTransformTimer > 0 then
    local transformRatio = self.shieldTransformTimer / self.shieldTransformTime
    setOrbPosition(1 - transformRatio * 0.7, transformRatio * 0.75)
    animator.resetTransformationGroup("orbs")
    animator.translateTransformationGroup("orbs", {transformRatio * -1.5, 0})
  else
    if self.shieldActive then
      deactivateShield()
    end

    animator.resetTransformationGroup("orbs")
    animator.rotateTransformationGroup("orbs", -self.armAngle or 0)
    for i = 1, 3 do
      animator.rotateTransformationGroup("orb"..i, self.orbitRate * dt)
      animator.setAnimationState("orb"..i, storage.projectileIds[i] == false and "orb" or "hidden")
    end
  end

  updateAim()
end

function uninit()
  activeItem.setItemShieldPolys()
  activeItem.setItemDamageSources()
  status.clearPersistentEffects("magnorbShield")
  
  for i, projectileId in ipairs(storage.projectileIds) do
    if projectileId then
      world.sendEntityMessage(projectileId, "setTargetPosition", nil)
		end
  end
end

function nextOrb()
  for _ = 1, 3 do
    self.lastOrb = (self.lastOrb + 1) % 3
    local i = self.lastOrb + 1
    if not storage.projectileIds[i] then return i end
  end
end

function availableOrbCount()
  local available = 0
  for i = 1, 3 do
    if not storage.projectileIds[i] then
      available = available + 1
    end
  end
  return available
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
    self.cooldownTimer = self.cooldownTime
    animator.playSound("fire")
  end
end

function firePosition(orbIndex)
  return vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("orb"..orbIndex, "orbPosition")))
end

function aimVector(firePos)
  return vec2.norm(world.distance(activeItem.ownerAimPosition(), firePos))
end

function checkProjectiles()
  for i, projectileId in ipairs(storage.projectileIds) do
    if projectileId then
      if not world.entityExists(projectileId) then
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

function setOrbPosition(spaceFactor, distance)
  for i = 1, 3 do
    animator.resetTransformationGroup("orb"..i)
    animator.translateTransformationGroup("orb"..i, {distance or 0, 0})
    animator.rotateTransformationGroup("orb"..i, 2 * math.pi * spaceFactor * ((i - 2) / 3))
  end
end

function setOrbAnimationState(newState)
  for i = 1, 3 do
    animator.setAnimationState("orb"..i, newState)
  end
end

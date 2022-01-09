require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/activeitem/stances.lua"

function init()
  activeItem.setCursor("/cursors/reticle0.cursor")

  projectiles = config.getParameter("projectiles")
  projectileParameters = config.getParameter("projectileParameters", {})
  cooldownTime = config.getParameter("cooldownTime", 0)
  cooldownTimer = cooldownTime

  initStances()

  storage.projectileIds = storage.projectileIds or {false, false, false}
  checkProjectiles()

  orbitRate = config.getParameter("orbitRate", 1) * -2 * math.pi

  animator.resetTransformationGroup("orbs")
  for i = 1, 3 do
    animator.setAnimationState("orb"..i, storage.projectileIds[i] == false and "orb" or "hidden")
  end
  setOrbPosition(1)

  shieldActive = false
  shieldTransformTimer = 0
  shieldTransformTime = config.getParameter("shieldTransformTime", 0.1)
  shieldPoly = animator.partPoly("glove", "shieldPoly")
  shieldEnergyCost = config.getParameter("shieldEnergyCost", 50)
  shieldHealth = 10000
  shieldKnockback = config.getParameter("shieldKnockback", 0)
  if shieldKnockback > 0 then
    knockbackDamageSource = {
      poly = shieldPoly,
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

  updateHand()
end

function update(dt, fireMode, shiftHeld)
  cooldownTimer = math.max(0, cooldownTimer)

  updateStance(dt)
  checkProjectiles()

  if fireMode == "alt" and availableOrbCount() == 3 and not status.resourceLocked("energy") and status.resourcePositive("shieldStamina") then
    if not shieldActive then
      activateShield()
    end
    setOrbAnimationState("shield")
    shieldTransformTimer = math.min(shieldTransformTime, shieldTransformTimer + dt)
  else
    if shieldTransformTimer > 0 and shieldTransformTimer < dt then
      setOrbPosition(1)
    end

    shieldTransformTimer = math.max(0, shieldTransformTimer - dt)
    if shieldTransformTimer > 0 then
      setOrbAnimationState("unshield")
    end
  end

  if shieldTransformTimer == 0 and fireMode == "primary" and lastFireMode ~= "primary" and cooldownTimer == 0 then
    local nextOrbIndex = nextOrb()
    if nextOrbIndex then
      fire(nextOrbIndex)
    end
  end
  lastFireMode = fireMode

  if shieldActive then
    if not status.resourcePositive("shieldStamina") or not status.overConsumeResource("energy", shieldEnergyCost * dt) then
      deactivateShield()
    else
      damageListener:update()
    end
  end

  if shieldTransformTimer > 0 then
    local transformRatio = shieldTransformTimer / shieldTransformTime
    setOrbPosition(1 - transformRatio * 0.7, transformRatio * 0.75)
    animator.resetTransformationGroup("orbs")
    animator.translateTransformationGroup("orbs", {transformRatio * -1.5, 0})
  else
    if shieldActive then
      deactivateShield()
    end

    animator.resetTransformationGroup("orbs")
    animator.rotateTransformationGroup("orbs", -self.armAngle or 0)
    for i = 1, 3 do
      animator.rotateTransformationGroup("orb"..i, orbitRate * dt)
      animator.setAnimationState("orb"..i, storage.projectileIds[i] == false and "orb" or "hidden")
    end
  end

  updateAim()
  updateHand()
end

function uninit()
  activeItem.setItemShieldPolys()
  activeItem.setItemDamageSources()
  status.clearPersistentEffects("magnorbShield")
  animator.stopAllSounds("shieldLoop")
end

function nextOrb()
  for i = 1, 3 do
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

function updateHand()
  local isFrontHand = (activeItem.hand() == "primary") == (mcontroller.facingDirection() < 0)
  animator.setGlobalTag("hand", isFrontHand and "front" or "back")
  activeItem.setOutsideOfHand(isFrontHand)
end

function fire(orbIndex)
  local firePos = firePosition(orbIndex)
  if world.lineCollision(mcontroller.position(), firePos) then return end
	
	local projectile = projectiles[orbIndex]
  local params = sb.jsonMerge(projectileParameters, projectile.parameters or {})
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
	
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
    cooldownTimer = cooldownTime
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
    if projectileId and not world.entityExists(projectileId) then
      storage.projectileIds[i] = false
    end
  end
end

function activateShield()
  shieldActive = true
  animator.resetTransformationGroup("orbs")
  animator.playSound("shieldOn")
  animator.playSound("shieldLoop", -1)
  setStance("shield")
  activeItem.setItemShieldPolys({shieldPoly})
  activeItem.setItemDamageSources({knockbackDamageSource})
  status.setPersistentEffects("magnorbShield", {{stat = "shieldHealth", amount = shieldHealth}})
  damageListener = damageListener("damageTaken", function(notifications)
    for _,notification in pairs(notifications) do
      if notification.hitType == "ShieldHit" then
        if status.resourcePositive("shieldStamina") then
          animator.playSound("shieldBlock")
        else
          animator.playSound("shieldBreak")
        end
        return
      end
    end
  end)
end

function deactivateShield()
  shieldActive = false
  animator.playSound("shieldOff")
  animator.stopAllSounds("shieldLoop")
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

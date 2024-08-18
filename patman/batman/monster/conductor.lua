require "/scripts/util.lua"

function init()
  self.ownerId = config.getParameter("ownerId")
  if not self.ownerId then
    return destroy()
  end

  for k, v in pairs(config.getParameter("scriptedAnimationParameters", {})) do
    monster.setAnimationParameter(k, v)
  end
  self.newLines = {}
  self.lineId = 0

  self.position = entity.position()
  self.id = entity.id()

  self.stepCount = config.getParameter("stepCount", 1)
  self.stepDelay = config.getParameter("stepDelay", 0)
  self.stepTimer = 0

  self.excludeOwner = config.getParameter("excludeOwner", false)
  self.checkOwnerCanDamage = config.getParameter("checkOwnerCanDamage", false)

  self.projectile = config.getParameter("projectile")
  if self.projectile then
    self.projectile.parameters = initProjectileParams(self.projectile.parameters)
    spawnProjectile(self.position)
  end

  self.queryRadius = config.getParameter("queryRadius", 32)
  self.queryOptions = config.getParameter("queryOptions", {})
  self.queryOptions.withoutEntityId = self.id
  local targets = findTargets(self.queryRadius, self.queryOptions, checkTarget)

  self.conductStep = coroutine.wrap(function()
    co_conductTargets(targets, util.randomIntInRange(self.stepCount))
    finishConduct()
    self.conductStep = nil
  end)
end

function update(dt)
  if self.despawnTimer then
    self.despawnTimer = self.despawnTimer - dt
    if self.despawnTimer <= 0 then
      return destroy()
    end
  end

  monster.setAnimationParameter("newLines", self.newLines)
  if #self.newLines > 0 then
    self.newLines = {}
  end

  if not self.conductStep then
    return
  end

  self.stepTimer = math.max(self.stepTimer - dt, 0)
  if self.stepTimer == 0 then
    self.stepTimer = util.randomInRange(self.stepDelay)
    local stepCount = util.randomIntInRange(self.stepCount)
    self.conductStep(stepCount)
  end
end

function co_conductTargets(targets, stepCount)
  local conductedPositions = {}
  
  for i, target in ipairs(targets) do
    local result = conductTarget(target, conductedPositions)
    if result then
      stepCount = stepCount - 1
      if stepCount <= 0 then
        stepCount = coroutine.yield()
      end
    end
  end
end

function conductTarget(target, conductedPositions)
  local targetPosition = world.entityPosition(target.id)
  if not targetPosition then
    return false
  end

  local startPosition = self.position
  local distanceFromCenter = world.magnitude(startPosition, targetPosition)
  local lowestDistance = copy(distanceFromCenter)

  for _, chainPosition in pairs(conductedPositions) do
    local distance = world.magnitude(chainPosition, targetPosition)
    if distance < lowestDistance and checkLiquidLine(chainPosition, targetPosition) then
      lowestDistance = distance
      startPosition = chainPosition
    end
  end

  world.debugLine(startPosition, targetPosition, "#F0F")
  if self.projectile then
    spawnProjectile(targetPosition)
  end

  local lineEndPosition = world.nearestTo(startPosition, targetPosition)
  createNewLine(startPosition, lineEndPosition)

  conductedPositions[target.id] = targetPosition
  return true
end

function findTargets(radius, options, filter)
  local entities = world.entityQuery(self.position, radius, options)
  local targets = {}

  for _, entityId in ipairs(entities) do
    local entityPosition = world.entityPosition(entityId)

    local valid = true
    if filter then
      valid = filter(entityId, entityPosition)
    end

    world.debugLine(self.position, entityPosition, valid and "#0F0" or "#F00")
    if valid then
      targets[#targets + 1] = {
        id = entityId,
        initialPosition = entityPosition
      }
    end
  end

  return targets
end

function checkTarget(entityId, entityPosition)
  if self.excludeOwner and entityId == self.ownerId then
    return false
  end

  if self.checkOwnerCanDamage and self.ownerId and not world.entityCanDamage(self.ownerId, entityId) then
    return false
  end

  local health = world.entityHealth(entityId)
  if health and health[1] == 0 then
    return false
  end

  entityPosition = entityPosition or world.entityPosition(entityId)
  if not world.liquidAt(entityPosition)
  or not checkLiquidLine(self.position, entityPosition) then
    return false
  end

  return true
end

function checkLiquidLine(startPos, endPos)
  if world.lineTileCollision(startPos, endPos) then
    return false
  end

  local liquids = world.liquidAlongLine(startPos, endPos)

  if #liquids == 0
  or world.magnitude(startPos, liquids[1][1]) > 2
  or world.magnitude(endPos, liquids[#liquids][1]) > 2 then
    return false
  end

  local lastLiquidId, lastPosition

  for i, v in ipairs(liquids) do
    local position, liquidId, liquidAmount = v[1], v[2][1], v[2][2]

    if i > 1 then
      if liquidId ~= lastLiquidId then
        return false
      end

      local mag = world.magnitude(lastPosition, position)
      if mag > 2 then
        return false
      end
    end
    
    lastLiquidId, lastPosition = liquidId, position
  end

  return true
end

function finishConduct()
  self.despawnTimer = config.getParameter("despawnDelay", 0)
end

function initProjectileParams(params)
  params = params or {}
  params.power = params.power or config.getParameter("power")
  params.powerMultiplier = config.getParameter("powerMultiplier")
  params.damageRepeatGroup = string.format("%s:%s:%s:%s", monster.type(), self.id, self.ownerId, world.time())
  return params
end

function spawnProjectile(position, params)
  if params then
    params = sb.jsonMerge(self.projectile.parameters, params or {})
  end
  world.spawnProjectile(self.projectile.type, position, self.id, randomVector(), nil, params or self.projectile.parameters)
end

function randomVector()
  local angle = math.random() * math.pi * 2
  return {math.cos(angle), math.sin(angle)}
end

function createNewLine(a, b)
  local newLine = {
    startPoint = a,
    endPoint = b,
    id = self.lineId
  }
  self.lineId = self.lineId + 1
  self.newLines[#self.newLines + 1] = newLine
  return newLine
end

function shouldDie()
  return false
end

function destroy()
  script.setUpdateDelta(0)
  _ENV.shouldDie = function()
    return true
  end
end

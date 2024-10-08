require "/scripts/vec2.lua"

local oldUpdate = update or function()
  localAnimator.clearDrawables()
  localAnimator.clearLightSources()
end

function init()
  self.trails = {}

  local defaults = {
    segments = 10,
    width = 0.5,
    color = {255, 255, 255, 255},
    shrink = true,
    fade = true,
    layer = "projectile-100"
  }

  self.trailConfig = sb.jsonMerge(defaults, animationConfig.animationParameter("trailConfig") or {})
  self.trailConfig.maxAlpha = self.trailConfig.color[4] or 255
end

function update(dt)
  oldUpdate(dt)

  local projectileIds = animationConfig.animationParameter("projectileIds") or {}
  for i, id in ipairs(projectileIds) do
    if not self.trails[i] then
      self.trails[i] = {}
    end

    local pos
    if id then
      pos = world.entityPosition(id)
    elseif id == false then
      local partPos = animationConfig.partPoint("orb"..i, "orbPosition")
      local handPos = activeItemAnimation.handPosition(partPos)
      pos = vec2.add(handPos, activeItemAnimation.ownerPosition())
    end
    trail(pos, self.trails[i])
  end
end

function trail(entityPos, points)
  if not entityPos or not points then return end

  local newPoint = {position = entityPos}
  if points[1] then
    local distance = world.distance(newPoint.position, points[1].position)
    newPoint.widthVec = vec2.rotate(vec2.norm(distance), math.pi / 2)
  end

  table.insert(points, 1, newPoint)
  points[self.trailConfig.segments + 1] = nil

  local lastPoint
  
  for i, point in ipairs(points) do
    local isFinalPoint = i == #points
    local segmentMult = 1 - (i / #points)
    local relativePos = world.distance(point.position, entityPos)

    if not isFinalPoint then
      local width = self.trailConfig.width
      if self.trailConfig.shrink then
        width = width * segmentMult
      end

      point.widthPosA = vec2.add(relativePos, vec2.mul(point.widthVec, width))
      point.widthPosB = vec2.add(relativePos, vec2.mul(point.widthVec, -width))
    end

    if lastPoint then
      local poly = {lastPoint.widthPosA, lastPoint.widthPosB}

      if isFinalPoint then
        poly[3] = relativePos
      else
        poly[3], poly[4] = point.widthPosB, point.widthPosA
      end

      if self.trailConfig.fade then
        self.trailConfig.color[4] = self.trailConfig.maxAlpha * segmentMult
      end

      localAnimator.addDrawable({position = entityPos, poly = poly, color = self.trailConfig.color}, self.trailConfig.layer)
      if self.trailConfig.outineWidth then
        local drawable = {position = entityPos, color = self.trailConfig.color, width = self.trailConfig.outineWidth}
        drawable.line = {poly[1], poly[4] or poly[3]}
        localAnimator.addDrawable(drawable, self.trailConfig.layer)
        drawable.line = {poly[2], poly[3]}
        localAnimator.addDrawable(drawable, self.trailConfig.layer)
      end
    end

    lastPoint = point
  end
end

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

    if id then
      trail(world.entityPosition(id), self.trails[i])
    elseif id == false then
      local pos = animationConfig.partPoint("orb"..i, "orbPosition")
      pos = activeItemAnimation.handPosition(pos)
      pos = vec2.add(pos, activeItemAnimation.ownerPosition())
      trail(pos, self.trails[i])
    end
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

    if i > 1 then
      lastPoint = points[i - 1]
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
    end
  end
end

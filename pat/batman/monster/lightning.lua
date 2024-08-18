local function randomInRange(range)
  return -range + math.random() * 2 * range
end

local function randomOffset(range)
  return {randomInRange(range), randomInRange(range)}
end

function createLightning(lineList, startPoint, endPoint, displacement, splitDistance)
  if splitDistance > world.magnitude(startPoint, endPoint) then
    local newLine = {
      distance = world.distance(endPoint, startPoint),
      startPoint = startPoint,
      endPoint = endPoint
    }
		table.insert(lineList, newLine)
    return
  end

  local midPoint = {(startPoint[1] + endPoint[1]) / 2, (startPoint[2] + endPoint[2]) / 2}
  midPoint = vec2.add(midPoint, randomOffset(displacement))
  
  createLightning(lineList, startPoint, midPoint, displacement, splitDistance)
  createLightning(lineList, midPoint, endPoint, displacement, splitDistance)
end

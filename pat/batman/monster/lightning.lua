Lightning = {}

function Lightning:init(params)
  self.bolts = {}

  self.duration = params.duration or 1
  self.boltCount = params.boltCount or 1
  self.displacement =  params.displacement or 2
  self.splitDistance = params.splitDistance or 4
end

function Lightning:update(dt)
  if #self.bolts == 0 then
    return
  end

  local t = dt / self.duration
  local newBolts = {}

  for _, bolt in pairs(self.bolts) do
    bolt.scale = bolt.scale - t
    if bolt.scale > 0 then
      newBolts[#newBolts + 1] = bolt
    end
  end
  
  self.bolts = newBolts
end

function Lightning:createBolt(startPoint, endPoint)
  local bolt = { lines = {}, scale = 1 }

  for i = 1, self.boltCount do
    self:createLines(bolt.lines, startPoint, endPoint)
  end

  self.bolts[#self.bolts + 1] = bolt
  return bolt
end

local function randomInRadius(center, radius)
  local r = radius * math.sqrt(math.random())
  local t = math.random() * 2 * math.pi
  return {
    center[1] + r * math.cos(t),
    center[2] + r * math.sin(t)
  }
end

function Lightning:createLines(lines, startPoint, endPoint)
  if self.splitDistance > world.magnitude(startPoint, endPoint) then
    local newLine = {
      startPoint = startPoint,
      endPoint = endPoint,
      relativeEndPoint = world.distance(endPoint, startPoint)
    }
    lines[#lines + 1] = newLine
    return
  end

  local midPoint = {(startPoint[1] + endPoint[1]) / 2, (startPoint[2] + endPoint[2]) / 2}
  midPoint = randomInRadius(midPoint, self.displacement)
  
  self:createLines(lines, startPoint, midPoint)
  self:createLines(lines, midPoint, endPoint)
end

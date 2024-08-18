require "/scripts/vec2.lua"
require "/patman/batman/monster/lightning.lua"

local function getParameter(key, default)
  local value = animationConfig.animationParameter(key)
  if value == nil then value = default end
  return value
end

function init()
  script.setUpdateDelta(getParameter("scriptDelta", 1))

  self.bolts = {}
  self.boltIds = {}
  self.duration = getParameter("duration", 1)
  self.boltCount = getParameter("boltCount", 1)
  self.displacement = getParameter("displacement", 2)
  self.splitDistance =  getParameter("splitDistance", 4)
  self.layers = getParameter("layers", {})
end

function update()
  local dt = script.updateDt()
  localAnimator.clearDrawables()

  local newLines = getParameter("newLines")
  if newLines and #newLines > 0 then
    for _, newLine in pairs(newLines) do
      createBolt(newLine)
    end
  end

  if #self.bolts == 0 then
    return
  end

  local oldBolts = self.bolts
  self.bolts = {}
  for _, bolt in pairs(oldBolts) do
    bolt:update(dt)
  end
end

function updateBolt(bolt, dt)
  bolt.time = math.max(0, bolt.time - dt)
  if bolt.time == 0 then
    return
  end

  self.bolts[#self.bolts + 1] = bolt
  bolt:draw()
end

function drawBolt(bolt)
  local lines = bolt.lines
  local fade = bolt.time / self.duration
  
  for _, layer in ipairs(self.layers) do
    if layer.fade ~= false then
      layer.color[4] = (layer.alpha or 255) * fade
    end

    local width = layer.width
    if layer.shrink ~= false then
      width = width * fade
    end

    local drawable = {
      line = {{0, 0}, nil},
      width = width,
      color = layer.color,
      fullbright = layer.fullbright ~= false
    }

    for _, line in ipairs(bolt.lines) do
      drawable.position = line.startPoint
      drawable.line[2] = line.distance
      localAnimator.addDrawable(drawable, layer.renderLayer)
    end
  end
end

function createBolt(line)
  if self.boltIds[line.id] then
    return
  end
  
  local newBolt = {
    lines = {},
    time = self.duration,
    id = line.id,
    update = updateBolt,
    draw = drawBolt
  }
  
  self.boltIds[line.id] = newBolt
  self.bolts[#self.bolts + 1] = newBolt

  for _ = 1, self.boltCount do
    createLightning(newBolt.lines, line.startPoint, line.endPoint, self.displacement, self.splitDistance)
  end

  return newBolt
end
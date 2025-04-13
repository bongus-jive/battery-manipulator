local function getParameter(key, default)
  local value = animationConfig.animationParameter(key)
  if value == nil then value = default end
  return value
end

function init()
  script.setUpdateDelta(getParameter("scriptDelta", 1))

  self.layers = getParameter("layers", {})
end

function update()
  localAnimator.clearDrawables()

  local bolts = getParameter("lightningBolts")
  if not bolts or #bolts == 0 then
    return
  end

  for _, bolt in pairs(bolts) do
    drawBolt(bolt)
  end
end

function drawBolt(bolt)
  for _, layer in ipairs(self.layers) do
    if layer.fade ~= false then
      layer.color[4] = (layer.alpha or 255) * bolt.scale
    end

    local width = layer.width
    if layer.shrink ~= false then
      width = width * bolt.scale
    end

    local drawable = {
      line = {{0, 0}, nil},
      width = width,
      color = layer.color,
      fullbright = layer.fullbright ~= false
    }

    for _, line in ipairs(bolt.lines) do
      drawable.position = line.startPoint
      drawable.line[2] = line.relativeEndPoint
      localAnimator.addDrawable(drawable, layer.renderLayer)
    end
  end
end

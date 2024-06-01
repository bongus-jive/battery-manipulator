function init()
  effect.setParentDirectives(effect.getParameter("directives", ""))

  local boundBox = mcontroller.boundBox()
  for _, name in ipairs(effect.getParameter("boundBoxEmitters", {})) do
    animator.setParticleEmitterOffsetRegion(name, boundBox)
    animator.setParticleEmitterActive(name, true)
  end

  projectileType = effect.getParameter("projectileType")
  projectileParameters = effect.getParameter("projectileParameters", {})

  local msg = effect.getParameter("receiveMessage")
  if msg then
    requiredMessages = effect.getParameter("messagesRequired", 1)
    recievedMessages = 0
    message.setHandler(msg, trigger)
  end

  animator.playSound("zap")
end

function trigger(_, _, sourceId, params)
  recievedMessages = recievedMessages + 1

  animator.playSound("zap")
  
  if recievedMessages < requiredMessages then
    return
  end

  if projectileType then
    params = sb.jsonMerge(projectileParameters, params or {})
    local angle = math.random() * math.pi * 2
    local direction = {math.cos(angle), math.sin(angle)}
    world.spawnProjectile(projectileType, mcontroller.position(), sourceId, direction, false, params)
  end

  effect.expire()
end

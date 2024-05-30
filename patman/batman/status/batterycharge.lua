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
    message.setHandler(msg, trigger)
  end
end

function trigger(_, _, sourceId, params)
  if projectileType then
    params = sb.jsonMerge(projectileParameters, params or {})
    local angle = math.random() * math.pi * 2
    local direction = {math.cos(angle), math.sin(angle)}
    world.spawnProjectile(projectileType, mcontroller.position(), sourceId, direction, false, params)
  end

  effect.expire()
end

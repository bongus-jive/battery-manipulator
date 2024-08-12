require "/scripts/messageutil.lua"

function init()
  effect.setParentDirectives(effect.getParameter("directives", ""))

  local boundBox = mcontroller.boundBox()
  for _, name in ipairs(effect.getParameter("boundBoxEmitters", {})) do
    animator.setParticleEmitterOffsetRegion(name, boundBox)
    animator.setParticleEmitterActive(name, true)
  end

  self.projectileType = effect.getParameter("projectileType")
  self.projectileParameters = effect.getParameter("projectileParameters", {})

  local msg = effect.getParameter("receiveMessage")
  if msg then
    self.requiredMessages = effect.getParameter("messagesRequired", 1)
    self.recievedMessages = 0
    message.setHandler(msg, simpleHandler(trigger))
  end

  animator.playSound("zap")
end


function trigger(sourceId, params)
  animator.playSound("zap")
  
  if self.recievedMessages < self.requiredMessages then
    return
  end

  if self.projectileType then
    params = sb.jsonMerge(self.projectileParameters, params or {})
    local angle = math.random() * math.pi * 2
    local direction = {math.cos(angle), math.sin(angle)}
    world.spawnProjectile(self.projectileType, mcontroller.position(), sourceId, direction, false, params)
  end

  effect.expire()
end

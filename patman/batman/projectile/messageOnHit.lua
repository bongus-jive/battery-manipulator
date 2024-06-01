local oldHit = hit
local msg

function hit(id)
  if oldHit then oldHit(id) end

  msg = msg or config.getParameter("messageOnHit")
  if not msg then return end
  world.sendEntityMessage(id, msg, projectile.sourceEntity(), {powerMultiplier = projectile.powerMultiplier()})
end

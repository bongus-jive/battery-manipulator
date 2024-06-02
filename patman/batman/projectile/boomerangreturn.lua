local oldInit = init

function init()
  oldInit()
  message.setHandler("return", function(_, _, controlForce, pickupDistance)
    self.returning = true
    self.controlForce = controlForce or self.controlForce
    self.pickupDistance = pickupDistance or self.pickupDistance
    mcontroller.applyParameters({collisionEnabled = false})
  end)
end

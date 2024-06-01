local oldInit = init

function init()
  oldInit()
  message.setHandler("return", function(_, _, controlForce)
    self.returning = true
    self.controlForce = controlForce or self.controlForce
    mcontroller.applyParameters({collisionEnabled = false})
  end)
end

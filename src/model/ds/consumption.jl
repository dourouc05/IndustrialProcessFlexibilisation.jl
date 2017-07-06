consumption(eq::EquipmentModel, p::Product, d::DateTime) = consumption(eq, p, consumption(p, equipment(eq)), d) # TODO: To test!

# These functions are just for overloading over the third parameter, and get dispatch on it.
consumption(eq::EquipmentModel, p::Product, c::NoConsumption, d::DateTime) = 0.0 # TODO: To test!
consumption(eq::EquipmentModel, p::Product, c::ConstantConsumption, d::DateTime) = on(eq, d) * consumption(c) # TODO: To test!
consumption(eq::EquipmentModel, p::Product, c::LinearConsumption, d::DateTime) = on(eq, d) * intercept(c) + quantity(eq, d, p) * slope(c) # TODO: To test!
consumption(eq::EquipmentModel, p::Product, c::QuadraticConsumption, d::DateTime) = on(eq, d) * intercept(c) + quantity(eq, d, p) * slope(c) + quantity(eq, d, p) ^ 2 * quadratic(c) # TODO: To test!

function consumption(eq::EquipmentModel, c::PiecewiseLinearConsumption, d::DateTime) # TODO: To test!
  error("Piecewise linear consumptions not yet implemented. ")
end
"""
Returns a JuMP expression for the consumption of the piece of equipment `eq` when it has to produce `p` at time `d`.
This expression is likely to involve optimisation variables, mostly indicating whether the process is on or the
quantity it has to process.
"""
consumption(eq::EquipmentModel, p::Product, d::DateTime) = consumption(eq, p, consumption(p, equipment(eq)), d) 

# These functions are just for overloading over the third parameter, and get dispatch on it.
consumption(eq::EquipmentModel, p::Product, c::NoConsumption, d::DateTime) = 0.0
consumption(eq::EquipmentModel, p::Product, c::ConstantConsumption, d::DateTime) = on(eq, d) * consumption(c)
consumption(eq::EquipmentModel, p::Product, c::LinearConsumption, d::DateTime) = on(eq, d) * intercept(c) + quantity(eq, d, p) * slope(c)
consumption(eq::EquipmentModel, p::Product, c::QuadraticConsumption, d::DateTime) = on(eq, d) * intercept(c) + quantity(eq, d, p) * slope(c) + quantity(eq, d, p) ^ 2 * quadratic(c)

function consumption(eq::EquipmentModel, c::PiecewiseLinearConsumption, d::DateTime)
  # TODO
  error("Piecewise linear consumptions not yet implemented. ")
end

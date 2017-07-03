"""
A electricity consumption model for a piece of equipment when producing a given product.
"""
abstract type ConsumptionModel end


struct NoConsumption <: ConsumptionModel end


"""
A constant consumption model, i.e. the machine always consumes the same quantity of electricity, whatever the quantity
it is currently producing.

For example, for a batch oven (like an EAF), this is the consumption per heat (over the whole heat).
For continuous processes (like electrolysis), this is the consumption when the machine is powered on.
"""
struct ConstantConsumption <: ConsumptionModel
  consumption::Float64
end
consumption(cc::ConstantConsumption) = cc.consumption


"""
A linear consumption model. With respect to a constant model (`ConstantConsumption`), it takes into account consumption
variability depending on the quantity the machine has to process. The relationship is forced to be linear
(it can be expressed as `consumption = intercept + slope * quantity`).

For example, for a batch oven (like an EAF), this is the consumption per heat (over the whole heat),
depending linearly on the heat size. For continuous processes (like electrolysis), this is the consumption
when the machine processes a given quantity of material.
"""
struct LinearConsumption <: ConsumptionModel
  intercept::Float64
  slope::Float64
end
intercept(lc::LinearConsumption) = lc.intercept
slope(lc::LinearConsumption) = lc.slope


"""
A quadratic consumption model. With respect to a constant model (`ConstantConsumption`), it takes into account consumption
variability depending on the quantity the machine has to process. The relationship is forced to be quadratic
(it can be expressed as `consumption = intercept + slope * quantity + quadratic * quantity ^ 2`).
The function must be convex (i.e. the consumption must increase when the machine has to process more).

For example, for a batch oven (like an EAF), this is the consumption per heat (over the whole heat),
depending linearly on the heat size. For continuous processes (like electrolysis), this is the consumption
when the machine processes a given quantity of material.
"""
struct QuadraticConsumption <: ConsumptionModel
  intercept::Float64
  slope::Float64
  quadratic::Float64

  function QuadraticConsumption(intercept::Float64, slope::Float64, quadratic::Float64)
    if quadratic < 0.0
      error("The quadratic consumption model is not convex; please use a piecewise linear approximation instead.")
    end
    new(intercept, slope, quadratic)
  end
end
intercept(qc::QuadraticConsumption) = qc.intercept
slope(qc::QuadraticConsumption) = qc.slope
quadratic(qc::QuadraticConsumption) = qc.quadratic


"""
A piecewise linear consumption model. With respect to a constant model (`ConstantConsumption`), it takes into account
consumption variability depending on the quantity the machine has to process. The relationship is forced to be
piecewise linear (it can be expressed as `consumption = intercept + slope * quantity`, where the coefficients depend
on the value of `quantity`). This allows for arbitrarily complex consumption function (not just linear or quadratic)

For example, for a batch oven (like an EAF), this is the consumption per heat (over the whole heat),
depending linearly on the heat size. For continuous processes (like electrolysis), this is the consumption
when the machine processes a given quantity of material.

More specifically, the piecewise linear relationship is stored in two arrays, listing the interpolation points.
`xs` is the list of abscissae where the function is known, `ys` the corresponding values (ordinates).
The `xs` vector is supposed to be sorted (the lowest abscissae come first).
"""
struct PiecewiseLinearConsumption <: ConsumptionModel
  xs::Array{Float64, 1}
  ys::Array{Float64, 1}

  function PiecewiseLinearConsumption(xs::Array{Float64, 1}, ys::Array{Float64, 1})
    if ! issorted(xs)
      error("The given abscissae are not sorted in increasing order.")
    end
    new(xs, ys)
  end
end
xs(plc::PiecewiseLinearConsumption) = plc.xs
ys(plc::PiecewiseLinearConsumption) = plc.ys

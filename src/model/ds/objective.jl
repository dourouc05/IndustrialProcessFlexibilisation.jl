"""
An objective function for the production model. As per its interface, it can define two functions:

  - `objectiveTimeStep(m::Model, o::ProductionObjective, pm::PlantModel, d::DateTime)`: the cost for the time step `d`
    (`d` indicates the beginning of the time step).
  - `objectiveShift(m::Model, o::ProductionObjective, pm::PlantModel, d::DateTime)`: the cost for the time step `d`
    (`d` indicates the beginning of the shift).

By default, these functions return a zero value. Otherwise, they must return a JuMP expression (either linear or
quadratic, i.e. a `JuMP.AffExpr` object or anything that JuMP allows as such --- this name is a bit misleading,
as quadratic functions are allowed within an `AffExpr`). To have a sensical objective function, at least one of them
must be implemented.

The function `objective(m::Model, o::ProductionObjective, pm::PlantModel)` computes the whole objective function,
summed over all the time steps and the shifts. It is not meant for customisation by subtypes.

Note: objectives are always minimised (use a sign to maximise).
"""
abstract type ProductionObjective end

"""
Evaluates the corresponding objective function `o` for the time step starting at `d`.

The implementation of this function must be thought about for each new objective function. Its default implementation
has a zero cost, which means that implementing it is not mandatory. See the documentation of `ProductionObjective`.
"""
objectiveTimeStep(m::Model, o::ProductionObjective, pm::PlantModel, d::DateTime) = AffExpr()

"""
Evaluates the corresponding objective function `o` for the shift starting at `d`.

The implementation of this function must be thought about for each new objective function. Its default implementation
has a zero cost, which means that implementing it is not mandatory. See the documentation of `ProductionObjective`.
"""
objectiveShift(m::Model, o::ProductionObjective, pm::PlantModel, d::DateTime) = AffExpr()

"""
Integrates the objective function over the whole optimisation horizon, both for the time steps (`objectiveTimeStep`)
and the shifts (`objectiveShift`).
"""
function objective(m::Model, o::ProductionObjective, pm::PlantModel)
  expr = AffExpr()

  # Sum over the time steps.
  for d in eachTimeStep(pm)
    expr += objectiveTimeStep(m, o, pm, d)
  end

  # Sum over the shifts.
  d = timeBeginning(pm)
  # for d in eachShift(pm) # TODO: implement the eachShift helper.
  while d <= timeEnding(pm)
    expr += objectiveShift(m, o, pm, d)
    d += shiftDuration(pm)
  end

  # Done!
  return expr
end

"""
Integrates the objective function over a time span from `from` (inclusive) to `to` (exclusive).
"""
function objective(m::Model, o::ProductionObjective, pm::PlantModel, from::DateTime, to::DateTime)
  expr = AffExpr()

  # Sum over the time steps.
  d = from
  while d < to
    expr += objectiveTimeStep(m, o, pm, d)
    d += timeStepDuration(pm)
  end

  # Sum over the shifts.
  d = from
  while d < to
    expr += objectiveShift(m, o, pm, d)
    d += shiftDuration(pm)
  end

  # Done!
  return expr
end



"""
A linear combination of multiple objective functions. This is a simple way of implementing multiobjective optimisation.

Each objective has a given weight; the corresponding complete objective function is:

    \sum_{i} weight_i f_i

The higher the weight, the more the objective function is important for the optimisation. Negative weights are allowed.
The sum of the weights does *not* have to sum up to one.

Each objective can be assigned a symbol with the `symbols` keyword argument. If no symbols are provided, then
this constructor provides default values: the objectives are given increasing numbers. The first one corresponds
to `Symbol(1)`, the second one to `Symbol(2)`, etc. If symbols are provided, no two objectives can have the same symbol.

Looking up objectives can be done with the functions `hasObjective` and `find`. Both can operate with just the type of
the objective (such as NoObjective or EnergyObjective), or use symbols. There is no guarantee of unicity with a type.
"""
struct ObjectiveCombination <: ProductionObjective # TODO: To test!
  objectives::Array{ProductionObjective, 1}
  symbols::Array{Symbol, 1}
  weights::Array{Float64, 1}

  function ObjectiveCombination(objectives::Array{ProductionObjective, 1},
                                weights::Array{Float64, 1}=ones(length(objectives));
                                symbols::Array{Symbol, 1}=Symbol[])
    # A few sanity checks.
    if length(objectives) != length(weights)
      error("Different number of objective functions and weights: " * string(length(objectives)) * " objectives, "
              * string(length(weights)) * " weights.") # TODO: To test explicitly!
    end

    if length(symbols) > 0 && length(objectives) != length(symbols)
      error("Different number of objective functions and symbols: " * string(length(objectives)) * " objectives, "
              * string(length(symbols)) * " symbols.") # TODO: To test explicitly!
    end

    # Generate the symbols if they are not provided. Otherwise, perform some sanity check.
    if length(symbols) == 0
      symbols = [Symbol(i) for i in 1:length(objectives)]
    elseif length(unique(symbols)) != length(symbols)
      error("Some symbols are identical: " * string(symbols)) # TODO: To test explicitly!
    end

    return new(objectives, symbols, weights)
  end
end

objectives(oc::ObjectiveCombination) = oc.objectives # TODO: To test!
symbols(oc::ObjectiveCombination) = oc.symbols # TODO: To test!
weights(oc::ObjectiveCombination) = oc.weights # TODO: To test!

nObjectives(oc::ObjectiveCombination) = length(objectives(oc)) # TODO: To test!
objectiveObject(oc::ObjectiveCombination, i::Int) = objectives(oc)[i] # TODO: To test! TODO: Get rid of objectiveObject()? Does the code still work with objective() instead of objectiveObject()?
objective(oc::ObjectiveCombination, i::Int) = oc.objectives[i] # TODO: To test!
symbol(oc::ObjectiveCombination, i::Int) = symbols(oc)[i] # TODO: To test!
weight(oc::ObjectiveCombination, i::Int) = weights(oc)[i] # TODO: To test!

"""
Returns an iterator of the objectives that have a truly nonzero weight. This is mostly useful to avoid generating
zero terms in the objective, making it more readable with JuMP.

Implementation details. Check for equality directly to zero: these are terms the user really wants not to see.
Very low values might be the result of some computation.
"""
nonzeroObjectives(oc::ObjectiveCombination) = filter((i) -> weight(oc, i) != 0.0, 1:nObjectives(oc)) # TODO: To test!

objectiveTimeStep(m::Model, oc::ObjectiveCombination, pm::PlantModel, d::DateTime) =
  sum([weight(oc, i) * objectiveTimeStep(m, objectiveObject(oc, i), pm, d) for i in nonzeroObjectives(oc)]) # TODO: To test!
objectiveShift(m::Model, oc::ObjectiveCombination, pm::PlantModel, d::DateTime) =
  sum([weight(oc, i) * objectiveShift(m, objectiveObject(oc, i), pm, d) for i in nonzeroObjectives(oc)]) # TODO: To test!
# TODO: Also directly test objective()!

copy(oc::ObjectiveCombination) = ObjectiveCombination(copy(objectives(oc)), copy(weights(oc))) # TODO: To test!

"""
Replaces the first objective that has the same type as `newObjective` by the latter in a new objective combination.
(The existing object is not altered.)

The behaviour is undefined in case of nonexistence of the objective to replace.
TODO: Check explicitly and throw an understandable error (instead of an undefined behaviour)?
"""
function replace(oc::ObjectiveCombination, newObjective::ProductionObjective, newWeight::Float64=NaN) # TODO: To test!
  idx = find((o) -> typeof(o) == typeof(newObjective), objectives(oc))

  # No such objective!
  if length(idx) == 0
    return oc
  end

  idx = idx[1] # Only consider the first such objective.
  nlo = copy(objectives(oc))
  nlw = copy(weights(oc))
  nlo[idx] = newObjective
  if ! isnan(newWeight)
    nlw[idx] = newWeight
  end
  return ObjectiveCombination(nlo, copy(symbols(oc)), nlw)
end

"""
Replaces the objective that has the `symbol` by `newObjective` in a *new* objective combination. (The existing object
is not altered.) If there is no objective with this `symbol`, a new one is added.
"""
function replace(oc::ObjectiveCombination, symbol::Symbol, newObjective::ProductionObjective, newWeight::Float64=NaN) # TODO: To test!
  idx = find((s) -> symbol == s, symbols(oc))

  # New lists for the new object.
  nlo = copy(objectives(oc))
  nls = copy(symbols(oc))
  nlw = copy(weights(oc))

  if length(idx) == 0 # No such objective!
    if isnan(newWeight)
      error("Adding a new objective, but the given weight is NaN. It must be a real number (positive, negative, or zero).")
    end

    push!(nlo, newObjective)
    push!(nls, symbol)
    push!(nlw, newWeight)
  else # Replace the objective.
    idx = idx[1]
    nlo[idx] = newObjective
    if ! isnan(newWeight)
      nlw[idx] = newWeight
    end
  end

  return ObjectiveCombination(nlo, nlw, symbols=nls)
end

"""
Determines whether the given objective combination `oc` has (at least) one objective of type `t`.

`t` must be the type of the objective to look for, such as `EnergyObjective` or `HRCostObjective`.
"""
hasObjective(t::DataType, oc::ObjectiveCombination) = in(t, [typeof(o) for o in objectives(oc)]) # TODO: To test!
hasObjective(t::DataType, oc::ProductionObjective) = false # TODO: To test!

"""
Determines whether the given objective combination `oc` has an objective whose symbol is `s`.
"""
hasObjective(s::Symbol, oc::ObjectiveCombination) = in(s, symbols(oc)) # TODO: To test!
hasObjective(s::Symbol, oc::ProductionObjective) = false # TODO: To test!

"""
Returns the first objective of type `t` in the combination `oc`.

If there is no such objective, an error is thrown. Existence of an objective type can be asserted with `hasObjective`.
"""
function find(t::DataType, oc::ObjectiveCombination) # TODO: To test!
  if ! hasObjective(t, oc)
    error("The objective combination has no objective with the given type \"" * string(t) * "\".")
  end
  return objectives(oc)[find((o) -> typeof(o) == t, objectives(oc))[1]]
end
find(t::DataType, oc::ProductionObjective) = error("Objectives other than ObjectiveCombination do not have a find() method.") # TODO: To test!

"""
Returns the objective whose symbol is `s` in the combination `oc`.

If there is no such objective, an error is thrown. Existence of an objective symbol can be asserted with `hasObjective`.
"""
function find(s::Symbol, oc::ObjectiveCombination) # TODO: To test!
  if ! hasObjective(s, oc)
    error("The objective combination has no objective with the given symbol \"" * string(s) * "\".")
  end
  return objectives(oc)[find((s) -> s == t, symbols(oc))[1]][1]
end
find(s::Symbol, oc::ProductionObjective) = error("Objectives other than ObjectiveCombination do not have a find() method.") # TODO: To test!



"""
No objective function. Objects of this type only act as placeholders.
"""
struct NoObjective <: ProductionObjective; end

objectiveTimeStep(m::Model, nobj::NoObjective, pm::PlantModel, d::DateTime) = AffExpr() # TODO: To test!
objectiveShift(m::Model, nobj::NoObjective, pm::PlantModel, d::DateTime) = AffExpr() # TODO: To test!



"""
Electricity prices. The electricity price is given as a time series `TimeArray`. Each equipment that has a consumption
in the plant model is concerned.

This objective offers two constructors:

  * one that performs sanity checks using a `Timing` object: there must be price information for each time step
  * one that performs no sanity checks; in this case, you might have failures down the line

Note: Currently, the library considers that the only energy is electricity.
"""
struct EnergyObjective <: ProductionObjective
  electricityPrice::TimeArray

  function EnergyObjective(electricityPrice::TimeArray, timing::Timing)
    for d in eachTimeStep(timing)
      if ! in(d, timestamp(electricityPrice))
        error("There is no electricity price for time step " * string(d))
      end
    end
    return new(electricityPrice)
  end

  function EnergyObjective(electricityPrice::TimeArray)
    return new(electricityPrice)
  end
end

"""
Retrieves the time series from the electricity objective.
"""
electricityPrice(eo::EnergyObjective) = eo.electricityPrice

"""
Retrieves the energy price at time `d`.
"""
function electricityPrice(eo::EnergyObjective, d::DateTime) 
  ts = electricityPrice(eo)
  if d < minimum(ts.timestamp)
    error("$d is before the first known electricity price, which is at $(minimum(ts.timestamp))")
  elseif d > maximum(ts.timestamp)
    error("$d is after the last known electricity price, which is at $(maximum(ts.timestamp))")
  end
  return electricityPrice(eo)[d].values[1]
end

function objectiveTimeStep(m::Model, eo::EnergyObjective, pm::PlantModel, d::DateTime)
  expr = AffExpr()
  for (eqName, eq) in equipmentModels(pm)
    for p in products(pm)
      if hasConsumption(p, equipment(eq)) && electricityPrice(eo, d) != 0.0
        # The consumption may be quite variable in structure: a constant, a linear expression, a quadratic expression, etc.
        # So no easy way to use push! here for performance.
        expr += electricityPrice(eo, d) * consumption(eq, p, d)
      end
    end
  end
  return expr
end



"""
Term in the objective function that associates a cost to each shift, possibly depending on the time of the day
of the shift. This might be used to enforce the HR costs of having workers a given shift, but also more precise
penalisations (avoid night shifts by giving them a very large cost, ignore others).
"""
struct HRCostObjective <: ProductionObjective
  price::Function # HRCostObjective(d::DateTime truncated to hours) -> Float64 TODO with Julia 0.5+: impose the signature of the function.
end

"""
Gives a price for having workers at time `d`.
"""
hrPrice(hro::HRCostObjective, d::DateTime) = hro.price(d)

"""
Evaluates the price of having workers doing the given `shifts` (for example, obtained as the result of the solver).
The first worked day is given by `firstDay`.
"""
function hrPrice(hro::HRCostObjective, firstDay::DateTime, shifts::BitArray{2}, timing::Timing) # TODO: Generalise this function so it is not tied to HRCostObjective?
  costs = similar(shifts, Float64)

  for i in 1:size(shifts, 2)
    dt = firstDay + (i - 1) * shiftDuration(timing)
    for team in 1:size(shifts, 1)
      shiftCost = sum([hrPrice(hro, dt2) for dt2 in dt:Hour(1):dt + shiftDuration(timing) - Hour(1)])
      costs[team, i] = shifts[team, i] * shiftCost
    end
  end

  return costs
end

function objectiveShift(m::Model, hro::HRCostObjective, pm::PlantModel, d::DateTime)
  hrm = timingModel(pm)

  # Check whether d is the beginning of a shift.
  # TODO: Only applies as such when shifts have a fixed length. Otherwise, could be replaced by a test on the discretisation of the shifts (if multiple of 2 hours, then must be at shiftBeginning + k * 2 hours).
  dt = shiftBeginning(hrm)
  while dt <= d
    if d == dt
      break
    else
      dt += shiftDuration(hrm)
    end
  end
  if dt > d
    error("The given date $(d) does not correspond to the beginning of a shift.")
  end

  # First accumulate the cost for each hour.
  shiftCost = 0.0
  i = 0
  while Hour(i) < shiftDuration(pm)
    shiftCost += hrPrice(hro, d + Hour(i))
    i += 1
  end

  # Then make up the expression for the whole shift.
  if shiftCost != 0.0
    return shiftCost * shiftOpen(hrm, d)
  else
    return AffExpr()
  end
end

# TODO: more objective functions! Transitions at the CC (some metal thrown when starting, changing the grade, stopping). Modelled as costs when transitions and stops occur in the first prototype.

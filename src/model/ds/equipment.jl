# TODO: To test (whole file! data structures, algorithms, and models).

# Variants of the model:
#    - depending on the number of products: simpler case for one product (no need to impose the "one product"
#      constraint).
#    - depending on the duration of the process: much simpler case for batch processes that last for one time step
#      (what flows in at one time step flows out at the next one, there is no storage).

abstract type AbstractEquipmentModel end
# TODO: Refactor? Eliminate this notion of AbstractEquipmentModel, only have EquipmentModel that is adapting depending on its arguments. This distinction with a base class is a source of head aches throughout the code.

struct EquipmentModel <: AbstractEquipmentModel
  equipment::Equipment
  timing::Timing
  ob::OrderBook

  quantity::Array{JuMP.Variable, 2}
  flowIn::Array{JuMP.Variable, 2}
  flowOut::Array{JuMP.Variable, 2}
  on::Array{JuMP.Variable, 1}
  start::Array{JuMP.Variable, 1}
  currentProduct::Array{JuMP.Variable, 2}

  function EquipmentModel(m::Model, eq::Equipment, timing::Timing, ob::OrderBook)
    # Basic model variables.
    flowIn  = @variable(m, [t=1:nTimeSteps(timing), p=1:nProducts(ob)], lowerbound=0)
    flowOut = @variable(m, [t=1:nTimeSteps(timing), p=1:nProducts(ob)], lowerbound=0)
    on      = @variable(m, [t=1:nTimeSteps(timing)], Bin)

    # If a process lasts for more than one time step, its quantity is not exactly what flows in, and it must be started.
    if nTimeSteps(timing, processTime(eq)) > 1
      quantity = @variable(m, [t=1:nTimeSteps(timing), p=1:nProducts(ob)], lowerbound= 0)
      start    = @variable(m, [t=1:nTimeSteps(timing)], Bin)
    else
      quantity = flowIn
      start = on
    end

    # Allows to make the distinction between the products (if needed).
    if nProducts(ob) > 1
      currentProduct = @variable(m, [t=1:nTimeSteps(timing), p=1:nProducts(ob)], Bin)
    else
      currentProduct = @variable(m, [t=1:0, p=1:0], Bin)
    end

    # Set the names of the variables.
    for t in 1:nTimeSteps(timing)
      setname(on[t], "equipment_on_$(name(eq))_$(t)")

      if nTimeSteps(timing, processTime(eq)) > 1
        setname(start[t], "equipment_start_$(name(eq))_$(t)")
        for p in 1:nProducts(ob)
          setname(quantity[t, p], "equipment_quantity_$(name(eq))_$(t)" * ((nProducts(ob) == 1) ? "" : "_prod$(p)"))
        end
      end

      for p in 1:nProducts(ob)
        setname(flowIn[t, p],  "equipment_flowIn_$(name(eq))_$(t)" * ((nProducts(ob) == 1) ? "" : "_prod$(p)"))
        setname(flowOut[t, p], "equipment_flowOut_$(name(eq))_$(t)" * ((nProducts(ob) == 1) ? "" : "_prod$(p)"))
        if nProducts(ob) > 1
          setname(currentProduct[t, p],  "equipment_currentProduct_$(name(eq))_$(t)_prod$(p)")
        end
      end
    end

    # Done!
    return new(eq, timing, ob, quantity, flowIn, flowOut, on, start, currentProduct)
  end
end

struct ImplicitEquipmentModel <: AbstractEquipmentModel
  equipment::AbstractEquipment
  timing::Timing
  ob::OrderBook

  quantity::Array{JuMP.Variable, 2}

  function ImplicitEquipmentModel(m::Model, eq::AbstractEquipment, timing::Timing, ob::OrderBook)
    quantity = @variable(m, [t=1:nTimeSteps(timing), p=1:nProducts(ob)], lowerbound=0)
    for t in 1:nTimeSteps(timing)
      for p in 1:nProducts(ob)
        setname(quantity[t, p], "equipment_quantity_$(name(eq))_$(t)" * ((nProducts(ob) == 1) ? "" : "_prod$(p)"))
      end
    end
    return new(eq, timing, ob, quantity)
  end
end

# New constructors so that the user does not even need to care about the distinction between EquipmentModel and ImplicitEquipmentModel when building objects.
EquipmentModel(m::Model, eq::InImplicitEquipment, timing::Timing, ob::OrderBook) = ImplicitEquipmentModel(m, eq, timing, ob)
EquipmentModel(m::Model, eq::OutImplicitEquipment, timing::Timing, ob::OrderBook) = ImplicitEquipmentModel(m, eq, timing, ob)

# Basic accessors for the model (needed to link to the subobjects).
equipment(eq::AbstractEquipmentModel) = eq.equipment
timing(eq::AbstractEquipmentModel) = eq.timing
orderBook(eq::AbstractEquipmentModel) = eq.ob

# Link to the methods of Equipment.
name(eq::EquipmentModel) = name(equipment(eq))
kind(eq::EquipmentModel) = kind(equipment(eq))
transformationRate(eq::EquipmentModel) = transformationRate(equipment(eq))
minimumUpTime(eq::EquipmentModel) = minimumUpTime(equipment(eq))
minimumProduction(eq::EquipmentModel) = minimumProduction(equipment(eq))
maximumProduction(eq::EquipmentModel) = maximumProduction(equipment(eq))
processTime(eq::EquipmentModel) = processTime(equipment(eq))

name(eq::ImplicitEquipmentModel) = name(equipment(eq))
kind(eq::ImplicitEquipmentModel) = kind(equipment(eq))

# Link to the methods of Timing.
timeBeginning(eq::AbstractEquipmentModel) = timeBeginning(timing(eq))
timeHorizon(eq::AbstractEquipmentModel) = timeHorizon(timing(eq))
timeEnding(eq::AbstractEquipmentModel) = timeEnding(timing(eq))
timeStepDuration(eq::AbstractEquipmentModel) = timeStepDuration(timing(eq))

nTimeSteps(eq::AbstractEquipmentModel, d::Period) = nTimeSteps(timing(eq), d) # TODO: Required here or not?
nTimeSteps(eq::AbstractEquipmentModel) = nTimeSteps(timing(eq))
dateToTimeStep(eq::AbstractEquipmentModel, d::DateTime) = dateToTimeStep(timing(eq), d)
eachTimeStep(eq::AbstractEquipmentModel; kwargs...) = eachTimeStep(timing(eq); kwargs...)

# Link to the methods of OrderBook.
products(eq::AbstractEquipmentModel) = products(orderBook(eq))
nProducts(eq::AbstractEquipmentModel) = nProducts(orderBook(eq))
productIds(eq::AbstractEquipmentModel) = productIds(orderBook(eq))

# Link to the methods of Product.
maxBatchSize(p::Product, eq::EquipmentModel) = maxBatchSize(p, equipment(eq))
minBatchSize(p::Product, eq::EquipmentModel) = minBatchSize(p, equipment(eq))

# Specific model accessors: low level.
quantity(eq::AbstractEquipmentModel) = eq.quantity
flowIn(eq::EquipmentModel) = eq.flowIn
flowOut(eq::EquipmentModel) = eq.flowOut
on(eq::EquipmentModel) = eq.on
start(eq::EquipmentModel) = eq.start
currentProduct(eq::EquipmentModel) = eq.currentProduct
currentProduct(eq::ImplicitEquipmentModel) = error("Implicit equipments do not have a current product variable per se. Use the one of the up/downstream piece of equipment.")

# Specific model accessors: high level.
quantity(eq::EquipmentModel, ts::Int, nProduct::Int) = quantity(eq)[ts, nProduct]
flowIn(eq::EquipmentModel, ts::Int, nProduct::Int) = flowIn(eq)[ts, nProduct]
flowOut(eq::EquipmentModel, ts::Int, nProduct::Int) = flowOut(eq)[ts, nProduct]
on(eq::EquipmentModel, ts::Int) = on(eq)[ts]
start(eq::EquipmentModel, ts::Int) = start(eq)[ts]
currentProduct(eq::EquipmentModel, ts::Int, nProduct::Int) = if nProducts(eq) > 1; currentProduct(eq)[ts, nProduct]; else; error("Only one product, currentProduct makes no sense"); end

quantity(eq::ImplicitEquipmentModel, ts::Int, nProduct::Int) = eq.quantity[ts, nProduct]
flowIn(eq::ImplicitEquipmentModel, ts::Int, nProduct::Int) = if kind(equipment(eq)) == :out; quantity(eq)[ts, nProduct]; else; error("Implicit in equipment has no flow in."); end
flowOut(eq::ImplicitEquipmentModel, ts::Int, nProduct::Int) = if kind(equipment(eq)) == :in; quantity(eq)[ts, nProduct]; else; error("Implicit out equipment has no flow out."); end

# Easy-to-use model accessors.
function checkDate(eq::AbstractEquipmentModel, d::DateTime, variable::Symbol) # TODO: To test! Same with the following function when they used to error.
  if d > timeEnding(eq)
    error("Asked time " * string(d) * " is beyond the optimisation horizon " * string(timeEnding(eq)) * " for the variable " * string(variable))
  end
  if d < timeBeginning(eq)
    error("Asked time " * string(d) * " is before the beginning of the optimisation horizon " * string(timeBeginning(eq)) * " for the variable " * string(variable))
  end
  return true
end

productId(eq::AbstractEquipmentModel, p::Product) = productIds(eq)[p]
quantity(eq::AbstractEquipmentModel, d::DateTime, p::Product) = checkDate(eq, d, :quantity) && quantity(eq, dateToTimeStep(eq, d), productId(eq, p))
flowIn(eq::AbstractEquipmentModel, d::DateTime, p::Product) = checkDate(eq, d, :flowIn) && flowIn(eq, dateToTimeStep(eq, d), productId(eq, p))
flowOut(eq::AbstractEquipmentModel, d::DateTime, p::Product) = checkDate(eq, d, :flowOut) && flowOut(eq, dateToTimeStep(eq, d), productId(eq, p))
on(eq::EquipmentModel, d::DateTime) = checkDate(eq, d, :on) && on(eq, dateToTimeStep(eq, d)) # Undefined for ImplicitEquipmentModel.
start(eq::EquipmentModel, d::DateTime) = checkDate(eq, d, :start) && start(eq, dateToTimeStep(eq, d)) # Undefined for ImplicitEquipmentModel.
currentProduct(eq::EquipmentModel, d::DateTime, p::Product) = currentProduct(eq, dateToTimeStep(eq, d), productId(eq, p))

off(eq::EquipmentModel, d::DateTime) = checkDate(eq, d, :off) && 1 - on(eq, d) # Undefined for ImplicitEquipmentModel.
stop(eq::EquipmentModel, d::DateTime) = checkDate(eq, d - processTime(eq), :stop) && start(eq, d - processTime(eq)) # Undefined for ImplicitEquipmentModel. TODO: What happens before optimisation horizon? Should read from the initial conditions. For now, just thrown an error.


# Define the constraints.
function postConstraints(m::Model, eq::EquipmentModel, hrm::TimingModel)
  for d in eachTimeStep(eq)
    # TODO: Only for non-continuous processes.
    # An equipment is started if it was off and becomes on. This only makes sense if the process lasts for more than
    # one time step (otherwise, each time the process is on, it is started).
    if nTimeSteps(eq, processTime(eq)) > 1
      # The process lasts for multiple time steps.
      if d > timeBeginning(eq)
        @constraint(m, start(eq, d) <= on(eq, d))
        @constraint(m, start(eq, d) <= off(eq, d - timeStepDuration(eq)))
        @constraint(m, start(eq, d) >= on(eq, d) + off(eq, d - timeStepDuration(eq)) - 1)
      elseif d == timeBeginning(eq) # TODO: handle the time step before optimisation! For now, was off.
        @constraint(m, on(eq, d) == start(eq, d))
      end
    end

    # TODO: Only for non-continuous processes when they have a duration.
    # When starting, an equipment must remain on for a given number of time periods.
    if nTimeSteps(eq, processTime(eq)) > 1 
      for d2 in eachTimeStep(eq, from=d, to=d + minimumUpTime(eq))
        @constraint(m, on(eq, d2) >= start(eq, d))
      end
    end

    # The process may only be running or starting when the current time step is allowed. 
    # TODO: How to split this among the various components? Just for processes that are not continuous or at least stoppable. 
    if nTimeSteps(eq, processTime(eq)) > 1
      @constraint(m, start(eq, d) <= timeStepOpen(hrm, d))
    end
    @constraint(m, on(eq, d) <= timeStepOpen(hrm, d))

    # TODO: Strengthen formulation: the equipment can start at most once in any time period of the process duration.
    # TODO: Strengthen formulation: if an equipment is on, it was started within the minimumUpTime last previous time steps.
    # TODO: Functionality: maximum up time; same with down.

    # Quantities only evolve when the flows in and out are evolving.
    # TODO: Only constraint that is really specific to a piece of equipment.
    if nTimeSteps(eq, processTime(eq)) > 1
      for p in products(eq)
        if d > timeBeginning(eq)
          @constraint(m, quantity(eq, d, p) == quantity(eq, d - timeStepDuration(eq), p) + flowIn(eq, d, p) - flowOut(eq, d, p) / transformationRate(eq))
        elseif d == timeBeginning(eq) # TODO: handle the time step before optimisation! For now, was empty.
          @constraint(m, quantity(eq, d, p) == flowIn(eq, d, p))
          # No outflow ensured by the minimum and maximum flows for the process (when d is before the  process time). 
        end
      end
    else
      # No quantity for short processes (one time step), it is entirely replaced by flowIn.
      for p in products(eq)
        if d > timeBeginning(eq)
          @constraint(m, flowIn(eq, d - timeStepDuration(eq), p) == flowOut(eq, d, p) / transformationRate(eq))
        elseif d == timeBeginning(eq) 
          # No outflow ensured by the minimum and maximum flows for the process (when d is before the  process time). 
        end
      end
    end

    # At most one product at a time, but only when the equipment is on.
    # Obviously, only when there are multiple products!
    if nProducts(eq) > 1 
      maxFlowIn = min(maximumProduction(eq), minimum([maxBatchSize(p, eq) for p in products(eq)]))
      minFlowIn = max(minimumProduction(eq), maximum([minBatchSize(p, eq) for p in products(eq)]))

      # @constraint(m, sum([currentProduct(eq, d, p) for p in products(eq)]) <= 1) # TODO: Why does this help the solver?
      @constraint(m, sum([currentProduct(eq, d, p) for p in products(eq)]) == on(eq, d)) # Slightly stronger than writing currentProduct <= on for each product separately.
      for p in products(eq)
        if min(maxFlowIn, maxBatchSize(p, eq)) != max(minFlowIn, minBatchSize(p, eq))
          @constraint(m, quantity(eq, d, p) <= min(maxFlowIn, maxBatchSize(p, eq)) * currentProduct(eq, d, p))
          @constraint(m, quantity(eq, d, p) >= max(minFlowIn, minBatchSize(p, eq)) * currentProduct(eq, d, p))
        else
          @constraint(m, quantity(eq, d, p) == max(minFlowIn, minBatchSize(p, eq)) * currentProduct(eq, d, p))
        end
      end
    end

    # TODO: Factor this out for non-batch processes!
    # A batch equipment can only have inputs when it starts.
    maxFlowIn = min(maximumProduction(eq), minimum([maxBatchSize(p, eq) for p in products(eq)]))
    minFlowIn = max(minimumProduction(eq), maximum([minBatchSize(p, eq) for p in products(eq)]))
    @constraint(m, sum([flowIn(eq, d, p) for p in products(eq)]) <= maxFlowIn * start(eq, d))

    # TODO: Factor this out for stoppable processes!
    # Limit the quantity within the process when it is off, either globally or per product.
    if nProducts(eq) > 1
      # A batch equipement can only have contents when it is on.
      if minimumProduction(eq) != maxFlowIn
        @constraint(m, sum([quantity(eq, d, p) for p in products(eq)]) <= maxFlowIn * on(eq, d))
        if minimumProduction(eq) > 0.
          @constraint(m, sum([quantity(eq, d, p) for p in products(eq)]) >= minimumProduction(eq) * on(eq, d))
        end
      else
        @constraint(m, sum([quantity(eq, d, p) for p in products(eq)]) == maxFlowIn * on(eq, d))
      end

      # The contents of the equipment are limited by the heat size.
      for p in products(eq)
        if min(maximumProduction(eq), maxBatchSize(p, eq)) != minBatchSize(p, eq)
          @constraint(m, quantity(eq, d, p) <= min(maximumProduction(eq), maxBatchSize(p, eq)) * on(eq, d))
          if minBatchSize(p, eq) > 0.
            @constraint(m, quantity(eq, d, p) >= minBatchSize(p, eq) * on(eq, d))
          end
        else
          @constraint(m, quantity(eq, d, p) == minBatchSize(p, eq) * on(eq, d))
        end
      end
    else
      # Write the two previous constraints together when there is only one product, using the tightest bounds.
      p = products(eq)[1]
      if min(maximumProduction(eq), maxBatchSize(p, eq)) != max(minimumProduction(eq), minBatchSize(p, eq))
        @constraint(m, quantity(eq, d, p) <= min(maximumProduction(eq), maxBatchSize(p, eq)) * on(eq, d))
        if max(minimumProduction(eq), minBatchSize(p, eq)) > 0.
          @constraint(m, quantity(eq, d, p) >= max(minimumProduction(eq), minBatchSize(p, eq)) * on(eq, d))
        end
      else
        @constraint(m, quantity(eq, d, p) == min(maximumProduction(eq), maxBatchSize(p, eq)) * on(eq, d))
      end
    end

    # TODO: Factor this out for batch processes!
    # A batch equipment can only have outputs when it is done.
    if d - processTime(eq) < timeBeginning(eq)
      # TODO: Initial conditions to replace the zero. 
      @constraint(m, sum([flowOut(eq, d, p) for p in products(eq)]) == 0.)
    else
      if maxFlowIn != minFlowIn
        @constraint(m, sum([flowOut(eq, d, p) for p in products(eq)]) <= transformationRate(eq) * maxFlowIn * stop(eq, d))
        @constraint(m, sum([flowOut(eq, d, p) for p in products(eq)]) >= transformationRate(eq) * minFlowIn * stop(eq, d))
      else
        @constraint(m, sum([flowOut(eq, d, p) for p in products(eq)]) == transformationRate(eq) * maxFlowIn * stop(eq, d))
      end
    end
  end
end

function postConstraints(m::Model, eq::ImplicitEquipmentModel, hrm::TimingModel) 
  for d in eachTimeStep(eq)
    # At most one product at a time.
    # TODO: Should be implied by the equipment constraints.
    # @constraint(m, sum([currentProduct(eq, d, p) for p in products(eq)]) <= 1)

    # The actual constraints are in the order book.
  end
end

function postConstraints(m::Model, hrm::TimingModel, eqs::Array{EquipmentModel, 1}) # TODO: First eqs, then hrm? 
  # A shift is open only if at least one equipment is used during that shift.
  # Otherwise, if the shifts have negative coefficients in the objective, the solver is free to open shifts, even though
  # no one is working at that time.
  for d in eachTimeStep(hrm)
    @constraint(m, timeStepOpen(hrm, d) <= sum([on(eq, d) for eq in eqs]))

    # EquipmentModel has the reverse constraint: on(eq, d) <= timeStepOpen(d).
    # postConstraints(m::Model, eq::EquipmentModel, hrm::TimingModel)
  end
end

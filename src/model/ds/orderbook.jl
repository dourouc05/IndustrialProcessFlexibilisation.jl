struct OrderBookModel
  ob::OrderBook
  timing::Timing

  function OrderBookModel(m::Model, ob::OrderBook, t::Timing)
    # No variables to create, so ignore m.

    # Check whether the timing in the order book matches that of the timing object.
    if nOrders(ob) > 0
      if latest(ob) < timeBeginning(t)
        warn("The latest order is at $(latest(ob)), but the optimisation starts later, at $(timeBeginning(t)).")
      end
      if earliest(ob) >= timeEnding(t)
        warn("The earliest order is at $(earliest(ob)), but the optimisation ends sooner, at $(timeEnding(t)).")
      end
    end

    return new(ob, t)
  end
end

# Basic accessors for the model (needed to link to the subobjects).
orderBook(ob::OrderBookModel) = ob.ob
timing(ob::OrderBookModel) = ob.timing

# Link to the methods of Timing.
timeBeginning(ob::OrderBookModel) = timeBeginning(timing(ob))
timeHorizon(ob::OrderBookModel) = timeHorizon(timing(ob))
timeEnding(ob::OrderBookModel) = timeEnding(timing(ob))
timeStepDuration(ob::OrderBookModel) = timeStepDuration(timing(ob))

nTimeSteps(ob::OrderBookModel, d::Period) = nTimeSteps(timing(ob), d)
nTimeSteps(ob::OrderBookModel) = nTimeSteps(timing(ob))
dateToTimeStep(ob::OrderBookModel, d::DateTime) = dateToTimeStep(timing(ob), d)
eachTimeStep(ob::OrderBookModel; kwargs...) = eachTimeStep(timing(ob); kwargs...)

# Link to the methods of OrderBook.
orderBookDetails(ob::OrderBookModel) = orderBook(orderBook(ob))
dates(ob::OrderBookModel) = dates(orderBook(ob))
products(ob::OrderBookModel) = products(orderBook(ob))
nProducts(ob::OrderBookModel) = nProducts(orderBook(ob))
dueBy(ob::OrderBookModel, dt::DateTime; kwargs...) = dueBy(orderBook(ob), dt; kwargs...)
fromto(ob::OrderBookModel, from::DateTime, to::DateTime) = fromto(orderBook(ob), from, to)
productIds(ob::OrderBookModel) = productIds(orderBook(ob))
productId(ob::OrderBookModel, p::Product) = productId(orderBook(ob), p)
productFromId(ob::OrderBookModel, i::Int) = productFromId(orderBook(ob), i)


function postConstraints(m::Model, ob::OrderBookModel, out::ImplicitEquipmentModel, alreadyProduced::Dict{Product, Float64}=Dict{Product, Float64}())
  if kind(out) != :out
    error("Expected the output node as equipment, got: " * string(king(out)))
  end

  oldDb = nothing
  for d in eachTimeStep(ob)
    db = dueBy(ob, d, cumulative=true)

    for (p, q) in db
      # If there is nothing new to be produced, then skip this constraing.
      if oldDb != nothing
        if haskey(oldDb, p) && q == oldDb[p]
          continue
        end
      end

      # Always discount what has already been produced.
      remainingQ = q - if haskey(alreadyProduced, p) alreadyProduced[p] else 0 end
      @constraint(m, sum([quantity(out, d2, p) for d2 in timeBeginning(ob) : timeStepDuration(ob) : d]) >= remainingQ)
    end
    oldDb = db
  end
end

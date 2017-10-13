struct FlowModel
  origin::AbstractEquipment
  destination::AbstractEquipment
  timing::Timing
  ob::OrderBook

  minValue::Float64
  maxValue::Float64

  function FlowModel(m::Model, origin::AbstractEquipment, destination::AbstractEquipment, timing::Timing, orderBook::OrderBook; minValue::Float64=0.0, maxValue::Float64=1.e10)
    # value = JuMP.Variable[] # TODO: Is a variable needed here? Yes, when there are multiple routes. I guess this class is flawed by design: should rather be a point between equipments (some dummy kind of equipment).

    return new(origin, destination, timing, orderBook, minValue, maxValue)
  end
end

# Basic accessors for the model.
origin(f::FlowModel) = f.origin # TODO: To test!
destination(f::FlowModel) = f.destination # TODO: To test!
timing(f::FlowModel) = f.timing # TODO: To test!
orderBook(f::FlowModel) = f.ob # TODO: To test!
minimumValue(f::FlowModel) = f.minValue # TODO: To test!
maximumValue(f::FlowModel) = f.maxValue # TODO: To test!

# Link to the methods of Timing.
timeBeginning(f::FlowModel) = timeBeginning(timing(f)) # TODO: To test
timeHorizon(f::FlowModel) = timeHorizon(timing(f)) # TODO: To test
timeEnding(f::FlowModel) = timeEnding(timing(f)) # TODO: To test
timeStepDuration(f::FlowModel) = timeStepDuration(timing(f)) # TODO: To test

nTimeSteps(f::FlowModel, d::Period) = nTimeSteps(timing(f), d)  # TODO: To test
nTimeSteps(f::FlowModel) = nTimeSteps(timing(f)) # TODO: To test
dateToTimeStep(f::FlowModel, d::DateTime) = dateToTimeStep(timing(f), d) # TODO: To test
eachTimeStep(f::FlowModel; kwargs...) = eachTimeStep(timing(f); kwargs...)

# Link to the methods of OrderBook.
products(f::FlowModel) = products(orderBook(f))
nProducts(f::FlowModel) = nProducts(orderBook(f))


function postConstraints(m::Model, f::FlowModel, eqs::Dict{AbstractString, AbstractEquipmentModel}) 
  if typeof(origin(f)) <: ImplicitEquipment && typeof(destination(f)) <: ImplicitEquipment
    error("Assertion failed: flow between two implicit equipments (in and out). ")
  end

  for d in eachTimeStep(f)
    for p in products(f)
      @constraint(m, flowOut(eqs[name(origin(f))], d, p) == flowIn(eqs[name(destination(f))], d, p))
      @constraint(m, flowOut(eqs[name(origin(f))], d, p) <= maximumValue(f)) # As there is no variable for a flow, the bounds must be imposed somewhere.
      if minimumValue(f) > 0
        @constraint(m, flowOut(eqs[name(origin(f))], d, p) >= minimumValue(f))
      end
    end
  end
end

struct FlowModel
  origin::AbstractEquipment
  destination::AbstractEquipment
  timing::Timing
  ob::OrderBook

  value::Array{JuMP.Variable,1}
  minValue::Float64
  maxValue::Float64

  function FlowModel(m::Model, origin::AbstractEquipment, destination::AbstractEquipment, timing::Timing, orderBook::OrderBook; minValue::Float64=0.0, maxValue::Float64=1.e10)
    # @variable(m, minValue <= value[t=1:nTimeSteps(timing)] <= maxValue)#, basename="flow_value_" * name(origin) * "_to_" * name(destination) * "_$t")
    value = JuMP.Variable[] # TODO: Is a variable needed here? Yes, when there are multiple routes. I guess this class is flawed by design: should rather be a point between equipments.

    return new(origin, destination, timing, orderBook, value, minValue, maxValue)
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
timeBeginning(f::FlowModel) = timeBeginning(timing(f))
timeHorizon(f::FlowModel) = timeHorizon(timing(f))
timeEnding(f::FlowModel) = timeEnding(timing(f)) # TODO: To test
timeStepDuration(f::FlowModel) = timeStepDuration(timing(f))

nTimeSteps(f::FlowModel, d::Period) = nTimeSteps(timing(f), d) # TODO: Required here or not?
nTimeSteps(f::FlowModel) = nTimeSteps(timing(f))
dateToTimeStep(f::FlowModel, d::DateTime) = dateToTimeStep(timing(f), d)
eachTimeStep(f::FlowModel; kwargs...) = eachTimeStep(timing(f); kwargs...)

# Link to the methods of OrderBook.
products(f::FlowModel) = products(orderBook(f))
nProducts(f::FlowModel) = nProducts(orderBook(f))

# Specific model accessors (need the sub-objects accessors).
# value(f::FlowModel) = f.value
# value(f::FlowModel, ts::Int) = value(f)[ts]
# value(f::FlowModel, d::DateTime) = value(f, dateToTimeStep(f, d), productId(eq, p))


function postConstraints(m::Model, f::FlowModel, eqs::Dict{AbstractString, AbstractEquipmentModel}) 
  if typeof(origin(f)) <: ImplicitEquipment && typeof(destination(f)) <: ImplicitEquipment
    error("Assertion failed: flow between two implicit equipments (in and out). ")
  end

  for d in eachTimeStep(f)
    for p in products(f)
      @constraint(m, flowOut(eqs[name(origin(f))], d, p) == flowIn(eqs[name(destination(f))], d, p))
      @constraint(m, flowOut(eqs[name(origin(f))], d, p) <= maximumValue(f)) # As there is no flow variable, the bounds must be imposed somewhere.
      if minimumValue(f) > 0
        @constraint(m, flowOut(eqs[name(origin(f))], d, p) >= minimumValue(f))
      end
    end
  end
end

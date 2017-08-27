struct PlantModel
  plant::Plant
  orderBook::OrderBook
  timing::Timing
  shifts::Shifts

  hr::TimingModel
  equipments::Dict{AbstractString, AbstractEquipmentModel} # (name of equipment) -> equipment
  flows::Dict{Tuple{AbstractString, AbstractString}, FlowModel} # (name of equipment, name of equipment) -> flow;
  # "in" and "out" are also considered as pieces of equipment, and correspond to the inflow of raw material
  # and the outflow of finished products.
  ob::OrderBookModel

  function PlantModel(m::Model, p::Plant, ob::OrderBook, timing::Timing, shifts::Shifts)
    # Create the variables for the HR part of the model.
    hr = TimingModel(m, timing, shifts)

    # Consistency check: the plant must have the required equipments for all the products in the order book.
    for pr in products(ob) # TODO: To check!
      if ! hasRequiredEquipments(p, pr)
        error("Required equipment " * name(e) * " not found in plant.")
      end
    end

    # Create the variables for each piece of equipment (considered separately).
    eqs = Dict{AbstractString, AbstractEquipmentModel}()
    for eq in equipments(p)
      eqs[name(eq)] = EquipmentModel(m, eq, timing, ob)
    end

    # Create the variables for the flows between the pieces of equipment (including "in" and "out").
    # TODO: Factor this out! Test it!
    neededFlows = Set{Tuple{AbstractString, AbstractString}}()
    for product in products(ob)
      requiredSteps = requiredEquipments(product)

      # If there are routes in the plant: find the origin and the destination.
      if length(routes(p)) > 0 # TODO: To test!
        # Origin: the step(s) without any incoming edge, i.e. no routes to this node.
        origins = Equipment[]
        for eq in copy(requiredSteps)
          if length(routes(p, to=eq)) == 0
            for e in equipments(p, eq)
              push!(origins, e)
            end
            filter!(e -> e != eq, requiredSteps)
          end
        end
        if length(origins) == 0
          error("No first node found for making product " * name(product) * ".")
        end
        union!(neededFlows, [("in", name(origin)) for origin in origins])

        # Destination: the only step(s) without any outgoing edge.
        destinations = Equipment[]
        for eq in copy(requiredSteps)
          if length(routes(p, from=eq)) == 0
            for e in equipments(p, eq)
              push!(destinations, e)
            end
            filter!(e -> e != eq, requiredSteps)
          end
        end
        if length(destinations) == 0
          error("No last node found for making product " * name(product) * ".")
        end
        union!(neededFlows, [(name(destination), "out") for destination in destinations])

        # Inner edges linked to either the origins or the destinations.
        # TODO: Are these two loops required?
        for origin in origins
          lr = filter(r -> in(to(r), requiredSteps), routes(p, from=origin))
          union!(neededFlows, [(name(origin), name(to(r))) for r in lr])
        end
        for destination in destinations
          lr = filter(r -> in(from(r), requiredSteps), routes(p, to=destination))
          union!(neededFlows, [(name(from(r)), name(destination)) for r in lr])
        end

        # Other edges between the required steps.
        for eq in copy(requiredSteps)
          # From eq.
          lr = filter(r -> in(kind(to(r)), requiredEquipments(product)), routes(p, from=eq))
          for e in equipments(p, eq)
            union!(neededFlows, [(name(e), name(to(r))) for r in lr])
          end

          # To eq.
          lr = filter(r -> in(kind(from(r)), requiredEquipments(product)), routes(p, to=eq))
          for e in equipments(p, eq)
            union!(neededFlows, [(name(from(r)), name(e)) for r in lr])
          end
        end
      else
        # No routes: the origin is the destination, which is the only piece of equipment found in the plant.
        # Thus, only two flows, that go from the origin to the equipment, and from the equipment to the destination.
        union!(neededFlows, [("in", name(equipments(p, requiredEquipments(product)[1])[1])), (name(equipments(p, requiredEquipments(product)[1])[1]), "out")])
      end
    end

    # Determine the needed flows for the plant and build their models.
    function __maxValue(f::Tuple{AbstractString, AbstractString})
      # By construction, there must be a piece of equipment, i.e. no flow between two implicit pieces of equipment.
      if isa(equipment(p, f[1]), ImplicitEquipment)
        # Hack for Julia 0.4: it seems it is impossible to retrieve the right element from the hash table
        # with "standard" techniques. Hence convert the dictionary to a list of pairs, filter the required one,
        # extract the corresponding value. This is very brittle, of course.
        #     collect(batchSizes(products(ob)[1])): pairs of pieces of equipments and batch sizes.
        #     filter(psdfg -> psdfg[1] == equipment(p, f[1]), ...): sizes for the required equipment.
        #     ...[1][2]: first (and only) pair matching, take the batch sizes.
        #     ...[2]: from the batch size tuple, take the maximum.
        # TODO: only one product here, innit?
        return filter(psdfg -> psdfg[1] == equipment(p, f[2]), collect(batchSizes(products(ob)[1])))[1][2][2]
        # return maxBatchSize(products(ob), equipment(p, f[2]))
      else
        # As above.
        return filter(psdfg -> psdfg[1] == equipment(p, f[1]), collect(batchSizes(products(ob)[1])))[1][2][2]
        # return maxBatchSize(products(ob), equipment(p, f[1]))
      end
    end
    flows = Dict{Tuple{AbstractString, AbstractString}, FlowModel}(
      (f[1], f[2]) => FlowModel(m, equipment(p, f[1]), equipment(p, f[2]), timing, ob,
                                 maxValue=__maxValue(f)) for f in neededFlows)
    # TODO: Bounds depending on the products for that flow (instead of a generic maxBatchSize over all products in the plant)?
    # TODO: hard-coded batch processes, as a full batch must leave one process to enter the next one.

    orderBookModel = OrderBookModel(m, ob, timing)

    return new(p, ob, timing, shifts, hr, eqs, flows, orderBookModel)
  end
end

# Basic accessors for sub-objects.
plant(pm::PlantModel) = pm.plant # TODO: To test!
orderBook(pm::PlantModel) = pm.orderBook # TODO: To test!
timing(pm::PlantModel) = pm.timing # TODO: To test!
shifts(pm::PlantModel) = pm.shifts # TODO: To test!

timingModel(pm::PlantModel) = pm.hr
equipmentModels(pm::PlantModel) = pm.equipments
flowModels(pm::PlantModel) = pm.flows
orderBookModel(pm::PlantModel) = pm.ob

equipmentModel(pm::PlantModel, e::AbstractString) = pm.equipments[e]
flowModel(pm::PlantModel, f::Tuple{AbstractString, AbstractString}) = pm.flows[f]
flowModel(pm::PlantModel, o::AbstractString, d::AbstractString) = pm.flows[(o, d)]

nEquipments(pm::PlantModel) = length(equipments(pm))

# Link to the methods of Timing.
timeBeginning(pm::PlantModel) = timeBeginning(timing(pm))
timeHorizon(pm::PlantModel) = timeHorizon(timing(pm))
timeEnding(pm::PlantModel) = timeEnding(timing(pm)) # TODO: To test!
timeStepDuration(pm::PlantModel) = timeStepDuration(timing(pm))

nTimeSteps(pm::PlantModel, d::Period) = nTimeSteps(timing(pm), d) 
nTimeSteps(pm::PlantModel) = nTimeSteps(timing(pm))
dateToTimeStep(pm::PlantModel, d::DateTime) = dateToTimeStep(timing(pm), d)
eachTimeStep(pm::PlantModel; kwargs...) = eachTimeStep(timing(pm); kwargs...)

# Link to the methods of Shifts. 
shiftBeginning(pm::PlantModel) = shiftBeginning(shifts(pm))
shiftDuration(pm::PlantModel) = shiftDuration(shifts(pm))
shiftDurations(pm::PlantModel) = shiftDurations(shifts(pm))
shiftDurationsStart(pm::PlantModel) = shiftDurationsStart(shifts(pm)) # TODO: TO TEST! 
shiftDurationsStep(pm::PlantModel) = shiftDurationsStep(shifts(pm)) # TODO: TO TEST! 
shiftDurationsStop(pm::PlantModel) = shiftDurationsStop(shifts(pm)) # TODO: TO TEST! 
nShiftDurations(pm::PlantModel) = nShiftDurations(shifts(pm)) # TODO: TO TEST! 

# Link to the methods of OrderBook.
orderBookDetails(pm::PlantModel) = orderBook(orderBook(pm))
dates(pm::PlantModel) = dates(orderBook(pm))
products(pm::PlantModel) = products(orderBook(pm))
nProducts(pm::PlantModel) = nProducts(orderBook(pm))

function productionModel(p::Plant, ob::OrderBook, timing::Timing, shifts::Shifts, obj::ProductionObjective;
                         solver::MathProgBase.AbstractMathProgSolver=JuMP.UnsetSolver(), outfile="",
                         alreadyProduced::Dict{Product, Float64}=Dict{Product, Float64}(),
                         forcedShifts::Array{Tuple{DateTime, Hour, Int}, 1}=Tuple{DateTime, Hour, Int}[]) 
  ## Variables.
  m = Model(solver=solver)
  pm = PlantModel(m, p, ob, timing, shifts)

  ## Constraints.
  postConstraints(m, pm.hr, forcedShifts) # Timing and HR
  postConstraints(m, pm.hr, collect(EquipmentModel, Iterators.filter((e) -> typeof(e) == EquipmentModel, values(equipmentModels(pm))))) # All equipments
  for eq in values(equipmentModels(pm)) 
    postConstraints(m, eq, pm.hr) # Each equipment
  end
  postConstraints(m, pm.ob, equipmentModel(pm, "out"), alreadyProduced) # Order book
  for (name, f) in flowModels(pm)
    postConstraints(m, f, equipmentModels(pm)) # Each flow between pieces of equipment
  end

  # TODO: Strengthen the formulation: when two pieces of equipment are next to each other in the same route, then the second may only be activated when the first one is done (batch processes).

  @objective(m, Min, objective(m, obj, pm))

  # writeLP(m, outfile, genericnames=false)
  status = solve(m)

  if status != :Infeasible && status != :Unbounded && status != :Error
    shiftsOpen = [round(Bool, round(Int, getvalue(shiftOpen(timingModel(pm), d)))) for d in timeBeginning(pm) : shiftDurationsStep(pm) : timeEnding(pm)] 
    productionRaw = getvalue(quantity(equipmentModel(pm, "out"))) # TODO: In PlantModel, link to the variables of each subobject model? Define quantity() and others on the plant model? Or just a subset?
    return ProductionModelResults(m, pm, shiftsOpen, shiftsAgregation(shiftsOpen, timing, shifts, solver), productionRaw)
  else
    if length(outfile) > 0 # TODO: More configurable than this! Currently, output just if file specified and the problem is infeasible. Should allow outputting in any case, in case of infeasibility, and never. 
      writeLP(m, outfile, genericnames=false)
    end
    return ProductionModelResults(m, pm)
  end
end

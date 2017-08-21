function productionModel(p::Plant, ob::OrderBook, timing::Timing, shifts::Shifts, obj::ProductionObjective;
                         solver::MathProgBase.AbstractMathProgSolver=JuMP.UnsetSolver(), outfile="",
                         alreadyProduced::Dict{Product, Float64}=Dict{Product, Float64}(),
                         forcedShifts::Array{Int, 1}=zeros(Int, 0))
  ## Variables.
  m = Model(solver=solver)
  pm = PlantModel(m, p, ob, timing, shifts)

  ## Constraints.
  postConstraints(m, pm.hr, forcedShifts)
  postConstraints(m, pm.hr, collect(EquipmentModel, Iterators.filter((e) -> typeof(e) == EquipmentModel, values(equipmentModels(pm)))))
  for eq in values(equipmentModels(pm))
    postConstraints(m, eq, pm.hr)
  end
  postConstraints(m, pm.ob, equipmentModel(pm, "out"), alreadyProduced)
  for (name, f) in flowModels(pm)
    postConstraints(m, f, equipmentModels(pm))
  end

  # TODO: Strengthen the formulation: when two pieces of equipment are next to each other in the same route, then the second may only be activated when the first one is done (batch processes).

  @objective(m, Min, objective(m, obj, pm))

  # writeLP(m, outfile, genericnames=false)
  status = solve(m)

  if status != :Infeasible && status != :Unbounded && status != :Error
    shiftsOpen = [round(Bool, round(Int, getvalue(shiftOpen(timingModel(pm), d)))) for d in shiftBeginning(pm) : shiftDurationsStep(pm) : timeEnding(pm)] 
    productionRaw = getvalue(quantity(equipmentModel(pm, "out"))) # TODO: In PlantModel, link to the variables of each subobject model? Define quantity() and others on the plant model? Or just a subset?
    return true, pm, m, shiftsOpen, productionRaw # TODO: Fill a results data structure, for God's sake! That return syntax is horrible, and using it is a nightmare!
  else
    if length(outfile) > 0
      writeLP(m, outfile, genericnames=false)
    end
    return false, pm, m, Bool[], Float64[]
  end
end

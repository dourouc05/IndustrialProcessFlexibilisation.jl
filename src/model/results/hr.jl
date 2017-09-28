struct HRModelResults
  feasibility::Bool
  model::Model
  # TODO: HRModel data structure

  teamAssignment::Array{Bool, 2} # First index: team. Second index: shift (to be correlated with a ProductionModelResults object, namely its shiftsOpen property). 

  objective::Float64
  objectiveDifferenceInitialSolution::Float64
  objectiveDifferenceInitialSolutionLess::Array{Bool, 2}
  objectiveDifferenceInitialSolutionMore::Array{Bool, 2}
  objectiveSlackMinimumHours::Array{Float64, 1}
  objectiveSlackMaximumHours::Array{Float64, 1}
  objectiveSlackOvertime::Array{Float64, 1}
  objectiveUnfairnessNumberShifts::Float64
  objectiveUnfairnessNumberHours::Float64
  
  # Infeasible constructor. 
  function HRModelResults(model::Model)
    return new(false, model, 
               Array{Bool}(0, 0), 
               0.0, 0.0, Array{Bool}(0, 0), Array{Bool}(0, 0), Float64[], Float64[], Float64[], 0.0, 0.0)
  end

  # Feasible constructor
  function HRModelResults(model::Model, 
                          teamAssignment::Array{Bool, 2}, 
                          objective::Float64, objectiveDifferenceInitialSolution::Float64, objectiveDifferenceInitialSolutionLess::Array{Bool, 2}, 
                          objectiveDifferenceInitialSolutionMore::Array{Bool, 2}, objectiveSlackMinimumHours::Array{Float64, 1}, 
                          objectiveSlackMaximumHours::Array{Float64, 1}, objectiveSlackOvertime::Array{Float64, 1}, 
                          objectiveUnfairnessNumberShifts::Float64, objectiveUnfairnessNumberHours::Float64)
    return new(true, model, 
               teamAssignment, 
               objective, objectiveDifferenceInitialSolution, objectiveDifferenceInitialSolutionLess, objectiveDifferenceInitialSolutionMore, 
               objectiveSlackMinimumHours, objectiveSlackMaximumHours, objectiveSlackOvertime, objectiveUnfairnessNumberShifts, objectiveUnfairnessNumberHours)
  end
end
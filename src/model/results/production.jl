# struct Batch
#   product::Product
#   quantity::Float64

#   start::DateTime
#   duration::TimePeriod
# end

"""
Results from the production model. They are divided into three categories: 

  * optimisation details: 
    * `feasibility`: whether there is a solution (other categories make no sense otherwise)
    * `model`: the internal JuMP optimisation model
    * `plantModel`: the internal plant model (see `PlantModel`)

  * HR results: 
    * `shiftsOpenRaw`: whether a shift (with a discretisation corresponding to the step in the `Shifts` object) is worked
    * `shiftsOpen`: indicates which shifts are worked, with realistic shift lengths ()

  * production results: 
    * `productionPlanOutput`: the production for each time step (first index) and each product (second index)

Two constructors: 

  * when infeasible: only takes as input `model` and `plantModel`
  * when feasible, also takes `shiftsOpenRaw` (`shiftsOpen` is derived automatically) and `productionPlanOutput`
"""
struct ProductionModelResults
  feasibility::Bool
  model::Model
  plantModel::PlantModel

  shiftsOpenRaw::Array{Bool, 1}
  shiftsOpen::Array{Tuple{DateTime, Hour}, 1}

  productionPlanOutput::Array{Float64, 2}

  # Infeasible constructor. 
  function ProductionModelResults(model::Model, plantModel::PlantModel)
    return new(false, model, plantModel, Bool[], BULLSHIT, Float64[])
  end

  # Feasible constructor
  function ProductionModelResults(model::Model, plantModel::PlantModel, shiftsOpenRaw::Array{Bool, 1}, productionPlanOutput::Array{Float64, 2})
    return new(false, model, plantModel, shiftsOpenRaw, shiftsAgregation(shiftsOpenRaw, shifts(plantModel)), productionPlanOutput)
  end
end


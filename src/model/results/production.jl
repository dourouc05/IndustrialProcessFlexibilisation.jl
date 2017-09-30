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
    * `shiftsOpen`: indicates which shifts are worked, with realistic shift lengths. The first element of the tuple is the 
      beginning of the shift, while the second is its length. The third element of the tuple gives the number of teams 
      that are required for this shift

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
  shiftsOpen::Array{Tuple{DateTime, Hour, Int}, 1} # TODO: make a specific data structure with dedicated operations? Would guarantee invariants as checked at the beginning of model/hr.jl:teamModel; other operations of this function would be simplified. Could make this data structure easier to evolve (two full teams are probably not needed if two machines are to be operated, depending on the plant). In this case, this data structure would remove the raw field. 

  productionPlanOutput::Array{Float64, 2} # TODO: Rewrite using the proposed Batch structure? Could get rid of the fixed matrix structure. 

  # Infeasible constructor. 
  function ProductionModelResults(model::Model, plantModel::PlantModel)
    return new(false, model, plantModel, Bool[], Tuple{DateTime, Hour}[], zeros(Float64, 0, 0))
  end

  # Feasible constructor
  function ProductionModelResults(model::Model, plantModel::PlantModel, shiftsOpenRaw::Array{Bool, 1}, shiftsOpen::Array{Tuple{DateTime, Hour, Int}, 1}, productionPlanOutput::Array{Float64, 2})
    return new(true, model, plantModel, shiftsOpenRaw, shiftsOpen, productionPlanOutput)
  end
end

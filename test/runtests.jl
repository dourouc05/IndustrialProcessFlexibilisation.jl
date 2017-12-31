using Base.Test
using Base.Dates
using TimeSeries
using JuMP
using Cbc
using IndustrialProcessFlexibilisation

# Types used for the tests.
struct ConcreteRoute <: Route end # Data structures > Routes
struct DummyProductionObjective <: ProductionObjective end # Optimisation models > Data structures > Objective

@testset "IndustrialProcessFlexibilisation.jl" begin
  include("data.jl")
  
  @testset "Optimisation models" begin
    include("model_ds.jl")

    @testset "Model building blocks (postConstraints)" begin
      include("model_postconstraints_timing.jl")
      include("model_postconstraints_equipments.jl")
      include("model_postconstraints_equipment.jl")
      include("model_postconstraints_orderbook.jl")
      include("model_postconstraints_flows.jl")
      include("model_postconstraints_objective.jl")
    end

    include("model_prod.jl")
    include("model_team.jl")
  end

  include("utils.jl")
  include("io.jl")
end
